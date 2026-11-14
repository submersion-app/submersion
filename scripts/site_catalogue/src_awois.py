#!/usr/bin/env python3
"""NOAA's Automated Wreck and Obstruction Information System (AWOIS).

Public domain (CC0 by Coast Survey's data policy). NOAA stopped updating
AWOIS in 2016 and has since retired its download host, so this reads the
Internet Archive's copy of NOAA's own file.

NOAA graded every position. Only wrecks graded High or Med pass, and only
those not charted as visible and not reported removed (spec section 1).

Run this file to download the register into the snapshot cache.
"""

import collections
import html
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

KEY = "awois"
URL = (
    "https://web.archive.org/web/20240519095415id_/"
    "https://wrecks.nauticalcharts.noaa.gov/downloads/AWOIS_Wrecks.kml"
)

FIELDS = (
    "RECRD", "VESSLTERMS", "FEATURE_TYPE", "LATDEC", "LONDEC", "GP_QUALITY",
    "DEPTH", "SOUNDING_TYPE", "YEARSUNK", "HISTORY",
)

MAX_DEPTH_M = 60.0
_GOOD_QUALITY = frozenset({"High", "Med"})
# How much of the end of a wreck's history is read for its fate.
_HISTORY_TAIL = 600
_GONE = re.compile(
    r"REMOVED|SALVAGED|REFLOATED|DISPROVED|NOT FOUND|DELETE", re.IGNORECASE
)
_PLACEMARK = re.compile(r"<Placemark\b.*?</Placemark>", re.DOTALL)
_CELL = re.compile(r"<th>(\w+)</th>\s*<td>(.*?)</td>", re.DOTALL)


def parse(raw: bytes) -> list[dict]:
    """One row per placemark, from the table in its description."""
    text = raw.decode("utf-8", errors="replace")
    rows = []
    for placemark in _PLACEMARK.findall(text):
        row = {
            field: html.unescape(value).strip()
            for field, value in _CELL.findall(placemark)
        }
        if not rows:
            require_fields(row, FIELDS, KEY)
        rows.append({field: row.get(field, "") for field in FIELDS})
    if not rows:
        raise ValueError(f"{KEY}: the file holds no placemarks")
    return rows


def _depth(row: dict) -> float | None:
    """The stated least depth in metres, or None when it is zero, blank or
    has no stated unit."""
    value = rec.number(row["DEPTH"])
    if value is None or value <= 0:
        return None
    unit = row["SOUNDING_TYPE"].lower()
    if "wire" in unit:
        # A wire-drag clearance: the depth a wire passed at untouched. The
        # wreck lies deeper than that by an amount no one states.
        return None
    if "feet" in unit:
        return rec.feet(value)
    if "fathom" in unit:
        return rec.fathoms(value)
    if "meter" in unit:
        return value
    return None


def _record(row: dict) -> tuple[dict | None, str | None]:
    name = row["VESSLTERMS"]
    if rec.is_placeholder(name):
        return None, "no_name"
    latitude, longitude = rec.number(row["LATDEC"]), rec.number(row["LONDEC"])
    if latitude is None or longitude is None:
        return None, "no_position"
    if row["GP_QUALITY"] not in _GOOD_QUALITY:
        return None, "low_quality"
    if row["FEATURE_TYPE"].lower().startswith("wreck - visible"):
        return None, "visible"
    if _GONE.search(row["HISTORY"][-_HISTORY_TAIL:]):
        return None, "removed"
    depth = _depth(row)
    if depth is not None and depth > MAX_DEPTH_M:
        return None, "too_deep"
    return (
        rec.working(
            id=f"awois_{row['RECRD']}",
            name=rec.display_name(name),
            lat=latitude,
            lon=longitude,
            source=KEY,
            kind="register",
            source_ref=URL,
            types=["wreck"],
            # A least depth over the wreck, and the only depth there is:
            # a lone depth is the site's maximum, as for every source.
            max_depth=depth,
            description=rec.fact_line(None, "lost", row["YEARSUNK"]),
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
    """Downloads the register and writes its snapshot."""
    return write_snapshot(KEY, URL, parse(http_get(URL, timeout=600)))


if __name__ == "__main__":
    print(fetch())
