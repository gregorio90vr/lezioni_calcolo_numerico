# ==============================================================================
# ORIGINE DEI DATI
# ------------------------------------------------------------------------------
# I dati provengono dal Risk-Free Rate register di EIOPA
# (https://www.eiopa.europa.eu/tools-and-data/risk-free-interest-rate-term-structures)
#
# EIOPA pubblica ogni mese, con riferimento all'ULTIMO GIORNO DI CALENDARIO del
# mese, la struttura a termine dei tassi risk-free che TUTTE le imprese di
# assicurazione europee devono usare per scontare le riserve tecniche ai fini
# della direttiva Solvency II. La curva non e' quindi una stima statistica come
# quella BCE, ma un DATO REGOLAMENTARE.
#
# La serie utilizzata e' la curva EUR, spot, SENZA volatility adjustment
# (foglio "RFR_spot_no_VA"): il VA e' una maggiorazione che dipende dal
# portafoglio della singola impresa, mentre la curva senza VA e' la curva
# risk-free di base, metodologicamente pulita.
#
# Costruzione della curva (cfr. dispense 01 e 03 di questo corso):
#   - sottostante: tassi SWAP EUR (par swap rate), non titoli di Stato;
#   - al tasso di mercato viene sottratto il Credit Risk Adjustment (CRA);
#   - i tassi sono quotati sui 15 nodi DLT (Deep, Liquid, Transparent) EUR
#     {1,...,13, 15, 20} anni; le scadenze intermedie 14, 16, 17, 18, 19
#     sono INTERPOLATE dal metodo Smith-Wilson;
#   - oltre il Last Liquid Point (LLP = 20 anni per l'euro) la curva e'
#     ESTRAPOLATA verso l'Ultimate Forward Rate (UFR).
# Questo script si ferma a 20 anni: la finestra 1-20Y coincide esattamente con
# la parte liquida della curva, quindi l'estrapolazione non entra nell'analisi.
#
# I tassi EIOPA sono espressi in CAPITALIZZAZIONE ANNUA COMPOSTA,
#   P(0,T) = (1 + r(T))^(-T),
# a differenza della curva BCE della lezione 04 che e' in capitalizzazione
# continua. Le due curve non sono direttamente sovrapponibili senza conversione.
#
# ATTENZIONE ALLE UNITA': gli archivi EIOPA contengono i tassi in forma
# DECIMALE (0.02592 = 2.592%). Questo script li converte una volta per tutte in
# PUNTI PERCENTUALI (2.592), la stessa convenzione del file 04_ecb_spot.xlsx,
# cosi' che 04c_pca_eiopa.R sia identico a 04_pca_ecb.R/04b_pca_ecb.R nella logica delle unita'
# e i risultati delle due lezioni siano direttamente confrontabili.
#
# Struttura di ogni archivio dati/eiopa_zips/*.zip:
#   EIOPA_RFR_<YYYYMMDD>_Term_Structures.xlsx   <- l'unico file usato
#     foglio "RFR_spot_no_VA":
#       riga  2 : intestazioni di paese/valuta, "Euro" in colonna C
#       righe 4-10 : metadati (Coupon_freq, LLP, Convergence, UFR, alpha, CRA, VA)
#       righe 11+  : dati, colonna B = scadenza (1..150), colonna C = tasso EUR
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  }
})

zip_dir_name     <- "../dati/eiopa_zips"
output_file_name <- "../dati/04c_eiopa_spot.xlsx"

n_tenor <- 20L   # scadenze 1Y..20Y = parte liquida della curva euro (LLP = 20)

# ------------------------------------------------------------------------------
# Risoluzione dei percorsi: funziona sia con Rscript (--file=...) sia da RStudio
# ------------------------------------------------------------------------------
args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grep(file_arg, args_all)])

if (length(script_path) > 0) {
  base_dir <- dirname(normalizePath(script_path[1], winslash = "/", mustWork = TRUE))
} else {
  base_dir <- getwd()
}

zip_dir     <- file.path(base_dir, zip_dir_name)
output_file <- file.path(base_dir, output_file_name)

if (!dir.exists(zip_dir)) {
  candidate <- file.path(getwd(), zip_dir_name)
  if (dir.exists(candidate)) zip_dir <- candidate
}

if (!dir.exists(zip_dir)) {
  stop(
    paste0(
      "Cartella non trovata: ", zip_dir_name,
      "\nControlla che gli archivi EIOPA siano in dati/eiopa_zips/.",
      "\nbase_dir=", base_dir, " | getwd()=", getwd()
    )
  )
}

zip_files <- list.files(zip_dir, pattern = "\\.zip$", full.names = TRUE)
if (length(zip_files) == 0L)
  stop("Nessun archivio .zip trovato in ", zip_dir)

cat("Archivi EIOPA trovati:", length(zip_files), "\n")

# ------------------------------------------------------------------------------
# Estrazione di una singola curva
# ------------------------------------------------------------------------------
# NOTA sulla data di riferimento: viene ricavata dal nome del file INTERNO
# all'archivio (EIOPA_RFR_<YYYYMMDD>_Term_Structures.xlsx) e non dal nome dello
# zip. I nomi degli zip sono infatti storicamente incoerenti ("April 2016_.zip",
# "_September 2017.zip", "July 2018 .zip", "EIOPA_RFR_20260630.zip") e il
# parsing dei nomi di mese in inglese fallisce quando R gira in locale italiano
# (as.Date("December 2015", format = "%B %Y") restituisce NA). Il nome del file
# interno e' invece uniforme su tutti gli archivi.
# ------------------------------------------------------------------------------
extract_curve <- function(zip_path, n_tenor = 20L) {
  members <- utils::unzip(zip_path, list = TRUE)$Name
  target  <- grep("Term_Structures.*\\.xlsx$", members, value = TRUE)
  if (length(target) == 0L)
    stop("Nessun file Term_Structures in ", basename(zip_path))
  target <- target[1L]

  ref_str <- sub(".*EIOPA_RFR_(\\d{8})_Term_Structures.*", "\\1", basename(target))
  if (!grepl("^\\d{8}$", ref_str))
    stop("Data non ricavabile dal nome interno: ", target)
  ref_date <- as.Date(ref_str, format = "%Y%m%d")

  tmp_dir <- tempfile("eiopa_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, files = target, exdir = tmp_dir, junkpaths = TRUE)
  xlsx_path <- file.path(tmp_dir, basename(target))

  raw <- as.data.table(read.xlsx(xlsx_path, sheet = "RFR_spot_no_VA",
                                 colNames = FALSE, skipEmptyRows = FALSE,
                                 skipEmptyCols = FALSE))

  # Individua la cella "Euro" invece di assumere righe/colonne fisse.
  hit <- which(raw == "Euro", arr.ind = TRUE)
  if (nrow(hit) == 0L)
    stop("Colonna 'Euro' non trovata in ", basename(target))
  hdr_row <- hit[1L, "row"]
  eur_col <- hit[1L, "col"]
  mat_col <- eur_col - 1L   # colonna B: scadenze

  # Metadati: righe immediatamente sotto l'intestazione, etichetta in col. B
  meta_keys <- c("Coupon_freq", "LLP", "Convergence", "UFR", "alpha", "CRA")
  meta_vals <- sapply(meta_keys, function(k) {
    r <- which(raw[[mat_col]] == k)
    if (length(r) == 0L) return(NA_real_)
    suppressWarnings(as.numeric(raw[[eur_col]][r[1L]]))
  })

  # Dati: prime n_tenor righe sotto l'intestazione con scadenza 1..n_tenor
  mat_num  <- suppressWarnings(as.numeric(raw[[mat_col]]))
  rate_num <- suppressWarnings(as.numeric(raw[[eur_col]]))
  keep <- which(!is.na(mat_num) & mat_num %in% seq_len(n_tenor) &
                  seq_len(nrow(raw)) > hdr_row)
  keep <- keep[!duplicated(mat_num[keep])]
  ord  <- keep[order(mat_num[keep])]

  if (length(ord) != n_tenor)
    stop("Attese ", n_tenor, " scadenze, trovate ", length(ord),
         " in ", basename(target))
  if (anyNA(rate_num[ord]))
    stop("Tassi mancanti in ", basename(target))

  list(
    date  = ref_date,
    # da decimale a punti percentuali: 0.02592 -> 2.592
    rates = rate_num[ord] * 100,
    meta  = meta_vals
  )
}

# ------------------------------------------------------------------------------
# Ciclo su tutti gli archivi
# ------------------------------------------------------------------------------
curves <- vector("list", length(zip_files))
metas  <- vector("list", length(zip_files))

for (i in seq_along(zip_files)) {
  res <- extract_curve(zip_files[i], n_tenor)
  curves[[i]] <- data.table(TIME_PERIOD = res$date, t(res$rates))
  metas[[i]]  <- data.table(TIME_PERIOD = res$date, t(res$meta))
  if (i %% 25L == 0L || i == length(zip_files))
    cat("  elaborati", i, "/", length(zip_files), "archivi\n")
}

wide_dt <- rbindlist(curves)
setnames(wide_dt, c("TIME_PERIOD", paste0(seq_len(n_tenor), "Y")))
setorder(wide_dt, TIME_PERIOD)

meta_dt <- rbindlist(metas)
setnames(meta_dt, c("TIME_PERIOD", "Coupon_freq", "LLP", "Convergence",
                    "UFR", "alpha", "CRA"))
setorder(meta_dt, TIME_PERIOD)

# ------------------------------------------------------------------------------
# Controlli di qualita'
# ------------------------------------------------------------------------------
if (anyDuplicated(wide_dt$TIME_PERIOD))
  stop("Date duplicate negli archivi EIOPA.")

# I parametri strutturali della curva euro devono essere costanti sul campione.
stopifnot(all(meta_dt$LLP == 20, na.rm = TRUE))
stopifnot(all(meta_dt$CRA == 10, na.rm = TRUE))

# Completezza: nessun mese mancante fra il primo e l'ultimo.
expected <- seq(from = as.Date(format(min(wide_dt$TIME_PERIOD), "%Y-%m-01")),
                to   = as.Date(format(max(wide_dt$TIME_PERIOD), "%Y-%m-01")),
                by   = "month")
observed <- as.Date(format(wide_dt$TIME_PERIOD, "%Y-%m-01"))
missing_months <- setdiff(as.character(expected), as.character(observed))

cat("Mesi attesi: ", length(expected),
    " | mesi presenti: ", length(observed), "\n", sep = "")
if (length(missing_months) > 0L) {
  warning("Mesi mancanti: ", paste(missing_months, collapse = ", "))
} else {
  cat("Copertura completa: nessun mese mancante.\n")
}

# ------------------------------------------------------------------------------
# Scrittura
# ------------------------------------------------------------------------------
wb <- createWorkbook()
addWorksheet(wb, "PCA_Input")
writeData(wb, sheet = "PCA_Input", x = as.data.frame(wide_dt))
addWorksheet(wb, "Metadata")
writeData(wb, sheet = "Metadata", x = as.data.frame(meta_dt))
saveWorkbook(wb, file = output_file, overwrite = TRUE)

message("File creato: ", output_file)
message("Righe PCA_Input: ", nrow(wide_dt), " | Colonne: ", ncol(wide_dt))
message("Periodo: ", format(min(wide_dt$TIME_PERIOD), "%b %Y"),
        " - ", format(max(wide_dt$TIME_PERIOD), "%b %Y"))
