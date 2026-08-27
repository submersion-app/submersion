# README Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `README.md` into a marketing-style page — a baked collage hero banner, alternating dark-theme screenshot feature rows, and developer/build details preserved in collapsible `<details>` — while keeping 100% of the current information.

**Architecture:** README images are produced by two committed, reproducible Python (Pillow) scripts under `scripts/readme/` and written to `docs/assets/screenshots/readme/`. The README itself is hand-authored Markdown using only GitHub-supported HTML (`<img>`, `<table>`, `<details>`). Existing prose sections are preserved verbatim; build/architecture sections are wrapped in `<details>`.

**Tech Stack:** Python 3 + Pillow (image compositing), macOS `sips` (quick dimension checks), GitHub-flavored Markdown.

**Source of truth:** Design spec at `docs/superpowers/specs/2026-06-13-readme-redesign-design.md`.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `scripts/readme/compose_hero.py` | Create | Composites the transparent collage hero banner from 3 source screenshots |
| `scripts/readme/prepare_showcase.py` | Create | Produces the 5 optimized dark feature-row images (incl. the cropped deco pane) |
| `scripts/readme/README.md` | Create | One-paragraph usage note for regenerating README assets |
| `docs/assets/screenshots/readme/hero.png` | Create | Baked transparent hero banner (generated) |
| `docs/assets/screenshots/readme/01-dive-logging.jpg` ... `05-statistics.jpg` | Create | Showcase row images (generated, opaque JPEG) |
| `README.md` | Modify | Full restructure; preserves all current content |

**Image format decision (resolves a minor spec inconsistency):** the hero is **PNG** (needs transparency); the five showcase images are **JPEG** (`.jpg`, opaque, smaller for page-load). This supersedes the `.png` examples in spec §6 naming.

**Source screenshots** live in `screenshots/Screenshots/` (gitignored; macOS filenames contain a U+202F narrow-no-break space before "PM" — always match by timestamp glob, never type the space).

**Verified source → output mapping** (each confirmed by viewing during design; re-verify before use):

| Output | Source timestamp | Screen |
| --- | --- | --- |
| `hero.png` (back-left) | `10.10.59` | desktop: dives + profile + deco + tissue loading |
| `hero.png` (mid-right) | `10.13.35` | desktop: dives + map |
| `hero.png` (front phone) | `10.44.45` | iOS home (crop `(120,222,1016,2028)`) |
| `01-dive-logging.jpg` | `10.24.28` | desktop dives table + profile + map |
| `02-profile-deco.jpg` | `10.10.59` (right-pane crop) | profile + deco + O2 + tissue loading |
| `03-dive-computers.jpg` | `10.17.30` (MUST verify by viewing) | Transfer / Dive Computers |
| `04-sites-gps.jpg` | `10.21.31` | dive detail: tide + surface GPS |
| `05-statistics.jpg` | `10.19.44` | statistics overview + records |

---

## Task 1: Branch + environment + directories

**Files:** none (setup only)

- [ ] **Step 1: Create a feature branch**

Run:
```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git checkout -b docs/readme-redesign
```
Expected: `Switched to a new branch 'docs/readme-redesign'`

- [ ] **Step 2: Ensure Pillow is available**

Run:
```bash
python3 -c "import PIL; print('Pillow', PIL.__version__)" || pip3 install --user Pillow
```
Expected: prints `Pillow <version>` (e.g. `Pillow 11.3.0`).

- [ ] **Step 3: Create destination directories**

Run:
```bash
mkdir -p scripts/readme docs/assets/screenshots/readme
ls -d scripts/readme docs/assets/screenshots/readme
```
Expected: both paths listed.

- [ ] **Step 4: Commit the empty scaffolding marker (skip if nothing to add)**

No commit yet — directories are created with content in later tasks.

---

## Task 2: Hero compose script + banner

**Files:**
- Create: `scripts/readme/compose_hero.py`
- Create (generated): `docs/assets/screenshots/readme/hero.png`

- [ ] **Step 1: Create `scripts/readme/compose_hero.py`**

Write this exact file (repo-relative paths; run from the repo root):

```python
#!/usr/bin/env python3
"""Compose the transparent collage hero banner for the README.

Run from the repo root:  python3 scripts/readme/compose_hero.py
Outputs a transparent PNG so the banner works on GitHub light AND dark themes.
Requires Pillow.  Source screenshots: screenshots/Screenshots/ (gitignored).
macOS screenshot filenames contain a U+202F space, so match by timestamp glob.
"""
import glob
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
```

- [ ] **Step 2: Generate the banner**

Run:
```bash
python3 scripts/readme/compose_hero.py
```
Expected: `wrote docs/assets/screenshots/readme/hero.png (1776x875)` (dimensions ±a few px).

- [ ] **Step 3: Verify dimensions and transparency**

Run:
```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha docs/assets/screenshots/readme/hero.png
```
Expected: width ~1776, height ~875, `hasAlpha: yes`.

- [ ] **Step 4: View the banner to confirm quality**

Open `docs/assets/screenshots/readme/hero.png` (use the Read tool on the file, or `open` it). Confirm: two angled desktop windows + an upright-ish iPhone in front, clean rounded corners, soft shadows, no black borders, no clipped edges. If wrong, re-check the source timestamps and crop box, then regenerate.

- [ ] **Step 5: Commit**

```bash
git add scripts/readme/compose_hero.py docs/assets/screenshots/readme/hero.png
git commit -m "feat(readme): add hero banner compose script and generated banner"
```

---

## Task 3: Showcase image script + 5 feature-row images

**Files:**
- Create: `scripts/readme/prepare_showcase.py`
- Create (generated): `docs/assets/screenshots/readme/01-dive-logging.jpg` … `05-statistics.jpg`

- [ ] **Step 1: Verify the Dive Computers source by viewing**

The screenshot catalog was unreliable, so confirm the candidate before scripting it. Run:
```bash
cd screenshots/Screenshots && m=( *"10.17.30"*.png ) && sips -Z 760 "${m[1]}" --out /tmp/verify-divecomputers.png && cd -
```
Then view `/tmp/verify-divecomputers.png` (Read tool). Confirm it shows the Transfer / Dive Computers screen (paired dive computers, USB/Bluetooth). If it does NOT, pick another dark dive-computer/transfer screen by viewing candidates and update the timestamp used in Step 2.

- [ ] **Step 2: Create `scripts/readme/prepare_showcase.py`**

Write this exact file:

```python
#!/usr/bin/env python3
"""Produce the 5 optimized dark-theme feature-row images for the README.

Run from the repo root:  python3 scripts/readme/prepare_showcase.py
Requires Pillow.  Source: screenshots/Screenshots/ (match by timestamp glob).
Each desktop window is trimmed of its dark drop-shadow background; the deco
image is a crop of the dive-detail right pane.
"""
import glob
from PIL import Image

SRC = "screenshots/Screenshots"
OUT = "docs/assets/screenshots/readme"
TARGET_W = 1100  # showcase display width


def load(ts):
    matches = glob.glob(f"{SRC}/*{ts}*.png")
    if not matches:
        raise SystemExit(f"no screenshot matches '{ts}'")
    return Image.open(matches[0]).convert("RGB")


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
    img.save(f"{OUT}/{name}", quality=82)
    print(f"wrote {OUT}/{name} ({img.size[0]}x{img.size[1]})")


# Full-window shots: autotrim then resize
save_jpg(autotrim(load("10.24.28")), "01-dive-logging.jpg")
save_jpg(autotrim(load("10.17.30")), "03-dive-computers.jpg")  # update ts if Step 1 failed
save_jpg(autotrim(load("10.21.31")), "04-sites-gps.jpg")
save_jpg(autotrim(load("10.19.44")), "05-statistics.jpg")

# Deco: crop the dive-detail RIGHT PANE (profile + deco + O2 + tissue loading)
win = autotrim(load("10.10.59"))
WW, HH = win.size
pane = win.crop((int(WW * 0.43), int(HH * 0.045), WW, HH))
save_jpg(pane, "02-profile-deco.jpg")
```

- [ ] **Step 3: Generate the showcase images**

Run:
```bash
python3 scripts/readme/prepare_showcase.py
```
Expected: five `wrote docs/assets/screenshots/readme/0X-....jpg` lines.

- [ ] **Step 4: View each generated image to confirm correctness**

View all five (Read tool) and confirm each matches its feature:
- `01-dive-logging.jpg` — dives table/list with profile
- `02-profile-deco.jpg` — profile chart + Deco Status + Oxygen Toxicity + Tissue Loading heatmap (right pane only, no dive list)
- `03-dive-computers.jpg` — Transfer / Dive Computers
- `04-sites-gps.jpg` — tide chart + surface GPS map
- `05-statistics.jpg` — statistics overview with stat cards + records

Each must be dark-theme, edges clean (no black shadow border). Fix the relevant source timestamp / crop fractions and regenerate if any is wrong.

- [ ] **Step 5: Check file sizes are web-reasonable**

Run:
```bash
ls -la docs/assets/screenshots/readme/*.jpg | awk '{printf "%6dKB  %s\n",$5/1024,$9}'
```
Expected: each well under ~400 KB.

- [ ] **Step 6: Commit**

```bash
git add scripts/readme/prepare_showcase.py docs/assets/screenshots/readme/*.jpg
git commit -m "feat(readme): add showcase image script and generated feature-row images"
```

---

## Task 4: Rewrite README.md

**Files:**
- Modify: `README.md` (full restructure)

**Preservation rule:** Keep every current section's prose verbatim. Line references below point at the CURRENT `README.md` (323 lines). Move build/architecture sections into `<details>`; do not delete any content.

- [ ] **Step 1: Replace the header + add hero + intro (current lines 1-17)**

Replace the top of the file (the `<div>` logo block through the intro paragraph) with:

```html
<div align="center">

<img src="assets/icon/icon.png" alt="Submersion logo" width="80">

# Submersion

*Own your dive log. Free and open-source, forever.*

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Build macOS](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=macOS&logo=apple)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)
[![Build Windows](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=Windows&logo=windows)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)
[![Build Linux](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=Linux&logo=linux)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)
[![Build Android](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=Android&logo=android)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)
[![Build iOS](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=iOS&logo=apple)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)

[![Download macOS](https://img.shields.io/badge/Download-macOS-2ea44f?logo=apple)](https://github.com/submersion-app/submersion/releases) [![Download Windows](https://img.shields.io/badge/Download-Windows-2ea44f?logo=windows)](https://github.com/submersion-app/submersion/releases) [![Download Linux](https://img.shields.io/badge/Download-Linux-2ea44f?logo=linux)](https://github.com/submersion-app/submersion/releases) [![Download Android](https://img.shields.io/badge/Download-Android-2ea44f?logo=android)](https://github.com/submersion-app/submersion/releases) [![Download iOS](https://img.shields.io/badge/Download-iOS-2ea44f?logo=apple)](https://apps.apple.com/us/app/submersion-dive-log/id6757456915)

<img src="docs/assets/screenshots/readme/hero.png" alt="Submersion on macOS and iOS" width="900">

</div>

Submersion gives scuba divers full ownership of their logbooks — no proprietary formats, no cloud lock-in, no subscription fees. Track analytics, stats, records, and trends across your dives, all stored locally and exportable to open standards. Free and open-source, forever.
```

- [ ] **Step 2: Insert the feature showcase (new section, after the intro)**

Add this section immediately after the intro paragraph. Rows alternate image side; cells use HTML so content renders reliably inside tables:

```html
## See it in action

<table>
<tr>
<td width="58%"><img src="docs/assets/screenshots/readme/01-dive-logging.jpg" alt="Dive logging"></td>
<td width="42%">
<h3>Comprehensive Dive Logging</h3>
<p>Every dive, fully detailed and in your control.</p>
<ul>
<li>Depth, duration, temperatures, conditions</li>
<li>Multi-tank gas mixes: air, nitrox, trimix</li>
<li>Buddies, trips, tags, and ratings</li>
<li>Sortable table or card views</li>
</ul>
</td>
</tr>
</table>

<table>
<tr>
<td width="42%">
<h3>Profile &amp; Decompression Analysis</h3>
<p>Serious technical-diving instrumentation.</p>
<ul>
<li>Interactive depth / temperature / pressure profile</li>
<li>16-compartment tissue loading visualization</li>
<li>Bühlmann ZH-L16C with gradient factors</li>
<li>CNS%, OTU, and ppO₂ tracking</li>
</ul>
</td>
<td width="58%"><img src="docs/assets/screenshots/readme/02-profile-deco.jpg" alt="Profile and decompression analysis"></td>
</tr>
</table>

<table>
<tr>
<td width="58%"><img src="docs/assets/screenshots/readme/03-dive-computers.jpg" alt="Dive computer integration"></td>
<td width="42%">
<h3>300+ Dive Computers</h3>
<p>Download dives directly from your computer.</p>
<ul>
<li>USB and Bluetooth LE connectivity</li>
<li>Shearwater, Suunto, Mares, Aqualung, and more</li>
<li>Incremental downloads with duplicate detection</li>
<li>Powered by libdivecomputer</li>
</ul>
</td>
</tr>
</table>

<table>
<tr>
<td width="42%">
<h3>Sites, GPS &amp; Conditions</h3>
<p>Location and environment for every dive.</p>
<ul>
<li>GPS entry/exit with interactive maps</li>
<li>Tide and weather integration</li>
<li>Reverse-geocoded country and region</li>
</ul>
</td>
<td width="58%"><img src="docs/assets/screenshots/readme/04-sites-gps.jpg" alt="Dive sites, GPS and conditions"></td>
</tr>
</table>

<table>
<tr>
<td width="58%"><img src="docs/assets/screenshots/readme/05-statistics.jpg" alt="Statistics and records"></td>
<td width="42%">
<h3>Statistics &amp; Records</h3>
<p>See your diving life at a glance.</p>
<ul>
<li>Totals, averages, and personal records</li>
<li>Breakdowns by year, country, and site</li>
<li>SAC trends and depth distribution</li>
</ul>
</td>
</tr>
</table>
```

- [ ] **Step 3: Keep "Why Submersion?" and "Data Philosophy" verbatim**

Preserve current README lines 19-38 (the `## Why Submersion?` bullet list and `## Data Philosophy` numbered list) exactly as they are, placed after the showcase.

- [ ] **Step 4: Keep the full "Features" section verbatim**

Preserve current README lines 40-122 (`## Features` and all sub-sections, including the "Confirmed working" callout) exactly, after Data Philosophy.

- [ ] **Step 5: Keep "Getting Started" (Prerequisites + Quick Start) visible**

Preserve current README lines 124-148 (`## Getting Started`, `### Prerequisites`, `### Quick Start` with its code block) exactly.

- [ ] **Step 6: Wrap build + architecture sections in `<details>`**

Replace the visible build/architecture sections (current lines 150-280) with collapsibles. Each `<summary>` is followed by a blank line, then the ORIGINAL content of that section verbatim, then `</details>`. Use this structure (fill each block with the exact current content from the referenced lines):

```html
## Building from Source

<details>
<summary><b>Build for release (iOS, Android, macOS, Windows, Linux)</b></summary>

<!-- verbatim content from current README lines 150-167 (the "Build for Release" code block) -->

</details>

<details>
<summary><b>macOS: building without a developer certificate</b></summary>

<!-- verbatim content from current README lines 169-194 -->

</details>

<details>
<summary><b>Windows: building from source</b></summary>

<!-- verbatim content from current README lines 196-207 -->

</details>

<details>
<summary><b>Linux: building from source (distro dependencies)</b></summary>

<!-- verbatim content from current README lines 209-246 -->

</details>

<details>
<summary><b>Architecture &amp; tech stack</b></summary>

<!-- verbatim content from current README lines 248-280 (the lib/ tree, tech stack, ARCHITECTURE.md link) -->

</details>
```

Note: inside `<details>`, keep a blank line after `<summary>` and before `</details>` so the Markdown code fences and lists render.

- [ ] **Step 7: Keep Roadmap, Contributing, License, Acknowledgments, footer verbatim**

Preserve current README lines 282-323 (`## Roadmap` table, `## Contributing`, `## License`, `## Acknowledgments`, and the closing `*Dive safe. Log everything. Own your data.*`) exactly.

- [ ] **Step 8: Verify no information was lost**

Run these greps; every one must return a match (proves preserved content survived the restructure):
```bash
grep -c "300+ supported dive computers" README.md
grep -c "Bühlmann ZH-L16C" README.md
grep -c "build_nosandbox_macos.sh" README.md
grep -c "libgtk-3-dev liblzma-dev" README.md
grep -c "UDDF 3.2" README.md
grep -c "git submodule update --init --recursive" README.md
grep -c "Dive safe. Log everything. Own your data." README.md
grep -c "ARCHITECTURE.md" README.md
```
Expected: each prints `1` (or more). If any prints `0`, that content was dropped — restore it.

- [ ] **Step 9: Verify all image paths resolve**

Run:
```bash
for p in $(grep -oE 'docs/assets/screenshots/readme/[^"]+' README.md); do test -f "$p" && echo "OK $p" || echo "MISSING $p"; done
test -f assets/icon/icon.png && echo "OK logo" || echo "MISSING logo"
```
Expected: all `OK`, no `MISSING`.

- [ ] **Step 10: Commit**

```bash
git add README.md
git commit -m "feat(readme): redesign with hero banner, feature showcase, and collapsible build docs"
```

---

## Task 5: Render verification

**Files:** none (verification only)

- [ ] **Step 1: Local structural sanity check**

Run:
```bash
grep -c "<details>" README.md   # expect 5
grep -c "</details>" README.md  # expect 5 (balanced)
grep -c "<table>" README.md     # expect 5 (showcase rows)
```
Expected: `<details>` open/close balanced at 5 each; 5 tables.

- [ ] **Step 2: Render the README on GitHub**

Push the branch and open it on GitHub to confirm real rendering (local Markdown preview does NOT match GitHub's `<details>`/table handling):
```bash
git push -u origin docs/readme-redesign
```
Then view `https://github.com/submersion-app/submersion/tree/docs/readme-redesign` and confirm: hero renders on both light and dark theme (toggle GitHub appearance), the 5 feature rows alternate and images load, the 5 build/architecture `<details>` expand correctly, and no raw HTML leaks as text.

- [ ] **Step 3: Fix any rendering issues**

If a table cell shows raw `<li>` text or a `<details>` body fails to render its code block, ensure there is a blank line after `<summary>` and around Markdown inside HTML blocks. Re-commit fixes.

- [ ] **Step 4: Open a pull request (optional, when ready)**

```bash
gh pr create --title "Redesign README with hero banner and screenshot showcase" \
  --body "Marketing-style README: baked collage hero, alternating dark-theme feature rows, build/architecture moved into collapsible <details>. All prior content preserved. Assets generated by scripts/readme/."
```

---

## Task 6: Document asset regeneration

**Files:**
- Create: `scripts/readme/README.md`

- [ ] **Step 1: Write `scripts/readme/README.md`**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/readme/README.md
git commit -m "docs(readme): document README asset regeneration scripts"
```

---

## Self-Review

**Spec coverage:**
- Marketing-top structure with collapsibles → Task 4 Steps 1, 6.
- Baked collage hero (transparent PNG) → Task 2.
- Alternating dark feature rows → Task 4 Step 2 + Task 3.
- Preserve 100% of content → Task 4 Steps 3-8 (verbatim + grep verification).
- Screenshots committed to `docs/assets/screenshots/readme/` → Tasks 2, 3.
- Compose script committed to `scripts/readme/compose_hero.py` → Task 2.
- Verify-by-viewing requirement → Task 2 Step 4, Task 3 Steps 1 & 4.
- No emoji → header/showcase use no emoji (only ZH-L16C / ppO₂ technical symbols, which are not emoji).
- Open item: Dive Computers image → Task 3 Step 1 (verify) covered.

**Placeholder scan:** The `<!-- verbatim content from lines X-Y -->` markers in Task 4 Step 6 are precise pointers to existing content (preservation), not undefined work. All scripts are shown in full. No TBD/TODO.

**Type/path consistency:** Output filenames match between Task 3 (generation) and Task 4 Step 2 (references): `01-dive-logging.jpg`, `02-profile-deco.jpg`, `03-dive-computers.jpg`, `04-sites-gps.jpg`, `05-statistics.jpg`, `hero.png`. The `04-sites-gps.jpg` name is used consistently. `prepare_showcase.py` writes exactly the five names the README references.

No gaps found.
