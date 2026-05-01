## Generate baked date manifests for irregular time-series products.
##
## Reads the JSON manifest files produced by stac-gen/lib/s3_manifest.py
## (cached in stac-gen/.cache/manifests/) and converts them to R Date
## vectors stored in SDP_manifests alongside SDP_catalog in sysdata.rda.
##
## Run this after running the STAC build (which populates the manifest
## cache), or as part of scripts/update_catalog.sh.

manifest_dir <- file.path("stac-gen", ".cache", "manifests")
manifest_files <- list.files(manifest_dir, pattern = "\\.json$", full.names = TRUE)

SDP_manifests <- list()
for (f in manifest_files) {
  cat_id <- tools::file_path_sans_ext(basename(f))
  entries <- jsonlite::fromJSON(f)
  if (length(entries) > 0 && "start" %in% names(entries)) {
    SDP_manifests[[cat_id]] <- sort(as.Date(entries$start))
  }
}

cat("Loaded manifests for", length(SDP_manifests), "irregular products:\n")
for (nm in names(SDP_manifests)) {
  cat("  ", nm, ":", length(SDP_manifests[[nm]]), "dates\n")
}

## Save both catalog and manifests to sysdata.rda.
## Load the existing catalog from the current sysdata.rda to preserve it.
load("R/sysdata.rda")
usethis::use_data(SDP_catalog, SDP_manifests, overwrite = TRUE, internal = TRUE)
