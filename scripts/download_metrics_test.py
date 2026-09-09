#!/usr/bin/env python3
"""Unit tests for download_metrics.py.

Run: python3 scripts/download_metrics_test.py

The regressions these guard:

  * The releases API reports `download_count` as a single lifetime integer with
    no history, so the CSV this script appends to is the only record that will
    ever exist. A bug that rewrites or truncates it destroys data that cannot
    be re-fetched, which is why write_rows is only ever handed a merge result
    and why an empty API response is refused rather than written.
  * A daily job that appends every asset unconditionally would add ~560 rows a
    day and grow without bound. Rows are therefore recorded only when a count
    changes, which makes the "unchanged asset is skipped" and "changed asset is
    appended" cases load-bearing rather than cosmetic.
  * Re-running on the same day (a manual dispatch after a failed schedule) must
    replace that day's rows, not double them.
"""

import importlib.util
import io
import json
import os
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "download_metrics.py")
spec = importlib.util.spec_from_file_location("download_metrics", SCRIPT)
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


def release(
    tag, assets, published_at="2026-09-06T15:48:51Z", prerelease=False, draft=False
):
    return {
        "tag_name": tag,
        "published_at": published_at,
        "prerelease": prerelease,
        "draft": draft,
        "assets": [
            {"name": name, "download_count": count, "size": size}
            for name, count, size in assets
        ],
    }


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        self.close()
        return False


def opener_for(pages):
    """Return a urlopen stand-in serving `pages` in order, recording requests."""
    calls = []

    def opener(request, timeout=None):
        calls.append(request)
        index = len(calls) - 1
        payload = pages[index] if index < len(pages) else []
        return FakeResponse(json.dumps(payload).encode("utf-8"))

    opener.calls = calls
    return opener


class ClassifyAssetTest(unittest.TestCase):
    def test_classifies_each_shipped_platform(self):
        cases = {
            "Submersion-v1.7.7.8077-macOS.dmg": "macos-dmg",
            "Submersion-v1.7.7.8077-Windows-Setup.exe": "windows-setup",
            "Submersion-v1.7.7.8077-Android.apk": "android-apk",
            "Submersion-v1.7.7.8077-Android.aab": "android-aab",
            "Submersion-v1.7.7.8077-iOS.ipa": "ios-ipa",
            "Submersion-v1.7.7.8077-Linux-amd64.deb": "linux-deb",
            "Submersion-v1.7.7.8077-Linux-x86_64.rpm": "linux-rpm",
            "Submersion-v1.7.7.8077-Linux.tar.gz": "linux-tarball",
        }
        for name, expected in cases.items():
            self.assertEqual(metrics.classify_asset(name), expected, name)

    def test_updater_feed_is_not_an_installer(self):
        # appcast.xml is over half of all recorded downloads because Sparkle
        # polls it for update checks. Counting it as an install would inflate
        # the headline number by roughly 2x.
        self.assertEqual(metrics.classify_asset("appcast.xml"), "updater-feed")
        self.assertNotIn("updater-feed", metrics.INSTALLER_KINDS)

    def test_release_metadata_is_not_an_installer(self):
        for name in ("checksums-sha256.txt", "release-notes.html"):
            self.assertNotIn(metrics.classify_asset(name), metrics.INSTALLER_KINDS)

    def test_every_installer_kind_is_reachable(self):
        # A kind listed in INSTALLER_KINDS that classify_asset can never return
        # is a silent typo: the installer total would quietly omit a platform.
        produced = {kind for _suffix, kind in metrics._KIND_BY_SUFFIX}
        self.assertTrue(metrics.INSTALLER_KINDS.issubset(produced))

    def test_unknown_extension_falls_back_to_other(self):
        self.assertEqual(metrics.classify_asset("something.wat"), "other")


class SnapshotRowsTest(unittest.TestCase):
    def test_flattens_assets_with_the_capture_date(self):
        rows = metrics.snapshot_rows(
            [release("v1.0.0", [("Submersion-v1.0.0-macOS.dmg", 365, 79688510)])],
            "2026-09-09",
        )
        self.assertEqual(len(rows), 1)
        self.assertEqual(
            rows[0],
            {
                "captured_at": "2026-09-09",
                "tag_name": "v1.0.0",
                "published_at": "2026-09-06T15:48:51Z",
                "prerelease": "false",
                "asset_name": "Submersion-v1.0.0-macOS.dmg",
                "asset_kind": "macos-dmg",
                "download_count": "365",
                "size_bytes": "79688510",
            },
        )

    def test_skips_draft_releases(self):
        rows = metrics.snapshot_rows(
            [release("v1.0.0", [("a.dmg", 1, 2)], draft=True)], "2026-09-09"
        )
        self.assertEqual(rows, [])

    def test_records_prerelease_flag(self):
        rows = metrics.snapshot_rows(
            [release("v1.0.0-beta", [("a.dmg", 1, 2)], prerelease=True)], "2026-09-09"
        )
        self.assertEqual(rows[0]["prerelease"], "true")

    def test_is_ordered_deterministically(self):
        # Row order decides the diff the daily commit produces. An unstable
        # order would churn the whole file every day.
        rows = metrics.snapshot_rows(
            [
                release(
                    "v2",
                    [("b.dmg", 1, 1), ("a.dmg", 1, 1)],
                    published_at="2026-02-01T00:00:00Z",
                ),
                release("v1", [("c.dmg", 1, 1)], published_at="2026-01-01T00:00:00Z"),
            ],
            "2026-09-09",
        )
        self.assertEqual(
            [(r["tag_name"], r["asset_name"]) for r in rows],
            [("v1", "c.dmg"), ("v2", "a.dmg"), ("v2", "b.dmg")],
        )

    def test_tolerates_missing_fields(self):
        rows = metrics.snapshot_rows(
            [{"tag_name": "v1", "assets": [{"name": "a.dmg"}]}], "2026-09-09"
        )
        self.assertEqual(rows[0]["download_count"], "0")
        self.assertEqual(rows[0]["published_at"], "")


class FetchReleasesTest(unittest.TestCase):
    def test_follows_pagination_until_a_short_page(self):
        full_page = [
            release("v%d" % i, [("a.dmg", i, 1)]) for i in range(metrics.PER_PAGE)
        ]
        opener = opener_for([full_page, [release("vlast", [("a.dmg", 1, 1)])]])
        releases = metrics.fetch_releases("owner/repo", opener=opener)
        self.assertEqual(len(releases), metrics.PER_PAGE + 1)
        self.assertEqual(len(opener.calls), 2)
        self.assertIn("page=1", opener.calls[0].full_url)
        self.assertIn("page=2", opener.calls[1].full_url)

    def test_stops_on_an_empty_page(self):
        opener = opener_for([[]])
        self.assertEqual(metrics.fetch_releases("owner/repo", opener=opener), [])
        self.assertEqual(len(opener.calls), 1)

    def test_sends_the_token_when_one_is_available(self):
        opener = opener_for([[]])
        metrics.fetch_releases("owner/repo", token="secret", opener=opener)
        self.assertEqual(opener.calls[0].get_header("Authorization"), "Bearer secret")

    def test_omits_authorization_without_a_token(self):
        opener = opener_for([[]])
        metrics.fetch_releases("owner/repo", token=None, opener=opener)
        self.assertIsNone(opener.calls[0].get_header("Authorization"))

    def test_rejects_a_non_list_payload(self):
        # A 404 body is a JSON object. Treating it as a page of releases would
        # produce an empty snapshot instead of an error.
        opener = opener_for([{"message": "Not Found"}])
        with self.assertRaises(ValueError):
            metrics.fetch_releases("owner/repo", opener=opener)


class MergeSnapshotTest(unittest.TestCase):
    def row(self, captured_at, tag, asset, count):
        return {
            "captured_at": captured_at,
            "tag_name": tag,
            "published_at": "2026-01-01T00:00:00Z",
            "prerelease": "false",
            "asset_name": asset,
            "asset_kind": "macos-dmg",
            "download_count": str(count),
            "size_bytes": "1",
        }

    def test_first_run_records_everything(self):
        new = [self.row("2026-09-09", "v1", "a.dmg", 10)]
        merged, additions = metrics.merge_snapshot([], new, "2026-09-09")
        self.assertEqual(merged, new)
        self.assertEqual(additions, new)

    def test_unchanged_counts_are_not_recorded_again(self):
        existing = [self.row("2026-09-08", "v1", "a.dmg", 10)]
        new = [self.row("2026-09-09", "v1", "a.dmg", 10)]
        merged, additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertEqual(additions, [])
        self.assertEqual(merged, existing)

    def test_changed_counts_are_appended(self):
        existing = [self.row("2026-09-08", "v1", "a.dmg", 10)]
        new = [self.row("2026-09-09", "v1", "a.dmg", 12)]
        merged, additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertEqual(additions, new)
        self.assertEqual(merged, existing + new)

    def test_compares_against_the_most_recent_value_not_the_oldest(self):
        existing = [
            self.row("2026-09-01", "v1", "a.dmg", 10),
            self.row("2026-09-08", "v1", "a.dmg", 12),
        ]
        new = [self.row("2026-09-09", "v1", "a.dmg", 12)]
        _merged, additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertEqual(additions, [])

    def test_rerunning_the_same_day_replaces_that_days_rows(self):
        existing = [
            self.row("2026-09-08", "v1", "a.dmg", 10),
            self.row("2026-09-09", "v1", "a.dmg", 12),
        ]
        new = [self.row("2026-09-09", "v1", "a.dmg", 13)]
        merged, additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertEqual(additions, new)
        self.assertEqual(merged, [existing[0]] + new)

    def test_full_records_every_asset_even_when_unchanged(self):
        existing = [self.row("2026-09-08", "v1", "a.dmg", 10)]
        new = [self.row("2026-09-09", "v1", "a.dmg", 10)]
        _merged, additions = metrics.merge_snapshot(
            existing, new, "2026-09-09", full=True
        )
        self.assertEqual(additions, new)

    def test_a_new_asset_on_an_existing_release_is_recorded(self):
        existing = [self.row("2026-09-08", "v1", "a.dmg", 10)]
        new = [
            self.row("2026-09-09", "v1", "a.dmg", 10),
            self.row("2026-09-09", "v1", "b.exe", 3),
        ]
        _merged, additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertEqual([r["asset_name"] for r in additions], ["b.exe"])

    def test_never_drops_rows_for_assets_missing_from_the_new_snapshot(self):
        # A deleted or renamed asset must not erase its recorded history.
        existing = [self.row("2026-09-08", "v0", "gone.dmg", 99)]
        new = [self.row("2026-09-09", "v1", "a.dmg", 1)]
        merged, _additions = metrics.merge_snapshot(existing, new, "2026-09-09")
        self.assertIn(existing[0], merged)


class CsvRoundTripTest(unittest.TestCase):
    def test_written_rows_read_back_identically(self):
        rows = metrics.snapshot_rows(
            [release("v1", [("Submersion-v1-macOS.dmg", 5, 10)])], "2026-09-09"
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "nested", "download_counts.csv")
            metrics.write_rows(path, rows)
            self.assertEqual(metrics.read_rows(path), rows)

    def test_missing_file_reads_as_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(metrics.read_rows(os.path.join(tmp, "absent.csv")), [])

    def test_header_matches_the_declared_field_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "download_counts.csv")
            metrics.write_rows(path, [])
            with open(path, encoding="utf-8") as handle:
                self.assertEqual(handle.readline().strip(), ",".join(metrics.FIELDS))


class MainTest(unittest.TestCase):
    def run_main(self, pages, path, extra=()):
        return metrics.main(
            ["--repo", "owner/repo", "--csv", path, *extra], opener=opener_for(pages)
        )

    def test_writes_a_snapshot_and_appends_on_the_next_day(self):
        pages = [[release("v1", [("Submersion-v1-macOS.dmg", 5, 10)])]]
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "download_counts.csv")
            self.assertEqual(
                self.run_main(pages, path, ["--captured-at", "2026-09-08"]), 0
            )
            self.assertEqual(len(metrics.read_rows(path)), 1)

            grown = [[release("v1", [("Submersion-v1-macOS.dmg", 9, 10)])]]
            self.assertEqual(
                self.run_main(grown, path, ["--captured-at", "2026-09-09"]), 0
            )
            rows = metrics.read_rows(path)
            self.assertEqual([r["download_count"] for r in rows], ["5", "9"])

    def test_refuses_to_write_when_the_api_reports_no_assets(self):
        # An outage or a revoked token must not blank the accumulated history.
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "download_counts.csv")
            metrics.write_rows(
                path,
                metrics.snapshot_rows(
                    [release("v1", [("a.dmg", 5, 10)])], "2026-09-08"
                ),
            )
            before = metrics.read_rows(path)
            self.assertEqual(
                self.run_main([[]], path, ["--captured-at", "2026-09-09"]), 1
            )
            self.assertEqual(metrics.read_rows(path), before)

    def test_reports_failure_when_the_api_payload_is_not_a_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "download_counts.csv")
            self.assertEqual(self.run_main([{"message": "Bad credentials"}], path), 1)
            self.assertFalse(os.path.exists(path))


class SummarizeTest(unittest.TestCase):
    def test_separates_installer_downloads_from_the_updater_feed(self):
        rows = metrics.snapshot_rows(
            [
                release(
                    "v1", [("Submersion-v1-macOS.dmg", 365, 1), ("appcast.xml", 474, 1)]
                )
            ],
            "2026-09-09",
        )
        summary = metrics.summarize(rows, rows, "2026-09-09", "download_counts.csv")
        self.assertIn("installer downloads:  365", summary)
        self.assertIn("all asset downloads:  839", summary)
        self.assertIn("updater-feed", summary)


if __name__ == "__main__":
    unittest.main()
