#!/usr/bin/env python3
"""Unit tests for fetch_training.py's pure helpers (issue #4724)."""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
import urllib.error
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("fetch_training", os.path.join(_HERE, "fetch_training.py"))
fetch_training = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fetch_training)


def detection(w, h):
    return {"pixelWidth": w, "pixelHeight": h, "embedding": [1.0, 0.0]}


class LabelledCropTest(unittest.TestCase):
    def test_labelled_crop_skips_small_and_empty(self):
        self.assertIsNone(fetch_training.labelled_crop({"path": "a", "detections": []}, 64))
        self.assertIsNone(fetch_training.labelled_crop({"path": "a", "error": "unreadable"}, 64))
        self.assertIsNone(fetch_training.labelled_crop({"path": "a", "detections": [detection(200, 63)]}, 64))
        big, small = detection(64, 300), detection(100, 100)
        self.assertIs(fetch_training.labelled_crop({"path": "a", "detections": [small, big]}, 64), big)

    def test_a_small_largest_box_is_not_replaced_by_a_smaller_one(self):
        # The largest box is the labelled animal; when it is too small the
        # photo is skipped rather than naming another animal in it.
        result = {"path": "a", "detections": [detection(1000, 60), detection(70, 70)]}
        self.assertIsNone(fetch_training.labelled_crop(result, 64))


class BatchTest(unittest.TestCase):
    def test_batches_are_stable_and_complete(self):
        records = [{"id": str(i)} for i in (5, 1, 12, 3, 40)]
        batches = fetch_training.batch_of(records, size=2)
        self.assertEqual([[r["id"] for r in b] for b in batches], [["1", "3"], ["5", "12"], ["40"]])
        self.assertEqual(batches, fetch_training.batch_of(list(reversed(records)), size=2))


class AssignTest(unittest.TestCase):
    def test_a_name_resolving_to_another_candidate_counts_for_that_one(self):
        index = {11: 0, 22: 1}
        self.assertEqual(fetch_training.candidate_for(22, index), 1)
        self.assertIsNone(fetch_training.candidate_for(None, index))
        self.assertIsNone(fetch_training.candidate_for(33, index))


class NextDayTest(unittest.TestCase):
    def test_seconds_until_next_utc_day(self):
        import datetime

        utc = datetime.timezone.utc
        late = datetime.datetime(2026, 11, 19, 23, 0, tzinfo=utc)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(late), 3600 + 60)
        sydney = datetime.timezone(datetime.timedelta(hours=11))
        same_instant = datetime.datetime(2026, 11, 20, 10, 0, tzinfo=sydney)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(same_instant), 3600 + 60)
        midnight = datetime.datetime(2026, 11, 20, 0, 0, tzinfo=utc)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(midnight), 86400 + 60)


class UntilDoneTest(unittest.TestCase):
    def test_waits_a_day_between_runs_until_the_stage_finishes(self):
        outcomes = [False, False, True]
        with mock.patch.object(fetch_training.time, "sleep") as sleep:
            self.assertTrue(fetch_training._until_done(lambda: outcomes.pop(0), True))
        self.assertEqual(sleep.call_count, 2)
        self.assertTrue(all(0 < c.args[0] <= 86400 + 60 for c in sleep.call_args_list))
        self.assertEqual(outcomes, [])

    def test_without_wait_it_stops_at_the_first_limit(self):
        calls = []
        with mock.patch.object(fetch_training.time, "sleep") as sleep:
            self.assertFalse(fetch_training._until_done(lambda: calls.append(1) or False, False))
        self.assertEqual(calls, [1])
        sleep.assert_not_called()


class _Budget:
    def __init__(self, limit):
        self.limit, self.spent = limit, 0

    def exhausted(self):
        return self.spent >= self.limit

    def spend(self, amount):
        self.spent += amount


def _write_100_bytes(url, path):
    with open(path, "wb") as fh:
        fh.write(b"x" * 100)


class DownloadBatchTest(unittest.TestCase):
    def batch(self, folder, count=10):
        records = [{"id": str(i), "photo_url": f"https://x/{i}/large.jpg"} for i in range(count)]
        return records, {r["id"]: os.path.join(folder, f"{r['id']}.jpg") for r in records}

    def test_stops_photo_by_photo_at_the_limit_and_charges_each_photo_once(self):
        with tempfile.TemporaryDirectory() as folder:
            records, paths = self.batch(folder)
            today = _Budget(300)
            outcome = fetch_training.download_batch(records, paths, today, _write_100_bytes, workers=1)
            self.assertEqual(outcome, fetch_training.LIMIT)
            self.assertEqual(today.spent, 300)
            self.assertEqual(sum(os.path.exists(p) for p in paths.values()), 3)
            tomorrow = _Budget(10_000)
            outcome = fetch_training.download_batch(records, paths, tomorrow, _write_100_bytes, workers=1)
            self.assertEqual(outcome, fetch_training.DONE)
            self.assertEqual(tomorrow.spent, 700)

    def test_photos_from_the_open_data_bucket_are_not_capped(self):
        with tempfile.TemporaryDirectory() as folder:
            records = [
                {"id": str(i), "photo_url": f"https://inaturalist-open-data.s3.amazonaws.com/photos/{i}/large.jpg"}
                for i in range(5)
            ]
            paths = {r["id"]: os.path.join(folder, f"{r['id']}.jpg") for r in records}
            spent = _Budget(0)
            outcome = fetch_training.download_batch(records, paths, spent, _write_100_bytes, workers=1)
            self.assertEqual(outcome, fetch_training.DONE)
            self.assertEqual(spent.spent, 0)
            self.assertEqual(sum(os.path.exists(p) for p in paths.values()), 5)

    def test_only_the_open_data_bucket_itself_is_uncapped(self):
        self.assertTrue(fetch_training.uncapped("https://inaturalist-open-data.s3.amazonaws.com/photos/1/large.jpg"))
        for url in (
            "https://static.inaturalist.org/photos/1/large.jpg",
            "https://inaturalist-open-data.s3.amazonaws.com.example.com/photos/1/large.jpg",
            "http://inaturalist-open-data.s3.amazonaws.com/photos/1/large.jpg",
        ):
            with self.subTest(url=url):
                self.assertFalse(fetch_training.uncapped(url))

    def failing_on_photo_1(self, error):
        def download(url, path):
            if "/1/" in url:
                raise error
            _write_100_bytes(url, path)

        return download

    def test_a_photo_gone_from_the_bucket_is_skipped_not_fatal(self):
        gone = urllib.error.HTTPError("https://x/1/large.jpg", 404, "Not Found", None, None)
        with tempfile.TemporaryDirectory() as folder:
            records, paths = self.batch(folder, count=3)
            budget = _Budget(10_000)
            with mock.patch("builtins.print"):
                outcome = fetch_training.download_batch(records, paths, budget, self.failing_on_photo_1(gone), workers=1)
            self.assertEqual(outcome, fetch_training.DONE)
            self.assertEqual(budget.spent, 200)
            self.assertFalse(os.path.exists(paths["1"]))

    def test_a_failure_that_may_pass_leaves_the_batch_for_a_later_run(self):
        busy = urllib.error.HTTPError("https://x/1/large.jpg", 503, "Busy", None, None)
        for error in (urllib.error.URLError("no route"), TimeoutError(), ConnectionResetError(), busy):
            with self.subTest(error=error), tempfile.TemporaryDirectory() as folder:
                records, paths = self.batch(folder, count=3)
                budget = _Budget(10_000)
                with mock.patch("builtins.print"):
                    outcome = fetch_training.download_batch(
                        records, paths, budget, self.failing_on_photo_1(error), workers=1
                    )
                self.assertEqual(outcome, fetch_training.RETRY)
                self.assertEqual(budget.spent, 200, "the photos that did download are charged")
                self.assertFalse(os.path.exists(paths["1"]))

    def test_an_unexpected_error_is_not_swallowed(self):
        with tempfile.TemporaryDirectory() as folder:
            records, paths = self.batch(folder, count=3)
            with self.assertRaises(KeyError):
                fetch_training.download_batch(
                    records, paths, _Budget(10_000), self.failing_on_photo_1(KeyError("bug")), workers=1
                )


class _Response:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def read(self):
        return self.body


class RequestBudgetTest(unittest.TestCase):
    def test_every_attempt_at_a_list_counts_against_the_day(self):
        busy = urllib.error.HTTPError("https://api.inaturalist.org", 503, "Busy", None, None)
        answers = [busy, busy, _Response(b'{"results": []}')]

        def urlopen(request, timeout):
            answer = answers.pop(0)
            if isinstance(answer, Exception):
                raise answer
            return answer

        with tempfile.TemporaryDirectory() as root:
            pack, work = os.path.join(root, "pack"), os.path.join(root, "work")
            os.makedirs(pack)
            with open(os.path.join(pack, "candidates.json"), "w", encoding="utf-8") as fh:
                json.dump([{"gbifKey": 1, "scientificName": "Scarus vetula"}], fh)
            with mock.patch("urllib.request.urlopen", urlopen), mock.patch("time.sleep"):
                self.assertTrue(fetch_training.stage_lists(work, pack))
            with open(os.path.join(work, "requests.json"), encoding="utf-8") as fh:
                self.assertEqual(list(json.load(fh).values()), [3])

    def test_a_retry_stops_at_the_day_s_limit_and_leaves_the_list_for_tomorrow(self):
        busy = urllib.error.HTTPError("https://api.inaturalist.org", 503, "Busy", None, None)
        sent = []

        def urlopen(request, timeout):
            sent.append(request)
            raise busy

        with tempfile.TemporaryDirectory() as root:
            pack, work = os.path.join(root, "pack"), os.path.join(root, "work")
            os.makedirs(pack)
            with open(os.path.join(pack, "candidates.json"), "w", encoding="utf-8") as fh:
                json.dump([{"gbifKey": 1, "scientificName": "Scarus vetula"}], fh)
            with (
                mock.patch.object(fetch_training, "DAILY_REQUESTS", 2),
                mock.patch("urllib.request.urlopen", urlopen),
                mock.patch("time.sleep"),
                mock.patch("builtins.print"),
            ):
                self.assertFalse(fetch_training.stage_lists(work, pack))
            self.assertEqual(len(sent), 2)
            with open(os.path.join(work, "requests.json"), encoding="utf-8") as fh:
                self.assertEqual(list(json.load(fh).values()), [2])
            self.assertFalse(os.path.exists(os.path.join(work, "lists", "1.json")))


try:
    import numpy  # noqa: F401

    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False


@unittest.skipUnless(HAVE_NUMPY, "needs numpy")
class EmbeddingArrayTest(unittest.TestCase):
    def test_a_batch_that_kept_nothing_saves_an_empty_array(self):
        self.assertEqual(fetch_training.embedding_array([]).shape, (0, 0))
        self.assertEqual(fetch_training.embedding_array([[1.0, 0.0], [0.0, 1.0]]).shape, (2, 2))


if __name__ == "__main__":
    unittest.main()
