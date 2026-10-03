#!/usr/bin/env python3
"""Unit tests for beta_failure_alert.py."""

import contextlib
import importlib.util
import io
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


alert = _load("beta_failure_alert")
gate = _load("check_ci_success_gate")

BETA_WORKFLOW = os.path.join(_HERE, "..", ".github", "workflows", "beta.yml")


def needs(**results):
    """Build the `toJSON(needs)` shape: {job: {result, outputs}}."""
    return {job.replace("_", "-"): {"result": r, "outputs": {}} for job, r in results.items()}


ALL_GREEN = needs(
    precheck="success",
    build="success",
    publish_beta="success",
    upload_testflight_ios="success",
    upload_testflight_macos="success",
    upload_play="success",
)

PLAY_RED = dict(ALL_GREEN, **needs(upload_play="failure"))

# A failed build skips every lane downstream of it. The lanes report
# `skipped`, never `failure`, which is why the alert job needs the build too.
BUILD_RED = needs(
    precheck="success",
    build="failure",
    publish_beta="skipped",
    upload_testflight_ios="skipped",
    upload_testflight_macos="skipped",
    upload_play="skipped",
)

# Nothing shippable changed since the last beta: precheck succeeds and gates
# everything else off. Not a failure, and not a publish either.
NOTHING_TO_SHIP = needs(
    precheck="success",
    build="skipped",
    publish_beta="skipped",
    upload_testflight_ios="skipped",
    upload_testflight_macos="skipped",
    upload_play="skipped",
)

RUN_JOBS = {
    "jobs": [
        {
            "name": "Compute version and gate",
            "conclusion": "success",
            "steps": [{"name": "Compute beta version", "conclusion": "success"}],
        },
        {
            "name": "Upload Android beta to Play open testing",
            "conclusion": "failure",
            "steps": [
                {"name": "Checkout repository", "conclusion": "success"},
                {"name": "Upload to Play open testing", "conclusion": "failure"},
                {"name": "Copy the beta to Play closed testing", "conclusion": "skipped"},
            ],
        },
        {"name": "Alert on failure", "conclusion": None, "steps": []},
    ]
}

CONTEXT = {
    "repo": "submersion-app/submersion",
    "run_id": "36460341104",
    "run_attempt": "1",
    "run_number": "120",
    "run_url": "https://github.com/submersion-app/submersion/actions/runs/36460341104",
    "tag": "v1.8.1.8510",
    "sha": "0123456789abcdef0123456789abcdef01234567",
    "assignee": "maintainer",
}


class FakeGh:
    """Records every gh invocation and answers from a scripted table.

    `responses` maps a command prefix (tuple of leading args) to either the
    stdout string or an exception instance to raise. A list answers each call
    with its next entry and repeats the last one, for a listing that changes
    between two reads.
    """

    def __init__(self, responses=None, open_issues=()):
        self.calls = []
        self.responses = dict(responses or {})
        self.responses.setdefault(("issue", "list"), json.dumps(list(open_issues)))
        self.responses.setdefault(("api",), json.dumps([RUN_JOBS]))
        self.responses.setdefault(("issue", "view"), issue_view("OPEN"))
        self.responses.setdefault(
            ("issue", "create"),
            "https://github.com/submersion-app/submersion/issues/2700\n",
        )

    def __call__(self, args):
        self.calls.append(list(args))
        for prefix in sorted(self.responses, key=len, reverse=True):
            if tuple(args[: len(prefix)]) == prefix:
                answer = self.responses[prefix]
                if isinstance(answer, list):
                    answer = answer.pop(0) if len(answer) > 1 else answer[0]
                if isinstance(answer, Exception):
                    raise answer
                return answer
        return ""

    def commands(self, *prefix):
        return [c for c in self.calls if tuple(c[: len(prefix)]) == prefix]


def issue_view(state, body="", comments=()):
    """The `gh issue view --json state,body,comments` shape."""
    return json.dumps(
        {"state": state, "body": body, "comments": [{"body": c} for c in comments]}
    )


def failed_in(run_number):
    return alert.FAILED_RUN.format(run_number)


def resolved_in(run_number):
    return alert.RESOLVED_RUN.format(run_number)


def _value(cmd, flag):
    return cmd[cmd.index(flag) + 1]


def _quiet(fn, *args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()) as out:
        result = fn(*args, **kwargs)
    return result, out.getvalue()


OPEN_ALERT = {"number": 2650, "body": f"{alert.MARKER}\nBeta is failing."}
OUR_ALERT = {"number": 2700, "body": f"{alert.MARKER}\nBeta is failing."}
NEWER_ALERT = {"number": 2710, "body": f"{alert.MARKER}\nBeta is failing."}
UNRELATED = {"number": 2611, "body": "CI: a green pre-push hook can still redden main"}


class DecideTest(unittest.TestCase):
    def test_a_failed_lane_raises_the_alert(self):
        self.assertEqual(alert.decide(PLAY_RED), ("alert", ["upload-play"]))

    def test_a_failed_build_raises_the_alert_though_every_lane_is_skipped(self):
        self.assertEqual(alert.decide(BUILD_RED), ("alert", ["build"]))

    def test_failed_jobs_are_listed_in_order(self):
        both = dict(PLAY_RED, **needs(publish_beta="failure"))
        self.assertEqual(alert.decide(both), ("alert", ["publish-beta", "upload-play"]))

    def test_a_run_that_published_everywhere_resolves(self):
        self.assertEqual(alert.decide(ALL_GREEN), ("resolve", []))

    def test_a_gated_off_run_does_nothing(self):
        self.assertEqual(alert.decide(NOTHING_TO_SHIP), ("none", []))

    def test_a_cancelled_lane_neither_alerts_nor_resolves(self):
        cancelled = dict(ALL_GREEN, **needs(upload_testflight_macos="cancelled"))
        self.assertEqual(alert.decide(cancelled), ("none", []))

    def test_no_needs_does_nothing(self):
        self.assertEqual(alert.decide({}), ("none", []))


class FailedStepsTest(unittest.TestCase):
    def test_lists_each_failed_job_with_its_failed_steps(self):
        self.assertEqual(
            alert.failed_steps(RUN_JOBS["jobs"]),
            [("Upload Android beta to Play open testing", ["Upload to Play open testing"])],
        )

    def test_a_timed_out_job_counts_as_failed(self):
        # needs reports a timeout as `failure`; the jobs API does not.
        jobs = [
            {
                "name": "Upload macOS beta to TestFlight",
                "conclusion": "timed_out",
                "steps": [{"name": "Distribute to Public Beta group", "conclusion": "cancelled"}],
            },
            {"name": "Build / Build Linux", "conclusion": "startup_failure", "steps": []},
        ]
        self.assertEqual(
            [name for name, _ in alert.failed_steps(jobs)],
            ["Upload macOS beta to TestFlight", "Build / Build Linux"],
        )

    def test_a_job_that_failed_outside_any_step_is_still_listed(self):
        jobs = [{"name": "Build / Build iOS", "conclusion": "failure", "steps": []}]
        self.assertEqual(alert.failed_steps(jobs), [("Build / Build iOS", [])])


class AlertTest(unittest.TestCase):
    def test_opens_an_issue_when_none_is_open(self):
        gh = FakeGh(open_issues=[UNRELATED])
        code, _ = _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        (create,) = gh.commands("issue", "create")
        body = _value(create, "--body")
        self.assertIn(alert.MARKER, body)
        self.assertIn("@maintainer", body)
        self.assertIn("Upload to Play open testing", body)
        self.assertIn(CONTEXT["run_url"], body)
        self.assertIn(CONTEXT["tag"], body)
        self.assertEqual(_value(create, "--label"), alert.LABEL)
        self.assertEqual(_value(create, "--repo"), CONTEXT["repo"])
        self.assertEqual(gh.commands("issue", "comment"), [])

    def test_assigns_the_new_issue(self):
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(edit[2], "2700")
        self.assertEqual(_value(edit, "--add-assignee"), "maintainer")

    def test_comments_on_the_open_alert_instead_of_opening_another(self):
        gh = FakeGh(open_issues=[UNRELATED, OPEN_ALERT])
        code, _ = _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(gh.commands("issue", "create"), [])
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], "2650")
        body = _value(comment, "--body")
        self.assertIn("@maintainer", body)
        self.assertIn("Upload to Play open testing", body)
        self.assertNotIn(alert.MARKER, body)

    def test_comments_on_the_oldest_alert_when_several_are_open(self):
        gh = FakeGh(open_issues=[NEWER_ALERT, OPEN_ALERT])
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], "2650")

    def test_lists_every_failed_job_even_when_the_api_misses_one(self):
        # A timed-out build is `failure` in needs but may be missing from the
        # API's failed jobs. Step details for Play must not hide it.
        both = dict(PLAY_RED, **needs(build="failure"))
        gh = FakeGh()
        _quiet(alert.run, both, CONTEXT, gh)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("`build`", body)
        self.assertIn("`upload-play`", body)
        self.assertIn("Upload to Play open testing", body)

    def test_a_duplicate_opened_by_a_concurrent_run_folds_into_the_oldest(self):
        # Two failing runs both found no alert and both opened one. The newer
        # issue hands its report to the older and closes itself.
        gh = FakeGh(
            responses={
                ("issue", "list"): [
                    json.dumps([UNRELATED]),
                    json.dumps([UNRELATED, OUR_ALERT, OPEN_ALERT]),
                ]
            }
        )
        code, _ = _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], "2650")
        self.assertIn("Upload to Play open testing", _value(comment, "--body"))
        (close,) = gh.commands("issue", "close")
        self.assertEqual(close[2], "2700")
        self.assertIn("#2650", _value(close, "--comment"))
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(edit[2], "2650")

    def test_the_oldest_alert_survives_a_newer_duplicate(self):
        # The run that opened the newer issue closes it; this one keeps its own.
        gh = FakeGh(
            responses={
                ("issue", "list"): [
                    json.dumps([]),
                    json.dumps([NEWER_ALERT, OUR_ALERT]),
                ]
            }
        )
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertEqual(gh.commands("issue", "comment"), [])
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(edit[2], "2700")

    def test_every_report_records_its_run(self):
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertIn(failed_in(120), _value(gh.commands("issue", "create")[0], "--body"))
        gh = FakeGh(open_issues=[OPEN_ALERT])
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertIn(failed_in(120), _value(gh.commands("issue", "comment")[0], "--body"))

    def test_reopens_an_alert_an_older_green_run_closed_meanwhile(self):
        # The comment landed on an issue a concurrent, older green run closed
        # between this run's lookup and its comment. The failure must win.
        gh = FakeGh(
            open_issues=[OPEN_ALERT],
            responses={("issue", "view"): issue_view("CLOSED", comments=[resolved_in(119)])},
        )
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        (reopen,) = gh.commands("issue", "reopen")
        self.assertEqual(reopen[2], "2650")

    def test_leaves_closed_an_alert_a_newer_run_resolved(self):
        # A newer run published on every lane: this older failure is stale.
        gh = FakeGh(
            open_issues=[OPEN_ALERT],
            responses={("issue", "view"): issue_view("CLOSED", comments=[resolved_in(121)])},
        )
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(gh.commands("issue", "reopen"), [])

    def test_an_alert_that_stayed_open_is_not_reopened(self):
        gh = FakeGh(open_issues=[OPEN_ALERT])
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(gh.commands("issue", "reopen"), [])

    def test_reads_only_open_ci_issues(self):
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        listing = gh.commands("issue", "list")[0]
        self.assertEqual(_value(listing, "--state"), "open")
        self.assertEqual(_value(listing, "--label"), alert.LABEL)

    def test_reads_the_jobs_of_this_attempt_only(self):
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        (api,) = gh.commands("api")
        self.assertIn(
            "repos/submersion-app/submersion/actions/runs/36460341104/attempts/1/jobs",
            api,
        )

    def test_a_failed_assignment_still_delivers_the_alert(self):
        error = subprocess.CalledProcessError(1, ["gh"], stderr="not a collaborator")
        gh = FakeGh(responses={("issue", "edit"): error})
        code, out = _quiet(alert.run, PLAY_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(len(gh.commands("issue", "create")), 1)
        self.assertIn("::warning::", out)

    def test_falls_back_to_job_ids_when_the_run_cannot_be_read(self):
        error = subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 403")
        gh = FakeGh(responses={("api",): error})
        code, out = _quiet(alert.run, BUILD_RED, CONTEXT, gh)
        self.assertEqual(code, 0)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("`build`", body)
        self.assertIn("::warning::", out)

    def test_a_failed_issue_write_fails_the_job(self):
        # The opposite of #2609: an alert that cannot be delivered must not
        # report success.
        error = subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 403")
        gh = FakeGh(responses={("issue", "create"): error})
        with self.assertRaises(subprocess.CalledProcessError):
            _quiet(alert.run, PLAY_RED, CONTEXT, gh)

    def test_a_missing_version_is_reported_as_such(self):
        precheck_red = needs(
            precheck="failure",
            build="skipped",
            publish_beta="skipped",
            upload_testflight_ios="skipped",
            upload_testflight_macos="skipped",
            upload_play="skipped",
        )
        gh = FakeGh()
        _quiet(alert.run, precheck_red, dict(CONTEXT, tag=""), gh)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("not computed", body)

    def test_an_empty_assignee_falls_back_to_the_default(self):
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, dict(CONTEXT, assignee=""), gh)
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(_value(edit, "--add-assignee"), alert.DEFAULT_ASSIGNEE)

    def test_an_assignee_written_with_an_at_sign_still_notifies(self):
        # "@name" is how GitHub users write a login; taken verbatim it becomes
        # an "@@name" mention and an assignment GitHub rejects.
        gh = FakeGh()
        _quiet(alert.run, PLAY_RED, dict(CONTEXT, assignee=" @maintainer "), gh)
        (edit,) = gh.commands("issue", "edit")
        self.assertEqual(_value(edit, "--add-assignee"), "maintainer")
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("@maintainer ", body)
        self.assertNotIn("@@", body)


class ResolveTest(unittest.TestCase):
    def test_closes_the_open_alert_once_every_lane_publishes(self):
        gh = FakeGh(open_issues=[OPEN_ALERT])
        code, _ = _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertEqual(code, 0)
        (close,) = gh.commands("issue", "close")
        self.assertEqual(close[2], "2650")
        self.assertIn(CONTEXT["tag"], _value(close, "--comment"))

    def test_records_the_resolving_run_in_the_close_comment(self):
        gh = FakeGh(open_issues=[OPEN_ALERT])
        _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertIn(resolved_in(120), _value(gh.commands("issue", "close")[0], "--comment"))

    def test_an_older_green_run_leaves_a_newer_failure_open(self):
        # Run 121's build failed fast while run 120 was still distributing.
        gh = FakeGh(
            open_issues=[OPEN_ALERT],
            responses={
                ("issue", "view"): issue_view(
                    "OPEN", body=failed_in(118), comments=[failed_in(121)]
                )
            },
        )
        code, out = _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertEqual(code, 0)
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertIn("121", out)

    def test_a_rerun_of_the_failed_run_resolves(self):
        # Re-running the failed jobs keeps the run number.
        gh = FakeGh(
            open_issues=[OPEN_ALERT],
            responses={("issue", "view"): issue_view("OPEN", body=failed_in(120))},
        )
        _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertEqual(len(gh.commands("issue", "close")), 1)

    def test_reopens_when_a_newer_failure_lands_while_closing(self):
        gh = FakeGh(
            open_issues=[OPEN_ALERT],
            responses={
                ("issue", "view"): [
                    issue_view("OPEN", body=failed_in(119)),
                    issue_view(
                        "CLOSED",
                        body=failed_in(119),
                        comments=[resolved_in(120), failed_in(121)],
                    ),
                ]
            },
        )
        _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertEqual(len(gh.commands("issue", "close")), 1)
        (reopen,) = gh.commands("issue", "reopen")
        self.assertEqual(reopen[2], "2650")

    def test_does_nothing_when_no_alert_is_open(self):
        gh = FakeGh(open_issues=[UNRELATED])
        _quiet(alert.run, ALL_GREEN, CONTEXT, gh)
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertEqual(gh.commands("issue", "create"), [])

    def test_a_gated_off_run_touches_nothing(self):
        gh = FakeGh(open_issues=[OPEN_ALERT])
        _quiet(alert.run, NOTHING_TO_SHIP, CONTEXT, gh)
        self.assertEqual(gh.calls, [])


class GhCliTest(unittest.TestCase):
    """The real runner: its raising on failure is what fails the job."""

    def setUp(self):
        self.real_run = subprocess.run
        self.addCleanup(setattr, subprocess, "run", self.real_run)

    def test_runs_gh_and_returns_its_stdout(self):
        seen = {}

        def fake_run(cmd, **kwargs):
            seen.update(cmd=cmd, **kwargs)
            return subprocess.CompletedProcess(cmd, 0, stdout="out\n", stderr="")

        subprocess.run = fake_run
        self.assertEqual(alert.gh_cli(["issue", "list"]), "out\n")
        self.assertEqual(seen["cmd"], ["gh", "issue", "list"])
        self.assertTrue(seen["check"])

    def test_a_failing_gh_raises(self):
        def fake_run(cmd, **kwargs):
            raise subprocess.CalledProcessError(1, cmd, stderr="HTTP 403")

        subprocess.run = fake_run
        with self.assertRaises(subprocess.CalledProcessError):
            alert.gh_cli(["issue", "create"])


class MainTest(unittest.TestCase):
    def test_reads_its_inputs_from_the_environment(self):
        env = {
            "NEEDS_JSON": json.dumps(PLAY_RED),
            "GITHUB_REPOSITORY": CONTEXT["repo"],
            "GITHUB_RUN_ID": CONTEXT["run_id"],
            "GITHUB_RUN_ATTEMPT": CONTEXT["run_attempt"],
            "GITHUB_RUN_NUMBER": CONTEXT["run_number"],
            "GITHUB_SERVER_URL": "https://github.com",
            "BETA_TAG": CONTEXT["tag"],
            "BETA_SHA": CONTEXT["sha"],
            "BETA_ALERT_ASSIGNEE": "maintainer",
        }
        gh = FakeGh()
        code, _ = _quiet(alert.main, env, gh)
        self.assertEqual(code, 0)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn(CONTEXT["run_url"], body)
        self.assertIn(failed_in(120), body)


class WorkflowWiringTest(unittest.TestCase):
    """The alert only sees jobs named in its needs, so every job must be."""

    @classmethod
    def setUpClass(cls):
        with open(BETA_WORKFLOW, encoding="utf-8") as fh:
            cls.text = fh.read()

    def test_the_alert_job_needs_every_other_job(self):
        jobs = gate.job_ids(self.text)
        self.assertIn(alert.ALERT_JOB, jobs)
        listed = gate.gate_needs(self.text, alert.ALERT_JOB)
        self.assertIsNotNone(listed, f"{alert.ALERT_JOB} declares no needs")
        missing = [j for j in jobs if j != alert.ALERT_JOB and j not in listed]
        self.assertEqual(
            missing,
            [],
            f"{alert.ALERT_JOB}.needs omits {missing}: a failure there would "
            "never raise the beta alert",
        )

    def _alert_condition(self):
        body = dict(gate._job_lines(self.text))[alert.ALERT_JOB]
        start = next(i for i, line in enumerate(body) if line.startswith("    if:"))
        block = [body[start]]
        for line in body[start + 1:]:
            if line.strip() and len(line) - len(line.lstrip()) <= 4:
                break
            block.append(line)
        return " ".join(" ".join(block).split())

    def test_the_alert_runs_on_any_failure_and_on_a_full_publish_only(self):
        # always() so a failed need does not skip it; the failure clause so
        # any failed job alerts; the no-skipped/no-cancelled clause so it can
        # resolve, while gated-off runs stay skipped; main only.
        condition = self._alert_condition()
        for clause in (
            "always()",
            "github.ref == 'refs/heads/main'",
            "contains(needs.*.result, 'failure') ||",
            "!contains(needs.*.result, 'skipped') &&",
            "!contains(needs.*.result, 'cancelled')",
        ):
            self.assertIn(clause, condition)

    def test_the_alert_job_has_no_concurrency_group(self):
        # A concurrency group keeps one pending job and cancels the one it
        # replaces whatever cancel-in-progress says, so a green run queued
        # behind an alert could discard a pending failure. Duplicates from
        # unserialized runs are folded together by the script instead.
        body = dict(gate._job_lines(self.text))[alert.ALERT_JOB]
        self.assertFalse(any(line.strip().startswith("concurrency:") for line in body))

    def test_the_alert_job_runs_this_script(self):
        body = dict(gate._job_lines(self.text))[alert.ALERT_JOB]
        self.assertTrue(
            any("beta_failure_alert.py" in cmd for cmd in gate._run_commands(body))
        )


if __name__ == "__main__":
    unittest.main()
