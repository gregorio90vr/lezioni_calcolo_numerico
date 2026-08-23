suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(ggplot2)
  library(lubridate)
  library(scales)
})

# ------------------------------------------------------------
#  ANALISI DI SUPPORTO (non entra nella dispensa)
#
#  Scopo: vedere COME si e' mossa la curva, scadenza per scadenza, nei
#  cinque periodi macro evidenziati nella Sezione 3.3.3 della dispensa 03
#  ("Gli scores mensili: la storia della politica monetaria BCE").
#  Serve a verificare a mano le affermazioni del testo, del tipo
#  "a settembre 2008 il tasso a 1 anno perde 60 pb mentre il 10 anni resta
#  fermo" oppure "PC2 negativo = irripidimento".
#
#  La PCA e' calibrata ESATTAMENTE come in 03_pca_ecb.R (taglio al
#  31/12/2025): solo cosi' gli scores qui calcolati coincidono con quelli
#  della Figura 8 della dispensa.
#
#  Input : ../dati/03_ecb_spot.xlsx
#  Output: ../output/03d_analisi_periodi/   <-- cartella SEPARATA, nessun
#          file .tex la referenzia: questi grafici non entrano nella dispensa.
#     evento_<tag>.pdf                   boxplot livelli + boxplot variazioni
#     periodo_<tag>.pdf                  4 pannelli per ciascun periodo
#     heatmap_mese_tenor.pdf             variazioni mensili, mese x scadenza
#     confronto_periodi.pdf              variazione cumulata, periodi a confronto
#     boxplot_centrate_per_scadenza.pdf  distribuzione di X centrata per tenor
#     boxplot_centrate_per_periodo.pdf   dispersione a confronto fra periodi
#     boxplot_livelli_vs_partenza.pdf    livelli nel periodo vs curva iniziale
#     boxplot_scostamento_da_inizio.pdf  scostamento dal livello di partenza
#     scores_rolling_zscore.pdf          scores standardizzati su finestra mobile
#     riepilogo_periodi.csv              numeri di sintesi
# ------------------------------------------------------------

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

input_xlsx <- "../dati/03_ecb_spot.xlsx"
output_dir <- "../output/03d_analisi_periodi"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

data_calibrazione <- as.Date("2025-12-31")

if (!file.exists(input_xlsx))
  stop("File non trovato: ", input_xlsx)

plot_theme <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        plot.title    = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(size = 9, colour = "grey30"),
        legend.position = "bottom")

# ==============================================================
# 1. DATI E PCA (identici a 03_pca_ecb.R)
# ==============================================================

cat("\n=== 1. DATI E CALIBRAZIONE PCA ===\n")

curve_df <- as.data.table(read.xlsx(input_xlsx, sheet = "PCA_Input"))
maturity_cols <- grep("^([1-9]|1[0-9]|20)Y$", names(curve_df), value = TRUE)
maturity_cols <- maturity_cols[order(as.integer(sub("Y$", "", maturity_cols)))]
maturity_num  <- as.integer(sub("Y$", "", maturity_cols))
n_mat         <- length(maturity_cols)

curve_df[, TIME_PERIOD := openxlsx::convertToDate(TIME_PERIOD)]
for (cc in maturity_cols) curve_df[, (cc) := as.numeric(get(cc)) / 100]

valid_rows <- rowSums(!is.na(curve_df[, ..maturity_cols])) >= 3L
curve_df   <- curve_df[valid_rows, c("TIME_PERIOD", maturity_cols), with = FALSE]
setorder(curve_df, TIME_PERIOD)

curve_df[, YM := lubridate::floor_date(TIME_PERIOD, "month")]
monthly_dt <- curve_df[, .SD[.N], by = YM, .SDcols = c("TIME_PERIOD", maturity_cols)]
setorder(monthly_dt, YM)
monthly_dt <- monthly_dt[TIME_PERIOD <= data_calibrazione]

R_mat_m       <- as.matrix(monthly_dt[, ..maturity_cols])
dates_m       <- monthly_dt$TIME_PERIOD
Delta_R_m     <- diff(R_mat_m)
dates_delta_m <- dates_m[-1]

# Centraggio e SVD
xm  <- colMeans(Delta_R_m)
X_m <- Delta_R_m - matrix(rep(xm, nrow(Delta_R_m)), nrow = nrow(Delta_R_m), byrow = TRUE)
sv  <- svd(X_m)
V   <- sv$v
scores_all <- sv$u %*% diag(sv$d)      # (M-1) x n, tutti gli scores

cat("Campione di calibrazione:", nrow(monthly_dt), "mesi (",
    format(min(dates_m), "%b %Y"), "-", format(max(dates_m), "%b %Y"), ")\n")
cat("Varianza spiegata PC1-PC3:",
    paste(round(100 * (sv$d^2 / sum(sv$d^2))[1:3], 2), collapse = ", "), "%\n")

# ==============================================================
# 2. PERIODI (le stesse fasce della Figura 8 della dispensa)
# ==============================================================

periodi <- data.table(
  tag   = c("lehman", "rialzi2011", "attese_qe", "qe", "rialzi2022"),
  label = c("Crisi Lehman Brothers",
            "Attese e rialzi BCE",
            "Attese QE",
            "QE BCE (esecuzione)",
            "Attese e rialzi BCE"),
  start = as.Date(c("2008-09-01", "2010-09-01", "2014-01-01", "2015-01-01", "2021-12-01")),
  end   = as.Date(c("2009-02-28", "2011-07-31", "2014-12-31", "2018-12-31", "2023-09-30"))
)
periodi[, titolo := paste0(label, " (", format(start, "%m/%Y"), " - ",
                           format(end, "%m/%Y"), ")")]

# --------------------------------------------------------------
# Decomposizione della variazione cumulata di un periodo.
#
# Per ogni mese s vale  Delta r_s = xm + sum_i alpha_{s,i} v_i, quindi
# sommando sui mesi del periodo P:
#
#   sum_{s in P} Delta r_s = |P| * xm + sum_i ( sum_{s in P} alpha_{s,i} ) v_i
#
# cioe' il movimento netto della curva si scompone, TENOR PER TENOR, in un
# termine di drift e nei contributi delle singole componenti principali.
# --------------------------------------------------------------
analizza_periodo <- function(p) {
  idx <- which(dates_delta_m >= p$start & dates_delta_m <= p$end)
  if (length(idx) == 0L) stop("Nessun mese nel periodo ", p$tag)

  n_mesi     <- length(idx)
  somma_sc   <- colSums(scores_all[idx, , drop = FALSE])   # somma scores per PC
  drift      <- n_mesi * xm
  contributi <- sapply(1:n_mat, function(i) somma_sc[i] * V[, i])  # n_mat x n_mat

  # variazione cumulata osservata: livello di fine periodo meno livello del
  # mese immediatamente precedente l'inizio
  i_fine   <- idx[n_mesi] + 1L        # +1: riga s di Delta = mese s+1 dei livelli
  i_inizio <- idx[1] + 1L - 1L
  var_oss  <- R_mat_m[i_fine, ] - R_mat_m[i_inizio, ]

  # verifica: drift + tutti i contributi deve ricomporre l'osservato
  ricomposto <- drift + rowSums(contributi)
  stopifnot(max(abs(ricomposto - var_oss)) < 1e-12)

  list(p = p, idx = idx, n_mesi = n_mesi,
       somma_scores = somma_sc,
       drift = drift, contributi = contributi,
       var_oss = var_oss,
       liv_inizio = R_mat_m[i_inizio, ], liv_fine = R_mat_m[i_fine, ],
       data_inizio = dates_m[i_inizio], data_fine = dates_m[i_fine])
}

res <- lapply(seq_len(nrow(periodi)), function(j) analizza_periodo(periodi[j]))
names(res) <- periodi$tag
cat("Decomposizione verificata su tutti i periodi (stopifnot superati).\n")

# ==============================================================
# 3. UN PDF PER PERIODO (4 pannelli)
# ==============================================================

cat("\n=== 3. GRAFICI PER PERIODO ===\n")

for (r in res) {
  p <- r$p

  # --- Pannello 1: livelli della curva a inizio/fine (+ date intermedie) ---
  idx_liv <- unique(round(seq(r$idx[1], r$idx[r$n_mesi] + 1, length.out = 4)))
  liv_dt <- rbindlist(lapply(idx_liv, function(i) data.table(
    Data    = format(dates_m[i], "%b %Y"),
    ord     = i,
    MAT_NUM = maturity_num,
    Tasso   = R_mat_m[i, ] * 100
  )))
  liv_dt[, Data := factor(Data, levels = unique(Data[order(ord)]))]

  g1 <- ggplot(liv_dt, aes(MAT_NUM, Tasso, colour = Data)) +
    geom_line(linewidth = 0.9) + geom_point(size = 1.4) +
    scale_x_continuous(breaks = seq(1, 20, 2)) +
    scale_colour_viridis_d(end = 0.85) +
    labs(title = "1. Livelli della curva",
         subtitle = "Curva a inizio periodo, in due date intermedie e a fine periodo",
         x = "Scadenza (anni)", y = "Tasso (%)", colour = NULL) +
    plot_theme

  # --- Pannello 2: variazione cumulata per scadenza ---
  var_dt <- data.table(MAT_NUM = maturity_num, Var_bp = r$var_oss * 1e4)
  g2 <- ggplot(var_dt, aes(factor(MAT_NUM), Var_bp)) +
    geom_col(fill = "#4575b4", width = 0.7) +
    geom_hline(yintercept = 0, colour = "grey30") +
    labs(title = "2. Variazione cumulata per scadenza",
         subtitle = paste0("Da ", format(r$data_inizio, "%b %Y"), " a ",
                           format(r$data_fine, "%b %Y"), " (", r$n_mesi, " mesi)"),
         x = "Scadenza (anni)", y = "Variazione (pb)") +
    plot_theme

  # --- Pannello 3: decomposizione nei contributi dei PC ---
  dec_dt <- rbindlist(list(
    data.table(MAT_NUM = maturity_num, Val = r$drift * 1e4,            Comp = "Drift (media)"),
    data.table(MAT_NUM = maturity_num, Val = r$contributi[, 1] * 1e4,  Comp = "PC1 (livello)"),
    data.table(MAT_NUM = maturity_num, Val = r$contributi[, 2] * 1e4,  Comp = "PC2 (pendenza)"),
    data.table(MAT_NUM = maturity_num, Val = r$contributi[, 3] * 1e4,  Comp = "PC3 (curvatura)"),
    data.table(MAT_NUM = maturity_num,
               Val = rowSums(r$contributi[, 4:n_mat, drop = FALSE]) * 1e4,
               Comp = "PC4+ (residuo)")
  ))
  dec_dt[, Comp := factor(Comp, levels = c("Drift (media)", "PC1 (livello)",
                                           "PC2 (pendenza)", "PC3 (curvatura)",
                                           "PC4+ (residuo)"))]

  g3 <- ggplot(dec_dt, aes(MAT_NUM, Val, colour = Comp)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_line(linewidth = 0.9) +
    geom_line(data = data.table(MAT_NUM = maturity_num, Val = r$var_oss * 1e4),
              aes(MAT_NUM, Val), inherit.aes = FALSE,
              colour = "black", linewidth = 1.3, linetype = "dashed") +
    scale_x_continuous(breaks = seq(1, 20, 2)) +
    scale_colour_manual(values = c("Drift (media)"   = "#999999",
                                   "PC1 (livello)"   = "#d73027",
                                   "PC2 (pendenza)"  = "#4575b4",
                                   "PC3 (curvatura)" = "#1a9850",
                                   "PC4+ (residuo)"  = "#b8860b")) +
    labs(title = "3. Decomposizione della variazione cumulata",
         subtitle = "Nera tratteggiata: variazione osservata (= somma di tutti i contributi)",
         x = "Scadenza (anni)", y = "Contributo (pb)", colour = NULL) +
    plot_theme

  # --- Pannello 4: scores mensili nel periodo ---
  sc_dt <- rbindlist(lapply(1:3, function(i) data.table(
    Data  = dates_delta_m[r$idx],
    Score = scores_all[r$idx, i] * 1e4,
    PC    = paste0("PC", i)
  )))
  g4 <- ggplot(sc_dt, aes(Data, Score, colour = PC)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_line(linewidth = 0.8) + geom_point(size = 1.3) +
    scale_colour_manual(values = c(PC1 = "#d73027", PC2 = "#4575b4", PC3 = "#1a9850")) +
    labs(title = "4. Scores mensili nel periodo",
         subtitle = paste0("Somma nel periodo (pb): PC1 = ",
                           round(r$somma_scores[1] * 1e4, 1), ", PC2 = ",
                           round(r$somma_scores[2] * 1e4, 1), ", PC3 = ",
                           round(r$somma_scores[3] * 1e4, 1)),
         x = NULL, y = "Score (pb)", colour = NULL) +
    plot_theme

  # Composizione 2x2 su una sola pagina usando 'grid' (pacchetto base R:
  # nessuna dipendenza aggiuntiva rispetto a gridExtra/patchwork).
  f <- file.path(output_dir, paste0("periodo_", p$tag, ".pdf"))
  grDevices::cairo_pdf(f, width = 13, height = 9)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    nrow = 3, ncol = 2, heights = grid::unit(c(1.1, 10, 10), "null"))))
  grid::grid.text(p$titolo,
                  vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1:2),
                  gp = grid::gpar(fontface = "bold", cex = 1.25))
  print(g1, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  print(g2, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 2))
  print(g3, vp = grid::viewport(layout.pos.row = 3, layout.pos.col = 1))
  print(g4, vp = grid::viewport(layout.pos.row = 3, layout.pos.col = 2))
  grDevices::dev.off()
  cat("Salvato:", basename(f), "\n")
}

# ==============================================================
# 3b. UN PDF PER EVENTO: boxplot dei livelli + boxplot delle variazioni
#
# Due pannelli affiancati, stessa struttura per tutti gli eventi:
#   sinistra  -> distribuzione dei LIVELLI della curva per scadenza dentro
#                l'evento (dove si e' collocata la curva);
#   destra    -> distribuzione delle VARIAZIONI mensili per scadenza
#                (di quanto si e' mossa).
# Le variazioni sono quelle grezze (non centrate): qui interessa di quanto la
# curva si e' mossa, non lo scostamento dalla deriva media del campione (per
# quello ci sono i file boxplot_centrate_*).
# ==============================================================

cat("\n=== 3b. UN PDF PER EVENTO (boxplot livelli + boxplot variazioni) ===\n")

for (r in res) {
  p <- r$p

  liv_ev_dt <- rbindlist(lapply(r$idx + 1L, function(i) data.table(
    MAT_NUM = maturity_num,
    Livello = R_mat_m[i, ] * 100
  )))

  gA <- ggplot(liv_ev_dt, aes(factor(MAT_NUM), Livello)) +
    geom_boxplot(fill = "#4575b4", alpha = 0.5, width = 0.65, linewidth = 0.3,
                 outlier.size = 0.7, outlier.alpha = 0.6) +
    labs(title = "Livelli della curva per scadenza",
         subtitle = paste0("Distribuzione dei livelli di fine mese nei ",
                           r$n_mesi, " mesi dell'evento"),
         x = "Scadenza (anni)", y = "Tasso (%)") +
    plot_theme

  var_ev_dt <- rbindlist(lapply(r$idx, function(j) data.table(
    MAT_NUM = maturity_num,
    Delta   = Delta_R_m[j, ] * 1e4
  )))

  gB <- ggplot(var_ev_dt, aes(factor(MAT_NUM), Delta)) +
    geom_hline(yintercept = 0, colour = "grey40", linetype = "dashed") +
    geom_boxplot(fill = "#e66101", alpha = 0.5, width = 0.65, linewidth = 0.3,
                 outlier.size = 0.7, outlier.alpha = 0.6) +
    labs(title = "Variazioni mensili per scadenza",
         subtitle = paste0(r$n_mesi, " mesi, da ",
                           format(dates_delta_m[r$idx[1]], "%b %Y"), " a ",
                           format(dates_delta_m[r$idx[r$n_mesi]], "%b %Y")),
         x = "Scadenza (anni)", y = "Variazione mensile (pb)") +
    plot_theme

  f <- file.path(output_dir, paste0("evento_", p$tag, ".pdf"))
  grDevices::cairo_pdf(f, width = 13, height = 5.5)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    nrow = 2, ncol = 2, heights = grid::unit(c(1.1, 10), "null"))))
  grid::grid.text(p$titolo,
                  vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1:2),
                  gp = grid::gpar(fontface = "bold", cex = 1.25))
  print(gA, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  print(gB, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 2))
  grDevices::dev.off()
  cat("Salvato:", basename(f), "\n")
}

# ==============================================================
# 4. GRAFICI TRASVERSALI
# ==============================================================

cat("\n=== 4. GRAFICI TRASVERSALI ===\n")

# --- Heatmap mese x scadenza, un pannello per periodo ---
heat_dt <- rbindlist(lapply(res, function(r) {
  rbindlist(lapply(seq_along(r$idx), function(j) data.table(
    Periodo = r$p$titolo,
    Mese    = dates_delta_m[r$idx[j]],
    MAT_NUM = maturity_num,
    Delta   = Delta_R_m[r$idx[j], ] * 1e4
  )))
}))
heat_dt[, Periodo := factor(Periodo, levels = periodi$titolo)]

lim <- max(abs(heat_dt$Delta))
g_heat <- ggplot(heat_dt, aes(Mese, factor(MAT_NUM), fill = Delta)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c",
                       midpoint = 0, limits = c(-lim, lim), name = "pb") +
  facet_wrap(~Periodo, scales = "free_x", ncol = 2) +
  labs(title = "Variazioni mensili per scadenza",
       subtitle = "Rosso: tassi in salita. Blu: tassi in discesa",
       x = NULL, y = "Scadenza (anni)") +
  plot_theme + theme(legend.position = "right")
ggsave(file.path(output_dir, "heatmap_mese_tenor.pdf"), g_heat,
       width = 12, height = 9, device = cairo_pdf)
cat("Salvato: heatmap_mese_tenor.pdf\n")

# --- Confronto della variazione cumulata fra i cinque periodi ---
conf_dt <- rbindlist(lapply(res, function(r) data.table(
  Periodo = r$p$titolo, MAT_NUM = maturity_num, Var_bp = r$var_oss * 1e4
)))
conf_dt[, Periodo := factor(Periodo, levels = periodi$titolo)]

g_conf <- ggplot(conf_dt, aes(MAT_NUM, Var_bp, colour = Periodo)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  scale_x_continuous(breaks = seq(1, 20, 2)) +
  scale_colour_brewer(palette = "Dark2") +
  labs(title = "Variazione cumulata della curva: confronto fra i periodi",
       x = "Scadenza (anni)", y = "Variazione cumulata (pb)", colour = NULL) +
  plot_theme + guides(colour = guide_legend(ncol = 2))
ggsave(file.path(output_dir, "confronto_periodi.pdf"), g_conf,
       width = 10, height = 6.5, device = cairo_pdf)
cat("Salvato: confronto_periodi.pdf\n")

# --------------------------------------------------------------
# Boxplot delle variazioni CENTRATE.
# X_m = Delta_R_m - xm e' esattamente la matrice decomposta dalla SVD:
# i boxplot mostrano come si distribuiscono le variazioni, tenor per tenor,
# una volta tolta la deriva media del campione. Il pannello "Intero campione"
# fa da riferimento per giudicare se un periodo e' anomalo.
# --------------------------------------------------------------
riga_box <- function(righe, etichetta) {
  rbindlist(lapply(righe, function(j) data.table(
    Periodo  = etichetta,
    MAT_NUM  = maturity_num,
    Centrata = X_m[j, ] * 1e4
  )))
}

box_dt <- rbind(
  riga_box(seq_len(nrow(X_m)), "Intero campione di calibrazione"),
  rbindlist(lapply(res, function(r) riga_box(r$idx, r$p$titolo)))
)
box_dt[, Periodo := factor(Periodo,
                           levels = c("Intero campione di calibrazione", periodi$titolo))]

g_box <- ggplot(box_dt, aes(factor(MAT_NUM), Centrata)) +
  geom_hline(yintercept = 0, colour = "grey40", linetype = "dashed") +
  geom_boxplot(fill = "#4575b4", alpha = 0.55, width = 0.65, linewidth = 0.3,
               outlier.size = 0.6, outlier.alpha = 0.5) +
  facet_wrap(~Periodo, ncol = 2, scales = "free_y") +
  labs(title = "Variazioni mensili centrate, per scadenza",
       subtitle = paste("Distribuzione delle variazioni una volta sottratta la media di colonna",
                        "(la matrice su cui agisce la SVD)"),
       x = "Scadenza (anni)", y = "Variazione centrata (pb)") +
  plot_theme
ggsave(file.path(output_dir, "boxplot_centrate_per_scadenza.pdf"), g_box,
       width = 12, height = 11, device = cairo_pdf)
cat("Salvato: boxplot_centrate_per_scadenza.pdf\n")

# Stessa informazione ristretta a quattro scadenze rappresentative, con i
# periodi affiancati: rende immediato il confronto della dispersione.
key_tenors <- c(1, 5, 10, 20)
box2_dt <- box_dt[MAT_NUM %in% key_tenors]
box2_dt[, Tenor := factor(paste0(MAT_NUM, "Y"), levels = paste0(key_tenors, "Y"))]

g_box2 <- ggplot(box2_dt, aes(Periodo, Centrata, fill = Tenor)) +
  geom_hline(yintercept = 0, colour = "grey40", linetype = "dashed") +
  geom_boxplot(alpha = 0.7, width = 0.7, linewidth = 0.3,
               outlier.size = 0.6, outlier.alpha = 0.5) +
  coord_flip() +
  scale_fill_brewer(palette = "Blues") +
  scale_x_discrete(limits = rev(levels(box2_dt$Periodo))) +
  labs(title = "Variazioni centrate: confronto della dispersione fra periodi",
       subtitle = "Quattro scadenze rappresentative",
       x = NULL, y = "Variazione centrata (pb)", fill = NULL) +
  plot_theme
ggsave(file.path(output_dir, "boxplot_centrate_per_periodo.pdf"), g_box2,
       width = 11, height = 7, device = cairo_pdf)
cat("Salvato: boxplot_centrate_per_periodo.pdf\n")

# --------------------------------------------------------------
# Boxplot con RIFERIMENTO AL LIVELLO DI PARTENZA.
# I boxplot precedenti mostrano le variazioni mese su mese: dicono quanto la
# curva si muove, non dove si trova rispetto a dove era all'inizio del
# periodo. Qui il riferimento e' il livello del mese precedente l'inizio.
#
#   1) livelli assoluti nel periodo, con sovrapposta la curva di partenza:
#      se il box sta sotto la linea rossa, in quel periodo la curva e' scesa;
#   2) scostamento dal livello di partenza (zero = partenza), che quantifica
#      la caduta o la salita scadenza per scadenza.
# --------------------------------------------------------------
liv_periodo_dt <- rbindlist(lapply(res, function(r) {
  rbindlist(lapply(r$idx + 1L, function(i) data.table(
    Periodo = r$p$titolo, MAT_NUM = maturity_num, Livello = R_mat_m[i, ] * 100
  )))
}))
partenza_dt <- rbindlist(lapply(res, function(r) data.table(
  Periodo = r$p$titolo, MAT_NUM = maturity_num, Partenza = r$liv_inizio * 100
)))
liv_periodo_dt[, Periodo := factor(Periodo, levels = periodi$titolo)]
partenza_dt[,  Periodo := factor(Periodo, levels = periodi$titolo)]

g_lev <- ggplot(liv_periodo_dt, aes(factor(MAT_NUM), Livello)) +
  geom_boxplot(fill = "#4575b4", alpha = 0.5, width = 0.65, linewidth = 0.3,
               outlier.size = 0.6, outlier.alpha = 0.5) +
  geom_line(data = partenza_dt, aes(factor(MAT_NUM), Partenza, group = 1),
            colour = "#d73027", linewidth = 0.9) +
  geom_point(data = partenza_dt, aes(factor(MAT_NUM), Partenza),
             colour = "#d73027", size = 1.3) +
  facet_wrap(~Periodo, ncol = 2, scales = "free_y") +
  labs(title = "Livelli della curva nel periodo, rispetto al livello di partenza",
       subtitle = paste("Box: distribuzione dei livelli di fine mese nel periodo.",
                        "Linea rossa: curva all'inizio del periodo.",
                        "Box sotto la linea = curva scesa"),
       x = "Scadenza (anni)", y = "Tasso (%)") +
  plot_theme
ggsave(file.path(output_dir, "boxplot_livelli_vs_partenza.pdf"), g_lev,
       width = 12, height = 11, device = cairo_pdf)
cat("Salvato: boxplot_livelli_vs_partenza.pdf\n")

scost_dt <- rbindlist(lapply(res, function(r) {
  rbindlist(lapply(r$idx + 1L, function(i) data.table(
    Periodo = r$p$titolo, MAT_NUM = maturity_num,
    Scost = (R_mat_m[i, ] - r$liv_inizio) * 1e4
  )))
}))
scost_dt[, Periodo := factor(Periodo, levels = periodi$titolo)]

g_scost <- ggplot(scost_dt, aes(factor(MAT_NUM), Scost)) +
  geom_hline(yintercept = 0, colour = "#d73027", linetype = "dashed", linewidth = 0.7) +
  geom_boxplot(fill = "#1a9850", alpha = 0.45, width = 0.65, linewidth = 0.3,
               outlier.size = 0.6, outlier.alpha = 0.5) +
  facet_wrap(~Periodo, ncol = 2, scales = "free_y") +
  labs(title = "Scostamento dal livello di partenza, per scadenza",
       subtitle = paste("Zero (linea rossa) = livello all'inizio del periodo.",
                        "Mediana sotto zero = curva mediamente piu' bassa della partenza"),
       x = "Scadenza (anni)", y = "Scostamento dalla partenza (pb)") +
  plot_theme
ggsave(file.path(output_dir, "boxplot_scostamento_da_inizio.pdf"), g_scost,
       width = 12, height = 11, device = cairo_pdf)
cat("Salvato: boxplot_scostamento_da_inizio.pdf\n")

# ==============================================================
# 4b. ROLLING Z-SCORE DEGLI SCORES (alternativa alla media mobile)
#
# Nella dispensa la lettura degli scores e' affidata a una media mobile
# centrata: uno smoothing diretto, che pero' lascia i tre pannelli su scale
# molto diverse (PC1 arriva a +/-300 pb, PC3 sta sotto i +/-50) e quindi non
# confrontabili fra loro.
#
# Qui si prova un'alternativa: invece di lisciare la serie la si
# standardizza su finestra mobile,
#
#     z_t = ( score_t - media_mobile_t ) / deviazione_standard_mobile_t
#
# cosi' ogni mese viene misurato in "quante deviazioni standard" rispetto al
# proprio passato/futuro recente. Due conseguenze utili:
#   - i tre PC finiscono sulla STESSA scala e si possono confrontare;
#   - il grafico evidenzia i mesi anomali invece del livello del movimento.
# Finestra centrata, come la media mobile della dispensa, per non introdurre
# ritardo rispetto agli eventi.
# ==============================================================

cat("\n=== 4b. ROLLING Z-SCORE DEGLI SCORES ===\n")

z_win <- 36   # ampiezza della finestra mobile, in mesi

scores_full <- rbindlist(lapply(1:3, function(i) data.table(
  TIME_PERIOD = dates_delta_m,
  Score       = scores_all[, i] * 1e4,
  PC          = paste0("PC", i)
)))
setorder(scores_full, PC, TIME_PERIOD)

scores_full[, mu   := frollapply(Score, z_win, mean, align = "center"), by = PC]
scores_full[, sdev := frollapply(Score, z_win, sd,   align = "center"), by = PC]
scores_full[, Z    := (Score - mu) / sdev]

cat("Finestra:", z_win, "mesi (centrata). Mesi con z calcolabile:",
    sum(!is.na(scores_full$Z)) / 3, "su", length(dates_delta_m), "\n")
cat("Mesi con |z| >= 2 per componente:\n")
print(scores_full[!is.na(Z), .(n_estremi = sum(abs(Z) >= 2)), by = PC])

# fasce dei periodi, come nella figura della dispensa
bande <- copy(periodi)
bande[, etichetta := c("Lehman\n(2008-2009)", "Attese e rialzi BCE\n(2010-2011)",
                       "Attese QE\n(2014)", "QE BCE\n(2015-2018)",
                       "Attese e rialzi BCE\n(2021-2023)")]
bande[, mid := start + (end - start) / 2]
bande[, alpha_v := c(0.15, 0.15, 0.28, 0.15, 0.15)]

etichette_pc <- c(PC1 = "PC1 - Livello", PC2 = "PC2 - Pendenza",
                  PC3 = "PC3 - Curvatura")

g_z <- ggplot(scores_full[!is.na(Z)], aes(TIME_PERIOD, Z)) +
  geom_rect(data = bande,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, alpha = alpha_v),
            fill = "grey50", inherit.aes = FALSE) +
  scale_alpha_identity() +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_hline(yintercept = c(-2, 2), colour = "#d73027",
             linetype = "dashed", linewidth = 0.4) +
  geom_line(colour = "#045a8d", linewidth = 0.7) +
  geom_point(data = scores_full[!is.na(Z) & abs(Z) >= 2],
             colour = "#d73027", size = 1.3) +
  geom_label(data = bande[, c(.SD, list(PC = "PC1"))],
             aes(x = mid, y = Inf, label = etichetta),
             inherit.aes = FALSE, vjust = 1.05, hjust = 0.5, size = 2.5,
             fill = "white", label.size = 0.2,
             label.padding = unit(0.15, "lines")) +
  facet_wrap(~PC, ncol = 1, labeller = labeller(PC = etichette_pc)) +
  labs(title = paste0("Scores mensili in rolling z-score (finestra ", z_win,
                      " mesi, centrata)"),
       subtitle = paste("Standardizzazione su finestra mobile al posto della media mobile:",
                        "i tre fattori sono ora sulla stessa scala.",
                        "\nLinee rosse tratteggiate: soglia |z| = 2. Punti rossi: mesi oltre soglia"),
       x = NULL, y = "z-score (deviazioni standard)") +
  plot_theme +
  theme(strip.text = element_text(face = "bold"), legend.position = "none")

ggsave(file.path(output_dir, "scores_rolling_zscore.pdf"), g_z,
       width = 11, height = 9, device = cairo_pdf)
cat("Salvato: scores_rolling_zscore.pdf\n")

# ==============================================================
# 5. RIEPILOGO NUMERICO (console + CSV)
# ==============================================================

cat("\n=== 5. RIEPILOGO PER PERIODO ===\n")

riepilogo <- rbindlist(lapply(res, function(r) {
  # quota del movimento osservato spiegata usando 1, 2, 3 componenti
  quota <- sapply(1:3, function(k) {
    appross <- r$drift + rowSums(r$contributi[, 1:k, drop = FALSE])
    1 - sum((appross - r$var_oss)^2) / sum(r$var_oss^2)
  })
  data.table(
    periodo      = r$p$label,
    da           = format(r$data_inizio, "%Y-%m-%d"),
    a            = format(r$data_fine,   "%Y-%m-%d"),
    n_mesi       = r$n_mesi,
    var_1Y_bp    = round(r$var_oss[1]  * 1e4, 1),
    var_5Y_bp    = round(r$var_oss[5]  * 1e4, 1),
    var_10Y_bp   = round(r$var_oss[10] * 1e4, 1),
    var_20Y_bp   = round(r$var_oss[20] * 1e4, 1),
    somma_PC1_bp = round(r$somma_scores[1] * 1e4, 1),
    somma_PC2_bp = round(r$somma_scores[2] * 1e4, 1),
    somma_PC3_bp = round(r$somma_scores[3] * 1e4, 1),
    quota_k1     = round(100 * quota[1], 1),
    quota_k2     = round(100 * quota[2], 1),
    quota_k3     = round(100 * quota[3], 1)
  )
}))
print(riepilogo)

csv_file <- file.path(output_dir, "riepilogo_periodi.csv")
fwrite(riepilogo, csv_file)
cat("\nSalvato:", basename(csv_file), "\n")

# Dettaglio tenor per tenor, stampato per ispezione manuale
for (r in res) {
  cat("\n---", r$p$titolo, "---\n")
  print(data.table(
    scadenza     = maturity_num,
    liv_inizio_p = round(r$liv_inizio * 100, 3),
    liv_fine_p   = round(r$liv_fine   * 100, 3),
    var_bp       = round(r$var_oss * 1e4, 1),
    contr_PC1    = round(r$contributi[, 1] * 1e4, 1),
    contr_PC2    = round(r$contributi[, 2] * 1e4, 1),
    contr_PC3    = round(r$contributi[, 3] * 1e4, 1)
  ))
}

cat("\n=== COMPLETATO. Output in:", normalizePath(output_dir), "===\n")
