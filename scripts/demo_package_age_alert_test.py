#!/usr/bin/env python3
"""Unit tests for demo_package_age_alert.py.

Run: python3 scripts/demo_package_age_alert_test.py

The demo-mode sample logbook is built by hand and keeps its seasons only
while it is young, so the alert must notice an old package, open one rolling
issue for it, and close that issue once a rebuild is published.
"""

import datetime
import importlib.util
import json
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "demo_package_age_alert",
    os.path.join(_HERE, "demo_package_age_alert.py"),
)
alert = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(alert)

NOW = datetime.datetime(2026, 12, 20, 12, tzinfo=datetime.timezone.utc)


def _manifest(*stamps):
    return {
        "formatVersion": 1,
        "packages": [
            {"schemaVersion": 318 + i, "generatedAt": stamp}
            for i, stamp in enumerate(stamps)
        ],
    }


class FakeGh:
    """Records gh calls and answers `issue list` with the given issues."""

    def __init__(self, open_issues=()):
        self.open_issues = list(open_issues)
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        if args[:2] == ["issue", "list"]:
            return json.dumps(self.open_issues)
        return ""

    def commands(self):
        return [call[:2] for call in self.calls]


class AgeTest(unittest.TestCase):
    def test_the_newest_package_decides_the_age(self):
        manifest = _manifest(
            "2026-09-01T00:00:00.000Z", "2026-11-25T06:34:03.026423Z"
        )

        newest = alert.newest_generated_at(manifest)

        self.assertEqual(
            newest,
            datetime.datetime(
                2026, 11, 25, 6, 34, 3, 26423, tzinfo=datetime.timezone.utc
            ),
        )

    def test_a_package_older_than_six_weeks_is_stale(self):
        fresh = datetime.datetime(2026, 11, 9, tzinfo=datetime.timezone.utc)
        old = datetime.datetime(2026, 11, 7, tzinfo=datetime.timezone.utc)

        self.assertFalse(alert.is_stale(fresh, NOW))
        self.assertTrue(alert.is_stale(old, NOW))
        self.assertEqual(alert.MAX_AGE_DAYS, 42)

    def test_a_manifest_without_packages_is_an_error(self):
        with self.assertRaises(ValueError):
            alert.newest_generated_at({"formatVersion": 1, "packages": []})


class RunTest(unittest.TestCase):
    def _run(self, manifest, gh):
        return alert.run(
            {"repo": "owner/repo"},
            fetch=lambda: manifest,
            gh=gh,
            now=NOW,
        )

    def test_a_stale_package_opens_one_rolling_issue(self):
        gh = FakeGh()

        self._run(_manifest("2026-10-29T06:34:03Z"), gh)

        create = [c for c in gh.calls if c[:2] == ["issue", "create"]]
        self.assertEqual(len(create), 1)
        body = create[0][create[0].index("--body") + 1]
        self.assertIn(alert.MARKER, body)
        self.assertIn("2026-10-29", body)
        self.assertIn(alert.TITLE, create[0])

    def test_a_stale_package_with_an_open_issue_adds_nothing(self):
        gh = FakeGh([{"number": 7, "body": f"x {alert.MARKER}"}])

        self._run(_manifest("2026-10-29T06:34:03Z"), gh)

        self.assertEqual(gh.commands(), [["issue", "list"]])

    def test_a_fresh_package_closes_the_open_issue(self):
        gh = FakeGh([{"number": 7, "body": f"x {alert.MARKER}"}])

        self._run(_manifest("2026-12-01T00:00:00Z"), gh)

        close = [c for c in gh.calls if c[:2] == ["issue", "close"]]
        self.assertEqual(len(close), 1)
        self.assertIn("7", close[0])

    def test_a_fresh_package_without_an_issue_does_nothing(self):
        gh = FakeGh()

        self._run(_manifest("2026-12-01T00:00:00Z"), gh)

        self.assertEqual(gh.commands(), [["issue", "list"]])

    def test_an_issue_without_the_marker_is_not_the_alert(self):
        gh = FakeGh([{"number": 9, "body": "Someone else's issue"}])

        self._run(_manifest("2026-10-29T06:34:03Z"), gh)

        self.assertIn(["issue", "create"], gh.commands())


class WorkflowTest(unittest.TestCase):
    def test_a_scheduled_workflow_runs_the_alert(self):
        path = os.path.join(
            _HERE, "..", ".github", "workflows", "demo-package-age.yml"
        )
        with open(path, encoding="utf-8") as f:
            workflow = f.read()

        self.assertIn("schedule:", workflow)
        self.assertIn("python3 scripts/demo_package_age_alert.py", workflow)
        self.assertIn("issues: write", workflow)


if __name__ == "__main__":
    unittest.main()
