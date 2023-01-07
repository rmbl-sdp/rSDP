test_that("sdp_get_catalog() returns a large data frame with the default arguments." , {
  expect_equal(nrow(sdp_get_catalog()) > 1, TRUE)
})
