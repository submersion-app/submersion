#!/usr/bin/env python3
"""Unit tests for testset.py, the rules that choose the accuracy test
photos."""

import importlib.util
import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("testset", os.path.join(_HERE, "testset.py"))
testset = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(testset)
import region_grid  # noqa: E402


def obs(i, observer="a", day="2025-01-01", region="caribbean"):
    return {"id": str(i), "observer": observer, "observed_on": day, "region": region}


class NameTests(unittest.TestCase):
    def test_below_species_is_its_species(self):
        self.assertEqual(testset.species_name("Holacanthus ciliaris ciliaris", "subspecies"), "Holacanthus ciliaris")
        self.assertEqual(testset.species_name("Holacanthus ciliaris", "species"), "Holacanthus ciliaris")

    def test_above_species_is_dropped(self):
        self.assertIsNone(testset.species_name("Holacanthus", "genus"))
        self.assertIsNone(testset.species_name("Holacanthus ciliaris x tricolor", "hybrid"))


class AcceptedKeyTests(unittest.TestCase):
    def test_an_accepted_species(self):
        match = {"usageKey": 10, "rank": "SPECIES", "status": "ACCEPTED", "matchType": "EXACT", "speciesKey": 10}
        self.assertEqual(testset.accepted_key(match), 10)

    def test_a_synonym_takes_the_accepted_key(self):
        match = {
            "usageKey": 11,
            "acceptedUsageKey": 10,
            "rank": "SPECIES",
            "status": "SYNONYM",
            "matchType": "EXACT",
            "speciesKey": 10,
        }
        self.assertEqual(testset.accepted_key(match), 10)

    def test_below_species_takes_its_species(self):
        match = {"usageKey": 12, "rank": "SUBSPECIES", "status": "ACCEPTED", "matchType": "EXACT", "speciesKey": 10}
        self.assertEqual(testset.accepted_key(match), 10)

    def test_no_match_or_a_higher_rank_is_none(self):
        self.assertIsNone(testset.accepted_key({"matchType": "NONE"}))
        self.assertIsNone(
            testset.accepted_key({"usageKey": 5, "rank": "GENUS", "status": "ACCEPTED", "matchType": "HIGHERRANK"})
        )


class SampleTests(unittest.TestCase):
    def test_sample_is_repeatable(self):
        pool = [obs(i, observer=str(i)) for i in range(100)]
        self.assertEqual(testset.sample(pool, 10, "s"), testset.sample(list(reversed(pool)), 10, "s"))
        self.assertNotEqual(testset.sample(pool, 10, "s"), testset.sample(pool, 10, "t"))

    def test_one_per_observer_per_day(self):
        pool = [obs(i) for i in range(5)] + [obs(9, day="2025-01-02")]
        picked = testset.sample(pool, 10, "s")
        self.assertEqual(len(picked), 2)
        self.assertEqual({p["observed_on"] for p in picked}, {"2025-01-01", "2025-01-02"})


class SplitTests(unittest.TestCase):
    def test_tune_half_is_repeatable_and_split_within_each_region(self):
        rows = [obs(i, region="red-sea") for i in range(7)] + [obs(i + 100, region="hawaii") for i in range(4)]
        tune = testset.tune_ids(rows)
        self.assertEqual(tune, testset.tune_ids(list(reversed(rows))))
        self.assertEqual(sum(1 for r in rows if r["region"] == "red-sea" and r["id"] in tune), 4)
        self.assertEqual(sum(1 for r in rows if r["region"] == "hawaii" and r["id"] in tune), 2)

    def test_rows_sharing_an_id_stay_together(self):
        rows = [obs(1, region="junk"), obs(1, region="junk"), obs(2, region="junk")]
        tune = testset.tune_ids(rows)
        self.assertEqual(len(tune), 1)


class LicenceTests(unittest.TestCase):
    def test_commons_licences(self):
        self.assertEqual(testset.commons_licence("CC BY-SA 4.0"), "cc-by-sa")
        self.assertEqual(testset.commons_licence("CC BY 2.0"), "cc-by")
        self.assertEqual(testset.commons_licence("CC0"), "cc0")
        self.assertEqual(testset.commons_licence("Public domain"), "pd")
        self.assertIsNone(testset.commons_licence("CC BY-NC 2.0"))
        self.assertIsNone(testset.commons_licence("CC BY-NC-SA 4.0"))
        self.assertIsNone(testset.commons_licence(""))


class QueryBoxTests(unittest.TestCase):
    def test_an_interior_cell_is_one_box(self):
        cell = region_grid.cell_of(12.1, -68.3, 5)
        self.assertEqual(testset.query_boxes(cell, 1, 5), [(5.0, -75.0, 20.0, -60.0)])

    def test_a_cell_at_the_antimeridian_is_two_boxes(self):
        cell = region_grid.cell_of(-18.0, 177.5, 5)
        boxes = testset.query_boxes(cell, 1, 5)
        self.assertEqual(sorted(boxes), [(-25.0, -180.0, -10.0, -175.0), (-25.0, 170.0, -10.0, 180.0)])

    def test_a_polar_cell_stops_at_the_pole(self):
        cell = region_grid.cell_of(88.0, 0.0, 5)
        self.assertEqual(testset.query_boxes(cell, 1, 5), [(80.0, -5.0, 90.0, 10.0)])


class UnderwaterTests(unittest.TestCase):
    def test_more_underwater_than_dry_is_kept(self):
        scores = {p: 0.0 for p in testset.UNDERWATER_PROMPTS + testset.DRY_PROMPTS}
        scores[testset.UNDERWATER_PROMPTS[0]] = 0.6
        scores[testset.DRY_PROMPTS[0]] = 0.4
        self.assertTrue(testset.underwater(scores))
        scores[testset.DRY_PROMPTS[1]] = 0.3
        self.assertFalse(testset.underwater(scores))


class CsvTests(unittest.TestCase):
    def test_round_trip_keeps_every_field(self):
        row = {f: f"v-{f}" for f in testset.FIELDS}
        row["attribution"] = "Ana, \"Reef\" photo"
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "set.csv")
            testset.write_rows(path, [row])
            self.assertEqual(testset.read_rows(path), [row])

    def test_regions_cover_the_seven_dive_areas(self):
        self.assertEqual(len(testset.REGIONS), 7)
        for south, west, north, east in testset.REGIONS.values():
            self.assertLess(south, north)
            self.assertLess(west, east)


if __name__ == "__main__":
    unittest.main()
