# Convert a time-like vector to plain numbers.
# POSIXct and difftime (including hms) become seconds; Dates become days.
time_to_numeric <- function(x, call = rlang::caller_env()) {
  if (inherits(x, "difftime")) return(as.numeric(x, units = "secs"))
  if (inherits(x, c("POSIXt", "Date"))) return(as.numeric(x))
  if (is.numeric(x)) return(as.numeric(x))
  cli::cli_abort(
    "{.arg time} must be numbers, dates, date-times, or durations, not {.obj_type_friendly {x}}.",
    call = call
  )
}

# Order of sequence groups: factor level order, otherwise order of first appearance.
sequence_levels <- function(x) {
  if (is.factor(x)) return(levels(droplevels(x)))
  unique(as.character(x[!is.na(x)]))
}

# Work out when every row's note starts and how long it lasts.
#
# Four modes:
#   row order    (time = NULL):                 one note per row, `60 / bpm` apart
#   row, length  (time = NULL, length):         notes evenly spread to fill `length`
#   stretch      (time given, no time_scale):   time values rescaled to fill the length
#   real time    (time given, time_scale):      onset = (time - min) * time_scale
#
# With `sequence`, each group gets its own timeline and the groups play one
# after another, `gap` seconds apart.
#
# `note_duration` (optional, seconds per row) overrides the default note
# length; missing values fall back to the default.
#
# Returns list(onset, duration, total).
compute_timing <- function(n, time = NULL, sequence = NULL, bpm = 120,
                           length = NULL, time_scale = NULL, gap = 1,
                           note_duration = NULL, call = rlang::caller_env()) {
  groups <- if (is.null(sequence)) {
    rep("1", n)
  } else {
    factor(as.character(sequence), levels = sequence_levels(sequence))
  }
  lvls <- if (is.null(sequence)) "1" else levels(groups)
  k <- length(lvls)
  if (!is.null(sequence) && anyNA(groups)) {
    cli::cli_abort("{.arg sequence} can't contain missing values.", call = call)
  }

  real_time <- !is.null(time_scale)
  if (real_time) {
    step <- NA_real_
    dur <- 0.5
  } else {
    step <- if (is.null(length)) {
      60 / bpm
    } else {
      avail <- length - gap * (k - 1)
      if (avail <= 0) {
        cli::cli_abort(c(
          "{.arg length} of {length} seconds is too short for {k} sequence groups with a {.arg gap} of {gap} seconds.",
          "i" = "Use a longer {.arg length} or a smaller {.arg gap}."
        ), call = call)
      }
      avail / n
    }
    dur <- min(max(step, 0.08), 2)
  }
  dur <- if (is.null(note_duration)) rep(dur, n) else ifelse(is.na(note_duration), dur, note_duration)

  tnum <- if (is.null(time)) NULL else time_to_numeric(time, call = call)
  onset <- rep(NA_real_, n)
  offset <- 0
  for (g in lvls) {
    idx <- which(groups == g)
    ng <- length(idx)
    if (is.null(tnum)) {
      local <- (seq_len(ng) - 1) * step
    } else if (real_time) {
      tg <- tnum[idx]
      local <- (tg - min(tg, na.rm = TRUE)) * time_scale
    } else {
      tg <- tnum[idx]
      span <- (ng - 1) * step
      rng <- range(tg, na.rm = TRUE)
      local <- if (!all(is.finite(rng)) || diff(rng) == 0) {
        rep(0, ng)
      } else {
        scales::rescale(tg, to = c(0, span), from = rng)
      }
      local[is.na(tg)] <- NA_real_
    }
    onset[idx] <- offset + local
    # The next group starts `gap` seconds after this group's last note ends.
    group_end <- max(c(local + dur[idx], dur[idx][1]), na.rm = TRUE)
    offset <- offset + group_end + gap
  }

  total <- max(c(onset + dur, dur[1]), na.rm = TRUE)
  list(onset = onset, duration = dur, total = total)
}

check_timing_args <- function(time_given, time_scale, length, bpm, bpm_given,
                              gap_given, sequence_given, call = rlang::caller_env()) {
  if (!is.null(time_scale) && !time_given) {
    cli::cli_abort(c(
      "{.arg time_scale} only works together with {.arg time}.",
      "i" = "Map a column to {.arg time}, like {.code time = seconds_behind}."
    ), call = call)
  }
  if (!is.null(time_scale) && !is.null(length)) {
    cli::cli_abort(c(
      "Use either {.arg time_scale} or {.arg length}, not both.",
      "i" = "{.arg time_scale} plays the data in real time; {.arg length} squeezes or stretches it to fit."
    ), call = call)
  }
  if (!is.null(time_scale) && bpm_given) {
    cli::cli_abort(c(
      "{.arg bpm} doesn't apply when {.arg time_scale} is set.",
      "i" = "With {.arg time_scale}, your {.arg time} column decides when notes play."
    ), call = call)
  }
  if (!is.null(length) && bpm_given) {
    cli::cli_abort(c(
      "Use either {.arg bpm} or {.arg length}, not both.",
      "i" = "{.arg bpm} sets the speed; {.arg length} sets the total seconds and works out the speed for you."
    ), call = call)
  }
  if (gap_given && !sequence_given) {
    cli::cli_warn("{.arg gap} is ignored without {.arg sequence}.", call = call)
  }
  check_positive(bpm, "bpm", call)
  if (!is.null(length)) check_positive(length, "length", call)
  if (!is.null(time_scale)) check_positive(time_scale, "time_scale", call)
}

check_positive <- function(x, arg, call) {
  if (!is.numeric(x) || base::length(x) != 1 || is.na(x) || x <= 0) {
    cli::cli_abort("{.arg {arg}} must be a single positive number.", call = call)
  }
}

check_total_length <- function(total, force, call = rlang::caller_env()) {
  mins <- total / 60
  if (total > 20 * 60 && !isTRUE(force)) {
    cli::cli_abort(c(
      "This sonification would last about {round(mins)} minutes.",
      "i" = "Set {.arg length} to a number of seconds to fit it into less time, like {.code length = 60}.",
      "i" = "Or use {.code force = TRUE} if you really want it this long."
    ), call = call)
  }
  if (total > 3 * 60) {
    cli::cli_warn(c(
      "This sonification lasts about {round(mins, 1)} minutes.",
      "i" = "Set {.arg length} to a number of seconds to make it shorter, like {.code length = 60}."
    ), call = call)
  }
}

# Map a `duration` mapping to seconds per row (NA stays NA).
#   a number you typed (duration = 0.2): every note lasts that long
#   a duration column (difftime/hms):     real time, times time_scale if set
#   numbers:                              rescaled into `duration_range`
#   text/factors/logical:                 one length per category
map_duration <- function(values, literal, duration_range, time_scale = NULL,
                         call = rlang::caller_env()) {
  if (literal) {
    if (!is.numeric(values) || any(values <= 0)) {
      cli::cli_abort("{.arg duration} must be a positive number of seconds, like {.code duration = 0.25}.", call = call)
    }
    return(as.numeric(values))
  }
  if (inherits(values, "difftime")) {
    secs <- as.numeric(values, units = "secs") * (time_scale %||% 1)
    if (any(secs < 0, na.rm = TRUE)) cli::cli_abort("{.arg duration} can't be negative.", call = call)
    return(pmax(secs, 0.03))
  }
  if (inherits(values, c("Date", "POSIXt"))) {
    cli::cli_abort(c(
      "{.arg duration} needs lengths of time, not dates.",
      "i" = "Subtract two dates or times to get one, like {.code duration = end - start}."
    ), call = call)
  }
  if (is.logical(values) || is.character(values)) values <- factor(values)
  if (is.factor(values)) {
    k <- nlevels(values)
    lens <- if (k == 1) mean(duration_range) else seq(duration_range[1], duration_range[2], length.out = k)
    return(lens[as.integer(values)])
  }
  if (!is.numeric(values)) {
    cli::cli_abort(
      "{.arg duration} must be numbers, text, or durations, not {.obj_type_friendly {values}}.",
      call = call
    )
  }
  finite <- values[is.finite(values)]
  if (length(finite) == 0 || diff(range(finite)) == 0) {
    return(ifelse(is.na(values), NA_real_, mean(duration_range)))
  }
  scales::rescale(values, to = duration_range, from = range(finite))
}

check_duration_range <- function(duration_range, call = rlang::caller_env()) {
  if (!is.numeric(duration_range) || base::length(duration_range) != 2 || anyNA(duration_range) ||
      duration_range[1] <= 0 || duration_range[1] >= duration_range[2]) {
    cli::cli_abort(
      "{.arg duration_range} must be two positive numbers of seconds, shortest first, like {.code c(0.1, 1.5)}.",
      call = call
    )
  }
}
