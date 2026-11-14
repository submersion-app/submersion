#!/usr/bin/env python3
"""Where a catalogue record is: country, territory, region, island, lake.

A register wreck lies at sea, where a geocoder answers nothing, and there
are tens of thousands of them. So the catalogue places its records against
Natural Earth's 1:10m boundaries (public domain), held offline: a point
inside a unit takes that unit, a point at sea takes the nearest land within
370 km (200 nautical miles), and farther out it has no country.

A territory with its own ISO 3166-1 code keeps that code (a reef off
Puerto Rico is PR, not US), as the catalogue already does for the
Caribbean Netherlands.

OpenStreetMap dive sites keep the geocoder's answer, which knows real
borders the coarse boundaries blur; `Places.settle` corrects it only where
the point lies in a territory the geocoder filed under its parent state.

Standard library only, so the tests run in CI with no packages.
"""

import json
import math
import os
import re
import sys
from collections import Counter, namedtuple
from pathlib import Path

_HERE = os.path.dirname(os.path.abspath(__file__))
_SCRIPTS = os.path.dirname(_HERE)
for _path in (_HERE, _SCRIPTS, os.path.join(_SCRIPTS, "geography")):
    if _path not in sys.path:
        sys.path.insert(0, _path)

from generate_country_names import fold as fold_country  # noqa: E402
from records import km  # noqa: E402
from site_country_resolver import (  # noqa: E402
    NAME_OVERRIDES,
    SUBDIVISION_ISLANDS,
)
from snapshots import CACHE_DIR, http_get  # noqa: E402

_REPO = Path(_SCRIPTS).parent

NATURAL_EARTH_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/"
    "geojson/"
)
UNITS_FILE = "ne_10m_admin_0_map_subunits.geojson"
REGIONS_FILE = "ne_10m_admin_1_states_provinces.geojson"
LAKES_FILE = "ne_10m_lakes.geojson"

# How far out to sea a record still belongs to the nearest land: 200
# nautical miles, the reach of an exclusive economic zone.
MAX_SEA_KM = 370.0
# How far from a first-level unit a record still takes its name.
MAX_REGION_KM = 50.0
# How far off a territory's shore an OpenStreetMap dive site still counts
# as in it, when the geocoder filed the site under the parent state.
TERRITORY_REACH_KM = 25.0
# How far inside a country, and from any lake, a point must be before it is
# called dry land. The boundaries are drawn at 1:10m: a harbour, an estuary
# or a bay falls on the wrong side of them by a few kilometres.
DRY_LAND_KM = 5.0

# Natural Earth's own subdivision codes for the islands the catalogue
# names (ISO writes these BQ-BO, BQ-SA, BQ-SE).
_NE_ISLAND_CODES = {"NL-BQ1": "BQ-BO", "NL-BQ2": "BQ-SA", "NL-BQ3": "BQ-SE"}

# Units Natural Earth gives no ISO code, by their `SU_A3`, where ISO 3166
# files them under a state other than the one Natural Earth draws them in.
UNIT_CODE_OVERRIDES = {
    "RUC": "UA",  # Crimea: ISO 3166-2 UA-43.
    "CYN": "CY",  # Northern Cyprus.
    "SOL": "SO",  # Somaliland.
}

Place = namedtuple("Place", "country_code country region island fresh at_sea")

_KM_PER_DEGREE = 111.19
# No edge of the boundaries is left longer than this many degrees, so the
# nearest vertex stands in for the nearest point of the coast.
_MAX_EDGE_DEGREES = 0.05
# A polygon whose box covers more cells than this is checked for every
# point instead of being filed under each cell.
_MAX_INDEXED_CELLS = 400


def _cell(lat: float, lon: float) -> tuple[int, int]:
    return (
        min(179, max(0, int(math.floor(lat)) + 90)),
        int(math.floor(lon) + 180) % 360,
    )


def _in_ring(ring, lat: float, lon: float) -> bool:
    """Crossing number: whether (lat, lon) is inside [ring] ([lon, lat]
    pairs)."""
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (
            yj - yi
        ) + xi:
            inside = not inside
        j = i
    return inside


def _box(ring) -> tuple[float, float, float, float]:
    lons = [point[0] for point in ring]
    lats = [point[1] for point in ring]
    return min(lats), min(lons), max(lats), max(lons)


class UnitIndex:
    """GeoJSON polygons, answering "which contains this point" and "which
    is nearest it"."""

    def __init__(self, features: list[dict]):
        self._properties = [feature.get("properties") or {} for feature in features]
        # (feature index, outer ring, holes, box)
        self._polygons: list[tuple] = []
        self._by_cell: dict[tuple[int, int], list[int]] = {}
        self._everywhere: list[int] = []
        self._vertices: dict[tuple[int, int], list[tuple]] = {}
        for index, feature in enumerate(features):
            geometry = feature.get("geometry") or {}
            if geometry.get("type") == "Polygon":
                polygons = [geometry["coordinates"]]
            elif geometry.get("type") == "MultiPolygon":
                polygons = geometry["coordinates"]
            else:
                continue
            for rings in polygons:
                if not rings or len(rings[0]) < 3:
                    continue
                self._add(index, rings[0], rings[1:])

    def _add(self, index: int, outer, holes) -> None:
        box = _box(outer)
        polygon = len(self._polygons)
        self._polygons.append((index, outer, holes, box))
        south, west, north, east = box
        rows = range(_cell(south, 0)[0], _cell(north, 0)[0] + 1)
        columns = range(int(math.floor(west)), int(math.floor(east)) + 1)
        if len(rows) * len(columns) > _MAX_INDEXED_CELLS:
            self._everywhere.append(polygon)
        else:
            for row in rows:
                for column in columns:
                    self._by_cell.setdefault(
                        (row, (column + 180) % 360), []
                    ).append(polygon)
        previous = None
        for point in outer:
            lon, lat = point[0], point[1]
            if previous is not None:
                steps = int(
                    max(abs(lat - previous[1]), abs(lon - previous[0]))
                    / _MAX_EDGE_DEGREES
                )
                for step in range(1, steps + 1):
                    t = step / (steps + 1)
                    self._vertex(
                        previous[1] + (lat - previous[1]) * t,
                        previous[0] + (lon - previous[0]) * t,
                        index,
                    )
            self._vertex(lat, lon, index)
            previous = (lon, lat)

    def _vertex(self, lat: float, lon: float, index: int) -> None:
        self._vertices.setdefault(_cell(lat, lon), []).append((lat, lon, index))

    def containing(self, lat: float, lon: float) -> dict | None:
        """The properties of the unit (lat, lon) lies in, or None."""
        candidates = self._by_cell.get(_cell(lat, lon), [])
        for polygon in list(candidates) + self._everywhere:
            index, outer, holes, (south, west, north, east) = self._polygons[polygon]
            if not (south <= lat <= north and west <= lon <= east):
                continue
            if _in_ring(outer, lat, lon) and not any(
                _in_ring(hole, lat, lon) for hole in holes
            ):
                return self._properties[index]
        return None

    def nearest(
        self, lat: float, lon: float, max_km: float
    ) -> tuple[dict, float] | None:
        """(properties, kilometres) of the unit nearest (lat, lon), or
        None when none lies within [max_km].

        Searches the cells around the point ring by ring. Every vertex not
        yet seen after ring r is more than r degrees away, so the search
        stops once the best distance is inside that.
        """
        rings = int(math.ceil(max_km / _KM_PER_DEGREE)) + 1
        row, column = _cell(lat, lon)
        # A degree of longitude shrinks towards the poles: widen the rings
        # by the factor at the poleward edge of the search.
        poleward = min(89.9, abs(lat) + rings)
        widen = int(math.ceil(1 / max(math.cos(math.radians(poleward)), 1 / 180)))
        best = None
        for ring in range(rings + 1):
            span = min(180, ring * widen)
            for d_row in range(-ring, ring + 1):
                r = row + d_row
                if not 0 <= r <= 179:
                    continue
                edge_row = abs(d_row) == ring
                previous_span = min(180, (ring - 1) * widen) if ring else -1
                for d_column in range(-span, span + 1):
                    if not edge_row and abs(d_column) <= previous_span:
                        continue
                    for v_lat, v_lon, index in self._vertices.get(
                        (r, (column + d_column) % 360), ()
                    ):
                        distance = km(lat, lon, v_lat, v_lon)
                        if best is None or distance < best[1]:
                            best = (index, distance)
                    if span == 180 and d_column == span - 1:
                        break
            if best is not None and best[1] <= ring * _KM_PER_DEGREE:
                break
        if best is None or best[1] > max_km:
            return None
        return self._properties[best[0]], best[1]


def _is_latin(text: str) -> bool:
    return all(ord(char) < 0x250 or 0x1E00 <= ord(char) < 0x2070 for char in text)


def region_name(properties: dict | None) -> str | None:
    """A first-level unit's English name, or None when Natural Earth has it
    only in a script most divers cannot read."""
    if not properties:
        return None
    for key in ("name_en", "name"):
        value = (properties.get(key) or "").strip()
        if value and _is_latin(value):
            return value
    return None


def english_name(code: str, candidates, known: dict[str, str]) -> str:
    """The English country name the catalogue writes for [code].

    The app must read the name back as the same code (its flag and its
    country text would disagree otherwise), so the first of [candidates]
    its table resolves to [code] wins. Raises ValueError naming the code
    when none does: add a NAME_OVERRIDES entry in site_country_resolver.
    """
    if code in NAME_OVERRIDES:
        return NAME_OVERRIDES[code]
    for candidate in candidates:
        if candidate and known.get(fold_country(candidate)) == code:
            return candidate
    raise ValueError(
        f"No English name the app reads back as {code}: tried "
        + ", ".join(repr(candidate) for candidate in candidates if candidate)
    )


def preferred_country_names(answers, known: dict[str, str]) -> dict[str, str]:
    """The name the catalogue already uses for each country: the commonest
    one among the geocoder's (code, name, island) [answers] that the app
    reads back as that code. A register record of the same country then
    says it the same way."""
    counts: dict[str, Counter] = {}
    for answer in answers:
        code, name = (list(answer or ()) + [None, None])[:2]
        if code and name and known.get(fold_country(name)) == code:
            counts.setdefault(code, Counter())[name] += 1
    return {code: count.most_common(1)[0][0] for code, count in counts.items()}


def known_country_names() -> dict[str, str]:
    """Folded country name to ISO code, as the app resolves them: the
    generated CLDR table plus the aliases in country_code.dart."""
    known: dict[str, str] = {}
    entry = re.compile(r"'((?:[^'\\]|\\.)*)':\s*'([A-Z]{2})'")
    generated = (
        _REPO / "lib" / "core" / "geography" / "country_names.generated.dart"
    ).read_text(encoding="utf-8")
    for name, code in entry.findall(generated):
        known[name.replace("\\'", "'")] = code
    aliases = (
        _REPO / "lib" / "core" / "geography" / "country_code.dart"
    ).read_text(encoding="utf-8")
    block = aliases.split("_aliasNames = {", 1)[1].split("};", 1)[0]
    for name, code in entry.findall(block):
        known.setdefault(fold_country(name.replace("\\'", "'")), code)
    return known


class Places:
    """Country, region, island and lake for a position."""

    def __init__(
        self,
        units: UnitIndex,
        regions: UnitIndex,
        lakes: UnitIndex,
        *,
        known_names: dict[str, str],
        preferred_names: dict[str, str],
    ):
        self._units = units
        self._regions = regions
        self._lakes = lakes
        self._known = known_names
        # A country the catalogue already names one way (its OpenStreetMap
        # dive sites say "United States") keeps that name on every record.
        self._preferred = dict(preferred_names)
        self._codes = frozenset(known_names.values())
        self._sovereign_codes = self._sovereigns(units)
        self._by_code: dict[str, list[dict]] = {}
        for properties in units._properties:
            code = self._own_code(properties)
            if code:
                self._by_code.setdefault(code, []).append(properties)
        self._names: dict[str, str] = {}
        self._memory: dict[tuple[float, float], Place] = {}

    def _own_code(self, properties: dict) -> str | None:
        """The unit's own ISO code, when it has one the app knows.
        Natural Earth also writes private codes (XK, XD) that it does
        not."""
        code = properties.get("ISO_A2_EH")
        if isinstance(code, str) and code in self._codes:
            return code
        return UNIT_CODE_OVERRIDES.get(properties.get("SU_A3"))

    def _sovereigns(self, units: UnitIndex) -> dict[str, str]:
        """Sovereign state name to its own code: the unit named for the
        state, else the code most of the state's own units share."""
        named: dict[str, str] = {}
        counts: dict[str, Counter] = {}
        for properties in units._properties:
            code = self._own_code(properties)
            sovereign = properties.get("SOVEREIGNT")
            if not code or not sovereign or properties.get("ADMIN") != sovereign:
                continue
            counts.setdefault(sovereign, Counter())[code] += 1
            if properties.get("SUBUNIT") == sovereign:
                named[sovereign] = code
        return {
            sovereign: named.get(sovereign) or count.most_common(1)[0][0]
            for sovereign, count in counts.items()
        }

    def _code(self, properties: dict) -> str | None:
        return self._own_code(properties) or self._sovereign_codes.get(
            properties.get("SOVEREIGNT")
        )

    def _name(self, code: str, properties: dict) -> str:
        if code in self._preferred:
            return self._preferred[code]
        if code not in self._names:
            candidates: list = []
            # This unit first, then every other unit of the same code: a
            # province's own names say nothing the app can read, and the
            # state's core unit names the state.
            for unit in [properties] + self._by_code.get(code, []):
                parent = self._sovereign_codes.get(unit.get("SOVEREIGNT"))
                own = [unit.get("NAME_EN"), unit.get("NAME_LONG"), unit.get("SUBUNIT")]
                state = [unit.get("ADMIN"), unit.get("SOVEREIGNT")]
                # A territory is named for itself; a part of a state
                # (England, Alaska) for the state.
                candidates += own + state if code != parent else state + own
            self._names[code] = english_name(code, candidates, self._known)
        return self._names[code]

    def _region(self, lat: float, lon: float, code: str | None):
        properties = self._regions.containing(lat, lon)
        if properties is None:
            found = self._regions.nearest(lat, lon, MAX_REGION_KM)
            properties = found[0] if found else None
        if properties is None:
            return None, None
        subdivision = str(properties.get("iso_3166_2") or "")
        subdivision = _NE_ISLAND_CODES.get(subdivision, subdivision)
        if code is not None and properties.get("iso_a2") not in (code, None):
            # A neighbour's region, or a territory Natural Earth files its
            # first-level unit under the parent state.
            if not subdivision.startswith(code + "-"):
                return None, None
        return region_name(properties), SUBDIVISION_ISLANDS.get(subdivision)

    def _offline(self, lat: float, lon: float):
        """(unit, kilometres to it, whether the point is at sea)."""
        properties = self._units.containing(lat, lon)
        if properties is not None:
            return properties, 0.0, False
        found = self._units.nearest(lat, lon, MAX_SEA_KM)
        return (found[0], found[1], True) if found else (None, None, True)

    def _finish(self, lat, lon, code, country, island, at_sea) -> Place:
        region, region_island = self._region(lat, lon, code)
        island = island or region_island
        if region in (island, country):
            region = None
        return Place(
            country_code=code,
            country=country,
            region=region,
            island=island,
            fresh=self._lakes.containing(lat, lon) is not None,
            at_sea=at_sea,
        )

    def on_dry_land(self, lat: float, lon: float) -> bool:
        """Whether nothing at (lat, lon) can be under water: the point is
        inside a country, outside every lake, and more than `DRY_LAND_KM`
        from any coast, border or lake shore. Rivers and small lakes are
        not on the map, so a wreck in one reads as dry."""
        if self._units.containing(lat, lon) is None:
            return False
        if self._lakes.containing(lat, lon) is not None:
            return False
        return (
            self._units.nearest(lat, lon, DRY_LAND_KM) is None
            and self._lakes.nearest(lat, lon, DRY_LAND_KM) is None
        )

    def place(self, lat: float, lon: float) -> Place:
        """Where (lat, lon) is, from the offline boundaries alone."""
        key = (round(lat, 4), round(lon, 4))
        if key not in self._memory:
            properties, _, at_sea = self._offline(lat, lon)
            code = self._code(properties) if properties else None
            country = self._name(code, properties) if code else None
            self._memory[key] = self._finish(lat, lon, code, country, None, at_sea)
        return self._memory[key]

    def settle(self, geocoded, lat: float, lon: float) -> Place:
        """Where an OpenStreetMap dive site is: the geocoder's (code, name,
        island), corrected where the point lies in a territory the geocoder
        filed under its parent state, and replaced by the offline answer
        where the geocoder had none."""
        code, country, island = (list(geocoded) + [None, None, None])[:3]
        if not code:
            return self.place(lat, lon)
        properties, distance, at_sea = self._offline(lat, lon)
        if properties is not None and distance <= TERRITORY_REACH_KM:
            own = self._own_code(properties)
            parent = self._sovereign_codes.get(properties.get("SOVEREIGNT"))
            if own and own != code and parent == code:
                code, country = own, self._name(own, properties)
        return self._finish(lat, lon, code, country, island, at_sea)


def fetch_boundaries(cache: Path = CACHE_DIR) -> None:
    """Downloads the three Natural Earth layers into the cache."""
    folder = cache / "naturalearth"
    folder.mkdir(parents=True, exist_ok=True)
    for name in (UNITS_FILE, REGIONS_FILE, LAKES_FILE):
        (folder / name).write_bytes(http_get(NATURAL_EARTH_URL + name, timeout=600))


def load_places(
    cache: Path = CACHE_DIR, preferred_names: dict[str, str] | None = None
) -> Places:
    """The offline lookup over the downloaded boundaries."""
    folder = cache / "naturalearth"

    def index(name: str) -> UnitIndex:
        path = folder / name
        if not path.exists():
            raise FileNotFoundError(
                f"No {name} in {folder}. Run places.fetch_boundaries first."
            )
        return UnitIndex(json.loads(path.read_text(encoding="utf-8"))["features"])

    return Places(
        index(UNITS_FILE),
        index(REGIONS_FILE),
        index(LAKES_FILE),
        known_names=known_country_names(),
        preferred_names=preferred_names or {},
    )


if __name__ == "__main__":
    fetch_boundaries()
