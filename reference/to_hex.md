# Pycnophylactic interpolation to a local hexagonal grid

Interpolates polygon counts to a local hexagonal grid while preserving
source-zone totals.

## Usage

``` r
to_hex(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  Hexagonal cell size specified in the linear units of the input
  projected CRS.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing hexagonal grid-cell polygons and interpolated
values.

## Details

Hex grids divide the study area into hexagonal cells of a fixed size.
Smaller cell sizes produce more output cells and may substantially
increase computation time.
