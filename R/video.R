#' Draw a sonification as a chart
#'
#' `sonify_plot()` draws the chart that [sonify_video()] animates, as an
#' ordinary ggplot, with every note played. Print it for a picture of your
#' sonification, or change it the way you'd change any ggplot (add `labs()`,
#' scales, annotations or a theme) and pass it to `sonify_video()` with
#' `plot =`. The video adds the moving playhead on top.
#'
#' The chart depends on how you made the sonification:
#'
#' * From [sonify_histogram()], a histogram. From [sonify_density()], a
#'   density curve.
#' * With `sequence`, each group gets its own row, like the New York Times's
#'   2010 Olympic Musical.
#' * Otherwise, `pitch` (up the side) against `time` or row order (along the
#'   bottom).
#'
#' Titles and captions line up with the edge of the whole image, not the
#' plot panel (`plot.title.position = "plot"`), even with a complete theme
#' given to `theme`. Use `title_position = "panel"` for ggplot2's default. If
#' you add a complete theme to the result yourself, with `+`, ggplot2 resets
#' the title position, so add `ggplot2::theme(plot.title.position = "plot")`
#' after it. [sonify_video()] lines titles up for you either way.
#'
#' @param x A sonification made by [sonify_data()], [sonify_histogram()] or
#'   [sonify_density()].
#' @param title,subtitle,caption Optional text for the chart.
#' @param x_label,y_label Axis labels. By default, the names of the columns you
#'   mapped.
#' @param theme Optional. A ggplot2 theme, complete (like
#'   `ggplot2::theme_classic()`) or partial (like
#'   `ggplot2::theme(plot.title = ggplot2::element_text(size = 24))`). It's
#'   added last, so it overrides soundeR's defaults.
#' @param title_position `"plot"` (the default) lines titles and captions up
#'   with the whole image; `"panel"` lines them up with the plot panel.
#' @param point_color Color for the dots (or bars, or curve). With more than
#'   one voice, one color per voice, in order or named by voice; by default
#'   each voice gets its own color from a colorblind-friendly palette.
#'
#' @return A ggplot.
#' @export
#' @examples
#' \dontrun{
#' race <- luge_finals |>
#'   sonify_data(time = behind, time_scale = 1, sequence = event, instrument = "piano")
#'
#' # A picture of the sonification
#' sonify_plot(race)
#'
#' # Customize it like any ggplot, then animate it
#' p <- sonify_plot(race) +
#'   ggplot2::labs(title = "Fractions of a second", x = "Seconds behind the winner") +
#'   ggplot2::scale_x_continuous(labels = function(s) paste0("+", s, " s"))
#' sonify_video(race, "luge.mp4", plot = p)
#' }
sonify_plot <- function(x, title = NULL, subtitle = NULL, caption = NULL,
                        x_label = NULL, y_label = NULL, theme = NULL,
                        title_position = c("plot", "panel"), point_color = NULL) {
  check_sonification(x)
  rlang::check_installed("ggplot2", reason = "to draw sonifications.")
  check_theme(theme)
  title_position <- rlang::arg_match(title_position)
  layout <- video_layout(x)
  voice_colors(layout$voices, point_color) # check the colors before drawing
  if (!is.null(x_label)) layout$x_label <- x_label
  if (!is.null(y_label)) layout$y_label <- y_label
  style <- list(
    title = title, subtitle = subtitle, caption = caption, theme = theme,
    title_position = title_position, point_color = point_color
  )
  p <- video_base(layout, style)
  attr(p, "soundeR_layout") <- layout
  attr(p, "soundeR_colors") <- voice_colors(layout$voices, point_color)
  p
}

#' Save a sonification as a video with a moving chart
#'
#' `sonify_video()` makes an MP4 video of your sonification: a chart of the
#' data, with a playhead that moves across it and marks that fill in as each
#' note plays, and the sound as the soundtrack. Videos are handy where audio
#' players aren't allowed, like a GitHub README, social media or slides.
#'
#' The chart is the one [sonify_plot()] draws. To change more than the
#' title, labels and theme, build it yourself with `sonify_plot()`, add to it
#' like any ggplot, and pass it in with `plot =`.
#'
#' @inheritParams sonify_plot
#' @param path Where to save the video. Must end in `.mp4`.
#' @param plot Optional. A chart made with [sonify_plot()] from this same
#'   sonification, customized however you like.
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
sonify_video <- function(x, path, plot = NULL, title = NULL, subtitle = NULL, caption = NULL,
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
  check_theme(theme)
  title_position <- rlang::arg_match(title_position)
  check_positive(fps, "fps", rlang::current_env())

  if (is.null(plot)) {
    plot <- sonify_plot(x, title = title, subtitle = subtitle, caption = caption,
                        x_label = x_label, y_label = y_label, theme = theme,
                        title_position = title_position, point_color = point_color)
  } else {
    check_video_plot(plot, x)
    if (!is.null(point_color)) {
      cli::cli_warn("{.arg point_color} is ignored with {.arg plot}; set it in {.fn sonify_plot} instead.")
    }
    extra <- list(title = title, subtitle = subtitle, caption = caption, x = x_label, y = y_label)
    extra <- extra[!vapply(extra, is.null, logical(1))]
    if (length(extra)) plot <- plot + do.call(ggplot2::labs, extra)
    if (!is.null(theme)) plot <- plot + theme
    plot <- plot + ggplot2::theme(plot.title.position = title_position,
                                  plot.caption.position = title_position)
  }
  layout <- attr(plot, "soundeR_layout")
  style <- list(
    colors = attr(plot, "soundeR_colors"), playhead_color = playhead_color,
    highlight_color = highlight_color
  )

  audio_file <- tempfile(fileext = ".wav")
  on.exit(unlink(audio_file))
  audio <- get_audio(x)
  write_wav(audio, audio_file)
  frame_times <- seq(0, audio_seconds(audio), by = 1 / fps)

  n_frames <- length(frame_times)
  cli::cli_progress_bar(paste("Drawing", n_frames, "frames"), total = n_frames)
  av::av_capture_graphics(
    {
      for (t in frame_times) {
        print(add_frame_layers(plot, layout, t, style))
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

check_theme <- function(theme, call = rlang::caller_env()) {
  if (!is.null(theme) && !inherits(theme, "theme")) {
    cli::cli_abort(c(
      "{.arg theme} must be a ggplot2 theme, like {.code ggplot2::theme_minimal()}.",
      "x" = "You supplied {.obj_type_friendly {theme}}."
    ), call = call)
  }
}

# A plot passed to sonify_video() must come from sonify_plot() of the same
# sonification, so the playhead knows where every note is.
check_video_plot <- function(plot, x, call = rlang::caller_env()) {
  layout <- attr(plot, "soundeR_layout")
  if (!inherits(plot, "ggplot") || is.null(layout)) {
    cli::cli_abort(c(
      "{.arg plot} must be a chart made with {.fn sonify_plot}.",
      "i" = "Start with {.code p <- sonify_plot(x)}, add to it like any ggplot, then use {.code plot = p}."
    ), call = call)
  }
  if (!identical(layout$notes$onset, video_layout(x)$notes$onset)) {
    cli::cli_abort(c(
      "{.arg plot} was made from a different sonification.",
      "i" = "Make it with {.fn sonify_plot} from the same sonification you're turning into a video."
    ), call = call)
  }
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

# The finished chart, with every note played. Frames add layers on top of it
# (see add_frame_layers()), so anything added to this plot stays put.
video_base <- function(layout, style) {
  n <- layout$notes
  colors <- voice_colors(layout$voices, style$point_color)
  n$fill <- unname(colors[as.character(n$voice_key)])
  dots <- ggplot2::geom_point(
    ggplot2::aes(fill = .data$fill, colour = .data$voice_key),
    shape = 21, size = 3.2, stroke = 0.6
  )

  if (layout$type == "sequence") {
    pad <- max(diff(layout$x_range) * 0.04, 0.05)
    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x, y = .data$group)) +
      dots +
      ggplot2::scale_y_discrete(limits = rev(layout$groups)) +
      ggplot2::coord_cartesian(xlim = layout$x_range + c(-pad, pad))
  } else if (layout$type == "density") {
    color <- colors[[1]]
    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x_value, y = .data$value)) +
      ggplot2::geom_area(fill = color, position = "identity") +
      ggplot2::geom_line(colour = color, linewidth = 0.6) +
      # Fixed limits, so nothing drawn in one frame can move the axis.
      ggplot2::scale_y_continuous(limits = c(0, max(n$value)),
                                  expand = ggplot2::expansion(mult = c(0, 0.05)))
  } else if (layout$type == "histogram") {
    p <- ggplot2::ggplot(n) +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = .data$bin_start, xmax = .data$bin_end, ymin = 0, ymax = .data$value,
                     fill = .data$fill, colour = .data$voice_key),
        linewidth = 0
      ) +
      ggplot2::scale_y_continuous(labels = scales::label_comma(),
                                  expand = ggplot2::expansion(mult = c(0, 0.05)))
  } else {
    p <- ggplot2::ggplot(n, ggplot2::aes(x = .data$x, y = .data$y)) + dots
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
    ggplot2::labs(x = layout$x_label, y = layout$y_label, title = style$title,
                  subtitle = style$subtitle, caption = style$caption) +
    video_default_theme(layout$type)
  if (!is.null(style$theme)) p <- p + style$theme
  # Keep titles where the user asked, even after a complete theme.
  p + ggplot2::theme(
    plot.title.position = style$title_position,
    plot.caption.position = style$title_position
  )
}

# Add one frame's moving parts to a finished chart: gray or hollow marks over
# the notes that haven't played yet, the highlight band (at the very bottom)
# and the playhead (on top). Every highlight is positioned through the data,
# mapped to the same group as the dots, so it always lands on the row that's
# playing, whatever order the axis shows.
add_frame_layers <- function(p, layout, t, style) {
  n <- layout$notes
  waiting <- n[n$onset > t + 1e-9, ]
  hollow <- ggplot2::geom_point(
    data = waiting, ggplot2::aes(colour = .data$voice_key),
    fill = "white", shape = 21, size = 3.2, stroke = 0.6
  )
  playhead <- function(x) ggplot2::geom_vline(xintercept = x, colour = style$playhead_color, linewidth = 0.9)

  if (layout$type == "sequence") {
    current <- layout$groups[max(which(layout$starts <= t + 1e-9), 1)]
    cur <- n[n$group == current, ]
    head <- playhead_x(cur$onset, cur$x, t)
    span <- diff(layout$x_range)
    pad <- max(span * 0.04, 0.05)
    row <- factor(current, levels = layout$groups)
    band <- ggplot2::geom_tile(
      data = data.frame(group = row, x = mean(layout$x_range), width = (span + 2 * pad) * 3),
      ggplot2::aes(width = .data$width), height = 0.9, fill = style$highlight_color
    )
    p$layers <- c(list(band), p$layers)
    p + hollow +
      ggplot2::geom_tile(data = data.frame(group = row, x = head),
                         width = span * 0.004 + 0.002, height = 0.9, fill = style$playhead_color)
  } else if (layout$type == "density") {
    head <- playhead_x(layout$head_onset, layout$head_x, t)
    # The part of the curve still to come, starting exactly at the playhead.
    # Add a point there only if the curve doesn't already have one: a
    # repeated x would make the area double up at that spot.
    ahead <- n[n$x_value >= head, c("x_value", "value")]
    if (nrow(ahead) > 0 && !any(abs(n$x_value - head) < 1e-9)) {
      at_head <- stats::approx(n$x_value, n$value, xout = head)$y
      ahead <- rbind(data.frame(x_value = head, value = at_head), ahead)
    }
    color <- style$colors[[1]]
    p + (if (nrow(ahead) > 1) ggplot2::geom_area(data = ahead, fill = "#e3e3e3", position = "identity")) +
      ggplot2::geom_line(colour = color, linewidth = 0.6) +
      playhead(head)
  } else if (layout$type == "histogram") {
    # Bars not yet played are light gray, so the shape shows from the start.
    p + ggplot2::geom_rect(
      data = waiting,
      ggplot2::aes(xmin = .data$bin_start, xmax = .data$bin_end, ymin = 0, ymax = .data$value),
      fill = "#e3e3e3", colour = NA, inherit.aes = FALSE
    ) + playhead(playhead_x(layout$head_onset, layout$head_x, t))
  } else {
    p + hollow + playhead(restore_x_class(playhead_x(n$onset, n$x, t), n$x))
  }
}

# One whole frame, for tests and previews.
video_frame <- function(layout, t, style) {
  base <- video_base(layout, style)
  add_frame_layers(base, layout, t, c(style, list(colors = voice_colors(layout$voices, style$point_color))))
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
