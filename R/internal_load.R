## Internal helpers for loading SpatRasters from resolved paths and
## applying shared post-load metadata (names, CRS, scale/offset). Pulls
## the duplicated cloud-vs-local load logic out of both the catalog and
## URL branches of the old sdp_get_raster() body. None exported.

## Load a SpatRaster from a character vector of /vsicurl/-prefixed paths.
## When download_files=TRUE, strips the prefix, downloads each file via
## download_data(), confirms success, and loads from the local copies.
.load_raster_from_paths <- function(paths, download_files, download_path,
                                    overwrite, ...) {
  if (!download_files) {
    return(terra::rast(paths, ...))
  }
  local_paths <- gsub(.SDP_VSICURL_PREFIX, "", paths)
  dl_results <- rSDP::download_data(local_paths,
                                    output_dir = download_path,
                                    overwrite = overwrite)
  ok <- dl_results$success == TRUE & dl_results$status_code %in% c(200, 206)
  if (!all(ok)) {
    failed <- if ("path" %in% names(dl_results)) dl_results$path[!ok] else local_paths[!ok]
    stop(sprintf("Unable to download %d dataset(s):\n  %s",
                 sum(!ok), paste(failed, collapse = "\n  ")))
  }
  message("Loading raster from local paths.")
  terra::rast(paste0(file.path(normalizePath(download_path)), "/",
                     basename(local_paths)), ...)
}

## Apply the common post-load metadata to a SpatRaster: layer names,
## CRS (always .SDP_CRS), and scale/offset if provided. scale_factor and
## offset are both NULL for the URL branch (no catalog entry) — in that
## case the scoff<- call is skipped entirely. This is the NULL-safe
## behavior the URL branch was supposed to have but didn't (it
## referenced an undefined `cat_line`, fixed in an earlier commit).
.apply_raster_metadata <- function(raster, layer_names,
                                   scale_factor = NULL, offset = NULL) {
  names(raster) <- layer_names
  terra::crs(raster) <- .SDP_CRS
  if (!is.null(scale_factor) && !is.null(offset)) {
    terra::scoff(raster) <- cbind(1 / scale_factor, offset)
  }
  raster
}
