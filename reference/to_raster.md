# Pycnophylactic interpolation to a raster grid

Interpolates polygon counts to a regular raster grid while preserving
source-zone totals when used with default centroid-based allocation.

## Usage

``` r
to_raster(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object in a projected CRS.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  Raster cell size specified in the linear units of the input projected
  CRS.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing raster grid-cell polygons and interpolated
values.

## Details

Raster grids divide the study area into regular cells of a fixed size.
In `pycnogrid`, interpolation is performed using a raster grid, but
results are returned as polygon grid cells in an `sf` object. Smaller
cell sizes produce more output cells and may substantially increase
computation time.

## Examples

``` r
out <- to_raster(
  source = nyc_ct_small,
  value_col = populationE,
  resolution = 250,
  max_iter = 5
)
#> Warning: Pycnophylactic smoothing did not converge within `max_iter = 5`. Final relative mean change was 0.0002211.
```
