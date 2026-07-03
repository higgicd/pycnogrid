# New York City census tract example data

Census tract population and employment data for New York City.

## Usage

``` r
nyc_ct
```

## Format

An sf object with:

- id:

  Census tract GEOID

- populationE:

  Estimated total population

- employment:

  Total employment

- geometry:

  MULTIPOLYGON geometry

## Source

U.S. Census Bureau American Community Survey 2023 5-year estimates; LEHD
LODES 2022. This product uses Census Bureau data but is not endorsed or
certified by the Census Bureau.

## Details

Population data were obtained from the American Community Survey using
the tidycensus package. Employment data were obtained from LEHD LODES
using the lehdr package.
