# Site Catalogue Foundation and Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show built-in dive sites in the site picker with area memory, adopt one in a single tap with its full details and a stored link, and move the built-in data into a format and store that can grow to tens of thousands of records.

**Architecture:** The bundled file becomes `assets/data/site_catalogue.json` (format 2, with source, licence and trust per record). A background importer copies it into two tables of the local cache database whenever its version sidecar changes, and every screen reads it through one `SiteCatalogue` interface. One adoption service creates a diver's site from a catalogue record and stores `dive_sites.catalogue_id`; the picker, GPS matching, the import page and the map all call it.

**Tech Stack:** Flutter, Riverpod, Drift (main database and `LocalCacheDatabase`), Python 3.14 scripts with `unittest`.

**Spec:** `docs/design/specs/2026-11-13-site-catalogue-picker-design.md` (program: `docs/design/specs/2026-11-13-site-catalogue-program.md`). Read both before starting.

## Global Constraints

- Fresh worktree first: `git submodule update --init --recursive`, `flutter pub get`, then codegen (`dart run build_runner build --delete-conflicting-outputs`, never with `--build-filter`). Rerun codegen after every table change.
- Never run the whole Flutter suite locally. Run the tests each task names, plus `flutter test test/architecture test/shared` after adding any file under `lib/`.
- Python: `python3.14`, tests are `unittest` files run directly (`python3.14 scripts/<name>_test.py`).
- Tests first in every task. `dart format .` before each commit. `flutter analyze` must be clean for the whole repo (infos fail CI).
- Local cache database: schema 20 to 21. Main database: schema 361 to 362 (landed as 363: main took 362 while this was in review, so every `362` below reads `363` in the code). If main has taken either number when you merge, renumber everywhere (rung, constant, `migrationVersions`, test file name, comments).
- Tables go in `lib/core/database/tables/` or `local_cache_database.dart`; main rungs in `lib/core/database/migrations/ladder/rungs_v340_onward.dart`; helpers as part files. Nothing new in `database.dart` except the version constant and the `migrationVersions` entry. `before_open.dart` is at its 800-line limit: do not add to it.
- Depths and distances shown to a diver go through `UnitFormatter` (`formatDepth`, `formatGeoDistance`).
- Every new string goes in all 11 ARB files under `lib/l10n/arb/` in alphabetical position, with real translations (a value identical to English fails `test/l10n/untranslated_english_values_test.dart`), then `flutter gen-l10n` from the repo root, and the generated files are committed.
- Paths are built with `p.join`; temporary space through `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown` (`LocalCacheDatabaseService.instance.resetForTesting()`, `tearDownTestDatabase()`).
- No file over 800 lines; no em-dashes; no emojis; commit messages and PR text never name the tool or model that wrote them.
- Radii and limits from the spec, verbatim: area radius 50 km; position rule 150 m; neighbour window 3 days; built-in section shows 5 rows before "Show all"; search shows up to 50 built-in matches, needs at least 2 characters.
- The PR needs an issue. Open one before the PR and write `Closes #N` in the description. The PR changes UI, so it needs before and after screenshots of the picker (phone and desktop widths).

## Review Focus

Inputs the spec implies but does not spell out. Each has a test in the task named.

1. **An anchor near the antimeridian.** A diver in Taveuni (longitude 179.9) expects sites at longitude -179.9 in "near here". Task 5.
2. **A search containing `%`, `_` or only punctuation.** It matches those characters literally or nothing; it never returns the whole catalogue. Task 5.
3. **A damaged catalogue file or a malformed record** (missing `name`, a string where a number belongs). Startup continues, bad records are skipped, and a file that cannot be parsed leaves the previous rows in place. Tasks 3 and 5.
4. **The local cache database is not open** (most widget tests, or a failed startup step). Every catalogue read answers as an empty catalogue; nothing throws. Tasks 5 and 11.
5. **A catalogue site with no coordinates, adopted through search.** It is created with no location, is never used as an area anchor, and does not break the position rule. Tasks 8 and 10.

---

## File Structure

New files:

| File | Responsibility |
|---|---|
| `scripts/site_catalogue_format.py` | The format 2 record, mappings, validation, version hash, writer |
| `scripts/site_country_resolver.py` | Country code and English name from coordinates, with the territory rule |
| `scripts/convert_legacy_dive_sites.py` | One-off conversion of `dive_sites.json`; deleted in Task 13 |
| `lib/features/dive_sites/domain/entities/catalogue_site.dart` | `CatalogueSite`, `CatalogueSource`, `CatalogueTrust` |
| `lib/features/dive_sites/domain/repositories/site_catalogue.dart` | The `SiteCatalogue` interface |
| `lib/features/dive_sites/domain/models/site_area_anchor.dart` | `SiteAreaAnchor` |
| `lib/features/dive_sites/domain/services/catalogue_site_mapping.dart` | Catalogue record to `DiveSite` and `SiteClassification` |
| `lib/features/dive_sites/domain/services/catalogue_site_visibility.dart` | The two hiding rules (replaces `built_in_site_dedup.dart`) |
| `lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart` | JSON to entities, dropping what it does not know |
| `lib/features/dive_sites/data/catalogue/site_catalogue_importer.dart` | Version check and atomic import |
| `lib/features/dive_sites/data/catalogue/local_site_catalogue.dart` | `SiteCatalogue` over the local cache database |
| `lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart` | The licence page entry |
| `lib/features/dive_sites/data/services/catalogue_adoption_service.dart` | The one adoption path |
| `lib/features/dive_sites/data/repositories/site_area_anchor_repository.dart` | Nearest dive with a located site |
| `lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart` | Providers for all of the above |
| `lib/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart` | A built-in row and its summary line |
| `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_built_in.dart` | The picker's built-in section state and rows |
| `lib/core/database/migrations/helpers/site_catalogue_id_migrations.dart` | The v362 column helper |
| `test/helpers/fake_site_catalogue.dart` | In-memory `SiteCatalogue` for tests |

Deleted by the end: `lib/features/dive_sites/data/services/dive_site_api_service.dart`, `lib/features/dive_sites/domain/services/built_in_site_dedup.dart`, `assets/data/dive_sites.json`, `scripts/convert_legacy_dive_sites.py`, and their tests.

---

### Task 1: Catalogue format in the scripts

**Files:**
- Create: `scripts/site_catalogue_format.py`, `scripts/site_catalogue_format_test.py`
- Create: `scripts/site_country_resolver.py`, `scripts/site_country_resolver_test.py`
- Modify: `scripts/dive_site_harvester.py` (`ReverseGeocoder` :89-187, `transform_to_submersion_format` :504-617, `_write_submersion_output` :815-903), `scripts/curated_sites.py`, `scripts/curated_sites_test.py`, `scripts/dive_site_harvester_test.py`
- Modify: `.github/workflows/ci.yaml` (job `script-tests`: add both new test files beside `scripts/curated_sites_test.py` at :747, and both modules to the `guards=` include list at :696)

**Interfaces:**
- Produces (`site_catalogue_format.py`):
  - `FORMAT = 2`
  - `SOURCES: dict[str, dict]` with keys `osm` (`name` "OpenStreetMap", `licence` "ODbL-1.0", `licence_url` "https://www.openstreetmap.org/copyright", `credit` "OpenStreetMap contributors") and `curated` (`name` "Submersion", `licence` "ODbL-1.0", `licence_url` the same URL, `credit` "Submersion contributors")
  - `NOTICE = "Contains information from OpenStreetMap, which is made available under the Open Database License (ODbL). https://www.openstreetmap.org/copyright"`
  - `map_entry(raw: str | None) -> list[str]`
  - `split_features(features: list[str] | None) -> tuple[list[str], list[str]]` returning `(types, remaining)`
  - `normalise_depths(depth: float | None, max_depth: float | None) -> tuple[float | None, float | None]` returning `(min_depth_m, max_depth_m)`
  - `osm_source_ref(site_id: str) -> str | None`
  - `to_catalogue_record(legacy: dict, *, source: str, source_ref: str | None, country_code: str | None, country: str | None) -> dict`
  - `validate_catalogue(doc: dict) -> list[str]`
  - `catalogue_version(data: bytes) -> str` (SHA-256 hex)
  - `write_catalogue(directory: Path, records: list[dict], generated_at: str) -> None` writing `site_catalogue.json` (`json.dump(..., indent=2, ensure_ascii=False)`) and `site_catalogue.version` (the hash of the JSON file's bytes, no newline)
- Produces (`site_country_resolver.py`):
  - `TERRITORY_NAMES: dict[str, str]` seeded with `{"BQ": "Caribbean Netherlands"}`
  - `NAME_OVERRIDES: dict[str, str]`, empty to start: code to English name, applied last, for a country whose geocoder name the app's `countryCodeFor` does not resolve
  - `resolve_country(address: dict) -> tuple[str | None, str | None]` returning `(code, english_name)`
  - `class CountryResolver` with `__init__(self, cache_path: Path)` and `lookup(self, latitude: float, longitude: float) -> tuple[str | None, str | None]`, one request per second, Nominatim `reverse` with `format=jsonv2`, `zoom=10`, `accept-language=en`, the existing `NOMINATIM_USER_AGENT`, results cached to `cache_path` after every call so a stopped run resumes

- [ ] **Step 1: Write the failing tests for the format module**

`scripts/site_catalogue_format_test.py`, `unittest`, loaded the way `curated_sites_test.py` loads its module:

```python
def test_entry_maps_source_values_to_app_names(self):
    self.assertEqual(fmt.map_entry("boat"), ["boat"])
    self.assertEqual(fmt.map_entry("Boat"), ["boat"])
    self.assertEqual(fmt.map_entry("shore"), ["shore"])
    for raw in ("stair", "steps", "ladder"):
        self.assertEqual(fmt.map_entry(raw), ["ladder"])
    self.assertEqual(fmt.map_entry("pier"), ["jetty"])
    for raw in ("boat:shore", "boat;shore", "boat  or shore"):
        self.assertEqual(fmt.map_entry(raw), ["boat", "shore"])
    for raw in ("stone", "yes", "", None):
        self.assertEqual(fmt.map_entry(raw), [])

def test_features_split_into_types_and_the_rest(self):
    types, rest = fmt.split_features(["wreck", "speleology", "cave", "drift", "sharks"])
    self.assertEqual(types, ["wreck", "cave"])
    self.assertEqual(rest, ["drift", "sharks"])

def test_a_lone_depth_is_the_maximum(self):
    self.assertEqual(fmt.normalise_depths(18.0, None), (None, 18.0))
    self.assertEqual(fmt.normalise_depths(None, 30.0), (None, 30.0))
    self.assertEqual(fmt.normalise_depths(12.0, 12.0), (None, 12.0))
    self.assertEqual(fmt.normalise_depths(15.0, 10.0), (10.0, 15.0))
    self.assertEqual(fmt.normalise_depths(3.0, 12.0), (3.0, 12.0))

def test_osm_ids_become_object_urls(self):
    self.assertEqual(fmt.osm_source_ref("osm_node_663869401"),
                     "https://www.openstreetmap.org/node/663869401")
    self.assertEqual(fmt.osm_source_ref("osm_way_24150076"),
                     "https://www.openstreetmap.org/way/24150076")
    self.assertIsNone(fmt.osm_source_ref("curated_nj_vega"))

def test_a_legacy_record_converts(self):
    legacy = {"id": "osm_node_663871191", "name": "Teru Kaze",
              "description": "Anti-submarine boat", "latitude": 11.9742,
              "longitude": 120.07955, "max_depth": 12.0, "min_depth": 3.0,
              "country": "Philippines", "region": "Palawan",
              "website": "http://example.org/x", "features": ["wreck"],
              "entry_type": "boat", "hazards": "fairway"}
    record = fmt.to_catalogue_record(legacy, source="osm",
        source_ref=fmt.osm_source_ref(legacy["id"]),
        country_code="PH", country="Philippines")
    self.assertEqual(record, {
        "id": "osm_node_663871191", "name": "Teru Kaze",
        "lat": 11.9742, "lon": 120.07955,
        "country_code": "PH", "country": "Philippines", "region": "Palawan",
        "min_depth_m": 3.0, "max_depth_m": 12.0,
        "types": ["wreck"], "entry": ["boat"],
        "hazards": "fairway", "description": "Anti-submarine boat",
        "website": "http://example.org/x",
        "source": "osm",
        "source_ref": "https://www.openstreetmap.org/node/663871191",
        "trust": "verified"})
```

Also: `test_empty_and_null_fields_are_left_out` (a legacy record with only `id` and `name` converts to exactly `id`, `name`, `source`, `trust`), `test_validate_names_each_problem` (duplicate id, missing name, undeclared source, `trust` outside `verified`/`researched`, latitude without longitude, a `types` value outside the 16 ids of `kBuiltInSiteTypes`, an `entry` value outside `EntryMethod`), and `test_the_version_is_the_hash_of_the_written_file` (write to a temp dir, hash the JSON file's bytes, compare with the sidecar's content).

- [ ] **Step 2: Run them and see them fail**

Run: `python3.14 scripts/site_catalogue_format_test.py`
Expected: FAIL, module not found.

- [ ] **Step 3: Implement `scripts/site_catalogue_format.py`**

Field order in a record is the order in the test above; optional keys are omitted, never written as null. `to_catalogue_record` passes `legacy["min_depth"]` and `legacy["max_depth"]` to `normalise_depths`, reads `locality`, `island`, `body_of_water`, `water_type`, `difficulty` when the legacy dict has them, writes `features` only when `split_features` leaves a remainder, and drops the legacy `ocean` key. The type ids and entry names are constants in the module with a comment naming `lib/core/database/site_type_seed.dart` and `EntryMethod` as their source. The JSON document is `{"metadata": {"format": 2, "generated_at": ..., "notice": NOTICE, "total_count": n, "sources": SOURCES}, "sites": [...]}`.

- [ ] **Step 4: Run them and see them pass**

Run: `python3.14 scripts/site_catalogue_format_test.py`
Expected: OK.

- [ ] **Step 5: Write the failing tests for the resolver**

```python
def test_a_plain_answer_gives_the_country(self):
    self.assertEqual(res.resolve_country(
        {"country": "Egypt", "country_code": "eg", "ISO3166-2-lvl4": "EG-BA"}),
        ("EG", "Egypt"))

def test_a_territory_subdivision_wins(self):
    # Measured from Nominatim for 12.08, -68.28 on 2026-11-13.
    self.assertEqual(res.resolve_country(
        {"municipality": "Bonaire", "ISO3166-2-lvl8": "BQ-BO",
         "country": "Netherlands", "country_code": "nl"}),
        ("BQ", "Caribbean Netherlands"))

def test_an_unknown_territory_prefix_is_an_error(self):
    with self.assertRaises(KeyError):
        res.resolve_country({"ISO3166-2-lvl8": "ZZ-01",
                             "country": "Nowhere", "country_code": "xx"})

def test_no_address_gives_nothing(self):
    self.assertEqual(res.resolve_country({}), (None, None))
```

Plus `test_lookup_reads_the_cache_before_the_network` (a cache file holding the rounded key answers with no request; inject the HTTP call as a constructor argument defaulting to `requests.get` so the test passes a function that fails if called).

- [ ] **Step 6: Run, implement `scripts/site_country_resolver.py`, run again**

`resolve_country`: `code = address["country_code"].upper()`. For every key starting `ISO3166-2-lvl`, take the part of the value before `-`; when it differs from `code`, it is the territory code and its name comes from `TERRITORY_NAMES` (a missing entry raises `KeyError` naming the code, so whoever runs the converter adds the name). Otherwise the name is `address["country"]`. The cache key is the coordinates rounded to 2 decimals, as the existing `ReverseGeocoder` does.

Run: `python3.14 scripts/site_country_resolver_test.py`
Expected: OK.

- [ ] **Step 7: Move the harvester and curated merge onto the new format**

- `curated_sites.py`: `CATALOGUE_FIELDS` becomes the format 2 key order. `merge_curated` emits records through `to_catalogue_record(..., source="curated", source_ref=entry["source"], ...)`, with `entry["depthM"]` as the maximum depth and `entry["kind"]` as a type when it is a built-in type id. Its proximity check reads `lat` and `lon`. Update the module docstring, which says `source`, `depthM` and `kind` never reach the app.
- `dive_site_harvester.py`: `transform_to_submersion_format` is renamed `transform_to_catalogue_record` and builds the legacy-shaped dict as today, then returns `to_catalogue_record(...)`. Country comes from `CountryResolver.lookup` for every record with coordinates (not only when `addr:country` is missing); a record without coordinates keeps a two-letter `addr:country` as its code and gets no name. `_write_submersion_output` writes sites through `write_catalogue(OUTPUT_DIR, ...)` and no longer writes `dive_sites.json` or its timestamped copy. The centres output is unchanged. Fix the docstring at line 9 that names `divesiteharvester.py`.
- Update `curated_sites_test.py` and `dive_site_harvester_test.py` for the new names and keys. `GeneratedAtCallSiteTest` counts `generated_at` keys through `utc_timestamp()`: keep every stamp going through that helper and update the expected count to what the file then has. `test_the_bundled_catalogue_carries_every_curated_site` reads `assets/data/site_catalogue.json` and is skipped with `unittest.skipUnless(os.path.exists(path), ...)` until Task 2 creates the file.

- [ ] **Step 8: Run every script test**

Run: `python3.14 scripts/site_catalogue_format_test.py && python3.14 scripts/site_country_resolver_test.py && python3.14 scripts/curated_sites_test.py && python3.14 scripts/dive_site_harvester_test.py`
Expected: OK four times (the harvester test may report skips when `overpy` is not installed; that is its existing behaviour).

- [ ] **Step 9: Commit**

```bash
git add scripts/site_catalogue_format.py scripts/site_catalogue_format_test.py scripts/site_country_resolver.py scripts/site_country_resolver_test.py scripts/dive_site_harvester.py scripts/dive_site_harvester_test.py scripts/curated_sites.py scripts/curated_sites_test.py .github/workflows/ci.yaml
git commit -m "feat(dive-sites): write the built-in site data in catalogue format 2"
```

---

### Task 2: Convert the shipped data

**Files:**
- Create: `scripts/convert_legacy_dive_sites.py`, `scripts/convert_legacy_dive_sites_test.py`
- Create: `assets/data/site_catalogue.json`, `assets/data/site_catalogue.version`
- Create: `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart`
- Modify: `.gitignore` (the resolver cache file)

**Interfaces:**
- Consumes: Task 1's `to_catalogue_record`, `osm_source_ref`, `write_catalogue`, `validate_catalogue`, `CountryResolver`.
- Produces: the two asset files. `assets/data/dive_sites.json` stays until Task 13.

- [ ] **Step 1: Write the failing converter tests**

`convert(legacy_doc: dict, curated: list[dict], lookup) -> list[dict]`, where `lookup(lat, lon)` returns `(code, name)`:

```python
def test_located_records_take_their_country_from_the_lookup(self):
    doc = {"sites": [{"id": "osm_node_1", "name": "Salt Pier",
                      "latitude": 12.08, "longitude": -68.28,
                      "country": "Nederland"}]}
    out = conv.convert(doc, [], lambda lat, lon: ("BQ", "Caribbean Netherlands"))
    self.assertEqual(out[0]["country_code"], "BQ")
    self.assertEqual(out[0]["country"], "Caribbean Netherlands")

def test_a_record_without_coordinates_keeps_a_two_letter_code_only(self):
    doc = {"sites": [{"id": "osm_way_2", "name": "A", "country": "CW"},
                     {"id": "osm_way_3", "name": "B", "country": "Deutschland"},
                     {"id": "osm_way_4", "name": "C"}]}
    out = conv.convert(doc, [], lambda lat, lon: self.fail("no lookup"))
    self.assertEqual(out[0]["country_code"], "CW")
    self.assertEqual(out[0]["country"], conv.CODE_NAMES["CW"])
    self.assertNotIn("country_code", out[1])
    self.assertNotIn("country", out[1])
    self.assertNotIn("country", out[2])

def test_regions_are_left_as_they_are(self):
    doc = {"sites": [{"id": "osm_node_5", "name": "X", "latitude": 27.0,
                      "longitude": 34.0, "country": "مصر",
                      "region": "البحر الأحمر"}]}
    out = conv.convert(doc, [], lambda lat, lon: ("EG", "Egypt"))
    self.assertEqual(out[0]["region"], "البحر الأحمر")

def test_curated_records_carry_their_source_depth_and_kind(self):
    curated = [{"id": "curated_nj_vega", "name": "Vega", "description": "d",
                "latitude": 40.1941, "longitude": -73.9464,
                "country": "United States", "region": "New Jersey",
                "website": None, "depthM": 17, "kind": "wreck",
                "source": "https://njscuba.net/x"}]
    doc = {"sites": [{"id": "curated_nj_vega", "name": "Vega",
                      "latitude": 40.1941, "longitude": -73.9464,
                      "country": "United States", "region": "New Jersey"}]}
    out = conv.convert(doc, curated, lambda lat, lon: ("US", "United States"))
    self.assertEqual(out[0]["source"], "curated")
    self.assertEqual(out[0]["source_ref"], "https://njscuba.net/x")
    self.assertEqual(out[0]["max_depth_m"], 17)
    self.assertEqual(out[0]["types"], ["wreck"])
```

`CODE_NAMES` holds the English names of the seven codes on coordinate-less records today: CW, US, SK, IT, NL, BE (US appears twice).

- [ ] **Step 2: Run, implement, run again**

Run: `python3.14 scripts/convert_legacy_dive_sites_test.py`
Expected: FAIL, then OK. `main()` reads `assets/data/dive_sites.json` and `scripts/dive_sites_curated.json`, builds a `CountryResolver` whose cache is `scripts/.site_country_cache.json`, runs `convert`, fails loudly if `validate_catalogue` reports anything, and calls `write_catalogue`. It keeps the legacy `generated_at`.

- [ ] **Step 3: Run the conversion**

Add `scripts/.site_country_cache.json` to `.gitignore`. Run in the background; it makes one geocoder request per second for about 3,300 positions, close to an hour, and resumes from the cache if stopped:

Run: `python3.14 scripts/convert_legacy_dive_sites.py`
Expected: `assets/data/site_catalogue.json` and `assets/data/site_catalogue.version` exist; the script prints the record count (3667) and exits 0. If it stops with `KeyError` for a territory code, add that code's English name to `TERRITORY_NAMES` (the name must be one the app's `countryCodeFor` resolves to the same code) and rerun.

- [ ] **Step 4: Write the failing asset test**

`test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart` reads the files from disk with `File(p.join('assets', 'data', ...))`:

- `metadata.format` is 2 and `metadata.notice` contains "Open Database License".
- 3667 records; ids unique; every record has non-empty `id`, `name`, `source`, `trust`; every `source` is a key of `metadata.sources`; `trust` is `verified` for all.
- `lat` and `lon` are present together or not at all.
- Every `country_code` is in `assignedAlpha2Codes`, and `countryCodeFor(record['country'])` equals the record's `country_code` (`lib/core/geography/country_code.dart`).
- `osm_node_663869401` (Salt Pier) has `country_code` `BQ`.
- No record has `min_depth_m` greater than `max_depth_m`.
- Every `types` value is in `kBuiltInSiteTypeIds`; every `entry` value is an `EntryMethod` name.
- The sidecar equals the SHA-256 of the JSON file's bytes (`package:crypto`).
- Every legacy id in `assets/data/dive_sites.json` is present (this check carries a comment that Task 13 removes it with the legacy file).

- [ ] **Step 5: Run it**

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart && python3.14 scripts/curated_sites_test.py`
Expected: PASS. A failing country check names a country whose English name the app does not resolve to that code. Add the code to `NAME_OVERRIDES` (or correct `TERRITORY_NAMES` or `CODE_NAMES`) with a name `countryCodeFor` does resolve, add a resolver test for it, and rerun the conversion (the cache makes the rerun fast).

- [ ] **Step 6: Commit**

```bash
git add scripts/convert_legacy_dive_sites.py scripts/convert_legacy_dive_sites_test.py assets/data/site_catalogue.json assets/data/site_catalogue.version test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart .gitignore
git commit -m "feat(dive-sites): convert the bundled sites to the catalogue file"
```

---

### Task 3: Catalogue entities, interface and parser

**Files:**
- Create: `lib/features/dive_sites/domain/entities/catalogue_site.dart`
- Create: `lib/features/dive_sites/domain/repositories/site_catalogue.dart`
- Create: `lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart`
- Create: `test/helpers/fake_site_catalogue.dart`
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart`

**Interfaces:**
- Produces:

```dart
enum CatalogueTrust { verified, researched }

class CatalogueSite extends Equatable {
  const CatalogueSite({
    required this.id, required this.name, this.location,
    this.countryCode, this.country, this.region, this.locality, this.island,
    this.bodyOfWater, this.waterType, this.minDepth, this.maxDepth,
    this.typeIds = const [], this.entryMethods = const [],
    this.features = const [], this.difficulty, this.hazards,
    this.description, this.website, required this.source, this.sourceRef,
    this.trust = CatalogueTrust.verified,
  });
  // GeoPoint? location; WaterType? waterType; double? minDepth, maxDepth;
  // List<String> typeIds; List<EntryMethod> entryMethods;
  // List<String> features; SiteDifficulty? difficulty; String source.
}

class CatalogueSource extends Equatable {
  const CatalogueSource({required this.key, required this.name,
      required this.licence, this.licenceUrl, required this.credit});
}

abstract interface class SiteCatalogue {
  Future<List<CatalogueSite>> near(GeoPoint point,
      {required double radiusMeters, int limit = 500});
  Future<List<CatalogueSite>> search(String query,
      {GeoPoint? areaFirst, double areaRadiusMeters = 50000, int limit = 50});
  Future<CatalogueSite?> byId(String id);
  Future<List<CatalogueSite>> allWithCoordinates();
  Future<CatalogueSource?> source(String key);
}

class ParsedSiteCatalogue {
  final int format;
  final List<CatalogueSite> sites;
  final List<CatalogueSource> sources;
}
ParsedSiteCatalogue parseSiteCatalogue(String json); // throws FormatException
String catalogueSearchText(CatalogueSite site);
```

- `FakeSiteCatalogue implements SiteCatalogue`, built from `List<CatalogueSite>` and an optional `Map<String, CatalogueSource>`. It applies the same rules as the real one with plain Dart (`distanceMeters` from `lib/core/utils/geo_math.dart`, `SiteQuery`-style word matching on `catalogueSearchText`), and counts calls per method in public `int` fields so widget tests can assert on them.

- [ ] **Step 1: Write the failing parser tests**

```dart
test('a full record parses', () {
  final parsed = parseSiteCatalogue(jsonEncode({
    'metadata': {'format': 2, 'sources': {
      'osm': {'name': 'OpenStreetMap', 'licence': 'ODbL-1.0',
        'licence_url': 'https://www.openstreetmap.org/copyright',
        'credit': 'OpenStreetMap contributors'}}},
    'sites': [{
      'id': 'osm_node_1', 'name': 'Salt Pier', 'lat': 12.08, 'lon': -68.28,
      'country_code': 'BQ', 'country': 'Caribbean Netherlands',
      'island': 'Bonaire', 'water_type': 'salt',
      'min_depth_m': 5, 'max_depth_m': 15.5,
      'types': ['reef', 'pier'], 'entry': ['shore'], 'features': ['drift'],
      'difficulty': 'beginner', 'hazards': 'boat traffic',
      'description': 'Pillars.', 'website': 'https://example.org',
      'source': 'osm', 'source_ref': 'https://www.openstreetmap.org/node/1',
      'trust': 'verified'}],
  }));
  expect(parsed.format, 2);
  expect(parsed.sources.single.credit, 'OpenStreetMap contributors');
  expect(parsed.sites.single, const CatalogueSite(
    id: 'osm_node_1', name: 'Salt Pier', location: GeoPoint(12.08, -68.28),
    countryCode: 'BQ', country: 'Caribbean Netherlands', island: 'Bonaire',
    waterType: WaterType.salt, minDepth: 5, maxDepth: 15.5,
    typeIds: ['reef', 'pier'], entryMethods: [EntryMethod.shore],
    features: ['drift'], difficulty: SiteDifficulty.beginner,
    hazards: 'boat traffic', description: 'Pillars.',
    website: 'https://example.org', source: 'osm',
    sourceRef: 'https://www.openstreetmap.org/node/1'));
});
```

Further tests, one behaviour each:
- `unknown names are dropped, the record is kept`: `water_type: 'acid'`, `entry: ['shore', 'teleport']`, `types: ['reef', 'volcano']`, `difficulty: 'heroic'`, `trust: 'rumour'` give `waterType` null, `[EntryMethod.shore]`, `['reef']`, `difficulty` null, `CatalogueTrust.verified`. A type id is known when it is in `kBuiltInSiteTypeIds`.
- `a record without an id or a name is skipped`, and so is a record that is not a map.
- `a number given as a string does not break the file`: `'lat': '12.08'` leaves `location` null for that record; the other records parse.
- `a latitude without a longitude gives no location`.
- `text that is not JSON throws FormatException`, and so does JSON without a `sites` list.
- `search text folds name, country, region, locality and island`: `catalogueSearchText` of a site named "Cancún" in "México" returns `normalize('Cancún México')` (`lib/core/text/fuzzy_match.dart`), with blank parts dropped the way `siteSearchText` drops them.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart`
Expected: FAIL, undefined names.

- [ ] **Step 3: Implement the entity, interface, parser and fake**

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/entities/catalogue_site.dart lib/features/dive_sites/domain/repositories/site_catalogue.dart lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart test/helpers/fake_site_catalogue.dart test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart
git commit -m "feat(dive-sites): add the site catalogue entities, interface and parser"
```

---

### Task 4: Catalogue tables in the local cache database

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (tables, the `@DriftDatabase` list at :327, `schemaVersion` at :347, the ladder after the v20 rung at :530, `beforeOpen` before its final `_addGridBlobColumns()` at :690)
- Test: `test/core/database/local_cache_migration_v21_site_catalogue_test.dart`

**Interfaces:**
- Produces: tables `site_catalogue` and `site_catalogue_meta`, Drift accessors `siteCatalogueEntries` and `siteCatalogueMeta`, row class `SiteCatalogueRow`.

```dart
@DataClassName('SiteCatalogueRow')
class SiteCatalogueEntries extends Table {
  @override
  String get tableName => 'site_catalogue';
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get searchText => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get locality => text().nullable()();
  TextColumn get island => text().nullable()();
  TextColumn get bodyOfWater => text().nullable()();
  TextColumn get waterType => text().nullable()();
  RealColumn get minDepth => real().nullable()();
  RealColumn get maxDepth => real().nullable()();
  TextColumn get typeIds => text().withDefault(const Constant('[]'))();
  TextColumn get entryMethods => text().withDefault(const Constant('[]'))();
  TextColumn get features => text().withDefault(const Constant('[]'))();
  TextColumn get difficulty => text().nullable()();
  TextColumn get hazards => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get trust => text().withDefault(const Constant('verified'))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SiteCatalogueMetaRow')
class SiteCatalogueMeta extends Table {
  @override
  String get tableName => 'site_catalogue_meta';
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
```

Index, created in the rung and re-asserted in `beforeOpen`: `CREATE INDEX IF NOT EXISTS idx_site_catalogue_lat_lon ON site_catalogue (latitude, longitude)`.

- [ ] **Step 1: Write the failing migration test**

Model it on `local_cache_migration_v20_grid_blob_test.dart`. Three tests:
- `a fresh database has both tables and the index`: open `LocalCacheDatabase(NativeDatabase.memory())`, expect `db.schemaVersion` `greaterThanOrEqualTo(21)`, `PRAGMA table_info('site_catalogue')` lists the 24 column names above in snake case, `sqlite_master` has `idx_site_catalogue_lat_lon`.
- `a version 20 database gains them`: seed `PRAGMA user_version = 20` in `setup:` with no catalogue tables, open, insert a row into each table.
- `a database stamped 21 without the tables is healed`: seed `PRAGMA user_version = 21` and nothing else, open, insert a row (the `beforeOpen` backstop).

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/database/local_cache_migration_v21_site_catalogue_test.dart`
Expected: FAIL to compile, `siteCatalogueEntries` undefined.

- [ ] **Step 3: Add the tables, the v21 rung and the backstop**

Rung: `if (from < 21) { createTable both; create the index }`, with a comment in the style of v18. Backstop: two `CREATE TABLE IF NOT EXISTS` statements whose columns match Drift's exactly, then the index statement. Run codegen.

- [ ] **Step 4: Run the new test and the neighbours**

Run: `flutter test test/core/database/local_cache_migration_v21_site_catalogue_test.dart test/core/database/local_cache_migration_v20_grid_blob_test.dart test/core/services/local_cache_database_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/local_cache_database.dart test/core/database/local_cache_migration_v21_site_catalogue_test.dart
git commit -m "feat(dive-sites): add the site catalogue tables to the local cache database"
```

---

### Task 5: Importer, local catalogue and startup

**Files:**
- Create: `lib/features/dive_sites/data/catalogue/site_catalogue_importer.dart`
- Create: `lib/features/dive_sites/data/catalogue/local_site_catalogue.dart`
- Create: `lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart`
- Modify: `lib/app.dart` (the post-frame list at :211-229)
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_importer_test.dart`, `test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart`

**Interfaces:**
- Consumes: Task 3 (`parseSiteCatalogue`, `catalogueSearchText`, `SiteCatalogue`), Task 4 (tables).
- Produces:

```dart
const kSiteCatalogueAsset = 'assets/data/site_catalogue.json';
const kSiteCatalogueVersionAsset = 'assets/data/site_catalogue.version';

enum SiteCatalogueImportOutcome { upToDate, imported, failed }

class SiteCatalogueImporter {
  SiteCatalogueImporter({LocalCacheDatabase? database, AssetBundle? bundle});
  Future<SiteCatalogueImportOutcome> importIfChanged();
}

class LocalSiteCatalogue implements SiteCatalogue {
  LocalSiteCatalogue({LocalCacheDatabase? database});
}

// site_catalogue_providers.dart
final siteCatalogueProvider = Provider<SiteCatalogue>((ref) => LocalSiteCatalogue());
final siteCatalogueRevisionProvider = StateProvider<int>((ref) => 0);
final siteCatalogueImportProvider = Provider<Future<void> Function()>(...);
final catalogueSiteProvider = FutureProvider.family<CatalogueSite?, String>(...);
final catalogueSourceProvider = FutureProvider.family<CatalogueSource?, String>(...);
```

Both classes take the database the way `RecentQueryRepository` does (`_database ?? LocalCacheDatabaseService.instance.database`). `siteCatalogueImportProvider` runs the importer and adds 1 to `siteCatalogueRevisionProvider` when the outcome is `imported`. `catalogueSiteProvider` and `catalogueSourceProvider` watch the revision, so they refetch after an import.

- [ ] **Step 1: Write the failing importer tests**

Use `LocalCacheDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions))` and a small `AssetBundle` fake (extend `CachingAssetBundle`, serve the two keys from a map, count `loadString` calls per key).

- `first run imports every record and stores the version`: outcome `imported`; row count equals the file's; meta `version` equals the sidecar; meta `sources` is the sources as JSON; a row's `search_text` equals `catalogueSearchText` of its site.
- `the same version imports nothing`: second call returns `upToDate` and never loads the JSON asset (the bundle's count for `kSiteCatalogueAsset` stays 1).
- `a new version replaces the rows`: change the bundle to a file without one of the earlier ids and with a new sidecar; after the call the old id is gone and the new one present.
- `a file that cannot be parsed leaves the old rows`: bundle serves `'not json'` with a new sidecar; outcome `failed`; rows and meta `version` unchanged; a later call with a good file returns `imported`.
- `a bad record is skipped, the rest import` (Review Focus 3): one record without `name` among three.
- `two calls at once import once`: `Future.wait` of two calls loads the JSON asset once.
- `a missing sidecar fails without throwing`.
- `the database not being open fails without throwing` (Review Focus 4): no injected database and `LocalCacheDatabaseService.instance.resetForTesting()`; outcome `failed`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_importer_test.dart`
Expected: FAIL, undefined names.

- [ ] **Step 3: Implement the importer**

Read the sidecar (trimmed) and compare with meta `version`. When it differs: load the JSON string, parse it with `compute(parseSiteCatalogue, json)`, then in one `db.transaction` delete every `site_catalogue` row, insert the new rows with `db.batch` in chunks of 500, and write meta `version` and `sources`. Any exception is caught, logged through `LoggerService`, and returns `failed`. A private `Future` field makes concurrent calls share one run.

- [ ] **Step 4: Run and see them pass**

- [ ] **Step 5: Write the failing catalogue tests**

Seed the tables through the importer with a fixture file of about a dozen sites.

- `near returns sites inside the radius, nearest first`, and excludes one just outside and every site without coordinates.
- `near works across the antimeridian` (Review Focus 1): anchor `GeoPoint(-16.8, 179.95)`, radius 50 km, a site at `(-16.8, -179.95)` is returned and one at `(-16.8, 178.0)` is not.
- `search needs every word`: "blue egypt" finds "Blue Hole" in Egypt and not "Blue Corner" in Palau.
- `search folds case and accents`: "cancun" finds "Cancún".
- `search puts the area first, then by name`: with `areaFirst` set, the in-area match precedes an alphabetically earlier match elsewhere.
- `search treats percent and underscore literally` (Review Focus 2): `search('%')` and `search('_')` return only sites whose text contains that character (none in the fixture, so an empty list), and `search('   ')` returns an empty list.
- `search respects the limit`.
- `byId returns the site or null`; list fields and enums round trip (compare with the parsed fixture entity).
- `allWithCoordinates leaves out sites without coordinates`.
- `source returns the stored source or null`.
- `every method answers empty when the database is not open` (Review Focus 4): `LocalSiteCatalogue()` with the service reset returns `[]`, `null`, `[]`, `[]`, `null`.

- [ ] **Step 6: Run, implement `LocalSiteCatalogue`, run again**

`near`: a bounding box from the radius (latitude plus or minus `radius / 111320`, longitude plus or minus that divided by `cos(latitude)`), as one range or, when the box crosses 180 degrees, two longitude ranges joined with OR; then `distanceMeters` in Dart to cut the corners and sort. `search`: `normalize` the query and split it into words exactly as `SiteQuery` does; each word becomes `search_text LIKE ? ESCAPE '\'` with `%`, `_` and `\` in the word escaped and wrapped in `%`. With `areaFirst`, run the in-area query (the bounding box plus the word conditions, up to `limit`) and then the worldwide query (ordered by `name`, up to `limit`), and return area matches followed by the others, without repeats, cut to `limit`. A `StateError` from the database getter is caught in one private helper that every method goes through.

Run: `flutter test test/features/dive_sites/data/catalogue`
Expected: PASS.

- [ ] **Step 7: Start the import after the first frame**

In `lib/app.dart`, add `_importSiteCatalogue()` to the post-frame list, written like its neighbours: `unawaited(ref.read(siteCatalogueImportProvider)())`.

- [ ] **Step 8: Run the guards and commit**

Run: `flutter test test/architecture test/shared && flutter analyze`
Expected: PASS, no issues. A provider guard may ask for a `// no-tick:` note on the service providers; follow its message.

```bash
git add lib/features/dive_sites/data/catalogue lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart lib/app.dart test/features/dive_sites/data/catalogue
git commit -m "feat(dive-sites): import the site catalogue into the local cache and query it"
```

---

### Task 6: The link column

**Files:**
- Modify: `lib/core/database/tables/site_tables.dart` (after `countryCode` at :39)
- Create: `lib/core/database/migrations/helpers/site_catalogue_id_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (a `part` line beside :91), `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (after the v361 rung at :162-169), `lib/core/database/migrations/before_open_child_columns.dart` (after :79-81), `lib/core/database/database.dart` (:322 and the end of `migrationVersions` at :1670)
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart`, `lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart`, `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart` (beside :91-95), the 11 ARB files
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart`
- Test: `test/core/database/migration_v362_site_catalogue_id_test.dart`, `test/features/dive_sites/data/repositories/site_catalogue_link_test.dart`, `test/core/services/sync/sync_record_overlay_site_catalogue_id_test.dart`
- Modify: `test/features/dive_log/data/repositories/dive_repository_site_mapping_test.dart` (`richSite` at :27-51)

**Interfaces:**
- Produces:
  - Column `dive_sites.catalogue_id` (Drift `catalogueId`), nullable text, with a doc comment: `/// The id of the built-in catalogue record this site was adopted from (v362). Null for a site the diver made by hand.`
  - `DiveSite.catalogueId` (`String?`), in the constructor, `copyWith` (`String? catalogueId`, `bool clearCatalogueId = false`) and `props`.
  - `SiteRepository.getSiteByCatalogueId(String catalogueId, {String? diverId}) -> Future<domain.DiveSite?>`: the diver's site with that link (when `diverId` is null, a site with no diver), the oldest by `createdAt` if there are several.
  - l10n key `settings_conflict_field_catalogueId`, English "Built-in catalogue link".

- [ ] **Step 1: Write the failing migration test**

Copy the shape of `test/core/database/migration_v361_site_country_code_test.dart`: a raw `dive_sites` table at `PRAGMA user_version = 361` gains `catalogue_id`; existing rows read back with it null; `AppDatabase.migrationVersions` contains 362; `AppDatabase.currentSchemaVersion` is `greaterThanOrEqualTo(362)`; a database stamped 362 without the column gets it from the backstop.

- [ ] **Step 2: Write the failing repository tests**

`site_catalogue_link_test.dart`, with `setUpTestDatabase()`:

- `createSite stores the link and reads it back`.
- `getSiteByCatalogueId finds the diver's site`: two divers each own a site linked to `osm_node_1`; each lookup returns that diver's own; a third diver gets null.
- `updateSite leaves the link alone`: create with a link, call `updateSite` with a `DiveSite` of the same id built fresh without `catalogueId` (what `site_edit_page.dart:2290` does), read back, the link is still there.
- `a merge keeps the survivor's link`: survivor linked to `a`, other linked to `b`, `mergedSite` without a link; the survivor ends with `a`.
- `a merge takes the other site's link when the survivor has none`.
- `undoing a merge restores each site's link`.

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/core/database/migration_v362_site_catalogue_id_test.dart test/features/dive_sites/data/repositories/site_catalogue_link_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Add the column**

- Table column with the doc comment.
- Helper part file: `extension SiteCatalogueIdMigrations on AppDatabase { Future<void> _assertSiteCatalogueIdColumn() => _addColumnIfMissing('dive_sites', 'catalogue_id', 'TEXT'); }`, with its `part` line.
- Rung: `if (from < 362) await _assertSiteCatalogueIdColumn();` and `if (from < 362) await reportProgress();`, with a comment in the style of v361 saying the column is nullable and offline, so the compatibility floor does not move.
- Backstop: `await _assertSiteCatalogueIdColumn();` in `_assertChildRowColumns()` with a comment.
- `currentSchemaVersion = 362`, and `362,` appended to `migrationVersions` with a comment.
- Run codegen, then `dart run tool/generate_sql_column_notes.dart`.

- [ ] **Step 5: Carry it through the entity, mapper and repository**

- Entity and mapper as in Interfaces.
- `createSite` (:169-199): write `catalogueId`.
- `_writeSiteUpdate` (:294-320): do not write it. Add a comment beside the existing omission of `sharedLibraryId` saying why (the edit page saves a freshly built entity; see the spec, section 8).
- `mergeSites` (:942): before writing the survivor, set its link to the stored survivor's link, else the first non-null link among the merged sites in `siteIds` order, ignoring whatever `mergedSite.catalogueId` holds.
- `_updateSiteRow` (:1620-1647) and `_undoMergeInner` (:1213-1242): write `catalogueId`.
- Add `getSiteByCatalogueId`.

- [ ] **Step 6: Conflict catalogue and strings**

Add `'catalogueId': ConflictField((l) => l.settings_conflict_field_catalogueId, FieldKind.shortText)` with a comment. Add the key to all 11 ARB files and run `flutter gen-l10n`.

- [ ] **Step 7: Sync and mapping tests**

- `sync_record_overlay_site_catalogue_id_test.dart`, modelled on `sync_record_overlay_site_country_code_test.dart`: a remote `diveSites` row that omits `catalogueId` (an older peer) overlaid on a local row that has one keeps the local value; a remote row that carries a value replaces it.
- Add `catalogueId: 'osm_node_1'` to `richSite` in `dive_repository_site_mapping_test.dart` and make that test pass. If the dive repository's site read is one of the raw SQL selects (`s.country_code AS site_country_code` at :3460 and :4377), add `s.catalogue_id` the same way.

- [ ] **Step 8: Run**

Run: `flutter test test/core/database test/features/dive_sites/data/repositories test/core/services/sync/sync_record_overlay_site_catalogue_id_test.dart test/features/dive_log/data/repositories/dive_repository_site_mapping_test.dart test/features/settings/presentation/conflicts test/features/agent_access/data/resources/schema_resource_test.dart test/l10n`
Expected: PASS. `test/core/database` includes `fresh_schema_declared_columns_test.dart` and `migration_column_names_test.dart`, which check the literal column name.

- [ ] **Step 9: Commit**

```bash
git add lib/core/database lib/features/dive_sites lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart lib/features/agent_access/data/resources/sql_column_notes.generated.dart lib/l10n test/core/database/migration_v362_site_catalogue_id_test.dart test/features/dive_sites/data/repositories/site_catalogue_link_test.dart test/core/services/sync/sync_record_overlay_site_catalogue_id_test.dart test/features/dive_log/data/repositories/dive_repository_site_mapping_test.dart
git commit -m "feat(dive-sites): store the catalogue record a site was adopted from"
```

---

### Task 7: The link in UDDF

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildSiteElement`, beside `mooringnumber` at :118-120)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseFullSite`, beside :1036)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_importSites`: the new-site path at :2175-2199 and the override path at :2075-2104)
- Test: `test/core/services/export/uddf/uddf_site_catalogue_link_round_trip_test.dart`

**Interfaces:**
- Consumes: Task 6 (`DiveSite.catalogueId`).
- Produces: UDDF site element `<catalogueid>`, parsed into the site map under the key `catalogueId`.

- [ ] **Step 1: Write the failing round-trip tests**

Model them on `uddf_site_features_round_trip_test.dart` (export with `UddfFullExportService().generateAllDataXmlForTest`, reset the database, restore through `UddfImportParser().parse` and `UddfEntityImporter().import`):

- `a linked site keeps its link through a backup and restore`.
- `a site without a link writes no catalogueid element` (the XML does not contain `<catalogueid`).
- `importing over an existing site without a link gives it the file's link`.
- `importing over an existing site with a link keeps the site's own`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/services/export/uddf/uddf_site_catalogue_link_round_trip_test.dart`
Expected: FAIL, the restored site's `catalogueId` is null.

- [ ] **Step 3: Implement**

Writer: `if (site.catalogueId != null) builder.element('catalogueid', nest: site.catalogueId);`. Parser: `site['catalogueId'] = getElementText(siteElement, 'catalogueid');`. New-site path: `catalogueId: siteData['catalogueId'] as String?`. Override path: the ordinary update no longer writes the link (Task 6), so add `catalogueId: Value(...)` to the `DiveSitesCompanion` passed to `updateSiteWithImportedMetadata` at :2104, only when the existing site has none and the file has one. The second, simpler exporter in `uddf_export_service.dart:222-282` is left alone; it writes no app-specific site elements.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/core/services/export/uddf`
Expected: PASS.

```bash
git add lib/core/services/export/uddf lib/features/dive_import/data/services/uddf_entity_importer.dart test/core/services/export/uddf/uddf_site_catalogue_link_round_trip_test.dart
git commit -m "feat(dive-sites): carry a site's catalogue link in UDDF"
```

---

### Task 8: Adoption and the hiding rules

**Files:**
- Create: `lib/features/dive_sites/domain/services/catalogue_site_mapping.dart`
- Create: `lib/features/dive_sites/domain/services/catalogue_site_visibility.dart`
- Create: `lib/features/dive_sites/data/services/catalogue_adoption_service.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart`, `lib/features/dive_sites/presentation/providers/site_providers.dart` (`SiteListNotifier`, beside `addSite` at :586)
- Test: `test/features/dive_sites/domain/services/catalogue_site_mapping_test.dart`, `catalogue_site_visibility_test.dart` (same folder), `test/features/dive_sites/data/services/catalogue_adoption_service_test.dart`

**Interfaces:**
- Consumes: Tasks 3 and 6.
- Produces:

```dart
DiveSite catalogueSiteToDiveSite(CatalogueSite site, {String? diverId});
SiteClassification catalogueSiteClassification(CatalogueSite site);

Set<String> linkedCatalogueIds(Iterable<DiveSite> userSites);
List<CatalogueSite> offerableCatalogueSites(
  List<CatalogueSite> sites, List<DiveSite> userSites,
  {required bool byPosition, double radiusMeters = 150});

class CatalogueAdoptionService {
  CatalogueAdoptionService({required SiteRepository siteRepository,
      Future<double?> Function(GeoPoint point)? fetchElevation});
  Future<DiveSite> adopt(CatalogueSite site,
      {required String? diverId, bool fillAltitude = true});
}

final catalogueAdoptionServiceProvider = Provider<CatalogueAdoptionService>(...);
// on SiteListNotifier:
Future<domain.DiveSite> adoptCatalogueSite(CatalogueSite site);
```

`catalogueAdoptionServiceProvider` builds the service from `siteRepositoryProvider` and `elevationServiceProvider.fetchElevation(latitude:, longitude:)`, as `siteMatchingServiceFactoryProvider` does. `adoptCatalogueSite` reads the diver id from `validatedCurrentDiverIdProvider`, calls the service, then reloads the list the way `addSite` does.

- [ ] **Step 1: Write the failing mapping tests**

```dart
test('every catalogue detail reaches the site', () {
  const source = CatalogueSite(
    id: 'osm_node_1', name: 'Salt Pier', location: GeoPoint(12.08, -68.28),
    countryCode: 'BQ', country: 'Caribbean Netherlands', region: 'Kralendijk',
    locality: 'Kralendijk', island: 'Bonaire', bodyOfWater: 'Caribbean Sea',
    waterType: WaterType.salt, minDepth: 5, maxDepth: 15,
    typeIds: ['reef', 'pier'], entryMethods: [EntryMethod.shore],
    features: ['drift'], difficulty: SiteDifficulty.beginner,
    hazards: 'boat traffic', description: 'Pillars.',
    website: 'https://example.org', source: 'osm');
  final site = catalogueSiteToDiveSite(source, diverId: 'diver-1');
  expect(site, const DiveSite(
    id: '', diverId: 'diver-1', name: 'Salt Pier', description: 'Pillars.',
    location: GeoPoint(12.08, -68.28), minDepth: 5, maxDepth: 15,
    difficulty: SiteDifficulty.beginner, waterType: WaterType.salt,
    country: 'Caribbean Netherlands', countryCode: 'BQ', region: 'Kralendijk',
    city: 'Kralendijk', island: 'Bonaire', bodyOfWater: 'Caribbean Sea',
    hazards: 'boat traffic', entryMethods: [EntryMethod.shore],
    catalogueId: 'osm_node_1'));
  expect(catalogueSiteClassification(source).typeIds, ['reef', 'pier']);
});
```

Also: `nothing is written into notes or description beyond the catalogue's own text` (a site with features and no description gets `description` `''` and `notes` `''`); `exit methods, rating, access notes, parking, mooring and altitude are left empty`; `a site without coordinates maps to a site without a location` (Review Focus 5).

- [ ] **Step 2: Write the failing visibility tests**

- `a linked site hides its own record`.
- `a linked site does not hide a neighbour 100 m away` ("Barracuda East" adopted, "Barracuda West" 100 m off still offered, with `byPosition: true`).
- `an unlinked site within 150 m hides the record when byPosition is true`, and does not at 151 m.
- `byPosition false hides by link only`.
- `a record without coordinates is hidden only by link` (Review Focus 5).
- `a diver site without coordinates hides nothing by position`.
- `linkedCatalogueIds collects the non-null links`.

- [ ] **Step 3: Write the failing adoption tests**

With `setUpTestDatabase()` and a real `SiteRepository`:

- `adopting creates the site with its types and link`: read back by id; `siteTypesForSite` (or the repository's read of the junction) lists the type ids.
- `adopting twice returns the first site` (the same id, one row).
- `two divers each get their own site`.
- `altitude is filled after the site exists`: `fetchElevation` returns 120; after the returned future and a pump of the event queue the stored site has altitude 120. `adopt` itself does not wait for the lookup: a `fetchElevation` that never completes still lets `adopt` return.
- `fillAltitude false never calls fetchElevation`.
- `a failing elevation lookup is swallowed`.
- `a site without coordinates is adopted without an elevation lookup` (Review Focus 5).

- [ ] **Step 4: Run and see them fail**

Run: `flutter test test/features/dive_sites/domain/services/catalogue_site_mapping_test.dart test/features/dive_sites/domain/services/catalogue_site_visibility_test.dart test/features/dive_sites/data/services/catalogue_adoption_service_test.dart`
Expected: FAIL, undefined names.

- [ ] **Step 5: Implement**

`offerableCatalogueSites` reuses the grid from `built_in_site_dedup.dart` (1 degree cells, own and adjacent cells) over the diver's unlinked, located sites. `adopt`: `getSiteByCatalogueId` first; else `createSite(catalogueSiteToDiveSite(...), classification: catalogueSiteClassification(...))`; then, when `fillAltitude` and the site has a location and a `fetchElevation`, start the lookup without awaiting it and write `updateSiteAltitude` when it answers, catching and logging any error.

- [ ] **Step 6: Run and commit**

Run the three test files, then `flutter test test/architecture test/shared`.
Expected: PASS.

```bash
git add lib/features/dive_sites/domain/services/catalogue_site_mapping.dart lib/features/dive_sites/domain/services/catalogue_site_visibility.dart lib/features/dive_sites/data/services/catalogue_adoption_service.dart lib/features/dive_sites/presentation/providers test/features/dive_sites/domain/services test/features/dive_sites/data/services/catalogue_adoption_service_test.dart
git commit -m "feat(dive-sites): adopt a catalogue site through one path and decide which are offered"
```

---

### Task 9: Move the existing screens onto the catalogue

Three parts, committed separately. After the third, `ExternalDiveSite` and `DiveSiteApiService` are gone.

**Files:**
- Part A: `lib/features/dive_sites/data/services/site_matching_service.dart`, `lib/features/dive_sites/presentation/providers/site_suggestion_providers.dart`; tests `test/features/dive_sites/data/services/site_matching_service_test.dart`, `site_suggestion_providers_test.dart`, `site_match_review_notifier_test.dart`, `test/features/dive_log/presentation/support/fake_matching_service.dart`
- Part B: `lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart`, `widgets/built_in_site_marker_layer.dart`, `widgets/built_in_site_info_card.dart`, `pages/site_map_page.dart` (:17, :335-346, :585-633), `widgets/site_map_content.dart` (:13, :319-328, :586-634); tests `visible_built_in_sites_provider_test.dart`, `site_map_page_built_in_test.dart`, `site_map_content_built_in_test.dart`, `built_in_site_marker_layer_test.dart`, `built_in_site_info_card_test.dart`
- Part C: `lib/features/dive_sites/presentation/providers/site_providers.dart` (:805-994), `pages/site_import_page.dart`; delete `dive_site_api_service.dart`, `built_in_site_dedup.dart`, `external_dive_site_types_test.dart`, `dive_site_api_service_built_in_test.dart`, `built_in_site_dedup_test.dart`; `lib/features/safety/presentation/pages/chambers_directory_page.dart:104` (a comment naming the old service)

**Interfaces:**
- Consumes: Tasks 3, 5, 8.
- Produces:
  - `SiteMatchingService({required SiteRepository siteRepository, required SiteCatalogue catalogue, required CatalogueAdoptionService adoption, required DiveRepository diveRepository, required MediaRepository mediaRepository, required this.diverId, required this.thresholds, TransactionRunner? runInTransaction, this.fetchElevation})`
  - `builtInSitesProvider` and `visibleBuiltInSitesProvider` typed `FutureProvider<List<CatalogueSite>>`
  - `BuiltInSiteMarkerLayer({required List<CatalogueSite> sites, required String? selectedCatalogueId, required void Function(CatalogueSite) onTap})`, marker key `Key('builtInPin_${site.id}')`
  - `BuiltInSiteInfoCard({required CatalogueSite site, required String actionLabel, required Future<void> Function() onAction})`
  - `Future<void> showCatalogueSiteDetails(BuildContext context, {required CatalogueSite site, required String actionLabel, required Future<void> Function() onAction})` in `built_in_site_info_card.dart`: a modal bottom sheet holding the card (Task 11 calls it from the picker)
  - `ExternalSiteSearchState.sites` typed `List<CatalogueSite>`, plus `Set<String> linkedCatalogueIds`; `ExternalSiteSearchNotifier.importSite(CatalogueSite site)`

**Part A: GPS matching**

- [ ] **Step 1: Change the tests first**

In `site_matching_service_test.dart`, build the service with a `FakeSiteCatalogue` and a real `CatalogueAdoptionService`. Keep every existing assertion about linking, batch dedup and the 100 m reuse. Add:
- `a created site carries the catalogue's details and link`: a bundled candidate with depth, entry and types yields a site with `catalogueId`, `maxDepth`, `entryMethods` and the site types.
- `a created site has no imported-from note`: `notes` is `''`.
- `a candidate the diver already adopted is linked, not created again`: the diver has a site linked to the candidate's id 400 m from the dive point; applying links the dive to it and creates nothing.

Update `fake_matching_service.dart` and the two other tests for the new constructor and types.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

`_CandidateRef.bundled` holds a `CatalogueSite`. `computeProposals` asks `catalogue.near(point, radiusMeters: thresholds.outerRadiusMeters)`. `_viewFor` fills `minDepth` and `maxDepth`. In `_applyOne`, the bundled branch keeps its batch dedup and 100 m guard, then calls `adoption.adopt(bundled, diverId: diverId, fillAltitude: false)` and records the site for the service's own `_fillAltitudes`, which still runs after the transaction. `siteMatchingServiceFactoryProvider` passes `siteCatalogueProvider` and `catalogueAdoptionServiceProvider`.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/dive_sites/data/services test/features/dive_sites/presentation/providers test/features/dive_log/presentation`
Expected: PASS.

```bash
git commit -am "refactor(dive-sites): match dives against the site catalogue"
```

**Part B: Map overlay and details card**

- [ ] **Step 5: Change the tests first**

- Provider test: `visibleBuiltInSitesProvider` uses `offerableCatalogueSites(..., byPosition: true)`, so a linked site hides only its own record and a neighbour 100 m off stays; it recomputes when `siteCatalogueRevisionProvider` changes.
- Info card test: the card shows the name, the location line, the depth range through the diver's units (a `maxDepth` of 30 reads "98 ft" under imperial settings), the type names, entry method names, hazards, description, website, and the source credit from `catalogueSourceProvider`; fields the site lacks render nothing; the action button carries `actionLabel` and calls `onAction` once per tap while it runs.
- Map page and content tests: "Add to my sites" creates a site with `catalogueId` set and runs the after-create rules.

- [ ] **Step 6: Run, implement, run**

`builtInSitesProvider` watches `siteCatalogueRevisionProvider` and returns `ref.watch(siteCatalogueProvider).allWithCoordinates()`. `_addBuiltInSite` in both map files keeps its `captureRulesAfterCreate` and snackbar code and replaces the `addSite(site.toDiveSite(), ...)` call with `ref.read(siteListNotifierProvider.notifier).adoptCatalogueSite(site)`. The card's action label on the map is the existing `diveSites_map_builtInSites_add`.

Run: `flutter test test/features/dive_sites/presentation`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git commit -am "refactor(dive-sites): draw the map's built-in sites from the catalogue"
```

**Part C: Import page, then delete the old service**

- [ ] **Step 8: Change the tests first**

For the notifier and page: a search calls `catalogue.search(query, limit: 200)`; a result whose id is in the diver's `linkedCatalogueIds` shows the existing "Already Imported" state (`diveSites_import_detail_alreadyImported`) on first load, with no session flag; importing calls `adoptCatalogueSite`, runs the after-create rules and flips that row; a result within 150 m of an unlinked site of the diver's is still offered (the position rule does not apply here).

- [ ] **Step 9: Implement and delete**

`ExternalSiteSearchNotifier` takes a `SiteCatalogue`. `searchByCountry(country)` calls `search(country, limit: 200)`. Remove `_importedIds` from the page. Delete `diveSiteApiServiceProvider`, the two old files and their three tests, and reword the comment in `chambers_directory_page.dart`.

- [ ] **Step 10: Run and commit**

Run: `grep -rn "ExternalDiveSite\|DiveSiteApiService\|dive_site_api_service\|built_in_site_dedup" lib test`
Expected: no output.

Run: `flutter analyze && flutter test test/features/dive_sites test/architecture test/shared`
Expected: no issues, PASS.

```bash
git add -A lib/features/dive_sites lib/features/safety test/features/dive_sites
git commit -m "refactor(dive-sites): search the catalogue from the import page and retire the old loader"
```

---

### Task 10: The area anchor

**Files:**
- Create: `lib/features/dive_sites/domain/models/site_area_anchor.dart`
- Create: `lib/features/dive_sites/data/repositories/site_area_anchor_repository.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart`
- Test: `test/features/dive_sites/data/repositories/site_area_anchor_repository_test.dart`

**Interfaces:**
- Produces:

```dart
class SiteAreaAnchor extends Equatable {
  const SiteAreaAnchor({required this.point, this.placeLabel});
  final GeoPoint point;
  final String? placeLabel; // the site's island, else region, else country
}

class SiteAreaAnchorRepository {
  SiteAreaAnchorRepository({AppDatabase? database});
  static const Duration window = Duration(days: 3);
  Future<SiteAreaAnchor?> forDive({required DateTime at, String? tripId,
      String? diverId, List<String> excludeDiveIds = const []});
  Future<SiteAreaAnchor?> forDives(List<String> diveIds, {String? diverId});
}

final siteAreaAnchorRepositoryProvider = Provider<SiteAreaAnchorRepository>(...);
```

- [ ] **Step 1: Write the failing tests**

With `setUpTestDatabase()`. Build every instant with `DateTime.utc(...)`; the stored times are wall clock stamped as UTC, and CI runs under `TZ=Australia/Sydney`.

- `the nearest dive of the same trip wins, however far in time`: a trip dive 9 days earlier with a located site beats a non-trip dive 1 hour earlier with a located site.
- `without a trip match, the nearest dive within 3 days wins`: candidates at 2 days before and 1 day after; the 1 day one is returned.
- `a dive more than 3 days away is ignored when it is not in the trip` (3 days and 1 minute gives null; exactly 3 days counts).
- `a dive whose site has no coordinates is skipped` (Review Focus 5), and so is a dive with no site.
- `the dive being edited is excluded`.
- `another diver's dives are ignored`.
- `the dive's entry time is used when it has one, else its dive time`: a dive whose `entryTime` puts it nearer wins over one whose only time is `diveDateTime`.
- `the place label is the island, else the region, else the country, else null`.
- `forDives uses the earliest selected dive and its trip, and excludes every selected dive`.
- `forDives with no ids returns null`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_sites/data/repositories/site_area_anchor_repository_test.dart`
Expected: FAIL, undefined names.

- [ ] **Step 3: Implement**

One query joining `dives` to `dive_sites` on `site_id`, where the site's latitude and longitude are not null, the dive's `diver_id` matches (no diver filter when `diverId` is null), and the dive id is not excluded. The dive's time is `COALESCE(entry_time, dive_date_time)`. Order by whether `trip_id` equals `tripId` (matches first, only when `tripId` is not null), then by the absolute difference from `at`. Take the first row that is either a trip match or within `window`. Exact trip id only: a side trip's dives are reached by the 3 day rule.

- [ ] **Step 4: Run and commit**

Run the test file, then `flutter test test/architecture`.
Expected: PASS.

```bash
git add lib/features/dive_sites/domain/models/site_area_anchor.dart lib/features/dive_sites/data/repositories/site_area_anchor_repository.dart lib/features/dive_sites/presentation/providers/site_catalogue_providers.dart test/features/dive_sites/data/repositories/site_area_anchor_repository_test.dart
git commit -m "feat(dive-sites): find the area of a dive from the dives around it"
```

---

### Task 11: Built-in sites in the picker

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_built_in.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_showBulkSitePicker` :2106-2121, `_showSitePicker` :3164-3179), `lib/features/planner/presentation/widgets/plan_dive_site_field.dart` (:60)
- Modify: the 11 ARB files
- Test: `test/features/dive_sites/presentation/widgets/site_picker/site_picker_built_in_test.dart`, `catalogue_site_tile_test.dart`; additions to `pick_or_create_site_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 8, 9 (`showCatalogueSiteDetails`), 10.
- Produces:
  - `showSitePicker(..., bool showBuiltIn = false, SiteAreaAnchor? areaAnchor)`
  - `pickOrCreateSite(..., SiteAreaAnchor? areaAnchor)`, which passes `showBuiltIn: allowCreate`
  - `SitePickerSheet({..., this.showBuiltIn = false, this.areaAnchor})`
  - `CatalogueSiteTile({required CatalogueSite site, required String? distanceText, required VoidCallback? onTap, required VoidCallback onDetails})`
  - `String catalogueSiteSummary(CatalogueSite site, UnitFormatter units, AppLocalizations l10n)`

New strings (English; translate the other ten):

| Key | English |
|---|---|
| `diveSites_picker_builtIn_nearPlace` | `More sites near {place}` |
| `diveSites_picker_builtIn_nearby` | `More sites nearby` |
| `diveSites_picker_builtIn_search` | `Built-in sites` |
| `diveSites_picker_builtIn_showAll` | `Show all {count}` |
| `diveSites_picker_builtIn_details` | `Site details` |
| `diveSites_picker_builtIn_useSite` | `Use this site` |
| `diveSites_picker_builtIn_adoptError` | `Could not add this site` |
| `diveLog_sitePicker_sortedByArea` | `Near the sites of your other dives` |

The diver's own nearby section keeps its existing label, "Nearby" (`diveSites_picker_nearby`).

- [ ] **Step 1: Write the failing tile tests**

- `the summary joins what the site has`: location (`island`, else `region`, else `country`), entry method names, depth range, type names, joined with " · ". Depths go through `UnitFormatter.formatDepth`: with metric settings a site with min 5 and max 15 shows the two formatted depths joined by an en dash as a range; with only a maximum it shows that one depth; with imperial settings the values are in feet. Missing parts leave no stray separator; a site with nothing else returns an empty string and the tile then has no subtitle.
- `the details button is an IconButton with the details tooltip`, and tapping it calls `onDetails` and not `onTap`.
- `a null onTap disables the row`.

- [ ] **Step 2: Write the failing picker tests**

Extend the `_pump` helper pattern of `site_picker_sheet_test.dart` in a new file, adding `showBuiltIn`, `areaAnchor`, `siteCatalogueProvider.overrideWithValue(FakeSiteCatalogue(...))`, and an override of `siteListNotifierProvider` or `catalogueAdoptionServiceProvider` so adoption stays in memory.

- `the flag off shows no built-in sites and never queries the catalogue` (the fake's call counts are 0), including while searching.
- `with a dive location, built-in sites within 50 km are listed under "More sites nearby", nearest first, with distances`.
- `with an inferred area, they are listed by name under "More sites near Bonaire" with no distances`, the header caption reads "Near the sites of your other dives", and the diver's own nearby sites are listed by name too.
- `an inferred area suppresses the device location request` (the fake location service's `calls` is 0).
- `the section shows five rows, then "Show all 9", which expands it in place`.
- `the diver's own nearby sites come first, then built-in sites, then the grouped list`.
- `a diver with no sites still sees the built-in section` (not only the empty state).
- `a site the diver already adopted is not in the section, and a different catalogue site 100 m from it is`.
- `a catalogue site within 150 m of an unlinked site of the diver's is hidden from the section`.
- `typing two characters searches the catalogue; one character does not`, and results appear under "Built-in sites" after the debounce (`await tester.pump(const Duration(milliseconds: 300))`).
- `search results skip the position rule but not the link rule`.
- `tapping a built-in row adopts once and returns the site`: two quick taps call adoption once; `onSiteSelected` receives a site whose `catalogueId` is the row's id.
- `the after-create rules run before the site is returned`: override `ruleEngineProvider` with a fake that records the call and renames the site; `onSiteSelected` receives the renamed site.
- `a failed adoption keeps the picker open and says so` ("Could not add this site").
- `the details button opens the card, and its "Use this site" adopts and returns`.
- `a catalogue that answers nothing behaves like the flag being off` (Review Focus 4): with `siteCatalogueProvider` left at its default and the local cache service reset, the sheet builds, shows the diver's sites, and `pumpAndSettle` completes.
- `closing the sheet with a search pending leaves no timer` (pump the sheet away within the debounce window; the test must not fail with a pending timer).
- `built-in sites appear when the catalogue becomes ready`: start with an empty fake, fill it and add 1 to `siteCatalogueRevisionProvider`; the section appears without reopening the sheet.

In `pick_or_create_site_test.dart`: `pickOrCreateSite passes showBuiltIn only when allowCreate is true`.

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker`
Expected: the new tests FAIL to compile.

- [ ] **Step 4: Implement the tile**

A `ListTile` with a leading avatar using `Icons.travel_explore`, the name as title, the summary and optional distance as subtitle (the layout `SitePickerSiteTile` uses), and `trailing: IconButton(icon: const Icon(Icons.info_outline), tooltip: l10n.diveSites_picker_builtIn_details, onPressed: onDetails)`. An `IconButton` satisfies `test/architecture/list_tile_trailing_width_test.dart`; a text button or chip there fails it.

- [ ] **Step 5: Implement the section**

`site_picker_built_in.dart` holds the built-in logic so `site_picker_sheet.dart` stays under 800 lines: a mixin or helper class on the sheet's state with

- `_builtInNearby` (`List<CatalogueSite>`), loaded once the anchor is known (in `initState` when it comes from the dive or the area anchor, again when a device fix lands, and again whenever `siteCatalogueRevisionProvider` changes, through `ref.listenManual`) through `catalogue.near(anchor, radiusMeters: 50000)`;
- `_builtInMatches`, loaded 250 ms after the last keystroke when the trimmed query has at least 2 characters, through `catalogue.search(query, areaFirst: anchor, limit: 50)`; the `Timer` is cancelled in `dispose`, and a result for a query that is no longer current is dropped;
- `_showAllBuiltIn` and `_adopting` flags;
- the rows: without a query, the section label (`nearPlace` with `areaAnchor.placeLabel` when the anchor is inferred and has one, else `nearby`), the first five of `offerableCatalogueSites(_builtInNearby, sites, byPosition: true)` (all of them once expanded) and the "Show all N" row; with a query, the "Built-in sites" label and `offerableCatalogueSites(_builtInMatches, sites, byPosition: false)`.

In the sheet: `_anchor` becomes `diveLocation ?? areaAnchor?.point ?? device`; an `_anchorIsInferred` getter is true when the area anchor is the one in use. The device request in `initState` also requires `areaAnchor == null`. When the anchor is inferred, the diver's nearby list and the built-in section sort by name and pass no distance text, and the header shows `diveLog_sitePicker_sortedByArea`. The built-in rows go after the diver's nearby rows and before the grouped list, and also when the diver has no sites or the search matches none of them.

Tap: guard on `_adopting`; `final rulesAfterCreate = captureRulesAfterCreate(context, ref);` then `adoptCatalogueSite`, `await rulesAfterCreate(subject: RuleSubject.sites, ids: [site.id])`, re-read the site with `siteRepositoryProvider.getSiteById` (falling back to the adopted entity), and call `widget.onSiteSelected`. On an exception, show `diveSites_picker_builtIn_adoptError` through `ScaffoldMessenger` and clear the guard. The details button calls `showCatalogueSiteDetails` with `diveSites_picker_builtIn_useSite` and the same tap handler.

- [ ] **Step 6: Pass the anchor from the callers**

- `_showSitePicker`: when the dive has no entry or exit location, `areaAnchor = await ref.read(siteAreaAnchorRepositoryProvider).forDive(at: _currentEntryTime(), tripId: _selectedTrip?.id, diverId: <the existing dive's diver id, else the validated current diver>, excludeDiveIds: [if (widget.diveId != null) widget.diveId!])` inside a try/catch that logs and yields null; check `mounted` before opening the picker.
- `_showBulkSitePicker`: `forDives(widget.bulkDiveIds!, diverId: ...)` the same way.
- `plan_dive_site_field.dart`: add `showBuiltIn: true` to its `showSitePicker` call. It passes no anchor, so built-in sites appear there on search only.
- `site_picker_field.dart`, `media_import_review_page.dart` and `nav_track_import_review_page.dart` are not touched: the first two never set the flag, and the third passes `allowCreate: false`.

- [ ] **Step 7: Strings**

Add the eight keys to all 11 ARB files and run `flutter gen-l10n`.

- [ ] **Step 8: Run**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker test/features/dive_log/presentation/pages test/features/planner test/features/media/presentation/pages/media_import_review_site_picker_test.dart test/l10n test/architecture test/shared`
Expected: PASS. The existing `site_picker_sheet_test.dart` passes unchanged, which shows the flag-off picker is as it was.

- [ ] **Step 9: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_picker lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/planner/presentation/widgets/plan_dive_site_field.dart lib/l10n test/features/dive_sites/presentation/widgets/site_picker
git commit -m "feat(dive-sites): offer built-in sites in the site picker with area memory"
```

---

### Task 12: Demo data generator

**Files:**
- Modify: `tool/demo_data/src/story/catalog.dart` (:6-27, :70-90), `tool/demo_data/src/story/story_plan.dart` (`Destination` at :45), `tool/demo_data/src/story/destinations.dart` (every destination, and `catalogSitesFor` at :531-546), `tool/demo_data/README.md` (:85-88)
- Test: the existing files under `test/tool/demo_data/`

**Interfaces:**
- Produces: `CatalogSite.countryCode` (`String?`); `Destination.siteCountryCode` (required `String`). `Destination.country` keeps its current value and still selects dive centres (`schedule.dart:434`), because `dive_centers.json` is unchanged.

- [ ] **Step 1: Change the tests first**

In `test/tool/demo_data/destinations_test.dart`, add `every destination names the country code of its sites`: for each destination, every site from `catalogSitesFor` has `countryCode == d.siteCountryCode`. The existing tests stay as they are, including `every destination has at least 6 catalogue sites in its area` and the New Jersey tests.

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/tool/demo_data/destinations_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

`Catalog.load` reads `site_catalogue.json` with the keys `lat`, `lon`, `country`, `country_code`, `region`, `description`. `catalogSitesFor` matches `s.countryCode == d.siteCountryCode` in place of the country string; the region and area conditions are unchanged (regions were not converted). Give each destination its code: read it from the converted file for the sites in that destination's area (Bonaire is `BQ`, not `NL`). Update the README paragraph to name the new file.

- [ ] **Step 4: Run every demo tool test**

Run: `flutter test test/tool/demo_data`
Expected: PASS. If a destination drops below 6 sites, its `siteCountryCode` is wrong for its area; fix the code, not the test.

- [ ] **Step 5: Commit**

```bash
git add tool/demo_data test/tool/demo_data
git commit -m "refactor(demo-data): read sites from the catalogue file"
```

The published demo package is built by hand on a maintainer's machine and is not rebuilt here. Say in the PR description that the next build will carry English country names on its sites.

---

### Task 13: Credit, site page, docs and cleanup

**Files:**
- Create: `lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart`
- Modify: `lib/core/bootstrap/bootstrap_shared.dart` (`registerBundledLicenses` at :30-33)
- Modify: `lib/features/dive_sites/presentation/widgets/site_detail_header.dart` (beside `_LibraryLine` at :161)
- Modify: the 11 ARB files; `docs/user/dive-sites.md` (:148-200)
- Delete: `assets/data/dive_sites.json`, `scripts/convert_legacy_dive_sites.py`, `scripts/convert_legacy_dive_sites_test.py`
- Modify: `test/features/dive_sites/data/services/bundled_osm_asset_metadata_test.dart`, `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart`, `scripts/curated_sites_test.py`
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_attribution_test.dart`, additions to `test/features/dive_sites/presentation/widgets/site_detail_header_test.dart`

**Interfaces:**
- Produces: `abstract final class SiteCatalogueAttribution { static const String packageName = 'Dive site data'; static void registerLicense(); }`
- New strings: `diveSites_catalogue_credit` = `From the built-in site catalogue. Source: {source}`; `diveSites_catalogue_website` = `Website`.

The licence page text, exactly:

```
Built-in dive sites (assets/data/site_catalogue.json) contain information
from OpenStreetMap, which is made available under the Open Database
License (ODbL).

© OpenStreetMap contributors
https://www.openstreetmap.org/copyright

The built-in dive site data as a whole is made available under the same
licence. It is published with the scripts that produce it in the
Submersion source repository.
```

- [ ] **Step 1: Write the failing tests**

- Attribution: after `SiteCatalogueAttribution.registerLicense()`, `LicenseRegistry.licenses` yields an entry whose packages are `['Dive site data']` and whose text contains "Open Database License" and "https://www.openstreetmap.org/copyright".
- Header: a site with `catalogueId` whose record and source resolve (override `catalogueSiteProvider` and `catalogueSourceProvider`) shows "From the built-in site catalogue. Source: OpenStreetMap contributors"; with a `website` it shows a "Website" link; a site without a link, or whose record no longer exists, shows neither.

- [ ] **Step 2: Run, implement, run**

Register the licence in `registerBundledLicenses()`. Add a `_CatalogueLine` to the header, shaped like `_LibraryLine`; the website opens with the helper the app already uses for external links (find it by searching `lib/` for `launchUrl`).

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_attribution_test.dart test/features/dive_sites/presentation/widgets/site_detail_header_test.dart`
Expected: PASS.

- [ ] **Step 3: Remove the legacy file and the converter**

Delete the three files. In `site_catalogue_asset_test.dart`, remove the check that reads the legacy file. In `bundled_osm_asset_metadata_test.dart`, replace the `dive_sites.json` entry with `site_catalogue.json` and assert its metadata (`format` 2, `total_count` equal to the number of sites); the centres entry is unchanged. Remove the `skipUnless` added to `curated_sites_test.py` in Task 1.

Run: `grep -rn "dive_sites\.json" lib test tool scripts .github`
Expected: no output. (Older design documents under `docs/design/` mention the file as history and stay as they are.)

- [ ] **Step 4: User documentation**

Update `docs/user/dive-sites.md`: the site picker offers built-in sites near the dive and when searching; tapping one adds it to the diver's sites with its details; where the data comes from and where the credit is shown.

- [ ] **Step 5: Final verification**

Run, in this order:

```bash
dart format .
flutter analyze
python3.14 scripts/site_catalogue_format_test.py && python3.14 scripts/site_country_resolver_test.py && python3.14 scripts/curated_sites_test.py && python3.14 scripts/dive_site_harvester_test.py
python3.14 scripts/check_docs_links.py
flutter test test/architecture test/shared test/l10n test/core/database test/features/dive_sites test/tool/demo_data test/core/services/export/uddf
```

Expected: no format changes left, no analyzer issues, every test passing.

- [ ] **Step 6: Commit**

```bash
git add -A lib/features/dive_sites lib/core/bootstrap/bootstrap_shared.dart lib/l10n docs/user/dive-sites.md assets/data scripts test/features/dive_sites
git commit -m "feat(dive-sites): credit the catalogue's sources and retire the legacy site file"
```

- [ ] **Step 7: Screenshots and PR**

Capture the site picker before this branch and after it (a dive with no GPS in a trip that has one named site), at phone and desktop widths, plus the details card and a linked site's page header. Open the issue, then the PR with `Closes #N`, attaching the screenshots through the project's screenshot gist as `CLAUDE.md` describes.

---

## Decisions this plan makes beyond the spec

- The ordinary site update does not write the link; only create, merge and merge undo do. The spec was corrected to say so.
- A duplicated site does not copy the link, because the duplicate page builds its site from the form.
- Country by coordinates uses the public geocoder with the territory rule the spec now states; the run takes about an hour and is cached.
- Curated records now ship their depth and type, which the old file dropped.
- The diver's own nearby section keeps its "Nearby" label.
- The credit lives on the licence page, where the app's other data credits are; the About dialog itself lists none.
- A side trip's dives are found by the 3 day rule, not by trip id.
