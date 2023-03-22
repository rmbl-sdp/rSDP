test_that("sdp_get_raster() returns data for single layer datasets", {
  expect_s4_class(sdp_get_raster("R1D014"), "SpatRaster")
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
