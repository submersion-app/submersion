#!/usr/bin/env python3
"""Unit tests for play_beta_cooldown.py."""

import contextlib
import importlib.util
import io
import json
import os
import subprocess
import unittest
from datetime import datetime, timedelta, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))

_spec = importlib.util.spec_from_file_location(
    "play_beta_cooldown", os.path.join(_HERE, "play_beta_cooldown.py")
)
cooldown = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cooldown)

BETA_WORKFLOW = os.path.join(_HERE, "..", "..", ".github", "workflows", "beta.yml")

NOW = datetime(2026, 10, 3, 20, 0, tzinfo=timezone.utc)


def iso(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def promoted_job(completed_at, conclusion="success"):
    """A Play job whose promotion step ended at completed_at."""
    return {
        "name": cooldown.PLAY_JOB,
        "steps": [
            {"name": "Upload to Play internal testing", "conclusion": "success",
             "completed_at": iso(completed_at - timedelta(minutes=2))},
            {"name": cooldown.PROMOTE_STEP, "conclusion": conclusion,
             "completed_at": iso(completed_at)},
        ],
    }


def skipped_promotion_job(completed_at):
    return {
        "name": cooldown.PLAY_JOB,
        "steps": [
            {"name": "Upload to Play internal testing", "conclusion": "success",
             "completed_at": iso(completed_at)},
            {"name": cooldown.PROMOTE_STEP, "conclusion": "skipped",
             "completed_at": iso(completed_at)},
        ],
    }


class FakeGh:
    """Serves the two endpoints the script reads, and records the calls."""

    def __init__(self, runs, jobs_by_run, fail=False):
        self.runs = runs
        self.jobs_by_run = jobs_by_run
        self.fail = fail
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        if self.fail:
            raise subprocess.CalledProcessError(1, ["gh", *args], stderr="HTTP 502")
        path = args[-1]
        if "/workflows/" in path:
            return json.dumps([{"workflow_runs": self.runs}])
        run_id = int(path.split("/runs/")[1].split("/")[0])
        return json.dumps([{"jobs": self.jobs_by_run.get(run_id, [])}])


def run_entry(run_id, created, conclusion="success"):
    return {"id": run_id, "created_at": iso(created), "conclusion": conclusion}


class LastPromotionTest(unittest.TestCase):
    def test_finds_the_newest_successful_promotion(self):
        gh = FakeGh(
            [run_entry(3, NOW - timedelta(hours=5)), run_entry(2, NOW - timedelta(hours=30))],
            {
                3: [skipped_promotion_job(NOW - timedelta(hours=4))],
                2: [promoted_job(NOW - timedelta(hours=29))],
            },
        )
        last = cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        self.assertEqual(last, NOW - timedelta(hours=29))

    def test_the_old_direct_upload_counts_as_a_promotion(self):
        # Before #2887 the job uploaded straight to open testing. Counting that
        # step keeps the first run after the switch from resetting a review.
        legacy = {
            "name": "Upload Android beta to Play open testing",
            "steps": [{"name": "Upload to Play open testing", "conclusion": "success",
                       "completed_at": iso(NOW - timedelta(hours=6))}],
        }
        gh = FakeGh([run_entry(2, NOW - timedelta(hours=7))], {2: [legacy]})
        last = cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        self.assertEqual(last, NOW - timedelta(hours=6))

    def test_other_jobs_and_steps_are_ignored(self):
        gh = FakeGh(
            [run_entry(2, NOW - timedelta(hours=7))],
            {2: [
                {"name": "Upload iOS beta to TestFlight",
                 "steps": [{"name": cooldown.PROMOTE_STEP, "conclusion": "success",
                            "completed_at": iso(NOW - timedelta(hours=6))}]},
                skipped_promotion_job(NOW - timedelta(hours=6)),
            ]},
        )
        self.assertIsNone(
            cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        )

    def test_a_failed_promotion_does_not_count(self):
        # A refused promotion committed nothing, so no review was started.
        gh = FakeGh(
            [run_entry(2, NOW - timedelta(hours=3), conclusion="failure")],
            {2: [promoted_job(NOW - timedelta(hours=2), conclusion="failure")]},
        )
        self.assertIsNone(
            cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        )

    def test_the_current_run_is_ignored(self):
        gh = FakeGh(
            [run_entry(9, NOW - timedelta(minutes=30))],
            {9: [promoted_job(NOW - timedelta(minutes=1))]},
        )
        self.assertIsNone(
            cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=9)
        )
        self.assertFalse(any("/runs/9/" in c[-1] for c in gh.calls))

    def test_runs_gated_off_are_not_read(self):
        # Most Beta runs are skipped by precheck; reading their jobs is wasted calls.
        gh = FakeGh([run_entry(4, NOW - timedelta(hours=1), conclusion="skipped")], {})
        cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        self.assertEqual([c for c in gh.calls if "/runs/4/" in c[-1]], [])

    def test_every_attempt_of_a_run_is_read(self):
        # A re-run that promoted counts; filter=all returns earlier attempts too.
        gh = FakeGh([run_entry(5, NOW - timedelta(hours=2))], {5: []})
        cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        jobs_call = next(c for c in gh.calls if "/runs/5/" in c[-1])
        self.assertIn("filter=all", jobs_call[-1])

    def test_queries_only_the_window(self):
        gh = FakeGh([], {})
        cooldown.last_promotion(gh, "o/r", since=NOW - timedelta(hours=60), exclude_run=None)
        runs_call = gh.calls[0][-1]
        self.assertIn("repos/o/r/actions/workflows/beta.yml/runs", runs_call)
        self.assertIn("created=%3E%3D" + iso(NOW - timedelta(hours=60)), runs_call)
        self.assertIn("--paginate", gh.calls[0])


class DecideTest(unittest.TestCase):
    def test_due_when_never_promoted_in_the_window(self):
        due, last = cooldown.decide(None, NOW, hours=48)
        self.assertTrue(due)
        self.assertIsNone(last)

    def test_not_due_inside_the_cooldown(self):
        due, _ = cooldown.decide(NOW - timedelta(hours=47, minutes=59), NOW, hours=48)
        self.assertFalse(due)

    def test_due_once_the_cooldown_has_passed(self):
        due, _ = cooldown.decide(NOW - timedelta(hours=48), NOW, hours=48)
        self.assertTrue(due)

    def test_zero_hours_always_promotes(self):
        due, _ = cooldown.decide(NOW - timedelta(minutes=1), NOW, hours=0)
        self.assertTrue(due)


class ParseHoursTest(unittest.TestCase):
    def test_blank_uses_the_default(self):
        self.assertEqual(cooldown.parse_hours(""), cooldown.DEFAULT_HOURS)
        self.assertEqual(cooldown.parse_hours(None), cooldown.DEFAULT_HOURS)

    def test_reads_whole_and_fractional_hours(self):
        self.assertEqual(cooldown.parse_hours("72"), 72.0)
        self.assertEqual(cooldown.parse_hours(" 1.5 "), 1.5)

    def test_rejects_nonsense(self):
        for bad in ("-1", "two days", "nan", "inf"):
            with self.assertRaises(ValueError, msg=bad):
                cooldown.parse_hours(bad)


class MainTest(unittest.TestCase):
    def env(self, output_path, **extra):
        env = {
            "GITHUB_REPOSITORY": "o/r",
            "GITHUB_RUN_ID": "9",
            "GITHUB_OUTPUT": output_path,
        }
        env.update(extra)
        return env

    def run_main(self, gh, **extra):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, "out")
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                code = cooldown.main(self.env(output, **extra), gh=gh, now=NOW)
            written = open(output).read() if os.path.exists(output) else ""
        return code, written, stdout.getvalue()

    def test_writes_due_true_when_nothing_was_promoted_recently(self):
        code, written, _ = self.run_main(FakeGh([], {}))
        self.assertEqual(code, 0)
        self.assertIn("due=true\n", written)

    def test_writes_due_false_and_says_when_inside_the_cooldown(self):
        gh = FakeGh(
            [run_entry(2, NOW - timedelta(hours=10))],
            {2: [promoted_job(NOW - timedelta(hours=9))]},
        )
        code, written, stdout = self.run_main(gh)
        self.assertEqual(code, 0)
        self.assertIn("due=false\n", written)
        self.assertIn(iso(NOW - timedelta(hours=9)), stdout)
        self.assertIn("::notice", stdout)

    def test_honours_the_configured_hours(self):
        gh = FakeGh(
            [run_entry(2, NOW - timedelta(hours=10))],
            {2: [promoted_job(NOW - timedelta(hours=9))]},
        )
        _, written, _ = self.run_main(gh, PLAY_OPEN_TESTING_COOLDOWN_HOURS="8")
        self.assertIn("due=true\n", written)

    def test_zero_hours_skips_the_api_entirely(self):
        gh = FakeGh([], {}, fail=True)
        code, written, _ = self.run_main(gh, PLAY_OPEN_TESTING_COOLDOWN_HOURS="0")
        self.assertEqual(code, 0)
        self.assertIn("due=true\n", written)
        self.assertEqual(gh.calls, [])

    def test_an_unreadable_history_fails_rather_than_guessing(self):
        # Guessing "due" could reset a running review; guessing "not due" could
        # stop open testing indefinitely without anyone noticing. Fail instead.
        code, written, stdout = self.run_main(FakeGh([], {}, fail=True))
        self.assertNotEqual(code, 0)
        self.assertNotIn("due=", written)
        self.assertIn("::error", stdout)

    def test_a_bad_hours_value_fails(self):
        code, written, stdout = self.run_main(FakeGh([], {}), PLAY_OPEN_TESTING_COOLDOWN_HOURS="soon")
        self.assertNotEqual(code, 0)
        self.assertNotIn("due=", written)
        self.assertIn("PLAY_OPEN_TESTING_COOLDOWN_HOURS", stdout)


class GhCliTest(unittest.TestCase):
    def setUp(self):
        original = subprocess.run
        self.addCleanup(setattr, subprocess, "run", original)

    def test_runs_gh_and_returns_its_stdout(self):
        seen = {}

        def fake_run(cmd, **kwargs):
            seen.update(cmd=cmd, **kwargs)
            return subprocess.CompletedProcess(cmd, 0, stdout="[]", stderr="")

        subprocess.run = fake_run
        self.assertEqual(cooldown.gh_cli(["api", "x"]), "[]")
        self.assertEqual(seen["cmd"], ["gh", "api", "x"])
        self.assertTrue(seen["check"])

    def test_a_failing_gh_raises(self):
        def fake_run(cmd, **kwargs):
            raise subprocess.CalledProcessError(1, cmd, stderr="HTTP 403")

        subprocess.run = fake_run
        with self.assertRaises(subprocess.CalledProcessError):
            cooldown.gh_cli(["api", "x"])


class WorkflowContractTest(unittest.TestCase):
    """The names this script searches for must exist in beta.yml."""

    def setUp(self):
        with open(BETA_WORKFLOW) as handle:
            self.workflow = handle.read()

    def test_the_play_job_name_matches(self):
        self.assertIn(f"name: {cooldown.PLAY_JOB}\n", self.workflow)

    def test_the_promotion_step_name_matches(self):
        self.assertIn(f"- name: {cooldown.PROMOTE_STEP}\n", self.workflow)

    def test_the_play_job_can_read_actions(self):
        play_job = self.workflow.split("  upload-play:\n", 1)[1].split("\n  alert:", 1)[0]
        self.assertIn("actions: read", play_job)
        self.assertIn("scripts/release/play_beta_cooldown.py", play_job)


if __name__ == "__main__":
    unittest.main()
