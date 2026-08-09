suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(ggplot2)
  library(lubridate)
  library(scales)
})

# ------------------------------------------------------------
#  PCA sulle VARIAZIONI MENSILI della curva dei tassi BCE
#  VERSIONE CALIBRAZIONE / VALIDAZIONE
#
#  A differenza di 04b_pca_ecb.R, che stima i loadings sull'intero
#  campione disponibile, qui la PCA e' calibrata SOLO sui dati fino al
#  31/12/2025. I loadings cosi' ottenuti vengono poi "congelati" e usati
#  per approssimare due curve che il modello non ha mai visto:
#     - 31/03/2026  (+3 mesi dalla data di calibrazione)
#     - 30/06/2026  (+6 mesi dalla data di calibrazione)
#
#  Input : ../dati/04_ecb_spot.xlsx (prodotto da 04_pca_ecb_prep.R)
#  Output: figure PDF e frammenti LaTeX in ../output/04_pca_ecb/
#
#  UNITA': i tassi sono convertiti in DECIMALI subito dopo la lettura
#  (2.592% -> 0.02592). La conversione avviene solo in fase di
#  visualizzazione:
#     livelli    * 100  -> percentuale
#     variazioni * 1e4  -> punti base
#
#  STRUTTURA DELLO SCRIPT (a fini didattici):
#     1. Elaborazione dei dati
#     2. Calcolo della PCA (solo campione di calibrazione)
#     3. Ricostruzione delle curve fuori campione (mar 2026, giu 2026)
#     4. Costruzione dei grafici
# ------------------------------------------------------------

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

input_xlsx <- "../dati/04_ecb_spot.xlsx"
output_dir <- "../output/04_pca_ecb"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Data di taglio del campione di calibrazione: tutto cio' che viene dopo
# e' fuori campione e serve solo come banco di prova.
data_calibrazione <- as.Date("2025-12-31")

# Le due curve target da approssimare con i loadings calibrati sopra.
data_target_1 <- as.Date("2026-03-31")   # +3 mesi
data_target_2 <- as.Date("2026-06-30")   # +6 mesi

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
monthly_full <- curve_df[, .SD[.N], by = YM, .SDcols = c("TIME_PERIOD", maturity_cols)]
setorder(monthly_full, YM)

cat("Serie mensile completa: ", nrow(monthly_full), " mesi (da ",
    format(min(monthly_full$TIME_PERIOD), "%b %Y"), " a ",
    format(max(monthly_full$TIME_PERIOD), "%b %Y"), ").\n", sep = "")

# ------------------------------------------------------------------
# TAGLIO CALIBRAZIONE / VALIDAZIONE
# monthly_full  -> tutta la serie, serve solo per pescare le curve target
# monthly_dt    -> campione di calibrazione, usato da tutto il resto
# ------------------------------------------------------------------
monthly_dt <- monthly_full[TIME_PERIOD <= data_calibrazione]

# Anche la serie giornaliera viene troncata: cosi' nessun grafico
# "di lezione" mostra dati successivi alla data di calibrazione.
curve_df <- curve_df[TIME_PERIOD <= data_calibrazione]

n_months      <- nrow(monthly_dt)
R_mat_m       <- as.matrix(monthly_dt[, ..maturity_cols])   # M x n
dates_m       <- monthly_dt$TIME_PERIOD                     # fine mese effettiva
Delta_R_m     <- diff(R_mat_m)                              # (M-1) x n
dates_delta_m <- dates_m[-1]

cat("Campione di CALIBRAZIONE: ", n_months, " mesi (da ",
    format(min(dates_m), "%b %Y"), " a ", format(max(dates_m), "%b %Y"), ").\n",
    sep = "")
cat("Variazioni mensili disponibili:", nrow(Delta_R_m), "\n")
cat("Mesi lasciati FUORI CAMPIONE:", nrow(monthly_full) - n_months, "\n")

monthly_dt[,anno := year(TIME_PERIOD)]
monthly_dt[,mese := month(TIME_PERIOD)]
monthly_dt[,periodo := paste0(anno,"_",mese)]


# ==============================================================
# SEZIONE 2: CALCOLO DELLA PCA (SOLO CAMPIONE DI CALIBRAZIONE)
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
cat("Varianza cumulata con k=3:", round(100 * cum_var[k], 2), "%\n")

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


#----- ricostruiamo delta di maggio 2015 (mese centrale del campione)

mese2       <- '2015_5'
row_number2 <- which(monthly_dt$periodo == mese2) -1 # in quanto in diff abbiamo tolto il valore iniziale
delta_dati2 <- Delta_R_m[row_number2,]

delta_ricostrito2<- xm + scores[row_number2,1]*loadings[,1]+scores[row_number2,2]*loadings[,2]+scores[row_number2,3]*loadings[,3]

confronto_maggio2015 <- data.table(maturity = maturity_num,
                                  x_m_originale = delta_dati2,
                                  x_m_ricostruito = delta_ricostrito2,
                                  delta_bp = (delta_ricostrito2 - delta_dati2)*1e4)

print(confronto_maggio2015)


#----- ricostruiamo delta di dicembre 2025 (ultimo mese del campione)

mese3       <- '2025_12'
row_number3 <- which(monthly_dt$periodo == mese3) -1 # in quanto in diff abbiamo tolto il valore iniziale
delta_dati3 <- Delta_R_m[row_number3,]

delta_ricostrito3<- xm + scores[row_number3,1]*loadings[,1] + scores[row_number3,2]*loadings[,2] + scores[row_number3,3]*loadings[,3]

confronto_dicembre2025 <- data.table(maturity = maturity_num,
                                    x_m_originale = delta_dati3,
                                    x_m_ricostruito = delta_ricostrito3,
                                    delta_bp = (delta_ricostrito3 - delta_dati3)*1e4)

print(confronto_dicembre2025)

cat("\nScores (pb) dei tre mesi selezionati:\n")
print(data.table(
  mese = c(mese1, mese2, mese3),
  PC1  = round(scores[c(row_number1, row_number2, row_number3), 1] * 1e4, 2),
  PC2  = round(scores[c(row_number1, row_number2, row_number3), 2] * 1e4, 2),
  PC3  = round(scores[c(row_number1, row_number2, row_number3), 3] * 1e4, 2)
))


#----- ricostruzione progressiva di maggio 2015
#
# Si usa il mese CENTRALE e non l'ultimo: a dicembre 2025 lo score PC2 vale
# circa -1.7 pb, quindi il contributo della pendenza sarebbe invisibile.
# Maggio 2015 ha invece tutti e tre i fattori ben marcati.

delta_ricostrito2_loading1     <- xm + scores[row_number2,1]*loadings[,1]
delta_ricostrito2_loading1_2   <- delta_ricostrito2_loading1 +scores[row_number2,2]*loadings[,2]
delta_ricostrito2_loading1_2_3 <- delta_ricostrito2_loading1_2 +scores[row_number2,3]*loadings[,3]


confronto_progressione_maggio2015 <- data.table(maturity = maturity_num,
                                  x_m_originale = delta_dati2,
                                  x_m_ricostruito_1     = delta_ricostrito2_loading1,
                                  x_m_ricostruito_1_2   = delta_ricostrito2_loading1_2,
                                  x_m_ricostruito_1_2_3 = delta_ricostrito2_loading1_2_3)


print(confronto_progressione_maggio2015)


# ==============================================================
# SEZIONE 3: RICOSTRUZIONE DELLE CURVE FUORI CAMPIONE
# ==============================================================
#
# Le colonne di V sono una base ortonormale di R^20: per k=n permettono di
# rappresentare ESATTAMENTE qualsiasi curva (non solo le variazioni su cui
# sono state stimate), e per k<n la proiezione P_k = V_k V_k^T ne da'
# un'approssimazione. Si proietta quindi direttamente la curva target, senza
# passare da un delta rispetto a una curva di riferimento.
#
# Nota: i loadings usati qui sono quelli calibrati nella Sezione 2, cioe'
# stimati su dati che si fermano al 31/12/2025. Le due curve seguenti sono
# posteriori a quella data: il modello non le ha mai viste.

cat("\n=== SEZIONE 3: RICOSTRUZIONE DELLE CURVE FUORI CAMPIONE ===\n")

curva_mar26      <- as.numeric(monthly_full[TIME_PERIOD==as.Date("2026-03-31"),maturity_cols,with = FALSE])
scores_mar26_k3  <- t(loadings) %*% curva_mar26
scores_mar26_k20 <- t(V) %*% curva_mar26
curva_mar_26_ricostruita_k3  <- as.numeric(loadings %*%  scores_mar26_k3)
curva_mar_26_ricostruita_k20  <- as.numeric(V %*%  scores_mar26_k20)

curva_jun26      <- as.numeric(monthly_full[TIME_PERIOD==as.Date("2026-06-30"),maturity_cols,with = FALSE])
scores_jun26_k3  <- t(loadings) %*% curva_jun26
scores_jun26_k20 <- t(V) %*% curva_jun26
curva_jun_26_ricostruita_k3  <- as.numeric(loadings %*%  scores_jun26_k3)
curva_jun_26_ricostruita_k20  <- as.numeric(V %*%  scores_jun26_k20)

ricostruzione_mar26 <- data.table(tenor = c(1:20),
                                  curva_mar26_orig = curva_mar26,
                                  curva_mar26_ricostruita_k3 = curva_mar_26_ricostruita_k3,
                                  curva_mar_26_ricostruita_k20 = curva_mar_26_ricostruita_k20,
                                  delta_k3  = curva_mar26 - curva_mar_26_ricostruita_k3,
                                  delta_k20 = curva_mar26 - curva_mar_26_ricostruita_k20)

ricostruzione_giu26 <- data.table(tenor = c(1:20),
                                  curva_jun26_orig = curva_jun26,
                                  curva_jun26_ricostruita_k3 = curva_jun_26_ricostruita_k3,
                                  curva_jun_26_ricostruita_k20 = curva_jun_26_ricostruita_k20,
                                  delta_k3  = curva_jun26 - curva_jun_26_ricostruita_k3,
                                  delta_k20 = curva_jun26 - curva_jun_26_ricostruita_k20)

# Errore di ricostruzione in norma L2 (bp) al variare del numero di
# componenti k = 1..n_mat: serve alla figura di convergenza (Sezione 4) e
# al riepilogo finale. Stessa proiezione V_k V_k^T usata sopra per k=3/k=20,
# qui applicata a ogni k.
errore_l2_per_k <- function(curva_orig) {
  sapply(1:n_mat, function(kk) {
    Vk  <- V[, 1:kk, drop = FALSE]
    ric <- as.numeric(Vk %*% (t(Vk) %*% curva_orig))
    sqrt(sum((ric - curva_orig)^2)) * 1e4
  })
}
err_k_mar26 <- errore_l2_per_k(curva_mar26)
err_k_giu26 <- errore_l2_per_k(curva_jun26)

# Verifica: con k=20 (= n_mat) la base V e' completa, quindi la
# ricostruzione deve coincidere ESATTAMENTE con la curva originale.
cat("Verifica k=20 = ricostruzione esatta (scarto max, mar26):",
    signif(max(abs(ricostruzione_mar26$delta_k20)), 3), "\n")
cat("Verifica k=20 = ricostruzione esatta (scarto max, giu26):",
    signif(max(abs(ricostruzione_giu26$delta_k20)), 3), "\n")

stampa_target <- function(data_target, dt_ricostruzione, scores_k3, err_k, etichetta_data) {
  cat("\n----- Curva target:", etichetta_data, "-----\n")
  cat("Orizzonte dalla calibrazione:",
      round(as.numeric(data_target - data_calibrazione) / 30.44), "mesi\n")
  cat("Scores (%) sui primi 3 loadings:",
      paste(round(scores_k3 * 100, 2), collapse = ", "), "\n")
  print(dt_ricostruzione)
  cat("\n--- Errore L2 di ricostruzione per numero di componenti (bp) ---\n")
  print(data.table(k = 1:n_mat, errore_bp = round(err_k, 2)))
}

stampa_target(data_target_1, ricostruzione_mar26, scores_mar26_k3, err_k_mar26, "31/03/2026")
stampa_target(data_target_2, ricostruzione_giu26, scores_jun26_k3, err_k_giu26, "30/06/2026")

cat("\n--- Confronto fra i due orizzonti (errore L2 in bp) ---\n")
print(data.table(
  k          = 1:n_mat,
  mar26_bp   = round(err_k_mar26, 2),
  giu26_bp   = round(err_k_giu26, 2)
))


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
# Grafico 0b — interpretazione geometrica della SVD (esempio 2x2)
# Illustra A = U Sigma V^T come composizione rotazione-scaling-rotazione.
# I vettori evidenziati sono v1, v2 (colonne di V, i loadings): sono
# esattamente le direzioni per cui vale A*v_i = sigma_i*u_i, cioe' quelle
# che A manda sui semiassi dell'ellisse. Dopo la rotazione V^T diventano
# esattamente gli assi coordinati e1, e2 (perche' V^T V = I).
#
# Nei due pannelli in alto sono inoltre tracciate, in modo volutamente
# discreto (rette grigie tratteggiate), le direzioni u1, u2 (colonne di U):
# sono gli assi su cui l'ellisse risulta orientata. Comparendo nella stessa
# posizione in entrambi i pannelli, rendono visibile che A ruota il
# riferimento da {v1,v2} a {u1,u2}.
# (Qui m = n = 2, quindi dominio e codominio sono lo stesso piano e i due
# riferimenti sono confrontabili; in generale u_i e v_i vivono in spazi
# diversi, R^m e R^n.)
#
# Output: output/04_pca_ecb/svd_geometria_esempio.pdf, condivisa anche
# dalla dispensa 04b (stesso percorso, illustrazione indipendente dal
# campione dati). Racchiusa in local({...}) per non sporcare l'ambiente
# globale con nomi (A, U, V, ...) gia' usati sotto per la PCA vera.
# Grafica base R (non ggplot2): un layout a griglia con pannelli e frecce
# di collegamento e' piu' semplice da comporre con layout()/arrows().
# ------------------------------------------------------------------
local({
  A <- matrix(c(1, 1,
                0, 1), nrow = 2, byrow = TRUE)

  sv    <- svd(A)
  U     <- sv$u
  d     <- sv$d
  V     <- sv$v
  Sigma <- diag(d)
  Vt    <- t(V)

  theta      <- seq(0, 2 * pi, length.out = 200)
  circle_pts <- rbind(cos(theta), sin(theta))

  v1 <- V[, 1]
  v2 <- V[, 2]

  outline_TL <- circle_pts
  outline_TR <- A %*% circle_pts
  outline_BL <- circle_pts
  outline_BR <- Sigma %*% circle_pts

  arrows_TL <- list(v1, v2)
  arrows_TR <- list(A %*% v1, A %*% v2)
  arrows_BL <- list(Vt %*% v1, Vt %*% v2)
  arrows_BR <- list(Sigma %*% (Vt %*% v1), Sigma %*% (Vt %*% v2))

  # Verifica: la rotazione V^T porta v1, v2 esattamente sugli assi coordinati.
  stopifnot(max(abs(arrows_BL[[1]] - c(1, 0))) < 1e-9)
  stopifnot(max(abs(arrows_BL[[2]] - c(0, 1))) < 1e-9)
  stopifnot(max(abs((U %*% arrows_BR[[1]]) - arrows_TR[[1]])) < 1e-9)
  stopifnot(max(abs((U %*% arrows_BR[[2]]) - arrows_TR[[2]])) < 1e-9)

  cross2 <- function(a, b) a[1] * b[2] - a[2] * b[1]
  stopifnot(abs(cross2(arrows_TR[[1]], U[, 1])) < 1e-9)
  stopifnot(abs(cross2(arrows_TR[[2]], U[, 2])) < 1e-9)

  col1  <- "#e6194B"
  col2  <- "#b8860b"
  col_u <- "grey45"

  draw_panel <- function(outline, arrows, title, dir_lines = NULL,
                         dir_labels = NULL) {
    lim <- max(abs(outline), abs(unlist(arrows))) * 1.25
    plot(NA, xlim = c(-lim, lim), ylim = c(-lim, lim), asp = 1,
         xlab = "", ylab = "", axes = FALSE, main = title, cex.main = 1.05)
    box(col = "grey60")
    abline(h = 0, v = 0, col = "grey85")

    if (!is.null(dir_lines)) {
      for (j in seq_along(dir_lines)) {
        dj <- dir_lines[[j]] / sqrt(sum(dir_lines[[j]]^2))
        t_max <- 2 * lim
        segments(-t_max * dj[1], -t_max * dj[2],
                  t_max * dj[1],  t_max * dj[2],
                 col = col_u, lty = 2, lwd = 1)
        if (!is.null(dir_labels)) {
          text(0.93 * lim * dj[1], 0.93 * lim * dj[2], dir_labels[j],
               col = col_u, cex = 0.85, font = 3)
        }
      }
    }

    lines(outline[1, ], outline[2, ], col = "#4575b4", lwd = 2.2)
    arrows(0, 0, arrows[[1]][1], arrows[[1]][2], col = col1, lwd = 2.4, length = 0.1)
    arrows(0, 0, arrows[[2]][1], arrows[[2]][2], col = col2, lwd = 2.4, length = 0.1)
  }

  draw_arrow_panel <- function(label, direction = c("right", "down", "up")) {
    direction <- match.arg(direction)
    plot(NA, xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
    switch(direction,
      right = { arrows(0.05, 0.5, 0.9, 0.5, lwd = 2.2, length = 0.14, col = "grey25")
                text(0.47, 0.72, label, font = 3, cex = 1.4) },
      down  = { arrows(0.5, 0.9, 0.5, 0.1, lwd = 2.2, length = 0.14, col = "grey25")
                text(0.78, 0.5, label, font = 3, cex = 1.4) },
      up    = { arrows(0.5, 0.1, 0.5, 0.9, lwd = 2.2, length = 0.14, col = "grey25")
                text(0.78, 0.5, label, font = 3, cex = 1.4) }
    )
  }

  pdf_file <- file.path(output_dir, "svd_geometria_esempio.pdf")
  grDevices::cairo_pdf(pdf_file, width = 8.5, height = 8.5)

  mat <- matrix(c(1, 2, 3,
                  4, 5, 6,
                  7, 8, 9), nrow = 3, byrow = TRUE)
  layout(mat, widths = c(3, 1, 3), heights = c(3, 1, 3))
  par(oma = c(0, 0, 0, 0), mar = c(1, 1, 2.5, 1))

  draw_panel(outline_TL, arrows_TL, "Direzioni v1, v2",
             dir_lines  = list(U[, 1], U[, 2]),
             dir_labels = c("u1", "u2"))
  draw_arrow_panel("A", "right")
  draw_panel(outline_TR, arrows_TR, "Immagine sotto A",
             dir_lines  = list(U[, 1], U[, 2]),
             dir_labels = c("u1", "u2"))

  draw_arrow_panel(expression(V^T), "down")
  plot.new()
  draw_arrow_panel("U", "up")

  draw_panel(outline_BL, arrows_BL, expression(paste("Dopo ", V^T, " (rotazione): v1,v2 -> e1,e2")))
  draw_arrow_panel(expression(Sigma), "right")
  draw_panel(outline_BR, arrows_BR, expression(paste("Dopo ", Sigma, " (scaling)")))

  grDevices::dev.off()
  cat("Figura SVD geometrica salvata:", pdf_file, "\n")
})

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
       y = "Variazione mensile (punti base)") +
  plot_theme
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
  labs(title = "Varianza spiegata per componente e varianza cumulata",
       x = "Componente principale", y = "Quota di varianza") +
  plot_theme
ggsave(file.path(output_dir, "step2_varianza_spiegata_m.pdf"),
       g4, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 5 — loadings delle prime tre componenti
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
  labs(title = "Loadings delle prime tre componenti (livello, pendenza, curvatura)",
       x = "Scadenza (anni)", y = "Loading") +
  plot_theme
ggsave(file.path(output_dir, "step3_loadings_pc1_pc3_m.pdf"),
       g5, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 6 — scores mensili con media mobile centrata a 7 mesi ed eventi macro
# ------------------------------------------------------------------
scores_dt <- data.table()
for (i in 1:k) {
  scores_dt <- rbind(scores_dt, data.table(
    TIME_PERIOD = dates_delta_m,
    Score       = scores[, i] * 1e4,      # in punti base
    PC          = paste0("PC", i)
  ))
}
# Media mobile CENTRATA (finestra simmetrica di 7 mesi: 3 prima, 3 dopo).
# Una media mobile "right-aligned" ritarderebbe di circa 3 mesi rispetto
# agli eventi, disallineando visivamente la linea dai periodi evidenziati.
scores_dt[, ScoreMA := data.table::frollmean(Score, n = 7, align = "center"), by = PC]

# Fasce: periodo in cui il MERCATO ha incorporato l'evento. Per i cicli di
# rialzo la fascia parte dai mesi di attesa, non dalla prima decisione BCE:
# i tassi si muovono in anticipo (cfr. commento nella dispensa).
# Per il QE si evidenzia il solo 2014, l'anno in cui il mercato ha prezzato
# il programma: e' li' che PC1 e' nettamente negativo, mentre nei quattro
# anni di acquisti effettivi e' indistinguibile da zero. Una fascia per
# ciascuno dei quattro eventi discussi nel testo.
key_periods <- data.table(
  start = as.Date(c("2008-09-01", "2010-09-01", "2014-01-01", "2021-12-01")),
  end   = as.Date(c("2009-02-28", "2011-07-31", "2014-12-31", "2023-09-30")),
  label = c("Lehman\n(2008-2009)", "Attese e rialzi BCE\n(2010-2011)",
            "Attese QE\n(2014)", "Rialzi BCE anti-inflazione\n(2021-2023)"),
  alpha_v = c(0.15, 0.15, 0.15, 0.15)
)
key_periods[, mid := start + (end - start) / 2]

g6 <- ggplot(scores_dt, aes(x = TIME_PERIOD)) +
  geom_rect(data = key_periods,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, alpha = alpha_v),
            fill = "grey50", inherit.aes = FALSE) +
  scale_alpha_identity() +
  geom_line(aes(y = Score), linewidth = 0.5, color = "#a6bddb") +
  geom_line(aes(y = ScoreMA), linewidth = 1, color = "#045a8d", na.rm = TRUE) +
  geom_label(data = key_periods[, c(.SD, list(PC = "PC1"))],
             aes(x = mid, y = Inf, label = label),
             inherit.aes = FALSE, vjust = 1.05, hjust = 0.5, size = 2.5,
             fill = "white", label.size = 0.2, label.padding = unit(0.15, "lines")) +
  facet_wrap(~PC, ncol = 1, scales = "free_y",
             labeller = labeller(PC = c(PC1 = "PC1 - Livello",
                                        PC2 = "PC2 - Pendenza",
                                        PC3 = "PC3 - Curvatura"))) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expansion(0.01)) +
  labs(title = "Scores mensili: serie grezza vs media mobile centrata",
       x = NULL, y = "Score (punti base)") +
  plot_theme +
  theme(strip.text = element_text(face = "bold"), legend.position = "none",
        axis.text.x = element_text(size = 7.5, angle = 45, hjust = 1))
ggsave(file.path(output_dir, "step3_scores_mensili_ma_m.pdf"),
       g6, width = 11, height = 9, device = cairo_pdf)
cat("Grafico scores con media mobile salvato.\n")

# ------------------------------------------------------------------
# Grafico 6b — serie storica dei livelli per alcune scadenze
# Pensato per essere letto accanto al Grafico 6: stesse fasce, stesso asse
# temporale. Gli scores dicono di QUANTO si e' mosso ciascun fattore, questo
# grafico dice DOVE sono finiti i tassi.
# ------------------------------------------------------------------
tenor_sel <- c(1, 5, 10, 15, 20)

serie_dt <- rbindlist(lapply(tenor_sel, function(tt) data.table(
  TIME_PERIOD = dates_m,
  Tenor       = paste0(tt, "Y"),
  Tasso       = R_mat_m[, tt] * 100
)))
serie_dt[, Tenor := factor(Tenor, levels = paste0(tenor_sel, "Y"))]

g6b <- ggplot(serie_dt, aes(x = TIME_PERIOD, y = Tasso, colour = Tenor)) +
  geom_rect(data = key_periods,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, alpha = alpha_v),
            fill = "grey50", inherit.aes = FALSE) +
  scale_alpha_identity() +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.4) +
  geom_line(linewidth = 0.8) +
  geom_label(data = key_periods, aes(x = mid, y = Inf, label = label),
             inherit.aes = FALSE, vjust = 1.05, hjust = 0.5, size = 2.5,
             fill = "white", label.size = 0.2, label.padding = unit(0.15, "lines")) +
  scale_colour_viridis_d(end = 0.9, direction = -1) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expansion(0.01)) +
  scale_y_continuous(labels = label_number(suffix = "%", accuracy = 0.1)) +
  labs(title = "Serie storica dei tassi per scadenze selezionate",
       x = NULL, y = "Tasso (%)", colour = "Scadenza") +
  plot_theme +
  theme(axis.text.x = element_text(size = 7.5, angle = 45, hjust = 1))
ggsave(file.path(output_dir, "step3_serie_storica_tenor.pdf"),
       g6b, width = 11, height = 6, device = cairo_pdf)
cat("Grafico serie storica per tenor salvato.\n")

# ------------------------------------------------------------------
# Grafico 7 — confronto osservata vs ricostruita sui tre mesi
# Grafico 8 — errore di ricostruzione per singola scadenza
# ------------------------------------------------------------------
etichetta1 <- paste0("Primo mese: ",    format(dates_delta_m[row_number1], "%b %Y"))
etichetta2 <- paste0("Mese centrale: ", format(dates_delta_m[row_number2], "%b %Y"))
etichetta3 <- paste0("Ultimo mese: ",   format(dates_delta_m[row_number3], "%b %Y"))

ricostruzione_dt <- rbind(
  data.table(Mese = etichetta1, MAT_NUM = maturity_num, Serie = "Osservata",           DeltaRate = delta_dati1),
  data.table(Mese = etichetta1, MAT_NUM = maturity_num, Serie = "Ricostruita (k = 3)", DeltaRate = delta_ricostrito),
  data.table(Mese = etichetta2, MAT_NUM = maturity_num, Serie = "Osservata",           DeltaRate = delta_dati2),
  data.table(Mese = etichetta2, MAT_NUM = maturity_num, Serie = "Ricostruita (k = 3)", DeltaRate = delta_ricostrito2),
  data.table(Mese = etichetta3, MAT_NUM = maturity_num, Serie = "Osservata",           DeltaRate = delta_dati3),
  data.table(Mese = etichetta3, MAT_NUM = maturity_num, Serie = "Ricostruita (k = 3)", DeltaRate = delta_ricostrito3)
)
ricostruzione_dt[, Mese := factor(Mese, levels = c(etichetta1, etichetta2, etichetta3))]

g7 <- ggplot(ricostruzione_dt, aes(x = MAT_NUM, y = DeltaRate * 1e4,
                                   color = Serie, linetype = Serie)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line(linewidth = 1.1) + geom_point(size = 1.6) +
  scale_color_manual(values = c("Osservata" = "#000000",
                                "Ricostruita (k = 3)" = "#d73027")) +
  scale_linetype_manual(values = c("Osservata" = "solid",
                                   "Ricostruita (k = 3)" = "dashed")) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  facet_wrap(~Mese, ncol = 1, scales = "free_y") +
  labs(title = "Variazione mensile osservata vs ricostruita (k = 3)",
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
  labs(title = "Errore di ricostruzione per scadenza (k = 3)",
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
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito2_loading1,     Serie = lbl_k1),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito2_loading1_2,   Serie = lbl_k2),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_ricostrito2_loading1_2_3, Serie = lbl_k3),
  data.table(MAT_NUM = maturity_num, DeltaRate = delta_dati2,                    Serie = "Reale")
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
# Figure dei target fuori campione — tre per ciascuna curva:
#   1) confronto originale / k=3 / k=n
#   2) errore per singola scadenza a k=3 (barre)
#   3) convergenza dell'errore L2, scala LINEARE fino a k=20
# ------------------------------------------------------------------
figure_target <- function(curva_orig, ric_k3, ric_k20, err_k, tag, etichetta_data) {

  # --- Figura 1: confronto curve -----------------------------------
  et_orig <- paste0("Curva ECB ", etichetta_data, " (originale)")
  et_k3   <- "Ricostruita con k=3"
  et_kn   <- paste0("Ricostruita con k=", n_mat, " (esatta)")
  liv     <- c(et_orig, et_k3, et_kn)

  curve_dt <- rbind(
    data.table(MAT_NUM = maturity_num, Valore = curva_orig*100, Tipo = et_orig),
    data.table(MAT_NUM = maturity_num, Valore = ric_k3*100,     Tipo = et_k3),
    data.table(MAT_NUM = maturity_num, Valore = ric_k20*100,    Tipo = et_kn)
  )
  curve_dt[, Tipo := factor(Tipo, levels = liv)]

  g_a <- ggplot(curve_dt, aes(x = MAT_NUM, y = Valore, colour = Tipo, linetype = Tipo)) +
    geom_line(linewidth = 1.1) +
    geom_point(data = curve_dt[Tipo == et_orig], size = 2.2) +
    scale_colour_manual(values = setNames(c("#000000","#1a9850","#e66101"), liv)) +
    scale_linetype_manual(values = setNames(c("solid","dashed","dotted"), liv)) +
    scale_x_continuous(breaks = seq(1, n_mat, by = 2)) +
    scale_y_continuous(labels = label_number(suffix = "%", accuracy = 0.01)) +
    labs(title = paste0("Ricostruzione PCA della curva ECB (", etichetta_data, ")"),
         x = "Scadenza (anni)", y = "Tasso (%)", colour = NULL, linetype = NULL) +
    plot_theme
  ggsave(file.path(output_dir, paste0("sez4_", tag, "_curva.pdf")),
         g_a, width = 9, height = 5, device = cairo_pdf)

  # --- Figura 2: errore per scadenza a k=3 -------------------------
  err_tenor_dt <- data.table(MAT_NUM = maturity_num,
                             Errore_bp = (ric_k3 - curva_orig) * 1e4)

  g_b <- ggplot(err_tenor_dt, aes(x = factor(MAT_NUM), y = Errore_bp)) +
    geom_col(fill = "#1a9850", width = 0.65) +
    geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
    labs(title = paste0("Errore di ricostruzione per scadenza, k = 3 (",
                        etichetta_data, ")"),
         x = "Scadenza (anni)", y = "Errore (punti base)") +
    plot_theme
  ggsave(file.path(output_dir, paste0("sez4_", tag, "_errore_tenor.pdf")),
         g_b, width = 9, height = 5, device = cairo_pdf)

  # --- Figura 3: convergenza dell'errore, scala lineare ------------
  conv_dt <- data.table(k = 1:n_mat, Errore_bp = err_k)
  ann_dt  <- data.table(k = 3L, y_pos = err_k[3],
                        label = sprintf("k=3\n%.1f bp", err_k[3]))

  g_c <- ggplot(conv_dt, aes(x = k, y = Errore_bp)) +
    geom_line(colour = "#1a9850", linewidth = 1.05) +
    geom_point(colour = "#1a9850", size = 2.1) +
    geom_point(data = ann_dt, aes(x = k, y = y_pos), colour = "tomato", size = 3.4) +
    geom_label(data = ann_dt, aes(x = k, y = y_pos, label = label),
               nudge_x = 2.2, nudge_y = 8, size = 3, colour = "tomato",
               fill = "white", label.size = 0.3, label.padding = unit(0.2, "lines")) +
    scale_x_continuous(breaks = 1:n_mat) +
    scale_y_continuous(labels = label_number(accuracy = 0.1, suffix = " bp")) +
    labs(title = paste0("Convergenza dell'errore di ricostruzione (",
                        etichetta_data, ")"),
         x = "Numero di componenti principali k",
         y = "Errore in norma euclidea (punti base)") +
    plot_theme
  ggsave(file.path(output_dir, paste0("sez4_", tag, "_convergenza.pdf")),
         g_c, width = 9, height = 5, device = cairo_pdf)

  cat("Figure del target", etichetta_data, "salvate (tag:", tag, ").\n")
}

figure_target(curva_mar26, curva_mar_26_ricostruita_k3, curva_mar_26_ricostruita_k20,
              err_k_mar26, "mar26", "31/03/2026")
figure_target(curva_jun26, curva_jun_26_ricostruita_k3, curva_jun_26_ricostruita_k20,
              err_k_giu26, "giu26", "30/06/2026")

# ------------------------------------------------------------------
# Grafico 10 — confronto diretto della convergenza sui due orizzonti
# ------------------------------------------------------------------
liv_target <- c("31/03/2026  (+3 mesi)", "30/06/2026  (+6 mesi)")
conf_dt <- rbind(
  data.table(k = 1:n_mat, Errore_bp = err_k_mar26, Target = liv_target[1]),
  data.table(k = 1:n_mat, Errore_bp = err_k_giu26, Target = liv_target[2])
)
# Ordine esplicito: l'orizzonte piu' corto per primo in legenda
conf_dt[, Target := factor(Target, levels = liv_target)]

g10 <- ggplot(conf_dt, aes(x = k, y = Errore_bp, colour = Target, shape = Target)) +
  geom_line(linewidth = 1.05) +
  geom_point(size = 2.1) +
  scale_colour_manual(values = setNames(c("#4575b4", "#d73027"), liv_target)) +
  scale_x_continuous(breaks = 1:n_mat) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, suffix = " bp")) +
  labs(title = "Convergenza dell'errore: confronto fra i due orizzonti",
       x = "Numero di componenti principali k",
       y = "Errore in norma euclidea (punti base)", colour = NULL, shape = NULL) +
  plot_theme
ggsave(file.path(output_dir, "sez4_confronto_orizzonti.pdf"),
       g10, width = 9, height = 5, device = cairo_pdf)
cat("Grafico confronto orizzonti salvato.\n")


# ==============================================================
# Frammenti LaTeX per la dispensa
# ==============================================================

# Tabella verticale: una riga per scadenza, cosi' non serve resizebox
scrivi_tabella <- function(curva_orig, ric_k3, tag, etichetta_data) {
  righe <- sprintf("%dY & %.3f & %.3f & %+.2f \\\\",
                   maturity_num, curva_orig*100, ric_k3*100,
                   (ric_k3 - curva_orig)*1e4)
  f <- file.path(output_dir, paste0("sez4_tabella_", tag, ".tex"))
  writeLines(c(
    "\\begin{center}",
    "\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{c c c c}",
    "\\toprule",
    "Scadenza & Curva ECB (\\%) & Ricostruita $k=3$ (\\%) & Errore $k=3$ (bp) \\\\",
    "\\midrule",
    righe,
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{center}"
  ), f)
  cat("Tabella salvata:", f, "\n")
}

scrivi_tabella(curva_mar26, curva_mar_26_ricostruita_k3, "mar26", "31/03/2026")
scrivi_tabella(curva_jun26, curva_jun_26_ricostruita_k3, "giu26", "30/06/2026")

# Riepilogo numerico
summary_file <- file.path(output_dir, "pca_summary_oos.tex")
writeLines(c(
  sprintf("Campione di calibrazione: \\textbf{%d} mesi (fino al %s) e \\textbf{%d} maturity.",
          n_months, format(data_calibrazione, "%d/%m/%Y"), n_mat),
  sprintf("Varianza spiegata PC1--PC3: \\textbf{%.2f\\%%, %.2f\\%%, %.2f\\%%} ($\\eta_3 = %.2f\\%%$).",
          100*expl_var[1], 100*expl_var[2], 100*expl_var[3], 100*cum_var[3]),
  sprintf("RMSE della ricostruzione in campione con $k=3$: \\textbf{%.2f~pb}.", rmse_m*1e4),
  sprintf("Errore fuori campione con $k=3$: \\textbf{%.2f~pb} sulla curva del 31/03/2026 e \\textbf{%.2f~pb} su quella del 30/06/2026.",
          err_k_mar26[3], err_k_giu26[3])
), summary_file)
cat("File riepilogo scritto:", summary_file, "\n")

cat("\n=== COMPLETATO. File salvati in:", normalizePath(output_dir), "===\n")
