#!/usr/bin/env python3
"""Unit tests for site_country_resolver.py.

Run: python3 scripts/site_country_resolver_test.py

A catalogue site's country comes from its coordinates, not from the text
OpenStreetMap happens to carry, and a territory with its own ISO code keeps
that code: a Bonaire site is BQ, not the Netherlands.
"""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "site_country_resolver",
    os.path.join(_HERE, "site_country_resolver.py"),
)
res = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(res)


class _Response:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def json(self):
        return self._payload


class ResolveCountryTest(unittest.TestCase):
    def test_a_plain_answer_gives_the_country(self):
        self.assertEqual(
            res.resolve_country(
                {
                    "country": "Egypt",
                    "country_code": "eg",
                    "ISO3166-2-lvl4": "EG-BA",
                }
            ),
            ("EG", "Egypt"),
        )

    def test_a_territory_subdivision_wins(self):
        # Measured from Nominatim for 12.08, -68.28 on 2026-11-13.
        self.assertEqual(
            res.resolve_country(
                {
                    "municipality": "Bonaire",
                    "ISO3166-2-lvl8": "BQ-BO",
                    "country": "Netherlands",
                    "postcode": "0000 BQ",
                    "country_code": "nl",
                }
            ),
            ("BQ", "Caribbean Netherlands"),
        )

    def test_a_country_of_the_kingdom_takes_its_own_code(self):
        # Curaçao, Aruba and Sint Maarten are named as countries but filed
        # under the Netherlands' code, with no subdivision code to go by.
        self.assertEqual(
            res.resolve_country({"country": "Curacao", "country_code": "nl"}),
            ("CW", "Curaçao"),
        )
        self.assertEqual(
            res.resolve_country({"country": "Aruba", "country_code": "nl"}),
            ("AW", "Aruba"),
        )
        self.assertEqual(
            res.resolve_country(
                {"country": "Sint Maarten", "country_code": "nl"}
            ),
            ("SX", "Sint Maarten"),
        )
        self.assertEqual(
            res.resolve_country(
                {"country": "Netherlands", "country_code": "nl"}
            ),
            ("NL", "Netherlands"),
        )

    def test_an_unknown_territory_prefix_is_an_error(self):
        with self.assertRaises(KeyError):
            res.resolve_country(
                {
                    "ISO3166-2-lvl8": "ZZ-01",
                    "country": "Nowhere",
                    "country_code": "xx",
                }
            )

    def test_no_address_gives_nothing(self):
        self.assertEqual(res.resolve_country({}), (None, None))

    def test_micronesia_goes_by_the_name_the_app_knows(self):
        self.assertEqual(
            res.resolve_country(
                {
                    "country": "Federated States of Micronesia",
                    "country_code": "fm",
                }
            ),
            ("FM", "Micronesia"),
        )

    def test_a_name_override_replaces_the_geocoders_name(self):
        res.NAME_OVERRIDES["XA"] = "Exampleland"
        self.addCleanup(res.NAME_OVERRIDES.pop, "XA")
        self.assertEqual(
            res.resolve_country(
                {"country": "Republic of Example", "country_code": "xa"}
            ),
            ("XA", "Exampleland"),
        )


class CountryResolverTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.cache_path = Path(self._tmp.name) / "cache.json"

    def test_lookup_reads_the_cache_before_the_network(self):
        self.cache_path.write_text(
            json.dumps({"12.08,-68.28": ["BQ", "Caribbean Netherlands"]}),
            encoding="utf-8",
        )

        def no_network(*args, **kwargs):
            self.fail("the cache should have answered")

        resolver = res.CountryResolver(
            self.cache_path, http_get=no_network, sleep=lambda _: None
        )

        self.assertEqual(
            resolver.lookup(12.0811, -68.2793),
            ("BQ", "Caribbean Netherlands"),
        )

    def test_an_answer_cached_before_a_rule_existed_is_corrected(self):
        # A cache written by an earlier run holds the geocoder's own pairing.
        self.cache_path.write_text(
            json.dumps({"12.1,-68.9": ["NL", "Curacao"]}),
            encoding="utf-8",
        )
        resolver = res.CountryResolver(
            self.cache_path,
            http_get=lambda *a, **k: self.fail("cached"),
            sleep=lambda _: None,
        )

        self.assertEqual(resolver.lookup(12.1, -68.9), ("CW", "Curaçao"))

    def test_lookup_asks_once_and_remembers(self):
        calls = []

        def fake_get(url, params=None, headers=None, timeout=None):
            calls.append((url, params, headers))
            return _Response(
                {"address": {"country": "Egypt", "country_code": "eg"}}
            )

        resolver = res.CountryResolver(
            self.cache_path, http_get=fake_get, sleep=lambda _: None
        )

        self.assertEqual(resolver.lookup(27.2, 33.8), ("EG", "Egypt"))
        self.assertEqual(resolver.lookup(27.2, 33.8), ("EG", "Egypt"))
        self.assertEqual(len(calls), 1)
        url, params, headers = calls[0]
        self.assertIn("nominatim.openstreetmap.org/reverse", url)
        self.assertEqual(params["accept-language"], "en")
        self.assertEqual(params["zoom"], 10)
        self.assertIn("User-Agent", headers)
        # The answer is on disk, so a stopped run resumes from it.
        stored = json.loads(self.cache_path.read_text(encoding="utf-8"))
        self.assertEqual(stored["27.2,33.8"], ["EG", "Egypt"])

    def test_open_sea_is_remembered_as_no_country(self):
        calls = []

        def fake_get(url, params=None, headers=None, timeout=None):
            calls.append(url)
            return _Response({"error": "Unable to geocode"})

        resolver = res.CountryResolver(
            self.cache_path, http_get=fake_get, sleep=lambda _: None
        )

        self.assertEqual(resolver.lookup(0.0, -30.0), (None, None))
        self.assertEqual(resolver.lookup(0.0, -30.0), (None, None))
        self.assertEqual(len(calls), 1)

    def test_a_failed_request_is_not_remembered(self):
        def fake_get(url, params=None, headers=None, timeout=None):
            return _Response({}, status_code=503)

        resolver = res.CountryResolver(
            self.cache_path, http_get=fake_get, sleep=lambda _: None
        )

        with self.assertRaises(RuntimeError):
            resolver.lookup(27.2, 33.8)
        self.assertFalse(self.cache_path.exists())


if __name__ == "__main__":
    unittest.main()
