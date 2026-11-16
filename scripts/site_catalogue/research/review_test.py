#!/usr/bin/env python3
"""Unit tests for review.py.

Run: python3 scripts/site_catalogue/research/review_test.py

The maintainer approves a batch of researched sites from one page. These
tests pin that the page needs no network, groups entries by area, shows
every source's figure and its distance from the point that would ship,
keeps failing entries out of the approval list, and escapes what it
prints.
"""

import os
import re
import sys
import unittest
from datetime import date

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE), os.path.dirname(os.path.dirname(_HERE))]

import check  # noqa: E402
import review  # noqa: E402
from check_test import DOMAINS, TODAY, _entry, _map_source, _placed  # noqa: E402


def _page(*entries):
    return review.render(check.check_entries(list(entries), DOMAINS, today=TODAY), DOMAINS)


class ReviewPageTest(unittest.TestCase):
    def test_offline_html(self):
        page = _page(_entry())
        self.assertTrue(page.startswith("<!doctype html>"))
        self.assertNotIn("<script", page)
        for tag in re.findall(r"<(?:link|img)[^>]*>", page):
            self.assertNotIn("http", tag)

    def test_one_row_per_entry_grouped_by_area(self):
        second = _entry(id="research_my_barracuda_point", name="Barracuda Point",
                        area="Sipadan", distinct_from=["research_id_usat_liberty"])
        page = _page(_entry(distinct_from=["research_my_barracuda_point"]), second)
        self.assertEqual(page.count('class="entry'), 2)
        self.assertLess(page.index("Sipadan"), page.index("Tulamben"))

    def test_area_heading_counts(self):
        page = _page(_entry(), _entry(id="research_id_b", name="", note="x"))
        self.assertIn("Tulamben (2 entries: 1 pass, 1 fail)", page)

    def test_failing_entry_shows_rule_and_no_approval_mark(self):
        page = _page(_entry(name="x" * 61))
        self.assertIn("name_length", page)
        self.assertIn("Not offered for approval", page)

    def test_a_passing_pending_entry_asks_for_a_decision(self):
        self.assertIn("Approve or reject", _page(_entry()))

    def test_source_distance_from_point(self):
        entry = _entry()
        entry["position"]["sources"].append(
            {"url": "https://dir.com/x", "read": "2026-11-16",
             "lat": -8.27391 - 0.01367, "lon": 115.5929}
        )
        page = _page(entry)
        self.assertRegex(page, r"1,5\d\d m")
        self.assertIn("cite only", page)
        self.assertIn("counting", page)

    def test_osm_map_link(self):
        page = _page(_entry())
        self.assertRegex(
            page,
            r'href="https://www\.openstreetmap\.org/\?mlat=-8\.27\d+&amp;'
            r'mlon=115\.59\d+#map=17/-8\.27\d+/115\.59\d+"',
        )

    def test_ships_as_line(self):
        page = _page(_entry())
        self.assertIn("Shore dive to a wreck.", page)
        self.assertIn("5 to 30 m", page)
        self.assertIn("Boat traffic overhead.", page)

    def test_a_maximum_alone_reads_to_that_depth(self):
        entry = _entry()
        del entry["min_depth_m"]
        self.assertIn("to 30 m", _page(entry))

    def test_an_unreadable_cited_figure_and_a_stray_source(self):
        entry = _entry()
        entry["position"]["sources"] += [
            {"url": "https://dir.com/x", "read": "2026-11-16",
             "lat": "8 16 S", "lon": "east of the jetty"},
            "not a source",
        ]
        page = _page(entry)
        self.assertIn("unreadable", page)
        self.assertIn("Approve or reject", page)

    def test_left_out_facts_are_shown(self):
        page = _page(_entry(max_depth_m={"sources": [
            {"url": "https://opa.com/a", "read": "2026-11-15", "value": 8},
            {"url": "https://pressb.org/b", "read": "2026-11-15", "value": 15},
        ]}))
        self.assertIn("depth left out", page)

    def test_names_escaped(self):
        page = _page(_entry(name="<b>Liberty</b>"))
        self.assertNotIn("<b>Liberty", page)
        self.assertIn("&lt;b&gt;Liberty", page)

    def test_decided_entries_are_folded_below(self):
        # Both stand at one point: each names the other as a separate site.
        approved = _entry(id="research_id_b", name="Coral Garden",
                          distinct_from=["research_id_usat_liberty"],
                          review={"state": "approved", "date": "2026-11-17"})
        page = _page(_entry(distinct_from=["research_id_b"]), approved)
        self.assertIn("<details", page)
        self.assertLess(page.index("USAT Liberty"), page.index("<details"))
        self.assertGreater(page.index("Coral Garden"), page.index("<details"))

    def test_a_map_read_entry_shows_its_map_link(self):
        page = _page(_placed([_map_source(-8.2759, 115.5937)], -8.2759, 115.5937))
        self.assertIn('href="https://opa.com/m.jpg"', page)
        self.assertIn("map image", page)

    def test_the_route_is_shown(self):
        page = _page(_placed([_map_source(-8.2759, 115.5937)], -8.2759, 115.5937))
        self.assertIn("Placed by", page)
        self.assertIn("a counting page&#x27;s map", page)
        self.assertIn("two stated figures that agree", _page(_entry()))

    def test_a_flag_is_shown_and_does_not_block_approval(self):
        a = _placed([_map_source(-8.2700, 115.5929)], -8.2700, 115.5929,
                    id="research_id_a", name="A")
        b = _placed([_map_source(-8.2727, 115.5929)], -8.2727, 115.5929,
                    id="research_id_b", name="B")
        page = _page(a, b)
        self.assertIn("neighbour_near", page)
        self.assertNotIn("Not offered for approval", page)
        self.assertIn("Approve or reject", page)

    def test_the_openstreetmap_link_is_at_the_shipped_point(self):
        page = _page(_placed([_map_source(-8.2759, 115.5937)], -8.2759, 115.5937))
        self.assertIn("mlat=-8.275900", page)

    def test_a_source_without_a_usable_address_still_renders(self):
        entry = _entry()
        entry["position"]["sources"] += [
            {"read": "2026-11-16", "lat": -8.2739, "lon": 115.5929},
            {"url": "not an address", "read": "2026-11-16",
             "lat": -8.2739, "lon": 115.5929},
        ]
        page = _page(entry)
        self.assertIn("Not offered for approval", page)
        self.assertIn("no address", page)
        self.assertIn("not an address", page)
        self.assertNotIn('href=""', page)

    def test_an_empty_batch(self):
        self.assertIn("No researched sites", _page())


if __name__ == "__main__":
    unittest.main()
