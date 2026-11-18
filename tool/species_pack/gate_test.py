#!/usr/bin/env python3
"""Unit tests for gate.py, the naming layer's ship gate (issue #4724)."""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("gate", os.path.join(_HERE, "gate.py"))
gate = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate)


def photo(right, *, group="fish", sample="natural", held_out=True, key="1", sure=False, wrong=False):
    return {
        "named_right": right,
        "confident_right": sure,
        "confident_wrong": wrong,
        "group": group,
        "sample": sample,
        "held_out": held_out,
        "gbif_key": key,
    }


def pair(base_right, trained_right, **kw):
    return photo(base_right, **kw), photo(trained_right, **kw)


def build(pairs):
    base, trained = {}, {}
    for i, (b, t) in enumerate(pairs):
        base[str(i)], trained[str(i)] = b, t
    return base, trained


GOOD_EVAL = {"bars after held-out gate": {"confident": 0.93}, "junk named (tune, at the chosen bars)": 0.01}
PASSING_RARE = {"pass": True}


class MoreNamedRightTest(unittest.TestCase):
    def test_more_named_right_needs_significance(self):
        few = build([pair(False, True)] * 3 + [pair(True, True)] * 50)
        self.assertFalse(gate.more_named_right(*few)["pass"])
        many = build([pair(False, True)] * 30 + [pair(True, False)] * 5)
        result = gate.more_named_right(*many)
        self.assertTrue(result["pass"])
        self.assertEqual((result["only trained"], result["only baseline"]), (30, 5))

    def test_only_held_out_natural_photos_count(self):
        tune = [pair(False, True, held_out=False)] * 40
        top_up = [pair(False, True, sample="top-up")] * 40
        self.assertFalse(gate.more_named_right(*build(tune + top_up))["pass"])


class ConfidentBarTest(unittest.TestCase):
    def test_confident_bar_never_fails(self):
        self.assertFalse(gate.confident_bar({"bars after held-out gate": {"confident": 1.01}})["pass"])
        self.assertTrue(gate.confident_bar(GOOD_EVAL)["pass"])


class GroupsTest(unittest.TestCase):
    def test_one_group_significantly_worse_fails(self):
        fish = [pair(False, True, group="fish")] * 40
        coral = [pair(True, False, group="coral")] * 12
        result = gate.no_group_worse(*build(fish + coral))
        self.assertFalse(result["pass"])
        self.assertEqual(result["worse"], ["coral"])

    def test_groups_count_top_up_photos_too(self):
        coral = [pair(True, False, group="coral", sample="top-up")] * 12
        self.assertFalse(gate.no_group_worse(*build(coral))["pass"])


class JunkTest(unittest.TestCase):
    def test_junk_over_two_percent_fails(self):
        self.assertTrue(gate.junk({"junk named (tune, at the chosen bars)": 0.02})["pass"])
        self.assertFalse(gate.junk({"junk named (tune, at the chosen bars)": 0.021})["pass"])


class RareTest(unittest.TestCase):
    def test_rare_check_at_two_percent(self):
        def check(wrong):
            photos = {str(i): photo(False, key="5", wrong=i < wrong, held_out=i % 2 == 0) for i in range(240)}
            photos["other"] = photo(False, key="6", wrong=True)
            return gate.rare_check(photos, {5})

        passing = check(4)
        self.assertTrue(passing["pass"])
        self.assertEqual((passing["photos"], passing["confident wrong"]), (240, 4))
        self.assertFalse(check(5)["pass"])

    def test_rare_check_with_no_photos_fails(self):
        self.assertFalse(gate.rare_check({}, {5})["pass"])


class VerdictTest(unittest.TestCase):
    def test_ship_only_when_all_pass(self):
        base, trained = build([pair(False, True)] * 30)
        good = gate.verdict(base, trained, GOOD_EVAL, PASSING_RARE)
        self.assertTrue(good["ship"])
        bad = gate.verdict(base, trained, GOOD_EVAL, {"pass": False})
        self.assertFalse(bad["ship"])
        self.assertEqual(
            set(good) - {"ship"}, {"more_named_right", "confident_bar", "no_group_worse", "junk", "rare_species"}
        )


if __name__ == "__main__":
    unittest.main()
