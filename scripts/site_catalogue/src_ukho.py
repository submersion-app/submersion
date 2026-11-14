#!/usr/bin/env python3
"""The UK Hydrographic Office's Wrecks and Obstructions register.

Open Government Licence v3.0. About 103,000 rows worldwide: every charted
wreck and obstruction, live or dead. Most are not dive sites, and many
positions are a reported sinking written to the nearest minute, so the
gate here is what makes the register usable (spec section 1): a named,
live, always-submerged wreck, with a position written to 0.01 minute or
fixed by a stated method, charted in 2 to 60 m.

Run this file to download the register into the snapshot cache.
"""

import collections
import csv
import io
import os
import re
import sys
import zipfile

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

KEY = "ukho"
URL = (
    "https://datahub.admiralty.co.uk/portal/sharing/rest/content/items/"
    "60c0908526b844a68494c038a457e1a7/data"
)
SOURCE_REF = (
    "https://datahub.admiralty.co.uk/portal/apps/sites/#/"
    "marine-data-portal/items?tags=GlobalWrecks"
)

# The columns the gate and the record read. The register has 50.
FIELDS = (
    "wreck_id", "name", "status", "wreck_category", "obstruction_category",
    "type", "latitude", "longitude", "position_method", "depth",
    "water_depth", "water_level_effect", "date_sunk", "general_comments",
)

MIN_DEPTH_M = 2.0
MAX_DEPTH_M = 60.0
# Decimals of a minute a position must be written to (0.01 minute is about
# 18 m), unless the register says how the position was fixed.
MIN_MINUTE_DECIMALS = 2

_NOT_WRECK_TYPES = frozenset(
    {"wellhead", "mobile crane", "anchor", "fisherman's fastener"}
)
_POSITION = re.compile(r"^\s*(\d{1,3})\s+(\d{1,2}(?:\.(\d+))?)\s*([NSEW])\s*$")
_DIVING_PROHIBITED = re.compile(
    r"\bno\b[^.;]*\bdiving\b"
    r"|\bdiving\b[^.;]*\b(prohibited|not permitted|forbidden|restricted)\b",
    re.IGNORECASE,
)
_RESTRICTION = re.compile(
    r"restrict|rest'd|prohibit|protected|military remains|controlled site"
    r"|historic wreck|heritage",
    re.IGNORECASE,
)
_MAX_HAZARD_CHARS = 200


def _decode(raw: bytes) -> str:
    """The register's text. It is nearly all ASCII; the few names with an
    accent are mostly UTF-8, and a line that is not is read as Windows
    Latin so one stray byte never stops the file."""
    lines = []
    for line in raw.split(b"\n"):
        try:
            lines.append(line.decode("utf-8"))
        except UnicodeDecodeError:
            lines.append(line.decode("cp1252", errors="replace"))
    return "\n".join(lines)


def parse(raw: bytes) -> list[dict]:
    """The register's rows, with the columns the catalogue reads."""
    csv.field_size_limit(1 << 30)
    reader = csv.DictReader(io.StringIO(_decode(raw), newline=""), delimiter="\t")
    rows = []
    for row in reader:
        if not rows:
            require_fields(row, FIELDS, KEY)
        rows.append({field: (row[field] or "").strip() for field in FIELDS})
    if not rows:
        raise ValueError(f"{KEY}: the register file holds no rows")
    return rows


def _coordinate(text: str) -> tuple[float, int] | None:
    """(degrees, decimals written in the minutes) for "51 20.55 N"."""
    match = _POSITION.match(text or "")
    if not match:
        return None
    value = int(match.group(1)) + float(match.group(2)) / 60
    if match.group(4) in "SW":
        value = -value
    return value, len(match.group(3) or "")


def _sentence_case(text: str) -> str:
    lowered = " ".join(text.split()).lower()
    return re.sub(
        r"(^|[.!?]\s+)([a-z])",
        lambda match: match.group(1) + match.group(2).upper(),
        lowered,
    )


def hazard(comments: str) -> str | None:
    """The register's own statement of a restriction or protection, in
    sentence case, or None when its comments state none."""
    text = " ".join((comments or "").split())
    if not _RESTRICTION.search(text):
        return None
    if len(text) > 120:
        # A long survey note: only the sentences that state it.
        sentences = [
            sentence
            for sentence in re.split(r"(?<=[.;])\s+", text)
            if _RESTRICTION.search(sentence)
        ]
        text = " ".join(sentences)
    text = _sentence_case(text)[:_MAX_HAZARD_CHARS].rstrip()
    return text if text.endswith((".", "!", "?")) else text + "."


def _record(row: dict) -> tuple[dict | None, str | None]:
    name = row["name"]
    if rec.is_placeholder(name):
        return None, "no_name"
    status = row["status"].lower()
    if "dead" in status or "lifted" in status:
        return None, "dead"
    if "doubtful" in status:
        return None, "doubtful"
    latitude = _coordinate(row["latitude"])
    longitude = _coordinate(row["longitude"])
    if latitude is None or longitude is None:
        return None, "no_position"
    if not row["water_level_effect"].lower().startswith("always under water"):
        return None, "not_submerged"
    if (
        not row["wreck_category"]
        or row["obstruction_category"]
        or row["type"].lower() in _NOT_WRECK_TYPES
    ):
        return None, "not_wreck"
    if (
        min(latitude[1], longitude[1]) < MIN_MINUTE_DECIMALS
        and not row["position_method"]
    ):
        return None, "coarse_position"
    charted = rec.number(row["water_depth"])
    least = rec.number(row["depth"])
    depth = charted if charted is not None else least
    if depth is None:
        return None, "no_depth"
    if depth < MIN_DEPTH_M:
        return None, "too_shallow"
    if depth > MAX_DEPTH_M:
        return None, "too_deep"
    if _DIVING_PROHIBITED.search(row["general_comments"]):
        return None, "diving_prohibited"
    return (
        rec.working(
            id=f"ukho_{row['wreck_id']}",
            name=rec.display_name(name),
            lat=latitude[0],
            lon=longitude[0],
            source=KEY,
            kind="register",
            source_ref=SOURCE_REF,
            types=["wreck"],
            max_depth=depth,
            min_depth=least
            if charted is not None and least is not None and least < charted
            else None,
            description=rec.fact_line(row["type"], "lost", row["date_sunk"]),
            hazards=hazard(row["general_comments"]),
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
    archive = zipfile.ZipFile(io.BytesIO(http_get(URL, timeout=600)))
    name = next(
        name for name in archive.namelist() if name.lower().endswith(".txt")
    )
    return write_snapshot(KEY, URL, parse(archive.read(name)))


if __name__ == "__main__":
    print(fetch())
