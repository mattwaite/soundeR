# soundeR

Turn data into sound, the tidyverse way.

A chart turns numbers into shapes you can see. soundeR turns them into
sounds you can hear: higher numbers become higher notes, the gap between
two events becomes the silence between two notes, and a whole season
becomes a short tune. It’s built for people learning data analysis in R.
Give it a data frame, name a column, and print the result.

*The luge finals at the 2026 Winter Olympics, one note per sled at the
moment it crossed the line, after the New York Times’s 2010 “Fractions
of a Second: An Olympic Musical.”*

``` r

library(soundeR)

luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano")
```

## Installation

``` r

# install.packages("remotes")
remotes::install_github("mattwaite/soundeR")
```

For real instruments (piano, xylophone, cello and 125 more), run this
once. It downloads about 30 MB of instrument sounds:

``` r

soundeR::sound_setup()
```

Without it, soundeR uses its own built-in sounds.

## A season you can hear

`husker_games` holds every game of Nebraska men’s basketball’s 2025-26
season: 28-7, a 20-0 start, and the program’s first NCAA tournament
wins. Map the point margin to pitch, so bigger wins are higher notes:

``` r

husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180)
```

In RStudio or Positron, printing a sonification opens an audio player in
the Viewer pane. In Quarto and R Markdown documents, the player appears
on the page.
[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md) shows
the note each row became, and
[`save_sound()`](https://www.mattwaite.com/soundeR/reference/save_sound.md)
saves it as `.mp3`, `.wav` or `.mid`.

## Hearing a distribution

[`sonify_histogram()`](https://www.mattwaite.com/soundeR/reference/sonify_histogram.md)
is a histogram for your ears: it sweeps across the bins from low to
high, and the more rows in a bin, the higher the note. `ne_house_years`
counts Nebraska’s single-family houses by the year they were built:

``` r

ne_house_years |>
  sonify_histogram(year_built, weight = houses, binwidth = 1, instrument = "marimba")
```

With one bin per year, you can hear old houses piling up on round-number
years like 1900. With `binwidth = 10`, the spikes disappear and the
shape of a century of building comes through.

See
[`vignette("soundeR")`](https://www.mattwaite.com/soundeR/articles/soundeR.md)
for a full walkthrough, and
[`vignette("distributions")`](https://www.mattwaite.com/soundeR/articles/distributions.md)
for more on distributions.
