# pycnogrid 0.2.1

* Changed the default `cell_allocation` from `"area"` to `"centroid"`. Centroid allocation preserves represented source-zone totals because each target cell is assigned to one source polygon.
* Marked `cell_allocation = "area"` as experimental. Fractional area allocation preserves the overall represented total but may not preserve individual source-zone totals when target cells overlap multiple sources.
* Added regression tests for individual source-zone preservation, including zero-valued source zones.

# pycnogrid 0.2.0

* Added `to_grid()` as the main interface for pycnophylactic interpolation to multiple grid systems.
* Added support for A5, S2, ISEA, local raster and local hex grids.
* Added `cell_inclusion` and `cell_allocation` options.
* Added support for higher-order neighbourhood smoothing.
* Added package vignette and expanded examples.
* Improved tests and CRAN-readiness.

# pycnogrid 0.1.0

* Initial development release.
* Added `to_h3()` for pycnophylactic interpolation to H3 grids.
* Added example NYC census tract datasets.
* Added unit tests and vignette infrastructure.
