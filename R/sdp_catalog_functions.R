#' Discover SDP data by downloading catalog information.
#'
#' @param domains The spatial domain of the desired data product.
#' @param types The type of product to return.
#' @param releases Which release (group) of data products to return.
#' @param deprecated Should older versions of datasets be returned, or just the latest version?
#' @param return_stac NOT IMPLEMENTED: Should the results be returned as a Spatio-temporal Asset Catalog? Otherwise return and ordinary data frame.
#'
#' @return
#' @export
#'
#' @examples
#'
#' ## Gets information on all current datasets.
#' sdp_cat <- get_sdp_catalog()
#' str(sdp_cat)
#'
#' ## Gets a subset of catalog entries for the Upper Gunnison (UG) domain.
#' sdp_sub <- get_sdp_catalog(domains="UG", types="Vegetation",
#'                           deprecated=FALSE,return_stac=FALSE)
#' sdp_sub
#'
get_sdp_catalog <- function(domains=c("UG","UER","GT"),
                            types=c("Mask","Topo","Vegetation",
                                    "Planning","Radiation","Snow",
                                    "Imagery","Supplemental"),
                            releases=c("Basemaps","Release1","Release2","Release3"),
                            deprecated=FALSE,return_stac=FALSE){

  sdp_domains <- c("UG","UER","GT")
  sdp_types <- c("Mask","Topo","Vegetation",
                 "Planning","Radiation","Snow","Imagery","Supplemental")
  sdp_releases <- c("Basemaps","Release1","Release2","Release3")

  stopifnot(all(domains %in% sdp_domains))
  stopifnot(all(types %in% sdp_types))
  stopifnot(all(releases %in% sdp_releases))

  cat <- utils::read.csv("https://www.rmbl.org/wp-content/uploads/2021/04/SDP_product_table_4_26_2021.csv")
  cat_filt <- cat[cat$Domain %in% domains & cat$Type %in% types & cat$Release %in% releases,]
  return(cat_filt)
}
