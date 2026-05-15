## code to prepare `SDP_catalog` dataset goes here
SDP_catalog <- read.csv("https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/SDP_product_table_05_15_2026.csv")

## Guardrail: refuse to bake sysdata.rda from a catalog with empty
## Data.URL / Metadata.URL. Empty URLs silently break downstream consumers
## (missing thumbnails, license="proprietary" fallback) instead of failing
## fast — so we fail fast here at build time.
.required_url_fields <- c("Data.URL", "Metadata.URL")
.missing <- unlist(lapply(.required_url_fields, function(f) {
  bad <- which(is.na(SDP_catalog[[f]]) | trimws(SDP_catalog[[f]]) == "")
  if (length(bad) > 0L) {
    sprintf("%s (rows: %s)", f, paste(SDP_catalog$CatalogID[bad], collapse = ", "))
  }
}))
if (length(.missing) > 0L) {
  stop("Catalog is missing required URL fields:\n  ",
       paste(.missing, collapse = "\n  "), call. = FALSE)
}

usethis::use_data(SDP_catalog, overwrite = TRUE, internal = TRUE)
