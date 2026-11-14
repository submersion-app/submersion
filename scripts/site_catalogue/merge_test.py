#!/usr/bin/env python3
"""Unit tests for merge.py.

Run: python3 scripts/site_catalogue/merge_test.py

The merge reads every source's snapshot and writes the catalogue the app
ships, with no network. These tests run it on the committed sample rows
of each source and pin: nothing excluded gets through, every record is
placed and valid, the report adds up, and the output is the same whatever
order the snapshots arrive in.
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
import site_catalogue_format as fmt  # noqa: E402
import snapshots  # noqa: E402
import src_awois  # noqa: E402
import src_ireland  # noqa: E402
import src_reefs  # noqa: E402
import src_ukho  # noqa: E402
import src_wikidata  # noqa: E402
from places import Place  # noqa: E402

_SAMPLES = os.path.join(_HERE, "samples")


def _bytes(name):
    with open(os.path.join(_SAMPLES, name), "rb") as file:
        return file.read()


def _json(name):
    return json.loads(_bytes(name).decode("utf-8"))


def _geocoded(elements, answer):
    return [dict(element, geocoded=answer) for element in elements]


def _snapshots():
    """Every source's rows, from the committed samples."""
    scuba = _json("osm_scuba.json")["elements"]
    return {
        "osm_sites": _geocoded(scuba, ["BQ", "Caribbean Netherlands", "Bonaire"]),
        "osm_wrecks": _json("osm_wrecks.json")["elements"],
        "ukho": src_ukho.parse(_bytes("ukho.tsv")),
        "awois": src_awois.parse(_bytes("awois.kml")),
        "nms_ie": src_ireland.parse(_bytes("ireland.csv")),
        "fwc": src_reefs.geojson_rows(_json("fwc.geojson")),
        "noaa_reefs": _json("federal_reefs.json"),
        "njdep": src_reefs.arcgis_rows(_json("njdep.json")),
        "nc_dmf": src_reefs.arcgis_rows(_json("nc_dmf.json")),
        "fknms": src_reefs.geojson_rows(_json("fknms.geojson")),
        "wikidata_sites": [
            dict(item="Q14213870", label="SAS Good Hope", lat=-34.267567,
                 lon=18.480833, precision=2.77778e-5,
                 globe="http://www.wikidata.org/entity/Q2"),
        ],
        "wikidata_wrecks": [
            dict(item="Q1", label="HMS Erne", lat=57.607447, lon=-1.807537,
                 precision=1e-6, globe="http://www.wikidata.org/entity/Q2"),
            dict(item="Q2", label="U-341", lat=58.566667, lon=-25.5,
                 precision=2.77778e-4,
                 globe="http://www.wikidata.org/entity/Q2"),
        ],
    }


_CURATED = [
    {
        "id": "curated_nj_pocopson", "name": "Pocopson",
        "description": "Schooner barge.", "latitude": 40.2034,
        "longitude": -73.9876, "country": "United States",
        "region": "New Jersey", "source": "https://example.org/pocopson",
        "depthM": 15, "kind": "wreck",
    },
    {
        "id": "curated_shore", "name": "Somewhere Beach",
        "description": "A beach.", "latitude": 10.0, "longitude": 20.0,
        "country": "Belize", "source": "https://example.org/beach",
        "kind": "shore",
    },
]


class _Places:
    """Stands in for the offline lookup: one answer everywhere, except the
    positions a test names."""

    def __init__(self, default=None, special=None, dry=()):
        self.default = default or Place(
            "GB", "United Kingdom", "Kent", None, False, True
        )
        self.special = special or {}
        self.dry = set(dry)

    def on_dry_land(self, lat, lon):
        return (round(lat, 1), round(lon, 1)) in self.dry

    def place(self, lat, lon):
        return self.special.get((round(lat, 1), round(lon, 1)), self.default)

    def settle(self, geocoded, lat, lon):
        offline = self.place(lat, lon)
        if not geocoded or not geocoded[0]:
            return offline
        return offline._replace(
            country_code=geocoded[0], country=geocoded[1],
            island=geocoded[2], region="Settled Region",
        )


def _build(snapshots_=None, curated=_CURATED, places=None):
    return merge.build(
        snapshots_ if snapshots_ is not None else _snapshots(),
        curated,
        places or _Places(),
    )


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records, cls.report = _build()
        cls.by_id = {record["id"]: record for record in cls.records}

    def test_every_record_is_valid_and_every_source_is_there(self):
        doc = {
            "metadata": {"format": fmt.FORMAT, "sources": fmt.SOURCES},
            "sites": self.records,
        }
        self.assertEqual(fmt.validate_catalogue(doc), [])
        self.assertEqual(
            {record["source"] for record in self.records},
            {"osm", "curated", "ukho", "awois", "nms_ie", "fwc", "noaa_reefs",
             "njdep", "nc_dmf", "fknms", "wikidata", "tpwd"},
        )

    def test_nothing_excluded_gets_through(self):
        for record in self.records:
            for state in ("ny", "nj", "nc", "fl"):
                self.assertFalse(
                    record["id"].startswith(f"usreef_{state}_"), record["id"]
                )
        # The Irish rows with a wrecksite.eu, uboat.net or Lloyd's List
        # position.
        for wreck_no in ("W06261", "W04795", "W02911"):
            self.assertNotIn(f"ie_{wreck_no}", self.by_id)
        # A dive centre, and a wreck where diving is prohibited.
        self.assertNotIn("osm_node_68531521", self.by_id)
        self.assertNotIn("ukho_47702", self.by_id)

    def test_a_register_record_says_so_and_a_dive_site_does_not(self):
        self.assertEqual(self.by_id["ukho_9438"]["kind"], "register")
        self.assertEqual(self.by_id["njreef_831"]["kind"], "register")
        self.assertEqual(self.by_id["osm_node_270525194"]["kind"], "register")
        self.assertEqual(self.by_id["wikidata_Q1"]["kind"], "register")
        for site_id in ("osm_node_663869401", "curated_nj_pocopson",
                        "fknms_molasses_reef", "wikidata_Q14213870"):
            self.assertNotIn("kind", self.by_id[site_id], site_id)

    def test_a_register_record_is_placed_by_the_offline_lookup(self):
        wreck = self.by_id["ukho_9438"]
        self.assertEqual(wreck["country_code"], "GB")
        self.assertEqual(wreck["country"], "United Kingdom")
        self.assertEqual(wreck["region"], "Kent")
        self.assertEqual(wreck["types"], ["wreck"])
        self.assertEqual(wreck["max_depth_m"], 22.0)
        self.assertEqual(wreck["min_depth_m"], 17.3)
        self.assertEqual(wreck["description"], "Steam ship, lost 1915")
        self.assertEqual(wreck["trust"], "verified")

    def test_an_openstreetmap_dive_site_keeps_the_geocoder_s_answer(self):
        site = self.by_id["osm_node_663869401"]
        self.assertEqual(site["country_code"], "BQ")
        self.assertEqual(site["country"], "Caribbean Netherlands")
        self.assertEqual(site["island"], "Bonaire")
        self.assertEqual(site["region"], "Settled Region")
        self.assertEqual(
            site["source_ref"], "https://www.openstreetmap.org/node/663869401"
        )

    def test_a_curated_site_keeps_its_own_region_and_details(self):
        wreck = self.by_id["curated_nj_pocopson"]
        self.assertEqual(wreck["region"], "New Jersey")
        self.assertEqual(wreck["country_code"], "GB")  # from the lookup
        self.assertEqual(wreck["types"], ["wreck"])
        self.assertEqual(wreck["max_depth_m"], 15)
        self.assertEqual(wreck["source_ref"], "https://example.org/pocopson")
        self.assertEqual(self.by_id["curated_shore"]["entry"], ["shore"])

    def test_a_curated_kind_that_is_not_a_site_type_stays_a_feature(self):
        records, _ = _build(curated=[dict(_CURATED[0], kind="drift")])
        wreck = {r["id"]: r for r in records}["curated_nj_pocopson"]
        self.assertNotIn("types", wreck)
        self.assertEqual(wreck["features"], ["drift"])

    def test_a_curated_site_the_lookup_cannot_place_keeps_its_own_country(self):
        records, _ = _build(
            places=_Places(default=Place(None, None, None, None, False, True))
        )
        by_id = {record["id"]: record for record in records}
        self.assertEqual(by_id["curated_nj_pocopson"]["country_code"], "US")
        self.assertEqual(by_id["curated_nj_pocopson"]["country"], "United States")
        self.assertNotIn("country_code", by_id["ukho_9438"])

    def test_a_position_in_a_lake_is_fresh_water(self):
        # George Royle's position, as if it lay in a lake.
        lake = Place("GB", "United Kingdom", None, None, True, False)
        records, _ = _build(places=_Places(special={(53.0, 1.2): lake}))
        by_id = {record["id"]: record for record in records}
        self.assertEqual(by_id["ukho_9438"]["water_type"], "fresh")
        self.assertNotIn("water_type", by_id["ukho_27570"])

    def test_own_terms_records_carry_their_source(self):
        self.assertEqual(self.by_id["ncreef_ar_130"]["source"], "nc_dmf")
        self.assertEqual(self.by_id["ncreef_ar_130"]["name"], "AR-130")
        self.assertNotIn("description", self.by_id["ncreef_ar_130"])
        texas = [r for r in self.records if r["source"] == "tpwd"]
        self.assertEqual(len(texas), 1)

    def test_the_report_adds_up(self):
        for origin, line in self.report.items():
            self.assertEqual(
                line["formed"], line["overlap"] + line["written"], origin
            )
            self.assertGreaterEqual(line["read"], line["formed"], origin)
        for origin in ("ukho", "awois", "nms_ie", "osm_sites", "osm_wrecks"):
            line = self.report[origin]
            self.assertEqual(
                line["read"], sum(line["dropped"].values()) + line["formed"],
                origin,
            )
        self.assertEqual(
            sum(line["written"] for line in self.report.values()),
            len(self.records),
        )
        self.assertEqual(self.report["ukho"]["dropped"]["coarse_position"], 1)
        self.assertEqual(self.report["curated"]["read"], 2)

    def test_the_output_does_not_depend_on_the_order_of_the_snapshots(self):
        snapshots_ = _snapshots()
        backwards = dict(reversed(list(snapshots_.items())))
        for key in backwards:
            backwards[key] = list(reversed(backwards[key]))
        self.assertEqual(_build(backwards)[0], self.records)

    def test_a_row_a_register_lists_twice_ships_once(self):
        # The UKHO file has carried the same wreck id on two rows.
        snapshots_ = _snapshots()
        twin = dict(
            next(r for r in snapshots_["ukho"] if r["wreck_id"] == "9438"),
            latitude="53 30.000 N",
        )
        snapshots_["ukho"].append(twin)
        records, report = _build(snapshots_)
        self.assertEqual(
            sum(1 for record in records if record["id"] == "ukho_9438"), 1
        )
        self.assertEqual(report["ukho"]["dropped"]["duplicate_id"], 1)
        line = report["ukho"]
        self.assertEqual(
            line["read"], sum(line["dropped"].values()) + line["formed"]
        )
        # The first row stands: the position is its own.
        wreck = {r["id"]: r for r in records}["ukho_9438"]
        self.assertAlmostEqual(wreck["lat"], 53.033133, places=5)

    def test_a_source_can_be_left_out(self):
        snapshots_ = _snapshots()
        del snapshots_["ukho"]
        records, report = _build(snapshots_)
        self.assertNotIn("ukho", report)
        self.assertFalse(any(r["source"] == "ukho" for r in records))


def _osm_wreck(number, name, lat, lon):
    return dict(type="node", id=number, lat=lat, lon=lon,
                tags={"name": name, "historic": "wreck"})


class PositionGateTest(unittest.TestCase):
    def test_a_wreck_on_dry_land_is_not_a_dive(self):
        # OpenStreetMap's historic=wreck and Wikidata's shipwrecks include
        # crashed aircraft on mountains and hulls in museums.
        snapshots_ = _snapshots()
        snapshots_["osm_wrecks"].append(
            _osm_wreck(901, "Flight 901 wreckage", -77.42, 167.46)
        )
        records, report = _build(
            snapshots_, places=_Places(dry={(-77.4, 167.5), (57.6, -1.8)})
        )
        ids = {r["id"] for r in records}
        self.assertNotIn("osm_node_901", ids)
        self.assertEqual(report["osm_wrecks"]["dropped"]["on_land"], 1)
        # Wikidata's HMS Erne, at a position the lookup calls dry.
        self.assertNotIn("wikidata_Q1", ids)
        self.assertEqual(report["wikidata_wrecks"]["dropped"]["on_land"], 1)

    def test_a_hydrographic_register_is_not_asked(self):
        # A surveyed wreck is in water whatever the coarse boundaries say:
        # the registers chart rivers and harbours.
        records, report = _build(places=_Places(dry={(53.0, 1.2)}))
        self.assertIn("ukho_9438", {r["id"] for r in records})
        self.assertNotIn("on_land", report["ukho"]["dropped"])

    def test_a_position_of_zero_zero_or_off_the_globe_never_ships(self):
        snapshots_ = _snapshots()
        snapshots_["osm_wrecks"] += [
            _osm_wreck(902, "Null Island Trawler", 0.0, 0.0),
            _osm_wreck(903, "Too Far North", 95.0, 10.0),
            _osm_wreck(904, "Too Far West", 10.0, -200.0),
        ]
        records, report = _build(snapshots_)
        ids = {r["id"] for r in records}
        self.assertFalse(ids & {"osm_node_902", "osm_node_903", "osm_node_904"})
        self.assertEqual(report["osm_wrecks"]["dropped"]["bad_position"], 3)
        line = report["osm_wrecks"]
        self.assertEqual(
            line["read"], sum(line["dropped"].values()) + line["formed"]
        )

    def test_a_dive_site_with_a_bad_position_keeps_its_name(self):
        # A dive site a diver may hold stays findable by name.
        snapshots_ = _snapshots()
        element = dict(snapshots_["osm_sites"][0], lat=0.0, lon=0.0)
        element.pop("center", None)
        snapshots_["osm_sites"][0] = element
        records, _ = _build(snapshots_)
        site = {r["id"]: r for r in records}[
            f"osm_{element['type']}_{element['id']}"
        ]
        self.assertNotIn("lat", site)
        self.assertNotIn("lon", site)


class SharedPositionTest(unittest.TestCase):
    @staticmethod
    def _wreck(number, label, lat=55.1234, lon=-6.4321):
        return dict(item=f"Q9{number}", label=label, lat=lat, lon=lon,
                    precision=1e-6, globe="http://www.wikidata.org/entity/Q2")

    def test_three_wrecks_on_one_point_are_an_area_not_three_wrecks(self):
        # A scuttled flotilla filed on one position: no one of them is
        # where the register says.
        snapshots_ = _snapshots()
        snapshots_["wikidata_wrecks"] += [
            self._wreck(1, "SMS V43"), self._wreck(2, "SMS V46"),
            self._wreck(3, "SMS S132"),
        ]
        records, report = _build(snapshots_)
        ids = {r["id"] for r in records}
        self.assertFalse(ids & {"wikidata_Q91", "wikidata_Q92", "wikidata_Q93"})
        self.assertEqual(
            report["wikidata_wrecks"]["dropped"]["shared_position"], 3
        )

    def test_two_wrecks_on_one_point_stay(self):
        # A collision, or one wreck lying on another.
        snapshots_ = _snapshots()
        snapshots_["wikidata_wrecks"] += [
            self._wreck(1, "Andrea"), self._wreck(2, "Stockholm Bow"),
        ]
        records, report = _build(snapshots_)
        ids = {r["id"] for r in records}
        self.assertTrue({"wikidata_Q91", "wikidata_Q92"} <= ids)
        self.assertNotIn("shared_position", report["wikidata_wrecks"]["dropped"])

    def test_reef_structures_on_one_point_stay(self):
        # A reef program places several structures at one published point.
        snapshots_ = _snapshots()
        records, report = _build(snapshots_)
        for key in ("fwc", "njdep", "noaa_reefs", "nc_dmf", "fknms"):
            self.assertNotIn("shared_position", report[key]["dropped"], key)


class OverlapInTheMergeTest(unittest.TestCase):
    def test_a_wreck_two_sources_list_ships_once_with_the_gap_filled(self):
        snapshots_ = _snapshots()
        # Wikidata's HMS Erne, moved onto UKHO's George Royle under its
        # name: the UKHO record survives.
        snapshots_["wikidata_wrecks"][0].update(
            label="George Royle", lat=53.0335, lon=1.1752
        )
        records, report = _build(snapshots_)
        ids = [r["id"] for r in records]
        self.assertIn("ukho_9438", ids)
        self.assertNotIn("wikidata_Q1", ids)
        self.assertEqual(report["wikidata_wrecks"]["overlap"], 1)
        # The report says which source each record was lost to.
        self.assertEqual(report["wikidata_wrecks"]["lost_to"], {"ukho": 1})
        self.assertEqual(report["ukho"]["lost_to"], {})

    def test_an_own_terms_record_on_a_curated_wreck_is_left_out(self):
        curated = [dict(_CURATED[0], name="Laita", latitude=38.8447,
                        longitude=-74.7162)]
        records, _ = _build(curated=curated)
        by_id = {record["id"]: record for record in records}
        self.assertNotIn("njreef_831", by_id)
        self.assertEqual(by_id["curated_nj_pocopson"]["name"], "Laita")
        self.assertEqual(by_id["curated_nj_pocopson"]["types"], ["wreck"])
        self.assertNotIn("locality", by_id["curated_nj_pocopson"])


class IdChangesTest(unittest.TestCase):
    def test_ids_gone_and_new_are_listed_by_their_prefix(self):
        changes = merge.id_changes(
            {"osm_node_1", "ukho_5", "curated_a"},
            {"osm_node_1", "ukho_6", "usreef_al_tank_n1_w2"},
        )
        self.assertEqual(
            changes,
            {
                "gone": {"curated": ["curated_a"], "ukho": ["ukho_5"]},
                "new": {"ukho": ["ukho_6"], "usreef": ["usreef_al_tank_n1_w2"]},
            },
        )


class MainTest(unittest.TestCase):
    def _run(self, *arguments, leave_out=()):
        self.cache = Path(self._tmp.name) / "cache"
        self.out = Path(self._tmp.name) / "out"
        self.out.mkdir(exist_ok=True)
        # Written once per test: a second run reads the same snapshots, as
        # a rerun of the merge does, stamps and all.
        if not self.cache.exists():
            for key, rows in _snapshots().items():
                if key not in leave_out:
                    snapshots.write_snapshot(
                        key, "https://example.org", rows, self.cache
                    )
            if self.with_metadata:
                (self.cache / merge.NJDEP_METADATA_FILE).write_text(
                    "<metadata>NJDEP</metadata>", encoding="utf-8"
                )
        output = io.StringIO()
        with redirect_stdout(output):
            code = merge.main(
                ["--cache", str(self.cache), "--out", str(self.out), *arguments],
                places=_Places(),
                curated=_CURATED,
            )
        return code, output.getvalue()

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.with_metadata = True

    def _doc(self):
        return json.loads((self.out / "site_catalogue.json").read_text("utf-8"))

    def test_the_catalogue_and_its_sidecar_are_written(self):
        code, output = self._run()
        self.assertEqual(code, 0)
        doc = self._doc()
        self.assertEqual(doc["metadata"]["total_count"], len(doc["sites"]))
        self.assertGreater(len(doc["sites"]), 30)
        raw = (self.out / "site_catalogue.json").read_bytes()
        self.assertEqual(
            (self.out / "site_catalogue.version").read_text("utf-8"),
            fmt.catalogue_version(raw),
        )
        ids = [site["id"] for site in doc["sites"]]
        self.assertEqual(ids, sorted(ids))
        # The report names every source and what it lost.
        for word in ("ukho", "coarse_position", "nms_ie", "excluded_source",
                     "written"):
            self.assertIn(word, output)

    def test_a_missing_snapshot_stops_the_merge_and_writes_nothing(self):
        code, output = self._run(leave_out=("awois",))
        self.assertEqual(code, 2)
        self.assertIn("awois", output)
        self.assertFalse((self.out / "site_catalogue.json").exists())

    def test_a_source_named_as_left_out_may_be_missing(self):
        code, _ = self._run("--without", "awois", leave_out=("awois",))
        self.assertEqual(code, 0)
        self.assertFalse(
            any(site["source"] == "awois" for site in self._doc()["sites"])
        )

    def test_the_same_snapshots_write_the_same_bytes(self):
        self._run()
        first = (self.out / "site_catalogue.json").read_bytes()
        code, _ = self._run()
        self.assertEqual(code, 0)
        self.assertEqual((self.out / "site_catalogue.json").read_bytes(), first)

    def test_open_only_leaves_out_the_own_terms_sources(self):
        code, _ = self._run("--open-only")
        self.assertEqual(code, 0)
        doc = self._doc()
        self.assertFalse(
            any(site["source"] in fmt.OWN_TERMS_SOURCES for site in doc["sites"])
        )
        self.assertNotIn("njdep", doc["metadata"]["sources"])

    def test_new_jersey_s_metadata_travels_with_its_records(self):
        code, _ = self._run()
        self.assertEqual(code, 0)
        shipped = self.out / "site_catalogue_njdep_metadata.xml"
        self.assertEqual(
            shipped.read_text(encoding="utf-8"), "<metadata>NJDEP</metadata>"
        )

    def test_new_jersey_does_not_ship_without_its_metadata(self):
        # NJDEP's agreement: its data may not be redistributed without all
        # the metadata provided.
        self.with_metadata = False
        code, output = self._run()
        self.assertEqual(code, 2)
        self.assertIn("metadata", output)
        self.assertFalse((self.out / "site_catalogue.json").exists())

    def test_without_new_jersey_no_metadata_is_needed_or_shipped(self):
        self.with_metadata = False
        code, _ = self._run("--without", "njdep", leave_out=("njdep",))
        self.assertEqual(code, 0)
        self.assertFalse(
            (self.out / "site_catalogue_njdep_metadata.xml").exists()
        )

    def test_open_only_needs_somewhere_of_its_own_to_write(self):
        # Without --out it would replace the catalogue the app ships and
        # delete New Jersey's metadata beside it.
        self._run()
        output = io.StringIO()
        with redirect_stdout(output):
            code = merge.main(
                ["--cache", str(self.cache), "--open-only"],
                places=_Places(),
                curated=_CURATED,
            )
        self.assertEqual(code, 2)
        self.assertIn("--out", output.getvalue())

    def test_the_open_only_catalogue_ships_no_new_jersey_metadata(self):
        code, _ = self._run("--open-only")
        self.assertEqual(code, 0)
        self.assertFalse(
            (self.out / "site_catalogue_njdep_metadata.xml").exists()
        )

    def test_ids_gone_and_new_are_reported_against_the_file_replaced(self):
        self._run()
        old = self._doc()
        old["sites"].append(
            {"id": "ukho_999999", "name": "Gone", "source": "ukho",
             "trust": "verified", "kind": "register", "lat": 1, "lon": 2}
        )
        (self.out / "site_catalogue.json").write_text(
            json.dumps(old), encoding="utf-8"
        )
        _, output = self._run()
        self.assertIn("ukho_999999", output)
        self.assertIn("gone", output.lower())


if __name__ == "__main__":
    unittest.main()
