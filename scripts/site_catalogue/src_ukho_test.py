#!/usr/bin/env python3
"""Unit tests for src_ukho.py, against real rows of the UKHO wreck file.

Run: python3 scripts/site_catalogue/src_ukho_test.py

The UKHO register lists every charted wreck, most of which no diver could
or should be sent to: wrecks that dry at low water, foul ground, positions
that are a reported sinking rounded to a mile. These tests pin the gate
that keeps the ones with a defensible position, on rows copied from the
register (samples/ukho.tsv).
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_ukho  # noqa: E402

with open(os.path.join(_HERE, "samples", "ukho.tsv"), "rb") as _file:
    _RAW = _file.read()


def _rows():
    return {row["wreck_id"]: row for row in src_ukho.parse(_RAW)}


def _one(row):
    """(the row's record or None, the reason it was dropped or None)."""
    records, dropped = src_ukho.records([row])
    return (records[0] if records else None), next(iter(dropped), None)


class ParseTest(unittest.TestCase):
    def test_every_sample_row_is_read(self):
        self.assertEqual(len(src_ukho.parse(_RAW)), 18)

    def test_a_file_without_a_column_the_gate_reads_is_refused(self):
        broken = _RAW.replace(b"water_level_effect", b"water_level", 1)
        with self.assertRaises(ValueError) as raised:
            src_ukho.parse(broken)
        self.assertIn("water_level_effect", str(raised.exception))


class EncodingTest(unittest.TestCase):
    def _name(self, raw_name: bytes) -> str:
        raw = _RAW.replace(b'"GEORGE ROYLE"', b'"' + raw_name + b'"', 1)
        row = {r["wreck_id"]: r for r in src_ukho.parse(raw)}["9438"]
        return row["name"]

    def test_a_name_written_in_utf8_is_read_as_written(self):
        # The register is nearly all ASCII, with a few UTF-8 names.
        self.assertEqual(self._name("Noemí I".encode("utf-8")), "Noemí I")

    def test_a_stray_single_byte_letter_does_not_stop_the_file(self):
        self.assertEqual(self._name("Noemí I".encode("cp1252")), "Noemí I")
        self.assertEqual(len(src_ukho.parse(_RAW)), 18)


class GateTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def _reason(self, wreck_id):
        return _one(self.rows[wreck_id])[1]

    def test_each_reason_a_row_is_dropped_for(self):
        for wreck_id, reason in [
            ("75388", "dead"),
            ("27124", "dead"),
            ("94439", "doubtful"),
            ("41162", "not_submerged"),
            ("82195", "not_wreck"),
            ("48072", "coarse_position"),
            ("92357", "too_shallow"),
            ("91638", "too_deep"),
            ("47702", "diving_prohibited"),
            ("41153", "no_name"),
        ]:
            self.assertEqual(self._reason(wreck_id), reason, wreck_id)

    def test_a_coarse_position_passes_with_a_stated_fixing_method(self):
        record, reason = _one(self.rows["52951"])
        self.assertIsNone(reason)
        self.assertEqual(record["name"], "Chikuzen")

    def test_a_wellhead_is_not_a_wreck(self):
        row = dict(self.rows["9438"], type="Wellhead")
        self.assertEqual(_one(row)[1], "not_wreck")

    def test_a_row_with_no_usable_position_or_depth_is_dropped_quietly(self):
        for change, reason in [
            ({"latitude": ""}, "no_position"),
            ({"longitude": "E"}, "no_position"),
            ({"water_depth": "UNKNOWN", "depth": ""}, "no_depth"),
        ]:
            row = dict(self.rows["9438"], **change)
            self.assertEqual(_one(row)[1], reason, change)

    def test_the_counts_cover_every_row(self):
        records, dropped = src_ukho.records(list(self.rows.values()))
        self.assertEqual(len(records) + sum(dropped.values()), 18)
        self.assertEqual(len(records), 8)


class RecordTest(unittest.TestCase):
    def setUp(self):
        self.rows = _rows()

    def test_a_surveyed_wreck(self):
        record, _ = _one(self.rows["9438"])
        self.assertEqual(record["id"], "ukho_9438")
        self.assertEqual(record["name"], "George Royle")
        self.assertEqual(record["source"], "ukho")
        self.assertEqual(record["kind"], "register")
        self.assertEqual(record["types"], ["wreck"])
        # 53 1.988 N, 1 10.493 E
        self.assertAlmostEqual(record["lat"], 53.033133, places=5)
        self.assertAlmostEqual(record["lon"], 1.174883, places=5)
        self.assertEqual(record["max_depth"], 22.0)
        self.assertEqual(record["min_depth"], 17.3)
        self.assertEqual(record["description"], "Steam ship, lost 1915")
        self.assertIsNone(record["hazards"])
        self.assertTrue(record["source_ref"].startswith("https://"))

    def test_south_and_west_are_negative(self):
        record, _ = _one(self.rows["82223"])
        self.assertAlmostEqual(record["lat"], -33.42075, places=4)
        self.assertAlmostEqual(record["lon"], -58.43025, places=4)

    def test_the_least_depth_is_a_minimum_only_when_it_is_less(self):
        row = dict(self.rows["9438"], depth="22", water_depth="22")
        self.assertIsNone(_one(row)[0]["min_depth"])
        row = dict(self.rows["9438"], depth="", water_depth="22")
        self.assertIsNone(_one(row)[0]["min_depth"])
        # With no charted depth, the least depth stands in for it.
        row = dict(self.rows["9438"], depth="18", water_depth="")
        record = _one(row)[0]
        self.assertEqual(record["max_depth"], 18.0)
        self.assertIsNone(record["min_depth"])

    def test_the_description_uses_what_the_register_states(self):
        self.assertEqual(
            _one(self.rows["27570"])[0]["description"], "Trawler"
        )
        self.assertEqual(
            _one(self.rows["31862"])[0]["description"],
            "Military vessel, lost 1801",
        )
        self.assertIsNone(_one(self.rows["92122"])[0]["description"])

    def test_the_register_s_doubt_stays_in_the_name(self):
        self.assertEqual(
            _one(self.rows["27570"])[0]["name"], "Frigg (possibly)"
        )
        # A name the register wrote in mixed case is left as it is.
        self.assertEqual(_one(self.rows["92122"])[0]["name"], "Pengasus")

    def test_a_stated_restriction_becomes_the_hazard_in_its_own_words(self):
        self.assertEqual(
            _one(self.rows["87393"])[0]["hazards"],
            "Rest'd area 300m radius. Fishing and anchoring prohibited.",
        )
        hazards = _one(self.rows["15080"])[0]["hazards"]
        self.assertIn("military remains", hazards)
        self.assertTrue(hazards[0].isupper())
        self.assertLessEqual(len(hazards), 200)

    def test_an_ordinary_comment_is_not_a_hazard(self):
        row = dict(self.rows["9438"], general_comments="INTACT, ON PORT SIDE")
        self.assertIsNone(_one(row)[0]["hazards"])


if __name__ == "__main__":
    unittest.main()
