#!/usr/bin/env python3
"""Unit tests for score.py's measured entries (issue #4721): the figures
NAMING_MEASURED copies into manifest.py, from levels measured by
levels.py."""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

import bars  # noqa: E402
import levels  # noqa: E402
import score  # noqa: E402

NEVER = bars.NEVER
SURER = bars.Bars(min_open=0.5, suggest=0.80, suggest_no_location=0.80, confident=NEVER, confident_no_location=NEVER)
MANIFEST = {
    "naming": {"minCropSide": 64, "minAllowedCandidates": 200, "topK": 5},
    "classifier": {"id": "classifier"},
    "packVersion": "2026.11.18.0356",
    "files": [],
}


def crop(with_top, without_top, correct):
    return {
        "with": bars.Scored(open_score=0.6, top_score=with_top, correct=correct, shorter_side=100, limited=True),
        "without": bars.Scored(open_score=0.6, top_score=without_top, correct=correct, shorter_side=100, limited=False),
    }


def entry(fish):
    found, surer_precision, _ = levels.measure(SURER, fish, [], fish, [], min_side=64)
    evaluation = {
        "levels measured under": {"bars": SURER.__dict__, "published": True},
        "surer precision": surer_precision,
        "levels": found,
    }
    return score._measured_entry(evaluation, MANIFEST, ["detector"], "centreCrop")["naming"]


class MeasuredEntryTests(unittest.TestCase):
    def test_a_measured_entry_carries_the_shown_figures(self):
        # Balanced is right 170 of 200 times with a location and 170 of 205
        # without; Surer 100 of 100 times either way.
        fish = (
            [crop(0.9, 0.9, True)] * 100
            + [crop(0.55, 0.55, True)] * 70
            + [crop(0.55, 0.55, False)] * 30
            + [crop(0.3, 0.56, False)] * 5
        )
        naming = entry(fish)
        self.assertEqual(naming["precision"], 1.0)
        self.assertEqual([(level["id"], level["precision"]) for level in naming["levels"]], [("balanced", 0.829)])
        self.assertEqual((naming["suggestScore"], naming["suggestScoreNoLocation"]), (0.8, 0.8))

    def test_a_surer_with_no_share_to_show_carries_no_precision(self):
        naming = entry([crop(0.9, 0.9, False)] * 40)
        self.assertNotIn("precision", naming)
        self.assertEqual(naming["levels"], [])


if __name__ == "__main__":
    unittest.main()
