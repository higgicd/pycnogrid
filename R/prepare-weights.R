prepare_source_cell_weights <- function(source_polys,
                                        source_values,
                                        target_cells,
                                        grid_type,
                                        resolution,
                                        cell_allocation,
                                        missing_policy,
                                        input_total_original) {

  # Number of target grid cells.
  # This is used repeatedly when constructing cell-level vectors and matrices.
  n_target <- nrow(target_cells)

  # Compute the area of each target cell.
  #
  # For A5, cells at a given resolution have a known nominal area, so we can
  # use the A5 cell-area helper and repeat that value for every target cell.
  #
  # For other grid types, use the actual sf polygon area. This assumes the
  # target cells are in an appropriate projected CRS for area calculations.
  if (grid_type == "a5") {
    cell_area <- rep(as.numeric(a5R::a5_cell_area(resolution)), n_target)
  } else {
    cell_area <- as.numeric(sf::st_area(target_cells))
  }

  # Build the raw source-to-cell relationship table.
  # This is the key spatial allocation step.
  #
  # If cell_allocation == "area", the relationship is based on polygon-cell
  # intersection areas. A cell can receive weights from multiple source polygons
  # if it overlaps more than one source.
  #
  # Otherwise, assignment is based on cell centroids. Each target cell is assigned
  # to the source polygon containing its centroid, with the cell's area used as
  # its allocation weight.
  #
  # Expected columns from these helpers are something like:
  #   source_id : source polygon identifier
  #   .tid      : target cell row index
  #   .weight   : overlap area or assigned cell area
  if (cell_allocation == "area") {
    inter_raw <- build_area_assignment(source_polys, target_cells)
  } else {
    inter_raw <- build_centroid_assignment(target_cells, source_polys, cell_area)
  }

  # If there are no source-cell relationships at all, interpolation cannot
  # proceed. This usually indicates a CRS mismatch, a resolution problem, or
  # non-overlapping source and target geometries.
  if (nrow(inter_raw) == 0) {
    rlang::abort(
      "No source-grid relationships were found. Check input CRS, `resolution`, and input geometries."
    )
  }

  # Identify source polygons that were represented in the source-cell
  # relationship table.
  #
  # A represented source is one that received at least one grid cell, or at
  # least one overlapping portion of a grid cell.
  represented_sources <- inter_raw |>
    dplyr::distinct(source_id)

  # Identify source polygons that received no grid cells.
  #
  # This can happen when the grid resolution is too coarse, especially for small
  # source polygons, or when centroid assignment misses narrow/sliver polygons.
  missing_sources <- source_values |>
    dplyr::anti_join(represented_sources, by = "source_id")

  # Start by assuming all input mass is represented.
  # This may be revised below if some source polygons received no cells.
  input_total_represented <- sum(source_values$source_value, na.rm = TRUE)

  # Handle source polygons that were not represented by the target grid.
  #
  # Depending on missing_policy, this can stop the function, warn the user,
  # or silently continue. If the function continues, the missing sources are
  # dropped from the interpolation because there is no target cell to which
  # their mass can be allocated.
  if (nrow(missing_sources) > 0) {
    missing_mass <- sum(missing_sources$source_value, na.rm = TRUE)
    missing_pct <- 100 * missing_mass / input_total_original

    msg <- paste0(
      nrow(missing_sources),
      " source polygon(s) received no grid cells at resolution ",
      resolution,
      ". Missing mass: ",
      signif(missing_mass, 6),
      " (",
      round(missing_pct, 3),
      "% of total mass)."
    )

    if (missing_policy == "abort") {
      rlang::abort(msg)
    } else if (missing_policy == "warn") {
      rlang::warn(msg)
    }

    # Keep only source polygons that are represented by at least one target cell.
    # From this point onward, the algorithm preserves represented mass rather
    # than original total mass if missing sources are allowed.
    source_values <- source_values |>
      dplyr::semi_join(represented_sources, by = "source_id")

    # Update the source total represented
    input_total_represented <- sum(source_values$source_value, na.rm = TRUE)
  }

  # Create a compact .sid numeric index for source polygons.
  #
  # Matrix operations require integer row/column indices, so .sid becomes the
  # matrix row index corresponding to each source_id.
  source_index <- source_values |>
    dplyr::mutate(.sid = dplyr::row_number()) |>
    dplyr::select(source_id, .sid)

  # Clean and aggregate the raw source-cell relationships.
  inter <- inter_raw |>
    # Drop relationships for missing/unrepresented sources.
    dplyr::semi_join(source_values, by = "source_id") |>
    # Attach the numeric source index .sid.
    dplyr::left_join(source_index, by = "source_id") |>
    # Sum weights in case the same source-cell pair appears more than once,
    # which can happen after geometric operations involving multipart polygons
    # or multiple intersection fragments.
    dplyr::group_by(.sid, .tid, source_id) |>
    dplyr::summarise(.weight = sum(.weight, na.rm = TRUE),
                     .groups = "drop")

  # Number of represented source polygons. Alongside n_target defined above,
  # these define the dimensions of the source-by-target weights matrix.
  n_source <- nrow(source_values)

  # Construct the unnormalized source-by-target spatial weights matrix.
  #
  # Rows are source polygons.
  # Columns are target grid cells.
  # Values are raw spatial weights, usually overlap areas.
  #
  # For area allocation:
  #   A_matrix[i, j] = area of overlap between source i and target cell j
  #
  # For centroid allocation:
  #   A_matrix[i, j] = area of target cell j if its centroid falls in source i
  #
  # This matrix is sparse because most source polygons intersect only a small
  # subset of all grid cells.
  A_matrix <- Matrix::sparseMatrix(
    i = inter$.sid,
    j = inter$.tid,
    x = inter$.weight,
    dims = c(n_source, n_target)
  )

  # Total assigned weight for each source polygon.
  #
  # Under area allocation, this is the total area of that source polygon covered
  # by target cells. Under centroid allocation, this is the summed area of cells
  # assigned to the source.
  row_sums <- Matrix::rowSums(A_matrix)

  # A represented source should always have positive assigned weight.
  # If not, something has gone wrong in the spatial assignment step.
  if (any(row_sums <= 0)) {
    rlang::abort("At least one represented source polygon has zero assigned grid weight.")
  }

  # Row-normalize the source-by-target matrix.
  #
  # W_matrix gives allocation proportions from each source polygon to its assigned
  # target cells. Each row sums to 1.
  #
  # This is the matrix used to allocate source totals to target cells.
  #
  # Example:
  #   If source A overlaps three cells with weights 20, 30, and 50,
  #   the normalized weights become 0.2, 0.3, and 0.5.
  # Use some sparse matrix trickery: left multiplying by diagonal
  # scales rows
  #
  # pmax(..., .Machine$double.eps) prevents division by zero if any empty
  W_matrix <- Matrix::Diagonal(x = 1 / pmax(row_sums, .Machine$double.eps),
                               n = n_source) %*% A_matrix

  # Total raw weight assigned to each target cell across all source polygons.
  #
  # Under area allocation, this is the area of the cell covered by source
  # polygons. Boundary cells may have less than their full area represented.
  #
  # Under centroid allocation, this should be the assigned cell area for
  # cells whose centroid falls inside a source polygon.
  col_sums <- as.numeric(Matrix::colSums(A_matrix))

  # Column-normalize the source-by-target matrix.
  #
  # V_matrix describes, for each target cell, the proportional contribution of each
  # source polygon to that cell's represented area.
  #
  # This is useful later for enforcing source-total preservation during the
  # pycnophylactic correction step. Conceptually, it lets cell-level quantities
  # be related back to their source polygons.
  #
  # Use some sparse matrix trickery: right multiplying by diagonal
  # scales columns
  #
  V_matrix <- A_matrix %*% Matrix::Diagonal(x = 1 / pmax(col_sums, .Machine$double.eps),
                                            n = n_target)

  # Replace any non-finite matrix values caused by numerical edge cases.
  V_matrix@x[!is.finite(V_matrix@x)] <- 0

  # Create the vector of source totals, ordered to match the rows of A_matrix,
  # W_matrix, and V_matrix.
  #
  # y[i] is the observed total for source polygon i.
  y <- source_index |>
    dplyr::left_join(source_values, by = "source_id") |>
    dplyr::arrange(.sid) |>
    dplyr::pull(source_value)

  # Calculate initial areal allocation
  x <- as.numeric(Matrix::t(W_matrix) %*% y)

  #if (grid_type == "a5") {
  #  cell_area <- rep(as.numeric(a5R::a5_cell_area(resolution)), n_target)
  #} else {
  #  cell_area <- as.numeric(sf::st_area(target_cells))
  #}

  #if (cell_allocation == "area") {
  #  cell_area_inside_source <- col_sums
  #} else {
  #  cell_area_inside_source <- cell_area
  #}
  cell_area_inside_source <- col_sums

  cell_coverage_fraction <- cell_area_inside_source / cell_area
  cell_coverage_fraction[!is.finite(cell_coverage_fraction)] <- 0
  cell_coverage_fraction <- pmin(cell_coverage_fraction, 1)

  density <- x / cell_area_inside_source
  density[!is.finite(density)] <- 0

  list(
    source_values = source_values,
    input_total_represented = input_total_represented,
    source_index = source_index,
    inter = inter,
    A_matrix = A_matrix,
    W_matrix = W_matrix,
    V_matrix = V_matrix,
    cell_area = cell_area,
    cell_area_inside_source = cell_area_inside_source,
    cell_coverage_fraction = cell_coverage_fraction,
    y = y,
    x = x,
    density = density
  )
}

build_area_assignment <- function(source_polys, target_cells) {
  suppressWarnings(sf::st_intersection(source_polys, target_cells)) |>
    dplyr::mutate(.weight = as.numeric(sf::st_area(geometry))) |>
    sf::st_drop_geometry() |>
    dplyr::filter(.weight > 0) |>
    dplyr::select(source_id, .tid, .weight)
}

build_centroid_assignment <- function(target_cells, source_polys, cell_area) {
  cell_areas <- tibble::tibble(.tid = target_cells$.tid, .weight = cell_area)

  target_pts <- suppressWarnings(sf::st_centroid(target_cells))

  assigned <- sf::st_join(
    target_pts,
    source_polys |> dplyr::select(source_id),
    join = sf::st_within,
    left = FALSE
  ) |>
    sf::st_drop_geometry() |>
    dplyr::select(.tid, source_id) |>
    dplyr::distinct()

  duplicate_cells <- assigned |>
    dplyr::count(.tid) |>
    dplyr::filter(n > 1)

  if (nrow(duplicate_cells) > 0) {
    rlang::abort(
      paste0(
        "At least one grid-cell centroid matched multiple source polygons. ",
        "Try `cell_allocation = \"area\"` instead."
      )
    )
  }

  assigned |>
    dplyr::left_join(cell_areas, by = ".tid") |>
    dplyr::select(source_id, .tid, .weight)
}
