#' Turn a data frame into sound
#'
#' `sonify_data()` turns each row of a data frame into a note. Map columns to
#' `pitch` (how high or low), `time` (when it plays) and `volume` (how loud),
#' pick an `instrument`, and print the result to hear it.
#'
#' Nothing is played or saved until you print the result (or call
#' [save_sound()]), just like a ggplot isn't drawn until it's printed. Use
#' [notes()] to see exactly which note each row became.
#'
#' ## How timing works
#'
#' * By default, rows play one after another in the order they appear, `bpm`
#'   notes per minute.
#' * `length` fits all the notes into that many seconds instead.
#' * `time` places each note according to a column: dates, times or numbers.
#'   The notes are spread out to fill the same total time.
#' * `time` together with `time_scale` plays your data in **real time**:
#'   `time_scale = 1` means one second of data is one second of sound, and
#'   `time_scale = 4` plays it four times slower.
#' * `sequence` plays groups (like events or games) one after another, with
#'   `gap` seconds of silence between them.
#'
#' Grouping with `dplyr::group_by()` does not change the sound. Use
#' `sequence` to hear groups in turn.
#'
#' @param data A data frame.
#' @param pitch A column (or calculation) to map to pitch. Bigger numbers are
#'   higher notes. Text and factors get one note per category. Leave it out to
#'   play every note at the same pitch.
#' @param time Optional. A column that decides when each note plays.
#' @param volume Optional. A column to map to loudness. Bigger is louder.
#' @param sequence Optional. A column of groups to play one after another.
#' @param instrument The instrument to use. See [instruments()].
#' @param bpm Notes per minute when rows play in order.
#' @param length Total length in seconds. Use instead of `bpm`.
#' @param time_scale Seconds of sound per unit of `time` (seconds for times
#'   and durations, days for dates). Plays `time` in real time.
#' @param gap Seconds of silence between `sequence` groups.
#' @param scale The musical scale that pitches snap to. See [sound_scales()].
#'   The default, `"pentatonic"`, sounds pleasant with any data. With
#'   `"none"`, the built-in synth plays exact frequencies, but real
#'   instruments play the nearest semitone.
#' @param key The key of the scale, like `"C"`, `"G"` or `"Bb"`.
#' @param range The lowest and highest notes to use, like `c("C3", "C6")`.
#' @param reverse If `TRUE`, bigger numbers become lower notes.
#' @param engine How to make the sound. `"auto"` uses real instruments when
#'   the fluidsynth package and a soundfont are available, and the built-in
#'   synth otherwise. See [sound_setup()].
#' @param force Set to `TRUE` to allow sonifications longer than 20 minutes.
#'
#' @return A `sonification` object. Print it to hear it.
#' @export
#' @examples
#' # A made-up season: points scored minus points allowed
#' season <- data.frame(
#'   game = 1:12,
#'   margin = c(12, -3, 8, 21, -15, 4, 7, -2, 18, -9, 3, 11)
#' )
#' s <- sonify_data(season, margin, instrument = "bell", bpm = 150)
#' notes(s)
#'
#' # A made-up race, played in real time like the NYT's 2010 Olympic Musical
#' race <- data.frame(behind = c(0, 0.09, 0.21, 0.30, 0.52, 0.55, 0.91, 1.34))
#' sonify_data(race, time = behind, time_scale = 2, instrument = "pluck")
sonify_data <- function(data, pitch = NULL, time = NULL, volume = NULL,
                        sequence = NULL, instrument = "piano", bpm = 120,
                        length = NULL, time_scale = NULL, gap = 1,
                        scale = "pentatonic", key = "C", range = c("C3", "C6"),
                        reverse = FALSE, engine = c("auto", "synth", "fluidsynth"),
                        force = FALSE) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame, not {.obj_type_friendly {data}}.")
  }
  q_pitch <- rlang::enquo(pitch)
  q_time <- rlang::enquo(time)
  q_volume <- rlang::enquo(volume)
  q_sequence <- rlang::enquo(sequence)

  engine <- rlang::arg_match(engine)
  scale <- check_scale(scale)
  key_pc <- key_to_pc(key)
  range_midi <- range_to_midi(range)
  inst <- resolve_instrument(instrument)
  check_timing_args(
    time_given = !rlang::quo_is_null(q_time), time_scale = time_scale,
    length = length, bpm = bpm, bpm_given = !missing(bpm),
    gap_given = !missing(gap), sequence_given = !rlang::quo_is_null(q_sequence)
  )

  if (inherits(data, "grouped_df") && rlang::quo_is_null(q_sequence)) {
    cli::cli_inform(
      c("i" = "Your data is grouped, but grouping doesn't change the sound.",
        " " = "To hear each group in turn, use {.code sequence = <group column>}."),
      .frequency = "regularly", .frequency_id = "soundeR_grouped"
    )
  }

  n <- nrow(data)
  if (n == 0) cli::cli_abort("{.arg data} has no rows to turn into sound.")

  pitch_vals <- eval_mapping(q_pitch, data, "pitch")
  time_vals <- eval_mapping(q_time, data, "time")
  volume_vals <- eval_mapping(q_volume, data, "volume")
  sequence_vals <- eval_mapping(q_sequence, data, "sequence")

  timing <- compute_timing(
    n, time = time_vals, sequence = sequence_vals, bpm = bpm, length = length,
    time_scale = time_scale, gap = gap
  )

  if (is.null(pitch_vals)) {
    midi <- rep(default_pitch(key_pc, range_midi), n)
    freq <- midi_to_freq(midi)
    value <- rep(NA, n)
  } else {
    mapped <- map_pitch(pitch_vals, scale, key_pc, range_midi, reverse)
    midi <- mapped$midi
    freq <- mapped$freq
    value <- pitch_vals
  }
  velocity <- if (is.null(volume_vals)) rep(100L, n) else map_volume(volume_vals)

  notes <- tibble::tibble(
    row = seq_len(n),
    sequence = if (is.null(sequence_vals)) NA_character_ else as.character(sequence_vals),
    onset = timing$onset,
    duration = timing$duration,
    midi = midi,
    note = midi_to_note(midi),
    freq = freq,
    velocity = velocity,
    instrument = inst$name,
    value = value,
    time_value = if (is.null(time_vals)) NA else time_vals
  )

  report_missing(notes, pitch_vals, time_vals, volume_vals)
  notes <- notes[!is.na(notes$midi) & !is.na(notes$onset) & !is.na(notes$velocity), ]
  if (nrow(notes) == 0) cli::cli_abort("Every row had a missing value, so there are no notes to play.")

  total <- max(notes$onset + notes$duration)
  check_total_length(total, force)

  new_sonification(
    notes = notes,
    settings = list(
      instrument = inst, engine = engine, bpm = bpm, length = length,
      time_scale = time_scale, gap = gap, scale = scale, key = key,
      range = range, reverse = reverse, total = total,
      labels = list(
        pitch = mapping_label(q_pitch), time = mapping_label(q_time),
        volume = mapping_label(q_volume), sequence = mapping_label(q_sequence)
      )
    )
  )
}

mapping_label <- function(q) if (rlang::quo_is_null(q)) NULL else rlang::as_label(q)

# Evaluate one mapping against the data; NULL if the mapping was left out.
eval_mapping <- function(q, data, arg, call = rlang::caller_env()) {
  if (rlang::quo_is_null(q)) return(NULL)
  vals <- tryCatch(
    rlang::eval_tidy(q, data),
    error = function(e) {
      expr <- rlang::quo_get_expr(q)
      if (is.symbol(expr) && !as.character(expr) %in% names(data)) {
        missing_col <- as.character(expr)
        guess <- names(data)[utils::adist(missing_col, names(data), ignore.case = TRUE)[1, ] <= 2]
        cli::cli_abort(c(
          "Can't find a column called {.field {missing_col}} for {.arg {arg}}.",
          if (length(guess)) c("i" = "Did you mean {.or {.field {guess}}}?"),
          "i" = "Your data has these columns: {.field {names(data)}}."
        ), call = call)
      }
      cli::cli_abort("Couldn't work out {.arg {arg}}.", parent = e, call = call)
    }
  )
  if (length(vals) == 1) vals <- rep(vals, nrow(data))
  if (length(vals) != nrow(data)) {
    cli::cli_abort(
      "{.arg {arg}} has {length(vals)} values, but {.arg data} has {nrow(data)} rows.",
      call = call
    )
  }
  vals
}

report_missing <- function(notes, pitch_vals, time_vals, volume_vals) {
  parts <- c(
    pitch = if (!is.null(pitch_vals)) sum(is.na(notes$midi)) else 0,
    time = if (!is.null(time_vals)) sum(is.na(notes$onset)) else 0,
    volume = if (!is.null(volume_vals)) sum(is.na(notes$velocity)) else 0
  )
  parts <- parts[parts > 0]
  if (length(parts) == 0) return(invisible())
  msgs <- sprintf("%d row%s with a missing %s", parts, ifelse(parts == 1, "", "s"), names(parts))
  n_skipped <- sum(parts)
  cli::cli_inform(c("i" = "Skipped {msgs}. {cli::qty(n_skipped)}{?That row is/Those rows are} silent."))
}

new_sonification <- function(notes, settings) {
  structure(
    list(notes = notes, settings = settings, cache = new.env(parent = emptyenv())),
    class = "sonification"
  )
}

#' See the notes in a sonification
#'
#' Every row of your data becomes a note. `notes()` shows the result as a
#' tibble: when each note starts (`onset`, in seconds), how long it lasts, its
#' pitch (as a MIDI number, a note name and a frequency in hertz), how loud it
#' is (`velocity`, 1 to 127), and the data `value` it came from. If you mapped
#' `time`, `time_value` holds the original time. The `row` column matches the
#' row number in your original data.
#'
#' @param x A sonification made by [sonify_data()].
#' @return A tibble with one row per note.
#' @export
#' @examples
#' s <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "sine")
#' notes(s)
notes <- function(x) {
  check_sonification(x)
  x$notes
}

check_sonification <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, "sonification")) {
    cli::cli_abort(
      "Expected a sonification made by {.fn sonify_data}, not {.obj_type_friendly {x}}.",
      call = call
    )
  }
}
