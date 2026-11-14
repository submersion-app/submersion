#!/usr/bin/env python3
"""Unit tests for src_reefs.py, against real rows of each reef source.

Run: python3 scripts/site_catalogue/src_reefs_test.py

Five sources list artificial reefs and moorings: Florida's deployments, a
federal compilation of the other states, New Jersey's and North
Carolina's own layers, and the Florida Keys buoys. These tests pin which
rows ship, under which source, and that the states whose terms forbid it
never do.
"""

import json
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import src_reefs  # noqa: E402


def _sample(name):
    with open(os.path.join(_HERE, "samples", name), encoding="utf-8") as file:
        return json.load(file)


def _by_id(records):
    return {record["id"]: record for record in records}


class FwcTest(unittest.TestCase):
    def setUp(self):
        rows = src_reefs.geojson_rows(_sample("fwc.geojson"))
        self.records, self.dropped = src_reefs.fwc_records(rows)
        self.by_id = _by_id(self.records)

    def test_deployments_of_one_reef_become_one_site(self):
        reef = self.by_id["fwc_PI0223"]
        self.assertEqual(reef["name"], "Rube Allyn Reef")
        self.assertEqual(reef["source"], "fwc")
        self.assertEqual(reef["kind"], "register")
        self.assertEqual(reef["types"], ["artificial_reef"])
        # The mean of three deployments a few metres apart.
        self.assertAlmostEqual(reef["lat"], 27.93203, places=4)
        self.assertAlmostEqual(reef["lon"], -83.023733, places=4)
        # The deepest water of the three, 45 ft; the shallowest top,
        # 45 - 17 ft.
        self.assertEqual(reef["max_depth"], 13.7)
        self.assertEqual(reef["min_depth"], 8.5)
        self.assertEqual(reef["description"], "Concrete, placed 2002")

    def test_the_same_name_far_away_is_its_own_site(self):
        other = self.by_id["fwc_PI0014"]
        self.assertEqual(other["name"], "Rube Allyn Reef")
        self.assertEqual(other["max_depth"], 13.4)
        # No relief stated.
        self.assertIsNone(other["min_depth"])

    def test_a_vessel_is_also_a_wreck(self):
        vandenberg = self.by_id["fwc_MO0062"]
        self.assertEqual(vandenberg["types"], ["artificial_reef", "wreck"])
        self.assertEqual(vandenberg["max_depth"], 44.2)
        self.assertEqual(vandenberg["min_depth"], 13.7)
        self.assertEqual(vandenberg["description"], "Vessel, placed 2009")

    def test_a_reef_module(self):
        self.assertEqual(
            self.by_id["fwc_BA0323"]["description"],
            "Reef modules, placed 2014",
        )

    def test_what_is_dropped(self):
        self.assertEqual(
            dict(self.dropped), {"too_deep": 1, "no_name": 1}
        )
        self.assertNotIn("fwc_BO0104", self.by_id)
        # A site with no stated depth still ships.
        self.assertIsNone(self.by_id["fwc_BA0188"]["max_depth"])
        self.assertEqual(len(self.records), 5)


class FederalTest(unittest.TestCase):
    def setUp(self):
        self.records, self.dropped = src_reefs.federal_records(
            _sample("federal_reefs.json")
        )
        self.by_name = {record["name"]: record for record in self.records}

    def test_the_states_whose_rows_come_from_elsewhere_or_not_at_all(self):
        # New York (terms forbid distribution), and New Jersey, North
        # Carolina and Florida (their own files are read instead).
        self.assertEqual(self.dropped["excluded_state"], 4)
        for record in self.records:
            for state in ("ny", "nj", "nc", "fl"):
                self.assertFalse(
                    record["id"].startswith(f"usreef_{state}_"), record["id"]
                )

    def test_a_state_with_no_stated_terms_ships_under_the_federal_source(self):
        tank = self.by_name["Tank 47"]
        self.assertEqual(tank["source"], "noaa_reefs")
        self.assertEqual(tank["id"], "usreef_al_tank_47_n2988_w8774")
        self.assertEqual(tank["kind"], "register")
        self.assertEqual(tank["types"], ["artificial_reef"])
        # 29 52 36.4 N, 87 44 6.6 W
        self.assertAlmostEqual(tank["lat"], 29.876778, places=5)
        self.assertAlmostEqual(tank["lon"], -87.735167, places=5)
        self.assertEqual(tank["max_depth"], 34.1)
        self.assertEqual(tank["description"], "Tank, placed 1994")
        self.assertEqual(
            tank["source_ref"],
            "https://www.outdooralabama.com/saltwater-fishing/artificial-reefs",
        )

    def test_a_vessel_is_also_a_wreck(self):
        self.assertEqual(
            self.by_name["70' OSV"]["types"], ["artificial_reef", "wreck"]
        )

    def test_rows_of_one_reef_are_grouped(self):
        reef = self.by_name["Betsy Ross Reef"]
        self.assertEqual(reef["types"], ["artificial_reef", "wreck"])
        self.assertEqual(reef["max_depth"], 25.9)
        self.assertEqual(
            sum(1 for r in self.records if r["name"] == "Betsy Ross Reef"), 1
        )

    def test_texas_is_its_own_source(self):
        port = self.by_name["Port Mansfield"]
        self.assertEqual(port["source"], "tpwd")
        self.assertTrue(port["id"].startswith("usreef_tx_port_mansfield_"))

    def test_hawaii_is_its_own_source_and_keeps_the_depth_limit(self):
        # The sample's Hawaii row is a corner marker; Louisiana's is deep.
        self.assertEqual(self.dropped["area_corner"], 1)
        self.assertEqual(self.dropped["too_deep"], 1)
        base = dict(
            _sample("federal_reefs.json")[5],
            reefName="Kualoa Artificial Reef - Small Barge",
        )
        records, _ = src_reefs.federal_records([dict(base, waterDepthFeet=60)])
        self.assertEqual(records[0]["source"], "hi_dar")
        _, dropped = src_reefs.federal_records([dict(base, waterDepthFeet=330)])
        self.assertEqual(dict(dropped), {"too_deep": 1})

    def test_two_sites_of_one_name_in_one_state_keep_ids_of_their_own(self):
        base = _sample("federal_reefs.json")[0]
        # 1.6 km apart: two sites, and both in the same hundredth of a
        # degree only if the id were coarser.
        other = dict(base, latitudeDMS="29 53 28.0 N")
        records, _ = src_reefs.federal_records([base, other])
        self.assertEqual(len(records), 2)
        self.assertEqual(len({record["id"] for record in records}), 2)

    def test_an_upper_case_name_is_recased(self):
        row = dict(_sample("federal_reefs.json")[0], reefName="BLUE CROWN")
        self.assertEqual(
            src_reefs.federal_records([row])[0][0]["name"], "Blue Crown"
        )

    def test_a_corner_of_a_reef_area_is_not_a_site(self):
        # Hawaii lists the corner markers of each reef area beside the
        # structures in it.
        base = dict(_sample("federal_reefs.json")[5], waterDepthFeet=60)
        corner = dict(base, reefName="Kualoa Artificial Reef - Corner A")
        barge = dict(base, reefName="Kualoa Artificial Reef - Small Barge")
        records, dropped = src_reefs.federal_records([corner, barge])
        self.assertEqual(dict(dropped), {"area_corner": 1})
        self.assertEqual(
            [r["name"] for r in records], ["Kualoa Artificial Reef - Small Barge"]
        )

    def test_a_row_with_no_name_or_position_is_dropped_quietly(self):
        self.assertEqual(self.dropped["no_name"], 1)
        row = dict(_sample("federal_reefs.json")[0], latitudeDMS="")
        self.assertEqual(
            dict(src_reefs.federal_records([row])[1]), {"no_position": 1}
        )

    def test_the_counts_cover_every_row(self):
        self.assertEqual(
            len(_sample("federal_reefs.json")),
            # Three Betsy Ross rows are one record.
            len(self.records) + 2 + sum(self.dropped.values()),
        )


class NjdepTest(unittest.TestCase):
    def setUp(self):
        rows = src_reefs.arcgis_rows(_sample("njdep.json"))
        self.records, self.dropped = src_reefs.njdep_records(rows)
        self.by_id = _by_id(self.records)

    def test_a_vessel_is_named_by_the_vessel(self):
        laita = self.by_id["njreef_831"]
        self.assertEqual(laita["name"], "Laita")
        self.assertEqual(laita["locality"], "Cape May Reef")
        self.assertEqual(laita["source"], "njdep")
        self.assertEqual(laita["kind"], "register")
        self.assertEqual(laita["types"], ["artificial_reef", "wreck"])
        self.assertEqual(laita["description"], "Ship, placed 1986")
        self.assertIsNone(laita["max_depth"])

    def test_an_upper_case_vessel_name_is_recased(self):
        rows = src_reefs.arcgis_rows(_sample("njdep.json"))
        rows = [dict(row, NAME="BLUE CROWN") for row in rows if row["UNIQUE_ID"] == 831]
        self.assertEqual(
            src_reefs.njdep_records(rows)[0][0]["name"], "Blue Crown"
        )

    def test_material_carries_its_reef_site_in_the_name(self):
        cars = self.by_id["njreef_957"]
        self.assertEqual(cars["name"], "Cape May Reef, Subway Car")
        self.assertEqual(cars["types"], ["artificial_reef"])

    def test_deployments_of_one_name_within_a_kilometre_are_one_site(self):
        self.assertEqual(
            self.by_id["njreef_1038"]["name"],
            "Cape May Reef, Stainless Steel Subway Car",
        )
        self.assertNotIn("njreef_1039", self.by_id)
        # The same material 4 km away on the same reef is another site.
        self.assertEqual(
            self.by_id["njreef_972"]["name"], "Cape May Reef, Subway Car"
        )

    def test_a_vessel_with_no_name_of_its_own_is_named_for_the_reef(self):
        self.assertEqual(self.by_id["njreef_830"]["name"], "Cape May Reef, Barge")

    def test_nothing_is_dropped_for_depth(self):
        self.assertEqual(dict(self.dropped), {})
        self.assertEqual(len(self.records), 6)


class MalformedRowsTest(unittest.TestCase):
    def test_a_new_jersey_row_without_a_number_is_dropped_not_fatal(self):
        rows = src_reefs.arcgis_rows(_sample("njdep.json"))
        broken = [dict(rows[0], UNIQUE_ID=None), dict(rows[0], UNIQUE_ID="UNKNOWN")]
        records, dropped = src_reefs.njdep_records(rows + broken)
        expected, _ = src_reefs.njdep_records(rows)
        self.assertEqual(len(records), len(expected))
        self.assertEqual(dropped["no_id"], 2)

    def test_a_north_carolina_reef_number_may_arrive_as_a_number(self):
        rows = src_reefs.arcgis_rows(_sample("nc_dmf.json"))
        numbered = dict(rows[0], REEF__=160, REEF_NAME="")
        records, _ = src_reefs.nc_dmf_records([numbered])
        self.assertEqual(len(records), 1)

    def test_paging_stops_at_an_empty_page_not_a_short_one(self):
        # A server whose page limit is under the size asked for answers
        # with short pages: stopping at the first would cut the layer short.
        from unittest import mock

        def page(numbers):
            return json.dumps({"features": [
                {"attributes": {"N": n}, "geometry": {"x": 1.0, "y": 2.0}}
                for n in numbers
            ]}).encode()

        pages = [page([1, 2]), page([3, 4]), page([5]), page([])]
        with mock.patch.object(src_reefs, "http_get", side_effect=pages), \
                mock.patch.object(src_reefs.time, "sleep"):
            rows = src_reefs._arcgis_pages("https://example.invalid/0", "json", 2000)
        self.assertEqual([row["N"] for row in rows], [1, 2, 3, 4, 5])


class NjdepMetadataTest(unittest.TestCase):
    def test_the_fetch_saves_the_layer_s_metadata_beside_its_snapshot(self):
        import tempfile
        from pathlib import Path
        from unittest import mock

        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(
                src_reefs, "http_get", return_value=b"<metadata/>"
            ) as get:
                path = src_reefs.save_njdep_metadata(Path(tmp))
            self.assertEqual(path, Path(tmp) / "njdep_metadata.xml")
            self.assertEqual(path.read_bytes(), b"<metadata/>")
            self.assertEqual(get.call_args.args[0], src_reefs.NJDEP_METADATA_URL)

    def test_an_empty_answer_is_not_saved_as_the_metadata(self):
        import tempfile
        from pathlib import Path
        from unittest import mock

        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(src_reefs, "http_get", return_value=b" "):
                with self.assertRaises(ValueError):
                    src_reefs.save_njdep_metadata(Path(tmp))
            self.assertFalse((Path(tmp) / "njdep_metadata.xml").exists())


class NcDmfTest(unittest.TestCase):
    def setUp(self):
        self.rows = src_reefs.arcgis_rows(_sample("nc_dmf.json"))
        self.records, self.dropped = src_reefs.nc_dmf_records(self.rows)
        self.by_id = _by_id(self.records)

    def test_every_site_ships_as_published(self):
        self.assertEqual(len(self.records), 4)
        self.assertEqual(dict(self.dropped), {})
        named = self.by_id["ncreef_ar_160"]
        self.assertEqual(named["name"], "Oregon Inlet Reef")
        self.assertEqual(named["source"], "nc_dmf")
        self.assertEqual(named["kind"], "register")
        self.assertEqual(named["types"], ["artificial_reef"])
        self.assertEqual(named["lat"], 35.731474)
        self.assertEqual(named["lon"], -75.446185)
        self.assertIsNone(named["description"])
        self.assertIsNone(named["max_depth"])

    def test_a_site_with_no_name_keeps_its_reef_number(self):
        # The layer writes the word "None" where a reef has no name.
        self.assertEqual(self.by_id["ncreef_ar_130"]["name"], "AR-130")

    def test_two_sites_are_never_grouped(self):
        rows = [dict(row, REEF_NAME="Same Name") for row in self.rows[:2]]
        rows[1]["_lat"], rows[1]["_lon"] = rows[0]["_lat"], rows[0]["_lon"]
        self.assertEqual(len(src_reefs.nc_dmf_records(rows)[0]), 2)


class FknmsTest(unittest.TestCase):
    def setUp(self):
        rows = src_reefs.geojson_rows(_sample("fknms.geojson"))
        self.records, self.dropped = src_reefs.fknms_records(rows)
        self.by_id = _by_id(self.records)

    def test_the_moorings_of_one_reef_are_one_dive_site(self):
        reef = self.by_id["fknms_molasses_reef"]
        self.assertEqual(reef["name"], "Molasses Reef")
        self.assertEqual(reef["source"], "fknms")
        self.assertEqual(reef["kind"], "site")
        self.assertEqual(reef["types"], ["reef"])
        self.assertAlmostEqual(reef["lat"], 25.008257, places=4)
        # 24, 21 and 22 ft.
        self.assertEqual(reef["max_depth"], 7.3)
        self.assertEqual(reef["min_depth"], 6.4)

    def test_a_wreck_mooring_is_a_wreck_without_its_article(self):
        wreck = self.by_id["fknms_spiegel_grove"]
        self.assertEqual(wreck["name"], "Spiegel Grove")
        self.assertEqual(wreck["types"], ["wreck"])
        self.assertEqual(wreck["max_depth"], 39.3)

    def test_boundary_and_spar_buoys_are_not_moorings(self):
        self.assertEqual(dict(self.dropped), {"not_mooring": 3})
        self.assertEqual(len(self.records), 2)


if __name__ == "__main__":
    unittest.main()
