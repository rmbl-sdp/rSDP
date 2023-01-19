#' Replace Multiple Strings in a Vector
#'
#' @param x vector with strings to replace
#' @param y vector with strings to use instead
#' @param vec initial character vector
#' @param ... arguments passed to `gsub`
#'
#'
replace_strngs <- function(x, y, vec, ...) {
  # iterate over strings
  vapply(X = vec,
         FUN.VALUE = character(1),
         USE.NAMES = FALSE,
         FUN = function(x_string) {
           # iterate over replacements
           Reduce(
             f = function(s, x) {
               gsub(pattern = x[1],
                    replacement = x[2],
                    x = s,
                    ...)
             },
             x = Map(f = base::c, x, y),
             init = x_string)
         })
}

