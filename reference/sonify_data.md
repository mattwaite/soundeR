# Turn a data frame into sound

`sonify_data()` turns each row of a data frame into a note. Map columns
to `pitch` (how high or low), `time` (when it plays) and `volume` (how
loud), pick an `instrument`, and print the result to hear it.

## Usage

``` r
sonify_data(
  data,
  pitch = NULL,
  time = NULL,
  volume = NULL,
  duration = NULL,
  pan = NULL,
  sequence = NULL,
  voice = NULL,
  instrument = "piano",
  bpm = 120,
  length = NULL,
  time_scale = NULL,
  gap = 1,
  scale = "pentatonic",
  key = "C",
  range = c("C3", "C6"),
  duration_range = c(0.1, 1.5),
  reverse = FALSE,
  engine = c("auto", "synth", "fluidsynth"),
  force = FALSE
)
```

## Arguments

- data:

  A data frame.

- pitch:

  A column (or calculation) to map to pitch. Bigger numbers are higher
  notes. Text and factors get one note per category. Leave it out to
  play every note at the same pitch. Use
  [`c()`](https://rdrr.io/r/base/c.html) to play several columns at
  once, one voice each.

- time:

  Optional. A column that decides when each note plays.

- volume:

  Optional. A column to map to loudness. Bigger is louder.

- duration:

  Optional. How long each note lasts. A number, like `duration = 0.2`,
  sets every note to that many seconds. A column makes bigger values
  longer notes, spread across `duration_range`. A column of durations
  (like `end - start`) plays in real time, times `time_scale` if you set
  it.

- pan:

  Optional. Where each note sits between your left and right speakers. A
  number from -1 (left) to 1 (right), or `"left"`, `"center"` or
  `"right"`, places every note. A column spreads bigger values to the
  right, and gives each category its own place. With more than one voice
  and no `pan`, the voices are spread across left and right
  automatically; use `pan = 0` to keep them all in the center.

- sequence:

  Optional. A column of groups to play one after another.

- voice:

  Optional. A column of groups, each played by its own instrument.

- instrument:

  The instrument to use (see
  [`instruments()`](https://mattwaite.github.io/soundeR/reference/instruments.md)).
  With more than one voice, one instrument per voice, in order or named
  by voice. Voices you leave out play the piano.

- bpm:

  Notes per minute when rows play in order.

- length:

  Total length in seconds. Use instead of `bpm`.

- time_scale:

  Seconds of sound per unit of `time` (seconds for times and durations,
  days for dates). Plays `time` in real time.

- gap:

  Seconds of silence between `sequence` groups.

- scale:

  The musical scale that pitches snap to. See
  [`sound_scales()`](https://mattwaite.github.io/soundeR/reference/sound_scales.md).
  The default, `"pentatonic"`, sounds pleasant with any data. `"happy"`
  is another name for it, and `"sad"` switches to a minor pentatonic.
  With `"none"`, the built-in synth plays exact frequencies, but real
  instruments play the nearest semitone.

- key:

  The key of the scale, like `"C"`, `"G"` or `"Bb"`.

- range:

  The lowest and highest notes to use, like `c("C3", "C6")`.

- duration_range:

  The shortest and longest notes, in seconds, when `duration` is a
  column of numbers or categories.

- reverse:

  If `TRUE`, bigger numbers become lower notes.

- engine:

  How to make the sound. `"auto"` uses real instruments when the
  fluidsynth package and a soundfont are available, and the built-in
  synth otherwise. See
  [`sound_setup()`](https://mattwaite.github.io/soundeR/reference/sound_setup.md).

- force:

  Set to `TRUE` to allow sonifications longer than 20 minutes.

## Value

A `sonification` object. Print it to hear it.

## Details

Nothing is played or saved until you print the result (or call
[`save_sound()`](https://mattwaite.github.io/soundeR/reference/save_sound.md)),
just like a ggplot isn't drawn until it's printed. Use
[`notes()`](https://mattwaite.github.io/soundeR/reference/notes.md) to
see exactly which note each row became.

### How timing works

- By default, rows play one after another in the order they appear,
  `bpm` notes per minute.

- `length` fits all the notes into that many seconds instead.

- `time` places each note according to a column: dates, times or
  numbers. The notes are spread out to fill the same total time.

- `time` together with `time_scale` plays your data in **real time**:
  `time_scale = 1` means one second of data is one second of sound, and
  `time_scale = 4` plays it four times slower.

- `sequence` plays groups (like events or games) one after another, with
  `gap` seconds of silence between them.

Grouping with
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
does not change the sound. Use `sequence` to hear groups in turn.

### More than one voice

There are two ways to play more than one instrument:

- Give `pitch` several columns, like
  `pitch = c(home_score, away_score)`. Each row plays one note per
  column at the same moment, and the columns share one pitch scale, so
  the same number is the same note in either column.

- Map a column to `voice`, like `voice = play_type`. Each note is played
  by the instrument for its group. Timing doesn't change.

Then give `instrument` one name per voice, either in order
(`c("xylophone", "cello")`) or by name
(`c(run = "tuba", pass = "harp")`).

## Examples

``` r
# A made-up season: points scored minus points allowed
season <- data.frame(
  game = 1:12,
  margin = c(12, -3, 8, 21, -15, 4, 7, -2, 18, -9, 3, 11)
)
s <- sonify_data(season, margin, instrument = "bell", bpm = 150)
notes(s)
#> # A tibble: 12 × 13
#>      row sequence voice onset duration  midi note   freq velocity   pan
#>    <int> <chr>    <chr> <dbl>    <dbl> <int> <chr> <dbl>    <int> <dbl>
#>  1     1 NA       NA      0        0.4    74 D5     587.      100     0
#>  2     2 NA       NA      0.4      0.4    60 C4     262.      100     0
#>  3     3 NA       NA      0.8      0.4    72 C5     523.      100     0
#>  4     4 NA       NA      1.2      0.4    84 C6    1047.      100     0
#>  5     5 NA       NA      1.6      0.4    48 C3     131.      100     0
#>  6     6 NA       NA      2        0.4    67 G4     392.      100     0
#>  7     7 NA       NA      2.4      0.4    69 A4     440       100     0
#>  8     8 NA       NA      2.8      0.4    60 C4     262.      100     0
#>  9     9 NA       NA      3.2      0.4    81 A5     880       100     0
#> 10    10 NA       NA      3.6      0.4    55 G3     196.      100     0
#> 11    11 NA       NA      4        0.4    67 G4     392.      100     0
#> 12    12 NA       NA      4.4      0.4    74 D5     587.      100     0
#> # ℹ 3 more variables: instrument <chr>, value <dbl>, time_value <lgl>

# Two voices at once: points for and against
scores <- data.frame(ours = c(70, 81, 64, 90), theirs = c(65, 84, 60, 72))
notes(sonify_data(scores, c(ours, theirs), instrument = c("bell", "pluck")))
#> # A tibble: 8 × 13
#>     row sequence voice  onset duration  midi note   freq velocity   pan
#>   <int> <chr>    <chr>  <dbl>    <dbl> <int> <chr> <dbl>    <int> <dbl>
#> 1     1 NA       ours     0        0.5    60 C4     262.      100  -0.6
#> 2     1 NA       theirs   0        0.5    55 G3     196.      100   0.6
#> 3     2 NA       ours     0.5      0.5    74 D5     587.      100  -0.6
#> 4     2 NA       theirs   0.5      0.5    76 E5     659.      100   0.6
#> 5     3 NA       ours     1        0.5    52 E3     165.      100  -0.6
#> 6     3 NA       theirs   1        0.5    48 C3     131.      100   0.6
#> 7     4 NA       ours     1.5      0.5    84 C6    1047.      100  -0.6
#> 8     4 NA       theirs   1.5      0.5    62 D4     294.      100   0.6
#> # ℹ 3 more variables: instrument <chr>, value <dbl>, time_value <lgl>

# One instrument per type of play
plays <- data.frame(
  yards = c(4, 12, 0, -2, 35),
  type = c("run", "pass", "incomplete", "run", "pass")
)
sonify_data(plays, yards, voice = type,
            instrument = c(run = "pluck", pass = "bell", incomplete = "square"))
5 notes · 2.5 seconds · pluck + bell + square

# A made-up race, played in real time like the NYT's 2010 Olympic Musical
race <- data.frame(behind = c(0, 0.09, 0.21, 0.30, 0.52, 0.55, 0.91, 1.34))
sonify_data(race, time = behind, time_scale = 2, instrument = "pluck")
8 notes · 3.2 seconds · pluck
```
