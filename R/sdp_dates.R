#' Discover available dates for an SDP time-series product.
#'
#' Returns a sorted vector of dates for which data is available. For
#' regular products (Yearly, Monthly, Daily), dates are computed from the
#' catalog's MinDate/MaxDate. For irregular products (Weekly drone
#' imagery), dates are discovered from the STAC catalog (online) or a
#' baked manifest (offline).
#'
#' @param catalog_id Character. A valid SDP catalog ID.
#' @param source One of `"auto"` (default), `"stac"`, or `"manifest"`.
#'   `"auto"` tries STAC first, falls back to the manifest.
#'   `"stac"` queries the live STAC catalog (requires network).
#'   `"manifest"` uses only the baked offline manifest.
#'
#' @return A sorted `Date` vector of available dates.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' ## Discover available dates for weekly drone imagery
#' dates <- sdp_get_dates("R6D001")
#' head(dates)
#'
#' ## Works offline with baked manifest
#' dates <- sdp_get_dates("R6D001", source = "manifest")
#'
#' ## Regular products compute from catalog range
#' dates <- sdp_get_dates("R4D001")  # Yearly snow persistence
#' }
sdp_get_dates <- function(catalog_id, source = c("auto", "stac", "manifest")) {
  source <- match.arg(source)
  stopifnot(is.character(catalog_id) && length(catalog_id) == 1L)

  cat <- sdp_get_catalog(deprecated = c(FALSE, TRUE))
  row <- cat[cat$CatalogID == catalog_id, ]
  if (nrow(row) == 0L) {
    stop(sprintf("Catalog ID '%s' not found.", catalog_id))
  }

  ts_type <- row$TimeSeriesType

  ## Regular products: compute deterministically from catalog range.
  if (ts_type %in% c("Yearly", "Monthly", "Daily")) {
    return(.dates_from_catalog(row))
  }
  if (ts_type == "Single") {
    return(row$MinDate)
  }

  ## Irregular products (Weekly): try STAC, fall back to manifest.
  if (source %in% c("auto", "stac")) {
    stac_dates <- tryCatch(.dates_from_stac(catalog_id, row),
                           error = function(e) NULL)
    if (!is.null(stac_dates) && length(stac_dates) > 0L) {
      return(stac_dates)
    }
    if (source == "stac") {
      stop("Failed to retrieve dates from STAC. Check network connectivity.")
    }
  }

  ## Manifest fallback.
  manifests <- get0("SDP_manifests", envir = asNamespace("rSDP"))
  if (!is.null(manifests) && catalog_id %in% names(manifests)) {
    return(manifests[[catalog_id]])
  }

  stop(sprintf(
    "No date information available for '%s'. Try source='stac' with network, or regenerate manifests.",
    catalog_id
  ))
}


## Compute dates from MinDate/MaxDate for regular time-series.
.dates_from_catalog <- function(row) {
  ts_type <- row$TimeSeriesType
  if (ts_type == "Yearly") {
    years <- row$MinYear:row$MaxYear
    return(as.Date(paste0(years, "-01-01")))
  }
  if (ts_type == "Monthly") {
    return(seq(row$MinDate, row$MaxDate, by = "month"))
  }
  if (ts_type == "Daily") {
    return(seq(row$MinDate, row$MaxDate, by = "day"))
  }
  stop(sprintf("Unsupported TimeSeriesType: '%s'", ts_type))
}


## Query the STAC catalog for item dates.
.dates_from_stac <- function(catalog_id, row) {
  rlang::check_installed("rstac", reason = "to query STAC for available dates")

  col_url <- .stac_collection_url(row)
  col <- rstac::read_stac(col_url)
  item_links <- Filter(function(l) l$rel == "item", col$links)

  if (length(item_links) == 0L) return(NULL)

  ## Parse dates from item hrefs like ./R6D001_2022-03-01/R6D001_2022-03-01.json
  date_strings <- vapply(item_links, function(l) {
    m <- regmatches(l$href, regexpr("\\d{4}-\\d{2}-\\d{2}", l$href))
    if (length(m) == 1L) m else NA_character_
  }, character(1))

  dates <- as.Date(date_strings[!is.na(date_strings)])
  sort(dates)
}


## Derive the STAC collection URL from catalog info.
.stac_collection_url <- function(row) {
  domain <- tolower(row$Domain)
  slug <- .product_to_slug(row$Product)
  sprintf(
    "https://rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1/rmbl-sdp-%s/%s-%s/collection.json",
    domain, domain, slug
  )
}


## Port of the Python product_to_slug() — lowercase, non-alphanum → hyphens.
.product_to_slug <- function(product_name) {
  slug <- tolower(trimws(product_name))
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  slug
}
