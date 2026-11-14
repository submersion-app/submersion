#!/usr/bin/env python3
"""Unit tests for grouping.py.

Run: python3 scripts/site_catalogue/grouping_test.py

A reef program lists deployments, not sites: one reef is dozens of rows a
few metres apart. These tests pin how rows of one name become one site,
and that the same name somewhere else stays a site of its own.
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import grouping  # noqa: E402


def _item(name, north_m=0.0, **extra):
    return dict(name=name, lat=27.93 + north_m / 111195.0, lon=-83.02, **extra)


class GroupByNameTest(unittest.TestCase):
    def test_one_name_within_a_kilometre_is_one_group(self):
        groups = grouping.group_by_name(
            [_item("Rube Allyn Reef"), _item("Rube Allyn Reef", 300),
             _item("Rube Allyn Reef", 900)]
        )
        self.assertEqual([len(group) for group in groups], [3])

    def test_rows_are_linked_through_their_neighbours(self):
        # 0, 800 and 1600 m: the ends are 1.6 km apart, each next to the
        # middle one.
        groups = grouping.group_by_name(
            [_item("Long Reef", 1600), _item("Long Reef"),
             _item("Long Reef", 800)]
        )
        self.assertEqual([len(group) for group in groups], [3])

    def test_the_same_name_far_away_is_another_site(self):
        groups = grouping.group_by_name(
            [_item("Rube Allyn Reef"), _item("Rube Allyn Reef", 5000)]
        )
        self.assertEqual(sorted(len(group) for group in groups), [1, 1])

    def test_names_are_compared_folded(self):
        groups = grouping.group_by_name(
            [_item("Hoyt Vandenberg"), _item("USS HOYT VANDENBERG", 50),
             _item("Hoyt Vandenberg wreck", 80)]
        )
        self.assertEqual([len(group) for group in groups], [3])

    def test_different_names_never_group(self):
        groups = grouping.group_by_name([_item("Tank 47"), _item("Tank 48", 5)])
        self.assertEqual(len(groups), 2)

    def test_the_groups_do_not_depend_on_the_order_of_the_rows(self):
        items = [_item("A Reef", n, id=str(n)) for n in (0, 500, 5000, 5400)]
        forward = grouping.group_by_name(items)
        backward = grouping.group_by_name(list(reversed(items)))
        as_sets = lambda groups: sorted(  # noqa: E731
            sorted(item["id"] for item in group) for group in groups
        )
        self.assertEqual(as_sets(forward), as_sets(backward))
        self.assertEqual(as_sets(forward), [["0", "500"], ["5000", "5400"]])

    def test_a_radius_can_be_given(self):
        groups = grouping.group_by_name(
            [_item("A Reef"), _item("A Reef", 300)], radius_km=0.1
        )
        self.assertEqual(len(groups), 2)


class MeanPositionTest(unittest.TestCase):
    def test_the_mean_of_the_positions(self):
        lat, lon = grouping.mean_position(
            [dict(lat=10.0, lon=20.0), dict(lat=11.0, lon=22.0)]
        )
        self.assertAlmostEqual(lat, 10.5)
        self.assertAlmostEqual(lon, 21.0)


if __name__ == "__main__":
    unittest.main()
