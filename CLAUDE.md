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
| 01 | `dispense/01_eiopa_rfr_bootstrap.tex` | `R/01_eiopa_rfr_bootstrap.R` | `output/01_eiopa_rfr_bootstrap/` |
| 03 | `dispense/03_eiopa_rfr_smith_wilson.tex` | `R/03_eiopa_rfr_smith_wilson.R` | `output/03_eiopa_rfr_smith_wilson/` |
| 04 | `dispense/04_pca_ecb.tex` | `R/04_pca_ecb.R` | `output/04_pca_ecb/` |

Adding a new lesson: create `NN_topic.tex`, `NN_topic.R`, `output/NN_topic/`.

## Running the scripts

### R scripts (run from within RStudio or `Rscript`)

All R scripts auto-detect their directory via `rstudioapi` and set `setwd()` accordingly. When running from the command line, invoke from the `R/` directory so relative paths resolve correctly.

```bash
# Lezione 01 — EIOPA RFR nuovo approccio (bootstrap, BoS-26-198)
Rscript R/01_eiopa_rfr_bootstrap.R       # writes PDFs to output/01_eiopa_rfr_bootstrap/

# Lezione 03 — EIOPA RFR Smith-Wilson (approccio variazionale, BoS-25-599)
Rscript R/03_eiopa_rfr_smith_wilson.R    # writes PDFs to output/03_eiopa_rfr_smith_wilson/

# Lezione 04 — PCA su variazioni mensili curve ECB
Rscript R/04_pca_ecb_prep.R             # Step 1: dati/data.csv → dati/04_ecb_spot.xlsx
Rscript R/04_pca_ecb.R                  # Step 2: reads xlsx, writes PDFs to output/04_pca_ecb/
```

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
| `01_eiopa_rfr_bootstrap.R` | `ggplot2`, `reshape2`, `openxlsx` |
| `03_eiopa_rfr_smith_wilson.R` | `ggplot2`, `openxlsx` |

## Data flow

```
ECB Portal CSV → dati/data.csv
                        ↓ 04_pca_ecb_prep.R
                 dati/04_ecb_spot.xlsx
                        ↓ 04_pca_ecb.R
                 output/04_pca_ecb/*.pdf

dati/eiopa_zips/*.zip
        ↓ python/dowload_eiopa.py
EIOPA_RFR_EUR_curves.xlsx

dati/01_eeswe.xlsx (par OIS €STR, ticker Bloomberg EESWE*)
        ↓ 01_eiopa_rfr_bootstrap.R       → output/01_eiopa_rfr_bootstrap/*.pdf

dati/03_eusa.xlsx (par IRS EUR vs EURIBOR 6M)
        ↓ 03_eiopa_rfr_smith_wilson.R    → output/03_eiopa_rfr_smith_wilson/*.pdf
```

## Key implementation notes

**Lezione 01 — Bootstrap (`01_eiopa_rfr_bootstrap.R`):** Implements the *current* EIOPA EUR methodology per **EIOPA-BoS-26-198** (May 2026), which replaced Smith-Wilson following the Solvency II amendments (Dir (EU) 2025/2, Reg (EU) 2026/269). Pipeline: (1) **bootstrap** with the constant-forward assumption (Annex D) — consecutive tenors solved linearly, non-consecutive ("gap") tenors solved via **Newton-Raphson** with the analytic derivative from Annex D.6 (bisection provided as a robust comparison); (2) **extrapolation** beyond the First Smoothing Point (FSP=20y) toward the UFR via the closed-form weight `B(α,h)=(1−e^{−αh})/(αh)`, using the Last Liquid Forward Rate (LLFR). Parameters (UFR=3.30%, FSP=20y, CRA=10bps, α fixed at the regulatory value with phasing-in 20%→11%) are at the top of the file. Input par rates are read from `dati/01_eeswe.xlsx` (Bloomberg €STR ticker `EESWE*`, valuation date 29/05/2026) with a hardcoded fallback. Note: this is **no longer Smith-Wilson** — there is no dense H matrix, no LU solve, and α is not calibrated.

**Lezione 03 — Smith-Wilson variazionale (`03_eiopa_rfr_smith_wilson.R`):** Derives Smith-Wilson from a minimum-energy variational principle (Lagrange multipliers, SPD projection). Ref: EIOPA-BoS-25-599 (Dec 2025, historical methodology). Input: `dati/03_eusa.xlsx` (Bloomberg EUSA*, July 2025 worked example).

**Lezione 04 — PCA (`04_pca_ecb.R`):** Uses SVD on *centred* (not scaled) monthly yield-curve changes. Monthly aggregation takes the last observation of each calendar month. Requires `04_pca_ecb_prep.R` to have been run first; will error with a clear message if the xlsx is missing.

**EIOPA downloader (`python/dowload_eiopa.py`):** `START_DATE`/`END_DATE` and `OUTPUT_FILE` are constants near the top. The parser handles two different Excel layouts (old vs new EIOPA format) transparently. The script auto-downloads missing ZIPs from EIOPA's public register; a polite `SLEEP_SEC = 1.5` delay is applied between requests.
