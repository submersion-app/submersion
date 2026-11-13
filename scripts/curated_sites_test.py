#!/usr/bin/env python3
"""Unit tests for curated_sites.py.

Run: python3 scripts/curated_sites_test.py

The site catalogue is harvested from OpenStreetMap, which has gaps (no New
Jersey ocean sites at all). Curated sites fill them, and they must survive
every harvest without duplicating a site OpenStreetMap later gains.
"""

import ast
import importlib.util
import json
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "curated_sites",
    os.path.join(_HERE, "curated_sites.py"),
)
curated_sites = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(curated_sites)

_CATALOGUE = os.path.join(_HERE, "..", "assets", "data", "site_catalogue.json")


def _curated(**overrides):
    entry = {
        "id": "curated_nj_example_wreck",
        "name": "Example Wreck",
        "description": "A freighter lying in about 30 m; a boat dive.",
        "latitude": 40.05,
        "longitude": -73.95,
        "country": "United States",
        "region": "New Jersey",
        "website": None,
        "depthM": 30,
        "kind": "wreck",
        "source": "https://example.gov/wrecks",
    }
    entry.update(overrides)
    return entry


def _harvested(**overrides):
    site = {
        "id": "osm_node_1",
        "name": "Somewhere Reef",
        "lat": 12.0,
        "lon": -68.0,
        "country_code": "BQ",
        "country": "Caribbean Netherlands",
        "description": "Dive Site",
        "source": "osm",
        "source_ref": "https://www.openstreetmap.org/node/1",
        "trust": "verified",
    }
    site.update(overrides)
    return site


def _in_the_states(latitude, longitude):
    return ("US", "United States")


class MergeTest(unittest.TestCase):
    def test_appends_curated_sites_as_catalogue_records(self):
        merged = curated_sites.merge_curated(
            [_harvested()], [_curated()], _in_the_states
        )

        self.assertEqual(len(merged), 2)
        self.assertEqual(
            merged[1],
            {
                "id": "curated_nj_example_wreck",
                "name": "Example Wreck",
                "lat": 40.05,
                "lon": -73.95,
                "country_code": "US",
                "country": "United States",
                "region": "New Jersey",
                "max_depth_m": 30,
                "types": ["wreck"],
                "description": "A freighter lying in about 30 m; a boat dive.",
                "source": "curated",
                "source_ref": "https://example.gov/wrecks",
                "trust": "verified",
            },
        )

    def test_a_kind_that_is_not_a_site_type_stays_a_feature(self):
        merged = curated_sites.merge_curated(
            [], [_curated(kind="drift")], _in_the_states
        )

        self.assertNotIn("types", merged[0])
        self.assertEqual(merged[0]["features"], ["drift"])

    def test_a_site_too_far_offshore_to_geocode_keeps_its_own_country(self):
        merged = curated_sites.merge_curated(
            [], [_curated()], lambda latitude, longitude: (None, None)
        )

        self.assertEqual(merged[0]["country_code"], "US")
        self.assertEqual(merged[0]["country"], "United States")

    def test_a_shore_kind_is_the_entry_not_a_type(self):
        merged = curated_sites.merge_curated(
            [], [_curated(kind="shore")], _in_the_states
        )

        self.assertEqual(merged[0]["entry"], ["shore"])
        self.assertNotIn("types", merged[0])
        self.assertNotIn("features", merged[0])

    def test_a_curated_id_already_present_is_not_added_twice(self):
        merged = curated_sites.merge_curated(
            [_harvested(id="curated_nj_example_wreck")],
            [_curated()],
            _in_the_states,
        )

        self.assertEqual(len(merged), 1)

    def test_a_site_openstreetmap_gained_nearby_replaces_the_curated_one(self):
        osm = _harvested(name="example wreck", lat=40.051, lon=-73.951)

        merged = curated_sites.merge_curated([osm], [_curated()], _in_the_states)

        self.assertEqual([s["id"] for s in merged], ["osm_node_1"])

    def test_the_same_name_far_away_is_another_site(self):
        osm = _harvested(name="Example Wreck", lat=12.0, lon=-68.0)

        merged = curated_sites.merge_curated([osm], [_curated()], _in_the_states)

        self.assertEqual(len(merged), 2)

    def test_a_harvested_site_without_coordinates_never_replaces_one(self):
        osm = _harvested(name="Example Wreck")
        del osm["lat"], osm["lon"]

        merged = curated_sites.merge_curated([osm], [_curated()], _in_the_states)

        self.assertEqual(len(merged), 2)


class ValidateTest(unittest.TestCase):
    def test_a_good_entry_passes(self):
        self.assertEqual(curated_sites.validate([_curated()]), [])

    def test_a_country_without_a_known_code_is_a_problem(self):
        problems = curated_sites.validate([_curated(country="Atlantis")])

        self.assertIn("no code for country 'Atlantis'", "\n".join(problems))

    def test_each_problem_is_named(self):
        problems = curated_sites.validate(
            [
                _curated(id="osm_node_9"),
                _curated(id="curated_nj_a", latitude=95.0),
                _curated(id="curated_nj_b", source=""),
                _curated(id="curated_nj_c", name=""),
                _curated(id="curated_nj_c"),
            ]
        )

        joined = "\n".join(problems)
        self.assertIn("osm_node_9", joined)
        self.assertIn("curated_nj_a", joined)
        self.assertIn("curated_nj_b", joined)
        self.assertIn("duplicate", joined)
        self.assertGreaterEqual(len(problems), 5)


class ShippedDataTest(unittest.TestCase):
    def test_the_curated_file_is_valid(self):
        curated = curated_sites.load_curated()

        self.assertGreater(len(curated), 0)
        self.assertEqual(curated_sites.validate(curated), [])

    @unittest.skipUnless(
        os.path.exists(_CATALOGUE), "the catalogue file is not written yet"
    )
    def test_the_bundled_catalogue_carries_every_curated_site(self):
        with open(_CATALOGUE, encoding="utf-8") as f:
            bundled = {s["id"]: s for s in json.load(f)["sites"]}

        for entry in curated_sites.load_curated():
            self.assertIn(entry["id"], bundled)
            site = bundled[entry["id"]]
            self.assertEqual(site["name"], entry["name"])
            self.assertEqual(site["lat"], entry["latitude"])
            self.assertEqual(site["lon"], entry["longitude"])
            self.assertEqual(site["description"], entry["description"])
            self.assertEqual(site["source"], "curated")
            self.assertEqual(site["source_ref"], entry["source"])
            self.assertEqual(site["max_depth_m"], entry["depthM"])

    def test_the_harvester_merges_curated_sites_into_its_output(self):
        path = os.path.join(_HERE, "dive_site_harvester.py")
        with open(path, encoding="utf-8") as f:
            tree = ast.parse(f.read())
        calls = [
            node.func.id
            for node in ast.walk(tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        ]

        self.assertIn("merge_curated", calls)


if __name__ == "__main__":
    unittest.main()
