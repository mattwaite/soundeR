test_that("pan maps numbers, words and categories to stereo positions", {
  expect_equal(map_pan(0.5, TRUE), 0.5)
  expect_equal(map_pan("left", TRUE), -1)
  expect_equal(map_pan("Right", TRUE), 1)
  expect_equal(map_pan("center", TRUE), 0)
  expect_error(map_pan(2, TRUE), "between -1")
  expect_error(map_pan("up", TRUE), "between -1")
  expect_equal(map_pan(c(0, 5, 10), FALSE), c(-1, 0, 1))
  expect_equal(map_pan(c("home", "away", "home"), FALSE), c(0.8, -0.8, 0.8))
  expect_equal(map_pan(c(3, 3), FALSE), c(0, 0))
})

test_that("equal-power gains keep the total level steady", {
  g <- pan_gains(c(-1, 0, 1))
  expect_equal(g$left, c(1, cos(pi / 4), 0))
  expect_equal(g$right, c(0, sin(pi / 4), 1))
  expect_equal(g$left^2 + g$right^2, c(1, 1, 1))
})

test_that("pan goes into the notes, and voices spread out by default", {
  d <- data.frame(x = 1:3, side = c("home", "away", "home"))
  expect_equal(notes(sonify_data(d, x, instrument = "sine"))$pan, c(0, 0, 0))
  expect_equal(notes(sonify_data(d, x, pan = "left", instrument = "sine"))$pan, c(-1, -1, -1))
  expect_equal(notes(sonify_data(d, x, pan = side, instrument = "sine"))$pan, c(0.8, -0.8, 0.8))
  pos <- -0.25
  expect_equal(notes(sonify_data(d, x, pan = pos, instrument = "sine"))$pan, rep(-0.25, 3))

  two <- data.frame(a = 1:2, b = 2:1)
  n <- notes(sonify_data(two, c(a, b), instrument = "sine"))
  expect_equal(n$pan[n$voice == "a"], c(-0.6, -0.6))
  expect_equal(n$pan[n$voice == "b"], c(0.6, 0.6))
  expect_equal(notes(sonify_data(two, c(a, b), pan = 0, instrument = "sine"))$pan, rep(0, 4))

  plays <- data.frame(yards = 1:3, type = c("run", "pass", "kick"))
  n <- notes(sonify_data(plays, yards, voice = type, instrument = "sine"))
  expect_equal(n$pan, c(-0.6, 0, 0.6))
})

test_that("missing pan values play in the center", {
  d <- data.frame(x = 1:3, p = c(0, NA, 10))
  expect_message(s <- sonify_data(d, x, pan = p, instrument = "sine"), "center")
  expect_equal(notes(s)$pan, c(-1, 0, 1))
})

test_that("panned synth notes land in the right speaker", {
  d <- data.frame(x = c(1, 3, 2))
  rms <- function(a) sqrt(colMeans(a$samples^2))
  left <- get_audio(sonify_data(d, x, pan = "left", instrument = "bell"))
  right <- get_audio(sonify_data(d, x, pan = "right", instrument = "bell"))
  expect_equal(ncol(left$samples), 2)
  expect_equal(rms(left)[2], 0)
  expect_equal(rms(right)[1], 0)
  centered <- get_audio(sonify_data(d, x, instrument = "bell"))
  expect_equal(ncol(centered$samples), 1)
})

test_that("MIDI files carry a pan setting per channel", {
  skip_if_not_installed("tuneR")
  n <- data.frame(onset = c(0, 0), duration = 1, midi = c(60L, 64L), velocity = 100L, pan = c(-1, 1))
  path <- withr::local_tempfile(fileext = ".mid")
  write_midi(n, path, program = c(0L, 0L))
  m <- tuneR::readMidi(path)
  cc <- m[m$event == "Controller" & m$parameter1 == 10, ]
  expect_setequal(cc$parameter2, c(0, 127))
  # Same instrument at two positions needs two channels.
  expect_equal(length(unique(cc$channel)), 2)
})

test_that("MIDI pan positions coarsen to fit 15 channels", {
  pan <- seq(-1, 1, length.out = 40)
  expect_lte(length(unique(midi_pans(pan, rep(0L, 40)))), 15)
  expect_equal(midi_pans(0, 0L), 64L)
  expect_message(p <- midi_pans(rep(c(-1, 1), 10), rep(1:10, each = 2)), "center")
  expect_equal(unique(p), 64L)
})

test_that("real instruments pan", {
  skip_if_not(fluidsynth_ready(), "fluidsynth or its soundfont isn't available")
  a <- get_audio(sonify_data(data.frame(x = c(1, 3, 2)), x, pan = "left", instrument = "cello"))
  rms <- sqrt(colMeans(a$samples^2))
  expect_gt(rms[1], 5 * rms[2])
})

test_that("histograms and densities can sweep from left to right", {
  h <- sonify_histogram(data.frame(x = c(1, 2, 2, 3, 5)), x, binwidth = 1, pan = TRUE, instrument = "sine")
  n <- notes(h)
  expect_equal(n$pan[1], -1)
  expect_equal(n$pan[nrow(n)], 1)
  expect_true(all(diff(n$pan) > 0))
  expect_true(all(notes(sonify_histogram(data.frame(x = 1:5), x, binwidth = 1, instrument = "sine"))$pan == 0))

  d <- sonify_density(data.frame(x = c(1, 2, 2, 3, 5)), x, pan = TRUE, length = 2)
  a <- get_audio(d)
  expect_equal(ncol(a$samples), 2)
  first <- sqrt(colMeans(a$samples[1:4000, ]^2))
  last <- sqrt(colMeans(a$samples[(nrow(a$samples) - 8000):(nrow(a$samples) - 4000), ]^2))
  expect_gt(first[1], first[2])
  expect_gt(last[2], last[1])
})
