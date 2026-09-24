# List the instruments you can use

Built-in synth sounds (`"sine"`, `"triangle"`, `"square"`, `"bell"`,
`"pluck"`) work everywhere. The 128 General MIDI instruments, such as
`"piano"`, `"xylophone"` or `"cello"`, use real recorded sounds through
the fluidsynth package. See
[`sound_setup()`](https://mattwaite.github.io/soundeR/reference/sound_setup.md).

## Usage

``` r
instruments(family = NULL)
```

## Arguments

- family:

  Optionally, only list instruments in this family, such as `"brass"` or
  `"chromatic percussion"`.

## Value

A tibble with the instrument `name`, its `family`, which `engine` plays
it, and its General MIDI `program` number (0-based).

## Examples

``` r
instruments()
#> # A tibble: 133 × 4
#>    name                  family engine     program
#>    <chr>                 <chr>  <chr>        <int>
#>  1 sine                  synth  synth           NA
#>  2 triangle              synth  synth           NA
#>  3 square                synth  synth           NA
#>  4 bell                  synth  synth           NA
#>  5 pluck                 synth  synth           NA
#>  6 acoustic grand piano  piano  fluidsynth       0
#>  7 bright acoustic piano piano  fluidsynth       1
#>  8 electric grand piano  piano  fluidsynth       2
#>  9 honky-tonk piano      piano  fluidsynth       3
#> 10 electric piano 1      piano  fluidsynth       4
#> # ℹ 123 more rows
instruments("brass")
#> # A tibble: 8 × 4
#>   name          family engine     program
#>   <chr>         <chr>  <chr>        <int>
#> 1 trumpet       brass  fluidsynth      56
#> 2 trombone      brass  fluidsynth      57
#> 3 tuba          brass  fluidsynth      58
#> 4 muted trumpet brass  fluidsynth      59
#> 5 french horn   brass  fluidsynth      60
#> 6 brass section brass  fluidsynth      61
#> 7 synth brass 1 brass  fluidsynth      62
#> 8 synth brass 2 brass  fluidsynth      63
```
