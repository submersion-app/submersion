#!/usr/bin/env python3
"""Checks the evidence behind researched dive sites.

    python3 scripts/site_catalogue/research/check.py [--file PATH]
        [--domains PATH] [--review OUT]

A researched site ships only when its evidence meets the rules of the
slice 3 design (docs/design/specs/2026-11-15-site-catalogue-researched-
sites-design.md, section 4): two counting pages on different domains
agree on its position within 150 m, each written finely enough to say so;
its depths agree well enough or are left out; every fact has a counting
page; and nothing holds any page's text. This script runs those rules on
`sites.json` with no network, prints what it found, and exits 1 when any
entry breaks one, whatever that entry's review state. CI runs it on the
committed file.

With `--review OUT` it also writes the page the maintainer approves a
batch from (review.py).
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
_CATALOGUE = os.path.dirname(_HERE)
for _path in (_HERE, _CATALOGUE, os.path.dirname(_CATALOGUE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import evidence  # noqa: E402
from site_catalogue_format import (  # noqa: E402
    ENTRY_METHODS,
    SITE_TYPE_IDS,
    WITHDRAWAL_REASONS,
    is_iso_date,
)

SITES_FILE = Path(_HERE) / "sites.json"
DOMAINS_FILE = Path(_HERE) / "domains.json"

# Two counting positions agree when they lie this close.
AGREE_M = 150.0
# The shipped point is the mean of the counting positions, to within this.
MEAN_M = 10.0
# The coarsest figure that can confirm a position: a tenth of a minute.
# Three decimals of a degree and a whole second are finer.
COARSEST_DEG = 0.1 / 60 + 1e-12
# Depths are left out when the counting maxima spread by more than both.
SPREAD_M = 5.0
SPREAD_SHARE = 0.25
FEET = 0.3048
NAME_MAX = 60

ENTRY_FIELDS = frozenset({
    "id", "name", "area", "country_code", "named", "position", "max_depth_m",
    "min_depth_m", "entry", "types", "hazards", "review", "withdrawn", "note",
    "distinct_from",
})
SOURCE_FIELDS = frozenset({
    "url", "read", "lat", "lon", "value", "unit", "contradicts", "archive",
    "method", "map",
})
FACTS = {
    "entry": frozenset(ENTRY_METHODS),
    "types": frozenset(SITE_TYPE_IDS),
    "hazards": frozenset(evidence.HAZARD_SENTENCES),
}
REVIEW_STATES = ("pending", "approved", "rejected")
_COUNTRY = re.compile(r"^[A-Z]{2}$")


@dataclass(frozen=True)
class Finding:
    entry_id: str
    rule: str
    message: str
    fatal: bool = True


@dataclass
class CheckedEntry:
    """An evidence entry with what the rules made of it: the findings,
    and the values it would ship."""

    entry: dict
    findings: list = field(default_factory=list)
    position: tuple | None = None
    # How the position was reached: "confirmed" (two stated figures
    # agree), "stated" (one) or "map" (map-grade figures).
    route: str | None = None
    min_depth: float | None = None
    max_depth: float | None = None
    types: list = field(default_factory=list)
    entries: list = field(default_factory=list)
    hazards: list = field(default_factory=list)
    left_out: list = field(default_factory=list)
    # Points for the reviewer that block nothing (see flag()).
    flags: list = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not any(finding.fatal for finding in self.findings)

    @property
    def id(self) -> str:
        return str(self.entry.get("id") or "(no id)")

    @property
    def state(self) -> str:
        review = self.entry.get("review")
        if review is None:
            return "pending"
        if not isinstance(review, dict):
            return "invalid"
        return review.get("state") or "pending"

    @property
    def withdrawn(self) -> bool:
        return bool(self.entry.get("withdrawn"))

    def fail(self, rule: str, message: str) -> None:
        self.findings.append(Finding(self.id, rule, message))

    def note(self, rule: str, message: str) -> None:
        self.findings.append(Finding(self.id, rule, message, fatal=False))
        self.left_out.append(message)

    def flag(self, rule: str, message: str) -> None:
        """A point for the reviewer to look at: it blocks nothing and
        leaves nothing out."""
        finding = Finding(self.id, rule, message, fatal=False)
        self.findings.append(finding)
        self.flags.append(finding)


def _sources(fact) -> list[dict]:
    if isinstance(fact, dict) and isinstance(fact.get("sources"), list):
        return [s for s in fact["sources"] if isinstance(s, dict)]
    return []


def _all_sources(entry: dict) -> list[dict]:
    found = []
    for key in ("named", "position", "max_depth_m", "min_depth_m", *FACTS):
        found.extend(_sources(entry.get(key)))
    return found


def _check_shape(checked: CheckedEntry, ids: set[str], today: date) -> None:
    entry = checked.entry
    site_id = entry.get("id")
    if not isinstance(site_id, str) or not site_id.startswith("research_"):
        checked.fail("id_prefix", "an id starts research_")
    elif site_id in ids:
        checked.fail("id_repeat", "the id is used by another entry")
    for key in sorted(set(entry) - ENTRY_FIELDS):
        checked.fail("text_field", f"no field {key!r}: a page's text is never kept")
    name = entry.get("name")
    if not isinstance(name, str) or not name.strip():
        checked.fail("shape", "no name")
    elif len(name) > NAME_MAX:
        checked.fail("name_length", f"name over {NAME_MAX} characters")
    if not isinstance(entry.get("country_code"), str) or not _COUNTRY.match(
        entry["country_code"]
    ):
        checked.fail("shape", "country_code is two capital letters")
    for source in _all_sources(entry):
        for key in sorted(set(source) - SOURCE_FIELDS):
            checked.fail("text_field", f"no source field {key!r}")
        read = source.get("read")
        try:
            when = date.fromisoformat(read) if isinstance(read, str) else None
        except ValueError:
            when = None
        if when is None:
            checked.fail("read_date", f"{source.get('url')}: no read date")
        elif when > today + timedelta(days=1):
            # A day of slack: a researcher east of UTC writes a date the
            # checker, running in UTC, has not reached yet.
            checked.fail("read_date", f"{source.get('url')}: read in the future")

    review = entry.get("review")
    if not isinstance(review, dict) or review.get("state") not in REVIEW_STATES:
        checked.fail("shape", "review.state is pending, approved or rejected")
    elif review["state"] != "pending" and not review.get("date"):
        checked.fail("shape", "a review decision carries its date")
    elif review["state"] == "rejected" and not review.get("reason"):
        checked.fail("shape", "a rejection carries its reason")
    withdrawn = entry.get("withdrawn")
    if withdrawn is not None:
        if not isinstance(withdrawn, dict) or withdrawn.get(
            "reason"
        ) not in WITHDRAWAL_REASONS:
            checked.fail("shape", f"withdrawn.reason is one of {WITHDRAWAL_REASONS}")
        elif not is_iso_date(withdrawn.get("date")):
            checked.fail("shape", "a withdrawal carries its date, YYYY-MM-DD")
        elif "replaced_by" in withdrawn and not _is_record_id(
            withdrawn["replaced_by"]
        ):
            checked.fail("shape", "withdrawn.replaced_by is a record id")


def _is_record_id(value) -> bool:
    """Whether [value] can name a catalogue record: a non-empty string."""
    return isinstance(value, str) and bool(value.strip())


def _check_domains(checked: CheckedEntry, domains) -> None:
    for source in _all_sources(checked.entry):
        url = source.get("url")
        kind = domains.kind_of(url) if isinstance(url, str) else None
        if kind is None:
            checked.fail("unknown_domain", f"{url}: domain on no list")
        elif kind == "never":
            checked.fail("never_source", f"{url}: a page never used")


def _counting(sources, domains) -> list[dict]:
    return [
        s for s in sources
        if isinstance(s.get("url"), str)
        and domains.kind_of(s["url"]) == "counting"
    ]


def _mean_longitude(values: list[float]) -> float:
    """The mean of longitudes that agree within 150 m, taken the short way
    round: two figures either side of 180 degrees average to 180, not 0."""
    first = values[0]
    unwrapped = [first + (v - first + 180.0) % 360.0 - 180.0 for v in values]
    mean = sum(unwrapped) / len(unwrapped)
    return (mean + 180.0) % 360.0 - 180.0 if not -180.0 <= mean <= 180.0 else mean


def _check_position(checked: CheckedEntry, domains) -> None:
    position = checked.entry.get("position")
    sources = _sources(position)
    counted = _counting(sources, domains)
    figures = []
    for source in sources:
        try:
            lat, lat_p = evidence.parse_coordinate(source.get("lat"), "lat")
            lon, lon_p = evidence.parse_coordinate(source.get("lon"), "lon")
        except ValueError as error:
            if source in counted:
                checked.fail("shape", f"{source.get('url')}: {error}")
                return
            # A cited page never counts, so its odd figure costs nothing.
            checked.note("position_unread", f"{source.get('url')}: {error}")
            continue
        figures.append((source, lat, lon, max(lat_p, lon_p)))
    counting = [f for f in figures if f[0] in counted]
    if len(counting) < 2:
        checked.fail("position_sources", "two counting pages state a position")
        return
    hosts = {evidence.registrable_domain(f[0]["url"]) for f in counting}
    if len(hosts) < 2:
        checked.fail("position_domains", "the counting positions share a domain")
    for source, _, _, precision in counting:
        if precision > COARSEST_DEG:
            checked.fail(
                "position_precision",
                f"{source['url']}: written coarser than a tenth of a minute",
            )
    for i, a in enumerate(counting):
        for b in counting[i + 1:]:
            apart = evidence.metres_between(a[1], a[2], b[1], b[2])
            if apart > AGREE_M:
                checked.fail(
                    "position_spread",
                    f"{a[0]['url']} and {b[0]['url']} are {apart:.0f} m apart",
                )
    mean = (
        sum(f[1] for f in counting) / len(counting),
        _mean_longitude([f[2] for f in counting]),
    )
    checked.position = mean
    checked.route = "confirmed"
    try:
        stated = (float(position["lat"]), float(position["lon"]))
    except (KeyError, TypeError, ValueError):
        checked.fail("shape", "position.lat and position.lon are numbers")
        return
    if evidence.metres_between(*stated, *mean) > MEAN_M:
        checked.fail("position_mean", "lat and lon are not the counting mean")


def _check_named(checked: CheckedEntry, domains) -> None:
    """Two counting pages on different domains name the site. A position
    two counting pages confirm proves that already."""
    if checked.route == "confirmed":
        return
    named = _counting(_sources(checked.entry.get("named")), domains)
    hosts = {evidence.registrable_domain(s["url"]) for s in named}
    if len(hosts) < 2:
        checked.fail(
            "named_sources", "two counting pages on different domains name the site"
        )


def _depth_values(checked: CheckedEntry, key: str, domains) -> list[float]:
    fact = checked.entry.get(key)
    if fact is None:
        return []
    if not isinstance(fact, dict):
        checked.fail("depth_by_hand", f"{key} is computed, never written")
        return []
    values = []
    for source in _counting(_sources(fact), domains):
        value, unit = source.get("value"), source.get("unit", "m")
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
            checked.fail("shape", f"{source['url']}: {key} value is a depth")
        elif unit not in ("m", "ft"):
            checked.fail("shape", f"{source['url']}: unit is m or ft")
        else:
            values.append(round(value * FEET, 2) if unit == "ft" else float(value))
    return values


def _check_depth(checked: CheckedEntry, domains) -> None:
    maxima = _depth_values(checked, "max_depth_m", domains)
    minima = _depth_values(checked, "min_depth_m", domains)
    if not maxima:
        if minima:
            checked.note("depth_spread", "a minimum depth with no maximum")
        return
    deepest, shallowest = max(maxima), min(maxima)
    spread = deepest - shallowest
    if spread > SPREAD_M and spread > SPREAD_SHARE * deepest:
        checked.note(
            "depth_spread",
            f"depth left out: counting pages say {shallowest:g} to {deepest:g} m",
        )
        return
    checked.max_depth = deepest
    if minima:
        checked.min_depth = min(minima)
        if checked.min_depth > deepest:
            checked.fail("depth_order", "the minimum depth is below the maximum")


def _check_facts(checked: CheckedEntry, domains) -> None:
    for key, vocabulary in FACTS.items():
        fact = checked.entry.get(key)
        if fact is None:
            continue
        values = fact.get("value") if isinstance(fact, dict) else None
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            checked.fail("shape", f"{key}.value is a list of names")
            continue
        unknown = [v for v in values if v not in vocabulary]
        if unknown:
            checked.fail("vocabulary", f"{key}: {', '.join(unknown)} not allowed")
            continue
        counting = _counting(_sources(fact), domains)
        if values and not any(not s.get("contradicts") for s in counting):
            checked.fail("fact_unsourced", f"{key}: no counting page states it")
            continue
        if any(s.get("contradicts") for s in counting):
            checked.note("fact_contradicted", f"{key} left out: a counting page disagrees")
            continue
        setattr(checked, "entries" if key == "entry" else key, list(values))


def check_entries(entries, domains, *, today: date) -> list[CheckedEntry]:
    """Every entry with what the rules made of it, in the given order."""
    results: list[CheckedEntry] = []
    ids: set[str] = set()
    for entry in entries:
        checked = CheckedEntry(entry if isinstance(entry, dict) else {})
        _check_shape(checked, ids, today)
        ids.add(checked.id)
        _check_domains(checked, domains)
        _check_position(checked, domains)
        _check_named(checked, domains)
        _check_depth(checked, domains)
        _check_facts(checked, domains)
        results.append(checked)
    _check_neighbours(results)
    return results


def _check_neighbours(results: list[CheckedEntry]) -> None:
    """Two standing entries within 150 m are one site written twice,
    unless one of them says why both stand."""
    standing = [
        r for r in results
        if r.position and not r.withdrawn and r.state != "rejected"
    ]
    for i, a in enumerate(standing):
        for b in standing[i + 1:]:
            if a.entry.get("note") or b.entry.get("note"):
                continue
            apart = evidence.metres_between(*a.position, *b.position)
            if apart <= AGREE_M:
                b.fail("neighbour", f"{apart:.0f} m from {a.id}; a note says why both stand")


def withdrawn_curated_problems(items) -> list[str]:
    """What is wrong with the file's `withdrawn_curated` list: an item
    that is not an object, an id that is not a curated one, a reason
    outside the list, or a date not written YYYY-MM-DD."""
    problems = []
    for item in items:
        if not isinstance(item, dict):
            problems.append(f"{item!r}: a curated withdrawal is an object")
            continue
        site_id = item.get("id")
        if not isinstance(site_id, str) or not site_id.startswith("curated_"):
            problems.append(f"{site_id!r}: only a curated id is withdrawn here")
        if item.get("reason") not in WITHDRAWAL_REASONS:
            problems.append(f"{site_id}: withdrawal reason {item.get('reason')!r}")
        if not is_iso_date(item.get("date")):
            problems.append(f"{site_id}: withdrawal date is not YYYY-MM-DD")
        if "replaced_by" in item and not _is_record_id(item["replaced_by"]):
            problems.append(f"{site_id}: replaced_by is a record id")
    return problems


def load(path: Path) -> dict:
    """The evidence document: its `sites` and `withdrawn_curated` lists."""
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    return {
        "sites": list(doc.get("sites") or []),
        "withdrawn_curated": list(doc.get("withdrawn_curated") or []),
    }


def report(results: list[CheckedEntry]) -> str:
    """What the rules made of a file, by area, then every finding."""
    lines = []
    areas: dict[str, list[CheckedEntry]] = {}
    for checked in results:
        areas.setdefault(str(checked.entry.get("area") or "(no area)"), []).append(checked)
    for area in sorted(areas):
        group = areas[area]
        states = {s: sum(1 for c in group if c.state == s) for s in REVIEW_STATES}
        failing = sum(1 for c in group if not c.ok)
        withdrawn = sum(1 for c in group if c.withdrawn)
        lines.append(
            f"{area}: {len(group)} entries, {failing} failing, "
            f"{states['pending']} pending, {states['approved']} approved, "
            f"{states['rejected']} rejected, {withdrawn} withdrawn"
        )
    for checked in results:
        for finding in checked.findings:
            mark = "FAIL" if finding.fatal else "note"
            lines.append(f"  {mark} {finding.entry_id} [{finding.rule}] {finding.message}")
    return "\n".join(lines) if lines else "No researched sites."


def main(argv=None, *, today: date | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--file", type=Path, default=SITES_FILE)
    parser.add_argument("--domains", type=Path, default=DOMAINS_FILE)
    parser.add_argument("--review", type=Path, default=None)
    args = parser.parse_args(argv)

    domains = evidence.load_domains(args.domains)
    doc = load(args.file)
    results = check_entries(doc["sites"], domains, today=today or date.today())
    print(report(results))
    curated_problems = withdrawn_curated_problems(doc["withdrawn_curated"])
    for problem in curated_problems:
        print(f"  FAIL withdrawn_curated {problem}")
    if args.review is not None:
        import review  # noqa: PLC0415

        args.review.write_text(review.render(results, domains), encoding="utf-8")
        print(f"Review page: {args.review}")
    return 0 if all(c.ok for c in results) and not curated_problems else 1


if __name__ == "__main__":
    sys.exit(main())
