#!/usr/bin/env python3
"""Unit tests for megalodon.py's checks that need no model tooling."""

import importlib.util
import os
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


if __name__ == "__main__":
    unittest.main()
