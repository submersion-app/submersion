#!/usr/bin/env python3
"""Unit tests for snapshots.py.

Run: python3 scripts/site_catalogue/snapshots_test.py

Each catalogue source is downloaded on its own into a snapshot the merge
reads later. These tests pin that a snapshot comes back as it was written,
that a missing or malformed one is an error and never an empty source, and
that every request carries the one client name the project allows.
"""

import os
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import snapshots  # noqa: E402


class _Response:
    def __init__(self, body=b"ok", status=200):
        self._body = body
        self.status = status

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


class SnapshotTest(unittest.TestCase):
    def test_a_snapshot_round_trips(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            path = snapshots.write_snapshot(
                "ukho", "https://example.org/w", [{"name": "Épave"}], cache
            )
            self.assertEqual(path, cache / "ukho.json")
            snapshot = snapshots.read_snapshot("ukho", cache)
            self.assertEqual(snapshot["source"], "ukho")
            self.assertEqual(snapshot["url"], "https://example.org/w")
            self.assertEqual(snapshot["rows"], [{"name": "Épave"}])
            self.assertRegex(
                snapshot["fetched_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$"
            )

    def test_a_missing_snapshot_names_its_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError) as raised:
                snapshots.read_snapshot("awois", Path(tmp))
            self.assertIn("awois", str(raised.exception))

    def test_a_snapshot_with_no_rows_is_refused(self):
        # A source that answered with nothing is a failed download, not a
        # source with no records.
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError) as raised:
                snapshots.write_snapshot("ukho", "https://x", [], Path(tmp))
            self.assertIn("ukho", str(raised.exception))
            self.assertFalse((Path(tmp) / "ukho.json").exists())

    def test_a_missing_column_is_named(self):
        with self.assertRaises(ValueError) as raised:
            snapshots.require_fields({"a": 1}, ("a", "b"), "ukho")
        self.assertIn("ukho", str(raised.exception))
        self.assertIn("b", str(raised.exception))
        snapshots.require_fields({"a": 1, "b": None}, ("a", "b"), "ukho")


class HttpTest(unittest.TestCase):
    def test_every_request_carries_only_the_fixed_client_name(self):
        self.assertEqual(snapshots.USER_AGENT, "dive-site-harvester/1.0")
        with mock.patch.object(
            snapshots.urllib.request, "urlopen", return_value=_Response(b"hi")
        ) as urlopen:
            body = snapshots.http_get(
                "https://example.org/data", params={"f": "json", "q": "a b"}
            )
        self.assertEqual(body, b"hi")
        request = urlopen.call_args.args[0]
        self.assertEqual(
            request.full_url, "https://example.org/data?f=json&q=a+b"
        )
        self.assertEqual(
            dict(request.header_items()),
            {"User-agent": "dive-site-harvester/1.0"},
        )

    def test_a_refusal_is_an_error_naming_the_status(self):
        error = urllib.error.HTTPError(
            "https://example.org", 403, "Forbidden", {}, None
        )
        self.addCleanup(error.close)
        with mock.patch.object(
            snapshots.urllib.request, "urlopen", side_effect=error
        ):
            with self.assertRaises(RuntimeError) as raised:
                snapshots.http_get("https://example.org")
        self.assertIn("403", str(raised.exception))
        self.assertIn("example.org", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
