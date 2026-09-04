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
(see NEAR_SHORE_KM in sea_area_index.dart), because IHO limits stop at the
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

# Coastline simplification, in degrees. 0.05 deg is ~5.5 km, which matches
# the resolver's near-shore tolerance; finer detail doubles the asset for no
# measurable gain in which sea a dive site lands in.
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


def build(payload: dict[str, Any]) -> dict[str, Any]:
    areas = []
    for feature in payload["features"]:
        area = build_area(feature["properties"]["name"], feature["geometry"])
        if area is None:
            logger.warning("Dropped empty feature: %s", feature["properties"])
            continue
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
    args = parser.parse_args()

    payload = (
        json.loads(args.input.read_text(encoding="utf-8"))
        if args.input
        else download(WFS_URL)
    )
    output = build(payload)
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
