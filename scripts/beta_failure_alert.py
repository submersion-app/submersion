#!/usr/bin/env python3
"""Raise, update or clear the Beta pipeline's failure alert issue.

Runs as the last job of .github/workflows/beta.yml. Five red Beta runs in
eleven hours, every one a failed Play upload, produced no notification of any
kind and were only found by reading the Actions list (#2597, #2598). A failed
upload or distribution means testers are not getting the build, so it must not
be silent.

Behaviour, decided from the workflow's `toJSON(needs)`:

  any job failed      Open one rolling alert issue if none is open, otherwise
                      comment on it. Either way the maintainer is assigned and
                      @-mentioned, which is what sends the notification.
  every job succeeded The beta published on every lane: close the open alert,
                      if there is one.
  anything else       A run gated off (nothing shippable, skip-publish) or
                      cancelled by a newer one. Not a failure, not a publish.

The rolling issue is found by MARKER in its body rather than by title, so
editing the title by hand does not make the next failure open a duplicate.
Runs are deliberately not serialized: a concurrency group keeps only one
pending job and cancels the one it replaces, so a green run could discard a
queued failure alert. Instead, two failing runs that each opened an issue fold
together afterwards: the newer issue hands its report to the oldest and closes.

Unserialized runs also finish out of order: the store lanes queue behind the
previous run's, but precheck and build do not, so a newer run's build can fail
while an older run is still uploading. The newest run's verdict wins. Every
report records its run number (FAILED_RUN) and every close records the
resolving run (RESOLVED_RUN). A green run closes only if no newer failure is
recorded, and reopens if one lands while it closes; a failing run reopens an
alert that an older or same-numbered run closed meanwhile. Run numbers only
grow, and a re-run keeps its number, so a re-run that goes green resolves the
failure it re-ran.

A failure to write the issue exits non-zero. An alert that cannot be delivered
must not report success, which is how the promotion alert hid its own failure
(#2609). Assigning and reading the run's failed steps are best effort: losing
either still delivers the alert.

Pure stdlib plus the `gh` CLI, which every GitHub-hosted runner carries.

Usage: beta_failure_alert.py   (inputs come from the environment, see main)
"""

import json
import os
import re
import subprocess
import sys

# The job in beta.yml that runs this script. beta_failure_alert_test.py checks
# that its needs list every other job: needs.*.result sees nothing else, and a
# failed build skips every lane rather than failing it.
ALERT_JOB = "alert"

MARKER = "<!-- beta-failure-alert -->"
LABEL = "ci"
TITLE = "Beta pipeline failing: testers are not getting new builds"

# Hidden run-number records in reports and close comments; see the docstring.
FAILED_RUN = "<!-- beta-failure-run: {} -->"
RESOLVED_RUN = "<!-- beta-resolved-run: {} -->"
_FAILED_RUN_RE = re.compile(r"<!-- beta-failure-run: (\d+) -->")
_RESOLVED_RUN_RE = re.compile(r"<!-- beta-resolved-run: (\d+) -->")

# Used when the BETA_ALERT_ASSIGNEE Actions variable is unset.
DEFAULT_ASSIGNEE = "ericgriffin"

# Job conclusions the jobs API uses for a job that needs.*.result reports as
# `failure`. A timeout is `failure` to needs but `timed_out` here.
FAILED_CONCLUSIONS = frozenset({"failure", "timed_out", "startup_failure"})


def decide(needs):
    """Return (action, failed_job_ids) for a `toJSON(needs)` mapping."""
    results = {job: (info or {}).get("result") for job, info in needs.items()}
    failed = sorted(job for job, result in results.items() if result == "failure")
    if failed:
        return "alert", failed
    if results and all(result == "success" for result in results.values()):
        return "resolve", []
    return "none", []


def failed_steps(jobs):
    """Return [(job name, [failed step names])] for every failed job."""
    return [
        (
            job.get("name", "?"),
            [
                step.get("name", "?")
                for step in job.get("steps") or []
                if step.get("conclusion") == "failure"
            ],
        )
        for job in jobs
        if job.get("conclusion") in FAILED_CONCLUSIONS
    ]


def gh_cli(args):
    """Run gh and return stdout; raises CalledProcessError on failure."""
    completed = subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    )
    return completed.stdout


def _warn(message):
    print(f"::warning::{message}")


def _run_jobs(gh, ctx):
    """Return the jobs of this run attempt, or None if they cannot be read."""
    path = (
        f"repos/{ctx['repo']}/actions/runs/{ctx['run_id']}"
        f"/attempts/{ctx['run_attempt']}/jobs"
    )
    try:
        pages = json.loads(gh(["api", "--paginate", "--slurp", path]))
    except (subprocess.CalledProcessError, ValueError) as exc:
        _warn(f"could not read this run's jobs ({exc}); listing job ids only")
        return None
    return [job for page in pages for job in page.get("jobs", [])]


def _failure_lines(gh, ctx, failed_ids):
    # The ids from needs are always listed: they are the complete set, while
    # the API's per-job details can miss one (a timeout reported as
    # `cancelled`), and details for one job must not hide another.
    lines = ["Failed: " + ", ".join(f"`{job}`" for job in failed_ids), ""]
    jobs = _run_jobs(gh, ctx)
    for name, steps in failed_steps(jobs) if jobs is not None else []:
        suffix = ", at " + ", ".join(f"`{s}`" for s in steps) if steps else ""
        lines.append(f"- **{name}**{suffix}")
    return lines


def _report(gh, ctx, failed_ids, assignee):
    tag = ctx["tag"] or "(version not computed: precheck failed)"
    sha = ctx["sha"][:12] if ctx["sha"] else "unknown"
    return "\n".join(
        [
            FAILED_RUN.format(ctx["run_number"]),
            f"@{assignee} Beta `{tag}` (source `{sha}`) failed:",
            "",
            *_failure_lines(gh, ctx, failed_ids),
            "",
            f"**Run:** {ctx['run_url']}",
            "",
            "Until this is fixed, testers on the failed lanes are not getting "
            "this build. Re-run the failed jobs once the cause is fixed; a run "
            "that publishes on every lane closes this issue.",
        ]
    )


def _open_alerts(gh, repo):
    """Return the numbers of every open rolling alert issue, oldest first."""
    listing = gh(
        [
            "issue", "list", "--repo", repo, "--state", "open",
            "--label", LABEL, "--limit", "200", "--json", "number,body",
        ]
    )
    return sorted(
        int(issue["number"])
        for issue in json.loads(listing or "[]")
        if MARKER in (issue.get("body") or "")
    )


def _open_alert(gh, repo):
    """Return the number of the oldest open rolling alert issue, or None."""
    numbers = _open_alerts(gh, repo)
    return numbers[0] if numbers else None


def _fold_duplicate(gh, repo, number, report):
    """Fold a just-opened issue into an older one a concurrent run opened.

    Returns the issue the alert now lives on.
    """
    oldest = _open_alert(gh, repo)
    if oldest is None or oldest >= number:
        return number
    gh(["issue", "comment", str(oldest), "--repo", repo, "--body", report])
    gh(
        [
            "issue", "close", str(number), "--repo", repo, "--reason",
            "not planned", "--comment",
            f"Duplicate of #{oldest}, opened by a concurrent run; "
            "its report is copied there.",
        ]
    )
    print(f"Folded duplicate #{number} into beta failure alert #{oldest}")
    return oldest


def _issue_record(gh, repo, number):
    """Return (state, newest failed run, newest resolving run) of an issue."""
    issue = json.loads(
        gh(["issue", "view", str(number), "--repo", repo, "--json", "state,body,comments"])
    )
    texts = [issue.get("body") or ""] + [
        c.get("body") or "" for c in issue.get("comments") or []
    ]

    def newest(pattern):
        return max((int(n) for t in texts for n in pattern.findall(t)), default=0)

    return issue.get("state"), newest(_FAILED_RUN_RE), newest(_RESOLVED_RUN_RE)


def _reopen(gh, repo, number, why):
    gh(["issue", "reopen", str(number), "--repo", repo, "--comment", why])
    print(f"Reopened beta failure alert #{number}: {why}")


def _assign(gh, repo, number, assignee):
    try:
        gh(["issue", "edit", str(number), "--repo", repo, "--add-assignee", assignee])
    except subprocess.CalledProcessError as exc:
        _warn(
            f"could not assign #{number} to {assignee} ({exc.stderr or exc}); "
            "the @-mention still notifies them"
        )


def raise_alert(gh, ctx, failed_ids):
    repo = ctx["repo"]
    # A login is often written "@name"; verbatim it would be an "@@name"
    # mention and an assignment GitHub rejects, so nobody would be notified.
    assignee = ctx["assignee"].strip().lstrip("@") or DEFAULT_ASSIGNEE
    report = _report(gh, ctx, failed_ids, assignee)
    number = _open_alert(gh, repo)
    if number is None:
        body = "\n".join(
            [
                MARKER,
                "Opened automatically by the Beta workflow. Later failures "
                "comment here instead of opening another issue.",
                "",
                report,
            ]
        )
        url = gh(
            [
                "issue", "create", "--repo", repo, "--title", TITLE,
                "--label", LABEL, "--body", body,
            ]
        ).strip()
        number = int(url.rstrip("/").rsplit("/", 1)[-1])
        print(f"Opened beta failure alert {url}")
        number = _fold_duplicate(gh, repo, number, report)
    else:
        gh(["issue", "comment", str(number), "--repo", repo, "--body", report])
        print(f"Commented on open beta failure alert #{number}")
    # A green run may have closed the issue between the lookup and the
    # comment. Unless that run was newer, this failure stands.
    run_number = int(ctx["run_number"])
    state, _, resolved = _issue_record(gh, repo, number)
    if state != "OPEN" and resolved <= run_number:
        _reopen(
            gh, repo, number,
            f"Run {run_number} failed after an older run closed this alert.",
        )
    _assign(gh, repo, number, assignee)


def resolve_alert(gh, ctx):
    repo = ctx["repo"]
    number = _open_alert(gh, repo)
    if number is None:
        print("Beta published on every lane; no alert is open.")
        return
    run_number = int(ctx["run_number"])
    _, failed, _ = _issue_record(gh, repo, number)
    if failed > run_number:
        print(
            f"Run {run_number} published on every lane, but newer run {failed} "
            f"failed; leaving #{number} open."
        )
        return
    gh(
        [
            "issue", "close", str(number), "--repo", repo, "--comment",
            f"{RESOLVED_RUN.format(run_number)}\n"
            f"Beta `{ctx['tag']}` published on every lane: {ctx['run_url']}",
        ]
    )
    print(f"Closed beta failure alert #{number}")
    # A newer run's failure may have landed while this one was closing.
    _, failed, _ = _issue_record(gh, repo, number)
    if failed > run_number:
        _reopen(
            gh, repo, number,
            f"Run {failed} failed while older run {run_number} was closing this alert.",
        )


def run(needs, ctx, gh=gh_cli):
    action, failed_ids = decide(needs)
    if action == "alert":
        raise_alert(gh, ctx, failed_ids)
    elif action == "resolve":
        resolve_alert(gh, ctx)
    else:
        print("No job failed and not every lane published; nothing to do.")
    return 0


def main(env, gh=gh_cli):
    repo = env["GITHUB_REPOSITORY"]
    run_id = env["GITHUB_RUN_ID"]
    ctx = {
        "repo": repo,
        "run_id": run_id,
        "run_attempt": env.get("GITHUB_RUN_ATTEMPT", "1"),
        "run_number": env["GITHUB_RUN_NUMBER"],
        "run_url": f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}"
        f"/{repo}/actions/runs/{run_id}",
        "tag": env.get("BETA_TAG", ""),
        "sha": env.get("BETA_SHA", ""),
        "assignee": env.get("BETA_ALERT_ASSIGNEE", ""),
    }
    return run(json.loads(env["NEEDS_JSON"]), ctx, gh)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(os.environ))
