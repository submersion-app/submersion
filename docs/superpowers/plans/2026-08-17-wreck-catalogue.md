# Wreck Catalogue (Slice 3a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A synced, diver-editable wreck catalogue: its own entity and pages alongside dive sites, with an optional site link and a link from `site_features.wreckId`.

**Architecture:** `Wrecks` mirrors `DiveSites` structurally (nullable `diverId`, `isShared`, own `hlc`) so ownership, sharing, and LWW sync behave identically; `site_features` gains `wreckId` and `source`. The UI reuses the sites feature's master-detail scaffold, list/table modes, and `SiteScapeView` rather than building parallel widgets. Wrecks join the existing customizable nav destination list as an unpinned entry.

**Tech Stack:** Drift, Riverpod (project hub `core/providers/provider.dart`), go_router, the existing sync serializer/service/repository trio.

**Spec:** `docs/superpowers/specs/2026-08-17-wreck-catalogue-design.md`

## Global Constraints

- Never use an em-dash (U+2014) anywhere: code, comments, docs, commits, PR body.
- No Co-Authored-By in commits; no attribution line or session URL in the PR body.
- New l10n keys go into ALL 11 arb files (en, ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` from the project root; generated `app_localizations*.dart` under `lib/l10n/arb/` ARE committed. `database.g.dart` is NEVER committed.
- `dart format .` before every commit; `flutter analyze` clean (infos are CI-fatal).
- Riverpod 3: `StateNotifier`/`valueOrNull` come from `package:submersion/core/providers/provider.dart`. In tests the `Override` type comes from `test/helpers/mock_providers.dart` (typedef), not any package import.
- All depths and lengths are STORED in meters and DISPLAYED in the diver's unit.
- Enum-valued columns store the raw enum NAME; the domain entity keeps the raw string plus a nullable typed getter, so a value from a newer build survives sync (the `site_features.type` precedent).
- Map-hosting widget tests use bounded pumps, never `pumpAndSettle`; pin `locale: Locale('en')` wherever finders use English strings.
- Capture test exit codes AND confirm the log's own `All tests passed!` line (pipe the log through `tr '\r' '\n'` first): a run killed by a sibling session exits 0 with no summary line.
- All commands run from `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/wreck-catalogue`; print `pwd` in the same compound command as builds and tests.

---

### Task 1: Worktree init

**Files:** none (the worktree and branch `worktree-wreck-catalogue` already exist, cut from origin/main at schema v152).

- [ ] **Step 1: Initialize**

```bash
pwd   # must print .../worktrees/wreck-catalogue
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Sanity**

Run: `pwd && flutter test test/shared/widgets/nav/ > /tmp/wc_t1.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

---

### Task 2: Schema v153

**Files:**
- Modify: `lib/core/database/database.dart` (new table after `SiteFeatures` ~line 2867; `@DriftDatabase` table list; `currentSchemaVersion` line 3064; `migrationVersions` tail; `onUpgrade` tail; `beforeOpen` backstop)
- Modify: `lib/core/database/performance_indexes.dart` (next to `idx_site_features_site`)
- Test: `test/core/database/migration_v153_wrecks_test.dart` (new)

**Interfaces:**
- Produces: Drift table `Wrecks` (row class `Wreck`, companion `WrecksCompanion`, accessor `_db.wrecks`) with columns `id, diverId, siteId, name, latitude, longitude, vesselType, depthToDeckMeters, depthToSeabedMeters, lengthMeters, yearBuilt, yearSunk, causeOfSinking, condition, penetrationPossible, protectedStatus, notes, isShared, createdAt, updatedAt, hlc`; plus `site_features.wreckId` (nullable) and `site_features.source` (TEXT default `'diver'`). Every later task depends on these exact names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  test('v153 adds wrecks plus the site_features link columns', () async {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(153));
    expect(AppDatabase.migrationVersions, contains(153));

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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
            createdAt: 1,
            updatedAt: 1,
            siteId: const Value('site-1'),
            latitude: const Value(12.15),
            longitude: const Value(-68.3),
            vesselType: const Value('ship'),
            depthToDeckMeters: const Value(18),
            depthToSeabedMeters: const Value(30),
          ),
        );

    final row = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals('w-1'))).getSingle();
    expect(row.siteId, 'site-1');
    expect(row.vesselType, 'ship');
    expect(row.isShared, isFalse);
    expect(row.hlc, isNull);
    expect(row.condition, isNull);

    // A wreck outlives the site: deleting the site NULLs the link.
    await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();
    final after = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals('w-1'))).getSingle();
    expect(after.siteId, isNull);
  });

  test('site_features carries the wreck link and a source default', () async {
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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
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
            wreckId: const Value('w-1'),
          ),
        );

    var feature = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(feature.wreckId, 'w-1');
    // Untouched rows are diver-placed; 3b sets other values.
    expect(feature.source, 'diver');

    // Deleting the wreck leaves the marker, unlinked.
    await (db.delete(db.wrecks)..where((t) => t.id.equals('w-1'))).go();
    feature = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(feature.wreckId, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_v153_wrecks_test.dart`
Expected: compile FAIL (`wrecks` undefined).

- [ ] **Step 3: Implement the schema**

1. Table, immediately after the `SiteFeatures` class:

```dart
/// Diver-maintained wreck catalogue (seascape program slice 3a). A wreck
/// is a top-level entity like a dive site: it carries its own position
/// and outlives any one site, so [siteId] is an optional link that NULLs
/// rather than cascading. External sources (slice 3b) write into this
/// same table rather than owning storage of their own.
class Wrecks extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();

  /// The site this wreck is dived from, when the diver has logged one.
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();
  /// Required, as on DiveSites: a nameless wreck is not a record anyone
  /// can use. (This is what lets WrecksCompanion.insert take name as a
  /// plain String rather than a Value.)
  TextColumn get name => text()();

  /// A wreck can be known before its position is.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// Enum NAMEs, plain text so a value from a newer build survives sync:
  /// vesselType ship|aircraft|other; causeOfSinking foundered|collision|
  /// grounding|scuttled|war|fire|unknown; condition intact|broken|debris;
  /// protectedStatus none|permitRequired|protected|warGrave.
  TextColumn get vesselType => text().nullable()();
  TextColumn get causeOfSinking => text().nullable()();
  TextColumn get condition => text().nullable()();
  TextColumn get protectedStatus => text().nullable()();

  /// Stored meters; displayed in the diver's unit.
  RealColumn get depthToDeckMeters => real().nullable()();
  RealColumn get depthToSeabedMeters => real().nullable()();
  RealColumn get lengthMeters => real().nullable()();
  IntColumn get yearBuilt => integer().nullable()();
  IntColumn get yearSunk => integer().nullable()();

  /// Null means unknown, which is not the same as no.
  BoolColumn get penetrationPossible => boolean().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

2. Two columns on `SiteFeatures`, after its `notes` column:

```dart
  /// The catalogue wreck this marker points at, when the diver linked
  /// one (slice 3a). NULLs rather than cascading: deleting the wreck
  /// record must not silently remove the marker from the map.
  TextColumn get wreckId =>
      text().nullable().references(Wrecks, #id, onDelete: KeyAction.setNull)();

  /// Provenance: 'diver' for hand-placed features; slice 3b writes its
  /// own source ids for imported ones.
  TextColumn get source => text().withDefault(const Constant('diver'))();
```

3. Add `Wrecks` to the `@DriftDatabase(tables: [...])` list next to `SiteFeatures`.
4. `currentSchemaVersion` 152 -> 153; append to `migrationVersions`:

```dart
    // v153: wrecks catalogue plus site_features.wreck_id/source
    // (seascape program slice 3a).
    153,
```

5. Idempotent helper next to `_assertSeascapeAppearanceColumn`:

```dart
  /// v153: the wreck link and provenance columns on site_features.
  Future<void> _assertSiteFeatureWreckColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('site_features')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('wreck_id')) {
      await customStatement(
        'ALTER TABLE site_features ADD COLUMN wreck_id TEXT REFERENCES '
        'wrecks(id) ON DELETE SET NULL',
      );
    }
    if (!names.contains('source')) {
      await customStatement(
        "ALTER TABLE site_features ADD COLUMN source TEXT NOT NULL "
        "DEFAULT 'diver'",
      );
    }
  }
```

6. `onUpgrade`, after the v152 block (the table must exist before the FK column references it):

```dart
        // v153: wreck catalogue (slice 3a).
        if (from < 153) {
          await createMigrator().createTable(wrecks);
          await _assertSiteFeatureWreckColumns();
        }
        if (from < 153) await reportProgress();
```

7. `beforeOpen` backstop, next to the v152 backstop:

```dart
        // v153 backstop: wrecks table and the site_features link columns
        // (parallel-branch version-collision self-heal; both are
        // idempotent).
        await createMigrator().createTable(wrecks);
        await _assertSiteFeatureWreckColumns();
```

8. `performance_indexes.dart`, next to `idx_site_features_site`:

```dart
  (
    name: 'idx_wrecks_site',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_wrecks_site '
        'ON wrecks(site_id)',
  ),
```

9. Regenerate: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run to verify pass**

Run: `pwd && flutter test test/core/database/ > /tmp/wc_t2.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t2.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!` (the whole database suite guards the ladder claims).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v153_wrecks_test.dart
git commit -m "feat(wrecks): wrecks table and site_features link, schema v153"
```

---

### Task 3: Domain entity

**Files:**
- Create: `lib/features/wrecks/domain/entities/wreck.dart`
- Test: `test/features/wrecks/domain/entities/wreck_test.dart` (new)

**Interfaces:**
- Produces:

```dart
enum WreckVesselType { ship, aircraft, other }
enum WreckCause { foundered, collision, grounding, scuttled, war, fire, unknown }
enum WreckCondition { intact, broken, debris }
enum WreckProtection { none, permitRequired, protected, warGrave }

class Wreck {
  final String id;
  final String? diverId;
  final String? siteId;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? vesselTypeName;      // raw stored string
  final String? causeName;
  final String? conditionName;
  final String? protectionName;
  final double? depthToDeckMeters;
  final double? depthToSeabedMeters;
  final double? lengthMeters;
  final int? yearBuilt;
  final int? yearSunk;
  final bool? penetrationPossible;
  final String notes;
  final bool isShared;
  WreckVesselType? get vesselType;   // null when the name is unknown
  WreckCause? get cause;
  WreckCondition? get condition;
  WreckProtection? get protection;
  bool get hasCoordinates;
  Wreck copyWith({...});             // clearSite/clearCoordinates/clearDepths flags
}
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

void main() {
  const base = Wreck(id: 'w-1', name: 'Hilma Hooker');

  test('known enum names decode; unknown ones survive as null', () {
    final typed = base.copyWith(
      vesselTypeName: 'ship',
      conditionName: 'broken',
      protectionName: 'warGrave',
      causeName: 'scuttled',
    );
    expect(typed.vesselType, WreckVesselType.ship);
    expect(typed.condition, WreckCondition.broken);
    expect(typed.protection, WreckProtection.warGrave);
    expect(typed.cause, WreckCause.scuttled);

    final future = base.copyWith(vesselTypeName: 'submersible');
    expect(future.vesselType, isNull);
    expect(future.vesselTypeName, 'submersible');
    // An unrelated edit preserves the unknown name.
    expect(future.copyWith(name: 'x').vesselTypeName, 'submersible');
  });

  test('hasCoordinates needs both halves', () {
    expect(base.hasCoordinates, isFalse);
    expect(base.copyWith(latitude: 12.15).hasCoordinates, isFalse);
    expect(
      base.copyWith(latitude: 12.15, longitude: -68.3).hasCoordinates,
      isTrue,
    );
  });

  test('copyWith clears nullables only via flags', () {
    final w = base.copyWith(
      siteId: 'site-1',
      latitude: 12.15,
      longitude: -68.3,
      depthToDeckMeters: 18,
    );
    expect(w.copyWith().siteId, 'site-1');
    expect(w.copyWith(clearSite: true).siteId, isNull);
    expect(w.copyWith(clearCoordinates: true).latitude, isNull);
    expect(w.copyWith(clearCoordinates: true).longitude, isNull);
    expect(w.copyWith(clearDepths: true).depthToDeckMeters, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure, then implement**

Create the file with the four enums, the class above, `const` constructor with `id` and `name` required and everything else optional (`notes = ''`, `isShared = false`), the four typed getters implemented as `Enum.values.asNameMap()[nameField]`, `hasCoordinates => latitude != null && longitude != null`, and `copyWith` honoring three clear flags: `clearSite` (nulls `siteId`), `clearCoordinates` (nulls BOTH `latitude` and `longitude`, since half a position is not a position), and `clearDepths` (nulls both depth fields; `lengthMeters` is NOT a depth and is not touched). Document each flag on its parameter.

- [ ] **Step 3: Run, format, commit**

Run: `flutter test test/features/wrecks/domain/entities/wreck_test.dart` (PASS), then:

```bash
dart format .
git add lib/features/wrecks/ test/features/wrecks/
git commit -m "feat(wrecks): Wreck domain entity"
```

---

### Task 4: Repository and providers

**Files:**
- Create: `lib/features/wrecks/data/repositories/wreck_repository.dart`
- Create: `lib/features/wrecks/presentation/providers/wreck_providers.dart`
- Test: `test/features/wrecks/data/repositories/wreck_repository_test.dart` (new)

**Interfaces:**
- Consumes: the `wrecks` table (Task 2), `domain.Wreck` (Task 3), `SyncRepository.markRecordPending/logDeletion`, `SyncEventBus.notifyLocalChange`.
- Produces:

```dart
class WreckRepository {
  Stream<void> watchWreckChanges();
  Future<domain.Wreck> createWreck(domain.Wreck wreck);   // assigns id when empty
  Future<List<domain.Wreck>> getAllWrecks();
  Future<domain.Wreck?> getWreckById(String id);
  Future<List<domain.Wreck>> getWrecksForSite(String siteId);
  Future<void> updateWreck(domain.Wreck wreck);
  Future<void> deleteWreck(String id);
}
final wreckRepositoryProvider;   // Provider<WreckRepository>
final wrecksProvider;            // FutureProvider<List<domain.Wreck>>
final wreckProvider;             // FutureProvider.family<domain.Wreck?, String>
final wrecksForSiteProvider;     // FutureProvider.family<List<domain.Wreck>, String>
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late WreckRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = WreckRepository();
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

  test('create / read / update / delete with the sync ritual', () async {
    final created = await repo.createWreck(
      const Wreck(
        id: '',
        name: 'Hilma Hooker',
        siteId: 'site-1',
        latitude: 12.15,
        longitude: -68.3,
        vesselTypeName: 'ship',
        depthToDeckMeters: 18,
      ),
    );
    expect(created.id, isNotEmpty);
    expect(created.vesselType, WreckVesselType.ship);

    // The write ritual: pending mark plus an hlc stamp, no parent bump
    // (a wreck is top-level, like a site).
    final row = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.hlc, isNotNull);
    final pending = await db.select(db.syncRecords).get();
    expect(pending.where((p) => p.entityType == 'wrecks'), isNotEmpty);

    expect(await repo.getAllWrecks(), hasLength(1));
    expect(await repo.getWrecksForSite('site-1'), hasLength(1));
    expect((await repo.getWreckById(created.id))!.name, 'Hilma Hooker');

    await repo.updateWreck(created.copyWith(name: 'Hilma', yearSunk: 1984));
    final updated = (await repo.getAllWrecks()).single;
    expect(updated.name, 'Hilma');
    expect(updated.yearSunk, 1984);

    await repo.deleteWreck(created.id);
    expect(await repo.getAllWrecks(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where(
        (d) => d.entityType == 'wrecks' && d.recordId == created.id,
      ),
      isNotEmpty,
    );
  });

  test('an unknown enum name round-trips unchanged', () async {
    final created = await repo.createWreck(
      const Wreck(id: '', name: 'Mystery', vesselTypeName: 'submersible'),
    );
    final read = await repo.getWreckById(created.id);
    expect(read!.vesselTypeName, 'submersible');
    expect(read.vesselType, isNull);
  });

  test('wrecks with no site are excluded from the per-site query', () async {
    await repo.createWreck(const Wreck(id: '', name: 'Unlinked'));
    await repo.createWreck(
      const Wreck(id: '', name: 'Linked', siteId: 'site-1'),
    );
    expect(await repo.getWrecksForSite('site-1'), hasLength(1));
    expect(await repo.getAllWrecks(), hasLength(2));
  });
}
```

- [ ] **Step 2: Run to verify failure, then implement**

Repository, mirroring `SiteFeatureRepository`'s structure (`AppDatabase get _db => DatabaseService.instance.database;`, a `SyncRepository` field, `const Uuid()`):

```dart
class WreckRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Emits whenever the `wrecks` table changes so providers refresh after
  /// a local write or a sync merge.
  Stream<void> watchWreckChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.wrecks));

  Future<domain.Wreck> createWreck(domain.Wreck wreck) async {
    final id = wreck.id.isEmpty ? _uuid.v4() : wreck.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.wrecks)
        .insert(_companion(wreck.copyWith(id: id), now, insert: true));
    await _markPending(id, now);
    return wreck.copyWith(id: id);
  }

  Future<List<domain.Wreck>> getAllWrecks() async {
    final rows = await (_db.select(_db.wrecks)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<domain.Wreck?> getWreckById(String id) async {
    final row = await (_db.select(
      _db.wrecks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<domain.Wreck>> getWrecksForSite(String siteId) async {
    final rows = await (_db.select(_db.wrecks)
          ..where((t) => t.siteId.equals(siteId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<void> updateWreck(domain.Wreck wreck) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.wrecks,
    )..where((t) => t.id.equals(wreck.id))).write(_companion(wreck, now));
    await _markPending(wreck.id, now);
  }

  Future<void> deleteWreck(String id) async {
    await (_db.delete(_db.wrecks)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: 'wrecks', recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPending(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: 'wrecks',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
  // _companion(...) builds WrecksCompanion from the entity (createdAt only
  // on insert); _toDomain(Wreck row) maps back. Both private.
}
```

Write `_companion` and `_toDomain` in full, field for field, using `Value(...)` for every nullable and passing `createdAt: Value(now)` only when `insert` is true.

Providers file:

```dart
final wreckRepositoryProvider = Provider<WreckRepository>(
  (ref) => WreckRepository(),
);

final wrecksProvider = FutureProvider<List<Wreck>>((ref) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getAllWrecks();
});

final wreckProvider = FutureProvider.family<Wreck?, String>((ref, id) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getWreckById(id);
});

/// Catalogue wrecks the diver linked to this site.
final wrecksForSiteProvider = FutureProvider.family<List<Wreck>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getWrecksForSite(siteId);
});
```

- [ ] **Step 3: Run, format, commit**

Run: `pwd && flutter test test/features/wrecks/ > /tmp/wc_t4.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t4.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`.

```bash
dart format .
git add lib/features/wrecks/ test/features/wrecks/
git commit -m "feat(wrecks): repository, providers, write ritual"
```

---

### Task 5: Sync enrollment

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (the twelve `'siteFeatures'` points at lines 435, 514, 915, 1397, 1887, 2815, 3538, 3771, 3998, 4379 plus the field/ctor entries and a new delta export)
- Modify: `lib/core/services/sync/sync_service.dart` (merge list ~1341, `entityHasUpdatedAt` ~1954, `parentRefs` ~2062)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets`)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` map)
- Test: `test/core/services/sync/wrecks_sync_test.dart` (new)

**Interfaces:**
- Consumes: the `wrecks` table (Task 2).
- Produces: the `'wrecks'` sync entity, LWW, exported by its own `hlc`; `parentRefs['siteFeatures']` gains its `wreckId` reference.

- [ ] **Step 1: Write the failing round-trip test**

```dart
import 'package:drift/drift.dart' show Value;
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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
            createdAt: 1,
            updatedAt: 1,
            vesselType: const Value('ship'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('wrecks fetch, upsert, list, and delete round-trip', () async {
    final record = await serializer.fetchRecord('wrecks', 'w-1');
    expect(record, isNotNull);
    expect(record!['name'], 'Hilma Hooker');

    await serializer.upsertRecord('wrecks', {
      ...record,
      'name': 'Hilma',
      'updatedAt': 2,
    });
    expect((await serializer.fetchRecord('wrecks', 'w-1'))!['name'], 'Hilma');

    expect(await serializer.recordIdsFor('wrecks'), contains('w-1'));

    await serializer.deleteRecord('wrecks', 'w-1');
    expect(await serializer.fetchRecord('wrecks', 'w-1'), isNull);
  });

  test('the delta export filters on the row own hlc', () async {
    await (db.update(db.wrecks)..where((t) => t.id.equals('w-1'))).write(
      const WrecksCompanion(hlc: Value('2026-08-17T00:00:00.000-0000')),
    );

    Future<int> count(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return payload.data.wrecks.length;
    }

    expect(await count(null), 1);
    expect(await count('2026-08-18T00:00:00.000-0000'), 0);
    expect(await count('2026-08-16T00:00:00.000-0000'), 1);
  });
}
```

- [ ] **Step 2: Run to verify failure** (`recordIdsFor` throws on a missing case by design), then **Step 3: Implement every enrollment point**

In `sync_data_serializer.dart`, add `wrecks` everywhere `siteFeatures` appears, positioned immediately after it so site-scoped data stays together:

1. Field: `final List<Map<String, dynamic>> wrecks;`
2. Ctor default: `this.wrecks = const [],`
3. `toJson`: `'wrecks': wrecks,` (this position defines the required `_baseTables` order)
4. `fromJson`: `wrecks: _parseList(json['wrecks']),`
5. `_baseTables`, at the SAME relative position: `(key: 'wrecks', table: _db.wrecks, blob: false, full: null),`
6. `_buildSyncData`: `wrecks: await _safeExport('wrecks', () => _exportWrecks(hlcSince)),`
7. `fetchRecord`:

```dart
      case 'wrecks':
        final row = await (_db.select(
          _db.wrecks,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

8. `upsertRecord`:

```dart
      case 'wrecks':
        await _db
            .into(_db.wrecks)
            .insertOnConflictUpdate(
              Wreck.fromJson(_withTimestampDefaults(data)),
            );
        return;
```

9. `upsertRecords` (batched):

```dart
      case 'wrecks':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.wrecks,
            records
                .map((r) => Wreck.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
```

10. `recordIdsFor`: `case 'wrecks': return plain(_db.wrecks, _db.wrecks.id);`
11. `_syncTableFor`: `case 'wrecks': return _db.wrecks;`
12. `deleteRecord`:

```dart
      case 'wrecks':
        await (_db.delete(
          _db.wrecks,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

Plus the delta export next to `_exportSiteFeatures`:

```dart
  /// Wrecks carry their own hlc (mutable LWW entity), so the delta
  /// filters on the row's clock rather than joining a parent.
  Future<List<Map<String, dynamic>>> _exportWrecks(String? hlcSince) async {
    final query = _db.select(_db.wrecks);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

In `sync_service.dart`:
- Merge list, after the `siteFeatures` entry: `(type: 'wrecks', records: data.wrecks, hasUpdatedAt: true),`
- `entityHasUpdatedAt`: `'wrecks': true,`
- `parentRefs`: add the new entity and extend the existing `siteFeatures` entry:

```dart
    'wrecks': [
      (field: 'diverId', parent: 'divers', nullable: true),
      (field: 'siteId', parent: 'diveSites', nullable: true),
    ],
```

```dart
    'siteFeatures': [
      (field: 'siteId', parent: 'diveSites', nullable: false),
      (field: 'wreckId', parent: 'wrecks', nullable: true),
    ],
```

In `sync_repository.dart` `_hlcTargets`: `'wrecks': (table: 'wrecks', pk: 'id'),`

In `sync_parent_refs_completeness_test.dart` `syncedTables`: `'wrecks': 'wrecks',`

- [ ] **Step 4: Run the full sync suite**

Run: `pwd && flutter test test/core/services/sync/ test/core/data/ > /tmp/wc_t5.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t5.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`. The completeness suites name any spot still missing; fix exactly what they name.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/sync/ lib/core/data/repositories/sync_repository.dart test/core/services/sync/
git commit -m "feat(wrecks): enroll wrecks as an LWW sync entity"
```

---

### Task 6: Site merge relink and undo

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (snapshot capture, transaction, relink helpers, `MergeSnapshot`, `undoMerge`)
- Test: `test/features/dive_sites/data/repositories/site_merge_wrecks_test.dart` (new)

**Interfaces:**
- Consumes: the `wrecks` table, `markRecordPending('wrecks')`.
- Produces: `MergeSnapshot.wreckOriginalSiteIds` (`Map<String, String>`, defaults `const {}`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late WreckRepository wreckRepository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    wreckRepository = WreckRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(tearDownTestDatabase);

  test('merge re-points wrecks to the survivor; undo restores', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'Salt Pier'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'Salt Peir'),
    );
    final wreck = await wreckRepository.createWreck(
      Wreck(id: '', name: 'Hilma Hooker', siteId: lose.id),
    );

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );
    expect(snapshot, isNotNull);

    var row = await database.select(database.wrecks).getSingle();
    expect(row.siteId, 'keep');
    expect(snapshot!.wreckOriginalSiteIds, {wreck.id: 'lose'});

    await repository.undoMerge(snapshot);
    row = await database.select(database.wrecks).getSingle();
    expect(row.siteId, 'lose');
  });

  test('an unlinked wreck is untouched by a merge', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'A'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'B'),
    );
    await wreckRepository.createWreck(const Wreck(id: '', name: 'Unlinked'));

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );

    expect(snapshot!.wreckOriginalSiteIds, isEmpty);
    expect((await database.select(database.wrecks).getSingle()).siteId, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure, then implement**

1. Snapshot capture, beside the existing `affectedFeatures` capture:

```dart
      final affectedWrecks = await (_db.select(
        _db.wrecks,
      )..where((t) => t.siteId.isIn(duplicateIds))).get();
      final wreckOriginalSiteIds = {
        for (final w in affectedWrecks)
          if (w.siteId != null) w.id: w.siteId!,
      };
```

2. Transaction, after `_relinkSiteFeatures(...)`: `await _relinkWrecks(duplicateIds, survivorId, now);`
3. Helper, after `_relinkSiteFeatures`:

```dart
  /// Catalogue wrecks follow their site through a merge. The link is
  /// nullable, so only rows that actually pointed at a loser move.
  Future<void> _relinkWrecks(
    List<String> duplicateIds,
    String survivorId,
    int now,
  ) async {
    if (duplicateIds.isEmpty) return;

    final affected = await (_db.select(
      _db.wrecks,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();

    if (affected.isEmpty) return;

    await (_db.update(
      _db.wrecks,
    )..where((t) => t.siteId.isIn(duplicateIds))).write(
      WrecksCompanion(siteId: Value(survivorId), updatedAt: Value(now)),
    );

    for (final wreck in affected) {
      await _syncRepository.markRecordPending(
        entityType: 'wrecks',
        recordId: wreck.id,
        localUpdatedAt: now,
      );
    }
  }
```

4. `MergeSnapshot`: add `final Map<String, String> wreckOriginalSiteIds;` with ctor param `this.wreckOriginalSiteIds = const {},`, and pass the captured map where the snapshot is constructed.
5. `undoMerge`, after the feature restore loop:

```dart
        // 4c. Re-point catalogue wrecks back to their original sites
        for (final entry in snapshot.wreckOriginalSiteIds.entries) {
          await (_db.update(
            _db.wrecks,
          )..where((t) => t.id.equals(entry.key))).write(
            WrecksCompanion(
              siteId: Value(entry.value),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'wrecks',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }
```

- [ ] **Step 3: Run, format, commit**

Run: `pwd && flutter test test/features/dive_sites/data/ > /tmp/wc_t6.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t6.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`.

```bash
dart format .
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart test/features/dive_sites/data/repositories/site_merge_wrecks_test.dart
git commit -m "feat(wrecks): merge relink and undo for catalogue wrecks"
```

---

### Task 7: l10n keys

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`

**Interfaces:**
- Produces: every string later tasks reference. Add with `"@key": {}` metadata, inserted next to `"nav_sites"`, then run `flutter gen-l10n` from the project root.

- [ ] **Step 1: Add the keys**

| key | en | de | es | fr | it | nl | pt | hu | ar | he | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|
| nav_wrecks | Wrecks | Wracks | Pecios | Épaves | Relitti | Wrakken | Naufrágios | Roncsok | حطام السفن | ספינות טרופות | 沉船 |
| wrecks_empty_title | No wrecks yet | Noch keine Wracks | Aún no hay pecios | Aucune épave | Nessun relitto | Nog geen wrakken | Ainda sem naufrágios | Még nincs roncs | لا توجد حطام بعد | אין ספינות טרופות | 尚无沉船 |
| wrecks_empty_body | Add wrecks you dive or want to dive | Wracks hinzufügen, die Sie tauchen oder tauchen möchten | Añade pecios que buceas o quieres bucear | Ajoutez les épaves que vous plongez ou souhaitez plonger | Aggiungi i relitti che immergi o vuoi immergere | Voeg wrakken toe die je duikt of wilt duiken | Adicione naufrágios que mergulha ou quer mergulhar | Adjon hozzá roncsokat, amelyeket merül vagy merülni szeretne | أضف الحطام الذي تغوص فيه أو ترغب بذلك | הוסיפו ספינות טרופות שצללתם או תרצו לצלול | 添加您潜过或想潜的沉船 |
| wrecks_add | Add wreck | Wrack hinzufügen | Añadir pecio | Ajouter une épave | Aggiungi relitto | Wrak toevoegen | Adicionar naufrágio | Roncs hozzáadása | إضافة حطام | הוספת ספינה טרופה | 添加沉船 |
| wrecks_edit | Edit wreck | Wrack bearbeiten | Editar pecio | Modifier l'épave | Modifica relitto | Wrak bewerken | Editar naufrágio | Roncs szerkesztése | تحرير الحطام | עריכת ספינה טרופה | 编辑沉船 |
| wrecks_field_name | Name | Name | Nombre | Nom | Nome | Naam | Nome | Név | الاسم | שם | 名称 |
| wrecks_field_vesselType | Vessel type | Schiffstyp | Tipo de embarcación | Type de navire | Tipo di imbarcazione | Vaartuigtype | Tipo de embarcação | Hajótípus | نوع السفينة | סוג כלי השיט | 船舶类型 |
| wrecks_field_depthToDeck | Depth to deck | Tiefe bis Deck | Profundidad a cubierta | Profondeur au pont | Profondità al ponte | Diepte tot dek | Profundidade ao convés | Mélység a fedélzetig | العمق حتى السطح | עומק לסיפון | 至甲板深度 |
| wrecks_field_depthToSeabed | Depth to seabed | Tiefe bis Grund | Profundidad al fondo | Profondeur au fond | Profondità al fondale | Diepte tot bodem | Profundidade ao fundo | Mélység a fenékig | العمق حتى القاع | עומק לקרקעית | 至海底深度 |
| wrecks_field_length | Length | Länge | Eslora | Longueur | Lunghezza | Lengte | Comprimento | Hossz | الطول | אורך | 长度 |
| wrecks_field_yearBuilt | Year built | Baujahr | Año de construcción | Année de construction | Anno di costruzione | Bouwjaar | Ano de construção | Építés éve | سنة البناء | שנת בנייה | 建造年份 |
| wrecks_field_yearSunk | Year sunk | Untergangsjahr | Año del hundimiento | Année du naufrage | Anno dell'affondamento | Zinkjaar | Ano do naufrágio | Elsüllyedés éve | سنة الغرق | שנת הטביעה | 沉没年份 |
| wrecks_field_cause | Cause of sinking | Untergangsursache | Causa del hundimiento | Cause du naufrage | Causa dell'affondamento | Oorzaak van zinken | Causa do naufrágio | Süllyedés oka | سبب الغرق | סיבת הטביעה | 沉没原因 |
| wrecks_field_condition | Condition | Zustand | Estado | État | Condizione | Staat | Condição | Állapot | الحالة | מצב | 状况 |
| wrecks_field_penetration | Penetration possible | Eindringen möglich | Penetración posible | Pénétration possible | Penetrazione possibile | Penetratie mogelijk | Penetração possível | Behatolás lehetséges | الاختراق ممكن | חדירה אפשרית | 可穿透 |
| wrecks_field_protection | Protected status | Schutzstatus | Estado de protección | Statut de protection | Stato di protezione | Beschermingsstatus | Estado de proteção | Védettségi állapot | حالة الحماية | מצב הגנה | 保护状态 |
| wrecks_field_site | Dive site | Tauchplatz | Punto de buceo | Site de plongée | Sito d'immersione | Duikstek | Local de mergulho | Merülőhely | موقع الغوص | אתר צלילה | 潜点 |
| wrecks_field_notes | Notes | Notizen | Notas | Remarques | Note | Notities | Notas | Jegyzetek | ملاحظات | הערות | 备注 |
| wrecks_sectionTitle | Wrecks here | Wracks hier | Pecios aquí | Épaves ici | Relitti qui | Wrakken hier | Naufrágios aqui | Roncsok itt | الحطام هنا | ספינות טרופות כאן | 此处的沉船 |
| wrecks_link | Link a wreck | Wrack verknüpfen | Vincular un pecio | Associer une épave | Collega un relitto | Wrak koppelen | Vincular naufrágio | Roncs társítása | ربط حطام | קישור ספינה טרופה | 关联沉船 |
| wrecks_linkNone | No wreck | Kein Wrack | Sin pecio | Aucune épave | Nessun relitto | Geen wrak | Sem naufrágio | Nincs roncs | بدون حطام | ללא ספינה טרופה | 无沉船 |
| wrecks_type_ship | Ship | Schiff | Barco | Navire | Nave | Schip | Navio | Hajó | سفينة | אונייה | 船 |
| wrecks_type_aircraft | Aircraft | Flugzeug | Aeronave | Aéronef | Aeromobile | Vliegtuig | Aeronave | Repülőgép | طائرة | מטוס | 飞机 |
| wrecks_type_other | Other | Andere | Otro | Autre | Altro | Overig | Outro | Egyéb | أخرى | אחר | 其他 |
| wrecks_cause_foundered | Foundered | Gesunken | Hundido | Sombré | Affondato | Vergaan | Afundado | Elsüllyedt | غرق | טבעה | 失事沉没 |
| wrecks_cause_collision | Collision | Kollision | Colisión | Collision | Collisione | Aanvaring | Colisão | Ütközés | تصادم | התנגשות | 碰撞 |
| wrecks_cause_grounding | Grounding | Strandung | Encallamiento | Échouement | Incaglio | Stranding | Encalhe | Zátonyra futás | جنوح | עלייה על שרטון | 搁浅 |
| wrecks_cause_scuttled | Scuttled | Selbstversenkung | Hundido a propósito | Sabordé | Autoaffondato | Tot zinken gebracht | Afundado propositalmente | Elsüllyesztett | إغراق متعمد | הוטבעה בכוונה | 自沉 |
| wrecks_cause_war | War loss | Kriegsverlust | Pérdida de guerra | Perte de guerre | Perdita bellica | Oorlogsverlies | Perda de guerra | Háborús veszteség | خسارة حربية | אבדן מלחמה | 战争损失 |
| wrecks_cause_fire | Fire | Feuer | Incendio | Incendie | Incendio | Brand | Incêndio | Tűz | حريق | שריפה | 火灾 |
| wrecks_cause_unknown | Unknown | Unbekannt | Desconocida | Inconnue | Sconosciuta | Onbekend | Desconhecida | Ismeretlen | غير معروف | לא ידוע | 未知 |
| wrecks_condition_intact | Intact | Intakt | Intacto | Intact | Intatto | Intact | Intacto | Ép | سليم | שלמה | 完整 |
| wrecks_condition_broken | Broken up | Auseinandergebrochen | Partido | Brisé | Spezzato | Gebroken | Partido | Törött | متكسر | שבורה | 破裂 |
| wrecks_condition_debris | Debris field | Trümmerfeld | Campo de restos | Champ de débris | Campo di detriti | Puinveld | Campo de destroços | Törmelékmező | حقل حطام | שדה שברים | 残骸区 |
| wrecks_protection_none | None | Keiner | Ninguno | Aucun | Nessuno | Geen | Nenhum | Nincs | لا يوجد | ללא | 无 |
| wrecks_protection_permitRequired | Permit required | Genehmigung erforderlich | Permiso requerido | Permis requis | Permesso richiesto | Vergunning vereist | Autorização necessária | Engedély szükséges | يلزم تصريح | נדרש היתר | 需要许可 |
| wrecks_protection_protected | Protected | Geschützt | Protegido | Protégé | Protetto | Beschermd | Protegido | Védett | محمي | מוגנת | 受保护 |
| wrecks_protection_warGrave | War grave | Kriegsgrab | Tumba de guerra | Sépulture de guerre | Tomba di guerra | Oorlogsgraf | Túmulo de guerra | Háborús sír | مقبرة حربية | קבר מלחמה | 战争坟场 |
| wrecks_deleteConfirm | Delete {name}? | {name} löschen? | ¿Eliminar {name}? | Supprimer {name} ? | Eliminare {name}? | {name} verwijderen? | Excluir {name}? | Törli: {name}? | حذف {name}؟ | למחוק את {name}? | 删除 {name}？ |

`wrecks_deleteConfirm` needs full placeholder metadata:

```json
  "@wrecks_deleteConfirm": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 2: Generate and commit**

Run: `pwd && flutter gen-l10n && flutter analyze lib/l10n > /tmp/wc_t7.log 2>&1; echo "exit=$?"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/l10n/arb/
git commit -m "feat(wrecks): l10n for the wreck catalogue"
```

---

### Task 8: Nav destination and route

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (entry after `sites`)
- Modify: `lib/core/theme/feature_accent_colors.dart` (BOTH palettes, next to `'sites'` at lines ~19 and ~57)
- Modify: `lib/core/router/app_router.dart` (new `/wrecks` route with nested `new`, `:wreckId`, and `:wreckId/edit`)
- Modify: `test/shared/widgets/nav/nav_destinations_test.dart`, `test/shared/widgets/nav/rail_destination_order_test.dart`
- Test: `test/features/wrecks/presentation/pages/wreck_routes_test.dart` (new)

**Interfaces:**
- Consumes: the pages from Task 9 (`WreckListPage`, `WreckDetailPage`, `WreckEditPage`). Implement Task 9 first if working out of order; the route bodies reference those class names.
- Produces: routes `/wrecks`, `/wrecks/new`, `/wrecks/:wreckId`, `/wrecks/:wreckId/edit`, and the `wrecks` nav id.

- [ ] **Step 1: Update the two nav contract tests first**

In `nav_destinations_test.dart`: the count assertion goes from 16 to 17 (and its description from "15 routable + more sentinel" to 16), and `'wrecks'` is inserted after `'sites'` in the expected id list. In `rail_destination_order_test.dart`: add `('wrecks', '/wrecks')` after `('sites', '/sites')`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/shared/widgets/nav/ test/core/theme/feature_accent_colors_test.dart`
Expected: FAIL (count 16 != 17, order mismatch).

- [ ] **Step 3: Implement**

1. `nav_destinations.dart`, immediately after the `sites` entry:

```dart
  NavDestination(
    id: 'wrecks',
    route: '/wrecks',
    icon: Icons.sailing_outlined,
    selectedIcon: Icons.sailing,
    label: (l10n) => l10n.nav_wrecks,
  ),
```

Also update the doc comment above `kNavDestinations` (it states the length).

2. `feature_accent_colors.dart`, in BOTH maps next to `'sites'` (the accent test fails otherwise):

```dart
      'wrecks': Color(0xFF00695C),   // light palette
```

```dart
      'wrecks': Color(0xFF4DB6AC),   // dark palette
```

3. `app_router.dart`, as a sibling of the `/sites` route:

```dart
          // Wrecks
          GoRoute(
            path: '/wrecks',
            name: 'wrecks',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const WreckListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newWreck',
                builder: (context, state) => const WreckEditPage(),
              ),
              GoRoute(
                path: ':wreckId',
                name: 'wreckDetail',
                builder: (context, state) =>
                    WreckDetailPage(wreckId: state.pathParameters['wreckId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editWreck',
                    builder: (context, state) =>
                        WreckEditPage(wreckId: state.pathParameters['wreckId']),
                  ),
                ],
              ),
            ],
          ),
```

with the import for the three pages.

- [ ] **Step 4: Route smoke test**

Create `test/features/wrecks/presentation/pages/wreck_routes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // A local router mirroring the four /wrecks route definitions, so the
  // path-parameter contract is pinned without booting the app shell.
  testWidgets('the wrecks routes parse their path parameters', (tester) async {
    String? seenWreckId;
    String? seenEditId;

    final router = GoRouter(
      initialLocation: '/wrecks',
      routes: [
        GoRoute(
          path: '/wrecks',
          builder: (context, state) =>
              const Scaffold(body: Text('WRECK_LIST')),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  const Scaffold(body: Text('WRECK_NEW')),
            ),
            GoRoute(
              path: ':wreckId',
              builder: (context, state) {
                seenWreckId = state.pathParameters['wreckId'];
                return const Scaffold(body: Text('WRECK_DETAIL'));
              },
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    seenEditId = state.pathParameters['wreckId'];
                    return const Scaffold(body: Text('WRECK_EDIT'));
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('WRECK_LIST'), findsOneWidget);

    router.go('/wrecks/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_NEW'), findsOneWidget);

    router.go('/wrecks/w-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_DETAIL'), findsOneWidget);
    expect(seenWreckId, 'w-1');

    router.go('/wrecks/w-1/edit');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_EDIT'), findsOneWidget);
    expect(seenEditId, 'w-1');
  });
}
```

Note that `new` must be declared BEFORE `:wreckId`, or go_router matches `/wrecks/new` as a wreck whose id is the literal string `new`.

- [ ] **Step 5: Run, format, commit**

Run: `pwd && flutter test test/shared/widgets/nav/ test/core/theme/feature_accent_colors_test.dart test/core/router/ test/features/wrecks/ > /tmp/wc_t8.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t8.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`.

```bash
dart format .
git add lib/shared/widgets/nav/ lib/core/theme/feature_accent_colors.dart lib/core/router/app_router.dart test/
git commit -m "feat(wrecks): nav destination and routes"
```

---

### Task 9: List, detail, and edit pages

**Files:**
- Create: `lib/features/wrecks/presentation/pages/wreck_list_page.dart`, `wreck_detail_page.dart`, `wreck_edit_page.dart`
- Create: `lib/features/wrecks/presentation/widgets/wreck_list_content.dart`
- Test: `test/features/wrecks/presentation/pages/wreck_list_page_test.dart`, `wreck_detail_page_test.dart`, `wreck_edit_page_test.dart` (new)

**Interfaces:**
- Consumes: `wrecksProvider`, `wreckProvider`, `wreckRepositoryProvider` (Task 4); the l10n keys (Task 7); `SiteScapeView` from `lib/features/site_scape/presentation/site_scape_view.dart`.
- Produces: `class WreckListPage extends ConsumerStatefulWidget { const WreckListPage({super.key}); }`, `class WreckDetailPage extends ConsumerWidget { final String wreckId; const WreckDetailPage({super.key, required this.wreckId}); }`, `class WreckEditPage extends ConsumerStatefulWidget { final String? wreckId; const WreckEditPage({super.key, this.wreckId}); }` (null wreckId is the create flow).

- [ ] **Step 1: Write the failing list test**

```dart
testWidgets('the list shows wrecks and filters by search', (tester) async {
  // ProviderScope overriding wrecksProvider with two wrecks
  // ('Hilma Hooker', 'Salt Pier Barge'), settingsProvider mocked, en
  // locale, home: WreckListPage(). Bounded pumps.
  // Assert both names render; enter 'hilma' in the search field
  // (ValueKey('wreckSearchField')); assert only 'Hilma Hooker' remains.
});

testWidgets('an empty catalogue shows the empty state', (tester) async {
  // wrecksProvider overridden with []; assert wrecks_empty_title text
  // and that the add action (ValueKey('wreckAddButton')) is present.
});
```

Write both in full, modeled on `site_list_content_test.dart`'s pump helper. Every provider override, widget key, and expected string named in the comments above is binding: those are the assertions, spelled out rather than paraphrased.

- [ ] **Step 2: Implement the list**

`WreckListPage` uses `MasterDetailScaffold` exactly as `SiteListPage` does (`sectionKey: 'wrecks'`, `?selected=` handling, detail pane `WreckDetailPage`), with `WreckListContent` as the master pane: a search field (`ValueKey('wreckSearchField')`) filtering on name case-insensitively, rows showing name plus depth-to-deck in display units and the linked site's name when present, an empty state using `wrecks_empty_title` / `wrecks_empty_body`, and a FAB (`ValueKey('wreckAddButton')`) pushing `/wrecks/new`. Do NOT add table mode or the map/list toggle in this task; the list is the deliverable.

- [ ] **Step 3: Write the failing detail test, then implement**

```dart
testWidgets('detail renders the facts in the diver unit', (tester) async {
  // wreckProvider('w-1') overridden with a wreck: name 'Hilma Hooker',
  // vesselTypeName 'ship', depthToDeckMeters 18, depthToSeabedMeters 30,
  // yearSunk 1984, conditionName 'intact'. Metric settings.
  // Assert: 'Hilma Hooker', 'Ship', '18 m', '30 m', '1984', 'Intact'.
});

testWidgets('a feet diver reads the depths in feet', (tester) async {
  // Same wreck, AppSettings(depthUnit: DepthUnit.feet); assert '59.1 ft'
  // for the deck depth (18 / 0.3048 = 59.055, one decimal).
});

testWidgets('an unknown enum name shows its raw value', (tester) async {
  // vesselTypeName 'submersible'; assert find.text('submersible').
});
```

`WreckDetailPage` watches `wreckProvider(wreckId)`; on data it renders the name as the title, a map card via `SiteScapeView` when `hasCoordinates` (selectedSiteId null, selectedSiteLocation the wreck position, mode held in local state, mapBuilder a single-pin `FlutterMap` mirroring the site detail preview), a facts card using the label helpers, the linked site as a tappable row pushing `/sites/<id>`, and app-bar edit and delete actions. Delete confirms with `wrecks_deleteConfirm(name)` and pops on success. A null wreck (deleted underneath) renders the not-found message rather than throwing.

Label helpers live beside the pages in `wreck_labels.dart`: `String wreckVesselTypeLabel(AppLocalizations, String? raw)`, and the same shape for cause, condition, and protection. Each switches on `Enum.values.asNameMap()[raw]` and returns the raw string for an unknown name and the empty string for null, exactly as `siteFeatureTypeLabel` does.

- [ ] **Step 4: Write the failing edit test, then implement**

```dart
testWidgets('creating a wreck writes it through the repository', (
  tester,
) async {
  // Recording fake repository (implements WreckRepository, records
  // createWreck/updateWreck calls, noSuchMethod for the rest).
  // WreckEditPage() with no wreckId; enter 'Hilma Hooker' in
  // ValueKey('wreckNameField'), '18' in ValueKey('wreckDeckDepthField'),
  // pick 'Ship' in ValueKey('wreckVesselTypeField'), tap
  // ValueKey('wreckSaveButton'). Assert one createWreck call with
  // name 'Hilma Hooker', depthToDeckMeters 18, vesselTypeName 'ship'.
});

testWidgets('a feet diver types feet and metres are stored', (tester) async {
  // AppSettings(depthUnit: DepthUnit.feet); enter '60' for deck depth;
  // assert the recorded depthToDeckMeters is closeTo(18.288, 1e-9).
});

testWidgets('saving without a name is refused', (tester) async {
  // Tap save with an empty name; assert no repository call and that the
  // form shows its validation message.
});
```

`WreckEditPage` is a `Form` with a `GlobalKey<FormState>`: name (required), vessel type dropdown, deck and seabed depth and length in display units, year built and year sunk (integer fields, four digits max), cause and condition and protection dropdowns, a penetration tristate (`DropdownButtonFormField<bool?>` with unknown/yes/no), a site picker sourced from `sitesProvider` with a "no site" entry (`wrecks_linkNone`), the shared location picker, and notes. Save maps display units back to meters, then calls `createWreck` or `updateWreck` and pops.

- [ ] **Step 5: Run, format, commit**

Run: `pwd && flutter test test/features/wrecks/ > /tmp/wc_t9.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t9.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`.

```bash
dart format .
git add lib/features/wrecks/ test/features/wrecks/
git commit -m "feat(wrecks): list, detail, and edit pages"
```

---

### Task 10: Site detail section and feature wreck picker

**Files:**
- Create: `lib/features/wrecks/presentation/widgets/site_wrecks_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (body column, after the features section)
- Modify: `lib/features/site_scape/presentation/site_feature_sheet.dart` (wreck picker when the type is `wreck`)
- Modify: `lib/features/dive_sites/data/repositories/site_feature_repository.dart` (carry `wreckId` through add/update)
- Test: `test/features/wrecks/presentation/widgets/site_wrecks_section_test.dart` (new), extend `test/features/site_scape/presentation/site_feature_sheet_test.dart`

**Interfaces:**
- Consumes: `wrecksForSiteProvider` (Task 4), `wrecksProvider`, the l10n keys (Task 7).
- Produces: `class SiteWrecksSection extends ConsumerWidget { final String siteId; const SiteWrecksSection({super.key, required this.siteId}); }`; `SiteFeatureSheetSave` gains `final String? wreckId;`; `SiteFeatureRepository.addFeature` gains `String? wreckId`, and `updateFeature` persists `feature.wreckId`.

- [ ] **Step 1: Write the failing section test**

```dart
testWidgets('the section lists linked wrecks and opens one', (tester) async {
  // ProviderScope overriding wrecksForSiteProvider('site-1') with one
  // wreck ('Hilma Hooker', depthToDeckMeters 18), settings mocked, en
  // locale, home: Scaffold(body: SiteWrecksSection(siteId: 'site-1')).
  // Assert the section title (wrecks_sectionTitle), the wreck name, and
  // the depth in display units; tapping the row invokes navigation to
  // /wrecks/<id> (captured through a local GoRouter).
});

testWidgets('no linked wrecks renders nothing', (tester) async {
  // wrecksForSiteProvider overridden with []; assert the section title
  // is absent, so an empty section never occupies space on site detail.
});
```

- [ ] **Step 2: Implement the section and wire it**

`SiteWrecksSection` watches `wrecksForSiteProvider(siteId)`, returns `SizedBox.shrink()` when the list is empty, and otherwise renders a `Card` with the `wrecks_sectionTitle` header, one `ListTile` per wreck (leading `Icons.sailing`, title name, subtitle deck depth in display units), each pushing `/wrecks/<id>`, plus a `wrecks_link` action pushing `/wrecks/new`. Insert it in `site_detail_page.dart` immediately after the `SiteFeaturesSection` block, inside the same `if (site.hasCoordinates)` guard.

- [ ] **Step 3: Write the failing picker test, then implement**

Append to `site_feature_sheet_test.dart`:

```dart
testWidgets('the wreck picker appears only for the wreck type', (
  tester,
) async {
  // pumpHost with wrecksProvider overridden to one wreck. Default type
  // is 'wreck', so ValueKey('siteFeatureWreckField') is present; switch
  // the type to 'Mooring' and assert it disappears.
});

testWidgets('picking a wreck returns its id in the save result', (
  tester,
) async {
  // Open the picker, choose 'Hilma Hooker', save; assert the returned
  // SiteFeatureSheetSave.wreckId equals that wreck's id.
});
```

In the sheet: add `final String? wreckId;` to `SiteFeatureSheetSave` (and to `_save`), hold `String? _wreckId = widget.existing?.wreckId` in state, and render a `DropdownButtonFormField<String?>` keyed `siteFeatureWreckField` only when `_typeName == SiteFeatureType.wreck.name`. Its items come from `await ref.read(wrecksProvider.future)` resolved in `initState` into local state, NOT from a bare `ref.read` of the AsyncValue: that exact shape silently dropped taps in slice 2 until the coverage pass caught it. Include a `wrecks_linkNone` entry mapping to null.

Then thread the value: `SiteFeature` gains `final String? wreckId;` with `copyWith` support including a `clearWreck` flag, `SiteFeatureRepository.addFeature` gains a `String? wreckId` parameter written into the companion, `updateFeature` writes `wreckId: Value(feature.wreckId)`, and `_toDomain` reads it back. The marker layer's `editSiteFeature` passes `wreckId: wreckId, clearWreck: wreckId == null` into its `copyWith`.

- [ ] **Step 4: Run, format, commit**

Run: `pwd && flutter test test/features/wrecks/ test/features/site_scape/ test/features/dive_sites/ > /tmp/wc_t10.log 2>&1; code=$?; echo "exit=$code"; tr '\r' '\n' < /tmp/wc_t10.log | grep -E "All tests passed|Some tests failed" | tail -1`
Expected: exit=0 and `All tests passed!`.

```bash
dart format .
git add lib/features/ test/features/
git commit -m "feat(wrecks): site detail section and feature wreck picker"
```

---

### Task 11: Full verification and PR

- [ ] **Step 1: Verify**

```bash
pwd
dart format .
flutter analyze
flutter gen-l10n
git status --short          # database.g.dart must NOT appear
```

Then the suite, in three foreground chunks so each fits the timeout and each verdict is read from the log itself:

```bash
export TMPDIR="$PWD/.tmp-flutter-test"; mkdir -p "$TMPDIR"
flutter test test/core > /tmp/wc_c1.log 2>&1; echo "exit=$?"
flutter test test/features > /tmp/wc_c2.log 2>&1; echo "exit=$?"
flutter test test/architecture test/accessibility test/shared test/l10n test/dives test/integration test/performance test/app_test.dart test/macos_entitlements_test.dart > /tmp/wc_c3.log 2>&1; echo "exit=$?"
```

For each log: `tr '\r' '\n' < /tmp/wc_cN.log | grep -E "All tests passed|Some tests failed" | tail -1`. A missing verdict line means the run was killed (a sibling session's `pkill`), not that it passed: re-run that chunk.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin worktree-wreck-catalogue
gh pr create --repo submersion-app/submersion --base main --head worktree-wreck-catalogue --title "feat(wrecks): editable wreck catalogue with site and feature links" --body-file <body file>
```

PR body per repo conventions (no attribution line, no session URL): cover the new entity and v153, the sync enrollment, the setNull lifecycle choices, merge relink and undo, the nav destination and routes, the three pages, and the two link points (site detail section, feature wreck picker). State explicitly that external sources are slice 3b and 3D rendering is 3c.

## Execution notes

- Manual visual pass before merge: `flutter run -d macos`; create a wreck with and without coordinates, link one to a site, confirm the site detail section shows it, place a wreck feature on that site and link it through the picker, delete the site and confirm the wreck survives with its link cleared, then merge two sites and undo.
- Task 8 depends on Task 9's page classes; if executing strictly in order, stub the three page classes at the top of Task 8 and fill them in Task 9, or simply execute Task 9 first.
- The nav contract tests (`nav_destinations_test`, `rail_destination_order_test`) and the accent palette test are the tripwires for a new destination. All three are updated in Task 8; if any other test hardcodes the destination count, its failure message names it.
- Adding an enum-valued column means adding it as raw TEXT, never a Drift enum column: a value from a newer build must survive sync rather than crash the decode.
