#' Create an R object representing an SDP dataset.
#'
#' @param catalog_id character. A single valid catalog number for an SDP dataset. This is in the `CatalogID` field for information returned by `sdp_get_catalog()`.
#' @param url character. A valid URL (e.g. https://path.to.dataset.tif) for the cloud-based dataset. You should specify either `catalog_id` or `url`, but not both. Note that when a URL is provided directly, scale/offset metadata is not applied to the returned raster (since there is no catalog entry to read it from); use `catalog_id` if you need those applied automatically.
#' @param years numeric. For annual time-series data, a numeric vector specifying which years to return. The default `NULL` returns all available years.
#' @param months numeric. For monthly time-series data, a numeric vector specifying which months of data to return. The default `NULL` returns all available months.
#' @param date_start class `Date`. For daily time-series data, the first day of data to return.
#' @param date_end class `Date`. For daily time-series data, the last day of data to return.
#' @param verbose logical. Should the function print status and progress messages?
#' @param download_files logical. Should the function download files to disk? The default `FALSE` creates cloud-based representations of the data without downloading.
#' @param download_path character. Destination path for downloaded files. This can be a relative or absolute path.
#' @param overwrite logical. Should files with the same names as the datasets be overwritten in `download_path`? If `FALSE`, the function will skip downloading files that already exist in the destination.
#' @param ... Other arguments to pass to the `terra::rast()` function.
#'
#' @details Files headers are read from cloud-based datasets using the `terra` package, but the full dataset is not downloaded locally unless `download_files=TRUE`. Instead `terra` uses the web-based file system embedded in GDAL (VSICURL) to access datasets on the cloud. For large datasets and slow network connections, the function might take up to a minute to complete.
#' Specifying local downloads `download_files=TRUE` might be more efficient for multi-layer data, but can take up lots of disk space.
#'
#' @return An R object (class `terra::SpatRaster`) representing the raster dataset.
#' @export
#'
#' @examples
#' ## Lookup catalog number for a dataset.
#' cat <- sdp_get_catalog(domain='UG',type='Vegetation')
#' lc_id <- cat$CatalogID[cat$Product=='Basic Landcover']
#'
#' ## Connect to the dataset without downloading
#' landcover <- sdp_get_raster(lc_id)
#' landcover
#'
sdp_get_raster <- function(catalog_id = NULL, url = NULL,
                           years = NULL, months = NULL,
                           date_start = NULL, date_end = NULL,
                           dates = NULL,
                           verbose = TRUE,
                           download_files = FALSE, download_path = NULL,
                           overwrite = FALSE,
                           bands = NULL, ...) {

  normalized <- .validate_user_args(catalog_id, url, years, months,
                                    date_start, date_end,
                                    download_files, download_path)
  months_pad <- normalized$months_pad

  if (!is.null(catalog_id)) {
    cat <- sdp_get_catalog(deprecated = c(FALSE, TRUE))
    cat_line <- cat[cat$CatalogID == catalog_id, ]
    .validate_args_vs_type(cat_line$TimeSeriesType,
                           years, months, date_start, date_end)
    spec <- .resolve_time_slices(cat_line, years, months_pad,
                                 date_start, date_end, dates,
                                 verbose)

    ## Irregular imagery: load each date as a separate SpatRaster
    ## (varying extents cannot be stacked into a single raster).
    if (isTRUE(spec$is_imagery)) {
      rasters <- lapply(spec$paths, function(p) {
        r <- .load_raster_from_paths(p, download_files, download_path,
                                     overwrite, ...)
        if (!is.null(bands)) r <- r[[bands]]
        .apply_raster_metadata(r, layer_names = NULL,
                               scale_factor = cat_line$DataScaleFactor,
                               offset       = cat_line$DataOffset)
      })
      names(rasters) <- spec$names
      if (verbose) {
        message(sprintf(
          "Returning a list of %d SpatRasters (one per date). Irregular imagery has varying extents and cannot be stacked into a single raster.",
          length(rasters)
        ))
      }
      return(rasters)
    }

    ## Regular products: single stacked SpatRaster.
    raster <- .load_raster_from_paths(spec$paths,
                                      download_files, download_path,
                                      overwrite, ...)
    if (!is.null(bands)) raster <- raster[[bands]]
    return(.apply_raster_metadata(raster, spec$names,
                                  scale_factor = cat_line$DataScaleFactor,
                                  offset       = cat_line$DataOffset))
  }

  ## URL branch. No catalog entry is available, so scale/offset are not
  ## applied to the returned raster. Only single-layer URLs are supported.
  if (!startsWith(url, "https://")) {
    stop("A valid URL must start with 'https://'")
  }
  raster_path <- paste0(.SDP_VSICURL_PREFIX, url)
  raster <- .load_raster_from_paths(raster_path,
                                    download_files, download_path,
                                    overwrite, ...)
  .apply_raster_metadata(raster,
                         layer_names  = gsub(".tif", "", basename(url)),
                         scale_factor = NULL,
                         offset       = NULL)
}

#' Extract SDP raster data at a set of locations.
#'
#' @param raster class `SpatRaster`. A raster dataset (class `terra::SpatRaster`) to extract data from.
#' @param locations A vector dataset (class `terra::SpatVector` or `sf::sf`) containing points, lines, or polygons at which to sample the raster data.
#' @param date_start class `Date`. If the raster dataset is a daily or monthly time-series, the minimum date of extracted data.
#' @param date_end class `Date`. If the raster dataset is a daily or monthly time-series, the maximum date of extracted data.
#' @param years numeric. If the raster dataset is an annual time-series, the years of data requested.
#' @param catalog_id character. Alternative method of specifying which dataset to sample. NOT IMPLEMENTED YET.
#' @param url_template character. Alternative method of specifying whic dataset to sample. NOT IMPLEMENTED YET.
#' @param bind logical. Should the extracted data be bound to the inputs? If not, a dataset is returned with the ID field in common with input data.
#' @param return_type character. Class of the output. If `return_type = 'SpatVector'`, retains geometry (as class `terra::SpatVector`). If `return_type = 'sf'` then also retains geometry as a Simple Features object (class `sf::sf`). If `return_type = 'DataFrame'` returns an ordinary data frame.
#' @param method Method for extracting values ("simple" or "bilinear"). With "simple" values for the cell a point falls in are returned. With "bilinear" the returned values are interpolated from the values of the four nearest raster cells. Ignored if `locations` represent lines or polygons.
#' @param sum_fun character or function. Function to use to summarize raster cells that overlap input features. Ignored if extracting by point. If `NULL`, and locations represent lines or polygons, the function returns all cell values.
#' @param verbose logical. Should the function print messages about the process?
#' @param ... other arguments to pass along to `terra::Extract()`
#'
#' @return a `data.frame` or `SpatVector` with extracted data. Each layer in the raster dataset is a column in the returned data.
#'
#' @export
#'
#' @examples
#'
#' ## Loads a raster.
#' sdp_rast <- sdp_get_raster("R4D004",date_start=as.Date("2021-11-02"),date_end=as.Date("2021-11-03"))
#'
#' ## Sampling locations.
#' location_pts <- data.frame(SiteName=c("Roaring Judy","Gothic","Galena Lake"),
#'                           Lat=c(38.716995,38.958446,39.021644),
#'                           Lon=c(-106.853186,-106.988934,-107.072569))
#' location_sv <- terra::vect(location_pts,geom=c("Lon","Lat"),crs="EPSG:4327")
#'
#' ## Extract data for sampling locations.
#' sdp_extr_sv <- sdp_extract_data(sdp_rast,location_sv,return_spatvector=TRUE)
#' sdp_extr_sv
#'
#' ## Can also return a data frame.
#' sdp_extr_df <- sdp_extract_data(sdp_rast,location_sv,return_spatvector=FALSE)
#' sdp_extr_df
#'
#'
sdp_extract_data <- function(raster,locations, date_start=NULL,
                             date_end=NULL,years=NULL,
                             catalog_id=NULL,url_template=NULL,
                             bind=TRUE, return_type="SpatVector",
                             method="bilinear", sum_fun="mean",
                             verbose=TRUE,...){

   if (is.list(raster) && !inherits(raster, "SpatRaster")) {
     stop("sdp_extract_data() does not yet support lists of SpatRasters. ",
          "For irregular imagery, extract from each element individually:\n",
          "  lapply(raster_list, function(r) sdp_extract_data(r, locations, ...))")
   }

   stopifnot("Raster must be a daily time-series with layer names representing \
             dates if `date_start` or `date_end` are specified"=
             (is.null(date_start) & is.null(date_end)) | all(!is.na(as.Date(names(raster),format="%Y-%m-%d"))))
   stopifnot("Raster must be an annual time-series with layer names representing \
             years if `years` are specified"=
             is.null(years) | all(names(raster) %in% as.character(1900:2100)))
   stopifnot("`return_type` must be one of 'SpatVector','sf', or 'DataFrame'"=(return_type %in% c("SpatVector","sf","DataFrame")))

   if(terra::geomtype(methods::as(locations,'SpatVector')) == "points"){
     sum_fun <- NULL
   }

    raster <- .filter_raster_layers_by_time(raster, years, date_start, date_end, verbose)

    if(inherits(locations, "sf")){
      locations <- terra::vect(locations)
    }

    if(terra::crs(locations) != terra::crs(raster) & verbose==TRUE){
      message(paste("Re-projecting locations to coordinate system of the raster."))
      locations <- terra::project(locations, y=.SDP_CRS)
    }
    if(verbose==TRUE){
      message(paste("Extracting data at", terra::nrow(locations),"locations for",
                  terra::nlyr(raster), "raster layers."))
    }
    extracted <- terra::extract(x=raster, y=locations, bind=FALSE, method=method, fun=sum_fun, ...)
    if(bind==TRUE & is.null(sum_fun) & terra::geomtype(methods::as(locations,'SpatVector')) != "points"){
      warning("Cannot bind outputs to input features when returning all raster values (`sum_fun=NULL`).\n
              Please specify a summary function such as `sum_fun='mean'` to bind inputs to outputs.")
    }else if(bind==TRUE & return_type=="DataFrame"){
      extracted <- as.data.frame(cbind(locations,extracted))
    }else if(bind==TRUE & return_type == "SpatVector"){
      extracted <- cbind(locations,extracted)
    }else if(bind==TRUE & return_type == "sf"){
      extracted <- sf::st_as_sf(cbind(locations,extracted))
    }else if(bind==FALSE & return_type %in% c("SpatVector","sf")){
      warning("Function will always return a data frame if `bind=FALSE`.")
    }
    if(verbose==TRUE){
      message(paste("Extraction complete."))
    }
    return(extracted)
}

