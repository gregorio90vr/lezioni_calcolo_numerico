suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(ggplot2)
  library(lubridate)
  library(scales)
})

# ------------------------------------------------------------
#  PCA sulle VARIAZIONI MENSILI della curva dei tassi BCE
#  Nuova versione: aggregazione all'ultima rilevazione mensile
#  Input: stesso file Excel di lezione_pca_3step.R
#  Output: file PDF in ../output/04_pca_ecb/ con suffisso _m
# ------------------------------------------------------------

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

input_xlsx <- "../dati/pca_input_curves_1Y_20Y.xlsx"
output_dir <- "../output/04_pca_ecb"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

plot_theme <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    legend.position  = "bottom"
  )

if (!file.exists(input_xlsx)) {
  stop(paste0("File non trovato: ", input_xlsx,
              "\nEsegui prima 04_pca_ecb_prep.R oppure verifica il percorso."))
}

# ==============================================================
# STEP 1 — Lettura, pulizia e aggregazione mensile
# ==============================================================

cat("\n=== STEP 1: LETTURA, PULIZIA E AGGREGAZIONE MENSILE ===\n")

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

# Riconosce le maturity
maturity_cols <- grep("^([1-9]|1[0-9]|20)Y$", names(curve_df), value = TRUE)
if (length(maturity_cols) < 3L)
  stop("Trovate meno di 3 maturity: impossibile costruire una PCA robusta.")
maturity_num  <- as.integer(sub("Y$", "", maturity_cols))
maturity_cols <- maturity_cols[order(maturity_num)]

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

for (cc in maturity_cols) curve_df[, (cc) := as.numeric(get(cc))]

# Rimuovi righe quasi vuote e interpola NA isolati
valid_rows <- rowSums(!is.na(curve_df[, ..maturity_cols])) >= 3L
curve_df   <- curve_df[valid_rows, c("TIME_PERIOD", maturity_cols), with = FALSE]
setorder(curve_df, TIME_PERIOD)

for (cc in maturity_cols) {
  x <- curve_df[[cc]]
  if (anyNA(x)) {
    ok <- which(!is.na(x))
    if (length(ok) >= 2L)
      curve_df[[cc]] <- approx(ok, x[ok], seq_along(x), rule = 2L)$y
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
dates_m      <- monthly_dt$YM                               # date mese
Delta_R_m    <- diff(R_mat_m)                               # (M-1) x n
dates_delta_m <- dates_m[-1]

cat("Aggregazione mensile: ", n_months, " mesi (da ",
    format(min(dates_m), "%b %Y"), " a ", format(max(dates_m), "%b %Y"), ").\n",
    sep = "")
cat("Variazioni mensili disponibili:", nrow(Delta_R_m), "\n")

# ------------------------------------------------------------------
# Grafico 1: curve dei livelli in 3 date rappresentative
# ------------------------------------------------------------------
sel_idx <- unique(round(c(1, n_months / 2, n_months)))
plot_curves_dt <- rbindlist(lapply(sel_idx, function(i) {
  data.table(Data    = format(monthly_dt$TIME_PERIOD[i], "%b %Y"),
             Maturity = maturity_cols,
             MAT_NUM  = as.integer(sub("Y$", "", maturity_cols)),
             Rate     = as.numeric(R_mat_m[i, ]))
}))

p1 <- ggplot(plot_curves_dt, aes(x = MAT_NUM, y = Rate, color = Data, group = Data)) +
  geom_line(linewidth = 1) + geom_point(size = 1.7) +
  labs(title = "STEP 1 — Curve dei tassi in 3 mesi rappresentativi",
       x = "Scadenza (anni)", y = "Tasso (%)", color = "Mese") +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.01)) +
  plot_theme
ggsave(file.path(output_dir, "step1_curve_livelli_m.pdf"),
       p1, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 2: boxplot delle variazioni MENSILI per maturity
# Con variazioni mensili i boxplot mostrano distribuzioni ben visibili
# (range tipico 20-80 bp) invece del rumore giornaliero (1-4 bp)
# ------------------------------------------------------------------
delta_m_dt <- as.data.table(Delta_R_m)
setnames(delta_m_dt, maturity_cols)
delta_m_dt[, TIME_PERIOD := dates_delta_m]
delta_m_long <- melt(delta_m_dt, id.vars = "TIME_PERIOD",
                     measure.vars = maturity_cols,
                     variable.name = "MATURITY", value.name = "DeltaRate")
delta_m_long[, MAT_NUM := as.integer(sub("Y$", "", MATURITY))]

p2 <- ggplot(delta_m_long, aes(x = factor(MAT_NUM), y = DeltaRate * 100)) +
  geom_hline(yintercept = 0, color = "grey40", linetype = "dashed") +
  geom_boxplot(fill = "#4575b4", alpha = 0.55,
               outlier.size = 0.7, outlier.alpha = 0.4, width = 0.65) +
  labs(title = "STEP 1 — Distribuzione delle variazioni mensili per scadenza",
       x = "Scadenza (anni)",
       y = "Variazione mensile (punti base)",
       caption = "Scatola: 25°–75° percentile; baffi: 1.5×IQR; punti: outlier.\n1 pb = 0.01%. Le variazioni mensili sono tipicamente 10–80 pb, ben visibili.") +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  plot_theme +
  theme(plot.caption = element_text(size = 8, color = "grey50"))
ggsave(file.path(output_dir, "step1_delta_mensili.pdf"),
       p2, width = 10, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 3: heatmap correlazione (su dati mensili)
# ------------------------------------------------------------------
cor_mat <- cor(Delta_R_m, use = "pairwise.complete.obs")
cor_dt  <- as.data.table(as.table(cor_mat))
setnames(cor_dt, c("MAT_X", "MAT_Y", "CORR"))
cor_dt[, MAT_XN := as.integer(sub("Y$", "", MAT_X))]
cor_dt[, MAT_YN := as.integer(sub("Y$", "", MAT_Y))]

p3 <- ggplot(cor_dt, aes(x = MAT_XN, y = MAT_YN, fill = CORR)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "STEP 1 — Correlazione tra variazioni mensili",
       x = "Scadenza X (anni)", y = "Scadenza Y (anni)", fill = "Corr") +
  coord_fixed() + plot_theme
ggsave(file.path(output_dir, "step1_heatmap_correlazioni_m.pdf"),
       p3, width = 7, height = 6, device = cairo_pdf)

# ------------------------------------------------------------------
# Grafico 3b (opzionale): correlazioni in 3D a barre
# Richiede il pacchetto plot3D; se non presente, il resto dello script continua.
# ------------------------------------------------------------------
if (requireNamespace("plot3D", quietly = TRUE)) {
  corr_cols <- colorRampPalette(c("#2c7bb6", "#ffffbf", "#d7191c"))(120)

  # Zoom verticale sul range osservato per evitare un grafico "schiacciato"
  corr_rng <- range(cor_mat, na.rm = TRUE)
  corr_pad <- max(0.01, 0.08 * diff(corr_rng))
  zlim_zoom <- c(max(-1, corr_rng[1] - corr_pad),
                 min(1, corr_rng[2] + corr_pad))
  corr_breaks <- seq(zlim_zoom[1], zlim_zoom[2], length.out = 121)

  # Esagerazione verticale forte per rendere leggibile l'asse Z
  z_expand <- if (diff(zlim_zoom) < 0.18) 28 else 28/2

  grDevices::cairo_pdf(file.path(output_dir, "step1_correlazioni_3d_barre_m.pdf"),
                       width = 10, height = 8.5)
  
  # Margini personalizzati per evitare sovrapposizioni
  par(mar = c(3, 3, 3, 3), oma = c(0, 0, 0, 4))
  
  plot3D::hist3D(
    x = sort(unique(cor_dt$MAT_XN)),
    y = sort(unique(cor_dt$MAT_YN)),
    z = cor_mat,
    colvar = cor_mat,
    col = corr_cols,
    breaks = corr_breaks,
    border = "grey40",
    shade = 0.3,
    lighting = TRUE,
    theta = 42,
    phi = 30,
    d = 2.5,
    scale = FALSE,
    expand = z_expand,
    ticktype = "detailed",
    xlab = "Scadenza X (anni)",
    ylab = "Scadenza Y (anni)",
    zlab = "Correlazione",
    zlim = zlim_zoom,
    main = "Correlazioni mensili (3D zoom)",
    cex.main = 1.15,
    cex.lab = 0.95,
    cex.axis = 0.85,
    colkey = FALSE
  )
  grDevices::dev.off()
  cat("Grafico 3D correlazioni salvato (plot3D).\n")
} else {
  cat("Pacchetto 'plot3D' non trovato: salto il grafico 3D correlazioni.\n")
}

# ==============================================================
# STEP 2 — PCA tramite SVD
# ==============================================================

cat("\n=== STEP 2: PCA CON SVD (DATI MENSILI) ===\n")

X_m       <- scale(Delta_R_m, center = TRUE, scale = FALSE) #toglie la media (center = TRUE), ma non divide per la std per rendere varianza a 1. (scale = FALSE)
sv_m      <- svd(X_m)
sing_vals <- sv_m$d
expl_var  <- sing_vals^2 / sum(sing_vals^2)
cum_var   <- cumsum(expl_var)
k_star    <- which(cum_var >= 0.95)[1L]
k_show    <- min(3L, ncol(X_m))

cat("Componenti per >=95% varianza:", k_star, "\n")
cat("Varianza spiegata prime", k_show, "componenti:",
    paste(round(100 * expl_var[1:k_show], 2), "%", collapse = ", "), "\n")

expl_dt <- data.table(PC = seq_along(expl_var),
                      ExplVar = expl_var, CumVar = cum_var)

p4 <- ggplot(expl_dt, aes(x = PC)) +
  geom_col(aes(y = ExplVar), fill = "#4575b4", alpha = 0.85) +
  geom_line(aes(y = CumVar), color = "#d73027", linewidth = 1) +
  geom_point(aes(y = CumVar), color = "#d73027", size = 1.6) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "#555555") +
  scale_y_continuous(labels = label_percent()) +
  labs(title = "STEP 2 — Scree plot e varianza cumulata (mensile)",
       x = "Componente principale", y = "Quota di varianza") +
  plot_theme
ggsave(file.path(output_dir, "step2_varianza_spiegata_m.pdf"),
       p4, width = 9, height = 5, device = cairo_pdf)

# ==============================================================
# STEP 3 — Interpretazione, scores con eventi, ricostruzione
# ==============================================================

cat("\n=== STEP 3: INTERPRETAZIONE E RICOSTRUZIONE (MENSILE) ===\n")

# ------------------------------------------------------------------
# Loadings
# ------------------------------------------------------------------
V_m <- sv_m$v
loadings_dt <- rbindlist(lapply(1:k_show, function(i) {
  data.table(MAT_NUM = as.integer(sub("Y$", "", maturity_cols)),
             Loading = V_m[, i], PC = paste0("PC", i))
}))

p5 <- ggplot(loadings_dt, aes(x = MAT_NUM, y = Loading, color = PC)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line(linewidth = 1) + geom_point(size = 1.4) +
  labs(title = "STEP 3 — Loadings delle prime componenti (livello/pendenza/curvatura)",
       x = "Scadenza (anni)", y = "Loading") +
  plot_theme
ggsave(file.path(output_dir, "step3_loadings_pc1_pc3_m.pdf"),
       p5, width = 9, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Scores mensili con annotazione eventi BCE/macroeconomici
# ------------------------------------------------------------------
scores_m <- sv_m$u[, 1:k_show, drop = FALSE] %*% diag(sv_m$d[1:k_show], nrow = k_show)

scores_dt_m <- rbindlist(lapply(1:k_show, function(i) {
  data.table(TIME_PERIOD = dates_delta_m, Score = scores_m[, i],
             PC = paste0("PC", i))
}))

# Definizione degli eventi macroeconomici chiave
# (corrispondenza con la data mensile più vicina nel campione)
key_events <- data.table(
  date  = as.Date(c("2008-10-01", "2012-07-01", "2015-01-01",
                    "2020-03-01", "2022-07-01")),
  label = c("Lehman\n(ott. 2008)", "Draghi\n(lug. 2012)",
            "QE BCE\n(gen. 2015)", "COVID\n(mar. 2020)",
            "Rialzi BCE\n(lug. 2022)")
)
key_events[, matched_date := {
  sapply(date, function(d)
    dates_delta_m[which.min(abs(as.numeric(dates_delta_m - d)))])
}]
key_events[, matched_date := as.Date(matched_date, origin = "1970-01-01")]

# Score PC1 nei mesi degli eventi (per posizionare le label sull'asse y)
pc1_dt <- scores_dt_m[PC == "PC1"]
key_events[, score_at_event := {
  sapply(matched_date, function(d)
    pc1_dt$Score[which.min(abs(as.numeric(pc1_dt$TIME_PERIOD - d)))])
}]

p6 <- ggplot(scores_dt_m, aes(x = TIME_PERIOD, y = Score)) +
  geom_line(linewidth = 0.7, color = "#4575b4") +
  geom_vline(data = key_events,
             aes(xintercept = matched_date),
             linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_label(data = key_events[, c(.SD, list(PC = "PC1"))],
             aes(x = matched_date, y = Inf, label = label),
             inherit.aes = FALSE,
             vjust = 1.05, hjust = 0.5, size = 2.5,
             fill = "white", label.size = 0.2, label.padding = unit(0.15, "lines")) +
  facet_wrap(~PC, ncol = 1, scales = "free_y",
             labeller = labeller(PC = c(PC1 = "PC1 — Livello",
                                        PC2 = "PC2 — Pendenza",
                                        PC3 = "PC3 — Curvatura"))) +
  labs(title = "STEP 3 — Scores mensili con eventi macroeconomici",
       subtitle = paste0("Dati: ", format(min(dates_delta_m), "%b %Y"),
                         " — ", format(max(dates_delta_m), "%b %Y")),
       x = NULL, y = "Score") +
  plot_theme +
  theme(strip.text = element_text(face = "bold"),
        legend.position = "none")
ggsave(file.path(output_dir, "step3_scores_mensili_m.pdf"),
       p6, width = 11, height = 9, device = cairo_pdf)
cat("Grafico scores con eventi salvato.\n")

# ------------------------------------------------------------------
# Ricostruzione su mesi rappresentativi:
# primo, centrale, ultimo mese del campione
# tramite scores/loadings (X_hat = Scores * t(Loadings))
# ------------------------------------------------------------------
k_rec       <- k_show
scores_k_m  <- sv_m$u[, 1:k_rec, drop = FALSE] %*%
                diag(sv_m$d[1:k_rec], nrow = k_rec)
loadings_k_m <- sv_m$v[, 1:k_rec, drop = FALSE]
X_hat_m     <- scores_k_m %*% t(loadings_k_m)

rmse_m      <- sqrt(mean((X_m - X_hat_m)^2, na.rm = TRUE))
cat("RMSE ricostruzione con k=3 (mensile):", signif(rmse_m, 4), "\n")

row_norms   <- sqrt(rowSums(Delta_R_m^2))
sel_months  <- data.table(
  Tipo = c("Primo mese", "Mese centrale", "Ultimo mese"),
  IDX  = c(1L, ceiling(nrow(Delta_R_m) / 2), nrow(Delta_R_m))
)[!duplicated(IDX)]
sel_months[, YM := dates_delta_m[IDX]]
sel_months[, Norma_pb := row_norms[IDX] * 100]

cat("Mesi selezionati per il confronto PCA:\n")
for (ii in seq_len(nrow(sel_months))) {
  cat(" -", sel_months$Tipo[ii], ":",
      format(sel_months$YM[ii], "%B %Y"),
      " (norma =", round(sel_months$Norma_pb[ii], 1), "pb)\n")
}

mean_delta_m <- attr(X_m, "scaled:center")

cmp_long <- rbindlist(lapply(seq_len(nrow(sel_months)), function(ii) {
  idx_i <- sel_months$IDX[ii]
  month_lab <- paste0(sel_months$Tipo[ii], ": ",
                      format(sel_months$YM[ii], "%b %Y"))
  rbind(
    data.table(
      Mese = month_lab,
      MAT_NUM = as.integer(sub("Y$", "", maturity_cols)),
      Serie = "Delta osservata",
      DeltaRate = as.numeric(Delta_R_m[idx_i, ])
    ),
    data.table(
      Mese = month_lab,
      MAT_NUM = as.integer(sub("Y$", "", maturity_cols)),
      Serie = "Delta ricostruita (PCA, k=3)",
      DeltaRate = as.numeric(X_hat_m[idx_i, ]) + mean_delta_m
    )
  )
}))
cmp_long[, Mese := factor(Mese, levels = unique(Mese))]

p7 <- ggplot(cmp_long, aes(x = MAT_NUM, y = DeltaRate * 100,
                            color = Serie, linetype = Serie)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line(linewidth = 1.1) + geom_point(size = 1.6) +
  scale_color_manual(values = c(`Delta osservata` = "#000000",
              `Delta ricostruita (PCA, k=3)` = "#d73027")) +
  scale_linetype_manual(values = c(`Delta osservata` = "solid",
              `Delta ricostruita (PCA, k=3)` = "dashed")) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  facet_wrap(~Mese, ncol = 1, scales = "free_y") +
  labs(title = "STEP 3 — Confronto: delta osservata vs delta ricostruita con PCA",
       subtitle = "Mesi selezionati: primo, centrale, ultimo",
       x = "Scadenza (anni)", y = "Variazione mensile (punti base)",
    color = "Serie", linetype = "Serie") +
  plot_theme
ggsave(file.path(output_dir, "step3_confronto_ricostruzione_m.pdf"),
       p7, width = 9, height = 9, device = cairo_pdf)
cat("Grafico confronto ricostruzione salvato.\n")

# ------------------------------------------------------------------
# Ricostruzione progressiva k = 0, 1, 2, 3 sul mese centrale
# ------------------------------------------------------------------
ref_idx <- sel_months[Tipo == "Mese centrale", IDX]
if (length(ref_idx) == 0L) ref_idx <- sel_months$IDX[min(2L, nrow(sel_months))]
ref_ym <- dates_delta_m[ref_idx]

prog_list <- lapply(0:3, function(k) {
  if (k == 0L) {
    x_rec <- rep(0, ncol(X_m))
    label <- "Solo media (k=0)"
  } else {
    x_rec <- as.numeric(
      scores_k_m[ref_idx, 1:k, drop = FALSE] %*%
      t(loadings_k_m[, 1:k, drop = FALSE])
    )
    pct   <- round(100 * cum_var[k], 1)
    label <- paste0("k=", k, "  (", pct, "% var.)")
  }
  data.table(MAT_NUM   = as.integer(sub("Y$", "", maturity_cols)),
             DeltaRate = x_rec + mean_delta_m,
             Serie     = label)
})
prog_list[[5]] <- data.table(
  MAT_NUM   = as.integer(sub("Y$", "", maturity_cols)),
  DeltaRate = as.numeric(Delta_R_m[ref_idx, ]),
  Serie     = "Reale"
)
lbl1 <- paste0("k=1  (", round(100 * cum_var[1], 1), "% var.)")
lbl2 <- paste0("k=2  (", round(100 * cum_var[2], 1), "% var.)")
lbl3 <- paste0("k=3  (", round(100 * cum_var[3], 1), "% var.)")
prog_list[[2]][, Serie := lbl1]
prog_list[[3]][, Serie := lbl2]
prog_list[[4]][, Serie := lbl3]
prog_dt <- rbindlist(prog_list)
prog_dt[, Serie := factor(Serie,
  levels = c("Solo media (k=0)", lbl1, lbl2, lbl3, "Reale"))]

col_scale <- setNames(
  c("#aaaaaa", "#74add1", "#f46d43", "#1a9850", "#000000"),
  c("Solo media (k=0)", lbl1, lbl2, lbl3, "Reale"))
lty_scale <- setNames(
  c("dotted", "dashed", "dashed", "dashed", "solid"),
  c("Solo media (k=0)", lbl1, lbl2, lbl3, "Reale"))
lwd_scale <- setNames(
  c(0.7, 1.0, 1.0, 1.0, 1.5),
  c("Solo media (k=0)", lbl1, lbl2, lbl3, "Reale"))

p8 <- ggplot(prog_dt, aes(x = MAT_NUM, y = DeltaRate * 100,
                            color = Serie, linetype = Serie,
                            linewidth = Serie)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_line() +
  geom_point(data = prog_dt[Serie == "Reale"], size = 2) +
  scale_color_manual(values = col_scale) +
  scale_linetype_manual(values = lty_scale) +
  scale_linewidth_manual(values = lwd_scale) +
  scale_y_continuous(labels = label_number(suffix = " pb")) +
  labs(title = "STEP 3 — Ricostruzione progressiva della variazione mensile",
      subtitle = paste0("Mese centrale: ", format(ref_ym, "%B %Y")),
       x = "Scadenza (anni)", y = "Variazione mensile (punti base)",
       color = "Componenti", linetype = "Componenti") +
  plot_theme +
  guides(linewidth = "none")
ggsave(file.path(output_dir, "step3_ricostruzione_progressiva_m.pdf"),
       p8, width = 10, height = 5.5, device = cairo_pdf)
cat("Grafico ricostruzione progressiva salvato.\n")

# ------------------------------------------------------------------
# Nelson-Siegel: fit per ogni mese e confronto visivo
# ------------------------------------------------------------------
cat("Fit Nelson-Siegel mensile...\n")
lambda_ns <- 1.5
mat_num_ns <- as.integer(sub("Y$", "", maturity_cols))

ns_basis <- function(T_vec, lam) {
  x <- T_vec / lam
  cbind(Level = 1, Slope = (1 - exp(-x)) / x,
        Curvature = (1 - exp(-x)) / x - exp(-x))
}
B_ns  <- ns_basis(mat_num_ns, lambda_ns)
betas <- t(apply(R_mat_m, 1, function(r) lm.fit(B_ns, r)$coefficients))
colnames(betas) <- c("beta0_level", "beta1_slope", "beta2_curv")

# Confronto fit NS per 3 date (inizio, picco 2022, recente)
peak_idx <- which.max(R_mat_m[, which(maturity_cols == "10Y")])
ns_sel   <- unique(c(1L, peak_idx, nrow(R_mat_m)))
ns_list  <- rbindlist(lapply(ns_sel, function(i) {
  r_hat <- as.numeric(B_ns %*% betas[i, ])
  rbind(
    data.table(MAT_NUM = mat_num_ns, Rate = R_mat_m[i, ],
               Tipo = "Osservata", Data = format(dates_m[i], "%b %Y")),
    data.table(MAT_NUM = mat_num_ns, Rate = r_hat,
               Tipo = "Nelson-Siegel", Data = format(dates_m[i], "%b %Y"))
  )
}))

p9 <- ggplot(ns_list, aes(x = MAT_NUM, y = Rate,
                           color = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1) + geom_point(size = 1.2) +
  facet_wrap(~Data, scales = "free_y") +
  scale_color_manual(values = c(Osservata = "steelblue",
                                 "Nelson-Siegel" = "tomato")) +
  scale_linetype_manual(values = c(Osservata = "solid",
                                    "Nelson-Siegel" = "dashed")) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.01)) +
  labs(title = "STEP 3 — Confronto curva osservata vs fit Nelson-Siegel",
       x = "Scadenza (anni)", y = "Tasso (%)", color = NULL, linetype = NULL) +
  plot_theme
ggsave(file.path(output_dir, "step3_nelson_siegel_confronto_m.pdf"),
       p9, width = 11, height = 5, device = cairo_pdf)

# ------------------------------------------------------------------
# Scrivi file di riepilogo per LaTeX
# ------------------------------------------------------------------
summary_file <- file.path(output_dir, "pca_summary_for_tex_m.tex")
writeLines(
  c(sprintf("Campione mensile analizzato: \\textbf{%d} mesi e \\textbf{%d} maturity.",
            n_months, ncol(R_mat_m)),
    sprintf("La soglia del 95\\%% di varianza spiegata \\`e raggiunta con \\textbf{%d} componenti principali.",
            k_star),
    sprintf("Varianza spiegata PC1--PC3: \\textbf{%.2f\\%%, %.2f\\%%, %.2f\\%%}.",
            100 * expl_var[1], 100 * expl_var[2], 100 * expl_var[3]),
    sprintf("RMSE della ricostruzione con $k=3$: \\textbf{%.5f} (variazioni mensili in \\%%).",
            rmse_m),
        sprintf("Mesi usati per il confronto (primo/centrale/ultimo): \\textbf{%s, %s, %s}.",
          format(sel_months$YM[1], "%B %Y"),
          format(sel_months$YM[min(2, nrow(sel_months))], "%B %Y"),
          format(sel_months$YM[nrow(sel_months)], "%B %Y")),
        sprintf("Norme L$_2$ delle variazioni selezionate: \\textbf{%.1f, %.1f, %.1f~pb}.",
          sel_months$Norma_pb[1],
          sel_months$Norma_pb[min(2, nrow(sel_months))],
          sel_months$Norma_pb[nrow(sel_months)])
  ),
  summary_file
)
cat("File riepilogo scritto:", summary_file, "\n")

cat("\n=== COMPLETATO. File salvati in:", normalizePath(output_dir), "===\n")


# ==============================================================
# SEZIONE 5 — Calibrazione degli scores su una curva arbitraria
# ==============================================================
# Data una curva y_new osservata su tutte le 20 scadenze, calcoliamo
# i pesi (scores) tramite proiezione ortogonale sui loadings PCA:
#
#   alpha_k = V_k^T * y_new      (k pesi — prodotto algebrico diretto)
#   y_hat_k = V_k * alpha_k      (ricostruzione con k componenti)
#
# Poiché le colonne di V sono ortonormali (V_k^T V_k = I_k), la
# proiezione è esatta in un passo. Con k = 20 la base è completa
# e la ricostruzione coincide con y_new (errore numericamente zero).
# ==============================================================

cat("\n=== SEZIONE 5: CALIBRAZIONE SU CURVA ARBITRARIA ===\n")

# --- Curva arbitraria (livelli) —- inserire qui valori a scelta ----
y_new <- c(
  "1Y"  = 0.02680, "2Y"  = 0.02752, "3Y"  = 0.02748, "4Y"  = 0.02753,
  "5Y"  = 0.02783, "6Y"  = 0.02818, "7Y"  = 0.02858, "8Y"  = 0.02904,
  "9Y"  = 0.02944, "10Y" = 0.02998, "11Y" = 0.03025, "12Y" = 0.03072,
  "13Y" = 0.03106, "14Y" = 0.03134, "15Y" = 0.03166, "16Y" = 0.03186,
  "17Y" = 0.03195, "18Y" = 0.03197, "19Y" = 0.03195, "20Y" = 0.03192
)

# --- Base ortonormale dei loadings (da SVD sui dati mensili) -------
V <- sv_m$v   # n x n, colonne ortonormali

# --- Pesi e ricostruzioni per k = 3, 5, 10, 20 --------------------
k_vals  <- c(3L, 5L, 10L, 20L)
maturities_num <- as.integer(sub("Y$", "", names(y_new)))

recon_list <- setNames(
  lapply(k_vals, function(k) {
    alpha_k <- as.numeric(t(V[, 1:k, drop = FALSE]) %*% y_new)   # k pesi
    y_hat_k <- as.numeric(V[, 1:k, drop = FALSE] %*% alpha_k)     # n valori
    y_hat_k
  }),
  paste0("k=", k_vals)
)

# Stampa pesi (scores) per le prime 3 componenti
alpha3 <- as.numeric(t(V[, 1:3]) %*% y_new)
cat(sprintf("Scores con k=3:  PC1 = %+.6f  PC2 = %+.6f  PC3 = %+.6f\n",
            alpha3[1], alpha3[2], alpha3[3]))

# ==============================================================
# Grafico A — Curve originale vs ricostruzioni con k = 3, 5, 10, 20
# ==============================================================
# Grafico A — Curva originale vs k=3 e k=20
# k=20: base completa, ricostruzione esatta (curva sovrapposta all'originale)
# ==============================================================
df_levels <- rbindlist(list(
  data.table(Scadenza = maturities_num,
             Valore   = as.numeric(y_new) * 100,
             Tipo     = "Originale"),
  data.table(Scadenza = maturities_num,
             Valore   = recon_list[["k=3"]]  * 100,
             Tipo     = "k=3 PC"),
  data.table(Scadenza = maturities_num,
             Valore   = recon_list[["k=20"]] * 100,
             Tipo     = "k=20 PC (esatta)")
))
df_levels[, Tipo := factor(Tipo,
  levels = c("Originale", "k=3 PC", "k=20 PC (esatta)"))]

p_s5a <- ggplot(df_levels,
                aes(x = Scadenza, y = Valore,
                    colour = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.1) +
  geom_point(data = df_levels[Tipo == "Originale"], size = 2.2) +
  scale_colour_manual(
    values = c("Originale" = "#000000",
               "k=3 PC"   = "#e66101",
               "k=20 PC (esatta)" = "#1a9850")) +
  scale_linetype_manual(
    values = c("Originale" = "solid",
               "k=3 PC"   = "dashed",
               "k=20 PC (esatta)" = "dotted")) +
  scale_x_continuous(breaks = seq(1, 20, by = 2)) +
  scale_y_continuous(labels = label_number(suffix = "%", accuracy = 0.01)) +
  labs(
    title   = "SEZ. 5 — Ricostruzione PCA di una curva dei livelli",
    x       = "Scadenza (anni)",
    y       = "Tasso (%)",
    colour  = NULL,
    linetype = NULL
  ) +
  plot_theme

ggsave(file.path(output_dir, "sez5_curva_ricostruzione.pdf"),
       p_s5a, width = 9, height = 5, device = cairo_pdf)
cat("Grafico A (ricostruzione livelli) salvato.\n")

# ==============================================================
# Grafico B — Convergenza su scala logaritmica (k = 1..19)
# La scala log mostra il tasso di convergenza e i valori a bassa
# ampiezza che su scala lineare collassano a zero e non si leggono.
# k=20 è escluso perché l'errore è rumore numerico (~1e-12 bp).
# ==============================================================
err_norms_bp <- sapply(1:20, function(k) {
  alpha_k <- as.numeric(t(V[, 1:k, drop = FALSE]) %*% y_new)
  y_hat_k <- as.numeric(V[, 1:k, drop = FALSE] %*% alpha_k)
  sqrt(sum((y_hat_k - y_new)^2)) * 1e4   # norma L2 in punti base
})

# Riduzione percentuale rispetto a k=1
riduzione_pct <- (1 - err_norms_bp / err_norms_bp[1]) * 100

cat(sprintf("\nErrore L2 (bp):  k=1: %.2f  |  k=3: %.2f  |  k=10: %.2f  |  k=20: %.2e\n",
            err_norms_bp[1], err_norms_bp[3], err_norms_bp[10], err_norms_bp[20]))
cat(sprintf("Riduzione (%%)  :  k=3: %.1f%%  |  k=10: %.1f%%\n",
            riduzione_pct[3], riduzione_pct[10]))

# Etichette annotate per k=3 e k=10
ann_dt <- data.table(
  k     = c(3L, 10L),
  y_pos = err_norms_bp[c(3, 10)],
  label = sprintf("k=%d\n%.2f bp\n(-%.0f%%)",
                  c(3L, 10L),
                  err_norms_bp[c(3, 10)],
                  riduzione_pct[c(3, 10)])
)

# Escludi k=20 dal grafico log (errore ~0, rumore macchina)
df_err <- data.table(k = 1:19, Errore_bp = err_norms_bp[1:19])

p_s5b <- ggplot(df_err, aes(x = k, y = Errore_bp)) +
  geom_line(color = "steelblue", linewidth = 1.1) +
  geom_point(color = "steelblue", size = 2.2) +
  geom_point(data = ann_dt, aes(x = k, y = y_pos),
             colour = "tomato", size = 3.5) +
  geom_label(data = ann_dt, aes(x = k, y = y_pos, label = label),
             nudge_x = 0.9, size = 3, colour = "tomato",
             fill = "white", label.size = 0.3,
             label.padding = unit(0.2, "lines")) +
  scale_x_continuous(breaks = 1:19) +
  scale_y_log10(
    labels = label_number(accuracy = 0.01, suffix = " bp"),
    minor_breaks = NULL
  ) +
  labs(
    title   = "SEZ. 5 — Convergenza dell'errore di ricostruzione (scala log)",
    x       = "Numero di componenti principali k",
    y       = "Errore L2 (punti base, scala log)"
  ) +
  plot_theme

ggsave(file.path(output_dir, "sez5_convergenza_errore.pdf"),
       p_s5b, width = 9, height = 5, device = cairo_pdf)
cat("Grafico B (convergenza errore, log) salvato.\n")
