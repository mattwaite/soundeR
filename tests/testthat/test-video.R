skip_if_not_installed("ggplot2")

race <- data.frame(
  event = rep(c("first", "second", "third"), times = c(3, 2, 3)),
  behind = c(0, 0.2, 0.5, 0, 0.3, 0, 0.1, 0.4)
)
race_s <- sonify_data(race, time = behind, time_scale = 1, sequence = event, instrument = "sine")
style <- list(point_color = "black", playhead_color = "red", highlight_color = "tan",
              title_position = "plot")

# Built positions of each layer: 1 = highlight band, 2 = dots, 3 = playhead.
built_layers <- function(p) ggplot2::ggplot_build(p)$data

test_that("the highlight and playhead land on the row that's playing, for every group", {
  layout <- video_layout(race_s)
  expect_equal(layout$groups, c("first", "second", "third"))
  n <- notes(race_s)
  for (g in layout$groups) {
    mid <- mean(range(n$onset[n$sequence == g]))
    d <- built_layers(video_frame(layout, mid, style))
    dots_y <- unique(d[[2]]$y[layout$notes$group == g])
    expect_equal(d[[1]]$y, dots_y, info = g)
    expect_equal(d[[3]]$y, dots_y, info = g)
  }
})

test_that("the first group is drawn at the top", {
  layout <- video_layout(race_s)
  d <- built_layers(video_frame(layout, 0, style))
  first_y <- unique(d[[2]]$y[layout$notes$group == "first"])
  expect_equal(first_y, max(d[[2]]$y))
})

test_that("groups are ordered by when they play, not row order", {
  shuffled <- race[c(4, 5, 1, 2, 3, 6, 7, 8), ]
  shuffled$event <- factor(shuffled$event, levels = c("third", "first", "second"))
  s <- sonify_data(shuffled, time = behind, time_scale = 1, sequence = event, instrument = "sine")
  expect_equal(video_layout(s)$groups, c("third", "first", "second"))
})

test_that("dots fill in as their notes play", {
  layout <- video_layout(race_s)
  d <- built_layers(video_frame(layout, 0.25, style))
  played <- d[[2]]$fill == "black"
  expect_equal(played, layout$notes$onset <= 0.25)
})

test_that("the playhead follows the data's x units between notes", {
  expect_equal(playhead_x(c(0, 1), c(10, 20), 0.5), 15)
  expect_equal(playhead_x(c(0, 1), c(10, 20), 5), 20)
  expect_equal(playhead_x(2, 7, 3), 7)
})

test_that("without sequence, pitch is plotted against time, including dates", {
  games <- data.frame(day = as.Date("2026-01-01") + c(0, 3, 10), margin = c(5, -2, 9))
  s <- sonify_data(games, margin, time = day, length = 5, instrument = "sine")
  layout <- video_layout(s)
  expect_equal(layout$type, "single")
  expect_s3_class(layout$notes$x, "Date")
  expect_equal(layout$x_label, "day")
  expect_equal(layout$y_label, "margin")
  p <- video_frame(layout, 1, style)
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("themes are added last, but titles stay flush left", {
  layout <- video_layout(race_s)
  big <- ggplot2::theme(plot.title = ggplot2::element_text(size = 31))
  p <- video_frame(layout, 0, c(style, list(theme = big)))
  expect_equal(p$theme$plot.title$size, 31)
  expect_equal(p$theme$plot.title.position, "plot")

  p <- video_frame(layout, 0, c(style, list(theme = ggplot2::theme_classic())))
  expect_equal(p$theme$plot.title.position, "plot")
  expect_equal(p$theme$plot.caption.position, "plot")

  panel <- style
  panel$title_position <- "panel"
  p <- video_frame(layout, 0, c(panel, list(theme = ggplot2::theme_classic())))
  expect_equal(p$theme$plot.title.position, "panel")
})

test_that("sonify_video() checks its inputs", {
  expect_error(sonify_video(race_s, "race.gif"), "mp4")
  expect_error(sonify_video(race_s, "race.mp4", theme = "minimal"), "ggplot2 theme")
  expect_error(sonify_video(mtcars, "race.mp4"), "sonification")
})

test_that("sonify_video() writes a video with sound", {
  skip_if_not_installed("av")
  skip_on_cran()
  path <- withr::local_tempfile(fileext = ".mp4")
  suppressMessages(sonify_video(race_s, path, title = "Test", width = 320, height = 180, fps = 4))
  info <- av::av_media_info(path)
  expect_equal(info$video$width, 320)
  expect_equal(nrow(info$audio), 1)
  expect_equal(info$duration, audio_seconds(get_audio(race_s)), tolerance = 0.5)
})
