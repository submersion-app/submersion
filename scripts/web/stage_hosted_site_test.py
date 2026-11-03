#!/usr/bin/env python3
"""Unit tests for stage_hosted_site.py."""

import hashlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "stage_hosted_site",
    os.path.join(_HERE, "stage_hosted_site.py"),
)
stage = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(stage)

WASM = b"\0asm\1\0\0\0 not really"
CLIENT_ID = "123-abc.apps.googleusercontent.com"
DOMAIN = "web.submersion.app"
ORIGIN = "https://web.submersion.app"
VERSION = {
    "app_name": "submersion",
    "version": "1.8.3",
    "build_number": "9095",
    "package_name": "submersion",
}


def _bundle_files(main_js=None, omit=()):
    """The files of a bundle that passes check_web_bundle, by name."""
    files = {
        name: b"x" for name in stage.check_web_bundle.REQUIRED if name not in omit
    }
    if "sqlite3.wasm" in files:
        files["sqlite3.wasm"] = WASM
    if "version.json" in files:
        files["version.json"] = json.dumps(VERSION).encode()
    if "main.dart.js" in files:
        files["main.dart.js"] = (
            main_js
            if main_js is not None
            else f'var a="{CLIENT_ID}",b="{ORIGIN}";'.encode()
        )
    files["index.html"] = b"<!doctype html><title>Submersion</title>"
    return files


def _write_zip(path, files):
    with zipfile.ZipFile(path, "w") as archive:
        for name, content in files.items():
            archive.writestr(name, content)


def _write_json(path, value):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle)


class _TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = self._tmp.name
        self.lock = os.path.join(self.root, "sqlite3_wasm.lock")
        with open(self.lock, "w", encoding="utf-8") as handle:
            handle.write(
                "url=https://example.invalid/sqlite3.wasm\n"
                f"sha256={hashlib.sha256(WASM).hexdigest()}\n"
            )
        self.zip = os.path.join(self.root, "Submersion-v1.8.3.9095-Web.zip")
        self.out = os.path.join(self.root, "site")

    def _stage(self):
        return stage.stage_site(self.zip, self.out, DOMAIN, CLIENT_ID, self.lock)


class StageSiteTest(_TempDirTest):
    def test_stages_the_bundle_with_cname_and_nojekyll(self):
        _write_zip(self.zip, _bundle_files())
        self.assertEqual(self._stage(), [])
        with open(os.path.join(self.out, "CNAME"), encoding="utf-8") as handle:
            self.assertEqual(handle.read(), "web.submersion.app\n")
        self.assertTrue(os.path.isfile(os.path.join(self.out, ".nojekyll")))
        with open(os.path.join(self.out, "index.html"), "rb") as handle:
            self.assertEqual(handle.read(), _bundle_files()["index.html"])

    def test_a_bundle_that_fails_the_bundle_check_is_refused(self):
        _write_zip(self.zip, _bundle_files(omit=("drift_worker.js",)))
        with self.assertRaises(stage.StageError) as caught:
            self._stage()
        self.assertIn("missing drift_worker.js", str(caught.exception))

    def test_a_zip_member_outside_the_folder_is_refused(self):
        for member in ("../evil.txt", "/abs.txt"):
            with self.subTest(member=member):
                files = _bundle_files()
                files[member] = b"escaped"
                _write_zip(self.zip, files)
                with self.assertRaises(stage.StageError):
                    self._stage()
                self.assertFalse(
                    os.path.exists(os.path.join(self.root, "evil.txt"))
                )
                self.assertFalse(os.path.exists("/abs.txt"))

    def test_a_non_empty_output_folder_is_refused(self):
        _write_zip(self.zip, _bundle_files())
        os.makedirs(self.out)
        with open(os.path.join(self.out, "stale.txt"), "w") as handle:
            handle.write("left over")
        with self.assertRaises(stage.StageError):
            self._stage()

    def test_a_missing_zip_is_refused(self):
        with self.assertRaises(stage.StageError):
            self._stage()

    def test_a_bundle_without_the_client_still_stages_with_a_warning(self):
        _write_zip(self.zip, _bundle_files(main_js=b"var a=1;"))
        warnings = self._stage()
        self.assertEqual(len(warnings), 1)
        self.assertIn(CLIENT_ID, warnings[0])
        self.assertTrue(os.path.isfile(os.path.join(self.out, "CNAME")))


class ClientWarningsTest(_TempDirTest):
    def _bundle(self, main_js):
        bundle = os.path.join(self.root, "bundle")
        os.makedirs(bundle)
        with open(os.path.join(bundle, "main.dart.js"), "wb") as handle:
            handle.write(main_js)
        return bundle

    def test_no_client_id_warns(self):
        bundle = self._bundle(b"var a=1;")
        warnings = stage.client_warnings(bundle, "", ORIGIN)
        self.assertEqual(len(warnings), 1)
        self.assertIn("GOOGLE_WEB_CLIENT_ID", warnings[0])

    def test_a_bundle_without_the_client_warns(self):
        bundle = self._bundle(f'var b="{ORIGIN}";'.encode())
        warnings = stage.client_warnings(bundle, CLIENT_ID, ORIGIN)
        self.assertEqual(len(warnings), 1)
        self.assertIn(CLIENT_ID, warnings[0])

    def test_a_client_built_for_another_origin_warns(self):
        bundle = self._bundle(
            f'var a="{CLIENT_ID}",b="https://elsewhere.example";'.encode()
        )
        warnings = stage.client_warnings(bundle, CLIENT_ID, ORIGIN)
        self.assertEqual(len(warnings), 1)
        self.assertIn(ORIGIN, warnings[0])

    def test_a_bundle_with_the_client_and_origin_is_quiet(self):
        bundle = self._bundle(f'var a="{CLIENT_ID}",b="{ORIGIN}";'.encode())
        self.assertEqual(stage.client_warnings(bundle, CLIENT_ID, ORIGIN), [])

    def test_a_missing_main_dart_js_warns(self):
        bundle = os.path.join(self.root, "empty")
        os.makedirs(bundle)
        self.assertEqual(len(stage.client_warnings(bundle, CLIENT_ID, ORIGIN)), 1)


class VersionTest(_TempDirTest):
    def test_read_version(self):
        path = os.path.join(self.root, "version.json")
        _write_json(path, VERSION)
        self.assertEqual(stage.read_version(path), (1, 8, 3, 9095))

    def test_unreadable_versions_read_as_none(self):
        missing = os.path.join(self.root, "absent.json")
        self.assertIsNone(stage.read_version(missing))
        invalid = os.path.join(self.root, "invalid.json")
        with open(invalid, "w") as handle:
            handle.write("{not json")
        self.assertIsNone(stage.read_version(invalid))
        no_build = os.path.join(self.root, "no_build.json")
        _write_json(no_build, {"version": "1.8.3"})
        self.assertIsNone(stage.read_version(no_build))
        not_numbers = os.path.join(self.root, "letters.json")
        _write_json(not_numbers, {"version": "1.x.3", "build_number": "9"})
        self.assertIsNone(stage.read_version(not_numbers))

    def test_may_deploy(self):
        older = (1, 8, 3, 9095)
        newer = (1, 8, 4, 9300)
        self.assertTrue(stage.may_deploy(newer, older, force=False))
        self.assertTrue(stage.may_deploy(older, older, force=False))
        self.assertFalse(stage.may_deploy(older, newer, force=False))
        self.assertTrue(stage.may_deploy(older, newer, force=True))
        self.assertTrue(stage.may_deploy(older, None, force=False))

    def test_a_later_build_of_the_same_version_is_newer(self):
        self.assertTrue(stage.may_deploy((1, 8, 3, 9100), (1, 8, 3, 9095), False))
        self.assertFalse(stage.may_deploy((1, 8, 3, 9000), (1, 8, 3, 9095), False))


class MainTest(_TempDirTest):
    def _run(self, argv):
        with redirect_stdout(io.StringIO()) as output:
            code = stage.main(argv)
        return code, output.getvalue()

    def test_check_newer_cli(self):
        staged = os.path.join(self.root, "staged.json")
        current = os.path.join(self.root, "current.json")
        _write_json(staged, VERSION)
        _write_json(current, dict(VERSION, version="1.8.4", build_number="9300"))
        code, output = self._run(["check-newer", staged, current])
        self.assertEqual(code, 1)
        self.assertIn("force", output)
        self.assertEqual(self._run(["check-newer", staged, current, "--force"])[0], 0)
        absent = os.path.join(self.root, "absent.json")
        self.assertEqual(self._run(["check-newer", staged, absent])[0], 0)
        self.assertEqual(self._run(["check-newer", absent, current])[0], 1)

    def test_stage_cli_prints_warnings_as_annotations(self):
        _write_zip(self.zip, _bundle_files(main_js=b"var a=1;"))
        code, output = self._run(
            [
                "stage",
                self.zip,
                self.out,
                "--domain",
                DOMAIN,
                "--client-id",
                CLIENT_ID,
                "--lock",
                self.lock,
            ]
        )
        self.assertEqual(code, 0)
        self.assertIn("::warning::", output)
        self.assertIn("OK: staged", output)

    def test_stage_cli_fails_on_a_broken_bundle(self):
        _write_zip(self.zip, _bundle_files(omit=("sqlite3.wasm",)))
        code, output = self._run(
            ["stage", self.zip, self.out, "--domain", DOMAIN, "--lock", self.lock]
        )
        self.assertEqual(code, 1)
        self.assertIn("FAIL:", output)


if __name__ == "__main__":
    unittest.main()
