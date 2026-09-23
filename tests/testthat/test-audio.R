test_that("WAV files round-trip, mono and stereo", {
  for (ch in 1:2) {
    m <- matrix(sin(seq(0, 20, length.out = 1000 * ch)) * 0.5, ncol = ch)
    path <- withr::local_tempfile(fileext = ".wav")
    write_wav(new_audio(m, 22050), path)
    expect_equal(readBin(path, "raw", 4), charToRaw("RIFF"))
    back <- read_wav(path)
    expect_equal(back$sr, 22050L)
    expect_equal(dim(back$samples), dim(m))
    expect_equal(back$samples, m, tolerance = 1e-4)
  }
})

test_that("tuneR can read our WAV files", {
  skip_if_not_installed("tuneR")
  path <- withr::local_tempfile(fileext = ".wav")
  write_wav(new_audio(sin(1:2205), 22050), path)
  w <- tuneR::readWave(path)
  expect_equal(w@samp.rate, 22050)
  expect_equal(length(w@left), 2205)
})

test_that("normalize and trim behave", {
  a <- new_audio(c(0.1, -0.5, 0.2, rep(0, 100)), 10)
  expect_equal(max(abs(normalize_audio(a)$samples)), 0.9)
  expect_equal(nrow(trim_tail(a, keep = 1)$samples), 3 + 10)
})

test_that("every synth voice makes sound of the right length", {
  s <- sonify_data(data.frame(x = c(1, 3, 2)), x, instrument = "sine", bpm = 60)
  for (v in synth_names) {
    a <- render_synth(notes(s), v)
    expect_equal(a$sr, synth_sr)
    expect_gt(audio_seconds(a), 3)
    expect_lt(audio_seconds(a), 4)
    expect_equal(max(abs(a$samples)), 0.9)
  }
})

test_that("MIDI files round-trip through tuneR", {
  skip_if_not_installed("tuneR")
  n <- data.frame(onset = c(0, 0.5, 0.5), duration = 0.4, midi = c(60L, 64L, 67L), velocity = 100L)
  path <- withr::local_tempfile(fileext = ".mid")
  write_midi(n, path, program = 13L)
  m <- tuneR::readMidi(path)
  on <- m[m$event == "Note On", ]
  expect_equal(on$parameter1, c(60, 64, 67))
  expect_equal(m$parameter1[m$event == "Program Change"], 13)
  expect_equal(midi_vlq(0x3FFF), c(0xFF, 0x7F))
})

test_that("overlapping notes at the same pitch don't cut each other off", {
  # Note-ons and note-offs must alternate on every channel + key.
  n <- data.frame(onset = c(0, 0.1, 0.2, 0.3, 1, 1.05), duration = 0.5,
                  midi = c(72L, 72L, 72L, 60L, 72L, 72L), velocity = 100L)
  on <- as.integer(round(n$onset * 960))
  off <- as.integer(round((n$onset + n$duration) * 960))
  ch <- assign_channels(on, off, n$midi)
  expect_false(9L %in% ch)
  for (k in unique(paste(ch, n$midi))) {
    i <- which(paste(ch, n$midi) == k)
    i <- i[order(on[i])]
    expect_true(all(utils::head(off[i], -1) <= utils::tail(on[i], -1)))
  }
  expect_equal(ch[1:3], c(0L, 1L, 2L))
  expect_equal(ch[4], 0L)

  skip_if_not_installed("tuneR")
  path <- withr::local_tempfile(fileext = ".mid")
  write_midi(n, path)
  m <- tuneR::readMidi(path)
  expect_setequal(m$channel[m$event == "Program Change"], unique(ch))
})

test_that("dense fluidsynth renders don't clip", {
  skip_if_not(fluidsynth_ready(), "fluidsynth or its soundfont isn't available")
  chords <- data.frame(t = rep(seq(0, 2, by = 0.1), each = 5), p = rep(1:5, 21))
  s <- sonify_data(chords, p, time = t, time_scale = 1, instrument = "piano", scale = "major")
  a <- get_audio(s)
  expect_lt(mean(abs(a$samples) >= 0.899), 0.001)
})

test_that("without real instruments, GM instruments fall back to a synth stand-in", {
  s <- sonify_data(data.frame(x = 1:3), x, instrument = "xylophone", engine = "synth")
  expect_equal(choose_engine(s), list(engine = "synth", voice = "bell"))
  expect_equal(synth_standin(0L), "pluck")
  expect_equal(synth_standin(42L), "triangle")
  b <- sonify_data(data.frame(x = 1:3), x, instrument = "bell", engine = "fluidsynth")
  expect_error(choose_engine(b), "built-in synth")
})

test_that("fluidsynth renders real instruments, loud and trimmed", {
  skip_if_not(fluidsynth_ready(), "fluidsynth or its soundfont isn't available")
  race <- data.frame(behind = c(0, 0.09, 0.21, 0.30))
  s <- sonify_data(race, time = behind, time_scale = 2, instrument = "piano")
  a <- get_audio(s)
  expect_equal(s$cache$engine$engine, "fluidsynth")
  expect_equal(ncol(a$samples), 2)
  expect_equal(max(abs(a$samples)), 0.9, tolerance = 1e-3)
  last_end <- max(notes(s)$onset + notes(s)$duration)
  expect_lt(audio_seconds(a), last_end + 3)
  expect_identical(get_audio(s), a) # cached
})
