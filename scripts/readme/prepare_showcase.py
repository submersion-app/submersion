#!/usr/bin/env python3
"""Produce the 5 optimized dark-theme feature-row images for the README.

Run from the repo root:  python3 scripts/readme/prepare_showcase.py
Requires Pillow.  Source: screenshots/Screenshots/ (gitignored); match by
timestamp glob because macOS filenames contain a U+202F narrow-no-break space.
Example source filename: "Screenshot 2026-06-12 at 10.24.28 PM.png".
Each desktop window is trimmed of its dark drop-shadow background; the deco
image is a crop of the dive-detail right pane.
"""
import glob
import os
from PIL import Image

SRC = "screenshots/Screenshots"
OUT = "docs/assets/screenshots/readme"
TARGET_W = 1100  # showcase display width


def load(ts):
    matches = glob.glob(f"{SRC}/*{ts}*.png")
    if not matches:
        raise SystemExit(f"no screenshot matches '{ts}'")
    return Image.open(matches[0]).convert("RGBA")


def autotrim(img, threshold=80, step=4):
    g = img.convert("L")
    px = g.load()
    w, h = g.size
    cols = [x for x in range(w) if max(px[x, y] for y in range(0, h, step)) > threshold]
    rows = [y for y in range(h) if max(px[x, y] for x in range(0, w, step)) > threshold]
    if not cols or not rows:
        return img
    return img.crop((min(cols), min(rows), max(cols) + 1, max(rows) + 1))


def save_jpg(img, name, target_w=TARGET_W):
    if img.size[0] > target_w:
        r = target_w / img.size[0]
        img = img.resize((target_w, int(img.size[1] * r)), Image.LANCZOS)
    img = img.convert("RGB")
    img.save(f"{OUT}/{name}", quality=82)
    print(f"wrote {OUT}/{name} ({img.size[0]}x{img.size[1]})")


def main():
    os.makedirs(OUT, exist_ok=True)
    # Full-window shots: autotrim then resize
    save_jpg(autotrim(load("10.24.28")), "01-dive-logging.jpg")
    save_jpg(autotrim(load("10.17.30")), "03-dive-computers.jpg")
    save_jpg(autotrim(load("10.21.31")), "04-sites-gps.jpg")
    save_jpg(autotrim(load("10.19.44")), "05-statistics.jpg")
    # Deco: crop the dive-detail RIGHT PANE (profile + deco + O2 + tissue loading)
    win = autotrim(load("10.10.59"))
    ww, hh = win.size
    pane = win.crop((int(ww * 0.43), int(hh * 0.045), ww, hh))
    save_jpg(pane, "02-profile-deco.jpg")


if __name__ == "__main__":
    main()
