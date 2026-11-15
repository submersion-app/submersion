#!/usr/bin/env python3
"""Researched dive sites, read from the evidence file for the merge.

Unlike the registers, researched sites are not downloaded. They are
written by hand, one entry per site, in `research/sites.json`, each fact
with the pages behind it, and checked by `research/check.py`. This module
turns every entry that passes those rules, that the maintainer approved
and that has not been withdrawn into a working record for the merge, and
gathers the withdrawals the catalogue lists.

A researched record carries no wording from any page: its description is
one line built here from its own entry and site type, and its hazards are
sentences of ours (research/evidence.py). Depth is left out of the line;
the record's depth fields carry it, in the diver's own units.
"""

import os
import sys
from collections import Counter
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
_RESEARCH = os.path.join(_HERE, "research")
for _path in (_HERE, _RESEARCH, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import check  # noqa: E402
import evidence  # noqa: E402
import records as rec  # noqa: E402
from site_catalogue_format import WITHDRAWAL_REASONS, is_iso_date  # noqa: E402

RESEARCH_FILE = Path(_RESEARCH) / "sites.json"
DOMAINS_FILE = Path(_RESEARCH) / "domains.json"
SOURCE = "research"
_REPOSITORY_FILE = (
    "https://github.com/submersion-app/submersion/blob/main/"
    "scripts/site_catalogue/research/sites.json"
)

# How a site type reads after an entry ("Shore dive to a wreck") and on
# its own ("Wreck dive"). A type not listed reads "on a <type> site".
_AFTER_ENTRY = {
    "wreck": "to a wreck",
    "wall": "on a wall",
    "reef": "on a reef",
    "artificial_reef": "on an artificial reef",
    "cave": "into a cave",
    "cavern": "into a cavern",
    "cenote": "into a cenote",
    "blue_hole": "into a blue hole",
    "pier": "under a pier",
    "kelp_forest": "in a kelp forest",
}
_ENTRY_WORDS = {"shore": "Shore", "boat": "Boat"}


@dataclass
class ResearchBatch:
    """What the evidence file gives the merge: the working records that
    ship, the withdrawals the catalogue lists, and the counts the report
    prints."""

    records: list = field(default_factory=list)
    withdrawn: dict = field(default_factory=dict)
    counts: dict = field(default_factory=dict)
    read: int = 0


def source_ref(entry_id: str) -> str:
    """The address of an entry's evidence in the public repository; the
    text fragment takes a browser to the entry."""
    return f"{_REPOSITORY_FILE}#:~:text={entry_id}"


def describe(entries, types) -> str | None:
    """The one line a researched record carries as its description, in
    our words, from its entry methods and site types; None when neither
    says anything."""
    mode = next((_ENTRY_WORDS[e] for e in entries if e in _ENTRY_WORDS), None)
    kind = types[0] if types else None
    if mode and kind:
        phrase = _AFTER_ENTRY.get(kind, f"on a {kind.replace('_', ' ')} site")
        return f"{mode} dive {phrase}."
    if mode:
        return f"{mode} dive."
    if kind:
        return f"{kind.replace('_', ' ').capitalize()} dive."
    return None


def working_record(
    site_id: str,
    name: str,
    lat: float,
    lon: float,
    *,
    country_hint: str,
    types=(),
    entry_type: str | None = None,
    max_depth: float | None = None,
    min_depth: float | None = None,
    hazards: str | None = None,
    description: str | None = None,
) -> dict:
    """A researched site as the merge's working record. [country_hint] is
    the researcher's country code, which the merge checks against its
    own lookup."""
    record = rec.working(
        id=site_id,
        name=name,
        lat=lat,
        lon=lon,
        source=SOURCE,
        kind="site",
        source_ref=source_ref(site_id),
        types=list(types),
        max_depth=max_depth,
        min_depth=min_depth,
        description=description,
        hazards=hazards,
        entry_type=entry_type,
    )
    record["country_hint"] = country_hint
    return record


def records(entries, domains, *, today: date) -> tuple[list[dict], Counter]:
    """The working records of every approved, sound, unwithdrawn entry,
    and a count of the rest by why they do not ship."""
    counts: Counter = Counter()
    formed = []
    for checked in check.check_entries(entries, domains, today=today):
        if checked.withdrawn:
            counts["withdrawn"] += 1
        elif not checked.ok:
            counts["failed"] += 1
        elif checked.state != "approved":
            counts[checked.state] += 1
        else:
            counts["approved"] += 1
            entry = checked.entry
            formed.append(
                working_record(
                    entry["id"],
                    entry["name"].strip(),
                    *checked.position,
                    country_hint=entry["country_code"],
                    types=checked.types,
                    entry_type=", ".join(checked.entries) or None,
                    max_depth=checked.max_depth,
                    min_depth=checked.min_depth,
                    hazards=evidence.hazards_text(checked.hazards),
                    description=describe(checked.entries, checked.types),
                )
            )
    return formed, counts


def withdrawals(entries, curated_withdrawn) -> dict[str, dict]:
    """Every withdrawal the catalogue lists: researched entries marked
    withdrawn, and curated records named in `withdrawn_curated`. Raises
    ValueError for a curated withdrawal that is not well formed."""
    found: dict[str, dict] = {}
    for entry in entries:
        withdrawn = entry.get("withdrawn")
        if withdrawn:
            found[entry["id"]] = {
                key: withdrawn[key]
                for key in ("reason", "date", "replaced_by")
                if withdrawn.get(key)
            }
    for item in curated_withdrawn:
        site_id = item.get("id") or ""
        if not site_id.startswith("curated_"):
            raise ValueError(f"{site_id!r}: only a curated id is withdrawn here")
        if item.get("reason") not in WITHDRAWAL_REASONS or not is_iso_date(
            item.get("date")
        ):
            raise ValueError(
                f"{site_id}: a withdrawal needs a reason and a YYYY-MM-DD date"
            )
        found[site_id] = {
            key: item[key] for key in ("reason", "date", "replaced_by") if item.get(key)
        }
    return _follow_replacements(found)


def _follow_replacements(found: dict[str, dict]) -> dict[str, dict]:
    """[found] with each replacement followed to the record that still
    ships: when B replaced A and was later replaced by C, A points at C.
    Raises ValueError for a loop."""
    followed = {}
    for site_id, withdrawal in found.items():
        target, seen = withdrawal.get("replaced_by"), {site_id}
        while target in found and found[target].get("replaced_by"):
            if target in seen:
                raise ValueError(f"{site_id}: its replacements loop back on it")
            seen.add(target)
            target = found[target]["replaced_by"]
        if target in seen:
            raise ValueError(f"{site_id}: its replacements loop back on it")
        followed[site_id] = (
            dict(withdrawal, replaced_by=target) if target else dict(withdrawal)
        )
    return followed


def load_batch(
    path: Path = RESEARCH_FILE,
    domains_path: Path = DOMAINS_FILE,
    *,
    today: date | None = None,
) -> ResearchBatch:
    """The evidence file as the merge takes it."""
    doc = check.load(path)
    domains = evidence.load_domains(domains_path)
    formed, counts = records(doc["sites"], domains, today=today or date.today())
    return ResearchBatch(
        records=formed,
        withdrawn=withdrawals(doc["sites"], doc["withdrawn_curated"]),
        counts=dict(counts),
        read=len(doc["sites"]),
    )
