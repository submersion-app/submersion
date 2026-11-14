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
_ODBL = "https://opendatacommons.org/licenses/odbl/1-0/"

_UKHO_STATEMENT = (
    "Contains public sector information, licensed under the Open Government "
    "Licence v3.0, from the UK Hydrographic Office."
)
_NJDEP_STATEMENT = (
    "This application was developed using New Jersey Department of "
    "Environmental Protection Geographic Information System digital data, "
    "but this secondary product has not been verified by NJDEP and is not "
    "state-authorized or endorsed."
)

# Where records come from, keyed by a record's `source`. `credit` is the
# short form a linked site's page shows. A source with `own_terms` allows
# reuse only on terms that cannot be passed on under the ODbL: its records
# ride beside the ODbL database, never blended into it (see the slice 2
# design, docs/design/specs/2026-11-14-site-catalogue-register-expansion-
# design.md).
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
        "licence_url": _ODBL,
        "credit": "Submersion contributors",
    },
    "ukho": {
        "name": "UK Hydrographic Office Wrecks and Obstructions",
        "licence": "OGL-UK-3.0",
        "licence_url": (
            "https://www.nationalarchives.gov.uk/doc/"
            "open-government-licence/version/3/"
        ),
        "credit": "UK Hydrographic Office",
    },
    "awois": {
        "name": "NOAA Automated Wreck and Obstruction Information System",
        "licence": "CC0-1.0",
        "licence_url": "https://nauticalcharts.noaa.gov/data/data-licensing.html",
        "credit": "NOAA Office of Coast Survey",
    },
    "fwc": {
        "name": "Artificial Reefs in Florida",
        "licence": "Public domain",
        "licence_url": (
            "https://www.arcgis.com/home/item.html"
            "?id=eb2bfd225149405bba23604f20159f56"
        ),
        "credit": "Florida Fish and Wildlife Conservation Commission, FWRI",
    },
    "noaa_reefs": {
        "name": "MarineCadastre Artificial Reefs",
        "licence": "Public domain",
        "licence_url": "https://www.fisheries.noaa.gov/inport/item/54191",
        "credit": "NOAA Office for Coastal Management and BOEM",
    },
    "fknms": {
        "name": "Florida Keys National Marine Sanctuary buoys",
        "licence": "US Government work",
        "licence_url": "https://floridakeys.noaa.gov/mbuoy/allmbuoys.html",
        "credit": "NOAA Florida Keys National Marine Sanctuary",
    },
    "nms_ie": {
        "name": "Wreck Inventory of Ireland Database",
        "licence": "CC-BY-4.0",
        "licence_url": "https://creativecommons.org/licenses/by/4.0/",
        "credit": "National Monuments Service, Government of Ireland",
    },
    "wikidata": {
        "name": "Wikidata",
        "licence": "CC0-1.0",
        "licence_url": "https://www.wikidata.org/wiki/Wikidata:Copyright",
        "credit": "Wikidata",
    },
    "njdep": {
        "name": "Artificial Reef Deployments in New Jersey",
        "licence": "NJDEP Data Distribution Agreement",
        "licence_url": (
            "https://www.arcgis.com/home/item.html"
            "?id=862307fcb54b4f70a6bdb9915d4c149f"
        ),
        "credit": "New Jersey Department of Environmental Protection",
        "own_terms": (
            "Redistributed with NJDEP's metadata and its credit and "
            "disclaimer, as its Data Distribution Agreement requires."
        ),
    },
    "hi_dar": {
        "name": "Hawaii artificial reefs",
        "licence": "Non-commercial use",
        "licence_url": "https://portal.ehawaii.gov/page/terms-of-use/",
        "credit": "Hawaii DLNR Division of Aquatic Resources",
        "own_terms": (
            "Copyright State of Hawaii. Not to be used for commercial "
            "purposes."
        ),
    },
    "tpwd": {
        "name": "Texas artificial reefs",
        "licence": "Non-commercial use, with credit",
        "licence_url": "https://tpwd.texas.gov/site/policies/copyright-policy",
        "credit": "Texas Parks and Wildlife Department",
        "own_terms": (
            "Copyright Texas Parks and Wildlife Department. Non-commercial "
            "use with credit; not to be sold."
        ),
    },
    "nc_dmf": {
        "name": "North Carolina Artificial Reef Guide",
        "licence": "Non-commercial use, unaltered, with citation",
        "licence_url": "https://www.nc.gov/disclaimer-terms-use",
        "credit": "N.C. Division of Marine Fisheries",
        "own_terms": (
            "Reproduced without alteration for non-commercial use, citing "
            "the N.C. Division of Marine Fisheries."
        ),
    },
}

# The sources whose records are not offered under the ODbL.
OWN_TERMS_SOURCES = tuple(
    key for key, source in SOURCES.items() if "own_terms" in source
)

KINDS = ("site", "register")


def catalogue_sources(*, open_only: bool = False) -> dict:
    """The sources a catalogue file declares; without the own-terms ones
    for the ODbL database alone."""
    return {
        key: source
        for key, source in SOURCES.items()
        if not (open_only and key in OWN_TERMS_SOURCES)
    }


def catalogue_notice(*, open_only: bool = False) -> str:
    """The notice a catalogue file carries.

    Every source is named with its licence. The ODbL covers the database
    the open sources were merged into; an own-terms source's records are
    carried beside it under their publisher's terms, and the notice says
    which those are.
    """
    sources = catalogue_sources(open_only=open_only)
    open_lines = [
        f"{source['name']} ({source['licence']}, {source['licence_url']})"
        for key, source in sources.items()
        if key not in OWN_TERMS_SOURCES
    ]
    parts = [
        "Contains information from OpenStreetMap, which is made available "
        "under the Open Database License (ODbL). " + _OSM_COPYRIGHT,
        "This database is made available under the Open Database License "
        "(ODbL) 1.0, " + _ODBL + " . It was compiled from: "
        + "; ".join(open_lines) + ".",
        _UKHO_STATEMENT,
        "Florida records were produced by the Florida Fish and Wildlife "
        "Conservation Commission, Fish and Wildlife Research Institute "
        "(FWC-FWRI).",
    ]
    if not open_only:
        own_lines = [
            f"{SOURCES[key]['name']} ({SOURCES[key]['licence']}, "
            f"{SOURCES[key]['licence_url']}): {SOURCES[key]['own_terms']}"
            for key in OWN_TERMS_SOURCES
        ]
        parts += [
            "The records of the following sources are not part of that "
            "database and are not licensed under the ODbL. They remain "
            "under their publishers' own terms: " + " ".join(own_lines),
            _NJDEP_STATEMENT,
            "Records from Hawaii, North Carolina and Texas may not be used "
            "commercially. North Carolina's records are reproduced without "
            "alteration from the Division of Marine Fisheries' reef guide.",
        ]
    parts.append(
        "Positions and depths are as their sources published them. This "
        "data is not for navigation."
    )
    return " ".join(parts)


NOTICE = catalogue_notice()

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
_HAS_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.\-]*:")
_BARE_HOST = re.compile(r"^[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+(/\S*)?$")
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


def normalise_website(raw: str | None) -> str | None:
    """A site's website as an http(s) address, or None.

    The value comes from a source anyone can edit, and the app opens it
    from a button labelled "Website": anything that is not a web address
    (tel:, mailto:, an app's own scheme) is dropped. A bare host, which
    sources often carry, gets https.
    """
    text = (raw or "").strip()
    if not text:
        return None
    if text.lower().startswith(("http://", "https://")):
        return text
    if _HAS_SCHEME.match(text):
        return None
    if _BARE_HOST.match(text):
        return "https://" + text
    return None


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
    kind: str = "site",
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
    put("website", normalise_website(legacy.get("website")))
    if kind == "register":
        # A dive site record carries no kind: it is what a record is
        # unless it says otherwise.
        record["kind"] = kind
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
    for key in OWN_TERMS_SOURCES:
        if key in sources and not (sources[key].get("own_terms") or "").strip():
            problems.append(f"metadata: source {key} must state its own_terms")

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
        kind = record.get("kind", "site")
        if kind not in KINDS:
            problems.append(f"{site_id}: kind {kind!r}")
        elif kind == "register" and "lat" not in record:
            problems.append(f"{site_id}: a register record needs lat and lon")
        for type_id in record.get("types") or []:
            if type_id not in SITE_TYPE_IDS:
                problems.append(f"{site_id}: unknown type {type_id!r}")
        for method in record.get("entry") or []:
            if method not in ENTRY_METHODS:
                problems.append(f"{site_id}: unknown entry {method!r}")
        website = record.get("website")
        if website is not None and normalise_website(website) != website:
            problems.append(f"{site_id}: website is not an http(s) address")
        min_depth = record.get("min_depth_m")
        max_depth = record.get("max_depth_m")
        if min_depth is not None and max_depth is not None and min_depth > max_depth:
            problems.append(f"{site_id}: min_depth_m above max_depth_m")
    return problems


def catalogue_version(data: bytes) -> str:
    """The version of a catalogue file: the SHA-256 of its bytes."""
    return hashlib.sha256(data).hexdigest()


def _compact(value) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def write_catalogue(
    directory: Path,
    records: list[dict],
    generated_at: str,
    *,
    open_only: bool = False,
) -> None:
    """Writes the catalogue and its version sidecar into [directory].

    The file is the metadata on one line, then one record per line in id
    order, so a refresh shows in a diff as the records that changed.

    With [open_only], the records of own-terms sources are left out: the
    ODbL database alone.

    Raises ValueError, and writes nothing, when the records do not validate.
    """
    if open_only:
        records = [
            record
            for record in records
            if record.get("source") not in OWN_TERMS_SOURCES
        ]
    records = sorted(records, key=lambda record: record.get("id") or "")
    doc = {
        "metadata": {
            "format": FORMAT,
            "generated_at": generated_at,
            "notice": catalogue_notice(open_only=open_only),
            "total_count": len(records),
            "sources": catalogue_sources(open_only=open_only),
        },
        "sites": records,
    }
    problems = validate_catalogue(doc)
    if problems:
        raise ValueError(
            "The site catalogue does not validate:\n" + "\n".join(problems)
        )

    text = (
        '{"metadata":'
        + _compact(doc["metadata"])
        + ',"sites":[\n'
        + ",\n".join(_compact(record) for record in records)
        + "\n]}\n"
    )
    data = text.encode("utf-8")
    (directory / CATALOGUE_FILE).write_bytes(data)
    (directory / VERSION_FILE).write_text(
        catalogue_version(data), encoding="utf-8"
    )
