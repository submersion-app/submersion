# Site Features (Annotation Backbone) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A synced `site_features` table of diver-placed annotations (wreck, mooring, entry, exit, swim-through, hazard, current) rendered on the 2D map and the 3D seascape, with tap-to-place, tap-to-edit, and a site detail Features section, in one PR.

**Architecture:** Full LWW entity (own `hlc`, `entityHasUpdatedAt: true`) following the `ServiceRecords` shape; `SiteSpecies` is the site-scoped child reference. 2D rendering is a self-contained `SiteFeatureMarkerLayer` dropped into all four site-selected map hosts; 3D rendering rides the existing `SceneMarker` pipeline with a new kind and a new `SceneOverlay.features` gate. Placement is host state on the site detail fullscreen page only.

**Tech Stack:** Drift, Riverpod (project hub `core/providers/provider.dart`), flutter_map, the existing sync serializer/service/repository trio.

**Spec:** `docs/superpowers/specs/2026-08-16-site-features-design.md`

## Global Constraints

- Never use an em-dash (U+2014) anywhere: code, comments, docs, commits, PR body.
- No Co-Authored-By in commits; no attribution line or session URL in the PR body.
- New l10n keys go into ALL 11 arb files (en, ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` from the project root; generated `app_localizations*.dart` under `lib/l10n/arb/` ARE committed. `database.g.dart` is NEVER committed.
- `dart format .` before every commit; `flutter analyze` clean (infos are CI-fatal).
- Riverpod 3: `StateNotifier`/`valueOrNull` come from `package:submersion/core/providers/provider.dart`. In tests, the `Override` type comes from `test/helpers/mock_providers.dart` (typedef), not from any package import.
- Depth is STORED in meters and DISPLAYED in the diver's unit everywhere.
- Map-hosting widget tests use bounded pumps, never `pumpAndSettle`; pin `locale: Locale('en')` wherever finders use English strings.
- Capture test exit codes directly (`flutter test ... > log 2>&1; code=$?`), never through a pipe; print `pwd` in the same compound command as builds/tests.
- Drift names the `SiteFeatures` row class `SiteFeature`, colliding with the domain entity: import the domain file `as domain` wherever both are in scope (house convention).
- All commands run from `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-features`.

---

### Task 1: Worktree init

**Files:** none (environment only; the worktree and branch `worktree-site-features` already exist, cut from origin/main).

- [ ] **Step 1: Initialize**

```bash
pwd   # must print .../worktrees/site-features
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Sanity**

Run: `pwd && flutter test test/features/dive_sites/presentation/pages/site_map_page_test.dart > /tmp/sf_t1.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

---

### Task 2: Schema v152

**Files:**
- Modify: `lib/core/database/database.dart` (table after the `SiteSpecies` class ~line 2833; `currentSchemaVersion` line 3029; `migrationVersions` tail ~line 3245; `onUpgrade` tail ~line 8019; `beforeOpen` backstop block ~line 8105)
- Modify: `lib/core/database/performance_indexes.dart` (next to `idx_site_species_site` ~line 177)
- Test: `test/core/database/migration_v152_site_features_test.dart` (new)

**Interfaces:**
- Produces: Drift table `SiteFeatures` (row class `SiteFeature`, companion `SiteFeaturesCompanion`, accessor `_db.siteFeatures`) with columns `id, siteId, type, name, latitude, longitude, bearingDeg, depthMeters, notes, createdAt, updatedAt, hlc`. Every later task depends on these exact column names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  test('v152 is claimed and site_features round-trips', () async {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(152));
    expect(AppDatabase.migrationVersions, contains(152));

    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f-1',
            siteId: 'site-1',
            type: 'wreck',
            latitude: 12.15,
            longitude: -68.3,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final row = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(row.type, 'wreck');
    expect(row.bearingDeg, isNull);
    expect(row.hlc, isNull);

    // FK cascade: deleting the site removes the feature.
    await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();
    final left = await db.select(db.siteFeatures).get();
    expect(left, isEmpty);
  });
}
```

If `DiveSitesCompanion.insert` requires different named args, mirror whatever an existing test (e.g., the v140 migration test) uses to insert a site; the assertion body stays.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_v152_site_features_test.dart`
Expected: compile FAIL (`siteFeatures` undefined).

- [ ] **Step 3: Implement the schema**

1. Table, inserted immediately after the `SiteSpecies` class:

```dart
/// Diver-placed annotations on a dive site (slice 2 of the seascape
/// usefulness program): wrecks, moorings, entry/exit points,
/// swim-throughs, hazards, and typical-current arrows. Points only;
/// optional bearing (current direction, wreck orientation) and optional
/// depth (meters). Mutable LWW entity: carries its own hlc.
class SiteFeatures extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();

  /// SiteFeatureType enum name. Plain text so rows from a newer build
  /// with unknown types survive; the UI renders a generic marker.
  TextColumn get type => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// 0-359 compass degrees; current direction or wreck orientation.
  RealColumn get bearingDeg => real().nullable()();

  /// Stored meters; displayed in the diver's unit.
  RealColumn get depthMeters => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

2. Register the table in the `@DriftDatabase(tables: [...])` annotation list (add `SiteFeatures` next to `SiteSpecies`).
3. `currentSchemaVersion` 151 -> 152; append to `migrationVersions`:

```dart
    // v152: site_features (seascape program slice 2): diver-placed
    // annotations on a site, synced LWW.
    152,
```

4. `onUpgrade`, after the v151 block:

```dart
        // v152: site features annotation table (slice 2).
        if (from < 152) {
          await createMigrator().createTable(siteFeatures);
        }
        if (from < 152) await reportProgress();
```

5. `beforeOpen` backstop, next to the v121 createTable backstops:

```dart
        // v152 backstop: site features table (parallel-branch
        // version-collision self-heal; createTable is idempotent).
        await createMigrator().createTable(siteFeatures);
```

6. `performance_indexes.dart`, next to `idx_site_species_site`:

```dart
  'CREATE INDEX IF NOT EXISTS idx_site_features_site '
      'ON site_features (site_id)',
```

(match the exact list-entry syntax of the neighboring index entries).
7. Regenerate: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run to verify pass**

Run: `pwd && flutter test test/core/database/migration_v152_site_features_test.dart test/core/database/ > /tmp/sf_t2.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0 (the whole database suite guards the ladder claims).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v152_site_features_test.dart
git commit -m "feat(sitefeatures): site_features table, schema v152"
```

---

### Task 3: Domain entity + type enum

**Files:**
- Create: `lib/features/dive_sites/domain/entities/site_feature.dart`
- Test: `test/features/dive_sites/domain/entities/site_feature_test.dart` (new)

**Interfaces:**
- Produces:

```dart
enum SiteFeatureType { wreck, mooring, entry, exit, swimThrough, hazard, current }

class SiteFeature {
  final String id;
  final String siteId;
  final String typeName;          // raw stored string, survives unknown types
  final String name;
  final double latitude;
  final double longitude;
  final double? bearingDeg;
  final double? depthMeters;
  final String notes;
  SiteFeatureType? get type;      // null when typeName is unknown
  SiteFeature copyWith({...});    // clearBearing/clearDepth flags for nullables
}
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

void main() {
  const base = SiteFeature(
    id: 'f-1',
    siteId: 's-1',
    typeName: 'wreck',
    latitude: 12.15,
    longitude: -68.3,
  );

  test('known type decodes; unknown type survives and decodes null', () {
    expect(base.type, SiteFeatureType.wreck);
    final future = base.copyWith(typeName: 'lavaTube');
    expect(future.type, isNull);
    expect(future.typeName, 'lavaTube');
    // copyWith without typeName preserves the raw unknown name.
    expect(future.copyWith(name: 'x').typeName, 'lavaTube');
  });

  test('copyWith clears nullables only via flags', () {
    final f = base.copyWith(bearingDeg: 45, depthMeters: 18);
    expect(f.copyWith().bearingDeg, 45);
    expect(f.copyWith(clearBearing: true).bearingDeg, isNull);
    expect(f.copyWith(clearDepth: true).depthMeters, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/domain/entities/site_feature_test.dart`
Expected: compile FAIL.

- [ ] **Step 3: Implement**

```dart
/// The fixed feature vocabulary for slice 2. Stored as the enum NAME;
/// user-extensible types are out of scope.
enum SiteFeatureType { wreck, mooring, entry, exit, swimThrough, hazard, current }

/// A diver-placed annotation on a dive site: a point with an optional
/// bearing and optional depth. [typeName] keeps the raw stored string so
/// a type from a newer app version round-trips unchanged; [type] is null
/// for unknown names and the UI renders a generic marker.
class SiteFeature {
  final String id;
  final String siteId;
  final String typeName;
  final String name;
  final double latitude;
  final double longitude;
  final double? bearingDeg;
  final double? depthMeters;
  final String notes;

  const SiteFeature({
    required this.id,
    required this.siteId,
    required this.typeName,
    this.name = '',
    required this.latitude,
    required this.longitude,
    this.bearingDeg,
    this.depthMeters,
    this.notes = '',
  });

  SiteFeatureType? get type => SiteFeatureType.values.asNameMap()[typeName];

  SiteFeature copyWith({
    String? id,
    String? siteId,
    String? typeName,
    String? name,
    double? latitude,
    double? longitude,
    double? bearingDeg,
    bool clearBearing = false,
    double? depthMeters,
    bool clearDepth = false,
    String? notes,
  }) {
    return SiteFeature(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      typeName: typeName ?? this.typeName,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bearingDeg: clearBearing ? null : (bearingDeg ?? this.bearingDeg),
      depthMeters: clearDepth ? null : (depthMeters ?? this.depthMeters),
      notes: notes ?? this.notes,
    );
  }
}
```

- [ ] **Step 4: Run to verify pass, commit**

Run the test file (PASS), then:

```bash
dart format .
git add lib/features/dive_sites/domain/entities/site_feature.dart test/features/dive_sites/domain/entities/site_feature_test.dart
git commit -m "feat(sitefeatures): SiteFeature domain entity"
```

---

### Task 4: Repository + providers

**Files:**
- Create: `lib/features/dive_sites/data/repositories/site_feature_repository.dart`
- Create: `lib/features/dive_sites/presentation/providers/site_feature_providers.dart`
- Test: `test/features/dive_sites/data/repositories/site_feature_repository_test.dart` (new)

**Interfaces:**
- Consumes: `SiteFeatures` table (Task 2), `domain.SiteFeature` (Task 3), `SyncRepository.markRecordPending/logDeletion`, `SyncEventBus.notifyLocalChange`.
- Produces:

```dart
class SiteFeatureRepository {
  Future<domain.SiteFeature> addFeature({required String siteId, required String typeName, required double latitude, required double longitude, double? bearingDeg, double? depthMeters, String name = '', String notes = ''});
  Future<List<domain.SiteFeature>> getFeaturesForSite(String siteId);
  Future<void> updateFeature(domain.SiteFeature feature);
  Future<void> deleteFeature(String id);
}
final siteFeatureRepositoryProvider; // Provider<SiteFeatureRepository>
final siteFeaturesProvider;          // FutureProvider.family<List<domain.SiteFeature>, String> by siteId
```

- [ ] **Step 1: Write the failing test**

Model the harness on `test/features/dive_sites/...` repository tests (setUpTestDatabase + a real site row):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SiteFeatureRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = SiteFeatureRepository();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('add / list / update / delete round-trip with the sync ritual', () async {
    final f = await repo.addFeature(
      siteId: 'site-1',
      typeName: 'mooring',
      latitude: 12.151,
      longitude: -68.299,
      depthMeters: 6,
    );
    expect(f.type?.name, 'mooring');

    final listed = await repo.getFeaturesForSite('site-1');
    expect(listed, hasLength(1));

    // The write ritual: the row is pending AND carries an hlc stamp.
    final row = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals(f.id))).getSingle();
    expect(row.hlc, isNotNull);
    final pending = await db.select(db.syncPendingRecords).get();
    expect(
      pending.where((p) => p.entityType == 'siteFeatures'),
      isNotEmpty,
    );
    // The parent site was bumped too.
    expect(pending.where((p) => p.entityType == 'diveSites'), isNotEmpty);

    await repo.updateFeature(f.copyWith(name: 'North ball', bearingDeg: 90));
    final updated = (await repo.getFeaturesForSite('site-1')).single;
    expect(updated.name, 'North ball');
    expect(updated.bearingDeg, 90);

    await repo.deleteFeature(f.id);
    expect(await repo.getFeaturesForSite('site-1'), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where(
        (d) => d.entityType == 'siteFeatures' && d.recordId == f.id,
      ),
      isNotEmpty,
    );
  });
}
```

If the pending/deletion tables have different accessor names, mirror the assertions used in an existing repository test that checks `markRecordPending`/`logDeletion` effects (`species_repository` tests are the reference); the assertions' INTENT is binding.

- [ ] **Step 2: Run to verify failure**, then **Step 3: Implement**

Repository (mirror `species_repository.dart`'s structure: `AppDatabase get _db => DatabaseService.instance.database;`, a `SyncRepository` field, `const Uuid()`):

```dart
class SiteFeatureRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<domain.SiteFeature> addFeature({
    required String siteId,
    required String typeName,
    required double latitude,
    required double longitude,
    double? bearingDeg,
    double? depthMeters,
    String name = '',
    String notes = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: id,
            siteId: siteId,
            type: typeName,
            latitude: latitude,
            longitude: longitude,
            name: Value(name),
            bearingDeg: Value(bearingDeg),
            depthMeters: Value(depthMeters),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _markPendingAndBumpSite(id, siteId, now);
    return domain.SiteFeature(
      id: id,
      siteId: siteId,
      typeName: typeName,
      name: name,
      latitude: latitude,
      longitude: longitude,
      bearingDeg: bearingDeg,
      depthMeters: depthMeters,
      notes: notes,
    );
  }

  Future<List<domain.SiteFeature>> getFeaturesForSite(String siteId) async {
    final rows =
        await (_db.select(_db.siteFeatures)
              ..where((t) => t.siteId.equals(siteId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  Future<void> updateFeature(domain.SiteFeature feature) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.siteFeatures,
    )..where((t) => t.id.equals(feature.id))).write(
      SiteFeaturesCompanion(
        type: Value(feature.typeName),
        name: Value(feature.name),
        latitude: Value(feature.latitude),
        longitude: Value(feature.longitude),
        bearingDeg: Value(feature.bearingDeg),
        depthMeters: Value(feature.depthMeters),
        notes: Value(feature.notes),
        updatedAt: Value(now),
      ),
    );
    await _markPendingAndBumpSite(feature.id, feature.siteId, now);
  }

  Future<void> deleteFeature(String id) async {
    final row = await (_db.select(
      _db.siteFeatures,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.siteFeatures)..where((t) => t.id.equals(id))).go();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.logDeletion(
      entityType: 'siteFeatures',
      recordId: id,
    );
    await _bumpSite(row.siteId, now);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPendingAndBumpSite(
    String id,
    String siteId,
    int now,
  ) async {
    await _syncRepository.markRecordPending(
      entityType: 'siteFeatures',
      recordId: id,
      localUpdatedAt: now,
    );
    await _bumpSite(siteId, now);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _bumpSite(String siteId, int now) async {
    await (_db.update(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).write(
      DiveSitesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveSites',
      recordId: siteId,
      localUpdatedAt: now,
    );
  }

  domain.SiteFeature _toDomain(SiteFeature row) => domain.SiteFeature(
    id: row.id,
    siteId: row.siteId,
    typeName: row.type,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    bearingDeg: row.bearingDeg,
    depthMeters: row.depthMeters,
    notes: row.notes,
  );
}
```

Imports: `database.dart`, `database_service.dart`, `sync_repository.dart`, `sync_event_bus` (find its import in `species_repository.dart` and copy), `package:drift/drift.dart` (for `Value`), `package:uuid/uuid.dart`, and the domain entity `as domain`.

Providers file:

```dart
final siteFeatureRepositoryProvider = Provider<SiteFeatureRepository>(
  (ref) => SiteFeatureRepository(),
);

/// Features for one site, refreshed on any site_features table change.
final siteFeaturesProvider =
    FutureProvider.family<List<domain.SiteFeature>, String>((
      ref,
      siteId,
    ) async {
      final repo = ref.watch(siteFeatureRepositoryProvider);
      ref.invalidateSelfWhen(
        DatabaseService.instance.database.tableUpdates(
          TableUpdateQuery.onTable(
            DatabaseService.instance.database.siteFeatures,
          ),
        ),
      );
      return repo.getFeaturesForSite(siteId);
    });
```

(`invalidateSelfWhen` is the project extension exported by `core/providers/provider.dart`; `siteExpectedSpeciesProvider` is the reference. If the stream type mismatches, adapt exactly the way that provider consumes its change stream.)

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/dive_sites/data/ test/features/dive_sites/domain/ > /tmp/sf_t4.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

```bash
dart format .
git add lib/features/dive_sites/data/repositories/site_feature_repository.dart lib/features/dive_sites/presentation/providers/site_feature_providers.dart test/features/dive_sites/data/repositories/site_feature_repository_test.dart
git commit -m "feat(sitefeatures): repository, providers, write ritual"
```

---

### Task 5: Sync enrollment (LWW)

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (12 points; `serviceRecords` is the template at lines 243, 317, 392, 468, 734, 1242, 1668, 2115, and the `siteSpecies` cases at 1873/2794/3507/3738/3963/4339)
- Modify: `lib/core/services/sync/sync_service.dart` (merge list ~1301, `entityHasUpdatedAt` ~1910, `parentRefs` ~2014)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map ~line 31)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (the `syncedTables` map at ~line 18)
- Test: `test/core/services/sync/site_features_sync_test.dart` (new)

**Interfaces:**
- Consumes: the `siteFeatures` table (Task 2).
- Produces: the `'siteFeatures'` sync entity, LWW, exported by its own `hlc`. Task 6 relies on `markRecordPending('siteFeatures')` stamping hlc (via `_hlcTargets`).

- [ ] **Step 1: Write the failing round-trip test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f-1',
            siteId: 'site-1',
            type: 'hazard',
            latitude: 12.15,
            longitude: -68.3,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('siteFeatures export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('siteFeatures', 'f-1');
    expect(record, isNotNull);
    expect(record!['type'], 'hazard');

    // Remote edit merges over the local row (LWW payload apply).
    await serializer.upsertRecord('siteFeatures', {
      ...record,
      'name': 'Fire coral patch',
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('siteFeatures', 'f-1');
    expect(merged!['name'], 'Fire coral patch');

    expect(await serializer.recordIdsFor('siteFeatures'), contains('f-1'));

    await serializer.deleteRecord('siteFeatures', 'f-1');
    expect(await serializer.fetchRecord('siteFeatures', 'f-1'), isNull);
  });
}
```

If `SyncDataSerializer`'s method names differ in casing or the constructor needs the db, mirror how `sync_data_serializer_record_ids_test.dart` instantiates and calls it; the round-trip intent is binding.

- [ ] **Step 2: Run to verify failure** (`recordIdsFor` throws on missing case by design), then **Step 3: Implement all enrollment points**

In `sync_data_serializer.dart`, add `siteFeatures` everywhere `serviceRecords` appears as a pattern, adjacent to the `siteSpecies` entries so site-scoped data stays together:

1. Field: `final List<Map<String, dynamic>> siteFeatures;`
2. Ctor default: `this.siteFeatures = const [],`
3. `toJson`: `'siteFeatures': siteFeatures,` (position defines the required `_baseTables` order)
4. `fromJson`: `siteFeatures: _parseList(json['siteFeatures']),`
5. `_baseTables`, at the SAME relative position as the toJson key:

```dart
    (key: 'siteFeatures', table: _db.siteFeatures, blob: false, full: null),
```

6. `_buildSyncData`:

```dart
      siteFeatures: await _safeExport(
        'siteFeatures',
        () => _exportSiteFeatures(hlcSince),
      ),
```

7. `fetchRecord` case:

```dart
      case 'siteFeatures':
        final row = await (_db.select(
          _db.siteFeatures,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

8. `upsertRecord` case:

```dart
      case 'siteFeatures':
        await _db
            .into(_db.siteFeatures)
            .insertOnConflictUpdate(
              SiteFeature.fromJson(_withTimestampDefaults(data)),
            );
        return;
```

9. `upsertRecords` (batched) case:

```dart
      case 'siteFeatures':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.siteFeatures,
            records
                .map((r) => SiteFeature.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
```

10. `recordIdsFor` case: `case 'siteFeatures': return plain(_db.siteFeatures, _db.siteFeatures.id);`
11. `_syncTableFor` case: `case 'siteFeatures': return _db.siteFeatures;`
12. `deleteRecord` case:

```dart
      case 'siteFeatures':
        await (_db.delete(
          _db.siteFeatures,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

Plus the delta export, next to `_exportServiceRecords` (own-hlc filter, NOT a parent join):

```dart
  Future<List<Map<String, dynamic>>> _exportSiteFeatures(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.siteFeatures);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

In `sync_service.dart`:
- Merge list, after the `siteSpecies` entry: `(type: 'siteFeatures', records: data.siteFeatures, hasUpdatedAt: true),`
- `entityHasUpdatedAt`: `'siteFeatures': true,`
- `parentRefs`:

```dart
    'siteFeatures': [
      (field: 'siteId', parent: 'diveSites', nullable: false),
    ],
```

In `sync_repository.dart` `_hlcTargets`: `'siteFeatures': (table: 'site_features', pk: 'id'),`

In `sync_parent_refs_completeness_test.dart` `syncedTables`: `'site_features': 'siteFeatures',`

- [ ] **Step 4: Run the full sync suite**

Run: `pwd && flutter test test/core/services/sync/ test/core/data/ > /tmp/sf_t5.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. The completeness suites (parent refs, record ids, hlc column, streaming parity, round-trip, batch coverage) each enumerate entities and their failure messages NAME any spot still missing; fix exactly what they name until green.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/sync/ lib/core/data/repositories/sync_repository.dart test/core/services/sync/
git commit -m "feat(sitefeatures): enroll siteFeatures as an LWW sync entity"
```

---

### Task 6: Site merge relink + undo

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (snapshot capture ~453-491, transaction ~493-518, relink helpers ~848, `MergeSnapshot` ~985, `undoMerge` ~569)
- Test: `test/features/dive_sites/data/repositories/site_merge_features_test.dart` (new)

**Interfaces:**
- Consumes: `siteFeatures` table, `markRecordPending('siteFeatures')` (Task 5's hlc stamp).
- Produces: `MergeSnapshot.featureOriginalSiteIds` (`Map<String, String>`, defaults `const {}`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['keep', 'lose']) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f-1',
            siteId: 'lose',
            type: 'wreck',
            latitude: 12.15,
            longitude: -68.3,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('merge re-points features to the survivor; undo restores', () async {
    final repo = SiteRepositoryImpl();
    final snapshot = await repo.mergeSites(
      mergedSite: const domain.DiveSite(id: 'keep', name: 'keep'),
      siteIds: const ['keep', 'lose'],
    );
    expect(snapshot, isNotNull);

    var row = await db.select(db.siteFeatures).getSingle();
    expect(row.siteId, 'keep');
    expect(snapshot!.featureOriginalSiteIds, {'f-1': 'lose'});

    await repo.undoMerge(snapshot);
    row = await db.select(db.siteFeatures).getSingle();
    expect(row.siteId, 'lose');
  });
}
```

Adapt the `SiteRepositoryImpl` construction and `domain.DiveSite` minimal ctor to whatever the existing merge tests in `test/features/dive_sites/` use (there are merge tests already; copy their setup verbatim); the assertions are binding.

- [ ] **Step 2: Run to verify failure**, then **Step 3: Implement**

1. Snapshot capture (with the other pre-transaction captures ~line 462):

```dart
      final affectedFeatures = await (_db.select(
        _db.siteFeatures,
      )..where((t) => t.siteId.isIn(duplicateIds))).get();
      final featureOriginalSiteIds = {
        for (final f in affectedFeatures) f.id: f.siteId,
      };
```

2. Transaction, after `_relinkMedia(...)`: `await _relinkSiteFeatures(duplicateIds, survivorId, now);`
3. Helper, after `_relinkDives`:

```dart
  Future<void> _relinkSiteFeatures(
    List<String> duplicateIds,
    String survivorId,
    int now,
  ) async {
    if (duplicateIds.isEmpty) return;
    final affected = await (_db.select(
      _db.siteFeatures,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();
    if (affected.isEmpty) return;
    await (_db.update(
      _db.siteFeatures,
    )..where((t) => t.siteId.isIn(duplicateIds))).write(
      SiteFeaturesCompanion(siteId: Value(survivorId), updatedAt: Value(now)),
    );
    for (final f in affected) {
      await _syncRepository.markRecordPending(
        entityType: 'siteFeatures',
        recordId: f.id,
        localUpdatedAt: now,
      );
    }
  }
```

4. `MergeSnapshot`: add `final Map<String, String> featureOriginalSiteIds;` with ctor param `this.featureOriginalSiteIds = const {},`; pass the captured map where the snapshot is constructed.
5. `undoMerge`, after the dive restore loop, mirror the dives pattern:

```dart
        // Restore feature links
        for (final entry in snapshot.featureOriginalSiteIds.entries) {
          await (_db.update(
            _db.siteFeatures,
          )..where((t) => t.id.equals(entry.key))).write(
            SiteFeaturesCompanion(
              siteId: Value(entry.value),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'siteFeatures',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }
```

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/dive_sites/data/ > /tmp/sf_t6.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0 (existing merge/undo tests keep passing; the snapshot ctor default keeps old constructions compiling).

```bash
dart format .
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart test/features/dive_sites/data/repositories/site_merge_features_test.dart
git commit -m "feat(sitefeatures): merge relink and undo for site features"
```

---

### Task 7: l10n keys + edit sheet

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Create: `lib/features/site_scape/presentation/site_feature_sheet.dart`
- Test: `test/features/site_scape/presentation/site_feature_sheet_test.dart` (new)

**Interfaces:**
- Consumes: `domain.SiteFeature`/`SiteFeatureType` (Task 3), settings depth unit.
- Produces:

```dart
sealed class SiteFeatureSheetResult {}
class SiteFeatureSheetSave extends SiteFeatureSheetResult {
  final String typeName; final String name; final double? bearingDeg;
  final double? depthMeters; final String notes;
}
class SiteFeatureSheetDelete extends SiteFeatureSheetResult {}

Future<SiteFeatureSheetResult?> showSiteFeatureSheet(
  BuildContext context, {
  domain.SiteFeature? existing,     // null = add flow
  double? initialDepthMeters,       // pre-sampled depth for the add flow
});

String siteFeatureTypeLabel(AppLocalizations l10n, String typeName); // hazard label for unknown names
```

- [ ] **Step 1: Add the l10n keys**

Insert next to `"siteScape_mode2d"` (present in all 11 files) with `"@key": {}` metadata; `siteFeature_deleteConfirm` carries a `{name}` placeholder with full metadata (`"placeholders": {"name": {"type": "String"}}`). Use a python insertion script as in prior slices. Values:

| key | en | de | es | fr | it | nl | pt | hu | ar | he | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|
| siteFeature_type_wreck | Wreck | Wrack | Pecio | Épave | Relitto | Wrak | Naufrágio | Roncs | حطام | ספינה טרופה | 沉船 |
| siteFeature_type_mooring | Mooring | Anlegeboje | Boya de amarre | Bouée d'amarrage | Boa di ormeggio | Meerboei | Boia de amarração | Kikötőbója | مربط | מצוף עגינה | 系泊浮标 |
| siteFeature_type_entry | Entry point | Einstieg | Punto de entrada | Point d'entrée | Punto d'ingresso | Instappunt | Ponto de entrada | Beszállási pont | نقطة الدخول | נקודת כניסה | 入水点 |
| siteFeature_type_exit | Exit point | Ausstieg | Punto de salida | Point de sortie | Punto d'uscita | Uitstappunt | Ponto de saída | Kiszállási pont | نقطة الخروج | נקודת יציאה | 出水点 |
| siteFeature_type_swimThrough | Swim-through | Durchschwimmstelle | Pasadizo | Passage | Passaggio | Doorzwemplek | Passagem | Átúszó | ممر | מעבר | 穿越通道 |
| siteFeature_type_hazard | Hazard | Gefahr | Peligro | Danger | Pericolo | Gevaar | Perigo | Veszély | خطر | סכנה | 危险 |
| siteFeature_type_current | Current | Strömung | Corriente | Courant | Corrente | Stroming | Correnteza | Áramlás | تيار | זרם | 水流 |
| siteFeature_sectionTitle | Features | Merkmale | Características | Éléments | Elementi | Kenmerken | Características | Jellemzők | معالم | מאפיינים | 特征 |
| siteFeature_addAction | Add feature | Merkmal hinzufügen | Añadir característica | Ajouter un élément | Aggiungi elemento | Kenmerk toevoegen | Adicionar característica | Jellemző hozzáadása | إضافة معلم | הוספת מאפיין | 添加特征 |
| siteFeature_placeHint | Tap the map to place the feature | Auf die Karte tippen, um das Merkmal zu platzieren | Toca el mapa para colocar la característica | Touchez la carte pour placer l'élément | Tocca la mappa per posizionare l'elemento | Tik op de kaart om het kenmerk te plaatsen | Toque no mapa para posicionar a característica | Koppintson a térképre a jellemző elhelyezéséhez | انقر على الخريطة لوضع المعلم | הקישו על המפה למיקום המאפיין | 点按地图放置特征 |
| siteFeature_addTitle | Add feature | Merkmal hinzufügen | Añadir característica | Ajouter un élément | Aggiungi elemento | Kenmerk toevoegen | Adicionar característica | Jellemző hozzáadása | إضافة معلم | הוספת מאפיין | 添加特征 |
| siteFeature_editTitle | Edit feature | Merkmal bearbeiten | Editar característica | Modifier l'élément | Modifica elemento | Kenmerk bewerken | Editar característica | Jellemző szerkesztése | تحرير المعلم | עריכת מאפיין | 编辑特征 |
| siteFeature_field_name | Name | Name | Nombre | Nom | Nome | Naam | Nome | Név | الاسم | שם | 名称 |
| siteFeature_field_bearing | Bearing (°) | Peilung (°) | Rumbo (°) | Cap (°) | Rilevamento (°) | Peiling (°) | Rumo (°) | Irány (°) | الاتجاه (°) | כיוון (°) | 方位 (°) |
| siteFeature_field_depth | Depth | Tiefe | Profundidad | Profondeur | Profondità | Diepte | Profundidade | Mélység | العمق | עומק | 深度 |
| siteFeature_field_notes | Notes | Notizen | Notas | Remarques | Note | Notities | Notas | Jegyzetek | ملاحظات | הערות | 备注 |
| siteFeature_deleteAction | Delete | Löschen | Eliminar | Supprimer | Elimina | Verwijderen | Excluir | Törlés | حذف | מחיקה | 删除 |
| siteFeature_deleteConfirm | Delete {name}? | {name} löschen? | ¿Eliminar {name}? | Supprimer {name} ? | Eliminare {name}? | {name} verwijderen? | Excluir {name}? | Törli: {name}? | حذف {name}؟ | למחוק את {name}? | 删除 {name}？ |

Then `flutter gen-l10n` from the project root.

- [ ] **Step 2: Write the failing test**

```dart
testWidgets('save flow returns the draft with metric depth', (tester) async {
  // Host: MaterialApp(locale: en, delegates, home: Scaffold with a button
  // that awaits showSiteFeatureSheet(context, initialDepthMeters: 18.0)
  // and stores the result; settingsProvider overridden with
  // MockSettingsNotifier(const AppSettings()) via a ProviderScope).
  // Open the sheet, verify the depth field shows '18' (meters diver),
  // pick 'Mooring' in the type dropdown, enter name 'North ball',
  // bearing '90', tap the save button, expect
  // SiteFeatureSheetSave(typeName: 'mooring', name: 'North ball',
  // bearingDeg: 90, depthMeters: 18).
});

testWidgets('a feet diver sees and edits depth in feet', (tester) async {
  // Same host but AppSettings(depthUnit: DepthUnit.feet) and
  // initialDepthMeters: 3.048; the field shows '10'; entering '20'
  // returns depthMeters closeTo(6.096, 1e-9).
});

testWidgets('edit flow offers delete and returns the sentinel', (tester) async {
  // existing: a SiteFeature(typeName: 'wreck', name: 'Hilma Hooker');
  // tap the delete action; expect SiteFeatureSheetDelete.
});
```

Write these three tests in full (the comments above define the exact behavior; the host scaffold mirrors `terrain_appearance_sheet_test.dart`'s pump pattern with `MockSettingsNotifier`).

- [ ] **Step 3: Run to verify failure, then implement the sheet**

`SiteFeatureSheet` is a `ConsumerStatefulWidget` inside a `showModalBottomSheet<SiteFeatureSheetResult>(isScrollControlled: true)`. Content: title (`addTitle`/`editTitle`); `DropdownButtonFormField<String>` over `SiteFeatureType.values.map((t) => t.name)` labeled with `siteFeatureTypeLabel` (key `ValueKey('siteFeatureTypeField')`; when `existing` has an unknown `typeName`, the dropdown value is null and the raw name shows as `hintText`, and saving without choosing keeps the raw name); `TextFormField`s for name (`siteFeatureNameField`), bearing (`siteFeatureBearingField`, numeric, valid empty or 0-359), depth (`siteFeatureDepthField`, numeric, shown/parsed in the diver's unit: `unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0`, display `meters / unitInMeters`, store `value * unitInMeters`), notes (`siteFeatureNotesField`); a `FilledButton` save (`siteFeatureSaveButton`) popping `SiteFeatureSheetSave`; when `existing != null`, a `TextButton` (`siteFeatureDeleteButton`, `siteFeature_deleteAction` label) that shows an `AlertDialog` with `siteFeature_deleteConfirm(name)` (name falls back to the type label) and on confirm pops the sheet with `SiteFeatureSheetDelete`.

```dart
String siteFeatureTypeLabel(AppLocalizations l10n, String typeName) {
  return switch (SiteFeatureType.values.asNameMap()[typeName]) {
    SiteFeatureType.wreck => l10n.siteFeature_type_wreck,
    SiteFeatureType.mooring => l10n.siteFeature_type_mooring,
    SiteFeatureType.entry => l10n.siteFeature_type_entry,
    SiteFeatureType.exit => l10n.siteFeature_type_exit,
    SiteFeatureType.swimThrough => l10n.siteFeature_type_swimThrough,
    SiteFeatureType.hazard => l10n.siteFeature_type_hazard,
    SiteFeatureType.current => l10n.siteFeature_type_current,
    null => typeName,
  };
}
```

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/site_scape/ > /tmp/sf_t7.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

```bash
dart format .
git add lib/features/site_scape/presentation/site_feature_sheet.dart lib/l10n/arb/ test/features/site_scape/presentation/site_feature_sheet_test.dart
git commit -m "feat(sitefeatures): feature edit sheet and l10n"
```

---

### Task 8: 2D marker layer + host wiring

**Files:**
- Create: `lib/features/site_scape/presentation/site_feature_marker_layer.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart` (after `BathymetryDepthOverlayLayer` in the map children), `lib/features/dive_sites/presentation/pages/site_map_page.dart` (same position in `_buildMap`), `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (preview card map children and `_FullscreenSiteScapePage` map children, both after their overlay layer)
- Test: `test/features/site_scape/presentation/site_feature_marker_layer_test.dart` (new)

**Interfaces:**
- Consumes: `siteFeaturesProvider` (Task 4), `showSiteFeatureSheet` + `siteFeatureTypeLabel` (Task 7).
- Produces: `class SiteFeatureMarkerLayer extends ConsumerWidget { final String? siteId; const SiteFeatureMarkerLayer({super.key, required this.siteId}); }`. Tapping a marker opens the sheet and persists the result through `siteFeatureRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('renders one rotated marker per feature and edits on tap', (
  tester,
) async {
  // Pump a FlutterMap (initialCenter at the feature) whose children are
  // [TileLayer-free] just the SiteFeatureMarkerLayer(siteId: 'site-1'),
  // inside ProviderScope overriding siteFeaturesProvider('site-1') with
  // [SiteFeature(id: 'f-1', typeName: 'current', bearingDeg: 90, ...)]
  // and settingsProvider with MockSettingsNotifier. Bounded pumps.
  // Assert: one Transform.rotate with angle closeTo(pi/2, 1e-9) exists
  // (key ValueKey('siteFeatureMarker-f-1')); tapping it opens the sheet
  // (find.byKey(ValueKey('siteFeatureSaveButton')) appears).
});

testWidgets('null siteId renders nothing', (tester) async {
  // Same pump with siteId: null; expect no siteFeatureMarker keys.
});
```

Write both in full, modeling the map host on `site_map_content_test.dart`'s pump (MaterialApp with en locale + delegates, Scaffold body: FlutterMap with `MapOptions(initialCenter: LatLng(12.15, -68.3), initialZoom: 14)`).

- [ ] **Step 2: Run to verify failure, then implement**

```dart
class SiteFeatureMarkerLayer extends ConsumerWidget {
  final String? siteId;

  const SiteFeatureMarkerLayer({super.key, required this.siteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = siteId;
    if (id == null) return const SizedBox.shrink();
    final features = ref.watch(siteFeaturesProvider(id)).valueOrNull;
    if (features == null || features.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        for (final f in features)
          Marker(
            point: LatLng(f.latitude, f.longitude),
            width: 36,
            height: 36,
            child: GestureDetector(
              key: ValueKey('siteFeatureMarker-${f.id}'),
              onTap: () => _edit(context, ref, f),
              child: Transform.rotate(
                angle: (f.bearingDeg ?? 0) * math.pi / 180.0,
                child: _FeatureGlyph(typeName: f.typeName),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    domain.SiteFeature feature,
  ) async {
    final result = await showSiteFeatureSheet(context, existing: feature);
    final repo = ref.read(siteFeatureRepositoryProvider);
    switch (result) {
      case SiteFeatureSheetSave(
        :final typeName,
        :final name,
        :final bearingDeg,
        :final depthMeters,
        :final notes,
      ):
        await repo.updateFeature(
          feature.copyWith(
            typeName: typeName,
            name: name,
            bearingDeg: bearingDeg,
            clearBearing: bearingDeg == null,
            depthMeters: depthMeters,
            clearDepth: depthMeters == null,
            notes: notes,
          ),
        );
      case SiteFeatureSheetDelete():
        await repo.deleteFeature(feature.id);
      case null:
        break;
    }
  }
}

/// One circular glyph per feature type; unknown types render the hazard
/// styling with a generic icon.
class _FeatureGlyph extends StatelessWidget {
  final String typeName;
  const _FeatureGlyph({required this.typeName});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (SiteFeatureType.values.asNameMap()[typeName]) {
      SiteFeatureType.wreck => (Icons.directions_boat, const Color(0xFF8B5CF6)),
      SiteFeatureType.mooring => (Icons.anchor, const Color(0xFF0EA5E9)),
      SiteFeatureType.entry => (Icons.login, const Color(0xFF22C55E)),
      SiteFeatureType.exit => (Icons.logout, const Color(0xFFF97316)),
      SiteFeatureType.swimThrough => (Icons.u_turn_right, const Color(0xFF14B8A6)),
      SiteFeatureType.hazard => (Icons.warning_amber, const Color(0xFFEF4444)),
      SiteFeatureType.current => (Icons.navigation, const Color(0xFF3B82F6)),
      null => (Icons.place, const Color(0xFFEF4444)),
    };
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
```

Host wiring: insert `SiteFeatureMarkerLayer(siteId: <selected site id expression>)` immediately after `BathymetryDepthOverlayLayer(...)` in: `site_map_content.dart` (`selectedSite?.id`... the layer sits inside `_buildMap`, which has `widget.selectedId`; use that), `site_map_page.dart` `_buildMap` (`selectionState.selectedId`), `site_detail_page.dart` preview map (`site.id`) and `_FullscreenSiteScapePage` map (`site.id`).

- [ ] **Step 3: Run, format, commit**

Run: `pwd && flutter test test/features/site_scape/ test/features/dive_sites/presentation/ > /tmp/sf_t8.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/features/site_scape/presentation/site_feature_marker_layer.dart lib/features/dive_sites/ test/features/site_scape/
git commit -m "feat(sitefeatures): 2D feature markers on all site map hosts"
```

---

### Task 9: Site detail Features section + placement mode

**Files:**
- Create: `lib/features/site_scape/presentation/site_features_section.dart`
- Create: `lib/features/bathymetry/domain/grid_sampling.dart` (pure depth sample helper)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (body column after the map section; `_FullscreenSiteScapePage` gains placement)
- Test: `test/features/bathymetry/domain/grid_sampling_test.dart`, `test/features/site_scape/presentation/site_features_section_test.dart`, extend `test/features/dive_sites/presentation/pages/site_detail_page_test.dart` (new placement test)

**Interfaces:**
- Consumes: providers/sheet from earlier tasks; `bathymetryGridProvider` + `BathymetryRepository.quantize`.
- Produces:
  - `double? sampleGridDepth(BathymetryGrid grid, double lat, double lon)`: nearest-cell depth in meters, null outside the grid or on a nodata/land cell.
  - `class SiteFeaturesSection extends ConsumerWidget { final String siteId; final VoidCallback onAddFeature; }`
  - `_FullscreenSiteScapePage({..., bool startPlacing = false})`; `_showFullscreenMap(..., {bool initialScape3d = false, bool startPlacing = false})`.

- [ ] **Step 1: Grid sampler, test-first**

```dart
test('sampleGridDepth picks the nearest cell and rejects outside/land', () {
  final grid = BathymetryGrid(
    originLat: 0, originLon: 0,
    cellSizeLatDeg: 0.001, cellSizeLonDeg: 0.001,
    rows: 2, cols: 2,
    depthsMeters: const [10, 20, null, -2],
    sourceId: 't', resolutionMeters: 100,
    fetchedAt: DateTime.utc(2026, 8, 16),
  );
  expect(sampleGridDepth(grid, 0.0001, 0.0001), 10);   // nearest (0,0)
  expect(sampleGridDepth(grid, 0.0009, 0.0001), isNull); // nodata cell (1,0)
  expect(sampleGridDepth(grid, 0.0009, 0.0009), isNull); // land (depth <= 0)
  expect(sampleGridDepth(grid, 0.5, 0.5), isNull);       // outside
});
```

Implementation:

```dart
double? sampleGridDepth(BathymetryGrid grid, double lat, double lon) {
  final r = ((lat - grid.originLat) / grid.cellSizeLatDeg).round();
  final c = ((lon - grid.originLon) / grid.cellSizeLonDeg).round();
  if (r < 0 || r >= grid.rows || c < 0 || c >= grid.cols) return null;
  final d = grid.depthAt(r, c);
  if (d == null || d <= 0) return null;
  return d;
}
```

- [ ] **Step 2: Features section, test-first**

Test (mirror the pane test harness: ProviderScope with `siteFeaturesProvider('site-1')` overridden to two features, `settingsProvider` mocked, en locale): the section lists both rows with type labels (`find.text('Mooring')`), shows depth in display units, the add button (`ValueKey('siteFeatureAddButton')`) fires `onAddFeature`, a row tap opens the sheet, and the sheet's delete flow calls the repository (override `siteFeatureRepositoryProvider` with a recording fake). Implementation: a `Card` with the `siteFeature_sectionTitle` header, `ListTile` per feature (leading `_FeatureGlyph`-style icon via an exported small widget or a plain `Icon`; title `name.isNotEmpty ? name : siteFeatureTypeLabel(...)`; subtitle depth text when present), plus a `TextButton.icon(Icons.add_location_alt)` add action. Row `onTap` reuses the exact `_edit` logic from Task 8 (extract that logic into a shared top-level helper `Future<void> editSiteFeature(BuildContext, WidgetRef, domain.SiteFeature)` in `site_feature_marker_layer.dart` and call it from both call sites).

- [ ] **Step 3: Wire the section + placement, test-first**

New site detail test (same harness as the existing embedded seascape tests, with `siteSeascapeProvider` parked and `siteFeaturesProvider` overridden empty): tapping the section's add button opens the fullscreen page with the placement banner (`find.byKey(ValueKey('siteFeaturePlaceBanner'))`); a tap on the map then opens the sheet; saving inserts via a recording fake repository.

Implementation:
1. Site detail body, after the map section block: `if (site.hasCoordinates) ...[ SiteFeaturesSection(siteId: site.id, onAddFeature: () => _showFullscreenMap(context, ref, site, startPlacing: true)), const SizedBox(height: 16), ]`.
2. `_showFullscreenMap` gains `bool startPlacing = false`, forwarded to `_FullscreenSiteScapePage`.
3. `_FullscreenSiteScapePage` state gains `late bool _placing = widget.startPlacing;`. Its `FlutterMap`'s `MapOptions` gains `onTap: (_, latLng) => _onMapTap(context, latLng)`. When `_placing` is false the handler returns immediately. The banner: `if (_placing)` a `Positioned(top: 8, left: 8, right: 8)` `Material` chip with `siteFeature_placeHint` and a close button (inside the `mapBuilder` Stack; wrap the existing `TrackpadZoomMap` in a `Stack` there).
4. `_onMapTap`:

```dart
  Future<void> _onMapTap(BuildContext context, LatLng latLng) async {
    if (!_placing) return;
    setState(() => _placing = false);
    final site = widget.site;
    final grid = ref
        .read(
          bathymetryGridProvider(
            BathymetryRepository.quantize(site.location!),
          ),
        )
        .valueOrNull;
    final sampled = grid == null
        ? null
        : sampleGridDepth(grid, latLng.latitude, latLng.longitude);
    if (!context.mounted) return;
    final result = await showSiteFeatureSheet(
      context,
      initialDepthMeters: sampled,
    );
    if (result is! SiteFeatureSheetSave) return;
    await ref
        .read(siteFeatureRepositoryProvider)
        .addFeature(
          siteId: site.id,
          typeName: result.typeName,
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          bearingDeg: result.bearingDeg,
          depthMeters: result.depthMeters,
          name: result.name,
          notes: result.notes,
        );
  }
```

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/site_scape/ test/features/bathymetry/ test/features/dive_sites/presentation/pages/site_detail_page_test.dart > /tmp/sf_t9.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

```bash
dart format .
git add lib/features/site_scape/ lib/features/bathymetry/domain/grid_sampling.dart lib/features/dive_sites/presentation/pages/site_detail_page.dart test/
git commit -m "feat(sitefeatures): features section and tap-to-place"
```

---

### Task 10: 3D rendering (read-only)

**Files:**
- Modify: `lib/features/dive_3d/domain/geometry/marker_layout.dart` (enum line 5), `lib/features/dive_3d/presentation/scene_overlay.dart` (+`features`), `lib/features/dive_3d/presentation/renderer/preview_painter.dart` (`_paintMarkers` color switch + kind gate), `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart` (tap hit-test kind gate), `lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart` (input + markers), `lib/features/dive_3d/application/site_seascape_providers.dart` (feature watch + input threading), `lib/features/site_scape/presentation/site_terrain_pane.dart` (chip + tap sheet)
- Test: extend `test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart` and `test/features/site_scape/presentation/site_terrain_pane_test.dart`

**Interfaces:**
- Consumes: `siteFeaturesProvider`, `enuOffsetMeters`, `sampleGridDepth` (Task 9).
- Produces:
  - `SceneMarkerKind.siteFeature`; `SceneOverlay.features`.
  - `class SiteFeatureMarkerInput { final String id; final String typeName; final String label; final ({double east, double north}) offset; final double? depthMeters; }` (const ctor; plain data, crosses `compute()`).
  - `SiteSeascapeInput.features` (`List<SiteFeatureMarkerInput>`, default `const []`).

- [ ] **Step 1: Geometry test-first**

Extend the geometry service test: an input with one feature (offset inside the grid box, `depthMeters: 15`) yields a `SceneMarker` with `kind: SceneMarkerKind.siteFeature`, `refId: 'f-1'`, `y == proj.yOf(15)`; a second feature without depth gets `y == proj.yOf(sampleGridDepth(...))` when the grid has a wet cell there, else the float constant. Write the expected values from the test's own grid fixture (the existing tests construct `SpatialProjection` to compute expectations; mirror that).

Implementation in `site_seascape_geometry_service.dart`: `SiteSeascapeInput` gains `this.features = const []`; in `buildWithLabels`, after the nearby-site markers:

```dart
      for (final f in input.features)
        SceneMarker(
          kind: SceneMarkerKind.siteFeature,
          refId: f.id,
          label: f.label,
          x: proj.xOf(f.offset.east),
          y: f.depthMeters != null
              ? proj.yOf(f.depthMeters!)
              : _featureY(input.grid, input.center, f.offset, proj),
          z: proj.zOf(f.offset.north),
          timestampSeconds: 0,
        ),
```

with a private `_featureY` that converts the ENU offset back to lat/lon (inverse of `enuOffsetMeters`: `lat = center.latitude + north / BathymetryTerrainBuilder.metersPerDegLat`, `lon = center.longitude + east / metersPerDegreeLongitude(center.latitude)`), calls `sampleGridDepth`, and falls back to `_markerFloat` when null.

- [ ] **Step 2: Renderer + overlay + providers**

1. `marker_layout.dart`: `enum SceneMarkerKind { gasSwitch, bookmark, photo, site, nearbySite, siteFeature }`.
2. `scene_overlay.dart`: add `features` to the enum.
3. `preview_painter.dart` `_paintMarkers`: the exhaustive color switch gains `SceneMarkerKind.siteFeature => const Color(0xFF14B8A6),` and the loop gains a gate before painting: `if (marker.kind == SceneMarkerKind.siteFeature && !_visible(SceneOverlay.features)) continue;`.
4. `dive_3d_interactive_viewport.dart` `_handleTapUp` marker loop: the same kind gate (skip siteFeature markers when `SceneOverlay.features` is not in `widget.visibleOverlays`).
5. `site_seascape_providers.dart`: watch `siteFeaturesProvider(siteId)` (`valueOrNull ?? const []`), map each feature to `SiteFeatureMarkerInput(id, typeName, label: f.name, offset: enuOffsetMeters(center, GeoPoint(f.latitude, f.longitude)), depthMeters: f.depthMeters)`, and pass `features:` into `SiteSeascapeInput`. `SiteFeatureMarkerInput` lives in `site_seascape_geometry_service.dart` next to `NearbySiteInput`.
6. `site_terrain_pane.dart`: `_visible` initializer gains `SceneOverlay.features`; the chip row gains `chip(SceneOverlay.features, context.l10n.siteFeature_sectionTitle)`; the viewport gains `onMarkerTap: (marker) { if (marker.kind == SceneMarkerKind.siteFeature) _showFeatureInfo(marker); }` where `_showFeatureInfo` looks the feature up in `ref.read(siteFeaturesProvider(widget.siteId)).valueOrNull` by `refId` and shows a read-only `showModalBottomSheet` (type label, name, depth in display units, bearing, notes).

- [ ] **Step 3: Pane test**

Extend `site_terrain_pane_test.dart`: with `siteFeaturesProvider('site-1')` overridden to one feature, the ready state's viewport `visibleOverlays` contains `SceneOverlay.features`; tapping the Features chip removes it; (the marker itself is scene data, covered by the geometry test).

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/dive_3d/ test/features/site_scape/ > /tmp/sf_t10.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

```bash
dart format .
git add lib/features/dive_3d/ lib/features/site_scape/presentation/site_terrain_pane.dart test/features/dive_3d/ test/features/site_scape/
git commit -m "feat(sitefeatures): read-only feature markers in the 3D seascape"
```

---

### Task 11: Full verification + PR

- [ ] **Step 1: Verify**

```bash
pwd
dart format .
flutter analyze
flutter test          # capture: > /tmp/sf_full.log 2>&1; code=$?  -- and READ the log tail, the exit code alone has masked failures before
flutter gen-l10n
git status --short    # expect clean except intended files; database.g.dart must NOT be staged
```

Expected: no format changes, zero analyze issues, full suite green (check the log's own "All tests passed!" line), no l10n drift.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin worktree-site-features
gh pr create --repo submersion-app/submersion --base main --head worktree-site-features --title "feat(sitefeatures): diver-placed site annotations, synced and rendered in 2D and 3D" --body-file <body file>
```

PR body per repo conventions (no attribution, no session URL): cover the LWW table + v152, the sync enrollment and its completeness-test guardrails, merge relink/undo, the four-host 2D layer with tap-to-place and tap-to-edit, depth pre-sampling, and the read-only 3D markers behind the Features chip.

## Execution notes

- Manual visual pass before merge: `flutter run -d macos`; on a site with bathymetry add a mooring (check depth pre-fill), a current with bearing 90 (check arrow rotation), view both in 2D and 3D, flip the Features chip, edit from the map and the section, merge two sites and undo.
- `MockSettingsNotifier` and the three page-local settings mocks break only on NEW SettingsNotifier setters; this slice adds none.
- The `flutter_map` `MapOptions.onTap` on the fullscreen page coexists with marker `GestureDetector`s: markers win their own hit test, so placement taps on empty water reach `onTap`.
- If `sync_extra_entities_round_trip_test.dart` or `sync_data_serializer_batch_coverage_test.dart` fail after Task 5, their failure messages name the missing enrollment; fix what they name (they are designed as the checklist).
