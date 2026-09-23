season <- data.frame(
  game = 1:6,
  margin = c(12, -3, 8, 21, -15, 4),
  result = c("W", "L", "W", "W", "L", "W")
)

test_that("sonify_data() builds one note per row", {
  s <- sonify_data(season, margin, instrument = "bell")
  expect_s3_class(s, "sonification")
  n <- notes(s)
  expect_named(n, c("row", "sequence", "onset", "duration", "midi", "note", "freq",
                    "velocity", "instrument", "value"))
  expect_equal(nrow(n), 6)
  expect_equal(n$onset, (0:5) * 0.5)
  expect_equal(n$value, season$margin)
  expect_equal(n$midi[which.max(season$margin)], 84L)
  expect_equal(n$midi[which.min(season$margin)], 48L)
})

test_that("pitch accepts calculations and text", {
  s <- sonify_data(season, margin * 2, instrument = "sine")
  expect_equal(notes(s)$value, season$margin * 2)
  r <- sonify_data(season, result, instrument = "sine")
  expect_equal(length(unique(notes(r)$midi)), 2)
})

test_that("leaving out pitch plays one note", {
  s <- sonify_data(season, instrument = "sine")
  expect_equal(unique(notes(s)$note), "C5")
})

test_that("the Olympic example works: real time, in sequence, no pitch", {
  race <- data.frame(
    event = rep(c("500m", "1000m"), each = 3),
    behind = c(0, 0.1, 0.3, 0, 0.05, 0.4)
  )
  s <- sonify_data(race, time = behind, time_scale = 2, sequence = event, instrument = "sine")
  n <- notes(s)
  expect_equal(n$onset[1:3], c(0, 0.2, 0.6))
  expect_equal(n$onset[4:6], 0.6 + 0.5 + 1 + c(0, 0.1, 0.8))
  expect_equal(n$sequence, race$event)
})

test_that("missing values become silence with a message", {
  d <- season
  d$margin[c(2, 5)] <- NA
  expect_message(s <- sonify_data(d, margin, instrument = "sine"), "2 rows with a missing pitch")
  expect_equal(notes(s)$row, c(1, 3, 4, 6))
  expect_equal(notes(s)$onset, c(0, 1, 1.5, 2.5))
})

test_that("mistyped columns get a suggestion", {
  expect_error(sonify_data(season, mragin), "Did you mean")
  expect_snapshot(sonify_data(season, mragin), error = TRUE)
})

test_that("bad inputs give friendly errors", {
  expect_error(sonify_data(1:3, x), "data frame")
  expect_error(sonify_data(season[0, ], margin), "no rows")
  expect_error(sonify_data(season, margin, instrument = "xylaphone"), "xylophone")
  expect_error(sonify_data(season, margin, scale = "dorian"), "must be one of")
  expect_error(sonify_data(season, margin, range = c("C6", "C3")), "low to high")
  expect_error(sonify_data(season, margin, bpm = 100, length = 5), "not both")
  expect_error(sonify_data(season, c(1, 2)), "2 values")
})

test_that("grouped data gets a hint but no change in sound", {
  skip_if_not_installed("dplyr")
  rlang::local_options(rlib_message_verbosity = "verbose")
  g <- dplyr::group_by(season, result)
  expect_message(s <- sonify_data(g, margin, instrument = "sine"), "grouping doesn't change")
  expect_equal(notes(s)$onset, notes(sonify_data(season, margin, instrument = "sine"))$onset)
})

test_that("instrument names resolve", {
  expect_equal(resolve_instrument("Xylophone")$program, 13L)
  expect_equal(resolve_instrument("piano")$program, 0L)
  expect_equal(resolve_instrument("cello")$program, 42L)
  expect_equal(resolve_instrument("bell")$type, "synth")
  expect_equal(nrow(instruments()), 133)
  expect_true(all(instruments("brass")$family == "brass"))
})
