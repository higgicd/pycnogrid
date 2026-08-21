# tests
## is expected output generated with defaults?
test_that("to_hex returns expected sf output", {
  out <- to_hex(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 250,
    max_iter = 20
  )

  expect_s3_class(out, "sf")
  expect_true(inherits(out, "data.frame"))

  expect_true(all(c(
    "cell_id",
    "pycno_populationE",
    "pycno_density",
    "pycno_coverage",
    "pycno_iter",
    "geometry"
  ) %in% names(out)))

  expect_gt(nrow(out), 0)
  expect_false(is.na(sf::st_crs(out)))
})

## mass preservation test
test_that("to_hex approximately preserves mass", {
  input_total <- sum(nyc_ct_small$populationE, na.rm = TRUE)

  out <- to_hex(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 250,
    max_iter = 20
  )

  output_total <- sum(out$pycno_populationE, na.rm = TRUE)

  expect_equal(
    output_total,
    input_total,
    tolerance = 1e-4
  )
})

## errors/warnings
test_that("to_hex errors on negative values", {
  bad <- nyc_ct_small
  bad$populationE[1] <- -1

  expect_error(
    to_hex(
      bad,
      value_col = populationE,
      id_col = id,
      resolution = 250
    )
  )
})
