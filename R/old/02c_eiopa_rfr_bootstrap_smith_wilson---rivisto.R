
rm(list = ls())

# ==============================================================================
# PARTE 0 — SETUP CONDIVISO
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(reshape2)
})

root    <- dirname(getwd())   
dir_dat <- file.path(root, "dati")
dir_out <- file.path(root, "output", "02c_eiopa_rfr_bootstrap_smith_wilson")

# --- A.1 dati di input --------------------------------------------------------
swap_in <- data.table(openxlsx::read.xlsx(
  file.path(dir_dat, "02_swap_euribor6m_ric_dic2025.xlsx")))
cra_eur   <- 10 / 1e4          # CRA = 10 bps (EUR)
fsp       <- 20                # First Smoothing Point
max_tenor <- max(swap_in[, tenor])


DLT <- c(1:13,15,20)
m = 20

swap_no_cra <- as.numeric(swap_in[,swap_inputEUR]) - cra_eur

H_heart <- function(u, v, a) {                       # cuore di Wilson
  mn <- pmin(u, v); Mx <- pmax(u, v)
  a * mn - exp(-a * Mx) * sinh(a * mn)
}
W_fun <- function(u, v, a, om = omega) exp(-om * (u + v)) * H_heart(u, v, a)
G_heart <- function(v, u, a) ifelse(v <= u,          # dH/dv, per il forward
                                    a - a * exp(-a * u) * cosh(a * v),
                                    a * exp(-a * v) * sinh(a * u))


#------- costruiamo la matrice C (flussi di cassa)
C <- matrix(nrow = m,ncol = length(DLT),data = 0)



col_c <- 1
for(j in DLT){
    
  colj <- rep(swap_no_cra[col_c],j)
    
  colj[j] = 1+ colj[j]
  
  C[1:length(colj),col_c] <- colj
    
    
    col_c <- col_c +1 
}

