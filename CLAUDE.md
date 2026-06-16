# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Kanimaji turns [KanjiVG](https://github.com/KanjiVG/kanjivg) stroke-order SVGs into animated
stroke-by-stroke drawings, emitted as one or more of: a CSS-animated SVG (`_anim.svg`), a
JavaScript-controllable SVG (`_js_anim.svg`), and an animated GIF (`_anim.gif`).

## Commands

Direct invocation (requires the Python deps + `cairosvg`/`imagemagick`/`gifsicle` on PATH; the Nix
dev shell provides them):

```
./kanimaji.py file1.svg file2.svg ...   # writes <name>_anim.svg / _js_anim.svg / _anim.gif next to each input
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
```

The `generate` derivation in `flake.nix` is the batch renderer: it symlinks KanjiVG SVGs in one at a
time, runs `kanimaji`, and collects outputs into `$out`. `kanjiList` accepts kanji characters
(optionally with a `-Suffix`), which it converts to `%05x` hex filenames.

## Configuration

All runtime behavior is driven by environment variables, loaded from `.env` via `load_dotenv()` at
startup. There are no CLI flags besides the list of input files. `kanimaji.py` reads each setting at
import time with `os.environ[...]`, so **every** variable in `.env` must be present or the program
crashes immediately. When adding a setting, add it to both `.env` and the read block near the top of
`kanimaji.py`.

Notable settings semantics:
- `GENERATE_SVG`, `GENERATE_JS_SVG`, `GENERATE_GIF` select which outputs are produced.
- `bool_flag()` treats unset or `"0"` as false; any other value is true.
- `STROKE_LENGTH_TO_DURATION` and `TIME_RESCALE` are **Python expressions** stored as strings and
  `eval`'d (with `length` / `interval` in scope) to map stroke length → draw time and to globally
  rescale total animation time.
- `TIMING_FUNCTION` must be one of `linear`, `ease`, `ease-in`, `ease-in-out`, `ease-out`; these are
  the CSS easing names, reimplemented in `bezier_cubic.py` for the GIF path (CSS/JS outputs use the
  name directly).
- The Nix `discord` attrset in `flake.nix` overrides these env vars at build time to theme output;
  it's the model for any other preset.

## Architecture

- `kanimaji.py` — everything. `create_animation(filename)` is called once per input file. It parses
  the SVG with lxml, strips any groups/styles this tool previously injected (suffixed `-Kanimaji`),
  then walks the KanjiVG stroke `<path>` elements twice: first to sum total path length/time, then to
  emit the chosen outputs.

  The core trick for all three outputs is `stroke-dasharray`/`stroke-dashoffset` animation: each
  stroke path's length (computed by `svg.path` via `compute_path_len`) becomes the dash length, and
  animating the offset from full-length to zero "draws" the stroke. The tool builds parallel
  `<g>` groups of `<use>` references to the original paths — `bg` (faint unfilled guide), `anim`
  (the drawn stroke), and optionally `brush`/`brush-brd` (the moving brush tip). Stroke-number
  groups (`kvg:StrokeNumbers_*`) and an optional grid are handled separately.

  - SVG output: writes pure-CSS `@keyframes` (one `strike-*` + `showhide-*` per stroke) into an
    injected `<style>`; loops infinitely.
  - JS-SVG output: emits CSS keyed off `.animate`/`.current`/`.backward` classes plus `data-stroke`/
    `data-duration` attributes, so external JS can drive playback. No JS library ships here.
  - GIF output: renders one static `<style>` per frame (sampled every `GIF_FRAME_DURATION`), writes
    each frame to a temp SVG, rasterizes with `cairosvg`, assembles with ImageMagick (`magick`), then
    optimizes with `gifsicle`. The two-step palette remap forces the background color into the
    palette to fix banding. Temp files are deleted only if `DELETE_TEMPORARY_FILES`.

- `bezier_cubic.py` — solves the cubic Bézier of a CSS easing curve (`value(pt1,ct1,ct2,pt2,x)`),
  used to sample the timing function at each GIF frame so GIF motion matches the CSS easing.

## Gotchas

- `compute` (line ~62) uses the builtin `compile`; `STROKE_LENGTH_TO_DURATION`/`TIME_RESCALE` are
  pre-compiled then `eval`'d per stroke.
- KanjiVG element ids contain colons (`kvg:...`); the code escapes `:` to `\3a ` for CSS selectors.
  Filenames are also ASCII-normalized (`filename_noext_ascii`) before being used in frame paths.
- External commands run through `run()` / `shescape()`; a nonzero exit aborts the whole run.
- `.env`, `flake.nix`, and `kanimaji.py` are the files most likely to need coordinated edits.
