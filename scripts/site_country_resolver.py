#!/usr/bin/env python3
"""The country a catalogue site lies in, from its coordinates.

OpenStreetMap's own country text is written in the local language
("Deutschland", "Nederland"), and a site in a territory is filed under the
parent state: every Bonaire site said "Nederland". So the catalogue asks a
geocoder where each site is, in English, and reads the ISO 3166-2
subdivision code as well as the country code: a subdivision that begins with
another ISO 3166-1 code (Bonaire is `BQ-BO` inside `nl`) names a territory
with a code of its own, and that code wins.

Answers are cached on disk after every request, so a stopped run resumes.
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/reverse"
NOMINATIM_USER_AGENT = "DiveSiteHarvester/1.0 (Submersion Dive Log App)"
# Nominatim allows at most one request a second.
NOMINATIM_MIN_INTERVAL = 1.1

# Territories with an ISO 3166-1 code of their own, by that code. The name
# is the English one the app resolves back to the same code
# (lib/core/geography/country_code.dart). A run that meets a territory not
# listed here stops with a KeyError naming it: add it, then run again.
TERRITORY_NAMES: dict[str, str] = {
    "BQ": "Caribbean Netherlands",
}

# Countries the geocoder names but files under another state's code, with
# no subdivision code to tell them apart: the constituent countries of the
# Kingdom of the Netherlands all come back as `nl`. Keyed by the geocoder's
# name, casefolded.
NAMED_TERRITORIES: dict[str, tuple[str, str]] = {
    "aruba": ("AW", "Aruba"),
    "curacao": ("CW", "Curaçao"),
    "curaçao": ("CW", "Curaçao"),
    "sint maarten": ("SX", "Sint Maarten"),
}

# Countries whose geocoder name the app does not resolve to their code, as
# code -> the English name it does resolve. Applied last.
NAME_OVERRIDES: dict[str, str] = {
    # The geocoder says "Federated States of Micronesia".
    "FM": "Micronesia",
}

_SUBDIVISION_PREFIX = "ISO3166-2-lvl"


def resolve_country(address: dict) -> tuple[str | None, str | None]:
    """(ISO 3166-1 alpha-2 code, English name) for a geocoder address."""
    raw_code = address.get("country_code")
    if not raw_code:
        return None, None
    code = raw_code.upper()
    name = address.get("country")

    for key, value in address.items():
        if not key.startswith(_SUBDIVISION_PREFIX) or not value:
            continue
        prefix = str(value).split("-")[0].upper()
        if prefix != code:
            # KeyError on purpose: an unlisted territory must be named.
            code, name = prefix, TERRITORY_NAMES[prefix]
            break

    return settle_country(code, name)


def settle_country(
    code: str | None, name: str | None
) -> tuple[str | None, str | None]:
    """A (code, name) pair with the name-based rules applied.

    Separate from `resolve_country` so an answer cached before a rule
    existed is corrected when it is read back.
    """
    if name and name.casefold() in NAMED_TERRITORIES:
        code, name = NAMED_TERRITORIES[name.casefold()]
    if code:
        name = NAME_OVERRIDES.get(code, name)
    return code, name


class _UrllibResponse:
    def __init__(self, status_code: int, body: bytes):
        self.status_code = status_code
        self._body = body

    def json(self):
        return json.loads(self._body.decode("utf-8"))


def _urllib_get(url, params=None, headers=None, timeout=None):
    """A requests-shaped GET on the standard library, so the resolver needs
    no third-party package."""
    request = urllib.request.Request(
        url + "?" + urllib.parse.urlencode(params or {}),
        headers=headers or {},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return _UrllibResponse(response.status, response.read())
    except urllib.error.HTTPError as error:
        return _UrllibResponse(error.code, b"{}")


class CountryResolver:
    """Looks countries up by coordinate, one request a second, cached."""

    def __init__(self, cache_path: Path, http_get=None, sleep=time.sleep):
        self._cache_path = cache_path
        self._http_get = http_get or _urllib_get
        self._sleep = sleep
        self._last_request = 0.0
        self._cache: dict[str, list] = {}
        if cache_path.exists():
            self._cache = json.loads(cache_path.read_text(encoding="utf-8"))

    def lookup(
        self, latitude: float, longitude: float
    ) -> tuple[str | None, str | None]:
        """(code, English name) for a position, or (None, None) at sea."""
        # About 11 m: fine enough that a site never answers for its
        # neighbour across a border (Eilat and Taba share a hundredth of a
        # degree), coarse enough that a re-harvested site keeps its answer.
        key = f"{round(latitude, 4)},{round(longitude, 4)}"
        if key in self._cache:
            code, name = self._cache[key]
            return settle_country(code, name)

        elapsed = time.monotonic() - self._last_request
        if elapsed < NOMINATIM_MIN_INTERVAL:
            self._sleep(NOMINATIM_MIN_INTERVAL - elapsed)
        response = self._http_get(
            NOMINATIM_ENDPOINT,
            params={
                "format": "jsonv2",
                "lat": latitude,
                "lon": longitude,
                "zoom": 10,
                "accept-language": "en",
            },
            headers={"User-Agent": NOMINATIM_USER_AGENT},
            timeout=30,
        )
        self._last_request = time.monotonic()
        if response.status_code != 200:
            # Not an answer: leave the cache alone so the next run asks again.
            raise RuntimeError(
                f"Geocoder answered {response.status_code} for {key}"
            )

        # Open sea comes back as {"error": "Unable to geocode"}: a real
        # answer, remembered as no country.
        code, name = resolve_country(response.json().get("address") or {})
        self._cache[key] = [code, name]
        self._cache_path.write_text(
            json.dumps(self._cache, ensure_ascii=False), encoding="utf-8"
        )
        return code, name
