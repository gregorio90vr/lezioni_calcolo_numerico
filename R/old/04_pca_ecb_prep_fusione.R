suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(ggplot2)
  library(lubridate)
  library(scales)
})


# Parsing robusto delle date
parse_time_period <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (is.numeric(x)) return(openxlsx::convertToDate(x))
  x_chr <- trimws(as.character(x))
  x_num <- suppressWarnings(as.numeric(x_chr))
  out   <- as.Date(rep(NA_character_, length(x_chr)))
  is_serial <- !is.na(x_num)
  if (any(is_serial)) out[is_serial] <- openxlsx::convertToDate(x_num[is_serial])
  to_parse <- is.na(out) & nzchar(x_chr)
  if (any(to_parse))
    out[to_parse] <- as.Date(
      lubridate::parse_date_time(x_chr[to_parse],
                                 orders = c("Y-m-d","Y/m/d","m/d/Y","d/m/Y","m-d-Y","d-m-Y","mdy","dmy"),
                                 exact = FALSE))
  out
}



input_xlsx <- "../dati/04_ecb_spot.xlsx"
input_xlsx2 <- "../dati/04_ecb_spot--recenti.xlsx"

dta <- data.table(read.xlsx(input_xlsx))
dtb <- data.table(read.xlsx(input_xlsx2))

dta[, TIME_PERIOD := parse_time_period(TIME_PERIOD)]
dtb[, TIME_PERIOD := parse_time_period(TIME_PERIOD)]

dtb <- dtb[TIME_PERIOD <= as.Date("2026-03-30")]
dt <- rbind(dta,dtb)

write.xlsx(dt,"04_ecb_spot_last.xlsx")
