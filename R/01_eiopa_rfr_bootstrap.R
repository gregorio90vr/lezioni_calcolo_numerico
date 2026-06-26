# ==============================================================================
#  CURVA EIOPA RISK-FREE RATE — Bootstrap (constant forward) + Estrapolazione FSP/LLFR
#  Laboratorio di Calcolo Numerico, UniVR — A.A. 2026/2027
#
#  Questo script riproduce tutti i risultati e le figure della dispensa
#  "Costruzione della Curva EIOPA Risk-Free Rate".
#
#  Riferimento: EIOPA-BoS-26-198 (RFR Technical Documentation, Maggio 2026)
#               che recepisce gli emendamenti a Solvency II
#               (Direttiva (UE) 2025/2, Reg. Delegato (UE) 2026/269).
#
#  METODO ATTUALE (NON più Smith-Wilson):
#    - Interpolazione : ipotesi "constant forward" + BOOTSTRAP (Annex D)
#    - Estrapolazione : First Smoothing Point (FSP), Last Liquid Forward Rate
#                       (LLFR) e convergenza all'UFR con peso B(a,h)  (sez. 8.5)
#    - alpha (convergenza) : parametro REGOLAMENTARE FISSO (no calibrazione)
#
#  Nucleo numerico del corso:
#    - Bootstrap sequenziale (tenor consecutivi -> lineare;
#                             tenor con "buchi" -> equazione NON lineare)
#    - Ricerca di zeri: NEWTON-RAPHSON (con derivata analitica, Annex D.6)
#                       confrontato con la BISEZIONE
#
#  Output: figure PDF in ../output/01_eiopa_rfr_bootstrap
#
#  Struttura:
#    Sez. 0  — Setup e parametri EIOPA EUR
#    Sez. 1  — Dati input: par OIS €STR (ticker EESWE*) e CRA
#    Sez. 2  — Bootstrap: Step 1, tenor consecutivi (lineare) e con buchi (NR)
#    Sez. 3  — Newton-Raphson vs Bisezione sull'equazione del bootstrap
#    Sez. 4  — FSP, LLFR ed estrapolazione (peso B(a,h), convergenza a UFR)
#    Sez. 5  — Curva completa: spot, forward, convergenza
#    Sez. 6  — Sensitività (alpha, UFR)
#    Sez. 7  — Confronto con interpolazione/estrapolazione alternativa (spline)
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

# Cartella output grafici
dir_out <- file.path(dirname(getwd()), "output", "01_eiopa_rfr_bootstrap")
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
col_llfr    <- "#2ca02c"   # verde — LLFR
col_nodi    <- "black"     # nodi di mercato
col_nr      <- "#185FA5"   # Newton-Raphson
col_bis     <- "#E07020"   # Bisezione
col_obs     <- "#B2182B"   # tenor osservati
col_interp  <- "#2166AC"   # tenor interpolati

# Helper: salva figura PDF
save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", path)
}

cat("\n====================================================================\n")
cat("  CURVA EIOPA EUR — Bootstrap + FSP/LLFR (EIOPA-BoS-26-198)\n")
cat("====================================================================\n\n")

# ==============================================================================
# PARAMETRI EIOPA EUR (sez. 8.1, 8.2, 8.4; Annex C)
# ==============================================================================

UFR_ann <- 0.0330                   # UFR annuo composto (EUR), Annex C
UFR_c   <- log(1 + UFR_ann)         # UFR in intensità continua ~ 3.2466%
FSP     <- 20                       # First Smoothing Point EUR (anni), sez. 8.2
CRA     <- 0.0010                   # Credit Risk Adjustment = 10 bps (sez. 6)
m1      <- 1                        # frequenza cedolare OIS €STR (annuale)

# Parametro di convergenza alpha (sez. 8.1.5): FISSO per legge.
#   target a regime = 11% (40% per SEK); meccanismo di phasing-in (Table 4):
#   2027:20%  2028:18.2%  2029:16.4%  2030:14.6%  2031:12.8%  2032:11%
phasing_alpha <- c("2027"=0.200, "2028"=0.182, "2029"=0.164,
                   "2030"=0.146, "2031"=0.128, "2032"=0.110)
alpha <- phasing_alpha["2027"]      # valore di esempio (primo anno di applicazione)
alpha <- as.numeric(alpha)

cat(sprintf("UFR annuo:    %.2f%%\n", UFR_ann * 100))
cat(sprintf("UFR continuo: %.4f%%\n", UFR_c * 100))
cat(sprintf("FSP = %d anni,  CRA = %d bps,  alpha = %.1f%% (phasing-in 2027)\n\n",
            FSP, CRA * 1e4, alpha * 100))

# ==============================================================================
# SEZ. 1 — DATI DI INPUT: par OIS €STR (ticker Bloomberg EESWE*)
# ==============================================================================
#
# ORIGINE DEI DATI
# ================
# I tassi par OIS (Overnight Index Swap) su €STR sono pubblicati quotidianamente
# da Bloomberg con i ticker EESWE<tenor> Curncy (es. EESWE10 Curncy = 10Y).
# Il file dati/01_eeswe.xlsx contiene la serie storica mensile per le 12 scadenze
# DLT (deep, liquid, transparent) dell'EUR. Qui usiamo la data di valutazione
# del 29/05/2026 (ultimo giorno lavorativo del mese).
#
# Scadenze DLT per EUR (in anni): 1,2,3,4,5,6,7,8,10,12,15,20.
# Le scadenze 9,11,13,14,16-19 non sono osservate (non DLT): vengono ricostruite
# per bootstrap sotto l'ipotesi di "constant forward".
# ==============================================================================

cat("=== SEZ. 1: DATI INPUT (par OIS €STR, ticker EESWE*) ===\n")

T_mkt <- c(1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20)

# Fallback (riga 29/05/2026 del file dati/01_eeswe.xlsx), par rate LORDI in %:
s_fallback <- c(2.39325, 2.43045, 2.43680, 2.46935, 2.50100, 2.54500,
                2.59700, 2.65030, 2.75150, 2.84600, 2.95800, 3.04400) / 100

# Lettura da dati/01_eeswe.xlsx (se disponibile), altrimenti fallback.
read_eswe <- function() {
  f <- file.path(dirname(getwd()), "dati", "01_eeswe.xlsx")
  if (!have_openxlsx || !file.exists(f)) return(NULL)
  out <- tryCatch({
    df <- openxlsx::read.xlsx(f, sheet = 1, startRow = 2, detectDates = TRUE)
    # prima colonna = date; colonne EESWE* in ordine di T_mkt
    dcol <- df[[1]]
    dates <- suppressWarnings(as.Date(dcol))
    if (all(is.na(dates))) dates <- as.Date(dcol, origin = "1899-12-30")
    idx <- which(format(dates, "%Y-%m-%d") == "2026-05-29")
    if (length(idx) == 0) idx <- nrow(df)        # ultima riga disponibile
    vals <- as.numeric(df[idx[1], -1])
    vals <- vals[!is.na(vals)]
    if (length(vals) != length(T_mkt)) return(NULL)
    vals / 100
  }, error = function(e) NULL)
  out
}

s_mkt <- read_eswe()
if (is.null(s_mkt)) {
  s_mkt <- s_fallback
  cat("  (uso valori di fallback hardcoded per il 29/05/2026)\n")
} else {
  cat("  (letti da dati/01_eeswe.xlsx, data 29/05/2026)\n")
}

# After-CRA (sez. 6: sottrazione del CRA dai tassi di input)
r_mkt <- s_mkt - CRA

N <- length(T_mkt)

cat("\n  Scadenza   OIS_par(%)   After-CRA(%)   DLT\n")
cat("  ---------------------------------------------\n")
for (i in seq_along(T_mkt)) {
  cat(sprintf("  %4d Y     %7.4f      %7.4f      *\n",
              T_mkt[i], s_mkt[i]*100, r_mkt[i]*100))
}
cat("\n")

# --- Grafico fig01: par OIS e after-CRA ---
df_input <- data.frame(
  Scadenza = rep(T_mkt, 2),
  Tasso    = c(s_mkt * 100, r_mkt * 100),
  Tipo     = rep(c("OIS par €STR (lordo)", "After-CRA (input bootstrap)"), each = N)
)
p1 <- ggplot(df_input, aes(x = Scadenza, y = Tasso, color = Tipo, shape = Tipo)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_color_manual(values = c("OIS par €STR (lordo)" = col_spot,
                                "After-CRA (input bootstrap)" = col_fwd)) +
  labs(title = "Tassi OIS €STR par — EUR 29/05/2026 (ticker Bloomberg EESWE*)",
       subtitle = sprintf("CRA = %d bps sottratto prima del bootstrap (sez. 6 EIOPA-BoS-26-198)",
                          CRA * 1e4),
       x = "Scadenza (anni)", y = "Tasso (%)", color = NULL, shape = NULL) +
  theme_dispensa +
  scale_x_continuous(breaks = T_mkt)
save_fig("fig01_input_par_estr", p1)


# ==============================================================================
# SEZ. 2 — BOOTSTRAP (Annex D): constant forward + ricerca di zeri
# ==============================================================================
#
# Condizione par di un OIS (cedola annuale, m1 = 1) a scadenza T_k:
#     s_k * sum_{j=1}^{T_k} d_j + d_{T_k} = 1                       (Annex D.3.5)
# con d_j = fattore di sconto a j anni (incognito).
#
# Ipotesi "constant forward": tra due tenor DLT non consecutivi il forward
# istantaneo è costante, quindi d_{t_k+i} = d_{t_k} * (1+f)^{-i}    (Annex D.5).
# ==============================================================================

cat("=== SEZ. 2: BOOTSTRAP (constant forward) ===\n")

# --- Equazione del bootstrap per un tenor con "buco" (Annex D.6.1) ----------
#  g(f) = s2*(1-d*)/f + d* + (s2-s1)/s1 * (1-d_tk)/d_tk - 1,   d*=(1+f)^{-gap}
#  (forma equivalente alla condizione par diretta; vedi dispensa)
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

# Newton-Raphson (Annex D.6.3-D.6.5), con tracciamento delle iterazioni
nr_solve <- function(s2, s1, d_tk, gap, f0, tol = 1e-15, nmax = 50) {
  f <- f0; tr <- data.frame(iter = 0, f = f0, g = g_boot(f0, s2, s1, d_tk, gap))
  for (k in seq_len(nmax)) {
    gv <- g_boot(f, s2, s1, d_tk, gap)
    if (abs(gv) < tol) break
    f <- f - gv / gp_boot(f, s2, s1, d_tk, gap)
    tr <- rbind(tr, data.frame(iter = k, f = f, g = g_boot(f, s2, s1, d_tk, gap)))
  }
  list(f = f, trace = tr, n_iter = nrow(tr) - 1)
}

# Bisezione sulla stessa equazione (metodo robusto di confronto)
bis_solve <- function(s2, s1, d_tk, gap, lo = 1e-6, hi = 1.0,
                      tol = 1e-15, nmax = 200) {
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

# --- Bootstrap completo: restituisce d_t e z_t (annuali, discreti) per t=1..FSP
bootstrap_curve <- function(T_mkt, r_mkt, FSP, solver = "newton") {
  Nloc <- length(T_mkt)
  Tmax <- FSP
  d <- rep(NA_real_, Tmax)           # fattori di sconto d_1..d_FSP
  is_obs <- rep(FALSE, Tmax)         # tenor osservato (DLT) ?
  is_obs[T_mkt[T_mkt <= Tmax]] <- TRUE

  # Step 1 (Annex D.4): primo tenor t1 = 1  ->  d_1 = 1/(1+r_1)
  d[1] <- 1 / (1 + r_mkt[1])

  # Step 2 (Annex D.5): scorri i tenor osservati in ordine
  for (k in 2:Nloc) {
    t_prev <- T_mkt[k - 1]; t_cur <- T_mkt[k]
    if (t_cur > Tmax) break
    gap <- t_cur - t_prev
    Sprev <- sum(d[1:t_prev])        # somma annualità note fino a t_prev

    if (gap == 1) {
      # tenor CONSECUTIVO -> equazione LINEARE in d_{t_cur}
      d[t_cur] <- (1 - r_mkt[k] * Sprev) / (1 + r_mkt[k])
    } else {
      # tenor con BUCO -> ipotesi constant forward, equazione NON lineare in f
      f0 <- d[t_prev - 1] / d[t_prev] - 1          # start: ultimo forward 1y
      if (solver == "newton") {
        f_star <- nr_solve(r_mkt[k], r_mkt[k - 1], d[t_prev], gap, f0)$f
      } else {
        f_star <- bis_solve(r_mkt[k], r_mkt[k - 1], d[t_prev], gap)$f
      }
      for (i in 1:gap) d[t_prev + i] <- d[t_prev] * (1 + f_star)^(-i)
    }
  }

  z <- d^(-1 / seq_len(Tmax)) - 1     # zero rate annuale discreto: d_t=(1+z_t)^{-t}
  list(t = seq_len(Tmax), d = d, z = z, is_obs = is_obs)
}

bc <- bootstrap_curve(T_mkt, r_mkt, FSP, solver = "newton")

# --- Verifica: i fattori di sconto replicano i par swap osservati? ---
cat("\n  Verifica bootstrap (valore par swap osservato = 1):\n")
max_err <- 0
for (i in seq_along(T_mkt)) {
  Ti <- T_mkt[i]; ri <- r_mkt[i]
  val <- ri * sum(bc$d[1:Ti]) + bc$d[Ti]
  max_err <- max(max_err, abs(val - 1))
  cat(sprintf("    T=%2d: valore = %.12f  (errore = %.2e)\n", Ti, val, abs(val - 1)))
}
cat(sprintf("  -> errore massimo di re-pricing = %.2e\n\n", max_err))

# --- Grafico fig02: curva zero bootstrap (osservati vs interpolati) ---
df_zero <- data.frame(
  t = bc$t, z = bc$z * 100,
  Tipo = ifelse(bc$is_obs, "Tenor osservato (DLT)", "Tenor interpolato (bootstrap)")
)
p2 <- ggplot(df_zero, aes(x = t, y = z)) +
  geom_line(color = col_interp, linewidth = 1) +
  geom_point(aes(color = Tipo, shape = Tipo), size = 2.6) +
  scale_color_manual(values = c("Tenor osservato (DLT)" = col_obs,
                                "Tenor interpolato (bootstrap)" = col_interp)) +
  scale_shape_manual(values = c("Tenor osservato (DLT)" = 16,
                                "Tenor interpolato (bootstrap)" = 1)) +
  labs(title = "Curva zero ricostruita per bootstrap (parte interpolata, 1–20 anni)",
       subtitle = "I tenor non DLT (9,11,13,14,16–19) sono ricavati con l'ipotesi constant forward",
       x = "Scadenza t (anni)", y = "Zero rate annuale (%)",
       color = NULL, shape = NULL) +
  theme_dispensa +
  scale_x_continuous(breaks = bc$t)
save_fig("fig02_bootstrap_zero", p2)

# --- Grafico fig03: forward 1y constant-forward (step) ---
fwd_1y <- numeric(FSP)
fwd_1y[1] <- 1 / bc$d[1] - 1
for (t in 2:FSP) fwd_1y[t] <- bc$d[t - 1] / bc$d[t] - 1
df_fwd1 <- data.frame(t = seq_len(FSP), f = fwd_1y * 100,
                      is_obs = bc$is_obs)
p3 <- ggplot(df_fwd1, aes(x = t, y = f)) +
  geom_step(direction = "vh", color = col_fwd, linewidth = 1) +
  geom_point(aes(color = ifelse(is_obs, "osservato", "interpolato")), size = 2.4) +
  scale_color_manual(values = c("osservato" = col_obs, "interpolato" = col_interp),
                     name = NULL) +
  labs(title = "Forward annuali f(t-1,t) e ipotesi constant forward",
       subtitle = "Nei tratti tra tenor non consecutivi il forward è costante (per costruzione)",
       x = "Scadenza t (anni)", y = "Forward annuale f(t-1,t) (%)") +
  theme_dispensa +
  scale_x_continuous(breaks = seq_len(FSP))
save_fig("fig03_constant_forward", p3)


# ==============================================================================
# SEZ. 3 — NEWTON-RAPHSON vs BISEZIONE sull'equazione del bootstrap
# ==============================================================================
#
# Caso di studio: l'ultimo "buco" 15Y -> 20Y (gap = 5 anni), il più ampio.
# ==============================================================================

cat("=== SEZ. 3: NEWTON-RAPHSON vs BISEZIONE (buco 15->20) ===\n")

# Ricostruisco d fino a 15 (per avere d_tk=d_15 e lo start f0)
bc15 <- bootstrap_curve(T_mkt[T_mkt <= 15], r_mkt[T_mkt <= 15], 15, solver = "newton")
k20  <- which(T_mkt == 20); k15 <- which(T_mkt == 15)
s2 <- r_mkt[k20]; s1 <- r_mkt[k15]; d_tk <- bc15$d[15]; gap <- 5
f0 <- bc15$d[14] / bc15$d[15] - 1

nr  <- nr_solve(s2, s1, d_tk, gap, f0)
bis <- bis_solve(s2, s1, d_tk, gap)

cat(sprintf("  f* (Newton)   = %.12f   in %d iterazioni\n", nr$f,  nr$n_iter))
cat(sprintf("  f* (Bisezione)= %.12f   in %d iterazioni\n", bis$f, bis$n_iter))
cat(sprintf("  |f_NR - f_bis| = %.2e\n\n", abs(nr$f - bis$f)))

# --- Grafico fig04a: la funzione g(f) ---
f_grid <- seq(max(1e-4, f0 - 0.03), f0 + 0.04, length.out = 400)
df_g <- data.frame(f = f_grid * 100,
                   g = sapply(f_grid, function(x) g_boot(x, s2, s1, d_tk, gap)))
p4a <- ggplot(df_g, aes(x = f, y = g)) +
  geom_line(color = col_fwd, linewidth = 1.1) +
  geom_hline(yintercept = 0, linewidth = 0.4) +
  geom_vline(xintercept = nr$f * 100, linetype = "dotted", color = col_ufr) +
  annotate("text", x = nr$f * 100, y = max(df_g$g) * 0.7,
           label = sprintf("f* = %.4f%%", nr$f * 100),
           color = col_ufr, size = 3.5, hjust = -0.1) +
  labs(title = "Equazione del bootstrap g(f) — buco 15Y -> 20Y",
       subtitle = "Lo zero di g(f) è il forward costante che riprezza il par swap a 20 anni",
       x = "Forward f (%)", y = "g(f)") +
  theme_dispensa
save_fig("fig04a_g_function", p4a)

# --- Grafico fig04b: convergenza NR vs Bisezione ---
err_nr  <- abs(nr$trace$f  - nr$f)
err_bis <- abs(bis$trace$f - nr$f)
df_conv <- rbind(
  data.frame(iter = nr$trace$iter,  err = err_nr,  Metodo = "Newton-Raphson"),
  data.frame(iter = bis$trace$iter, err = err_bis, Metodo = "Bisezione")
)
df_conv <- df_conv[df_conv$err > 0, ]
p4b <- ggplot(df_conv, aes(x = iter, y = err, color = Metodo, shape = Metodo)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  scale_y_log10() +
  scale_color_manual(values = c("Newton-Raphson" = col_nr, "Bisezione" = col_bis)) +
  labs(title = "Convergenza: Newton-Raphson (quadratica) vs Bisezione (lineare)",
       subtitle = sprintf("Newton: %d iter; Bisezione: %d iter (stessa tolleranza)",
                          nr$n_iter, bis$n_iter),
       x = "Iterazione", y = expression(group("|", f[k] - f^"*", "|")),
       color = NULL, shape = NULL) +
  theme_dispensa
save_fig("fig04b_newton_vs_bisezione", p4b)


# ==============================================================================
# SEZ. 4 — FSP, LLFR ed ESTRAPOLAZIONE (sez. 8.2-8.5)
# ==============================================================================

cat("=== SEZ. 4: FSP, LLFR, ESTRAPOLAZIONE ===\n")

# Zero rate CONTINUI dai discreti: z^c_t = ln(1 + z_t)
zc <- log(1 + bc$z)

# LLFR (sez. 8.5.6): FSP=20 è l'ultimo tenor DLT (L=F) => LLFR^c = f^c_{19,20}
#   forward continuo annuale: f^c_{t-1,t} = t*z^c_t - (t-1)*z^c_{t-1}
LLFR_c <- FSP * zc[FSP] - (FSP - 1) * zc[FSP - 1]
cat(sprintf("  FSP    = %d anni\n", FSP))
cat(sprintf("  z^c(FSP) = %.4f%%   (zero continuo a 20 anni)\n", zc[FSP] * 100))
cat(sprintf("  LLFR^c = %.4f%%   (= f^c_{19,20})\n", LLFR_c * 100))
cat(sprintf("  UFR^c  = %.4f%%\n\n", UFR_c * 100))

# Peso di convergenza (sez. 8.5.5):  B(a,h) = (1 - e^{-a h})/(a h)
B_weight <- function(a, h) ifelse(h == 0, 1, (1 - exp(-a * h)) / (a * h))

# Estrapolazione: per h = 1..(150-FSP)
extrapolate <- function(a) {
  h  <- 1:(150 - FSP)
  fc <- UFR_c + (LLFR_c - UFR_c) * B_weight(a, h)          # sez. 8.5.5
  zc_ext <- (FSP * zc[FSP] + h * fc) / (FSP + h)           # sez. 8.5.7
  z_ext  <- exp(zc_ext) - 1                                # sez. 8.5.8
  data.frame(t = FSP + h, zc = zc_ext, z = z_ext, fc = fc)
}
ext <- extrapolate(alpha)

# --- Grafico fig05: funzione peso B(a,h) per diversi alpha ---
hh <- seq(0, 130, length.out = 400)
df_B <- do.call(rbind, lapply(c(0.110, alpha, 0.40), function(a) {
  data.frame(h = hh, B = B_weight(a, hh),
             alpha = sprintf("a = %.1f%%", a * 100))
}))
p5 <- ggplot(df_B, aes(x = h, y = B, color = alpha)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = c(0, 1), linetype = "dashed", color = "gray60") +
  labs(title = expression(paste("Peso di convergenza ", B(a, h) == (1 - e^{-a*h})/(a*h))),
       subtitle = "B(a,0)=1 (forward = LLFR all'FSP); B(a,h)->0 (forward -> UFR). a piu' grande = convergenza piu' rapida",
       x = "Orizzonte h oltre l'FSP (anni)", y = "B(a,h)", color = expression(alpha)) +
  theme_dispensa
save_fig("fig05_peso_Bah", p5)


# ==============================================================================
# SEZ. 5 — CURVA COMPLETA: spot e forward, convergenza all'UFR
# ==============================================================================

cat("=== SEZ. 5: CURVA COMPLETA ===\n")

# Unione: parte bootstrap (1..FSP) + parte estrapolata (FSP+1..150)
t_all  <- c(bc$t, ext$t)
z_all  <- c(bc$z, ext$z)
zc_all <- c(zc,  ext$zc)
# forward continuo annuale su tutta la curva
fc_all <- numeric(length(t_all))
fc_all[1] <- zc_all[1]
for (i in 2:length(t_all))
  fc_all[i] <- t_all[i] * zc_all[i] - t_all[i - 1] * zc_all[i - 1]

cat("\n  Curva finale (alpha = ", sprintf("%.1f%%", alpha*100), "):\n")
cat("    T(anni)   Spot(%)   Forward(%)\n")
cat("    --------------------------------\n")
for (T in c(1, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150)) {
  idx <- which(t_all == T)
  cat(sprintf("    %6d  %8.4f   %8.4f\n", T, z_all[idx]*100, (exp(fc_all[idx])-1)*100))
}
cat("\n")

# --- Grafico fig06: curva spot e forward 1..150 ---
df_curve <- rbind(
  data.frame(T = t_all, Tasso = z_all * 100,        Tipo = "Spot z(0,T)"),
  data.frame(T = t_all, Tasso = (exp(fc_all)-1)*100, Tipo = "Forward f(0,T)")
)
spot_nodi <- data.frame(T = bc$t[bc$is_obs], Tasso = bc$z[bc$is_obs] * 100)
p6 <- ggplot(df_curve, aes(x = T, y = Tasso, color = Tipo, linetype = Tipo)) +
  geom_line(linewidth = 1.1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = FSP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = spot_nodi, aes(x = T, y = Tasso), color = col_nodi,
             size = 2.1, shape = 16, inherit.aes = FALSE) +
  annotate("text", x = FSP + 2, y = min(df_curve$Tasso) + 0.05, label = "FSP",
           color = "gray40", size = 3) +
  annotate("text", x = 110, y = UFR_ann * 100 + 0.06,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3.2) +
  scale_color_manual(values = c("Spot z(0,T)" = col_spot, "Forward f(0,T)" = col_fwd)) +
  scale_linetype_manual(values = c("Spot z(0,T)" = "solid", "Forward f(0,T)" = "dashed")) +
  labs(title = "Curva EIOPA EUR — bootstrap (≤FSP) + estrapolazione FSP/LLFR (>FSP)",
       subtitle = sprintf("FSP = %d anni, LLFR = %.3f%%, UFR = %.2f%%, alpha = %.1f%%",
                          FSP, (exp(LLFR_c)-1)*100, UFR_ann * 100, alpha*100),
       x = "Scadenza T (anni)", y = "Tasso (%)", color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig06_curva_spot_forward", p6)

# --- Grafico fig06b: convergenza |forward - UFR| ---
df_cv <- data.frame(T = ext$t, dist = abs(ext$fc - UFR_c) * 1e4)  # bps
p6b <- ggplot(df_cv, aes(x = T, y = dist)) +
  geom_line(color = col_fwd, linewidth = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  annotate("text", x = 130, y = 1.4, label = "1 bp", color = "red", size = 3) +
  scale_y_log10() +
  labs(title = expression(paste("|", f^c, "(t",F,",t",F,"+h) - ", UFR^c, "| — convergenza all'UFR")),
       subtitle = "Scala logaritmica: il forward estrapolato converge monotonicamente all'UFR (peso B(a,h)->0)",
       x = "Scadenza T (anni)", y = "|forward − UFR| (bps)") +
  theme_dispensa
save_fig("fig06b_convergenza_ufr", p6b)


# ==============================================================================
# SEZ. 6 — SENSITIVITÀ (alpha, UFR)
# ==============================================================================

cat("=== SEZ. 6: SENSITIVITÀ ===\n")

# --- 6a: sensitività ad alpha (phasing-in 2027 vs target 2032 vs SEK) ---
df_sa <- do.call(rbind, lapply(c(0.110, alpha, 0.40), function(a) {
  e <- extrapolate(a)
  data.frame(T = c(bc$t, e$t),
             f = (exp(c(fc_all[seq_len(FSP)], e$fc)) - 1) * 100,
             alpha = sprintf("a = %.1f%%", a * 100))
}))
p7a <- ggplot(df_sa, aes(x = T, y = f, color = alpha)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted") +
  geom_vline(xintercept = FSP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  labs(title = expression(paste("Sensitività del forward al parametro di convergenza ", alpha)),
       subtitle = "alpha e' FISSO per legge (phasing-in 20%->11%; 40% per SEK): controlla la velocita' di convergenza all'UFR",
       x = "Scadenza T (anni)", y = "Forward (%)", color = expression(alpha)) +
  theme_dispensa
save_fig("fig07a_sensitivita_alpha", p7a)

# --- 6b: sensitività all'UFR ---
df_su <- do.call(rbind, lapply(c(0.0315, 0.0330, 0.0345), function(ufr_a) {
  ufr_c <- log(1 + ufr_a)
  h <- 1:(150 - FSP)
  fc <- ufr_c + (LLFR_c - ufr_c) * B_weight(alpha, h)
  zc_e <- (FSP * zc[FSP] + h * fc) / (FSP + h)
  data.frame(T = c(bc$t, FSP + h),
             z = c(bc$z, exp(zc_e) - 1) * 100,
             UFR = sprintf("UFR = %.2f%%", ufr_a * 100))
}))
p7b <- ggplot(df_su, aes(x = T, y = z, color = UFR)) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = FSP, color = "gray60", linetype = "dashed", linewidth = 0.5) +
  labs(title = "Sensitività della curva spot all'UFR",
       subtitle = "Le curve coincidono fino all'FSP (bootstrap dai dati) e divergono in estrapolazione",
       x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL) +
  theme_dispensa
save_fig("fig07b_sensitivita_ufr", p7b)


# ==============================================================================
# SEZ. 7 — CONFRONTO: estrapolazione EIOPA vs spline cubica naturale
# ==============================================================================
#
# Motivazione didattica: l'estrapolazione è il problema chiave. I metodi classici
# di interpolazione (es. spline cubica) interpolano bene ma NON convergono a un
# asintoto economico (l'UFR): oltre l'ultimo nodo estrapolano linearmente.
# ==============================================================================

cat("=== SEZ. 7: CONFRONTO con spline cubica ===\n")

T_eval <- seq(1, 80, by = 0.25)
# spline cubica naturale sugli spot ai tenor osservati
spline_fit <- splinefun(bc$t[bc$is_obs], bc$z[bc$is_obs] * 100, method = "natural")
r_spline <- spline_fit(T_eval)
# curva EIOPA (spot) interpolata sui medesimi punti
eiopa_spot <- approx(t_all, z_all * 100, xout = T_eval)$y

df_cmp <- rbind(
  data.frame(T = T_eval, Tasso = r_spline,   Metodo = "Spline cubica naturale"),
  data.frame(T = T_eval, Tasso = eiopa_spot, Metodo = "EIOPA (bootstrap + FSP/LLFR)")
)
p8 <- ggplot(df_cmp, aes(x = T, y = Tasso, color = Metodo, linetype = Metodo)) +
  annotate("rect", xmin = FSP, xmax = 80, ymin = -Inf, ymax = Inf,
           fill = "gray85", alpha = 0.35) +
  annotate("text", x = (FSP + 80)/2, y = max(df_cmp$Tasso, na.rm = TRUE),
           label = "Estrapolazione (T > FSP)", color = "gray40", size = 3.3) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = UFR_ann * 100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
  geom_vline(xintercept = FSP, color = "gray50", linetype = "dashed", linewidth = 0.5) +
  geom_point(data = data.frame(T = bc$t[bc$is_obs], Tasso = bc$z[bc$is_obs]*100),
             aes(x = T, y = Tasso), color = col_nodi, size = 2.1, shape = 16,
             inherit.aes = FALSE) +
  annotate("text", x = 55, y = UFR_ann * 100 + 0.10,
           label = sprintf("UFR = %.2f%%", UFR_ann * 100), color = col_ufr, size = 3.2) +
  scale_color_manual(values = c("Spline cubica naturale" = col_llfr,
                                "EIOPA (bootstrap + FSP/LLFR)" = col_spot)) +
  scale_linetype_manual(values = c("Spline cubica naturale" = "dashed",
                                   "EIOPA (bootstrap + FSP/LLFR)" = "solid")) +
  labs(title = "Estrapolazione: spline cubica vs metodo EIOPA",
       subtitle = "Oltre l'FSP la spline estrapola senza vincolo; il metodo EIOPA converge all'UFR",
       x = "Scadenza T (anni)", y = "Spot rate (%)", color = NULL, linetype = NULL) +
  theme_dispensa
save_fig("fig08_confronto_spline", p8)


# ==============================================================================
# FINE — Riepilogo file generati
# ==============================================================================

cat("\n====================================================================\n")
cat("  GRAFICI GENERATI in:", dir_out, "\n")
cat("====================================================================\n")
files_out <- list.files(dir_out, pattern = "\\.pdf$")
for (f in files_out) cat("  •", f, "\n")
cat("\n")
