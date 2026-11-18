#!/usr/bin/env python3
"""Unit tests for fetch_training.py's pure helpers (issue #4724)."""

import importlib.util
import os
import sys
import unittest

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


if __name__ == "__main__":
    unittest.main()
