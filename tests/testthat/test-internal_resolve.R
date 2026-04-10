## In-memory catalog-row fixture for resolver tests. Constructs a one-row
## data frame with the columns the resolvers read. No network, no COG.
.fake_cat_line <- function(type,
                           data_url = "https://test.example/data/{year}.tif",
                           min_date = as.Date("2003-01-01"),
                           max_date = as.Date("2005-12-31"),
                           min_year = 2003L,
                           max_year = 2005L,
                           scale_factor = 1,
                           offset = 0) {
  data.frame(
    CatalogID       = "FAKE01",
    TimeSeriesType  = type,
    Data.URL        = data_url,
    MinDate         = min_date,
    MaxDate         = max_date,
    MinYear         = min_year,
    MaxYear         = max_year,
    DataScaleFactor = scale_factor,
    DataOffset      = offset,
    stringsAsFactors = FALSE
  )
}

## --- .substitute_template ---

test_that(".substitute_template handles vector year", {
  result <- .substitute_template("a/{year}/b.tif", year = 2003:2005)
  expect_equal(result, c("a/2003/b.tif", "a/2004/b.tif", "a/2005/b.tif"))
})

test_that(".substitute_template handles scalar year", {
  result <- .substitute_template("a/{year}/b.tif", year = 2003)
  expect_equal(result, "a/2003/b.tif")
})

test_that(".substitute_template handles year and month together", {
  result <- .substitute_template("a/{year}/{month}/b.tif",
                                 year  = c("2003", "2003"),
                                 month = c("01", "02"))
  expect_equal(result, c("a/2003/01/b.tif", "a/2003/02/b.tif"))
})

test_that(".substitute_template recycles scalar against vector", {
  result <- .substitute_template("a/{year}/{month}/b.tif",
                                 year  = "2003",
                                 month = c("01", "02", "03"))
  expect_equal(result, c("a/2003/01/b.tif", "a/2003/02/b.tif", "a/2003/03/b.tif"))
})

test_that(".substitute_template returns template unchanged when nothing passed", {
  expect_equal(.substitute_template("a/b.tif"), "a/b.tif")
})

test_that(".substitute_template rejects mismatched vector lengths", {
  expect_error(
    .substitute_template("a/{year}/{month}/b.tif",
                         year  = c("2003", "2004", "2005"),
                         month = c("01", "02"))
  )
})

## --- .resolve_single ---

test_that(".resolve_single returns one path and basename-minus-tif name", {
  cl <- .fake_cat_line("Single", data_url = "https://test.example/dem_1m_v1.tif")
  result <- .resolve_single(cl, verbose = FALSE)
  expect_length(result$paths, 1L)
  expect_equal(result$names, "dem_1m_v1")
  expect_equal(result$paths, paste0(.SDP_VSICURL_PREFIX, "https://test.example/dem_1m_v1.tif"))
})

## --- .resolve_yearly ---

test_that(".resolve_yearly with explicit years returns character names", {
  cl <- .fake_cat_line("Yearly", min_year = 2003L, max_year = 2005L)
  result <- suppressMessages(
    .resolve_yearly(cl, years = 2003:2004,
                    date_start = NULL, date_end = NULL, verbose = FALSE)
  )
  expect_equal(result$names, c("2003", "2004"))
  expect_length(result$paths, 2L)
  expect_type(result$names, "character")
})

test_that(".resolve_yearly with no time args returns all catalog years", {
  cl <- .fake_cat_line("Yearly", min_year = 2003L, max_year = 2005L)
  result <- suppressMessages(
    .resolve_yearly(cl, years = NULL,
                    date_start = NULL, date_end = NULL, verbose = FALSE)
  )
  expect_equal(result$names, c("2003", "2004", "2005"))
})

test_that(".resolve_yearly errors when requested years are entirely outside range", {
  cl <- .fake_cat_line("Yearly", min_year = 2003L, max_year = 2005L)
  expect_error(
    .resolve_yearly(cl, years = c(1999, 2001),
                    date_start = NULL, date_end = NULL, verbose = FALSE),
    "No dataset available for any specified years"
  )
})

test_that(".resolve_yearly warns when some years are outside range", {
  cl <- .fake_cat_line("Yearly", min_year = 2003L, max_year = 2005L)
  expect_warning(
    suppressMessages(
      .resolve_yearly(cl, years = c(2001, 2003, 2004),
                      date_start = NULL, date_end = NULL, verbose = FALSE)
    ),
    "No dataset available for some specified years"
  )
})

test_that(".resolve_yearly with date range preserves seq(by='year') anchor-day semantics", {
  ## Request Jun 15 2003 through Jun 10 2005. seq(by='year') anchors on
  ## the FIRST day of the overlap (Jun 15) and steps one year at a time:
  ## Jun 15 2003, Jun 15 2004. Jun 15 2005 would come next, but 2005-06-15
  ## is AFTER the requested end of 2005-06-10, so it is excluded.
  ## This is an off-by-one trap preserved verbatim from the old code.
  cl <- .fake_cat_line("Yearly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-31"),
                        min_year = 2003L, max_year = 2005L)
  result <- suppressMessages(
    .resolve_yearly(cl, years = NULL,
                    date_start = as.Date("2003-06-15"),
                    date_end   = as.Date("2005-06-10"),
                    verbose = FALSE)
  )
  expect_equal(result$names, c("2003", "2004"))
})

test_that(".resolve_yearly with date range covering full years returns all years", {
  cl <- .fake_cat_line("Yearly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-31"),
                        min_year = 2003L, max_year = 2005L)
  result <- suppressMessages(
    .resolve_yearly(cl, years = NULL,
                    date_start = as.Date("2003-01-01"),
                    date_end   = as.Date("2005-12-31"),
                    verbose = FALSE)
  )
  expect_equal(result$names, c("2003", "2004", "2005"))
})

## --- .resolve_monthly ---

test_that(".resolve_monthly with years and months returns year-month cross-product", {
  cl <- .fake_cat_line("Monthly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-01"),
                        data_url = "https://test.example/{year}_{month}.tif")
  result <- suppressMessages(
    .resolve_monthly(cl,
                     years      = c(2003, 2004),
                     months_pad = c("06", "07"),
                     date_start = NULL, date_end = NULL,
                     verbose    = FALSE)
  )
  expect_equal(result$names, c("2003-06", "2003-07", "2004-06", "2004-07"))
})

test_that(".resolve_monthly with months only returns matching months across all years", {
  cl <- .fake_cat_line("Monthly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2004-12-01"),
                        data_url = "https://test.example/{year}_{month}.tif")
  result <- suppressMessages(
    .resolve_monthly(cl,
                     years      = NULL,
                     months_pad = "07",
                     date_start = NULL, date_end = NULL,
                     verbose    = FALSE)
  )
  expect_equal(result$names, c("2003-07", "2004-07"))
})

test_that(".resolve_monthly with no time args returns all monthly layers", {
  cl <- .fake_cat_line("Monthly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2003-03-01"),
                        data_url = "https://test.example/{year}_{month}.tif")
  result <- suppressMessages(
    .resolve_monthly(cl,
                     years      = NULL,
                     months_pad = NULL,
                     date_start = NULL, date_end = NULL,
                     verbose    = FALSE)
  )
  expect_equal(result$names, c("2003-01", "2003-02", "2003-03"))
})

test_that(".resolve_monthly errors on empty overlap", {
  cl <- .fake_cat_line("Monthly",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2003-12-01"),
                        data_url = "https://test.example/{year}_{month}.tif")
  ## Request year 1999 — no overlap at all.
  expect_error(
    suppressMessages(
      .resolve_monthly(cl,
                       years      = 1999,
                       months_pad = "06",
                       date_start = NULL, date_end = NULL,
                       verbose    = FALSE)
    )
  )
})

## --- .resolve_daily ---

test_that(".resolve_daily with no time args clips to first 30 layers", {
  cl <- .fake_cat_line("Daily",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-31"),
                        data_url = "https://test.example/{year}_{day}.tif")
  result <- suppressMessages(
    .resolve_daily(cl, date_start = NULL, date_end = NULL, verbose = FALSE)
  )
  expect_length(result$paths, 30L)
  expect_length(result$names, 30L)
  expect_equal(result$names[1],  "2003-01-01")
  expect_equal(result$names[30], "2003-01-30")
})

test_that(".resolve_daily with date range returns exactly the overlap", {
  cl <- .fake_cat_line("Daily",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-31"),
                        data_url = "https://test.example/{year}_{day}.tif")
  result <- suppressMessages(
    .resolve_daily(cl,
                   date_start = as.Date("2003-01-05"),
                   date_end   = as.Date("2003-01-07"),
                   verbose    = FALSE)
  )
  expect_equal(result$names, c("2003-01-05", "2003-01-06", "2003-01-07"))
  expect_length(result$paths, 3L)
})

test_that(".resolve_daily errors when request is entirely outside range", {
  cl <- .fake_cat_line("Daily",
                        min_date = as.Date("2003-01-01"),
                        max_date = as.Date("2005-12-31"))
  expect_error(
    .resolve_daily(cl,
                   date_start = as.Date("1999-01-01"),
                   date_end   = as.Date("1999-12-31"),
                   verbose    = FALSE),
    "No data available for any requested days"
  )
})

## --- .resolve_time_slices dispatch ---

test_that(".resolve_time_slices dispatches correctly on TimeSeriesType", {
  cl_single <- .fake_cat_line("Single", data_url = "https://test.example/x.tif")
  result <- .resolve_time_slices(cl_single, NULL, NULL, NULL, NULL, verbose = FALSE)
  expect_equal(result$names, "x")

  cl_yearly <- .fake_cat_line("Yearly")
  result_y <- suppressMessages(
    .resolve_time_slices(cl_yearly, 2003:2004, NULL, NULL, NULL, verbose = FALSE)
  )
  expect_equal(result_y$names, c("2003", "2004"))
})

test_that(".resolve_time_slices errors on unsupported TimeSeriesType", {
  cl_bad <- .fake_cat_line("UnknownType")
  expect_error(
    .resolve_time_slices(cl_bad, NULL, NULL, NULL, NULL, verbose = FALSE),
    "Unsupported TimeSeriesType"
  )
})
