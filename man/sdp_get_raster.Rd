% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sdp_extraction_functions.R
\name{sdp_get_raster}
\alias{sdp_get_raster}
\title{Create an R object representing an SDP dataset.}
\usage{
sdp_get_raster(
  catalog_id = NULL,
  url = NULL,
  years = NULL,
  months = NULL,
  date_start = NULL,
  date_end = NULL,
  verbose = TRUE,
  download_files = FALSE,
  download_path = NULL,
  overwrite = FALSE,
  ...
)
}
\arguments{
\item{catalog_id}{character. A single valid catalog number for an SDP dataset. This is in the \code{CatalogID} field for information returned by \code{sdp_get_catalog()}.}

\item{url}{character. A valid URL (e.g. https://path.to.dataset.tif) for the cloud-based dataset. You should specify either \code{catalog_id} or \code{url}, but not both.}

\item{years}{numeric. For annual time-series data, a numeric vector specifying which years to return. The default \code{NULL} returns all available years.}

\item{months}{numeric. For monthly time-series data, a numeric vector specifying which months of data to return. The default \code{NULL} returns all available months.}

\item{date_start}{class \code{Date}. For daily time-series data, the first day of data to return.}

\item{date_end}{class \code{Date}. For daily time-series data, the last day of data to return.}

\item{verbose}{logical. Should the function print status and progress messages?}

\item{download_files}{logical. Should the function download files to disk? The default \code{FALSE} creates cloud-based representations of the data without downloading.}

\item{download_path}{character. Destination path for downloaded files. This can be a relative or absolute path.}

\item{overwrite}{logical. Should files with the same names as the datasets be overwritten in \code{download_path}? If \code{FALSE}, the function will skip downloading files that already exist in the destination.}

\item{...}{Other arguments to pass to the \code{terra::rast()} function.}
}
\value{
An R object (class \code{terra::SpatRaster}) representing the raster dataset.
}
\description{
Create an R object representing an SDP dataset.
}
\details{
Files headers are read from cloud-based datasets using the \code{terra} package, but the full dataset is not downloaded locally unless \code{download_files=TRUE}. Instead \code{terra} uses the web-based file system embedded in GDAL (VSICURL) to access datasets on the cloud. For large datasets and slow network connections, the function might take up to a minute to complete.
Specifying local downloads \code{download_files=TRUE} might be more efficient for multi-layer data, but can take up lots of disk space.
}
\examples{
## Lookup catalog number for a dataset.
cat <- sdp_get_catalog(domain='UG',type='Vegetation')
lc_id <- cat$CatalogID[cat$Product=='Basic Landcover']

## Connect to the dataset without downloading
landcover <- sdp_get_raster(lc_id)
landcover

}
