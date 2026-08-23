# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Smith-Wilson, dicembre 2025: TRE SCENARI
#  Companion di dispense/03b_eiopa_rfr_smith_wilson_dic2025.tex
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Confronta tre modi di ricostruire la curva EIOPA di dicembre 2025, cambiando
#  una variabile alla volta:
#    Scenario 1 — par EUSA* + alpha* (zero del criterio sez. 9.14)
#    Scenario 2 — par EUSA* + alpha ufficiale EIOPA
#    Scenario 3 — nodi della curva RFR ufficiale (convenzione zero-coupon) +
#                 alpha ufficiale EIOPA
#  1 vs 2: isola l'effetto della scelta di alpha (stessi dati).
#  2 vs 3: isola l'effetto della fonte dati (stesso alpha).
#
#  Funzioni core ricopiate da 03_eiopa_rfr_smith_wilson.R (script autosufficiente).
#  Riferimento: EIOPA-BoS-25-599, Sez. 9 (Smith-Wilson).
#  Dati: dati/03_eusa.xlsx (par IRS EUR vs EURIBOR 6M, ticker Bloomberg EUSA*);
#  curva ufficiale: dati/eiopa_zips/EIOPA_RFR_20251231.zip.
#
#  Esecuzione (dalla cartella R/):
#    "/c/Program Files/R/R-4.4.2/bin/Rscript.exe" 03b_eiopa_rfr_smith_wilson_dic2025.R
# ==============================================================================

# ---- 0. SETUP ----------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
})
have_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

dir_out <- file.path(dirname(getwd()), "output", "03b_eiopa_rfr_smith_wilson_dic2025")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)
# Pulizia: rimuove gli artefatti di esecuzioni precedenti (rinominati in questa
# riscrittura) per non lasciare file orfani con i vecchi nomi.
old_files <- list.files(dir_out, full.names = TRUE)
if (length(old_files) > 0) unlink(old_files)

theme_dispensa <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, color = "gray30"),
    legend.position  = "bottom"
  )

col_spot <- "#185FA5"
col_fwd  <- "#993C1D"
col_ufr  <- "#7060CC"
col_par  <- "black"

save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

# ---- PARAMETRI EIOPA EUR (sez. 9.2-9.4; Annex E) -----------------------------
UFR_ann <- 0.0330
omega   <- log(1 + UFR_ann)
LLP     <- 20
CP      <- max(LLP + 40, 60)
CRA     <- 0.0010
tau     <- 1e-4
a_min   <- 0.05

T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 20)
N     <- length(T_mkt)

u_pay <- seq_len(LLP)
m     <- length(u_pay)

cat("\n=====================================================================\n")
cat("  Curva EIOPA EUR — Smith-Wilson, dicembre 2025: TRE SCENARI\n")
cat("=====================================================================\n\n")

# ==============================================================================
# 1. FUNZIONI CORE SMITH-WILSON (identiche a 03_eiopa_rfr_smith_wilson.R)
# ==============================================================================

H_heart <- function(u, v, a) {
  mn <- pmin(u, v); Mx <- pmax(u, v)
  a * mn - exp(-a * Mx) * sinh(a * mn)
}
G_heart <- function(v, u, a) {
  ifelse(v <= u,
         a - a * exp(-a * u) * cosh(a * v),
         a * exp(-a * v) * sinh(a * u))
}

build_C <- function(maturities, rates) {
  n <- length(maturities)
  C <- matrix(0, m, n)
  for (k in seq_len(n)) {
    Tk <- maturities[k]; rk <- rates[k]
    if (Tk > 1) C[1:(Tk - 1), k] <- rk
    C[Tk, k] <- 1 + rk
  }
  C
}

# Convenzione "zero-coupon" (strumento GVT, sez. 8-9 EIOPA-BoS-26-198): un
# tasso spot r_k paga un unico flusso (1+r_k)^Tk alla scadenza Tk, nessuna
# cedola intermedia. Usata per calibrare sui nodi della curva RFR ufficiale
# (gia' tassi zero, non par swap).
build_C_zero <- function(maturities, spot_rates) {
  n <- length(maturities)
  C <- matrix(0, m, n)
  for (k in seq_len(n)) {
    Tk <- maturities[k]
    C[Tk, k] <- (1 + spot_rates[k]) ^ Tk
  }
  C
}

# maturities/rates ignorati se si passa C direttamente (solo length(maturities)
# serve per il vettore p).
sw_system <- function(maturities, rates, a, C = NULL) {
  if (is.null(C)) C <- build_C(maturities, rates)
  d  <- exp(-omega * u_pay)
  Q  <- C * d
  q  <- as.numeric(t(C) %*% d)
  Hm <- outer(u_pay, u_pay, H_heart, a = a)
  QHQ <- t(Q) %*% Hm %*% Q
  list(C = C, d = d, Q = Q, q = q, H = Hm, QHQ = QHQ, p = rep(1, length(maturities)))
}

sw_calibrate <- function(maturities, rates, a, C = NULL) {
  sys <- sw_system(maturities, rates, a, C = C)
  rhs <- sys$p - sys$q
  R   <- chol(sys$QHQ)
  b   <- backsolve(R, forwardsolve(t(R), rhs))
  Qb  <- as.numeric(sys$Q %*% b)
  c(sys, list(b = b, Qb = Qb))
}

sw_P <- function(v, Qb, a) {
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  exp(-omega * v) * (1 + Hv)
}
sw_spot_int <- function(v, Qb, a) -log(sw_P(v, Qb, a)) / v
sw_spot_ann <- function(v, Qb, a) exp(sw_spot_int(v, Qb, a)) - 1
sw_fwd_int  <- function(v, Qb, a) {
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  Gv <- sapply(v, function(x) sum(G_heart(x, u_pay, a) * Qb))
  omega - Gv / (1 + Hv)
}
sw_fwd_ann  <- function(v, Qb, a) exp(sw_fwd_int(v, Qb, a)) - 1

# Ricerca di zeri comune (sez. 9.14): piu' piccolo alpha>=a_min con
# |f(CP,alpha)-omega|<=tau, dato un qualunque modo di calibrare Qb(alpha).
find_alpha_star <- function(qb_of_alpha) {
  gfun <- function(a) abs(sw_fwd_int(CP, qb_of_alpha(a), a) - omega) - tau
  lo <- 0.02; hi <- 0.30; flo <- gfun(lo); fhi <- gfun(hi)
  if (flo * fhi > 0) {
    a_unc <- if (gfun(a_min) <= 0) a_min else hi
  } else {
    for (k in 1:80) {
      mid <- 0.5 * (lo + hi); gm <- gfun(mid)
      if (sign(gm) == sign(flo)) { lo <- mid; flo <- gm } else hi <- mid
      if ((hi - lo) < 1e-7) break
    }
    a_unc <- 0.5 * (lo + hi)
  }
  max(a_min, a_unc)
}

alpha_star_for_mat <- function(rates, maturities) {
  find_alpha_star(function(a) sw_calibrate(maturities, rates, a)$Qb)
}

# Variante: calibrazione da una matrice C gia' costruita (es. nodi zero-coupon).
alpha_star_for_C <- function(C, maturities) {
  find_alpha_star(function(a) sw_calibrate(maturities, NULL, a, C = C)$Qb)
}

# Lettura curva ufficiale EIOPA (foglio RFR_spot_no_VA dello zip del mese)
read_eiopa_official <- function(date) {
  if (!have_openxlsx) return(NULL)
  zdir <- file.path(dirname(getwd()), "dati", "eiopa_zips")
  ym   <- format(date, "%Y%m")
  tryCatch({
    zf <- list.files(zdir, pattern = paste0("^EIOPA_RFR_", ym, "[0-9]{2}\\.zip$"),
                     full.names = TRUE)
    if (length(zf) == 0) return(NULL)
    zf <- zf[1]
    inner <- utils::unzip(zf, list = TRUE)$Name
    ts <- grep("Term_Structures", inner, value = TRUE, ignore.case = TRUE)[1]
    if (is.na(ts)) return(NULL)
    utils::unzip(zf, files = ts, exdir = tempdir(), overwrite = TRUE)
    raw  <- openxlsx::read.xlsx(file.path(tempdir(), ts),
                                sheet = "RFR_spot_no_VA", colNames = FALSE,
                                skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    lab  <- raw[[2]]; val <- raw[[3]]
    getp <- function(name) as.numeric(val[which(lab == name)[1]])
    CRA_bps <- getp("CRA")
    mlab <- suppressWarnings(as.numeric(lab))
    sel  <- which(!is.na(mlab) & mlab >= 1 & mlab <= 150)
    mat  <- mlab[sel]; spot <- suppressWarnings(as.numeric(val[sel]))
    ok   <- !is.na(mat) & !is.na(spot)
    list(CRA   = CRA_bps,
         alpha = getp("alpha"),
         zip   = basename(zf),
         mat   = mat[ok], spot = spot[ok])
  }, error = function(e) NULL)
}

# Lettura par EUSA da 03_eusa.xlsx (12 mesi x 15 scadenze)
read_eusa_all <- function() {
  f <- file.path(dirname(getwd()), "dati", "03_eusa.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 1, detectDates = TRUE)
    dcol  <- df[[1]]
    dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    M <- as.matrix(df[, -1]); storage.mode(M) <- "numeric"
    keep <- !is.na(dates) & rowSums(is.na(M)) == 0 & ncol(M) == N
    data.frame(date = dates[keep], M[keep, , drop = FALSE] / 100, check.names = FALSE)
  }, error = function(e) NULL)
}

# ==============================================================================
# 2. DATI COMUNI: par EUSA*, curva ufficiale, nodi RFR ufficiali (dicembre 2025)
# ==============================================================================

eusa_all <- read_eusa_all()
if (is.null(eusa_all)) stop("Impossibile leggere dati/03_eusa.xlsx")

d_dic   <- as.Date("2025-12-31")
off_dic <- read_eiopa_official(d_dic)
if (is.null(off_dic)) stop("Curva ufficiale EIOPA non trovata per dicembre 2025 (EIOPA_RFR_20251231.zip)")

if (!any(eusa_all$date == d_dic)) stop("Par rate EUSA* non disponibili per il 31/12/2025 in dati/03_eusa.xlsx")
s_dic   <- as.numeric(eusa_all[eusa_all$date == d_dic, -1])
CRA_dic <- if (is.finite(off_dic$CRA)) off_dic$CRA / 1e4 else CRA
r_dic   <- s_dic - CRA_dic                                   # par EUSA after-CRA
a_dic   <- if (is.finite(off_dic$alpha)) off_dic$alpha else alpha_star_for_mat(r_dic, T_mkt)
lab_dic <- "Dicembre 2025"

r_zero_dic <- off_dic$spot[match(T_mkt, off_dic$mat)]        # nodi RFR ufficiali, gia' al netto del CRA
if (!all(is.finite(r_zero_dic))) {
  stop("Curva ufficiale EIOPA priva di uno o piu' tenor DLT {1..13,15,20} richiesti")
}

cat(sprintf("Mese: %s  (zip %s)\n", lab_dic, off_dic$zip))
cat(sprintf("  CRA = %.0f bps,  alpha ufficiale EIOPA = %.4f\n\n", CRA_dic * 1e4, a_dic))

C_eusa     <- build_C(T_mkt, r_dic)
C_zero_dic <- build_C_zero(T_mkt, r_zero_dic)

a_dic_crit <- alpha_star_for_mat(r_dic, T_mkt)                # alpha* (criterio) sui dati EUSA
a_rfr_crit <- alpha_star_for_C(C_zero_dic, T_mkt)             # alpha* (criterio) sui nodi RFR ufficiali
cat(sprintf("  alpha* (criterio, EUSA)     = %.4f\n", a_dic_crit))
cat(sprintf("  alpha* (criterio, nodi RFR) = %.4f\n\n", a_rfr_crit))

# --- Tabelle dati di input -----------------------------------------------------
tab_input_eusa <- data.frame(
  Tenor        = T_mkt,
  EUSA_pct     = round(s_dic * 100, 4),
  afterCRA_pct = round(r_dic * 100, 4)
)
cat("  Par rate EUSA* e after-CRA (dicembre 2025):\n")
print(tab_input_eusa, row.names = FALSE)
write.csv(tab_input_eusa, file.path(dir_out, "tab_input_eusa_dic.csv"), row.names = FALSE)

tab_input_rfr <- data.frame(
  Tenor              = T_mkt,
  RFR_ufficiale_pct  = round(r_zero_dic * 100, 4)
)
cat("\n  Tassi RFR ufficiali ai 15 nodi DLT (gia' al netto del CRA):\n")
print(tab_input_rfr, row.names = FALSE)
write.csv(tab_input_rfr, file.path(dir_out, "tab_input_rfr_dic.csv"), row.names = FALSE)

# --- tab_C_dicembre: matrice dei flussi di cassa C (20x15), convenzione swap --
write_C_latex <- function(C, maturities, out_file, mese_lab) {
  m <- nrow(C); n <- ncol(C)
  lines <- c(
    "% GENERATO AUTOMATICAMENTE da 03b_eiopa_rfr_smith_wilson_dic2025.R",
    "\\begin{table}[H]",
    "\\centering",
    paste0("\\caption{Matrice dei flussi di cassa $\\mathbf{C}\\in\\mathbb{R}^{20\\times 15}$,",
           " ", mese_lab, ". Celle \\colorbox{cyan!20}{azzurre} = cedola $r_j$;",
           " celle \\colorbox{orange!35}{arancio} = cedola$+$rimborso $1{+}r_j$;",
           " punti = flusso nullo.}"),
    "\\label{tab:C-dicembre}",
    "\\resizebox{\\textwidth}{!}{%",
    "\\renewcommand{\\arraystretch}{1.15}",
    "\\scriptsize",
    paste0("\\begin{tabular}{r|", paste(rep("r", n), collapse = ""), "}")
  )
  hdr <- paste0("$u_i\\backslash T_j$ & ",
                paste(sprintf("\\textbf{%dY}", maturities), collapse = " & "),
                " \\\\")
  lines <- c(lines, "\\toprule", hdr, "\\midrule")
  for (i in seq_len(m)) {
    cells <- character(n)
    for (j in seq_len(n)) {
      Tj <- maturities[j]; v <- C[i, j]
      if (i < Tj) {
        cells[j] <- sprintf("\\cellcolor{cyan!18}$%.4f$", v)
      } else if (i == Tj) {
        cells[j] <- sprintf("\\cellcolor{orange!35}$\\mathbf{%.4f}$", v)
      } else {
        cells[j] <- "$\\cdot$"
      }
    }
    lines <- c(lines, paste0("$", i, "$ & ", paste(cells, collapse = " & "), " \\\\"))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}}", "\\end{table}")
  writeLines(lines, out_file)
  cat(sprintf("  [OK] %s\n", out_file))
}
write_C_latex(C_eusa, T_mkt, file.path(dir_out, "tab_C_dicembre.tex"), "dicembre~2025")

# ==============================================================================
# 3. IL PARAMETRO ALPHA: due criteri a confronto (per EUSA e per i nodi RFR)
# ==============================================================================

a_grid <- seq(a_min, 0.30, length.out = 200)

plot_alpha_criterio <- function(C, a_crit, a_uff, titolo, sub_lab) {
  g_vals <- sapply(a_grid, function(a)
    (sw_fwd_int(CP, sw_calibrate(T_mkt, NULL, a, C = C)$Qb, a) - omega) * 1e4)
  df_g <- data.frame(alpha = a_grid, g = g_vals)
  ggplot(df_g, aes(x = alpha, y = g)) +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = -1, ymax = 1,
             fill = "gray85", alpha = 0.5) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
    geom_line(linewidth = 1, color = col_fwd) +
    geom_vline(xintercept = a_crit, color = col_spot, linetype = "dashed", linewidth = 0.6) +
    geom_vline(xintercept = a_uff, color = "#2E7D32", linetype = "dotdash", linewidth = 0.5) +
    geom_vline(xintercept = a_min, color = "gray55", linetype = "dotted", linewidth = 0.5) +
    annotate("text", x = a_min, y = max(df_g$g) * 0.55,
             label = sprintf("alpha_min = %.2f", a_min),
             hjust = -0.1, color = "gray40", size = 3.3) +
    labs(title = titolo,
         subtitle = sprintf(paste0("g(alpha) = f(CP, alpha) - omega in bps; banda grigia = +/-1 bp.\n",
                                   "Linea blu tratteggiata: alpha* = %.4f (%s); linea verde: alpha EIOPA = %.4f"),
                            a_crit, sub_lab, a_uff),
         x = expression(alpha), y = "f(CP, alpha) - omega  (bps)") +
    theme_dispensa
}

p_alpha_eusa <- plot_alpha_criterio(C_eusa, a_dic_crit, a_dic,
                                     sprintf("Calibrazione di alpha — dati EUSA*, %s", lab_dic),
                                     "criterio, dati EUSA*")
save_fig("fig_alpha_eusa_dic", p_alpha_eusa)

p_alpha_rfr <- plot_alpha_criterio(C_zero_dic, a_rfr_crit, a_dic,
                                    sprintf("Calibrazione di alpha — nodi RFR ufficiali, %s", lab_dic),
                                    "criterio, nodi RFR")
save_fig("fig_alpha_rfr_dic", p_alpha_rfr)

cat(sprintf("  Divario alpha*-alpha_uff:  EUSA = %.4f ; nodi RFR = %.4f\n\n",
            a_dic_crit - a_dic, a_rfr_crit - a_dic))

# ==============================================================================
# 4. ESECUZIONE DEI TRE SCENARI
# ==============================================================================

# mats_all/sp_off_all/df_vs_off/grid_f sono condivisi da tutti gli scenari
mats_all    <- 1:80
sp_off_all  <- off_dic$spot[match(mats_all, off_dic$mat)] * 100
off_spot_60 <- off_dic$spot[match(1:60, off_dic$mat)] * 100
ok60        <- is.finite(off_spot_60)
df_vs_off   <- data.frame(T = (1:60)[ok60], val = off_spot_60[ok60])
grid_f      <- seq(0.5, 60, by = 0.25)

# Esegue un intero scenario di ricostruzione: calibrazione, confronto con la
# curva ufficiale (overlay + scarti), tabella/figura dei residui nodo per
# nodo, e le metriche RMSE/max in zona liquida ed in estrapolazione.
run_scenario <- function(label, slug, C, alpha) {
  cat(sprintf("--- %s (alpha = %.4f) ---\n", label, alpha))
  Qb <- sw_calibrate(T_mkt, NULL, alpha, C = C)$Qb

  P_pay   <- sw_P(u_pay, Qb, alpha)
  rep_err <- max(abs(t(C) %*% P_pay - 1))

  # --- curva spot + forward -----------------------------------------------
  df_curve <- rbind(
    data.frame(T = grid_f, val = sw_spot_ann(grid_f, Qb, alpha) * 100, Serie = "Spot r(0,T)"),
    data.frame(T = grid_f, val = sw_fwd_ann (grid_f, Qb, alpha) * 100, Serie = "Forward f(0,T)")
  )
  p_curve <- ggplot(df_curve, aes(x = T, y = val, color = Serie)) +
    geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    annotate("text", x = 59, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
             hjust = 1, color = col_ufr, size = 3.4) +
    labs(title = sprintf("Curva Smith-Wilson calibrata — %s", label),
         subtitle = sprintf("alpha = %.4f. Spot r(0,T) e forward f(0,T). Linea viola = UFR = 3.30%%.", alpha),
         x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) +
    theme_dispensa
  save_fig(paste0("fig_curve_", slug, "_dic"), p_curve)

  # --- confronto con la curva ufficiale, pannello doppio -------------------
  sw_all     <- sw_spot_ann(mats_all, Qb, alpha) * 100
  res_all    <- (sw_all - sp_off_all) * 100                 # bps
  ok_all     <- is.finite(res_all)
  res_nodi   <- res_all[match(T_mkt, mats_all)]
  sw_nodi    <- sw_all[match(T_mkt, mats_all)]
  RMSE_liq   <- sqrt(mean(res_nodi^2))
  max_liq    <- max(abs(res_nodi))
  extra_sel  <- mats_all > LLP & ok_all
  RMSE_extra <- sqrt(mean(res_all[extra_sel]^2))
  max_extra  <- max(abs(res_all[extra_sel]))
  ylim_res   <- max(2, ceiling(max(abs(res_all[ok_all]))))

  df_vs_sw <- data.frame(T = grid_f, val = sw_spot_ann(grid_f, Qb, alpha) * 100)
  p_top <- ggplot() +
    geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(data = df_vs_sw, aes(x = T, y = val, color = "SW ricostruito"), linewidth = 1.1) +
    geom_point(data = df_vs_off, aes(x = T, y = val, color = "EIOPA ufficiale"),
               shape = 21, size = 1.6, fill = "white", stroke = 1.0) +
    annotate("text", x = 59, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
             hjust = 1, color = col_ufr, size = 3.2) +
    scale_color_manual(values = c("SW ricostruito" = col_spot, "EIOPA ufficiale" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = sprintf("%s vs EIOPA ufficiale", label),
         subtitle = "Tasso spot annuo",
         x = NULL, y = "Tasso spot (%)", color = NULL) +
    theme_dispensa + theme(legend.position = "top")

  df_res <- data.frame(T    = mats_all[ok_all],
                        Res  = res_all[ok_all],
                        Zona = ifelse(mats_all[ok_all] <= LLP, "Liquida", "Estrapolazione"))
  df_res$Zona <- factor(df_res$Zona, levels = c("Liquida", "Estrapolazione"))
  p_bot <- ggplot(df_res, aes(x = T, y = Res, fill = Zona)) +
    geom_col(width = 0.9) +
    geom_vline(xintercept = LLP + 0.5, color = "gray50", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    geom_hline(yintercept = c(-2, 2), color = "gray65", linetype = "dotted", linewidth = 0.35) +
    annotate("text", x = LLP + 1, y = ylim_res * 0.85, label = "LLP = 20a",
             hjust = 0, color = "gray40", size = 3.2) +
    scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 60, 80)) +
    scale_y_continuous(limits = c(-ylim_res, ylim_res)) +
    labs(subtitle = sprintf(paste0("Scarto SW - EIOPA (bps, tenor 1-80a). Linee tratteggiate: +/-2 bps. ",
                                    "RMSE liquida = %.2f bps, RMSE estrapolazione = %.2f bps."),
                            RMSE_liq, RMSE_extra),
         x = "Scadenza T (anni)", y = "Scarto (bps)", fill = NULL) +
    theme_dispensa + theme(legend.position = "top")

  path_vs <- file.path(dir_out, paste0("fig_vs_eiopa_", slug, "_dic.pdf"))
  pdf(path_vs, width = 9, height = 7.5)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    2, 1, heights = grid::unit(c(2, 1), "null"))))
  print(p_top, vp = grid::viewport(layout.pos.row = 1))
  print(p_bot, vp = grid::viewport(layout.pos.row = 2))
  dev.off()
  cat(sprintf("  [OK] %s\n", path_vs))

  # --- tabella e figura dei residui nodo per nodo ---------------------------
  tab_nodi <- data.frame(
    Tenor          = T_mkt,
    SW_zero_pct    = round(sw_nodi, 4),
    EIOPA_zero_pct = round(off_dic$spot[match(T_mkt, off_dic$mat)] * 100, 4),
    delta_bps      = round(res_nodi, 2)
  )
  cat("  Residui nodo per nodo (SW - EIOPA ufficiale):\n")
  print(tab_nodi, row.names = FALSE)
  write.csv(tab_nodi, file.path(dir_out, paste0("tab_residui_", slug, "_dic.csv")), row.names = FALSE)

  df_bar <- data.frame(T = factor(T_mkt, levels = T_mkt), delta = res_nodi)
  p_bar <- ggplot(df_bar, aes(x = T, y = delta)) +
    geom_col(fill = col_spot, width = 0.7) +
    geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    labs(title = sprintf("Residui ai 15 nodi DLT — %s", label),
         subtitle = "SW ricostruito - EIOPA ufficiale (bps)",
         x = "Scadenza T (anni)", y = "Scarto (bps)") +
    theme_dispensa
  save_fig(paste0("fig_residui_", slug, "_dic"), p_bar, w = 8, h = 4.5)

  cat(sprintf("  riprezzamento max|C'P-1|=%.2e   RMSE_liq=%.3f  max_liq=%.3f   RMSE_extra=%.3f  max_extra=%.3f\n\n",
              rep_err, RMSE_liq, max_liq, RMSE_extra, max_extra))

  list(label = label, slug = slug, alpha = alpha, rep_err = rep_err,
       RMSE_liq = RMSE_liq, max_liq = max_liq, RMSE_extra = RMSE_extra, max_extra = max_extra)
}

res1 <- run_scenario("Scenario 1: EUSA* + alpha* (criterio)",       "s1", C_eusa,     a_dic_crit)
res2 <- run_scenario("Scenario 2: EUSA* + alpha ufficiale EIOPA",   "s2", C_eusa,     a_dic)
res3 <- run_scenario("Scenario 3: nodi RFR ufficiali + alpha uff.", "s3", C_zero_dic, a_dic)

# ==============================================================================
# 5. TABELLA RIASSUNTIVA E DIAGNOSTICA FINALE
# ==============================================================================

tab_summary <- data.frame(
  Scenario         = c(res1$label, res2$label, res3$label),
  alpha            = round(c(res1$alpha, res2$alpha, res3$alpha), 4),
  RMSE_liquida_bps = round(c(res1$RMSE_liq, res2$RMSE_liq, res3$RMSE_liq), 3),
  max_liquida_bps  = round(c(res1$max_liq, res2$max_liq, res3$max_liq), 3),
  RMSE_estrap_bps  = round(c(res1$RMSE_extra, res2$RMSE_extra, res3$RMSE_extra), 3),
  max_estrap_bps   = round(c(res1$max_extra, res2$max_extra, res3$max_extra), 3)
)
cat("\n=====================================================================\n")
cat("  CONFRONTO COMPLESSIVO DEI TRE SCENARI\n")
cat("=====================================================================\n")
print(tab_summary, row.names = FALSE)
write.csv(tab_summary, file.path(dir_out, "tab_summary_scenari_dic.csv"), row.names = FALSE)

cat(sprintf("\n  Effetto alpha (Scenario 1 -> 2, stessi dati EUSA*):\n"))
cat(sprintf("    RMSE estrapolazione: %.3f -> %.3f bps\n", res1$RMSE_extra, res2$RMSE_extra))
cat(sprintf("  Effetto fonte dati (Scenario 2 -> 3, stesso alpha ufficiale):\n"))
cat(sprintf("    RMSE estrapolazione: %.3f -> %.3f bps\n\n", res2$RMSE_extra, res3$RMSE_extra))

cat("=====================================================================\n")
cat("  FIGURE GENERATE in:", dir_out, "\n")
cat("=====================================================================\n")
for (f in list.files(dir_out, pattern = "\\.pdf$")) cat("  -", f, "\n")
cat("\n")
