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
