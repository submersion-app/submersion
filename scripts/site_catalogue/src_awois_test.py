#!/usr/bin/env python3
"""Unit tests for src_awois.py, against real AWOIS placemarks.

Run: python3 scripts/site_catalogue/src_awois_test.py

NOAA graded every AWOIS position, and most named wrecks are graded low.
These tests pin the gate that keeps the well-fixed ones that are still
there and under water, on placemarks copied from the register
(samples/awois.kml).
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_awois  # noqa: E402

with open(os.path.join(_HERE, "samples", "awois.kml"), "rb") as _file:
    _RAW = _file.read()


def _rows():
    return {row["RECRD"]: row for row in src_awois.parse(_RAW)}


def _one(row):
    records, dropped = src_awois.records([row])
    return (records[0] if records else None), next(iter(dropped), None)


class ParseTest(unittest.TestCase):
    def test_every_placemark_is_read_with_its_fields(self):
        rows = _rows()
        self.assertEqual(len(rows), 9)
        self.assertEqual(rows["10358"]["VESSLTERMS"], "CAROL  A")
        self.assertEqual(rows["10358"]["GP_QUALITY"], "High")
        # Entities in the register's text are read as the characters.
        self.assertNotIn("&amp;", "".join(rows["1133"].values()))

    def test_a_document_with_no_placemarks_is_refused(self):
        with self.assertRaises(ValueError):
            src_awois.parse(b"<kml><Document></Document></kml>")


class GateTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def test_each_reason_a_row_is_dropped_for(self):
        for record_id, reason in [
            ("1", "low_quality"),
            ("1041", "low_quality"),
            ("12508", "visible"),
            ("52338", "removed"),
            ("10003", "no_name"),
        ]:
            self.assertEqual(_one(self.rows[record_id])[1], reason, record_id)

    def test_a_wreck_charted_deeper_than_60_m_is_dropped(self):
        row = dict(self.rows["10358"], DEPTH="250")
        self.assertEqual(_one(row)[1], "too_deep")

    def test_a_row_with_no_position_is_dropped_quietly(self):
        row = dict(self.rows["10358"], LATDEC="")
        self.assertEqual(_one(row)[1], "no_position")

    def test_the_counts_cover_every_row(self):
        records, dropped = src_awois.records(list(self.rows.values()))
        self.assertEqual(len(records), 4)
        self.assertEqual(len(records) + sum(dropped.values()), 9)


class RecordTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def test_a_well_fixed_wreck(self):
        record, _ = _one(self.rows["10358"])
        self.assertEqual(record["id"], "awois_10358")
        self.assertEqual(record["name"], "Carol A")
        self.assertEqual(record["source"], "awois")
        self.assertEqual(record["kind"], "register")
        self.assertEqual(record["types"], ["wreck"])
        self.assertEqual(record["description"], "Lost 1977")
        # 21 feet: a lone depth is the maximum.
        self.assertEqual(record["max_depth"], 6.4)
        self.assertIsNone(record["min_depth"])
        self.assertIn("web.archive.org", record["source_ref"])

    def test_each_unit_a_depth_is_written_in(self):
        self.assertEqual(_one(self.rows["11897"])[0]["max_depth"], 27.4)
        self.assertEqual(_one(self.rows["1133"])[0]["max_depth"], 12.9)
        self.assertIsNone(_one(self.rows["10195"])[0]["max_depth"])
        # A depth with no stated unit says too little to use.
        row = dict(self.rows["10358"], SOUNDING_TYPE="")
        self.assertIsNone(_one(row)[0]["max_depth"])
        # A wire-drag clearance is the depth a wire was drawn at without
        # touching anything: the wreck lies deeper, by an unstated amount.
        row = dict(
            self.rows["10358"], SOUNDING_TYPE="Wire-drag clearance, feet"
        )
        self.assertIsNone(_one(row)[0]["max_depth"])


if __name__ == "__main__":
    unittest.main()
