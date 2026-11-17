#!/usr/bin/env python3
"""Unit tests for bars.py: choosing the pack's naming bars from scored
crops."""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("bars", os.path.join(_HERE, "bars.py"))
bars = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bars)

NEVER = bars.NEVER


def s(open_score, top, correct, side=100, limited=True):
    return bars.Scored(open_score=open_score, top_score=top, correct=correct, shorter_side=side, limited=limited)


def both(crops):
    """The same crops named with and without a location."""
    return list(crops), [bars.Scored(c.open_score, c.top_score, c.correct, c.shorter_side, False) for c in crops]


def choose(fish, junk=(), **kw):
    with_loc, no_loc = both(fish)
    junk_with, junk_without = both(junk)
    return bars.choose_bars(with_loc, no_loc, junk_with, junk_without, min_side=64, **kw)


class WilsonTests(unittest.TestCase):
    def test_wilson_known_values(self):
        low, high = bars.wilson(10, 10, 1.96)
        self.assertAlmostEqual(low, 0.7225, places=4)
        self.assertAlmostEqual(high, 1.0, places=12)
        low, high = bars.wilson(5, 10, 1.96)
        self.assertAlmostEqual(low + high, 1.0, places=12)

    def test_wilson_empty_is_unknown(self):
        self.assertEqual(bars.wilson(0, 0, 1.96), (0.0, 1.0))


class MeetsTests(unittest.TestCase):
    def test_meets_needs_a_suggestion(self):
        crops = [s(0.5, 0.4, True)] * 50
        self.assertEqual(bars.meets(crops, min_open=0.0, bar=0.5, min_side=64, target=0.85), (False, 0))

    def test_meets_uses_the_lower_bound_not_the_point_estimate(self):
        # 18 of 20 is 90%, but its one-sided lower bound is below 85%.
        crops = [s(0.5, 0.9, True)] * 18 + [s(0.5, 0.9, False)] * 2
        self.assertEqual(bars.meets(crops, min_open=0.0, bar=0.5, min_side=64, target=0.85), (False, 18))

    def test_small_crops_are_never_suggested(self):
        crops = [s(0.5, 0.9, True, side=63)] * 50
        self.assertEqual(bars.meets(crops, min_open=0.0, bar=0.5, min_side=64, target=0.85), (False, 0))


class ChooseTests(unittest.TestCase):
    def test_choose_takes_the_bar_naming_the_most_fish(self):
        fish = [s(0.5, 0.9, True)] * 40 + [s(0.5, 0.6, True)] * 10 + [s(0.5, 0.55, False)] * 10
        chosen = choose(fish)
        # 0.55 would add ten wrong names (50 of 60 fails); 0.56 to 0.60 all
        # name the same 50, and the highest of them adds no wrong ones.
        self.assertEqual(chosen.suggest, 0.60)
        self.assertEqual(chosen.suggest_no_location, 0.60)

    def test_open_score_tie_goes_higher(self):
        fish = [s(0.5, 0.9, True)] * 50
        self.assertEqual(choose(fish).min_open, 0.50)

    def test_open_score_can_buy_a_lower_bar(self):
        fish = [s(0.6, 0.6, True)] * 50 + [s(0.1, 0.7, False)] * 10
        chosen = choose(fish)
        self.assertGreater(chosen.min_open, 0.10)
        self.assertEqual(chosen.suggest, 0.60)

    def test_no_passing_value_is_never(self):
        chosen = choose([s(0.5, 0.9, False)] * 50)
        self.assertEqual(
            (chosen.suggest, chosen.suggest_no_location, chosen.confident, chosen.confident_no_location),
            (NEVER, NEVER, NEVER, NEVER),
        )

    def test_suggest_is_chosen_from_limited_crops_only(self):
        fish = [s(0.5, 0.9, True)] * 50 + [s(0.5, 0.9, False, limited=False)] * 50
        _, no_loc = both(fish)
        chosen = bars.choose_bars(fish, no_loc, [], [], min_side=64)
        self.assertEqual(chosen.suggest, 0.90)
        self.assertEqual(chosen.suggest_no_location, NEVER)

    def test_confident_never_below_suggest(self):
        fish = [s(0.5, 0.9, True)] * 100 + [s(0.5, 0.7, True)] * 30 + [s(0.5, 0.7, False)] * 3
        chosen = choose(fish)
        self.assertEqual(chosen.suggest, 0.70)
        self.assertGreaterEqual(chosen.confident, chosen.suggest)
        self.assertEqual(chosen.confident, 0.90)

    def test_confident_needs_ninety_five(self):
        # 50 of 50 has a one-sided lower bound of 0.949: enough to suggest,
        # not enough to be confident.
        chosen = choose([s(0.5, 0.9, True)] * 50)
        self.assertEqual(chosen.suggest, 0.90)
        self.assertEqual(chosen.confident, NEVER)


class JunkTests(unittest.TestCase):
    def test_junk_raises_min_open(self):
        fish = [s(0.2, 0.9, True)] * 100 + [s(0.6, 0.9, True)] * 100
        junk = [s(0.21 + i / 100, 0.95, False) for i in range(10)]
        chosen = choose(fish, junk)
        self.assertEqual(chosen.min_open, 0.31)
        self.assertEqual(chosen.suggest, 0.90)

    def test_junk_under_the_rate_changes_nothing(self):
        fish = [s(0.2, 0.9, True)] * 200
        junk = [s(0.9, 0.95, False)] + [s(0.9, 0.1, False)] * 99
        self.assertEqual(choose(fish, junk).min_open, 0.20)

    def test_junk_impossible_turns_everything_off(self):
        fish = [s(0.9, 0.9, True)] * 100
        junk = [s(0.9, 0.99, False)] * 10
        chosen = choose(fish, junk)
        self.assertEqual(
            (chosen.suggest, chosen.suggest_no_location, chosen.confident, chosen.confident_no_location),
            (NEVER, NEVER, NEVER, NEVER),
        )


class NamedTests(unittest.TestCase):
    def test_named_uses_the_matching_bar(self):
        chosen = bars.Bars(min_open=0.2, suggest=0.5, suggest_no_location=0.7, confident=0.8, confident_no_location=0.9)
        crops = [s(0.3, 0.6, True), s(0.3, 0.6, True, limited=False), s(0.1, 0.6, True), s(0.3, 0.85, True)]
        self.assertEqual(bars.named(crops, chosen, min_side=64), [True, False, False, True])
        self.assertEqual(bars.named(crops, chosen, min_side=64, confident=True), [False, False, False, True])


class GateTests(unittest.TestCase):
    CHOSEN = bars.Bars(min_open=0.0, suggest=0.5, suggest_no_location=0.5, confident=0.9, confident_no_location=0.9)

    def test_gate_switches_off_a_failing_bar(self):
        with_loc = [s(0.5, 0.6, True)] * 20 + [s(0.5, 0.6, False)] * 30
        no_loc = [s(0.5, 0.95, True, limited=False)] * 100
        gated, off = bars.held_out_gate(self.CHOSEN, with_loc, no_loc, min_side=64)
        self.assertEqual(gated.suggest, NEVER)
        self.assertEqual(gated.confident, NEVER)
        self.assertEqual(gated.suggest_no_location, 0.5)
        self.assertEqual(gated.confident_no_location, 0.9)
        self.assertEqual(off, ["suggestScore", "confidentScore"])

    def test_gate_keeps_a_bar_whose_interval_reaches_target(self):
        with_loc = [s(0.5, 0.95, True)] * 9 + [s(0.5, 0.95, False)]
        no_loc = [s(0.5, 0.95, True, limited=False)] * 10
        gated, off = bars.held_out_gate(self.CHOSEN, with_loc, no_loc, min_side=64)
        self.assertEqual(gated, self.CHOSEN)
        self.assertEqual(off, [])


class GateEvidenceTests(unittest.TestCase):
    def test_a_bar_that_names_nothing_held_out_is_switched_off(self):
        chosen = bars.Bars(min_open=0.0, suggest=0.5, suggest_no_location=0.5, confident=0.99, confident_no_location=0.99)
        with_loc = [s(0.5, 0.9, True)] * 50
        no_loc = [s(0.5, 0.9, True, limited=False)] * 50
        gated, off = bars.held_out_gate(chosen, with_loc, no_loc, min_side=64)
        self.assertEqual(gated.suggest, 0.5)
        self.assertEqual(gated.confident, NEVER)
        self.assertEqual(gated.confident_no_location, NEVER)
        self.assertEqual(off, ["confidentScore", "confidentScoreNoLocation"])


class McNemarTests(unittest.TestCase):
    def test_mcnemar_symmetric_and_exact(self):
        self.assertAlmostEqual(bars.mcnemar_p(0, 6), 2 * 0.5**6, places=12)
        self.assertEqual(bars.mcnemar_p(0, 6), bars.mcnemar_p(6, 0))
        self.assertEqual(bars.mcnemar_p(3, 3), 1.0)
        self.assertEqual(bars.mcnemar_p(0, 0), 1.0)


if __name__ == "__main__":
    unittest.main()
