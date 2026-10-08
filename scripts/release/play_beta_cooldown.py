#!/usr/bin/env python3
"""Decide whether this beta should go on to Play open testing.

Runs inside the Play job of .github/workflows/beta.yml, after the build has
gone to the internal testing track. Every merge to main makes a beta, often
several a day, and each one used to go straight to open testing. Google counts
its review turnaround "from the last submitted change to an app", so a new
release submitted while another is in review sends the app to the back of the
queue. Merges arriving faster than a review finishes kept 1.8.1 in review for
days while open testers stayed on 8556 (#2887).

So open testing gets a build at most once per cooldown. The internal track has
no review wait and takes every build; this script only decides the promotion:

  the last successful promotion is older than the cooldown, or there is none
      due=true: promote this build to open testing (and closed testing)
  it is newer than the cooldown
      due=false: leave the release under review alone; a later merge, after
      the cooldown, ships the newest build then

The history comes from the Actions API: the newest successful run of the
promotion step in an earlier Beta run. A refused or skipped promotion does not
count, since it submitted nothing. If the history cannot be read the script
fails rather than guessing: "due" could reset a running review, and "not due"
could stop open testing without anyone noticing.

PLAY_OPEN_TESTING_COOLDOWN_HOURS (an Actions variable) sets the cooldown,
DEFAULT_HOURS when unset; 0 promotes every build, the old behaviour.

Pure stdlib plus the `gh` CLI, which every GitHub-hosted runner carries.

Usage: play_beta_cooldown.py   (inputs come from the environment, see main)
"""

import json
import math
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

# Must match the job and step names in beta.yml; play_beta_cooldown_test.py
# checks that they do.
PLAY_JOB = "Upload Android beta to Play"
PROMOTE_STEP = "Promote to Play open testing"

# Every (job, step) that submitted a release to open testing. The second is the
# job before #2887, which uploaded each beta straight to open testing; counting
# it stops the first run after the switch from resetting a running review.
# Drop it once no run older than the cooldown plus WINDOW_MARGIN carries it.
PROMOTIONS = frozenset({
    (PLAY_JOB, PROMOTE_STEP),
    ("Upload Android beta to Play open testing", "Upload to Play open testing"),
})

WORKFLOW_FILE = "beta.yml"

# Longer than a typical review. 8556 cleared in under a day, and Google warns
# that some reviews take up to seven days.
DEFAULT_HOURS = 48.0

# A run created before the window can still promote inside it, after queueing
# for its build and for the Play job's concurrency group. Runs this much older
# than the window are read too.
WINDOW_MARGIN = timedelta(hours=12)


def gh_cli(args):
    """Run `gh` and return its stdout."""
    completed = subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    )
    return completed.stdout


def _parse_time(value):
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def _iso(moment):
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _pages(gh, path, key):
    """Every item under `key` across the pages of a paginated endpoint."""
    pages = json.loads(gh(["api", "--paginate", "--slurp", path]))
    return [item for page in pages for item in page.get(key, [])]


def last_promotion(gh, repo, since, exclude_run):
    """When the newest successful promotion since `since` ended, or None."""
    created = quote(">=", safe="") + _iso(since)
    runs = _pages(
        gh,
        f"repos/{repo}/actions/workflows/{WORKFLOW_FILE}/runs?created={created}&per_page=100",
        "workflow_runs",
    )
    newest = None
    for run in runs:
        # Precheck gates most runs off entirely; their jobs never reached Play.
        if run["id"] == exclude_run or run.get("conclusion") == "skipped":
            continue
        jobs = _pages(
            gh, f"repos/{repo}/actions/runs/{run['id']}/jobs?filter=all&per_page=100", "jobs"
        )
        for job in jobs:
            for step in job.get("steps") or []:
                if (job.get("name"), step.get("name")) not in PROMOTIONS:
                    continue
                if step.get("conclusion") != "success":
                    continue
                ended = _parse_time(step["completed_at"])
                if newest is None or ended > newest:
                    newest = ended
    return newest


def decide(last, now, hours):
    """Return (due, last) for the newest promotion time and the cooldown."""
    if last is None or hours == 0:
        return True, last
    return now - last >= timedelta(hours=hours), last


def parse_hours(raw):
    """The cooldown in hours from the Actions variable; blank means default."""
    text = (raw or "").strip()
    if not text:
        return DEFAULT_HOURS
    hours = float(text)
    if not math.isfinite(hours) or hours < 0:
        raise ValueError(f"must be a non-negative number of hours, got {text!r}")
    return hours


def main(env, gh=gh_cli, now=None):
    now = now or datetime.now(timezone.utc)
    try:
        hours = parse_hours(env.get("PLAY_OPEN_TESTING_COOLDOWN_HOURS"))
    except ValueError as exc:
        print(f"::error title=Play open testing cooldown::PLAY_OPEN_TESTING_COOLDOWN_HOURS {exc}")
        return 1

    last = None
    if hours > 0:
        try:
            last = last_promotion(
                gh,
                env["GITHUB_REPOSITORY"],
                since=now - timedelta(hours=hours) - WINDOW_MARGIN,
                exclude_run=int(env.get("GITHUB_RUN_ID") or 0),
            )
        except (subprocess.CalledProcessError, ValueError, KeyError) as exc:
            detail = getattr(exc, "stderr", "") or exc
            print(
                "::error title=Play open testing cooldown::Could not read the earlier "
                f"Beta runs to find the last open-testing promotion: {detail}"
            )
            return 1

    due, last = decide(last, now, hours)
    if due:
        when = f"last promoted {_iso(last)}" if last else "no promotion found in the window"
        print(f"Promoting to open testing ({when}; cooldown {hours:g}h).")
    else:
        print(
            f"::notice title=Play open testing cooldown::Not promoting: the last "
            f"promotion ended {_iso(last)}, inside the {hours:g}h cooldown. This build "
            "is on internal testing; a merge after the cooldown ships the newest build "
            "to open testing."
        )

    with open(env["GITHUB_OUTPUT"], "a") as output:
        output.write(f"due={'true' if due else 'false'}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(os.environ))
