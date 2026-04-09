## Internal package constants.
##
## These values are referenced in multiple places across the package. Keeping
## them in one file makes it easier to update them consistently and avoids
## copy/paste drift (e.g., a previous version of the package maintained two
## separate lists of valid TimeSeriesType values that disagreed with each
## other). These are not exported; they live in the package namespace and
## are accessed as `.SDP_*` from other R files in the package.

## Hard-coded CRS for all SDP raster products (UTM zone 13N).
.SDP_CRS <- "EPSG:32613"

## Prefix used by GDAL's virtual file system for HTTPS-hosted datasets.
.SDP_VSICURL_PREFIX <- "/vsicurl/"

## Valid values for the catalog-filter arguments of `sdp_get_catalog()`.
.SDP_DOMAINS <- c("UG", "UER", "GT")

.SDP_TYPES <- c("Mask", "Topo", "Vegetation", "Hydro",
                "Planning", "Radiation", "Snow", "Climate",
                "Imagery", "Supplemental")

.SDP_RELEASES <- c("Basemaps", "Release1", "Release2", "Release3", "Release4")

.SDP_TIMESERIES_TYPES <- c("Single", "Yearly", "Seasonal", "Monthly", "Daily")

## Length (in characters) of a valid SDP Catalog ID (e.g., "R3D009", "BM012").
.SDP_CATALOG_ID_NCHAR <- 6L
