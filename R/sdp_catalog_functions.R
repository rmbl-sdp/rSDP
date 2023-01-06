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

  cat <- read.csv("https://www.rmbl.org/wp-content/uploads/2021/04/SDP_product_table_4_26_2021.csv")
  cat_filt <- dplyr::filter(cat,Domain %in% domains & Type %in% types & Release %in% releases)
  return(cat_filt)
}
