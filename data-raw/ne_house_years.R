## Prepare `ne_house_years`: the number of single-family houses in Nebraska by
## the year they were built, compiled by Matt Waite from a statewide parcel
## file provided by the state's Office of the Chief Information Officer.
## About 13,000 parcels have NA for the build year and aren't included.
## The file's documentation isn't online yet (Matt is getting it), so the
## docs describe the round-number heaping without explaining it.
## The raw file (data-raw/ne_house_years.csv) has columns building_year and n;
## here they're renamed to year_built and houses.

raw <- read.csv("data-raw/ne_house_years.csv")

ne_house_years <- tibble::tibble(
  year_built = as.integer(raw$building_year),
  houses = as.integer(raw$n)
)
ne_house_years <- ne_house_years[order(ne_house_years$year_built), ]

stopifnot(
  nrow(ne_house_years) == 182,
  sum(ne_house_years$houses) == 515985,
  !anyDuplicated(ne_house_years$year_built),
  all(ne_house_years$houses > 0),
  min(ne_house_years$year_built) == 1800,
  max(ne_house_years$year_built) == 2026,
  ne_house_years$houses[ne_house_years$year_built == 1900] == 19205
)

usethis::use_data(ne_house_years, overwrite = TRUE)
