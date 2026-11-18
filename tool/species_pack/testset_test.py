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

    def test_a_synonym_of_a_subspecies_takes_the_species(self):
        match = {
            "usageKey": 11,
            "acceptedUsageKey": 99,
            "rank": "SPECIES",
            "status": "SYNONYM",
            "matchType": "EXACT",
            "speciesKey": 10,
        }
        self.assertEqual(testset.accepted_key(match), 10)

    def test_below_species_takes_its_species(self):
        match = {"usageKey": 12, "rank": "SUBSPECIES", "status": "ACCEPTED", "matchType": "EXACT", "speciesKey": 10}
        self.assertEqual(testset.accepted_key(match), 10)

    def test_a_species_without_a_species_key_takes_its_usage_key(self):
        match = {"usageKey": 10, "rank": "SPECIES", "status": "ACCEPTED", "matchType": "EXACT"}
        self.assertEqual(testset.accepted_key(match), 10)

    def test_a_synonym_without_a_species_key_takes_the_accepted_key(self):
        match = {"usageKey": 11, "acceptedUsageKey": 10, "rank": "SPECIES", "status": "SYNONYM", "matchType": "EXACT"}
        self.assertEqual(testset.accepted_key(match), 10)

    def test_below_species_without_a_species_key_is_none(self):
        match = {"usageKey": 12, "rank": "SUBSPECIES", "status": "ACCEPTED", "matchType": "EXACT"}
        self.assertIsNone(testset.accepted_key(match))

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

    def test_undated_observations_are_not_one_day(self):
        pool = [obs(i, day="") for i in range(3)]
        self.assertEqual(len(testset.sample(pool, 10, "s")), 3)

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

    def test_a_cell_at_the_west_edge_is_two_boxes(self):
        cell = region_grid.cell_of(-18.0, -177.5, 5)
        boxes = testset.query_boxes(cell, 1, 5)
        self.assertEqual(sorted(boxes), [(-25.0, -180.0, -10.0, -170.0), (-25.0, 175.0, -10.0, 180.0)])

    def test_a_polar_cell_stops_at_the_pole(self):
        cell = region_grid.cell_of(88.0, 0.0, 5)
        self.assertEqual(testset.query_boxes(cell, 1, 5), [(80.0, -5.0, 90.0, 10.0)])

    def test_neighbours_spanning_every_column_are_one_world_box(self):
        cell = region_grid.cell_of(12.1, 22.5, 5)
        self.assertEqual(testset.query_boxes(cell, 36, 5), [(-90.0, -180.0, 90.0, 180.0)])


class UnderwaterTests(unittest.TestCase):
    def test_more_underwater_than_dry_is_kept(self):
        scores = {p: 0.0 for p in testset.UNDERWATER_PROMPTS + testset.DRY_PROMPTS}
        scores[testset.UNDERWATER_PROMPTS[0]] = 0.6
        scores[testset.DRY_PROMPTS[0]] = 0.4
        self.assertTrue(testset.underwater(scores))
        scores[testset.DRY_PROMPTS[1]] = 0.3
        self.assertFalse(testset.underwater(scores))


class GroupTests(unittest.TestCase):
    def test_group_from_the_taxon_or_its_ancestors(self):
        self.assertEqual(testset.group_of(47113, [1, 2, 47114, 47113]), "sea snails and nudibranchs")
        self.assertEqual(testset.group_of(47178, [1, 2]), "fish")
        self.assertEqual(testset.group_of(9999, [1, 47273, 9999]), "sharks and rays")

    def test_other_animals_have_no_group(self):
        self.assertIsNone(testset.group_of(40151, [1, 2, 355675, 40151]))

    def test_groups_are_the_seven(self):
        self.assertEqual(
            testset.GROUPS,
            {
                "fish": 47178,
                "sharks and rays": 47273,
                "octopus": 47458,
                "crabs": 121639,
                "sea snails and nudibranchs": 47114,
                "sea stars": 47668,
                "coral": 47532,
            },
        )


class TopUpTests(unittest.TestCase):
    def pool(self, group, n, start):
        return [dict(obs(start + i, observer=f"{group}{i}"), group=group) for i in range(n)]

    def test_a_short_group_is_topped_up_to_the_target(self):
        natural = self.pool("octopus", 10, 0)
        pool = natural + self.pool("octopus", 400, 1000)
        extra = testset.top_ups(pool, natural, "s")
        self.assertEqual(len(extra), testset.TOP_UP - 10)
        self.assertFalse({o["id"] for o in extra} & {o["id"] for o in natural})
        self.assertTrue(all(o["group"] == "octopus" for o in extra))

    def test_fish_and_full_groups_are_left_alone(self):
        natural = self.pool("fish", 3, 0) + self.pool("crabs", testset.TOP_UP, 100)
        pool = natural + self.pool("fish", 300, 1000) + self.pool("crabs", 300, 2000)
        self.assertEqual(testset.top_ups(pool, natural, "s"), [])

    def test_a_small_pool_gives_what_it_has(self):
        pool = self.pool("coral", 20, 0)
        self.assertEqual(len(testset.top_ups(pool, [], "s")), 20)

    def test_top_ups_are_repeatable(self):
        pool = self.pool("sea stars", 400, 0)
        self.assertEqual(testset.top_ups(pool, [], "s"), testset.top_ups(list(reversed(pool)), [], "s"))


class UncheckedTests(unittest.TestCase):
    def test_ids_without_a_true_or_false_verdict(self):
        verdicts = {"a": True, "b": False, "c": None, "d": "yes"}
        self.assertEqual(testset.unchecked(["a", "b", "c", "d", "e"], verdicts), ["c", "d", "e"])

    def test_nothing_missing_is_empty(self):
        self.assertEqual(testset.unchecked(["a"], {"a": False}), [])


class CsvTests(unittest.TestCase):
    def test_round_trip_keeps_every_field(self):
        row = {f: f"v-{f}" for f in testset.FIELDS}
        row["attribution"] = "Ana, \"Reef\" photo"
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "set.csv")
            testset.write_rows(path, [row])
            self.assertEqual(testset.read_rows(path), [row])

    def test_fields_carry_group_sample_and_detector(self):
        for field in ("group", "sample", "detector", "box_x", "box_y", "box_w", "box_h"):
            self.assertIn(field, testset.FIELDS)

    def test_regions_cover_the_seven_dive_areas(self):
        self.assertEqual(len(testset.REGIONS), 7)
        for south, west, north, east in testset.REGIONS.values():
            self.assertLess(south, north)
            self.assertLess(west, east)


if __name__ == "__main__":
    unittest.main()
