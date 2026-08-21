#' Pycnophylactic interpolation to a raster grid
#'
#' Interpolates polygon counts to a regular raster grid while preserving
#' source-zone totals when used with default centroid-based allocation.
#'
#' @details
#' Raster grids divide the study area into regular cells of a fixed size. In
#' `pycnogrid`, interpolation is performed using a raster grid, but results are
#' returned as polygon grid cells in an `sf` object. Smaller cell sizes produce
#' more output cells and may substantially increase computation time.
#'
#' @inheritParams to_grid
#' @param resolution Raster cell size specified in the linear units of the input projected CRS.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing raster grid-cell polygons and
#'   interpolated values.
#'
#' @examples
#' out <- to_raster(
#'   source = nyc_ct_small,
#'   value_col = populationE,
#'   resolution = 250,
#'   max_iter = 5
#' )
#'
#' @export
to_raster <- function(source,
                  value_col,
                  resolution,
                  ...) {

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = "raster",
    resolution = resolution,
    ...
  )
}
