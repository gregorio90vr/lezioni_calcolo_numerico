# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Teaching materials for *Laboratorio di Calcolo Numerico*, UniVR — A.A. 2026/2027. The repository contains:

- **R scripts** implementing financial/numerical methods (EIOPA RFR curves, PCA on yield curves)
- **Python utility** for downloading and parsing EIOPA ZIP files
- **Data** in `dati/` (ECB CSV, EIOPA ZIPs) and **generated output** PDFs in `output/`

## Naming convention

Each lesson uses the prefix `NN_topic` consistently across **three** files:

| Lesson | Dispensa | Script R | Output |
|--------|----------|----------|--------|
| 01 | `dispense/01_bond_duration_convexity.tex` | `R/01_bond_duration_convexity.R` | `output/01_bond_duration_convexity/` |
| 02 | `dispense/02_eiopa_rfr_bootstrap.tex` | `R/02_eiopa_rfr_bootstrap.R` | `output/02_eiopa_rfr_bootstrap/` |
| 03 | `dispense/03_eiopa_rfr_smith_wilson.tex` | `R/03_eiopa_rfr_smith_wilson.R` | `output/03_eiopa_rfr_smith_wilson/` |
| 03c | `dispense/03c_eiopa_rfr_smith_wilson.tex` | *(nessuno — riusa 03)* | *(nessuno — riusa `output/03_eiopa_rfr_smith_wilson/`)* |
| 04 | `dispense/04_pca_ecb.tex` | `R/04_pca_ecb.R` | `output/04_pca_ecb/` |
| 04b | `dispense/04b_pca_ecb.tex` | `R/04b_pca_ecb.R` | `output/04b_pca_ecb/` |
| 04c | `dispense/04c_pca_eiopa.tex` | `R/04c_pca_eiopa.R` | `output/04c_pca_eiopa/` |

Adding a new lesson: create `NN_topic.tex`, `NN_topic.R`, `output/NN_topic/`.

**La famiglia "03" (Smith-Wilson):** 03 e 03c sono due varianti della stessa lezione, che
differiscono **solo** nella dimostrazione della positiva definitezza della matrice di Wilson
(Sez. 4.2); tutto il resto del testo è identico.

- **03** è la versione **canonica**: la positiva definitezza è dimostrata con una
  rappresentazione integrale *ad hoc* del nucleo (funzioni ausiliarie
  $\varphi_t(x)=1-e^{-\alpha(t-x)}$) più un'induzione discendente sui nodi.
- **03c** ricava la stessa proprietà **per via variazionale**, seguendo Gach (2017,
  `materiale/03/NoteontheSmith-Wilsoninterestratecurve_v14July2017.pdf`): il funzionale che
  Smith-Wilson effettivamente minimizza induce un prodotto scalare esplicito, di cui
  $W(t,u)$ è il rappresentante della valutazione puntuale
  ($\langle W(\cdot,u),h\rangle = h(u)$, verificata per parti); quindi $[W(u_i,u_j)]$ è
  letteralmente una matrice di Gram. Effetto collaterale voluto: l'«energia»
  $\zeta^\top H \zeta$ smette di essere una metafora e coincide col funzionale originale.
  L'apparato di analisi funzionale di Gach (Sobolev, Riesz, completezza) è **deliberatamente
  evitato** — la classe non ha fatto analisi funzionale; resta solo integrazione per parti.
  La dimostrazione della 03 è conservata nell'**Appendice A** della 03c, con un'osservazione
  finale che confronta le due strade.

03c **non ha né script R né cartella output propri**: i numeri non cambiano, quindi riusa
figure e tabelle di `output/03_eiopa_rfr_smith_wilson/` prodotte da
`R/03_eiopa_rfr_smith_wilson.R` (stesso principio con cui 04b riusa
`svd_geometria_esempio.pdf` della 04). Per compilarla serve aver eseguito almeno una volta
lo script della 03.

**La famiglia "04" (PCA su curve dei tassi):** 04, 04b e 04c sono tre varianti
della stessa lezione (PCA sulle variazioni mensili di una curva dei tassi),
non lezioni indipendenti — da qui la numerazione con lettera anziché un
numero progressivo separato:

- **04** è la versione **canonica/finale** (schema calibrazione/validazione
  su curva ECB — loadings stimati fino al 31/12/2025, poi validati su
  marzo/giugno 2026).
- **04b** è la versione **full-sample** su curva ECB (nessuno split
  train/test, PCA e ricostruzione sull'intero campione fino al 30/06/2026).
- **04c** è la stessa metodologia applicata alla curva **EIOPA** anziché
  ECB (mirror strutturale della 04b).

Due script di supporto non seguono la tabella sopra perché non sono
abbinati a una propria dispensa:
- `R/04_pca_ecb_prep.R` — **condiviso** da 04 e 04b: prepara
  `dati/04_ecb_spot.xlsx`, letto da entrambe. Resta senza lettera proprio
  perché serve all'intera famiglia, non a una singola variante.
- `R/04d_analisi_periodi.R` — script di analisi interna (nessuna dispensa
  lo referenzia), tarato sulla calibrazione della 04; scrive in
  `output/04d_analisi_periodi/`.

L'illustrazione geometrica della SVD (`svd_geometria_esempio.pdf`,
indipendente dal campione dati) **non** è più uno script a sé: è generata
da un blocco `local({...})` dentro `R/04_pca_ecb.R` (Sezione 4, "Grafico
0b"), isolato con `local()` apposta per non sporcare l'ambiente globale
con nomi (`A`, `U`, `V`, ...) già usati subito dopo per la PCA vera.
Scrive comunque in `output/04_pca_ecb/`, quindi resta condivisa con la
dispensa 04b, che la referenzia dallo stesso percorso: **04b_pca_ecb.R
non la rigenera**, va eseguito prima `04_pca_ecb.R` almeno una volta.

## Running the scripts

### R scripts (run from within RStudio or `Rscript`)

All R scripts auto-detect their directory via `rstudioapi` and set `setwd()` accordingly. When running from the command line, invoke from the `R/` directory so relative paths resolve correctly.

```bash
# Lezione 01 — Titoli obbligazionari: prezzo, rendimento, duration, convexity
Rscript R/01_bond_duration_convexity.R   # writes PDFs to output/01_bond_duration_convexity/ (nessun dato esterno)

# Lezione 02 — EIOPA RFR nuovo approccio (bootstrap, BoS-26-198)
Rscript R/02_eiopa_rfr_bootstrap.R       # writes PDFs to output/02_eiopa_rfr_bootstrap/

# Lezione 03 — EIOPA RFR Smith-Wilson (approccio variazionale, BoS-25-599)
Rscript R/03_eiopa_rfr_smith_wilson.R    # writes PDFs to output/03_eiopa_rfr_smith_wilson/

# Preparazione dati condivisa da 04 e 04b (PCA su curve ECB)
Rscript R/04_pca_ecb_prep.R             # unisce i due CSV grezzi ECB → dati/04_ecb_spot.xlsx + dati/04b_ecb_spot_20260730.xlsx

# Lezione 04 — PCA ECB in schema calibrazione/validazione (versione finale)
Rscript R/04_pca_ecb.R                  # legge dati/04_ecb_spot.xlsx, writes PDFs to output/04_pca_ecb/

# Lezione 04b — PCA ECB full-sample (senza split calibrazione/validazione)
Rscript R/04b_pca_ecb.R                 # legge dati/04_ecb_spot.xlsx + dati/04b_ecb_spot_20260730.xlsx, writes PDFs to output/04b_pca_ecb/

# Lezione 04c — PCA su variazioni mensili curve EIOPA RFR (EUR, no VA)
Rscript R/04c_pca_eiopa_prep.R          # Step 1: dati/eiopa_zips/*.zip → dati/04c_eiopa_spot.xlsx
Rscript R/04c_pca_eiopa.R               # Step 2: reads xlsx, writes PDFs to output/04c_pca_eiopa/
```

All lesson-04 scripts are BOM-free and run from either RStudio or
`Rscript`. (Le versioni precedenti a questa riorganizzazione, incluso il
pre-2026 `04_pca_ecb.R` che carried a UTF-8 BOM that broke `Rscript`, sono
archiviate in `R/old/`.)

### Python script

```bash
pip install requests openpyxl pandas
python python/dowload_eiopa.py              # main run: builds EIOPA_RFR_EUR_curves.xlsx
python python/dowload_eiopa.py missing      # list missing ZIP files
python python/dowload_eiopa.py diagnose 2022-03-31   # debug single date
```

ZIPs must be placed in `dati/eiopa_zips/`. Two filename formats are accepted: `EIOPA_RFR_YYYYMMDD.zip` or `Month YYYY.zip` (English or Italian month names).

## R package dependencies

| Script | Packages |
|--------|----------|
| `04_pca_ecb_prep.R` | `data.table`, `openxlsx` |
| `04_pca_ecb.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `04b_pca_ecb.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `04c_pca_eiopa_prep.R` | `data.table`, `openxlsx` |
| `04c_pca_eiopa.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `01_bond_duration_convexity.R` | `data.table`, `ggplot2` |
| `02_eiopa_rfr_bootstrap.R` | `ggplot2`, `reshape2`, `openxlsx` |
| `03_eiopa_rfr_smith_wilson.R` | `ggplot2`, `openxlsx` |

## Data flow

```
(nessun dato esterno)
        ↓ 01_bond_duration_convexity.R   → output/01_bond_duration_convexity/*.pdf
          (due titoli didattici, definiti hardcoded nello script — niente file in dati/)

dati/04_dati_originali_ecb_2004_2025.csv (export SDMX grezzo ECB, storico)
dati/04_dati_originali_ecb_2026_finoLuglio.csv (export SDMX grezzo ECB, 2026,
                                                scaricato a parte dal portale)
                        ↓ 04_pca_ecb_prep.R (fread selettivo: 3.5GB → <150MB
                          RAM; filtra alle 20 chiavi spot AAA SR_1Y..SR_20Y)
        ├─→ dati/04_ecb_spot.xlsx            (giornaliero, ott 2004 → 30/06/2026;
        │                                     condiviso da 04 e 04b)
        └─→ dati/04b_ecb_spot_20260730.xlsx  (una riga: curva del 30/07/2026,
                                              per la ricostruzione fuori campione
                                              — usata solo dalla 04b)
                        ↓ 04_pca_ecb.R       (usa dati/04_ecb_spot.xlsx, troncato
                          a fine dic 2025 per la calibrazione; mar/giu 2026
                          restano come insieme di validazione)
                 output/04_pca_ecb/*.pdf
                        ↓ 04b_pca_ecb.R      (usa entrambi i file dati, intero
                          campione, nessuno split)
                 output/04b_pca_ecb/*.pdf

File precedenti (`04_ecb_spot_last.xlsx`, `04_ecb_spot--recenti.xlsx`, versioni
vecchie di `04_ecb_spot.xlsx`), prodotti manualmente prima che
`04_pca_ecb_prep.R` fosse allineato ai due CSV sopra, sono archiviati in
`dati/old/`.

dati/eiopa_zips/*.zip
        ↓ python/dowload_eiopa.py
EIOPA_RFR_EUR_curves.xlsx

dati/eiopa_zips/*.zip (127 archivi mensili, dic 2015 → giu 2026)
        ↓ 04c_pca_eiopa_prep.R
                 dati/04c_eiopa_spot.xlsx
                        ↓ 04c_pca_eiopa.R
                 output/04c_pca_eiopa/*.pdf

dati/02_swap_euribor6m_ric_dic2025.xlsx (par swap EUR vs EURIBOR 6M, dic 2025)
dati/02_dec25_eiopa_rfr_newapproach.csv (benchmark: curva ufficiale EIOPA
                                         ricalcolata col nuovo metodo bootstrap,
                                         per il confronto like-for-like in Sez. 6)
        ↓ 02_eiopa_rfr_bootstrap.R       → output/02_eiopa_rfr_bootstrap/*.pdf

dati/03_eusa.xlsx (par IRS EUR vs EURIBOR 6M, luglio 2025)
dati/03_eiopa_input_swap_dec2025.csv (par swap input EIOPA grezzi, dic 2025,
                                      per la ricostruzione di confronto)
        ↓ 03_eiopa_rfr_smith_wilson.R    → output/03_eiopa_rfr_smith_wilson/*.pdf
```

### materiale/ (riferimenti bibliografici, non letti da nessuno script)

Sottocartelle numeriche allineate alla lezione che citano il materiale
(stesso principio di `dispense/`, `R/`, `output/`, `dati/`):

- `materiale/02/` — documentazione EIOPA-BoS-26-198 e il tool ufficiale
  EIOPA `RFR extrapolation and VA calculation (19 May 2026) (2).xlsm`
  (riferimento manuale, non letto da alcuno script).
- `materiale/03/` — documentazione EIOPA-BoS-25-599, le note
  Smith-Wilson (Gach 2017, Lagerås & Lindholm 2016 = `1602.02011v1.pdf`),
  un riferimento di analisi funzionale (Zeidler) e appunti di revisione
  della dispensa.
- `materiale/04/` — bibliografia PCA/analisi fattoriale (Litterman 1991,
  Rebonato, Meucci, Jolliffe, Alexander) e `svd_geometrica.png`, sorgente
  dell'illustrazione geometrica generata dal blocco `local({...})` in
  `R/04_pca_ecb.R` (Sezione 4, "Grafico 0b").
- `materiale/Options Futures and Other Derivatives by John C Hull.PDF`
  resta nella root: citato dalla 01, dalla 02 e dalla 03 (`\cite{hull2018}`),
  non è specifico di una singola lezione. La 01 non ha una propria
  sottocartella `materiale/`: la bibliografia (Hull cap.~4, Fabozzi, e i
  riferimenti su bisezione/Newton già condivisi con 02/03) non richiede
  documentazione aggiuntiva.

## Key implementation notes

**Lezione 01 — Bond, duration, convexity (`01_bond_duration_convexity.R`):** Prima lezione del corso, autosufficiente (nessun file in `dati/`): due titoli didattici hardcoded in cima allo script, Bond A (cedola 4%, $T=5$, $P_{\mathrm{mkt}}=97.50$) e Bond B (cedola 3%, $T=10$, $P_{\mathrm{mkt}}=96.00$), cedole annue, capitalizzazione annua composta ($P(y)=\sum CF_t(1+y)^{-t}$) — convenzione diversa dall'intensità continua usata internamente dalla curva EIOPA (dispensa 03), scelta apposta per far emergere la relazione $D_{\mathrm{mod}}=D_{\mathrm{Mac}}/(1+y)$. Il rendimento a scadenza (YTM) si trova con bisezione **e** Newton-Raphson (stesso schema, stesso stile di tracciamento delle iterazioni, della dispensa 02); su Bond A, dic. 2025-style: YTM ≈ 4.5706%, Newton converge in 4 iterazioni contro le 31 della bisezione. Duration di Macaulay/modificata e convexity sono derivate/verificate simbolicamente (`bond_dprice`, `bond_d2price`) e confrontate con l'errore di troncamento dell'approssimazione di Taylor su una griglia di shock ±200 bps. La Sezione 5 immunizza una passività a duration singola ($D_L=7$) risolvendo un sistema lineare $2\times 2$ nei pesi di portafoglio — prima comparsa nel corso di una combinazione lineare per aggregare grandezze finanziarie. Nota di implementazione: nei `geom_point()` con `data=` esplicito bisogna passare colonne già nell'unità del `ggplot()` padre (es. `y` in decimale, non already-scaled `y*100`), perché l'estetica ereditata (`aes(x = y*100)`) si applica anche ai dati del nuovo layer — un bug di questo tipo (scala raddoppiata sull'asse x) è stato corretto durante la stesura.

**Lezione 02 — Bootstrap (`02_eiopa_rfr_bootstrap.R`):** Implements the *current* EIOPA EUR methodology per **EIOPA-BoS-26-198** (May 2026), which replaced Smith-Wilson following the Solvency II amendments (Dir (EU) 2025/2, Reg (EU) 2026/269). Pipeline: (1) **bootstrap** with the constant-forward assumption (Annex D) — consecutive tenors solved linearly, non-consecutive ("gap") tenors solved via **Newton-Raphson** with the analytic derivative from Annex D.6 (bisection provided as a robust comparison); (2) **extrapolation** beyond the First Smoothing Point (FSP=20y) toward the UFR via the closed-form weight `B(α,h)=(1−e^{−αh})/(αh)`, using the Last Liquid Forward Rate (LLFR). Parameters (UFR=3.30%, FSP=20y, CRA=10bps, α fixed at the regulatory value with phasing-in 20%→11%) are at the top of the file. Input par rates are read from `dati/02_swap_euribor6m_ric_dic2025.xlsx` (par swap EUR vs EURIBOR 6M, dicembre 2025) with a hardcoded fallback. Sezione 6 confronta la ricostruzione con la curva ufficiale EIOPA ricalcolata col nuovo metodo, letta da `dati/02_dec25_eiopa_rfr_newapproach.csv` (se presente). Note: this is **no longer Smith-Wilson** — there is no dense H matrix, no LU solve, and α is not calibrated.

**Lezione 03 — Smith-Wilson variazionale (`03_eiopa_rfr_smith_wilson.R`):** Derives Smith-Wilson from a minimum-energy variational principle (Lagrange multipliers, SPD projection). Ref: EIOPA-BoS-25-599 (Dec 2025, historical methodology). Input principale: `dati/03_eusa.xlsx` (Bloomberg EUSA*, July 2025 worked example). La Parte 4 (ricostruzione dicembre 2025) confronta anche con i par swap di input EIOPA grezzi in `dati/03_eiopa_input_swap_dec2025.csv`, citati anche nel commento di apertura della dispensa 02 come esempio di ricostruzione condivisa fra le due lezioni.

**Lezione 04 — PCA ECB calibrazione/validazione (`04_pca_ecb.R`):** Versione **canonica/finale** della famiglia 04: rende esplicito lo schema train/test rispetto alla variante full-sample (lezione 04b). Legge `dati/04_ecb_spot.xlsx` (condiviso con la 04b, prodotto da `04_pca_ecb_prep.R`) ma lo tronca a `data_calibrazione <- as.Date("2025-12-31")`: `monthly_full` tiene tutta la serie (serve solo per pescare i target), `monthly_dt` è il campione di calibrazione (256 mesi, 255 variazioni) da cui si stimano i loadings. Anche `curve_df` giornaliero è troncato, così nessun grafico "di lezione" mostra dati post-calibrazione. Varianza spiegata 89,67/8,41/1,43% (η₃ = 99,51%), RMSE in-sample k=3 = 1,40 pb. Mesi campione: ott 2004 / **mag 2015** (centrale) / **dic 2025** (ultimo); la ricostruzione progressiva usa il **centrale**, non l'ultimo, perché a dic 2025 lo score PC2 vale −1,7 pb e la pendenza sarebbe invisibile (mag 2015: PC1 +77,8 / PC2 −42,7 / PC3 −13,2 pb).

La Sezione 4 ha **due** sottosezioni gemelle generate dalla stessa funzione `analizza_target(data_target)` + `figure_target(res, tag, etichetta)`, con `tag ∈ {mar26, giu26}`: target 31/03/2026 (+3 mesi, α = 13,63/−0,11/−1,15%, errore k=3 = **10,25 pb**) e 30/06/2026 (+6 mesi, α = 13,07/−0,12/−1,17%, errore k=3 = **10,35 pb**). Il punto pedagogico è che l'errore a k=3 è **quasi identico ai due orizzonti**: raddoppiare la distanza dal campione non degrada la proiezione, il che giustifica la ricalibrazione annuale. Differiscono solo nella coda (marzo salta a k=4, giugno a k=5). La figura `svd_geometria_esempio.pdf` è condivisa con la 04b (`../output/04_pca_ecb/`) perché è pura illustrazione geometrica indipendente dal campione.

**Lezione 04b — PCA full-sample (`04b_pca_ecb.R`):** Uses SVD on *centred* (not scaled) monthly yield-curve changes; the centring is done explicitly (loop over columns + matrix subtraction) rather than via `scale()`, to mirror the notation of the dispensa. Monthly aggregation takes the last observation of each calendar month, dal campione `dati/04_ecb_spot.xlsx` (ott 2004 → 30/06/2026, 262 mesi), prodotto da `04_pca_ecb_prep.R` (condiviso con la lezione 04, che tronca lo stesso campione per la calibrazione). **Unità: decimali** — la conversione da percentuale avviene una sola volta subito dopo la lettura (`/ 100`); i grafici convertono in fase di display (livelli `* 100` → %, variazioni `* 1e4` → bp). Si noti che la lezione 04c adotta la convenzione opposta (percentuale ovunque).

Lo script è organizzato in **4 sezioni didattiche esplicite** (scelta dell'utente, da preservare): 1) elaborazione dati, 2) calcolo PCA, 3) ricostruzione della curva fuori campione, 4) costruzione dei grafici — tutti i `ggplot`/`ggsave` stanno in fondo, nessun grafico mescolato al calcolo.

Mesi di riferimento per i tre esempi (Sezione 3.3): primo = ottobre 2004, centrale = **settembre 2015**, ultimo = **giugno 2026**. Sono stringhe hardcoded (`mese1`/`mese2`/`mese3`, per scelta esplicita non rese dinamiche) da aggiornare manualmente alla prossima estensione dei dati; il centrale è `ceiling(n_delta/2)` e si sposta ogni volta che il campione cresce — verificarlo sempre con uno script read-only invece di stimarlo. La **ricostruzione progressiva** (Figura 11) usa invece **giugno 2026**, con gli scores citati nel testo (PC1 −34,7 / PC2 +8,6 / PC3 −2,7 pb).

Nella Sezione 4 la curva target è la curva **ECB del 30/07/2026** (`dati/04b_ecb_spot_20260730.xlsx`, fuori campione). Si proietta **direttamente la curva**, non un delta rispetto a una curva di riferimento: `y_hat = V_k V_k^T y`. La giustificazione è che le colonne di `V` sono una base ortonormale completa di R^20, quindi valide per rappresentare qualsiasi vettore, non solo variazioni. *Nota storica*: una versione precedente usava lo schema `y_rif + V_k V_k^T (y − y_rif)` giustificato via Eckart–Young; è stato abbandonato su indicazione esplicita dell'utente, e con esso le voci bibliografiche `lardic2003`/`jamshidian1997`/`golub1997`/`alexander2008`, ora rimosse. Restano citate solo `litterman1991` e `rebonato2004`.

Errori di ricostruzione sulla curva ECB del 30/07/2026 (proiezione diretta, bp): k=1 → 118.94, k=2 → 118.09, **k=3 → 8.99**, k=4 → 6.90, k=5 → 1.66, k≥10 → 0. Scores α = 14,26% / −0,14% / −1,18%. Il profilo è sempre lo stesso: errore enorme con k=1,2 perché una curva di *livelli* (~3%) non è rappresentabile con 1-2 direzioni a media nulla stimate sulle *variazioni*; il salto vero è a k=3.

**Lezione 04c — PCA su curve EIOPA (`04c_pca_eiopa.R`):** Mirror strutturale della lezione 04b (la variante full-sample, non quella con split calibrazione/validazione) con fonte dati diversa: curva regolamentare EIOPA EUR, spot, **senza volatility adjustment** (foglio `RFR_spot_no_VA`), scadenze 1Y–20Y (= LLP euro, quindi solo la parte liquida: l'estrapolazione verso l'UFR non entra nell'analisi). `04c_pca_eiopa_prep.R` estrae le curve dai 127 zip in `dati/eiopa_zips/`; ricava la data dal nome del file **interno** all'archivio (`EIOPA_RFR_<YYYYMMDD>_Term_Structures.xlsx`) perché i nomi degli zip sono incoerenti e il parsing dei mesi inglesi fallisce in locale italiano. **Unità: percentuale ovunque** — la conversione da decimale avviene una sola volta nel prep (`* 100`), così le lezioni 04b e 04c sono direttamente confrontabili. Nessuna aggregazione mensile: EIOPA pubblica già una curva al mese. Rispetto alla 04b cambiano gli eventi macro annotati (campione dic 2015→giu 2026), la ricostruzione progressiva usa il mese di norma massima anziché il centrale, e la sezione finale proietta una curva **ECB** (31/12/2025) sui loadings **EIOPA** (esercizio speculare alla 04b).

**04d — Analisi di supporto (`R/04d_analisi_periodi.R`):** Script interno, **nessuna dispensa lo referenzia**: verifica a mano gli scores/eventi macro citati nel testo della lezione 04, con la PCA calibrata esattamente come `04_pca_ecb.R` (taglio al 31/12/2025). Output in `output/04d_analisi_periodi/`.

**EIOPA downloader (`python/dowload_eiopa.py`):** `START_DATE`/`END_DATE` and `OUTPUT_FILE` are constants near the top. The parser handles two different Excel layouts (old vs new EIOPA format) transparently. The script auto-downloads missing ZIPs from EIOPA's public register; a polite `SLEEP_SEC = 1.5` delay is applied between requests.
