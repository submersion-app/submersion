#!/usr/bin/env python3
"""Unit tests for check_bundled_native_assets.py.

Run: python3 scripts/check_bundled_native_assets_test.py

The headline case is the issue #1129 regression: a Windows bundle whose
NativeAssetsManifest.json declares sqlcipher.dll but whose Release directory
does not actually contain it, because the CMake install rule that copies
build/native_assets/windows/ was skipped. That build succeeds, packages, ships,
and then dies on the user's machine with error 126.
"""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_bundled_native_assets",
    os.path.join(_HERE, "check_bundled_native_assets.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

SQLITE = guard.REQUIRED_ASSET_ID
PDFIUM = "package:pdfium_dart/libpdfium"


def _windows_manifest(assets):
    return {"format-version": [1, 0, 0], "native-assets": {"windows_x64": assets}}


def _linux_manifest(assets):
    return {"format-version": [1, 0, 0], "native-assets": {"linux_x64": assets}}


class BundleBuilder:
    """Builds a throwaway app bundle on disk for one test case."""

    def __init__(self, test, manifest=None, files=(), manifest_missing=False):
        self.root = tempfile.mkdtemp()
        test.addCleanup(self._cleanup)
        assets_dir = os.path.join(self.root, "data", "flutter_assets")
        os.makedirs(assets_dir)
        if not manifest_missing:
            with open(os.path.join(assets_dir, "NativeAssetsManifest.json"), "w") as fh:
                json.dump(manifest, fh)
        for rel in files:
            path = os.path.join(self.root, rel.replace("/", os.sep))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as fh:
                fh.write(b"")

    def _cleanup(self):
        for dirpath, _dirnames, filenames in os.walk(self.root, topdown=False):
            for name in filenames:
                os.unlink(os.path.join(dirpath, name))
            os.rmdir(dirpath)


class CheckBundleTests(unittest.TestCase):
    def _check(self, **kwargs):
        return guard.check_bundle(BundleBuilder(self, **kwargs).root)

    def test_green_windows_bundle_has_every_declared_dll(self):
        ok, lines = self._check(
            manifest=_windows_manifest(
                {
                    SQLITE: ["absolute", "sqlcipher.dll"],
                    PDFIUM: ["absolute", "pdfium.dll"],
                }
            ),
            files=("sqlcipher.dll", "pdfium.dll"),
        )
        self.assertTrue(ok, lines)
        self.assertTrue(all("FAIL" not in line for line in lines))

    def test_red_issue_1129_declared_but_not_bundled(self):
        # The manifest promises sqlcipher.dll; the install step never copied it.
        ok, lines = self._check(
            manifest=_windows_manifest({SQLITE: ["absolute", "sqlcipher.dll"]}),
            files=(),
        )
        self.assertFalse(ok)
        self.assertTrue(any("sqlcipher.dll" in line and "FAIL" in line for line in lines))

    def test_red_one_of_several_missing(self):
        # pdfium.dll dropped the same way; a partial bundle is still a failure.
        ok, lines = self._check(
            manifest=_windows_manifest(
                {
                    SQLITE: ["absolute", "sqlcipher.dll"],
                    PDFIUM: ["absolute", "pdfium.dll"],
                }
            ),
            files=("sqlcipher.dll",),
        )
        self.assertFalse(ok)
        self.assertTrue(any("pdfium.dll" in line and "FAIL" in line for line in lines))

    def test_green_linux_layout_resolves_lib_subdirectory(self):
        # The Linux bundle puts native assets in lib/ next to the executable.
        ok, lines = self._check(
            manifest=_linux_manifest({SQLITE: ["absolute", "libsqlcipher.so"]}),
            files=("lib/libsqlcipher.so",),
        )
        self.assertTrue(ok, lines)

    def test_system_libraries_are_not_expected_in_the_bundle(self):
        # A "system" asset resolves through the OS loader, not the bundle.
        ok, lines = self._check(
            manifest=_windows_manifest(
                {
                    SQLITE: ["absolute", "sqlcipher.dll"],
                    "package:foo/bar": ["system", "/usr/lib/libz.so"],
                }
            ),
            files=("sqlcipher.dll",),
        )
        self.assertTrue(ok, lines)

    def test_process_assets_have_no_file_to_check(self):
        ok, lines = self._check(
            manifest=_windows_manifest(
                {
                    SQLITE: ["absolute", "sqlcipher.dll"],
                    "package:foo/bar": ["process"],
                }
            ),
            files=("sqlcipher.dll",),
        )
        self.assertTrue(ok, lines)

    def test_missing_manifest_fails_closed(self):
        ok, lines = self._check(manifest_missing=True)
        self.assertFalse(ok)
        self.assertTrue(any("NativeAssetsManifest.json" in line for line in lines))

    def test_manifest_without_the_database_engine_fails_closed(self):
        # The manifest itself lost SQLCipher (e.g. the pubspec hook define was
        # dropped): the bundle is self-consistent but the app cannot open its
        # database, so file-presence alone must not be enough to pass.
        ok, lines = self._check(
            manifest=_windows_manifest({PDFIUM: ["absolute", "pdfium.dll"]}),
            files=("pdfium.dll",),
        )
        self.assertFalse(ok)
        self.assertTrue(any(SQLITE in line for line in lines))

    def test_manifest_with_no_native_assets_fails_closed(self):
        ok, lines = self._check(manifest=_windows_manifest({}))
        self.assertFalse(ok)


class MainTests(unittest.TestCase):
    def _main(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = guard.main(["check_bundled_native_assets.py", *args])
        return code, buf.getvalue()

    def test_no_args_prints_usage(self):
        code, out = self._main()
        self.assertEqual(code, 2)
        self.assertIn("Usage:", out)

    def test_missing_bundle_is_a_failure(self):
        code, out = self._main("/no/such/bundle")
        self.assertEqual(code, 1)
        self.assertIn("FAIL", out)

    def test_green_bundle_exits_zero(self):
        root = BundleBuilder(
            self,
            manifest=_windows_manifest({SQLITE: ["absolute", "sqlcipher.dll"]}),
            files=("sqlcipher.dll",),
        ).root
        code, out = self._main(root)
        self.assertEqual(code, 0)
        self.assertIn("PASS", out)

    def test_red_bundle_exits_one(self):
        root = BundleBuilder(
            self,
            manifest=_windows_manifest({SQLITE: ["absolute", "sqlcipher.dll"]}),
            files=(),
        ).root
        code, out = self._main(root)
        self.assertEqual(code, 1)
        self.assertIn("FAIL", out)


if __name__ == "__main__":
    unittest.main()
