#' Discover SDP data by downloading catalog information.
#'
#' @param domains The spatial domain of the desired data product.
#' @param types The type of product to return.
#' @param releases Which release (group) of data products to return.
#' @param timeseries_types Some datasets are structured as single datasets (e.g. `Single`), and others are time-series with various periods (e.g.`Monthly`).
#' @param deprecated Should older versions of datasets be returned, or just the latest version?
#' @param return_stac NOT IMPLEMENTED: Should the results be returned as a Spatio-temporal Asset Catalog? Otherwise return and ordinary data frame.
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
sdp_get_catalog <- function(domains=c("UG","UER","GT"),
                            types=c("Mask","Topo","Vegetation","Hydro",
                                    "Planning","Radiation","Snow","Climate",
                                    "Imagery","Supplemental"),
                            releases=c("Basemaps","Release1","Release2",
                                       "Release3","Release4"),
                            timeseries_types=c("Single","Yearly","Seasonal",
                                               "Monthly","Daily"),
                            deprecated=FALSE,return_stac=FALSE){

  sdp_domains <- c("UG","UER","GT")
  sdp_types <- c("Mask","Topo","Vegetation", "Hydro",
                 "Planning","Radiation","Snow","Climate","Imagery","Supplemental")
  sdp_releases <- c("Basemaps","Release1","Release2","Release3","Release4")
  sdp_tstypes <- c("Single","Annual","Seasonal","Monthly","Daily")

  #utils::data("catalog",package="rSDP",envir=environment())
  ##sdp_cat_url <- "https://www.rmbl.org/wp-content/uploads/2021/04/SDP_product_table_4_26_2021.csv"

  stopifnot(all(domains %in% sdp_domains))
  stopifnot(all(types %in% sdp_types))
  stopifnot(all(releases %in% sdp_releases))
  stopifnot(is.logical(deprecated) & length(deprecated==1))
  stopifnot(is.logical(return_stac) & length(return_stac==1))
  stopifnot()

  #catalog <- rSDP:::catalog
  catalog <- get0("SDP_catalog", envir = asNamespace("rSDP"))
  catalog$MinDate <- as.Date(catalog$MinDate,format="%m/%d/%y")
  catalog$MaxDate <- as.Date(catalog$MaxDate,format="%m/%d/%y")
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
  stopifnot(nchar(catalog_id)==6)
  stopifnot(length(catalog_id)==1)

  cat <- sdp_get_catalog(deprecated=c(FALSE,TRUE))
  meta_url <- cat[cat$CatalogID==catalog_id,]$Metadata.URL

  metadata_xml <- xml2::read_xml(meta_url)

  if(return_list){
    metadata_list <- xml2::as_list(metadata_xml)
    return(metadata_list)
  }else{
    return(metadata_xml)
  }
}
