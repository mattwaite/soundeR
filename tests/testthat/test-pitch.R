test_that("note names convert to MIDI numbers", {
  expect_equal(note_to_midi(c("C4", "A4", "F#3", "Bb5", "C-1", "g9")), c(60L, 69L, 54L, 82L, 0L, 127L))
  expect_equal(note_to_midi(c(60, 61.4)), c(60L, 61L))
  expect_error(note_to_midi("H2"), "note name")
})

test_that("MIDI numbers convert to note names and frequencies", {
  expect_equal(midi_to_note(c(0, 60, 61, 127)), c("C-1", "C4", "C#4", "G9"))
  expect_equal(note_to_midi(midi_to_note(0:127)), 0:127)
  expect_equal(midi_to_freq(69), 440)
  expect_equal(midi_to_freq(81), 880)
})

test_that("scales produce the right notes", {
  expect_equal(scale_notes("pentatonic", 0L, c(60L, 72L)), c(60, 62, 64, 67, 69, 72))
  expect_equal(scale_notes("major", key_to_pc("G"), c(67L, 79L)), c(67, 69, 71, 72, 74, 76, 78, 79))
  expect_error(check_scale("dorian"), "must be one of")
  expect_error(key_to_pc("H"), "note letter")
})

test_that("pitches snap to the nearest scale note, ties going down", {
  expect_equal(snap_to_scale(c(60, 61, 65.4, 66, NA), c(60, 62, 64, 67)), c(60L, 60L, 64L, 67L, NA))
})

test_that("the default pitch is the tonic nearest the middle of the range", {
  expect_equal(default_pitch(0L, c(48L, 84L)), 72L) # C3..C6: C4 and C5 tie, take C5
  expect_equal(default_pitch(7L, c(60L, 72L)), 67L)
})

test_that("numbers map from the lowest to the highest note", {
  p <- map_pitch(c(1, 5, 10), "pentatonic", 0L, c(48L, 84L))
  expect_equal(p$midi[c(1, 3)], c(48L, 84L))
  r <- map_pitch(c(1, 5, 10), "pentatonic", 0L, c(48L, 84L), reverse = TRUE)
  expect_equal(r$midi[c(1, 3)], c(84L, 48L))
  expect_true(all(((p$midi - 0) %% 12) %in% scales_list$pentatonic))
})

test_that("scale = 'none' keeps exact frequencies", {
  p <- map_pitch(c(0, 1, 3), "none", 0L, c(60L, 72L))
  expect_equal(p$freq[2], midi_to_freq(64))
  expect_equal(p$freq[3], midi_to_freq(72))
})

test_that("categories get distinct notes", {
  p <- map_pitch(c("W", "L", "W", "T"), "pentatonic", 0L, c(48L, 84L))
  expect_equal(length(unique(p$midi)), 3)
  expect_equal(p$midi[1], p$midi[3])
  expect_error(map_pitch(letters, "pentatonic", 0L, c(60L, 64L)), "categories")
})

test_that("constant values play the middle of the range", {
  expect_equal(unique(map_pitch(c(5, 5, 5), "chromatic", 0L, c(60L, 72L))$midi), 66L)
})

test_that("volume maps to MIDI velocity", {
  expect_equal(map_volume(c(0, 5, 10)), c(40L, 80L, 120L))
  expect_equal(map_volume(c(3, 3)), c(100L, 100L))
  expect_equal(map_volume(c("lo", "hi")), c(50L, 120L)[c(2, 1)])
})

test_that("happy and sad are friendly scale names", {
  expect_true(all(c("happy", "sad") %in% sound_scales()))
  expect_equal(scales_list$happy, scales_list$pentatonic)
  expect_equal(scales_list$sad, scales_list$minor_pentatonic)
  d <- data.frame(x = 1:12)
  happy <- notes(sonify_data(d, x, scale = "happy", instrument = "sine"))$midi
  sad <- notes(sonify_data(d, x, scale = "sad", instrument = "sine"))$midi
  expect_equal(happy, notes(sonify_data(d, x, instrument = "sine"))$midi)
  expect_true(all((sad %% 12) %in% c(0, 3, 5, 7, 10)))
  expect_true(any(sad != happy))
})
