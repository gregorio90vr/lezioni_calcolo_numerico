# ==============================================================================
#  Dispensa 02 (ufficiale) — Curva EIOPA Risk-Free: i due metodi a confronto
#  Script 2/2 — metodo SMITH-WILSON (EIOPA-BoS-25-599)
#  Genera dispense/02_eiopa_rfr_bootstrap_smith_wilson.tex, Sez. 4, 6.2, 7,
#  l'export Excel.
#
#  Va eseguito DOPO R/02_eiopa_rfr_bootstrap.R: Sez. 7 confronta le due
#  ricostruzioni, quindi ha bisogno ANCHE della curva bootstrap. I due
#  script sono due processi R separati (niente sopravvive in memoria da uno
#  all'altro): questo script rilegge curva_bootstrap_dic2025.csv, scritto a
#  fine sessione dallo script bootstrap nella stessa cartella di output
#  condivisa. Stesso pattern gia' in uso nel repo tra 04_pca_ecb_prep.R e
#  04_pca_ecb.R/04b_pca_ecb.R (xlsx intermedio in dati/).
#
#  Destinazione: ../output/02_eiopa_rfr_bootstrap_smith_wilson/ (condivisa
#  con R/02_eiopa_rfr_bootstrap.R).
#
#  Input:  ../dati/02_swap_euribor6m_ric_dic2025.xlsx   (par swap input EIOPA,
#          stesso file del bootstrap: STESSI dati per entrambi i metodi)
#          ../dati/eiopa_zips/EIOPA_RFR_202512??.zip    (curva ufficiale SW)
#          curva_bootstrap_dic2025.csv                  (scritto da
#          R/02_eiopa_rfr_bootstrap.R, nella cartella di output)
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
#     02_eiopa_rfr_bootstrap.R -- stessa indipendenza gia' seguita da
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

GEN <- "% GENERATO da R/02_eiopa_rfr_smith_wilson.R"

# --- lettore dello zip ufficiale EIOPA ----------------------------------------
# Restituisce la curva spot ufficiale (metodo Smith-Wilson) piu' CRA e alpha
# pubblicati, per il mese richiesto.
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

cat("\n=====================================================================\n")
cat("  DISPENSA 02 (Smith-Wilson) -> ", normalizePath(dir_out, mustWork = FALSE), "\n")
cat("=====================================================================\n\n")

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

# --- B.0 dati di input --------------------------------------------------------
# STESSI dati di input del bootstrap: par swap after-CRA ai 15 tenor DLT.
swap_in <- data.table(openxlsx::read.xlsx(
  file.path(dir_dat, "02_swap_euribor6m_ric_dic2025.xlsx")))
cra_eur   <- 10 / 1e4          # CRA = 10 bps (EUR)
fsp       <- 20                # First Smoothing Point del bootstrap = LLP (stesso punto, Sez. 3)
max_tenor <- max(swap_in[, tenor])
s_post <- rep(0, max_tenor)
for (i in swap_in[, tenor]) s_post[i] <- swap_in[tenor == i, swap_inputEUR] - cra_eur

UFR_ann <- 3.3 / 100
UFR_c   <- log(1 + UFR_ann)

# --- B.1 parametri (sez. 9.7-9.14) --------------------------------------------
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
# a fini didattici, sullo stesso schema di newton_traccia() dello script
# bootstrap).
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

# --- B.8 curva bootstrap (per Sez. 7): letta dal CSV scritto dallo script ----
#     R/02_eiopa_rfr_bootstrap.R -- va eseguito prima di questo.
f_boot <- file.path(dir_out, "curva_bootstrap_dic2025.csv")
if (!file.exists(f_boot))
  stop("curva_bootstrap_dic2025.csv non trovato: eseguire prima R/02_eiopa_rfr_bootstrap.R")
curve_finale <- fread(f_boot)

# ==============================================================================
# PARTE C — OUTPUT: FIGURE E TABELLE (parte Smith-Wilson + confronto)
# ==============================================================================

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
# Qui sta il punto della dispensa: entrambe le curve sono state costruite
# dagli stessi 15 par swap after-CRA e con lo stesso UFR (script separati,
# stessi input -- vedi curva_bootstrap_dic2025.csv letto in B.8). Lo scarto
# misurato isola quindi la SOLA differenza di metodologia.
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
