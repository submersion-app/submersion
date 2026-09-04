#!/usr/bin/env python3
"""Unit tests for sea_area_harvester.py.

Run: python3 scripts/sea_area_harvester_test.py

These cover the ring encoder and the per-feature builder. The runtime
resolver trusts three things about the shipped table -- rings are closed,
degenerate rings are gone, and areas are sorted ascending so the smallest
match wins -- and a generator that quietly stops honouring any of them
would name the wrong sea on a diver's phone.
"""

import importlib.util
import os
import unittest
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))

try:
    import shapely  # noqa: F401

    _HAS_SHAPELY = True
except ImportError:  # pragma: no cover - exercised only on bare runners
    _HAS_SHAPELY = False

if _HAS_SHAPELY:
    _spec = importlib.util.spec_from_file_location(
        "sea_area_harvester",
        os.path.join(_HERE, "sea_area_harvester.py"),
    )
    sea_area_harvester = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(sea_area_harvester)


def _square(x, y, size):
    """A closed square ring, counter-clockwise from the lower-left corner."""
    return [
        (x, y),
        (x + size, y),
        (x + size, y + size),
        (x, y + size),
        (x, y),
    ]


def _polygon(outer, holes=()):
    return {
        "type": "Polygon",
        "coordinates": [list(outer)] + [list(h) for h in holes],
    }


@unittest.skipUnless(_HAS_SHAPELY, "shapely is not installed")
class FlattenRingTest(unittest.TestCase):
    def test_flattens_to_alternating_lon_lat(self):
        flat = sea_area_harvester.flatten_ring(_square(0, 0, 10))
        self.assertEqual(flat, [0, 0, 10, 0, 10, 10, 0, 10, 0, 0])

    def test_closes_a_ring_that_does_not_repeat_its_first_point(self):
        flat = sea_area_harvester.flatten_ring([(0, 0), (10, 0), (10, 10)])
        self.assertEqual(flat[:2], flat[-2:])

    def test_drops_points_that_rounding_collapsed_together(self):
        # Two points 1e-6 degrees apart round to the same coordinate.
        flat = sea_area_harvester.flatten_ring(
            [(0, 0), (0.0000001, 0), (10, 0), (10, 10), (0, 0)]
        )
        self.assertEqual(flat, [0, 0, 10, 0, 10, 10, 0, 0])

    def test_rejects_a_ring_that_rounding_flattened_below_a_triangle(self):
        self.assertIsNone(
            sea_area_harvester.flatten_ring(
                [(0, 0), (0.0000001, 0), (0.0000002, 0), (0, 0)]
            )
        )


@unittest.skipUnless(_HAS_SHAPELY, "shapely is not installed")
class BuildAreaTest(unittest.TestCase):
    def test_renames_iho_labels_to_the_name_a_diver_writes(self):
        area = sea_area_harvester.build_area(
            "Mediterranean Sea - Western Basin", _polygon(_square(0, 0, 10))
        )
        self.assertEqual(area["name"], "Mediterranean Sea")

    def test_keeps_a_name_that_needs_no_override(self):
        area = sea_area_harvester.build_area(
            "Caribbean Sea", _polygon(_square(0, 0, 10))
        )
        self.assertEqual(area["name"], "Caribbean Sea")

    def test_reports_the_bounding_box_and_extent(self):
        area = sea_area_harvester.build_area(
            "Test Sea", _polygon(_square(5, -3, 10))
        )
        self.assertEqual(area["bbox"], [5, -3, 15, 7])
        self.assertAlmostEqual(area["area"], 100.0, places=3)

    def test_keeps_a_landmass_big_enough_to_hold_an_inland_dive_site(self):
        big = 1.0  # square degrees, far above MIN_HOLE_AREA
        area = sea_area_harvester.build_area(
            "Test Sea",
            _polygon(_square(0, 0, 10), holes=[_square(4, 4, big)]),
        )
        self.assertEqual(len(area["polygons"][0]["holes"]), 1)

    def test_drops_islets_too_small_to_matter(self):
        # A site on a small island should report the sea around it, and
        # keeping every islet grows the asset roughly fourteenfold.
        tiny = 0.01  # square degrees, below MIN_HOLE_AREA
        area = sea_area_harvester.build_area(
            "Test Sea",
            _polygon(_square(0, 0, 10), holes=[_square(4, 4, tiny)]),
        )
        self.assertNotIn("holes", area["polygons"][0])


@unittest.skipUnless(_HAS_SHAPELY, "shapely is not installed")
class NormalizeLabelTest(unittest.TestCase):
    def test_folds_a_ligature_back_to_plain_letters(self):
        # The French Pacific labels really do arrive this way.
        self.assertEqual(
            sea_area_harvester.normalize_label("oc\u00e9an Paci\ufb01que nord"),
            "oc\u00e9an Pacifique nord",
        )

    def test_trims_surrounding_whitespace(self):
        self.assertEqual(sea_area_harvester.normalize_label("  Rotes Meer "), "Rotes Meer")

    def test_leaves_ordinary_labels_alone(self):
        for label in ("Rotes Meer", "\u7ea2\u6d77", "\u0627\u0644\u0628\u062d\u0631 \u0627\u0644\u0623\u062d\u0645\u0631", "mer Rouge"):
            self.assertEqual(sea_area_harvester.normalize_label(label), label)


@unittest.skipUnless(_HAS_SHAPELY, "shapely is not installed")
class TranslationTest(unittest.TestCase):
    def test_attaches_translations_to_the_matching_area(self):
        output = sea_area_harvester.build(
            {
                "features": [
                    {
                        "properties": {"name": "Red Sea"},
                        "geometry": _polygon(_square(0, 0, 10)),
                    }
                ]
            },
            {"Red Sea": {"de": "Rotes Meer", "fr": "mer Rouge"}},
        )
        self.assertEqual(
            output["areas"][0]["names"], {"de": "Rotes Meer", "fr": "mer Rouge"}
        )

    def test_omits_the_key_entirely_when_nothing_is_translated(self):
        output = sea_area_harvester.build(
            {
                "features": [
                    {
                        "properties": {"name": "Red Sea"},
                        "geometry": _polygon(_square(0, 0, 10)),
                    }
                ]
            },
            {},
        )
        self.assertNotIn("names", output["areas"][0])

    def test_every_shipped_sea_has_a_reviewed_wikidata_item(self):
        # A name added to NAME_OVERRIDES without a QID would silently ship
        # untranslated.
        qids = set(sea_area_harvester.WIKIDATA_QIDS.values())
        self.assertEqual(
            len(qids),
            len(sea_area_harvester.WIKIDATA_QIDS),
            "two seas point at the same Wikidata item",
        )
        for name, qid in sea_area_harvester.WIKIDATA_QIDS.items():
            self.assertRegex(qid, r"^Q\d+$", f"{name} has a malformed QID")

    def test_english_is_not_fetched_because_the_name_is_the_fallback(self):
        self.assertNotIn("en", sea_area_harvester.TRANSLATION_LANGUAGES)


@unittest.skipUnless(_HAS_SHAPELY, "shapely is not installed")
class BuildTest(unittest.TestCase):
    def _payload(self, *features):
        return {
            "features": [
                {"properties": {"name": name}, "geometry": geometry}
                for name, geometry in features
            ]
        }

    def test_sorts_areas_ascending_so_the_smallest_match_wins(self):
        output = sea_area_harvester.build(
            self._payload(
                ("Big Ocean", _polygon(_square(0, 0, 40))),
                ("Small Gulf", _polygon(_square(1, 1, 2))),
            )
        )
        self.assertEqual(
            [a["name"] for a in output["areas"]], ["Small Gulf", "Big Ocean"]
        )

    def test_stamps_a_timestamp_that_actually_parses(self):
        # isoformat() already writes "+00:00", so appending "Z" would give
        # "...+00:00Z" and every ISO-8601 parser would reject it.
        output = sea_area_harvester.build(
            self._payload(("Test Sea", _polygon(_square(0, 0, 10))))
        )
        stamp = output["metadata"]["generated_at"]
        self.assertTrue(stamp.endswith("Z"), stamp)
        self.assertNotIn("+00:00", stamp)
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        self.assertEqual(parsed.tzinfo, timezone.utc)

    def test_carries_the_attribution_the_licence_requires(self):
        output = sea_area_harvester.build(
            self._payload(("Test Sea", _polygon(_square(0, 0, 10))))
        )
        metadata = output["metadata"]
        self.assertEqual(metadata["license"], "CC-BY 4.0")
        self.assertIn("Flanders Marine Institute", metadata["citation"])
        self.assertEqual(metadata["total_count"], 1)


if __name__ == "__main__":
    unittest.main()
