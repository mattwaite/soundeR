# Hear a distribution, like a histogram

`sonify_histogram()` is the sound version of
[`ggplot2::geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html).
It sorts a column of numbers into bins, then sweeps across them from the
lowest bin to the highest. Each bin is one note: the more rows in the
bin, the higher (and louder) the note. Empty bins are silent.

## Usage

``` r
sonify_histogram(
  data,
  x,
  weight = NULL,
  bins = NULL,
  binwidth = NULL,
  instrument = "piano",
  length = 20,
  bpm = NULL,
  log = FALSE,
  pan = FALSE,
  scale = "pentatonic",
  key = "C",
  range = c("C3", "C6"),
  engine = c("auto", "synth", "fluidsynth"),
  force = FALSE
)
```

## Arguments

- data:

  A data frame.

- x:

  A column of numbers whose distribution you want to hear.

- weight:

  Optional. A column of counts, for data that's already counted.

- bins:

  Number of bins. Use `bins` or `binwidth`, not both. If you give
  neither, soundeR uses 30 bins and suggests picking a `binwidth`.

- binwidth:

  How wide each bin is, in the units of `x`. Bins line up with multiples
  of `binwidth`, so `binwidth = 10` for years gives 1900 to 1909, 1910
  to 1919, and so on.

- instrument:

  The instrument to use (see
  [`instruments()`](https://www.mattwaite.com/soundeR/reference/instruments.md)).
  With more than one voice, one instrument per voice, in order or named
  by voice. Voices you leave out play the piano.

- length:

  Total length in seconds of the sweep.

- bpm:

  Notes (bins) per minute. Use instead of `length`.

- log:

  If `TRUE`, pitch follows the logarithm of the counts. That spreads out
  the notes when a few bins are much bigger than the rest.

- pan:

  If `TRUE`, the sound travels from your left speaker to your right as
  the sweep moves from the lowest bin to the highest, so you can hear
  where you are along the axis.

- scale:

  The musical scale that pitches snap to. See
  [`sound_scales()`](https://www.mattwaite.com/soundeR/reference/sound_scales.md).
  The default, `"pentatonic"`, sounds pleasant with any data. `"happy"`
  is another name for it, and `"sad"` switches to a minor pentatonic.
  With `"none"`, the built-in synth plays exact frequencies, but real
  instruments play the nearest semitone.

- key:

  The key of the scale, like `"C"`, `"G"` or `"Bb"`.

- range:

  The lowest and highest notes to use, like `c("C3", "C6")`.

- engine:

  How to make the sound. `"auto"` uses real instruments when the
  fluidsynth package and a soundfont are available, and the built-in
  synth otherwise. See
  [`sound_setup()`](https://www.mattwaite.com/soundeR/reference/sound_setup.md).

- force:

  Set to `TRUE` to allow sonifications longer than 20 minutes.

## Value

A `sonification` object. Print it to hear it, or pass it to
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
to see it as a histogram.

## Details

Like a histogram, what you hear depends on the bins. Try a few values of
`binwidth`: narrow bins show detail (and noise), wide bins show the
overall shape.

If your data is already counted, with one row per value and a column of
counts, give that column to `weight`.

[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md) on the
result has one row per non-empty bin: `bin_start` and `bin_end` give its
edges (each bin includes its start but not its end), `value` is its
count, and `row` is the bin's number, counting from the lowest.

## Examples

``` r
# Already-counted data: houses built in Nebraska, by year
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

# Raw values work too
sonify_histogram(data.frame(x = rnorm(500)), x, bins = 20, instrument = "bell")
20 notes · 20.0 seconds · bell
```
