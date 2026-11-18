#!/usr/bin/env python3
"""Unit tests for metrics.py, the numbers in the accuracy report."""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("metrics", os.path.join(_HERE, "metrics.py"))
metrics = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(metrics)


class SizeBucketTests(unittest.TestCase):
    def test_bucket_edges(self):
        self.assertEqual(
            [metrics.size_bucket(s) for s in (63, 64, 127, 128, 255, 256)],
            ["under 64", "64-127", "64-127", "128-255", "128-255", "256+"],
        )


class TopKTests(unittest.TestCase):
    def test_top_k_counts_ranks_below_k(self):
        ranks = [0, 1, 2, None]
        self.assertEqual(metrics.top_k(ranks, 1), 0.25)
        self.assertEqual(metrics.top_k(ranks, 3), 0.75)

    def test_top_k_of_nothing_is_zero(self):
        self.assertEqual(metrics.top_k([], 1), 0.0)


class RateTests(unittest.TestCase):
    def test_rate_carries_its_interval(self):
        r = metrics.rate(5, 10)
        self.assertEqual((r.n, r.hits, r.value), (10, 5, 0.5))
        self.assertLess(r.low, 0.5)
        self.assertGreater(r.high, 0.5)

    def test_rate_of_nothing(self):
        r = metrics.rate(0, 0)
        self.assertEqual((r.n, r.value, r.low, r.high), (0, 0.0, 0.0, 1.0))

    def test_coverage_and_precision(self):
        coverage, precision = metrics.coverage_precision([True, True, False, False], [True, False, True, False])
        self.assertEqual((coverage.hits, coverage.n), (2, 4))
        self.assertEqual((precision.hits, precision.n), (1, 2))

    def test_nothing_named_has_no_precision(self):
        coverage, precision = metrics.coverage_precision([False, False], [True, True])
        self.assertEqual(coverage.value, 0.0)
        self.assertEqual(precision.n, 0)


class RecommendTests(unittest.TestCase):
    PREFERENCE = ["licensed", "unlicensed", "pair"]

    def recommend(self, named, p, junk_ok=None):
        return metrics.recommend(named, p, self.PREFERENCE, junk_ok or {n: True for n in named})

    def test_a_significantly_better_pair_wins(self):
        named = {"licensed": 268, "unlicensed": 285, "pair": 317}
        p = {frozenset(("licensed", "pair")): 0.0002, frozenset(("unlicensed", "pair")): 0.0035, frozenset(("licensed", "unlicensed")): 0.28}
        self.assertEqual(self.recommend(named, p), "pair")

    def test_a_close_result_goes_to_the_simpler_choice(self):
        named = {"licensed": 268, "unlicensed": 285, "pair": 290}
        p = {frozenset(("licensed", "pair")): 0.2, frozenset(("unlicensed", "pair")): 0.6, frozenset(("licensed", "unlicensed")): 0.28}
        self.assertEqual(self.recommend(named, p), "licensed")

    def test_too_much_junk_rules_a_run_out(self):
        named = {"licensed": 268, "unlicensed": 285, "pair": 317}
        p = {frozenset(("licensed", "pair")): 0.0002, frozenset(("unlicensed", "pair")): 0.0035, frozenset(("licensed", "unlicensed")): 0.01}
        junk_ok = {"licensed": True, "unlicensed": True, "pair": False}
        self.assertEqual(self.recommend(named, p, junk_ok), "unlicensed")

    def test_a_preferred_run_outside_the_junk_target_is_passed_over(self):
        named = {"licensed": 300, "unlicensed": 285, "pair": 290}
        p = {frozenset(("unlicensed", "pair")): 0.6}
        junk_ok = {"licensed": False, "unlicensed": True, "pair": True}
        self.assertEqual(self.recommend(named, p, junk_ok), "unlicensed")

    def test_a_clearly_better_run_the_preference_does_not_name_wins(self):
        named = {"licensed": 10, "other": 50}
        p = {frozenset(("licensed", "other")): 0.001}
        self.assertEqual(self.recommend(named, p), "other")

    def test_nothing_within_the_junk_target_is_none(self):
        self.assertIsNone(self.recommend({"pair": 1}, {}, {"pair": False}))


class FloorTests(unittest.TestCase):
    # Held-out share of photos with any box, per group (measured accuracy
    # findings, pack 2026.11.18.0030).
    FISH_DETECTOR = {
        "fish": 0.95, "sharks and rays": 0.91, "octopus": 0.62, "crabs": 0.50,
        "sea snails and nudibranchs": 0.60, "sea stars": 0.68, "coral": 0.40,
    }
    MEGALODON = {
        "fish": 0.80, "sharks and rays": 0.78, "octopus": 0.79, "crabs": 0.65,
        "sea snails and nudibranchs": 0.90, "sea stars": 0.84, "coral": 0.83,
    }
    PAIR = {
        "fish": 0.98, "sharks and rays": 0.96, "octopus": 0.90, "crabs": 0.77,
        "sea snails and nudibranchs": 0.95, "sea stars": 0.91, "coral": 0.92,
    }

    def test_groups_under_the_floor_sorted(self):
        self.assertEqual(
            metrics.groups_below_floor(self.FISH_DETECTOR),
            ["coral", "crabs", "octopus", "sea snails and nudibranchs", "sea stars"],
        )
        self.assertEqual(metrics.groups_below_floor(self.MEGALODON), ["crabs"])
        self.assertEqual(metrics.groups_below_floor(self.PAIR), [])

    def test_exactly_the_floor_passes(self):
        self.assertEqual(metrics.groups_below_floor({"crabs": 0.70}), [])
        self.assertEqual(metrics.groups_below_floor({"crabs": 0.69}, floor=0.70), ["crabs"])

    def test_with_the_floor_only_the_pair_is_eligible(self):
        named = {"megalodon": 252, "cfd": 303, "pair": 304}
        p = {frozenset(("megalodon", "pair")): 0.00005, frozenset(("cfd", "pair")): 1.0, frozenset(("megalodon", "cfd")): 0.0007}
        eligible = {
            "megalodon": not metrics.groups_below_floor(self.MEGALODON),
            "cfd": not metrics.groups_below_floor(self.FISH_DETECTOR),
            "pair": not metrics.groups_below_floor(self.PAIR),
        }
        self.assertEqual(metrics.recommend(named, p, ["megalodon", "cfd", "pair"], eligible), "pair")

    def test_nothing_over_the_floor_is_no_recommendation(self):
        named = {"megalodon": 252, "cfd": 303}
        eligible = {
            "megalodon": not metrics.groups_below_floor(self.MEGALODON),
            "cfd": not metrics.groups_below_floor(self.FISH_DETECTOR),
        }
        self.assertIsNone(metrics.recommend(named, {}, ["megalodon", "cfd"], eligible))


class BreakdownTests(unittest.TestCase):
    def test_breakdown_groups_and_sorts(self):
        items = [("b", 1), ("a", 2), ("b", 3)]
        out = metrics.breakdown(items, key=lambda i: i[0], measure=lambda group: {"total": sum(v for _, v in group)})
        self.assertEqual(list(out), ["a", "b"])
        self.assertEqual(out["b"], {"total": 4})


if __name__ == "__main__":
    unittest.main()
