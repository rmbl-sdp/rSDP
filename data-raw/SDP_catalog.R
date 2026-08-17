## code to prepare `SDP_catalog` dataset goes here
SDP_catalog <- read.csv("https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/SDP_product_table_08_17_2026.csv")

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

## Guardrail: CatalogIDs must be unique. A fill-down slip in the source
## spreadsheet once published a table with three rows sharing one ID,
## silently shadowing two products and dangling the NewVersionID
## references that pointed at them.
.dup_ids <- unique(SDP_catalog$CatalogID[duplicated(SDP_catalog$CatalogID)])
if (length(.dup_ids) > 0L) {
  stop("Duplicate CatalogIDs in catalog: ", paste(.dup_ids, collapse = ", "),
       call. = FALSE)
}

## Preserve SDP_manifests (baked by data-raw/SDP_manifests.R) — use_data()
## rewrites sysdata.rda with only the objects listed, so saving SDP_catalog
## alone would silently drop the manifests and break offline Weekly-date
## resolution (.resolve_weekly, sdp_get_dates(source = "manifest")).
.prev <- new.env()
if (file.exists("R/sysdata.rda")) load("R/sysdata.rda", envir = .prev)
if (exists("SDP_manifests", envir = .prev, inherits = FALSE)) {
  SDP_manifests <- get("SDP_manifests", envir = .prev)
  usethis::use_data(SDP_catalog, SDP_manifests, overwrite = TRUE, internal = TRUE)
} else {
  warning("SDP_manifests not found in existing sysdata.rda; saving catalog only. ",
          "Run data-raw/SDP_manifests.R after the STAC build to restore manifests.")
  usethis::use_data(SDP_catalog, overwrite = TRUE, internal = TRUE)
}
