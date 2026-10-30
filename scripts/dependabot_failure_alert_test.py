#!/usr/bin/env python3
"""Unit tests for dependabot_failure_alert.py."""

import contextlib
import datetime
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


alert = _load("dependabot_failure_alert")

WORKFLOW = os.path.join(_HERE, "..", ".github", "workflows", "dependabot-alert.yml")
REPO = "submersion-app/submersion"
NOW = datetime.datetime(2026, 10, 17, 12, 0, tzinfo=datetime.timezone.utc)
CONTEXT = {"repo": REPO, "assignee": "maintainer"}


def run_(run_id, title, conclusion, created):
    return {
        "id": run_id,
        "display_title": title,
        "conclusion": conclusion,
        "created_at": created,
        "html_url": f"https://github.com/{REPO}/actions/runs/{run_id}",
    }


BUNDLER_RED = run_(
    36851179684, "bundler in /ios, /macos - Update #1602463943", "failure",
    "2026-10-01T10:46:08Z",
)
BUNDLER_GREEN = run_(
    37000000001, "bundler in /ios, /macos - Update #1640000000", "success",
    "2026-10-16T10:46:08Z",
)
PUB_GREEN = run_(36900000000, "pub in /. - Update #1624328242", "success", "2026-10-13T06:39:47Z")
EXCON_RED = run_(
    36500000000, "bundler in /macos for excon - Update #1593467194", "failure",
    "2026-09-27T17:57:45Z",
)
# Older than the lookback window: a stream that never ran again.
STALE_RED = run_(
    35000000000, "bundler in /ios for json - Update #1400000000", "failure",
    "2026-08-01T10:00:00Z",
)

WORKFLOWS = {
    "workflows": [
        {"id": 1, "path": ".github/workflows/ci.yaml"},
        {"id": 234706444, "path": "dynamic/dependabot/dependabot-updates"},
    ]
}


def runs_page(*runs):
    return json.dumps([{"workflow_runs": list(runs)}])


def _view(texts):
    return json.dumps(
        {"body": texts[0] if texts else "", "comments": [{"body": t} for t in texts[1:]]}
    )


class FakeGh:
    """Records every gh invocation and answers from a scripted table.

    `responses` maps a command prefix (tuple of leading args) to the stdout
    string or an exception instance to raise. The longest prefix wins.
    `issues` is the issue listing, open and closed alike; `issue_texts` is
    the body then comments every `issue view` returns, and `issue_views`
    overrides that per issue number.
    """

    def __init__(
        self, runs=(), issues=(), issue_texts=(), issue_views=None, responses=None
    ):
        self.calls = []
        self.responses = {
            ("api", "--paginate", "--slurp", f"repos/{REPO}/actions/workflows"):
                json.dumps([WORKFLOWS]),
            ("api", "--paginate", "--slurp", f"repos/{REPO}/actions/workflows/234706444/runs"):
                runs_page(*runs),
            ("issue", "list"): list(issues),
            ("issue", "view"): _view(issue_texts),
            ("issue", "create"): f"https://github.com/{REPO}/issues/2800\n",
        }
        for number, texts in (issue_views or {}).items():
            self.responses[("issue", "view", str(number))] = _view(texts)
        self.responses.update(responses or {})

    def __call__(self, args):
        self.calls.append(list(args))
        # An api path's query string is not part of what it matches on.
        bare = [a.split("?", 1)[0] if a.startswith("repos/") else a for a in args]
        for prefix in sorted(self.responses, key=len, reverse=True):
            if tuple(bare[: len(prefix)]) == prefix:
                answer = self.responses[prefix]
                if isinstance(answer, Exception):
                    raise answer
                if isinstance(answer, list):
                    # An issue listing answers with the issues in the state
                    # it asks for, and updated since the date its search
                    # names, as gh does.
                    state = args[args.index("--state") + 1].upper()
                    search = args[args.index("--search") + 1] if "--search" in args else ""
                    since = search.removeprefix("updated:>=")
                    answer = json.dumps(
                        [
                            i for i in answer
                            if (state == "ALL" or i["state"] == state)
                            and i["updatedAt"][:10] >= since
                        ]
                    )
                return answer
        return ""

    def commands(self, *prefix):
        return [c for c in self.calls if tuple(c[: len(prefix)]) == prefix]


def _value(cmd, flag):
    return cmd[cmd.index(flag) + 1]


def _quiet(fn, *args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()) as out:
        result = fn(*args, **kwargs)
    return result, out.getvalue()


OPEN_ALERT = {
    "number": 2790, "state": "OPEN", "updatedAt": "2026-10-16T13:17:00Z",
    "body": f"{alert.MARKER}\nDependabot is failing.",
}
UNRELATED = {
    "number": 2611, "state": "OPEN", "updatedAt": "2026-10-16T09:00:00Z",
    "body": "CI: a green pre-push hook can still redden main",
}
# An earlier alert, closed (by hand or by a fix PR's "Closes") while the run
# it reported was still inside the lookback (#3720).
CLOSED_ALERT = {
    "number": 2780, "state": "CLOSED", "updatedAt": "2026-10-14T14:54:00Z",
    "body": f"{alert.MARKER}\n{alert.FAILED_RUN.format(BUNDLER_RED['id'])}",
}
# A closed alert last touched before the lookback cannot hold a record of any
# run inside it, so it is never read.
OLD_CLOSED_ALERT = {
    "number": 2600, "state": "CLOSED", "updatedAt": "2026-08-01T13:17:00Z",
    "body": f"{alert.MARKER}\nDependabot is failing.",
}


class StreamKeyTest(unittest.TestCase):
    def test_strips_the_update_number(self):
        self.assertEqual(alert.stream_key(BUNDLER_RED["display_title"]), "bundler in /ios, /macos")

    def test_keeps_a_security_update_dependency(self):
        self.assertEqual(
            alert.stream_key(EXCON_RED["display_title"]), "bundler in /macos for excon"
        )

    def test_a_title_without_a_number_is_its_own_key(self):
        self.assertEqual(alert.stream_key("Dependabot"), "Dependabot")


class FailingStreamsTest(unittest.TestCase):
    def test_a_stream_whose_latest_run_failed_is_failing(self):
        self.assertEqual(alert.failing_streams([BUNDLER_RED, PUB_GREEN], NOW), [BUNDLER_RED])

    def test_a_newer_green_run_clears_the_stream(self):
        self.assertEqual(alert.failing_streams([BUNDLER_GREEN, BUNDLER_RED], NOW), [])
        # Order in the listing does not matter, only creation time.
        self.assertEqual(alert.failing_streams([BUNDLER_RED, BUNDLER_GREEN], NOW), [])

    def test_a_failure_after_a_green_run_is_failing(self):
        newer_red = dict(BUNDLER_RED, id=37100000000, created_at="2026-10-17T10:00:00Z")
        self.assertEqual(
            alert.failing_streams([BUNDLER_GREEN, newer_red], NOW), [newer_red]
        )

    def test_streams_are_sorted_by_key(self):
        self.assertEqual(
            alert.failing_streams([EXCON_RED, BUNDLER_RED], NOW), [BUNDLER_RED, EXCON_RED]
        )

    def test_a_timed_out_or_startup_failure_counts(self):
        for conclusion in ("timed_out", "startup_failure"):
            run = dict(BUNDLER_RED, conclusion=conclusion)
            self.assertEqual(alert.failing_streams([run], NOW), [run], conclusion)

    def test_a_cancelled_run_is_not_a_failure(self):
        self.assertEqual(alert.failing_streams([dict(BUNDLER_RED, conclusion="cancelled")], NOW), [])

    def test_a_run_older_than_the_lookback_is_ignored(self):
        self.assertEqual(alert.failing_streams([STALE_RED], NOW), [])


class RunTest(unittest.TestCase):
    def test_a_failure_with_no_open_alert_opens_one(self):
        gh = FakeGh(runs=[BUNDLER_RED, PUB_GREEN], issues=[UNRELATED])
        code, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(code, 0)
        (create,) = gh.commands("issue", "create")
        body = _value(create, "--body")
        self.assertIn(alert.MARKER, body)
        self.assertIn(alert.FAILED_RUN.format(BUNDLER_RED["id"]), body)
        self.assertIn("@maintainer", body)
        self.assertIn("bundler in /ios, /macos", body)
        self.assertIn(BUNDLER_RED["html_url"], body)
        self.assertNotIn("pub in /.", body)
        self.assertEqual(_value(create, "--label"), alert.LABEL)
        (assign,) = gh.commands("issue", "edit")
        self.assertEqual(assign[2], "2800")
        self.assertEqual(_value(assign, "--add-assignee"), "maintainer")
        self.assertIn("Opened", out)

    def test_a_new_failure_comments_on_the_open_alert(self):
        gh = FakeGh(
            runs=[BUNDLER_RED, EXCON_RED],
            issues=[OPEN_ALERT],
            issue_texts=[OPEN_ALERT["body"] + "\n" + alert.FAILED_RUN.format(EXCON_RED["id"])],
        )
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "create"), [])
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], "2790")
        body = _value(comment, "--body")
        # Only the run not already reported is in the comment.
        self.assertIn(alert.FAILED_RUN.format(BUNDLER_RED["id"]), body)
        self.assertNotIn(alert.FAILED_RUN.format(EXCON_RED["id"]), body)
        self.assertIn("@maintainer", body)

    def test_an_already_reported_failure_is_not_repeated(self):
        # A daily check must not comment every day on the same red run.
        gh = FakeGh(
            runs=[BUNDLER_RED],
            issues=[OPEN_ALERT],
            issue_texts=[OPEN_ALERT["body"], alert.FAILED_RUN.format(BUNDLER_RED["id"])],
        )
        _, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "comment"), [])
        self.assertEqual(gh.commands("issue", "create"), [])
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertIn("already reported", out)

    def test_a_run_reported_on_a_closed_alert_does_not_reopen_it(self):
        # #3705 closed #3495 while its runs were still red in the lookback,
        # and the next daily check opened #3720 reporting the same runs.
        gh = FakeGh(
            runs=[BUNDLER_RED, PUB_GREEN],
            issues=[CLOSED_ALERT, UNRELATED],
            issue_views={CLOSED_ALERT["number"]: [CLOSED_ALERT["body"]]},
        )
        _, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "create"), [])
        self.assertEqual(gh.commands("issue", "comment"), [])
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertEqual(gh.commands("issue", "edit"), [])
        self.assertIn("already reported", out)

    def test_a_run_reported_in_a_closed_alerts_comment_counts(self):
        gh = FakeGh(
            runs=[EXCON_RED],
            issues=[CLOSED_ALERT],
            issue_views={
                CLOSED_ALERT["number"]: [
                    CLOSED_ALERT["body"], alert.FAILED_RUN.format(EXCON_RED["id"]),
                ],
            },
        )
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "create"), [])

    def test_a_new_failure_after_a_closed_alert_opens_one_with_only_it(self):
        gh = FakeGh(
            runs=[BUNDLER_RED, EXCON_RED],
            issues=[CLOSED_ALERT],
            issue_views={CLOSED_ALERT["number"]: [CLOSED_ALERT["body"]]},
        )
        _quiet(alert.run, CONTEXT, gh, NOW)
        (create,) = gh.commands("issue", "create")
        body = _value(create, "--body")
        self.assertIn(alert.FAILED_RUN.format(EXCON_RED["id"]), body)
        self.assertNotIn(alert.FAILED_RUN.format(BUNDLER_RED["id"]), body)

    def test_the_open_alert_skips_a_run_a_closed_alert_reported(self):
        gh = FakeGh(
            runs=[BUNDLER_RED, EXCON_RED],
            issues=[OPEN_ALERT, CLOSED_ALERT],
            issue_views={
                OPEN_ALERT["number"]: [OPEN_ALERT["body"]],
                CLOSED_ALERT["number"]: [CLOSED_ALERT["body"]],
            },
        )
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "create"), [])
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], str(OPEN_ALERT["number"]))
        body = _value(comment, "--body")
        self.assertIn(alert.FAILED_RUN.format(EXCON_RED["id"]), body)
        self.assertNotIn(alert.FAILED_RUN.format(BUNDLER_RED["id"]), body)

    def test_the_open_alert_is_the_oldest_open_one_not_a_closed_one(self):
        older_closed = dict(CLOSED_ALERT, number=2700)
        gh = FakeGh(runs=[EXCON_RED], issues=[OPEN_ALERT, older_closed])
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "create"), [])
        (comment,) = gh.commands("issue", "comment")
        self.assertEqual(comment[2], str(OPEN_ALERT["number"]))

    def test_open_and_recently_closed_alerts_are_listed_apart(self):
        # One listing of every state would let old closed ci issues push the
        # open alert past --limit, and a duplicate alert would open.
        gh = FakeGh(runs=[BUNDLER_RED])
        _quiet(alert.run, CONTEXT, gh, NOW)
        open_listing, closed_listing = gh.commands("issue", "list")
        self.assertEqual(_value(open_listing, "--state"), "open")
        self.assertNotIn("--search", open_listing)
        self.assertEqual(_value(closed_listing, "--state"), "closed")
        self.assertEqual(_value(closed_listing, "--search"), "updated:>=2026-09-12")

    def test_a_closed_alert_older_than_the_lookback_is_not_read(self):
        gh = FakeGh(runs=[BUNDLER_RED], issues=[OLD_CLOSED_ALERT])
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "view"), [])
        self.assertEqual(len(gh.commands("issue", "create")), 1)

    def test_an_unrelated_issue_is_never_read(self):
        gh = FakeGh(runs=[BUNDLER_RED], issues=[UNRELATED])
        _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "view"), [])

    def test_a_closed_alert_does_not_block_closing_the_open_one(self):
        gh = FakeGh(runs=[BUNDLER_GREEN, PUB_GREEN], issues=[CLOSED_ALERT, OPEN_ALERT])
        _quiet(alert.run, CONTEXT, gh, NOW)
        (close,) = gh.commands("issue", "close")
        self.assertEqual(close[2], str(OPEN_ALERT["number"]))

    def test_all_green_with_only_a_closed_alert_closes_nothing(self):
        gh = FakeGh(runs=[BUNDLER_GREEN, PUB_GREEN], issues=[CLOSED_ALERT])
        _, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertIn("no alert is open", out)

    def test_all_green_closes_the_open_alert(self):
        gh = FakeGh(runs=[BUNDLER_GREEN, BUNDLER_RED, PUB_GREEN], issues=[OPEN_ALERT])
        _quiet(alert.run, CONTEXT, gh, NOW)
        (close,) = gh.commands("issue", "close")
        self.assertEqual(close[2], "2790")
        self.assertIn("succeeded", _value(close, "--comment"))

    def test_all_green_with_no_alert_does_nothing(self):
        gh = FakeGh(runs=[BUNDLER_GREEN, PUB_GREEN], issues=[UNRELATED])
        _, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "close"), [])
        self.assertEqual(gh.commands("issue", "create"), [])
        self.assertIn("no alert is open", out)

    def test_the_runs_query_is_bounded_by_the_lookback(self):
        gh = FakeGh(runs=[PUB_GREEN])
        _quiet(alert.run, CONTEXT, gh, NOW)
        (listing,) = [c for c in gh.commands("api") if "/runs" in c[-1]]
        self.assertIn("status=completed", listing[-1])
        self.assertIn("created=%3E%3D2026-09-12", listing[-1])

    def test_no_runs_at_all_fails_rather_than_closing_the_alert(self):
        # Dependabot that stopped running is not "every stream green".
        gh = FakeGh(runs=[], issues=[OPEN_ALERT])
        with self.assertRaises(RuntimeError):
            _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "close"), [])

    def test_a_missing_dependabot_workflow_fails(self):
        gh = FakeGh(
            responses={
                ("api", "--paginate", "--slurp", f"repos/{REPO}/actions/workflows"):
                    json.dumps([{"workflows": []}]),
            }
        )
        with self.assertRaises(RuntimeError):
            _quiet(alert.run, CONTEXT, gh, NOW)

    def test_a_failed_listing_is_not_read_as_all_green(self):
        # A listing that cannot be read must fail the job, never close the alert.
        error = subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 502")
        gh = FakeGh(
            issues=[OPEN_ALERT],
            responses={
                ("api", "--paginate", "--slurp",
                 f"repos/{REPO}/actions/workflows/234706444/runs"): error,
            },
        )
        with self.assertRaises(subprocess.CalledProcessError):
            _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(gh.commands("issue", "close"), [])

    def test_a_failed_assignment_still_delivers_the_alert(self):
        error = subprocess.CalledProcessError(1, ["gh"], stderr="not a collaborator")
        gh = FakeGh(runs=[BUNDLER_RED], responses={("issue", "edit"): error})
        code, out = _quiet(alert.run, CONTEXT, gh, NOW)
        self.assertEqual(code, 0)
        self.assertEqual(len(gh.commands("issue", "create")), 1)
        self.assertIn("::warning::", out)

    def test_an_at_prefixed_assignee_is_normalized(self):
        gh = FakeGh(runs=[BUNDLER_RED])
        _quiet(alert.run, dict(CONTEXT, assignee="@maintainer"), gh, NOW)
        body = _value(gh.commands("issue", "create")[0], "--body")
        self.assertIn("@maintainer ", body)
        self.assertNotIn("@@", body)
        self.assertEqual(_value(gh.commands("issue", "edit")[0], "--add-assignee"), "maintainer")

    def test_an_empty_assignee_falls_back_to_the_default(self):
        gh = FakeGh(runs=[BUNDLER_RED])
        _quiet(alert.run, dict(CONTEXT, assignee=""), gh, NOW)
        self.assertEqual(
            _value(gh.commands("issue", "edit")[0], "--add-assignee"), alert.DEFAULT_ASSIGNEE
        )


class GhCliTest(unittest.TestCase):
    def test_runs_gh_and_returns_stdout(self):
        seen = {}

        def fake_run(cmd, **kwargs):
            seen["cmd"], seen["kwargs"] = cmd, kwargs
            return subprocess.CompletedProcess(cmd, 0, stdout="out\n", stderr="")

        original = alert.subprocess.run
        alert.subprocess.run = fake_run
        self.addCleanup(setattr, alert.subprocess, "run", original)
        self.assertEqual(alert.gh_cli(["issue", "list"]), "out\n")
        self.assertEqual(seen["cmd"], ["gh", "issue", "list"])
        # check=True is what turns a failed gh call into a failed job.
        self.assertTrue(seen["kwargs"]["check"])


class MainTest(unittest.TestCase):
    def test_reads_its_inputs_from_the_environment(self):
        gh = FakeGh(runs=[BUNDLER_RED])
        env = {"GITHUB_REPOSITORY": REPO, "DEPENDABOT_ALERT_ASSIGNEE": "someone"}
        code, _ = _quiet(alert.main, env, gh, NOW)
        self.assertEqual(code, 0)
        self.assertEqual(_value(gh.commands("issue", "edit")[0], "--add-assignee"), "someone")


class WorkflowTest(unittest.TestCase):
    def setUp(self):
        with open(WORKFLOW, encoding="utf-8") as fh:
            self.text = fh.read()

    def test_runs_on_a_schedule_and_on_demand(self):
        self.assertIn("schedule:", self.text)
        self.assertIn("cron:", self.text)
        self.assertIn("workflow_dispatch:", self.text)

    def test_can_write_issues_and_read_runs(self):
        self.assertIn("issues: write", self.text)
        self.assertIn("actions: read", self.text)

    def test_runs_this_script(self):
        self.assertIn("python3 scripts/dependabot_failure_alert.py", self.text)
        self.assertIn("DEPENDABOT_ALERT_ASSIGNEE", self.text)


if __name__ == "__main__":
    unittest.main()
