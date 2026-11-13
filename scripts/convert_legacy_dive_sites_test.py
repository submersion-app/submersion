#!/usr/bin/env python3
"""Unit tests for convert_legacy_dive_sites.py.

Run: python3 scripts/convert_legacy_dive_sites_test.py

The one-off conversion of assets/data/dive_sites.json into the site
catalogue. It goes away with the legacy file once the app reads the
catalogue.
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "convert_legacy_dive_sites",
    os.path.join(_HERE, "convert_legacy_dive_sites.py"),
)
conv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(conv)


class ConvertTest(unittest.TestCase):
    def test_located_records_take_their_country_from_the_lookup(self):
        doc = {
            "sites": [
                {
                    "id": "osm_node_1",
                    "name": "Salt Pier",
                    "latitude": 12.08,
                    "longitude": -68.28,
                    "country": "Nederland",
                }
            ]
        }

        out = conv.convert(
            doc, [], lambda lat, lon: ("BQ", "Caribbean Netherlands")
        )

        self.assertEqual(out[0]["country_code"], "BQ")
        self.assertEqual(out[0]["country"], "Caribbean Netherlands")
        self.assertEqual(
            out[0]["source_ref"], "https://www.openstreetmap.org/node/1"
        )
        self.assertEqual(out[0]["source"], "osm")

    def test_a_located_record_at_sea_has_no_country(self):
        doc = {
            "sites": [
                {
                    "id": "osm_node_1",
                    "name": "Far Out",
                    "latitude": 0.0,
                    "longitude": -30.0,
                    "country": "Somewhere",
                }
            ]
        }

        out = conv.convert(doc, [], lambda lat, lon: (None, None))

        self.assertNotIn("country_code", out[0])
        self.assertNotIn("country", out[0])

    def test_a_record_without_coordinates_keeps_a_two_letter_code_only(self):
        doc = {
            "sites": [
                {"id": "osm_way_2", "name": "A", "country": "CW"},
                {"id": "osm_way_3", "name": "B", "country": "Deutschland"},
                {"id": "osm_way_4", "name": "C"},
            ]
        }

        out = conv.convert(doc, [], lambda lat, lon: self.fail("no lookup"))

        self.assertEqual(out[0]["country_code"], "CW")
        self.assertEqual(out[0]["country"], conv.CODE_NAMES["CW"])
        self.assertNotIn("country_code", out[1])
        self.assertNotIn("country", out[1])
        self.assertNotIn("country", out[2])

    def test_regions_are_left_as_they_are(self):
        doc = {
            "sites": [
                {
                    "id": "osm_node_5",
                    "name": "X",
                    "latitude": 27.0,
                    "longitude": 34.0,
                    "country": "مصر",
                    "region": "البحر الأحمر",
                }
            ]
        }

        out = conv.convert(doc, [], lambda lat, lon: ("EG", "Egypt"))

        self.assertEqual(out[0]["region"], "البحر الأحمر")

    def test_curated_records_carry_their_source_depth_and_kind(self):
        curated = [
            {
                "id": "curated_nj_vega",
                "name": "Vega",
                "description": "d",
                "latitude": 40.1941,
                "longitude": -73.9464,
                "country": "United States",
                "region": "New Jersey",
                "website": None,
                "depthM": 17,
                "kind": "wreck",
                "source": "https://njscuba.net/x",
            }
        ]
        doc = {
            "sites": [
                {
                    "id": "curated_nj_vega",
                    "name": "Vega",
                    "latitude": 40.1941,
                    "longitude": -73.9464,
                    "country": "United States",
                    "region": "New Jersey",
                }
            ]
        }

        out = conv.convert(
            doc, curated, lambda lat, lon: ("US", "United States")
        )

        self.assertEqual(out[0]["source"], "curated")
        self.assertEqual(out[0]["source_ref"], "https://njscuba.net/x")
        self.assertEqual(out[0]["max_depth_m"], 17)
        self.assertEqual(out[0]["types"], ["wreck"])
        self.assertEqual(out[0]["country_code"], "US")

    def test_a_curated_id_missing_from_the_curated_file_is_an_error(self):
        doc = {"sites": [{"id": "curated_nj_gone", "name": "Gone"}]}

        with self.assertRaises(KeyError):
            conv.convert(doc, [], lambda lat, lon: ("US", "United States"))

    def test_order_and_count_are_kept(self):
        doc = {
            "sites": [
                {"id": "osm_node_2", "name": "B"},
                {"id": "osm_node_1", "name": "A"},
            ]
        }

        out = conv.convert(doc, [], lambda lat, lon: (None, None))

        self.assertEqual([r["id"] for r in out], ["osm_node_2", "osm_node_1"])


if __name__ == "__main__":
    unittest.main()
