
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
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(pycnogrid)
```

``` r
out <- to_h3(
  source = nyc_ct_small,
  value_col = populationE,
  id_col = id,
  resolution = 9,
  output_type = "sf"
)
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
```

``` r
out |> glimpse()
#> Rows: 43
#> Columns: 8
#> $ h3                <chr> "892a100d257ffff", "892a100d203ffff", "892a100d273ff…
#> $ source_id         <chr> "36061009100", "36061005600", "36061005400", "360610…
#> $ cell_area         <dbl> 105880.3, 105874.6, 105869.8, 105895.9, 105890.8, 10…
#> $ density           <dbl> 0.0608706180, 0.0384511483, 0.0445925150, 0.00125622…
#> $ pycno_populationE <dbl> 6445.00000, 4071.00000, 4721.00000, 133.02955, 1183.…
#> $ pycno_density     <dbl> 0.0608706180, 0.0384511483, 0.0445925150, 0.00125622…
#> $ pycno_iter        <int> 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5…
#> $ geometry          <POLYGON [°]> POLYGON ((-73.99414 40.7461..., POLYGON ((-7…
```
