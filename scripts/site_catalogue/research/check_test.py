#!/usr/bin/env python3
"""Unit tests for check.py.

Run: python3 scripts/site_catalogue/research/check_test.py

A researched site ships only when its evidence meets the rules of the
slice 3 design: two counting pages that agree on its position, depths
that agree well enough, every fact sourced, and no text from any page.
Each test breaks one rule on an entry that otherwise passes.
"""

import copy
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import date
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE), os.path.dirname(os.path.dirname(_HERE))]

import check  # noqa: E402
from evidence import DomainLists  # noqa: E402

TODAY = date(2026, 11, 16)
DOMAINS = DomainLists(
    counting={"opa.com": "operator", "pressb.org": "dive press"},
    cite_only={"dir.com": "directory"},
    never={"bad.eu": "proprietary"},
)

# 40 m apart, north and south of -8.2739, 115.5929.
_A = {"url": "https://opa.com/liberty", "read": "2026-11-16",
      "lat": -8.27372, "lon": 115.5929}
_B = {"url": "https://www.pressb.org/x", "read": "2026-11-15",
      "lat": "8 16 27.0 S", "lon": "115 35 34.4 E"}


def _mean_lat():
    return (-8.27372 + -(8 + 16 / 60 + 27.0 / 3600)) / 2


def _mean_lon():
    return (115.5929 + (115 + 35 / 60 + 34.4 / 3600)) / 2


def _entry(**overrides):
    entry = {
        "id": "research_id_usat_liberty",
        "name": "USAT Liberty",
        "area": "Tulamben",
        "country_code": "ID",
        "position": {
            "lat": round(_mean_lat(), 6),
            "lon": round(_mean_lon(), 6),
            "sources": [dict(_A), dict(_B)],
        },
        "max_depth_m": {"sources": [
            {"url": "https://opa.com/liberty", "read": "2026-11-16", "value": 29},
            {"url": "https://pressb.org/x", "read": "2026-11-15", "value": 30},
        ]},
        "min_depth_m": {"sources": [
            {"url": "https://opa.com/liberty", "read": "2026-11-16", "value": 5},
        ]},
        "entry": {"value": ["shore"], "sources": [
            {"url": "https://opa.com/liberty", "read": "2026-11-16"},
        ]},
        "types": {"value": ["wreck"], "sources": [
            {"url": "https://pressb.org/x", "read": "2026-11-15"},
        ]},
        "hazards": {"value": ["boat_traffic"], "sources": [
            {"url": "https://opa.com/liberty", "read": "2026-11-16"},
        ]},
        "review": {"state": "pending"},
        "withdrawn": None,
    }
    entry.update(overrides)
    return entry


def _check(*entries):
    return check.check_entries(list(entries), DOMAINS, today=TODAY)


def _one(entry):
    return _check(entry)[0]


def _rules(checked, fatal=True):
    return {f.rule for f in checked.findings if f.fatal == fatal}


def _with(path, value, entry=None):
    """The passing entry with one value replaced at [path]."""
    entry = copy.deepcopy(entry or _entry())
    target = entry
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return entry


class PassingTest(unittest.TestCase):
    def test_passing_entry(self):
        checked = _one(_entry())
        self.assertTrue(checked.ok, checked.findings)
        self.assertAlmostEqual(checked.position[0], _mean_lat(), places=6)
        self.assertAlmostEqual(checked.position[1], _mean_lon(), places=6)
        self.assertEqual(checked.max_depth, 30)
        self.assertEqual(checked.min_depth, 5)
        self.assertEqual(checked.entries, ["shore"])
        self.assertEqual(checked.types, ["wreck"])
        self.assertEqual(checked.hazards, ["boat_traffic"])
        self.assertEqual(checked.left_out, [])


class ShapeTest(unittest.TestCase):
    def test_id_prefix_and_repeat(self):
        self.assertIn("id_prefix", _rules(_one(_entry(id="curated_x"))))
        second = _entry(position=_entry()["position"], note="both stand")
        checked = _check(_entry(note="both stand"), second)
        self.assertIn("id_repeat", _rules(checked[1]))

    def test_unknown_field_is_free_text(self):
        self.assertIn("text_field", _rules(_one(_entry(summary="Great dive"))))

    def test_free_text_on_a_source_fails(self):
        entry = _with(("position", "sources", 0, "quote"), "lovely wreck")
        self.assertIn("text_field", _rules(_one(entry)))

    def test_name_over_60_fails(self):
        self.assertIn("name_length", _rules(_one(_entry(name="x" * 61))))

    def test_missing_name_or_country_fails(self):
        self.assertIn("shape", _rules(_one(_entry(name=""))))
        self.assertIn("shape", _rules(_one(_entry(country_code="Indonesia"))))

    def test_vocabulary(self):
        self.assertIn("vocabulary", _rules(_one(_with(("types", "value"), ["shipwreck"]))))
        self.assertIn("vocabulary", _rules(_one(_with(("entry", "value"), ["helicopter"]))))
        self.assertIn("vocabulary", _rules(_one(_with(("hazards", "value"), ["sharks"]))))

    def test_future_read_date_fails(self):
        entry = _with(("position", "sources", 0, "read"), "2026-11-18")
        self.assertIn("read_date", _rules(_one(entry)))

    def test_a_read_date_one_day_ahead_passes(self):
        # A researcher east of UTC can be a day ahead of the checker.
        entry = _with(("position", "sources", 0, "read"), "2026-11-17")
        self.assertTrue(_one(entry).ok, _one(entry).findings)

    def test_a_review_that_is_not_an_object_is_reported(self):
        checked = _one(_entry(review="approved"))
        self.assertIn("shape", _rules(checked))
        self.assertNotEqual(checked.state, "approved")
        check.report([checked])

    def test_an_unreadable_read_date_fails(self):
        entry = _with(("position", "sources", 0, "read"), "16 Nov 2026")
        self.assertIn("read_date", _rules(_one(entry)))

    def test_no_review_reads_as_pending(self):
        entry = _entry()
        del entry["review"]
        self.assertEqual(_one(entry).state, "pending")

    def test_missing_read_date_fails(self):
        entry = _entry()
        del entry["types"]["sources"][0]["read"]
        self.assertIn("read_date", _rules(_one(entry)))

    def test_review_state(self):
        self.assertIn("shape", _rules(_one(_entry(review={"state": "maybe"}))))
        self.assertIn("shape", _rules(_one(_entry(review={"state": "approved"}))))
        self.assertTrue(_one(_entry(review={"state": "approved", "date": "2026-11-17"})).ok)
        self.assertIn("shape", _rules(_one(_entry(review={"state": "rejected", "date": "2026-11-17"}))))

    def test_withdrawal_shape(self):
        self.assertIn("shape", _rules(_one(_entry(withdrawn={"reason": "bored", "date": "2026-12-01"}))))
        self.assertIn("shape", _rules(_one(_entry(withdrawn={"reason": "position"}))))
        self.assertTrue(_one(_entry(withdrawn={"reason": "position", "date": "2026-12-01"})).ok)

    def test_a_withdrawal_date_is_an_iso_date_string(self):
        for bad in (20261201, "1 Dec 2026", "2026-13-01"):
            entry = _entry(withdrawn={"reason": "position", "date": bad})
            self.assertIn("shape", _rules(_one(entry)), bad)


class DomainTest(unittest.TestCase):
    def test_unknown_domain_fails(self):
        entry = _with(("types", "sources", 0, "url"), "https://elsewhere.net/x")
        self.assertIn("unknown_domain", _rules(_one(entry)))

    def test_never_source_fails(self):
        entry = _with(("types", "sources", 0, "url"), "https://www.bad.eu/x")
        self.assertIn("never_source", _rules(_one(entry)))


class PositionTest(unittest.TestCase):
    def test_one_counting_source(self):
        entry = _entry()
        entry["position"]["sources"] = [dict(_A)]
        entry["position"]["lat"], entry["position"]["lon"] = _A["lat"], _A["lon"]
        self.assertIn("position_sources", _rules(_one(entry)))

    def test_two_sources_one_domain(self):
        entry = _with(("position", "sources", 1, "url"), "https://shop.opa.com/y")
        self.assertIn("position_domains", _rules(_one(entry)))

    def test_whole_minute_figure_fails(self):
        entry = _entry()
        entry["position"]["sources"][1].update(lat="8 16 S", lon="115 36 E")
        self.assertIn("position_precision", _rules(_one(entry)))

    def test_two_decimal_figure_fails(self):
        entry = _entry()
        entry["position"]["sources"][1].update(lat=-8.27, lon=115.59)
        self.assertIn("position_precision", _rules(_one(entry)))

    def test_a_figure_that_does_not_parse_fails(self):
        entry = _with(("position", "sources", 1, "lat"), "-8 16 27 S")
        self.assertIn("shape", _rules(_one(entry)))

    def test_counting_figures_200m_apart_fail(self):
        entry = _entry()
        entry["position"]["sources"][1].update(lat=-8.27552, lon=115.5929)
        lat = (-8.27372 + -8.27552) / 2
        entry["position"].update(lat=lat, lon=115.5929)
        self.assertIn("position_spread", _rules(_one(entry)))

    def test_cite_only_2km_off_passes(self):
        entry = _entry()
        entry["position"]["sources"].append(
            {"url": "https://dir.com/x", "read": "2026-11-16",
             "lat": -8.2919, "lon": 115.5929}
        )
        checked = _one(entry)
        self.assertTrue(checked.ok, checked.findings)
        self.assertAlmostEqual(checked.position[0], _mean_lat(), places=6)

    def test_an_unreadable_cite_only_figure_is_a_note(self):
        entry = _entry()
        entry["position"]["sources"].append(
            {"url": "https://dir.com/x", "read": "2026-11-16",
             "lat": "8 16 S", "lon": "east of the jetty"}
        )
        checked = _one(entry)
        self.assertTrue(checked.ok, checked.findings)
        self.assertIn("position_unread", _rules(checked, fatal=False))

    def test_mean_across_the_antimeridian(self):
        # Taveuni, Fiji: 30 m either side of 180 degrees.
        entry = _entry(country_code="FJ")
        entry["position"]["sources"] = [
            {"url": "https://opa.com/t", "read": "2026-11-16",
             "lat": -16.80012, "lon": 179.99985},
            {"url": "https://pressb.org/t", "read": "2026-11-16",
             "lat": -16.80012, "lon": -179.99985},
        ]
        entry["position"].update(lat=-16.80012, lon=180.0)
        checked = _one(entry)
        self.assertTrue(checked.ok, checked.findings)
        self.assertAlmostEqual(abs(checked.position[1]), 180.0, places=6)

    def test_a_stated_position_that_is_not_numbers_fails(self):
        entry = _with(("position", "lat"), "eight south")
        self.assertIn("shape", _rules(_one(entry)))

    def test_mean_more_than_10m_off_fails(self):
        entry = _with(("position", "lat"), round(_mean_lat(), 6) + 0.0002)
        self.assertIn("position_mean", _rules(_one(entry)))

    def test_no_position_fails(self):
        entry = _entry()
        del entry["position"]
        self.assertIn("position_sources", _rules(_one(entry)))


class DepthTest(unittest.TestCase):
    def _maxima(self, *values):
        entry = _entry()
        entry["max_depth_m"]["sources"] = [
            {"url": url, "read": "2026-11-15", "value": value}
            for url, value in zip(
                ["https://opa.com/a", "https://pressb.org/b"], values
            )
        ]
        return entry

    def test_depth_spread_within_the_line_ships_the_deepest(self):
        checked = _one(self._maxima(32, 40))
        self.assertEqual(checked.max_depth, 40)
        self.assertEqual(checked.min_depth, 5)

    def test_depth_spread_beyond_the_line_ships_nothing(self):
        checked = _one(self._maxima(8, 15))
        self.assertTrue(checked.ok)
        self.assertIsNone(checked.max_depth)
        self.assertIsNone(checked.min_depth)
        self.assertIn("depth_spread", _rules(checked, fatal=False))

    def test_a_spread_of_five_metres_at_ten_is_within(self):
        # 5 m is not more than 5 m.
        self.assertEqual(_one(self._maxima(5, 10)).max_depth, 10)

    def test_cite_only_depth_is_not_used(self):
        entry = _entry()
        entry["max_depth_m"]["sources"] = [
            {"url": "https://dir.com/a", "read": "2026-11-15", "value": 40}
        ]
        checked = _one(entry)
        self.assertIsNone(checked.max_depth)
        self.assertIsNone(checked.min_depth)

    def test_feet_converted(self):
        entry = _entry()
        entry["max_depth_m"]["sources"] = [
            {"url": "https://opa.com/a", "read": "2026-11-15", "value": 100, "unit": "ft"}
        ]
        self.assertAlmostEqual(_one(entry).max_depth, 30.48)

    def test_unknown_unit_fails(self):
        entry = _with(("max_depth_m", "sources", 0, "unit"), "fathoms")
        self.assertIn("shape", _rules(_one(entry)))

    def test_min_deeper_than_max_fails(self):
        entry = _with(("min_depth_m", "sources", 0, "value"), 35)
        self.assertIn("depth_order", _rules(_one(entry)))

    def test_depth_written_by_hand_fails(self):
        self.assertIn("depth_by_hand", _rules(_one(_entry(max_depth_m=30))))

    def test_no_depth_at_all_passes_with_none(self):
        entry = _entry()
        del entry["max_depth_m"], entry["min_depth_m"]
        checked = _one(entry)
        self.assertTrue(checked.ok, checked.findings)
        self.assertIsNone(checked.max_depth)

    def test_a_depth_that_is_not_a_number_fails(self):
        entry = _with(("max_depth_m", "sources", 0, "value"), "thirty")
        self.assertIn("shape", _rules(_one(entry)))


class FactTest(unittest.TestCase):
    def test_contradicted_type_left_out(self):
        entry = _entry()
        entry["types"]["sources"].append(
            {"url": "https://opa.com/liberty", "read": "2026-11-16", "contradicts": True}
        )
        checked = _one(entry)
        self.assertTrue(checked.ok)
        self.assertEqual(checked.types, [])
        self.assertIn("fact_contradicted", _rules(checked, fatal=False))

    def test_a_fact_may_be_absent(self):
        entry = _entry()
        del entry["hazards"]
        checked = _one(entry)
        self.assertTrue(checked.ok, checked.findings)
        self.assertEqual(checked.hazards, [])

    def test_a_fact_value_that_is_not_a_list_fails(self):
        entry = _with(("types", "value"), "wreck")
        self.assertIn("shape", _rules(_one(entry)))

    def test_value_without_counting_source_fails(self):
        entry = _with(("types", "sources", 0, "url"), "https://dir.com/x")
        self.assertIn("fact_unsourced", _rules(_one(entry)))


class NeighbourTest(unittest.TestCase):
    def _near(self):
        near = _entry(id="research_id_coral_garden", name="Coral Garden")
        return near

    def test_two_entries_within_150m_fail_without_note(self):
        checked = _check(_entry(), self._near())
        self.assertIn("neighbour", _rules(checked[1]))

    def test_a_note_lets_both_stand(self):
        checked = _check(_entry(), _entry(**{**self._near(), "note": "separate site"}))
        self.assertTrue(all(c.ok for c in checked), [c.findings for c in checked])

    def test_a_withdrawn_entry_is_not_a_neighbour(self):
        withdrawn = _entry(withdrawn={"reason": "position", "date": "2026-12-01"})
        checked = _check(withdrawn, self._near())
        self.assertTrue(checked[1].ok, checked[1].findings)

    def test_a_rejected_entry_is_not_a_neighbour(self):
        rejected = _entry(review={"state": "rejected", "date": "2026-11-17",
                                  "reason": "weak sources"})
        checked = _check(rejected, self._near())
        self.assertTrue(checked[1].ok, checked[1].findings)

    def test_withdrawn_entry_still_checked(self):
        entry = _entry(name="", withdrawn={"reason": "position", "date": "2026-12-01"})
        self.assertFalse(_one(entry).ok)


class MainTest(unittest.TestCase):
    def _run(self, entries, withdrawn_curated=()):
        with tempfile.TemporaryDirectory() as tmp:
            sites = Path(tmp) / "sites.json"
            sites.write_text(json.dumps({
                "sites": entries, "withdrawn_curated": list(withdrawn_curated),
            }), encoding="utf-8")
            domains = Path(tmp) / "domains.json"
            domains.write_text(json.dumps({
                "counting": DOMAINS.counting,
                "cite_only": DOMAINS.cite_only,
                "never": DOMAINS.never,
            }), encoding="utf-8")
            out = io.StringIO()
            with redirect_stdout(out):
                code = check.main(
                    ["--file", str(sites), "--domains", str(domains)], today=TODAY
                )
            return code, out.getvalue()

    def test_a_clean_file_exits_zero_and_reports(self):
        code, text = self._run([_entry()])
        self.assertEqual(code, 0)
        self.assertIn("Tulamben", text)
        self.assertIn("1 pending", text)

    def test_a_failing_entry_exits_one_naming_it(self):
        code, text = self._run([_entry(name="")])
        self.assertEqual(code, 1)
        self.assertIn("research_id_usat_liberty", text)

    def test_review_writes_the_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "review.html"
            sites = Path(tmp) / "sites.json"
            sites.write_text(json.dumps({"sites": [_entry()]}), encoding="utf-8")
            domains = Path(tmp) / "domains.json"
            domains.write_text(json.dumps({
                "counting": DOMAINS.counting, "cite_only": DOMAINS.cite_only,
                "never": DOMAINS.never,
            }), encoding="utf-8")
            with redirect_stdout(io.StringIO()) as printed:
                code = check.main(["--file", str(sites), "--domains", str(domains),
                                   "--review", str(out)], today=TODAY)
            self.assertEqual(code, 0)
            self.assertIn("USAT Liberty", out.read_text(encoding="utf-8"))
            self.assertIn("Review page", printed.getvalue())

    def test_an_empty_file_passes(self):
        self.assertEqual(self._run([])[0], 0)

    def test_a_bad_curated_withdrawal_exits_one_naming_it(self):
        for bad in (
            {"id": "curated_x", "reason": "position", "date": 20261202},
            {"id": "curated_x", "reason": "bored", "date": "2026-12-02"},
            {"id": "osm_node_1", "reason": "position", "date": "2026-12-02"},
            "curated_x",
            {"id": "curated_x", "reason": "position", "date": "2026-12-02",
             "replaced_by": 7},
        ):
            code, text = self._run([], [bad])
            self.assertEqual(code, 1, bad)
            self.assertIn("curated_x" if isinstance(bad, str) else bad["id"], text)
        self.assertEqual(self._run([], [
            {"id": "curated_x", "reason": "position", "date": "2026-12-02"}])[0], 0)


if __name__ == "__main__":
    unittest.main()
