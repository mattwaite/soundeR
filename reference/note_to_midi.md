# Convert between note names and MIDI note numbers

MIDI numbers pitches from 0 to 127, with middle C (`"C4"`) at 60 and
concert A (`"A4"`, 440 Hz) at 69. Note names use a letter, an optional
sharp (`#`) or flat (`b`), and an octave number.

## Usage

``` r
note_to_midi(x)

midi_to_note(x)

midi_to_freq(x)
```

## Arguments

- x:

  For `note_to_midi()`, a character vector of note names such as `"C4"`,
  `"F#3"` or `"Bb5"`. Numbers are passed through unchanged. For
  `midi_to_note()` and `midi_to_freq()`, MIDI note numbers.

## Value

`note_to_midi()` returns integers, `midi_to_note()` returns note names
(always spelled with sharps), and `midi_to_freq()` returns frequencies
in hertz.

## Examples

``` r
note_to_midi(c("C4", "A4", "F#3", "Bb5"))
#> [1] 60 69 54 82
midi_to_note(60:64)
#> [1] "C4"  "C#4" "D4"  "D#4" "E4" 
midi_to_freq(69)
#> [1] 440
```
