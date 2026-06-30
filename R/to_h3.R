#' Pycnophylactic interpolation to an H3 grid
#'
#' Interpolates polygon counts to an H3 grid while preserving source-zone
#' totals.
#'
#' @details
#' H3 is a hierarchical global discrete grid system composed primarily of
#' hexagonal cells. Higher resolution levels produce smaller cells and a larger
#' number of output cells. H3 resolutions range from 0 to 15, but high
#' resolutions may be impractical for large study areas.
#'
#' Calls [to_grid()] with `grid_type = "h3"`.
#'
#' @inheritParams to_grid
#' @param resolution A5 resolution level (0--15). Higher values produce smaller cells
#'   and many more output polygons. For typical urban analyses, values around
#'   9--12 are usually more practical.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing H3 cells and interpolated values.
#' @export
to_h3 <- function(source,
                  value_col,
                  resolution,
                  ...) {

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = "h3",
    resolution = resolution,
    ...
  )
}
