#!/usr/bin/env python3
"""Unit tests for check_glibc_floor.py.

Run: python3 scripts/check_glibc_floor_test.py

The case this guards is issue #3523: the Linux release build runs on a hosted
runner, and when GitHub moves that runner to a newer Ubuntu the shipped
binaries start needing that Ubuntu's glibc. Every build step still succeeds,
and the app then refuses to start on the distributions
docs/user/installation.md says it supports.

readelf is not run here: the tests feed the guard captured `readelf -V -W`
output, so they run on any host, including macOS where binutils is absent.
"""

import contextlib
import importlib.util
import io
import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_glibc_floor", os.path.join(_HERE, "check_glibc_floor.py")
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

INSTALLATION_DOC = os.path.join(_HERE, os.pardir, "docs", "user", "installation.md")

ELF_MAGIC = b"\x7fELF"


def _readelf(needs, definitions=(), symbols=()):
    """Build `readelf -V -W` output shaped like binutils prints it.

    ``needs`` is ``[(file, [version, ...]), ...]`` for the version needs
    section. ``definitions`` and ``symbols`` are version names placed in the
    other two sections, which name versions too but are not requirements.
    """
    lines = []
    if symbols:
        lines.append("")
        lines.append(
            "Version symbols section '.gnu.version' contains 4 entries:"
        )
        lines.append(" Addr: 0x0000000000001234  Offset: 0x00001234  Link: 6 (.dynsym)")
        entries = "  ".join(
            "%d (%s)" % (index + 2, name) for index, name in enumerate(symbols)
        )
        lines.append("  000:   0 (*local*)       " + entries)
    if definitions:
        lines.append("")
        lines.append(
            "Version definition section '.gnu.version_d' contains 2 entries:"
        )
        lines.append(" Addr: 0x0000000000001500  Offset: 0x00001500  Link: 7 (.dynstr)")
        lines.append(
            "  000000: Rev: 1  Flags: BASE  Index: 1  Cnt: 1  Name: libexample.so"
        )
        for name in definitions:
            lines.append(
                "  0x001c: Rev: 1  Flags: none  Index: 2  Cnt: 1  Name: %s" % name
            )
    if needs:
        lines.append("")
        lines.append(
            "Version needs section '.gnu.version_r' contains %d entries:" % len(needs)
        )
        lines.append(" Addr: 0x0000000000001600  Offset: 0x00001600  Link: 7 (.dynstr)")
        for file_name, versions in needs:
            lines.append(
                "  000000: Version: 1  File: %s  Cnt: %d" % (file_name, len(versions))
            )
            for index, name in enumerate(versions):
                lines.append(
                    "  0x0010:   Name: %s  Flags: none  Version: %d" % (name, index + 2)
                )
    return "\n".join(lines) + "\n"


class ParseVersionTests(unittest.TestCase):
    def test_versions_compare_numerically_not_as_strings(self):
        # As strings "2.4" sorts after "2.38"; as glibc versions it is older.
        self.assertLess(guard.parse_version("2.4"), guard.parse_version("2.38"))
        self.assertLess(guard.parse_version("2.2.5"), guard.parse_version("2.3"))
        self.assertEqual(guard.parse_version("2.38"), (2, 38))


class RequiredVersionsTests(unittest.TestCase):
    def test_collects_glibc_versions_from_every_needed_library(self):
        output = _readelf(
            [
                ("libm.so.6", ["GLIBC_2.29"]),
                ("libc.so.6", ["GLIBC_2.38", "GLIBC_2.2.5"]),
            ]
        )
        self.assertEqual(
            guard.required_glibc_versions(output),
            {"2.29", "2.38", "2.2.5"},
        )

    def test_ignores_libstdcxx_and_private_versions(self):
        output = _readelf(
            [
                ("libc.so.6", ["GLIBC_2.34", "GLIBC_PRIVATE"]),
                ("libstdc++.so.6", ["GLIBCXX_3.4.32", "CXXABI_1.3.15"]),
            ]
        )
        self.assertEqual(guard.required_glibc_versions(output), {"2.34"})

    def test_ignores_versions_named_outside_the_needs_section(self):
        # A library that defines its own GLIBC_-looking version, and the
        # per-symbol table that repeats requirement names in parentheses,
        # must not count: only the needs section is what the loader checks.
        output = _readelf(
            [("libc.so.6", ["GLIBC_2.17"])],
            definitions=["GLIBC_9.99"],
            symbols=["GLIBC_9.98", "GLIBC_2.17"],
        )
        self.assertEqual(guard.required_glibc_versions(output), {"2.17"})

    def test_no_needs_section_means_no_requirements(self):
        self.assertEqual(guard.required_glibc_versions(""), set())


class IsElfTests(unittest.TestCase):
    def test_unreadable_path_is_not_elf(self):
        # A file that vanishes between the directory walk and the read, or
        # a directory, cannot be opened; it is skipped rather than crashing.
        missing = os.path.join(tempfile.gettempdir(), "glibc-floor-no-such-file")
        self.assertFalse(guard.is_elf(missing))
        self.assertFalse(guard.is_elf(tempfile.gettempdir()))


class BundleBuilder:
    """Builds a throwaway Linux bundle whose files a fake readelf describes."""

    def __init__(self, test, elf_files=None, other_files=()):
        self.root = tempfile.mkdtemp()
        test.addCleanup(shutil.rmtree, self.root)
        self.outputs = {}
        for rel, output in (elf_files or {}).items():
            self._write(rel, ELF_MAGIC + b"\x02\x01\x01")
            self.outputs[os.path.join(self.root, rel.replace("/", os.sep))] = output
        for rel in other_files:
            self._write(rel, b"not an ELF file")

    def _write(self, rel, content):
        path = os.path.join(self.root, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(content)

    def reader(self, path):
        return self.outputs[path]


class CheckBundleTests(unittest.TestCase):
    def _check(self, max_version="2.38", **kwargs):
        bundle = BundleBuilder(self, **kwargs)
        return guard.check_bundle(bundle.root, max_version, reader=bundle.reader)

    def test_green_bundle_at_the_floor_passes(self):
        ok, lines = self._check(
            elf_files={
                "submersion": _readelf([("libc.so.6", ["GLIBC_2.34", "GLIBC_2.2.5"])]),
                "lib/libsqlcipher.so": _readelf([("libc.so.6", ["GLIBC_2.38"])]),
                "lib/libapp.so": _readelf([("libc.so.6", ["GLIBC_2.17"])]),
            }
        )
        self.assertTrue(ok, lines)
        self.assertIn("  ok    lib/libsqlcipher.so needs GLIBC_2.38", lines)
        self.assertIn("  bundle needs glibc 2.38 (limit 2.38)", lines)

    def test_issue_3523_library_built_on_a_newer_runner_fails(self):
        # The regression: libsqlcipher.so rebuilt on Ubuntu 26.04 picks up a
        # symbol version from glibc 2.43 while the app binary itself is fine.
        ok, lines = self._check(
            elf_files={
                "submersion": _readelf([("libc.so.6", ["GLIBC_2.34"])]),
                "lib/libsqlcipher.so": _readelf(
                    [("libc.so.6", ["GLIBC_2.43", "GLIBC_2.38"])]
                ),
            }
        )
        self.assertFalse(ok)
        self.assertIn(
            "  FAIL  lib/libsqlcipher.so needs GLIBC_2.43, newer than 2.38",
            lines,
        )
        self.assertIn("  ok    submersion needs GLIBC_2.34", lines)

    def test_numeric_comparison_does_not_flag_old_two_digit_versions(self):
        ok, lines = self._check(
            elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.4"])])},
        )
        self.assertTrue(ok, lines)

    def test_a_raised_limit_is_honoured(self):
        ok, lines = self._check(
            max_version="2.39",
            elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.39"])])},
        )
        self.assertTrue(ok, lines)

    def test_non_elf_files_are_skipped(self):
        ok, lines = self._check(
            elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.34"])])},
            other_files=("data/icudtl.dat", "data/flutter_assets/AssetManifest.bin"),
        )
        self.assertTrue(ok, lines)
        self.assertEqual(
            [line for line in lines if line.startswith("  ok")],
            ["  ok    submersion needs GLIBC_2.34"],
        )

    def test_elf_file_without_glibc_requirements_is_reported_not_failed(self):
        # Data-only or statically linked objects need no glibc version.
        ok, lines = self._check(
            elf_files={
                "submersion": _readelf([("libc.so.6", ["GLIBC_2.34"])]),
                "lib/libflutter_linux_gtk.so": _readelf([]),
            }
        )
        self.assertTrue(ok, lines)
        self.assertIn("  ok    lib/libflutter_linux_gtk.so needs no GLIBC version", lines)

    def test_symlinked_libraries_are_checked_once(self):
        # Bundles carry soname links such as libfoo.so -> libfoo.so.1; the
        # target is checked, the link is not reported a second time.
        bundle = BundleBuilder(
            self,
            elf_files={
                "submersion": _readelf([("libc.so.6", ["GLIBC_2.34"])]),
                "lib/libfoo.so.1": _readelf([("libc.so.6", ["GLIBC_2.17"])]),
            },
        )
        try:
            os.symlink("libfoo.so.1", os.path.join(bundle.root, "lib", "libfoo.so"))
        except OSError as error:
            # Windows allows symlinks only with Developer Mode or admin rights.
            self.skipTest("cannot create symlinks here: %s" % error)
        ok, lines = guard.check_bundle(bundle.root, "2.38", reader=bundle.reader)
        self.assertTrue(ok, lines)
        self.assertFalse(any("lib/libfoo.so " in line for line in lines), lines)

    def test_bundle_with_no_elf_files_fails_closed(self):
        ok, lines = self._check(other_files=("data/icudtl.dat",))
        self.assertFalse(ok)
        self.assertIn("  FAIL  no ELF files found in the bundle", lines)

    def test_bundle_needing_no_glibc_version_at_all_fails_closed(self):
        # Every real build links libc. Finding no requirement anywhere means
        # the readelf output was not understood, and passing would be vacuous.
        ok, lines = self._check(elf_files={"submersion": _readelf([])})
        self.assertFalse(ok)
        self.assertIn(
            "  FAIL  no GLIBC version requirement found in any ELF file; "
            "the readelf output was not understood",
            lines,
        )


class MainTests(unittest.TestCase):
    def _run(self, argv, reader=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = guard.main(argv, reader=reader)
        return code, out.getvalue()

    def test_no_arguments_prints_usage(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                self._run(["check_glibc_floor.py"])
        self.assertEqual(raised.exception.code, 2)

    def test_default_limit_is_the_documented_floor(self):
        # The guard and the installation docs make the same promise; raising
        # one without the other ships a release the docs misdescribe.
        with open(INSTALLATION_DOC, encoding="utf-8") as fh:
            doc = fh.read()
        self.assertIn(
            "glibc %s or newer" % guard.DEFAULT_MAX_GLIBC,
            doc,
            "docs/user/installation.md and DEFAULT_MAX_GLIBC disagree",
        )

    def test_malformed_max_is_a_usage_error(self):
        for bad in ("2.38a", "", "2", "latest"):
            with self.subTest(max=bad):
                with contextlib.redirect_stderr(io.StringIO()) as err:
                    with self.assertRaises(SystemExit) as raised:
                        self._run(["check_glibc_floor.py", "--max", bad, "bundle"])
                self.assertEqual(raised.exception.code, 2)
                self.assertIn("expected a version such as 2.38", err.getvalue())

    def test_passing_bundle_exits_zero(self):
        bundle = BundleBuilder(
            self, elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.38"])])}
        )
        code, out = self._run(["check_glibc_floor.py", bundle.root], bundle.reader)
        self.assertEqual(code, 0, out)
        self.assertIn("-> PASS", out)

    def test_failing_bundle_exits_one_and_names_the_issue(self):
        bundle = BundleBuilder(
            self, elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.39"])])}
        )
        code, out = self._run(["check_glibc_floor.py", bundle.root], bundle.reader)
        self.assertEqual(code, 1, out)
        self.assertIn("-> FAIL", out)
        self.assertIn("#3523", out)

    def test_max_flag_overrides_the_default(self):
        bundle = BundleBuilder(
            self, elf_files={"submersion": _readelf([("libc.so.6", ["GLIBC_2.39"])])}
        )
        code, out = self._run(
            ["check_glibc_floor.py", "--max", "2.39", bundle.root], bundle.reader
        )
        self.assertEqual(code, 0, out)


class ReadelfTests(unittest.TestCase):
    def test_missing_readelf_exits_with_install_hint(self):
        with self.assertRaises(SystemExit) as raised:
            guard.read_version_info(__file__, readelf="readelf-that-does-not-exist")
        self.assertIn("binutils", str(raised.exception.code))

    def test_failing_readelf_exits_naming_the_file(self):
        failure = subprocess.CalledProcessError(1, ["readelf", "-V", "-W", __file__])
        with mock.patch.object(guard.subprocess, "run", side_effect=failure):
            with self.assertRaises(SystemExit) as raised:
                guard.read_version_info(__file__)
        self.assertIn("readelf failed on", str(raised.exception.code))
        self.assertIn(__file__, str(raised.exception.code))

    def test_readelf_runs_in_the_c_locale(self):
        # A translated binutils would print section headers the parser
        # cannot read, and every bundle would fail as "not understood".
        completed = subprocess.CompletedProcess([], 0, stdout="output")
        with mock.patch.dict(os.environ, {"LC_ALL": "de_DE.UTF-8"}):
            with mock.patch.object(
                guard.subprocess, "run", return_value=completed
            ) as run:
                self.assertEqual(guard.read_version_info(__file__), "output")
        self.assertEqual(run.call_args.kwargs["env"]["LC_ALL"], "C")


if __name__ == "__main__":
    unittest.main()
