#!/usr/bin/env python3
"""Unit tests for region_grid.py."""

import importlib.util
import json
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "region_grid", os.path.join(_HERE, "region_grid.py")
)
grid = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(grid)


class CellTests(unittest.TestCase):
    def test_origin_corner_is_cell_zero(self):
        self.assertEqual(grid.cell_of(-90, -180, 5), 0)

    def test_north_pole_and_antimeridian_fall_in_the_last_row_first_column(self):
        last_row_first = (grid.rows(5) - 1) * grid.columns(5)
        self.assertEqual(grid.cell_of(90, 180, 5), last_row_first)

    def test_just_below_the_maximum_is_the_last_cell(self):
        self.assertEqual(grid.cell_of(89.99, 179.99, 5), grid.cell_count(5) - 1)

    def test_out_of_range_latitude_clamps(self):
        self.assertEqual(grid.cell_of(-100, 0, 5), grid.cell_of(-90, 0, 5))


class NeighbourhoodTests(unittest.TestCase):
    def test_interior_cell_has_nine(self):
        c = grid.cell_of(12.1, -68.3, 5)
        self.assertEqual(len(grid.neighbourhood(c, 1, 5)), 9)

    def test_seam_wraps_longitude(self):
        c = grid.cell_of(12.1, -179.0, 5)
        cells = grid.neighbourhood(c, 1, 5)
        self.assertEqual(len(cells), 9)
        east_end = grid.cell_of(12.1, 179.0, 5)
        self.assertIn(east_end, cells)

    def test_top_row_stops_at_the_pole(self):
        c = grid.cell_of(89.0, 10.0, 5)
        cells = grid.neighbourhood(c, 1, 5)
        self.assertEqual(len(cells), 6)
        for n in cells:
            self.assertTrue(0 <= n < grid.cell_count(5))

    def test_zero_rings_is_the_cell_itself(self):
        self.assertEqual(grid.neighbourhood(100, 0, 5), {100})


class PackBitsTests(unittest.TestCase):
    def test_bits_land_in_the_right_byte_and_position(self):
        packed = grid.pack_bits([[0, 9]], 5)
        self.assertEqual(len(packed), grid.row_bytes(5))
        self.assertEqual(packed[0], 0b00000001)
        self.assertEqual(packed[1], 0b00000010)

    def test_each_candidate_has_its_own_row(self):
        packed = grid.pack_bits([[], [0]], 5)
        self.assertEqual(len(packed), 2 * grid.row_bytes(5))
        self.assertEqual(packed[grid.row_bytes(5)], 1)


class VectorFileTests(unittest.TestCase):
    def test_checked_in_vectors_match_this_module(self):
        path = os.path.join(_HERE, "testdata", "region_vectors.json")
        with open(path, encoding="utf-8") as fh:
            self.assertEqual(json.load(fh), json.loads(json.dumps(grid.vectors())))


if __name__ == "__main__":
    unittest.main()
