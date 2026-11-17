#!/usr/bin/env python3
"""Unit tests for boxes.py: merging two detectors' boxes."""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("boxes", os.path.join(_HERE, "boxes.py"))
boxes = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(boxes)


def b(x, y, w, h, score, source="a"):
    return {"x": x, "y": y, "w": w, "h": h, "score": score, "source": source}


class IouTests(unittest.TestCase):
    def test_identical_boxes(self):
        self.assertAlmostEqual(boxes.iou((0.1, 0.1, 0.2, 0.2), (0.1, 0.1, 0.2, 0.2)), 1.0, places=12)

    def test_disjoint_boxes(self):
        self.assertEqual(boxes.iou((0.0, 0.0, 0.1, 0.1), (0.5, 0.5, 0.1, 0.1)), 0.0)

    def test_half_overlap(self):
        # Overlap 0.1 x 0.2 of two 0.2 x 0.2 boxes: 0.02 / (0.04 + 0.04 - 0.02).
        self.assertAlmostEqual(boxes.iou((0.0, 0.0, 0.2, 0.2), (0.1, 0.0, 0.2, 0.2)), 1 / 3, places=12)

    def test_empty_boxes_do_not_divide_by_zero(self):
        self.assertEqual(boxes.iou((0.1, 0.1, 0.0, 0.0), (0.1, 0.1, 0.0, 0.0)), 0.0)


class MergeTests(unittest.TestCase):
    def test_keeps_the_higher_of_two_overlapping_boxes(self):
        merged = boxes.merge([[b(0.1, 0.1, 0.3, 0.3, 0.6, "a")], [b(0.11, 0.1, 0.3, 0.3, 0.9, "b")]])
        self.assertEqual([m["source"] for m in merged], ["b"])

    def test_keeps_both_when_they_do_not_overlap(self):
        merged = boxes.merge([[b(0.0, 0.0, 0.2, 0.2, 0.6, "a")], [b(0.5, 0.5, 0.2, 0.2, 0.9, "b")]])
        self.assertEqual([m["source"] for m in merged], ["b", "a"])

    def test_overlap_below_the_threshold_keeps_both(self):
        merged = boxes.merge([[b(0.0, 0.0, 0.2, 0.2, 0.6, "a")], [b(0.1, 0.0, 0.2, 0.2, 0.9, "b")]])
        self.assertEqual(len(merged), 2)

    def test_stops_at_max_boxes(self):
        run = [b(i / 10, 0.0, 0.05, 0.05, 1 - i / 100) for i in range(10)]
        self.assertEqual(len(boxes.merge([run], max_boxes=8)), 8)

    def test_extra_fields_ride_along(self):
        box = dict(b(0.0, 0.0, 0.2, 0.2, 0.6), embedding=[1.0])
        self.assertEqual(boxes.merge([[box]])[0]["embedding"], [1.0])


class BestMatchTests(unittest.TestCase):
    def test_the_box_that_overlaps_most_above_the_floor(self):
        target = (0.1, 0.1, 0.2, 0.2)
        found = [(0.5, 0.5, 0.1, 0.1), (0.1, 0.1, 0.2, 0.21), (0.1, 0.1, 0.2, 0.2)]
        self.assertEqual(boxes.best_match(target, found), 2)

    def test_none_when_nothing_overlaps_enough(self):
        self.assertIsNone(boxes.best_match((0.1, 0.1, 0.2, 0.2), [(0.15, 0.1, 0.2, 0.2)]))
        self.assertIsNone(boxes.best_match((0.1, 0.1, 0.2, 0.2), []))


if __name__ == "__main__":
    unittest.main()
