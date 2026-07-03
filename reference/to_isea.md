# Pycnophylactic interpolation to an ISEA grid

Interpolates polygon counts to an ISEA discrete global grid while
preserving source-zone totals.

## Usage

``` r
to_isea(source, value_col, resolution, aperture = c(3, 4), ...)
```

## Arguments

- source:

  An `sf` polygon object in a projected CRS.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  ISEA resolution level. Higher values produce smaller cells and
  substantially more output polygons.

- aperture:

  ISEA aperture: one of `3` or `4`.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing ISEA cells and interpolated values.

## Details

ISEA grids are equal-area hierarchical discrete global grid systems
based on the Icosahedral Snyder Equal Area projection. The `aperture`
determines the refinement factor between successive resolutions:
aperture 3, 4, or 7.

Calls
[`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md)
with `grid_type` set to `"isea3h"` or `"isea4h"` according to
`aperture`.

## Examples

``` r
out <- to_isea(
  source = nyc_ct_small,
  value_col = populationE,
  resolution = 18,
  aperture = 3,
  max_iter = 5
)
#> Warning: Pycnophylactic smoothing did not converge within `max_iter = 5`. Final relative mean change was 0.001357.

out <- to_isea(
  source = nyc_ct_small,
  value_col = populationE,
  resolution = 14,
  aperture = 4,
  max_iter = 5
)
#> Warning: Pycnophylactic smoothing did not converge within `max_iter = 5`. Final relative mean change was 0.0002818.
```
