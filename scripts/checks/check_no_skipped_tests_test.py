#!/usr/bin/env python3
"""Unit tests for check_no_skipped_tests.py."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_no_skipped_tests",
    os.path.join(_HERE, "check_no_skipped_tests.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


def _start(test_id, name):
    return {"type": "testStart", "test": {"id": test_id, "name": name}}


def _done(test_id, result="success", skipped=False, hidden=False):
    return {
        "type": "testDone",
        "testID": test_id,
        "result": result,
        "skipped": skipped,
        "hidden": hidden,
    }


# The loader pseudo-test and setUpAll are reported as hidden tests; they are
# not the file's own tests and must never count as passed or skipped.
_LOADER = [
    _start(1, "loading integration_test/x_test.dart"),
    _done(1, hidden=True),
]

PASSED = _LOADER + [
    _start(2, "full encryption lifecycle against real SQLCipher"),
    _done(2),
    {"type": "done", "success": True},
]

# markTestSkipped() at runtime, in the shape a real `flutter test -d macos
# --file-reporter json:` run produced: the test starts normally, the reason
# arrives as a "skip" print, and testDone has skipped=true, result=success.
SKIPPED = _LOADER + [
    _start(2, "AVFoundation transcodes a real clip smaller"),
    {
        "type": "print",
        "testID": 2,
        "messageType": "skip",
        "message": "ffmpeg not on PATH; cannot synthesize the input clip",
    },
    _done(2, skipped=True),
    {"type": "done", "success": True},
]

# A test declared with `skip: 'reason'`: the reason arrives in the testStart
# metadata, and no "skip" print follows.
STATIC_SKIP = _LOADER + [
    {
        "type": "testStart",
        "test": {
            "id": 2,
            "name": "needs a dive computer",
            "metadata": {"skip": True, "skipReason": "no hardware in CI"},
        },
    },
    _done(2, skipped=True),
    {"type": "done", "success": True},
]

ONLY_HIDDEN = _LOADER + [{"type": "done", "success": True}]


def _write(events):
    fd, path = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        for event in events:
            fh.write(json.dumps(event) + "\n")
    return path


class SummarizeTests(unittest.TestCase):
    def test_passed_test_is_counted(self):
        summary = guard.summarize(json.dumps(e) for e in PASSED)
        self.assertEqual(summary.ran, 1)
        self.assertEqual(summary.skipped, [])

    def test_runtime_skip_is_reported_with_reason(self):
        summary = guard.summarize(json.dumps(e) for e in SKIPPED)
        self.assertEqual(summary.ran, 0)
        self.assertEqual(len(summary.skipped), 1)
        name, reason = summary.skipped[0]
        self.assertEqual(name, "AVFoundation transcodes a real clip smaller")
        self.assertIn("ffmpeg not on PATH", reason)

    def test_declared_skip_is_reported_with_its_metadata_reason(self):
        summary = guard.summarize(json.dumps(e) for e in STATIC_SKIP)
        self.assertEqual(summary.ran, 0)
        self.assertEqual(
            summary.skipped, [("needs a dive computer", "no hardware in CI")]
        )

    def test_hidden_tests_are_ignored(self):
        summary = guard.summarize(json.dumps(e) for e in ONLY_HIDDEN)
        self.assertEqual(summary.ran, 0)
        self.assertEqual(summary.skipped, [])

    def test_blank_and_non_json_lines_are_ignored(self):
        lines = ["", "   ", "not json"] + [json.dumps(e) for e in PASSED]
        self.assertEqual(guard.summarize(lines).ran, 1)


class CheckReportTests(unittest.TestCase):
    def _check(self, events):
        path = _write(events)
        self.addCleanup(os.unlink, path)
        return guard.check_report(path)

    def test_passing_report_is_ok(self):
        ok, lines = self._check(PASSED)
        self.assertTrue(ok)
        self.assertTrue(any("1 test ran" in line for line in lines))

    def test_skipped_test_fails(self):
        ok, lines = self._check(SKIPPED)
        self.assertFalse(ok)
        self.assertTrue(any("ffmpeg not on PATH" in line for line in lines))

    def test_report_with_no_tests_fails(self):
        # A file that ran nothing passes `flutter test` just like a skip does.
        ok, lines = self._check(ONLY_HIDDEN)
        self.assertFalse(ok)
        self.assertTrue(any("no tests ran" in line for line in lines))


class MainTests(unittest.TestCase):
    def _run(self, argv):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(argv)
        return rc, buf.getvalue()

    def test_all_reports_pass(self):
        path = _write(PASSED)
        self.addCleanup(os.unlink, path)
        rc, out = self._run(["prog", path])
        self.assertEqual(rc, 0)
        self.assertIn("PASS", out)

    def test_one_skipping_report_fails_the_run(self):
        good = _write(PASSED)
        bad = _write(SKIPPED)
        self.addCleanup(os.unlink, good)
        self.addCleanup(os.unlink, bad)
        rc, out = self._run(["prog", good, bad])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", out)

    def test_no_reports_fails(self):
        # An empty glob or a loop that excluded every file must not pass.
        rc, out = self._run(["prog"])
        self.assertEqual(rc, 1)
        self.assertIn("no test reports", out)

    def test_missing_report_fails(self):
        rc, out = self._run(["prog", os.path.join(_HERE, "does_not_exist.json")])
        self.assertEqual(rc, 1)
        self.assertIn("ERROR", out)


if __name__ == "__main__":
    unittest.main()
