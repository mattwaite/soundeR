# List the instruments you can use

Built-in synth sounds (`"sine"`, `"triangle"`, `"square"`, `"bell"`,
`"pluck"`) work everywhere. The 128 General MIDI instruments, such as
`"piano"`, `"xylophone"` or `"cello"`, use real recorded sounds through
the fluidsynth package. See
[`sound_setup()`](https://www.mattwaite.com/soundeR/reference/sound_setup.md).

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
it, its General MIDI `program` number (0-based), and the `low` and
`high` notes of its usual range. Notes stay in that range unless you set
`range` yourself.

## Examples

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
instruments("brass")
#> # A tibble: 8 × 6
#>   name          family engine     program low   high 
#>   <chr>         <chr>  <chr>        <int> <chr> <chr>
#> 1 trumpet       brass  fluidsynth      56 G3    C6   
#> 2 trombone      brass  fluidsynth      57 E2    E5   
#> 3 tuba          brass  fluidsynth      58 D1    D4   
#> 4 muted trumpet brass  fluidsynth      59 G3    C6   
#> 5 french horn   brass  fluidsynth      60 F2    F5   
#> 6 brass section brass  fluidsynth      61 C3    C6   
#> 7 synth brass 1 brass  fluidsynth      62 C3    C6   
#> 8 synth brass 2 brass  fluidsynth      63 C3    C6   
```
