#!/usr/bin/env python3
"""The working record every catalogue source produces, and the name rules.

A source module turns its register's rows into working records: plain
dicts with one fixed set of keys (`working`). The merge gates, groups,
de-duplicates and places them, then writes them through
`site_catalogue_format.to_catalogue_record`.

Two registers rarely write one wreck's name the same way ("HMS EXETER",
"Exeter (wreck)"), so the overlap check compares folded names
(`fold_name`), and upper-case register names are recased for display
(`display_name`).
"""

import math
import re
import unicodedata

FEET_TO_M = 0.3048
FATHOMS_TO_M = 1.8288

# What a ship is called before its name. Kept as written when a register
# name is recased; dropped when two names are compared.
SHIP_PREFIXES = (
    "HMS", "HMT", "HMAS", "HMCS", "HMNZS", "USS", "USNS", "USAT", "USCGC",
    "SS", "MV", "MT", "FV", "SV", "RMS", "RFA", "MFV", "TSS", "SMS",
)

# Designations that stay upper case in a recased name, beyond the prefixes.
_KEEP_UPPER = frozenset(SHIP_PREFIXES) | {
    "TB", "LCT", "LST", "LCU", "LCI", "LCM", "MTB", "MGB", "ML", "HMY",
    "II", "III", "IV", "VI", "VII", "VIII", "IX", "XI", "XII",
}

# Dropped from the front of a folded name, longest first.
_FOLD_PREFIXES = tuple(
    sorted(
        [prefix.lower() for prefix in SHIP_PREFIXES]
        + ["s s", "m v", "f v", "the", "wreck of the", "wreck of", "wreck",
           "epave", "wrak"],
        key=len,
        reverse=True,
    )
)

# Dropped from the end of a folded name.
_FOLD_SUFFIXES = ("shipwreck", "wreck", "reef")

# A name that says nothing about which site it is.
_PLACEHOLDERS = frozenset(
    {"unknown", "unidentified", "wreck", "wrecks", "obstruction", "barge"}
)
_PLACEHOLDER_START = re.compile(r"^(unnamed|unknown)\b", re.IGNORECASE)

# Names so common that two records sharing one are the same site only when
# they are almost on top of each other.
GENERIC_NAMES = frozenset(
    {"barge", "tug", "trawler", "dredger", "yacht", "pontoon", "lighter",
     "landing craft", "fishing vessel", "boat"}
)

KINDS = ("site", "register")


def _ascii(text: str) -> str:
    return (
        unicodedata.normalize("NFKD", text)
        .encode("ascii", "ignore")
        .decode("ascii")
    )


def fold_name(name: str) -> str:
    """[name] as two sources' names for one site are compared: lower case,
    no accents, no bracketed text, no ship prefix, no trailing "wreck" or
    "reef". A name that is nothing but a dropped word keeps it.
    """
    text = re.sub(r"\(.*?\)", " ", _ascii(name).lower())
    words = re.sub(r"[^a-z0-9]+", " ", text).strip()
    changed = True
    while changed:
        changed = False
        for prefix in _FOLD_PREFIXES:
            if words.startswith(prefix + " "):
                words = words[len(prefix) + 1:]
                changed = True
                break
    for suffix in _FOLD_SUFFIXES:
        if words.endswith(" " + suffix):
            words = words[: -len(suffix) - 1]
            break
    return words.strip()


def is_placeholder(name: str) -> bool:
    """Whether [name] names no particular site ("Unknown", "Wreck")."""
    text = (name or "").strip()
    if not text:
        return True
    return (
        text.lower() in _PLACEHOLDERS
        or _PLACEHOLDER_START.match(text) is not None
    )


def is_generic(folded: str) -> bool:
    """Whether a folded name is too common, or too short, to match on from
    a distance."""
    return folded in GENERIC_NAMES or len(folded) < 4


def _recase_word(word: str, next_word: str | None) -> str:
    bare = re.sub(r"[^A-Za-z0-9]", "", word)
    if bare.upper() in _KEEP_UPPER:
        return word
    # "U 11", "U-534", "LCT7074": a short designation with its number.
    letters = re.sub(r"[^A-Za-z]", "", word)
    if len(letters) <= 3 and re.search(r"\d", word) and "-" not in word[1:2]:
        if not re.search(r"[A-Za-z]{4,}", word):
            return word
    if len(letters) == 1 and next_word and next_word[:1].isdigit():
        return word
    return re.sub(
        r"[A-Za-z]+",
        lambda match: match.group(0)[0].upper() + match.group(0)[1:].lower(),
        word,
    )


def display_name(raw: str) -> str:
    """A register's name as the catalogue shows it.

    A name written all in capitals is put in title case, with ship
    prefixes and designations kept as written and bracketed remarks (the
    register's own doubt, "(POSSIBLY)") in lower case. A name that already
    has lower-case letters is the source's own spelling and is left alone.
    """
    text = " ".join((raw or "").split())
    if any(char.islower() for char in text):
        return text
    parts = re.split(r"(\(.*?\))", text)
    out = []
    for part in parts:
        if part.startswith("("):
            out.append(part.lower())
            continue
        words = part.split(" ")
        out.append(
            " ".join(
                _recase_word(word, words[i + 1] if i + 1 < len(words) else None)
                if word
                else word
                for i, word in enumerate(words)
            )
        )
    return "".join(out).strip()


def slug(text: str) -> str:
    """[text] as an id part: lower-case ASCII letters and digits joined by
    underscores."""
    return re.sub(r"[^a-z0-9]+", "_", _ascii(text).lower()).strip("_")


def number(raw) -> float | None:
    """What a register wrote in a numeric column, or None when it wrote
    nothing or a word ("UNKNOWN")."""
    if raw is None:
        return None
    try:
        return float(str(raw).strip())
    except ValueError:
        return None


def feet(value: float) -> float:
    return value * FEET_TO_M


def fathoms(value: float) -> float:
    return value * FATHOMS_TO_M


def km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle kilometres between two positions."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371.0088 * math.asin(min(1.0, math.sqrt(h)))


def _depth(value) -> float | None:
    if value is None or value <= 0:
        return None
    return round(value, 1)


def working(
    *,
    id: str,
    name: str,
    lat: float | None,
    lon: float | None,
    source: str,
    kind: str,
    source_ref: str | None = None,
    types=(),
    max_depth: float | None = None,
    min_depth: float | None = None,
    description: str | None = None,
    hazards: str | None = None,
    locality: str | None = None,
    region: str | None = None,
    website: str | None = None,
    entry_type: str | None = None,
    features=(),
    water_type: str | None = None,
    geocoded=None,
) -> dict:
    """One site as every source hands it to the merge.

    Depths are metres; zero or below is no depth. [geocoded] is the
    geocoder's (code, name, island) for an OpenStreetMap dive site, and
    None for everything the merge places itself.
    """
    if kind not in KINDS:
        raise ValueError(f"{id}: kind {kind!r}")
    located = lat is not None and lon is not None
    return {
        "id": id,
        "name": " ".join(name.split()),
        "lat": round(lat, 6) if located else None,
        "lon": round(lon, 6) if located else None,
        "source": source,
        "kind": kind,
        "source_ref": source_ref,
        "types": list(types),
        "max_depth": _depth(max_depth),
        "min_depth": _depth(min_depth),
        "description": description,
        "hazards": hazards,
        "locality": locality,
        "region": region,
        "website": website,
        "entry_type": entry_type,
        "features": list(features),
        "water_type": water_type,
        "geocoded": list(geocoded) if geocoded is not None else None,
    }
