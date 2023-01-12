#' Create an R object representing an SDP cloud-based dataset.
#'
#' @param catalog_id A valid catalog number for an SDP dataset. This is in the `CatalogID` field for information returned by `sdp_get_catalog()`.
#' @param url A valid URL (e.g. https://path.to.dataset.tif) for the cloud-based dataset. You should specify either `catalog_id` or `url`, but not both.
#' @param years For time-series data, a numeric vector specifying which years to return. The default `NULL` returns all available years.
#' @param ... Other arguments to pass to the `terra::rast()` function.
#'
#' @details Files headers are read from cloud-based datasets using the `terra` package, but the full dataset is not downloaded locally. Instead `terra` uses the web-based file system embedded in GDAL (VSICURL) to access datasets on the cloud. For large datasets and slow network connections, the function might take up to a minute to complete.
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
sdp_get_raster <- function(catalog_id=NULL,url=NULL,years=NULL,...){

  stopifnot(is.null(catalog_id) | is.null(url))
  stopifnot(class(catalog_id) == "character" | class(url) == "character")
  stopifnot(length(catalog_id) %in% c(0,1) & length(url) %in% c(0,1))
  stopifnot(length(c(catalog_id,url)) == 1)

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
      print(paste("Returning dataset with",length(years_cat),"layers be patient..."))
      raster <- terra::rast(raster_path,...)
      names(raster) <- years_cat
      return(raster)

    }else if(is.null(years) & cat_line$TimeSeriesType=="Yearly"){
      cat_years <- cat_line$MinYear:cat_line$MaxYear
      raster_path <- unlist(lapply(cat_years, FUN=function(x) {gsub("{year}",x,raster_path,fixed=TRUE)}))
      print(paste("Returning dataset with",length(cat_years),"layers, be patient..."))
      raster <- terra::rast(raster_path,...)
      names(raster) <- cat_years
      return(raster)
    }else if(cat_line$TimeSeriesType=="Single"){
      raster <- terra::rast(raster_path,...)
      return(raster)
    }
  }else if(class(url)=="character"){
    url_start <- substr(url,1,8)
    if(url_start=="https://"){
      raster_path <- paste0("/vsicurl/",url)
      raster <- terra::rast(raster_path,...)
      return(raster)
    }else{
      errorCondition("A valid URL must start with 'https://'")
    }
  }else{
    errorCondition("You must specify either a dataset catalog ID, or a URL.")
  }

}
sdp_extract_timeseries <- function(catalog_id,url_template){

}

