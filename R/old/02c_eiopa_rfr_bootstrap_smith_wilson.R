# ==============================================================================
#  Dispensa 02c — Curva EIOPA Risk-Free: i due metodi a confronto
#  Script DEDICATO: genera TUTTE le figure e le tabelle di
#  dispense/02c_eiopa_rfr_bootstrap_smith_wilson.tex
#
#  Destinazione unica: ../output/02c_eiopa_rfr_bootstrap_smith_wilson/
#  La dispensa 02c non dipende quindi dagli script delle lezioni 02 e 03:
#  qui il metodo a bootstrap (EIOPA-BoS-26-198) e il metodo Smith-Wilson
#  (EIOPA-BoS-25-599) sono ricostruiti nella STESSA sessione, dagli STESSI
#  dati di input -- ed e' proprio questo che rende il confronto della Sez. 7
#  un esperimento controllato in cui l'unica variabile e' la metodologia.
#
#  Struttura:
#    PARTE 0  setup condiviso (path, tema, helper, lettori dati)
#    PARTE A  metodo a bootstrap: calcolo
#    PARTE B  metodo Smith-Wilson: calcolo
#    PARTE C  output (figure .pdf e tabelle .tex)
#
#  Input:  ../dati/02_swap_euribor6m_ric_dic2025.xlsx   (par swap input EIOPA)
#          ../dati/02_dec25_eiopa_rfr_newapproach.csv   (benchmark nuovo metodo)
#          ../dati/eiopa_zips/EIOPA_RFR_202512??.zip    (curva ufficiale SW)
# ==============================================================================

rm(list = ls())

# ==============================================================================
# PARTE 0 — SETUP CONDIVISO
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(reshape2)
})
have_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)
if (!have_openxlsx) stop("Il pacchetto openxlsx e' necessario per leggere i dati di input.")

# Se lanciato da RStudio si posiziona nella cartella dello script (come 03).
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

root    <- dirname(getwd())                       # radice del progetto (cwd = R/)
dir_dat <- file.path(root, "dati")
dir_out <- file.path(root, "output", "02c_eiopa_rfr_bootstrap_smith_wilson")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

# --- tema e colori (unici per tutta la dispensa) ------------------------------
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

GEN <- "% GENERATO da R/02c_eiopa_rfr_bootstrap_smith_wilson.R"

# --- lettore unico dello zip ufficiale EIOPA ----------------------------------
# Unifica read_eiopa_sw() della 02 e read_eiopa_official() della 03: restituisce
# la curva spot ufficiale (metodo Smith-Wilson) piu' CRA e alpha pubblicati.
read_eiopa_official <- function(ym = "202512") {
  zdir <- file.path(dir_dat, "eiopa_zips")
  tryCatch({
    zf <- list.files(zdir, pattern = paste0("^EIOPA_RFR_", ym, "[0-9]{2}\\.zip$"),
                     full.names = TRUE)
    if (length(zf) == 0) return(NULL)
    zf    <- zf[1]
    inner <- utils::unzip(zf, list = TRUE)$Name
    ts    <- grep("Term_Structures", inner, value = TRUE, ignore.case = TRUE)[1]
    if (is.na(ts)) return(NULL)
    utils::unzip(zf, files = ts, exdir = tempdir(), overwrite = TRUE)
    raw  <- openxlsx::read.xlsx(file.path(tempdir(), ts), sheet = "RFR_spot_no_VA",
                                colNames = FALSE, skipEmptyRows = FALSE,
                                skipEmptyCols = FALSE)
    lab  <- raw[[2]]; val <- raw[[3]]
    getp <- function(nm) as.numeric(val[which(lab == nm)[1]])
    ml   <- suppressWarnings(as.numeric(lab))
    sel  <- which(!is.na(ml) & ml >= 1 & ml <= 150)
    tt   <- ml[sel]; zz <- suppressWarnings(as.numeric(val[sel]))
    ok   <- !is.na(tt) & !is.na(zz)
    list(CRA = getp("CRA"), alpha = getp("alpha"), zip = basename(zf),
         curva = data.table(tenor = tt[ok], rann = zz[ok]))
  }, error = function(e) NULL)
}

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
cat("  DISPENSA 02c -> ", normalizePath(dir_out, mustWork = FALSE), "\n")
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

# ==============================================================================
# PARTE B — IL METODO SMITH-WILSON (EIOPA-BoS-25-599)
# ==============================================================================
# Codice di riferimento per la ricostruzione di dicembre 2025 (Sez. 4 e 6.2
# della dispensa). Nucleo numerico: sistema SPD risolto per Cholesky (Sez.
# "Il principio di minima energia") + calibrazione di alpha per BISEZIONE
# (Sez. "Calibrazione di alpha"). Si sceglie la bisezione, e non Newton,
# perche' evita di dover derivare il forward rispetto ad alpha: Newton
# richiederebbe dH/dalpha, d(dH/dt)/dalpha e quindi db/dalpha -- tre derivate
# aggiuntive per un guadagno di sole poche iterazioni, non essenziale qui.
#
# Nota informativa (nessun impatto sul metodo scelto sotto): la macro VBA
# ufficiale di EIOPA per Smith-Wilson (funzioni SmithWilsonBruteForce/Galfa,
# vedi R/marcort.txt) non usa ne' bisezione ne' Newton per alpha. Scansiona
# alpha a passi di 0.1 finche' il criterio si inverte, poi raffina una cifra
# decimale alla volta (funzione AlfaScan, 5 raffinamenti) fino a 6 cifre: una
# griglia via via piu' fitta, non una ricerca di zeri in senso stretto. Usa
# anche un criterio di arresto algebricamente diverso, riformulato tramite
# una quantita' kappa per evitare di ricostruire l'intera matrice di Wilson
# ad ogni valutazione -- una scorciatoia pensata per la velocita' in
# Excel/VBA, non per la trasparenza didattica che cerchiamo qui.

# --- B.1 parametri e dati di input (sez. 9.7-9.14) ---------------------------
LLP   <- 20                       # Last Liquid Point = FSP del nuovo metodo
CP    <- max(LLP + 40, 60)        # Convergence Point
tau   <- 1e-4                     # tolleranza di convergenza (1 bp)
a_min <- 0.05                     # limite inferiore regolamentare per alpha
omega <- UFR_c                    # intensita' dell'UFR: stesso UFR del bootstrap

T_mkt <- c(1:13, 15, 20)          # 15 scadenze DLT quotate (= DLT nel testo)
N     <- length(T_mkt)            # numero di strumenti (colonne di C)
u_pay <- seq_len(LLP)             # 20 date di pagamento annuali (= u nel testo)
m     <- length(u_pay)            # numero di date di pagamento (righe di C)

s_sw <- s_post[T_mkt]             # par after-CRA ai 15 tenor DLT, per tenor esatto
                                   # (= identico input del bootstrap; NON per posizione
                                   #  di riga nel file di dati, che sarebbe fragile)

# --- B.2 la matrice dei flussi di cassa C e i termini Q, p, q ----------------
# C[i,j] e' il flusso pagato al tempo u_i dallo strumento j-esimo: la cedola
# s_j per ogni anno prima della scadenza, cedola+rimborso (1+s_j) all'anno
# della scadenza T_j. Costruzione colonna per colonna.
C <- matrix(0, nrow = m, ncol = N)
for (col_c in seq_along(T_mkt)) {
  Tj       <- T_mkt[col_c]
  colj     <- rep(s_sw[col_c], Tj)
  colj[Tj] <- colj[Tj] + 1
  C[1:Tj, col_c] <- colj
}

delta <- exp(-omega * u_pay)      # sconto di base (UFR): delta_i = exp(-omega u_i)
Q     <- diag(delta) %*% C        # Q = diag(delta) C (eq. sistema Sez. 6.2)
p     <- rep(1, N)                # prezzo di mercato di ogni strumento = 1 (par)
q     <- as.numeric(t(C) %*% delta)

# --- B.3 il kernel di Wilson e le sue matrici --------------------------------
H_heart <- function(t, u, a) {                       # H(t,u): cuore di Wilson
  mn <- pmin(t, u); Mx <- pmax(t, u)
  a * mn - exp(-a * Mx) * sinh(a * mn)
}
dHdt <- function(t, u, a) {                          # dH/dt(t,u): serve al forward
  ifelse(t <= u,
         a - a * exp(-a * u) * cosh(a * t),
         a * exp(-a * t) * sinh(a * u))
}
W_fun <- function(t, u, a, om = omega) exp(-om * (t + u)) * H_heart(t, u, a)

# Le due matrici sotto sono costruite a doppio ciclo esplicito, non con
# outer()/sapply() vettorizzati: piu' lento, ma corrisponde riga per riga
# alla definizione H = [H(t_i,u_j)] della dispensa -- scelta didattica.
Hmat <- function(t, u, a) {
  out <- matrix(0, length(t), length(u))
  for (i in seq_along(t)) for (j in seq_along(u)) out[i, j] <- H_heart(t[i], u[j], a)
  out
}
dHdvmat <- function(t, u, a) {
  out <- matrix(0, length(t), length(u))
  for (i in seq_along(t)) for (j in seq_along(u)) out[i, j] <- dHdt(t[i], u[j], a)
  out
}

# --- B.4 soluzione del sistema SPD (Q'HQ) b = p - q, per Cholesky -----------
b_solve <- function(a) {
  AA <- t(Q) %*% Hmat(u_pay, u_pay, a) %*% Q      # matrice SPD del sistema
  R  <- chol(AA)                                  # AA = R'R
  y  <- forwardsolve(t(R), p - q)                 # R' y = p - q
  backsolve(R, y)                                 # R b = y
}
zeta <- function(a) as.numeric(Q %*% b_solve(a))  # zeta = Q b

# --- B.5 fattori di sconto, spot e forward, a una scadenza qualsiasi v ------
P_fun <- function(v, z, a) {
  exp(-omega * v) * (1 + as.numeric(Hmat(v, u_pay, a) %*% z))
}
spot_int <- function(v, z, a) -log(P_fun(v, z, a)) / v
spot_ann <- function(v, z, a) exp(spot_int(v, z, a)) - 1
fwd_int  <- function(v, z, a) {
  Hv <- as.numeric(Hmat(v, u_pay, a) %*% z)
  Gv <- as.numeric(dHdvmat(v, u_pay, a) %*% z)
  omega - Gv / (1 + Hv)
}
fwd_ann  <- function(v, z, a) exp(fwd_int(v, z, a)) - 1

# --- B.6 calibrazione di alpha per bisezione (criterio eq. criterio-alpha) --
# g(alpha) = f(0,CP;alpha) - omega - tau: la radice cercata e' il piu' piccolo
# alpha >= a_min per cui il forward al Convergence Point rientra nella
# tolleranza tau attorno all'UFR. La funzione traccia ogni iterazione (utile
# a fini didattici, sullo stesso schema di newton_traccia() in Parte A).
g_alpha <- function(a) fwd_int(CP, zeta(a), a) - omega - tau

sw_calibra_alpha_bisezione <- function(a_lo = 0.02, a_hi = 0.30, tol = 1e-16, nmax = 200) {
  v_lo <- g_alpha(a_lo); v_hi <- g_alpha(a_hi)
  if (v_lo * v_hi > 0)
    stop("L'intervallo [a_lo, a_hi] non contiene una radice di g(alpha).")
  trace  <- data.table(k = integer(0), a = numeric(0), g = numeric(0), errore = numeric(0))
  errore <- Inf; k <- 0L
  while (errore > tol && k < nmax) {
    a_mid <- (a_lo + a_hi) / 2
    g_mid <- g_alpha(a_mid)
    errore <- abs(g_mid)
    if (g_mid * v_lo > 0) { a_lo <- a_mid; v_lo <- g_mid } else { a_hi <- a_mid }
    k <- k + 1L
    trace <- rbind(trace, data.table(k = k, a = (a_lo + a_hi) / 2, g = g_mid, errore = errore))
  }
  list(alpha = max(a_min, tail(trace$a, 1)), trace = trace)
}

# --- B.7 calibrazione su dicembre 2025 ---------------------------------------
off <- read_eiopa_official("202512")
if (is.null(off)) stop("Curva ufficiale EIOPA (zip dicembre 2025) non trovata.")
eiopa_sw <- off$curva

bis    <- sw_calibra_alpha_bisezione()
a_crit <- bis$alpha                                       # alpha dal criterio (bisezione)
a_sw   <- if (is.finite(off$alpha)) off$alpha else a_crit # curva pubblicata: usa l'ufficiale

Qb  <- zeta(a_sw)                                          # zeta alla curva pubblicata
QHQ <- t(Q) %*% Hmat(u_pay, u_pay, a_sw) %*% Q

rep_err <- max(abs(t(C) %*% P_fun(u_pay, Qb, a_sw) - 1))
cat(sprintf("  [B] zip %s | CRA = %.0f bps | alpha ufficiale = %.4f | alpha criterio (bisezione) = %.4f | %d iterazioni\n",
            off$zip, off$CRA, a_sw, a_crit, nrow(bis$trace)))
cat(sprintf("  [B] verifica riprezzamento: max|C'P - 1| = %.2e\n", rep_err))

# ==============================================================================
# PARTE C — OUTPUT: FIGURE E TABELLE
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

# ------------------------------------------------------------------------------
# C.3  Sezione 4 e 5.3: il metodo Smith-Wilson
# ------------------------------------------------------------------------------

# --- funzioni di Wilson: le "basi" dell'interpolante -------------------------
{
  t_grid <- seq(0.01, 60, length.out = 600)
  u_nodi <- c(1, 5, 10, 20)
  df3 <- rbindlist(lapply(u_nodi, function(uj)
    data.table(t = t_grid, W = W_fun(t_grid, uj, a_sw),
               u = factor(paste0("u = ", uj, "a"), levels = paste0("u = ", u_nodi, "a")))))
  p3 <- ggplot(df3, aes(x = t, y = W, color = u)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
    geom_vline(xintercept = LLP, linetype = "dashed", color = "gray70", linewidth = 0.4) +
    geom_line(linewidth = 0.9) +
    labs(title = "Funzioni di Wilson W(t,u_j): le 'basi' dell'interpolante SW",
         subtitle = sprintf("La curva SW e' combinazione lineare di queste funzioni (alpha = %.4f)", a_sw),
         x = "t (anni)", y = expression(W(t, u[j])), color = "Nodo") +
    theme_dispensa
  save_fig("fig3_kernel_wilson", p3)
}

# --- matrice SPD del sistema Q'HQ --------------------------------------------
{
  df4 <- melt(QHQ); names(df4) <- c("i", "j", "v")
  df4$i_lab <- factor(T_mkt[df4$i], levels = T_mkt)
  df4$j_lab <- factor(T_mkt[df4$j], levels = rev(T_mkt))
  ev_min <- min(eigen(QHQ, symmetric = TRUE, only.values = TRUE)$values)
  p4 <- ggplot(df4, aes(x = i_lab, y = j_lab, fill = v)) + geom_tile() +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0) +
    labs(title = expression(paste("Matrice del sistema  ", Q^T, H, Q,
                                  "  (simmetrica definita positiva)")),
         subtitle = sprintf("n = %d strumenti; lambda_min = %.2e > 0  =>  Cholesky applicabile",
                            N, ev_min),
         x = "Scadenza (anni)", y = "Scadenza (anni)", fill = NULL) +
    theme_dispensa + theme(aspect.ratio = 1,
                           axis.text.x = element_text(size = 7),
                           axis.text.y = element_text(size = 7))
  save_fig("fig4_matrice_QHQ", p4, w = 7, h = 6)
}

# --- calibrazione di alpha: g(alpha) come ricerca di zeri --------------------
a_grid <- seq(a_min, 0.30, length.out = 200)
g_vals <- sapply(a_grid, function(a) (fwd_int(CP, zeta(a), a) - omega) * 1e4)
plot_alpha <- function(mostra_ufficiale, sottotitolo) {
  p <- ggplot(data.table(alpha = a_grid, g = g_vals), aes(x = alpha, y = g)) +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = -1, ymax = 1, fill = "gray85", alpha = 0.5) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
    geom_line(linewidth = 1, color = col_fwd) +
    geom_vline(xintercept = a_crit, color = col_spot, linetype = "dashed", linewidth = 0.6) +
    geom_vline(xintercept = a_min, color = "gray55", linetype = "dotted", linewidth = 0.5) +
    annotate("text", x = a_crit, y = max(g_vals) * 0.85,
             label = sprintf("alpha* = %.4f", a_crit), hjust = -0.1, color = col_spot, size = 3.6) +
    annotate("text", x = a_min, y = max(g_vals) * 0.55, label = sprintf("alpha_min = %.2f", a_min),
             hjust = -0.1, color = "gray40", size = 3.3) +
    labs(title = "Calibrazione di alpha: ricerca di zeri (criterio sez. 9.14)",
         subtitle = sottotitolo, x = expression(alpha), y = "f(CP, alpha) - omega  (bps)") +
    theme_dispensa
  if (mostra_ufficiale)
    p <- p + geom_vline(xintercept = a_sw, color = "#2E7D32", linetype = "dotdash", linewidth = 0.5)
  p
}
save_fig("fig5_calibrazione_alpha", plot_alpha(FALSE,
  "g(alpha) = f(CP,alpha) - omega in bps; banda grigia = tolleranza +/-1 bp"))
save_fig("fig_sw_alpha_dic", plot_alpha(TRUE, sprintf(
  "Dicembre 2025. Linea blu: alpha* dal criterio = %.4f; linea verde: alpha ufficiale EIOPA = %.4f",
  a_crit, a_sw)))

# --- spot e forward della curva SW calibrata ---------------------------------
grid_f <- seq(0.5, 60, by = 0.25)
df_curve_sw <- rbind(
  data.table(T = grid_f, val = spot_ann(grid_f, Qb, a_sw) * 100, Serie = "Spot r(0,T)"),
  data.table(T = grid_f, val = fwd_ann (grid_f, Qb, a_sw) * 100, Serie = "Forward f(0,T)"))
plot_sw_curve <- function(titolo, sottotitolo) {
  ggplot(df_curve_sw, aes(x = T, y = val, color = Serie)) +
    geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(linewidth = 1) +
    annotate("text", x = 59, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
             hjust = 1, color = col_ufr, size = 3.4) +
    scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = titolo, subtitle = sottotitolo,
         x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) +
    theme_dispensa
}
save_fig("fig2_spot_forward_par", plot_sw_curve("Spot e forward — dicembre 2025",
  sprintf("Curva Smith-Wilson calibrata. Il forward converge all'UFR al CP = %d anni.", CP)))
save_fig("fig_sw_curve_dic", plot_sw_curve("Curva Smith-Wilson calibrata — dicembre 2025",
  "Spot r(0,T) e forward f(0,T). Linea viola = UFR = 3.30%."))

# --- fattori di sconto SW con i 15 nodi DLT ----------------------------------
{
  grid_P <- seq(0.5, 22, by = 0.1)
  p_sn <- ggplot(data.table(T = grid_P, P = P_fun(grid_P, Qb, a_sw)), aes(x = T, y = P)) +
    geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_line(linewidth = 1, color = col_spot) +
    geom_point(data = data.table(T = T_mkt, P = P_fun(T_mkt, Qb, a_sw)),
               aes(x = T, y = P), inherit.aes = FALSE, color = col_nodi, size = 2.5) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20)) +
    labs(title = "Fattori di sconto P(0,T) — Smith-Wilson, dicembre 2025",
         subtitle = sprintf(paste0("Punti neri: P(0,T_j) ai 15 nodi DLT. ",
                                   "Verifica di riprezzamento: max|C'P - 1| = %.1e"), rep_err),
         x = "Scadenza T (anni)", y = "P(0,T)") +
    theme_dispensa
  save_fig("fig_sconto_nodi_dic", p_sn)
}

# --- matrice dei flussi di cassa C in LaTeX ----------------------------------
{
  lines <- c(GEN, "\\begin{table}[H]", "\\centering",
    paste0("\\caption{Matrice dei flussi di cassa $\\mathbf{C}\\in\\mathbb{R}^{20\\times 15}$,",
           " dicembre~2025. Celle \\colorbox{cyan!20}{azzurre} = cedola $s_j$;",
           " celle \\colorbox{orange!35}{arancio} = cedola$+$rimborso $1{+}s_j$;",
           " punti = flusso nullo.}"),
    "\\label{tab:C-dic}", "\\resizebox{\\textwidth}{!}{%",
    "\\renewcommand{\\arraystretch}{1.15}", "\\scriptsize",
    paste0("\\begin{tabular}{r|", paste(rep("r", N), collapse = ""), "}"), "\\toprule",
    paste0("$u_i\\backslash T_j$ & ",
           paste(sprintf("\\textbf{%dY}", T_mkt), collapse = " & "), " \\\\"), "\\midrule")
  for (i in seq_len(m)) {
    cells <- character(N)
    for (j in seq_len(N)) {
      Tj <- T_mkt[j]; v <- C[i, j]
      cells[j] <- if (i < Tj) sprintf("\\cellcolor{cyan!18}$%.4f$", v)
             else if (i == Tj) sprintf("\\cellcolor{orange!35}$\\mathbf{%.4f}$", v)
             else "$\\cdot$"
    }
    lines <- c(lines, paste0("$", i, "$ & ", paste(cells, collapse = " & "), " \\\\"))
  }
  save_tab("tab_C_dic", c(lines, "\\bottomrule", "\\end{tabular}}", "\\end{table}"))
}

# --- SW ricostruito vs SW ufficiale EIOPA ------------------------------------
{
  mats_all   <- 1:80
  sp_sw_all  <- spot_ann(mats_all, Qb, a_sw) * 100
  sp_off_all <- eiopa_sw$rann[match(mats_all, eiopa_sw$tenor)] * 100
  res_all    <- (sp_sw_all - sp_off_all) * 100
  ok_all     <- is.finite(res_all)
  RMSE_liq   <- sqrt(mean(res_all[match(T_mkt, mats_all)]^2, na.rm = TRUE))
  ylim_res   <- max(2, ceiling(max(abs(res_all[ok_all]), na.rm = TRUE)))
  cat(sprintf("  [C] SW vs ufficiale: RMSE ai nodi DLT = %.3f bps, max = %.3f bps\n",
              RMSE_liq, max(abs(res_all[ok_all]))))

  off60 <- eiopa_sw$rann[match(1:60, eiopa_sw$tenor)] * 100
  ok60  <- is.finite(off60)
  p_top <- ggplot() +
    geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.5) +
    geom_line(data = data.table(T = grid_f, val = spot_ann(grid_f, Qb, a_sw) * 100),
              aes(x = T, y = val, color = "SW ricostruito"), linewidth = 1.1) +
    geom_point(data = data.table(T = (1:60)[ok60], val = off60[ok60]),
               aes(x = T, y = val, color = "EIOPA ufficiale"), shape = 21, size = 1.6,
               fill = "white", stroke = 1.0) +
    annotate("text", x = 59, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
             hjust = 1, color = col_ufr, size = 3.2) +
    scale_color_manual(values = c("SW ricostruito" = col_spot, "EIOPA ufficiale" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = "SW ricostruito vs EIOPA ufficiale — dicembre 2025",
         subtitle = "Tasso spot annuo: le due curve coincidono a occhio nudo (vedi pannello inferiore)",
         x = NULL, y = "Tasso spot (%)", color = NULL) +
    theme_dispensa + theme(legend.position = "top")

  df_res <- data.table(T = mats_all[ok_all], Res = res_all[ok_all],
                       Zona = factor(ifelse(mats_all[ok_all] <= LLP, "Liquida", "Estrapolazione"),
                                     levels = c("Liquida", "Estrapolazione")))
  p_bot <- ggplot(df_res, aes(x = T, y = Res, fill = Zona)) +
    geom_col(width = 0.9) +
    geom_vline(xintercept = LLP + 0.5, color = "gray50", linetype = "dashed", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
    geom_hline(yintercept = c(-2, 2), color = "gray65", linetype = "dotted", linewidth = 0.35) +
    scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 60, 80)) +
    scale_y_continuous(limits = c(-ylim_res, ylim_res)) +
    labs(subtitle = sprintf("Scarto SW - EIOPA (bps, tenor 1-80a). Linee tratteggiate: +/-2 bps. RMSE ai nodi DLT = %.2f bps.", RMSE_liq),
         x = "Scadenza T (anni)", y = "Scarto (bps)", fill = NULL) +
    theme_dispensa + theme(legend.position = "top")

  pdf(file.path(dir_out, "fig_sw_vs_eiopa_dic.pdf"), width = 9, height = 7.5)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    2, 1, heights = grid::unit(c(2, 1), "null"))))
  print(p_top, vp = grid::viewport(layout.pos.row = 1))
  print(p_bot, vp = grid::viewport(layout.pos.row = 2))
  invisible(dev.off())
  message("  [OK] fig_sw_vs_eiopa_dic.pdf")
}

# --- tabella della curva SW ricostruita --------------------------------------
{
  tt_tab <- sort(unique(c(T_mkt, 25, 30, 40, 50, 60, 80)))
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva Smith--Wilson ricostruita, dicembre~2025: tasso spot e forward a ",
           "capitalizzazione continua e annua composta, ai 15 nodi DLT (zona liquida, $T\\le\\LLP$) ",
           "e ad alcuni tenor di estrapolazione. Serie completa (1--100 anni), insieme a quella ",
           "del bootstrap, in \\texttt{curva\\_ricostruita\\_dic2025.xlsx}.}"),
    "\\label{tab:curva-ricostruita-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\resizebox{\\textwidth}{!}{%", "\\begin{tabular}{rcccc}", "\\toprule",
    "$T$ (anni) & spot continuo (\\%) & spot annuo comp. (\\%) & forward continuo (\\%) & forward annuo comp. (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(tt_tab)) {
    v <- tt_tab[i]
    lines <- c(lines, sprintf("%s%d & %.4f & %.4f & %.4f & %.4f\\\\", tint(i), v,
                              spot_int(v, Qb, a_sw) * 100, spot_ann(v, Qb, a_sw) * 100,
                              fwd_int(v, Qb, a_sw) * 100,  fwd_ann(v, Qb, a_sw) * 100))
  }
  save_tab("tab_curva_ricostruita_dic",
           c(lines, "\\bottomrule", "\\end{tabular}}", "\\end{table}"))
}

# ------------------------------------------------------------------------------
# C.4  Sezione 7: confronto fra LE DUE RICOSTRUZIONI
# ------------------------------------------------------------------------------
# Qui sta il punto della dispensa 02c: entrambe le curve sono state costruite in
# questa stessa sessione, dagli stessi 15 par swap after-CRA e con lo stesso UFR.
# Lo scarto misurato isola quindi la SOLA differenza di metodologia.
{
  mats  <- 1:120
  r_new <- curve_finale$rann[match(mats, curve_finale$tenor)] * 100
  r_sw  <- spot_ann(mats, Qb, a_sw) * 100
  d_sw  <- (r_new - r_sw) * 100
  ok    <- is.finite(d_sw)

  sel60 <- mats <= 60
  df_c <- rbind(
    data.table(T = mats[sel60], val = r_new[sel60], Metodo = "Nuovo metodo (bootstrap)"),
    data.table(T = mats[sel60], val = r_sw[sel60],  Metodo = "Smith-Wilson"))
  p_c <- ggplot(df_c, aes(x = T, y = val, color = Metodo, linetype = Metodo)) +
    geom_vline(xintercept = fsp, color = "gray55", linetype = "dashed", linewidth = 0.5) +
    geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
    geom_line(linewidth = 1) +
    annotate("text", x = 58, y = UFR_ann * 100 + 0.04,
             label = sprintf("UFR = %.2f%%", UFR_ann * 100), hjust = 1, color = col_ufr, size = 3.2) +
    scale_color_manual(values = c("Nuovo metodo (bootstrap)" = col_spot, "Smith-Wilson" = col_fwd)) +
    scale_linetype_manual(values = c("Nuovo metodo (bootstrap)" = "solid", "Smith-Wilson" = "dashed")) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 50, 60)) +
    labs(title = "Nuovo metodo vs Smith-Wilson: curve spot EUR — dicembre 2025",
         subtitle = "Entrambe ricostruite qui, dagli stessi input: fino all'FSP interpolano gli stessi nodi, oltre divergono",
         x = "Scadenza t (anni)", y = "Tasso zero annuo r(t) (%)", color = NULL, linetype = NULL) +
    theme_dispensa
  save_fig("fig_sw_vs_new_rivisto", p_c)

  df_d <- data.table(T = mats[ok], delta = d_sw[ok])
  i_pk <- which.max(abs(df_d$delta)); T_pk <- df_d$T[i_pk]; d_pk <- df_d$delta[i_pk]
  p_ds <- ggplot(df_d, aes(x = T, y = delta)) +
    annotate("rect", xmin = fsp, xmax = max(df_d$T), ymin = -Inf, ymax = Inf,
             fill = "gray85", alpha = 0.30) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
    geom_vline(xintercept = fsp, color = "gray55", linetype = "dashed", linewidth = 0.5) +
    geom_line(color = col_spot, linewidth = 1) +
    geom_point(data = data.table(T = T_pk, delta = d_pk), aes(x = T, y = delta),
               color = col_obs, size = 2.2, inherit.aes = FALSE) +
    annotate("text", x = T_pk + 3, y = d_pk, hjust = 0, color = col_obs, size = 3.2,
             label = sprintf("max %+.1f bps (t = %d)", d_pk, T_pk)) +
    labs(title = "Scarto metodologico: nuovo metodo meno Smith-Wilson",
         subtitle = "Zona liquida: scarto trascurabile. Estrapolazione: il nuovo metodo, ancorato all'LLFR, produce una coda piu' bassa",
         x = "Scadenza t (anni)", y = "Delta zero rate (bps)") +
    theme_dispensa
  save_fig("fig_sw_delta_rivisto", p_ds)

  Tsel <- c(1, 5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 120)
  lines <- c(GEN, "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Confronto metodologico a parit\\`a di dati: la curva spot EUR di ",
           "dicembre~2025 ricostruita col nuovo metodo (bootstrap, Sez.~\\ref{sec:recon-bootstrap}) ",
           "e con Smith--Wilson (Sez.~\\ref{sec:ricostruzione-sw}), a partire dagli stessi 15 par ",
           "swap after-CRA. Lo scarto isola l'effetto della \\emph{sola} metodologia. La riga in ",
           "grassetto \\`e l'$\\FSP$.}"),
    "\\label{tab:sw-vs-new-rivisto}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & nuovo metodo (\\%) & Smith--Wilson (\\%) & $\\Delta$ (bps)\\\\", "\\midrule")
  for (i in seq_along(Tsel)) {
    j <- match(Tsel[i], mats)
    if (is.na(j) || !is.finite(d_sw[j])) next
    numstr <- if (Tsel[i] == fsp) sprintf("\\textbf{%d}", Tsel[i]) else as.character(Tsel[i])
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f\\\\",
                              tint(i), numstr, r_new[j], r_sw[j], d_sw[j]))
  }
  save_tab("tab_sw_vs_new_rivisto", c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}"))

  cat(sprintf("  [C] CONFRONTO bootstrap vs SW (entrambi ricostruiti):\n"))
  cat(sprintf("      zona liquida  max|delta| = %.3f bps\n", max(abs(d_sw[ok & mats <= fsp]))))
  cat(sprintf("      estrapolazione max|delta| = %.2f bps al tenor %d\n", abs(d_pk), T_pk))
}

# ------------------------------------------------------------------------------
# C.5  Excel: le due curve ricostruite, 1-100 anni
# ------------------------------------------------------------------------------
{
  xlsx_path <- file.path(dir_out, "curva_ricostruita_dic2025.xlsx")
  mm <- 1:100
  df_bt <- data.frame(
    Tenor_anni             = mm,
    Spot_continuo_pct      = round(curve_finale$rc[match(mm, curve_finale$tenor)] * 100, 6),
    Spot_annuo_comp_pct    = round(curve_finale$rann[match(mm, curve_finale$tenor)] * 100, 6),
    Forward_continuo_pct   = round(curve_finale$fwd_c[match(mm, curve_finale$tenor)] * 100, 6),
    Forward_annuo_comp_pct = round(curve_finale$fwd_ann[match(mm, curve_finale$tenor)] * 100, 6))
  df_sw <- data.frame(
    Tenor_anni             = mm,
    Spot_continuo_pct      = round(spot_int(mm, Qb, a_sw) * 100, 6),
    Spot_annuo_comp_pct    = round(spot_ann(mm, Qb, a_sw) * 100, 6),
    Forward_continuo_pct   = round(fwd_int (mm, Qb, a_sw) * 100, 6),
    Forward_annuo_comp_pct = round(fwd_ann (mm, Qb, a_sw) * 100, 6))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Bootstrap");   openxlsx::writeData(wb, "Bootstrap", df_bt)
  openxlsx::addWorksheet(wb, "SmithWilson"); openxlsx::writeData(wb, "SmithWilson", df_sw)
  openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
  message("  [OK] curva_ricostruita_dic2025.xlsx (fogli Bootstrap + SmithWilson)")
}

cat("\n=====================================================================\n")
cat("  FATTO. Output in", dir_out, "\n")
cat(sprintf("  %d figure PDF, %d tabelle .tex\n",
            length(list.files(dir_out, pattern = "\\.pdf$")),
            length(list.files(dir_out, pattern = "\\.tex$"))))
cat("=====================================================================\n\n")
