# Brand Asset Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One command renders the approved Submersion social card and every other brand image (banners, transparent mark, lockups, wordmarks) from code.

**Architecture:** A new `scripts/brand/` folder holds the moved icon generator, a pure-data preset table, a Pillow-free layout module, a transparent-mark module built from the icon's own shape primitives, and a CLI renderer that draws with Pillow and bundled Inter Display fonts. Output goes to `assets/brand/`, where the generated PNGs are committed (changed after implementation from a gitignored `scripts/brand/out/`; see Task 6).

**Tech Stack:** Python 3.10+ (3.14 locally, `python3.14`; system `python3` is 3.9 and too old), Pillow >= 10.1 (float font sizes), `unittest`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-11-brand-asset-generator-design.md`

## Global Constraints

- No em-dashes (U+2014) or en-dashes as punctuation anywhere: code, comments, docs, commit messages.
- No mention of Claude, Claude Code, or Anthropic in any file, commit message, or trailer. No `Co-Authored-By` trailers.
- No emojis in code, comments, or docs.
- `scripts/generate_icon.py` moves to `scripts/brand/generate_icon.py`; its ONLY edit is the project-root path fix. No other code change to it.
- The generated PNGs are committed under `assets/brand/`, the generator's default output; `assets/brand/` must never be listed in `pubspec.yaml`. (Tasks 1 to 5 were executed with the original gitignored `scripts/brand/out/` design; Task 6 supersedes every `scripts/brand/out/` and `.gitignore` step in them.)
- The README is not modified.
- Tests fail, never skip, when Pillow or the fonts are missing.
- Colors: name `#06303C` (6, 48, 60); slogan `#0B4452` (11, 68, 82); rule `#C80000` (200, 0, 0); light-theme name white, slogan (230, 248, 250).
- Banner gradient: 160 degrees, `#4FE9FD` 0%, `#40D3E0` 45%, `#2FB4AA` 100%.
- Name text "Submersion"; slogan text "Dive safe. Log everything."
- Fonts: `InterDisplay-ExtraBold.ttf` (name), `InterDisplay-Medium.ttf` (slogan), under `scripts/brand/fonts/` with Inter's license as `OFL.txt`.
- Stage explicit paths only (never `git add -A` / `git add .`). Submodule init and `flutter pub get` are not needed for this work (no Flutter or native code changes).
- Run local Python through the venv: `scripts/.venv/bin/python` (created in Task 1).
- Text rendering REQUIRES Pillow's RAQM layout (system libfribidi: `brew install fribidi` / `apt-get install libfribidi0`). No BASIC fallback; the generator exits 2 with those install commands when RAQM is unavailable.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `scripts/brand/generate_icon.py` | Moved app icon generator (path fix only) |
| `scripts/brand/layout.py` | Pure geometry: boxes for icon, name, rule, slogan |
| `scripts/brand/presets.py` | Preset table, theme colors, safe insets |
| `scripts/brand/mark.py` | Transparent mark from icon primitives |
| `scripts/brand/generate_brand_assets.py` | Pillow rendering and CLI |
| `scripts/brand/layout_test.py` | Tests for layout.py and presets.py (no Pillow) |
| `scripts/brand/generate_brand_assets_test.py` | Rendering, mark, and CLI tests (Pillow) |
| `scripts/brand/fonts/` | Inter Display TTFs and OFL.txt |
| `scripts/brand/README.md` | Usage, preset purposes, how to add a preset |
| `scripts/requirements.txt` | Add Pillow |
| `.gitignore` | Add `scripts/brand/out/` |
| `.github/workflows/ci.yaml` | script-tests job: install Pillow, run brand tests |

---

### Task 1: Folder setup, icon generator move, fonts, dependencies

**Files:**
- Move: `scripts/generate_icon.py` -> `scripts/brand/generate_icon.py` (edit line 239 only)
- Create: `scripts/brand/fonts/InterDisplay-ExtraBold.ttf`, `scripts/brand/fonts/InterDisplay-Medium.ttf`, `scripts/brand/fonts/OFL.txt`
- Modify: `scripts/requirements.txt`, `.gitignore`

**Interfaces:**
- Produces: `scripts/brand/generate_icon.py` exporting `SUPERSAMPLE`, `build_flag(size)`, `build_wave_arrow_mask(size)`, `create_icon(size)` unchanged; the venv at `scripts/.venv`; the two font files.

- [ ] **Step 1: Create the venv and install Pillow**

Ask the user before downloading (package source PyPI). Then:

```bash
python3.14 -m venv scripts/.venv
scripts/.venv/bin/pip install 'Pillow>=10.1'
scripts/.venv/bin/python -c "import PIL, PIL.features as f; print(PIL.__version__, 'raqm' if f.check('raqm') else 'no-raqm')"
```

Expected: a Pillow version >= 10.1 and whether RAQM is available. Record both for the final report. `scripts/.venv/` is already covered by the `.venv/` pattern in `.gitignore`.

- [ ] **Step 2: Move the icon generator with git**

```bash
mkdir -p scripts/brand
git mv scripts/generate_icon.py scripts/brand/generate_icon.py
```

- [ ] **Step 3: Fix the project-root path (the only edit)**

In `scripts/brand/generate_icon.py`, `main()`:

```python
    project_root = os.path.dirname(script_dir)
```

becomes:

```python
    project_root = os.path.dirname(os.path.dirname(script_dir))
```

- [ ] **Step 4: Verify the moved script regenerates identical icons**

```bash
scripts/.venv/bin/python scripts/brand/generate_icon.py
scripts/.venv/bin/python - <<'EOF'
import subprocess
from io import BytesIO
from PIL import Image, ImageChops
for name in ("icon.png", "icon_macos.png", "icon_adaptive_foreground.png",
             "icon_adaptive_background.png", "favicon.png"):
    path = f"assets/icon/{name}"
    committed = subprocess.run(["git", "show", f"HEAD:{path}"], capture_output=True, check=True).stdout
    old = Image.open(BytesIO(committed)).convert("RGBA")
    new = Image.open(path).convert("RGBA")
    bbox = ImageChops.difference(old, new).getbbox()
    print(name, "identical pixels" if bbox is None else f"DIFFERS in {bbox}")
EOF
git status --short assets/icon/
```

Expected: every file prints `identical pixels` and the script wrote into `assets/icon/` (not `scripts/assets/icon/`). If `git status` shows the PNGs modified with identical pixels (encoder byte differences only), restore them with `git checkout -- assets/icon/`. These are regenerated outputs, not work in progress. If any file prints `DIFFERS`, stop and report: the move changed behavior.

Also confirm nothing was written to the wrong place:

```bash
test ! -e scripts/assets && echo "no stray scripts/assets"
```

- [ ] **Step 5: Download Inter and install the two fonts**

Ask the user before downloading (source: the official rsms/inter GitHub release v4.1; state the zip size shown by `curl -sIL` before fetching). `SCRATCH` below is the session scratchpad directory; run every command from the repository root:

```bash
SCRATCH=<session scratchpad path from the system prompt>
curl -sSLo "$SCRATCH/inter.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
unzip -l "$SCRATCH/inter.zip" | grep -E 'InterDisplay-(ExtraBold|Medium)\.ttf|LICENSE'
```

The listing shows where the static TTFs and the license live in the zip (expected `extras/ttf/` and `LICENSE.txt`; use the listed paths if they differ). Copy them into the repo:

```bash
mkdir -p scripts/brand/fonts
unzip -j -o "$SCRATCH/inter.zip" 'extras/ttf/InterDisplay-ExtraBold.ttf' 'extras/ttf/InterDisplay-Medium.ttf' -d scripts/brand/fonts/
unzip -p "$SCRATCH/inter.zip" LICENSE.txt > scripts/brand/fonts/OFL.txt
```

Verify:

```bash
scripts/.venv/bin/python -c "
from PIL import ImageFont
for f in ('InterDisplay-ExtraBold', 'InterDisplay-Medium'):
    font = ImageFont.truetype(f'scripts/brand/fonts/{f}.ttf', 116.5)
    print(f, font.getname(), font.getbbox('Submersion'))"
head -3 scripts/brand/fonts/OFL.txt
```

Expected: family `Inter Display`, styles `ExtraBold` and `Medium`, a float size accepted, and the license header naming the SIL Open Font License.

- [ ] **Step 6: Add Pillow to requirements and ignore the output folder**

Append to `scripts/requirements.txt`:

```
# brand/generate_icon.py, brand/generate_brand_assets.py - app icon and brand images
# (10.1 is the first release that accepts float font sizes)
Pillow>=10.1
```

Append to `.gitignore` next to the existing `scripts/sample_data/` line:

```
scripts/brand/out/
```

- [ ] **Step 7: Commit**

```bash
git add scripts/brand/generate_icon.py scripts/brand/fonts/InterDisplay-ExtraBold.ttf scripts/brand/fonts/InterDisplay-Medium.ttf scripts/brand/fonts/OFL.txt scripts/requirements.txt .gitignore
git add -u scripts/generate_icon.py
git commit -m "chore(brand): move the icon generator into scripts/brand and bundle Inter Display

The icon generator moves unchanged apart from its project-root path, which
now climbs one more directory. Inter Display (SIL Open Font License) is
bundled for the brand asset generator; Pillow is now listed in
scripts/requirements.txt, which the icon script already needed."
```

---

### Task 2: Layout geometry and preset table

**Files:**
- Create: `scripts/brand/layout.py`, `scripts/brand/presets.py`
- Test: `scripts/brand/layout_test.py`

**Interfaces:**
- Produces (`layout.py`): `NAME = "Submersion"`, `SLOGAN = "Dive safe. Log everything."`, `REF_ICON = 340.0`, frozen dataclasses `Insets(left, top, right, bottom)`, `Box(x, y, w, h)` with `.right`, `.bottom`, `.center_x`, `.center_y`, and `Layout(icon, name, name_px, rule, slogan, slogan_px, block)` where `rule`, `slogan`, `slogan_px` are `None` without a slogan; `compute_layout(width, height, insets, kind, show_slogan, measure, icon_ratio) -> Layout`. `measure(text: str, role: str, px: float) -> tuple[float, float]` returns the ink width and height; `role` is `"name"` or `"slogan"`; `kind` is `"horizontal"` or `"stacked"`.
- Produces (`presets.py`): frozen dataclass `Preset(name, width, height, kind, layout, purpose, theme="dark", show_slogan=True, icon_ratio=0.53, left_inset=None)`; `kind` in `"banner" | "transparent" | "mark"`, `layout` in `"horizontal" | "stacked" | "none"`; `PRESETS` tuple; `find(name) -> Preset` (raises `KeyError`); `safe_insets(preset) -> Insets`; `size_label(preset) -> str`; `THEMES = {"dark": (name_rgb, slogan_rgb), "light": (...)}`; `RULE_COLOR`, `LOCKUP_MARGIN = 48`, `DEFAULT_INSET_RATIO = 0.125`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/brand/layout_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for layout.py and presets.py.

Run: python3 scripts/brand/layout_test.py

Pure geometry, no Pillow: text is measured by a fake linear measurer, so
these tests pin the layout rules (slogan matches the wordmark width, every
element stays inside its safe area, blocks are centered) independently of
fonts.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import layout  # noqa: E402
import presets  # noqa: E402
from layout import Insets, compute_layout  # noqa: E402

EPS = 1e-6


def fake_measure(text, role, px):
    per_char = 0.55 if role == "name" else 0.5
    height = 0.72 if role == "name" else 0.9
    return len(text) * px * per_char, px * height


def layout_for(preset):
    return compute_layout(
        preset.width,
        preset.height,
        presets.safe_insets(preset),
        preset.layout,
        preset.show_slogan,
        fake_measure,
        preset.icon_ratio,
    )


def boxes(result):
    return [b for b in (result.icon, result.name, result.rule, result.slogan) if b]


class LayoutTest(unittest.TestCase):
    def test_slogan_width_matches_name_width(self):
        result = layout_for(presets.find("github-social"))
        self.assertAlmostEqual(result.slogan.w, result.name.w, places=6)

    def test_every_preset_stays_inside_its_safe_area(self):
        for preset in presets.PRESETS:
            if preset.kind == "mark":
                continue
            with self.subTest(preset=preset.name):
                ins = presets.safe_insets(preset)
                result = layout_for(preset)
                for box in boxes(result):
                    self.assertGreaterEqual(box.x, ins.left - EPS)
                    self.assertGreaterEqual(box.y, ins.top - EPS)
                    self.assertLessEqual(box.right, preset.width - ins.right + EPS)
                    self.assertLessEqual(box.bottom, preset.height - ins.bottom + EPS)

    def test_block_is_centered_in_safe_area(self):
        preset = presets.find("linkedin-banner")
        ins = presets.safe_insets(preset)
        result = layout_for(preset)
        safe_cx = ins.left + (preset.width - ins.left - ins.right) / 2
        safe_cy = ins.top + (preset.height - ins.top - ins.bottom) / 2
        self.assertAlmostEqual(result.block.center_x, safe_cx, places=6)
        self.assertAlmostEqual(result.block.center_y, safe_cy, places=6)

    def test_constrained_canvas_scales_down_instead_of_overflowing(self):
        ins = Insets(20, 20, 20, 20)
        result = compute_layout(600, 400, ins, "horizontal", True, fake_measure, 0.53)
        self.assertLess(result.icon.w, 0.53 * 400)
        self.assertLessEqual(result.block.w, 600 - 40 + EPS)

    def test_horizontal_puts_text_right_of_icon_and_centers_vertically(self):
        result = layout_for(presets.find("github-social"))
        gap = 64.0 * result.icon.w / layout.REF_ICON
        self.assertAlmostEqual(result.name.x, result.icon.right + gap, places=6)
        text_top = result.name.y
        text_bottom = result.slogan.bottom
        self.assertAlmostEqual((text_top + text_bottom) / 2, result.icon.center_y, places=6)
        self.assertAlmostEqual(result.rule.x, result.name.x, places=6)

    def test_stacked_puts_icon_above_centered_text(self):
        result = layout_for(presets.find("square"))
        self.assertLessEqual(result.icon.bottom, result.name.y + EPS)
        self.assertAlmostEqual(result.icon.center_x, result.block.center_x, places=6)
        self.assertAlmostEqual(result.name.center_x, result.block.center_x, places=6)
        self.assertAlmostEqual(result.rule.center_x, result.block.center_x, places=6)
        self.assertAlmostEqual(result.slogan.center_x, result.block.center_x, places=6)

    def test_wordmark_has_no_rule_or_slogan(self):
        result = layout_for(presets.find("wordmark-dark"))
        self.assertIsNone(result.rule)
        self.assertIsNone(result.slogan)
        self.assertIsNone(result.slogan_px)

    def test_unknown_layout_kind_raises(self):
        with self.assertRaises(ValueError):
            compute_layout(100, 100, Insets(0, 0, 0, 0), "diagonal", True, fake_measure, 0.5)

    def test_insets_leaving_no_room_raise(self):
        with self.assertRaises(ValueError):
            compute_layout(100, 100, Insets(60, 0, 60, 0), "horizontal", True, fake_measure, 0.5)


class PresetsTest(unittest.TestCase):
    def test_names_are_unique(self):
        names = [p.name for p in presets.PRESETS]
        self.assertEqual(len(names), len(set(names)))

    def test_expected_presets_exist_with_exact_sizes(self):
        expected = {
            "github-social": (1280, 640),
            "og-image": (1200, 630),
            "readme-banner": (2000, 500),
            "social-header": (1500, 500),
            "linkedin-banner": (1584, 396),
            "play-feature": (1024, 500),
            "website-hero": (1920, 640),
            "website-hero@2x": (3840, 1280),
            "square": (1080, 1080),
            "mark-256": (256, 256),
            "mark-512": (512, 512),
            "mark-1024": (1024, 1024),
        }
        for name, size in expected.items():
            with self.subTest(name=name):
                p = presets.find(name)
                self.assertEqual((p.width, p.height), size)
        for name in ("lockup-dark", "lockup-light", "wordmark-dark", "wordmark-light"):
            self.assertEqual(presets.find(name).kind, "transparent")

    def test_default_inset_is_one_eighth_of_height(self):
        ins = presets.safe_insets(presets.find("github-social"))
        self.assertEqual(ins, Insets(80, 80, 80, 80))

    def test_avatar_presets_widen_the_left_inset(self):
        self.assertEqual(presets.safe_insets(presets.find("social-header")).left, 300)
        self.assertEqual(presets.safe_insets(presets.find("linkedin-banner")).left, 400)

    def test_transparent_presets_use_the_lockup_margin(self):
        m = presets.LOCKUP_MARGIN
        self.assertEqual(presets.safe_insets(presets.find("lockup-dark")), Insets(m, m, m, m))

    def test_find_unknown_raises_key_error(self):
        with self.assertRaises(KeyError):
            presets.find("nope")

    def test_size_label(self):
        self.assertEqual(presets.size_label(presets.find("github-social")), "1280x640")
        self.assertEqual(presets.size_label(presets.find("lockup-dark")), "~2400 wide")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/.venv/bin/python scripts/brand/layout_test.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'layout'`.

- [ ] **Step 3: Implement layout.py**

Create `scripts/brand/layout.py`:

```python
"""Geometry for Submersion brand banners and lockups.

No Pillow import: text is measured through an injected callable, so the
layout rules are testable with a fake measurer. Every dimension is derived
from the icon size using the approved 1280x640 card's proportions, measured
between ink edges on that render. Text boxes are ink bounding boxes, so the
slogan's left and right ink edges line up exactly with the wordmark's.
"""

from dataclasses import dataclass

NAME = "Submersion"
SLOGAN = "Dive safe. Log everything."

# Reference proportions, in pixels, at a 340px icon on the approved card.
REF_ICON = 340.0
REF_NAME_PX = 116.0
REF_GAP_ICON_TEXT = 64.0
REF_GAP_NAME_RULE = 40.0
REF_RULE_W = 96.0
REF_RULE_H = 8.0
REF_GAP_RULE_SLOGAN = 46.0

# Font size used to probe the slogan's width before solving its real size.
SLOGAN_PROBE_PX = 100.0

LAYOUT_KINDS = ("horizontal", "stacked")
_MAX_FIT_PASSES = 50


@dataclass(frozen=True)
class Insets:
    left: float
    top: float
    right: float
    bottom: float


@dataclass(frozen=True)
class Box:
    x: float
    y: float
    w: float
    h: float

    @property
    def right(self):
        return self.x + self.w

    @property
    def bottom(self):
        return self.y + self.h

    @property
    def center_x(self):
        return self.x + self.w / 2

    @property
    def center_y(self):
        return self.y + self.h / 2


@dataclass(frozen=True)
class Layout:
    icon: Box
    name: Box
    name_px: float
    rule: Box | None
    slogan: Box | None
    slogan_px: float | None
    block: Box


@dataclass(frozen=True)
class _Text:
    """Measured text column at one icon size."""

    unit: float
    name_px: float
    name_w: float
    name_h: float
    slogan_px: float | None
    slogan_w: float
    slogan_h: float

    @property
    def width(self):
        return max(self.name_w, self.slogan_w)

    @property
    def height(self):
        if self.slogan_px is None:
            return self.name_h
        u = self.unit
        return (
            self.name_h
            + (REF_GAP_NAME_RULE + REF_RULE_H + REF_GAP_RULE_SLOGAN) * u
            + self.slogan_h
        )


def _measure_text(icon, show_slogan, measure):
    unit = icon / REF_ICON
    name_px = REF_NAME_PX * unit
    name_w, name_h = measure(NAME, "name", name_px)
    if not show_slogan:
        return _Text(unit, name_px, name_w, name_h, None, 0.0, 0.0)
    probe_w, _ = measure(SLOGAN, "slogan", SLOGAN_PROBE_PX)
    slogan_px = SLOGAN_PROBE_PX * name_w / probe_w
    slogan_w, slogan_h = measure(SLOGAN, "slogan", slogan_px)
    return _Text(unit, name_px, name_w, name_h, slogan_px, slogan_w, slogan_h)


def _block_size(kind, icon, text):
    gap = REF_GAP_ICON_TEXT * text.unit
    if kind == "horizontal":
        return icon + gap + text.width, max(icon, text.height)
    return max(icon, text.width), icon + gap + text.height


def compute_layout(width, height, insets, kind, show_slogan, measure, icon_ratio):
    """Place the icon, name, rule and slogan inside the canvas safe area.

    The icon starts at icon_ratio * height; the whole block shrinks by one
    scale factor until it fits the safe area, then is centered in it.
    """
    if kind not in LAYOUT_KINDS:
        raise ValueError(f"unknown layout kind {kind!r}; expected one of {LAYOUT_KINDS}")
    safe = Box(
        insets.left,
        insets.top,
        width - insets.left - insets.right,
        height - insets.top - insets.bottom,
    )
    if safe.w <= 0 or safe.h <= 0:
        raise ValueError(f"insets {insets} leave no room on a {width}x{height} canvas")

    icon = icon_ratio * height
    for _ in range(_MAX_FIT_PASSES):
        text = _measure_text(icon, show_slogan, measure)
        block_w, block_h = _block_size(kind, icon, text)
        factor = min(safe.w / block_w, safe.h / block_h)
        if factor >= 1.0:
            break
        # A hair under the exact ratio so rounding in real font metrics
        # cannot leave the block a fraction of a pixel too large.
        icon *= factor * 0.999
    else:
        raise ValueError(f"could not fit the block into a {width}x{height} canvas")

    return _place(kind, safe, icon, text, block_w, block_h)


def _place(kind, safe, icon, text, block_w, block_h):
    u = text.unit
    x0 = safe.x + (safe.w - block_w) / 2
    y0 = safe.y + (safe.h - block_h) / 2
    block = Box(x0, y0, block_w, block_h)
    gap = REF_GAP_ICON_TEXT * u

    if kind == "horizontal":
        icon_box = Box(x0, y0 + (block_h - icon) / 2, icon, icon)
        text_x = x0 + icon + gap
        text_y = y0 + (block_h - text.height) / 2

        def align(w):
            return text_x
    else:
        icon_box = Box(x0 + (block_w - icon) / 2, y0, icon, icon)
        text_y = y0 + icon + gap

        def align(w):
            return x0 + (block_w - w) / 2

    name = Box(align(text.name_w), text_y, text.name_w, text.name_h)
    if text.slogan_px is None:
        return Layout(icon_box, name, text.name_px, None, None, None, block)

    rule_w, rule_h = REF_RULE_W * u, REF_RULE_H * u
    rule = Box(align(rule_w), name.bottom + REF_GAP_NAME_RULE * u, rule_w, rule_h)
    slogan = Box(
        align(text.slogan_w),
        rule.bottom + REF_GAP_RULE_SLOGAN * u,
        text.slogan_w,
        text.slogan_h,
    )
    return Layout(icon_box, name, text.name_px, rule, slogan, text.slogan_px, block)
```

- [ ] **Step 4: Implement presets.py**

Create `scripts/brand/presets.py`:

```python
"""Every image generate_brand_assets.py can render.

Adding a destination is one new Preset entry. Sizes are pixels. Banners are
drawn on the teal background; transparent presets are lockups cropped to
their content; marks are the bare logo glyph.
"""

from dataclasses import dataclass

from layout import Insets

DEFAULT_INSET_RATIO = 0.125  # 80px on the 640px-high card (GitHub's 40pt border)
LOCKUP_MARGIN = 48

RULE_COLOR = (200, 0, 0)  # #C80000, dive-flag red
THEMES = {
    # Navy text, for light backgrounds (and the teal banners).
    "dark": ((6, 48, 60), (11, 68, 82)),
    # White text, for dark backgrounds.
    "light": ((255, 255, 255), (230, 248, 250)),
}


@dataclass(frozen=True)
class Preset:
    name: str
    width: int
    height: int
    kind: str  # "banner" | "transparent" | "mark"
    layout: str  # "horizontal" | "stacked" | "none"
    purpose: str
    theme: str = "dark"
    show_slogan: bool = True
    icon_ratio: float = 0.53
    left_inset: float | None = None


def _banner(name, width, height, purpose, **kw):
    return Preset(name, width, height, "banner", "horizontal", purpose, **kw)


def _lockup(name, purpose, **kw):
    # A square working canvas with icon_ratio 1.0 forces the layout to be
    # width-bound, so the lockup comes out close to 2400px wide before cropping.
    return Preset(name, 2400, 2400, "transparent", "horizontal", purpose, icon_ratio=1.0, **kw)


def _mark(size):
    return Preset(f"mark-{size}", size, size, "mark", "none", "Transparent logo mark, no tile")


PRESETS = (
    _banner("github-social", 1280, 640, "GitHub repository social preview"),
    _banner("og-image", 1200, 630, "Website and docs link previews (Open Graph, Twitter card)"),
    _banner("readme-banner", 2000, 500, "README banner, 4:1 for high-density screens"),
    _banner("social-header", 1500, 500, "X/Twitter and Mastodon profile header", left_inset=300),
    _banner("linkedin-banner", 1584, 396, "LinkedIn banner", left_inset=400),
    _banner("play-feature", 1024, 500, "Google Play feature graphic"),
    _banner("website-hero", 1920, 640, "Website home page hero"),
    _banner("website-hero@2x", 3840, 1280, "Website home page hero, 2x"),
    Preset("square", 1080, 1080, "banner", "stacked", "Square social posts", icon_ratio=0.36),
    _mark(256),
    _mark(512),
    _mark(1024),
    _lockup("lockup-dark", "Transparent lockup, navy text for light backgrounds"),
    _lockup("lockup-light", "Transparent lockup, white text for dark backgrounds", theme="light"),
    _lockup("wordmark-dark", "Transparent icon and name, navy text", show_slogan=False),
    _lockup(
        "wordmark-light",
        "Transparent icon and name, white text",
        theme="light",
        show_slogan=False,
    ),
)

_BY_NAME = {p.name: p for p in PRESETS}


def find(name):
    """Return the preset called name; raises KeyError if there is none."""
    return _BY_NAME[name]


def safe_insets(preset):
    if preset.kind == "transparent":
        m = LOCKUP_MARGIN
        return Insets(m, m, m, m)
    d = preset.height * DEFAULT_INSET_RATIO
    left = preset.left_inset if preset.left_inset is not None else d
    return Insets(left, d, d, d)


def size_label(preset):
    if preset.kind == "transparent":
        return f"~{preset.width} wide"
    return f"{preset.width}x{preset.height}"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `scripts/.venv/bin/python scripts/brand/layout_test.py -v`
Expected: all tests PASS. Also confirm these modules import without Pillow: `python3.14 -S -c "import sys; sys.path.insert(0,'scripts/brand'); import layout, presets"` exits 0 (the `-S` flag skips site-packages, so Pillow is unavailable).

- [ ] **Step 6: Commit**

```bash
git add scripts/brand/layout.py scripts/brand/presets.py scripts/brand/layout_test.py
git commit -m "feat(brand): layout geometry and preset table for brand images

Pure, Pillow-free layout: every dimension derives from the icon size using
the approved social card's proportions, the slogan is sized to the
wordmark's ink width, and one scale factor shrinks the block until it fits
the safe area. Presets cover link previews, README, social headers, Play
Store, website, square posts, transparent lockups, wordmarks and marks."
```

---

### Task 3: Transparent logo mark

**Files:**
- Create: `scripts/brand/mark.py`
- Test: `scripts/brand/generate_brand_assets_test.py` (mark tests only in this task)

**Interfaces:**
- Consumes: `generate_icon.SUPERSAMPLE`, `generate_icon.build_flag(size)`, `generate_icon.build_wave_arrow_mask(size)`.
- Produces: `mark.render_glyph(size) -> Image` (RGBA, glyph in app-icon coordinates on a transparent size x size canvas) and `mark.create_mark(size) -> Image` (RGBA, glyph cropped and centered with 4% padding).

- [ ] **Step 1: Write the failing tests**

Create `scripts/brand/generate_brand_assets_test.py`:

```python
#!/usr/bin/env python3
"""Tests for the brand image renderer, the transparent mark, and the CLI.

Run: python3 scripts/brand/generate_brand_assets_test.py

Needs Pillow (pip install -r scripts/requirements.txt). Deliberately fails
rather than skips without it, so CI cannot go green having tested nothing.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image, ImageChops, ImageFilter, ImageStat  # noqa: E402

from generate_icon import build_wave_arrow_mask  # noqa: E402
from mark import create_mark, render_glyph  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
ICON_PNG = os.path.join(REPO, "assets", "icon", "icon.png")


def teal_pixel_count(img):
    """Opaque pixels in the tile's cyan-teal family (low red, high green and blue)."""
    return sum(
        1
        for r, g, b, a in img.getdata()
        if a > 200 and r < 120 and g > 150 and b > 150
    )


class MarkTest(unittest.TestCase):
    def test_mark_is_square_with_clear_corners(self):
        mark = create_mark(256)
        self.assertEqual(mark.size, (256, 256))
        self.assertEqual(mark.mode, "RGBA")
        for xy in ((0, 0), (255, 0), (0, 255), (255, 255)):
            self.assertEqual(mark.getpixel(xy)[3], 0, xy)

    def test_mark_is_centered_and_nearly_fills_the_canvas(self):
        mark = create_mark(512)
        left, top, right, bottom = mark.getchannel("A").getbbox()
        self.assertAlmostEqual((left + right) / 2, 256, delta=3)
        self.assertAlmostEqual((top + bottom) / 2, 256, delta=3)
        self.assertGreater(max(right - left, bottom - top), 512 * 0.88)

    def test_mark_has_no_tile_teal(self):
        self.assertEqual(teal_pixel_count(create_mark(512)), 0)

    def test_glyph_matches_the_committed_app_icon(self):
        # Drift guard: mark.py copies the outline and edge-lighting steps of
        # generate_icon.apply_depth_effects. Inside the glyph (eroded 2px to
        # stay clear of anti-aliased edges) the flag pixels, including the
        # edge lighting that bleeds inward, must match icon.png.
        glyph = render_glyph(1024).convert("RGB")
        icon = Image.open(ICON_PNG).convert("RGB")
        inside = build_wave_arrow_mask(1024).filter(ImageFilter.MinFilter(5))
        diff = ImageStat.Stat(ImageChops.difference(glyph, icon), mask=inside)
        for channel_mean in diff.mean:
            self.assertLess(channel_mean, 3.0)

    def test_glyph_keeps_the_white_outline(self):
        # The 1px ring just outside the glyph is the icon's white outline: it
        # must be opaque and white in the mark, not transparent or red.
        glyph = render_glyph(1024)
        mask = build_wave_arrow_mask(1024)
        ring = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(3)), mask)
        ring = ring.point(lambda v: 255 if v > 128 else 0)
        self.assertGreater(ImageStat.Stat(glyph.getchannel("A"), mask=ring).mean[0], 200)
        for channel_mean in ImageStat.Stat(glyph.convert("RGB"), mask=ring).mean:
            self.assertGreater(channel_mean, 170)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'mark'`.

- [ ] **Step 3: Implement mark.py**

Create `scripts/brand/mark.py`:

```python
"""The Submersion logo mark on a transparent background.

The dive-flag waves and arrow, without the app icon's teal tile or drop
shadow (a translucent black shadow reads as a smudge on dark backgrounds).
The white outline and edge lighting stay, so the mark reads on any
background.

Geometry comes from generate_icon.py's own primitives, so the shape cannot
diverge from the icon. The outline and edge-lighting steps are a copy of the
matching parts of generate_icon.apply_depth_effects, which always draws the
drop shadow; generate_brand_assets_test.py compares the result against
assets/icon/icon.png to catch the copy drifting.
"""

from PIL import Image, ImageChops, ImageFilter

from generate_icon import SUPERSAMPLE, build_flag, build_wave_arrow_mask

MARK_PADDING = 0.04


def _solid(size, color):
    return Image.new("RGBA", size, color)


def _edge_band(mask, outside, dy, blur):
    """The mask shifted by dy, limited to outside the glyph, then blurred."""
    band = Image.new("L", mask.size, 0)
    band.paste(mask, (0, dy))
    band = ImageChops.multiply(band, outside)
    return band.filter(ImageFilter.GaussianBlur(blur))


def _render_glyph_hi(hi):
    size = (hi, hi)
    mask = build_wave_arrow_mask(hi)
    flag = build_flag(hi)
    img = _solid(size, (0, 0, 0, 0))

    # White outline via mask dilation.
    expanded = mask
    for _ in range(4):
        expanded = expanded.filter(ImageFilter.MaxFilter(5))
    outline = _solid(size, (0, 0, 0, 0))
    outline.paste(_solid(size, (255, 255, 255, 255)), (0, 0), expanded)
    img = Image.alpha_composite(img, outline)

    # Dive flag pattern, cut to the waves and arrow.
    img.paste(flag, (0, 0), mask)

    # Edge lighting: highlight above top edges, shadow below bottom edges.
    offset = int(hi * 0.006)
    blur = int(hi * 0.012)
    outside = mask.point(lambda v: 0 if v > 0 else 255)
    for color, dy in (((255, 255, 255, 80), -offset), ((0, 0, 0, 60), offset)):
        layer = _solid(size, (0, 0, 0, 0))
        layer.paste(_solid(size, color), (0, 0), _edge_band(mask, outside, dy, blur))
        img = Image.alpha_composite(img, layer)
    return img


def render_glyph(size):
    """The glyph where it sits in the app icon, on a transparent square."""
    hi = size * SUPERSAMPLE
    return _render_glyph_hi(hi).resize((size, size), Image.Resampling.LANCZOS)


def create_mark(size):
    """The glyph cropped to its bounds and centered with a small padding."""
    hi = size * SUPERSAMPLE
    glyph = _render_glyph_hi(hi)
    glyph = glyph.crop(glyph.getchannel("A").getbbox())
    scale = hi * (1 - 2 * MARK_PADDING) / max(glyph.size)
    glyph = glyph.resize(
        (round(glyph.width * scale), round(glyph.height * scale)),
        Image.Resampling.LANCZOS,
    )
    canvas = _solid((hi, hi), (0, 0, 0, 0))
    canvas.paste(glyph, ((hi - glyph.width) // 2, (hi - glyph.height) // 2))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py -v`
Expected: 5 tests PASS. If `test_glyph_matches_the_committed_app_icon` fails, print `diff.mean` and inspect before touching the tolerance: a large difference means the copied steps diverge from `apply_depth_effects`.

- [ ] **Step 5: Mutation-check the drift guard**

Back up first: `cp scripts/brand/mark.py "$SCRATCH/mark.py.bak"` (mark.py is uncommitted, so restore with `cp`, never `git checkout`). Then run two mutations, one at a time, restoring between them:

1. Outline loop `range(4)` to `range(0)`: `test_glyph_keeps_the_white_outline` must FAIL.
2. In `_render_glyph_hi`, paste a recolored flag (`flag = Image.new("RGBA", size, (150, 0, 0, 255))` right after `flag = build_flag(hi)`): `test_glyph_matches_the_committed_app_icon` must FAIL.

Restore with `cp "$SCRATCH/mark.py.bak" scripts/brand/mark.py` and re-run: all PASS. If a mutation does not fail its test, the guard is not protecting anything; fix the test before continuing.

- [ ] **Step 6: Commit**

```bash
git add scripts/brand/mark.py scripts/brand/generate_brand_assets_test.py
git commit -m "feat(brand): transparent logo mark built from the icon's primitives

The dive-flag waves and arrow without the teal tile or drop shadow, keeping
the white outline and edge lighting. Geometry reuses generate_icon.py; a
test compares the glyph against the committed icon.png to catch the copied
outline and lighting steps drifting."
```

---

### Task 4: Renderer and CLI

**Files:**
- Create: `scripts/brand/generate_brand_assets.py`
- Test: `scripts/brand/generate_brand_assets_test.py` (append render and CLI tests)

**Interfaces:**
- Consumes: `layout.compute_layout`, `layout.NAME`, `layout.SLOGAN`, `layout.REF_ICON`, `presets.PRESETS`, `presets.find`, `presets.safe_insets`, `presets.size_label`, `presets.THEMES`, `presets.RULE_COLOR`, `presets.LOCKUP_MARGIN`, `mark.create_mark`, `generate_icon.create_icon`.
- Produces: `generate_brand_assets.render(preset) -> Image` (RGB for banners, RGBA otherwise), `generate_brand_assets.measure(text, role, px) -> (w, h)`, `generate_brand_assets.main(argv=None) -> int`, module globals `FONT_DIR`, `DEFAULT_OUT`, `FONT_FILES`.

- [ ] **Step 1: Append the failing tests**

In `scripts/brand/generate_brand_assets_test.py`, add these imports after the existing `from mark import ...` line:

```python
import contextlib  # noqa: E402
import io  # noqa: E402
import tempfile  # noqa: E402

import generate_brand_assets as gen  # noqa: E402
import presets  # noqa: E402
```

and add these classes above `if __name__ == "__main__":`:

```python
class RenderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.images = {p.name: gen.render(p) for p in presets.PRESETS}

    def test_banners_and_marks_render_at_exact_size(self):
        for p in presets.PRESETS:
            if p.kind == "transparent":
                continue
            with self.subTest(preset=p.name):
                self.assertEqual(self.images[p.name].size, (p.width, p.height))

    def test_transparent_lockups_are_about_2400_wide(self):
        for p in presets.PRESETS:
            if p.kind != "transparent":
                continue
            with self.subTest(preset=p.name):
                self.assertGreaterEqual(self.images[p.name].width, 2300)
                self.assertLessEqual(self.images[p.name].width, 2400)

    def test_banners_are_opaque(self):
        for p in presets.PRESETS:
            if p.kind == "banner":
                with self.subTest(preset=p.name):
                    self.assertEqual(self.images[p.name].mode, "RGB")

    def test_transparent_presets_have_clear_corners_and_content(self):
        for p in presets.PRESETS:
            if p.kind == "banner":
                continue
            with self.subTest(preset=p.name):
                img = self.images[p.name]
                self.assertEqual(img.mode, "RGBA")
                w, h = img.size
                for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
                    self.assertEqual(img.getpixel(xy)[3], 0, xy)
                self.assertIsNotNone(img.getchannel("A").getbbox())

    def test_lockup_themes_differ_only_in_text(self):
        dark = self.images["lockup-dark"]
        light = self.images["lockup-light"]
        self.assertEqual(dark.size, light.size)
        icon_strip = (0, 0, int(dark.width * 0.25), dark.height)
        self.assertIsNone(
            ImageChops.difference(dark.crop(icon_strip), light.crop(icon_strip)).getbbox()
        )
        text_half = (dark.width // 2, 0, dark.width, dark.height)
        dark_text = dark.crop(text_half)
        light_text = light.crop(text_half)
        # Darkest opaque text pixel is navy in one and near-white in the other.
        dark_min = min(sum(px[:3]) for px in dark_text.getdata() if px[3] == 255)
        light_min = min(sum(px[:3]) for px in light_text.getdata() if px[3] == 255)
        self.assertLess(dark_min, 3 * 90)
        self.assertGreater(light_min, 3 * 200)

    def test_wordmark_is_shorter_than_lockup(self):
        self.assertLess(self.images["wordmark-dark"].height, self.images["lockup-dark"].height)


class CliTest(unittest.TestCase):
    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = gen.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_list_prints_every_preset(self):
        code, out, _ = self.run_main("--list")
        self.assertEqual(code, 0)
        for p in presets.PRESETS:
            self.assertIn(p.name, out)
        self.assertIn("1280x640", out)

    def test_only_renders_the_requested_subset(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, _, _ = self.run_main("--only", "mark-256,github-social", "--out", tmp)
            self.assertEqual(code, 0)
            self.assertEqual(sorted(os.listdir(tmp)), ["github-social.png", "mark-256.png"])
            with Image.open(os.path.join(tmp, "github-social.png")) as img:
                self.assertEqual(img.size, (1280, 640))

    def test_unknown_preset_exits_nonzero_and_lists_valid_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, _, err = self.run_main("--only", "nope", "--out", tmp)
            self.assertEqual(code, 2)
            self.assertIn("nope", err)
            self.assertIn("github-social", err)
            self.assertEqual(os.listdir(tmp), [])

    def test_missing_font_exits_nonzero_naming_the_file(self):
        saved = gen.FONT_DIR
        with tempfile.TemporaryDirectory() as fonts, tempfile.TemporaryDirectory() as tmp:
            gen.FONT_DIR = fonts
            try:
                code, _, err = self.run_main("--only", "github-social", "--out", tmp)
            finally:
                gen.FONT_DIR = saved
            self.assertEqual(code, 2)
            self.assertIn("InterDisplay-ExtraBold.ttf", err)

    def test_missing_raqm_exits_nonzero_with_install_hint(self):
        saved = gen.raqm_available
        with tempfile.TemporaryDirectory() as tmp:
            gen.raqm_available = lambda: False
            try:
                code, _, err = self.run_main("--only", "github-social", "--out", tmp)
            finally:
                gen.raqm_available = saved
            self.assertEqual(code, 2)
            self.assertIn("fribidi", err)
            self.assertEqual(os.listdir(tmp), [])

    def test_marks_render_without_raqm(self):
        saved = gen.raqm_available
        with tempfile.TemporaryDirectory() as tmp:
            gen.raqm_available = lambda: False
            try:
                code, _, _ = self.run_main("--only", "mark-256", "--out", tmp)
            finally:
                gen.raqm_available = saved
            self.assertEqual(code, 0)
            self.assertEqual(os.listdir(tmp), ["mark-256.png"])

    def test_raqm_is_available_for_text(self):
        # Guards the environment: without RAQM, Inter's GPOS kerning is lost.
        self.assertTrue(gen.raqm_available(), "install fribidi (see README.md)")

    def test_default_output_folder_is_gitignored(self):
        self.assertEqual(gen.DEFAULT_OUT, os.path.join(HERE, "out"))
        with open(os.path.join(REPO, ".gitignore"), encoding="utf-8") as f:
            self.assertIn("scripts/brand/out/", f.read().splitlines())
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'generate_brand_assets'`.

- [ ] **Step 3: Implement generate_brand_assets.py**

Create `scripts/brand/generate_brand_assets.py`:

```python
#!/usr/bin/env python3
"""Generate Submersion brand images: banners, transparent lockups and marks.

Usage:
  python3 scripts/brand/generate_brand_assets.py              # every preset
  python3 scripts/brand/generate_brand_assets.py --list
  python3 scripts/brand/generate_brand_assets.py --only github-social,mark-512
  python3 scripts/brand/generate_brand_assets.py --out /path/to/dir

Writes <out>/<preset>.png; the default output folder scripts/brand/out/ is
gitignored. Needs Pillow: pip install -r scripts/requirements.txt. Presets
are defined in presets.py; see README.md in this folder.
"""

import argparse
import functools
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont, features
except ImportError:
    sys.exit("Pillow is required: pip install -r scripts/requirements.txt")

import presets
from generate_icon import create_icon
from layout import NAME, REF_ICON, SLOGAN, compute_layout
from mark import create_mark

BRAND_DIR = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(BRAND_DIR, "fonts")
DEFAULT_OUT = os.path.join(BRAND_DIR, "out")
FONT_FILES = {"name": "InterDisplay-ExtraBold.ttf", "slogan": "InterDisplay-Medium.ttf"}

# The approved card's background: 160 degrees, three stops.
GRADIENT_ANGLE = 160
GRADIENT_STOPS = ((0.0, (79, 233, 253)), (0.45, (64, 211, 224)), (1.0, (47, 180, 170)))

# Decorative waves in the approved card's 1280x640 coordinates:
# (baseline y, amplitude, period) for the two filled bands and the thin line.
WAVE_BANDS = ((520, 30, 640), (570, 26, 640))
WAVE_LINE = (90, 22, 640)
WAVE_FILL = (255, 255, 255, 26)  # 10% white
WAVE_STROKE = (255, 255, 255, 41)  # 16% white
WAVE_STROKE_W = 3

# Icon drop shadow at the 340px reference icon: (y offset, blur, opacity).
ICON_SHADOWS = ((22, 17, 0.38), (4, 4, 0.22))
SHADOW_RGB = (0, 62, 72)

# Inter keeps its kerning only in the GPOS table, which Pillow's BASIC layout
# ignores; RAQM (libraqm plus the system libfribidi) is required for text.
RAQM_HINT = (
    "Pillow's RAQM text layout is unavailable, so Inter's kerning would be lost. "
    "Install fribidi: `brew install fribidi` (macOS) or "
    "`sudo apt-get install libfribidi0` (Debian/Ubuntu)."
)


def raqm_available():
    return features.check("raqm")


def _font_path(role):
    return os.path.join(FONT_DIR, FONT_FILES[role])


@functools.lru_cache(maxsize=None)
def _font(path, px):
    return ImageFont.truetype(path, px, layout_engine=ImageFont.Layout.RAQM)


def measure(text, role, px):
    """Ink width and height of text at px, for layout.compute_layout."""
    left, top, right, bottom = _font(_font_path(role), px).getbbox(text)
    return right - left, bottom - top


def _color_at(t):
    t = min(1.0, max(0.0, t))
    for (t0, c0), (t1, c1) in zip(GRADIENT_STOPS, GRADIENT_STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
    return GRADIENT_STOPS[-1][1]


def _background(width, height):
    """CSS-style angled linear gradient, computed small and scaled up.

    A linear gradient is reproduced exactly by bilinear upscaling, so an
    eighth-size render keeps this fast even for the 3840px hero.
    """
    sw, sh = max(2, width // 8), max(2, height // 8)
    angle = math.radians(GRADIENT_ANGLE)
    dx, dy = math.sin(angle), -math.cos(angle)
    length = abs(sw * dx) + abs(sh * dy)
    small = Image.new("RGB", (sw, sh))
    px = small.load()
    for y in range(sh):
        for x in range(sw):
            t = ((x + 0.5 - sw / 2) * dx + (y + 0.5 - sh / 2) * dy) / length + 0.5
            px[x, y] = _color_at(t)
    return small.resize((width, height), Image.Resampling.BILINEAR).convert("RGBA")


def _wave_points(width, sx, sy, base, amp, period, ss):
    steps = max(2, int(width / 4))
    return [
        (
            i * width / steps * ss,
            (base - amp * math.sin(2 * math.pi * (i * width / steps) / (period * sx))) * sy * ss,
        )
        for i in range(steps + 1)
    ]


def _waves(width, height):
    """The decorative wave bands and line, drawn at 2x for smooth edges."""
    ss = 2
    sx, sy = width / 1280, height / 640
    layer = Image.new("RGBA", (width * ss, height * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for base, amp, period in WAVE_BANDS:
        top = _wave_points(width, sx, sy, base, amp, period, ss)
        draw.polygon(top + [(width * ss, height * ss), (0, height * ss)], fill=WAVE_FILL)
    base, amp, period = WAVE_LINE
    draw.line(
        _wave_points(width, sx, sy, base, amp, period, ss),
        fill=WAVE_STROKE,
        width=max(1, round(WAVE_STROKE_W * sy * ss)),
        joint="curve",
    )
    return layer.resize((width, height), Image.Resampling.LANCZOS)


@functools.lru_cache(maxsize=None)
def _icon(px):
    return create_icon(px)


def _icon_shadow(size, icon_img, x, y):
    scale = icon_img.width / REF_ICON
    alpha = icon_img.getchannel("A")
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    for dy, blur, opacity in ICON_SHADOWS:
        mask = Image.new("L", size, 0)
        mask.paste(alpha.point(lambda v, o=opacity: round(v * o)), (x, round(y + dy * scale)))
        layer = Image.new("RGBA", size, SHADOW_RGB + (255,))
        layer.putalpha(mask.filter(ImageFilter.GaussianBlur(blur * scale)))
        shadow = Image.alpha_composite(shadow, layer)
    return shadow


def _draw_text(draw, box, text, role, px, color):
    font = _font(_font_path(role), px)
    left, top, _, _ = font.getbbox(text)
    draw.text((box.x - left, box.y - top), text, font=font, fill=color)


def render(preset):
    """Render one preset to a Pillow image (RGB for banners, RGBA otherwise)."""
    if preset.kind == "mark":
        return create_mark(preset.width)

    lay = compute_layout(
        preset.width,
        preset.height,
        presets.safe_insets(preset),
        preset.layout,
        preset.show_slogan,
        measure,
        preset.icon_ratio,
    )
    size = (preset.width, preset.height)
    banner = preset.kind == "banner"
    if banner:
        canvas = Image.alpha_composite(_background(*size), _waves(*size))
    else:
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))

    icon_img = _icon(round(lay.icon.w))
    x, y = round(lay.icon.x), round(lay.icon.y)
    if banner:
        canvas = Image.alpha_composite(canvas, _icon_shadow(size, icon_img, x, y))
    canvas.alpha_composite(icon_img, (x, y))

    name_color, slogan_color = presets.THEMES[preset.theme]
    draw = ImageDraw.Draw(canvas)
    _draw_text(draw, lay.name, NAME, "name", lay.name_px, name_color)
    if lay.slogan is not None:
        r = lay.rule
        draw.rounded_rectangle(
            (r.x, r.y, r.right, r.bottom), radius=r.h / 2, fill=presets.RULE_COLOR
        )
        _draw_text(draw, lay.slogan, SLOGAN, "slogan", lay.slogan_px, slogan_color)

    if banner:
        return canvas.convert("RGB")
    m = presets.LOCKUP_MARGIN
    b = lay.block
    return canvas.crop(
        (round(b.x - m), round(b.y - m), round(b.right + m), round(b.bottom + m))
    )


def _parse_args(argv):
    parser = argparse.ArgumentParser(description="Generate Submersion brand images.")
    parser.add_argument("--list", action="store_true", help="list presets and exit")
    parser.add_argument("--only", help="comma-separated preset names to render")
    parser.add_argument("--out", default=DEFAULT_OUT, help="output directory")
    return parser.parse_args(argv)


def _select(only):
    if not only:
        return list(presets.PRESETS), []
    names = [n.strip() for n in only.split(",") if n.strip()]
    known = {p.name for p in presets.PRESETS}
    unknown = [n for n in names if n not in known]
    return [presets.find(n) for n in names if n in known], unknown


def main(argv=None):
    args = _parse_args(argv)
    if args.list:
        for p in presets.PRESETS:
            print(f"{p.name:<18} {presets.size_label(p):<12} {p.purpose}")
        return 0

    selected, unknown = _select(args.only)
    if unknown:
        valid = ", ".join(p.name for p in presets.PRESETS)
        print(f"unknown preset(s): {', '.join(unknown)}. Valid: {valid}", file=sys.stderr)
        return 2

    if any(p.kind != "mark" for p in selected):
        if not raqm_available():
            print(RAQM_HINT, file=sys.stderr)
            return 2
        for role in FONT_FILES:
            path = _font_path(role)
            if not os.path.isfile(path):
                print(f"missing font file: {path}", file=sys.stderr)
                return 2

    os.makedirs(args.out, exist_ok=True)
    for p in selected:
        img = render(p)
        path = os.path.join(args.out, f"{p.name}.png")
        img.save(path, optimize=True)
        print(f"  {path} ({img.width}x{img.height})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run all brand tests to verify they pass**

Run:

```bash
scripts/.venv/bin/python scripts/brand/layout_test.py
time scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py -v
```

Expected: all PASS. Record the wall time of the second command for the report.

- [ ] **Step 5: Generate everything and inspect it**

```bash
time scripts/.venv/bin/python scripts/brand/generate_brand_assets.py
```

Expected: 16 files listed, and the wall time recorded. Open every PNG in `scripts/brand/out/` with the Read tool and check: text is crisp and inside the safe area, the red rule sits under the name's left edge (horizontal) or centered (square), the slogan spans exactly the name's width, the icon shadow is soft teal (not grey), the waves match the approved card, and transparent images have no background.

Compare `github-social.png` with the approved prototype `submersion-social-preview-oneline.png` in the session scratchpad. If the spacing looks off compared with the approved render, adjust only the `REF_GAP_*` constants in `layout.py` (they were measured by eye from the approved render), re-run both test files, and regenerate.

- [ ] **Step 6: Commit**

```bash
git add scripts/brand/generate_brand_assets.py scripts/brand/generate_brand_assets_test.py
git commit -m "feat(brand): render brand banners, lockups and marks from code

generate_brand_assets.py draws every preset with Pillow and the bundled
Inter Display fonts: the approved teal card with its waves and icon shadow
for banners, cropped transparent lockups and wordmarks in navy or white
text, and the transparent mark. --list, --only and --out control what is
rendered and where; output defaults to the gitignored scripts/brand/out/."
```

---

### Task 5: CI wiring and README

**Files:**
- Modify: `.github/workflows/ci.yaml` (script-tests job, after the "Run dive site harvester tests" step)
- Create: `scripts/brand/README.md`

**Interfaces:**
- Consumes: the two test files from Tasks 2 to 4.

- [ ] **Step 1: Add the CI step**

In `.github/workflows/ci.yaml`, in the `script-tests` job, insert after the `Run dive site harvester tests` step (before `Run appcast beta feed test`):

```yaml
      - name: Run brand asset generator tests
        # The generator draws the social card, banners, lockups and logo mark
        # from code. Pillow is installed with the same retry as coverage.py;
        # the tests fail rather than skip without it, so this step cannot go
        # green having tested nothing. Text needs Pillow's RAQM layout, which
        # loads the system libfribidi; install it if the runner lacks it.
        # layout_test.py needs no Pillow.
        run: |
          for attempt in 1 2 3; do
            if python3 -m pip install 'Pillow>=10.1'; then
              break
            fi
            echo "::warning::pip install Pillow failed (attempt $attempt/3)"
            if [ "$attempt" -lt 3 ]; then
              sleep $((attempt * 10))
            else
              echo "::error::pip install Pillow failed after 3 attempts"
              exit 1
            fi
          done
          if ! python3 -c "from PIL import features; raise SystemExit(not features.check('raqm'))"; then
            sudo apt-get update
            sudo apt-get install -y libfribidi0
          fi
          python3 scripts/brand/layout_test.py
          python3 scripts/brand/generate_brand_assets_test.py
```

- [ ] **Step 2: Validate the workflow file parses**

```bash
scripts/.venv/bin/python -c "import sys; print(sys.version)"
python3.14 -c "import yaml" 2>/dev/null && python3.14 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml')); print('ci.yaml OK')" || ruby -ryaml -e "YAML.load_file('.github/workflows/ci.yaml'); puts 'ci.yaml OK'"
python3 scripts/check_ci_success_gate.py
```

Expected: `ci.yaml OK`, and the CI aggregation gate passes (no new job was added, only a step).

- [ ] **Step 3: Write the README**

Create `scripts/brand/README.md`:

````markdown
# Brand assets

Code that draws the Submersion logo and brand images. Nothing generated here
is committed; run the scripts to get fresh PNGs.

## Setup

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install -r scripts/requirements.txt
```

Python 3.10 or newer. Text rendering needs Pillow's RAQM layout, which loads
the system fribidi library: `brew install fribidi` on macOS, `sudo apt-get
install libfribidi0` on Debian/Ubuntu. Without it the generator stops with
that message rather than drawing un-kerned text.

## App icon

`generate_icon.py` draws the app icon and writes it into `assets/icon/`,
which `flutter_launcher_icons.yaml` then fans out to every platform.

```bash
scripts/.venv/bin/python scripts/brand/generate_icon.py
```

## Banners, lockups and marks

```bash
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py          # all presets
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py --list   # what exists
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py --only github-social
```

Output goes to `scripts/brand/out/` (gitignored); `--out` picks another folder.

| Preset | Size | Use |
| --- | --- | --- |
| `github-social` | 1280x640 | Repository Settings > General > Social preview |
| `og-image` | 1200x630 | Website and docs link previews (Open Graph, Twitter card) |
| `readme-banner` | 2000x500 | README banner |
| `social-header` | 1500x500 | X/Twitter and Mastodon profile header |
| `linkedin-banner` | 1584x396 | LinkedIn banner |
| `play-feature` | 1024x500 | Google Play feature graphic |
| `website-hero`, `website-hero@2x` | 1920x640, 3840x1280 | Website home page hero |
| `square` | 1080x1080 | Square social posts |
| `mark-256`, `mark-512`, `mark-1024` | square | Logo glyph only, transparent |
| `lockup-dark`, `lockup-light` | ~2400 wide | Icon, name, rule and slogan on transparency; navy or white text |
| `wordmark-dark`, `wordmark-light` | ~2400 wide | Icon and name on transparency; navy or white text |

"dark" and "light" name the text color: dark text for light backgrounds,
light text for dark backgrounds.

## Adding a preset

Add one entry to `PRESETS` in `presets.py`. Banners take a size and an
optional `left_inset` for platforms whose avatar covers the left of the
image. Then add the size to `test_expected_presets_exist_with_exact_sizes` in
`layout_test.py` and run both test files:

```bash
scripts/.venv/bin/python scripts/brand/layout_test.py
scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py
```

## Fonts

`fonts/` holds Inter Display (ExtraBold for the name, Medium for the slogan)
from https://github.com/rsms/inter, under the SIL Open Font License in
`fonts/OFL.txt`.
````

- [ ] **Step 4: Run every brand test one final time**

```bash
scripts/.venv/bin/python scripts/brand/layout_test.py
scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py
git status --short
```

Expected: all PASS; `git status` shows only `.github/workflows/ci.yaml` and `scripts/brand/README.md` (no PNGs, no `scripts/brand/out/`).

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yaml scripts/brand/README.md
git commit -m "ci(brand): run the brand asset generator tests in script-tests

Installs Pillow with the job's existing retry and runs the layout and
renderer tests. Adds a README for scripts/brand/ covering setup, every
preset's purpose, and how to add one."
```

- [ ] **Step 6: Report**

Send the user (SendUserFile): `github-social.png` next to the approved prototype, and a contact sheet of every other output. Report the Pillow version, the full-run wall time, and the test wall time. Do not push or open a PR without asking.

---

### Task 6: Commit the generated images under assets/brand (added after implementation)

The user decided, after reviewing the output, to commit the images. This task supersedes the `scripts/brand/out/` output folder and its `.gitignore` entry from Tasks 1, 4 and 5, and fixes the CI step order raised in review.

**Files:**
- Modify: `scripts/brand/generate_brand_assets.py` (`DEFAULT_OUT` and module docstring)
- Modify: `scripts/brand/generate_brand_assets_test.py` (default-output tests)
- Modify: `.gitignore` (remove the `scripts/brand/out/` entry), `scripts/brand/README.md`, the spec
- Modify: `.github/workflows/ci.yaml` (step order)
- Create: `assets/brand/*.png` (16 generated images)

- [x] **Step 1: Replace the gitignore test with the new default-output tests**

In `CliTest`, `test_default_output_folder_is_gitignored` becomes:

```python
    def test_default_output_folder_is_assets_brand(self):
        self.assertEqual(gen.DEFAULT_OUT, os.path.join(REPO, "assets", "brand"))

    def test_brand_images_are_not_bundled_into_the_app(self):
        # The committed banners are for the web, stores and social sites.
        # Flutter only bundles the asset folders pubspec.yaml lists, so
        # listing assets/brand/ would ship ~2 MB of PNGs in every build.
        with open(os.path.join(REPO, "pubspec.yaml"), encoding="utf-8") as f:
            pubspec = f.read()
        self.assertNotIn("assets/brand", pubspec)
```

Run: `scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py CliTest`
Expected: FAIL, `DEFAULT_OUT` is still `scripts/brand/out`.

- [x] **Step 2: Point the default output at assets/brand**

```python
# Committed output, like generate_icon.py's assets/icon/. Not listed in
# pubspec.yaml, so none of it is bundled into the app.
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(BRAND_DIR)), "assets", "brand")
```

Remove the `# Brand images generated by ...` comment and `scripts/brand/out/` line from `.gitignore` (it then matches `main`). Update the README and spec to say the images are committed under `assets/brand/`.

- [x] **Step 3: Generate and verify**

```bash
rm -rf scripts/brand/out
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py
scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py
```

Expected: 16 files in `assets/brand/` (about 2 MB), all tests PASS.

- [x] **Step 4: Run the brand CI step before the dive site step**

`scripts/requirements.txt` lists Pillow, and the "Run dive site harvester tests" step installs it with an unretried `pip install -r`. If that step runs first it downloads Pillow and a transient failure fails the job before the retried install is reached. Move the "Run brand asset generator tests" step above "Run dive site harvester tests"; the later requirements install then finds Pillow already present.

- [x] **Step 5: Commit**

```bash
git add .gitignore scripts/brand/README.md scripts/brand/generate_brand_assets.py scripts/brand/generate_brand_assets_test.py docs/superpowers/specs/2026-09-11-brand-asset-generator-design.md assets/brand/*.png
git commit -m "feat(brand): commit the generated brand images under assets/brand"
```
