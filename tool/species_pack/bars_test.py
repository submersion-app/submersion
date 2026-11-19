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


class LevelTests(unittest.TestCase):
    """A naming level (issue #4721): lower suggest bars at a lower target,
    the pack's floor and size held, never above the level above it."""

    SURER = bars.Bars(min_open=0.5, suggest=0.80, suggest_no_location=0.80, confident=NEVER, confident_no_location=NEVER)
    # 160 of 200 right at 0.55 and below, 100 of 100 above it.
    FISH = [s(0.6, 0.9, True)] * 100 + [s(0.6, 0.55, True)] * 60 + [s(0.6, 0.55, False)] * 40

    def level(self, fish, junk=(), ceiling=None, target=0.65, no_loc=None):
        with_loc, without = both(fish)
        junk_with, junk_without = both(junk)
        return bars.level_bars(
            with_loc,
            without if no_loc is None else no_loc,
            junk_with,
            junk_without,
            surer=self.SURER,
            ceiling=ceiling or self.SURER,
            min_side=64,
            target=target,
        )

    def test_level_is_lower_than_surer(self):
        level = self.level(self.FISH)
        self.assertEqual((level.suggest, level.suggest_no_location), (0.55, 0.55))
        self.assertEqual(level.min_open, 0.5)
        self.assertEqual((level.confident, level.confident_no_location), (NEVER, NEVER))

    def test_level_takes_the_bar_naming_most_right_not_the_lowest(self):
        # 0.55 also meets 0.75, but only adds a wrong name: the same 100
        # right, so the tie goes to the higher bar, as for the pack's bars.
        surer = bars.Bars(0.5, 0.90, 0.90, NEVER, NEVER)
        fish = [s(0.6, 0.80, True)] * 100 + [s(0.6, 0.55, False)]
        with_loc, without = both(fish)
        level = bars.level_bars(
            with_loc, without, [], [], surer=surer, ceiling=surer, min_side=64, target=0.75
        )
        self.assertEqual((level.suggest, level.suggest_no_location), (0.80, 0.80))

    def test_level_never_above_ceiling(self):
        ceiling = bars.Bars(0.5, 0.70, 0.80, NEVER, NEVER)
        _, no_loc = both(self.FISH)
        level = self.level([s(0.6, 0.95, True)] * 100, ceiling=ceiling, no_loc=no_loc)
        self.assertEqual(level.suggest, 0.70)
        self.assertEqual(level.suggest_no_location, 0.55)

    def test_level_equal_to_ceiling_is_none(self):
        fish = [s(0.6, 0.85, True)] * 100 + [s(0.6, 0.5, False)] * 100
        self.assertIsNone(self.level(fish))

    def test_junk_raises_the_level(self):
        level = self.level(self.FISH, junk=[s(0.6, 0.56, False)] * 10)
        self.assertEqual((level.suggest, level.suggest_no_location), (0.57, 0.57))

    def test_junk_raises_only_the_bar_that_names_it(self):
        with_loc, without = both(self.FISH)
        # Named only without a location: with one, its best name scores low.
        junk_with = [s(0.6, 0.30, False)] * 10
        junk_without = [s(0.6, 0.56, False, limited=False)] * 10
        level = bars.level_bars(
            with_loc,
            without,
            junk_with,
            junk_without,
            surer=self.SURER,
            ceiling=self.SURER,
            min_side=64,
            target=0.65,
        )
        self.assertEqual((level.suggest, level.suggest_no_location), (0.55, 0.57))

    def test_junk_that_cannot_pass_drops_the_level(self):
        self.assertIsNone(self.level(self.FISH, junk=[s(0.6, 0.79, False)] * 10))

    def test_targets(self):
        self.assertEqual(bars.LEVEL_TARGETS, (("balanced", 0.75), ("eager", 0.65)))


class PublishedBarsTests(unittest.TestCase):
    """Levels are measured under the bars the pack ships with, not bars a
    later run re-derives (issue #4721)."""

    NAMING = {
        "provisional": False,
        "minCropSide": 64,
        "minOpenScore": 0.44,
        "suggestScore": 0.74,
        "confidentScore": 1.01,
        "suggestScoreNoLocation": 0.81,
        "confidentScoreNoLocation": 1.01,
    }

    def test_measured_naming_gives_its_bars(self):
        self.assertEqual(bars.published_bars(self.NAMING), bars.Bars(0.44, 0.74, 0.81, 1.01, 1.01))

    def test_provisional_naming_gives_none(self):
        self.assertIsNone(bars.published_bars({**self.NAMING, "provisional": True}))

    def test_a_missing_no_location_confident_bar_follows_the_confident_bar(self):
        naming = {k: v for k, v in self.NAMING.items() if k != "confidentScoreNoLocation"}
        self.assertEqual(bars.published_bars({**naming, "confidentScore": 0.95}).confident_no_location, 0.95)


class LevelGateTests(unittest.TestCase):
    SURER = LevelTests.SURER
    LEVEL = bars.Bars(0.5, 0.55, 0.80, NEVER, NEVER)

    def gate(self, with_loc):
        no_loc = [s(0.6, 0.9, True, limited=False)] * 50
        return bars.level_gate(self.LEVEL, self.SURER, with_loc, no_loc, min_side=64, target=0.65)

    def test_gate_drops_a_level_whose_interval_is_below_target(self):
        self.assertFalse(self.gate([s(0.6, 0.6, True)] * 10 + [s(0.6, 0.6, False)] * 90))

    def test_gate_keeps_a_level_that_meets_target(self):
        self.assertTrue(self.gate([s(0.6, 0.6, True)] * 90 + [s(0.6, 0.6, False)] * 10))

    def test_gate_drops_a_level_that_names_nothing(self):
        self.assertFalse(self.gate([s(0.6, 0.3, True)] * 50))


class McNemarTests(unittest.TestCase):
    def test_mcnemar_symmetric_and_exact(self):
        self.assertAlmostEqual(bars.mcnemar_p(0, 6), 2 * 0.5**6, places=12)
        self.assertEqual(bars.mcnemar_p(0, 6), bars.mcnemar_p(6, 0))
        self.assertEqual(bars.mcnemar_p(3, 3), 1.0)
        self.assertEqual(bars.mcnemar_p(0, 0), 1.0)


if __name__ == "__main__":
    unittest.main()
