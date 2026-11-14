#!/usr/bin/env python3
"""Unit tests for src_ireland.py, against real rows of the Irish inventory.

Run: python3 scripts/site_catalogue/src_ireland_test.py

The Wreck Inventory of Ireland says where each position came from. Some
came from sites whose data the catalogue may not reuse (wrecksite.eu,
uboat.net) and some are loss reports, not wreck positions. These tests pin
that those never pass, on rows copied from the inventory
(samples/ireland.csv).
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_ireland  # noqa: E402

with open(os.path.join(_HERE, "samples", "ireland.csv"), "rb") as _file:
    _RAW = _file.read()


def _rows():
    return {row["Wreck No"]: row for row in src_ireland.parse(_RAW)}


def _one(row):
    records, dropped = src_ireland.records([row])
    return (records[0] if records else None), next(iter(dropped), None)


class ParseTest(unittest.TestCase):
    def test_every_sample_row_is_read(self):
        rows = src_ireland.parse(_RAW)
        self.assertEqual(len(rows), 10)
        # The byte order mark is not part of the first column's name.
        self.assertIn("Wreck Name", rows[0])

    def test_a_file_without_the_position_source_column_is_refused(self):
        broken = _RAW.replace(b"Source of Co-ordinate", b"Source", 1)
        with self.assertRaises(ValueError) as raised:
            src_ireland.parse(broken)
        self.assertIn("Source of Co-ordinate", str(raised.exception))


class GateTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def test_each_reason_a_row_is_dropped_for(self):
        for wreck_no, reason in [
            ("W06261", "excluded_source"),  # wrecksite.eu
            ("W04795", "excluded_source"),  # uboat.net
            ("W02911", "excluded_source"),  # Lloyd's List, a loss report
            ("W04181", "unstated_source"),
            ("W00485", "coarse_position"),
            ("W00001", "no_position"),
            ("W00112", "no_name"),
        ]:
            self.assertEqual(_one(self.rows[wreck_no])[1], reason, wreck_no)

    def test_an_excluded_source_is_caught_however_it_is_written(self):
        for source in ("www.wrecksite.eu", "wrecksite.eu; BVLS 1939-1945",
                       "UBoat.net", "Lloyd’s List", "BVLS 1939-1945",
                       "Parliamentary Papers 1880, LXVI"):
            row = dict(self.rows["W00248"])
            row["Source of Co-ordinate"] = source
            self.assertEqual(_one(row)[1], "excluded_source", source)

    def test_the_counts_cover_every_row(self):
        records, dropped = src_ireland.records(list(self.rows.values()))
        self.assertEqual(len(records), 3)
        self.assertEqual(len(records) + sum(dropped.values()), 10)


class RecordTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def test_a_surveyed_wreck(self):
        record, _ = _one(self.rows["W00248"])
        self.assertEqual(record["id"], "ie_W00248")
        self.assertEqual(record["name"], "Topaz")
        self.assertEqual(record["source"], "nms_ie")
        self.assertEqual(record["kind"], "register")
        self.assertEqual(record["types"], ["wreck"])
        self.assertEqual(record["lat"], 53.8702)
        self.assertEqual(record["lon"], -6.17636)
        self.assertEqual(record["description"], "Steamship, lost 1891")
        self.assertIsNone(record["max_depth"])
        self.assertTrue(record["source_ref"].startswith("https://"))

    def test_the_type_suffix_leaves_the_name(self):
        self.assertEqual(
            _one(self.rows["W00051"])[0]["name"], "James Postlethwaite"
        )

    def test_an_unknown_class_says_nothing(self):
        self.assertIsNone(_one(self.rows["W02432"])[0]["description"])


if __name__ == "__main__":
    unittest.main()
