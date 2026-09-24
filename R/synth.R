# The built-in synth: plain-R oscillators that need no soundfont.
# Each voice function returns the samples for one note, including its release.

synth_sr <- 22050L

# Attack, a gentle decay to a sustain level, then a release after the note ends.
adsr <- function(n, n_on, sr, attack = 0.01, decay = 0.1, sustain = 0.7) {
  t <- (seq_len(n) - 1) / sr
  env <- ifelse(t < attack, t / attack,
                sustain + (1 - sustain) * exp(-(t - attack) / decay))
  if (n > n_on) {
    rel <- seq_len(n - n_on)
    env[(n_on + 1):n] <- env[n_on] * exp(-5 * rel / (n - n_on))
  }
  env
}

voice_wave <- function(shape) {
  force(shape)
  function(freq, dur, sr) {
    n_on <- max(1L, round(dur * sr))
    n <- n_on + round(0.15 * sr)
    phase <- freq * (seq_len(n) - 1) / sr
    wave <- switch(shape,
      sine = sin(2 * pi * phase),
      triangle = 2 * abs(2 * (phase - floor(phase + 0.5))) - 1,
      square = 0.5 * sign(sin(2 * pi * phase))
    )
    wave * adsr(n, n_on, sr)
  }
}

# Two-operator FM with an exponential decay: glockenspiel/vibraphone-ish.
voice_bell <- function(freq, dur, sr) {
  n <- round((dur + 0.6) * sr)
  t <- (seq_len(n) - 1) / sr
  env <- exp(-3 * t / (dur + 0.6))
  env * sin(2 * pi * freq * t + 2 * env * sin(2 * pi * freq * 3.5 * t))
}

# Karplus-Strong plucked string: guitar/harp-ish.
voice_pluck <- function(freq, dur, sr) {
  n <- round((dur + 0.3) * sr)
  p <- max(2L, round(sr / freq))
  x <- c(stats::runif(p, -1, 1), numeric(max(0, n - p)))
  y <- as.numeric(stats::filter(x, c(numeric(p - 1), 0.498, 0.498), method = "recursive"))
  y[seq_len(n)] * adsr(n, round(dur * sr), sr, attack = 0.002, decay = 10, sustain = 1)
}

synth_voices <- list(
  sine = voice_wave("sine"),
  triangle = voice_wave("triangle"),
  square = voice_wave("square"),
  bell = voice_bell,
  pluck = voice_pluck
)

# `voice` is one synth voice for every note, or one per note.
render_synth <- function(notes, voice, sr = synth_sr) {
  voice <- rep_len(voice, nrow(notes))
  sounds <- lapply(seq_len(nrow(notes)), function(i) {
    synth_voices[[voice[i]]](notes$freq[i], notes$duration[i], sr) * (notes$velocity[i] / 127)
  })
  starts <- floor(notes$onset * sr) + 1
  total <- max(starts + lengths(sounds)) + round(0.2 * sr)
  buf <- numeric(total)
  for (i in seq_along(sounds)) {
    idx <- starts[i] + seq_along(sounds[[i]]) - 1
    buf[idx] <- buf[idx] + sounds[[i]]
  }
  normalize_audio(new_audio(buf, sr))
}
