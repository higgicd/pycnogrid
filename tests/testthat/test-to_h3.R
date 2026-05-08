# tests
## is expected output generated with defaults?
test_that("to_h3 returns expected output", {
  out <- to_h3(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 9,
    max_iter = 5
  )

  expect_s3_class(out, "tbl_df")
  expect_true("h3" %in% names(out))
  expect_true("pycno_populationE" %in% names(out))
  expect_gt(nrow(out), 0)
})

## mass preservation test
test_that("to_h3 approximately preserves mass", {
  input_total <- sum(nyc_ct_small$populationE, na.rm = TRUE)

  out <- to_h3(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 9,
    max_iter = 20
  )

  output_total <- sum(out$pycno_populationE, na.rm = TRUE)

  expect_equal(
    output_total,
    input_total,
    tolerance = 1e-4
  )
})

## can has sf output?
test_that("to_h3 can return sf output", {
  out <- to_h3(
    nyc_ct_small,
    value_col = populationE,
    id_col = id,
    resolution = 9,
    output_type = "sf",
    max_iter = 5
  )

  expect_s3_class(out, "sf")
  expect_true("geometry" %in% names(out))
})

## errors/warnings
test_that("to_h3 errors on negative values", {
  bad <- nyc_ct_small
  bad$populationE[1] <- -1

  expect_error(
    to_h3(
      bad,
      value_col = populationE,
      id_col = id,
      resolution = 9
    )
  )
})
