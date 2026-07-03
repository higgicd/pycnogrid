# tests
## is expected output generated with defaults?
test_that("to_s2 returns expected sf output", {
  out <- to_s2(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 15,
    max_iter = 20
  )

  expect_s3_class(out, "sf")
  expect_true(inherits(out, "data.frame"))

  expect_true(all(c(
    "s2",
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
test_that("to_s2 approximately preserves mass", {
  input_total <- sum(nyc_ct_small$populationE, na.rm = TRUE)

  out <- to_s2(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 15,
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
test_that("to_s2 errors on negative values", {
  bad <- nyc_ct_small
  bad$populationE[1] <- -1

  expect_error(
    to_s2(
      bad,
      value_col = populationE,
      id_col = id,
      resolution = 15
    )
  )
})
