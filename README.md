
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
sdp_cat
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
#>                                                                                                   Data.URL
#> 54 https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_2mcover_3m_v2.tif
#> 55   https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_cover_3m_v3.tif
#> 56  https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_height_1m_v2.tif
#> 57    https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_ht20_3m_v2.tif
#> 58    https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_ht80_3m_v4.tif
#> 59      https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_landcover_1m_v4.tif
#> 60   https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_ndvi_oct2017_1m_v1.tif
#> 61  https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_ndvi_sept2019_1m_v2.tif
#> 73             https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/basemaps/UG_canopy_basemap_v3.tif
#> 74          https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/basemaps/UG_landcover_basemap_v3.tif
#>                                                                                                        Metadata.URL
#> 54 https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_2mcover_3m_v2_metadata.xml
#> 55   https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_cover_3m_v3_metadata.xml
#> 56  https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_height_1m_v2_metadata.xml
#> 57    https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_ht20_3m_v2_metadata.xml
#> 58    https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_canopy_ht80_3m_v4_metadata.xml
#> 59      https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_landcover_1m_v4_metadata.xml
#> 60   https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_ndvi_oct2017_1m_v1_metadata.xml
#> 61  https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/released/release3/UG_ndvi_sept2019_1m_v2_metadata.xml
#> 73             https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/basemaps/UG_canopy_basemap_v3_metadata.xml
#> 74          https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/basemaps/UG_landcover_basemap_v3_metadata.xml
```
