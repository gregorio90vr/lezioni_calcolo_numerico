# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Teaching materials for *Laboratorio di Calcolo Numerico*, UniVR — A.A. 2026/2027. The repository contains:

- **R scripts** implementing financial/numerical methods (Smith-Wilson curve, PCA on yield curves)
- **Python utility** for downloading and parsing EIOPA ZIP files
- **Data** in `dati/` (ECB CSV, EIOPA ZIPs) and **generated output** PDFs in `output/`

## Running the scripts

### R scripts (run from within RStudio or `Rscript`)

All R scripts auto-detect their directory via `rstudioapi` and set `setwd()` accordingly. When running from the command line, invoke from the `R/` directory so relative paths resolve correctly.

```bash
# From repo root:
Rscript R/prepare_pca_input.R          # Step 1: converts dati/data.csv → dati/pca_input_curves_1Y_20Y.xlsx
Rscript R/lezione_pca_mensile.R        # Step 2: reads xlsx, writes PDFs to output/pca_mensile/
Rscript R/curva_eiopa_rfr_CN.R         # Standalone: writes PDFs to output/curva_eiopa_rfr/
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
| `prepare_pca_input.R` | `data.table`, `openxlsx` |
| `lezione_pca_mensile.R` | `data.table`, `openxlsx`, `ggplot2`, `lubridate`, `scales`, `plot3D` (optional) |
| `curva_eiopa_rfr_CN.R` | `ggplot2`, `reshape2`, `openxlsx` |

## Data flow

```
ECB Portal CSV → dati/data.csv
                        ↓ prepare_pca_input.R
                 dati/pca_input_curves_1Y_20Y.xlsx
                        ↓ lezione_pca_mensile.R
                 output/pca_mensile/*.pdf

dati/eiopa_zips/*.zip
        ↓ python/dowload_eiopa.py
EIOPA_RFR_EUR_curves.xlsx

dati/EESWE.xlsx (par OIS €STR, ticker Bloomberg EESWE*)
        ↓ curva_eiopa_rfr_CN.R
output/curva_eiopa_rfr/*.pdf
```

## Key implementation notes

**EIOPA RFR curve (`curva_eiopa_rfr_CN.R`):** Implements the *current* EIOPA EUR methodology per **EIOPA-BoS-26-198** (May 2026), which replaced Smith-Wilson following the Solvency II amendments (Dir (EU) 2025/2, Reg (EU) 2026/269). Pipeline: (1) **bootstrap** with the constant-forward assumption (Annex D) — consecutive tenors solved linearly, non-consecutive ("gap") tenors solved via **Newton-Raphson** with the analytic derivative from Annex D.6 (bisection provided as a robust comparison); (2) **extrapolation** beyond the First Smoothing Point (FSP=20y) toward the UFR via the closed-form weight `B(α,h)=(1−e^{−αh})/(αh)`, using the Last Liquid Forward Rate (LLFR). Parameters (UFR=3.30%, FSP=20y, CRA=10bps, α fixed at the regulatory value with phasing-in 20%→11%) are at the top of the file. Input par rates are read from `dati/EESWE.xlsx` (Bloomberg €STR ticker `EESWE*`, valuation date 29/05/2026) with a hardcoded fallback. Note: this is **no longer Smith-Wilson** — there is no dense H matrix, no LU solve, and α is not calibrated.

**PCA (`lezione_pca_mensile.R`):** Uses SVD on *centred* (not scaled) monthly yield-curve changes. Monthly aggregation takes the last observation of each calendar month. Requires `prepare_pca_input.R` to have been run first; will error with a clear message if the xlsx is missing.

**EIOPA downloader (`python/dowload_eiopa.py`):** `START_DATE`/`END_DATE` and `OUTPUT_FILE` are constants near the top. The parser handles two different Excel layouts (old vs new EIOPA format) transparently. The script auto-downloads missing ZIPs from EIOPA's public register; a polite `SLEEP_SEC = 1.5` delay is applied between requests.
