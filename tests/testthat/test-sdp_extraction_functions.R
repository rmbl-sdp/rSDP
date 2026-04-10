test_that("sdp_get_raster() returns data for single layer datasets", {
  expect_s4_class(sdp_get_raster("R1D014"), "SpatRaster")
})

## Regression pins for names(raster). These assertions lock in the exact
## form of layer names produced by each TimeSeriesType so that the
## decomposition refactor of sdp_get_raster() can be verified not to
## silently change them. sdp_extract_data() relies on Yearly names being
## character (via int-to-string coercion) and Daily names being parseable
## by as.Date(); changing either form would break downstream filtering.
test_that("sdp_get_raster() preserves Single layer-name format (basename minus .tif)", {
  r <- sdp_get_raster("R1D014")
  expect_equal(names(r), "UER_mask_3m_v1")
})

test_that("sdp_get_raster() preserves Yearly layer-name format (4-digit year as character)", {
  r <- sdp_get_raster("R4D003", years = 2003:2004)
  expect_equal(names(r), c("2003", "2004"))
})

test_that("sdp_get_raster() preserves Daily layer-name format (YYYY-MM-DD)", {
  r <- sdp_get_raster("R4D004",
                      date_start = as.Date("2020-11-01"),
                      date_end   = as.Date("2020-11-01"))
  expect_equal(names(r), "2020-11-01")
})

test_that("sdp_get_raster() accepts a direct URL (url= branch)", {
  ## Integration test for the previously-broken URL branch. Uses a known
  ## Single dataset's Data.URL from the catalog so it stays valid as long
  ## as R1D014 exists. The URL branch does not apply scale/offset, and
  ## that caveat is documented in @param url.
  cat_row <- sdp_get_catalog(deprecated = c(FALSE, TRUE))
  cat_row <- cat_row[cat_row$CatalogID == "R1D014", ]
  expect_s4_class(sdp_get_raster(url = cat_row$Data.URL), "SpatRaster")
})

test_that("sdp_get_raster() returns data for daily timeseries when dates are specified", {
  expect_s4_class(sdp_get_raster("R4D004",date_start=as.Date("2020-11-01"),date_end=as.Date("2020-11-01")), "SpatRaster")
})

test_that("sdp_get_raster() returns data for daily timeseries when dates are not specified", {
  expect_s4_class(sdp_get_raster("R4D004"), "SpatRaster")
})

test_that("sdp_get_raster() returns data for monthly timeseries when only months are specified", {
  expect_s4_class(sdp_get_raster("R4D008",months=c(1,2)), "SpatRaster")
})

test_that("sdp_get_raster() returns data for monthly timeseries when months and years are specified", {
  expect_s4_class(sdp_get_raster("R4D008",months=c(6,7), years=c(2003:2005)), "SpatRaster")
})

test_that("sdp_get_raster() returns data for monthly timeseries when date_start and date_end are specified", {
  expect_s4_class(sdp_get_raster("R4D008",date_start=as.Date("2002-09-15"),date_end=as.Date("2002-11-15")), "SpatRaster")
})

test_that("sdp_get_raster() returns data for yearly timeseries when years are specified", {
  expect_s4_class(sdp_get_raster("R4D003",years=2003:2004), "SpatRaster")
})

test_that("sdp_get_raster() returns data for yearly timeseries when date_start and date_end are specified", {
  expect_s4_class(sdp_get_raster("R4D003",date_start=as.Date("2002-09-15"),date_end=as.Date("2003-11-15")), "SpatRaster")
})

test_that("sdp_extract_data() works with spatVectors", {
  location_df <- data.frame(SiteName=c("Roaring Judy","Gothic","Galena Lake"),
                            Lat=c(38.716995,38.958446,39.021644),
                            Lon=c(-106.853186,-106.988934,-107.072569))
  location_sv <- terra::vect(location_df,geom=c("Lon","Lat"),crs="EPSG:4327")
  test_raster <- sdp_get_raster("R4D003",date_start=as.Date("2002-09-15"),date_end=as.Date("2003-11-15"))
  expect_s4_class(sdp_extract_data(test_raster,location_sv,
                                   return_type = 'SpatVector'), "SpatVector")
})
