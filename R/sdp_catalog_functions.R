#' Discover SDP data by downloading catalog information.
#'
#' @param domains The spatial domain of the desired data product.
#' @param types The type of product to return.
#' @param releases Which release (group) of data products to return.
#' @param timeseries_types Some datasets are structured as single datasets (e.g. `Single`), and others are time-series with various periods (e.g.`Monthly`).
#' @param deprecated Should older versions of datasets be returned, or just the latest version?
#' @param return_stac Logical. If `TRUE`, returns the root of the RMBL SDP's static STAC catalog as an `rstac` object (requires the `rstac` package). The returned catalog is browseable via `rstac` traversal methods but does not support `rstac::stac_search()` (which requires a STAC API server). You can browse the catalog interactively at `https://radiantearth.github.io/stac-browser/#/external/rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1/catalog.json`. When `return_stac=TRUE`, filter arguments (`domains`, `types`, etc.) are ignored; use `rstac` methods to filter the returned catalog. Default `FALSE` returns an ordinary data frame.
#'
#' @return
#' A data frame containing basic catalog information for the matched data products.
#'
#' @export
#'
#' @examples
#'
#' ## Gets information on all current datasets.
#' sdp_cat <- sdp_get_catalog()
#' str(sdp_cat)
#'
#' ## Gets a subset of catalog entries for the Upper Gunnison (UG) domain.
#' sdp_sub <- sdp_get_catalog(domains="UG", types="Vegetation",
#'                           deprecated=FALSE,return_stac=FALSE)
#' sdp_sub
#'
sdp_get_catalog <- function(domains=.SDP_DOMAINS,
                            types=.SDP_TYPES,
                            releases=.SDP_RELEASES,
                            timeseries_types=.SDP_TIMESERIES_TYPES,
                            deprecated=FALSE,return_stac=FALSE){

  #utils::data("catalog",package="rSDP",envir=environment())
  ##sdp_cat_url <- "https://www.rmbl.org/wp-content/uploads/2021/04/SDP_product_table_4_26_2021.csv"

  stopifnot(all(domains %in% .SDP_DOMAINS))
  stopifnot(all(types %in% .SDP_TYPES))
  stopifnot(all(releases %in% .SDP_RELEASES))
  stopifnot(all(timeseries_types %in% .SDP_TIMESERIES_TYPES))
  stopifnot(is.logical(deprecated))
  stopifnot(is.logical(return_stac) && length(return_stac) == 1)

  if (isTRUE(return_stac)) {
    rlang::check_installed("rstac", reason = "to return a STAC catalog object")
    if (!is.null(domains) && !identical(domains, .SDP_DOMAINS) ||
        !is.null(types) && !identical(types, .SDP_TYPES)) {
      message("Filter arguments are ignored when return_stac=TRUE. Use rstac methods to filter the returned catalog.")
    }
    stac_root <- "https://rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1/catalog.json"
    return(rstac::read_stac(stac_root))
  }

  #catalog <- rSDP:::catalog
  catalog <- get0("SDP_catalog", envir = asNamespace("rSDP"))
  catalog$MinDate <- as.Date(catalog$MinDate,format="%m/%d/%Y")
  catalog$MaxDate <- as.Date(catalog$MaxDate,format="%m/%d/%Y")
  cat_filt <- catalog[catalog$Domain %in% domains & catalog$Type %in% types &
                  catalog$Release %in% releases & catalog$Deprecated %in% deprecated &
                  catalog$TimeSeriesType %in% timeseries_types,]
  return(cat_filt)
}

#' Download detailed geospatial metadata for SDP Datasets.
#'
#' @param catalog_id The unique Catalog ID code for the desired dataset.
#' @param return_list Logical. If `TRUE`, then the output is parsed as an R list object.
#'
#' @return
#' A nested list (`return_list=TRUE`) or XML document (`return_list=FALSE`) containing detailed geospatial metadata for each dataset.
#'
#' @export
#'
#' @examples
#'
#' ##Get metadata for a specific item.
#' sdp_get_metadata(catalog_id="R1D001",return_list=TRUE)
#'
#'
sdp_get_metadata <- function(catalog_id,return_list=TRUE){
  stopifnot(nchar(catalog_id) == .SDP_CATALOG_ID_NCHAR)
  stopifnot(length(catalog_id)==1)

  cat <- sdp_get_catalog(deprecated=c(FALSE,TRUE))
  meta_url <- cat[cat$CatalogID==catalog_id,]$Metadata.URL

  metadata_xml <- xml2::read_xml(meta_url,timeout=200)

  if(return_list){
    metadata_list <- xml2::as_list(metadata_xml)
    return(metadata_list)
  }else{
    return(metadata_xml)
  }
}
