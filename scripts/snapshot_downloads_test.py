#!/usr/bin/env python3
"""Unit tests for snapshot_downloads.py."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

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


class FetchTest(unittest.TestCase):
    def test_reads_every_page(self):
        pages = {1: [{"id": i} for i in range(100)], 2: [{"id": 100}]}
        asked = []

        def get_page(number):
            asked.append(number)
            return pages[number]

        self.assertEqual(len(mod.fetch_all_releases(get_page)), 101)
        self.assertEqual(asked, [1, 2])

    def test_exactly_full_last_page_stops_on_the_empty_one(self):
        pages = {1: [{"id": i} for i in range(100)], 2: []}
        self.assertEqual(len(mod.fetch_all_releases(pages.__getitem__)), 100)

    def test_error_propagates(self):
        def get_page(_):
            raise urllib.error.URLError("down")

        with self.assertRaises(urllib.error.URLError):
            mod.fetch_all_releases(get_page)


class GitHubPageTest(unittest.TestCase):
    def test_request_is_authenticated_and_paged(self):
        response = io.BytesIO(b"[]")
        with mock.patch("urllib.request.urlopen", return_value=response) as urlopen:
            self.assertEqual(mod.github_get_page("o/r", "tok", 3), [])
        request = urlopen.call_args.args[0]
        self.assertIn("/repos/o/r/releases?per_page=100&page=3", request.full_url)
        self.assertEqual(request.get_header("Authorization"), "Bearer tok")


class WorkspaceTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def summary(self):
        return json.loads((self.root / "downloads/summary.json").read_text())


class OutputTest(WorkspaceTest):
    def test_writes_snapshot_summary_and_readme(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        self.assertTrue((self.root / "downloads/2026/11/2026-11-01.json").is_file())
        self.assertEqual(self.summary()["total"], 225)
        self.assertTrue((self.root / "README.md").is_file())

    def test_existing_readme_is_left_alone(self):
        (self.root / "README.md").write_text("kept")
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        self.assertEqual((self.root / "README.md").read_text(), "kept")

    def test_same_day_rerun_overwrites(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        mod.write_outputs(self.root, mod.build_snapshot(BIGGER_RELEASES, NOW))
        summary = self.summary()
        self.assertEqual(len(summary["history"]), 1)
        self.assertEqual(summary["history"][0]["total"], 425)
        self.assertEqual(summary["total"], 425)

    def test_history_is_rebuilt_from_files(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        day_one = self.root / "downloads/2026/11/2026-11-01.json"
        edited = json.loads(day_one.read_text())
        edited["releases"][0]["assets"][0]["downloads"] = 101
        day_one.write_text(json.dumps(edited))
        later = datetime(2026, 11, 2, 4, 17, tzinfo=timezone.utc)
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, later))
        self.assertEqual(self.summary()["history"][0]["total"], 226)

    def test_gap_in_days_leaves_no_entry(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        later = datetime(2026, 11, 4, 4, 17, tzinfo=timezone.utc)
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, later))
        self.assertEqual(
            [h["date"] for h in self.summary()["history"]],
            ["2026-11-01", "2026-11-04"],
        )

    def test_snapshots_load_across_months_in_date_order(self):
        october = datetime(2026, 10, 31, 4, 17, tzinfo=timezone.utc)
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, october))
        self.assertEqual(
            [s["date"] for s in mod.load_snapshots(self.root)],
            ["2026-10-31", "2026-11-01"],
        )

    def test_falling_total_warns_and_still_publishes(self):
        mod.write_outputs(self.root, mod.build_snapshot(BIGGER_RELEASES, NOW))
        later = datetime(2026, 11, 2, 4, 17, tzinfo=timezone.utc)
        warnings = mod.write_outputs(self.root, mod.build_snapshot(RELEASES, later))
        self.assertTrue(any("fell from 425 to 225" in w for w in warnings), warnings)
        self.assertEqual(self.summary()["total"], 225)

    def test_same_day_correction_downward_does_not_warn(self):
        mod.write_outputs(self.root, mod.build_snapshot(BIGGER_RELEASES, NOW))
        warnings = mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        self.assertEqual(warnings, [])


class MainTest(WorkspaceTest):
    def run_main(self, get_page):
        stdout = io.StringIO()
        with mock.patch.dict(os.environ, {"GH_TOKEN": "tok"}):
            with contextlib.redirect_stdout(stdout):
                code = mod.main(
                    ["--repo", "o/r", "--out", str(self.root)],
                    get_page=get_page,
                    now=NOW,
                )
        return code, stdout.getvalue()

    def assert_nothing_written(self):
        self.assertEqual(list(self.root.iterdir()), [])

    def test_success_writes_files(self):
        code, _ = self.run_main(lambda page: RELEASES if page == 1 else [])
        self.assertEqual(code, 0)
        self.assertEqual(self.summary()["total"], 225)

    def test_failed_fetch_writes_nothing(self):
        def get_page(_):
            raise urllib.error.URLError("down")

        code, output = self.run_main(get_page)
        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        self.assert_nothing_written()

    def test_malformed_response_writes_nothing(self):
        code, output = self.run_main(lambda _: [{"tag_name": "v1"}])
        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        self.assert_nothing_written()

    def test_no_releases_writes_nothing(self):
        code, _ = self.run_main(lambda _: [])
        self.assertEqual(code, 1)
        self.assert_nothing_written()

    def test_no_counted_files_writes_nothing(self):
        code, _ = self.run_main(lambda _: [RELEASES[3]])
        self.assertEqual(code, 1)
        self.assert_nothing_written()

    def test_missing_token_writes_nothing(self):
        stdout = io.StringIO()
        with mock.patch.dict(os.environ, {}, clear=True):
            with contextlib.redirect_stdout(stdout):
                code = mod.main(
                    ["--repo", "o/r", "--out", str(self.root)],
                    get_page=lambda _: RELEASES,
                    now=NOW,
                )
        self.assertEqual(code, 1)
        self.assertIn("GH_TOKEN", stdout.getvalue())
        self.assert_nothing_written()

    def test_new_installer_type_prints_a_workflow_warning(self):
        releases = [
            release(
                "v1",
                "2026-10-26T00:00:00Z",
                [asset("x-macOS.dmg", 1), asset("x-macOS.pkg", 1)],
            )
        ]
        code, output = self.run_main(lambda _: releases)
        self.assertEqual(code, 0)
        self.assertIn("::warning::", output)
        self.assertIn("x-macOS.pkg", output)


if __name__ == "__main__":
    unittest.main()
