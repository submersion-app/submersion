#!/usr/bin/env python3
"""Unit tests for fetch_demo_db.py.

Run: python3 scripts/demo_data/fetch_demo_db_test.py

The store screenshots are captured from the demo-mode sample logbook
(issue #3708). The fetch must pick a package this build can open (never one
built for a newer schema), refuse a download whose checksum does not match
the manifest, and never write outside the directory it was given.
"""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "fetch_demo_db", os.path.join(_HERE, "fetch_demo_db.py")
)
fetch = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fetch)


def _package(schema, sha="0" * 64):
    return {
        "schemaVersion": schema,
        "url": f"https://example.test/submersion-demo-s{schema}.zip",
        "sha256": sha,
        "size": 1,
        "generatedAt": "2026-10-26T00:00:00Z",
    }


def _zip(entries):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for name, data in entries.items():
            z.writestr(name, data)
    return buf.getvalue()


class CurrentSchemaTest(unittest.TestCase):
    def test_reads_the_schema_from_database_dart(self):
        source = "class AppDatabase {\n  static const int currentSchemaVersion = 318;\n}\n"
        self.assertEqual(fetch.current_schema(source), 318)

    def test_a_missing_declaration_is_an_error(self):
        with self.assertRaises(ValueError):
            fetch.current_schema("class AppDatabase {}")


class PickPackageTest(unittest.TestCase):
    def test_picks_the_newest_package_this_build_can_open(self):
        manifest = {"packages": [_package(300), _package(320), _package(318)]}
        self.assertEqual(fetch.pick_package(manifest, 318)["schemaVersion"], 318)
        self.assertEqual(fetch.pick_package(manifest, 319)["schemaVersion"], 318)

    def test_a_package_for_a_newer_schema_is_never_picked(self):
        manifest = {"packages": [_package(320)]}
        with self.assertRaises(ValueError):
            fetch.pick_package(manifest, 318)


class VerifyTest(unittest.TestCase):
    def test_a_matching_checksum_passes(self):
        data = b"logbook"
        fetch.verify(data, hashlib.sha256(data).hexdigest())

    def test_a_bad_checksum_is_rejected(self):
        with self.assertRaises(ValueError):
            fetch.verify(b"logbook", "0" * 64)


class ExtractTest(unittest.TestCase):
    def test_extracts_the_database_and_photos(self):
        data = _zip({"submersion_demo.db": b"db", "photos/reef.jpg": b"jpg"})
        with tempfile.TemporaryDirectory() as out:
            fetch.extract(data, out)
            with open(os.path.join(out, "submersion_demo.db"), "rb") as f:
                self.assertEqual(f.read(), b"db")
            self.assertTrue(os.path.isfile(os.path.join(out, "photos", "reef.jpg")))

    def test_an_entry_outside_the_directory_is_refused(self):
        data = _zip({"../escape.txt": b"x"})
        with tempfile.TemporaryDirectory() as parent:
            out = os.path.join(parent, "out")
            os.mkdir(out)
            with self.assertRaises(ValueError):
                fetch.extract(data, out)
            self.assertFalse(os.path.exists(os.path.join(parent, "escape.txt")))

    def test_a_package_without_a_database_is_refused(self):
        data = _zip({"photos/reef.jpg": b"jpg"})
        with tempfile.TemporaryDirectory() as out:
            with self.assertRaises(ValueError):
                fetch.extract(data, out)


class MainTest(unittest.TestCase):
    """The command as the screenshot jobs run it, against local files."""

    def _publish(self, tmp, sha=None):
        data = _zip({fetch.DATABASE_NAME: b"db", "photos/reef.jpg": b"jpg"})
        zip_path = os.path.join(tmp, "submersion-demo-s318.zip")
        with open(zip_path, "wb") as f:
            f.write(data)
        manifest = {
            "formatVersion": 1,
            "packages": [
                {
                    **_package(318, sha or hashlib.sha256(data).hexdigest()),
                    "url": pathlib.Path(zip_path).as_uri(),
                }
            ],
        }
        manifest_path = os.path.join(tmp, "demo-manifest.json")
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f)
        dart = os.path.join(tmp, "database.dart")
        with open(dart, "w", encoding="utf-8") as f:
            f.write("static const int currentSchemaVersion = 318;")
        return pathlib.Path(manifest_path).as_uri(), dart

    def _run(self, out, manifest_url, dart):
        quiet = io.StringIO()
        with contextlib.redirect_stdout(quiet), contextlib.redirect_stderr(quiet):
            return fetch.main(
                [out, "--manifest-url", manifest_url, "--database-dart", dart]
            )

    def test_fetches_verifies_and_extracts_the_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest_url, dart = self._publish(tmp)
            out = os.path.join(tmp, "out")

            self.assertEqual(self._run(out, manifest_url, dart), 0)
            with open(os.path.join(out, fetch.DATABASE_NAME), "rb") as f:
                self.assertEqual(f.read(), b"db")
            self.assertTrue(os.path.exists(os.path.join(out, "photos", "reef.jpg")))

    def test_a_checksum_mismatch_fails_and_extracts_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest_url, dart = self._publish(tmp, sha="f" * 64)
            out = os.path.join(tmp, "out")

            self.assertEqual(self._run(out, manifest_url, dart), 1)
            self.assertFalse(os.path.exists(out))


if __name__ == "__main__":
    unittest.main()
