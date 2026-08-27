# README Redesign — Design Spec

**Date:** 2026-06-13
**Status:** Approved (pending written-spec review)
**Topic:** Redesign the GitHub project README (`README.md`) to be more visually
appealing using app screenshots, while preserving all existing information
(getting started, build instructions, architecture, etc.).

---

## 1. Goals

1. Make the top of the README visually striking so the GitHub project page sells
   the app at a glance.
2. Showcase the app with real screenshots (hero banner + feature showcase).
3. Preserve **100%** of the current README's useful information — nothing is
   deleted, only reorganized. Developer-heavy content moves into collapsible
   `<details>` blocks rather than being removed.

## 2. Constraints

- **GitHub-flavored Markdown rendering:** `<img>`, `<picture>`, `<details>`,
  `<table>` are allowed; `<style>`, CSS, and `<script>` are stripped. All layout
  must use these allowed primitives. Column widths use the `width` attribute on
  `<img>`/`<td>`, not `style=`.
- **No emoji** anywhere in the README (project rule in `CLAUDE.md`). Visual
  emphasis comes from screenshots and `<details>` widgets, not emoji headers.
- **Source screenshots are gitignored:** `screenshots/Screenshots/` is not
  tracked. README images must be committed copies in a tracked path.
- **App theme:** dark UI with a teal/cyan accent and a red dive-flag logo. The
  showcase standardizes on **dark-theme** screenshots for cohesion (decided over
  a light/dark mix, which never looks uniform because a README renders on one
  page background while screenshots carry their own).
- **Dual GitHub themes:** the README is viewed on a white (light) or near-black
  (dark) page depending on the viewer. The hero banner is therefore a
  **transparent PNG** so it sits cleanly on both.

## 3. Approved decisions

| Decision | Choice |
| --- | --- |
| Overall structure | **Marketing top, developer details in collapsibles** (single file) |
| Hero treatment | **Baked layered "collage" banner** — one pre-composed transparent PNG (tilted/overlapping desktops + upright-ish phone) |
| Feature showcase | **Alternating feature rows** (image one side, heading + bullets the other), all-dark screenshots |
| Screenshot source | Curate from `screenshots/Screenshots/` (freshest set, per user) |
| Screenshot destination | `docs/assets/screenshots/readme/` (git-tracked) |

## 4. README structure (section by section)

1. **Header** (centered)
   - Official logo `assets/icon/icon.png` at ~80px (via `<img width="80">`).
   - Title: **Submersion**
   - Tagline: *"Own your dive log. Free and open-source, forever."*
   - Existing build-status + license badges, then existing download badges
     (kept verbatim).

2. **Hero banner** — `docs/assets/screenshots/readme/hero.png`, centered, full
   width, transparent background.

3. **Intro paragraph** — existing "Submersion gives scuba divers full
   ownership..." text, kept verbatim.

4. **Feature showcase** — alternating rows, dark screenshots. Five marquee rows:
   1. Comprehensive Dive Logging
   2. Profile & Decompression Analysis (tissue-loading heatmap)
   3. 300+ Dive Computers (USB / Bluetooth)
   4. Dive Sites, GPS & Maps
   5. Statistics & Records

   Each row: one screenshot + a heading + 3-4 bullet points. Rows alternate
   image left / image right.

5. **Why Submersion? + Data Philosophy** — existing bullet sets, kept.

6. **Full Feature List** — existing categorized bullets, kept for completeness.
   The three longest sub-sections collapse into `<details>` so the section stays
   scannable.

7. **Getting Started** — Prerequisites + Quick Start, fully visible.

8. **Build & Development** — moved into collapsible `<details>` blocks (collapsed
   by default; content preserved verbatim):
   - Build for Release (all platforms)
   - macOS without an Apple certificate
   - Windows from source
   - Linux from source (distro dependency lists)
   - Architecture & tech stack (+ link to `ARCHITECTURE.md`)

9. **Roadmap** — existing table, kept.
10. **Contributing** — kept.
11. **License** — kept.
12. **Acknowledgments** — kept.
13. **Footer** — *"Dive safe. Log everything. Own your data."*

## 5. Hero banner specification

A single transparent PNG composed from three source screenshots:

- **Back-left:** desktop technical view (dives list + depth profile + deco +
  tissue loading), scaled to 1000px wide, 18px corners, rotated **-4°**.
- **Mid-right:** desktop dives + map (dark), 820px wide, 18px corners, **+4°**.
- **Front:** iPhone home (dark), **cropped to the device bezel** (drops the iOS
  Simulator toolbar + window background), 300px wide, bezel corners (~32px at
  placed size), rotated **+12°**, positioned over the right desktop so it floats
  in its own plane.

Composition rules learned during design (encoded in the script):
- Desktop window screenshots are auto-trimmed of their dark drop-shadow
  background (bright-content bounding box).
- The phone is cropped to a calibrated device box and masked at the bezel
  radius; the bottom crop matches the top bezel so the chin is symmetric (no
  black border on the light theme).
- Layers are composited on an oversized margin canvas so rotated + shadowed
  layers never clip at an edge; a final `getbbox()` crop trims tight.

**Maintenance note:** the phone crop box `(120, 222, 1016, 2028)` is calibrated
to the specific `1136x2168` capture (`...10.44.45 PM.png`). If the iPhone
screenshot is re-captured at a different size, the crop box must be recalibrated.

The compose script is committed to `scripts/readme/compose_hero.py` (full source
in Appendix A) with a short usage note, so the banner is reproducible.

## 6. Screenshot assets

- **Source:** `screenshots/Screenshots/` (macOS captures + real iOS captures).
  The `screenshots/iPhone_6_7_inch/` and `screenshots/iPad_13_inch/` folders are
  **splash-screen-only and unusable** — do not use them.
- **Destination:** `docs/assets/screenshots/readme/` (git-tracked).
- **Optimization:** resize to ~1000px wide, compress (JPEG for opaque shots;
  PNG with transparency for `hero.png`). Source PNGs are 1-5 MB; optimized
  copies are tens-to-low-hundreds of KB.
- **Naming:** semantic — `01-dive-logging.png`, `02-profile-deco.png`,
  `03-dive-computers.png`, `04-sites-map.png`, `05-statistics.png`, `hero.png`.
- **Verification requirement:** the auto-generated screenshot catalog had several
  **mislabeled** timestamp→screen mappings. Every chosen image MUST be confirmed
  by viewing it, not by trusting a filename or catalog label.

### Verified source → feature mapping

These timestamp→screen mappings were confirmed by viewing the images:

| Feature / use | Source (timestamp) | Theme | Notes |
| --- | --- | --- | --- |
| Hero — desktop technical | `10.10.59` | dark | dives + profile + deco + tissue loading |
| Hero — desktop map | `10.13.35` | dark | dives + Bonaire map |
| Hero — phone | `10.44.45` | dark | iOS home; crop `(120,222,1016,2028)` |
| Dive Logging row | `10.24.28` | dark | dives table + profile + map |
| Profile & Deco row | crop of `10.10.59` right pane | dark | profile + deco + O2 + tissue loading |
| Sites, GPS & Conditions row | `10.21.31` | dark | tide chart + surface GPS |
| Statistics row | `10.19.44` | dark | stats overview + records |
| Equipment (spare) | `10.15.22` | dark | gear detail + service history |
| Gas calculator (spare) | `10.28.08` | dark | MOD calculator |

**Still to verify during implementation:** the **300+ Dive Computers** row image
(candidate `10.17.30` Transfer / Dive Computers, dark — not yet visually
confirmed). If unsuitable, pick another verified dark shot.

## 7. Non-goals / out of scope

- No mobile (iPad) showcase shots beyond the iPhone already in the hero (the
  curated tablet set is splash-only; not re-capturing for this task).
- No content rewrite of feature copy beyond light editing to fit rows; existing
  factual content is preserved.
- No CI or docs-site changes; this is `README.md` plus committed image assets and
  the compose script.

## 8. Open items to settle in the implementation plan

1. Confirm/replace the Dive Computers row screenshot (verify by viewing).
2. Exact `<details>` grouping for the "Full Feature List" long sub-sections.
3. Whether to add an optional small "Available everywhere" mobile strip (the
   hero already signals cross-platform; default is to skip).

---

## Appendix A — `compose_hero.py` (approved generator)

```python
#!/usr/bin/env python3
"""Compose a layered 'collage' README hero banner from app screenshots.

Outputs a transparent PNG so the banner sits cleanly on both GitHub light and
dark themes.
"""
import glob
import sys
from PIL import Image, ImageDraw, ImageFilter

SRC = "screenshots/Screenshots"  # adjust to repo-relative path on integration
OUT = sys.argv[1] if len(sys.argv) > 1 else "docs/assets/screenshots/readme/hero.png"

# Oversized transparent working canvas. Layers are placed against design
# coordinates plus MARGIN so rotated + shadowed layers never hit an edge;
# the final getbbox() crop trims the transparent border tight to the content.
MARGIN = 180
W, H = 1700 + MARGIN * 2, 720 + MARGIN * 2
canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))


def load(ts):
    """Load the (single) source screenshot whose name contains timestamp ts."""
    matches = glob.glob(f"{SRC}/*{ts}*.png")
    if not matches:
        raise SystemExit(f"no screenshot matches '{ts}'")
    return Image.open(matches[0]).convert("RGBA")


def rounded(img, radius):
    """Apply rounded corners via an alpha mask."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def with_shadow(img, blur=30, offset=(0, 18), opacity=130, pad=80):
    """Return a larger RGBA image of img with a soft drop shadow behind it."""
    w, h = img.size
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sil = Image.new("RGBA", img.size, (0, 0, 0, opacity))
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
    """Crop a window screenshot to its bounding box, dropping the dark
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
    if crop:  # explicit crop (e.g. phone device box) takes precedence
        src = src.crop(crop)
    else:  # desktop window shots: trim the dark background + drop shadow
        src = autotrim(src)
    img = rounded(scaled(src, target_w), radius)
    img = with_shadow(img)
    img = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    cx, cy = center[0] + MARGIN, center[1] + MARGIN
    x = int(cx - img.size[0] / 2)
    y = int(cy - img.size[1] / 2)
    canvas.alpha_composite(img, (x, y))


# Back: desktop technical view (dives + profile + deco + tissue loading)
place("10.10.59", target_w=1000, radius=18, angle=-4, center=(540, 360))
# Mid-right: desktop dives + Bonaire map (dark)
place("10.13.35", target_w=820, radius=18, angle=4, center=(1230, 360))
# Front: iPhone home (dark), cropped to the device bezel, leaning +12.
place("10.44.45", target_w=300, radius=32, angle=12, center=(1150, 400),
      crop=(120, 222, 1016, 2028))

# Trim fully-transparent margins, then export
bbox = canvas.getbbox()
if bbox:
    canvas = canvas.crop(bbox)
canvas.save(OUT)
print(f"wrote {OUT} ({canvas.size[0]}x{canvas.size[1]})")
```

Requires Pillow (`pip3 install --user Pillow`). The crop pane for the
Profile & Deco showcase row is produced by trimming `10.10.59` to its window
bbox and cropping the right ~57% (detail pane), dropping the top title bar.
