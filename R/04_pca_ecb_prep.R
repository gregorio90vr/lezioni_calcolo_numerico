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
#   1Y  = scadenza 1 anno (da 1Y a 20Y nel dataset)
#
# Dati disponibili dal 06/09/2004. Fonte: BCE, liberamente scaricabili.
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  }
})

input_file_name <- "../dati/data.csv"       # copia data.csv in LaboratorioPCA/dati/
output_file_name <- "../dati/pca_input_curves_1Y_20Y.xlsx"

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grep(file_arg, args_all)])

if (length(script_path) > 0) {
  base_dir <- dirname(normalizePath(script_path[1], winslash = "/", mustWork = TRUE))
} else {
  base_dir <- getwd()
}

input_file <- file.path(base_dir, input_file_name)
output_file <- file.path(base_dir, output_file_name)

if (!file.exists(input_file)) {
  candidate <- file.path(getwd(), input_file_name)
  if (file.exists(candidate)) {
    input_file <- candidate
  }
}

if (!file.exists(input_file)) {
  stop(
    paste0(
      "Input file non trovato: ", input_file_name,
      "\nControlla che il file sia nella cartella dello script o nella working directory.",
      "\nbase_dir=", base_dir,
      " | getwd()=", getwd()
    )
  )
}

raw_dt <- fread(input_file)

# Handle both lowercase/uppercase ECB column names.
key_col <- names(raw_dt)[tolower(names(raw_dt)) == "key"][1]
date_col <- names(raw_dt)[tolower(names(raw_dt)) == "time_period"][1]
value_col <- names(raw_dt)[tolower(names(raw_dt)) == "obs_value"][1]

if (any(is.na(c(key_col, date_col, value_col)))) {
  stop("Missing required columns: key/KEY, TIME_PERIOD, OBS_VALUE")
}

raw_dt[, MATURITY := fifelse(
  grepl("([1-9]|1[0-9]|20)Y$", get(key_col)),
  sub(".*\\.(([1-9]|1[0-9]|20)Y)$", "\\1", get(key_col)),
  NA_character_
)]

# Define the valid KEY patterns for filtering
valid_keys <- paste0("YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_", c(1:20), "Y")

# Filter rows based on the valid KEY values
raw_dt0 <- copy(raw_dt)
raw_dt <- raw_dt[get(key_col) %in% valid_keys]

long_dt <- raw_dt[,
  .(
    TIME_PERIOD = as.Date(get(date_col)),
    MATURITY,
    OBS_VALUE = as.numeric(get(value_col))
  )
]
long_dt[,MATURITY:=gsub("YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_","",MATURITY)]
setorder(long_dt, TIME_PERIOD, MATURITY)
long_dt <- long_dt[, .(OBS_VALUE = tail(OBS_VALUE, 1L)), by = .(TIME_PERIOD, MATURITY)]

wide_dt <- dcast(long_dt, TIME_PERIOD ~ MATURITY, value.var = "OBS_VALUE")

ordered_maturities <- paste0(1:20, "Y")
available_maturities <- intersect(ordered_maturities, names(wide_dt))

wide_dt <- wide_dt[, c("TIME_PERIOD", available_maturities), with = FALSE]
setorder(wide_dt, TIME_PERIOD)

wb <- createWorkbook()
addWorksheet(wb, "PCA_Input")
writeData(wb, sheet = "PCA_Input", x = as.data.frame(wide_dt))
addWorksheet(wb, "Long_Format")
writeData(wb, sheet = "Long_Format", x = as.data.frame(long_dt))
saveWorkbook(wb, file = output_file, overwrite = TRUE)

message("File creato: ", output_file)
message("Righe PCA_Input: ", nrow(wide_dt), " | Colonne: ", ncol(wide_dt))
