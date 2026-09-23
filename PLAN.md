# soundeR — a tidyverse-friendly data sonification package for R

> **Purpose of this document:** the design plan and working reference for building the package.
> Future work sessions should read this first, follow the roadmap, and add to the
> **Session log** at the bottom. When a decision changes, update the relevant section here.

Started: 2026-09-22 · Owner: Matt Waite

---

## 1. Why this exists

Data sonification means turning data into sound. It's the audio version of a chart. The R options today don't work for a beginner class:

| Package | Status | Problem for beginners |
|---|---|---|
| `sonify` (CRAN, Siegert, 2017) | On CRAN, version 0.0-1 (verified) | Base R `sonify(x, y)`. Makes one continuous sine sweep. No instruments, no data-frame interface. |
| `playitbyr` (ca. 2011) | Archived (from memory) | Had a ggplot-like grammar, but needed Csound installed. |
| `audiolyzR` | Abandoned (from memory) | Needed Max/MSP. |
| `tuneR` / `seewave` / `audio` | On CRAN (from memory) | Low-level signal and audio tools, not sonification tools. |

**The main inspiration: "Fractions of a Second: An Olympic Musical"** (New York Times, Feb 2010, Amanda Cox, Vancouver Winter Olympics). [Archived link](https://archive.nytimes.com/www.nytimes.com/interactive/2010/02/26/sports/olympics/20100226-olysymphony.html). I couldn't fetch the page directly; this description comes from contemporaneous write-ups (FlowingData, VizWorld):
- Each row is one event. Each dot is one athlete, placed by **seconds behind the gold medalist**.
- Press play and each athlete becomes a **piano-like note, sounded when they cross the line**. The spacing between notes *is* the real gap in finishing times, so you hear how tiny the margins are.
- **The data drives *when* notes happen, not their pitch.** Time is the mapping, played in real time (1 second of data = 1 second of audio), not stretched to fit a length. The sound is paired with a simple dot plot.
- There was also a critique: a Ryerson Review of Journalism piece titled "…a symphony of one note, repeated often." I only saw the title. It's a useful design lesson: a timing-only mapping is powerful but can be monotonous. Optional pitch (e.g., by place) and a distinct note for the winner might help.

Other inspiration outside R (from memory): Python's **STRAUSS** and **astronify**, **Highcharts Sonification**, and **TwoTone** (web app, from Datavized/Google News Initiative).

**The gap:** nothing in R does for sound what ggplot2 does for pictures. That means a data-first, pipeable interface with column mappings, sensible defaults that sound musical, and output that "just plays" in RStudio, Positron, Quarto, and Posit Cloud without installing system tools.

**Teaching angles worth keeping in mind:**
- **Accessibility.** Sonification is a real tool for blind and low-vision people. This makes a strong case for it in a data class.
- **Design choices shape meaning.** Pitch range, scale, tempo, and instrument change the impression of the same data, just as axis ranges and colors do. This parallels dataviz ethics.
- **Inspectability.** Students should be able to *see* the notes their data became (see the note tibble, §4.3).

---

## 2. Target API — the acceptance tests

These three examples define "done" for the MVP and later phases. The syntax is aspirational and will be refined, but every design decision should make these read naturally.

### 2.1 A season of Nebraska basketball: an ordered sequence of events

```r
library(soundeR)

husker_games |>
  arrange(date) |>
  sonify_data(pitch = point_margin, instrument = "xylophone", bpm = 120)
```

- One note per row, played in row order. Higher pitch means a bigger win and lower pitch means a worse loss.
- Printing the result shows an audio player (§6).
- Two-voice version: pivot longer and map `voice`:

```r
husker_games |>
  pivot_longer(c(husker_score, opponent_score), names_to = "side", values_to = "score") |>
  sonify_data(pitch = score, voice = side, instrument = c("xylophone", "cello"), bpm = 120)
```

- Stretch goal: `accent = win` (win/loss changes velocity or articulation), or `instrument = result` mapped per note.

### 2.2 Every pitch of the World Series: many rows, several variables

```r
ws_pitches |>
  arrange(game_date, at_bat_number, pitch_number) |>
  sonify_data(pitch = release_speed, voice = pitch_type, length = 90)
```

- There are roughly 2,000 to 2,500 pitches in a 7-game series. At `bpm = 50` that's about **45+ minutes**. So the plan **must** support a total-duration target: `length = 90` means "fit this whole thing into 90 seconds," which overrides `bpm`.
- `voice = pitch_type` gives each pitch type its own instrument (or its own stereo pan position).
- Show a `cli` warning when output exceeds ~3 minutes, suggesting `length =`.
- Optional `time = ` mapping (e.g., a datetime column) spaces notes by real time instead of row order. Gaps between games become silence.

### 2.3 The distribution of house ages in Nebraska: a distribution, not a sequence

Playing rows in order is **meaningless** for a distribution. Row order is arbitrary. This needs a *stat* step, like `geom_histogram()` computing bins before drawing.

```r
ne_houses |>
  sonify_histogram(year_built, bins = 20, instrument = "marimba", length = 15)
```

- Bin the values, then **sweep low to high across the bins**. Each bin is a time step. Its pitch rises with bin position, and its **count maps to loudness and/or note density** (more houses means louder, or more notes in a "cloud").
- Should also accept **pre-binned** data via `weight =`. ACS table B25034 ("Year Structure Built," via `tidycensus`) already comes in bins:
  ```r
  acs_b25034 |> sonify_histogram(decade_built, weight = estimate)
  ```
- Later: `sonify_density()` (a continuous tone whose volume follows the density curve), and a boxplot-style sonification for comparing distributions (`voice = county`).

**This is the requirement that's easiest to miss. Keep distributions as a first-class case from the start.** Internally it's a stat layer that turns data into a table of timed events, then passes that table to the same renderer as `sonify_data()`.

### 2.4 The NYT Olympic Musical, recreated: time is the data (flagship example)

This is the project's north star. If a student can rebuild the 2010 NYT piece in three lines, the package works.

```r
luge_finals |>
  sonify_data(time = behind, instrument = "piano", time_scale = 1, sequence = event)

# or computing the gap yourself from total times, as students would with raw data:
luge_finals |>
  group_by(event) |>
  mutate(seconds_behind = total_time - min(total_time)) |>
  sonify_data(time = seconds_behind, instrument = "piano", time_scale = 1, sequence = event)
```

- **No `pitch` mapping.** Every note is the same pitch, or pitch is optional (`pitch = place` if wanted). So `pitch` **must be optional**, with a sensible default single note.
- **`time =` in real seconds.** `time_scale = 1` means 1 data-second = 1 audio-second. `time_scale = 4` slows it down 4x so gaps of hundredths of a second are audible. This is different from `length =`, which stretches data to fit a duration. Both are needed.
- **`sequence = event`** plays groups **one after another** with a pause between (`gap = 1` second). By contrast, `voice =` plays groups **at the same time**. Beginners need these two to be clearly different.
- The **visual companion** matters: `autoplot()` for this should look like the NYT dot plot (one row per event, dots at seconds behind). Later, `sonify_video()` can animate a playhead across it.
- Stretch: an accent or different note for the gold medalist (`accent = place == 1`).
- **Dataset: `luge_finals`** (bundled). All five luge events at Milano Cortina 2026 (77 sleds). Men's doubles gold–silver was 0.068 s. Real time (`time_scale = 1`) runs 32.8 s; 4× slow motion runs 112 s.

**Design implication:** a real piano sound is central to this example. The Tier 0 synth can't do a convincing piano, so the fluidsynth path (Phase 2) matters more than first assumed. Consider pulling it into Phase 1 if Phase 0 shows it installs cleanly.

---

## 3. Design principles

1. **Data first, pipeable.** The first argument is a data frame, and it works with `|>` and `%>%`.
2. **Tidy evaluation for mappings.** Use bare column names like `pitch = point_margin`, implemented with `rlang` (`enquo`/`{{ }}`). Computed expressions like `pitch = pts - opp_pts` should work.
3. **Sounds good by default.** Snap pitches to a **pentatonic scale** by default, so any data sounds musical instead of like a dial-up modem. Use sensible range, tempo, and instrument defaults.
4. **Returns an object and has no side effects.** `sonify_data()` returns a `sonification` object. The *print method* plays or embeds it, as with ggplot. Saving is explicit (`save_sound()`).
5. **Inspectable.** The object holds a plain tibble of note events that students can view, filter, and plot.
6. **Zero system dependencies for the default path.** A student on a school Chromebook using Posit Cloud must be able to hear something. Real instruments are the richer, optional path.
7. **Friendly errors** via `cli`: "Column `pionts` not found. Did you mean `points`?"
8. **Beginner vocabulary.** Use `pitch`, `volume`, `length`, `bpm`, and `instrument`. Avoid `midi_note`, `velocity`, `sr`, and `ADSR` in the main API. The expert terms can appear in the note tibble and advanced arguments.

---

## 4. Architecture

The pipeline works like ggplot's build process:

```
data ──► mappings (tidy eval) ──► stat (identity | histogram | density)
     ──► scales (value → pitch/volume/time, snapped to musical scale)
     ──► NOTE TIBBLE (the "score")
     ──► renderer (synth | MIDI+fluidsynth)
     ──► audio (Wave samples) ──► print → <audio> player / save_sound()
```

### 4.1 Main function signature (draft)

```r
sonify_data(
  data,
  pitch    = NULL,         # optional mapping; numeric → pitch; categorical → distinct notes;
                           #   NULL = one fixed note (see §2.4, the NYT Olympic case)
  volume   = NULL,         # optional mapping → loudness (MIDI velocity)
  duration = NULL,         # optional mapping → note length
  voice    = NULL,         # optional grouping → groups play AT THE SAME TIME (tracks/instruments)
  sequence = NULL,         # optional grouping → groups play ONE AFTER ANOTHER
  gap      = 1,            # seconds of silence between sequence groups
  time     = NULL,         # optional mapping → onset; default = row order
  time_scale = NULL,       # with time =: audio seconds per data unit (1 = real time)
  instrument = "piano",    # name, or vector of names (one per voice)
  bpm      = 120,          # notes per minute when time is row order
  length   = NULL,         # total seconds; overrides bpm / stretches time =
  scale    = "pentatonic", # "pentatonic", "major", "minor", "chromatic", "blues", "none"
  key      = "C",
  range    = c("C3", "C6"),# pitch range as note names (or MIDI numbers)
  reverse  = FALSE,        # high values → low pitch
  engine   = "auto"        # "auto" | "synth" | "fluidsynth"
)
```

`group_by()` has **no effect on the sound** (decision 3a). Only `voice =` and `sequence =` decide how groups play. Grouped input triggers a one-time hint suggesting `sequence =` or `voice =`.

### 4.2 Mapping rules

- **Numeric → pitch:** rescale linearly (via `scales::rescale`) from data range to `range` in MIDI note numbers. Then quantize to the nearest note in `scale`/`key`. Keep the unquantized frequency in the note table too.
- **Categorical → pitch:** each level gets a distinct scale degree, in factor-level order.
- **NA → rest** (silence), with a one-time `cli` message saying how many.
- **Time:** default is one note per row at `60 / bpm` seconds each. With `length`, the step is `length / n_rows`. With `time =`, there are two modes:
  - `time_scale` given (real-time mode, as in the NYT piece): onset = `(time - min(time)) * time_scale`. Also accept difftime, POSIXct, and hms, converting to seconds.
  - Otherwise: onsets = `rescale(time, to = c(0, length))`.
  - Warn when notes collide or overlap heavily.
- **Sequence:** each `sequence` group gets its own timeline, then groups are laid end to end with `gap` seconds between them, in factor/appearance order.
- **No pitch mapping:** every note gets the tonic of `key` in the middle of `range` (e.g., C5).
- **Volume:** rescale to velocity 40–120 (so nothing goes fully silent).
- **Long-output guard:** a warning at more than 3 minutes, and a hard stop at more than ~20 minutes unless `force = TRUE`.

### 4.3 The note tibble (the teaching payoff)

Each `sonification` object carries a tibble, one row per note:

| column | meaning |
|---|---|
| `row` | source row index (joins back to data) |
| `voice` | voice/track label |
| `onset` | start time in seconds |
| `duration` | seconds |
| `midi` | MIDI note number (integer) |
| `note` | note name, e.g. `"E4"` |
| `freq` | Hz |
| `velocity` | 1–127 |
| `instrument` | instrument name |
| `value` | the original data value that produced this note |

Accessors: `notes(x)` returns the tibble. `autoplot(x)` / `plot(x)` draws a **piano-roll** ggplot (time on x, pitch on y, colored by voice). This lets students *see* the sound and compare it with a normal chart of the same data.

### 4.4 The `sonification` object

A list with class `"sonification"`: `$data`, `$notes`, `$settings` (bpm, length, scale, key, range, engine), and a lazily cached `$audio`. Methods:
- `print()`: render if needed, then show the player (§6) and a one-line `cli` summary ("48 notes · 1 voice · 24.0 s · xylophone").
- `notes()`, `plot()`/`autoplot()`, `save_sound()`, `summary()`.
- `knit_print()` for Quarto/R Markdown.

### 4.5 Composition (open decision, phase 3+)

These are options for layering several sonifications. Pick one later and don't build it in the MVP:
- `c(s1, s2)` / `play_together(s1, s2)` for simultaneous playback, and `then(s1, s2)` for sequential playback.
- A ggplot-style `+` with layers (`sonify_data(data) + voice(pitch = x)`). This is powerful but adds a new idiom for beginners.
- Leaning toward: `voice =` inside `sonify_data()` covers 90% of cases, and add `sound_mix()` later.

---

## 5. Sound backends (tiered)

### Tier 0 — Pure-R synthesizer (MVP default, no system dependencies)

- Generate samples in base R: for each note, run an oscillator → envelope (attack/decay/sustain/release) → sum into a buffer → normalize.
- A few built-in "synth instruments" that don't need soundfonts:
  - `"sine"`, `"triangle"`, `"square"` (basic)
  - `"bell"` (simple 2-operator FM; sounds like glockenspiel or vibraphone)
  - `"pluck"` (**Karplus–Strong**; sounds like guitar or harp. Can be vectorized with `stats::filter(method = "recursive")`)
  - `"marimba"`/`"xylophone"` approximations (sine + short decay + a partial at an inharmonic ratio)
- Write WAV directly with `writeBin()` (the 44-byte RIFF header is easy) or through `tuneR::writeWave` (decision: see §9). Mono, 22,050 Hz, 16-bit keeps files small.
- The synth is **the fallback whenever fluidsynth isn't available**. `engine = "auto"` picks fluidsynth when installed and the soundfont is present, and the synth otherwise.

### Tier 1 — Real instruments via MIDI + `fluidsynth`

- Write a **pure-R Standard MIDI File writer** (`write_midi()`). The format is small and well documented: header chunk, one track chunk per voice, variable-length delta times, program-change events, and note on/off. Put percussion voices on channel 10. This also gives a nice extra feature: students can open the `.mid` in GarageBand or MuseScore.
- Render MIDI → WAV with rOpenSci's **`fluidsynth`** package (Jeroen Ooms).
  - **Verified (CRAN page, 2026-09-22):** v1.0.4 published 2026-09-15. Imports `av` and `rappdirs`. CRAN has **binaries for macOS (arm64 + x86_64) and Windows**. Linux needs `libfluidsynth-dev` / `fluidsynth-devel` plus a GM soundfont package (`fluid-soundfont-gm`). Exports include `midi_play()`, `midi_convert()`, `midi_read()`, `soundfont_path()`, and `soundfont_download()`.
  - **Verified by installing (Phase 0, 2026-09-22):** the macOS arm64 binary installs cleanly with no Homebrew needed, bundling libfluidsynth 2.6.0.
    - `midi_convert(midi, soundfont = soundfont_path(), output = "output.mp3", settings = list(), verbose = interactive())`
    - `midi_play(midi, soundfont, audio.driver = NULL, settings, verbose)`
    - `midi_read(midi, verbose = FALSE)`
    - `soundfont_path(download = FALSE)` **errors** if no soundfont is found, so wrap it in `tryCatch` for `engine = "auto"`. `soundfont_download()` takes no arguments.
    - The soundfont is **GeneralUser GS v1.471**, a **28.3 MB zip** from `github.com/ropensci/fluidsynth/releases`. It's cached at `~/Library/Application Support/soundfonts/generaluser-gs/v1.471.sf2` on macOS (via rappdirs), with a 300 s download timeout.
  - **Confirmed in Phase 0:** writes `.wav`/`.mp3` by extension, renders in ~1 s, and output is quiet by default (see §10, Phase 0 notes).
  - **Still TO VERIFY:** whether it works on Posit Cloud (Linux, so it may need system libraries there); and how much a 28 MB-per-student download hurts on campus Wi-Fi.
- **Instrument name lookup:** a built-in table of the 128 General MIDI programs with friendly aliases (`"xylophone"`, `"marimba"`, `"cello"`, `"trumpet"`, `"piano"`, `"steel drums"`, …). Fuzzy matching on names, and `instruments()` lists them. *From memory: GM Xylophone = program 14 (1-based) / 13 (0-based), Marimba = 13/12. Verify against the GM spec when building the table.*
- Also add a small **drum map** for percussion voices (`instrument = "drums"` → channel 10, categorical mapping onto kick/snare/hat…). This fits things like "each three-pointer is a cymbal."

### Tier 2 (later / maybe)

- Stereo panning by voice or by a mapped variable (`pan = shot_x`).
- `sonify_video()`: an animated plot (gganimate/ggplot frames) with the audio attached via `av`. This is the "chart with a soundtrack" deliverable for class projects.
- Export MusicXML for notation (probably via the `gm` package). Low priority.

---

## 6. Playback — the historical pain point

R has never had reliable console audio. `tuneR::play()` shells out to an external player, and `audio::play()` has CRAN and platform trouble. Plan:

1. **Primary:** the print method builds an HTML `<audio controls>` element with the WAV **base64-embedded** as a data URI and shows it with `htmltools` in the viewer pane. This works in RStudio, Positron, VS Code, and Posit Cloud, because the browser is doing the playing.
2. **Quarto / R Markdown:** a `knit_print.sonification()` method emits the same `<audio>` tag, so rendered HTML documents have inline, playable sonifications. That's great for assignments.
3. **Size budget:** 22.05 kHz mono 16-bit is ~44 KB/s, so 60 s ≈ 2.6 MB, or ~3.5 MB as base64. That's fine. For long pieces, offer mp3 via `av` if available (verify `av` can encode mp3 from WAV).
4. **Fallback:** `play(x)` tries in order: macOS `afplay`, Windows default player (`shell.exec`), Linux `aplay`/`paplay`, and `tuneR::play`. This is for plain-terminal R.
5. **Autoplay:** don't autoplay by default because browsers block it anyway. Maybe offer `options(soundeR.autoplay = TRUE)`.

`save_sound(x, "season.wav")` picks the format from the extension: `.wav`, `.mp3` (via av), or `.mid` (MIDI, no rendering needed).

---

## 7. Package skeleton (proposed)

```
soundeR/
├── DESCRIPTION           # Imports: rlang, cli, tibble, vctrs?, scales, htmltools, base64enc(or jsonlite)
│                         # Suggests: fluidsynth, av, tuneR, ggplot2, knitr, rmarkdown, testthat, dplyr, tidyr
├── R/
│   ├── sonify_data.R     # sonify_data(): capture mappings, dispatch stat, build notes
│   ├── sonify_histogram.R
│   ├── stats.R           # stat_identity / stat_histogram / stat_density → event tables
│   ├── scales.R          # value → midi, musical scales/keys, note-name parsing ("C4" ↔ 60)
│   ├── timing.R          # bpm / length / time mapping, long-output guard
│   ├── notes.R           # note tibble constructor + validator
│   ├── synth.R           # oscillators, envelopes, FM bell, Karplus–Strong, mixing
│   ├── midi_write.R      # pure-R SMF writer
│   ├── instruments.R     # GM table + aliases + instruments()
│   ├── render.R          # engine selection, render_audio()
│   ├── wav.R             # write_wav() / read for tests
│   ├── player.R          # HTML <audio> builder, print, knit_print, play()
│   ├── save.R            # save_sound()
│   ├── plot.R            # autoplot/piano roll
│   └── data.R            # docs for bundled datasets
├── data/                 # small example datasets (see §8)
├── tests/testthat/
├── vignettes/            # "Your first sonification", "Distributions", "Instruments"
└── PLAN.md / CLAUDE.md
```

Use `usethis::create_package()`, `usethis::use_testthat()`, `usethis::use_mit_license()`, and roxygen2. Keep **Imports lean**: dplyr/tidyr go in Suggests only (examples use them, the package doesn't).

**Testing strategy:**
- Snapshot-test the **note tibble** (deterministic, no audio needed). This is where most of the logic lives.
- WAV writer: check header bytes, length, and sample range.
- MIDI writer: round-trip through `tuneR::readMidi()` (Suggests) and compare notes.
- Synth: check output length = expected seconds × sample rate, and that it's non-silent.
- Skip fluidsynth tests when it isn't installed.

---

## 8. Example datasets to bundle (small, documented)

| Dataset | Source idea | Use |
|---|---|---|
| `luge_finals` ✅ | Milano Cortina 2026 luge, all five events, sleds that completed every run: event, rank, bib, athlete, country, run_1–4, total_time, behind. Scraped from Wikipedia (`data-raw/luge_finals.R`). One Wikipedia total has transposed digits (Grancagnolo 3:33.942 → 3:33.492, matching his runs and the page's own "Behind"); the script uses the sum of runs and prints mismatches. | §2.4, the NYT recreation, real-time mode |
| `husker_games` ✅ | Nebraska men's basketball 2025-26 (28-7, 20-0 start, first NCAA wins, Sweet 16): game_number, date (Central), opponent, location, game_type, conference_game, husker_score, opponent_score, point_margin, result. From `hoopR::load_mbb_schedule(2026)` (`data-raw/husker_games.R`); record checked against huskers.com. | §2.1, sequences |
| `ws_pitches` | World Series Statcast pitches (`baseballr::statcast_search`): game_date, inning, pitch_type, release_speed, description. Consider trimming to one game for size. | §2.2, many rows, multi-voice |
| `ne_housing_age` | ACS B25034 for Nebraska counties (`tidycensus`), already binned by decade built | §2.3, pre-binned histogram |

Check licensing/redistribution for each. Store build scripts in `data-raw/`.

---

## 9. Open decisions (resolve and record here)

1. ~~**Function name `sonify()`.**~~ **DECIDED (2026-09-22): the main verb is `sonify_data()`.** This avoids masking CRAN's `sonify::sonify()`, is easier to search for, and gives a `sonify_` prefix family (`sonify_data()`, `sonify_histogram()`, `sonify_density()`) that shows up together with Tab completion, like stringr's `str_`.
2. **Package name.** `soundeR`, `soundr`, and `sonifyr` were **all free on CRAN as of 2026-09-22** (checked). The GitHub repo is `mattwaite/soundeR` (private). Tidyverse style prefers lowercase (`soundr`?). Also check GitHub/R-universe collisions.
3. **Pitch as first positional mapping?** Should `sonify_data(home_score)` work without `pitch =`? This is the user's original example. **Yes: make `pitch` the 2nd positional argument, but optional** (the NYT Olympic case maps only `time`).
3a. **`group_by()` meaning. DECIDED (Phase 1): no effect on sound.** Students' pipelines are almost always still grouped after `group_by() |> mutate()`, so any automatic meaning would fire accidentally. `voice =` / `sequence =` must be explicit, and grouped input gets a `cli` hint. Easy to revisit later (e.g., make grouping imply `sequence`).
4. **WAV writing:** hand-rolled `writeBin` (zero deps) vs `tuneR` (a known quantity). **Decided: hand-rolled.** It worked in the Phase 0 spike: 20 lines, and `tuneR::readWave` reads it back. tuneR goes in Suggests for tests.
5. **Default engine:** synth vs fluidsynth. Leaning `"auto"` = fluidsynth if installed and the soundfont is present, else synth. Is it confusing if the same code sounds different on two machines? Maybe print which engine was used.
6. **Tempo vocabulary:** `bpm` vs `speed` vs `notes_per_second`. `bpm` is familiar from music. Should "beat" = one row always?
7. **Composition model** (§4.5).
8. **Default scale:** major pentatonic in C. Would minor pentatonic be moodier and better for "losses"? Maybe allow `mood = "happy"/"sad"` aliases. (Fun and teachable.)

---

## 10. Roadmap

### Phase 0 — Spike (1 session)
- [x] Create the package skeleton (`usethis`: DESCRIPTION, MIT license, testthat 3e), git init. Nothing is committed yet. `spike/` holds throwaway prototypes and is Rbuildignored. `.claude/launch.json` serves `spike/out` on port 8765 for browser checks.
- [x] Install `fluidsynth` 1.0.4, `tuneR` 1.4.7, `av` 0.9.6 (CRAN binaries). Verified the fluidsynth API and soundfont details (§5).
- [x] Prove the playback path (`spike/01_synth_playback.R`): base-R bell (FM) and pluck (Karplus–Strong via `stats::filter`) → hand-rolled WAV → base64 `<audio>`. It loads in a browser (readyState 4, correct duration) and runs in about 1 s. 22.05 kHz mono gives ~44 KB/s.
- [x] Prove the Quarto path (`spike/02_quarto_embed.qmd`): an `output: asis` chunk emitting a base64 `<audio>` tag plays in rendered HTML. **Gotcha:** `quarto render --output-dir` wipes that directory, so never point it at a folder holding inputs.
- [x] Pure-R MIDI writer (`spike/03_midi_fluidsynth.R`): header, tempo, program change, note on/off with VLQ deltas. The round-trip through `tuneR::readMidi` matches.
- [x] Render that MIDI with fluidsynth (2026-09-22). The soundfont downloaded in ~1.5 s on a fast connection (31.3 MB unzipped .sf2). `midi_convert()` writes **both `.wav` and `.mp3` by file extension**. Output is **44.1 kHz 16-bit stereo**. Rendering takes about 1 s. All 8 note onsets in the mock Olympic race land within 10 ms of target. Xylophone (GM program 13, 0-based) also works. Listening page: `spike/out/olympic.html`.
  - **Gotcha: renders are very quiet.** The fluidsynth default `synth.gain` is 0.2, giving a peak of ~0.06 (≈ −24 dBFS). Fix in the package: render with `settings = list(synth.gain = 1.0)` (peak ~0.28), then **peak-normalize in R** to ~0.9. So always render to WAV first, normalize, then encode mp3 via `av` if needed.
  - **Gotcha: tail padding.** The output runs ~3 s past the last note-off (reverb/release). Trim trailing samples below ~−60 dB, keeping a short natural tail (~0.5–1 s).
- [ ] Still untested: the RStudio/Positron **viewer pane** specifically (the browser test covers the same mechanism, but confirm by hand).

### Phase 1 — MVP: "a season sounds like something" (§2.1)
Code lives in `R/`: `pitch.R`, `timing.R`, `instruments.R`, `sonify_data.R`, `wav.R`, `synth.R`, `midi.R`, `render.R`, `player.R`.
- [x] `note_to_midi()` / `midi_to_note()` / `midi_to_freq()`, `sound_scales()` (pentatonic, minor_pentatonic, major, minor, blues, chromatic, none), and quantization (ties snap down). The default single pitch is the tonic nearest mid-range, with ties going up (C5 for C3–C6).
- [x] `sonify_data(data, pitch, time, volume, sequence, instrument, bpm, length, time_scale, gap, scale, key, range, reverse, engine, force)` → `sonification` object. `notes()` returns the note tibble (§4.3, plus a `sequence` column; `voice` waits for Phase 3). `volume` is already mapped (velocity 40–120).
- [x] Synth engine (sine, triangle, square, bell, pluck) at 22.05 kHz mono. WAV reader and writer (mono/stereo 16-bit).
- [x] `print` (non-interactive: summary + hint; interactive: `htmltools::html_print()` player in the viewer), `knit_print` (registered via `@exportS3Method`), `notes()`, `save_sound()` for `.wav`/`.mp3`/`.mid`. The player embeds **mp3 via av** when available (much smaller), otherwise WAV. The summary line reports the notes' span, not the audio length.
- [x] Long-output guard (warn > 3 min, error > 20 min unless `force = TRUE`).
- [x] Optional `pitch`; `time =` with `time_scale` (real-time mode) and stretch mode; `sequence =` + `gap` (factor-level or first-appearance order).
- [x] fluidsynth engine (pulled forward from Phase 2): gain 0.6 → normalize to 0.9 → trim tail (keep 0.75 s). `engine = "auto"` falls back to a synth stand-in (mallets → bell; piano/guitar/bass/ethnic → pluck; else triangle) with a rate-limited message. `sound_setup()` installs/downloads with friendly messages. `instruments()` lists 5 synth + 128 GM instruments (GM names verified against the soundfont's preset headers), plus aliases like `"piano"`, `"guitar"`, `"strings"`.
- [x] Conflicting timing arguments are errors: `time_scale` without `time`, `time_scale` + `length`, `time_scale` + explicit `bpm`, `bpm` + `length`. `gap` without `sequence` warns.
- [x] Friendly errors: mistyped columns ("Did you mean margin?"), unknown instruments (edit-distance suggestions), bad scale/key/range, wrong-length mappings. NA → silence with one message. Grouped data → a rate-limited hint.
- [x] Tests: 137 passing (pitch, timing, sonify_data, audio/WAV/MIDI/fluidsynth, player). `R CMD check`: 0 errors / 0 warnings / 0 notes. The fluidsynth test skips when no soundfont is present. Verified end to end in the browser and in a Quarto doc (`spike/04_phase1.qmd`).
- [x] **Datasets:** `luge_finals` (Milano Cortina 2026, Matt's pick) and `husker_games` (men's 2025-26, Matt's pick), each with a `data-raw/` script, a cited source, and sanity checks. Documented in `R/data.R`, tested in `test-data.R`.
- [x] "Your first sonification" vignette **drafted** (`vignettes/soundeR.Rmd`, 2026-09-23) for Matt to edit. It covers luge (real time, slow motion, `sequence`, computing `behind` yourself), `notes()`, the Husker season (pitch, `scale = "none"`, narrow `range`, `volume = game_type`, `time = date`), `instruments()`, `save_sound()`, and exercises. It renders in ~15 s to ~2.7 MB with 9 players. Rendering from the command line needs `RSTUDIO_PANDOC=/Applications/quarto/bin/tools/aarch64` (no standalone pandoc on this Mac).
- [x] Matt confirmed in RStudio (2026-09-23): the viewer player works.
- [x] Embedded players now use 96 kbps mp3 (av's default was 320k): 112 s went from 4.6 MB to 1.4 MB. `save_sound(".mp3")` uses 192 kbps.

### Phase 2 — Real instruments
- [x] Mostly done early in Phase 1 (`write_midi()`, GM table, `instruments()`, fluidsynth engine, `save_sound()` mid/mp3, `sound_setup()`).
- [ ] Remaining: test on Posit Cloud/Linux; per-instrument sensible default ranges (e.g., cello shouldn't play C6); maybe cache the rendered mp3 too.

### Phase 3 — Many rows, many voices (§2.2)
- [ ] `voice =` and `group_by()` support; per-voice instruments; `volume =`, `duration =`.
- [ ] `time =` mapping (dates/datetimes/numerics).
- [ ] Bundle `ws_pitches`. Piano-roll `autoplot()`.

### Phase 4 — Distributions (§2.3)
- [ ] `sonify_histogram()` with `bins`, `binwidth`, and `weight`; count → volume/density.
- [ ] `sonify_density()`. Bundle `ne_housing_age`, and write the "Hearing distributions" vignette.

### Phase 5 — Polish & teaching
- [ ] Drums/percussion mapping, panning.
- [ ] `sonify_video()` (plot + soundtrack via `av`). **Prototype exists:** `spike/05_readme_video.R` uses `av::av_capture_graphics()` to make a NYT-style dot plot of `luge_finals`, with a moving playhead and dots that fill as each note sounds, plus the audio (1280×640, 12 fps, 35 s, 1.3 MB, ~35 s to render). This is also **how to get sound into the GitHub README**: GitHub strips `<audio>` but plays MP4s uploaded through its web editor (`user-attachments` URLs, 10 MB limit). A committed mp3/mp4 referenced by a repo path does not play inline.
- [ ] pkgdown site with embedded audio examples. Teaching materials and a class exercise.
- [ ] Accessibility review with actual screen-reader users, if possible. CRAN submission.

---

## 11. Session log

Add an entry per work session: date, what was done, decisions made, and what's next.

- **2026-09-22** — Wrote this plan. Environment: macOS, R 4.5.2. No audio packages installed yet (`tuneR`, `av`, `fluidsynth`, `audio` all absent). ggplot2, dplyr, rlang, vctrs, cli, tibble, and scales are present. No system `fluidsynth`/`ffmpeg`/`sox` on PATH (the R `fluidsynth` binary package should bundle what it needs; verify). **Next:** Phase 0.
- **2026-09-22 (later)** — Matt identified the NYT 2010 "Fractions of a Second: An Olympic Musical" as the main inspiration. Added §2.4 as the flagship example. Consequences: `pitch` is now optional; added real-time `time_scale`; added `sequence =` (groups play in turn) as distinct from `voice =` (groups play together); raised the priority of the fluidsynth piano. New open decision 3a (what `group_by()` means).
- **2026-09-22 (Phase 0)** — Decided the main verb is `sonify_data()` (decision 1). Built the package skeleton. Installed fluidsynth/tuneR/av. Proved the zero-dependency synth → WAV → base64 `<audio>` path in the browser and in Quarto. Wrote and round-trip-tested a pure-R MIDI writer. Verified fluidsynth signatures and soundfont details. **Next:** download the soundfont with permission, render the piano Olympic example, and check the RStudio viewer by hand. Then start Phase 1 (move the spike code into `R/` properly, with tests).
- **2026-09-22 (Phase 0, cont.)** — Matt approved the soundfont download. The fluidsynth piano and xylophone render correctly with accurate timing. Found that renders are quiet by default (gain 0.2) and have ~3 s of trailing silence; fixes are recorded in Phase 0 notes. Since fluidsynth installed painlessly on macOS, **recommend pulling the piano engine into Phase 1**, because the Olympic flagship needs it. The synth stays as the no-download fallback. **Next:** Matt checks the RStudio viewer by hand, then Phase 1.
- **2026-09-22 (Phase 0, cont.)** — Matt's first run in RStudio failed ("cannot open file 'spike/out/season_bell.wav'") because the working directory wasn't the project root. Fixed spike 1 to locate the root from the script's own path, and it now opens the players in the viewer via `htmltools::html_print()` when interactive. Added `soundeR.Rproj`. **Lesson for the package:** never depend on the working directory. Render to `tempfile()`, and only write where the user explicitly says (`save_sound(path)`). Beginners will run code from anywhere.
- **2026-09-22 (Phase 1)** — Built the MVP. Decisions: `group_by()` has no effect on sound (3a); fluidsynth pulled into Phase 1; hand-rolled WAV. Implemented pitch/scales, four timing modes plus sequence, note tibble, synth + fluidsynth engines with fallback, the mp3-embedded player, knit_print, save_sound, sound_setup, and instruments. 137 tests, clean `R CMD check`. Gotchas: the `length` argument name shadows `base::length`, which is fine for calls since R skips non-function bindings but is worth remembering; keep R code ASCII-only (use `\u00b7` escapes). **Late fix:** same-pitch notes overlapping on one MIDI channel cut each other off (a note-off silences the key). This affected the Olympic case most. `write_midi()` now assigns overlapping same-key notes to separate channels (skipping 9 = drums), with a program change per channel. Also, dense renders clipped inside fluidsynth at gain 0.6, so the renderer now re-renders at gain/3 until the peak is under 0.99. 146 tests. Nothing is committed yet. **Next:** Matt picks the real datasets; build `data-raw/` scripts; write the vignette; Matt tries it in RStudio.
- **2026-09-23** — Matt confirmed the RStudio viewer works. Committed and pushed to the private repo **github.com/mattwaite/soundeR** (`spike/` and `.claude/` are gitignored). Built both real datasets: `luge_finals` (Milano Cortina 2026 luge finals, 5 events, 77 sleds; corrected one Wikipedia typo, see §8) and `husker_games` (Nebraska men's 2025-26, 35 games, 28-7). Gotcha: Wikipedia's `<br>` tags carry attributes (`<br id=...>`), so match `<br[^>]*>`. ESPN dates are UTC, so convert to America/Chicago before taking the date. **Next:** the "Your first sonification" vignette built on these two datasets; smaller mp3s for embeds; then Phase 3 (voices).
- **2026-09-23 (later)** — Drafted the vignette for Matt to edit. Lowered the embed mp3 bitrate to 96k. Wrote `README.md` with a `VIDEO_GOES_HERE` placeholder, and made the README demo video (`spike/out/luge_readme.mp4`) via `spike/05_readme_video.R`. Matt needs to drag it into GitHub's web editor, since only uploaded videos play in READMEs. `R CMD check` is clean apart from a network-time NOTE. **Next:** Matt edits the vignette; decide whether `sonify_video()` becomes a real function (the prototype suggests it's cheap); Phase 3 voices.
