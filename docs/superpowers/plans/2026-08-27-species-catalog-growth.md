# Species Catalog Growth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bundled species catalog versioned (corrections reach existing installs without touching diver edits), generate the two id-keyed lookup switches from the asset with a coverage test, and add about 150 curated freshwater species with iNaturalist-localized names and hand-written descriptions in all 11 locales.

**Architecture:** `species.json`'s `version` drives a one-time upsert pass guarded by `hlc IS NULL`, with the applied version in SharedPreferences (cleared by restore). Three `tool/` scripts share pure functions in `tool/src/species_tool_support.dart`: a lookup-switch renderer, an ARB key inserter, and an iNaturalist name merger; the freshwater seed lives in `tool/data/` and every generated artifact is committed. No schema change.

**Tech Stack:** Flutter, Drift 2.34 (`DoUpdate(where:)`), SharedPreferences, `dart:io` HttpClient in tools, `flutter gen-l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-27-species-catalog-growth-design.md`

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-catalog` on branch `worktree-species-catalog` (cut from origin/main 929d7130860). `flutter analyze` prints `Analyzing species-catalog...` when it runs in the right tree.
- No schema change. No em-dashes anywhere. No emojis in code or docs. Immutable entities. Tests first. Single-file test runs with exit codes, never through a pipe.
- Every new ARB key exists in all 11 locales (`ar de en es fr he hu it nl pt zh`); generated l10n Dart is committed with the ARB change.
- Tools are run with `dart run tool/<name>.dart` from the worktree root. Network tools (`generate_freshwater_species`, `generate_species_gbif_keys`) are manual and never part of tests or CI.
- Species ids are `sp_<snake_case_english_name>`; ARB keys are `species_<id minus sp_>_name` and `_desc`.
- `dart format .` before every commit. Commit per task; do not push.

---

### Task 1: `BundledSpeciesCatalog` and a pure catalog parser

**Files:**
- Create: `lib/features/marine_life/domain/entities/bundled_species_catalog.dart`
- Modify: `lib/features/marine_life/data/services/species_seed_service.dart`
- Test: `test/features/marine_life/data/services/species_seed_service_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BundledSpeciesCatalog { const BundledSpeciesCatalog({required this.version, required this.species}); final int version; final List<Species> species; }
  // SpeciesSeedService
  static BundledSpeciesCatalog parseCatalog(String jsonString);         // pure, missing version reads as 1
  static Future<BundledSpeciesCatalog> loadBundledCatalog();          // rootBundle + cache
  static Future<List<Species>> loadBundledSpecies();                   // unchanged signature, returns catalog.species
  static void overrideCatalog(BundledSpeciesCatalog catalog);          // @visibleForTesting, seeds the cache
  static void clearCache();
  ```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/species_seed_service.dart';

void main() {
  const twoRows = '''
{
  "version": 2,
  "species": [
    {"id": "sp_a", "commonName": "A", "scientificName": "Aus aus",
     "category": "fish", "taxonomyClass": "Actinopterygii", "description": "d"},
    {"id": "sp_b", "commonName": "B", "scientificName": null,
     "category": "nonsense", "taxonomyClass": null, "description": null}
  ]
}
''';

  test('parseCatalog reads the version and every row as built-in', () {
    final catalog = SpeciesSeedService.parseCatalog(twoRows);

    expect(catalog.version, 2);
    expect(catalog.species.map((s) => s.id), ['sp_a', 'sp_b']);
    expect(catalog.species.first.isBuiltIn, isTrue);
    expect(catalog.species.first.category, SpeciesCategory.fish);
    expect(catalog.species.last.category, SpeciesCategory.other);
    expect(catalog.species.last.scientificName, isNull);
  });

  test('a catalog without a version is version 1', () {
    final catalog = SpeciesSeedService.parseCatalog('{"species": []}');

    expect(catalog.version, 1);
    expect(catalog.species, isEmpty);
  });

  test('overrideCatalog feeds loadBundledSpecies until the cache clears', () async {
    addTearDown(SpeciesSeedService.clearCache);
    SpeciesSeedService.overrideCatalog(SpeciesSeedService.parseCatalog(twoRows));

    final species = await SpeciesSeedService.loadBundledSpecies();
    final catalog = await SpeciesSeedService.loadBundledCatalog();

    expect(species.map((s) => s.id), ['sp_a', 'sp_b']);
    expect(catalog.version, 2);
  });
}
```

- [ ] **Step 2: Run it red**: `flutter test test/features/marine_life/data/services/species_seed_service_test.dart` fails to compile (`parseCatalog` undefined).

- [ ] **Step 3: Implement**

`bundled_species_catalog.dart`:

```dart
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// The bundled species asset: its rows plus the catalog version that gates
/// the re-seed upgrade pass (see SpeciesRepository.seedBuiltInSpecies).
class BundledSpeciesCatalog {
  const BundledSpeciesCatalog({required this.version, required this.species});

  final int version;
  final List<Species> species;
}
```

`species_seed_service.dart` becomes:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/bundled_species_catalog.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

class SpeciesSeedService {
  static BundledSpeciesCatalog? _cached;

  /// Decodes the asset text. A catalog without a `version` is version 1: the
  /// value shipped before versioning meant anything.
  static BundledSpeciesCatalog parseCatalog(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final version = data['version'] is int ? data['version'] as int : 1;
    final speciesList = data['species'] as List<dynamic>;
    final species = speciesList.map((item) {
      final map = item as Map<String, dynamic>;
      return Species(
        id: map['id'] as String,
        commonName: map['commonName'] as String,
        scientificName: map['scientificName'] as String?,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => SpeciesCategory.other,
        ),
        taxonomyClass: map['taxonomyClass'] as String?,
        description: map['description'] as String?,
        isBuiltIn: true,
      );
    }).toList();
    return BundledSpeciesCatalog(version: version, species: species);
  }

  /// Load the bundled catalog, cached after the first read (the reset and
  /// the seed both use it).
  static Future<BundledSpeciesCatalog> loadBundledCatalog() async {
    final cached = _cached;
    if (cached != null) return cached;
    final jsonString = await rootBundle.loadString('assets/data/species.json');
    return _cached = parseCatalog(jsonString);
  }

  /// Load built-in species from the bundled JSON asset.
  static Future<List<Species>> loadBundledSpecies() async =>
      (await loadBundledCatalog()).species;

  /// Seeds the cache so tests can run the seed against a small catalog.
  @visibleForTesting
  static void overrideCatalog(BundledSpeciesCatalog catalog) {
    _cached = catalog;
  }

  /// Clear the cached catalog (useful for testing).
  static void clearCache() {
    _cached = null;
  }
}
```

- [ ] **Step 4: Run it green**, then `flutter test test/features/marine_life/` to confirm nothing else depended on the old cache field.
- [ ] **Step 5: Commit** `feat(marine-life): expose the bundled catalog version`.

---

### Task 2: `BuiltInSpeciesSeedVersionStore`

**Files:**
- Create: `lib/features/marine_life/data/services/builtin_species_seed_version_store.dart`
- Create: `test/helpers/in_memory_seed_version_store.dart`
- Test: `test/features/marine_life/data/services/builtin_species_seed_version_store_test.dart`

**Interfaces:**
```dart
abstract class BuiltInSpeciesSeedVersionStore {
  Future<int> appliedVersion();          // 0 when unset
  Future<void> markApplied(int version);
  Future<void> clear();
}
class PrefsBuiltInSpeciesSeedVersionStore implements BuiltInSpeciesSeedVersionStore {
  PrefsBuiltInSpeciesSeedVersionStore(SharedPreferences prefs);
  static const key = 'builtin_species_seed_version';
}
// test helper
class InMemorySeedVersionStore implements BuiltInSpeciesSeedVersionStore { int? version; int clearCalls = 0; }
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/marine_life/data/services/builtin_species_seed_version_store.dart';

void main() {
  test('reads 0 when nothing was applied, then round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsBuiltInSpeciesSeedVersionStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.appliedVersion(), 0);
    await store.markApplied(2);
    expect(await store.appliedVersion(), 2);
    await store.clear();
    expect(await store.appliedVersion(), 0);
  });

  test('a malformed stored value reads as 0', () async {
    SharedPreferences.setMockInitialValues({
      PrefsBuiltInSpeciesSeedVersionStore.key: 'two',
    });
    final store = PrefsBuiltInSpeciesSeedVersionStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.appliedVersion(), 0);
  });
}
```

- [ ] **Step 2: Run it red** (compile failure).
- [ ] **Step 3: Implement**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Which bundled catalog version this device has applied. Device-local by
/// design: the catalog is re-seeded on every install, so nothing about it
/// syncs. Restore-from-backup clears it (BackupService) so a restored older
/// database is upgraded again on the next launch.
abstract class BuiltInSpeciesSeedVersionStore {
  Future<int> appliedVersion();
  Future<void> markApplied(int version);
  Future<void> clear();
}

class PrefsBuiltInSpeciesSeedVersionStore
    implements BuiltInSpeciesSeedVersionStore {
  PrefsBuiltInSpeciesSeedVersionStore(this._prefs);

  static const key = 'builtin_species_seed_version';

  final SharedPreferences _prefs;

  @override
  Future<int> appliedVersion() async {
    try {
      return _prefs.getInt(key) ?? 0;
    } catch (_) {
      // A value of another type reads as never applied.
      return 0;
    }
  }

  @override
  Future<void> markApplied(int version) => _prefs.setInt(key, version);

  @override
  Future<void> clear() => _prefs.remove(key);
}
```

Test helper `test/helpers/in_memory_seed_version_store.dart`:

```dart
import 'package:submersion/features/marine_life/data/services/builtin_species_seed_version_store.dart';

class InMemorySeedVersionStore implements BuiltInSpeciesSeedVersionStore {
  InMemorySeedVersionStore([this.version]);

  int? version;
  int clearCalls = 0;

  @override
  Future<int> appliedVersion() async => version ?? 0;

  @override
  Future<void> markApplied(int applied) async => version = applied;

  @override
  Future<void> clear() async {
    clearCalls++;
    version = null;
  }
}
```

- [ ] **Step 4: Run it green.**
- [ ] **Step 5: Commit** `feat(marine-life): add the built-in species seed version store`.

---

### Task 3: Versioned re-seed in `SpeciesRepository` and the startup wiring

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (`seedBuiltInSpecies`, `resetBuiltInSpecies`)
- Modify: `lib/core/presentation/pages/startup_page.dart:673-676`
- Test: `test/features/marine_life/data/repositories/species_repository_seed_test.dart`

**Interfaces:**
```dart
Future<void> seedBuiltInSpecies({BuiltInSpeciesSeedVersionStore? versionStore});
```
`versionStore == null` keeps today's behaviour (INSERT OR IGNORE only). Startup passes a prefs store; `resetBuiltInSpecies` calls it without one.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_seed_service.dart';
import 'package:submersion/features/marine_life/domain/entities/bundled_species_catalog.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

import '../../../../helpers/in_memory_seed_version_store.dart';
import '../../../../helpers/test_database.dart';

domain.Species _row(String id, String name, {String? description}) =>
    domain.Species(
      id: id,
      commonName: name,
      scientificName: '$name sci',
      category: SpeciesCategory.fish,
      description: description ?? '$name description',
      isBuiltIn: true,
    );

BundledSpeciesCatalog _catalog(int version, List<domain.Species> rows) =>
    BundledSpeciesCatalog(version: version, species: rows);

void main() {
  late AppDatabase db;
  late SpeciesRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    SpeciesSeedService.clearCache();
    await tearDownTestDatabase();
  });

  Future<Specy> read(String id) =>
      (db.select(db.species)..where((t) => t.id.equals(id))).getSingle();

  test('first launch inserts every row and records the version', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore();

    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'A');
    expect((await read('sp_a')).hlc, isNull);
    expect(store.version, 2);
  });

  test('a newer catalog updates untouched rows and keeps edited ones', () async {
    SpeciesSeedService.overrideCatalog(
      _catalog(1, [_row('sp_a', 'A'), _row('sp_b', 'B')]),
    );
    final store = InMemorySeedVersionStore();
    await repository.seedBuiltInSpecies(versionStore: store);
    // The diver renames B: every edit path stamps an hlc.
    await repository.updateSpecies(
      (await repository.getSpeciesById('sp_b'))!.copyWith(commonName: 'Mine'),
    );
    expect((await read('sp_b')).hlc, isNotNull);

    SpeciesSeedService.overrideCatalog(
      _catalog(2, [_row('sp_a', 'A2'), _row('sp_b', 'B2'), _row('sp_c', 'C')]),
    );
    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'A2');
    expect((await read('sp_b')).commonName, 'Mine');
    expect((await read('sp_c')).commonName, 'C');
    expect(store.version, 2);
  });

  test('the same version only fills in missing rows', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore(2);
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion(
            id: const Value('sp_a'),
            commonName: const Value('Old'),
            category: const Value('fish'),
            isBuiltIn: const Value(true),
          ),
        );

    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'Old');
  });

  test('a deleted built-in row comes back at the next version', () async {
    SpeciesSeedService.overrideCatalog(_catalog(1, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore();
    await repository.seedBuiltInSpecies(versionStore: store);
    await repository.deleteSpecies('sp_a');

    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'A');
  });

  test('without a store the seed is the plain INSERT OR IGNORE', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion(
            id: const Value('sp_a'),
            commonName: const Value('Old'),
            category: const Value('fish'),
            isBuiltIn: const Value(true),
          ),
        );

    await repository.seedBuiltInSpecies();

    expect((await read('sp_a')).commonName, 'Old');
  });

  test('resetBuiltInSpecies clears the hlc and pending record of a restored row',
      () async {
    SpeciesSeedService.overrideCatalog(_catalog(1, [_row('sp_a', 'A')]));
    await repository.seedBuiltInSpecies(versionStore: InMemorySeedVersionStore());
    await repository.updateSpecies(
      (await repository.getSpeciesById('sp_a'))!.copyWith(commonName: 'Mine'),
    );
    // In use, so the reset restores rather than deletes it.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion(
        id: const Value('d1'),
        diveDateTime: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_a');

    await repository.resetBuiltInSpecies();

    final row = await read('sp_a');
    expect(row.commonName, 'A');
    expect(row.hlc, isNull);
    final pending = await db
        .customSelect(
          "SELECT record_id FROM sync_records "
          "WHERE entity_type = 'species' AND record_id = 'sp_a'",
        )
        .get();
    expect(pending, isEmpty);
  });
}
```

Check `getSpeciesById` and `addSighting` names against `species_repository.dart` before running (`grep -n "Future<domain.Species?> get\|Future<.*> addSighting" lib/features/marine_life/data/repositories/species_repository.dart`) and use the real names.

- [ ] **Step 2: Run it red**: the named parameter does not exist.
- [ ] **Step 3: Implement**

Replace `seedBuiltInSpecies` with:

```dart
  /// Seed built-in species from the bundled JSON asset.
  ///
  /// Every launch runs the cheap INSERT OR IGNORE batch keyed on the stable
  /// sp_ ids, which refills a wiped table. When [versionStore] reports a
  /// version below the asset's, the batch becomes an upsert that also
  /// rewrites rows the diver never touched (`hlc IS NULL`: every edit path
  /// stamps an hlc, the seed never does), so catalog corrections reach
  /// existing installs while edits survive. A built-in row the diver deleted
  /// comes back at the next catalog version.
  Future<void> seedBuiltInSpecies({
    BuiltInSpeciesSeedVersionStore? versionStore,
  }) async {
    final catalog = await SpeciesSeedService.loadBundledCatalog();
    final applied = await versionStore?.appliedVersion();
    final upgrade = applied != null && applied < catalog.version;

    await _db.batch((batch) {
      for (final species in catalog.species) {
        final companion = SpeciesCompanion(
          id: Value(species.id),
          commonName: Value(species.commonName),
          scientificName: Value(species.scientificName),
          category: Value(species.category.name),
          taxonomyClass: Value(species.taxonomyClass),
          description: Value(species.description),
          isBuiltIn: const Value(true),
        );
        if (upgrade) {
          batch.insert(
            _db.species,
            companion,
            onConflict: DoUpdate(
              (old) => companion,
              where: (old) => old.hlc.isNull(),
            ),
          );
        } else {
          batch.insert(_db.species, companion, mode: InsertMode.insertOrIgnore);
        }
      }
    });

    if (upgrade) {
      await versionStore.markApplied(catalog.version);
    }
  }
```

In `resetBuiltInSpecies`, change the in-use update to also clear the hlc and drop the pending record:

```dart
    for (final species in builtInSpecies) {
      if (inUseIds.contains(species.id)) {
        await (_db.update(
          _db.species,
        )..where((t) => t.id.equals(species.id))).write(
          SpeciesCompanion(
            commonName: Value(species.commonName),
            scientificName: Value(species.scientificName),
            category: Value(species.category.name),
            taxonomyClass: Value(species.taxonomyClass),
            description: Value(species.description),
            isBuiltIn: const Value(true),
            // Restored to the bundle means untouched again, so the next
            // catalog version may update it.
            hlc: const Value(null),
          ),
        );
        await (_db.delete(_db.syncRecords)..where(
              (t) => t.entityType.equals('species') & t.recordId.equals(species.id),
            ))
            .go();
      }
    }
```

Add the import `package:submersion/features/marine_life/data/services/builtin_species_seed_version_store.dart`.

`startup_page.dart:673-676` becomes:

```dart
    await timeStartupStep('speciesSeed', () async {
      final speciesRepository = SpeciesRepository();
      await speciesRepository.seedBuiltInSpecies(
        versionStore: PrefsBuiltInSpeciesSeedVersionStore(
          await SharedPreferences.getInstance(),
        ),
      );
    });
```

with the store import. `SharedPreferences` is already imported there (line 652 uses it).

- [ ] **Step 4: Run green**: the seed test, then `flutter test test/features/marine_life/data/repositories/` and `test/core/presentation/` if a startup test exists (`ls test/core/presentation/pages/ | grep startup`).
- [ ] **Step 5: Commit** `feat(marine-life): re-seed untouched built-in species when the catalog version rises`.

---

### Task 4: Restore clears the applied version

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (constructor, `_replaceDatabaseAndRebaselineSync`)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart:37-49`
- Test: `test/features/backup/data/services/backup_service_replace_test.dart` (add a case)

- [ ] **Step 1: Write the failing test** (inside the existing `restore modes` group, using the file's `fakeDb`, `preferences`, `writeRestoreSource`, `_EpochSpySyncRepository`):

```dart
    test('a restore clears the applied catalog version', () async {
      final seedStore = InMemorySeedVersionStore(2);
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        seedVersionStore: seedStore,
      );

      await service.restoreFromFile(await writeRestoreSource());

      expect(seedStore.version, isNull);
      expect(seedStore.clearCalls, 1);
    });
```

Add `import '../../../../helpers/in_memory_seed_version_store.dart';`.

- [ ] **Step 2: Run it red** (no named parameter `seedVersionStore`).
- [ ] **Step 3: Implement**

Constructor: add `BuiltInSpeciesSeedVersionStore? seedVersionStore,` after `backupEncryptionKeyStore`, field `final BuiltInSpeciesSeedVersionStore? _seedVersionStore;`, initializer `_seedVersionStore = seedVersionStore`. In `_replaceDatabaseAndRebaselineSync`, directly after the `await _dbAdapter.restore(...)` call:

```dart
    // The restored file carries whatever built-in species rows its backup
    // had; forgetting the applied catalog version makes the next launch run
    // the upgrade pass again (diver-edited rows keep their hlc and are
    // skipped by it).
    try {
      await _seedVersionStore?.clear();
    } catch (e, st) {
      _log.warning(
        'Could not clear the built-in species seed version after restore',
        error: e,
        stackTrace: st,
      );
    }
```

Provider: add `seedVersionStore: PrefsBuiltInSpeciesSeedVersionStore(ref.watch(sharedPreferencesProvider)),` to `backupServiceProvider`. The headless `buildScheduledBackupService` only backs up, so it stays as is.

- [ ] **Step 4: Run green**: `flutter test test/features/backup/data/services/backup_service_replace_test.dart`.
- [ ] **Step 5: Commit** `feat(backup): forget the applied species catalog version on restore`.

---

### Task 5: Tool support library (pure functions) with tests

**Files:**
- Create: `tool/src/species_tool_support.dart`
- Test: `test/tool/species_tool_support_test.dart` (imports the library by relative path: `import '../../tool/src/species_tool_support.dart';`)
- Fixture (already saved): `test/fixtures/inaturalist/taxa_esox_lucius_all_names.json`

**Interfaces:**
```dart
const appLocales = ['en', 'de', 'es', 'fr', 'it', 'pt', 'nl', 'hu', 'zh', 'ar', 'he'];
String speciesSlug(String id);                                         // 'sp_x' -> 'x', throws on a bad id
String renderNameLookup(List<Map<String, dynamic>> rows);               // full Dart source of species_name_lookup.dart
String renderDescriptionLookup(List<Map<String, dynamic>> rows);        // full Dart source of species_description_lookup.dart
class ArbSpeciesEntry { final String id; final String name; final String description; }
String insertSpeciesArbKeys(String arbText, List<ArbSpeciesEntry> entries); // after the last species_*_desc line; throws if a key exists
Map<String, String> localizedNamesFromTaxon(Map<String, dynamic> taxon, {required String englishFallback}); // locale -> name for every appLocale
```

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/species_tool_support.dart';

void main() {
  final rows = [
    {'id': 'sp_a_fish', 'commonName': 'A Fish', 'description': 'Desc A'},
    {'id': 'sp_b_ray', 'commonName': 'B Ray', 'description': 'Desc B'},
  ];

  test('speciesSlug strips the prefix and rejects other ids', () {
    expect(speciesSlug('sp_whale_shark'), 'whale_shark');
    expect(() => speciesSlug('whale_shark'), throwsFormatException);
    expect(() => speciesSlug('sp_Whale'), throwsFormatException);
  });

  test('renderNameLookup emits one case per row inside the switch', () {
    final source = renderNameLookup(rows);

    expect(source, contains('// GENERATED by tool/generate_species_lookups.dart'));
    expect(source, contains("String? builtInSpeciesName(AppLocalizations l10n, String id) =>"));
    expect(source, contains("  'sp_a_fish' => l10n.species_a_fish_name,\n"));
    expect(source, contains("  'sp_b_ray' => l10n.species_b_ray_name,\n"));
    expect(source, contains('  _ => null,\n};\n'));
    expect('sp_'.allMatches(source).length, 2 + 1); // two cases plus the doc comment's example
  });

  test('renderDescriptionLookup mirrors the name renderer with _desc', () {
    final source = renderDescriptionLookup(rows);

    expect(source, contains("  'sp_a_fish' => l10n.species_a_fish_desc,\n"));
    expect(source, contains('String? builtInSpeciesDescription('));
  });

  test('insertSpeciesArbKeys lands after the last species_*_desc key', () {
    const arb = '''
{
  "@@locale": "en",
  "species_whale_shark_name": "Whale Shark",
  "species_whale_shark_desc": "Big.",
  "common_action_done": "Done"
}
''';
    final out = insertSpeciesArbKeys(arb, [
      const ArbSpeciesEntry(id: 'sp_a_fish', name: 'A Fish', description: 'Desc "A"'),
    ]);

    final lines = out.split('\n');
    final descAt = lines.indexWhere((l) => l.contains('"species_whale_shark_desc"'));
    expect(lines[descAt + 1], '  "species_a_fish_name": "A Fish",');
    expect(lines[descAt + 2], '  "species_a_fish_desc": "Desc \\"A\\"",');
    expect(lines[descAt + 3], '  "common_action_done": "Done"');
    expect(jsonDecode(out), isA<Map<String, dynamic>>());
  });

  test('insertSpeciesArbKeys refuses an existing key', () {
    const arb = '{\n  "species_whale_shark_name": "W",\n  "species_whale_shark_desc": "B"\n}\n';
    expect(
      () => insertSpeciesArbKeys(arb, [
        const ArbSpeciesEntry(id: 'sp_whale_shark', name: 'x', description: 'y'),
      ]),
      throwsStateError,
    );
  });

  test('localizedNamesFromTaxon picks the top valid name per locale', () async {
    final json = jsonDecode(
      await File('test/fixtures/inaturalist/taxa_esox_lucius_all_names.json').readAsString(),
    ) as Map<String, dynamic>;
    final taxon = (json['results'] as List).first as Map<String, dynamic>;

    final names = localizedNamesFromTaxon(taxon, englishFallback: 'Pike');

    expect(names['en'], 'Northern Pike');
    expect(names['de'], 'Hecht'); // position 0 beats Europaeischer Hecht at 56
    expect(names['zh'], '白斑狗鱼'); // zh-CN preferred over zh (traditional)
    expect(names['pt'], 'Lúcio');
    expect(names['ar'], 'Northern Pike'); // absent: English name, not the fallback
    expect(names.keys.toSet(), appLocales.toSet());
  });

  test('localizedNamesFromTaxon falls back to the seed name without names', () {
    final names = localizedNamesFromTaxon({'name': 'Esox lucius'}, englishFallback: 'Pike');

    expect(names['en'], 'Pike');
    expect(names['he'], 'Pike');
  });
}
```

- [ ] **Step 2: Run it red.**
- [ ] **Step 3: Implement** `tool/src/species_tool_support.dart`:

```dart
// Pure helpers shared by the species catalog tools. Kept free of dart:io and
// the network so test/tool/species_tool_support_test.dart can cover them.

/// App locales, in the order the ARB files are listed.
const List<String> appLocales = [
  'en', 'de', 'es', 'fr', 'it', 'pt', 'nl', 'hu', 'zh', 'ar', 'he',
];

final RegExp _idPattern = RegExp(r'^sp_[a-z0-9_]+$');

/// `sp_whale_shark` -> `whale_shark`, the part the ARB keys are built from.
String speciesSlug(String id) {
  if (!_idPattern.hasMatch(id)) {
    throw FormatException('Species id must match ${_idPattern.pattern}: $id');
  }
  return id.substring(3);
}

const String _generatedHeader =
    '// GENERATED by tool/generate_species_lookups.dart from\n'
    '// assets/data/species.json. Do not edit; rerun the tool.\n';

String renderNameLookup(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer(_generatedHeader)
    ..write('''
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized common names for the built-in species catalog.
///
/// The rows in `assets/data/species.json` are seeded into the `species`
/// table as English literals, and the stored `common_name` is what UDDF export
/// writes out, so that column deliberately stays English. Rendering it
/// directly is what left every species list in English under a translated
/// locale; on-screen callers resolve through here instead.
///
/// Keyed on the stable seed id rather than the name, matching
/// `builtInDiveTypeName`. Custom species carry a UUID id, so they can never
/// collide with an `sp_` slug and always fall through to null.
///
/// Returns null for anything that is not a known built-in id, and callers
/// fall back to the stored English name.
String? builtInSpeciesName(AppLocalizations l10n, String id) => switch (id) {
''');
  for (final row in rows) {
    final id = row['id'] as String;
    buffer.writeln("  '$id' => l10n.species_${speciesSlug(id)}_name,");
  }
  buffer.write('  _ => null,\n};\n');
  return buffer.toString();
}

String renderDescriptionLookup(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer(_generatedHeader)
    ..write('''
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized descriptions for the built-in species catalog.
///
/// Companion to `builtInSpeciesName`; see that file for why the stored column
/// stays English. Split out purely to keep each generated file inside the
/// project's file-size budget.
///
/// Returns null for anything that is not a known built-in id, and callers
/// fall back to the stored English description.
String? builtInSpeciesDescription(
  AppLocalizations l10n,
  String id,
) => switch (id) {
''');
  for (final row in rows) {
    final id = row['id'] as String;
    buffer.writeln("  '$id' => l10n.species_${speciesSlug(id)}_desc,");
  }
  buffer.write('  _ => null,\n};\n');
  return buffer.toString();
}

class ArbSpeciesEntry {
  const ArbSpeciesEntry({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

String _jsonString(String value) {
  final escaped = value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n');
  return '"$escaped"';
}

/// Inserts `species_<slug>_name` and `_desc` lines after the last existing
/// `species_*_desc` line. The ARB files are feature blocks, not sorted, so
/// the anchor is positional. Throws if any key is already present.
String insertSpeciesArbKeys(String arbText, List<ArbSpeciesEntry> entries) {
  final lines = arbText.split('\n');
  final anchorPattern = RegExp(r'^  "species_[a-z0-9_]+_desc": ');
  var anchor = -1;
  for (var i = 0; i < lines.length; i++) {
    if (anchorPattern.hasMatch(lines[i])) anchor = i;
  }
  if (anchor == -1) {
    throw StateError('No species_*_desc key to anchor on');
  }
  final inserted = <String>[];
  for (final entry in entries) {
    final slug = speciesSlug(entry.id);
    for (final key in ['species_${slug}_name', 'species_${slug}_desc']) {
      if (arbText.contains('"$key"')) {
        throw StateError('$key already exists in the ARB file');
      }
    }
    inserted
      ..add('  "species_${slug}_name": ${_jsonString(entry.name)},')
      ..add('  "species_${slug}_desc": ${_jsonString(entry.description)},');
  }
  // The anchor line keeps its trailing comma; the inserted lines all carry
  // one, and the line after the anchor already existed, so the object stays
  // well-formed.
  lines.insertAll(anchor + 1, inserted);
  return lines.join('\n');
}

/// Which iNaturalist name locales serve each app locale, best first.
const Map<String, List<String>> _localeCandidates = {
  'en': ['en'],
  'de': ['de'],
  'es': ['es'],
  'fr': ['fr'],
  'it': ['it'],
  'pt': ['pt', 'pt-BR', 'pt-PT'],
  'nl': ['nl'],
  'hu': ['hu'],
  'zh': ['zh-CN', 'zh'],
  'ar': ['ar'],
  'he': ['he'],
};

/// One name per app locale from a `/v1/taxa?...&all_names=true` taxon: the
/// valid name with the lowest `position` for the best candidate locale,
/// falling back to the taxon's English name, then to [englishFallback].
Map<String, String> localizedNamesFromTaxon(
  Map<String, dynamic> taxon, {
  required String englishFallback,
}) {
  final names = (taxon['names'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((n) => n['is_valid'] != false && n['name'] is String)
      .toList();

  String? best(List<String> candidates) {
    for (final locale in candidates) {
      final matches = names.where((n) => n['locale'] == locale).toList()
        ..sort(
          (a, b) => ((a['position'] as int?) ?? 1 << 30).compareTo(
            (b['position'] as int?) ?? 1 << 30,
          ),
        );
      if (matches.isNotEmpty) return matches.first['name'] as String;
    }
    return null;
  }

  final english =
      best(['en']) ?? taxon['preferred_common_name'] as String? ?? englishFallback;
  return {
    for (final locale in appLocales)
      locale: locale == 'en' ? english : best(_localeCandidates[locale]!) ?? english,
  };
}
```

- [ ] **Step 4: Run green.** Also `flutter analyze tool test/tool`.
- [ ] **Step 5: Commit** `chore(tool): add the species catalog tool support library`.

---

### Task 6: Lookup generator, regeneration, coverage test

**Files:**
- Create: `tool/generate_species_lookups.dart`
- Regenerate: `lib/features/marine_life/presentation/species_name_lookup.dart`, `species_description_lookup.dart`
- Test: `test/features/marine_life/presentation/species_lookup_coverage_test.dart`

- [ ] **Step 1: Write the coverage test** (it passes today; it is the regression net for Task 11):

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/species_description_lookup.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  late Map<String, dynamic> raw;
  late List<Map<String, dynamic>> catalog;

  setUpAll(() async {
    raw =
        jsonDecode(await File('assets/data/species.json').readAsString())
            as Map<String, dynamic>;
    catalog = (raw['species'] as List).cast<Map<String, dynamic>>();
  });

  test('the catalog carries a version of at least 2', () {
    expect(raw['version'], isA<int>());
    expect(raw['version'] as int, greaterThanOrEqualTo(2));
  });

  test('ids are unique and slug-shaped', () {
    final ids = catalog.map((r) => r['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^sp_[a-z0-9_]+$')));
    }
  });

  test('every row resolves through the English ARB to its own text', () {
    final l10n = AppLocalizationsEn();
    for (final row in catalog) {
      final id = row['id'] as String;
      expect(builtInSpeciesName(l10n, id), row['commonName'], reason: id);
      expect(builtInSpeciesDescription(l10n, id), row['description'], reason: id);
    }
  });

  test('the switches carry no case the catalog lacks', () async {
    final ids = catalog.map((r) => r['id'] as String).toSet();
    for (final path in [
      'lib/features/marine_life/presentation/species_name_lookup.dart',
      'lib/features/marine_life/presentation/species_description_lookup.dart',
    ]) {
      final cases = RegExp(r"^  '(sp_[a-z0-9_]+)' =>", multiLine: true)
          .allMatches(await File(path).readAsString())
          .map((m) => m.group(1)!)
          .toList();
      expect(cases.length, ids.length, reason: path);
      expect(cases.toSet().difference(ids), isEmpty, reason: path);
    }
  });
}
```

The version assertion fails until Task 11 bumps the asset; until then run the file expecting exactly that one failure, and note it in the commit message.

- [ ] **Step 2: Write the generator** `tool/generate_species_lookups.dart`:

```dart
// Regenerates the two id-keyed lookup switches from assets/data/species.json.
//
//   dart run tool/generate_species_lookups.dart
//
// No network. Run after any change to the asset, then dart format.
import 'dart:convert';
import 'dart:io';

import 'src/species_tool_support.dart';

Future<void> main() async {
  final catalog =
      jsonDecode(await File('assets/data/species.json').readAsString())
          as Map<String, dynamic>;
  final rows = (catalog['species'] as List).cast<Map<String, dynamic>>();

  const dir = 'lib/features/marine_life/presentation';
  await File('$dir/species_name_lookup.dart').writeAsString(
    renderNameLookup(rows),
  );
  await File('$dir/species_description_lookup.dart').writeAsString(
    renderDescriptionLookup(rows),
  );
  final format = await Process.run('dart', [
    'format',
    '$dir/species_name_lookup.dart',
    '$dir/species_description_lookup.dart',
  ]);
  stdout.write(format.stdout);
  stderr.write(format.stderr);
  stdout.writeln('Wrote ${rows.length} cases into both lookups');
}
```

- [ ] **Step 3: Regenerate and prove equivalence**: `dart run tool/generate_species_lookups.dart`, then `git diff --stat lib/features/marine_life/presentation/` must show only header and doc-comment changes (no case lines added or removed: `git diff lib/features/marine_life/presentation/ | grep "^[-+]  'sp_" | wc -l` prints 0).
- [ ] **Step 4: Run** the coverage test (3 of 4 pass; the version test fails as expected), `test/features/marine_life/presentation/`, and `flutter analyze`.
- [ ] **Step 5: Commit** `chore(marine-life): generate the species lookup switches from the asset`.

---

### Task 7: ARB key tool and freshwater generator (network client injected)

**Files:**
- Create: `tool/generate_species_arb_keys.dart`
- Create: `tool/generate_freshwater_species.dart`
- Create: `tool/src/inaturalist_names_client.dart`

`generate_species_arb_keys.dart`:

```dart
// Inserts species name and description keys for new catalog rows into every
// ARB file, from the localized file the freshwater generator writes.
//
//   dart run tool/generate_species_arb_keys.dart [tool/data/freshwater_species_localized.json]
//
// No network. Follow with: flutter gen-l10n
import 'dart:convert';
import 'dart:io';

import 'src/species_tool_support.dart';

Future<void> main(List<String> args) async {
  final source = args.isEmpty
      ? 'tool/data/freshwater_species_localized.json'
      : args.first;
  final localized =
      (jsonDecode(await File(source).readAsString()) as List)
          .cast<Map<String, dynamic>>();

  for (final locale in appLocales) {
    final path = 'lib/l10n/arb/app_$locale.arb';
    final entries = [
      for (final row in localized)
        ArbSpeciesEntry(
          id: row['id'] as String,
          name: (row['names'] as Map<String, dynamic>)[locale] as String,
          description:
              (row['descriptions'] as Map<String, dynamic>)[locale] as String,
        ),
    ];
    final text = await File(path).readAsString();
    final updated = insertSpeciesArbKeys(text, entries);
    jsonDecode(updated); // refuse to write anything that does not parse
    await File(path).writeAsString(updated);
    stdout.writeln('$locale: added ${entries.length * 2} keys');
  }
}
```

`tool/src/inaturalist_names_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';

const String inaturalistUserAgent = 'Submersion/1.0 (https://submersion.app)';

/// Resolves a scientific name to its iNaturalist taxon with every name
/// attached (`all_names=true`). One request per species; polite pacing.
class InaturalistNamesClient {
  InaturalistNamesClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<Map<String, dynamic>?> taxonByScientificName(
    String scientificName, {
    int? taxonId,
  }) async {
    final uri = taxonId != null
        ? Uri.parse('https://api.inaturalist.org/v1/taxa/$taxonId?all_names=true')
        : Uri.parse(
            'https://api.inaturalist.org/v1/taxa?q=${Uri.encodeQueryComponent(scientificName)}'
            '&rank=species&all_names=true&per_page=5',
          );
    for (var attempt = 1; attempt <= 3; attempt++) {
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, inaturalistUserAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final results = ((jsonDecode(body) as Map<String, dynamic>)['results'] as List)
            .cast<Map<String, dynamic>>();
        for (final r in results) {
          if (taxonId != null || r['name'] == scientificName) return r;
        }
        return null;
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
    throw HttpException('iNaturalist failed for $scientificName');
  }

  void close() => _client.close();
}
```

`generate_freshwater_species.dart`:

```dart
// Turns tool/data/freshwater_species_seed.json into catalog rows.
//
//   dart run tool/generate_freshwater_species.dart
//
// Network (iNaturalist, one request per species, one per second). Writes
// assets/data/species.json (appended rows, version bumped) and
// tool/data/freshwater_species_localized.json, then prints the follow-ups.
import 'dart:convert';
import 'dart:io';

import 'src/inaturalist_names_client.dart';
import 'src/species_tool_support.dart';

Future<void> main() async {
  final seed = (jsonDecode(
    await File('tool/data/freshwater_species_seed.json').readAsString(),
  ) as List).cast<Map<String, dynamic>>();
  final catalogFile = File('assets/data/species.json');
  final catalog = jsonDecode(await catalogFile.readAsString()) as Map<String, dynamic>;
  final rows = (catalog['species'] as List).cast<Map<String, dynamic>>();
  final existingIds = rows.map((r) => r['id']).toSet();
  final existingSci = rows.map((r) => r['scientificName']).whereType<String>().toSet();

  for (final entry in seed) {
    final id = entry['id'] as String;
    speciesSlug(id);
    if (existingIds.contains(id)) throw StateError('$id already in the catalog');
    if (existingSci.contains(entry['scientificName'])) {
      throw StateError('${entry['scientificName']} already in the catalog');
    }
    final descriptions = entry['description'] as Map<String, dynamic>;
    for (final locale in appLocales) {
      if (descriptions[locale] is! String) {
        throw StateError('$id lacks a $locale description');
      }
    }
  }

  final client = InaturalistNamesClient();
  final localized = <Map<String, dynamic>>[];
  final added = <Map<String, dynamic>>[];
  try {
    for (final entry in seed) {
      final scientific = entry['scientificName'] as String;
      final taxon = await client.taxonByScientificName(
        scientific,
        taxonId: entry['inaturalistTaxonId'] as int?,
      );
      if (taxon == null) stderr.writeln('No iNaturalist taxon for $scientific');
      final names = localizedNamesFromTaxon(
        taxon ?? const {},
        englishFallback: entry['commonName'] as String,
      );
      added.add({
        'id': entry['id'],
        'commonName': names['en'],
        'scientificName': scientific,
        'category': entry['category'],
        'taxonomyClass': entry['taxonomyClass'],
        'description': (entry['description'] as Map<String, dynamic>)['en'],
      });
      localized.add({
        'id': entry['id'],
        'names': names,
        'descriptions': entry['description'],
      });
      stdout.writeln('${entry['id']}: ${names['en']} (${taxon?['id'] ?? 'no taxon'})');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    client.close();
  }

  const encoder = JsonEncoder.withIndent('  ');
  await catalogFile.writeAsString(
    '${encoder.convert({'version': (catalog['version'] as int? ?? 1) + 1, 'species': [...rows, ...added]})}\n',
  );
  await File('tool/data/freshwater_species_localized.json').writeAsString(
    '${encoder.convert(localized)}\n',
  );
  stdout.writeln('Added ${added.length} rows. Now run:');
  stdout.writeln('  dart run tool/generate_species_arb_keys.dart');
  stdout.writeln('  flutter gen-l10n');
  stdout.writeln('  dart run tool/generate_species_lookups.dart');
  stdout.writeln('  dart run tool/generate_species_gbif_keys.dart');
}
```

- [ ] **Step 1: Write the files**, `flutter analyze tool`, and a dry run of the ARB tool against a throwaway copy: `cp lib/l10n/arb/app_en.arb /tmp/x.arb` is not needed; instead run `dart run tool/generate_species_arb_keys.dart test/fixtures/species_localized_sample.json` only after Task 11 produces real input. For now the analyzer is the check.
- [ ] **Step 2: Commit** `chore(tool): add the ARB key and freshwater species generators`.

---

### Task 8: Freshwater seed, part 1 (about 50 North American and European fish)

**Files:**
- Create: `tool/data/freshwater_species_seed.json` (a JSON array)

Each entry has `id`, `scientificName`, `category`, `taxonomyClass`, `commonName`, `description` with all 11 locales. `inaturalistTaxonId` is optional and omitted (the tool resolves by scientific name). Descriptions are one sentence, 10 to 20 words, about what a diver sees (shape, markings, habitat, behaviour), written natively in each language, not word-for-word.

Species (ids follow the English name): northern pike, muskellunge, chain pickerel, walleye, sauger, yellow perch, European perch, zander, ruffe, largemouth bass, smallmouth bass, rock bass, bluegill, pumpkinseed, black crappie, white crappie, brown trout, rainbow trout, brook trout, lake trout, Arctic char, Atlantic salmon, chinook salmon, sockeye salmon, coho salmon, kokanee, lake whitefish, cisco, European grayling, common carp, grass carp, tench, common bream, roach, rudd, chub, barbel, European eel, American eel, burbot, channel catfish, flathead catfish, brown bullhead, wels catfish, white sturgeon, lake sturgeon, European sturgeon, alligator gar, longnose gar, bowfin, American paddlefish, sea lamprey, freshwater drum, white sucker, common minnow, three-spined stickleback, alewife.

- [ ] **Step 1: Write the entries** (a python script in the scratchpad that assembles the list and dumps it with `ensure_ascii=False, indent=2`).
- [ ] **Step 2: Validate**: a scratchpad check that ids are unique, match the pattern, every entry has all 11 description locales as non-empty strings, and no scientific name already appears in `assets/data/species.json`.
- [ ] **Step 3: Commit** `data(marine-life): curate freshwater fish of North America and Europe`.

### Task 9: Freshwater seed, part 2 (about 50 fish from Africa, South America, Asia, Australia)

Species: Nile perch, Nile tilapia, African tigerfish, marbled lungfish, electric catfish, Lake Malawi cichlids (blue mbuna `Pseudotropheus zebra`... choose clearly valid names: `Maylandia zebra`, `Aulonocara jacobfreibergi`, `Labeotropheus fuelleborni`), Tanganyika: `Neolamprologus brichardi`, `Cyphotilapia frontosa`, `Tropheus moorii`; Amazon: arapaima, silver arowana, red-bellied piranha, black piranha, pacu (`Piaractus brachypomus`), tambaqui, electric eel, ocellate river stingray (`Potamotrygon motoro`), redtail catfish, tiger shovelnose catfish, peacock bass (`Cichla ocellaris`), oscar, angelfish (`Pterophyllum scalare`), discus, armored catfish (`Pterygoplichthys pardalis`), cardinal tetra, Mexican tetra (blind cave form), Asian: Mekong giant catfish, giant barb (`Catlocarpio siamensis`), Asian arowana, snakehead (`Channa striata`), giant snakehead, climbing perch, mahseer (`Tor putitora`), koi (`Cyprinus rubrofuscus`), goldfish, giant gourami, clown knifefish, walking catfish, Japanese eel, ayu, Baikal omul, Baikal oilfish (golomyanka `Comephorus baikalensis`), Australian: Murray cod, golden perch, Australian bass, barramundi, silver perch, saratoga (`Scleropages jardinii`), sooty grunter, freshwater sawfish (`Pristis pristis`), bull shark (skip if already marine; check), eel-tailed catfish, spangled perch, rainbowfish (`Melanotaenia splendida`).

- [ ] Steps as Task 8 (write, validate, commit `data(marine-life): curate freshwater fish of Africa, the Americas, Asia and Australia`).

### Task 10: Freshwater seed, part 3 (about 50 non-fish: invertebrates, reptiles, amphibians, mammals, plants)

Species: signal crayfish, red swamp crayfish, noble crayfish, white-clawed crayfish, Tasmanian giant freshwater crayfish, zebra mussel, quagga mussel, freshwater pearl mussel, Chinese pond mussel, swan mussel, freshwater sponge (`Spongilla lacustris`), freshwater jellyfish (`Craspedacusta sowerbii`), great pond snail, ramshorn snail, apple snail (`Pomacea canaliculata`), freshwater bryozoan (`Pectinatella magnifica`), Chinese mitten crab, giant freshwater prawn, water boatman? (skip insects); reptiles: common snapping turtle, alligator snapping turtle, painted turtle, red-eared slider, common map turtle, spiny softshell, Florida softshell, pig-nosed turtle, Mary River turtle, yellow-spotted river turtle, European pond turtle, American alligator, spectacled caiman, black caiman, freshwater crocodile (`Crocodylus johnstoni`), Nile crocodile (check not marine-listed), northern water snake, anaconda (`Eunectes murinus`); amphibians (`other`, class Amphibia): hellbender, mudpuppy, axolotl, Chinese giant salamander, smooth newt, great crested newt, American bullfrog, common frog; mammals: North American river otter, Eurasian otter, giant otter, North American beaver, Eurasian beaver, muskrat, platypus, Florida manatee (`Trichechus manatus latirostris` if the marine catalog lacks it, else skip), Amazonian manatee, Amazon river dolphin, Baikal seal, capybara, hippopotamus; plants: white water lily, yellow pond lily, spatterdock, American eelgrass (`Vallisneria americana`), coontail, Eurasian watermilfoil, muskgrass (`Chara vulgaris`), Canadian waterweed, curly-leaf pondweed, water hyacinth, hornwort, common reed.

Every mammal, reptile and amphibian gets the right `taxonomyClass` (`Mammalia`, `Reptilia`, `Amphibia`); invertebrates `Malacostraca`, `Bivalvia`, `Gastropoda`, `Demospongiae`, `Hydrozoa`, `Phylactolaemata`; plants `Magnoliopsida`/`Liliopsida`/`Charophyceae`.

- [ ] Steps as Task 8 (commit `data(marine-life): curate freshwater invertebrates, reptiles, amphibians, mammals and plants`). Before writing, `grep -i "manatee\|crocodile\|otter\|hippo\|bull shark\|sawfish" assets/data/species.json` and drop anything already present.

---

### Task 11: Generate the catalog (network) and refresh every artifact

- [ ] **Step 1**: `dart run tool/generate_freshwater_species.dart > scratch/freshwater_gen.log 2>&1` (about 3 minutes). Read the log: every line names a taxon id; "No iNaturalist taxon" lines mean a scientific name iNat spells differently; fix the seed (or add `inaturalistTaxonId`) and rerun after `git checkout assets/data/species.json`.
- [ ] **Step 2**: `dart run tool/generate_species_arb_keys.dart`, `flutter gen-l10n`, `dart run tool/generate_species_lookups.dart`.
- [ ] **Step 3**: extend `_straddlingTaxa` in `tool/generate_species_gbif_keys.dart` with the freshwater families that hold terrestrial relatives, each with a one-line comment: `Cricetidae` (muskrat, with voles and hamsters), `Emydidae` (pond turtles, with box turtles), `Colubridae` (water snakes, with most land snakes), `Salamandridae` (newts, with land salamanders), `Ambystomatidae` (axolotl, with mole salamanders), `Rodentia` (beaver and capybara, with every rat and squirrel), `Caviidae` (capybara, with guinea pigs), `Boidae` (anaconda, with boas), `Haloragaceae` (milfoil, with land Gunnera relatives), `Poaceae` (common reed, with every grass). Then `dart run tool/generate_species_gbif_keys.dart > scratch/gbif_gen.log 2>&1` and read the unmatched list; tighten `species_gbif_keys_asset_test.dart:27` to `0.9`.
- [ ] **Step 4**: run `test/features/marine_life/presentation/species_lookup_coverage_test.dart`, `test/l10n/arb_parity_test.dart`, `test/features/reef/domain/services/species_gbif_keys_asset_test.dart`, `test/features/marine_life/`, `test/features/reef/`; then `flutter analyze --fatal-infos`.
- [ ] **Step 5**: Commit in two parts: `data(marine-life): add the freshwater species to the bundled catalog (v2)` (asset, ARBs, generated l10n, lookups, localized json) and `chore(reef): refresh GBIF keys for the freshwater catalog` (tool change, asset, test threshold).

---

### Task 12: Docs, format, full suite

- [ ] `docs/features/marine-life.md`: under "## Species Database" add a sentence that the catalog covers freshwater species (lakes, rivers, springs and cenotes) and that catalog corrections reach existing installs without touching species the diver edited; add a new section before "## Identification Tips":

```
## Growing the Catalog (maintainers)

The bundled catalog is `assets/data/species.json`; its `version` gates a
one-time upgrade pass on each device that rewrites rows the diver never
edited. To add species:

1. Add entries to `tool/data/freshwater_species_seed.json` (or a sibling seed)
   with descriptions in all 11 locales.
2. `dart run tool/generate_freshwater_species.dart` (network) writes the
   catalog rows and the localized names file and bumps the version.
3. `dart run tool/generate_species_arb_keys.dart`, `flutter gen-l10n`,
   `dart run tool/generate_species_lookups.dart`,
   `dart run tool/generate_species_gbif_keys.dart` (network).
4. Run `test/features/marine_life/presentation/species_lookup_coverage_test.dart`.

Suggestions filed through the in-app "Suggest for the catalog" action arrive
as GitHub issues labelled `species-suggestion`; they land in the seed the same
way.
```

- [ ] `dart format .`, `flutter analyze --fatal-infos`, full `flutter test` detached with the exit line checked, commit `docs: describe the versioned species catalog and its tools`. Do not push.

## Self-review notes

- Spec 4.1: Tasks 1 to 4. Spec 4.2: Tasks 5 to 7 (generators, coverage test). Spec 4.3: Tasks 8 to 11. Spec 4.4 error handling: Task 2 (malformed prefs), Task 4 (clear failure logged), Task 7 (retries, validate-before-write, refuse existing keys). Spec 4.5 tests: Tasks 1 to 6 and 11. Docs: Task 12.
- The spec listed `tool/data/freshwater_species_localized.json` as generated output; Task 7 writes it and Task 11 commits it.
- `seedBuiltInSpecies` takes the store per call rather than through the constructor so the dozens of `SpeciesRepository()` call sites and tests stay untouched; the spec's "optional constructor parameter" wording is superseded by this.
