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
        "description": "Dive Site",
        "latitude": 12.0,
        "longitude": -68.0,
        "country": "Nederland",
        "region": None,
        "website": None,
    }
    site.update(overrides)
    return site


class MergeTest(unittest.TestCase):
    def test_appends_curated_sites_with_only_catalogue_fields(self):
        merged = curated_sites.merge_curated([_harvested()], [_curated()])

        self.assertEqual(len(merged), 2)
        self.assertEqual(
            set(merged[1].keys()),
            set(curated_sites.CATALOGUE_FIELDS),
        )
        self.assertEqual(merged[1]["id"], "curated_nj_example_wreck")

    def test_a_curated_id_already_present_is_not_added_twice(self):
        merged = curated_sites.merge_curated(
            [_harvested(id="curated_nj_example_wreck")],
            [_curated()],
        )

        self.assertEqual(len(merged), 1)

    def test_a_site_openstreetmap_gained_nearby_replaces_the_curated_one(self):
        osm = _harvested(name="example wreck", latitude=40.051, longitude=-73.951)

        merged = curated_sites.merge_curated([osm], [_curated()])

        self.assertEqual([s["id"] for s in merged], ["osm_node_1"])

    def test_the_same_name_far_away_is_another_site(self):
        osm = _harvested(name="Example Wreck", latitude=12.0, longitude=-68.0)

        merged = curated_sites.merge_curated([osm], [_curated()])

        self.assertEqual(len(merged), 2)


class ValidateTest(unittest.TestCase):
    def test_a_good_entry_passes(self):
        self.assertEqual(curated_sites.validate([_curated()]), [])

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

    def test_the_bundled_catalogue_carries_every_curated_site(self):
        path = os.path.join(_HERE, "..", "assets", "data", "dive_sites.json")
        with open(path, encoding="utf-8") as f:
            bundled = {s["id"]: s for s in json.load(f)["sites"]}

        for entry in curated_sites.load_curated():
            self.assertIn(entry["id"], bundled)
            for field in curated_sites.CATALOGUE_FIELDS:
                self.assertEqual(bundled[entry["id"]][field], entry[field])

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
