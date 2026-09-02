#!/usr/bin/env python3
"""Unit tests for chamber_harvester.py.

Run: python3 scripts/chamber_harvester_test.py

These cover the validation gates, which are the only thing standing between a
broken parser and a safety-critical dataset shipping with blank phone numbers.
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "chamber_harvester",
    os.path.join(_HERE, "chamber_harvester.py"),
)
chamber_harvester = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(chamber_harvester)


def _row(**overrides):
    row = {
        "id": "it-example",
        "name": "Centro Iperbarico Example",
        "country": "IT",
        "city": "Milano",
        "phone": "+39-02-1234-5678",
        "latitude": 45.4642,
        "longitude": 9.19,
        "capability": "diving_emergency",
        "availability": "h24",
        "verified": {
            "date": "2026-08-26",
            "via": "facility",
            "url": "https://example.org/iperbarico",
        },
    }
    row.update(overrides)
    return row


class ValidateChambersTest(unittest.TestCase):
    def test_a_well_formed_row_passes(self):
        self.assertEqual(
            chamber_harvester.validate_chambers([_row()], min_count=1), []
        )

    def test_duplicate_ids_are_rejected(self):
        errors = chamber_harvester.validate_chambers([_row(), _row()], min_count=1)
        self.assertTrue(any("duplicate id" in e for e in errors))

    def test_a_row_without_a_phone_is_rejected(self):
        errors = chamber_harvester.validate_chambers([_row(phone="")], min_count=1)
        self.assertTrue(any("phone" in e for e in errors))

    def test_a_national_format_phone_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(phone="02 1234 5678")], min_count=1
        )
        self.assertTrue(any("phone" in e for e in errors))

    def test_a_country_name_instead_of_a_code_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(country="Italy")], min_count=1
        )
        self.assertTrue(any("country" in e for e in errors))

    def test_out_of_range_coordinates_are_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(latitude=91.0)], min_count=1
        )
        self.assertTrue(any("latitude" in e for e in errors))

    def test_null_island_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(latitude=0.0, longitude=0.0)], min_count=1
        )
        self.assertTrue(any("0,0" in e for e in errors))

    def test_an_unknown_capability_value_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(capability="wellness")], min_count=1
        )
        self.assertTrue(any("capability" in e for e in errors))

    def test_a_missing_verification_block_is_rejected(self):
        row = _row()
        del row["verified"]
        errors = chamber_harvester.validate_chambers([row], min_count=1)
        self.assertTrue(any("verified" in e for e in errors))

    def test_a_future_verification_date_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [
                _row(
                    verified={
                        "date": "2999-01-01",
                        "via": "facility",
                        "url": "https://example.org",
                    }
                )
            ],
            min_count=1,
        )
        self.assertTrue(any("future" in e for e in errors))

    def test_the_row_count_floor_is_enforced(self):
        errors = chamber_harvester.validate_chambers([_row()], min_count=100)
        self.assertTrue(any("at least 100" in e for e in errors))


class DescribePhoneShapeTest(unittest.TestCase):
    def test_reports_the_shape_without_the_number(self):
        shape = chamber_harvester.describe_phone_shape("02 1234 5678")
        self.assertIn("10 digits", shape)
        self.assertIn("no leading +", shape)
        self.assertNotIn("1234", shape)

    def test_a_fused_pair_of_numbers_is_visible_from_the_digit_count(self):
        shape = chamber_harvester.describe_phone_shape("+399572646110957264911")
        self.assertIn("21 digits", shape)
        self.assertIn("leading +", shape)

    def test_a_validation_error_does_not_echo_the_number(self):
        errors = chamber_harvester.validate_chambers(
            [_row(phone="02 1234 5678")], min_count=1
        )
        joined = " ".join(errors)
        self.assertIn("phone", joined)
        self.assertNotIn("1234", joined)


class DropRedundantEmergencyLinesTest(unittest.TestCase):
    def test_a_duplicate_emergency_line_is_removed(self):
        rows = chamber_harvester.drop_redundant_emergency_lines(
            [_row(phone="+39-02-1234-5678", emergencyPhone="+39-02-1234-5678")]
        )
        self.assertNotIn("emergencyPhone", rows[0])
        self.assertEqual(rows[0]["phone"], "+39-02-1234-5678")

    def test_a_genuinely_different_emergency_line_is_kept(self):
        rows = chamber_harvester.drop_redundant_emergency_lines(
            [_row(phone="+39-02-1234-5678", emergencyPhone="+39-02-9999-9999")]
        )
        self.assertEqual(rows[0]["emergencyPhone"], "+39-02-9999-9999")

    def test_a_row_without_an_emergency_line_is_untouched(self):
        rows = chamber_harvester.drop_redundant_emergency_lines([_row()])
        self.assertNotIn("emergencyPhone", rows[0])


class MergeRowsTest(unittest.TestCase):
    def test_overlay_rows_win_over_harvested_leads(self):
        lead = _row(phone="+39-02-0000-0000")
        overlay = _row(phone="+39-02-9999-9999")
        merged = chamber_harvester.merge_rows([lead], [overlay])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["phone"], "+39-02-9999-9999")

    def test_rows_with_distinct_ids_are_both_kept(self):
        merged = chamber_harvester.merge_rows([_row(id="it-a")], [_row(id="it-b")])
        self.assertEqual({r["id"] for r in merged}, {"it-a", "it-b"})

    def test_output_is_sorted_by_id_for_stable_diffs(self):
        merged = chamber_harvester.merge_rows([_row(id="it-z"), _row(id="it-a")], [])
        self.assertEqual([r["id"] for r in merged], ["it-a", "it-z"])


if __name__ == "__main__":
    unittest.main()
