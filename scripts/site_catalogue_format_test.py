#!/usr/bin/env python3
"""Unit tests for site_catalogue_format.py.

Run: python3 scripts/site_catalogue_format_test.py

The built-in site catalogue (assets/data/site_catalogue.json) is written by
the harvester in one format the app reads back. These tests pin that format:
the mappings from source values to names the app knows, the depth rule, and
the version sidecar the app compares before it imports the file.
"""

import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "site_catalogue_format",
    os.path.join(_HERE, "site_catalogue_format.py"),
)
fmt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fmt)


def _record(**overrides):
    record = {
        "id": "osm_node_1",
        "name": "Somewhere Reef",
        "source": "osm",
        "trust": "verified",
    }
    record.update(overrides)
    return record


def _doc(records):
    return {
        "metadata": {"format": fmt.FORMAT, "sources": fmt.SOURCES},
        "sites": records,
    }


class EntryTest(unittest.TestCase):
    def test_entry_maps_source_values_to_app_names(self):
        self.assertEqual(fmt.map_entry("boat"), ["boat"])
        self.assertEqual(fmt.map_entry("Boat"), ["boat"])
        self.assertEqual(fmt.map_entry("shore"), ["shore"])
        for raw in ("stair", "steps", "ladder"):
            self.assertEqual(fmt.map_entry(raw), ["ladder"])
        self.assertEqual(fmt.map_entry("pier"), ["jetty"])
        for raw in ("boat:shore", "boat;shore", "boat  or shore"):
            self.assertEqual(fmt.map_entry(raw), ["boat", "shore"])
        for raw in ("stone", "yes", "", None):
            self.assertEqual(fmt.map_entry(raw), [])

    def test_an_entry_named_twice_is_listed_once(self):
        self.assertEqual(fmt.map_entry("stair;ladder"), ["ladder"])


class FeaturesTest(unittest.TestCase):
    def test_features_split_into_types_and_the_rest(self):
        types, rest = fmt.split_features(
            ["wreck", "speleology", "cave", "drift", "sharks"]
        )
        self.assertEqual(types, ["wreck", "cave"])
        self.assertEqual(rest, ["drift", "sharks"])

    def test_no_features_gives_two_empty_lists(self):
        self.assertEqual(fmt.split_features(None), ([], []))
        self.assertEqual(fmt.split_features([]), ([], []))


class DepthTest(unittest.TestCase):
    def test_a_lone_depth_is_the_maximum(self):
        self.assertEqual(fmt.normalise_depths(18.0, None), (None, 18.0))
        self.assertEqual(fmt.normalise_depths(None, 30.0), (None, 30.0))
        self.assertEqual(fmt.normalise_depths(12.0, 12.0), (None, 12.0))
        self.assertEqual(fmt.normalise_depths(15.0, 10.0), (10.0, 15.0))
        self.assertEqual(fmt.normalise_depths(3.0, 12.0), (3.0, 12.0))
        self.assertEqual(fmt.normalise_depths(None, None), (None, None))


class SourceRefTest(unittest.TestCase):
    def test_osm_ids_become_object_urls(self):
        self.assertEqual(
            fmt.osm_source_ref("osm_node_663869401"),
            "https://www.openstreetmap.org/node/663869401",
        )
        self.assertEqual(
            fmt.osm_source_ref("osm_way_24150076"),
            "https://www.openstreetmap.org/way/24150076",
        )
        self.assertEqual(
            fmt.osm_source_ref("osm_relation_7"),
            "https://www.openstreetmap.org/relation/7",
        )
        self.assertIsNone(fmt.osm_source_ref("curated_nj_vega"))


class RecordTest(unittest.TestCase):
    def test_a_legacy_record_converts(self):
        legacy = {
            "id": "osm_node_663871191",
            "name": "Teru Kaze",
            "description": "Anti-submarine boat",
            "latitude": 11.9742,
            "longitude": 120.07955,
            "max_depth": 12.0,
            "min_depth": 3.0,
            "country": "Philippines",
            "region": "Palawan",
            "website": "http://example.org/x",
            "features": ["wreck"],
            "entry_type": "boat",
            "hazards": "fairway",
        }
        record = fmt.to_catalogue_record(
            legacy,
            source="osm",
            source_ref=fmt.osm_source_ref(legacy["id"]),
            country_code="PH",
            country="Philippines",
        )
        expected = {
            "id": "osm_node_663871191",
            "name": "Teru Kaze",
            "lat": 11.9742,
            "lon": 120.07955,
            "country_code": "PH",
            "country": "Philippines",
            "region": "Palawan",
            "min_depth_m": 3.0,
            "max_depth_m": 12.0,
            "types": ["wreck"],
            "entry": ["boat"],
            "hazards": "fairway",
            "description": "Anti-submarine boat",
            "website": "http://example.org/x",
            "source": "osm",
            "source_ref": "https://www.openstreetmap.org/node/663871191",
            "trust": "verified",
        }
        self.assertEqual(record, expected)
        # Key order is part of the format: it keeps regenerated files stable.
        self.assertEqual(list(record), list(expected))

    def test_empty_and_null_fields_are_left_out(self):
        legacy = {
            "id": "osm_node_2",
            "name": "Bare",
            "description": "",
            "region": None,
            "website": None,
            "features": [],
            "ocean": "Pacific",
        }
        record = fmt.to_catalogue_record(
            legacy,
            source="osm",
            source_ref=None,
            country_code=None,
            country=None,
        )
        self.assertEqual(
            record,
            {
                "id": "osm_node_2",
                "name": "Bare",
                "source": "osm",
                "trust": "verified",
            },
        )

    def test_features_that_are_not_types_are_kept(self):
        record = fmt.to_catalogue_record(
            {"id": "osm_node_3", "name": "X", "features": ["reef", "drift"]},
            source="osm",
            source_ref=None,
            country_code=None,
            country=None,
        )
        self.assertEqual(record["types"], ["reef"])
        self.assertEqual(record["features"], ["drift"])

    def test_a_lone_legacy_depth_becomes_the_maximum(self):
        record = fmt.to_catalogue_record(
            {"id": "osm_node_4", "name": "X", "min_depth": 18.0},
            source="osm",
            source_ref=None,
            country_code=None,
            country=None,
        )
        self.assertEqual(record["max_depth_m"], 18.0)
        self.assertNotIn("min_depth_m", record)

    def test_optional_place_fields_pass_through(self):
        record = fmt.to_catalogue_record(
            {
                "id": "osm_node_5",
                "name": "X",
                "locality": "Kralendijk",
                "island": "Bonaire",
                "body_of_water": "Caribbean Sea",
                "water_type": "salt",
                "difficulty": "beginner",
            },
            source="osm",
            source_ref=None,
            country_code="BQ",
            country="Caribbean Netherlands",
        )
        self.assertEqual(record["locality"], "Kralendijk")
        self.assertEqual(record["island"], "Bonaire")
        self.assertEqual(record["body_of_water"], "Caribbean Sea")
        self.assertEqual(record["water_type"], "salt")
        self.assertEqual(record["difficulty"], "beginner")


class WebsiteTest(unittest.TestCase):
    def test_web_addresses_pass_through(self):
        self.assertEqual(
            fmt.normalise_website("https://example.org/x"),
            "https://example.org/x",
        )
        self.assertEqual(
            fmt.normalise_website(" http://example.org "), "http://example.org"
        )

    def test_a_bare_host_gets_https(self):
        self.assertEqual(
            fmt.normalise_website("www.diveabaco.com"),
            "https://www.diveabaco.com",
        )
        self.assertEqual(
            fmt.normalise_website("example.org/sites?id=1"),
            "https://example.org/sites?id=1",
        )

    def test_anything_that_is_not_a_web_address_is_dropped(self):
        # The value is an OpenStreetMap tag anyone can edit, and the app
        # opens it from a button labelled "Website".
        for raw in (
            "tel:+15551234",
            "mailto:shop@example.org",
            "javascript:alert(1)",
            "intent://scan/#Intent;scheme=zxing;end",
            "ftp://example.org/x",
            "not a link",
            "",
            None,
        ):
            self.assertIsNone(fmt.normalise_website(raw), raw)

    def test_a_record_keeps_only_a_web_address(self):
        def website(raw):
            return fmt.to_catalogue_record(
                {"id": "osm_node_1", "name": "X", "website": raw},
                source="osm",
                source_ref=None,
                country_code=None,
                country=None,
            ).get("website")

        self.assertEqual(website("www.example.org"), "https://www.example.org")
        self.assertIsNone(website("tel:+15551234"))


class ValidateTest(unittest.TestCase):
    def test_a_good_document_passes(self):
        self.assertEqual(fmt.validate_catalogue(_doc([_record()])), [])

    def test_validate_names_each_problem(self):
        problems = fmt.validate_catalogue(
            _doc(
                [
                    _record(),
                    _record(),
                    _record(id="osm_node_2", name=""),
                    _record(id="osm_node_3", source="rumour"),
                    _record(id="osm_node_4", trust="hearsay"),
                    _record(id="osm_node_5", lat=1.0),
                    _record(id="osm_node_6", types=["volcano"]),
                    _record(id="osm_node_7", entry=["teleport"]),
                    _record(id="osm_node_8", min_depth_m=20, max_depth_m=5),
                ]
            )
        )
        text = "\n".join(problems)
        self.assertIn("osm_node_1: duplicate id", text)
        self.assertIn("osm_node_2: no name", text)
        self.assertIn("osm_node_3: undeclared source 'rumour'", text)
        self.assertIn("osm_node_4: trust 'hearsay'", text)
        self.assertIn("osm_node_5: lat and lon must come together", text)
        self.assertIn("osm_node_6: unknown type 'volcano'", text)
        self.assertIn("osm_node_7: unknown entry 'teleport'", text)
        self.assertIn("osm_node_8: min_depth_m above max_depth_m", text)
        self.assertEqual(len(problems), 8)

    def test_a_website_that_is_not_a_web_address_is_a_problem(self):
        problems = fmt.validate_catalogue(
            _doc([_record(website="tel:+15551234")])
        )

        self.assertEqual(
            problems, ["osm_node_1: website is not an http(s) address"]
        )

    def test_each_source_names_its_licence_text(self):
        for key, source in fmt.SOURCES.items():
            for field in ("name", "licence", "licence_url", "credit"):
                self.assertTrue(source.get(field), f"{key}: {field}")
            self.assertTrue(
                source["licence_url"].startswith("https://"), key
            )
        for key in ("osm", "curated"):
            self.assertEqual(fmt.SOURCES[key]["licence"], "ODbL-1.0", key)
        # OpenStreetMap asks for a link to its copyright page; our own
        # records point at the licence itself.
        self.assertEqual(
            fmt.SOURCES["osm"]["licence_url"],
            "https://www.openstreetmap.org/copyright",
        )
        self.assertEqual(
            fmt.SOURCES["curated"]["licence_url"],
            "https://opendatacommons.org/licenses/odbl/1-0/",
        )

    def test_a_wrong_format_number_is_a_problem(self):
        doc = _doc([_record()])
        doc["metadata"]["format"] = 1
        self.assertIn("format", "\n".join(fmt.validate_catalogue(doc)))


class WriteTest(unittest.TestCase):
    def test_the_version_is_the_hash_of_the_written_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            fmt.write_catalogue(
                directory, [_record()], "2026-02-01T02:12:29Z"
            )
            data = (directory / "site_catalogue.json").read_bytes()
            version = (directory / "site_catalogue.version").read_text(
                encoding="utf-8"
            )
            self.assertEqual(version, hashlib.sha256(data).hexdigest())
            self.assertEqual(version, fmt.catalogue_version(data))

    def test_the_written_document_carries_its_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            fmt.write_catalogue(
                directory,
                [_record(name="Cancún")],
                "2026-02-01T02:12:29Z",
            )
            raw = (directory / "site_catalogue.json").read_text(
                encoding="utf-8"
            )
            doc = json.loads(raw)
            self.assertEqual(doc["metadata"]["format"], 2)
            self.assertEqual(
                doc["metadata"]["generated_at"], "2026-02-01T02:12:29Z"
            )
            self.assertEqual(doc["metadata"]["total_count"], 1)
            self.assertIn("Open Database License", doc["metadata"]["notice"])
            self.assertEqual(
                doc["metadata"]["sources"]["osm"]["licence"], "ODbL-1.0"
            )
            # Names are written as they are, not as escapes.
            self.assertIn("Cancún", raw)

    def test_a_document_that_does_not_validate_is_not_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            with self.assertRaises(ValueError):
                fmt.write_catalogue(
                    directory,
                    [_record(), _record()],
                    "2026-02-01T02:12:29Z",
                )
            self.assertFalse((directory / "site_catalogue.json").exists())


class KindTest(unittest.TestCase):
    def _converted(self, kind):
        return fmt.to_catalogue_record(
            {
                "id": "ukho_1",
                "name": "HMS Exeter",
                "latitude": -4.9,
                "longitude": 111.6,
                "website": "https://example.org/exeter",
            },
            source="ukho",
            source_ref="https://example.org",
            country_code="ID",
            country="Indonesia",
            kind=kind,
        )

    def test_a_register_record_carries_its_kind_and_a_site_does_not(self):
        register = self._converted("register")
        self.assertEqual(register["kind"], "register")
        keys = list(register)
        # After the website, before the source.
        self.assertEqual(keys.index("kind"), keys.index("website") + 1)
        self.assertEqual(keys.index("source"), keys.index("kind") + 1)
        self.assertNotIn("kind", self._converted("site"))

    def test_validate_rejects_an_unknown_kind(self):
        problems = fmt.validate_catalogue(_doc([_record(kind="other")]))
        self.assertEqual(problems, ["osm_node_1: kind 'other'"])

    def test_a_register_record_needs_a_position(self):
        problems = fmt.validate_catalogue(
            _doc([_record(source="ukho", kind="register")])
        )
        self.assertEqual(
            problems, ["osm_node_1: a register record needs lat and lon"]
        )
        self.assertEqual(
            fmt.validate_catalogue(
                _doc([_record(source="ukho", kind="register", lat=1, lon=2)])
            ),
            [],
        )


class SourcesTest(unittest.TestCase):
    def test_every_source_of_the_program_is_declared(self):
        self.assertEqual(
            sorted(fmt.SOURCES),
            sorted(
                [
                    "osm",
                    "curated",
                    "ukho",
                    "awois",
                    "fwc",
                    "noaa_reefs",
                    "fknms",
                    "nms_ie",
                    "wikidata",
                    "njdep",
                    "hi_dar",
                    "tpwd",
                    "nc_dmf",
                ]
            ),
        )

    def test_every_own_terms_source_states_its_terms(self):
        self.assertEqual(
            sorted(fmt.OWN_TERMS_SOURCES),
            ["hi_dar", "nc_dmf", "njdep", "tpwd"],
        )
        for key, source in fmt.SOURCES.items():
            if key in fmt.OWN_TERMS_SOURCES:
                self.assertTrue(source["own_terms"].strip(), key)
            else:
                self.assertNotIn("own_terms", source, key)

    def test_the_credits_are_the_short_names_a_site_page_shows(self):
        self.assertEqual(
            fmt.SOURCES["ukho"]["credit"], "UK Hydrographic Office"
        )
        self.assertEqual(fmt.SOURCES["ukho"]["licence"], "OGL-UK-3.0")
        self.assertEqual(fmt.SOURCES["nms_ie"]["licence"], "CC-BY-4.0")
        self.assertEqual(fmt.SOURCES["wikidata"]["licence"], "CC0-1.0")

    def test_the_notice_names_every_source_and_the_non_commercial_ones(self):
        for key, source in fmt.SOURCES.items():
            self.assertIn(source["name"], fmt.NOTICE, key)
        self.assertIn(
            "Contains public sector information, licensed under the Open "
            "Government Licence v3.0, from the UK Hydrographic Office.",
            fmt.NOTICE,
        )
        self.assertIn(
            "This application was developed using New Jersey Department of "
            "Environmental Protection Geographic Information System digital "
            "data, but this secondary product has not been verified by NJDEP "
            "and is not state-authorized or endorsed.",
            fmt.NOTICE,
        )
        self.assertIn("not for navigation", fmt.NOTICE)
        self.assertIn("may not be used commercially", fmt.NOTICE)
        self.assertIn("without alteration", fmt.NOTICE)
        self.assertIn("https://www.openstreetmap.org/copyright", fmt.NOTICE)

    def test_a_record_of_an_own_terms_source_needs_its_terms_declared(self):
        doc = _doc([_record(source="njdep", kind="register", lat=1, lon=2)])
        doc["metadata"]["sources"] = {
            "njdep": {"name": "x", "licence": "x", "credit": "x"}
        }
        self.assertEqual(
            fmt.validate_catalogue(doc),
            ["metadata: source njdep must state its own_terms"],
        )


class LinesTest(unittest.TestCase):
    def _write(self, records, **kwargs):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            fmt.write_catalogue(
                directory, records, "2026-02-01T02:12:29Z", **kwargs
            )
            return (directory / "site_catalogue.json").read_text(
                encoding="utf-8"
            )

    def test_the_file_is_one_record_per_line_sorted_by_id(self):
        raw = self._write(
            [
                _record(id="osm_node_3"),
                _record(id="osm_node_1"),
                _record(id="osm_node_2"),
            ]
        )
        doc = json.loads(raw)
        self.assertEqual(
            [site["id"] for site in doc["sites"]],
            ["osm_node_1", "osm_node_2", "osm_node_3"],
        )
        lines = raw.split("\n")
        self.assertTrue(lines[0].startswith('{"metadata":'))
        self.assertTrue(lines[0].endswith(',"sites":['))
        record_lines = lines[1:4]
        for line in record_lines:
            self.assertTrue(line.startswith('{"id":'), line)
        self.assertEqual(lines[4], "]}")
        self.assertEqual(lines[5], "")
        self.assertEqual(len(lines), 6)

    def test_open_only_leaves_out_own_terms_sources(self):
        records = [
            _record(id="ukho_1", source="ukho", kind="register", lat=1, lon=2),
            _record(
                id="njreef_1", source="njdep", kind="register", lat=1, lon=2
            ),
        ]
        full = json.loads(self._write(records))
        self.assertEqual(len(full["sites"]), 2)
        self.assertIn("njdep", full["metadata"]["sources"])

        doc = json.loads(self._write(records, open_only=True))
        self.assertEqual([s["id"] for s in doc["sites"]], ["ukho_1"])
        self.assertEqual(doc["metadata"]["total_count"], 1)
        for key in fmt.OWN_TERMS_SOURCES:
            self.assertNotIn(key, doc["metadata"]["sources"])
        self.assertNotIn(
            "may not be used commercially", doc["metadata"]["notice"]
        )
        self.assertIn("Open Database License", doc["metadata"]["notice"])


if __name__ == "__main__":
    unittest.main()
