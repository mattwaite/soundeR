# Hear a distribution as a smooth curve

`sonify_density()` is the sound version of
[`ggplot2::geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html).
It draws a smooth curve through the distribution of a column, then
sweeps across it from the lowest value to the highest. By default you
hear one continuous tone that glides up where the data is dense and down
where it's sparse, and gets quieter where there's little data.

## Usage

``` r
sonify_density(
  data,
  x,
  weight = NULL,
  adjust = 1,
  glide = TRUE,
  instrument = if (glide) "triangle" else "piano",
  length = 10,
  points = 120,
  scale = "pentatonic",
  key = "C",
  range = c("C3", "C6"),
  pan = FALSE,
  engine = c("auto", "synth", "fluidsynth")
)
```

## Arguments

- data:

  A data frame.

- x:

  A column of numbers whose distribution you want to hear.

- weight:

  Optional. A column of counts, for data that's already counted.

- adjust:

  Make the curve smoother (bigger) or more detailed (smaller). `2` is
  twice as smooth as the default.

- glide:

  If `TRUE` (the default), one continuous gliding tone. If `FALSE`, a
  run of notes, which works with any instrument.

- instrument:

  The sound to use. With `glide = TRUE`, `"sine"`, `"triangle"` or
  `"square"`.

- length:

  Total length in seconds of the sweep.

- points:

  How many points along the curve to use.

- scale:

  The musical scale notes snap to when `glide = FALSE`. See
  [`sound_scales()`](https://mattwaite.github.io/soundeR/reference/sound_scales.md).
  The glide always follows the curve exactly.

- key:

  The key of the scale, like `"C"`, `"G"` or `"Bb"`.

- range:

  The lowest and highest notes to use, like `c("C3", "C6")`.

- pan:

  If `TRUE`, the sound travels from your left speaker to your right as
  the sweep moves across the curve.

- engine:

  How to make the sound. `"auto"` uses real instruments when the
  fluidsynth package and a soundfont are available, and the built-in
  synth otherwise. See
  [`sound_setup()`](https://mattwaite.github.io/soundeR/reference/sound_setup.md).

## Value

A `sonification` object. Print it to hear it, or pass it to
[`sonify_video()`](https://mattwaite.github.io/soundeR/reference/sonify_video.md)
to see the curve.

## Details

`adjust` controls how smooth the curve is, just like in
`geom_density()`: bigger values smooth more, smaller values show more
detail.

The glide uses soundeR's built-in sounds (`"sine"`, `"triangle"` or
`"square"`), because real instruments play separate notes. With
`glide = FALSE`, the curve is played as a quick run of notes instead,
and any instrument works.

[`notes()`](https://mattwaite.github.io/soundeR/reference/notes.md) on
the result has one row per point along the curve: `x_value` is where the
point sits, `value` is the curve's height there.

## Examples

``` r
sonify_density(data.frame(x = c(rnorm(300), rnorm(100, 4))), x)
120 notes · 10.0 seconds · triangle

# Already-counted data
ne_house_years |>
  sonify_density(year_built, weight = houses, adjust = 4)
120 notes · 10.0 seconds · triangle
```
