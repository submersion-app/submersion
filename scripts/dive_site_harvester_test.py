#!/usr/bin/env python3
"""Unit tests for dive_site_harvester.py.

Run: python3 scripts/dive_site_harvester_test.py

These cover the metadata build stamp. The harvester writes `generated_at`
into two shipped assets, and the conventional-looking `isoformat() + "Z"`
produces a string no ISO-8601 parser accepts, so the stamp is worthless to
anyone who later wants to know how stale the bundled data is.
"""

import importlib.util
import ast
import os
import unittest
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))
_SOURCE = os.path.join(_HERE, "dive_site_harvester.py")

try:
    import overpy  # noqa: F401
    import requests  # noqa: F401
    import tenacity  # noqa: F401
    import tqdm  # noqa: F401

    _HAS_DEPS = True
except ImportError:  # pragma: no cover - exercised only on bare runners
    _HAS_DEPS = False

if _HAS_DEPS:
    _spec = importlib.util.spec_from_file_location(
        "dive_site_harvester",
        _SOURCE,
    )
    dive_site_harvester = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(dive_site_harvester)


@unittest.skipUnless(_HAS_DEPS, "the harvester's dependencies are not installed")
class UtcTimestampTest(unittest.TestCase):
    def test_stamps_a_timestamp_that_actually_parses(self):
        # isoformat() already writes "+00:00", so appending "Z" would give
        # "...+00:00Z" and every ISO-8601 parser would reject it.
        stamp = dive_site_harvester.utc_timestamp()

        self.assertTrue(stamp.endswith("Z"), stamp)
        self.assertNotIn("+00:00", stamp)
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        self.assertEqual(parsed.tzinfo, timezone.utc)

    def test_stamps_the_current_instant(self):
        before = datetime.now(timezone.utc).replace(microsecond=0)
        stamp = dive_site_harvester.utc_timestamp()
        after = datetime.now(timezone.utc)

        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        self.assertGreaterEqual(parsed, before)
        self.assertLessEqual(parsed, after)


class _FixedCountry:
    """Stands in for the country resolver, which would ask the network."""

    def __init__(self, answer):
        self.answer = answer
        self.asked = []

    def lookup(self, latitude, longitude):
        self.asked.append((latitude, longitude))
        return self.answer


@unittest.skipUnless(_HAS_DEPS, "the harvester's dependencies are not installed")
class TransformTest(unittest.TestCase):
    def _with_country(self, answer):
        resolver = _FixedCountry(answer)
        original = dive_site_harvester.country_resolver
        dive_site_harvester.country_resolver = resolver
        self.addCleanup(
            setattr, dive_site_harvester, "country_resolver", original
        )
        return resolver

    def test_an_osm_site_becomes_a_catalogue_record(self):
        resolver = self._with_country(("BQ", "Caribbean Netherlands"))

        record = dive_site_harvester.transform_to_catalogue_record(
            {
                "osm_id": 663869401,
                "osm_type": "node",
                "tags": {"name": "Salt Pier", "description": "Pillars."},
                "geometry": {"type": "Point", "coordinates": [-68.28, 12.08]},
                "address": {"country": "Nederland", "state": "Bonaire"},
                "contact": {"website": "https://example.org"},
                "dive_attributes": {
                    "depth": "15 m",
                    "entry_type": "shore",
                    "hazards": "boat traffic",
                    "site_types": ["reef", "sharks"],
                    "drift_diving": True,
                },
            }
        )

        self.assertEqual(resolver.asked, [(12.08, -68.28)])
        self.assertEqual(
            record,
            {
                "id": "osm_node_663869401",
                "name": "Salt Pier",
                "lat": 12.08,
                "lon": -68.28,
                "country_code": "BQ",
                "country": "Caribbean Netherlands",
                "region": "Bonaire",
                "max_depth_m": 15.0,
                "types": ["reef"],
                "entry": ["shore"],
                "features": ["sharks", "drift"],
                "hazards": "boat traffic",
                "description": "Pillars.",
                "website": "https://example.org",
                "source": "osm",
                "source_ref": "https://www.openstreetmap.org/node/663869401",
                "trust": "verified",
            },
        )

    def test_a_site_without_coordinates_keeps_a_two_letter_country_code(self):
        resolver = self._with_country(("XX", "Never asked"))

        record = dive_site_harvester.transform_to_catalogue_record(
            {
                "osm_id": 7,
                "osm_type": "way",
                "tags": {"name": "Somewhere"},
                "address": {"country": "cw"},
            }
        )

        self.assertEqual(resolver.asked, [])
        self.assertEqual(record["country_code"], "CW")
        self.assertNotIn("country", record)
        self.assertNotIn("lat", record)

    def test_a_site_without_coordinates_drops_a_country_name(self):
        self._with_country(("XX", "Never asked"))

        record = dive_site_harvester.transform_to_catalogue_record(
            {
                "osm_id": 8,
                "osm_type": "way",
                "tags": {"name": "Somewhere"},
                "address": {"country": "Deutschland"},
            }
        )

        self.assertNotIn("country_code", record)
        self.assertNotIn("country", record)


class GeneratedAtCallSiteTest(unittest.TestCase):
    """The helper is only worth having if every call site reaches for it.

    A source scan rather than a call because the three stamps are written
    deep inside methods that only run after a full Overpass harvest. The
    scan walks the parsed tree rather than the raw text so prose about the
    bug -- this docstring included -- cannot trip it.
    """

    def setUp(self):
        with open(_SOURCE, encoding="utf-8") as f:
            self.tree = ast.parse(f.read())

    def test_no_call_site_appends_z_to_an_isoformat(self):
        offenders = [
            node.lineno
            for node in ast.walk(self.tree)
            if isinstance(node, ast.BinOp)
            and isinstance(node.op, ast.Add)
            and isinstance(node.left, ast.Call)
            and isinstance(node.left.func, ast.Attribute)
            and node.left.func.attr == "isoformat"
        ]

        self.assertEqual(offenders, [], "isoformat() already carries +00:00")

    def test_every_generated_at_goes_through_the_helper(self):
        stamps = [
            ast.unparse(value)
            for node in ast.walk(self.tree)
            if isinstance(node, ast.Dict)
            for key, value in zip(node.keys, node.values)
            if isinstance(key, ast.Constant) and key.value == "generated_at"
        ]

        # The centres file and the raw dump; the site catalogue is stamped
        # through write_catalogue, checked below.
        self.assertEqual(stamps, ["utc_timestamp()"] * 2)

    def test_the_site_catalogue_is_stamped_by_the_helper(self):
        stamps = [
            ast.unparse(node.args[2])
            for node in ast.walk(self.tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "write_catalogue"
        ]

        self.assertEqual(stamps, ["utc_timestamp()"])


class CatalogueOutputTest(unittest.TestCase):
    """Sites leave the harvester in the catalogue format, and only there.

    A source scan for the same reason as above: the write happens after a
    full Overpass harvest.
    """

    def setUp(self):
        with open(_SOURCE, encoding="utf-8") as f:
            self.tree = ast.parse(f.read())

    def test_the_legacy_site_file_is_no_longer_written(self):
        names = [
            node.value
            for node in ast.walk(self.tree)
            if isinstance(node, ast.Constant)
            and isinstance(node.value, str)
            and node.value.startswith("dive_sites")
            and node.value.endswith(".json")
            and "raw" not in node.value
        ]

        self.assertEqual(names, [])

    def test_sites_take_their_country_from_the_resolver(self):
        transform = next(
            node
            for node in ast.walk(self.tree)
            if isinstance(node, ast.FunctionDef)
            and node.name == "transform_to_catalogue_record"
        )
        calls = [
            ast.unparse(node.func)
            for node in ast.walk(transform)
            if isinstance(node, ast.Call)
        ]

        self.assertIn("country_resolver.lookup", calls)
        self.assertIn("to_catalogue_record", calls)


if __name__ == "__main__":
    unittest.main()
