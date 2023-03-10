#' Create an R object representing an SDP dataset.
#'
#' @param catalog_id character. A single valid catalog number for an SDP dataset. This is in the `CatalogID` field for information returned by `sdp_get_catalog()`.
#' @param url character. A valid URL (e.g. https://path.to.dataset.tif) for the cloud-based dataset. You should specify either `catalog_id` or `url`, but not both.
#' @param years numeric. For annual time-series data, a numeric vector specifying which years to return. The default `NULL` returns all available years.
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
sdp_get_raster <- function(catalog_id=NULL,url=NULL,years=NULL,
                           date_start=NULL,date_end=NULL, verbose=TRUE,
                           download_files=FALSE,download_path=NULL,overwrite=FALSE,...){

  stopifnot("Please specify either catalog_id or url, not both."=is.null(catalog_id) | is.null(url))
  stopifnot(class(catalog_id) == "character" | class(url) == "character")
  stopifnot("Please specify a single Catalog ID or URL."=length(catalog_id) %in% c(0,1) & length(url) %in% c(0,1))
  stopifnot("Please specify a single Catalog ID or URL."=length(c(catalog_id,url)) == 1)
  stopifnot("Date ranges must be class `Date` if specified."=(is.null(date_start) & is.null(date_end)) | (class(date_start)=="Date" & class(date_end)=="Date"))
  stopifnot("You must specify `download_path` if `download_files=TRUE`"=(download_files==FALSE & is.null(download_path)) | (download_files==TRUE & class(download_path)=="character"))

  if(class(catalog_id)=="character"){
    cat <- sdp_get_catalog(deprecated=c(FALSE,TRUE))
    cat_line <- cat[cat$CatalogID==catalog_id,]
    cat_url <- cat_line$Data.URL
    raster_path <- paste0("/vsicurl/",cat_url)

    if(!is.null(years) & cat_line$TimeSeriesType=="Yearly"){
      cat_url <- cat_line$Data.URL
      cat_years <- cat_line$MinYear:cat_line$MaxYear
      years_cat <- years[years %in% cat_years]

      if(length(years_cat)==0){
        stop(paste("No dataset available for any specified years. Available years are",
                   paste(cat_years,collapse=" ")))
      }else if((length(years_cat) < length(years)) & length(years_cat) > 0){
        warning(paste("No dataset available for some specified years. \n Returning data for",years_cat))
      }
      raster_path <- unlist(lapply(years_cat, FUN=function(x) {gsub("{year}",x,raster_path,fixed=TRUE)}))
      if(verbose==TRUE){
        print(paste("Returning dataset with",length(years_cat),"layers be patient..."))
      }
      if(download_files==FALSE){
        raster <- terra::rast(raster_path,...)
      }else if(download_files==TRUE){
        raster_path <- gsub("/vsicurl/","",raster_path)
        dl_results <- rSDP::download_data(raster_path,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      names(raster) <- years_cat
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)

    }else if(is.null(years) & cat_line$TimeSeriesType=="Yearly"){
      cat_years <- cat_line$MinYear:cat_line$MaxYear
      raster_path <- unlist(lapply(cat_years, FUN=function(x) {gsub("{year}",x,raster_path,fixed=TRUE)}))
      if(verbose==TRUE){
        print(paste("Returning dataset with",length(cat_years),"layers, be patient..."))
      }
      if(download_files==FALSE){
        raster <- terra::rast(raster_path,...)
      }else if(download_files==TRUE){
        raster_path <- gsub("/vsicurl/","",raster_path)
        dl_results <- rSDP::download_data(raster_path,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      names(raster) <- cat_years
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)
    }else if(!is.null(date_start) & !is.null(date_end) & cat_line$TimeSeriesType=="Daily"){
      cat_days <- seq(as.Date(cat_line$MinDate,format="%m/%d/%y"),as.Date(cat_line$MaxDate,format="%m/%d/%y"),by="day")
      days_input <- seq(date_start,date_end,by="day")
      days_overlap <- days_input[days_input %in% cat_days]
      if(length(days_overlap)==0){
        stop(paste("No data available for any requested days. Available days are", min(cat_days),"to",max(cat_days)))
      }else if((length(days_overlap) < length(days_input)) & length(days_overlap) > 0){
        warning(paste("No data available for some requested days. \n Returning data for",min(days_overlap),"to",max(days_overlap)))
      }
      years_overlap <- format(days_overlap,format="%Y")
      doys_overlap <- format(days_overlap,format="%j")
      days_df <- data.frame(raster_path,years_overlap,doys_overlap)
      repl_fun <- function(x){
        rep1 <- gsub("{year}",x[2],x[1],fixed=TRUE)
        rep2 <- gsub("{day}",x[3],rep1,fixed=TRUE)
        return(rep2)
        }
      raster_path_day <- apply(days_df,MARGIN=1,FUN=repl_fun)
      if(verbose==TRUE){
        print(paste("Returning dataset with",length(days_overlap),"layers, be patient..."))
      }
      if(download_files==FALSE){
        raster <- terra::rast(raster_path_day,...)
      }else if(download_files==TRUE){
        raster_path_day <- gsub("/vsicurl/","",raster_path_day)
        dl_results <- rSDP::download_data(raster_path_day,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path_day)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      names(raster) <- as.character(days_overlap)
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)
    }else if(is.null(date_start) & is.null(date_end) & cat_line$TimeSeriesType=="Daily"){
      cat_days <- seq(as.Date(cat_line$MinDate,format="%m/%d/%y"),
                      as.Date(cat_line$MaxDate,format="%m/%d/%y"),by="day")[1:30]
      years_overlap <- format(cat_days,format="%Y")
      doys_overlap <- format(cat_days,format="%j")
      days_df <- data.frame(raster_path,years_overlap,doys_overlap)
      repl_fun <- function(x){
        rep1 <- gsub("{year}",x[2],x[1],fixed=TRUE)
        rep2 <- gsub("{day}",x[3],rep1,fixed=TRUE)
        return(rep2)
      }
      raster_path_day <- apply(days_df,MARGIN=1,FUN=repl_fun)
      if(verbose==TRUE){
        print(paste("No time bounds set for daily data, returning the first 30 layers. Specify StartDate or EndDate to retrieve larger daily time-series..."))
      }
      if(download_files==FALSE){
        raster <- terra::rast(raster_path_day,...)
      }else if(download_files==TRUE){
        raster_path_day <- gsub("/vsicurl/","",raster_path_day)
        dl_results <- rSDP::download_data(raster_path_day,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path_day)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      names(raster) <- as.character(cat_days)
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)
    }else if(cat_line$TimeSeriesType=="Single"){
      if(download_files==FALSE){
        raster <- terra::rast(raster_path,...)
      }else if(download_files==TRUE){
        raster_path <- gsub("/vsicurl/","",raster_path)
        dl_results <- rSDP::download_data(raster_path,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)
    }
  }else if(class(url)=="character"){
    url_start <- substr(url,1,8)
    if(url_start=="https://"){
      raster_path <- paste0("/vsicurl/",url)
      if(download_files==FALSE){
        raster <- terra::rast(raster_path,...)
      }else if(download_files==TRUE){
        raster_path <- gsub("/vsicurl/","",raster_path)
        dl_results <- rSDP::download_data(raster_path,
                                          output_dir=download_path,
                                          overwrite=overwrite)
        if(all(dl_results$success==TRUE & dl_results$status_code %in% c(200,206))){
          print("Loading raster from local paths.")
          raster <- terra::rast(paste0(file.path(normalizePath(download_path)),"/",basename(raster_path)),...)
        }else{
          stop("Unable to download datasets locally.")
        }
      }
      terra::crs(raster) <- "EPSG:32613"
      terra::scoff(raster) <- cbind(1/cat_line$DataScaleFactor,cat_line$DataOffset)
      return(raster)
    }else{
      errorCondition("A valid URL must start with 'https://'")
    }
  }else{
    errorCondition("You must specify either a dataset catalog ID, or a URL.")
  }

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
#' @param bind logical. Should the extracted data be bound to the inputs? If not, a data frame is returned with the ID field in common with input data.
#' @param return_spatvector logical. Should the returned dataset be a vector dataset with retained geometry (class `terra::SpatVector`). If `FALSE` returns an ordinary data frame.
#' @param method Method for extracting values ("simple" or "bilinear"). With "simple" values for the cell a point falls in are returned. With "bilinear" the returned values are interpolated from the values of the four nearest raster cells. Ignored if `locations` represent lines or points.
#' @param sum_fun character or function. Function to use to summarize raster cells that overlap input features. Ignored if extracting by point.
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
#' sdp_extr_df <- sdp_extract_data(sdp_rast,location_sv,return_spatvector=TRUE)
#' sdp_extr_df
sdp_extract_data <- function(raster,locations, date_start=NULL,
                             date_end=NULL,years=NULL,
                             catalog_id=NULL,url_template=NULL,
                             bind=TRUE, return_spatvector=TRUE,
                             method="bilinear", sum_fun="mean",
                             verbose=TRUE,...){

   stopifnot("Raster must be a daily time-series with layer names representing \
             dates if `date_start` or `date_end` are specified"=
             (is.null(date_start) & is.null(date_end)) | all(!is.na(as.Date(names(raster),format="%Y-%m-%d"))))
   stopifnot("Raster must be an annual time-series with layer names representing \
             years if `years` are specified"=
             is.null(years) | all(names(raster) %in% as.character(1900:2100)))

   if(terra::geomtype(locations) == "points"){
     sum_fun <- NULL
   }

    if(!is.null(years)){
      years_overlap <- years[years %in% as.numeric(names(raster))]
      if(length(years_overlap)==0){
        stop(paste("No raster layers match any specified years. Available years are",
                   paste(names(raster),collapse=" ")))
      }else if((length(years_overlap) < length(years)) & length(years_overlap) > 0 & verbose==TRUE){
        warning(paste("No layer matches some specified years. \n Returning data for",
                      paste(years_overlap,collapse=" ")))
      }
      raster <- raster[[as.character(years_overlap)]]
    }else if(!is.null(date_start) & !is.null(date_end)){
      day_seq <- seq(date_start,date_end,by="day")
      rast_days <- as.Date(names(raster))
      days_overlap <- day_seq[day_seq %in% rast_days]
      if(length(days_overlap)==0){
        stop(paste("No raster layers match any specified dates. Available dates are",
                   paste(names(raster),collapse=" ")))
      }else if(length(days_overlap) < length(day_seq) & length(days_overlap) > 0 & verbose==TRUE){
        warning(paste("No layer matches some specified days. \n Returning data for",paste(days_overlap,collapse=" ")))
      }
      raster <- raster[[as.character(days_overlap)]]
    }

    if('sf' %in% class(locations)){
      locations <- terra::vect(locations)
    }

    if(terra::crs(locations) != terra::crs(raster) & verbose==TRUE){
      print(paste("Re-projecting locations to coordinate system of the raster."))
      locations <- terra::project(locations, y="EPSG:32613")
    }
    if(verbose==TRUE){
      print(paste("Extracting data at", terra::nrow(locations),"locations for",
                  terra::nlyr(raster), "raster layers."))
    }
    extracted <- terra::extract(x=raster, y=locations, bind=FALSE, method=method, fun=sum_fun, ...)
    if(bind==TRUE & is.null(sum_fun) & terra::geomtype(locations) != "points"){
      warning("Cannot bind outputs to input features when returning all raster values (`sum_fun=NULL`).\n
              Please specify a summary function such as `sum_fun='mean'` to bind inputs to outputs.")
    }else if(bind==TRUE & return_spatvector==FALSE){
      extracted <- as.data.frame(cbind(locations,extracted))
    }else if(bind==TRUE & return_spatvector==TRUE){
      extracted <- cbind(locations,extracted)
    }else if(bind==FALSE & return_spatvector==TRUE){
      warning("Function will always return a data frame if `bind=FALSE`.")
    }
    if(verbose==TRUE){
      print(paste("Extraction complete."))
    }
    return(extracted)
}

