#!/usr/bin/env python3
"""Unit tests for linux_package_deps.py.

Run: python3 scripts/linux_package_deps_test.py

The regression this guards: desktop_webview_window's CMake silently falls back
from webkit2gtk-4.1 to 4.0 when 4.1 is absent at build time, which changes what
the shipped binary needs without failing the build. A hand-written dependency
list would then be wrong in a way nothing detects until a user's package
manager installs the wrong library. Deriving the list from DT_NEEDED and
failing on any unmapped soname makes that impossible to ship.
"""

import importlib.util
import json
import os
import tempfile
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "linux_package_deps.py"
)
spec = importlib.util.spec_from_file_location("linux_package_deps", SCRIPT)
deps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deps)

SONAME_MAP = {
    "libgtk-3.so.0": {
        "apt": "libgtk-3-0",
        "rpm": "libgtk-3.so.0()(64bit)",
        "dnf": "gtk3",
        "pacman": "gtk3",
        "zypper": "gtk3",
    },
    "libc.so.6": {
        "apt": "libc6",
        "rpm": "libc.so.6()(64bit)",
        "dnf": "glibc",
        "pacman": "glibc",
        "zypper": "glibc",
    },
    "libglib-2.0.so.0": {
        "apt": "libglib2.0-0",
        "rpm": "libglib-2.0.so.0()(64bit)",
        "dnf": "glib2",
        "pacman": "glib2",
        "zypper": "libglib-2_0-0",
    },
}


class MapSonamesTest(unittest.TestCase):
    def test_maps_to_apt_names(self):
        result = deps.map_sonames({"libgtk-3.so.0", "libc.so.6"}, SONAME_MAP, "apt")
        self.assertEqual(result, ["libc6", "libgtk-3-0"])

    def test_maps_to_rpm_soname_provides(self):
        result = deps.map_sonames({"libgtk-3.so.0"}, SONAME_MAP, "rpm")
        self.assertEqual(result, ["libgtk-3.so.0()(64bit)"])

    def test_deduplicates_shared_packages(self):
        # Several glib sonames map to one apt package; the list must not repeat it.
        result = deps.map_sonames({"libglib-2.0.so.0", "libc.so.6"}, SONAME_MAP, "apt")
        self.assertEqual(result, ["libc6", "libglib2.0-0"])

    def test_output_is_sorted_for_reproducibility(self):
        result = deps.map_sonames(
            {"libgtk-3.so.0", "libc.so.6", "libglib-2.0.so.0"}, SONAME_MAP, "apt"
        )
        self.assertEqual(result, sorted(result))

    def test_excluded_soname_contributes_no_dependency(self):
        # libjvm.so is reachable from the bundle but never loaded on Linux;
        # declaring it would put a JRE on every user's machine.
        soname_map = dict(SONAME_MAP)
        soname_map["libjvm.so"] = {"exclude": "never loaded on Linux"}
        result = deps.map_sonames(
            {"libc.so.6", "libjvm.so"}, soname_map, "apt"
        )
        self.assertEqual(result, ["libc6"])

    def test_excluded_soname_is_not_treated_as_unmapped(self):
        soname_map = {"libjvm.so": {"exclude": "never loaded on Linux"}}
        self.assertEqual(deps.map_sonames({"libjvm.so"}, soname_map, "rpm"), [])

    def test_unmapped_soname_is_a_hard_failure(self):
        with self.assertRaises(SystemExit) as caught:
            deps.map_sonames({"libwebkit2gtk-4.0.so.37"}, SONAME_MAP, "apt")
        self.assertIn("libwebkit2gtk-4.0.so.37", str(caught.exception))


class BundledFilteringTest(unittest.TestCase):
    def test_bundled_libraries_are_not_dependencies(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "lib"))
            for name in ("libsqlcipher.so", "libdivecomputer.so.0"):
                open(os.path.join(root, "lib", name), "w").close()
            bundled = deps.bundled_sonames(root)
        self.assertEqual(bundled, {"libsqlcipher.so", "libdivecomputer.so.0"})

    def test_missing_lib_dir_yields_no_bundled_names(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(deps.bundled_sonames(root), set())


class LoadMapTest(unittest.TestCase):
    def test_comment_key_is_ignored(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(
                {"_comment": "notes", "libc.so.6": SONAME_MAP["libc.so.6"]}, handle
            )
            path = handle.name
        try:
            loaded = deps.load_map(path)
            self.assertNotIn("_comment", loaded)
            self.assertIn("libc.so.6", loaded)
        finally:
            os.unlink(path)

    def test_shipped_map_covers_every_library_the_plugins_link(self):
        # The real map must stay loadable and cover the core GTK stack; an
        # entry lost to a bad edit would only surface as a CI build failure.
        shipped = deps.load_map(deps.DEFAULT_MAP)
        for soname in (
            "libgtk-3.so.0",
            "libwebkit2gtk-4.1.so.0",
            "libsoup-3.0.so.0",
            "libsecret-1.so.0",
            "libstdc++.so.6",
            "libepoxy.so.0",
            "libfontconfig.so.1",
            "ld-linux-x86-64.so.2",
        ):
            self.assertIn(soname, shipped)
            for column in ("apt", "rpm", "dnf", "pacman", "zypper"):
                self.assertTrue(shipped[soname][column])

    def test_every_shipped_entry_is_either_mapped_or_explicitly_excluded(self):
        # A half-filled entry would emit an empty dependency token, which fpm
        # accepts and which then makes the package undeployable.
        shipped = deps.load_map(deps.DEFAULT_MAP)
        for soname, entry in shipped.items():
            with self.subTest(soname=soname):
                if entry.get("exclude"):
                    self.assertTrue(entry["exclude"].strip())
                    continue
                for column in ("apt", "rpm", "dnf", "pacman", "zypper"):
                    self.assertTrue(entry.get(column), soname)

    def test_libjvm_is_excluded_rather_than_mapped_to_a_jre(self):
        shipped = deps.load_map(deps.DEFAULT_MAP)
        self.assertIn("exclude", shipped["libjvm.so"])


if __name__ == "__main__":
    unittest.main()
