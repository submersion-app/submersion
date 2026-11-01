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
import subprocess
import sys
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

PLATFORMS = ("macos", "android", "windows", "linux")
RECENT_LIMIT = 4
SCHEMA = 1

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

# Left out on purpose. A file matching neither these nor the suffixes above is
# reported, so a new installer type cannot drop out of the count unnoticed. That
# is why .zip is not a blanket exclusion: only the demo data's zips are known.
_EXCLUDED_SUFFIXES = (".xml", ".aab", ".ipa", ".txt", ".html", ".json")
_DEMO_DATA_PREFIX = "submersion-demo-"


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
    classified = (
        (classify_asset(asset["name"]), asset["downloads"])
        for asset in release["assets"]
    )
    return [(platform, count) for platform, count in classified if platform]


def totals_for(snapshot: dict) -> dict:
    """Add up the counted files, overall and by platform."""
    counted = [
        found for release in snapshot["releases"] for found in _counted_assets(release)
    ]
    platforms = {
        platform: sum(count for name, count in counted if name == platform)
        for platform in PLATFORMS
    }
    return {"total": sum(platforms.values()), "platforms": platforms}


def recent_releases(snapshot: dict, limit: int = RECENT_LIMIT) -> list[dict]:
    """Return the newest stable releases that have at least one counted file."""
    counted = [
        {
            "tag": release["tag"],
            "published_at": release["published_at"],
            "downloads": sum(count for _, count in _counted_assets(release)),
        }
        for release in snapshot["releases"]
        if _counted_assets(release) and not release["prerelease"]
    ]
    return sorted(counted, key=lambda r: r["published_at"], reverse=True)[:limit]


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


def _known_exclusion(name: str) -> bool:
    lowered = name.lower()
    return lowered.endswith(_EXCLUDED_SUFFIXES) or lowered.startswith(_DEMO_DATA_PREFIX)


def unclassified_assets(snapshot: dict) -> list[str]:
    """Return file names that are neither counted nor known to be excluded."""
    return sorted(
        {
            asset["name"]
            for release in snapshot["releases"]
            for asset in release["assets"]
            if classify_asset(asset["name"]) is None
            and not _known_exclusion(asset["name"])
        }
    )


def gh_cli(args: list[str]) -> str:
    """Run gh and return stdout; raises CalledProcessError on failure."""
    completed = subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    )
    return completed.stdout


def fetch_all_releases(gh: Callable[[list[str]], str], repo: str) -> list[dict]:
    """Read every release, leaving the page walking to gh."""
    path = f"repos/{repo}/releases?per_page=100"
    pages = json.loads(gh(["api", "--paginate", "--slurp", path]))
    return [release for page in pages for release in page]


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


def _falling_total_warnings(earlier: list[dict], snapshot: dict) -> list[str]:
    if not earlier:
        return []
    before = totals_for(earlier[-1])["total"]
    after = totals_for(snapshot)["total"]
    if after >= before:
        return []
    return [
        f"Download total fell from {before} to {after}. "
        "Deleting a release removes its counts."
    ]


def write_outputs(root: Path, snapshot: dict) -> list[str]:
    """Store a snapshot and rebuild the summary, returning workflow warnings."""
    date = snapshot["date"]
    stored = [s for s in load_snapshots(root) if s["date"] != date]
    _write_json(_snapshot_path(root, date), snapshot)
    readme = root / "README.md"
    if not readme.exists():
        readme.write_text(README, encoding="utf-8")
    snapshots = sorted([*stored, snapshot], key=lambda s: s["date"])
    _write_json(root / "downloads" / "summary.json", build_summary(snapshots))
    return _falling_total_warnings([s for s in stored if s["date"] < date], snapshot)


def main(
    argv: list[str] | None = None,
    gh: Callable[[list[str]], str] | None = None,
    now: datetime | None = None,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="owner/name of the repository")
    parser.add_argument(
        "--out", required=True, type=Path, help="checkout of the metrics branch"
    )
    args = parser.parse_args(argv)

    # Everything is read before anything is written, so a failure leaves the
    # metrics branch alone.
    try:
        releases = fetch_all_releases(gh or gh_cli, args.repo)
        snapshot = build_snapshot(releases, now or datetime.now(timezone.utc))
        total = totals_for(snapshot)["total"]
    except (
        subprocess.CalledProcessError,
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ) as error:
        print(f"::error::Could not read releases: {error!r}")
        return 1
    if total == 0:
        print("::error::GitHub returned no counted downloads.")
        return 1

    unknown = unclassified_assets(snapshot)
    warnings = [
        *write_outputs(args.out, snapshot),
        *([f"Files neither counted nor excluded: {', '.join(unknown)}"] if unknown else []),
    ]
    for warning in warnings:
        print(f"::warning::{warning}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
