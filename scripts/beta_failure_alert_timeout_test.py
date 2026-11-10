#!/usr/bin/env python3
"""Unit tests for how beta_failure_alert.py treats cancelled and timed-out jobs.

GitHub reports a job that hit its timeout-minutes as `cancelled`, to needs and
to the jobs API alike, exactly like one a newer run preempted (Beta run
42740909797, whose macOS build timed out at 45 minutes, against run
42732478246, whose builds a newer run cancelled). Only the job's check-run
annotations tell them apart. The shared fakes live in beta_failure_alert_test.
"""

import importlib.util
import json
import os
import subprocess
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(_HERE, f"{name}.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


base = _load("beta_failure_alert_test")
alert = base.alert
needs = base.needs
FakeGh = base.FakeGh
CONTEXT = base.CONTEXT
_quiet = base._quiet
_value = base._value

# The build was cancelled, so every lane behind it was skipped.
BUILD_CANCELLED = needs(
    precheck="success",
    build="cancelled",
    publish_beta="skipped",
    upload_testflight_ios="skipped",
    upload_testflight_macos="skipped",
    upload_play="skipped",
)

MACOS_JOB_ID = 129582153394
IOS_JOB_ID = 129582153390

MACOS_CANCELLED = {
    "id": MACOS_JOB_ID,
    "name": "Build / Build macOS",
    "conclusion": "cancelled",
    "steps": [
        {"name": "Install dependencies", "conclusion": "success"},
        {"name": "Build Mac App Store package", "conclusion": "cancelled"},
        {"name": "Upload Mac App Store pkg artifact", "conclusion": "skipped"},
    ],
}

CANCELLED_RUN_JOBS = {
    "jobs": [
        {"id": 1, "name": "Compute version and gate", "conclusion": "success", "steps": []},
        {"id": 2, "name": "Build / Build Android", "conclusion": "success", "steps": []},
        MACOS_CANCELLED,
        {"id": 3, "name": "Upload macOS beta to TestFlight", "conclusion": "skipped", "steps": []},
        {"id": 4, "name": "Alert on failure", "conclusion": None, "steps": []},
    ]
}

WINDOWS_FAILED = {
    "id": 5,
    "name": "Build / Build Windows",
    "conclusion": "failure",
    "steps": [{"name": "Build Windows release", "conclusion": "failure"}],
}

IOS_CANCELLED = {
    "id": IOS_JOB_ID,
    "name": "Build / Build iOS",
    "conclusion": "cancelled",
    "steps": [{"name": "Build iOS App Store package", "conclusion": "cancelled"}],
}


def annotation(message):
    return {"annotation_level": "failure", "message": message}


# The check-run annotations of each kind of cancellation, as the API returns
# them (one page, slurped).
CANCELED = annotation("The operation was canceled.")
TIMEOUT_ANNOTATIONS = [
    [annotation("The job has exceeded the maximum execution time of 45m0s"), CANCELED]
]
PREEMPTED_ANNOTATIONS = [
    [
        annotation("Canceling since a higher priority waiting request for beta-build exists"),
        CANCELED,
    ]
]


def annotations_call(job_id):
    """The gh args that read one job's check-run annotations."""
    return (
        "api", "--paginate", "--slurp",
        f"repos/submersion-app/submersion/check-runs/{job_id}/annotations",
    )


def run_jobs(*jobs):
    """The slurped jobs listing for a run with these jobs."""
    return json.dumps([{"jobs": list(jobs)}])


def cancelled_gh(annotations, **kwargs):
    """A FakeGh for a run whose macOS build was cancelled, for whatever reason."""
    responses = {
        ("api",): json.dumps([CANCELLED_RUN_JOBS]),
        annotations_call(MACOS_JOB_ID): annotations,
    }
    responses.update(kwargs.pop("responses", {}))
    return FakeGh(responses=responses, **kwargs)


def http_error():
    return subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 403")


class DecideCancelledTest(unittest.TestCase):
    def test_a_cancelled_job_is_left_for_the_timeout_check(self):
        # needs cannot tell a timeout from a preemption; run() reads the jobs.
        cancelled = dict(base.ALL_GREEN, **needs(upload_testflight_macos="cancelled"))
        self.assertEqual(
            alert.decide(cancelled), ("cancelled", ["upload-testflight-macos"])
        )

    def test_a_cancelled_build_is_left_for_the_timeout_check(self):
        self.assertEqual(alert.decide(BUILD_CANCELLED), ("cancelled", ["build"]))

    def test_a_failure_wins_over_a_cancellation(self):
        both = dict(BUILD_CANCELLED, **needs(publish_beta="failure"))
        self.assertEqual(alert.decide(both), ("alert", ["publish-beta"]))


class CancelReasonTest(unittest.TestCase):
    def test_reads_each_kind_of_cancellation(self):
        self.assertEqual(alert.cancel_reason(TIMEOUT_ANNOTATIONS[0]), "timeout")
        self.assertEqual(alert.cancel_reason(PREEMPTED_ANNOTATIONS[0]), "benign")
        by_hand = [annotation("The run was canceled by @maintainer."), CANCELED]
        self.assertEqual(alert.cancel_reason(by_hand), "benign")
        self.assertEqual(alert.cancel_reason([CANCELED]), "unknown")
        self.assertEqual(alert.cancel_reason([]), "unknown")


class TimedOutStepsTest(unittest.TestCase):
    def test_a_job_that_hit_its_timeout_is_listed_at_the_step_it_was_cut_off_in(self):
        self.assertEqual(
            alert.failed_steps(
                CANCELLED_RUN_JOBS["jobs"], timed_out_ids=frozenset({MACOS_JOB_ID})
            ),
            [("Build / Build macOS (timed out)", ["Build Mac App Store package"])],
        )

    def test_a_cancelled_job_that_did_not_time_out_is_not_listed(self):
        self.assertEqual(alert.failed_steps(CANCELLED_RUN_JOBS["jobs"]), [])


class TimeoutTest(unittest.TestCase):
    """A timeout is `cancelled`, so only the job annotations reveal it."""

    def test_a_build_that_hit_its_timeout_raises_the_alert(self):
        gh = cancelled_gh(json.dumps(TIMEOUT_ANNOTATIONS))
        code, _ = _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        self.assertEqual(code, 0)
        (create,) = gh.commands("issue", "create")
        body = _value(create, "--body")
        self.assertIn("`build`", body)
        self.assertIn("Build / Build macOS (timed out)", body)
        self.assertIn("Build Mac App Store package", body)
        self.assertIn(base.failed_in(120), body)
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(_value(edit, "--add-assignee"), "maintainer")

    def test_a_build_a_newer_run_preempted_touches_no_issue(self):
        gh = cancelled_gh(json.dumps(PREEMPTED_ANNOTATIONS), open_issues=[base.OPEN_ALERT])
        code, out = _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(gh.commands("issue"), [])
        self.assertIn("nothing to do", out)
        self.assertNotIn("::warning::", out)

    def test_a_job_the_api_reports_as_timed_out_raises_the_alert(self):
        # The documented `timed_out` conclusion needs no annotation lookup.
        timed_out_job = dict(MACOS_CANCELLED, conclusion="timed_out")
        gh = FakeGh(responses={("api",): run_jobs(timed_out_job)})
        _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("Build / Build macOS (timed out)", body)
        self.assertIn("Build Mac App Store package", body)
        self.assertEqual(
            [c for c in gh.commands("api") if c[-1].endswith("/annotations")], []
        )

    def test_reads_the_annotations_of_cancelled_jobs_only(self):
        gh = cancelled_gh(json.dumps(PREEMPTED_ANNOTATIONS))
        _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        reads = [c[-1] for c in gh.commands("api") if c[-1].endswith("/annotations")]
        self.assertEqual(reads, [annotations_call(MACOS_JOB_ID)[-1]])

    def test_finds_a_timeout_on_a_later_annotation_page(self):
        pages = [[CANCELED], [annotation("The job has exceeded the maximum execution time of 45m0s")]]
        gh = cancelled_gh(json.dumps(pages))
        _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        self.assertEqual(len(gh.commands("issue", "create")), 1)

    def test_an_unrecognised_cancellation_is_warned_about_not_alerted(self):
        # A reworded timeout message must show somewhere rather than pass
        # silently, but an unknown reason is not proof of a failure.
        gh = cancelled_gh(json.dumps([[CANCELED]]))
        code, out = _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(gh.commands("issue"), [])
        self.assertIn("::warning::Build / Build macOS was cancelled for a reason", out)

    def test_an_unreadable_run_fails_the_job_rather_than_guess(self):
        # Silence is how four timed-out betas went unnoticed; a red alert job
        # at least shows in the Actions list.
        gh = cancelled_gh(json.dumps(TIMEOUT_ANNOTATIONS), responses={("api",): http_error()})
        with self.assertRaises(subprocess.CalledProcessError):
            _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)
        self.assertEqual(gh.commands("issue"), [])

    def test_unreadable_annotations_fail_the_job_rather_than_guess(self):
        gh = cancelled_gh(http_error())
        with self.assertRaises(subprocess.CalledProcessError):
            _quiet(alert.run, BUILD_CANCELLED, CONTEXT, gh)


class FailureReportTimeoutTest(unittest.TestCase):
    """On a failed run the alert goes out regardless; timeouts add detail."""

    def test_a_failure_report_also_names_a_job_that_timed_out(self):
        # Windows failed and macOS timed out in the same build: the report
        # must name both, though only the failure decided to alert.
        gh = cancelled_gh(
            json.dumps(TIMEOUT_ANNOTATIONS),
            responses={("api",): run_jobs(*CANCELLED_RUN_JOBS["jobs"], WINDOWS_FAILED)},
        )
        _quiet(alert.run, base.BUILD_RED, CONTEXT, gh)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("Build / Build macOS (timed out)", body)
        self.assertIn("Build Windows release", body)

    def test_unreadable_annotations_still_deliver_a_failure_alert(self):
        gh = cancelled_gh(http_error())
        code, out = _quiet(alert.run, base.BUILD_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(len(gh.commands("issue", "create")), 1)
        self.assertIn("::warning::", out)

    def test_one_unreadable_annotation_keeps_the_other_timeouts(self):
        # iOS's annotations fail to load; macOS's timeout must still be named.
        gh = cancelled_gh(
            json.dumps(TIMEOUT_ANNOTATIONS),
            responses={
                ("api",): run_jobs(IOS_CANCELLED, MACOS_CANCELLED, WINDOWS_FAILED),
                annotations_call(IOS_JOB_ID): http_error(),
            },
        )
        code, out = _quiet(alert.run, base.BUILD_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("Build / Build macOS (timed out)", body)
        self.assertIn("::warning::could not read the annotations of Build / Build iOS", out)

    def test_a_cancelled_job_without_an_id_does_not_stop_the_alert(self):
        no_id = {k: v for k, v in MACOS_CANCELLED.items() if k != "id"}
        gh = FakeGh(responses={("api",): run_jobs(no_id, WINDOWS_FAILED)})
        code, _ = _quiet(alert.run, base.BUILD_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("Build Windows release", body)


if __name__ == "__main__":
    unittest.main()
