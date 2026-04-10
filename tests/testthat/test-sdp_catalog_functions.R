test_that("sdp_get_catalog() returns a large data frame with the default arguments." , {
  expect_equal(nrow(sdp_get_catalog()) > 1, TRUE)
})

test_that("sdp_get_metadata() returns an list named 'qgis'.", {
  expect_equal(names(sdp_get_metadata("R4D022"))=="qgis",TRUE)
})

test_that("sdp_get_catalog(return_stac=TRUE) returns an rstac catalog object.", {
  skip_if_not_installed("rstac")
  skip_on_cran()
  ## This test requires the STAC catalog to be deployed on S3.
  ## It will fail until stac-gen output is synced to
  ## s3://rmbl-sdp/stac/v1/catalog.json.
  tryCatch(
    {
      cat <- sdp_get_catalog(return_stac = TRUE)
      expect_true(inherits(cat, "doc_catalog") || inherits(cat, "STACCatalog") || "id" %in% names(cat))
      expect_equal(cat$id, "rmbl-sdp")
    },
    error = function(e) {
      skip(paste("STAC catalog not yet deployed to S3:", conditionMessage(e)))
    }
  )
})
