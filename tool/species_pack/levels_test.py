#!/usr/bin/env python3
"""Unit tests for levels.py: measuring a pack's naming levels (issue
#4721)."""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("levels", os.path.join(_HERE, "levels.py"))
levels = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(levels)

import bars  # noqa: E402

NEVER = bars.NEVER
SURER = bars.Bars(min_open=0.5, suggest=0.80, suggest_no_location=0.80, confident=NEVER, confident_no_location=NEVER)


def record(top, correct):
    """One crop, limited by place with a location and not without one."""
    return {
        "with": bars.Scored(open_score=0.6, top_score=top, correct=correct, shorter_side=100, limited=True),
        "without": bars.Scored(open_score=0.6, top_score=top, correct=correct, shorter_side=100, limited=False),
    }


def measure(fish, junk=()):
    """Levels measured with the same crops as the tune and held-out halves."""
    return levels.measure(SURER, fish, list(junk), fish, list(junk), min_side=64)


class MeasureTests(unittest.TestCase):
    def test_a_level_less_often_right_than_surer_is_kept(self):
        # 100 of 100 right over Surer's bar, 70 of 100 at 0.55: Balanced
        # names at 0.55, and Eager would name no more.
        fish = [record(0.9, True)] * 100 + [record(0.55, True)] * 70 + [record(0.55, False)] * 30
        found, surer_precision = measure(fish)
        self.assertEqual(surer_precision, 1.0)
        self.assertEqual([level["id"] for level in found], ["balanced"])
        self.assertEqual(found[0]["held-out"]["precision"]["value"], 0.85)
        self.assertEqual(found[0]["held-out"]["junk named"]["n"], 0)

    def test_a_level_more_often_right_than_the_one_above_is_left_out(self):
        # Surer is right 70 of 100 times; lowering the bar adds 100 right.
        fish = [record(0.9, True)] * 70 + [record(0.9, False)] * 30 + [record(0.55, True)] * 100
        found, surer_precision = measure(fish)
        self.assertEqual(surer_precision, 0.7)
        self.assertEqual(found, [])

    def test_surer_naming_nothing_has_no_precision(self):
        fish = [record(0.55, True)] * 100
        _, surer_precision = measure(fish)
        self.assertIsNone(surer_precision)

    def test_a_level_naming_nothing_right_held_out_is_left_out(self):
        # Balanced names at 0.55 on the tune half; held out it names one
        # crop, wrongly, which the gate's interval cannot rule out, but a
        # precision of 0 is no share to show.
        tune = [record(0.55, True)] * 100
        held = [record(0.55, False)]
        found, surer_precision = levels.measure(SURER, tune, [], held, [], min_side=64)
        self.assertIsNone(surer_precision)
        self.assertEqual(found, [])

    def test_manifest_precision_is_a_share_at_the_places_kept(self):
        self.assertIsNone(levels.manifest_precision(None))
        self.assertIsNone(levels.manifest_precision(0.0))
        self.assertIsNone(levels.manifest_precision(0.0004))
        self.assertEqual(levels.manifest_precision(0.8971), 0.897)

    def test_rates_count_junk_named_with_or_without_a_location(self):
        junk = [record(0.9, False)] * 2 + [record(0.3, False)] * 2
        held = levels.rates(SURER, [record(0.9, True)], junk, min_side=64)
        self.assertEqual((held["junk named"]["hits"], held["junk named"]["n"]), (2, 4))
        self.assertEqual(held["coverage"]["value"], 1.0)


if __name__ == "__main__":
    unittest.main()
