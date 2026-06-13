#!/usr/bin/env python3
"""Compose the transparent collage hero banner for the README.

Run from the repo root:  python3 scripts/readme/compose_hero.py
Outputs a transparent PNG so the banner works on GitHub light AND dark themes.
Requires Pillow.  Source screenshots: screenshots/Screenshots/ (gitignored).
macOS screenshot filenames contain a U+202F space, so match by timestamp glob.
Example source filename: "Screenshot 2026-06-12 at 10.10.59 PM.png".
"""
import glob
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

SRC = "screenshots/Screenshots"
OUT = sys.argv[1] if len(sys.argv) > 1 else "docs/assets/screenshots/readme/hero.png"

MARGIN = 180  # oversized canvas so rotated+shadowed layers never clip; cropped at end
W, H = 1700 + MARGIN * 2, 720 + MARGIN * 2
canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))


def load(ts):
    matches = glob.glob(f"{SRC}/*{ts}*.png")
    if not matches:
        raise SystemExit(f"no screenshot matches '{ts}'")
    return Image.open(matches[0]).convert("RGBA")


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def with_shadow(img, blur=30, offset=(0, 18), opacity=130, pad=80):
    w, h = img.size
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sil = Image.new("RGBA", img.size, (0, 0, 0, 255))
    sil.putalpha(img.split()[3].point(lambda a: int(a * opacity / 255)))
    shadow.paste(sil, (pad + offset[0], pad + offset[1]), sil)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    layer.alpha_composite(shadow)
    layer.alpha_composite(img, (pad, pad))
    return layer


def scaled(img, target_w):
    r = target_w / img.size[0]
    return img.resize((target_w, int(img.size[1] * r)), Image.LANCZOS)


def autotrim(img, threshold=80, step=4):
    """Crop a window screenshot to its bright-content bbox, dropping the dark
    background + drop shadow."""
    g = img.convert("L")
    px = g.load()
    w, h = g.size
    cols = [x for x in range(w) if max(px[x, y] for y in range(0, h, step)) > threshold]
    rows = [y for y in range(h) if max(px[x, y] for x in range(0, w, step)) > threshold]
    if not cols or not rows:
        return img
    return img.crop((min(cols), min(rows), max(cols) + 1, max(rows) + 1))


def place(ts, target_w, radius, angle, center, crop=None):
    src = load(ts)
    if crop:
        src = src.crop(crop)
    else:
        src = autotrim(src)
    img = rounded(scaled(src, target_w), radius)
    img = with_shadow(img)
    img = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    cx, cy = center[0] + MARGIN, center[1] + MARGIN
    canvas.alpha_composite(img, (int(cx - img.size[0] / 2), int(cy - img.size[1] / 2)))


def main():
    global canvas
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # Back: desktop technical view (dives + profile + deco + tissue loading)
    place("10.10.59", target_w=1000, radius=18, angle=-4, center=(540, 360))
    # Mid-right: desktop dives + map (dark)
    place("10.13.35", target_w=820, radius=18, angle=4, center=(1230, 360))
    # Front: iPhone home (dark), cropped to the device bezel, leaning +12.
    place("10.44.45", target_w=300, radius=32, angle=12, center=(1150, 400),
          crop=(120, 222, 1016, 2028))

    bbox = canvas.getbbox()
    if bbox:
        canvas = canvas.crop(bbox)
    canvas.save(OUT)
    print(f"wrote {OUT} ({canvas.size[0]}x{canvas.size[1]})")


if __name__ == "__main__":
    main()
