
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
remotes::install_github("higgicd/pycnogrid")
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
#> 1 892a10… 36061009…   105885. 1.35e-2            1430.       0.0135            5
#> 2 892a10… 36061009…   105891. 4.49e-2            4751.       0.0449            5
#> 3 892a10… 36061005…   105880. 1.98e-2            2092.       0.0198            5
#> 4 892a10… 36061008…   105875. 3.05e-2            3231.       0.0305            5
#> 5 892a10… 36061010…   105896. 1.14e-2            1209.       0.0114            5
#> 6 892a10… 36061011…   105901. 8.70e-4              92.2      0.000870          5
```
