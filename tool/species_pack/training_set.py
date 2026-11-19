#!/usr/bin/env python3
"""Which iNaturalist photos the naming layer trains and validates on
(issue #4724; docs/design/specs/2026-11-18-marine-life-naming-layer-design.md).

- Licences: CC0, CC BY and CC BY-NC only. Share-alike licences would each
  demand their own licence on the trained file, and ND or all rights
  reserved photos may not be adapted.
- Leak guard: no test observation, and nothing a test set observer recorded
  on or after the cutoff, since every test photo dates from then.
- Validation: about a tenth of the observers with photos from after the
  cutoff, which BioCLIP 2 has not seen. Their later photos validate; none
  of theirs train.
- At most 50 photos a species and 5 an observer a species, later photos
  first.

Standard library only, so its test runs without the model tooling.
"""

import csv
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from testset import CUTOFF  # noqa: E402

LICENCES = ("cc0", "cc-by", "cc-by-nc")
PER_SPECIES = 50
PER_OBSERVER = 5
VALIDATION_FRACTION = 0.10
SEED = "naming-layer-2026-11"
# Test species whose training photos the rare-species check leaves out.
HELD_BACK = 100
CREDIT_FIELDS = ["id", "uri", "licence", "attribution"]



def _hash(text):
    return int(hashlib.sha256((SEED + text).encode("utf-8")).hexdigest(), 16)


def _after_cutoff(r):
    return r["created"][:10] >= CUTOFF


def observation_record(o, candidate, gbif_key):
    """An iNaturalist v2 observation as a training record for the candidate
    at index `candidate`, or None when its first photo is missing, has no
    URL, or is not under a training licence. A hidden place is kept as
    None."""
    photos = o.get("photos") or []
    if not photos or photos[0].get("license_code") not in LICENCES or not photos[0].get("url"):
        return None
    photo = photos[0]
    lat = lon = None
    if o.get("location") and not o.get("obscured"):
        lat, lon = (float(v) for v in o["location"].split(","))
    return {
        "id": str(o["id"]),
        "uri": o.get("uri") or f"https://www.inaturalist.org/observations/{o['id']}",
        "created": o.get("created_at") or "",
        "observer": (o.get("user") or {}).get("login") or "",
        "candidate": candidate,
        "gbif_key": gbif_key,
        "lat": lat,
        "lon": lon,
        "photo_url": re.sub(r"/square\.", "/large.", photo["url"]),
        "licence": photo["license_code"],
        "attribution": photo.get("attribution") or "",
    }


def guard(records, test_ids, test_observers):
    """`records` less every test observation and every observation a test
    set observer created on or after the cutoff."""
    return [
        r
        for r in records
        if r["id"] not in test_ids and not (r["observer"] in test_observers and _after_cutoff(r))
    ]


def validation_observers(records):
    """About VALIDATION_FRACTION of the observers with a record from after
    the cutoff, the same for the same records in any order."""
    later = {r["observer"] for r in records if _after_cutoff(r)}
    limit = round(VALIDATION_FRACTION * 1000)
    return {o for o in later if _hash(o) % 1000 < limit}


def split(records, val_observers):
    """(training, validation): validation observers' later records
    validate, and none of their records train."""
    train = [r for r in records if r["observer"] not in val_observers]
    validation = [r for r in records if r["observer"] in val_observers and _after_cutoff(r)]
    return train, validation


def cap(records):
    """At most PER_SPECIES records a species and PER_OBSERVER an observer a
    species, preferring records from after the cutoff, then the newest."""
    # Stable sorts, last key first: later records, then newest, then id.
    ordered = sorted(records, key=lambda r: r["id"])
    ordered = sorted(ordered, key=lambda r: r["created"], reverse=True)
    ordered = sorted(ordered, key=lambda r: not _after_cutoff(r))
    per_species, per_observer, kept = {}, {}, []
    for r in ordered:
        key = r["gbif_key"]
        pair = (key, r["observer"])
        if per_species.get(key, 0) >= PER_SPECIES or per_observer.get(pair, 0) >= PER_OBSERVER:
            continue
        per_species[key] = per_species.get(key, 0) + 1
        per_observer[pair] = per_observer.get(pair, 0) + 1
        kept.append(r)
    return kept


def held_back_species(test_rows):
    """HELD_BACK gbif keys of species in the test set's underwater
    iNaturalist photos, the same for the same rows in any order."""
    keys = {
        int(r["gbif_key"])
        for r in test_rows
        if r["source"] == "inaturalist" and r["underwater"] == "yes" and r["gbif_key"]
    }
    return sorted(sorted(keys), key=lambda k: _hash(str(k)))[:HELD_BACK]


def without_species(records, keys):
    """`records` less those of any species in `keys`."""
    return [r for r in records if r["gbif_key"] not in keys]


def write_credits(path, records):
    """One row per training photo with its credit, by observation id."""
    with open(path + ".partial", "w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=CREDIT_FIELDS)
        writer.writeheader()
        for r in sorted(records, key=lambda r: int(r["id"])):
            writer.writerow({k: r[k] for k in CREDIT_FIELDS})
    os.replace(path + ".partial", path)
