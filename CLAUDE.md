# rSDP

R package providing a simplified interface for discovering, querying, and subsetting raster data products from the **RMBL Spatial Data Platform** (Rocky Mountain Biological Laboratory). Datasets are cloud-optimized GeoTIFFs hosted on Amazon S3 (`rmbl-sdp.s3.us-east-2.amazonaws.com`) and accessed via GDAL's `/vsicurl/` without download by default.

## Layout

- `R/sdp_catalog_functions.R` — `sdp_get_catalog()`, `sdp_get_metadata()` (catalog filtering + XML metadata fetch)
- `R/sdp_extraction_functions.R` — `sdp_get_raster()`, `sdp_extract_data()` (the heavy lifting; ~360 lines, lots of branching by `TimeSeriesType`)
- `R/sdp_utility_functions.R` — `download_data()` (curl::multi_download wrapper), `replace_strngs()` (internal)
- `R/sysdata.rda` — internal `SDP_catalog` data frame, baked in via `data-raw/SDP_catalog.R`
- `tests/testthat/` — testthat 3rd edition; **tests hit the live S3 catalog & rasters** (no mocking)
- `vignettes/` — `sdp-cloud-data.Rmd`, `wrangle-raster-data.Rmd`, `field-site-sampling.Rmd`, `pretty-maps.Rmd`
- `data-raw/SDP_catalog.R` — regenerates `sysdata.rda` from the canonical CSV on S3
- `README.Rmd` → `README.md` (do not edit `README.md` directly)
- `_pkgdown.yml` + `.github/workflows/pkgdown.yaml` — pkgdown site auto-deploys on push to `main`

## Conventions

- Roxygen2 for all docs (`RoxygenNote: 7.1.2` in DESCRIPTION — likely worth bumping during refactor)
- Exports are managed via roxygen `@export`; do **not** hand-edit `NAMESPACE`
- All exported functions live in the `sdp_*` namespace
- CRS for all SDP rasters is `EPSG:32613` (UTM 13N); the package hard-codes this
- Catalog IDs are 6-character codes like `R3D009`, `R4D004`, `BM012` (Release/Basemap + type + number)
- `TimeSeriesType` ∈ {`Single`, `Yearly`, `Monthly`, `Daily`} drives most branching in `sdp_get_raster()`
- URL templates in the catalog use `{year}`, `{month}`, `{day}` placeholders that get substituted

## Common commands

Run from the package root in R:

```r
devtools::document()           # regenerate man/ + NAMESPACE from roxygen
devtools::test()               # run testthat suite (REQUIRES NETWORK — hits S3)
devtools::check()              # full R CMD check
devtools::install()            # install locally
pkgdown::build_site()          # preview docs site

# Regenerate the bundled catalog from the S3 CSV (after any catalog change):
source("data-raw/SDP_catalog.R")

# Regenerate the README:
devtools::build_readme()       # or rmarkdown::render("README.Rmd")
```

## Things to be careful about

- **Live tests**: `tests/testthat/test-*.R` make real HTTP requests to S3. A failing test could mean a code bug *or* a moved/renamed dataset in the catalog. Investigate before "fixing."
- **Catalog drift**: `R/sysdata.rda` is a frozen snapshot. The canonical source is the CSV referenced in `data-raw/SDP_catalog.R` (currently `SDP_product_table_04_11_2023.csv`). Refactors that touch catalog logic should re-run `data-raw/SDP_catalog.R` to pick up the latest schema.
- **Date parsing inconsistency**: `sdp_get_catalog()` parses `MinDate`/`MaxDate` with `"%m/%d/%Y"`, but the daily-timeseries branch in `sdp_get_raster()` re-parses with `"%m/%d/%y"` (line ~153). This is a known smell worth resolving during refactor.
- **`class(x) == "..."` checks**: Used throughout (e.g. `class(catalog_id) == "character"`). These break for objects with multi-element class vectors and have been the recommended-against style since R 4.0. Good refactor target — prefer `inherits()` or `is.character()`.
- **Repeated branching in `sdp_get_raster()`**: Six near-duplicate branches handle the year/month/date combinations for Yearly/Monthly/Daily series. Strong DRY candidate but tread carefully — the branches have subtle differences.
- **Don't edit `NAMESPACE` or `man/*.Rd` by hand** — they're generated.
- **Don't edit `README.md` directly** — edit `README.Rmd` and rebuild.
