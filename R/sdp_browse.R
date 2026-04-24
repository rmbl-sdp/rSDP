#' Browse SDP data products as a visual thumbnail grid.
#'
#' Renders an HTML grid of data product cards showing thumbnails,
#' product names, key metadata, SDP Browser links, and copyable
#' `sdp_get_raster()` snippets. The output displays in the
#' RStudio/Positron Viewer pane or in a web browser.
#'
#' The HTML uses only element attributes (no inline `style`, no
#' JavaScript) for maximum compatibility across RStudio, Positron,
#' Quarto, and R Markdown.
#'
#' @param domains The spatial domain(s) to include.
#' @param types The type(s) of products to include.
#' @param releases Which release(s) to include.
#' @param timeseries_types Which time-series types to include.
#' @param deprecated Logical. Should deprecated datasets be included?
#' @param columns Integer. Number of columns in the grid (default 4).
#' @param width Integer. Card width in pixels (default 220).
#' @param max_products Integer or NULL. Cap the number of products shown.
#'   `NULL` (default) shows all matches.
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
#' ## Show only the first 8 products in a 2-column grid
#' sdp_browse(types = "Topo", columns = 2, max_products = 8)
#' }
sdp_browse <- function(domains = .SDP_DOMAINS,
                       types = .SDP_TYPES,
                       releases = .SDP_RELEASES,
                       timeseries_types = .SDP_TIMESERIES_TYPES,
                       deprecated = FALSE,
                       columns = 4L,
                       width = 220L,
                       max_products = NULL) {

  rlang::check_installed("htmltools", reason = "to render the browse grid")

  cat <- sdp_get_catalog(
    domains = domains,
    types = types,
    releases = releases,
    timeseries_types = timeseries_types,
    deprecated = deprecated
  )

  if (!is.null(max_products)) {
    cat <- utils::head(cat, max_products)
  }

  if (nrow(cat) == 0) {
    return(htmltools::browsable(htmltools::HTML(
      "<p><b>No products match the specified filters.</b></p>"
    )))
  }

  cat$ThumbnailURL <- .derive_thumbnail_url(cat$Data.URL, cat$TimeSeriesType)

  title <- .build_filter_summary_title(nrow(cat), domains, types)

  cards <- lapply(seq_len(nrow(cat)), function(i) {
    .build_card(cat[i, ], width)
  })

  ## Build table rows, filling incomplete rows with empty cells.
  rows_html <- list()
  for (i in seq(1, length(cards), by = columns)) {
    chunk <- cards[i:min(i + columns - 1, length(cards))]
    ## Pad with empty cells if the last row is incomplete.
    while (length(chunk) < columns) {
      chunk <- c(chunk, list(htmltools::tags$td(width = width)))
    }
    rows_html <- c(rows_html, list(htmltools::tags$tr(chunk)))
  }

  grid <- htmltools::tags$table(
    cellpadding = "8",
    cellspacing = "6",
    rows_html
  )

  page <- htmltools::tagList(
    htmltools::tags$p(htmltools::tags$b(title)),
    grid
  )

  htmltools::browsable(page)
}

.SDP_BROWSER_BASE <- "https://sdpbrowser.org/"

## Derive thumbnail URLs from Data.URL and TimeSeriesType (vectorized).
.derive_thumbnail_url <- function(data_urls, ts_types) {
  vapply(seq_along(data_urls), function(i) {
    url <- data_urls[i]
    if (is.na(url) || url == "") return("")
    if (ts_types[i] == "Single") {
      return(sub("\\.tif$", "_thumbnail.png", url))
    }
    dir_url <- sub("/[^/]+$", "", url)
    parent <- sub("/[^/]+$", "", dir_url)
    stem <- sub("^.*/", "", dir_url)
    paste0(parent, "/", stem, "_thumbnail.png")
  }, character(1))
}


## Build a single card using only HTML attributes (no inline style).
.build_card <- function(row, width) {
  cat_id <- as.character(row$CatalogID)
  product <- as.character(row$Product)
  domain <- as.character(row$Domain)
  resolution <- if (!is.na(row$Resolution)) as.character(row$Resolution) else ""
  ts_type <- as.character(row$TimeSeriesType)
  thumb_url <- row$ThumbnailURL
  browser_url <- paste0(.SDP_BROWSER_BASE, "#add=", utils::URLencode(cat_id, reserved = TRUE))
  code_snippet <- sprintf('sdp_get_raster("%s")', cat_id)

  meta_parts <- c(domain, resolution, ts_type)
  meta_parts <- meta_parts[meta_parts != ""]
  meta_line <- paste(meta_parts, collapse = " \u00b7 ")

  htmltools::tags$td(
    width = width,
    valign = "top",
    bgcolor = "#f8f8f8",
    htmltools::tags$img(
      src = thumb_url,
      width = width - 10,
      alt = cat_id,
      loading = "lazy"
    ),
    htmltools::tags$br(),
    htmltools::tags$b(cat_id),
    htmltools::tags$br(),
    product,
    htmltools::tags$br(),
    htmltools::tags$small(meta_line),
    htmltools::tags$br(),
    htmltools::tags$a(
      href = browser_url,
      target = "_blank",
      "SDP Browser \u2197"
    ),
    htmltools::tags$br(),
    htmltools::tags$code(code_snippet)
  )
}


## Build the title line with product count and active filters.
.build_filter_summary_title <- function(n, domains, types) {
  title <- sprintf("%d product%s", n, ifelse(n == 1, "", "s"))
  filters <- character(0)
  if (!identical(domains, .SDP_DOMAINS)) {
    filters <- c(filters, paste0("domains=", paste(domains, collapse = ", ")))
  }
  if (!identical(types, .SDP_TYPES)) {
    filters <- c(filters, paste0("types=", paste(types, collapse = ", ")))
  }
  if (length(filters) > 0) {
    title <- paste0(title, " \u2014 ", paste(filters, collapse = ", "))
  }
  title
}
