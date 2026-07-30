# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Bootstrap (constant forward) + Estrapolazione FSP/LLFR
#  Ricalcolo DICEMBRE 2025 da TRE FONTI di dati di input
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Riferimento: EIOPA-BoS-26-198 (RFR Technical Documentation, Maggio 2026),
#  che recepisce gli emendamenti a Solvency II (Dir (UE) 2025/2, Reg (UE) 2026/269).
#
#  METODO (NON più Smith-Wilson):
#    - Interpolazione : ipotesi "constant forward" + BOOTSTRAP (Annex D)
#    - Estrapolazione : First Smoothing Point (FSP), Last Liquid Forward Rate
#                       (LLFR) e convergenza all'UFR con peso B(a,h) (sez. 8.5)
#    - alpha (convergenza) : parametro REGOLAMENTARE FISSO (no calibrazione)
#
#  TRE FONTI di ricostruzione (dicembre 2025, stesse 15 scadenze DLT EUSA):
#    Fonte A — par EUSA di mercato (EURIBOR 6M, Bloomberg) dopo CRA
#    Fonte B — par IMPLICITI derivati dalla curva RFR ufficiale (zip EIOPA),
#              gia' al netto del CRA, ottenuti dagli zeri ufficiali
#    Fonte C — dati di input EIOPA "originali" (par swap lordi YE2025,
#              eiopa_input_swap_dec2025.csv), dopo CRA
#    Tutte passano per lo stesso bootstrap (Newton-Raphson sui buchi).
#
#  Confronto LIKE-FOR-LIKE con la curva ufficiale EIOPA di dic 2025 RICALCOLATA
#  col nuovo metodo (bootstrap), da dati/dec25_eiopa_rfr_newapproach.csv: stesso
#  metodo su entrambi i lati (bootstrap vs bootstrap), tenor 1..120.
#
#  Nucleo numerico del corso:
#    - Bootstrap sequenziale (tenor consecutivi -> lineare; buchi -> NON lineare)
#    - Ricerca di zeri: NEWTON-RAPHSON (derivata analitica, Annex D.6) vs BISEZIONE
#
#  Output: figure PDF e tabelle .tex in ../output/01_eiopa_rfr_bootstrap
# ==============================================================================

# ---- 0. SETUP ----------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
  library(reshape2)
})
have_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

dir_out <- file.path(dirname(getwd()), "output", "01_eiopa_rfr_bootstrap")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)
# NB: nessuna pulizia della cartella di output. Qui scrive anche
# 01_eiopa_rfr_bootstrap_rivisto.R (che genera gli asset della dispensa):
# un unlink() indiscriminato cancellerebbe i suoi file.

theme_dispensa <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, color = "gray30"),
    legend.position  = "bottom"
  )

col_spot    <- "#185FA5"   # blu — tasso spot
col_fwd     <- "#993C1D"   # rosso mattone — forward
col_ufr     <- "#7060CC"   # viola — UFR
col_llfr    <- "#2ca02c"   # verde — LLFR
col_nodi    <- "black"
col_nr      <- "#185FA5"
col_bis     <- "#E07020"
col_obs     <- "#B2182B"
col_interp  <- "#2166AC"

save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

cat("\n====================================================================\n")
cat("  CURVA EIOPA EUR — Bootstrap + FSP/LLFR — dicembre 2025, tre fonti\n")
cat("====================================================================\n\n")

# ==============================================================================
# PARAMETRI EIOPA EUR (sez. 8.1, 8.2, 8.4; Annex C)
# ==============================================================================

UFR_ann <- 0.0330                   # UFR annuo composto (EUR), Annex C
UFR_c   <- log(1 + UFR_ann)         # UFR intensità continua ~ 3.2466%
FSP     <- 20                       # First Smoothing Point EUR (anni), sez. 8.2
CRA     <- 0.0010                   # Credit Risk Adjustment = 10 bps (sez. 6)

# alpha di convergenza (sez. 8.1.5): FISSO per legge; phasing-in (Table 4)
phasing_alpha <- c("2027"=0.200, "2028"=0.182, "2029"=0.164,
                   "2030"=0.146, "2031"=0.128, "2032"=0.110)
alpha <- as.numeric(phasing_alpha["2032"])   # 11% (valore a regime, usato come riferimento
                                              # principale della dispensa; coerente con
                                              # 01_eiopa_rfr_bootstrap_rivisto.R)

# LLFR dal tool ufficiale EIOPA (xlsm "RFR extrapolation and VA calculation"), in
# capitalizzazione continua: media pesata di forward tra FSP(20y) e tenor piu' lunghi
# (25/30/40/50y, pesi 0.33/0.12/0.48/0.04/0.03) via funzione VBA GetLLFR -- non il
# singolo forward 19->20 di Def. 4.6. Provenienza/generalita' del dato da chiarire
# (Fonte D, sperimentale).
LLFR_c_XLSM <- 0.03224887

cat(sprintf("UFR annuo=%.2f%%  UFR continuo=%.4f%%  FSP=%d  CRA=%dbps  alpha=%.1f%%\n\n",
            UFR_ann*100, UFR_c*100, FSP, CRA*1e4, alpha*100))

# Scadenze DLT EUR per gli swap EURIBOR 6M (EUSA), valide giu-dic 2025
T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 20)
N     <- length(T_mkt)
# Buchi (tenor non consecutivi): 13->15 (gap 2), 15->20 (gap 5)

# ==============================================================================
# 1. FUNZIONI CORE — BOOTSTRAP ed ESTRAPOLAZIONE
# ==============================================================================

# Equazione del bootstrap per un tenor con "buco" (Annex D.6.1)
g_boot  <- function(f, s2, s1, d_tk, gap) {
  d_star <- (1 + f)^(-gap)
  s2 * (1 - d_star) / f + d_star + (s2 - s1) / s1 * (1 - d_tk) / d_tk - 1
}
# Derivata analitica (Annex D.6.2)
gp_boot <- function(f, s2, s1, d_tk, gap) {
  d_star  <- (1 + f)^(-gap)
  d_starp <- -gap * (1 + f)^(-gap - 1)
  s2 * ((-d_starp * f - (1 - d_star)) / f^2) + d_starp
}
# Newton-Raphson (Annex D.6.3-D.6.5) con tracciamento
nr_solve <- function(s2, s1, d_tk, gap, f0, tol = 1e-15, nmax = 60) {
  f <- f0; tr <- data.frame(iter = 0, f = f0, g = g_boot(f0, s2, s1, d_tk, gap))
  for (k in seq_len(nmax)) {
    gv <- g_boot(f, s2, s1, d_tk, gap)
    if (abs(gv) < tol) break
    f <- f - gv / gp_boot(f, s2, s1, d_tk, gap)
    tr <- rbind(tr, data.frame(iter = k, f = f, g = g_boot(f, s2, s1, d_tk, gap)))
  }
  list(f = f, trace = tr, n_iter = nrow(tr) - 1)
}
# Bisezione sulla stessa equazione (metodo di confronto robusto)
bis_solve <- function(s2, s1, d_tk, gap, lo = 1e-6, hi = 1.0, tol = 1e-15, nmax = 200) {
  glo <- g_boot(lo, s2, s1, d_tk, gap); ghi <- g_boot(hi, s2, s1, d_tk, gap)
  if (glo * ghi > 0) stop("bisezione: nessun cambio di segno in [lo,hi]")
  tr <- data.frame(iter = integer(), f = numeric(), g = numeric(), width = numeric())
  for (k in seq_len(nmax)) {
    mid <- 0.5 * (lo + hi); gm <- g_boot(mid, s2, s1, d_tk, gap)
    tr <- rbind(tr, data.frame(iter = k, f = mid, g = gm, width = hi - lo))
    if (sign(gm) == sign(glo)) { lo <- mid; glo <- gm } else { hi <- mid }
    if ((hi - lo) < tol) break
  }
  list(f = 0.5 * (lo + hi), trace = tr, n_iter = nrow(tr))
}

# Bootstrap completo: par after-CRA -> d_t, z_t (annuali) per t = 1..FSP
bootstrap_curve <- function(T_mkt, r_mkt, FSP, solver = "newton") {
  Nloc <- length(T_mkt); Tmax <- FSP
  d <- rep(NA_real_, Tmax)
  is_obs <- rep(FALSE, Tmax); is_obs[T_mkt[T_mkt <= Tmax]] <- TRUE
  d[1] <- 1 / (1 + r_mkt[1])                     # Step 1 (Annex D.4)
  for (k in 2:Nloc) {
    t_prev <- T_mkt[k - 1]; t_cur <- T_mkt[k]
    if (t_cur > Tmax) break
    gap <- t_cur - t_prev; Sprev <- sum(d[1:t_prev])
    if (gap == 1) {
      d[t_cur] <- (1 - r_mkt[k] * Sprev) / (1 + r_mkt[k])   # lineare (Annex D.5)
    } else {
      f0 <- d[t_prev - 1] / d[t_prev] - 1                    # start: ultimo fwd 1y
      f_star <- if (solver == "newton")
        nr_solve(r_mkt[k], r_mkt[k - 1], d[t_prev], gap, f0)$f
      else
        bis_solve(r_mkt[k], r_mkt[k - 1], d[t_prev], gap)$f
      for (i in 1:gap) d[t_prev + i] <- d[t_prev] * (1 + f_star)^(-i)
    }
  }
  z <- d^(-1 / seq_len(Tmax)) - 1
  list(t = seq_len(Tmax), d = d, z = z, is_obs = is_obs)
}

# Peso di convergenza (sez. 8.5.5)
B_weight <- function(a, h) ifelse(h == 0, 1, (1 - exp(-a * h)) / (a * h))

# LLFR continuo (sez. 8.5.6): FSP = ultimo tenor DLT  =>  LLFR^c = f^c_{FSP-1,FSP}
llfr_c <- function(zc_vec) FSP * zc_vec[FSP] - (FSP - 1) * zc_vec[FSP - 1]

# Estrapolazione da zeri continui liquidi zc_vec (1..FSP) per h = 1..(150-FSP).
# llfr_override, se fornito, sostituisce il LLFR calcolato da llfr_c(zc_vec) (Fonte D).
extrapolate_from <- function(zc_vec, a, llfr_override = NULL) {
  L <- if (is.null(llfr_override)) llfr_c(zc_vec) else llfr_override
  h  <- 1:(150 - FSP)
  fc <- UFR_c + (L - UFR_c) * B_weight(a, h)               # sez. 8.5.5
  zc_ext <- (FSP * zc_vec[FSP] + h * fc) / (FSP + h)        # sez. 8.5.7
  data.frame(t = FSP + h, zc = zc_ext, z = exp(zc_ext) - 1, fc = fc)
}

# ==============================================================================
# 2. DATI COMUNI (dicembre 2025): par EUSA, curva ufficiale, par impliciti
# ==============================================================================

read_eusa_all <- function() {
  f <- file.path(dirname(getwd()), "dati", "03_eusa.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 1, detectDates = TRUE)
    dcol  <- df[[1]]; dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    M <- as.matrix(df[, -1]); storage.mode(M) <- "numeric"
    keep <- !is.na(dates) & rowSums(is.na(M)) == 0 & ncol(M) == N
    data.frame(date = dates[keep], M[keep, , drop = FALSE] / 100, check.names = FALSE)
  }, error = function(e) NULL)
}

read_eiopa_official <- function(date) {
  if (!have_openxlsx) return(NULL)
  zdir <- file.path(dirname(getwd()), "dati", "eiopa_zips")
  ym <- format(date, "%Y%m")
  tryCatch({
    zf <- list.files(zdir, pattern = paste0("^EIOPA_RFR_", ym, "[0-9]{2}\\.zip$"),
                     full.names = TRUE)
    if (length(zf) == 0) return(NULL)
    zf <- zf[1]
    inner <- utils::unzip(zf, list = TRUE)$Name
    ts <- grep("Term_Structures", inner, value = TRUE, ignore.case = TRUE)[1]
    if (is.na(ts)) return(NULL)
    utils::unzip(zf, files = ts, exdir = tempdir(), overwrite = TRUE)
    raw <- openxlsx::read.xlsx(file.path(tempdir(), ts), sheet = "RFR_spot_no_VA",
                               colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    lab <- raw[[2]]; val <- raw[[3]]
    getp <- function(name) as.numeric(val[which(lab == name)[1]])
    ml <- suppressWarnings(as.numeric(lab))
    sel <- which(!is.na(ml) & ml >= 1 & ml <= 150)
    mat <- ml[sel]; spot <- suppressWarnings(as.numeric(val[sel]))
    ok <- !is.na(mat) & !is.na(spot)
    list(CRA = getp("CRA"), alpha = getp("alpha"), zip = basename(zf),
         mat = mat[ok], spot = spot[ok])
  }, error = function(e) NULL)
}

# Curva EIOPA ufficiale di dicembre 2025 RICALCOLATA col nuovo metodo (bootstrap),
# fornita come benchmark like-for-like. Tenor YR1..YR120, spot annuo decimale.
read_eiopa_newmethod <- function() {
  f <- file.path(dirname(getwd()), "dati", "dec25_eiopa_rfr_newapproach.csv")
  if (!file.exists(f)) return(NULL)
  tryCatch({
    df <- read.csv(f, stringsAsFactors = FALSE)
    tt <- as.integer(sub("^YR", "", df$tenor))
    zz <- as.numeric(df[[2]])
    ok <- !is.na(tt) & !is.na(zz)
    list(t = tt[ok], z = zz[ok])
  }, error = function(e) NULL)
}

# Dati input EIOPA "originali" (par swap lordi, YE 2025) sugli stessi 15 tenor DLT:
# Fonte C, alternativa al proxy Bloomberg EUSA* (Fonte A).
read_eiopa_input_ye25 <- function() {
  f <- file.path(dirname(getwd()), "dati", "eiopa_input_swap_dec2025.csv")
  if (!file.exists(f)) return(NULL)
  tryCatch({
    df <- read.csv(f, stringsAsFactors = FALSE)
    tt <- as.integer(df$tenor)
    ss <- as.numeric(df$swap_inputEUR)
    ok <- !is.na(tt) & !is.na(ss)
    data.frame(t = tt[ok], s = ss[ok])
  }, error = function(e) NULL)
}

d_dic <- as.Date("2025-12-31"); lab_dic <- "Dicembre 2025"
eusa_all <- read_eusa_all()
if (is.null(eusa_all)) stop("Impossibile leggere dati/03_eusa.xlsx")
off <- read_eiopa_official(d_dic)
if (is.null(off)) stop("Curva ufficiale EIOPA non trovata (EIOPA_RFR_20251231.zip)")

s_dic  <- as.numeric(eusa_all[eusa_all$date == d_dic, -1])   # par EUSA lordi
CRA_dic <- if (is.finite(off$CRA)) off$CRA / 1e4 else CRA
r_eusa <- s_dic - CRA_dic                                    # Fonte A: par after-CRA

# curva ufficiale Smith-Wilson: zeri 1..150. off$spot e' in forma DECIMALE.
# Usata SOLO come dato di input per ricavare i par impliciti (Fonte B) -- non
# come benchmark di confronto (sostituita dalla curva nuovo-metodo sotto).
zoff_all_dec <- off$spot                    # decimale ai tenor off$mat
mat_all      <- off$mat
zoff20_dec   <- zoff_all_dec[match(1:20, mat_all)]                    # decimale 1..20
doff20       <- (1 + zoff20_dec)^(-(1:20))                            # fattori di sconto ufficiali

# Fonte B: par IMPLICITI dalla curva ufficiale (gia' netti CRA), ai tenor DLT
r_impl <- sapply(T_mkt, function(Tk) (1 - doff20[Tk]) / sum(doff20[1:Tk]))

# Fonte C: dati di input EIOPA "originali" (par swap lordi YE2025), ai tenor DLT
inp_ye25 <- read_eiopa_input_ye25()
if (is.null(inp_ye25))
  stop("Dati input EIOPA originali non trovati (dati/eiopa_input_swap_dec2025.csv)")
s_input <- inp_ye25$s[match(T_mkt, inp_ye25$t)]              # lordo, allineato a T_mkt
r_input <- s_input - CRA_dic                                 # Fonte C: par after-CRA

# --- Asset di Sez. 1-2 (figura motivazione + tabella dati di input). La dispensa
#     03 genera i propri equivalenti nella PROPRIA cartella: nessun file in
#     comune tra le due dispense (i duplicati sono voluti).
{
  df1 <- data.frame(T = off$mat, val = off$spot * 100)
  p_mot <- ggplot(df1, aes(x = T, y = val)) +
    annotate("rect", xmin = 20, xmax = max(df1$T), ymin = -Inf, ymax = Inf,
             fill = "gray85", alpha = 0.35) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.7) +
    geom_vline(xintercept = 20, color = "gray55", linetype = "dashed", linewidth = 0.4) +
    geom_line(linewidth = 1, color = col_spot) +
    annotate("text", x = 21, y = min(df1$val), label = "estrapolazione (T > 20a)",
             hjust = 0, color = "gray35", size = 3.4) +
    annotate("text", x = max(df1$T) - 1, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
             hjust = 1, color = col_ufr, size = 3.6) +
    scale_x_continuous(breaks = c(1, 10, 20, 40, 60, 80, 100, 120, 150)) +
    labs(title = "Curva spot EUR ufficiale EIOPA — dicembre 2025",
         subtitle = "Zona grigia: estrapolazione (T > 20 anni); linea viola: UFR = 3.30%",
         x = "Scadenza T (anni)", y = "Tasso spot annuo (%)") +
    theme_dispensa
  ggsave(file.path(dir_out, "fig_motivazione.pdf"), plot = p_mot, width = 9, height = 5.5, device = "pdf")
  message("  [OK] fig_motivazione.pdf")
}
{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Par swap EUR di input EIOPA a dicembre~2025 ai 15 tenor DLT ",
           "(\\texttt{eiopa\\_input\\_swap\\_dec2025.csv}), lordi e dopo la sottrazione del CRA. ",
           "I tenor 15 e 20 chiudono un ``buco'' (13$\\to$15, 15$\\to$20).}"),
    "\\label{tab:input-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rcc}", "\\toprule",
    "$T_k$ (anni) & input EIOPA lordo (\\%) & after-CRA $r_k$ (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(T_mkt)) {
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    tag  <- if (T_mkt[i] == 20) "~\\textbf{(ultimo tenor liquido)}" else if (T_mkt[i] == 15) "~(buco)" else ""
    lines <- c(lines, sprintf("%s%d%s & %.4f & %.4f\\\\", tint, T_mkt[i], tag,
                              s_input[i]*100, r_input[i]*100))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_input_dic.tex"))
  message("  [OK] tab_input_dic.tex")
}

# Figura di Sez.2: fattori di sconto dalla curva ufficiale EIOPA di dicembre 2025
# (method-agnostica). La dispensa 03 ha la propria copia nella sua cartella.
# NOTA: la figura effettivamente usata dalla dispensa 01 (fig_fattori_sconto.pdf,
# costruita sulla ricostruzione bootstrap) e' generata da
# 01_eiopa_rfr_bootstrap_rivisto.R; questa e' la variante storica dai dati ufficiali.
{
  mm <- off$mat; zz <- off$spot
  sel <- mm >= 1 & mm <= 25
  dfP <- data.frame(T = mm[sel], P = (1 + zz[sel])^(-mm[sel]))
  pP <- ggplot(dfP, aes(x = T, y = P)) + geom_line(linewidth = 1, color = col_spot) +
    labs(title = "Fattori di sconto P(0,T)",
         subtitle = "P(0,T) = prezzo oggi di 1 unita' pagata in T; decresce con la scadenza",
         x = "Scadenza T (anni)", y = "P(0,T)") + theme_dispensa +
    scale_x_continuous(breaks = c(1,5,10,15,20,25))
  ggsave(file.path(dir_out, "fig_fattori_sconto_ufficiale.pdf"), plot = pP,
         width = 8, height = 5, device = "pdf")
  message("  [OK] fig_fattori_sconto_ufficiale.pdf")
}

# Curva ufficiale ricalcolata col NUOVO metodo (bootstrap): benchmark like-for-like
# per il confronto in run_source(). Tenor 1..120, spot in PERCENTO.
newm <- read_eiopa_newmethod()
if (is.null(newm))
  stop("Curva EIOPA nuovo metodo non trovata (dati/dec25_eiopa_rfr_newapproach.csv)")
znew_all_dec <- newm$z                                                # decimale ai tenor newm$t
tmat_new     <- newm$t
znew_at      <- function(tt) znew_all_dec[match(tt, tmat_new)] * 100  # -> PERCENTO

cat(sprintf("Mese: %s  (zip %s);  alpha ufficiale SW = %.4f (informativo)\n\n",
            lab_dic, off$zip, off$alpha))
cat("  Par EUSA* (Fonte A), par impliciti (Fonte B) e input EIOPA originali (Fonte C), %:\n")
print(data.frame(Tenor = T_mkt, EUSA_par = round(s_dic*100,4),
                 EUSA_afterCRA = round(r_eusa*100,4),
                 par_implicito = round(r_impl*100,4),
                 input_EIOPA_lordo = round(s_input*100,4)), row.names = FALSE)
cat("\n")

# ==============================================================================
# 3. FIGURE DIDATTICHE (metodo) — sui dati di input EIOPA (dicembre 2025)
# ==============================================================================

# --- fig01: par input EIOPA lordi e after-CRA ---
df_input <- data.frame(
  Scadenza = rep(T_mkt, 2), Tasso = c(s_input*100, r_input*100),
  Tipo = rep(c("Input EIOPA (lordo)", "After-CRA (input bootstrap)"), each = N))
p1 <- ggplot(df_input, aes(x = Scadenza, y = Tasso, color = Tipo, shape = Tipo)) +
  geom_line(linewidth = 1) + geom_point(size = 2.5) +
  scale_color_manual(values = c("Input EIOPA (lordo)" = col_spot,
                                "After-CRA (input bootstrap)" = col_fwd)) +
  labs(title = sprintf("Par swap di input EIOPA — EUR %s", lab_dic),
       subtitle = sprintf("CRA = %d bps sottratto prima del bootstrap (sez. 6)", CRA_dic*1e4),
       x = "Scadenza (anni)", y = "Tasso (%)", color = NULL, shape = NULL) +
  theme_dispensa + scale_x_continuous(breaks = T_mkt)
save_fig("fig01_input_par", p1)

# --- Bootstrap di riferimento (dati input EIOPA) per le figure didattiche ---
bcRef <- bootstrap_curve(T_mkt, r_input, FSP, solver = "newton")

# verifica re-pricing
max_err <- 0
for (i in seq_along(T_mkt)) {
  Ti <- T_mkt[i]; val <- r_input[i]*sum(bcRef$d[1:Ti]) + bcRef$d[Ti]
  max_err <- max(max_err, abs(val - 1))
}
cat(sprintf("Verifica re-pricing bootstrap (input EIOPA): max|valore par - 1| = %.2e\n\n", max_err))

# --- fig02: curva zero bootstrap (osservati vs interpolati) ---
df_zero <- data.frame(t = bcRef$t, z = bcRef$z*100,
  Tipo = ifelse(bcRef$is_obs, "Tenor osservato (DLT)", "Tenor interpolato (bootstrap)"))
p2 <- ggplot(df_zero, aes(x = t, y = z)) +
  geom_line(color = col_interp, linewidth = 1) +
  geom_point(aes(color = Tipo, shape = Tipo), size = 2.6) +
  scale_color_manual(values = c("Tenor osservato (DLT)" = col_obs,
                                "Tenor interpolato (bootstrap)" = col_interp)) +
  scale_shape_manual(values = c("Tenor osservato (DLT)" = 16,
                                "Tenor interpolato (bootstrap)" = 1)) +
  labs(title = "Curva zero ricostruita per bootstrap (1-20 anni) — dati di input EIOPA",
       subtitle = "I tenor non DLT (14, 16-19) sono ricavati con l'ipotesi constant forward",
       x = "Scadenza t (anni)", y = "Zero rate annuale (%)", color = NULL, shape = NULL) +
  theme_dispensa + scale_x_continuous(breaks = bcRef$t)
save_fig("fig02_bootstrap_zero", p2)

# --- fig03: forward 1y constant-forward (step) ---
fwd_1y <- numeric(FSP); fwd_1y[1] <- 1/bcRef$d[1] - 1
for (t in 2:FSP) fwd_1y[t] <- bcRef$d[t-1]/bcRef$d[t] - 1
df_fwd1 <- data.frame(t = seq_len(FSP), f = fwd_1y*100, is_obs = bcRef$is_obs)
df_step <- data.frame(t0 = seq_len(FSP) - 1, t1 = seq_len(FSP), f = fwd_1y*100)
p3 <- ggplot() +
  geom_segment(data = df_step, aes(x = t0, xend = t1, y = f, yend = f),
               color = col_fwd, linewidth = 1) +
  geom_point(data = df_fwd1, aes(x = t, y = f,
             color = ifelse(is_obs, "osservato", "interpolato")), size = 2.4) +
  scale_color_manual(values = c("osservato" = col_obs, "interpolato" = col_interp), name = NULL) +
  labs(title = "Forward annuali f(t-1,t) e ipotesi constant forward — dati di input EIOPA",
       subtitle = "Nei tratti tra tenor non consecutivi il forward e' costante (gap 13->15, 15->20)",
       x = "Scadenza t (anni)", y = "Forward annuale f(t-1,t) (%)") +
  theme_dispensa + scale_x_continuous(breaks = seq_len(FSP))
save_fig("fig03_constant_forward", p3)

# --- Newton sui due gap (13->15, gap 2; 15->20, gap 5), dati di input EIOPA ---
bc15 <- bootstrap_curve(T_mkt[T_mkt <= 15], r_input[T_mkt <= 15], 15, solver = "newton")
k13 <- which(T_mkt == 13); k15 <- which(T_mkt == 15); k20 <- which(T_mkt == 20)
s2 <- r_input[k20]; s1 <- r_input[k15]; d_tk <- bc15$d[15]; gap <- 5
f0 <- bc15$d[14]/bc15$d[15] - 1
nr <- nr_solve(s2, s1, d_tk, gap, f0)
nr13 <- nr_solve(r_input[k15], r_input[k13], bcRef$d[13], 2, bcRef$d[12]/bcRef$d[13] - 1)
cat(sprintf("Gap 13->15: f*(Newton)=%.12f in %d iter\n", nr13$f, nr13$n_iter))
cat(sprintf("Gap 15->20: f*(Newton)=%.12f in %d iter\n\n", nr$f, nr$n_iter))

# --- fig04: convergenza di Newton sui due gap (residuo |phi(f_k)| per iterazione) ---
df_conv <- rbind(
  data.frame(iter = nr13$trace$iter, resid = abs(nr13$trace$g), Gap = "13 -> 15 (g=2)"),
  data.frame(iter = nr$trace$iter,   resid = abs(nr$trace$g),   Gap = "15 -> 20 (g=5)"))
df_conv <- df_conv[df_conv$resid > 0, ]
p4 <- ggplot(df_conv, aes(x = iter, y = resid)) +
  geom_line(linewidth = 1, color = col_nr) + geom_point(size = 2.4, color = col_nr) +
  facet_wrap(~ Gap, scales = "free_x") +
  scale_y_log10() +
  labs(title = "Convergenza di Newton sui due gap del bootstrap — dicembre 2025",
       subtitle = "Residuo |phi(f_k)| per iterazione (scala log): convergenza quadratica",
       x = "Iterazione k", y = "Residuo |phi(f_k)|") +
  theme_dispensa
save_fig("fig04_newton_convergenza", p4)

# --- fig05: peso B(a,h) ---
hh <- seq(0, 130, length.out = 400)
df_B <- do.call(rbind, lapply(c(0.110, alpha, 0.40), function(a)
  data.frame(h = hh, B = B_weight(a, hh), alpha = sprintf("a = %.1f%%", a*100))))
p5 <- ggplot(df_B, aes(x = h, y = B, color = alpha)) +
  geom_line(linewidth = 1) + geom_hline(yintercept = c(0,1), linetype = "dashed", color = "gray60") +
  labs(title = expression(paste("Peso di convergenza ", B(a,h) == (1-e^{-a*h})/(a*h))),
       subtitle = "B(a,0)=1 (forward=LLFR all'FSP); B(a,h)->0 (forward->UFR). a piu' grande = convergenza piu' rapida",
       x = "Orizzonte h oltre l'FSP (anni)", y = "B(a,h)", color = expression(alpha)) + theme_dispensa
save_fig("fig05_peso_Bah", p5)

# ==============================================================================
# 4. RICOSTRUZIONE DA TRE FONTI — helper run_source()
# ==============================================================================

# Esegue una ricostruzione completa (bootstrap + estrapolazione) a partire da un
# vettore di par after-CRA, la confronta con la curva ufficiale e produce
# figure/tabella/metriche. Mirror di run_scenario() della lezione 03b.
# llfr_override, se fornito, sostituisce il LLFR calcolato internamente (Fonte D).
run_source <- function(label, slug, r_par, alpha, llfr_override = NULL) {
  cat(sprintf("--- %s (alpha=%.1f%%) ---\n", label, alpha*100))
  bc  <- bootstrap_curve(T_mkt, r_par, FSP, solver = "newton")
  zc  <- log(1 + bc$z)
  ext <- extrapolate_from(zc, alpha, llfr_override)
  t_all <- c(bc$t, ext$t); z_all <- c(bc$z, ext$z); zc_all <- c(zc, ext$zc)
  L_c <- if (is.null(llfr_override)) llfr_c(zc) else llfr_override

  # re-pricing
  rep_err <- max(sapply(seq_along(T_mkt), function(i)
    abs(r_par[i]*sum(bc$d[1:T_mkt[i]]) + bc$d[T_mkt[i]] - 1)))

  # forward continuo annuale su tutta la curva
  fc_all <- numeric(length(t_all)); fc_all[1] <- zc_all[1]
  for (i in 2:length(t_all)) fc_all[i] <- t_all[i]*zc_all[i] - t_all[i-1]*zc_all[i-1]

  # --- fig curva spot+forward 1..150 ---
  df_curve <- rbind(
    data.frame(T = t_all, Tasso = z_all*100,           Tipo = "Spot z(0,T)"),
    data.frame(T = t_all, Tasso = (exp(fc_all)-1)*100,  Tipo = "Forward f(0,T)"))
  spot_nodi <- data.frame(T = bc$t[bc$is_obs], Tasso = bc$z[bc$is_obs]*100)
  p_curve <- ggplot(df_curve, aes(x = T, y = Tasso, color = Tipo, linetype = Tipo)) +
    geom_line(linewidth = 1.05) +
    geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
    geom_vline(xintercept = FSP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
    geom_point(data = spot_nodi, aes(x = T, y = Tasso), color = col_nodi, size = 2,
               shape = 16, inherit.aes = FALSE) +
    annotate("text", x = 112, y = UFR_ann*100 + 0.06, label = sprintf("UFR = %.2f%%", UFR_ann*100),
             color = col_ufr, size = 3.2) +
    scale_color_manual(values = c("Spot z(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
    scale_linetype_manual(values = c("Spot z(0,T)" = "solid", "Forward f(0,T)" = "dashed")) +
    labs(title = sprintf("Curva EIOPA bootstrap + FSP/LLFR — %s", label),
         subtitle = sprintf("FSP=%d, LLFR=%.3f%%, UFR=%.2f%%, alpha=%.1f%%",
                            FSP, (exp(L_c)-1)*100, UFR_ann*100, alpha*100),
         x = "Scadenza T (anni)", y = "Tasso (%)", color = NULL, linetype = NULL) + theme_dispensa
  save_fig(paste0("fig_curve_", slug), p_curve)

  # --- confronto LIKE-FOR-LIKE con curva ufficiale ricalcolata a nuovo metodo ---
  mats <- 1:120
  z_rec  <- z_all[match(mats, t_all)]*100
  z_o    <- znew_at(mats)
  res    <- (z_rec - z_o)*100                    # bps
  ok     <- is.finite(res)
  res_nodi <- res[match(T_mkt, mats)]
  RMSE_liq <- sqrt(mean(res[1:FSP]^2, na.rm = TRUE)); max_liq <- max(abs(res[1:FSP]), na.rm = TRUE)
  ex_sel <- mats > FSP & ok
  RMSE_ex <- sqrt(mean(res[ex_sel]^2)); max_ex <- max(abs(res[ex_sel]))
  ylim_res <- max(3, ceiling(max(abs(res[ok]))))

  df_top <- data.frame(T = mats, val = z_rec)
  df_off <- data.frame(T = mats, val = z_o)
  p_top <- ggplot() +
    geom_vline(xintercept = FSP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(data = df_top, aes(x = T, y = val, color = "Bootstrap ricostruito"), linewidth = 1.1) +
    geom_point(data = df_off[df_off$T %% 5 == 0 | df_off$T <= FSP, ],
               aes(x = T, y = val, color = "EIOPA nuovo metodo (bootstrap)"),
               shape = 21, size = 1.5, fill = "white", stroke = 0.9) +
    annotate("text", x = 118, y = UFR_ann*100 + 0.05, label = "UFR = 3.30%", hjust = 1,
             color = col_ufr, size = 3.1) +
    scale_color_manual(values = c("Bootstrap ricostruito" = col_spot,
                                  "EIOPA nuovo metodo (bootstrap)" = col_fwd)) +
    scale_x_continuous(breaks = c(1,5,10,15,20,30,50,80,120)) +
    labs(title = sprintf("%s vs curva ufficiale EIOPA (nuovo metodo, bootstrap)", label),
         subtitle = "Confronto like-for-like: stesso metodo (bootstrap) su entrambi i lati",
         x = NULL, y = "Tasso spot (%)", color = NULL) +
    theme_dispensa + theme(legend.position = "top")

  df_res <- data.frame(T = mats[ok], Res = res[ok],
                       Zona = ifelse(mats[ok] <= FSP, "Liquida", "Estrapolazione"))
  df_res$Zona <- factor(df_res$Zona, levels = c("Liquida", "Estrapolazione"))
  p_bot <- ggplot(df_res, aes(x = T, y = Res, fill = Zona)) +
    geom_col(width = 0.9) +
    geom_vline(xintercept = FSP + 0.5, color = "gray50", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    annotate("text", x = FSP + 1, y = ylim_res*0.85, label = "FSP = 20a", hjust = 0,
             color = "gray40", size = 3.1) +
    scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
    scale_x_continuous(breaks = c(1,5,10,15,20,30,50,80,120)) +
    scale_y_continuous(limits = c(-ylim_res, ylim_res)) +
    labs(subtitle = sprintf(paste0("Scarto bootstrap - nuovo metodo ufficiale (bps, 1-120a). ",
                                    "RMSE liquida = %.2f bps, RMSE estrapolazione = %.2f bps."),
                            RMSE_liq, RMSE_ex),
         x = "Scadenza T (anni)", y = "Scarto (bps)", fill = NULL) +
    theme_dispensa + theme(legend.position = "top")

  path_vs <- file.path(dir_out, paste0("fig_vs_newmethod_", slug, ".pdf"))
  pdf(path_vs, width = 9, height = 7.5)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(2, 1, heights = grid::unit(c(2,1), "null"))))
  print(p_top, vp = grid::viewport(layout.pos.row = 1))
  print(p_bot, vp = grid::viewport(layout.pos.row = 2))
  dev.off()
  cat(sprintf("  [OK] %s\n", path_vs))

  # --- tabella delta ai nodi DLT (CSV + LaTeX) ---
  tab_nodi <- data.frame(
    Tenor = T_mkt,
    boot_zero_pct = round(z_all[match(T_mkt, t_all)]*100, 4),
    EIOPA_new_pct = round(znew_at(T_mkt), 4),
    delta_bps     = round(res_nodi, 2))
  cat("  Delta ai nodi DLT (bootstrap - EIOPA nuovo metodo):\n"); print(tab_nodi, row.names = FALSE)
  write.csv(tab_nodi, file.path(dir_out, paste0("tab_delta_new_", slug, ".csv")), row.names = FALSE)

  {
    lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
      "\\begin{table}[H]\\centering\\small",
      sprintf(paste0("\\caption{Delta ai tenor DLT tra la ricostruzione a bootstrap (%s) e la curva ",
                      "EIOPA ufficiale di dicembre~2025 ricalcolata col nuovo metodo (bootstrap). ",
                      "Confronto like-for-like.}"), label),
      sprintf("\\label{tab:delta-new-%s}\\renewcommand{\\arraystretch}{1.15}", slug),
      "\\begin{tabular}{rccc}", "\\toprule",
      "$T_k$ (anni) & Bootstrap (\\%) & EIOPA nuovo metodo (\\%) & $\\Delta$ (bps)\\\\",
      "\\midrule")
    for (i in seq_along(T_mkt)) {
      tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
      lines <- c(lines, sprintf("%s%d & %.4f & %.4f & %.2f\\\\",
                                tint, tab_nodi$Tenor[i], tab_nodi$boot_zero_pct[i],
                                tab_nodi$EIOPA_new_pct[i], tab_nodi$delta_bps[i]))
    }
    lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
    writeLines(lines, file.path(dir_out, paste0("tab_delta_new_", slug, ".tex")))
    message("  [OK] tab_delta_new_", slug, ".tex")
  }

  cat(sprintf("  re-pricing max|..|=%.2e  LLFR=%.4f%%  RMSE_liq=%.3f max_liq=%.3f  RMSE_ex=%.3f max_ex=%.3f\n\n",
              rep_err, (exp(L_c)-1)*100, RMSE_liq, max_liq, RMSE_ex, max_ex))

  list(label = label, slug = slug, alpha = alpha, LLFR = exp(L_c)-1, rep_err = rep_err,
       RMSE_liq = RMSE_liq, max_liq = max_liq, RMSE_ex = RMSE_ex, max_ex = max_ex,
       t_all = t_all, z_all = z_all, fc_all = fc_all, bc = bc, ext = ext)
}

resA <- run_source("Fonte A: par EUSA di mercato",        "eusa", r_eusa, alpha)
resB <- run_source("Fonte B: par impliciti dall'ufficiale", "impl", r_impl, alpha)
resC <- run_source("Fonte C: dati input EIOPA originali (YE25)", "input", r_input, alpha)
resD <- run_source("Fonte D: input EIOPA (YE25) con LLFR ufficiale xlsm", "llfr", r_input, alpha,
                    llfr_override = LLFR_c_XLSM)

# ==============================================================================
# 4b. RICOSTRUZIONE PRINCIPALE (dispensa 01): LLFR pesato + curva + benchmark
# ==============================================================================
# La dispensa principale usa la ricostruzione dai dati di input EIOPA con l'LLFR
# calcolato secondo la formula ufficiale a media pesata (EIOPA-BoS-26-198, sez.
# 8.5.6). Qui: (i) riproduciamo il calcolo pesato dell'LLFR e verifichiamo che
# coincide con LLFR_c_XLSM; (ii) generiamo curva, confronto col benchmark e
# tabelle con titoli neutri.

# --- (i) LLFR a media pesata: 5 tenor DLT del tool ufficiale (20/25/30/40/50) ---
# Zero rate a capitalizzazione CONTINUA (colonna "Bootstrapped Zero Rate CC" del
# tool ufficiale EIOPA); LLPbeforeFSP = 15 (ultimo tenor DLT prima dell'FSP).
llfr_LLP    <- 15
llfr_zLLP   <- 0.0306008
llfr_ten    <- c(20, 25, 30, 40, 50)
llfr_w      <- c(0.33, 0.12, 0.48, 0.04, 0.03)
llfr_zCC    <- c(0.031587, 0.031676, 0.031461, 0.030718, 0.029257)
# forward continui: primo termine tra LLP(15) e FSP(20); gli altri tra FSP e t_k
llfr_fwd    <- numeric(length(llfr_ten))
llfr_fwd[1] <- (llfr_ten[1]*llfr_zCC[1] - llfr_LLP*llfr_zLLP) / (llfr_ten[1] - llfr_LLP)
for (i in 2:length(llfr_ten))
  llfr_fwd[i] <- (llfr_ten[i]*llfr_zCC[i] - llfr_ten[1]*llfr_zCC[1]) / (llfr_ten[i] - llfr_ten[1])
llfr_contrib <- llfr_w * llfr_fwd
LLFR_weighted <- sum(llfr_contrib)
cat(sprintf("\n  LLFR pesato ricalcolato = %.6f%% (continuo);  costante LLFR_c_XLSM = %.6f%%\n",
            LLFR_weighted*100, LLFR_c_XLSM*100))

# tabella LaTeX del calcolo pesato
{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Calcolo dell'LLFR a media pesata (EIOPA-BoS-26-198, sez.~8.5.6) per ",
           "dicembre~2025. Ogni riga: forward continuo $f^c$ tra la scadenza indicata e il ",
           "riferimento precedente (l'FSP a 20 anni, o il tenor DLT 15 per il primo termine), ",
           "moltiplicato per il peso $w$. La somma dei contributi \\`e l'$\\LLFR^c$.}"),
    "\\label{tab:llfr-weighted}\\renewcommand{\\arraystretch}{1.2}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "Tenor (anni) & peso $w$ & $f^c$ (\\%) & contributo $w\\,f^c$ (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(llfr_ten)) {
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    lines <- c(lines, sprintf("%s%d & %.2f & %.4f & %.4f\\\\", tint, llfr_ten[i],
                              llfr_w[i], llfr_fwd[i]*100, llfr_contrib[i]*100))
  }
  lines <- c(lines, "\\midrule",
    sprintf("\\textbf{$\\LLFR^c$} & \\textbf{%.2f} & & \\textbf{%.4f}\\\\",
            sum(llfr_w), LLFR_weighted*100),
    "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_llfr_weighted.tex"))
  message("  [OK] tab_llfr_weighted.tex")
}

# --- (ii) curva ricostruita (titoli neutri) --- vista limitata a 60 anni (coerente con le
# altre figure di livello della dispensa; la convergenza fino a 150 e' gia' mostrata da
# Fig.11/12, pensate apposta per l'orizzonte lungo)
t_all <- resD$t_all; z_all <- resD$z_all; fc_all <- resD$fc_all
sel60 <- t_all <= 60

# --- fig: spot vs forward, dati bootstrap (per Sez.2 del tex: sostituisce l'illustrazione
# generica Smith-Wilson con la STESSA ricostruzione di fig_ricostruzione_dic qui sotto, cosi'
# la Figura 2 e la Figura 9 della dispensa mostrano coerentemente la stessa curva) ---
dfSF01 <- rbind(
  data.frame(T = t_all[sel60], val = z_all[sel60]*100,           Serie = "Spot r(t)"),
  data.frame(T = t_all[sel60], val = (exp(fc_all[sel60])-1)*100, Serie = "Forward f(t)"))
pSF01 <- ggplot(dfSF01, aes(x = T, y = val, color = Serie)) + geom_line(linewidth = 1) +
  scale_color_manual(values = c("Spot r(t)" = col_spot, "Forward f(t)" = col_fwd)) +
  labs(title = "Tasso spot r(t) e forward istantaneo f(t)",
       subtitle = "Curva EIOPA EUR (bootstrap + FSP/LLFR), dicembre 2025 -- il forward si muove piu' rapidamente: lo spot ne e' la media su [0,t]",
       x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) + theme_dispensa +
  scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60))
save_fig("fig_spot_fwd_bootstrap", pSF01)

df_curve_m <- rbind(
  data.frame(T = t_all[sel60], Tasso = z_all[sel60]*100,          Tipo = "Spot z(0,T)"),
  data.frame(T = t_all[sel60], Tasso = (exp(fc_all[sel60])-1)*100, Tipo = "Forward f(0,T)"))
spot_nodi_m <- data.frame(T = resD$bc$t[resD$bc$is_obs], Tasso = resD$bc$z[resD$bc$is_obs]*100)
p_main <- ggplot(df_curve_m, aes(x = T, y = Tasso, color = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.05) +
  geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = FSP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = spot_nodi_m, aes(x = T, y = Tasso), color = col_nodi, size = 2,
             shape = 16, inherit.aes = FALSE) +
  annotate("text", x = 58, y = UFR_ann*100 + 0.06, label = sprintf("UFR = %.2f%%", UFR_ann*100),
           color = col_ufr, size = 3.2, hjust = 1) +
  scale_color_manual(values = c("Spot z(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  scale_linetype_manual(values = c("Spot z(0,T)" = "solid", "Forward f(0,T)" = "dashed")) +
  labs(title = sprintf("Curva EIOPA EUR ricostruita (bootstrap + FSP/LLFR) — %s", lab_dic),
       subtitle = sprintf("FSP=%d, LLFR=%.3f%% (media pesata), UFR=%.2f%%, alpha=%.1f%%",
                          FSP, (exp(LLFR_c_XLSM)-1)*100, UFR_ann*100, alpha*100),
       x = "Scadenza T (anni)", y = "Tasso (%)", color = NULL, linetype = NULL) + theme_dispensa +
  scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60))
save_fig("fig_ricostruzione_dic", p_main)

# --- (ii) confronto col benchmark (titoli neutri) ---
# Le statistiche (RMSE/max) restano calcolate sull'intero orizzonte disponibile (1-120a);
# solo la FINESTRA VISUALIZZATA nei due pannelli e' limitata a 60 anni, per coerenza con le
# altre figure di livello della dispensa.
mats <- 1:120
z_rec <- z_all[match(mats, t_all)]*100
z_o   <- znew_at(mats)
res   <- (z_rec - z_o)*100
okm   <- is.finite(res)
res_nodi_m <- res[match(T_mkt, mats)]
RMSE_liq_m <- sqrt(mean(res[1:FSP]^2, na.rm = TRUE)); max_liq_m <- max(abs(res[1:FSP]), na.rm = TRUE)
exsel_m <- mats > FSP & okm
RMSE_ex_m <- sqrt(mean(res[exsel_m]^2)); max_ex_m <- max(abs(res[exsel_m]))

mats60  <- mats <= 60
ylim_m  <- max(1, ceiling(max(abs(res[okm & mats60]))))

df_topm <- data.frame(T = mats[mats60], val = z_rec[mats60])
df_offm <- data.frame(T = mats[mats60], val = z_o[mats60])
p_topm <- ggplot() +
  geom_vline(xintercept = FSP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
  geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
  geom_line(data = df_topm, aes(x = T, y = val, color = "Ricostruzione (queste dispense)"), linewidth = 1.1) +
  geom_point(data = df_offm[df_offm$T %% 5 == 0 | df_offm$T <= FSP, ],
             aes(x = T, y = val, color = "Curva ufficiale EIOPA"),
             shape = 21, size = 1.5, fill = "white", stroke = 0.9) +
  annotate("text", x = 58, y = UFR_ann*100 + 0.05, label = "UFR = 3.30%", hjust = 1,
           color = col_ufr, size = 3.1) +
  scale_color_manual(values = c("Ricostruzione (queste dispense)" = col_spot,
                                "Curva ufficiale EIOPA" = col_fwd)) +
  scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60)) +
  labs(title = sprintf("Ricostruzione vs curva ufficiale EIOPA — %s", lab_dic),
       subtitle = "Tasso spot annuo; stesso metodo (bootstrap + FSP/LLFR pesato) su entrambi i lati",
       x = NULL, y = "Tasso spot (%)", color = NULL) +
  theme_dispensa + theme(legend.position = "top")

df_resm <- data.frame(T = mats[okm & mats60], Res = res[okm & mats60],
                      Zona = ifelse(mats[okm & mats60] <= FSP, "Liquida", "Estrapolazione"))
df_resm$Zona <- factor(df_resm$Zona, levels = c("Liquida", "Estrapolazione"))
p_botm <- ggplot(df_resm, aes(x = T, y = Res, fill = Zona)) +
  geom_col(width = 0.9) +
  geom_vline(xintercept = FSP + 0.5, color = "gray50", linetype = "dashed", linewidth = 0.4) +
  geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
  annotate("text", x = FSP + 1, y = ylim_m*0.85, label = "FSP = 20a", hjust = 0,
           color = "gray40", size = 3.1) +
  scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
  scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60)) +
  scale_y_continuous(limits = c(-ylim_m, ylim_m)) +
  labs(subtitle = sprintf(paste0("Scarto ricostruzione - ufficiale (bps). RMSE (1-120a): ",
                                  "liquida = %.2f, estrapolazione = %.2f bps."),
                          RMSE_liq_m, RMSE_ex_m),
       x = "Scadenza T (anni)", y = "Scarto (bps)", fill = NULL) +
  theme_dispensa + theme(legend.position = "top")

path_m <- file.path(dir_out, "fig_vs_benchmark_dic.pdf")
pdf(path_m, width = 9, height = 7.5)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout = grid::grid.layout(2, 1, heights = grid::unit(c(2,1), "null"))))
print(p_topm, vp = grid::viewport(layout.pos.row = 1))
print(p_botm, vp = grid::viewport(layout.pos.row = 2))
dev.off()
cat(sprintf("  [OK] %s\n", path_m))

# --- (ii) tabella delta ai nodi DLT + alcuni tenor estrapolati (titoli neutri) ---
{
  T_extra <- c(30, 40, 50, 60)
  T_tab   <- c(T_mkt, T_extra)
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Ricostruzione di dicembre~2025 (bootstrap dai dati di input EIOPA, LLFR a ",
           "media pesata) vs curva EIOPA ufficiale, ai 15 tenor DLT e, per illustrare la ",
           "convergenza in estrapolazione, ad alcuni tenor oltre l'FSP (30, 40, 50, 60 anni).}"),
    "\\label{tab:delta-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$T_k$ (anni) & ricostruzione (\\%) & EIOPA ufficiale (\\%) & $\\Delta$ (bps)\\\\",
    "\\midrule")
  for (i in seq_along(T_tab)) {
    if (i == length(T_mkt) + 1) {
      lines <- c(lines, "\\midrule",
                 "\\multicolumn{4}{l}{\\emph{Oltre l'FSP (estrapolazione):}}\\\\",
                 "\\midrule")
    }
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    Tk <- T_tab[i]
    lines <- c(lines, sprintf("%s%d & %.4f & %.4f & %.2f\\\\", tint, Tk,
                              z_rec[match(Tk, mats)], z_o[match(Tk, mats)], res[match(Tk, mats)]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_delta_dic.tex"))
  message("  [OK] tab_delta_dic.tex")
}

# --- (ii) tabella dati di input (solo input EIOPA lordo/after-CRA) ---
{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Par swap EUR di input EIOPA a dicembre~2025 ai 15 tenor DLT ",
           "(\\texttt{eiopa\\_input\\_swap\\_dec2025.csv}), lordi e after-CRA. I tenor 15 e 20 chiudono ",
           "un gap (13$\\to$15, 15$\\to$20).}"),
    "\\label{tab:input-main-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rcc}", "\\toprule",
    "$T_k$ (anni) & input EIOPA lordo (\\%) & after-CRA $r_k$ (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(T_mkt)) {
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    lines <- c(lines, sprintf("%s%d & %.4f & %.4f\\\\", tint, T_mkt[i],
                              s_input[i]*100, r_input[i]*100))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_input_main_dic.tex"))
  message("  [OK] tab_input_main_dic.tex")
}

# --- Excel: curva bootstrap completa (continua e annua comp.), 1-100a -----------
#     Nella cartella della dispensa 01; la dispensa 03 ha il proprio file.
if (have_openxlsx) {
  xlsx_path   <- file.path(dir_out, "curva_ricostruita_dic2025.xlsx")
  mats_full   <- 1:100
  idx_full    <- match(mats_full, t_all)
  zc_all      <- log(1 + z_all)
  df_boot_full <- data.frame(
    Tenor_anni             = mats_full,
    Spot_continuo_pct      = round(zc_all[idx_full] * 100, 6),
    Spot_annuo_comp_pct    = round(z_all[idx_full] * 100, 6),
    Forward_continuo_pct   = round(fc_all[idx_full] * 100, 6),
    Forward_annuo_comp_pct = round((exp(fc_all[idx_full]) - 1) * 100, 6)
  )
  wb <- if (file.exists(xlsx_path)) openxlsx::loadWorkbook(xlsx_path) else openxlsx::createWorkbook()
  if ("Bootstrap" %in% openxlsx::sheets(wb)) openxlsx::removeWorksheet(wb, "Bootstrap")
  openxlsx::addWorksheet(wb, "Bootstrap")
  openxlsx::writeData(wb, "Bootstrap", df_boot_full)
  openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
  message("  [OK] ", xlsx_path, " (foglio Bootstrap)")
} else {
  message("  [SKIP] openxlsx non disponibile: curva_ricostruita_dic2025.xlsx non aggiornato")
}

cat(sprintf("  Ricostruzione principale: RMSE_liq=%.3f max_liq=%.3f  RMSE_ex=%.3f max_ex=%.3f\n\n",
            RMSE_liq_m, max_liq_m, RMSE_ex_m, max_ex_m))

# ==============================================================================
# 5. FIGURE DI SINTESI (ricostruzione di riferimento: input EIOPA + LLFR pesato)
# ==============================================================================
# La ricostruzione di riferimento per la dispensa principale usa i dati di input
# EIOPA e l'LLFR a media pesata (= Fonte D, resD).

# --- fig convergenza |forward - UFR| ---
df_cv <- data.frame(T = resD$ext$t, dist = abs(resD$ext$fc - UFR_c)*1e4)
p6b <- ggplot(df_cv, aes(x = T, y = dist)) +
  geom_line(color = col_fwd, linewidth = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  annotate("text", x = 130, y = 1.4, label = "1 bp", color = "red", size = 3) + scale_y_log10() +
  labs(title = "Convergenza del forward all'UFR",
       subtitle = "Scala log: |forward - UFR| decresce monotonicamente (peso B(a,h)->0)",
       x = "Scadenza T (anni)", y = "|forward - UFR| (bps)") + theme_dispensa
save_fig("fig06b_convergenza_ufr", p6b)

# --- sensitività alpha (LLFR pesato): distanza spot-UFR in bps, scala log, tre alpha ---
df_sa <- do.call(rbind, lapply(c(0.110, alpha, 0.40), function(a) {
  e <- extrapolate_from(log(1 + resD$bc$z), a, LLFR_c_XLSM)
  data.frame(T = e$t, dist = abs(e$z - UFR_ann)*1e4,
             alpha = sprintf("alpha = %.1f%%", a*100)) }))
p7a <- ggplot(df_sa, aes(x = T, y = dist, color = alpha)) +
  geom_line(linewidth = 1) + scale_y_log10() +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  annotate("text", x = 145, y = 1.4, label = "1 bp", color = "red", size = 3) +
  labs(title = expression(paste("Sensitività della velocità di convergenza al parametro ", alpha)),
       subtitle = "Distanza dello spot dall'UFR in bps (scala log): alpha maggiore converge molto piu' rapidamente",
       x = "Scadenza T (anni)", y = "|spot - UFR| (bps)", color = expression(alpha)) + theme_dispensa
save_fig("fig07a_sensitivita_alpha", p7a)

# --- spline vs metodo EIOPA ---
T_eval <- seq(1, 80, by = 0.25)
spline_fit <- splinefun(resD$bc$t[resD$bc$is_obs], resD$bc$z[resD$bc$is_obs]*100, method = "natural")
r_spline <- spline_fit(T_eval)
eiopa_spot <- approx(resD$t_all, resD$z_all*100, xout = T_eval)$y
df_cmp <- rbind(data.frame(T = T_eval, Tasso = r_spline,   Metodo = "Spline cubica naturale"),
                data.frame(T = T_eval, Tasso = eiopa_spot, Metodo = "EIOPA (bootstrap + FSP/LLFR)"))
p8 <- ggplot(df_cmp, aes(x = T, y = Tasso, color = Metodo, linetype = Metodo)) +
  annotate("rect", xmin = FSP, xmax = 80, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.35) +
  annotate("text", x = (FSP+80)/2, y = max(df_cmp$Tasso, na.rm = TRUE),
           label = "Estrapolazione (T > FSP)", color = "gray40", size = 3.3) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = FSP, color = "gray50", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = data.frame(T = resD$bc$t[resD$bc$is_obs], Tasso = resD$bc$z[resD$bc$is_obs]*100),
             aes(x = T, y = Tasso), color = col_nodi, size = 2, shape = 16, inherit.aes = FALSE) +
  annotate("text", x = 55, y = UFR_ann*100 + 0.10, label = "UFR = 3.30%", color = col_ufr, size = 3.2) +
  scale_color_manual(values = c("Spline cubica naturale" = col_llfr,
                                "EIOPA (bootstrap + FSP/LLFR)" = col_spot)) +
  scale_linetype_manual(values = c("Spline cubica naturale" = "dashed",
                                   "EIOPA (bootstrap + FSP/LLFR)" = "solid")) +
  labs(title = "Estrapolazione: spline cubica vs metodo EIOPA",
       subtitle = "Oltre l'FSP la spline estrapola senza vincolo; il metodo EIOPA converge all'UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL, linetype = NULL) + theme_dispensa
save_fig("fig08_confronto_spline", p8)

# ==============================================================================
# 5b. CONFRONTO METODOLOGICO: nuovo metodo (bootstrap) vs Smith-Wilson
#     Due curve UFFICIALI EIOPA dello stesso mese (dicembre 2025) sugli stessi dati:
#       - nuovo metodo : znew_at()  (dec25_eiopa_rfr_newapproach.csv), tenor 1..120
#       - Smith-Wilson : off$spot   (curva pubblicata SW), tenor off$mat 1..150
#     Il delta isola la sola differenza di METODOLOGIA (stessi nodi liquidi).
# ==============================================================================
mats_cmp   <- 1:120
z_new_cmp  <- znew_at(mats_cmp)                                  # % (nuovo metodo)
z_sw_cmp   <- zoff_all_dec[match(mats_cmp, mat_all)] * 100       # % (Smith-Wilson)
delta_cmp  <- (z_new_cmp - z_sw_cmp) * 100                       # bps (nuovo - SW)

# --- fig: confronto diretto delle CURVE di livello (1-60 anni, zoom sulla zona informativa) ---
mats_plot60 <- 1:60
df_curves60 <- rbind(
  data.frame(T = mats_plot60, val = z_new_cmp[mats_plot60], Metodo = "Nuovo metodo (bootstrap)"),
  data.frame(T = mats_plot60, val = z_sw_cmp[mats_plot60],  Metodo = "Smith-Wilson"))
p_swnew_curves <- ggplot(df_curves60, aes(x = T, y = val, color = Metodo, linetype = Metodo)) +
  geom_vline(xintercept = FSP, color = "gray50", linetype = "dashed", linewidth = 0.5) +
  geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dotted", linewidth = 0.7) +
  geom_line(linewidth = 1) +
  annotate("text", x = 58, y = UFR_ann*100 + 0.04, label = "UFR = 3.30%",
           color = col_ufr, size = 3.1, hjust = 1) +
  scale_color_manual(values = c("Nuovo metodo (bootstrap)" = col_spot, "Smith-Wilson" = col_fwd)) +
  scale_linetype_manual(values = c("Nuovo metodo (bootstrap)" = "solid", "Smith-Wilson" = "dashed")) +
  labs(title = "Nuovo metodo vs Smith-Wilson: curve spot — dicembre 2025",
       subtitle = "Fino all'FSP (20 anni) le curve coincidono; oltre, l'estrapolazione diverge (di pochi bps)",
       x = "Scadenza T (anni)", y = "Tasso spot (%)", color = NULL, linetype = NULL) +
  theme_dispensa + scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60))
save_fig("fig_sw_vs_new_curves", p_swnew_curves)

# --- fig: delta (nuovo - SW) in bps, zoom 1-60 anni (il tratto 60-120 e' quasi piatto) ---
df_swnew <- data.frame(T = mats_plot60, delta = delta_cmp[mats_plot60])
i_peak <- which.max(abs(df_swnew$delta)); T_peak <- df_swnew$T[i_peak]; d_peak <- df_swnew$delta[i_peak]
ylim_sw <- max(2, ceiling(max(abs(df_swnew$delta), na.rm = TRUE)))
p_swnew <- ggplot(df_swnew, aes(x = T, y = delta)) +
  annotate("rect", xmin = FSP, xmax = 60, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.35) +
  annotate("text", x = (FSP+60)/2, y = ylim_sw*0.9, label = "Estrapolazione (T > FSP)",
           color = "gray40", size = 3.3) +
  geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
  geom_vline(xintercept = FSP, color = "gray50", linetype = "dashed", linewidth = 0.5) +
  geom_line(color = col_spot, linewidth = 1) +
  geom_point(data = data.frame(T = T_peak, delta = d_peak), aes(x = T, y = delta),
             inherit.aes = FALSE, color = col_fwd, size = 2.2) +
  annotate("text", x = T_peak, y = d_peak - sign(d_peak)*ylim_sw*0.12,
           label = sprintf("max: %+.1f bps (T=%d)", d_peak, T_peak), color = col_fwd, size = 3.1) +
  labs(title = "Nuovo metodo (bootstrap) vs Smith-Wilson — dicembre 2025",
       subtitle = "Delta spot (nuovo - Smith-Wilson) in bps: ~0 in zona liquida, cresce in estrapolazione",
       x = "Scadenza T (anni)", y = expression(paste(Delta, " spot  (nuovo - SW)  [bps]"))) +
  theme_dispensa + scale_x_continuous(breaks = c(1,10,20,30,40,50,60))
save_fig("fig_sw_vs_new", p_swnew)

# tabella delta SW vs nuovo metodo a scadenze chiave (range completo 1-120)
{
  Tsel <- c(1,5,10,15,20,25,30,40,50,60,80,100,120)
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva spot EUR ufficiale EIOPA a dicembre~2025: nuovo metodo (bootstrap) ",
           "vs metodo Smith--Wilson, e loro differenza in bps. La riga in grassetto ($T=20$) \\`e ",
           "l'FSP: sotto le due curve coincidono, oltre iniziano a divergere.}"),
    "\\label{tab:sw-vs-new}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$T$ (anni) & nuovo metodo (\\%) & Smith--Wilson (\\%) & $\\Delta$ (bps)\\\\",
    "\\midrule")
  for (i in seq_along(Tsel)) {
    Tk <- Tsel[i]; j <- match(Tk, mats_cmp)
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    numstr <- if (Tk == FSP) sprintf("\\textbf{%d}", Tk) else as.character(Tk)
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f\\\\",
                              tint, numstr, z_new_cmp[j], z_sw_cmp[j], delta_cmp[j]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_sw_vs_new.tex"))
  message("  [OK] tab_sw_vs_new.tex")
}
cat(sprintf("  Confronto SW vs nuovo metodo: |delta| max in zona liquida = %.3f bps; max in estrap. = %.2f bps\n\n",
            max(abs(delta_cmp[mats_cmp <= FSP]), na.rm = TRUE),
            max(abs(delta_cmp[mats_cmp >  FSP]), na.rm = TRUE)))

# ==============================================================================
# 6. TABELLE LaTeX (\input nella dispensa)
# ==============================================================================

# tab dati input (par EUSA lordi/after-CRA + par impliciti Fonte B + input originali Fonte C)
{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    "\\caption{Par swap EUR a dicembre~2025 ai 15 tenor DLT. Fonte A: \\texttt{EUSA*} (EURIBOR~6M) lordi e after-CRA. Fonte B: par impliciti dalla curva RFR ufficiale (gi\\`a netti CRA). Fonte C: par swap lordi da \\texttt{eiopa\\_input\\_swap\\_dec2025.csv}, i dati di input EIOPA originali. I tenor 15 e 20 chiudono un ``buco'' (13$\\to$15, 15$\\to$20).}",
    "\\label{tab:input-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{lcccc}", "\\toprule",
    "$T_k$ (anni) & \\texttt{EUSA*} $s_k$ (\\%) & after-CRA $r_k$ (\\%) & par implicito (\\%) & input EIOPA (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(T_mkt)) {
    tint <- if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""
    tag  <- if (T_mkt[i] == FSP) "~\\textbf{(FSP)}" else if (T_mkt[i] == 15) "~(buco)" else ""
    lines <- c(lines, sprintf("%s%d%s & %.4f & %.4f & %.4f & %.4f\\\\",
                              tint, T_mkt[i], tag, s_dic[i]*100, r_eusa[i]*100, r_impl[i]*100, s_input[i]*100))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_input_dic.tex"))
  message("  [OK] tab_input_dic.tex")
}

# tab curva riepilogo (Fonte A) a scadenze chiave
{
  Tleft <- c(1,5,10,15,20); Tright <- c(30,50,80,100,150)
  gv <- function(T, v, t_all) v[which(t_all == T)]
  z_all <- resA$z_all; f_all <- exp(resA$fc_all) - 1; t_all <- resA$t_all
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    "\\caption{Curva EIOPA EUR ricostruita (Fonte A, EUSA, dicembre~2025): spot e forward a scadenze chiave.}",
    "\\label{tab:curva}\\renewcommand{\\arraystretch}{1.2}",
    "\\begin{tabular}{rrr|rrr}", "\\toprule",
    "$T$ & Spot (\\%) & Fwd (\\%) & $T$ & Spot (\\%) & Fwd (\\%)\\\\", "\\midrule")
  for (i in seq_along(Tleft))
    lines <- c(lines, sprintf("%d & %.4f & %.4f & %d & %.4f & %.4f\\\\",
      Tleft[i], gv(Tleft[i],z_all,t_all)*100, gv(Tleft[i],f_all,t_all)*100,
      Tright[i], gv(Tright[i],z_all,t_all)*100, gv(Tright[i],f_all,t_all)*100))
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_curva.tex"))
  message("  [OK] tab_curva.tex")
}

# tab riassuntiva 4 fonti (LaTeX)
{
  fmt <- function(x) sprintf("%.2f", x)
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap.R",
    "\\begin{table}[H]\\centering\\small",
    "\\caption{Ricostruzione bootstrap di dicembre~2025 dalle quattro fonti, vs curva EIOPA ufficiale ricalcolata col nuovo metodo (bootstrap). Confronto \\textbf{like-for-like}: stesso metodo su entrambi i lati. Zona liquida = 15 nodi DLT ($T\\le\\FSP$); estrapolazione = tenor interi 21--120. Fonte D usa lo stesso bootstrap della Fonte C ma con l'LLFR preso dal tool ufficiale EIOPA (sperimentale, provenienza da chiarire).}",
    "\\label{tab:summary-fonti}\\renewcommand{\\arraystretch}{1.2}",
    "\\resizebox{\\textwidth}{!}{%",
    "\\begin{tabular}{lccccc}", "\\toprule",
    "Fonte di input & $\\alpha$ & RMSE liq.\\ (bps) & max liq.\\ (bps) & RMSE estrap.\\ (bps) & max estrap.\\ (bps)\\\\",
    "\\midrule",
    sprintf("A --- par \\texttt{EUSA*} di mercato & %.0f\\%% & %s & %s & %s & %s\\\\",
            resA$alpha*100, fmt(resA$RMSE_liq), fmt(resA$max_liq), fmt(resA$RMSE_ex), fmt(resA$max_ex)),
    sprintf("B --- par impliciti dall'ufficiale & %.0f\\%% & %s & %s & %s & %s\\\\",
            resB$alpha*100, fmt(resB$RMSE_liq), fmt(resB$max_liq), fmt(resB$RMSE_ex), fmt(resB$max_ex)),
    sprintf("C --- input EIOPA originali (YE25) & %.0f\\%% & %s & %s & %s & %s\\\\",
            resC$alpha*100, fmt(resC$RMSE_liq), fmt(resC$max_liq), fmt(resC$RMSE_ex), fmt(resC$max_ex)),
    sprintf("D --- Fonte C con LLFR ufficiale xlsm & %.0f\\%% & %s & %s & %s & %s\\\\",
            resD$alpha*100, fmt(resD$RMSE_liq), fmt(resD$max_liq), fmt(resD$RMSE_ex), fmt(resD$max_ex)),
    "\\bottomrule", "\\end{tabular}}", "\\end{table}")
  writeLines(lines, file.path(dir_out, "tab_summary_fonti.tex"))
  message("  [OK] tab_summary_fonti.tex")
}

# tab riassuntiva 4 fonti (CSV)
tab_summary <- data.frame(
  Fonte = c(resA$label, resB$label, resC$label, resD$label),
  alpha = c(resA$alpha, resB$alpha, resC$alpha, resD$alpha),
  RMSE_liq = round(c(resA$RMSE_liq, resB$RMSE_liq, resC$RMSE_liq, resD$RMSE_liq), 3),
  max_liq  = round(c(resA$max_liq,  resB$max_liq,  resC$max_liq,  resD$max_liq), 3),
  RMSE_ex  = round(c(resA$RMSE_ex,  resB$RMSE_ex,  resC$RMSE_ex,  resD$RMSE_ex), 3),
  max_ex   = round(c(resA$max_ex,   resB$max_ex,   resC$max_ex,   resD$max_ex), 3))
write.csv(tab_summary, file.path(dir_out, "tab_summary_fonti.csv"), row.names = FALSE)

cat("\n====================================================================\n")
cat("  CONFRONTO DELLE QUATTRO FONTI (vs curva ufficiale nuovo metodo, bootstrap)\n")
cat("====================================================================\n")
print(tab_summary, row.names = FALSE)

cat("\n====================================================================\n")
cat("  FILE GENERATI in:", dir_out, "\n")
cat("====================================================================\n")
for (f in list.files(dir_out)) cat("  -", f, "\n")
cat("\n")
