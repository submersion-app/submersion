#!/usr/bin/env python3
"""Unit tests for overlap.py.

Run: python3 scripts/site_catalogue/overlap_test.py

Nine sources list some of the same wrecks and reefs. These tests pin when
two records are one site, which of them survives, what the survivor takes
from the other, and the two things that must never happen: a dive site id
a diver may hold being merged away, and a field passing between an
own-terms record and an ODbL one.
"""

import os
import random
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import overlap  # noqa: E402
import records as rec  # noqa: E402

# One metre of latitude, in degrees.
_M = 1 / 111195.0


def _r(source, record_id, name, *, north=0.0, kind="register",
       types=("wreck",), **extra):
    return rec.working(
        id=record_id, name=name, lat=50.0 + north * _M, lon=-1.0,
        source=source, kind=kind, types=types, **extra,
    )


def _site(source, record_id, name, **extra):
    extra.setdefault("types", ())
    return _r(source, record_id, name, kind="site", **extra)


def _ids(records):
    return sorted(record["id"] for record in records)


class SameSiteTest(unittest.TestCase):
    def test_the_same_name_within_two_kilometres(self):
        ukho = _r("ukho", "ukho_1", "HMS Exeter")
        self.assertTrue(
            overlap.same_site(ukho, _r("osm", "osm_node_1", "Exeter", north=1500))
        )
        self.assertFalse(
            overlap.same_site(ukho, _r("osm", "osm_node_1", "Exeter", north=2500))
        )

    def test_a_generic_name_needs_to_be_almost_on_top(self):
        barge = _r("ukho", "ukho_1", "Barge", types=())
        self.assertFalse(
            overlap.same_site(barge, _r("awois", "awois_1", "Barge", north=500, types=()))
        )
        self.assertTrue(
            overlap.same_site(barge, _r("awois", "awois_1", "Barge", north=150, types=()))
        )

    def test_a_name_that_begins_with_another_is_another_site(self):
        self.assertFalse(
            overlap.same_site(
                _r("njdep", "njreef_1", "Cape May Reef, Laita", types=()),
                _r("fwc", "fwc_1", "Cape May Reef", north=190, types=()),
            )
        )

    def test_two_wrecks_from_two_sources_in_one_place(self):
        ukho = _r("ukho", "ukho_1", "Unnamed Coaster A")
        self.assertTrue(
            overlap.same_site(ukho, _r("awois", "awois_1", "Mary Ann", north=80))
        )
        self.assertFalse(
            overlap.same_site(ukho, _r("awois", "awois_1", "Mary Ann", north=120))
        )

    def test_two_wrecks_of_one_source_are_two_wrecks(self):
        self.assertFalse(
            overlap.same_site(
                _r("ukho", "ukho_1", "Alpha"), _r("ukho", "ukho_2", "Beta", north=80)
            )
        )

    def test_a_reef_and_a_wreck_in_one_place_are_two_sites(self):
        self.assertFalse(
            overlap.same_site(
                _r("ukho", "ukho_1", "Alpha"),
                _r("fwc", "fwc_1", "Beta Reef", north=50, types=("artificial_reef",)),
            )
        )

    def test_a_record_without_a_position_matches_nothing(self):
        nowhere = rec.working(
            id="osm_node_9", name="Exeter", lat=None, lon=None,
            source="osm", kind="site",
        )
        self.assertFalse(overlap.same_site(nowhere, _r("ukho", "ukho_1", "Exeter")))


class DiveSiteSourcesTest(unittest.TestCase):
    def test_openstreetmap_dive_sites_are_never_merged_with_each_other(self):
        kept, dropped = overlap.resolve([
            _site("osm", "osm_node_1", "Portsea Pier"),
            _site("osm", "osm_node_2", "Portsea Pier", north=50),
            _site("osm", "osm_node_3", "Wreck Alpha", types=("wreck",)),
            _site("osm", "osm_node_4", "Wreck Beta", north=60, types=("wreck",)),
        ])
        self.assertEqual(len(kept), 4)
        self.assertEqual(sum(dropped.values()), 0)

    def test_curated_sites_are_never_merged_with_each_other(self):
        kept, _ = overlap.resolve([
            _site("curated", "curated_a", "Mohawk"),
            _site("curated", "curated_b", "Mohawk", north=50),
        ])
        self.assertEqual(len(kept), 2)

    def test_a_curated_site_steps_aside_for_openstreetmap_as_before(self):
        osm = _site("osm", "osm_node_1", "hilma hooker")
        kept, dropped = overlap.resolve(
            [_site("curated", "curated_a", "Hilma Hooker", north=900), osm]
        )
        self.assertEqual(_ids(kept), ["osm_node_1"])
        self.assertEqual(dict(dropped), {("curated", "osm"): 1})
        kept, _ = overlap.resolve(
            [_site("curated", "curated_a", "Hilma Hooker", north=1100), osm]
        )
        self.assertEqual(len(kept), 2)

    def test_a_curated_site_is_not_folded_into_a_differently_written_name(self):
        # The existing rule compares names ignoring case only.
        kept, _ = overlap.resolve([
            _site("curated", "curated_a", "The Hilma Hooker wreck", north=100),
            _site("osm", "osm_node_1", "Hilma Hooker"),
        ])
        self.assertEqual(len(kept), 2)


class SurvivorTest(unittest.TestCase):
    def _winner(self, *records):
        kept, _ = overlap.resolve(list(records))
        self.assertEqual(len(kept), 1)
        return kept[0]["id"]

    def test_the_order_of_survivors(self):
        name = "Alpha"
        chain = [
            _site("osm", "osm_node_1", name, types=("wreck",)),
            _site("fknms", "fknms_alpha", name, types=("wreck",)),
            _site("wikidata", "wikidata_Q1", name, types=("wreck",)),
            _r("fwc", "fwc_1", name),
            _r("noaa_reefs", "usreef_al_alpha", name),
            _r("ukho", "ukho_1", name),
            _r("awois", "awois_1", name),
            _r("nms_ie", "ie_W1", name),
            _r("osm", "osm_node_2", name),
            _r("wikidata", "wikidata_Q2", name),
            _r("njdep", "njreef_1", name),
        ]
        for i in range(len(chain) - 1):
            self.assertEqual(
                self._winner(chain[i + 1], chain[i]), chain[i]["id"], chain[i]["id"]
            )
        # Curated sits between OpenStreetMap dive sites and the rest.
        self.assertEqual(
            self._winner(
                _r("ukho", "ukho_1", name), _site("curated", "curated_a", name)
            ),
            "curated_a",
        )

    def test_within_one_source_the_lower_id_wins(self):
        self.assertEqual(
            self._winner(_r("ukho", "ukho_20", "Alpha"), _r("ukho", "ukho_100", "Alpha")),
            "ukho_100",
        )

    def test_the_answer_does_not_depend_on_the_order_of_the_input(self):
        records = [
            _site("osm", "osm_node_1", "Alpha", types=("wreck",)),
            _r("ukho", "ukho_1", "Alpha", north=40, max_depth=30),
            _r("awois", "awois_1", "Alpha", north=90),
            _r("ukho", "ukho_2", "Beta", north=5000),
            _r("nms_ie", "ie_W1", "Beta", north=5300),
        ]
        expected = overlap.resolve(records)[0]
        for seed in range(5):
            shuffled = list(records)
            random.Random(seed).shuffle(shuffled)
            self.assertEqual(overlap.resolve(shuffled)[0], expected)
        self.assertEqual(_ids(expected), ["osm_node_1", "ukho_2"])


class TakingTest(unittest.TestCase):
    def test_the_survivor_takes_only_what_it_lacks(self):
        osm = _site(
            "osm", "osm_node_1", "Exeter", types=("reef",),
            description="A fine dive.", source_ref="https://osm.example/1",
        )
        ukho = _r(
            "ukho", "ukho_1", "HMS EXETER", north=300, max_depth=55.0,
            min_depth=40.0, description="Heavy cruiser, lost 1942",
            hazards="Restricted area.",
        )
        kept, dropped = overlap.resolve([ukho, osm])
        self.assertEqual(dict(dropped), {("ukho", "osm"): 1})
        survivor = kept[0]
        self.assertEqual(survivor["id"], "osm_node_1")
        self.assertEqual(survivor["name"], "Exeter")
        self.assertEqual(survivor["kind"], "site")
        self.assertEqual(survivor["source"], "osm")
        self.assertEqual(survivor["source_ref"], "https://osm.example/1")
        self.assertEqual(survivor["lat"], 50.0)
        self.assertEqual(survivor["max_depth"], 55.0)
        self.assertEqual(survivor["min_depth"], 40.0)
        # A type it has stands: the other's is not added to it.
        self.assertEqual(survivor["types"], ["reef"])
        self.assertEqual(survivor["description"], "A fine dive.")
        self.assertEqual(survivor["hazards"], "Restricted area.")

    def test_a_survivor_with_no_type_takes_the_other_s(self):
        osm = _site("osm", "osm_node_1", "Exeter")
        ukho = _r("ukho", "ukho_1", "HMS EXETER", north=300)
        kept, _ = overlap.resolve([ukho, osm])
        self.assertEqual(kept[0]["types"], ["wreck"])

    def test_a_curated_site_that_steps_aside_gives_nothing(self):
        # That rule is older than the registers and stays as it was: the
        # OpenStreetMap record ships as OpenStreetMap wrote it.
        osm = _site("osm", "osm_node_1", "Hilma Hooker")
        curated = _site(
            "curated", "curated_a", "Hilma Hooker", north=400,
            types=("wreck",), max_depth=30.0, description="A drug runner.",
        )
        kept, dropped = overlap.resolve([curated, osm])
        self.assertEqual(dict(dropped), {("curated", "osm"): 1})
        survivor = kept[0]
        self.assertEqual(survivor["id"], "osm_node_1")
        self.assertIsNone(survivor["max_depth"])
        self.assertIsNone(survivor["description"])
        self.assertEqual(survivor["types"], [])

    def test_a_depth_the_survivor_has_is_never_overwritten(self):
        kept, _ = overlap.resolve([
            _site("osm", "osm_node_1", "Exeter", max_depth=20.0),
            _r("ukho", "ukho_1", "Exeter", max_depth=55.0, min_depth=40.0),
        ])
        self.assertEqual(kept[0]["max_depth"], 20.0)
        # A minimum deeper than the survivor's own maximum is not taken.
        self.assertIsNone(kept[0]["min_depth"])

    def test_the_input_records_are_not_changed(self):
        osm = _site("osm", "osm_node_1", "Exeter")
        overlap.resolve([osm, _r("ukho", "ukho_1", "Exeter", max_depth=55.0)])
        self.assertIsNone(osm["max_depth"])
        self.assertEqual(osm["types"], [])


class OwnTermsTest(unittest.TestCase):
    def test_an_own_terms_record_is_left_out_whole_on_a_match(self):
        curated = _site("curated", "curated_nj_mohawk", "Mohawk", types=("wreck",))
        nj = _r("njdep", "njreef_5", "Mohawk", north=200,
                types=("artificial_reef", "wreck"),
                description="Ship, placed 1990", locality="Sea Girt Reef")
        kept, dropped = overlap.resolve([nj, curated])
        self.assertEqual(dict(dropped), {("njdep", "curated"): 1})
        self.assertEqual(kept, [curated])

    def test_an_own_terms_record_gives_nothing_to_a_register_record(self):
        ukho = _r("ukho", "ukho_1", "Mohawk")
        nj = _r("njdep", "njreef_5", "Mohawk", north=200, max_depth=20.0,
                hazards="x", description="Ship, placed 1990")
        kept, _ = overlap.resolve([nj, ukho])
        self.assertEqual(kept, [ukho])

    def test_own_terms_records_of_one_source_are_never_merged(self):
        kept, _ = overlap.resolve([
            _r("nc_dmf", "ncreef_ar_130", "AR-130", types=("artificial_reef",)),
            _r("nc_dmf", "ncreef_ar_131", "AR-130", north=50,
               types=("artificial_reef",)),
        ])
        self.assertEqual(len(kept), 2)

    def test_two_own_terms_sources_do_not_blend_either(self):
        kept, dropped = overlap.resolve([
            _r("njdep", "njreef_5", "Shared Wreck", max_depth=None),
            _r("tpwd", "usreef_tx_shared", "Shared Wreck", north=100,
               max_depth=25.0),
        ])
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["id"], "njreef_5")
        self.assertIsNone(kept[0]["max_depth"])

    def test_every_source_has_a_rank(self):
        ranked = {source for source, _ in overlap.RANK}
        for source in overlap.OWN_TERMS_SOURCES:
            self.assertIn(source, ranked)
        with self.assertRaises(ValueError):
            overlap.resolve([_r("mystery", "x_1", "Alpha")])


class ScaleTest(unittest.TestCase):
    def test_a_match_is_found_across_the_antimeridian(self):
        def wreck(source, record_id, lon):
            return rec.working(
                id=record_id, name="Tui Tai", lat=-17.0, lon=lon,
                source=source, kind="register", types=("wreck",),
            )

        # 85 metres apart, on either side of 180 degrees.
        kept, _ = overlap.resolve(
            [wreck("ukho", "ukho_1", 179.9996), wreck("awois", "awois_1", -179.9996)]
        )
        self.assertEqual(_ids(kept), ["ukho_1"])

    def test_a_match_is_found_at_high_latitude_and_across_cells(self):
        def at(source, record_id, lat, lon):
            return rec.working(
                id=record_id, name="Alpha", lat=lat, lon=lon, source=source,
                kind="register", types=["wreck"],
            )
        # 1.5 km apart along the 78th parallel: 0.065 degrees of longitude.
        kept, _ = overlap.resolve(
            [at("ukho", "ukho_1", 78.0, 15.0), at("awois", "awois_1", 78.0, 15.065)]
        )
        self.assertEqual(_ids(kept), ["ukho_1"])
        # Either side of a cell boundary and of the equator.
        kept, _ = overlap.resolve(
            [at("ukho", "ukho_1", 0.004, 9.9995), at("awois", "awois_1", -0.004, 10.0005)]
        )
        self.assertEqual(_ids(kept), ["ukho_1"])


if __name__ == "__main__":
    unittest.main()
