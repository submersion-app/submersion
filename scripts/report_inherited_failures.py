#!/usr/bin/env python3
"""Mark pull-request CI failures that main is failing too.

A pull request's CI tests the merge of the branch into main, so when main is
red every open branch goes red with it, and the contributor cannot tell their
own breakage from the pre-existing kind (issue #2611). The `CI Success` gate
runs this script on a pull request whose required jobs did not all pass. For
each failed job it looks up the same job, by name, in main's CI/CD run, and
emits:

  - a warning annotation, "Also failing on main", when main's job failed too:
    the failure is probably inherited, and the run on main is linked;
  - a notice, "Not failing on main", when main's job passed: the failure is
    new;
  - a notice, "No result on main", when main skipped, cancelled or never ran
    the job, so there is nothing to compare with.

The pull request stays red either way. Test shards are compared as one job,
because a branch that changes the test files moves them between shards. So a
failing shard can still hide a second failure the branch added on top of
main's; the annotation says "likely" for that reason.

The baseline is main's finished run at the pull request's base commit, the one
this merge was built on, looked up by sha; failing that, the newest finished
run on main.
Cancelled runs are skipped: concurrency cancels superseded runs on main, and
their jobs say nothing about whether main is healthy.

This is reporting only. It exits 0 whatever happens, including API errors, so
it can never be the reason a pipeline fails. Standard library only: the gate
job installs nothing.

Environment: GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_WORKFLOW_REF, BASE_SHA
(the pull request's base sha), GH_TOKEN or GITHUB_TOKEN (needs actions: read),
GITHUB_STEP_SUMMARY (optional), GITHUB_API_URL (optional).
"""

import json
import os
import re
import sys
import urllib.request

# The job running this script. Its own failure is the symptom, not a cause.
GATE_NAME = "CI Success"

FAILED = frozenset({"failure", "timed_out"})

# A finished run whose jobs describe main's health. Cancelled and skipped runs
# do not: their jobs never got to a verdict.
_USABLE_RUN = frozenset({"success", "failure", "timed_out"})

_PAGE = 100

_SHARD_SUFFIX = re.compile(r"\s*\(shard \d+\)$")


def escape_data(text):
    """Escape a workflow command's message."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    """Escape a workflow command property such as title=."""
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def failed_job_names(jobs):
    """Sorted, unique names of the failed jobs, leaving out the gate."""
    return sorted(
        {
            j["name"]
            for j in jobs
            if j.get("conclusion") in FAILED and j.get("name") != GATE_NAME
        }
    )


def pick_baseline(runs, base_sha):
    """main's run to compare against, or None when there is none."""
    usable = [
        r
        for r in runs
        if r.get("status") == "completed" and r.get("conclusion") in _USABLE_RUN
    ]
    for r in usable:
        if r.get("head_sha") == base_sha:
            return r
    return usable[0] if usable else None


def job_family(name):
    """The name a job is compared under: test shards share one.

    Shards are load-balanced over test weights (scripts/bundle_tests.py), so a
    pull request that adds, removes or resizes a test file moves files between
    shards. main's broken file can then fail in a different shard number.
    """
    return _SHARD_SUFFIX.sub("", name)


def classify(pr_failed, main_jobs):
    """Split failed job names into (inherited, new, unknown) against main.

    new needs main to have PASSED the job. A job main skipped (a docs-only
    commit skips codegen and everything after it), cancelled or never ran is
    unknown: there is no verdict on main to compare with.
    """
    main_failed = set()
    main_passed = set()
    for j in main_jobs:
        family = job_family(j["name"])
        if j.get("conclusion") in FAILED:
            main_failed.add(family)
        elif j.get("conclusion") == "success":
            main_passed.add(family)
    inherited, new, unknown = [], [], []
    for name in pr_failed:
        family = job_family(name)
        if family in main_failed:
            inherited.append(name)
        elif family in main_passed:
            new.append(name)
        else:
            unknown.append(name)
    return inherited, new, unknown


def api_get(path, env=os.environ):
    """GET a GitHub REST path and decode its JSON body."""
    base = env.get("GITHUB_API_URL", "https://api.github.com")
    token = env.get("GH_TOKEN") or env.get("GITHUB_TOKEN", "")
    request = urllib.request.Request(base + path)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def list_jobs(fetch, repo, run_id):
    """Every job of a run, latest attempt only, across pages."""
    jobs = []
    page = 1
    while True:
        body = fetch(
            f"/repos/{repo}/actions/runs/{run_id}/jobs"
            f"?filter=latest&per_page={_PAGE}&page={page}"
        )
        batch = body.get("jobs", [])
        jobs.extend(batch)
        if len(batch) < _PAGE or len(jobs) >= body.get("total_count", 0):
            return jobs
        page += 1


def workflow_file(env):
    """The workflow's file name, from GITHUB_WORKFLOW_REF."""
    ref = env.get("GITHUB_WORKFLOW_REF", "")
    path = ref.split("@", 1)[0]
    return path.rsplit("/", 1)[-1] or "ci.yaml"


def notice(message):
    print(f"::notice::{escape_data(message)}")


def report(env, fetch):
    repo = env["GITHUB_REPOSITORY"]
    run_id = env["GITHUB_RUN_ID"]
    base_sha = env.get("BASE_SHA", "")

    pr_failed = failed_job_names(list_jobs(fetch, repo, run_id))
    if not pr_failed:
        return

    # The base commit first, by sha: a long-lived branch's base can be older
    # than any page of recent runs. Then main's newest finished run.
    runs_path = f"/repos/{repo}/actions/workflows/{workflow_file(env)}/runs"
    filters = "branch=main&event=push&status=completed"
    baseline = None
    if base_sha:
        at_base = fetch(f"{runs_path}?head_sha={base_sha}&{filters}&per_page=10")
        baseline = pick_baseline(at_base.get("workflow_runs", []), base_sha)
    if baseline is None:
        recent = fetch(f"{runs_path}?{filters}&per_page=30")
        baseline = pick_baseline(recent.get("workflow_runs", []), base_sha)
    if baseline is None:
        notice(
            "No finished CI/CD run on main to compare against, so inherited "
            "failures cannot be told apart from new ones."
        )
        return

    inherited, new, unknown = classify(
        pr_failed, list_jobs(fetch, repo, baseline["id"])
    )
    sha = baseline.get("head_sha", "")[:9]
    url = baseline.get("html_url", "")
    at_base = baseline.get("head_sha") == base_sha
    where = "at this pull request's base" if at_base else "in its newest finished run"

    for name in inherited:
        title = escape_property("Also failing on main")
        print(
            f"::warning title={title}::"
            + escape_data(
                f"{name} also failed on main {where} ({sha}): {url}. The "
                "failure is likely inherited from main rather than caused by "
                "this pull request. It still blocks the merge until main is "
                "fixed and this branch picks up the fix."
            )
        )
    for name in new:
        title = escape_property("Not failing on main")
        print(
            f"::notice title={title}::"
            + escape_data(
                f"{name} passed on main {where} ({sha}), so this failure is "
                "new on this pull request."
            )
        )
    for name in unknown:
        title = escape_property("No result on main")
        print(
            f"::notice title={title}::"
            + escape_data(
                f"{name} has no result on main {where} ({sha}): it was "
                "skipped, cancelled or not run there, so this failure cannot "
                "be compared."
            )
        )

    summary_path = env.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        lines = [
            "### Failures compared with main",
            "",
            f"Baseline: [main run at {sha}]({url}), {where}.",
            "",
            "| Job | On main |",
            "| --- | --- |",
        ]
        lines += [f"| {name} | also failing: likely inherited |" for name in inherited]
        lines += [f"| {name} | passing: new here |" for name in new]
        lines += [f"| {name} | no result on main: cannot compare |" for name in unknown]
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")


def main(env=None, fetch=None):
    env = os.environ if env is None else env
    fetch = (lambda path: api_get(path, env)) if fetch is None else fetch
    try:
        report(env, fetch)
    except Exception as error:  # Reporting must never fail the gate.
        notice(f"Could not compare this run's failures with main: {error}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
