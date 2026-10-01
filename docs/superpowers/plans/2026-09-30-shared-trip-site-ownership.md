# Shared Trip and Site Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Only the owning profile can delete, unshare or merge away a shared trip or dive site; every other profile hides it from itself instead, so no profile's action removes anything from another profile (issue #2594).

**Architecture:** Two new synced tables (`trip_hides`, `site_hides`, schema v250) hold each profile's hidden shared items. `VisibilityFilter`, the single choke point for trip and site lists, excludes the active profile's hidden rows. A pure policy file (`shared_item_policy.dart`) decides destroy-or-hide, and both the repositories (enforcement) and the UI (which action to offer) ask it.

**Tech Stack:** Flutter, Riverpod (StateNotifier and FutureProvider), Drift (SQLite), the app's HLC sync (`SyncDataSerializer` / `SyncService`), gen-l10n ARB files in 11 locales.

**Spec:** `docs/superpowers/specs/2026-09-30-shared-trip-site-ownership-design.md`

## Global Constraints

- Schema version becomes exactly `250`; `AppDatabase.minimumCompatibleSchemaVersion` stays `240` (table-only rung, an older peer keeps the new entity types as inert unknowns).
- Tables live in `lib/core/database/tables/`, rungs and helpers in `lib/core/database/migrations/`; never define a table or a rung in `database.dart` itself (it only lists them).
- New sync entity type names: `tripHides` (table `trip_hides`) and `siteHides` (table `site_hides`).
- Every new ARB key is added to `app_en.arb` (alphabetical position) and translated into all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. Non-English ARB files are grouped by feature, not alphabetical: insert next to a neighbouring key.
- ARB plurals use `one{...}` and `other{...}` with the `{count}` placeholder inside the text, never `=1{1 ...}` with a hard-coded digit.
- Never use the em-dash character or the en-dash as prose punctuation in code, comments, strings, commits or the PR.
- No tool or model attribution in commits, the PR or any file.
- Paths in tests are built with `p.join`, never a literal `/`.
- A test that replaces process-wide state restores it in `addTearDown`.
- Import groups: dart, flutter, packages, then local (`package:submersion/...`).
- Codegen (Drift and Mockito): the Bash tool refuses a bare `build` token, so run it from a script file: write `dart run build_runner build --delete-conflicting-outputs` into `$SCRATCH/codegen.sh` (the session scratchpad) and run `bash $SCRATCH/codegen.sh`.
- After each task: `dart format` on the touched files, `flutter analyze` on the touched files with zero issues (infos are fatal in CI).
- Commit after each task with a conventional message ending in `Refs #2594`. Stage explicit paths, never `git add -A`.
- The spec named two explicit unique indexes; this plan uses Drift `uniqueKeys` `{diverId, tripId}` / `{diverId, siteId}` instead, which SQLite enforces through an autoindex with the same leading column. The spec's `countOtherProfilesDivesOnTrip/AtSite` become one method, `ProfileHidesRepository.diveLinkCounts`, which returns the active profile's count and every other profile's count in one query. `bulkDeleteSites` keeps its `SiteLinks` return type and skips non-destroyable ids (the notifier splits the selection before calling it and reports the split).

## Review Focus

1. **Diver delete hands a shared trip to a profile that hid it.** `deleteDiverWithReassignment` moves shared trips and sites to a surviving profile; if that profile had hidden one, it would own an item it cannot see and cannot hide again. Expected: reassignment deletes the new owner's hides of the reassigned items. Test in Task 8.
2. **A hide arrives by sync while the list is open.** The trip and site lists refresh on `trips` / `dive_sites` table ticks only. Expected: a hide or unhide written by sync refreshes the lists. Test in Task 5 (`watchTripsChanges` / `watchSitesChanges` emit on hide-table writes).
3. **Ownerless legacy rows** (`diver_id IS NULL`, shared). Expected: anyone may delete them, nobody is offered a hide, and the delete dialog never says "Remove from my profile". Tests in Task 1 (policy) and Task 6 (repository).
4. **A non-owner saves the edit page of a shared trip or site.** The page sends `isShared` from its own state. Expected: the stored `is_shared` and `diver_id` never change from a non-owner's save, even if a stale page state says otherwise. Tests in Task 6 and Task 7.
5. **Merge selection with two or more sites owned by other profiles.** Only one site can survive, so at least one non-owned site would be destroyed. Expected: the list refuses before opening the merge page, with a message; with exactly one non-owned site, it becomes the survivor. Test in Task 14.

---

## File Structure

Create:
- `lib/core/data/visibility/shared_item_policy.dart`: `SharedItemKind`, `canDestroySharedItem`, `canHideSharedItem`, `splitForBulkDelete`. Pure functions, no imports beyond Dart.
- `lib/features/divers/data/repositories/profile_hides_repository.dart`: `ProfileHidesRepository`, `HiddenItem`. The only writer of `trip_hides` / `site_hides` outside sync.
- `lib/features/divers/presentation/providers/profile_hides_providers.dart`: `profileHidesRepositoryProvider`, `hiddenItemsProvider`.
- `lib/shared/widgets/shared_items/shared_by_banner.dart`: the "Shared by {owner}" line.
- `lib/shared/widgets/shared_items/shared_item_dialogs.dart`: remove-from-profile confirmation, owner-name lookup, the other-profiles-dives line, bulk dialog body lines.
- `lib/features/settings/presentation/pages/hidden_items_page.dart`: the Settings list with Unhide.
- `test/helpers/shared_items_fixture.dart`: seeding and sync-bookkeeping helpers shared by the repository tests.
- Tests listed per task.

Modify (main ones): `trip_tables.dart`, `site_tables.dart`, `database.dart`, `migrations/helpers/trip_migrations.dart`, `migrations/helpers/site_migrations.dart`, `migrations/ladder/rungs_v231_onward.dart`, `migrations/before_open.dart`, `sync_repository.dart`, `sync_data_serializer.dart`, `sync_service.dart`, `visibility_filter.dart`, `query_name_index.dart`, `site_type_repository.dart`, `trip_repository.dart`, `site_repository_impl.dart`, `dive_parent_links.dart`, `diver_delete_steps.dart`, `diver_repository.dart`, `trip_providers.dart`, `site_providers.dart`, the trip and site detail/edit pages, `life_notes_section.dart`, both list contents, `settings_page.dart`, `app_router.dart`, 11 ARB files.

---

### Task 1: Sharing policy

**Files:**
- Create: `lib/core/data/visibility/shared_item_policy.dart`
- Test: `test/core/data/visibility/shared_item_policy_test.dart`

**Interfaces:**
- Produces:
  - `enum SharedItemKind { trip, site }`
  - `bool canDestroySharedItem({required String? ownerId, required String? activeDiverId})`
  - `bool canHideSharedItem({required String? ownerId, required bool isShared, required String? activeDiverId})`
  - `({List<T> destroy, List<T> hide}) splitForBulkDelete<T>(Iterable<T> items, {required String? Function(T) ownerOf, required bool Function(T) isSharedOf, required String? activeDiverId})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';

/// Who may delete or hide a shared trip or site (issue #2594).
void main() {
  group('canDestroySharedItem', () {
    test('the owner may', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: 'a'), isTrue);
    });
    test('another profile may not', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: 'b'), isFalse);
    });
    test('anyone may destroy an ownerless item', () {
      expect(canDestroySharedItem(ownerId: null, activeDiverId: 'b'), isTrue);
    });
    test('a caller naming no profile may', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: null), isTrue);
    });
  });

  group('canHideSharedItem', () {
    test('another profile may hide a shared item', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: 'b'),
        isTrue,
      );
    });
    test('the owner may not hide its own item', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: 'a'),
        isFalse,
      );
    });
    test('an unshared item is never hidden', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: false, activeDiverId: 'b'),
        isFalse,
      );
    });
    test('an ownerless item is never hidden', () {
      expect(
        canHideSharedItem(ownerId: null, isShared: true, activeDiverId: 'b'),
        isFalse,
      );
    });
    test('no active profile hides nothing', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: null),
        isFalse,
      );
    });
  });

  test('exactly one action applies to any owned shared item', () {
    for (final active in ['a', 'b']) {
      final destroy = canDestroySharedItem(ownerId: 'a', activeDiverId: active);
      final hide = canHideSharedItem(
        ownerId: 'a',
        isShared: true,
        activeDiverId: active,
      );
      expect(destroy != hide, isTrue, reason: 'active $active');
    }
  });

  test('splitForBulkDelete deletes owned and ownerless, hides others\' shared',
      () {
    final items = [
      (id: 'mine', owner: 'a', shared: true),
      (id: 'theirs', owner: 'b', shared: true),
      (id: 'legacy', owner: null, shared: true),
    ];
    final split = splitForBulkDelete(
      items,
      ownerOf: (i) => i.owner,
      isSharedOf: (i) => i.shared,
      activeDiverId: 'a',
    );
    expect(split.destroy.map((i) => i.id), ['mine', 'legacy']);
    expect(split.hide.map((i) => i.id), ['theirs']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/visibility/shared_item_policy_test.dart`
Expected: FAIL, `shared_item_policy.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
/// Who may do what to a trip or dive site shared between diver profiles
/// (issue #2594). A shared item is owned by its `diver_id` and referenced by
/// every other profile: only the owner destroys it or changes its sharing,
/// and every other profile may hide it from itself. The repositories, the
/// pages and the lists all ask here, so the rule lives in one place, as
/// `equipment_ownership.dart` does for gear.
library;

/// The two kinds of item shared through an `is_shared` flag.
enum SharedItemKind { trip, site }

/// The active profile may delete, merge away or re-share the item. An
/// ownerless item and a caller that names no profile behave as they did
/// before sharing existed.
bool canDestroySharedItem({
  required String? ownerId,
  required String? activeDiverId,
}) => activeDiverId == null || ownerId == null || ownerId == activeDiverId;

/// The active profile sees the item only because another profile shared
/// it, so it may hide it from itself. For any owned shared item exactly one
/// of this and [canDestroySharedItem] holds.
bool canHideSharedItem({
  required String? ownerId,
  required bool isShared,
  required String? activeDiverId,
}) =>
    activeDiverId != null &&
    isShared &&
    ownerId != null &&
    ownerId != activeDiverId;

/// Splits a bulk-delete selection: the items the active profile may
/// destroy, and the shared items of other profiles it hides instead. An
/// item that fits neither (another profile's private item, which the lists
/// never show) is left out of both.
({List<T> destroy, List<T> hide}) splitForBulkDelete<T>(
  Iterable<T> items, {
  required String? Function(T) ownerOf,
  required bool Function(T) isSharedOf,
  required String? activeDiverId,
}) {
  final destroy = <T>[];
  final hide = <T>[];
  for (final item in items) {
    final owner = ownerOf(item);
    if (canDestroySharedItem(ownerId: owner, activeDiverId: activeDiverId)) {
      destroy.add(item);
    } else if (canHideSharedItem(
      ownerId: owner,
      isShared: isSharedOf(item),
      activeDiverId: activeDiverId,
    )) {
      hide.add(item);
    }
  }
  return (destroy: destroy, hide: hide);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/visibility/shared_item_policy_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/visibility/shared_item_policy.dart test/core/data/visibility/shared_item_policy_test.dart
git commit -m "feat(sharing): who may delete or hide a shared trip or site

Refs #2594"
```

---

### Task 2: Schema v250, the trip_hides and site_hides tables

**Files:**
- Modify: `lib/core/database/tables/trip_tables.dart` (append after `TripEquipment`)
- Modify: `lib/core/database/tables/site_tables.dart` (append at end)
- Modify: `lib/core/database/database.dart` (table list after `TripEquipment`, `currentSchemaVersion`, `migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/trip_migrations.dart`
- Modify: `lib/core/database/migrations/helpers/site_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v249 rung)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v248 backstop)
- Modify: `test/core/database/migration_v249_trip_fill_forecast_test.dart` (relax the exact version assertion)
- Test: `test/core/database/migration_v250_profile_hides_test.dart`

**Interfaces:**
- Produces: Drift classes `TripHides` (`@DataClassName('TripHideRow')`, accessor `db.tripHides`, companion `TripHidesCompanion`) and `SiteHides` (`@DataClassName('SiteHideRow')`, accessor `db.siteHides`, companion `SiteHidesCompanion`). Columns: `id`, `tripId` / `siteId`, `diverId`, `createdAt`, `hlc`.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v250: trip_hides and site_hides, a profile's hidden shared trips
/// and sites (issue #2594).
void main() {
  /// A v249 database with only the parents the hides point at.
  NativeDatabase setupDb({bool withParents = true}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 249');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      if (withParents) {
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v250 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 250);
    expect(AppDatabase.migrationVersions, contains(250));
    expect(AppDatabase.migrationStepCount(249), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v249 creates both tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_hides'), {
      'id',
      'trip_id',
      'diver_id',
      'created_at',
      'hlc',
    });
    expect(await columnsOf(db, 'site_hides'), {
      'id',
      'site_id',
      'diver_id',
      'created_at',
      'hlc',
    });
  });

  test('a profile hides a trip or a site once', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO divers (id) VALUES ('d1')");
    await db.customStatement("INSERT INTO trips (id) VALUES ('t1')");
    await db.customStatement("INSERT INTO dive_sites (id) VALUES ('s1')");
    await db.customStatement(
      "INSERT INTO trip_hides (id, trip_id, diver_id, created_at) "
      "VALUES ('a', 't1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO trip_hides (id, trip_id, diver_id, created_at) "
        "VALUES ('b', 't1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
    await db.customStatement(
      "INSERT INTO site_hides (id, site_id, diver_id, created_at) "
      "VALUES ('c', 's1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO site_hides (id, site_id, diver_id, created_at) "
        "VALUES ('d', 's1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a fixture without the parents gains no hides tables', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_hides'), isEmpty);
    expect(await columnsOf(db, 'site_hides'), isEmpty);
  });

  test('a fresh database has both tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'trip_hides'), contains('trip_id'));
    expect(await columnsOf(db, 'site_hides'), contains('site_id'));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v250_profile_hides_test.dart`
Expected: FAIL (version is 249, tables missing).

- [ ] **Step 3: Declare the tables**

Append to `lib/core/database/tables/trip_tables.dart` (it already imports `diver_tables.dart`):

```dart

/// A shared trip one diver profile has hidden from itself (v250, issue
/// #2594). The trip stays in its owner's log and in every other profile. A
/// parent-gated child of `trips`, like `trip_equipment`: no updated_at, its
/// own clock, exported through pending marks. Both parents cascade.
@DataClassName('TripHideRow')
class TripHides extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// Leads with the profile: every read is "this profile's hidden trips".
  @override
  List<Set<Column>> get uniqueKeys => [
    {diverId, tripId},
  ];
  // coverage:ignore-end
}
```

Append to `lib/core/database/tables/site_tables.dart` (it already imports `diver_tables.dart`):

```dart

/// A shared dive site one diver profile has hidden from itself (v250, issue
/// #2594). The site stays in its owner's log and in every other profile. A
/// parent-gated child of `dive_sites`; both parents cascade.
@DataClassName('SiteHideRow')
class SiteHides extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// Leads with the profile: every read is "this profile's hidden sites".
  @override
  List<Set<Column>> get uniqueKeys => [
    {diverId, siteId},
  ];
  // coverage:ignore-end
}
```

- [ ] **Step 4: Register the tables and the rung in `database.dart`**

In the `@DriftDatabase(tables: [...])` list, after `TripEquipment,`:

```dart
    // A profile's hidden shared trips and sites (v250, issue #2594)
    TripHides,
    SiteHides,
```

Change `static const int currentSchemaVersion = 249;` to `250`. Append to `migrationVersions` after `249,`:

```dart
    // v250: trip_hides and site_hides, the shared trips and sites a profile
    // has hidden from itself (issue #2594). Table-only rung, no backfill;
    // an older peer keeps the new entity types as inert unknowns, so the
    // floor does not move. #2562 and #2409 held stale claims below 249
    // when this was taken.
    250,
```

- [ ] **Step 5: Add the idempotent helpers**

In `lib/core/database/migrations/helpers/trip_migrations.dart`, inside `extension TripMigrations on AppDatabase`, after `_assertTripEquipmentSchema`:

```dart
  /// The trip_hides table (v250, issue #2594). Called from the v250 rung
  /// and the beforeOpen backstop. Skipped on a partial migration-test
  /// fixture that lacks a parent table.
  Future<void> _assertTripHidesSchema() async {
    for (final parent in const ['trips', 'divers']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(tripHides);
  }
```

In `lib/core/database/migrations/helpers/site_migrations.dart`, inside `extension SiteMigrations on AppDatabase` (add at the end of the extension):

```dart
  /// The site_hides table (v250, issue #2594). Called from the v250 rung
  /// and the beforeOpen backstop. Skipped on a partial migration-test
  /// fixture that lacks a parent table.
  Future<void> _assertSiteHidesSchema() async {
    for (final parent in const ['dive_sites', 'divers']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(siteHides);
  }
```

`Migrator.createTable` issues `CREATE TABLE IF NOT EXISTS`, so both helpers are idempotent.

- [ ] **Step 6: Add the rung and the backstop**

In `rungs_v231_onward.dart`, after the `if (from < 249) await reportProgress();` line:

```dart
    // v250: a profile's hidden shared trips and sites (issue #2594).
    // Table-only rung, no backfill; re-asserted in beforeOpen.
    if (from < 250) {
      await _assertTripHidesSchema();
      await _assertSiteHidesSchema();
    }
    if (from < 250) await reportProgress();
```

In `before_open.dart`, after `await _assertTripEquipmentSchema();`:

```dart

    // v250 backstop: trip_hides and site_hides (idempotent).
    await _assertTripHidesSchema();
    await _assertSiteHidesSchema();
```

- [ ] **Step 7: Relax the v249 test**

In `test/core/database/migration_v249_trip_fill_forecast_test.dart`, replace `expect(AppDatabase.currentSchemaVersion, 249);` with:

```dart
    // Relaxed once v250 (profile hides, #2594) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(249));
```

and replace `expect(AppDatabase.migrationStepCount(248), 1);` / `expect(AppDatabase.migrationStepCount(247), 2);` with `expect(AppDatabase.migrationStepCount(248), 2);` / `expect(AppDatabase.migrationStepCount(247), 3);`.

- [ ] **Step 8: Run codegen, then the tests**

Run: `bash $SCRATCH/codegen.sh` (see Global Constraints), then
`flutter test test/core/database/migration_v250_profile_hides_test.dart test/core/database/migration_v249_trip_fill_forecast_test.dart test/core/database/migration_v248_trip_equipment_test.dart`
Expected: PASS. Then run the whole `test/core/database/` folder; any other test pinning `currentSchemaVersion == 249` or a step count is updated the same way.

- [ ] **Step 9: Commit**

```bash
git add lib/core/database/tables/trip_tables.dart lib/core/database/tables/site_tables.dart lib/core/database/database.dart lib/core/database/database.g.dart lib/core/database/migrations/helpers/trip_migrations.dart lib/core/database/migrations/helpers/site_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart test/core/database/migration_v250_profile_hides_test.dart test/core/database/migration_v249_trip_fill_forecast_test.dart
git commit -m "feat(sharing): add trip_hides and site_hides (schema v250)

Refs #2594"
```

(Add any other generated or test file the codegen and Step 8 touched, by explicit path; check `git status` first.)

---

### Task 3: Sync the hides as parent-gated children

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (entity map, after `'tripEquipment'`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every place `tripEquipment` appears; the list is in Step 3)
- Modify: `lib/core/services/sync/sync_service.dart` (apply-order list, `entityHasUpdatedAt`, `parentRefs`)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart:153`, `test/core/services/sync/sync_parent_refs_completeness_test.dart:107`, `test/core/services/sync/sync_serializer_fetch_record_test.dart:138`
- Test: `test/core/services/sync/profile_hides_sync_test.dart`

**Interfaces:**
- Consumes: `TripHideRow`, `SiteHideRow`, `db.tripHides`, `db.siteHides` (Task 2).
- Produces: sync entity types `tripHides` and `siteHides` accepted by `SyncDataSerializer.fetchRecord`, `upsertRecord`, `upsertRecords`, `deleteRecord`, and exported in `SyncData.tripHides` / `SyncData.siteHides`.

- [ ] **Step 1: Write the failing sync test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Sync of a profile's hidden shared trips and sites (issue #2594): parent-
/// gated children of `trips` and `dive_sites`, like trip_equipment.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;
  const t = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Salt Pier',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('a trip hide round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'h1',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('tripHides', 'h1');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('tripHides', 'h1');
    expect(await db.select(db.tripHides).get(), isEmpty);
    await serializer.upsertRecord('tripHides', fetched!);
    expect((await db.select(db.tripHides).get()).single.id, 'h1');
  });

  test('a site hide round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.siteHides)
        .insert(
          SiteHidesCompanion.insert(
            id: 'h2',
            siteId: 's1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('siteHides', 'h2');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('siteHides', 'h2');
    expect(await db.select(db.siteHides).get(), isEmpty);
    await serializer.upsertRecord('siteHides', fetched!);
    expect((await db.select(db.siteHides).get()).single.id, 'h2');
  });

  test('a peer copy of the same hide under another id converges', () async {
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'zzz-local',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    await serializer.upsertRecords('tripHides', [
      {
        'id': 'aaa-peer',
        'tripId': 't1',
        'diverId': 'b',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    final rows = await db.select(db.tripHides).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test('both types are parent-gated children with their parents declared',
      () {
    expect(SyncDataSerializer.parentGatedChildEntities, contains('tripHides'));
    expect(SyncDataSerializer.parentGatedChildEntities, contains('siteHides'));
    expect(SyncService.entityHasUpdatedAt['tripHides'], isFalse);
    expect(SyncService.entityHasUpdatedAt['siteHides'], isFalse);
    expect(
      SyncService.parentRefs['tripHides']!.map((r) => r.parent).toSet(),
      {'trips', 'divers'},
    );
    expect(
      SyncService.parentRefs['siteHides']!.map((r) => r.parent).toSet(),
      {'diveSites', 'divers'},
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/profile_hides_sync_test.dart`
Expected: FAIL (unknown entity type `tripHides`).

- [ ] **Step 3: Wire both types through the serializer**

Mirror each `tripEquipment` occurrence in `lib/core/services/sync/sync_data_serializer.dart` (see `git show 274ecd88841 -- lib/core/services/sync/sync_data_serializer.dart` for the full template):

1. `class SyncData`: fields `final List<Map<String, dynamic>> tripHides;` and `siteHides;` after `tripEquipment`; constructor defaults `this.tripHides = const [], this.siteHides = const [],`; `toJson` entries `'tripHides': tripHides, 'siteHides': siteHides,`; `fromJson` entries `tripHides: _parseList(json['tripHides']), siteHides: _parseList(json['siteHides']),`.
2. The table descriptor list (near line 1189): `(key: 'tripHides', table: _db.tripHides, blob: false, full: null), (key: 'siteHides', table: _db.siteHides, blob: false, full: null),`.
3. `parentGatedChildEntities` (line 1582): add `'tripHides', 'siteHides',` after `'tripEquipment',`.
4. The type-to-table map (near line 1741): `'tripHides': 'trip_hides', 'siteHides': 'site_hides',`.
5. The export (near line 2297), after the `tripEquipment:` entry:

```dart
      tripHides: await _safeExport(
        'tripHides',
        () async => _withPendingChildren(
          'tripHides',
          await _exportTripHides(hlcSince),
          pendingChildren,
        ),
      ),
      siteHides: await _safeExport(
        'siteHides',
        () async => _withPendingChildren(
          'siteHides',
          await _exportSiteHides(hlcSince),
          pendingChildren,
        ),
      ),
```

6. `fetchRecord` switch (near line 2811):

```dart
      case 'tripHides':
        final row = await (_db.select(
          _db.tripHides,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'siteHides':
        final row = await (_db.select(
          _db.siteHides,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

7. Single-record apply helpers, after `_applyTripEquipmentRecord`:

```dart
  /// Applies one incoming `trip_hides` row (v250, issue #2594). The
  /// (trip, profile) pair is unique: a peer's copy under another id is
  /// reconciled to the lower id and then skipped, as
  /// [_applyTripEquipmentRecord] does.
  Future<void> _applyTripHideRecord(TripHideRow record) async {
    await _reconcileJunctionIds(
      'trip_hides',
      parentColumn: 'trip_id',
      childColumn: 'diver_id',
      pairs: [(parent: record.tripId, child: record.diverId, id: record.id)],
    );
    await _db
        .into(_db.tripHides)
        .insert(
          record,
          onConflict: DoNothing<$TripHidesTable, TripHideRow>(
            target: const [],
          ),
        );
  }

  /// As [_applyTripHideRecord], for `site_hides`.
  Future<void> _applySiteHideRecord(SiteHideRow record) async {
    await _reconcileJunctionIds(
      'site_hides',
      parentColumn: 'site_id',
      childColumn: 'diver_id',
      pairs: [(parent: record.siteId, child: record.diverId, id: record.id)],
    );
    await _db
        .into(_db.siteHides)
        .insert(
          record,
          onConflict: DoNothing<$SiteHidesTable, SiteHideRow>(
            target: const [],
          ),
        );
  }
```

and the single-record switch (near line 4315):

```dart
      case 'tripHides':
        await _applyTripHideRecord(TripHideRow.fromJson(data));
        return;
      case 'siteHides':
        await _applySiteHideRecord(SiteHideRow.fromJson(data));
        return;
```

8. The batch apply switch (near line 5481), after `case 'tripEquipment':`:

```dart
      case 'tripHides':
        // DoNothing: see [_applyTripHideRecord].
        final tripHideRows = _lowestIdPerPair(
          records.map((r) => TripHideRow.fromJson(r)).toList(),
          (row) => (parent: row.tripId, child: row.diverId, id: row.id),
        );
        await _reconcileJunctionIds(
          'trip_hides',
          parentColumn: 'trip_id',
          childColumn: 'diver_id',
          pairs: [
            for (final row in tripHideRows)
              (parent: row.tripId, child: row.diverId, id: row.id),
          ],
        );
        await _db.batch(
          (b) => b.insertAll(
            _db.tripHides,
            tripHideRows,
            onConflict: DoNothing<$TripHidesTable, TripHideRow>(
              target: const [],
            ),
          ),
        );
        return;
      case 'siteHides':
        // DoNothing: see [_applySiteHideRecord].
        final siteHideRows = _lowestIdPerPair(
          records.map((r) => SiteHideRow.fromJson(r)).toList(),
          (row) => (parent: row.siteId, child: row.diverId, id: row.id),
        );
        await _reconcileJunctionIds(
          'site_hides',
          parentColumn: 'site_id',
          childColumn: 'diver_id',
          pairs: [
            for (final row in siteHideRows)
              (parent: row.siteId, child: row.diverId, id: row.id),
          ],
        );
        await _db.batch(
          (b) => b.insertAll(
            _db.siteHides,
            siteHideRows,
            onConflict: DoNothing<$SiteHidesTable, SiteHideRow>(
              target: const [],
            ),
          ),
        );
        return;
```

9. The `plain(...)` switch (near line 6039): `case 'tripHides': return plain(_db.tripHides, _db.tripHides.id); case 'siteHides': return plain(_db.siteHides, _db.siteHides.id);`
10. The table lookup switch (near line 6443): `case 'tripHides': return _db.tripHides; case 'siteHides': return _db.siteHides;`
11. `deleteRecord` switch (near line 6921):

```dart
      case 'tripHides':
        await (_db.delete(
          _db.tripHides,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'siteHides':
        await (_db.delete(
          _db.siteHides,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

12. Export functions, after `_exportTripEquipment`:

```dart
  /// Hidden shared trips (v250, issue #2594), gated on the parent trip's
  /// clock like [_exportTripEquipment]. A hide travels on its own pending
  /// mark, never by re-stamping the trip.
  Future<List<Map<String, dynamic>>> _exportTripHides(String? hlcSince) async {
    if (hlcSince != null) {
      final trips = await (_db.select(
        _db.trips,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final tripIds = trips.map((t) => t.id).toSet();
      if (tripIds.isEmpty) return [];
      return _childRowsOf(
        tripIds,
        (chunk) => (_db.select(
          _db.tripHides,
        )..where((t) => t.tripId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.tripHides).get();
    return rows.map((r) => r.toJson()).toList();
  }

  /// As [_exportTripHides], for hidden shared sites.
  Future<List<Map<String, dynamic>>> _exportSiteHides(String? hlcSince) async {
    if (hlcSince != null) {
      final sites = await (_db.select(
        _db.diveSites,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final siteIds = sites.map((s) => s.id).toSet();
      if (siteIds.isEmpty) return [];
      return _childRowsOf(
        siteIds,
        (chunk) => (_db.select(
          _db.siteHides,
        )..where((t) => t.siteId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.siteHides).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- [ ] **Step 4: Wire `SyncRepository` and `SyncService`**

`sync_repository.dart`, entity map after `'tripEquipment'`:

```dart
    'tripHides': (table: 'trip_hides', pk: 'id'),
    'siteHides': (table: 'site_hides', pk: 'id'),
```

`sync_service.dart`, the apply-order list, directly after the `type: 'tripEquipment'` record:

```dart
          // After their parents (trips, sites and divers), issue #2594.
          (type: 'tripHides', records: data.tripHides, hasUpdatedAt: false),
          (type: 'siteHides', records: data.siteHides, hasUpdatedAt: false),
```

`entityHasUpdatedAt` (line 2505 map): `'tripHides': false, 'siteHides': false,`.
`parentRefs` (line 2678 map), after `'tripEquipment'`:

```dart
    // v250: a profile's hidden shared trips and sites (issue #2594).
    'tripHides': [
      (field: 'tripId', parent: 'trips', nullable: false),
      (field: 'diverId', parent: 'divers', nullable: false),
    ],
    'siteHides': [
      (field: 'siteId', parent: 'diveSites', nullable: false),
      (field: 'diverId', parent: 'divers', nullable: false),
    ],
```

- [ ] **Step 5: Extend the completeness guards**

- `sync_data_serializer_batch_coverage_test.dart` after line 153: `(type: 'tripHides', table: db.tripHides.actualTableName), (type: 'siteHides', table: db.siteHides.actualTableName),`
- `sync_parent_refs_completeness_test.dart` after line 107: `'trip_hides': 'tripHides', 'site_hides': 'siteHides',`
- `sync_serializer_fetch_record_test.dart` after line 138: `'tripHides', 'siteHides',`

- [ ] **Step 6: Run the sync tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS, including every completeness guard (they fail if any arm is missing, which is how they catch a half-wired type).

- [ ] **Step 7: Commit**

```bash
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/profile_hides_sync_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart
git commit -m "feat(sync): sync hidden shared trips and sites as parent-gated children

Refs #2594"
```

---

### Task 4: ProfileHidesRepository

**Files:**
- Create: `test/helpers/shared_items_fixture.dart`
- Create: `lib/features/divers/data/repositories/profile_hides_repository.dart`
- Modify: `test/architecture/repository_tick_stream_test.dart` (register `watchChanges`)
- Test: `test/features/divers/data/repositories/profile_hides_repository_test.dart`

**Interfaces:**
- Consumes: `SharedItemKind`, `canHideSharedItem` (Task 1); `db.tripHides`, `db.siteHides` (Task 2); entity types `tripHides` / `siteHides` (Task 3).
- Produces:
  - `class HiddenItem { SharedItemKind kind; String id; String name; String? ownerId; DateTime? startDate; DateTime? endDate; String? location; }`
  - `class ProfileHidesRepository` with `static const tripEntity = 'tripHides'`, `static const siteEntity = 'siteHides'`, and:
    - `Stream<void> watchChanges()`
    - `Future<bool> hide(SharedItemKind kind, String id, String diverId)`
    - `Future<void> unhide(SharedItemKind kind, String id, String diverId)`
    - `Future<List<HiddenItem>> hiddenItems(String diverId)`
    - `Future<void> deleteHides(SharedItemKind kind, List<String> ids, {String? diverId})` (runs inside the caller's transaction, notifies nothing)
    - `Future<({int mine, int others})> diveLinkCounts(SharedItemKind kind, String id, String? diverId)`
  - Fixture helpers: `kSharedTs`, `seedDivers`, `seedTrip`, `seedSite`, `seedDive`, `pendingCount`, `tombstoneCount`, `clearPendingMarks`.

- [ ] **Step 1: Write the shared fixture**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Rows for the shared trip and site tests (issue #2594): profiles, trips
/// and sites with an owner and a share flag, dives linked to them, and the
/// sync bookkeeping the tests read back.
const kSharedTs = 1700000000000;

Future<void> seedDivers(AppDatabase db, List<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
  }
}

Future<void> seedTrip(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.trips)
    .insert(
      TripsCompanion.insert(
        id: id,
        name: name ?? 'Trip $id',
        startDate: kSharedTs,
        endDate: kSharedTs,
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedSite(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: name ?? 'Site $id',
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedDive(
  AppDatabase db,
  String id, {
  required String diver,
  String? tripId,
  String? siteId,
}) => db
    .into(db.dives)
    .insert(
      DivesCompanion.insert(
        id: id,
        diverId: Value(diver),
        diveDateTime: kSharedTs,
        tripId: Value(tripId),
        siteId: Value(siteId),
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
      ),
    );

Future<void> clearPendingMarks(AppDatabase db) =>
    db.customStatement('DELETE FROM sync_records');

Future<int> pendingCount(
  AppDatabase db,
  String entityType,
  String recordId,
) async => (await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
          "AND record_id = ? AND sync_status = 'pending'",
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle())
    .read<int>('n');

Future<int> tombstoneCount(AppDatabase db, String entityType) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
              variables: [Variable<String>(entityType)],
            )
            .getSingle())
        .read<int>('n');
```

- [ ] **Step 2: Write the failing repository test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A profile's hidden shared trips and sites (issue #2594).
void main() {
  late AppDatabase db;
  late ProfileHidesRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = ProfileHidesRepository();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true, name: 'Bonaire');
    await seedTrip(db, 'private', owner: 'a');
    await seedSite(db, 'pier', owner: 'a', shared: true, name: 'Salt Pier');
  });

  tearDown(tearDownTestDatabase);

  test('another profile hides a shared trip, marked pending', () async {
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'b'), isTrue);
    final row = (await db.select(db.tripHides).get()).single;
    expect((row.tripId, row.diverId), ('shared', 'b'));
    expect(
      await pendingCount(db, ProfileHidesRepository.tripEntity, row.id),
      1,
    );
  });

  test('hiding twice keeps one row', () async {
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'b'), isTrue);
    expect(await db.select(db.tripHides).get(), hasLength(1));
  });

  test('the owner, an unshared trip and a missing trip are refused', () async {
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'a'), isFalse);
    expect(await repository.hide(SharedItemKind.trip, 'private', 'b'), isFalse);
    expect(await repository.hide(SharedItemKind.trip, 'nope', 'b'), isFalse);
    expect(await db.select(db.tripHides).get(), isEmpty);
  });

  test('unhide deletes and tombstones the row', () async {
    await repository.hide(SharedItemKind.site, 'pier', 'b');
    await repository.unhide(SharedItemKind.site, 'pier', 'b');
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });

  test('hiddenItems lists the profile\'s trips then sites', () async {
    await repository.hide(SharedItemKind.site, 'pier', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    final items = await repository.hiddenItems('b');
    expect(items.map((i) => (i.kind, i.id, i.name, i.ownerId)), [
      (SharedItemKind.trip, 'shared', 'Bonaire', 'a'),
      (SharedItemKind.site, 'pier', 'Salt Pier', 'a'),
    ]);
    expect(await repository.hiddenItems('a'), isEmpty);
  });

  test('deleteHides removes every profile\'s hides of an item', () async {
    await seedDivers(db, ['c']);
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'c');
    await db.transaction(
      () => repository.deleteHides(SharedItemKind.trip, ['shared']),
    );
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 2);
  });

  test('deleteHides with a diverId removes only that profile\'s', () async {
    await seedDivers(db, ['c']);
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'c');
    await db.transaction(
      () => repository.deleteHides(
        SharedItemKind.trip,
        ['shared'],
        diverId: 'c',
      ),
    );
    expect((await db.select(db.tripHides).get()).single.diverId, 'b');
  });

  test('diveLinkCounts splits the item\'s dives by profile', () async {
    await seedDive(db, 'a1', diver: 'a', tripId: 'shared', siteId: 'pier');
    await seedDive(db, 'b1', diver: 'b', tripId: 'shared');
    await seedDive(db, 'b2', diver: 'b', tripId: 'shared', siteId: 'pier');
    expect(
      await repository.diveLinkCounts(SharedItemKind.trip, 'shared', 'b'),
      (mine: 2, others: 1),
    );
    expect(
      await repository.diveLinkCounts(SharedItemKind.site, 'pier', 'a'),
      (mine: 1, others: 1),
    );
    expect(
      await repository.diveLinkCounts(SharedItemKind.site, 'none', 'a'),
      (mine: 0, others: 0),
    );
  });

  test('watchChanges emits on a hide', () async {
    final tick = repository.watchChanges().first.timeout(
      const Duration(seconds: 5),
    );
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await expectLater(tick, completes);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/divers/data/repositories/profile_hides_repository_test.dart`
Expected: FAIL, the repository file does not exist.

- [ ] **Step 4: Write the repository**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// A shared trip or dive site one profile has hidden from itself, for the
/// Settings list (issue #2594).
class HiddenItem {
  const HiddenItem({
    required this.kind,
    required this.id,
    required this.name,
    this.ownerId,
    this.startDate,
    this.endDate,
    this.location,
  });

  final SharedItemKind kind;
  final String id;
  final String name;
  final String? ownerId;

  /// A trip's dates; null for a site.
  final DateTime? startDate;
  final DateTime? endDate;

  /// A trip's location, or a site's region and country.
  final String? location;
}

typedef _HideTable = ({
  String table,
  String parentTable,
  String parentColumn,
  String entity,
});

/// The shared trips and sites each profile has hidden from itself (issue
/// #2594): the `trip_hides` and `site_hides` rows. A hide never changes
/// what any other profile sees. Parent-gated children of their trip or
/// site; writes never touch the parent row (#1769).
class ProfileHidesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();
  final _log = LoggerService.forClass(ProfileHidesRepository);

  static const String tripEntity = 'tripHides';
  static const String siteEntity = 'siteHides';

  static _HideTable _of(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => (
      table: 'trip_hides',
      parentTable: 'trips',
      parentColumn: 'trip_id',
      entity: tripEntity,
    ),
    SharedItemKind.site => (
      table: 'site_hides',
      parentTable: 'dive_sites',
      parentColumn: 'site_id',
      entity: siteEntity,
    ),
  };

  TableInfo<Table, dynamic> _tableOf(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => _db.tripHides,
    SharedItemKind.site => _db.siteHides,
  };

  /// Emits when a hide is written or removed, or a hidden item's own row
  /// changes (its name, or its deletion).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripHides),
      TableUpdateQuery.onTable(_db.siteHides),
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );

  /// Hides item [id] from [diverId]. True when it is hidden afterwards,
  /// including when it already was. False, writing nothing, when
  /// [canHideSharedItem] refuses (the owner, an unshared or ownerless
  /// item) or the item does not exist.
  Future<bool> hide(SharedItemKind kind, String id, String diverId) async {
    final t = _of(kind);
    try {
      final parent = await _db
          .customSelect(
            'SELECT diver_id, is_shared FROM ${t.parentTable} WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (parent == null ||
          !canHideSharedItem(
            ownerId: parent.read<String?>('diver_id'),
            isShared: parent.read<int>('is_shared') != 0,
            activeDiverId: diverId,
          )) {
        _log.warning('Refused to hide ${t.parentTable} $id for $diverId');
        return false;
      }
      final added = await _db.transaction(() async {
        if ((await _hideIds(t, [id], diverId: diverId)).isNotEmpty) {
          return false;
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final hideId = _uuid.v4();
        await _db.customInsert(
          'INSERT INTO ${t.table} (id, ${t.parentColumn}, diver_id, '
          'created_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(hideId),
            Variable.withString(id),
            Variable.withString(diverId),
            Variable.withInt(now),
          ],
          updates: {_tableOf(kind)},
        );
        await _syncRepository.markRecordPending(
          entityType: t.entity,
          recordId: hideId,
          localUpdatedAt: now,
        );
        return true;
      });
      if (added) SyncEventBus.notifyLocalChange();
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to hide ${t.parentTable} $id for $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Shows item [id] to [diverId] again: deletes and tombstones the hide.
  Future<void> unhide(SharedItemKind kind, String id, String diverId) async {
    try {
      await _db.transaction(() => deleteHides(kind, [id], diverId: diverId));
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unhide ${_of(kind).parentTable} $id for $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// [diverId]'s hidden trips (newest first), then sites (by name).
  Future<List<HiddenItem>> hiddenItems(String diverId) async {
    final trips = await _db
        .customSelect(
          'SELECT t.id, t.name, t.diver_id, t.start_date, t.end_date, '
          't.location FROM trip_hides h JOIN trips t ON t.id = h.trip_id '
          'WHERE h.diver_id = ? ORDER BY t.start_date DESC',
          variables: [Variable.withString(diverId)],
        )
        .get();
    final sites = await _db
        .customSelect(
          'SELECT s.id, s.name, s.diver_id, s.region, s.country '
          'FROM site_hides h JOIN dive_sites s ON s.id = h.site_id '
          'WHERE h.diver_id = ? ORDER BY s.name COLLATE NOCASE',
          variables: [Variable.withString(diverId)],
        )
        .get();
    DateTime? date(int? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    return [
      for (final r in trips)
        HiddenItem(
          kind: SharedItemKind.trip,
          id: r.read<String>('id'),
          name: r.read<String>('name'),
          ownerId: r.read<String?>('diver_id'),
          startDate: date(r.read<int?>('start_date')),
          endDate: date(r.read<int?>('end_date')),
          location: r.read<String?>('location'),
        ),
      for (final r in sites)
        HiddenItem(
          kind: SharedItemKind.site,
          id: r.read<String>('id'),
          name: r.read<String>('name'),
          ownerId: r.read<String?>('diver_id'),
          location: [
            r.read<String?>('region'),
            r.read<String?>('country'),
          ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        ),
    ];
  }

  /// Deletes and tombstones the hides of items [ids]: every profile's, or
  /// only [diverId]'s. Runs inside the caller's transaction and notifies
  /// nothing. A cascade from the parent writes no tombstone, so a trip or
  /// site delete calls this first and every peer drops the hides too.
  Future<void> deleteHides(
    SharedItemKind kind,
    List<String> ids, {
    String? diverId,
  }) async {
    if (ids.isEmpty) return;
    final t = _of(kind);
    final hideIds = await _hideIds(t, ids, diverId: diverId);
    if (hideIds.isEmpty) return;
    await _db.customUpdate(
      'DELETE FROM ${t.table} WHERE id IN '
      '(${List.filled(hideIds.length, '?').join(', ')})',
      variables: [for (final id in hideIds) Variable.withString(id)],
      updates: {_tableOf(kind)},
      updateKind: UpdateKind.delete,
    );
    await _syncRepository.logDeletions(
      entityType: t.entity,
      recordIds: hideIds,
    );
  }

  /// The dives linked to item [id]: those [diverId] logged, and those every
  /// other profile logged. For the delete and remove confirmations.
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async {
    final column = kind == SharedItemKind.trip ? 'trip_id' : 'site_id';
    final row = await _db
        .customSelect(
          // stats-scope-exempt: counts every dive a delete would unlink,
          // excluded ones included.
          'SELECT '
          'COALESCE(SUM(CASE WHEN diver_id IS ? THEN 1 ELSE 0 END), 0) '
          'AS mine, '
          'COALESCE(SUM(CASE WHEN diver_id IS ? THEN 0 ELSE 1 END), 0) '
          'AS others '
          'FROM dives WHERE $column = ?',
          variables: [
            Variable<String>(diverId),
            Variable<String>(diverId),
            Variable.withString(id),
          ],
        )
        .getSingle();
    return (mine: row.read<int>('mine'), others: row.read<int>('others'));
  }

  Future<List<String>> _hideIds(
    _HideTable t,
    List<String> ids, {
    String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM ${t.table} WHERE ${t.parentColumn} IN '
          '(${List.filled(ids.length, '?').join(', ')})'
          '${diverId == null ? '' : ' AND diver_id = ?'}',
          variables: [
            for (final id in ids) Variable.withString(id),
            if (diverId != null) Variable.withString(diverId),
          ],
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }
}
```

- [ ] **Step 5: Register the tick stream**

In `test/architecture/repository_tick_stream_test.dart`, next to the `TripEquipmentRepository.watchChanges` entry, add the import and:

```dart
      'ProfileHidesRepository.watchChanges': () =>
          ProfileHidesRepository().watchChanges(),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/divers/data/repositories/profile_hides_repository_test.dart test/architecture/repository_tick_stream_test.dart`
Expected: PASS. If a `stats-scope` architecture guard flags `diveLinkCounts`, move the `stats-scope-exempt` comment to the exact form the guard reads (see `_clearDiveLinks` in `dive_parent_links.dart`).

- [ ] **Step 7: Commit**

```bash
git add test/helpers/shared_items_fixture.dart lib/features/divers/data/repositories/profile_hides_repository.dart test/features/divers/data/repositories/profile_hides_repository_test.dart test/architecture/repository_tick_stream_test.dart
git commit -m "feat(sharing): a repository for a profile's hidden shared trips and sites

Refs #2594"
```

---

### Task 5: Hidden items leave every list

**Files:**
- Modify: `lib/core/data/visibility/visibility_filter.dart`
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (lines 46, 76, 618, 653; `watchTripsChanges`)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (lines 92, 1022; `watchSitesChanges`)
- Modify: `lib/features/site_types/data/repositories/site_type_repository.dart:185`
- Modify: `lib/features/query/data/query_name_index.dart` (`tables`, `load`)
- Modify: `test/core/data/visibility/visibility_filter_test.dart` (new signatures)
- Test: `test/features/trips/data/repositories/trip_hidden_visibility_test.dart`, `test/features/dive_sites/data/repositories/site_hidden_visibility_test.dart`, `test/features/query/data/query_name_index_test.dart` (add a case)

**Interfaces:**
- Consumes: `SharedItemKind` (Task 1), `ProfileHidesRepository.hide` (Task 4, tests only), fixture helpers (Task 4).
- Produces (changed signatures):
  - `VisibilityFilter.applyToTrips(AppDatabase db, SimpleSelectStatement<$TripsTable, Trip> query, String? diverId)`
  - `VisibilityFilter.applyToDiveSites(AppDatabase db, SimpleSelectStatement<$DiveSitesTable, DiveSite> query, String? diverId)`
  - `VisibilityFilter.sqlFragment({required String tableAlias, required String? diverId, required String conjunction, required SharedItemKind kind})`

- [ ] **Step 1: Write the failing trip visibility test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A trip one profile hides leaves that profile's lists only (issue #2594).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    await seedDivers(db, ['a', 'b', 'c']);
    await seedTrip(db, 'shared', owner: 'a', shared: true, name: 'Bonaire');
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> visibleTo(String diverId) async => [
    for (final t in await trips.getAllTrips(diverId: diverId)) t.id,
  ];

  test('getAllTrips hides it from b, not from a or c', () async {
    expect(await visibleTo('b'), isEmpty);
    expect(await visibleTo('a'), ['shared']);
    expect(await visibleTo('c'), ['shared']);
  });

  test('getAllTripsWithStats, search and findTripForDate hide it from b',
      () async {
    expect(await trips.getAllTripsWithStats(diverId: 'b'), isEmpty);
    expect(await trips.searchTrips('bon', diverId: 'b'), isEmpty);
    final date = DateTime.fromMillisecondsSinceEpoch(kSharedTs);
    expect(await trips.findTripForDate(date, diverId: 'b'), isNull);
    expect((await trips.findTripForDate(date, diverId: 'c'))?.id, 'shared');
  });

  test('a lookup by id still finds it', () async {
    expect((await trips.getTripById('shared'))?.name, 'Bonaire');
  });

  test('watchTripsChanges ticks on a hide', () async {
    await seedTrip(db, 'other', owner: 'a', shared: true);
    final tick = trips.watchTripsChanges().first.timeout(
      const Duration(seconds: 5),
    );
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'other', 'b');
    await expectLater(tick, completes);
  });
}
```

Write `site_hidden_visibility_test.dart` the same way over `SiteRepository` (`getAllSites(diverId:)`, `searchSites(query, diverId:)`, `getSiteById`, `watchSitesChanges`) with `seedSite(db, 'pier', owner: 'a', shared: true, name: 'Salt Pier')` and `hide(SharedItemKind.site, 'pier', 'b')`, plus a `SiteTypeRepository().getSiteTypeStatistics(diverId: 'b')` check that a hidden site tagged with a type (insert a `site_site_types` row for a built-in type) is not counted for `b` but is for `c`.

In `test/features/query/data/query_name_index_test.dart`, add a case: seed divers `a`,`b`, a shared trip owned by `a`, hide it for `b`, then `load(diverId: 'b')` has no trip ref value for it and `load(diverId: 'a')` does. Follow the file's existing setup for building the index.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/data/repositories/trip_hidden_visibility_test.dart test/features/dive_sites/data/repositories/site_hidden_visibility_test.dart test/features/query/data/query_name_index_test.dart`
Expected: FAIL (the hidden trip is still listed for `b`).

- [ ] **Step 3: Change the filter**

Replace `applyToTrips`, `applyToDiveSites` and `sqlFragment` in `visibility_filter.dart`, and update the class doc comment's first sentence to mention hides:

```dart
  /// Applies `(diver_id = diverId OR is_shared = true) AND id NOT IN
  /// (diverId's hidden trips)` to a Drift select on the `trips` table
  /// (issue #2594).
  static void applyToTrips(
    AppDatabase db,
    SimpleSelectStatement<$TripsTable, Trip> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    final hides = db.tripHides;
    query.where(
      (t) =>
          (t.diverId.equals(diverId) | t.isShared.equals(true)) &
          t.id.isNotInQuery(
            db.selectOnly(hides)
              ..addColumns([hides.tripId])
              ..where(hides.diverId.equals(diverId)),
          ),
    );
  }

  /// As [applyToTrips], on the `dive_sites` table.
  static void applyToDiveSites(
    AppDatabase db,
    SimpleSelectStatement<$DiveSitesTable, DiveSite> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    final hides = db.siteHides;
    query.where(
      (t) =>
          (t.diverId.equals(diverId) | t.isShared.equals(true)) &
          t.id.isNotInQuery(
            db.selectOnly(hides)
              ..addColumns([hides.siteId])
              ..where(hides.diverId.equals(diverId)),
          ),
    );
  }
```

```dart
  /// Returns a SQL fragment and its variables for raw-SQL composition:
  /// owner-or-shared, minus the items [diverId] has hidden (issue #2594).
  ///
  /// * `tableAlias` qualifies the column names (e.g. `"t"` in
  ///   `FROM trips t`, or `"trips"` when the table is unaliased).
  /// * `conjunction` is `"AND"` when other WHERE clauses precede this
  ///   fragment, or `"WHERE"` when this is the first predicate.
  /// * `kind` names the hides table to exclude.
  ///
  /// When `diverId` is `null`, the fragment is empty (no text, no vars),
  /// so callers can concatenate unconditionally.
  static SqlFragment sqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
    required SharedItemKind kind,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    final (hides, column) = switch (kind) {
      SharedItemKind.trip => ('trip_hides', 'trip_id'),
      SharedItemKind.site => ('site_hides', 'site_id'),
    };
    final clause =
        ' $conjunction ($tableAlias.diver_id = ? OR $tableAlias.is_shared = 1)'
        ' AND $tableAlias.id NOT IN '
        '(SELECT $column FROM $hides WHERE diver_id = ?)';
    return SqlFragment(
      whereClause: clause,
      variables: [Variable.withString(diverId), Variable.withString(diverId)],
    );
  }
```

Add `import 'package:submersion/core/data/visibility/shared_item_policy.dart';`.

- [ ] **Step 4: Update every caller**

- `trip_repository.dart:46`: `VisibilityFilter.applyToTrips(_db, query, diverId);`
- `trip_repository.dart:76, 618, 653`: add `kind: SharedItemKind.trip,` to each `sqlFragment` call.
- `site_repository_impl.dart:92, 1022`: `VisibilityFilter.applyToDiveSites(_db, query, diverId);` / `(_db, searchQuery, diverId)`.
- `site_type_repository.dart:185`: add `kind: SharedItemKind.site,`.
- Add the `shared_item_policy.dart` import where needed.
- `visibility_filter_test.dart`: pass `db` first and `kind:` in each call; its expected SQL text and variable counts change accordingly (two variables now).

- [ ] **Step 5: Tick the lists on hide writes**

`trip_repository.dart`:

```dart
  /// Emits whenever the `trips` table, or a profile's hidden trips, change,
  /// so list providers refresh after a sync or any other write (a hide
  /// changes which trips a profile sees, issue #2594).
  Stream<void> watchTripsChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.tripHides),
    ]),
  );
```

`site_repository_impl.dart`, the same for `watchSitesChanges` over `_db.diveSites` and `_db.siteHides`.

- [ ] **Step 6: Exclude hidden rows from the query-language name index**

In `query_name_index.dart`, `tables`: add `'trip_hides', 'site_hides',` after `'equipment_shares',`. In `load`, replace the line `final where = visible.isEmpty ? '' : 'WHERE ${visible.join(' OR ')}';` with:

```dart
      // A profile's hidden shared trips and sites (issue #2594) leave its
      // name completion, as they leave its lists.
      final hides = diverId == null
          ? null
          : switch (subject) {
              QuerySubject.trips => (table: 'trip_hides', column: 'trip_id'),
              QuerySubject.sites => (table: 'site_hides', column: 'site_id'),
              _ => null,
            };
      if (hides != null) variables.add(Variable<String>(diverId));
      final clauses = [
        if (visible.isNotEmpty) '(${visible.join(' OR ')})',
        if (hides != null)
          't.${entity.idColumn} NOT IN '
              '(SELECT ${hides.column} FROM ${hides.table} WHERE diver_id = ?)',
      ];
      final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
```

Update the doc comment above `load` to say hidden items are excluded.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/trips/data/repositories/ test/features/dive_sites/data/repositories/ test/features/site_types/ test/features/query/ test/core/data/visibility/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/data/visibility/visibility_filter.dart lib/features/trips/data/repositories/trip_repository.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart lib/features/site_types/data/repositories/site_type_repository.dart lib/features/query/data/query_name_index.dart test/core/data/visibility/visibility_filter_test.dart test/features/trips/data/repositories/trip_hidden_visibility_test.dart test/features/dive_sites/data/repositories/site_hidden_visibility_test.dart test/features/query/data/query_name_index_test.dart
git commit -m "feat(sharing): a profile's hidden trips and sites leave its lists

Refs #2594"
```

---

### Task 6: Trip repository enforces ownership, and trip deletes reach peers

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_parent_links.dart` (add `clearDiveTripLinks`)
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`deleteTrip`, `updateTrip`, `setShared`)
- Test: `test/features/trips/data/repositories/trip_ownership_test.dart`
- Regenerate: `test/features/dive_import/data/services/uddf_entity_importer_test.mocks.dart` (Mockito mock of `TripRepository`)

**Interfaces:**
- Consumes: `canDestroySharedItem`, `SharedItemKind` (Task 1); `ProfileHidesRepository.deleteHides` (Task 4).
- Produces:
  - `Future<void> clearDiveTripLinks(AppDatabase db, SyncRepository syncRepository, List<String> tripIds, {required int now})`
  - `Future<bool> TripRepository.deleteTrip(String id, {String? actingDiverId})`
  - `Future<void> TripRepository.updateTrip(domain.Trip trip, {String? actingDiverId})`
  - `Future<bool> TripRepository.setShared(String id, bool isShared, {String? actingDiverId})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Only a shared trip's owner destroys or re-shares it (issue #2594).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true);
    await seedDive(db, 'a1', diver: 'a', tripId: 'shared');
    await seedDive(db, 'b1', diver: 'b', tripId: 'shared');
  });

  tearDown(tearDownTestDatabase);

  Future<String?> tripOf(String diveId) async =>
      (await (db.select(db.dives)..where((d) => d.id.equals(diveId)))
              .getSingle())
          .tripId;

  test('a non-owner cannot delete it; nothing changes', () async {
    expect(await trips.deleteTrip('shared', actingDiverId: 'b'), isFalse);
    expect(await trips.getTripById('shared'), isNotNull);
    expect(await tripOf('a1'), 'shared');
    expect(await tripOf('b1'), 'shared');
  });

  test('the owner deletes it; every dive is unlinked, stamped and pending',
      () async {
    await clearPendingMarks(db);
    expect(await trips.deleteTrip('shared', actingDiverId: 'a'), isTrue);
    expect(await trips.getTripById('shared'), isNull);
    for (final dive in ['a1', 'b1']) {
      expect(await tripOf(dive), isNull);
      expect(await pendingCount(db, 'dives', dive), 1, reason: dive);
    }
  });

  test('the owner\'s delete tombstones every profile\'s hide', () async {
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');
    await trips.deleteTrip('shared', actingDiverId: 'a');
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 1);
  });

  test('an ownerless trip is deleted by anyone', () async {
    await seedTrip(db, 'legacy', shared: true);
    expect(await trips.deleteTrip('legacy', actingDiverId: 'b'), isTrue);
  });

  test('a caller naming no profile deletes as before', () async {
    expect(await trips.deleteTrip('shared'), isTrue);
  });

  test('a missing trip reports false', () async {
    expect(await trips.deleteTrip('nope', actingDiverId: 'a'), isFalse);
  });

  test('a non-owner\'s save cannot unshare it but still edits it', () async {
    final trip = (await trips.getTripById('shared'))!;
    await trips.updateTrip(
      trip.copyWith(name: 'Renamed', isShared: false),
      actingDiverId: 'b',
    );
    final saved = (await trips.getTripById('shared'))!;
    expect(saved.name, 'Renamed');
    expect(saved.isShared, isTrue);
    expect(saved.diverId, 'a');
  });

  test('the owner\'s save unshares it', () async {
    final trip = (await trips.getTripById('shared'))!;
    await trips.updateTrip(trip.copyWith(isShared: false), actingDiverId: 'a');
    expect((await trips.getTripById('shared'))!.isShared, isFalse);
  });

  test('setShared refuses a non-owner', () async {
    expect(
      await trips.setShared('shared', false, actingDiverId: 'b'),
      isFalse,
    );
    expect((await trips.getTripById('shared'))!.isShared, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_ownership_test.dart`
Expected: FAIL (compile error: no `actingDiverId` parameter).

- [ ] **Step 3: Add `clearDiveTripLinks`**

In `dive_parent_links.dart`, after `clearDiveSiteLinks`, and extend the file's top comment with "and `dives.trip_id`":

```dart
/// Clears the trip of the dives logged on [tripIds], every profile's,
/// stamping and marking each dive so the change reaches peers (issue
/// #2594: the trip delete used to clear them unstamped, so peers kept the
/// link). Run it inside the caller's transaction, before the trips are
/// deleted.
Future<void> clearDiveTripLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> tripIds, {
  required int now,
}) => _clearDiveLinks(db, syncRepository, 'trip_id', tripIds, now: now);
```

- [ ] **Step 4: Guard the trip repository**

Replace `deleteTrip` (keep its doc paragraph about the single transaction and add the ownership sentence):

```dart
  /// Delete a trip and all associated child records, when [actingDiverId]
  /// may (issue #2594): its owner, anyone for an ownerless trip, and any
  /// caller that names no profile. Returns false, with nothing changed, for
  /// a trip another profile owns or one that does not exist.
  ///
  /// Every profile's dives keep their data and lose the trip, stamped and
  /// marked pending; every profile's hide of the trip is tombstoned.
  ///
  /// (keep the existing paragraph about the one transaction here)
  // stats-scope-exempt: deletion cascade
  Future<bool> deleteTrip(String id, {String? actingDiverId}) async {
    try {
      final row = await (_db.select(
        _db.trips,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return false;
      if (!canDestroySharedItem(
        ownerId: row.diverId,
        activeDiverId: actingDiverId,
      )) {
        _log.warning('Refused to delete trip $id: another profile owns it');
        return false;
      }
      _log.info('Deleting trip: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // Delete child records with non-nullable FKs first
        await LiveaboardDetailsRepository().deleteByTripId(id);
        await _itineraryDays.deleteByTripId(id);
        await TripChecklistRepository().deleteByTripId(id);
        await TripDayWeatherRepository().deleteByTripId(id);
        // Slots, their ledger and the links on the tanks that used them.
        await TripCylinderRepository().deleteByTripId(id);
        // Packed gear (issue #2338): deleted and tombstoned before the trip.
        await TripEquipmentRepository().deleteByTripId(id);
        // Every profile's hide of the trip (issue #2594), tombstoned.
        await ProfileHidesRepository().deleteHides(SharedItemKind.trip, [id]);
        // Every profile's dives lose the trip, stamped and marked pending.
        await clearDiveTripLinks(_db, _syncRepository, [id], now: now);

        // Delete the trip
        await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(entityType: 'trips', recordId: id);
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Deleted trip: $id');
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete trip: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `updateTrip`, change the signature to `Future<void> updateTrip(domain.Trip trip, {String? actingDiverId}) async {`, read the stored row right after `final now = ...`:

```dart
      // Only the owner changes sharing (issue #2594): another profile's save
      // keeps the stored flag, whatever its page state says.
      final stored = await (_db.select(
        _db.trips,
      )..where((t) => t.id.equals(trip.id))).getSingleOrNull();
      final maySetSharing =
          stored == null ||
          canDestroySharedItem(
            ownerId: stored.diverId,
            activeDiverId: actingDiverId,
          );
```

and replace `isShared: Value(trip.isShared),` with `isShared: maySetSharing ? Value(trip.isShared) : const Value.absent(),`.

Replace `setShared`:

```dart
  /// Flip the shared state of a single trip, when [actingDiverId] may
  /// (issue #2594). Returns false, with nothing changed, for a trip another
  /// profile owns or one that does not exist. Marks it pending for sync.
  Future<bool> setShared(
    String id,
    bool isShared, {
    String? actingDiverId,
  }) async {
    try {
      final row = await (_db.select(
        _db.trips,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null ||
          !canDestroySharedItem(
            ownerId: row.diverId,
            activeDiverId: actingDiverId,
          )) {
        return false;
      }
      _log.info('Setting trip $id isShared=$isShared');
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
        TripsCompanion(isShared: Value(isShared), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set shared flag on trip $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Add imports: `shared_item_policy.dart`, `profile_hides_repository.dart`, `dive_parent_links.dart`. `dive_mirror_service.dart:253,262` keeps calling `setShared` without `actingDiverId` (the mirror acts for the library, not a profile) and ignores the result.

- [ ] **Step 5: Regenerate the Mockito mocks, then run the tests**

Run: `bash $SCRATCH/codegen.sh`, then
`flutter test test/features/trips/ test/features/dive_import/ test/features/dive_log/data/`
Expected: PASS. Existing `trip_repository_test` delete cases still pass (`deleteTrip(id)` with no profile deletes as before).

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_parent_links.dart lib/features/trips/data/repositories/trip_repository.dart test/features/trips/data/repositories/trip_ownership_test.dart test/features/dive_import/data/services/uddf_entity_importer_test.mocks.dart
git commit -m "fix(trips): only a shared trip's owner deletes or unshares it

A trip delete now stamps and marks the dives it unlinks, so peers drop
the link too.

Refs #2594"
```

---

### Task 7: Site repository enforces ownership

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (`deleteSite`, `bulkDeleteSites`, `_deleteSiteRows`, `mergeSites`, `updateSite` / `_writeSiteUpdate`, `setShared`)
- Test: `test/features/dive_sites/data/repositories/site_ownership_test.dart`
- Regenerate: every `*.mocks.dart` that mocks `SiteRepository` (the five listed by `grep -rl "Future<void> deleteSite" test`)

**Interfaces:**
- Consumes: `canDestroySharedItem`, `SharedItemKind` (Task 1); `ProfileHidesRepository.deleteHides` (Task 4).
- Produces:
  - `Future<bool> SiteRepository.deleteSite(String id, {bool cascadeMedia = true, String? actingDiverId})`
  - `Future<SiteLinks> SiteRepository.bulkDeleteSites(List<String> ids, {bool cascadeMedia = true, String? actingDiverId})` (skips ids the profile may not destroy)
  - `Future<MergeSnapshot?> SiteRepository.mergeSites({required domain.DiveSite mergedSite, required List<String> siteIds, String? actingDiverId})` (returns null, changing nothing, when a duplicate is another profile's)
  - `Future<void> SiteRepository.updateSite(domain.DiveSite site, {SiteClassification? classification, String? actingDiverId})`
  - `Future<bool> SiteRepository.setShared(String id, bool isShared, {String? actingDiverId})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Only a shared site's owner destroys, merges away or re-shares it
/// (issue #2594).
void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    await seedDivers(db, ['a', 'b']);
    await seedSite(db, 'theirs', owner: 'a', shared: true);
    await seedSite(db, 'mine', owner: 'b', shared: true);
    await seedDive(db, 'b1', diver: 'b', siteId: 'theirs');
  });

  tearDown(tearDownTestDatabase);

  test('a non-owner cannot delete it', () async {
    expect(await sites.deleteSite('theirs', actingDiverId: 'b'), isFalse);
    expect(await sites.getSiteById('theirs'), isNotNull);
  });

  test('the owner deletes it and every profile\'s hide', () async {
    await ProfileHidesRepository().hide(SharedItemKind.site, 'theirs', 'b');
    expect(await sites.deleteSite('theirs', actingDiverId: 'a'), isTrue);
    expect(await sites.getSiteById('theirs'), isNull);
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });

  test('bulk delete skips another profile\'s sites', () async {
    await sites.bulkDeleteSites(['theirs', 'mine'], actingDiverId: 'b');
    expect(await sites.getSiteById('theirs'), isNotNull);
    expect(await sites.getSiteById('mine'), isNull);
  });

  test('merge refuses another profile\'s duplicate', () async {
    final survivor = (await sites.getSiteById('mine'))!;
    final snapshot = await sites.mergeSites(
      mergedSite: survivor,
      siteIds: ['mine', 'theirs'],
      actingDiverId: 'b',
    );
    expect(snapshot, isNull);
    expect(await sites.getSiteById('theirs'), isNotNull);
  });

  test('merge keeps another profile\'s survivor, owner and sharing',
      () async {
    final survivor = (await sites.getSiteById('theirs'))!;
    final snapshot = await sites.mergeSites(
      mergedSite: survivor.copyWith(isShared: false, diverId: 'b'),
      siteIds: ['theirs', 'mine'],
      actingDiverId: 'b',
    );
    expect(snapshot, isNotNull);
    expect(await sites.getSiteById('mine'), isNull);
    final kept = (await sites.getSiteById('theirs'))!;
    expect((kept.diverId, kept.isShared), ('a', true));
  });

  test('a non-owner\'s save cannot unshare it', () async {
    final site = (await sites.getSiteById('theirs'))!;
    await sites.updateSite(
      site.copyWith(name: 'Renamed', isShared: false),
      actingDiverId: 'b',
    );
    final saved = (await sites.getSiteById('theirs'))!;
    expect((saved.name, saved.isShared), ('Renamed', true));
  });

  test('setShared refuses a non-owner', () async {
    expect(
      await sites.setShared('theirs', false, actingDiverId: 'b'),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/data/repositories/site_ownership_test.dart`
Expected: FAIL (compile error: no `actingDiverId`).

- [ ] **Step 3: Add the ownership helper**

In `SiteRepository`, next to `_deleteSiteRows`:

```dart
  /// Which of [ids] [actingDiverId] may destroy (issue #2594): its own,
  /// ownerless ones, and all of them for a caller that names no profile.
  Future<List<String>> _destroyableSiteIds(
    List<String> ids,
    String? actingDiverId,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.isIn(ids))).get();
    final owners = {for (final r in rows) r.id: r.diverId};
    return [
      for (final id in ids)
        if (owners.containsKey(id) &&
            canDestroySharedItem(
              ownerId: owners[id],
              activeDiverId: actingDiverId,
            ))
          id,
    ];
  }
```

- [ ] **Step 4: Guard delete, bulk delete, merge, update and setShared**

- `_deleteSiteRows`: inside the transaction, before `await (_db.delete(_db.diveSites)...`, add:

```dart
      // Every profile's hide of the sites (issue #2594), tombstoned.
      await ProfileHidesRepository().deleteHides(SharedItemKind.site, ids);
```

- `deleteSite`: new signature `Future<bool> deleteSite(String id, {bool cascadeMedia = true, String? actingDiverId})`; before logging, `if ((await _destroyableSiteIds([id], actingDiverId)).isEmpty) { _log.warning('Refused to delete site $id: another profile owns it'); return false; }`; `return true;` after the notify. Add to its doc: "Returns false, with nothing changed, for a site another profile owns or one that does not exist (issue #2594)."
- `bulkDeleteSites`: add `String? actingDiverId`; first line of the body after the empty check: `final allowed = await _destroyableSiteIds(ids, actingDiverId); if (allowed.length < ids.length) { _log.warning('Bulk delete skipped ${ids.length - allowed.length} sites another profile owns'); } if (allowed.isEmpty) return const SiteLinks();` and use `allowed` for the rest.
- `mergeSites`: add `String? actingDiverId`. Right after `final duplicateIds = ...`:

```dart
    // Only sites the profile may destroy are merged away (issue #2594); a
    // survivor another profile owns keeps its owner and sharing.
    final destroyable = await _destroyableSiteIds(duplicateIds, actingDiverId);
    if (destroyable.length != duplicateIds.length) {
      _log.warning('Refused to merge away sites another profile owns');
      return null;
    }
```

  After `originalSurvivor` is read, replace the use of `survivorSite` in `_updateSiteRow(survivorSite, now)` with `guardedSurvivor`:

```dart
      final guardedSurvivor =
          canDestroySharedItem(
            ownerId: originalSurvivor.diverId,
            activeDiverId: actingDiverId,
          )
          ? survivorSite
          : survivorSite.copyWith(
              diverId: originalSurvivor.diverId,
              isShared: originalSurvivor.isShared,
            );
```

  Inside the merge transaction, before the `for (final duplicateId in duplicateIds)` delete loop: `await ProfileHidesRepository().deleteHides(SharedItemKind.site, duplicateIds);`.
- `updateSite`: add `String? actingDiverId` and pass it to `_writeSiteUpdate(site, classification: classification, actingDiverId: actingDiverId)`. In `_writeSiteUpdate` add the parameter and, after the `metadataPatch` block:

```dart
      // Only the owner changes sharing (issue #2594).
      if ((await _destroyableSiteIds([site.id], actingDiverId)).isEmpty &&
          await getSiteById(site.id) != null) {
        companion = companion.copyWith(isShared: const Value.absent());
      }
```

- `setShared`: same shape as the trip version in Task 6 over `_db.diveSites` / `DiveSitesCompanion` / `'diveSites'`, returning `Future<bool>`.

Add imports: `shared_item_policy.dart`, `profile_hides_repository.dart`.

- [ ] **Step 5: Regenerate mocks, run the tests**

Run: `bash $SCRATCH/codegen.sh`, then `flutter test test/features/dive_sites/ test/features/dive_import/ test/features/import_wizard/ test/features/site_types/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart test/features/dive_sites/data/repositories/site_ownership_test.dart
git add $(git diff --name-only -- '*.mocks.dart')
git commit -m "fix(sites): only a shared site's owner deletes, merges away or unshares it

Refs #2594"
```

---

### Task 8: Diver delete cleans up hides

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (`diverTripAndSiteSteps`)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (`deleteDiverWithReassignment`, Step 0)
- Modify: `test/features/divers/data/repositories/diver_delete_tombstones_test.dart`
- Test: `test/features/divers/data/repositories/diver_reassignment_hides_test.dart`

**Interfaces:**
- Consumes: `ProfileHidesRepository.deleteHides`, `SharedItemKind` (Tasks 1, 4), fixture helpers.

- [ ] **Step 1: Write the failing tests**

In `diver_delete_tombstones_test.dart`, next to the `trip_equipment` seed (search `pack-a`), seed a second diver `other` if the file does not already have one, a shared trip and site owned by `other`, and hides by the deleted diver:

```dart
      // The diver's hides of another profile's shared items (issue #2594).
      await db
          .into(db.tripHides)
          .insert(
            TripHidesCompanion.insert(
              id: 'hide-t',
              tripId: 'other-trip',
              diverId: diverId,
              createdAt: stale,
            ),
          );
      await db
          .into(db.siteHides)
          .insert(
            SiteHidesCompanion.insert(
              id: 'hide-s',
              siteId: 'other-site',
              diverId: diverId,
              createdAt: stale,
            ),
          );
```

and add `('trip_hides', 'tripHides', 'hide-t'), ('site_hides', 'siteHides', 'hide-s'),` to the expected tombstones list. Match the file's own names for the diver id variable and the timestamp.

New test `diver_reassignment_hides_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Deleting a profile hands its shared trips and sites to a survivor; the
/// survivor's own hides of them go, or it would own items it cannot see
/// (issue #2594).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['heir', 'leaving']);
    await db.customStatement(
      "UPDATE divers SET is_default = 1 WHERE id = 'heir'",
    );
    await seedTrip(db, 'shared', owner: 'leaving', shared: true);
    await seedSite(db, 'pier', owner: 'leaving', shared: true);
    final hides = ProfileHidesRepository();
    await hides.hide(SharedItemKind.trip, 'shared', 'heir');
    await hides.hide(SharedItemKind.site, 'pier', 'heir');
  });

  tearDown(tearDownTestDatabase);

  test('the new owner\'s hides of reassigned items are tombstoned', () async {
    await DiverRepository().deleteDiverWithReassignment('leaving');
    final trip = await (db.select(
      db.trips,
    )..where((t) => t.id.equals('shared'))).getSingle();
    expect(trip.diverId, 'heir');
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 1);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divers/data/repositories/diver_delete_tombstones_test.dart test/features/divers/data/repositories/diver_reassignment_hides_test.dart`
Expected: FAIL (hides cascade without tombstones; reassignment leaves the heir's hides).

- [ ] **Step 3: Add the delete steps**

In `diverTripAndSiteSteps`, directly before `(table: 'trips', ...)`:

```dart
  // The diver's own hides, and every profile's hides of the diver's trips
  // and sites (issue #2594). They would cascade; deleting them first
  // tombstones them.
  (
    table: 'trip_hides',
    entityType: 'tripHides',
    where: 'diver_id = ?1 OR $_ofDiverTrips',
  ),
  (
    table: 'site_hides',
    entityType: 'siteHides',
    where:
        'diver_id = ?1 OR '
        'site_id IN (SELECT id FROM dive_sites WHERE diver_id = ?1)',
  ),
```

- [ ] **Step 4: Clear the heir's hides on reassignment**

In `deleteDiverWithReassignment`, inside `if (targetId != null) { ... }`, after the two "Mark reassigned records pending" loops:

```dart
          // The heir now owns these; its own hides of them would leave it
          // owning items it cannot see (issue #2594).
          final hides = ProfileHidesRepository();
          await hides.deleteHides(
            SharedItemKind.trip,
            sharedTripIds,
            diverId: targetId,
          );
          await hides.deleteHides(
            SharedItemKind.site,
            sharedSiteIds,
            diverId: targetId,
          );
```

Add the two imports.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/divers/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/divers/data/repositories/diver_delete_steps.dart lib/features/divers/data/repositories/diver_repository.dart test/features/divers/data/repositories/diver_delete_tombstones_test.dart test/features/divers/data/repositories/diver_reassignment_hides_test.dart
git commit -m "fix(divers): a profile delete tombstones hides and clears the heir's

Refs #2594"
```

---

### Task 9: Notifiers and providers

**Files:**
- Create: `lib/features/divers/presentation/providers/profile_hides_providers.dart`
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart` (`TripListNotifier`)
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart` (`SiteListNotifier`)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (register `hiddenItemsProvider`)
- Test: `test/features/divers/presentation/providers/profile_hides_providers_test.dart`, `test/features/trips/presentation/providers/trip_list_notifier_ownership_test.dart`, `test/features/dive_sites/presentation/providers/site_list_notifier_ownership_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4, 6, 7.
- Produces:
  - `final profileHidesRepositoryProvider = Provider<ProfileHidesRepository>`
  - `final hiddenItemsProvider = FutureProvider<List<HiddenItem>>` (the validated current diver's)
  - `TripListNotifier`: `Future<bool> deleteTrip(String id)`, `Future<bool> hideTrip(String id)`, `Future<void> unhideTrip(String id)`; `updateTrip` passes the acting profile.
  - `SiteListNotifier`: `Future<bool> deleteSite(String id)`, `Future<({List<domain.DiveSite> sites, SiteLinks links})> bulkDeleteSites(List<String> ids)` (deletes only what the profile may; unchanged return type), `Future<int> hideSites(List<String> ids)`, `Future<void> unhideSites(List<String> ids)`; `updateSite` and `mergeSites` pass the acting profile.

- [ ] **Step 1: Write the failing provider and notifier tests**

`profile_hides_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true);
  });

  tearDown(tearDownTestDatabase);

  test('hiddenItemsProvider lists the active profile\'s hides and refreshes',
      () async {
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'b'),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(hiddenItemsProvider, (_, __) {});
    addTearDown(sub.close);
    expect(await container.read(hiddenItemsProvider.future), isEmpty);

    await container
        .read(profileHidesRepositoryProvider)
        .hide(SharedItemKind.trip, 'shared', 'b');
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(hiddenItemsProvider.future)).single.id,
      'shared',
    );
  });
}
```

For the two notifier tests, follow the existing notifier test setup in `test/features/trips/presentation/providers/trip_providers_test.dart` (real repository over `setUpTestDatabase`, a `ProviderContainer` overriding `validatedCurrentDiverIdProvider` and `currentDiverIdProvider`). Cases:

- Trip, active `b`: `deleteTrip('shared')` returns false and the trip stays; `hideTrip('shared')` returns true and the notifier's state no longer contains it; `unhideTrip('shared')` brings it back. Active `a`: `deleteTrip('shared')` returns true.
- Site, active `b`, sites `theirs` (owner `a`, shared) and `mine` (owner `b`): `bulkDeleteSites(['theirs', 'mine'])` returns `sites` with only `mine` and leaves `theirs`; `hideSites(['theirs'])` returns 1 and the state drops it; `unhideSites(['theirs'])` restores it; `deleteSite('theirs')` returns false.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divers/presentation/providers/profile_hides_providers_test.dart test/features/trips/presentation/providers/trip_list_notifier_ownership_test.dart test/features/dive_sites/presentation/providers/site_list_notifier_ownership_test.dart`
Expected: FAIL (missing providers and methods).

- [ ] **Step 3: Write the providers**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The shared trips and sites each profile has hidden (issue #2594).
final profileHidesRepositoryProvider = Provider<ProfileHidesRepository>(
  (ref) => ProfileHidesRepository(),
);

/// The active profile's hidden trips and sites, for Settings > Shared
/// data. Refreshes when a hide, a trip or a site changes, including by
/// sync.
final hiddenItemsProvider = FutureProvider<List<HiddenItem>>((ref) async {
  final repository = ref.watch(profileHidesRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  return repository.hiddenItems(diverId);
});
```

Register it in `test/architecture/provider_tick_build_smoke_test.dart` the way `trip_equipment_providers` were (see `git show 274ecd88841 -- test/architecture/provider_tick_build_smoke_test.dart`).

- [ ] **Step 4: Extend `TripListNotifier`**

Replace `updateTrip` and `deleteTrip`, and add the hide pair:

```dart
  Future<void> updateTrip(Trip trip) async {
    final actingDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    await _repository.updateTrip(trip, actingDiverId: actingDiverId);
    await refresh();
    _ref.invalidate(tripByIdProvider(trip.id));
    _ref.invalidate(tripWithStatsProvider(trip.id));
  }

  /// Deletes [id] when the active profile may (issue #2594). False, with
  /// nothing changed, for a shared trip another profile owns.
  Future<bool> deleteTrip(String id) async {
    final actingDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    final deleted = await _repository.deleteTrip(
      id,
      actingDiverId: actingDiverId,
    );
    await refresh();
    return deleted;
  }

  /// Hides another profile's shared trip [id] from the active profile only
  /// (issue #2594). False when the policy refuses.
  Future<bool> hideTrip(String id) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return false;
    final hidden = await _ref
        .read(profileHidesRepositoryProvider)
        .hide(SharedItemKind.trip, id, diverId);
    await refresh();
    _ref.invalidate(hiddenItemsProvider);
    return hidden;
  }

  /// Shows a hidden trip [id] to the active profile again.
  Future<void> unhideTrip(String id) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    await _ref
        .read(profileHidesRepositoryProvider)
        .unhide(SharedItemKind.trip, id, diverId);
    await refresh();
    _ref.invalidate(hiddenItemsProvider);
  }
```

- [ ] **Step 5: Extend `SiteListNotifier`**

```dart
  Future<void> updateSite(
    domain.DiveSite site, {
    SiteClassification? classification,
  }) async {
    final actingDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    await _repository.updateSite(
      site,
      classification: classification,
      actingDiverId: actingDiverId,
    );
    await _loadSites();
  }

  /// Deletes [id] when the active profile may (issue #2594). False, with
  /// nothing changed, for a shared site another profile owns.
  Future<bool> deleteSite(String id) async {
    final actingDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    final deleted = await _repository.deleteSite(
      id,
      actingDiverId: actingDiverId,
    );
    await _loadSites();
    return deleted;
  }

  /// Bulk delete multiple sites: only those the active profile may destroy
  /// (issue #2594); callers hide the rest with [hideSites].
  ///
  /// Returns the deleted sites and the dives and plans the delete left
  /// without a site, so [restoreSites] can undo both.
  Future<({List<domain.DiveSite> sites, SiteLinks links})> bulkDeleteSites(
    List<String> ids,
  ) async {
    final actingDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    final sitesToDelete = [
      for (final site in await _repository.getSitesByIds(ids))
        if (canDestroySharedItem(
          ownerId: site.diverId,
          activeDiverId: actingDiverId,
        ))
          site,
    ];
    // The delete reports the links it cleared, read in its own transaction.
    final links = await _repository.bulkDeleteSites([
      for (final site in sitesToDelete) site.id,
    ], actingDiverId: actingDiverId);
    await _loadSites();
    _invalidateSiteProviders(ids);
    return (sites: sitesToDelete, links: links);
  }

  /// Hides other profiles' shared sites [ids] from the active profile only
  /// (issue #2594). Returns how many are hidden afterwards.
  Future<int> hideSites(List<String> ids) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return 0;
    final hides = _ref.read(profileHidesRepositoryProvider);
    var hidden = 0;
    for (final id in ids) {
      if (await hides.hide(SharedItemKind.site, id, diverId)) hidden++;
    }
    await _loadSites();
    _invalidateSiteProviders(ids);
    _ref.invalidate(hiddenItemsProvider);
    return hidden;
  }

  /// Shows hidden sites [ids] to the active profile again.
  Future<void> unhideSites(List<String> ids) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    final hides = _ref.read(profileHidesRepositoryProvider);
    for (final id in ids) {
      await hides.unhide(SharedItemKind.site, id, diverId);
    }
    await _loadSites();
    _invalidateSiteProviders(ids);
    _ref.invalidate(hiddenItemsProvider);
  }
```

In `mergeSites`, read `actingDiverId` the same way and pass `actingDiverId: actingDiverId` to `_repository.mergeSites`. Add imports for `shared_item_policy.dart` and `profile_hides_providers.dart` in both provider files.

- [ ] **Step 6: Run the tests, then every test that mocks these notifiers**

Run: `flutter test test/features/divers/presentation/ test/features/trips/presentation/providers/ test/features/dive_sites/presentation/providers/ test/architecture/`
Then: `flutter analyze test/` to catch hand-written mocks that `implements TripListNotifier` / `SiteListNotifier` without `noSuchMethod`; give each missing member a trivial override (`Future<bool> hideTrip(String id) async => true;` and so on).
Expected: PASS, zero analyzer issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/divers/presentation/providers/profile_hides_providers.dart lib/features/trips/presentation/providers/trip_providers.dart lib/features/dive_sites/presentation/providers/site_providers.dart test/architecture/provider_tick_build_smoke_test.dart test/features/divers/presentation/providers/profile_hides_providers_test.dart test/features/trips/presentation/providers/trip_list_notifier_ownership_test.dart test/features/dive_sites/presentation/providers/site_list_notifier_ownership_test.dart
git commit -m "feat(sharing): list notifiers delete as the owner and hide for others

Refs #2594"
```

(Add any mock file Step 6 touched, by path.)

---

### Task 10: Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other `app_*.arb` files
- Regenerated: `lib/l10n/arb/app_localizations*.dart` (by `flutter gen-l10n`)

**Interfaces:**
- Produces these `context.l10n` getters and methods, used by Tasks 11 to 15:

| Key | English | Placeholders |
| --- | --- | --- |
| `sharedItems_sharedBy` | Shared by {owner} | owner: String |
| `sharedItems_ownerUnknown` | another profile | |
| `sharedItems_removeAction` | Remove from my profile | |
| `sharedItems_removeTitle` | Remove '{name}' from your profile? | name: String |
| `sharedItems_removeBody` | It stays in {owner}'s log and in every other profile. It is only hidden here. | owner: String |
| `sharedItems_removeOwnDives` | {count, plural, one{{count} of your dives stays linked to it.} other{{count} of your dives stay linked to it.}} | count: int |
| `sharedItems_removeRestoreHint` | You can bring it back from Settings > Shared data. | |
| `sharedItems_removedSnackbar` | Removed from your profile | |
| `sharedItems_undo` | Undo | |
| `sharedItems_notOwner_trip` | Only its owner can delete this trip | |
| `sharedItems_notOwner_site` | Only its owner can delete this site | |
| `sharedItems_otherProfilesDives_trip` | {count, plural, one{{count} dive in another profile will lose this trip.} other{{count} dives in other profiles will lose this trip.}} | count: int |
| `sharedItems_otherProfilesDives_site` | {count, plural, one{{count} dive in another profile will lose this site.} other{{count} dives in other profiles will lose this site.}} | count: int |
| `sharedItems_shareOwnerOnly` | Only {owner} can change sharing | owner: String |
| `sharedItems_bulkDeleteCount_trips` | {count, plural, one{{count} trip will be deleted.} other{{count} trips will be deleted.}} | count: int |
| `sharedItems_bulkHideCount_trips` | {count, plural, one{{count} shared trip will be removed from your profile only.} other{{count} shared trips will be removed from your profile only.}} | count: int |
| `sharedItems_bulkDeleteCount_sites` | {count, plural, one{{count} site will be deleted.} other{{count} sites will be deleted.}} | count: int |
| `sharedItems_bulkHideCount_sites` | {count, plural, one{{count} shared site will be removed from your profile only.} other{{count} shared sites will be removed from your profile only.}} | count: int |
| `sharedItems_bulkSharedWarning_trips` | {count, plural, one{{count} of them is shared with other profiles and will be deleted for everyone.} other{{count} of them are shared with other profiles and will be deleted for everyone.}} | count: int |
| `sharedItems_bulkSharedWarning_sites` | {count, plural, one{{count} of them is shared with other profiles and will be deleted for everyone.} other{{count} of them are shared with other profiles and will be deleted for everyone.}} | count: int |
| `sharedItems_bulkRemoveTitle` | {count, plural, one{Remove {count} item from your profile?} other{Remove {count} items from your profile?}} | count: int |
| `sharedItems_bulkHiddenSnackbar` | {count, plural, one{{count} item removed from your profile} other{{count} items removed from your profile}} | count: int |
| `sharedItems_mergeTooManyShared` | Only one of the selected sites can belong to another profile. Deselect the others to merge. | |
| `settings_hiddenItems_title` | Hidden from this profile | |
| `settings_hiddenItems_trips` | Trips | |
| `settings_hiddenItems_sites` | Sites | |
| `settings_hiddenItems_unhide` | Unhide | |
| `settings_hiddenItems_empty` | Nothing is hidden from this profile. | |

- [ ] **Step 1: Add the English keys**

Insert each key into `app_en.arb` at its alphabetical position with an `@key` block carrying a `description` and, for placeholders, `placeholders` with `type` and `example`, in the style of `trips_deleteShared_body` (line 19590). Example:

```json
  "sharedItems_removeOwnDives": "{count, plural, one{{count} of your dives stays linked to it.} other{{count} of your dives stay linked to it.}}",
  "@sharedItems_removeOwnDives": {
    "description": "Line in the remove-from-profile confirmation counting the active profile's own dives that keep their link to the hidden trip or site.",
    "placeholders": {
      "count": {
        "type": "int",
        "example": "2"
      }
    }
  },
```

- [ ] **Step 2: Translate into the 10 other locales**

Add every key to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`, grouped next to the existing `trips_deleteShared_*` / `settings_shareAll*` keys in each file (non-English files are grouped by feature, not alphabetical). Translate naturally, matching each file's existing terms for "profile", "trip", "site", "share" and its quotation marks (for example German uses the „...“ style seen in `trips_deleteShared_body`). Keep every plural as `one{...}` / `other{...}` with `{count}` in the text; Arabic may add the CLDR categories its file already uses elsewhere (`zero`, `two`, `few`, `many`). Placeholders keep their English names.

- [ ] **Step 3: Generate and check**

Run: `flutter gen-l10n`, then `flutter analyze lib/l10n` and `flutter test test/l10n/` (if the folder exists; it holds the ARB completeness and plural guards).
Expected: no missing-translation warnings for the new keys, zero analyzer issues, guards PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): strings for hiding and owning shared trips and sites

Refs #2594"
```

---

### Task 11: Shared-item UI pieces

**Files:**
- Create: `lib/shared/widgets/shared_items/shared_item_dialogs.dart`
- Create: `lib/shared/widgets/shared_items/shared_by_banner.dart`
- Test: `test/shared/widgets/shared_items/shared_item_dialogs_test.dart`, `test/shared/widgets/shared_items/shared_by_banner_test.dart`

**Interfaces:**
- Consumes: Task 1 (`SharedItemKind`), Task 10 strings, `allDiversProvider`, `validatedCurrentDiverIdProvider`, `Diver`.
- Produces:
  - `String sharedItemOwnerName(List<Diver> divers, String? ownerId, AppLocalizations l10n)`
  - `Future<bool> confirmRemoveFromProfile(BuildContext context, {required String name, required String ownerName, required int ownDiveCount})`
  - `String? otherProfilesDivesLine(AppLocalizations l10n, SharedItemKind kind, int count)` (null for 0)
  - `List<String> bulkDeleteLines(AppLocalizations l10n, SharedItemKind kind, {required int deleteCount, required int hideCount, int sharedDeleteCount = 0})`
  - `class SharedByBanner extends ConsumerWidget { const SharedByBanner({required String? ownerId, required bool isShared}); }` (renders nothing unless the item is shared and owned by another profile)

- [ ] **Step 1: Write the failing widget tests**

`shared_item_dialogs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final divers = [
    Diver(id: 'a', name: 'Alice', createdAt: DateTime(2024), updatedAt: DateTime(2024)),
  ];

  test('sharedItemOwnerName names the owner or falls back', () {
    expect(sharedItemOwnerName(divers, 'a', l10n), 'Alice');
    expect(sharedItemOwnerName(divers, 'gone', l10n), 'another profile');
    expect(sharedItemOwnerName(divers, null, l10n), 'another profile');
  });

  test('otherProfilesDivesLine is null for none', () {
    expect(otherProfilesDivesLine(l10n, SharedItemKind.trip, 0), isNull);
    expect(
      otherProfilesDivesLine(l10n, SharedItemKind.trip, 3),
      '3 dives in other profiles will lose this trip.',
    );
    expect(
      otherProfilesDivesLine(l10n, SharedItemKind.site, 1),
      '1 dive in another profile will lose this site.',
    );
  });

  test('bulkDeleteLines states each non-empty half', () {
    expect(
      bulkDeleteLines(l10n, SharedItemKind.trip, deleteCount: 3, hideCount: 2),
      [
        '3 trips will be deleted.',
        '2 shared trips will be removed from your profile only.',
      ],
    );
    expect(
      bulkDeleteLines(l10n, SharedItemKind.site, deleteCount: 0, hideCount: 1),
      ['1 shared site will be removed from your profile only.'],
    );
    expect(
      bulkDeleteLines(
        l10n,
        SharedItemKind.trip,
        deleteCount: 2,
        hideCount: 0,
        sharedDeleteCount: 1,
      ),
      [
        '2 trips will be deleted.',
        '1 of them is shared with other profiles and will be deleted for '
            'everyone.',
      ],
    );
  });

  testWidgets('confirmRemoveFromProfile shows owner, own dives and hint',
      (tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = confirmRemoveFromProfile(
              context,
              name: 'Bonaire',
              ownerName: 'Alice',
              ownDiveCount: 2,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text("Remove 'Bonaire' from your profile?"), findsOneWidget);
    expect(find.textContaining("It stays in Alice's log"), findsOneWidget);
    expect(find.textContaining('2 of your dives stay linked'), findsOneWidget);
    expect(find.textContaining('Settings > Shared data'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
```

`shared_by_banner_test.dart`: pump `SharedByBanner(ownerId: 'a', isShared: true)` in a `ProviderScope` overriding `allDiversProvider` (Alice `a`, Bob `b`) and `validatedCurrentDiverIdProvider` to `'b'`: expect `Shared by Alice`. With the active diver `'a'`, or `isShared: false`, or `ownerId: null`: expect no `Shared by` text.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/shared/widgets/shared_items/`
Expected: FAIL (files missing).

- [ ] **Step 3: Write `shared_item_dialogs.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The owning profile's name, or a neutral fallback for a profile that is
/// gone or unknown (issue #2594).
String sharedItemOwnerName(
  List<Diver> divers,
  String? ownerId,
  AppLocalizations l10n,
) {
  for (final diver in divers) {
    if (diver.id == ownerId) return diver.name;
  }
  return l10n.sharedItems_ownerUnknown;
}

/// The owner's delete-confirmation line counting the other profiles' dives
/// that will lose the trip or site; null when there are none.
String? otherProfilesDivesLine(
  AppLocalizations l10n,
  SharedItemKind kind,
  int count,
) {
  if (count <= 0) return null;
  return switch (kind) {
    SharedItemKind.trip => l10n.sharedItems_otherProfilesDives_trip(count),
    SharedItemKind.site => l10n.sharedItems_otherProfilesDives_site(count),
  };
}

/// A bulk-delete confirmation's lines: what is deleted (and how many of
/// those are shared, so deleted for every profile), and what is only
/// removed from the active profile. An empty half has no line.
List<String> bulkDeleteLines(
  AppLocalizations l10n,
  SharedItemKind kind, {
  required int deleteCount,
  required int hideCount,
  int sharedDeleteCount = 0,
}) => [
  if (deleteCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkDeleteCount_trips(
        deleteCount,
      ),
      SharedItemKind.site => l10n.sharedItems_bulkDeleteCount_sites(
        deleteCount,
      ),
    },
  if (deleteCount > 0 && sharedDeleteCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkSharedWarning_trips(
        sharedDeleteCount,
      ),
      SharedItemKind.site => l10n.sharedItems_bulkSharedWarning_sites(
        sharedDeleteCount,
      ),
    },
  if (hideCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkHideCount_trips(hideCount),
      SharedItemKind.site => l10n.sharedItems_bulkHideCount_sites(hideCount),
    },
];

/// Confirms hiding another profile's shared trip or site from the active
/// profile only (issue #2594). True when confirmed.
Future<bool> confirmRemoveFromProfile(
  BuildContext context, {
  required String name,
  required String ownerName,
  required int ownDiveCount,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.sharedItems_removeTitle(name)),
        content: Text(
          [
            ctx.l10n.sharedItems_removeBody(ownerName),
            if (ownDiveCount > 0) ctx.l10n.sharedItems_removeOwnDives(ownDiveCount),
            ctx.l10n.sharedItems_removeRestoreHint,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.common_action_remove),
          ),
        ],
      ),
    ) ??
    false;
```

- [ ] **Step 4: Write `shared_by_banner.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

/// "Shared by {owner}", shown on a trip or site that another profile owns
/// and shares (issue #2594), so the active profile knows why it can only
/// remove the item from itself. Renders nothing otherwise.
class SharedByBanner extends ConsumerWidget {
  const SharedByBanner({
    super.key,
    required this.ownerId,
    required this.isShared,
  });

  final String? ownerId;
  final bool isShared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final divers = ref.watch(allDiversProvider).value;
    if (divers == null ||
        !canHideSharedItem(
          ownerId: ownerId,
          isShared: isShared,
          activeDiverId: activeDiverId,
        )) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.sharedItems_sharedBy(
                sharedItemOwnerName(divers, ownerId, context.l10n),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/shared/widgets/shared_items/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/shared_items/ test/shared/widgets/shared_items/
git commit -m "feat(sharing): the shared-by line and the remove and delete dialog pieces

Refs #2594"
```

---

### Task 12: Trip detail and trip edit pages

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (`_headerCards` at 370, the menu handler at 462, the menu item at 534, `_showDeleteConfirmation` at 551)
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (share `SwitchListTile` at 636)
- Modify: `test/features/trips/presentation/pages/trip_detail_page_test.dart`, `test/features/trips/presentation/pages/trip_edit_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4 (`diveLinkCounts`), 9 (`deleteTrip`, `hideTrip`, `unhideTrip`, `profileHidesRepositoryProvider`), 10, 11.

- [ ] **Step 1: Write the failing widget tests**

In `trip_detail_page_test.dart`, inside the `delete confirmation on shared trip` group, reuse the existing setup (the `sharedTrip` there has no `diverId`; build `Trip(... diverId: 'd1', isShared: true)` with `twoDivers` Alice `d1` and Bob `d2`), add overrides `validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd2')` and `profileHidesRepositoryProvider.overrideWithValue(_FakeHides())` where:

```dart
class _FakeHides extends Fake implements ProfileHidesRepository {
  @override
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async => (mine: 2, others: 5);
}
```

Cases:
- Non-owner (`d2`): the menu shows `Remove from my profile` and no `Delete`; the page shows `Shared by Alice`; tapping it shows `Remove 'Salt Pier Getaway' from your profile?` and `2 of your dives stay linked to it.`; confirming calls the mock notifier's `hideTrip` (give `_MockTripListNotifier` a `hiddenIds` list recorded by `hideTrip`, returning true) and shows `Removed from your profile` with `Undo`.
- Owner (`d1`): `Delete` is shown; the dialog title is `Delete shared trip?` and the body contains `5 dives in other profiles will lose this trip.`

In `trip_edit_page_test.dart`, in the share-toggle group: with two divers and the trip owned by `d1` while the active diver is `d2`, the `SwitchListTile` is disabled (`tester.widget<SwitchListTile>(...).onChanged` is null) and `Only Alice can change sharing` is shown; with the active diver `d1` it is enabled.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/pages/trip_detail_page_test.dart test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: the new cases FAIL.

- [ ] **Step 3: Show the banner**

Replace `_headerCards`:

```dart
  /// The cards above the trip's story, the same in every layout, under
  /// "Shared by" when another profile owns the trip (issue #2594).
  Widget _headerCards(Trip trip) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SharedByBanner(ownerId: trip.diverId, isShared: trip.isShared),
      TripHeaderCards(
        children: [
          TripGearAlertsPanel(trip: trip),
          TripCylindersCard(trip: trip),
          TripGearCard(trip: trip),
        ],
      ),
    ],
  );
```

- [ ] **Step 4: Switch the menu between delete and remove**

In `_buildMoreMenu`, read the active diver at the top: `final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;` and `final canDestroy = canDestroySharedItem(ownerId: trip.diverId, activeDiverId: activeDiverId);`. Replace the `delete` menu item with:

```dart
        if (canDestroy)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  context.l10n.trips_detail_action_delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                const Icon(Icons.visibility_off_outlined),
                const SizedBox(width: 8),
                Flexible(child: Text(context.l10n.sharedItems_removeAction)),
              ],
            ),
          ),
```

In `onSelected`, before `} else if (value == 'export') {`, add:

```dart
        } else if (value == 'remove') {
          await _removeFromProfile(context, ref, trip);
```

and add, after `_showDeleteConfirmation`:

```dart
  /// Hides another profile's shared trip from the active profile only
  /// (issue #2594), with Undo.
  Future<void> _removeFromProfile(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final divers = await ref.read(allDiversProvider.future);
    final activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final counts = await ref
        .read(profileHidesRepositoryProvider)
        .diveLinkCounts(SharedItemKind.trip, trip.id, activeDiverId);
    if (!context.mounted) return;
    final confirmed = await confirmRemoveFromProfile(
      context,
      name: trip.name,
      ownerName: sharedItemOwnerName(divers, trip.diverId, context.l10n),
      ownDiveCount: counts.mine,
    );
    if (!confirmed || !context.mounted) return;
    final notifier = ref.read(tripListNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!await notifier.hideTrip(trip.id)) return;
    if (!context.mounted) return;
    if (embedded) {
      onDeleted?.call();
    } else {
      context.pop();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sharedItems_removedSnackbar),
        action: SnackBarAction(
          label: l10n.sharedItems_undo,
          onPressed: () => notifier.unhideTrip(trip.id),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Add the count to the owner's dialog and handle a refusal**

In `_showDeleteConfirmation`, after reading `divers`, when `isSharedDelete`:

```dart
    final activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final others = isSharedDelete
        ? (await ref
                  .read(profileHidesRepositoryProvider)
                  .diveLinkCounts(SharedItemKind.trip, trip.id, activeDiverId))
              .others
        : 0;
    if (!context.mounted) return false;
```

and make the shared body `[ctx.l10n.trips_deleteShared_body(trip.name), ?otherProfilesDivesLine(ctx.l10n, SharedItemKind.trip, others)].join('\n\n')` (if the project's Dart version lacks null-aware elements, use `if (line != null) line`). In the `delete` handler, use the result: `final deleted = await ref.read(tripListNotifierProvider.notifier).deleteTrip(trip.id); if (!deleted) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.sharedItems_notOwner_trip))); return; }` before the existing pop and snackbar.

- [ ] **Step 6: Lock the Share switch for non-owners**

In `trip_edit_page.dart`, at the `SwitchListTile` (line 636): compute `final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;` and `final mayShare = !isEditing || canDestroySharedItem(ownerId: _originalTrip?.diverId, activeDiverId: activeDiverId);`, then set `onChanged: mayShare ? (v) async { ...existing body... } : null,` and `subtitle: mayShare ? null : Text(context.l10n.sharedItems_shareOwnerOnly(sharedItemOwnerName(divers, _originalTrip?.diverId, context.l10n))),`.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/trips/presentation/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_detail_page.dart lib/features/trips/presentation/pages/trip_edit_page.dart test/features/trips/presentation/pages/trip_detail_page_test.dart test/features/trips/presentation/pages/trip_edit_page_test.dart
git commit -m "feat(trips): remove another profile's shared trip from your profile only

Refs #2594"
```

---

### Task 13: Site detail and site edit pages

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (body column at 204, embedded menu at 455, `_handleMenuAction` delete at 494)
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (AppBar actions at 1166, `_confirmDelete` at 1915, `_deleteSite` at 1950, `LifeNotesSection` call at 1122)
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart` (share toggle)
- Modify: `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`, `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4, 9, 10, 11.
- Produces: `LifeNotesSection` gains `final String? shareLockedReason;` (null keeps the toggle enabled).

- [ ] **Step 1: Write the failing widget tests**

Mirror Task 12 Step 1 for sites, with a `DiveSite(id: 'pier', name: 'Salt Pier', diverId: 'd1', isShared: true)`, the `_FakeHides` fake, and the existing site test harnesses:
- `site_detail_page_test.dart` (embedded mode, where the delete lives): active `d2` shows `Shared by Alice` and `Remove from my profile`; confirming calls `SiteListNotifier.hideSites(['pier'])` (record it in the test's mock notifier). Active `d1`: `Delete shared site?` and `5 dives in other profiles will lose this site.`
- `site_edit_page_test.dart`: active `d2`, editing `pier`: the AppBar delete icon's tooltip is `Remove from my profile`, tapping it shows the remove dialog; the share `FormRow.toggle` is disabled with help text `Only Alice can change sharing`. Active `d1`: the delete dialog is the shared one with the count.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/presentation/pages/`
Expected: new cases FAIL.

- [ ] **Step 3: Detail page**

- Body column (line 214): after `SiteDetailHeader(site: site),` add `SharedByBanner(ownerId: site.diverId, isShared: site.isShared),`.
- Embedded menu: compute `canDestroy` as in Task 12 from `ref.watch(validatedCurrentDiverIdProvider).value`; when false, replace the `delete` item with a `value: 'remove'` item (`Icons.visibility_off_outlined`, `sharedItems_removeAction`).
- `_handleMenuAction`: add `if (action == 'remove') { await _removeFromProfile(context, ref, site); return; }` with a `_removeFromProfile` like Task 12's, using `SharedItemKind.site`, `siteListNotifierProvider.notifier.hideSites([site.id])` (success when it returns 1), `unhideSites([site.id])` for Undo, `widget.onDeleted?.call()` when embedded and `context.go('/sites')` otherwise.
- In the `delete` branch, when `isSharedDelete`, read `diveLinkCounts(SharedItemKind.site, site.id, activeDiverId).others` and append `otherProfilesDivesLine(...)` to the shared body before `withSiteDeleteUsage`. Use the bool from `deleteSite`: on false show `sharedItems_notOwner_site` and stop.

- [ ] **Step 4: Edit page and life-notes toggle**

- `life_notes_section.dart`: add `this.shareLockedReason,` to the constructor and `final String? shareLockedReason;`, and change the toggle to:

```dart
        if (showShareToggle)
          FormRow.toggle(
            label: l10n.common_label_shareWithAllProfiles,
            value: isShared,
            onChanged: onShareChanged,
            enabled: shareLockedReason == null,
            helpText: shareLockedReason,
          ),
```

- `site_edit_page.dart`, the `LifeNotesSection(...)` call: pass `shareLockedReason: _shareLockedReason(),` with:

```dart
  /// Why the Share switch is locked: another profile owns the site (issue
  /// #2594). Null when the active profile may change sharing.
  String? _shareLockedReason() {
    if (!widget.isEditing && !widget.isMerging) return null;
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    if (canDestroySharedItem(
      ownerId: _originalSite?.diverId,
      activeDiverId: activeDiverId,
    )) {
      return null;
    }
    final divers = ref.watch(allDiversProvider).value ?? const [];
    return context.l10n.sharedItems_shareOwnerOnly(
      sharedItemOwnerName(divers, _originalSite?.diverId, context.l10n),
    );
  }
```

- AppBar action: when `_shareLockedReason() != null` (the site is another profile's), show `IconButton(icon: const Icon(Icons.visibility_off_outlined), tooltip: context.l10n.sharedItems_removeAction, onPressed: _confirmRemove)` instead of the delete button. `_confirmRemove` follows Task 12's `_removeFromProfile` with `SharedItemKind.site`, `hideSites([widget.siteId!])`, and on success sets `_hasChanges = false` and navigates exactly as `_deleteSite` does.
- `_confirmDelete`: when `(_originalSite?.isShared ?? false)` and there are 2+ divers, use `sites_deleteShared_title` / `sites_deleteShared_body(name)` plus `otherProfilesDivesLine(...)`, exactly as the detail page, so the edit page no longer skips the shared warning. `_deleteSite`: on a false result show `sharedItems_notOwner_site` and stop.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/dive_sites/presentation/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart test/features/dive_sites/presentation/pages/site_detail_page_test.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart
git commit -m "feat(sites): remove another profile's shared site from your profile only

The site edit page now shows the shared-site delete warning too.

Refs #2594"
```

---

### Task 14: List bulk delete and site merge

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (`_confirmAndDelete` at 303)
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (`_startMerge` at 252, `_confirmAndDelete` at 308)
- Modify: `test/features/trips/presentation/widgets/trip_list_content_test.dart`, `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`

**Interfaces:**
- Consumes: `splitForBulkDelete`, `canDestroySharedItem` (Task 1); notifier methods (Task 9); `bulkDeleteLines`, strings (Tasks 10, 11).

- [ ] **Step 1: Write the failing widget tests**

Trip list (active `d2`, two divers, trips `mine` owned by `d2` and shared, and `theirs` owned by `d1` and shared, both selected via the file's existing selection helpers): the dialog contains `1 trip will be deleted.`, `1 of them is shared with other profiles and will be deleted for everyone.` and `1 shared trip will be removed from your profile only.`; confirming calls the mock notifier's `deleteTrip('mine')` and `hideTrip('theirs')`, never `deleteTrip('theirs')`. With only `theirs` selected, the title is `Remove 1 item from your profile?`.

Site list: the same split over `bulkDeleteSites(['mine'])` and `hideSites(['theirs'])`; the Undo snackbar action calls `restoreSites` for the deleted half and `unhideSites(['theirs'])` for the hidden half. Merge: with two sites owned by `d1` and one by `d2` selected, tapping Merge shows `Only one of the selected sites can belong to another profile...` and pushes nothing; with one `d1` site and one `d2` site selected (in that order `d2`, `d1`), the pushed `extra` list starts with the `d1` site id.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart test/features/dive_sites/presentation/widgets/site_list_content_test.dart`
Expected: new cases FAIL.

- [ ] **Step 3: Trip list**

Replace `_confirmAndDelete` in `trip_list_content.dart`:

```dart
  Future<BulkActionOutcome> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;

    // Another profile's shared trips are hidden, not deleted (issue #2594).
    final activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final trips = ref.read(tripListNotifierProvider).value ?? const [];
    final selected = [
      for (final t in trips)
        if (ids.contains(t.trip.id)) t.trip,
    ];
    final split = splitForBulkDelete(
      selected,
      ownerOf: (t) => t.diverId,
      isSharedOf: (t) => t.isShared,
      activeDiverId: activeDiverId,
    );
    // The owner's shared trips go for every profile: say how many, as the
    // detail page's shared warning does, once two or more profiles exist.
    final divers = await ref.read(allDiversProvider.future);
    if (!mounted) return BulkActionOutcome.cancelled;
    final deleteCount = split.destroy.length;
    final hideCount = split.hide.length;
    final sharedDeleteCount = divers.length >= 2
        ? split.destroy.where((t) => t.isShared).length
        : 0;
    if (deleteCount + hideCount == 0) return BulkActionOutcome.cancelled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          deleteCount > 0
              ? ctx.l10n.common_bulkDelete_title(deleteCount + hideCount)
              : ctx.l10n.sharedItems_bulkRemoveTitle(hideCount),
        ),
        content: Text(
          [
            ...bulkDeleteLines(
              ctx.l10n,
              SharedItemKind.trip,
              deleteCount: deleteCount,
              hideCount: hideCount,
              sharedDeleteCount: sharedDeleteCount,
            ),
            if (deleteCount > 0) ctx.l10n.common_bulkDelete_body,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: deleteCount > 0
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            child: Text(
              deleteCount > 0
                  ? ctx.l10n.common_action_delete
                  : ctx.l10n.common_action_remove,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return BulkActionOutcome.cancelled;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(tripListNotifierProvider.notifier);
    _selection.exit();

    var deleted = 0;
    for (final trip in split.destroy) {
      if (await notifier.deleteTrip(trip.id)) deleted++;
    }
    var hidden = 0;
    for (final trip in split.hide) {
      if (await notifier.hideTrip(trip.id)) hidden++;
    }

    if (!mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            if (deleted > 0) l10n.common_bulkDelete_snackbar(deleted),
            if (hidden > 0) l10n.sharedItems_bulkHiddenSnackbar(hidden),
          ].join(' · '),
        ),
      ),
    );
    return BulkActionOutcome.completed;
  }
```

Add imports for `shared_item_policy.dart`, `shared_item_dialogs.dart`, `diver_providers.dart`.

- [ ] **Step 4: Site list bulk delete**

In `site_list_content.dart` `_confirmAndDelete`, after `final idsToDelete = _selectedIds.toList();`, split the selection with `splitForBulkDelete` over `await ref.read(siteRepositoryProvider).getSitesByIds(idsToDelete)` (owner `s.diverId`, shared `s.isShared`, active from `validatedCurrentDiverIdProvider.future`). Read `usage` only for the destroy half. Compute `sharedDeleteCount` exactly as the trip list does (shared sites in the destroy half, when `allDiversProvider` has two or more profiles) and pass it to `bulkDeleteLines`. Dialog title: `diveSites_list_bulkDelete_title` when the destroy half is non-empty, else `sharedItems_bulkRemoveTitle(hideCount)`; content: `bulkDeleteLines(...)` lines, then (when deleting) `withSiteDeleteUsage(context.l10n, context.l10n.diveSites_list_bulkDelete_content(deleteCount), usage)`. On confirm: `bulkDeleteSites(destroyIds)` when non-empty, `hideSites(hideIds)` when non-empty; store both in `_deletedSites` and a new `List<String> _hiddenSiteIds` field. The snackbar text joins `diveSites_list_bulkDelete_snackbar(deleted.sites.length)` (when any) and `sharedItems_bulkHiddenSnackbar(hidden)` (when any) with ` · `. The Undo action restores the deleted half as today and then `await ref.read(siteListNotifierProvider.notifier).unhideSites(_hiddenSiteIds)` when non-empty, clearing both fields.

- [ ] **Step 5: Site merge ordering**

At the top of `_startMerge`:

```dart
    // A merge destroys every site but the first (issue #2594): another
    // profile's shared site may only be the survivor, so at most one fits.
    final activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final selected = await ref
        .read(siteRepositoryProvider)
        .getSitesByIds(_selectedIds.toList());
    final notOwned = [
      for (final s in selected)
        if (!canDestroySharedItem(
          ownerId: s.diverId,
          activeDiverId: activeDiverId,
        ))
          s.id,
    ];
    if (!mounted) return BulkActionOutcome.cancelled;
    if (notOwned.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sharedItems_mergeTooManyShared)),
      );
      return BulkActionOutcome.cancelled;
    }
    final orderedIds = [
      ...notOwned,
      for (final id in _selectedIds)
        if (!notOwned.contains(id)) id,
    ];
```

and push `extra: orderedIds` instead of `_selectedIds.toList()`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/trips/presentation/widgets/ test/features/dive_sites/presentation/widgets/`
Expected: PASS, including the shared `bulk_delete_contract.dart` and `selection_contract.dart` suites these lists run.

- [ ] **Step 7: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_list_content.dart lib/features/dive_sites/presentation/widgets/site_list_content.dart test/features/trips/presentation/widgets/trip_list_content_test.dart test/features/dive_sites/presentation/widgets/site_list_content_test.dart
git commit -m "feat(sharing): bulk delete hides other profiles' shared trips and sites

A merge keeps another profile's shared site as the survivor and refuses
more than one.

Refs #2594"
```

---

### Task 15: Settings, hidden items

**Files:**
- Create: `lib/features/settings/presentation/pages/hidden_items_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`SharedDataSectionContent` at 2772)
- Modify: `lib/core/router/app_router.dart` (a child route of `/settings`)
- Test: `test/features/settings/presentation/pages/hidden_items_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart` (add cases)

**Interfaces:**
- Consumes: `hiddenItemsProvider`, `HiddenItem`, notifier `unhideTrip` / `unhideSites` (Task 9), strings (Task 10), `sharedItemOwnerName` (Task 11).
- Produces: route `/settings/hidden-items`.

- [ ] **Step 1: Write the failing tests**

`hidden_items_page_test.dart`: override `hiddenItemsProvider` with two items (a trip `Bonaire` owned by `a`, a site `Salt Pier` owned by `a`), `allDiversProvider` with Alice `a`, and the two list notifiers with mocks recording `unhideTrip` / `unhideSites`. Expect the headers `Trips` and `Sites`, both names, `Shared by Alice` under each, and tapping the first `Unhide` calls `unhideTrip('bonaire-id')`. With an empty list, expect `Nothing is hidden from this profile.`

`settings_page_shared_data_test.dart`: with `hiddenItemsProvider` overridden to two items the section shows `Hidden from this profile` and `2`; with an empty list the row is absent.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/pages/hidden_items_page_test.dart test/features/settings/presentation/pages/settings_page_shared_data_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the page**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

/// The shared trips and sites the active profile has hidden from itself,
/// each with Unhide (issue #2594).
class HiddenItemsPage extends ConsumerWidget {
  const HiddenItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(hiddenItemsProvider);
    final divers = ref.watch(allDiversProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_hiddenItems_title)),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text(context.l10n.common_error_tryAgain)),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.settings_hiddenItems_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final trips = [
            for (final i in items)
              if (i.kind == SharedItemKind.trip) i,
          ];
          final sites = [
            for (final i in items)
              if (i.kind == SharedItemKind.site) i,
          ];
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (trips.isNotEmpty) ...[
                _Header(context.l10n.settings_hiddenItems_trips),
                for (final item in trips) _HiddenRow(item: item, divers: divers),
              ],
              if (sites.isNotEmpty) ...[
                _Header(context.l10n.settings_hiddenItems_sites),
                for (final item in sites) _HiddenRow(item: item, divers: divers),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _HiddenRow extends ConsumerWidget {
  const _HiddenRow({required this.item, required this.divers});

  final HiddenItem item;
  final List<Diver> divers;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    title: Text(item.name),
    subtitle: Text(
      [
        if (item.location case final location? when location.isNotEmpty)
          location,
        context.l10n.sharedItems_sharedBy(
          sharedItemOwnerName(divers, item.ownerId, context.l10n),
        ),
      ].join(' · '),
    ),
    trailing: TextButton(
      onPressed: () => switch (item.kind) {
        SharedItemKind.trip =>
          ref.read(tripListNotifierProvider.notifier).unhideTrip(item.id),
        SharedItemKind.site =>
          ref.read(siteListNotifierProvider.notifier).unhideSites([item.id]),
      },
      child: Text(context.l10n.settings_hiddenItems_unhide),
    ),
  );
}
```

(Import `Diver` from `package:submersion/features/divers/domain/entities/diver.dart`. If `common_error_tryAgain` is the wrong fallback key, use the one `SharedDataSectionContent` already uses.)

- [ ] **Step 4: Route and Settings row**

In `app_router.dart`, next to the existing `/settings/backup` child route, add a `GoRoute(path: 'hidden-items', builder: (context, state) => const HiddenItemsPage())` in the same shape as its siblings. In `SharedDataSectionContent`, watch `final hidden = ref.watch(hiddenItemsProvider).value ?? const [];` and, after the share-all-equipment `ListTile`, add:

```dart
                if (hidden.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: Text(context.l10n.settings_hiddenItems_title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${hidden.length}'),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/settings/hidden-items'),
                  ),
                ],
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/settings/ test/core/router/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/hidden_items_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/core/router/app_router.dart test/features/settings/presentation/pages/hidden_items_page_test.dart test/features/settings/presentation/pages/settings_page_shared_data_test.dart
git commit -m "feat(settings): list and unhide the shared trips and sites hidden here

Refs #2594"
```

---

### Task 16: Whole-branch verification, screenshots and PR

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze` (whole project; infos are fatal in CI).
Expected: no changes left unformatted; `No issues found!`.

- [ ] **Step 2: Architecture guards and the full suite**

Run: `flutter test test/architecture/` then `./scripts/run_all_tests.sh` (check `df -h /Volumes/fltmp` first; one full run is enough).
Expected: PASS. A guard failing on a file this branch does not touch means main moved; check main before changing anything.

- [ ] **Step 3: Run the app and capture screenshots**

With two profiles (Alice owning a shared trip and site, Bob active), capture in light and dark mode, at phone and desktop widths where the layout differs:
- Bob's trip detail page: "Shared by Alice" and the menu's "Remove from my profile"
- the remove confirmation
- Alice's shared delete dialog with the other-profiles count
- the mixed bulk-delete dialog on the trip list
- Settings > Shared data with the "Hidden from this profile" row, and the hidden-items page
Save them under the session scratchpad and hand them to the maintainer (gh cannot upload images).

- [ ] **Step 4: Re-check the schema claim**

Run: `git fetch origin main && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="` and scan open PR diffs for `currentSchemaVersion = 250`. If 250 was taken, renumber the rung, the list entry, the comments and `migration_v250_profile_hides_test.dart`.

- [ ] **Step 5: Open the PR**

Title: `fix(sharing): only a shared trip or site's owner deletes it; other profiles hide it`. Body, following the repository template: a Summary of the owner/reference model; `Closes #2594` and `Refs #2151` on their own lines; a Screenshots section listing each image from Step 3; a Test plan listing the new test files. No tool attribution anywhere.
