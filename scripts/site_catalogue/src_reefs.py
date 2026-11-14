#!/usr/bin/env python3
"""Artificial reefs and moorings: five sources.

- `fwc`: Florida's reef deployments (public domain).
- `noaa_reefs`: MarineCadastre's compilation of the other states' reefs
  (published as public domain). It is a compilation: each state's own
  terms decide what ships. New York's forbid distribution, so its rows
  are dropped. Florida, New Jersey and North Carolina are read from their
  own files instead. Hawaii and Texas allow non-commercial use only, so
  their rows become own-terms sources (`hi_dar`, `tpwd`).
- `njdep`: New Jersey's deployments, from the state's own layer, under its
  Data Distribution Agreement (own terms).
- `nc_dmf`: North Carolina's reef sites, carried exactly as published (its
  terms allow non-commercial copying "without alteration").
- `fknms`: the Florida Keys sanctuary's mooring buoys. These mark places
  people dive, so they are dive site records, not register records.

A reef program lists deployments; `grouping` turns them into sites.

Run this file to download all five into the snapshot cache.
"""

import collections
import io
import json
import os
import re
import sqlite3
import sys
import tempfile
import time
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import records as rec  # noqa: E402
from grouping import group_by_name, mean_position  # noqa: E402
from snapshots import (  # noqa: E402
    CACHE_DIR,
    http_get,
    require_fields,
    write_snapshot,
)

MAX_DEPTH_M = 60.0

FWC_URL = (
    "https://gis.myfwc.com/mapping/rest/services/Open_Data/"
    "Artificial_Reef_Locations_in_Florida/MapServer/12"
)
FWC_REF = "https://www.arcgis.com/home/item.html?id=eb2bfd225149405bba23604f20159f56"
FEDERAL_URL = "https://marinecadastre.gov/downloads/data/mc/ArtificialReef.zip"
NJDEP_URL = (
    "https://mapsdep.nj.gov/arcgis/rest/services/Features/"
    "Environmental_admin/MapServer/42"
)
NJDEP_REF = "https://www.arcgis.com/home/item.html?id=862307fcb54b4f70a6bdb9915d4c149f"
NJDEP_METADATA_URL = (
    "https://www.arcgis.com/sharing/rest/content/items/"
    "862307fcb54b4f70a6bdb9915d4c149f/info/metadata/metadata.xml"
)
# New Jersey's metadata for its layer, as saved beside the snapshot. Its
# agreement requires the metadata to travel with the data, so the merge
# ships this file with the catalogue.
NJDEP_METADATA_CACHE_FILE = "njdep_metadata.xml"
NC_DMF_URL = (
    "https://services2.arcgis.com/kCu40SDxsCGcuUWO/arcgis/rest/services/"
    "DMF_ReefGuide/FeatureServer/0"
)
NC_DMF_REF = (
    "https://www.deq.nc.gov/about/divisions/marine-fisheries/"
    "public-information-and-education/coastal-fishing-information/"
    "artificial-reefs/interactive-reef-guide"
)
FKNMS_URL = (
    "https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/"
    "PubFKNMSBuoy2025/FeatureServer/0"
)
FKNMS_REF = "https://floridakeys.noaa.gov/mbuoy/allmbuoys.html"

# Rows of the federal file that never ship from it: New York's terms forbid
# distribution; the other three are read from their own, fuller files.
EXCLUDED_STATES = ("FL", "NJ", "NC", "NY")
# States whose terms allow non-commercial use only: their own source keys.
OWN_TERMS_STATES = {"HI": "hi_dar", "TX": "tpwd"}

# Each state's own reef program page, a federal-file record's reference.
STATE_PAGES = {
    "AL": "https://www.outdooralabama.com/saltwater-fishing/artificial-reefs",
    "CA": "https://wildlife.ca.gov/Conservation/Marine/Artificial-Reefs",
    "DE": "https://data.delaware.gov/stories/s/Artificial-Reefs/adne-snct/",
    "GA": "https://coastalgadnr.org/HERU/downloads",
    "HI": "https://dlnr.hawaii.gov/dar/fishing/artificial-reefs-and-fads/",
    "LA": "https://www.wlf.louisiana.gov/page/artificial-reefs",
    "MA": "https://www.mass.gov/service-details/artificial-reefs",
    "MD": "https://dnr.maryland.gov/fisheries/pages/reefs/index.aspx",
    "MS": "https://dmr.ms.gov/artificial-reef/",
    "PR": "https://www.fisheries.noaa.gov/inport/item/54191",
    "RI": "https://www.fisheries.noaa.gov/inport/item/54191",
    "SC": "https://www.dnr.sc.gov/marine/reef/",
    "TX": "https://tpwd.texas.gov/landwater/water/habitats/artificial_reef/",
    "VA": "https://webapps.mrc.virginia.gov/public/maps/artificial_reefs_list.php",
}
FEDERAL_REF = "https://www.fisheries.noaa.gov/inport/item/54191"

FEDERAL_FIELDS = (
    "reefIdentifier", "reefName", "reefComposition", "reefStructure",
    "reefYear", "stateAbbreviation", "waterDepthFeet", "latitudeDMS",
    "longitudeDMS",
)

_MOORINGS = frozenset({"Mooring", "Mooring Wreck", "Mooring-LV"})
_VESSEL = re.compile(
    r"\b(ship|vessel|tug|tugboat|barge|boat|trawler|ferry|freighter|tanker)\b",
    re.IGNORECASE,
)
# What Florida calls each material category, as a description says it.
_FWC_MATERIALS = {
    "Module": "Reef modules",
    "Concrete": "Concrete",
    "Vessel": "Vessel",
    "Metal": "Metal structure",
    "Rock": "Rock",
}
# "Kualoa Artificial Reef - Corner A": a marker at the corner of a reef
# area, not a structure in it.
_AREA_CORNER = re.compile(r"\bCorner\s+[A-Z0-9]$", re.IGNORECASE)
_DMS = re.compile(r"^\s*(\d+)\s+(\d+)\s+([\d.]+)\s*([NSEW])\s*$")


def geojson_rows(doc: dict) -> list[dict]:
    """A GeoJSON collection's features as rows: their properties plus the
    point as `_lat` and `_lon`."""
    rows = []
    for feature in doc.get("features") or []:
        coordinates = (feature.get("geometry") or {}).get("coordinates") or [None, None]
        row = dict(feature.get("properties") or {})
        row["_lon"], row["_lat"] = coordinates[0], coordinates[1]
        rows.append(row)
    return rows


def arcgis_rows(doc: dict) -> list[dict]:
    """An ArcGIS JSON answer's features as rows: their attributes plus the
    point as `_lat` and `_lon`."""
    rows = []
    for feature in doc.get("features") or []:
        geometry = feature.get("geometry") or {}
        row = dict(feature.get("attributes") or {})
        row["_lon"], row["_lat"] = geometry.get("x"), geometry.get("y")
        rows.append(row)
    return rows


def _year(value) -> int | None:
    years = re.findall(r"(?<!\d)(1[89]\d\d|20\d\d)(?!\d)", str(value or ""))
    return int(years[-1]) if years else None


def _commonest(values) -> str | None:
    counted = collections.Counter(value for value in values if value)
    return counted.most_common(1)[0][0] if counted else None


def _earliest(years) -> int | None:
    years = [year for year in years if year]
    return min(years) if years else None


def _depths(depths_m):
    known = [depth for depth in depths_m if depth]
    return max(known) if known else None


# ---------------------------------------------------------------- Florida


def fwc_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    dropped = collections.Counter()
    items = []
    for row in rows:
        name = (row.get("Name") or "").strip()
        if rec.is_placeholder(name) or row.get("_lat") is None:
            dropped["no_name" if row.get("_lat") is not None else "no_position"] += 1
            continue
        depth = rec.number(row.get("Depth"))
        relief = rec.number(row.get("Relief"))
        items.append(
            dict(
                name=name,
                lat=row["_lat"],
                lon=row["_lon"],
                id=str(row.get("DeployID") or ""),
                depth=rec.feet(depth) if depth else None,
                top=rec.feet(depth - relief)
                if depth and relief and 0 < relief < depth
                else None,
                material=row.get("MatCat"),
                year=_year(row.get("DeployDate")),
            )
        )
    records = []
    for group in group_by_name(items):
        group.sort(key=lambda item: item["id"])
        depth = _depths(item["depth"] for item in group)
        if depth is not None and depth > MAX_DEPTH_M:
            dropped["too_deep"] += 1
            continue
        tops = [item["top"] for item in group if item["top"]]
        lat, lon = mean_position(group)
        material = _commonest(item["material"] for item in group)
        records.append(
            rec.working(
                id=f"fwc_{group[0]['id']}",
                name=rec.display_name(group[0]["name"]),
                lat=lat,
                lon=lon,
                source="fwc",
                kind="register",
                source_ref=FWC_REF,
                types=["artificial_reef"]
                + (["wreck"] if any(i["material"] == "Vessel" for i in group) else []),
                max_depth=depth,
                min_depth=min(tops) if tops else None,
                description=rec.fact_line(
                    _FWC_MATERIALS.get(material),
                    "placed",
                    _earliest(item["year"] for item in group),
                ),
            )
        )
    return records, dropped


# ------------------------------------------------------- the federal file


def _dms(text) -> float | None:
    match = _DMS.match(str(text or ""))
    if not match:
        return None
    value = (
        int(match.group(1)) + int(match.group(2)) / 60 + float(match.group(3)) / 3600
    )
    return -value if match.group(4) in "SW" else value


def _hundredths(value: float, positive: str, negative: str) -> str:
    return f"{positive if value >= 0 else negative}{round(abs(value) * 100):d}"


def _plain_structure(text) -> str | None:
    """A structure the file names in a word or two ("Tank", "Vessel"), or
    None for a free-text description or "Other"."""
    text = " ".join(str(text or "").split())
    if not text or text.lower() == "other" or len(text) > 30:
        return None
    return text if re.fullmatch(r"[A-Za-z ]+", text) else None


def federal_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    dropped = collections.Counter()
    by_state: dict[str, list[dict]] = {}
    for row in rows:
        state = (row.get("stateAbbreviation") or "").strip().upper()
        if state in EXCLUDED_STATES or not state:
            dropped["excluded_state"] += 1
            continue
        name = (row.get("reefName") or "").strip()
        if rec.is_placeholder(name):
            dropped["no_name"] += 1
            continue
        if _AREA_CORNER.search(name):
            dropped["area_corner"] += 1
            continue
        lat, lon = _dms(row.get("latitudeDMS")), _dms(row.get("longitudeDMS"))
        if lat is None or lon is None:
            dropped["no_position"] += 1
            continue
        depth = rec.number(row.get("waterDepthFeet"))
        structure = f"{row.get('reefStructure') or ''} {row.get('reefComposition') or ''}"
        by_state.setdefault(state, []).append(
            dict(
                name=name,
                lat=lat,
                lon=lon,
                depth=rec.feet(depth) if depth else None,
                vessel=bool(_VESSEL.search(structure)),
                structure=_plain_structure(row.get("reefStructure")),
                year=_year(row.get("reefYear")),
            )
        )
    records = []
    taken: set[str] = set()
    for state in sorted(by_state):
        sites = []
        for group in group_by_name(by_state[state]):
            depth = _depths(item["depth"] for item in group)
            if depth is not None and depth > MAX_DEPTH_M:
                dropped["too_deep"] += 1
                continue
            sites.append((mean_position(group), group, depth))
        # In position order, so the rare two sites of one name in one
        # hundredth of a degree are told apart the same way every run.
        for (lat, lon), group, depth in sorted(sites, key=lambda site: site[0]):
            # The name and where it is, to a hundredth of a degree: sites
            # of one name are a kilometre apart or more, and adding a
            # deployment moves a site's mean position by metres.
            site_id = "usreef_{}_{}_{}_{}".format(
                state.lower(),
                rec.slug(group[0]["name"]),
                _hundredths(lat, "n", "s"),
                _hundredths(lon, "e", "w"),
            )
            suffix = 2
            unique = site_id
            while unique in taken:
                unique = f"{site_id}_{suffix}"
                suffix += 1
            taken.add(unique)
            records.append(
                rec.working(
                    id=unique,
                    name=rec.display_name(group[0]["name"]),
                    lat=lat,
                    lon=lon,
                    source=OWN_TERMS_STATES.get(state, "noaa_reefs"),
                    kind="register",
                    source_ref=STATE_PAGES.get(state, FEDERAL_REF),
                    types=["artificial_reef"]
                    + (["wreck"] if any(item["vessel"] for item in group) else []),
                    max_depth=depth,
                    description=rec.fact_line(
                        _commonest(item["structure"] for item in group),
                        "placed",
                        _earliest(item["year"] for item in group),
                    ),
                )
            )
    return records, dropped


# ------------------------------------------------------------- New Jersey


def _nj_is_material(row: dict) -> bool:
    """Whether a New Jersey deployment's name only says what was sunk
    ("Subway Car", "Dredge Rock"), not which reef or vessel it is."""
    name = (row.get("NAME") or "").strip().lower()
    kind = (row.get("TYPE") or "").strip().lower()
    material = (row.get("MATERIAL") or "").strip().lower()
    return (
        rec.is_placeholder(name)
        or (kind and kind in name)
        or (kind.rstrip("s") and kind.rstrip("s") in name)
        or material.startswith(name)
    )


def njdep_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    dropped = collections.Counter()
    items = []
    for row in rows:
        name = (row.get("NAME") or "").strip()
        site = (row.get("REEF_SITE") or "").strip()
        if not name or not site:
            dropped["no_name"] += 1
            continue
        if row.get("_lat") is None or row.get("_lon") is None:
            dropped["no_position"] += 1
            continue
        reef = f"{site} Reef"
        items.append(
            dict(
                # Material carries its reef in the name; a vessel or a
                # named reef stands on its own, with the reef as its place.
                name=f"{reef}, {name}" if _nj_is_material(row) else name,
                locality=reef,
                lat=row["_lat"],
                lon=row["_lon"],
                id=int(row["UNIQUE_ID"]),
                kind=(row.get("TYPE") or "").strip(),
                year=_year(row.get("YEAR_DEPLOYED")),
            )
        )
    records = []
    for group in group_by_name(items):
        group.sort(key=lambda item: item["id"])
        lat, lon = mean_position(group)
        kind = _commonest(item["kind"] for item in group)
        records.append(
            rec.working(
                id=f"njreef_{group[0]['id']}",
                name=rec.display_name(group[0]["name"]),
                lat=lat,
                lon=lon,
                source="njdep",
                kind="register",
                source_ref=NJDEP_REF,
                types=["artificial_reef"]
                + (["wreck"] if any(item["kind"] == "Ship" for item in group) else []),
                locality=group[0]["locality"],
                description=rec.fact_line(
                    kind, "placed", _earliest(item["year"] for item in group)
                ),
            )
        )
    return records, dropped


# --------------------------------------------------------- North Carolina


def nc_dmf_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """One record per reef site, exactly as the state publishes it: its
    name or number and its position. Nothing is grouped, renamed or
    described."""
    dropped = collections.Counter()
    records = []
    for row in rows:
        number = (row.get("REEF__") or "").strip()
        if not number:
            dropped["no_name"] += 1
            continue
        if row.get("_lat") is None or row.get("_lon") is None:
            dropped["no_position"] += 1
            continue
        name = (row.get("REEF_NAME") or "").strip()
        records.append(
            rec.working(
                id=f"ncreef_{rec.slug(number)}",
                # The layer writes the word "None" for a reef with no name.
                name=name if name and name.lower() != "none" else number,
                lat=row["_lat"],
                lon=row["_lon"],
                source="nc_dmf",
                kind="register",
                source_ref=NC_DMF_REF,
                types=["artificial_reef"],
            )
        )
    return records, dropped


# ----------------------------------------------------------- Florida Keys


def fknms_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    dropped = collections.Counter()
    by_location: dict[str, list[dict]] = {}
    for row in rows:
        location = (row.get("Location") or "").strip()
        if row.get("BuoyType") not in _MOORINGS or not location:
            dropped["not_mooring"] += 1
            continue
        if row.get("_lat") is None or row.get("_lon") is None:
            dropped["no_position"] += 1
            continue
        depth = rec.number(row.get("Depth__ft_"))
        by_location.setdefault(location, []).append(
            dict(
                lat=row["_lat"],
                lon=row["_lon"],
                depth=rec.feet(depth) if depth else None,
                wreck=row.get("BuoyType") == "Mooring Wreck",
            )
        )
    records = []
    for location in sorted(by_location):
        buoys = by_location[location]
        lat, lon = mean_position(buoys)
        depths = [buoy["depth"] for buoy in buoys if buoy["depth"]]
        name = re.sub(r"^The\s+", "", location)
        records.append(
            rec.working(
                id=f"fknms_{rec.slug(name)}",
                name=name,
                lat=lat,
                lon=lon,
                source="fknms",
                kind="site",
                source_ref=FKNMS_REF,
                types=["wreck"] if any(buoy["wreck"] for buoy in buoys) else ["reef"],
                max_depth=max(depths) if depths else None,
                min_depth=min(depths)
                if len(depths) > 1 and min(depths) < max(depths)
                else None,
            )
        )
    return records, dropped


# ------------------------------------------------------------------ fetch


def _arcgis_pages(url: str, fmt: str, page_size: int) -> list[dict]:
    """Every row of an ArcGIS layer, a page at a time, a second apart."""
    rows: list[dict] = []
    offset = 0
    while True:
        doc = json.loads(
            http_get(
                url + "/query",
                params={
                    "where": "1=1",
                    "outFields": "*",
                    "outSR": "4326",
                    "f": fmt,
                    "orderByFields": "OBJECTID",
                    "resultOffset": offset,
                    "resultRecordCount": page_size,
                },
            )
        )
        if "error" in doc:
            raise RuntimeError(f"{url} answered {doc['error']}")
        page = geojson_rows(doc) if fmt == "geojson" else arcgis_rows(doc)
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size
        time.sleep(1)


def fetch_fwc():
    rows = _arcgis_pages(FWC_URL, "geojson", 2000)
    require_fields(rows[0], ("DeployID", "Name", "Depth", "Relief", "MatCat", "DeployDate"), "fwc")
    return write_snapshot("fwc", FWC_URL, rows)


def fetch_federal():
    archive = zipfile.ZipFile(io.BytesIO(http_get(FEDERAL_URL, timeout=600)))
    name = next(n for n in archive.namelist() if n.lower().endswith(".gpkg"))
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "reefs.gpkg")
        with open(path, "wb") as file:
            file.write(archive.read(name))
        database = sqlite3.connect(path)
        try:
            database.row_factory = sqlite3.Row
            table = database.execute(
                "select table_name from gpkg_contents"
            ).fetchone()[0]
            rows = [
                {field: row[field] for field in FEDERAL_FIELDS}
                for row in database.execute(
                    "select {} from \"{}\"".format(", ".join(FEDERAL_FIELDS), table)
                )
            ]
        finally:
            database.close()
    return write_snapshot("noaa_reefs", FEDERAL_URL, rows)


def save_njdep_metadata(cache=CACHE_DIR):
    """Downloads NJDEP's metadata document for the layer into the cache."""
    body = http_get(NJDEP_METADATA_URL)
    if not body.strip():
        raise ValueError("njdep: the metadata document came back empty")
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / NJDEP_METADATA_CACHE_FILE
    path.write_bytes(body)
    return path


def fetch_njdep():
    rows = _arcgis_pages(NJDEP_URL, "json", 2000)
    require_fields(rows[0], ("UNIQUE_ID", "REEF_SITE", "NAME", "TYPE", "MATERIAL", "YEAR_DEPLOYED"), "njdep")
    save_njdep_metadata()
    return write_snapshot("njdep", NJDEP_URL, rows)


def fetch_nc_dmf():
    rows = _arcgis_pages(NC_DMF_URL, "json", 1000)
    require_fields(rows[0], ("REEF_NAME", "REEF__"), "nc_dmf")
    return write_snapshot("nc_dmf", NC_DMF_URL, rows)


def fetch_fknms():
    rows = _arcgis_pages(FKNMS_URL, "geojson", 2000)
    require_fields(rows[0], ("Location", "BuoyType", "Depth__ft_"), "fknms")
    return write_snapshot("fknms", FKNMS_URL, rows)


if __name__ == "__main__":
    for fetch in (fetch_fwc, fetch_federal, fetch_njdep, fetch_nc_dmf, fetch_fknms):
        print(fetch())
        time.sleep(1)
