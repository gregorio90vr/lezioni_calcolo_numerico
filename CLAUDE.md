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
| 02 | `dispense/02_eiopa_rfr_bootstrap_smith_wilson.tex` | `R/02_eiopa_rfr_bootstrap.R` + `R/02_eiopa_rfr_smith_wilson.R` (**due** script, in quest'ordine) | `output/02_eiopa_rfr_bootstrap_smith_wilson/` (condivisa) |
| 03 | `dispense/03_pca_ecb.tex` | `R/03_pca_ecb.R` | `output/03_pca_ecb/` |
| 03b | `dispense/approfondimenti/03b_pca_ecb.tex` | `R/03b_pca_ecb.R` | `output/03b_pca_ecb/` |
| 03c | `dispense/approfondimenti/03c_pca_eiopa.tex` | `R/03c_pca_eiopa.R` | `output/03c_pca_eiopa/` |

Adding a new lesson: create `NN_topic.tex`, `NN_topic.R`, `output/NN_topic/`.

**Tre sottocartelle di `dispense/`, tre significati diversi (da non confondere):**
`dispense/` (root) contiene solo le lezioni **principali**, il percorso che lo studente segue
(01, 02, 03). `dispense/approfondimenti/` contiene varianti/note **parallele e valide**, tenute
aggiornate ma non parte del percorso principale — oggi 03b, 03c e `note_H_spd.tex` (v. sotto).
`dispense/backup/` contiene metodologia **superata e congelata** (non più mantenuta) — v. sotto.
`dispense/old/` è il cimitero dei draft abbandonati. In tutti e tre i casi (root esclusa) i file
`.tex` vivono un livello sotto `dispense/`, quindi ogni `\includegraphics{}`/`\input{}` verso
`output/` richiede `../../` invece di `../` — a differenza di `dispense/backup/` (congelato,
path relativi non aggiornati di proposito, v. sotto), i file in `dispense/approfondimenti/`
**hanno** i path corretti perché è contenuto attivo.

- **03b** (`dispense/approfondimenti/03b_pca_ecb.tex`) e **03c**
  (`dispense/approfondimenti/03c_pca_eiopa.tex`) sono varianti della stessa lezione PCA (03),
  non lezioni indipendenti — per questo sono in `approfondimenti/` e non in `dispense/` insieme
  alla 03. Script R (`R/03b_pca_ecb.R`, `R/03c_pca_eiopa.R`) e cartelle di output
  (`output/03b_pca_ecb/`, `output/03c_pca_eiopa/`) **non si sono spostati** — solo le dispense
  `.tex` sono sotto `approfondimenti/`, script e output restano dov'erano.
- **`note_H_spd.tex`** (`dispense/approfondimenti/note_H_spd.tex`) è una nota standalone
  (nessuno script/output proprio) che dimostra che la matrice di Gram di Wilson $H$ è SPD via
  il **Teorema di Mercer** — una **terza** via rispetto alle due già in `dispense/backup/`:
  02e (variazionale, rappresentante di Riesz) e 02f/02g (elementare, induzione discendente sui
  nodi). Era orfana (header che rimandava a un nome file — `03_eiopa_rfr_smith_wilson.tex` —
  non più esistente da quando quel contenuto è diventato `dispense/backup/02c_...tex`); il
  riferimento è stato corretto in occasione dello spostamento in `approfondimenti/`.

**Backup della famiglia "curva RFR EIOPA" (`dispense/backup/`):** prima che la dispensa 02
diventasse il documento unificato, i due metodi avevano trattazioni separate. Quelle vecchie
dispense (complete e valide, non bozze abbandonate — per quello non sono in `dispense/old/`,
il "cimitero" di draft superati del repo) sono conservate come riferimento, con nomi e
contenuto **non più mantenuti attivamente**:

| Lettera | Dispensa (in `dispense/backup/`) | Era | Script/output |
|---------|-----------------------------------|-----|----------------|
| 02a | `02a_eiopa_rfr_bootstrap.tex` | `02_eiopa_rfr_bootstrap.tex` (bootstrap da solo) | `R/old/02_eiopa_rfr_bootstrap.R` → `output/02_eiopa_rfr_bootstrap/` (non rinominati, congelati) |
| 02b | `02b_eiopa_rfr_confronti.tex` | (nota di approfondimento sul bootstrap: residuo di estrapolazione vs benchmark, calcolo LLFR, tool VBA EIOPA — non duplica una lezione, ma è comunque backup) | nessuno script proprio, usa lo stesso output di 02a, congelato |
| 02c | `02c_eiopa_rfr_smith_wilson.tex` | `03_eiopa_rfr_smith_wilson.tex` (Smith-Wilson da solo) | `R/old/03_eiopa_rfr_smith_wilson_finale.R` → `output/03_eiopa_rfr_smith_wilson/` (non rinominati, congelati) |
| 02d | `02d_eiopa_rfr_smith_wilson_dic2025.tex` | `03b_eiopa_rfr_smith_wilson_dic2025.tex` | `R/old/03b_eiopa_rfr_smith_wilson_dic2025.R` → `output/03b_eiopa_rfr_smith_wilson_dic2025/` (script spostato in `R/old/` quando "03b" è servito alla famiglia PCA, nome storico non rinumerato, output invariato) |
| 02e | `02e_eiopa_rfr_smith_wilson.tex` | `03c_eiopa_rfr_smith_wilson.tex` (variante, dimostrazione variazionale) | nessuno, riusa l'output di 02c |
| 02f | `02f_eiopa_rfr_smith_wilson.tex` | `03d_eiopa_rfr_smith_wilson.tex` (nota SPD dettagliata) | nessuno, nota solo testuale |
| 02g | `02g_eiopa_rfr_smith_wilson.tex` | `03e_eiopa_rfr_smith_wilson.tex` (nota SPD canonica) | nessuno, nota solo testuale |

Le cartelle di output e gli script associati **non sono stati rinominati** insieme alle
dispense: sono congelati (nessuno script li rigenera più), quindi rinominarli avrebbe
richiesto riscrivere tutti i path `\includegraphics`/`\input` dentro le dispense di backup
senza alcun beneficio pratico. Per lo stesso motivo i file `.tex` spostati in
`dispense/backup/` **non hanno i path relativi corretti** per la nuova posizione (mancherebbe
un `../` in più, dato che si scende di un livello sotto `dispense/`): il `.pdf` già compilato
in quella stessa cartella resta l'artefatto di riferimento. `R/old/03b_eiopa_rfr_smith_wilson_dic2025.R`
(lo script di 02d) è stato spostato in `R/old/` — non per essere backup dei metodi EIOPA come
gli altri, ma per liberare il prefisso "03b" alla rinumerazione della famiglia PCA (ex "04");
resta invariata la sua cartella di output, `output/03b_eiopa_rfr_smith_wilson_dic2025/`.

**02 — il documento unificato (bootstrap + Smith-Wilson), dispensa ufficiale e finale:** non
è una variante di lezione ma un **merge** (nato come "02c"), ed è l'unica dispensa che tratta
i due metodi insieme — quella che gli studenti usano. Struttura **per fasi**
(scelta esplicita dell'utente, da preservare — la prima versione, che trattava i due metodi a
profondità diverse, è stata respinta perché non aveva evoluzione lineare):

```
1-2  fondamenti comuni (motivazioni, curva/spot/forward/par)   ← testo 02
3    dati di mercato comuni ai due metodi: DLT, CRA, UFR       ← nuova, v. sotto
4    struttura matematica: il metodo Smith-Wilson              ← da 03 §4
       4.1 Last Liquid Point e nodi di pagamento               ← nuova
       4.x Calibrazione di alpha (+ Convergence Point)         ← esistente, formalizzata
5    struttura matematica: il metodo a bootstrap               ← testo 02
6    ricostruzione di dicembre 2025
       6.1 i dati di input (COMUNI ai due metodi)              ← 02 §4.1
       6.2 ricostruzione con Smith-Wilson                      ← da 03 §5
       6.3 ricostruzione col bootstrap                         ← 02 §4.2-4.5
7    confronto tra i due metodi                                ← 02 §6 + §6.3 nuova
8    conclusioni                                               ← 02 §7 + bullet SW
Appendice A  sensitività di alpha (solo bootstrap)             ← testo 02, spostato
```

**Sez. 3 — dati di mercato comuni (DLT, CRA, UFR):** aggiunta successivamente alla stesura
iniziale (che partiva direttamente con Smith-Wilson in Sez. 3), su richiesta esplicita
dell'utente. Motivazione: la Sez. Smith-Wilson usava già tre ingredienti — la lista delle 15
scadenze DLT, il tasso after-CRA, l'intensità $\omega=\UFR^c$ — **senza mai definirli nel
testo che la precede**: in un caso (`\ref{sec:fsp-dlt}`, DLT) e in un altro
(`\ref{sec:cra}`, CRA) il rimando puntava addirittura in avanti, dentro la sezione bootstrap,
cioè dopo. La causa: quei tre punti erano coperti solo da un riquadro di note
("Notazione di questa sezione: tre avvertenze") che nel frattempo era stato commentato e
quindi non compariva più nel PDF. Si sono spostati in una sezione comune, prima della
biforcazione, solo i tre ingredienti **davvero** comuni ai due metodi (DLT, CRA, UFR); il
**First Smoothing Point resta nel bootstrap** (Sez. 5) — è terminologia specifica di quel
metodo, non va confuso con l'atto di spostare "tutto ciò che serve a entrambi".

**Ordine cronologico, non ordine di nascita del documento:** Smith-Wilson è il metodo
storico (in vigore 2016-2026, EIOPA-BoS-25-599) e viene presentato per primo; il bootstrap
(EIOPA-BoS-26-198) lo sostituisce dal 2027 ed è presentato come ciò che segue e rimpiazza —
anche se il documento è nato come merge dentro il testo della 02 (bootstrap), che quindi
inizialmente veniva prima. Invertire l'ordine dopo la stesura iniziale **non è stato uno
scambio meccanico di blocchi**: le label restano agganciate al loro contenuto e i `\ref` si
risolvono da soli, ma tutta la prosa dei punti di giunzione (aperture di sezione, richiami
"come visto sopra"/"come vedremo", il paragrafo di notazione, l'ordine dei bullet in
Conclusioni) andava riscritta a mano perché assumeva la direzione precedente — un'inversione
di ordine narrativo richiede sempre questa verifica punto per punto, non è mai solo un
cambio di label.

I due metodi ricevono così lo **stesso trattamento a ogni livello**, e i dati di input
compaiono **una volta sola** prima della biforcazione: è ciò che rende il confronto un
esperimento controllato. Le §1–§2 della 03 (motivazioni, curva/spot/forward/par) **non** sono
state portate: sono un duplicato quasi verbatim delle §1–§2 della 02, con le stesse label.
Il testo della 02 è preservato integralmente; le modifiche sono il titolo della sezione di
confronto, il re-livellamento delle sottosezioni sotto la §6, i due numeri del confronto
(vedi sotto), e uno spostamento strutturale: l'analisi di sensitività di α (§6 nella prima
stesura, poi §7) è stata portata in **Appendice A** (dopo le Conclusioni, come già fa
`03c_...tex`) perché riguarda solo l'α del bootstrap, non il confronto fra i due metodi;
questo ha fatto scalare Confronto e Conclusioni a §7/§8 (numeri validi dopo l'aggiunta della
Sez. 3 "dati di mercato comuni", v. sopra). Verificato con grep che tutte le label interne
(`fig:alpha-curve`, `fig:alpha-delta`, `tab:alpha-sens`) sono usate solo dentro quella
sezione: lo spostamento non rompe nessun riferimento esterno, a parte i tre `\ref` che vi
puntano (ora "Appendice~\ref{sec:sens-alpha}" invece di "Sez.~\ref{sec:sens-alpha}").

**Niente `keybox` nella Sez. 4 (Smith-Wilson):** su richiesta esplicita dell'utente, i tre
box colorati che la Sez. 4 conteneva in origine (notazione, "due chiusure diverse",
riepilogo minima-energia) sono stati convertiti in `\paragraph{...}` con testo semplice,
per uniformità con la Sez. 5 (bootstrap), che non ne ha mai usati. Nel convertire il box
"due chiusure diverse" il contenuto è stato **accorciato**, non solo de-boxato: duplicava
quasi parola per parola la §7.3 "Il confronto in dettaglio" — resta un rimando lì. Il box
"notazione" (le tre corrispondenze LLP↔FSP, α SW-vs-bootstrap, ω↔UFR) era invece rimasto
solo commentato, non convertito — vedi il paragrafo successivo per come è stato risolto.

**Armonizzazione della notazione (scelte da preservare):** il materiale SW è stato riscritto
nella notazione della 02, non incollato. In particolare: `r(t)`→`r^c(t)` e
`r_ann(t)`→`r(t)` (la 03 usa la convenzione opposta); il par rate after-CRA passa da `r_j`
(03) a `s_j` (convenzione 02, `eq:cra-def`, ora nella Sez. 3 comune) perché in 02 `r_t` è lo
zero rate; lo sconto base UFR passa da `d_j = e^{-ω u_j}` (03) a `δ_j` perché in 02
`d_t = P(0,t)`; `ω` è introdotto come `= UFR^c` (Definizione dell'UFR, Sez. 3) per agganciarlo
alla notazione di 02. `LLP` (03) e `FSP` (02) sono lo stesso punto a 20 anni: **il First
Smoothing Point resta definito solo nel bootstrap** (Sez. 5, `def:fsp`) — non è stato
spostato nella Sez. 3 comune perché è terminologia specifica di quel metodo (scelta esplicita
dell'utente); la Sez. 4.1 ("Il Last Liquid Point e i nodi di pagamento") introduce `LLP` con
una propria `Definizione` che rimanda a `def:fsp` per l'equivalenza $\LLP=\FSP=20$ — prima di
questa sotto-sezione dedicata, `\LLP` compariva in Sez. 4 senza mai essere stato definito nel
testo visibile (il box di notazione che lo faceva era commentato). Il parametro `α` esiste in
**entrambi i metodi con significati diversi** (kernel di Wilson calibrato vs parametro
regolamentare fisso): dentro la Sez. 4 resta `α` (così formule e figure ereditate restano
coerenti), con una distinzione esplicita rispetto all'`α` del bootstrap in apertura della
sotto-sezione "Calibrazione di α" (Sez. 4.x); nella Sez. 7.3, dove i due compaiono affiancati,
si usano `\alphaSW` e `α`. Il Convergence Point `\CP`, che nella prima stesura compariva
dentro il criterio di calibrazione come inciso informale, ha ora una propria `Definizione`
(`def:cp`) subito prima di essere usato ($\CP=\max(\LLP+40,60)=60$ anni) — stesso trattamento
che il bootstrap riserva a `FSP` e `LLFR`.

Due punti del testo 03 sono stati **riscritti** perché in un documento unificato sarebbero
contraddittori o rotti: (a) l'affermazione che «neppure un bootstrap ricorsivo è applicabile»
ai tenor mancanti — falsa in 02c, dove la Sez. 5 quei gap li bootstrappa: è diventata il
paragrafo «Lo stesso problema mal posto, due chiusure diverse», che è anche il perno del
confronto; (b) i rimandi alla tabella di input e alla sezione spline della 03, redirette alle
corrispondenti di 02 (`tab:input-ric-dic`, `sec:fsp-dlt`, `sec:dati-input-dic`). L'unica
collisione di label reale era `sec:ricostruzione`, rinominata `sec:ricostruzione-sw`.
Anche l'apertura della Sez. 7 (Confronto) è stata riformulata: prima lasciava intendere che
le figure confrontassero le due curve *ufficiali* EIOPA, mentre confrontano le **nostre due
ricostruzioni** (ciascuna già validata contro la propria ufficiale in §6.2/§6.3) — lo dice
ora esplicitamente in apertura.

**I due script dedicati (`R/02_eiopa_rfr_bootstrap.R` + `R/02_eiopa_rfr_smith_wilson.R`).**
La dispensa 02 nasceva da un unico script che ricostruiva entrambi i metodi nella stessa
sessione R; è stata poi divisa in **due script**, uno per metodo, che scrivono nella stessa
cartella condivisa e vanno eseguiti **in quest'ordine** (il secondo dipende dal primo). Il
motivo dello split: la Sez. 7 (confronto) e l'export Excel hanno bisogno di ENTRAMBE le curve
insieme, ma i due script sono due processi R separati — niente sopravvive in memoria da uno
all'altro. Lo script bootstrap salva quindi la curva ricostruita in
`curva_bootstrap_dic2025.csv` (dentro `output/02_eiopa_rfr_bootstrap_smith_wilson/`) a fine
sessione; lo script Smith-Wilson lo rilegge per generare Sez. 7 e l'Excel — stesso pattern già
in uso nel repo tra `03_pca_ecb_prep.R` e `03_pca_ecb.R`/`03b_pca_ecb.R` (xlsx intermedio in
`dati/`). Insieme generano tutti e 31 gli artefatti (21 figure + 10 tabelle) + il CSV
intermedio. La dispensa non dipende dagli script dei backup 02a-02g.

`R/02_eiopa_rfr_bootstrap.R` (18 artefatti: Sez. 2 parziale, 3, 5, 6.3, Appendice A):
- **Il bootstrap dei gap è scritto come un loop generico** sui tenor DLT (Newton sul forward
  costante, poi chiusura col vincolo par), non come i ~430 righe di blocchi copia-incollati
  del vecchio standalone (backup 02a). Verificato che riproduce 02a esattamente:
  `tab_curva_bootstrap`, `tab_llfr_calcolo` e `tab_confronto_eiopa` coincidono cifra per cifra.
- **Corregge un bug di 02a.** In `dispense/backup/`'s script associato,
  `R/old/02_eiopa_rfr_bootstrap.R` (righe 160, 178, 194, 209), il forward ai tenor 16–19 è
  calcolato come `tk*rc - (tk-1)*curve[tk,rc]` usando lo stesso tenor invece del precedente, il
  che restituisce semplicemente `rc`. Nello script attuale il forward nel gap 15→20 risulta
  correttamente **costante** (3,5147%), coerente con l'ipotesi di forward costante che la
  tabella stessa dichiara. È l'unica differenza numerica rispetto a 02a.
- **Il confronto fra i due metodi (Sez. 7, nello script Smith-Wilson) usa le due ricostruzioni
  nostre**, non il bootstrap contro la curva SW ufficiale letta dallo zip (scelta esplicita
  dell'utente: isola la sola metodologia). I due numeri citati nel testo: zona liquida
  $<0.35$ bps, massimo in estrapolazione $\sim5.5$ bps a 38 anni. La curva ufficiale resta
  letta e usata per le due validazioni separate (`tab_confronto_eiopa` per il bootstrap,
  `fig_sw_vs_eiopa_dic` per SW, nell'altro script).
- **Suffissi `_jul` rinominati in `_dic`** (nello script Smith-Wilson: `fig_sw_alpha_dic`,
  `fig_sconto_nodi_dic`, `fig_sw_curve_dic`, `fig_sw_vs_eiopa_dic`, `tab_C_dic.tex` con label
  `tab:C-dic`): i dati sono di dicembre, il suffisso `luglio` era un residuo di quando
  l'esempio era luglio 2025.
- Le sette figure che 02a referenzia ma che **nessuno script vivo produceva** (erano residui
  di `R/old/01_eiopa_rfr_bootstrap.R`: `fig01_input_par`, `fig02_bootstrap_zero`,
  `fig03_constant_forward`, `fig04_newton_convergenza`, `fig05_peso_Bah`,
  `fig_spot_fwd_bootstrap`, `fig_vs_benchmark_dic`) sono **riscritte da zero** qui. Il buco
  resta aperto in 02a, che è backup congelato.

`R/02_eiopa_rfr_smith_wilson.R` (13 artefatti: Sez. 4, 6.2, 7, export Excel):
- **La calibrazione di $\alpha$ (PARTE B) usa la bisezione**, non Newton: è il codice scritto
  direttamente dall'utente (non riscritto da zero), riorganizzato in funzioni (`H_heart`,
  `Hmat`/`dHdvmat` a doppio ciclo esplicito — corrispondono riga per riga a
  $\Hmat=[H(u_i,u_j)]$ della dispensa, scelta didattica non una svista di performance —
  `b_solve`, `zeta`, `P_fun`/`spot_int`/`spot_ann`/`fwd_int`/`fwd_ann`,
  `sw_calibra_alpha_bisezione` con traccia delle iterazioni sullo stesso schema di
  `newton_traccia()` dello script bootstrap) e commentato secondo l'approccio della dispensa.
  La bisezione è stata scelta esplicitamente per evitare di dover derivare il forward rispetto
  ad $\alpha$ (necessario invece a Newton: richiederebbe $\partial H/\partial\alpha$,
  $\partial(\partial H/\partial t)/\partial\alpha$ e quindi $\partial b/\partial\alpha$).
  L'utente aveva prototipato anche Newton con tutto questo apparato di derivate analitiche;
  è stato scartato nello script canonico proprio per questo motivo, non per instabilità
  numerica. Verificato in esecuzione: `alpha* = 0.0736` (43 iterazioni di bisezione),
  identico all'$\alpha$ ufficiale EIOPA di dicembre 2025 — stesso numero già documentato nella
  dispensa (Sez. 6.2, Osservazione "$\alpha$ da criterio vs $\alpha$ pubblicato"), quindi il
  passaggio da bisezione-in-un-colpo-solo (funzione `alpha_star_for_mat`, rimossa) a bisezione
  con traccia esplicita non cambia alcun numero pubblicato, solo l'organizzazione del codice.
  La frase della dispensa che dichiarava "*noi implementeremo Newton*" (Sez.
  "Calibrazione di $\alpha$") era già disallineata dal codice canonico precedente (che usava
  comunque bisezione) ed è stata corretta.
  Nota a margine: la macro VBA ufficiale di EIOPA (`R/marcort.txt`, funzioni
  `SmithWilsonBruteForce`/`Galfa`) non usa né bisezione né Newton per $\alpha$: scansiona a
  passi di 0.1 finché il criterio si inverte, poi raffina una cifra decimale alla volta
  (funzione `AlfaScan`, 5 raffinamenti fino a 6 cifre) — una griglia via via più fitta, non
  una vera ricerca di zeri — con un criterio di arresto riformulato in forma chiusa (una
  quantità $\kappa$) per evitare di ricostruire la matrice di Wilson ad ogni valutazione:
  una scorciatoia per la velocità in Excel/VBA, non per la trasparenza didattica. Non ha
  richiesto né richiede modifiche al codice: è solo un confronto istruttivo.

**La ex-famiglia "03" (Smith-Wilson da sola), ora backup 02c/02e/02f/02g:** dalla riorganizzazione
che ha reso la ex-02c la dispensa 02 ufficiale (vedi sopra), l'intera famiglia che trattava
Smith-Wilson da sola è stata spostata in `dispense/backup/` con nomi rinumerati nella sequenza
02x (contenuto non modificato, solo rinominato e spostato — eccetto i rimandi incrociati fra
questi file, riscritti per usare i nuovi nomi). 02c e 02e sono due varianti della stessa
lezione, che differiscono **solo** nella dimostrazione della positiva definitezza della matrice
di Wilson (Sez. 4.2); tutto il resto del testo è identico. 02f e 02g sono note di
approfondimento autonome (non varianti di lezione: niente sezioni economiche, niente
calibrazione/ricostruzione) dedicate a quella stessa dimostrazione.

- **02c** (`dispense/backup/02c_eiopa_rfr_smith_wilson.tex`, ex "03") è la versione
  **canonica**. Dalla riorganizzazione che ha introdotto 02f/02g (allora 03d/03e), la Sez. 4.2
  di 02c **non contiene più** la dimostrazione per esteso: enuncia solo il risultato
  (`Proposizione~\ref{prop:H-spd}`, "La matrice di Wilson è SPD") citando Gach (2017) e
  Lagerås-Lindholm (2016), e rimanda alla nota **02g** per una dimostrazione autosufficiente
  (e alla **02f** per la stessa dimostrazione con più passaggi). Questo per tenere 02c snella
  — era la dispensa che gli studenti leggevano per intero, quando trattava SW da sola.
- **02e** (`dispense/backup/02e_eiopa_rfr_smith_wilson.tex`, ex "03c") ricava la stessa
  proprietà **per via variazionale**, seguendo Gach (2017,
  `materiale/03/NoteontheSmith-Wilsoninterestratecurve_v14July2017.pdf`): il funzionale che
  Smith-Wilson effettivamente minimizza induce un prodotto scalare esplicito, di cui
  $W(t,u)$ è il rappresentante della valutazione puntuale
  ($\langle W(\cdot,u),h\rangle = h(u)$, verificata per parti); quindi $[W(u_i,u_j)]$ è
  letteralmente una matrice di Gram. Effetto collaterale voluto: l'«energia»
  $\zeta^\top H \zeta$ smette di essere una metafora e coincide col funzionale originale.
  L'apparato di analisi funzionale di Gach (Sobolev, Riesz, completezza) è **deliberatamente
  evitato** — la classe non ha fatto analisi funzionale; resta solo integrazione per parti.
  A differenza di 02c, **02e continua a portare la dimostrazione per esteso** (non solo
  l'enunciato): quella variazionale nel corpo principale, e quella elementare (identica a
  02g) conservata nella propria **Appendice A**, con un'osservazione finale che confronta le
  due strade.

02e **non ha né script R né cartella output propri**: i numeri non cambiano, quindi riusa
figure e tabelle di `output/03_eiopa_rfr_smith_wilson/` (nome storico, non rinominato: vedi
nota sulle cartelle di output congelate) prodotte da `R/old/03_eiopa_rfr_smith_wilson_finale.R`
(stesso principio con cui 03b riusa `svd_geometria_esempio.pdf` della 03). Il contenuto di
quella cartella resta quello generato l'ultima volta dallo script quando era ancora attivo;
non viene più rigenerato.

**02g** (`dispense/backup/02g_eiopa_rfr_smith_wilson.tex`, ex "03e") è la sede canonica della
dimostrazione elementare della positiva definitezza della matrice di Wilson (rappresentazione
integrale del nucleo con funzioni ausiliarie $\varphi_t(x)=1-e^{-\alpha(t-x)}$, "la forma
quadratica è un quadrato più l'integrale di un quadrato", induzione discendente sui nodi) — è
il paragrafo che fino alla riorganizzazione stava per esteso in 02c (Sez. 4.2), spostato qui
parola per parola quando 02c è stata alleggerita. Stesso contenuto, verbatim, dell'Appendice A
di 02e.

**02f** (`dispense/backup/02f_eiopa_rfr_smith_wilson.tex`, ex "03d") non è una terza variante
ma una nota di approfondimento ulteriore: isola la stessa dimostrazione di 02g e la sviluppa
con molti più passaggi (ogni integrale calcolato termine a termine, il passaggio
somma-doppia→quadrato mostrato prima a $m=2$, l'induzione con un esempio concreto a $m=3$
nodi) e con verifiche numeriche ($\alpha=0{,}0736$, nodi $u=(1,5,10)$). Nessun risultato nuovo
rispetto a 02g — stesso enunciato, stessa strategia dimostrativa, solo più esplicita.

Sia 02f sia 02g **non hanno né script R né cartella output propri** — a differenza di 02e,
inoltre, non riusano nemmeno le figure della 02c: sono puramente testuali/matematiche, senza
figure. Nota di path: i file spostati in `dispense/backup/` non hanno i riferimenti relativi
`\includegraphics`/`\input` corretti per la nuova posizione (resterebbero da un livello
sbagliato) — i `.pdf` già compilati restano l'artefatto di riferimento; 02f e 02g, non avendo
figure/tabelle esterne, non sono comunque affetti da questo problema e restano ricompilabili.

**La famiglia "03" (PCA su curve dei tassi, ex "04" — rinumerata quando "03" si è liberato
dal riordino EIOPA-RFR):** 03, 03b e 03c sono tre varianti della stessa lezione (PCA sulle
variazioni mensili di una curva dei tassi), non lezioni indipendenti — da qui la numerazione
con lettera anziché un numero progressivo separato:

- **03** (ex "04", `dispense/03_pca_ecb.tex`) è la versione **canonica/finale** (schema
  calibrazione/validazione su curva ECB — loadings stimati fino al 31/12/2025, poi
  validati su marzo/giugno 2026). Resta in `dispense/` (lezione di riferimento).
- **03b** (ex "04b", `dispense/approfondimenti/03b_pca_ecb.tex`) è la versione
  **full-sample** su curva ECB (nessuno split train/test, PCA e ricostruzione
  sull'intero campione fino al 30/06/2026).
- **03c** (ex "04c", `dispense/approfondimenti/03c_pca_eiopa.tex`) è la stessa
  metodologia applicata alla curva **EIOPA** anziché ECB (mirror strutturale della 03b).

03b e 03c sono in `dispense/approfondimenti/` (varianti parallele, non il percorso
principale) dalla riorganizzazione della struttura di `dispense/`; script R e cartelle
`output/` non sono stati toccati da quello spostamento — restano dove il resto di questa
sezione li descrive.

Due script di supporto non seguono la tabella sopra perché non sono
abbinati a una propria dispensa:
- `R/03_pca_ecb_prep.R` — **condiviso** da 03 e 03b: prepara
  `dati/03_ecb_spot.xlsx`, letto da entrambe. Resta senza lettera proprio
  perché serve all'intera famiglia, non a una singola variante.
- `R/03d_analisi_periodi.R` — script di analisi interna (nessuna dispensa
  lo referenzia), tarato sulla calibrazione della 03; scrive in
  `output/03d_analisi_periodi/`.

L'illustrazione geometrica della SVD (`svd_geometria_esempio.pdf`,
indipendente dal campione dati) **non** è più uno script a sé: è generata
da un blocco `local({...})` dentro `R/03_pca_ecb.R` (Sezione 4, "Grafico
0b"), isolato con `local()` apposta per non sporcare l'ambiente globale
con nomi (`A`, `U`, `V`, ...) già usati subito dopo per la PCA vera.
Scrive comunque in `output/03_pca_ecb/`, quindi resta condivisa con la
dispensa 03b, che la referenzia dallo stesso percorso: **03b_pca_ecb.R
non la rigenera**, va eseguito prima `03_pca_ecb.R` almeno una volta.

## Running the scripts

### R scripts (run from within RStudio or `Rscript`)

All R scripts auto-detect their directory via `rstudioapi` and set `setwd()` accordingly. When running from the command line, invoke from the `R/` directory so relative paths resolve correctly.

```bash
# Lezione 01 — Titoli obbligazionari: prezzo, rendimento, duration, convexity
Rscript R/01_bond_duration_convexity.R   # writes PDFs to output/01_bond_duration_convexity/ (nessun dato esterno)

# Dispensa 02 (ufficiale) — bootstrap (BoS-26-198) + Smith-Wilson (BoS-25-599) + confronto
# Due script, DA ESEGUIRE IN QUESTO ORDINE (il secondo rilegge un CSV scritto dal primo):
Rscript R/02_eiopa_rfr_bootstrap.R       # 1/2: bootstrap, 18 artefatti + CSV intermedio
Rscript R/02_eiopa_rfr_smith_wilson.R    # 2/2: Smith-Wilson + Sez.7 + Excel, 13 artefatti
# entrambi in output/02_eiopa_rfr_bootstrap_smith_wilson/ (31 artefatti totali)

# Preparazione dati condivisa da 03 e 03b (PCA su curve ECB)
Rscript R/03_pca_ecb_prep.R             # unisce i due CSV grezzi ECB → dati/03_ecb_spot.xlsx + dati/03b_ecb_spot_20260730.xlsx

# Lezione 03 — PCA ECB in schema calibrazione/validazione (versione finale)
Rscript R/03_pca_ecb.R                  # legge dati/03_ecb_spot.xlsx, writes PDFs to output/03_pca_ecb/

# Lezione 03b — PCA ECB full-sample (senza split calibrazione/validazione)
Rscript R/03b_pca_ecb.R                 # legge dati/03_ecb_spot.xlsx + dati/03b_ecb_spot_20260730.xlsx, writes PDFs to output/03b_pca_ecb/

# Lezione 03c — PCA su variazioni mensili curve EIOPA RFR (EUR, no VA)
Rscript R/03c_pca_eiopa_prep.R          # Step 1: dati/eiopa_zips/*.zip → dati/03c_eiopa_spot.xlsx
Rscript R/03c_pca_eiopa.R               # Step 2: reads xlsx, writes PDFs to output/03c_pca_eiopa/
```

All lesson-03 (PCA) scripts are BOM-free and run from either RStudio or
`Rscript`. (Le versioni precedenti a questa riorganizzazione, incluso il
pre-2026 `04_pca_ecb.R` (nome storico pre-rinumerazione) che carried a UTF-8
BOM that broke `Rscript`, sono archiviate in `R/old/`.)

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
| `03_pca_ecb_prep.R` | `data.table`, `openxlsx` |
| `03_pca_ecb.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `03b_pca_ecb.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `03c_pca_eiopa_prep.R` | `data.table`, `openxlsx` |
| `03c_pca_eiopa.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `01_bond_duration_convexity.R` | `data.table`, `ggplot2` |
| `02_eiopa_rfr_bootstrap.R` | `data.table`, `ggplot2`, `reshape2`, `openxlsx` |
| `02_eiopa_rfr_smith_wilson.R` | `data.table`, `ggplot2`, `reshape2`, `openxlsx` |

## Data flow

```
(nessun dato esterno)
        ↓ 01_bond_duration_convexity.R   → output/01_bond_duration_convexity/*.pdf
          (due titoli didattici, definiti hardcoded nello script — niente file in dati/)

dati/03_dati_originali_ecb_2004_2025.csv (export SDMX grezzo ECB, storico)
dati/03_dati_originali_ecb_2026_finoLuglio.csv (export SDMX grezzo ECB, 2026,
                                                scaricato a parte dal portale)
                        ↓ 03_pca_ecb_prep.R (fread selettivo: 3.5GB → <150MB
                          RAM; filtra alle 20 chiavi spot AAA SR_1Y..SR_20Y)
        ├─→ dati/03_ecb_spot.xlsx            (giornaliero, ott 2004 → 30/06/2026;
        │                                     condiviso da 03 e 03b)
        └─→ dati/03b_ecb_spot_20260730.xlsx  (una riga: curva del 30/07/2026,
                                              per la ricostruzione fuori campione
                                              — usata solo dalla 03b)
                        ↓ 03_pca_ecb.R       (usa dati/03_ecb_spot.xlsx, troncato
                          a fine dic 2025 per la calibrazione; mar/giu 2026
                          restano come insieme di validazione)
                 output/03_pca_ecb/*.pdf
                        ↓ 03b_pca_ecb.R      (usa entrambi i file dati, intero
                          campione, nessuno split)
                 output/03b_pca_ecb/*.pdf

File precedenti (`04_ecb_spot_last.xlsx`, `04_ecb_spot--recenti.xlsx`, versioni
vecchie con nomi pre-rinumerazione), prodotti manualmente prima che
`03_pca_ecb_prep.R` (ex `04_pca_ecb_prep.R`) fosse allineato ai due CSV sopra,
sono archiviati in `dati/old/`.

dati/eiopa_zips/*.zip
        ↓ python/dowload_eiopa.py
EIOPA_RFR_EUR_curves.xlsx

dati/eiopa_zips/*.zip (127 archivi mensili, dic 2015 → giu 2026)
        ↓ 03c_pca_eiopa_prep.R
                 dati/03c_eiopa_spot.xlsx
                        ↓ 03c_pca_eiopa.R
                 output/03c_pca_eiopa/*.pdf

dati/02_swap_euribor6m_ric_dic2025.xlsx (par swap EUR vs EURIBOR 6M, dic 2025 —
                                         STESSO input per bootstrap e Smith-Wilson)
dati/02_dec25_eiopa_rfr_newapproach.csv (benchmark: curva ufficiale EIOPA
                                         ricalcolata col nuovo metodo bootstrap)
dati/eiopa_zips/EIOPA_RFR_202512??.zip  (curva ufficiale Smith-Wilson)
        ↓ 02_eiopa_rfr_bootstrap.R (1/2)
                 output/02_eiopa_rfr_bootstrap_smith_wilson/  (18 artefatti)
                        + curva_bootstrap_dic2025.csv (per lo script 2/2)
                        ↓ 02_eiopa_rfr_smith_wilson.R (2/2, rilegge il CSV sopra)
                 stessa cartella  (13 artefatti in più: SW + Sez.7 + Excel)

--- pipeline storiche, ora backup (script spostati in R/old/, output congelato) ---
dati/02_swap_euribor6m_ric_dic2025.xlsx, dati/02_dec25_eiopa_rfr_newapproach.csv
        ↓ R/old/02_eiopa_rfr_bootstrap.R  → output/02_eiopa_rfr_bootstrap/*.pdf
          (alimentava dispense/02_eiopa_rfr_bootstrap.tex, ora dispense/backup/02a_...)

dati/03_eusa.xlsx (par IRS EUR vs EURIBOR 6M, luglio 2025)
dati/03_eiopa_input_swap_dec2025.csv (par swap input EIOPA grezzi, dic 2025,
                                      per la ricostruzione di confronto)
        ↓ R/old/03_eiopa_rfr_smith_wilson_finale.R → output/03_eiopa_rfr_smith_wilson/*.pdf
          (alimentava dispense/03_eiopa_rfr_smith_wilson.tex, ora dispense/backup/02c_...)
```

### materiale/ (riferimenti bibliografici, non letti da nessuno script)

Sottocartelle numeriche allineate alla lezione che citano il materiale
(stesso principio di `dispense/`, `R/`, `output/`, `dati/`):

- `materiale/02/` — documentazione EIOPA-BoS-26-198 (bootstrap) **e**
  EIOPA-BoS-25-599 (Smith-Wilson): unite qui durante il riordino che ha reso
  "02" la dispensa unificata (prima erano divise fra `materiale/02/` e
  `materiale/03/`, quando le due metodologie avevano dispense separate).
  Contiene il tool ufficiale EIOPA `RFR extrapolation and VA calculation
  (19 May 2026) (2).xlsm`, le note Smith-Wilson (Gach 2017, Lagerås &
  Lindholm 2016 = `1602.02011v1.pdf`), un riferimento di analisi funzionale
  (Zeidler) e appunti di revisione (nessuno letto da alcuno script).
- `materiale/03/` — bibliografia PCA/analisi fattoriale (Litterman 1991,
  Rebonato, Meucci, Jolliffe) e `svd_geometrica.png`, sorgente
  dell'illustrazione geometrica generata dal blocco `local({...})` in
  `R/03_pca_ecb.R` (Sezione 4, "Grafico 0b"). Prima della rinumerazione
  della famiglia PCA (ex "04") questa cartella era occupata dalla
  bibliografia Smith-Wilson, spostata in `materiale/02/` (vedi sopra) per
  liberare il numero.
- `materiale/Options Futures and Other Derivatives by John C Hull.PDF`
  resta nella root: citato dalla 01 e dalla 02 (`\cite{hull2018}`),
  non è specifico di una singola lezione (la 03/PCA non lo cita: bibliografia
  disgiunta). La 01 non ha una propria sottocartella `materiale/`: la
  bibliografia (Hull cap.~4, Fabozzi, e i riferimenti su bisezione/Newton
  già condivisi con 02) non richiede documentazione aggiuntiva.

## Key implementation notes

**Lezione 01 — Bond, duration, convexity (`01_bond_duration_convexity.R`):** Prima lezione del corso, autosufficiente (nessun file in `dati/`): due titoli didattici hardcoded in cima allo script, Bond A (cedola 4%, $T=5$, $P_{\mathrm{mkt}}=97.50$) e Bond B (cedola 3%, $T=10$, $P_{\mathrm{mkt}}=96.00$), cedole annue, capitalizzazione annua composta ($P(y)=\sum CF_t(1+y)^{-t}$) — convenzione diversa dall'intensità continua usata internamente dalla curva EIOPA (dispensa 02, sezione Smith-Wilson), scelta apposta per far emergere la relazione $D_{\mathrm{mod}}=D_{\mathrm{Mac}}/(1+y)$. Il rendimento a scadenza (YTM) si trova con bisezione **e** Newton-Raphson (stesso schema, stesso stile di tracciamento delle iterazioni, della dispensa 02, sezione bootstrap); su Bond A, dic. 2025-style: YTM ≈ 4.5706%, Newton converge in 4 iterazioni contro le 31 della bisezione. Duration di Macaulay/modificata e convexity sono derivate/verificate simbolicamente (`bond_dprice`, `bond_d2price`) e confrontate con l'errore di troncamento dell'approssimazione di Taylor su una griglia di shock ±200 bps. La Sezione 5 immunizza una passività a duration singola ($D_L=7$) risolvendo un sistema lineare $2\times 2$ nei pesi di portafoglio — prima comparsa nel corso di una combinazione lineare per aggregare grandezze finanziarie. Nota di implementazione: nei `geom_point()` con `data=` esplicito bisogna passare colonne già nell'unità del `ggplot()` padre (es. `y` in decimale, non already-scaled `y*100`), perché l'estetica ereditata (`aes(x = y*100)`) si applica anche ai dati del nuovo layer — un bug di questo tipo (scala raddoppiata sull'asse x) è stato corretto durante la stesura.

**Bootstrap, la parte che alimenta la dispensa 02 ufficiale (`R/02_eiopa_rfr_bootstrap.R`):**
implements the *current* EIOPA EUR methodology per **EIOPA-BoS-26-198** (May 2026), which
replaced Smith-Wilson following the Solvency II amendments (Dir (EU) 2025/2, Reg (EU)
2026/269). Pipeline: (1) **bootstrap** with the constant-forward assumption (Annex D) —
consecutive tenors solved linearly, non-consecutive ("gap") tenors solved via
**Newton-Raphson** with the analytic derivative from Annex D.6; (2) **extrapolation** beyond
the First Smoothing Point (FSP=20y) toward the UFR via the closed-form weight
`B(α,h)=(1−e^{−αh})/(αh)`, using the Last Liquid Forward Rate (LLFR). Parameters (UFR=3.30%,
FSP=20y, CRA=10bps, α fixed at the regulatory value with phasing-in 20%→11%) are at the top of
the file. Input par rates are read from `dati/02_swap_euribor6m_ric_dic2025.xlsx` (par swap
EUR vs EURIBOR 6M, dicembre 2025) with a hardcoded fallback. La sezione finale confronta la
ricostruzione con la curva ufficiale EIOPA ricalcolata col nuovo metodo, letta da
`dati/02_dec25_eiopa_rfr_newapproach.csv` (se presente). Note: this is **no longer
Smith-Wilson** — there is no dense H matrix, no LU solve, and α is not calibrated. (Backup
frozen: `R/old/02_eiopa_rfr_bootstrap.R`, quasi identico ma con un bug ai tenor 16-19 — vedi
sopra — alimentava lo standalone `dispense/backup/02a_eiopa_rfr_bootstrap.tex`.)

**Smith-Wilson variazionale, materiale di riferimento per la parte SW della dispensa 02
ufficiale (`R/02_eiopa_rfr_smith_wilson.R`):** derives Smith-Wilson from a minimum-energy
variational principle (Lagrange multipliers, SPD projection). Ref: EIOPA-BoS-25-599 (Dec 2025,
historical methodology). L'implementazione attuale (bisezione per α, vedi sopra) usa come
input `dati/02_swap_euribor6m_ric_dic2025.xlsx`, lo stesso del bootstrap. Il backup frozen
`R/old/03_eiopa_rfr_smith_wilson_finale.R` (che alimentava lo standalone
`dispense/backup/02c_eiopa_rfr_smith_wilson.tex`) usava invece un input diverso,
`dati/03_eusa.xlsx` (Bloomberg EUSA*, July 2025 worked example), e confrontava anche con i par
swap di input EIOPA grezzi in `dati/03_eiopa_input_swap_dec2025.csv`.

**Lezione 03 — PCA ECB calibrazione/validazione (`03_pca_ecb.R`):** Versione **canonica/finale** della famiglia 03: rende esplicito lo schema train/test rispetto alla variante full-sample (lezione 03b). Legge `dati/03_ecb_spot.xlsx` (condiviso con la 03b, prodotto da `03_pca_ecb_prep.R`) ma lo tronca a `data_calibrazione <- as.Date("2025-12-31")`: `monthly_full` tiene tutta la serie (serve solo per pescare i target), `monthly_dt` è il campione di calibrazione (256 mesi, 255 variazioni) da cui si stimano i loadings. Anche `curve_df` giornaliero è troncato, così nessun grafico "di lezione" mostra dati post-calibrazione. Varianza spiegata 89,67/8,41/1,43% (η₃ = 99,51%), RMSE in-sample k=3 = 1,40 pb. Mesi campione: ott 2004 / **mag 2015** (centrale) / **dic 2025** (ultimo); la ricostruzione progressiva usa il **centrale**, non l'ultimo, perché a dic 2025 lo score PC2 vale −1,7 pb e la pendenza sarebbe invisibile (mag 2015: PC1 +77,8 / PC2 −42,7 / PC3 −13,2 pb).

La Sezione 4 ha **due** sottosezioni gemelle generate dalla stessa funzione `analizza_target(data_target)` + `figure_target(res, tag, etichetta)`, con `tag ∈ {mar26, giu26}`: target 31/03/2026 (+3 mesi, α = 13,63/−0,11/−1,15%, errore k=3 = **10,25 pb**) e 30/06/2026 (+6 mesi, α = 13,07/−0,12/−1,17%, errore k=3 = **10,35 pb**). Il punto pedagogico è che l'errore a k=3 è **quasi identico ai due orizzonti**: raddoppiare la distanza dal campione non degrada la proiezione, il che giustifica la ricalibrazione annuale. Differiscono solo nella coda (marzo salta a k=4, giugno a k=5). La figura `svd_geometria_esempio.pdf` è condivisa con la 03b (`../output/03_pca_ecb/`) perché è pura illustrazione geometrica indipendente dal campione.

**Lezione 03b — PCA full-sample (`03b_pca_ecb.R`):** Uses SVD on *centred* (not scaled) monthly yield-curve changes; the centring is done explicitly (loop over columns + matrix subtraction) rather than via `scale()`, to mirror the notation of the dispensa. Monthly aggregation takes the last observation of each calendar month, dal campione `dati/03_ecb_spot.xlsx` (ott 2004 → 30/06/2026, 262 mesi), prodotto da `03_pca_ecb_prep.R` (condiviso con la lezione 03, che tronca lo stesso campione per la calibrazione). **Unità: decimali** — la conversione da percentuale avviene una sola volta subito dopo la lettura (`/ 100`); i grafici convertono in fase di display (livelli `* 100` → %, variazioni `* 1e4` → bp). Si noti che la lezione 03c adotta la convenzione opposta (percentuale ovunque).

Lo script è organizzato in **4 sezioni didattiche esplicite** (scelta dell'utente, da preservare): 1) elaborazione dati, 2) calcolo PCA, 3) ricostruzione della curva fuori campione, 4) costruzione dei grafici — tutti i `ggplot`/`ggsave` stanno in fondo, nessun grafico mescolato al calcolo.

Mesi di riferimento per i tre esempi (Sezione 3.3): primo = ottobre 2004, centrale = **settembre 2015**, ultimo = **giugno 2026**. Sono stringhe hardcoded (`mese1`/`mese2`/`mese3`, per scelta esplicita non rese dinamiche) da aggiornare manualmente alla prossima estensione dei dati; il centrale è `ceiling(n_delta/2)` e si sposta ogni volta che il campione cresce — verificarlo sempre con uno script read-only invece di stimarlo. La **ricostruzione progressiva** (Figura 11) usa invece **giugno 2026**, con gli scores citati nel testo (PC1 −34,7 / PC2 +8,6 / PC3 −2,7 pb).

Nella Sezione 4 la curva target è la curva **ECB del 30/07/2026** (`dati/03b_ecb_spot_20260730.xlsx`, fuori campione). Si proietta **direttamente la curva**, non un delta rispetto a una curva di riferimento: `y_hat = V_k V_k^T y`. La giustificazione è che le colonne di `V` sono una base ortonormale completa di R^20, quindi valide per rappresentare qualsiasi vettore, non solo variazioni. *Nota storica*: una versione precedente usava lo schema `y_rif + V_k V_k^T (y − y_rif)` giustificato via Eckart–Young; è stato abbandonato su indicazione esplicita dell'utente, e con esso le voci bibliografiche `lardic2003`/`jamshidian1997`/`golub1997`/`alexander2008`, ora rimosse. Restano citate solo `litterman1991` e `rebonato2004`.

Errori di ricostruzione sulla curva ECB del 30/07/2026 (proiezione diretta, bp): k=1 → 118.94, k=2 → 118.09, **k=3 → 8.99**, k=4 → 6.90, k=5 → 1.66, k≥10 → 0. Scores α = 14,26% / −0,14% / −1,18%. Il profilo è sempre lo stesso: errore enorme con k=1,2 perché una curva di *livelli* (~3%) non è rappresentabile con 1-2 direzioni a media nulla stimate sulle *variazioni*; il salto vero è a k=3.

**Lezione 03c — PCA su curve EIOPA (`03c_pca_eiopa.R`):** Mirror strutturale della lezione 03b (la variante full-sample, non quella con split calibrazione/validazione) con fonte dati diversa: curva regolamentare EIOPA EUR, spot, **senza volatility adjustment** (foglio `RFR_spot_no_VA`), scadenze 1Y–20Y (= LLP euro, quindi solo la parte liquida: l'estrapolazione verso l'UFR non entra nell'analisi). `03c_pca_eiopa_prep.R` estrae le curve dai 127 zip in `dati/eiopa_zips/`; ricava la data dal nome del file **interno** all'archivio (`EIOPA_RFR_<YYYYMMDD>_Term_Structures.xlsx`) perché i nomi degli zip sono incoerenti e il parsing dei mesi inglesi fallisce in locale italiano. **Unità: percentuale ovunque** — la conversione da decimale avviene una sola volta nel prep (`* 100`), così le lezioni 03b e 03c sono direttamente confrontabili. Nessuna aggregazione mensile: EIOPA pubblica già una curva al mese. Rispetto alla 03b cambiano gli eventi macro annotati (campione dic 2015→giu 2026), la ricostruzione progressiva usa il mese di norma massima anziché il centrale, e la sezione finale proietta una curva **ECB** (31/12/2025) sui loadings **EIOPA** (esercizio speculare alla 03b).

**03d — Analisi di supporto (`R/03d_analisi_periodi.R`):** Script interno, **nessuna dispensa lo referenzia**: verifica a mano gli scores/eventi macro citati nel testo della lezione 03, con la PCA calibrata esattamente come `03_pca_ecb.R` (taglio al 31/12/2025). Output in `output/03d_analisi_periodi/`.

**EIOPA downloader (`python/dowload_eiopa.py`):** `START_DATE`/`END_DATE` and `OUTPUT_FILE` are constants near the top. The parser handles two different Excel layouts (old vs new EIOPA format) transparently. The script auto-downloads missing ZIPs from EIOPA's public register; a polite `SLEEP_SEC = 1.5` delay is applied between requests.
