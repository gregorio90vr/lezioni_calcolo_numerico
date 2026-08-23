# ==============================================================================
#  Dispensa 02 (ufficiale) — Curva EIOPA Risk-Free: i due metodi a confronto
#  Script 1/2 — metodo A BOOTSTRAP (EIOPA-BoS-26-198)
#  Genera dispense/02_eiopa_rfr_bootstrap_smith_wilson.tex, Sez. 2 (parziale),
#  3, 5, 6.3, Appendice A.
#
#  Va eseguito PRIMA di R/02_eiopa_rfr_smith_wilson.R: a fine script esporta
#  la curva ricostruita in curva_bootstrap_dic2025.csv, dentro la stessa
#  cartella di output condivisa -- lo script Smith-Wilson la rilegge per
#  generare il confronto di Sez. 7 (serve ENTRAMBE le curve insieme, e i due
#  script sono due processi R separati: niente sopravvive in memoria da uno
#  all'altro). Stesso pattern gia' in uso nel repo tra 04_pca_ecb_prep.R e
#  04_pca_ecb.R/04b_pca_ecb.R (xlsx intermedio in dati/).
#
#  Destinazione: ../output/02_eiopa_rfr_bootstrap_smith_wilson/ (condivisa
#  con R/02_eiopa_rfr_smith_wilson.R).
#
#  Input:  ../dati/02_swap_euribor6m_ric_dic2025.xlsx   (par swap input EIOPA)
#          ../dati/02_dec25_eiopa_rfr_newapproach.csv   (benchmark nuovo metodo)
# ==============================================================================

rm(list = ls())

# ==============================================================================
# PARTE 0 — SETUP
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(reshape2)
})
have_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)
if (!have_openxlsx) stop("Il pacchetto openxlsx e' necessario per leggere i dati di input.")

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

root    <- dirname(getwd())                       # radice del progetto (cwd = R/)
dir_dat <- file.path(root, "dati")
dir_out <- file.path(root, "output", "02_eiopa_rfr_bootstrap_smith_wilson")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

# --- tema e colori (unici per tutta la dispensa; duplicati in
#     02_eiopa_rfr_smith_wilson.R -- stessa indipendenza gia' seguita da
#     04_pca_ecb.R/04b_pca_ecb.R, che duplicano il proprio setup pur
#     condividendo l'input) ------------------------------------------------
theme_dispensa <- theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title       = element_text(face = "bold", size = 13),
        plot.subtitle    = element_text(size = 10, color = "gray30"),
        legend.position  = "bottom")

col_spot <- "#185FA5"   # blu   — tasso spot / metodo a bootstrap
col_fwd  <- "#993C1D"   # rosso — forward / Smith-Wilson
col_ufr  <- "#7060CC"   # viola — UFR
col_obs  <- "#B2182B"   # rosso acceso — punti notevoli
col_nodi <- "black"     # nodi di mercato

save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  ggsave(file.path(dir_out, paste0(nome, ".pdf")), plot = plot_obj,
         width = w, height = h, device = "pdf")
  message("  [OK] ", nome, ".pdf")
}
save_tab <- function(nome, lines) {
  writeLines(lines, file.path(dir_out, paste0(nome, ".tex")))
  message("  [OK] ", nome, ".tex")
}
# alternanza colore righe nelle tabelle (stile della dispensa)
tint <- function(i) if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""

GEN <- "% GENERATO da R/02_eiopa_rfr_bootstrap.R"

# Benchmark like-for-like: curva ufficiale RICALCOLATA da EIOPA col nuovo metodo
read_eiopa_newmethod <- function() {
  f <- file.path(dir_dat, "02_dec25_eiopa_rfr_newapproach.csv")
  if (!file.exists(f)) return(NULL)
  tryCatch({
    df <- read.csv(f, stringsAsFactors = FALSE)
    tt <- as.integer(sub("^YR", "", df$tenor)); zz <- as.numeric(df[[2]])
    ok <- !is.na(tt) & !is.na(zz)
    data.table(tenor = tt[ok], rann = zz[ok])
  }, error = function(e) NULL)
}

cat("\n=====================================================================\n")
cat("  DISPENSA 02 (bootstrap) -> ", normalizePath(dir_out, mustWork = FALSE), "\n")
cat("=====================================================================\n\n")

# ==============================================================================
# PARTE A — IL METODO A BOOTSTRAP (EIOPA-BoS-26-198)
# ==============================================================================

# --- A.1 dati di input --------------------------------------------------------
swap_in <- data.table(openxlsx::read.xlsx(
  file.path(dir_dat, "02_swap_euribor6m_ric_dic2025.xlsx")))
cra_eur   <- 10 / 1e4          # CRA = 10 bps (EUR)
fsp       <- 20                # First Smoothing Point
max_tenor <- max(swap_in[, tenor])

# par rate after-CRA, indicizzati per tenor intero (0 dove non quotato)
s_post <- rep(0, max_tenor)
for (i in swap_in[, tenor]) s_post[i] <- swap_in[tenor == i, swap_inputEUR] - cra_eur
tenor_oss <- sort(swap_in[, tenor])          # 1..13, 15, 20, 25, 30, 40, 50

# --- A.2 bootstrap dei tenor consecutivi (Annex D.4-D.5) ----------------------
# La condizione par ai tenor 1..13 da' un sistema TRIANGOLARE INFERIORE: si
# risolve per sostituzione in avanti, un fattore di sconto alla volta.
n_data <- 13
L <- matrix(0, n_data, n_data)
for (i in seq_len(n_data)) for (j in seq_len(i))
  L[i, j] <- if (i == j) 1 + s_post[i] else s_post[i]

dtk  <- rep(NA_real_, max_tenor)
dtk[1:n_data] <- solve(L, rep(1, n_data))

# --- A.3 tenor non consecutivi: forward costante nel gap + Newton -------------
# Nei "buchi" (13->15, 15->20, 20->25, ...) l'incognita e' il forward annuale f,
# costante nel gap; la condizione par al tenor di chiusura da' phi(f) = 0.
phi <- function(f, s2, s1, gap, d_prev) {
  dstar <- (1 + f)^(-gap)
  s2 * (1 - dstar) / f + dstar + ((s2 - s1) / s1) * ((1 - d_prev) / d_prev) - 1
}
dphi <- function(f, s2, s1, gap) {
  dstar     <- (1 + f)^(-gap)
  dstar_der <- -gap * (1 + f)^(-gap - 1)
  s2 * ((-f * dstar_der - (1 - dstar)) / f^2) + dstar_der
}
# Newton tracciato: una riga per iterazione (serve anche alle figure/tabelle)
newton_traccia <- function(s2, s1, d_prev, g, f0, tol = 1e-16, nmax = 50) {
  out <- data.table(k = 0L, f = f0, phi = phi(f0, s2, s1, g, d_prev), incr = NA_real_)
  f <- f0
  for (k in seq_len(nmax)) {
    fprev <- f
    f <- f - phi(f, s2, s1, g, d_prev) / dphi(f, s2, s1, g)
    out <- rbind(out, data.table(k = as.integer(k), f = f,
                                 phi = phi(f, s2, s1, g, d_prev), incr = abs(f - fprev)))
    if (abs(f - fprev) <= tol) break
  }
  out
}

rc_of <- function(d, t) -log(d) / t
newton_log <- list()       # tracce Newton, per fig04
f_gap      <- list()       # forward di gap risolti

for (idx in seq_along(tenor_oss)) {
  Tk <- tenor_oss[idx]
  if (Tk <= n_data) next                       # gia' risolti col sistema L
  Tprev <- tenor_oss[idx - 1]
  g     <- Tk - Tprev
  if (g > 1) {
    # forward costante nel gap: una ricerca di zeri scalare
    rc_prev  <- rc_of(dtk[Tprev], Tprev)
    rc_prev2 <- rc_of(dtk[Tprev - 1], Tprev - 1)
    f0  <- exp(Tprev * rc_prev - (Tprev - 1) * rc_prev2) - 1   # forward annuale in Tprev
    tr  <- newton_traccia(s_post[Tk], s_post[Tprev], dtk[Tprev], g, f0)
    fst <- tail(tr$f, 1)
    newton_log[[paste0(Tprev, "->", Tk)]] <- tr
    f_gap[[paste0(Tprev, "->", Tk)]]      <- fst
    for (i in seq_len(g - 1)) dtk[Tprev + i] <- dtk[Tprev] * (1 + fst)^(-i)
  }
  # chiusura al tenor quotato con la condizione par (sostituzione in avanti)
  dtk[Tk] <- (1 - s_post[Tk] * sum(dtk[1:(Tk - 1)])) / (1 + s_post[Tk])
}
stopifnot(!any(is.na(dtk)))

tt      <- seq_len(max_tenor)
rc      <- rc_of(dtk, tt)
rann    <- exp(rc) - 1
fwd_c   <- c(rc[1], tt[-1] * rc[-1] - tt[-max_tenor] * rc[-max_tenor])
curve   <- data.table(tenor = tt, swap_wo_cra = s_post, dtk = dtk,
                      rc = rc, rann = rann, fwd_c = fwd_c, fwd_ann = exp(fwd_c) - 1)

cat("  [A] bootstrap completato fino a", max_tenor, "anni\n")
for (nm in names(f_gap))
  cat(sprintf("      gap %-8s f* = %.8f%%  (%d iterazioni Newton)\n",
              nm, f_gap[[nm]] * 100, nrow(newton_log[[nm]]) - 1))

# --- A.4 LLFR: media pesata dei forward continui attorno all'FSP --------------
UFR_ann <- 3.3 / 100
UFR_c   <- log(1 + UFR_ann)
tenor_llfr <- c(20, 25, 30, 40, 50)
w_llfr     <- c(0.33, 0.12, 0.48, 0.04, 0.03)
rif_llfr   <- c(15, rep(fsp, length(tenor_llfr) - 1))   # tenor di partenza del forward
fwd_llfr   <- mapply(function(b, a) (curve[b, rc] * b - curve[a, rc] * a) / (b - a),
                     tenor_llfr, rif_llfr)
LLFR_c <- sum(fwd_llfr * w_llfr)
cat(sprintf("  [A] LLFR^c = %.6f%%   UFR^c = %.6f%%   (%.2f bps sotto l'UFR)\n",
            LLFR_c * 100, UFR_c * 100, (LLFR_c - UFR_c) * 1e4))

# --- A.5 estrapolazione e curva finale 1-150 ---------------------------------
B_weight  <- function(a, h) ifelse(h == 0, 1, (1 - exp(-a * h)) / (a * h))
alpha     <- 0.11                        # parametro di convergenza (regime)
tenor_max <- 150

curva_alpha <- function(a) {
  hh   <- seq_len(tenor_max - fsp)
  fc   <- UFR_c + (LLFR_c - UFR_c) * B_weight(a, hh)
  rc_e <- (fsp * curve[fsp, rc] + hh * fc) / (fsp + hh)
  data.table(tenor = seq_len(tenor_max),
             rc    = c(curve[1:fsp, rc],    rc_e),
             rann  = c(curve[1:fsp, rann],  exp(rc_e) - 1),
             fwd_c = c(curve[1:fsp, fwd_c], fc))
}
ext <- curva_alpha(alpha)
curve_finale <- data.table(
  tenor           = ext$tenor,
  discount_factor = c(curve[1:fsp, dtk], exp(-ext$rc[(fsp + 1):tenor_max] *
                                               ext$tenor[(fsp + 1):tenor_max])),
  rc = ext$rc, rann = ext$rann, fwd_c = ext$fwd_c, fwd_ann = exp(ext$fwd_c) - 1)

# --- A.6 esporta la curva per lo script Smith-Wilson (serve a Sez. 7) --------
fwrite(curve_finale, file.path(dir_out, "curva_bootstrap_dic2025.csv"))
cat("  [A] curva esportata in curva_bootstrap_dic2025.csv (per R/02_eiopa_rfr_smith_wilson.R)\n")

# ==============================================================================
# PARTE C — OUTPUT: FIGURE E TABELLE (parte bootstrap)
# ==============================================================================

# ------------------------------------------------------------------------------
# C.1  Sezione 2: fattori di sconto, spot e forward (illustrazioni comuni)
# ------------------------------------------------------------------------------
{
  sel <- curve_finale$tenor <= 25
  dfP <- data.table(T = curve_finale$tenor[sel], P = curve_finale$discount_factor[sel])
  pP <- ggplot(dfP, aes(x = T, y = P)) +
    geom_line(linewidth = 1, color = col_spot) +
    geom_point(data = dfP[T %in% tenor_oss], aes(x = T, y = P), color = col_nodi, size = 1.8) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25)) +
    labs(title = "Fattori di sconto P(0,t)",
         subtitle = "P(0,t) = prezzo oggi di 1 unita' pagata in t; decresce con la scadenza. Punti neri: tenor quotati",
         x = "Scadenza t (anni)", y = "P(0,t)") +
    theme_dispensa
  save_fig("fig_fattori_sconto", pP, w = 8, h = 5)
}

{   # spot continuo e forward istantaneo (curva ricostruita, 1-60 anni)
  sel <- curve_finale$tenor <= 60
  df_sf <- rbind(
    data.table(T = curve_finale$tenor[sel], val = curve_finale$rc[sel] * 100,
               Serie = "Spot r^c(t)"),
    data.table(T = curve_finale$tenor[sel], val = curve_finale$fwd_c[sel] * 100,
               Serie = "Forward f(t)"))
  p_sf <- ggplot(df_sf, aes(x = T, y = val, color = Serie)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Spot r^c(t)" = col_spot, "Forward f(t)" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = "Tasso spot r^c(t) e forward istantaneo f(t)",
         subtitle = "Il forward si muove piu' rapidamente: lo spot ne e' la media su [0,t] e reagisce con ritardo",
         x = "Scadenza t (anni)", y = "Tasso continuo (%)", color = NULL) +
    theme_dispensa
  save_fig("fig_spot_fwd_bootstrap", p_sf, w = 8, h = 5)
}

# ------------------------------------------------------------------------------
# C.2  Sezione 3 e 5.2: il metodo a bootstrap
# ------------------------------------------------------------------------------

# --- tabella dei dati di input (tenor / RIC / lordo / after-CRA / uso) --------
ric_of_tenor <- function(x) sprintf("EURAB6E%dY=", x)
{
  tab_in <- data.table(tenor = swap_in[, tenor], ric = ric_of_tenor(swap_in[, tenor]),
                       lordo = swap_in[, swap_inputEUR],
                       netto = swap_in[, swap_inputEUR] - cra_eur)
  tab_in[, uso := ifelse(tenor <= fsp, "bootstrap", "solo LLFR")]
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Tassi swap EUR di input a dicembre~2025 (valuation date 31/12/2025), ",
           "con il rispettivo \\emph{Reuters Instrument Code}. I ticker sono quelli prescritti ",
           "dalla documentazione ufficiale EIOPA per la curva risk-free EUR; il dato \\`e ",
           "acquisito da LSEG Data \\& Analytics (ex Refinitiv). Il CRA di ",
           sprintf("%d~bps ", round(cra_eur * 1e4)),
           "\\`e sottratto prima del bootstrap. \\`E il medesimo input usato anche dal metodo ",
           "Smith--Wilson in Sez.~\\ref{sec:ricostruzione-sw}.}"),
    "\\label{tab:input-ric-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rlccl}", "\\toprule",
    "$T_k$ (anni) & RIC & swap lordo (\\%) & after-CRA $s_k$ (\\%) & utilizzo\\\\", "\\midrule")
  for (i in seq_len(nrow(tab_in))) {
    uso_tex <- if (tab_in$uso[i] == "bootstrap") "bootstrap" else "solo $\\LLFR$"
    lines <- c(lines, sprintf("%s%d & \\texttt{%s} & %.4f & %.4f & %s\\\\",
                              tint(i), tab_in$tenor[i], tab_in$ric[i],
                              tab_in$lordo[i] * 100, tab_in$netto[i] * 100, uso_tex))
  }
  save_tab("tab_input_ric_dic", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}

# --- fig01: par swap lordi e after-CRA ---------------------------------------
{
  df_i <- rbind(
    data.table(T = swap_in$tenor, val = swap_in$swap_inputEUR * 100, Serie = "swap lordo"),
    data.table(T = swap_in$tenor, val = (swap_in$swap_inputEUR - cra_eur) * 100,
               Serie = "after-CRA"))
  p_i <- ggplot(df_i, aes(x = T, y = val, color = Serie, shape = Serie)) +
    geom_line(linewidth = 0.8) + geom_point(size = 2) +
    scale_color_manual(values = c("swap lordo" = col_obs, "after-CRA" = col_spot)) +
    scale_x_continuous(breaks = tenor_oss) +
    labs(title = "Par swap EUR di input EIOPA — dicembre 2025",
         subtitle = sprintf("15 scadenze DLT + i tenor 25-50 usati solo per l'LLFR; CRA = %d bps",
                            round(cra_eur * 1e4)),
         x = "Scadenza T (anni)", y = "Par rate (%)", color = NULL, shape = NULL) +
    theme_dispensa
  save_fig("fig01_input_par", p_i)
}

# --- fig02: curva zero ricostruita 1-20, nodi quotati vs interpolati ----------
{
  df_z <- data.table(T = 1:fsp, r = curve[1:fsp, rann] * 100)
  df_z[, Tipo := ifelse(T %in% tenor_oss, "quotato (DLT)", "da forward costante")]
  p_z <- ggplot(df_z, aes(x = T, y = r)) +
    geom_line(color = col_spot, linewidth = 0.9) +
    geom_point(aes(shape = Tipo, fill = Tipo), size = 2.6, color = col_spot, stroke = 0.9) +
    scale_shape_manual(values = c("quotato (DLT)" = 21, "da forward costante" = 21)) +
    scale_fill_manual(values = c("quotato (DLT)" = col_spot, "da forward costante" = "white")) +
    scale_x_continuous(breaks = 1:fsp) +
    labs(title = "Curva zero ricostruita per bootstrap — zona liquida (1-20 anni)",
         subtitle = "Cerchi pieni: tenor DLT quotati. Cerchi vuoti: 14 e 16-19, ricavati dall'ipotesi di forward costante",
         x = "Scadenza t (anni)", y = "Tasso zero annuo r(t) (%)",
         shape = NULL, fill = NULL) +
    theme_dispensa
  save_fig("fig02_bootstrap_zero", p_z)
}

# --- fig03: forward annuali, i "gradini" nei gap -----------------------------
{
  df_f <- data.table(T = 2:fsp, f = curve[2:fsp, fwd_ann] * 100)
  df_f[, Tratto := ifelse(T %in% c(14, 15), "gap 13->15",
                   ifelse(T %in% 16:20, "gap 15->20", "tenor consecutivi"))]
  p_f <- ggplot(df_f, aes(x = T, y = f)) +
    geom_step(direction = "mid", color = "gray55", linewidth = 0.5) +
    geom_point(aes(color = Tratto), size = 2.4) +
    scale_color_manual(values = c("tenor consecutivi" = col_spot,
                                  "gap 13->15" = col_obs, "gap 15->20" = col_fwd)) +
    scale_x_continuous(breaks = 2:fsp) +
    labs(title = "Forward annuali f(t-1,t) ricostruiti",
         subtitle = "Nei gap il forward e' costante per costruzione: si vedono i gradini piatti su 13->15 e 15->20",
         x = "Scadenza t (anni)", y = "Forward annuale (%)", color = NULL) +
    theme_dispensa
  save_fig("fig03_constant_forward", p_f)
}

# --- tabella della curva bootstrap 1-20 --------------------------------------
{
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva ricostruita per bootstrap nella zona liquida ($1\\le t\\le\\FSP$). ",
           "$d_t$ fattore di sconto, $r^c_t$ tasso zero continuo, $r_t$ tasso zero annuo ",
           "composto, $f_{t-1,t}$ forward annuale. I tenor contrassegnati con $\\dagger$ ",
           "(14, 16--19) non sono quotati: nascono dall'ipotesi di forward costante nei gap.}"),
    "\\label{tab:curva-bootstrap}\\renewcommand{\\arraystretch}{1.1}",
    "\\begin{tabular}{rcccc}", "\\toprule",
    "$t$ (anni) & $d_t$ & $r^c_t$ (\\%) & $r_t$ (\\%) & $f_{t-1,t}$ (\\%)\\\\", "\\midrule")
  for (t in 1:fsp) {
    mark <- if (t %in% tenor_oss) "" else "$^\\dagger$"
    fwd_str <- if (t == 1) "---" else sprintf("%.4f", curve[t, fwd_ann] * 100)
    lines <- c(lines, sprintf("%s%d%s & %.7f & %.4f & %.4f & %s\\\\",
                              tint(t), t, mark, curve[t, dtk],
                              curve[t, rc] * 100, curve[t, rann] * 100, fwd_str))
  }
  save_tab("tab_curva_bootstrap", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}

# --- tabella + figura della convergenza di Newton ----------------------------
tr_1315 <- newton_log[["13->15"]]
{
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Metodo di Newton sull'equazione non lineare~\\eqref{eq:boot-nl} per il gap ",
           "$13\\to15$ ($g=2$). Inizializzazione $f_0$ = forward annuale del tenor 13; ",
           "criterio d'arresto $|f_k-f_{k-1}|\\le 10^{-16}$. Il residuo $\\varphi(f_k)$ crolla ",
           "di diversi ordini di grandezza per iterazione: \\`e la firma della convergenza ",
           "quadratica.}"),
    "\\label{tab:newton-esempio}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$k$ & $f_k$ (\\%) & $\\varphi(f_k)$ & $|f_k-f_{k-1}|$\\\\", "\\midrule")
  for (i in seq_len(nrow(tr_1315))) {
    incr_str <- if (is.na(tr_1315$incr[i])) "---" else sprintf("%.3e", tr_1315$incr[i])
    lines <- c(lines, sprintf("%s%d & %.8f & %+.3e & %s\\\\",
                              tint(i), tr_1315$k[i], tr_1315$f[i] * 100,
                              tr_1315$phi[i], incr_str))
  }
  save_tab("tab_newton_esempio", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}
{
  df_n <- rbindlist(lapply(names(newton_log), function(nm) {
    d <- copy(newton_log[[nm]]); d[, Gap := paste("gap", nm)]; d[k > 0]
  }))
  df_n <- df_n[Gap %in% c("gap 13->15", "gap 15->20")]
  df_n[, absphi := pmax(abs(phi), 1e-18)]
  p_n <- ggplot(df_n, aes(x = k, y = absphi, color = Gap, shape = Gap)) +
    geom_line(linewidth = 0.9) + geom_point(size = 2.6) +
    scale_y_log10() +
    scale_x_continuous(breaks = seq_len(max(df_n$k))) +
    scale_color_manual(values = c("gap 13->15" = col_spot, "gap 15->20" = col_fwd)) +
    labs(title = "Convergenza del metodo di Newton sui due gap",
         subtitle = "Residuo |phi(f_k)| a ogni iterazione (scala logaritmica): precisione macchina in 3 iterazioni",
         x = "Iterazione k", y = "|phi(f_k)|", color = NULL, shape = NULL) +
    theme_dispensa
  save_fig("fig04_newton_convergenza", p_n)
}

# --- tabelle dell'LLFR -------------------------------------------------------
{
  t_ext <- c(15, 20, 25, 30, 40, 50)
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Valori del bootstrap esteso oltre l'$\\FSP$, ai tenor DLT che entrano ",
           "nel calcolo dell'$\\LLFR$. Il tratto $21\\le t\\le 50$ \\emph{non} fa parte della ",
           "curva risk-free pubblicata: serve solo a ricavare i forward della ",
           "Tabella~\\ref{tab:llfr-calcolo}.}"),
    "\\label{tab:bootstrap-esteso}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & $d_t$ & $r^c_t$ (\\%) & $r_t$ (\\%)\\\\", "\\midrule")
  for (i in seq_along(t_ext)) {
    t <- t_ext[i]
    lines <- c(lines, sprintf("%s%d & %.7f & %.4f & %.4f\\\\", tint(i), t,
                              curve[t, dtk], curve[t, rc] * 100, curve[t, rann] * 100))
  }
  save_tab("tab_bootstrap_esteso", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}
{
  contrib <- w_llfr * fwd_llfr
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Calcolo dell'$\\LLFR$ come media pesata dei forward continui attorno ",
           "all'$\\FSP$ (eq.~\\eqref{eq:llfr}). Ogni riga: forward continuo $f^c_{a,b}$ tra il ",
           "tenor di riferimento $a$ e il tenor $b$, moltiplicato per il peso EIOPA $w$. ",
           "La somma dei contributi \\`e l'$\\LLFR^c$.}"),
    "\\label{tab:llfr-calcolo}\\renewcommand{\\arraystretch}{1.2}",
    "\\begin{tabular}{rrccccc}", "\\toprule",
    paste0("$b$ & $a$ & $d_b$ & $r^c_b$ (\\%) & $f^c_{a,b}$ (\\%) & $w_b$ & ",
           "$w_b f^c_{a,b}$ (\\%)\\\\"), "\\midrule")
  for (i in seq_along(tenor_llfr)) {
    b <- tenor_llfr[i]
    lines <- c(lines, sprintf("%s%d & %d & %.7f & %.4f & %.4f & %.2f & %.4f\\\\",
                              tint(i), b, rif_llfr[i], curve[b, dtk], curve[b, rc] * 100,
                              fwd_llfr[i] * 100, w_llfr[i], contrib[i] * 100))
  }
  lines <- c(lines, "\\midrule",
    sprintf("\\multicolumn{5}{r}{\\textbf{$\\LLFR^c$}} & \\textbf{%.2f} & \\textbf{%.4f}\\\\",
            sum(w_llfr), LLFR_c * 100),
    sprintf("\\multicolumn{5}{r}{\\textit{per confronto:} $\\UFR^c$} & & \\textit{%.4f}\\\\",
            UFR_c * 100))
  save_tab("tab_llfr_calcolo", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}

# --- il peso di convergenza B(alpha,h): due viste ----------------------------
plot_B <- function(alphas, sottotitolo) {
  hh <- seq(0, 130, length.out = 500)
  df_B <- rbindlist(lapply(alphas, function(a)
    data.table(h = hh, B = B_weight(a, hh), alpha = sprintf("alpha = %.0f%%", a * 100))))
  ggplot(df_B, aes(x = h, y = B, color = alpha, linetype = alpha)) +
    geom_hline(yintercept = c(0, 1), linetype = "dashed", color = "gray60", linewidth = 0.4) +
    geom_line(linewidth = 1) +
    annotate("text", x = 2, y = 0.97, label = "B = 1: forward = LLFR (all'FSP)",
             hjust = 0, size = 3.2, color = "gray30") +
    annotate("text", x = 128, y = 0.06, label = "B -> 0: forward -> UFR",
             hjust = 1, size = 3.2, color = "gray30") +
    labs(title = expression(paste("Peso di convergenza  ",
                                  B(alpha, h) == (1 - e^{-alpha * h}) / (alpha * h))),
         subtitle = sottotitolo, x = "Orizzonte h oltre l'FSP (anni)",
         y = expression(B(alpha, h)), color = NULL, linetype = NULL) +
    theme_dispensa
}
save_fig("fig05_peso_Bah", plot_B(c(0.05, 0.11, 0.30),
  "Parte da 1 all'FSP (h=0, forward = LLFR) e tende a 0 (h -> infinito, forward = UFR)"))
save_fig("fig_b_alpha_h", plot_B(c(0.11, 0.20, 0.40),
  "I tre valori rilevanti: regime (11%), phasing-in 2027 (20%) e il valore SEK (40%)"))

# --- confronto con il benchmark ufficiale (nuovo metodo) ---------------------
eiopa_new <- read_eiopa_newmethod()
if (is.null(eiopa_new)) warning("benchmark nuovo metodo non trovato: tabella/figura saltate")

if (!is.null(eiopa_new)) {
  Tsel   <- c(1, 5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 120)
  r_mine <- curve_finale$rann[match(Tsel, curve_finale$tenor)] * 100
  r_off  <- eiopa_new$rann[match(Tsel, eiopa_new$tenor)] * 100
  delta  <- (r_mine - r_off) * 100
  ok     <- is.finite(delta)
  cat(sprintf("  [C] bootstrap vs ufficiale: max|delta| liquida = %.3f bps, estrapolazione = %.3f bps\n",
              max(abs(delta[ok & Tsel <= fsp])), max(abs(delta[ok & Tsel > fsp]))))
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva ricostruita vs curva ufficiale EIOPA di dicembre~2025 (ricalcolata ",
           "col nuovo metodo a bootstrap: confronto \\emph{like-for-like}, stesso metodo su ",
           "entrambi i lati). La riga in grassetto \\`e l'$\\FSP$: sopra di essa siamo in zona ",
           "liquida, sotto in estrapolazione.}"),
    "\\label{tab:confronto-eiopa}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & $r_t$ ricostruito (\\%) & $r_t$ EIOPA (\\%) & $\\Delta$ (bps)\\\\", "\\midrule")
  for (i in seq_along(Tsel)) {
    if (!ok[i]) next
    numstr <- if (Tsel[i] == fsp) sprintf("\\textbf{%d}", Tsel[i]) else as.character(Tsel[i])
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f\\\\",
                              tint(i), numstr, r_mine[i], r_off[i], delta[i]))
  }
  save_tab("tab_confronto_eiopa", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))

  # figura a due pannelli: overlay 1-60 + scarti 1-120
  mm    <- 1:120
  r_m   <- curve_finale$rann[match(mm, curve_finale$tenor)] * 100
  r_o   <- eiopa_new$rann[match(mm, eiopa_new$tenor)] * 100
  d_all <- (r_m - r_o) * 100
  okk   <- is.finite(d_all)
  rmse  <- sqrt(mean(d_all[okk]^2)); mx <- max(abs(d_all[okk]))

  p_top <- ggplot() +
    geom_vline(xintercept = fsp, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(data = data.table(T = mm[mm <= 60], v = r_m[mm <= 60]),
              aes(x = T, y = v, color = "ricostruita"), linewidth = 1.1) +
    geom_point(data = data.table(T = mm[mm <= 60], v = r_o[mm <= 60]),
               aes(x = T, y = v, color = "EIOPA ufficiale"), shape = 21, size = 1.6,
               fill = "white", stroke = 1.0) +
    scale_color_manual(values = c("ricostruita" = col_spot, "EIOPA ufficiale" = col_obs)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = "Ricostruzione a bootstrap vs curva ufficiale EIOPA — dicembre 2025",
         subtitle = sprintf("Tasso spot annuo. RMSE = %.3f bps, scarto massimo = %.3f bps (tenor 1-120)",
                            rmse, mx),
         x = NULL, y = "Tasso spot (%)", color = NULL) +
    theme_dispensa + theme(legend.position = "top")

  df_r <- data.table(T = mm[okk], Res = d_all[okk],
                     Zona = factor(ifelse(mm[okk] <= fsp, "Liquida", "Estrapolazione"),
                                   levels = c("Liquida", "Estrapolazione")))
  p_bot <- ggplot(df_r, aes(x = T, y = Res, fill = Zona)) +
    geom_col(width = 0.9) +
    geom_vline(xintercept = fsp + 0.5, color = "gray50", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 60, 80, 100, 120)) +
    labs(subtitle = "Scarto ricostruita - ufficiale (bps)",
         x = "Scadenza t (anni)", y = "Scarto (bps)", fill = NULL) +
    theme_dispensa + theme(legend.position = "top")

  pdf(file.path(dir_out, "fig_vs_benchmark_dic.pdf"), width = 9, height = 7.5)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    2, 1, heights = grid::unit(c(2, 1), "null"))))
  print(p_top, vp = grid::viewport(layout.pos.row = 1))
  print(p_bot, vp = grid::viewport(layout.pos.row = 2))
  invisible(dev.off())
  message("  [OK] fig_vs_benchmark_dic.pdf")
}

# --- sensitivita' ad alpha (Sez. 6) ------------------------------------------
alpha_lo <- 0.11; alpha_hi <- 0.20
c_lo <- curva_alpha(alpha_lo); c_hi <- curva_alpha(alpha_hi)
stopifnot(max(abs(c_lo$rann - curve_finale$rann)) < 1e-12)
{
  lab_lo <- sprintf("alpha = %.0f%% (base, regime)", alpha_lo * 100)
  lab_hi <- sprintf("alpha = %.0f%% (phasing-in 2027)", alpha_hi * 100)
  df_b <- rbind(
    data.table(T = c_lo$tenor, val = abs(c_lo$fwd_c - UFR_c) * 1e4, Scenario = lab_lo),
    data.table(T = c_hi$tenor, val = abs(c_hi$fwd_c - UFR_c) * 1e4, Scenario = lab_hi))
  df_b <- df_b[T > fsp & val > 0]
  p_a <- ggplot(df_b, aes(x = T, y = val, color = Scenario, linetype = Scenario)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = setNames(c(col_spot, col_fwd), c(lab_lo, lab_hi))) +
    scale_linetype_manual(values = setNames(c("solid", "dashed"), c(lab_lo, lab_hi))) +
    scale_y_log10() + scale_x_continuous(breaks = c(20, 40, 60, 80, 100, 120, 150)) +
    labs(title = "Velocita' di convergenza: distanza del forward dall'UFR (scala log)",
         subtitle = "Base (alpha=11%, continua) vs phasing-in (alpha=20%, tratteggiata): la distanza residua scala come 1/alpha",
         x = "Scadenza t (anni)", y = "|f(t) - UFR|  (bps)", color = NULL, linetype = NULL) +
    theme_dispensa
  save_fig("fig_alpha_curve", p_a)
}
{
  df_d <- data.table(T = c_hi$tenor, delta = (c_hi$rann - c_lo$rann) * 1e4)
  i_pk <- which.max(abs(df_d$delta)); T_pk <- df_d$T[i_pk]; d_pk <- df_d$delta[i_pk]
  p_d <- ggplot(df_d, aes(x = T, y = delta)) +
    annotate("rect", xmin = fsp, xmax = tenor_max, ymin = -Inf, ymax = Inf,
             fill = "gray85", alpha = 0.30) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
    geom_vline(xintercept = fsp, color = "gray55", linetype = "dashed", linewidth = 0.5) +
    geom_line(color = col_spot, linewidth = 1) +
    geom_point(data = data.table(T = T_pk, delta = d_pk), aes(x = T, y = delta),
               color = col_obs, size = 2.2, inherit.aes = FALSE) +
    annotate("text", x = T_pk + 3, y = d_pk, hjust = 0, color = col_obs, size = 3.2,
             label = sprintf("max %+.2f bps (t = %d)", d_pk, T_pk)) +
    scale_x_continuous(breaks = c(1, 20, 40, 60, 80, 100, 120, 150)) +
    labs(title = "Effetto di alpha sullo zero rate: differenza tra i due scenari",
         subtitle = sprintf("Delta = r(t) con alpha=%.0f%% meno r(t) con alpha=%.0f%%; nullo fino all'FSP",
                            alpha_hi * 100, alpha_lo * 100),
         x = "Scadenza t (anni)", y = "Delta zero rate (bps)") +
    theme_dispensa
  save_fig("fig_alpha_delta", p_d)
}
{
  Tsel <- c(20, 25, 30, 40, 50, 60, 80, 100, 120, 150)
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Sensitivit\\`a al parametro di convergenza $\\alpha$: confronto tra il ",
           sprintf("valore di regime ($\\alpha=%.0f\\%%$) e quello di phasing-in ", alpha_lo * 100),
           sprintf("($\\alpha=%.0f\\%%$). ", alpha_hi * 100),
           "Le ultime due colonne misurano la \\emph{velocit\\`a di convergenza} come distanza ",
           "residua del forward dall'$\\UFR^c$: un $\\alpha$ maggiore la chiude pi\\`u in fretta. ",
           "All'$\\FSP$ le due curve coincidono per costruzione.}"),
    "\\label{tab:alpha-sens}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccccc}", "\\toprule",
    "& \\multicolumn{3}{c}{zero rate $r_t$} & \\multicolumn{2}{c}{$|f^c_t-\\UFR^c|$ (bps)}\\\\",
    "\\cmidrule(lr){2-4}\\cmidrule(lr){5-6}",
    sprintf("$t$ (anni) & $\\alpha=%.0f\\%%$ & $\\alpha=%.0f\\%%$ & $\\Delta$ (bps) & $\\alpha=%.0f\\%%$ & $\\alpha=%.0f\\%%$\\\\",
            alpha_lo * 100, alpha_hi * 100, alpha_lo * 100, alpha_hi * 100), "\\midrule")
  for (i in seq_along(Tsel)) {
    t <- Tsel[i]; j <- match(t, c_lo$tenor)
    numstr <- if (t == fsp) sprintf("\\textbf{%d}", t) else as.character(t)
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f & %.2f & %.2f\\\\",
                              tint(i), numstr, c_lo$rann[j] * 100, c_hi$rann[j] * 100,
                              (c_hi$rann[j] - c_lo$rann[j]) * 1e4,
                              abs(c_lo$fwd_c[j] - UFR_c) * 1e4,
                              abs(c_hi$fwd_c[j] - UFR_c) * 1e4))
  }
  save_tab("tab_alpha_sens", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))
}

cat("\n=====================================================================\n")
cat("  FATTO (bootstrap). Output in", dir_out, "\n")
cat(sprintf("  %d figure PDF, %d tabelle .tex presenti in cartella (incl. Smith-Wilson se gia' eseguito)\n",
            length(list.files(dir_out, pattern = "\\.pdf$")),
            length(list.files(dir_out, pattern = "\\.tex$"))))
cat("  Prossimo passo: Rscript R/02_eiopa_rfr_smith_wilson.R\n")
cat("=====================================================================\n\n")
