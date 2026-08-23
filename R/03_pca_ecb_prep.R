# ==============================================================================
# ORIGINE DEI DATI
# ------------------------------------------------------------------------------
# I dati provengono dall'ECB Data Portal (https://data.ecb.europa.eu)
# Dataset: YC - Euro area yield curves
#
# La serie utilizzata e' la SPOT RATE CURVE stimata dalla BCE su un campione
# composto esclusivamente da titoli di Stato dell'area Euro con rating AAA
# (il merito creditizio piu' elevato, es. Germania, Paesi Bassi, Finlandia).
#
# La curva e' stimata giornalmente con il modello di Svensson (estensione a
# 6 parametri del modello Nelson-Siegel), in regime di capitalizzazione
# continua. I tassi sono espressi in percentuale annua.
#
# Struttura della chiave ECB (es. scadenza 1Y):
#   YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_1Y
#   YC  = dataset Yield Curve
#   B   = frequenza Business day (giornaliera)
#   U2  = area Euro
#   EUR = valuta Euro
#   4F  = provider (BCE)
#   G_N_A = Government bond, Nominal, rating AAA
#   SV  = metodo di stima Svensson
#   C   = capitalizzazione Continua
#   YM  = minimizzazione dell'errore sul rendimento (Yield error Minimisation)
#   SR  = Spot Rate (non forward, non par)
#   1Y  = scadenza 1 anno (da 1Y a 20Y usate qui; il dataset ECB ne pubblica
#         fino a 30Y, e include anche BETA0-3/TAU1-2 e le serie forward/par:
#         tutte scartate dal filtro su valid_keys)
#
# Dati disponibili dal 06/09/2004. Fonte: BCE, liberamente scaricabili.
#
# INPUT: l'export ECB per il 2026 arriva in un file separato da quello
# storico (2004-2025), perche' scaricato in un secondo momento dal portale.
# Questo script legge ENTRAMBI i CSV grezzi e li unisce in un'unica serie
# continua. I due file grezzi sono export SDMX completi del dataflow YC
# (39 colonne, ~100 serie diverse per data: BETA0-3, TAU1-2, forward, par,
# spot da 1Y a 30Y) e pesano diversi GB: si selezionano solo le 3 colonne
# necessarie (KEY, TIME_PERIOD, OBS_VALUE) direttamente in lettura con
# fread(..., select = ...), che scarta le altre colonne durante il parsing
# senza mai allocarle in memoria (verificato: 3.5GB letti in ~4s, <150MB di
# RAM, anche su una macchina con poca memoria libera).
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  }
})

input_file_name_a <- "../dati/03_dati_originali_ecb_2004_2025.csv"       # storico 2004-2025
input_file_name_b <- "../dati/03_dati_originali_ecb_2026_finoLuglio.csv" # 2026, scaricato a parte

# File 1: campione principale per la PCA, tutte le date fino a fine_periodo
output_file_name_merged <- "../dati/03_ecb_spot.xlsx"
fine_periodo <- as.Date("2026-06-30")

# File 2: singola curva "fuori campione" per la ricostruzione (Sezione 4 di
# 03b_pca_ecb.R). Nota: il 31/07/2026 non e' pubblicato nel file di input
# (ultimo giorno disponibile lavorativo: 30/07/2026), quindi si usa quello.
output_file_name_oos <- "../dati/03b_ecb_spot_20260730.xlsx"
data_oos <- as.Date("2026-07-30")

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grep(file_arg, args_all)])

if (length(script_path) > 0) {
  base_dir <- dirname(normalizePath(script_path[1], winslash = "/", mustWork = TRUE))
} else {
  base_dir <- getwd()
}

resolve_path <- function(rel_path) {
  candidate <- file.path(base_dir, rel_path)
  if (file.exists(candidate)) return(candidate)
  candidate <- file.path(getwd(), rel_path)
  if (file.exists(candidate)) return(candidate)
  stop(
    paste0(
      "Input file non trovato: ", rel_path,
      "\nControlla che il file sia nella cartella dello script o nella working directory.",
      "\nbase_dir=", base_dir, " | getwd()=", getwd()
    )
  )
}

input_file_a <- resolve_path(input_file_name_a)
input_file_b <- resolve_path(input_file_name_b)
output_file_merged <- file.path(base_dir, output_file_name_merged)
output_file_oos     <- file.path(base_dir, output_file_name_oos)

# Le 20 scadenze spot AAA usate per la PCA (esclude BETA0-3, TAU1-2, forward,
# par, e le scadenze oltre 20Y).
valid_keys <- paste0("YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_", 1:20, "Y")
ordered_maturities <- paste0(1:20, "Y")

# ------------------------------------------------------------------
# Lettura di un export SDMX grezzo, filtrato alle 20 scadenze spot AAA
# ------------------------------------------------------------------
read_ecb_long <- function(file) {
  dt <- fread(file, select = c("KEY", "TIME_PERIOD", "OBS_VALUE"))
  dt <- dt[KEY %chin% valid_keys]
  dt[, `:=`(
    TIME_PERIOD = as.Date(TIME_PERIOD),
    MATURITY    = gsub("^.*SR_", "", KEY),
    OBS_VALUE   = as.numeric(OBS_VALUE)
  )]
  dt[, KEY := NULL]
  dt[]
}

cat("Lettura", input_file_a, "...\n")
long_a <- read_ecb_long(input_file_a)
cat("  ", nrow(long_a), "osservazioni,",
    format(min(long_a$TIME_PERIOD)), "-", format(max(long_a$TIME_PERIOD)), "\n")

cat("Lettura", input_file_b, "...\n")
long_b <- read_ecb_long(input_file_b)
cat("  ", nrow(long_b), "osservazioni,",
    format(min(long_b$TIME_PERIOD)), "-", format(max(long_b$TIME_PERIOD)), "\n")

# Unione: se le date si sovrappongono fra i due file si tiene l'ultima
# osservazione per (data, scadenza), stesso criterio gia' usato altrove
# nella pipeline per gestire eventuali doppioni.
long_dt <- rbindlist(list(long_a, long_b))
setorder(long_dt, TIME_PERIOD, MATURITY)
long_dt <- long_dt[, .(OBS_VALUE = tail(OBS_VALUE, 1L)), by = .(TIME_PERIOD, MATURITY)]

cat("Totale dopo unione:", nrow(long_dt), "osservazioni,",
    format(min(long_dt$TIME_PERIOD)), "-", format(max(long_dt$TIME_PERIOD)), "\n")

# ------------------------------------------------------------------
# File 1 — campione principale, tutte le date fino a fine_periodo
# ------------------------------------------------------------------
long_main <- long_dt[TIME_PERIOD <= fine_periodo]
wide_main <- dcast(long_main, TIME_PERIOD ~ MATURITY, value.var = "OBS_VALUE")
wide_main <- wide_main[, c("TIME_PERIOD", intersect(ordered_maturities, names(wide_main))), with = FALSE]
setorder(wide_main, TIME_PERIOD)

wb <- createWorkbook()
addWorksheet(wb, "PCA_Input")
writeData(wb, sheet = "PCA_Input", x = as.data.frame(wide_main))
addWorksheet(wb, "Long_Format")
writeData(wb, sheet = "Long_Format", x = as.data.frame(long_main))
saveWorkbook(wb, file = output_file_merged, overwrite = TRUE)

message("File creato: ", output_file_merged)
message("Righe PCA_Input: ", nrow(wide_main), " | Colonne: ", ncol(wide_main),
        " | fino al ", format(max(wide_main$TIME_PERIOD)))

# ------------------------------------------------------------------
# File 2 — singola curva fuori campione, per la ricostruzione out-of-sample
# ------------------------------------------------------------------
if (!(data_oos %in% long_dt$TIME_PERIOD)) {
  stop("Curva del ", format(data_oos), " non trovata nei dati di input. ",
       "Date piu' recenti disponibili: ",
       paste(format(tail(sort(unique(long_dt$TIME_PERIOD)), 3)), collapse = ", "))
}

long_oos <- long_dt[TIME_PERIOD == data_oos]
wide_oos <- dcast(long_oos, TIME_PERIOD ~ MATURITY, value.var = "OBS_VALUE")
wide_oos <- wide_oos[, c("TIME_PERIOD", intersect(ordered_maturities, names(wide_oos))), with = FALSE]

wb2 <- createWorkbook()
addWorksheet(wb2, "PCA_Input")
writeData(wb2, sheet = "PCA_Input", x = as.data.frame(wide_oos))
saveWorkbook(wb2, file = output_file_oos, overwrite = TRUE)

message("File creato: ", output_file_oos, " (curva del ", format(data_oos), ")")
