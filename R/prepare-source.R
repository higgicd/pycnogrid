validate_source <- function(source, value_col, id_col = NULL) {
  value_col <- rlang::as_name(rlang::ensym(value_col))

  if (!inherits(source, "sf")) {
    rlang::abort("`source` must be an sf object.")
  }

  if (!value_col %in% names(source)) {
    rlang::abort(paste0("`", value_col, "` was not found in `source`."))
  }

  if (!is.numeric(source[[value_col]])) {
    rlang::abort("`value_col` must be numeric.")
  }

  if (anyNA(source[[value_col]])) {
    rlang::abort("`value_col` cannot contain missing values.")
  }

  if (any(source[[value_col]] < 0, na.rm = TRUE)) {
    rlang::abort("`value_col` must be non-negative.")
  }

  if (sum(source[[value_col]], na.rm = TRUE) == 0) {
    rlang::warn("The total value in `value_col` is zero. Output values will all be zero.")
  }

  # check if projected
  if (sf::st_is_longlat(source)) {
    rlang::abort(
      "`source` must use a projected CRS. Transform it before calling `pycno_interpolate()`."
    )
  }

  if (!all(sf::st_is_valid(source))) {
    bad <- which(!sf::st_is_valid(source))
    rlang::abort(
      paste0(
        "`source` contains invalid geometries. ",
        "Please repair them before interpolation. ",
        "Invalid row(s): ", paste(utils::head(bad, 10), collapse = ", "),
        if (length(bad) > 10) " ..." else ""
      )
    )
  }

  if (any(sf::st_is_empty(source))) {
    bad <- which(sf::st_is_empty(source))
    rlang::abort(
      paste0(
        "`source` contains empty geometries. ",
        "Empty row(s): ", paste(utils::head(bad, 10), collapse = ", "),
        if (length(bad) > 10) " ..." else ""
      )
    )
  }

  geom_type <- unique(as.character(sf::st_geometry_type(source)))

  if (!all(geom_type %in% c("POLYGON", "MULTIPOLYGON"))) {
    rlang::abort("`source` must contain only POLYGON or MULTIPOLYGON geometries.")
  }

  if (is.na(sf::st_crs(source))) {
    rlang::abort("`source` must have a valid CRS.")
  }

  id_col_quo <- rlang::enquo(id_col)

  if (!rlang::quo_is_null(id_col_quo)) {
    id_col <- rlang::as_name(rlang::ensym(id_col))

    if (!id_col %in% names(source)) {
      rlang::abort(paste0("`", id_col, "` was not found in `source`."))
    }

    if (anyNA(source[[id_col]])) {
      rlang::abort("`id_col` cannot contain missing values.")
    }

    if (anyDuplicated(source[[id_col]]) > 0) {
      rlang::abort("`id_col` must uniquely identify rows in `source`.")
    }
  } else {
    source$.source_id <- seq_len(nrow(source))
    id_col <- ".source_id"
  }

  list(
    source = source,
    value_col = value_col,
    id_col = id_col,
    out_name = paste0("pycno_", value_col)
  )
}

validate_grid_args <- function(grid_type = NULL,
                               resolution,
                               cell_inclusion,
                               cell_allocation,
                               #output_type = NULL,
                               #output_choices = NULL,
                               nb_order = NULL,
                               max_iter,
                               tolerance,
                               include_self,
                               missing_policy = NULL) {
  if (!is.null(grid_type)) {
    grid_type <- match.arg(grid_type, c("h3", "a5", "s2", "raster", "isea3h", "isea4h", "isea7h", "isea43h"))
  }

  if (!is.null(cell_inclusion)) {
    cell_inclusion <- match.arg(
      cell_inclusion,
      c("intersect", "centroid")
    )
  }

  if (!is.null(cell_allocation)) {
    cell_allocation <- match.arg(
      cell_allocation,
      c("area", "centroid")
    )
  }

  #if (!is.null(output_type)) {
  #  if (is.null(output_choices)) {
  #    output_type <- match.arg(output_type)
  #  } else {
  #    output_type <- match.arg(output_type, output_choices)
  #  }
  #}

  if (!is.null(missing_policy)) {
    missing_policy <- match.arg(missing_policy, c("abort", "warn", "ignore"))
  }

  if (!rlang::is_scalar_integerish(resolution) || resolution < 0) {
    rlang::abort("`resolution` must be a single non-negative integer.")
  }

  if (!is.null(grid_type) && grid_type == "h3" && resolution > 15) {
    rlang::abort("For `grid_type = \"h3\"`, `resolution` must be between 0 and 15.")
  }

  if (!is.null(nb_order)) {
    if (!rlang::is_scalar_integerish(nb_order) || nb_order < 0) {
      rlang::abort("`nb_order` must be a single non-negative integer.")
    }
  }

  if (!rlang::is_scalar_integerish(max_iter) || max_iter < 0) {
    rlang::abort("`max_iter` must be a non-negative integer.")
  }

  if (!rlang::is_scalar_double(tolerance) || tolerance <= 0) {
    rlang::abort("`tolerance` must be a positive number.")
  }

  if (!rlang::is_scalar_logical(include_self)) {
    rlang::abort("`include_self` must be TRUE or FALSE.")
  }

  list(
    grid_type = grid_type,
    resolution = resolution,
    #output_type = output_type,
    cell_inclusion = cell_inclusion,
    cell_allocation = cell_allocation,
    nb_order = nb_order,
    max_iter = max_iter,
    tolerance = tolerance,
    include_self = include_self,
    missing_policy = missing_policy
  )
}

prep_source <- function(source, value_col, id_col) {
  source <- source |>
    sf::st_zm(drop = TRUE, what = "ZM") |>
    sf::st_cast("MULTIPOLYGON", warn = FALSE) |>
    dplyr::mutate(.source_value = .data[[value_col]]) |>
    dplyr::select(
      source_id = dplyr::all_of(id_col),
      .source_value
    )

  source_values <- source |>
    sf::st_drop_geometry() |>
    dplyr::select(
      source_id,
      source_value = .source_value
    ) |>
    dplyr::distinct(source_id, .keep_all = TRUE)

  input_total_original <- sum(source_values$source_value, na.rm = TRUE)

  source_index <- source_values |>
    dplyr::mutate(.sid = dplyr::row_number()) |>
    dplyr::select(source_id, .sid)

  source <- source |>
    dplyr::left_join(source_index, by = "source_id")

  list(
    source = source,
    source_values = source_values,
    source_index = source_index,
    input_total_original = input_total_original,
    input_total_represented = input_total_original
  )
}

add_pycno_attrs <- function(out,
                            iterations,
                            relative_mean_change,
                            grid_type = NULL,
                            resolution = NULL,
                            neighbour_k = NULL,
                            input_total_original,
                            input_total_represented) {
  attr(out, "iterations") <- iterations
  attr(out, "relative_mean_change") <- relative_mean_change

  if (!is.null(grid_type)) {
    attr(out, "grid_type") <- grid_type
  }

  if (!is.null(resolution)) {
    attr(out, "resolution") <- resolution

    # Backward-compatible alias used by the specialized H3 workflow.
    if (!is.null(grid_type) && identical(grid_type, "h3")) {
      attr(out, "h3_resolution") <- resolution
    }
  }

  if (!is.null(neighbour_k)) {
    attr(out, "neighbour_k") <- neighbour_k
  }

  attr(out, "input_total_original") <- input_total_original
  attr(out, "input_total_represented") <- input_total_represented
  attr(out, "missing_mass") <- input_total_original - input_total_represented
  attr(out, "missing_mass_relative") <-
    (input_total_original - input_total_represented) /
    max(abs(input_total_original), .Machine$double.eps, na.rm = TRUE)

  out
}
