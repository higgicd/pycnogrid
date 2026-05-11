#' Pycnophylactic interpolation to an H3 grid
#'
#' Interpolates polygon totals to an H3 grid while preserving mass
#' over the represented H3 cells.
#'
#' @param source An `sf` polygon object.
#' @param value_col Unquoted column containing non-negative source totals.
#' @param id_col Optional unique identifier column for source polygons.
#' @param resolution H3 resolution (0--15).
#' @param output_type Output format: `"h3"` for a tibble of H3 cell IDs
#'   or `"sf"` for polygon geometries.
#' @param k H3 neighbourhood distance used for smoothing.
#' @param max_iter Maximum number of pycnophylactic smoothing iterations.
#'   If `0`, returns the initial area-based allocation without smoothing.
#' @param tolerance Convergence tolerance based on relative mean density change.
#' @param include_self Logical. Should each H3 cell include itself in smoothing?
#' @param missing_policy How to handle source polygons that receive no H3
#'   cells. One of `"abort"`, `"warn"`, or `"ignore"`.
#' @param db_conn Optional DuckDB connection. If `NULL`, a temporary in-memory
#'   database is created automatically.
#'
#' @details
#' Source polygons are converted to H3 cells using centroid assignment via
#' `duckh3`. Initial densities are computed from the total area of assigned
#' H3 cells rather than the exact source polygon area.
#'
#' H3 cells are not equal area. Cell areas are computed directly using the
#' H3 library in square metres.
#'
#' @return
#' A tibble containing H3 cell IDs and interpolated values when
#' `output_type = "h3"`, or an `sf` object of H3 polygons when
#' `output_type = "sf"`.
#'
#' @export
to_h3 <- function(source,
                  value_col,
                  id_col = NULL,
                  resolution,
                  output_type = c("h3", "sf"),
                  k = 1,
                  max_iter = 500,
                  tolerance = 1e-4,
                  include_self = TRUE,
                  missing_policy = c("abort", "warn", "ignore"),
                  db_conn = NULL) {

  # ---------------------------------------------------------------------------
  # 0. initialization
  # ---------------------------------------------------------------------------

  ## check connection
  if (is.null(db_conn)) {
    db_conn <- duckh3::ddbh3_create_conn(dbdir = "memory")
    on.exit(DBI::dbDisconnect(db_conn, shutdown = TRUE), add = TRUE)
  }

  ## get value column
  value_col <- rlang::as_name(rlang::ensym(value_col))
  out_name <- paste0("pycno_", rlang::as_string(value_col))

  output_type <- match.arg(output_type)
  missing_policy <- match.arg(missing_policy)

  # check value column
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

  # check sf inputs
  ## must be sf
  if (!inherits(source, "sf")) {
    rlang::abort("`source` must be an sf object.")
  }

  ## check valid geometries
  if (!all(sf::st_is_valid(source))) {
    bad <- which(!sf::st_is_valid(source))
    rlang::abort(
      paste0(
        "`source` contains invalid geometries. ",
        "Please repair them before using `to_h3()`. ",
        "Invalid row(s): ", paste(utils::head(bad, 10), collapse = ", "),
        if (length(bad) > 10) " ..." else ""
      )
    )
  }

  ## check for empty geometries
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

  ## check geometry types, should only be POLYGON or MULTIPOLYGON
  geom_type <- unique(as.character(sf::st_geometry_type(source)))

  if (!all(geom_type %in% c("POLYGON", "MULTIPOLYGON"))) {
    rlang::abort("`source` must contain only POLYGON or MULTIPOLYGON geometries.")
  }

  ## check crs
  if (is.na(sf::st_crs(source))) {
    rlang::abort("`source` must have a valid CRS.")
  }

  # check id column for missing column, missing values, or duplicates
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

  # check output parameters
  if (!rlang::is_scalar_integerish(resolution) || resolution < 0 || resolution > 15) {
    rlang::abort("`resolution` must be a single integer between 0 and 15.")
  }

  if (!rlang::is_scalar_integerish(k) || k < 0) {
    rlang::abort("`k` must be a single non-negative integer.")
  }

  if (!rlang::is_scalar_logical(include_self)) {
    rlang::abort("`include_self` must be TRUE or FALSE.")
  }

  # check convergence parameters
  if (!rlang::is_scalar_integerish(max_iter) || max_iter < 0) {
    rlang::abort("`max_iter` must be a non-negative integer.")
  }

  if (!rlang::is_scalar_double(tolerance) || tolerance <= 0) {
    rlang::abort("`tolerance` must be a positive number.")
  }

  # ---------------------------------------------------------------------------
  # 1. get sources and target cells
  # ---------------------------------------------------------------------------

  # prepare input sources, source values from the value_col, and convert
  # geometry to wkt
  source <- sf::st_transform(source, 4326)
  source$.source_value <- source[[value_col]]
  source$.wkt <- sf::st_as_text(sf::st_geometry(source))

  source_values <- source |>
    sf::st_drop_geometry() |>
    dplyr::select(source_id = dplyr::all_of(id_col),
                  source_value = .source_value) |>
    dplyr::distinct(source_id, .keep_all = TRUE) |>
    dplyr::copy_to(
      dest = db_conn,
      name = "pycno_source_values",
      overwrite = TRUE,
      temporary = FALSE
    )

  # track total source values from original input
  input_total_original <- source_values |>
    dplyr::summarise(total = sum(source_value, na.rm = TRUE)) |>
    dplyr::pull(total)

  # initialize represented total assuming all sources are represented
  input_total_represented <- input_total_original

  ## deal with multipolygons - explode multipolygons into separate
  ## parts. however, they will not be counted twice as their value_col
  ## only enters source_values above, this just ensures all polygons
  ## get covered by h3 grid cells
  source_parts <- source |>
    dplyr::select(source_id = dplyr::all_of(id_col)) |>
    sf::st_cast("MULTIPOLYGON", warn = FALSE) |>
    sf::st_cast("POLYGON", warn = FALSE)

  ## get wkt geometry
  source_parts$wkt <- sf::st_as_text(sf::st_geometry(source_parts))

  source_parts <- source_parts |>
    sf::st_drop_geometry() |>
    dplyr::select(source_id, wkt) |>
    dplyr::copy_to(
      dest = db_conn,
      name = "pycno_source_parts",
      overwrite = TRUE,
      temporary = FALSE
    )

  # create h3 cells based on centroids in the source polygons
  cells_raw <- source_parts |>
    dplyr::mutate(h3_list = dbplyr::sql(
      paste0("h3_polygon_wkt_to_cells_string(wkt, ", resolution, ")")
    )) |>
    dplyr::transmute(source_id, h3 = dbplyr::sql("UNNEST(h3_list)")) |>
    dplyr::compute(name = "pycno_cells_raw", temporary = FALSE)

  #cells_raw_df <- cells_raw |> as.data.frame()

  # cells_raw checks
  ## check - if no h3 cells were actually generated for some reason, perhaps a
  ## significant mismatch in resolutions
  n_cells <- cells_raw |>
    dplyr::summarise(n = dplyr::n()) |>
    dplyr::pull(n)

  if (n_cells == 0) {
    rlang::abort(
      "No H3 cells were generated. Try a finer `resolution` or check the input geometry."
    )
  }

  ## check - warn if there were overlapping input polygons and duplicate h3 cells
  dup_cells <- cells_raw |>
    dplyr::count(h3) |>
    dplyr::filter(n > 1) |>
    dplyr::summarise(n = dplyr::n()) |>
    dplyr::pull(n)

  if (dup_cells > 0) {
    rlang::warn(
      paste0(
        dup_cells,
        " H3 cells were generated by more than one source polygon. ",
        "Duplicated cells were assigned to the smallest `source_id`."
      )
    )
  }

  # cell assignment
  ## complete the assignment of h3 cells to source polygons by their source_id
  ## if polygons overlap, assign duplicated H3 cells to the smallest source_id.
  cells_assigned <- cells_raw |>
    dplyr::group_by(h3) |>
    dplyr::summarise(source_id = min(source_id, na.rm = TRUE), .groups = "drop") |>
    dplyr::compute(name = "pycno_cells_assigned", temporary = FALSE)

  ## check - if empty output generated after assignment back to polygons
  n_assigned <- cells_assigned |>
    dplyr::summarise(n = dplyr::n()) |>
    dplyr::pull(n)

  if (n_assigned == 0) {
    rlang::abort("No H3 cells remain after assignment.")
  }

  ## check - warn if some input polygons did not receive any h3 cells
  ## e.g. no h3 centroids inside a given source polygon
  missing_sources <- source_values |>
    dplyr::anti_join(
      cells_raw |> dplyr::distinct(source_id),
      by = "source_id"
    ) |>
    dplyr::collect()

  if (nrow(missing_sources) > 0) {

    missing_mass <- sum(missing_sources$source_value, na.rm = TRUE)

    total_mass_original <- source_values |>
      dplyr::summarise(total = sum(source_value, na.rm = TRUE)) |>
      dplyr::pull(total)

    missing_pct <- 100 * missing_mass / total_mass_original

    msg <- paste0(
      nrow(missing_sources),
      " source polygon(s) received no H3 cells at resolution ",
      resolution,
      ". ",
      "Missing mass: ",
      signif(missing_mass, 6),
      " (",
      round(missing_pct, 3),
      "% of total mass). ",
      "Try increasing `resolution`."
    )

    if (missing_policy == "abort") {
      rlang::abort(msg)

    } else if (missing_policy == "warn") {
      rlang::warn(msg)
    }

    # overwrite source values keeping only ones represented in the system
    source_values <- source_values |>
      dplyr::semi_join(
        cells_raw |> dplyr::distinct(source_id),
        by = "source_id"
      ) |>
      dplyr::compute(
        name = "pycno_source_values_represented",
        temporary = FALSE
      )

    # update represented total
    input_total_represented <- source_values |>
      dplyr::summarise(total = sum(source_value, na.rm = TRUE)) |>
      dplyr::pull(total)
  }

  # ---------------------------------------------------------------------------
  # 2. get H3 cell areas
  # ---------------------------------------------------------------------------

  # h3 cells are not equal area
  cells_area <- cells_assigned |>
    dplyr::mutate(
      cell_area = dbplyr::sql("h3_cell_area(h3_string_to_h3(h3), 'm^2')"),
      density = 0
    ) |>
    dplyr::compute(name = "pycno_cells_area", temporary = FALSE)

  # ---------------------------------------------------------------------------
  # 3. get initial areal density by assigned H3 area
  # ---------------------------------------------------------------------------

  area_by_source <- cells_area |>
    # group by source polygon id
    dplyr::group_by(source_id) |>
    # get total area of h3 cells inside the source polygon
    dplyr::summarise(assigned_area = sum(cell_area, na.rm = TRUE),
                     .groups = "drop") |>
    # compute table
    dplyr::compute(name = "pycno_area_by_source", temporary = FALSE)

  cells <- cells_area |>
    dplyr::select(h3, source_id, cell_area) |>
    # join the total h3 areas by source polygon
    dplyr::left_join(area_by_source, by = "source_id") |>
    # join the source value_col
    dplyr::left_join(source_values, by = "source_id") |>
    # get initial density of value_col over the
    dplyr::mutate(density = dplyr::case_when(
      assigned_area > 0 ~ source_value / assigned_area,
      TRUE ~ 0
    )) |>
    #dplyr::mutate(density = dplyr::if_else(assigned_area > 0, source_value / assigned_area, 0)) |>
    dplyr::select(h3, source_id, cell_area, density) |>
    dplyr::compute(name = "pycno_cells", temporary = FALSE)

  #cells_df <- cells |> as.data.frame()

  # ---------------------------------------------------------------------------
  # 3b. return unsmoothed areal allocation if requested
  # ---------------------------------------------------------------------------

  if (max_iter == 0) {

    input_total <- source_values |>
      dplyr::summarise(total = sum(source_value, na.rm = TRUE)) |>
      dplyr::pull(total)

    out <- dplyr::tbl(db_conn, "pycno_cells") |>
      dplyr::mutate(
        !!out_name := as.numeric(density * cell_area),
        pycno_density = as.numeric(density),
        pycno_iter = 0
      )

    output_total <- out |>
      dplyr::summarise(total = sum(.data[[out_name]], na.rm = TRUE)) |>
      dplyr::pull(total)

    mass_error <- abs(output_total - input_total)
    mass_relative_error <- mass_error / max(abs(input_total), .Machine$double.eps, na.rm = TRUE)

    if (mass_relative_error > tolerance) {
      rlang::warn(
        paste0(
          "Output total differs from input total. ",
          "Relative mass error: ", signif(mass_relative_error, 4), "."
        )
      )
    }

    if (output_type == "h3") {
      out <- out |>
        dplyr::collect()
    } else {
      out <- out |>
        dplyr::mutate(
          geometry = dbplyr::sql("h3_cell_to_boundary_wkt(h3_string_to_h3(h3))")
        ) |>
        dplyr::collect() |>
        sf::st_as_sf(wkt = "geometry", crs = 4326)
    }

    attr(out, "iterations") <- 0
    attr(out, "relative_mean_change") <- NA_real_
    attr(out, "h3_resolution") <- resolution
    attr(out, "neighbour_k") <- k
    attr(out, "input_total_original") <- input_total_original
    attr(out, "input_total_represented") <- input_total_represented
    attr(out, "missing_mass") <- input_total_original - input_total_represented
    attr(out, "missing_mass_relative") <-
      (input_total_original - input_total_represented) /
      max(abs(input_total_original), .Machine$double.eps, na.rm = TRUE)

    return(out)
  }

  # ---------------------------------------------------------------------------
  # 4. build H3 neighbour list
  # ---------------------------------------------------------------------------

  # get all neighbours based on grid disk and k
  neighbours_all <- cells |>
    dplyr::transmute(h3, neighbour_h3 = dbplyr::sql(
      paste0(
        "h3_h3_to_string(UNNEST(h3_grid_disk(h3_string_to_h3(h3), ",
        k,
        ")))"
      )
    ))

  # remove self if include_self is FALSE
  if (!include_self) {
    neighbours_all <- neighbours_all |>
      dplyr::filter(h3 != neighbour_h3)
  }

  # compute the neighbours table
  neighbours_all <- neighbours_all |>
    dplyr::compute(name = "pycno_neighbours_all", temporary = FALSE)

  active_cell_ids <- cells |>
    dplyr::select(neighbour_h3 = h3) |>
    dplyr::distinct()

  # create final neighbours list
  neighbours <- neighbours_all |>
    dplyr::inner_join(active_cell_ids, by = "neighbour_h3") |>
    dplyr::compute(name = "pycno_neighbours", temporary = FALSE)

  # ---------------------------------------------------------------------------
  # 5. iterate: smooth -> correct -> check mass error
  # ---------------------------------------------------------------------------

  # get total input volume/mass
  input_total <- source_values |>
    dplyr::summarise(total = sum(source_value, na.rm = TRUE)) |>
    dplyr::pull(total)

  # set initial iteration values
  last_error <- Inf
  iter_used <- 0

  # iterate
  for (iter in seq_len(max_iter)) {
    # track the iteration
    iter_used <- iter

    # drop the previous round table
    DBI::dbExecute(db_conn, "DROP TABLE IF EXISTS pycno_cells_before")

    # get initial or previous round cells and densities
    cells_before <- dplyr::tbl(db_conn, "pycno_cells") |>
      dplyr::select(h3, density_before = density) |>
      dplyr::compute(name = "pycno_cells_before", temporary = FALSE)

    # get current cells
    cells_current <- dplyr::tbl(db_conn, "pycno_cells")

    # get current neighbours list
    neighbours_current <- dplyr::tbl(db_conn, "pycno_neighbours")

    # smoothing
    ## drop previous round smoothed
    DBI::dbExecute(db_conn, "DROP TABLE IF EXISTS pycno_smoothed")

    smoothed <- neighbours_current |>
      # join target cell info
      dplyr::left_join(cells_current |>
                         dplyr::select(h3, source_id, cell_area),
                       by = "h3") |>
      # join neighbourhing cells info
      dplyr::left_join(
        cells_current |>
          dplyr::select(neighbour_h3 = h3, neighbour_density = density),
        by = "neighbour_h3"
      ) |>
      # calculate mean density of neighbours
      dplyr::group_by(h3, source_id, cell_area) |>
      dplyr::summarise(density = mean(neighbour_density, na.rm = TRUE),
                       .groups = "drop") |>
      # compute to table
      dplyr::compute(name = "pycno_smoothed", temporary = FALSE)

    # source estimates
    ## drop the previous round table
    DBI::dbExecute(db_conn, "DROP TABLE IF EXISTS pycno_source_est")

    ## calculate total volume estimates in the h3 cells by source_id after the smoothing round
    source_est <- smoothed |>
      dplyr::group_by(source_id) |>
      dplyr::summarise(est_value = sum(density * cell_area, na.rm = TRUE),
                       .groups = "drop") |>
      dplyr::compute(name = "pycno_source_est", temporary = FALSE)

    ## checks
    ### check if mass was lost due to h3 grid resolution
    missing_est <- source_values |>
      dplyr::anti_join(source_est, by = "source_id") |>
      dplyr::collect()

    if (nrow(missing_est) > 0) {
      rlang::abort(
        paste0(
          nrow(missing_est),
          " source polygon(s) have no estimated mass during correction. ",
          "This indicates they have still no active H3 cells in the current interpolation grid."
        )
      )
    }

    ### check for strange zeros - places where a source polygon has positive input volume
    ### but after smoothing that volume becomes zero, negative, NA
    zero_est <- source_est |>
      dplyr::left_join(source_values, by = "source_id") |>
      dplyr::filter(
        source_value > 0,
        est_value <= 0 | is.na(est_value)
      ) |>
      dplyr::collect()

    if (nrow(zero_est) > 0) {
      rlang::abort(
        paste0(
          nrow(zero_est),
          " source polygon(s) have positive input mass but zero estimated mass ",
          "during correction. The pycnophylactic correction cannot be computed."
        )
      )
    }

    # correct the volumes
    ## drop output from previous iteration round
    DBI::dbExecute(db_conn, "DROP TABLE IF EXISTS pycno_cells_next")

    ## get correction proportions
    corrected <- smoothed |>
      # join total source volumes implied after smoothing
      dplyr::left_join(source_est, by = "source_id") |>
      # join original source values
      dplyr::left_join(source_values, by = "source_id") |>
      # get corrected density
      dplyr::mutate(
        density = dplyr::case_when(
          # if the source had no value_col to begin with, keep
          # h3 cell density at zero, no spillovers!
          source_value == 0 ~ 0,
          # apply correction for h3 cells with source values
          est_value > 0 ~ density * source_value / est_value,
          TRUE ~ NA_real_
        )
      ) |>
      # compute table for input to next round (if required)
      dplyr::select(h3, source_id, cell_area, density) |>
      dplyr::compute(name = "pycno_cells_next", temporary = FALSE)



    # when to stop? get change statistics
    #change <- corrected |>
    #  dplyr::left_join(cells_before, by = "h3") |>
    #  # get abs changes in density now versus before
    #  dplyr::summarise(
    #    max_abs_change = max(abs(density - density_before), na.rm = TRUE),
    #    mean_abs_change = mean(abs(density - density_before), na.rm = TRUE),
        # relative mean change probably best for convergence?
        # less sensitive to original units
    #    rel_mean_change = mean(abs(density - density_before) /
    #                             pmax(abs(density_before), 1e-12), na.rm = TRUE),
    #    .groups = "drop"
    #  ) |>
    #  dplyr::collect()

    change <- corrected |>
      dplyr::left_join(cells_before, by = "h3") |>
      dplyr::mutate(
        abs_change = abs(density - density_before),
        denom = dplyr::case_when(
          abs(density_before) > 1e-12 ~ abs(density_before),
          TRUE ~ 1e-12
        )
      ) |>
      dplyr::summarise(
        max_abs_change = max(abs_change, na.rm = TRUE),
        mean_abs_change = mean(abs_change, na.rm = TRUE),
        rel_mean_change = mean(abs_change / denom, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::collect()

    #last_error <- change$max_abs_change
    last_error <- change |> pull("rel_mean_change")

    # drop original pycno cells and rename next
    DBI::dbExecute(db_conn, "DROP TABLE IF EXISTS pycno_cells")
    DBI::dbExecute(db_conn,
                   "ALTER TABLE pycno_cells_next RENAME TO pycno_cells")

    # at 1e-4 default, stop when average density change is less than 0.01%
    if (last_error <= tolerance) {
      break
    }
  }

  # warn about no convergence within iteration limit
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

  # prepare output
  out <- dplyr::tbl(db_conn, "pycno_cells") |>
    dplyr::mutate(
      !!out_name := as.numeric(density * cell_area),
      pycno_density = as.numeric(density),
      pycno_iter = iter_used
    )

  # check output totals
  ## get output total after pycno
  output_total <- out |>
    dplyr::summarise(total = sum(.data[[out_name]], na.rm = TRUE)) |>
    dplyr::pull(total)

  ## get the difference pre-post pycno
  mass_error <- abs(output_total - input_total)
  mass_relative_error <- mass_error / max(abs(input_total), .Machine$double.eps, na.rm = TRUE)

  if (mass_relative_error > tolerance) {
    rlang::warn(
      paste0(
        "Output total differs from input total. ",
        "Relative mass error: ", signif(mass_relative_error, 4), "."
      )
    )
  }

  # ---------------------------------------------------------------------------
  # 6. return as h3 or sf
  # ---------------------------------------------------------------------------

  if (output_type == "h3") {
    # output only with h3 strings
    out <- out |>
      dplyr::collect()

  } else {
    # or full sf geometry
    out <- out |>
      dplyr::mutate(geometry = dbplyr::sql("h3_cell_to_boundary_wkt(h3_string_to_h3(h3))")) |>
      dplyr::collect() |>
      sf::st_as_sf(wkt = "geometry", crs = 4326)
  }

  # add attributes
  attr(out, "iterations") <- iter_used
  attr(out, "relative_mean_change") <- last_error
  attr(out, "h3_resolution") <- resolution
  attr(out, "neighbour_k") <- k
  attr(out, "input_total_original") <- input_total_original
  attr(out, "input_total_represented") <- input_total_represented
  attr(out, "missing_mass") <- input_total_original - input_total_represented
  attr(out, "missing_mass_relative") <-
    (input_total_original - input_total_represented) /
    max(abs(input_total_original), .Machine$double.eps, na.rm = TRUE)

  # let's go!
  out
}
