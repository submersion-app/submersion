#!/usr/bin/env python3
"""Wikidata: dive sites and notable wrecks. CC0.

Wikidata holds a few hundred items classed as dive sites, which are dive
site records, and tens of thousands of wrecks. Most of the wrecks were
imported from loss registers and are positioned to a minute of arc at
best, so a wreck passes only with a Wikipedia article (it is notable) and
a position finer than a minute.

Run this file to download both into the snapshot cache.
"""

import collections
import json
import os
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import records as rec  # noqa: E402
from snapshots import http_get, write_snapshot  # noqa: E402

KEY_SITES = "wikidata_sites"
KEY_WRECKS = "wikidata_wrecks"
SPARQL_URL = "https://query.wikidata.org/sparql"

_EARTH = "http://www.wikidata.org/entity/Q2"
# One minute of arc, the coarsest position a wreck may not have.
_ARC_MINUTE = 1 / 60

# Each item's coordinate with the precision and globe Wikidata records for
# it, and its English label.
_POSITION = """
  ?item p:P625 ?statement . ?statement psv:P625 ?node .
  ?node wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon ;
        wikibase:geoGlobe ?globe .
  OPTIONAL { ?node wikibase:geoPrecision ?precision }
  OPTIONAL { ?item rdfs:label ?label FILTER(LANG(?label) = "en") }
}"""
_SELECT = "SELECT DISTINCT ?item ?label ?lat ?lon ?precision ?globe WHERE {"
# The items of a set that have a Wikipedia article in any language. The
# optimizer is told to keep the order written: left to itself it starts
# from every Wikipedia article there is and times out.
_ARTICLES = """SELECT DISTINCT ?item WHERE {
  hint:Query hint:optimizer "None" .
  %s
  ?item wdt:P625 [] .
  ?article schema:about ?item .
  ?article schema:isPartOf ?wiki .
  ?wiki wikibase:wikiGroup "wikipedia" .
}"""

# Shipwrecks (Q852190), and ships whose significant event (P793) is a
# shipwrecking (Q906512) or a scuttling (Q1786766).
_WRECK_SETS = (
    "?item wdt:P31 wd:Q852190 .",
    "VALUES ?event { wd:Q906512 wd:Q1786766 } ?item wdt:P793 ?event .",
)

# Instances of "underwater diving site" (Q26205080) and its subclasses.
SITE_QUERY = _SELECT + " ?item wdt:P31/wdt:P279* wd:Q26205080 ." + _POSITION
# Positions and articles are asked for separately and joined here: in one
# query the service times out.
WRECK_POSITION_QUERIES = tuple(
    _SELECT + " " + wrecks + _POSITION for wrecks in _WRECK_SETS
)
WRECK_ARTICLE_QUERIES = tuple(_ARTICLES % wrecks for wrecks in _WRECK_SETS)


def rows_from_bindings(bindings: list[dict]) -> list[dict]:
    """One row per item from a SPARQL answer. An item with more than one
    coordinate keeps the most precisely stated one."""

    def value(binding, key):
        return (binding.get(key) or {}).get("value")

    rows: dict[str, dict] = {}
    for binding in bindings:
        item = value(binding, "item").rsplit("/", 1)[-1]
        row = dict(
            item=item,
            label=value(binding, "label"),
            lat=rec.number(value(binding, "lat")),
            lon=rec.number(value(binding, "lon")),
            precision=rec.number(value(binding, "precision")),
            globe=value(binding, "globe"),
        )
        held = rows.get(item)
        if held is None or (row["precision"] or 1e9) < (held["precision"] or 1e9):
            rows[item] = row
    return list(rows.values())


def with_article(rows: list[dict], article_bindings: list[dict]) -> list[dict]:
    """The [rows] whose item has a Wikipedia article: it is in the answer
    to an article query."""
    notable = {
        binding["item"]["value"].rsplit("/", 1)[-1]
        for binding in article_bindings
    }
    return [row for row in rows if row["item"] in notable]


def _whole_minutes(value: float) -> bool:
    minutes = abs(value) * 60
    return abs(minutes - round(minutes)) < 2e-4


def _coarse(row: dict) -> bool:
    """Whether a position is good to a minute of arc at best: Wikidata
    says so, or both coordinates are written in whole minutes."""
    precision = row.get("precision")
    if precision is not None and precision >= _ARC_MINUTE - 1e-6:
        return True
    return _whole_minutes(row["lat"]) and _whole_minutes(row["lon"])


def _records(rows, *, kind: str, types, gate) -> tuple[list, collections.Counter]:
    kept, dropped = [], collections.Counter()
    for row in rows:
        label = (row.get("label") or "").strip()
        if not label or label == row["item"]:
            dropped["no_label"] += 1
            continue
        if row.get("globe") != _EARTH or row.get("lat") is None or row.get("lon") is None:
            dropped["not_on_earth"] += 1
            continue
        if gate and _coarse(row):
            dropped["coarse_position"] += 1
            continue
        kept.append(
            rec.working(
                id=f"wikidata_{row['item']}",
                name=label,
                lat=row["lat"],
                lon=row["lon"],
                source="wikidata",
                kind=kind,
                source_ref=f"https://www.wikidata.org/wiki/{row['item']}",
                types=types,
            )
        )
    return kept, dropped


def site_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """Wikidata's dive sites, as dive site records."""
    return _records(rows, kind="site", types=[], gate=False)


def wreck_records(rows: list[dict]) -> tuple[list[dict], collections.Counter]:
    """Notable wrecks with a position finer than a minute of arc, as
    register records. The snapshot holds only wrecks with a Wikipedia
    article: the query asks for no others."""
    return _records(rows, kind="register", types=["wreck"], gate=True)


def _query(sparql: str) -> list[dict]:
    """The bindings of one query. The service at times allows one request
    a minute; a refusal is retried once after that wait."""

    def ask():
        return http_get(
            SPARQL_URL, params={"query": sparql, "format": "json"}, timeout=300
        )

    try:
        body = ask()
    except RuntimeError as error:
        if "429" not in str(error):
            raise
        time.sleep(66)
        body = ask()
    return json.loads(body)["results"]["bindings"]


def fetch():
    """Downloads the dive sites and the notable wrecks. Five queries, a
    little over a minute apart."""
    sites = rows_from_bindings(_query(SITE_QUERY))
    paths = [write_snapshot(KEY_SITES, SPARQL_URL, sites)]
    positions: list[dict] = []
    articles: list[dict] = []
    for query in WRECK_POSITION_QUERIES:
        time.sleep(66)
        positions.extend(_query(query))
    for query in WRECK_ARTICLE_QUERIES:
        time.sleep(66)
        articles.extend(_query(query))
    wrecks = with_article(rows_from_bindings(positions), articles)
    paths.append(write_snapshot(KEY_WRECKS, SPARQL_URL, wrecks))
    return paths


if __name__ == "__main__":
    print(fetch())
