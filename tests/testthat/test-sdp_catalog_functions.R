test_that("sdp_get_catalog() returns a large data frame with the default arguments." , {
  expect_equal(nrow(sdp_get_catalog()) > 1, TRUE)
})

test_that("sdp_get_catalog() hides deprecated rows by default and includes them when asked.", {
  cat_default <- sdp_get_catalog()
  cat_all <- sdp_get_catalog(include_deprecated = TRUE)
  expect_true(all(cat_default$Deprecated == FALSE))
  expect_true(nrow(cat_all) >= nrow(cat_default))
  ## Known deprecated -> replacement pairs in the 05_15_2026 catalog.
  dep <- cat_all[cat_all$CatalogID %in% c("R4D001", "R4D002"), ]
  expect_equal(sort(dep$NewVersionID), c("R6D007", "R6D008"))
})

test_that("sdp_get_metadata() warns when looking up a deprecated dataset.", {
  ## Wrap in try() so a network/XML failure doesn't mask the warning check.
  expect_warning(try(sdp_get_metadata("R4D001"), silent = TRUE), "deprecated")
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
