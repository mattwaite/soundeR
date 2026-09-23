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
#'   plays it, and its General MIDI `program` number (0-based).
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
