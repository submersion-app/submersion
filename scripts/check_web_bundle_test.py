#!/usr/bin/env python3
"""Unit tests for check_web_bundle.py."""

import gzip
import hashlib
import importlib.util
import json
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_web_bundle",
    os.path.join(_HERE, "check_web_bundle.py"),
)
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

WASM = b"\0asm\1\0\0\0 not really"


def _write(root, name, content=b"x"):
    path = os.path.join(root, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(content)


class BundleCheckTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.bundle = os.path.join(self._tmp.name, "web")
        os.makedirs(self.bundle)
        for name in check.REQUIRED:
            _write(self.bundle, name, WASM if name == "sqlite3.wasm" else b"x")
        self.lock = os.path.join(self._tmp.name, "sqlite3_wasm.lock")
        with open(self.lock, "w", encoding="utf-8") as handle:
            handle.write(
                "url=https://example.invalid/sqlite3.wasm\n"
                f"sha256={hashlib.sha256(WASM).hexdigest()}\n"
            )

    def test_a_complete_bundle_passes(self):
        self.assertEqual(check.check_bundle(self.bundle, self.lock), [])

    def test_a_missing_worker_fails(self):
        os.remove(os.path.join(self.bundle, "drift_worker.js"))
        failures = check.check_bundle(self.bundle, self.lock)
        self.assertEqual(len(failures), 1)
        self.assertIn("drift_worker.js", failures[0])

    def test_a_service_worker_fails(self):
        _write(self.bundle, "flutter_service_worker.js")
        failures = check.check_bundle(self.bundle, self.lock)
        self.assertEqual(len(failures), 1)
        self.assertIn("flutter_service_worker.js", failures[0])

    def test_a_wrong_wasm_hash_fails(self):
        _write(self.bundle, "sqlite3.wasm", b"some other build")
        failures = check.check_bundle(self.bundle, self.lock)
        self.assertEqual(len(failures), 1)
        self.assertIn("sqlite3.wasm", failures[0])

    def test_worker_sources_and_sidecars_fail(self):
        _write(self.bundle, "drift_worker.dart")
        _write(self.bundle, "compute_worker.js.map")
        _write(self.bundle, "compute_worker.js.deps")
        _write(self.bundle, "main.dart.js.map")
        failures = check.check_bundle(self.bundle, self.lock)
        self.assertEqual(len(failures), 4)
        joined = "\n".join(failures)
        for name in (
            "drift_worker.dart",
            "compute_worker.js.map",
            "compute_worker.js.deps",
            "main.dart.js.map",
        ):
            self.assertIn(name, joined)

    def test_main_reports_and_exits_nonzero_on_failure(self):
        os.remove(os.path.join(self.bundle, "HOSTING.md"))
        self.assertEqual(check.main([self.bundle, self.lock]), 1)

    def test_main_passes_a_complete_bundle(self):
        self.assertEqual(check.main([self.bundle, self.lock]), 0)


class SampleLogbookTest(unittest.TestCase):
    """The sample logbook ships in the bundle (issue #4121): when its index
    is there, everything it names must be there too, byte for byte."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.bundle = self._tmp.name
        packed = gzip.compress(b"sample", mtime=0)
        _write(self.bundle, "demo/submersion_demo.db.gz", packed)
        _write(self.bundle, "demo/photos/reef.jpg", b"jpg")
        self.index = {
            "formatVersion": 1,
            "schemaVersion": 327,
            "generatedAt": "2026-10-30T00:00:00Z",
            "database": {
                "path": "submersion_demo.db.gz",
                "size": 6,
                "sha256": hashlib.sha256(b"sample").hexdigest(),
                "compressedSize": len(packed),
            },
            "photos": ["photos/reef.jpg"],
        }

    def _write_index(self):
        _write(
            self.bundle,
            "demo/demo.json",
            json.dumps(self.index).encode("utf-8"),
        )

    def test_a_complete_sample_logbook_passes(self):
        self._write_index()
        self.assertEqual(check.check_sample_logbook(self.bundle), [])

    def test_a_bundle_without_one_passes(self):
        self.assertEqual(check.check_sample_logbook(self.bundle), [])

    def test_a_database_that_does_not_match_fails(self):
        self.index["database"]["sha256"] = "0" * 64
        self._write_index()
        failures = check.check_sample_logbook(self.bundle)
        self.assertEqual(len(failures), 1)
        self.assertIn("submersion_demo.db", failures[0])

    def test_a_missing_photo_fails(self):
        self.index["photos"].append("photos/wreck.jpg")
        self._write_index()
        failures = check.check_sample_logbook(self.bundle)
        self.assertEqual(len(failures), 1)
        self.assertIn("wreck.jpg", failures[0])

    def test_an_unreadable_index_fails(self):
        _write(self.bundle, "demo/demo.json", b"{not json")
        self.assertEqual(len(check.check_sample_logbook(self.bundle)), 1)


if __name__ == "__main__":
    unittest.main()
