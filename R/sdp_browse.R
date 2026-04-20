#' Browse SDP data products as a visual thumbnail grid.
#'
#' Renders an interactive HTML grid of data product cards showing
#' thumbnails, product names, and key metadata. The output displays
#' in the RStudio/Positron Viewer pane or in a web browser.
#'
#' @param domains The spatial domain(s) to include.
#' @param types The type(s) of products to include.
#' @param releases Which release(s) to include.
#' @param timeseries_types Which time-series types to include.
#' @param deprecated Logical. Should deprecated datasets be included?
#' @param columns Integer. Number of columns in the grid (default 4).
#' @param width Integer. Minimum card width in pixels (default 220).
#'
#' @return A `browsable` HTML object (displays in the Viewer pane when
#'   printed interactively, or can be saved with `htmltools::save_html()`).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' ## Browse all current vegetation products
#' sdp_browse(types = "Vegetation")
#'
#' ## Browse the new GMUG domain
#' sdp_browse(domains = "GMUG")
#'
#' ## Narrow to topo products at 3m resolution
#' sdp_browse(types = "Topo", domains = "GMUG")
#' }
sdp_browse <- function(domains = .SDP_DOMAINS,
                       types = .SDP_TYPES,
                       releases = .SDP_RELEASES,
                       timeseries_types = .SDP_TIMESERIES_TYPES,
                       deprecated = FALSE,
                       columns = 4L,
                       width = 220L) {

  rlang::check_installed("htmltools", reason = "to render the browse grid")

  cat <- sdp_get_catalog(
    domains = domains,
    types = types,
    releases = releases,
    timeseries_types = timeseries_types,
    deprecated = deprecated
  )

  if (nrow(cat) == 0) {
    return(htmltools::browsable(htmltools::HTML(
      "<p style='font-family: sans-serif; color: #666;'>No products match the specified filters.</p>"
    )))
  }

  cat$ThumbnailURL <- .derive_thumbnail_url(cat$Data.URL, cat$TimeSeriesType)

  subtitle <- .build_filter_summary(domains, types, releases, timeseries_types, deprecated)

  cards <- lapply(seq_len(nrow(cat)), function(i) {
    .build_card(cat[i, ], width)
  })

  max_width <- columns * (width + 20)

  grid <- htmltools::div(
    style = sprintf(
      "display:grid; grid-template-columns:repeat(%d, minmax(%dpx, 1fr)); gap:10px; max-width:%dpx; margin:auto;",
      columns, width, max_width
    ),
    cards
  )

  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$style(htmltools::HTML("
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
               background: #f5f5f5; padding: 20px; margin: 0; }
      "))
    ),
    htmltools::div(
      style = "max-width: 1200px; margin: auto; padding-bottom: 20px;",
      htmltools::h3(
        style = "margin: 0 0 4px 0; color: #333;",
        sprintf("%d product%s", nrow(cat), ifelse(nrow(cat) == 1, "", "s"))
      ),
      htmltools::p(
        style = "margin: 0 0 16px 0; color: #666; font-size: 13px;",
        subtitle
      )
    ),
    grid
  )

  htmltools::browsable(
    htmltools::tagList(
      htmltools::tags$html(
        htmltools::tags$body(page)
      )
    )
  )
}


## Derive thumbnail URLs from Data.URL and TimeSeriesType (vectorized).
.derive_thumbnail_url <- function(data_urls, ts_types) {
  vapply(seq_along(data_urls), function(i) {
    url <- data_urls[i]
    if (is.na(url) || url == "") return("")
    if (ts_types[i] == "Single") {
      return(sub("\\.tif$", "_thumbnail.png", url))
    }
    # Time-series: URL has template in filename, thumbnail is at directory level
    dir_url <- sub("/[^/]+$", "", url)
    parent <- sub("/[^/]+$", "", dir_url)
    stem <- sub("^.*/", "", dir_url)
    paste0(parent, "/", stem, "_thumbnail.png")
  }, character(1))
}


## Build a single card's HTML.
.build_card <- function(row, width) {
  thumb_url <- row$ThumbnailURL
  catalog_id <- row$CatalogID
  product <- row$Product
  domain <- row$Domain
  resolution <- if (!is.na(row$Resolution)) row$Resolution else ""
  ts_type <- row$TimeSeriesType

  meta_line <- paste(
    c(domain, resolution, ts_type)[c(domain, resolution, ts_type) != ""],
    collapse = " \u00b7 "
  )

  htmltools::div(
    style = "position:relative; border-radius:8px; overflow:hidden; background:#1a1a2e; min-height:160px;",
    htmltools::tags$img(
      src = thumb_url,
      alt = catalog_id,
      loading = "lazy",
      style = "width:100%; display:block; min-height:140px; object-fit:cover;",
      onerror = "this.style.display='none'"
    ),
    htmltools::div(
      style = paste0(
        "position:absolute; bottom:0; left:0; right:0; ",
        "background:linear-gradient(transparent 0%, rgba(0,0,0,0.85) 60%); ",
        "padding:28px 10px 8px 10px; color:white;"
      ),
      htmltools::div(
        style = "font-size:11px; opacity:0.7; letter-spacing:0.5px;",
        catalog_id
      ),
      htmltools::div(
        style = "font-weight:600; font-size:13px; line-height:1.3; margin:2px 0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;",
        title = product,
        product
      ),
      htmltools::div(
        style = "font-size:11px; opacity:0.75;",
        meta_line
      )
    )
  )
}


## Build a human-readable filter summary string.
.build_filter_summary <- function(domains, types, releases, timeseries_types, deprecated) {
  parts <- character(0)
  if (!identical(domains, .SDP_DOMAINS)) {
    parts <- c(parts, paste0("domains: ", paste(domains, collapse = ", ")))
  }
  if (!identical(types, .SDP_TYPES)) {
    parts <- c(parts, paste0("types: ", paste(types, collapse = ", ")))
  }
  if (!identical(releases, .SDP_RELEASES)) {
    parts <- c(parts, paste0("releases: ", paste(releases, collapse = ", ")))
  }
  if (!identical(timeseries_types, .SDP_TIMESERIES_TYPES)) {
    parts <- c(parts, paste0("timeseries: ", paste(timeseries_types, collapse = ", ")))
  }
  if (isTRUE(deprecated)) {
    parts <- c(parts, "including deprecated")
  }
  if (length(parts) == 0) return("All current datasets")
  paste(parts, collapse = " | ")
}
