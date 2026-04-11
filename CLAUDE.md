# rSDP

R package providing a simplified interface for discovering, querying, and subsetting raster data products from the **RMBL Spatial Data Platform** (Rocky Mountain Biological Laboratory). Datasets are cloud-optimized GeoTIFFs hosted on Amazon S3 (`rmbl-sdp.s3.us-east-2.amazonaws.com`) and accessed via GDAL's `/vsicurl/` without download by default.

## Layout

- `R/sdp_catalog_functions.R` — `sdp_get_catalog()`, `sdp_get_metadata()` (catalog filtering, XML metadata fetch, STAC access via `return_stac=TRUE`)
- `R/sdp_extraction_functions.R` — `sdp_get_raster()`, `sdp_extract_data()` (~40-line orchestrators delegating to internal helpers)
- `R/internal_resolve.R` — `.resolve_time_slices()` and per-type resolvers (Yearly/Monthly/Daily/Single), `.filter_raster_layers_by_time()`
- `R/internal_load.R` — `.load_raster_from_paths()`, `.apply_raster_metadata()`
- `R/internal_validate.R` — `.validate_user_args()`, `.validate_args_vs_type()`
- `R/constants.R` — internal `.SDP_*` constants (CRS, VSICURL prefix, valid domains/types/releases/timeseries types)
- `R/sdp_utility_functions.R` — `download_data()` (curl::multi_download wrapper)
- `R/sysdata.rda` — internal `SDP_catalog` data frame, baked in via `data-raw/SDP_catalog.R`
- `stac-gen/` — Python + pystac tooling for generating a static STAC catalog from the SDP product table. See `stac-gen/README.md` for setup and usage. Excluded from R package build via `.Rbuildignore`.
- `tests/testthat/` — testthat 3rd edition; live-S3 integration tests + in-memory unit tests for internal helpers
- `vignettes/` — `sdp-cloud-data.Rmd`, `wrangle-raster-data.Rmd`, `field-site-sampling.Rmd`, `pretty-maps.Rmd`
- `data-raw/SDP_catalog.R` — regenerates `sysdata.rda` from the canonical CSV on S3
- `README.Rmd` → `README.md` (do not edit `README.md` directly)
- `_pkgdown.yml` + `.github/workflows/pkgdown.yaml` — pkgdown site auto-deploys on push to `main`

## Conventions

- Roxygen2 for all docs (`RoxygenNote: 7.1.2` in DESCRIPTION)
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
- **Catalog drift**: `R/sysdata.rda` is a frozen snapshot. The canonical source is the CSV referenced in `data-raw/SDP_catalog.R` (currently `SDP_product_table_04_11_2023.csv`). If the catalog CSV changes, both `data-raw/SDP_catalog.R` (R side) and `stac-gen/build_stac.py` (STAC side) need to be re-run.
- **STAC catalog deployment**: `sdp_get_catalog(return_stac=TRUE)` fetches from `s3://rmbl-sdp/stac/v1/catalog.json`. If the STAC catalog hasn't been synced to S3 yet, this will error. The R test skips gracefully in that case. See `stac-gen/README.md` for deployment steps.
- **Don't edit `NAMESPACE` or `man/*.Rd` by hand** — they're generated.
- **Don't edit `README.md` directly** — edit `README.Rmd` and rebuild.
