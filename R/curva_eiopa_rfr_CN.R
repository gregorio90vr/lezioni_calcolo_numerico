# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Smith-Wilson su swap par
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Questo script riproduce tutti i risultati e le figure della dispensa
#  "Costruzione della Curva EIOPA Risk-Free Rate"
#
#  Riferimento: EIOPA-BoS-25-599 (Technical Documentation, Dec 2025)
#
#  Output: figure PDF in ../output/curva_eiopa_rfr/
#
#  Struttura:
#    Sez. 0  — Setup e parametri EIOPA EUR 2025
#    Sez. 1  — Dati input e visualizzazione OIS par rates
#    Sez. 2  — Kernel di Wilson: visualizzazione e proprietà
#    Sez. 3  — Calibrazione SW: matrice H, soluzione sistema lineare
#    Sez. 4  — Bisezione per alpha*
#    Sez. 5  — Curva completa: spot, forward, convergenza a UFR
#    Sez. 6  — Confronto spline cubiche vs Smith-Wilson
#    Sez. 7  — Analisi di sensitività (UFR, alpha)
# ==============================================================================

# ---- 0. SETUP ----------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
  library(reshape2)
})

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

# Cartella output grafici
dir_out <- file.path(dirname(getwd()), "output", "curva_eiopa_rfr")
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
col_spot    <- "#185FA5"   # blu scuro — tasso spot
col_fwd     <- "#993C1D"   # rosso mattone — forward
col_ufr     <- "#7060CC"   # viola — UFR
col_spline  <- "#2ca02c"   # verde — spline
col_nodi    <- "black"     # nodi di mercato
col_kernel  <- "#E07020"   # arancio — kernel

# Helper: salva figura PDF
save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

cat("\n====================================================================\n")
cat("  CURVA EIOPA EUR — Smith-Wilson su swap par (EIOPA-BoS-25-599)\n")
cat("====================================================================\n\n")

# ==============================================================================
# PARAMETRI EIOPA EUR 2025 (sez. 9.3, 9.4)
# ==============================================================================

UFR_ann <- 0.0330                   # 3.30% annuo composto
UFR_c   <- log(1 + UFR_ann)        # intensità continua ~ 3.2466%
LLP     <- 20                       # Last Liquid Point EUR (anni)
CP      <- max(LLP + 40, 60)       # Convergence Point = 60 anni
CRA     <- 0.0010                   # Credit Risk Adjustment = 10 bps

cat(sprintf("UFR annuo:   %.2f%%\n", UFR_ann * 100))
cat(sprintf("UFR continuo: %.4f%%\n", UFR_c * 100))
cat(sprintf("LLP = %d anni,  CP = %d anni,  CRA = %d bps\n\n", LLP, CP, CRA * 1e4))

# ==============================================================================
# SEZ. 1 — DATI DI INPUT: tassi OIS €STR par
# ==============================================================================
#
# ORIGINE DEI DATI
# ================
# I tassi par OIS (Overnight Index Swap) su €STR sono pubblicati quotidianamente
# da Bloomberg (ticker: EESWE*) e Refinitiv/LSEG. EIOPA li raccoglie per tutte
# le valute rilevanti (EUR, GBP, CHF, USD, JPY, ...) e ne pubblica le curve
# mensilmente. I dati qui riportati sono illustrativi ma rappresentativi del
# livello di mercato a maggio 2025.
#
# Per l'EUR le scadenze standard DLT (deep, liquid, transparent) fino al LLP=20
# anni sono: 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20.
# Le scadenze 9, 11, 13, 14, 16-19 non sono incluse perché non soddisfano
# i criteri di liquidità (residual volume < 6% del totale, sez. 3.7 EIOPA).
#
# Riferimento: EIOPA-BoS-25-599, sez. 5.3, Annex B.
# ==============================================================================

cat("=== SEZ. 1: DATI INPUT ===\n")

# Scadenze DLT per EUR (in anni)
T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20)

# Tassi par OIS €STR (%, valori illustrativi maggio 2025)
s_mkt <- c(3.742, 2.851, 2.577, 2.468, 2.413, 2.398,
           2.393, 2.400, 2.470, 2.510, 2.555, 2.581) / 100

# After-CRA (sez. 7.3 EIOPA: sottrazione del CRA)
r_mkt <- s_mkt - CRA

N <- length(T_mkt)  # numero di strumenti

# Tabella riassuntiva
cat("\n  Scadenza   OIS_par(%)   After-CRA(%)\n")
cat("  ----------------------------------------\n")
for (i in seq_along(T_mkt)) {
  cat(sprintf("  %4d Y     %6.3f       %6.3f\n", T_mkt[i], s_mkt[i]*100, r_mkt[i]*100))
}
cat("\n")

# --- Grafico: tassi par OIS e after-CRA ---
df_input <- data.frame(
  Scadenza = rep(T_mkt, 2),
  Tasso    = c(s_mkt * 100, r_mkt * 100),
  Tipo     = rep(c("OIS par (lordo)", "After-CRA (netto)"), each = N)
)

p1 <- ggplot(df_input, aes(x = Scadenza, y = Tasso, color = Tipo, shape = Tipo)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_color_manual(values = c("OIS par (lordo)" = col_spot, "After-CRA (netto)" = col_fwd)) +
  labs(title = "Tassi OIS €STR par — EUR maggio 2025 (illustrativo)",
       subtitle = sprintf("CRA = %d bps sottratto per ottenere i tassi risk-free (sez. 7.3 EIOPA)",
                          CRA * 1e4),
       x = "Scadenza (anni)", y = "Tasso (%)",
       color = NULL, shape = NULL) +
  theme_dispensa +
  scale_x_continuous(breaks = T_mkt)
save_fig("fig01_input_ois_par", p1)


# ==============================================================================
# SEZ. 2 — KERNEL DI WILSON: visualizzazione e proprietà
# ==============================================================================

cat("=== SEZ. 2: KERNEL DI WILSON ===\n")

# Kernel W(t, u) — eq. (9.7) EIOPA-BoS-25-599
W_kernel <- function(t, u, ufr, alpha) {
  tmin <- pmin(t, u)
  tmax <- pmax(t, u)
  exp(-ufr * (t + u)) * (alpha * tmin - exp(-alpha * tmax) * sinh(alpha * tmin))
}

# Grafico: kernel W(t, u_j) per diversi nodi u_j, con alpha fisso
alpha_plot <- 0.128  # valore tipico EUR
t_grid <- seq(0.01, 60, length.out = 500)

# Scegliamo 4 nodi rappresentativi
u_nodi <- c(1, 5, 10, 20)
df_kernel <- do.call(rbind, lapply(u_nodi, function(uj) {
  data.frame(t = t_grid, W = W_kernel(t_grid, uj, UFR_c, alpha_plot),
             u = paste0("u = ", uj, " anni"))
}))

p2a <- ggplot(df_kernel, aes(x = t, y = W, color = u)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = LLP, linetype = "dashed", color = "gray70", linewidth = 0.5) +
  annotate("text", x = LLP + 1, y = max(df_kernel$W) * 0.9, label = "LLP",
           color = "gray50", size = 3.5) +
  labs(title = expression(paste("Kernel di Wilson ", W(t, u[j]),
                                " — sez. 9.7 EIOPA-BoS-25-599")),
       subtitle = bquote(alpha == .(alpha_plot) ~ ", " ~ UFR[c] == .(round(UFR_c, 5))),
       x = "t (anni)", y = expression(W(t, u[j])), color = "Nodo") +
  theme_dispensa
save_fig("fig02a_kernel_wilson", p2a)

# Grafico: effetto di alpha sul kernel (fissato u = 10)
alpha_vals <- c(0.05, 0.10, 0.15, 0.30, 0.50)
u_fix <- 10
df_alpha_eff <- do.call(rbind, lapply(alpha_vals, function(a) {
  data.frame(t = t_grid, W = W_kernel(t_grid, u_fix, UFR_c, a),
             alpha = paste0("α = ", sprintf("%.2f", a)))
}))

p2b <- ggplot(df_alpha_eff, aes(x = t, y = W, color = alpha)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  labs(title = expression(paste("Effetto di ", alpha, " sul kernel (nodo ", u == 10, " anni)")),
       subtitle = "Alpha piccolo → kernel più ampio → convergenza a UFR più lenta",
       x = "t (anni)", y = expression(W(t, 10)), color = NULL) +
  theme_dispensa
save_fig("fig02b_kernel_alpha_effetto", p2b)

# Grafico: matrice W = [W(u_i, u_j)] come heatmap
W_matrix <- matrix(0, N, N)
for (i in 1:N) for (j in 1:N) {
  W_matrix[i, j] <- W_kernel(T_mkt[i], T_mkt[j], UFR_c, alpha_plot)
}

df_Wmat <- melt(W_matrix)
names(df_Wmat) <- c("i", "j", "W")
df_Wmat$i_lab <- factor(T_mkt[df_Wmat$i], levels = T_mkt)
df_Wmat$j_lab <- factor(T_mkt[df_Wmat$j], levels = rev(T_mkt))

p2c <- ggplot(df_Wmat, aes(x = i_lab, y = j_lab, fill = W)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                       midpoint = 0) +
  labs(title = expression(paste("Matrice kernel ", bold(W) == group("[", W(u[i], u[j]), "]"),
                                " — simmetrica definita positiva")),
       subtitle = bquote(alpha == .(alpha_plot) ~ ", dimensione " ~ .(N) %*% .(N)),
       x = expression(u[j] ~ " (anni)"), y = expression(u[i] ~ " (anni)"),
       fill = expression(W(u[i], u[j]))) +
  theme_dispensa +
  theme(aspect.ratio = 1)
save_fig("fig02c_matrice_kernel_W", p2c, w = 7, h = 6)


# ==============================================================================
# SEZ. 3 — CALIBRAZIONE SMITH-WILSON: matrice H e sistema lineare
# ==============================================================================

cat("=== SEZ. 3: CALIBRAZIONE SW ===\n")

# Funzione: costruisce matrice H e vettore b = 1 - mu_Q
# Riferimento: sez. 9.15 EIOPA-BoS-25-599
sw_build_system <- function(maturities, par_rates, ufr, alpha) {
  N <- length(maturities)
  H    <- matrix(0, N, N)
  mu_Q <- numeric(N)
  
  for (i in seq_len(N)) {
    Ti <- maturities[i]
    ri <- par_rates[i]
    for (j in seq_len(Ti)) {
      c_ij <- if (j < Ti) ri else (1 + ri)
      mu_Q[i] <- mu_Q[i] + c_ij * exp(-ufr * j)
      for (k in seq_len(N)) {
        H[i, k] <- H[i, k] + c_ij * W_kernel(j, maturities[k], ufr, alpha)
      }
    }
  }
  
  list(H = H, b = 1 - mu_Q, mu_Q = mu_Q)
}

# Funzione: calibrazione completa (costruisce sistema e risolve)
sw_calibrate <- function(maturities, par_rates, ufr, alpha) {
  sys <- sw_build_system(maturities, par_rates, ufr, alpha)
  zeta <- solve(sys$H, sys$b)  # LU con pivoting (LAPACK dgesv)
  list(zeta = zeta, H = sys$H, b = sys$b, mu_Q = sys$mu_Q)
}

# Funzione: fattore di sconto P(0, t)
sw_discount <- function(t, maturities, zeta, ufr, alpha) {
  P <- exp(-ufr * t)
  for (k in seq_along(maturities)) {
    P <- P + zeta[k] * W_kernel(t, maturities[k], ufr, alpha)
  }
  P
}

# Funzione: tasso forward f(0,t) via derivata centrata
sw_forward <- function(t, maturities, zeta, ufr, alpha, h = 1e-7) {
  Pp <- sw_discount(t + h, maturities, zeta, ufr, alpha)
  Pm <- sw_discount(t - h, maturities, zeta, ufr, alpha)
  -(log(Pp) - log(Pm)) / (2 * h)
}

# --- Calibrazione con alpha illustrativo ---
alpha_ill <- 0.128
cal <- sw_calibrate(T_mkt, r_mkt, UFR_c, alpha_ill)
zeta_ill <- cal$zeta
H_ill    <- cal$H

cat(sprintf("  Matrice H: %d x %d, densa, non simmetrica\n", N, N))
cat(sprintf("  Cond(H) = %.2f (norma 2)\n", kappa(H_ill, exact = TRUE)))
cat(sprintf("  Soluzione zeta (primi 5): %s\n",
            paste(sprintf("%.6f", zeta_ill[1:5]), collapse = ", ")))

# --- Verifica: i fattori di sconto replicano i par? ---
cat("\n  Verifica calibrazione (valore par swap = 1):\n")
for (i in seq_along(T_mkt)) {
  Ti <- T_mkt[i]
  ri <- r_mkt[i]
  val <- 0
  for (j in 1:Ti) {
    c_ij <- if (j < Ti) ri else (1 + ri)
    val <- val + c_ij * sw_discount(j, T_mkt, zeta_ill, UFR_c, alpha_ill)
  }
  cat(sprintf("    T=%2d: valore = %.10f  (errore = %.2e)\n", Ti, val, abs(val - 1)))
}

# --- Grafico: struttura matrice H (heatmap) ---
df_H <- melt(H_ill)
names(df_H) <- c("riga", "col", "valore")
df_H$riga_lab <- factor(T_mkt[df_H$riga], levels = T_mkt)
df_H$col_lab  <- factor(T_mkt[df_H$col], levels = T_mkt)

p3a <- ggplot(df_H, aes(x = col_lab, y = riga_lab, fill = valore)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                       midpoint = 0) +
  labs(title = expression(paste("Matrice ", bold(H), " del sistema EIOPA (sez. 9.15)")),
       subtitle = bquote("Densa, non simmetrica — " ~ kappa[2](bold(H)) == 
                           .(sprintf("%.1f", kappa(H_ill, exact = TRUE)))),
       x = expression(u[k] ~ " (colonna)"), y = expression(T[i] ~ " (riga)"),
       fill = expression(H[ik])) +
  theme_dispensa +
  theme(aspect.ratio = 1)
save_fig("fig03a_matrice_H", p3a, w = 7, h = 6)

# --- Grafico: vettore zeta (coefficienti) ---
df_zeta <- data.frame(scadenza = T_mkt, zeta = zeta_ill)

p3b <- ggplot(df_zeta, aes(x = scadenza, y = zeta)) +
  geom_col(fill = col_spot, alpha = 0.7, width = 0.7) +
  geom_hline(yintercept = 0, linewidth = 0.4) +
  labs(title = expression(paste("Coefficienti ", zeta[k], " — soluzione del sistema ",
                                bold(H), zeta == bold(b))),
       subtitle = bquote(alpha == .(alpha_ill) ~ ", " ~ N == .(N) ~ " nodi"),
       x = "Nodo (scadenza in anni)", y = expression(zeta[k])) +
  scale_x_continuous(breaks = T_mkt) +
  theme_dispensa
save_fig("fig03b_coefficienti_zeta", p3b)

# --- Grafico: condizionamento H in funzione di alpha ---
alpha_grid <- seq(0.05, 0.50, by = 0.005)
cond_vals <- sapply(alpha_grid, function(a) {
  sys <- sw_build_system(T_mkt, r_mkt, UFR_c, a)
  kappa(sys$H, exact = TRUE)
})

df_cond <- data.frame(alpha = alpha_grid, kappa = cond_vals)

p3c <- ggplot(df_cond, aes(x = alpha, y = kappa)) +
  geom_line(linewidth = 1.2, color = col_spot) +
  geom_point(data = data.frame(alpha = alpha_ill,
                               kappa = kappa(H_ill, exact = TRUE)),
             color = "red", size = 3) +
  annotate("text", x = alpha_ill + 0.02, 
           y = kappa(H_ill, exact = TRUE) * 1.1,
           label = bquote(alpha^"*" ~ "≈ 0.128"), color = "red", size = 3.5) +
  labs(title = expression(paste("Numero di condizionamento ", kappa[2](bold(H)),
                                " vs ", alpha)),
       subtitle = "Alpha piccolo → colonne di H quasi proporzionali → malcondizionamento",
       x = expression(alpha), y = expression(kappa[2](bold(H)))) +
  theme_dispensa
save_fig("fig03c_condizionamento_vs_alpha", p3c)


# ==============================================================================
# SEZ. 4 — BISEZIONE PER alpha*
# ==============================================================================

cat("\n=== SEZ. 4: BISEZIONE PER alpha* ===\n")

# Funzione g(alpha) = f(0, CP; alpha) - UFR_c
# Criterio: |g(alpha*)| <= 1 bp = 1e-4
g_alpha <- function(alpha, maturities, par_rates, ufr, cp) {
  cal <- sw_calibrate(maturities, par_rates, ufr, alpha)
  fwd_cp <- sw_forward(cp, maturities, cal$zeta, ufr, alpha)
  fwd_cp - ufr
}

# Bisezione con tracciamento delle iterazioni
find_alpha_traced <- function(maturities, par_rates, ufr, llp,
                              tol_fwd = 1e-4, tol_alpha = 1e-6, n_max = 60) {
  cp <- max(llp + 40, 60)
  a <- 0.05
  b <- 1.0
  trace <- data.frame(iter = integer(), a = numeric(), b = numeric(),
                      mid = numeric(), g_mid = numeric(), width = numeric())
  
  for (k in seq_len(n_max)) {
    am <- 0.5 * (a + b)
    g_val <- g_alpha(am, maturities, par_rates, ufr, cp)
    trace <- rbind(trace, data.frame(iter = k, a = a, b = b,
                                     mid = am, g_mid = g_val, width = b - a))
    
    if (abs(g_val) <= tol_fwd) {
      b <- am  # soddisfatto: cercare più piccolo
    } else {
      a <- am  # non soddisfatto
    }
    
    if ((b - a) < tol_alpha) break
  }
  
  list(alpha_star = b, trace = trace, n_iter = nrow(trace))
}

# Esecuzione bisezione
cat("  Bisezione su [0.05, 1.0] con tol_alpha = 1e-6...\n")
bis_result <- find_alpha_traced(T_mkt, r_mkt, UFR_c, LLP)
alpha_star <- bis_result$alpha_star
n_iter     <- bis_result$n_iter
trace_df   <- bis_result$trace

cat(sprintf("  alpha* = %.6f\n", alpha_star))
cat(sprintf("  Iterazioni: %d\n", n_iter))
cat(sprintf("  Stima teorica: ceil(log2(0.95 / 1e-6)) = %d\n",
            ceiling(log2(0.95 / 1e-6))))

# --- Grafico: convergenza bisezione (ampiezza intervallo) ---
p4a <- ggplot(trace_df, aes(x = iter, y = width)) +
  geom_line(linewidth = 1, color = col_spot) +
  geom_point(size = 1.5, color = col_spot) +
  geom_hline(yintercept = 1e-6, linetype = "dashed", color = "red") +
  annotate("text", x = n_iter * 0.7, y = 3e-6, 
           label = expression(epsilon[alpha] == 10^{-6}),
           color = "red", size = 3.5) +
  scale_y_log10() +
  labs(title = expression(paste("Convergenza della bisezione per ", alpha^"*")),
       subtitle = sprintf("Intervallo [0.05, 1.0] → α* = %.6f in %d iterazioni",
                          alpha_star, n_iter),
       x = "Iterazione", y = "Ampiezza intervallo (b - a)") +
  theme_dispensa
save_fig("fig04a_bisezione_convergenza", p4a)

# --- Grafico: funzione g(alpha) ---
alpha_g_grid <- seq(0.05, 0.50, length.out = 80)
g_vals <- sapply(alpha_g_grid, function(a) {
  g_alpha(a, T_mkt, r_mkt, UFR_c, CP)
})

df_g <- data.frame(alpha = alpha_g_grid, g = g_vals * 1e4)  # in bps

p4b <- ggplot(df_g, aes(x = alpha, y = g)) +
  geom_line(linewidth = 1.2, color = col_fwd) +
  geom_hline(yintercept = c(-1, 1), linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = 0, linewidth = 0.4) +
  geom_vline(xintercept = alpha_star, linetype = "dotted", color = col_ufr) +
  annotate("text", x = alpha_star + 0.02, y = max(df_g$g) * 0.8,
           label = bquote(alpha^"*" == .(sprintf("%.4f", alpha_star))),
           color = col_ufr, size = 3.5) +
  annotate("rect", xmin = 0.05, xmax = 0.50, ymin = -1, ymax = 1,
           fill = "green", alpha = 0.08) +
  labs(title = expression(paste("Funzione ", g(alpha) == f(0, CP, alpha) - UFR[c],
                                " — criterio EIOPA")),
       subtitle = "Zona verde: |g| ≤ 1 bp (criterio soddisfatto). α* è il minimo α nella zona.",
       x = expression(alpha), y = expression(g(alpha) ~ " (bps)")) +
  theme_dispensa
save_fig("fig04b_funzione_g_alpha", p4b)


# ==============================================================================
# SEZ. 5 — CURVA COMPLETA: spot, forward, convergenza
# ==============================================================================

cat("\n=== SEZ. 5: CURVA COMPLETA ===\n")

# Calibrazione con alpha*
cal_star <- sw_calibrate(T_mkt, r_mkt, UFR_c, alpha_star)
zeta_star <- cal_star$zeta

# Valutazione curva 1-150 anni
T_full <- seq(0.5, 150, by = 0.5)
P_full <- sapply(T_full, function(t) sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star))
r_spot <- -log(P_full) / T_full * 100
f_fwd  <- sapply(T_full, function(t) sw_forward(t, T_mkt, zeta_star, UFR_c, alpha_star)) * 100

# Tabella spot/forward per scadenze selezionate
cat("\n  Curva finale (alpha* = ", sprintf("%.6f", alpha_star), "):\n")
cat("    T(anni)    Spot(%)    Forward(%)\n")
cat("    ----------------------------------\n")
for (T in c(1, 2, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150)) {
  idx <- which.min(abs(T_full - T))
  cat(sprintf("    %6.0f   %8.4f    %8.4f\n", T, r_spot[idx], f_fwd[idx]))
}

# --- Grafico principale: curva spot e forward ---
df_curve <- data.frame(
  T = rep(T_full[T_full <= 100], 2),
  Tasso = c(r_spot[T_full <= 100], f_fwd[T_full <= 100]),
  Tipo = rep(c("Spot r(0,T)", "Forward f(0,T)"), each = sum(T_full <= 100))
)

# Spot rates ai nodi di mercato
spot_nodi <- sapply(T_mkt, function(t) {
  P <- sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star)
  -log(P) / t * 100
})

p5a <- ggplot(df_curve, aes(x = T, y = Tasso, color = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_vline(xintercept = CP, color = "gray60", linetype = "dotted", linewidth = 0.5) +
  geom_point(data = data.frame(T = T_mkt, Tasso = spot_nodi, Tipo = "Nodi mercato"),
             aes(x = T, y = Tasso), color = col_nodi, size = 2.2, shape = 16,
             inherit.aes = FALSE) +
  annotate("text", x = LLP + 1.5, y = min(df_curve$Tasso) + 0.05, label = "LLP",
           color = "gray40", size = 3) +
  annotate("text", x = CP + 1.5, y = min(df_curve$Tasso) + 0.05, label = "CP",
           color = "gray40", size = 3) +
  annotate("text", x = 85, y = UFR_ann * 100 + 0.06,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3.2) +
  scale_color_manual(values = c("Spot r(0,T)" = col_spot, "Forward f(0,T)" = col_fwd,
                                "Nodi mercato" = col_nodi)) +
  scale_linetype_manual(values = c("Spot r(0,T)" = "solid", "Forward f(0,T)" = "dashed",
                                   "Nodi mercato" = "solid")) +
  labs(title = "Curva EIOPA EUR — Smith-Wilson su swap par",
       subtitle = sprintf("α* = %.4f, LLP = %d anni, CP = %d anni, UFR = %.2f%%",
                          alpha_star, LLP, CP, UFR_ann * 100),
       x = "Scadenza T (anni)", y = "Tasso (%)",
       color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig05a_curva_spot_forward", p5a)

# --- Grafico: convergenza forward verso UFR ---
df_conv <- data.frame(T = T_full[T_full >= 20], fwd = f_fwd[T_full >= 20])
df_conv$distanza_bps <- (df_conv$fwd - UFR_c * 100) * 100  # in bps (centesimi di %)

p5b <- ggplot(df_conv, aes(x = T, y = abs(distanza_bps))) +
  geom_line(linewidth = 1, color = col_fwd) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  geom_vline(xintercept = CP, linetype = "dotted", color = "gray60") +
  annotate("text", x = CP + 2, y = 5, label = "CP = 60", color = "gray40", size = 3) +
  annotate("text", x = 120, y = 1.5, label = "1 bp", color = "red", size = 3) +
  scale_y_log10() +
  labs(title = expression(paste("|f(0,T) - ", UFR[c], "| — convergenza verso l'UFR")),
       subtitle = "Scala logaritmica. Al CP il forward è entro 1 bp dall'UFR per costruzione.",
       x = "Scadenza T (anni)", y = "|f(0,T) − UFR| (bps)") +
  theme_dispensa
save_fig("fig05b_convergenza_ufr", p5b)

# --- Grafico: fattori di sconto P(0,t) ---
df_discount <- data.frame(T = T_full[T_full <= 100],
                          P = P_full[T_full <= 100])

p5c <- ggplot(df_discount, aes(x = T, y = P)) +
  geom_line(linewidth = 1.1, color = col_spot) +
  geom_point(data = data.frame(T = T_mkt,
                               P = sapply(T_mkt, function(t) 
                                 sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star))),
             color = col_nodi, size = 2, shape = 16) +
  geom_line(data = data.frame(T = T_full[T_full <= 100],
                              P_asint = exp(-UFR_c * T_full[T_full <= 100])),
            aes(x = T, y = P_asint), linetype = "dotted", color = col_ufr, linewidth = 0.7) +
  labs(title = "Fattori di sconto P(0,T) — Smith-Wilson",
       subtitle = expression(paste("Tratto puntinato: ", e^{-UFR[c] * T},
                                   " (limite asintotico)")),
       x = "Scadenza T (anni)", y = "P(0,T)") +
  theme_dispensa
save_fig("fig05c_fattori_sconto", p5c)


# ==============================================================================
# SEZ. 5bis — INTERPOLAZIONE CLASSICA: FALLIMENTO IN ESTRAPOLAZIONE
# ==============================================================================
#
# Motivazione didattica (filo logico della dispensa):
# costruire la curva e' un problema di interpolazione + estrapolazione di una
# funzione nota solo in N nodi. I metodi classici interpolano bene ma NON sanno
# estrapolare verso un asintoto economico (l'UFR):
#   - polinomio globale di grado N-1: fenomeno di Runge, oscillazioni ai bordi
#     ed esplosione fuori dall'intervallo dei nodi;
#   - spline cubica naturale: interpola in modo regolare ma estrapola in modo
#     lineare, senza alcuna convergenza all'UFR;
#   - Smith-Wilson: converge strutturalmente all'UFR.
# ==============================================================================

cat("\n=== SEZ. 5bis: FALLIMENTO INTERPOLAZIONE CLASSICA ===\n")

# Spot rate ai nodi di mercato (dalla curva SW calibrata con alpha*)
spot_nodi_5bis <- sapply(T_mkt, function(t) {
  P <- sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star)
  -log(P) / t * 100
})

# Griglia di valutazione: interpolazione (1-20) + estrapolazione (20-60)
T_eval <- seq(1, 60, by = 0.25)

# (a) Interpolante polinomiale globale di grado N-1 = 11.
#     poly(..., raw = FALSE) usa una base ortogonale numericamente stabile;
#     predict() estende il polinomio anche fuori dall'intervallo dei nodi.
poly_model <- lm(spot_nodi_5bis ~ poly(T_mkt, degree = N - 1))
r_poly <- predict(poly_model, newdata = data.frame(T_mkt = T_eval))

# (b) Spline cubica naturale (estrapola linearmente oltre l'ultimo nodo)
spline_5bis <- splinefun(T_mkt, spot_nodi_5bis, method = "natural")
r_spline_5bis <- spline_5bis(T_eval)

# (c) Smith-Wilson (converge all'UFR)
r_sw_5bis <- sapply(T_eval, function(t) {
  P <- sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star)
  -log(P) / t * 100
})

df_fail <- rbind(
  data.frame(T = T_eval, Tasso = r_poly,        Metodo = "Polinomio globale (grado 11)"),
  data.frame(T = T_eval, Tasso = r_spline_5bis, Metodo = "Spline cubica naturale"),
  data.frame(T = T_eval, Tasso = r_sw_5bis,     Metodo = "Smith-Wilson (EIOPA)")
)
df_fail$Metodo <- factor(df_fail$Metodo,
  levels = c("Polinomio globale (grado 11)", "Spline cubica naturale",
             "Smith-Wilson (EIOPA)"))

col_poly <- "#C0392B"  # rosso acceso — polinomio (Runge)

p5bis <- ggplot(df_fail, aes(x = T, y = Tasso, color = Metodo, linetype = Metodo)) +
  # regione di estrapolazione (oltre il LLP) evidenziata
  annotate("rect", xmin = LLP, xmax = 60, ymin = -Inf, ymax = Inf,
           fill = "gray85", alpha = 0.35) +
  annotate("text", x = (LLP + 60) / 2, y = 5.4,
           label = "Estrapolazione (T > LLP)", color = "gray40", size = 3.3) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr,
             linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = LLP, color = "gray50", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = data.frame(T = T_mkt, Tasso = spot_nodi_5bis),
             aes(x = T, y = Tasso), color = col_nodi, size = 2.2, shape = 16,
             inherit.aes = FALSE) +
  annotate("text", x = 50, y = UFR_ann * 100 + 0.12,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3.2) +
  scale_color_manual(values = c(
    "Polinomio globale (grado 11)" = col_poly,
    "Spline cubica naturale"       = col_spline,
    "Smith-Wilson (EIOPA)"         = col_spot)) +
  scale_linetype_manual(values = c(
    "Polinomio globale (grado 11)" = "solid",
    "Spline cubica naturale"       = "dashed",
    "Smith-Wilson (EIOPA)"         = "solid")) +
  coord_cartesian(ylim = c(1.5, 5.5)) +
  labs(title = "Interpolazione classica e fallimento in estrapolazione",
       subtitle = paste0("Il polinomio globale oscilla (Runge) ed esplode oltre i nodi; ",
                         "la spline estrapola lineare; solo SW converge all'UFR"),
       x = "Scadenza T (anni)", y = "Spot rate (%)",
       color = NULL, linetype = NULL) +
  scale_x_continuous(breaks = c(T_mkt, 30, 40, 50, 60)) +
  theme_dispensa
save_fig("fig00_interpolazione_fallimento", p5bis)


# ==============================================================================
# SEZ. 6 — CONFRONTO SPLINE CUBICHE vs SMITH-WILSON
# ==============================================================================

cat("\n=== SEZ. 6: CONFRONTO SPLINE vs SW ===\n")

# Interpolazione spline cubica naturale sugli spot ai nodi
spot_at_nodes <- sapply(T_mkt, function(t) {
  P <- sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star)
  -log(P) / t * 100
})

# Spline cubica naturale (per confronto)
spline_fit <- splinefun(T_mkt, spot_at_nodes, method = "natural")
T_spline <- seq(1, 60, by = 0.25)
r_spline <- spline_fit(T_spline)

# SW spot sugli stessi punti
r_sw_compare <- sapply(T_spline, function(t) {
  P <- sw_discount(t, T_mkt, zeta_star, UFR_c, alpha_star)
  -log(P) / t * 100
})

df_compare <- data.frame(
  T = rep(T_spline, 2),
  Tasso = c(r_spline, r_sw_compare),
  Metodo = rep(c("Spline cubica naturale", "Smith-Wilson (EIOPA)"), each = length(T_spline))
)

p6 <- ggplot(df_compare, aes(x = T, y = Tasso, color = Metodo, linetype = Metodo)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted") +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = data.frame(T = T_mkt, Tasso = spot_at_nodes),
             aes(x = T, y = Tasso), color = col_nodi, size = 2, shape = 16,
             inherit.aes = FALSE) +
  annotate("text", x = 55, y = UFR_ann * 100 + 0.08,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3) +
  scale_color_manual(values = c("Spline cubica naturale" = col_spline,
                                "Smith-Wilson (EIOPA)" = col_spot)) +
  scale_linetype_manual(values = c("Spline cubica naturale" = "dashed",
                                   "Smith-Wilson (EIOPA)" = "solid")) +
  labs(title = "Confronto interpolazione: spline cubica vs Smith-Wilson",
       subtitle = "Oltre il LLP=20a la spline estrapolizza linearmente, SW converge all'UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)",
       color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig06_confronto_spline_sw", p6)


# ==============================================================================
# SEZ. 7 — ANALISI DI SENSITIVITÀ
# ==============================================================================

cat("\n=== SEZ. 7: SENSITIVITÀ ===\n")

# --- 7a: Sensitività a UFR ---
UFR_grid <- c(0.0315, 0.0330, 0.0345)
df_sens_ufr <- do.call(rbind, lapply(UFR_grid, function(ufr_a) {
  ufr_cont <- log(1 + ufr_a)
  a_star <- find_alpha_traced(T_mkt, r_mkt, ufr_cont, LLP)$alpha_star
  cal_tmp <- sw_calibrate(T_mkt, r_mkt, ufr_cont, a_star)
  T_plt <- seq(1, 100, by = 0.5)
  spot_tmp <- sapply(T_plt, function(t) {
    P <- sw_discount(t, T_mkt, cal_tmp$zeta, ufr_cont, a_star)
    -log(P) / t * 100
  })
  data.frame(T = T_plt, Spot = spot_tmp,
             UFR = sprintf("UFR = %.2f%%", ufr_a * 100))
}))

p7a <- ggplot(df_sens_ufr, aes(x = T, y = Spot, color = UFR)) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  labs(title = "Sensitività della curva spot all'UFR",
       subtitle = "Le curve divergono oltre il LLP; il tasso asintotico è determinato dall'UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)",
       color = NULL) +
  theme_dispensa
save_fig("fig07a_sensitivita_ufr", p7a)

# --- 7b: Sensitività ad alpha (a UFR fisso) ---
alpha_sens <- c(alpha_star - 0.03, alpha_star, alpha_star + 0.03)
df_sens_alpha <- do.call(rbind, lapply(alpha_sens, function(a) {
  cal_tmp <- sw_calibrate(T_mkt, r_mkt, UFR_c, a)
  T_plt <- seq(1, 100, by = 0.5)
  fwd_tmp <- sapply(T_plt, function(t) {
    sw_forward(t, T_mkt, cal_tmp$zeta, UFR_c, a)
  }) * 100
  data.frame(T = T_plt, Forward = fwd_tmp,
             Alpha = sprintf("α = %.3f", a))
}))

p7b <- ggplot(df_sens_alpha, aes(x = T, y = Forward, color = Alpha)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted") +
  geom_vline(xintercept = LLP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_vline(xintercept = CP, color = "gray60", linetype = "dotted", linewidth = 0.5) +
  labs(title = expression(paste("Sensitività del forward a ", alpha, " (UFR fisso)")),
       subtitle = "Alpha più grande → convergenza più rapida verso l'UFR",
       x = "Scadenza T (anni)", y = "Forward rate (%)",
       color = NULL) +
  theme_dispensa
save_fig("fig07b_sensitivita_alpha", p7b)

# ==============================================================================
# FINE — Riepilogo file generati
# ==============================================================================

cat("\n====================================================================\n")
cat("  GRAFICI GENERATI in:", dir_out, "\n")
cat("====================================================================\n")
files_out <- list.files(dir_out, pattern = "\\.pdf$")
for (f in files_out) cat("  •", f, "\n")
cat("\n")
