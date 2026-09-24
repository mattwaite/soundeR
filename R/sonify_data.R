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
#' ## More than one voice
#'
#' There are two ways to play more than one instrument:
#'
#' * Give `pitch` several columns, like `pitch = c(home_score, away_score)`.
#'   Each row plays one note per column at the same moment, and the columns
#'   share one pitch scale, so the same number is the same note in either
#'   column.
#' * Map a column to `voice`, like `voice = play_type`. Each note is played by
#'   the instrument for its group. Timing doesn't change.
#'
#' Then give `instrument` one name per voice, either in order
#' (`c("xylophone", "cello")`) or by name
#' (`c(run = "tuba", pass = "harp")`).
#'
#' @param data A data frame.
#' @param pitch A column (or calculation) to map to pitch. Bigger numbers are
#'   higher notes. Text and factors get one note per category. Leave it out to
#'   play every note at the same pitch. Use `c()` to play several columns at
#'   once, one voice each.
#' @param time Optional. A column that decides when each note plays.
#' @param volume Optional. A column to map to loudness. Bigger is louder.
#' @param sequence Optional. A column of groups to play one after another.
#' @param voice Optional. A column of groups, each played by its own
#'   instrument.
#' @param instrument The instrument to use (see [instruments()]). With more
#'   than one voice, one instrument per voice, in order or named by voice.
#'   Voices you leave out play the piano.
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
#' # Two voices at once: points for and against
#' scores <- data.frame(ours = c(70, 81, 64, 90), theirs = c(65, 84, 60, 72))
#' notes(sonify_data(scores, c(ours, theirs), instrument = c("bell", "pluck")))
#'
#' # One instrument per type of play
#' plays <- data.frame(
#'   yards = c(4, 12, 0, -2, 35),
#'   type = c("run", "pass", "incomplete", "run", "pass")
#' )
#' sonify_data(plays, yards, voice = type,
#'             instrument = c(run = "pluck", pass = "bell", incomplete = "square"))
#'
#' # A made-up race, played in real time like the NYT's 2010 Olympic Musical
#' race <- data.frame(behind = c(0, 0.09, 0.21, 0.30, 0.52, 0.55, 0.91, 1.34))
#' sonify_data(race, time = behind, time_scale = 2, instrument = "pluck")
sonify_data <- function(data, pitch = NULL, time = NULL, volume = NULL,
                        sequence = NULL, voice = NULL, instrument = "piano", bpm = 120,
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
  q_voice <- rlang::enquo(voice)
  pitch_qs <- split_pitch(q_pitch)
  if (length(pitch_qs) > 1 && !rlang::quo_is_null(q_voice)) {
    cli::cli_abort(c(
      "Use either several {.arg pitch} columns or {.arg voice}, not both.",
      "i" = "Several {.arg pitch} columns already make one voice per column."
    ))
  }

  engine <- rlang::arg_match(engine)
  scale <- check_scale(scale)
  key_pc <- key_to_pc(key)
  range_midi <- range_to_midi(range)
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

  pitch_list <- lapply(pitch_qs, eval_mapping, data = data, arg = "pitch", call = rlang::current_env())
  time_vals <- eval_mapping(q_time, data, "time")
  volume_vals <- eval_mapping(q_volume, data, "volume")
  sequence_vals <- eval_mapping(q_sequence, data, "sequence")
  voice_vals <- eval_mapping(q_voice, data, "voice")

  # Voices: one per pitch column, one per group of `voice`, or none.
  k <- max(length(pitch_list), 1)
  voice_levels <- NULL
  if (k > 1) {
    voice_levels <- names(pitch_qs)
  } else if (!is.null(voice_vals)) {
    # Factor level order, otherwise order of first appearance; NAs get a voice too.
    voice_levels <- sequence_levels(voice_vals)
    if (anyNA(voice_vals)) voice_levels <- c(voice_levels, "(missing)")
    voice_vals <- ifelse(is.na(voice_vals), "(missing)", as.character(voice_vals))
  }
  insts <- resolve_voice_instruments(instrument, voice_levels)

  timing <- compute_timing(
    n, time = time_vals, sequence = sequence_vals, bpm = bpm, length = length,
    time_scale = time_scale, gap = gap
  )

  if (length(pitch_list) == 0) {
    midi <- rep(default_pitch(key_pc, range_midi), n)
    freq <- midi_to_freq(midi)
    value <- rep(NA, n)
  } else {
    # All pitch columns share one scale, so equal values get equal notes.
    value <- combine_values(pitch_list)
    mapped <- map_pitch(value, scale, key_pc, range_midi, reverse)
    midi <- mapped$midi
    freq <- mapped$freq
  }
  velocity <- if (is.null(volume_vals)) rep(100L, n) else map_volume(volume_vals)

  voice_col <- if (k > 1) {
    rep(voice_levels, each = n)
  } else if (!is.null(voice_vals)) {
    voice_vals
  } else {
    NA_character_
  }
  notes <- tibble::tibble(
    row = rep(seq_len(n), k),
    sequence = if (is.null(sequence_vals)) NA_character_ else rep(as.character(sequence_vals), k),
    voice = voice_col,
    onset = rep(timing$onset, k),
    duration = rep(timing$duration, k),
    midi = midi,
    note = midi_to_note(midi),
    freq = freq,
    velocity = rep(velocity, k),
    instrument = if (is.null(voice_levels)) insts[[1]]$name else
      vapply(insts[voice_col], `[[`, character(1), "name", USE.NAMES = FALSE),
    value = value,
    time_value = if (is.null(time_vals)) NA else rep(time_vals, k)
  )
  if (k > 1) notes <- notes[order(notes$onset, notes$row, match(notes$voice, voice_levels)), ]

  report_missing(notes, length(pitch_list) > 0, !is.null(time_vals), !is.null(volume_vals), k > 1)
  notes <- notes[!is.na(notes$midi) & !is.na(notes$onset) & !is.na(notes$velocity), ]
  if (nrow(notes) == 0) cli::cli_abort("Every row had a missing value, so there are no notes to play.")

  total <- max(notes$onset + notes$duration)
  check_total_length(total, force)

  new_sonification(
    notes = notes,
    settings = list(
      instruments = insts, voices = voice_levels, engine = engine, bpm = bpm, length = length,
      time_scale = time_scale, gap = gap, scale = scale, key = key,
      range = range, reverse = reverse, total = total,
      labels = list(
        pitch = if (length(pitch_qs)) names(pitch_qs), time = mapping_label(q_time),
        volume = mapping_label(q_volume), sequence = mapping_label(q_sequence),
        voice = mapping_label(q_voice)
      )
    )
  )
}

mapping_label <- function(q) if (rlang::quo_is_null(q)) NULL else rlang::as_label(q)

# `pitch = c(a, b)` becomes one quosure per column, named by label.
split_pitch <- function(q) {
  if (rlang::quo_is_null(q)) return(list())
  expr <- rlang::quo_get_expr(q)
  if (!rlang::is_call(expr, "c")) return(rlang::set_names(list(q), rlang::as_label(q)))
  args <- rlang::call_args(expr)
  env <- rlang::quo_get_env(q)
  qs <- lapply(args, rlang::new_quosure, env = env)
  labels <- vapply(qs, rlang::as_label, character(1))
  given <- names(args) %||% rep("", length(args))
  labels[given != ""] <- given[given != ""]
  rlang::set_names(qs, labels)
}

# Stack several pitch columns into one vector for a shared scale.
combine_values <- function(vals) {
  if (length(vals) == 1) return(vals[[1]])
  if (all(vapply(vals, is.numeric, logical(1)))) return(unlist(vals, use.names = FALSE))
  if (all(vapply(vals, function(v) inherits(v, "Date"), logical(1)))) return(do.call(c, unname(vals)))
  unlist(lapply(vals, as.character), use.names = FALSE)
}

# Match `instrument` to voices. Returns a list of resolved instruments, named
# by voice (or a single unnamed one when there are no voices).
resolve_voice_instruments <- function(instrument, voices, call = rlang::caller_env()) {
  if (!is.character(instrument) || length(instrument) == 0 || anyNA(instrument)) {
    cli::cli_abort("{.arg instrument} must be instrument names, like {.val xylophone}.", call = call)
  }
  if (is.null(voices)) {
    if (length(instrument) > 1) {
      cli::cli_abort(c(
        "You gave {length(instrument)} instruments, but there's only one voice.",
        "i" = "To play several, use several {.arg pitch} columns, like {.code pitch = c(home, away)}, or map a column to {.arg voice}."
      ), call = call)
    }
    return(list(resolve_instrument(instrument, call = call)))
  }
  nm <- names(instrument)
  if (!is.null(nm) && any(nm != "")) {
    if (any(nm == "")) {
      cli::cli_abort("Give every instrument a voice name, or none of them.", call = call)
    }
    unknown <- setdiff(nm, voices)
    if (length(unknown)) {
      guesses <- unlist(lapply(unknown, function(u) voices[utils::adist(u, voices, ignore.case = TRUE)[1, ] <= 2]))
      cli::cli_abort(c(
        "{.val {unknown}} {?isn't a voice/aren't voices}.",
        if (length(guesses)) c("i" = "Did you mean {.or {.val {unique(guesses)}}}?"),
        "i" = "The voices are {.val {voices}}."
      ), call = call)
    }
    missing_voices <- setdiff(voices, nm)
    if (length(missing_voices)) {
      cli::cli_inform(c("i" = "No instrument given for {.val {missing_voices}}, so {?it plays/they play} the piano."))
      instrument <- c(instrument, rlang::set_names(rep("piano", length(missing_voices)), missing_voices))
    }
    instrument <- instrument[voices]
  } else if (length(instrument) == 1) {
    instrument <- rep(instrument, length(voices))
  } else if (length(instrument) != length(voices)) {
    cli::cli_abort(c(
      "You gave {length(instrument)} instruments for {length(voices)} voices.",
      "i" = "Give one instrument per voice ({.val {voices}}), or name them, like {.code c({voices[1]} = \"harp\")}."
    ), call = call)
  }
  out <- lapply(unname(instrument), resolve_instrument, call = call)
  programs <- unique(unlist(lapply(out, function(i) if (i$type == "gm") i$program)))
  if (length(programs) > 15) {
    cli::cli_abort("soundeR can play at most 15 different real instruments at once.", call = call)
  }
  rlang::set_names(out, voices)
}

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

report_missing <- function(notes, has_pitch, has_time, has_volume, per_note) {
  count <- function(bad) if (per_note) sum(bad) else length(unique(notes$row[bad]))
  parts <- c(
    pitch = if (has_pitch) count(is.na(notes$midi)) else 0,
    time = if (has_time) length(unique(notes$row[is.na(notes$onset)])) else 0,
    volume = if (has_volume) length(unique(notes$row[is.na(notes$velocity)])) else 0
  )
  parts <- parts[parts > 0]
  if (length(parts) == 0) return(invisible())
  unit <- ifelse(per_note & names(parts) == "pitch", "note", "row")
  msgs <- sprintf("%d %s%s with a missing %s", parts, unit, ifelse(parts == 1, "", "s"), names(parts))
  cli::cli_inform(c("i" = "Skipped {msgs}. They play as silence."))
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
