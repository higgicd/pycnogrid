#' New York City census tract example data
#'
#' Census tract population and employment data for New York City.
#'
#' Population data were obtained from the American Community Survey
#' using the tidycensus package. Employment data were obtained from
#' LEHD LODES using the lehdr package.
#'
#' @format An sf object with:
#' \describe{
#'   \item{id}{Census tract GEOID}
#'   \item{populationE}{Estimated total population}
#'   \item{employment}{Total employment}
#'   \item{geometry}{MULTIPOLYGON geometry}
#' }
#'
#' @source
#' American Community Survey 2023; LEHD LODES 2022
"nyc_ct"

#' Small New York City census tract example data
#'
#' A small contiguous subset of NYC census tracts for examples and testing.
#'
#' @format An sf object.
"nyc_ct_small"
