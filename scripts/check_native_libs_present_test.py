#!/usr/bin/env python3
"""Unit tests for check_native_libs_present.py.

Run: python3 scripts/check_native_libs_present_test.py

These exercise the APK/AAB native-library presence parser and its pass/fail
contract, including the issue #433 regression (an archive that ships its ABIs
but no SQLite/SQLCipher engine) which the Build Android integration step would only catch
by actually crashing on a device.
"""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
import zipfile

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_native_libs_present",
    os.path.join(_HERE, "check_native_libs_present.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

# The standard Flutter release ABI set; the SQLCipher AAR ships all three.
ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")

# Derived from the guard rather than hardcoded: when the engine changes (as it
# did from libsqlite3.so to libsqlcipher.so), these tests must follow the
# constant automatically instead of silently testing the wrong library name.
REQUIRED = guard.REQUIRED_LIBS[0]


def _zip_bytes(names):
    """Return the bytes of a zip whose entries are ``names`` (empty contents)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name in names:
            zf.writestr(name, b"")
    return buf.getvalue()


def _open_zip(names):
    return zipfile.ZipFile(io.BytesIO(_zip_bytes(names)))


def _apk(prefix="lib", libs=None, abis=ABIS):
    """Entry names for an archive bundling ``libs`` under each ABI."""
    libs = libs if libs is not None else (REQUIRED, "libflutter.so")
    return [f"{prefix}/{abi}/{lib}" for abi in abis for lib in libs]


class AbiToLibsTests(unittest.TestCase):
    def test_apk_layout(self):
        m = guard.abi_to_libs(_open_zip([f"lib/arm64-v8a/{REQUIRED}"]))
        self.assertEqual(m, {"arm64-v8a": {REQUIRED}})

    def test_aab_layout(self):
        m = guard.abi_to_libs(_open_zip([f"base/lib/arm64-v8a/{REQUIRED}"]))
        self.assertEqual(m, {"arm64-v8a": {REQUIRED}})

    def test_groups_multiple_libs_per_abi(self):
        m = guard.abi_to_libs(_open_zip(_apk()))
        self.assertEqual(set(m), set(ABIS))
        for abi in ABIS:
            self.assertEqual(m[abi], {REQUIRED, "libflutter.so"})

    def test_ignores_non_lib_and_nested_paths(self):
        m = guard.abi_to_libs(
            _open_zip(
                [
                    f"lib/arm64-v8a/{REQUIRED}",  # counted
                    "assets/foo.so",                # not under lib/<abi>/
                    "lib/arm64-v8a/sub/deep.so",    # nested deeper than <abi>/
                    "classes.dex",                  # not a .so
                ]
            )
        )
        self.assertEqual(m, {"arm64-v8a": {REQUIRED}})


class CheckArchiveTests(unittest.TestCase):
    def _run(self, names):
        with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as fh:
            fh.write(_zip_bytes(names))
            path = fh.name
        try:
            return guard.check_archive(path)
        finally:
            os.unlink(path)

    def test_green_all_abis_have_sqlite(self):
        ok, lines = self._run(_apk())
        self.assertTrue(ok)
        self.assertEqual(len(lines), len(ABIS))
        self.assertTrue(all("ok" in line for line in lines))

    def test_red_issue_433_no_sqlite_anywhere(self):
        # Ships its ABIs but the engine lib was dropped (the +eol regression).
        ok, lines = self._run(_apk(libs=("libflutter.so", "libapp.so")))
        self.assertFalse(ok)
        self.assertTrue(any(f"missing {REQUIRED}" in line for line in lines))

    def test_partial_abi_drop_fails(self):
        # Present for arm64 but missing for armeabi-v7a -> still a failure.
        names = (
            _apk(abis=("arm64-v8a",))
            + _apk(libs=("libflutter.so",), abis=("armeabi-v7a",))
        )
        ok, lines = self._run(names)
        self.assertFalse(ok)
        self.assertTrue(
            any("armeabi-v7a" in line and "missing" in line for line in lines)
        )

    def test_aab_layout_passes(self):
        ok, lines = self._run(_apk(prefix="base/lib"))
        self.assertTrue(ok)

    def test_no_native_libs_fails_closed(self):
        ok, lines = self._run(["classes.dex", "AndroidManifest.xml"])
        self.assertFalse(ok)
        self.assertTrue(any("no native libraries" in line for line in lines))


class MainTests(unittest.TestCase):
    def _main(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = guard.main(["check_native_libs_present.py", *args])
        return code, buf.getvalue()

    def _file(self, names):
        with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as fh:
            fh.write(_zip_bytes(names))
            self.addCleanup(os.unlink, fh.name)
            return fh.name

    def test_no_args_prints_usage(self):
        code, out = self._main()
        self.assertEqual(code, 2)
        self.assertIn("Usage:", out)

    def test_missing_file_is_error(self):
        code, out = self._main("/no/such/app.apk")
        self.assertEqual(code, 1)
        self.assertIn("ERROR reading", out)

    def test_green_file_exits_zero_and_reports_pass(self):
        code, out = self._main(self._file(_apk()))
        self.assertEqual(code, 0)
        self.assertIn("PASS", out)

    def test_red_file_exits_one_and_reports_fail(self):
        code, out = self._main(self._file(_apk(libs=("libflutter.so",))))
        self.assertEqual(code, 1)
        self.assertIn("FAIL", out)


if __name__ == "__main__":
    unittest.main()
