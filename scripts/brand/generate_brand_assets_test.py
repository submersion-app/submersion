#!/usr/bin/env python3
"""Tests for the brand image renderer, the transparent mark, and the CLI.

Run: python3 scripts/brand/generate_brand_assets_test.py

Needs Pillow (pip install -r scripts/requirements.txt). Deliberately fails
rather than skips without it, so CI cannot go green having tested nothing.
"""

import contextlib
import io
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image, ImageChops, ImageFilter, ImageStat  # noqa: E402

import generate_brand_assets as gen  # noqa: E402
import presets  # noqa: E402
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


def darkest_opaque_luminance(img):
    opaque = _where(img.getchannel("A"), lambda v: v == 255)
    return ImageStat.Stat(img.convert("L"), mask=opaque).extrema[0][0]


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
        # Darkest opaque text pixel is navy in one and near-white in the other.
        self.assertLess(darkest_opaque_luminance(dark.crop(text_half)), 90)
        self.assertGreater(darkest_opaque_luminance(light.crop(text_half)), 200)

    def test_red_rule_appears_in_lockup_but_not_wordmark(self):
        def red_text_pixels(img):
            # Right of the icon only (it ends about a third of the way
            # across): the icon's own dive-flag red is on the left.
            r, g, b, a = img.crop((int(img.width * 0.36), 0, img.width, img.height)).split()
            hits = _where(a, lambda v: v == 255)
            for channel, test in ((r, lambda v: v > 150), (g, lambda v: v < 60), (b, lambda v: v < 60)):
                hits = ImageChops.multiply(hits, _where(channel, test))
            return hits.histogram()[255]

        self.assertGreater(red_text_pixels(self.images["lockup-dark"]), 0)
        self.assertEqual(red_text_pixels(self.images["wordmark-dark"]), 0)


class WavesTest(unittest.TestCase):
    def test_overlapping_bands_stack(self):
        # Regression: ImageDraw replaces pixels instead of blending, so two
        # 10% bands drawn on one layer stayed 10% where they overlap. Stacked,
        # the overlap is 1 - 0.9 * 0.9 = 19% white (alpha about 48).
        waves = gen._waves(1280, 640)
        band_one_only = waves.getpixel((40, 530))[3]
        both_bands = waves.getpixel((40, 630))[3]
        self.assertAlmostEqual(band_one_only, 26, delta=2)
        self.assertAlmostEqual(both_bands, 48, delta=3)


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

    def test_default_output_folder_is_assets_brand(self):
        self.assertEqual(gen.DEFAULT_OUT, os.path.join(REPO, "assets", "brand"))

    def test_brand_images_are_not_bundled_into_the_app(self):
        # The committed banners are for the web, stores and social sites.
        # Flutter only bundles the asset folders pubspec.yaml lists, so
        # listing assets/brand/ would ship ~2 MB of PNGs in every build.
        with open(os.path.join(REPO, "pubspec.yaml"), encoding="utf-8") as f:
            pubspec = f.read()
        self.assertNotIn("assets/brand", pubspec)


if __name__ == "__main__":
    unittest.main()
