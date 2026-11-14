#!/usr/bin/env python3
"""Curated dive sites merged into the built-in site catalogue.

The catalogue's sources have gaps. `dive_sites_curated.json` fills them with
researched sites, and `scripts/site_catalogue/merge.py` reads it on every run
so they survive.

Each curated entry carries a site's name, description and position plus
`source` (where its position came from), `depthM` and `kind`. All of them
reach the catalogue: the source as the record's `source_ref`, the depth as
its maximum depth, and the kind as a site type (wreck, wall, reef) or an
entry (shore). Descriptions are our own words; positions come from public
sources.

A curated site steps aside once OpenStreetMap gains a dive site of the same
name within a kilometre, so the catalogue never lists one site twice
(`scripts/site_catalogue/overlap.py`).
"""

import json
from pathlib import Path

CURATED_FILE = Path(__file__).parent / "dive_sites_curated.json"

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
