test_that("get_sdp_catalog() returns a large data frame with the default arguments." , {
  expect_equal(nrow(get_sdp_catalog()) > 1, TRUE)
})
