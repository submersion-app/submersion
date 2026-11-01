#!/usr/bin/env python3
"""Save GitHub's download counters so submersion.app can show them.

GitHub keeps one running total per release file and no history. This script
records every file's count and builds the summary the website reads.

Only installers count. Most of the raw total is appcast.xml, which is the app's
updater polling for a new version, and store bundles (.aab, .ipa) are not files
people install directly. The result is still fetches rather than people: an app
update downloads the same installer as a new download does.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

PLATFORMS = ("macos", "android", "windows", "linux")
RECENT_LIMIT = 4
SCHEMA = 1
PER_PAGE = 100
REQUEST_TIMEOUT_SECONDS = 30

README = """\
# Download metrics

Machine-written download counts for Submersion, saved once a day by
`.github/workflows/download-metrics.yml` on `main`. This branch shares no
history with `main`.

- `downloads/YYYY/MM/YYYY-MM-DD.json`: every release file's count on that day.
- `downloads/summary.json`: the file submersion.app reads.

The counts are installer fetches, so they include app updates. App Store and
Google Play installs are not counted.
"""

# Matched whole, so a .tar.gz counts and any other .gz does not.
_SUFFIXES = (
    (".dmg", "macos"),
    (".exe", "windows"),
    (".apk", "android"),
    (".tar.gz", "linux"),
    (".deb", "linux"),
    (".rpm", "linux"),
)

# Left out on purpose. A file matching neither list is reported, so a new
# installer type cannot drop out of the count unnoticed.
_EXCLUDED_SUFFIXES = (".xml", ".aab", ".ipa", ".txt", ".html", ".json", ".zip")


def classify_asset(name: str) -> str | None:
    """Return the platform an installer belongs to, or None if it is not one."""
    lowered = name.lower()
    for suffix, platform in _SUFFIXES:
        if lowered.endswith(suffix):
            return platform
    return None


def build_snapshot(releases: list[dict], captured_at: datetime) -> dict:
    """Record every file of every published release at one moment."""
    moment = captured_at.astimezone(timezone.utc)
    return {
        "schema": SCHEMA,
        "date": moment.strftime("%Y-%m-%d"),
        "captured_at": moment.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "releases": [
            {
                "tag": release["tag_name"],
                "published_at": release["published_at"],
                "prerelease": release["prerelease"],
                "assets": [
                    {"name": asset["name"], "downloads": asset["download_count"]}
                    for asset in release["assets"]
                ],
            }
            for release in releases
            if not release["draft"]
        ],
    }


def _counted_assets(release: dict) -> list[tuple[str, int]]:
    """Return (platform, downloads) for each installer in a snapshot release."""
    found = []
    for asset in release["assets"]:
        platform = classify_asset(asset["name"])
        if platform is not None:
            found.append((platform, asset["downloads"]))
    return found


def totals_for(snapshot: dict) -> dict:
    """Add up the counted files, overall and by platform."""
    platforms = {platform: 0 for platform in PLATFORMS}
    for release in snapshot["releases"]:
        for platform, downloads in _counted_assets(release):
            platforms[platform] += downloads
    return {"total": sum(platforms.values()), "platforms": platforms}


def recent_releases(snapshot: dict, limit: int = RECENT_LIMIT) -> list[dict]:
    """Return the newest stable releases that have at least one counted file."""
    counted = []
    for release in snapshot["releases"]:
        assets = _counted_assets(release)
        if assets and not release["prerelease"]:
            counted.append(
                {
                    "tag": release["tag"],
                    "published_at": release["published_at"],
                    "downloads": sum(downloads for _, downloads in assets),
                }
            )
    counted.sort(key=lambda release: release["published_at"], reverse=True)
    return counted[:limit]


def build_summary(snapshots: list[dict]) -> dict:
    """Build the one file the website reads from snapshots, oldest first."""
    latest = snapshots[-1]
    return {
        "schema": SCHEMA,
        "generated_at": latest["captured_at"],
        **totals_for(latest),
        "recent_releases": recent_releases(latest),
        "history": [
            {"date": snapshot["date"], **totals_for(snapshot)}
            for snapshot in snapshots
        ],
    }


def unclassified_assets(snapshot: dict) -> list[str]:
    """Return file names that are neither counted nor known to be excluded."""
    names = set()
    for release in snapshot["releases"]:
        for asset in release["assets"]:
            name = asset["name"]
            if classify_asset(name) is None and not name.lower().endswith(
                _EXCLUDED_SUFFIXES
            ):
                names.add(name)
    return sorted(names)


def fetch_all_releases(get_page: Callable[[int], list[dict]]) -> list[dict]:
    """Read every page of releases, stopping at the first page that is not full."""
    releases = []
    page = 1
    while True:
        batch = get_page(page)
        releases.extend(batch)
        if len(batch) < PER_PAGE:
            return releases
        page += 1


def github_get_page(repo: str, token: str, page: int) -> list[dict]:
    """Fetch one page of releases from the GitHub API."""
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/releases"
        f"?per_page={PER_PAGE}&page={page}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
        },
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        return json.load(response)


def _snapshot_path(root: Path, date: str) -> Path:
    year, month, _ = date.split("-")
    return root / "downloads" / year / month / f"{date}.json"


def load_snapshots(root: Path) -> list[dict]:
    """Read every stored snapshot, oldest first."""
    # Paths are downloads/YYYY/MM/YYYY-MM-DD.json, so their order is date order.
    paths = sorted(root.glob("downloads/*/*/*.json"))
    return [json.loads(path.read_text(encoding="utf-8")) for path in paths]


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def write_outputs(root: Path, snapshot: dict) -> list[str]:
    """Store a snapshot and rebuild the summary, returning workflow warnings."""
    warnings = []
    earlier = [s for s in load_snapshots(root) if s["date"] < snapshot["date"]]
    if earlier:
        before = totals_for(earlier[-1])["total"]
        after = totals_for(snapshot)["total"]
        if after < before:
            warnings.append(
                f"Download total fell from {before} to {after}. "
                "Deleting a release removes its counts."
            )

    _write_json(_snapshot_path(root, snapshot["date"]), snapshot)
    readme = root / "README.md"
    if not readme.exists():
        readme.write_text(README, encoding="utf-8")
    _write_json(root / "downloads" / "summary.json", build_summary(load_snapshots(root)))
    return warnings


def _collect(
    get_page: Callable[[int], list[dict]], now: datetime
) -> tuple[dict | None, str]:
    """Fetch before anything is written, so a failure leaves the branch alone."""
    try:
        snapshot = build_snapshot(fetch_all_releases(get_page), now)
    except (OSError, ValueError, KeyError, TypeError) as error:
        return None, f"Could not read releases: {error!r}"
    if totals_for(snapshot)["total"] == 0:
        return None, "GitHub returned no counted downloads."
    return snapshot, ""


def main(
    argv: list[str] | None = None,
    get_page: Callable[[int], list[dict]] | None = None,
    now: datetime | None = None,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="owner/name of the repository")
    parser.add_argument(
        "--out", required=True, type=Path, help="checkout of the metrics branch"
    )
    args = parser.parse_args(argv)

    token = os.environ.get("GH_TOKEN")
    if not token:
        print("::error::GH_TOKEN is not set.")
        return 1
    reader = get_page or (lambda page: github_get_page(args.repo, token, page))

    snapshot, problem = _collect(reader, now or datetime.now(timezone.utc))
    if snapshot is None:
        print(f"::error::{problem}")
        return 1

    warnings = write_outputs(args.out, snapshot)
    unknown = unclassified_assets(snapshot)
    if unknown:
        warnings.append(f"Files neither counted nor excluded: {', '.join(unknown)}")
    for warning in warnings:
        print(f"::warning::{warning}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
