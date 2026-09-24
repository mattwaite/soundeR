# Houses built in Nebraska, by year

The number of single-family houses in Nebraska by the year they were
built, from 1800 to 2026, compiled from parcel records. It's already
counted, one row per year, so give `houses` to the `weight` argument of
[`sonify_histogram()`](https://mattwaite.github.io/soundeR/reference/sonify_histogram.md).

## Usage

``` r
ne_house_years
```

## Format

A tibble with 182 rows and 2 columns:

- year_built:

  The year the house was built.

- houses:

  How many single-family houses were built that year.

## Source

Compiled by Matt Waite from Nebraska parcel records. See
`data-raw/ne_house_years.R` in the package source.

## Details

A few things to know before you listen:

- **Round-number years.** Before 1950, 42% of houses have a year ending
  in 0, where you'd expect about 10%, and 58% end in 0 or 5. 1900 alone
  has 19,205 houses, compared with 730 in 1901. From 1980 on the pattern
  mostly disappears. Why old houses pile up on round numbers isn't
  documented yet. With one bin per year, you can hear it.

- **Recent years are incomplete.** 2025 (408 houses) and 2026 (1) were
  only partly recorded when the data was compiled, so they're far lower
  than the years before them. That's not a housing crash.

- **Missing years.** 45 of the years between 1800 and 2026 have no
  houses and no row.

- **Unknown years.** About 13,000 parcels have no build year recorded.
  They aren't included.

## Examples

``` r
ne_house_years
#> # A tibble: 182 × 2
#>    year_built houses
#>         <int>  <int>
#>  1       1800      4
#>  2       1820      1
#>  3       1821      1
#>  4       1840      2
#>  5       1848      1
#>  6       1849      2
#>  7       1850     10
#>  8       1851      1
#>  9       1853      1
#> 10       1854      3
#> # ℹ 172 more rows

# One bin per decade
ne_house_years |>
  sonify_histogram(year_built, weight = houses, binwidth = 10, instrument = "marimba")
21 notes · 20.0 seconds · marimba
```
