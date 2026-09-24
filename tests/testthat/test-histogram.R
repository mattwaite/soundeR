test_that("bins line up with multiples of binwidth and include their start", {
  b <- make_bins(c(1900, 1909, 1910, 1923), rep(1, 4), binwidth = 10)
  expect_equal(b$start, c(1900, 1910, 1920))
  expect_equal(b$end, c(1910, 1920, 1930))
  expect_equal(b$count, c(2, 1, 1))
  # A value exactly on an edge doesn't slip into the bin below.
  b <- make_bins(c(0.3, 0.6, 0.9), rep(1, 3), binwidth = 0.3)
  expect_equal(b$count, c(1, 1, 1))
})

test_that("bins = n covers the range, with the maximum in the last bin", {
  b <- make_bins(c(0, 5, 10), rep(1, 3), bins = 5)
  expect_equal(nrow(b), 5)
  expect_equal(b$start[1], 0)
  expect_equal(b$end[5], 10)
  expect_equal(b$count, c(1, 0, 1, 0, 1))
  expect_equal(make_bins(c(3, 3), c(1, 1), bins = 4)$count[1], 2)
})

test_that("weights are summed within bins", {
  b <- make_bins(c(1, 2, 11), c(10, 5, 1), binwidth = 10)
  expect_equal(b$count, c(15, 1))
})

test_that("each non-empty bin is one note, and empty bins are silent gaps", {
  d <- data.frame(x = c(0, 0, 0, 30, 35), w = 1)
  s <- sonify_histogram(d, x, binwidth = 10, length = 4, instrument = "sine")
  n <- notes(s)
  expect_equal(nrow(s$settings$histogram$bins), 4)
  expect_equal(n$row, c(1, 4))
  expect_equal(n$onset, c(0, 3))          # bins 2 and 3 are one-second silences
  expect_equal(n$duration, c(1, 1))
  expect_equal(n$value, c(3, 2))
  expect_equal(n$bin_start, c(0, 30))
  expect_equal(n$bin_end, c(10, 40))
  expect_gt(n$midi[1], n$midi[2])         # more rows, higher note
  expect_false("time_value" %in% names(n))
})

test_that("empty bins don't produce a missing-value message", {
  d <- data.frame(x = c(0, 30))
  expect_no_message(sonify_histogram(d, x, binwidth = 10, instrument = "sine"))
})

test_that("pre-counted data works through weight", {
  s <- sonify_histogram(ne_house_years, year_built, weight = houses, binwidth = 10, instrument = "sine")
  n <- notes(s)
  expect_equal(sum(n$value), sum(ne_house_years$houses))
  expect_equal(n$value[n$bin_start == 1900],
               sum(ne_house_years$houses[ne_house_years$year_built %in% 1900:1909]))
  expect_equal(s$settings$total, 20)
  expect_equal(s$settings$labels, list(pitch = "houses", x = "year_built"))
})

test_that("length and bpm set the pace", {
  d <- data.frame(x = 1:4)
  s <- sonify_histogram(d, x, bins = 4, length = 8, instrument = "sine")
  expect_equal(notes(s)$onset, c(0, 2, 4, 6))
  s <- sonify_histogram(d, x, bins = 4, bpm = 120, instrument = "sine")
  expect_equal(notes(s)$onset, c(0, 0.5, 1, 1.5))
})

test_that("log spreads out pitches for lopsided counts", {
  d <- data.frame(x = c(1, 2, 3), w = c(1, 10, 1000))
  lin <- notes(sonify_histogram(d, x, weight = w, binwidth = 1, instrument = "sine"))
  lg <- notes(sonify_histogram(d, x, weight = w, binwidth = 1, log = TRUE, instrument = "sine"))
  expect_equal(lin$midi[1], lin$midi[2])
  expect_lt(lg$midi[1], lg$midi[2])
  expect_equal(lg$value, c(1, 10, 1000))
})

test_that("default bins come with a nudge toward binwidth", {
  rlang::local_options(rlib_message_verbosity = "verbose")
  expect_message(sonify_histogram(data.frame(x = 1:10), x, instrument = "sine"), "binwidth")
})

test_that("missing values are left out, with a message", {
  d <- data.frame(x = c(1, NA, 3), w = c(1, 1, NA))
  expect_message(s <- sonify_histogram(d, x, weight = w, binwidth = 1, instrument = "sine"), "2 rows")
  expect_equal(sum(notes(s)$value), 1)
})

test_that("bad inputs give friendly errors", {
  d <- data.frame(x = 1:3, type = c("a", "b", "a"), w = c(1, -1, 1))
  expect_error(sonify_histogram(d, x, bins = 3, binwidth = 1), "not both")
  expect_error(sonify_histogram(d, x, length = 5, bpm = 60), "not both")
  expect_error(sonify_histogram(d, type), "count them first")
  expect_error(sonify_histogram(d, x, weight = w), "negative")
  expect_error(sonify_histogram(d, x, binwidth = 0), "positive")
  expect_error(sonify_histogram(d, x, bins = 0), "whole number")
  expect_error(sonify_histogram(d), "which column")
  expect_error(sonify_histogram(d, xx), "Did you mean")
})

test_that("the video draws bars that fill as the sweep reaches them", {
  skip_if_not_installed("ggplot2")
  d <- data.frame(x = c(0, 0, 0, 30, 35))
  s <- sonify_histogram(d, x, binwidth = 10, length = 4, instrument = "sine")
  layout <- video_layout(s)
  expect_equal(layout$type, "histogram")
  expect_equal(layout$y_label, "count")
  st <- list(point_color = "navy", playhead_color = "red", highlight_color = "tan", title_position = "plot")
  for (t in c(0, 2.9, 3)) {
    d_built <- ggplot2::ggplot_build(video_frame(layout, t, st))$data
    bars <- d_built[[1]]
    expect_equal(bars$xmin, c(0, 30))
    expect_equal(bars$ymax, c(3, 2))
    expect_equal(bars$fill == "navy", notes(s)$onset <= t, info = t)
  }
  # The playhead reaches each bar's left edge as its note starts.
  expect_equal(playhead_x(layout$head_onset, layout$head_x, 3), 30)
  expect_equal(playhead_x(layout$head_onset, layout$head_x, 4), 40)
})
