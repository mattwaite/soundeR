# Save a sonification as a sound file

The file type comes from the extension: `.wav` for plain audio, `.mp3`
for smaller files (needs the av package), or `.mid` for a MIDI file you
can open in GarageBand, MuseScore or other music software.

## Usage

``` r
save_sound(x, path)
```

## Arguments

- x:

  A sonification made by
  [`sonify_data()`](https://www.mattwaite.com/soundeR/reference/sonify_data.md).

- path:

  Where to save it, like `"season.wav"`.

## Value

`path`, invisibly.

## Examples

``` r
s <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "bell")
path <- tempfile(fileext = ".wav")
save_sound(s, path)
#> ✔ Saved /tmp/RtmpPdRcIy/file202d44ca7078.wav.
```
