#' Pycnophylactic interpolation to an A5 grid
#'
#' Interpolates polygon counts to an A5 grid while preserving source-zone
#' totals.
#'
#' @details
#' A5 is a hierarchical global discrete grid system in which each increase in
#' resolution subdivides cells by a factor of five. Consequently, the number
#' of cells grows exponentially with resolution and very high resolutions may
#' be impractical for pycnophylactic interpolation.
#'
#' Calls [to_grid()] with `grid_type = "a5"`.
#'
#' @inheritParams to_grid
#' @param resolution A5 resolution level (0--30). Higher values produce smaller cells
#'   and many more output polygons. For typical urban analyses, values around
#'   8--16 are usually more practical.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing A5 cells and interpolated values.
#' @export
to_a5 <- function(source,
                  value_col,
                  resolution,
                  ...) {

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = "a5",
    resolution = resolution,
    ...
  )
}
