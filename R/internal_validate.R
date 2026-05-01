## Internal argument-validation helpers for sdp_get_raster() and friends.
##
## These split the old single validation block into two stages so that the
## URL branch can reuse the pre-lookup half, and so that the post-lookup
## "is this arg combo supported for this TimeSeriesType?" checks have a
## single source of truth. None of these are exported.

## Pre-catalog-lookup checks. Returns a normalized arg list (currently
## just `months_pad`) so downstream code doesn't need to recompute it from
## the raw `months` input.
.validate_user_args <- function(catalog_id, url, years, months,
                                date_start, date_end,
                                download_files, download_path) {
  stopifnot("Please specify either catalog_id or url, not both." =
              is.null(catalog_id) | is.null(url))
  stopifnot("You must specify either catalog_id or url." =
              is.character(catalog_id) | is.character(url))
  stopifnot("Please specify a single Catalog ID or URL." =
              length(catalog_id) %in% c(0, 1) & length(url) %in% c(0, 1))
  stopifnot("Please specify a single Catalog ID or URL." =
              length(c(catalog_id, url)) == 1)
  stopifnot("Date ranges must be class `Date` if specified." =
              (is.null(date_start) & is.null(date_end)) |
              (inherits(date_start, "Date") & inherits(date_end, "Date")))
  stopifnot("You must specify `download_path` if `download_files=TRUE`" =
              (download_files == FALSE & is.null(download_path)) |
              (download_files == TRUE & is.character(download_path)))

  ## Normalize `months` to zero-padded two-digit strings (was a dangling
  ## free variable `months_pad` in the old body of sdp_get_raster()).
  months_pad <- if (is.null(months)) {
    NULL
  } else {
    formatC(as.numeric(months), width = 2, format = "d", flag = "0")
  }
  stopifnot("Invalid months specified." =
              is.null(months_pad) |
              all(months_pad %in% formatC(1:12, width = 2, format = "d", flag = "0")))

  list(months_pad = months_pad)
}

## Post-catalog-lookup check: is this combination of time arguments valid
## for the dataset's TimeSeriesType? Previously these combinations fell
## through the if/else chain silently and produced cryptic terra errors
## from unsubstituted `{year}`/`{month}`/`{day}` placeholders in paths.
## Now they produce clear messages at the rSDP boundary.
.validate_args_vs_type <- function(ts_type, years, months, date_start, date_end) {
  has_years  <- !is.null(years)
  has_months <- !is.null(months)
  has_dates  <- !is.null(date_start) && !is.null(date_end)

  if (ts_type == "Single") {
    if (has_years || has_months || has_dates) {
      stop("Time arguments (years/months/date_start/date_end) are not supported for Single datasets.")
    }
  } else if (ts_type == "Yearly") {
    if (has_months) {
      stop("`months` is not supported for Yearly datasets.")
    }
    if (has_years && has_dates) {
      stop("Specify either `years` or `date_start`/`date_end` for Yearly datasets, not both.")
    }
  } else if (ts_type == "Monthly") {
    if (has_years && !has_months && !has_dates) {
      stop("For Monthly datasets, `years` must be combined with `months`. Use `date_start`/`date_end` instead if you want a date-range subset.")
    }
    if (has_dates && (has_years || has_months)) {
      stop("For Monthly datasets, use either `date_start`/`date_end` OR `years`/`months`, not both.")
    }
  } else if (ts_type == "Daily") {
    if (has_years || has_months) {
      stop("For Daily datasets, use `date_start`/`date_end` instead of `years` or `months`.")
    }
  } else if (ts_type == "Weekly") {
    if (has_years || has_months) {
      stop("For Weekly datasets, use `date_start`/`date_end` or `dates` instead of `years` or `months`.")
    }
  }
  ## Seasonal or unknown types fall through without validation, matching
  ## the old behavior (there is no resolver for Seasonal yet either).
  invisible(NULL)
}
