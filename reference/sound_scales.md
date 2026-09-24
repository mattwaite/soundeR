# Musical scales available for pitch mapping

Musical scales available for pitch mapping

## Usage

``` r
sound_scales()
```

## Value

A character vector of scale names to use with the `scale` argument of
[`sonify_data()`](https://www.mattwaite.com/soundeR/reference/sonify_data.md).
`"none"` skips snapping, so pitches follow the data exactly. `"happy"`
and `"sad"` are friendly names for `"pentatonic"` (the default) and
`"minor_pentatonic"`.

## Examples

``` r
sound_scales()
#> [1] "pentatonic"       "minor_pentatonic" "major"            "minor"           
#> [5] "blues"            "chromatic"        "none"             "happy"           
#> [9] "sad"             
```
