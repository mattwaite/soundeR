# Build an HTML <audio> player with the sound embedded, so it plays anywhere a
# browser does: the RStudio/Positron viewer, Quarto and R Markdown documents.
# Uses mp3 when the av package is available (much smaller), otherwise WAV.
player_tag <- function(x) {
  audio <- get_audio(x)
  wav <- tempfile(fileext = ".wav")
  on.exit(unlink(wav))
  write_wav(audio, wav)
  src <- wav
  type <- "audio/wav"
  if (requireNamespace("av", quietly = TRUE)) {
    mp3 <- tempfile(fileext = ".mp3")
    on.exit(unlink(mp3), add = TRUE)
    ok <- tryCatch({
      av::av_audio_convert(wav, mp3, verbose = FALSE)
      TRUE
    }, error = function(e) FALSE)
    if (ok) {
      src <- mp3
      type <- "audio/mpeg"
    }
  }
  htmltools::tags$audio(
    controls = NA, preload = "auto",
    src = paste0("data:", type, ";base64,", base64enc::base64encode(src))
  )
}

describe <- function(x) {
  n <- nrow(x$notes)
  secs <- x$settings$total
  inst <- x$settings$instrument$name
  engine <- x$cache$engine
  sound <- if (is.null(engine)) {
    inst
  } else if (engine$engine == "synth" && engine$voice != inst) {
    paste0(inst, " (played by the built-in ", engine$voice, " sound)")
  } else {
    inst
  }
  sprintf("%d note%s \u00b7 %.1f seconds \u00b7 %s", n, if (n == 1) "" else "s", secs, sound)
}

#' @export
print.sonification <- function(x, ...) {
  if (interactive()) {
    tag <- player_tag(x)
    cli::cli_text(describe(x))
    htmltools::html_print(htmltools::tagList(tag, htmltools::p(describe(x))))
  } else {
    cli::cli_text(describe(x))
    cli::cli_text("Print this in RStudio or Positron to hear it, or save it with {.fn save_sound}.")
  }
  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.sonification <- function(x, ...) {
  knitr::asis_output(as.character(player_tag(x)))
}

#' Save a sonification as a sound file
#'
#' The file type comes from the extension: `.wav` for plain audio, `.mp3` for
#' smaller files (needs the av package), or `.mid` for a MIDI file you can
#' open in GarageBand, MuseScore or other music software.
#'
#' @param x A sonification made by [sonify_data()].
#' @param path Where to save it, like `"season.wav"`.
#' @return `path`, invisibly.
#' @export
#' @examples
#' s <- sonify_data(data.frame(x = c(1, 5, 3)), x, instrument = "bell")
#' path <- tempfile(fileext = ".wav")
#' save_sound(s, path)
save_sound <- function(x, path) {
  check_sonification(x)
  if (!rlang::is_string(path)) cli::cli_abort("{.arg path} must be a single file name.")
  ext <- tolower(sub(".*\\.([^.]+)$", "\\1", path))
  if (ext == path) ext <- ""
  if (ext == "wav") {
    write_wav(get_audio(x), path)
  } else if (ext == "mp3") {
    rlang::check_installed("av", reason = "to save mp3 files.")
    wav <- tempfile(fileext = ".wav")
    on.exit(unlink(wav))
    write_wav(get_audio(x), wav)
    av::av_audio_convert(wav, path, verbose = FALSE)
  } else if (ext == "mid") {
    inst <- x$settings$instrument
    write_midi(x$notes, path, program = if (inst$type == "gm") inst$program else 0L)
  } else {
    cli::cli_abort(c(
      "I can't save {.file {path}}.",
      "i" = "End the file name with {.file .wav}, {.file .mp3} or {.file .mid}."
    ))
  }
  cli::cli_alert_success("Saved {.file {path}}.")
  invisible(path)
}
