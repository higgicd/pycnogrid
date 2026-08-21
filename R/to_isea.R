#' Pycnophylactic interpolation to an ISEA grid
#'
#' Interpolates polygon counts to an ISEA discrete global grid while preserving
#' source-zone totals when used with default centroid-based allocation.
#'
#' @details
#' ISEA grids are equal-area hierarchical discrete global grid systems based on
#' the Icosahedral Snyder Equal Area projection. The `aperture` determines the
#' refinement factor between successive resolutions: aperture 3, 4, or 7.
#'
#' Calls [to_grid()] with `grid_type` set to `"isea3h"` or `"isea4h"`
#' according to `aperture`.
#'
#' @inheritParams to_grid
#' @param resolution ISEA resolution level. Higher values produce smaller cells
#'   and substantially more output polygons.
#' @param aperture ISEA aperture: one of `3` or `4`.
#' @param ... Additional arguments passed to [to_grid()].
#'
#' @return An `sf` object containing ISEA cells and interpolated values.
#'
#' @examples
#' out <- to_isea(
#'   source = nyc_ct_small,
#'   value_col = populationE,
#'   resolution = 19,
#'   aperture = 3,
#'   max_iter = 5
#' )
#'
#' out <- to_isea(
#'   source = nyc_ct_small,
#'   value_col = populationE,
#'   resolution = 15,
#'   aperture = 4,
#'   max_iter = 5
#' )
#'
#' @export
to_isea <- function(source,
                    value_col,
                    resolution,
                    aperture = c(3, 4),
                    ...) {

  aperture <- match.arg(
    as.character(aperture),
    choices = c("3", "4")
  )

  to_grid(
    source = source,
    value_col = {{ value_col }},
    grid_type = paste0("isea", aperture, "h"),
    resolution = resolution,
    ...
  )
}
