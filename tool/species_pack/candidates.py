#!/usr/bin/env python3
"""The pack's candidate list: every built-in catalogue species with its own
GBIF key, then the species GBIF has the most photographed observations of
within the catalogue's higher taxa, then the species divers record most in
shallow surveys there, photographed or not.

Network access is only in `_get_json` and the `fetch_*` functions that call
it; candidates_test.py tests the rest, and the facet queries with GBIF
replaced by a stub.
"""

import hashlib
import itertools
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "species-pack-builder/0.1 (+https://github.com/submersion-app/submersion)"
API = "https://api.gbif.org/v1"

# Mirrors lib/features/marine_life/domain/services/species_category_mapper.dart,
# adapted to the GBIF backbone: it gives ray-finned fish no class, and puts
# turtles and snakes in classes of their own.
_BATOID_ORDERS = {"Rajiformes", "Myliobatiformes", "Torpediniformes", "Rhinopristiformes"}
_CARTILAGINOUS = {"Elasmobranchii", "Holocephali", "Chondrichthyes"}
_FISH_CLASSES = {None, "Actinopterygii", "Sarcopterygii", "Petromyzonti", "Myxini", "Cephalaspidomorphi"}
_OTHER_CLASSES = {"Aves", "Squamata", "Crocodylia", "Reptilia", "Amphibia"}


def category_for(taxon):
    """The app's species category for a GBIF species record."""
    kingdom = taxon.get("kingdom")
    phylum = taxon.get("phylum")
    klass = taxon.get("class")
    order = taxon.get("order")
    if klass in _CARTILAGINOUS:
        return "ray" if order in _BATOID_ORDERS else "shark"
    if klass == "Mammalia":
        return "mammal"
    if klass == "Testudines" or order == "Testudines":
        return "turtle"
    if klass == "Anthozoa":
        return "invertebrate" if order == "Actiniaria" else "coral"
    if kingdom in ("Plantae", "Chromista"):
        return "plant"
    if klass in _OTHER_CLASSES:
        return "other"
    if phylum == "Chordata":
        return "fish" if klass in _FISH_CLASSES else "invertebrate"
    if kingdom == "Animalia":
        return "invertebrate"
    return "other"


def catalogue_candidates(catalogue, species_keys):
    """One candidate per GBIF key for the catalogue species that have one,
    in catalogue order. `species_keys` maps key (as text) to catalogue id,
    as assets/data/species_gbif_keys.json does: one species per key."""
    key_of = {sid: int(key) for key, sid in species_keys.items()}
    rows = []
    seen = set()
    for species in catalogue:
        key = key_of.get(species["id"])
        if key is None or key in seen or not species.get("scientificName"):
            continue
        seen.add(key)
        rows.append(
            {
                "gbifKey": key,
                "scientificName": species["scientificName"],
                "commonName": species["commonName"],
                "category": species["category"],
                "catalogId": species["id"],
            }
        )
    return rows


# Candidates are widened only within the orders of these catalogue
# categories: every fish, shark and ray order is aquatic, and so are nearly
# all the coral and invertebrate orders divers meet. Mammals, turtles,
# reptiles, amphibians and plants stay as the catalogue has them: their
# orders hold far more land species than water ones (a hippo's order holds
# every deer), and GBIF's most photographed would be the land ones.
EXPANDABLE = {"fish", "shark", "ray", "coral", "invertebrate"}

# Invertebrate orders whose photographed species are mostly on land.
LAND_ORDERS = {
    "Stylommatophora", "Isopoda", "Araneae", "Coleoptera", "Lepidoptera",
    "Hymenoptera", "Diptera", "Hemiptera", "Odonata", "Orthoptera",
}


def expansion_order_keys(records):
    """The GBIF order keys to widen the candidate list within, from
    (catalogue category, GBIF species record) pairs."""
    return {
        record["orderKey"]
        for category, record in records
        if category in EXPANDABLE
        and record.get("orderKey") is not None
        and record.get("order") not in LAND_ORDERS
    }


def _get_json(url, cache_path):
    if cache_path and os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8") as fh:
            return json.load(fh)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = json.load(response)
            break
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == 5:
                raise
            time.sleep(2 ** attempt)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 5:
                raise
            time.sleep(2 ** attempt)
    if cache_path:
        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
        with open(cache_path, "w", encoding="utf-8") as fh:
            json.dump(data, fh)
    return data


# Photographed human observations: mostly iNaturalist, so every one is a
# sighting.
PHOTO_FILTERS = [("media_type", "StillImage"), ("basis_of_record", "HUMAN_OBSERVATION")]

# Human observations from dive surveys, photographed or not. Reef visual
# census programmes record species divers see often but rarely photograph
# (Creole Wrasse). Monitoring programmes also publish a row for every
# species not seen on a survey, so only sightings count. Fishery catches and
# deep ROV surveys log millions of records below diving depth, so only
# records from 0 to 40 m count; records without a depth do not.
SURVEY_FILTERS = [
    ("basis_of_record", "HUMAN_OBSERVATION"),
    ("occurrence_status", "PRESENT"),
    ("depth", "0,40"),
]


def facet_cache_path(work, route, taxon_keys, filters, min_count, limit):
    """Where a species facet is cached. The name says which taxa and filters
    were asked about, and the floor and limit, so a changed query cannot be
    answered from an earlier one's cache. Earlier builds paged the photo
    facet into `species_*` files; this name never matches one."""
    taxa = ",".join(str(k) for k in sorted(taxon_keys))
    query = taxa + "|" + "&".join(f"{k}={v}" for k, v in filters)
    digest = hashlib.sha256(query.encode()).hexdigest()[:12]
    return os.path.join(work, "facets", f"{route}_{digest}_{min_count}_{limit}.json")


def _species_facet(taxon_keys, work, route, filters, min_count, limit):
    """(speciesKey, count) for species with at least `min_count` occurrences
    matching `filters` under any of `taxon_keys`, most first.

    One request for the whole facet: GBIF's facet paging (facetOffset)
    repeats species at page boundaries and skips others, which dropped 157
    photographed species from a 1,000-a-page build."""
    params = [("taxon_key", str(k)) for k in taxon_keys] + filters + [
        ("limit", "0"),
        ("facet", "speciesKey"),
        ("facetMincount", str(min_count)),
        ("facetLimit", str(limit)),
    ]
    data = _get_json(
        f"{API}/occurrence/search?{urllib.parse.urlencode(params)}",
        facet_cache_path(work, route, taxon_keys, filters, min_count, limit),
    )
    counts = (data.get("facets") or [{}])[0].get("counts", [])
    if len(counts) >= limit:
        print(
            f"warning: GBIF returned {len(counts)} {route} species, the limit; "
            "species beyond it are missing, so raise the limit",
            file=sys.stderr,
        )
    return [(int(c["name"]), int(c["count"])) for c in counts]


def fetch_photographed_species(taxon_keys, work, *, min_images, limit=20000):
    """(speciesKey, count) for species with at least `min_images` photographed
    human observations under any of `taxon_keys`, most photographed first."""
    return _species_facet(taxon_keys, work, "photographed", PHOTO_FILTERS, min_images, limit)


def fetch_surveyed_species(taxon_keys, work, *, min_records, limit=20000):
    """(speciesKey, count) for species with at least `min_records` present
    human observations at 0 to 40 m under any of `taxon_keys`, most recorded
    first."""
    return _species_facet(taxon_keys, work, "surveyed", SURVEY_FILTERS, min_records, limit)


def wanted_keys(photographed, surveyed, have, room):
    """The species keys to add to a list that already holds `have`, at most
    `room` of them: the photographed ones in their order, then the surveyed
    ones not already chosen, in theirs. `photographed` and `surveyed` are
    (key, count) pairs, most first. When the room runs out, survey-only
    species are the ones left out."""
    chosen = []
    seen = set(have)
    for key, _ in itertools.chain(photographed, surveyed):
        if len(chosen) >= room:
            break
        if key not in seen:
            seen.add(key)
            chosen.append(key)
    return chosen


def fetch_species(key, work):
    """The GBIF species record, with an English common name when GBIF has one."""
    record = _get_json(f"{API}/species/{key}", os.path.join(work, "species", f"{key}.json"))
    if not record.get("vernacularName"):
        names = _get_json(
            f"{API}/species/{key}/vernacularNames?limit=100",
            os.path.join(work, "vernacular", f"{key}.json"),
        )
        for entry in names.get("results", []):
            if entry.get("language") == "eng" and entry.get("vernacularName"):
                record = {**record, "vernacularName": entry["vernacularName"]}
                break
    return record


def _english_name(record):
    name = (record.get("vernacularName") or "").split(",")[0].strip()
    if not name:
        return record.get("canonicalName") or record.get("scientificName")
    return name[0].upper() + name[1:]


def gbif_candidate(record):
    """A candidate from a GBIF species record, or None if it cannot be one."""
    if record.get("rank") != "SPECIES" or record.get("taxonomicStatus") not in ("ACCEPTED", None):
        return None
    name = record.get("canonicalName")
    if not name:
        return None
    return {
        "gbifKey": int(record["key"]),
        "scientificName": name,
        "commonName": _english_name(record),
        "category": category_for(record),
    }
