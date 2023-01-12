
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rSDP

<!-- badges: start -->
<!-- badges: end -->

The rSDP package provides a simple interface for discovering, querying,
and subsetting data products that are incorporated into the RMBL Spatial
Data Platform. The RMBL SDP provides a set of curated, high-resolution,
and high-fidelity geospatial datasets for a set of domains in Western
Colorado (USA) in the vicinity of [Rocky Mountain Biological
Laboratory](https://rmbl.org). For more information about the RMBL SDP
[see
here](https://www.rmbl.org/scientists/resources/spatial-data-platform/).

SDP data products are provided as geospatial raster datasets in
[cloud-optimized Geotiff]() (COG) format. The rSDP package provides
functions to access these datasets in cloud storage (Amazon S3) without
downloading.

## Installation

You can install the development version of rSDP from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("rmbl-sdp/rSDP")
```

## Discovering SDP Data and Metadata

The package provides functions `sdp_get_catalog()`, and
`sdp_get_metadata()` that download information about what datasets are
currently available and what their spatial attributes are.

``` r
library(rSDP)
## Gets entries for vegetation data products in the Upper Gunnison (UG) domain.
sdp_cat <- sdp_get_catalog(domains="UG", 
                           types="Vegetation",
                           deprecated=FALSE,
                           return_stac=FALSE)
sdp_cat[,1:5]
#>    CatalogID  Release       Type                       Product Domain
#> 54    R3D013 Release3 Vegetation              Understory Cover     UG
#> 55    R3D014 Release3 Vegetation       Vegetation Canopy Cover     UG
#> 56    R3D015 Release3 Vegetation      Vegetation Canopy Height     UG
#> 57    R3D016 Release3 Vegetation 20th Percentile Canopy Height     UG
#> 58    R3D017 Release3 Vegetation 80th Percentile Canopy Height     UG
#> 59    R3D018 Release3 Vegetation               Basic Landcover     UG
#> 60    R3D019 Release3 Vegetation        October 2017 NAIP NDVI     UG
#> 61    R3D020 Release3 Vegetation       Septober 2019 NAIP NDVI     UG
#> 73     BM012 Basemaps Vegetation      Canopy Structure Basemap     UG
#> 74     BM013 Basemaps Vegetation             Landcover Basemap     UG
```

``` r
## Grabs detailed metadata for a specific dataset.
item_meta <- sdp_get_metadata(catalog_id="R1D001",return_list=TRUE)

## Prints the detailed description.
item_description <- item_meta$qgis$abstract[[1]]
print(item_description)
#> [1] "This map represents estimated stream flowlines from a hydrologically corrected digital elevation model. The lines were derived in GRASS GIS using a multi-direction algorithm that allows channel braiding. Each stream segment is identified by a unique integer. Stream lines were delineated for drainage areas greater than 512000 square meters.\n"
```

## Accessing SDP data in the cloud.

The function `sdp_get_raster()`, creates R representations of
cloud-based datasets that can be used for further processing, returning
a `SpatRaster` which can be further manipulated using functions in the
`terra` package.

``` r
## Grabs detailed metadata for a specific dataset.
dem <- sdp_get_raster(catalog_id="R3D009")
terra::plot(dem)
```

<img src="man/figures/README-example3-1.png" width="100%" />
