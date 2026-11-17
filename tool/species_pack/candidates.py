#!/usr/bin/env python3
"""The pack's candidate list: every built-in catalogue species with its own
GBIF key, then the species GBIF has the most photographed observations of
within the catalogue's higher taxa.

Network access is only in the `fetch_*` functions; the rest is pure and
tested by manifest_test.py.
"""

import hashlib
import json
import os
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


def fetch_photographed_species(taxon_keys, work, *, min_images, page=1000, limit=20000):
    """(speciesKey, count) for species with at least `min_images` photographed
    human observations under any of `taxon_keys`, most photographed first."""
    params = [("taxon_key", str(k)) for k in taxon_keys] + [
        ("media_type", "StillImage"),
        ("basis_of_record", "HUMAN_OBSERVATION"),
        ("limit", "0"),
        ("facet", "speciesKey"),
        ("facetMincount", str(min_images)),
        ("facetLimit", str(page)),
    ]
    # The cache name says which taxa were asked about, so a changed list
    # cannot be answered from an earlier query's cache.
    query_id = hashlib.sha256(",".join(str(k) for k in sorted(taxon_keys)).encode()).hexdigest()[:12]
    found = []
    offset = 0
    while offset < limit:
        query = urllib.parse.urlencode(params + [("facetOffset", str(offset))])
        data = _get_json(
            f"{API}/occurrence/search?{query}",
            os.path.join(work, "facets", f"species_{query_id}_{min_images}_{offset}.json"),
        )
        counts = (data.get("facets") or [{}])[0].get("counts", [])
        found.extend((int(c["name"]), int(c["count"])) for c in counts)
        if len(counts) < page:
            break
        offset += page
    return found


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
