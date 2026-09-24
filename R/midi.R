# A small Standard MIDI File writer (format 0, one track, one channel).

midi_vlq <- function(x) {
  bytes <- bitwAnd(x, 0x7F)
  x <- bitwShiftR(x, 7)
  while (x > 0) {
    bytes <- c(bitwOr(bitwAnd(x, 0x7F), 0x80), bytes)
    x <- bitwShiftR(x, 7)
  }
  bytes
}

midi_u32 <- function(x) {
  c(bitwShiftR(x, 24), bitwAnd(bitwShiftR(x, 16), 0xFF),
    bitwAnd(bitwShiftR(x, 8), 0xFF), bitwAnd(x, 0xFF))
}

midi_u16 <- function(x) c(bitwShiftR(x, 8), bitwAnd(x, 0xFF))

# Melodic channels: all 16 except channel 10 (index 9), which is drums.
midi_channels <- setdiff(0:15, 9L)

# In MIDI a note-off silences whatever is sounding on that channel and key, so
# two overlapping notes at the same pitch would cut each other short (common in
# real-time sonifications, where many notes share one pitch). And each channel
# plays one instrument at a time. So give each note a channel that already
# plays its instrument (`program`) and where its key is free, opening a new
# channel when needed. Returns 0-based channel numbers.
assign_channels <- function(on, off, key, program = 0L, call = rlang::caller_env()) {
  program <- rep_len(as.integer(program), length(on))
  n_ch <- length(midi_channels)
  free_at <- matrix(-1L, nrow = n_ch, ncol = 128)
  ch_program <- rep(NA_integer_, n_ch)
  ch <- integer(length(on))
  for (i in order(on, off)) {
    k <- key[i] + 1L
    mine <- which(ch_program == program[i])
    free <- mine[free_at[mine, k] <= on[i]]
    if (length(free)) {
      j <- free[1]
    } else if (anyNA(ch_program)) {
      j <- which(is.na(ch_program))[1]
      ch_program[j] <- program[i]
    } else if (length(mine)) {
      j <- mine[which.min(free_at[mine, k])]
    } else {
      cli::cli_abort("Too many different instruments at once; MIDI allows 15.", call = call)
    }
    ch[i] <- midi_channels[j]
    free_at[j, k] <- off[i]
  }
  ch
}

# notes needs onset, duration (seconds), midi and velocity. `program` is a
# General MIDI program (0-based), one for all notes or one per note.
# At 120 bpm and 480 ticks per beat, one tick is about a millisecond.
write_midi <- function(notes, path, program = 0L, ppq = 480L, bpm = 120) {
  to_tick <- function(s) as.integer(round(s * ppq * bpm / 60))
  on <- to_tick(notes$onset)
  off <- pmax(on + 1L, to_tick(notes$onset + notes$duration))
  program <- rep_len(as.integer(program), nrow(notes))
  channel <- assign_channels(on, off, notes$midi, program)
  ev <- rbind(
    data.frame(tick = on, status = 0x90 + channel, d1 = notes$midi, d2 = notes$velocity, ord = 1L),
    data.frame(tick = off, status = 0x80 + channel, d1 = notes$midi, d2 = 0L, ord = 0L)
  )
  # Note-offs go before note-ons at the same tick so repeated notes retrigger.
  ev <- ev[order(ev$tick, ev$ord), ]
  tempo <- as.integer(round(60e6 / bpm))
  used <- sort(unique(channel))
  body <- c(
    0, 0xFF, 0x51, 0x03, bitwAnd(bitwShiftR(tempo, 16), 0xFF),
    bitwAnd(bitwShiftR(tempo, 8), 0xFF), bitwAnd(tempo, 0xFF),
    unlist(lapply(used, function(ch) c(0, 0xC0 + ch, program[match(ch, channel)])))
  )
  deltas <- diff(c(0L, ev$tick))
  body <- c(body, unlist(lapply(seq_len(nrow(ev)), function(i) {
    c(midi_vlq(deltas[i]), ev$status[i], ev$d1[i], ev$d2[i])
  })))
  body <- c(body, 0, 0xFF, 0x2F, 0x00)
  bytes <- c(
    utf8ToInt("MThd"), midi_u32(6), midi_u16(0), midi_u16(1), midi_u16(ppq),
    utf8ToInt("MTrk"), midi_u32(length(body)), body
  )
  writeBin(as.raw(bytes), path)
  invisible(path)
}
