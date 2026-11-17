#!/usr/bin/env python3
"""Unit tests for src_research.py.

Run: python3 scripts/site_catalogue/src_research_test.py

Researched sites reach the merge from the evidence file, not from a
download. These tests pin which entries become records (approved, sound,
not withdrawn), what each record carries, the line written as its
description, where its source link points, and the list of withdrawals
the catalogue carries.
"""

import os
import sys
import unittest
from datetime import date

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE), os.path.join(_HERE, "research")]

import src_research  # noqa: E402
from evidence import DomainLists  # noqa: E402

TODAY = date(2026, 11, 16)
DOMAINS = DomainLists(counting={"opa.com": "operator", "pressb.org": "press"})


def _entry(site_id="research_id_usat_liberty", **overrides):
    entry = {
        "id": site_id,
        "name": "USAT Liberty",
        "area": "Tulamben",
        "country_code": "ID",
        "position": {
            "lat": -8.27391,
            "lon": 115.5929,
            "sources": [
                {"url": "https://opa.com/a", "read": "2026-11-16",
                 "lat": -8.27382, "lon": 115.5929},
                {"url": "https://pressb.org/b", "read": "2026-11-16",
                 "lat": -8.27400, "lon": 115.5929},
            ],
        },
        "max_depth_m": {"sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16", "value": 30}]},
        "min_depth_m": {"sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16", "value": 5}]},
        "entry": {"value": ["shore"], "sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16"}]},
        "types": {"value": ["wreck"], "sources": [
            {"url": "https://pressb.org/b", "read": "2026-11-16"}]},
        "hazards": {"value": ["permit", "boat_traffic"], "sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16"}]},
        "review": {"state": "approved", "date": "2026-11-17"},
        "withdrawn": None,
    }
    entry.update(overrides)
    return entry


def _records(*entries):
    return src_research.records(list(entries), DOMAINS, today=TODAY)


class RecordsTest(unittest.TestCase):
    def test_an_approved_entry_becomes_a_dive_site_record(self):
        records, counts = _records(_entry())
        self.assertEqual(len(records), 1)
        record = records[0]
        self.assertEqual(record["id"], "research_id_usat_liberty")
        self.assertEqual(record["source"], "research")
        self.assertEqual(record["kind"], "site")
        self.assertAlmostEqual(record["lat"], -8.27391)
        self.assertEqual(record["max_depth"], 30)
        self.assertEqual(record["min_depth"], 5)
        self.assertEqual(record["types"], ["wreck"])
        self.assertEqual(record["entry_type"], "shore")
        self.assertEqual(
            record["hazards"],
            "Boat traffic overhead. Protected area; a permit or fee may be needed.",
        )
        self.assertEqual(record["description"], "Shore dive to a wreck.")
        self.assertEqual(record["country_hint"], "ID")
        self.assertEqual(counts["approved"], 1)

    def test_only_approved_sound_unwithdrawn_entries_ship(self):
        records, counts = _records(
            _entry("research_id_a", review={"state": "pending"}),
            _entry("research_id_b", review={"state": "rejected",
                                            "date": "2026-11-17", "reason": "x"},
                   note="apart"),
            _entry("research_id_c", withdrawn={"reason": "position",
                                               "date": "2026-12-01"}),
            _entry("research_id_d", name="", note="apart"),
        )
        self.assertEqual(records, [])
        self.assertEqual(counts["pending"], 1)
        self.assertEqual(counts["rejected"], 1)
        self.assertEqual(counts["withdrawn"], 1)
        self.assertEqual(counts["failed"], 1)

    def test_a_map_read_entry_forms_a_record_placed_from_a_map(self):
        entry = _entry(named={"place": "Tulamben Bay", "sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16"},
            {"url": "https://pressb.org/b", "read": "2026-11-16"},
        ]})
        entry["position"] = {"lat": -8.2759, "lon": 115.5937, "sources": [
            {"url": "https://opa.com/a", "read": "2026-11-16", "method": "map",
             "map": "https://opa.com/m.jpg", "lat": -8.2759, "lon": 115.5937},
        ]}
        records, _ = _records(entry)
        self.assertEqual(records[0]["position_from"], "map")

    def test_a_stated_entry_forms_a_record_with_no_position_from(self):
        records, _ = _records(_entry())
        self.assertNotIn("position_from", records[0])

    def test_app_entry_names_survive_the_format(self):
        entry = _entry()
        entry["entry"]["value"] = ["boat", "giantStride"]
        record = _records(entry)[0][0]
        self.assertEqual(record["entry_type"], "boat, giantStride")


class DescribeTest(unittest.TestCase):
    def test_the_spec_examples_without_depth(self):
        self.assertEqual(src_research.describe(["shore"], ["wreck"]),
                         "Shore dive to a wreck.")
        self.assertEqual(src_research.describe(["boat"], ["wall"]),
                         "Boat dive on a wall.")
        self.assertEqual(src_research.describe([], ["reef"]), "Reef dive.")

    def test_entry_alone(self):
        self.assertEqual(src_research.describe(["boat"], []), "Boat dive.")

    def test_other_types(self):
        self.assertEqual(src_research.describe([], ["artificial_reef"]),
                         "Artificial reef dive.")
        self.assertEqual(src_research.describe(["shore"], ["muck"]),
                         "Shore dive on a muck site.")

    def test_freshwater_and_pool_types_read_naturally(self):
        self.assertEqual(src_research.describe(["shore"], ["lake"]), "Shore dive in a lake.")
        self.assertEqual(src_research.describe(["shore"], ["quarry"]), "Shore dive in a quarry.")
        self.assertEqual(src_research.describe(["shore"], ["river"]), "Shore dive in a river.")
        self.assertEqual(src_research.describe(["shore"], ["spring"]), "Shore dive into a spring.")
        self.assertEqual(src_research.describe(["shore"], ["pool"]), "Shore dive in a pool.")

    def test_nothing_known(self):
        self.assertIsNone(src_research.describe([], []))
        self.assertIsNone(src_research.describe(["giantStride"], []))


class SourceRefTest(unittest.TestCase):
    def test_points_at_the_entry_in_the_repository(self):
        ref = src_research.source_ref("research_id_usat_liberty")
        self.assertTrue(ref.startswith(
            "https://github.com/submersion-app/submersion/blob/main/"
            "scripts/site_catalogue/research/sites.json"
        ))
        self.assertIn("research_id_usat_liberty", ref)


class WithdrawalsTest(unittest.TestCase):
    def test_cumulative_over_sites_and_curated(self):
        withdrawn = src_research.withdrawals(
            [
                _entry("research_id_a", withdrawn={
                    "reason": "position", "date": "2026-12-01",
                    "replaced_by": "research_id_b"}),
                _entry("research_id_b"),
            ],
            [{"id": "curated_x", "reason": "not_a_site", "date": "2026-12-02"}],
        )
        self.assertEqual(withdrawn, {
            "research_id_a": {"reason": "position", "date": "2026-12-01",
                              "replaced_by": "research_id_b"},
            "curated_x": {"reason": "not_a_site", "date": "2026-12-02"},
        })

    def test_a_replacement_chain_points_at_the_last_record(self):
        withdrawn = src_research.withdrawals(
            [
                _entry("research_id_a", withdrawn={
                    "reason": "position", "date": "2026-12-01",
                    "replaced_by": "research_id_b"}),
                _entry("research_id_b", withdrawn={
                    "reason": "position", "date": "2027-02-01",
                    "replaced_by": "research_id_c"}),
                _entry("research_id_c"),
            ],
            [],
        )
        self.assertEqual(withdrawn["research_id_a"]["replaced_by"], "research_id_c")
        self.assertEqual(withdrawn["research_id_b"]["replaced_by"], "research_id_c")

    def test_a_replacement_withdrawn_outright_leaves_no_link(self):
        withdrawn = src_research.withdrawals(
            [
                _entry("research_id_a", withdrawn={
                    "reason": "position", "date": "2026-12-01",
                    "replaced_by": "research_id_b"}),
                _entry("research_id_b", withdrawn={
                    "reason": "not_a_site", "date": "2027-02-01"}),
            ],
            [],
        )
        self.assertNotIn("replaced_by", withdrawn["research_id_a"])

    def test_a_longer_replacement_loop_is_refused(self):
        def withdrawn(site_id, replaced_by):
            return _entry(site_id, withdrawn={
                "reason": "position", "date": "2026-12-01",
                "replaced_by": replaced_by})
        with self.assertRaises(ValueError):
            src_research.withdrawals([
                withdrawn("research_id_a", "research_id_b"),
                withdrawn("research_id_b", "research_id_c"),
                withdrawn("research_id_c", "research_id_b"),
            ], [])

    def test_a_replacement_loop_is_refused(self):
        with self.assertRaises(ValueError):
            src_research.withdrawals(
                [
                    _entry("research_id_a", withdrawn={
                        "reason": "position", "date": "2026-12-01",
                        "replaced_by": "research_id_b"}),
                    _entry("research_id_b", withdrawn={
                        "reason": "position", "date": "2027-02-01",
                        "replaced_by": "research_id_a"}),
                ],
                [],
            )

    def test_a_bad_curated_withdrawal_is_refused(self):
        for bad in (
            {"id": "osm_node_1", "reason": "position", "date": "2026-12-02"},
            {"id": "curated_x", "reason": "bored", "date": "2026-12-02"},
            {"id": "curated_x", "reason": "position"},
            {"id": "curated_x", "reason": "position", "date": 20261202},
            {"id": "curated_x", "reason": "position", "date": "2 Dec 2026"},
        ):
            with self.assertRaises(ValueError, msg=bad):
                src_research.withdrawals([], [bad])


if __name__ == "__main__":
    unittest.main()
