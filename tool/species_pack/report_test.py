#!/usr/bin/env python3
"""Unit tests for report.py's "Naming levels" section (issue #4721), from
levels measured by levels.py, so a renamed key fails here rather than
reading as "n/a"."""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

import bars  # noqa: E402
import levels  # noqa: E402
import report  # noqa: E402

NEVER = bars.NEVER
SURER = bars.Bars(min_open=0.5, suggest=0.80, suggest_no_location=0.80, confident=NEVER, confident_no_location=NEVER)
RUN = "both centreCrop"


def crop(with_top, without_top, correct):
    return {
        "with": bars.Scored(open_score=0.6, top_score=with_top, correct=correct, shorter_side=100, limited=True),
        "without": bars.Scored(open_score=0.6, top_score=without_top, correct=correct, shorter_side=100, limited=False),
    }


def evaluation(fish):
    """An evaluation as score.py stores one, measured on `fish` as both
    halves."""
    found, surer_precision, surer_held = levels.measure(SURER, fish, [], fish, [], min_side=64)
    return {
        "levels measured under": {"bars": SURER.__dict__, "published": True},
        "surer precision": surer_precision,
        "surer held-out": surer_held,
        "levels": found,
    }


# Balanced at 0.55: 170 of 200 right with a location, 170 of 205 without.
FISH = (
    [crop(0.9, 0.9, True)] * 100
    + [crop(0.55, 0.55, True)] * 70
    + [crop(0.55, 0.55, False)] * 30
    + [crop(0.3, 0.56, False)] * 5
)


def lines(e):
    return report.naming_levels_lines({"evaluations": {RUN: e}})


def cells(found, level):
    row = next(line for line in found if line.startswith(f"| {RUN} | {level} |"))
    return [cell.strip() for cell in row.strip().strip("|").split("|")]


class NamingLevelsTests(unittest.TestCase):
    def test_a_level_row_shows_both_sides_and_its_shown_figure(self):
        row = cells(lines(evaluation(FISH)), "balanced")
        self.assertTrue(row[5].startswith("85.0%"), row[5])
        self.assertTrue(row[6].startswith("82.9%"), row[6])
        self.assertTrue(row[7].startswith("97.6%"), row[7])
        self.assertTrue(row[8].startswith("100.0%"), row[8])
        self.assertEqual(row[9], "82.9%")

    def test_the_surer_row_shows_its_two_sides_and_what_the_manifest_carries(self):
        row = cells(lines(evaluation(FISH)), "surer")
        self.assertEqual(row[3:5], ["0.80", "0.80"])
        self.assertTrue(row[5].startswith("100.0%"), row[5])
        self.assertEqual(row[9], "100.0%")
        # A Surer right 0 times has no share to carry, so it shows none.
        unshown = evaluation([crop(0.9, 0.9, False)] * 40)
        self.assertEqual(cells(lines(unshown), "surer")[9], "n/a")

    def test_results_from_before_both_sides_still_render(self):
        e = evaluation(FISH)
        del e["surer held-out"]
        for level in e["levels"]:
            del level["precision"]
            del level["held-out"]["precision without location"]
            del level["held-out"]["coverage without location"]
        surer = cells(lines(e), "surer")
        self.assertEqual(surer[5:9], ["n/a"] * 4)
        balanced = cells(lines(e), "balanced")
        self.assertEqual([balanced[6], balanced[8], balanced[9]], ["n/a"] * 3)

    def test_a_shown_figure_set_by_a_small_side_is_flagged(self):
        # Surer is right every time with a location, and 1 of 3 times on
        # the few crops it names without one, which set its figure.
        small = [crop(0.9, 0.5, True)] * 98 + [crop(0.9, 0.85, True)] + [crop(0.5, 0.85, False)] * 2
        found = lines(evaluation(small))
        warnings = [line for line in found if line.startswith("- warning:") and "surer" in line]
        self.assertEqual(len(warnings), 1, found)
        self.assertIn("without a location", warnings[0])
        self.assertIn("3 held-out crops", warnings[0])

    def test_a_shown_figure_from_a_large_side_is_not_flagged(self):
        found = lines(evaluation(FISH))
        self.assertEqual([line for line in found if "names only" in line], [])


if __name__ == "__main__":
    unittest.main()
