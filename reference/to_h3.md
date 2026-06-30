# Pycnophylactic interpolation to an H3 grid

Interpolates polygon counts to an H3 grid while preserving source-zone
totals.

## Usage

``` r
to_h3(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  A5 resolution level (0–15). Higher values produce smaller cells and
  many more output polygons. For typical urban analyses, values around
  9–12 are usually more practical.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing H3 cells and interpolated values.

## Details

H3 is a hierarchical global discrete grid system composed primarily of
hexagonal cells. Higher resolution levels produce smaller cells and a
larger number of output cells. H3 resolutions range from 0 to 15, but
high resolutions may be impractical for large study areas.

Calls
[`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md)
with `grid_type = "h3"`.
