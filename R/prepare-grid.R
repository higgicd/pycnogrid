prepare_target_cells <- function(source_polys,
                                 grid_type,
                                 resolution,
                                 cell_inclusion) {

  if (grid_type == "h3") {
    target_cells <- prepare_h3_cells(
      source_polys,
      resolution,
      cell_inclusion
      )
  } else if (grid_type == "a5") {
    target_cells <- prepare_a5_cells(
      source_polys,
      resolution,
      cell_inclusion
      )
  } else if (grid_type == "s2") {
    target_cells <- prepare_s2_cells(
      source_polys,
      resolution,
      cell_inclusion
      )
  } else if (grid_type == "raster") {
    target_cells <- prepare_raster_cells(
      source_polys,
      resolution,
      cell_inclusion
      )
  } else if (grid_type == "isea3h") {
    target_cells <- prepare_isea_cells(
      source_polys,
      resolution,
      cell_inclusion,
      aperture = "3"
    )
  } else if (grid_type == "isea4h") {
    target_cells <- prepare_isea_cells(
      source_polys,
      resolution,
      cell_inclusion,
      aperture = "4"
    )
  } else if (grid_type == "isea7h") {
    target_cells <- prepare_isea_cells(
      source_polys,
      resolution,
      cell_inclusion,
      aperture = "7"
    )
  } #else if (grid_type == "isea43h") {
    #target_cells <- prepare_isea_cells(
    #  source_polys,
    #  resolution,
    #  cell_inclusion,
    #  aperture = "4/3"
    #)
  #}

  n_target <- nrow(target_cells)

  if (n_target == 0) {
    rlang::abort("No grid cells were generated. Try a finer `resolution` or check the input geometry.")
  }

  target_cells <- target_cells |>
    sf::st_transform(sf::st_crs(source_polys))

  target_cells
}

prepare_h3_cells <- function(source_polys, resolution, cell_inclusion) {

  source_polys_ll <- source_polys |>
    sf::st_transform(crs = 4326)

  if (cell_inclusion == "intersect") {
    containment <- "intersect"
  } else {
    containment <- "centroid"
  }

  h3_cells <- h3o::sfc_to_cells(
    sf::st_geometry(source_polys_ll),
    resolution = resolution,
    containment = containment
  ) |>
    h3o::flatten_h3() |>
    unique()

  tibble::tibble(h3 = as.character(h3_cells)) |>
    dplyr::mutate(geometry = sf::st_as_sfc(h3_cells),
                  .tid = dplyr::row_number()) |>
    sf::st_as_sf()
}

prepare_a5_cells <- function(source_polys, resolution, cell_inclusion) {
  source_polys_ll <- source_polys |>
    sf::st_transform(crs = 4326)

  if (cell_inclusion == "intersect") {
    a5_cells <- a5R::a5_grid(sf::st_geometry(source_polys_ll), resolution = resolution) |>
      unique()

  } else {
    a5_cells <- a5R::a5_polygon_to_cells(sf::st_geometry(source_polys_ll), resolution = resolution) |>
      a5R::a5_uncompact(resolution = resolution) |>
      unique()
  }

  tibble::tibble(a5 = as.character(a5_cells)) |>
    dplyr::mutate(
      geometry = sf::st_as_sfc(a5R::a5_cell_to_boundary(a5_cells)),
      .tid = dplyr::row_number()
    ) |>
    sf::st_as_sf()

}

prepare_s2_cells <- function(source_polys,
                             resolution,
                             cell_inclusion) {

  source_polys_ll <- source_polys |>
    sf::st_transform(crs = 4326)

  s2_cells <- source_polys_ll |>
    sf::st_geometry() |>
    s2::as_s2_geography() |>
    s2::s2_covering_cell_ids(
      min_level = resolution,
      max_level = resolution,
      max_cells = 10000000
    ) |>
    unlist() |>
    unique()

  target_cells <- tibble::tibble(
    s2 = as.character(s2_cells),
    geometry = sf::st_as_sfc(s2::s2_cell_polygon(s2_cells), crs = 4326)
  ) |>
    sf::st_as_sf() |>
    dplyr::mutate(.tid = dplyr::row_number())

  if (cell_inclusion == "centroid") {
    cell_centroids <- suppressWarnings(sf::st_centroid(target_cells))

    keep <- lengths(sf::st_within(
      sf::st_geometry(cell_centroids),
      sf::st_geometry(source_polys_ll)
    )) > 0

    target_cells <- target_cells[keep, ] |>
      dplyr::mutate(.tid = dplyr::row_number())
  }

  target_cells
}

prepare_raster_cells <- function(source_polys,
                                 resolution,
                                 cell_inclusion) {

  source_polys_vect <- terra::vect(source_polys)

  raster_cells <- terra::rast(
    source_polys_vect,
    resolution = resolution,
    crs = terra::crs(source_polys_vect)
  )

  raster_cells[] <- 1

  if (cell_inclusion == "intersect") {
    touches_flag <- TRUE
  } else {
    touches_flag <- FALSE
  }

  raster_cells <- terra::mask(
    raster_cells,
    source_polys_vect,
    touches = touches_flag
  )

  terra::as.polygons(
    raster_cells,
    aggregate = FALSE,
    values = FALSE,
    na.rm = TRUE
  ) |>
    sf::st_as_sf() |>
    dplyr::mutate(
      raster_cell = dplyr::row_number(),
      .tid = dplyr::row_number()
    )
}

prepare_isea_cells <- function(source_polys,
                               resolution,
                               cell_inclusion,
                               aperture) {

  source_polys_ll <- source_polys |>
    sf::st_transform(crs = 4326)

  grid <- hexify::hex_grid(
    type = "isea",
    resolution = resolution,
    aperture = aperture
    )

  if (cell_inclusion == "intersect") {
    # hexify::grid_rect does not fully cover source_polys
    # so make a buffer half the grid width in metres
    grid_half_width_m <- grid@diagonal_km * 1000

    source_polys_bbox_ll <- source_polys |>
      sf::st_buffer(dist = grid_half_width_m) |>
      sf::st_transform(crs = 4326) |>
      sf::st_bbox()

    isea_cells <- hexify::grid_rect(
      bbox = source_polys_bbox_ll,
      grid = grid
    ) |>
      sf::st_filter(sf::st_geometry(source_polys_ll), .predicate = sf::st_intersects) |>
      unique()

    #isea_cells <- hexify::grid_rect(
    #  bbox = source_polys_ll,
    #  grid = grid
    #) |>
    #  unique()

  } else {

    isea_cells <- hexify::grid_clip(
      boundary = source_polys_ll,
      grid = grid,
      crop = FALSE
    ) |>
      unique()
  }

  isea_cells |>
    dplyr::mutate(
      cell_id = as.character(cell_id),
      .tid = dplyr::row_number()
    )
}

#prepare_sf_cells <- function(source_polys, resolution, cell_inclusion) {
#
#}
