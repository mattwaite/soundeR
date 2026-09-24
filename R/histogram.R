#' Hear a distribution, like a histogram
#'
#' `sonify_histogram()` is the sound version of `ggplot2::geom_histogram()`.
#' It sorts a column of numbers into bins, then sweeps across them from the
#' lowest bin to the highest. Each bin is one note: the more rows in the bin,
#' the higher (and louder) the note. Empty bins are silent.
#'
#' Like a histogram, what you hear depends on the bins. Try a few values of
#' `binwidth`: narrow bins show detail (and noise), wide bins show the overall
#' shape.
#'
#' If your data is already counted, with one row per value and a column of
#' counts, give that column to `weight`.
#'
#' [notes()] on the result has one row per non-empty bin: `bin_start` and
#' `bin_end` give its edges (each bin includes its start but not its end),
#' `value` is its count, and `row` is the bin's number, counting from the
#' lowest.
#'
#' @param data A data frame.
#' @param x A column of numbers whose distribution you want to hear.
#' @param weight Optional. A column of counts, for data that's already counted.
#' @param bins Number of bins. Use `bins` or `binwidth`, not both. If you give
#'   neither, soundeR uses 30 bins and suggests picking a `binwidth`.
#' @param binwidth How wide each bin is, in the units of `x`. Bins line up
#'   with multiples of `binwidth`, so `binwidth = 10` for years gives 1900 to
#'   1909, 1910 to 1919, and so on.
#' @param log If `TRUE`, pitch follows the logarithm of the counts. That
#'   spreads out the notes when a few bins are much bigger than the rest.
#' @param length Total length in seconds of the sweep.
#' @param bpm Notes (bins) per minute. Use instead of `length`.
#' @inheritParams sonify_data
#'
#' @return A `sonification` object. Print it to hear it, or pass it to
#'   [sonify_video()] to see it as a histogram.
#' @export
#' @examples
#' # Already-counted data: houses built in Nebraska, by year
#' ne_house_years
#'
#' # One bin per decade
#' ne_house_years |>
#'   sonify_histogram(year_built, weight = houses, binwidth = 10, instrument = "marimba")
#'
#' # Raw values work too
#' sonify_histogram(data.frame(x = rnorm(500)), x, bins = 20, instrument = "bell")
sonify_histogram <- function(data, x, weight = NULL, bins = NULL, binwidth = NULL,
                             instrument = "piano", length = 20, bpm = NULL,
                             log = FALSE, scale = "pentatonic", key = "C",
                             range = c("C3", "C6"), engine = c("auto", "synth", "fluidsynth"),
                             force = FALSE) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame, not {.obj_type_friendly {data}}.")
  }
  q_x <- rlang::enquo(x)
  q_weight <- rlang::enquo(weight)
  if (rlang::quo_is_missing(q_x)) cli::cli_abort("Tell me which column to hear with {.arg x}.")
  if (!is.null(bins) && !is.null(binwidth)) {
    cli::cli_abort("Use either {.arg bins} or {.arg binwidth}, not both.")
  }
  if (!is.null(bpm) && !missing(length)) {
    cli::cli_abort("Use either {.arg bpm} or {.arg length}, not both.")
  }
  if (!is.null(bins) && (!is.numeric(bins) || base::length(bins) != 1 || bins < 1)) {
    cli::cli_abort("{.arg bins} must be a whole number, 1 or more.")
  }
  if (!is.null(binwidth)) check_positive(binwidth, "binwidth", rlang::current_env())
  if (!is.null(bpm)) check_positive(bpm, "bpm", rlang::current_env())
  check_positive(length, "length", rlang::current_env())

  values <- eval_mapping(q_x, data, "x")
  if (!is.numeric(values)) {
    cli::cli_abort(c(
      "{.arg x} must be numbers, not {.obj_type_friendly {values}}.",
      "i" = "To hear counts of categories, count them first and use {.fn sonify_data}, like {.code count(data, type) |> sonify_data(n)}."
    ))
  }
  weights <- if (rlang::quo_is_null(q_weight)) rep(1, nrow(data)) else eval_mapping(q_weight, data, "weight")
  if (!is.numeric(weights)) cli::cli_abort("{.arg weight} must be numbers (counts).")
  if (any(weights < 0, na.rm = TRUE)) cli::cli_abort("{.arg weight} can't be negative.")

  keep <- !is.na(values) & !is.na(weights) & is.finite(values)
  if (any(!keep)) {
    cli::cli_inform(c("i" = "Left out {sum(!keep)} row{?s} with a missing {.arg x} or {.arg weight}."))
  }
  values <- values[keep]
  weights <- weights[keep]
  # Rows with zero weight don't count, and shouldn't stretch the range.
  values <- values[weights > 0]
  weights <- weights[weights > 0]
  if (base::length(values) == 0) cli::cli_abort("There's nothing to count in {.arg x}.")

  if (is.null(bins) && is.null(binwidth)) {
    bins <- 30
    cli::cli_inform(
      c("i" = "Using 30 bins. Pick a better value with {.arg binwidth}, like {.code binwidth = 10}."),
      .frequency = "regularly", .frequency_id = "soundeR_bins"
    )
  }
  b <- make_bins(values, weights, bins = bins, binwidth = binwidth)

  n_bins <- nrow(b)
  step <- if (is.null(bpm)) length / n_bins else 60 / bpm
  filled <- b[b$count > 0, ]
  filled$pitch_value <- if (log) log10(filled$count) else filled$count

  # Each bin plays at its own slot, so empty bins are silences of the right
  # length: bin numbers played in real time, one `step` per bin.
  s <- sonify_data(
    filled, pitch = .data$pitch_value, volume = .data$count, time = .data$bin, time_scale = step,
    duration = step, instrument = instrument, scale = scale, key = key,
    range = range, engine = engine, force = force
  )

  n <- s$notes
  n$row <- filled$bin[n$row]
  n$value <- filled$count[match(n$row, filled$bin)]
  n$bin_start <- b$start[n$row]
  n$bin_end <- b$end[n$row]
  n$time_value <- NULL
  s$notes <- n

  x_label <- rlang::as_label(q_x)
  s$settings$labels <- list(
    pitch = if (rlang::quo_is_null(q_weight)) "count" else rlang::as_label(q_weight),
    x = x_label
  )
  s$settings$histogram <- list(bins = b, binwidth = b$end[1] - b$start[1], step = step, log = log)
  s
}

# Sort values into equal-width bins, including the start of each bin and not
# its end (the last bin also includes the maximum). With `binwidth`, edges
# line up with multiples of it. Returns one row per bin, empty ones included.
make_bins <- function(values, weights, bins = NULL, binwidth = NULL) {
  lo <- min(values)
  hi <- max(values)
  if (!is.null(binwidth)) {
    start <- floor(lo / binwidth + 1e-9) * binwidth
    n_bins <- floor((hi - start) / binwidth + 1e-9) + 1
  } else {
    binwidth <- if (hi > lo) (hi - lo) / bins else 1
    start <- lo
    n_bins <- as.integer(bins)
  }
  # The small tolerance keeps a value sitting exactly on an edge (like 1910
  # with binwidth 10) from slipping into the bin below through rounding.
  idx <- floor((values - start) / binwidth + 1e-9) + 1
  idx <- pmin(pmax(idx, 1), n_bins)
  counts <- rep(0, n_bins)
  sums <- tapply(weights, idx, sum)
  counts[as.integer(names(sums))] <- sums
  data.frame(
    bin = seq_len(n_bins),
    start = start + (seq_len(n_bins) - 1) * binwidth,
    end = start + seq_len(n_bins) * binwidth,
    count = counts
  )
}
