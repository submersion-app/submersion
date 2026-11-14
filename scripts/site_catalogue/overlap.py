#!/usr/bin/env python3
"""One site listed by two sources ships once.

Two records are the same site when their folded names are equal and they
lie within 2 km (200 m for a name too common to match on from afar), or
when both are wrecks from different sources within 100 m of each other
whatever they are called.

The record that survives is the one from the source that is most about
diving, then the register that fixes positions best (`RANK`). It keeps its
own id, name and position, and takes a depth, a type, a description or a
hazard from the record it replaced only where its own is empty.

Two things never happen:

- A dive site id a diver may hold is merged away. OpenStreetMap dive sites
  are never merged with each other, nor curated sites with each other; a
  curated site steps aside for an OpenStreetMap dive site of the same name
  within 1 km, as it always has.
- A field passes between an own-terms record and any other. Where an
  own-terms record is the same site as another record, it is left out
  whole.
"""

import collections
import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

from records import fold_name, is_generic, km  # noqa: E402
from site_catalogue_format import OWN_TERMS_SOURCES  # noqa: E402

# Which record survives, first to last, as (source, kind).
RANK = [
    ("osm", "site"),
    ("curated", "site"),
    ("fknms", "site"),
    ("wikidata", "site"),
    ("fwc", "register"),
    ("noaa_reefs", "register"),
    ("ukho", "register"),
    ("awois", "register"),
    ("nms_ie", "register"),
    ("osm", "register"),
    ("wikidata", "register"),
] + [(source, "register") for source in OWN_TERMS_SOURCES]

SAME_NAME_KM = 2.0
GENERIC_NAME_KM = 0.2
SAME_WRECK_KM = 0.1
# A curated site steps aside for an OpenStreetMap dive site this close.
CURATED_KM = 1.0

# Sources whose records are dive site ids a diver may already hold.
_HELD = frozenset({("osm", "site"), ("curated", "site")})
# What a survivor may take from the record it replaced, where its own is
# empty.
_TAKEN = ("description", "hazards")

_CELL = 0.05


def _key(record: dict) -> tuple[str, str]:
    return record["source"], record["kind"]


def _own_terms(record: dict) -> bool:
    return record["source"] in OWN_TERMS_SOURCES


def same_site(a: dict, b: dict) -> bool:
    """Whether two records are one site."""
    if None in (a["lat"], a["lon"], b["lat"], b["lon"]):
        return False
    distance = km(a["lat"], a["lon"], b["lat"], b["lon"])

    if _key(a) in _HELD and _key(b) in _HELD:
        # Never among themselves: the one existing rule is a curated site
        # stepping aside for OpenStreetMap, on the name ignoring case.
        return (
            a["source"] != b["source"]
            and a["name"].casefold() == b["name"].casefold()
            and distance <= CURATED_KM
        )
    if a["source"] == b["source"] and _own_terms(a):
        return False

    name = fold_name(a["name"])
    if name and name == fold_name(b["name"]):
        limit = GENERIC_NAME_KM if is_generic(name) else SAME_NAME_KM
        if distance <= limit:
            return True

    return (
        a["source"] != b["source"]
        and "wreck" in a["types"]
        and "wreck" in b["types"]
        and "register" in (a["kind"], b["kind"])
        and distance <= SAME_WRECK_KM
    )


def _take(survivor: dict, loser: dict) -> None:
    """Fills the survivor's empty fields from the record it replaced."""
    if survivor["max_depth"] is None and loser["max_depth"] is not None:
        survivor["max_depth"] = loser["max_depth"]
    if (
        survivor["min_depth"] is None
        and loser["min_depth"] is not None
        and survivor["max_depth"] is not None
        and loser["min_depth"] < survivor["max_depth"]
    ):
        survivor["min_depth"] = loser["min_depth"]
    for type_id in loser["types"]:
        if type_id not in survivor["types"]:
            survivor["types"].append(type_id)
    for field in _TAKEN:
        if not survivor[field] and loser[field]:
            survivor[field] = loser[field]


def _cells(record: dict):
    """The grid cells a record's match could be filed under: its own and
    every neighbour within reach, wider in longitude towards the poles."""
    row = math.floor(record["lat"] / _CELL)
    column = math.floor(record["lon"] / _CELL)
    reach = int(
        math.ceil(1 / max(math.cos(math.radians(min(abs(record["lat"]) + 1, 89))), 0.02))
    )
    for d_row in (-1, 0, 1):
        for d_column in range(-reach, reach + 1):
            yield row + d_row, column + d_column


def resolve(records: list[dict]) -> tuple[list[dict], collections.Counter]:
    """The records that ship, and how many each source lost to which:
    a count per (loser source, winner source).

    The answer does not depend on the order of [records], and the input
    records are not changed.
    """
    rank = {key: index for index, key in enumerate(RANK)}
    for record in records:
        if _key(record) not in rank:
            raise ValueError(
                f"{record['id']}: no rank for source {record['source']!r} "
                f"as a {record['kind']} record"
            )
    ordered = sorted(records, key=lambda r: (rank[_key(r)], r["id"]))

    survivors: list[dict] = []
    grid: dict[tuple[int, int], list[dict]] = {}
    dropped: collections.Counter = collections.Counter()
    for record in ordered:
        match = None
        if record["lat"] is not None and record["lon"] is not None:
            for cell in _cells(record):
                for survivor in grid.get(cell, ()):
                    if same_site(survivor, record):
                        match = survivor
                        break
                if match is not None:
                    break
        if match is not None:
            dropped[(record["source"], match["source"])] += 1
            if not _own_terms(record) and not _own_terms(match):
                _take(match, record)
            continue
        kept = dict(record, types=list(record["types"]))
        survivors.append(kept)
        if kept["lat"] is not None and kept["lon"] is not None:
            grid.setdefault(
                (math.floor(kept["lat"] / _CELL), math.floor(kept["lon"] / _CELL)),
                [],
            ).append(kept)
    return survivors, dropped
