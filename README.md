# Kanimaji #

## Generation of animations ##

This is a small utility for transforming KanjiVG images into animated SVG, GIF, or WebP files, or SVGs that can easily animated via Javascript (with no library dependency!).

 * SVG samples (animated via CSS, no SMIL/<animate> element):

![084b8 SVG](http://maurimo.github.io/kanimaji/samples/084b8_anim.svg)
![08972 SVG](http://maurimo.github.io/kanimaji/samples/08972_anim.svg)

 * GIF samples:

![084b8 GIF](http://maurimo.github.io/kanimaji/samples/084b8_anim.gif)
![08972 GIF](http://maurimo.github.io/kanimaji/samples/08972_anim.gif)

(these GIFs are 150x150 and have size 24k and 30k. With transparent background the generated image are quite bigger ~220k unluckily).

 * Javascript controlled SVG:

See the [Demo on the Project Page](http://maurimo.github.io/kanimaji/index.html).

## Dependencies ##

Kanimaji depends on
 * [Python 3]() with lxml support.
 * [svg.path](https://pypi.python.org/pypi/svg.path) Python library, for approximating path lengths.
 * [python-dotenv](https://pypi.org/project/python-dotenv/), for loading settings from `.env`.

If you want to be able to generate animated GIF or WebP, you will also need:
 * [CairoSVG](https://cairosvg.org/) for rendering SVG frames to PNG.
 * [ImageMagick](www.imagemagick.org)'s magick program to merge PNG's into a GIF.
 * [Gifsicle](https://www.lcdf.org/gifsicle/) to optimize GIF size.
 * [libwebp](https://developers.google.com/speed/webp)'s `img2webp` to assemble the animated WebP.

A [Nix](https://nixos.org/) flake is also provided; `nix develop` gives a shell with all
dependencies, and `nix build` can render kanji in batch (see `flake.nix`). The batch renderer runs
in parallel across CPU cores — pass `--cores 0` to use all of them (the full ~11k KanjiVG set is a
multi-day job single-core).

## Usage ##

Just run
```
./kanimaji.py file1.svg file2.svg ...
```
where the files are KanjiVG SVG files (could work with other SVG files, but it hasn't been tested).

## Settings ##

Just edit the `.env` file, all settings are explained there. In this file you can also enable/disable SVG, GIF, JS-SVG, and WebP generation.

## License ##

This software is formally released under MIT/BSD (at your option).
You are free to do what you want with this program, please credit my work if you use it.
If you find it useful and feel like, you may give a donation on my github page!
