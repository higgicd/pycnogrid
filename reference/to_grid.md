# Pycnophylactic interpolation to a grid

Interpolates polygon counts to a regular or global discrete grid while
preserving source-zone totals.

## Usage

``` r
to_grid(
  source,
  value_col,
  id_col = NULL,
  grid_type = c("h3", "a5", "s2", "raster", "isea3h", "isea4h", "isea7h", "isea43h"),
  resolution,
  cell_inclusion = c("intersect", "centroid"),
  cell_allocation = c("area", "centroid"),
  nb_order = 1,
  max_iter = 500,
  tolerance = 1e-04,
  include_self = TRUE,
  missing_policy = c("abort", "warn", "ignore")
)
```

## Arguments

- source:

  An `sf` polygon object.

- value_col:

  Column containing the values to interpolate. May be supplied as an
  unquoted column name or a character string.

- id_col:

  Optional unique identifier column for source polygons.

- grid_type:

  Grid system to interpolate to. One of `"h3"`, `"a5"`, `"s2"`,
  `"isea3h"`, `"isea4h"`, `"isea7h"`, `"isea43h"`, or `"raster"`.

- resolution:

  Grid resolution. For H3, A5, S2, and ISEA grids this is the grid
  level. For raster grids this is the cell size in metres.

- cell_inclusion:

  Method used to determine which grid cells are included. One of
  `"intersect"` or `"centroid"`.

- cell_allocation:

  Method used to allocate source values to grid cells. One of `"area"`
  or `"centroid"`.

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
