# Draw a sonification as a chart

`sonify_plot()` draws the chart that
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
animates, as an ordinary ggplot, with every note played. Print it for a
picture of your sonification, or change it the way you'd change any
ggplot (add `labs()`, scales, annotations or a theme) and pass it to
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
with `plot =`. The video adds the moving playhead on top.

## Usage

``` r
sonify_plot(
  x,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  x_label = NULL,
  y_label = NULL,
  theme = NULL,
  title_position = c("plot", "panel"),
  point_color = NULL
)
```

## Arguments

- x:

  A sonification made by
  [`sonify_data()`](https://www.mattwaite.com/soundeR/reference/sonify_data.md),
  [`sonify_histogram()`](https://www.mattwaite.com/soundeR/reference/sonify_histogram.md)
  or
  [`sonify_density()`](https://www.mattwaite.com/soundeR/reference/sonify_density.md).

- title, subtitle, caption:

  Optional text for the chart.

- x_label, y_label:

  Axis labels. By default, the names of the columns you mapped.

- theme:

  Optional. A ggplot2 theme, complete (like
  [`ggplot2::theme_classic()`](https://ggplot2.tidyverse.org/reference/ggtheme.html))
  or partial (like
  `ggplot2::theme(plot.title = ggplot2::element_text(size = 24))`). It's
  added last, so it overrides soundeR's defaults.

- title_position:

  `"plot"` (the default) lines titles and captions up with the whole
  image; `"panel"` lines them up with the plot panel.

- point_color:

  Color for the dots (or bars, or curve). With more than one voice, one
  color per voice, in order or named by voice; by default each voice
  gets its own color from a colorblind-friendly palette.

## Value

A ggplot.

## Details

The chart depends on how you made the sonification:

- From
  [`sonify_histogram()`](https://www.mattwaite.com/soundeR/reference/sonify_histogram.md),
  a histogram. From
  [`sonify_density()`](https://www.mattwaite.com/soundeR/reference/sonify_density.md),
  a density curve.

- With `sequence`, each group gets its own row, like the New York
  Times's 2010 Olympic Musical.

- Otherwise, `pitch` (up the side) against `time` or row order (along
  the bottom).

Titles and captions line up with the edge of the whole image, not the
plot panel (`plot.title.position = "plot"`), even with a complete theme
given to `theme`. Use `title_position = "panel"` for ggplot2's default.
If you add a complete theme to the result yourself, with `+`, ggplot2
resets the title position, so add
`ggplot2::theme(plot.title.position = "plot")` after it.
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
lines titles up for you either way.

## Examples

``` r
if (FALSE) { # \dontrun{
race <- luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano")

# A picture of the sonification
sonify_plot(race)

# Customize it like any ggplot, then animate it
p <- sonify_plot(race) +
  ggplot2::labs(title = "Fractions of a second", x = "Seconds behind the winner") +
  ggplot2::scale_x_continuous(labels = function(s) paste0("+", s, " s"))
sonify_video(race, "luge.mp4", plot = p)
} # }
```
