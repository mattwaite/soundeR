# General MIDI Level 1 programs (0-based). Checked against the GeneralUser GS
# soundfont's bank-0 preset headers, which line up slot for slot.
gm_names <- c(
  "acoustic grand piano", "bright acoustic piano", "electric grand piano", "honky-tonk piano",
  "electric piano 1", "electric piano 2", "harpsichord", "clavinet",
  "celesta", "glockenspiel", "music box", "vibraphone",
  "marimba", "xylophone", "tubular bells", "dulcimer",
  "drawbar organ", "percussive organ", "rock organ", "church organ",
  "reed organ", "accordion", "harmonica", "tango accordion",
  "nylon guitar", "steel guitar", "jazz guitar", "clean electric guitar",
  "muted electric guitar", "overdriven guitar", "distortion guitar", "guitar harmonics",
  "acoustic bass", "electric bass (finger)", "electric bass (pick)", "fretless bass",
  "slap bass 1", "slap bass 2", "synth bass 1", "synth bass 2",
  "violin", "viola", "cello", "contrabass",
  "tremolo strings", "pizzicato strings", "harp", "timpani",
  "string ensemble 1", "string ensemble 2", "synth strings 1", "synth strings 2",
  "choir aahs", "voice oohs", "synth voice", "orchestra hit",
  "trumpet", "trombone", "tuba", "muted trumpet",
  "french horn", "brass section", "synth brass 1", "synth brass 2",
  "soprano sax", "alto sax", "tenor sax", "baritone sax",
  "oboe", "english horn", "bassoon", "clarinet",
  "piccolo", "flute", "recorder", "pan flute",
  "blown bottle", "shakuhachi", "whistle", "ocarina",
  "lead 1 (square)", "lead 2 (sawtooth)", "lead 3 (calliope)", "lead 4 (chiff)",
  "lead 5 (charang)", "lead 6 (voice)", "lead 7 (fifths)", "lead 8 (bass + lead)",
  "pad 1 (new age)", "pad 2 (warm)", "pad 3 (polysynth)", "pad 4 (choir)",
  "pad 5 (bowed)", "pad 6 (metallic)", "pad 7 (halo)", "pad 8 (sweep)",
  "fx 1 (rain)", "fx 2 (soundtrack)", "fx 3 (crystal)", "fx 4 (atmosphere)",
  "fx 5 (brightness)", "fx 6 (goblins)", "fx 7 (echoes)", "fx 8 (sci-fi)",
  "sitar", "banjo", "shamisen", "koto",
  "kalimba", "bagpipe", "fiddle", "shanai",
  "tinkle bell", "agogo", "steel drums", "woodblock",
  "taiko drum", "melodic tom", "synth drum", "reverse cymbal",
  "guitar fret noise", "breath noise", "seashore", "bird tweet",
  "telephone ring", "helicopter", "applause", "gunshot"
)

gm_family <- rep(c(
  "piano", "chromatic percussion", "organ", "guitar", "bass", "strings",
  "ensemble", "brass", "reed", "pipe", "synth lead", "synth pad",
  "synth effects", "ethnic", "percussive", "sound effects"
), each = 8)

# A comfortable pitch range for each GM program: typical orchestral and band
# ranges, rounded, and trimmed to the part of the range that sounds good
# (about two and a half to three octaves). Family defaults first, then
# instruments that differ.
gm_family_range <- c(
  "piano" = "C3-C6", "chromatic percussion" = "C4-C7", "organ" = "C3-C6",
  "guitar" = "E2-E5", "bass" = "E1-G3", "strings" = "C3-C6", "ensemble" = "C3-C6",
  "brass" = "C3-C6", "reed" = "C3-C6", "pipe" = "C4-C7", "synth lead" = "C3-C6",
  "synth pad" = "C3-C6", "synth effects" = "C3-C6", "ethnic" = "C3-C6",
  "percussive" = "C3-C6", "sound effects" = "C3-C6"
)
gm_range_overrides <- c(
  "glockenspiel" = "C5-C8", "vibraphone" = "F3-F6", "marimba" = "C3-C6",
  "tubular bells" = "C4-G5", "dulcimer" = "C3-C6", "harmonica" = "C4-C7",
  "violin" = "G3-G6", "viola" = "C3-C6", "cello" = "C2-C5", "contrabass" = "E1-E3",
  "harp" = "C3-C6", "timpani" = "D2-C4",
  "trumpet" = "G3-C6", "trombone" = "E2-E5", "tuba" = "D1-D4", "muted trumpet" = "G3-C6",
  "french horn" = "F2-F5",
  "soprano sax" = "A3-D6", "alto sax" = "C#3-A5", "tenor sax" = "G#2-E5",
  "baritone sax" = "C#2-A4", "oboe" = "C4-G6", "english horn" = "E3-C6",
  "bassoon" = "A#1-C5", "clarinet" = "E3-G6",
  "piccolo" = "D5-C8", "recorder" = "C5-C7", "whistle" = "D5-D7",
  "blown bottle" = "C4-C6", "shakuhachi" = "C4-C6", "ocarina" = "C4-C6",
  "banjo" = "D3-D6", "kalimba" = "C4-E6", "bagpipe" = "C4-C6", "fiddle" = "G3-G6",
  "shanai" = "C4-C6", "tinkle bell" = "C5-C8", "agogo" = "C4-C6",
  "steel drums" = "C4-E6", "woodblock" = "C4-C6", "taiko drum" = "C3-C5",
  "melodic tom" = "C3-C5", "synth drum" = "C3-C5"
)

# c(low, high) MIDI numbers for a resolved instrument.
instrument_range <- function(inst) {
  spec <- if (inst$type == "synth") {
    "C3-C6"
  } else {
    name <- gm_names[inst$program + 1]
    if (name %in% names(gm_range_overrides)) gm_range_overrides[[name]] else gm_family_range[[gm_family[inst$program + 1]]]
  }
  note_to_midi(strsplit(spec, "-", fixed = TRUE)[[1]])
}

# The default pitch range for a set of instruments: an instrument's own range,
# or, for several, the part they share (so equal values stay equal notes
# across voices). If they share less than an octave and a half, C3 to C6.
default_range <- function(insts) {
  real <- Filter(function(i) i$type == "gm", insts)
  if (length(real) == 0) return(note_to_midi(c("C3", "C6")))
  ranges <- lapply(real, instrument_range)
  lo <- max(vapply(ranges, `[`, integer(1), 1))
  hi <- min(vapply(ranges, `[`, integer(1), 2))
  if (hi - lo >= 18) return(c(lo, hi))
  names <- unique(vapply(real, `[[`, character(1), "name"))
  cli::cli_inform(
    c("i" = "{.val {names}} have little pitch range in common, so they share C3 to C6.",
      " " = "Set {.arg range} to choose, like {.code range = c(\"C3\", \"C5\")}."),
    .frequency = "regularly", .frequency_id = paste0("soundeR_range_", paste(sort(names), collapse = "_"))
  )
  note_to_midi(c("C3", "C6"))
}

# Short, friendly names that point at a GM program.
gm_aliases <- c(
  "piano" = 0, "grand piano" = 0, "electric piano" = 4, "organ" = 16,
  "guitar" = 24, "acoustic guitar" = 24, "electric guitar" = 27,
  "bass" = 32, "electric bass" = 33, "double bass" = 43, "upright bass" = 43,
  "strings" = 48, "string ensemble" = 48, "choir" = 52, "saxophone" = 65, "sax" = 65,
  "horn" = 60, "french horns" = 60, "brass" = 61, "steel drum" = 114,
  "orchestral harp" = 46, "tin whistle" = 78, "celeste" = 8, "wood block" = 115
)

# Built-in synth sounds that need no soundfont.
synth_names <- c("sine", "triangle", "square", "bell", "pluck")

# Synth stand-ins when a GM instrument can't be played.
synth_standin <- function(program) {
  family <- gm_family[program + 1]
  if (family %in% c("chromatic percussion", "percussive")) return("bell")
  if (family %in% c("piano", "guitar", "bass", "ethnic")) return("pluck")
  "triangle"
}

#' List the instruments you can use
#'
#' Built-in synth sounds (`"sine"`, `"triangle"`, `"square"`, `"bell"`,
#' `"pluck"`) work everywhere. The 128 General MIDI instruments, such as
#' `"piano"`, `"xylophone"` or `"cello"`, use real recorded sounds through the
#' fluidsynth package. See [sound_setup()].
#'
#' @param family Optionally, only list instruments in this family, such as
#'   `"brass"` or `"chromatic percussion"`.
#' @return A tibble with the instrument `name`, its `family`, which `engine`
#'   plays it, its General MIDI `program` number (0-based), and the `low` and
#'   `high` notes of its usual range. Notes stay in that range unless you set
#'   `range` yourself.
#' @export
#' @examples
#' instruments()
#' instruments("brass")
instruments <- function(family = NULL) {
  out <- tibble::tibble(
    name = c(synth_names, gm_names),
    family = c(rep("synth", length(synth_names)), gm_family),
    engine = c(rep("synth", length(synth_names)), rep("fluidsynth", 128)),
    program = c(rep(NA_integer_, length(synth_names)), 0:127)
  )
  ranges <- lapply(c(lapply(synth_names, function(n) list(type = "synth")),
                     lapply(0:127, function(p) list(type = "gm", program = p))), instrument_range)
  out$low <- midi_to_note(vapply(ranges, `[`, integer(1), 1))
  out$high <- midi_to_note(vapply(ranges, `[`, integer(1), 2))
  if (!is.null(family)) out <- out[out$family %in% tolower(family), ]
  out
}

# Resolve a user-supplied instrument name to list(name, type, program).
resolve_instrument <- function(instrument, call = rlang::caller_env()) {
  if (!rlang::is_string(instrument)) {
    cli::cli_abort("{.arg instrument} must be a single instrument name, like {.val xylophone}.", call = call)
  }
  key <- tolower(trimws(instrument))
  if (key %in% synth_names) return(list(name = key, type = "synth", program = NA_integer_))
  if (key %in% gm_names) {
    return(list(name = key, type = "gm", program = match(key, gm_names) - 1L))
  }
  if (key %in% names(gm_aliases)) {
    return(list(name = key, type = "gm", program = as.integer(gm_aliases[[key]])))
  }
  all_names <- c(synth_names, gm_names, names(gm_aliases))
  guess <- all_names[utils::adist(key, all_names)[1, ] <= 2]
  cli::cli_abort(c(
    "I don't know an instrument called {.val {instrument}}.",
    if (length(guess)) c("i" = "Did you mean {.or {.val {guess}}}?"),
    "i" = "See all of them with {.run soundeR::instruments()}."
  ), call = call)
}
