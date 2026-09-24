# Set up real instruments

soundeR can play 128 real instruments, like piano, xylophone and cello,
through the fluidsynth package. They need a one-time download of a
"soundfont", a file of recorded instrument sounds (about 30 MB).
`sound_setup()` checks what's missing and downloads it.

## Usage

``` r
sound_setup()
```

## Value

`TRUE` if real instruments are ready, invisibly.

## Details

Without it, soundeR still works using its built-in synth sounds.

## Examples

``` r
if (FALSE) { # \dontrun{
sound_setup()
} # }
```
