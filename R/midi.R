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
# real-time sonifications, where many notes share one pitch). Give each note a
# channel where its key is free; returns 0-based channel numbers.
assign_channels <- function(on, off, key) {
  free_at <- matrix(-1L, nrow = length(midi_channels), ncol = 128)
  ch <- integer(length(on))
  for (i in order(on, off)) {
    k <- key[i] + 1L
    free <- which(free_at[, k] <= on[i])
    j <- if (length(free)) free[1] else which.min(free_at[, k])
    ch[i] <- midi_channels[j]
    free_at[j, k] <- off[i]
  }
  ch
}

# notes needs onset, duration (seconds), midi and velocity.
# At 120 bpm and 480 ticks per beat, one tick is about a millisecond.
write_midi <- function(notes, path, program = 0L, ppq = 480L, bpm = 120) {
  to_tick <- function(s) as.integer(round(s * ppq * bpm / 60))
  on <- to_tick(notes$onset)
  off <- pmax(on + 1L, to_tick(notes$onset + notes$duration))
  channel <- assign_channels(on, off, notes$midi)
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
    unlist(lapply(used, function(ch) c(0, 0xC0 + ch, program)))
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
