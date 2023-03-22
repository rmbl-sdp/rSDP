test_that("sdp_get_catalog() returns a large data frame with the default arguments." , {
  expect_equal(nrow(sdp_get_catalog()) > 1, TRUE)
})

test_that("sdp_get_metadata() returns an list named 'qgis'.", {
  expect_equal(names(sdp_get_metadata("R4D022"))=="qgis",TRUE)
})
