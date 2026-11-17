#!/usr/bin/env python3
"""Tests for taking a site catalogue release into the app.

Run: python3.14 scripts/site_catalogue_intake_test.py
"""

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import site_catalogue_intake as intake  # noqa: E402


def _catalogue(folder: Path, generated_at: str) -> None:
    path = folder / "site_catalogue.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '{"metadata":{"format":2,"generated_at":"%s"},"sites":[\n]}\n' % generated_at,
        encoding="utf-8",
    )


class _ReleaseFixture(unittest.TestCase):
    """A downloaded release and an empty repository to take it into."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.release = Path(self._tmp.name) / "release"
        self.repo = Path(self._tmp.name) / "repo"
        self.release.mkdir()
        for name in intake.INTAKE_FILES:
            (self.release / name).write_text(f"contents of {name}\n", encoding="utf-8")
        _catalogue(self.release, "2026-11-17T01:54:24Z")
        (self.release / "site_catalogue_open.json").write_text("{}\n", encoding="utf-8")


class TakeTest(_ReleaseFixture):
    def test_takes_every_release_file_to_its_place(self):
        changed = intake.take(self.release, self.repo)
        self.assertEqual(sorted(changed), sorted(intake.INTAKE_FILES.values()))
        self.assertIn("assets/data/site_catalogue.json", changed)
        self.assertEqual(
            (self.repo / "assets/data/site_catalogue.json").read_bytes(),
            (self.release / "site_catalogue.json").read_bytes(),
        )
        self.assertEqual(
            (self.repo / intake.INTAKE_FILES["format.json"]).read_text("utf-8"),
            "contents of format.json\n",
        )

    def test_the_open_build_is_not_taken(self):
        changed = intake.take(self.release, self.repo)
        self.assertFalse(any("open" in path for path in changed))

    def test_a_missing_file_changes_nothing(self):
        (self.release / "format.json").unlink()
        with self.assertRaises(ValueError) as caught:
            intake.take(self.release, self.repo)
        self.assertIn("format.json", str(caught.exception))
        self.assertFalse((self.repo / "assets/data/site_catalogue.json").exists())

    def test_an_older_release_is_refused(self):
        _catalogue(self.repo / "assets" / "data", "2026-12-01T06:00:00Z")
        with self.assertRaises(ValueError) as caught:
            intake.take(self.release, self.repo)
        self.assertIn("older", str(caught.exception))
        shipped = (self.repo / "assets/data/site_catalogue.json").read_text("utf-8")
        self.assertIn("2026-12-01T06:00:00Z", shipped)

    def test_an_older_release_is_taken_when_rolling_back_on_purpose(self):
        _catalogue(self.repo / "assets" / "data", "2026-12-01T06:00:00Z")
        changed = intake.take(self.release, self.repo, allow_older=True)
        self.assertIn("assets/data/site_catalogue.json", changed)

    def test_a_release_built_from_the_same_snapshots_is_not_older(self):
        # A research release rebuilds from the same snapshot set, so it keeps
        # the same stamp while its content changes.
        _catalogue(self.repo / "assets" / "data", "2026-11-17T01:54:24Z")
        self.assertIn("assets/data/site_catalogue.json", intake.take(self.release, self.repo))

    def test_the_pr_body(self):
        body = intake.pr_body("2026.11.17", "Built from snapshots-2026-11-16.")
        self.assertIn("2026.11.17", body)
        self.assertIn("Built from snapshots-2026-11-16.", body)
        self.assertIn("close and reopen this PR", body)
        self.assertIn("Refs #4514", body)


class MainTest(_ReleaseFixture):
    """The command line the workflow runs."""

    def _main(self, *argv):
        output = io.StringIO()
        with redirect_stdout(output):
            code = intake.main([str(self.release), *argv], repo=self.repo)
        return code, output.getvalue()

    def test_takes_the_release_and_writes_the_pr_body(self):
        notes = Path(self._tmp.name) / "notes.md"
        notes.write_text("Built from snapshots-2026-11-16.\n", encoding="utf-8")
        body = Path(self._tmp.name) / "body.md"
        code, output = self._main("--tag", "2026.11.17", "--notes", str(notes), "--body", str(body))
        self.assertEqual(code, 0)
        self.assertIn("assets/data/site_catalogue.json", output)
        text = body.read_text("utf-8")
        self.assertIn("2026.11.17", text)
        self.assertIn("Built from snapshots-2026-11-16.", text)

    def test_a_body_without_notes(self):
        body = Path(self._tmp.name) / "body.md"
        code, _ = self._main("--tag", "2026.11.17", "--body", str(body))
        self.assertEqual(code, 0)
        self.assertIn("Refs #4514", body.read_text("utf-8"))

    def test_a_refused_release_exits_1_and_writes_no_body(self):
        _catalogue(self.repo / "assets" / "data", "2026-12-01T06:00:00Z")
        body = Path(self._tmp.name) / "body.md"
        code, output = self._main("--tag", "2026.11.17", "--body", str(body))
        self.assertEqual(code, 1)
        self.assertIn("older", output)
        self.assertFalse(body.exists())

    def test_allow_older_reaches_take(self):
        _catalogue(self.repo / "assets" / "data", "2026-12-01T06:00:00Z")
        code, _ = self._main("--allow-older")
        self.assertEqual(code, 0)


class MalformedTest(_ReleaseFixture):
    def test_a_malformed_release_catalogue_is_refused_with_a_reason(self):
        (self.release / "site_catalogue.json").write_text('{"metadata":', encoding="utf-8")
        with self.assertRaises(ValueError) as caught:
            intake.take(self.release, self.repo)
        self.assertIn("site_catalogue.json", str(caught.exception))
        self.assertFalse((self.repo / "assets/data/site_catalogue.json").exists())


if __name__ == "__main__":
    unittest.main()
