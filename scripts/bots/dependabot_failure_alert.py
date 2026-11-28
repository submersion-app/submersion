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

A run counts as reported once any alert issue records it, a closed one
included. Closing the alert, by hand or with a fix PR's "Closes", acknowledges
the runs it reported; until they age out of the lookback their streams still
read as failing, and the next daily check would otherwise open a fresh alert
repeating them (#3720 repeated all of #3495). A stream also stays failing
when its title changes, as editing a `directories:` list in dependabot.yml
does, because the renamed stream's green runs are another key.

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


def _since(now):
    """Return the first day of the lookback, as YYYY-MM-DD."""
    return (now - datetime.timedelta(days=LOOKBACK_DAYS)).date().isoformat()


def _runs(gh, repo, now):
    query = urllib.parse.urlencode(
        {"per_page": 100, "status": "completed", "created": f">={_since(now)}"}
    )
    path = f"repos/{repo}/actions/workflows/{_workflow_id(gh, repo)}/runs?{query}"
    return [run for page in _api(gh, path) for run in page.get("workflow_runs", [])]


def _alerts(gh, repo, state, search=None):
    """Return the rolling alert issues in `state`, narrowed by `search`."""
    args = [
        "issue", "list", "--repo", repo, "--state", state,
        "--label", LABEL, "--limit", "200", "--json", "number,body",
    ]
    if search:
        args += ["--search", search]
    return [
        issue
        for issue in json.loads(gh(args) or "[]")
        if MARKER in (issue.get("body") or "")
    ]


def _open_alerts(gh, repo):
    return _alerts(gh, repo, "open")


def _recently_closed_alerts(gh, repo, now):
    # A closed alert last updated before the lookback cannot record a run
    # inside it. Listing open and closed alerts separately also keeps the
    # open one from being pushed past --limit by old closed issues.
    return _alerts(gh, repo, "closed", f"updated:>={_since(now)}")


def _open_alert(alerts):
    """Return the number of the oldest open rolling alert issue, or None."""
    numbers = sorted(int(issue["number"]) for issue in alerts)
    return numbers[0] if numbers else None


def _reported(gh, repo, alerts):
    """Return the ids of the runs the given alert issues have reported."""
    reported = set()
    for alert in alerts:
        issue = json.loads(
            gh(
                [
                    "issue", "view", str(alert["number"]), "--repo", repo,
                    "--json", "body,comments",
                ]
            )
        )
        texts = [issue.get("body") or ""] + [
            c.get("body") or "" for c in issue.get("comments") or []
        ]
        reported |= {int(n) for t in texts for n in _FAILED_RUN_RE.findall(t)}
    return reported


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


def raise_alert(gh, ctx, failing, now):
    repo = ctx["repo"]
    # A login is often written "@name"; verbatim it would be an "@@name"
    # mention and an assignment GitHub rejects, so nobody would be notified.
    assignee = ctx["assignee"].strip().lstrip("@") or DEFAULT_ASSIGNEE
    open_alerts = _open_alerts(gh, repo)
    number = _open_alert(open_alerts)
    reported = _reported(
        gh, repo, open_alerts + _recently_closed_alerts(gh, repo, now)
    )
    new = [run for run in failing if int(run["id"]) not in reported]
    if not new:
        print("Every failing run is already reported on an open or closed alert.")
        return
    if number is None:
        body = "\n".join(
            [
                MARKER,
                "Opened automatically by the Dependabot failure alert workflow. "
                "Later failures comment here instead of opening another issue.",
                "",
                _report(new, assignee),
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
    number = _open_alert(_open_alerts(gh, repo))
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
        raise_alert(gh, ctx, failing, now)
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
