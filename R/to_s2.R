#' Pycnophylactic interpolation to an S2 grid
#'
#' Interpolates polygon counts to an S2 grid while preserving source-zone
#' totals.
#'
#' @details
#' S2 is a hierarchical global discrete grid system based on recursively
#' subdividing the six faces of a cube projected onto the sphere. Higher cell
#' levels produce smaller cells and a larger number of output cells. Very high
#' levels may be impractical for pycnophylactic interpolation over large study
#' areas.
#'
#' Calls [to_grid()] with `grid_type = "s2"`.
#'
#' @inheritParams to_grid
#' @param resolution S2 resolution level (0--30). Higher values produce smaller cells
#'   and many more output polygons. For typical urban analyses, values around
#'   8--16 are usually more practical.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing S2 cells and interpolated values.
#' @export
to_s2 <- function(source,
                  value_col,
                  resolution,
                  ...) {

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = "s2",
    resolution = resolution,
    ...
  )
}
