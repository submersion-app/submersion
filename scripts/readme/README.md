# README asset generators

`import_website_shots.py` regenerates the screenshots embedded in the
top-level `README.md`: everything under `docs/assets/screenshots/readme/`.
The logo and the badges are not its concern. It resolves its paths from its
own location, so it can be run from any directory. It requires Pillow
(`pip3 install --user Pillow`).

```bash
python3 scripts/readme/import_website_shots.py
```

## Provenance

The screenshots are the same captures the website uses, so the README and
submersion.app stay visually in step. They are read from the sibling
[submersion-website](https://github.com/submersion-app/submersion-website)
repository:

```
repos/submersion-app/
├── submersion/            <- this repo
└── submersion-website/
    └── screenshots/       <- source PNGs
```

Clone the website repo next to this one, or point the script somewhere else
with an argument or the `SUBMERSION_WEBSITE` environment variable:

```bash
python3 scripts/readme/import_website_shots.py ~/some/other/screenshots
```

To refresh the README after the website gets new screenshots, pull the website
repo and re-run the script.

## What it does

The README's top half follows the website's home page section by section, so
it takes one image per website screenshot. Each source is flattened to RGB,
resized (1600px wide for the full-width image that leads each section, 1000px
for the extras shown in a row beneath it) and saved as a quality-85
progressive JPEG into `docs/assets/screenshots/readme/`. A source narrower than
its target, such as the portrait phone capture, keeps its own width rather
than being upscaled. Output names carry a numeric prefix matching the order
the image appears in `README.md`, then the website's own file name.

The macOS window captures have rounded corners that are transparent over
black. Compositing those onto a fixed matte would leave four dark nubs
visible against GitHub's light theme, so the script squares each corner off
using the nearest opaque pixel in the same row instead. See `flatten()`.

## Adding or replacing an image

Edit the `MAPPING` table in the script, re-run it, and update the
corresponding `<img>` tag in `README.md`. Keep the two in step: the script
writes exactly the filenames the README references. It never deletes
anything, but at the end of a run it lists any file in the output directory
it did not write, so an image dropped from `MAPPING` is easy to spot and
remove by hand.

Always view the output images before committing, and confirm each one shows
the screen its README caption claims.
