set.seed(2026)
two_humps <- data.frame(x = c(rnorm(300), rnorm(100, 5)))

test_that("the weighted bandwidth matches bw.nrd0 on the expanded data", {
  x <- c(1, 2, 2, 3, 3, 3, 4, 10)
  expect_equal(weighted_bw(c(1, 2, 3, 4, 10), c(1, 2, 3, 1, 1)), stats::bw.nrd0(x))
  expect_equal(weighted_bw(c(10, 1, 3, 4, 2), c(1, 1, 3, 1, 2)), stats::bw.nrd0(x))
  expect_equal(weighted_bw(ne_house_years$year_built, ne_house_years$houses),
               stats::bw.nrd0(rep(ne_house_years$year_built, ne_house_years$houses)))
  expect_equal(weighted_bw(two_humps$x, rep(1, 400)), stats::bw.nrd0(two_humps$x))
  # Non-count weights still give a sensible, positive bandwidth.
  expect_gt(weighted_bw(two_humps$x, runif(400)), 0)
})

test_that("the curve is sampled evenly across the data and swept in time", {
  s <- sonify_density(two_humps, x, points = 50, length = 5)
  n <- notes(s)
  expect_equal(nrow(n), 50)
  expect_equal(range(n$x_value), range(two_humps$x))
  expect_equal(n$onset, (0:49) * 0.1)
  expect_equal(n$duration, rep(0.1, 50))
  expect_equal(s$settings$glide, "triangle")
  expect_equal(s$settings$labels, list(pitch = "density", x = "x"))
})

test_that("pitch follows the curve: two humps, two peaks", {
  n <- notes(sonify_density(two_humps, x))
  f <- n$freq
  peaks <- which(diff(sign(diff(f))) < 0) + 1
  expect_length(peaks, 2)
  expect_lt(n$x_value[peaks[1]], 2)
  expect_gt(n$x_value[peaks[2]], 3)
  # The glide isn't snapped to a scale.
  expect_gt(length(unique(round(f, 3))), 60)
})

test_that("adjust smooths the curve", {
  wiggly <- sonify_density(ne_house_years, year_built, weight = houses, adjust = 0.5)
  smooth <- sonify_density(ne_house_years, year_built, weight = houses, adjust = 4)
  bumps <- function(s) sum(diff(sign(diff(notes(s)$value))) < 0)
  expect_gt(bumps(wiggly), bumps(smooth))
  expect_equal(smooth$settings$density$bw, 8 * wiggly$settings$density$bw)
})

test_that("the glide renders as one continuous tone", {
  s <- sonify_density(two_humps, x, length = 3)
  a <- get_audio(s)
  expect_equal(a$sr, synth_sr)
  expect_equal(audio_seconds(a), 3.2, tolerance = 0.01)
  expect_equal(max(abs(a$samples)), 0.9)
  # No silent gaps in the middle, as there would be between separate notes.
  mid <- a$samples[round(0.5 * a$sr):round(2.5 * a$sr), 1]
  win <- matrix(mid[seq_len(floor(length(mid) / 441) * 441)], nrow = 441)
  expect_gt(min(apply(abs(win), 2, max)), 0.05)
  expect_match(describe(s), "triangle")
})

test_that("glide = FALSE plays notes with any instrument, snapped to the scale", {
  s <- sonify_density(two_humps, x, glide = FALSE, instrument = "bell", points = 40)
  expect_null(s$settings$glide)
  n <- notes(s)
  expect_true(all(((n$midi - 0) %% 12) %in% scales_list$pentatonic))
  expect_equal(unique(n$instrument), "bell")
})

test_that("bad inputs give friendly errors", {
  expect_error(sonify_density(two_humps, x, instrument = "marimba"), "glide = FALSE")
  expect_error(sonify_density(data.frame(x = c(1, 1)), x), "two different values")
  expect_error(sonify_density(two_humps, x, adjust = 0), "positive")
  expect_error(sonify_density(two_humps, x, points = 3), "10 or more")
  expect_error(sonify_density(data.frame(x = letters), x), "numbers")
  expect_error(sonify_density(two_humps), "which column")
})

test_that("the video fills the curve up to the playhead", {
  skip_if_not_installed("ggplot2")
  s <- sonify_density(two_humps, x, points = 20, length = 2)
  layout <- video_layout(s)
  expect_equal(layout$type, "density")
  n <- notes(s)
  # The playhead reaches each point as its slice of the sweep starts.
  expect_equal(playhead_x(layout$head_onset, layout$head_x, n$onset[5]), n$x_value[5])
  expect_equal(playhead_x(layout$head_onset, layout$head_x, 2), max(n$x_value))
  st <- list(point_color = "navy", playhead_color = "red", highlight_color = "tan", title_position = "plot")
  built <- ggplot2::ggplot_build(video_frame(layout, 1, st))$data
  played <- built[[2]]
  expect_equal(unique(played$fill), "navy")
  expect_equal(max(played$x), playhead_x(layout$head_onset, layout$head_x, 1), tolerance = 1e-6)
})
