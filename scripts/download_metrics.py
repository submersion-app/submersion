#!/usr/bin/env python3
"""Snapshot GitHub release asset download counts into a CSV time series.

GitHub reports `download_count` per release asset as a single lifetime integer.
There is no history, no per-day breakdown and no way to ask the API what a
count was last week, so the only way to get trend data is to record the counts
on a schedule and diff them afterwards. This script is that recorder; the
scheduled half lives in .github/workflows/download-metrics.yml.

What the counts do and do not mean:

  * They count downloads, not people. There is no unique-user or IP dedup, so
    re-downloads, CI jobs and mirrors all add to the total. GitHub filters some
    known crawlers, but not reliably.
  * appcast.xml is the Sparkle updater feed. It is fetched on every update
    check, so it dwarfs the installer counts and is classified separately --
    see INSTALLER_KINDS -- to keep it out of the headline number.
  * Source tarball/zipball downloads are not counted by GitHub at all; only
    uploaded assets are.
  * A count resets if an asset is deleted and re-uploaded, which shows up here
    as a decrease.

Rows are recorded only when a count changes. A daily run that appended every
asset would add roughly 560 rows a day and grow without bound; recording
changes only keeps the file small, and a value holds until the next recorded
row for that (tag_name, asset_name) series. Pass --full to record every asset
regardless.

Usage:
    download_metrics.py [--repo owner/name] [--csv path] [--full]

Reads GITHUB_TOKEN from the environment when present, purely for the higher
API rate limit; the endpoint is public and works without one.
"""

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

API_ROOT = "https://api.github.com"
DEFAULT_REPO = "submersion-app/submersion"
DEFAULT_CSV = "download_counts.csv"

# The releases endpoint caps per_page at 100. MAX_PAGES is a runaway guard: a
# malformed response that never shortens would otherwise loop forever.
PER_PAGE = 100
MAX_PAGES = 50
TIMEOUT_SECONDS = 30

FIELDS = (
    "captured_at",
    "tag_name",
    "published_at",
    "prerelease",
    "asset_name",
    "asset_kind",
    "download_count",
    "size_bytes",
)

# Suffix -> kind, longest/most specific first: ".tar.gz" has to win over a
# bare archive match, and the Windows installer over a generic executable.
_KIND_BY_SUFFIX = (
    (".dmg", "macos-dmg"),
    (".pkg", "macos-pkg"),
    (".msix", "windows-msix"),
    (".exe", "windows-setup"),
    (".apk", "android-apk"),
    (".aab", "android-aab"),
    (".ipa", "ios-ipa"),
    (".deb", "linux-deb"),
    (".rpm", "linux-rpm"),
    (".appimage", "linux-appimage"),
    (".tar.gz", "linux-tarball"),
    (".zip", "archive"),
)

# Assets that ride along with a release but are not an install of the app.
_KIND_BY_NAME = {
    "appcast.xml": "updater-feed",
    "appcast-beta.xml": "updater-feed",
    "checksums-sha256.txt": "metadata",
    "release-notes.html": "metadata",
}

# What counts towards "someone downloaded the app". Deliberately excludes the
# updater feed, the checksums and the release notes.
INSTALLER_KINDS = frozenset(
    {
        "macos-dmg",
        "macos-pkg",
        "windows-msix",
        "windows-setup",
        "android-apk",
        "android-aab",
        "ios-ipa",
        "linux-deb",
        "linux-rpm",
        "linux-appimage",
        "linux-tarball",
    }
)


def classify_asset(name):
    """Bucket an asset filename into a platform or metadata kind."""
    lowered = name.lower()
    if lowered in _KIND_BY_NAME:
        return _KIND_BY_NAME[lowered]
    for suffix, kind in _KIND_BY_SUFFIX:
        if lowered.endswith(suffix):
            return kind
    return "other"


def _request_json(url, token, opener):
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "submersion-download-metrics",
    }
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, headers=headers)
    with opener(request, timeout=TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_releases(repo, token=None, opener=urllib.request.urlopen):
    """Return every published release for `repo`, following pagination."""
    releases = []
    for page in range(1, MAX_PAGES + 1):
        url = "{root}/repos/{repo}/releases?per_page={per_page}&page={page}".format(
            root=API_ROOT, repo=repo, per_page=PER_PAGE, page=page
        )
        batch = _request_json(url, token, opener)
        if not isinstance(batch, list):
            # An error body is a JSON object. Reading it as a page of releases
            # would turn a 404 or a bad token into a silently empty snapshot.
            message = batch.get("message", batch) if isinstance(batch, dict) else batch
            raise ValueError("unexpected releases payload: {0}".format(message))
        releases.extend(batch)
        if len(batch) < PER_PAGE:
            break
    return releases


def snapshot_rows(releases, captured_at):
    """Flatten releases into one CSV row per asset, in a stable order."""
    rows = []
    for release in releases:
        if release.get("draft"):
            continue
        tag_name = release.get("tag_name") or ""
        published_at = release.get("published_at") or ""
        prerelease = "true" if release.get("prerelease") else "false"
        for asset in release.get("assets") or ():
            asset_name = asset.get("name") or ""
            rows.append(
                {
                    "captured_at": captured_at,
                    "tag_name": tag_name,
                    "published_at": published_at,
                    "prerelease": prerelease,
                    "asset_name": asset_name,
                    "asset_kind": classify_asset(asset_name),
                    "download_count": str(int(asset.get("download_count") or 0)),
                    "size_bytes": str(int(asset.get("size") or 0)),
                }
            )
    # Sorted so the daily commit diffs cleanly instead of reshuffling the file.
    rows.sort(key=lambda row: (row["published_at"], row["tag_name"], row["asset_name"]))
    return rows


def _series_key(row):
    return (row.get("tag_name"), row.get("asset_name"))


def latest_counts(rows):
    """Map each (tag, asset) series to its most recently recorded count."""
    counts = {}
    for row in sorted(rows, key=lambda row: row.get("captured_at", "")):
        counts[_series_key(row)] = row.get("download_count")
    return counts


def merge_snapshot(existing, new_rows, captured_at, full=False):
    """Fold a snapshot into the recorded history.

    Returns (merged_rows, appended_rows). Rows already recorded for
    `captured_at` are replaced, so a manual re-run after a failed scheduled
    run corrects the day rather than duplicating it. Rows for series absent
    from `new_rows` are always kept: a deleted or renamed asset must not erase
    its own history.
    """
    kept = [row for row in existing if row.get("captured_at") != captured_at]
    previous = latest_counts(kept)
    if full:
        additions = list(new_rows)
    else:
        additions = [
            row
            for row in new_rows
            if previous.get(_series_key(row)) != row["download_count"]
        ]
    return kept + additions, additions


def read_rows(path):
    """Read recorded rows, or an empty list if the CSV does not exist yet."""
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def write_rows(path, rows):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=FIELDS,
            restval="",
            extrasaction="ignore",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows, additions, captured_at, path):
    """Render the lifetime totals this snapshot saw, for the run log."""
    totals = {}
    for row in rows:
        kind = row["asset_kind"]
        totals[kind] = totals.get(kind, 0) + int(row["download_count"])
    installers = sum(count for kind, count in totals.items() if kind in INSTALLER_KINDS)
    lines = [
        "Snapshot {0} -> {1}".format(captured_at, path),
        "  assets seen:          {0}".format(len(rows)),
        "  rows appended:        {0}".format(len(additions)),
        "  installer downloads:  {0}".format(installers),
        "  all asset downloads:  {0}".format(sum(totals.values())),
        "  by kind (lifetime):",
    ]
    for kind, total in sorted(totals.items(), key=lambda item: (-item[1], item[0])):
        lines.append("    {0:>8}  {1}".format(total, kind))
    return "\n".join(lines)


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Snapshot GitHub release asset download counts into a CSV."
    )
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY") or DEFAULT_REPO,
        help="owner/name to read releases from (default: %(default)s)",
    )
    parser.add_argument(
        "--csv",
        default=DEFAULT_CSV,
        help="CSV to append to, created if absent (default: %(default)s)",
    )
    parser.add_argument(
        "--captured-at",
        default=None,
        help="snapshot date as YYYY-MM-DD (default: today, UTC)",
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="record every asset, not only those whose count changed",
    )
    return parser.parse_args(argv)


def main(argv=None, opener=urllib.request.urlopen):
    args = parse_args(argv)
    captured_at = args.captured_at or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    token = os.environ.get("GITHUB_TOKEN") or None

    try:
        releases = fetch_releases(args.repo, token=token, opener=opener)
    except (urllib.error.URLError, ValueError, json.JSONDecodeError) as error:
        print(
            "error: could not read releases for {0}: {1}".format(args.repo, error),
            file=sys.stderr,
        )
        return 1

    rows = snapshot_rows(releases, captured_at)
    if not rows:
        # Refusing here is what stops an outage, a revoked token or a repo
        # rename from blanking history that cannot be re-fetched.
        print(
            "error: {0} reported no release assets; refusing to write an empty "
            "snapshot over the recorded history".format(args.repo),
            file=sys.stderr,
        )
        return 1

    merged, additions = merge_snapshot(
        read_rows(args.csv), rows, captured_at, full=args.full
    )
    write_rows(args.csv, merged)
    print(summarize(rows, additions, captured_at, args.csv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
