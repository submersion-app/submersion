#!/usr/bin/env python3
"""Curated dive sites merged into the harvested site catalogue.

OpenStreetMap, the catalogue's source, has gaps: it holds no New Jersey ocean
sites at all. `dive_sites_curated.json` fills them with researched sites, and
`dive_site_harvester.py` merges it into every harvest so they survive.

Each curated entry carries the catalogue's fields plus `source` (where its
position came from), `depthM` and `kind`, which stay in the curated file for
review and never reach the app. Descriptions are our own words; positions
come from public sources.

A curated site steps aside once OpenStreetMap gains a site of the same name
nearby, so a harvest never lists one site twice.
"""

import json
import math
from pathlib import Path

CURATED_FILE = Path(__file__).parent / "dive_sites_curated.json"

# The fields a site carries in assets/data/dive_sites.json.
CATALOGUE_FIELDS = (
    "id",
    "name",
    "description",
    "latitude",
    "longitude",
    "country",
    "region",
    "website",
)

# A harvested site of the same name this close is the same site.
SAME_SITE_KM = 1.0


def load_curated(path: Path = CURATED_FILE) -> list[dict]:
    """The curated entries, as written in the curated file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _km(a: dict, b: dict) -> float:
    p1, p2 = math.radians(a["latitude"]), math.radians(b["latitude"])
    dp = p2 - p1
    dl = math.radians(b["longitude"] - a["longitude"])
    h = (
        math.sin(dp / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    )
    return 2 * 6371 * math.asin(math.sqrt(h))


def merge_curated(sites: list[dict], curated: list[dict]) -> list[dict]:
    """[sites] followed by each curated entry not already among them, reduced
    to the catalogue's fields.

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
            and s.get("latitude") is not None
            and s.get("longitude") is not None
            and _km(s, entry) <= SAME_SITE_KM
            for s in sites
        ):
            continue
        merged.append({field: entry.get(field) for field in CATALOGUE_FIELDS})
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
