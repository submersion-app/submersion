#!/usr/bin/env python3
"""Unit tests for places.py.

Run: python3 scripts/site_catalogue/places_test.py

A register wreck lies at sea, where a geocoder answers nothing, so the
catalogue places its records against boundaries it holds offline. These
tests pin the lookup on hand-made squares: inside a unit, at sea near one,
too far out, a territory over its parent state, a lake, a region, and the
antimeridian.
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import places  # noqa: E402


def _square(south, west, north, east, **properties):
    return {
        "type": "Feature",
        "properties": properties,
        "geometry": {
            "type": "Polygon",
            "coordinates": [[
                [west, south], [east, south], [east, north], [west, north],
                [west, south],
            ]],
        },
    }


def _unit(south, west, north, east, code, admin, *, sovereign=None,
          subunit=None, **extra):
    return _square(
        south, west, north, east,
        ISO_A2_EH=code, ADMIN=admin, SOVEREIGNT=sovereign or admin,
        SUBUNIT=subunit or admin, NAME_EN=subunit or admin,
        SU_A3=extra.pop("su_a3", admin[:3].upper()), **extra,
    )


# A state, a territory of it with its own code, a neighbour, and a unit
# with no ISO code that belongs to the state.
_FRANCE = _unit(40, 0, 50, 10, "FR", "France")
_TAHITI = _unit(-18, -150, -17, -149, "PF", "French Polynesia",
                sovereign="France")
_SWISS = _unit(45, 10, 48, 12, "CH", "Switzerland")
_GERMANY = _unit(48, 10, 55, 15, "DE", "Germany")
_BASE = _unit(34, 32, 35, 33, "-99", "Akrotiri", sovereign="France")
_FIJI_EAST = _unit(-17, -180, -16, -179.9, "FJ", "Fiji")

_KNOWN = {
    "france": "FR", "french polynesia": "PF", "switzerland": "CH",
    "germany": "DE", "fiji": "FJ", "micronesia": "FM",
    "united kingdom": "GB", "england": "GB",
}

_REGIONS = [
    _square(42, 2, 44, 4, name_en="Occitanie", name="Occitanie",
            iso_a2="FR", iso_3166_2="FR-OCC"),
    _square(45, 10, 46, 11, name_en="Ticino", name="Ticino", iso_a2="CH",
            iso_3166_2="CH-TI"),
    _square(12, -69, 13, -68, name_en="Bonaire", name="Bonaire",
            iso_a2="BQ", iso_3166_2="BQ-BO"),
    _square(30, 30, 31, 31, name_en="جنوب سيناء", name="Janub Sina",
            iso_a2="EG", iso_3166_2="EG-JS"),
]

_LAKES = [_square(46, 6, 46.5, 7, name="Lake Geneva")]


def _places(units=None, preferred=None):
    return places.Places(
        places.UnitIndex(units or [
            _FRANCE, _TAHITI, _SWISS, _GERMANY, _BASE, _FIJI_EAST,
        ]),
        places.UnitIndex(_REGIONS),
        places.UnitIndex(_LAKES),
        known_names=_KNOWN,
        preferred_names=preferred or {},
    )


class UnitIndexTest(unittest.TestCase):
    def test_a_point_inside_a_unit_finds_it(self):
        index = places.UnitIndex([_FRANCE, _SWISS])
        self.assertEqual(index.containing(45, 5)["ADMIN"], "France")
        self.assertEqual(index.containing(46, 11)["ADMIN"], "Switzerland")
        self.assertIsNone(index.containing(30, 5))

    def test_a_point_at_sea_finds_the_nearest_unit_within_reach(self):
        index = places.UnitIndex([_FRANCE])
        # 0.27 degrees of latitude south of the square's edge: 30 km.
        properties, distance = index.nearest(39.73, 5, 370)
        self.assertEqual(properties["ADMIN"], "France")
        self.assertAlmostEqual(distance, 30, delta=3)
        self.assertIsNone(index.nearest(39.73, 5, 10))
        self.assertIsNone(index.nearest(30, 5, 370))

    def test_the_nearer_of_two_units_wins(self):
        index = places.UnitIndex([_FRANCE, _GERMANY])
        # North of Germany's square, far from France's.
        self.assertEqual(index.nearest(55.5, 12, 370)[0]["ADMIN"], "Germany")

    def test_a_hole_is_not_inside(self):
        ring = _square(0, 0, 10, 10, ADMIN="Ring")
        ring["geometry"]["coordinates"].append(
            [[4, 4], [6, 4], [6, 6], [4, 6], [4, 4]]
        )
        index = places.UnitIndex([ring])
        self.assertIsNotNone(index.containing(2, 2))
        self.assertIsNone(index.containing(5, 5))

    def test_a_multipolygon_is_searched_whole(self):
        feature = _square(0, 0, 1, 1, ADMIN="Islands")
        feature["geometry"] = {
            "type": "MultiPolygon",
            "coordinates": [
                feature["geometry"]["coordinates"],
                [[[5, 5], [6, 5], [6, 6], [5, 6], [5, 5]]],
            ],
        }
        index = places.UnitIndex([feature])
        self.assertIsNotNone(index.containing(5.5, 5.5))
        self.assertIsNotNone(index.containing(0.5, 0.5))

    def test_the_antimeridian_is_no_wall(self):
        index = places.UnitIndex([_FIJI_EAST])
        # Just west of the date line, a few kilometres from land east of it.
        properties, distance = index.nearest(-16.5, 179.95, 370)
        self.assertEqual(properties["ADMIN"], "Fiji")
        self.assertLess(distance, 20)

    def test_near_a_pole_the_search_still_ends(self):
        index = places.UnitIndex([_FRANCE])
        self.assertIsNone(index.nearest(89.5, 5, 370))


class PlaceTest(unittest.TestCase):
    def test_inside_a_unit(self):
        place = _places().place(45, 5)
        self.assertEqual(place.country_code, "FR")
        self.assertEqual(place.country, "France")
        self.assertFalse(place.at_sea)

    def test_at_sea_near_a_unit(self):
        place = _places().place(39.73, 5)
        self.assertEqual(place.country_code, "FR")
        self.assertTrue(place.at_sea)

    def test_beyond_370_km_there_is_no_country(self):
        place = _places().place(20, -40)
        self.assertIsNone(place.country_code)
        self.assertIsNone(place.country)
        self.assertTrue(place.at_sea)

    def test_a_territory_keeps_its_own_code(self):
        place = _places().place(-17.5, -149.5)
        self.assertEqual(place.country_code, "PF")
        self.assertEqual(place.country, "French Polynesia")

    def test_a_unit_with_no_code_takes_its_sovereign_s(self):
        place = _places().place(34.5, 32.5)
        self.assertEqual(place.country_code, "FR")
        self.assertEqual(place.country, "France")

    def test_a_name_already_in_the_catalogue_is_reused(self):
        # OpenStreetMap dive sites already say "United States"; a register
        # record of the same country must not say it another way.
        place = _places(preferred={"FR": "Frankreich"}).place(45, 5)
        self.assertEqual(place.country, "Frankreich")

    def test_a_lake_is_fresh_water(self):
        self.assertTrue(_places().place(46.2, 6.5).fresh)
        self.assertFalse(_places().place(45, 5).fresh)

    def test_the_region_is_the_unit_the_point_lies_in(self):
        self.assertEqual(_places().place(43, 3).region, "Occitanie")

    def test_the_nearest_region_of_the_same_country_within_50_km(self):
        # 30 km south of Occitanie's square, still in France.
        self.assertEqual(_places().place(41.73, 3).region, "Occitanie")
        self.assertIsNone(_places().place(41.28, 3).region)

    def test_a_region_of_another_country_is_never_borrowed(self):
        # In Germany's square, 22 km north of a Swiss region's edge: the
        # nearest region is Swiss, and Germany has none within reach.
        swiss_region = _square(47.5, 10, 48, 11, name_en="Graubunden",
                               name="Graubunden", iso_a2="CH",
                               iso_3166_2="CH-GR")
        index = places.Places(
            places.UnitIndex([_SWISS, _GERMANY]),
            places.UnitIndex([swiss_region]), places.UnitIndex([]),
            known_names=_KNOWN, preferred_names={},
        )
        place = index.place(48.2, 10.5)
        self.assertEqual(place.country_code, "DE")
        self.assertIsNone(place.region)
        # The same region is used for a Swiss point just outside it.
        self.assertEqual(index.place(47.4, 10.5).region, "Graubunden")

    def test_a_region_written_in_another_script_falls_back_or_is_dropped(self):
        index = places.UnitIndex(_REGIONS)
        self.assertEqual(
            places.region_name(index.containing(30.5, 30.5)), "Janub Sina"
        )
        self.assertIsNone(
            places.region_name({"name_en": "沖縄県", "name": "沖縄県"})
        )

    def test_an_island_comes_from_the_subdivision_code(self):
        units = [_unit(12, -69, 13, -68, "BQ", "Netherlands",
                       subunit="Caribbean Netherlands")]
        index = places.Places(
            places.UnitIndex(units), places.UnitIndex(_REGIONS),
            places.UnitIndex([]),
            known_names={"caribbean netherlands": "BQ"}, preferred_names={},
        )
        place = index.place(12.1, -68.3)
        self.assertEqual(place.country_code, "BQ")
        self.assertEqual(place.island, "Bonaire")
        # The region would only repeat the island.
        self.assertIsNone(place.region)

    def test_natural_earth_s_own_codes_for_bonaire_name_the_island(self):
        units = [_unit(12, -69, 13, -68, "BQ", "Netherlands",
                       subunit="Caribbean Netherlands")]
        regions = [_square(12, -69, 13, -68, name_en="Bonaire",
                           name="Bonaire", iso_a2="NL", iso_3166_2="NL-BQ1")]
        index = places.Places(
            places.UnitIndex(units), places.UnitIndex(regions),
            places.UnitIndex([]),
            known_names={"caribbean netherlands": "BQ"}, preferred_names={},
        )
        self.assertEqual(index.place(12.1, -68.3).island, "Bonaire")

    def test_a_code_the_app_does_not_know_falls_to_the_sovereign(self):
        # Natural Earth gives a UN zone a private code of its own.
        zone = _unit(34, 32, 35, 33, "XD", "Akrotiri", sovereign="France")
        place = _places(units=[_FRANCE, zone]).place(34.5, 32.5)
        self.assertEqual(place.country_code, "FR")

    def test_a_part_of_a_state_is_named_by_any_unit_of_that_state(self):
        # The first unit met is a province whose own names the app cannot
        # read; the state's core unit can still name the code.
        province = _unit(40, 20, 41, 21, "FR", "Republic of France",
                         subunit="Provence", sovereign="Republic of France")
        place = _places(units=[province, _FRANCE]).place(40.5, 20.5)
        self.assertEqual(place.country, "France")

    def test_the_same_position_is_answered_from_memory(self):
        index = _places()
        first = index.place(45, 5)
        self.assertIs(index.place(45, 5), first)


class SettleTest(unittest.TestCase):
    def test_a_territory_wins_over_its_parent_state(self):
        place = _places().settle(("FR", "France", None), -17.5, -149.5)
        self.assertEqual(place.country_code, "PF")
        self.assertEqual(place.country, "French Polynesia")

    def test_a_territory_wins_for_a_site_just_off_its_shore(self):
        # 5 km north of Tahiti's square: most dive sites are in the water.
        place = _places().settle(("FR", "France", None), -16.955, -149.5)
        self.assertEqual(place.country_code, "PF")
        # 60 km out it is the geocoder's call.
        place = _places().settle(("FR", "France", None), -16.46, -149.5)
        self.assertEqual(place.country_code, "FR")

    def test_settling_never_renames_a_country_for_later_records(self):
        index = _places()
        index.settle(("FR", "Frankreich", None), 45, 5)
        self.assertEqual(index.place(44, 5).country, "France")

    def test_the_geocoder_stands_at_a_border_the_boundaries_blur(self):
        # The offline squares put this point in Germany; the geocoder,
        # which knows the real border, said Switzerland.
        place = _places().settle(("CH", "Switzerland", None), 48.2, 10.5)
        self.assertEqual(place.country_code, "CH")
        self.assertEqual(place.country, "Switzerland")

    def test_no_geocoder_answer_uses_the_offline_one(self):
        place = _places().settle((None, None, None), 39.73, 5)
        self.assertEqual(place.country_code, "FR")
        self.assertEqual(place.country, "France")

    def test_the_geocoder_s_island_is_kept(self):
        place = _places().settle(("FR", "France", "Corsica"), 45, 5)
        self.assertEqual(place.island, "Corsica")

    def test_the_region_and_the_lake_still_come_from_the_boundaries(self):
        place = _places().settle(("FR", "France", None), 43, 3)
        self.assertEqual(place.region, "Occitanie")
        self.assertTrue(
            _places().settle(("CH", "Switzerland", None), 46.2, 6.5).fresh
        )


class EnglishNameTest(unittest.TestCase):
    def test_the_first_candidate_the_app_reads_back_wins(self):
        self.assertEqual(
            places.english_name("GB", ["Great Britain", "United Kingdom"],
                                _KNOWN),
            "United Kingdom",
        )

    def test_an_override_names_what_the_app_would_not_read(self):
        self.assertEqual(
            places.english_name(
                "FM", ["Federated States of Micronesia"], _KNOWN
            ),
            "Micronesia",
        )

    def test_a_name_the_app_cannot_read_stops_the_merge(self):
        with self.assertRaises(ValueError) as raised:
            places.english_name("XX", ["Atlantis"], _KNOWN)
        self.assertIn("XX", str(raised.exception))
        self.assertIn("Atlantis", str(raised.exception))

    def test_every_override_reads_back_as_its_code(self):
        known = places.known_country_names()
        for code, name in places.NAME_OVERRIDES.items():
            self.assertEqual(
                known.get(places.fold_country(name)), code, f"{code}: {name}"
            )
        for code in ("VI", "PM", "SJ"):
            self.assertIn(code, places.NAME_OVERRIDES)

    def test_preferred_names_are_the_commonest_one_the_app_reads(self):
        answers = [
            ("FR", "France", None), ("FR", "France", None),
            ("FR", "Frankreich", None), ("CH", "Atlantis", None),
            (None, None, None), ("DE", "Germany", "Rugen"),
        ]
        self.assertEqual(
            places.preferred_country_names(answers, _KNOWN),
            {"FR": "France", "DE": "Germany"},
        )

    def test_the_app_s_table_is_read_from_its_dart_source(self):
        known = places.known_country_names()
        self.assertEqual(known["united states"], "US")
        self.assertEqual(known["french polynesia"], "PF")
        # An alias from country_code.dart, not from the generated table.
        self.assertEqual(known["united states of america"], "US")
        self.assertGreater(len(known), 2000)


if __name__ == "__main__":
    unittest.main()
