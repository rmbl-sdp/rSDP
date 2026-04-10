test_that(".apply_raster_metadata sets names and CRS", {
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  result <- .apply_raster_metadata(r,
                                   layer_names  = "test_layer",
                                   scale_factor = 10,
                                   offset       = 5)
  expect_equal(names(result), "test_layer")
  expect_true(grepl("32613", terra::crs(result)))
  ## Note: scoff behavior on pure in-memory rasters (created via
  ## terra::rast(nrows, ncols, vals)) is a silent no-op — scale/offset
  ## are file-header metadata and the setter has no effect without a
  ## source file. The scoff round-trip is exercised by the live-S3
  ## tests in test-sdp_extraction_functions.R via sdp_get_raster().
})

test_that(".apply_raster_metadata is NULL-safe when scale_factor or offset are NULL", {
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  expect_no_error({
    result <- .apply_raster_metadata(r, layer_names = "test")
  })
  expect_equal(names(result), "test")
  expect_true(grepl("32613", terra::crs(result)))
})

test_that(".apply_raster_metadata accepts multi-layer names", {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 3, vals = 1:12)
  result <- .apply_raster_metadata(r,
                                   layer_names = c("2003", "2004", "2005"))
  expect_equal(names(result), c("2003", "2004", "2005"))
})
