#!/usr/bin/env python3
"""Unit tests for naming.py, the pack tools' copy of the app's species
namer. The Dart side checks the same vectors in
test/features/species_id/domain/species_namer_vectors_test.dart."""

import importlib.util
import json
import math
import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


naming = _load("naming")
grid = _load("region_grid")


class NameTests(unittest.TestCase):
    def test_open_score_ignores_the_region_limit(self):
        result = naming.name([2.0, 1.0, 0.0], [False, True, True], top_k=5)
        self.assertAlmostEqual(result.open_score, 1 / (1 + math.exp(-1) + math.exp(-2)), places=12)
        self.assertEqual(result.ranked[0][0], 1)
        self.assertAlmostEqual(result.ranked[0][1], 1 / (1 + math.exp(-1)), places=12)
        self.assertTrue(result.location_limited)
        self.assertEqual([i for i, _ in result.ranked], [1, 2])

    def test_no_mask_ranks_every_candidate(self):
        result = naming.name([0.0, 3.0, 1.0], None, top_k=5)
        self.assertFalse(result.location_limited)
        self.assertEqual([i for i, _ in result.ranked], [1, 2, 0])
        self.assertAlmostEqual(result.ranked[0][1], result.open_score, places=12)

    def test_ties_keep_the_lower_index_first(self):
        result = naming.name([1.0, 1.0, 0.0], None, top_k=5)
        self.assertEqual([i for i, _ in result.ranked], [0, 1, 2])

    def test_top_k_cuts_the_ranking(self):
        result = naming.name([0.0, 1.0, 2.0, 3.0], None, top_k=2)
        self.assertEqual([i for i, _ in result.ranked], [3, 2])

    def test_empty_or_infinite_logits_are_unusable(self):
        self.assertIsNone(naming.name([], None, top_k=5))
        self.assertIsNone(naming.name([float("nan"), 1.0], None, top_k=5))

    def test_an_infinite_highest_logit_is_unusable(self):
        self.assertIsNone(naming.name([float("inf"), 1.0], None, top_k=5))
        self.assertIsNone(naming.name([-math.inf, -math.inf], None, top_k=5))


class UnitTests(unittest.TestCase):
    def test_unusable_embeddings(self):
        self.assertIsNone(naming.unit([]))
        self.assertIsNone(naming.unit([0.0, 0.0]))
        self.assertIsNone(naming.unit([float("nan"), 1.0]))
        self.assertIsNone(naming.unit([float("inf"), 1.0]))

    def test_unit_length(self):
        self.assertEqual(naming.unit([3.0, 4.0]), [0.6, 0.8])

    def test_logits_are_scaled_dot_products(self):
        self.assertEqual(naming.logits([0.6, 0.8], [[1.0, 0.0], [0.5, 0.5]], 10.0), [6.0, 7.0])


class AllowedTests(unittest.TestCase):
    def setUp(self):
        self.cd = 30
        self.cell = grid.cell_of(12, -68, self.cd)
        self.bits = grid.pack_bits([[self.cell], [self.cell], [], [5]], self.cd)

    def allowed(self, cell, min_allowed=1, rings=0, overrides=None):
        return naming.allowed_for(
            cell,
            self.bits,
            4,
            cell_degrees=self.cd,
            rings=rings,
            min_allowed=min_allowed,
            overrides=overrides or {},
        )

    def test_recorded_candidates_are_allowed(self):
        self.assertEqual(self.allowed(self.cell), [True, True, False, False])

    def test_fallback_below_min_allowed(self):
        self.assertIsNone(self.allowed(self.cell, min_allowed=3))
        self.assertIsNone(self.allowed(None))
        self.assertIsNone(self.allowed(-1))
        self.assertIsNone(self.allowed(grid.cell_count(self.cd)))
        self.assertIsNone(self.allowed(grid.cell_of(-60, 100, self.cd)))

    def test_neighbouring_cells_count(self):
        east = grid.cell_of(12, -38, self.cd)
        self.assertIsNone(self.allowed(east))
        self.assertEqual(self.allowed(east, rings=1), [True, True, False, False])

    def test_override_counts_before_the_floor(self):
        self.assertIsNone(self.allowed(self.cell, min_allowed=2, overrides={1: False}))
        self.assertEqual(
            self.allowed(self.cell, min_allowed=3, overrides={2: True}), [True, True, True, False]
        )


class SuggestableTests(unittest.TestCase):
    BARS = dict(min_crop_side=64, min_open_score=0.2, suggest_score=0.5, suggest_score_no_location=0.7)

    def test_suggestable_uses_the_no_location_bar_when_not_limited(self):
        limited = naming.Naming(open_score=0.6, ranked=((0, 0.6),), location_limited=True)
        unlimited = naming.Naming(open_score=0.6, ranked=((0, 0.6),), location_limited=False)
        self.assertTrue(naming.suggestable(limited, 100, **self.BARS))
        self.assertFalse(naming.suggestable(unlimited, 100, **self.BARS))

    def test_size_and_open_score_floors(self):
        result = naming.Naming(open_score=0.6, ranked=((0, 0.9),), location_limited=True)
        self.assertFalse(naming.suggestable(result, 63, **self.BARS))
        low_open = naming.Naming(open_score=0.19, ranked=((0, 0.9),), location_limited=True)
        self.assertFalse(naming.suggestable(low_open, 100, **self.BARS))

    def test_empty_ranking_is_not_suggestable(self):
        result = naming.Naming(open_score=0.6, ranked=(), location_limited=True)
        self.assertFalse(naming.suggestable(result, 100, **self.BARS))


class VectorFileTests(unittest.TestCase):
    def assertClose(self, got, want, where="vectors"):
        """Equal, except floats to 12 places: `math.exp` need not round the
        same way on every platform."""
        if isinstance(want, float):
            self.assertAlmostEqual(got, want, places=12, msg=where)
        elif isinstance(want, dict):
            self.assertEqual(sorted(got), sorted(want), where)
            for k in want:
                self.assertClose(got[k], want[k], f"{where}.{k}")
        elif isinstance(want, list):
            self.assertEqual(len(got), len(want), where)
            for i, (g, w) in enumerate(zip(got, want)):
                self.assertClose(g, w, f"{where}[{i}]")
        else:
            self.assertEqual(got, want, where)

    def test_written_vectors_match_vectors(self):
        path = os.path.join(_HERE, "testdata", "naming_vectors.json")
        with open(path, encoding="utf-8") as fh:
            self.assertClose(json.load(fh), json.loads(json.dumps(naming.vectors())))

    def test_vector_values_are_exact_in_float32(self):
        v = naming.vectors()
        for value in [x for row in v["textEmbeddings"] for x in row] + [
            x for case in v["cases"] for x in case["embedding"]
        ]:
            self.assertEqual(value * 16, int(value * 16))

    def test_vectors_cover_ties_limits_and_fallback(self):
        cases = naming.vectors()["cases"]
        self.assertTrue(any(c["tie"] for c in cases))
        self.assertTrue(any(c["expected"]["locationLimited"] for c in cases))
        self.assertTrue(any(c["cell"] is not None and not c["expected"]["locationLimited"] for c in cases))
        config = naming.vectors()["config"]
        self.assertTrue(any(c["boxShorterSide"] < config["minCropSide"] for c in cases))

    def test_vectors_show_the_open_score_guarding_a_limited_list(self):
        v = naming.vectors()
        config = v["config"]
        guarded = [
            c
            for c in v["cases"]
            if c["expected"]["locationLimited"]
            and c["expected"]["candidates"][0]["score"] >= config["suggestScore"]
            and c["expected"]["openScore"] < config["minOpenScore"]
        ]
        self.assertTrue(guarded)
        self.assertFalse(any(c["expected"]["suggestable"] for c in guarded))
        self.assertTrue(any(c["expected"]["suggestable"] for c in v["cases"]))


class MainTests(unittest.TestCase):
    def test_write_vectors_writes_the_vectors(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "vectors.json")
            self.assertEqual(naming.main(["--write-vectors", path]), 0)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        self.assertTrue(text.endswith("\n"))
        self.assertEqual(json.loads(text), json.loads(json.dumps(naming.vectors())))


if __name__ == "__main__":
    unittest.main()
