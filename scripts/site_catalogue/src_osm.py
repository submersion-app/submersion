#!/usr/bin/env python3
"""OpenStreetMap: dive sites and wrecks. ODbL 1.0.

Dive sites are the objects tagged `sport=scuba_diving`, less the shops,
clubs, schools and hotels that carry the same tag. They are dive site
records, and their ids are the ones the catalogue has always used, so a
site a diver adopted keeps its link.

Wrecks are the named objects tagged as a wreck and not as a dive site.
They are register records, and only wrecks that stay under water and may
be visited pass.

A dive site's country comes from the geocoder, asked here, at fetch time,
so the merge needs no network.

Run this file to download both into the snapshot cache.
"""

import collections
import json
import os
import re
import sys
import time
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import records as rec  # noqa: E402
from site_catalogue_format import (  # noqa: E402
    normalise_depths,
    split_features,
)
from snapshots import http_get, write_snapshot  # noqa: E402

KEY_SITES = "osm_sites"
KEY_WRECKS = "osm_wrecks"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"
SITES_QUERY = (
    '[out:json][timeout:600];nwr["sport"="scuba_diving"];out center tags;'
)
WRECKS_QUERY = (
    "[out:json][timeout:600];("
    'nwr["name"]["historic"="wreck"];'
    'nwr["name"]["seamark:type"="wreck"];'
    'nwr["name"]["wreck:type"];'
    ");out center tags;"
)

MAX_DEPTH_M = 60.0

_BUSINESS_KEYS = ("shop", "club", "office")
_BUSINESS_SERVICES = (
    "scuba_diving:courses", "scuba_diving:rental", "scuba_diving:filling",
    "scuba_diving:repair",
)
_BUSINESS_TOURISM = frozenset({"hotel", "guest_house", "hostel", "resort"})
# Not `pitch`: that is how OpenStreetMap tags the place a sport is
# practised, and real dive spots carry it. Not `swimming_pool`: a pool
# tagged for scuba is a training site.
_BUSINESS_LEISURE = frozenset({"sports_centre", "fitness_centre", "resort"})
# A name that reads as a dive centre, shop, club or school, in the
# languages OpenStreetMap's dive businesses are mostly named in.
_BUSINESS_NAME = re.compile(
    r"\b(dive|diving|scuba|divers?)\s*(center|centre|shop|club|school|resort"
    r"|college|academy)\b"
    r"|\btauch(schule|basis|club|verein|shop|center|sport|zentrum)"
    r"|\bclub\s+de\s+plong"
    r"|\b(centre|[ée]cole)\s+de\s+plong"
    r"|\bcentro\s+de\s+buceo\b|\bduik(school|centrum|winkel)",
    re.IGNORECASE,
)

_FRESH_WATER = frozenset(
    {"lake", "pond", "reservoir", "quarry", "river", "basin", "oxbow"}
)
_VISIBLE_CATEGORIES = frozenset({"hull_showing", "hull_visible", "mast_showing"})
_NOT_SHIPS = frozenset({"car", "jeep", "van"})
_WRECK_DEPTH_KEYS = ("wreck:depth", "depth", "seamark:wreck:depth")
_DEPTH = re.compile(r"([\d.]+)\s*(m|meters?|metres?|ft|feet)?")
_YES = ("yes", "true", "1")


def is_business(tags: dict, name: str) -> bool:
    """Whether a scuba-tagged object serves divers and is not a place to
    dive. An object marked `scuba_diving:divespot=yes` is a site whatever
    else it carries."""
    if tags.get("scuba_diving:divespot") == "yes":
        return False
    if tags.get("amenity") == "dive_centre":
        return True
    if any(key in tags for key in _BUSINESS_KEYS):
        return True
    if any(tags.get(key) in _YES for key in _BUSINESS_SERVICES):
        return True
    if tags.get("tourism") in _BUSINESS_TOURISM:
        return True
    if tags.get("leisure") in _BUSINESS_LEISURE:
        return True
    return _BUSINESS_NAME.search(name or "") is not None


def parse_depth(text) -> float | None:
    """A tagged depth ("30m", "100 ft", "25") in metres."""
    match = _DEPTH.match(str(text or "").strip().lower())
    if not match:
        return None
    try:
        value = float(match.group(1))
    except ValueError:
        return None
    if match.group(2) in ("ft", "feet"):
        value = rec.feet(value)
    return round(value, 1)


def _position(element: dict) -> tuple[float | None, float | None]:
    centre = element.get("center") or {}
    lat = element.get("lat", centre.get("lat"))
    lon = element.get("lon", centre.get("lon"))
    return (lat, lon) if lat is not None and lon is not None else (None, None)


def _ref(element: dict) -> str:
    return f"https://www.openstreetmap.org/{element['type']}/{element['id']}"


def _site_types(tags: dict) -> tuple[list[str], list[str], str | None]:
    """(site type ids, other features, water type) an object's tags state."""
    types: list[str] = []
    if tags.get("historic") == "wreck" or tags.get("seamark:type") == "wreck":
        types.append("wreck")
    natural = tags.get("natural")
    if natural == "reef":
        types.append("reef")
    if natural == "cave_entrance":
        types.append("cave")
    if natural == "spring":
        types.append("spring")
    water = tags.get("water")
    if water == "lake":
        types.append("lake")
    if water == "quarry" or tags.get("landuse") == "quarry":
        types.append("quarry")
    pool = tags.get("leisure") == "swimming_pool"
    if pool:
        types.append("pool")
    fresh = (
        pool
        or water in _FRESH_WATER
        or natural == "spring"
        or tags.get("landuse") == "quarry"
        or tags.get("salt") == "no"
    )

    tagged = [
        key.rsplit(":", 1)[-1]
        for key, value in tags.items()
        if key.startswith("scuba_diving:type:") and value in _YES
    ]
    tagged += [
        part.strip()
        for part in re.split(r"[;,]", tags.get("scuba_diving:type") or "")
        if part.strip()
    ]
    if tags.get("scuba_diving:drift") in _YES:
        tagged.append("drift")
    scuba_types, features = split_features(tagged)
    for type_id in scuba_types:
        if type_id not in types:
            types.append(type_id)
    return types, features, "fresh" if fresh else None


def site_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """The scuba-tagged objects that are dive sites, as dive site records."""
    kept, dropped = [], collections.Counter()
    for element in rows:
        tags = element.get("tags") or {}
        # The description stood in for a missing name before this slice;
        # it still does, so no id a diver may hold is lost.
        name = tags.get("name") or tags.get("name:en") or tags.get("description")
        if not name or not name.strip():
            dropped["no_name"] += 1
            continue
        if is_business(tags, name):
            dropped["business"] += 1
            continue
        lat, lon = _position(element)
        min_depth, max_depth = normalise_depths(
            parse_depth(tags.get("scuba_diving:depth")),
            parse_depth(tags.get("scuba_diving:maxdepth")),
        )
        types, features, water = _site_types(tags)
        description = "\n\n".join(
            part for part in (tags.get("description"), tags.get("note")) if part
        )
        kept.append(
            rec.working(
                id=f"osm_{element['type']}_{element['id']}",
                name=name,
                lat=lat,
                lon=lon,
                source="osm",
                kind="site",
                source_ref=_ref(element),
                types=types,
                max_depth=max_depth,
                min_depth=min_depth,
                description=description or None,
                hazards=tags.get("scuba_diving:hazard"),
                website=tags.get("website") or tags.get("contact:website"),
                entry_type=tags.get("scuba_diving:entry"),
                features=features,
                water_type=water,
                geocoded=element.get("geocoded"),
            )
        )
    return kept, dropped


def wreck_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """The named wrecks that stay under water and may be visited, as
    register records."""
    kept, dropped = [], collections.Counter()
    for element in rows:
        tags = element.get("tags") or {}
        name = (tags.get("name") or "").strip()
        if rec.is_placeholder(name):
            dropped["no_name"] += 1
            continue
        if tags.get("sport") == "scuba_diving":
            # Harvested as a dive site, under the same id.
            dropped["scuba_tagged"] += 1
            continue
        lat, lon = _position(element)
        if lat is None:
            dropped["no_position"] += 1
            continue
        if (
            tags.get("wreck:visible_at_high_tide") == "yes"
            or tags.get("wreck:visible_at_low_tide") == "yes"
            or tags.get("seamark:wreck:category") in _VISIBLE_CATEGORIES
        ):
            dropped["visible"] += 1
            continue
        if tags.get("access") in ("no", "private"):
            dropped["no_access"] += 1
            continue
        if tags.get("wreck:type") in _NOT_SHIPS:
            dropped["not_a_ship"] += 1
            continue
        depth = next(
            (
                parsed
                for parsed in (parse_depth(tags.get(key)) for key in _WRECK_DEPTH_KEYS)
                if parsed
            ),
            None,
        )
        if depth is not None and depth > MAX_DEPTH_M:
            dropped["too_deep"] += 1
            continue
        kept.append(
            rec.working(
                id=f"osm_{element['type']}_{element['id']}",
                name=name,
                lat=lat,
                lon=lon,
                source="osm",
                kind="register",
                source_ref=_ref(element),
                types=["wreck"],
                max_depth=depth,
                website=tags.get("website"),
            )
        )
    return kept, dropped


def _overpass(query: str) -> list[dict]:
    """The elements Overpass answers [query] with. A busy server is asked
    once more after a minute, then the fetch stops."""
    try:
        body = http_get(OVERPASS_URL, params={"data": query}, timeout=900)
    except RuntimeError as error:
        if not any(code in str(error) for code in ("429", "502", "504")):
            raise
        time.sleep(60)
        body = http_get(OVERPASS_URL, params={"data": query}, timeout=900)
    doc = json.loads(body)
    if doc.get("remark"):
        raise RuntimeError(f"Overpass cut the answer short: {doc['remark']}")
    return doc.get("elements") or []


def fetch_sites(resolver=None):
    """Downloads the scuba-tagged objects and asks the geocoder where each
    dive site is. The geocoder's answers are cached, so a rerun asks only
    about sites it has not seen."""
    if resolver is None:
        from site_country_resolver import CountryResolver

        resolver = CountryResolver(
            Path(_HERE).parent / ".site_country_cache.json"
        )
    elements = _overpass(SITES_QUERY)
    for element in elements:
        tags = element.get("tags") or {}
        name = tags.get("name") or tags.get("name:en") or tags.get("description")
        lat, lon = _position(element)
        if not name or lat is None or is_business(tags, name):
            continue
        element["geocoded"] = list(resolver.lookup_place(lat, lon))
    return write_snapshot(KEY_SITES, OVERPASS_URL, elements)


def fetch_wrecks():
    return write_snapshot(KEY_WRECKS, OVERPASS_URL, _overpass(WRECKS_QUERY))


if __name__ == "__main__":
    print(fetch_wrecks())
    time.sleep(10)
    print(fetch_sites())
