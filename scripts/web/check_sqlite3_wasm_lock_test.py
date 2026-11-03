#!/usr/bin/env python3
"""Unit tests for check_sqlite3_wasm_lock.py."""

import importlib.util
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_sqlite3_wasm_lock",
    os.path.join(_HERE, "check_sqlite3_wasm_lock.py"),
)
checker = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(checker)

LOCK = (
    "url=https://github.com/simolus3/sqlite3.dart/releases/download/"
    "sqlite3-{v}/sqlite3.wasm\n"
    "sha256=13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4\n"
)
PUBSPEC_LOCK = (
    "packages:\n"
    "  sqflite:\n"
    "    version: \"2.4.1\"\n"
    "  sqlite3:\n"
    "    dependency: \"direct main\"\n"
    "    description:\n"
    "      name: sqlite3\n"
    "    source: hosted\n"
    "    version: \"{v}\"\n"
    "  sqlite3_flutter_libs:\n"
    "    version: \"0.5.40\"\n"
)


def _write(directory, name, text):
    path = os.path.join(directory, name)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return path


class LockVersionTest(unittest.TestCase):
    def test_lock_version_is_read_from_the_release_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = _write(tmp, "sqlite3_wasm.lock", LOCK.format(v="3.5.1"))
            self.assertEqual(checker.lock_version(lock), "3.5.1")

    def test_pubspec_version_is_the_sqlite3_package_not_its_neighbours(self):
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(tmp, "pubspec.lock", PUBSPEC_LOCK.format(v="3.5.1"))
            self.assertEqual(checker.pubspec_sqlite3_version(pubspec), "3.5.1")

    def test_matching_versions_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = _write(tmp, "sqlite3_wasm.lock", LOCK.format(v="3.5.1"))
            pubspec = _write(tmp, "pubspec.lock", PUBSPEC_LOCK.format(v="3.5.1"))
            self.assertEqual(checker.check(lock, pubspec), [])

    def test_a_newer_dart_package_fails_the_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = _write(tmp, "sqlite3_wasm.lock", LOCK.format(v="3.5.1"))
            pubspec = _write(tmp, "pubspec.lock", PUBSPEC_LOCK.format(v="3.5.2"))
            problems = checker.check(lock, pubspec)
            self.assertEqual(len(problems), 1)
            self.assertIn("3.5.1", problems[0])
            self.assertIn("3.5.2", problems[0])

    def test_a_lock_without_a_sha_fails_the_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = _write(tmp, "sqlite3_wasm.lock", LOCK.format(v="3.5.1").splitlines()[0] + "\n")
            pubspec = _write(tmp, "pubspec.lock", PUBSPEC_LOCK.format(v="3.5.1"))
            problems = checker.check(lock, pubspec)
            self.assertTrue(any("sha256" in p for p in problems))


if __name__ == "__main__":
    unittest.main()
