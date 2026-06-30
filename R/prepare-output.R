finalize_pycno_output <- function(target_cells,
                                  source,
                                  density,
                                  cell_area_inside_source,
                                  cell_coverage_fraction,
                                  y,
                                  out_name,
                                  iter_used,
                                  relative_mean_change,
                                  grid_type = NULL,
                                  resolution = NULL,
                                  tolerance,
                                  input_total_original,
                                  input_total_represented) {

  input_total <- sum(y, na.rm = TRUE)
  output_total <- sum(density * cell_area_inside_source, na.rm = TRUE)

  mass_error <- abs(output_total - input_total)
  mass_relative_error <- mass_error / max(
    abs(input_total),
    .Machine$double.eps,
    na.rm = TRUE
  )

  if (mass_relative_error > tolerance) {
    rlang::warn(
      paste0(
        "Output total differs from input total. ",
        "Relative mass error: ",
        signif(mass_relative_error, 4),
        "."
      )
    )
  }

  out <- target_cells |>
    sf::st_transform(sf::st_crs(source)) |>
    dplyr::mutate(
      !!out_name := as.numeric(density * cell_area_inside_source),
      pycno_density = as.numeric(density),
      pycno_coverage = as.numeric(cell_coverage_fraction),
      pycno_iter = iter_used
    )

  out <- add_pycno_attrs(
    out = out,
    iterations = iter_used,
    relative_mean_change = relative_mean_change,
    grid_type = grid_type,
    resolution = resolution,
    input_total_original = input_total_original,
    input_total_represented = input_total_represented
  )

  out
}
