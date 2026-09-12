#!/usr/bin/env python3
"""Generate Submersion brand images: banners, transparent lockups and marks.

Usage:
  python3 scripts/brand/generate_brand_assets.py              # every preset
  python3 scripts/brand/generate_brand_assets.py --list
  python3 scripts/brand/generate_brand_assets.py --only github-social,mark-512
  python3 scripts/brand/generate_brand_assets.py --out /path/to/dir

Writes <out>/<preset>.png; the default output folder is assets/brand/, where
the images are committed. Needs Pillow (pip install -r scripts/requirements.txt) with RAQM
text layout, which loads the system fribidi library. Presets are defined in
presets.py; see README.md in this folder.
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
# Committed output, like generate_icon.py's assets/icon/. Not listed in
# pubspec.yaml, so none of it is bundled into the app.
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(BRAND_DIR)), "assets", "brand")
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

# The size assets/icon/icon.png is generated at; every banner icon is this
# render scaled down (no preset needs a larger icon).
OFFICIAL_ICON_PX = 1024

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
    """The decorative wave bands and line, drawn at 2x for smooth edges.

    Each shape gets its own layer: ImageDraw replaces pixels rather than
    blending them, so overlapping bands drawn on one layer would not stack.
    """
    ss = 2
    sx, sy = width / 1280, height / 640
    hi = (width * ss, height * ss)
    result = Image.new("RGBA", hi, (0, 0, 0, 0))
    for base, amp, period in WAVE_BANDS:
        layer = Image.new("RGBA", hi, (0, 0, 0, 0))
        top = _wave_points(width, sx, sy, base, amp, period, ss)
        ImageDraw.Draw(layer).polygon(top + [hi, (0, hi[1])], fill=WAVE_FILL)
        result = Image.alpha_composite(result, layer)
    layer = Image.new("RGBA", hi, (0, 0, 0, 0))
    base, amp, period = WAVE_LINE
    ImageDraw.Draw(layer).line(
        _wave_points(width, sx, sy, base, amp, period, ss),
        fill=WAVE_STROKE,
        width=max(1, round(WAVE_STROKE_W * sy * ss)),
        joint="curve",
    )
    result = Image.alpha_composite(result, layer)
    return result.resize((width, height), Image.Resampling.LANCZOS)


@functools.lru_cache(maxsize=None)
def _official_icon():
    return create_icon(OFFICIAL_ICON_PX)


@functools.lru_cache(maxsize=None)
def _icon(px):
    # Scale the official icon rather than rendering at px: generate_icon.py
    # draws its white outline a fixed number of pixels wide, so a direct
    # small render would show it several times thicker than the real icon.
    return _official_icon().resize((px, px), Image.Resampling.LANCZOS)


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
