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

import functools

from PIL import Image, ImageChops, ImageFilter

from generate_icon import SUPERSAMPLE, build_flag, build_wave_arrow_mask

MARK_PADDING = 0.04
# Every mark is scaled down from a render at the official icon's size, so the
# white outline keeps the icon's hairline proportion at any size.
MASTER_PX = 1024


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


@functools.lru_cache(maxsize=None)
def _master_glyph_hi():
    # Drawn once at the official icon's scale. The outline is a fixed number
    # of pixels wide, so rendering directly at a smaller size would make it
    # several times thicker, relative to the logo, than the real icon has it.
    return _render_glyph_hi(MASTER_PX * SUPERSAMPLE)


@functools.lru_cache(maxsize=None)
def _master_mark_hi():
    glyph = _master_glyph_hi()
    hi = glyph.width
    glyph = glyph.crop(glyph.getchannel("A").getbbox())
    scale = hi * (1 - 2 * MARK_PADDING) / max(glyph.size)
    glyph = glyph.resize(
        (round(glyph.width * scale), round(glyph.height * scale)),
        Image.Resampling.LANCZOS,
    )
    canvas = _solid((hi, hi), (0, 0, 0, 0))
    canvas.paste(glyph, ((hi - glyph.width) // 2, (hi - glyph.height) // 2))
    return canvas


def render_glyph(size):
    """The glyph where it sits in the app icon, on a transparent square."""
    return _master_glyph_hi().resize((size, size), Image.Resampling.LANCZOS)


def create_mark(size):
    """The glyph cropped to its bounds and centered with a small padding."""
    return _master_mark_hi().resize((size, size), Image.Resampling.LANCZOS)
