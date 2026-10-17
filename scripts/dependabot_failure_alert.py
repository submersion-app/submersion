#!/usr/bin/env python3
"""Raise, update or clear the Dependabot failure alert issue.

Runs daily from .github/workflows/dependabot-alert.yml. Dependabot runs in a
workflow GitHub generates (dynamic/dependabot/dependabot-updates), so a
failed update notifies nobody: the bundler updates for ios/ and macos/ failed
every month from at least July 2026, security updates included, and were only
found by reading the Actions list (#2766, the same gap as #2598).

Each run of that workflow belongs to an update stream, named by its title
without the " - Update #N" suffix: "bundler in /ios, /macos" for the monthly
version update, "bundler in /macos for excon" for a security update. A stream
is failing when its newest run within LOOKBACK_DAYS failed.

  a stream is failing  Open one rolling alert issue if none is open, otherwise
                       comment on it, listing each failing run not already
                       reported. The maintainer is assigned and @-mentioned,
                       which sends the notification. A run already reported
                       is not reported again, so a daily check does not
                       comment daily on the same red run.
  no stream is failing Close the open alert, if there is one.

The lookback is longer than the monthly bundler cadence, so a red monthly run
stays visible until the next one. It also lets a security stream that never
runs again (its alert was fixed by a version update) age out instead of
holding the issue open forever.

The rolling issue is found by MARKER in its body, and each reported run by a
hidden FAILED_RUN record, so editing the title or text by hand changes
nothing. A listing that cannot be read raises, failing the job, rather than
reading as "nothing failed" and closing the alert. Assigning is best effort:
the @-mention still notifies.

Pure stdlib plus the `gh` CLI, which every GitHub-hosted runner carries.

Usage: dependabot_failure_alert.py   (inputs come from the environment, see main)
"""

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.parse

WORKFLOW_PATH = "dynamic/dependabot/dependabot-updates"

MARKER = "<!-- dependabot-failure-alert -->"
LABEL = "ci"
TITLE = "Dependabot updates failing: dependency and security updates are not landing"

FAILED_RUN = "<!-- dependabot-failed-run: {} -->"
_FAILED_RUN_RE = re.compile(r"<!-- dependabot-failed-run: (\d+) -->")
_UPDATE_SUFFIX_RE = re.compile(r"\s+-\s+Update #\d+$")

LOOKBACK_DAYS = 35

# Used when the DEPENDABOT_ALERT_ASSIGNEE Actions variable is unset.
DEFAULT_ASSIGNEE = "ericgriffin"

FAILED_CONCLUSIONS = frozenset({"failure", "timed_out", "startup_failure"})


def stream_key(title):
    """Return the update stream a run title belongs to."""
    return _UPDATE_SUFFIX_RE.sub("", title or "")


def failing_streams(runs, now):
    """Return the newest run of each failing stream, sorted by stream key."""
    since = now - datetime.timedelta(days=LOOKBACK_DAYS)
    newest = {}
    for run in runs:
        created = datetime.datetime.fromisoformat(run["created_at"].replace("Z", "+00:00"))
        if created < since:
            continue
        key = stream_key(run.get("display_title"))
        if key not in newest or created > newest[key][0]:
            newest[key] = (created, run)
    return [
        run
        for key, (_, run) in sorted(newest.items())
        if run.get("conclusion") in FAILED_CONCLUSIONS
    ]


def gh_cli(args):
    """Run gh and return stdout; raises CalledProcessError on failure."""
    completed = subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    )
    return completed.stdout


def _warn(message):
    print(f"::warning::{message}")


def _api(gh, path):
    return json.loads(gh(["api", "--paginate", "--slurp", path]) or "[]")


def _workflow_id(gh, repo):
    for page in _api(gh, f"repos/{repo}/actions/workflows"):
        for workflow in page.get("workflows", []):
            if workflow.get("path") == WORKFLOW_PATH:
                return workflow["id"]
    raise RuntimeError(
        f"no {WORKFLOW_PATH} workflow in {repo}; is Dependabot version updates on?"
    )


def _runs(gh, repo, now):
    since = (now - datetime.timedelta(days=LOOKBACK_DAYS)).date().isoformat()
    query = urllib.parse.urlencode(
        {"per_page": 100, "status": "completed", "created": f">={since}"}
    )
    path = f"repos/{repo}/actions/workflows/{_workflow_id(gh, repo)}/runs?{query}"
    return [run for page in _api(gh, path) for run in page.get("workflow_runs", [])]


def _open_alert(gh, repo):
    """Return the number of the oldest open rolling alert issue, or None."""
    listing = gh(
        [
            "issue", "list", "--repo", repo, "--state", "open",
            "--label", LABEL, "--limit", "200", "--json", "number,body",
        ]
    )
    numbers = sorted(
        int(issue["number"])
        for issue in json.loads(listing or "[]")
        if MARKER in (issue.get("body") or "")
    )
    return numbers[0] if numbers else None


def _reported(gh, repo, number):
    """Return the ids of the runs the open alert has already reported."""
    issue = json.loads(
        gh(["issue", "view", str(number), "--repo", repo, "--json", "body,comments"])
    )
    texts = [issue.get("body") or ""] + [
        c.get("body") or "" for c in issue.get("comments") or []
    ]
    return {int(n) for t in texts for n in _FAILED_RUN_RE.findall(t)}


def _report(runs, assignee):
    lines = [FAILED_RUN.format(run["id"]) for run in runs]
    lines += [f"@{assignee} Dependabot update runs failed:", ""]
    lines += [
        f"- **{stream_key(run.get('display_title'))}** "
        f"({run.get('conclusion')}, {run['created_at'][:10]}): {run['html_url']}"
        for run in runs
    ]
    lines += [
        "",
        "The run log's error table names the cause; a "
        "`dependency_file_not_parseable` error means Dependabot could not read "
        "the manifest. Security updates for that ecosystem fail the same way. "
        "Once every update stream's newest run succeeds, this issue closes.",
    ]
    return "\n".join(lines)


def _assign(gh, repo, number, assignee):
    try:
        gh(["issue", "edit", str(number), "--repo", repo, "--add-assignee", assignee])
    except subprocess.CalledProcessError as exc:
        _warn(
            f"could not assign #{number} to {assignee} ({exc.stderr or exc}); "
            "the @-mention still notifies them"
        )


def raise_alert(gh, ctx, failing):
    repo = ctx["repo"]
    # A login is often written "@name"; verbatim it would be an "@@name"
    # mention and an assignment GitHub rejects, so nobody would be notified.
    assignee = ctx["assignee"].strip().lstrip("@") or DEFAULT_ASSIGNEE
    number = _open_alert(gh, repo)
    if number is None:
        body = "\n".join(
            [
                MARKER,
                "Opened automatically by the Dependabot failure alert workflow. "
                "Later failures comment here instead of opening another issue.",
                "",
                _report(failing, assignee),
            ]
        )
        url = gh(
            [
                "issue", "create", "--repo", repo, "--title", TITLE,
                "--label", LABEL, "--body", body,
            ]
        ).strip()
        number = int(url.rstrip("/").rsplit("/", 1)[-1])
        print(f"Opened Dependabot failure alert {url}")
    else:
        reported = _reported(gh, repo, number)
        new = [run for run in failing if int(run["id"]) not in reported]
        if not new:
            print(f"Every failing run is already reported on #{number}.")
            return
        gh(
            [
                "issue", "comment", str(number), "--repo", repo,
                "--body", _report(new, assignee),
            ]
        )
        print(f"Commented on open Dependabot failure alert #{number}")
    _assign(gh, repo, number, assignee)


def resolve_alert(gh, ctx):
    repo = ctx["repo"]
    number = _open_alert(gh, repo)
    if number is None:
        print("No Dependabot update stream is failing; no alert is open.")
        return
    gh(
        [
            "issue", "close", str(number), "--repo", repo, "--comment",
            "The newest run of every Dependabot update stream in the last "
            f"{LOOKBACK_DAYS} days succeeded.",
        ]
    )
    print(f"Closed Dependabot failure alert #{number}")


def run(ctx, gh=gh_cli, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    runs = _runs(gh, ctx["repo"], now)
    if not runs:
        # pub and github_actions update weekly, so an empty window means
        # Dependabot stopped running (a broken dependabot.yml, say). Failing
        # the job beats closing the alert as though every stream were green.
        raise RuntimeError(
            f"no completed Dependabot run in the last {LOOKBACK_DAYS} days"
        )
    failing = failing_streams(runs, now)
    if failing:
        raise_alert(gh, ctx, failing)
    else:
        resolve_alert(gh, ctx)
    return 0


def main(env, gh=gh_cli, now=None):
    ctx = {
        "repo": env["GITHUB_REPOSITORY"],
        "assignee": env.get("DEPENDABOT_ALERT_ASSIGNEE", ""),
    }
    return run(ctx, gh, now)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(os.environ))
