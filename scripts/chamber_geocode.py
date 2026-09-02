#!/usr/bin/env python3
"""Forward geocoding for chamber leads, via OpenStreetMap Nominatim.

Registry pages publish addresses, not coordinates, but the emergency card sorts
by distance and the dataset validation requires a latitude and longitude on
every row. Results are cached on disk so re-running the harvester does not
re-query Nominatim for rows that already resolved.

Nominatim's usage policy allows at most one request per second and requires a
identifying user agent. Both are honoured here.
"""

import json
import os
import time
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_PATH = os.path.join(SCRIPT_DIR, ".chamber_geocode_cache.json")

ENDPOINT = "https://nominatim.openstreetmap.org/search"
USER_AGENT = "SubmersionChamberHarvester/1.0 (dive log app; chamber directory)"
MIN_INTERVAL = 1.1


class Geocoder:
    def __init__(self, cache_path=CACHE_PATH):
        self.cache_path = cache_path
        self.cache = {}
        self._last_request = 0.0
        if os.path.exists(cache_path):
            with open(cache_path, encoding="utf-8") as handle:
                self.cache = json.load(handle)

    def save(self):
        with open(self.cache_path, "w", encoding="utf-8") as handle:
            json.dump(self.cache, handle, indent=2, ensure_ascii=False, sort_keys=True)

    def _rate_limit(self):
        elapsed = time.time() - self._last_request
        if elapsed < MIN_INTERVAL:
            time.sleep(MIN_INTERVAL - elapsed)
        self._last_request = time.time()

    def lookup(self, query, country_code):
        """Return (latitude, longitude), or None when nothing matched."""
        key = f"{country_code}|{query}"
        if key in self.cache:
            hit = self.cache[key]
            return (hit["lat"], hit["lon"]) if hit else None

        self._rate_limit()
        params = urllib.parse.urlencode(
            {
                "q": query,
                "countrycodes": country_code.lower(),
                "format": "json",
                "limit": 1,
            }
        )
        request = urllib.request.Request(
            f"{ENDPOINT}?{params}", headers={"User-Agent": USER_AGENT}
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                results = json.load(response)
        except Exception as error:  # noqa: BLE001 - report and carry on
            print(f"  geocode failed for {query!r}: {error}")
            return None

        if not results:
            self.cache[key] = None
            return None

        lat = float(results[0]["lat"])
        lon = float(results[0]["lon"])
        self.cache[key] = {"lat": lat, "lon": lon}
        return (lat, lon)


MANUAL_PATH = os.path.join(SCRIPT_DIR, "data", "chamber_coordinates.json")


def load_manual_coordinates():
    """Hand-recorded coordinates, keyed by chamber id.

    Nominatim cannot find a resort island clinic or a hospital department by
    name, and a chamber the card cannot place is a chamber it cannot rank, so
    it would otherwise be dropped. This file is the escape hatch, seeded with
    the coordinates the placeholder dataset already shipped.
    """
    if not os.path.exists(MANUAL_PATH):
        return {}
    with open(MANUAL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def geocode_rows(rows, geocoder=None):
    """Fill latitude and longitude on rows that lack them.

    Order of preference: coordinates already on the row, then the hand-recorded
    file, then Nominatim with the most specific query (facility name plus
    city), then the city alone, which still puts the chamber in the right town
    for distance sorting.

    Rows that resolve to none of these are reported by name so they can be
    added to the manual file, rather than disappearing quietly.
    """
    geocoder = geocoder or Geocoder()
    manual = load_manual_coordinates()
    resolved = 0
    unplaced = []

    for row in rows:
        if row.get("latitude") is not None and row.get("longitude") is not None:
            continue

        hit = manual.get(row["id"])
        if hit:
            row["latitude"], row["longitude"] = hit["lat"], hit["lon"]
            resolved += 1
            continue

        attempts = []
        if row.get("city"):
            attempts.append(f"{row['name']}, {row['city']}")
            attempts.append(row["city"])
        else:
            attempts.append(row["name"])

        for query in attempts:
            point = geocoder.lookup(query, row["country"])
            if point:
                row["latitude"], row["longitude"] = point
                resolved += 1
                break
        else:
            unplaced.append(row)

    geocoder.save()
    print(f"Geocoded {resolved} rows")
    if unplaced:
        print(f"Could not place {len(unplaced)} rows; add them to {MANUAL_PATH}:")
        for row in unplaced:
            print(f"  {row['id']}: {row['name']} ({row.get('city')}, {row['country']})")
    return rows
