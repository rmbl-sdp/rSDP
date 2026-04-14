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
.SDP_DOMAINS <- c("UG", "UER", "GT", "GMUG")

.SDP_TYPES <- c("Mask", "Topo", "Vegetation", "Hydro",
                "Planning", "Radiation", "Snow", "Climate",
                "Imagery", "Supplemental")

.SDP_RELEASES <- c("Basemaps", "Release1", "Release2", "Release3", "Release4", "Release5")

.SDP_TIMESERIES_TYPES <- c("Single", "Yearly", "Seasonal", "Monthly", "Daily")

## Length (in characters) of a valid SDP Catalog ID (e.g., "R3D009", "BM012").
.SDP_CATALOG_ID_NCHAR <- 6L

## Parse date strings from the catalog CSV. Handles both 4-digit year
## (%m/%d/%Y, e.g. "7/16/2018") and 2-digit year (%m/%d/%y, e.g.
## "7/16/18") formats, since the upstream CSV has used both over time.
## Cannot rely on parse-failure fallback because %m/%d/%Y silently
## accepts 2-digit years (interpreting "01" as year 1 AD), so we
## detect the format by checking the year-part string length.
.parse_sdp_date <- function(x) {
  has_4digit <- grepl("/\\d{4}$", x)
  d <- rep(as.Date(NA), length(x))
  if (any(has_4digit, na.rm = TRUE)) {
    d[has_4digit] <- as.Date(x[has_4digit], format = "%m/%d/%Y")
  }
  if (any(!has_4digit & !is.na(x))) {
    idx <- !has_4digit & !is.na(x)
    d[idx] <- as.Date(x[idx], format = "%m/%d/%y")
  }
  d
}
