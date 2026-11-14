#!/usr/bin/env python3
"""Unit tests for src_wikidata.py.

Run: python3 scripts/site_catalogue/src_wikidata_test.py

Wikidata lists a few hundred dive sites and tens of thousands of wrecks,
most of the wrecks imported from loss registers with a position good to a
minute of arc at best. These tests pin the gate: a wreck needs a Wikipedia
article and a position finer than a minute.
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_wikidata  # noqa: E402

_EARTH = "http://www.wikidata.org/entity/Q2"


def _binding(item, label, lat, lon, precision=None, globe=_EARTH):
    binding = {
        "item": {"value": f"http://www.wikidata.org/entity/{item}"},
        "lat": {"value": str(lat)},
        "lon": {"value": str(lon)},
        "globe": {"value": globe},
    }
    if label is not None:
        binding["label"] = {"value": label}
    if precision is not None:
        binding["precision"] = {"value": str(precision)}
    return binding


def _row(**overrides):
    row = dict(
        item="Q14213870", label="SAS Good Hope", lat=-34.267567,
        lon=18.480833, precision=2.77778e-5, globe=_EARTH,
    )
    row.update(overrides)
    return row


class RowsTest(unittest.TestCase):
    def test_an_answer_becomes_one_row_per_item(self):
        rows = src_wikidata.rows_from_bindings([
            _binding("Q1", "Reef", "-34.17675", "18.4595", "2.77778E-5"),
            _binding("Q2", None, "1.5", "2.5"),
        ])
        self.assertEqual(
            rows[0],
            dict(item="Q1", label="Reef", lat=-34.17675, lon=18.4595,
                 precision=2.77778e-5, globe=_EARTH),
        )
        self.assertIsNone(rows[1]["label"])
        self.assertIsNone(rows[1]["precision"])

    def test_an_item_with_two_positions_keeps_the_more_precise(self):
        rows = src_wikidata.rows_from_bindings([
            _binding("Q1", "Reef", "10.5", "20.5", "0.0166667"),
            _binding("Q1", "Reef", "10.4821", "20.5113", "1.0E-4"),
        ])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["lat"], 10.4821)


class SiteRecordsTest(unittest.TestCase):
    def test_a_dive_site_is_a_dive_site_record(self):
        records, dropped = src_wikidata.site_records([_row()])
        self.assertEqual(dict(dropped), {})
        record = records[0]
        self.assertEqual(record["id"], "wikidata_Q14213870")
        self.assertEqual(record["name"], "SAS Good Hope")
        self.assertEqual(record["source"], "wikidata")
        self.assertEqual(record["kind"], "site")
        self.assertEqual(record["types"], [])
        self.assertEqual(
            record["source_ref"], "https://www.wikidata.org/wiki/Q14213870"
        )

    def test_a_dive_site_is_not_gated_on_precision(self):
        records, _ = src_wikidata.site_records([_row(precision=0.0166667)])
        self.assertEqual(len(records), 1)

    def test_what_is_dropped(self):
        for change, reason in [
            (dict(label=None), "no_label"),
            (dict(label="Q14213870"), "no_label"),
            (dict(globe="http://www.wikidata.org/entity/Q111"), "not_on_earth"),
        ]:
            _, dropped = src_wikidata.site_records([_row(**change)])
            self.assertEqual(dict(dropped), {reason: 1}, change)


class WreckRecordsTest(unittest.TestCase):
    def test_a_wreck_with_a_fine_position_is_a_register_record(self):
        records, dropped = src_wikidata.wreck_records([_row()])
        self.assertEqual(dict(dropped), {})
        self.assertEqual(records[0]["kind"], "register")
        self.assertEqual(records[0]["types"], ["wreck"])
        self.assertEqual(records[0]["id"], "wikidata_Q14213870")

    def test_a_position_good_to_a_minute_at_best_is_dropped(self):
        for change in (
            dict(precision=0.0166667),          # stated as one arc-minute
            dict(precision=1.0),                # a whole degree
            # A whole-minute position, whatever precision it claims.
            dict(lat=58.566667, lon=-25.5, precision=2.77778e-4),
            dict(lat=36.75, lon=-22.833333, precision=None),
        ):
            _, dropped = src_wikidata.wreck_records([_row(**change)])
            self.assertEqual(dict(dropped), {"coarse_position": 1}, change)

    def test_no_stated_precision_passes_on_a_finely_written_position(self):
        records, _ = src_wikidata.wreck_records(
            [_row(lat=57.607447, lon=-1.807537, precision=None)]
        )
        self.assertEqual(len(records), 1)


class QueryTest(unittest.TestCase):
    def test_wreck_positions_and_articles_are_asked_for_separately(self):
        # Joined in one query, the service times out.
        self.assertEqual(len(src_wikidata.WRECK_POSITION_QUERIES), 2)
        self.assertEqual(len(src_wikidata.WRECK_ARTICLE_QUERIES), 2)
        for query in src_wikidata.WRECK_POSITION_QUERIES:
            self.assertIn("wikibase:geoPrecision", query)
            self.assertNotIn("wikiGroup", query)
        for query in src_wikidata.WRECK_ARTICLE_QUERIES:
            self.assertIn('wikibase:wikiGroup "wikipedia"', query)
            self.assertNotIn("geoPrecision", query)
        for queries in (src_wikidata.WRECK_POSITION_QUERIES,
                        src_wikidata.WRECK_ARTICLE_QUERIES):
            self.assertIn("wd:Q852190", queries[0])
            self.assertIn("wd:Q906512", queries[1])
            self.assertIn("wd:Q1786766", queries[1])

    def test_the_site_query_asks_for_the_dive_site_class(self):
        self.assertIn("wd:Q26205080", src_wikidata.SITE_QUERY)
        self.assertNotIn("wikiGroup", src_wikidata.SITE_QUERY)


class ArticleTest(unittest.TestCase):
    def test_only_wrecks_with_a_wikipedia_article_are_kept(self):
        rows = [_row(item="Q1"), _row(item="Q2"), _row(item="Q3")]
        articles = [
            {"item": {"value": "http://www.wikidata.org/entity/Q1"}},
            {"item": {"value": "http://www.wikidata.org/entity/Q3"}},
            {"item": {"value": "http://www.wikidata.org/entity/Q9"}},
        ]
        kept = src_wikidata.with_article(rows, articles)
        self.assertEqual([row["item"] for row in kept], ["Q1", "Q3"])


if __name__ == "__main__":
    unittest.main()
