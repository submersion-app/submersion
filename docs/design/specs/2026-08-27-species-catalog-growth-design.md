# Species Catalog Growth: Versioned Re-seed, Lookup Generators, Freshwater Species

Date: 2026-08-27
Status: Design approved in conversation; spec awaiting review
Follows: `2026-08-26-species-online-lookup-design.md` (part 3), which added
the iNaturalist lookup and the GitHub suggestion channel. This is part 4 of
the Marine Life program: the bundled catalog itself.

## 1. Goal

Make the bundled species catalog safe to grow and correct, then grow it:

1. **Versioned re-seed.** Corrections to bundled rows reach existing installs.
   Today the seed is `INSERT OR IGNORE` on the stable `sp_` id, run on every
   launch, so a renamed, recategorized or re-described built-in species never
   changes on a device that already has it. Divers' own edits to built-in rows
   must survive the re-seed.
2. **Generators and a coverage test** for the two id-keyed lookup switches
   (`species_name_lookup.dart`, `species_description_lookup.dart`). Both say
   "Generated from `assets/data/species.json`" but no generator exists and no
   test ties the switches, the asset and the ARB keys together.
3. **About 150 freshwater species**, curated, with names localized from
   iNaturalist and descriptions in all eleven app locales, so lake, river,
   cenote and spring divers find their animals in the picker.

## 2. Current State (verified 2026-08-27 on `main`)

- `assets/data/species.json`: `{"version": 1, "species": [...]}`, 511 rows,
  fields `id, commonName, scientificName, category, taxonomyClass,
  description`. Nothing reads `version`.
- `SpeciesSeedService.loadBundledSpecies()` decodes `species` into domain
  entities with `isBuiltIn: true` (static cache).
- `SpeciesRepository.seedBuiltInSpecies()` (`species_repository.dart:430`)
  batches `InsertMode.insertOrIgnore`; `StartupPage` calls it on every
  launch (`startup_page.dart:673`). No `hlc`, no `markRecordPending`.
- `species` table: `id, common_name, scientific_name, category,
  taxonomy_class, description, photo_path, is_built_in, hlc`. No timestamps,
  no uniqueness on names. Four bundled rows share a scientific name with
  another row (two manta, two wobbegong/hammerhead pairs).
- `SpeciesRepository.updateSpecies()` works on built-in rows and calls
  `markRecordPending`, whose `_stampHlc` writes `species.hlc` (`species` is in
  `hlcTargets`). The sync exporter then drops built-in rows
  (`_exportSpecies` filters `is_built_in = 0`), so such an edit is
  device-local. `resetBuiltInSpecies()` restores bundled values but leaves the
  stale `hlc`.
- Lookups: `builtInSpeciesName` and `builtInSpeciesDescription`, one
  `switch` expression each, 511 cases, keys `species_<slug>_name` and
  `species_<slug>_desc` where `<slug>` is the id without `sp_`. All 11 ARB
  files carry all 1022 keys; no `@` metadata.
- `assets/data/species_gbif_keys.json` (507 of 511 resolved) is produced by
  `tool/generate_species_gbif_keys.dart` (GBIF match API, manual, network),
  consumed by the reef nearby-species matcher, and checked by
  `test/features/reef/domain/services/species_gbif_keys_asset_test.dart`
  (loose: passes above 75 percent resolved).
- Only species tool: the GBIF key generator. No test cross-checks
  `species.json` against the ARB keys or the switches.

## 3. Decisions Made During the Brainstorm

| Question | Decision |
|---|---|
| Re-seed policy | Keep diver edits, update untouched rows. "Untouched" means `hlc IS NULL`: every edit path stamps an hlc, the seed never does. |
| Where the applied version lives | SharedPreferences (`builtin_species_seed_version`, int). No schema change. Restore-from-backup clears it so a restored older database is re-upgraded on the next launch. |
| Freshwater scope | Curated list of about 150 species, generated through iNaturalist for localized names. |
| Description translations | Authored by hand in the seed file for all 11 locales (no translation API, no Wikipedia text and its CC BY-SA terms). Same review path as the 511 existing hand-written descriptions. |
| Delivery | One PR, three commit groups (re-seed, generators, freshwater data). No schema change. |

## 4. Design

### 4.1 Versioned re-seed

**Asset.** `species.json` `version` becomes meaningful: it is bumped whenever
a bundled row changes or rows are added (this PR bumps it to 2). The loader
exposes it: `SpeciesSeedService.loadBundledCatalog()` returns
`BundledSpeciesCatalog({required int version, required List<Species>
species})`; `loadBundledSpecies()` stays as a thin wrapper for existing
callers.

**Marker.** `BuiltInSpeciesSeedVersionStore` (marine_life/data/services), a
small class over `SharedPreferences` with `Future<int> appliedVersion()`
(default 0), `Future<void> markApplied(int)`, `Future<void> clear()`. Injected
into `SpeciesRepository` through an optional constructor parameter so tests
pass a fake; production wiring builds it from `sharedPreferencesProvider`'s
instance at the startup call site.

**Seeding.** `seedBuiltInSpecies()` becomes:

```
catalog = load bundled catalog
applied = store.appliedVersion()
if (applied < catalog.version):
  batch: for every bundled row
    INSERT ... ON CONFLICT(id) DO UPDATE SET
      common_name, scientific_name, category, taxonomy_class, description,
      is_built_in = 1
    WHERE species.hlc IS NULL
  store.markApplied(catalog.version)
else:
  batch: INSERT OR IGNORE (today's path, kept as the cheap idempotent net
  that refills a wiped table without touching the marker)
```

Drift: `batch.insert(table, companion, onConflict: DoUpdate((old) =>
companion, where: (old) => old.hlc.isNull()))`. The `WHERE` on the conflict
clause is what keeps a diver's edited row. A row a diver deleted cannot exist
(built-in rows in use cannot be deleted; unused built-in rows can, through the
manager) and would be recreated by the upsert. That is the intended reading of
"the catalog is the catalog": deleting a bundled species hides it until the
next catalog version. The manager already offers "Reset to defaults" for the
opposite direction.

**Edited rows.** `resetBuiltInSpecies()` additionally sets `hlc = NULL` on
every row it restores, so a reset row counts as untouched again. It also
deletes the row's `sync_records` entry for `species` if one exists, keeping
the two invariants (untouched means no hlc; pending means exported) from
drifting; the exporter ignores built-in rows either way.

**Restore.** The backup restore path that replaces the database calls
`store.clear()` after the swap. The next launch sees `applied = 0 < version`
and re-runs the upgrade pass; rows the restored database's owner edited keep
their hlc and are skipped. The plan locates the single restore completion hook
(the restore service that already reruns startup maintenance).

**Cost.** The upgrade pass runs once per catalog version (about 660 upserts in
one batch); every other launch keeps today's `INSERT OR IGNORE` batch. No
change to startup ordering.

### 4.2 Lookup generators and the coverage test

`tool/generate_species_lookups.dart` (no network) reads `species.json` and
writes both switch files with a real generated header:

```
// GENERATED by tool/generate_species_lookups.dart from
// assets/data/species.json. Do not edit; rerun the tool.
```

Output is deterministic (asset order), formatted by `dart format` inside the
tool, and byte-identical to the current files apart from the header (the plan
proves this by regenerating before adding any species and diffing).

`tool/generate_species_arb_keys.dart` (no network) reads a "species names and
descriptions by locale" JSON (the freshwater seed's output, section 4.3) and
inserts `species_<slug>_name` and `species_<slug>_desc` into all 11 ARB files
after the last existing `species_*_desc` key, refusing to overwrite an
existing key. It is the only writer of species ARB keys from now on.

Coverage test `test/features/marine_life/presentation/species_lookup_coverage_test.dart`:

- for every row of `species.json`, `builtInSpeciesName(AppLocalizationsEn(),
  id)` equals the row's `commonName` and `builtInSpeciesDescription(...)`
  equals its `description` (asset, English ARB and both switches agree);
- the number of switch cases equals the row count (no orphan case for a
  removed id), checked by scanning the generated files for `'sp_` literals;
- `species.json` ids are unique and every id matches `^sp_[a-z0-9_]+$`;
- `version` is an int of at least 2.

`test/features/marine_life/data/species_seed_version_test.dart` covers 4.1
with an in-memory database and a fake store: first launch inserts and marks;
same version inserts only missing rows; higher version updates untouched rows,
skips a row with an hlc, recreates a deleted row; `resetBuiltInSpecies`
clears the hlc; `clear()` forces an upgrade pass.

### 4.3 Freshwater species

**Seed file.** `tool/data/freshwater_species_seed.json`, curated by hand,
about 150 entries:

```json
{
  "id": "sp_northern_pike",
  "scientificName": "Esox lucius",
  "inaturalistTaxonId": 49543,
  "category": "fish",
  "taxonomyClass": "Actinopterygii",
  "commonName": "Northern Pike",
  "description": {
    "en": "Ambush predator of weedy lake margins, with a long body and duckbill snout.",
    "de": "...", "es": "...", "fr": "...", "it": "...", "pt": "...",
    "nl": "...", "hu": "...", "zh": "...", "ar": "...", "he": "..."
  }
}
```

`commonName` is the English fallback; descriptions are authored for all 11
locales in the seed itself.

**Curation.** Species divers meet in lakes, rivers, springs, cenotes and
flooded quarries worldwide, roughly: North American and European game and
coarse fish (pike, perch, zander, walleye, muskellunge, bass, sunfish,
crappie, trout, char, salmon, whitefish, grayling, carp, tench, bream, roach,
chub, barbel, catfish, burbot, sturgeon, paddlefish, gar, bowfin, eels,
lamprey); African rift-lake cichlids and Nile perch, tigerfish, lungfish;
Amazon and Mekong giants (arapaima, arowana, pacu, piranha, electric eel,
freshwater stingray, giant catfish); Australian Murray cod and barramundi;
cave and cenote animals (blind cave tetra, cave crayfish); freshwater
invertebrates (crayfish, mussels including zebra and quagga, freshwater
sponge, freshwater jellyfish, snails); freshwater turtles, alligators,
caimans and freshwater crocodiles; amphibians (hellbender, mudpuppy, axolotl,
newts) under `other`; freshwater mammals (river otter, beaver, muskrat,
Florida manatee, platypus, Baikal seal, Amazon river dolphin); common water
plants (water lily, eelgrass, coontail, milfoil, muskgrass, elodea). Species
already in the marine catalog (saltwater crocodile, manatee species present
there) are not duplicated; the tool refuses an id or scientific name that
already exists in `species.json`.

**Categories** reuse the existing enum; there is no freshwater category and
none is added. Amphibians go to `other`, water plants to `plant`, crayfish and
mussels to `invertebrate`.

**Generator.** `tool/generate_freshwater_species.dart` (network, manual):

1. reads the seed;
2. for each entry with `inaturalistTaxonId`, calls
   `https://api.inaturalist.org/v1/taxa/{id}?locale=<code>` once per app
   locale (`en de es fr it pt nl hu zh ar he`; iNaturalist's `zh-CN` for
   `zh`), takes the best name per app locale from the `all_names` list,
   keeps the seed's curated English name for `en`, and fills any locale
   iNaturalist lacks from `tool/data/freshwater_species_name_overrides.json`,
   a hand-authored file (the marine catalog ships no English fallback in any
   locale, so neither does this; the overrides cover 653 names); rate-limited
   to one request per second with the part 3 user agent;
3. appends the entries to `species.json` (`commonName` = English name,
   `description` = English description) and bumps `version` to 2;
4. writes `tool/data/freshwater_species_localized.json` (names and
   descriptions by locale) for `generate_species_arb_keys.dart`;
5. prints the follow-ups: run `generate_species_arb_keys.dart`,
   `generate_species_lookups.dart`, `generate_species_gbif_keys.dart`, then
   `flutter gen-l10n`.

The seed, the localized output and the generated artifacts are all committed,
so the catalog is reproducible without the network and reviewable in the PR.

**GBIF keys** are refreshed with the existing tool so the reef nearby-species
feature can match freshwater occurrences. The straddling-taxa list in that
tool is extended if a freshwater family straddles the marine boundary (the
plan checks the generated whitelist for the cases the existing regression
test guards).

**Catalog suggestion channel (part 3)** is unchanged; a diver's suggestion
issue now has a documented landing place: add to the seed, rerun the tools.
`docs/features/marine-life.md` gains a short "Growing the catalog" section
for maintainers and a line telling divers freshwater species are included.

### 4.4 Error handling

- Upgrade pass failure (SQLite error) leaves the marker unchanged, so the
  next launch retries; the startup step already logs and continues
  (`timeStartupStep`).
- Missing or malformed `SharedPreferences` value reads as 0.
- The freshwater tool aborts on any HTTP failure after three retries, writes
  nothing partial (all files are written at the end), and reports the taxon
  it failed on; a taxon returning no name in any locale keeps the seed's
  English name.
- The ARB writer validates each file as JSON after insertion and refuses to
  write if a key already exists, so a rerun cannot duplicate keys
  (`arb_parity_test` guards the rest).

### 4.5 Testing

- Unit: seed version store (prefs fake), repository upgrade semantics (4.2
  list), `BundledSpeciesCatalog` decoding including a missing `version`
  (treated as 1).
- Coverage test binding asset, English ARB and switches (4.2).
- Tool tests, pure functions only: the lookup file renderer (given three
  rows, output equals a golden string), the ARB inserter (given a small ARB
  string, keys land after the anchor and the result parses), the freshwater
  name merge (iNat response fixture with a missing locale falls back to
  English). The network client is injected; tests never hit it.
- Existing `species_gbif_keys_asset_test` keeps passing after the key
  refresh; its "large majority" threshold is tightened to 90 percent since
  the generator now covers freshwater rows too.
- `arb_parity_test` and the full suite.

### 4.6 Out of scope

- A freshwater category or habitat field, and filtering the picker by
  habitat.
- Syncing diver edits to built-in rows across devices (the exporter's
  exclusion is deliberate and stays).
- Deduplicating the four bundled scientific-name twins.
- In-app catalog updates without an app release.

## 5. Files

- Modify: `assets/data/species.json` (version 2, about 660 rows),
  `assets/data/species_gbif_keys.json`, 11 ARB files and their generated
  Dart, `species_name_lookup.dart`, `species_description_lookup.dart`
  (regenerated), `species_seed_service.dart`, `species_repository.dart`
  (seed, reset), `startup_page.dart` (store wiring), the restore completion
  hook, `docs/features/marine-life.md`.
- Create: `lib/features/marine_life/data/services/builtin_species_seed_version_store.dart`,
  `lib/features/marine_life/domain/entities/bundled_species_catalog.dart`,
  `tool/generate_species_lookups.dart`, `tool/generate_species_arb_keys.dart`,
  `tool/generate_freshwater_species.dart`, `tool/src/species_tool_support.dart`
  (shared pure functions the tool tests import), `tool/data/freshwater_species_seed.json`,
  `tool/data/freshwater_species_localized.json`, the tests in 4.5.
