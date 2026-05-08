# data-raw/nyc_example.R

library(dplyr)
library(sf)
library(tidycensus)
library(lehdr)

# download population data
nyc_ct <- tidycensus::get_acs(
  geography = "tract",
  variables = c(population = "B01001_001"),
  state = "36",
  county = c("061", "005", "047", "081", "085"),
  year = 2023,
  output = "wide",
  geometry = TRUE,
  keep_geo_vars = TRUE,
  cb = FALSE
) |>
  select(id = GEOID, populationE, geometry) |>
  st_transform(crs = 26918) |>
  tigris::erase_water()

# download employment data
ny_lodes_ct <- lehdr::grab_lodes(
  state = "ny",
  year = 2022,
  lodes_type = "wac",
  job_type = "JT00",
  segment = "S000",
  agg_geo = "tract"
) |>
  transmute(
    id = as.character(w_tract),
    employment = C000
  ) |>
  select(id, employment)

# join lodes to the census data
nyc_ct <- nyc_ct |>
  left_join(ny_lodes_ct, by = "id") |>
  mutate(employment = tidyr::replace_na(employment, 0))

# filter out a few examples
## brooklyn
#bk_ids <- c("36047001300", "36047001501", "36047003101", "36047001502", "36047001100")

## lower mahattan
lmh_ids <- c(
  "36061010900",
  "36061005200",
  "36061010100",
  "36061009700",
  "36061008300",
  "36061009100",
  "36061008000",
  "36061007400",
  "36061011300",
  "36061009500",
  "36061008200",
  "36061008900",
  "36061011100",
  "36061005000",
  "36061007200",
  "36061005400",
  "36061005600",
  "36061005800",
  "36061006800",
  "36061007600",
  "36061008100",
  "36061008400",
  "36061008700",
  "36061009300",
  "36061010300",
  "36061011500"
)

nyc_ct_small <- nyc_ct |>
  filter(id %in% lmh_ids)

# save into package
usethis::use_data(nyc_ct, nyc_ct_small, overwrite = TRUE)
