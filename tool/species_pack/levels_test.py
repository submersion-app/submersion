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


def split(with_top, without_top, correct):
    """One crop whose two namings score differently: limiting it to a place
    moves its top score, as it does for a real crop."""
    return {
        "with": bars.Scored(open_score=0.6, top_score=with_top, correct=correct, shorter_side=100, limited=True),
        "without": bars.Scored(open_score=0.6, top_score=without_top, correct=correct, shorter_side=100, limited=False),
    }


def measure(fish, junk=()):
    """(levels, Surer's figure) measured with the same crops as the tune
    and held-out halves."""
    found, surer_precision, _ = levels.measure(SURER, fish, list(junk), fish, list(junk), min_side=64)
    return found, surer_precision


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
        found, surer_precision, _ = levels.measure(SURER, tune, [], held, [], min_side=64)
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

    def test_rates_measure_both_sides(self):
        level = bars.Bars(min_open=0.5, suggest=0.5, suggest_no_location=0.7, confident=NEVER, confident_no_location=NEVER)
        held = [record(0.6, True)] * 8 + [record(0.6, False)] * 2 + [record(0.8, True)] * 3
        out = levels.rates(level, held, [], min_side=64)
        self.assertAlmostEqual(out["precision"]["value"], 11 / 13)
        self.assertEqual(out["precision without location"]["value"], 1.0)
        self.assertAlmostEqual(out["coverage without location"]["value"], 3 / 13)

    def test_shown_precision_takes_the_lower_side_that_names_something(self):
        def rate(value, n):
            return {"value": value, "n": n}

        self.assertEqual(levels.shown_precision(rate(0.8, 10), rate(0.7, 5)), 0.7)
        self.assertEqual(levels.shown_precision(rate(0.8, 10), rate(None, 0)), 0.8)
        self.assertEqual(levels.shown_precision(rate(0.0, 4), rate(0.9, 9)), 0.0)
        self.assertIsNone(levels.shown_precision(rate(None, 0), rate(None, 0)))

    def test_deciding_side_is_the_lower_and_on_a_tie_the_larger(self):
        def rate(value, n):
            return {"value": value, "n": n}

        held = {"precision": rate(0.8, 10), "precision without location": rate(0.7, 5)}
        self.assertEqual(levels.deciding_side(held), ("without a location", rate(0.7, 5)))
        # A tie is set as surely by the side naming more crops.
        tie = {"precision": rate(0.8, 3), "precision without location": rate(0.8, 50)}
        self.assertEqual(levels.deciding_side(tie), ("without a location", rate(0.8, 50)))
        # Results from before both sides were measured carry one side only.
        self.assertEqual(levels.deciding_side({"precision": rate(0.8, 10)}), ("with a location", rate(0.8, 10)))
        self.assertIsNone(levels.deciding_side({}))

    def test_surers_figure_is_its_lower_side(self):
        # 90 right both ways; 20 wrong crops the location limit keeps below
        # Surer's bar are named without a location.
        fish = [record(0.9, True)] * 90 + [split(0.5, 0.85, False)] * 20
        _, surer_precision = measure(fish)
        self.assertAlmostEqual(surer_precision, 90 / 110)

    def test_measure_hands_back_surers_rates(self):
        # The rates Surer's figure was taken from, so score.py need not
        # measure them again.
        fish = [record(0.9, True)] * 90 + [split(0.5, 0.85, False)] * 20
        _, surer_precision, surer_rates = levels.measure(SURER, fish, [], fish, [], min_side=64)
        self.assertEqual(surer_rates, levels.rates(SURER, fish, [], min_side=64))
        self.assertAlmostEqual(surer_rates["precision without location"]["value"], surer_precision)

    def test_a_level_less_often_right_without_a_location_shows_that(self):
        fish = (
            [record(0.9, True)] * 100
            + [record(0.55, True)] * 70
            + [record(0.55, False)] * 30
            + [split(0.3, 0.56, False)] * 5
        )
        found, _ = measure(fish)
        self.assertEqual([level["id"] for level in found], ["balanced"])
        held = found[0]["held-out"]
        self.assertEqual(held["precision"]["value"], 0.85)
        self.assertAlmostEqual(held["precision without location"]["value"], 170 / 205)
        self.assertEqual(found[0]["precision"], 0.829)

    def test_levels_are_held_below_surers_lower_figure(self):
        # Surer is right every time with a location but 100 of 130 without
        # one; a level right 87% of the time on its weaker side would read
        # as more often right than Surer.
        fish = (
            [record(0.9, True)] * 100
            + [split(0.5, 0.85, False)] * 30
            + [split(0.55, 0.65, True)] * 100
            + [split(0.55, 0.3, False)] * 20
        )
        found, surer_precision = measure(fish)
        self.assertAlmostEqual(surer_precision, 100 / 130)
        self.assertEqual(found, [])

    def test_eager_is_held_below_balanceds_lower_figure(self):
        # Chosen on the tune half: Balanced at 0.55, Eager at 0.45. Held
        # out, Balanced is right every time with a location but 100 of 125
        # without one; Eager, right 200 of 225 on its weaker side, would
        # read as more often right than Balanced.
        tune = (
            [record(0.9, True)] * 100
            + [record(0.55, True)] * 70
            + [record(0.55, False)] * 30
            + [record(0.45, True)] * 50
            + [record(0.45, False)] * 50
        )
        held = [record(0.9, True)] * 100 + [split(0.1, 0.6, False)] * 25 + [split(0.5, 0.5, True)] * 100
        found, _, _ = levels.measure(SURER, tune, [], held, [], min_side=64)
        self.assertEqual([level["id"] for level in found], ["balanced"])
        self.assertEqual(found[0]["precision"], 0.8)


if __name__ == "__main__":
    unittest.main()
