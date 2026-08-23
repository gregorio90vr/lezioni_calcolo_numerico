rm(list =ls())
require(data.table)
require(openxlsx)


# ---- PARAMETRI EIOPA EUR (sez. 9.2-9.4; Annex E) -----------------------------
UFR_ann <- 0.0330                  # Ultimate Forward Rate annuo composto
omega   <- log(1 + UFR_ann)        # intensita' UFR  omega = log(1+UFR)
LLP     <- 20                      # Last Liquid Point (anni)
CP      <- max(LLP + 40, 60)       # Convergence Point = 60 anni
CRA     <- 0.0010                  # Credit Risk Adjustment di default = 10 bps
tau     <- 1e-4                    # tolleranza di convergenza (1 bp)
a_min   <- 0.05                    # limite inferiore regolamentare per alpha
DLT     <- c(1:13,15,20)
m       <- 20
n       <- length(DLT)
u       <- c(1:m)
tmax    <- 150
#----loading data
file_path_input <- "C:\\Users\\gpelleg5\\OneDrive - Assicurazioni Generali S.p.A\\Desktop\\SmithWilson\\02_swap_euribor6m_ric_dic2025.xlsx"
swap_in <- data.table(read.xlsx(file_path_input))
swap_in_vector <- as.numeric(swap_in[,swap_inputEUR]) - CRA

file_path_input2 <- "C:\\Users\\gpelleg5\\OneDrive - Assicurazioni Generali S.p.A\\Desktop\\SmithWilson\\curvaeiopaufficiale.xlsx"
eiopa_ufficiale <- data.table(read.xlsx(file_path_input2))
eiopa_ufficiale_vector <- as.numeric(eiopa_ufficiale[,rfr_euro_dic25])


#---- costruiamo matrice C
c_col <- 1
C <- matrix(nrow = m,ncol = n,data =0)
for(j in DLT){
  colj <- rep(swap_in_vector[c_col],j)
  colj[j] <- colj[j] +1
  C[1:length(colj),c_col] <- colj
  c_col <- c_col + 1
}


#---- Costruiamo diagD

diagD <- diag(exp(-omega*u))

#--- costruiamo Q = diagD * Ct

Q = diagD %*% C
p = rep(1,n)
q = t(C) %*% exp(-omega*u)





#---- definiamo la funzione che risolve i q per ongi alpha fissato
H_heart <- function(t, u, a) {
  mn <- pmin(t, u)
  Mx <- pmax(t, u)
  a * mn - exp(-a * Mx) * sinh(a * mn)
}

dHdt <- function(t, u, a) {
  ifelse(t <= u,
         a - a * exp(-a * u) * cosh(a * t),
         a * exp(-a * t) * sinh(a * u))
}

d2Hdt2 <- function(t, u, a) {
  ifelse(t <= u,
         -a * a * exp(-a * u) * sinh(a * t),
         -a * a * exp(-a * t) * sinh(a * u))
}

Hmat <- function(t,u,a){
  Hout <- matrix(data = 0,nrow = length(t),ncol = length(u))
  for(i in c(1:length(t))){
    for(j in c(1:length(u))){
      Hout[i,j] <- H_heart(t[i],u[j],a)
    }
  }
  Hout
}

dHdvmat <- function(t,u,a){
  Hout2 <- matrix(data = 0,nrow = length(t),ncol = length(u))
  for(i in c(1:length(t))){
    for(j in c(1:length(u))){
      Hout2[i,j] <- dHdt(t[i],u[j],a)
    }
  }
  Hout2
}

d2Hdt2mat <- function(t,u,a){
  Hout <- matrix(data = 0,nrow = length(t),ncol = length(u))
  for(i in c(1:length(t))){
    for(j in c(1:length(u))){
      Hout[i,j] <- d2Hdt2(t[i],u[j],a)
    }
  }
  Hout
}


#---dipende solo da aplha
b_solve <- function(a){
  bout <- rep(0,m)
  
  bb <- p-q
  AA <- t(Q) %*% Hmat(u,u,a) %*% Q
  
  R <- chol(AA)
  
  y <- forwardsolve(t(R), bb)
  bout <- backsolve(R, y)
  
  bout
}


zeta <- function(a){
  b <- b_solve(a)
  zeta <- Q %*% b
  as.numeric(zeta)
}
rfr <- function(a){
  b <- b_solve(a)
  zeta <- Q %*% b

  pt <- (1 + rowSums(Hmat(c(1:tmax),u,a) %*% diag(as.numeric(zeta)))) *exp(-omega*c(1:tmax))
  pt <- (1 + Hmat(c(1:tmax),u,a) %*% zeta) *exp(-omega*c(1:tmax))
  pt <- as.numeric(pt)
  
  tb_finale <- data.table(
    tenor = c(1:tmax),
    discount_factor = pt,
    r_c             = (-1/c(1:tmax))*log(pt),
    fwd_c           = as.numeric(fwd(a)),
    r_ann           = pt^(-1/c(1:tmax))-1,
    fwd_ann         = exp(as.numeric(fwd(a))) - 1,
    rfr_eiopa       = eiopa_ufficiale_vector,
    delta_bps       = (eiopa_ufficiale_vector-(pt^(-1/c(1:tmax))-1))*1e4
  )
  
  tb_finale
}

fwd <- function(a){
  
  #--- troviamo i coefficineti per la scomposizione di wilson
  b <- b_solve(a)
  zeta <- Q %*% b
  
  
  out <- omega - (dHdvmat(c(1:tmax),u,a) %*% zeta) / (1 + Hmat(c(1:tmax),u,a) %*% zeta)
  out
}

dfwd_dt <- function(a){
  
  # coefficienti Wilson
  b <- b_solve(a)
  zeta <- Q %*% b
  
  ft <- 1 + Hmat(1:tmax, u, a) %*% zeta
  
  Ht  <- dHdvmat(1:tmax, u, a) %*% zeta
  Htt <- d2Hdt2mat(1:tmax, u, a) %*% zeta
  
  out <- (Htt * ft - Ht^2) / ft^2
  
  out
}

fwd(.2)-omega
g <-function(a){
  out <-fwd(a)-omega
  out[CP]-tau
} 


#---------bisezione
xx <- seq(from = 0.05,to = .5,by =0.01)
cc <- 1
outxx <- NULL
for(a in xx){
  outxx[cc] <- g(a)
  cc <- cc +1
}
plot(xx,outxx)

# Estremi iniziali
alpha_start <- 0.05
alpha_end   <- .1

# Valutazione della funzione agli estremi
v1 <- g(alpha_start)
v2 <- g(alpha_end)

# Verifica che la radice sia effettivamente contenuta nell'intervallo
if (v1 * v2 > 0) {
  stop("L'intervallo scelto non contiene una radice.")
}

# Parametri del metodo
toll <- 1e-16
errore <- Inf
cont <- 0

# Metodo di bisezione
while (errore > toll) {
  
  # Punto medio
  valore_medio <- (alpha_start + alpha_end) / 2
  g_valore_medio <- g(valore_medio)
  
  # Errore corrente
  errore <- abs(g_valore_medio)
  
  
  # Aggiornamento dell'intervallo
  if (g_valore_medio * v1 > 0) {
    
    alpha_start <- valore_medio
    v1 <- g_valore_medio
    
  } else {
    
    alpha_end <- valore_medio
    v2 <- g_valore_medio
  }
  
  cont <- cont + 1
  
  alpha_bisezione <- (alpha_start + alpha_end) / 2
  
  cat(
    "Iter =", cont,
    "| alpha =", alpha_bisezione,
    "| g(alpha) =", g(alpha_bisezione),
    "| errore =", errore,
    "\n"
  )
  
}

# # Approssimazione finale della radice
# 
# 
# cat("\nRadice =", radice, "\n")
# cat("Iterazioni =", cont, "\n")
# cat("g(radice) =", g(radice), "\n")
# 
# 
# 
# 
#===========================================================
# dH / da
#===========================================================

dHda <- function(t, u, a){
  
  mn <- pmin(t,u)
  mx <- pmax(t,u)
  
  mn -
    exp(-a*mx) *
    (
      -mx * sinh(a*mn) +
        mn * cosh(a*mn)
    )
}

dHdamat <- function(t,u,a){
  
  out <- matrix(0,length(t),length(u))
  
  for(i in seq_along(t)){
    for(j in seq_along(u)){
      out[i,j] <- dHda(t[i],u[j],a)
    }
  }
  
  out
}


#===========================================================
# d/dalpha [ dH/dt ]
#===========================================================

ddHdt_da <- function(t,u,a){
  
  ifelse(
    t <= u,
    
    1 -
      exp(-a*u)*cosh(a*t) +
      a*u*exp(-a*u)*cosh(a*t) -
      a*t*exp(-a*u)*sinh(a*t),
    
    exp(-a*t)*sinh(a*u) +
      a*(-t)*exp(-a*t)*sinh(a*u) +
      a*u*exp(-a*t)*cosh(a*u)
  )
}

ddHdt_damat <- function(t,u,a){
  
  out <- matrix(0,length(t),length(u))
  
  for(i in seq_along(t)){
    for(j in seq_along(u)){
      out[i,j] <- ddHdt_da(t[i],u[j],a)
    }
  }
  
  out
}


#===========================================================
# db/da
#===========================================================

db_da <- function(a){
  
  H  <- Hmat(u,u,a)
  dH <- dHdamat(u,u,a)
  
  M  <- t(Q) %*% H  %*% Q
  dM <- t(Q) %*% dH %*% Q
  
  b <- b_solve(a)
  
  -solve(M, dM %*% b)
}


#===========================================================
# dzeta/da
#===========================================================

dzeta_da <- function(a){
  
  Q %*% db_da(a)
}


#===========================================================
# derivata analitica del forward al CP
#===========================================================

dfwd_dalpha <- function(a){
  
  zeta  <- Q %*% b_solve(a)
  dzeta <- dzeta_da(a)
  
  Hcp      <- Hmat(CP,u,a)
  dHcp_da  <- dHdamat(CP,u,a)
  
  Ht       <- dHdvmat(CP,u,a)
  dHt_da   <- ddHdt_damat(CP,u,a)
  
  A <- as.numeric(Ht %*% zeta)
  
  B <- as.numeric(
    1 + Hcp %*% zeta
  )
  
  dA <- as.numeric(
    dHt_da %*% zeta +
      Ht %*% dzeta
  )
  
  dB <- as.numeric(
    dHcp_da %*% zeta +
      Hcp %*% dzeta
  )
  
  -(dA*B - A*dB)/(B^2)
}


#===========================================================
# g(alpha)
#===========================================================

g <- function(a){
  
  as.numeric(
    fwd(a)[CP] - omega - tau
  )
}


#===========================================================
# dg(alpha)
#===========================================================

dg <- function(a){
  
  as.numeric(
    dfwd_dalpha(a)
  )
}

# Punto iniziale
alpha <- 0.05

toll <- 1e-15
errore <- Inf
cont <- 0
max_iter <- 100

while (errore > toll && cont < max_iter) {

  g_alpha <- g(alpha)
  dg_alpha <- dg(alpha)

  # if (abs(dg_alpha) < 1e-14) {
  #   stop("Derivata numerica troppo vicina a zero.")
  # }

  alpha_new <- alpha - g_alpha / dg_alpha

  errore <- g(alpha_new)

  alpha <- alpha_new
  cont <- cont + 1

  cat(
    "Iter =", cont,
    "| alpha =", alpha,
    "| g(alpha) =", g(alpha),
    "| errore =", errore,
    "\n"
  )
}

alpha_newton <- alpha


rfr_finale <- rfr(alpha_bisezione)

plot(
  rfr_finale[, tenor],
  rfr_finale[, r_ann],
  type = "l",
  col = "blue",
  lwd = 2,
  xlab = "Tenor",
  ylab = "Rate",
  main = "Smith-Wilson Curve"
)

lines(
  rfr_finale[, tenor],
  rfr_finale[, fwd_ann],
  col = "red",
  lwd = 2
)

legend(
  "bottomright",
  legend = c("Spot", "Forward"),
  col = c("blue", "red"),
  lwd = 2,
  bty = "n"
)