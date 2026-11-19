#!/usr/bin/env python3
"""Unit tests for build_pack.py: the credits, the pack version and the options."""

import contextlib
import importlib.util
import io
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


build_pack = _load("build_pack")
manifest = _load("manifest")


class CreditsTests(unittest.TestCase):
    def names(self, detector_set):
        return [c["name"] for c in build_pack.credits_for(detector_set)]

    def test_the_fish_detector_pack_credits_it(self):
        names = self.names("cfd")
        self.assertIn("Community Fish Detector", names)
        self.assertIn("RF-DETR", names)
        self.assertNotIn("FathomNet Megalodon", names)

    def test_a_megalodon_pack_credits_mbari_under_cc_by(self):
        credits = {c["name"]: c for c in build_pack.credits_for("megalodon")}
        self.assertNotIn("Community Fish Detector", credits)
        self.assertNotIn("RF-DETR", credits)
        megalodon = credits["FathomNet Megalodon"]
        self.assertEqual(megalodon["licence"], "CC BY 4.0")
        self.assertIn("MBARI", megalodon["text"])

    def test_every_pack_credits_the_classifier_and_gbif(self):
        for detector_set in manifest.DETECTOR_SETS:
            names = self.names(detector_set)
            self.assertIn("BioCLIP 2", names)
            self.assertIn("GBIF occurrence and taxonomy data", names)

    def test_the_pair_credits_both(self):
        names = self.names("both")
        self.assertIn("Community Fish Detector", names)
        self.assertIn("FathomNet Megalodon", names)

    def test_the_fish_detector_credit_says_no_licence_is_stated(self):
        credits = {c["name"]: c for c in build_pack.credits_for("cfd")}
        cfd = credits["Community Fish Detector"]
        self.assertEqual(cfd["licence"], "No licence stated; its authors leave the terms to the user")
        self.assertIn("https://github.com/filippovarini/community-fish-detector/issues/8", cfd["text"])
        self.assertNotIn("awaiting", cfd["licence"])

    def test_the_gbif_credit_names_what_the_pack_uses(self):
        gbif = {c["name"]: c for c in build_pack.credits_for("both")}["GBIF occurrence and taxonomy data"]
        self.assertIn("Species names", gbif["text"])
        self.assertIn("counts of where each species has been recorded", gbif["text"])


class PackVersionTests(unittest.TestCase):
    def test_two_builds_on_one_day_get_different_versions(self):
        import datetime

        morning = datetime.datetime(2026, 11, 17, 9, 5, tzinfo=datetime.timezone.utc)
        evening = datetime.datetime(2026, 11, 17, 18, 40, tzinfo=datetime.timezone.utc)
        self.assertEqual(build_pack.default_version(morning), "2026.11.17.0905")
        self.assertNotEqual(build_pack.default_version(morning), build_pack.default_version(evening))


class BuildOptionsTests(unittest.TestCase):
    def test_defaults(self):
        args = build_pack.parse_args(["--out", "x"])
        self.assertEqual(args.detectors, "cfd")
        self.assertEqual(args.max_candidates, 10000)
        self.assertEqual(args.min_images, 50)
        self.assertEqual(args.min_survey_records, 50)

    def test_detectors_choose_a_set(self):
        self.assertEqual(build_pack.parse_args(["--out", "x", "--detectors", "both"]).detectors, "both")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            build_pack.parse_args(["--out", "x", "--detectors", "ssd"])

    def test_survey_floor_is_its_own_option(self):
        args = build_pack.parse_args(["--out", "x", "--min-survey-records", "25"])
        self.assertEqual(args.min_survey_records, 25)
        self.assertEqual(args.min_images, 50)


if __name__ == "__main__":
    unittest.main()
