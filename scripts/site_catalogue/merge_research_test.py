#!/usr/bin/env python3
"""Unit tests for researched sites in merge.py.

Run: python3 scripts/site_catalogue/merge_research_test.py

Researched records join the merge from the evidence file: they rank last,
pass no field either way, take their country from the researcher when the
lookup cannot place them, and may leave a shipped catalogue only by a
withdrawal. Curated withdrawals are taken here too.
"""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import merge  # noqa: E402
import snapshots  # noqa: E402
import src_research  # noqa: E402
from merge_test import _CURATED, _Places, _snapshots  # noqa: E402
from places import Place  # noqa: E402


def _research_record(site_id, name, lat, lon, country="ID", **extra):
    record = src_research.working_record(
        site_id, name, lat, lon, country_hint=country, **extra
    )
    return record


def _batch(records=(), withdrawn=None):
    return src_research.ResearchBatch(
        records=list(records), withdrawn=dict(withdrawn or {}),
        counts={"approved": len(records)}, read=len(records),
    )


class ResearchInTheMergeTest(unittest.TestCase):
    def _build(self, batch, places=None, previous_ids=None, curated=_CURATED):
        return merge.build(
            {}, curated, places or _Places(Place("ID", "Indonesia", "Bali",
                                                 None, False, False)),
            research=batch, previous_ids=previous_ids,
        )

    def test_research_written_researched(self):
        records, report = self._build(_batch([
            _research_record("research_id_x", "Liberty", -8.27, 115.59,
                             types=["wreck"], entry_type="shore",
                             description="Shore dive to a wreck."),
        ]))
        by_id = {r["id"]: r for r in records}
        record = by_id["research_id_x"]
        self.assertEqual(record["trust"], "researched")
        self.assertEqual(record["source"], "research")
        self.assertEqual(record["country_code"], "ID")
        self.assertEqual(record["region"], "Bali")
        self.assertEqual(record["entry"], ["shore"])
        self.assertEqual(report["research"]["written"], 1)

    def test_country_mismatch_fails(self):
        with self.assertRaises(ValueError) as raised:
            self._build(_batch([
                _research_record("research_my_x", "Barracuda Point",
                                 -8.27, 115.59, country="MY"),
            ]))
        self.assertIn("research_my_x", str(raised.exception))

    def test_unplaceable_point_takes_entry_code(self):
        nowhere = Place(None, None, None, None, False, True)
        records, _ = self._build(
            _batch([_research_record("research_my_x", "Barracuda Point",
                                     4.115, 118.629, country="MY")]),
            places=_Places(nowhere),
        )
        record = {r["id"]: r for r in records}["research_my_x"]
        self.assertEqual(record["country_code"], "MY")
        self.assertEqual(record["country"], "Malaysia")

    def test_shipped_research_id_lost_to_overlap_fails(self):
        osm = [{"type": "node", "id": 1, "lat": -8.27, "lon": 115.59,
                "tags": {"sport": "scuba_diving", "name": "Liberty"},
                "geocoded": ["ID", "Indonesia", None]}]
        batch = _batch([_research_record("research_id_x", "Liberty Wreck",
                                         -8.2701, 115.59)])
        with self.assertRaises(ValueError) as raised:
            merge.build({"osm_sites": osm}, [], _Places(Place(
                "ID", "Indonesia", "Bali", None, False, False)),
                research=batch, previous_ids={"research_id_x"})
        self.assertIn("research_id_x", str(raised.exception))
        self.assertIn("osm_node_1", str(raised.exception))

    def test_a_shipped_research_id_that_leaves_any_other_way_fails(self):
        with self.assertRaises(ValueError) as raised:
            self._build(_batch([]), previous_ids={"research_id_gone"})
        self.assertIn("research_id_gone", str(raised.exception))

    def test_a_shipped_curated_id_that_leaves_without_withdrawal_fails(self):
        with self.assertRaises(ValueError) as raised:
            self._build(_batch([]), previous_ids={"curated_gone"})
        self.assertIn("curated_gone", str(raised.exception))

    def test_a_withdrawal_naming_no_curated_record_fails(self):
        with self.assertRaises(ValueError) as raised:
            self._build(_batch([], withdrawn={
                "curated_shroe": {"reason": "duplicate", "date": "2026-12-01"}}))
        self.assertIn("curated_shroe", str(raised.exception))

    def test_withdrawn_research_id_may_leave(self):
        records, _ = self._build(
            _batch([], withdrawn={"research_id_gone": {
                "reason": "position", "date": "2026-12-01"}}),
            previous_ids={"research_id_gone"},
        )
        self.assertNotIn("research_id_gone", {r["id"] for r in records})

    def test_withdrawn_curated_left_out(self):
        records, report = self._build(_batch([], withdrawn={
            "curated_shore": {"reason": "not_a_site", "date": "2026-12-01"}}))
        ids = {r["id"] for r in records}
        self.assertNotIn("curated_shore", ids)
        self.assertIn("curated_nj_pocopson", ids)
        self.assertEqual(report["curated"]["dropped"], {"withdrawn": 1})

    def test_report_research_line(self):
        _, report = self._build(_batch([
            _research_record("research_id_x", "Liberty", -8.27, 115.59)]))
        self.assertEqual(report["research"]["formed"], 1)
        self.assertEqual(report["research"]["read"], 1)


class ResearchInMainTest(unittest.TestCase):
    def test_withdrawn_in_metadata_and_research_read_every_run(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cache, out = Path(tmp.name) / "cache", Path(tmp.name) / "out"
        out.mkdir()
        for key, rows in _snapshots().items():
            snapshots.write_snapshot(key, "https://example.org", rows, cache)
        (cache / merge.NJDEP_METADATA_FILE).write_text("<m/>", encoding="utf-8")
        batch = _batch([], withdrawn={
            "curated_shore": {"reason": "not_a_site", "date": "2026-12-01"}})
        with redirect_stdout(io.StringIO()) as printed:
            code = merge.main(
                ["--cache", str(cache), "--out", str(out)],
                places=_Places(), curated=_CURATED, research=batch,
            )
        self.assertEqual(code, 0)
        doc = json.loads((out / "site_catalogue.json").read_text("utf-8"))
        self.assertEqual(doc["metadata"]["withdrawn"], {
            "curated_shore": {"reason": "not_a_site", "date": "2026-12-01"}})
        self.assertIn("research", printed.getvalue())
        self.assertIn("Withdrawn: 1", printed.getvalue())
        self.assertIn("curated_shore (not_a_site", printed.getvalue())

    def test_a_withdrawal_the_file_cannot_hold_stops_main_cleanly(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cache, out = Path(tmp.name) / "cache", Path(tmp.name) / "out"
        out.mkdir()
        for key, rows in _snapshots().items():
            snapshots.write_snapshot(key, "https://example.org", rows, cache)
        (cache / merge.NJDEP_METADATA_FILE).write_text("<m/>", encoding="utf-8")
        batch = _batch([], withdrawn={"research_id_a": {
            "reason": "position", "date": "2026-12-01",
            "replaced_by": "research_id_pending"}})
        with redirect_stdout(io.StringIO()) as printed:
            code = merge.main(
                ["--cache", str(cache), "--out", str(out)],
                places=_Places(), curated=_CURATED, research=batch,
            )
        self.assertEqual(code, 2)
        self.assertIn("research_id_pending", printed.getvalue())

    def test_a_silent_departure_stops_main_and_writes_nothing(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cache, out = Path(tmp.name) / "cache", Path(tmp.name) / "out"
        out.mkdir()
        for key, rows in _snapshots().items():
            snapshots.write_snapshot(key, "https://example.org", rows, cache)
        (cache / merge.NJDEP_METADATA_FILE).write_text("<m/>", encoding="utf-8")
        previous = '{"metadata":{},"sites":[{"id":"research_id_gone"}]}'
        (out / "site_catalogue.json").write_text(previous, encoding="utf-8")
        with redirect_stdout(io.StringIO()) as printed:
            code = merge.main(
                ["--cache", str(cache), "--out", str(out)],
                places=_Places(), curated=_CURATED, research=_batch([]),
            )
        self.assertEqual(code, 2)
        self.assertIn("research_id_gone", printed.getvalue())
        self.assertEqual(
            (out / "site_catalogue.json").read_text("utf-8"), previous
        )



if __name__ == "__main__":
    unittest.main()
