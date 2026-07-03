#' Pycnophylactic interpolation to a local hexagonal grid
#'
#' Interpolates polygon counts to a local hexagonal grid while preserving
#' source-zone totals.
#'
#' @details
#' Hex grids divide the study area into hexagonal cells of a fixed size. Smaller cell sizes produce
#' more output cells and may substantially increase computation time.
#'
#' @inheritParams to_grid
#' @param resolution Hexagonal cell size specified in the linear units of the input projected CRS.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing hexagonal grid-cell polygons and
#'   interpolated values.
#'
#' @examples
#' out <- to_hex(
#'   source = nyc_ct_small,
#'   value_col = populationE,
#'   resolution = 500,
#'   max_iter = 5
#' )
#'
#' @export
to_hex <- function(source,
                      value_col,
                      resolution,
                      ...) {

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = "hex",
    resolution = resolution,
    ...
  )
}
