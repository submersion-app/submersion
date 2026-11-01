#!/usr/bin/env python3
"""Unit tests for snapshot_downloads.py."""

import importlib.util
import os
import unittest
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "snapshot_downloads",
    os.path.join(_HERE, "snapshot_downloads.py"),
)
mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mod)

NOW = datetime(2026, 11, 1, 4, 17, tzinfo=timezone.utc)


def asset(name, count):
    return {"name": name, "download_count": count}


def release(tag, published_at, assets, draft=False, prerelease=False):
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "published_at": published_at,
        "assets": assets,
    }


def stable_assets(macos_count):
    return [
        asset("Submersion-v1.8.3.9095-macOS.dmg", macos_count),
        asset("Submersion-v1.8.3.9095-Windows-Setup.exe", 50),
        asset("Submersion-v1.8.3.9095-Android.apk", 40),
        asset("Submersion-v1.8.3.9095-Linux.tar.gz", 20),
        asset("Submersion-v1.8.3.9095-Linux.deb", 3),
        asset("Submersion-v1.8.3.9095-Linux.rpm", 2),
        asset("appcast.xml", 999),
        asset("Submersion-v1.8.3.9095-Android.aab", 7),
        asset("Submersion-v1.8.3.9095-iOS.ipa", 7),
        asset("checksums-sha256.txt", 5),
        asset("release-notes.html", 4),
    ]


def releases_with(macos_count):
    return [
        release("v1.8.3.9095", "2026-10-26T00:00:00Z", stable_assets(macos_count)),
        release(
            "v1.6.1-beta.116",
            "2026-07-10T00:00:00Z",
            [asset("Submersion-v1.6.1-beta.116-macOS.dmg", 10)],
            prerelease=True,
        ),
        release(
            "v9.9.9.1", None, [asset("Submersion-v9.9.9.1-macOS.dmg", 500)], draft=True
        ),
        release(
            "demo-data",
            "2026-10-27T00:00:00Z",
            [asset("submersion-demo-s327.zip", 11), asset("demo-manifest.json", 90)],
        ),
    ]


RELEASES = releases_with(100)
BIGGER_RELEASES = releases_with(300)


class ClassifyTest(unittest.TestCase):
    def test_platform_suffixes(self):
        self.assertEqual(mod.classify_asset("Submersion-v1-macOS.DMG"), "macos")
        self.assertEqual(mod.classify_asset("x-Windows-Setup.exe"), "windows")
        self.assertEqual(mod.classify_asset("x-Android.apk"), "android")
        for name in ("x-Linux.tar.gz", "x.deb", "x.rpm"):
            self.assertEqual(mod.classify_asset(name), "linux")

    def test_excluded_files(self):
        for name in (
            "appcast.xml",
            "x.aab",
            "x.ipa",
            "checksums-sha256.txt",
            "release-notes.html",
            "demo.zip",
            "manifest.json",
            "notes.gz",
        ):
            self.assertIsNone(mod.classify_asset(name))


class SnapshotTest(unittest.TestCase):
    def setUp(self):
        self.snapshot = mod.build_snapshot(RELEASES, NOW)

    def test_drafts_are_removed(self):
        self.assertNotIn("v9.9.9.1", [r["tag"] for r in self.snapshot["releases"]])

    def test_every_other_file_is_kept(self):
        latest = self.snapshot["releases"][0]
        self.assertIn({"name": "appcast.xml", "downloads": 999}, latest["assets"])

    def test_dates_are_utc(self):
        self.assertEqual(self.snapshot["date"], "2026-11-01")
        self.assertEqual(self.snapshot["captured_at"], "2026-11-01T04:17:00Z")

    def test_totals_count_installers_and_prereleases_only(self):
        self.assertEqual(
            mod.totals_for(self.snapshot),
            {
                "total": 225,
                "platforms": {"macos": 110, "android": 40, "windows": 50, "linux": 25},
            },
        )


class SummaryTest(unittest.TestCase):
    def test_recent_releases_skip_prereleases_and_uncounted(self):
        recent = mod.recent_releases(mod.build_snapshot(RELEASES, NOW))
        self.assertEqual([r["tag"] for r in recent], ["v1.8.3.9095"])
        self.assertEqual(recent[0]["downloads"], 215)
        self.assertEqual(recent[0]["published_at"], "2026-10-26T00:00:00Z")

    def test_recent_releases_keep_newest_four(self):
        releases = [
            release(f"v1.{day}", f"2026-10-0{day}T00:00:00Z", [asset("x.dmg", 1)])
            for day in (3, 6, 1, 5, 2, 4)
        ]
        recent = mod.recent_releases(mod.build_snapshot(releases, NOW))
        self.assertEqual([r["tag"] for r in recent], ["v1.6", "v1.5", "v1.4", "v1.3"])

    def test_summary_shape_and_history_order(self):
        first = mod.build_snapshot(RELEASES, NOW)
        second = mod.build_snapshot(
            BIGGER_RELEASES, datetime(2026, 11, 2, 4, 17, tzinfo=timezone.utc)
        )
        summary = mod.build_summary([first, second])
        self.assertEqual(
            sorted(summary),
            [
                "generated_at",
                "history",
                "platforms",
                "recent_releases",
                "schema",
                "total",
            ],
        )
        self.assertEqual(summary["schema"], 1)
        self.assertEqual(summary["generated_at"], "2026-11-02T04:17:00Z")
        self.assertEqual(
            [h["date"] for h in summary["history"]], ["2026-11-01", "2026-11-02"]
        )
        self.assertEqual(summary["total"], summary["history"][-1]["total"])
        self.assertEqual(summary["history"][0]["total"], 225)
        self.assertEqual(summary["total"], 425)

    def test_new_installer_type_is_reported(self):
        releases = [dict(RELEASES[0], assets=[asset("x-macOS.pkg", 1)])]
        self.assertEqual(
            mod.unclassified_assets(mod.build_snapshot(releases, NOW)),
            ["x-macOS.pkg"],
        )

    def test_known_excluded_files_are_not_reported(self):
        self.assertEqual(mod.unclassified_assets(mod.build_snapshot(RELEASES, NOW)), [])


if __name__ == "__main__":
    unittest.main()
