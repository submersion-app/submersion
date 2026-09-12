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
