#!/usr/bin/env python3
"""Reading the evidence behind a researched dive site.

A researched site's facts come from published pages, each written its own
way: decimal degrees, degrees and minutes, degrees, minutes and seconds,
with or without hemisphere letters, to whatever precision the author
chose. This module reads a figure as the page wrote it and says how
precise it is, names the domain a page belongs to, files that domain as
a page that counts, one that may only be cited, or one never used, and
holds the hazard sentences a record carries, which are our own words.

The rules that use these are in check.py; the design is
docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md.
"""

import json
import os
import re
import sys
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlparse

_HERE = os.path.dirname(os.path.abspath(__file__))
_CATALOGUE = os.path.dirname(_HERE)
if _CATALOGUE not in sys.path:
    sys.path.insert(0, _CATALOGUE)

from records import km  # noqa: E402

LISTS = ("counting", "cite_only", "never")

# The hazards a researched record may carry, in the order they are
# written, each as the sentence the catalogue holds.
HAZARD_SENTENCES = {
    "strong_current": "Strong currents.",
    "surge": "Surge in shallow water.",
    "boat_traffic": "Boat traffic overhead.",
    "overhead": "Overhead environment; penetration needs training.",
    "entanglement": "Lines and nets.",
    "cold": "Cold water.",
    "low_visibility": "Visibility often low.",
    "permit": "Protected area; a permit or fee may be needed.",
    "depth": "Depth beyond recreational limits nearby.",
}

# Second-level labels under a two-letter country code that a registrar
# sells beneath (divers.co.uk, parks.gov.my).
_SECOND_LEVEL = frozenset({"co", "com", "org", "net", "gov", "ac", "edu"})

_MARKS = re.compile("[°º˚′″'\"’”]")
_HEMISPHERES = {"lat": {"N": 1, "S": -1}, "lon": {"E": 1, "W": -1}}
_LIMITS = {"lat": 90.0, "lon": 180.0}
_NUMBER = re.compile(r"^\d+(\.\d+)?$")


def _decimals(text: str) -> int:
    return len(text.split(".", 1)[1]) if "." in text else 0


def parse_coordinate(value, axis: str) -> tuple[float, float]:
    """A latitude or longitude as a page wrote it, as (decimal degrees,
    precision in degrees).

    [value] is a number, or text in decimal degrees, degrees and decimal
    minutes, or degrees, minutes and seconds, with an optional hemisphere
    letter of [axis] ("lat" or "lon"). The precision is one unit of the
    last place written: "4 06.9 N" is precise to a tenth of a minute.
    Raises ValueError for anything else, including a minus sign and a
    hemisphere letter together, which would be read twice.
    """
    if axis not in _HEMISPHERES:
        raise ValueError(f"axis {axis!r}")
    if isinstance(value, bool) or value is None:
        raise ValueError(f"not a coordinate: {value!r}")
    if isinstance(value, (int, float)):
        # Written out in full: repr gives 5e-05 for a small float.
        text = (
            format(Decimal(repr(value)), "f") if isinstance(value, float) else str(value)
        )
    elif isinstance(value, str):
        text = value
    else:
        raise ValueError(f"not a coordinate: {value!r}")

    text = _MARKS.sub(" ", text).strip().upper()
    sign = 1
    letter = None
    if text and text[-1] in "NSEW":
        letter, text = text[-1], text[:-1].strip()
    elif text and text[0] in "NSEW":
        letter, text = text[0], text[1:].strip()
    if letter is not None:
        if letter not in _HEMISPHERES[axis]:
            raise ValueError(f"{value!r}: {letter} is not a {axis} hemisphere")
        sign = _HEMISPHERES[axis][letter]
    if text.startswith(("-", "+")):
        if letter is not None:
            raise ValueError(f"{value!r}: a sign and a hemisphere letter")
        if text[0] == "-":
            sign = -sign
        text = text[1:].strip()

    parts = text.split()
    if not 1 <= len(parts) <= 3 or not all(_NUMBER.match(p) for p in parts):
        raise ValueError(f"not a coordinate: {value!r}")
    if any("." in part for part in parts[:-1]):
        # 8 16.5 28 is no form a page means: only the last place has a
        # fraction.
        raise ValueError(f"{value!r}: a fraction before the last part")
    numbers = [float(p) for p in parts]
    if any(n >= 60 for n in numbers[1:]):
        raise ValueError(f"{value!r}: minutes or seconds of 60 or more")
    degrees = numbers[0] + sum(
        n / 60 ** index for index, n in enumerate(numbers[1:], start=1)
    )
    if degrees > _LIMITS[axis]:
        raise ValueError(f"{value!r}: out of range for {axis}")
    unit = 1 / 60 ** (len(parts) - 1)
    precision = unit * 10 ** -_decimals(parts[-1])
    return sign * degrees, precision


def registrable_domain(url: str) -> str:
    """The domain a page's address belongs to: lower case, without its
    port or `www.`, cut to the name a registrar sells (`padi.com`,
    `divers.co.uk`)."""
    host = (urlparse(url).hostname or "").lower()
    if "." not in host:
        raise ValueError(f"no host in {url!r}")
    labels = host.split(".")
    if labels[0] == "www":
        labels = labels[1:]
    keep = (
        3
        if len(labels) >= 3
        and labels[-2] in _SECOND_LEVEL
        and len(labels[-1]) == 2
        else 2
    )
    return ".".join(labels[-keep:])


@dataclass(frozen=True)
class DomainLists:
    """The domains a page may come from, each with the reason it is
    filed where it is: `counting` pages confirm a fact, `cite_only` pages
    may be named but confirm nothing, `never` pages are not used."""

    counting: dict = field(default_factory=dict)
    cite_only: dict = field(default_factory=dict)
    never: dict = field(default_factory=dict)

    def kind_of(self, url: str) -> str | None:
        """Which list a page's domain is on, or None when it is on none.
        A page on a subdomain takes its parent's list."""
        host = (urlparse(url).hostname or "").lower()
        for name in LISTS:
            for domain in getattr(self, name):
                if host == domain or host.endswith("." + domain):
                    return name
        return None


def _domain_key(domain: str) -> str:
    """A list's domain as hosts are compared: lower case, without `www.`."""
    key = domain.strip().lower()
    return key[4:] if key.startswith("www.") else key


def load_domains(path: Path) -> DomainLists:
    """The domain lists in [path], each domain in lower case without
    `www.`. Raises ValueError when a domain is on two lists."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    lists: dict[str, dict] = {name: {} for name in LISTS}
    seen: dict[str, str] = {}
    for name in LISTS:
        for domain, reason in (data.get(name) or {}).items():
            key = _domain_key(domain)
            if key in seen:
                raise ValueError(f"{key} is on both {seen[key]} and {name}")
            seen[key] = name
            lists[name][key] = reason
    return DomainLists(**lists)


def metres_between(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle metres between two positions."""
    return km(lat1, lon1, lat2, lon2) * 1000


def hazards_text(codes) -> str | None:
    """The hazards a record carries, as one text in table order, or None
    for none."""
    chosen = set(codes)
    sentences = [s for code, s in HAZARD_SENTENCES.items() if code in chosen]
    return " ".join(sentences) or None
