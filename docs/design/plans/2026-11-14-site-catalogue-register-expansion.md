# Site Catalogue Register Expansion (Slice 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the built-in site catalogue from 3,667 to about 21,400 records by harvesting the open wreck and reef registers, and make the app handle register records well.

**Architecture:** A Python package under `scripts/site_catalogue/` holds one fetch-and-parse module per source, each writing a snapshot outside git, plus a network-free merge that applies gates, grouping, overlap, own-terms rules and an offline place lookup and writes `assets/data/site_catalogue.json`. In the app, a record gains a `kind` (dive site or register); the catalogue interface reads by kind and by map bounds; the picker gets a closed register section; GPS matching prefers dive site records; the map overlay loads by viewport.

**Tech Stack:** Python 3 standard library (merge, gates, place lookup; CI runs them with no packages), `requests`/`overpy` only where `scripts/requirements.txt` already lists them; Flutter, Drift (local cache database), Riverpod, flutter_map.

**Spec:** `docs/design/specs/2026-11-14-site-catalogue-register-expansion-design.md`. Read it first; this plan cites its sections as "spec 5" and its appendices as "spec A", "spec B". The program overview is `docs/design/specs/2026-11-13-site-catalogue-program.md`.

## Global Constraints

- Every outside request sends `User-Agent: dive-site-harvester/1.0` and nothing naming a person, an address or the project. A refused request stops that fetch; identifying details are never added.
- Merge, gates, overlap, grouping and place lookup are standard library Python only.
- New script tests are standalone `unittest` files runnable as `python3 scripts/site_catalogue/<name>_test.py`, and each is added to `.github/workflows/ci.yaml` step "Run Python guard tests with coverage" with its module in the `guards` list.
- Snapshots and downloads live in `scripts/.site_catalogue_cache/` (add to `.gitignore`); never committed.
- No em-dashes or spaced hyphens as punctuation in any file, comment, commit or PR text. No mention of the tool or model that wrote the code anywhere.
- Paths are built with `p.join` / `os.path.join` / `Path`, temp space through `Directory.systemTemp` / `tempfile`.
- Every new user-visible string goes in all 11 ARB files under `lib/l10n/arb/`, translated, then `flutter gen-l10n`.
- Depths and distances shown follow the diver's unit settings (existing formatters).
- Files stay under 800 lines. `dart format .` before every commit.
- Never run the whole Flutter suite locally. Run the test files a task names, plus `test/architecture/` and `test/shared/` after adding any `lib/` file.
- Local cache database is schema 21 today; this plan takes 22. If `main` has taken 22 by merge time, renumber.
- Commit messages follow the repository's style (`feat(dive-sites): ...`), one commit per task.
- Gates decide, not counts (spec "Measured facts"). A source more than a tenth away from its expected count is explained in the PR.

## Review Focus

1. A register row with an empty or malformed position, depth or date (blank, "0", "UNKNOWN", a lone hemisphere letter): the parser drops or blanks that value and keeps going; it never raises and never writes 0,0. Tests in Tasks 4 to 6.
2. A snapshot from a source whose columns changed or that returned an error page: the fetch fails loudly naming the missing column; it does not write an empty snapshot that the merge then treats as "this source has no records". Test in Task 2.
3. A position on the antimeridian or near a pole in `inBounds` and the place lookup: bounds that cross 180 degrees return sites on both sides; a point at 179.9 E finds land at 179.9 W. Tests in Tasks 3 and 10.
4. An install that already holds a schema-21 catalogue table: after the ladder step the old rows read as dive site records until the import replaces them, and the import still runs. Test in Task 9.
5. A diver's adopted site whose catalogue id left the catalogue: the picker, the site page and GPS matching show no error and offer nothing stale. Test in Task 11 (picker) reusing the fake with the id absent.

---

## File Structure

```
scripts/site_catalogue/
  records.py            working record, name folding and casing, units, word lists
  snapshots.py          cache folder, HTTP with the fixed client name, snapshot read/write
  places.py             offline country, territory, region, island, lake lookup
  src_ukho.py           UKHO wrecks: fetch, parse, gate
  src_awois.py          AWOIS wrecks
  src_ireland.py        Wreck Inventory of Ireland
  src_reefs.py          FWC, federal reef file (incl. hi_dar, tpwd), NJDEP, NC, Florida Keys
  src_osm.py            OpenStreetMap dive sites (cleaning, geocoding) and wrecks
  src_wikidata.py       Wikidata dive sites and wrecks
  grouping.py           deployments into sites
  overlap.py            same-site rules, survivors, own-terms rule
  merge.py              the command: snapshots in, catalogue out, report
  samples/              a few real rows per source, committed, for parser tests
  *_test.py             one per module
scripts/site_catalogue_format.py   + kind, own_terms, sources, notice, line-per-record writer
scripts/dive_site_harvester.py     dive centres only
scripts/curated_sites.py           unchanged API; merge calls it
assets/data/site_catalogue.json, .version, site_catalogue_njdep_metadata.xml
lib/features/dive_sites/domain/entities/catalogue_site.dart          + CatalogueKind
lib/core/database/local_cache_site_catalogue_tables.dart             + kind column
lib/core/database/local_cache_database.dart                          ladder 22, backstop
lib/features/dive_sites/data/catalogue/*.dart                        parser, mapper, near/count/inBounds/search
lib/features/dive_sites/domain/repositories/site_catalogue.dart      interface
lib/features/dive_sites/presentation/widgets/site_picker/site_picker_register.dart   new: the register section
lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart         by bounds
lib/features/dive_sites/domain/matching/{match_candidate,site_matcher}.dart
lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart
tool/demo_data/src/story/{catalog,destinations}.dart
```

---

### Task 0: Branch, baseline, before screenshots

**Files:** none committed.

- [ ] **Step 1:** `git switch -c ericgriffin/site-catalogue-register-expansion` from the current branch tip (which is `main` plus the two spec files). Run `git submodule update --init --recursive` and `flutter pub get`; confirm `lib/core/database/local_cache_database.g.dart` contains `SiteCatalogueEntries`.
- [ ] **Step 2:** Commit the spec, the program overview change and this plan: `docs(dive-sites): design and plan the open-register catalogue expansion`.
- [ ] **Step 3:** Capture the "before" screenshots the PR needs, before any `lib/` change: the site picker on a dive with GPS near sites (light and dark), and the Sites map with the built-in overlay on, zoomed out. Use a macOS debug build with its own database (`SUBMERSION_DB_PATH`); save under the scratchpad as `before-*.png`.

---

### Task 1: Catalogue format: kind, own terms, sources, line-per-record file

**Files:**
- Modify: `scripts/site_catalogue_format.py`
- Test: `scripts/site_catalogue_format_test.py`

**Interfaces:**
- Produces: `SOURCES` with keys `osm, curated, ukho, awois, fwc, noaa_reefs, fknms, nms_ie, wikidata, njdep, hi_dar, tpwd, nc_dmf`, each `{name, licence, licence_url, credit}` exactly as spec 12's table, and `own_terms` on `njdep, hi_dar, tpwd, nc_dmf`; `OWN_TERMS_SOURCES: tuple[str, ...]`; `KINDS = ("site", "register")`; `to_catalogue_record(legacy, *, source, source_ref, country_code, country, kind="site") -> dict` (writes `"kind": "register"` only for a register record, after `website` and before `source`); `write_catalogue(directory, records, generated_at, *, open_only=False) -> None`.

- [ ] **Step 1: Failing tests** in `site_catalogue_format_test.py`:
  - `test_a_register_record_carries_its_kind_and_a_site_does_not`: `to_catalogue_record({...}, source="ukho", ..., kind="register")["kind"] == "register"`; with `kind="site"` the key is absent.
  - `test_validate_rejects_an_unknown_kind`: a record with `"kind": "other"` yields a problem line containing `kind`.
  - `test_every_own_terms_source_states_its_terms`: for each key in `OWN_TERMS_SOURCES`, `SOURCES[key]["own_terms"]` is a non-empty string; no other source has the key.
  - `test_the_notice_names_every_source_and_the_non_commercial_ones`: `NOTICE` contains each `SOURCES[k]["name"]`, the UKHO statement verbatim (spec 12), the NJDEP disclaimer verbatim (spec 12), "not for navigation", and "may not be used commercially".
  - `test_the_file_is_one_record_per_line_sorted_by_id`: write three records in scrambled order; the file parses as JSON, `sites` ids are sorted, and the text has exactly one line per record (each record line starts with `{"id":`).
  - `test_open_only_leaves_out_own_terms_sources`: with one `njdep` and one `ukho` record, `open_only=True` writes one site, a `sources` map without the four own-terms keys, and a notice without "may not be used commercially".
  - Keep the existing sidecar test: the `.version` is the SHA-256 of the bytes written.
- [ ] **Step 2:** `python3 scripts/site_catalogue_format_test.py`; expect the new tests to fail.
- [ ] **Step 3: Implement.** The file layout is fixed: line 1 `{"metadata":<compact json>,"sites":[`, then one compact record per line joined by `,\n`, then `]}` and a final newline; `ensure_ascii=False`. Records sorted by `id`. `validate_catalogue` adds: `kind` in `KINDS` when present; a register record has `lat` and `lon`; a source in `OWN_TERMS_SOURCES` is declared with `own_terms`.
- [ ] **Step 4:** Run the test file; all pass. Run `python3 scripts/curated_sites_test.py` (still green).
- [ ] **Step 5:** Commit `feat(dive-sites): catalogue format carries record kind and own-terms sources`.

---

### Task 2: Working records and snapshots

**Files:**
- Create: `scripts/site_catalogue/records.py`, `scripts/site_catalogue/snapshots.py`
- Test: `scripts/site_catalogue/records_test.py`, `scripts/site_catalogue/snapshots_test.py`
- Modify: `.gitignore` (add `scripts/.site_catalogue_cache/`)

**Interfaces:**
- Produces (`records.py`):
  - `fold_name(name: str) -> str` (spec 5 rule 1 and spec B lists).
  - `is_placeholder(name: str) -> bool` (spec B).
  - `is_generic(folded: str) -> bool` (spec B list, or under four letters).
  - `display_name(raw: str) -> str` title-cases an upper-case register name.
  - `slug(text: str) -> str` lower-case ASCII, runs of other characters to `_`.
  - `feet(v) -> float`, `fathoms(v) -> float`, `km(lat1, lon1, lat2, lon2) -> float`.
  - `working(*, id, name, lat, lon, source, kind, source_ref=None, types=(), max_depth=None, min_depth=None, description=None, hazards=None, locality=None, region=None, website=None, entry_type=None, features=(), water_type=None, geocoded=None) -> dict`: the working record every source returns. Keys as named; `types` and `features` are lists; a depth of 0 or below becomes `None`; `lat`/`lon` rounded to 6 decimals.
- Produces (`snapshots.py`):
  - `CACHE_DIR: Path` (`scripts/.site_catalogue_cache`), `USER_AGENT = "dive-site-harvester/1.0"`.
  - `http_get(url: str, *, params: dict | None = None, timeout: int = 120) -> bytes` (urllib; raises `RuntimeError` naming the status on a non-200).
  - `write_snapshot(key: str, url: str, rows: list[dict], cache: Path = CACHE_DIR) -> Path`; `read_snapshot(key: str, cache: Path = CACHE_DIR) -> dict` with keys `source, url, fetched_at, rows`; raises `FileNotFoundError` naming the key.
  - `require_fields(row: dict, fields: tuple[str, ...], source: str) -> None` raises `ValueError("<source>: missing column <name>")`.

- [ ] **Step 1: Failing tests.** `records_test.py`:
  - `fold_name("HMS EXETER") == "exeter"`; `fold_name("Moravia (possibly)") == "moravia"`; `fold_name("Épave du Liban") == "du liban"`; `fold_name("Wreck of the Rhone") == "rhone"`; `fold_name("Molasses Reef") == "molasses"`.
  - `display_name("HMS EXETER") == "HMS Exeter"`; `display_name("U 11") == "U 11"`; `display_name("TB. TECE-1") == "TB. Tece-1"`; `display_name("HMS MORAVIA (POSSIBLY)") == "HMS Moravia (possibly)"`; `display_name("Salt Pier") == "Salt Pier"` (mixed case is left alone).
  - `is_placeholder` true for `"UNKNOWN"`, `"Wreck"`, `"Unnamed Barge 1"`, `"Obstruction"`, `""`; false for `"Barge 12"`.
  - `is_generic("tug")` and `is_generic("abc")` true; `is_generic("thistlegorm")` false.
  - `working(..., max_depth=0)["max_depth"] is None`.
  - `round(feet(145), 1) == 44.2`; `round(fathoms(10), 1) == 18.3`.
  `snapshots_test.py`: a snapshot round-trips through a temp cache; `read_snapshot` on a missing key raises `FileNotFoundError` whose message contains the key; `require_fields({"a": 1}, ("a", "b"), "ukho")` raises `ValueError` containing `ukho` and `b`; `http_get` sends exactly `USER_AGENT` (patch `urllib.request.urlopen`, assert the request header) and raises on status 403.
- [ ] **Step 2:** Run both; expect failures.
- [ ] **Step 3: Implement.** Each test and module that imports a sibling or `site_catalogue_format` first puts `scripts/` and `scripts/site_catalogue/` on `sys.path` (three lines at the top, relative to `__file__`). `display_name` only changes a name with no lower-case letters; it keeps these prefixes upper-case: HMS, HMT, HMAS, HMCS, HMNZS, USS, USNS, USAT, USCGC, SS, MV, MT, FV, SV, RMS, RFA, MFV, TSS, SMS, TB, and a leading single letter followed by digits ("U 11").
- [ ] **Step 4:** Run both; pass.
- [ ] **Step 5:** Add both test files and both modules to `ci.yaml` (see Global Constraints). Commit `feat(dive-sites): working records and snapshots for the catalogue harvest`.

---

### Task 3: Offline place lookup

**Files:**
- Create: `scripts/site_catalogue/places.py`
- Test: `scripts/site_catalogue/places_test.py`

**Interfaces:**
- Consumes: `records.km`, `snapshots.http_get`, `snapshots.CACHE_DIR`.
- Produces:
  - `fetch_boundaries(cache: Path = CACHE_DIR) -> None` downloads the three Natural Earth files of spec A into `cache/naturalearth/`.
  - `class UnitIndex: __init__(self, features: list[dict])`; `containing(lat, lon) -> dict | None` (a feature's `properties`); `nearest(lat, lon, max_km) -> tuple[dict, float] | None`.
  - `Place = namedtuple("Place", "country_code country region island fresh at_sea")`.
  - `class Places: __init__(self, units: UnitIndex, regions: UnitIndex, lakes: UnitIndex, name_for_code: Callable[[str], str])`; `place(lat, lon) -> Place`; `settle(geocoded: tuple[str | None, str | None, str | None], lat, lon) -> Place` (the rule for OpenStreetMap dive sites, spec 7).
  - `load_places(cache: Path = CACHE_DIR, dart_names: Path = <repo>/lib/core/geography/country_names.generated.dart) -> Places`.
  - `english_name(code: str, candidate: str, known: dict[str, str]) -> str` raises `ValueError` naming the code and candidate when the folded candidate does not map to that code in the app's table.

- [ ] **Step 1: Failing tests**, all on tiny hand-made GeoJSON squares (no download):
  - A point inside square A returns A's properties; a point 30 km off A's edge returns `(A, about 30)` from `nearest(..., 370)` and `None` from `nearest(..., 10)`.
  - Two units, a state and a territory square with its own `ISO_A2_EH`: `place` inside the territory gives the territory's code; `settle(("FR", "France", None), lat, lon)` inside it gives the territory's code; `settle(("CH", "Switzerland", None), ...)` at a point the offline index puts in a different sovereign state keeps `CH`; `settle((None, None, None), ...)` uses the offline answer.
  - A unit with `ISO_A2_EH == "-99"` takes its parent's code (the feature whose `ADM0_A3` it shares and that has a code).
  - A point inside a lake square has `fresh=True`; outside, `False`.
  - A unit across the antimeridian: a point at 179.95 finds a unit whose ring sits at -179.9, within 20 km.
  - Region: inside a first-level square gives its `name_en`; 30 km outside gives it; 80 km outside gives `None`; a region of another country is never used.
  - Island: a first-level unit with `iso_3166_2 == "BQ-BO"` gives island "Bonaire" (reuse `SUBDIVISION_ISLANDS` from `site_country_resolver.py`).
  - `english_name("FM", "Federated States of Micronesia", known)` returns "Micronesia" (override) and an unknown pairing raises.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** Containment: per-ring bounding box, then crossing number, holes subtract. Nearest: bucket every ring vertex into 1 degree cells keyed by floored lat and lon (longitude wrapped); search the point's cell and outward ring by ring until a vertex is found, then one ring more, and take the minimum `km`; vertex distance stands in for edge distance (Natural Earth 10m vertices are about a kilometre apart). Cache answers by position rounded to 4 decimals. `place`: unit containing, else nearest within 370 km; region containing, else nearest within 50 km with the same `iso_a2`; `at_sea` true when not inside any unit. The known-names table is parsed from the generated Dart map with a regular expression; folding matches `countryLookupKey` (lower-case, accents stripped, punctuation to spaces).
- [ ] **Step 4:** Run; pass.
- [ ] **Step 5:** CI wiring; commit `feat(dive-sites): offline country, territory and region lookup for catalogue records`.

---

### Task 4: Wreck registers: UKHO, AWOIS, Ireland

**Files:**
- Create: `scripts/site_catalogue/src_ukho.py`, `src_awois.py`, `src_ireland.py`, and `samples/ukho.tsv`, `samples/awois.kml`, `samples/ireland.csv`
- Test: `scripts/site_catalogue/src_ukho_test.py`, `src_awois_test.py`, `src_ireland_test.py`

**Interfaces:**
- Consumes: `records.*`, `snapshots.*`.
- Produces, in each module: `KEY: str` (`"ukho"`, `"awois"`, `"nms_ie"`); `URL: str` (spec A); `fetch() -> Path` (downloads, parses to rows, writes the snapshot); `parse(raw: bytes) -> list[dict]` (rows with the source's own column names, strings); `records(rows: list[dict]) -> tuple[list[dict], collections.Counter]` (working records that pass the gate, and a count per drop reason).
- Drop reason keys (used by the merge report and the tests): `no_name`, `no_position`, `dead`, `doubtful`, `not_submerged`, `not_wreck`, `coarse_position`, `too_shallow`, `too_deep`, `diving_prohibited` (UKHO); `no_name`, `low_quality`, `visible`, `removed`, `too_deep` (AWOIS); `no_name`, `no_position`, `excluded_source`, `unstated_source`, `coarse_position` (Ireland).

- [ ] **Step 1: Samples.** Copy 12 to 20 real rows per source from the downloaded files into `samples/`, in the source's exact format (UKHO: header line plus rows, tab-separated, quoted, CRLF; AWOIS: a KML document with a few `Placemark`s; Ireland: header plus rows with the byte order mark). Choose rows so every drop reason and every pass path has at least one row. Keep UKHO's free-text columns short (trim `circumstances_of_loss`, `surveying_details` to empty) so the sample holds no long quoted text.
- [ ] **Step 2: Failing tests.** For each module, against its sample:
  - `parse` returns the expected row count and `require_fields` rejects a header with a column removed (Review Focus 2).
  - UKHO, each asserted on a named sample row: `status` "dead" drops as `dead`; `water_level_effect` "covers and uncovers" drops as `not_submerged`; `obstruction_category` "foul ground" drops as `not_wreck`; position "6 0 S" / "110 10 E" with empty `position_method` drops as `coarse_position`, and the same precision with `position_method` set passes; `water_depth` 1 drops as `too_shallow`, 61 as `too_deep`; a `general_comments` that reads "No fishing, diving, anchoring" after its "Restricted Area" label drops as `diving_prohibited`.
  - UKHO pass row: id `ukho_<wreck_id>`; name through `display_name`; `lat`/`lon` from degrees and decimal minutes with hemisphere (`"51 20.55 N"` is 51.3425); `max_depth` = `water_depth`; `min_depth` = `depth` only when less; `types == ["wreck"]`; `kind == "register"`; description `"Steam ship, lost 1916"` from `type` "steam ship" and `date_sunk` "19160902", `"Trawler"` when the date is empty, `None` when both are; hazards is the register's sentence in sentence case for a comment matching spec B's hazard list (`"Rest'D area 300m radius. Fishing and Anchoring Prohibited."` becomes `"Rest'd area 300m radius. Fishing and anchoring prohibited."`), else `None`.
  - A UKHO row with an empty latitude, or `"UNKNOWN"` in a numeric column, drops as `no_position` or treats the number as absent; nothing raises (Review Focus 1).
  - AWOIS: `GP_QUALITY` "Low" drops as `low_quality`; `FEATURE_TYPE` "Wreck, visible" as `visible`; a history ending "RECOMMENDED REMOVAL FROM CHART... REPORTED REMOVED." as `removed`; `VESSLTERMS` "UNKNOWN" as `no_name`; `DEPTH` 30 with "Feet and tenths" gives `max_depth` 9.1, with "Fathoms and tenths" 54.9, `DEPTH` 0 gives `None`; a depth over 60 m drops as `too_deep`; id `awois_<RECRD>`; `source_ref` is the archive URL.
  - Ireland: "Source of Co-ordinate" containing "wrecksite" or "uboat" drops as `excluded_source`; "Lloyd's List" as `excluded_source`; empty as `unstated_source`; `DD_Lat` "53.9" as `coarse_position`; `0` as `no_position`; "Ardmore (SS)" is named "Ardmore"; description `"Steamship, lost 1894"` from `Classification` and the year column; id `ie_<Wreck No>`.
- [ ] **Step 3:** Run the three test files; fail.
- [ ] **Step 4: Implement** per spec 1, 2 and A. UKHO file is Latin-1; read with `csv.DictReader(delimiter="\t")` and a raised `csv.field_size_limit`. The UKHO download is a zip; `fetch` reads `Wrecks.txt` from it. AWOIS rows come from each placemark's HTML table (`<th>` field, `<td>` value), unescaped.
- [ ] **Step 5:** Run; pass. CI wiring. Commit `feat(dive-sites): UKHO, AWOIS and Irish wreck register sources`.

---

### Task 5: Reef sources and grouping

**Files:**
- Create: `scripts/site_catalogue/grouping.py`, `src_reefs.py`, `samples/fwc.geojson`, `samples/federal_reefs.json`, `samples/njdep.json`, `samples/nc_dmf.json`, `samples/fknms.geojson`
- Test: `scripts/site_catalogue/grouping_test.py`, `src_reefs_test.py`

**Interfaces:**
- Produces (`grouping.py`): `group_by_name(items: list[dict], *, radius_km: float = 1.0, name_of=lambda i: i["name"]) -> list[list[dict]]` (same folded name, single-linked within the radius); `mean_position(items) -> tuple[float, float]`.
- Produces (`src_reefs.py`): for each of `fwc`, `federal`, `njdep`, `nc_dmf`, `fknms` a `fetch_<name>() -> Path` and a `<name>_records(rows) -> tuple[list[dict], Counter]`. `federal_records` returns records with source `noaa_reefs`, `hi_dar` or `tpwd` by state. Drop reasons: `no_name`, `too_deep`, `excluded_state`, `not_mooring`.
- `EXCLUDED_STATES = ("FL", "NJ", "NC", "NY")`; `OWN_TERMS_STATES = {"HI": "hi_dar", "TX": "tpwd"}`.

- [ ] **Step 1: Samples**, real rows: FWC with one reef of three deployments within 1 km, one namesake 5 km away, a vessel, a deep one, an "Unnamed" one; the federal file as a small JSON list of row dicts (the test does not need a GeoPackage) covering AL, SC, HI, TX, NY, NJ, NC, FL; NJDEP rows for one reef site with a vessel and two "Subway Car" rows; NC rows with and without `REEF_NAME`; Keys buoys for one reef with three moorings, one wreck mooring, one spar buoy.
- [ ] **Step 2: Failing tests.**
  - Grouping: three points of one name within 1 km are one group; the namesake 5 km away is its own; names differing only by case or a ship prefix group together.
  - FWC: the three deployments become one record at their mean position with the deepest depth, id `fwc_<lowest DeployID>`, `types == ["artificial_reef"]`; a `MatCat` "Vessel" group also has `wreck`; `max_depth` = `Depth` feet in metres, `min_depth` = depth less `Relief` when relief is positive; description `"Reefmaker Florida Limestone (1), placed 2014"`; over 60 m drops as `too_deep`; "Unnamed 2" as `no_name`.
  - Federal: NY, NJ, NC and FL rows drop as `excluded_state`; an AL row is source `noaa_reefs` with id `usreef_al_<slug>_<lat to 0.1>_<lon to 0.1>`; an HI row is source `hi_dar`, a TX row `tpwd`; `source_ref` is the state program's page (a `STATE_PAGES` dict, URLs from the spec's licence findings and the federal metadata).
  - NJDEP: the vessel is named by `NAME` with `locality` "Cape May Reef"; the two subway car rows within 1 km become one record named "Cape May Reef, Subway Car"; id `njreef_<lowest UNIQUE_ID>`; no depth; source `njdep`.
  - NC: one record per row, never grouped; name is `REEF_NAME` or else `REEF__`; id `ncreef_<slug of REEF__>`; no depth, no description; position exactly the geometry's.
  - Keys: the spar buoy drops as `not_mooring`; three moorings of one `Location` are one record at their mean, `kind == "site"`, `types == ["reef"]`, `max_depth` deepest and `min_depth` shallowest; "The Spiegel Grove" is named "Spiegel Grove" with `types == ["wreck"]`; id `fknms_spiegel_grove`.
- [ ] **Step 3:** Run; fail.
- [ ] **Step 4: Implement.** `fetch_federal` downloads the zip, opens the GeoPackage with `sqlite3`, and reads the attribute columns of spec A plus `latitudeDMS`/`longitudeDMS` (degrees, minutes, seconds and hemisphere) for the position, so no geometry blob is parsed. ArcGIS sources page with `resultOffset` at the layer's page size with a one second pause.
- [ ] **Step 5:** Run; pass. CI wiring. Commit `feat(dive-sites): artificial reef and mooring sources with deployment grouping`.

---

### Task 6: OpenStreetMap and Wikidata sources

**Files:**
- Create: `scripts/site_catalogue/src_osm.py`, `src_wikidata.py`, `samples/osm_scuba.json`, `samples/osm_wrecks.json`, `samples/wikidata_sites.json`, `samples/wikidata_wrecks.json`
- Modify: `scripts/site_country_resolver.py` (`NOMINATIM_USER_AGENT` becomes `"dive-site-harvester/1.0"`), `scripts/dive_site_harvester.py` (same constant)
- Test: `scripts/site_catalogue/src_osm_test.py`, `src_wikidata_test.py`; update `scripts/site_country_resolver_test.py` if it pins the old client name

**Interfaces:**
- Produces (`src_osm.py`): `fetch_sites(resolver=None) -> Path` (one worldwide Overpass query `nwr["sport"="scuba_diving"]; out center tags;`, then the cached `CountryResolver.lookup_place` for each located element, stored on the row as `geocoded: [code, name, island]`); `fetch_wrecks() -> Path`; `is_business(tags: dict, name: str) -> bool`; `site_records(rows) -> tuple[list[dict], Counter]` (source `osm`, kind `site`); `wreck_records(rows) -> tuple[list[dict], Counter]` (source `osm`, kind `register`). Drop reasons: `no_name`, `business`, `scuba_tagged`, `visible`, `no_access`, `not_a_ship`, `too_deep`.
- Produces (`src_wikidata.py`): `fetch() -> Path` (two snapshots, keys `wikidata_sites`, `wikidata_wrecks`); `site_records(rows)`, `wreck_records(rows)`. Drop reasons: `no_label`, `not_on_earth`, `no_article`, `coarse_position`.

- [ ] **Step 1: Failing tests.**
  - `is_business`: true for `amenity=dive_centre`; any `shop`; `club`; `office`; `scuba_diving:rental=yes`; `tourism=hotel`; `leisure=sports_centre`; a name "Blue Water Dive Center" with no tags; false for the same tags plus `scuba_diving:divespot=yes`; false for a plain `sport=scuba_diving` node named "Salt Pier".
  - Site records: a way with only a `center` gets that position; id `osm_way_<id>`; `types` from tags (`historic=wreck` gives wreck, `natural=reef` reef, `natural=cave_entrance` cave, `natural=spring` spring, `water=lake` lake with `water_type == "fresh"`, `water=quarry` or `landuse=quarry` quarry with fresh); existing depth, entry, hazard, website and description handling is unchanged from `dive_site_harvester.transform_to_catalogue_record` (assert on one sample that the output equals what that function returns today, apart from region, country and the new types); the row's `geocoded` is carried on the working record; a site with no position still passes.
  - Wreck records: a wreck that also has `sport=scuba_diving` drops as `scuba_tagged`; `wreck:visible_at_high_tide=yes` and `seamark:wreck:category=hull_showing` drop as `visible`; `access=private` as `no_access`; `wreck:type=car` as `not_a_ship`; `wreck:depth=75` as `too_deep`; a pass row has kind `register`, `types == ["wreck"]`, `max_depth` from the first of `wreck:depth`, `depth`, `seamark:wreck:depth`.
  - Wikidata: a wreck with no sitelink count drops as `no_article`; a coordinate whose precision is one arc-minute or coarser drops as `coarse_position`; a coordinate not on Earth as `not_on_earth`; a label equal to the Q id as `no_label`; ids `wikidata_<Q id>`; dive sites are kind `site`, wrecks `register` with `types == ["wreck"]`; `source_ref` is `https://www.wikidata.org/wiki/<Q id>`.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** Wikidata rows carry `item, label, lat, lon, precision, sitelinks`; read the precision with `p:P625/psv:P625` and `wikibase:geoPrecision`, the globe with `wikibase:geoGlobe`, and count Wikipedia sitelinks with `schema:about` and `schema:isPartOf` matching a Wikipedia host. Classes and events are in spec A. Pause two seconds between queries; split a query that times out. Overpass: `[out:json][timeout:600]`; on 429 or 504 wait 60 seconds and retry once, then stop.
- [ ] **Step 4:** Run; pass, with `python3 scripts/site_country_resolver_test.py` and `python3 scripts/dive_site_harvester_test.py` (after `pip install -r scripts/requirements.txt` in a venv).
- [ ] **Step 5:** CI wiring. Commit `feat(dive-sites): OpenStreetMap and Wikidata catalogue sources`.

---

### Task 7: Overlap and own-terms rules

**Files:**
- Create: `scripts/site_catalogue/overlap.py`
- Test: `scripts/site_catalogue/overlap_test.py`

**Interfaces:**
- Consumes: `records.fold_name`, `records.is_generic`, `records.km`, `site_catalogue_format.OWN_TERMS_SOURCES`.
- Produces: `RANK: list[tuple[str, str]]` (source, kind) in spec 5's order, own-terms sources last; `same_site(a: dict, b: dict) -> bool`; `resolve(records: list[dict]) -> tuple[list[dict], collections.Counter]` returning survivors and a count per `(loser source, winner source)`.

- [ ] **Step 1: Failing tests** (records built with `records.working`):
  - Rule 1: "HMS Exeter" (`ukho`) and "Exeter" (`osm` register) 1.5 km apart are the same; 2.5 km apart are not.
  - A generic name: two "Barge" records 500 m apart are not the same; 150 m apart are.
  - "Portsea Pier" and "Portsea Pier West Reef" 190 m apart are not the same (a name that begins with another).
  - Rule 2: two wrecks of different names, `ukho` and `awois`, 80 m apart are the same; 120 m apart are not; two wrecks of one source 80 m apart with different names are not; two `osm` dive site wrecks are not.
  - Dive site sources: two `osm` kind `site` records of the same name 50 m apart both survive; two `curated` likewise; a `curated` record steps aside for an `osm` site of the same name (ignoring case) 900 m away and not for one 1.1 km away.
  - Survivors: `osm` site beats `ukho`; `ukho` beats `awois`; `awois` beats `nms_ie`; `fknms` beats `fwc`; within `ukho` the lower id wins.
  - Taking: the surviving `osm` site with no depth takes `max_depth`, `min_depth`, `types` (appended, no repeats), `description` and `hazards` from the `ukho` loser, each only where its own is empty, and keeps its id, name, position, source, source_ref and kind `site`.
  - Own terms: an `njdep` record matching a `curated` wreck is left out and the curated record is unchanged (no field taken); an `njdep` record matching a `ukho` record is left out; an `njdep` record never gives a depth to another record; two `nc_dmf` records are never merged with each other.
  - `resolve` is deterministic: the same input in a different order gives the same survivors.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** Sort by `(rank, id)`; keep survivors in a grid of 0.02 degree cells and test each incoming record against the nine cells around it (rule 1's 2 km fits inside that neighbourhood below 80 degrees of latitude; above that, widen the longitude span by `1/cos(lat)`).
- [ ] **Step 4:** Run; pass.
- [ ] **Step 5:** CI wiring. Commit `feat(dive-sites): overlap rules between catalogue sources`.

---

### Task 8: The merge command

**Files:**
- Create: `scripts/site_catalogue/merge.py`
- Modify: `scripts/dive_site_harvester.py` (remove the site catalogue half: `transform_to_catalogue_record`, the curated merge and `write_catalogue` call; it writes `dive_centers.json` only; keep `utc_timestamp` and everything its test checks), `scripts/dive_site_harvester_test.py` (follow), `scripts/requirements.txt` (comment only: the site catalogue needs no packages beyond these)
- Test: `scripts/site_catalogue/merge_test.py`

**Interfaces:**
- Consumes: every `*_records` function, `grouping`, `overlap.resolve`, `places.load_places`, `curated_sites.load_curated`/`curated_record`, `site_catalogue_format.to_catalogue_record`/`write_catalogue`.
- Produces: `SOURCE_STEPS: dict[str, Callable]` mapping each snapshot key to its records function; `build(snapshots: dict[str, list[dict]], curated: list[dict], places) -> tuple[list[dict], dict]` returning catalogue records and a report dict `{source: {"read": n, "dropped": {reason: n}, "overlap": {winner: n}, "written": n}}`; `id_changes(old_ids: set[str], new_ids: set[str]) -> dict` with `gone` and `new` lists grouped by id prefix; `main(argv) -> int`.
- Command: `python3 scripts/site_catalogue/merge.py [--without KEY ...] [--open-only] [--out DIR]`. Default `--out` is `assets/data`. Exit code 2, naming the key, when a snapshot is missing and not listed in `--without`.

- [ ] **Step 1: Failing tests** with tiny in-memory snapshots and a stub `places` whose `place` and `settle` return fixed `Place`s:
  - A missing snapshot returns exit code 2 and writes nothing; with `--without` for that key it writes.
  - A federal New York, New Jersey, North Carolina or Florida row never reaches the output (assert no id begins `usreef_ny_`, `usreef_nj_`, `usreef_nc_`, `usreef_fl_`), and an Irish row with a wrecksite position never does.
  - A register record gets `country_code`, `country` and `region` from `places.place`; an `osm` site gets them from `places.settle(geocoded, ...)`; a curated entry from `places.place` with the entry's own country as the fallback when the place has none; a record whose place is `fresh` gets `water_type` "fresh".
  - Every written record validates (`validate_catalogue` returns nothing) and every register record carries `"kind": "register"`.
  - The report counts add up: for each source `read == sum(dropped) + sum(overlap) + written`.
  - `id_changes({"osm_node_1", "ukho_5"}, {"osm_node_1", "ukho_6"})` reports `ukho_5` gone and `ukho_6` new under `ukho`.
  - `--open-only` writes no own-terms record.
  - Output is byte-identical for the same snapshots in a different key order (determinism).
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** `generated_at` comes from the newest snapshot's `fetched_at`, so a rerun on the same snapshots writes the same bytes. The report prints as an aligned text table, followed by ids gone and new against the existing `assets/data/site_catalogue.json` (first 40 of each per source, with totals).
- [ ] **Step 4:** Run `merge_test.py`, `dive_site_harvester_test.py`, `curated_sites_test.py`, `site_catalogue_format_test.py`, `site_country_resolver_test.py`; all pass (`test_the_bundled_catalogue_carries_every_curated_site` still reads the old shipped file here and stays green).
- [ ] **Step 5:** CI wiring for `merge_test.py` and `merge.py`. Commit `feat(dive-sites): merge catalogue sources offline into one file`.

---

### Task 9: App reads the record kind

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/catalogue_site.dart`, `lib/features/dive_sites/data/catalogue/catalogue_enum_names.dart`, `site_catalogue_parser.dart`, `site_catalogue_row_mapper.dart`, `lib/core/database/local_cache_site_catalogue_tables.dart`, `lib/core/database/local_cache_database.dart`
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart`, `site_catalogue_importer_test.dart`, and the local cache migration test that covers schema 21 (find it with `grep -rl "siteCatalogueEntries\|site_catalogue" test/core/database`)

**Interfaces:**
- Produces: `enum CatalogueKind { site, register }`; `CatalogueSite.kind` (`CatalogueKind`, default `CatalogueKind.site`, in `props` and `copyWith`); `catalogueKindsByName`; table column `kind` (`TextColumn`, default `'site'`); `LocalCacheDatabase.schemaVersion == 22`; index `idx_site_catalogue_kind_lat_lon` on `(kind, latitude, longitude)`.

- [ ] **Step 1: Failing tests.**
  - Parser: `"kind": "register"` parses to `CatalogueKind.register`; absent, or any other value, to `CatalogueKind.site`.
  - Mapper round trip: a register site written with `catalogueSiteToRow` and read with `catalogueSiteFromRow` is still a register site.
  - Migration (Review Focus 4): a database created at schema 21 with one catalogue row, opened at 22, has the `kind` column, that row reads as `CatalogueKind.site`, and `SiteCatalogueImporter.importIfChanged()` afterwards returns `imported` for a file with a different hash. A fresh database has the column (backstop).
- [ ] **Step 2:** Run those test files; fail (compile errors count).
- [ ] **Step 3: Implement.** Ladder step `if (from < 22)`: add the column when missing (use the file's existing column-exists helper) and create the index; mirror both in the raw `kCreateSiteCatalogueTableSql` and the `beforeOpen` backstop. Run codegen (`dart run build_runner build --delete-conflicting-outputs`, unfiltered, in the background).
- [ ] **Step 4:** Run the test files, `test/core/database/` for the local cache, and `test/architecture/`; pass.
- [ ] **Step 5:** `dart format .`; commit `feat(dive-sites): catalogue records carry a kind`.

---

### Task 10: Catalogue reads by kind and by bounds

**Files:**
- Modify: `lib/features/dive_sites/domain/repositories/site_catalogue.dart`, `lib/features/dive_sites/data/catalogue/local_site_catalogue.dart`, `test/helpers/fake_site_catalogue.dart`
- Create: `lib/features/dive_sites/domain/entities/catalogue_bounds.dart`
- Test: `test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class CatalogueBounds extends Equatable {
    const CatalogueBounds({required this.south, required this.west, required this.north, required this.east});
    final double south, west, north, east; // west > east means the box crosses 180
    GeoPoint get center;
  }
  typedef CatalogueBoundsResult = ({List<CatalogueSite> sites, bool truncated});
  ```
  and on `SiteCatalogue`:
  ```dart
  Future<List<CatalogueSite>> near(GeoPoint point, {required double radiusMeters, int limit = 500, CatalogueKind? kind});
  Future<int> countNear(GeoPoint point, {required double radiusMeters, required CatalogueKind kind});
  Future<CatalogueBoundsResult> inBounds(CatalogueBounds bounds, {int limit = 1500});
  ```
  `allWithCoordinates()` stays until Task 12 removes it.

- [ ] **Step 1: Failing tests** over a real in-memory `LocalCacheDatabase` seeded with two dive site rows and three register rows around one point:
  - `near(kind: CatalogueKind.site)` returns only the two; `kind: register` only the three; `kind: null` all five, nearest first.
  - `countNear(kind: register)` is 3 at a radius that holds them and 1 at a radius that holds one; it counts by real distance, not by the box (a row in the box's corner outside the radius is not counted).
  - `inBounds` returns the rows inside; with `limit: 3` it returns the two dive site rows first, then the register row nearest the centre, and `truncated` is true; with a generous limit `truncated` is false.
  - `inBounds` across the antimeridian (`west: 179, east: -179`) returns rows at 179.5 and at -179.5 (Review Focus 3).
  - Search tie-break: among rows whose names match equally and are both outside the area, the dive site row comes before the register row; a register row whose name matches still comes before a dive site row matched only by place.
  - A read with the database closed answers empty, zero and `(sites: [], truncated: false)`.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** `countNear` selects only latitude and longitude for the box and kind and counts by distance. `inBounds` reads the box for dive sites up to the limit, then register rows ordered by squared degree distance from the centre for the remainder; `truncated` when either query hit its cap. The search order adds `kind` after the in-name term in SQL and the same tie-break in the Dart regrouping. Mirror every rule in `FakeSiteCatalogue` (add `countNearCalls`, `inBoundsCalls`).
- [ ] **Step 4:** Run the test file plus every test that uses `FakeSiteCatalogue` and now fails to compile (`grep -rl FakeSiteCatalogue test`); pass.
- [ ] **Step 5:** `dart format .`; commit `feat(dive-sites): read the catalogue by kind and by map bounds`.

---

### Task 11: The picker's register section

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_register.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_built_in.dart`, `site_picker_sheet.dart`, `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/dive_sites/presentation/widgets/site_picker/site_picker_register_test.dart` (new), `site_picker_built_in_test.dart`

**Interfaces:**
- Consumes: `SiteCatalogue.near(kind:)`, `countNear`, `offerableCatalogueSites`, `CatalogueSiteTile`, the built-in mixin's `_adopt`, `builtInAnchor`, `builtInAnchorIsInferred`, `builtInPlaceLabel`.
- Produces: a mixin `SitePickerRegister` with `loadRegisterNearby()`, `List<Widget Function()> registerRows(List<DiveSite> userSites)`, constant `sitePickerRegisterListLimit = 200`.
- Strings (English; translate the other ten):
  - `diveSites_picker_register_nearPlace`: "Wrecks and reefs near {place}"
  - `diveSites_picker_register_nearby`: "Wrecks and reefs nearby"
  - `diveSites_picker_register_show`: plural, "Show {count} charted wreck or reef" / "Show {count} charted wrecks and reefs"
  - `diveSites_picker_register_capped`: "Showing the nearest {count}. Search to find the rest."

- [ ] **Step 1: Failing widget tests** using `site_picker_built_in_harness.dart` and a `FakeSiteCatalogue` holding dive site and register records near the anchor:
  - "More sites near" lists dive site records only (no register name is found under it).
  - With register records in range, a section labelled "Wrecks and reefs nearby" shows one row "Show 3 charted wrecks and reefs" and no register rows; with none in range, no such label exists.
  - Tapping the row lists the three, nearest first with distances for a measured anchor; for an inferred anchor the label is "Wrecks and reefs near Bonaire", the rows are by name and show no distance.
  - With 250 register records the opened section shows 200 rows and the capped caption with 200.
  - A register record the diver has adopted (linked id), and one within 150 m of an unlinked site of theirs, are not listed.
  - Tapping a register row adopts once and closes the picker with the new site (reuse the adoption test's assertions).
  - With text in the search field the register section is absent and the single "Built-in sites" list shows both kinds.
  - `showBuiltIn: false` shows no register section and makes no `countNear` call.
  - A diver's site linked to an id the catalogue no longer holds: the picker builds, lists that site under theirs, and offers nothing for it (Review Focus 5).
- [ ] **Step 2:** Run both test files; fail.
- [ ] **Step 3: Implement.** The built-in mixin's `loadBuiltInNearby` asks for `kind: CatalogueKind.site`. The register mixin loads `countNear` with the nearby list of the first `sitePickerRegisterListLimit` on open only (the closed row needs the count alone). Rows are appended in `site_picker_sheet.dart` directly after the built-in rows. The section follows the guards: no button in `ListTile.trailing`, no indeterminate spinner.
- [ ] **Step 4:** `flutter gen-l10n`; run the two test files, `test/architecture/`, `test/shared/`, and the l10n tests the index memory names; pass.
- [ ] **Step 5:** `dart format .`; commit `feat(dive-sites): charted wrecks and reefs get their own picker section`.

---

### Task 12: Map overlay by viewport

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart`, `lib/features/dive_sites/presentation/pages/site_map_page.dart`, `lib/features/dive_sites/presentation/widgets/site_map_content.dart`, `built_in_site_marker_layer.dart` (only if its input type changes), `lib/features/dive_sites/domain/repositories/site_catalogue.dart` and `local_site_catalogue.dart` and `test/helpers/fake_site_catalogue.dart` (remove `allWithCoordinates`), ARB files
- Test: `test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart`, the existing map page and map content widget tests (`grep -rl "showBuiltInSitesProvider" test`), `site_catalogue_asset_test.dart` (its `allWithCoordinates` use moves to `inBounds` of the whole world with a large limit)

**Interfaces:**
- Produces: `const kBuiltInOverlayMarkerLimit = 1500;` `final builtInOverlayBoundsProvider = StateProvider<CatalogueBounds?>((ref) => null);` `final visibleBuiltInSitesProvider = FutureProvider.autoDispose<({List<CatalogueSite> sites, bool truncated})>` (reads the bounds provider; empty when it is null; applies `offerableCatalogueSites(..., byPosition: true)`). `builtInSitesProvider` is removed.
- String: `diveSites_map_builtIn_zoomIn`: "Zoom in to see every built-in site".

- [ ] **Step 1: Failing tests.**
  - Provider: with bounds set, it asks `inBounds` once with those bounds and `kBuiltInOverlayMarkerLimit`; changing the bounds asks again; a catalogue revision bump asks again; with bounds null it returns empty and asks nothing; a diver's linked site hides its record; `truncated` passes through.
  - Map widget tests: with the overlay on, the layer shows the sites the fake returns for the current bounds; after a simulated move end the bounds provider holds the new bounds; when the fake reports `truncated`, the caption text is shown, and it is absent otherwise; with the overlay off, `inBoundsCalls == 0`.
  - The selected site's info card is found through `catalogueSiteProvider(id)` after the bounds change so that the site is no longer in the loaded list.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** Both map widgets set `builtInOverlayBoundsProvider` from the map camera on `MapEventMoveEnd` and on first layout, debounced 300 ms, only while the overlay is on. The caption is a small chip over the map near the toggle, not a snack bar. The overlay stays off by default.
- [ ] **Step 4:** Run the named tests, `test/architecture/`, `test/shared/`; pass. `grep -rn allWithCoordinates lib test` returns nothing.
- [ ] **Step 5:** `dart format .`; commit `feat(dive-sites): built-in map overlay loads the sites in view`.

---

### Task 13: GPS matching prefers dive site records

**Files:**
- Modify: `lib/features/dive_sites/domain/matching/match_candidate.dart`, `site_matcher.dart`, `lib/features/dive_sites/data/services/site_matching_service.dart`
- Test: the matcher's unit test (`grep -rl matchRanked test`), `test/features/dive_sites/data/services/site_matching_service_test.dart`

**Interfaces:**
- Produces: `MatchCandidate({required id, required location, required isExisting, this.isRegister = false})`.

- [ ] **Step 1: Failing tests** with balanced thresholds (inner 150 m, outer 1000 m, separation 75 m):
  - A register candidate at 60 m and a dive site candidate at 120 m: the outcome is `AutoMatch` on the dive site candidate.
  - A lone register candidate at 60 m: `AutoMatch` on it.
  - A register candidate at 60 m and a dive site candidate at 400 m (outside the inner radius): `AutoMatch` on the register candidate.
  - Two dive site candidates at 100 m and 120 m plus a register candidate at 10 m: `Suggested` with all three in range.
  - An existing site at 140 m still beats both kinds, as today.
  - Service: a catalogue record with `CatalogueKind.register` becomes a candidate with `isRegister: true`.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement.** The pool is the first non-empty of: existing sites inside the inner radius; non-register candidates inside the inner radius; every candidate inside the inner radius. The rest of `matchRanked` is unchanged.
- [ ] **Step 4:** Run; pass.
- [ ] **Step 5:** `dart format .`; commit `feat(dive-sites): GPS matching prefers a dive site over a charted wreck`.

---

### Task 14: Run the harvest and ship the data

**Files:**
- Modify: `assets/data/site_catalogue.json`, `assets/data/site_catalogue.version`
- Create: `assets/data/site_catalogue_njdep_metadata.xml`
- Modify: `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart`, `test/features/dive_sites/data/services/bundled_osm_asset_metadata_test.dart` (only if a pinned key changed), `scripts/curated_sites_test.py` (only if a curated id stepped aside)

- [ ] **Step 1: Fetch.** Copy an existing `scripts/.site_country_cache.json` from a sibling worktree if one exists. Run each source's fetch alone, in the background where it runs over two minutes: boundaries, UKHO, AWOIS, Ireland, FWC, federal reefs, NJDEP, NC, Keys, OSM wrecks, Wikidata, then OSM dive sites (the only one that geocodes). A source that refuses the client name is reported to the maintainer, not worked around.
- [ ] **Step 2: Merge.** `python3 scripts/site_catalogue/merge.py`; save the report to the scratchpad. Compare each source's `written` with the spec's expected count; investigate anything more than a tenth away before going on (a mis-mapped gate is the likely cause). Read the ids-gone list: no `curated_` id and no `osm_` dive site id may be gone unless the object left OpenStreetMap or became a business.
- [ ] **Step 3: New Jersey metadata.** Download the layer's metadata XML (spec A) to `assets/data/site_catalogue_njdep_metadata.xml`.
- [ ] **Step 4: Update the asset test**, then run it:
  - The pinned total and the `inBounds` whole-world count become the real numbers.
  - `sources.keys` contains all 13 keys; each own-terms source has `own_terms`.
  - Every record with `"kind": "register"` has `lat` and `lon`; every `ukho` record's `max_depth_m` is between 2 and 60; no `fwc`, `noaa_reefs`, `hi_dar` or `tpwd` record is deeper than 60.
  - No id begins `usreef_ny_`, `usreef_fl_`, `usreef_nj_` or `usreef_nc_`.
  - A site at Tahiti (latitude between -18 and -17, longitude between -150 and -149) has `country_code` `PF`.
  - No `region` holds a character outside the Latin, Latin Extended and punctuation ranges.
  - "Salt Pier" keeps `osm_node_663869401`, `BQ`, and island Bonaire (existing test, unchanged).
  - A known wreck appears once: `sites.where((s) => normalize(s['name']).contains('thistlegorm'))` has length 1.
  - The existing search, sea, cenote and country-in-another-language tests still pass; raise their expected minimums only where the new data makes them pass trivially.
  - The file is one record per line (`readAsLinesSync().length == sites.length + 2`).
- [ ] **Step 5:** Run `site_catalogue_asset_test.dart`, `bundled_osm_asset_metadata_test.dart`, `python3 scripts/curated_sites_test.py`; pass. Commit data and tests together: `feat(dive-sites): built-in catalogue grows to the open wreck and reef registers`.

---

### Task 15: Credits, licence text and user docs

**Files:**
- Modify: `lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart`, `README.md` (licence section), `docs/user/dive-sites.md`
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_attribution_test.dart`

- [ ] **Step 1: Failing tests.** The licence entry's text contains, for every source in the shipped file's `metadata.sources`, its `name` and its `licence_url`; the UKHO statement verbatim; the NJDEP credit and disclaimer verbatim with "application"; the words "not for navigation"; a sentence naming Hawaii, North Carolina and Texas records as not for commercial use; "without alteration" for North Carolina; and the path of the New Jersey metadata file. The test reads the sources from `assets/data/site_catalogue.json`, so a source added later without a credit fails it.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3: Implement** the text as one block in the order of spec 12's table, OpenStreetMap first. README licence section gains the data notice of spec 6 (three sentences). `docs/user/dive-sites.md`: the register section in the picker, the sources list, and that register positions come from the registers.
- [ ] **Step 4:** Run the attribution test and `python3 scripts/check_docs_links.py`; pass.
- [ ] **Step 5:** `dart format .`; commit `docs(dive-sites): credit every catalogue source and state their terms`.

---

### Task 16: Demo data generator

**Files:**
- Modify: `tool/demo_data/src/story/catalog.dart`, `tool/demo_data/src/story/destinations.dart`, `tool/demo_data/README.md` (only if it describes the keys)
- Test: `test/tool/demo_data/destinations_test.dart` and any `test/tool/demo_data/*` test that reads the catalogue

- [ ] **Step 1: Failing tests.** `Catalog.load` skips a record with `"kind": "register"` (a fixture with one of each yields one site). Then run `destinations_test.dart` against the new shipped file and note every destination that now has fewer than six sites.
- [ ] **Step 2: Re-key** each failing destination to the shipped file's values: the country code the file now carries (Guadeloupe `GP`, French Polynesia `PF`) and the English region string it now carries; where the file has no region for the destination's sites, set `region: null` and rely on the area circle. Do not change a destination's area circle or its name.
- [ ] **Step 3:** Run every `test/tool/demo_data/` test file one at a time; pass. Confirm the 20 `curated_nj_*` ids in `destination_life.dart` are all in the shipped file.
- [ ] **Step 4:** `dart format .`; commit `fix(demo-data): follow the catalogue's new country codes and regions`.

---

### Task 17: Verify, screenshots, PR

- [ ] **Step 1:** `dart format .`; `flutter analyze` on the whole repository; fix every issue. Run each test file touched in Tasks 9 to 16, then `test/architecture/` and `test/shared/`. Run every `scripts/site_catalogue/*_test.py` and the four existing catalogue script tests.
- [ ] **Step 2:** Build and run the macOS app with its own database. Check acceptance items 7 to 12 of the spec by hand: the register section near Scapa Flow (a dive with GPS at 58.9, -3.1) and its absence far from any register record; a wreck found by search; the import page's country chip order; the map overlay loading by viewport and its caption over the North Sea; the licence page text; the source line on a site adopted from a UKHO record. Time the first import in a profile build and note it.
- [ ] **Step 3:** Capture "after" screenshots matching Task 0's, plus the opened register section and the map caption, light and dark. Push them to the project's current secret screenshots gist as `<pr>-<nn>-<screen>-<state>.png` (list gists first; start the next numbered gist if the current one is over 75 MB).
- [ ] **Step 4:** Merge `origin/main`, rerun `flutter analyze` on the whole repository and the local cache database tests (renumber the ladder step if main took 22). Push the branch (the pre-push hook runs; touch no `lib/` or `test/` file while it does).
- [ ] **Step 5:** Open the PR to `main` with the repository's template: summary, `Part of #4514`, the merge report (per-source counts, ids gone and new), any source more than a tenth from its expected count with the reason, the import timing, and the screenshots by pinned raw gist URL. Bind the PR and read its checks.

---

## Notes for the executor

- Tasks 1 to 8 touch only `scripts/`; Tasks 9 to 13 touch only `lib/` and `test/` and use fixtures, so they do not need the harvest. Task 14 needs 1 to 8 done; Tasks 15 and 16 need 14.
- The spec's "Left to the builder" list is yours to decide. Record each decision in the PR description if it would surprise a reviewer.
- If a gate cannot be implemented as the spec words it because the live source differs from spec A, stop and say so; do not approximate silently.
