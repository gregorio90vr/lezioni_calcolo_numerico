
rm(list = ls())
require(data.table)
require(openxlsx)


#------ caricamento dati

swap_eur_dec2025 <- data.table(read.xlsx("../dati/01_swap_euribor6m_ric_dic2025.xlsx"))#data.table(read.csv("~/SviluppoCodice/01_eiopa_rfr_bootstrap/INPUT_EIOPA_YE25.csv"))
cra_eur <- 10/1e4 #10pbs

#------ bootstrap per le scadenze vicine (dispensa Sez. 3.3: la condizione par e il bootstrap)
fsp                       <- 20 # First Smoothing Point (FSP)
max_tenor                 <- max(swap_eur_dec2025[,tenor])
swap_eur_dec2025_post_cra <- rep(0,max_tenor)
for(i in swap_eur_dec2025[,tenor]){
  swap_eur_dec2025_post_cra[i] <- swap_eur_dec2025[tenor==i,swap_inputEUR] - cra_eur
}

#------ creiamo i vari vettori fino a max_tenor (oltre FSP perchè serve per calcolare i tassi per LLFR)
dtk   <- rep(0,max_tenor)
rc    <- rep(0,max_tenor)
rann  <- rep(0,max_tenor)
fwd_c <- rep(0,max_tenor)
fwd_ann <- rep(0,max_tenor)

# Step 1-2a (Annex D.4-D.5): tenor consecutivi 1..13, sostituzione in avanti.
# L e' triangolare inferiore -> si ricava un fattore di sconto alla volta
# usando solo quelli gia' noti, senza invertire una matrice densa (dispensa,
# par. "Una lettura matriciale").
n_data <- 13 # par consecutivi
L = matrix(nrow = n_data,ncol = n_data,data = 0)

for (i in c(1:n_data)){
  ncol_loc <- i
  for(j in c(1:ncol_loc)){
    if(i==j){
      L[i, j] <- 1 + swap_eur_dec2025_post_cra[i]
    }else{
      L[i, j] <- swap_eur_dec2025_post_cra[i]
    }
  }
}

#termine noto
b = rep(1,n_data)

dtk_bootstrap    <- solve(L, b) # fattori di sconto
rc_bootstrap     <- -1 * log(dtk_bootstrap)/c(1:n_data)
rann_bootstrap   <- exp(rc_bootstrap) - 1
fwd_c_bootstrap  <- rc_bootstrap[2:n_data]*c(2:n_data) - rc_bootstrap[1:(n_data-1)]*c(1:(n_data-1)) # dovrebbe essere diviso la differenza tra i tenor che sono 1

dtk[1:13] <- dtk_bootstrap
rc[1:13] <- rc_bootstrap
rann[1:13] <- rann_bootstrap
fwd_c[2:13] <- fwd_c_bootstrap
fwd_ann[2:13] <- exp(fwd_c_bootstrap)-1

curve <- data.table(tenor = c(1:max_tenor),swap_wo_cra = swap_eur_dec2025_post_cra,dtk = dtk,rc = rc,rann = rann,fwd_c = fwd_c,fwd_ann = fwd_ann)

#------ determinazione risk-free per tenor non CONSECUTIVI (dispensa Sez. 3.4-3.5):
# equazione non lineare phi(f)=0 (Annex D.6, eq. boot-nl) nell'unica incognita
# f = forward costante nel gap; si risolve con Newton (Sez. 3.5), che richiede
# anche la derivata analitica derivata_phi = phi'.

phi <- function(f,s2,s1,gap,dtk){
  dstar    <- (1+f)^(-gap)
  phi_out  <- s2*(1-dstar)/f + dstar + ((s2- s1)/(s1))*((1-dtk)/(dtk)) - 1
  phi_out
}

derivata_phi <- function(f,s2,s1,gap){
  dstar     <- (1+f)^(-gap)
  dstar_der <- -gap*((1+f)^(-gap-1))
  phi_out   <- s2*((-f*dstar_der-(1-dstar))/(f^2))+dstar_der
  phi_out
}



#--- TK =14 -- Newton: gap 13->15 (g=2), tenor noti 13 e 15
tk                <- 14
swap_rate_tk      <- swap_eur_dec2025_post_cra[15]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[13]
g = 2

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0 #(è un fwd annualizzato)
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}

dt14 <- dtk_prec*((1+f_star)^-1)
rc_14     <- -1 * log(dt14)/tk
rann_14   <- exp(rc_14) - 1

curve[14,dtk := dt14]
curve[14,rc := rc_14]
curve[14,rann := rann_14]
curve[14,fwd_c := 14*rc_14-13*curve[13,rc]]
curve[14,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK =15 -- Step 2a per un tenor isolato: S_15 e' noto da mercato, si
# ricava d_15 per sostituzione in avanti (stessa logica della matrice L)

tk = 15
dt15 <- (1-swap_eur_dec2025_post_cra[15]*sum(curve[1:14,dtk]))/(1+swap_eur_dec2025_post_cra[15])
rc_15     <- -1 * log(dt15)/tk
rann_15   <- exp(rc_15) - 1


curve[tk,dtk := dt15]
curve[tk,rc := rc_15]
curve[tk,rann := rann_15]
curve[tk,fwd_c := tk*rc_15-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK =16 -- Newton: gap 15->20 (g=5), tenor noti 15 e 20

tk                <- 16
swap_rate_tk      <- swap_eur_dec2025_post_cra[20]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[15]  #swap noti
g = 20-15

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}

dt16 <- dtk_prec*((1+f_star)^-1)
rc_16     <- -1 * log(dt16)/tk
rann_16   <- exp(rc_16) - 1

curve[tk,dtk := dt16]
curve[tk,rc := rc_16]
curve[tk,rann := rann_16]
curve[tk,fwd_c := tk*rc_16-(tk-1)*curve[tk,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)



#--- TK =17 -- stesso gap 15->20: f_star gia' trovato da Newton (TK=16) resta
# costante nel gap (eq. cf), qui applichiamo solo la composizione (i_gap=2)

tk                <- 17
dt17 <- dtk_prec*((1+f_star)^-2)
rc_17     <- -1 * log(dt17)/tk
rann_17   <- exp(rc_17) - 1

curve[tk,dtk := dt17]
curve[tk,rc := rc_17]
curve[tk,rann := rann_17]
curve[tk,fwd_c := tk*rc_17-(tk-1)*curve[tk,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)


#--- TK =18 -- stesso gap 15->20, stesso f_star (eq. cf), i_gap=3

tk                <- 18
dt18 <- dtk_prec*((1+f_star)^-3)
rc_18     <- -1 * log(dt18)/tk
rann_18   <- exp(rc_18) - 1

curve[tk,dtk := dt18]
curve[tk,rc := rc_18]
curve[tk,rann := rann_18]
curve[tk,fwd_c := tk*rc_18-(tk-1)*curve[tk,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK =19 -- stesso gap 15->20, stesso f_star (eq. cf), i_gap=4

tk                <- 19
dt19 <- dtk_prec*((1+f_star)^-4)
rc_19     <- -1 * log(dt19)/tk
rann_19   <- exp(rc_19) - 1

curve[tk,dtk := dt19]
curve[tk,rc := rc_19]
curve[tk,rann := rann_19]
curve[tk,fwd_c := tk*rc_19-(tk-1)*curve[tk,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)


#--- TK = 20 -- Step 2a per un tenor isolato: S_20 e' noto da mercato (FSP)

tk = 20
dt20 <- (1-swap_eur_dec2025_post_cra[20]*sum(curve[1:19,dtk]))/(1+swap_eur_dec2025_post_cra[20])
rc_20     <- -1 * log(dt20)/tk
rann_20   <- exp(rc_20) - 1


curve[tk,dtk := dt20]
curve[tk,rc := rc_20]
curve[tk,rann := rann_20]
curve[tk,fwd_c := tk*rc_20-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)


#--- TK = 21 -- Newton: gap 20->25 (g=5), tenor noti 20 (FSP) e 25

tk                <- 21
swap_rate_tk      <- swap_eur_dec2025_post_cra[25]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[20]  #swap noti
g = 25-20

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}

curve[tk,dtk := dtk_prec*((1+f_star)^-1)]
curve[tk,rc := -1 * log(curve[tk,dtk])/tk]
curve[tk,rann := exp(curve[tk,rc]) - 1]
curve[tk,fwd_c := tk*curve[tk,rc]-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#---------------------------------
#tk=22-24 -- restanti tenor nel gap 20->25: stesso f_star (eq. cf), i_gap=2,3,4
counter = 1
dtk_prec <- curve[20,dtk]
for(ii in c(22:24)){
  
  tk = ii
  i_gap = ii-20
  dtloc <- dtk_prec*((1+f_star)^-i_gap)
  rc_loc     <- -1 * log(dtloc)/tk
  rann_loc   <- exp(rc_loc) - 1
  
  curve[tk,dtk := dtloc]
  curve[tk,rc := rc_loc]
  curve[tk,rann := rann_loc]
  curve[tk,fwd_c := tk*rc_loc-(tk-1)*curve[tk-1,rc]]
  curve[tk,fwd_ann := exp(fwd_c)-1]
  
  
  
}
print(curve)


#--- TK = 25 -- Step 2a per un tenor isolato: S_25 e' noto da mercato (par condition)
tk = 25
d_par <- (1-swap_eur_dec2025_post_cra[25]*sum(curve[1:(tk-1),dtk]))/(1+swap_eur_dec2025_post_cra[25])
rc_par     <- -1 * log(d_par)/tk
rann_par   <- exp(rc_par) - 1


curve[tk,dtk := d_par]
curve[tk,rc := rc_par]
curve[tk,rann := rann_par]
curve[tk,fwd_c := tk*rc_par-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK = 26 -- Newton: gap 25->30 (g=5), tenor noti 25 e 30

tk                <- 26
swap_rate_tk      <- swap_eur_dec2025_post_cra[30]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[25]  #swap noti
g = 30-25

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}


curve[tk,dtk := dtk_prec*((1+f_star)^-1)]
curve[tk,rc := -1 * log(curve[tk,dtk])/tk]
curve[tk,rann := exp(curve[tk,rc]) - 1]
curve[tk,fwd_c := tk*curve[tk,rc]-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]


print(curve)

# #---------------------------------
# #tk=27-29 -- restanti tenor nel gap 25->30: stesso f_star (eq. cf), i_gap=2,3,4

dtk_prec <- curve[25,dtk]
for(ii in c(27:29)){
  
  tk = ii
  i_gap = ii-25
  dtloc <- dtk_prec*((1+f_star)^-i_gap)
  rc_loc     <- -1 * log(dtloc)/tk
  rann_loc   <- exp(rc_loc) - 1
  
  curve[tk,dtk := dtloc]
  curve[tk,rc := rc_loc]
  curve[tk,rann := rann_loc]
  curve[tk,fwd_c := tk*rc_loc-(tk-1)*curve[tk-1,rc]]
  curve[tk,fwd_ann := exp(fwd_c)-1]
  
  
  
}
print(curve)

#--- TK = 30 -- Step 2a per un tenor isolato: S_30 e' noto da mercato (par condition)
tk = 30
d_par <- (1-swap_eur_dec2025_post_cra[tk]*sum(curve[1:(tk-1),dtk]))/(1+swap_eur_dec2025_post_cra[tk])
rc_par     <- -1 * log(d_par)/tk
rann_par   <- exp(rc_par) - 1


curve[tk,dtk := d_par]
curve[tk,rc := rc_par]
curve[tk,rann := rann_par]
curve[tk,fwd_c := tk*rc_par-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK = 31 -- Newton: gap 30->40 (g=10), tenor noti 30 e 40

tk                <- 31
swap_rate_tk      <- swap_eur_dec2025_post_cra[40]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[30]  #swap noti
g = 40-30

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}


curve[tk,dtk := dtk_prec*((1+f_star)^-1)]
curve[tk,rc := -1 * log(curve[tk,dtk])/tk]
curve[tk,rann := exp(curve[tk,rc]) - 1]
curve[tk,fwd_c := tk*curve[tk,rc]-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]


print(curve)

# #---------------------------------
# #tk=32-39 -- restanti tenor nel gap 30->40: stesso f_star (eq. cf), i_gap=2..9

dtk_prec <- curve[30,dtk]
for(ii in c(32:39)){
  
  tk = ii
  i_gap = ii-30
  dtloc <- dtk_prec*((1+f_star)^-i_gap)
  rc_loc     <- -1 * log(dtloc)/tk
  rann_loc   <- exp(rc_loc) - 1
  
  curve[tk,dtk := dtloc]
  curve[tk,rc := rc_loc]
  curve[tk,rann := rann_loc]
  curve[tk,fwd_c := tk*rc_loc-(tk-1)*curve[tk-1,rc]]
  curve[tk,fwd_ann := exp(fwd_c)-1]
  
  
  
}
print(curve)

#--- TK = 40 -- Step 2a per un tenor isolato: S_40 e' noto da mercato (par condition)
tk = 40
d_par <- (1-swap_eur_dec2025_post_cra[tk]*sum(curve[1:(tk-1),dtk]))/(1+swap_eur_dec2025_post_cra[tk])
rc_par     <- -1 * log(d_par)/tk
rann_par   <- exp(rc_par) - 1


curve[tk,dtk := d_par]
curve[tk,rc := rc_par]
curve[tk,rann := rann_par]
curve[tk,fwd_c := tk*rc_par-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#--- TK = 41 -- Newton: gap 40->50 (g=10), tenor noti 40 e 50

tk                <- 41
swap_rate_tk      <- swap_eur_dec2025_post_cra[50]
swap_rate_tk_prec <- swap_eur_dec2025_post_cra[40]  #swap noti
g = 50-40

tk_prec = tk - 1

dtk_prec <- curve[tk_prec,dtk]
f0 <- exp(curve[tk_prec,fwd_c])-1
# f0 <- curve[tk_prec,
errore <- 1

f_star <- f0
while(errore > 1e-16){
  fprev <- f_star
  f_star <- f_star - phi(f_star,swap_rate_tk,swap_rate_tk_prec,g,dtk_prec)/derivata_phi(f_star,swap_rate_tk,swap_rate_tk_prec,g)
  print(f_star)
  errore <- abs(fprev-f_star)
}


curve[tk,dtk := dtk_prec*((1+f_star)^-1)]
curve[tk,rc := -1 * log(curve[tk,dtk])/tk]
curve[tk,rann := exp(curve[tk,rc]) - 1]
curve[tk,fwd_c := tk*curve[tk,rc]-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]


print(curve)

# #---------------------------------
# #tk=42-49 -- restanti tenor nel gap 40->50: stesso f_star (eq. cf), i_gap=2..9

dtk_prec <- curve[40,dtk]
for(ii in c(42:49)){
  
  tk = ii
  i_gap = ii-40
  dtloc <- dtk_prec*((1+f_star)^-i_gap)
  rc_loc     <- -1 * log(dtloc)/tk
  rann_loc   <- exp(rc_loc) - 1
  
  curve[tk,dtk := dtloc]
  curve[tk,rc := rc_loc]
  curve[tk,rann := rann_loc]
  curve[tk,fwd_c := tk*rc_loc-(tk-1)*curve[tk-1,rc]]
  curve[tk,fwd_ann := exp(fwd_c)-1]
  
  
  
}
print(curve)

#--- TK = 50 -- Step 2a per un tenor isolato: S_50 e' noto da mercato (par condition,
# ultimo tenor liquido usato per l'LLFR)
tk = 50
d_par <- (1-swap_eur_dec2025_post_cra[tk]*sum(curve[1:(tk-1),dtk]))/(1+swap_eur_dec2025_post_cra[tk])
rc_par     <- -1 * log(d_par)/tk
rann_par   <- exp(rc_par) - 1


curve[tk,dtk := d_par]
curve[tk,rc := rc_par]
curve[tk,rann := rann_par]
curve[tk,fwd_c := tk*rc_par-(tk-1)*curve[tk-1,rc]]
curve[tk,fwd_ann := exp(fwd_c)-1]

print(curve)

#------------------------------------------------------------------

#------------------------------ ESTRAPOLAZIONE (dispensa Sez. 3.6: dall'LLFR all'UFR)
# Fino a fsp=20 la curva e' quella liquida (bootstrap, sopra). Oltre fsp, il
# forward continuo converge dall'LLFR verso l'UFR con il peso B(alpha,h).

#--- Dove arrivare: l'UFR (dispensa par. "Dove arrivare: l'UFR")
UFR_ann  <- 3.3/100          # UFR annuo composto (parametro regolamentare EUR)
UFR_c    <- log(UFR_ann+1)   # UFR in tasso continuo


#--- Da dove partire: l'LLFR (dispensa par. "Da dove partire: l'LLFR", eq. llfr, sez. 8.5.6)
# media pesata dei forward continui attorno all'FSP: il primo termine e' il
# forward 15->20 (ultimo prima dell'FSP), gli altri sono forward FSP->tenor
# per i tenor DLT oltre l'FSP (25,30,40,50)
tenor_llfr = c(20,25,30,40,50)
w_llfr = c(0.33,0.12,0.48,0.04,0.03)
fwd_c_per_media <- c(
  (curve[20,rc]*20- curve[15,rc]*15)/(20-15),
  (curve[25,rc]*25- curve[20,rc]*20)/(25-20),
  (curve[30,rc]*30- curve[20,rc]*20)/(30-20),
  (curve[40,rc]*40- curve[20,rc]*20)/(40-20),
  (curve[50,rc]*50- curve[20,rc]*20)/(50-20)
)
LLFR_c <- sum(fwd_c_per_media * w_llfr)


#--- Come passare dall'uno all'altro: curva fwd estrapolata e curva risk free
# (dispensa par. "Come passare dall'uno all'altro", eq. extrap-fwd/extrap-zero)

alpha = 0.11   # parametro di convergenza (fisso per legge, valore a regime; il phasing-in
               # 2027->2032+ e' analizzato come scenario di confronto in Sez. 5 della dispensa)

h <- c((fsp+1):150)-fsp   # orizzonte oltre l'FSP: h=1,...,130 (NON il tenor assoluto)
fwd_c_extrapolati <- UFR_c +(LLFR_c - UFR_c)*(1/(alpha*h))*(1-exp(-alpha*h))   # eq. extrap-fwd: f^c = UFR^c + (LLFR^c-UFR^c)*B(alpha,h)
fwd_ann_extrapolati <- exp(fwd_c_extrapolati)-1
rc_estrapolati <- (fsp*curve[fsp,rc]+ h*fwd_c_extrapolati)/(fsp+h)            # eq. extrap-zero: z^c_{FSP+h} = (FSP*z^c_FSP + h*f^c)/(FSP+h)
rann_estrapolati <- exp(rc_estrapolati) - 1

#---------------------- costruiamo la curva finale (liquida 1-20 + estrapolata 21-150)
tenor_max <- 150
swap_euribor6m  <- rep(0,tenor_max)
swap_wo_cra     <- rep(0,tenor_max)
discount_factor <- rep(0,tenor_max)
r_c             <- rep(0,tenor_max)
r_ann           <- rep(0,tenor_max)
fwd_c           <- rep(0,tenor_max)
fwd_ann         <- rep(0,tenor_max)


#---inseriamo swap
for(i in swap_eur_dec2025[,tenor]){
  swap_euribor6m[i] <- swap_eur_dec2025[tenor==i,swap_inputEUR]
  swap_wo_cra[i]    <- swap_eur_dec2025[tenor==i,swap_inputEUR] - cra_eur
}

# risk-free capitalizzazione continua
r_c[1:20]          <- curve[1:20,rc]
r_c[21:tenor_max]  <- rc_estrapolati

# risk-free capitalizzazione annuale
r_ann[1:20]          <- curve[1:20,rann]
r_ann[21:tenor_max]  <- rann_estrapolati

# tassi forward capitalizzazione continua
fwd_c[1:20]          <- curve[1:20,fwd_c]
fwd_c[21:tenor_max]  <- fwd_c_extrapolati

# tassi forward capitalizzazione annuale
fwd_ann[1:20]          <- curve[1:20,fwd_ann]
fwd_ann[21:tenor_max]  <- fwd_ann_extrapolati

# discount factor
discount_factor[1:20]          <- curve[1:20,dtk]
discount_factor[21:tenor_max]  <- exp(-r_c[21:tenor_max]*c(21:tenor_max))


curve_finale <- data.table(tenor = c(1:tenor_max),
                           swap_euribor6m = swap_euribor6m,
                           swap_wo_cra = swap_wo_cra,
                           discount_factor = discount_factor,
                           rc = r_c,
                           rann = r_ann,
                           fwd_c = fwd_c,
                           fwd_ann = fwd_ann)


print(curve_finale)


# ==============================================================================
# ==============================================================================
#  OUTPUT PER LA DISPENSA 01 (figure PDF e tabelle .tex)
#
#  Tutto quanto segue e' costruito SOLO a partire dagli oggetti gia' calcolati
#  sopra (curve, curve_finale, LLFR_c, ...): non ricalcola nulla del bootstrap.
#  Destinazione: ../output/01_eiopa_rfr_bootstrap/
#
#  Notazione allineata alla dispensa: r(t) tasso zero, P(0,t) fattore di sconto,
#  f(t) forward. Ai tenor interi: r_t, r^c_t, d_t.
# ==============================================================================
# ==============================================================================

suppressPackageStartupMessages(library(ggplot2))

dir_out <- file.path("..", "output", "01_eiopa_rfr_bootstrap")
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

theme_dispensa <- theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title       = element_text(face = "bold", size = 13),
        plot.subtitle    = element_text(size = 10, color = "gray30"),
        legend.position  = "bottom")

col_spot <- "#185FA5"; col_fwd  <- "#993C1D"; col_ufr <- "#7060CC"
col_obs  <- "#B2182B"; col_off  <- "#E07020"; col_nodi <- "black"

save_fig <- function(nome, plot_obj, w = 9, h = 5.5) {
  path <- file.path(dir_out, paste0(nome, ".pdf"))
  ggsave(path, plot = plot_obj, width = w, height = h, device = "pdf")
  message("  [OK] ", nome, ".pdf")
}
save_tab <- function(nome, lines) {
  writeLines(lines, file.path(dir_out, paste0(nome, ".tex")))
  message("  [OK] ", nome, ".tex")
}
# alternanza colore righe nelle tabelle (stile della dispensa)
tint <- function(i) if (i %% 2 == 1) "\\rowcolor{rowtint}" else ""

cat("\n=====================================================================\n")
cat("  OUTPUT DISPENSA 01 -> ", normalizePath(dir_out, mustWork = FALSE), "\n")
cat("=====================================================================\n\n")

# ------------------------------------------------------------------------------
# 1. DATI DI INPUT: tabella tenor / RIC / swap lordo / after-CRA / uso
# ------------------------------------------------------------------------------
# I RIC (Reuters Instrument Code) sono quelli prescritti dalla documentazione
# EIOPA (Tab.1, par. 4.3.6) per la curva EUR: root EURAB6E + tenor + "Y=".
# Fonte del dato: LSEG Data & Analytics (ex Refinitiv, ex Thomson Reuters).
ric_of_tenor <- function(tt) sprintf("EURAB6E%dY=", tt)

tab_input <- data.table(
  tenor = swap_eur_dec2025[, tenor],
  ric   = ric_of_tenor(swap_eur_dec2025[, tenor]),
  lordo = swap_eur_dec2025[, swap_inputEUR],
  netto = swap_eur_dec2025[, swap_inputEUR] - cra_eur
)
tab_input[, uso := ifelse(tenor <= fsp, "bootstrap", "solo LLFR")]
print(tab_input)

{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Tassi swap EUR di input a dicembre~2025 (valuation date 31/12/2025), ",
           "con il rispettivo \\emph{Reuters Instrument Code}. I ticker sono quelli prescritti ",
           "dalla documentazione ufficiale EIOPA per la curva risk-free EUR; il dato \\`e ",
           "acquisito da LSEG Data \\& Analytics (ex Refinitiv). Il CRA di ",
           sprintf("%d~bps ", round(cra_eur*1e4)),
           "\\`e sottratto prima del bootstrap.}"),
    "\\label{tab:input-ric-dic}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rlccl}", "\\toprule",
    paste0("$T_k$ (anni) & RIC & swap lordo (\\%) & after-CRA $s_k$ (\\%) & utilizzo\\\\"),
    "\\midrule")
  for (i in seq_len(nrow(tab_input))) {
    uso_tex <- if (tab_input$uso[i] == "bootstrap") "bootstrap" else "solo $\\LLFR$"
    lines <- c(lines, sprintf("%s%d & \\texttt{%s} & %.4f & %.4f & %s\\\\",
                              tint(i), tab_input$tenor[i], tab_input$ric[i],
                              tab_input$lordo[i]*100, tab_input$netto[i]*100, uso_tex))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_input_ric_dic", lines)
}

# ------------------------------------------------------------------------------
# 2. BOOTSTRAP: curva ricostruita 1-20 (zona liquida)
# ------------------------------------------------------------------------------
tenor_osservati <- swap_eur_dec2025[, tenor]

{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva ricostruita per bootstrap nella zona liquida ($1\\le t\\le\\FSP$). ",
           "$d_t$ fattore di sconto, $r^c_t$ tasso zero continuo, $r_t$ tasso zero annuo ",
           "composto, $f_{t-1,t}$ forward annuale. I tenor contrassegnati con $\\dagger$ ",
           "(14, 16--19) non sono quotati: nascono dall'ipotesi di forward costante nei gap.}"),
    "\\label{tab:curva-bootstrap}\\renewcommand{\\arraystretch}{1.1}",
    "\\begin{tabular}{rcccc}", "\\toprule",
    "$t$ (anni) & $d_t$ & $r^c_t$ (\\%) & $r_t$ (\\%) & $f_{t-1,t}$ (\\%)\\\\",
    "\\midrule")
  for (t in 1:fsp) {
    mark <- if (t %in% tenor_osservati) "" else "$^\\dagger$"
    fwd_str <- if (t == 1) "---" else sprintf("%.4f", curve[t, fwd_ann]*100)
    lines <- c(lines, sprintf("%s%d%s & %.7f & %.4f & %.4f & %s\\\\",
                              tint(t), t, mark, curve[t, dtk],
                              curve[t, rc]*100, curve[t, rann]*100, fwd_str))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_curva_bootstrap", lines)
}

# ------------------------------------------------------------------------------
# 3. NEWTON: esempio numerico tracciato sul gap 13->15 (g=2)
# ------------------------------------------------------------------------------
# Stessa iterazione dei blocchi didattici sopra, ma registrando ogni passo per
# poterla stampare in dispensa (funzione obiettivo, residuo, incremento).
newton_traccia <- function(s2, s1, dtk_prec, g, f0, tol = 1e-16, nmax = 50) {
  out <- data.table(k = 0L, f = f0, phi = phi(f0, s2, s1, g, dtk_prec), incr = NA_real_)
  f <- f0
  for (k in seq_len(nmax)) {
    fprev <- f
    f <- f - phi(f, s2, s1, g, dtk_prec) / derivata_phi(f, s2, s1, g)
    out <- rbind(out, data.table(k = as.integer(k), f = f,
                                 phi = phi(f, s2, s1, g, dtk_prec),
                                 incr = abs(f - fprev)))
    if (abs(f - fprev) <= tol) break
  }
  out
}

# gap 13->15: tenor noti 13 e 15, f0 = forward annualizzato del tenor 13
tr_1315 <- newton_traccia(s2 = swap_eur_dec2025_post_cra[15],
                          s1 = swap_eur_dec2025_post_cra[13],
                          dtk_prec = curve[13, dtk], g = 2,
                          f0 = exp(curve[13, fwd_c]) - 1)
cat("  Newton gap 13->15: f* =", sprintf("%.10f%%", tail(tr_1315$f,1)*100),
    "in", nrow(tr_1315)-1, "iterazioni\n")
print(tr_1315)

{
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Metodo di Newton sull'equazione non lineare~\\eqref{eq:boot-nl} per il gap ",
           "$13\\to15$ ($g=2$). Inizializzazione $f_0$ = forward annuale del tenor 13; ",
           "criterio d'arresto $|f_k-f_{k-1}|\\le 10^{-16}$. Il residuo $\\varphi(f_k)$ crolla ",
           "di diversi ordini di grandezza per iterazione: \\`e la firma della convergenza ",
           "quadratica.}"),
    "\\label{tab:newton-esempio}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$k$ & $f_k$ (\\%) & $\\varphi(f_k)$ & $|f_k-f_{k-1}|$\\\\",
    "\\midrule")
  for (i in seq_len(nrow(tr_1315))) {
    incr_str <- if (is.na(tr_1315$incr[i])) "---" else sprintf("%.3e", tr_1315$incr[i])
    lines <- c(lines, sprintf("%s%d & %.8f & %+.3e & %s\\\\",
                              tint(i), tr_1315$k[i], tr_1315$f[i]*100,
                              tr_1315$phi[i], incr_str))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_newton_esempio", lines)
}

# ------------------------------------------------------------------------------
# 4. LLFR: bootstrap esteso a 50 anni e calcolo della media pesata
# ------------------------------------------------------------------------------
# Il bootstrap oltre l'FSP (tenor 21-50) serve ESCLUSIVAMENTE a produrre i
# forward continui che entrano nella media pesata dell'LLFR.
{
  t_ext <- c(15, 20, 25, 30, 40, 50)
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Valori del bootstrap esteso oltre l'$\\FSP$, ai tenor DLT che entrano ",
           "nel calcolo dell'$\\LLFR$. Il tratto $21\\le t\\le 50$ \\emph{non} fa parte della ",
           "curva risk-free pubblicata: serve solo a ricavare i forward della ",
           "Tabella~\\ref{tab:llfr-calcolo}.}"),
    "\\label{tab:bootstrap-esteso}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & $d_t$ & $r^c_t$ (\\%) & $r_t$ (\\%)\\\\",
    "\\midrule")
  for (i in seq_along(t_ext)) {
    t <- t_ext[i]
    lines <- c(lines, sprintf("%s%d & %.7f & %.4f & %.4f\\\\",
                              tint(i), t, curve[t, dtk], curve[t, rc]*100, curve[t, rann]*100))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_bootstrap_esteso", lines)
}

# tabella del calcolo pesato dell'LLFR: un contributo per riga
{
  # riferimento del forward: per il primo termine e' il tenor 15 (ultimo DLT
  # prima dell'FSP), per gli altri e' l'FSP stesso
  rif <- c(15, rep(fsp, length(tenor_llfr) - 1))
  contrib <- w_llfr * fwd_c_per_media
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Calcolo dell'$\\LLFR$ come media pesata dei forward continui attorno ",
           "all'$\\FSP$ (eq.~\\eqref{eq:llfr}). Ogni riga: forward continuo $f^c_{a,b}$ tra il ",
           "tenor di riferimento $a$ e il tenor $b$, moltiplicato per il peso EIOPA $w$. ",
           "La somma dei contributi \\`e l'$\\LLFR^c$.}"),
    "\\label{tab:llfr-calcolo}\\renewcommand{\\arraystretch}{1.2}",
    "\\begin{tabular}{rrccccc}", "\\toprule",
    paste0("$b$ & $a$ & $d_b$ & $r^c_b$ (\\%) & $f^c_{a,b}$ (\\%) & $w_b$ & ",
           "$w_b f^c_{a,b}$ (\\%)\\\\"),
    "\\midrule")
  for (i in seq_along(tenor_llfr)) {
    b <- tenor_llfr[i]
    lines <- c(lines, sprintf("%s%d & %d & %.7f & %.4f & %.4f & %.2f & %.4f\\\\",
                              tint(i), b, rif[i], curve[b, dtk], curve[b, rc]*100,
                              fwd_c_per_media[i]*100, w_llfr[i], contrib[i]*100))
  }
  lines <- c(lines, "\\midrule",
    sprintf("\\multicolumn{5}{r}{\\textbf{$\\LLFR^c$}} & \\textbf{%.2f} & \\textbf{%.4f}\\\\",
            sum(w_llfr), LLFR_c*100),
    sprintf("\\multicolumn{5}{r}{\\textit{per confronto:} $\\UFR^c$} & & \\textit{%.4f}\\\\",
            UFR_c*100),
    "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_llfr_calcolo", lines)
}
cat(sprintf("  LLFR^c = %.6f%%   UFR^c = %.6f%%   (differenza %.2f bps)\n",
            LLFR_c*100, UFR_c*100, (LLFR_c - UFR_c)*1e4))

# ------------------------------------------------------------------------------
# 5. ESTRAPOLAZIONE: la funzione peso B(alpha,h)
# ------------------------------------------------------------------------------
B_weight <- function(a, h) ifelse(h == 0, 1, (1 - exp(-a*h)) / (a*h))
{
  hh <- seq(0, 130, length.out = 500)
  df_B <- do.call(rbind, lapply(c(0.11, 0.20, 0.40), function(a)
    data.frame(h = hh, B = B_weight(a, hh),
               alpha = sprintf("alpha = %.0f%%", a*100))))
  pB <- ggplot(df_B, aes(x = h, y = B, color = alpha, linetype = alpha)) +
    geom_hline(yintercept = c(0, 1), linetype = "dashed", color = "gray60", linewidth = 0.4) +
    geom_line(linewidth = 1) +
    annotate("text", x = 2, y = 0.97, label = "B = 1: forward = LLFR (all'FSP)",
             hjust = 0, size = 3.2, color = "gray30") +
    annotate("text", x = 128, y = 0.06, label = "B -> 0: forward -> UFR",
             hjust = 1, size = 3.2, color = "gray30") +
    labs(title = expression(paste("Peso di convergenza  ", B(alpha, h) == (1 - e^{-alpha*h})/(alpha*h))),
         subtitle = "Un alpha piu' grande spinge il peso a zero piu' rapidamente: convergenza all'UFR piu' veloce",
         x = "Orizzonte h oltre l'FSP (anni)", y = expression(B(alpha, h)),
         color = NULL, linetype = NULL) +
    theme_dispensa
  save_fig("fig_b_alpha_h", pB)
}

# ------------------------------------------------------------------------------
# 6. CURVA FINALE e confronto con la curva ufficiale EIOPA
# ------------------------------------------------------------------------------
# Benchmark like-for-like: curva ufficiale di dicembre 2025 RICALCOLATA da EIOPA
# col nuovo metodo (bootstrap), cosi' il confronto isola i soli dati di input.
read_eiopa_newmethod <- function() {
  f <- file.path("..", "dati", "dec25_eiopa_rfr_newapproach.csv")
  if (!file.exists(f)) return(NULL)
  tryCatch({
    df <- read.csv(f, stringsAsFactors = FALSE)
    tt <- as.integer(sub("^YR", "", df$tenor)); zz <- as.numeric(df[[2]])
    ok <- !is.na(tt) & !is.na(zz)
    data.table(tenor = tt[ok], rann = zz[ok])
  }, error = function(e) NULL)
}
# Curva Smith-Wilson ufficiale pubblicata (zip EIOPA), per il confronto metodologico.
read_eiopa_sw <- function(ym = "202512") {
  zdir <- file.path("..", "dati", "eiopa_zips")
  tryCatch({
    zf <- list.files(zdir, pattern = paste0("^EIOPA_RFR_", ym, "[0-9]{2}\\.zip$"),
                     full.names = TRUE)
    if (length(zf) == 0) return(NULL)
    inner <- utils::unzip(zf[1], list = TRUE)$Name
    ts <- grep("Term_Structures", inner, value = TRUE, ignore.case = TRUE)[1]
    if (is.na(ts)) return(NULL)
    utils::unzip(zf[1], files = ts, exdir = tempdir(), overwrite = TRUE)
    raw <- openxlsx::read.xlsx(file.path(tempdir(), ts), sheet = "RFR_spot_no_VA",
                               colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    lab <- raw[[2]]; val <- raw[[3]]
    ml  <- suppressWarnings(as.numeric(lab))
    sel <- which(!is.na(ml) & ml >= 1 & ml <= 150)
    tt  <- ml[sel]; zz <- suppressWarnings(as.numeric(val[sel]))
    ok  <- !is.na(tt) & !is.na(zz)
    data.table(tenor = tt[ok], rann = zz[ok])
  }, error = function(e) NULL)
}

eiopa_new <- read_eiopa_newmethod()
eiopa_sw  <- read_eiopa_sw()
if (is.null(eiopa_new)) warning("curva ufficiale nuovo metodo non trovata: figure/tabelle di confronto saltate")
if (is.null(eiopa_sw))  warning("curva ufficiale Smith-Wilson non trovata: confronto SW saltato")

# --- tabella di confronto con la curva ufficiale, inclusi i tenor > 20 ---
if (!is.null(eiopa_new)) {
  Tsel <- c(1, 5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 120)
  r_mine <- curve_finale$rann[match(Tsel, curve_finale$tenor)]*100
  r_off  <- eiopa_new$rann[match(Tsel, eiopa_new$tenor)]*100
  delta  <- (r_mine - r_off)*100                                  # bps
  ok     <- is.finite(delta)
  cat(sprintf("  Confronto vs ufficiale: max|delta| liquida = %.3f bps, estrapolazione = %.3f bps\n",
              max(abs(delta[ok & Tsel <= fsp])), max(abs(delta[ok & Tsel > fsp]))))
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Curva ricostruita vs curva ufficiale EIOPA di dicembre~2025 (ricalcolata ",
           "col nuovo metodo a bootstrap: confronto \\emph{like-for-like}, stesso metodo su ",
           "entrambi i lati). La riga in grassetto \\`e l'$\\FSP$: sopra di essa siamo in zona ",
           "liquida, sotto in estrapolazione.}"),
    "\\label{tab:confronto-eiopa}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & $r_t$ ricostruito (\\%) & $r_t$ EIOPA (\\%) & $\\Delta$ (bps)\\\\",
    "\\midrule")
  for (i in seq_along(Tsel)) {
    if (!ok[i]) next
    numstr <- if (Tsel[i] == fsp) sprintf("\\textbf{%d}", Tsel[i]) else as.character(Tsel[i])
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f\\\\",
                              tint(i), numstr, r_mine[i], r_off[i], delta[i]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_confronto_eiopa", lines)
}

# ------------------------------------------------------------------------------
# 7. SENSITIVITA' AL PARAMETRO alpha (0.11 base/regime vs 0.20 phasing-in 2027)
# ------------------------------------------------------------------------------
# alpha entra SOLO nell'estrapolazione: bootstrap e LLFR non dipendono da alpha
# e non vengono ricalcolati. Rifacciamo quindi solo il blocco di estrapolazione.
# alpha=0.11 (regime) e' il valore usato per curve_finale in tutta la Sez. 4; qui
# lo confrontiamo con lo scenario di phasing-in 2027 (alpha=0.20).
curva_alpha <- function(a) {
  hh   <- 1:(150 - fsp)
  fc   <- UFR_c + (LLFR_c - UFR_c) * (1/(a*hh)) * (1 - exp(-a*hh))
  rc_e <- (fsp*curve[fsp, rc] + hh*fc) / (fsp + hh)
  data.table(tenor = 1:150,
             rc    = c(curve[1:fsp, rc],    rc_e),
             rann  = c(curve[1:fsp, rann],  exp(rc_e) - 1),
             fwd_c = c(curve[1:fsp, fwd_c], fc))
}
alpha_lo <- 0.11; alpha_hi <- 0.20
c_lo <- curva_alpha(alpha_lo); c_hi <- curva_alpha(alpha_hi)

# verifica: con alpha = 0.11 dobbiamo riottenere la curva_finale gia' calcolata
# (e' lo stesso valore usato sopra per l'estrapolazione principale)
stopifnot(max(abs(c_lo$rann - curve_finale$rann)) < 1e-12)

# Distanza residua del forward dall'UFR, scala log: e' qui che l'effetto di alpha
# sulla VELOCITA' di convergenza si vede in modo netto (le curve zero, invece,
# sono a dicembre 2025 quasi indistinguibili: LLFR dista solo ~2 bps dall'UFR).
{
  lab_lo <- sprintf("alpha = %.0f%% (base, regime)", alpha_lo*100)
  lab_hi <- sprintf("alpha = %.0f%% (phasing-in 2027)", alpha_hi*100)
  cols   <- setNames(c(col_spot, col_fwd), c(lab_lo, lab_hi))
  ltys   <- setNames(c("solid", "dashed"),  c(lab_lo, lab_hi))

  df_b <- rbind(
    data.table(T = c_lo$tenor, val = abs(c_lo$fwd_c - UFR_c)*1e4, Scenario = lab_lo),
    data.table(T = c_hi$tenor, val = abs(c_hi$fwd_c - UFR_c)*1e4, Scenario = lab_hi))
  df_b <- df_b[T > fsp & val > 0]
  p_alpha <- ggplot(df_b, aes(x = T, y = val, color = Scenario, linetype = Scenario)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = cols) + scale_linetype_manual(values = ltys) +
    scale_y_log10() +
    scale_x_continuous(breaks = c(20,40,60,80,100,120,150)) +
    labs(title = "Velocita' di convergenza: distanza del forward dall'UFR (scala log)",
         subtitle = "Base (alpha=11%, continua) vs scenario di phasing-in (alpha=20%, tratteggiata): la distanza residua scala come 1/alpha",
         x = "Scadenza t (anni)", y = "|f(t) - UFR|  (bps)", color = NULL, linetype = NULL) +
    theme_dispensa
  save_fig("fig_alpha_curve", p_alpha)
}

{
  d_alpha <- (c_hi$rann - c_lo$rann)*1e4                          # bps
  df_d <- data.table(T = c_hi$tenor, delta = d_alpha)
  i_pk <- which.max(abs(df_d$delta)); T_pk <- df_d$T[i_pk]; d_pk <- df_d$delta[i_pk]
  p_d <- ggplot(df_d, aes(x = T, y = delta)) +
    annotate("rect", xmin = fsp, xmax = 150, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.30) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.4) +
    geom_vline(xintercept = fsp, color = "gray55", linetype = "dashed", linewidth = 0.5) +
    geom_line(color = col_spot, linewidth = 1) +
    geom_point(data = data.table(T = T_pk, delta = d_pk), aes(x = T, y = delta),
               color = col_obs, size = 2.2, inherit.aes = FALSE) +
    annotate("text", x = T_pk + 3, y = d_pk, hjust = 0, color = col_obs, size = 3.2,
             label = sprintf("max %+.2f bps (t = %d)", d_pk, T_pk)) +
    scale_x_continuous(breaks = c(1,20,40,60,80,100,120,150)) +
    labs(title = "Effetto di alpha sullo zero rate: differenza tra i due scenari",
         subtitle = sprintf("Delta = r(t) con alpha=%.0f%% meno r(t) con alpha=%.0f%%; nullo fino all'FSP",
                            alpha_hi*100, alpha_lo*100),
         x = "Scadenza t (anni)", y = "Delta zero rate (bps)") +
    theme_dispensa
  save_fig("fig_alpha_delta", p_d)
}

{
  Tsel <- c(20, 25, 30, 40, 50, 60, 80, 100, 120, 150)
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Sensitivit\\`a al parametro di convergenza $\\alpha$: confronto tra il ",
           sprintf("valore di regime ($\\alpha=%.0f\\%%$) e quello di phasing-in ", alpha_lo*100),
           sprintf("($\\alpha=%.0f\\%%$). ", alpha_hi*100),
           "Le ultime due colonne misurano la \\emph{velocit\\`a di convergenza} come distanza ",
           "residua del forward dall'$\\UFR^c$: un $\\alpha$ maggiore la chiude pi\\`u in fretta. ",
           "All'$\\FSP$ le due curve coincidono per costruzione.}"),
    "\\label{tab:alpha-sens}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccccc}", "\\toprule",
    paste0("& \\multicolumn{3}{c}{zero rate $r_t$} & \\multicolumn{2}{c}{",
           "$|f^c_t-\\UFR^c|$ (bps)}\\\\"),
    "\\cmidrule(lr){2-4}\\cmidrule(lr){5-6}",
    sprintf("$t$ (anni) & $\\alpha=%.0f\\%%$ & $\\alpha=%.0f\\%%$ & $\\Delta$ (bps) & $\\alpha=%.0f\\%%$ & $\\alpha=%.0f\\%%$\\\\",
            alpha_lo*100, alpha_hi*100, alpha_lo*100, alpha_hi*100),
    "\\midrule")
  for (i in seq_along(Tsel)) {
    t <- Tsel[i]; j <- match(t, c_lo$tenor)
    numstr <- if (t == fsp) sprintf("\\textbf{%d}", t) else as.character(t)
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f & %.2f & %.2f\\\\",
                              tint(i), numstr,
                              c_lo$rann[j]*100, c_hi$rann[j]*100,
                              (c_hi$rann[j] - c_lo$rann[j])*1e4,
                              abs(c_lo$fwd_c[j] - UFR_c)*1e4,
                              abs(c_hi$fwd_c[j] - UFR_c)*1e4))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_alpha_sens", lines)
}

# ------------------------------------------------------------------------------
# 8. CONFRONTO METODOLOGICO: nuovo metodo (bootstrap) vs Smith-Wilson
# ------------------------------------------------------------------------------
if (!is.null(eiopa_sw)) {
  mats <- 1:120
  r_new <- curve_finale$rann[match(mats, curve_finale$tenor)]*100
  r_sw  <- eiopa_sw$rann[match(mats, eiopa_sw$tenor)]*100
  d_sw  <- (r_new - r_sw)*100                                     # bps
  ok    <- is.finite(d_sw)

  sel60 <- mats <= 60
  df_c <- rbind(
    data.table(T = mats[sel60], val = r_new[sel60], Metodo = "Nuovo metodo (bootstrap)"),
    data.table(T = mats[sel60], val = r_sw[sel60],  Metodo = "Smith-Wilson"))
  p_c <- ggplot(df_c, aes(x = T, y = val, color = Metodo, linetype = Metodo)) +
    geom_vline(xintercept = fsp, color = "gray55", linetype = "dashed", linewidth = 0.5) +
    geom_hline(yintercept = UFR_ann*100, color = col_ufr, linetype = "dotted", linewidth = 0.8) +
    geom_line(linewidth = 1) +
    annotate("text", x = 58, y = UFR_ann*100 + 0.04, label = sprintf("UFR = %.2f%%", UFR_ann*100),
             hjust = 1, color = col_ufr, size = 3.2) +
    scale_color_manual(values = c("Nuovo metodo (bootstrap)" = col_spot, "Smith-Wilson" = col_fwd)) +
    scale_linetype_manual(values = c("Nuovo metodo (bootstrap)" = "solid", "Smith-Wilson" = "dashed")) +
    scale_x_continuous(breaks = c(1,5,10,15,20,30,40,50,60)) +
    labs(title = "Nuovo metodo vs Smith-Wilson: curve spot EUR — dicembre 2025",
         subtitle = "Fino all'FSP le due curve interpolano gli stessi nodi liquidi; oltre, le estrapolazioni divergono",
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
  lines <- c("% GENERATO da R/01_eiopa_rfr_bootstrap_rivisto.R",
    "\\begin{table}[H]\\centering\\small",
    paste0("\\caption{Confronto metodologico a parit\\`a di dati: curva spot EUR ufficiale di ",
           "dicembre~2025 col nuovo metodo (bootstrap) e col metodo Smith--Wilson. Lo scarto ",
           "isola l'effetto della \\emph{sola} metodologia. La riga in grassetto \\`e l'$\\FSP$.}"),
    "\\label{tab:sw-vs-new-rivisto}\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular}{rccc}", "\\toprule",
    "$t$ (anni) & nuovo metodo (\\%) & Smith--Wilson (\\%) & $\\Delta$ (bps)\\\\",
    "\\midrule")
  for (i in seq_along(Tsel)) {
    j <- match(Tsel[i], mats)
    if (is.na(j) || !is.finite(d_sw[j])) next
    numstr <- if (Tsel[i] == fsp) sprintf("\\textbf{%d}", Tsel[i]) else as.character(Tsel[i])
    lines <- c(lines, sprintf("%s%s & %.4f & %.4f & %+.2f\\\\",
                              tint(i), numstr, r_new[j], r_sw[j], d_sw[j]))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  save_tab("tab_sw_vs_new_rivisto", lines)

  cat(sprintf("  SW vs nuovo metodo: max|delta| liquida = %.3f bps, estrapolazione = %.2f bps (a t=%d)\n",
              max(abs(d_sw[ok & mats <= fsp])), max(abs(d_sw[ok & mats > fsp])), T_pk))
}

# ------------------------------------------------------------------------------
# 9. FIGURA fattori di sconto (era in output/shared: ora propria della disp. 01)
# ------------------------------------------------------------------------------
{
  sel <- curve_finale$tenor <= 25
  dfP <- data.table(T = curve_finale$tenor[sel], P = curve_finale$discount_factor[sel])
  pP <- ggplot(dfP, aes(x = T, y = P)) +
    geom_line(linewidth = 1, color = col_spot) +
    geom_point(data = dfP[T %in% tenor_osservati], aes(x = T, y = P),
               color = col_nodi, size = 1.8) +
    scale_x_continuous(breaks = c(1,5,10,15,20,25)) +
    labs(title = "Fattori di sconto P(0,t)",
         subtitle = "P(0,t) = prezzo oggi di 1 unita' pagata in t; decresce con la scadenza. Punti neri: tenor quotati",
         x = "Scadenza t (anni)", y = "P(0,t)") +
    theme_dispensa
  save_fig("fig_fattori_sconto", pP, w = 8, h = 5)
}

cat("\n  Fatto. Output in ", dir_out, "\n\n")
