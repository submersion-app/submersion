# Equipment Sharing and History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an equipment owner share items with other diver profiles in the same library, so every profile an item is shared with can use and manage it, and show each item's history of users, shares and (later) transfers.

**Architecture:** Two new synced child tables of `equipment`: `equipment_shares` (who may use an item besides its owner) and `equipment_ownership_events` (append-only log of share, unshare and, from PR 3, transfer events). One visibility rule, "owner OR share row", replaces the six `diver_id = ?` clauses in `EquipmentRepository`, which carries sharing to every list, picker, clock, reminder and export that reads through them. New UI: owner chips, a "Shared with me" picker section, a profile checklist for sharing, bulk share, an Owner filter and table column, "Share all my equipment" in Settings, and a History card on the item page built from the service clocks' dive set plus the event log.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod 3 (`flutter_riverpod`), `flutter_test`, ARB l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-17-equipment-sharing-transfer-identity-design.md` (PR 2 of its Delivery section, plus the "Equipment history" section). Read it before starting any task.

**PR:** one PR from branch `ericgriffin/equipment-sharing-profiles-67d843`. Description must contain `Closes #2046` and `Refs #1549`.

## Global Constraints

- Schema rung: **228**. Task 0 confirms it is still free; if `origin/main` has moved past 227, use the next free number everywhere this plan says 228 (constants, `if (from < 228)`, test file names, comments) and relax the then-newest rung's exact-version test instead of v227's.
- `minimumCompatibleSchemaVersion` stays **224**. New tables never raise it.
- Entity type strings: `'equipmentShares'` and `'equipmentOwnershipEvents'`. Event kinds stored as TEXT: `'shared'`, `'unshared'`, `'transferred'` (PR 2 writes only the first two).
- A share row never names the item's own owner. The repository enforces it; SQLite cannot.
- Owner-only actions: delete, and managing shares. Everything else is open to a sharee. "Owner-only" is an accident guard, not a security boundary.
- Every sharing surface (chips, picker section, Shared with row, bulk Share, Owner filter chips, table column default, History card, Settings row) appears only when two or more diver profiles exist: `ref.watch(allDiversProvider).maybeWhen(data: (d) => d.length >= 2, orElse: () => false)`.
- `markRecordPending` goes after any `_db.batch` closure, never inside it. Deletes write a tombstone with `SyncRepository.logDeletion(entityType:, recordId:)`, because SQLite cascades write none.
- Every provider that calls a repository method subscribes with `ref.invalidateSelfWhen(repo.watchXChanges())` (guard: `test/architecture/provider_change_tick_test.dart`), and each new tick-subscribing provider gets a case in `test/architecture/provider_tick_build_smoke_test.dart`.
- Dates in UI go through `UnitFormatter(ref.watch(settingsProvider)).formatDate(...)` (guard: `test/architecture/preference_aware_date_format_test.dart`).
- Every new ARB key is added to all 11 files in `lib/l10n/arb/` (`app_en.arb` plus ar, de, es, fr, he, hu, it, nl, pt, zh) with a real translation, then `flutter gen-l10n` is run and the generated `app_localizations*.dart` files are committed. Guard: `test/l10n/arb_parity_test.dart`.
- No em dashes or en dashes used as punctuation anywhere: code, comments, ARB strings, commit messages, PR text. No mention of Claude, Claude Code or Anthropic in any commit or PR text, and no `Co-Authored-By` trailer.
- Paths in tests and code are built with `p.join`, never with a literal `/`.
- `*.g.dart` files are git-ignored: after any Drift table change run `dart run build_runner build --delete-conflicting-outputs`, and never stage `.g.dart` files.
- Stage explicit paths only (`git add <path> ...`), never `git add -A` or `git add -u`.
- After every task: `dart format .` then `flutter analyze` must report no issues (infos are fatal in CI).
- After any task that adds a file under `lib/`: `flutter test test/architecture/`.
- Tests are written first and must fail before the implementation step.

## Review Focus

1. **A sharee tries to delete a shared item** (detail page overflow, bulk delete, or any path that reaches the notifier): the item must survive and the user must learn why. Pinned by the repository guard test in Task 5 and the bulk delete skip test in Task 12.
2. **A shared item's service schedule uses the owner's custom service kind**: the sharee must still see the clock with its name and get its reminder, because `ServiceDueEngine` silently skips a schedule whose kind is missing from the list it is given. Pinned in Task 6.
3. **Two devices share the same item with the same profile before syncing** (two share rows, same pair, different ids): the peer must converge on one row without a unique-index failure. Pinned by the concurrent-pair test in Task 2.
4. **Merging diver profiles when the keeper already has a share of an item the duplicate also has, or owns an item shared with the duplicate**: no unique-index throw, no self-share, and undo restores the removed rows. Pinned in Task 7.
5. **A profile an item is shared with is deleted**: its share rows go with tombstones, the owner keeps the item, and the History card keeps the event reading "a deleted profile". Pinned in Task 7 (delete) and Task 16 (display).

---

## File Structure

**New files**

| Path | Responsibility |
| --- | --- |
| `lib/core/database/equipment_share_uniqueness.dart` | Unique `(equipment_id, diver_id)` index on `equipment_shares`, collapse-then-create assert. |
| `lib/features/equipment/domain/entities/equipment_share.dart` | `EquipmentShare` value type. |
| `lib/features/equipment/domain/entities/equipment_ownership_event.dart` | `EquipmentOwnershipEvent` value type and `EquipmentOwnershipEventKind` enum. |
| `lib/features/equipment/data/repositories/equipment_share_repository.dart` | Shares and the event log: read, share, unshare, set, bulk share, share all; writes events in the same transaction. |
| `lib/features/equipment/presentation/providers/equipment_share_providers.dart` | `equipmentShareRepositoryProvider`, `equipmentSharesProvider`, `equipmentOwnershipEventsProvider`, `diverNamesByIdProvider`, `hasMultipleDiversProvider`. |
| `lib/features/equipment/domain/services/equipment_history_builder.dart` | Pure: folds usage dives and events into newest-first history entries. |
| `lib/features/equipment/presentation/providers/equipment_history_providers.dart` | `equipmentHistoryProvider(equipmentId)`. |
| `lib/features/equipment/presentation/widgets/equipment_owner_chip.dart` | Small chip naming an item's owner. |
| `lib/features/equipment/presentation/widgets/profile_checklist_dialog.dart` | Reusable multi-select diver profile dialog. |
| `lib/features/equipment/presentation/widgets/equipment_sharing_row.dart` | Detail page "Shared with" / "Owned by" row. |
| `lib/features/equipment/presentation/widgets/equipment_history_card.dart` | Detail page History card. |
| `test/...` | One test file per unit, named in each task. |

**Modified files (main ones)**

`lib/core/database/database.dart`, `lib/core/database/performance_indexes.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/conflict_reference.dart`, `lib/core/data/visibility/visibility_filter.dart`, `lib/features/equipment/data/repositories/equipment_repository_impl.dart`, `lib/features/equipment/presentation/providers/equipment_providers.dart`, `lib/features/equipment/presentation/pages/equipment_edit_page.dart`, `lib/features/equipment/data/services/equipment_findings_pass.dart`, `lib/features/notifications/data/services/notification_scheduler.dart`, `lib/features/divers/data/repositories/diver_delete_steps.dart`, `lib/features/divers/data/repositories/diver_merge_repository.dart`, `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart`, `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `lib/features/equipment/presentation/pages/equipment_detail_page.dart`, `lib/features/equipment/presentation/widgets/equipment_list_content.dart`, `lib/features/equipment/domain/models/equipment_filter_state.dart`, `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`, `lib/features/equipment/domain/constants/equipment_field.dart`, `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`, `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/l10n/arb/*.arb`.

---

## Task 0: Preflight

**Files:** none changed.

- [ ] **Step 1: Confirm the worktree is initialized**

Run: `git submodule status | head -3 && ls .dart_tool/package_config.json && ls lib/core/database/database.g.dart`
Expected: three existing paths, no "No such file". If any is missing run `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Confirm schema rung 228 is free**

Run: `git fetch -q origin main && git show origin/main:lib/core/database/database.dart | grep -n "static const int currentSchemaVersion"`
Expected: `currentSchemaVersion = 227;`. If it is higher, merge `origin/main` into the branch first (`git merge origin/main`), then use the next free number for every "228" in this plan.

- [ ] **Step 3: Confirm a clean baseline**

Run: `flutter analyze` then `flutter test test/features/equipment test/core/services/sync test/core/database/migration_v227_hidden_tank_presets_test.dart`
Expected: no analyzer issues, all tests pass. If anything fails on the untouched branch, stop and report it; do not fix unrelated failures in this PR.

---

## Task 1: Schema v228, the two tables and their indexes

**Files:**
- Create: `lib/core/database/equipment_share_uniqueness.dart`
- Modify: `lib/core/database/database.dart` (tables after `EquipmentTags` ~line 2720; `@DriftDatabase` list ~line 4239; `currentSchemaVersion` line 4302; `migrationVersions` end ~line 4963; `_assertChildHlcColumns` ~line 5383; new helper next to `_assertEquipmentTagSchema` ~line 8533; `onCreate` ~line 8897; `onUpgrade` end ~line 12581; `beforeOpen` backstops ~line 12714)
- Modify: `lib/core/database/performance_indexes.dart` (`kPerformanceIndexes`, near the `idx_equipment_components_parent` entry ~line 190)
- Modify: `test/core/database/migration_v227_hidden_tank_presets_test.dart:29-35`
- Test: `test/core/database/migration_v228_equipment_sharing_test.dart`

**Interfaces:**
- Produces: Drift tables `equipmentShares` (row class `EquipmentShareRow`, companion `EquipmentSharesCompanion`) with columns `id, equipmentId, diverId, createdAt, hlc`; `equipmentOwnershipEvents` (row class `EquipmentOwnershipEventRow`, companion `EquipmentOwnershipEventsCompanion`) with columns `id, equipmentId, kind, fromDiverId, toDiverId, occurredAt, hlc`. Constants `kEquipmentSharesUniqueIndexName`, function `Future<void> assertEquipmentShareUniqueness(DatabaseConnectionUser db)`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v228_equipment_sharing_test.dart`. Copy the helpers `setupDb`, `columnsOf`, `tableInfo` and `ddlOf` verbatim from `test/core/database/migration_v219_equipment_tags_test.dart`, then change `setupDb`'s default `userVersion` to `227`. Then add these tests inside `main()`:

```dart
  test('v228 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 228);
    expect(AppDatabase.migrationVersions, contains(228));
    expect(AppDatabase.migrationStepCount(227), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds equipment_shares and equipment_ownership_events', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'equipment_shares'),
      containsAll(['id', 'equipment_id', 'diver_id', 'created_at', 'hlc']),
    );
    expect(
      await columnsOf(db, 'equipment_ownership_events'),
      containsAll([
        'id',
        'equipment_id',
        'kind',
        'from_diver_id',
        'to_diver_id',
        'occurred_at',
        'hlc',
      ]),
    );
  });

  test('shares cascade from item and diver; events detach from a diver', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final shares = await ddlOf(db, 'table', 'equipment_shares');
    expect(shares, contains('REFERENCES equipment (id) ON DELETE CASCADE'));
    expect(shares, contains('REFERENCES divers (id) ON DELETE CASCADE'));
    final events = await ddlOf(db, 'table', 'equipment_ownership_events');
    expect(events, contains('REFERENCES equipment (id) ON DELETE CASCADE'));
    expect(events, contains('REFERENCES divers (id) ON DELETE SET NULL'));
  });

  test('creates the share unique index and both lookup indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await ddlOf(db, 'index', kEquipmentSharesUniqueIndexName), isNotNull);
    expect(await ddlOf(db, 'index', 'idx_equipment_shares_diver'), isNotNull);
    expect(
      await ddlOf(db, 'index', 'idx_equipment_ownership_events_equipment'),
      isNotNull,
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(upgraded.close);
    addTearDown(fresh.close);
    for (final table in const ['equipment_shares', 'equipment_ownership_events']) {
      expect(await tableInfo(upgraded, table), await tableInfo(fresh, table));
    }
    expect(
      await ddlOf(upgraded, 'index', kEquipmentSharesUniqueIndexName),
      await ddlOf(fresh, 'index', kEquipmentSharesUniqueIndexName),
    );
  });

  test('a database stamped v228 without the schema heals in beforeOpen', () async {
    final db = AppDatabase(setupDb(userVersion: 228));
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_shares'), contains('diver_id'));
    expect(await columnsOf(db, 'equipment_ownership_events'), contains('kind'));
    expect(await ddlOf(db, 'index', kEquipmentSharesUniqueIndexName), isNotNull);
  });

  test('a fixture without an equipment table skips both tables', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_shares'), isEmpty);
    expect(await columnsOf(db, 'equipment_ownership_events'), isEmpty);
  });

  test('a duplicate share pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('d1','d1',0,0)",
    );
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('d2','d2',0,0)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at, diver_id) "
      "VALUES ('e1','e1','bcd',0,0,'d1')",
    );
    await db.customStatement(
      "INSERT INTO equipment_shares (id, equipment_id, diver_id, created_at) "
      "VALUES ('s1','e1','d2',0)",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO equipment_shares (id, equipment_id, diver_id, created_at) "
        "VALUES ('s2','e1','d2',1)",
      ),
      throwsA(anything),
    );
  });
```

Add imports at the top: `import 'package:submersion/core/database/equipment_share_uniqueness.dart';` alongside the ones copied from the v219 test.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/core/database/migration_v228_equipment_sharing_test.dart`
Expected: compile error, `equipment_share_uniqueness.dart` not found.

- [ ] **Step 3: Create the uniqueness file**

`lib/core/database/equipment_share_uniqueness.dart`:

```dart
import 'package:drift/drift.dart';

/// The (equipment_id, diver_id) unique index on `equipment_shares` (v228,
/// issue #2046). With the index in place an unguarded duplicate insert
/// throws, so every writer uses `DoNothing`.
const String kEquipmentSharesUniqueIndexName =
    'idx_equipment_shares_equipment_diver_unique';

const String kCreateEquipmentSharesUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kEquipmentSharesUniqueIndexName '
    'ON equipment_shares(equipment_id, diver_id)';

/// Keeps the oldest row of each (item, diver) pair, `id` breaking ties, so
/// every device lands on the same survivor.
const String _collapseDuplicateSharePairsSql = '''
  DELETE FROM equipment_shares WHERE rowid IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY equipment_id, diver_id ORDER BY created_at ASC, id ASC
      ) AS rn FROM equipment_shares
    ) WHERE rn > 1
  )
''';

Future<bool> _exists(DatabaseConnectionUser db, String type, String name) async =>
    (await db
            .customSelect(
              'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
              variables: [Variable<String>(type), Variable<String>(name)],
            )
            .get())
        .isNotEmpty;

/// Creates the share pair index when missing, collapsing any duplicate pairs
/// first so the create cannot fail. A no-op before the table exists.
Future<void> assertEquipmentShareUniqueness(DatabaseConnectionUser db) async {
  if (!await _exists(db, 'table', 'equipment_shares')) return;
  if (await _exists(db, 'index', kEquipmentSharesUniqueIndexName)) return;
  await db.customStatement(_collapseDuplicateSharePairsSql);
  await db.customStatement(kCreateEquipmentSharesUniqueIndexSql);
}
```

- [ ] **Step 4: Add the two Drift tables**

In `lib/core/database/database.dart`, directly after the `EquipmentTags` class:

```dart
/// Diver profiles an equipment item is shared with (v228, issue #2046). The
/// owner stays `equipment.diver_id`; a row here makes the item visible to
/// [diverId] too. Surrogate uuid primary key like [EquipmentTags]; the
/// (equipment_id, diver_id) unique index lives in
/// equipment_share_uniqueness.dart. The repository never writes a row that
/// names the item's own owner.
@DataClassName('EquipmentShareRow')
class EquipmentShares extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Append-only log of an item's share and ownership changes (v228, issue
/// #2046): `shared`, `unshared`, and `transferred` from the transfer work.
/// Diver references are SET NULL, so deleting a profile keeps the event,
/// read as "a deleted profile". No row is ever updated.
@DataClassName('EquipmentOwnershipEventRow')
class EquipmentOwnershipEvents extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get fromDiverId => text().nullable().references(
    Divers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get toDiverId => text().nullable().references(
    Divers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get occurredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
```

In the `@DriftDatabase(tables: [...])` list, directly after `EquipmentTags,`:

```dart
    // Equipment sharing and its event log (v228, issue #2046)
    EquipmentShares,
    EquipmentOwnershipEvents,
```

Add `import 'package:submersion/core/database/equipment_share_uniqueness.dart';` next to the existing `tag_uniqueness.dart` import.

- [ ] **Step 5: Add the rung**

1. `static const int currentSchemaVersion = 228;`
2. At the end of `migrationVersions` (after `227,`):

```dart
    // v228: equipment sharing (issue #2046). Two tables, equipment_shares
    // with its (equipment_id, diver_id) unique index and
    // equipment_ownership_events, plus two lookup indexes. Additive only, so
    // the compatibility floor stays.
    228,
```

3. In `_assertChildHlcColumns`, add `'equipment_shares',` and `'equipment_ownership_events',` after `'equipment_tags',`.
4. After `_assertEquipmentTagSchema`, add:

```dart
  /// Idempotent creation of the v228 equipment sharing schema (issue #2046):
  /// `equipment_shares` with its (equipment, diver) unique index, and
  /// `equipment_ownership_events`. Called from the v228 rung and the
  /// beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain tables
  /// whose foreign keys point nowhere.
  Future<void> _assertEquipmentSharingSchema() async {
    for (final parent in const ['equipment', 'divers']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await createMigrator().createTable(equipmentShares);
    await createMigrator().createTable(equipmentOwnershipEvents);
    await assertEquipmentShareUniqueness(this);
  }
```

5. In `onCreate`, after `await assertEquipmentTagUniqueness(this);`:

```dart
        // Equipment share pair unique index (v228, issue #2046), for the
        // same reason: createAll() never builds raw-SQL indexes.
        await assertEquipmentShareUniqueness(this);
```

6. At the end of `onUpgrade`, after the v227 block:

```dart
        // v228: equipment sharing (issue #2046). Table-only rung, no
        // backfill: no existing row changes.
        if (from < 228) {
          await _assertEquipmentSharingSchema();
        }
        if (from < 228) await reportProgress();
```

7. In `beforeOpen`, after the v221 backstop:

```dart
        // v228 backstop: the equipment sharing tables and the share pair
        // index (parallel-branch version-collision self-heal; all
        // idempotent).
        await _assertEquipmentSharingSchema();
```

- [ ] **Step 6: Add the lookup indexes**

In `lib/core/database/performance_indexes.dart`, inside `kPerformanceIndexes`, after the `idx_equipment_components_parent` entry:

```dart
  // Visibility subquery "items shared with this diver" (v228, issue #2046).
  (
    name: 'idx_equipment_shares_diver',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_shares_diver '
        'ON equipment_shares(diver_id)',
  ),
  // An item's history, oldest first (v228, issue #2046).
  (
    name: 'idx_equipment_ownership_events_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_ownership_events_equipment '
        'ON equipment_ownership_events(equipment_id, occurred_at)',
  ),
```

- [ ] **Step 7: Relax the v227 exact assertion**

In `test/core/database/migration_v227_hidden_tank_presets_test.dart` lines 29-35 replace the test body with:

```dart
  test('v227 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(227));
    expect(AppDatabase.migrationVersions, contains(227));
    expect(AppDatabase.migrationStepCount(226), greaterThanOrEqualTo(1));
  });
```

- [ ] **Step 8: Regenerate and run**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/database/migration_v228_equipment_sharing_test.dart test/core/database/migration_v227_hidden_tank_presets_test.dart test/core/database/performance_indexes_test.dart`
Expected: all pass.

- [ ] **Step 9: Run the sync census to see what Task 2 must fix**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart`
Expected: FAIL naming `equipment_shares` and `equipment_ownership_events` (tables with `hlc` not in `hlcTargets`). That is expected and Task 2 fixes it. Commit Task 1 anyway: the branch is not pushed until Task 19, so one intermediate red census commit is fine.

- [ ] **Step 10: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database/equipment_share_uniqueness.dart lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v228_equipment_sharing_test.dart test/core/database/migration_v227_hidden_tank_presets_test.dart
git commit -m "feat(equipment): add the equipment sharing tables (v228)"
```

---

## Task 2: Sync registration for both tables

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets` ~line 152)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~line 1571; `entityHasUpdatedAt` ~line 2415; `parentRefs` ~line 2614)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`SyncData` field ~339, ctor ~430, `toJson` ~520, `fromJson` ~615, `_baseTables` ~1095, `parentGatedChildEntities` ~1494, `parentGatedTables` ~1636, `_buildSyncData` ~2143, exporters ~7496, `fetchRecord` ~2608, `upsertRecord` ~3949, `upsertRecords` ~4989, `recordIdsFor` ~5460, `_syncTableFor` ~5837, `deleteRecord` ~6256)
- Modify: `lib/core/services/sync/conflict_reference.dart` (`_defaultTargets` ~line 77)
- Modify census lists: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`), `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (`targets`), `test/core/services/sync/sync_serializer_fetch_record_test.dart` (`simpleTypes`, `targets`)
- Test: `test/core/services/sync/equipment_sharing_sync_test.dart`

**Interfaces:**
- Consumes: Task 1 tables.
- Produces: entity types `'equipmentShares'` and `'equipmentOwnershipEvents'` registered everywhere a synced parent-gated child is; `SyncData.equipmentShares` and `SyncData.equipmentOwnershipEvents` (`List<Map<String, dynamic>>`).

Model every change on the existing `equipmentTags` lines named in each step (use the siteSiteTypes shape for `equipmentShares` upserts, because its pair is unique and two devices can mint different ids for one pair).

- [ ] **Step 1: Write the failing round-trip test**

Create `test/core/services/sync/equipment_sharing_sync_test.dart`. Base it on `test/core/services/sync/equipment_tags_sync_test.dart` (copy its imports, `setUp`, `tearDown` and serializer construction), then write:

```dart
  Future<void> seedParents() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'bcd',
        name: 'BCD',
        type: 'bcd',
        createdAt: t,
        updatedAt: t,
        diverId: const Value('owner'),
      ),
    );
  }

  test('a share row round-trips through fetchRecord and upsertRecord', () async {
    await seedParents();
    await db.into(db.equipmentShares).insert(
      EquipmentSharesCompanion.insert(
        id: 's1', equipmentId: 'bcd', diverId: 'wife', createdAt: 1,
      ),
    );
    final json = await serializer.fetchRecord('equipmentShares', 's1');
    expect(json, isNotNull);
    await serializer.deleteRecord('equipmentShares', 's1');
    expect(await serializer.fetchRecord('equipmentShares', 's1'), isNull);
    await serializer.upsertRecord('equipmentShares', json!);
    expect(await serializer.fetchRecord('equipmentShares', 's1'), isNotNull);
  });

  test('an event row round-trips with null diver ids', () async {
    await seedParents();
    await db.into(db.equipmentOwnershipEvents).insert(
      EquipmentOwnershipEventsCompanion.insert(
        id: 'ev1', equipmentId: 'bcd', kind: 'shared', occurredAt: 5,
        fromDiverId: const Value('owner'),
      ),
    );
    final json = await serializer.fetchRecord('equipmentOwnershipEvents', 'ev1');
    expect(json?['toDiverId'], isNull);
    await serializer.deleteRecord('equipmentOwnershipEvents', 'ev1');
    await serializer.upsertRecords('equipmentOwnershipEvents', [json!]);
    expect(
      await serializer.fetchRecord('equipmentOwnershipEvents', 'ev1'),
      isNotNull,
    );
  });

  test('a peer pair under another id converges on one row', () async {
    await seedParents();
    await db.into(db.equipmentShares).insert(
      EquipmentSharesCompanion.insert(
        id: 'zzz-local', equipmentId: 'bcd', diverId: 'wife', createdAt: 1,
      ),
    );
    await serializer.upsertRecords('equipmentShares', [
      {'id': 'aaa-peer', 'equipmentId': 'bcd', 'diverId': 'wife', 'createdAt': 2, 'hlc': null},
    ]);
    final rows = await db.select(db.equipmentShares).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'aaa-peer');
  });

  test('an equipment tombstone drops its shares and events on the peer', () async {
    await seedParents();
    await db.into(db.equipmentShares).insert(
      EquipmentSharesCompanion.insert(
        id: 's1', equipmentId: 'bcd', diverId: 'wife', createdAt: 1,
      ),
    );
    await db.into(db.equipmentOwnershipEvents).insert(
      EquipmentOwnershipEventsCompanion.insert(
        id: 'ev1', equipmentId: 'bcd', kind: 'shared', occurredAt: 1,
      ),
    );
    await serializer.deleteRecord('equipment', 'bcd');
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    expect(await db.select(db.equipmentOwnershipEvents).get(), isEmpty);
  });

  test('a divers tombstone drops shares and nulls event divers', () async {
    await seedParents();
    await db.into(db.equipmentShares).insert(
      EquipmentSharesCompanion.insert(
        id: 's1', equipmentId: 'bcd', diverId: 'wife', createdAt: 1,
      ),
    );
    await db.into(db.equipmentOwnershipEvents).insert(
      EquipmentOwnershipEventsCompanion.insert(
        id: 'ev1', equipmentId: 'bcd', kind: 'shared', occurredAt: 1,
        fromDiverId: const Value('owner'), toDiverId: const Value('wife'),
      ),
    );
    await serializer.deleteRecord('divers', 'wife');
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    final event = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(event.toDiverId, isNull);
    expect(event.fromDiverId, 'owner');
  });
```

The converge test asserts the lower id wins, matching `_reconcileJunctionIds` for `site_site_types` (issue #2003). If `deleteRecord('divers', ...)` in this codebase runs with foreign keys off, replace that test's expectations with a call to `serializer.repairDanglingForeignKeys()` (the method `applyInDeferredFkTransaction` uses) before the asserts, and note it in the commit message.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/core/services/sync/equipment_sharing_sync_test.dart`
Expected: FAIL (unknown entity type `equipmentShares` in `fetchRecord`, or a `recordIdsFor` throw).

- [ ] **Step 3: Register in `sync_repository.dart`**

In `hlcTargets`, after `'equipmentTags': ...`:

```dart
    'equipmentShares': (table: 'equipment_shares', pk: 'id'),
    'equipmentOwnershipEvents': (
      table: 'equipment_ownership_events',
      pk: 'id',
    ),
```

- [ ] **Step 4: Register in `sync_service.dart`**

1. `mergeOrder`, after the `equipmentTags` entry:

```dart
          // After both parents (equipment and divers), issue #2046.
          (
            type: 'equipmentShares',
            records: data.equipmentShares,
            hasUpdatedAt: false,
          ),
          (
            type: 'equipmentOwnershipEvents',
            records: data.equipmentOwnershipEvents,
            hasUpdatedAt: false,
          ),
```

2. `entityHasUpdatedAt`, after `'equipmentTags': false,`: `'equipmentShares': false,` and `'equipmentOwnershipEvents': false,`.
3. `parentRefs`, after the `equipmentTags` entry:

```dart
    // v228: equipment sharing (issue #2046). The diver keys are left to
    // repairDanglingForeignKeys like every diverId (see the note above).
    'equipmentShares': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
    'equipmentOwnershipEvents': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
```

- [ ] **Step 5: Register in `sync_data_serializer.dart`**

Add, each next to its `equipmentTags` twin:

1. Fields: `final List<Map<String, dynamic>> equipmentShares;` and `final List<Map<String, dynamic>> equipmentOwnershipEvents;`
2. Constructor: `this.equipmentShares = const [],` and `this.equipmentOwnershipEvents = const [],`
3. `toJson`: `'equipmentShares': equipmentShares,` and `'equipmentOwnershipEvents': equipmentOwnershipEvents,`
4. `fromJson`: `equipmentShares: _parseList(json['equipmentShares']),` and `equipmentOwnershipEvents: _parseList(json['equipmentOwnershipEvents']),`
5. `_baseTables`:

```dart
      (key: 'equipmentShares', table: _db.equipmentShares, blob: false, full: null),
      (
        key: 'equipmentOwnershipEvents',
        table: _db.equipmentOwnershipEvents,
        blob: false,
        full: null,
      ),
```

6. `parentGatedChildEntities`: `'equipmentShares',` and `'equipmentOwnershipEvents',`
7. `parentGatedTables`: `'equipmentShares': 'equipment_shares',` and `'equipmentOwnershipEvents': 'equipment_ownership_events',`
8. `_buildSyncData`, after the `equipmentTags:` export:

```dart
        equipmentShares: await _safeExport(
          'equipmentShares',
          () async => _withPendingChildren(
            'equipmentShares',
            await _exportEquipmentChildren(_db.equipmentShares, hlcSince),
            pendingChildren,
          ),
        ),
        equipmentOwnershipEvents: await _safeExport(
          'equipmentOwnershipEvents',
          () async => _withPendingChildren(
            'equipmentOwnershipEvents',
            await _exportEquipmentChildren(
              _db.equipmentOwnershipEvents,
              hlcSince,
            ),
            pendingChildren,
          ),
        ),
```

9. Next to `_exportEquipmentTags`, a shared exporter for tables keyed by `equipment_id` (both new tables have that column; Drift exposes it as `equipmentId` on each):

```dart
  /// The rows of an `equipment_id`-keyed child table, gated on the parent's
  /// clock like [_exportEquipmentTags]: with [hlcSince], only the children
  /// of items modified since then (pending children are added by the
  /// caller).
  Future<List<Map<String, dynamic>>> _exportEquipmentChildren<
    T extends Table,
    R extends DataClass
  >(TableInfo<T, R> table, String? hlcSince) async {
    final equipmentId = table.columnsByName['equipment_id']! as Expression<String>;
    if (hlcSince != null) {
      final modifiedItems = await (_db.select(
        _db.equipment,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final itemIds = modifiedItems.map((e) => e.id).toSet();
      if (itemIds.isEmpty) return [];
      return _childRowsOf(
        itemIds,
        (chunk) =>
            (_db.select(table)..where((_) => equipmentId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(table).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

If `_childRowsOf`'s callback type does not accept this generic form, write two concrete exporters `_exportEquipmentShares` and `_exportEquipmentOwnershipEvents` by copying `_exportEquipmentTags` and swapping the table.

10. `fetchRecord`:

```dart
      case 'equipmentShares':
        final row = await (_db.select(
          _db.equipmentShares,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'equipmentOwnershipEvents':
        final row = await (_db.select(
          _db.equipmentOwnershipEvents,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

11. `upsertRecord`:

```dart
      case 'equipmentShares':
        await _applyEquipmentShareRecord(EquipmentShareRow.fromJson(data));
        return;
      case 'equipmentOwnershipEvents':
        await _db
            .into(_db.equipmentOwnershipEvents)
            .insertOnConflictUpdate(EquipmentOwnershipEventRow.fromJson(data));
        return;
```

with, next to `_applySiteSiteTypeRecord`:

```dart
  /// Applies one incoming `equipment_shares` row (v228, issue #2046). The
  /// (item, diver) pair is unique, so a peer's copy of a pair this device
  /// holds under another id is reconciled to the lower id and then skipped
  /// with DO NOTHING, as [_applySiteSiteTypeRecord] does.
  Future<void> _applyEquipmentShareRecord(EquipmentShareRow record) async {
    await _reconcileJunctionIds(
      'equipment_shares',
      parentColumn: 'equipment_id',
      childColumn: 'diver_id',
      pairs: [
        (parent: record.equipmentId, child: record.diverId, id: record.id),
      ],
    );
    await _db
        .into(_db.equipmentShares)
        .insert(
          record,
          onConflict: DoNothing<$EquipmentSharesTable, EquipmentShareRow>(
            target: const [],
          ),
        );
  }
```

12. `upsertRecords`:

```dart
      case 'equipmentShares':
        // DoNothing: see [_applyEquipmentShareRecord].
        final shareRows = _lowestIdPerPair(
          records.map((r) => EquipmentShareRow.fromJson(r)).toList(),
          (row) => (parent: row.equipmentId, child: row.diverId, id: row.id),
        );
        await _reconcileJunctionIds(
          'equipment_shares',
          parentColumn: 'equipment_id',
          childColumn: 'diver_id',
          pairs: [
            for (final row in shareRows)
              (parent: row.equipmentId, child: row.diverId, id: row.id),
          ],
        );
        await _db.batch(
          (b) => b.insertAll(
            _db.equipmentShares,
            shareRows,
            onConflict: DoNothing<$EquipmentSharesTable, EquipmentShareRow>(
              target: const [],
            ),
          ),
        );
        return;
      case 'equipmentOwnershipEvents':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentOwnershipEvents,
            records.map((r) => EquipmentOwnershipEventRow.fromJson(r)).toList(),
          ),
        );
        return;
```

13. `recordIdsFor`:

```dart
      case 'equipmentShares':
        return plain(_db.equipmentShares, _db.equipmentShares.id);
      case 'equipmentOwnershipEvents':
        return plain(
          _db.equipmentOwnershipEvents,
          _db.equipmentOwnershipEvents.id,
        );
```

14. `_syncTableFor`: `case 'equipmentShares': return _db.equipmentShares;` and `case 'equipmentOwnershipEvents': return _db.equipmentOwnershipEvents;`
15. `deleteRecord`:

```dart
      case 'equipmentShares':
        await (_db.delete(
          _db.equipmentShares,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'equipmentOwnershipEvents':
        await (_db.delete(
          _db.equipmentOwnershipEvents,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 6: Conflict reference map**

In `lib/core/services/sync/conflict_reference.dart` `_defaultTargets`, add `'fromDiverId': 'divers',` and `'toDiverId': 'divers',`.

- [ ] **Step 7: Update the census lists**

1. `sync_parent_refs_completeness_test.dart` `syncedTables`: `'equipment_shares': 'equipmentShares',` and `'equipment_ownership_events': 'equipmentOwnershipEvents',`
2. `sync_data_serializer_batch_coverage_test.dart` `targets`: `(type: 'equipmentShares', table: db.equipmentShares.actualTableName),` and `(type: 'equipmentOwnershipEvents', table: db.equipmentOwnershipEvents.actualTableName),`
3. `sync_serializer_fetch_record_test.dart` `simpleTypes`: `'equipmentShares',` and `'equipmentOwnershipEvents',`; add the same two to `targets` in "fetches a seeded row for each single-PK entity type".

- [ ] **Step 8: Run the sync suite**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/services/sync test/core/database`
Expected: all pass, including `sync_hlc_target_registration_test`, `child_hlc_test`, `pending_child_export_test`, `sync_base_streaming_parity_test`, `sync_data_serializer_record_ids_test` and the new file.

- [ ] **Step 9: Commit**

```bash
dart format lib/core test/core
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_service.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/conflict_reference.dart test/core/services/sync/equipment_sharing_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart
git commit -m "feat(sync): sync equipment shares and ownership events"
```

---

## Task 3: Share entities, `EquipmentShareRepository` and its providers

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_share.dart`
- Create: `lib/features/equipment/domain/entities/equipment_ownership_event.dart`
- Create: `lib/features/equipment/data/repositories/equipment_share_repository.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_share_providers.dart`
- Modify: `test/architecture/repository_tick_stream_test.dart` (stream map ~line 180, plus a `fires` test)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (`_tickGroup('equipment', ...)` ~line 522)
- Test: `test/features/equipment/data/repositories/equipment_share_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 tables.
- Produces:
  - `class EquipmentShare { String id; String equipmentId; String diverId; DateTime createdAt; }`
  - `enum EquipmentOwnershipEventKind { shared, unshared, transferred }` with `static EquipmentOwnershipEventKind? fromName(String name)`
  - `class EquipmentOwnershipEvent { String id; String equipmentId; EquipmentOwnershipEventKind kind; String? fromDiverId; String? toDiverId; DateTime occurredAt; }`
  - `class EquipmentShareResult { int added; int removed; int skippedNotOwned; int rejected; int itemsChanged; }` (`added` counts (item, profile) pairs, `itemsChanged` counts items)
  - `EquipmentShareRepository`: `Stream<void> watchChanges()`, `Future<List<EquipmentShare>> getSharesFor(String equipmentId)`, `Future<Map<String, List<EquipmentShare>>> getSharesForItems(Iterable<String> equipmentIds)`, `Future<List<EquipmentOwnershipEvent>> getEventsFor(String equipmentId)`, `Future<EquipmentShareResult> shareMany({required List<String> equipmentIds, required List<String> diverIds, required String actingDiverId})`, `Future<EquipmentShareResult> setShares({required String equipmentId, required Set<String> diverIds, required String actingDiverId})`, `Future<EquipmentShareResult> unshare({required String equipmentId, required String diverId, required String actingDiverId})`, `Future<EquipmentShareResult> shareAllForDiver({required String ownerId, required List<String> diverIds})`
  - Providers: `equipmentShareRepositoryProvider`, `equipmentSharesProvider` (family by equipment id), `equipmentOwnershipEventsProvider` (family by equipment id), `diverNamesByIdProvider` (`FutureProvider<Map<String, String>>`), `hasMultipleDiversProvider` (`Provider<bool>`)

- [ ] **Step 1: Write the failing repository test**

`test/features/equipment/data/repositories/equipment_share_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentShareRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentShareRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife', 'son']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    for (final (id, owner) in [('bcd', 'owner'), ('reg', 'owner'), ('mask', 'wife')]) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id, name: id, type: 'bcd', createdAt: t, updatedAt: t,
          diverId: Value(owner),
        ),
      );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.customSelect(
      'SELECT record_id FROM sync_records WHERE entity_type = ?',
      variables: [Variable<String>(entityType)],
    ).get())
      r.read<String>('record_id'),
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('shareMany adds one row and one shared event per pair', () async {
    final result = await repo.shareMany(
      equipmentIds: ['bcd', 'reg'],
      diverIds: ['wife', 'son'],
      actingDiverId: 'owner',
    );
    expect(result.added, 4);
    expect(result.itemsChanged, 2);
    final shares = await repo.getSharesForItems(['bcd', 'reg']);
    expect({for (final s in shares['bcd']!) s.diverId}, {'wife', 'son'});
    final events = await repo.getEventsFor('bcd');
    expect(events, hasLength(2));
    expect(events.every((e) => e.kind == EquipmentOwnershipEventKind.shared), isTrue);
    expect(events.every((e) => e.fromDiverId == 'owner'), isTrue);
    expect({for (final e in events) e.toDiverId}, {'wife', 'son'});
    expect(await pending('equipmentShares'), hasLength(4));
    expect(await pending('equipmentOwnershipEvents'), hasLength(4));
  });

  test('a share to the owner or to an unknown profile is rejected', () async {
    final result = await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['owner', 'ghost'],
      actingDiverId: 'owner',
    );
    expect(result.added, 0);
    expect(result.rejected, 2);
    expect(await repo.getSharesFor('bcd'), isEmpty);
    expect(await repo.getEventsFor('bcd'), isEmpty);
  });

  test('an existing pair is ignored and logs no second event', () async {
    await repo.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    final again = await repo.shareMany(
      equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner',
    );
    expect(again.added, 0);
    expect(await repo.getSharesFor('bcd'), hasLength(1));
    expect(await repo.getEventsFor('bcd'), hasLength(1));
  });

  test('a sharee cannot share or unshare an item it does not own', () async {
    await repo.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    final share = await repo.shareMany(
      equipmentIds: ['bcd', 'mask'], diverIds: ['son'], actingDiverId: 'wife',
    );
    expect(share.skippedNotOwned, 1);
    expect(share.added, 1); // the mask is the wife's own
    final unshare = await repo.unshare(
      equipmentId: 'bcd', diverId: 'wife', actingDiverId: 'wife',
    );
    expect(unshare.skippedNotOwned, 1);
    expect(await repo.getSharesFor('bcd'), hasLength(1));
  });

  test('unshare deletes the row, tombstones it and logs unshared', () async {
    await repo.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    final shareId = (await repo.getSharesFor('bcd')).single.id;
    final result = await repo.unshare(
      equipmentId: 'bcd', diverId: 'wife', actingDiverId: 'owner',
    );
    expect(result.removed, 1);
    expect(await repo.getSharesFor('bcd'), isEmpty);
    expect(await tombstones('equipmentShares'), contains(shareId));
    final events = await repo.getEventsFor('bcd');
    expect(events.map((e) => e.kind), [
      EquipmentOwnershipEventKind.shared,
      EquipmentOwnershipEventKind.unshared,
    ]);
    expect(events.last.toDiverId, 'wife');
  });

  test('setShares adds and removes to match, oldest event first', () async {
    await repo.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    final result = await repo.setShares(
      equipmentId: 'bcd', diverIds: {'son'}, actingDiverId: 'owner',
    );
    expect(result.added, 1);
    expect(result.removed, 1);
    expect({for (final s in await repo.getSharesFor('bcd')) s.diverId}, {'son'});
    final kinds = [for (final e in await repo.getEventsFor('bcd')) e.kind];
    expect(kinds.first, EquipmentOwnershipEventKind.shared);
    expect(kinds, containsAll([
      EquipmentOwnershipEventKind.unshared,
      EquipmentOwnershipEventKind.shared,
    ]));
  });

  test('shareAllForDiver shares only the owner items', () async {
    final result = await repo.shareAllForDiver(ownerId: 'owner', diverIds: ['son']);
    expect(result.added, 2);
    expect(result.itemsChanged, 2);
    expect(await repo.getSharesFor('mask'), isEmpty);
  });

  test('watchChanges fires on a share', () async {
    final fired = repo.watchChanges().first;
    await repo.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    await expectLater(fired, completes);
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_share_repository_test.dart`
Expected: compile error, the repository and entity files do not exist.

- [ ] **Step 3: Create the entities**

`lib/features/equipment/domain/entities/equipment_share.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A diver profile an equipment item is shared with (issue #2046). The
/// item's owner is never a share.
class EquipmentShare extends Equatable {
  final String id;
  final String equipmentId;
  final String diverId;
  final DateTime createdAt;

  const EquipmentShare({
    required this.id,
    required this.equipmentId,
    required this.diverId,
    required this.createdAt,
  });

  EquipmentShare copyWith({
    String? id,
    String? equipmentId,
    String? diverId,
    DateTime? createdAt,
  }) => EquipmentShare(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    diverId: diverId ?? this.diverId,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [id, equipmentId, diverId, createdAt];
}
```

`lib/features/equipment/domain/entities/equipment_ownership_event.dart`:

```dart
import 'package:equatable/equatable.dart';

/// What an [EquipmentOwnershipEvent] records. Stored by [name].
enum EquipmentOwnershipEventKind {
  shared,
  unshared,
  transferred;

  /// Null for a kind this build does not know (written by a newer peer), so
  /// readers can skip it instead of failing.
  static EquipmentOwnershipEventKind? fromName(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One entry of an item's append-only share and ownership log (issue
/// #2046). For [EquipmentOwnershipEventKind.shared] and `unshared`,
/// [fromDiverId] is the owner at the time and [toDiverId] the sharee; for
/// `transferred`, the old and the new owner. Either is null once that
/// profile is deleted.
class EquipmentOwnershipEvent extends Equatable {
  final String id;
  final String equipmentId;
  final EquipmentOwnershipEventKind kind;
  final String? fromDiverId;
  final String? toDiverId;
  final DateTime occurredAt;

  const EquipmentOwnershipEvent({
    required this.id,
    required this.equipmentId,
    required this.kind,
    this.fromDiverId,
    this.toDiverId,
    required this.occurredAt,
  });

  EquipmentOwnershipEvent copyWith({
    String? id,
    String? equipmentId,
    EquipmentOwnershipEventKind? kind,
    String? fromDiverId,
    String? toDiverId,
    DateTime? occurredAt,
  }) => EquipmentOwnershipEvent(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    kind: kind ?? this.kind,
    fromDiverId: fromDiverId ?? this.fromDiverId,
    toDiverId: toDiverId ?? this.toDiverId,
    occurredAt: occurredAt ?? this.occurredAt,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    kind,
    fromDiverId,
    toDiverId,
    occurredAt,
  ];
}
```

- [ ] **Step 4: Create the repository**

`lib/features/equipment/data/repositories/equipment_share_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';

/// Counts from one share operation, for the UI's partial-result messages.
class EquipmentShareResult {
  final int added;
  final int removed;

  /// Items skipped because the acting diver does not own them.
  final int skippedNotOwned;

  /// (item, profile) pairs refused: the profile owns the item or no longer
  /// exists.
  final int rejected;

  /// Items that gained at least one share, for "Shared N items" messages
  /// ([added] counts (item, profile) pairs).
  final int itemsChanged;

  const EquipmentShareResult({
    this.added = 0,
    this.removed = 0,
    this.skippedNotOwned = 0,
    this.rejected = 0,
    this.itemsChanged = 0,
  });

  EquipmentShareResult operator +(EquipmentShareResult other) =>
      EquipmentShareResult(
        added: added + other.added,
        removed: removed + other.removed,
        skippedNotOwned: skippedNotOwned + other.skippedNotOwned,
        rejected: rejected + other.rejected,
        itemsChanged: itemsChanged + other.itemsChanged,
      );
}

/// Equipment shares and the share/ownership event log (issue #2046).
///
/// Only an item's owner changes its shares. Every added share writes a
/// `shared` event and every removed share an `unshared` event, in the same
/// transaction. Writes never touch the `equipment` row (#1769: a child change
/// does not re-stamp its parent).
class EquipmentShareRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String sharesEntity = 'equipmentShares';
  static const String eventsEntity = 'equipmentOwnershipEvents';

  /// Ids bound per `IN (...)` list, under SQLite's 999-variable floor.
  static const int _idChunk = 900;

  /// Emits when a share or an event is written or removed.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.equipmentShares,
      _db.equipmentOwnershipEvents,
    ]),
  );

  Future<List<EquipmentShare>> getSharesFor(String equipmentId) async =>
      (await getSharesForItems([equipmentId]))[equipmentId] ?? const [];

  /// Shares keyed by item id; an item without shares is absent.
  Future<Map<String, List<EquipmentShare>>> getSharesForItems(
    Iterable<String> equipmentIds,
  ) async {
    final ids = equipmentIds.toSet().toList();
    final result = <String, List<EquipmentShare>>{};
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, (i + _idChunk).clamp(0, ids.length));
      final rows =
          await (_db.select(_db.equipmentShares)
                ..where((t) => t.equipmentId.isIn(chunk))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      for (final r in rows) {
        (result[r.equipmentId] ??= []).add(_toShare(r));
      }
    }
    return result;
  }

  /// [equipmentId]'s events, oldest first. Kinds this build does not know
  /// are skipped.
  Future<List<EquipmentOwnershipEvent>> getEventsFor(String equipmentId) async {
    final rows =
        await (_db.select(_db.equipmentOwnershipEvents)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.occurredAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final r in rows)
        if (EquipmentOwnershipEventKind.fromName(r.kind) case final kind?)
          EquipmentOwnershipEvent(
            id: r.id,
            equipmentId: r.equipmentId,
            kind: kind,
            fromDiverId: r.fromDiverId,
            toDiverId: r.toDiverId,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(r.occurredAt),
          ),
    ];
  }

  /// Shares every item in [equipmentIds] that [actingDiverId] owns with each
  /// of [diverIds]. Existing pairs are left alone.
  Future<EquipmentShareResult> shareMany({
    required List<String> equipmentIds,
    required List<String> diverIds,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final owners = await _ownersOf(equipmentIds);
      final known = await _existingDivers(diverIds);
      var total = const EquipmentShareResult();
      for (final id in equipmentIds.toSet()) {
        final owner = owners[id];
        if (owner != actingDiverId) {
          total += const EquipmentShareResult(skippedNotOwned: 1);
          continue;
        }
        var itemTotal = const EquipmentShareResult();
        for (final diverId in diverIds.toSet()) {
          itemTotal += await _add(id, owner!, diverId, known, now);
        }
        total += itemTotal;
        if (itemTotal.added > 0) {
          total += const EquipmentShareResult(itemsChanged: 1);
        }
      }
      return total;
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Makes [equipmentId]'s shares exactly [diverIds], for the owner's
  /// profile checklist.
  Future<EquipmentShareResult> setShares({
    required String equipmentId,
    required Set<String> diverIds,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final owner = (await _ownersOf([equipmentId]))[equipmentId];
      if (owner != actingDiverId) {
        return const EquipmentShareResult(skippedNotOwned: 1);
      }
      final current = {
        for (final s in await getSharesFor(equipmentId)) s.diverId,
      };
      final known = await _existingDivers(diverIds);
      var total = const EquipmentShareResult();
      for (final diverId in current.difference(diverIds)) {
        total += await _remove(equipmentId, owner!, diverId, now);
      }
      for (final diverId in diverIds.difference(current)) {
        total += await _add(equipmentId, owner!, diverId, known, now);
      }
      return total;
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  Future<EquipmentShareResult> unshare({
    required String equipmentId,
    required String diverId,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final owner = (await _ownersOf([equipmentId]))[equipmentId];
      if (owner != actingDiverId) {
        return const EquipmentShareResult(skippedNotOwned: 1);
      }
      return _remove(
        equipmentId,
        owner!,
        diverId,
        DateTime.now().millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Shares every item [ownerId] owns with each of [diverIds], for Settings >
  /// Shared data.
  Future<EquipmentShareResult> shareAllForDiver({
    required String ownerId,
    required List<String> diverIds,
  }) async {
    final owned =
        await (_db.selectOnly(_db.equipment)
              ..addColumns([_db.equipment.id])
              ..where(_db.equipment.diverId.equals(ownerId)))
            .map((r) => r.read(_db.equipment.id)!)
            .get();
    if (owned.isEmpty) return const EquipmentShareResult();
    return shareMany(
      equipmentIds: owned,
      diverIds: diverIds,
      actingDiverId: ownerId,
    );
  }

  Future<EquipmentShareResult> _add(
    String equipmentId,
    String owner,
    String diverId,
    Set<String> knownDivers,
    int now,
  ) async {
    if (diverId == owner || !knownDivers.contains(diverId)) {
      return const EquipmentShareResult(rejected: 1);
    }
    final shareId = _uuid.v4();
    final inserted = await _db
        .into(_db.equipmentShares)
        .insertReturningOrNull(
          EquipmentSharesCompanion.insert(
            id: shareId,
            equipmentId: equipmentId,
            diverId: diverId,
            createdAt: now,
          ),
          onConflict: DoNothing<$EquipmentSharesTable, EquipmentShareRow>(
            target: const [],
          ),
        );
    if (inserted == null) return const EquipmentShareResult();
    final eventId = await _logEvent(
      equipmentId,
      EquipmentOwnershipEventKind.shared,
      from: owner,
      to: diverId,
      now: now,
    );
    await _markPending(sharesEntity, shareId, now);
    await _markPending(eventsEntity, eventId, now);
    return const EquipmentShareResult(added: 1);
  }

  Future<EquipmentShareResult> _remove(
    String equipmentId,
    String owner,
    String diverId,
    int now,
  ) async {
    final rows =
        await (_db.select(_db.equipmentShares)..where(
              (t) =>
                  t.equipmentId.equals(equipmentId) & t.diverId.equals(diverId),
            ))
            .get();
    if (rows.isEmpty) return const EquipmentShareResult();
    await (_db.delete(_db.equipmentShares)..where(
          (t) => t.equipmentId.equals(equipmentId) & t.diverId.equals(diverId),
        ))
        .go();
    for (final r in rows) {
      await _syncRepository.logDeletion(
        entityType: sharesEntity,
        recordId: r.id,
      );
    }
    final eventId = await _logEvent(
      equipmentId,
      EquipmentOwnershipEventKind.unshared,
      from: owner,
      to: diverId,
      now: now,
    );
    await _markPending(eventsEntity, eventId, now);
    return const EquipmentShareResult(removed: 1);
  }

  Future<String> _logEvent(
    String equipmentId,
    EquipmentOwnershipEventKind kind, {
    required String? from,
    required String? to,
    required int now,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.equipmentOwnershipEvents)
        .insert(
          EquipmentOwnershipEventsCompanion.insert(
            id: id,
            equipmentId: equipmentId,
            kind: kind.name,
            fromDiverId: Value(from),
            toDiverId: Value(to),
            occurredAt: now,
          ),
        );
    return id;
  }

  Future<void> _markPending(String entityType, String id, int now) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );

  Future<Map<String, String?>> _ownersOf(Iterable<String> equipmentIds) async {
    final ids = equipmentIds.toSet().toList();
    final owners = <String, String?>{};
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, (i + _idChunk).clamp(0, ids.length));
      final rows = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.isIn(chunk))).get();
      for (final r in rows) {
        owners[r.id] = r.diverId;
      }
    }
    return owners;
  }

  Future<Set<String>> _existingDivers(Iterable<String> diverIds) async {
    final ids = diverIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.divers,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id};
  }

  EquipmentShare _toShare(EquipmentShareRow r) => EquipmentShare(
    id: r.id,
    equipmentId: r.equipmentId,
    diverId: r.diverId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  );
}
```

- [ ] **Step 5: Run the repository test**

Run: `flutter test test/features/equipment/data/repositories/equipment_share_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Create the providers**

`lib/features/equipment/presentation/providers/equipment_share_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';

final equipmentShareRepositoryProvider = Provider<EquipmentShareRepository>(
  (ref) => EquipmentShareRepository(),
);

/// The profiles [equipmentId] is shared with, oldest share first.
final equipmentSharesProvider =
    FutureProvider.family<List<EquipmentShare>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getSharesFor(equipmentId);
    });

/// [equipmentId]'s share and ownership events, oldest first.
final equipmentOwnershipEventsProvider =
    FutureProvider.family<List<EquipmentOwnershipEvent>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getEventsFor(equipmentId);
    });

/// Every profile's name by id, for owner chips and history rows.
final diverNamesByIdProvider = FutureProvider<Map<String, String>>((ref) async {
  final divers = await ref.watch(allDiversProvider.future);
  return {for (final d in divers) d.id: d.name};
});

/// Sharing UI shows only when two or more profiles exist, as for sites and
/// trips.
final hasMultipleDiversProvider = Provider<bool>(
  (ref) => ref
      .watch(allDiversProvider)
      .maybeWhen(data: (divers) => divers.length >= 2, orElse: () => false),
);
```

Check the import path of `invalidateSelfWhen` (`lib/core/providers/ref_invalidate_on_change.dart`) against `equipment_providers.dart`'s imports and use the same one.

- [ ] **Step 7: Register in the architecture guards**

1. `test/architecture/repository_tick_stream_test.dart`: add `import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';`, add `'EquipmentShareRepository.watchChanges': EquipmentShareRepository().watchChanges,` to the stream map, and add:

```dart
    test('EquipmentShareRepository.watchChanges fires on a share and an event', () async {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('d1','d1',$now,$now)",
      );
      await db.customStatement(
        "INSERT INTO equipment (id, name, type, created_at, updated_at, diver_id) "
        "VALUES ('e1','e1','bcd',$now,$now,'d1')",
      );
      expect(
        await fires(
          EquipmentShareRepository().watchChanges(),
          () => db.customStatement(
            "INSERT INTO equipment_ownership_events (id, equipment_id, kind, occurred_at) "
            "VALUES ('ev1','e1','shared',$now)",
          ),
        ),
        isTrue,
      );
    });
```

If `fires` only observes Drift-API writes (a `customStatement` does not notify), replace the write with `db.into(db.equipmentOwnershipEvents).insert(EquipmentOwnershipEventsCompanion.insert(id: 'ev1', equipmentId: 'e1', kind: 'shared', occurredAt: now))`.

2. `test/architecture/provider_tick_build_smoke_test.dart`, inside `_tickGroup('equipment', [...])`:

```dart
    (
      name: 'equipmentSharesProvider',
      read: (c) => c.read(equipmentSharesProvider(_id).future),
    ),
    (
      name: 'equipmentOwnershipEventsProvider',
      read: (c) => c.read(equipmentOwnershipEventsProvider(_id).future),
    ),
```

with the import of `equipment_share_providers.dart`.

- [ ] **Step 8: Run guards**

Run: `flutter test test/architecture/ test/features/equipment/data/repositories/equipment_share_repository_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/features/equipment test/features/equipment test/architecture
git add lib/features/equipment/domain/entities/equipment_share.dart lib/features/equipment/domain/entities/equipment_ownership_event.dart lib/features/equipment/data/repositories/equipment_share_repository.dart lib/features/equipment/presentation/providers/equipment_share_providers.dart test/features/equipment/data/repositories/equipment_share_repository_test.dart test/architecture/repository_tick_stream_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(equipment): add the share repository and the share event log"
```

---

## Task 4: The visibility filter

**Files:**
- Modify: `lib/core/data/visibility/visibility_filter.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (lines 88-90, 122-123, 163-164, 202-203, 820-821, 846 and the manual `EquipmentItem(` in `searchEquipment` ~lines 874-915; new methods after `getEquipmentByIds` ~line 263)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (providers at lines 45, 60, 72, 97, 366, 961, 1043)
- Test: `test/features/equipment/data/repositories/equipment_visibility_test.dart`
- Test: `test/core/data/visibility/visibility_filter_test.dart` (add a group)

**Interfaces:**
- Consumes: Task 1 tables, Task 3 `equipmentShareRepositoryProvider`.
- Produces: `VisibilityFilter.applyToEquipment(AppDatabase db, SimpleSelectStatement<$EquipmentTable, EquipmentData> query, String? diverId)`, `VisibilityFilter.equipmentSqlFragment({required String tableAlias, required String? diverId, required String conjunction}) -> SqlFragment`, `EquipmentRepository.isVisibleTo(String equipmentId, String diverId) -> Future<bool>`, `EquipmentRepository.visibleIdsAmong(Iterable<String> ids, String diverId) -> Future<Set<String>>`. `searchEquipment` rows now carry `diverId` and `createdAt`.

- [ ] **Step 1: Write the failing visibility test**

`test/features/equipment/data/repositories/equipment_visibility_test.dart`:

```dart
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  Future<void> seed() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife', 'son']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    Future<void> item(String id, String owner, {bool active = true}) =>
        db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: id, name: id, type: 'bcd', createdAt: t, updatedAt: t,
            diverId: Value(owner),
            isActive: Value(active),
            lastServiceDate: Value(t),
            serviceIntervalDays: const Value(365),
          ),
        );
    await item('owned', 'owner');
    await item('shared', 'wife');
    await item('other', 'son');
    await item('shared-retired', 'wife', active: false);
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['shared', 'shared-retired'],
      diverIds: ['owner'],
      actingDiverId: 'wife',
    );
  }

  group('visible to the owner diver', () {
    setUp(() async {
      db = await setUpTestDatabase();
      repo = EquipmentRepository();
      await seed();
    });
    tearDown(tearDownTestDatabase);

    Set<String> ids(Iterable<dynamic> items) => {for (final i in items) i.id as String};

    test('getActiveEquipment returns owned and shared', () async {
      expect(ids(await repo.getActiveEquipment(diverId: 'owner')), {'owned', 'shared'});
    });
    test('getRetiredEquipment returns a shared retired item', () async {
      expect(ids(await repo.getRetiredEquipment(diverId: 'owner')), {'shared-retired'});
    });
    test('getAllEquipment returns owned and shared, never another diver', () async {
      expect(
        ids(await repo.getAllEquipment(diverId: 'owner')),
        {'owned', 'shared', 'shared-retired'},
      );
    });
    test('getEquipmentByStatus returns shared items', () async {
      expect(
        ids(await repo.getEquipmentByStatus(EquipmentStatus.active, diverId: 'owner')),
        containsAll(['owned', 'shared']),
      );
    });
    test('getEquipmentWithServiceDates returns shared items', () async {
      expect(
        ids(await repo.getEquipmentWithServiceDates(diverId: 'owner')),
        {'owned', 'shared'},
      );
    });
    test('searchEquipment finds a shared item and hydrates its owner', () async {
      final found = await repo.searchEquipment('shared', diverId: 'owner');
      expect(ids(found), {'shared', 'shared-retired'});
      expect(found.first.diverId, 'wife');
      expect(found.first.createdAt, isNotNull);
    });
    test('a null diver stays unfiltered', () async {
      expect(ids(await repo.getAllEquipment()), hasLength(4));
    });
    test('the sharee side: the son sees only his own', () async {
      expect(ids(await repo.getAllEquipment(diverId: 'son')), {'other'});
    });
    test('visibleIdsAmong and isVisibleTo', () async {
      expect(
        await repo.visibleIdsAmong(['owned', 'shared', 'other'], 'owner'),
        {'owned', 'shared'},
      );
      expect(await repo.isVisibleTo('other', 'owner'), isFalse);
      expect(await repo.isVisibleTo('shared', 'owner'), isTrue);
    });
  });

  test('getActiveEquipment statement count does not grow with shares', () async {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase.memory(logStatements: true)),
    );
    db = DatabaseService.instance.database;
    repo = EquipmentRepository();
    addTearDown(tearDownTestDatabase);
    final logged = <String>[];
    Future<int> count() async {
      logged.clear();
      await runZoned(
        () => repo.getActiveEquipment(diverId: 'owner'),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      return logged.where((l) => l.startsWith('Drift: Sent')).length;
    }
    await runZoned(seed, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
    final few = await count();
    final t = DateTime.now().millisecondsSinceEpoch;
    await runZoned(() async {
      for (var i = 0; i < 20; i++) {
        await db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: 'x$i', name: 'x$i', type: 'bcd', createdAt: t, updatedAt: t,
            diverId: const Value('wife'),
          ),
        );
      }
      await EquipmentShareRepository().shareMany(
        equipmentIds: [for (var i = 0; i < 20; i++) 'x$i'],
        diverIds: ['owner'],
        actingDiverId: 'wife',
      );
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
    expect(await count(), few);
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_visibility_test.dart`
Expected: FAIL (shared items missing from each list; `visibleIdsAmong` undefined).

- [ ] **Step 3: Add the filter helpers**

In `lib/core/data/visibility/visibility_filter.dart`, inside `VisibilityFilter`, after `applyToDiveSites`:

```dart
  /// Owner-or-shared predicate for `equipment` (issue #2046): an item is
  /// visible to [diverId] when [diverId] owns it or holds an
  /// `equipment_shares` row for it. Unlike trips and sites there is no
  /// all-profiles flag; sharing is per profile. No-op for a null [diverId].
  static void applyToEquipment(
    AppDatabase db,
    SimpleSelectStatement<$EquipmentTable, EquipmentData> query,
    String? diverId,
  ) {
    if (diverId == null) return;
    final shares = db.equipmentShares;
    query.where(
      (t) =>
          t.diverId.equals(diverId) |
          t.id.isInQuery(
            db.selectOnly(shares)
              ..addColumns([shares.equipmentId])
              ..where(shares.diverId.equals(diverId)),
          ),
    );
  }

  /// [applyToEquipment] for raw SQL: `$conjunction (alias.diver_id = ? OR
  /// alias.id IN (items shared with ?))`. Empty for a null [diverId].
  static SqlFragment equipmentSqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
  }) {
    if (diverId == null) {
      return const SqlFragment(whereClause: '', variables: []);
    }
    return SqlFragment(
      whereClause:
          ' $conjunction ($tableAlias.diver_id = ? OR $tableAlias.id IN '
          '(SELECT equipment_id FROM equipment_shares WHERE diver_id = ?))',
      variables: [Variable.withString(diverId), Variable.withString(diverId)],
    );
  }
```

Update the class doc comment's first sentence to: "Applies owner-or-shared visibility predicates: an `is_shared` flag for trips and dive sites, per-profile share rows for equipment."

Add a group to `test/core/data/visibility/visibility_filter_test.dart`:

```dart
  group('equipmentSqlFragment', () {
    test('is empty for a null diver', () {
      final f = VisibilityFilter.equipmentSqlFragment(
        tableAlias: 'e', diverId: null, conjunction: 'AND',
      );
      expect(f.isEmpty, isTrue);
    });
    test('binds the diver twice', () {
      final f = VisibilityFilter.equipmentSqlFragment(
        tableAlias: 'e', diverId: 'd1', conjunction: 'WHERE',
      );
      expect(f.whereClause, contains('WHERE (e.diver_id = ? OR e.id IN'));
      expect(f.variables, hasLength(2));
    });
  });
```

- [ ] **Step 4: Use it in the repository**

In `equipment_repository_impl.dart` add `import 'package:submersion/core/data/visibility/visibility_filter.dart';` and replace each of the five blocks

```dart
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }
```

in `getActiveEquipment`, `getRetiredEquipment`, `getAllEquipment`, `getEquipmentByStatus` and `getEquipmentWithServiceDates` with:

```dart
      VisibilityFilter.applyToEquipment(_db, query, diverId);
```

In `searchEquipment`, replace line 846 and the `variables` list:

```dart
      final visibility = VisibilityFilter.equipmentSqlFragment(
        tableAlias: 'e',
        diverId: diverId,
        conjunction: 'AND',
      );
      final variables = [
        for (var i = 0; i < 5; i++) Variable.withString(searchTerm),
        ...visibility.variables,
      ];
```

and in the SQL replace `$diverFilter` with `${visibility.whereClause}`. In the manual `EquipmentItem(` construction below it add:

```dart
          diverId: row.data['diver_id'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
```

Keep the existing five search term variables exactly as they were if they are written out individually; only the diver part changes.

After `getEquipmentByIds`, add:

```dart
  /// Whether [diverId] owns [equipmentId] or holds a share of it.
  Future<bool> isVisibleTo(String equipmentId, String diverId) async =>
      (await visibleIdsAmong([equipmentId], diverId)).isNotEmpty;

  /// The subset of [ids] visible to [diverId] (owned or shared), in one
  /// statement per 450 ids (each chunk binds the ids plus the diver twice).
  Future<Set<String>> visibleIdsAmong(
    Iterable<String> ids,
    String diverId,
  ) async {
    final list = ids.toSet().toList();
    final visible = <String>{};
    for (var i = 0; i < list.length; i += 450) {
      final chunk = list.sublist(i, (i + 450).clamp(0, list.length));
      final query = _db.select(_db.equipment)..where((t) => t.id.isIn(chunk));
      VisibilityFilter.applyToEquipment(_db, query, diverId);
      visible.addAll((await query.get()).map((r) => r.id));
    }
    return visible;
  }
```

- [ ] **Step 5: Refresh lists on share changes**

In `equipment_providers.dart` import `equipment_share_providers.dart` and add this line next to the existing `ref.invalidateSelfWhen(repository.watchEquipmentChanges());` in `activeEquipmentProvider`, `retiredEquipmentProvider`, `equipmentByStatusProvider`, `allEquipmentProvider`, `equipmentSearchProvider`, `activeEquipmentClocksProvider` and `tripServiceAlertsProvider`:

```dart
    ref.invalidateSelfWhen(
      ref.read(equipmentShareRepositoryProvider).watchChanges(),
    );
```

- [ ] **Step 6: Run**

Run: `flutter test test/features/equipment test/core/data/visibility test/architecture/`
Expected: PASS. If an existing equipment widget test now fails because a provider body builds a real `EquipmentShareRepository` against no database, override `equipmentShareRepositoryProvider` there with a repository created after `setUpTestDatabase()`, or override the list provider it reads, following the file's existing override style.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core/data/visibility/visibility_filter.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/equipment/presentation/providers/equipment_providers.dart test/features/equipment/data/repositories/equipment_visibility_test.dart test/core/data/visibility/visibility_filter_test.dart
git commit -m "feat(equipment): show gear shared with a profile in its lists"
```

(Add any test file you had to touch in Step 6 to the `git add` list.)

---

## Task 5: Delete tombstones the new rows and stays owner-only

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`deleteEquipment` ~lines 548-642; new `deleteOwnedEquipment`)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart:485-488` (`EquipmentListNotifier.deleteEquipment`)
- Test: `test/features/equipment/data/repositories/equipment_delete_shares_test.dart`

**Interfaces:**
- Produces: `EquipmentRepository.deleteOwnedEquipment(String id, {required String? actingDiverId}) -> Future<bool>`; `EquipmentListNotifier.deleteEquipment(String id) -> Future<bool>` (false when skipped).

- [ ] **Step 1: Write the failing test**

`test/features/equipment/data/repositories/equipment_delete_shares_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'bcd', name: 'bcd', type: 'bcd', createdAt: t, updatedAt: t,
        diverId: const Value('owner'),
      ),
    );
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner',
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('deleting an item tombstones its shares and events', () async {
    final shareId = (await db.select(db.equipmentShares).getSingle()).id;
    final eventId = (await db.select(db.equipmentOwnershipEvents).getSingle()).id;
    await repo.deleteEquipment('bcd');
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    expect(await tombstones('equipmentShares'), contains(shareId));
    expect(await tombstones('equipmentOwnershipEvents'), contains(eventId));
  });

  test('a sharee cannot delete; the owner can', () async {
    expect(await repo.deleteOwnedEquipment('bcd', actingDiverId: 'wife'), isFalse);
    expect(await repo.getEquipmentById('bcd'), isNotNull);
    expect(await repo.deleteOwnedEquipment('bcd', actingDiverId: 'owner'), isTrue);
    expect(await repo.getEquipmentById('bcd'), isNull);
  });

  test('with no diver at all the delete proceeds', () async {
    expect(await repo.deleteOwnedEquipment('bcd', actingDiverId: null), isTrue);
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_delete_shares_test.dart`
Expected: FAIL (`deleteOwnedEquipment` undefined; no tombstones for shares).

- [ ] **Step 3: Implement**

In `deleteEquipment`, inside the transaction, directly after `await EquipmentTagRepository().deleteLinksForEquipment(id);`:

```dart
        // Shares and their event log (issue #2046): deleted and tombstoned
        // before the row, like the tag links, so every peer drops them too.
        final shareIds = await (_db.selectOnly(_db.equipmentShares)
              ..addColumns([_db.equipmentShares.id])
              ..where(_db.equipmentShares.equipmentId.equals(id)))
            .map((r) => r.read(_db.equipmentShares.id)!)
            .get();
        final eventIds = await (_db.selectOnly(_db.equipmentOwnershipEvents)
              ..addColumns([_db.equipmentOwnershipEvents.id])
              ..where(_db.equipmentOwnershipEvents.equipmentId.equals(id)))
            .map((r) => r.read(_db.equipmentOwnershipEvents.id)!)
            .get();
        await (_db.delete(
          _db.equipmentShares,
        )..where((t) => t.equipmentId.equals(id))).go();
        await (_db.delete(
          _db.equipmentOwnershipEvents,
        )..where((t) => t.equipmentId.equals(id))).go();
        await _syncRepository.logDeletions(
          entityType: 'equipmentShares',
          recordIds: shareIds,
        );
        await _syncRepository.logDeletions(
          entityType: 'equipmentOwnershipEvents',
          recordIds: eventIds,
        );
```

Update the method's doc comment to name share rows and events among the tombstoned children. After `deleteEquipment`, add:

```dart
  /// Deletes [id] only when [actingDiverId] owns it; delete is owner-only
  /// (issue #2046), so a profile the item is shared with gets false and
  /// nothing changes. A null [actingDiverId] (no diver profile exists)
  /// deletes as [deleteEquipment] does.
  Future<bool> deleteOwnedEquipment(
    String id, {
    required String? actingDiverId,
  }) async {
    if (actingDiverId != null) {
      final item = await getEquipmentById(id);
      if (item != null && item.diverId != actingDiverId) return false;
    }
    await deleteEquipment(id);
    return true;
  }
```

In `EquipmentListNotifier` replace `deleteEquipment`:

```dart
  /// False, changing nothing, when the active diver does not own [id].
  Future<bool> deleteEquipment(String id) async {
    final diverId =
        _validatedDiverId ??
        await _ref.read(validatedCurrentDiverIdProvider.future);
    final deleted = await _repository.deleteOwnedEquipment(
      id,
      actingDiverId: diverId,
    );
    await refresh();
    return deleted;
  }
```

Callers that ignore the result keep compiling. `EquipmentRepository` fakes that `extends EquipmentRepository` inherit the new method, so they need no change.

- [ ] **Step 4: Run**

Run: `flutter test test/features/equipment`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/equipment/presentation/providers/equipment_providers.dart test/features/equipment/data/repositories/equipment_delete_shares_test.dart
git commit -m "feat(equipment): keep delete owner-only and tombstone share rows"
```

---

## Task 6: Owner checks that become visibility checks, and service kinds

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart:231-248` (`_parentIdToSave`)
- Modify: `lib/features/equipment/data/services/equipment_findings_pass.dart:100-112` (`itemsById`)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (new `allServiceKindsByIdProvider` next to `serviceKindsProvider` ~line 753)
- Modify: `lib/features/equipment/presentation/widgets/service_clocks_card.dart:49,94-95`, `service_history_section.dart:50-55,293-302`, `service_record_dialog.dart:194,228-238`
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart:67`
- Test: `test/features/equipment/data/services/equipment_findings_pass_test.dart` (add a test)
- Test: `test/features/notifications/shared_gear_reminder_test.dart`
- Test: `test/features/equipment/presentation/widgets/service_clocks_card_test.dart` (add a test)
- Test: the existing edit page deep-link parent test (find it with `grep -rln "parent=" test/features/equipment/presentation/pages`), add one case

**Interfaces:**
- Consumes: `EquipmentRepository.isVisibleTo`, `visibleIdsAmong` (Task 4).
- Produces: `allServiceKindsByIdProvider` (`FutureProvider<Map<String, ServiceKind>>`, every kind, unscoped).

- [ ] **Step 1: Write the failing scheduler test (Review Focus 2)**

`test/features/notifications/shared_gear_reminder_test.dart`. Copy `_FakeNotificationService` from `test/features/notifications/service_ledger_scheduler_test.dart`, but make it also record `scheduleServiceReminder` calls (add a list and override that method with the same parameters the real `NotificationService.scheduleServiceReminder` declares, returning `1`). Then:

```dart
  test('a sharee gets the reminder for a clock on the owner custom kind', () async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.serviceKinds).insert(
      ServiceKindsCompanion.insert(
        id: 'owner-kind', name: 'Owner clean', createdAt: t, updatedAt: t,
        diverId: const Value('owner'),
      ),
    );
    final item = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', diverId: 'owner', name: 'Reg', type: EquipmentType.regulator),
    );
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: 'sched', equipmentId: item.id, serviceKindId: 'owner-kind',
        anchorDate: DateTime.now().subtract(const Duration(days: 360)),
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );
    await EquipmentShareRepository().shareMany(
      equipmentIds: [item.id], diverIds: ['wife'], actingDiverId: 'owner',
    );
    final fake = _FakeNotificationService();
    await NotificationScheduler(notificationService: fake)
        .scheduleAll(settings: const AppSettings(), diverId: 'wife');
    expect(fake.serviceReminders, isNotEmpty);
  });
```

Adjust the `ServiceKindsCompanion.insert` required fields and the `ServiceSchedule` constructor to the real signatures (check `lib/features/equipment/domain/entities/service_schedule.dart` and the `ServiceKinds` table); the kind needs an interval that makes the clock due within the reminder window, so set its interval field (for example `intervalDays: const Value(365)`) as the table defines it.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/notifications/shared_gear_reminder_test.dart`
Expected: FAIL, no reminder (the scoped kinds list drops the owner's custom kind, so `ServiceDueEngine` skips the schedule).

- [ ] **Step 3: Load every kind in the scheduler**

In `notification_scheduler.dart` `scheduleAll`, replace `await _serviceKindRepository.getAllKinds(diverId: diverId);` with:

```dart
    // Every kind, not only [diverId]'s: a shared item's schedule can use its
    // owner's custom kind, and ServiceDueEngine drops a schedule whose kind
    // is missing (issue #2046).
    final kinds = await _serviceKindRepository.getAllKinds();
```

Run the test again. Expected: PASS.

- [ ] **Step 4: Resolve kind names unscoped in the UI**

In `equipment_providers.dart`, after `serviceKindsProvider`:

```dart
/// Every service kind by id, whoever created it. For resolving the name of
/// a kind a schedule or record already references: a shared item's clock can
/// use its owner's custom kind, which [serviceKindsProvider] (the active
/// diver's choices) leaves out (issue #2046).
final allServiceKindsByIdProvider = FutureProvider<Map<String, ServiceKind>>((
  ref,
) async {
  final repository = ref.watch(serviceKindRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchServiceKindsChanges());
  return {for (final k in await repository.getAllKinds()) k.id: k};
});
```

Add it to `_tickGroup('equipment', ...)` in `provider_tick_build_smoke_test.dart`:

```dart
    (
      name: 'allServiceKindsByIdProvider',
      read: (c) => c.read(allServiceKindsByIdProvider.future),
    ),
```

Then:
1. `service_clocks_card.dart`: build `kindsById` from `ref.watch(allServiceKindsByIdProvider).value ?? const {}` instead of `serviceKindsProvider` (lines 49 and 94-95). Keep `serviceKindsProvider` wherever the card offers kinds to *choose* from.
2. `service_history_section.dart`: build `kindsById` (lines 50-55) and the export map (lines 293-302) from `allServiceKindsByIdProvider`.
3. `service_record_dialog.dart`: the dropdown offers `serviceKindsProvider`'s kinds plus any kind this item's schedules reference. Where the dialog reads `ref.watch(serviceKindsProvider)` for the dropdown (lines 228-238), compute:

```dart
    final allKinds = ref.watch(allServiceKindsByIdProvider).value ?? const {};
    List<ServiceKind> offered(List<ServiceKind> scoped) => [
      ...scoped,
      for (final s in schedules)
        if (allKinds[s.serviceKindId] case final k?)
          if (!scoped.any((e) => e.id == k.id)) k,
    ];
```

and pass `offered(kinds)` wherever the dropdown and `_maybePrefillFromKind` used `kinds`. `schedules` is the item's schedule list the dialog already has (it is passed to `_maybePrefillFromKind`); use that variable's real name.

Add a test to `service_clocks_card_test.dart`: override `allServiceKindsByIdProvider` with a map holding a custom kind `'owner-kind'` named `'Owner clean'`, override `serviceKindsProvider` with only built-ins, give the card a schedule on `'owner-kind'`, and expect `find.text('Owner clean')` to find one widget. Follow the file's existing pump helper.

- [ ] **Step 5: Findings pass (failing test first)**

Add to `test/features/equipment/data/services/equipment_findings_pass_test.dart` a test that seeds diver `owner` with item `reg`, diver `wife`, shares `reg` with `wife` via `EquipmentShareRepository().shareMany`, then calls `pass.itemsById(['reg'], diverId: 'wife')` and expects one item. Run it (FAIL), then change `itemsById` to:

```dart
  Future<List<EquipmentItem>> itemsById(
    Iterable<String> ids, {
    String? diverId,
  }) async {
    final visible = diverId == null
        ? null
        : await _equipment.visibleIdsAmong(ids, diverId);
    return [
      for (final id in ids)
        if (visible == null || visible.contains(id))
          if (await _equipment.getEquipmentById(id) case final item?) item,
    ];
  }
```

and update its doc comment: "With [diverId], only the items visible to that diver (owned or shared), as [activeItems] scopes them." Run it again: PASS.

- [ ] **Step 6: Edit page parent check (failing test first)**

In the existing edit page test that covers `/equipment/new?parent=<id>` while `activeEquipmentProvider` is still loading, add a case where the parent item belongs to another diver but is shared with the active diver, and expect the saved item's `parentEquipmentId` to be that parent id. Run it (FAIL: the owner check drops it). Then in `_parentIdToSave` replace

```dart
    if (parent == null || !parent.isFitted || parent.diverId != diverId) {
      return null;
    }
```

with

```dart
    if (parent == null || !parent.isFitted) return null;
    // A parent shared with [diverId] is as usable as one it owns (#2046).
    if (diverId != null &&
        !await ref.read(equipmentRepositoryProvider).isVisibleTo(id, diverId)) {
      return null;
    }
```

and update the doc comment ("a fitted item visible to [diverId]"). Run: PASS.

- [ ] **Step 7: Run and commit**

Run: `flutter test test/features/equipment test/features/notifications test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart lib/features/equipment/data/services/equipment_findings_pass.dart lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/equipment/presentation/widgets/service_clocks_card.dart lib/features/equipment/presentation/widgets/service_history_section.dart lib/features/equipment/presentation/widgets/service_record_dialog.dart lib/features/notifications/data/services/notification_scheduler.dart test/features/notifications/shared_gear_reminder_test.dart test/features/equipment/data/services/equipment_findings_pass_test.dart test/features/equipment/presentation/widgets/service_clocks_card_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(equipment): treat shared gear as the diver's own for clocks and parents"
```

(Add the edit page test file you changed.)

---

## Task 7: Diver deletion and merge handle the new tables

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (`diverGearSteps`, after the `equipment_tags` entry ~line 151)
- Modify: `lib/features/divers/data/repositories/diver_merge_repository.dart` (snapshot fields; `mergeDivers` loop; `undoMerge`; two new private methods)
- Test: `test/features/divers/data/repositories/diver_delete_equipment_shares_test.dart`
- Test: `test/features/divers/data/repositories/diver_merge_equipment_shares_test.dart`

**Interfaces:**
- Produces: `DiverMergeSnapshot.deletedShareRows` (`List<Map<String, dynamic>>`, default `const []`) and `DiverMergeSnapshot.repointedOwnershipEvents` (`List<({String rowId, String? priorFrom, String? priorTo, String? priorHlc})>`, default `const []`).

- [ ] **Step 1: Write the failing delete test (Review Focus 5)**

`test/features/divers/data/repositories/diver_delete_equipment_shares_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final (id, isDefault) in [('owner', true), ('wife', false)]) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(
          id: id, name: id, createdAt: t, updatedAt: t,
          isDefault: Value(isDefault),
        ),
      );
    }
    for (final (id, owner) in [('bcd', 'owner'), ('mask', 'wife')]) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id, name: id, type: 'bcd', createdAt: t, updatedAt: t,
          diverId: Value(owner),
        ),
      );
    }
    final shares = EquipmentShareRepository();
    await shares.shareMany(equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner');
    await shares.shareMany(equipmentIds: ['mask'], diverIds: ['owner'], actingDiverId: 'wife');
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('deleting the sharee drops its shares with tombstones; the owner keeps the item', () async {
    final wifeShare = (await (db.select(db.equipmentShares)
          ..where((t) => t.diverId.equals('wife'))).getSingle()).id;
    await DiverRepository().deleteDiverWithReassignment('wife');
    expect(await (db.select(db.equipment)..where((t) => t.id.equals('bcd'))).getSingleOrNull(), isNotNull);
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    expect(await tombstones('equipmentShares'), contains(wifeShare));
  });

  test('the owner item keeps its shared event with the sharee nulled', () async {
    await DiverRepository().deleteDiverWithReassignment('wife');
    final events = await (db.select(db.equipmentOwnershipEvents)
          ..where((t) => t.equipmentId.equals('bcd'))).get();
    expect(events, hasLength(1));
    expect(events.single.toDiverId, isNull);
    expect(events.single.fromDiverId, 'owner');
  });

  test('the deleted diver own items take their events with tombstones', () async {
    final maskEvent = (await (db.select(db.equipmentOwnershipEvents)
          ..where((t) => t.equipmentId.equals('mask'))).getSingle()).id;
    await DiverRepository().deleteDiverWithReassignment('wife');
    expect(await tombstones('equipmentOwnershipEvents'), contains(maskEvent));
  });
}
```

Check `deleteDiverWithReassignment`'s real signature in `diver_repository.dart:445` and pass whatever else it requires.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/divers/data/repositories/diver_delete_equipment_shares_test.dart`
Expected: FAIL (the cascades remove rows but write no tombstones).

- [ ] **Step 3: Add the delete steps**

In `diverGearSteps`, after the `equipment_tags` entry:

```dart
  // Shares of the diver's gear, and the diver's own shares of other
  // profiles' gear (issue #2046).
  (
    table: 'equipment_shares',
    entityType: 'equipmentShares',
    where: 'equipment_id IN ($_diverGear) OR diver_id = ?1',
  ),
  // The event log of the diver's gear. Events on other profiles' gear that
  // name this diver stay, their diver columns nulled by ON DELETE SET NULL.
  (
    table: 'equipment_ownership_events',
    entityType: 'equipmentOwnershipEvents',
    where: 'equipment_id IN ($_diverGear)',
  ),
```

Run the test: PASS.

- [ ] **Step 4: Write the failing merge test (Review Focus 4)**

`test/features/divers/data/repositories/diver_merge_equipment_shares_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final t = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;

  Future<void> share(String id, String item, String diver) =>
      db.into(db.equipmentShares).insert(
        EquipmentSharesCompanion.insert(
          id: id, equipmentId: item, diverId: diver, createdAt: t,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['keep', 'dup', 'son']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    for (final (id, owner) in [
      ('son-bcd', 'son'),   // shared with keep AND dup: collision
      ('keep-reg', 'keep'), // shared with dup: would become a self-share
      ('dup-mask', 'dup'),  // shared with keep: item moves to keep
      ('son-fins', 'son'),  // shared with dup only: plain repoint
    ]) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id, name: id, type: 'bcd', createdAt: t, updatedAt: t,
          diverId: Value(owner),
        ),
      );
    }
    await share('s-keep-bcd', 'son-bcd', 'keep');
    await share('s-dup-bcd', 'son-bcd', 'dup');
    await share('s-dup-reg', 'keep-reg', 'dup');
    await share('s-keep-mask', 'dup-mask', 'keep');
    await share('s-dup-fins', 'son-fins', 'dup');
    await db.into(db.equipmentOwnershipEvents).insert(
      EquipmentOwnershipEventsCompanion.insert(
        id: 'ev', equipmentId: 'son-fins', kind: 'shared', occurredAt: t,
        fromDiverId: const Value('son'), toDiverId: const Value('dup'),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, String>> sharesByItem() async => {
    for (final s in await db.select(db.equipmentShares).get())
      '${s.equipmentId}/${s.id}': s.diverId,
  };

  test('merge drops colliding and self shares and repoints the rest', () async {
    await DiverMergeRepository().mergeDivers(keeperId: 'keep', duplicateId: 'dup');
    final shares = await db.select(db.equipmentShares).get();
    expect({for (final s in shares) s.id}, {'s-keep-bcd', 's-dup-fins'});
    expect(shares.firstWhere((s) => s.id == 's-dup-fins').diverId, 'keep');
    final owners = {
      for (final e in await db.select(db.equipment).get()) e.id: e.diverId,
    };
    for (final s in shares) {
      expect(owners[s.equipmentId], isNot(s.diverId), reason: 'no self-share');
    }
    final deleted = {
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    };
    expect(deleted, containsAll(['s-dup-bcd', 's-dup-reg', 's-keep-mask']));
  });

  test('merge repoints event divers', () async {
    await DiverMergeRepository().mergeDivers(keeperId: 'keep', duplicateId: 'dup');
    final ev = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(ev.toDiverId, 'keep');
    expect(ev.fromDiverId, 'son');
  });

  test('undo restores shares, their tombstones and event divers', () async {
    final before = await sharesByItem();
    final repo = DiverMergeRepository();
    final snapshot = await repo.mergeDivers(keeperId: 'keep', duplicateId: 'dup');
    await repo.undoMerge(snapshot);
    expect(await sharesByItem(), before);
    final tombstones = [
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    ];
    expect(tombstones, isEmpty);
    final ev = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(ev.toDiverId, 'dup');
  });
}
```

- [ ] **Step 5: Run to see it fail**

Run: `flutter test test/features/divers/data/repositories/diver_merge_equipment_shares_test.dart`
Expected: FAIL with a UNIQUE constraint error on `equipment_shares`.

- [ ] **Step 6: Implement merge handling**

In `DiverMergeSnapshot` add fields, constructor params (`this.deletedShareRows = const []`, `this.repointedOwnershipEvents = const []`) and docs:

```dart
  /// `equipment_shares` rows the merge deleted because repointing them would
  /// duplicate a pair or share an item with its own owner (issue #2046).
  /// Undo reinserts them and clears their tombstones.
  final List<Map<String, dynamic>> deletedShareRows;

  /// `equipment_ownership_events` whose `from_diver_id` or `to_diver_id`
  /// named the duplicate (neither is a `diver_id` column, so the generic
  /// repoint skips them), with their prior values for undo.
  final List<({String rowId, String? priorFrom, String? priorTo, String? priorHlc})>
  repointedOwnershipEvents;
```

In `mergeDivers`, declare `final deletedShares = <Map<String, dynamic>>[];` and `final repointedEvents = <({String rowId, String? priorFrom, String? priorTo, String? priorHlc})>[];` with the other lists; inside the transaction, directly after `PRAGMA defer_foreign_keys = ON` and before the `for (final table in tables)` loop:

```dart
      // Before the generic repoint, which would otherwise hit the share
      // pair index or create a self-share (issue #2046).
      deletedShares.addAll(
        await _dropCollidingShares(keeperId: keeperId, duplicateId: duplicateId),
      );
```

and after the `_repointLinkedBuddies` call:

```dart
      repointedEvents.addAll(
        await _repointOwnershipEvents(
          keeperId: keeperId,
          duplicateId: duplicateId,
          now: now,
        ),
      );
```

Pass `deletedShareRows: deletedShares, repointedOwnershipEvents: repointedEvents` to the returned snapshot. Add the two methods after `_repointLinkedBuddies`:

```dart
  /// Shares the generic repoint cannot move: the duplicate's share of an item
  /// the keeper already shares or owns, the duplicate's share of its own
  /// item (never written, but a peer could hold one), and the keeper's share
  /// of an item the duplicate owns (the item moves to the keeper). Deleted and
  /// tombstoned; returned whole for undo.
  Future<List<Map<String, dynamic>>> _dropCollidingShares({
    required String keeperId,
    required String duplicateId,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT s.* FROM equipment_shares s
      JOIN equipment e ON e.id = s.equipment_id
      WHERE (s.diver_id = ?1 AND (
              e.diver_id IN (?1, ?2)
              OR EXISTS (SELECT 1 FROM equipment_shares k
                         WHERE k.equipment_id = s.equipment_id
                           AND k.diver_id = ?2)))
         OR (s.diver_id = ?2 AND e.diver_id = ?1)
      ''',
      variables: [Variable<String>(duplicateId), Variable<String>(keeperId)],
    ).get();
    final dropped = [for (final r in rows) r.data];
    for (final row in dropped) {
      final id = row['id'] as String;
      await _db.customStatement('DELETE FROM equipment_shares WHERE id = ?', [id]);
      await _syncRepository.logDeletion(entityType: 'equipmentShares', recordId: id);
    }
    return dropped;
  }

  /// Moves event diver references from the duplicate to the keeper. The log
  /// is otherwise append-only; a merge is the one rewrite, because both
  /// profiles are the same person.
  Future<List<({String rowId, String? priorFrom, String? priorTo, String? priorHlc})>>
  _repointOwnershipEvents({
    required String keeperId,
    required String duplicateId,
    required int now,
  }) async {
    final rows = await (_db.select(_db.equipmentOwnershipEvents)..where(
          (t) =>
              t.fromDiverId.equals(duplicateId) | t.toDiverId.equals(duplicateId),
        ))
        .get();
    final touched =
        <({String rowId, String? priorFrom, String? priorTo, String? priorHlc})>[];
    for (final row in rows) {
      touched.add((
        rowId: row.id,
        priorFrom: row.fromDiverId,
        priorTo: row.toDiverId,
        priorHlc: row.hlc,
      ));
      await (_db.update(_db.equipmentOwnershipEvents)
            ..where((t) => t.id.equals(row.id)))
          .write(
            EquipmentOwnershipEventsCompanion(
              fromDiverId: Value(
                row.fromDiverId == duplicateId ? keeperId : row.fromDiverId,
              ),
              toDiverId: Value(
                row.toDiverId == duplicateId ? keeperId : row.toDiverId,
              ),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'equipmentOwnershipEvents',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    return touched;
  }
```

In `undoMerge`, after the `repointedLinkedBuddies` loop:

```dart
      // Event diver references go back, with their clocks and pending marks.
      for (final entry in snapshot.repointedOwnershipEvents) {
        await _db.customStatement(
          'UPDATE equipment_ownership_events '
          'SET from_diver_id = ?, to_diver_id = ?, hlc = ? WHERE id = ?',
          [entry.priorFrom, entry.priorTo, entry.priorHlc, entry.rowId],
        );
        await _db.customStatement(
          'DELETE FROM sync_records WHERE entity_type = ? AND record_id = ?',
          ['equipmentOwnershipEvents', entry.rowId],
        );
      }

      // Shares the merge dropped come back, their tombstones cleared so the
      // next sync does not delete them again.
      for (final row in snapshot.deletedShareRows) {
        await _insertRowMap('equipment_shares', row);
        await _db.customStatement(
          'DELETE FROM deletion_log WHERE entity_type = ? AND record_id = ?',
          ['equipmentShares', row['id']],
        );
      }
```

This runs after the repointed rows went back to the duplicate, so a reinserted duplicate share cannot collide with the keeper's.

- [ ] **Step 7: Run**

Run: `flutter test test/features/divers`
Expected: PASS, including the auto-discovering `diver_merge_repository_test.dart` census.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/features/divers/data/repositories/diver_delete_steps.dart lib/features/divers/data/repositories/diver_merge_repository.dart test/features/divers/data/repositories/diver_delete_equipment_shares_test.dart test/features/divers/data/repositories/diver_merge_equipment_shares_test.dart
git commit -m "fix(divers): keep equipment shares consistent when profiles are deleted or merged"
```

---

## Task 8: Gear on a dive carries its owner

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (batch mapper ~lines 480-512; single-dive mapper ~lines 4093-4122)
- Test: `test/features/dive_log/data/repositories/dive_gear_owner_test.dart`

**Interfaces:**
- Produces: `dive.equipment[i].diverId` is the item's owner (was null).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'bcd', name: 'bcd', type: 'bcd', createdAt: t, updatedAt: t,
        diverId: const Value('owner'),
      ),
    );
    await db.into(db.dives).insert(
      DivesCompanion.insert(
        id: 'dive1', diveDateTime: t, createdAt: t, updatedAt: t,
        diverId: const Value('wife'),
      ),
    );
    await db.into(db.diveEquipment).insert(
      DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'bcd'),
    );
  });

  tearDown(tearDownTestDatabase);

  test('a single dive gear item carries its owner', () async {
    final dive = await DiveRepository().getDiveById('dive1');
    expect(dive!.equipment.single.diverId, 'owner');
  });

  test('getAllDives gear carries its owner', () async {
    final dives = await DiveRepository().getAllDives(diverId: 'wife');
    expect(dives.single.equipment.single.diverId, 'owner');
  });
}
```

Match `DivesCompanion.insert` and `DiveEquipmentCompanion.insert` to their required columns (see any existing dive repository test that inserts a dive with gear, for example `grep -rln "DiveEquipmentCompanion.insert" test | head -1`).

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_gear_owner_test.dart`
Expected: FAIL, `diverId` is null.

- [ ] **Step 3: Implement**

In both `EquipmentItem(` constructions add `diverId: e.diverId,` directly after `id: e.id,`.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/dive_log/data/repositories`
Expected: PASS.

```bash
dart format lib test
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_gear_owner_test.dart
git commit -m "feat(dive-log): hydrate the owner of each gear item on a dive"
```

---

## Task 9: Strings for every new surface

All new copy lands in one task so the UI tasks only reference keys. Each key goes into all 11 ARB files.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: the keys below, available as `context.l10n.<key>`.

- [ ] **Step 1: Add the English keys**

Add near the top of `app_en.arb` (recent keys go there), with `@` metadata for every placeholder:

```json
  "equipment_sharedWithMe": "Shared with me",
  "equipment_owner_unknown": "Another profile",
  "equipment_ownerChip_semanticLabel": "Owned by {name}",
  "@equipment_ownerChip_semanticLabel": {"placeholders": {"name": {"type": "String"}}},
  "equipment_picker_ownerHeader": "From {name}",
  "@equipment_picker_ownerHeader": {"placeholders": {"name": {"type": "String"}}},
  "equipment_sharing_sharedWithLabel": "Shared with",
  "equipment_sharing_notShared": "Not shared",
  "equipment_sharing_ownedByLabel": "Owned by",
  "equipment_sharing_dialogTitle": "Share with",
  "equipment_sharing_dialogBody": "Profiles you choose can add this gear to their dives and log its servicing. Only the owner can delete it or change who it is shared with.",
  "equipment_sharing_noOtherProfiles": "There are no other profiles to share with",
  "equipment_bulkShare_action": "Share with...",
  "equipment_bulkShare_done": "{count, plural, =1{Shared 1 item} other{Shared {count} items}}",
  "@equipment_bulkShare_done": {"placeholders": {"count": {"type": "int"}}},
  "equipment_bulkShare_doneSkipped": "{count, plural, =1{Shared 1 item} other{Shared {count} items}}, skipped {skipped} you do not own",
  "@equipment_bulkShare_doneSkipped": {"placeholders": {"count": {"type": "int"}, "skipped": {"type": "int"}}},
  "equipment_bulkDelete_partial": "{deleted, plural, =1{Deleted 1 item} other{Deleted {deleted} items}}. {skipped, plural, =1{1 shared item was kept: only its owner can delete it} other{{skipped} shared items were kept: only their owners can delete them}}",
  "@equipment_bulkDelete_partial": {"placeholders": {"deleted": {"type": "int"}, "skipped": {"type": "int"}}},
  "equipment_filter_section_owner": "Owner",
  "equipment_filter_owner_mine": "Mine",
  "enum_equipmentField_owner": "Owner",
  "enum_equipmentField_owner_short": "Owner",
  "equipment_set_noLongerShared": "No longer shared",
  "equipment_history_title": "History",
  "equipment_history_empty": "Not used on any dive yet",
  "equipment_history_deletedProfile": "a deleted profile",
  "equipment_history_runDives": "{count, plural, =1{1 dive} other{{count} dives}}",
  "@equipment_history_runDives": {"placeholders": {"count": {"type": "int"}}},
  "equipment_history_dateRange": "{from} to {to}",
  "@equipment_history_dateRange": {"placeholders": {"from": {"type": "String"}, "to": {"type": "String"}}},
  "equipment_history_added": "Added by {name}",
  "@equipment_history_added": {"placeholders": {"name": {"type": "String"}}},
  "equipment_history_shared": "Shared with {name}",
  "@equipment_history_shared": {"placeholders": {"name": {"type": "String"}}},
  "equipment_history_unshared": "Stopped sharing with {name}",
  "@equipment_history_unshared": {"placeholders": {"name": {"type": "String"}}},
  "equipment_history_transferred": "Transferred from {from} to {to}",
  "@equipment_history_transferred": {"placeholders": {"from": {"type": "String"}, "to": {"type": "String"}}},
  "settings_shareAllEquipment_title": "Share all my equipment...",
  "settings_shareAllEquipment_body": "{count, plural, =1{Share your 1 item with the profiles you choose.} other{Share your {count} items with the profiles you choose.}}",
  "@settings_shareAllEquipment_body": {"placeholders": {"count": {"type": "int"}}},
```

Change the existing `settings_sharedData_sectionSubtitle` value to `"Share sites, trips and equipment across profiles"`.

- [ ] **Step 2: Translate into the ten other locales**

Add every key above to each of the ten other ARB files with a natural translation in that language (no `@` metadata in non-English files, matching the existing files), keeping `{placeholders}` and ICU plural structure intact and adding the plural categories each language needs (for example `few`/`many` where the language's existing plurals in that file use them). Update `settings_sharedData_sectionSubtitle` in each file to mention equipment as well. Keep "..." in the two ellipsis strings. No em dashes or en dashes as punctuation in any translation.

- [ ] **Step 3: Regenerate and check parity**

Run: `flutter gen-l10n && flutter test test/l10n/`
Expected: PASS (`arb_parity_test` confirms every locale has every key with matching placeholders).

- [ ] **Step 4: Update the hardcoded section subtitle**

In `lib/features/settings/presentation/widgets/settings_list_content.dart` ~lines 100-105, change the `sharedData` section's fallback `subtitle: 'Share sites and trips across profiles'` to `'Share sites, trips and equipment across profiles'`.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/ lib/features/settings/presentation/widgets/settings_list_content.dart
git commit -m "feat(l10n): add equipment sharing and history strings"
```

---

## Task 10: Owner chips and the picker's "Shared with me" section

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_owner_chip.dart`
- Create: `lib/features/equipment/presentation/utils/equipment_owner_sections.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart` (build ~lines 67-248, row types ~300-317)
- Modify: `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart` (constructor ~40-64, trailing Row ~201-239)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4805`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3495`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_buildTrailing` ~line 1314 and its caller ~1305)
- Test: `test/features/equipment/presentation/utils/equipment_owner_sections_test.dart`
- Test: `test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart` (add a group)
- Test: `test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart` (add a test)

**Interfaces:**
- Consumes: `diverNamesByIdProvider`, `hasMultipleDiversProvider` (Task 3); `EquipmentItem.diverId` on dive gear (Task 8).
- Produces: `EquipmentOwnerChip({required String? ownerId})`; `bool showsOwnerChip(EquipmentItem item, String? referenceDiverId, {required bool multipleDivers})`; `typedef OwnerSection = ({String? ownerId, List<EquipmentItem> items})`; `List<OwnerSection> sectionsByOwner(List<EquipmentItem> items, {required String? activeDiverId, required String Function(String ownerId) ownerName})`; `DiveGearTreeView.ownerReferenceDiverId` (`String?`).

- [ ] **Step 1: Write the failing sections test**

`test/features/equipment/presentation/utils/equipment_owner_sections_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';

EquipmentItem item(String id, String? owner) =>
    EquipmentItem(id: id, diverId: owner, name: id, type: EquipmentType.bcd);

void main() {
  const names = {'wife': 'Zoe', 'son': 'Adam', 'owner': 'Bill'};
  String nameOf(String id) => names[id]!;

  test('own items first, then one section per owner by name', () {
    final sections = sectionsByOwner(
      [item('a', 'wife'), item('b', 'owner'), item('c', 'son'), item('d', 'wife'), item('e', 'owner')],
      activeDiverId: 'owner',
      ownerName: nameOf,
    );
    expect(sections.map((s) => s.ownerId), [null, 'son', 'wife']);
    expect(sections.first.items.map((i) => i.id), ['b', 'e']);
    expect(sections.last.items.map((i) => i.id), ['a', 'd']);
  });

  test('an ownerless item counts as the active diver own', () {
    final sections = sectionsByOwner(
      [item('a', null)], activeDiverId: 'owner', ownerName: nameOf,
    );
    expect(sections.single.ownerId, isNull);
  });

  test('no active diver puts everything in one section', () {
    final sections = sectionsByOwner(
      [item('a', 'wife'), item('b', 'son')], activeDiverId: null, ownerName: nameOf,
    );
    expect(sections, hasLength(1));
  });

  test('showsOwnerChip only for another owner with two or more profiles', () {
    expect(showsOwnerChip(item('a', 'wife'), 'owner', multipleDivers: true), isTrue);
    expect(showsOwnerChip(item('a', 'owner'), 'owner', multipleDivers: true), isFalse);
    expect(showsOwnerChip(item('a', 'wife'), 'owner', multipleDivers: false), isFalse);
    expect(showsOwnerChip(item('a', null), 'owner', multipleDivers: true), isFalse);
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/equipment/presentation/utils/equipment_owner_sections_test.dart`
Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement the helpers and the chip**

`lib/features/equipment/presentation/utils/equipment_owner_sections.dart`:

```dart
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One picker section: the active diver's own items ([ownerId] null), or the
/// items another profile shares with it.
typedef OwnerSection = ({String? ownerId, List<EquipmentItem> items});

/// [items] split for a picker (issue #2046): the active diver's own items
/// first, then a section per other owner ordered by [ownerName]. An item with
/// no owner, or any item when there is no active diver, counts as own.
/// Item order inside a section is kept.
List<OwnerSection> sectionsByOwner(
  List<EquipmentItem> items, {
  required String? activeDiverId,
  required String Function(String ownerId) ownerName,
}) {
  final own = <EquipmentItem>[];
  final others = <String, List<EquipmentItem>>{};
  for (final item in items) {
    final owner = item.diverId;
    if (activeDiverId == null || owner == null || owner == activeDiverId) {
      own.add(item);
    } else {
      (others[owner] ??= []).add(item);
    }
  }
  final ownerIds = sortedByText(others.keys.toList(), ownerName);
  return [
    if (own.isNotEmpty) (ownerId: null, items: own),
    for (final id in ownerIds) (ownerId: id, items: others[id]!),
  ];
}

/// Whether a row for [item] shows an owner chip: another profile owns it
/// than [referenceDiverId] (the active diver in lists, the dive's diver on a
/// dive), and more than one profile exists.
bool showsOwnerChip(
  EquipmentItem item,
  String? referenceDiverId, {
  required bool multipleDivers,
}) =>
    multipleDivers &&
    item.diverId != null &&
    referenceDiverId != null &&
    item.diverId != referenceDiverId;
```

Check `sortedByText`'s signature in `lib/core/text/text_sort.dart` (it is called as `sortedByText(rows, (r) => r.name)` in the equipment repository) and adapt the call if its parameters differ.

`lib/features/equipment/presentation/widgets/equipment_owner_chip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small chip naming the profile that owns an item (issue #2046), shown
/// where the item belongs to someone other than the profile in context.
class EquipmentOwnerChip extends ConsumerWidget {
  final String? ownerId;

  const EquipmentOwnerChip({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final name = (ownerId == null ? null : names[ownerId]) ??
        l10n.equipment_owner_unknown;
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.equipment_ownerChip_semanticLabel(name),
      excludeSemantics: true,
      child: Chip(
        key: ValueKey('equipment-owner-chip-$ownerId'),
        avatar: Icon(
          Icons.person_outline,
          size: 14,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        label: Text(name),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
```

Run the sections test: PASS.

- [ ] **Step 4: Write the failing picker test**

In `test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart`, add a group using the file's existing pump helper plus these overrides (add `allDiversProvider`, `validatedCurrentDiverIdProvider`, `diverNamesByIdProvider`, `equipmentRollupClockProvider` if the helper lacks them):

```dart
  group('shared gear', () {
    final own = EquipmentItem(id: 'mine', diverId: 'owner', name: 'My BCD', type: EquipmentType.bcd);
    final wifes = EquipmentItem(id: 'hers', diverId: 'wife', name: 'Her Reg', type: EquipmentType.regulator);
    final divers = [
      Diver(id: 'owner', name: 'Bill', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
      Diver(id: 'wife', name: 'Anna', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    ];

    List<Override> overrides(List<Diver> ds) => [
      activeEquipmentProvider.overrideWith((ref) async => [own, wifes]),
      allDiversProvider.overrideWith((ref) async => ds),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'owner'),
    ];

    testWidgets('lists shared gear under Shared with me and the owner', (tester) async {
      await pumpPicker(tester, extraOverrides: overrides(divers));
      expect(find.text('Shared with me'), findsOneWidget);
      expect(find.text('From Anna'), findsOneWidget);
      expect(find.byKey(const ValueKey('equipment-owner-chip-wife')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('My BCD')).dy,
        lessThan(tester.getTopLeft(find.text('Her Reg')).dy),
      );
    });

    testWidgets('no section with a single profile', (tester) async {
      await pumpPicker(tester, extraOverrides: overrides(divers.take(1).toList()));
      expect(find.text('Shared with me'), findsNothing);
    });
  });
```

Replace `pumpPicker(tester, extraOverrides: ...)` with the file's real helper; if its helper takes no extra overrides, add an `extraOverrides` parameter to it. Construct `Diver` with its real required fields (`lib/features/divers/domain/entities/diver.dart:144`). Run: FAIL.

- [ ] **Step 5: Sections in the picker**

In `equipment_picker_sheet.dart`:

1. Add row types next to `_HeaderRow`:

```dart
final class _SectionRow extends _PickerRow {
  final String title;
  _SectionRow(this.title);
}
```

(Match the existing sealed class's constructor style: if `_HeaderRow` is `const`, make this `const` too.)

2. Replace the `rows` construction (the `for (final group in arrangeEquipment(...))` block) with:

```dart
            final multipleDivers = ref.watch(hasMultipleDiversProvider);
            final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
            final names = ref.watch(diverNamesByIdProvider).value ?? const {};
            final sections = multipleDivers
                ? sectionsByOwner(
                    available,
                    activeDiverId: activeDiverId,
                    ownerName: (id) => names[id] ?? context.l10n.equipment_owner_unknown,
                  )
                : [(ownerId: null, items: available)];
            final rows = <_PickerRow>[
              for (final (i, section) in sections.indexed) ...[
                if (section.ownerId != null && sections[i - 1].ownerId == null)
                  _SectionRow(context.l10n.equipment_sharedWithMe),
                if (section.ownerId case final owner?)
                  _SectionRow(
                    context.l10n.equipment_picker_ownerHeader(
                      names[owner] ?? context.l10n.equipment_owner_unknown,
                    ),
                  ),
                for (final group in arrangeEquipment(
                  section.items,
                  arrangement,
                  typeLabel: (type) => type.localizedName(context.l10n),
                )) ...[
                  if (group.type != null) _HeaderRow(group.type!),
                  for (final equipment in group.items)
                    _ItemRow(equipment, showTypeLabel: group.type == null),
                ],
              ],
            ];
```

When the first section is already someone else's (the active diver owns nothing visible here), `i - 1` is out of range; guard it: `if (section.ownerId != null && (i == 0 || sections[i - 1].ownerId == null))`.

3. In `itemBuilder`, add the `_SectionRow` arm:

```dart
        _SectionRow(:final title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
```

4. In the `_ItemRow` `ListTile`, make `trailing` a `Row(mainAxisSize: MainAxisSize.min, children: [...])` holding `if (showsOwnerChip(item, activeDiverId, multipleDivers: multipleDivers)) EquipmentOwnerChip(ownerId: item.diverId)`, a `SizedBox(width: 8)` when the chip shows, and the existing `ServiceStatusIndicatorFor(...)`. Read `activeDiverId` and `multipleDivers` in `build` before `equipmentAsync.when` so the builder closure sees them.

Add the imports (`diver_providers.dart`, `equipment_share_providers.dart`, `equipment_owner_sections.dart`, `equipment_owner_chip.dart`). Run the picker test: PASS.

- [ ] **Step 6: Owner chip on a dive's gear (failing test first)**

In `dive_gear_tree_view_test.dart` add a test that pumps `DiveGearTreeView(links: [GearLink(item: EquipmentItem(id: 'reg', diverId: 'owner', name: 'Reg', type: EquipmentType.regulator))], ownerReferenceDiverId: 'wife')` with `allDiversProvider` overridden to two divers named as in Step 4, and expects `find.byKey(const ValueKey('equipment-owner-chip-owner'))` to find one widget; and a second test with `ownerReferenceDiverId: 'owner'` expecting none. Build `GearLink` with its real constructor (grep `class GearLink`). Run: FAIL.

Then in `DiveGearTreeView` add the field and constructor parameter:

```dart
  /// The diver whose dive this is. A row whose item another profile owns
  /// shows that owner's chip (issue #2046). Null shows no chips.
  final String? ownerReferenceDiverId;
```

and in `_rows`' trailing `Row`, first child:

```dart
            if (showsOwnerChip(
              item,
              widget.ownerReferenceDiverId,
              multipleDivers: ref.watch(hasMultipleDiversProvider),
            )) ...[
              EquipmentOwnerChip(ownerId: item.diverId),
              const SizedBox(width: 4),
            ],
```

Pass `ownerReferenceDiverId: dive.diverId` at `dive_detail_page.dart:4805` and `ownerReferenceDiverId: _existingDive?.diverId ?? ref.watch(validatedCurrentDiverIdProvider).value` at `dive_edit_page.dart:3495` (use the page's real field name for the loaded dive; it is referenced at line 5250). Run: PASS.

- [ ] **Step 7: Owner chip on equipment list rows**

In `equipment_list_content.dart`, give `_buildTrailing` a parameter `Widget? ownerChip` and wrap each of its return values:

```dart
    Widget withOwner(Widget trailing) => ownerChip == null
        ? trailing
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [trailing, const SizedBox(height: 4), ownerChip],
          );
```

At the caller (~line 1305), pass `ownerChip: showsOwnerChip(item, activeDiverId, multipleDivers: multipleDivers) ? EquipmentOwnerChip(ownerId: item.diverId) : null`, reading `activeDiverId` from `validatedCurrentDiverIdProvider` and `multipleDivers` from `hasMultipleDiversProvider` in that row widget's `build` (it is a `ConsumerWidget`, or receives `ref`; follow what it already does to read `equipmentRollupClockProvider`).

Add a test to `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` using `_buildPhoneOverrides(items: [own, wifes])` plus `allDiversProvider` (two divers) and `validatedCurrentDiverIdProvider` ('owner'): the chip key for `wife` shows once and none for `owner`.

- [ ] **Step 8: Run and commit**

Run: `flutter test test/features/dive_log/presentation test/features/equipment test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/presentation/widgets/equipment_owner_chip.dart lib/features/equipment/presentation/utils/equipment_owner_sections.dart lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/presentation/utils/equipment_owner_sections_test.dart test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git commit -m "feat(equipment): show whose gear it is and group shared gear in the picker"
```

---

## Task 11: Sharing on the item page

**Files:**
- Create: `lib/features/equipment/presentation/widgets/profile_checklist_dialog.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_sharing_row.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (details card after the trips row ~line 619; app bar popup ~lines 274-286 and embedded header ~350)
- Test: `test/features/equipment/presentation/widgets/profile_checklist_dialog_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart`

**Interfaces:**
- Consumes: `equipmentSharesProvider`, `equipmentShareRepositoryProvider`, `diverNamesByIdProvider`, `hasMultipleDiversProvider`.
- Produces: `Future<Set<String>?> showProfileChecklistDialog(BuildContext context, {required String title, required String body, required List<Diver> profiles, required Set<String> initiallySelected, required String confirmLabel, bool allowEmpty = true})`; `EquipmentSharingRow({required EquipmentItem equipment})`.

- [ ] **Step 1: Write the failing dialog test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final profiles = [
    Diver(id: 'wife', name: 'Anna', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    Diver(id: 'son', name: 'Tom', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  ];

  /// Opens the dialog and returns the pending result future.
  Future<Future<Set<String>?>> open(
    WidgetTester tester, {
    bool allowEmpty = true,
    Set<String> initial = const {},
  }) async {
    late Future<Set<String>?> result;
    await tester.pumpWidget(testApp(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = showProfileChecklistDialog(
            context,
            title: 'Share with',
            body: 'Body',
            profiles: profiles,
            initiallySelected: initial,
            confirmLabel: 'Share',
            allowEmpty: allowEmpty,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('returns the checked profiles', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Tom'));
    await tester.pump();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(await result, {'son'});
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('confirm is disabled with nothing checked when empty is not allowed', (tester) async {
    await open(tester, allowEmpty: false);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Share'));
    expect(button.onPressed, isNull);
  });

  testWidgets('starts from the initial selection', (tester) async {
    await open(tester, initial: {'wife'});
    final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Anna'));
    expect(tile.value, isTrue);
  });
}
```

Use the real `Diver` constructor. Run: FAIL (file missing).

- [ ] **Step 2: Implement the dialog**

`lib/features/equipment/presentation/widgets/profile_checklist_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks which of [profiles] to pick (issue #2046). Returns the checked ids,
/// or null when cancelled. With [allowEmpty] false the confirm button stays
/// disabled until at least one profile is checked.
Future<Set<String>?> showProfileChecklistDialog(
  BuildContext context, {
  required String title,
  required String body,
  required List<Diver> profiles,
  required Set<String> initiallySelected,
  required String confirmLabel,
  bool allowEmpty = true,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _ProfileChecklistDialog(
    title: title,
    body: body,
    profiles: profiles,
    initiallySelected: initiallySelected,
    confirmLabel: confirmLabel,
    allowEmpty: allowEmpty,
  ),
);

class _ProfileChecklistDialog extends StatefulWidget {
  final String title;
  final String body;
  final List<Diver> profiles;
  final Set<String> initiallySelected;
  final String confirmLabel;
  final bool allowEmpty;

  const _ProfileChecklistDialog({
    required this.title,
    required this.body,
    required this.profiles,
    required this.initiallySelected,
    required this.confirmLabel,
    required this.allowEmpty,
  });

  @override
  State<_ProfileChecklistDialog> createState() =>
      _ProfileChecklistDialogState();
}

class _ProfileChecklistDialogState extends State<_ProfileChecklistDialog> {
  late Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canConfirm = widget.allowEmpty || _selected.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            const SizedBox(height: 12),
            for (final diver in widget.profiles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(diver.id),
                secondary: ProfileAvatar(
                  photo: diver.photo,
                  initials: diver.initials,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                ),
                title: Text(diver.name),
                onChanged: (checked) => setState(() {
                  _selected = checked == true
                      ? {..._selected, diver.id}
                      : _selected.difference({diver.id});
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.pop(context, {..._selected})
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
```

Run the dialog test: PASS.

- [ ] **Step 3: Write the failing detail page test**

`test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart`: copy the pump helper and overrides from `test/features/equipment/presentation/pages/equipment_detail_tags_test.dart` (lines 25-117, including `_MockServiceRecordNotifier` and the `Intl.defaultLocale` setUp), with `tagsForEquipmentProvider(id)` returning `const []`, and add these overrides, parameterized by the active diver and the profiles:

```dart
      allDiversProvider.overrideWith((ref) async => divers),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => activeDiverId),
      equipmentSharesProvider(id).overrideWith((ref) async => shares),
      equipmentHistoryProvider(id).overrideWith((ref) async => const []),
```

(`equipmentHistoryProvider` arrives in Task 15; add that override line in Task 16 instead if this test runs first.) The item under test is `EquipmentItem(id: id, diverId: 'owner', name: 'Wing', type: EquipmentType.bcd)`; `divers` are `owner` (Bill), `wife` (Anna); `shares` is `[EquipmentShare(id: 's1', equipmentId: id, diverId: 'wife', createdAt: DateTime(2026))]`.

```dart
  testWidgets('the owner sees Shared with and the delete menu', (tester) async {
    await pump(tester, activeDiverId: 'owner');
    expect(find.text('Shared with'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
  });

  testWidgets('a sharee sees Owned by and no delete menu', (tester) async {
    await pump(tester, activeDiverId: 'wife');
    expect(find.text('Owned by'), findsOneWidget);
    expect(find.text('Bill'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('one profile shows no sharing rows', (tester) async {
    await pump(tester, activeDiverId: 'owner', divers: [bill]);
    expect(find.text('Shared with'), findsNothing);
    expect(find.text('Owned by'), findsNothing);
  });

  testWidgets('tapping Shared with opens the checklist of other profiles', (tester) async {
    await pump(tester, activeDiverId: 'owner');
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Anna'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Bill'), findsNothing);
  });
```

If the page shows `PopupMenuButton<String>` for things other than delete (a future menu), assert on `find.text('Delete')` after opening the menu instead. Run: FAIL.

- [ ] **Step 4: Implement the sharing row**

`lib/features/equipment/presentation/widgets/equipment_sharing_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item page's sharing rows (issue #2046), shown only when two or more
/// profiles exist. The owner sees "Shared with" and taps it to change the
/// shares; a profile the item is shared with sees "Owned by" and the shares
/// read-only.
class EquipmentSharingRow extends ConsumerWidget {
  final EquipmentItem equipment;

  const EquipmentSharingRow({super.key, required this.equipment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasMultipleDiversProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final shares = ref.watch(equipmentSharesProvider(equipment.id)).value ?? const [];
    final isOwner = equipment.diverId == null || equipment.diverId == activeDiverId;
    String nameOf(String id) => names[id] ?? l10n.equipment_owner_unknown;

    final sharedWith = shares.isEmpty
        ? Text(l10n.equipment_sharing_notShared)
        : Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              for (final s in shares)
                Chip(
                  label: Text(nameOf(s.diverId)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isOwner)
          _row(context, l10n.equipment_sharing_ownedByLabel,
              Text(nameOf(equipment.diverId!))),
        InkWell(
          onTap: isOwner ? () => _edit(context, ref, activeDiverId, shares.map((s) => s.diverId).toSet()) : null,
          borderRadius: BorderRadius.circular(8),
          child: _row(
            context,
            l10n.equipment_sharing_sharedWithLabel,
            sharedWith,
            chevron: isOwner,
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, Widget value, {bool chevron = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String? activeDiverId,
    Set<String> current,
  ) async {
    if (activeDiverId == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final divers = await ref.read(allDiversProvider.future);
    final others = [for (final d in divers) if (d.id != activeDiverId) d];
    if (!context.mounted) return;
    final chosen = await showProfileChecklistDialog(
      context,
      title: l10n.equipment_sharing_dialogTitle,
      body: l10n.equipment_sharing_dialogBody,
      profiles: others,
      initiallySelected: current,
      confirmLabel: l10n.common_action_save,
    );
    if (chosen == null) return;
    try {
      await ref.read(equipmentShareRepositoryProvider).setShares(
        equipmentId: equipment.id,
        diverIds: chosen,
        actingDiverId: activeDiverId,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    }
  }
}
```

The `_row` layout mirrors the page's `_buildDetailRow` (label left, value right). Keep the file under 400 lines.

- [ ] **Step 5: Use it on the page and hide delete for a sharee**

In `equipment_detail_page.dart`:
1. In `_buildDetailsSection`, after the trips row (`tripCountAsync.when(...)`), add `EquipmentSharingRow(equipment: equipment),`.
2. In `_EquipmentDetailContent.build`, compute

```dart
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    // Delete is owner-only (issue #2046).
    final isOwner = equipment.diverId == null ||
        activeDiverId == null ||
        equipment.diverId == activeDiverId;
```

and wrap both `PopupMenuButton<String>` usages (app bar ~line 274-286 and embedded header ~350) in `if (isOwner)`. Pass `isOwner` into the embedded header builder if it is a separate method.

Run the detail page test: PASS.

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/equipment test/architecture/`
Expected: PASS. Existing detail page tests that do not override `allDiversProvider` get `hasMultipleDiversProvider == false` (the provider errors or stays loading without a database, and `maybeWhen` returns false), so they need no change; if one fails because `allDiversProvider` hits a missing database, add `allDiversProvider.overrideWith((ref) async => const [])` to that file's overrides.

```bash
dart format lib test
git add lib/features/equipment/presentation/widgets/profile_checklist_dialog.dart lib/features/equipment/presentation/widgets/equipment_sharing_row.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/widgets/profile_checklist_dialog_test.dart test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart
git commit -m "feat(equipment): share an item with profiles from its page"
```

---

## Task 12: List: bulk Share, owner-only bulk delete, Owner filter, Owner column

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_bulkActions` ~525-557; `_confirmAndDelete` ~603-645; `_buildTableView` adapter ~756; filter apply call ~277-307)
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`
- Modify: `lib/features/equipment/domain/constants/equipment_field.dart`
- Test: `test/features/equipment/domain/models/equipment_filter_state_owner_test.dart`
- Test: `test/features/equipment/domain/constants/equipment_field_owner_test.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (add a group)

**Interfaces:**
- Produces: `enum EquipmentOwnerFilter { all, mine, sharedWithMe }`; `EquipmentFilterState.owner` (default `all`); `EquipmentFilterState.apply(List<EquipmentItem>, Map<String, Iterable<String>>, {String? activeDiverId})`; `EquipmentField.owner` (last value); `EquipmentFieldAdapter({..., Map<String, String> ownerNames = const {}})`.

- [ ] **Step 1: Failing filter state test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

void main() {
  final items = [
    const EquipmentItem(id: 'a', diverId: 'owner', name: 'a', type: EquipmentType.bcd),
    const EquipmentItem(id: 'b', diverId: 'wife', name: 'b', type: EquipmentType.bcd),
  ];

  List<String> ids(EquipmentOwnerFilter f) => [
    for (final i in EquipmentFilterState(owner: f).apply(items, const {}, activeDiverId: 'owner')) i.id,
  ];

  test('owner axis', () {
    expect(ids(EquipmentOwnerFilter.all), ['a', 'b']);
    expect(ids(EquipmentOwnerFilter.mine), ['a']);
    expect(ids(EquipmentOwnerFilter.sharedWithMe), ['b']);
  });

  test('a non-default owner counts as an active filter and survives copyWith', () {
    const f = EquipmentFilterState(owner: EquipmentOwnerFilter.mine);
    expect(f.hasActiveFilters, isTrue);
    expect(f.copyWith(clearType: true).owner, EquipmentOwnerFilter.mine);
    expect(f, const EquipmentFilterState(owner: EquipmentOwnerFilter.mine));
    expect(f == const EquipmentFilterState(), isFalse);
  });
}
```

Run: FAIL.

- [ ] **Step 2: Implement the owner axis**

In `equipment_filter_state.dart`:

```dart
/// Whose gear the list shows (issue #2046). Only offered with two or more
/// profiles.
enum EquipmentOwnerFilter { all, mine, sharedWithMe }
```

Add `final EquipmentOwnerFilter owner;` with constructor default `this.owner = EquipmentOwnerFilter.all`; include `owner != EquipmentOwnerFilter.all` in `hasActiveFilters`; add `EquipmentOwnerFilter? owner` to `copyWith` (`owner: owner ?? this.owner`); add it to `==`, `hashCode` and `toString`. Change `apply`:

```dart
  List<EquipmentItem> apply(
    List<EquipmentItem> equipment,
    Map<String, Iterable<String>> tagIdsByEquipment, {
    String? activeDiverId,
  }) {
    final selected = type;
    final ownerAxis = activeDiverId == null ? EquipmentOwnerFilter.all : owner;
    if (selected == null &&
        attrConditions.isEmpty &&
        tagIds.isEmpty &&
        ownerAxis == EquipmentOwnerFilter.all) {
      return equipment;
    }
    bool ownerMatches(EquipmentItem e) => switch (ownerAxis) {
      EquipmentOwnerFilter.all => true,
      EquipmentOwnerFilter.mine => e.diverId == null || e.diverId == activeDiverId,
      EquipmentOwnerFilter.sharedWithMe =>
        e.diverId != null && e.diverId != activeDiverId,
    };
    return equipment
        .where(
          (e) =>
              (selected == null || e.type == selected) &&
              attrConditions.every((c) => c.matches(e)) &&
              ownerMatches(e) &&
              (tagIds.isEmpty ||
                  (tagIdsByEquipment[e.id] ?? const <String>[]).any(
                    tagIds.contains,
                  )),
        )
        .toList();
  }
```

In `equipment_list_content.dart` pass `activeDiverId: ref.watch(validatedCurrentDiverIdProvider).value` to the `filter.apply(...)` call. Run the test: PASS.

- [ ] **Step 3: Owner chips in the filter sheet**

In `equipment_filter_sheet.dart`: add a draft field `late EquipmentOwnerFilter _owner;` seeded in `initState` from the current filter; reset to `all` in `_clearAll`; pass `owner: _owner` in `_applyFilters`; and add `_buildOwnerSection()` to the body ListView after the status section, returning `const SizedBox.shrink()` unless `ref.watch(hasMultipleDiversProvider)`:

```dart
  Widget _buildOwnerSection() {
    if (!widget.ref.watch(hasMultipleDiversProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final labels = {
      EquipmentOwnerFilter.all: l10n.equipment_list_typeFilterAll,
      EquipmentOwnerFilter.mine: l10n.equipment_filter_owner_mine,
      EquipmentOwnerFilter.sharedWithMe: l10n.equipment_sharedWithMe,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.equipment_filter_section_owner,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in labels.entries)
                ChoiceChip(
                  key: ValueKey('equipment_filter_owner_${entry.key.name}'),
                  label: Text(entry.value),
                  selected: _owner == entry.key,
                  onSelected: (_) => setState(() => _owner = entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
```

The sheet reads providers through `widget.ref` (it is constructed with `EquipmentFilterSheet(ref: ref)`); use whatever it uses for `ownedEquipmentTypesProvider`. Also make sure constructing the draft `EquipmentFilterState` in `_applyFilters` keeps every other field it already sets.

- [ ] **Step 4: Owner table column (failing test first)**

`test/features/equipment/domain/constants/equipment_field_owner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('owner is appended last so saved layouts keep their order', () {
    expect(EquipmentField.values.last, EquipmentField.owner);
    expect(EquipmentFieldAdapter.instance.fieldFromName('owner'), EquipmentField.owner);
  });

  test('owner resolves the name from the injected map', () {
    const adapter = EquipmentFieldAdapter(ownerNames: {'wife': 'Anna'});
    const item = EquipmentItem(id: 'a', diverId: 'wife', name: 'a', type: EquipmentType.bcd);
    expect(adapter.extractValue(EquipmentField.owner, item), 'Anna');
  });
}
```

If `EquipmentFieldAdapter`'s constructor is not `const`, drop `const` and pass the other required maps as `const {}`. Run: FAIL. Then in `equipment_field.dart` append `owner` after `tags` with the comment `// Owner (issue #2046). Appended for the same reason; never reordered.` and add its arm to every switch: `name` `'owner'`, `displayName` `'Owner'`, `shortLabel` `'Owner'`, `localizedDisplayName` `l10n.enum_equipmentField_owner`, `localizedShortLabel` `l10n.enum_equipmentField_owner_short`, `icon` `Icons.person_outline`, `defaultWidth` `140`, `minWidth` `90`, `sortable` `true`, `categoryName` `'details'`, `isRightAligned` `false`. In the adapter add `final Map<String, String> ownerNames;` (constructor `this.ownerNames = const {}`), `EquipmentField.owner => ownerNames[entity.diverId] ?? ''` in `extractValue`, and `EquipmentField.owner => (value as String).isEmpty ? '--' : value` in `formatValue`. In `_buildTableView` pass `ownerNames: ref.watch(diverNamesByIdProvider).value ?? const {}`. Run: PASS.

- [ ] **Step 5: Bulk Share and owner-only bulk delete (failing tests first)**

Add a group to `equipment_list_content_test.dart` with `_buildPhoneOverrides(items: [own, wifes])` plus `allDiversProvider` (Bill `owner`, Anna `wife`, Tom `son`), `validatedCurrentDiverIdProvider` (`'owner'`) and `equipmentListNotifierProvider` overridden with a fake notifier whose `deleteEquipment(id)` returns `id == 'mine'`:

1. Enter selection mode, check `My BCD`, open the bulk actions, expect `Share with...` enabled; check `Her Reg` too, expect it disabled.
2. Check both, tap delete, confirm, expect the snackbar text `Deleted 1 item. 1 shared item was kept: only its owner can delete it`.

Use the file's `selection_contract.dart` / `bulk_delete_contract.dart` helpers for entering selection and finding actions. Run: FAIL.

Then in `_bulkActions`, read `final multipleDivers = ref.watch(hasMultipleDiversProvider); final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;` and add, after `editTags`:

```dart
      if (multipleDivers)
        BulkAction(
          id: 'share',
          icon: Icons.share,
          label: context.l10n.equipment_bulkShare_action,
          isEnabled: (ids) =>
              everyChecked(ids, (e) => e.diverId == activeDiverId),
          onInvoke: () => _shareSelected(activeDiverId),
        ),
```

and the handler:

```dart
  Future<BulkActionOutcome> _shareSelected(String? activeDiverId) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty || activeDiverId == null) return BulkActionOutcome.cancelled;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final divers = await ref.read(allDiversProvider.future);
    final others = [for (final d in divers) if (d.id != activeDiverId) d];
    if (!mounted) return BulkActionOutcome.cancelled;
    final chosen = await showProfileChecklistDialog(
      context,
      title: l10n.equipment_sharing_dialogTitle,
      body: l10n.equipment_sharing_dialogBody,
      profiles: others,
      initiallySelected: const {},
      confirmLabel: l10n.common_action_share,
      allowEmpty: false,
    );
    if (chosen == null) return BulkActionOutcome.cancelled;
    try {
      final result = await ref.read(equipmentShareRepositoryProvider).shareMany(
        equipmentIds: ids,
        diverIds: chosen.toList(),
        actingDiverId: activeDiverId,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(result.skippedNotOwned == 0
            ? l10n.equipment_bulkShare_done(result.itemsChanged)
            : l10n.equipment_bulkShare_doneSkipped(
                result.itemsChanged, result.skippedNotOwned)),
      ));
      return BulkActionOutcome.completed;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
      return BulkActionOutcome.failed;
    }
  }
```

In `_confirmAndDelete` replace the delete loop and snackbar:

```dart
    var deleted = 0;
    for (final id in ids) {
      if (await notifier.deleteEquipment(id)) deleted++;
    }
    final skipped = ids.length - deleted;

    if (!mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          skipped == 0
              ? context.l10n.common_bulkDelete_snackbar(deleted)
              : context.l10n.equipment_bulkDelete_partial(deleted, skipped),
        ),
      ),
    );
```

Run the list tests: PASS.

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/equipment test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/features/equipment/domain/models/equipment_filter_state.dart lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart lib/features/equipment/domain/constants/equipment_field.dart test/features/equipment/domain/models/equipment_filter_state_owner_test.dart test/features/equipment/domain/constants/equipment_field_owner_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git commit -m "feat(equipment): share in bulk and filter the list by owner"
```

---

## Task 13: Settings > Shared data: "Share all my equipment..."

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`SharedDataSectionContent` rows ~2750-2763; new `_confirmAndBulkShareEquipment` next to `_confirmAndBulkShareTrips` ~2632-2689)
- Test: `test/features/settings/presentation/pages/shared_data_equipment_test.dart`

**Interfaces:**
- Consumes: `EquipmentShareRepository.shareAllForDiver`, `showProfileChecklistDialog`.

- [ ] **Step 1: Failing test**

Pump `SharedDataSectionContent` inside `testApp` with overrides: `allDiversProvider` (Bill `owner`, Anna `wife`), `validatedCurrentDiverIdProvider` (`'owner'`), `allEquipmentProvider` returning two items owned by `owner` and one by `wife`, `shareByDefaultProvider` (whatever the page's switch needs, see the file's other tests via `grep -rln SharedDataSectionContent test`), and `equipmentShareRepositoryProvider` overridden with a fake:

```dart
class _FakeShareRepository extends EquipmentShareRepository {
  ({String ownerId, List<String> diverIds})? call;
  @override
  Future<EquipmentShareResult> shareAllForDiver({
    required String ownerId,
    required List<String> diverIds,
  }) async {
    call = (ownerId: ownerId, diverIds: diverIds);
    return const EquipmentShareResult(added: 2, itemsChanged: 2);
  }
}
```

Test: tap `Share all my equipment...`, expect the dialog body `Share your 2 items with the profiles you choose.`, tap `Anna`, tap `Share`, expect `fake.call` to be `(ownerId: 'owner', diverIds: ['wife'])` and the snackbar `Shared 2 items`. Run: FAIL.

- [ ] **Step 2: Implement**

After the trips `ListTile` in `SharedDataSectionContent`:

```dart
          const Divider(height: 1),
          ListTile(
            title: Text(context.l10n.settings_shareAllEquipment_title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmAndBulkShareEquipment(context, ref),
          ),
```

and next to `_confirmAndBulkShareTrips`:

```dart
  /// Shares every item the active diver owns with the profiles picked in
  /// the checklist (issue #2046). Per profile, unlike sites and trips, which
  /// share with every profile at once.
  Future<void> _confirmAndBulkShareEquipment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    final visible = await ref.read(allEquipmentProvider.future);
    final ownedCount = visible.where((e) => e.diverId == diverId).length;
    if (ownedCount == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settings_shareAll_noneToShare)),
      );
      return;
    }
    final divers = await ref.read(allDiversProvider.future);
    final others = [for (final d in divers) if (d.id != diverId) d];
    if (others.isEmpty || !context.mounted) return;
    final chosen = await showProfileChecklistDialog(
      context,
      title: l10n.settings_shareAllEquipment_title,
      body: l10n.settings_shareAllEquipment_body(ownedCount),
      profiles: others,
      initiallySelected: const {},
      confirmLabel: l10n.common_action_share,
      allowEmpty: false,
    );
    if (chosen == null) return;
    try {
      final result = await ref
          .read(equipmentShareRepositoryProvider)
          .shareAllForDiver(ownerId: diverId, diverIds: chosen.toList());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipment_bulkShare_done(result.itemsChanged))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.common_error_tryAgain),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }
```

If `_confirmAndBulkShareTrips` is a method on a widget class rather than top-level, put this one in the same place and match its receiver. Run the test: PASS.

- [ ] **Step 3: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/pages/settings_page.dart test/features/settings/presentation/pages/shared_data_equipment_test.dart
git commit -m "feat(settings): share all my equipment with chosen profiles"
```

---

## Task 14: Sets keep unshared members but stop applying them

**Files:**
- Create: `lib/features/equipment/presentation/utils/usable_set_items.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3558-3583` (`_addGear`)
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` (row subtitles, arranged list ~lines 231-240)
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` (above the checkbox list ~line 399)
- Test: `test/features/equipment/presentation/utils/usable_set_items_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_unshared_test.dart`

**Interfaces:**
- Consumes: `EquipmentRepository.visibleIdsAmong` (Task 4).
- Produces: `List<EquipmentItem> usableSetItems(Iterable<EquipmentItem> items, Set<String> visibleIds)`.

- [ ] **Step 1: Failing unit test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/usable_set_items.dart';

void main() {
  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.bcd);

  test('keeps visible members in set order', () {
    expect(
      usableSetItems([item('c'), item('a'), item('b')], {'a', 'c'}).map((i) => i.id),
      ['c', 'a'],
    );
  });

  test('nothing visible applies nothing', () {
    expect(usableSetItems([item('a')], const {}), isEmpty);
  });
}
```

Run: FAIL (file missing).

- [ ] **Step 2: Implement the helper**

```dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The members of a set a diver can still put on a dive: those in
/// [visibleIds] (owned or shared). A member whose share was removed stays
/// in the set, shown as "No longer shared", but is not applied (issue
/// #2046). Set order is kept.
List<EquipmentItem> usableSetItems(
  Iterable<EquipmentItem> items,
  Set<String> visibleIds,
) => [
  for (final item in items)
    if (visibleIds.contains(item.id)) item,
];
```

Run: PASS.

- [ ] **Step 3: Apply it where a set reaches a dive**

Every set path on the dive edit page (the set picker, the geofence suggestion, the on-empty default set) goes through `_addGear(items, viaSetId: ...)`. At the top of `_addGear`, after `if (items.isEmpty) return;`:

```dart
    // A set can list gear no longer shared with this dive's diver; it stays
    // in the set but is not applied (issue #2046).
    var toAdd = items;
    if (viaSetId != null) {
      final diverId =
          _existingDive?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      if (!mounted) return;
      if (diverId != null) {
        final visible = await ref
            .read(equipmentRepositoryProvider)
            .visibleIdsAmong(items.map((i) => i.id), diverId);
        if (!mounted) return;
        toAdd = usableSetItems(items, visible);
      }
    }
    if (toAdd.isEmpty) return;
```

and use `toAdd` instead of `items` in the rest of the method. Use the page's real field for the loaded dive (the one read at line 5250).

- [ ] **Step 4: "No longer shared" on the set pages (failing test first)**

`test/features/equipment/presentation/pages/equipment_set_detail_unshared_test.dart`: copy the pump setup of `test/features/equipment/presentation/pages/equipment_set_detail_geofence_test.dart`, give the set two items `mine` and `gone`, override `allEquipmentProvider` to return only `mine`, and expect `find.text('No longer shared')` once, under `gone`. Run: FAIL.

In `equipment_set_detail_page.dart`, read `final visibleIds = ref.watch(allEquipmentProvider).value?.map((e) => e.id).toSet();` and, where each item row builds its subtitle from `labels[item.id]`, append `context.l10n.equipment_set_noLongerShared` to the subtitle parts when `visibleIds != null && !visibleIds.contains(item.id)`. In `equipment_set_edit_page.dart`, above the checkbox list, render a disabled `ListTile(title: Text(item.name), subtitle: Text(context.l10n.equipment_set_noLongerShared), enabled: false)` for each `set.items` entry whose id is not in `allEquipmentProvider`'s ids (the page already keeps such ids selected in `_selectedEquipmentIds`, so saving keeps them in the set). Run: PASS.

- [ ] **Step 5: Run and commit**

Run: `flutter test test/features/equipment test/features/dive_log/presentation test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/presentation/utils/usable_set_items.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/equipment/presentation/pages/equipment_set_detail_page.dart lib/features/equipment/presentation/pages/equipment_set_edit_page.dart test/features/equipment/presentation/utils/usable_set_items_test.dart test/features/equipment/presentation/pages/equipment_set_detail_unshared_test.dart
git commit -m "feat(equipment): keep unshared gear in sets without applying it"
```

---

## Task 15: History data: usage runs and the event log, merged

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_history_builder.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_history_providers.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (new `getUsageByDiver` after `getItemExposure` ~line 1140)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart`
- Test: `test/features/equipment/domain/services/equipment_history_builder_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_usage_by_diver_test.dart`

**Interfaces:**
- Consumes: `getItemExposure` (existing), `EquipmentShareRepository.getEventsFor` (Task 3).
- Produces:
  - `typedef EquipmentUsageDive = ({String diveId, String? diverId, DateTime date});`
  - `sealed class EquipmentHistoryEntry` with subclasses `EquipmentUsageRun({String? diverId, DateTime first, DateTime last, int diveCount})`, `EquipmentEventEntry({EquipmentOwnershipEvent event})`, `EquipmentAddedEntry({String? ownerId, DateTime at})`, each exposing `DateTime get at`
  - `List<EquipmentHistoryEntry> buildEquipmentHistory({required List<EquipmentUsageDive> dives, required List<EquipmentOwnershipEvent> events, required String? currentOwnerId, required DateTime? createdAt})` (newest first)
  - `EquipmentRepository.getUsageByDiver(EquipmentItem item) -> Future<List<EquipmentUsageDive>>`
  - `equipmentHistoryProvider` (`FutureProvider.family<List<EquipmentHistoryEntry>, String>`)

- [ ] **Step 1: Failing builder test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';

void main() {
  DateTime d(int day) => DateTime.utc(2026, 1, day);
  EquipmentUsageDive dive(String id, String? diver, int day) =>
      (diveId: id, diverId: diver, date: d(day));
  EquipmentOwnershipEvent event(
    EquipmentOwnershipEventKind kind,
    int day, {String? from, String? to}) =>
      EquipmentOwnershipEvent(
        id: 'e$day', equipmentId: 'x', kind: kind,
        fromDiverId: from, toDiverId: to, occurredAt: d(day),
      );

  test('folds consecutive dives by diver into runs, A B A is three runs', () {
    final history = buildEquipmentHistory(
      // fed out of date order on purpose
      dives: [dive('3', 'bill', 5), dive('1', 'bill', 1), dive('4', 'bill', 6),
              dive('2', 'anna', 3), dive('0', 'bill', 2)],
      events: const [],
      currentOwnerId: 'bill',
      createdAt: null,
    );
    final runs = history.whereType<EquipmentUsageRun>().toList();
    expect(runs.map((r) => (r.diverId, r.diveCount)), [
      ('bill', 2), // days 5-6, newest first
      ('anna', 1),
      ('bill', 2), // days 1-2
    ]);
    expect(runs.first.first, d(5));
    expect(runs.first.last, d(6));
  });

  test('interleaves events and runs newest first, added entry last', () {
    final history = buildEquipmentHistory(
      dives: [dive('1', 'bill', 2), dive('2', 'anna', 8)],
      events: [event(EquipmentOwnershipEventKind.shared, 5, from: 'bill', to: 'anna')],
      currentOwnerId: 'bill',
      createdAt: d(1),
    );
    expect(history.map((e) => e.runtimeType), [
      EquipmentUsageRun, EquipmentEventEntry, EquipmentUsageRun, EquipmentAddedEntry,
    ]);
    expect((history.last as EquipmentAddedEntry).ownerId, 'bill');
  });

  test('the original owner is the first transfer from side', () {
    final history = buildEquipmentHistory(
      dives: const [],
      events: [
        event(EquipmentOwnershipEventKind.transferred, 4, from: 'bill', to: 'tom'),
        event(EquipmentOwnershipEventKind.transferred, 9, from: 'tom', to: 'anna'),
      ],
      currentOwnerId: 'anna',
      createdAt: d(1),
    );
    expect((history.last as EquipmentAddedEntry).ownerId, 'bill');
  });

  test('an event naming the same profile on both sides is skipped', () {
    final history = buildEquipmentHistory(
      dives: const [],
      events: [event(EquipmentOwnershipEventKind.shared, 3, from: 'bill', to: 'bill')],
      currentOwnerId: 'bill',
      createdAt: d(1),
    );
    expect(history.whereType<EquipmentEventEntry>(), isEmpty);
  });

  test('no created date gives no added entry; no dives gives no runs', () {
    expect(
      buildEquipmentHistory(
        dives: const [], events: const [], currentOwnerId: 'bill', createdAt: null,
      ),
      isEmpty,
    );
  });

  test('same-day dives order by dive id for a stable fold', () {
    final history = buildEquipmentHistory(
      dives: [dive('b', 'anna', 1), dive('a', 'bill', 1), dive('c', 'bill', 1)],
      events: const [], currentOwnerId: 'bill', createdAt: null,
    );
    expect(history.whereType<EquipmentUsageRun>().map((r) => r.diverId),
        ['bill', 'anna', 'bill']);
  });
}
```

Run: FAIL (file missing).

- [ ] **Step 2: Implement the builder**

`lib/features/equipment/domain/services/equipment_history_builder.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';

/// One dive an item was used on, with the dive's diver (issue #2046).
typedef EquipmentUsageDive = ({String diveId, String? diverId, DateTime date});

/// One line of an item's History card.
sealed class EquipmentHistoryEntry extends Equatable {
  const EquipmentHistoryEntry();

  /// When the entry happened, for ordering: a run's last dive, an event's
  /// time, the item's creation.
  DateTime get at;
}

/// Consecutive dives by one diver.
class EquipmentUsageRun extends EquipmentHistoryEntry {
  final String? diverId;
  final DateTime first;
  final DateTime last;
  final int diveCount;

  const EquipmentUsageRun({
    required this.diverId,
    required this.first,
    required this.last,
    required this.diveCount,
  });

  @override
  DateTime get at => last;

  @override
  List<Object?> get props => [diverId, first, last, diveCount];
}

class EquipmentEventEntry extends EquipmentHistoryEntry {
  final EquipmentOwnershipEvent event;

  const EquipmentEventEntry(this.event);

  @override
  DateTime get at => event.occurredAt;

  @override
  List<Object?> get props => [event];
}

/// The item's creation by its original owner. No event is written for it:
/// the owner is the first transfer's from side, or the current owner.
class EquipmentAddedEntry extends EquipmentHistoryEntry {
  final String? ownerId;
  @override
  final DateTime at;

  const EquipmentAddedEntry({required this.ownerId, required this.at});

  @override
  List<Object?> get props => [ownerId, at];
}

/// An item's history, newest first (issue #2046): usage runs folded from
/// [dives] (any order), the share and ownership [events] (an event naming the
/// same profile on both sides, left by a profile merge, is skipped), and the
/// item's creation when [createdAt] is known. Ties order events, then runs,
/// then the creation.
List<EquipmentHistoryEntry> buildEquipmentHistory({
  required List<EquipmentUsageDive> dives,
  required List<EquipmentOwnershipEvent> events,
  required String? currentOwnerId,
  required DateTime? createdAt,
}) {
  final sorted = [...dives]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.diveId.compareTo(b.diveId);
    });
  final runs = <EquipmentUsageRun>[];
  for (final dive in sorted) {
    final last = runs.isEmpty ? null : runs.last;
    if (last != null && last.diverId == dive.diverId) {
      runs[runs.length - 1] = EquipmentUsageRun(
        diverId: last.diverId,
        first: last.first,
        last: dive.date,
        diveCount: last.diveCount + 1,
      );
    } else {
      runs.add(
        EquipmentUsageRun(
          diverId: dive.diverId,
          first: dive.date,
          last: dive.date,
          diveCount: 1,
        ),
      );
    }
  }

  final kept = [
    for (final e in events)
      if (e.fromDiverId == null || e.fromDiverId != e.toDiverId) e,
  ];
  final firstTransfer = kept
      .where((e) => e.kind == EquipmentOwnershipEventKind.transferred)
      .fold<EquipmentOwnershipEvent?>(
        null,
        (earliest, e) =>
            earliest == null || e.occurredAt.isBefore(earliest.occurredAt)
            ? e
            : earliest,
      );

  int rank(EquipmentHistoryEntry e) => switch (e) {
    EquipmentEventEntry() => 0,
    EquipmentUsageRun() => 1,
    EquipmentAddedEntry() => 2,
  };

  return [
    for (final e in kept) EquipmentEventEntry(e),
    ...runs,
    if (createdAt != null)
      EquipmentAddedEntry(
        ownerId: firstTransfer?.fromDiverId ?? currentOwnerId,
        at: createdAt,
      ),
  ]..sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    return byTime != 0 ? byTime : rank(a).compareTo(rank(b));
  });
}
```

Note the "added" tie rule: the creation must stay last even when a dive or event has the same timestamp, which the rank order guarantees. Run the builder test: PASS.

- [ ] **Step 3: Failing repository test**

`test/features/equipment/data/repositories/equipment_usage_by_diver_test.dart`: seed divers `owner` and `wife`; a cylinder item `cyl` owned by `owner` (`type: 'tank'`); dive `d1` by `owner` linking `cyl` through `dive_equipment`; dive `d2` by `wife` linking it only through `dive_tanks.equipment_id`; dive `d3` by `wife` with no link. Then:

```dart
  test('returns the clock dive set with each dive diver', () async {
    final repo = EquipmentRepository();
    final item = (await repo.getEquipmentById('cyl'))!;
    final usage = await repo.getUsageByDiver(item);
    expect({for (final u in usage) u.diveId: u.diverId}, {'d1': 'owner', 'd2': 'wife'});
  });
```

Insert the `dive_tanks` row with its real required columns (see `DiveTanksCompanion` usage in `test/core/services/sync/equipment_tombstone_tank_link_test.dart`). Run: FAIL (method missing).

- [ ] **Step 4: Implement `getUsageByDiver`**

After `getItemExposure`:

```dart
  /// The dives [item] was used on, each with its diver, for the item's
  /// History card (issue #2046). The same dive set the service clocks count
  /// ([getItemExposure]), so the card and the clocks never disagree.
  // stats-scope-exempt: gear wear is physical, not descriptive
  Future<List<({String diveId, String? diverId, DateTime date})>>
  getUsageByDiver(EquipmentItem item) async {
    final exposure = await getItemExposure(item);
    final ids = [for (final s in exposure.samples) s.diveId];
    final diverByDive = <String, String?>{};
    for (var i = 0; i < ids.length; i += 900) {
      final chunk = ids.sublist(i, (i + 900).clamp(0, ids.length));
      final rows =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.id, _db.dives.diverId])
                ..where(_db.dives.id.isIn(chunk)))
              .get();
      for (final r in rows) {
        diverByDive[r.read(_db.dives.id)!] = r.read(_db.dives.diverId);
      }
    }
    return [
      for (final s in exposure.samples)
        (diveId: s.diveId, diverId: diverByDive[s.diveId], date: s.date),
    ];
  }
```

If `test/core/database/dive_stats_scope_census_test.dart` flags the method, move the `stats-scope-exempt` comment to where that census looks (its failure message names the expected spot). Run: PASS.

- [ ] **Step 5: The provider**

`lib/features/equipment/presentation/providers/equipment_history_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';

/// [equipmentId]'s History card entries, newest first (issue #2046).
final equipmentHistoryProvider =
    FutureProvider.family<List<EquipmentHistoryEntry>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      final shares = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
      ref.invalidateSelfWhen(shares.watchChanges());
      final item = await repository.getEquipmentById(equipmentId);
      if (item == null) return const [];
      return buildEquipmentHistory(
        dives: await repository.getUsageByDiver(item),
        events: await shares.getEventsFor(equipmentId),
        currentOwnerId: item.diverId,
        createdAt: item.createdAt,
      );
    });
```

Use the same import for `diveRepositoryProvider` that `equipment_providers.dart` uses. Add to `_tickGroup('equipment', ...)` in `provider_tick_build_smoke_test.dart`:

```dart
    (
      name: 'equipmentHistoryProvider',
      read: (c) => c.read(equipmentHistoryProvider(_id).future),
    ),
```

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/equipment test/architecture/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/domain/services/equipment_history_builder.dart lib/features/equipment/presentation/providers/equipment_history_providers.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart test/features/equipment/domain/services/equipment_history_builder_test.dart test/features/equipment/data/repositories/equipment_usage_by_diver_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(equipment): build an item history from its dives and share log"
```

---

## Task 16: The History card on the item page

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_history_card.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (before `ServiceHistorySection` ~line 248)
- Modify: `test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart` (add the `equipmentHistoryProvider` override if not added in Task 11)
- Test: `test/features/equipment/presentation/widgets/equipment_history_card_test.dart`

**Interfaces:**
- Consumes: `equipmentHistoryProvider` (Task 15), `diverNamesByIdProvider`, `hasMultipleDiversProvider`.
- Produces: `EquipmentHistoryCard({required String equipmentId})`.

- [ ] **Step 1: Failing widget test**

Pump `EquipmentHistoryCard(equipmentId: 'x')` with `testApp` and overrides: `settingsProvider` (`MockSettingsNotifier()`), `allDiversProvider` (Bill `owner`, Anna `wife`), `validatedCurrentDiverIdProvider` (`'owner'`), and

```dart
      equipmentHistoryProvider('x').overrideWith((ref) async => [
        EquipmentUsageRun(diverId: 'wife', first: DateTime(2026, 3, 1), last: DateTime(2026, 3, 9), diveCount: 4),
        EquipmentEventEntry(EquipmentOwnershipEvent(
          id: 'e', equipmentId: 'x', kind: EquipmentOwnershipEventKind.shared,
          fromDiverId: 'owner', toDiverId: null, occurredAt: DateTime(2026, 2, 1),
        )),
        EquipmentUsageRun(diverId: 'owner', first: DateTime(2026, 1, 2), last: DateTime(2026, 1, 2), diveCount: 1),
        EquipmentAddedEntry(ownerId: 'owner', at: DateTime(2026, 1, 1)),
      ]),
```

Expectations:

```dart
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('4 dives'), findsOneWidget);
    expect(find.text('Shared with a deleted profile'), findsOneWidget);
    expect(find.text('Added by Bill'), findsOneWidget);
```

A second test with one profile in `allDiversProvider` expects `find.text('History')` to find nothing. A third test taps the `Bill` run inside a `MaterialApp.router` with a `/dives` route and checks `container.read(diveFilterProvider).equipmentIds == ['x']`; tapping the `Anna` run changes nothing. Run: FAIL.

- [ ] **Step 2: Implement the card**

`lib/features/equipment/presentation/widgets/equipment_history_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_history_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Who used an item, when, and every share and ownership change (issue
/// #2046). Shown only when two or more profiles exist. The active diver's
/// own runs open their dive list filtered to the item; other divers' runs
/// are not tappable, because the dive list shows only the active profile.
class EquipmentHistoryCard extends ConsumerWidget {
  final String equipmentId;

  const EquipmentHistoryCard({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasMultipleDiversProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final entries = ref.watch(equipmentHistoryProvider(equipmentId)).value;

    String nameOf(String? id) => id == null
        ? l10n.equipment_history_deletedProfile
        : names[id] ?? l10n.equipment_owner_unknown;

    Widget tile(EquipmentHistoryEntry entry) => switch (entry) {
      EquipmentUsageRun(:final diverId, :final first, :final last, :final diveCount) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.scuba_diving),
          title: Text(nameOf(diverId)),
          subtitle: Text(
            '${l10n.equipment_history_runDives(diveCount)} · '
            '${first == last ? units.formatDate(first) : l10n.equipment_history_dateRange(units.formatDate(first), units.formatDate(last))}',
          ),
          trailing: diverId == activeDiverId
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: diverId == activeDiverId && diverId != null
              ? () {
                  ref.read(diveFilterProvider.notifier).state =
                      DiveFilterState(equipmentIds: [equipmentId]);
                  context.go('/dives');
                }
              : null,
        ),
      EquipmentEventEntry(:final event) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(switch (event.kind) {
          EquipmentOwnershipEventKind.shared => Icons.share,
          EquipmentOwnershipEventKind.unshared => Icons.person_remove_outlined,
          EquipmentOwnershipEventKind.transferred => Icons.swap_horiz,
        }),
        title: Text(switch (event.kind) {
          EquipmentOwnershipEventKind.shared =>
            l10n.equipment_history_shared(nameOf(event.toDiverId)),
          EquipmentOwnershipEventKind.unshared =>
            l10n.equipment_history_unshared(nameOf(event.toDiverId)),
          EquipmentOwnershipEventKind.transferred =>
            l10n.equipment_history_transferred(
              nameOf(event.fromDiverId),
              nameOf(event.toDiverId),
            ),
        }),
        subtitle: Text(units.formatDate(event.occurredAt)),
      ),
      EquipmentAddedEntry(:final ownerId, :final at) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline),
        title: Text(l10n.equipment_history_added(nameOf(ownerId))),
        subtitle: Text(units.formatDate(at)),
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.equipment_history_title, style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(),
            if (entries == null)
              const Center(child: CircularProgressIndicator())
            else if (!entries.any((e) => e is EquipmentUsageRun))
              ...[
                Text(
                  l10n.equipment_history_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final e in entries) tile(e),
              ]
            else
              for (final e in entries) tile(e),
          ],
        ),
      ),
    );
  }
}
```

Check two things against the codebase before running: `Icons.scuba_diving` exists in the Flutter SDK in use (otherwise use `equipmentTypeIcon` for the item's type or `Icons.pool`), and `diveFilterProvider` is exported from `dive_providers.dart` (the detail page's Dives row uses it; copy that import). Remove the loading spinner if the page's other cards render nothing while loading; match `ServiceHistorySection`.

- [ ] **Step 3: Place it on the page**

In `equipment_detail_page.dart`, directly before `ServiceHistorySection(equipmentId: ...)`:

```dart
            EquipmentHistoryCard(equipmentId: equipment.id),
            const SizedBox(height: 24),
```

Only add the gap when the card shows: wrap both in `if (ref.watch(hasMultipleDiversProvider)) ...[...]` so a single-profile page keeps its current spacing. Add `equipmentHistoryProvider(id).overrideWith((ref) async => const [])` to the detail page tests that override `allDiversProvider` with two profiles (Task 11's file).

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/equipment test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/presentation/widgets/equipment_history_card.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/widgets/equipment_history_card_test.dart test/features/equipment/presentation/pages/equipment_detail_sharing_test.dart
git commit -m "feat(equipment): show an item's history of users and shares"
```

---

## Task 17: The Dives count matches the list it opens

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart:940-962` (`getDiveCountForEquipment`)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart:291-299` (`equipmentDiveCountProvider`)
- Test: `test/features/equipment/data/repositories/equipment_dive_count_test.dart`

**Interfaces:**
- Produces: `EquipmentRepository.getDiveCountForEquipment(String equipmentId, {String? diverId})`. A null `diverId` counts every diver's dives (the assembly history dialog keeps calling it that way).

- [ ] **Step 1: Failing test**

Seed divers `owner` and `wife`; item `cyl` owned by `owner`; dives: `d1` (owner, linked through `dive_equipment`), `d2` (owner, linked only through `dive_tanks.equipment_id`), `d3` (wife, linked through `dive_equipment`).

```dart
  test('counts the active diver dives with the dive filter link set', () async {
    final repo = EquipmentRepository();
    expect(await repo.getDiveCountForEquipment('cyl', diverId: 'owner'), 2);
    expect(await repo.getDiveCountForEquipment('cyl', diverId: 'wife'), 1);
    expect(await repo.getDiveCountForEquipment('cyl'), 3);
  });

  test('a dive linked both ways counts once', () async {
    // add a dive_tanks row for d1 as well
    expect(await EquipmentRepository().getDiveCountForEquipment('cyl', diverId: 'owner'), 2);
  });
```

In the second test, insert the extra `dive_tanks` row for `d1` before the assertion. Run: FAIL (today the count ignores the diver and the tank link: 2, 2, 2).

- [ ] **Step 2: Implement**

```dart
  /// Dives [equipmentId] is on, for the item page's Dives row: linked
  /// directly or through a tank the registry matched to a cylinder, the link
  /// set the dive list's equipment filter uses, so the row's count and the
  /// list it opens agree. With [diverId], only that diver's dives, since the
  /// dive list shows only the active profile (issue #2046).
  Future<int> getDiveCountForEquipment(
    String equipmentId, {
    String? diverId,
  }) async {
    try {
      // stats-scope-exempt: matches the dive list, which ignores stats scope
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) AS count
        FROM dives d
        WHERE (EXISTS (SELECT 1 FROM dive_equipment de
                       WHERE de.dive_id = d.id AND de.equipment_id = ?1)
            OR EXISTS (SELECT 1 FROM dive_tanks dt
                       WHERE dt.dive_id = d.id AND dt.equipment_id = ?1))
          AND (?2 IS NULL OR d.diver_id = ?2)
      ''',
            variables: [
              Variable.withString(equipmentId),
              Variable<String>(diverId),
            ],
          )
          .getSingle();
      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Keep the existing exempt comment's placement if the stats-scope census requires it in a particular spot. In `equipmentDiveCountProvider`:

```dart
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getDiveCountForEquipment(equipmentId, diverId: diverId);
```

Fakes that override `getDiveCountForEquipment(String)` in tests (grep `getDiveCountForEquipment` under `test/`) must gain the `{String? diverId}` parameter to keep compiling.

- [ ] **Step 3: Run and commit**

Run: `flutter test test/features/equipment test/core/database/dive_stats_scope_census_test.dart test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/equipment/presentation/providers/equipment_providers.dart test/features/equipment/data/repositories/equipment_dive_count_test.dart
git commit -m "fix(equipment): count only the dives the Dives row opens"
```

(Add any test fakes you updated.)

---

## Task 18: Exports include shared gear

`allEquipmentProvider` now returns visible gear (Task 4), so the full UDDF export, the equipment CSV, the maintenance log and the check-ins export include shared items with no code change. This task pins that.

**Files:**
- Test: `test/features/equipment/presentation/providers/all_equipment_shared_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'bcd', name: 'bcd', type: 'bcd', createdAt: t, updatedAt: t,
        diverId: const Value('owner'),
      ),
    );
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['bcd'], diverIds: ['wife'], actingDiverId: 'owner',
    );
  });

  tearDown(tearDownTestDatabase);

  test('the list every export reads includes gear shared with the diver', () async {
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'wife'),
      ],
    );
    addTearDown(container.dispose);
    final items = await container.read(allEquipmentProvider.future);
    expect(items.map((e) => e.id), ['bcd']);
  });
}
```

- [ ] **Step 2: Run and commit**

Run: `flutter test test/features/equipment/presentation/providers/all_equipment_shared_test.dart`
Expected: PASS (Task 4 already made it true). If it fails, the export path reads a different provider; fix that provider to use the visible list rather than weakening the test.

```bash
dart format test
git add test/features/equipment/presentation/providers/all_equipment_shared_test.dart
git commit -m "test(equipment): pin shared gear in the list exports read"
```

---

## Task 19: Whole-branch verification and the PR

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes left unformatted, "No issues found!".

- [ ] **Step 2: One full test run**

Check the RAM-disk temp space first if this machine uses one (`df -h "$TMPDIR"`; clear leftover `flutter_tools.*` directories if it is nearly full). Then run the whole suite once:

Run: `flutter test`
Expected: all pass. Do not overlap this with another local test run.

- [ ] **Step 3: Spec coverage check**

Walk the spec's PR 2 list and "Equipment history" section and tick each against the commits: v228 tables and indexes; sync for both; visibility filter in the six methods; the two explicit owner checks; gear owner hydration; owner chips; picker sections; detail row and sharee view; bulk Share; Owner filter; Owner column; Settings row; service kind names and scheduler kinds; exports; share events; usage runs and History card; Dives count. Anything missing becomes a new task before the PR.

- [ ] **Step 4: Run the app and capture screenshots**

Launch the macOS build from this worktree (not the installed app). With two profiles, capture before (from `main`) and after for: the equipment picker with a "Shared with me" section; an item page as owner (Shared with row, History card) and as a sharee (Owned by row, no delete); the list with an owner chip and the Owner filter; Settings > Shared data with the new row. Capture light and dark for the item page, and phone width (resize the window narrow) plus desktop width for the picker and the item page. Save the images under the session scratchpad and list them for the maintainer.

- [ ] **Step 5: Ask before pushing**

Stop and ask the user to approve pushing the branch and opening the PR. Do not push or open it without that approval.

- [ ] **Step 6: Open the PR (after approval)**

Push with `git push -u origin ericgriffin/equipment-sharing-profiles-67d843`, then open the PR with the repository template. Title: `feat(equipment): share gear between diver profiles and show its history`. The body's summary covers what ships (sharing, the History card, the Dives count fix) and what is deferred to PR 3 (transfer, kept-item handling on diver deletion). It contains `Closes #2046` and `Refs #1549` on their own lines, and the Screenshots section lists each captured image by what it shows, noting that the images are attached separately. No attribution lines of any kind.
