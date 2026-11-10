#!/usr/bin/env python3
"""Generate the country name table the app resolves site countries with.

    python3 scripts/geography/generate_country_names.py

A dive site's country is free text: typed by the diver, imported, or filled
by reverse geocoding, often in the local language. To put a flag beside it
(issue #4426) the app maps that text to an ISO 3166-1 alpha-2 code through
the table this script writes to lib/core/geography/country_names.generated.dart.

The names come from CLDR (Unicode licence), pinned to CLDR_VERSION:

- every territory name in the app's eleven place-name languages, including
  CLDR's short and variant forms ("UK", "Mexique");
- each country's own name in its official languages (from territoryInfo),
  so "República Dominicana" and Arabic "مصر" resolve. A language CLDR ships
  no locale data for is skipped.

Only assigned country codes are kept: those with both an alpha-3 code and an
ISO numeric code below 900 (900-999 is private use). A name that two
countries share after folding is dropped, because no flag beats a wrong one.

The fold mirrors `normalize` in lib/core/text/fuzzy_match.dart (trim,
lowercase, strip the same diacritics) and also drops periods; the Dart side
folds a stored country the same way before looking it up, and a Dart test
checks the two agree.
"""

from __future__ import annotations

import json
import os
import urllib.request

CLDR_VERSION = "49.0.0"
_BASE_URL = (
    "https://raw.githubusercontent.com/unicode-org/cldr-json/"
    f"{CLDR_VERSION}/cldr-json/"
)
# The app's place-name languages, as PlaceNameLanguage.supportedCodes lists
# them in lib/core/constants/place_name_language.dart.
PLACE_NAME_LANGUAGES = (
    "en", "es", "fr", "de", "it", "nl", "pt", "hu", "ar", "he", "zh",
)
_OFFICIAL_STATUSES = {"official", "de_facto_official", "official_regional"}
_ALT_SUFFIXES = ("-alt-short", "-alt-variant")

_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTPUT_PATH = os.path.join(
    _REPO, "lib", "core", "geography", "country_names.generated.dart"
)

# Mirrors _diacriticMap in lib/core/text/fuzzy_match.dart.
_DIACRITICS = {
    0xE0: "a", 0xE1: "a", 0xE2: "a", 0xE3: "a", 0xE4: "a", 0xE5: "a",
    0xE7: "c",
    0xE8: "e", 0xE9: "e", 0xEA: "e", 0xEB: "e",
    0xEC: "i", 0xED: "i", 0xEE: "i", 0xEF: "i",
    0xF1: "n",
    0xF2: "o", 0xF3: "o", 0xF4: "o", 0xF5: "o", 0xF6: "o", 0xF8: "o",
    0xF9: "u", 0xFA: "u", 0xFB: "u", 0xFC: "u",
    0xFD: "y", 0xFF: "y",
    0x151: "o", 0x171: "u",
}


def fold(text: str) -> str:
    """The lookup key for [text]: the Dart fold, then periods removed."""
    folded = "".join(_DIACRITICS.get(ord(ch), ch) for ch in text.strip().lower())
    return folded.replace(".", "")


def _is_assigned(entry: dict) -> bool:
    numeric = entry.get("_numeric", "")
    return bool(entry.get("_alpha3")) and numeric.isdigit() and int(numeric) < 900


def assigned_codes(code_mappings: dict, deprecated=frozenset()) -> set[str]:
    """The alpha-2 codes CLDR maps to a current country.

    [deprecated] holds the withdrawn codes (CLDR's territoryAlias: YU, ZR,
    SU and the like), which keep their old numeric and alpha-3 codes.
    """
    return {
        code
        for code, entry in code_mappings.items()
        if len(code) == 2
        and code.isalpha()
        and code not in deprecated
        and _is_assigned(entry)
    }


def alpha3_map(code_mappings: dict, deprecated=frozenset()) -> dict[str, str]:
    """Alpha-3 to alpha-2, for assigned codes only."""
    assigned = assigned_codes(code_mappings, deprecated)
    return {code_mappings[code]["_alpha3"]: code for code in assigned}


def names_from_locale(
    territories: dict, assigned: set[str], only: set[str] | None = None
) -> list[tuple[str, str]]:
    """(name, code) pairs from one locale's territory names.

    [only] limits the result to those codes: a country's own-language name is
    taken from that language's locale, and nothing else in it.
    """
    pairs = []
    for key, name in territories.items():
        code = key
        for suffix in _ALT_SUFFIXES:
            if key.endswith(suffix):
                code = key[: -len(suffix)]
        if code not in assigned or (only is not None and code not in only):
            continue
        pairs.append((name, code))
    return pairs


def official_languages(territory_info: dict) -> dict[str, set[str]]:
    """Each language mapped to the territories where it is official."""
    result: dict[str, set[str]] = {}
    for code, info in territory_info.items():
        for language, details in info.get("languagePopulation", {}).items():
            if details.get("_officialStatus") in _OFFICIAL_STATUSES:
                result.setdefault(language, set()).add(code)
    return result


def build_table(pairs) -> dict[str, str]:
    """Folded name to code, dropping blank names and any name two codes share."""
    table: dict[str, str] = {}
    ambiguous: set[str] = set()
    for name, code in pairs:
        key = fold(name)
        if not key or key in ambiguous:
            continue
        if key in table and table[key] != code:
            del table[key]
            ambiguous.add(key)
            continue
        table[key] = code
    return table


def _dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def render_dart(
    names: dict[str, str],
    alpha3: dict[str, str],
    assigned: set[str],
    version: str,
) -> str:
    """The Dart source of the generated table, sorted so reruns diff cleanly."""
    lines = [
        "// GENERATED FILE. Do not edit by hand.",
        "// Generated by scripts/geography/generate_country_names.py from",
        f"// CLDR {version} (Unicode licence). Rerun the script to update it.",
        "",
        "/// Folded country name to ISO 3166-1 alpha-2 code (issue #4426).",
        "const Map<String, String> cldrCountryNameCodes = {",
    ]
    lines += [f"  {_dart_string(k)}: {_dart_string(v)}," for k, v in sorted(names.items())]
    lines += [
        "};",
        "",
        "/// ISO 3166-1 alpha-3 code to alpha-2 code, for assigned countries.",
        "const Map<String, String> alpha3ToAlpha2 = {",
    ]
    lines += [f"  {_dart_string(k)}: {_dart_string(v)}," for k, v in sorted(alpha3.items())]
    lines += [
        "};",
        "",
        "/// Every assigned ISO 3166-1 alpha-2 code.",
        "const Set<String> assignedAlpha2Codes = {",
    ]
    lines += [f"  {_dart_string(code)}," for code in sorted(assigned)]
    lines += ["};", ""]
    return "\n".join(lines)


def _fetch(path: str) -> dict:
    with urllib.request.urlopen(_BASE_URL + path, timeout=60) as response:
        return json.load(response)


def _territories(locale: str) -> dict:
    data = _fetch(f"cldr-localenames-full/main/{locale}/territories.json")
    return data["main"][locale]["localeDisplayNames"]["territories"]


def main() -> None:
    code_mappings = _fetch("cldr-core/supplemental/codeMappings.json")[
        "supplemental"
    ]["codeMappings"]
    deprecated = set(
        _fetch("cldr-core/supplemental/aliases.json")["supplemental"]["metadata"][
            "alias"
        ]["territoryAlias"]
    )
    assigned = assigned_codes(code_mappings, deprecated)
    available = set(
        _fetch("cldr-core/availableLocales.json")["availableLocales"]["full"]
    )
    pairs = []
    for language in PLACE_NAME_LANGUAGES:
        pairs += names_from_locale(_territories(language), assigned)
    territory_info = _fetch("cldr-core/supplemental/territoryInfo.json")[
        "supplemental"
    ]["territoryInfo"]
    for language, codes in sorted(official_languages(territory_info).items()):
        if language in PLACE_NAME_LANGUAGES or language not in available:
            continue
        pairs += names_from_locale(_territories(language), assigned, only=codes)
    table = build_table(pairs)
    source = render_dart(
        table, alpha3_map(code_mappings, deprecated), assigned, CLDR_VERSION
    )
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as out:
        out.write(source)
    print(f"wrote {len(table)} names for {len(assigned)} codes to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
