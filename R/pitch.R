note_names <- c("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
pitch_class <- c(C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11)

#' Convert between note names and MIDI note numbers
#'
#' MIDI numbers pitches from 0 to 127, with middle C (`"C4"`) at 60 and
#' concert A (`"A4"`, 440 Hz) at 69. Note names use a letter, an optional
#' sharp (`#`) or flat (`b`), and an octave number.
#'
#' @param x For `note_to_midi()`, a character vector of note names such as
#'   `"C4"`, `"F#3"` or `"Bb5"`. Numbers are passed through unchanged. For
#'   `midi_to_note()` and `midi_to_freq()`, MIDI note numbers.
#' @return `note_to_midi()` returns integers, `midi_to_note()` returns note
#'   names (always spelled with sharps), and `midi_to_freq()` returns
#'   frequencies in hertz.
#' @export
#' @examples
#' note_to_midi(c("C4", "A4", "F#3", "Bb5"))
#' midi_to_note(60:64)
#' midi_to_freq(69)
note_to_midi <- function(x) {
  if (is.numeric(x)) return(as.integer(round(x)))
  m <- regmatches(x, regexec("^([A-Ga-g])([#b]?)(-?[0-9]+)$", trimws(x)))
  bad <- lengths(m) == 0
  if (any(bad)) {
    cli::cli_abort(c(
      "Can't read {.val {x[bad]}} as a note name.",
      "i" = "Use a letter, an optional {.code #} or {.code b}, and an octave, like {.val C4} or {.val F#3}."
    ))
  }
  vapply(m, function(p) {
    base <- pitch_class[[toupper(p[2])]]
    acc <- switch(p[3], "#" = 1L, "b" = -1L, 0L)
    as.integer(12L * (as.integer(p[4]) + 1L) + base + acc)
  }, integer(1))
}

#' @rdname note_to_midi
#' @export
midi_to_note <- function(x) {
  x <- as.integer(round(x))
  out <- paste0(note_names[x %% 12L + 1L], x %/% 12L - 1L)
  out[is.na(x)] <- NA_character_
  out
}

#' @rdname note_to_midi
#' @export
midi_to_freq <- function(x) 440 * 2^((x - 69) / 12)

scales_list <- list(
  pentatonic       = c(0, 2, 4, 7, 9),
  minor_pentatonic = c(0, 3, 5, 7, 10),
  major            = c(0, 2, 4, 5, 7, 9, 11),
  minor            = c(0, 2, 3, 5, 7, 8, 10),
  blues            = c(0, 3, 5, 6, 7, 10),
  chromatic        = 0:11,
  none             = 0:11,
  # Friendly names: a major pentatonic sounds bright, a minor one sad.
  happy            = c(0, 2, 4, 7, 9),
  sad              = c(0, 3, 5, 7, 10)
)

#' Musical scales available for pitch mapping
#'
#' @return A character vector of scale names to use with the `scale` argument
#'   of [sonify_data()]. `"none"` skips snapping, so pitches follow the data
#'   exactly. `"happy"` and `"sad"` are friendly names for `"pentatonic"`
#'   (the default) and `"minor_pentatonic"`.
#' @export
#' @examples
#' sound_scales()
sound_scales <- function() names(scales_list)

check_scale <- function(scale, call = rlang::caller_env()) {
  if (!rlang::is_string(scale) || !scale %in% names(scales_list)) {
    cli::cli_abort(c(
      "{.arg scale} must be one of {.or {.val {names(scales_list)}}}.",
      "x" = "You supplied {.val {scale}}."
    ), call = call)
  }
  scale
}

key_to_pc <- function(key, call = rlang::caller_env()) {
  midi <- tryCatch(note_to_midi(paste0(key, "4")), error = function(e) NULL)
  if (!rlang::is_string(key) || is.null(midi)) {
    cli::cli_abort(c(
      "{.arg key} must be a note letter like {.val C}, {.val F#} or {.val Bb}.",
      "x" = "You supplied {.val {key}}."
    ), call = call)
  }
  midi %% 12L
}

range_to_midi <- function(range, call = rlang::caller_env()) {
  if (length(range) != 2) {
    cli::cli_abort("{.arg range} must have two notes, like {.code c(\"C3\", \"C6\")}.", call = call)
  }
  r <- note_to_midi(range)
  if (r[1] >= r[2]) {
    cli::cli_abort("{.arg range} must go from low to high, like {.code c(\"C3\", \"C6\")}.", call = call)
  }
  if (r[1] < 0 || r[2] > 127) {
    cli::cli_abort("{.arg range} must stay within MIDI notes 0 to 127 (C-1 to G9).", call = call)
  }
  r
}

# All MIDI notes in `range` (inclusive) that belong to `scale` in `key`.
scale_notes <- function(scale, key_pc, range_midi) {
  m <- seq(range_midi[1], range_midi[2])
  m[((m - key_pc) %% 12L) %in% scales_list[[scale]]]
}

# Nearest allowed note for each target; ties go to the lower note.
snap_to_scale <- function(target, allowed) {
  vapply(target, function(t) {
    if (is.na(t)) return(NA_integer_)
    as.integer(allowed[which.min(abs(allowed - t))])
  }, integer(1))
}

# The tonic closest to the middle of the range; ties go to the higher one.
default_pitch <- function(key_pc, range_midi) {
  tonics <- seq(range_midi[1], range_midi[2])
  tonics <- rev(tonics[(tonics - key_pc) %% 12L == 0L])
  if (length(tonics) == 0) return(as.integer(round(mean(range_midi))))
  as.integer(tonics[which.min(abs(tonics - mean(range_midi)))])
}

# Map data values to MIDI pitches. Returns list(midi, freq).
map_pitch <- function(values, scale, key_pc, range_midi, reverse = FALSE,
                      call = rlang::caller_env()) {
  allowed <- scale_notes(scale, key_pc, range_midi)
  if (is.logical(values) || is.character(values)) values <- factor(values)

  if (is.factor(values)) {
    k <- nlevels(values)
    if (k > length(allowed)) {
      cli::cli_abort(c(
        "{.arg pitch} has {k} categories, but the range and scale only allow {length(allowed)} different notes.",
        "i" = "Widen {.arg range} or use {.code scale = \"chromatic\"}."
      ), call = call)
    }
    pos <- if (k == 1) ceiling(length(allowed) / 2) else round(seq(1, length(allowed), length.out = k))
    if (reverse) pos <- rev(pos)
    midi <- as.integer(allowed[pos][as.integer(values)])
    return(list(midi = midi, freq = midi_to_freq(midi)))
  }

  if (inherits(values, c("Date", "POSIXt", "difftime"))) values <- as.numeric(values)
  if (!is.numeric(values)) {
    cli::cli_abort(
      "{.arg pitch} must be numbers, text, or a factor, not {.obj_type_friendly {values}}.",
      call = call
    )
  }
  to <- if (reverse) rev(range_midi) else range_midi
  finite <- values[is.finite(values)]
  target <- if (length(finite) == 0 || diff(range(finite)) == 0) {
    ifelse(is.na(values), NA_real_, mean(range_midi))
  } else {
    scales::rescale(values, to = to, from = range(finite))
  }
  if (scale == "none") {
    list(midi = as.integer(round(target)), freq = midi_to_freq(target))
  } else {
    midi <- snap_to_scale(target, allowed)
    list(midi = midi, freq = midi_to_freq(midi))
  }
}

# Map data values to MIDI velocity (loudness), 40 to 120.
map_volume <- function(values, call = rlang::caller_env()) {
  if (is.logical(values) || is.character(values)) values <- factor(values)
  if (is.factor(values)) {
    k <- nlevels(values)
    levels_vel <- if (k == 1) 100 else round(seq(50, 120, length.out = k))
    return(as.integer(levels_vel[as.integer(values)]))
  }
  if (!is.numeric(values)) {
    cli::cli_abort(
      "{.arg volume} must be numbers, text, or a factor, not {.obj_type_friendly {values}}.",
      call = call
    )
  }
  finite <- values[is.finite(values)]
  if (length(finite) == 0 || diff(range(finite)) == 0) {
    return(ifelse(is.na(values), NA_integer_, 100L))
  }
  as.integer(round(scales::rescale(values, to = c(40, 120), from = range(finite))))
}
