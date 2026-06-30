# Pycnophylactic interpolation to a raster grid

Interpolates polygon counts to a regular raster grid while preserving
source-zone totals.

## Usage

``` r
to_raster(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  Raster cell size in metres.

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
