# rSDP 0.4

* New `sdp_get_dates()` function discovers available dates for any time-series product. For regular products (Yearly/Monthly/Daily), dates are computed from the catalog. For irregular products (Weekly drone imagery), dates are queried from the live STAC catalog or a baked offline manifest. Supports `source = "auto"`, `"stac"`, or `"manifest"`.
* `sdp_get_raster()` now supports Weekly/irregular time-series products (R6D001, R6D002). Products with `Type="Imagery"` return a named list of SpatRasters (one per date) since each acquisition has varying spatial extents. Other irregular time-series on consistent grids will stack normally.
* New `dates` parameter for `sdp_get_raster()`: accepts an explicit Date vector for exact date selection.
* New `bands` parameter for `sdp_get_raster()`: select specific bands from multi-band imagery (e.g., `bands = 1:3` for RGB).
* Added `{calendarday}` template placeholder support for weekly URL patterns.
* Baked date manifests for R6D001 (111 dates) and R6D002 (55 dates) stored in package data for offline use.
* Updated catalog to 162 products including Release 6 GT drone imagery.
* `sdp_extract_data()` now provides a helpful error when passed a list of SpatRasters from irregular imagery, directing users to extract per-element via `lapply()`.

# rSDP 0.3

* New `sdp_browse()` function renders a visual thumbnail grid of data products in the RStudio/Positron Viewer pane. Accepts the same filter arguments as `sdp_get_catalog()`. Mirrors the `browse()` feature in the pysdp companion package.
* STAC collections now include thumbnail assets, displayed automatically in STAC Browser.
* Fixed invalid JSON in STAC items: `NaN` nodata values from COG headers are now serialized as `null`.
* Fixed multi-band STAC metadata: RGB/RGBA basemaps now correctly declare one `raster:bands` entry per COG band instead of a single entry.

# rSDP 0.2

* **New GMUG domain**: Added 16 datasets for the Gunnison, Grand Mesa, and Uncompahgre National Forests as Release 5. Includes vegetation canopy structure (cover, height, understory), topographic products (DEM, slope, aspect, hillshade, flow accumulation) at 3m and 9m resolution, and summer/winter solstice solar radiation — all derived from 2015–2021 LiDAR data. Access with `sdp_get_catalog(domains="GMUG")`.
* Updated catalog to 156 products across 4 domains (UG, UER, GT, GMUG).
* Added `scripts/update_catalog.sh` for automated catalog updates across both the R package and STAC pipelines.
* Added STAC (SpatioTemporal Asset Catalog) support. Use `sdp_get_catalog(return_stac=TRUE)` to access the SDP catalog as a static STAC catalog via the `rstac` package. The catalog is browseable at `https://radiantearth.github.io/stac-browser/#/external/rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1/catalog.json`.
* Added `stac-gen/` Python tooling for generating the static STAC catalog from the SDP product table.
* Decomposed `sdp_get_raster()` into small, testable internal helpers (`R/internal_resolve.R`, `R/internal_load.R`, `R/internal_validate.R`). No changes to the exported function interface.
* Fixed two latent bugs in `sdp_get_raster()`: the `url=` branch referenced an undefined variable (`cat_line`) and used `errorCondition()` instead of `stop()`.
* Invalid argument combinations (e.g., `years` with Daily datasets) now produce clear error messages instead of cryptic `terra::rast()` failures.
* Status messages now use `message()` instead of `print()` and can be silenced with `suppressMessages()`.
* Centralized package constants in `R/constants.R`; resolved an inconsistency between "Yearly" and "Annual" in the `timeseries_types` validation.
* Replaced `class(x) == "..."` comparisons with `inherits()` / `is.character()` per R 4.0+ best practice.
* Removed unused `replace_strngs()` function.
* Added 58 unit tests for the new internal helpers (no network required) plus regression-pin tests for `names(raster)` output.

# rSDP 0.1

* Initial public release for beta testing. Feedback welcome! Please add issues you find to the [GitHub Repository](https://github.com/rmbl-sdp/rSDP/issues) for the package. If possible, please include a [reproducible example](https://community.rstudio.com/t/faq-whats-a-reproducible-example-reprex-and-how-do-i-create-one/5219)
* Added a `NEWS.md` file to track changes to the package.
