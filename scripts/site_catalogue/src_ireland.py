#!/usr/bin/env python3
"""The Wreck Inventory of Ireland Database (National Monuments Service).

CC BY 4.0. About 18,000 rows, 3,500 with a position. The inventory says
where each position came from, and that decides what may ship (spec
section 1): positions taken from wrecksite.eu or uboat.net are those
sites' data, not the inventory's to license; positions from Lloyd's List
and similar are where a loss was reported, not where a wreck lies.

Run this file to download the inventory into the snapshot cache.
"""

import collections
import csv
import io
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import records as rec  # noqa: E402
from snapshots import (  # noqa: E402
    http_get,
    require_fields,
    write_snapshot,
)

KEY = "nms_ie"
URL = (
    "https://www.arcgis.com/sharing/rest/content/items/"
    "d4b084c880b546fabe38345461b563d2/data"
)
SOURCE_REF = (
    "https://data.gov.ie/dataset/"
    "national-monuments-service-wreck-inventory-of-ireland"
)

FIELDS = (
    "Wreck Name", "Wreck No", "Classification", "DD_Lat", "DD_Long",
    "Source of Co-ordinate", "Date_of_Loss_Year_Only",
)

# Decimals a position must be written to (0.001 degree is about 100 m).
MIN_DECIMALS = 3
# A position credited to any of these does not ship.
_EXCLUDED_SOURCE = re.compile(
    r"wrecksite|uboat|lloyd|bvls|parliamentary", re.IGNORECASE
)
# "Ardmore (SS)": the inventory's vessel type after the name.
_TYPE_SUFFIX = re.compile(r"\s*\([A-Z]{2,4}\)\s*$")


def parse(raw: bytes) -> list[dict]:
    """The inventory's rows, with the columns the catalogue reads."""
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig"), newline=""))
    rows = []
    for row in reader:
        if not rows:
            require_fields(row, FIELDS, KEY)
        rows.append({field: (row[field] or "").strip() for field in FIELDS})
    if not rows:
        raise ValueError(f"{KEY}: the inventory file holds no rows")
    return rows


def _decimals(text: str) -> int:
    return len(text.split(".", 1)[1]) if "." in text else 0


def _whole_minutes(value: float) -> bool:
    """Whether a decimal coordinate is a whole minute of arc written out
    ("56.16667" is 56 degrees 10 minutes)."""
    minutes = abs(value) * 60
    return abs(minutes - round(minutes)) < 1e-3


def _record(row: dict) -> tuple[dict | None, str | None]:
    name = _TYPE_SUFFIX.sub("", row["Wreck Name"])
    if rec.is_placeholder(name):
        return None, "no_name"
    latitude, longitude = rec.number(row["DD_Lat"]), rec.number(row["DD_Long"])
    # The inventory writes 0, 0 for a wreck it cannot place.
    if not latitude or not longitude:
        return None, "no_position"
    source = row["Source of Co-ordinate"].replace("’", "'")
    if _EXCLUDED_SOURCE.search(source):
        return None, "excluded_source"
    if not source:
        return None, "unstated_source"
    if min(_decimals(row["DD_Lat"]), _decimals(row["DD_Long"])) < MIN_DECIMALS:
        return None, "coarse_position"
    # A reported position, whoever it is credited to: the inventory files
    # 24 scuttled U-boats on one whole-minute point.
    if _whole_minutes(latitude) and _whole_minutes(longitude):
        return None, "coarse_position"
    classification = row["Classification"]
    return (
        rec.working(
            id=f"ie_{row['Wreck No']}",
            name=rec.display_name(name),
            lat=latitude,
            lon=longitude,
            source=KEY,
            kind="register",
            source_ref=SOURCE_REF,
            types=["wreck"],
            description=rec.fact_line(
                None if classification.lower() == "unknown" else classification,
                "lost",
                row["Date_of_Loss_Year_Only"],
            ),
        ),
        None,
    )


def records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """The rows that pass the gate as working records, and how many rows
    each reason dropped."""
    kept, dropped = [], collections.Counter()
    for row in rows:
        record, reason = _record(row)
        if record is None:
            dropped[reason] += 1
        else:
            kept.append(record)
    return kept, dropped


def fetch():
    """Downloads the inventory and writes its snapshot."""
    return write_snapshot(KEY, URL, parse(http_get(URL, timeout=600)))


if __name__ == "__main__":
    print(fetch())
