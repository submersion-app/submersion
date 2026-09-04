#!/usr/bin/env python3
"""
IHO Sea Area Harvester

Builds the offline body-of-water lookup table shipped with Submersion.

Nominatim cannot answer "which sea is this?": OpenStreetMap has no ocean or
sea polygons, so a reverse geocode anywhere in open salt water returns
nothing and a near-shore one snaps to the closest land feature. Almost every
dive happens in salt water, so the app carries its own table instead.

The source is IHO Sea Areas v3, the digitised form of "Limits of Oceans &
Seas, Special Publication No. 23" (IHO, 1953), published by the Flanders
Marine Institute under CC-BY 4.0:

    Flanders Marine Institute (2018). IHO Sea Areas, version 3.
    https://www.marineregions.org/ - https://doi.org/10.14284/323

The full layer is ~250 MB of coordinates. This script simplifies it to
roughly a megabyte, which is the resolution the runtime lookup actually
needs: the resolver already tolerates a few kilometres of coastline error
(see nearShoreKm in sea_area_index.dart), because IHO limits stop at the
legal boundary of a sea and dive-site coordinates are routinely recorded
from a beach or a moored boat.

Usage:
    python scripts/sea_area_harvester.py

Output:
    assets/data/sea_areas.json
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from shapely.geometry import Polygon, shape

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
OUTPUT_FILE = PROJECT_ROOT / "assets" / "data" / "sea_areas.json"

WFS_URL = (
    "https://geo.vliz.be/geoserver/MarineRegions/wfs"
    "?service=WFS&version=1.0.0&request=GetFeature"
    "&typeName=MarineRegions:iho&outputFormat=application%2Fjson"
)
USER_AGENT = "SeaAreaHarvester/1.0 (Submersion Dive Log App)"
DOWNLOAD_TIMEOUT = 900  # seconds; the raw layer is ~250 MB

SOURCE_CITATION = (
    "Flanders Marine Institute (2018). IHO Sea Areas, version 3. "
    "Available online at https://www.marineregions.org/. "
    "https://doi.org/10.14284/323"
)
SOURCE_LICENSE = "CC-BY 4.0"

# Coastline simplification, in degrees. 0.05 deg is ~5.5 km of latitude,
# and less longitude the further from the equator (~2.8 km at 60 degrees).
# So the error it introduces is not equal to the resolver's 4 km near-shore
# tolerance (nearShoreKm in sea_area_index.dart), but it sits in the same
# few-kilometre band -- which is the point: detail finer than that band is
# swallowed by the tolerance rather than changing which sea a dive site
# lands in, and it doubles the asset. Measured: halving this to 0.02 deg
# left all 30 curated sites and the 3,256-site corpus unchanged.
SIMPLIFY_TOLERANCE = 0.05

# Coordinates are stored to this many decimals: ~110 m, far below the
# simplification error, and it keeps the JSON a third smaller than the
# full float repr.
COORD_DECIMALS = 3

# Islands smaller than this are dropped from the polygon holes. The unit is
# square degrees, so the physical threshold shrinks towards the poles:
# ~615 km2 at the equator, ~310 km2 at 60 degrees. A dive site on a small
# island should report the sea around it, so only landmasses big enough to
# hold an inland dive site of their own (Cuba, Sicily, Iceland, Tasmania)
# are worth carving out. Keeping every islet instead grows the asset from
# ~1 MB to ~14 MB.
MIN_HOLE_AREA = 0.05

# Names as a diver would write them. IHO's own labels are either split
# ("Mediterranean Sea - Western Basin"), archaic ("Barentsz Sea") or
# alternatives ("Andaman or Burma Sea"). Both Mediterranean basins collapse
# to one name on purpose: the resolver picks the smallest matching area, so
# the Adriatic, Aegean, Ionian and Tyrrhenian still win where they apply.
NAME_OVERRIDES = {
    "Andaman or Burma Sea": "Andaman Sea",
    "Balearic (Iberian Sea)": "Balearic Sea",
    "Barentsz Sea": "Barents Sea",
    "Eastern China Sea": "East China Sea",
    "Irish Sea and St. George's Channel": "Irish Sea",
    "Japan Sea": "Sea of Japan",
    "Mediterranean Sea - Eastern Basin": "Mediterranean Sea",
    "Mediterranean Sea - Western Basin": "Mediterranean Sea",
    "Molukka Sea": "Molucca Sea",
    "Rio de La Plata": "Rio de la Plata",
    "Seto Naikai or Inland Sea": "Seto Inland Sea",
    "The Coastal Waters of Southeast Alaska and British Columbia": (
        "Coastal Waters of Southeast Alaska and British Columbia"
    ),
    "The Northwestern Passages": "Northwestern Passages",
}

# Languages the app can display place names in, matching
# PlaceNameLanguage.supportedCodes. English is not fetched: the IHO display
# name above is the English one, and it is what every other language falls
# back to.
TRANSLATION_LANGUAGES = [
    "es",
    "fr",
    "de",
    "it",
    "nl",
    "pt",
    "hu",
    "ar",
    "he",
    "zh",
]

WIKIDATA_ENDPOINT = "https://www.wikidata.org/w/api.php"

# Wikidata item per sea, so the shipped table can name a sea in the diver's
# own language. Hand-reviewed rather than matched by name at build time,
# and worth keeping that way: these were resolved by checking each
# candidate's coordinate falls inside that sea's own polygon, and three
# still came back wrong because a coordinate inside a polygon does not make
# an entity the polygon. "North Pacific Ocean" matched the Marshall
# Islands, which really are in the North Pacific; "Arctic Ocean" matched
# the polar land region; "Mediterranean Sea" matched the basin of
# surrounding countries. A second pass comparing each item's English label
# against the name here is what caught them.
#
# A handful legitimately differ in spelling from the IHO label and are
# correct: Ceram/Seram Sea, Gulf of St./Saint Lawrence, Malacca
# Strait/Strait of Malacca, and Rio/Rio de la Plata. "The Northwestern
# Passages" has no better item than the Northwest Passage route.
WIKIDATA_QIDS = {
    "Adriatic Sea":                                            "Q13924",
    "Aegean Sea":                                              "Q34575",
    "Alboran Sea":                                             "Q199408",
    "Andaman Sea":                                             "Q47632",
    "Arabian Sea":                                             "Q58705",
    "Arafura Sea":                                             "Q128880",
    "Arctic Ocean":                                            "Q788",
    "Baffin Bay":                                              "Q37040",
    "Balearic Sea":                                            "Q200712",
    "Bali Sea":                                                "Q277014",
    "Baltic Sea":                                              "Q545",
    "Banda Sea":                                               "Q171510",
    "Barents Sea":                                             "Q45823",
    "Bass Strait":                                             "Q171846",
    "Bay of Bengal":                                           "Q38684",
    "Bay of Biscay":                                           "Q41573",
    "Bay of Fundy":                                            "Q181857",
    "Beaufort Sea":                                            "Q131274",
    "Bering Sea":                                              "Q44725",
    "Bismarck Sea":                                            "Q199436",
    "Black Sea":                                               "Q166",
    "Bristol Channel":                                         "Q188203",
    "Caribbean Sea":                                           "Q1247",
    "Celebes Sea":                                             "Q19270",
    "Celtic Sea":                                              "Q81499",
    "Ceram Sea":                                               "Q210855",
    "Chukchi Sea":                                             "Q159252",
    "Coastal Waters of Southeast Alaska and British Columbia": "Q5138334",
    "Coral Sea":                                               "Q82931",
    "Davis Strait":                                            "Q189262",
    "East China Sea":                                          "Q45341",
    "East Siberian Sea":                                       "Q163434",
    "English Channel":                                         "Q34640",
    "Flores Sea":                                              "Q150370",
    "Great Australian Bight":                                  "Q186733",
    "Greenland Sea":                                           "Q132868",
    "Gulf of Aden":                                            "Q41837",
    "Gulf of Alaska":                                          "Q180531",
    "Gulf of Aqaba":                                           "Q81611",
    "Gulf of Boni":                                            "Q641148",
    "Gulf of Bothnia":                                         "Q122574",
    "Gulf of California":                                      "Q132811",
    "Gulf of Finland":                                         "Q14686",
    "Gulf of Guinea":                                          "Q41430",
    "Gulf of Mexico":                                          "Q12630",
    "Gulf of Oman":                                            "Q79948",
    "Gulf of Riga":                                            "Q174731",
    "Gulf of St. Lawrence":                                    "Q169523",
    "Gulf of Suez":                                            "Q168277",
    "Gulf of Thailand":                                        "Q131217",
    "Gulf of Tomini":                                          "Q1507546",
    "Halmahera Sea":                                           "Q212083",
    "Hudson Bay":                                              "Q3040",
    "Hudson Strait":                                           "Q207702",
    "Indian Ocean":                                            "Q1239",
    "Inner Seas off the West Coast of Scotland":               "Q5762423",
    "Ionian Sea":                                              "Q37495",
    "Irish Sea":                                               "Q41735",
    "Java Sea":                                                "Q49364",
    "Kara Sea":                                                "Q33629",
    "Kattegat":                                                "Q131716",
    "Labrador Sea":                                            "Q184189",
    "Laccadive Sea":                                           "Q544914",
    "Laptev Sea":                                              "Q7988",
    "Ligurian Sea":                                            "Q42820",
    "Lincoln Sea":                                             "Q243125",
    "Makassar Strait":                                         "Q194477",
    "Malacca Strait":                                          "Q48359",
    "Mediterranean Sea":                                       "Q4918",
    "Molucca Sea":                                             "Q185291",
    "Mozambique Channel":                                      "Q165100",
    "North Atlantic Ocean":                                    "Q350134",
    "North Pacific Ocean":                                     "Q12353254",
    "North Sea":                                               "Q1693",
    "Northwestern Passages":                                   "Q81136",
    "Norwegian Sea":                                           "Q47545",
    "Persian Gulf":                                            "Q34675",
    "Philippine Sea":                                          "Q159183",
    "Red Sea":                                                 "Q23406",
    "Rio de la Plata":                                         "Q35827",
    "Savu Sea":                                                "Q193465",
    "Sea of Azov":                                             "Q35000",
    "Sea of Japan":                                            "Q27092",
    "Sea of Marmara":                                          "Q35367",
    "Sea of Okhotsk":                                          "Q41602",
    "Seto Inland Sea":                                         "Q231312",
    "Singapore Strait":                                        "Q205655",
    "Skagerrak":                                               "Q1695",
    "Solomon Sea":                                             "Q199479",
    "South Atlantic Ocean":                                    "Q1482804",
    "South China Sea":                                         "Q37660",
    "South Pacific Ocean":                                     "Q12355425",
    "Southern Ocean":                                          "Q7354",
    "Strait of Gibraltar":                                     "Q36124",
    "Sulu Sea":                                                "Q160194",
    "Tasman Sea":                                              "Q33254",
    "Timor Sea":                                               "Q131418",
    "Tyrrhenian Sea":                                          "Q38882",
    "White Sea":                                               "Q44133",
    "Yellow Sea":                                              "Q37960",
}

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def utc_timestamp() -> str:
    """Now, as RFC3339 UTC: 2026-09-04T06:33:21Z.

    `datetime.isoformat()` already writes the offset as "+00:00", so the
    conventional-looking `isoformat() + "Z"` yields "...+00:00Z", which no
    ISO-8601 parser accepts. Sub-second precision means nothing for a
    dataset build stamp, so seconds it is.
    """
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def download(url: str) -> dict[str, Any]:
    """Fetch the WFS layer as GeoJSON."""
    logger.info("Downloading IHO Sea Areas (this takes several minutes)...")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=DOWNLOAD_TIMEOUT) as response:
        payload = json.load(response)
    logger.info("Downloaded %d features", len(payload.get("features", [])))
    return payload


def flatten_ring(coords: Any) -> list[float] | None:
    """Round a ring to [lon, lat, lon, lat, ...], dropping repeated points.

    Returns None when rounding collapses the ring below a triangle.
    """
    rounded = [
        (round(x, COORD_DECIMALS), round(y, COORD_DECIMALS)) for x, y in coords
    ]
    deduped = [rounded[0]]
    for point in rounded[1:]:
        if point != deduped[-1]:
            deduped.append(point)
    # Count distinct points before closing: shapely hands over closed rings,
    # but the check has to mean "at least a triangle" either way.
    distinct = len(deduped) - 1 if deduped[0] == deduped[-1] else len(deduped)
    if distinct < 3:
        return None
    if deduped[0] != deduped[-1]:
        deduped.append(deduped[0])
    flat: list[float] = []
    for lon, lat in deduped:
        flat.append(lon)
        flat.append(lat)
    return flat


def build_area(name: str, geometry: Any) -> dict[str, Any] | None:
    """Simplify one IHO feature into the shipped area record."""
    simplified = shape(geometry).simplify(
        SIMPLIFY_TOLERANCE, preserve_topology=True
    )
    if simplified.is_empty:
        return None

    parts = (
        simplified.geoms
        if simplified.geom_type == "MultiPolygon"
        else [simplified]
    )
    polygons: list[dict[str, Any]] = []
    for part in parts:
        outer = flatten_ring(part.exterior.coords)
        if outer is None:
            continue
        holes: list[list[float]] = []
        for interior in part.interiors:
            if Polygon(interior).area < MIN_HOLE_AREA:
                continue
            hole = flatten_ring(
                Polygon(interior)
                .simplify(SIMPLIFY_TOLERANCE, preserve_topology=True)
                .exterior.coords
            )
            if hole is not None:
                holes.append(hole)
        polygon: dict[str, Any] = {"outer": outer}
        if holes:
            polygon["holes"] = holes
        polygons.append(polygon)

    if not polygons:
        return None

    min_lon, min_lat, max_lon, max_lat = simplified.bounds
    return {
        "name": NAME_OVERRIDES.get(name, name),
        "bbox": [
            round(min_lon, COORD_DECIMALS),
            round(min_lat, COORD_DECIMALS),
            round(max_lon, COORD_DECIMALS),
            round(max_lat, COORD_DECIMALS),
        ],
        "area": round(simplified.area, 4),
        "polygons": polygons,
    }


def normalize_label(label: str) -> str:
    """Fold typographic variants back to plain characters.

    Wikidata labels are human-entered and a few carry ligatures: the French
    Pacific labels arrive with U+FB01 in "Paci(fi)que", which sorts and
    searches as its own character and renders inconsistently. NFKC also
    settles Arabic presentation forms and non-breaking spaces.
    """
    return unicodedata.normalize("NFKC", label).strip()


def wikidata_request(url: str) -> dict[str, Any]:
    """One Wikidata API call, backing off when it rate-limits us."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    delay = 1.0
    for attempt in range(8):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            if attempt >= 4:
                raise
            time.sleep(delay)
            delay *= 2
        except OSError:
            if attempt >= 4:
                raise
            time.sleep(delay)
            delay *= 2
    raise RuntimeError(f"Wikidata kept refusing: {url}")


def fetch_translations() -> dict[str, dict[str, str]]:
    """Sea name per language, keyed by the English display name.

    English is absent on purpose: it is the area's own `name`, which every
    language falls back to. Coverage is not uniform -- Hungarian labels
    exist for about five sixths of these seas -- and a missing language is
    simply left out rather than guessed at.
    """
    names: dict[str, dict[str, str]] = {}
    by_qid = {qid: name for name, qid in WIKIDATA_QIDS.items()}
    qids = sorted(by_qid)
    languages = "|".join(TRANSLATION_LANGUAGES)
    for start in range(0, len(qids), 40):
        chunk = qids[start : start + 40]
        logger.info(
            "Fetching labels %d-%d of %d", start + 1, start + len(chunk), len(qids)
        )
        payload = wikidata_request(
            f"{WIKIDATA_ENDPOINT}?action=wbgetentities"
            f"&ids={'|'.join(chunk)}&props=labels"
            f"&languages={languages}&format=json"
        )
        for qid, entity in payload["entities"].items():
            labels = {
                language: normalize_label(label["value"])
                for language, label in entity.get("labels", {}).items()
                if language in TRANSLATION_LANGUAGES
            }
            if labels:
                names[by_qid[qid]] = labels
        time.sleep(1.0)
    return names


def build(
    payload: dict[str, Any],
    translations: dict[str, dict[str, str]] | None = None,
) -> dict[str, Any]:
    translations = translations or {}
    areas = []
    for feature in payload["features"]:
        area = build_area(feature["properties"]["name"], feature["geometry"])
        if area is None:
            logger.warning("Dropped empty feature: %s", feature["properties"])
            continue
        localized = translations.get(area["name"])
        if localized:
            area["names"] = dict(sorted(localized.items()))
        areas.append(area)

    # Ascending area is the resolver's precedence: the smallest polygon
    # containing a point wins, so the Gulf of Aqaba beats the Red Sea and
    # the Adriatic beats the Mediterranean without a hand-kept priority list.
    areas.sort(key=lambda a: (a["area"], a["name"]))

    vertices = sum(
        len(p["outer"]) // 2 + sum(len(h) // 2 for h in p.get("holes", ()))
        for a in areas
        for p in a["polygons"]
    )
    logger.info(
        "Built %d areas, %d polygons, %d vertices",
        len(areas),
        sum(len(a["polygons"]) for a in areas),
        vertices,
    )
    return {
        "metadata": {
            "generated_at": utc_timestamp(),
            "source": "IHO Sea Areas version 3 (Flanders Marine Institute)",
            "source_url": "https://doi.org/10.14284/323",
            "license": SOURCE_LICENSE,
            "citation": SOURCE_CITATION,
            "simplify_tolerance_degrees": SIMPLIFY_TOLERANCE,
            "coordinate_decimals": COORD_DECIMALS,
            "min_hole_area_square_degrees": MIN_HOLE_AREA,
            "translation_source": "Wikidata labels (CC0)",
            "translation_languages": list(TRANSLATION_LANGUAGES),
            "total_count": len(areas),
        },
        "areas": areas,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        type=Path,
        help="Read the raw WFS GeoJSON from a file instead of downloading it",
    )
    parser.add_argument("--output", type=Path, default=OUTPUT_FILE)
    parser.add_argument(
        "--names-cache",
        type=Path,
        help=(
            "Read sea name translations from this JSON file instead of "
            "querying Wikidata, and write them there after a fetch"
        ),
    )
    args = parser.parse_args()

    payload = (
        json.loads(args.input.read_text(encoding="utf-8"))
        if args.input
        else download(WFS_URL)
    )

    if args.names_cache and args.names_cache.exists():
        translations = json.loads(args.names_cache.read_text(encoding="utf-8"))
        logger.info("Loaded %d translated names from cache", len(translations))
    else:
        translations = fetch_translations()
        if args.names_cache:
            args.names_cache.write_text(
                json.dumps(translations, ensure_ascii=False, indent=1),
                encoding="utf-8",
            )

    output = build(payload, translations)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    logger.info(
        "Wrote %s (%.0f KB)",
        args.output,
        args.output.stat().st_size / 1024,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
