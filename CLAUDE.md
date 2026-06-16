# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Kanimaji turns [KanjiVG](https://github.com/KanjiVG/kanjivg) stroke-order SVGs into animated
stroke-by-stroke drawings, emitted as one or more of: a CSS-animated SVG (`_anim.svg`), a
JavaScript-controllable SVG (`_js_anim.svg`), an animated GIF (`_anim.gif`), and an animated WebP
(`_anim.webp`).

## Commands

Direct invocation (requires the Python deps + `cairosvg`/`imagemagick`/`gifsicle`/`libwebp`'s
`img2webp` on PATH; the Nix dev shell provides them):

```
./kanimaji.py file1.svg file2.svg ...   # writes <name>_anim.{svg,js_anim.svg,gif,webp} next to each input
```

Inputs are KanjiVG SVGs. Each filename's hex prefix is the Unicode codepoint of the kanji (e.g.
`065e5.svg` = 日); KanjiVG also has variant files like `065e5-Kaisho.svg`.

Nix (primary build/run path):

```
nix build .#kanimaji       # build the CLI as a Python application
nix build .#all            # render the ENTIRE KanjiVG set into ./result (slow)
nix build .#custom         # render the small hardcoded kanjiList in flake.nix
nix build .#allDiscord     # .#all + .#custom but with the Discord theme override
nix build .#customDiscord
nix develop                # dev shell: deps + black + types-lxml
black kanimaji.py          # formatting (the only linter/formatter configured)

nix build .#all --cores 0  # use all CPU cores (see batch renderer below)
```

The `generate` derivation in `flake.nix` is the batch renderer: it symlinks each KanjiVG SVG into
`$out`, runs `kanimaji`, and collects the outputs. It renders the characters **in parallel** via
`xargs -P$NIX_BUILD_CORES` (falling back to `nproc`), so pass `--cores N` / `--cores 0` to control
core use — this matters because the full ~11k-kanji set is otherwise a multi-day single-core job.
Each character is an independent process (sidesteps the GIL and the per-character serial
`img2webp`/`gifsicle` step); frame temp files are uniquely named per input and deleted once that
character's webp/gif is compiled, so the working set stays bounded to the active workers.
`kanjiList` accepts kanji characters (optionally with a `-Suffix`), which it converts to `%05x` hex
filenames.

## Configuration

All runtime behavior is driven by environment variables, loaded from `.env` via `load_dotenv()` at
startup. There are no CLI flags besides the list of input files. `kanimaji.py` reads each setting at
import time with `os.environ[...]`, so **every** variable in `.env` must be present or the program
crashes immediately. When adding a setting, add it to both `.env` and the read block near the top of
`kanimaji.py`.

Notable settings semantics:
- `GENERATE_SVG`, `GENERATE_JS_SVG`, `GENERATE_GIF`, `GENERATE_WEBP` select which outputs are produced.
- `bool_flag()` treats unset or `"0"` as false; any other value is true.
- WebP: `WEBP_SIZE`, `WEBP_QUALITY` (`100` = lossless via `img2webp -lossless`, lower = lossy `-q`),
  and `WEBP_BACKGROUND_COLOR`, which drives transparency via `color_has_alpha()`: a solid color
  renders opaque (no meaningful alpha stored), while `"transparent"` or an alpha color
  (`#rrggbbaa` / `rgba(...)`) keeps 8-bit alpha.
- `FINAL_FRAME_HOLD` is how long the completed glyph is held before the GIF/WebP loops (it replaces
  the old `WAIT_AFTER`-derived last-frame delay for raster output; `WAIT_AFTER` still drives the
  CSS/JS loop pause and the speed rescale). `GIF_POSTER_FINAL_FRAME` / `WEBP_POSTER_FINAL_FRAME` lead
  with the completed glyph as a poster frame for a graceful static/first-paint fallback.
- `STROKE_LENGTH_TO_DURATION` and `TIME_RESCALE` are **Python expressions** stored as strings and
  `eval`'d (with `length` / `interval` in scope) to map stroke length → draw time and to globally
  rescale total animation time.
- `TIMING_FUNCTION` must be one of `linear`, `ease`, `ease-in`, `ease-in-out`, `ease-out`; these are
  the CSS easing names, reimplemented in `bezier_cubic.py` for the GIF path (CSS/JS outputs use the
  name directly).
- The Nix `discord` attrset in `flake.nix` overrides these env vars at build time to theme output
  (currently WebP-only, transparent background, blurple strokes, poster frame on); it's the model
  for any other preset.

## Architecture

- `kanimaji.py` — everything. `create_animation(filename)` is called once per input file. It parses
  the SVG with lxml, strips any groups/styles this tool previously injected (suffixed `-Kanimaji`),
  then walks the KanjiVG stroke `<path>` elements twice: first to sum total path length/time, then to
  emit the chosen outputs.

  The core trick for all outputs is `stroke-dasharray`/`stroke-dashoffset` animation: each
  stroke path's length (computed by `svg.path` via `compute_path_len`) becomes the dash length, and
  animating the offset from full-length to zero "draws" the stroke. The tool builds parallel
  `<g>` groups of `<use>` references to the original paths — `bg` (faint unfilled guide), `anim`
  (the drawn stroke), and optionally `brush`/`brush-brd` (the moving brush tip). Stroke-number
  groups (`kvg:StrokeNumbers_*`) and an optional grid are handled separately.

  - SVG output: writes pure-CSS `@keyframes` (one `strike-*` + `showhide-*` per stroke) into an
    injected `<style>`; loops infinitely.
  - JS-SVG output: emits CSS keyed off `.animate`/`.current`/`.backward` classes plus `data-stroke`/
    `data-duration` attributes, so external JS can drive playback. No JS library ships here.
  - GIF and WebP both build the same per-frame static CSS (`static_css`, one `<style>` per frame
    sampled every `GIF_FRAME_DURATION`; gated on `GENERATE_GIF or GENERATE_WEBP`), write each frame
    to a temp SVG, and rasterize with `cairosvg`. GIF then assembles with ImageMagick (`magick`) and
    optimizes with `gifsicle` (a two-step palette remap forces the bg color into the palette to fix
    banding); WebP assembles with `img2webp` (libwebp's inter-frame `WebPAnimEncoder` — do **not**
    hand-roll frame muxing, which loses that compression). Temp frames are deleted only if
    `DELETE_TEMPORARY_FILES`.

- `bezier_cubic.py` — solves the cubic Bézier of a CSS easing curve (`value(pt1,ct1,ct2,pt2,x)`),
  used to sample the timing function at each GIF frame so GIF motion matches the CSS easing.

## Gotchas

- `STROKE_LENGTH_TO_DURATION`/`TIME_RESCALE` are pre-compiled with the builtin `compile` then
  `eval`'d per stroke.
- The per-frame `anim` rule uses `stroke-dasharray: pathlen, pathlen+1` — the gap is deliberately
  large so the dash pattern can't wrap and paint a stray highlight sliver at the stroke's far end on
  its first frame (cairosvg dashes along the path's *true* length, which differs from the rounded
  `compute_path_len`). Don't shrink it back to a tiny gap.
- KanjiVG element ids contain colons (`kvg:...`); the code escapes `:` to `\3a ` for CSS selectors.
  Filenames are also ASCII-normalized (`filename_noext_ascii`) before being used in frame paths.
- External commands run through `run()` / `shescape()`; a nonzero exit aborts the whole run.
- `.env`, `flake.nix`, and `kanimaji.py` are the files most likely to need coordinated edits.
