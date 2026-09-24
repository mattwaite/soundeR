#' Save a sonification as a video with a moving chart
#'
#' `sonify_video()` makes an MP4 video of your sonification: a chart of the
#' data, with a playhead that moves across it and dots that fill in as each
#' note plays, and the sound as the soundtrack. Videos are handy where audio
#' players aren't allowed, like a GitHub README, social media or slides.
#'
#' The chart depends on how you made the sonification:
#'
#' * From [sonify_histogram()], a histogram whose bars fill in as the sweep
#'   passes them. From [sonify_density()], a curve that fills in the same way.
#' * With `sequence`, each group gets its own row, like the New York Times's
#'   2010 Olympic Musical. The row that's playing is highlighted.
#' * Without `sequence`, the chart plots `pitch` (up the side) against `time`
#'   or row order (along the bottom).
#'
#' ## Changing the look
#'
#' `theme` accepts any ggplot2 theme, just like adding one to a ggplot: a
#' complete theme such as `ggplot2::theme_classic()`, or a few changes such
#' as `ggplot2::theme(plot.title = ggplot2::element_text(size = 24))`. It's
#' added last, so it overrides soundeR's defaults.
#'
#' Titles and captions line up with the edge of the whole image, not the
#' plot panel (`plot.title.position = "plot"`), even with a complete theme.
#' Use `title_position = "panel"` for ggplot2's default.
#'
#' @param x A sonification made by [sonify_data()].
#' @param path Where to save the video. Must end in `.mp4`.
#' @param title,subtitle,caption Optional text for the chart.
#' @param x_label,y_label Axis labels. By default, the names of the columns you
#'   mapped.
#' @param theme Optional. A ggplot2 theme to change how the chart looks.
#' @param title_position `"plot"` (the default) lines titles and captions up
#'   with the whole image; `"panel"` lines them up with the plot panel.
#' @param point_color Color for the dots. With more than one voice, one color
#'   per voice, in order or named by voice; by default each voice gets its
#'   own color from a colorblind-friendly palette.
#' @param playhead_color,highlight_color Colors for the moving playhead and
#'   the band behind the row that's playing.
#' @param width,height Size of the video in pixels.
#' @param fps Frames per second. Higher is smoother but slower to make.
#'
#' @return `path`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' luge_finals |>
#'   sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano") |>
#'   sonify_video(
#'     "luge.mp4",
#'     title = "Fractions of a second",
#'     subtitle = "Each note is a sled crossing the finish line",
#'     x_label = "Seconds behind the winner",
#'     theme = ggplot2::theme_classic()
#'   )
#' }
sonify_video <- function(x, path, title = NULL, subtitle = NULL, caption = NULL,
                         x_label = NULL, y_label = NULL,
                         theme = NULL, title_position = c("plot", "panel"),
                         point_color = NULL, playhead_color = "#c8102e",
                         highlight_color = "#f2efe6", width = 1280, height = 720,
                         fps = 12) {
  check_sonification(x)
  rlang::check_installed(c("ggplot2", "av"), reason = "to make videos.")
  if (!rlang::is_string(path) || !grepl("\\.mp4$", path, ignore.case = TRUE)) {
    cli::cli_abort("{.arg path} must be a file name ending in {.file .mp4}, like {.file luge.mp4}.")
  }
  if (!is.null(theme) && !inherits(theme, "theme")) {
    cli::cli_abort(c(
      "{.arg theme} must be a ggplot2 theme, like {.code ggplot2::theme_minimal()}.",
      "x" = "You supplied {.obj_type_friendly {theme}}."
    ))
  }
  title_position <- rlang::arg_match(title_position)
  check_positive(fps, "fps", rlang::current_env())

  audio_file <- tempfile(fileext = ".wav")
  on.exit(unlink(audio_file))
  audio <- get_audio(x)
  write_wav(audio, audio_file)
  frame_times <- seq(0, audio_seconds(audio), by = 1 / fps)

  layout <- video_layout(x)
  voice_colors(layout$voices, point_color) # check the colors before drawing
  if (!is.null(x_label)) layout$x_label <- x_label
  if (!is.null(y_label)) layout$y_label <- y_label
  style <- list(
    title = title, subtitle = subtitle, caption = caption, theme = theme,
    title_position = title_position, point_color = point_color,
    playhead_color = playhead_color, highlight_color = highlight_color
  )

  n_frames <- length(frame_times)
  cli::cli_progress_bar(paste("Drawing", n_frames, "frames"), total = n_frames)
  av::av_capture_graphics(
    {
      for (t in frame_times) {
        print(video_frame(layout, t, style))
        cli::cli_progress_update()
      }
    },
    output = path, width = width, height = height, res = 110,
    framerate = fps, audio = audio_file, verbose = FALSE
  )
  cli::cli_progress_done()
  cli::cli_alert_success("Saved {.file {path}}.")
  invisible(path)
}

# Everything about the chart that doesn't change from frame to frame.
video_layout <- function(x) {
  n <- x$notes
  labels <- x$settings$labels
  voices <- x$settings$voices
  n$voice_key <- if (is.null(voices)) factor("all") else factor(n$voice, levels = voices)
  common <- list(voices = voices, legend_title = labels$voice)
  if (!is.null(x$settings$density)) {
    n <- n[order(n$onset), ]
    last <- nrow(n)
    c(common, list(
      type = "density", notes = n,
      head_onset = c(n$onset, n$onset[last] + x$settings$density$step),
      head_x = c(n$x_value, n$x_value[last]),
      x_label = labels$x, y_label = labels$pitch
    ))
  } else if (!is.null(x$settings$histogram)) {
    h <- x$settings$histogram
    # The playhead reaches each bar's left edge as its note starts, and the
    # right edge of the last bar as the sweep ends.
    last <- which.max(n$onset)
    c(common, list(
      type = "histogram", notes = n,
      head_onset = c(n$onset, n$onset[last] + h$step),
      head_x = c(n$bin_start, n$bin_end[last]),
      x_label = labels$x, y_label = labels$pitch
    ))
  } else if (!is.null(labels$sequence)) {
    # Groups in the order they play.
    starts <- sort(tapply(n$onset, n$sequence, min))
    groups <- names(starts)
    n$group <- factor(n$sequence, levels = groups)
    n$x <- if (is.null(labels$time)) {
      stats::ave(n$onset, n$group, FUN = seq_along)
    } else {
      tv <- time_to_numeric(n$time_value)
      tv - stats::ave(tv, n$group, FUN = function(v) min(v, na.rm = TRUE))
    }
    c(common, list(
      type = "sequence", notes = n, groups = groups, starts = starts,
      x_label = if (is.null(labels$time)) "Order" else labels$time,
      y_label = NULL,
      x_range = range(n$x)
    ))
  } else {
    n$x <- if (is.null(labels$time)) n$row else n$time_value
    if (inherits(n$x, "difftime")) n$x <- as.numeric(n$x, units = "secs")
    n$y <- if (is.null(labels$pitch)) factor(" ") else n$value
    c(common, list(
      type = "single", notes = n,
      x_label = if (is.null(labels$time)) "Row" else labels$time,
      y_label = paste(labels$pitch, collapse = " and ")
    ))
  }
}

# Where the playhead sits at sound time `t`, in the chart's x units: the notes'
# onsets map to their x positions, and the playhead moves in between.
playhead_x <- function(onset, x, t) {
  x_num <- as.numeric(x)
  if (length(unique(onset)) < 2) return(x_num[1])
  stats::approx(onset, x_num, xout = t, rule = 2, ties = mean)$y
}

restore_x_class <- function(v, like) {
  if (inherits(like, "Date")) return(as.Date(v, origin = "1970-01-01"))
  if (inherits(like, "POSIXct")) return(as.POSIXct(v, origin = "1970-01-01", tz = attr(like, "tzone") %||% ""))
  v
}

# Build the ggplot for one frame. Every highlight is positioned through the
# data (mapped to the same group as the dots), so it always lands on the row
# that's playing, whatever order the axis shows.
video_frame <- function(layout, t, style) {
  n <- layout$notes
  n$played <- n$onset <= t + 1e-9
  colors <- voice_colors(layout$voices, style$point_color)
  # Played dots fill with their voice's color; unplayed ones are hollow.
  n$fill <- ifelse(n$played, colors[as.character(n$voice_key)], "white")
  dots <- ggplot2::geom_point(
    ggplot2::aes(fill = .data$fill, colour = .data$voice_key),
    shape = 21, size = 3.2, stroke = 0.6
  )

  if (layout$type == "sequence") {
    current <- layout$groups[max(which(layout$starts <= t + 1e-9), 1)]
    cur <- n[n$group == current, ]
    head <- playhead_x(cur$onset, cur$x, t)
    span <- diff(layout$x_range)
    pad <- max(span * 0.04, 0.05)
    band <- data.frame(group = factor(current, levels = layout$groups),
                       x = mean(layout$x_range), width = (span + 2 * pad) * 3)
    head_df <- data.frame(group = band$group, x = head)

    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x, y = .data$group)) +
      ggplot2::geom_tile(data = band, ggplot2::aes(width = .data$width), height = 0.9,
                         fill = style$highlight_color) +
      dots +
      ggplot2::geom_tile(data = head_df, width = span * 0.004 + 0.002, height = 0.9,
                         fill = style$playhead_color) +
      ggplot2::scale_y_discrete(limits = rev(layout$groups)) +
      ggplot2::coord_cartesian(xlim = layout$x_range + c(-pad, pad)) +
      ggplot2::labs(x = layout$x_label, y = layout$y_label)
  } else if (layout$type == "density") {
    head <- playhead_x(layout$head_onset, layout$head_x, t)
    color <- colors[[1]]
    # The played part of the curve, ending exactly at the playhead. Add a
    # point at the playhead only if the curve doesn't already have one there:
    # a repeated x would make the area double up at that spot.
    played <- n[n$x_value <= head, c("x_value", "value")]
    if (nrow(played) > 0 && !any(abs(n$x_value - head) < 1e-9)) {
      at_head <- stats::approx(n$x_value, n$value, xout = head)$y
      played <- rbind(played, data.frame(x_value = head, value = at_head))
    }
    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x_value, y = .data$value)) +
      ggplot2::geom_area(fill = "#e3e3e3", position = "identity") +
      (if (nrow(played) > 1) ggplot2::geom_area(data = played, fill = color, position = "identity")) +
      ggplot2::geom_line(colour = color, linewidth = 0.6) +
      ggplot2::geom_vline(xintercept = head, colour = style$playhead_color, linewidth = 0.9) +
      # Fixed limits, so nothing drawn in one frame can move the axis.
      ggplot2::scale_y_continuous(limits = c(0, max(n$value)),
                                  expand = ggplot2::expansion(mult = c(0, 0.05))) +
      ggplot2::labs(x = layout$x_label, y = layout$y_label)
  } else if (layout$type == "histogram") {
    # Bars not yet played are light gray, so the shape shows from the start.
    n$fill <- ifelse(n$played, colors[as.character(n$voice_key)], "#e3e3e3")
    head <- playhead_x(layout$head_onset, layout$head_x, t)
    p <- ggplot2::ggplot(n) +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = .data$bin_start, xmax = .data$bin_end, ymin = 0, ymax = .data$value,
                     fill = .data$fill, colour = .data$voice_key),
        linewidth = 0
      ) +
      ggplot2::geom_vline(xintercept = head, colour = style$playhead_color, linewidth = 0.9) +
      ggplot2::scale_y_continuous(labels = scales::label_comma(), expand = ggplot2::expansion(mult = c(0, 0.05))) +
      ggplot2::labs(x = layout$x_label, y = layout$y_label)
  } else {
    head <- restore_x_class(playhead_x(n$onset, n$x, t), n$x)
    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x, y = .data$y)) +
      ggplot2::geom_vline(xintercept = head, colour = style$playhead_color, linewidth = 0.9) +
      dots +
      ggplot2::labs(x = layout$x_label, y = layout$y_label)
  }

  p <- p +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_colour_manual(
      values = colors, name = layout$legend_title,
      guide = if (length(colors) > 1) {
        ggplot2::guide_legend(override.aes = list(fill = unname(colors), size = 4))
      } else {
        "none"
      }
    ) +
    ggplot2::labs(title = style$title, subtitle = style$subtitle, caption = style$caption) +
    video_default_theme(layout$type)
  if (!is.null(style$theme)) p <- p + style$theme
  # Keep titles where the user asked, even after a complete theme.
  p + ggplot2::theme(
    plot.title.position = style$title_position,
    plot.caption.position = style$title_position
  )
}

video_default_theme <- function(type) {
  ggplot2::theme_minimal(base_size = 15) +
    ggplot2::theme(
      panel.grid.major.y = if (type == "sequence") ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      legend.position = "top",
      legend.justification = "left",
      legend.location = "plot",
      plot.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
}

# Okabe-Ito colors (colorblind-friendly), minus the red-orange that would
# clash with the playhead, led by the single-voice navy.
voice_palette <- c("#1f2d3d", "#E69F00", "#0072B2", "#009E73", "#CC79A7",
                   "#56B4E9", "#F0E442", "#999999")

# One color per voice, named by voice ("all" when there are no voices).
voice_colors <- function(voices, point_color = NULL, call = rlang::caller_env()) {
  keys <- voices %||% "all"
  if (is.null(point_color)) {
    if (length(keys) > length(voice_palette)) {
      cli::cli_abort("There are {length(keys)} voices; give {.arg point_color} one color for each.", call = call)
    }
    return(rlang::set_names(voice_palette[seq_along(keys)], keys))
  }
  if (!is.character(point_color)) cli::cli_abort("{.arg point_color} must be colors, like {.val navy}.", call = call)
  if (!is.null(names(point_color)) && !is.null(voices)) {
    missing_voices <- setdiff(keys, names(point_color))
    if (length(missing_voices)) {
      cli::cli_abort("{.arg point_color} has no color for {.val {missing_voices}}.", call = call)
    }
    return(point_color[keys])
  }
  point_color <- unname(point_color)
  if (length(point_color) == 1) return(rlang::set_names(rep(point_color, length(keys)), keys))
  if (length(point_color) != length(keys)) {
    cli::cli_abort("{.arg point_color} has {length(point_color)} colors for {length(keys)} voices.", call = call)
  }
  rlang::set_names(point_color, keys)
}
