# Multiple Roles Per Person On A Dive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the diver and each buddy hold several roles on one dive (e.g. Divemaster and Dive Guide), stored in two new synced junction tables, with every reader, writer, importer and exporter of roles updated.

**Architecture:** Two junction tables (`dive_diver_roles`, `dive_buddy_roles`) hold the role sets. The existing scalars (`dives.diver_role`, `dive_buddies.role`) stay as the primary-role mirror for older app versions. One pure helper (`DiveRoleSet`) owns ordering, normalization (Solo exclusivity), resolution (the self-healing read rule) and merging; one repository (`DiveRoleLinkRepository`) owns every junction read and write. Entities switch to lists (`Dive.diverRoleIds`, `BuddyWithRole.roles`) and every consumer is moved onto them.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-05-multiple-dive-roles-design.md`

## Global Constraints

- Schema version 262 (`AppDatabase.currentSchemaVersion = 262`); 261 is held by open PR #2985. Re-check the next free rung before pushing. (Shipped as v272: main shipped v261 through v271, apart from 268 which an open branch holds, so every v262 below became v272 as main was merged in.)
- `AppDatabase.minimumCompatibleSchemaVersion` stays 240 (the sync floor is NOT raised).
- New tables live in `lib/core/database/tables/buddy_tables.dart`; the rung goes in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`; the helper in `lib/core/database/migrations/helpers/buddy_migrations.dart`. Never add a table or rung to `database.dart` beyond registering the table class and the version.
- Junction primary keys are surrogate uuids, never composite (#347). `role_id` has no foreign key.
- Canonical role order: built-in ids in `DiveRole.builtInIds` order, then any other id ascending. The primary role is the first id of a normalized set.
- Solo is exclusive: a normalized set never holds `solo` beside another role (Solo is dropped).
- A buddy's role set is never empty (empty normalizes to `['buddy']`); the diver's may be empty.
- No new l10n strings: reuse `common_action_done`, `buddies_picker_noRole`, `diveLog_bulkEdit_buddyRoleMixed`.
- No em dashes anywhere (code, comments, docs, commits). No mention of any AI tool in commits or PR text.
- After every task: `dart format .`, `flutter analyze` (zero issues), the task's tests. After any task that adds a file under `lib/`: `flutter test test/architecture/`.
- Platform-agnostic paths in tests (`p.join`, `Directory.systemTemp`); restore any process-wide state a test replaces.

## Review Focus

1. **A dive edited on an older app version after a multi-role save.** The older phone changes `dives.diver_role` (or `dive_buddies.role`) and nothing else. Expected: the newer phone shows exactly the role the older phone set, not the stale set. Pinned by `DiveRoleSet.resolve` tests in Task 1 and the repository test "an older peer's scalar change wins" in Task 5.
2. **An older peer re-saves a dive's buddies (delete-and-reinsert with fresh `dive_buddies` ids).** Expected: each buddy's extra roles survive, because the junction is keyed on (dive, buddy). Pinned by the Task 7 test "buddy roles survive a dive_buddies row being replaced".
3. **Removing a buddy from a dive.** Expected: their `dive_buddy_roles` rows are deleted and tombstoned, so a later re-add starts from Buddy, not the old set. Pinned by the Task 7 test "removing a buddy tombstones their role rows".
4. **Two devices adding the same role to the same person while apart.** Expected: one row survives on both (lowest id), no duplicate and no unique-index crash. Pinned by the Task 3 sync tests.
5. **Merging or consolidating dives where a person is on both.** Expected: their roles are unioned, Solo-normalized, and undo restores exactly the prior rows. Pinned by Task 12 tests.

---

## File Structure

Create:
- `lib/features/dive_roles/domain/services/dive_role_set.dart`: pure ordering, normalize, resolve, accumulate, union, toggle.
- `lib/core/database/dive_role_link_uniqueness.dart`: unique-index assert for both junctions.
- `lib/features/dive_roles/data/repositories/dive_role_link_repository.dart`: junction reads (resolved sets) and minimal-diff writes.
- `lib/features/dive_roles/presentation/dive_role_list_display.dart`: joined labels and id-to-role resolution for display.
- Tests mirroring each under `test/`.

Modify (by task): tables, migrations, database registration, sync serializer/service/repository, Dive and BuddyWithRole entities, dive and buddy repositories, role selector sheet, buddy picker, dive edit and detail pages, bulk edit request/snapshot/service/field set, merge builder/service/snapshot, consolidation, mirror service and field census, uncombine, split, buddy merge repository, UDDF writers/parsers/importer, payload slicer, participant names, detailed PDF and its plumbing, signatures, role-in-use guard, buddy list usual role, connections role subtitle, planned-dive fill fields.

---

### Task 1: `DiveRoleSet`, the pure role-set rules

**Files:**
- Create: `lib/features/dive_roles/domain/services/dive_role_set.dart`
- Test: `test/features/dive_roles/domain/services/dive_role_set_test.dart`

**Interfaces:**
- Produces:
  - `int DiveRoleSet.compare(String a, String b)`
  - `List<String> DiveRoleSet.normalize(Iterable<String> ids)` (dedupe, drop blanks, canonical order, Solo exclusivity)
  - `List<String> DiveRoleSet.normalizeBuddy(Iterable<String> ids)` (as normalize, empty becomes `['buddy']`)
  - `String? DiveRoleSet.primary(Iterable<String> ids)` (first of `normalize`, or null)
  - `List<String> DiveRoleSet.resolve({required String? scalar, required Iterable<String> junction})`
  - `List<String> DiveRoleSet.resolveBuddy({required String? scalar, required Iterable<String> junction})`
  - `List<String> DiveRoleSet.union(Iterable<Iterable<String>> sets)`
  - `List<String> DiveRoleSet.accumulate(Iterable<String> ids)` (importer rule: Buddy dropped when anything else is present; never empty)
  - `List<String> DiveRoleSet.toggle(Iterable<String> current, String id)` (picker rule)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';

void main() {
  const dm = DiveRole.diveMasterId;
  const guide = DiveRole.diveGuideId;
  const buddy = DiveRole.buddyId;
  const solo = DiveRole.soloId;
  const instructor = DiveRole.instructorId;

  group('normalize', () {
    test('orders built-ins by seed order, then custom ids ascending', () {
      expect(DiveRoleSet.normalize(['zz-custom', dm, 'aa-custom', guide]), [
        guide,
        dm,
        'aa-custom',
        'zz-custom',
      ]);
    });

    test('dedupes and drops blank ids', () {
      expect(DiveRoleSet.normalize([dm, '', dm]), [dm]);
    });

    test('drops Solo when it sits beside another role', () {
      expect(DiveRoleSet.normalize([solo, instructor]), [instructor]);
      expect(DiveRoleSet.normalize([solo]), [solo]);
    });

    test('a buddy set is never empty', () {
      expect(DiveRoleSet.normalizeBuddy(const []), [buddy]);
      expect(DiveRoleSet.normalizeBuddy([dm]), [dm]);
    });
  });

  test('primary is the first normalized id', () {
    expect(DiveRoleSet.primary([dm, guide]), guide);
    expect(DiveRoleSet.primary(const []), isNull);
  });

  group('resolve', () {
    test('no scalar means no roles, whatever the junction holds', () {
      expect(DiveRoleSet.resolve(scalar: null, junction: [dm]), isEmpty);
    });

    test('an empty junction falls back to the scalar', () {
      expect(DiveRoleSet.resolve(scalar: dm, junction: const []), [dm]);
    });

    test('a junction whose primary is the scalar is the set', () {
      expect(DiveRoleSet.resolve(scalar: guide, junction: [dm, guide]), [
        guide,
        dm,
      ]);
    });

    test('an older peer\'s scalar change wins over a stale junction', () {
      expect(DiveRoleSet.resolve(scalar: instructor, junction: [dm, guide]), [
        instructor,
      ]);
      // A member that is not the primary also marks the junction stale.
      expect(DiveRoleSet.resolve(scalar: dm, junction: [dm, guide]), [dm]);
    });

    test('a buddy always resolves to at least Buddy', () {
      expect(DiveRoleSet.resolveBuddy(scalar: null, junction: const []), [
        buddy,
      ]);
    });
  });

  test('union merges and Solo-normalizes', () {
    expect(
      DiveRoleSet.union([
        [solo],
        [dm],
      ]),
      [dm],
    );
    expect(
      DiveRoleSet.union([
        [guide],
        [dm, guide],
      ]),
      [guide, dm],
    );
  });

  test('accumulate drops Buddy when another role is present', () {
    expect(DiveRoleSet.accumulate([buddy, dm]), [dm]);
    expect(DiveRoleSet.accumulate([buddy]), [buddy]);
    expect(DiveRoleSet.accumulate(const []), [buddy]);
  });

  group('toggle', () {
    test('adds and removes an ordinary role', () {
      expect(DiveRoleSet.toggle([dm], guide), [guide, dm]);
      expect(DiveRoleSet.toggle([guide, dm], guide), [dm]);
    });

    test('ticking Solo clears everything else', () {
      expect(DiveRoleSet.toggle([dm, guide], solo), [solo]);
    });

    test('ticking another role clears Solo', () {
      expect(DiveRoleSet.toggle([solo], dm), [dm]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_roles/domain/services/dive_role_set_test.dart`
Expected: FAIL, `dive_role_set.dart` not found.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// The rules for a set of per-dive roles (issue #1221): one canonical order,
/// Solo exclusivity, the read rule that reconciles the junction tables with
/// the scalar primary-role columns older app versions still write, and the
/// merges the importers and the dive merge use.
///
/// Canonical order needs no database: built-in ids in [DiveRole.builtInIds]
/// order, then every other id ascending. Every device therefore agrees on a
/// set's primary role, which is what the scalar columns hold.
abstract final class DiveRoleSet {
  static int _rank(String id) {
    final index = DiveRole.builtInIds.indexOf(id);
    return index < 0 ? DiveRole.builtInIds.length : index;
  }

  static int compare(String a, String b) {
    final byRank = _rank(a).compareTo(_rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  }

  /// [ids] deduped, blanks dropped, in canonical order, with Solo dropped
  /// when it sits beside any other role.
  static List<String> normalize(Iterable<String> ids) {
    final sorted = ids.where((id) => id.isNotEmpty).toSet().toList()
      ..sort(compare);
    if (sorted.length > 1 && sorted.contains(DiveRole.soloId)) {
      return List.unmodifiable([
        for (final id in sorted)
          if (id != DiveRole.soloId) id,
      ]);
    }
    return List.unmodifiable(sorted);
  }

  /// [normalize] for a buddy link, which always carries a role.
  static List<String> normalizeBuddy(Iterable<String> ids) {
    final normalized = normalize(ids);
    return normalized.isEmpty ? const [DiveRole.buddyId] : normalized;
  }

  /// The primary role of [ids]: what the scalar column holds.
  static String? primary(Iterable<String> ids) {
    final normalized = normalize(ids);
    return normalized.isEmpty ? null : normalized.first;
  }

  /// The roles a person holds, from the scalar column and the junction rows.
  ///
  /// The junction is current only when its own primary role is [scalar]:
  /// every write keeps the two in step, so any other combination means an
  /// older app version changed the scalar after the junction was written,
  /// and the scalar is the newer truth. A null scalar means no role.
  static List<String> resolve({
    required String? scalar,
    required Iterable<String> junction,
  }) {
    if (scalar == null || scalar.isEmpty) return const [];
    final set = normalize(junction);
    if (set.isNotEmpty && set.first == scalar) return set;
    return List.unmodifiable([scalar]);
  }

  /// [resolve] for a buddy link, never empty.
  static List<String> resolveBuddy({
    required String? scalar,
    required Iterable<String> junction,
  }) {
    final resolved = resolve(scalar: scalar, junction: junction);
    return resolved.isEmpty ? const [DiveRole.buddyId] : resolved;
  }

  /// Every role of every set in [sets], normalized.
  static List<String> union(Iterable<Iterable<String>> sets) =>
      normalize(sets.expand((s) => s));

  /// The importer rule: roles inferred from separate fields of a file are
  /// added up, and the generic Buddy role stays only when nothing more
  /// specific was found.
  static List<String> accumulate(Iterable<String> ids) {
    final normalized = normalize(ids);
    if (normalized.isEmpty) return const [DiveRole.buddyId];
    if (normalized.length > 1 && normalized.contains(DiveRole.buddyId)) {
      return List.unmodifiable([
        for (final id in normalized)
          if (id != DiveRole.buddyId) id,
      ]);
    }
    return normalized;
  }

  /// The picker rule: [id] flips in [current]; ticking Solo clears every
  /// other role and ticking anything else clears Solo.
  static List<String> toggle(Iterable<String> current, String id) {
    final set = current.toSet();
    if (set.contains(id)) {
      set.remove(id);
    } else if (id == DiveRole.soloId) {
      set
        ..clear()
        ..add(id);
    } else {
      set
        ..remove(DiveRole.soloId)
        ..add(id);
    }
    return normalize(set);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_roles/domain/services/dive_role_set_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format lib/features/dive_roles test/features/dive_roles
flutter analyze
flutter test test/architecture/
git add lib/features/dive_roles/domain/services/dive_role_set.dart test/features/dive_roles/domain/services/dive_role_set_test.dart
git commit -m "feat(dive-roles): add the role set rules for multiple roles per person"
```

---

### Task 2: Schema v262, the two junction tables

**Files:**
- Modify: `lib/core/database/tables/buddy_tables.dart` (append two tables)
- Create: `lib/core/database/dive_role_link_uniqueness.dart`
- Modify: `lib/core/database/migrations/helpers/buddy_migrations.dart` (add `_assertDiveRoleLinkSchema`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (v262 rung)
- Modify: `lib/core/database/migrations/before_open.dart` (backstop line)
- Modify: `lib/core/database/migrations/migration_strategy.dart` (onCreate index assert)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (import)
- Modify: `lib/core/database/migrations/helpers/sync_migrations.dart` (child hlc list)
- Modify: `lib/core/database/database.dart` (register tables, version 262, `migrationVersions`)
- Test: `test/core/database/migration_v262_dive_role_links_test.dart`

**Interfaces:**
- Produces: Drift tables `DiveDiverRoles` (row class `DiveDiverRole`, companion `DiveDiverRolesCompanion`, accessor `db.diveDiverRoles`) and `DiveBuddyRoles` (row class `DiveBuddyRole`, `DiveBuddyRolesCompanion`, `db.diveBuddyRoles`); `assertDiveRoleLinkUniqueness(DatabaseConnectionUser db)`; index names `kDiveDiverRolesUniqueIndexName`, `kDiveBuddyRolesUniqueIndexName`.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_role_link_uniqueness.dart';

void main() {
  /// A v261 database: the parents exist, the two junctions do not.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 261');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE buddies (id TEXT PRIMARY KEY)');
      rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO buddies (id) VALUES ('b1')");
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v262 is the current schema and in the ladder; floor unchanged', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(262));
    expect(AppDatabase.migrationVersions, contains(262));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('creates both junctions with their columns', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_diver_roles'), {
      'id',
      'dive_id',
      'role_id',
      'created_at',
      'hlc',
    });
    expect(await columnsOf(db, 'dive_buddy_roles'), {
      'id',
      'dive_id',
      'buddy_id',
      'role_id',
      'created_at',
      'hlc',
    });
  });

  test('the natural keys are unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) "
      "VALUES ('r1', 'd1', 'diveMaster', 0)",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) "
        "VALUES ('r2', 'd1', 'diveMaster', 0)",
      ),
      throwsA(anything),
    );
    await db.customStatement(
      "INSERT INTO dive_buddy_roles "
      "(id, dive_id, buddy_id, role_id, created_at) "
      "VALUES ('x1', 'd1', 'b1', 'diveGuide', 0)",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO dive_buddy_roles "
        "(id, dive_id, buddy_id, role_id, created_at) "
        "VALUES ('x2', 'd1', 'b1', 'diveGuide', 0)",
      ),
      throwsA(anything),
    );
  });

  test('the uniqueness assert is idempotent', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await assertDiveRoleLinkUniqueness(db);
    await assertDiveRoleLinkUniqueness(db);
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
          "('$kDiveDiverRolesUniqueIndexName', "
          "'$kDiveBuddyRolesUniqueIndexName')",
        )
        .get();
    expect(rows, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v262_dive_role_links_test.dart`
Expected: FAIL (`dive_role_link_uniqueness.dart` missing).

- [ ] **Step 3: Add the tables** to the end of `lib/core/database/tables/buddy_tables.dart`:

```dart
/// The diver's own roles on a dive (v262, issue #1221). `dives.diver_role`
/// stays as the primary role for older app versions (see DiveRoleSet).
/// Surrogate uuid key, as [DiveDiveTypes]; `roleId` has no foreign key
/// because a custom role can arrive by sync after a row naming it.
@DataClassName('DiveDiverRole')
class DiveDiverRoles extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get roleId => text()();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Each buddy's roles on a dive (v262, issue #1221). Keyed on the
/// (dive, buddy) pair rather than on `dive_buddies.id`: older app versions
/// save a dive's buddies by deleting and re-inserting every `dive_buddies`
/// row under fresh ids, which would orphan rows hung off the row id.
/// `dive_buddies.role` stays as the primary role.
@DataClassName('DiveBuddyRole')
class DiveBuddyRoles extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
      text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get roleId => text()();
  IntColumn get createdAt => integer()();

  /// This child's own clock (see [DiveDiverRoles.hlc]).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

If `Dives` is not imported in `buddy_tables.dart`, add the import of the file that declares it (check the existing imports at the top of the file; `DiveBuddies` already references `Dives`, so it is in scope).

- [ ] **Step 4: Create `lib/core/database/dive_role_link_uniqueness.dart`**

```dart
/// Role junction identity (v262, issue #1221): one `dive_diver_roles` row per
/// (dive, role) and one `dive_buddy_roles` row per (dive, buddy, role).
///
/// Both tables carry their unique index from the day they exist, like
/// `site_site_types` (v217), so the collapse below only ever runs against a
/// database whose index was lost (a restore of a partially migrated file).
/// It keeps the oldest row of each key, `id` breaking ties, so every device
/// lands on the same survivor. With the index in place an unguarded
/// duplicate insert THROWS, so every writer must use `DoNothing` or check
/// first.
library;

import 'package:drift/drift.dart';

const String kDiveDiverRolesUniqueIndexName =
    'idx_dive_diver_roles_dive_role_unique';

const String kDiveBuddyRolesUniqueIndexName =
    'idx_dive_buddy_roles_dive_buddy_role_unique';

const _specs = [
  (
    table: 'dive_diver_roles',
    key: 'dive_id, role_id',
    index: kDiveDiverRolesUniqueIndexName,
  ),
  (
    table: 'dive_buddy_roles',
    key: 'dive_id, buddy_id, role_id',
    index: kDiveBuddyRolesUniqueIndexName,
  ),
];

Future<bool> _exists(
  DatabaseConnectionUser db,
  String type,
  String name,
) async {
  final rows = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
        variables: [Variable<String>(type), Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Asserts both unique indexes, collapsing duplicates first so creating an
/// index cannot abort. Self-guarding on the tables existing, so partial
/// migration-test fixtures pass through. Called from `onCreate`, the v262
/// rung and `beforeOpen`.
Future<void> assertDiveRoleLinkUniqueness(DatabaseConnectionUser db) async {
  for (final spec in _specs) {
    if (!await _exists(db, 'table', spec.table)) continue;
    if (await _exists(db, 'index', spec.index)) continue;
    await db.customStatement('''
      DELETE FROM ${spec.table} WHERE rowid IN (
        SELECT rowid FROM (
          SELECT rowid, ROW_NUMBER() OVER (
            PARTITION BY ${spec.key} ORDER BY created_at ASC, id ASC
          ) AS rn FROM ${spec.table}
        ) WHERE rn > 1
      )
    ''');
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ${spec.index} '
      'ON ${spec.table}(${spec.key})',
    );
  }
}
```

- [ ] **Step 5: Add the migration helper** to `BuddyMigrations` in `lib/core/database/migrations/helpers/buddy_migrations.dart`:

```dart
  /// v262: the role junctions (issue #1221). Table-only, no backfill: an
  /// existing dive resolves to its scalar role (DiveRoleSet.resolve), so
  /// no row is minted per device. Idempotent; called from the v262 rung and
  /// the beforeOpen backstop. Skipped on a partial fixture without parents.
  Future<void> _assertDiveRoleLinkSchema() async {
    for (final parent in const ['dives', 'buddies']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(diveDiverRoles);
    await Migrator(this).createTable(diveBuddyRoles);
    await assertDiveRoleLinkUniqueness(this);
  }
```

(`_tableExists` is the helper `_assertTripHidesSchema` uses; `createTable` on an existing table throws, so guard each: use the same `Migrator.createTable` call `_assertTripHidesSchema` makes. If `createTable` is not idempotent there, wrap each in `if (!await _tableExists('dive_diver_roles'))` and likewise for `dive_buddy_roles`.)

- [ ] **Step 6: Wire the rung, backstop, onCreate and child hlc list**

`rungs_v231_onward.dart`, after the v260 block:

```dart
    // v262: the role junctions (issue #1221), several roles per person on a
    // dive. Table-only rung, no backfill; re-asserted in beforeOpen. 261 is
    // held by #2985.
    if (from < 262) {
      await _assertDiveRoleLinkSchema();
    }
    if (from < 262) await reportProgress();
```

`before_open.dart`, next to the v250 backstop lines:

```dart
    // v262 backstop: the role junctions and their unique indexes.
    await _assertDiveRoleLinkSchema();
```

`migration_strategy.dart` onCreate, after `assertEquipmentShareUniqueness(this);`:

```dart
    // Role junction unique indexes (v262, issue #1221), for the same
    // reason: createAll() never builds raw-SQL indexes.
    await assertDiveRoleLinkUniqueness(this);
```

`app_database_migrations.dart`: add `import 'package:submersion/core/database/dive_role_link_uniqueness.dart';` in the import block (alphabetical).

`sync_migrations.dart` `_assertChildHlcColumns` list: append `'dive_diver_roles',` and `'dive_buddy_roles',` (harmless on fresh tables, keeps the list the census of hlc children).

`database.dart`: add `DiveDiverRoles, DiveBuddyRoles,` to the `@DriftDatabase(tables: [...])` list right after `DiveRoles,`; set `currentSchemaVersion = 262`; add `262` to `migrationVersions` (find the list with `grep -n "migrationVersions" lib/core/database/database.dart` and append).

- [ ] **Step 7: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` contains `class DiveDiverRole` and `class DiveBuddyRole`.

- [ ] **Step 8: Run the migration test and the existing ladder tests**

Run: `flutter test test/core/database/migration_v262_dive_role_links_test.dart test/core/database/`
Expected: PASS. If a test pins `currentSchemaVersion == 260` exactly (the newest-rung test), relax it to `greaterThanOrEqualTo(260)` as v217's test did.

- [ ] **Step 9: Format, analyze, architecture, commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/core/database test/core/database/migration_v262_dive_role_links_test.dart
git commit -m "feat(dive-roles): add the dive_diver_roles and dive_buddy_roles tables (v262)"
```

---

### Task 3: Sync the two junctions

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every arm `siteSiteTypes` has)
- Modify: `lib/core/services/sync/sync_service.dart` (records list, `hasUpdatedAt` map, parent refs)
- Modify: `lib/core/data/repositories/sync_repository.dart` (entity to table/pk map)
- Test: `test/core/services/sync/dive_role_links_sync_test.dart`; the existing completeness tests (`sync_parent_refs_completeness_test.dart`, `sync_data_serializer_batch_coverage_test.dart`, `sync_serializer_fetch_record_test.dart`) must stay green.

**Interfaces:**
- Consumes: Task 2 tables.
- Produces: sync entity types `'diveDiverRoles'` and `'diveBuddyRoles'` (used by every `markRecordPending` / `logDeletion` call from Task 5 on).

- [ ] **Step 1: Write the failing sync test**

Model it on `test/core/services/sync/site_classification_sync_test.dart` (read it first for the harness: how it builds a `SyncDataSerializer`, exports and applies). The test file must cover:

```dart
// 1. export: a dive whose hlc is newer than hlcSince exports its
//    dive_diver_roles and dive_buddy_roles rows under the keys
//    'diveDiverRoles' and 'diveBuddyRoles'.
// 2. apply: upsertRecord('diveDiverRoles', json) inserts the row; applying a
//    second row for the same (dive, role) under a LOWER id leaves exactly one
//    row whose id is the lower one; under a HIGHER id leaves the local row.
// 3. the same pair of checks for 'diveBuddyRoles' keyed on
//    (dive, buddy, role).
// 4. batch apply (upsertRecords) of two rows for the same key in one payload
//    keeps one row, the lower id.
// 5. deleteRecord('diveBuddyRoles', id) removes the row.
```

Write each as a `test(...)` with concrete ids (`'r-a'` < `'r-b'`), inserting parents with `customStatement` as `site_classification_sync_test.dart` does.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/dive_role_links_sync_test.dart`
Expected: FAIL (unknown entity type).

- [ ] **Step 3: Register in the serializer.** In `sync_data_serializer.dart`, at each location where `siteSiteTypes` appears, add the two entities next to it:

1. `SyncData` fields: `final List<Map<String, dynamic>> diveDiverRoles; final List<Map<String, dynamic>> diveBuddyRoles;`
2. constructor defaults `this.diveDiverRoles = const [], this.diveBuddyRoles = const [],`
3. `toJson`: `'diveDiverRoles': diveDiverRoles, 'diveBuddyRoles': diveBuddyRoles,`
4. `fromJson`: `diveDiverRoles: _parseList(json['diveDiverRoles']), diveBuddyRoles: _parseList(json['diveBuddyRoles']),`
5. table registry list near line 1190: `(key: 'diveDiverRoles', table: _db.diveDiverRoles, blob: false, full: null), (key: 'diveBuddyRoles', table: _db.diveBuddyRoles, blob: false, full: null),`
6. `parentGatedChildEntities` set: add `'diveDiverRoles', 'diveBuddyRoles',` after `'diveDiveTypes',`.
7. entity to table name map near line 1830: `'diveDiverRoles': 'dive_diver_roles', 'diveBuddyRoles': 'dive_buddy_roles',`
8. export block near line 2215 (next to `diveDiveTypes`):

```dart
      diveDiverRoles: await _safeExport(
        'diveDiverRoles',
        () async => _withPendingChildren(
          'diveDiverRoles',
          await _exportDiveChildRows(_db.diveDiverRoles, hlcSince),
          pendingChildren,
        ),
      ),
      diveBuddyRoles: await _safeExport(
        'diveBuddyRoles',
        () async => _withPendingChildren(
          'diveBuddyRoles',
          await _exportDiveChildRows(_db.diveBuddyRoles, hlcSince),
          pendingChildren,
        ),
      ),
```

and add the generic helper beside `_exportDiveDiveTypes` (copy that method's body, replacing the table):

```dart
  /// Rows of a dive child table, gated on the parent dive's clock like
  /// [_exportDiveDiveTypes].
  Future<List<Map<String, dynamic>>> _exportDiveChildRows<T extends Table, R>(
    TableInfo<T, R> table,
    String? hlcSince,
  ) async {
    final diveIdColumn = table.columnsByName['dive_id']! as GeneratedColumn<String>;
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];
      return _childRowsOf(
        diveIds,
        (chunk) => (_db.select(table)..where((_) => diveIdColumn.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(table).get();
    return rows.map((r) => (r as DataClass).toJson()).toList();
  }
```

(If `_childRowsOf`'s signature does not accept this generic row type, write two concrete methods `_exportDiveDiverRoles` and `_exportDiveBuddyRoles` by copying `_exportDiveDiveTypes` verbatim and swapping the table; prefer that over fighting generics.)

9. `fetchRecord` switch near line 2933: `case 'diveDiverRoles':` and `case 'diveBuddyRoles':` selecting by `id`, returning `row?.toJson()`.
10. single apply (`upsertRecord`) near line 4540:

```dart
      case 'diveDiverRoles':
        await _applyDiveDiverRoleRecord(DiveDiverRole.fromJson(data));
        return;
      case 'diveBuddyRoles':
        await _applyDiveBuddyRoleRecord(DiveBuddyRole.fromJson(data));
        return;
```

with the two appliers beside `_applySiteSiteTypeRecord`:

```dart
  /// Applies one incoming `dive_diver_roles` row (v262, issue #1221): the
  /// (dive, role) key is unique, so a peer's copy under another id is
  /// reconciled to the lower id and then skipped with DO NOTHING, for the
  /// reasons [_applyDiveDiveTypeRecord] gives.
  Future<void> _applyDiveDiverRoleRecord(DiveDiverRole record) async {
    await _reconcileJunctionIds(
      'dive_diver_roles',
      parentColumn: 'dive_id',
      childColumn: 'role_id',
      pairs: [(parent: record.diveId, child: record.roleId, id: record.id)],
    );
    await _db
        .into(_db.diveDiverRoles)
        .insert(
          record,
          onConflict: DoNothing<$DiveDiverRolesTable, DiveDiverRole>(
            target: const [],
          ),
        );
  }

  /// Applies one incoming `dive_buddy_roles` row (v262). Its key is a
  /// triple, so it reconciles through [_reconcileBuddyRoleIds].
  Future<void> _applyDiveBuddyRoleRecord(DiveBuddyRole record) async {
    await _reconcileBuddyRoleIds([record]);
    await _db
        .into(_db.diveBuddyRoles)
        .insert(
          record,
          onConflict: DoNothing<$DiveBuddyRolesTable, DiveBuddyRole>(
            target: const [],
          ),
        );
  }

  /// [_reconcileJunctionIds] for the (dive, buddy, role) key of
  /// `dive_buddy_roles`: this device's row goes whenever the incoming id
  /// sorts below it.
  Future<void> _reconcileBuddyRoleIds(List<DiveBuddyRole> rows) async {
    if (rows.isEmpty) return;
    await _db.batch((batch) {
      for (final row in rows) {
        batch.customStatement(
          'DELETE FROM dive_buddy_roles WHERE dive_id = ? AND buddy_id = ? '
          'AND role_id = ? AND id > ?',
          [row.diveId, row.buddyId, row.roleId, row.id],
        );
      }
    });
  }
```

11. batch apply (`upsertRecords`) near line 5650:

```dart
      case 'diveDiverRoles':
        final diverRoleRows = _lowestIdPerPair(
          records.map((r) => DiveDiverRole.fromJson(r)).toList(),
          (row) => (parent: row.diveId, child: row.roleId, id: row.id),
        );
        await _reconcileJunctionIds(
          'dive_diver_roles',
          parentColumn: 'dive_id',
          childColumn: 'role_id',
          pairs: [
            for (final row in diverRoleRows)
              (parent: row.diveId, child: row.roleId, id: row.id),
          ],
        );
        await _db.batch(
          (b) => b.insertAll(
            _db.diveDiverRoles,
            diverRoleRows,
            onConflict: DoNothing<$DiveDiverRolesTable, DiveDiverRole>(
              target: const [],
            ),
          ),
        );
        return;
      case 'diveBuddyRoles':
        // The pair key folds (dive, buddy) into one string; it only keys the
        // in-memory dedupe, never SQL.
        final buddyRoleRows = _lowestIdPerPair(
          records.map((r) => DiveBuddyRole.fromJson(r)).toList(),
          (row) => (
            parent: '${row.diveId}|${row.buddyId}',
            child: row.roleId,
            id: row.id,
          ),
        );
        await _reconcileBuddyRoleIds(buddyRoleRows);
        await _db.batch(
          (b) => b.insertAll(
            _db.diveBuddyRoles,
            buddyRoleRows,
            onConflict: DoNothing<$DiveBuddyRolesTable, DiveBuddyRole>(
              target: const [],
            ),
          ),
        );
        return;
```

12. the `plain(...)` switch near line 6337: `case 'diveDiverRoles': return plain(_db.diveDiverRoles, _db.diveDiverRoles.id);` and the same for `diveBuddyRoles`.
13. the table-by-entity switch near line 6745: `case 'diveDiverRoles': return _db.diveDiverRoles;` and `diveBuddyRoles`.
14. `deleteRecord` switch near line 7215: delete by id from each table.

- [ ] **Step 4: Register in sync_service and sync_repository**

`sync_service.dart` near line 1584 (records list), add after the `diveDiveTypes` entry:

```dart
          (
            type: 'diveDiverRoles',
            records: data.diveDiverRoles,
            hasUpdatedAt: false,
          ),
          (
            type: 'diveBuddyRoles',
            records: data.diveBuddyRoles,
            hasUpdatedAt: false,
          ),
```

(match the exact record shape the `diveDiveTypes` entry uses). Near line 2580 add `'diveDiverRoles': false, 'diveBuddyRoles': false,`. Parent refs near line 2772:

```dart
    'diveDiverRoles': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveBuddyRoles': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'buddyId', parent: 'buddies', nullable: false),
    ],
```

`sync_repository.dart` near line 152: `'diveDiverRoles': (table: 'dive_diver_roles', pk: 'id'), 'diveBuddyRoles': (table: 'dive_buddy_roles', pk: 'id'),`

- [ ] **Step 5: Run the new and existing sync tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS. The completeness tests enumerate tables and entity maps; if one fails naming the new tables, add them to whatever list it names (that is its job).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core test/core/services/sync/dive_role_links_sync_test.dart
git commit -m "feat(sync): sync the dive role junctions"
```

---

### Task 4: Switch the entities to role lists (no behaviour change)

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`diverRoleId` becomes `diverRoleIds`)
- Modify: `lib/features/buddies/domain/entities/buddy.dart` (`BuddyWithRole.role` becomes `roles`)
- Modify: every compile site in `lib/` and `test/` (the analyzer lists them)
- Modify: `lib/features/dive_log/domain/services/dive_mirror_fields.dart`, `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart` (field-name censuses)

**Interfaces:**
- Produces:
  - `Dive.diverRoleIds: List<String>` (default `const []`), `copyWith({List<String>? diverRoleIds})`, in `props`.
  - `BuddyWithRole({required Buddy buddy, required List<DiveRole> roles})` (non-const, asserts non-empty), `DiveRole get primaryRole`, `List<String> get roleIds`; `props => [buddy, roles]`.

This task changes types only. Every site keeps today's behaviour: where code read one role it now reads `primaryRole` / `diverRoleIds.firstOrNull`, and where it built one it builds a one-element list. Later tasks give each site its multi-role behaviour.

- [ ] **Step 1: Change `BuddyWithRole`** in `buddy.dart`:

```dart
class BuddyWithRole extends Equatable {
  final Buddy buddy;

  /// Every role this person holds on the dive, in DiveRoleSet order; never
  /// empty. The first is the primary role `dive_buddies.role` holds.
  final List<DiveRole> roles;

  BuddyWithRole({required this.buddy, required this.roles})
    : assert(roles.isNotEmpty, 'a buddy link always carries a role');

  DiveRole get primaryRole => roles.first;

  List<String> get roleIds => [for (final r in roles) r.id];

  @override
  List<Object?> get props => [buddy, roles];
}
```

- [ ] **Step 2: Change `Dive`.** Replace the field `final String? diverRoleId;` (line ~90) with:

```dart
  /// The active diver's own roles on this dive, in DiveRoleSet order (issue
  /// #1221); empty when none. The first is the primary role
  /// `dives.diver_role` holds for older app versions.
  final List<String> diverRoleIds;
```

constructor `this.diverRoleIds = const [],` (replacing `this.diverRoleId,`), copyWith parameter `List<String>? diverRoleIds,` and body `diverRoleIds: diverRoleIds ?? this.diverRoleIds,`, and `diverRoleIds` in `props` (replacing `diverRoleId`). Note the old copyWith could not clear the role; a list can be cleared with `diverRoleIds: const []`.

- [ ] **Step 3: Update the censuses.** In `dive_mirror_fields.dart` replace `'diverRoleId'` with `'diverRoleIds'` in `kMirroredDiveFields`, rename the `mirroredDiveFrom` parameter to `required List<String> diverRoleIds` and pass `diverRoleIds: diverRoleIds`. In `planned_dive_fill_fields.dart` replace `'diverRoleId'` with `'diverRoleIds'`.

- [ ] **Step 4: Fix every compile error preserving behaviour.**

Run: `flutter analyze 2>&1 | grep error | head -80`

Apply these mechanical rules at each site the analyzer reports:
- `BuddyWithRole(buddy: X, role: Y)` becomes `BuddyWithRole(buddy: X, roles: [Y])`.
- reading `bwr.role` becomes `bwr.primaryRole` (later tasks replace these with set-aware code).
- `dive.diverRoleId` (read) becomes `dive.diverRoleIds.firstOrNull` (the repo already uses `firstOrNull`, e.g. in `dive_mirror_service.dart`; if the analyzer reports it undefined in a file, add the same import that file uses).
- `diverRoleId: x` in a `Dive(...)` or `copyWith(...)` becomes `diverRoleIds: [?x]` (null-aware element, already used in `uddf_export_service.dart`).
- `diverRoleId: row.diverRole` in the two dive repository mappers becomes `diverRoleIds: [?row.diverRole]`.
- `diverRole: Value(dive.diverRoleId)` in create/update becomes `diverRole: Value(dive.diverRoleIds.firstOrNull)`.
- `copyWith(diverRoleId: ...)` in the merge builder becomes `diverRoleIds: [?_firstNonNull(sorted, (d) => d.diverRoleIds.firstOrNull)]` (Task 12 replaces it with a union).
- In `dive_edit_page.dart` keep `String? _diverRoleId` for now; convert at the boundary (`diverRoleIds: [?_diverRoleId]`, `_diverRoleId = dive.diverRoleIds.firstOrNull`). Task 10 converts the page state.
- `const BuddyWithRole(` anywhere becomes `BuddyWithRole(`.

Then fix tests the same way: `grep -rln "BuddyWithRole(\|diverRoleId" test` and apply the same rules; in `test/helpers/dive_participants.dart` make `linkedParticipant` build `roles: [DiveRole.synthetic(roleId)]`.

- [ ] **Step 5: Regenerate if needed and run the affected suites**

Run: `flutter analyze` (zero issues), then
`flutter test test/features/buddies test/features/dive_log test/features/dive_roles test/core/services/export test/features/signatures test/features/dive_import test/features/universal_import test/features/dive_computer test/features/connections test/features/insights`
Expected: PASS, the same results as before the change (this task changes no behaviour).

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A lib test
git status --short   # confirm only intended files
git commit -m "refactor(dive-roles): carry role lists on Dive and BuddyWithRole"
```

---

### Task 5: `DiveRoleLinkRepository`, the junction reads and writes

**Files:**
- Create: `lib/features/dive_roles/data/repositories/dive_role_link_repository.dart`
- Test: `test/features/dive_roles/data/repositories/dive_role_link_repository_test.dart`

**Interfaces:**
- Consumes: `DiveRoleSet` (Task 1), tables and sync entities (Tasks 2 and 3).
- Produces (all on `DiveRoleLinkRepository()`, which reads `DatabaseService.instance.database` like `BuddyRepository`):
  - `Future<Map<String, List<String>>> diverRoleIdsForDives(List<String> diveIds)`: resolved sets; a dive with no role maps to `[]`.
  - `Future<Map<String, Map<String, List<String>>>> buddyRoleIdsForDives(List<String> diveIds)`: `diveId -> buddyId -> resolved set` for every `dive_buddies` row.
  - `Future<List<DiveDiverRole>> diverRoleRowsForDives(List<String> diveIds)` and `Future<List<DiveBuddyRole>> buddyRoleRowsForDives(List<String> diveIds)`: raw rows for snapshots.
  - `Future<void> writeDiverRoles(String diveId, Iterable<String> roleIds, {int? now})`: normalize, set `dives.diver_role` to the primary (marking the dive pending only if it changed), minimal-diff the junction.
  - `Future<void> writeBuddyRoles(String diveId, String buddyId, Iterable<String> roleIds, {int? now})`: `normalizeBuddy`, set `dive_buddies.role` for the pair (marking that row pending only if it changed), minimal-diff the junction.
  - `Future<void> deleteBuddyRoles(String diveId, Iterable<String> buddyIds)`: delete and tombstone.
  - `Future<void> restoreRows({required List<String> diveIds, required List<DiveDiverRole> diverRows, required List<DiveBuddyRole> buddyRows})`: make the junction rows of `diveIds` exactly the given rows (tombstone extras, insertOrReplace the rest, mark pending). Used by undo paths.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRoleLinkRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRoleLinkRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
      "VALUES ('d1', 0, 0, 0), ('d2', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO buddies (id, name, created_at, updated_at) "
      "VALUES ('b1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) "
      "VALUES ('l1', 'd1', 'b1', 'buddy', 0)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<int> count(String sql) async => (await DatabaseService
          .instance
          .database
          .customSelect(sql)
          .getSingle())
      .read<int>('n');

  test('writeDiverRoles stores the set and the primary scalar', () async {
    await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
    expect(await repo.diverRoleIdsForDives(['d1', 'd2']), {
      'd1': ['diveGuide', 'diveMaster'],
      'd2': <String>[],
    });
    final row = await DatabaseService.instance.database
        .customSelect("SELECT diver_role FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.read<String?>('diver_role'), 'diveGuide');
  });

  test('a legacy dive reads its scalar role', () async {
    await DatabaseService.instance.database.customStatement(
      "UPDATE dives SET diver_role = 'instructor' WHERE id = 'd2'",
    );
    expect((await repo.diverRoleIdsForDives(['d2']))['d2'], ['instructor']);
  });

  test("an older peer's scalar change wins", () async {
    await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
    await DatabaseService.instance.database.customStatement(
      "UPDATE dives SET diver_role = 'student' WHERE id = 'd1'",
    );
    expect((await repo.diverRoleIdsForDives(['d1']))['d1'], ['student']);
  });

  test('a rewrite keeps unchanged rows and tombstones removed ones', () async {
    await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
    final db = DatabaseService.instance.database;
    final before = await db.select(db.diveDiverRoles).get();
    final dmId = before.firstWhere((r) => r.roleId == 'diveMaster').id;

    await repo.writeDiverRoles('d1', ['diveMaster', 'instructor']);

    final after = await db.select(db.diveDiverRoles).get();
    expect(after.map((r) => r.roleId).toSet(), {'diveMaster', 'instructor'});
    expect(after.firstWhere((r) => r.roleId == 'diveMaster').id, dmId);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'diveDiverRoles'",
      ),
      1,
    );
  });

  test('Solo beside another role is dropped on write', () async {
    await repo.writeDiverRoles('d1', ['solo', 'instructor']);
    expect((await repo.diverRoleIdsForDives(['d1']))['d1'], ['instructor']);
  });

  test('an empty diver set clears the scalar and the rows', () async {
    await repo.writeDiverRoles('d1', ['diveMaster']);
    await repo.writeDiverRoles('d1', const []);
    expect((await repo.diverRoleIdsForDives(['d1']))['d1'], isEmpty);
    expect(await count('SELECT COUNT(*) AS n FROM dive_diver_roles'), 0);
  });

  test('writeBuddyRoles sets the pair scalar and the set', () async {
    await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
    expect(await repo.buddyRoleIdsForDives(['d1']), {
      'd1': {
        'b1': ['diveGuide', 'diveMaster'],
      },
    });
    final row = await DatabaseService.instance.database
        .customSelect("SELECT role FROM dive_buddies WHERE id = 'l1'")
        .getSingle();
    expect(row.read<String>('role'), 'diveGuide');
  });

  test('an empty buddy set becomes Buddy', () async {
    await repo.writeBuddyRoles('d1', 'b1', const []);
    expect((await repo.buddyRoleIdsForDives(['d1']))['d1'], {
      'b1': ['buddy'],
    });
  });

  test('deleteBuddyRoles removes and tombstones the rows', () async {
    await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
    await repo.deleteBuddyRoles('d1', ['b1']);
    expect(await count('SELECT COUNT(*) AS n FROM dive_buddy_roles'), 0);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'diveBuddyRoles'",
      ),
      2,
    );
  });

  test('restoreRows puts back exactly the captured rows', () async {
    await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
    final captured = await repo.diverRoleRowsForDives(['d1']);
    await repo.writeDiverRoles('d1', ['instructor']);

    await repo.restoreRows(
      diveIds: ['d1'],
      diverRows: captured,
      buddyRows: const [],
    );

    final db = DatabaseService.instance.database;
    final rows = await db.select(db.diveDiverRoles).get();
    expect(rows.map((r) => r.id).toSet(), captured.map((r) => r.id).toSet());
  });
}
```

(If `dives` requires more NOT NULL columns than the insert gives, copy the minimal dive insert from an existing repository test such as `test/features/buddies/data/repositories/buddy_repository_bulk_test.dart`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_roles/data/repositories/dive_role_link_repository_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';

/// Reads and writes the role junctions (issue #1221): `dive_diver_roles`
/// and `dive_buddy_roles`, kept in step with the scalar primary-role columns
/// `dives.diver_role` and `dive_buddies.role` that older app versions read.
///
/// Every read goes through [DiveRoleSet.resolve], so a scalar an older
/// version changed after the junction was written wins. Writes are minimal
/// diffs: unchanged rows keep their ids and clocks, removed rows are
/// tombstoned, new rows are marked pending. No method notifies or opens a
/// transaction; the caller owns both, as the bulk repository methods do.
class DiveRoleLinkRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<DiveDiverRole>> diverRoleRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(
      _db.diveDiverRoles,
    )..where((t) => t.diveId.isIn(diveIds))).get();
  }

  Future<List<DiveBuddyRole>> buddyRoleRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.isIn(diveIds))).get();
  }

  Future<Map<String, List<String>>> diverRoleIdsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final dives = await (_db.selectOnly(_db.dives)
          ..addColumns([_db.dives.id, _db.dives.diverRole])
          ..where(_db.dives.id.isIn(diveIds)))
        .get();
    final junction = <String, List<String>>{};
    for (final row in await diverRoleRowsForDives(diveIds)) {
      junction.putIfAbsent(row.diveId, () => []).add(row.roleId);
    }
    return {
      for (final d in dives)
        d.read(_db.dives.id)!: DiveRoleSet.resolve(
          scalar: d.read(_db.dives.diverRole),
          junction: junction[d.read(_db.dives.id)!] ?? const [],
        ),
    };
  }

  Future<Map<String, Map<String, List<String>>>> buddyRoleIdsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final links = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    final junction = <(String, String), List<String>>{};
    for (final row in await buddyRoleRowsForDives(diveIds)) {
      junction.putIfAbsent((row.diveId, row.buddyId), () => []).add(row.roleId);
    }
    final result = <String, Map<String, List<String>>>{};
    for (final link in links) {
      result.putIfAbsent(link.diveId, () => {})[link.buddyId] =
          DiveRoleSet.resolveBuddy(
            scalar: link.role,
            junction: junction[(link.diveId, link.buddyId)] ?? const [],
          );
    }
    return result;
  }

  Future<void> writeDiverRoles(
    String diveId,
    Iterable<String> roleIds, {
    int? now,
  }) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final wanted = DiveRoleSet.normalize(roleIds);
    final primary = wanted.isEmpty ? null : wanted.first;
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return;
    if (dive.diverRole != primary) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(diverRole: Value(primary), updatedAt: Value(at)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: at,
      );
    }
    final existing = await (_db.select(
      _db.diveDiverRoles,
    )..where((t) => t.diveId.equals(diveId))).get();
    for (final row in existing) {
      if (wanted.contains(row.roleId)) continue;
      await (_db.delete(
        _db.diveDiverRoles,
      )..where((t) => t.id.equals(row.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveDiverRoles',
        recordId: row.id,
      );
    }
    final have = {for (final r in existing) r.roleId};
    for (final roleId in wanted) {
      if (have.contains(roleId)) continue;
      final id = _uuid.v4();
      await _db
          .into(_db.diveDiverRoles)
          .insert(
            DiveDiverRolesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              roleId: Value(roleId),
              createdAt: Value(at),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveDiverRoles',
        recordId: id,
        localUpdatedAt: at,
      );
    }
  }

  Future<void> writeBuddyRoles(
    String diveId,
    String buddyId,
    Iterable<String> roleIds, {
    int? now,
  }) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final wanted = DiveRoleSet.normalizeBuddy(roleIds);
    final links = await (_db.select(_db.diveBuddies)..where(
          (t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId),
        ))
        .get();
    for (final link in links) {
      if (link.role == wanted.first) continue;
      await (_db.update(_db.diveBuddies)..where((t) => t.id.equals(link.id)))
          .write(DiveBuddiesCompanion(role: Value(wanted.first)));
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: link.id,
        localUpdatedAt: at,
      );
    }
    final existing = await (_db.select(_db.diveBuddyRoles)..where(
          (t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId),
        ))
        .get();
    for (final row in existing) {
      if (wanted.contains(row.roleId)) continue;
      await (_db.delete(
        _db.diveBuddyRoles,
      )..where((t) => t.id.equals(row.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveBuddyRoles',
        recordId: row.id,
      );
    }
    final have = {for (final r in existing) r.roleId};
    for (final roleId in wanted) {
      if (have.contains(roleId)) continue;
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddyRoles)
          .insert(
            DiveBuddyRolesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(buddyId),
              roleId: Value(roleId),
              createdAt: Value(at),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddyRoles',
        recordId: id,
        localUpdatedAt: at,
      );
    }
  }

  Future<void> deleteBuddyRoles(
    String diveId,
    Iterable<String> buddyIds,
  ) async {
    final ids = buddyIds.toList();
    if (ids.isEmpty) return;
    final rows = await (_db.select(_db.diveBuddyRoles)..where(
          (t) => t.diveId.equals(diveId) & t.buddyId.isIn(ids),
        ))
        .get();
    if (rows.isEmpty) return;
    await (_db.delete(_db.diveBuddyRoles)..where(
          (t) => t.diveId.equals(diveId) & t.buddyId.isIn(ids),
        ))
        .go();
    await _syncRepository.logDeletions(
      entityType: 'diveBuddyRoles',
      recordIds: rows.map((r) => r.id),
    );
  }

  Future<void> restoreRows({
    required List<String> diveIds,
    required List<DiveDiverRole> diverRows,
    required List<DiveBuddyRole> buddyRows,
  }) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final keepDiver = {for (final r in diverRows) r.id};
    final keepBuddy = {for (final r in buddyRows) r.id};
    final currentDiver = await diverRoleRowsForDives(diveIds);
    final currentBuddy = await buddyRoleRowsForDives(diveIds);
    await _syncRepository.logDeletions(
      entityType: 'diveDiverRoles',
      recordIds: [
        for (final r in currentDiver)
          if (!keepDiver.contains(r.id)) r.id,
      ],
    );
    await _syncRepository.logDeletions(
      entityType: 'diveBuddyRoles',
      recordIds: [
        for (final r in currentBuddy)
          if (!keepBuddy.contains(r.id)) r.id,
      ],
    );
    await (_db.delete(
      _db.diveDiverRoles,
    )..where((t) => t.diveId.isIn(diveIds))).go();
    await (_db.delete(
      _db.diveBuddyRoles,
    )..where((t) => t.diveId.isIn(diveIds))).go();
    for (final r in diverRows) {
      await _db
          .into(_db.diveDiverRoles)
          .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
      await _syncRepository.markRecordPending(
        entityType: 'diveDiverRoles',
        recordId: r.id,
        localUpdatedAt: now,
      );
    }
    for (final r in buddyRows) {
      await _db
          .into(_db.diveBuddyRoles)
          .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddyRoles',
        recordId: r.id,
        localUpdatedAt: now,
      );
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_roles/data/repositories/dive_role_link_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/features/dive_roles/data/repositories/dive_role_link_repository.dart test/features/dive_roles/data/repositories/dive_role_link_repository_test.dart
git commit -m "feat(dive-roles): read and write role sets through the junctions"
```

---

### Task 6: Dive repository persists and hydrates the diver's roles

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Modify: `lib/features/dive_log/data/services/dive_split_service.dart`
- Modify: `lib/features/dive_log/data/services/dive_uncombine_service.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_diver_roles_test.dart`; extend `test/features/dive_log/data/services/dive_uncombine_service_test.dart` and the split service test

**Interfaces:**
- Consumes: `DiveRoleLinkRepository.diverRoleIdsForDives`, `writeDiverRoles` (Task 5).
- Produces: `createDive` / `updateDive` persist `Dive.diverRoleIds`; every dive mapper (`_mapRowToDive`, `_mapRowToDiveWithPreloadedData`) hydrates it.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/data/repositories/dive_repository_diver_roles_test.dart
// setUp: setUpTestDatabase(); repo = DiveRepository() (use the same
// construction the existing dive repository tests use, e.g. in
// test/features/dive_log/data/repositories/dive_repository_test.dart).
test('createDive stores several diver roles and getDiveById reads them', () async {
  final created = await repo.createDive(
    Dive(id: '', dateTime: DateTime.utc(2026, 1, 1),
        diverRoleIds: const ['diveMaster', 'diveGuide']),
  );
  final read = await repo.getDiveById(created.id);
  expect(read!.diverRoleIds, ['diveGuide', 'diveMaster']);
});

test('updateDive replaces the set', () async {
  final created = await repo.createDive(
    Dive(id: '', dateTime: DateTime.utc(2026, 1, 1),
        diverRoleIds: const ['diveMaster', 'diveGuide']),
  );
  await repo.updateDive(created.copyWith(diverRoleIds: const ['instructor']));
  expect((await repo.getDiveById(created.id))!.diverRoleIds, ['instructor']);
});

test('the list loader hydrates the set', () async {
  final created = await repo.createDive(
    Dive(id: '', dateTime: DateTime.utc(2026, 1, 1),
        diverRoleIds: const ['diveMaster', 'diveGuide']),
  );
  final all = await repo.getAllDives();
  expect(all.firstWhere((d) => d.id == created.id).diverRoleIds,
      ['diveGuide', 'diveMaster']);
});
```

Add to the uncombine test: after uncombining a dive that held `['diveMaster','diveGuide']`, each restored dive has `diverRoleIds` empty. Add to the split test: the new dive from a split of a dive with `['diveMaster','diveGuide']` carries the same set.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_diver_roles_test.dart`
Expected: FAIL (`diverRoleIds` reads back `['diveGuide']` only, the primary).

- [ ] **Step 3: Implement in `dive_repository_impl.dart`**

1. Field: `final DiveRoleLinkRepository _roleLinks = DiveRoleLinkRepository();` beside `_buddyRepository`, with the import.
2. `createDive` (after `await _replaceDiveTypeRows(id, dive.diveTypeIds, now);`): `await _roleLinks.writeDiverRoles(id, dive.diverRoleIds, now: now);` and change the companion to `diverRole: Value(DiveRoleSet.primary(dive.diverRoleIds)),`.
3. `updateDive` (after `_replaceDiveTypeRows(dive.id, ...)`): `await _roleLinks.writeDiverRoles(dive.id, dive.diverRoleIds, now: now);` and the same companion change.
4. Batch loader (near line 550): `final diverRolesByDive = await _roleLinks.diverRoleIdsForDives(diveIds);` and pass `diverRoleIds: diverRolesByDive[row.id] ?? const []` into `_mapRowToDiveWithPreloadedData`, adding a `List<String> diverRoleIds = const []` parameter to that method and using it instead of `[?row.diverRole]`.
5. Single mapper `_mapRowToDive` (near line 4253): `final diverRoleIds = (await _roleLinks.diverRoleIdsForDives([row.id]))[row.id] ?? const [];` and `diverRoleIds: diverRoleIds,`.
6. Search the file for any other `Dive(` built from a row (`grep -n "diverRoleIds: \[?row" dive_repository_impl.dart`) and give each the same hydration.

- [ ] **Step 4: Split copies the set; uncombine clears it**

`dive_split_service.dart`, after the new dive row insert (step 1 in that method): 

```dart
      // The diver's own roles travel with the dive row (issue #1221).
      final roles = await DiveRoleLinkRepository().diverRoleIdsForDives([
        diveRow.id,
      ]);
      await DiveRoleLinkRepository().writeDiverRoles(
        newDiveId,
        roles[diveRow.id] ?? const [],
        now: now,
      );
```

(use the method's existing `now` variable; if none, `DateTime.now().millisecondsSinceEpoch`).

`dive_uncombine_service.dart`: beside `diverRole: const Value(null),`, after the restored dive insert: `await DiveRoleLinkRepository().writeDiverRoles(restoredId, const []);` (use the variable naming the restored dive id there). Since the restored row is a fresh insert with no junction rows and a null scalar, this is a no-op today; it guards a future copy path. If the restored dive is inserted with a brand-new id and no junction copy, skip the call and instead add the test only (assert empty).

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): persist and load the diver's role set"
```

---

### Task 7: Buddy repository persists and hydrates buddy role sets

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_repository_roles_test.dart`; keep `buddy_repository_bulk_test.dart` green

**Interfaces:**
- Consumes: Task 5 repository.
- Produces:
  - `getBuddiesForDive`, `getBuddiesForDives`, `getBuddiesForDivesWithCertifications` return `BuddyWithRole.roles` from resolved sets.
  - `setBuddiesForDive(diveId, List<BuddyWithRole>)` writes each person's roles.
  - `addBuddyToDive(String diveId, String buddyId, List<String> roleIds)` (was `String roleId`): replaces that person's roles.
  - `removeBuddyFromDive`, `bulkRemoveBuddies` delete role rows.
  - `bulkAddBuddies`, `bulkUpdateBuddyRoles`, `bulkReplaceBuddies` write `bwr.roleIds`.
  - `Future<Map<String, List<String>>> unanimousBuddyRolesForDives(List<String> diveIds)` (was `Map<String, String>`).

- [ ] **Step 1: Write the failing tests**

```dart
// setUp as in buddy_repository_bulk_test.dart (dives d1, d2; buddies b1, b2).
test('setBuddiesForDive stores each buddy\'s role set', () async {
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
  ]);
  final read = await repo.getBuddiesForDive('d1');
  expect(read.single.roleIds, ['diveGuide', 'diveMaster']);
});

test('buddy roles survive a dive_buddies row being replaced', () async {
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
  ]);
  // What an older app version does on save: same pair, fresh row id, and
  // the primary role it read.
  final db = DatabaseService.instance.database;
  await db.customStatement("DELETE FROM dive_buddies WHERE dive_id = 'd1'");
  await db.customStatement(
    "INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) "
    "VALUES ('fresh', 'd1', 'b1', 'diveGuide', 0)",
  );
  expect((await repo.getBuddiesForDive('d1')).single.roleIds,
      ['diveGuide', 'diveMaster']);
});

test('removing a buddy tombstones their role rows', () async {
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
  ]);
  await repo.removeBuddyFromDive('d1', 'b1');
  await repo.addBuddyToDive('d1', 'b1', const ['buddy']);
  expect((await repo.getBuddiesForDive('d1')).single.roleIds, ['buddy']);
});

test('the batch load returns sets per dive', () async {
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
  ]);
  final byDive = await repo.getBuddiesForDives(['d1']);
  expect(byDive['d1']!.single.roleIds, ['diveGuide', 'diveMaster']);
});

test('unanimous role sets omit buddies whose sets differ', () async {
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
  ]);
  await repo.setBuddiesForDive('d2', [
    BuddyWithRole(buddy: ana, roles: [role('diveGuide'), role('diveMaster')]),
    BuddyWithRole(buddy: ben, roles: [role('instructor')]),
  ]);
  expect(await repo.unanimousBuddyRolesForDives(['d1', 'd2']), {
    'b1': ['diveGuide', 'diveMaster'],
    'b2': ['instructor'],
  });
  await repo.setBuddiesForDive('d1', [
    BuddyWithRole(buddy: ana, roles: [role('diveMaster')]),
  ]);
  expect((await repo.unanimousBuddyRolesForDives(['d1', 'd2'])).containsKey('b1'),
      isFalse);
});
```

with helpers `DiveRole role(String id) => DiveRole.synthetic(id);` and `ana`/`ben` built like the existing bulk test's buddies.

Note on `unanimousBuddyRolesForDives`: today a buddy present on only some dives still reports its role (the SQL groups only rows that exist). Keep that: unanimous over the dives where the buddy is linked.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_roles_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

1. Field `final DiveRoleLinkRepository _roleLinks = DiveRoleLinkRepository();`.
2. `getBuddiesForDive`: after the query, `final sets = (await _roleLinks.buddyRoleIdsForDives([diveId]))[diveId] ?? const {};` and build roles:

```dart
      final roleIds = sets[buddy.id] ??
          DiveRoleSet.resolveBuddy(
            scalar: row.data['role'] as String?,
            junction: const [],
          );
      final roles = [
        for (final id in roleIds)
          resolveDiveRole(
            rolesById,
            id,
            diveDiverId: row.data['dive_diver_id'] as String?,
          ),
      ];
      return domain.BuddyWithRole(buddy: buddy, roles: roles);
```

and the re-wrap at the end `domain.BuddyWithRole(buddy: byId[w.buddy.id]!, roles: w.roles)`.
3. `getBuddiesForDives`: `final sets = await _roleLinks.buddyRoleIdsForDives(diveIds);` and per row `final roleIds = sets[link.diveId]?[link.buddyId] ?? DiveRoleSet.resolveBuddy(scalar: link.role, junction: const []);` mapped through `resolveDiveRole` the same way. `getBuddiesForDivesWithCertifications`: `roles: row.roles`.
4. `setBuddiesForDive`: keep the delete-and-reinsert of `dive_buddies`, set `role: Value(DiveRoleSet.primary(bwr.roleIds) ?? DiveRole.buddyId)` on insert, then after the insert loop:

```dart
    final kept = {for (final b in buddies) b.buddy.id};
    await _roleLinks.deleteBuddyRoles(diveId, [
      for (final row in existing)
        if (!kept.contains(row.buddyId)) row.buddyId,
    ]);
    for (final bwr in buddies) {
      await _roleLinks.writeBuddyRoles(diveId, bwr.buddy.id, bwr.roleIds, now: now);
    }
```

5. `addBuddyToDive(String diveId, String buddyId, List<String> roleIds)`: write the row with `role: Value(DiveRoleSet.normalizeBuddy(roleIds).first)` as today (update or insert), then `await _roleLinks.writeBuddyRoles(diveId, buddyId, roleIds, now: now);`. Update every caller (`grep -rn "addBuddyToDive(" lib test`): a single role `x` becomes `[x]` (Task 15 rewrites the importer's calls).
6. `removeBuddyFromDive`: `await _roleLinks.deleteBuddyRoles(diveId, [buddyId]);` after the row delete.
7. `bulkAddBuddies`: on insert, and on existing-with-`overwriteRole`, call `_roleLinks.writeBuddyRoles(diveId, bwr.buddy.id, bwr.roleIds, now: now)` (the companion `role:` uses `DiveRoleSet.normalizeBuddy(bwr.roleIds).first`).
8. `bulkUpdateBuddyRoles`: replace the `role:` write with, for each existing row, `_roleLinks.writeBuddyRoles(row.diveId, bwr.buddy.id, bwr.roleIds, now: now)`; keep the hlc stamp on the `dive_buddies` rows only when the primary changed (`writeBuddyRoles` marks them pending itself).
9. `bulkRemoveBuddies`: per dive `await _roleLinks.deleteBuddyRoles(diveId, buddyIds);`.
10. `bulkReplaceBuddies`: as `setBuddiesForDive` (delete role rows for leavers, write sets for the rest).
11. `unanimousBuddyRolesForDives`:

```dart
  Future<Map<String, List<String>>> unanimousBuddyRolesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final sets = await _roleLinks.buddyRoleIdsForDives(diveIds);
    final seen = <String, List<String>>{};
    final mixed = <String>{};
    for (final perDive in sets.values) {
      for (final entry in perDive.entries) {
        final held = seen[entry.key];
        if (held == null) {
          seen[entry.key] = entry.value;
        } else if (!const ListEquality<String>().equals(held, entry.value)) {
          mixed.add(entry.key);
        }
      }
    }
    return {
      for (final e in seen.entries)
        if (!mixed.contains(e.key)) e.key: e.value,
    };
  }
```

(import `package:collection/collection.dart` for `ListEquality`). Fix `buddyCountsForDives`' stale comment: "One dive_buddies row per (dive, buddy), so COUNT(diveId) equals the distinct-dive count."

12. Update callers of `unanimousBuddyRolesForDives` (`dive_edit_page.dart` `_existingBuddyRoleIds` becomes `Map<String, List<String>>`; for this task convert at the boundary: `_roleForBuddy` uses `existing.first` until Task 11).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/buddies test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(buddies): persist and load each buddy's role set"
```

---

### Task 8: Multi-select role sheet and display helpers

**Files:**
- Modify: `lib/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart`
- Create: `lib/features/dive_roles/presentation/dive_role_list_display.dart`
- Test: `test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart` (create or extend), `test/features/dive_roles/presentation/dive_role_list_display_test.dart`

**Interfaces:**
- Produces:
  - `Future<List<DiveRole>?> showDiveRoleSelector(BuildContext context, {required String title, required List<DiveRole> roles, Set<String> credentialRoleIds = const {}, bool allowEmpty = false, List<String> selectedRoleIds = const [], Future<DiveRole?> Function(String name)? onCreateCustomRole})`: null when dismissed, otherwise the ticked roles in `DiveRoleSet` order. For a buddy (`allowEmpty: false`) an empty tick set returns `[]` and callers map it to Buddy through `normalizeBuddy`.
  - `DiveRoleSelection` is removed.
  - `List<DiveRole> rolesForIds(Iterable<String> ids, Map<String, DiveRole> byId)` (synthetic fallback, input order kept).
  - `extension DiveRoleListDisplay on Iterable<DiveRole> { String joinedLocalizedNames(AppLocalizations l10n); }` joining with `', '`.

- [ ] **Step 1: Write the failing widget test**

```dart
// Pump a MaterialApp with localizations (copy the harness from an existing
// dive_roles widget test, e.g. test/features/dive_roles/presentation/pages/
// dive_roles_page_test.dart) and a button that awaits showDiveRoleSelector
// and stores the result.
testWidgets('ticks several roles and returns them on Done', (tester) async {
  // open with roles: buddy, diveGuide, diveMaster, solo; nothing selected
  // tap 'Divemaster', tap 'Dive Guide', tap 'Done'
  // expect result ids == ['diveGuide', 'diveMaster']
});

testWidgets('ticking Solo clears the others; ticking another clears Solo',
    (tester) async {
  // start selected [diveMaster]; tap 'Solo' -> only Solo checked;
  // tap 'Dive Guide' -> Solo unchecked, Dive Guide checked; Done -> ['diveGuide']
});

testWidgets('dismissing returns null', (tester) async {
  // open, tap outside the sheet (tester.tapAt(Offset(10, 10))), settle
  // expect result null
});

testWidgets('No role clears every tick when empty is allowed', (tester) async {
  // allowEmpty: true, selected [diveMaster]; tap 'No role'; Done -> []
});
```

Fill each body with concrete `find.text(...)` taps and `expect`s; use `Checkbox` finders (`find.byWidgetPredicate((w) => w is CheckboxListTile && w.value == true)`) to assert tick state.

And for the display helper:

```dart
test('joins localized names and keeps unknown ids', () {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final byId = {
    'diveGuide': DiveRole(id: 'diveGuide', name: 'Dive Guide', isBuiltIn: true,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  };
  final roles = rolesForIds(['diveGuide', 'mystery'], byId);
  expect(roles.joinedLocalizedNames(l10n), 'Dive Guide, mystery');
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_roles/presentation/`
Expected: FAIL.

- [ ] **Step 3: Implement the display helper**

```dart
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// The roles [ids] name, in the order given; an id with no row shows its raw
/// slug (see [DiveRole.synthetic]).
List<DiveRole> rolesForIds(Iterable<String> ids, Map<String, DiveRole> byId) =>
    [for (final id in ids) byId[id] ?? DiveRole.synthetic(id)];

extension DiveRoleListDisplay on Iterable<DiveRole> {
  /// "Divemaster, Dive Guide": each role's localized name, comma-joined, the
  /// same separator the dive's leader names use.
  String joinedLocalizedNames(AppLocalizations l10n) =>
      map((r) => r.localizedName(l10n)).join(', ');
}
```

- [ ] **Step 4: Implement the sheet.** Replace `DiveRoleSelection` and `showDiveRoleSelector` with:

```dart
/// Bottom sheet for picking the roles a person holds on a dive (issue
/// #1221). Every row is a checkbox; Done returns the ticked roles in
/// DiveRoleSet order, and dismissing returns null so the caller changes
/// nothing. Ticking Solo clears the rest and ticking anything else clears
/// Solo ([DiveRoleSet.toggle]). [allowEmpty] adds a "No role" row that
/// clears every tick (the diver's own role); a buddy's caller maps an empty
/// result to Buddy.
Future<List<DiveRole>?> showDiveRoleSelector(
  BuildContext context, {
  required String title,
  required List<DiveRole> roles,
  Set<String> credentialRoleIds = const {},
  bool allowEmpty = false,
  List<String> selectedRoleIds = const [],
  Future<DiveRole?> Function(String name)? onCreateCustomRole,
}) {
  return showModalBottomSheet<List<DiveRole>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _DiveRoleSelectorSheet(
      title: title,
      roles: roles,
      credentialRoleIds: credentialRoleIds,
      allowEmpty: allowEmpty,
      selectedRoleIds: selectedRoleIds,
      onCreateCustomRole: onCreateCustomRole,
    ),
  );
}

class _DiveRoleSelectorSheet extends StatefulWidget {
  const _DiveRoleSelectorSheet({
    required this.title,
    required this.roles,
    required this.credentialRoleIds,
    required this.allowEmpty,
    required this.selectedRoleIds,
    required this.onCreateCustomRole,
  });

  final String title;
  final List<DiveRole> roles;
  final Set<String> credentialRoleIds;
  final bool allowEmpty;
  final List<String> selectedRoleIds;
  final Future<DiveRole?> Function(String name)? onCreateCustomRole;

  @override
  State<_DiveRoleSelectorSheet> createState() => _DiveRoleSelectorSheetState();
}

class _DiveRoleSelectorSheetState extends State<_DiveRoleSelectorSheet> {
  late List<String> _ticked = DiveRoleSet.normalize(widget.selectedRoleIds);
  late final List<DiveRole> _roles = [...widget.roles];

  List<DiveRole> get _ordered => [
    ..._roles.where((r) => widget.credentialRoleIds.contains(r.id)),
    ..._roles.where((r) => !widget.credentialRoleIds.contains(r.id)),
  ];

  void _done() {
    final byId = {for (final r in _roles) r.id: r};
    Navigator.pop(context, [
      for (final id in _ticked) byId[id] ?? DiveRole.synthetic(id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _done,
                    child: Text(l10n.common_action_done),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (widget.allowEmpty)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.buddies_picker_noRole),
                selected: _ticked.isEmpty,
                onTap: () => setState(() => _ticked = const []),
              ),
            for (final role in _ordered)
              CheckboxListTile(
                value: _ticked.contains(role.id),
                secondary: widget.credentialRoleIds.contains(role.id)
                    ? const Icon(Icons.workspace_premium)
                    : null,
                title: Text(role.localizedName(l10n)),
                onChanged: (_) => setState(
                  () => _ticked = DiveRoleSet.toggle(_ticked, role.id),
                ),
              ),
            if (widget.onCreateCustomRole != null)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.buddies_picker_addCustomRole),
                onTap: () async {
                  final created = await _showAddCustomRoleDialog(
                    context,
                    widget.onCreateCustomRole!,
                  );
                  if (created == null || !mounted) return;
                  setState(() {
                    if (!_roles.any((r) => r.id == created.id)) {
                      _roles.add(created);
                    }
                    _ticked = DiveRoleSet.toggle(
                      _ticked.where((id) => id != created.id),
                      created.id,
                    );
                  });
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

Keep `_showAddCustomRoleDialog` and `_AddCustomRoleDialog` unchanged. Add the `DiveRoleSet` import.

- [ ] **Step 5: Adapt the callers so the tree compiles** (behaviour finished in Tasks 9 to 11). Each caller now receives `List<DiveRole>?`:
  - `buddy_picker.dart` `_MeChip`: `allowEmpty: true, selectedRoleIds: [?diverRoleId]`, then `if (picked != null) onChanged(picked.firstOrNull?.id);` (Task 9 makes it a list).
  - `_BuddyChip._showRoleSelector`: `selectedRoleIds: buddyWithRole.roleIds`; on non-null result `onRoleChanged(picked.isEmpty ? DiveRole.builtInBuddy() : picked.first)` (Task 9).
  - `_showRoleSelectorForBuddy`: on non-null `_addBuddy(buddy, picked.isEmpty ? DiveRole.builtInBuddy() : picked.first)` (Task 9).
  - `dive_edit_page.dart` `_showBulkDiverRolePicker` and `_showBulkBuddyRolePicker`: the same first-element conversion (Task 11).

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/dive_roles test/features/buddies/presentation test/features/dive_log/presentation`
Expected: PASS (update any existing test that tapped a radio row to tap the checkbox and Done).

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib test
git commit -m "feat(dive-roles): pick several roles in the role sheet"
```

---

### Task 9: Buddy picker chips carry role sets

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_picker_test.dart` (extend)

**Interfaces:**
- Produces: `BuddyPicker({..., List<String> diverRoleIds = const [], ValueChanged<List<String>>? onDiverRoleChanged})` (was `String? diverRoleId` / `ValueChanged<String?>`); `_BuddyChip.onRoleChanged: ValueChanged<List<DiveRole>>`; the selection sheet's `_addBuddy(Buddy, List<DiveRole>)`.

- [ ] **Step 1: Failing widget tests**

```dart
testWidgets('the Me chip shows every role, joined', (tester) async {
  // pump BuddyPicker(diverRoleIds: ['diveGuide', 'diveMaster'],
  //   onDiverRoleChanged: (_) {}, selectedBuddies: const [], onChanged: (_) {})
  // with diveRoleMapProvider overridden to the built-ins
  // expect(find.text('Dive Guide, Divemaster'), findsOneWidget);
});

testWidgets('a buddy chip shows every role and returns the picked set',
    (tester) async {
  // selectedBuddies: [BuddyWithRole(buddy: ana, roles: [guide, dm])]
  // expect 'Dive Guide, Divemaster'; tap the chip; untick Dive Guide; Done
  // expect onChanged received roleIds ['diveMaster']
});

testWidgets('unticking every role of a buddy leaves Buddy', (tester) async {
  // chip with [dm]; open; untick Divemaster; Done
  // expect onChanged received roleIds ['buddy']
});
```

- [ ] **Step 2: Run, expect FAIL.** `flutter test test/features/buddies/presentation/widgets/buddy_picker_test.dart`

- [ ] **Step 3: Implement**

- Me chip label: `diverRoleIds.isEmpty ? l10n.buddies_picker_setMyRole : rolesForIds(diverRoleIds, rolesById).joinedLocalizedNames(l10n)`, rendered with `maxLines: 1, overflow: TextOverflow.ellipsis` inside a `Tooltip(message: label, ...)`. On tap: `allowEmpty: true, selectedRoleIds: diverRoleIds`; `if (picked != null) onChanged([for (final r in picked) r.id]);`
- `_BuddyChip` label: `buddyWithRole.roles.joinedLocalizedNames(l10n)` with the same ellipsis and tooltip; on tap `selectedRoleIds: buddyWithRole.roleIds`, result mapped:

```dart
    if (picked == null) return;
    onRoleChanged(picked.isEmpty ? [DiveRole.builtInBuddy()] : picked);
```

- In `BuddyPicker.build`, `onRoleChanged: (roles) { ... BuddyWithRole(buddy: b.buddy, roles: roles) ... }`.
- Selection sheet: `selectedRole` becomes `selectedRoles` (`.map((b) => b.roles).firstOrNull`), the chip text `selectedRoles?.joinedLocalizedNames(l10n) ?? l10n.diveRole_builtin_buddy`; `_addBuddy(Buddy buddy, List<DiveRole> roles)` builds `BuddyWithRole(buddy: buddy, roles: roles)`; `_showRoleSelectorForBuddy` calls `_addBuddy(buddy, picked.isEmpty ? [DiveRole.builtInBuddy()] : picked)` on a non-null result.
- Update `dive_edit_page.dart` call site: `diverRoleIds: _diverRoleIds` and `onDiverRoleChanged: (ids) => setState(() { _markDirty(); _diverRoleIds = ids; })` (Task 10 introduces `_diverRoleIds`; do the rename here if Task 10 has not run: replace `String? _diverRoleId` with `List<String> _diverRoleIds = const []` throughout the page, mapping `dive.diverRoleIds` in and out).

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/buddies/presentation`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(buddies): show and edit several roles on the Me and buddy chips"
```

---

### Task 10: Single-dive editor and dive detail

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (single-dive paths)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test: extend `test/features/dive_log/presentation/pages/dive_detail_page_test.dart` (or the file that covers `_buildBuddiesSection`), and the dive edit page save test

**Interfaces:**
- Consumes: `rolesForIds`, `joinedLocalizedNames` (Task 8); `Dive.diverRoleIds`.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('detail shows my roles and each buddy\'s roles, joined',
    (tester) async {
  // dive with diverRoleIds ['diveGuide', 'diveMaster'] and buddiesForDive
  // overridden to [BuddyWithRole(buddy: ana, roles: [instructor, safety])]
  // expect find.text('Dive Guide, Divemaster') and
  // find.text('Instructor, Safety Diver'); buddy count text says 1 buddy.
});

testWidgets('saving the editor keeps several roles', (tester) async {
  // open the editor on a dive with diverRoleIds [dm, guide]; save untouched;
  // expect the repository received diverRoleIds ['diveGuide', 'diveMaster'].
});
```

Copy the provider overrides from the existing detail-page buddies test.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`dive_edit_page.dart`: `List<String> _diverRoleIds = const [];` (replacing `String? _diverRoleId`), load `_diverRoleIds = dive.diverRoleIds;`, save `diverRoleIds: _diverRoleIds,` at both `Dive(...)` builds (lines ~1463 and ~5928), `isEmpty: _selectedBuddies.isEmpty && _diverRoleIds.isEmpty`, and the `BuddyPicker` wiring from Task 9. Line ~701 (`role: existing.role`) becomes `roles: existing.roles`.

`dive_detail_page.dart`:

```dart
                if (dive.diverRoleIds.isNotEmpty)
                  _buildMyRoleTile(context, ref, dive),
                if (showLegacyText)
                  LegacyBuddyTextSection(dive: dive)
                else if (buddies.isEmpty && dive.diverRoleIds.isEmpty)
```

`_buildBuddyTile` subtitle: `Text(bwr.roles.joinedLocalizedNames(context.l10n))`. `_buildMyRoleTile` subtitle:

```dart
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final label = rolesForIds(
      dive.diverRoleIds,
      rolesById,
    ).joinedLocalizedNames(context.l10n);
    ...
      subtitle: Text(label),
```

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/dive_log/presentation`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(dive-log): edit and show several roles per person on a dive"
```

---

### Task 11: Bulk edit replaces role sets

**Files:**
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (add `DiverRolesOp`)
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart` (add `priorDiverRoleIds`)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (diverRole no longer a companion column)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (bulk paths)
- Test: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`, `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`

**Interfaces:**
- Produces: `class DiverRolesOp extends BulkCollectionOp { final List<String> roleIds; const DiverRolesOp({required this.roleIds}); }` (replace semantics); `BulkEditSnapshot.priorDiverRoleIds: Map<String, List<String>>?`; `BulkScalarInputs` loses `diverRoleId`.

- [ ] **Step 1: Failing service tests**

```dart
test('DiverRolesOp replaces the set on every dive, and undo restores', () async {
  // dives d1 [dm, guide], d2 [instructor] via DiveRoleLinkRepository
  final snap = await service.apply(BulkEditRequest(
    diveIds: ['d1', 'd2'],
    ops: [DiverRolesOp(roleIds: ['safetyDiver', 'supportDiver'])],
  ));
  expect(await roleLinks.diverRoleIdsForDives(['d1', 'd2']), {
    'd1': ['supportDiver', 'safetyDiver'],
    'd2': ['supportDiver', 'safetyDiver'],
  });
  await service.undo(snap);
  expect(await roleLinks.diverRoleIdsForDives(['d1', 'd2']), {
    'd1': ['diveGuide', 'diveMaster'],
    'd2': ['instructor'],
  });
});

test('a buddy role update rewrites the set where the buddy is linked',
    () async {
  // b1 on d1 with [dm]; d2 without b1
  await service.apply(BulkEditRequest(diveIds: ['d1', 'd2'], ops: [
    BuddiesOp(mode: BulkCollectionMode.update, buddies: [
      BuddyWithRole(buddy: ana, roles: [role('diveGuide'), role('diveMaster')]),
    ]),
  ]));
  expect((await buddyRepo.getBuddiesForDive('d1')).single.roleIds,
      ['diveGuide', 'diveMaster']);
  expect(await buddyRepo.getBuddiesForDive('d2'), isEmpty);
});
```

Order note: `normalize` puts `supportDiver` (index 7) before `safetyDiver` (index 8).

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement the op, snapshot and service**

`bulk_edit_request.dart`:

```dart
/// The diver's own roles on every selected dive, replaced by [roleIds]
/// (issue #1221). Replace is the only mode: the gated "My role" row sets
/// exactly the picked set, as every gated field does.
class DiverRolesOp extends BulkCollectionOp {
  final List<String> roleIds;
  const DiverRolesOp({required this.roleIds});
}
```

`bulk_edit_snapshot.dart`: field `final Map<String, List<String>>? priorDiverRoleIds;` and constructor `this.priorDiverRoleIds,`.

`bulk_dive_edit_service.dart`: field `final DiveRoleLinkRepository _roleLinks = DiveRoleLinkRepository();`; capture in the switch:

```dart
        case DiverRolesOp():
          priorDiverRoleIds = await _roleLinks.diverRoleIdsForDives(ids);
```

(declare `Map<String, List<String>>? priorDiverRoleIds;` with the others and pass it to the snapshot); apply in `_applyOp`:

```dart
      case DiverRolesOp(:final roleIds):
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          await _roleLinks.writeDiverRoles(id, roleIds, now: now);
        }
```

undo, after the scalar restore loop:

```dart
      final diverRoles = snapshot.priorDiverRoleIds;
      if (diverRoles != null) {
        for (final id in ids) {
          await _roleLinks.writeDiverRoles(id, diverRoles[id] ?? const []);
        }
      }
```

`bulk_edit_field_set.dart`: remove `diverRoleId` from `BulkScalarInputs`; `BulkField.diverRole => c,` (the gate stays, its value rides `DiverRolesOp`). Update the doc comment on `BulkField.diverRole` to say so.

- [ ] **Step 4: Edit page bulk wiring**

- `_saveBulk`: `scalarFields.remove(BulkField.diverRole);` beside the notes removal.
- `_collectCollectionOps`: `if (_bulkEnabled.contains(BulkField.diverRole)) ops.add(DiverRolesOp(roleIds: _diverRoleIds));`
- `_collectScalarInputs`: drop `diverRoleId:`.
- My-role row: `value: _diverRoleIds.isEmpty ? null : rolesForIds(_diverRoleIds, rolesById).joinedLocalizedNames(l10n)`, placeholder `_bulkDiverRolePlaceholder` = `diveLog_bulkEdit_buddyRoleMixed` when the selected dives' sets differ, the joined common set when they agree, else `diveLog_edit_row_notSet`. Load the sets in `_loadBulkMembers` with `DiveRoleLinkRepository().diverRoleIdsForDives(ids)` into `List<String>? _existingDiverRoleIds` (null when mixed).
- `_showBulkDiverRolePicker`: `allowEmpty: true, selectedRoleIds: _diverRoleIds`; on non-null result `_diverRoleIds = [for (final r in picked) r.id]`. `onClear` sets `const []`.
- Buddy rows: `final Map<String, List<DiveRole>> _buddyRoleById`, `final Map<String, List<String>> _existingBuddyRoleIds`; `_bulkBuddyRoleIds(id)` returns picked ids, else existing, else `[buddy]` for a fresh add, else null (mixed); `_bulkBuddyRoleLabel` joins or says Mixed; the role control moves from `trailingBuilder` to `detailBuilder` (a `TextButton` whose child is the label `Text` with `maxLines: 1, overflow: TextOverflow.ellipsis`), keeping the `ValueKey('buddy-role-${item.id}')`. Check `BulkMembershipEditor` for a `detailBuilder` parameter (`grep -n "detailBuilder" lib/shared/bulk_edit/bulk_membership_editor.dart`); if it does not exist, keep `trailingBuilder` and wrap the button in `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160))`.
- `_showBulkBuddyRolePicker`: `selectedRoleIds: _bulkBuddyRoleIds(item.id) ?? const []`; on non-null result `_buddyRoleById[item.id] = picked.isEmpty ? [DiveRole.builtInBuddy()] : picked;`.
- `_addBuddyMembers`: `_buddyRoleById[bwr.buddy.id] = bwr.roles;`.
- `_buddyWithRole(id)`: `roles: _rolesForBuddy(id)`, where `_rolesForBuddy` returns picked, else `[for (final r in existing) DiveRole.synthetic(r)]`, else `[DiveRole.builtInBuddy()]`.

- [ ] **Step 5: Form test.** In `bulk_dive_edit_form_test.dart` add: enable My role, pick Divemaster and Dive Guide, save; expect the captured request has a `DiverRolesOp` with `['diveGuide', 'diveMaster']` and its scalars contain no `diver_role` column.

- [ ] **Step 6: Run tests, expect PASS.** `flutter test test/features/dive_log`

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(dive-log): bulk edit replaces role sets"
```

---

### Task 12: Dive merge and consolidation union roles

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Modify: `lib/features/dive_log/data/services/dive_merge_snapshot.dart`
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart`
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`, `test/features/dive_log/data/services/dive_merge_service_test.dart`, `test/features/dive_log/data/services/dive_consolidation_service_test.dart` (extend each)

**Interfaces:**
- Produces: `DiveMergeSnapshot.diverRoleRows: List<DiveDiverRole>` and `buddyRoleRows: List<DiveBuddyRole>` (default `const []`), captured in `capture`.

- [ ] **Step 1: Failing tests**

Builder:

```dart
test('the merged dive holds the union of the diver roles', () {
  final a = dive(diverRoleIds: const ['diveMaster']);
  final b = dive(diverRoleIds: const ['diveGuide']);
  expect(build([a, b]).mergedDive.diverRoleIds, ['diveGuide', 'diveMaster']);
});

test('Solo yields to another role in the union', () {
  final a = dive(diverRoleIds: const ['solo']);
  final b = dive(diverRoleIds: const ['instructor']);
  expect(build([a, b]).mergedDive.diverRoleIds, ['instructor']);
});
```

(use the builder test file's existing `dive(...)` / `build(...)` helpers.)

Merge service: two dives, buddy Ana as `[dm]` on one and `[guide]` on the other; after merge, Ana's set on the merged dive is `['diveGuide', 'diveMaster']`; after undo, each source dive's sets are back (`buddyRoleIdsForDives`) and the merged dive is gone.

Consolidation: target has Ana `[dm]` and diver `[instructor]`; secondary has Ana `[guide]` and diver `[safetyDiver]`; after consolidation the target holds Ana `['diveGuide', 'diveMaster']` and diver `['instructor', 'safetyDiver']`; undo restores both exactly.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

Builder: `diverRoleIds: DiveRoleSet.union([for (final d in sorted) d.diverRoleIds]),`.

Snapshot: add the two fields and capture

```dart
      diverRoleRows: await (db.select(
        db.diveDiverRoles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      buddyRoleRows: await (db.select(
        db.diveBuddyRoles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
```

Add a pure helper on the snapshot:

```dart
  /// Each person's resolved role set per source dive, from the captured rows
  /// (DiveRoleSet.resolveBuddy), keyed (diveId, buddyId).
  Map<(String, String), List<String>> resolvedBuddyRoles() {
    final junction = <(String, String), List<String>>{};
    for (final r in buddyRoleRows) {
      junction.putIfAbsent((r.diveId, r.buddyId), () => []).add(r.roleId);
    }
    return {
      for (final link in buddyRows)
        (link.diveId, link.buddyId): DiveRoleSet.resolveBuddy(
          scalar: link.role,
          junction: junction[(link.diveId, link.buddyId)] ?? const [],
        ),
    };
  }
```

Merge service, step 8 (buddies): after the union loop,

```dart
      final resolved = snapshot.resolvedBuddyRoles();
      final roleLinks = DiveRoleLinkRepository();
      for (final buddyId in seenBuddies) {
        await roleLinks.writeBuddyRoles(
          mergedId,
          buddyId,
          DiveRoleSet.union([
            for (final source in result.sortedSources)
              ?resolved[(source.id, buddyId)],
          ]),
          now: now,
        );
      }
```

Merge undo: add `batch.deleteWhere(_db.diveDiverRoles, (t) => t.diveId.equals(mergedId)); batch.deleteWhere(_db.diveBuddyRoles, (t) => t.diveId.equals(mergedId));` beside the other child deletes, tombstoning those rows first with `_sync.logDeletions(...)` over the current ids (as the undo does for the other children; follow that file's pattern for tombstoning merge-output rows), then after the source dives are restored:

```dart
      await DiveRoleLinkRepository().restoreRows(
        diveIds: [for (final d in snapshot.diveRows) d.id],
        diverRows: snapshot.diverRoleRows,
        buddyRows: snapshot.buddyRoleRows,
      );
```

Consolidation: after its buddy union loop, for every buddy now on the target (`targetBuddyIds`), write the union of the target's and the secondary's resolved sets; and `await roleLinks.writeDiverRoles(targetDiveId, DiveRoleSet.union([targetSet, secondarySet]), now: now)` where the sets come from `roleLinks.diverRoleIdsForDives` captured BEFORE any write (read both at the start of the secondary loop). Undo: add `'diveDiverRoles'` and `'diveBuddyRoles'` to `snapshotIds` and `currentChildIds` (selecting by `diveId.equals(mergedId)`), the two `deleteWhere`s to the batch, and a `restoreRows` call over the snapshot's dives after the reinsert loops.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/dive_log`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(dive-log): union roles when dives are merged or consolidated"
```

---

### Task 13: Mirror maps every role

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_mirror_service.dart`
- Test: `test/features/dive_log/data/services/dive_mirror_service_test.dart` (extend)

- [ ] **Step 1: Failing test**

```dart
test('the sibling carries every role on both sides', () async {
  // source dive owned by diver A with diverRoleIds [dm, guide] and a buddy
  // linked to diver B holding [instructor, safetyDiver].
  // mirror to B.
  // expect: B's sibling diverRoleIds == ['instructor', 'safetyDiver'];
  // the reciprocal buddy for A on the sibling has roleIds ['diveGuide',
  // 'diveMaster'].
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** in `_createSibling`:

```dart
    final sourceRoleIds = source.diverRoleIds;

    // The target's own roles: what its buddy held on the source.
    var targetRoleIds = const <String>[];
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) {
        targetRoleIds = bwr.roleIds;
      }
    }
    final mappedTarget = await _rolesFor(targetRoleIds, targetDiverId);
```

pass `diverRoleIds: [for (final r in mappedTarget) r.id]` to `mirroredDiveFrom`; the reciprocal buddy gets `roles: await _rolesFor(sourceRoleIds.isEmpty ? const [DiveRole.buddyId] : sourceRoleIds, targetDiverId)`; each other buddy `roles: await _rolesFor(bwr.roleIds, targetDiverId)`. Add:

```dart
  /// [roleIds] mapped one by one through [_roleFor], deduped (two custom
  /// roles can both fall back to Buddy) and normalized.
  Future<List<DiveRole>> _rolesFor(
    List<String> roleIds,
    String targetDiverId,
  ) async {
    final byId = <String, DiveRole>{};
    for (final id in roleIds) {
      final role = await _roleFor(id, targetDiverId);
      byId[role.id] = role;
    }
    return [for (final id in DiveRoleSet.normalize(byId.keys)) byId[id]!];
  }
```

For the target's own set, an empty source set stays empty (no role), as today's null.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/dive_log/data/services/dive_mirror_service_test.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(dive-log): mirror every role onto a sibling dive"
```

---

### Task 14: Buddy merge unions roles

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_merge_repository_test.dart` (extend; find the file with `grep -rln "BuddyMergeRepository\|mergeBuddies" test/features/buddies`)

**Interfaces:**
- Produces: `BuddyMergeSnapshot.roleRows: List<DiveBuddyRole>` (default `const []`).

- [ ] **Step 1: Failing tests**

```dart
test('a shared dive keeps the union of both buddies\' roles', () async {
  // d1: survivor S [dm], duplicate D [guide]
  // merge D into S
  // expect S on d1 has roleIds ['diveGuide', 'diveMaster']; no row for D.
});

test('a dive only the duplicate was on moves its whole set', () async {
  // d2: D [instructor, safetyDiver]; merge; S on d2 has that set.
});

test('undo restores every role row', () async {
  // merge, then undo; buddyRoleIdsForDives(['d1','d2']) equals the
  // pre-merge map exactly.
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

- Capture before the transaction: `final roleRows = await (_db.select(_db.diveBuddyRoles)..where((t) => t.buddyId.isIn(orderedIds))).get();` and the resolved sets `final sets = await DiveRoleLinkRepository().buddyRoleIdsForDives({for (final r in allDiveBuddyRows) r.diveId}.toList());`.
- Delete `_roleRank`. On collision: snapshot the survivor row the first time (as today), set its role through the role link repository, and delete the duplicate's row (as today):

```dart
              final union = DiveRoleSet.union([
                sets[dupRow.diveId]?[survivorId] ?? const [],
                sets[dupRow.diveId]?[duplicateId] ?? const [],
              ]);
              await roleLinks.writeBuddyRoles(dupRow.diveId, survivorId, union, now: now);
              await roleLinks.deleteBuddyRoles(dupRow.diveId, [duplicateId]);
              sets[dupRow.diveId]![survivorId] = union;
```

  (record the survivor row in `modifiedDiveBuddyEntries` the first time before `writeBuddyRoles` changes its role).
- On no collision (relink): after updating `buddy_id`, move the set: `writeBuddyRoles(dupRow.diveId, survivorId, sets[dupRow.diveId]?[duplicateId] ?? [dupRow.role])` then `deleteBuddyRoles(dupRow.diveId, [duplicateId])`, and record `sets[dupRow.diveId]![survivorId]`.
- Pass `roleRows` into the snapshot. In undo, after the buddies and `dive_buddies` rows are restored:

```dart
      await DiveRoleLinkRepository().restoreRows(
        diveIds: {for (final r in snapshot.roleRows) r.diveId}
            .union({for (final e in snapshot.deletedDiveBuddyEntries) e.diveId})
            .union({for (final e in snapshot.modifiedDiveBuddyEntries) e.diveId})
            .toList(),
        diverRows: await DiveRoleLinkRepository().diverRoleRowsForDives(...same ids...),
        buddyRows: snapshot.roleRows,
      );
```

  Careful: `restoreRows` replaces ALL buddy role rows of those dives. Restrict it to the merged buddies: add an optional `Set<String>? onlyBuddyIds` parameter to `restoreRows` that limits the buddy-row deletion and tombstoning to those buddy ids, and pass `{snapshot.originalSurvivor.id, ...snapshot.deletedBuddies.map((b) => b.id)}`; pass `diverRows` only when restoring diver rows (make it optional, default null meaning "leave diver rows alone"). Update Task 5's tests with one case for each new parameter.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/buddies test/features/dive_roles`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(buddies): union roles when buddies are merged"
```

---

### Task 15: UDDF and the importers

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildDiverRole`, `<buddyroles>`)
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart` (custom role collection)
- Modify: `lib/core/services/export/uddf/uddf_participant_writers.dart`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (parse every `<diverrole>`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (diver role list; accumulate per person)
- Modify: `lib/features/universal_import/data/services/payload_slicer.dart`
- Test: `test/core/services/export/uddf/uddf_diver_role_round_trip_test.dart`, `uddf_buddy_roles_round_trip_test.dart`, `uddf_dives_export_participants_test.dart`, `test/features/universal_import/data/services/payload_slicer_test.dart` (extend each); a new importer test `test/features/dive_import/data/services/uddf_entity_importer_roles_test.dart`

**Interfaces:**
- Produces: dive map key `diverRoleIds` (`List<String>`) replacing `diverRoleId`.

- [ ] **Step 1: Failing tests**

```dart
// uddf_diver_role_round_trip_test.dart
test('several diver roles round-trip, primary first', () async {
  // export a dive with diverRoleIds ['diveGuide', 'diveMaster']
  // expect the XML holds two <diverrole> elements in that order
  // import it; expect the imported dive's diverRoleIds equal the original.
});

// uddf_buddy_roles_round_trip_test.dart
test('a buddy with several roles round-trips exactly', () async {
  // buddy Ana roles [buddy, instructor] -> import -> [buddy, instructor]
  // buddy Ben roles [diveGuide, diveMaster] -> import -> the same
});

// uddf_dives_export_participants_test.dart
test('a person with any leader role goes in <divemaster> once', () {
  // rows: Ana [buddy, diveMaster]; Ben [buddy]
  // expect leaders() == [Ana]; plainBuddies() == [Ben]
});

// uddf_entity_importer_roles_test.dart
test('roles inferred from separate fields add up; Buddy drops out', () async {
  // diveData: buddyRefs [x], diveGuideRefs [x], no buddyRoleRefs
  // expect x's roles on the dive == ['diveGuide']
});
test('exact roles win over inferred ones', () async {
  // buddyRefs [x], buddyRoleRefs [{x, instructor}, {x, buddy}]
  // expect ['buddy', 'instructor']
});

// payload_slicer_test.dart
test('the slice keeps every custom diver role a dive names', () {
  // dive {'diverRoleIds': ['custom-1', 'diveMaster']}, metadata declares
  // custom-1 and custom-2; expect the slice declares custom-1 only.
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`buildDiverRole`:

```dart
  /// The logbook owner's own roles on [dive], one custom `<diverrole>`
  /// element each inside `informationbeforedive` (not UDDF standard), in
  /// DiveRoleSet order. An older reader takes the first, the primary role.
  static void buildDiverRole(XmlBuilder builder, Dive dive) {
    for (final roleId in dive.diverRoleIds) {
      if (roleId.isNotEmpty) builder.element('diverrole', nest: roleId);
    }
  }
```

`<buddyroles>` collection:

```dart
    final roleRows = <String, List<BuddyWithRole>>{
      for (final entry in (diveBuddies ?? const {}).entries)
        if (entry.value
                .where((b) => !listEquals(b.roleIds, const [DiveRole.buddyId]))
                .toList()
            case final rows when rows.isNotEmpty)
          entry.key: rows,
    };
```

and the writer emits one `<buddy ref role>` per id of `row.roleIds` (all of them, Buddy included when the set has more than one role, so the set round-trips exactly). Use `listEquals` from `package:flutter/foundation.dart` or `ListEquality` from collection.

`uddf_export_service.dart` custom roles: `for (final row in rows) ...row.roleIds,` and `for (final dive in dives) ...dive.diverRoleIds,`.

Participant writers:

```dart
  static List<BuddyWithRole> leaders(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (row.roleIds.any(DiveRole.leaderIds.contains)) row,
  ];

  static List<BuddyWithRole> plainBuddies(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (!row.roleIds.any(DiveRole.leaderIds.contains) &&
          !row.roleIds.contains(DiveRole.soloId))
        row,
  ];
```

Update the class doc ("a person and their roles"; "anyone holding a leader role").

Full import parse:

```dart
      final diverRoles = [
        for (final e in beforeElement.findElements('diverrole'))
          if (e.innerText.trim() case final id when id.isNotEmpty) id,
      ];
      if (diverRoles.isNotEmpty) diveData['diverRoleIds'] = diverRoles;
```

Importer, diver roles:

```dart
      final diverRoleValue = diveData['diverRoleIds'];
      final diverRoleIds = DiveRoleSet.normalize([
        if (diverRoleValue is List)
          for (final id in diverRoleValue.whereType<String>())
            if (id.isNotEmpty) ?await localRoleId(id),
      ]);
```

and `diverRoleIds: diverRoleIds,` in the `Dive(...)`.

Importer, `_linkBuddiesToDive`: collect instead of calling `addBuddyToDive` per source:

```dart
    final inferred = <String, List<String>>{};
    final exact = <String, List<String>>{};
    void infer(String buddyId, String roleId) =>
        inferred.putIfAbsent(buddyId, () => []).add(roleId);
```

each existing `addBuddyToDive(diveId, id, DiveRole.buddyId)` becomes `infer(id, DiveRole.buddyId)` (and `diveGuideId` likewise); the `<buddyroles>` loop becomes `exact.putIfAbsent(newBuddyId, () => []).add(await localRoleId(roleId) ?? DiveRole.buddyId);`. At the end:

```dart
    for (final buddyId in {...inferred.keys, ...exact.keys}) {
      final roles = exact.containsKey(buddyId)
          ? DiveRoleSet.normalizeBuddy(exact[buddyId]!)
          : DiveRoleSet.accumulate(inferred[buddyId]!);
      await repository.addBuddyToDive(diveId, buddyId, roles);
    }
```

Update the comment above the exact-roles block: exact roles now replace the inferred set for that person rather than overriding one row.

Payload slicer: `if (dive['diverRoleIds'] case final List ids) ...ids,` in place of `dive['diverRoleId'],`.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/core/services/export test/features/dive_import test/features/universal_import`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(file-export): carry several roles per person through UDDF and imports"
```

---

### Task 16: CSV, Excel, PADI and detailed PDF, signatures

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_participant_names.dart`
- Modify: `lib/core/services/pdf_templates/pdf_template_builder.dart`, `pdf_template_detailed.dart`, `pdf_template_simple.dart`, `pdf_template_padi.dart`, `pdf_template_naui.dart` (accept `diveRolesById`), `lib/core/services/export/pdf/pdf_export_service.dart`, `lib/core/services/export/export_service.dart` (pass through), and the PDF call sites in `lib/features/settings/presentation/providers/export_providers.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Modify: `lib/features/signatures/presentation/widgets/buddy_signatures_section.dart`, `buddy_signature_card.dart`, `buddy_signature_request_sheet.dart`
- Test: `test/features/dive_log/domain/services/dive_participant_names_test.dart`, the detailed PDF team-fields test (find with `grep -rln "teamFields\|_teamFields" test`), signature card test

**Interfaces:**
- Produces: `Map<String, DiveRole> diveRolesById = const {}` parameter on every `buildPdf` and export pass-through, beside `diveTypesById`.

- [ ] **Step 1: Failing tests**

```dart
// dive_participant_names_test.dart
test('anyone with a guide role is a dive master, never a buddy too', () {
  final dive = Dive(id: 'd', dateTime: DateTime(2026), buddies: [
    BuddyWithRole(buddy: ana, roles: [r('buddy'), r('diveGuide')]),
    BuddyWithRole(buddy: ben, roles: [r('buddy')]),
  ]);
  expect(dive.resolvedDiveMasterNames, 'Ana');
  expect(dive.resolvedBuddyNames, 'Ben');
});

// detailed PDF team fields
test('a buddy line joins their roles and the diver\'s own roles print',
    () {
  // dive.diverRoleIds ['diveGuide', 'diveMaster'], buddy Ana [instructor,
  // safetyDiver]; diveRolesById = built-ins.
  // expect fields include ('Instructor, Safety Diver', 'Ana') and
  // ('Dive Guide, Divemaster', <the Me label>).
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

Participant names: `.where((b) => b.roleIds.any(_guideRoleIds.contains) == guides)`.

Detailed PDF `_teamFields(Dive dive, AppLocalizations l10n, Map<String, DiveRole> diveRolesById)`:

```dart
      if (dive.diverRoleIds.isNotEmpty)
        _Field(
          rolesForIds(dive.diverRoleIds, diveRolesById).joinedLocalizedNames(l10n),
          l10n.buddies_picker_me,
        ),
      for (final buddy in dive.buddies)
        _Field(buddy.roles.joinedLocalizedNames(l10n), buddy.buddy.name),
```

Thread `diveRolesById` exactly as `diveTypesById` is threaded (same files, same positions; the base-class doc in `pdf_template_builder.dart` gets a line for it). At the three app call sites read it with `await ref.read(diveRoleMapProvider.future)` wrapped in a try/catch that falls back to `const {}` (mirror `diveTypesByIdOrEmpty`).

Signatures: `role: bwr.primaryRole.id` in `buddy_signatures_section.dart`; the card and request sheet show `buddyWithRole.roles.joinedLocalizedNames(context.l10n)`.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/core/services/export test/core/services/pdf_templates test/features/dive_log/domain test/features/signatures`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(file-export): print every role in exports and signature cards"
```

---

### Task 17: Role-in-use guard, usual role, connections subtitle

**Files:**
- Modify: `lib/features/dive_roles/data/repositories/dive_role_repository.dart` (`isDiveRoleInUse`)
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (`getAllBuddiesWithDiveCount` role counts)
- Modify: `lib/features/connections/data/connections_node_sql.dart`, `lib/features/connections/data/connections_reader.dart` (find with `grep -rln "buildBuddyRoleSql" lib`)
- Test: `test/features/dive_roles/data/repositories/dive_role_repository_test.dart`, `test/features/buddies/data/repositories/buddy_repository_test.dart` (usual role), `test/features/connections/data/connections_sql_test.dart`

- [ ] **Step 1: Failing tests**

```dart
test('a role held only in a junction row is in use', () async {
  // custom role c1 owned by diver v; dive d (diver v) with
  // diverRoleIds [diveMaster, c1]; isDiveRoleInUse('c1') == true.
  // buddy link with roles [buddy, c2] on d; isDiveRoleInUse('c2') == true.
});

test('usual role counts every role a buddy held', () async {
  // Ana: d1 [diveGuide, diveMaster], d2 [diveMaster]
  // getAllBuddiesWithDiveCount -> Ana.usualRoleId == 'diveMaster'
});

test('connections subtitle: one role held on every dive', () async {
  // Ana: d1 [diveGuide, diveMaster], d2 [diveMaster] -> subtitle diveMaster
  // Ben: d1 [diveGuide, diveMaster], d2 [diveGuide, diveMaster] -> none
  //      (two roles are on every dive, so no single one stands for Ben)
  // Cy:  d1 [instructor], d2 [student] -> none
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`isDiveRoleInUse` adds two terms (a junction row counts as a reference; over-counting a stale row is the safe side of a deletion guard):

```dart
            '(SELECT COUNT(*) FROM dive_buddy_roles WHERE role_id = ?1 '
            'AND (?2 IS NULL OR dive_id NOT IN ($otherDiversDives))) + '
            '(SELECT COUNT(*) FROM dive_diver_roles r JOIN dives d '
            'ON d.id = r.dive_id WHERE r.role_id = ?1 '
            'AND (?2 IS NULL OR d.diver_id IS NULL OR d.diver_id = ?2)) + '
```

Update its doc: "any dive_buddies row, dive_buddy_roles row, dives.diver_role or dive_diver_roles row".

Usual role: replace the second whole-table query with resolved sets:

```dart
      final linkRows = await _db.select(_db.diveBuddies).get();
      final sets = await _roleLinks.buddyRoleIdsForDives(
        {for (final r in linkRows) r.diveId}.toList(),
      );
      final roleCountsByBuddy = <String, Map<String, int>>{};
      for (final perDive in sets.values) {
        for (final entry in perDive.entries) {
          final counts = roleCountsByBuddy.putIfAbsent(entry.key, () => {});
          for (final roleId in entry.value) {
            counts.update(roleId, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }
```

(For very large libraries `isIn` over every dive id may exceed SQLite's variable limit; check how `getBuddiesForDives` handles big lists and chunk the same way, or add a whole-table variant `allBuddyRoleIds()` to `DiveRoleLinkRepository` that reads both tables without a filter. Prefer the whole-table variant here; add a test for it in Task 5's file.)

Connections: change `buildBuddyRoleSql` to return each in-scope (buddy, dive, scalar role) plus the junction rows, and pick in Dart:

```sql
SELECT db.buddy_id AS id, db.dive_id AS dive_id, db.role AS role
FROM dive_buddies db
JOIN dives d ON d.id = db.dive_id
WHERE <scope> AND db.buddy_id IN (...)
```

then in the reader load `buddyRoleRowsForDives` for those dive ids, resolve each (dive, buddy) with `DiveRoleSet.resolveBuddy`, and keep a buddy's subtitle only when exactly one role id appears in every one of their in-scope dives' sets. Update the function's doc comment and the SQL test's expected SQL.

- [ ] **Step 4: Run tests, expect PASS.** `flutter test test/features/dive_roles test/features/buddies test/features/connections`

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(buddies): count every role in usual-role and role-in-use checks"
```

---

### Task 18: Sweep, full verification

**Files:** any remaining `primaryRole` / `firstOrNull` stopgaps from Task 4.

- [ ] **Step 1: Find stopgaps**

Run: `grep -rn "primaryRole\|diverRoleIds.firstOrNull" lib`
Expected: only `BuddyWithRole.primaryRole` uses that genuinely want the primary (signature storage, scalar writes). Convert any display or logic site still reading one role to the set.

- [ ] **Step 2: Insights solo detection check.** Confirm `insights_repository.dart` still compares `d.diver_role = 'solo'` and add one test to `test/features/insights/data/repositories/solo_vs_buddy_count_test.dart`: a dive written through `DiveRoleLinkRepository.writeDiverRoles(d, ['solo'])` counts as solo, and one written with `['solo', 'instructor']` does not (Solo was dropped on write).

- [ ] **Step 3: Legacy buddy-text conversion check.** `collapseLinks` in `lib/features/buddies/domain/services/legacy_conversion_planner.dart` already turns a person named in both the buddy and the dive master text into one Dive Master link, which is what `DiveRoleSet.accumulate` gives. Pin it: add a test to the planner's test file asserting `planLegacyConversion(buddyText: 'Ana', diveMasterText: 'Ana', ...)` yields one link for Ana with `DiveRole.diveMasterId`, and that `buddy_conversion_repository.dart` writes it through `addBuddyToDive` or `writeBuddyRoles` so the junction is in step (if it inserts `dive_buddies` directly with `role:`, the read rule already resolves it to that single role; no change needed).

- [ ] **Step 4: Full verification**

```bash
dart format .
flutter analyze
flutter test test/architecture/
flutter test
```

Expected: zero analyzer issues; all tests pass. (Run the full suite once, per the repo's testing notes; check `df -h /Volumes/fltmp` first if a run hangs.)

- [ ] **Step 5: Commit** (if the sweep changed anything)

```bash
git add lib test
git commit -m "fix(dive-roles): read role sets everywhere a single role was read"
```
