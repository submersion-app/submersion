#!/usr/bin/env python3
"""Unit tests for src_osm.py, against real OpenStreetMap elements.

Run: python3 scripts/site_catalogue/src_osm_test.py

OpenStreetMap's scuba tag marks dive sites and also the shops, clubs and
hotels that serve divers, and its wreck tags mark hulks on beaches as well
as wrecks under water. These tests pin which become catalogue sites, on
elements copied from OpenStreetMap (samples/osm_scuba.json,
samples/osm_wrecks.json).
"""

import json
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_osm  # noqa: E402


def _elements(name):
    with open(os.path.join(_HERE, "samples", name), encoding="utf-8") as file:
        return {e["id"]: e for e in json.load(file)["elements"]}


def _site(element):
    records, dropped = src_osm.site_records([element])
    return (records[0] if records else None), next(iter(dropped), None)


def _wreck(element):
    records, dropped = src_osm.wreck_records([element])
    return (records[0] if records else None), next(iter(dropped), None)


class BusinessTest(unittest.TestCase):
    def test_what_serves_divers_is_not_a_dive_site(self):
        for tags in (
            {"amenity": "dive_centre"},
            {"shop": "scuba_diving"},
            {"shop": "sports"},
            {"club": "scuba_diving"},
            {"office": "company"},
            {"scuba_diving:rental": "yes"},
            {"scuba_diving:courses": "yes"},
            {"scuba_diving:filling": "yes"},
            {"scuba_diving:repair": "yes"},
            {"tourism": "hotel"},
            {"tourism": "resort"},
            {"leisure": "sports_centre"},
            {"leisure": "fitness_centre"},
        ):
            self.assertTrue(src_osm.is_business(tags, "Somewhere"), tags)

    def test_a_name_that_reads_as_a_business_is_one(self):
        for name in ("Blue Water Dive Center", "Tauchclub Octopus",
                     "Arborek Dive Shop", "Club de plongée de Brest",
                     "Scuba Centre Malta", "PADI Diving School"):
            self.assertTrue(src_osm.is_business({}, name), name)

    def test_a_marked_dive_spot_is_a_site_whatever_else_it_carries(self):
        self.assertFalse(
            src_osm.is_business(
                {"club": "scuba_diving", "scuba_diving:divespot": "yes"},
                "Banter See Dive Center",
            )
        )

    def test_an_entry_point_named_for_its_dive_centre_is_a_site(self):
        # German lakes name the way in after the centre beside it.
        for name in (
            "Taucheinstieg Ost Tauchzentrum Geiseltal",
            "Ehemaliger Einstieg der Tauchbasis Oasis in den Sundhäuser See",
        ):
            self.assertFalse(
                src_osm.is_business({"sport": "scuba_diving"}, name), name
            )
        self.assertTrue(
            src_osm.is_business({"sport": "scuba_diving"}, "Tauchzentrum Geiseltal")
        )

    def test_a_place_the_sport_is_practised_is_not_a_business(self):
        # OpenStreetMap tags the place a sport happens leisure=pitch, and
        # Dutch dive spots are mapped that way; a pool tagged for scuba is
        # a training site.
        self.assertFalse(src_osm.is_business({"leisure": "pitch"}, "Goese Sas"))
        self.assertFalse(
            src_osm.is_business({"leisure": "swimming_pool"}, "Fosse de Plongée")
        )

    def test_an_ordinary_site_is_not_a_business(self):
        self.assertFalse(src_osm.is_business({"sport": "scuba_diving"}, "Salt Pier"))
        self.assertFalse(
            src_osm.is_business({"tourism": "attraction"}, "Anemone Reef")
        )
        self.assertFalse(src_osm.is_business({}, "Divers Rock"))


class SiteRecordsTest(unittest.TestCase):
    def setUp(self):
        self.elements = _elements("osm_scuba.json")

    def test_each_reason_an_element_is_dropped_for(self):
        for element_id, reason in [
            (68531521, "business"),   # amenity=dive_centre
            (33756441, "business"),   # shop
            (153071972, "business"),  # a club, by tag and by name
            (2130801890, "business"),  # tourism=hotel
            (4432316400, "business"),  # equipment rental
            (31567779, "no_name"),
        ]:
            self.assertEqual(
                _site(self.elements[element_id])[1], reason, element_id
            )

    def test_a_plain_site_keeps_its_id_and_details(self):
        record, _ = _site(self.elements[663869401])
        self.assertEqual(record["id"], "osm_node_663869401")
        self.assertEqual(record["name"], "Salt Pier")
        self.assertEqual(record["source"], "osm")
        self.assertEqual(record["kind"], "site")
        self.assertEqual(record["lat"], 12.083594)
        self.assertEqual(record["lon"], -68.281952)
        self.assertEqual(
            record["description"],
            "Not allowed to access when there's a ship at the pier",
        )
        self.assertEqual(
            record["website"],
            "https://www.shorediving.com/Earth/ABC/BonaireS/Salt_Pier/index.htm",
        )
        self.assertEqual(
            record["source_ref"],
            "https://www.openstreetmap.org/node/663869401",
        )

    def test_depths_and_features_read_as_before(self):
        record, _ = _site(self.elements[5710652974])
        self.assertEqual(record["min_depth"], 7.0)
        self.assertEqual(record["max_depth"], 13.0)
        self.assertEqual(record["features"], ["sea"])

    def test_a_lone_depth_is_the_maximum(self):
        record, _ = _site(self.elements[4323234])
        self.assertEqual(record["max_depth"], 21.0)
        self.assertIsNone(record["min_depth"])

    def test_a_way_or_relation_takes_the_position_of_its_centre(self):
        way, _ = _site(self.elements[4323234])
        self.assertEqual(way["id"], "osm_way_4323234")
        self.assertEqual(way["lat"], 51.283386)
        self.assertEqual(way["lon"], 4.396724)
        relation, _ = _site(self.elements[50701])
        self.assertEqual(relation["id"], "osm_relation_50701")
        self.assertIsNotNone(relation["lat"])

    def test_a_site_with_no_position_still_ships(self):
        element = dict(self.elements[663869401])
        del element["lat"], element["lon"]
        record, reason = _site(element)
        self.assertIsNone(reason)
        self.assertIsNone(record["lat"])

    def test_types_and_water_come_from_the_object_s_own_tags(self):
        for element_id, types, water in [
            (663869535, ["wreck"], None),        # historic=wreck
            (270985343, ["reef"], None),         # natural=reef
            (384934092, ["cave"], None),         # natural=cave_entrance
            (764536299, ["spring", "cave"], "fresh"),  # spring, speleology
            (4323234, ["lake"], "fresh"),        # water=lake
            (663869563, ["quarry"], "fresh"),    # landuse=quarry
        ]:
            record, _ = _site(self.elements[element_id])
            self.assertEqual(record["types"], types, element_id)
            self.assertEqual(record["water_type"], water, element_id)

    def test_a_pool_is_a_fresh_water_pool_site(self):
        element = dict(self.elements[663869401])
        element["tags"] = dict(element["tags"], leisure="swimming_pool")
        record, reason = _site(element)
        self.assertIsNone(reason)
        self.assertEqual(record["types"], ["pool"])
        self.assertEqual(record["water_type"], "fresh")

    def test_a_marked_dive_spot_with_a_club_tag_is_a_site(self):
        record, reason = _site(self.elements[663870622])
        self.assertIsNone(reason)
        self.assertEqual(record["name"], "Banter See - UWC Heim")

    def test_the_geocoder_s_answer_travels_with_the_record(self):
        element = dict(
            self.elements[663869401],
            geocoded=["BQ", "Caribbean Netherlands", "Bonaire"],
        )
        self.assertEqual(
            _site(element)[0]["geocoded"],
            ["BQ", "Caribbean Netherlands", "Bonaire"],
        )
        self.assertIsNone(_site(self.elements[663869401])[0]["geocoded"])

    def test_a_depth_in_feet_is_converted(self):
        element = dict(self.elements[663869401])
        element["tags"] = dict(
            element["tags"], **{"scuba_diving:maxdepth": "100 ft"}
        )
        self.assertEqual(_site(element)[0]["max_depth"], 30.5)

    def test_an_entry_and_a_hazard_are_carried(self):
        element = dict(self.elements[663869401])
        element["tags"] = dict(
            element["tags"],
            **{"scuba_diving:entry": "shore", "scuba_diving:hazard": "boats"},
        )
        record, _ = _site(element)
        self.assertEqual(record["entry_type"], "shore")
        self.assertEqual(record["hazards"], "boats")


class WreckRecordsTest(unittest.TestCase):
    def setUp(self):
        self.elements = _elements("osm_wrecks.json")

    def test_each_reason_a_wreck_is_dropped_for(self):
        for element_id, reason in [
            (105399696, "scuba_tagged"),  # already a dive site record
            (283360371, "visible"),       # shows at high tide
            (331325152, "visible"),       # hull showing
            (101368127, "visible"),       # shows at low tide
            # The SS Richard Montgomery: its masts show, and it is
            # closed too.
            (455926943, "visible"),
            (3701621597, "not_a_ship"),
            (295839258, "too_deep"),
        ]:
            self.assertEqual(
                _wreck(self.elements[element_id])[1], reason, element_id
            )

    def test_a_wreck_closed_to_visitors_is_dropped(self):
        for access in ("no", "private"):
            element = dict(self.elements[44933809])
            element["tags"] = dict(element["tags"], access=access)
            self.assertEqual(_wreck(element)[1], "no_access", access)
        element = dict(self.elements[44933809])
        element["tags"] = dict(element["tags"], access="permit")
        self.assertIsNone(_wreck(element)[1])

    def test_a_submerged_wreck_is_a_register_record(self):
        record, reason = _wreck(self.elements[270525194])
        self.assertIsNone(reason)
        self.assertEqual(record["id"], "osm_node_270525194")
        self.assertEqual(record["name"], "Shirala")
        self.assertEqual(record["source"], "osm")
        self.assertEqual(record["kind"], "register")
        self.assertEqual(record["types"], ["wreck"])
        self.assertEqual(record["max_depth"], 22.0)
        self.assertEqual(
            record["source_ref"],
            "https://www.openstreetmap.org/node/270525194",
        )

    def test_any_of_the_depth_keys_is_read(self):
        self.assertEqual(_wreck(self.elements[330610844])[0]["max_depth"], 12.2)
        self.assertIsNone(_wreck(self.elements[44933809])[0]["max_depth"])

    def test_a_wreck_with_no_name_or_position_is_dropped_quietly(self):
        element = dict(self.elements[44933809])
        element["tags"] = {
            k: v for k, v in element["tags"].items() if k != "name"
        }
        self.assertEqual(_wreck(element)[1], "no_name")
        element = dict(self.elements[44933809])
        del element["lat"]
        self.assertEqual(_wreck(element)[1], "no_position")


if __name__ == "__main__":
    unittest.main()
