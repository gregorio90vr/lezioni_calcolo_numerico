# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Metodo SMITH-WILSON (su par swap €STR)
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Questo script riproduce tutti i risultati e le figure della dispensa
#  "Costruzione della Curva EIOPA Risk-Free Rate — Il metodo Smith-Wilson".
#
#  Riferimento: EIOPA-BoS-25-599 (RFR Technical Documentation, Dic 2025),
#               Sezione 9 (Extrapolation and interpolation), in cui Smith-Wilson
#               era il metodo UFFICIALE EIOPA.
#
#  NOTA STORICA: dal documento EIOPA-BoS-26-198 (Mag 2026) il metodo SW e' stato
#  SOSTITUITO da un metodo basato su bootstrap (constant forward) + estrapolazione
#  FSP/LLFR. Questo script (e la dispensa associata) studiano il metodo SW come
#  lezione di calcolo numerico e come ricostruzione metodologica.
#
#  FORMULAZIONE EIOPA (sez. 9.8-9.10):
#    - matrice dei flussi C (m x n),  d = exp(-omega*u),  Q = d_Delta C,  q = C'd
#    - cuore di Wilson  H(u,v) = a*min - exp(-a*max)*sinh(a*min)    (sez. 9.7)
#    - sistema SPD      (Q'HQ) b = p - q ,  con p = 1 (par swap)    (sez. 9.10)
#    - soluzione        b = (Q'HQ)^{-1}(p-q)  via CHOLESKY (Q'HQ e' SPD)
#    - curva            P(v) = e^{-omega v}(1 + H(v,u) Q b)         (sez. 9.10)
#                       y(v) = -log P(v)/v ,  R(v) = e^{y(v)} - 1   (sez. 9.5/9.12)
#                       f(v) = omega - G(v,u)Qb / (1 + H(v,u)Qb)    (sez. 9.12)
#
#  Nucleo numerico del corso:
#    - Sistema lineare SPD: fattorizzazione di CHOLESKY (confronto con LU)
#    - Numero di condizionamento di Q'HQ
#    - Ricerca di zeri per alpha: BISEZIONE vs NEWTON-RAPHSON   (criterio sez. 9.14)
#
#  Output: figure PDF in ../output/curva_eiopa_rfr_sw/
#
#  Struttura:
#    Sez. 0 — Setup e parametri EIOPA EUR
#    Sez. 1 — Dati input: par OIS €STR (ticker EESWE*) e CRA
#    Sez. 2 — Kernel di Wilson: visualizzazione e proprieta'
#    Sez. 3 — Calibrazione SW: matrici C,Q,H; sistema SPD Q'HQ b = p-q (Cholesky)
#    Sez. 4 — Determinazione di alpha: bisezione vs Newton (criterio sez. 9.14)
#    Sez. 5 — Curva completa: spot, forward, convergenza a UFR, sconto
#    Sez. 6 — Confronto spline cubiche vs Smith-Wilson
#    Sez. 7 — Analisi di sensitivita' (UFR, alpha)
#    Sez. 8 — Validazione multi-data EESWE: ricostruzione vs curve ufficiali EIOPA
#    Sez. 9 — Validazione EUSA (IRS EURIBOR): conferma diagnostica dell'input EIOPA
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

# Cartella output grafici (separata da quella del metodo nuovo)
dir_out <- file.path(dirname(getwd()), "output", "curva_eiopa_rfr_sw")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

# Tema grafico comune
theme_dispensa <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, color = "gray30"),
    legend.position  = "bottom"
  )

# Colori
col_spot   <- "#185FA5"   # blu scuro — tasso spot
col_fwd    <- "#993C1D"   # rosso mattone — forward
col_ufr    <- "#7060CC"   # viola — UFR
col_spline <- "#2ca02c"   # verde — spline
col_nodi   <- "black"     # nodi di mercato
col_nr     <- "#185FA5"   # Newton-Raphson
col_bis    <- "#E07020"   # Bisezione

# Helper: salva figura PDF
save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

# Helper: legge il foglio RFR_spot_no_VA da uno zip EIOPA e back-calcola i par rate
# lordi (before CRA) per le scadenze T_mkt usando la formula:
#   P(j) = (1 + R_j)^{-j},   par_T = (1 - P(T)) / sum_{j=1}^{T} P(j) + CRA
# Restituisce lista(par_gross, par_after_cra, CRA, alpha, UFR, LLP) o NULL.
par_from_zip <- function(zpath) {
  if (!have_openxlsx || !file.exists(zpath)) return(NULL)
  tryCatch({
    inner <- utils::unzip(zpath, list = TRUE)$Name
    ts <- grep("Term_Structures", inner, value = TRUE, ignore.case = TRUE)[1]
    if (is.na(ts)) return(NULL)
    utils::unzip(zpath, files = ts, exdir = tempdir(), overwrite = TRUE)
    raw   <- openxlsx::read.xlsx(file.path(tempdir(), ts),
                                 sheet = "RFR_spot_no_VA", colNames = FALSE,
                                 skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    lab   <- raw[[2]]; val <- suppressWarnings(as.numeric(raw[[3]]))
    getp  <- function(name) as.numeric(val[which(lab == name)[1]])
    CRA_i <- getp("CRA") / 1e4
    mlab  <- suppressWarnings(as.numeric(lab))
    sel   <- which(!is.na(mlab) & mlab >= 1 & mlab <= LLP)
    spot_j <- val[sel]
    if (length(spot_j) < LLP || any(is.na(spot_j))) return(NULL)
    Pj <- (1 + spot_j)^(-(1:LLP))
    pars_ac <- sapply(T_mkt, function(T) (1 - Pj[T]) / sum(Pj[seq_len(T)]))
    list(par_gross     = pars_ac + CRA_i,
         par_after_cra = pars_ac,
         CRA   = CRA_i,
         alpha = getp("alpha"),
         UFR   = getp("UFR") / 100,
         LLP   = as.integer(getp("LLP")))
  }, error = function(e) NULL)
}

cat("\n====================================================================\n")
cat("  CURVA EIOPA EUR — Smith-Wilson su par swap (EIOPA-BoS-25-599)\n")
cat("====================================================================\n\n")

# ==============================================================================
# PARAMETRI EIOPA EUR (sez. 9.2, 9.3, 9.4; Annex E)
# ==============================================================================

UFR_ann <- 0.0330                 # UFR annuo composto (EUR), sez. 9.3 / Annex E
omega   <- log(1 + UFR_ann)        # intensita' UFR  omega = log(1+UFR) ~ 3.2466%
LLP     <- 20                      # Last Liquid Point EUR (anni), sez. 9.2
CP      <- max(LLP + 40, 60)       # Convergence Point = 60 anni, sez. 9.4
CRA     <- 0.0010                  # Credit Risk Adjustment = 10 bps, sez. 7
tau     <- 1e-4                    # tolleranza di convergenza (1 bp), sez. 9.4/9.14

cat(sprintf("UFR annuo:        %.2f%%\n", UFR_ann * 100))
cat(sprintf("UFR intensita':   %.4f%%   (omega = log(1+UFR))\n", omega * 100))
cat(sprintf("LLP = %d anni,  CP = %d anni,  CRA = %d bps,  tau = %g (1 bp)\n\n",
            LLP, CP, CRA * 1e4, tau))

# ==============================================================================
# SEZ. 1 — DATI DI INPUT: par OIS €STR (ticker Bloomberg EESWE*)
# ==============================================================================
#
# ORIGINE DEI DATI
# ================
# Per l'EUR EIOPA usa tassi par degli OIS su €STR (sez. 5.3, Annex B di
# EIOPA-BoS-25-599). Il provider primario e' Refinitiv/LSEG; Bloomberg pubblica gli
# stessi strumenti con i ticker EESWE<tenor> Curncy (es. EESWE10 = 10Y €STR OIS).
#
# In questa dispensa usiamo i dati Bloomberg EESWE* da dati/EESWE.xlsx.
# La Sez. 8 (validazione) mostra che esiste uno scarto sistematico di ~25-30 bps
# tra questi tassi e quelli impliciti nella curva ufficiale EIOPA: lo stesso
# strumento quotato da provider diversi diverge (Bloomberg BGN vs Refinitiv fixing).
# La Sez. 8 include un'analisi diagnostica per distinguere le possibili cause
# (ticker, campo Bloomberg, orario di fixing, strumento sottostante).
#
# Scadenze DLT per EUR (anni): 1,2,3,4,5,6,7,8,10,12,15,20  (sez. 5.3, Annex B).
# Le scadenze 9,11,13,14,16-19 NON sono osservate: SW le ricostruisce in forma
# chiusa (nessun bootstrap; SW e' fittato direttamente ai par swap, sez. 9.15).
# ==============================================================================

cat("=== SEZ. 1: DATI INPUT (par OIS €STR, ticker Bloomberg EESWE*, 29/05/2026) ===\n")

T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20)   # scadenze DLT (anni)

# Fallback (valori Bloomberg EESWE* PX_LAST del 29/05/2026, da dati/EESWE.xlsx):
s_fallback <- c(2.39325, 2.43045, 2.43680, 2.46935, 2.50100, 2.54500,
                2.59700, 2.65030, 2.75150, 2.84600, 2.95800, 3.04400) / 100

# Lettura da dati/EESWE.xlsx (se disponibile), altrimenti fallback.
read_eswe <- function() {
  f <- file.path(dirname(getwd()), "dati", "EESWE.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 2, detectDates = TRUE)
    dcol  <- df[[1]]
    dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    idx <- which(format(dates, "%Y-%m-%d") == "2026-05-29")
    if (length(idx) == 0) idx <- nrow(df)
    vals <- as.numeric(df[idx[1], -1]); vals <- vals[!is.na(vals)]
    if (length(vals) != length(T_mkt)) return(NULL)
    vals / 100
  }, error = function(e) NULL)
}

s_mkt <- read_eswe()
if (is.null(s_mkt)) {
  s_mkt <- s_fallback
  cat("  (uso valori di fallback hardcoded per il 29/05/2026)\n")
} else {
  cat("  (letti da dati/EESWE.xlsx, data 29/05/2026)\n")
}

# After-CRA (sez. 7: CRA = 10 bps per EUR; sottratto PRIMA della calibrazione SW)
r_mkt <- s_mkt - CRA
N <- length(T_mkt)

cat(sprintf("\n  CRA EUR = %d bps (sez. 7.3 di EIOPA-BoS-25-599)\n", CRA * 1e4))
cat("\n  Scadenza   EESWE(%)   After-CRA(%)\n")
cat("  ----------------------------------------\n")
for (i in seq_along(T_mkt))
  cat(sprintf("  %4d Y     %7.4f      %7.4f\n", T_mkt[i], s_mkt[i]*100, r_mkt[i]*100))
cat("\n")

# --- Grafico fig01: par OIS e after-CRA ---
df_input <- data.frame(
  Scadenza = rep(T_mkt, 2),
  Tasso    = c(s_mkt * 100, r_mkt * 100),
  Tipo     = rep(c("OIS par €STR - EESWE* (lordo)", "After-CRA (input SW)"), each = N)
)
p1 <- ggplot(df_input, aes(x = Scadenza, y = Tasso, color = Tipo, shape = Tipo)) +
  geom_line(linewidth = 1) + geom_point(size = 2.5) +
  scale_color_manual(values = c("OIS par €STR - EESWE* (lordo)" = col_spot,
                                "After-CRA (input SW)" = col_fwd)) +
  labs(title = "Tassi OIS €STR par — EUR 29/05/2026 (Bloomberg EESWE*, PX_LAST)",
       subtitle = sprintf("CRA = %d bps sottratto prima della calibrazione (sez. 7 EIOPA-BoS-25-599)",
                          CRA * 1e4),
       x = "Scadenza (anni)", y = "Tasso (%)", color = NULL, shape = NULL) +
  theme_dispensa + scale_x_continuous(breaks = T_mkt)
save_fig("fig01_input_par_estr", p1)


# ==============================================================================
# SEZ. 2 — KERNEL DI WILSON: cuore H, funzione W e proprieta'
# ==============================================================================
#
# Cuore di Wilson (sez. 9.7.1):
#    H(u,v) = a*min(u,v) - exp(-a*max(u,v)) * sinh(a*min(u,v))
# Funzione di Wilson (dipende anche da omega):
#    W(u,v) = exp(-omega*(u+v)) * H(u,v)
# Derivata dH/dv (sez. 9.7.4), usata per il forward:
#    G(u,v) = dH(u,v)/dv = { a - a*exp(-a u) cosh(a v)   se v <= u
#                          { a*exp(-a v) sinh(a u)        se v >= u
# ==============================================================================

cat("=== SEZ. 2: KERNEL DI WILSON ===\n")

H_heart <- function(u, v, a) {
  m <- pmin(u, v); M <- pmax(u, v)
  a * m - exp(-a * M) * sinh(a * m)
}
W_fun <- function(u, v, a, om = omega) exp(-om * (u + v)) * H_heart(u, v, a)

# dH(u,v)/dv  (derivata rispetto al PRIMO argomento quando lo si usa come f(v,u_j))
G_heart <- function(v, u, a) {
  ifelse(v <= u,
         a - a * exp(-a * u) * cosh(a * v),
         a * exp(-a * v) * sinh(a * u))
}

alpha_plot <- 0.128
t_grid <- seq(0.01, 80, length.out = 600)
u_nodi <- c(1, 5, 10, 20)

df_kernel <- do.call(rbind, lapply(u_nodi, function(uj)
  data.frame(t = t_grid, W = W_fun(t_grid, uj, alpha_plot),
             u = paste0("u = ", uj, " anni"))))
p2a <- ggplot(df_kernel, aes(x = t, y = W, color = u)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = LLP, linetype = "dashed", color = "gray70") +
  annotate("text", x = LLP + 1.5, y = max(df_kernel$W) * 0.9, label = "LLP",
           color = "gray50", size = 3.5) +
  labs(title = expression(paste("Funzione di Wilson ", W(t, u[j]),
                                " = ", e^{-omega(t+u)}, H(t, u[j]), "  (sez. 9.7)")),
       subtitle = bquote(alpha == .(alpha_plot) ~ ", " ~ omega == .(round(omega, 5))),
       x = "t (anni)", y = expression(W(t, u[j])), color = "Nodo") +
  theme_dispensa
save_fig("fig02a_kernel_wilson", p2a)

alpha_vals <- c(0.05, 0.10, 0.15, 0.30, 0.50)
df_alpha_eff <- do.call(rbind, lapply(alpha_vals, function(a)
  data.frame(t = t_grid, W = W_fun(t_grid, 10, a),
             alpha = sprintf("alpha = %.2f", a))))
p2b <- ggplot(df_alpha_eff, aes(x = t, y = W, color = alpha)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  labs(title = expression(paste("Effetto di ", alpha, " sul kernel (nodo ", u == 10, " anni)")),
       subtitle = "Alpha piccolo -> kernel piu' ampio -> convergenza a UFR piu' lenta",
       x = "t (anni)", y = expression(W(t, 10)), color = NULL) +
  theme_dispensa
save_fig("fig02b_kernel_alpha_effetto", p2b)

# Matrice di Gram del kernel  W_ij = W(u_i,u_j)  sui nodi DLT  (simmetrica def. pos.)
W_matrix <- outer(T_mkt, T_mkt, function(a, b) W_fun(a, b, alpha_plot))
df_Wmat <- melt(W_matrix); names(df_Wmat) <- c("i", "j", "W")
df_Wmat$i_lab <- factor(T_mkt[df_Wmat$i], levels = T_mkt)
df_Wmat$j_lab <- factor(T_mkt[df_Wmat$j], levels = rev(T_mkt))
p2c <- ggplot(df_Wmat, aes(x = i_lab, y = j_lab, fill = W)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0) +
  labs(title = expression(paste("Matrice di Gram ", bold(W) == group("[", W(u[i], u[j]), "]"),
                                " — simmetrica def. positiva (sez. 9.9)")),
       subtitle = bquote(alpha == .(alpha_plot) ~ ", dimensione " ~ .(N) %*% .(N)),
       x = expression(u[j] ~ " (anni)"), y = expression(u[i] ~ " (anni)"),
       fill = expression(W(u[i], u[j]))) +
  theme_dispensa + theme(aspect.ratio = 1)
save_fig("fig02c_matrice_kernel_W", p2c, w = 7, h = 6)


# ==============================================================================
# SEZ. 3 — CALIBRAZIONE SMITH-WILSON: matrici C, Q, H; sistema SPD Q'HQ b = p-q
# ==============================================================================
#
# Strumenti: n = 12 par swap di scadenza T_k. Date di pagamento (annuali): 1..LLP,
# quindi m = LLP = 20. La matrice dei flussi C (m x n) e' (sez. 9.15, Table 9):
#    C[j,k] = r_k        per  u_j < T_k
#    C[T_k,k] = 1 + r_k
#    C[j,k] = 0          per  u_j > T_k
# Prezzi di mercato p = 1 (i par swap valgono alla pari).
# d = exp(-omega*u);  Q = diag(d) C;  q = C' d.
# Sistema (sez. 9.10):   (Q'HQ) b = p - q ,   b = (Q'HQ)^{-1}(p-q).
# Q'HQ e' SIMMETRICA DEFINITA POSITIVA -> fattorizzazione di Cholesky.
# ==============================================================================

cat("=== SEZ. 3: CALIBRAZIONE SW (sistema SPD Q'HQ b = p-q) ===\n")

u_pay <- seq_len(LLP)     # date di pagamento annuali 1..20  (m = 20)
m <- length(u_pay)

build_C <- function(maturities, rates) {
  C <- matrix(0, m, N)
  for (k in seq_len(N)) {
    Tk <- maturities[k]; rk <- rates[k]
    if (Tk > 1) C[1:(Tk - 1), k] <- rk
    C[Tk, k] <- 1 + rk
  }
  C
}

# Costruisce gli oggetti del sistema per un dato alpha
sw_system <- function(maturities, rates, a) {
  C <- build_C(maturities, rates)
  d <- exp(-omega * u_pay)
  Q <- C * d                        # diag(d) %*% C  (broadcast per riga)
  q <- as.numeric(t(C) %*% d)       # = Q' 1
  Hm <- outer(u_pay, u_pay, H_heart, a = a)   # cuore di Wilson (m x m), SPD
  QHQ <- t(Q) %*% Hm %*% Q          # n x n, simmetrica def. positiva
  list(C = C, d = d, Q = Q, q = q, H = Hm, QHQ = QHQ, p = rep(1, N))
}

# Calibrazione: risolve il sistema SPD con CHOLESKY (confronto con LU)
sw_calibrate <- function(maturities, rates, a) {
  sys <- sw_system(maturities, rates, a)
  rhs <- sys$p - sys$q
  R  <- chol(sys$QHQ)               # Cholesky: QHQ = R'R  (R triangolare sup.)
  b  <- backsolve(R, forwardsolve(t(R), rhs))
  Qb <- as.numeric(sys$Q %*% b)     # coefficienti "estesi" sui nodi di pagamento
  c(sys, list(b = b, Qb = Qb))
}

# Funzioni curva (sez. 9.10 / 9.12), valutate dai coefficienti Qb sui nodi u_pay
sw_P <- function(v, Qb, a) {
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  exp(-omega * v) * (1 + Hv)
}
sw_spot_int <- function(v, Qb, a) -log(sw_P(v, Qb, a)) / v     # intensita' spot y(v)
sw_spot_ann <- function(v, Qb, a) exp(sw_spot_int(v, Qb, a)) - 1   # tasso spot annuo
sw_fwd_int  <- function(v, Qb, a) {                            # forward intensita'
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  Gv <- sapply(v, function(x) sum(G_heart(x, u_pay, a) * Qb))
  omega - Gv / (1 + Hv)
}

# --- Calibrazione con alpha illustrativo ---
alpha_ill <- 0.128
cal <- sw_calibrate(T_mkt, r_mkt, alpha_ill)

# Confronto Cholesky vs LU (solve = LU con pivoting, LAPACK dgesv)
b_lu <- solve(cal$QHQ, cal$p - cal$q)
ev   <- eigen(cal$QHQ, symmetric = TRUE, only.values = TRUE)$values
cat(sprintf("  Sistema n=%d. Q'HQ simmetrica? %s ; def. positiva? %s (lambda_min=%.3e)\n",
            N, isTRUE(all.equal(cal$QHQ, t(cal$QHQ))), all(ev > 0), min(ev)))
cat(sprintf("  Cond_2(Q'HQ) = %.2f\n", max(ev) / min(ev)))
cat(sprintf("  ||b_chol - b_LU||_inf = %.2e  (Cholesky vs LU)\n", max(abs(cal$b - b_lu))))

# --- Verifica: i fattori di sconto replicano i par swap? ---
cat("\n  Verifica calibrazione (valore par swap = 1):\n")
max_err <- 0
for (i in seq_along(T_mkt)) {
  Ti <- T_mkt[i]; ri <- r_mkt[i]
  Pj  <- sw_P(seq_len(Ti), cal$Qb, alpha_ill)
  val <- ri * sum(Pj[seq_len(Ti)]) + Pj[Ti]
  max_err <- max(max_err, abs(val - 1))
  cat(sprintf("    T=%2d: valore = %.12f  (errore = %.2e)\n", Ti, val, abs(val - 1)))
}
cat(sprintf("  -> errore massimo di re-pricing = %.2e\n\n", max_err))

# --- fig03a: heatmap della matrice del sistema Q'HQ (SPD) ---
df_A <- melt(cal$QHQ); names(df_A) <- c("i", "j", "val")
df_A$i_lab <- factor(T_mkt[df_A$i], levels = T_mkt)
df_A$j_lab <- factor(T_mkt[df_A$j], levels = rev(T_mkt))
p3a <- ggplot(df_A, aes(x = i_lab, y = j_lab, fill = val)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0) +
  labs(title = expression(paste("Matrice del sistema ", bold(Q)*minute*bold(H)*bold(Q),
                                " — simmetrica def. positiva (sez. 9.10)")),
       subtitle = bquote("Cholesky applicabile; " ~ kappa[2] == .(sprintf("%.1f", max(ev)/min(ev)))),
       x = expression(T[j] ~ " (anni)"), y = expression(T[i] ~ " (anni)"),
       fill = expression((Q*minute*H*Q)[ij])) +
  theme_dispensa + theme(aspect.ratio = 1)
save_fig("fig03a_matrice_QHQ", p3a, w = 7, h = 6)

# --- fig03b: coefficienti b ---
df_b <- data.frame(scadenza = T_mkt, b = cal$b)
p3b <- ggplot(df_b, aes(x = scadenza, y = b)) +
  geom_col(fill = col_spot, alpha = 0.7, width = 0.7) +
  geom_hline(yintercept = 0, linewidth = 0.4) +
  labs(title = expression(paste("Coefficienti ", b[k], " — soluzione del sistema ",
                                bold(Q)*minute*bold(H)*bold(Q), bold(b) == bold(p) - bold(q))),
       subtitle = bquote(alpha == .(alpha_ill) ~ ", " ~ n == .(N) ~ " strumenti"),
       x = "Strumento (scadenza in anni)", y = expression(b[k])) +
  scale_x_continuous(breaks = T_mkt) + theme_dispensa
save_fig("fig03b_coefficienti_b", p3b)

# --- fig03c: condizionamento di Q'HQ in funzione di alpha ---
alpha_grid <- seq(0.05, 0.50, by = 0.005)
cond_vals <- sapply(alpha_grid, function(a) {
  sys <- sw_system(T_mkt, r_mkt, a)
  e <- eigen(sys$QHQ, symmetric = TRUE, only.values = TRUE)$values
  max(e) / min(e)
})
df_cond <- data.frame(alpha = alpha_grid, kappa = cond_vals)
p3c <- ggplot(df_cond, aes(x = alpha, y = kappa)) +
  geom_line(linewidth = 1.2, color = col_spot) +
  scale_y_log10() +
  labs(title = expression(paste("Numero di condizionamento ", kappa[2](bold(Q)*minute*bold(H)*bold(Q)),
                                " vs ", alpha)),
       subtitle = "Alpha piccolo -> colonne quasi proporzionali -> malcondizionamento (scala log)",
       x = expression(alpha), y = expression(kappa[2])) +
  theme_dispensa
save_fig("fig03c_condizionamento_vs_alpha", p3c)


# ==============================================================================
# SEZ. 4 — DETERMINAZIONE DI alpha: bisezione vs Newton (criterio sez. 9.14)
# ==============================================================================
#
# Criterio EIOPA (sez. 9.14.4-9.14.5): trovare il PIU' PICCOLO alpha >= a_min tale
# che il gap di convergenza al Convergence Point T = max(LLP+40,60) soddisfi
#    g(alpha) = | f(T) - omega | <= tau   (tau = 1 bp),  con a_min = 0.05.
# g(alpha) e' DECRESCENTE in alpha. Strategia (sez. 9.14.5):
#    1) risolvere numericamente g(alpha) = tau  ->  radice "non vincolata" alpha_unc;
#    2) applicare il vincolo:  alpha* = max(a_min, alpha_unc).
# Ogni valutazione di g richiede di ricalibrare il sistema (b dipende da alpha).
# ==============================================================================

cat("=== SEZ. 4: DETERMINAZIONE DI alpha (sez. 9.14) ===\n")

a_min <- 0.05                            # limite inferiore regolamentare (sez. 9.14.4)

g_gap <- function(a) {                   # gap (con segno) f(T) - omega
  Qb <- sw_calibrate(T_mkt, r_mkt, a)$Qb
  sw_fwd_int(CP, Qb, a) - omega
}
h_root <- function(a) abs(g_gap(a)) - tau   # zero quando |f(T)-omega| = tau

# --- Bisezione su h_root: risolve g(alpha) = tau nel bracket [lo,hi] ---
bisez_alpha <- function(lo = 0.02, hi = 0.30, eps = 1e-7, nmax = 60) {
  flo <- h_root(lo); fhi <- h_root(hi)
  if (flo * fhi > 0) stop("bisezione: nessun cambio di segno nel bracket")
  tr <- data.frame(iter = integer(), a = numeric(), h = numeric(), width = numeric())
  for (k in seq_len(nmax)) {
    mid <- 0.5 * (lo + hi); hm <- h_root(mid)
    tr <- rbind(tr, data.frame(iter = k, a = mid, h = hm, width = hi - lo))
    if (sign(hm) == sign(flo)) { lo <- mid; flo <- hm } else { hi <- mid }
    if ((hi - lo) < eps) break
  }
  list(alpha = 0.5 * (lo + hi), trace = tr, n_iter = nrow(tr))
}

# --- Newton-Raphson su h_root (derivata numerica centrata, alpha clampato) ---
newton_alpha <- function(a0 = 0.10, tol = 1e-12, nmax = 50, hh = 1e-5) {
  a <- a0
  tr <- data.frame(iter = 0, a = a0, h = h_root(a0))
  for (k in seq_len(nmax)) {
    hv <- h_root(a)
    if (abs(hv) < tol) break
    hp <- (h_root(a + hh) - h_root(a - hh)) / (2 * hh)
    a  <- min(max(a - hv / hp, 0.02), 1.0)        # clamp nel dominio PD
    tr <- rbind(tr, data.frame(iter = k, a = a, h = h_root(a)))
  }
  list(alpha = a, trace = tr, n_iter = nrow(tr) - 1)
}

bis <- bisez_alpha()
nr  <- newton_alpha(a0 = 0.10)
alpha_unc  <- bis$alpha                  # radice non vincolata di g(alpha)=tau
alpha_star <- max(a_min, alpha_unc)      # vincolo regolamentare alpha >= 0.05
cat(sprintf("  Bisezione : alpha_unc = %.6f  in %d iter\n", bis$alpha, bis$n_iter))
cat(sprintf("  Newton    : alpha_unc = %.6f  in %d iter\n", nr$alpha, nr$n_iter))
cat(sprintf("  |alpha_bis - alpha_NR| = %.2e\n", abs(bis$alpha - nr$alpha)))
cat(sprintf("  g(0.05) = %.4f bps <= 1 bp  =>  il vincolo alpha >= 0.05 e' attivo\n", abs(g_gap(a_min))*1e4))
cat(sprintf("  ==> alpha* = max(0.05, %.4f) = %.4f\n\n", alpha_unc, alpha_star))

# --- fig04b: funzione g(alpha) in bps con soglia tau, radice e floor ---
alpha_g_grid <- seq(0.02, 0.50, length.out = 90)
df_g <- data.frame(alpha = alpha_g_grid,
                   g = sapply(alpha_g_grid, function(a) abs(g_gap(a))) * 1e4)  # bps
p4b <- ggplot(df_g, aes(x = alpha, y = g)) +
  geom_line(linewidth = 1.2, color = col_fwd) +
  geom_hline(yintercept = tau * 1e4, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = alpha_unc,  linetype = "dotdash", color = col_fwd) +
  geom_vline(xintercept = a_min,      linetype = "dotted",  color = col_ufr) +
  annotate("text", x = alpha_unc + 0.012, y = max(df_g$g) * 0.55,
           label = bquote(alpha[unc] == .(sprintf("%.4f", alpha_unc))),
           color = col_fwd, size = 3.4, hjust = 0) +
  annotate("text", x = a_min + 0.012, y = max(df_g$g) * 0.85,
           label = bquote(alpha^"*" == 0.05 ~ "(floor)"),
           color = col_ufr, size = 3.4, hjust = 0) +
  annotate("text", x = 0.40, y = tau*1e4 + max(df_g$g)*0.05,
           label = "tau = 1 bp", color = "gray30", size = 3.2) +
  labs(title = expression(paste("Gap di convergenza ", g(alpha) == abs(f(T) - omega),
                                "  (criterio sez. 9.14)")),
       subtitle = sprintf("T = CP = %d anni. g(alpha)=tau in alpha_unc; il floor 0.05 e' attivo => alpha* = 0.05",
                          CP),
       x = expression(alpha), y = expression(g(alpha) ~ " (bps)")) +
  theme_dispensa
save_fig("fig04b_funzione_g_alpha", p4b)

# --- fig04a: convergenza bisezione vs Newton verso la radice di g(alpha)=tau ---
err_bis <- abs(bis$trace$a - alpha_unc)
err_nr  <- abs(nr$trace$a  - alpha_unc)
df_conv <- rbind(
  data.frame(iter = bis$trace$iter, err = err_bis, Metodo = "Bisezione"),
  data.frame(iter = nr$trace$iter,  err = err_nr,  Metodo = "Newton-Raphson")
)
df_conv <- df_conv[df_conv$err > 0, ]
p4a <- ggplot(df_conv, aes(x = iter, y = err, color = Metodo, shape = Metodo)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  scale_y_log10() +
  scale_color_manual(values = c("Bisezione" = col_bis, "Newton-Raphson" = col_nr)) +
  labs(title = "Convergenza per la radice di g(alpha)=tau: bisezione (lineare) vs Newton (quadratica)",
       subtitle = sprintf("Bisezione: %d iter; Newton: %d iter (radice non vincolata alpha_unc)",
                          bis$n_iter, nr$n_iter),
       x = "Iterazione", y = expression(group("|", alpha[k] - alpha^"*", "|")),
       color = NULL, shape = NULL) +
  theme_dispensa
save_fig("fig04a_bisezione_convergenza", p4a)


# ==============================================================================
# SEZ. 5 — CURVA COMPLETA: spot, forward, convergenza, fattori di sconto
# ==============================================================================

cat("=== SEZ. 5: CURVA COMPLETA (alpha* = ", sprintf("%.6f", alpha_star), ") ===\n")

cal_star <- sw_calibrate(T_mkt, r_mkt, alpha_star)
Qb_star  <- cal_star$Qb

T_full <- seq(0.5, 150, by = 0.5)
P_full <- sw_P(T_full, Qb_star, alpha_star)
R_spot <- (exp(-log(P_full)/T_full) - 1) * 100                      # spot annuo (%)
f_fwd  <- (exp(sw_fwd_int(T_full, Qb_star, alpha_star)) - 1) * 100   # forward annuo (%)

cat("\n    T(anni)   Spot(%)   Forward(%)\n")
cat("    --------------------------------\n")
for (T in c(1, 2, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150)) {
  idx <- which.min(abs(T_full - T))
  cat(sprintf("    %6.0f  %8.4f   %8.4f\n", T, R_spot[idx], f_fwd[idx]))
}
cat("\n")

spot_nodi <- data.frame(T = T_mkt,
                        Tasso = sw_spot_ann(T_mkt, Qb_star, alpha_star) * 100)

# --- fig05a: curva spot e forward ---
sel <- T_full <= 100
df_curve <- rbind(
  data.frame(T = T_full[sel], Tasso = R_spot[sel], Tipo = "Spot r(0,T)"),
  data.frame(T = T_full[sel], Tasso = f_fwd[sel],  Tipo = "Forward f(0,T)")
)
p5a <- ggplot(df_curve, aes(x = T, y = Tasso, color = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_vline(xintercept = CP, color = "gray60", linetype = "dotted", linewidth = 0.5) +
  geom_point(data = spot_nodi, aes(x = T, y = Tasso), color = col_nodi, size = 2.2,
             shape = 16, inherit.aes = FALSE) +
  annotate("text", x = LLP + 1.5, y = min(df_curve$Tasso) + 0.05, label = "LLP",
           color = "gray40", size = 3) +
  annotate("text", x = CP + 1.5, y = min(df_curve$Tasso) + 0.05, label = "CP",
           color = "gray40", size = 3) +
  annotate("text", x = 85, y = UFR_ann * 100 + 0.06,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3.2) +
  scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  scale_linetype_manual(values = c("Spot r(0,T)" = "solid", "Forward f(0,T)" = "dashed")) +
  labs(title = "Curva EIOPA EUR — Smith-Wilson su par swap €STR (29/05/2026)",
       subtitle = sprintf("alpha* = %.4f, LLP = %d anni, CP = %d anni, UFR = %.2f%%",
                          alpha_star, LLP, CP, UFR_ann * 100),
       x = "Scadenza T (anni)", y = "Tasso (%)", color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig05a_curva_spot_forward", p5a)

# --- fig05b: convergenza |f - UFR| ---
sel2 <- T_full >= LLP
df_conv2 <- data.frame(T = T_full[sel2],
                       dist = abs(sw_fwd_int(T_full[sel2], Qb_star, alpha_star) - omega) * 1e4)
p5b <- ggplot(df_conv2, aes(x = T, y = dist)) +
  geom_line(linewidth = 1, color = col_fwd) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  geom_vline(xintercept = CP, linetype = "dotted", color = "gray60") +
  annotate("text", x = CP + 2, y = 5, label = "CP = 60", color = "gray40", size = 3) +
  annotate("text", x = 120, y = 1.5, label = "1 bp", color = "red", size = 3) +
  scale_y_log10() +
  labs(title = expression(paste("|f(0,T) - ", omega, "| — convergenza all'intensita' UFR")),
       subtitle = "Scala log. Al CP il forward e' entro 1 bp dall'UFR (criterio sez. 9.14).",
       x = "Scadenza T (anni)", y = "|f(0,T) - UFR| (bps)") +
  theme_dispensa
save_fig("fig05b_convergenza_ufr", p5b)

# --- fig05c: fattori di sconto ---
df_disc <- data.frame(T = T_full[sel], P = P_full[sel])
p5c <- ggplot(df_disc, aes(x = T, y = P)) +
  geom_line(linewidth = 1.1, color = col_spot) +
  geom_point(data = data.frame(T = T_mkt, P = sw_P(T_mkt, Qb_star, alpha_star)),
             aes(x = T, y = P), color = col_nodi, size = 2, shape = 16) +
  geom_line(data = data.frame(T = T_full[sel], Pa = exp(-omega * T_full[sel])),
            aes(x = T, y = Pa), linetype = "dotted", color = col_ufr, linewidth = 0.7) +
  labs(title = "Fattori di sconto P(0,T) — Smith-Wilson",
       subtitle = expression(paste("Tratto puntinato: ", e^{-omega * T}, " (limite asintotico)")),
       x = "Scadenza T (anni)", y = "P(0,T)") +
  theme_dispensa
save_fig("fig05c_fattori_sconto", p5c)


# ==============================================================================
# SEZ. 6 — CONFRONTO SPLINE CUBICA NATURALE vs SMITH-WILSON
# ==============================================================================

cat("=== SEZ. 6: CONFRONTO SPLINE vs SW ===\n")

spot_at_nodes <- sw_spot_ann(T_mkt, Qb_star, alpha_star) * 100
spline_fit <- splinefun(T_mkt, spot_at_nodes, method = "natural")
T_spline <- seq(1, 60, by = 0.25)
df_cmp <- rbind(
  data.frame(T = T_spline, Tasso = spline_fit(T_spline), Metodo = "Spline cubica naturale"),
  data.frame(T = T_spline, Tasso = sw_spot_ann(T_spline, Qb_star, alpha_star) * 100,
             Metodo = "Smith-Wilson (EIOPA)")
)
p6 <- ggplot(df_cmp, aes(x = T, y = Tasso, color = Metodo, linetype = Metodo)) +
  annotate("rect", xmin = LLP, xmax = 60, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.35) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted") +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = data.frame(T = T_mkt, Tasso = spot_at_nodes),
             aes(x = T, y = Tasso), color = col_nodi, size = 2, shape = 16, inherit.aes = FALSE) +
  annotate("text", x = 50, y = UFR_ann * 100 + 0.08,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3) +
  scale_color_manual(values = c("Spline cubica naturale" = col_spline,
                                "Smith-Wilson (EIOPA)" = col_spot)) +
  scale_linetype_manual(values = c("Spline cubica naturale" = "dashed",
                                   "Smith-Wilson (EIOPA)" = "solid")) +
  labs(title = "Confronto interpolazione/estrapolazione: spline cubica vs Smith-Wilson",
       subtitle = "Oltre il LLP=20a la spline estrapola senza vincolo; SW converge all'UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig06_confronto_spline_sw", p6)


# ==============================================================================
# SEZ. 7 — ANALISI DI SENSITIVITA' (UFR, alpha)
# ==============================================================================

cat("=== SEZ. 7: SENSITIVITA' ===\n")

# --- 7a: sensitivita' all'UFR (con relativo alpha* ricalcolato) ---
df_su <- do.call(rbind, lapply(c(0.0315, 0.0330, 0.0345), function(ufr_a) {
  om <- log(1 + ufr_a)
  # ricalibro con questa UFR: ridefinisco omega localmente via funzioni dedicate
  H_heart_l <- H_heart
  sys_loc <- function(a) {
    C <- build_C(T_mkt, r_mkt); d <- exp(-om * u_pay); Q <- C * d
    q <- as.numeric(t(C) %*% d); Hm <- outer(u_pay, u_pay, H_heart, a = a)
    list(Q = Q, q = q, QHQ = t(Q) %*% Hm %*% Q)
  }
  cal_loc <- function(a) { s <- sys_loc(a); R <- chol(s$QHQ)
    b <- backsolve(R, forwardsolve(t(R), rep(1, N) - s$q)); as.numeric(s$Q %*% b) }
  gap_loc <- function(a) { Qb <- cal_loc(a)
    Hv <- sapply(CP, function(x) sum(H_heart(x, u_pay, a) * Qb))
    Gv <- sapply(CP, function(x) sum(G_heart(x, u_pay, a) * Qb))
    abs((om - Gv/(1 + Hv)) - om) - tau }
  # bisezione locale
  lo <- 0.05; hi <- 1.0
  if (gap_loc(lo) <= 0) a_s <- lo else {
    flo <- gap_loc(lo)
    for (k in 1:60) { mid <- 0.5*(lo+hi); gm <- gap_loc(mid)
      if (sign(gm)==sign(flo)) { lo<-mid; flo<-gm } else hi<-mid
      if ((hi-lo)<1e-7) break }
    a_s <- 0.5*(lo+hi)
  }
  Qb <- cal_loc(a_s)
  Tp <- seq(1, 100, by = 0.5)
  Pv <- sapply(Tp, function(x) exp(-om*x) * (1 + sum(H_heart(x, u_pay, a_s) * Qb)))
  data.frame(T = Tp, Spot = (exp(-log(Pv)/Tp) - 1) * 100,
             UFR = sprintf("UFR = %.2f%%", ufr_a * 100))
}))
p7a <- ggplot(df_su, aes(x = T, y = Spot, color = UFR)) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  labs(title = "Sensitivita' della curva spot all'UFR",
       subtitle = "Le curve coincidono fino al LLP e divergono in estrapolazione verso il rispettivo UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL) +
  theme_dispensa
save_fig("fig07a_sensitivita_ufr", p7a)

# --- 7b: sensitivita' ad alpha (UFR fisso) ---
df_sa <- do.call(rbind, lapply(c(alpha_star - 0.03, alpha_star, alpha_star + 0.03), function(a) {
  Qb <- sw_calibrate(T_mkt, r_mkt, a)$Qb
  Tp <- seq(1, 100, by = 0.5)
  data.frame(T = Tp, Forward = (exp(sw_fwd_int(Tp, Qb, a)) - 1) * 100,
             Alpha = sprintf("alpha = %.3f", a))
}))
p7b <- ggplot(df_sa, aes(x = T, y = Forward, color = Alpha)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted") +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_vline(xintercept = CP, color = "gray60", linetype = "dotted", linewidth = 0.5) +
  labs(title = expression(paste("Sensitivita' del forward ad ", alpha, " (UFR fisso)")),
       subtitle = "Alpha piu' grande -> convergenza piu' rapida verso l'UFR",
       x = "Scadenza T (anni)", y = "Forward rate (%)", color = NULL) +
  theme_dispensa
save_fig("fig07b_sensitivita_alpha", p7b)

# ==============================================================================
# SEZ. 8 — VALIDAZIONE MULTI-DATA: ricostruzione SW vs curve UFFICIALI EIOPA
# ==============================================================================
#
# OBIETTIVO
# =========
# Ripetiamo l'intera pipeline SW (CRA -> calibrazione -> alpha) per tutti i
# fine-mese disponibili in dati/EESWE.xlsx e confrontiamo la curva ricostruita
# con quella UFFICIALE EIOPA dello stesso mese (dati/eiopa_zips/).
#
# INPUT: tassi Bloomberg EESWE* (€STR OIS, PX_LAST) da dati/EESWE.xlsx.
#
# DIAGNOSTICA: per capire lo scarto ~25-30 bps tra EESWE e curva ufficiale,
# back-calcoliamo i par rate impliciti nella curva ufficiale (formula inversa):
#   P(j) = (1+R_j)^{-j},  par_T_eiopa = (1-P(T))/sum P(j) + CRA
# e li confrontiamo con EESWE scadenza per scadenza. Lo scarto in bps mostra
# se il problema e' il ticker (strumento sbagliato), il provider (Bloomberg vs
# Refinitiv), o il campo (PX_LAST vs mid a orario diverso).
# Nota: per T=1 lo spot EIOPA = par_eiopa - CRA = s_1 - CRA esattamente
# (unico flusso a T=1), quindi  s_1_eiopa = spot_eiopa(1Y) + CRA.
#
# DOPPIA ALPHA:
#   (a) alpha* dal criterio sez. 9.14 (bisezione);
#   (b) alpha ufficiale letto dallo stesso zip EIOPA.
# ==============================================================================

cat("=== SEZ. 8: VALIDAZIONE MULTI-DATA (SW ricostruita vs ufficiale EIOPA) ===\n")

# --- 8.0 Lettore EESWE (tutte le date) per confronto secondario ---------------
read_eswe_all <- function() {
  f <- file.path(dirname(getwd()), "dati", "EESWE.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 2, detectDates = TRUE)
    dcol  <- df[[1]]
    dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    M <- as.matrix(df[, -1])
    storage.mode(M) <- "numeric"
    keep <- !is.na(dates) & rowSums(is.na(M)) == 0 & ncol(M) == length(T_mkt)
    data.frame(date = dates[keep], M[keep, , drop = FALSE] / 100,
               check.names = FALSE)
  }, error = function(e) NULL)
}

# --- 8.1 Parser della curva ufficiale EIOPA + back-calc par rate ---------------
# Legge il foglio RFR_spot_no_VA dello zip per anno-mese, ritorna:
#   list(par_gross, par_after_cra, CRA, alpha, UFR, LLP, zip, mat, spot)
read_eiopa_official <- function(date) {
  if (!have_openxlsx) return(NULL)
  zdir <- file.path(dirname(getwd()), "dati", "eiopa_zips")
  ym   <- format(date, "%Y%m")
  tryCatch({
    zf <- list.files(zdir, pattern = paste0("^EIOPA_RFR_", ym, "[0-9]{2}\\.zip$"),
                     full.names = TRUE)
    if (length(zf) == 0) {
      mname <- format(date, "%B")
      zf <- list.files(zdir, pattern = paste0("^_?", mname, ".*", format(date, "%Y"),
                                              ".*\\.zip$"), full.names = TRUE,
                       ignore.case = TRUE)
    }
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
    CRA_bps <- getp("CRA")                          # valore RAW in bps (es. 10)
    CRA_dec <- CRA_bps / 1e4                         # decimale (es. 0.001)
    mlab  <- suppressWarnings(as.numeric(lab))
    sel   <- which(!is.na(mlab) & mlab >= 1 & mlab <= 150)
    mat   <- mlab[sel]; spot <- suppressWarnings(as.numeric(val[sel]))
    ok    <- !is.na(mat) & !is.na(spot)
    mat_ok <- mat[ok]; spot_ok <- spot[ok]
    # back-calcolo par rate per le scadenze T_mkt (spot ordinati per maturity)
    ord    <- order(mat_ok)
    spot_s <- spot_ok[ord][seq_len(LLP)]             # spot 1..LLP ordinati
    Pj     <- (1 + spot_s)^(-(seq_len(LLP)))         # P(j) = (1+R_j)^{-j}
    pars_ac <- sapply(T_mkt, function(T) (1 - Pj[T]) / sum(Pj[seq_len(T)]))
    list(par_gross     = pars_ac + CRA_dec,
         par_after_cra = pars_ac,
         CRA   = CRA_bps,                             # salvato in BPS per retrocompatibilita'
         alpha = getp("alpha"),
         UFR   = getp("UFR") / 100,
         LLP   = as.integer(getp("LLP")),
         zip   = basename(zf),
         mat   = mat_ok, spot = spot_ok)
  }, error = function(e) NULL)
}

# --- 8.2 alpha* dal criterio per un vettore di tassi after-CRA ----------------
alpha_star_for <- function(rates) {
  gfun <- function(a) abs(sw_fwd_int(CP, sw_calibrate(T_mkt, rates, a)$Qb, a) - omega) - tau
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
  list(alpha_star = max(a_min, a_unc), alpha_unc = a_unc)
}

# --- 8.3 Loop sulle date EESWE (driver: dati/EESWE.xlsx) ---------------------
eswe_all <- read_eswe_all()

if (is.null(eswe_all)) {
  cat("  (EESWE.xlsx non leggibile: salto la validazione multi-data)\n\n")
} else {
  mats_cmp <- 1:150
  rec_list <- list(); res_list <- list(); tab_rows <- list()

  for (i in seq_len(nrow(eswe_all))) {
    d   <- eswe_all$date[i]
    s_i <- as.numeric(eswe_all[i, -1])              # par OIS Bloomberg EESWE* (decimali)
    off <- read_eiopa_official(d)
    if (is.null(off)) {
      cat(sprintf("  [%s] curva ufficiale non trovata, skip\n", format(d, "%Y-%m-%d")))
      next
    }

    CRA_i  <- if (is.finite(off$CRA)) off$CRA / 1e4 else CRA
    r_i    <- s_i - CRA_i                           # after-CRA (input SW)
    a_crit <- alpha_star_for(r_i)$alpha_star
    a_off  <- if (is.finite(off$alpha)) off$alpha else a_crit

    Qb_crit <- sw_calibrate(T_mkt, r_i, a_crit)$Qb
    Qb_off  <- sw_calibrate(T_mkt, r_i, a_off )$Qb
    sp_crit <- sw_spot_ann(mats_cmp, Qb_crit, a_crit) * 100
    sp_off  <- sw_spot_ann(mats_cmp, Qb_off , a_off ) * 100
    sp_uff  <- off$spot[match(mats_cmp, off$mat)] * 100
    dlab    <- format(d, "%b %Y")

    r_crit <- (sp_crit - sp_uff) * 100              # residui in bps
    r_off  <- (sp_off  - sp_uff) * 100

    rec_list[[length(rec_list) + 1]] <- rbind(
      data.frame(T = mats_cmp, Spot = sp_uff,  Serie = "Ufficiale EIOPA",             data = dlab),
      data.frame(T = mats_cmp, Spot = sp_crit, Serie = "EESWE (alpha-crit.)", data = dlab),
      data.frame(T = mats_cmp, Spot = sp_off,  Serie = "EESWE (alpha-uff.)",   data = dlab)
    )
    res_list[[length(res_list) + 1]] <- rbind(
      data.frame(T = mats_cmp, Res = r_crit, Var = "alpha-criterio",  data = dlab),
      data.frame(T = mats_cmp, Res = r_off,  Var = "alpha-ufficiale", data = dlab)
    )

    liq <- mats_cmp <= LLP; ext <- mats_cmp > LLP
    d_off <- (sp_off - sp_uff) * 100
    tab_rows[[length(tab_rows) + 1]] <- data.frame(
      Data       = format(d, "%Y-%m-%d"),
      zip        = off$zip,
      alpha_crit = round(a_crit, 5),
      alpha_uff  = round(a_off,  5),
      RMSE_liq   = round(sqrt(mean(d_off[liq]^2, na.rm = TRUE)), 2),
      RMSE_ext   = round(sqrt(mean(d_off[ext]^2, na.rm = TRUE)), 2),
      max_diff   = round(max(abs(d_off),          na.rm = TRUE), 2)
    )
    cat(sprintf("  [%s] zip=%s  alpha: crit=%.5f uff=%.5f  |res|max=%.1f bps\n",
                format(d, "%Y-%m-%d"), off$zip, a_crit, a_off,
                max(abs(d_off), na.rm = TRUE)))
  }

  if (length(rec_list) > 0) {
    df_rec <- do.call(rbind, rec_list)
    df_res <- do.call(rbind, res_list)
    tab    <- do.call(rbind, tab_rows)
    lev    <- unique(format(eswe_all$date, "%b %Y"))
    df_rec$data <- factor(df_rec$data, levels = lev)
    df_res$data <- factor(df_res$data, levels = lev)

    cat("\n  Tabella riassuntiva (EESWE[alpha-uff.] - ufficiale, bps):\n")
    print(tab, row.names = FALSE)
    write.csv(tab, file.path(dir_out, "tab_confronto.csv"), row.names = FALSE)
    cat(sprintf("  [OK] %s\n", file.path(dir_out, "tab_confronto.csv")))

    col_uff  <- col_nodi
    col_crit <- col_spot
    col_off  <- col_fwd
    serie_lev <- c("Ufficiale EIOPA", "EESWE (alpha-uff.)", "EESWE (alpha-crit.)")
    col_vals <- c("Ufficiale EIOPA"       = col_uff,
                  "EESWE (alpha-uff.)"    = col_off,
                  "EESWE (alpha-crit.)"   = col_crit)
    lt_vals  <- c("Ufficiale EIOPA"       = "solid",
                  "EESWE (alpha-uff.)"    = "solid",
                  "EESWE (alpha-crit.)"   = "longdash")
    df_rec$Serie <- factor(df_rec$Serie, levels = serie_lev)

    # --- fig08: overlay per data (T <= 60) ---
    df_o <- df_rec[df_rec$T <= 60, ]
    p8 <- ggplot(df_o, aes(x = T, y = Spot, color = Serie, linetype = Serie)) +
      geom_line(linewidth = 0.8) +
      geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
      facet_wrap(~ data, ncol = 2) +
      scale_color_manual(values = col_vals) +
      scale_linetype_manual(values = lt_vals) +
      labs(title = "Validazione: curva spot SW (input EESWE*) vs ufficiale EIOPA",
           subtitle = "Scarto sistematico in zona liquida = differenza tra Bloomberg EESWE* e fonte EIOPA",
           x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL, linetype = NULL) +
      theme_dispensa + theme(legend.position = "bottom")
    save_fig("fig08_multidata_overlay", p8, w = 9, h = 8)

    # --- fig09: residui in bps ---
    df_r <- df_res[df_res$T <= 80, ]
    p9 <- ggplot(df_r, aes(x = T, y = Res, color = data, linetype = Var)) +
      geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
      geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
      geom_line(linewidth = 0.7) +
      scale_linetype_manual(values = c("alpha-criterio" = "dashed", "alpha-ufficiale" = "solid")) +
      labs(title = "Residuo spot: SW su EESWE* - ufficiale EIOPA",
           subtitle = "Zona liquida (T<=20): basis Bloomberg EESWE* vs fonte EIOPA; estrapolazione: effetto alpha",
           x = "Scadenza T (anni)", y = "Residuo (bps)", color = "Data", linetype = "alpha") +
      theme_dispensa
    save_fig("fig09_residui_bps", p9)
  }

  # ---- DIAGNOSTICA: confronto EESWE vs par rate impliciti nella curva EIOPA ----
  # Risponde alla domanda: "EESWE1 - CRA deve dare lo spot EIOPA a 1Y?"
  # Per T=1: spot_eiopa(1Y) = par_eiopa(1Y) - CRA  (unico flusso a T=1, vedi sez. 5)
  # Quindi: EESWE1 == par_eiopa(1Y)  iff  la fonte e' la stessa.
  # Lo scarto mostra se il problema e' il ticker, il campo, o il timing.
  cat("\n=== DIAGNOSTICA: EESWE* vs par rate impliciti nella curva EIOPA ===\n")
  cat("  Domanda: EESWE<T> - CRA == spot EIOPA a scadenza T? (deve valere se input corretto)\n")
  cat("  Per T=1: spot_EIOPA(1Y) = par_EIOPA(1Y) - CRA  (un solo flusso a T=1)\n\n")
  cat(sprintf("  %-12s  %-10s  %-10s  %-10s  %-10s  %s\n",
              "Data", "T(anni)", "EESWE(%)", "par_EIOPA(%)", "Scarto(bp)", "Note"))
  cat(paste(rep("-", 75), collapse = ""), "\n")
  diag_rows <- list()
  for (i in seq_len(nrow(eswe_all))) {
    d   <- eswe_all$date[i]
    off <- read_eiopa_official(d)
    if (is.null(off)) next
    # back-calc par_eiopa per le scadenze DLT
    CRA_i  <- if (is.finite(off$CRA)) off$CRA / 1e4 else CRA   # bps -> decimale
    spot_s <- off$spot[order(off$mat)][seq_len(LLP)]            # spot 1..LLP ordinati
    Pj     <- (1 + spot_s)^(-(seq_len(LLP)))                    # no recycling
    par_eiopa <- sapply(T_mkt, function(T) (1 - Pj[T]) / sum(Pj[seq_len(T)]) + CRA_i)
    s_eswe    <- as.numeric(eswe_all[i, -1])
    scarto_bp <- (s_eswe - par_eiopa) * 1e4           # in bps (EESWE - EIOPA)
    for (j in seq_along(T_mkt)) {
      note <- if (T_mkt[j] == 1) "(spot=par-CRA)" else ""
      cat(sprintf("  %-12s  %-10d  %-10.4f  %-10.4f  %-10.1f  %s\n",
                  format(d, "%Y-%m-%d"), T_mkt[j],
                  s_eswe[j]*100, par_eiopa[j]*100, scarto_bp[j], note))
    }
    diag_rows[[length(diag_rows) + 1]] <- data.frame(
      Data = format(d, "%Y-%m-%d"), T = T_mkt,
      EESWE_pct = round(s_eswe * 100, 4),
      par_EIOPA_pct = round(par_eiopa * 100, 4),
      scarto_bps = round(scarto_bp, 1)
    )
    cat("\n")
  }
  cat("  INTERPRETAZIONE:\n")
  cat("  - Scarto ~0: EESWE e' la fonte corretta (stesso strumento e provider)\n")
  cat("  - Scarto costante per tutte le date: differenza sistematica di fonte o ticker\n")
  cat("  - Scarto > 10 bps: probabile strumento diverso (es. EURIBOR IRS vs €STR OIS)\n")
  cat("    Suggerimento: verificare EUSA<T> Curncy (EUR IRS vs EURIBOR) in Bloomberg\n")
  cat("    e confrontarlo con i valori par_EIOPA(%) sopra.\n\n")
  if (length(diag_rows) > 0) {
    diag_df <- do.call(rbind, diag_rows)
    write.csv(diag_df, file.path(dir_out, "tab_diagnostica_eeswe.csv"), row.names = FALSE)
    cat(sprintf("  [OK] %s\n\n", file.path(dir_out, "tab_diagnostica_eeswe.csv")))
  }
}


# ==============================================================================
# SEZ. 9 — VALIDAZIONE (II): input IRS EURIBOR (EUSA*) — conferma diagnostica
# ==============================================================================
#
# La diagnostica della Sez. 8 conclude che lo scarto sistematico ~25 bps tra la
# ricostruzione su EESWE (OIS €STR) e la curva ufficiale e' la firma del basis
# EURIBOR-€STR, e IPOTIZZA che l'input vero di EIOPA sia un IRS vs EURIBOR (EUSA*).
# Qui VERIFICHIAMO l'ipotesi: ripetiamo l'intera pipeline SW usando i tassi par
# IRS EUR vs EURIBOR (ticker Bloomberg EUSA<tenor> CMPL, file dati/tickersEUSA.xlsx)
# e confrontiamo la curva ricostruita con quella ufficiale EIOPA sugli stessi mesi.
#
# DIFFERENZE rispetto a EESWE:
#   - 13 scadenze, INCLUSO il 9Y: {1,2,3,4,5,6,7,8,9,10,12,15,20}
#   - strumento: IRS EUR vs EURIBOR 6M (non OIS €STR)
#   - stesso CRA (10 bps) e stessa pipeline SW (per istruzione/coerenza metodologica)
#
# RISULTATO: EUSA - CRA ricostruisce la curva ufficiale entro pochi bps (vs ~25 bps
# con EESWE) e |EUSA - par_EIOPA| < ~2 bps => l'input EIOPA e' l'IRS EURIBOR, non
# l'OIS €STR. La verifica proposta nella diagnostica della Sez. 8 si chiude.
# ==============================================================================

cat("=== SEZ. 9: VALIDAZIONE EUSA (IRS EURIBOR) vs ufficiale EIOPA ===\n")

T_mkt_eusa <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20)   # 13 scadenze (incl. 9Y)

# --- 9.0 Lettore tickersEUSA.xlsx (header in riga 1, prima colonna 'Date') -----
# Differenze rispetto a read_eswe_all(): startRow = 1 (niente riga 'Ticker'), e
# 13 scadenze invece di 12 (presenza del 9Y).
read_eusa_all <- function() {
  f <- file.path(dirname(getwd()), "dati", "tickersEUSA.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 1, detectDates = TRUE)
    dcol  <- df[[1]]
    dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    M <- as.matrix(df[, -1]); storage.mode(M) <- "numeric"
    keep <- !is.na(dates) & rowSums(is.na(M)) == 0 & ncol(M) == length(T_mkt_eusa)
    data.frame(date = dates[keep], M[keep, , drop = FALSE] / 100, check.names = FALSE)
  }, error = function(e) NULL)
}

# --- 9.1 alpha* dal criterio (sez. 9.14) per un set di scadenze qualsiasi ------
alpha_star_for_mat <- function(rates, maturities) {
  gfun <- function(a) abs(sw_fwd_int(CP, sw_calibrate(maturities, rates, a)$Qb, a) - omega) - tau
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

# --- 9.2 Loop sulle date EUSA (driver: dati/tickersEUSA.xlsx) ------------------
eusa_all <- read_eusa_all()

if (is.null(eusa_all)) {
  cat("  (tickersEUSA.xlsx non leggibile: salto la validazione EUSA)\n\n")
} else {
  mats_cmp <- 1:150
  rec_list <- list(); res_list <- list(); tab_rows <- list(); diag_rows <- list()

  for (i in seq_len(nrow(eusa_all))) {
    d   <- eusa_all$date[i]
    s_i <- as.numeric(eusa_all[i, -1])              # par IRS EUR vs EURIBOR (decimali)
    off <- read_eiopa_official(d)
    if (is.null(off)) {
      cat(sprintf("  [%s] curva ufficiale non trovata, skip\n", format(d, "%Y-%m-%d")))
      next
    }

    CRA_i  <- if (is.finite(off$CRA)) off$CRA / 1e4 else CRA
    r_i    <- s_i - CRA_i                            # after-CRA (input SW)
    a_crit <- alpha_star_for_mat(r_i, T_mkt_eusa)
    a_off  <- if (is.finite(off$alpha)) off$alpha else a_crit

    Qb_crit <- sw_calibrate(T_mkt_eusa, r_i, a_crit)$Qb
    Qb_off  <- sw_calibrate(T_mkt_eusa, r_i, a_off )$Qb
    sp_crit <- sw_spot_ann(mats_cmp, Qb_crit, a_crit) * 100
    sp_off  <- sw_spot_ann(mats_cmp, Qb_off , a_off ) * 100
    sp_uff  <- off$spot[match(mats_cmp, off$mat)] * 100
    dlab    <- format(d, "%b %Y")

    r_crit <- (sp_crit - sp_uff) * 100              # residui in bps
    r_off  <- (sp_off  - sp_uff) * 100

    rec_list[[length(rec_list) + 1]] <- rbind(
      data.frame(T = mats_cmp, Spot = sp_uff,  Serie = "Ufficiale EIOPA",        data = dlab),
      data.frame(T = mats_cmp, Spot = sp_crit, Serie = "EUSA (alpha-crit.)",     data = dlab),
      data.frame(T = mats_cmp, Spot = sp_off,  Serie = "EUSA (alpha-uff.)",      data = dlab)
    )
    res_list[[length(res_list) + 1]] <- rbind(
      data.frame(T = mats_cmp, Res = r_crit, Var = "alpha-criterio",  data = dlab),
      data.frame(T = mats_cmp, Res = r_off,  Var = "alpha-ufficiale", data = dlab)
    )

    liq <- mats_cmp <= LLP; ext <- mats_cmp > LLP
    d_off <- (sp_off - sp_uff) * 100

    # diagnostica: par rate impliciti nella curva ufficiale (gross, +CRA)
    spot_s    <- off$spot[order(off$mat)][seq_len(LLP)]
    Pj        <- (1 + spot_s)^(-(seq_len(LLP)))
    par_eiopa <- sapply(T_mkt_eusa, function(T) (1 - Pj[T]) / sum(Pj[seq_len(T)]) + CRA_i)
    scarto_bp <- (s_i - par_eiopa) * 1e4

    tab_rows[[length(tab_rows) + 1]] <- data.frame(
      Data       = format(d, "%Y-%m-%d"),
      zip        = off$zip,
      alpha_crit = round(a_crit, 5),
      alpha_uff  = round(a_off,  5),
      RMSE_liq   = round(sqrt(mean(d_off[liq]^2, na.rm = TRUE)), 2),
      RMSE_ext   = round(sqrt(mean(d_off[ext]^2, na.rm = TRUE)), 2),
      max_diff   = round(max(abs(d_off),          na.rm = TRUE), 2)
    )
    diag_rows[[length(diag_rows) + 1]] <- data.frame(
      Data = format(d, "%Y-%m-%d"), T = T_mkt_eusa,
      EUSA_pct      = round(s_i * 100, 4),
      par_EIOPA_pct = round(par_eiopa * 100, 4),
      scarto_bps    = round(scarto_bp, 1)
    )
    cat(sprintf("  [%s] zip=%s  alpha: crit=%.4f uff=%.4f  RMSE_liq=%.2f  |EUSA-par|max=%.1f bps\n",
                format(d, "%Y-%m-%d"), off$zip, a_crit, a_off,
                round(sqrt(mean(d_off[liq]^2, na.rm = TRUE)), 2),
                max(abs(scarto_bp), na.rm = TRUE)))
  }

  if (length(rec_list) > 0) {
    df_rec <- do.call(rbind, rec_list)
    df_res <- do.call(rbind, res_list)
    tab    <- do.call(rbind, tab_rows)
    diagdf <- do.call(rbind, diag_rows)
    lev    <- unique(format(eusa_all$date, "%b %Y"))
    df_rec$data <- factor(df_rec$data, levels = lev)
    df_res$data <- factor(df_res$data, levels = lev)

    cat("\n  Tabella riassuntiva EUSA (ricostruita[alpha-uff.] - ufficiale, bps):\n")
    print(tab, row.names = FALSE)
    write.csv(tab,    file.path(dir_out, "tab_confronto_eusa.csv"),    row.names = FALSE)
    write.csv(diagdf, file.path(dir_out, "tab_diagnostica_eusa.csv"), row.names = FALSE)
    cat(sprintf("  [OK] %s\n", file.path(dir_out, "tab_confronto_eusa.csv")))
    cat(sprintf("  [OK] %s\n", file.path(dir_out, "tab_diagnostica_eusa.csv")))

    serie_lev <- c("Ufficiale EIOPA", "EUSA (alpha-uff.)", "EUSA (alpha-crit.)")
    col_vals  <- c("Ufficiale EIOPA"   = col_nodi,
                   "EUSA (alpha-uff.)" = col_fwd,
                   "EUSA (alpha-crit.)" = col_spot)
    lt_vals   <- c("Ufficiale EIOPA"   = "solid",
                   "EUSA (alpha-uff.)" = "solid",
                   "EUSA (alpha-crit.)" = "longdash")
    df_rec$Serie <- factor(df_rec$Serie, levels = serie_lev)

    # --- fig10: overlay per data (T <= 60) ---
    df_o <- df_rec[df_rec$T <= 60, ]
    p10 <- ggplot(df_o, aes(x = T, y = Spot, color = Serie, linetype = Serie)) +
      geom_line(linewidth = 0.8) +
      geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
      facet_wrap(~ data, ncol = 2) +
      scale_color_manual(values = col_vals) +
      scale_linetype_manual(values = lt_vals) +
      labs(title = "Validazione: curva spot SW (input EUSA*, IRS EURIBOR) vs ufficiale EIOPA",
           subtitle = "La ricostruzione da EUSA-CRA coincide con l'ufficiale entro pochi bps (vs ~25 bps con EESWE)",
           x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL, linetype = NULL) +
      theme_dispensa + theme(legend.position = "bottom")
    save_fig("fig10_eusa_overlay", p10, w = 9, h = 8)

    # --- fig11: residui in bps ---
    df_r <- df_res[df_res$T <= 80, ]
    p11 <- ggplot(df_r, aes(x = T, y = Res, color = data, linetype = Var)) +
      geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
      geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
      geom_line(linewidth = 0.7) +
      scale_linetype_manual(values = c("alpha-criterio" = "dashed", "alpha-ufficiale" = "solid")) +
      labs(title = "Residuo spot: SW su EUSA* (IRS EURIBOR) - ufficiale EIOPA",
           subtitle = "In zona liquida il residuo e' di pochi bps: EUSA e' l'input coerente con la curva EIOPA",
           x = "Scadenza T (anni)", y = "Residuo (bps)", color = "Data", linetype = "alpha") +
      theme_dispensa
    save_fig("fig11_eusa_residui", p11)

    # --- fig12: basis EUSA vs EESWE contro i par rate impliciti EIOPA (mese di rif.) ---
    eswe_all_loc <- read_eswe_all()
    ref_date <- max(eusa_all$date)
    off_ref  <- read_eiopa_official(ref_date)
    if (!is.null(off_ref)) {
      CRA_r  <- if (is.finite(off_ref$CRA)) off_ref$CRA / 1e4 else CRA
      spot_r <- off_ref$spot[order(off_ref$mat)][seq_len(LLP)]
      Pjr    <- (1 + spot_r)^(-(seq_len(LLP)))
      par_e  <- function(Tset) sapply(Tset, function(T) (1 - Pjr[T]) / sum(Pjr[seq_len(T)]) + CRA_r)
      df_basis <- data.frame()
      j_eusa <- which(format(eusa_all$date, "%Y-%m") == format(ref_date, "%Y-%m"))[1]
      if (!is.na(j_eusa)) {
        s_u <- as.numeric(eusa_all[j_eusa, -1])
        df_basis <- rbind(df_basis, data.frame(T = T_mkt_eusa,
          scarto = (s_u - par_e(T_mkt_eusa)) * 1e4, Strumento = "EUSA (IRS EURIBOR)"))
      }
      if (!is.null(eswe_all_loc)) {
        j_eswe <- which(format(eswe_all_loc$date, "%Y-%m") == format(ref_date, "%Y-%m"))[1]
        if (!is.na(j_eswe)) {
          s_e <- as.numeric(eswe_all_loc[j_eswe, -1])
          df_basis <- rbind(df_basis, data.frame(T = T_mkt,
            scarto = (s_e - par_e(T_mkt)) * 1e4, Strumento = "EESWE (OIS €STR)"))
        }
      }
      if (nrow(df_basis) > 0) {
        p12 <- ggplot(df_basis, aes(x = T, y = scarto, color = Strumento, shape = Strumento)) +
          geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
          geom_hline(yintercept = c(-2, 2), color = "gray75", linetype = "dotted", linewidth = 0.4) +
          geom_line(linewidth = 0.9) + geom_point(size = 2.4) +
          scale_color_manual(values = c("EUSA (IRS EURIBOR)" = col_fwd,
                                        "EESWE (OIS €STR)"   = col_spot)) +
          labs(title = sprintf("Scarto vs par rate impliciti EIOPA - %s", format(ref_date, "%b %Y")),
               subtitle = "EUSA (EURIBOR) collassa nella banda +/-2 bps (input corretto); EESWE (€STR) resta ~25 bps sotto",
               x = "Scadenza T (anni)", y = "Strumento - par EIOPA (bps)",
               color = NULL, shape = NULL) +
          scale_x_continuous(breaks = T_mkt_eusa) + theme_dispensa
        save_fig("fig12_eusa_vs_eeswe_basis", p12)
      }
    }
  }
}


# ==============================================================================
# FINE — Riepilogo file generati
# ==============================================================================
cat("\n====================================================================\n")
cat("  GRAFICI GENERATI in:", dir_out, "\n")
cat("====================================================================\n")
for (f in list.files(dir_out, pattern = "\\.pdf$")) cat("  •", f, "\n")
cat("\n")
