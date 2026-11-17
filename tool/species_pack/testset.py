#!/usr/bin/env python3
"""The rules that choose the accuracy test photos (the measured accuracy
design, docs/design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md).

fetch_testset.py does the network and model work; everything here is pure,
so it is tested in CI. Standard library only.
"""

import csv
import hashlib
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import region_grid  # noqa: E402

# BioCLIP 2's training data came from a GBIF download created 2024-05-01
# (10.15468/dl.bfv433). Two months' margin covers records created before it
# and indexed after.
CUTOFF = "2024-07-01"
LICENCES = ("cc0", "cc-by", "cc-by-sa")
# iNaturalist taxa: ray-finned fish, and sharks and rays.
TAXA = (47178, 47273)
PER_REGION = 450
SEED = "accuracy-2026-11"

# (south, west, north, east). Each takes in land too, and so freshwater
# fish, which the design keeps.
REGIONS = {
    "caribbean": (10.0, -88.0, 27.5, -59.0),
    "red-sea": (12.0, 32.0, 30.0, 44.0),
    "coral-triangle": (-10.0, 115.0, 19.0, 162.0),
    "hawaii": (18.5, -161.0, 22.5, -154.5),
    "great-barrier-reef": (-25.0, 142.0, -10.0, 156.0),
    "mediterranean": (30.0, -6.0, 46.0, 36.5),
    "california": (22.5, -125.0, 38.5, -109.0),
}

FIELDS = [
    "source",
    "id",
    "box",
    "photo_url",
    "licence",
    "attribution",
    "page_url",
    "region",
    "lat",
    "lon",
    "created",
    "observer",
    "label_name",
    "gbif_key",
    "label_source",
    "habitat",
    "recorded_before_cutoff",
    "underwater",
]

UNDERWATER_PROMPTS = [
    "an underwater photo of a fish",
    "a fish swimming over a coral reef",
    "a fish swimming in clear water, photographed by a diver",
    "a fish among rocks and seaweed underwater",
]
DRY_PROMPTS = [
    "a fish held in a person's hand",
    "a dead fish lying on a boat deck",
    "a fish on ice at a fish market",
    "a fish in an aquarium tank",
    "a caught fish hanging from a fishing line",
    "a drawing of a fish",
    "a fish lying on the ground or on a table",
]

_BELOW_SPECIES = {"species", "subspecies", "variety", "form"}
_GBIF_BELOW_SPECIES = {"SUBSPECIES", "VARIETY", "FORM", "INFRASPECIFIC_NAME"}


def species_name(name, rank):
    """The binomial an iNaturalist taxon counts as, or None above species
    rank (and for hybrids)."""
    if rank not in _BELOW_SPECIES:
        return None
    return " ".join(name.split()[:2])


def accepted_key(match):
    """The GBIF accepted species key from a `species/match` reply, or None
    when the name did not match at species rank or below."""
    if match.get("matchType") in (None, "NONE", "HIGHERRANK"):
        return None
    rank = match.get("rank")
    if rank == "SPECIES":
        if match.get("status") == "SYNONYM":
            return match.get("acceptedUsageKey")
        return match.get("usageKey")
    if rank in _GBIF_BELOW_SPECIES:
        return match.get("speciesKey")
    return None


def _hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sample(pool, n, seed):
    """`n` observations in an order fixed by `seed`, keeping only the first
    per observer per day, so one diver's afternoon cannot dominate."""
    seen = set()
    picked = []
    for o in sorted(pool, key=lambda o: _hash(seed + o["id"])):
        day = (o["observer"], o["observed_on"])
        if day in seen:
            continue
        seen.add(day)
        picked.append(o)
        if len(picked) == n:
            break
    return picked


def tune_ids(rows):
    """The ids in the tune half: within each region, the first half
    (rounded up) of the ids ordered by their hash. Rows sharing an id
    (boxes on one junk photo) stay together."""
    by_region = {}
    for r in rows:
        by_region.setdefault(r["region"], set()).add(r["id"])
    tune = set()
    for ids in by_region.values():
        ordered = sorted(ids, key=_hash)
        tune.update(ordered[: math.ceil(len(ordered) / 2)])
    return tune


_CC = re.compile(r"^cc[ -]by(?P<sa>[ -]sa)?(?: \d(?:\.\d)?)?(?: [a-z]+)?$")


def commons_licence(short_name):
    """A Wikimedia Commons licence name as one this set accepts, or None."""
    name = short_name.strip().lower()
    if name.startswith("cc0"):
        return "cc0"
    if "public domain" in name or name in ("pd", "pdm"):
        return "pd"
    m = _CC.match(name)
    if m:
        return "cc-by-sa" if m.group("sa") else "cc-by"
    return None


def query_boxes(cell, rings, cell_degrees):
    """`cell` and its neighbours as (south, west, north, east) boxes for a
    GBIF query: two when the block wraps round longitude 180."""
    n_rows = region_grid.rows(cell_degrees)
    n_cols = region_grid.columns(cell_degrees)
    row, col = divmod(cell, n_cols)
    south = max(0, row - rings) * cell_degrees - 90.0
    north = min(n_rows, row + rings + 1) * cell_degrees - 90.0
    if 2 * rings + 1 >= n_cols:
        return [(south, -180.0, north, 180.0)]
    west = (col - rings) * cell_degrees - 180.0
    east = (col + rings + 1) * cell_degrees - 180.0
    if west < -180:
        return [(south, west + 360, north, 180.0), (south, -180.0, north, east)]
    if east > 180:
        return [(south, west, north, 180.0), (south, -180.0, north, east - 360)]
    return [(south, west, north, east)]


def underwater(scores):
    """Whether a photo's zero-shot scores say it was taken underwater."""
    wet = sum(scores.get(p, 0.0) for p in UNDERWATER_PROMPTS)
    dry = sum(scores.get(p, 0.0) for p in DRY_PROMPTS)
    return wet >= dry


def write_rows(path, rows):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def read_rows(path):
    with open(path, encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))
