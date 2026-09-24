# Your first sonification

A chart turns numbers into shapes you can see. A **sonification** turns
numbers into sounds you can hear. Higher numbers can become higher
notes, the gap between two events can become the silence between two
notes, and a whole season of games can become a short tune.

soundeR does this with one function,
[`sonify_data()`](https://www.mattwaite.com/soundeR/reference/sonify_data.md).
It works like the rest of the tidyverse: give it a data frame, tell it
which columns to listen to, and print the result. In RStudio or Positron
an audio player appears in the Viewer pane. In a Quarto or R Markdown
document, like this one, the player appears on the page.

``` r

library(soundeR)
library(dplyr)
```

## Real instruments (one-time setup)

soundeR can play 128 real instruments, from piano to xylophone to cello.
They need a one-time download of instrument sounds, about 30 MB:

``` r

sound_setup()
```

If you skip this, everything still works. soundeR uses its own built-in
sounds instead and tells you when it does.

## Fractions of a second

In 2010, during the Vancouver Winter Olympics, The New York Times
published “Fractions of a Second: An Olympic Musical.” For each event,
it played one note for every athlete at the moment they crossed the
finish line, spaced by how far they finished behind the winner. You
could *hear* how close the races were.

We can rebuild that with `luge_finals`, the results of every luge event
at the 2026 Winter Olympics in Milan and Cortina d’Ampezzo:

``` r

luge_finals |>
  select(event, rank, athlete, country, total_time, behind)
#> # A tibble: 77 × 6
#>    event          rank athlete             country total_time behind
#>    <fct>         <int> <chr>               <chr>        <dbl>  <dbl>
#>  1 Men's singles     1 Max Langenhan       Germany       211.  0    
#>  2 Men's singles     2 Jonas Müller        Austria       212.  0.596
#>  3 Men's singles     3 Dominik Fischnaller Italy         212.  0.934
#>  4 Men's singles     4 Kristers Aparjods   Latvia        213.  1.42 
#>  5 Men's singles     5 Nico Gleirscher     Austria       213.  1.78 
#>  6 Men's singles     6 Felix Loch          Germany       213.  1.86 
#>  7 Men's singles     7 Leon Felderer       Italy         213.  1.93 
#>  8 Men's singles     8 Wolfgang Kindl      Austria       213.  2.07 
#>  9 Men's singles     9 Timon Grancagnolo   Germany       213.  2.30 
#> 10 Men's singles    10 Gints Bērziņš       Latvia        214.  2.85 
#> # ℹ 67 more rows
```

`behind` is how many seconds each sled finished behind the winner of its
event. Let’s listen to the men’s singles final:

``` r

mens_singles <- luge_finals |>
  filter(event == "Men's singles")

mens_singles |>
  sonify_data(time = behind, time_scale = 1, instrument = "piano")
```

There’s no pitch here. Every note is the same. Only two things matter:

- `time = behind` decides **when** each note plays. The winner, 0
  seconds behind, plays first.
- `time_scale = 1` plays it in **real time**: one second of data is one
  second of sound.

Max Langenhan won by 0.596 seconds, and you can hear the gap before the
second note. Now try the men’s doubles, where gold and silver were
separated by 0.068 seconds. In real time those first notes nearly blur
together, so slow it down four times with `time_scale = 4`:

``` r

luge_finals |>
  filter(event == "Men's doubles") |>
  sonify_data(time = behind, time_scale = 4, instrument = "piano")
```

To hear every event, one after another like the original, use
`sequence`. It plays each group in turn, with a second of silence
between them:

``` r

luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano")
```

### Working it out yourself

`luge_finals` already has a `behind` column, but real data usually
won’t. You can compute it with
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html) and
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html):

``` r

luge_finals |>
  group_by(event) |>
  mutate(seconds_behind = total_time - min(total_time)) |>
  sonify_data(time = seconds_behind, time_scale = 1, sequence = event, instrument = "piano")
```

Grouping your data doesn’t change the sound by itself.
`sequence = event` is what plays the events one at a time. If you pass
grouped data without `sequence`, soundeR reminds you of that.

## What did the data become?

Every row became a note.
[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md) shows
you exactly which one, the same way you’d look at the data behind a
chart:

``` r

race <- mens_singles |>
  sonify_data(time = behind, time_scale = 1, instrument = "piano")

notes(race)
#> # A tibble: 20 × 13
#>      row sequence voice onset duration  midi note   freq velocity   pan
#>    <int> <chr>    <chr> <dbl>    <dbl> <int> <chr> <dbl>    <int> <dbl>
#>  1     1 NA       NA    0          0.5    72 C5     523.      100     0
#>  2     2 NA       NA    0.596      0.5    72 C5     523.      100     0
#>  3     3 NA       NA    0.934      0.5    72 C5     523.      100     0
#>  4     4 NA       NA    1.42       0.5    72 C5     523.      100     0
#>  5     5 NA       NA    1.78       0.5    72 C5     523.      100     0
#>  6     6 NA       NA    1.86       0.5    72 C5     523.      100     0
#>  7     7 NA       NA    1.93       0.5    72 C5     523.      100     0
#>  8     8 NA       NA    2.07       0.5    72 C5     523.      100     0
#>  9     9 NA       NA    2.30       0.5    72 C5     523.      100     0
#> 10    10 NA       NA    2.85       0.5    72 C5     523.      100     0
#> 11    11 NA       NA    3.24       0.5    72 C5     523.      100     0
#> 12    12 NA       NA    3.58       0.5    72 C5     523.      100     0
#> 13    13 NA       NA    3.70       0.5    72 C5     523.      100     0
#> 14    14 NA       NA    3.77       0.5    72 C5     523.      100     0
#> 15    15 NA       NA    3.80       0.5    72 C5     523.      100     0
#> 16    16 NA       NA    4.01       0.5    72 C5     523.      100     0
#> 17    17 NA       NA    4.02       0.5    72 C5     523.      100     0
#> 18    18 NA       NA    4.36       0.5    72 C5     523.      100     0
#> 19    19 NA       NA    4.41       0.5    72 C5     523.      100     0
#> 20    20 NA       NA    4.68       0.5    72 C5     523.      100     0
#> # ℹ 3 more variables: instrument <chr>, value <lgl>, time_value <dbl>
```

`row` matches the row of your data, `onset` is the second the note
starts, `note` is its name (C5 is the C an octave above middle C), and
`value` is the number it came from.

## A season you can hear

`husker_games` holds every game of Nebraska men’s basketball’s 2025-26
season, the best in program history: 28 wins, a 20-0 start, and the
program’s first NCAA tournament wins.

``` r

husker_games |>
  select(game_number, date, opponent, husker_score, opponent_score, point_margin)
#> # A tibble: 35 × 6
#>    game_number date       opponent      husker_score opponent_score point_margin
#>          <int> <date>     <chr>                <int>          <int>        <int>
#>  1           1 2025-11-03 West Georgia            86             53           33
#>  2           2 2025-11-08 Florida Inte…           96             66           30
#>  3           3 2025-11-11 Maryland Eas…           69             50           19
#>  4           4 2025-11-15 Oklahoma               105             99            6
#>  5           5 2025-11-20 New Mexico              84             72           12
#>  6           6 2025-11-21 Kansas State            86             85            1
#>  7           7 2025-11-25 Winthrop                80             73            7
#>  8           8 2025-11-29 South Caroli…           72             63            9
#>  9           9 2025-12-07 Creighton               71             50           21
#> 10          10 2025-12-10 Wisconsin               90             60           30
#> # ℹ 25 more rows
```

This time, let’s map `point_margin` to **pitch**. Bigger wins are higher
notes, and losses are the lowest:

``` r

husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180)
```

Each game is one note, played in order, 180 notes per minute. Listen for
the long run of high notes during the 20-0 start, then the first low
note: a three-point loss at Michigan in late January.

The pitches snap to a **pentatonic scale**, the five-note scale you get
from only the black keys of a piano. Any data sounds reasonably musical
on it. The real numbers are still there in
[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md).

### Your choices change what people hear

Just like the axes and colors of a chart, the choices you make shape
what a listener takes away.

Turn `scale` off and pitches follow the numbers exactly. It’s more
precise, but harder to listen to:

``` r

husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180, scale = "none")
```

The scale sets the mood, too. `scale = "sad"` plays the same shape in a
minor key, and suddenly a 28-win season sounds like a lament. (The
default is `scale = "happy"`.)

``` r

husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180, scale = "sad")
```

Narrow the `range` of notes and a dominant season sounds a lot more
ordinary:

``` r

husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180, range = c("C4", "G4"))
```

You can map loudness, too. Here the postseason gets louder: `game_type`
has three levels (regular season, Big Ten tournament and NCAA
tournament), and each level is louder than the one before:

``` r

husker_games |>
  sonify_data(point_margin, volume = game_type, instrument = "xylophone", bpm = 180)
```

`duration` sets how long each note rings. A number sets every note to
that many seconds, so `duration = 0.1` makes short, crisp notes that are
easier to tell apart at a fast tempo. A column works too: bigger values
ring longer.

``` r

husker_games |>
  sonify_data(point_margin, duration = 0.1, instrument = "xylophone", bpm = 180)
```

And instead of one note per row, `time = date` places each game on the
calendar. `length = 20` fits the whole season into 20 seconds. Listen
for the gaps: the break around Christmas, and the waits between
tournament rounds.

``` r

husker_games |>
  sonify_data(point_margin, time = date, length = 20, instrument = "marimba")
```

## Picking an instrument

[`instruments()`](https://www.mattwaite.com/soundeR/reference/instruments.md)
lists everything you can use:

``` r

instruments()
#> # A tibble: 133 × 6
#>    name                  family engine     program low   high 
#>    <chr>                 <chr>  <chr>        <int> <chr> <chr>
#>  1 sine                  synth  synth           NA C3    C6   
#>  2 triangle              synth  synth           NA C3    C6   
#>  3 square                synth  synth           NA C3    C6   
#>  4 bell                  synth  synth           NA C3    C6   
#>  5 pluck                 synth  synth           NA C3    C6   
#>  6 acoustic grand piano  piano  fluidsynth       0 C3    C6   
#>  7 bright acoustic piano piano  fluidsynth       1 C3    C6   
#>  8 electric grand piano  piano  fluidsynth       2 C3    C6   
#>  9 honky-tonk piano      piano  fluidsynth       3 C3    C6   
#> 10 electric piano 1      piano  fluidsynth       4 C3    C6   
#> # ℹ 123 more rows
```

The first five are soundeR’s built-in sounds, which work everywhere. The
rest are real instruments. `low` and `high` show each one’s usual range:
unless you set `range` yourself, notes stay inside it, so a tuba plays
low and a piccolo plays high. You can also filter by family:

``` r

instruments("chromatic percussion")
#> # A tibble: 8 × 6
#>   name          family               engine     program low   high 
#>   <chr>         <chr>                <chr>        <int> <chr> <chr>
#> 1 celesta       chromatic percussion fluidsynth       8 C4    C7   
#> 2 glockenspiel  chromatic percussion fluidsynth       9 C5    C8   
#> 3 music box     chromatic percussion fluidsynth      10 C4    C7   
#> 4 vibraphone    chromatic percussion fluidsynth      11 F3    F6   
#> 5 marimba       chromatic percussion fluidsynth      12 C3    C6   
#> 6 xylophone     chromatic percussion fluidsynth      13 C4    C7   
#> 7 tubular bells chromatic percussion fluidsynth      14 C4    G5   
#> 8 dulcimer      chromatic percussion fluidsynth      15 C3    C6
```

## More than one voice

So far every note has come from one instrument. There are two ways to
use more.

### Two columns at once

List more than one column in `pitch` and each row plays one note per
column at the same moment. Here Nebraska’s score is the marimba and the
opponent’s score is the cello:

``` r

husker_games |>
  sonify_data(c(husker_score, opponent_score), instrument = c("marimba", "cello"), bpm = 150)
```

Both columns share one pitch scale, so 70 points is the same note
whichever team scored it. That’s what makes the comparison audible: in a
close game, like the 58-56 win over Michigan State on Jan. 2, the two
notes are nearly the same. In a blowout, like the 90-55 win over Oregon
on Jan. 13, they’re far apart.

Put on headphones and you’ll also hear the two voices in different
places: with more than one voice, soundeR spreads them from left to
right. The `pan` column in
[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md) says
where each note sits, from -1 (left) to 1 (right). Use `pan = "left"`,
`pan = "right"` or any number in between to place notes yourself,
`pan = 0` to keep everything in the center, or map a column, like
`pan = location`, to spread groups across the stereo field.

[`notes()`](https://www.mattwaite.com/soundeR/reference/notes.md) shows
which voice each note belongs to:

``` r

husker_games |>
  sonify_data(c(husker_score, opponent_score), instrument = c("marimba", "cello")) |>
  notes() |>
  select(row, voice, onset, note, pan, instrument, value)
#> # A tibble: 70 × 7
#>      row voice          onset note    pan instrument value
#>    <int> <chr>          <dbl> <chr> <dbl> <chr>      <int>
#>  1     1 husker_score     0   E4     -0.6 marimba       86
#>  2     1 opponent_score   0   D3      0.6 cello         53
#>  3     2 husker_score     0.5 A4     -0.6 marimba       96
#>  4     2 opponent_score   0.5 G3      0.6 cello         66
#>  5     3 husker_score     1   A3     -0.6 marimba       69
#>  6     3 opponent_score   1   D3      0.6 cello         50
#>  7     4 husker_score     1.5 C5     -0.6 marimba      105
#>  8     4 opponent_score   1.5 A4      0.6 cello         99
#>  9     5 husker_score     2   E4     -0.6 marimba       84
#> 10     5 opponent_score   2   A3      0.6 cello         72
#> # ℹ 60 more rows
```

### An instrument for each group

To give each *kind* of row its own sound, map a column to `voice` and
name an instrument for each group. Here wins are the marimba and losses
the cello:

``` r

husker_games |>
  sonify_data(point_margin, voice = result,
              instrument = c(W = "marimba", L = "cello"), bpm = 150)
```

`voice` only changes which instrument plays a note, not when it plays.
The games still play in order. (Here the instrument repeats what pitch
already says, since losses are the low notes anyway. Saying the same
thing two ways can make a pattern easier to hear, just as color and
position can double up in a chart.)

If you leave a group out of the list, soundeR plays it on the piano and
tells you which groups it filled in.

## Saving your sound

[`save_sound()`](https://www.mattwaite.com/soundeR/reference/save_sound.md)
saves a sonification as a file. The ending of the file name picks the
format:

``` r

season <- husker_games |>
  sonify_data(point_margin, instrument = "xylophone", bpm = 180)

save_sound(season, "husker-season.mp3") # to share
save_sound(season, "husker-season.wav") # uncompressed audio
save_sound(season, "husker-season.mid") # to open in GarageBand or MuseScore
```

## Making a video

Audio players don’t work everywhere. GitHub, most social media sites and
some slide software won’t play them.
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
turns a sonification into an MP4 video: a chart of your data, with a
playhead that moves across it and dots that fill in as each note plays.

``` r

luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano") |>
  sonify_video(
    "luge.mp4",
    title = "Fractions of a second: luge at the 2026 Winter Olympics",
    subtitle = "Each note is a sled crossing the finish line, in real time",
    x_label = "Seconds behind the winner"
  )
```

With `sequence`, each group gets its own row and the one that’s playing
is highlighted. Without it, the chart plots your `pitch` column against
time. With more than one voice, each voice gets its own color.

The chart is a ggplot, so you can change its look with any ggplot2
theme, the same way you would with a ggplot:

``` r

husker_games |>
  sonify_data(c(husker_score, opponent_score), instrument = c("marimba", "cello")) |>
  sonify_video(
    "husker-scores.mp4",
    title = "Nebraska vs. opponents, 2025-26",
    x_label = "Game",
    y_label = "Points",
    theme = ggplot2::theme_classic(base_size = 16)
  )
```

Titles line up with the left edge of the whole image, not the plot
panel, even with a theme like `theme_classic()`. Making a video takes
about as long as the sound itself: a 30-second sonification takes about
30 seconds to draw.

To change more than the title, labels and theme, draw the chart yourself
with
[`sonify_plot()`](https://www.mattwaite.com/soundeR/reference/sonify_plot.md).
It returns an ordinary ggplot, with every note played, so you can add
scales, annotations or anything else. Then hand it to
[`sonify_video()`](https://www.mattwaite.com/soundeR/reference/sonify_video.md)
with `plot =`, and the video adds the moving playhead on top:

``` r

race <- luge_finals |>
  sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano")

p <- sonify_plot(race) +
  ggplot2::labs(title = "Fractions of a second", x = NULL) +
  ggplot2::scale_x_continuous(
    breaks = 0:8,
    labels = function(s) ifelse(s == 0, "Winner", paste0("+", s, " s"))
  ) +
  ggplot2::annotate("text", x = 1.9, y = "Men's doubles",
                    label = "0.068 s between gold and silver", hjust = 0, vjust = -1.2)

sonify_video(race, "luge.mp4", plot = p)
```

[`sonify_plot()`](https://www.mattwaite.com/soundeR/reference/sonify_plot.md)
on its own is handy too, for a picture of your sonification in a report.

## Things to try

- Which luge podium was closer, men’s singles or women’s singles? Listen
  first, then check with
  [`filter()`](https://dplyr.tidyverse.org/reference/filter.html) and
  [`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html).
- In the luge, map `pitch = rank` and add `reverse = TRUE` so the winner
  plays the highest note. Does that make it easier to follow?
- Play the Husker season sorted by `point_margin` with
  [`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html).
  What does the sound tell you now that it didn’t before, and what did
  you lose?
- Give each `location` (home, away and neutral) its own instrument with
  `voice`. Can you hear whether Nebraska played differently on the road?
- In the two-score version, try `scale = "chromatic"`. The notes clash
  more. Does that make close games easier or harder to hear?
- Pick a column from your own data. What should be high, what should be
  loud, and what should decide when a note plays?
