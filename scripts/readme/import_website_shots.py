#!/usr/bin/env python3
"""Import the website's screenshots into the README asset directory.

Run from anywhere:  python3 scripts/readme/import_website_shots.py [SRC_DIR]

Source images live in the sibling submersion-website repository
(https://github.com/submersion-app/submersion-website) under `screenshots/`.
If that checkout is somewhere else, pass its `screenshots/` directory as
SRC_DIR, or set SUBMERSION_WEBSITE to the same directory.

Requires Pillow (`pip3 install --user Pillow`).
"""

import os
import sys
from collections import Counter

from PIL import Image

# Paths are anchored to this file, not the working directory, so the script
# behaves the same from the repo root, a subdirectory, or a worktree.
# This file is <repo>/scripts/readme/import_website_shots.py: its directory
# is scripts/readme, the parent of that is scripts, and the parent of that
# is the repo root.
_HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(_HERE))
DEFAULT_SRC = os.path.join(os.path.dirname(REPO_ROOT), "submersion-website", "screenshots")
OUT_DIR = os.path.join(REPO_ROOT, "docs", "assets", "screenshots", "readme")

SHOWCASE_WIDTH = 1600
EXTRA_WIDTH = 1000
QUALITY = 85

# (source name, output name, target width). The numeric prefix is the order the
# image appears in README.md. Each website section has one showcase image at
# full width; the sections that show more than one screenshot on the site get
# the rest as a row of extras beneath it. A source narrower than its target
# width (the portrait phone and buoyancy captures) is kept at its own width
# rather than upscaled.
MAPPING = [
    ("dive-detail.png", "01-dive-detail.jpg", SHOWCASE_WIDTH),
    ("duplicate-review.png", "02-duplicate-review.jpg", SHOWCASE_WIDTH),
    ("trip-day.png", "03-trip-day.jpg", SHOWCASE_WIDTH),
    ("site-map.png", "04-site-map.jpg", SHOWCASE_WIDTH),
    ("seascape.png", "05-seascape.jpg", EXTRA_WIDTH),
    ("media-browser.jpg", "06-media-browser.jpg", SHOWCASE_WIDTH),
    ("video-species.jpg", "07-video-species.jpg", EXTRA_WIDTH),
    ("tissue-cylinders.png", "08-tissue-cylinders.jpg", SHOWCASE_WIDTH),
    ("insights-connections.png", "09-insights-connections.jpg", SHOWCASE_WIDTH),
    ("insights-progression.png", "10-insights-progression.jpg", EXTRA_WIDTH),
    ("safety-review.png", "11-safety-review.jpg", SHOWCASE_WIDTH),
    ("buoyancy.png", "12-buoyancy.jpg", EXTRA_WIDTH),
    ("planner.png", "13-planner.jpg", SHOWCASE_WIDTH),
    ("gear-figure.png", "14-gear-figure.jpg", SHOWCASE_WIDTH),
    ("ready.png", "15-ready.jpg", SHOWCASE_WIDTH),
    ("sync-storage.png", "16-sync-storage.jpg", SHOWCASE_WIDTH),
    ("data-quality.png", "17-data-quality.jpg", SHOWCASE_WIDTH),
    ("platform-mac.png", "18-platform-mac.jpg", SHOWCASE_WIDTH),
    ("platform-ipad.png", "19-platform-ipad.jpg", EXTRA_WIDTH),
    ("platform-iphone.png", "20-platform-iphone.jpg", EXTRA_WIDTH),
]

# Alpha at or above this counts as opaque. The macOS window screenshots are
# fully opaque apart from the anti-aliased arc at each rounded corner, so a
# lower threshold would let the black underneath bleed into the fill color.
OPAQUE = 250


def flatten(img):
    """Drop alpha, squaring off rounded corners with the window's own color.

    The transparent corner arcs sit over black. Compositing onto any fixed
    matte leaves four nubs that show against one of GitHub's two themes, so
    each transparent pixel instead takes the color of the nearest opaque pixel
    in its row. Corners end up squared in the titlebar/content color, which
    reads correctly in both light and dark.

    The fill is written at full alpha. Pillow's RGBA to RGB conversion drops
    the alpha band rather than compositing it, so the copied pixel's own alpha
    could not darken the result either way, but writing 255 keeps the intent
    legible without relying on that detail.
    """
    if img.mode not in ("RGBA", "LA") and "transparency" not in img.info:
        return img.convert("RGB")

    img = img.convert("RGBA")
    width, height = img.size
    alpha = img.getchannel("A").load()
    pixels = img.load()

    for y in range(height):
        if alpha[0, y] >= OPAQUE and alpha[width - 1, y] >= OPAQUE:
            continue  # interior row, nothing to extend

        left = next((x for x in range(width) if alpha[x, y] >= OPAQUE), None)
        if left is None:
            # Nothing in this row to extend from. Leaving it would bake the
            # black beneath the alpha into the JPEG as a dark band, so stop
            # and say so rather than invent pixels: this fill handles rounded
            # corners, not transparent margins or drop shadows.
            raise ValueError(
                f"row {y} has no pixel with alpha >= {OPAQUE}; the corner fill "
                "only handles rounded corners, not transparent margins or shadows"
            )
        right = next(x for x in range(width - 1, -1, -1) if alpha[x, y] >= OPAQUE)

        fill = pixels[left, y][:3] + (255,)
        for x in range(left):
            pixels[x, y] = fill
        fill = pixels[right, y][:3] + (255,)
        for x in range(right + 1, width):
            pixels[x, y] = fill

    return img.convert("RGB")


def main():
    src_dir = (
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("SUBMERSION_WEBSITE", DEFAULT_SRC)
    )
    if not os.path.isdir(src_dir):
        sys.exit(
            f"source directory not found: {src_dir}\n"
            "Clone https://github.com/submersion-app/submersion-website next to "
            "this repo, or pass the path to its screenshots/ directory."
        )

    # A duplicated output name in MAPPING would overwrite an earlier image
    # with no error and leave the README showing the wrong screen.
    outputs = [out for _, out, _ in MAPPING]
    dupes = sorted(out for out, n in Counter(outputs).items() if n > 1)
    if dupes:
        sys.exit("MAPPING has duplicate output names: " + ", ".join(dupes))

    # Check every source up front so a rename on the website side reports all
    # the missing files at once, rather than one per run.
    missing = [
        name for name, _, _ in MAPPING if not os.path.isfile(os.path.join(src_dir, name))
    ]
    if missing:
        sys.exit(
            f"{len(missing)} source screenshot(s) missing from {src_dir}:\n  "
            + "\n  ".join(missing)
        )

    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0

    for src_name, out_name, width in MAPPING:
        src = os.path.join(src_dir, src_name)

        # Image.open is lazy and holds the file open until the image is closed,
        # so close it here rather than leaving it to the garbage collector.
        # flatten() returns a new image, which stays valid past the with block.
        with Image.open(src) as src_img:
            try:
                img = flatten(src_img)
            except ValueError as err:
                sys.exit(f"{src}: {err}")
        # Never upscale: a narrow portrait capture keeps its own width.
        width = min(width, img.width)
        height = round(img.height * width / img.width)
        if (width, height) != img.size:
            img = img.resize((width, height), Image.LANCZOS)

        out = os.path.join(OUT_DIR, out_name)
        img.save(out, "JPEG", quality=QUALITY, optimize=True, progressive=True)

        size = os.path.getsize(out)
        total += size
        rel = os.path.relpath(out, REPO_ROOT)
        print(f"wrote {rel} ({width}x{height}, {size / 1024:.0f} KB)")

    print(f"\n{len(MAPPING)} images, {total / 1024 / 1024:.2f} MB total")

    # Point out anything in the output directory this run did not write, so
    # an image dropped from MAPPING is easy to spot. Deleting is left to the
    # person, since a file here may be referenced from somewhere else.
    orphans = sorted(
        name
        for name in os.listdir(OUT_DIR)
        if name not in outputs and not name.startswith(".")
    )
    if orphans:
        print(f"\nnot produced by this script (delete by hand if stale):")
        for name in orphans:
            print(f"  {name}")


if __name__ == "__main__":
    main()
