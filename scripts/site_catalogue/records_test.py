#!/usr/bin/env python3
"""Unit tests for records.py.

Run: python3 scripts/site_catalogue/records_test.py

Every catalogue source hands the merge the same working record, and two
sources name one wreck differently ("HMS EXETER", "Exeter (wreck)"). These
tests pin the record's shape and the name rules the overlap check and the
shipped names rest on.
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import records  # noqa: E402


class FoldNameTest(unittest.TestCase):
    def test_a_ship_prefix_and_case_are_dropped(self):
        self.assertEqual(records.fold_name("HMS EXETER"), "exeter")
        self.assertEqual(records.fold_name("S.S. Thistlegorm"), "thistlegorm")

    def test_bracketed_text_is_dropped(self):
        self.assertEqual(records.fold_name("Moravia (possibly)"), "moravia")
        self.assertEqual(
            records.fold_name("HMS WAVERLEY (BOW SECTION)"), "waverley"
        )

    def test_accents_and_a_leading_wreck_word_are_dropped(self):
        self.assertEqual(records.fold_name("Épave du Liban"), "du liban")
        self.assertEqual(records.fold_name("Wreck of the Rhone"), "rhone")

    def test_a_trailing_reef_or_wreck_is_dropped(self):
        self.assertEqual(records.fold_name("Molasses Reef"), "molasses")
        self.assertEqual(records.fold_name("Hilma Hooker wreck"), "hilma hooker")

    def test_a_name_that_is_only_a_dropped_word_stays(self):
        # "The Wreck" must not fold to nothing and match every other one.
        self.assertEqual(records.fold_name("Reef"), "reef")


class DisplayNameTest(unittest.TestCase):
    def test_an_upper_case_name_is_title_cased(self):
        self.assertEqual(records.display_name("HMS EXETER"), "HMS Exeter")
        self.assertEqual(
            records.display_name("SAMUDRA JAYA V"), "Samudra Jaya V"
        )
        self.assertEqual(records.display_name("JEAN-PIERRE"), "Jean-Pierre")

    def test_designations_stay_as_written(self):
        self.assertEqual(records.display_name("U 11"), "U 11")
        self.assertEqual(records.display_name("TB. TECE-1"), "TB. Tece-1")
        self.assertEqual(records.display_name("LCT 7074"), "LCT 7074")

    def test_the_register_s_doubt_is_lower_cased(self):
        self.assertEqual(
            records.display_name("HMS MORAVIA (POSSIBLY)"),
            "HMS Moravia (possibly)",
        )

    def test_a_mixed_case_name_is_left_alone(self):
        self.assertEqual(records.display_name("Salt Pier"), "Salt Pier")
        self.assertEqual(records.display_name("  Salt Pier "), "Salt Pier")


class WordListTest(unittest.TestCase):
    def test_placeholders(self):
        for name in ("UNKNOWN", "Wreck", "Unnamed Barge 1", "Obstruction",
                     "", "  ", "unidentified", "Unknown (Deadlight)"):
            self.assertTrue(records.is_placeholder(name), name)
        for name in ("Barge 12", "Soldier Reef", "Salt Pier"):
            self.assertFalse(records.is_placeholder(name), name)
        self.assertTrue(records.is_placeholder("BARGE"))

    def test_generic_names(self):
        self.assertTrue(records.is_generic("tug"))
        self.assertTrue(records.is_generic("abc"))
        self.assertTrue(records.is_generic("fishing vessel"))
        self.assertFalse(records.is_generic("thistlegorm"))


class UnitsTest(unittest.TestCase):
    def test_feet_and_fathoms_become_metres(self):
        self.assertEqual(round(records.feet(145), 1), 44.2)
        self.assertEqual(round(records.fathoms(10), 1), 18.3)

    def test_km_is_a_great_circle_distance(self):
        # One degree of latitude.
        self.assertAlmostEqual(records.km(0, 0, 1, 0), 111.19, places=1)
        # Across the antimeridian the short way round.
        self.assertLess(records.km(0, 179.95, 0, -179.95), 12)

    def test_slug(self):
        self.assertEqual(records.slug("The Spiegel Grove"), "the_spiegel_grove")
        self.assertEqual(records.slug("AR-130"), "ar_130")
        self.assertEqual(records.slug("  Épave #2 "), "epave_2")

    def test_number_reads_what_a_register_writes(self):
        self.assertEqual(records.number("12.5"), 12.5)
        self.assertEqual(records.number(" 7 "), 7.0)
        for raw in ("", None, "UNKNOWN", "n/a", "N"):
            self.assertIsNone(records.number(raw), raw)


class WorkingTest(unittest.TestCase):
    def _working(self, **overrides):
        values = dict(
            id="ukho_1", name="HMS Exeter", lat=-4.9021284, lon=111.5775,
            source="ukho", kind="register",
        )
        values.update(overrides)
        return records.working(**values)

    def test_the_record_has_every_key_the_merge_reads(self):
        record = self._working()
        self.assertEqual(
            sorted(record),
            sorted([
                "id", "name", "lat", "lon", "source", "kind", "source_ref",
                "types", "max_depth", "min_depth", "description", "hazards",
                "locality", "region", "website", "entry_type", "features",
                "water_type", "geocoded",
            ]),
        )
        self.assertEqual(record["types"], [])
        self.assertEqual(record["features"], [])
        self.assertEqual(record["lat"], -4.902128)

    def test_a_depth_of_zero_is_no_depth(self):
        self.assertIsNone(self._working(max_depth=0)["max_depth"])
        self.assertIsNone(self._working(min_depth=-1)["min_depth"])
        self.assertEqual(self._working(max_depth=12.34)["max_depth"], 12.3)

    def test_a_site_may_have_no_position(self):
        record = self._working(lat=None, lon=None, kind="site")
        self.assertIsNone(record["lat"])
        self.assertIsNone(record["lon"])

    def test_an_unknown_kind_is_refused(self):
        with self.assertRaises(ValueError):
            self._working(kind="other")


if __name__ == "__main__":
    unittest.main()
