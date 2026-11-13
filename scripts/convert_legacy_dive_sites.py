#!/usr/bin/env python3
"""One-off conversion of assets/data/dive_sites.json into the site catalogue.

Usage:
    python scripts/convert_legacy_dive_sites.py

Reads the legacy bundled file and the curated entries, asks the geocoder for
each located site's country (about one request a second, cached in
scripts/.site_country_cache.json so a stopped run resumes), and writes
assets/data/site_catalogue.json with its version sidecar.

This script and its test are removed with the legacy file once the app
reads the catalogue; later catalogues come from dive_site_harvester.py.
"""

import json
import re
import sys
from pathlib import Path

from curated_sites import curated_record, load_curated
from site_catalogue_format import (
    osm_source_ref,
    to_catalogue_record,
    write_catalogue,
)
from site_country_resolver import CountryResolver

SCRIPT_DIR = Path(__file__).parent.resolve()
DATA_DIR = SCRIPT_DIR.parent / "assets" / "data"
LEGACY_FILE = DATA_DIR / "dive_sites.json"
CACHE_FILE = SCRIPT_DIR / ".site_country_cache.json"

# English names for the country codes carried by legacy records that have
# no coordinates to look up.
CODE_NAMES = {
    "BE": "Belgium",
    "CW": "Curaçao",
    "IT": "Italy",
    "NL": "Netherlands",
    "SK": "Slovakia",
    "US": "United States",
}

_TWO_LETTERS = re.compile(r"^[A-Za-z]{2}$")


def convert(legacy_doc: dict, curated: list[dict], lookup) -> list[dict]:
    """Catalogue records for the legacy document's sites, in its order.

    `lookup(latitude, longitude)` answers (ISO code, English name).
    """
    curated_by_id = {entry["id"]: entry for entry in curated}
    records = []
    for site in legacy_doc["sites"]:
        latitude, longitude = site.get("latitude"), site.get("longitude")
        code = name = None
        if latitude is not None and longitude is not None:
            code, name = lookup(latitude, longitude)
        elif _TWO_LETTERS.match(site.get("country") or ""):
            code = site["country"].upper()
            name = CODE_NAMES[code]

        if site["id"].startswith("curated_"):
            # KeyError on purpose: a curated site the curated file no
            # longer holds has lost its source.
            records.append(
                curated_record(
                    curated_by_id[site["id"]],
                    country_code=code,
                    country=name,
                )
            )
        else:
            records.append(
                to_catalogue_record(
                    site,
                    source="osm",
                    source_ref=osm_source_ref(site["id"]),
                    country_code=code,
                    country=name,
                )
            )
    return records


def main() -> int:
    legacy_doc = json.loads(LEGACY_FILE.read_text(encoding="utf-8"))
    resolver = CountryResolver(CACHE_FILE)
    total = len(legacy_doc["sites"])
    done = 0

    def lookup(latitude, longitude):
        nonlocal done
        done += 1
        if done % 100 == 0:
            print(f"{done} of {total} located sites", flush=True)
        return resolver.lookup(latitude, longitude)

    records = convert(legacy_doc, load_curated(), lookup)
    write_catalogue(
        DATA_DIR, records, legacy_doc["metadata"]["generated_at"]
    )
    print(f"Wrote {len(records)} sites to {DATA_DIR / 'site_catalogue.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
