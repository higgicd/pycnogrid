# Pycnophylactic interpolation to an A5 grid

Interpolates polygon counts to an A5 grid while preserving source-zone
totals when used with default centroid-based allocation.

## Usage

``` r
to_a5(source, value_col, resolution, ...)
```

## Arguments

- source:

  An `sf` polygon object in a projected CRS.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- resolution:

  A5 resolution level (0–30). Higher values produce smaller cells and
  many more output polygons. For typical urban analyses, values around
  8–16 are usually more practical.

- ...:

  Additional arguments passed to
  [`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md).

## Value

An `sf` object containing A5 cells and interpolated values.

## Details

A5 is a hierarchical global discrete grid system in which each increase
in resolution subdivides cells by a factor of five. Consequently, the
number of cells grows exponentially with resolution and very high
resolutions may be impractical for pycnophylactic interpolation.

Calls
[`to_grid()`](https://higgicd.github.io/pycnogrid/reference/to_grid.md)
with `grid_type = "a5"`.

## Examples

``` r
out <- to_a5(
  source = nyc_ct_small,
  value_col = populationE,
  resolution = 15,
  max_iter = 5
)
#> Warning: Pycnophylactic smoothing did not converge within `max_iter = 5`. Final relative mean change was 0.006208.
```
