# Save a sonification as a video with a moving chart

`sonify_video()` makes an MP4 video of your sonification: a chart of the
data, with a playhead that moves across it and dots that fill in as each
note plays, and the sound as the soundtrack. Videos are handy where
audio players aren't allowed, like a GitHub README, social media or
slides.

## Usage

``` r
sonify_video(
  x,
  path,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  x_label = NULL,
  y_label = NULL,
  theme = NULL,
  title_position = c("plot", "panel"),
  point_color = NULL,
  playhead_color = "#c8102e",
  highlight_color = "#f2efe6",
  width = 1280,
  height = 720,
  fps = 12
)
```

## Arguments

- x:

  A sonification made by
  [`sonify_data()`](https://mattwaite.github.io/soundeR/reference/sonify_data.md).

- path:

  Where to save the video. Must end in `.mp4`.

- title, subtitle, caption:

  Optional text for the chart.

- x_label, y_label:

  Axis labels. By default, the names of the columns you mapped.

- theme:

  Optional. A ggplot2 theme to change how the chart looks.

- title_position:

  `"plot"` (the default) lines titles and captions up with the whole
  image; `"panel"` lines them up with the plot panel.

- point_color:

  Color for the dots. With more than one voice, one color per voice, in
  order or named by voice; by default each voice gets its own color from
  a colorblind-friendly palette.

- playhead_color, highlight_color:

  Colors for the moving playhead and the band behind the row that's
  playing.

- width, height:

  Size of the video in pixels.

- fps:

  Frames per second. Higher is smoother but slower to make.

## Value

`path`, invisibly.

## Details

The chart depends on how you made the sonification:

- From
  [`sonify_histogram()`](https://mattwaite.github.io/soundeR/reference/sonify_histogram.md),
  a histogram whose bars fill in as the sweep passes them. From
  [`sonify_density()`](https://mattwaite.github.io/soundeR/reference/sonify_density.md),
  a curve that fills in the same way.

- With `sequence`, each group gets its own row, like the New York
  Times's 2010 Olympic Musical. The row that's playing is highlighted.

- Without `sequence`, the chart plots `pitch` (up the side) against
  `time` or row order (along the bottom).

### Changing the look

`theme` accepts any ggplot2 theme, just like adding one to a ggplot: a
complete theme such as
[`ggplot2::theme_classic()`](https://ggplot2.tidyverse.org/reference/ggtheme.html),
or a few changes such as
`ggplot2::theme(plot.title = ggplot2::element_text(size = 24))`. It's
added last, so it overrides soundeR's defaults.

Titles and captions line up with the edge of the whole image, not the
plot panel (`plot.title.position = "plot"`), even with a complete theme.
Use `title_position = "panel"` for ggplot2's default.

## Examples

``` r
if (FALSE) { # \dontrun{
luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano") |>
  sonify_video(
    "luge.mp4",
    title = "Fractions of a second",
    subtitle = "Each note is a sled crossing the finish line",
    x_label = "Seconds behind the winner",
    theme = ggplot2::theme_classic()
  )
} # }
```
