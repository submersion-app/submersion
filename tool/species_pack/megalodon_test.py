#!/usr/bin/env python3
"""Unit tests for megalodon.py's checks that need no model tooling."""

import importlib.util
import os
import shutil
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("megalodon", os.path.join(_HERE, "megalodon.py"))
megalodon = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(megalodon)


class ConvertedDirTests(unittest.TestCase):
    def test_a_work_folder_without_the_model_says_how_to_convert_it(self):
        with tempfile.TemporaryDirectory() as work:
            with self.assertRaises(SystemExit) as stop:
                megalodon.converted_dir(work, "megalodon-2024")
            self.assertIn("megalodon.py convert megalodon-2024", str(stop.exception))

    def test_a_package_or_a_compiled_model_is_enough(self):
        for name in ("detector.mlpackage", "detector.mlmodelc"):
            with tempfile.TemporaryDirectory() as work:
                folder = os.path.join(work, "models", "megalodon-2024")
                os.makedirs(os.path.join(folder, name))
                self.assertEqual(megalodon.converted_dir(work, "megalodon-2024"), folder)


class ToolModelTests(unittest.TestCase):
    """The vision tool compiles a model package once and deletes it, so it
    is handed a copy and the converted package stays for build_pack.py."""

    def converted(self, work):
        package = os.path.join(work, "models", "megalodon-2024", "detector.mlpackage")
        os.makedirs(os.path.join(package, "Data"))
        with open(os.path.join(package, "Data", "weights.bin"), "wb") as fh:
            fh.write(b"one")
        return package

    def test_the_tool_gets_a_copy_and_the_package_stays(self):
        with tempfile.TemporaryDirectory() as work:
            package = self.converted(work)
            given = megalodon.tool_model(work, "megalodon-2024")
            self.assertNotEqual(given, package)
            self.assertTrue(given.endswith(".mlpackage"))
            with open(os.path.join(given, "Data", "weights.bin"), "rb") as fh:
                self.assertEqual(fh.read(), b"one")
            # What the tool does: compile beside the copy, delete the copy.
            os.makedirs(given[: -len(".mlpackage")] + ".mlmodelc")
            shutil.rmtree(given)
            self.assertTrue(os.path.isdir(package))
            self.assertTrue(megalodon.tool_model(work, "megalodon-2024").endswith(".mlmodelc"))

    def test_a_new_conversion_replaces_the_compiled_copy(self):
        with tempfile.TemporaryDirectory() as work:
            package = self.converted(work)
            given = megalodon.tool_model(work, "megalodon-2024")
            os.makedirs(given[: -len(".mlpackage")] + ".mlmodelc")
            shutil.rmtree(given)
            with open(os.path.join(package, "Data", "weights.bin"), "wb") as fh:
                fh.write(b"two, longer")
            again = megalodon.tool_model(work, "megalodon-2024")
            self.assertTrue(again.endswith(".mlpackage"))
            with open(os.path.join(again, "Data", "weights.bin"), "rb") as fh:
                self.assertEqual(fh.read(), b"two, longer")

    def test_a_new_conversion_changes_the_stamp(self):
        with tempfile.TemporaryDirectory() as work:
            package = self.converted(work)
            before = megalodon.converted_stamp(work, "megalodon-2024")
            with open(os.path.join(package, "Data", "weights.bin"), "wb") as fh:
                fh.write(b"two, longer")
            self.assertNotEqual(megalodon.converted_stamp(work, "megalodon-2024"), before)

    def test_a_folder_with_only_a_compiled_model_uses_it(self):
        with tempfile.TemporaryDirectory() as work:
            compiled = os.path.join(work, "models", "megalodon-2024", "detector.mlmodelc")
            os.makedirs(compiled)
            self.assertEqual(megalodon.tool_model(work, "megalodon-2024"), compiled)


class SettingsTests(unittest.TestCase):
    def test_the_scorer_runs_megalodon_as_a_pack_would(self):
        sys.path.insert(0, _HERE)
        import manifest

        pack = manifest.DETECTORS["megalodon"]
        self.assertEqual(megalodon.CHECKPOINTS["megalodon-2024"]["id"], pack["id"])
        written = megalodon.manifest_for_settings(base={"formatVersion": 2, "classifier": {}})
        self.assertEqual(written["formatVersion"], 2)
        self.assertEqual(written["detectors"], [pack])
        self.assertEqual(written["boxes"], manifest.BOXES)

    def test_the_settings_are_a_copy_of_the_packs(self):
        sys.path.insert(0, _HERE)
        import manifest

        self.assertIsNot(megalodon.SETTINGS, manifest.DETECTORS["megalodon"])
        self.assertIsNot(megalodon.SETTINGS["mean"], manifest.DETECTORS["megalodon"]["mean"])


if __name__ == "__main__":
    unittest.main()
