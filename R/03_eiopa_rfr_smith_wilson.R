# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Metodo SMITH-WILSON (approccio variazionale)
#  Companion della dispensa  dispense/03.Eiopa_RFR_SW_variazionale.tex
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Questo script standalone riproduce i GRAFICI PRINCIPALI della nuova dispensa,
#  organizzati nelle 4 parti:
#    Parte 1 — Motivazioni economiche      -> fig1
#    Parte 2 — Curva dei tassi e forward   -> fig2 (+ fig2b)
#    Parte 3 — Struttura matematica SW     -> fig3, fig4, fig5
#    Parte 3b — Confronto Spline vs SW      -> fig_spline_vs_sw
#    Parte 4 — Ricostruzione luglio 2025    -> fig_sw_alpha_jul, fig_sw_curve_jul,
#                                              fig_sw_residui_jul  (+ CSV)
#
#  Riferimento metodologico: EIOPA-BoS-25-599 (RFR Technical Documentation),
#  Sezione 9 (Smith-Wilson). Le funzioni core sono ricopiate da
#  "curva_eiopa_rfr_CN - sw.R" per rendere lo script autosufficiente.
#
#  Dati di ricostruzione: dati/tickersEUSA_v3.xlsx (par IRS EUR vs EURIBOR 6M,
#  ticker Bloomberg EUSA*), scadenze DLT ufficiali EUR SWP {1..13,15,20} valide
#  30 giu - 31 dic 2025. Curve ufficiali EIOPA: dati/eiopa_zips/.
#
#  Esecuzione (dalla cartella R/):
#    "/c/Program Files/R/R-4.4.2/bin/Rscript.exe" 03_eiopa_rfr_smith_wilson.R
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

# Cartella output dedicata alla nuova dispensa
dir_out <- file.path(dirname(getwd()), "output", "03_eiopa_rfr_smith_wilson")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

# Tema grafico comune (coerente con le altre dispense)
theme_dispensa <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, color = "gray30"),
    legend.position  = "bottom"
  )

col_spot <- "#185FA5"   # blu — tasso spot
col_fwd  <- "#993C1D"   # rosso mattone — forward
col_ufr  <- "#7060CC"   # viola — UFR
col_par  <- "black"     # nodi par di mercato

save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

# ---- PARAMETRI EIOPA EUR (sez. 9.2-9.4; Annex E) -----------------------------
UFR_ann <- 0.0330                  # Ultimate Forward Rate annuo composto
omega   <- log(1 + UFR_ann)        # intensita' UFR  omega = log(1+UFR)
LLP     <- 20                      # Last Liquid Point (anni)
CP      <- max(LLP + 40, 60)       # Convergence Point = 60 anni
CRA     <- 0.0010                  # Credit Risk Adjustment di default = 10 bps
tau     <- 1e-4                    # tolleranza di convergenza (1 bp)
a_min   <- 0.05                    # limite inferiore regolamentare per alpha

# Scadenze DLT ufficiali EUR SWP (30 giu - 31 dic 2025): 15 tenor
T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 20)
N     <- length(T_mkt)

u_pay <- seq_len(LLP)              # date di pagamento annuali 1..20
m     <- length(u_pay)

cat("\n=====================================================================\n")
cat("  Curva EIOPA EUR — Smith-Wilson (approccio variazionale)\n")
cat("  Dispensa 03 — companion R\n")
cat("=====================================================================\n\n")

# ==============================================================================
# 1. FUNZIONI CORE SMITH-WILSON  (sez. 9.7-9.12 di EIOPA-BoS-25-599)
# ==============================================================================

# Cuore di Wilson  H(u,v) = a*min - exp(-a*max)*sinh(a*min)   (sez. 9.7.1)
H_heart <- function(u, v, a) {
  mn <- pmin(u, v); Mx <- pmax(u, v)
  a * mn - exp(-a * Mx) * sinh(a * mn)
}
# Funzione di Wilson  W(u,v) = exp(-omega(u+v)) H(u,v)
W_fun <- function(u, v, a, om = omega) exp(-om * (u + v)) * H_heart(u, v, a)
# Derivata dH/dv  (sez. 9.7.4), usata per il forward
G_heart <- function(v, u, a) {
  ifelse(v <= u,
         a - a * exp(-a * u) * cosh(a * v),
         a * exp(-a * v) * sinh(a * u))
}

# Matrice dei flussi C (m x n):  C[j,k]=r_k per u_j<T_k ; C[T_k,k]=1+r_k (sez. 9.15)
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

# Oggetti del sistema EIOPA per un dato alpha:  (Q'HQ) b = p - q   (sez. 9.10)
sw_system <- function(maturities, rates, a) {
  C  <- build_C(maturities, rates)
  d  <- exp(-omega * u_pay)
  Q  <- C * d                       # diag(d) %*% C
  q  <- as.numeric(t(C) %*% d)      # = Q' 1
  Hm <- outer(u_pay, u_pay, H_heart, a = a)   # cuore di Wilson (m x m), SPD
  QHQ <- t(Q) %*% Hm %*% Q          # n x n simmetrica definita positiva
  list(C = C, d = d, Q = Q, q = q, H = Hm, QHQ = QHQ, p = rep(1, length(maturities)))
}

# Calibrazione: risolve il sistema SPD con CHOLESKY  (QHQ = R'R)
sw_calibrate <- function(maturities, rates, a) {
  sys <- sw_system(maturities, rates, a)
  rhs <- sys$p - sys$q
  R   <- chol(sys$QHQ)
  b   <- backsolve(R, forwardsolve(t(R), rhs))
  Qb  <- as.numeric(sys$Q %*% b)
  c(sys, list(b = b, Qb = Qb))
}

# Funzioni curva valutate dai coefficienti Qb sui nodi di pagamento u_pay
sw_P <- function(v, Qb, a) {
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  exp(-omega * v) * (1 + Hv)
}
sw_spot_int <- function(v, Qb, a) -log(sw_P(v, Qb, a)) / v          # intensita' spot
sw_spot_ann <- function(v, Qb, a) exp(sw_spot_int(v, Qb, a)) - 1    # tasso spot annuo
sw_fwd_int  <- function(v, Qb, a) {                                 # forward intensita'
  Hv <- sapply(v, function(x) sum(H_heart(x, u_pay, a) * Qb))
  Gv <- sapply(v, function(x) sum(G_heart(x, u_pay, a) * Qb))
  omega - Gv / (1 + Hv)
}
sw_fwd_ann  <- function(v, Qb, a) exp(sw_fwd_int(v, Qb, a)) - 1     # forward annuo

# Criterio EIOPA per alpha (sez. 9.14): piu' piccolo alpha>=a_min con |f(CP,a)-omega|<=tau
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

# Lettura par EUSA da tickersEUSA_v3.xlsx (12 mesi x 15 scadenze)
read_eusa_all <- function() {
  f <- file.path(dirname(getwd()), "dati", "tickersEUSA_v3.xlsx")
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
# 2. DATI: par EUSA + filtro alla finestra giugno -> dicembre 2025
# ==============================================================================

eusa_all <- read_eusa_all()
if (is.null(eusa_all)) stop("Impossibile leggere dati/tickersEUSA_v3.xlsx")

# Finestra regolamentare del set {1..13,15,20}: 30 giugno - 31 dicembre 2025
in_window <- format(eusa_all$date, "%Y") == "2025" &
             as.integer(format(eusa_all$date, "%m")) >= 6
eusa <- eusa_all[in_window, , drop = FALSE]
eusa <- eusa[order(eusa$date), ]
cat(sprintf("Mesi nella finestra giu-dic 2025: %d\n", nrow(eusa)))
cat("  ", paste(format(eusa$date), collapse = ", "), "\n\n")

ref_date <- max(eusa$date)            # mese di riferimento per le figure 1-5 (dic 2025)
ref_lab  <- format(ref_date, "%b %Y")

# --- Calibrazione del mese di riferimento -------------------------------------
off_ref  <- read_eiopa_official(ref_date)
if (is.null(off_ref)) stop("Curva ufficiale EIOPA non trovata per ", ref_lab)
CRA_ref  <- if (is.finite(off_ref$CRA)) off_ref$CRA / 1e4 else CRA
s_ref    <- as.numeric(eusa[eusa$date == ref_date, -1])   # par EUSA (decimali)
r_ref    <- s_ref - CRA_ref                                # input after-CRA
a_ref    <- alpha_star_for_mat(r_ref, T_mkt)
cal_ref  <- sw_calibrate(T_mkt, r_ref, a_ref)
Qb_ref   <- cal_ref$Qb

cat(sprintf("Mese di riferimento: %s  (zip %s)\n", ref_lab, off_ref$zip))
cat(sprintf("  CRA = %.0f bps,  alpha* (criterio) = %.4f\n\n", CRA_ref * 1e4, a_ref))

# ==============================================================================
# PARTE 1 — MOTIVAZIONI ECONOMICHE  (fig1)
# ==============================================================================
# Spot e forward ricostruiti fino al Convergence Point: oltre il LLP il mercato
# non quota, la curva e' ESTRAPOLATA e il forward converge all'UFR.

grid1 <- seq(1, CP, by = 0.25)
df1 <- rbind(
  data.frame(T = grid1, val = sw_spot_ann(grid1, Qb_ref, a_ref) * 100, Serie = "Spot r(0,T)"),
  data.frame(T = grid1, val = sw_fwd_ann (grid1, Qb_ref, a_ref) * 100, Serie = "Forward f(0,T)")
)
p1 <- ggplot(df1, aes(x = T, y = val, color = Serie)) +
  annotate("rect", xmin = LLP, xmax = CP, ymin = -Inf, ymax = Inf,
           fill = "gray85", alpha = 0.35) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed", linewidth = 0.7) +
  geom_vline(xintercept = LLP, color = "gray55", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 1) +
  annotate("text", x = LLP + 0.6, y = min(df1$val), label = "estrapolazione (T > LLP)",
           hjust = 0, color = "gray35", size = 3.4) +
  annotate("text", x = CP - 0.5, y = UFR_ann * 100 + 0.06, label = "UFR = 3.30%",
           hjust = 1, color = col_ufr, size = 3.6) +
  scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  labs(title = sprintf("Perche' estrapolare: curva EUR ricostruita oltre il LLP (%s)", ref_lab),
       subtitle = "Il mercato e' liquido solo fino al LLP=20a; oltre, il forward converge all'UFR",
       x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) +
  theme_dispensa
save_fig("fig1_motivazione_estrapolazione", p1)

# ==============================================================================
# PARTE 2 — CURVA DEI TASSI E TASSI FORWARD  (fig2, fig2b)
# ==============================================================================
# Spot, forward e nodi par EUSA per il mese di riferimento.

grid2 <- seq(0.5, 30, by = 0.25)
df2 <- rbind(
  data.frame(T = grid2, val = sw_spot_ann(grid2, Qb_ref, a_ref) * 100, Serie = "Spot r(0,T)"),
  data.frame(T = grid2, val = sw_fwd_ann (grid2, Qb_ref, a_ref) * 100, Serie = "Forward f(0,T)")
)
df2_par <- data.frame(T = T_mkt, val = s_ref * 100)
p2 <- ggplot(df2, aes(x = T, y = val, color = Serie)) +
  geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 1) +
  geom_point(data = df2_par, aes(x = T, y = val), inherit.aes = FALSE,
             color = col_par, size = 2) +
  scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  labs(title = sprintf("Spot, forward e par swap EUSA* — %s", ref_lab),
       subtitle = "Punti neri: par rate IRS EUR vs EURIBOR 6M ai 15 nodi DLT {1..13,15,20}",
       x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25, 30)) +
  theme_dispensa
save_fig("fig2_spot_forward_par", p2)

df2b <- data.frame(T = grid2, P = sw_P(grid2, Qb_ref, a_ref))
p2b <- ggplot(df2b, aes(x = T, y = P)) +
  geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 1, color = col_spot) +
  labs(title = sprintf("Fattori di sconto P(0,T) — %s", ref_lab),
       subtitle = "P(0,T) = prezzo oggi di 1 unita' pagata in T; decresce con la scadenza",
       x = "Scadenza T (anni)", y = "P(0,T)") +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25, 30)) +
  theme_dispensa
save_fig("fig2b_fattori_sconto", p2b)

# ==============================================================================
# PARTE 3 — STRUTTURA MATEMATICA SW (approccio variazionale)  (fig3, fig4, fig5)
# ==============================================================================

# --- fig3: famiglia di funzioni di Wilson W(t,u_j) (le "basi" RKHS) ------------
t_grid <- seq(0.01, 60, length.out = 600)
u_nodi <- c(1, 5, 10, 20)
df3 <- do.call(rbind, lapply(u_nodi, function(uj)
  data.frame(t = t_grid, W = W_fun(t_grid, uj, a_ref),
             u = factor(paste0("u = ", uj, "a"), levels = paste0("u = ", u_nodi, "a")))))
p3 <- ggplot(df3, aes(x = t, y = W, color = u)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
  geom_vline(xintercept = LLP, linetype = "dashed", color = "gray70", linewidth = 0.4) +
  geom_line(linewidth = 0.9) +
  labs(title = "Funzioni di Wilson W(t,u_j): le 'basi' dell'interpolante SW",
       subtitle = sprintf("La curva SW e' combinazione lineare di queste funzioni (alpha = %.3f)", a_ref),
       x = "t (anni)", y = expression(W(t, u[j])), color = "Nodo") +
  theme_dispensa
save_fig("fig3_kernel_wilson", p3)

# --- fig4: matrice SPD Q'HQ del mese di riferimento ---------------------------
QHQ <- cal_ref$QHQ
df4 <- melt(QHQ); names(df4) <- c("i", "j", "v")
df4$i_lab <- factor(T_mkt[df4$i], levels = T_mkt)
df4$j_lab <- factor(T_mkt[df4$j], levels = rev(T_mkt))
ev_min <- min(eigen(QHQ, symmetric = TRUE, only.values = TRUE)$values)
p4 <- ggplot(df4, aes(x = i_lab, y = j_lab, fill = v)) +
  geom_tile() +
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

# --- fig5: criterio per alpha come ricerca di zeri (sez. 9.14) -----------------
a_grid <- seq(a_min, 0.30, length.out = 200)
g_vals <- sapply(a_grid, function(a)
  (sw_fwd_int(CP, sw_calibrate(T_mkt, r_ref, a)$Qb, a) - omega) * 1e4)   # in bps
df5 <- data.frame(alpha = a_grid, g = g_vals)
p5 <- ggplot(df5, aes(x = alpha, y = g)) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -1, ymax = 1,
           fill = "gray85", alpha = 0.5) +
  geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
  geom_line(linewidth = 1, color = col_fwd) +
  geom_vline(xintercept = a_ref, color = col_spot, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = a_min, color = "gray55", linetype = "dotted", linewidth = 0.5) +
  annotate("text", x = a_ref, y = max(df5$g) * 0.85,
           label = sprintf("alpha* = %.3f", a_ref), hjust = -0.1, color = col_spot, size = 3.6) +
  annotate("text", x = a_min, y = max(df5$g) * 0.6, label = "a_min = 0.05",
           hjust = -0.1, color = "gray40", size = 3.3) +
  labs(title = "Calibrazione di alpha: ricerca di zeri (criterio sez. 9.14)",
       subtitle = "g(alpha) = f(CP,alpha) - omega in bps; banda grigia = tolleranza +/-1 bp",
       x = expression(alpha), y = "f(CP, alpha) - omega  (bps)") +
  theme_dispensa
save_fig("fig5_calibrazione_alpha", p5)

# ==============================================================================
# SEZIONE — LIMITI DELL'INTERPOLAZIONE SPLINE  (fig_spline_vs_sw)
# ==============================================================================
# Dati luglio 2025 (mese di riferimento per la ricostruzione passo a passo)

d_jul   <- as.Date("2025-07-31")
off_jul <- read_eiopa_official(d_jul)
if (is.null(off_jul)) stop("Curva ufficiale luglio 2025 non trovata in dati/eiopa_zips/")
s_jul   <- as.numeric(eusa[eusa$date == d_jul, -1])
CRA_jul <- if (is.finite(off_jul$CRA)) off_jul$CRA / 1e4 else CRA
r_jul   <- s_jul - CRA_jul
a_jul   <- if (is.finite(off_jul$alpha)) off_jul$alpha else alpha_star_for_mat(r_jul, T_mkt)
Qb_jul  <- sw_calibrate(T_mkt, r_jul, a_jul)$Qb
lab_jul <- "Luglio 2025"

cat(sprintf("\nMese passo a passo: %s  (zip %s)\n", lab_jul, off_jul$zip))
cat(sprintf("  CRA = %.0f bps,  alpha ufficiale = %.4f\n", CRA_jul * 1e4, a_jul))

# Ventaglio di estrapolazioni: due spline cubiche con diversa condizione al contorno,
# costruite sugli STESSI tassi liquidi spot ai 15 nodi DLT (la stessa informazione data
# a entrambi i metodi). Coincidono per T <= LLP, divergono in modo arbitrario oltre.
sp_nodes <- sw_spot_ann(T_mkt, Qb_jul, a_jul) * 100   # spot di riferimento ai nodi (%)
grid_spl <- seq(1, 60, by = 0.25)

spl_nat <- splinefun(T_mkt, sp_nodes, method = "natural")  # 2a derivata = 0 ai bordi
spl_fmm <- splinefun(T_mkt, sp_nodes, method = "fmm")      # cubica ai bordi (default R)
spot_sw <- sw_spot_ann(grid_spl, Qb_jul, a_jul) * 100

df_fan <- rbind(
  data.frame(T = grid_spl, val = spl_nat(grid_spl), Serie = "Spline naturale"),
  data.frame(T = grid_spl, val = spl_fmm(grid_spl), Serie = "Spline cubica (fmm)"),
  data.frame(T = grid_spl, val = spot_sw,           Serie = "Smith-Wilson")
)
df_fan$Serie <- factor(df_fan$Serie,
  levels = c("Spline naturale", "Spline cubica (fmm)", "Smith-Wilson"))

p_fan <- ggplot(df_fan, aes(x = T, y = val, color = Serie)) +
  annotate("rect", xmin = LLP, xmax = 60, ymin = -Inf, ymax = Inf,
           fill = "gray85", alpha = 0.35) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed",
             linewidth = 0.7) +
  geom_vline(xintercept = LLP, color = "gray55", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 1) +
  coord_cartesian(ylim = c(-1, 6)) +     # la fmm puo' uscire dalla scala: divergenza
  scale_color_manual(values = c("Spline naturale"     = "#E08214",
                                "Spline cubica (fmm)"  = "#B2182B",
                                "Smith-Wilson"         = col_spot)) +
  annotate("text", x = LLP + 0.7, y = -0.6, label = "estrapolazione (T > LLP)",
           hjust = 0, color = "gray35", size = 3.3) +
  annotate("text", x = 59, y = UFR_ann * 100 + 0.18, label = "UFR = 3.30%",
           hjust = 1, color = col_ufr, size = 3.5) +
  labs(title = sprintf("Oltre il LLP il dato non basta: estrapolazioni a confronto (%s)", lab_jul),
       subtitle = "Le spline coincidono sui dati liquidi ma divergono in modo arbitrario; SW converge all'UFR",
       x = "Scadenza T (anni)", y = "Tasso spot r(0,T) (%)", color = NULL) +
  theme_dispensa + theme(legend.position = "top")
save_fig("fig_spline_vs_sw", p_fan)

# ==============================================================================
# PARTE 4 — RICOSTRUZIONE luglio 2025: passo a passo
# ==============================================================================

# --- Tabella dati di input ----------------------------------------------------
tab_input <- data.frame(
  Tenor        = T_mkt,
  EUSA_pct     = round(s_jul * 100, 4),
  afterCRA_pct = round(r_jul * 100, 4)
)
cat("\n  Par rate EUSA* e after-CRA (luglio 2025):\n")
print(tab_input, row.names = FALSE)

# --- fig_sw_alpha_jul: calibrazione di alpha ----------------------------------
a_grid <- seq(a_min, 0.30, length.out = 200)
g_jul  <- sapply(a_grid, function(a)
  (sw_fwd_int(CP, sw_calibrate(T_mkt, r_jul, a)$Qb, a) - omega) * 1e4)
df_g <- data.frame(alpha = a_grid, g = g_jul)
p_alpha_jul <- ggplot(df_g, aes(x = alpha, y = g)) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -1, ymax = 1,
           fill = "gray85", alpha = 0.5) +
  geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
  geom_line(linewidth = 1, color = col_fwd) +
  geom_vline(xintercept = a_jul, color = col_spot, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = a_min, color = "gray55", linetype = "dotted", linewidth = 0.5) +
  annotate("text", x = a_jul, y = max(df_g$g) * 0.80,
           label = sprintf("alpha* = %.4f", a_jul),
           hjust = -0.1, color = col_spot, size = 3.6) +
  annotate("text", x = a_min, y = max(df_g$g) * 0.55,
           label = sprintf("alpha_min = %.2f", a_min),
           hjust = -0.1, color = "gray40", size = 3.3) +
  labs(title = sprintf("Calibrazione di alpha — %s", lab_jul),
       subtitle = "g(alpha) = f(CP, alpha) - omega in bps; banda grigia = tolleranza +/-1 bp",
       x = expression(alpha), y = "f(CP, alpha) - omega  (bps)") +
  theme_dispensa
save_fig("fig_sw_alpha_jul", p_alpha_jul)

# --- fig_sw_curve_jul: spot + forward + nodi par ------------------------------
grid_f <- seq(0.5, 30, by = 0.25)
df_curve <- rbind(
  data.frame(T = grid_f, val = sw_spot_ann(grid_f, Qb_jul, a_jul) * 100, Serie = "Spot r(0,T)"),
  data.frame(T = grid_f, val = sw_fwd_ann (grid_f, Qb_jul, a_jul) * 100, Serie = "Forward f(0,T)")
)
df_par_jul <- data.frame(T = T_mkt, val = s_jul * 100)
p_curve_jul <- ggplot(df_curve, aes(x = T, y = val, color = Serie)) +
  geom_vline(xintercept = LLP, color = "gray70", linetype = "dashed", linewidth = 0.4) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dashed",
             linewidth = 0.5) +
  geom_line(linewidth = 1) +
  geom_point(data = df_par_jul, aes(x = T, y = val), inherit.aes = FALSE,
             color = col_par, size = 2.5) +
  scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25, 30)) +
  annotate("text", x = 29.5, y = UFR_ann * 100 + 0.06, label = "UFR",
           hjust = 1, color = col_ufr, size = 3.4) +
  labs(title = sprintf("Curva Smith-Wilson calibrata — %s", lab_jul),
       subtitle = "Punti neri: par rate EUSA* ai 15 nodi DLT. Linea viola = UFR = 3.30%.",
       x = "Scadenza T (anni)", y = "Tasso annuo (%)", color = NULL) +
  theme_dispensa
save_fig("fig_sw_curve_jul", p_curve_jul)

# --- fig_sw_residui_jul: scarto SW - ufficiale su tutti i tenor interi -------
# La curva ufficiale EIOPA pubblica spot a tutti i tenor interi 1..150;
# confrontiamo su 1..80 (zona liquida + estrapolazione fino al CP)
mats_all   <- 1:80
sp_sw_all  <- sw_spot_ann(mats_all, Qb_jul, a_jul) * 100
sp_off_all <- off_jul$spot[match(mats_all, off_jul$mat)] * 100
res_all    <- (sp_sw_all - sp_off_all) * 100   # bps
ok         <- is.finite(res_all)
df_res_jul <- data.frame(T = mats_all[ok], Res = res_all[ok],
                         Zona = ifelse(mats_all[ok] <= LLP, "Liquida", "Estrapolazione"))
res_jul    <- res_all[match(T_mkt, mats_all)]   # per diagnostica (nodi DLT)
ylim_res   <- max(2, ceiling(max(abs(res_all[ok]), na.rm = TRUE)))
p_res_jul <- ggplot(df_res_jul, aes(x = T, y = Res, fill = Zona)) +
  geom_col(width = 0.9, show.legend = TRUE) +
  geom_vline(xintercept = LLP + 0.5, color = "gray50", linetype = "dashed",
             linewidth = 0.4) +
  geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
  geom_hline(yintercept = c(-2, 2), color = "gray65", linetype = "dotted",
             linewidth = 0.35) +
  scale_fill_manual(values = c("Liquida" = col_spot, "Estrapolazione" = col_fwd)) +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 40, 60, 80)) +
  scale_y_continuous(limits = c(-ylim_res, ylim_res)) +
  annotate("text", x = LLP + 1, y = ylim_res * 0.85, label = "LLP = 20a",
           hjust = 0, color = "gray40", size = 3.2) +
  labs(title = sprintf("Residui SW - ufficiale EIOPA su tutti i tenor — %s", lab_jul),
       subtitle = "Ogni barra = scarto spot in bps (tenor interi 1-80a). Linee tratteggiate: +/-2 bps.",
       x = "Tenor (anni)", y = "Differenza (bps)", fill = NULL) +
  theme_dispensa +
  theme(legend.position = "top")
save_fig("fig_sw_residui_jul", p_res_jul)

# --- Diagnostica numerica (residui ai 15 nodi DLT, tutti <= LLP) -------------
RMSE_liq <- sqrt(mean(res_jul^2, na.rm = TRUE))
maxdiff  <- max(abs(res_jul), na.rm = TRUE)
tab_diag <- data.frame(
  Mese         = format(d_jul, "%Y-%m-%d"),
  alpha_uff    = round(a_jul, 4),
  RMSE_bps     = round(RMSE_liq, 2),
  max_diff_bps = round(maxdiff, 2)
)
cat("\n  Diagnostica luglio 2025:\n")
print(tab_diag, row.names = FALSE)
write.csv(tab_diag, file.path(dir_out, "tab_ricostruzione_var.csv"), row.names = FALSE)
cat(sprintf("\n  [OK] %s\n", file.path(dir_out, "tab_ricostruzione_var.csv")))

cat("\n=====================================================================\n")
cat("  FIGURE GENERATE in:", dir_out, "\n")
cat("=====================================================================\n")
for (f in list.files(dir_out, pattern = "\\.pdf$")) cat("  -", f, "\n")
cat("\n")
