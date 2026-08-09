
# ==============================================================================
#  Dispensa 01: Titoli obbligazionari — prezzo, rendimento, duration, convexity
#  Corso di Calcolo Numerico — Laboratorio
#  Universita' degli Studi di Verona — A.A. 2026-2027
#
#  Script autosufficiente: nessun file dati esterno. I due titoli di esempio
#  (Bond A, Bond B) sono definiti qui sotto con numeri didattici (stile Hull),
#  non con quotazioni di mercato reali. Non ha una controparte "prep": tutto
#  cio' che serve e' calcolato dentro questo file.
#
#  Convenzione: cedole ANNUE, tasso y a capitalizzazione annua composta
#  (P(y) = sum CF_t (1+y)^-t) — la stessa convenzione della quotazione di
#  mercato dei titoli, diversa dall'intensita' continua usata internamente
#  dalla curva EIOPA (dispensa 3, Sez. 2): il passaggio dall'una all'altra
#  e' proprio uno dei temi che la dispensa 3 riprendera'.
# ==============================================================================

rm(list = ls())
require(data.table)
suppressPackageStartupMessages(library(ggplot2))

# ------------------------------------------------------------------------------
# 0. FUNZIONI DI BASE: prezzo, derivate, duration, convexity
# ------------------------------------------------------------------------------
# cf, times: vettori di flussi di cassa e delle rispettive scadenze (anni).
# Valgono per QUALSIASI schema di flussi (non solo cedola fissa annua), cosi'
# le stesse funzioni servono sia per i bond sia, in astratto, per una passivita'.

bond_price <- function(y, cf, times) sum(cf / (1 + y)^times)

bond_dprice <- function(y, cf, times) -sum(times * cf / (1 + y)^(times + 1))

bond_d2price <- function(y, cf, times) sum(times * (times + 1) * cf / (1 + y)^(times + 2))

macaulay_duration <- function(y, cf, times) {
  sum(times * cf / (1 + y)^times) / bond_price(y, cf, times)
}

modified_duration <- function(Dmac, y) Dmac / (1 + y)

convexity <- function(y, cf, times) bond_d2price(y, cf, times) / bond_price(y, cf, times)

# flussi di un titolo a cedola fissa annua, nozionale N, cedola c, scadenza T
cashflow_bond <- function(c, N, Tmax) {
  times <- 1:Tmax
  cf <- rep(c * N, Tmax)
  cf[Tmax] <- cf[Tmax] + N
  list(cf = cf, times = times)
}

# ------------------------------------------------------------------------------
# 1. I DUE TITOLI DI ESEMPIO (Sez. 2)
# ------------------------------------------------------------------------------
# Bond A: nozionale 100, cedola 4%, scadenza 5 anni, prezzo di mercato 97.50
# Bond B: nozionale 100, cedola 3%, scadenza 10 anni, prezzo di mercato 96.00
# Prezzi sotto la pari per entrambi -> in entrambi i casi ci aspettiamo y > cedola.

N <- 100
bondA <- list(N = N, c = 0.04, Tmax = 5,  Pmkt = 97.50)
bondB <- list(N = N, c = 0.03, Tmax = 10, Pmkt = 96.00)

bondA <- c(bondA, cashflow_bond(bondA$c, bondA$N, bondA$Tmax))
bondB <- c(bondB, cashflow_bond(bondB$c, bondB$N, bondB$Tmax))

cat("Bond A: cedola", bondA$c*100, "%  T =", bondA$Tmax, " Pmkt =", bondA$Pmkt, "\n")
cat("Bond B: cedola", bondB$c*100, "%  T =", bondB$Tmax, " Pmkt =", bondB$Pmkt, "\n")

# ------------------------------------------------------------------------------
# 2. RICERCA DEL RENDIMENTO A SCADENZA (YTM): BISEZIONE E NEWTON (Sez. 3)
# ------------------------------------------------------------------------------
# phi(y) = P(y) - Pmkt = 0. phi e' strettamente decrescente in y (Proposizione
# della dispensa, Sez. 2.5): esiste un'unica radice in (-1, +inf).

phi     <- function(y, bond) bond_price(y, bond$cf, bond$times) - bond$Pmkt
dphi    <- function(y, bond) bond_dprice(y, bond$cf, bond$times)

bisezione_traccia <- function(bond, a, b, tol = 1e-10, nmax = 60) {
  fa <- phi(a, bond); fb <- phi(b, bond)
  stopifnot(fa * fb < 0)
  out <- data.table(k = integer(0), a = numeric(0), b = numeric(0),
                     m = numeric(0), phi_m = numeric(0), ampiezza = numeric(0))
  for (k in seq_len(nmax)) {
    m <- (a + b) / 2
    fm <- phi(m, bond)
    out <- rbind(out, data.table(k = k, a = a, b = b, m = m, phi_m = fm,
                                  ampiezza = b - a))
    if (abs(fm) < 1e-14 || (b - a) / 2 < tol) break
    if (fa * fm < 0) { b <- m; fb <- fm } else { a <- m; fa <- fm }
  }
  out
}

newton_traccia_ytm <- function(bond, y0, tol = 1e-12, nmax = 30) {
  out <- data.table(k = 0L, y = y0, phi = phi(y0, bond), incr = NA_real_)
  y <- y0
  for (k in seq_len(nmax)) {
    yprev <- y
    y <- y - phi(y, bond) / dphi(y, bond)
    out <- rbind(out, data.table(k = as.integer(k), y = y, phi = phi(y, bond),
                                  incr = abs(y - yprev)))
    if (abs(y - yprev) <= tol) break
  }
  out
}

tr_bisA <- bisezione_traccia(bondA, a = 0, b = 0.20)
tr_newA <- newton_traccia_ytm(bondA, y0 = bondA$c)

ytm_bisA <- tail(tr_bisA$m, 1)
ytm_newA <- tail(tr_newA$y, 1)
cat(sprintf("Bond A: YTM bisezione = %.8f%% (%d iter), YTM Newton = %.8f%% (%d iter)\n",
            ytm_bisA*100, nrow(tr_bisA), ytm_newA*100, nrow(tr_newA)-1))

# Bond B: solo Newton, serve per il confronto di Sez. 6 e per l'immunizzazione
tr_newB <- newton_traccia_ytm(bondB, y0 = bondB$c)
ytm_newB <- tail(tr_newB$y, 1)
cat(sprintf("Bond B: YTM Newton = %.8f%% (%d iter)\n", ytm_newB*100, nrow(tr_newB)-1))

y_A <- ytm_newA
y_B <- ytm_newB

# ------------------------------------------------------------------------------
# 3. DURATION, MODIFIED DURATION, CONVEXITY (Sez. 4)
# ------------------------------------------------------------------------------
Dmac_A <- macaulay_duration(y_A, bondA$cf, bondA$times)
Dmod_A <- modified_duration(Dmac_A, y_A)
Conv_A <- convexity(y_A, bondA$cf, bondA$times)

Dmac_B <- macaulay_duration(y_B, bondB$cf, bondB$times)
Dmod_B <- modified_duration(Dmac_B, y_B)
Conv_B <- convexity(y_B, bondB$cf, bondB$times)

cat(sprintf("Bond A: D_mac = %.4f  D_mod = %.4f  C = %.4f\n", Dmac_A, Dmod_A, Conv_A))
cat(sprintf("Bond B: D_mac = %.4f  D_mod = %.4f  C = %.4f\n", Dmac_B, Dmod_B, Conv_B))

# tabella dei flussi di Bond A al proprio YTM: base per la Tab. 1 (schema Hull)
tab_flussi_A <- data.table(
  t   = bondA$times,
  cf  = bondA$cf,
  pv  = bondA$cf / (1 + y_A)^bondA$times
)
tab_flussi_A[, peso := pv / sum(pv)]
tab_flussi_A[, contrib_t := peso * t]
stopifnot(abs(sum(tab_flussi_A$pv) - bond_price(y_A, bondA$cf, bondA$times)) < 1e-8)
stopifnot(abs(sum(tab_flussi_A$contrib_t) - Dmac_A) < 1e-8)

# ------------------------------------------------------------------------------
# 4. APPROSSIMAZIONE DI TAYLOR: ERRORE LINEARE VS QUADRATICA (Sez. 4.5)
# ------------------------------------------------------------------------------
dy_grid <- seq(-0.02, 0.02, by = 0.0005)  # +-200 bps attorno a y_A
P0_A    <- bond_price(y_A, bondA$cf, bondA$times)

taylor_dt <- data.table(
  dy       = dy_grid,
  esatto   = sapply(y_A + dy_grid, bond_price, cf = bondA$cf, times = bondA$times),
  lineare  = P0_A * (1 - Dmod_A * dy_grid),
  quadr    = P0_A * (1 - Dmod_A * dy_grid + 0.5 * Conv_A * dy_grid^2)
)
taylor_dt[, err_lineare := 1e4 * (lineare - esatto) / P0_A]  # errore in bps di prezzo
taylor_dt[, err_quadr   := 1e4 * (quadr   - esatto) / P0_A]

# righe di dettaglio per la tabella in dispensa (griglia piu' rada)
dy_tab <- c(-0.02, -0.01, -0.005, -0.0025, 0, 0.0025, 0.005, 0.01, 0.02)
tab_taylor <- data.table(
  dy      = dy_tab,
  esatto  = sapply(y_A + dy_tab, bond_price, cf = bondA$cf, times = bondA$times),
  lineare = P0_A * (1 - Dmod_A * dy_tab),
  quadr   = P0_A * (1 - Dmod_A * dy_tab + 0.5 * Conv_A * dy_tab^2)
)
tab_taylor[, err_lineare := 1e4 * (lineare - esatto) / P0_A]
tab_taylor[, err_quadr   := 1e4 * (quadr   - esatto) / P0_A]

# ------------------------------------------------------------------------------
# 5. DURATION DI PORTAFOGLIO E IMMUNIZZAZIONE (Sez. 5)
# ------------------------------------------------------------------------------
# Passivita': un unico pagamento la cui "duration" (= scadenza, essendo un
# flusso singolo) e' D_L = 7 anni. Si cercano i pesi w_A + w_B = 1 tali che
# la duration del portafoglio {Bond A, Bond B} coincida con D_L.
D_L <- 7

w_A <- (D_L - Dmac_B) / (Dmac_A - Dmac_B)
w_B <- 1 - w_A
stopifnot(w_A >= 0 && w_A <= 1)

Dport <- w_A * Dmac_A + w_B * Dmac_B
Cport <- w_A * Conv_A + w_B * Conv_B
cat(sprintf("Immunizzazione: w_A = %.4f, w_B = %.4f, D_portafoglio = %.4f (target %.1f)\n",
            w_A, w_B, Dport, D_L))
stopifnot(abs(Dport - D_L) < 1e-8)

# griglia di w_A per il grafico "duration di portafoglio vs peso"
w_grid <- seq(0, 1, by = 0.01)
port_dt <- data.table(w_A = w_grid, D = w_grid * Dmac_A + (1 - w_grid) * Dmac_B)

# ==============================================================================
# ==============================================================================
#  OUTPUT PER LA DISPENSA 01 (figure PDF e tabelle .tex)
#  Destinazione: ../output/01_bond_duration_convexity/
# ==============================================================================
# ==============================================================================

dir_out <- file.path("..", "output", "01_bond_duration_convexity")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

theme_dispensa <- theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title       = element_text(face = "bold", size = 13),
        plot.subtitle    = element_text(size = 10, color = "gray30"),
        legend.position  = "bottom")

col_a <- "#185FA5"; col_b <- "#993C1D"; col_target <- "#7060CC"
col_lin <- "#2E8B57"; col_quad <- "#B2182B"; col_pt <- "black"

save_fig <- function(nome, plot_obj, w = 8, h = 5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", nome, ".pdf")
}
save_tab <- function(nome, lines) {
  writeLines(lines, file.path(dir_out, paste0(nome, ".tex")))
  message("  [OK] ", nome, ".tex")
}
tint <- function(i) if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""

cat("\n=====================================================================\n")
cat("  OUTPUT DISPENSA 01 -> ", normalizePath(dir_out, mustWork = FALSE), "\n")
cat("=====================================================================\n\n")

# ------------------------------------------------------------------------------
# 1. TABELLA: flussi di cassa e pesi del Bond A al proprio YTM
# ------------------------------------------------------------------------------
{
  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Bond A: flussi di cassa, valore attuale al rendimento $y=",
           sprintf("%.4f", y_A*100), "\\%$, peso $\\mathrm{pv}_t/P$ e contributo ",
           "$t\\cdot\\mathrm{pv}_t/P$ alla duration di Macaulay~\\eqref{eq:macaulay}. ",
           "La somma dell'ultima colonna \\`e $D_{\\mathrm{Mac}}$.}"),
    "\\label{tab:flussi-bondA}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rcccc}", "\\toprule",
    "$t$ (anni) & $CF_t$ & $\\mathrm{pv}_t=CF_t(1+y)^{-t}$ & peso $\\mathrm{pv}_t/P$ & $t\\cdot$peso\\\\",
    "\\midrule")
  for (i in seq_len(nrow(tab_flussi_A))) {
    lines <- c(lines, sprintf("%s%d & %.4f & %.4f & %.4f & %.4f\\\\",
                              tint(i), tab_flussi_A$t[i], tab_flussi_A$cf[i],
                              tab_flussi_A$pv[i], tab_flussi_A$peso[i],
                              tab_flussi_A$contrib_t[i]))
  }
  lines <- c(lines, "\\midrule",
             sprintf("\\multicolumn{2}{r}{Somma (=$P$, =$D_{\\mathrm{Mac}}$)} & %.4f & 1.0000 & %.4f\\\\",
                     sum(tab_flussi_A$pv), sum(tab_flussi_A$contrib_t)),
             "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_flussi_bondA", lines)
}

# ------------------------------------------------------------------------------
# 2. FIGURA: prezzo in funzione del rendimento, Bond A
# ------------------------------------------------------------------------------
{
  y_grid <- seq(0.005, 0.14, by = 0.001)
  dfP <- data.table(y = y_grid,
                     P = sapply(y_grid, bond_price, cf = bondA$cf, times = bondA$times))
  pP <- ggplot(dfP, aes(x = y * 100, y = P)) +
    geom_line(linewidth = 1, color = col_a) +
    geom_hline(yintercept = bondA$Pmkt, linetype = "dashed", color = "gray40") +
    geom_point(data = data.table(y = y_A, P = bondA$Pmkt), color = col_pt, size = 2.2) +
    annotate("text", x = y_A * 100 + 1.3, y = bondA$Pmkt + 3,
             label = sprintf("YTM = %.3f%%", y_A * 100), size = 3.5) +
    labs(title = "Bond A: prezzo in funzione del rendimento",
         subtitle = "P(y) e' strettamente decrescente e convessa; il rendimento a scadenza e' l'unico zero di P(y)-P_mkt",
         x = "Rendimento y (%)", y = "Prezzo P(y)") +
    theme_dispensa
  save_fig("fig_prezzo_rendimento", pP)
}

# ------------------------------------------------------------------------------
# 3. TABELLE: iterazioni bisezione e Newton (Bond A)
# ------------------------------------------------------------------------------
{
  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Bisezione su $[0,0.20]$ per il rendimento a scadenza del Bond A: ",
           "punto medio $m_k$, residuo $\\varphi(m_k)=P(m_k)-P_{\\mathrm{mkt}}$ e ampiezza ",
           "dell'intervallo. Si mostrano le prime 10 e le ultime 2 iterazioni.}"),
    "\\label{tab:bisezione-ytm}\\renewcommand{\\arraystretch}{1.1}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$k$ & $m_k$ (\\%) & $\\varphi(m_k)$ & ampiezza\\\\",
    "\\midrule")
  n_bis <- nrow(tr_bisA)
  idx <- unique(c(seq_len(min(10, n_bis)), (n_bis-1):n_bis))
  idx <- idx[idx >= 1 & idx <= n_bis]
  for (i in idx) {
    if (i == idx[length(idx)-1] + 1 && i > 11) lines <- c(lines, "$\\vdots$ & $\\vdots$ & $\\vdots$ & $\\vdots$\\\\")
    lines <- c(lines, sprintf("%s%d & %.6f & %+.3e & %.2e\\\\",
                              tint(i), tr_bisA$k[i], tr_bisA$m[i]*100,
                              tr_bisA$phi_m[i], tr_bisA$ampiezza[i]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_bisezione_ytm", lines)
}

{
  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Newton-Raphson per il rendimento a scadenza del Bond A, ",
           "inizializzato a $y_0=$ cedola $=4\\%$. Il residuo crolla quadraticamente: ",
           "gia' alla terza iterazione l'incremento e' sotto la precisione macchina.}"),
    "\\label{tab:newton-ytm}\\renewcommand{\\arraystretch}{1.1}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$k$ & $y_k$ (\\%) & $\\varphi(y_k)$ & $|y_k-y_{k-1}|$\\\\",
    "\\midrule")
  for (i in seq_len(nrow(tr_newA))) {
    incr_str <- if (is.na(tr_newA$incr[i])) "---" else sprintf("%.3e", tr_newA$incr[i])
    lines <- c(lines, sprintf("%s%d & %.8f & %+.3e & %s\\\\",
                              tint(i), tr_newA$k[i], tr_newA$y[i]*100,
                              tr_newA$phi[i], incr_str))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_newton_ytm", lines)
}

# ------------------------------------------------------------------------------
# 4. FIGURA: confronto di convergenza bisezione vs Newton
# ------------------------------------------------------------------------------
{
  y_star <- ytm_newA
  df_bis <- data.table(k = tr_bisA$k, err = abs(tr_bisA$m - y_star), metodo = "Bisezione")
  df_new <- data.table(k = tr_newA$k, err = abs(tr_newA$y - y_star), metodo = "Newton")
  df_new <- df_new[err > 0]  # log-scale: elimina l'errore esattamente nullo finale
  df_conv <- rbind(df_bis, df_new)
  pC <- ggplot(df_conv, aes(x = k, y = err, color = metodo, shape = metodo)) +
    geom_line(linewidth = 0.8) + geom_point(size = 1.8) +
    scale_y_log10() +
    labs(title = "Convergenza: bisezione vs Newton-Raphson",
         subtitle = "Errore |y_k - y*| in scala logaritmica: la bisezione dimezza l'errore, Newton lo eleva al quadrato",
         x = "Iterazione k", y = expression("|"*y[k]-y*"*|"*" (scala log)")) +
    theme_dispensa
  save_fig("fig_convergenza_bisezione_newton", pC)
}

# ------------------------------------------------------------------------------
# 5. TABELLA riepilogo: prezzo, YTM, duration, convexity dei due bond
# ------------------------------------------------------------------------------
{
  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    "\\caption{Riepilogo dei due titoli di esempio al proprio rendimento a scadenza.}",
    "\\label{tab:riepilogo-duration}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{lccccccc}", "\\toprule",
    "Titolo & cedola & $T$ & $P_{\\mathrm{mkt}}$ & YTM (\\%) & $D_{\\mathrm{Mac}}$ & $D_{\\mathrm{mod}}$ & $C$\\\\",
    "\\midrule",
    sprintf("%sBond A & %.0f\\%% & %d & %.2f & %.4f & %.4f & %.4f & %.4f\\\\",
            tint(1), bondA$c*100, bondA$Tmax, bondA$Pmkt, y_A*100, Dmac_A, Dmod_A, Conv_A),
    sprintf("%sBond B & %.0f\\%% & %d & %.2f & %.4f & %.4f & %.4f & %.4f\\\\",
            tint(2), bondB$c*100, bondB$Tmax, bondB$Pmkt, y_B*100, Dmac_B, Dmod_B, Conv_B),
    "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_riepilogo_duration", lines)
}

# ------------------------------------------------------------------------------
# 6. FIGURA + TABELLA: Taylor lineare vs quadratica, Bond A
# ------------------------------------------------------------------------------
{
  df_plot <- rbind(
    data.table(dy = taylor_dt$dy, P = taylor_dt$esatto,  serie = "Esatto"),
    data.table(dy = taylor_dt$dy, P = taylor_dt$lineare, serie = "Approx. lineare (duration)"),
    data.table(dy = taylor_dt$dy, P = taylor_dt$quadr,   serie = "Approx. quadratica (+convexity)")
  )
  pT <- ggplot(df_plot, aes(x = dy * 1e4, y = P, color = serie, linetype = serie)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Esatto" = col_pt, "Approx. lineare (duration)" = col_lin,
                                   "Approx. quadratica (+convexity)" = col_quad)) +
    labs(title = "Bond A: prezzo esatto vs approssimazione di Taylor",
         subtitle = "Al 1o ordine (sola duration) l'approssimazione e' una retta tangente; al 2o ordine (+convexity) segue la curvatura",
         x = expression(Delta*y~"(bps)"), y = "Prezzo") +
    theme_dispensa
  save_fig("fig_taylor_prezzo", pT, w = 8.5, h = 5.5)

  pE <- ggplot(taylor_dt, aes(x = dy * 1e4)) +
    geom_line(aes(y = err_lineare, color = "Errore lineare"), linewidth = 1) +
    geom_line(aes(y = err_quadr,   color = "Errore quadratico"), linewidth = 1) +
    scale_color_manual(values = c("Errore lineare" = col_lin, "Errore quadratico" = col_quad),
                        name = NULL) +
    labs(title = "Errore di troncamento dell'approssimazione di Taylor",
         subtitle = "Errore (bps di prezzo) rispetto al prezzo esatto: il lineare cresce come Dy^2, il quadratico come Dy^3",
         x = expression(Delta*y~"(bps)"), y = "Errore (bps di prezzo)") +
    theme_dispensa
  save_fig("fig_taylor_errore", pE)

  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Bond A: prezzo esatto e approssimazioni di Taylor al 1\\textsuperscript{o} ",
           "e 2\\textsuperscript{o} ordine, per diversi shock $\\Delta y$. Errore in bps di prezzo ",
           "rispetto all'esatto.}"),
    "\\label{tab:taylor-confronto}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccccc}", "\\toprule",
    "$\\Delta y$ (bps) & esatto & lineare & quadratico & err. lineare (bps) & err. quadr. (bps)\\\\",
    "\\midrule")
  for (i in seq_len(nrow(tab_taylor))) {
    lines <- c(lines, sprintf("%s%+.0f & %.4f & %.4f & %.4f & %+.2f & %+.3f\\\\",
                              tint(i), tab_taylor$dy[i]*1e4, tab_taylor$esatto[i],
                              tab_taylor$lineare[i], tab_taylor$quadr[i],
                              tab_taylor$err_lineare[i], tab_taylor$err_quadr[i]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_taylor_confronto", lines)
}

# ------------------------------------------------------------------------------
# 7. FIGURA + TABELLA: immunizzazione di portafoglio
# ------------------------------------------------------------------------------
{
  pI <- ggplot(port_dt, aes(x = w_A, y = D)) +
    geom_line(linewidth = 1, color = col_a) +
    geom_hline(yintercept = D_L, linetype = "dashed", color = col_target) +
    geom_point(aes(x = w_A_pt, y = D_L), data = data.table(w_A_pt = w_A, D_L = D_L),
               color = col_pt, size = 2.2) +
    annotate("text", x = w_A + 0.12, y = D_L - 0.35,
             label = sprintf("w_A = %.3f", w_A), size = 3.5) +
    labs(title = "Duration di portafoglio in funzione del peso w_A",
         subtitle = sprintf("Portafoglio {Bond A, Bond B}: la retta w_A*D_A+(1-w_A)*D_B incrocia il target D_L=%d nel punto evidenziato", D_L),
         x = expression(w[A]), y = "Duration di portafoglio") +
    theme_dispensa
  save_fig("fig_immunizzazione", pI)

  lines <- c("% GENERATO da R/01_bond_duration_convexity.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Immunizzazione di una passivita' di duration $D_L=", D_L,
           "$ con il portafoglio $\\{$Bond A, Bond B$\\}$: pesi che risolvono il ",
           "sistema~\\eqref{eq:immunizzazione} e duration/convexity risultanti.}"),
    "\\label{tab:immunizzazione}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{lc}", "\\toprule",
    sprintf("%speso Bond A, $w_A$ & %.4f\\\\", tint(1), w_A),
    sprintf("%speso Bond B, $w_B=1-w_A$ & %.4f\\\\", tint(2), w_B),
    sprintf("%sduration di portafoglio $D_{\\mathrm{port}}$ & %.4f\\\\", tint(3), Dport),
    sprintf("%sconvexity di portafoglio $C_{\\mathrm{port}}$ & %.4f\\\\", tint(4), Cport),
    sprintf("%starget $D_L$ & %.4f\\\\", tint(5), D_L),
    "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_immunizzazione", lines)
}

cat("\n  Fatto. Output in ", dir_out, "\n\n")
