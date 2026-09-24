season <- data.frame(
  game = 1:6,
  margin = c(12, -3, 8, 21, -15, 4),
  result = c("W", "L", "W", "W", "L", "W")
)

test_that("sonify_data() builds one note per row", {
  s <- sonify_data(season, margin, instrument = "bell")
  expect_s3_class(s, "sonification")
  n <- notes(s)
  expect_named(n, c("row", "sequence", "voice", "onset", "duration", "midi", "note", "freq",
                    "velocity", "pan", "instrument", "value", "time_value"))
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
  expect_error(sonify_data(season, 1:2), "2 values")
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

test_that("several pitch columns play together on a shared scale", {
  d <- data.frame(ours = c(70, 80, 60), theirs = c(80, 60, 70))
  s <- sonify_data(d, c(ours, theirs), instrument = c("bell", "pluck"))
  n <- notes(s)
  expect_equal(nrow(n), 6)
  expect_equal(n$voice, rep(c("ours", "theirs"), 3))
  expect_equal(n$instrument, rep(c("bell", "pluck"), 3))
  expect_equal(n$onset, rep(c(0, 0.5, 1), each = 2))
  expect_equal(n$row, rep(1:3, each = 2))
  # Same number, same note, whichever column it came from.
  expect_equal(n$midi[n$voice == "ours" & n$value == 80], n$midi[n$voice == "theirs" & n$value == 80])
  expect_equal(s$settings$labels$pitch, c("ours", "theirs"))
})

test_that("pitch columns can be renamed inside c()", {
  d <- data.frame(a = 1:2, b = 2:3)
  s <- sonify_data(d, c(home = a, away = b), instrument = "sine")
  expect_equal(unique(notes(s)$voice), c("home", "away"))
})

test_that("voice picks an instrument per group without changing timing", {
  plays <- data.frame(yards = c(4, 12, 0, -2), type = c("run", "pass", "incomplete", "run"))
  s <- sonify_data(plays, yards, voice = type,
                   instrument = c(run = "tuba", pass = "harp", incomplete = "timpani"))
  n <- notes(s)
  expect_equal(n$onset, c(0, 0.5, 1, 1.5))
  expect_equal(n$instrument, c("tuba", "harp", "timpani", "tuba"))
  expect_equal(s$settings$voices, c("run", "pass", "incomplete"))

  in_order <- sonify_data(plays, yards, voice = type, instrument = c("tuba", "harp", "timpani"))
  expect_equal(notes(in_order)$instrument, n$instrument)
  one <- sonify_data(plays, yards, voice = type, instrument = "harp")
  expect_equal(unique(notes(one)$instrument), "harp")
})

test_that("voices left out of a named instrument list play the piano", {
  plays <- data.frame(yards = c(4, 12, -7), type = c("run", "pass", "sack"))
  expect_message(
    s <- sonify_data(plays, yards, voice = type, instrument = c(run = "tuba", pass = "harp")),
    "sack"
  )
  expect_equal(notes(s)$instrument, c("tuba", "harp", "piano"))
})

test_that("missing voice values get their own voice", {
  plays <- data.frame(yards = c(4, 12, 3), type = c("run", NA, "run"))
  expect_message(s <- sonify_data(plays, yards, voice = type, instrument = "tuba"), NA)
  expect_equal(notes(s)$voice, c("run", "(missing)", "run"))
})

test_that("mismatched instruments and voices give friendly errors", {
  plays <- data.frame(yards = c(4, 12), type = c("run", "pass"))
  expect_error(sonify_data(plays, yards, voice = type, instrument = c(runn = "tuba")), "Did you mean")
  expect_error(sonify_data(plays, yards, voice = type, instrument = c("tuba", "harp", "oboe")), "3 instruments for 2 voices")
  expect_error(sonify_data(plays, yards, voice = type, instrument = c(run = "tuba", "harp")), "every instrument")
  expect_error(sonify_data(plays, yards, instrument = c("tuba", "harp")), "only one voice")
  expect_error(sonify_data(plays, c(yards, yards), voice = type), "not both")
})

test_that("missing values in one pitch column only silence that voice", {
  d <- data.frame(a = c(1, NA, 3), b = c(4, 5, 6))
  expect_message(s <- sonify_data(d, c(a, b), instrument = "sine"), "1 note with a missing pitch")
  expect_equal(nrow(notes(s)), 5)
})

test_that("duration sets how long notes last", {
  d <- data.frame(x = c(1, 5, 3), len = c(1, 10, 4), kind = c("a", "b", "a"))
  expect_equal(notes(sonify_data(d, x, duration = 0.2, instrument = "sine"))$duration, rep(0.2, 3))
  expect_equal(notes(sonify_data(d, x, duration = 1/4, instrument = "sine"))$duration, rep(0.25, 3))
  note_len <- 0.3
  expect_equal(notes(sonify_data(d, x, duration = note_len, instrument = "sine"))$duration, rep(0.3, 3))
  n <- notes(sonify_data(d, x, duration = len, instrument = "sine"))
  expect_equal(n$duration[c(1, 2)], c(0.1, 1.5))
  n <- notes(sonify_data(d, x, duration = len, duration_range = c(0.2, 0.4), instrument = "sine"))
  expect_equal(range(n$duration), c(0.2, 0.4))
  expect_equal(notes(sonify_data(d, x, duration = kind, instrument = "sine"))$duration, c(0.1, 1.5, 0.1))
  expect_error(sonify_data(d, x, duration = -1), "positive number")
  s <- sonify_data(d, x, duration = len, instrument = "sine")
  expect_equal(s$settings$labels$duration, "len")
  expect_equal(s$settings$total, max(notes(s)$onset + notes(s)$duration))
})

test_that("durations apply to every voice of a row", {
  d <- data.frame(a = 1:2, b = 2:1, len = c(1, 2))
  n <- notes(sonify_data(d, c(a, b), duration = len, instrument = "sine"))
  expect_equal(n$duration, c(0.1, 0.1, 1.5, 1.5))
})

test_that("missing durations get the default length, with a message", {
  d <- data.frame(x = 1:3, len = c(1, NA, 3))
  expect_message(s <- sonify_data(d, x, duration = len, instrument = "sine"), "missing duration")
  expect_equal(nrow(notes(s)), 3)
  expect_equal(notes(s)$duration[2], 0.5)
})

test_that("real instruments default to their usual range", {
  d <- data.frame(x = c(1, 5, 10))
  cello <- sonify_data(d, x, instrument = "cello")
  expect_equal(cello$settings$range, c("C2", "C5"))
  expect_equal(range(notes(cello)$midi), note_to_midi(c("C2", "C5")))
  expect_equal(sonify_data(d, x, instrument = "tuba")$settings$range, c("D1", "D4"))
  expect_equal(sonify_data(d, x, instrument = "bell")$settings$range, c("C3", "C6"))
  # Your own range always wins.
  expect_equal(sonify_data(d, x, instrument = "tuba", range = c("C4", "C6"))$settings$range, c("C4", "C6"))
})

test_that("several instruments share the range they have in common", {
  d <- data.frame(a = c(1, 5), b = c(5, 10))
  s <- sonify_data(d, c(a, b), instrument = c("marimba", "cello"))
  expect_equal(s$settings$range, c("C3", "C5"))
  # Built-in sounds don't narrow it.
  s <- sonify_data(d, c(a, b), instrument = c("bell", "cello"))
  expect_equal(s$settings$range, c("C2", "C5"))
})

test_that("instruments with little range in common fall back to C3-C6, with a message", {
  rlang::local_options(rlib_message_verbosity = "verbose")
  d <- data.frame(a = c(1, 5), b = c(5, 10))
  expect_message(s <- sonify_data(d, c(a, b), instrument = c("piccolo", "tuba")), "little pitch range")
  expect_equal(s$settings$range, c("C3", "C6"))
})

test_that("instruments() lists each instrument's range", {
  i <- instruments()
  expect_true(all(c("low", "high") %in% names(i)))
  expect_equal(unlist(i[i$name == "cello", c("low", "high")], use.names = FALSE), c("C2", "C5"))
  expect_true(all(note_to_midi(i$high) - note_to_midi(i$low) >= 12))
})
