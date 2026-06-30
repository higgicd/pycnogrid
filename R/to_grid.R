#' Pycnophylactic interpolation to a grid
#'
#' Interpolates polygon counts to a regular or global discrete grid while
#' preserving source-zone totals.
#'
#' @param source An `sf` polygon object.
#' @param value_col Column containing the values to interpolate. May be
#'   supplied as an unquoted column name or a character string.
#' @param id_col Optional unique identifier column for source polygons.
#' @param grid_type Grid system to interpolate to. One of `"h3"`, `"a5"`,
#'   `"s2"`, `"isea3h"`, `"isea4h"`, `"isea7h"`, `"isea43h"`,  or `"raster"`.
#' @param resolution Grid resolution. For H3, A5, S2, and ISEA grids this is the grid
#'   level. For raster grids this is the cell size in metres.
#' @param cell_inclusion Method used to determine which grid cells are included.
#'   One of `"intersect"` or `"centroid"`.
#' @param cell_allocation Method used to allocate source values to grid cells.
#'   One of `"area"` or `"centroid"`.
#' @param nb_order Neighbourhood order used for smoothing. A value of `1` uses
#'   first-order neighbours; larger values include higher-order neighbours.
#' @param max_iter Maximum number of pycnophylactic smoothing iterations. If
#'   `0`, returns the initial allocation without smoothing.
#' @param tolerance Convergence tolerance based on relative mean density change.
#' @param include_self Logical. Should each cell include itself when smoothing?
#' @param missing_policy How to handle source polygons that receive no grid
#'   cells. One of `"abort"`, `"warn"`, or `"ignore"`.
#'
#' @return An `sf` object containing grid-cell geometries and interpolated
#'   values.
#' @export
to_grid <- function(source,
                    value_col,
                    id_col = NULL,
                    grid_type = c("h3", "a5", "s2", "raster", "isea3h", "isea4h", "isea7h", "isea43h"),
                    resolution,
                    cell_inclusion = c("intersect", "centroid"),
                    cell_allocation = c("area", "centroid"),
                    nb_order = 1,
                    max_iter = 500,
                    tolerance = 1e-4,
                    include_self = TRUE,
                    missing_policy = c("abort", "warn", "ignore")) {
  # ---------------------------------------------------------------------------
  # 0. Check inputs and prepare source data
  # ---------------------------------------------------------------------------

  checked <- validate_source(source, {{ value_col }}, {{ id_col }})

  source <- checked$source
  value_col <- checked$value_col
  id_col <- checked$id_col
  out_name <- checked$out_name

  args <- validate_grid_args(
    grid_type = grid_type,
    resolution = resolution,
    cell_inclusion = cell_inclusion,
    cell_allocation = cell_allocation,
    nb_order = nb_order,
    max_iter = max_iter,
    tolerance = tolerance,
    include_self = include_self,
    missing_policy = missing_policy
  )

  grid_type <- args$grid_type
  resolution <- args$resolution
  cell_inclusion <- args$cell_inclusion
  cell_allocation <- args$cell_allocation
  nb_order <- args$nb_order
  max_iter <- args$max_iter
  tolerance <- args$tolerance
  include_self <- args$include_self
  missing_policy <- args$missing_policy

  if (grid_type == "h3") {
    rlang::check_installed("h3o")
  } else if (grid_type == "a5") {
    rlang::check_installed("a5R")
  } else if (grid_type == "s2") {
    rlang::check_installed("s2")
  } else if (grid_type == "raster") {
    rlang::check_installed("terra")
  } else if (grepl("^isea", grid_type)) {
    rlang::check_installed("hexify")
  }

  prepped <- prep_source(source, value_col, id_col)

  source_polys <- prepped$source
  source_values <- prepped$source_values
  input_total_original <- prepped$input_total_original
  input_total_represented <- prepped$input_total_represented

  # ---------------------------------------------------------------------------
  # 1. Generate target cells
  # ---------------------------------------------------------------------------

  target_cells <- prepare_target_cells(
    source_polys = source_polys,
    grid_type = grid_type,
    resolution = resolution,
    cell_inclusion = cell_inclusion
  )

  n_target <- nrow(target_cells)

  if (n_target == 0) {
    rlang::abort("No grid cells were generated. Try a finer `resolution` or check the input geometry.")
  }

  # ---------------------------------------------------------------------------
  # 2. Associate source values with target cells
  # ---------------------------------------------------------------------------

  source_cell_weights <- prepare_source_cell_weights(
    source_polys = source_polys,
    source_values = source_values,
    target_cells = target_cells,
    grid_type = grid_type,
    resolution = resolution,
    cell_allocation = cell_allocation,
    missing_policy = missing_policy,
    input_total_original = input_total_original
  )

  source_values <- source_cell_weights$source_values
  input_total_represented <- source_cell_weights$input_total_represented
  source_index <- source_cell_weights$source_index
  A_matrix <- source_cell_weights$A_matrix
  W_matrix <- source_cell_weights$W_matrix
  V_matrix <- source_cell_weights$V_matrix
  cell_area <- source_cell_weights$cell_area
  cell_area_inside_source <- source_cell_weights$cell_area_inside_source
  cell_coverage_fraction <- source_cell_weights$cell_coverage_fraction
  y <- source_cell_weights$y
  x <- source_cell_weights$x
  density <- source_cell_weights$density

  # ---------------------------------------------------------------------------
  # 3. Return unsmoothed areal allocation, if requested
  # ---------------------------------------------------------------------------

  if (max_iter == 0) {
    out <- finalize_pycno_output(
      target_cells = target_cells,
      source = source,
      density = density,
      cell_area_inside_source = cell_area_inside_source,
      cell_coverage_fraction = cell_coverage_fraction,
      y = y,
      out_name = out_name,
      iter_used = 0,
      relative_mean_change = NA_real_,
      grid_type = grid_type,
      resolution = resolution,
      tolerance = tolerance,
      input_total_original = input_total_original,
      input_total_represented = input_total_represented
    )

    return(out)
  }

  # ---------------------------------------------------------------------------
  # 4. Build smoothing matrix
  # ---------------------------------------------------------------------------

  S_matrix <- build_smoothing_matrix(
    target_cells = target_cells,
    nb_order = nb_order,
    include_self = include_self
  )

  # ---------------------------------------------------------------------------
  # 5. Smooth densities and restore source totals
  # ---------------------------------------------------------------------------

  last_error <- Inf
  iter_used <- 0

  for (iter in seq_len(max_iter)) {
    iter_used <- iter
    density_before <- density

    density <- as.numeric(S_matrix %*% density)
    density[!is.finite(density)] <- 0
    density[density < 0] <- 0

    source_est <- as.numeric(A_matrix %*% density)

    zero_est <- which(y > 0 & (source_est <= 0 | is.na(source_est)))

    if (length(zero_est) > 0) {
      rlang::abort(
        paste0(
          length(zero_est),
          " source polygon(s) have positive input mass but zero estimated mass ",
          "during correction. The pycnophylactic correction cannot be computed."
        )
      )
    }

    ratio <- y / source_est
    ratio[!is.finite(ratio)] <- 1

    correction <- as.numeric(Matrix::t(V_matrix) %*% ratio)
    correction[!is.finite(correction)] <- 1

    density <- density * correction

    abs_change <- abs(density - density_before)
    denom <- pmax(abs(density_before), 1e-12)
    last_error <- mean(abs_change / denom, na.rm = TRUE)

    if (last_error <= tolerance) {
      break
    }
  }

  if (last_error > tolerance) {
    rlang::warn(
      paste0(
        "Pycnophylactic smoothing did not converge within `max_iter = ",
        max_iter,
        "`. Final relative mean change was ",
        signif(last_error, 4),
        "."
      )
    )
  }

  # ---------------------------------------------------------------------------
  # 6. Check mass preservation and return output
  # ---------------------------------------------------------------------------

  finalize_pycno_output(
    target_cells = target_cells,
    source = source,
    density = density,
    cell_area_inside_source = cell_area_inside_source,
    cell_coverage_fraction = cell_coverage_fraction,
    y = y,
    out_name = out_name,
    iter_used = iter_used,
    relative_mean_change = last_error,
    grid_type = grid_type,
    resolution = resolution,
    tolerance = tolerance,
    input_total_original = input_total_original,
    input_total_represented = input_total_represented
  )
}
