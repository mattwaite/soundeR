# Luge finals at the Milano Cortina 2026 Winter Olympics

Final results of all five luge events at the 2026 Winter Olympics, held
at the Cortina Sliding Centre in Cortina d'Ampezzo, Italy, Feb. 7-12,
2026. Luge is timed to the thousandth of a second, and medals are often
decided by less than a tenth. It's a natural fit for recreating the New
York Times's 2010 "Fractions of a Second: An Olympic Musical", which
played each finisher as a note at the moment they crossed the line.

## Usage

``` r
luge_finals
```

## Format

A tibble with 77 rows and 11 columns:

- event:

  The event: Men's singles, Women's singles, Men's doubles, Women's
  doubles or Team relay (a factor in that order).

- rank:

  Final place.

- bib:

  Start number.

- athlete:

  The athlete or athletes. Doubles partners are separated by " / ";
  relay team members are separated by commas.

- country:

  The country.

- run_1, run_2, run_3, run_4:

  Time for each run, in seconds. Doubles had two runs, so `run_3` and
  `run_4` are `NA`. For the team relay these are the four legs: women's
  singles, men's doubles, men's singles and women's doubles.

- total_time:

  Total time in seconds, the sum of the runs.

- behind:

  Seconds behind the winner of the event.

## Source

Wikipedia's results page for each event
(<https://en.wikipedia.org/wiki/Luge_at_the_2026_Winter_Olympics>),
which cites the official Olympic results. One total on Wikipedia (Timon
Grancagnolo, men's singles) has transposed digits. Here it is corrected
to the sum of his runs, which matches the page's own time-behind figure.
See `data-raw/luge_finals.R` in the package source.

## Details

Only sleds that completed every run are included. In singles, the top 20
after three runs advanced to the fourth, so the others' totals aren't
comparable.

## Examples

``` r
luge_finals
#> # A tibble: 77 × 11
#>    event    rank   bib athlete country run_1 run_2 run_3 run_4 total_time behind
#>    <fct>   <int> <int> <chr>   <chr>   <dbl> <dbl> <dbl> <dbl>      <dbl>  <dbl>
#>  1 Men's …     1     1 Max La… Germany  52.9  52.9  52.7  52.7       211.  0    
#>  2 Men's …     2     5 Jonas … Austria  53.0  53.0  52.8  53.0       212.  0.596
#>  3 Men's …     3    12 Domini… Italy    53.1  53.0  52.9  53.1       212.  0.934
#>  4 Men's …     4     3 Kriste… Latvia   53.2  53.1  53.2  53.1       213.  1.42 
#>  5 Men's …     5     6 Nico G… Austria  53.3  53.4  53.1  53.2       213.  1.78 
#>  6 Men's …     6     2 Felix … Germany  53.4  53.3  53.2  53.1       213.  1.86 
#>  7 Men's …     7    10 Leon F… Italy    53.2  53.4  53.2  53.3       213.  1.93 
#>  8 Men's …     8     8 Wolfga… Austria  53.4  53.3  53.2  53.4       213.  2.07 
#>  9 Men's …     9     9 Timon … Germany  53.4  53.4  53.5  53.1       213.  2.30 
#> 10 Men's …    10     4 Gints … Latvia   53.5  53.4  53.4  53.7       214.  2.85 
#> # ℹ 67 more rows

# Hear each event's finishers cross the line, four times slower than real life
luge_finals |>
  sonify_data(time = behind, time_scale = 4, sequence = event, instrument = "bell")
77 notes · 111.8 seconds · bell
```
