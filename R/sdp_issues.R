## Client-side helpers for interacting with the SDP data-issues tracker.
##
## All open issues for SDP datasets are tracked in the dedicated repo
## `rmbl-sdp/sdp-products` rather than the main rSDP code repo, so that
## dataset feedback and code bugs stay cleanly separated. See:
## https://github.com/rmbl-sdp/sdp-products

.SDP_ISSUES_REPO <- "rmbl-sdp/sdp-products"
.SDP_ISSUES_HTML <- paste0("https://github.com/", .SDP_ISSUES_REPO)
.SDP_ISSUES_API  <- paste0("https://api.github.com/repos/", .SDP_ISSUES_REPO)
.SDP_ISSUES_VALID_TYPES <- c(
  "incorrect-values", "missing-dates", "metadata-error",
  "acquisition-gap", "documentation", "other"
)
.SDP_ISSUES_CACHE_TTL_SECS <- 3600L


#' Report an issue with an SDP data product.
#'
#' Opens the GitHub Issue Form for `rmbl-sdp/sdp-products` with the
#' CatalogID (and optional issue type) pre-filled. Dataset issues are
#' tracked in a dedicated repository so that feedback on the *data*
#' stays separate from issues with the rSDP package code.
#'
#' @param catalog_id character. A 6-character SDP CatalogID (e.g.
#'   `"R3D009"`). Must match a current or deprecated entry in
#'   `sdp_get_catalog(include_deprecated = TRUE)`.
#' @param type character. Optional issue type. One of
#'   `"incorrect-values"`, `"missing-dates"`, `"metadata-error"`,
#'   `"acquisition-gap"`, `"documentation"`, `"other"`.
#' @param open logical. If `TRUE` (default), open the URL in the user's
#'   browser via [utils::browseURL()]. If `FALSE`, just return it.
#'
#' @return The prefilled issue-form URL, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' sdp_report_issue("R4D004")
#' sdp_report_issue("R3D009", type = "metadata-error")
#' }
sdp_report_issue <- function(catalog_id, type = NULL, open = TRUE) {
  stopifnot(is.character(catalog_id) && length(catalog_id) == 1L)
  stopifnot(nchar(catalog_id) == .SDP_CATALOG_ID_NCHAR)
  if (!is.null(type)) {
    stopifnot(is.character(type) && length(type) == 1L)
    if (!type %in% .SDP_ISSUES_VALID_TYPES) {
      stop(sprintf("`type` must be one of: %s",
                   paste(.SDP_ISSUES_VALID_TYPES, collapse = ", ")),
           call. = FALSE)
    }
  }

  cat <- sdp_get_catalog(include_deprecated = TRUE)
  if (!catalog_id %in% cat$CatalogID) {
    warning(sprintf("Catalog ID '%s' is not in the bundled catalog; filing anyway.",
                    catalog_id), call. = FALSE)
  }

  params <- c(
    template = "dataset-issue.yml",
    "catalog_id" = catalog_id
  )
  if (!is.null(type)) params <- c(params, issue_type = type)
  query <- paste(
    paste0(names(params), "=", vapply(params, utils::URLencode, character(1), reserved = TRUE)),
    collapse = "&"
  )
  url <- sprintf("%s/issues/new?%s", .SDP_ISSUES_HTML, query)

  if (isTRUE(open)) {
    utils::browseURL(url)
  }
  invisible(url)
}


#' List known open issues for SDP data products.
#'
#' Queries the GitHub REST API for open issues on `rmbl-sdp/sdp-products`
#' and returns them as a tidy data frame. Results are cached on disk
#' for an hour to keep interactive use responsive and to stay within
#' GitHub's anonymous rate limit.
#'
#' @param catalog_id character. Optional CatalogID to filter to a single
#'   dataset. `NULL` (default) returns all open issues.
#' @param refresh logical. If `TRUE`, bypass the on-disk cache and
#'   re-fetch from GitHub.
#'
#' @return A data frame with one row per open issue and columns
#'   `CatalogID`, `number`, `title`, `type`, `severity`, `status`,
#'   `created`, `updated`, `url`. Returns an empty data frame (with the
#'   right columns) if there are no open issues or if the API call
#'   fails offline.
#' @export
#'
#' @examples
#' \dontrun{
#' sdp_known_issues()
#' sdp_known_issues("R4D004")
#' sdp_known_issues(refresh = TRUE)
#' }
sdp_known_issues <- function(catalog_id = NULL, refresh = FALSE) {
  if (!is.null(catalog_id)) {
    stopifnot(is.character(catalog_id) && length(catalog_id) == 1L)
  }
  issues <- .fetch_open_issues(refresh = refresh)
  if (!is.null(catalog_id)) {
    issues <- issues[issues$CatalogID == catalog_id, , drop = FALSE]
  }
  issues
}


## Internal: returns the cache file path for the open-issues snapshot.
.issues_cache_path <- function() {
  dir <- tools::R_user_dir("rSDP", which = "cache")
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.path(dir, "open_issues.rds")
}

## Internal: fetch all open issues from GitHub, returning a data frame.
## Uses an on-disk cache with a 1h TTL. Falls back to cached or empty
## results when the API is unreachable.
.fetch_open_issues <- function(refresh = FALSE) {
  cache_path <- .issues_cache_path()
  if (!isTRUE(refresh) && file.exists(cache_path)) {
    cached <- tryCatch(readRDS(cache_path), error = function(e) NULL)
    if (!is.null(cached) &&
        difftime(Sys.time(), cached$fetched_at, units = "secs") <
        .SDP_ISSUES_CACHE_TTL_SECS) {
      return(cached$issues)
    }
  }

  rlang::check_installed("jsonlite", reason = "to parse GitHub API responses")

  empty <- data.frame(
    CatalogID = character(0), number = integer(0), title = character(0),
    type = character(0), severity = character(0), status = character(0),
    created = as.POSIXct(character(0), tz = "UTC"),
    updated = as.POSIXct(character(0), tz = "UTC"),
    url = character(0),
    stringsAsFactors = FALSE
  )

  fetched <- tryCatch(
    .gh_fetch_issues_paginated(),
    error = function(e) {
      message(sprintf("Could not fetch SDP open issues from GitHub: %s",
                      conditionMessage(e)))
      NULL
    }
  )

  if (is.null(fetched)) {
    ## Fall back to stale cache if present, else empty.
    if (file.exists(cache_path)) {
      cached <- tryCatch(readRDS(cache_path), error = function(e) NULL)
      if (!is.null(cached)) return(cached$issues)
    }
    return(empty)
  }

  saveRDS(list(fetched_at = Sys.time(), issues = fetched), cache_path)
  fetched
}

## Internal: paginated GET against the issues endpoint. Returns a
## data frame. Pull-requests are filtered out (GH lumps PRs into the
## issues endpoint; sdp-products won't have PRs anyway).
.gh_fetch_issues_paginated <- function() {
  rlang::check_installed("jsonlite", reason = "to parse GitHub API responses")
  per_page <- 100L
  page <- 1L
  all_issues <- list()
  repeat {
    url <- sprintf("%s/issues?state=open&per_page=%d&page=%d",
                   .SDP_ISSUES_API, per_page, page)
    h <- curl::new_handle()
    curl::handle_setheaders(h,
      "Accept" = "application/vnd.github+json",
      "User-Agent" = "rSDP"
    )
    pat <- Sys.getenv("GITHUB_PAT", Sys.getenv("GITHUB_TOKEN", ""))
    if (nzchar(pat)) {
      curl::handle_setheaders(h, "Authorization" = paste("Bearer", pat))
    }
    resp <- curl::curl_fetch_memory(url, handle = h)
    if (resp$status_code != 200L) {
      stop(sprintf("GitHub API returned HTTP %d", resp$status_code),
           call. = FALSE)
    }
    chunk <- jsonlite::fromJSON(rawToChar(resp$content),
                                simplifyVector = FALSE)
    if (length(chunk) == 0L) break
    all_issues <- c(all_issues, chunk)
    if (length(chunk) < per_page) break
    page <- page + 1L
  }

  .issues_to_dataframe(all_issues)
}

## Internal: turn a list of GH issue objects into a tidy data frame.
.issues_to_dataframe <- function(issues) {
  if (length(issues) == 0L) {
    return(data.frame(
      CatalogID = character(0), number = integer(0), title = character(0),
      type = character(0), severity = character(0), status = character(0),
      created = as.POSIXct(character(0), tz = "UTC"),
      updated = as.POSIXct(character(0), tz = "UTC"),
      url = character(0),
      stringsAsFactors = FALSE
    ))
  }

  pick_label <- function(labels, prefix) {
    names <- vapply(labels, function(l) l$name %||% "", character(1))
    hit <- names[startsWith(names, prefix)]
    if (length(hit) == 0L) NA_character_ else sub(prefix, "", hit[[1L]])
  }
  ## R's || does not handle NULL like rlang's %||%; define locally.
  `%||%` <- function(a, b) if (is.null(a)) b else a

  ## GH lumps PRs into the issues endpoint — filter them out.
  issues <- Filter(function(i) is.null(i$pull_request), issues)

  data.frame(
    CatalogID = vapply(issues, function(i) pick_label(i$labels, "product:"),
                      character(1)),
    number    = vapply(issues, function(i) as.integer(i$number), integer(1)),
    title     = vapply(issues, function(i) i$title %||% "", character(1)),
    type      = vapply(issues, function(i) pick_label(i$labels, "type:"),
                      character(1)),
    severity  = vapply(issues, function(i) pick_label(i$labels, "severity:"),
                      character(1)),
    status    = vapply(issues, function(i) pick_label(i$labels, "status:"),
                      character(1)),
    created   = as.POSIXct(vapply(issues, function(i) i$created_at %||% NA_character_, character(1)),
                           tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    updated   = as.POSIXct(vapply(issues, function(i) i$updated_at %||% NA_character_, character(1)),
                           tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    url       = vapply(issues, function(i) i$html_url %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

## Internal: counts of open issues per CatalogID. Returns a data frame
## with columns CatalogID, OpenIssues. Used by sdp_get_catalog() and
## sdp_browse() to surface counts inline.
.open_issue_counts <- function(refresh = FALSE) {
  issues <- .fetch_open_issues(refresh = refresh)
  if (nrow(issues) == 0L) {
    return(data.frame(CatalogID = character(0), OpenIssues = integer(0),
                      stringsAsFactors = FALSE))
  }
  issues <- issues[!is.na(issues$CatalogID), , drop = FALSE]
  tab <- table(issues$CatalogID)
  data.frame(CatalogID = names(tab),
             OpenIssues = as.integer(unname(tab)),
             stringsAsFactors = FALSE)
}
