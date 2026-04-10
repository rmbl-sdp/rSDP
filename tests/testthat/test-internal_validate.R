test_that(".validate_args_vs_type rejects Single with any time args", {
  expect_error(
    .validate_args_vs_type("Single", years = 2003, months = NULL,
                           date_start = NULL, date_end = NULL),
    "not supported for Single"
  )
  expect_error(
    .validate_args_vs_type("Single", years = NULL, months = NULL,
                           date_start = as.Date("2003-01-01"),
                           date_end   = as.Date("2003-01-02")),
    "not supported for Single"
  )
})

test_that(".validate_args_vs_type rejects Yearly with months", {
  expect_error(
    .validate_args_vs_type("Yearly", years = NULL, months = 6,
                           date_start = NULL, date_end = NULL),
    "not supported for Yearly"
  )
})

test_that(".validate_args_vs_type rejects Yearly with years AND dates", {
  expect_error(
    .validate_args_vs_type("Yearly", years = 2003, months = NULL,
                           date_start = as.Date("2003-01-01"),
                           date_end   = as.Date("2004-01-01")),
    "either `years` or `date_start`"
  )
})

test_that(".validate_args_vs_type rejects Monthly with years-only (no months/dates)", {
  expect_error(
    .validate_args_vs_type("Monthly", years = 2003, months = NULL,
                           date_start = NULL, date_end = NULL),
    "must be combined with"
  )
})

test_that(".validate_args_vs_type rejects Daily with years or months", {
  expect_error(
    .validate_args_vs_type("Daily", years = 2003, months = NULL,
                           date_start = NULL, date_end = NULL),
    "Daily datasets"
  )
  expect_error(
    .validate_args_vs_type("Daily", years = NULL, months = 6,
                           date_start = NULL, date_end = NULL),
    "Daily datasets"
  )
})

test_that(".validate_args_vs_type accepts all valid combinations silently", {
  expect_silent(.validate_args_vs_type("Single", NULL, NULL, NULL, NULL))
  expect_silent(.validate_args_vs_type("Yearly", 2003, NULL, NULL, NULL))
  expect_silent(.validate_args_vs_type("Yearly", NULL, NULL,
                                       as.Date("2003-01-01"),
                                       as.Date("2005-12-31")))
  expect_silent(.validate_args_vs_type("Yearly", NULL, NULL, NULL, NULL))
  expect_silent(.validate_args_vs_type("Monthly", 2003, 6, NULL, NULL))
  expect_silent(.validate_args_vs_type("Monthly", NULL, 6, NULL, NULL))
  expect_silent(.validate_args_vs_type("Monthly", NULL, NULL,
                                       as.Date("2003-01-01"),
                                       as.Date("2003-06-30")))
  expect_silent(.validate_args_vs_type("Monthly", NULL, NULL, NULL, NULL))
  expect_silent(.validate_args_vs_type("Daily", NULL, NULL,
                                       as.Date("2003-01-01"),
                                       as.Date("2003-01-10")))
  expect_silent(.validate_args_vs_type("Daily", NULL, NULL, NULL, NULL))
})

test_that(".validate_user_args normalizes months to zero-padded strings", {
  result <- .validate_user_args(catalog_id = "R4D008", url = NULL,
                                years = NULL, months = c(3, 11),
                                date_start = NULL, date_end = NULL,
                                download_files = FALSE, download_path = NULL)
  expect_equal(result$months_pad, c("03", "11"))
})

test_that(".validate_user_args returns NULL months_pad when months not specified", {
  result <- .validate_user_args(catalog_id = "R4D008", url = NULL,
                                years = NULL, months = NULL,
                                date_start = NULL, date_end = NULL,
                                download_files = FALSE, download_path = NULL)
  expect_null(result$months_pad)
})

test_that(".validate_user_args rejects invalid month numbers", {
  expect_error(
    .validate_user_args(catalog_id = "R4D008", url = NULL,
                        years = NULL, months = c(0, 13),
                        date_start = NULL, date_end = NULL,
                        download_files = FALSE, download_path = NULL),
    "Invalid months"
  )
})

test_that(".validate_user_args rejects both catalog_id and url", {
  expect_error(
    .validate_user_args(catalog_id = "R4D008", url = "https://x/y.tif",
                        years = NULL, months = NULL,
                        date_start = NULL, date_end = NULL,
                        download_files = FALSE, download_path = NULL),
    "either catalog_id or url"
  )
})
