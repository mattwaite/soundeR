s <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "bell")

test_that("the player embeds the audio", {
  html <- as.character(player_tag(s))
  expect_match(html, "^<audio")
  expect_match(html, "data:audio/(mpeg|wav);base64,")
})

test_that("knit_print gives an HTML player", {
  skip_if_not_installed("knitr")
  out <- knit_print.sonification(s)
  expect_s3_class(out, "knit_asis")
  expect_match(out, "<audio")
})

test_that("printing outside an interactive session describes the sound", {
  fresh <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "bell")
  expect_snapshot(print(fresh))
})

test_that("save_sound() writes wav, mp3 and mid files", {
  dir <- withr::local_tempdir()
  expect_message(save_sound(s, file.path(dir, "a.wav")), "Saved")
  expect_equal(read_wav(file.path(dir, "a.wav"))$sr, synth_sr)
  save_sound(s, file.path(dir, "a.mid")) |> suppressMessages()
  expect_equal(readBin(file.path(dir, "a.mid"), "raw", 4), charToRaw("MThd"))
  skip_if_not_installed("av")
  save_sound(s, file.path(dir, "a.mp3")) |> suppressMessages()
  expect_gt(file.size(file.path(dir, "a.mp3")), 1000)
})

test_that("save_sound() rejects unknown formats and non-sonifications", {
  expect_error(save_sound(s, "a.ogg"), "can't save")
  expect_error(save_sound(s, "noextension"), "can't save")
  expect_error(save_sound(mtcars, "a.wav"), "sonification")
})
