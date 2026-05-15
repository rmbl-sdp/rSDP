test_that("sdp_report_issue() builds a prefilled URL with catalog_id", {
  url <- sdp_report_issue("R4D001", open = FALSE)
  expect_match(url, "github.com/rmbl-sdp/sdp-products/issues/new")
  expect_match(url, "template=dataset-issue.yml")
  expect_match(url, "catalog_id=R4D001")
})

test_that("sdp_report_issue() appends a type when provided", {
  url <- sdp_report_issue("R4D001", type = "metadata-error", open = FALSE)
  expect_match(url, "issue_type=metadata-error")
})

test_that("sdp_report_issue() rejects invalid type", {
  expect_error(
    sdp_report_issue("R4D001", type = "no-such-type", open = FALSE),
    "must be one of"
  )
})

test_that("sdp_report_issue() warns on an unknown catalog_id but still returns a URL", {
  expect_warning(
    url <- sdp_report_issue("ZZZ999", open = FALSE),
    "not in the bundled catalog"
  )
  expect_match(url, "catalog_id=ZZZ999")
})

test_that(".issues_to_dataframe handles an empty input", {
  df <- rSDP:::.issues_to_dataframe(list())
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0L)
  expect_setequal(
    names(df),
    c("CatalogID", "number", "title", "type", "severity", "status",
      "created", "updated", "url")
  )
})

test_that(".issues_to_dataframe extracts product/type/severity labels", {
  issue <- list(
    number = 7L,
    title = "Bad pixels in 2019",
    html_url = "https://github.com/rmbl-sdp/sdp-products/issues/7",
    created_at = "2026-05-15T00:00:00Z",
    updated_at = "2026-05-16T00:00:00Z",
    labels = list(
      list(name = "product:R4D004"),
      list(name = "type:incorrect-values"),
      list(name = "severity:high"),
      list(name = "status:investigating")
    )
  )
  df <- rSDP:::.issues_to_dataframe(list(issue))
  expect_equal(df$CatalogID, "R4D004")
  expect_equal(df$type, "incorrect-values")
  expect_equal(df$severity, "high")
  expect_equal(df$status, "investigating")
  expect_equal(df$number, 7L)
})

test_that(".issues_to_dataframe filters out pull requests", {
  pr <- list(number = 1L, title = "a PR",
             html_url = "https://example.com",
             created_at = "2026-01-01T00:00:00Z",
             updated_at = "2026-01-01T00:00:00Z",
             labels = list(),
             pull_request = list(url = "x"))
  issue <- list(number = 2L, title = "an issue",
                html_url = "https://example.com",
                created_at = "2026-01-01T00:00:00Z",
                updated_at = "2026-01-01T00:00:00Z",
                labels = list())
  df <- rSDP:::.issues_to_dataframe(list(pr, issue))
  expect_equal(nrow(df), 1L)
  expect_equal(df$number, 2L)
})

test_that("sdp_get_catalog(with_issue_counts=TRUE) adds an OpenIssues column", {
  ## Use a temporary cache directory so we don't touch the user's real
  ## cache and so we can pre-seed a synthetic snapshot.
  tmp <- tempfile("rSDP-cache-")
  dir.create(tmp, recursive = TRUE)
  old_cache <- Sys.getenv("R_USER_CACHE_DIR", unset = NA)
  Sys.setenv(R_USER_CACHE_DIR = tmp)
  on.exit({
    if (is.na(old_cache)) Sys.unsetenv("R_USER_CACHE_DIR")
    else Sys.setenv(R_USER_CACHE_DIR = old_cache)
  })
  snapshot <- list(
    fetched_at = Sys.time(),
    issues = data.frame(
      CatalogID = c("R4D001", "R4D001", "R4D008"),
      number = 1:3,
      title = c("a", "b", "c"),
      type = NA_character_, severity = NA_character_, status = NA_character_,
      created = Sys.time(), updated = Sys.time(),
      url = "https://example.com",
      stringsAsFactors = FALSE
    )
  )
  saveRDS(snapshot, rSDP:::.issues_cache_path())

  cat <- sdp_get_catalog(include_deprecated = TRUE, with_issue_counts = TRUE)
  expect_true("OpenIssues" %in% names(cat))
  expect_equal(cat$OpenIssues[cat$CatalogID == "R4D001"], 2L)
  expect_equal(cat$OpenIssues[cat$CatalogID == "R4D008"], 1L)
  expect_equal(cat$OpenIssues[cat$CatalogID == "R4D002"], 0L)
})
