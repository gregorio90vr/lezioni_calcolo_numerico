suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(ggplot2)
  library(lubridate)
  library(scales)
})

# ------------------------------------------------------------
#  PCA sulle VARIAZIONI MENSILI della curva dei tassi BCE
#  Aggregazione all'ultima rilevazione di ogni mese di calendario.
#  Input : ../dati/04_ecb_spot.xlsx (prodotto da 04_pca_ecb_prep.R)
#  Output: figure PDF e frammenti LaTeX in ../output/04b_pca_ecb/
#
#  UNITA': i tassi sono convertiti in DECIMALI subito dopo la lettura
#  (2.592% -> 0.02592), cosi' da essere direttamente confrontabili con
#  la curva ECB fuori campione dell'ultima sezione. La conversione avviene solo in
#  fase di visualizzazione:
#     livelli    * 100  -> percentuale
#     variazioni * 1e4  -> punti base
#
#  STRUTTURA DELLO SCRIPT (a fini didattici):
#     1. Elaborazione dei dati
#     2. Calcolo della PCA
#     3. Ricostruzione della curva ECB di luglio 2026 (fuori campione)
#     4. Costruzione dei grafici
# ------------------------------------------------------------

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

input_xlsx <- "../dati/04_ecb_spot.xlsx"
output_dir <- "../output/04b_pca_ecb"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(input_xlsx)) {
  stop(paste0("File non trovato: ", input_xlsx,
              "\nEsegui prima 04_pca_ecb_prep.R oppure verifica il percorso."))
}

# ==============================================================
# SEZIONE 1: ELABORAZIONE DEI DATI
# ==============================================================

cat("\n=== SEZIONE 1: ELABORAZIONE DEI DATI ===\n")

sheet_names <- getSheetNames(input_xlsx)
use_sheet   <- if ("PCA_Input" %in% sheet_names) "PCA_Input" else sheet_names[1]
curve_df    <- as.data.table(read.xlsx(input_xlsx, sheet = use_sheet))

# Uniforma nome colonna data
if (!"TIME_PERIOD" %in% names(curve_df)) {
  idx <- which(tolower(names(curve_df)) == "time_period")
  if (length(idx) == 1L) setnames(curve_df, names(curve_df)[idx], "TIME_PERIOD")
}
if (!"TIME_PERIOD" %in% names(curve_df))
  stop("Colonna TIME_PERIOD non trovata nel file Excel.")

# Riconosce le maturity e le ordina per scadenza crescente
maturity_cols <- grep("^([1-9]|1[0-9]|20)Y$", names(curve_df), value = TRUE)
if (length(maturity_cols) < 3L)
  stop("Trovate meno di 3 maturity: impossibile costruire una PCA robusta.")
maturity_cols <- maturity_cols[order(as.integer(sub("Y$", "", maturity_cols)))]
maturity_num  <- as.integer(sub("Y$", "", maturity_cols))
n_mat         <- length(maturity_cols)

# Parsing robusto delle date
parse_time_period <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (is.numeric(x)) return(openxlsx::convertToDate(x))
  x_chr <- trimws(as.character(x))
  x_num <- suppressWarnings(as.numeric(x_chr))
  out   <- as.Date(rep(NA_character_, length(x_chr)))
  is_serial <- !is.na(x_num)
  if (any(is_serial)) out[is_serial] <- openxlsx::convertToDate(x_num[is_serial])
  to_parse <- is.na(out) & nzchar(x_chr)
  if (any(to_parse))
    out[to_parse] <- as.Date(
      lubridate::parse_date_time(x_chr[to_parse],
                                 orders = c("Y-m-d","Y/m/d","m/d/Y","d/m/Y","m-d-Y","d-m-Y","mdy","dmy"),
                                 exact = FALSE))
  out
}

curve_df[, TIME_PERIOD := parse_time_period(TIME_PERIOD)]
if (anyNA(curve_df$TIME_PERIOD))
  stop("Alcune date in TIME_PERIOD non sono parseabili. Verifica il formato.")

# Conversione in decimali: 2.592 (%) -> 0.02592
for (cc in maturity_cols) curve_df[, (cc) := as.numeric(get(cc)) / 100]

# Rimuovi righe quasi vuote e interpola NA isolati
valid_rows <- rowSums(!is.na(curve_df[, ..maturity_cols])) >= 3L
curve_df   <- curve_df[valid_rows, c("TIME_PERIOD", maturity_cols), with = FALSE]
setorder(curve_df, TIME_PERIOD)

for (cc in maturity_cols) {
  x <- curve_df[[cc]]
  if (anyNA(x)) {
    ok <- which(!is.na(x))
    if (length(ok) >= 2L) {
      cat("Interpolazione NA sulla colonna", cc, "\n")
      curve_df[[cc]] <- approx(ok, x[ok], seq_along(x), rule = 2L)$y
    }
  }
}

cat("Dati giornalieri caricati:", nrow(curve_df), "osservazioni.\n")


# ------------------------------------------------------------------
# AGGREGAZIONE MENSILE
# Strategia: ultima osservazione disponibile di ogni mese di calendario.
# Il fine-mese cattura il "mark-to-market" mensile su cui si fondano
# le analisi di rischio e le variazioni mensili di portafoglio.
# ------------------------------------------------------------------

curve_df[, YM := lubridate::floor_date(TIME_PERIOD, "month")]
# Ultima osservazione di ogni mese (fine mese effettivo BCE)
monthly_dt <- curve_df[, .SD[.N], by = YM, .SDcols = c("TIME_PERIOD", maturity_cols)]
setorder(monthly_dt, YM)

n_months     <- nrow(monthly_dt)
R_mat_m      <- as.matrix(monthly_dt[, ..maturity_cols])   # M x n
# NOTA: YM e' solo la chiave di raggruppamento (primo giorno del mese), usata
# per selezionare l'ultima osservazione disponibile in ogni mese. La data
# associata a ogni riga a valle (grafici, eventi, mese selezionato) e' invece
# la fine mese effettiva TIME_PERIOD, coerentemente con quanto dichiarato nella
# dispensa (t*(s) = ultima giornata BCE del mese).
dates_m      <- monthly_dt$TIME_PERIOD                      # fine mese effettiva
Delta_R_m    <- diff(R_mat_m)                               # (M-1) x n
dates_delta_m <- dates_m[-1]

cat("Aggregazione mensile: ", n_months, " mesi (da ",
    format(min(dates_m), "%b %Y"), " a ", format(max(dates_m), "%b %Y"), ").\n",
    sep = "")
cat("Variazioni mensili disponibili:", nrow(Delta_R_m), "\n")

monthly_dt[,anno := year(TIME_PERIOD)]
monthly_dt[,mese := month(TIME_PERIOD)]
monthly_dt[,periodo := paste0(anno,"_",mese)]


# ==============================================================
# SEZIONE 2: CALCOLO DELLA PCA
# ==============================================================

cat("\n=== SEZIONE 2: CALCOLO DELLA PCA (SVD SU DATI MENSILI) ===\n")

xm <- rep(0,length(maturity_cols))
for(i in c(1:length(maturity_cols))){
  xm[i] <- mean(Delta_R_m[,i])
}
X_m = Delta_R_m - matrix(rep(xm, nrow(Delta_R_m)), nrow = nrow(Delta_R_m), byrow = TRUE)

sv_m      <- svd(X_m)
sing_vals <- sv_m$d
V <- sv_m$v
U <- sv_m$u
k =3

loadings <- V[,1:k] # 20 valori 1 per ogni maturity, limitato a tre dimensioni

scores_all <- U %*% diag(sing_vals)
scores     <- scores_all[,1:k] #tre valori per ogni mese quindi ho l'indicazione del mese

X_m_k = scores %*% t(loadings)

expl_var <- sing_vals^2 / sum(sing_vals^2)
cum_var  <- cumsum(expl_var)

cat("Varianza spiegata prime", k, "componenti:",
    paste(round(100 * expl_var[1:k], 2), "%", collapse = ", "), "\n")

rmse_m <- sqrt(mean((X_m - X_m_k)^2))
cat("RMSE ricostruzione con k=3:", signif(rmse_m, 4),
    " (in bp:", round(rmse_m * 1e4, 2), ")\n")

#----- ricostruiamo delta primo mese

mese1 <- '2004_10'
row_number1 <- which(monthly_dt$periodo == mese1) -1 # in quanto in diff abbiamo tolto il valore iniziale
delta_dati1 <- Delta_R_m[row_number1,]

delta_ricostrito <- xm + scores[row_number1,1]*loadings[,1]+scores[row_number1,2]*loadings[,2]+scores[row_number1,3]*loadings[,3]

confronto_ottobre2004 <- data.table(maturity = maturity_num,
                       x_m_originale = delta_dati1,
                       x_m_ricostruito = delta_ricostrito,
                       delta_bp = (delta_ricostrito - delta_dati1)*1e4)

print(confronto_ottobre2004)


#----- ricostruiamo delta di settembre 2015

mese2       <- '2015_9'
row_number2 <- which(monthly_dt$periodo == mese2) -1 # in quanto in diff abbiamo tolto il valore iniziale
delta_dati2 <- Delta_R_m[row_number2,]

delta_ricostrito2<- xm + scores[row_number2,1]*loadings[,1]+scores[row_number2,2]*loadings[,2]+scores[row_number2,3]*loadings[,3]

confronto_settembre2015 <- data.table(maturity = maturity_num,
                                  x_m_originale = delta_dati2,
                                  x_m_ricostruito = delta_ricostrito2,
                                  delta_bp = (delta_ricostrito2 - delta_dati2)*1e4)

print(confronto_settembre2015)


#----- ricostruiamo delta di giugno 2026

mese3       <- '2026_6'
row_number3 <- which(monthly_dt$periodo == mese3) -1 # in quanto in diff abbiamo tolto il valore iniziale
delta_dati3 <- Delta_R_m[row_number3,]

delta_ricostrito3<- xm + scores[row_number3,1]*loadings[,1] + scores[row_number3,2]*loadings[,2] + scores[row_number3,3]*loadings[,3]

confronto_giugno2026 <- data.table(maturity = maturity_num,
                                    x_m_originale = delta_dati3,
                                    x_m_ricostruito = delta_ricostrito3,
                                    delta_bp = (delta_ricostrito3 - delta_dati3)*1e4)

print(confronto_giugno2026)


#----- ricostruzione progressiva di giugno 2026

delta_ricostrito3_loading1     <- xm + scores[row_number3,1]*loadings[,1]
delta_ricostrito3_loading1_2   <- delta_ricostrito3_loading1 +scores[row_number3,2]*loadings[,2]
delta_ricostrito3_loading1_2_3 <- delta_ricostrito3_loading1_2 +scores[row_number3,3]*loadings[,3]


confronto_progressione_giugno2026 <- data.table(maturity = maturity_num,
                                  x_m_originale = delta_dati3,
                                  x_m_ricostruito_1     = delta_ricostrito3_loading1,
                                  x_m_ricostruito_1_2   = delta_ricostrito3_loading1_2,
                                  x_m_ricostruito_1_2_3 = delta_ricostrito3_loading1_2_3)


print(confronto_progressione_giugno2026)


# ==============================================================
# SEZIONE 3: RICOSTRUZIONE CURVA ECB LUGLIO 2026 (FUORI CAMPIONE)
# ==============================================================
#
# Le colonne di V sono una base ortonormale di R^20: per k=n permettono di
# rappresentare ESATTAMENTE qualsiasi curva (non solo le variazioni su cui
# sono state stimate), e per k<n la proiezione P_k = V_k V_k^T ne da'
# un'approssimazione. Si proietta quindi direttamente la curva target, senza
# passare da un delta rispetto a una curva di riferimento.

cat("\n=== SEZIONE 3: RICOSTRUZIONE CURVA ECB LUGLIO 2026 (FUORI CAMPIONE) ===\n")

# --- Curva target: ECB al 30/07/2026 --------------------------------
# Il campione principale (monthly_dt) finisce a giugno 2026: per avere una
# curva genuinamente fuori campione serve un file con dati piu' recenti.
# Fonte: dati/04b_ecb_spot_20260730.xlsx (ECB Data Portal), foglio PCA_Input,
# una singola riga (gia' filtrata da 04_pca_ecb_prep.R).
input_xlsx2 <- "../dati/04b_ecb_spot_20260730.xlsx"
dt <- data.table(read.xlsx(input_xlsx2, sheet = "PCA_Input"))

y_new <- as.numeric(dt[, maturity_cols, with = FALSE]) / 100

cat("Curva target:", format(as.Date("2026-07-30")), "\n")

#metodo 1: proiettando sul sottospazio dei loadings e combinazione lineare dei loadings
alpha <- t(loadings) %*% y_new
cat("Scores alpha (%) sui primi 3 loadings:",
    paste(round(as.numeric(alpha) * 100, 2), collapse = ", "), "\n")
y_new_ricostruita_m1 <- alpha[1] * loadings[,1] + alpha[2] * loadings[,2] + alpha[3] * loadings[,3]
y_new_ricostruita_m1 <- as.numeric(y_new_ricostruita_m1)

#metodo 2: usando il proiettore ortogonale (equivalente al metodo 1)
y_new_ricostruita_m2 <- as.numeric(loadings %*% t(loadings) %*% y_new)

cat("Le due formulazioni coincidono (scarto max):",
    signif(max(abs(y_new_ricostruita_m1 - y_new_ricostruita_m2)), 3), "\n")

# --- Ricostruzioni per alcuni valori di k --------------------------
ricostruisci <- function(kk) {
  Vk <- V[, 1:kk, drop = FALSE]
  as.numeric(Vk %*% (t(Vk) %*% y_new))
}
ric_k3  <- ricostruisci(3)
ric_k10 <- ricostruisci(10)
ric_kn  <- ricostruisci(n_mat)

confronto_ecb <- data.table(
  maturity          = maturity_num,
  curva_ecb         = y_new,
  curva_ricostruita = ric_k3,
  errore_k3_bp      = (ric_k3  - y_new)*1e4,
  errore_k10_bp     = (ric_k10 - y_new)*1e4,
  errore_k20_bp     = (ric_kn - y_new)*1e4
)
print(confronto_ecb)

# --- Errore al variare di k ----------------------------------------
err_k <- rep(0, n_mat)
for (kk in 1:n_mat) {
  err_k[kk] <- sqrt(sum((ricostruisci(kk) - y_new)^2)) * 1e4
}

tabella_errori <- data.table(k = 1:n_mat, errore_bp = round(err_k, 2))
cat("\n--- Errore L2 di ricostruzione per numero di componenti (bp) ---\n")
print(tabella_errori)


# ==============================================================
# SEZIONE 4: COSTRUZIONE DEI GRAFICI
# ==============================================================

cat("\n=== SEZIONE 4: COSTRUZIONE DEI GRAFICI ===\n")

plot_theme <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    legend.position  = "bottom"
  )

# ------------------------------------------------------------------
# Grafico 0 — esempio illustrativo di una curva dei tassi (sezione 1.1)
# ------------------------------------------------------------------
esempio_dt <- data.table(
  MAT_NUM = maturity_num,
  Rate    = as.numeric(curve_df[.N, ..maturity_cols]) * 100
)

g0 <- ggplot(esempio_dt, aes(x = MAT_NUM, y = Rate)) +
  geom_line(linewidth = 1.1, color = "#4575b4") +
  geom_point(size = 2, color = "#4575b4") +
  scale_x_continuous(breaks = maturity_num) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.01)) +
  labs(title = "Esempio di curva dei tassi di interesse",
       x = "Scadenza (tenor / maturity, anni)",
       y = "Tasso di interesse (%)") +
  plot_theme
ggsave(file.path(output_dir, "step0_esempio_curva_tassi.pdf"),
       g0, width = 8, height = 4.5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 1 — curve dei livelli in 3 mesi rappresentativi
# ------------------------------------------------------------------
idx_livelli <- unique(round(c(1, n_months / 2, n_months)))
livelli_dt  <- data.table()
for (i in idx_livelli) {
  livelli_dt <- rbind(livelli_dt, data.table(
    Data    = format(dates_m[i], "%b %Y"),
    MAT_NUM = maturity_num,
    Rate    = as.numeric(R_mat_m[i, ]) * 100
  ))
}

g1 <- ggplot(livelli_dt, aes(x = MAT_NUM, y = Rate, color = Data, group = Data)) +
  geom_line(linewidth = 1) + geom_point(size = 1.7) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.01)) +
  labs(title = "Curve dei tassi in 3 mesi rappresentativi",
       x = "Scadenza (anni)", y = "Tasso (%)", color = "Mese") +
  plot_theme
ggsave(file.path(output_dir, "step1_curve_livelli_m.pdf"),
       g1, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 2 — boxplot delle variazioni mensili per scadenza
# ------------------------------------------------------------------
delta_dt <- as.data.table(Delta_R_m)
setnames(delta_dt, maturity_cols)
delta_dt[, TIME_PERIOD := dates_delta_m]
delta_long <- melt(delta_dt, id.vars = "TIME_PERIOD",
                   measure.vars = maturity_cols,
                   variable.name = "MATURITY", value.name = "DeltaRate")
delta_long[, MAT_NUM := as.integer(sub("Y$", "", MATURITY))]

g2 <- ggplot(delta_long, aes(x = factor(MAT_NUM), y = DeltaRate * 1e4)) +
  geom_hline(yintercept = 0, color = "grey40", linetype = "dashed") +
  geom_boxplot(fill = "#4575b4", alpha = 0.55,
               outlier.size = 0.7, outlier.alpha = 0.4, width = 0.65) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  labs(title = "Distribuzione delle variazioni mensili per scadenza",
       x = "Scadenza (anni)",
       y = "Variazione mensile (punti base)",
       caption = "Scatola: 25-75 percentile; baffi: 1.5xIQR; punti: outlier.\n1 pb = 0.01%. Le variazioni mensili sono tipicamente 10-80 pb, ben visibili.") +
  plot_theme +
  theme(plot.caption = element_text(size = 8, color = "grey50"))
ggsave(file.path(output_dir, "step1_delta_mensili.pdf"),
       g2, width = 10, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 3 — heatmap delle correlazioni fra variazioni mensili
# ------------------------------------------------------------------
cor_mat <- cor(Delta_R_m, use = "pairwise.complete.obs")
cor_dt  <- as.data.table(as.table(cor_mat))
setnames(cor_dt, c("MAT_X", "MAT_Y", "CORR"))
cor_dt[, MAT_XN := as.integer(sub("Y$", "", MAT_X))]
cor_dt[, MAT_YN := as.integer(sub("Y$", "", MAT_Y))]

g3 <- ggplot(cor_dt, aes(x = MAT_XN, y = MAT_YN, fill = CORR)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Correlazione tra variazioni mensili",
       x = "Scadenza X (anni)", y = "Scadenza Y (anni)", fill = "Corr") +
  coord_fixed() + plot_theme
ggsave(file.path(output_dir, "step1_heatmap_correlazioni_m.pdf"),
       g3, width = 7, height = 6, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 3b (opzionale) — correlazioni in 3D a barre
# Richiede il pacchetto plot3D; se assente il resto dello script continua.
# ------------------------------------------------------------------
if (requireNamespace("plot3D", quietly = TRUE)) {
  corr_cols <- colorRampPalette(c("#2c7bb6", "#ffffbf", "#d7191c"))(120)

  corr_rng  <- range(cor_mat, na.rm = TRUE)
  corr_pad  <- max(0.01, 0.08 * diff(corr_rng))
  zlim_zoom <- c(max(-1, corr_rng[1] - corr_pad), min(1, corr_rng[2] + corr_pad))
  corr_breaks <- seq(zlim_zoom[1], zlim_zoom[2], length.out = 121)
  z_expand    <- if (diff(zlim_zoom) < 0.18) 28 else 28 / 2

  grDevices::cairo_pdf(file.path(output_dir, "step1_correlazioni_3d_barre_m.pdf"),
                       width = 10, height = 8.5)
  par(mar = c(3, 3, 3, 3), oma = c(0, 0, 0, 4))
  plot3D::hist3D(
    x = sort(unique(cor_dt$MAT_XN)), y = sort(unique(cor_dt$MAT_YN)),
    z = cor_mat, colvar = cor_mat, col = corr_cols, breaks = corr_breaks,
    border = "grey40", shade = 0.3, lighting = TRUE,
    theta = 42, phi = 30, d = 2.5, scale = FALSE, expand = z_expand,
    ticktype = "detailed",
    xlab = "Scadenza X (anni)", ylab = "Scadenza Y (anni)", zlab = "Correlazione",
    zlim = zlim_zoom, main = "Correlazioni mensili (3D zoom)",
    cex.main = 1.15, cex.lab = 0.95, cex.axis = 0.85, colkey = FALSE
  )
  grDevices::dev.off()
  cat("Grafico 3D correlazioni salvato (plot3D).\n")
} else {
  cat("Pacchetto 'plot3D' non trovato: salto il grafico 3D correlazioni.\n")
}

# ------------------------------------------------------------------
# Grafico 4 — scree plot e varianza cumulata
# ------------------------------------------------------------------
var_dt <- data.table(PC = seq_along(expl_var), ExplVar = expl_var, CumVar = cum_var)
lab_dt <- var_dt[1:k]
lab_dt[, Label := sprintf("%.1f%%", 100 * CumVar)]

g4 <- ggplot(var_dt, aes(x = PC)) +
  geom_col(aes(y = ExplVar), fill = "#4575b4", alpha = 0.85) +
  geom_line(aes(y = CumVar), color = "#d73027", linewidth = 1) +
  geom_point(aes(y = CumVar), color = "#d73027", size = 1.6) +
  geom_label(data = lab_dt, aes(y = CumVar, label = Label),
             nudge_y = 0.045, size = 3.2, colour = "#d73027",
             fill = "white", label.size = 0.25,
             label.padding = unit(0.15, "lines")) +
  scale_y_continuous(labels = label_percent()) +
  labs(title = "Scree plot e varianza cumulata (mensile)",
       x = "Componente principale", y = "Quota di varianza") +
  plot_theme
ggsave(file.path(output_dir, "step2_varianza_spiegata_m.pdf"),
       g4, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 5 — loadings delle prime tre componenti
# (sostituisce i plot() base R usati in fase esplorativa)
# ------------------------------------------------------------------
loadings_dt <- data.table()
for (i in 1:k) {
  loadings_dt <- rbind(loadings_dt, data.table(
    MAT_NUM = maturity_num,
    Loading = loadings[, i],
    PC      = paste0("PC", i)
  ))
}

g5 <- ggplot(loadings_dt, aes(x = MAT_NUM, y = Loading, color = PC)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line(linewidth = 1) + geom_point(size = 1.4) +
  labs(title = "Loadings delle prime componenti (livello/pendenza/curvatura)",
       x = "Scadenza (anni)", y = "Loading") +
  plot_theme
ggsave(file.path(output_dir, "step3_loadings_pc1_pc3_m.pdf"),
       g5, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 6 — scores mensili con media mobile a 6 mesi ed eventi macro
# ------------------------------------------------------------------
scores_dt <- data.table()
for (i in 1:k) {
  scores_dt <- rbind(scores_dt, data.table(
    TIME_PERIOD = dates_delta_m,
    Score       = scores[, i] * 1e4,      # in punti base
    PC          = paste0("PC", i)
  ))
}
scores_dt[, ScoreMA := data.table::frollmean(Score, n = 6, align = "right"), by = PC]

key_events <- data.table(
  date  = as.Date(c("2008-10-01", "2015-01-01", "2022-07-01")),
  label = c("Lehman\n(ott. 2008)", "QE BCE\n(gen. 2015)", "Rialzi BCE\n(lug. 2022)")
)
key_events[, matched_date := as.Date(sapply(date, function(d)
  dates_delta_m[which.min(abs(as.numeric(dates_delta_m - d)))]), origin = "1970-01-01")]

g6 <- ggplot(scores_dt, aes(x = TIME_PERIOD)) +
  geom_line(aes(y = Score), linewidth = 0.5, color = "#a6bddb") +
  geom_line(aes(y = ScoreMA), linewidth = 1, color = "#045a8d", na.rm = TRUE) +
  geom_vline(data = key_events, aes(xintercept = matched_date),
             linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_label(data = key_events[, c(.SD, list(PC = "PC1"))],
             aes(x = matched_date, y = Inf, label = label),
             inherit.aes = FALSE, vjust = 1.05, hjust = 0.5, size = 2.5,
             fill = "white", label.size = 0.2, label.padding = unit(0.15, "lines")) +
  facet_wrap(~PC, ncol = 1, scales = "free_y",
             labeller = labeller(PC = c(PC1 = "PC1 - Livello",
                                        PC2 = "PC2 - Pendenza",
                                        PC3 = "PC3 - Curvatura"))) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  labs(title = "Scores mensili: serie grezza vs media mobile a 6 mesi",
       subtitle = "Linea chiara: score mensile. Linea blu scura: media mobile a 6 mesi",
       x = NULL, y = "Score (punti base)") +
  plot_theme +
  theme(strip.text = element_text(face = "bold"), legend.position = "none")
ggsave(file.path(output_dir, "step3_scores_mensili_ma_m.pdf"),
       g6, width = 11, height = 9, device = cairo_pdf)
cat("Grafico scores con media mobile salvato.\n")

# ------------------------------------------------------------------
# Grafico 7 — confronto osservata vs ricostruita sui tre mesi
# Grafico 8 — errore di ricostruzione per singola scadenza
# ------------------------------------------------------------------
etichetta1 <- paste0("Primo mese: ",    format(dates_delta_m[row_number1], "%b %Y"))
etichetta2 <- paste0("Mese centrale: ", format(dates_delta_m[row_number2], "%b %Y"))
etichetta3 <- paste0("Ultimo mese: ",   format(dates_delta_m[row_number3], "%b %Y"))

ricostruzione_dt <- rbind(
  data.table(Mese = etichetta1, MAT_NUM = maturity_num, Serie = "Delta osservata",               DeltaRate = delta_dati1),
  data.table(Mese = etichetta1, MAT_NUM = maturity_num, Serie = "Delta ricostruita (PCA, k=3)",  DeltaRate = delta_ricostrito),
  data.table(Mese = etichetta2, MAT_NUM = maturity_num, Serie = "Delta osservata",               DeltaRate = delta_dati2),
  data.table(Mese = etichetta2, MAT_NUM = maturity_num, Serie = "Delta ricostruita (PCA, k=3)",  DeltaRate = delta_ricostrito2),
  data.table(Mese = etichetta3, MAT_NUM = maturity_num, Serie = "Delta osservata",               DeltaRate = delta_dati3),
  data.table(Mese = etichetta3, MAT_NUM = maturity_num, Serie = "Delta ricostruita (PCA, k=3)",  DeltaRate = delta_ricostrito3)
)
ricostruzione_dt[, Mese := factor(Mese, levels = c(etichetta1, etichetta2, etichetta3))]

g7 <- ggplot(ricostruzione_dt, aes(x = MAT_NUM, y = DeltaRate * 1e4,
                                   color = Serie, linetype = Serie)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line(linewidth = 1.1) + geom_point(size = 1.6) +
  scale_color_manual(values = c("Delta osservata" = "#000000",
                                "Delta ricostruita (PCA, k=3)" = "#d73027")) +
  scale_linetype_manual(values = c("Delta osservata" = "solid",
                                   "Delta ricostruita (PCA, k=3)" = "dashed")) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  facet_wrap(~Mese, ncol = 1, scales = "free_y") +
  labs(title = "Confronto: delta osservata vs delta ricostruita con PCA",
       subtitle = "Mesi selezionati: primo, centrale, ultimo",
       x = "Scadenza (anni)", y = "Variazione mensile (punti base)",
       color = "Serie", linetype = "Serie") +
  plot_theme
ggsave(file.path(output_dir, "step3_confronto_ricostruzione_m.pdf"),
       g7, width = 9, height = 9, device = cairo_pdf)
cat("Grafico confronto ricostruzione salvato.\n")

errore_dt <- rbind(
  data.table(Mese = etichetta1, MAT_NUM = maturity_num, Errore_bp = (delta_ricostrito  - delta_dati1)*1e4),
  data.table(Mese = etichetta2, MAT_NUM = maturity_num, Errore_bp = (delta_ricostrito2 - delta_dati2)*1e4),
  data.table(Mese = etichetta3, MAT_NUM = maturity_num, Errore_bp = (delta_ricostrito3 - delta_dati3)*1e4)
)
errore_dt[, Mese := factor(Mese, levels = c(etichetta1, etichetta2, etichetta3))]

g8 <- ggplot(errore_dt, aes(x = factor(MAT_NUM), y = Errore_bp)) +
  geom_col(fill = "#e66101", width = 0.65) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  facet_wrap(~Mese, ncol = 1, scales = "free_y") +
  labs(title = "Errore di ricostruzione per scadenza (k=3)",
       subtitle = "Differenza (ricostruita - osservata) sui mesi selezionati",
       x = "Scadenza (anni)", y = "Errore (punti base)") +
  plot_theme
ggsave(file.path(output_dir, "step3_errore_ricostruzione_tenor_m.pdf"),
       g8, width = 9, height = 9, device = cairo_pdf)
cat("Grafico errore di ricostruzione per tenore salvato.\n")

# ------------------------------------------------------------------
# Grafico 9 — ricostruzione progressiva: si aggiunge un fattore alla volta
# ------------------------------------------------------------------
lbl_k1 <- paste0("k=1  (", round(100 * cum_var[1], 1), "% var.)")
lbl_k2 <- paste0("k=2  (", round(100 * cum_var[2], 1), "% var.)")
lbl_k3 <- paste0("k=3  (", round(100 * cum_var[3], 1), "% var.)")
livelli_serie <- c(lbl_k1, lbl_k2, lbl_k3, "Reale")

progressiva_dt <- rbind(
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito3_loading1,     Serie = lbl_k1),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito3_loading1_2,   Serie = lbl_k2),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito3_loading1_2_3, Serie = lbl_k3),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_dati3,                    Serie = "Reale")
)
progressiva_dt[, Serie := factor(Serie, levels = livelli_serie)]

col_scale <- setNames(c("#74add1", "#f46d43", "#1a9850", "#000000"), livelli_serie)
lty_scale <- setNames(c("solid", "solid", "solid", "solid"), livelli_serie)
lwd_scale <- setNames(c(1.0, 1.0, 1.0, 1.5), livelli_serie)

g9 <- ggplot(progressiva_dt, aes(x = MAT_NUM, y = DeltaRate * 1e4,
                                 color = Serie, linetype = Serie, linewidth = Serie)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line() +
  geom_point(data = progressiva_dt[Serie == "Reale"], size = 2) +
  scale_color_manual(values = col_scale) +
  scale_linetype_manual(values = lty_scale) +
  scale_linewidth_manual(values = lwd_scale) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  labs(title = "Ricostruzione progressiva della variazione mensile",
       subtitle = paste0("Ultimo mese: ", format(dates_delta_m[row_number3], "%B %Y")),
       x = "Scadenza (anni)", y = "Variazione mensile (punti base)",
       color = "Componenti", linetype = "Componenti") +
  plot_theme +
  theme(legend.text = element_text(size = rel(1.05)),
        legend.title = element_text(size = rel(1.05)),
        legend.key.size = unit(1.26, "lines")) +
  guides(linewidth = "none")
ggsave(file.path(output_dir, "step3_ricostruzione_progressiva_m.pdf"),
       g9, width = 10, height = 5.5, device = cairo_pdf)
cat("Grafico ricostruzione progressiva salvato.\n")

# ------------------------------------------------------------------
# Figura 1 — curva ECB (30/07/2026) originale e ricostruzioni con k = 3 e k = n
# ------------------------------------------------------------------
et_orig <- "Curva ECB 30/07/2026 (originale)"
et_k3   <- "Ricostruita con k=3"
et_kn   <- "Ricostruita con k=20 (esatta)"
livelli_fig1 <- c(et_orig, et_k3, et_kn)

curve_fig1 <- rbind(
  data.table(MAT_NUM = maturity_num, Valore = y_new*100,  Tipo = et_orig),
  data.table(MAT_NUM = maturity_num, Valore = ric_k3*100, Tipo = et_k3),
  data.table(MAT_NUM = maturity_num, Valore = ric_kn*100, Tipo = et_kn)
)
curve_fig1[, Tipo := factor(Tipo, levels = livelli_fig1)]

g_fig1 <- ggplot(curve_fig1, aes(x = MAT_NUM, y = Valore, colour = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.1) +
  geom_point(data = curve_fig1[Tipo == et_orig], size = 2.2) +
  scale_colour_manual(values = setNames(c("#000000","#1a9850","#e66101"), livelli_fig1)) +
  scale_linetype_manual(values = setNames(c("solid","dashed","dotted"), livelli_fig1)) +
  scale_x_continuous(breaks = seq(1, 20, by = 2)) +
  scale_y_continuous(labels = label_number(suffix = "%", accuracy = 0.01)) +
  labs(title = "Ricostruzione PCA della curva ECB (30/07/2026)",
       subtitle = "Proiezione diretta sui primi k loadings",
       x = "Scadenza (anni)", y = "Tasso (%)", colour = NULL, linetype = NULL) +
  plot_theme
ggsave(file.path(output_dir, "sez5_curva_ricostruzione.pdf"),
       g_fig1, width = 9, height = 5, device = cairo_pdf)
cat("Figura 1 (confronto ricostruzione) salvata.\n")

# ------------------------------------------------------------------
# Figura 2 — errore per singola scadenza a k = 3 (barre, serie unica)
# ------------------------------------------------------------------
err_tenor_dt <- data.table(MAT_NUM = maturity_num, Errore_bp = (ric_k3 - y_new) * 1e4)

g_fig2 <- ggplot(err_tenor_dt, aes(x = factor(MAT_NUM), y = Errore_bp)) +
  geom_col(fill = "#1a9850", width = 0.65) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  labs(title = "Errore di ricostruzione per scadenza (k = 3)",
       subtitle = "Differenza (ricostruita - originale) sulla curva ECB (30/07/2026)",
       x = "Scadenza (anni)", y = "Errore (punti base)") +
  plot_theme
ggsave(file.path(output_dir, "sez5_errore_per_tenor.pdf"),
       g_fig2, width = 9, height = 5, device = cairo_pdf)
cat("Figura 2 (errore per tenor) salvata.\n")

# ------------------------------------------------------------------
# Figura 3 — convergenza dell'errore in norma L2, scala LINEARE
# (a differenza di una scala log, mostra visibilmente che a k=20 l'errore
# e' esattamente zero, invece di escluderlo perche' non rappresentabile)
# ------------------------------------------------------------------
conv_dt <- data.table(k = 1:n_mat, Errore_bp = err_k)

# Il salto informativo e' a k=3: proiettare un livello (~3%) su 1-2
# direzioni a media nulla (stimate sulle variazioni) e' pessimo, k=3 lo
# risolve quasi del tutto.
ann_dt <- data.table(k = 3L, y_pos = err_k[3],
                     label = sprintf("k=3\n%.1f bp", err_k[3]))

g_fig3 <- ggplot(conv_dt, aes(x = k, y = Errore_bp)) +
  geom_line(colour = "#1a9850", linewidth = 1.05) +
  geom_point(colour = "#1a9850", size = 2.1) +
  geom_point(data = ann_dt, aes(x = k, y = y_pos), colour = "tomato", size = 3.4) +
  geom_label(data = ann_dt, aes(x = k, y = y_pos, label = label),
             nudge_x = 2.2, nudge_y = 8, size = 3, colour = "tomato",
             fill = "white", label.size = 0.3, label.padding = unit(0.2, "lines")) +
  scale_x_continuous(breaks = 1:n_mat) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, suffix = " bp")) +
  labs(title = "Convergenza dell'errore di ricostruzione",
       subtitle = "Norma L2 dell'errore sulla curva ECB (30/07/2026) al variare di k",
       x = "Numero di componenti principali k",
       y = "Errore L2 (punti base)") +
  plot_theme
ggsave(file.path(output_dir, "sez5_convergenza_errore.pdf"),
       g_fig3, width = 9, height = 5, device = cairo_pdf)
cat("Figura 3 (convergenza errore) salvata.\n")


# ==============================================================
# Frammenti LaTeX per la dispensa
# ==============================================================

# Tabella — curva originale, ricostruzione ed errore a k = 3
# (verticale: una riga per scadenza, cosi' non serve resizebox)
righe_tab_k3 <- sprintf("%dY & %.3f & %.3f & %+.2f \\\\",
                        maturity_num, y_new*100, ric_k3*100, (ric_k3 - y_new)*1e4)

tab_k3_file <- file.path(output_dir, "sez5_tabella_k3.tex")
writeLines(c(
  "\\begin{center}",
  "\\renewcommand{\\arraystretch}{1.15}",
  "\\begin{tabular}{c c c c}",
  "\\toprule",
  "Scadenza & Curva ECB (\\%) & Ricostruita $k=3$ (\\%) & Errore $k=3$ (bp) \\\\",
  "\\midrule",
  righe_tab_k3,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{center}"
), tab_k3_file)
cat("Tabella di ricostruzione salvata:", tab_k3_file, "\n")

# Riepilogo numerico
summary_file <- file.path(output_dir, "pca_summary_for_tex_m.tex")
writeLines(c(
  sprintf("Campione mensile analizzato: \\textbf{%d} mesi e \\textbf{%d} maturity.",
          n_months, n_mat),
  sprintf("Varianza spiegata PC1--PC3: \\textbf{%.2f\\%%, %.2f\\%%, %.2f\\%%}.",
          100*expl_var[1], 100*expl_var[2], 100*expl_var[3]),
  sprintf("RMSE della ricostruzione con $k=3$: \\textbf{%.2f~pb}.", rmse_m*1e4),
  sprintf("Errore sulla curva ECB (30/07/2026): \\textbf{%.2f~pb} con $k=1$, crolla a \\textbf{%.2f~pb} con $k=3$.",
          err_k[1], err_k[3])
), summary_file)
cat("File riepilogo scritto:", summary_file, "\n")

cat("\n=== COMPLETATO. File salvati in:", normalizePath(output_dir), "===\n")
