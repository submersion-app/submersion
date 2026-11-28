#!/usr/bin/env python3
"""Tests for taking an equipment catalogue release into the app.

Run: python3.14 scripts/equipment_catalogue_intake_test.py
"""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import equipment_catalogue_intake as intake  # noqa: E402


def _catalogue(path: Path, generated_at: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"format": 1, "generatedAt": generated_at, "records": []}) + "\n",
        encoding="utf-8",
    )


class TakeTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.release = Path(self._tmp.name) / "release"
        self.repo = Path(self._tmp.name) / "repo"
        _catalogue(self.release / "equipment-catalogue.json", "2026-11-28T04:13:00Z")

    def test_copies_the_catalogue_and_writes_the_tag(self):
        written = intake.take(self.release, "2026.11.28", self.repo)
        self.assertEqual(written, [
            "assets/data/equipment_catalogue.json",
            "assets/data/equipment_catalogue.version",
        ])
        self.assertEqual(
            (self.repo / "assets/data/equipment_catalogue.json").read_text("utf-8"),
            (self.release / "equipment-catalogue.json").read_text("utf-8"),
        )
        self.assertEqual(
            (self.repo / "assets/data/equipment_catalogue.version").read_text("utf-8"),
            "2026.11.28\n",
        )

    def test_a_release_without_the_catalogue_changes_nothing(self):
        (self.release / "equipment-catalogue.json").unlink()
        with self.assertRaises(ValueError):
            intake.take(self.release, "2026.11.28", self.repo)
        self.assertFalse((self.repo / "assets").exists())

    def test_an_older_release_is_refused(self):
        _catalogue(self.repo / "assets/data/equipment_catalogue.json", "2026-12-01T00:00:00Z")
        with self.assertRaises(ValueError):
            intake.take(self.release, "2026.11.28", self.repo)

    def test_an_older_release_is_taken_when_allowed(self):
        _catalogue(self.repo / "assets/data/equipment_catalogue.json", "2026-12-01T00:00:00Z")
        intake.take(self.release, "2026.11.28", self.repo, allow_older=True)
        shipped = json.loads((self.repo / "assets/data/equipment_catalogue.json").read_text("utf-8"))
        self.assertEqual(shipped["generatedAt"], "2026-11-28T04:13:00Z")

    def test_a_bad_tag_is_refused(self):
        with self.assertRaises(ValueError):
            intake.take(self.release, "latest; rm -rf /", self.repo)

    def test_pr_body_links_the_release_and_the_issue(self):
        body = intake.pr_body("2026.11.28", "349 models from 38 makers.")
        self.assertIn("releases/tag/2026.11.28", body)
        self.assertIn("349 models from 38 makers.", body)
        self.assertIn("Refs #5118", body)
        self.assertIn("close and reopen", body)

    def test_main_writes_the_body(self):
        body = Path(self._tmp.name) / "body.md"
        with redirect_stdout(io.StringIO()):
            code = intake.main([str(self.release), "--tag", "2026.11.28", "--body", str(body)],
                               repo=self.repo)
        self.assertEqual(code, 0)
        self.assertIn("2026.11.28", body.read_text("utf-8"))

    def test_main_reports_a_refusal(self):
        (self.release / "equipment-catalogue.json").unlink()
        out = io.StringIO()
        with redirect_stdout(out):
            code = intake.main([str(self.release), "--tag", "2026.11.28"], repo=self.repo)
        self.assertEqual(code, 1)
        self.assertIn("missing", out.getvalue())


if __name__ == "__main__":
    unittest.main()
