# README asset generators

These scripts regenerate the images embedded in the top-level `README.md`.
Run them from the repo root. They require Pillow (`pip3 install --user Pillow`)
and read source screenshots from `screenshots/Screenshots/` (gitignored).

- `compose_hero.py` — builds the transparent collage hero banner
  (`docs/assets/screenshots/readme/hero.png`).
- `prepare_showcase.py` — builds the five dark-theme feature-row images
  (`docs/assets/screenshots/readme/0X-*.jpg`).

Both match source screenshots by timestamp substring (macOS filenames contain a
U+202F narrow-no-break space, so globbing by timestamp avoids it). If a source
screenshot is re-captured at a different resolution, the iPhone crop box in
`compose_hero.py` may need recalibration. Always view the output images before
committing — confirm each shows the intended screen.
