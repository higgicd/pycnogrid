# tests
## are source zone totals preserved?
## helper functions

make_source_zones <- function(values = c(10, 90)) {
  rectangle <- function(xmin, xmax) {
    sf::st_polygon(list(matrix(
      c(
        xmin, 0,
        xmax, 0,
        xmax, 2,
        xmin, 2,
        xmin, 0
      ),
      ncol = 2,
      byrow = TRUE
    )))
  }

  sf::st_sf(
    zone = c("west", "east"),
    value = values,
    geometry = sf::st_sfc(
      rectangle(0, 1.3),
      rectangle(1.3, 3),
      crs = 3857
    )
  )
}

reaggregate_by_centroid <- function(out, source) {
  reconstructed <- suppressWarnings(sf::st_centroid(out)) |>
    sf::st_join(
      source |> dplyr::select(zone),
      join = sf::st_within,
      left = FALSE
    ) |>
    sf::st_drop_geometry() |>
    dplyr::group_by(zone) |>
    dplyr::summarise(
      reconstructed = sum(pycno_value),
      .groups = "drop"
    )

  source |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      zone,
      expected = value
    ) |>
    dplyr::left_join(reconstructed, by = "zone") |>
    dplyr::mutate(
      reconstructed = dplyr::coalesce(reconstructed, 0)
    )
}

## individual source totals

test_that("centroid allocation preserves each represented source total", {
  source <- make_source_zones()

  out <- to_raster(
    source,
    value_col = value,
    id_col = zone,
    resolution = 1,
    cell_allocation = "centroid",
    max_iter = 20
  )

  totals <- reaggregate_by_centroid(out, source)

  expect_equal(
    totals$reconstructed,
    totals$expected,
    tolerance = 1e-8
  )
})

## zero-valued source

test_that("centroid allocation does not leak mass into zero sources", {
  source <- make_source_zones(values = c(0, 90))

  out <- to_raster(
    source,
    value_col = value,
    id_col = zone,
    resolution = 1,
    cell_allocation = "centroid",
    max_iter = 20
  )

  totals <- reaggregate_by_centroid(out, source)

  expect_equal(
    totals$reconstructed,
    totals$expected,
    tolerance = 1e-8
  )

  expect_equal(
    totals$reconstructed[totals$expected == 0],
    0
  )
})

## new default

test_that("default allocation is centroid allocation", {
  source <- make_source_zones()

  default <- to_raster(
    source,
    value_col = value,
    id_col = zone,
    resolution = 1,
    max_iter = 20
  )

  explicit <- to_raster(
    source,
    value_col = value,
    id_col = zone,
    resolution = 1,
    cell_allocation = "centroid",
    max_iter = 20
  )

  expect_equal(
    default$pycno_value,
    explicit$pycno_value,
    tolerance = 1e-12
  )
})

## area warning

test_that("area allocation warns about source-zone preservation", {
  source <- make_source_zones()

  expect_warning(
    to_raster(
      source,
      value_col = value,
      id_col = zone,
      resolution = 1,
      cell_allocation = "area",
      max_iter = 0
    ),
    "may not preserve individual source-zone totals"
  )
})
