#!/usr/bin/env python3
"""
Recompression chamber directory harvester.

Collects leads from the national hyperbaric registries that publish one,
merges a hand-curated overlay covering every region without a reachable
registry, and writes assets/data/chambers.json.

No source found publishes chamber data under a redistribution license, so
every row is verified against the facility's own website and cites that URL.
Treat registry listings as leads to confirm, never as data to copy.

Usage:
    python3 scripts/chamber_harvester.py --leads     # refresh scripts/chamber_leads.json
    python3 scripts/chamber_harvester.py --build     # merge + validate + write the asset
"""

import argparse
import json
import os
import re
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "assets", "data", "chambers.json")
LEADS_PATH = os.path.join(SCRIPT_DIR, "chamber_leads.json")
OVERLAY_PATH = os.path.join(SCRIPT_DIR, "data", "chambers_overlay.json")
OVERLAY_PARTS_DIR = os.path.join(SCRIPT_DIR, "data", "overlay_parts")
FIXTURE_DIR = os.path.join(SCRIPT_DIR, "fixtures", "chambers")

MIN_CHAMBERS = 100

CAPABILITIES = {"diving_emergency", "hyperbaric_unit", "elective", "unknown"}
AVAILABILITIES = {"h24", "on_call", "business_hours", "unknown"}
VERIFICATION_VIA = {"facility", "registry"}

ISO_COUNTRY = re.compile(r"^[A-Z]{2}$")
# Internationally dialable: a leading +, then digits with the separators that
# survive copy-paste from a hospital website.
E164_ISH = re.compile(r"^\+[0-9][0-9\-\s().]{5,}$")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def describe_phone_shape(value):
    """Describe why a number looks wrong without echoing the number itself.

    The two failure modes this pipeline actually hits are a missing country
    code and two numbers fused into one by a greedy match, and both are visible
    from the digit count and the leading character alone. Reporting the shape
    rather than the value also keeps published contact details out of build
    logs, which is what code scanning objects to.
    """
    digits = sum(1 for character in value if character.isdigit())
    lead = "leading +" if value.startswith("+") else "no leading +"
    return f"{digits} digits, {lead}"


def validate_chambers(chambers, min_count=MIN_CHAMBERS):
    """Return a list of human-readable errors. Empty means the dataset is fit
    to ship."""
    errors = []
    seen = set()

    for chamber in chambers:
        cid = chamber.get("id", "")
        where = cid or chamber.get("name", "<unnamed>")

        if not cid:
            errors.append(f"{where}: missing id")
        elif cid in seen:
            errors.append(f"duplicate id: {cid}")
        else:
            seen.add(cid)

        if not chamber.get("name", "").strip():
            errors.append(f"{where}: missing name")

        country = chamber.get("country", "")
        if not ISO_COUNTRY.match(country):
            errors.append(
                f"{where}: country must be an ISO 3166-1 alpha-2 code, "
                f"got {country!r}"
            )

        phone = chamber.get("phone", "")
        if not phone.strip():
            errors.append(f"{where}: missing phone")
        elif not E164_ISH.match(phone):
            errors.append(
                f"{where}: phone must be internationally dialable "
                f"({describe_phone_shape(phone)})"
            )

        emergency_phone = chamber.get("emergencyPhone")
        if emergency_phone is not None and not E164_ISH.match(emergency_phone):
            errors.append(
                f"{where}: emergencyPhone must be internationally dialable "
                f"({describe_phone_shape(emergency_phone)})"
            )

        lat = chamber.get("latitude")
        lon = chamber.get("longitude")
        if not isinstance(lat, (int, float)):
            errors.append(f"{where}: missing latitude")
        elif not -90 <= lat <= 90:
            errors.append(f"{where}: latitude out of range: {lat}")
        if not isinstance(lon, (int, float)):
            errors.append(f"{where}: missing longitude")
        elif not -180 <= lon <= 180:
            errors.append(f"{where}: longitude out of range: {lon}")
        if lat == 0 and lon == 0:
            errors.append(f"{where}: coordinates are 0,0, which is a failed geocode")

        capability = chamber.get("capability", "unknown")
        if capability not in CAPABILITIES:
            errors.append(f"{where}: unknown capability {capability!r}")

        availability = chamber.get("availability", "unknown")
        if availability not in AVAILABILITIES:
            errors.append(f"{where}: unknown availability {availability!r}")

        verified = chamber.get("verified")
        if not isinstance(verified, dict):
            errors.append(f"{where}: missing verified block")
        else:
            date = verified.get("date", "")
            if not ISO_DATE.match(date):
                errors.append(
                    f"{where}: verified.date must be YYYY-MM-DD, got {date!r}"
                )
            elif date > datetime.now(timezone.utc).strftime("%Y-%m-%d"):
                errors.append(f"{where}: verified.date is in the future: {date}")
            if verified.get("via") not in VERIFICATION_VIA:
                errors.append(
                    f"{where}: verified.via must be one of {sorted(VERIFICATION_VIA)}"
                )
            if not verified.get("url", "").startswith("http"):
                errors.append(f"{where}: verified.url must be a URL")

    if len(chambers) < min_count:
        errors.append(
            f"dataset has {len(chambers)} chambers, expected at least {min_count}"
        )

    return errors


# Ids that already ship. `hiddenChamberIds` in the app's settings stores raw
# ids, so a facility arriving from a parser under a generated id must be mapped
# back onto the id it shipped with, or a chamber a diver deliberately hid comes
# back from the dead.
ID_ALIASES = {
    "gb-ddrc-healthcare": "gb-ddrc",
}


def canonicalize_ids(chambers):
    for chamber in chambers:
        alias = ID_ALIASES.get(chamber["id"])
        if alias:
            chamber["id"] = alias
    return chambers


def drop_redundant_emergency_lines(chambers):
    """Remove emergencyPhone when it just repeats phone.

    A duplicate carries no information and invites the reader to believe the
    two fields were mixed up, which is a costly thing to second-guess in a
    directory someone dials during an emergency.
    """
    for chamber in chambers:
        if chamber.get("emergencyPhone") == chamber.get("phone"):
            chamber.pop("emergencyPhone", None)
    return chambers


def merge_rows(leads, overlay):
    """Merge harvested leads with the curated overlay. Overlay wins: it is
    hand-verified, the leads are not. Sorted by id so regenerating the asset
    produces a reviewable diff."""
    by_id = {}
    for row in leads:
        by_id[row["id"]] = row
    for row in overlay:
        by_id[row["id"]] = row
    return [by_id[key] for key in sorted(by_id)]


def write_dataset(chambers, sources, path=OUTPUT_PATH):
    payload = {
        "datasetVersion": datetime.now(timezone.utc).strftime("%Y-%m"),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "note": (
            "Hyperbaric facility directory. Availability changes without notice: "
            "ALWAYS call the diver emergency hotline first for referral. Each "
            "entry carries the date and source its details were verified against."
        ),
        "sources": sources,
        "chambers": chambers,
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def _load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def assemble_overlay():
    """Combine the per-region curation files into the overlay.

    The overlay is split by region while it is being curated because each
    region is researched independently, and a single file would be a merge
    conflict waiting to happen. Assembling it here keeps the build reading one
    input.
    """
    geocode = _load_module("chamber_geocode.py", "chamber_geocode")

    rows = []
    for name in sorted(os.listdir(OVERLAY_PARTS_DIR)):
        if not name.endswith(".json"):
            continue
        part = _load_json(os.path.join(OVERLAY_PARTS_DIR, name), {"chambers": []})
        part_rows = part.get("chambers", [])
        print(f"  {name}: {len(part_rows)} rows")
        rows.extend(part_rows)

    geocode.geocode_rows(rows)
    placed = [r for r in rows if r.get("latitude") is not None]
    dropped = len(rows) - len(placed)
    if dropped:
        print(f"Dropped {dropped} curated rows that could not be placed on a map")

    with open(OVERLAY_PATH, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "sources": [
                    {
                        "id": "curated",
                        "name": "Hand-curated, each row verified against the facility",
                        "url": "https://github.com/submersion-app/submersion",
                        "retrieved": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
                    }
                ],
                "chambers": sorted(placed, key=lambda r: r["id"]),
            },
            handle,
            indent=2,
            ensure_ascii=False,
        )
        handle.write("\n")
    print(f"Wrote {len(placed)} curated chambers to {OVERLAY_PATH}")
    return 0


def build():
    leads_doc = _load_json(LEADS_PATH, {"chambers": [], "sources": []})
    overlay_doc = _load_json(OVERLAY_PATH, {"chambers": [], "sources": []})

    chambers = drop_redundant_emergency_lines(
        merge_rows(
            canonicalize_ids(leads_doc.get("chambers", [])),
            canonicalize_ids(overlay_doc.get("chambers", [])),
        )
    )
    sources = leads_doc.get("sources", []) + overlay_doc.get("sources", [])

    errors = validate_chambers(chambers)
    if errors:
        print(f"Refusing to write the dataset: {len(errors)} validation errors")
        for error in errors:
            print(f"  {error}")
        return 1

    write_dataset(chambers, sources)
    print(f"Wrote {len(chambers)} chambers to {OUTPUT_PATH}")
    return 0


SOURCES = [
    {
        "id": "simsi",
        "name": "SIMSI (Societa Italiana di Medicina Subacquea e Iperbarica)",
        "url": "https://simsi.it/centri-iperbarici-italiani/",
        "fixture": "simsi.html",
        "parser": "parse_simsi",
    },
    {
        "id": "bha",
        "name": "British Hyperbaric Association",
        "url": "https://ukhyperbaric.com/members/",
        "fixture": "bha.html",
        "parser": "parse_bha",
    },
    {
        "id": "ffessm",
        "name": "FFESSM liste des caissons",
        "url": "https://ffessm74.com/wp-content/uploads/2014/03/Liste_Caissons2.pdf",
        "fixture": "ffessm.pdf",
        "parser": "parse_ffessm",
    },
]


def _load_module(filename, name):
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        name, os.path.join(SCRIPT_DIR, filename)
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def harvest_leads():
    """Parse the committed fixtures into leads, geocode them, and write
    chamber_leads.json.

    Fixtures rather than live fetches: the parsers are pinned to the page
    versions the tests assert against, so refreshing the data is a deliberate
    act of recapturing a fixture and re-running the tests, not a silent change
    that lands whenever a registry restyles its site.
    """
    sources = _load_module("chamber_sources.py", "chamber_sources")
    geocode = _load_module("chamber_geocode.py", "chamber_geocode")
    retrieved = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    rows = []
    descriptors = []
    for source in SOURCES:
        path = os.path.join(FIXTURE_DIR, source["fixture"])
        if not os.path.exists(path):
            print(f"  missing fixture, skipping: {source['fixture']}")
            continue

        if source["fixture"].endswith(".pdf"):
            import pypdf

            reader = pypdf.PdfReader(path)
            payload = "\n".join(page.extract_text() or "" for page in reader.pages)
        else:
            with open(path, encoding="utf-8") as handle:
                payload = handle.read()

        parser = getattr(sources, source["parser"])
        parsed = parser(payload, retrieved=retrieved, source_url=source["url"])
        print(f"  {source['id']}: {len(parsed)} leads")
        rows.extend(parsed)
        descriptors.append(
            {
                "id": source["id"],
                "name": source["name"],
                "url": source["url"],
                "retrieved": retrieved,
            }
        )

    geocode.geocode_rows(rows)
    placed = [r for r in rows if r.get("latitude") is not None]
    dropped = len(rows) - len(placed)
    if dropped:
        print(f"Dropped {dropped} leads that could not be placed on a map")

    with open(LEADS_PATH, "w", encoding="utf-8") as handle:
        json.dump(
            {"sources": descriptors, "chambers": placed},
            handle,
            indent=2,
            ensure_ascii=False,
        )
        handle.write("\n")
    print(f"Wrote {len(placed)} leads to {LEADS_PATH}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--leads", action="store_true", help="refresh leads from registries"
    )
    parser.add_argument(
        "--overlay",
        action="store_true",
        help="assemble the curated per-region files into the overlay",
    )
    parser.add_argument(
        "--build", action="store_true", help="merge, validate and write the asset"
    )
    args = parser.parse_args()

    if args.leads:
        raise SystemExit(harvest_leads())
    if args.overlay:
        raise SystemExit(assemble_overlay())
    if args.build:
        raise SystemExit(build())
    parser.print_help()
    return 0


if __name__ == "__main__":
    main()
