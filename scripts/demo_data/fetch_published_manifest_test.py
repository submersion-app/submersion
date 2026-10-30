#!/usr/bin/env python3
"""Unit tests for fetch_published_manifest.py.

Run: python3 scripts/demo_data/fetch_published_manifest_test.py

A build merges its package into this manifest, and publishing replaces the
release's copy with the result. So a build must never start from anything but
the published manifest: an empty start after a failed download, or a stale
local copy, would drop the packages older apps need.
"""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
import urllib.error
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location(
    "fetch_published_manifest",
    os.path.join(_HERE, "fetch_published_manifest.py"),
)
fetch_published_manifest = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fetch_published_manifest)

PUBLISHED = json.dumps(
    {"formatVersion": 1, "packages": [{"schemaVersion": 318}]}
).encode()


def _http_error(code):
    return urllib.error.HTTPError("https://example", code, "x", {}, None)


class MainTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.out = self._dir.name
        self.path = os.path.join(self.out, "demo-manifest.json")

    def _stale(self):
        with open(self.path, "w", encoding="utf-8") as f:
            f.write('{"formatVersion": 1, "packages": []}')

    def _read(self):
        with open(self.path, encoding="utf-8") as f:
            return json.load(f)

    def test_writes_the_published_manifest(self):
        code = fetch_published_manifest.main(
            ["x", self.out], fetcher=lambda url: PUBLISHED
        )

        self.assertEqual(code, 0)
        self.assertEqual(self._read()["packages"], [{"schemaVersion": 318}])

    def test_replaces_a_stale_local_manifest(self):
        self._stale()

        fetch_published_manifest.main(
            ["x", self.out], fetcher=lambda url: PUBLISHED
        )

        self.assertEqual(self._read()["packages"], [{"schemaVersion": 318}])

    def test_asks_past_the_download_cache(self):
        urls = []

        def fetcher(url):
            urls.append(url)
            return PUBLISHED

        fetch_published_manifest.main(
            ["x", self.out], fetcher=fetcher, now=lambda: 1234.5
        )

        self.assertEqual(
            urls, [f"{fetch_published_manifest.MANIFEST_URL}?t=1234"]
        )

    def test_nothing_published_starts_empty_without_a_stale_copy(self):
        self._stale()

        code = fetch_published_manifest.main(
            ["x", self.out], fetcher=lambda url: None
        )

        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.path))

    def test_a_failed_download_stops_the_build(self):
        def fetcher(url):
            raise urllib.error.URLError("no network")

        code = fetch_published_manifest.main(["x", self.out], fetcher=fetcher)

        self.assertEqual(code, 1)

    def test_a_server_error_stops_the_build(self):
        def fetcher(url):
            raise _http_error(503)

        code = fetch_published_manifest.main(["x", self.out], fetcher=fetcher)

        self.assertEqual(code, 1)

    def test_a_manifest_it_cannot_read_stops_the_build(self):
        for body in (b"<html>", b"[]", b'{"packages": "x"}'):
            self._stale()
            code = fetch_published_manifest.main(
                ["x", self.out], fetcher=lambda url, b=body: b
            )

            self.assertEqual(code, 1, body)
            self.assertEqual(self._read()["packages"], [], body)

    def test_usage_needs_the_output_folder(self):
        self.assertEqual(fetch_published_manifest.main(["x"]), 2)


class FetchTest(unittest.TestCase):
    def _open(self, *, body=None, error=None):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = body
        return mock.patch.object(
            fetch_published_manifest.urllib.request,
            "urlopen",
            return_value=response,
            side_effect=error,
        )

    def test_returns_the_body(self):
        with self._open(body=PUBLISHED):
            self.assertEqual(
                fetch_published_manifest.fetch("https://example"), PUBLISHED
            )

    def test_a_404_means_nothing_is_published(self):
        with self._open(error=_http_error(404)):
            self.assertIsNone(fetch_published_manifest.fetch("https://example"))

    def test_any_other_status_raises(self):
        with self._open(error=_http_error(401)):
            with self.assertRaises(urllib.error.HTTPError):
                fetch_published_manifest.fetch("https://example")


class PackScriptTest(unittest.TestCase):
    def test_pack_sh_fetches_the_manifest_before_it_builds(self):
        with open(os.path.join(_HERE, "pack.sh"), encoding="utf-8") as f:
            script = f.read()

        self.assertIn("fetch_published_manifest.py", script)
        self.assertLess(
            script.index("fetch_published_manifest.py"),
            script.index("flutter test"),
        )
        self.assertNotIn("gh release download", script)


if __name__ == "__main__":
    unittest.main()
