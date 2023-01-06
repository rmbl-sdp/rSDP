
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rSDP

<!-- badges: start -->
<!-- badges: end -->

The rSDP package provides a simplified interface for discovering,
querying, and subsetting data products that are incorporated into the
RMBL Spatial Data Platform. The RMBL SDP provides a set of curated,
high-resolution, and high-fidelity geospatial datasets for a set of
domains in Western Colorado (USA) in the vicinity of [Rocky Mountain
Biological Laboratory](https://rmbl.org). For more information about the
RMBL SDP [see
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

## Discovering Data

The package provides functions `get_sdp_catalog()`, and
`get_sdp_template()` that download information about what datasets are
currently available and what their spatial attributes are.

``` r
library(rSDP)
## Gets entries for vegetation data products in the Upper Gunnison (UG) domain.
sdp_cat <- get_sdp_catalog(domains="UG", 
                           types="Vegetation",
                           deprecated=FALSE,
                           return_stac=FALSE)
sdp_cat[,1:5]
#>     Release       Type                       Product Domain Resolution
#> 54 Release3 Vegetation              Understory Cover     UG         3m
#> 55 Release3 Vegetation       Vegetation Canopy Cover     UG         3m
#> 56 Release3 Vegetation      Vegetation Canopy Height     UG         1m
#> 57 Release3 Vegetation 20th Percentile Canopy Height     UG         3m
#> 58 Release3 Vegetation 80th Percentile Canopy Height     UG         3m
#> 59 Release3 Vegetation               Basic Landcover     UG         1m
#> 60 Release3 Vegetation        October 2017 NAIP NDVI     UG         1m
#> 61 Release3 Vegetation       Septober 2019 NAIP NDVI     UG         1m
#> 73 Basemaps Vegetation      Canopy Structure Basemap     UG         2m
#> 74 Basemaps Vegetation             Landcover Basemap     UG         2m
```
