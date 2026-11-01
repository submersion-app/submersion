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

from datetime import datetime, timezone

PLATFORMS = ("macos", "android", "windows", "linux")
RECENT_LIMIT = 4
SCHEMA = 1

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
