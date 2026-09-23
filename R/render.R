fluidsynth_ready <- function() {
  requireNamespace("fluidsynth", quietly = TRUE) &&
    !is.null(tryCatch(fluidsynth::soundfont_path(), error = function(e) NULL))
}

# Decide which engine and voice will actually play this sonification.
choose_engine <- function(x, call = rlang::caller_env()) {
  inst <- x$settings$instrument
  engine <- x$settings$engine
  if (inst$type == "synth") {
    if (engine == "fluidsynth") {
      cli::cli_abort(c(
        "{.val {inst$name}} is a built-in synth sound, so it can't use {.code engine = \"fluidsynth\"}.",
        "i" = "Pick a real instrument from {.run soundeR::instruments()}, or use {.code engine = \"auto\"}."
      ), call = call)
    }
    return(list(engine = "synth", voice = inst$name))
  }
  if (engine != "synth" && fluidsynth_ready()) {
    return(list(engine = "fluidsynth", program = inst$program))
  }
  if (engine == "fluidsynth") {
    cli::cli_abort(c(
      "Real instruments aren't set up yet.",
      "i" = "Run {.run soundeR::sound_setup()} once to set them up."
    ), call = call)
  }
  standin <- synth_standin(inst$program)
  if (engine == "auto") {
    cli::cli_inform(
      c("i" = "Playing {.val {inst$name}} with the built-in {.val {standin}} sound because real instruments aren't set up.",
        " " = "Run {.run soundeR::sound_setup()} once to hear the real thing."),
      .frequency = "regularly", .frequency_id = "soundeR_standin"
    )
  }
  list(engine = "synth", voice = standin)
}

render_fluidsynth <- function(notes, program) {
  mid <- tempfile(fileext = ".mid")
  wav <- tempfile(fileext = ".wav")
  on.exit(unlink(c(mid, wav)))
  write_midi(notes, mid, program = program)
  # fluidsynth's default gain (0.2) is very quiet, so render louder and then
  # normalize. Many notes at once can clip, so back off the gain if they do.
  gain <- 0.6
  repeat {
    fluidsynth::midi_convert(
      mid, soundfont = fluidsynth::soundfont_path(), output = wav,
      settings = list(synth.gain = gain), verbose = FALSE
    )
    audio <- read_wav(wav)
    if (max(abs(audio$samples)) < 0.99 || gain < 0.05) break
    gain <- gain / 3
  }
  trim_tail(normalize_audio(audio), keep = 0.75)
}

# Render (or fetch from the cache) the audio for a sonification.
get_audio <- function(x) {
  if (!is.null(x$cache$audio)) return(x$cache$audio)
  choice <- choose_engine(x)
  audio <- if (choice$engine == "fluidsynth") {
    render_fluidsynth(x$notes, choice$program)
  } else {
    render_synth(x$notes, choice$voice)
  }
  x$cache$engine <- choice
  x$cache$audio <- audio
  audio
}

#' Set up real instruments
#'
#' soundeR can play 128 real instruments, like piano, xylophone and cello,
#' through the fluidsynth package. They need a one-time download of a
#' "soundfont", a file of recorded instrument sounds (about 30 MB).
#' `sound_setup()` checks what's missing and downloads it.
#'
#' Without it, soundeR still works using its built-in synth sounds.
#'
#' @return `TRUE` if real instruments are ready, invisibly.
#' @export
#' @examples
#' \dontrun{
#' sound_setup()
#' }
sound_setup <- function() {
  if (!requireNamespace("fluidsynth", quietly = TRUE)) {
    cli::cli_inform(c(
      "x" = "The {.pkg fluidsynth} package isn't installed.",
      "i" = "Install it with {.run install.packages(\"fluidsynth\")}, then run {.run soundeR::sound_setup()} again."
    ))
    return(invisible(FALSE))
  }
  if (is.null(tryCatch(fluidsynth::soundfont_path(), error = function(e) NULL))) {
    cli::cli_inform("Downloading instrument sounds (about 30 MB, one time only)...")
    fluidsynth::soundfont_download()
  }
  cli::cli_alert_success("Real instruments are ready. Try {.code instrument = \"xylophone\"}.")
  invisible(TRUE)
}
