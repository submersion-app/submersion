#!/usr/bin/env python3
"""Builds the site catalogue the app ships, from the sources' snapshots.

    python3 scripts/site_catalogue/merge.py [--without KEY ...]
                                            [--open-only] [--out DIR]

Each source is downloaded on its own, by its own module, into the snapshot
cache (run `python3 scripts/site_catalogue/src_ukho.py` and its siblings,
and `places.py` for the boundaries). This step then needs no network: it
gates each source's rows, turns deployments into sites, removes the sites
two sources both list, places every record in a country and a region, and
writes `assets/data/site_catalogue.json` with its version sidecar.

It refuses to run when a source's snapshot is missing, unless that source
is named with `--without`: a catalogue quietly short of a register would
look like a clean run.

`--open-only` writes the catalogue without the own-terms sources: the
ODbL database alone, for the ODbL offer and for anyone redistributing
commercially.

It prints, per source, what was read, what each gate dropped and what was
written, then the ids that left and joined the catalogue it replaces.
"""

import argparse
import json
import os
import sys
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import places as places_module  # noqa: E402
import records as rec  # noqa: E402
import src_awois  # noqa: E402
import src_ireland  # noqa: E402
import src_osm  # noqa: E402
import src_reefs  # noqa: E402
import src_ukho  # noqa: E402
import src_wikidata  # noqa: E402
from curated_sites import CURATED_COUNTRY_CODES, load_curated  # noqa: E402
from overlap import resolve  # noqa: E402
from site_catalogue_format import (  # noqa: E402
    CATALOGUE_FILE,
    map_entry,
    to_catalogue_record,
    write_catalogue,
)
from snapshots import CACHE_DIR, read_snapshot  # noqa: E402

_REPO = Path(_HERE).parent.parent
DEFAULT_OUT = _REPO / "assets" / "data"

# Each snapshot and the function that turns its rows into working records.
SOURCE_STEPS = {
    "osm_sites": src_osm.site_records,
    "osm_wrecks": src_osm.wreck_records,
    "ukho": src_ukho.records,
    "awois": src_awois.records,
    "nms_ie": src_ireland.records,
    "fwc": src_reefs.fwc_records,
    "noaa_reefs": src_reefs.federal_records,
    "njdep": src_reefs.njdep_records,
    "nc_dmf": src_reefs.nc_dmf_records,
    "fknms": src_reefs.fknms_records,
    "wikidata_sites": src_wikidata.site_records,
    "wikidata_wrecks": src_wikidata.wreck_records,
}

_ORIGIN = "_origin"
_CURATED = "curated"
# How many ids of each kind the report lists before it only counts.
_LISTED_IDS = 40


def _curated_working(entry: dict) -> dict:
    """A curated entry as a working record. Its kind is a site type
    (wreck, wall, reef) or an entry (shore)."""
    kind = entry.get("kind")
    is_entry = bool(map_entry(kind))
    return rec.working(
        id=entry["id"],
        name=entry["name"],
        lat=entry.get("latitude"),
        lon=entry.get("longitude"),
        source="curated",
        kind="site",
        source_ref=entry.get("source"),
        types=[kind] if kind and not is_entry else [],
        max_depth=entry.get("depthM"),
        description=entry.get("description"),
        region=entry.get("region"),
        website=entry.get("website"),
        entry_type=kind if is_entry else None,
    )


def _catalogue_record(record: dict, places, curated_countries: dict) -> dict:
    """A working record placed in the world and written in the catalogue's
    format."""
    code = country = island = None
    region = record["region"]
    water_type = record["water_type"]
    if record["lat"] is not None and record["lon"] is not None:
        if record["geocoded"] is not None:
            place = places.settle(record["geocoded"], record["lat"], record["lon"])
        else:
            place = places.place(record["lat"], record["lon"])
        code, country, island = place.country_code, place.country, place.island
        # A curated entry's own region stands; everything else takes the
        # English name the boundaries give.
        region = region or place.region
        if place.fresh and not water_type:
            water_type = "fresh"
    if code is None and record["id"] in curated_countries:
        # A wreck too far out for the lookup: the entry's own country.
        country = curated_countries[record["id"]]
        code = CURATED_COUNTRY_CODES.get(country)
        if code is None:
            country = None
    return to_catalogue_record(
        {
            "id": record["id"],
            "name": record["name"],
            "latitude": record["lat"],
            "longitude": record["lon"],
            "region": region,
            "locality": record["locality"],
            "island": island,
            "water_type": water_type,
            "min_depth": record["min_depth"],
            "max_depth": record["max_depth"],
            # Site types first: the format sorts type ids from the rest.
            "features": record["types"] + record["features"],
            "entry_type": record["entry_type"],
            "hazards": record["hazards"],
            "description": record["description"],
            "website": record["website"],
        },
        source=record["source"],
        source_ref=record["source_ref"],
        country_code=code,
        country=country,
        kind=record["kind"],
    )


def build(snapshots: dict, curated: list[dict], places) -> tuple[list[dict], dict]:
    """The catalogue's records, and a report of what became of each
    source's rows.

    [snapshots] maps a snapshot key to its rows. A key that is absent is a
    source left out. The report maps each key (and "curated") to its rows
    `read`, the rows each gate `dropped`, the records `formed`, those lost
    to `overlap` with another source, and those `written`.
    """
    working: list[dict] = []
    report: dict[str, dict] = {}
    for key in sorted(snapshots):
        formed, dropped = SOURCE_STEPS[key](snapshots[key])
        # A register can list one id on two rows. The first stands.
        seen: set[str] = set()
        unique = []
        for record in formed:
            if record["id"] in seen:
                dropped["duplicate_id"] += 1
                continue
            seen.add(record["id"])
            record[_ORIGIN] = key
            unique.append(record)
        formed = unique
        working.extend(formed)
        report[key] = {
            "read": len(snapshots[key]),
            "dropped": dict(sorted(dropped.items())),
            "formed": len(formed),
        }
    for entry in curated:
        record = _curated_working(entry)
        record[_ORIGIN] = _CURATED
        working.append(record)
    report[_CURATED] = {"read": len(curated), "dropped": {}, "formed": len(curated)}

    survivors, _ = resolve(working)
    written: dict[str, int] = {}
    for record in survivors:
        written[record[_ORIGIN]] = written.get(record[_ORIGIN], 0) + 1
    for key, line in report.items():
        line["written"] = written.get(key, 0)
        line["overlap"] = line["formed"] - line["written"]

    curated_countries = {entry["id"]: entry.get("country") for entry in curated}
    return (
        [
            _catalogue_record(record, places, curated_countries)
            for record in sorted(survivors, key=lambda r: r["id"])
        ],
        report,
    )


def id_changes(old_ids: set[str], new_ids: set[str]) -> dict:
    """The ids that left and joined the catalogue, grouped by their
    prefix (the part before the first underscore)."""

    def grouped(ids) -> dict[str, list[str]]:
        groups: dict[str, list[str]] = {}
        for site_id in sorted(ids):
            groups.setdefault(site_id.split("_", 1)[0], []).append(site_id)
        return groups

    return {"gone": grouped(old_ids - new_ids), "new": grouped(new_ids - old_ids)}


def _print_report(report: dict, changes: dict | None) -> None:
    print(f"{'source':17}{'read':>8}{'formed':>8}{'overlap':>9}{'written':>9}  dropped")
    for key, line in report.items():
        dropped = ", ".join(
            f"{reason} {count}" for reason, count in line["dropped"].items()
        )
        print(
            f"{key:17}{line['read']:>8}{line['formed']:>8}"
            f"{line['overlap']:>9}{line['written']:>9}  {dropped}"
        )
    print(f"{'total':17}{'':>8}{'':>8}{'':>9}"
          f"{sum(line['written'] for line in report.values()):>9}")
    if changes is None:
        print("\nNo catalogue to compare with: every id is new.")
        return
    for label in ("gone", "new"):
        total = sum(len(ids) for ids in changes[label].values())
        print(f"\nIds {label}: {total}")
        for prefix, ids in changes[label].items():
            listed = ", ".join(ids[:_LISTED_IDS])
            more = f" and {len(ids) - _LISTED_IDS} more" if len(ids) > _LISTED_IDS else ""
            print(f"  {prefix} ({len(ids)}): {listed}{more}")


def _existing_ids(directory: Path) -> set[str] | None:
    path = directory / CATALOGUE_FILE
    if not path.exists():
        return None
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except ValueError:
        return None
    return {site["id"] for site in doc.get("sites") or [] if "id" in site}


def main(argv=None, *, places=None, curated=None) -> int:
    """Runs the merge. [places] and [curated] stand in for the offline
    lookup and the curated file in tests."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--without", nargs="+", default=[], metavar="KEY",
        choices=sorted(SOURCE_STEPS),
        help="snapshot keys to leave out of this catalogue",
    )
    parser.add_argument(
        "--open-only", action="store_true",
        help="write the ODbL database alone, without the own-terms sources",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--cache", type=Path, default=CACHE_DIR)
    arguments = parser.parse_args(argv)

    snapshots: dict[str, list[dict]] = {}
    fetched: list[str] = []
    for key in sorted(SOURCE_STEPS):
        if key in arguments.without:
            continue
        try:
            snapshot = read_snapshot(key, arguments.cache)
        except FileNotFoundError as error:
            print(f"{error}\nName it with --without to build a catalogue without it.")
            return 2
        snapshots[key] = snapshot["rows"]
        fetched.append(snapshot["fetched_at"])

    if places is None:
        answers = [
            row.get("geocoded")
            for row in snapshots.get("osm_sites", [])
            if row.get("geocoded")
        ]
        places = places_module.load_places(
            arguments.cache,
            places_module.preferred_country_names(
                answers, places_module.known_country_names()
            ),
        )
    if curated is None:
        curated = load_curated()

    catalogue, report = build(snapshots, curated, places)
    old_ids = _existing_ids(arguments.out)
    # Stamped with the newest download, so the same snapshots always write
    # the same bytes.
    write_catalogue(
        arguments.out, catalogue, max(fetched), open_only=arguments.open_only
    )
    _print_report(
        report,
        None if old_ids is None else id_changes(old_ids, {r["id"] for r in catalogue}),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
