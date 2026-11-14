#!/usr/bin/env python3
"""Curated dive sites merged into the harvested site catalogue.

OpenStreetMap, the catalogue's source, has gaps: it holds no New Jersey ocean
sites at all. `dive_sites_curated.json` fills them with researched sites, and
`dive_site_harvester.py` merges it into every harvest so they survive.

Each curated entry carries a site's name, description and position plus
`source` (where its position came from), `depthM` and `kind`. All of them
reach the catalogue: the source as the record's `source_ref`, the depth as
its maximum depth, and the kind as a site type (wreck, wall, reef) or an
entry (shore). Descriptions are our own words; positions come from public
sources.

A curated site steps aside once OpenStreetMap gains a site of the same name
nearby, so a harvest never lists one site twice.
"""

import json
import math
from pathlib import Path

from site_catalogue_format import map_entry, to_catalogue_record

CURATED_FILE = Path(__file__).parent / "dive_sites_curated.json"

# A harvested site of the same name this close is the same site.
SAME_SITE_KM = 1.0

# The ISO code of each country a curated entry names. A wreck far offshore
# is beyond what the geocoder can place, so its own country stands, and
# needs its code from here.
CURATED_COUNTRY_CODES = {
    "Belize": "BZ",
    "Cayman Islands": "KY",
    "Honduras": "HN",
    "Turks and Caicos Islands": "TC",
    "United States": "US",
}


def load_curated(path: Path = CURATED_FILE) -> list[dict]:
    """The curated entries, as written in the curated file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _km(site: dict, entry: dict) -> float:
    """Kilometres between a catalogue record and a curated entry."""
    p1, p2 = math.radians(site["lat"]), math.radians(entry["latitude"])
    dp = p2 - p1
    dl = math.radians(entry["longitude"] - site["lon"])
    h = (
        math.sin(dp / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    )
    return 2 * 6371 * math.asin(math.sqrt(h))


def curated_record(
    entry: dict,
    *,
    country_code: str | None,
    country: str | None,
    island: str | None = None,
) -> dict:
    """The catalogue record for a curated entry.

    [island] is the island the geocoder placed it on, where its territory
    is several islands (Bonaire in the Caribbean Netherlands).
    """
    kind = entry.get("kind")
    is_entry = bool(map_entry(kind))
    working = {
        "id": entry["id"],
        "name": entry["name"],
        "description": entry.get("description"),
        "latitude": entry.get("latitude"),
        "longitude": entry.get("longitude"),
        "region": entry.get("region"),
        "island": island,
        "website": entry.get("website"),
        "max_depth": entry.get("depthM"),
        "entry_type": kind if is_entry else None,
        "features": [kind] if kind and not is_entry else [],
    }
    if country_code is None:
        # Not placed by the geocoder: the entry's own country, with its code.
        country = entry.get("country")
        country_code = CURATED_COUNTRY_CODES.get(country)
    return to_catalogue_record(
        working,
        source="curated",
        source_ref=entry.get("source"),
        country_code=country_code,
        country=country,
    )


def merge_curated(sites: list[dict], curated: list[dict], place_of) -> list[dict]:
    """[sites] followed by a catalogue record for each curated entry not
    already among them.

    [sites] are catalogue records. `place_of(latitude, longitude)` answers
    (ISO code, English name, island) for a curated entry's position, as
    `CountryResolver.lookup_place` does, so a curated site is placed exactly
    as a harvested one.

    A curated entry is left out when its id is already present, or when a
    site of the same name (ignoring case) lies within SAME_SITE_KM.
    """
    ids = {s["id"] for s in sites}
    merged = list(sites)
    for entry in curated:
        if entry["id"] in ids:
            continue
        name = entry["name"].casefold()
        if any(
            (s.get("name") or "").casefold() == name
            and s.get("lat") is not None
            and s.get("lon") is not None
            and _km(s, entry) <= SAME_SITE_KM
            for s in sites
        ):
            continue
        code, country, island = place_of(entry["latitude"], entry["longitude"])
        merged.append(
            curated_record(
                entry, country_code=code, country=country, island=island
            )
        )
        ids.add(entry["id"])
    return merged


def validate(curated: list[dict]) -> list[str]:
    """Every problem with the curated entries, one line each, naming the
    entry; empty when they are sound."""
    problems = []
    seen = set()
    for entry in curated:
        site_id = entry.get("id") or "(no id)"
        if not str(site_id).startswith("curated_"):
            problems.append(f"{site_id}: id must start with curated_")
        if site_id in seen:
            problems.append(f"{site_id}: duplicate id")
        seen.add(site_id)
        for field in ("name", "description", "country", "source"):
            if not entry.get(field):
                problems.append(f"{site_id}: missing {field}")
        country = entry.get("country")
        if country and country not in CURATED_COUNTRY_CODES:
            problems.append(f"{site_id}: no code for country {country!r}")
        latitude, longitude = entry.get("latitude"), entry.get("longitude")
        if not isinstance(latitude, (int, float)) or not -90 <= latitude <= 90:
            problems.append(f"{site_id}: latitude out of range")
        if not isinstance(longitude, (int, float)) or not (
            -180 <= longitude <= 180
        ):
            problems.append(f"{site_id}: longitude out of range")
        if entry.get("source") and not str(entry["source"]).startswith(
            "https://"
        ):
            problems.append(f"{site_id}: source must be an https link")
    return problems
