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
| `curva_eiopa_rfr_CN.R` | `ggplot2`, `reshape2` |

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

(curva_eiopa_rfr_CN.R uses hardcoded illustrative data — no external input file needed)
```

## Key implementation notes

**Smith-Wilson (`curva_eiopa_rfr_CN.R`):** Implements the full EIOPA EUR methodology per EIOPA-BoS-25-599. Parameters (UFR = 3.30%, LLP = 20y, CP = 60y, CRA = 10bps) are declared at the top of the file. `alpha*` is found via bisection on the convergence condition `|f(0,CP) − UFR_c| ≤ 1 bp`. The system matrix H is dense and non-symmetric; solved with `solve()` (LAPACK LU).

**PCA (`lezione_pca_mensile.R`):** Uses SVD on *centred* (not scaled) monthly yield-curve changes. Monthly aggregation takes the last observation of each calendar month. Requires `prepare_pca_input.R` to have been run first; will error with a clear message if the xlsx is missing.

**EIOPA downloader (`python/dowload_eiopa.py`):** `START_DATE`/`END_DATE` and `OUTPUT_FILE` are constants near the top. The parser handles two different Excel layouts (old vs new EIOPA format) transparently. The script auto-downloads missing ZIPs from EIOPA's public register; a polite `SLEEP_SEC = 1.5` delay is applied between requests.
