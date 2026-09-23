test_that("rows play in order at bpm", {
  t <- compute_timing(3, bpm = 120)
  expect_equal(t$onset, c(0, 0.5, 1))
  expect_equal(t$duration, rep(0.5, 3))
})

test_that("length spreads notes to fill the time", {
  t <- compute_timing(5, length = 10)
  expect_equal(t$onset, c(0, 2, 4, 6, 8))
  expect_equal(t$total, 10)
})

test_that("time without time_scale stretches to the same total", {
  t <- compute_timing(3, time = c(0, 1, 10), bpm = 60)
  expect_equal(t$onset, c(0, 0.2, 2))
})

test_that("time_scale plays in real time", {
  t <- compute_timing(3, time = c(10, 10.5, 12), time_scale = 2)
  expect_equal(t$onset, c(0, 1, 4))
})

test_that("durations and date-times become seconds", {
  d <- as.difftime(c(0, 1.5), units = "mins")
  expect_equal(compute_timing(2, time = d, time_scale = 1)$onset, c(0, 90))
  p <- as.POSIXct("2026-01-01 12:00:00", tz = "UTC") + c(0, 3)
  expect_equal(compute_timing(2, time = p, time_scale = 1)$onset, c(0, 3))
  expect_error(compute_timing(2, time = c("a", "b"), time_scale = 1), "must be numbers")
})

test_that("sequence groups play one after another with a gap", {
  t <- compute_timing(4, time = c(0, 0.5, 0, 0.2), sequence = c("a", "a", "b", "b"),
                      time_scale = 1, gap = 1)
  # group a ends at 0.5 + 0.5 duration = 1.0, then a 1 s gap
  expect_equal(t$onset, c(0, 0.5, 2, 2.2))
})

test_that("sequence follows factor levels", {
  s <- factor(c("a", "b"), levels = c("b", "a"))
  t <- compute_timing(2, sequence = s, bpm = 60, gap = 0)
  expect_equal(t$onset, c(1, 0))
})

test_that("conflicting timing arguments are errors", {
  expect_error(check_timing_args(FALSE, 1, NULL, 120, FALSE, FALSE, FALSE), "only works together")
  expect_error(check_timing_args(TRUE, 1, 10, 120, FALSE, FALSE, FALSE), "not both")
  expect_error(check_timing_args(TRUE, 1, NULL, 90, TRUE, FALSE, FALSE), "doesn't apply")
  expect_error(check_timing_args(FALSE, NULL, 10, 90, TRUE, FALSE, FALSE), "not both")
  expect_warning(check_timing_args(FALSE, NULL, NULL, 120, FALSE, TRUE, FALSE), "ignored")
  expect_error(check_timing_args(FALSE, NULL, NULL, -5, TRUE, FALSE, FALSE), "positive")
})

test_that("length too short for the gaps is an error", {
  expect_error(compute_timing(4, sequence = c("a", "b", "c", "d"), length = 2, gap = 1), "too short")
})

test_that("long sonifications warn, very long ones stop", {
  expect_warning(check_total_length(200, FALSE), "minutes")
  expect_error(check_total_length(1500, FALSE), "force")
  expect_warning(check_total_length(1500, TRUE), "minutes")
  expect_silent(check_total_length(60, FALSE))
})
