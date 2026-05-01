## Internal helpers for resolving SDP catalog entries into concrete lists
## of raster paths and layer names, and for filtering already-loaded
## SpatRasters by time. These replace the ~180-line if/else chain that
## used to live inside sdp_get_raster(). None are exported.
##
## Design notes:
##  - Resolvers are PURE functions. Given a one-row `cat_line` data frame
##    and argument values, they return list(paths, names). They do not
##    touch the network and do not call terra::rast(). This makes them
##    unit-testable with in-memory fixtures.
##  - Resolvers own their own verbose message() calls because only they
##    know the final layer count.
##  - `names` is always a character vector. This matters: sdp_extract_data()
##    does `as.numeric(names(raster))` on Yearly rasters and checks
##    `names(raster) %in% as.character(1900:2100)`. The previous Y1 branch
##    produced numeric `raster_names` that became character only via the
##    implicit int-to-string coercion in `names<-`. We produce character
##    directly.
##  - Several subtle off-by-one behaviors (Y3 and M2 both step by year/month
##    from the FIRST overlap day, not from calendar boundaries) are
##    PRESERVED verbatim because the exact semantics are load-bearing and
##    documented in the behavioral preservation matrix of the refactor
##    plan. Do not "fix" them here.

## Substitute {year}, {month}, {day} placeholders in a URL template.
##
## Accepts NULL, scalar, or vector values for each placeholder. Scalar
## values are recycled against the longest vector. Placeholders that are
## NULL are left as-is in the template (callers are expected to only pass
## the placeholders their dataset uses).
.substitute_template <- function(template, year = NULL, month = NULL,
                                  day = NULL, calendarday = NULL) {
  stopifnot(length(template) == 1L)

  lens <- c(
    if (!is.null(year))        length(year),
    if (!is.null(month))       length(month),
    if (!is.null(day))         length(day),
    if (!is.null(calendarday)) length(calendarday)
  )
  if (length(lens) == 0L) {
    return(template)
  }
  n <- max(lens)
  stopifnot(all(lens == 1L | lens == n))

  year_v  <- if (is.null(year))        NULL else rep(as.character(year),        length.out = n)
  month_v <- if (is.null(month))       NULL else rep(as.character(month),       length.out = n)
  day_v   <- if (is.null(day))         NULL else rep(as.character(day),         length.out = n)
  cday_v  <- if (is.null(calendarday)) NULL else rep(as.character(calendarday), length.out = n)

  out <- character(n)
  for (i in seq_len(n)) {
    s <- template
    if (!is.null(year_v))  s <- gsub("{year}",        year_v[i],  s, fixed = TRUE)
    if (!is.null(month_v)) s <- gsub("{month}",       month_v[i], s, fixed = TRUE)
    if (!is.null(day_v))   s <- gsub("{day}",         day_v[i],   s, fixed = TRUE)
    if (!is.null(cday_v))  s <- gsub("{calendarday}", cday_v[i],  s, fixed = TRUE)
    out[i] <- s
  }
  out
}

## Single dispatcher: picks the resolver for this TimeSeriesType.
## Caller must have already run .validate_args_vs_type() on the same
## cat_line$TimeSeriesType so we can assume the arg combo is valid here.
.resolve_time_slices <- function(cat_line, years, months_pad,
                                 date_start, date_end, dates,
                                 verbose) {
  switch(cat_line$TimeSeriesType,
    Single  = .resolve_single(cat_line, verbose),
    Yearly  = .resolve_yearly(cat_line, years, date_start, date_end, verbose),
    Monthly = .resolve_monthly(cat_line, years, months_pad, date_start, date_end, verbose),
    Daily   = .resolve_daily(cat_line, date_start, date_end, verbose),
    Weekly  = .resolve_weekly(cat_line, dates, date_start, date_end, verbose),
    stop(sprintf("Unsupported TimeSeriesType: '%s'", cat_line$TimeSeriesType))
  )
}

## Single: one path, one layer name derived from the filename minus .tif.
## Note: the .tif strip uses an unanchored, unescaped pattern verbatim from
## the old code. Subtly broken for hypothetical URLs containing `xtif` etc,
## but current catalog data is safe. Not fixing here to keep the refactor
## behavior-preserving.
.resolve_single <- function(cat_line, verbose) {
  template <- paste0(.SDP_VSICURL_PREFIX, cat_line$Data.URL)
  list(
    paths = template,
    names = gsub(".tif", "", basename(cat_line$Data.URL))
  )
}

## Yearly: three sub-cases matching the old Y1/Y2/Y3 branches.
.resolve_yearly <- function(cat_line, years, date_start, date_end, verbose) {
  template <- paste0(.SDP_VSICURL_PREFIX, cat_line$Data.URL)
  cat_years <- cat_line$MinYear:cat_line$MaxYear

  if (!is.null(years)) {
    ## Y1: explicit years
    years_cat <- years[years %in% cat_years]
    if (length(years_cat) == 0L) {
      stop(paste("No dataset available for any specified years. Available years are",
                 paste(cat_years, collapse = " ")))
    } else if (length(years_cat) < length(years)) {
      warning(paste("No dataset available for some specified years. \n Returning data for",
                    years_cat))
    }
    paths <- .substitute_template(template, year = years_cat)
    layer_names <- as.character(years_cat)
    if (verbose) {
      message(paste("Returning yearly dataset with", length(years_cat), "layers..."))
    }
  } else if (!is.null(date_start) && !is.null(date_end)) {
    ## Y3: date range. Anchor-day semantics of seq(by="year") are
    ## PRESERVED from the old code — do not replace with integer year
    ## arithmetic even though it would be simpler.
    cat_days <- seq(cat_line$MinDate, cat_line$MaxDate, by = "day")
    req_days <- seq(date_start, date_end, by = "day")
    days_overlap <- req_days[req_days %in% cat_days]
    if (length(days_overlap) == 0L) {
      stop(paste("No dataset available for the specified years. Available years are",
                 paste(cat_years, collapse = " ")))
    }
    dates_overlap <- seq(min(days_overlap), max(days_overlap), by = "year")
    years_overlap <- format(dates_overlap, "%Y")
    paths <- .substitute_template(template, year = years_overlap)
    layer_names <- years_overlap
    if (verbose) {
      message(paste("Returning yearly dataset with", length(paths), "layers..."))
    }
  } else {
    ## Y2: no time args — return all catalog years.
    paths <- .substitute_template(template, year = cat_years)
    layer_names <- as.character(cat_years)
    if (verbose) {
      message(paste("Returning yearly dataset with", length(cat_years), "layers..."))
    }
  }

  list(paths = paths, names = layer_names)
}

## Monthly: four sub-cases matching the old M1/M2/M3/M4 branches. Takes
## already-padded months_pad from the caller (normalized in
## .validate_user_args()).
.resolve_monthly <- function(cat_line, years, months_pad,
                             date_start, date_end, verbose) {
  template <- paste0(.SDP_VSICURL_PREFIX, cat_line$Data.URL)
  cat_months <- seq(cat_line$MinDate, cat_line$MaxDate, by = "month")
  cat_months_char <- format(cat_months, format = "%m")
  cat_years_char  <- format(cat_months, format = "%Y")

  if (!is.null(years) && !is.null(months_pad)) {
    ## M1: years + months intersection
    years_char <- as.character(years)
    dates_overlap <- cat_months[cat_months_char %in% months_pad &
                                cat_years_char  %in% years_char]
  } else if (!is.null(date_start) && !is.null(date_end)) {
    ## M2: date range. Anchor-day semantics of seq(by="month") PRESERVED.
    cat_days <- seq(cat_line$MinDate, cat_line$MaxDate, by = "day")
    req_days <- seq(date_start, date_end, by = "day")
    days_overlap <- req_days[req_days %in% cat_days]
    if (length(days_overlap) == 0L) {
      stop("No monthly data available for the specified date range.")
    }
    dates_overlap <- seq(min(days_overlap), max(days_overlap), by = "month")
  } else if (!is.null(months_pad)) {
    ## M3: months across all catalog years
    dates_overlap <- cat_months[cat_months_char %in% months_pad]
  } else {
    ## M4: no time args — all catalog months
    dates_overlap <- cat_months
  }

  ## Behavior change note: the old M1/M3 branches did not emit stop() on
  ## empty overlap; they silently produced a 0-layer raster_path leading to
  ## a terra::rast() error further down. We now fail early with a clear
  ## message. Called out in the refactor commit.
  if (length(dates_overlap) == 0L) {
    stop("No monthly data available for the specified filters.")
  }

  months_overlap <- format(dates_overlap, "%m")
  years_overlap  <- format(dates_overlap, "%Y")
  paths <- .substitute_template(template, year = years_overlap, month = months_overlap)
  layer_names <- format(dates_overlap, format = "%Y-%m")
  if (verbose) {
    message(paste("Returning monthly dataset with", length(paths), "layers..."))
  }
  list(paths = paths, names = layer_names)
}

## Daily: two sub-cases matching the old D1/D2 branches. The no-time-args
## case silently clips to the first 30 days — this is an intentional
## behavior preserved from the old code (with its "returning the first 30
## layers" message) because callers who load a multi-decade daily dataset
## without time bounds would otherwise build thousands of VSICURL handles.
.resolve_daily <- function(cat_line, date_start, date_end, verbose) {
  template <- paste0(.SDP_VSICURL_PREFIX, cat_line$Data.URL)

  if (!is.null(date_start) && !is.null(date_end)) {
    ## D1: date range
    cat_days <- seq(cat_line$MinDate, cat_line$MaxDate, by = "day")
    days_input <- seq(date_start, date_end, by = "day")
    days_overlap <- days_input[days_input %in% cat_days]
    if (length(days_overlap) == 0L) {
      stop(paste("No data available for any requested days. Available days are",
                 min(cat_days), "to", max(cat_days)))
    } else if (length(days_overlap) < length(days_input)) {
      warning(paste("No data available for some requested days. \n Returning data for",
                    min(days_overlap), "to", max(days_overlap)))
    }
    if (verbose) {
      message(paste("Returning daily dataset with", length(days_overlap), "layers..."))
    }
  } else {
    ## D2: no time args — clip to the first 30 days
    days_overlap <- seq(cat_line$MinDate, cat_line$MaxDate, by = "day")[1:30]
    if (verbose) {
      message("No time bounds set for daily data, returning the first 30 layers. Specify `date_start` or `date_end` to retrieve larger daily time-series...")
    }
  }

  years_overlap <- format(days_overlap, format = "%Y")
  doys_overlap  <- format(days_overlap, format = "%j")
  paths <- .substitute_template(template, year = years_overlap, day = doys_overlap)
  layer_names <- format(days_overlap, format = "%Y-%m-%d")
  list(paths = paths, names = layer_names)
}

## Weekly/irregular: resolves dates from a baked manifest (offline) or
## STAC traversal (online), filters to the requested subset, and returns
## one path per date. Sets is_imagery=TRUE to signal the orchestrator
## to load as a list of SpatRasters instead of stacking.
.resolve_weekly <- function(cat_line, dates, date_start, date_end, verbose) {
  template <- paste0(.SDP_VSICURL_PREFIX, cat_line$Data.URL)

  ## Get available dates from baked manifest.
  manifests <- get0("SDP_manifests", envir = asNamespace("rSDP"))
  all_dates <- if (!is.null(manifests)) manifests[[cat_line$CatalogID]] else NULL

  if (is.null(all_dates) || length(all_dates) == 0L) {
    stop(sprintf(
      "No date manifest found for '%s'. Run scripts/update_catalog.sh to regenerate manifests, or use sdp_get_dates() with source='stac'.",
      cat_line$CatalogID
    ))
  }

  ## Filter to requested dates.
  if (!is.null(dates)) {
    missing <- dates[!dates %in% all_dates]
    if (length(missing) > 0L) {
      warning(sprintf("No data for %d of %d requested dates. Available range: %s to %s.",
                      length(missing), length(dates), min(all_dates), max(all_dates)))
    }
    selected <- sort(dates[dates %in% all_dates])
    if (length(selected) == 0L) {
      stop(sprintf("None of the requested dates are available. Available range: %s to %s.",
                   min(all_dates), max(all_dates)))
    }
  } else if (!is.null(date_start) && !is.null(date_end)) {
    selected <- all_dates[all_dates >= date_start & all_dates <= date_end]
    if (length(selected) == 0L) {
      stop(sprintf("No data available between %s and %s. Available range: %s to %s.",
                   date_start, date_end, min(all_dates), max(all_dates)))
    }
  } else {
    selected <- all_dates
  }

  ## Resolve each date to a URL.
  years_v  <- as.character(format(selected, "%Y"))
  months_v <- format(selected, "%m")
  days_v   <- format(selected, "%d")
  paths <- .substitute_template(template,
                                year = years_v,
                                month = months_v,
                                calendarday = days_v)
  layer_names <- format(selected, "%Y-%m-%d")

  if (verbose) {
    message(sprintf("Returning %d dates for weekly dataset.", length(selected)))
  }

  ## is_imagery is determined by the catalog Type field, not the
  ## TimeSeriesType. Products with Type="Imagery" have varying extents
  ## per time step and must be loaded individually. Future irregular
  ## time-series on a consistent grid (e.g., weekly snow products)
  ## will have Type != "Imagery" and stack normally.
  list(paths = paths, names = layer_names,
       is_imagery = (cat_line$Type == "Imagery"))
}


## Filter an already-loaded SpatRaster by a `years` or `date_start`/
## `date_end` range, preserving the error-on-empty / warn-on-partial
## semantics. Used by sdp_extract_data(). This is a different beast from
## .resolve_time_slices() (which operates on a catalog entry and builds
## paths), so the logic is similar in spirit but not shared.
.filter_raster_layers_by_time <- function(raster, years, date_start, date_end, verbose = TRUE) {
  if (!is.null(years)) {
    years_overlap <- years[years %in% as.numeric(names(raster))]
    if (length(years_overlap) == 0L) {
      stop(paste("No raster layers match any specified years. Available years are",
                 paste(names(raster), collapse = " ")))
    } else if (length(years_overlap) < length(years) && verbose) {
      warning(paste("No layer matches some specified years. \n Returning data for",
                    paste(years_overlap, collapse = " ")))
    }
    return(raster[[as.character(years_overlap)]])
  }
  if (!is.null(date_start) && !is.null(date_end)) {
    day_seq <- seq(date_start, date_end, by = "day")
    rast_days <- as.Date(names(raster))
    days_overlap <- day_seq[day_seq %in% rast_days]
    if (length(days_overlap) == 0L) {
      stop(paste("No raster layers match any specified dates. Available dates are",
                 paste(names(raster), collapse = " ")))
    } else if (length(days_overlap) < length(day_seq) && verbose) {
      warning(paste("No layer matches some specified days. \n Returning data for",
                    paste(days_overlap, collapse = " ")))
    }
    return(raster[[as.character(days_overlap)]])
  }
  raster
}
