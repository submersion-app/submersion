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


class CheckPackTest(unittest.TestCase):
    BARS = {"min_open": 0.1, "suggest": 0.7, "suggest_no_location": 0.8, "confident": 0.93, "confident_no_location": 1.01}

    SETTINGS = {"anchor": 1e-3, "epochs": 4, "blend": 0.5, "sharpness": 2.0, "seed": 0}

    def confirm(self, held=(5, 6), named_at=None, settings=None):
        gate.confirm_check_pack(
            {"held back species": list(held), **(settings or self.SETTINGS)},
            [6, 5],
            {"bars after held-out gate": named_at or self.BARS},
            {"bars after held-out gate": self.BARS},
            {"held back species": [], **self.SETTINGS},
        )

    def test_a_check_pack_trained_with_other_settings_is_refused(self):
        for changed in ({"blend": 0.75}, {"epochs": 5}, {"seed": 1}):
            with self.subTest(changed=changed), self.assertRaisesRegex(SystemExit, "settings"):
                self.confirm(settings={**self.SETTINGS, **changed})

    def test_a_check_pack_that_held_back_the_test_species_passes(self):
        self.confirm()

    def test_a_pack_that_held_back_other_species_is_refused(self):
        for held in ((), (5,), (5, 6, 7)):
            with self.subTest(held=held), self.assertRaisesRegex(SystemExit, "held back"):
                self.confirm(held=held)

    def test_scores_named_at_other_bars_are_refused(self):
        with self.assertRaisesRegex(SystemExit, "bars"):
            self.confirm(named_at={**self.BARS, "confident": 0.95})


class TrainingRecordTest(unittest.TestCase):
    MANIFEST = {"files": [{"name": "text_embeddings.f16", "sha256": "b" * 64}]}

    def test_a_record_of_the_pack_s_rows_passes(self):
        gate.confirm_training_record({"rows sha256": "b" * 64}, self.MANIFEST, "check")

    def test_a_record_of_other_rows_or_none_is_refused(self):
        for record in ({"rows sha256": "c" * 64}, {}):
            with self.subTest(record=record), self.assertRaisesRegex(SystemExit, "check"):
                gate.confirm_training_record(record, self.MANIFEST, "check")


class SameBaseTest(unittest.TestCase):
    BASE = {
        "files": [
            {"name": "detector.coreml.zip", "sha256": "d" * 64},
            {"name": "candidates.json", "sha256": "a" * 64},
            {"name": "text_embeddings.f16", "sha256": "b" * 64},
        ]
    }

    def pack(self, rows, **changes):
        def sha(f):
            return changes.get(f["name"], rows if f["name"] == "text_embeddings.f16" else f["sha256"])

        return {"files": [{**f, "sha256": sha(f)} for f in self.BASE["files"]]}

    def confirm(self, check=None, check_record=None):
        gate.confirm_same_base(
            self.BASE,
            {"trained": self.pack("t" * 64), "check": check or self.pack("c" * 64)},
            {"trained": {"base rows sha256": "b" * 64}, "check": check_record or {"base rows sha256": "b" * 64}},
        )

    def test_packs_built_from_the_baseline_pass(self):
        self.confirm()

    def test_a_pack_with_other_candidates_or_models_is_refused(self):
        for name in ("candidates.json", "detector.coreml.zip"):
            with self.subTest(name=name), self.assertRaisesRegex(SystemExit, "check"):
                self.confirm(check=self.pack("c" * 64, **{name: "e" * 64}))

    def test_a_pack_trained_from_other_name_rows_is_refused(self):
        with self.assertRaisesRegex(SystemExit, "name rows"):
            self.confirm(check_record={"base rows sha256": "e" * 64})


class ProvenanceTest(unittest.TestCase):
    FILES = [
        {"name": "detector.coreml.zip", "sha256": "d" * 64},
        {"name": "classifier.coreml.zip", "sha256": "e" * 64},
        {"name": "candidates.json", "sha256": "a" * 64},
        {"name": "text_embeddings.f16", "sha256": "b" * 64},
        {"name": "regions.bin", "sha256": "c" * 64},
    ]
    MANIFEST = {"packVersion": "v1", "files": FILES}

    def scored(self, **changes):
        files = {f["name"]: f["sha256"] for f in self.FILES}
        return {"pack": "v1", "files": {**files, **changes}}

    def test_scores_made_on_the_pack_files_pass(self):
        gate.confirm_scored(self.scored(), self.MANIFEST, "trained")

    def test_scores_made_on_other_rows_or_models_are_refused(self):
        for name in ("text_embeddings.f16", "detector.coreml.zip", "classifier.coreml.zip"):
            with self.subTest(name=name), self.assertRaisesRegex(SystemExit, "trained"):
                gate.confirm_scored(self.scored(**{name: "f" * 64}), self.MANIFEST, "trained")

    def test_scores_of_another_pack_version_are_refused(self):
        with self.assertRaisesRegex(SystemExit, "v2"):
            gate.confirm_scored({**self.scored(), "pack": "v2"}, self.MANIFEST, "trained")

    def test_scores_from_before_files_were_recorded_are_refused(self):
        with self.assertRaisesRegex(SystemExit, "score it again"):
            gate.confirm_scored({"pack": "v1"}, self.MANIFEST, "baseline")

    def test_the_three_scores_must_cover_the_same_photos(self):
        photos = {"1": {}, "2": {}}
        gate.confirm_same_photos(photos, dict(photos), dict(photos))
        with self.assertRaisesRegex(SystemExit, "different photos"):
            gate.confirm_same_photos(photos, {"1": {}}, dict(photos))


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
