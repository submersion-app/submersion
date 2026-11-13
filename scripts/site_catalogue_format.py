#!/usr/bin/env python3
"""The format of the built-in site catalogue (assets/data/site_catalogue.json).

One record per site, with where it came from and how far it is trusted. The
app loads the file into its local cache whenever the version sidecar
(site_catalogue.version) changes, so every script that writes the file goes
through `write_catalogue`.

Source values are mapped here to names the app already knows, so the app
never has to guess what "stair" or "speleology" means.
"""

import hashlib
import json
import re
from pathlib import Path

FORMAT = 2

CATALOGUE_FILE = "site_catalogue.json"
VERSION_FILE = "site_catalogue.version"

_OSM_COPYRIGHT = "https://www.openstreetmap.org/copyright"

# Where records come from, keyed by a record's `source`.
SOURCES = {
    "osm": {
        "name": "OpenStreetMap",
        "licence": "ODbL-1.0",
        "licence_url": _OSM_COPYRIGHT,
        "credit": "OpenStreetMap contributors",
    },
    "curated": {
        "name": "Submersion",
        "licence": "ODbL-1.0",
        "licence_url": _OSM_COPYRIGHT,
        "credit": "Submersion contributors",
    },
}

NOTICE = (
    "Contains information from OpenStreetMap, which is made available under "
    "the Open Database License (ODbL). " + _OSM_COPYRIGHT
)

TRUST_LEVELS = ("verified", "researched")

# The ids of the app's built-in site types
# (lib/core/database/site_type_seed.dart, kBuiltInSiteTypes).
SITE_TYPE_IDS = (
    "reef",
    "wall",
    "wreck",
    "artificial_reef",
    "cave",
    "cavern",
    "cenote",
    "blue_hole",
    "lake",
    "quarry",
    "river",
    "spring",
    "pool",
    "pier",
    "muck",
    "kelp_forest",
)

# The names of the app's EntryMethod values
# (lib/core/constants/app_enums.dart).
ENTRY_METHODS = (
    "shore",
    "boat",
    "backRoll",
    "frontRoll",
    "giantStride",
    "seatedEntry",
    "ladder",
    "platform",
    "jetty",
    "other",
)

# A source's word for a kind of site, where it differs from the app's id.
_TYPE_ALIASES = {"speleology": "cave"}

# A source's word for an entry, as the app's EntryMethod name. Anything not
# listed (OpenStreetMap also has "stone" and a bare "yes") says too little.
_ENTRY_ALIASES = {
    "boat": "boat",
    "shore": "shore",
    "stair": "ladder",
    "steps": "ladder",
    "ladder": "ladder",
    "pier": "jetty",
}

_ENTRY_SPLIT = re.compile(r"[:;,/]|\bor\b")
_OSM_ID = re.compile(r"^osm_(node|way|relation)_(\d+)$")

# Optional text fields that keep their legacy name.
_PLACE_FIELDS = ("region", "locality", "island", "body_of_water", "water_type")


def map_entry(raw: str | None) -> list[str]:
    """The app's entry methods for a source's entry value, without repeats."""
    if not raw:
        return []
    methods: list[str] = []
    for token in _ENTRY_SPLIT.split(raw.lower()):
        method = _ENTRY_ALIASES.get(token.strip())
        if method and method not in methods:
            methods.append(method)
    return methods


def split_features(features: list[str] | None) -> tuple[list[str], list[str]]:
    """A source's feature list as (site type ids, everything else).

    The rest (drift, sharks, training...) describes the diving, not the
    place; it stays in the record for later use.
    """
    types: list[str] = []
    rest: list[str] = []
    for feature in features or []:
        type_id = _TYPE_ALIASES.get(feature, feature)
        if type_id in SITE_TYPE_IDS:
            if type_id not in types:
                types.append(type_id)
        elif feature not in rest:
            rest.append(feature)
    return types, rest


def normalise_depths(
    depth: float | None, max_depth: float | None
) -> tuple[float | None, float | None]:
    """(min_depth_m, max_depth_m) from a source's depth and maximum depth.

    OpenStreetMap's `scuba_diving:depth` is the site's depth, not its
    shallowest point, so a depth with no maximum is the maximum.
    """
    if depth is None:
        return None, max_depth
    if max_depth is None or depth == max_depth:
        return None, depth
    if depth > max_depth:
        return max_depth, depth
    return depth, max_depth


def osm_source_ref(site_id: str) -> str | None:
    """The OpenStreetMap object behind an `osm_<type>_<id>` site id."""
    match = _OSM_ID.match(site_id)
    if not match:
        return None
    return f"https://www.openstreetmap.org/{match.group(1)}/{match.group(2)}"


def to_catalogue_record(
    legacy: dict,
    *,
    source: str,
    source_ref: str | None,
    country_code: str | None,
    country: str | None,
) -> dict:
    """A catalogue record from a site in the harvester's working shape.

    Empty values are left out, never written as null. The key order here is
    the file's key order.
    """
    min_depth, max_depth = normalise_depths(
        legacy.get("min_depth"), legacy.get("max_depth")
    )
    types, features = split_features(legacy.get("features"))

    record: dict = {"id": legacy["id"], "name": legacy["name"]}

    def put(key: str, value) -> None:
        if value not in (None, "", []):
            record[key] = value

    if legacy.get("latitude") is not None and legacy.get("longitude") is not None:
        record["lat"] = legacy["latitude"]
        record["lon"] = legacy["longitude"]
    put("country_code", country_code)
    put("country", country)
    for field in _PLACE_FIELDS:
        put(field, legacy.get(field))
    put("min_depth_m", min_depth)
    put("max_depth_m", max_depth)
    put("types", types)
    put("entry", map_entry(legacy.get("entry_type")))
    put("features", features)
    put("difficulty", legacy.get("difficulty"))
    put("hazards", legacy.get("hazards"))
    put("description", legacy.get("description"))
    put("website", legacy.get("website"))
    record["source"] = source
    put("source_ref", source_ref)
    record["trust"] = "verified"
    return record


def validate_catalogue(doc: dict) -> list[str]:
    """Everything wrong with a catalogue document, one line per problem."""
    problems: list[str] = []
    metadata = doc.get("metadata") or {}
    if metadata.get("format") != FORMAT:
        problems.append(f"metadata: format must be {FORMAT}")
    sources = metadata.get("sources") or {}

    seen: set[str] = set()
    for record in doc.get("sites") or []:
        site_id = record.get("id") or "(no id)"
        if site_id in seen:
            problems.append(f"{site_id}: duplicate id")
        seen.add(site_id)
        if not record.get("name"):
            problems.append(f"{site_id}: no name")
        if record.get("source") not in sources:
            problems.append(
                f"{site_id}: undeclared source {record.get('source')!r}"
            )
        if record.get("trust") not in TRUST_LEVELS:
            problems.append(f"{site_id}: trust {record.get('trust')!r}")
        if ("lat" in record) != ("lon" in record):
            problems.append(f"{site_id}: lat and lon must come together")
        for type_id in record.get("types") or []:
            if type_id not in SITE_TYPE_IDS:
                problems.append(f"{site_id}: unknown type {type_id!r}")
        for method in record.get("entry") or []:
            if method not in ENTRY_METHODS:
                problems.append(f"{site_id}: unknown entry {method!r}")
        min_depth = record.get("min_depth_m")
        max_depth = record.get("max_depth_m")
        if min_depth is not None and max_depth is not None and min_depth > max_depth:
            problems.append(f"{site_id}: min_depth_m above max_depth_m")
    return problems


def catalogue_version(data: bytes) -> str:
    """The version of a catalogue file: the SHA-256 of its bytes."""
    return hashlib.sha256(data).hexdigest()


def write_catalogue(
    directory: Path, records: list[dict], generated_at: str
) -> None:
    """Writes the catalogue and its version sidecar into [directory].

    Raises ValueError, and writes nothing, when the records do not validate.
    """
    doc = {
        "metadata": {
            "format": FORMAT,
            "generated_at": generated_at,
            "notice": NOTICE,
            "total_count": len(records),
            "sources": SOURCES,
        },
        "sites": records,
    }
    problems = validate_catalogue(doc)
    if problems:
        raise ValueError(
            "The site catalogue does not validate:\n" + "\n".join(problems)
        )

    data = json.dumps(doc, indent=2, ensure_ascii=False).encode("utf-8")
    (directory / CATALOGUE_FILE).write_bytes(data)
    (directory / VERSION_FILE).write_text(
        catalogue_version(data), encoding="utf-8"
    )
