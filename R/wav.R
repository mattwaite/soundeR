# Audio inside soundeR is a list(samples = matrix [n x channels] in -1..1, sr = sample rate).

new_audio <- function(samples, sr) {
  if (is.null(dim(samples))) samples <- matrix(samples, ncol = 1)
  list(samples = samples, sr = as.integer(sr))
}

# Write 16-bit PCM WAV (mono or stereo).
write_wav <- function(audio, path) {
  s <- audio$samples
  channels <- ncol(s)
  pcm <- as.integer(round(pmax(pmin(t(s), 1), -1) * 32767))
  n <- length(pcm) * 2L
  con <- file(path, "wb")
  on.exit(close(con))
  writeChar("RIFF", con, eos = NULL)
  writeBin(36L + n, con, size = 4, endian = "little")
  writeChar("WAVE", con, eos = NULL)
  writeChar("fmt ", con, eos = NULL)
  writeBin(16L, con, size = 4, endian = "little")
  writeBin(c(1L, channels), con, size = 2, endian = "little")
  writeBin(c(audio$sr, audio$sr * channels * 2L), con, size = 4, endian = "little")
  writeBin(c(channels * 2L, 16L), con, size = 2, endian = "little")
  writeChar("data", con, eos = NULL)
  writeBin(n, con, size = 4, endian = "little")
  writeBin(pcm, con, size = 2, endian = "little")
  invisible(path)
}

# Read 16-bit PCM WAV, skipping any extra chunks.
read_wav <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  if (readChar(con, 4, useBytes = TRUE) != "RIFF") cli::cli_abort("{.file {path}} is not a WAV file.")
  readBin(con, "integer", size = 4, endian = "little")
  if (readChar(con, 4, useBytes = TRUE) != "WAVE") cli::cli_abort("{.file {path}} is not a WAV file.")
  fmt <- NULL
  repeat {
    id <- readChar(con, 4, useBytes = TRUE)
    if (length(id) == 0) cli::cli_abort("{.file {path}} has no audio data.")
    size <- readBin(con, "integer", size = 4, endian = "little")
    if (id == "fmt ") {
      f <- readBin(con, "integer", n = 2, size = 2, endian = "little", signed = FALSE)
      sr <- readBin(con, "integer", size = 4, endian = "little")
      readBin(con, "integer", size = 4, endian = "little")
      g <- readBin(con, "integer", n = 2, size = 2, endian = "little", signed = FALSE)
      if (size > 16) readBin(con, "raw", n = size - 16)
      fmt <- list(format = f[1], channels = f[2], sr = sr, bits = g[2])
    } else if (id == "data") {
      if (is.null(fmt) || !fmt$format %in% c(1L, 65534L) || fmt$bits != 16L) {
        cli::cli_abort("Only 16-bit PCM WAV files are supported.")
      }
      x <- readBin(con, "integer", n = size / 2, size = 2, endian = "little")
      m <- matrix(x / 32768, ncol = fmt$channels, byrow = TRUE)
      return(new_audio(m, fmt$sr))
    } else {
      readBin(con, "raw", n = size + size %% 2)
    }
  }
}

# Scale so the loudest sample hits `peak`.
normalize_audio <- function(audio, peak = 0.9) {
  m <- max(abs(audio$samples))
  if (m > 0) audio$samples <- audio$samples / m * peak
  audio
}

# Drop trailing near-silence, keeping `keep` seconds after the last sound.
trim_tail <- function(audio, threshold = 0.001, keep = 0.5) {
  loud <- which(apply(abs(audio$samples), 1, max) > threshold)
  if (length(loud) == 0) return(audio)
  end <- min(nrow(audio$samples), max(loud) + round(keep * audio$sr))
  audio$samples <- audio$samples[seq_len(end), , drop = FALSE]
  audio
}

audio_seconds <- function(audio) nrow(audio$samples) / audio$sr
