#!/usr/bin/env python3
"""Unit tests for the sources' fetch functions.

Run: python3 scripts/site_catalogue/fetch_test.py

Each source downloads its register and writes a snapshot the merge later
reads with no network. These tests stand in for the network and pin what a
fetch does with an answer: it writes the rows under its own key, and it
stops, naming the column, when a register no longer carries a column the
gate reads. A fetch that passed such an answer on would hand the merge a
snapshot every row of which fails its gate, or none.
"""

import io
import json
import os
import sqlite3
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [_HERE, os.path.dirname(_HERE)]

import places  # noqa: E402
import src_awois  # noqa: E402
import src_ireland  # noqa: E402
import src_osm  # noqa: E402
import src_reefs  # noqa: E402
import src_ukho  # noqa: E402
import src_wikidata  # noqa: E402

_SAMPLES = os.path.join(_HERE, "samples")


def _bytes(name):
    with open(os.path.join(_SAMPLES, name), "rb") as file:
        return file.read()


def _json(name):
    return json.loads(_bytes(name).decode("utf-8"))


class _Written:
    """Stands in for `write_snapshot`: keeps what a fetch wrote."""

    def __init__(self):
        self.snapshots = {}

    def __call__(self, key, url, rows, *args, **kwargs):
        self.snapshots[key] = list(rows)
        return f"{key}.json"


class RegisterFetchTest(unittest.TestCase):
    """The three wreck registers: one file each, parsed as it arrives."""

    def test_the_ukho_register_is_read_out_of_its_archive(self):
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("readme.pdf", b"not the register")
            bundle.writestr("Wrecks.txt", _bytes("ukho.tsv"))
        written = _Written()
        with mock.patch.object(
            src_ukho, "http_get", return_value=archive.getvalue()
        ), mock.patch.object(src_ukho, "write_snapshot", written):
            src_ukho.fetch()
        self.assertEqual(len(written.snapshots["ukho"]), 18)
        self.assertIn("wreck_id", written.snapshots["ukho"][0])

    def test_a_ukho_file_without_a_gate_column_stops_the_fetch(self):
        lines = _bytes("ukho.tsv").split(b"\n")
        lines[0] = lines[0].replace(b"water_level_effect", b"water_effect")
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("Wrecks.txt", b"\n".join(lines))
        written = _Written()
        with mock.patch.object(
            src_ukho, "http_get", return_value=archive.getvalue()
        ), mock.patch.object(src_ukho, "write_snapshot", written):
            with self.assertRaises(ValueError) as raised:
                src_ukho.fetch()
        self.assertIn("water_level_effect", str(raised.exception))
        self.assertEqual(written.snapshots, {})

    def test_awois_and_the_irish_inventory_are_written_under_their_keys(self):
        for module, sample, key in (
            (src_awois, "awois.kml", "awois"),
            (src_ireland, "ireland.csv", "nms_ie"),
        ):
            written = _Written()
            with mock.patch.object(
                module, "http_get", return_value=_bytes(sample)
            ), mock.patch.object(module, "write_snapshot", written):
                module.fetch()
            self.assertGreater(len(written.snapshots[key]), 0, key)

    def test_an_error_page_in_place_of_a_register_stops_the_fetch(self):
        for module in (src_awois, src_ireland):
            written = _Written()
            with mock.patch.object(
                module, "http_get", return_value=b"<html>Not found</html>"
            ), mock.patch.object(module, "write_snapshot", written):
                with self.assertRaises(ValueError):
                    module.fetch()
            self.assertEqual(written.snapshots, {})


class ReefFetchTest(unittest.TestCase):
    """The reef programs: four ArcGIS layers and one GeoPackage."""

    _LAYERS = (
        ("fetch_fwc", "fwc", "fwc.geojson", src_reefs.geojson_rows, "DeployID"),
        ("fetch_nc_dmf", "nc_dmf", "nc_dmf.json", src_reefs.arcgis_rows, "REEF__"),
        ("fetch_fknms", "fknms", "fknms.geojson", src_reefs.geojson_rows,
         "BuoyType"),
    )

    def test_each_layer_is_written_under_its_key(self):
        for fetch, key, sample, to_rows, _ in self._LAYERS:
            rows = to_rows(_json(sample))
            written = _Written()
            with mock.patch.object(
                src_reefs, "_arcgis_pages", return_value=rows
            ), mock.patch.object(src_reefs, "write_snapshot", written):
                getattr(src_reefs, fetch)()
            self.assertEqual(len(written.snapshots[key]), len(rows), key)

    def test_a_layer_that_lost_a_column_stops_its_fetch(self):
        for fetch, key, sample, to_rows, column in self._LAYERS:
            rows = [
                {name: value for name, value in row.items() if name != column}
                for row in to_rows(_json(sample))
            ]
            written = _Written()
            with mock.patch.object(
                src_reefs, "_arcgis_pages", return_value=rows
            ), mock.patch.object(src_reefs, "write_snapshot", written):
                with self.assertRaises(ValueError) as raised:
                    getattr(src_reefs, fetch)()
            self.assertIn(column, str(raised.exception), key)
            self.assertEqual(written.snapshots, {}, key)

    def test_new_jersey_s_metadata_is_saved_with_its_rows(self):
        rows = src_reefs.arcgis_rows(_json("njdep.json"))
        written = _Written()
        with mock.patch.object(
            src_reefs, "_arcgis_pages", return_value=rows
        ), mock.patch.object(
            src_reefs, "save_njdep_metadata"
        ) as metadata, mock.patch.object(src_reefs, "write_snapshot", written):
            src_reefs.fetch_njdep()
        metadata.assert_called_once()
        self.assertEqual(len(written.snapshots["njdep"]), len(rows))

    def test_new_jersey_without_a_column_saves_nothing(self):
        rows = [
            {name: value for name, value in row.items() if name != "REEF_SITE"}
            for row in src_reefs.arcgis_rows(_json("njdep.json"))
        ]
        written = _Written()
        with mock.patch.object(
            src_reefs, "_arcgis_pages", return_value=rows
        ), mock.patch.object(
            src_reefs, "save_njdep_metadata"
        ) as metadata, mock.patch.object(src_reefs, "write_snapshot", written):
            with self.assertRaises(ValueError) as raised:
                src_reefs.fetch_njdep()
        self.assertIn("REEF_SITE", str(raised.exception))
        metadata.assert_not_called()
        self.assertEqual(written.snapshots, {})

    def test_a_layer_is_read_a_page_at_a_time(self):
        def page(numbers):
            return json.dumps({"features": [
                {"attributes": {"N": n}, "geometry": {"x": -74.0, "y": 39.5}}
                for n in numbers
            ]}).encode()

        pages = [page(range(3)), page(range(3, 5)), page([])]
        with mock.patch.object(
            src_reefs, "http_get", side_effect=pages
        ) as get, mock.patch.object(src_reefs.time, "sleep"):
            rows = src_reefs._arcgis_pages("https://example.invalid/0", "json", 3)
        self.assertEqual([row["N"] for row in rows], [0, 1, 2, 3, 4])
        # Each page starts where the last one ended.
        self.assertEqual(
            [call.kwargs["params"]["resultOffset"] for call in get.call_args_list][:2],
            [0, 3],
        )

    def test_a_layer_that_answers_with_an_error_stops_the_fetch(self):
        body = json.dumps({"error": {"code": 400, "message": "bad"}}).encode()
        with mock.patch.object(
            src_reefs, "http_get", return_value=body
        ), mock.patch.object(src_reefs.time, "sleep"):
            with self.assertRaises(RuntimeError) as raised:
                src_reefs._arcgis_pages("https://example.invalid/0", "json", 3)
        self.assertIn("bad", str(raised.exception))

    def _geopackage(self, columns):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "reefs.gpkg")
            database = sqlite3.connect(path)
            database.execute("create table gpkg_contents (table_name text)")
            database.execute("insert into gpkg_contents values ('ArtificialReef')")
            database.execute(
                "create table ArtificialReef ({})".format(
                    ", ".join(f"{column} text" for column in columns)
                )
            )
            database.execute(
                "insert into ArtificialReef values ({})".format(
                    ", ".join("?" for _ in columns)
                ),
                [f"value of {column}" for column in columns],
            )
            database.commit()
            database.close()
            archive = io.BytesIO()
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.write(path, "ArtificialReef/ArtificialReef.gpkg")
            return archive.getvalue()

    def test_the_federal_file_is_read_out_of_its_geopackage(self):
        written = _Written()
        with mock.patch.object(
            src_reefs, "http_get",
            return_value=self._geopackage(src_reefs.FEDERAL_FIELDS),
        ), mock.patch.object(src_reefs, "write_snapshot", written):
            src_reefs.fetch_federal()
        self.assertEqual(
            written.snapshots["noaa_reefs"],
            [{field: f"value of {field}" for field in src_reefs.FEDERAL_FIELDS}],
        )

    def test_a_federal_file_without_a_column_stops_the_fetch(self):
        columns = [
            field for field in src_reefs.FEDERAL_FIELDS if field != "reefName"
        ]
        written = _Written()
        with mock.patch.object(
            src_reefs, "http_get", return_value=self._geopackage(columns)
        ), mock.patch.object(src_reefs, "write_snapshot", written):
            with self.assertRaises(sqlite3.OperationalError) as raised:
                src_reefs.fetch_federal()
        self.assertIn("reefName", str(raised.exception))
        self.assertEqual(written.snapshots, {})


class _Geocoder:
    def __init__(self):
        self.asked = []

    def lookup_place(self, lat, lon):
        self.asked.append((lat, lon))
        return ("BQ", "Caribbean Netherlands", "Bonaire")


class OsmFetchTest(unittest.TestCase):
    def test_wrecks_are_written_as_overpass_answered(self):
        elements = _json("osm_wrecks.json")["elements"]
        written = _Written()
        with mock.patch.object(
            src_osm, "_overpass", return_value=elements
        ), mock.patch.object(src_osm, "write_snapshot", written):
            src_osm.fetch_wrecks()
        self.assertEqual(written.snapshots["osm_wrecks"], elements)

    def test_only_the_sites_that_will_ship_located_are_geocoded(self):
        elements = [
            dict(type="node", id=1, lat=12.08, lon=-68.28,
                 tags={"sport": "scuba_diving", "name": "Salt Pier"}),
            # A business, an object with no name and one with no position.
            dict(type="node", id=2, lat=12.1, lon=-68.3,
                 tags={"sport": "scuba_diving", "name": "Dive Shop",
                       "amenity": "dive_centre"}),
            dict(type="node", id=3, lat=12.2, lon=-68.3,
                 tags={"sport": "scuba_diving"}),
            dict(type="relation", id=4,
                 tags={"sport": "scuba_diving", "name": "Somewhere"}),
        ]
        geocoder = _Geocoder()
        written = _Written()
        with mock.patch.object(
            src_osm, "_overpass", return_value=elements
        ), mock.patch.object(src_osm, "write_snapshot", written):
            src_osm.fetch_sites(resolver=geocoder)
        self.assertEqual(geocoder.asked, [(12.08, -68.28)])
        rows = {row["id"]: row for row in written.snapshots["osm_sites"]}
        self.assertEqual(len(rows), 4)
        self.assertEqual(
            rows[1]["geocoded"], ["BQ", "Caribbean Netherlands", "Bonaire"]
        )
        for other in (2, 3, 4):
            self.assertNotIn("geocoded", rows[other])

    def test_an_answer_overpass_cut_short_stops_the_fetch(self):
        body = json.dumps(
            {"elements": [{"id": 1}], "remark": "runtime error: timed out"}
        ).encode()
        with mock.patch.object(src_osm, "http_get", return_value=body):
            with self.assertRaises(RuntimeError) as raised:
                src_osm._overpass("[out:json];node(1);out;")
        self.assertIn("timed out", str(raised.exception))

    def test_a_whole_answer_is_its_elements(self):
        body = json.dumps({"elements": [{"id": 1}, {"id": 2}]}).encode()
        with mock.patch.object(src_osm, "http_get", return_value=body):
            self.assertEqual(
                src_osm._overpass("[out:json];node(1);out;"),
                [{"id": 1}, {"id": 2}],
            )


def _binding(item, label=None, lat=None, lon=None, precision=None):
    binding = {"item": {"value": f"http://www.wikidata.org/entity/{item}"}}
    for key, value in (
        ("label", label), ("lat", lat), ("lon", lon), ("precision", precision),
    ):
        if value is not None:
            binding[key] = {"value": str(value)}
    if lat is not None:
        binding["globe"] = {"value": "http://www.wikidata.org/entity/Q2"}
    return binding


class WikidataFetchTest(unittest.TestCase):
    def test_sites_and_the_wrecks_with_an_article_are_written(self):
        answers = {
            src_wikidata.SITE_QUERY: [
                _binding("Q10", "Sodwana Bay", -27.5, 32.7, 1e-5),
            ],
            src_wikidata.WRECK_POSITION_QUERIES[0]: [
                _binding("Q20", "SS Thistlegorm", 27.814, 33.921, 1e-5),
                _binding("Q21", "An unremarked hull", 50.1, -1.2, 1e-5),
            ],
            src_wikidata.WRECK_POSITION_QUERIES[1]: [
                _binding("Q22", "HMS Erne", 57.607, -1.807, 1e-6),
            ],
            src_wikidata.WRECK_ARTICLE_QUERIES[0]: [_binding("Q20")],
            src_wikidata.WRECK_ARTICLE_QUERIES[1]: [_binding("Q22")],
        }
        written = _Written()
        with mock.patch.object(
            src_wikidata, "_query", side_effect=lambda query: answers[query]
        ) as query, mock.patch.object(
            src_wikidata.time, "sleep"
        ) as sleep, mock.patch.object(src_wikidata, "write_snapshot", written):
            src_wikidata.fetch()
        self.assertEqual(query.call_count, 5)
        # A pause before every query after the first: the service allows
        # about one a minute.
        self.assertEqual(sleep.call_count, 4)
        self.assertEqual(
            [row["item"] for row in written.snapshots["wikidata_sites"]], ["Q10"]
        )
        self.assertEqual(
            sorted(row["item"] for row in written.snapshots["wikidata_wrecks"]),
            ["Q20", "Q22"],
        )

    def test_a_query_s_answer_is_its_bindings(self):
        body = json.dumps({"results": {"bindings": [{"x": 1}]}}).encode()
        with mock.patch.object(src_wikidata, "http_get", return_value=body):
            self.assertEqual(src_wikidata._query("select"), [{"x": 1}])


class BoundariesFetchTest(unittest.TestCase):
    def test_the_three_layers_are_saved_under_their_names(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            with mock.patch.object(
                places, "http_get", return_value=b'{"features": []}'
            ) as get:
                places.fetch_boundaries(cache)
            saved = sorted(path.name for path in (cache / "naturalearth").iterdir())
            self.assertEqual(
                saved,
                sorted([places.UNITS_FILE, places.REGIONS_FILE, places.LAKES_FILE]),
            )
            self.assertEqual(get.call_count, 3)

    def test_the_lookup_names_a_layer_that_was_never_downloaded(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(FileNotFoundError) as raised:
                places.load_places(Path(folder))
        self.assertIn(places.UNITS_FILE, str(raised.exception))


if __name__ == "__main__":
    unittest.main()
