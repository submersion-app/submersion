#!/usr/bin/env python3
"""Unit tests for evidence.py.

Run: python3 scripts/site_catalogue/research/evidence_test.py

A researched site's facts are read from pages that write positions in
several ways and to several precisions. These tests pin how a figure is
read, how precise it is taken to be, how a page's domain is named and
filed, and the hazard sentences written in our own words.
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE), os.path.dirname(os.path.dirname(_HERE))]

import evidence  # noqa: E402


class ParseCoordinateTest(unittest.TestCase):
    def test_a_number_is_decimal_degrees(self):
        value, precision = evidence.parse_coordinate(-8.27391, "lat")
        self.assertAlmostEqual(value, -8.27391)
        self.assertAlmostEqual(precision, 0.00001)

    def test_decimal_degrees_as_text_keep_their_precision(self):
        value, precision = evidence.parse_coordinate("-8.27391", "lat")
        self.assertAlmostEqual(value, -8.27391)
        self.assertAlmostEqual(precision, 0.00001)
        _, coarse = evidence.parse_coordinate("115.6", "lon")
        self.assertAlmostEqual(coarse, 0.1)

    def test_degrees_minutes_seconds(self):
        value, precision = evidence.parse_coordinate("8 16 28.80 S", "lat")
        self.assertAlmostEqual(value, -(8 + 16 / 60 + 28.8 / 3600), places=6)
        self.assertAlmostEqual(precision, 0.01 / 3600)

    def test_marks_are_read_as_spaces(self):
        value, _ = evidence.parse_coordinate("8°16′28.80″S", "lat")
        self.assertAlmostEqual(value, -(8 + 16 / 60 + 28.8 / 3600), places=6)
        value, _ = evidence.parse_coordinate("115° 35' 34.77\" E", "lon")
        self.assertAlmostEqual(value, 115 + 35 / 60 + 34.77 / 3600, places=6)

    def test_degrees_and_decimal_minutes(self):
        value, precision = evidence.parse_coordinate("4 06.9 N", "lat")
        self.assertAlmostEqual(value, 4 + 6.9 / 60, places=6)
        self.assertAlmostEqual(precision, 0.1 / 60)

    def test_whole_minutes_are_coarse(self):
        value, precision = evidence.parse_coordinate("4 6 N", "lat")
        self.assertAlmostEqual(value, 4.1)
        self.assertAlmostEqual(precision, 1 / 60)

    def test_whole_seconds(self):
        _, precision = evidence.parse_coordinate("8 16 19 S", "lat")
        self.assertAlmostEqual(precision, 1 / 3600)

    def test_west_is_negative(self):
        value, _ = evidence.parse_coordinate("1 37 48 W", "lon")
        self.assertLess(value, 0)

    def test_a_sign_and_a_letter_together_are_refused(self):
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("-8 16.48 S", "lat")
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("-8.27 N", "lat")

    def test_a_letter_of_the_other_axis_is_refused(self):
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("115 35 E", "lat")
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("8 16 S", "lon")

    def test_out_of_range_is_refused(self):
        with self.assertRaises(ValueError):
            evidence.parse_coordinate(91, "lat")
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("181 0 E", "lon")
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("8 61 S", "lat")
        with self.assertRaises(ValueError):
            evidence.parse_coordinate("8 16 60 S", "lat")

    def test_rubbish_is_refused(self):
        for text in ("", "north", "8 16 28 12 S", True, None):
            with self.assertRaises(ValueError, msg=repr(text)):
                evidence.parse_coordinate(text, "lat")

    def test_an_unknown_axis_is_a_programming_error(self):
        with self.assertRaises(ValueError):
            evidence.parse_coordinate(1.0, "alt")


class DomainTest(unittest.TestCase):
    def test_registrable_domain(self):
        self.assertEqual(
            evidence.registrable_domain("https://www.padi.com/ja/x"), "padi.com"
        )
        self.assertEqual(
            evidence.registrable_domain("https://a.divers.co.uk/x"),
            "divers.co.uk",
        )
        self.assertEqual(
            evidence.registrable_domain("http://Sub.Example.ORG:8080/p?q=1"),
            "example.org",
        )
        self.assertEqual(
            evidence.registrable_domain("https://parks.gov.my/sipadan"),
            "parks.gov.my",
        )

    def test_a_url_with_no_host_is_refused(self):
        with self.assertRaises(ValueError):
            evidence.registrable_domain("not a url")

    def _lists(self, data):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "domains.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            return evidence.load_domains(path)

    def test_domain_lists(self):
        lists = self._lists({
            "counting": {"tulambenwreckdivers.com": "local operator"},
            "cite_only": {"padi.com": "directory"},
            "never": {"wrecksite.eu": "proprietary"},
        })
        self.assertEqual(
            lists.kind_of("https://tulambenwreckdivers.com/Liberty"), "counting"
        )
        self.assertEqual(lists.kind_of("https://www.padi.com/x"), "cite_only")
        self.assertEqual(lists.kind_of("https://www.wrecksite.eu/x"), "never")
        self.assertIsNone(lists.kind_of("https://example.com/x"))

    def test_a_subdomain_takes_its_parent_s_list(self):
        lists = self._lists({
            "counting": {"alertdiver.eu": "dive press"},
            "cite_only": {},
            "never": {},
        })
        self.assertEqual(
            lists.kind_of("https://shop.alertdiver.eu/x"), "counting"
        )

    def test_a_domain_on_two_lists_is_refused(self):
        with self.assertRaises(ValueError):
            self._lists({
                "counting": {"padi.com": "a"},
                "cite_only": {"padi.com": "b"},
                "never": {},
            })


class DistanceTest(unittest.TestCase):
    def test_metres_between(self):
        self.assertAlmostEqual(
            evidence.metres_between(0, 0, 0.001, 0), 111.2, delta=0.5
        )


class HazardTest(unittest.TestCase):
    def test_hazard_sentences_order(self):
        self.assertEqual(
            list(evidence.HAZARD_SENTENCES.items()),
            [
                ("strong_current", "Strong currents."),
                ("surge", "Surge in shallow water."),
                ("boat_traffic", "Boat traffic overhead."),
                ("overhead", "Overhead environment; penetration needs training."),
                ("entanglement", "Lines and nets."),
                ("cold", "Cold water."),
                ("low_visibility", "Visibility often low."),
                ("permit", "Protected area; a permit or fee may be needed."),
                ("depth", "Depth beyond recreational limits nearby."),
            ],
        )

    def test_hazards_text_joins_in_table_order(self):
        self.assertEqual(
            evidence.hazards_text(["permit", "strong_current"]),
            "Strong currents. Protected area; a permit or fee may be needed.",
        )
        self.assertIsNone(evidence.hazards_text([]))


if __name__ == "__main__":
    unittest.main()
