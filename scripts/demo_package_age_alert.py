#!/usr/bin/env python3
"""Opens a rolling issue when the demo-mode sample logbook needs a rebuild.

The sample logbook is built by hand (`scripts/demo_data/pack.sh` reads a
private harvest) and published to the `demo-data` release. The app moves its
dates so the newest dive lands just before the day it is opened, by whole
years while that keeps the newest dive within six weeks, so the seasons stay
true; past that it moves by weeks, which keeps the service clocks on today
but carries summer dives into winter. The newest dive falls in the week before
the build, so a package younger than five weeks keeps both, and this alert
asks for a rebuild once the newest package is older.

Run weekly by `.github/workflows/demo-package-age.yml`: one open issue while
the package is stale, closed once a newer package is published.
"""

import datetime
import json
import os
import subprocess
import sys
import urllib.request

MANIFEST_URL = (
    "https://github.com/submersion-app/submersion/releases/download/"
    "demo-data/demo-manifest.json"
)

# A week less than demoSeasonSlackDays in
# lib/features/demo_mode/data/demo_date_columns.dart: that window runs from the
# newest dive, which falls in the week before the build. A test ties the two.
MAX_AGE_DAYS = 35

MARKER = "<!-- demo-package-age-alert -->"
TITLE = "Rebuild the demo-mode sample logbook"


def newest_generated_at(manifest):
    """The newest package's build time in [manifest]; raises ValueError when
    it lists none."""
    stamps = [
        p["generatedAt"] for p in manifest.get("packages", []) if p.get("generatedAt")
    ]
    if not stamps:
        raise ValueError("the demo manifest lists no package")
    return max(_parse(s) for s in stamps)


def _parse(stamp):
    parsed = datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=datetime.timezone.utc)
    return parsed


def is_stale(generated, now):
    """Whether a package built at [generated] is older than MAX_AGE_DAYS."""
    return now - generated > datetime.timedelta(days=MAX_AGE_DAYS)


def fetch_manifest():
    with urllib.request.urlopen(MANIFEST_URL, timeout=30) as response:
        return json.load(response)


def gh_cli(args):
    """Run gh and return stdout; raises CalledProcessError on failure."""
    completed = subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    )
    return completed.stdout


def _open_alerts(gh, repo):
    issues = json.loads(
        gh(
            [
                "issue", "list", "--repo", repo, "--state", "open",
                "--search", f'"{TITLE}" in:title', "--limit", "50",
                "--json", "number,body",
            ]
        )
        or "[]"
    )
    return [i["number"] for i in issues if MARKER in (i.get("body") or "")]


def _body(generated, now):
    age = (now - generated).days
    return (
        f"{MARKER}\n"
        f"The published demo-mode sample logbook was built on "
        f"{generated.date().isoformat()}, {age} days ago. Past "
        f"{MAX_AGE_DAYS} days the app can no longer move it by whole years "
        "and keep its newest dive recent, so its seasons drift: summer dives "
        "show in winter.\n\n"
        "Rebuild and publish it as `tool/demo_data/README.md` describes "
        "(`scripts/demo_data/pack.sh`, then upload the zip and the merged "
        "`demo-manifest.json` to the `demo-data` release). This issue closes "
        "itself once a newer package is published.\n"
    )


def run(ctx, fetch=fetch_manifest, gh=gh_cli, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    repo = ctx["repo"]
    generated = newest_generated_at(fetch())
    open_alerts = _open_alerts(gh, repo)
    if is_stale(generated, now):
        if open_alerts:
            print(f"Demo package is stale; alert #{open_alerts[0]} is open.")
            return 0
        gh(
            [
                "issue", "create", "--repo", repo, "--title", TITLE,
                "--body", _body(generated, now),
            ]
        )
        print("Opened the demo package rebuild alert.")
        return 0
    for number in open_alerts:
        gh(
            [
                "issue", "close", str(number), "--repo", repo, "--comment",
                f"A demo package built on {generated.date().isoformat()} is "
                "published.",
            ]
        )
        print(f"Closed demo package rebuild alert #{number}")
    return 0


def main(env, fetch=fetch_manifest, gh=gh_cli, now=None):
    return run({"repo": env["GITHUB_REPOSITORY"]}, fetch, gh, now)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(os.environ))
