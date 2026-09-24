#' Hear a distribution as a smooth curve
#'
#' `sonify_density()` is the sound version of `ggplot2::geom_density()`. It
#' draws a smooth curve through the distribution of a column, then sweeps
#' across it from the lowest value to the highest. By default you hear one
#' continuous tone that glides up where the data is dense and down where it's
#' sparse, and gets quieter where there's little data.
#'
#' `adjust` controls how smooth the curve is, just like in `geom_density()`:
#' bigger values smooth more, smaller values show more detail.
#'
#' The glide uses soundeR's built-in sounds (`"sine"`, `"triangle"` or
#' `"square"`), because real instruments play separate notes. With
#' `glide = FALSE`, the curve is played as a quick run of notes instead, and
#' any instrument works.
#'
#' [notes()] on the result has one row per point along the curve: `x_value`
#' is where the point sits, `value` is the curve's height there.
#'
#' @inheritParams sonify_histogram
#' @param x A column of numbers whose distribution you want to hear.
#' @param adjust Make the curve smoother (bigger) or more detailed (smaller).
#'   `2` is twice as smooth as the default.
#' @param glide If `TRUE` (the default), one continuous gliding tone. If
#'   `FALSE`, a run of notes, which works with any instrument.
#' @param points How many points along the curve to use.
#' @param instrument The sound to use. With `glide = TRUE`, `"sine"`,
#'   `"triangle"` or `"square"`.
#' @param scale The musical scale notes snap to when `glide = FALSE`. See
#'   [sound_scales()]. The glide always follows the curve exactly.
#' @param length Total length in seconds of the sweep.
#'
#' @return A `sonification` object. Print it to hear it, or pass it to
#'   [sonify_video()] to see the curve.
#' @export
#' @examples
#' sonify_density(data.frame(x = c(rnorm(300), rnorm(100, 4))), x)
#'
#' # Already-counted data
#' ne_house_years |>
#'   sonify_density(year_built, weight = houses, adjust = 4)
sonify_density <- function(data, x, weight = NULL, adjust = 1, glide = TRUE,
                           instrument = if (glide) "triangle" else "piano",
                           length = 10, points = 120, scale = "pentatonic",
                           key = "C", range = c("C3", "C6"),
                           engine = c("auto", "synth", "fluidsynth")) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame, not {.obj_type_friendly {data}}.")
  }
  q_x <- rlang::enquo(x)
  q_weight <- rlang::enquo(weight)
  if (rlang::quo_is_missing(q_x)) cli::cli_abort("Tell me which column to hear with {.arg x}.")
  check_positive(adjust, "adjust", rlang::current_env())
  check_positive(length, "length", rlang::current_env())
  if (!is.numeric(points) || base::length(points) != 1 || points < 10) {
    cli::cli_abort("{.arg points} must be a number, 10 or more.")
  }
  if (!rlang::is_bool(glide)) cli::cli_abort("{.arg glide} must be {.code TRUE} or {.code FALSE}.")
  glide_waves <- c("sine", "triangle", "square")
  if (glide && !(rlang::is_string(instrument) && instrument %in% glide_waves)) {
    cli::cli_abort(c(
      "A glide can only use {.or {.val {glide_waves}}}.",
      "i" = "To use {.val {instrument}}, add {.code glide = FALSE} to play the curve as notes."
    ))
  }

  values <- eval_mapping(q_x, data, "x")
  if (!is.numeric(values)) cli::cli_abort("{.arg x} must be numbers, not {.obj_type_friendly {values}}.")
  weights <- if (rlang::quo_is_null(q_weight)) rep(1, nrow(data)) else eval_mapping(q_weight, data, "weight")
  if (!is.numeric(weights)) cli::cli_abort("{.arg weight} must be numbers (counts).")
  if (any(weights < 0, na.rm = TRUE)) cli::cli_abort("{.arg weight} can't be negative.")
  keep <- is.finite(values) & !is.na(weights)
  if (any(!keep)) {
    cli::cli_inform(c("i" = "Left out {sum(!keep)} row{?s} with a missing {.arg x} or {.arg weight}."))
  }
  values <- values[keep & weights > 0]
  weights <- weights[keep & weights > 0]
  if (base::length(unique(values)) < 2) {
    cli::cli_abort("{.arg x} needs at least two different values to draw a curve.")
  }

  bw <- weighted_bw(values, weights) * adjust
  dens <- stats::density(values, weights = weights / sum(weights), bw = bw,
                         from = min(values), to = max(values), n = as.integer(points))
  curve <- data.frame(point = seq_along(dens$x), x_value = dens$x, height = dens$y)
  step <- length / nrow(curve)

  s <- sonify_data(
    curve, pitch = .data$height, volume = .data$height, time = .data$point, time_scale = step,
    duration = step, instrument = instrument,
    scale = if (glide) "none" else scale, key = key, range = range, engine = engine
  )
  n <- s$notes
  n$x_value <- curve$x_value[n$row]
  n$time_value <- NULL
  s$notes <- n
  s$settings$labels <- list(pitch = "density", x = rlang::as_label(q_x))
  s$settings$density <- list(bw = bw, step = step, glide = glide)
  if (glide) s$settings$glide <- instrument
  s
}

# Rule-of-thumb bandwidth, like stats::bw.nrd0(), that counts the weights,
# so pre-counted data gets the same smoothing the raw rows would. With
# whole-number counts it matches bw.nrd0() on the expanded data exactly.
weighted_bw <- function(x, weights) {
  o <- order(x)
  x <- x[o]
  weights <- weights[o]
  counts <- all(abs(weights - round(weights)) < 1e-8)
  total <- sum(weights)
  m <- sum(weights * x) / total
  if (counts) {
    n <- total
    s <- sqrt(sum(weights * (x - m)^2) / (n - 1))
    ends <- cumsum(weights)
    # The k-th value of the data if every row were written out.
    kth <- function(k) x[which(ends >= k)[1]]
    # Quantiles the way quantile() does by default (type 7).
    q <- function(p) {
      h <- (n - 1) * p + 1
      lo <- floor(h)
      kth(lo) + (h - lo) * (kth(min(lo + 1, n)) - kth(lo))
    }
  } else {
    # Effective sample size of the weights.
    n <- total^2 / sum(weights^2)
    s <- sqrt(sum(weights * (x - m)^2) / total)
    cw <- cumsum(weights) / total
    q <- function(p) x[which(cw >= p - 1e-12)[1]]
  }
  spread <- min(s, (q(0.75) - q(0.25)) / 1.34)
  if (!(spread > 0)) spread <- s
  if (!(spread > 0)) spread <- 1
  0.9 * spread * n^(-0.2)
}

# One continuous tone whose frequency glides smoothly through the notes'
# frequencies, with loudness following their velocities.
render_glide <- function(notes, wave, sr = synth_sr) {
  notes <- notes[order(notes$onset), ]
  total <- max(notes$onset + notes$duration)
  n_samp <- ceiling(total * sr)
  t <- (seq_len(n_samp) - 1) / sr
  mid <- notes$onset + notes$duration / 2
  # Glide in log-frequency, so equal musical steps take equal time.
  freq <- 2^stats::approx(mid, log2(notes$freq), xout = t, rule = 2)$y
  amp <- stats::approx(mid, notes$velocity / 127, xout = t, rule = 2)$y
  phase <- cumsum(freq) / sr
  wave_samples <- switch(wave,
    sine = sin(2 * pi * phase),
    triangle = 2 * abs(2 * (phase - floor(phase + 0.5))) - 1,
    square = 0.5 * sign(sin(2 * pi * phase))
  )
  fade <- pmin(1, t / 0.05, (total - t) / 0.15)
  out <- wave_samples * amp * pmax(fade, 0)
  normalize_audio(new_audio(c(out, numeric(round(0.2 * sr))), sr))
}
