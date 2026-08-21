# Pycnophylactic interpolation to a grid

Interpolates polygon counts to a regular or global discrete grid.
Centroid allocation preserves represented source-zone totals while
smoothing densities across neighboring target cells. Areal allocation
preserves global totals.

## Usage

``` r
to_grid(
  source,
  value_col,
  id_col = NULL,
  grid_type = c("h3", "a5", "s2", "isea3h", "isea4h", "raster", "hex"),
  resolution,
  cell_inclusion = c("intersect", "centroid"),
  cell_allocation = c("centroid", "area"),
  nb_order = 1,
  max_iter = 500,
  tolerance = 1e-04,
  include_self = TRUE,
  missing_policy = c("abort", "warn", "ignore")
)
```

## Arguments

- source:

  An `sf` polygon object in a projected CRS.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- id_col:

  Optional unique identifier column for source polygons.

- grid_type:

  Grid system to interpolate to. One of `"h3"`, `"a5"`, `"s2"`,
  `"isea3h"`, `"isea4h"`, `"raster"`, or `"hex"`.

- resolution:

  Grid resolution. For H3, A5, S2, and ISEA grids this is the grid
  level. For local raster and hex grids this is the cell size in the
  linear units of the input projected CRS.

- cell_inclusion:

  Method used to determine which grid cells are included. One of
  `"intersect"` or `"centroid"`.

- cell_allocation:

  Method used to allocate source values to grid cells. `"centroid"`, the
  default, assigns each target cell to the source polygon containing its
  centroid and preserves represented source-zone totals. `"area"` uses
  fractional source-cell overlap areas. Area allocation is experimental:
  it preserves the overall represented total but may not preserve each
  individual source-zone total.

- nb_order:

  Neighbourhood order used for smoothing. A value of `1` uses
  first-order neighbours; larger values include higher-order neighbours.

- max_iter:

  Maximum number of pycnophylactic smoothing iterations. If `0`, returns
  the initial allocation without smoothing.

- tolerance:

  Convergence tolerance based on relative mean density change.

- include_self:

  Logical. Should each cell include itself when smoothing?

- missing_policy:

  How to handle source polygons that receive no grid cells. One of
  `"abort"`, `"warn"`, or `"ignore"`.

## Value

An `sf` object containing grid-cell geometries and interpolated values.

## Details

With `cell_allocation = "centroid"`, each represented target cell
belongs to one source polygon. The correction step therefore preserves
the total associated with each represented source zone.

With `cell_allocation = "area"`, target cells may overlap several source
polygons. The current fractional correction preserves the overall
represented total but does not guarantee preservation of every
individual source-zone total. This mode is experimental.

## Examples

``` r
out <- to_grid(
  source = nyc_ct_small,
  value_col = populationE,
  grid_type = "h3",
  resolution = 9,
  max_iter = 5
)
```
