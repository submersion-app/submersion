#!/usr/bin/env python3
"""Unit tests for stage_linux_package.py.

Run: python3 scripts/release/stage_linux_package_test.py

The tree this builds is the only thing standing between a working install and
a 40 MB archive of loose files: it is where the .desktop entry, the icons, the
AppStream metadata, the udev rules, and the install-method marker come from.
Every assertion here is something a user would otherwise discover as a missing
menu entry or an unreachable dive computer.
"""

import importlib.util
import os
import tempfile
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "stage_linux_package.py"
)
spec = importlib.util.spec_from_file_location("stage_linux_package", SCRIPT)
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


def make_bundle(root):
    """A minimal stand-in for build/linux/x64/release/bundle."""
    os.makedirs(os.path.join(root, "lib"))
    os.makedirs(os.path.join(root, "data", "flutter_assets"))
    with open(os.path.join(root, "submersion"), "w") as handle:
        handle.write("binary")
    with open(os.path.join(root, "lib", "libsqlcipher.so"), "w") as handle:
        handle.write("lib")
    return root


class TreeLayoutTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.bundle = make_bundle(os.path.join(self._tmp.name, "bundle"))
        self.staging = os.path.join(self._tmp.name, "staging")
        stage.build_tree(
            self.bundle, self.staging, version="1.7.7.7180", install_method="deb"
        )

    def tearDown(self):
        self._tmp.cleanup()

    def _path(self, *parts):
        return os.path.join(self.staging, *parts)

    def test_bundle_is_copied_verbatim(self):
        self.assertTrue(os.path.isfile(self._path("usr/lib/submersion/submersion")))
        self.assertTrue(
            os.path.isfile(self._path("usr/lib/submersion/lib/libsqlcipher.so"))
        )

    def test_bundle_relative_layout_is_preserved_for_the_rpath(self):
        # The runner finds its native assets through $ORIGIN/lib
        # (linux/CMakeLists.txt:17); flattening the tree would break every
        # bundled library at launch.
        binary = self._path("usr/lib/submersion/submersion")
        sibling_lib = self._path("usr/lib/submersion/lib")
        self.assertEqual(os.path.dirname(binary), os.path.dirname(sibling_lib))

    def test_wrapper_is_executable_and_execs_the_real_binary(self):
        wrapper = self._path("usr/bin/submersion")
        self.assertTrue(os.access(wrapper, os.X_OK))
        with open(wrapper) as handle:
            self.assertIn('exec /usr/lib/submersion/submersion "$@"', handle.read())

    def test_desktop_file_binds_the_window_to_its_icon(self):
        with open(self._path("usr/share/applications/app.submersion.desktop")) as h:
            text = h.read()
        self.assertIn("StartupWMClass=submersion", text)
        self.assertIn("Exec=submersion %U", text)
        self.assertIn("Icon=app.submersion", text)
        self.assertIn("Categories=Science;Education;Utility;", text)

    def test_icons_are_installed_at_every_hicolor_size(self):
        for size in (16, 32, 48, 64, 128, 256, 512):
            self.assertTrue(
                os.path.isfile(
                    self._path(
                        "usr/share/icons/hicolor/%dx%d/apps/app.submersion.png"
                        % (size, size)
                    )
                ),
                "missing %dx%d icon" % (size, size),
            )

    def test_appstream_metadata_carries_id_name_and_version(self):
        with open(self._path("usr/share/metainfo/app.submersion.metainfo.xml")) as h:
            text = h.read()
        self.assertIn("<id>app.submersion</id>", text)
        self.assertIn("<name>Submersion</name>", text)
        self.assertIn('version="1.7.7.7180"', text)

    def test_appstream_metadata_is_well_formed_xml(self):
        import xml.dom.minidom

        xml.dom.minidom.parse(
            self._path("usr/share/metainfo/app.submersion.metainfo.xml")
        )

    def test_udev_rules_are_installed_and_use_uaccess(self):
        path = self._path("usr/lib/udev/rules.d/60-submersion-divecomputers.rules")
        self.assertTrue(os.path.isfile(path))
        with open(path) as handle:
            text = handle.read()
        self.assertIn('TAG+="uaccess"', text)
        self.assertNotIn("plugdev", text)

    def test_install_method_marker_records_the_format(self):
        with open(self._path("usr/lib/submersion/INSTALL_METHOD")) as handle:
            self.assertEqual(handle.read().strip(), "deb")


class ReproducibleDateTest(unittest.TestCase):
    """SOURCE_DATE_EPOCH keeps two builds of one commit byte-identical."""

    def tearDown(self):
        os.environ.pop("SOURCE_DATE_EPOCH", None)

    def test_source_date_epoch_is_honoured(self):
        os.environ["SOURCE_DATE_EPOCH"] = "1788393600"  # 2026-09-03T00:00:00Z
        self.assertEqual(stage.build_date(), "2026-09-03")

    def test_source_date_epoch_is_read_as_utc_not_local_time(self):
        # 1788393600 is 2026-09-03T00:00:00Z. Interpreted in a timezone behind
        # UTC it would render as the 2nd, so two builders in different
        # timezones would produce different packages from one commit.
        os.environ["SOURCE_DATE_EPOCH"] = "1788393600"
        self.assertEqual(stage.build_date(), "2026-09-03")

    def test_falls_back_to_today_when_unset(self):
        os.environ.pop("SOURCE_DATE_EPOCH", None)
        self.assertRegex(stage.build_date(), r"^\d{4}-\d{2}-\d{2}$")

    def test_a_malformed_epoch_is_rejected_rather_than_ignored(self):
        # Silently falling back would make a build that meant to be
        # reproducible quietly stop being so.
        os.environ["SOURCE_DATE_EPOCH"] = "not-a-number"
        with self.assertRaises(SystemExit):
            stage.build_date()

    def test_metainfo_uses_the_pinned_date(self):
        os.environ["SOURCE_DATE_EPOCH"] = "1788393600"
        with tempfile.TemporaryDirectory() as tmp:
            bundle = make_bundle(os.path.join(tmp, "bundle"))
            staging = os.path.join(tmp, "staging")
            stage.build_tree(bundle, staging, version="1.0.0.1", install_method="deb")
            with open(
                os.path.join(staging, "usr/share/metainfo/app.submersion.metainfo.xml")
            ) as handle:
                self.assertIn('date="2026-09-03"', handle.read())


class InstallMethodTest(unittest.TestCase):
    def test_rpm_marker_says_rpm(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = make_bundle(os.path.join(tmp, "bundle"))
            staging = os.path.join(tmp, "staging")
            stage.build_tree(bundle, staging, version="1.0.0.1", install_method="rpm")
            with open(os.path.join(staging, "usr/lib/submersion/INSTALL_METHOD")) as h:
                self.assertEqual(h.read().strip(), "rpm")

    def test_unknown_install_method_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = make_bundle(os.path.join(tmp, "bundle"))
            with self.assertRaises(SystemExit):
                stage.build_tree(
                    bundle,
                    os.path.join(tmp, "s"),
                    version="1.0.0.1",
                    install_method="snap",
                )


if __name__ == "__main__":
    unittest.main()
