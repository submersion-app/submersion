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


def _where(channel, test):
    return channel.point(lambda v: 255 if test(v) else 0)


def teal_pixel_count(img):
    """Opaque pixels in the tile's cyan-teal family (low red, high green and blue)."""
    r, g, b, a = img.split()
    hits = _where(a, lambda v: v > 200)
    for channel, test in ((r, lambda v: v < 120), (g, lambda v: v > 150), (b, lambda v: v > 150)):
        hits = ImageChops.multiply(hits, _where(channel, test))
    return hits.histogram()[255]


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
