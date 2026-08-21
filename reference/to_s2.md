# Pycnophylactic interpolation to an S2 grid

Interpolates polygon counts to an S2 grid while preserving source-zone
totals when used with default centroid-based allocation.

## Usage

``` r
to_s2(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object in a projected CRS.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  S2 resolution level (0–30). Higher values produce smaller cells and
  many more output polygons. For typical urban analyses, values around
  8–16 are usually more practical.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing S2 cells and interpolated values.

## Details

S2 is a hierarchical global discrete grid system based on recursively
subdividing the six faces of a cube projected onto the sphere. Higher
cell levels produce smaller cells and a larger number of output cells.
Very high levels may be impractical for pycnophylactic interpolation
over large study areas.

Calls
[`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md)
with `grid_type = "s2"`.

## Examples

``` r
out <- to_s2(
  source = nyc_ct_small,
  value_col = populationE,
  resolution = 15,
  max_iter = 5
)
#> Warning: Pycnophylactic smoothing did not converge within `max_iter = 5`. Final relative mean change was 0.0002154.
```
