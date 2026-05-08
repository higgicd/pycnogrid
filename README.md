
<!-- README.md is generated from README.Rmd. Please edit that file -->

# pycnogrid

<!-- badges: start -->

<!-- badges: end -->

`pycnogrid` provides tools for pycnophylactic interpolation of polygon
totals to H3 grids while preserving mass.

## Installation

You can install the development version of `pycnogrid` from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("YOUR_GITHUB_NAME/pycnogrid")
```

## Example

``` r
library(pycnogrid)

out <- to_h3(
  source = nyc_ct_small,
  value_col = populationE,
  id_col = id,
  resolution = 9
)
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.

head(out)
#> # A tibble: 6 × 7
#>   h3      source_id cell_area density pycno_populationE pycno_density pycno_iter
#>   <chr>   <chr>         <dbl>   <dbl>             <dbl>         <dbl>      <int>
#> 1 892a10… 36061009…   105891. 0.0449              4751.       0.0449           5
#> 2 892a10… 36061009…   105885. 0.0135              1430.       0.0135           5
#> 3 892a10… 36061007…   105885. 0.0232              2455        0.0232           5
#> 4 892a10… 36061008…   105890. 0.0172              1821.       0.0172           5
#> 5 892a10… 36061008…   105885. 0.0304              3217.       0.0304           5
#> 6 892a10… 36061010…   105891. 0.00698              739.       0.00698          5
```
