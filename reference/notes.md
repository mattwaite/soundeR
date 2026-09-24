# See the notes in a sonification

Every row of your data becomes a note. `notes()` shows the result as a
tibble: when each note starts (`onset`, in seconds), how long it lasts,
its pitch (as a MIDI number, a note name and a frequency in hertz), how
loud it is (`velocity`, 1 to 127), and the data `value` it came from. If
you mapped `time`, `time_value` holds the original time. The `row`
column matches the row number in your original data.

## Usage

``` r
notes(x)
```

## Arguments

- x:

  A sonification made by
  [`sonify_data()`](https://mattwaite.github.io/soundeR/reference/sonify_data.md).

## Value

A tibble with one row per note.

## Examples

``` r
s <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "sine")
notes(s)
#> # A tibble: 3 × 13
#>     row sequence voice onset duration  midi note   freq velocity   pan
#>   <int> <chr>    <chr> <dbl>    <dbl> <int> <chr> <dbl>    <int> <dbl>
#> 1     1 NA       NA      0        0.5    48 C3     131.      100     0
#> 2     2 NA       NA      0.5      0.5    84 C6    1047.      100     0
#> 3     3 NA       NA      1        0.5    67 G4     392.      100     0
#> # ℹ 3 more variables: instrument <chr>, value <dbl>, time_value <lgl>
```
