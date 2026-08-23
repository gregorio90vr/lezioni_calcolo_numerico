# Laboratorio di Calcolo Numerico — UniVR, A.A. 2026/2027

Materiale didattico: dispense in `dispense/`, script R in `R/`, dati in `dati/`, output
(figure/tabelle PDF) in `output/`. Ogni lezione usa il prefisso `NN_topic` condiviso da
dispensa, script e cartella di output (dettagli in `CLAUDE.md`). Le vecchie trattazioni
separate del metodo EIOPA e della famiglia PCA, superate dal riordino descritto sotto, restano
disponibili come backup in `dispense/backup/`. Sintesi per blocchi:

## 01 — Titoli obbligazionari: prezzo, rendimento, duration, convexity

`dispense/01_bond_duration_convexity.tex`

Prima lezione del corso, autosufficiente (nessun dato esterno): due titoli didattici
(cedola 4%/3%, $T=5$ e $T=10$). Rendimento a scadenza (YTM) per bisezione **e**
Newton-Raphson; duration di Macaulay/modificata e convexity derivate simbolicamente e
confrontate con l'errore di troncamento dell'approssimazione di Taylor su una griglia di
shock ±200 bps. Introduce lo zero-coupon bond e il fattore di sconto $P(0,t)$ — l'unità di
misura di tutto il corso — e le convenzioni di capitalizzazione (annua qui, continua nelle
lezioni successive).

Immunizza poi una passività zero-coupon a duration singola risolvendo un sistema lineare
2×2 nei pesi di portafoglio — prima combinazione lineare del corso usata per aggregare
grandezze finanziarie — e chiude mostrando i due limiti che le lezioni successive rimuovono:
un esperimento numerico su tre scenari di shock (parallelo, irripidimento, appiattimento)
mostra che l'immunizzazione per duration protegge solo dal primo, aprendo alla scomposizione
in componenti principali della lezione **03**; l'osservazione che un solo rendimento non
basta per scadenze diverse apre alla curva della lezione **02**.

## 02 — Curva EIOPA Risk-Free: bootstrap e Smith-Wilson

`dispense/02_eiopa_rfr_bootstrap_smith_wilson.tex` — dispensa **ufficiale e finale**, alimentata
da **due script** eseguiti in sequenza (`R/02_eiopa_rfr_bootstrap.R` poi
`R/02_eiopa_rfr_smith_wilson.R`, che rilegge un CSV intermedio scritto dal primo).

Tratta i due metodi insieme, con lo stesso grado di dettaglio, in un percorso a fasi:
fondamenti comuni → dati di mercato comuni (DLT, CRA, UFR) → la teoria di **Smith-Wilson**
(metodologia storica, EIOPA-BoS-25-599, 2016–2026) → la teoria del **bootstrap** (metodologia
attuale, EIOPA-BoS-26-198, dal 2027) → le due ricostruzioni di dicembre 2025 a partire dagli
**stessi dati di input** → confronto → conclusioni. Il punto di vista è che entrambi i metodi
partono dallo stesso problema sottodeterminato — 15 quotazioni par per 20 scadenze — e lo
chiudono diversamente: Smith-Wilson con un criterio di ottimalità (minima energia, algebra
lineare su matrici SPD, moltiplicatori di Lagrange, calibrazione di α per **bisezione**),
il bootstrap con un'ipotesi strutturale (forward costante nei gap, risolto con **Newton**).
Poiché le due curve sono ricostruite dagli stessi input, lo scarto misurato isola la sola
metodologia.

## 03 — PCA su curve dei tassi (famiglia)

Analisi in componenti principali (PCA/SVD) sulle variazioni mensili di una curva dei tassi,
per capire quante e quali direzioni (livello, pendenza, curvatura) spiegano la maggior parte
della variabilità storica. 03, 03b, 03c sono varianti della stessa metodologia, non lezioni
indipendenti.

- **03** (`dispense/03_pca_ecb.tex`) — versione canonica/finale, curva **ECB**, schema
  **calibrazione/validazione**: loadings stimati sui dati fino al 31/12/2025, poi validati
  fuori campione su marzo e giugno 2026.
- **03b** (`dispense/03b_pca_ecb.tex`) — variante **full-sample** su curva ECB: nessuno split
  train/test, PCA e ricostruzione sull'intero campione fino al 30/06/2026.
- **03c** (`dispense/03c_pca_eiopa.tex`) — stessa metodologia della 03b applicata alla curva
  **EIOPA** (spot, senza volatility adjustment) anziché ECB.

*(`R/03d_analisi_periodi.R` è uno script di supporto interno, senza dispensa propria: verifica
a mano gli score e gli eventi macro citati nel testo della 03.)*

## Backup: le vecchie trattazioni separate (`dispense/backup/`)

Prima del riordino, i due metodi EIOPA avevano dispense separate e la famiglia PCA si
chiamava "04". Quelle versioni — complete e valide, non bozze abbandonate — restano come
riferimento, con contenuto non più mantenuto attivamente (script e cartelle di output
congelati, con i nomi storici):

- **02a** — il bootstrap trattato da solo (ex dispensa "02").
- **02b** — companion investigativo sul bootstrap: confronta la ricostruzione a partire da
  quattro fonti di dati diverse per isolare l'effetto della fonte dati da quello della
  definizione di LLFR.
- **02c** — Smith-Wilson trattato da solo (ex dispensa "03"), versione canonica.
- **02d** — nota di verifica su Smith-Wilson: confronta tre scenari di ricostruzione per
  isolare l'effetto dei dati di input da quello della scelta di α.
- **02e** — variante di 02c: la positiva definitezza della matrice di Wilson dimostrata per
  via **variazionale** (Gach 2017) anziché elementare.
- **02f** / **02g** — note di approfondimento sulla dimostrazione elementare della positiva
  definitezza (rispettivamente versione dettagliata passo-passo e versione compatta).

Dettagli completi (mappa vecchio→nuovo nome, script e output associati) in `CLAUDE.md`.
