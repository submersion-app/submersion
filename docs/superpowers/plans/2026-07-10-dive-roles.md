# Dive Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Custom per-dive roles (#551) and recording the active diver's own role on a dive (#547), backed by a new `dive_roles` reference table.

**Architecture:** A `dive_roles` table mirrors the proven `dive_types` pattern (seeded built-ins + user-defined rows, HLC sync, Settings management page). `BuddyWithRole.role` changes from the `BuddyRole` enum to a `DiveRole` entity resolved from the table; `dives` gains a nullable `diver_role` column for the diver's own role, surfaced as a pinned "Me" chip in the Buddies card.

**Tech Stack:** Flutter, Drift ORM (build_runner codegen), Riverpod, go_router, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-10-dive-roles-design.md`

## Global Constraints

- All work happens in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-roles`. Run every command from that directory. Never `cd` to the main checkout.
- Migration is **v103** (`currentSchemaVersion` goes 102 -> 103). Append `103,` to `migrationVersions`.
- The new Drift table class is `DiveRoles` with `@DataClassName('DiveRoleRow')` — the row class MUST be `DiveRoleRow` because the domain entity is named `DiveRole` and an unrelated `BuddyRoleRow` already exists.
- Built-in role ids are the legacy `BuddyRole` enum `.name` strings plus three new ones: `buddy`, `diveGuide`, `instructor`, `student`, `diveMaster`, `solo`, `rearGuard`, `supportDiver`, `safetyDiver`. Custom role ids are UUID v4 (NOT name-derived slugs — renames must not break references).
- Custom roles are always created with the active diver's `diverId` (a `diverId`-null custom row is invisible — known orphan trap).
- **`.role.name` trap:** after the type change, `bwr.role.name` still compiles but returns the display name, not the id. Every write-site must use `.role.id`. The sites are enumerated in Task 5.
- After any change to `lib/core/database/database.dart` tables, run `dart run build_runner build --delete-conflicting-outputs` before compiling/testing.
- After any `.arb` change, run `flutter gen-l10n`. Every new key goes into `app_en.arb` AND all 10 other locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`). Dutch `rearGuard` MUST be "Hekkensluiter".
- No emojis anywhere. `dart format .` (whole repo) before each commit. `flutter analyze` on the whole project — never pipe through `head`/`tail`.
- Run tests per-file (`flutter test <file>`), not the whole suite (timeout risk).
- Commit at the end of each task with the message given in the task. Do not add Co-Authored-By lines.

---

### Task 1: Schema v103 — `dive_roles` table, seed, `dives.diver_role` column

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_v103_dive_roles_test.dart` (new)

**Interfaces:**
- Produces: Drift table getter `_db.diveRoles` (row class `DiveRoleRow`, companion `DiveRolesCompanion` with columns `id, diverId, name, isBuiltIn, sortOrder, createdAt, updatedAt, hlc`), `Dives` column getter `diverRole` (`row.diverRole`, `DivesCompanion(diverRole: ...)`), constant `kSeedBuiltInDiveRolesSql`, `AppDatabase.currentSchemaVersion == 103`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v103_dive_roles_test.dart`. Mirror the structure of `test/core/database/migration_v99_buddy_roles_test.dart` (fresh-schema test, real-onUpgrade test, backstop test). Content:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('v103 dive_roles migration', () {
    test('fresh database has dive_roles with 9 built-in seeds and '
        'dives.diver_role column', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      final seeds = await db.customSelect(
        'SELECT id, name, is_built_in, sort_order FROM dive_roles '
        'ORDER BY sort_order',
      ).get();
      expect(seeds.length, 9);
      expect(
        seeds.map((r) => r.read<String>('id')).toList(),
        [
          'buddy', 'diveGuide', 'instructor', 'student', 'diveMaster',
          'solo', 'rearGuard', 'supportDiver', 'safetyDiver',
        ],
      );
      expect(seeds.every((r) => r.read<int>('is_built_in') == 1), isTrue);

      final diveCols =
          await db.customSelect("PRAGMA table_info('dives')").get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );
    });

    test('real onUpgrade from v102 creates dive_roles, seeds built-ins, '
        'and adds dives.diver_role preserving rows', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 102');
          // Minimal v102-shaped dives table: only the columns this test and
          // the beforeOpen index backstops touch. If ensurePerformanceIndexes
          // fails on a missing column, add that column here.
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT PRIMARY KEY NOT NULL,
              diver_id TEXT,
              dive_date_time INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              buddy TEXT,
              hlc TEXT
            )
          ''');
          rawDb.execute(
            "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
            "VALUES ('d1', 1000, 1000, 1000)",
          );
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final seeds =
          await db.customSelect('SELECT id FROM dive_roles').get();
      expect(seeds.length, 9);

      final diveCols =
          await db.customSelect("PRAGMA table_info('dives')").get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );

      final rows = await db.customSelect(
        'SELECT id, diver_role FROM dives',
      ).get();
      expect(rows.length, 1);
      expect(rows.single.read<String?>('diver_role'), isNull);
    });

    test('beforeOpen backstop heals a database already at '
        'currentSchemaVersion that is missing the v103 objects', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT PRIMARY KEY NOT NULL,
              diver_id TEXT,
              dive_date_time INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              buddy TEXT,
              hlc TEXT
            )
          ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final seeds =
          await db.customSelect('SELECT id FROM dive_roles').get();
      expect(seeds.length, 9);
      final diveCols =
          await db.customSelect("PRAGMA table_info('dives')").get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );
    });

    test('version ladder includes 103', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(103));
      expect(AppDatabase.migrationVersions, contains(103));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v103_dive_roles_test.dart`
Expected: FAIL (`dive_roles` table does not exist / version 103 missing).

- [ ] **Step 3: Add the table, seed constant, and column to `database.dart`**

3a. Immediately after the `DiveTypes` table class (which ends at line ~1408), add:

```dart
/// Per-dive role vocabulary: built-in + custom (v103, issues #551/#547).
/// Built-in ids are the legacy BuddyRole enum names so existing
/// dive_buddies.role strings resolve without data migration; custom ids
/// are UUIDs so renames never break references.
@DataClassName('DiveRoleRow')
class DiveRoles extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-in roles
  TextColumn get name => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

3b. Near `kSeedBuiltInDiveTypesSql` (declared at lines ~1465-1487; mirror its exact style), add:

```dart
/// Seeds the nine built-in dive roles. INSERT OR IGNORE keeps it idempotent;
/// re-asserted in beforeOpen like the dive-type seed.
const kSeedBuiltInDiveRolesSql = '''
  INSERT OR IGNORE INTO dive_roles
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT s.id, s.name, 1, s.sort_order, t.now, t.now
  FROM (
    SELECT 'buddy' AS id, 'Buddy' AS name, 0 AS sort_order
    UNION ALL SELECT 'diveGuide', 'Dive Guide', 1
    UNION ALL SELECT 'instructor', 'Instructor', 2
    UNION ALL SELECT 'student', 'Student', 3
    UNION ALL SELECT 'diveMaster', 'Divemaster', 4
    UNION ALL SELECT 'solo', 'Solo', 5
    UNION ALL SELECT 'rearGuard', 'Rear Guard', 6
    UNION ALL SELECT 'supportDiver', 'Support Diver', 7
    UNION ALL SELECT 'safetyDiver', 'Safety Diver', 8
  ) s
  CROSS JOIN (
    SELECT CAST(strftime('%s', 'now') AS INTEGER) * 1000 AS now
  ) t
''';
```

(If `kSeedBuiltInDiveTypesSql` computes its timestamp differently, copy that exact idiom instead.)

3c. In the `Dives` table class (line ~383; `buddy` column is at line ~402), add next to `buddy`:

```dart
  /// The active diver's own role on this dive (dive_roles id, #547).
  TextColumn get diverRole => text().nullable()();
```

3d. Register `DiveRoles,` in the `@DriftDatabase(tables: [...])` list (near `DiveTypes,` at line ~1980).

3e. Add `'dive_roles',` to the `_hlcTables` list (lines ~2151-2178, near `'dive_types',`).

3f. Bump the version: `static const int currentSchemaVersion = 103;` (line ~2036) and append `103,` to `migrationVersions` (ends at line ~2141).

3g. In `onCreate` (after the dive-types seed call at line ~2308), add:

```dart
        await customStatement(kSeedBuiltInDiveRolesSql);
```

3h. In `onUpgrade`, after the `if (from < 102)` block (lines ~4981-4984), add:

```dart
        if (from < 103) {
          // Dive roles vocabulary (#551) + the diver's own role (#547).
          // createTable is IF NOT EXISTS and the seed is INSERT OR IGNORE,
          // so this block is idempotent; beforeOpen re-asserts the same
          // objects against schema-version collisions.
          await m.createTable(diveRoles);
          await customStatement(kSeedBuiltInDiveRolesSql);
          final diveCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final hasDiverRole = diveCols.any(
            (c) => c.read<String>('name') == 'diver_role',
          );
          if (!hasDiverRole) {
            await customStatement(
              'ALTER TABLE dives ADD COLUMN diver_role TEXT',
            );
          }
        }
        if (from < 103) await reportProgress();
```

3i. In `beforeOpen` (lines ~4986-5054), after the existing v100 backstop `createTable` calls, add:

```dart
        // v103 backstop: dive_roles + built-in seed + dives.diver_role.
        await createMigrator().createTable(diveRoles);
        await customStatement(kSeedBuiltInDiveRolesSql);
        final divesCols = await customSelect(
          "PRAGMA table_info('dives')",
        ).get();
        final hasDiverRoleCol = divesCols.any(
          (c) => c.read<String>('name') == 'diver_role',
        );
        if (divesCols.isNotEmpty && !hasDiverRoleCol) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN diver_role TEXT',
          );
        }
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, `lib/core/database/database.g.dart` regenerated with `DiveRoleRow`.

- [ ] **Step 5: Run the migration test to verify it passes**

Run: `flutter test test/core/database/migration_v103_dive_roles_test.dart`
Expected: PASS (4 tests). If the onUpgrade test fails inside `ensurePerformanceIndexes` on a missing `dives` column, add that column to the fixture DDL in both fixture tests and re-run.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): add dive_roles table and dives.diver_role column (v103)"
```

---

### Task 2: `DiveRole` entity, repository, providers

**Files:**
- Create: `lib/features/dive_roles/domain/entities/dive_role.dart`
- Create: `lib/features/dive_roles/data/repositories/dive_role_repository.dart`
- Create: `lib/features/dive_roles/presentation/providers/dive_role_providers.dart`
- Test: `test/features/dive_roles/data/repositories/dive_role_repository_test.dart` (new)

**Interfaces:**
- Consumes: `_db.diveRoles` / `DiveRoleRow` / `DiveRolesCompanion` (Task 1).
- Produces:
  - `class DiveRole` with `String id`, `String? diverId`, `String name`, `bool isBuiltIn`, `int sortOrder`, `DateTime createdAt`, `DateTime updatedAt`, `copyWith`, static id constants (`DiveRole.buddyId` ... `DiveRole.safetyDiverId`), `static const List<String> builtInIds`, `factory DiveRole.synthetic(String slug)`, `factory DiveRole.builtInBuddy()`.
  - `DiveRole mapDiveRoleRow(DiveRoleRow row)` (top-level, exported from the repository file).
  - `class DiveRoleRepository` with `watchDiveRolesChanges()`, `getAllDiveRoles({String? diverId})`, `getDiveRoleById(String id)`, `createDiveRole({required String name, required String diverId})`, `renameDiveRole(String id, String newName)`, `deleteDiveRole(String id)`, `isDiveRoleInUse(String id)`.
  - Providers: `diveRoleRepositoryProvider`, `allDiveRolesProvider` (`FutureProvider<List<DiveRole>>`), `diveRoleMapProvider` (`FutureProvider<Map<String, DiveRole>>`), `diveRoleListNotifierProvider` with notifier methods `addDiveRoleByName(String name)`, `renameDiveRole(String id, String name)`, `deleteDiveRole(String id)`, `isDiveRoleInUse(String id)`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/dive_roles/data/repositories/dive_role_repository_test.dart`. Follow the setup pattern of `test/features/tags/data/repositories/tag_repository_test.dart` (uses `setUpTestDatabase()` / `tearDownTestDatabase()` from `test/helpers/test_database.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

Future<String> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  return 'diver-1';
}

void main() {
  late DiveRoleRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRoleRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('DiveRoleRepository', () {
    test('getAllDiveRoles returns 9 built-ins ordered built-in-first '
        'by sortOrder', () async {
      final roles = await repository.getAllDiveRoles();
      expect(roles.length, 9);
      expect(roles.first.id, DiveRole.buddyId);
      expect(roles.map((r) => r.id).toList(), DiveRole.builtInIds);
      expect(roles.every((r) => r.isBuiltIn), isTrue);
    });

    test('createDiveRole creates a custom role with a UUID id scoped to '
        'the diver, listed after built-ins', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      expect(created.isBuiltIn, isFalse);
      expect(created.diverId, diverId);
      expect(DiveRole.builtInIds, isNot(contains(created.id)));
      expect(created.id.length, 36); // uuid v4

      final roles = await repository.getAllDiveRoles(diverId: diverId);
      expect(roles.length, 10);
      expect(roles.last.id, created.id);
    });

    test('custom roles of another diver are not returned', () async {
      final diverId = await _insertDiver();
      await repository.createDiveRole(name: 'Scooter Pilot', diverId: diverId);
      final roles = await repository.getAllDiveRoles(diverId: 'other-diver');
      expect(roles.length, 9);
    });

    test('renameDiveRole renames a custom role and keeps its id', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      await repository.renameDiveRole(created.id, 'Sweep');
      final fetched = await repository.getDiveRoleById(created.id);
      expect(fetched!.name, 'Sweep');
    });

    test('renameDiveRole throws for built-in roles', () async {
      expect(
        () => repository.renameDiveRole(DiveRole.buddyId, 'X'),
        throwsException,
      );
    });

    test('deleteDiveRole throws for built-in roles', () async {
      expect(
        () => repository.deleteDiveRole(DiveRole.buddyId),
        throwsException,
      );
    });

    test('deleteDiveRole removes an unused custom role', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      await repository.deleteDiveRole(created.id);
      expect(await repository.getDiveRoleById(created.id), isNull);
    });

    test('isDiveRoleInUse reflects dive_buddies.role and dives.diver_role '
        'references', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      expect(await repository.isDiveRoleInUse(created.id), isFalse);

      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at, "
        "diver_role) VALUES ('d1', 1000, 1000, 1000, '${created.id}')",
      );
      expect(await repository.isDiveRoleInUse(created.id), isTrue);

      await db.customStatement("DELETE FROM dives WHERE id = 'd1'");
      expect(await repository.isDiveRoleInUse(created.id), isFalse);

      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
        "VALUES ('d2', 1000, 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO buddies (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Bud', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (id, dive_id, buddy_id, role) "
        "VALUES ('db1', 'd2', 'b1', '${created.id}')",
      );
      expect(await repository.isDiveRoleInUse(created.id), isTrue);
    });
  });
}
```

Note: check the real `divers`/`buddies`/`dive_buddies` column lists with `PRAGMA table_info` if an insert fails (e.g. NOT NULL columns without defaults) and extend the insert statements accordingly.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_roles/data/repositories/dive_role_repository_test.dart`
Expected: FAIL (files do not exist / compile error).

- [ ] **Step 3: Write the entity**

Create `lib/features/dive_roles/domain/entities/dive_role.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A per-dive role (built-in or user-defined) from the dive_roles table.
/// Built-in ids are the legacy BuddyRole enum names; custom ids are UUIDs.
class DiveRole extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final bool isBuiltIn;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveRole({
    required this.id,
    this.diverId,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String buddyId = 'buddy';
  static const String diveGuideId = 'diveGuide';
  static const String instructorId = 'instructor';
  static const String studentId = 'student';
  static const String diveMasterId = 'diveMaster';
  static const String soloId = 'solo';
  static const String rearGuardId = 'rearGuard';
  static const String supportDiverId = 'supportDiver';
  static const String safetyDiverId = 'safetyDiver';

  /// Built-in ids in seed sortOrder. Must match kSeedBuiltInDiveRolesSql.
  static const List<String> builtInIds = [
    buddyId,
    diveGuideId,
    instructorId,
    studentId,
    diveMasterId,
    soloId,
    rearGuardId,
    supportDiverId,
    safetyDiverId,
  ];

  /// Placeholder for a role id with no dive_roles row (legacy or
  /// not-yet-synced data). Displays the raw slug instead of silently
  /// renaming it to Buddy.
  factory DiveRole.synthetic(String slug) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return DiveRole(id: slug, name: slug, createdAt: epoch, updatedAt: epoch);
  }

  /// The default role, used where legacy code assumed BuddyRole.buddy.
  factory DiveRole.builtInBuddy() {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return DiveRole(
      id: buddyId,
      name: 'Buddy',
      isBuiltIn: true,
      createdAt: epoch,
      updatedAt: epoch,
    );
  }

  DiveRole copyWith({
    String? id,
    String? diverId,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveRole(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    isBuiltIn,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
```

- [ ] **Step 4: Write the repository**

Create `lib/features/dive_roles/data/repositories/dive_role_repository.dart`. Model imports, logger, `SyncRepository` usage, and error style on `lib/features/dive_types/data/repositories/dive_type_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Maps a Drift row to the domain entity. Shared with BuddyRepository.
DiveRole mapDiveRoleRow(DiveRoleRow row) {
  return DiveRole(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    isBuiltIn: row.isBuiltIn,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

class DiveRoleRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveRoleRepository);

  Stream<void> watchDiveRolesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveRoles));

  /// Built-ins plus the given diver's custom roles, built-ins first,
  /// each group ordered by sortOrder then name.
  Future<List<DiveRole>> getAllDiveRoles({String? diverId}) async {
    final query = _db.select(_db.diveRoles)
      ..where(
        (t) => t.isBuiltIn.equals(true) | _customForDiver(t, diverId),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.isBuiltIn),
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
      ]);
    final rows = await query.get();
    return rows.map(mapDiveRoleRow).toList();
  }

  Expression<bool> _customForDiver(
    $DiveRolesTable t,
    String? diverId,
  ) {
    if (diverId == null) return t.isBuiltIn.equals(false);
    return t.isBuiltIn.equals(false) & t.diverId.equals(diverId);
  }

  Future<DiveRole?> getDiveRoleById(String id) async {
    final row = await (_db.select(
      _db.diveRoles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapDiveRoleRow(row);
  }

  Future<DiveRole> createDiveRole({
    required String name,
    required String diverId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxSortOrder =
        await (_db.selectOnly(_db.diveRoles)
              ..addColumns([_db.diveRoles.sortOrder.max()]))
            .map((r) => r.read(_db.diveRoles.sortOrder.max()))
            .getSingle() ??
        0;
    await _db
        .into(_db.diveRoles)
        .insert(
          DiveRolesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: name.trim(),
            isBuiltIn: const Value(false),
            sortOrder: Value(maxSortOrder + 1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'diveRoles',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    _log.info('Created custom dive role $id ($name)');
    final created = await getDiveRoleById(id);
    return created!;
  }

  Future<void> renameDiveRole(String id, String newName) async {
    final existing = await getDiveRoleById(id);
    if (existing == null) {
      throw Exception('Dive role not found: $id');
    }
    if (existing.isBuiltIn) {
      throw Exception('Cannot update built-in dive roles');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.diveRoles)..where((t) => t.id.equals(id))).write(
      DiveRolesCompanion(name: Value(newName.trim()), updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveRoles',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> deleteDiveRole(String id) async {
    final existing = await getDiveRoleById(id);
    if (existing == null) return;
    if (existing.isBuiltIn) {
      throw Exception('Cannot delete built-in dive roles');
    }
    await (_db.delete(_db.diveRoles)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: 'diveRoles', recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// True when any dive_buddies row or dives.diver_role references [id].
  Future<bool> isDiveRoleInUse(String id) async {
    final result = await _db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM dive_buddies WHERE role = ?1) + '
          '(SELECT COUNT(*) FROM dives WHERE diver_role = ?1) AS uses',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return (result.read<int>('uses')) > 0;
  }
}
```

Exact API details (e.g. `markRecordPending` named params, `LoggerService.forClass`) must match `dive_type_repository.dart` — copy from there if signatures differ.

- [ ] **Step 5: Write the providers**

Create `lib/features/dive_roles/presentation/providers/dive_role_providers.dart`, modeled line-for-line on `lib/features/dive_types/presentation/providers/dive_type_providers.dart` (same imports, same `validatedCurrentDiverIdProvider` + `invalidateSelfWhen` idiom, same notifier shape):

```dart
final diveRoleRepositoryProvider = Provider<DiveRoleRepository>((ref) {
  return DiveRoleRepository();
});

/// Built-ins + current diver's custom roles; refreshes on table changes.
final allDiveRolesProvider = FutureProvider<List<DiveRole>>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(diveRoleRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDiveRolesChanges());
  return repository.getAllDiveRoles(diverId: diverId);
});

/// id -> DiveRole lookup for cheap display resolution.
final diveRoleMapProvider = FutureProvider<Map<String, DiveRole>>((ref) async {
  final roles = await ref.watch(allDiveRolesProvider.future);
  return {for (final role in roles) role.id: role};
});

class DiveRoleListNotifier
    extends StateNotifier<AsyncValue<List<DiveRole>>> {
  // Mirror DiveTypeListNotifier: constructor (repository, ref), diver-change
  // listener, watchDiveRolesChanges subscription, _load method.

  Future<DiveRole> addDiveRoleByName(String name) async {
    final diverId = _ref.read(currentDiverIdProvider);
    if (diverId == null) {
      throw Exception('No active diver');
    }
    final created = await _repository.createDiveRole(
      name: name,
      diverId: diverId,
    );
    await _load();
    return created;
  }

  Future<void> renameDiveRole(String id, String name) async {
    await _repository.renameDiveRole(id, name);
    await _load();
  }

  Future<void> deleteDiveRole(String id) async {
    await _repository.deleteDiveRole(id);
    await _load();
  }

  Future<bool> isDiveRoleInUse(String id) =>
      _repository.isDiveRoleInUse(id);
}

final diveRoleListNotifierProvider = StateNotifierProvider.autoDispose<
  DiveRoleListNotifier,
  AsyncValue<List<DiveRole>>
>((ref) {
  ref.watch(currentDiverIdProvider);
  return DiveRoleListNotifier(ref.watch(diveRoleRepositoryProvider), ref);
});
```

Copy the notifier scaffolding (constructor body, listeners, `_load`) verbatim from `DiveTypeListNotifier` (lines 68-201 of `dive_type_providers.dart`), renaming types.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/dive_roles/data/repositories/dive_role_repository_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): DiveRole entity, repository, and providers"
```

---

### Task 3: l10n strings and localized display extension

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`
- Create: `lib/features/dive_roles/presentation/dive_role_display.dart`

**Interfaces:**
- Consumes: `DiveRole` (Task 2).
- Produces: `extension DiveRoleDisplay on DiveRole { String localizedName(AppLocalizations l10n); }` and l10n getters: `diveRole_builtin_buddy` ... `diveRole_builtin_safetyDiver`, `diveRoles_appBar_title`, `diveRoles_addTooltip`, `diveRoles_builtInHeader`, `diveRoles_customHeader`, `diveRoles_addDialog_title`, `diveRoles_addDialog_nameLabel`, `diveRoles_addDialog_nameHint`, `diveRoles_addDialog_nameValidation`, `diveRoles_addDialog_addButton`, `diveRoles_renameDialog_title`, `diveRoles_deleteDialog_title`, `diveRoles_deleteDialog_content(name)`, `diveRoles_deleteTooltip`, `diveRoles_renameTooltip`, `diveRoles_snackbar_added(name)`, `diveRoles_snackbar_deleted(name)`, `diveRoles_snackbar_cannotDelete(name)`, `diveRoles_snackbar_errorAdding(error)`, `settings_manage_diveRoles`, `settings_manage_diveRoles_subtitle`, `buddies_picker_addCustomRole`, `buddies_picker_noRole`, `buddies_picker_me`, `buddies_picker_setMyRole`, `buddies_picker_selectMyRole`.

- [ ] **Step 1: Add English strings**

In `lib/l10n/arb/app_en.arb`, keys sort alphabetically within the file's existing grouping conventions. Add (placeholder metadata style copied from `@diveTypes_deleteDialog_content` at lines ~4140-4146):

```json
  "buddies_picker_addCustomRole": "Add custom role...",
  "buddies_picker_me": "Me",
  "buddies_picker_noRole": "No role",
  "buddies_picker_selectMyRole": "Select my role",
  "buddies_picker_setMyRole": "Set my role",

  "diveRole_builtin_buddy": "Buddy",
  "diveRole_builtin_diveGuide": "Dive Guide",
  "diveRole_builtin_diveMaster": "Divemaster",
  "diveRole_builtin_instructor": "Instructor",
  "diveRole_builtin_rearGuard": "Rear Guard",
  "diveRole_builtin_safetyDiver": "Safety Diver",
  "diveRole_builtin_solo": "Solo",
  "diveRole_builtin_student": "Student",
  "diveRole_builtin_supportDiver": "Support Diver",

  "diveRoles_addDialog_addButton": "Add",
  "diveRoles_addDialog_nameHint": "e.g., Photographer",
  "diveRoles_addDialog_nameLabel": "Dive Role Name",
  "diveRoles_addDialog_nameValidation": "Please enter a name",
  "diveRoles_addDialog_title": "Add Custom Dive Role",
  "diveRoles_addTooltip": "Add dive role",
  "diveRoles_appBar_title": "Dive Roles",
  "diveRoles_builtInHeader": "Built-in Dive Roles",
  "diveRoles_customHeader": "Custom Dive Roles",
  "diveRoles_deleteDialog_content": "Are you sure you want to delete \"{name}\"?",
  "@diveRoles_deleteDialog_content": {
    "placeholders": { "name": { "type": "Object" } }
  },
  "diveRoles_deleteDialog_title": "Delete Dive Role?",
  "diveRoles_deleteTooltip": "Delete dive role",
  "diveRoles_renameDialog_title": "Rename Dive Role",
  "diveRoles_renameTooltip": "Rename dive role",
  "diveRoles_snackbar_added": "Added dive role: {name}",
  "@diveRoles_snackbar_added": {
    "placeholders": { "name": { "type": "Object" } }
  },
  "diveRoles_snackbar_cannotDelete": "Cannot delete \"{name}\" - it is used by existing dives",
  "@diveRoles_snackbar_cannotDelete": {
    "placeholders": { "name": { "type": "Object" } }
  },
  "diveRoles_snackbar_deleted": "Deleted dive role: {name}",
  "@diveRoles_snackbar_deleted": {
    "placeholders": { "name": { "type": "Object" } }
  },
  "diveRoles_snackbar_errorAdding": "Error adding dive role: {error}",
  "@diveRoles_snackbar_errorAdding": {
    "placeholders": { "error": { "type": "Object" } }
  },

  "settings_manage_diveRoles": "Dive Roles",
  "settings_manage_diveRoles_subtitle": "Manage custom dive roles"
```

- [ ] **Step 2: Translate into the 10 other locales**

Add every key above to each of `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb` with proper translations (match each file's existing tone; reuse each locale's existing translations of "Buddy", "Dive Guide", "Instructor", "Student", "Divemaster", "Solo" from the diveTypes/buddies sections where present). MANDATORY: in `app_nl.arb`, `"diveRole_builtin_rearGuard": "Hekkensluiter"`.

- [ ] **Step 3: Regenerate localizations and verify compilation**

Run: `flutter gen-l10n`
Expected: exits 0.
Run: `flutter analyze lib/l10n`
Expected: no new errors.

- [ ] **Step 4: Write the display extension**

Create `lib/features/dive_roles/presentation/dive_role_display.dart`:

```dart
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

extension DiveRoleDisplay on DiveRole {
  /// Localized name for built-in roles; stored name for custom/synthetic.
  String localizedName(AppLocalizations l10n) {
    if (!isBuiltIn) return name;
    return switch (id) {
      DiveRole.buddyId => l10n.diveRole_builtin_buddy,
      DiveRole.diveGuideId => l10n.diveRole_builtin_diveGuide,
      DiveRole.instructorId => l10n.diveRole_builtin_instructor,
      DiveRole.studentId => l10n.diveRole_builtin_student,
      DiveRole.diveMasterId => l10n.diveRole_builtin_diveMaster,
      DiveRole.soloId => l10n.diveRole_builtin_solo,
      DiveRole.rearGuardId => l10n.diveRole_builtin_rearGuard,
      DiveRole.supportDiverId => l10n.diveRole_builtin_supportDiver,
      DiveRole.safetyDiverId => l10n.diveRole_builtin_safetyDiver,
      _ => name,
    };
  }
}
```

(Check the actual import path for `AppLocalizations` in an existing widget — e.g. `buddy_picker.dart` imports `package:submersion/l10n/l10n_extension.dart`; the class import used by non-widget files may differ.)

- [ ] **Step 5: Verify and commit**

Run: `flutter analyze`
Expected: no new issues.

```bash
dart format .
git add -A
git commit -m "feat(roles): dive role l10n strings and localized display"
```

---

### Task 4: Sync wiring for `dive_roles`

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (~line 47)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (multiple switch sites)
- Test: `test/core/services/sync/sync_dive_roles_test.dart` (new)

**Interfaces:**
- Consumes: `_db.diveRoles`, entity key string `'diveRoles'` (already emitted by `DiveRoleRepository` in Task 2).
- Produces: `SyncData.diveRoles` (`List<Map<String, dynamic>>`), full sync export/import/tombstone support for `'diveRoles'`.

- [ ] **Step 1: Write the failing sync test**

Create `test/core/services/sync/sync_dive_roles_test.dart`, modeled on `test/core/services/sync/sync_buddy_roles_test.dart` (same `setUpTestDatabase` harness, same hand-built row maps + `hlcAt` helper — copy those helpers from that file):

```dart
// imports and hlcAt/row helpers copied from sync_buddy_roles_test.dart

Map<String, dynamic> diveRoleRow(
  String id, {
  required String hlc,
  bool isBuiltIn = false,
  String name = 'Hekkensluiter',
  String? diverId,
}) {
  return {
    'id': id,
    'diver_id': diverId,
    'name': name,
    'is_built_in': isBuiltIn,
    'sort_order': 20,
    'created_at': 1000,
    'updated_at': 1000,
    'hlc': hlc,
  };
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('export includes a custom dive_roles row', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord(
      'diveRoles',
      diveRoleRow('role-1', hlc: hlcAt(1000, 'dev-a')),
    );
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    final ids = payload.data.diveRoles.map((r) => r['id']).toSet();
    expect(ids, contains('role-1'));
  });

  test('export skips built-in dive roles', () async {
    final serializer = SyncDataSerializer();
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    // The 9 seeded built-ins must not appear in the payload.
    expect(payload.data.diveRoles, isEmpty);
  });

  test('deleteAllRecords preserves built-in dive roles', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord(
      'diveRoles',
      diveRoleRow('role-1', hlc: hlcAt(1000, 'dev-a')),
    );
    await serializer.deleteAllRecords('diveRoles');
    final db = DatabaseService.instance.database;
    final rows = await db.customSelect('SELECT id FROM dive_roles').get();
    final ids = rows.map((r) => r.read<String>('id')).toSet();
    expect(ids, isNot(contains('role-1')));
    expect(ids.length, 9); // built-ins survive
  });

  test('tombstone deleteRecord removes a custom dive role', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord(
      'diveRoles',
      diveRoleRow('role-1', hlc: hlcAt(1000, 'dev-a')),
    );
    await serializer.deleteRecord('diveRoles', 'role-1');
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          "SELECT id FROM dive_roles WHERE id = 'role-1'",
        )
        .get();
    expect(rows, isEmpty);
  });
}
```

Match method names (`exportData`, `upsertRecord`, `deleteAllRecords`, `deleteRecord`) to what `sync_buddy_roles_test.dart` actually calls — adjust if the harness differs.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/sync_dive_roles_test.dart`
Expected: FAIL (`diveRoles` not a field on SyncData / unknown entityType).

- [ ] **Step 3: Register the HLC target in `sync_repository.dart`**

In the `_hlcTargets` map (near line 47, next to `'diveTypes'`):

```dart
    'diveRoles': (table: 'dive_roles', pk: 'id'),
```

- [ ] **Step 4: Wire the serializer**

In `lib/core/services/sync/sync_data_serializer.dart`, mirror the `diveTypes` handling at EVERY site (search for `diveTypes` and add the `diveRoles` analog beside each occurrence):

1. `SyncData` class: field `final List<Map<String, dynamic>> diveRoles;` (near line 246), constructor default `this.diveRoles = const [],` (near 296), `toJson` entry `'diveRoles': diveRoles,` (near 347), `fromJson` entry `diveRoles: _parseList(json['diveRoles']),` (near 399).
2. Base-table export registry (lines ~610-621): add

```dart
    (
      key: 'diveRoles',
      table: null,
      blob: false,
      full: () => _exportDiveRoles(null),
    ),
```

3. `_buildSyncData` (near lines 997-1004): add `diveRoles: await _exportDiveRoles(hlcSince),` following the `_exportDiveTypes(hlcSince)` call pattern.
4. New exporter next to `_exportDiveTypes` (lines ~3409-3420):

```dart
  Future<List<Map<String, dynamic>>> _exportDiveRoles(String? hlcSince) async {
    // Built-in dive roles are re-seeded identically on every device, so
    // syncing them only risks collisions and payload bloat. Custom only.
    final query = _db.select(_db.diveRoles)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

5. `fetchRecord` switch (line ~1177) and `fetchRecords` (line ~1459): add `case 'diveRoles':` mirroring the `diveTypes` cases (lines 1350-1354 / 1550-1554), using `_db.diveRoles`.
6. `upsertRecord` (line ~1641): add mirroring lines 1839-1843:

```dart
      case 'diveRoles':
        await _db
            .into(_db.diveRoles)
            .insertOnConflictUpdate(
              DiveRoleRow.fromJson(data).toCompanion(false),
            );
        return;
```

7. `upsertRecords` batch (line ~1969): mirror the diveTypes batch case (lines 2280-2286) with `DiveRoleRow.fromJson(r).toCompanion(false)`.
8. `recordIdsFor` / `plain(...)` cases (near 2538): add the `diveRoles` case beside `diveTypes`.
9. `deleteAllRecords` (line ~2622): mirror the built-in-preserving diveTypes branch (lines 2628-2632):

```dart
    if (entityType == 'diveRoles') {
      await (_db.delete(
        _db.diveRoles,
      )..where((t) => t.isBuiltIn.equals(false))).go();
      return;
    }
```

(match the actual code shape of the diveTypes branch — it may be a switch case rather than an if).
10. `_syncTableFor` (line ~2649): `'diveRoles' => _db.diveRoles,` beside the diveTypes mapping.
11. `deleteRecord` tombstone apply (near 2917): add the diveRoles delete mirroring diveTypes.

Note: `.toCompanion(false)` is correct here — dive_roles is an HLC entity (memory: `.toCompanion(false)` on HLC entities only).

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/sync_dive_roles_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Run neighboring sync tests to catch regressions**

Run: `flutter test test/core/services/sync/sync_buddy_roles_test.dart test/core/services/sync/sync_builtin_reference_data_test.dart test/core/services/sync/sync_serializer_upsert_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): sync dive_roles (custom rows only, tombstones, adopt-safe)"
```

---

### Task 5: Switch `BuddyWithRole.role` to `DiveRole` across all consumers

**Files:**
- Modify: `lib/features/buddies/domain/entities/buddy.dart:101-110`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (327-366, 371-417, 422-456, 516-562, 589-629)
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3205-3214`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:3684`
- Modify: `lib/features/signatures/presentation/widgets/buddy_signature_card.dart:74`, `buddy_signature_request_sheet.dart:85`, `buddy_signatures_section.dart:154`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:105-116`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1744,1756-1760,1775,1789`
- Modify/Test: `test/features/buddies/data/repositories/buddy_repository_test.dart` and every test file listed in Step 8

**Interfaces:**
- Consumes: `DiveRole`, `DiveRole.synthetic`, `DiveRole.builtInBuddy`, `mapDiveRoleRow`, `DiveRoleDisplay.localizedName`, `allDiveRolesProvider` (Tasks 2-3).
- Produces: `BuddyWithRole { Buddy buddy; DiveRole role; }`; `BuddyRepository.addBuddyToDive(String diveId, String buddyId, String roleId)` (role param is now a String id); all role persistence uses `.role.id`.

**THE `.role.name` TRAP:** `DiveRole.name` is the display name. Every persistence site must write `.role.id`. The complete list of sites that previously wrote `.role.name`:
`buddy_repository.dart` lines 400, 440, 456, 534, 549, 617 and `buddy_signatures_section.dart` line 154. Convert ALL of them to `.id` / `roleId`.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/buddies/data/repositories/buddy_repository_test.dart` (adapt insert helpers to the file's existing ones):

```dart
group('dive role resolution', () {
  test('getBuddiesForDive resolves built-in role ids to DiveRole entities',
      () async {
    // ... insert dive d1 and buddy b1 using this file's existing helpers ...
    await repository.addBuddyToDive('d1', 'b1', DiveRole.diveGuideId);
    final result = await repository.getBuddiesForDive('d1');
    expect(result.single.role.id, DiveRole.diveGuideId);
    expect(result.single.role.isBuiltIn, isTrue);
    expect(result.single.role.name, 'Dive Guide');
  });

  test('getBuddiesForDive resolves custom roles and keeps unknown slugs '
      'as synthetic roles', () async {
    final roleRepo = DiveRoleRepository();
    final custom = await roleRepo.createDiveRole(
      name: 'Hekkensluiter',
      diverId: 'diver-1', // insert diver first with the file's helper
    );
    await repository.addBuddyToDive('d1', 'b1', custom.id);
    var result = await repository.getBuddiesForDive('d1');
    expect(result.single.role.name, 'Hekkensluiter');

    // Unknown slug: written directly, must surface as synthetic, not Buddy.
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "UPDATE dive_buddies SET role = 'mysterySlug' WHERE dive_id = 'd1'",
    );
    result = await repository.getBuddiesForDive('d1');
    expect(result.single.role.id, 'mysterySlug');
    expect(result.single.role.name, 'mysterySlug');
  });

  test('setBuddiesForDive persists the role id, not the display name',
      () async {
    final buddy = /* build Buddy entity as this file does */;
    await repository.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: buddy, role: DiveRole.builtInBuddy()),
    ]);
    final db = DatabaseService.instance.database;
    final row = await db
        .customSelect("SELECT role FROM dive_buddies WHERE dive_id = 'd1'")
        .getSingle();
    expect(row.read<String>('role'), 'buddy'); // id, NOT 'Buddy'
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_test.dart`
Expected: FAIL (compile error: `DiveRole` not the role type yet).

- [ ] **Step 3: Change the entity**

In `lib/features/buddies/domain/entities/buddy.dart` replace lines 101-110:

```dart
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Buddy with role for a specific dive
class BuddyWithRole extends Equatable {
  final Buddy buddy;
  final DiveRole role;

  const BuddyWithRole({required this.buddy, required this.role});

  @override
  List<Object?> get props => [buddy, role];
}
```

Remove the now-unused `enums.dart` import if `BuddyRole` is no longer referenced in this file.

- [ ] **Step 4: Update `buddy_repository.dart`**

4a. `getBuddiesForDive` (327-367): replace the enum parse (362-365) with table resolution:

```dart
    // Resolve role ids against dive_roles; unknown slugs stay visible as
    // synthetic roles instead of silently coercing to Buddy.
    final roleRows = await _db.select(_db.diveRoles).get();
    final rolesById = {
      for (final r in roleRows) r.id: mapDiveRoleRow(r),
    };
    return results.map((row) {
      final buddy = domain.Buddy( /* unchanged */ );
      final roleId = (row.data['role'] as String?) ?? DiveRole.buddyId;
      final role = rolesById[roleId] ?? DiveRole.synthetic(roleId);
      return domain.BuddyWithRole(buddy: buddy, role: role);
    }).toList();
```

Move the `roleRows` fetch BEFORE the `results.map(...)` (the map callback is synchronous).

4b. `setBuddiesForDive` line 400: `role: Value(buddyWithRole.role.name)` -> `role: Value(buddyWithRole.role.id)`.

4c. `addBuddyToDive` (422-456): change the signature to accept the id string:

```dart
  Future<void> addBuddyToDive(
    String diveId,
    String buddyId,
    String roleId,
  ) async {
```

and lines 440/456: `Value(role.name)` -> `Value(roleId)`.

4d. `bulkAddBuddies` lines 534, 549 and `bulkReplaceBuddies` line 617: `bwr.role.name` -> `bwr.role.id`.

Add imports: `package:submersion/features/dive_roles/domain/entities/dive_role.dart` and `package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart` (for `mapDiveRoleRow`).

- [ ] **Step 5: Update the read-only display consumers**

Each of these swaps `role.displayName` for `role.localizedName(context.l10n)` and adds imports of `dive_role_display.dart` (and `l10n_extension.dart` where missing):

- `dive_detail_page.dart:3684`: `subtitle: Text(bwr.role.displayName)` -> `subtitle: Text(bwr.role.localizedName(context.l10n))`.
- `buddy_signature_card.dart:74`: `buddyWithRole.role.displayName` -> `buddyWithRole.role.localizedName(context.l10n)`.
- `buddy_signature_request_sheet.dart:85`: `widget.buddyWithRole.role.displayName` -> `widget.buddyWithRole.role.localizedName(context.l10n)`.
- `buddy_signatures_section.dart:154`: `role: bwr.role.name` -> `role: bwr.role.id` (this one PERSISTS into the signature record — id, not display name).

- [ ] **Step 6: Update `buddy_picker.dart` (provider-driven roles, mechanical)**

- `_BuddyChip` field (line 134): `ValueChanged<BuddyRole> onRoleChanged` -> `ValueChanged<DiveRole> onRoleChanged`; chip subtitle (162): `buddyWithRole.role.displayName` -> `buddyWithRole.role.localizedName(context.l10n)`.
- `_BuddyChip._showRoleSelector` (175-215): convert `_BuddyChip` usage so the role list comes from the parent. Simplest mechanical change: make `BuddyPicker.build` watch the provider and pass it down:

```dart
    final roles =
        ref.watch(allDiveRolesProvider).value ?? <DiveRole>[];
```

pass `roles: roles` into `_BuddyChip`, add `final List<DiveRole> roles;` to `_BuddyChip`, and in `_showRoleSelector` replace `...BuddyRole.values.map((role) {` with `...roles.map((role) {`, `isSelected` compare by `role.id == buddyWithRole.role.id`, `title: Text(role.localizedName(context.l10n))`.
- `_BuddySelectionSheet._addBuddy` (499): parameter `BuddyRole role` -> `DiveRole role`.
- `_showRoleSelectorForBuddy` (520-564): the sheet is a `ConsumerState`, so read roles there:

```dart
    final roles =
        ref.read(allDiveRolesProvider).value ?? <DiveRole>[];
    final credentialRoleIds = credentials.map((c) => c.role.name).toSet();
    final orderedRoles = [
      ...roles.where((r) => credentialRoleIds.contains(r.id)),
      ...roles.where((r) => !credentialRoleIds.contains(r.id)),
    ];
```

(`c.role` is still the `BuddyRole` credential enum; `.name` gives the slug, matched against `DiveRole.id`.) Update `leading:` icon check to `credentialRoleIds.contains(role.id)` and `title: Text(role.localizedName(context.l10n))`.
- Trailing chip (471): `selectedRole?.displayName ?? 'Buddy'` -> `selectedRole?.localizedName(context.l10n) ?? context.l10n.diveRole_builtin_buddy`.
- Imports: add `dive_role.dart`, `dive_role_providers.dart`, `dive_role_display.dart`; remove the `enums.dart` import if unused (still used by `BuddyRoleCredential`? that type lives in its own file — verify).

- [ ] **Step 7: Update remaining compile sites**

- `dive_edit_page.dart:3205-3214` (bulk-edit helper `_buddyWithRole`): `role: BuddyRole.buddy` -> `role: DiveRole.builtInBuddy()`; adjust the helper's types and add the `dive_role.dart` import.
- `uddf_export_builders.dart:105-116`: replace the enum bucketing:

```dart
    // Leaders map to UDDF leader elements; every other role (including
    // custom roles) exports as a plain buddy. Solo exports as neither.
    const leaderRoleIds = {
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
      DiveRole.instructorId,
    };
    final regularBuddies = diveBuddyList
        .where(
          (b) =>
              !leaderRoleIds.contains(b.role.id) &&
              b.role.id != DiveRole.soloId,
        )
        .toList();
    final guidesAndDivemasters = diveBuddyList
        .where((b) => leaderRoleIds.contains(b.role.id))
        .toList();
```

- `uddf_entity_importer.dart` lines 1744, 1756-1760, 1775, 1789: `BuddyRole.buddy` -> `DiveRole.buddyId`, `BuddyRole.diveGuide` -> `DiveRole.diveGuideId` (the repository now takes the id string). Update imports.
- `buddy_merge_repository.dart`: NO changes needed — it handles raw `role` strings (`_roleRank` at lines 98-107 is keyed on the same slug strings; custom roles rank 0 via `?? 0`). Verify it still compiles.
- Run `flutter analyze` and fix any remaining `BuddyRole`-as-dive-role compile errors the same way (display -> `localizedName`, persistence -> `.id`). Do NOT touch `BuddyRoleCredential`, `buddy_roles_editor.dart`, `instructor_picker_field.dart`, or `kProfessionalBuddyRoles` — the credentials system keeps the enum.

- [ ] **Step 8: Update affected tests**

Fix compilation in the test files that construct `BuddyWithRole(role: BuddyRole.x)` or call `addBuddyToDive(..., BuddyRole.x)` — replace with `DiveRole` fixtures. Useful fixture helper (add per file or in `test/helpers/`):

```dart
DiveRole builtInRole(String id, String name, int sortOrder) => DiveRole(
      id: id,
      name: name,
      isBuiltIn: true,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
```

Files (from exploration; `flutter analyze` is the authoritative list):
`test/features/buddies/data/repositories/buddy_repository_test.dart`, `buddy_repository_bulk_test.dart`, `buddy_merge_test.dart`, `test/features/buddies/presentation/widgets/buddy_picker_test.dart`, `buddy_picker_roles_test.dart`, `test/features/dive_log/data/repositories/dive_repository_test.dart`, `bulk_dive_edit_service_test.dart`, `bulk_membership_wiring_test.dart`, `dive_detail_page_section_config_test.dart`, `test/features/dive_import/data/services/uddf_entity_importer_test.dart`, `test/integration/uddf_test_importer.dart`, `test/integration/uddf_round_trip_test.dart`.
Widget tests that render the picker now need `allDiveRolesProvider` overridden:

```dart
allDiveRolesProvider.overrideWith(
  (ref) async => DiveRole.builtInIds
      .asMap()
      .entries
      .map((e) => builtInRole(e.value, e.value, e.key))
      .toList(),
),
```

(Credential-ordering tests in `buddy_picker_roles_test.dart` compare by id — keep their assertions, adjust types.)

- [ ] **Step 9: Verify**

Run: `flutter analyze`
Expected: no errors.
Run: `flutter test test/features/buddies test/features/dive_import test/core/services/export/uddf test/integration/uddf_round_trip_test.dart`
Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): resolve per-dive buddy roles from dive_roles table"
```

---

### Task 6: `Dive.diverRoleId` plumbing

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (constructor ~164, copyWith params ~530, copyWith body ~618, props ~708)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (companions at ~863 and ~1106; mappers at ~2613 and ~2965)
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart` (~326)
- Test: `test/features/dive_log/data/repositories/dive_repository_test.dart` (add case)
- Test: `test/features/dive_log/domain/services/dive_merge_builder_diver_role_test.dart` (new)

**Interfaces:**
- Consumes: `dives.diver_role` column (Task 1).
- Produces: `Dive.diverRoleId` (`String?`), persisted via create/update, mapped on read, adopted first-non-null during dive consolidation merges.

- [ ] **Step 1: Write the failing tests**

6a. In `test/features/dive_log/data/repositories/dive_repository_test.dart`, add (following the file's existing create/read pattern):

```dart
test('diverRoleId round-trips through create, read, and update', () async {
  final dive = /* build a minimal Dive as this file's other tests do */
      .copyWith(diverRoleId: 'rearGuard');
  final id = await repository.createDive(dive);
  var loaded = await repository.getDiveById(id);
  expect(loaded!.diverRoleId, 'rearGuard');

  await repository.updateDive(loaded.copyWith(diverRoleId: 'instructor'));
  loaded = await repository.getDiveById(id);
  expect(loaded!.diverRoleId, 'instructor');
});
```

(If the file constructs `Dive(...)` directly, add `diverRoleId: 'rearGuard'` as a named arg instead of copyWith. Match the file's real repository method names — check whether `createDive` returns the id or the dive.)

6b. Create `test/features/dive_log/domain/services/dive_merge_builder_diver_role_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
// import dive.dart and dive_merge_builder.dart with the same paths the
// existing dive_merge_builder tests use (check test/features/dive_log/
// domain/services/ for an existing _test.dart to copy setup from).

void main() {
  test('merge adopts diverRoleId from the first dive that has one', () {
    // Build two minimal Dive fixtures the same way the existing
    // dive_merge_builder test builds them: primary with diverRoleId null,
    // secondary with diverRoleId 'rearGuard'. Run the builder's build()
    // and expect mergedDive.diverRoleId == 'rearGuard'.
  });
}
```

Copy fixture construction verbatim from the existing merge-builder test file (find it with `ls test/features/dive_log/domain/services/`), then assert `merged.diverRoleId == 'rearGuard'`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_test.dart test/features/dive_log/domain/services/dive_merge_builder_diver_role_test.dart`
Expected: FAIL (no `diverRoleId` member).

- [ ] **Step 3: Add the field to the `Dive` entity**

In `lib/features/dive_log/domain/entities/dive.dart`:
- Field, next to `buddy`/`diveMaster` (lines 49-50): `final String? diverRoleId;`
- Constructor (after `this.diveMaster,` at line ~164): `this.diverRoleId,`
- copyWith params (after `String? diveMaster,` at ~530): `String? diverRoleId,`
- copyWith body (after `diveMaster: ...` at ~618): `diverRoleId: diverRoleId ?? this.diverRoleId,`
- props (near `buddy` at ~708): add `diverRoleId,`

(No null-clear sentinel exists in this entity; clearing the role on save works because the edit page constructs `Dive(...)` directly, not via copyWith.)

- [ ] **Step 4: Persist and map in `dive_repository_impl.dart`**

- create companion (line ~863, beside `buddy: Value(dive.buddy),`): `diverRole: Value(dive.diverRoleId),`
- update companion (line ~1106): `diverRole: Value(dive.diverRoleId),`
- `_mapRowToDiveWithPreloadedData` (line ~2613, beside `buddy: row.buddy,`): `diverRoleId: row.diverRole,`
- `_mapRowToDive` (line ~2965): `diverRoleId: row.diverRole,`

- [ ] **Step 5: Adopt in the merge builder**

In `lib/features/dive_log/domain/services/dive_merge_builder.dart`, in the `Dive(` construction (lines 303-382), beside `buddy:`/`diveMaster:` (326-327):

```dart
      diverRoleId: _firstNonNull(sorted, (d) => d.diverRoleId),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_test.dart test/features/dive_log/domain/services/dive_merge_builder_diver_role_test.dart`
Expected: PASS. (Sync of the new column is automatic — `_exportDives` uses generated `toJson`; no serializer edits needed.)

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): persist the diver's own role on dives (#547)"
```

---

### Task 7: Role selector sheet with custom-role creation + "Me" chip in BuddyPicker

**Files:**
- Create: `lib/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- Test: `test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart` (new)
- Test: `test/features/buddies/presentation/widgets/buddy_picker_me_chip_test.dart` (new)

**Interfaces:**
- Consumes: `allDiveRolesProvider`, `diveRoleMapProvider`, `diveRoleListNotifierProvider`, `DiveRoleDisplay`, `currentDiverProvider` (`FutureProvider<Diver?>` from `lib/features/divers/presentation/providers/diver_providers.dart:178`).
- Produces:
  - `class DiveRoleSelection { final DiveRole? role; }` (role null = explicit "No role")
  - `Future<DiveRoleSelection?> showDiveRoleSelector(BuildContext context, {required String title, required List<DiveRole> roles, Set<String> credentialRoleIds, bool allowNone, String? selectedRoleId, Future<DiveRole?> Function(String name)? onCreateCustomRole})` — returns null when cancelled.
  - `BuddyPicker` gains optional `String? diverRoleId` and `ValueChanged<String?>? onDiverRoleChanged` (Me chip renders only when `onDiverRoleChanged != null`).

- [ ] **Step 1: Write the failing selector-sheet widget test**

Create `test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart`. Use the harness style of `test/features/buddies/presentation/widgets/buddy_picker_test.dart` (ProviderScope + MaterialApp + AppLocalizations delegates + a button that opens the sheet):

```dart
// Fixtures: three built-in roles + one custom role via the builtInRole
// helper pattern from Task 5, plus:
// DiveRole custom = DiveRole(id: 'uuid-1', name: 'Hekkensluiter',
//     diverId: 'diver-1', sortOrder: 9, createdAt: ..., updatedAt: ...);

testWidgets('lists roles in order and returns the tapped role', (tester) async {
  DiveRoleSelection? result;
  // pump harness whose button calls:
  // result = await showDiveRoleSelector(context,
  //     title: 'Select role', roles: fixtures);
  // tap button, pumpAndSettle, tap 'Hekkensluiter', pumpAndSettle
  expect(result!.role!.id, 'uuid-1');
});

testWidgets('shows No role entry when allowNone and returns null role',
    (tester) async {
  // open with allowNone: true; tap the 'No role' tile
  // expect result!.role, isNull  (selection made, role cleared)
});

testWidgets('Add custom role flow creates and returns the new role',
    (tester) async {
  // open with onCreateCustomRole: (name) async => custom.copyWith(name: name);
  // tap 'Add custom role...', enter 'Scooter Pilot' in the dialog,
  // tap Add; expect result!.role!.name == 'Scooter Pilot'
});

testWidgets('credential roles float to the top with premium icon',
    (tester) async {
  // open with credentialRoleIds: {'instructor'};
  // expect the first ListTile is Instructor and has Icons.workspace_premium
});
```

Write these as real tests (full pump harness code copied from `buddy_picker_test.dart`'s `_buildPicker`/`_openSheet` helpers).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the selector sheet**

Create `lib/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// Result wrapper distinguishing "cancelled" (showDiveRoleSelector returns
/// null) from "explicitly chose no role" (DiveRoleSelection(null)).
class DiveRoleSelection {
  final DiveRole? role;
  const DiveRoleSelection(this.role);
}

Future<DiveRoleSelection?> showDiveRoleSelector(
  BuildContext context, {
  required String title,
  required List<DiveRole> roles,
  Set<String> credentialRoleIds = const {},
  bool allowNone = false,
  String? selectedRoleId,
  Future<DiveRole?> Function(String name)? onCreateCustomRole,
}) {
  final orderedRoles = [
    ...roles.where((r) => credentialRoleIds.contains(r.id)),
    ...roles.where((r) => !credentialRoleIds.contains(r.id)),
  ];
  return showModalBottomSheet<DiveRoleSelection>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            if (allowNone)
              ListTile(
                leading: Icon(
                  selectedRoleId == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(ctx.l10n.buddies_picker_noRole),
                onTap: () =>
                    Navigator.pop(ctx, const DiveRoleSelection(null)),
              ),
            ...orderedRoles.map(
              (role) => ListTile(
                leading: Icon(
                  credentialRoleIds.contains(role.id)
                      ? Icons.workspace_premium
                      : role.id == selectedRoleId
                      ? Icons.radio_button_checked
                      : Icons.person,
                ),
                title: Text(role.localizedName(ctx.l10n)),
                onTap: () => Navigator.pop(ctx, DiveRoleSelection(role)),
              ),
            ),
            if (onCreateCustomRole != null)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(ctx.l10n.buddies_picker_addCustomRole),
                onTap: () async {
                  final created =
                      await _showAddCustomRoleDialog(ctx, onCreateCustomRole);
                  if (created != null && ctx.mounted) {
                    Navigator.pop(ctx, DiveRoleSelection(created));
                  }
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

Future<DiveRole?> _showAddCustomRoleDialog(
  BuildContext context,
  Future<DiveRole?> Function(String name) onCreate,
) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.diveRoles_addDialog_title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: ctx.l10n.diveRoles_addDialog_nameLabel,
          hintText: ctx.l10n.diveRoles_addDialog_nameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(ctx, value);
          },
          child: Text(ctx.l10n.diveRoles_addDialog_addButton),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return null;
  return onCreate(name);
}
```

(Verify `common_action_cancel` exists in app_en.arb; if the codebase uses a different key for Cancel, use that one. Dispose of the controller via `addTearDown`-equivalent pattern used elsewhere, or convert the dialog to a small StatefulWidget matching `dive_types_page.dart`'s add dialog.)

- [ ] **Step 4: Run the sheet test to verify it passes**

Run: `flutter test test/features/dive_roles/presentation/widgets/dive_role_selector_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing Me-chip test**

Create `test/features/buddies/presentation/widgets/buddy_picker_me_chip_test.dart` (harness copied from `buddy_picker_test.dart`, plus overrides for `allDiveRolesProvider`, `diveRoleMapProvider` dependencies, and `currentDiverProvider.overrideWith((ref) async => Diver(id: 'diver-1', name: 'Eric G', ...))` — build the `Diver` fixture with that entity's required fields):

```dart
testWidgets('Me chip hidden when onDiverRoleChanged is null', (tester) async {
  // pump BuddyPicker(selectedBuddies: [], onChanged: (_) {})
  expect(find.text('Me'), findsNothing);
});

testWidgets('Me chip shows Set my role when diverRoleId is null',
    (tester) async {
  // pump BuddyPicker(..., diverRoleId: null, onDiverRoleChanged: (_) {})
  expect(find.text('Me'), findsOneWidget);
  expect(find.text('Set my role'), findsOneWidget);
});

testWidgets('tapping Me chip opens selector; choosing a role calls '
    'onDiverRoleChanged with its id', (tester) async {
  String? changed = 'sentinel';
  // pump with onDiverRoleChanged: (v) => changed = v
  // tap the Me chip, pumpAndSettle, tap 'Rear Guard'
  expect(changed, 'rearGuard');
});

testWidgets('choosing No role calls onDiverRoleChanged(null)', (tester) async {
  // diverRoleId: 'rearGuard'; tap Me chip, tap 'No role'
  // expect changed, isNull
});
```

- [ ] **Step 6: Run to verify failure, then add the Me chip to `BuddyPicker`**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_picker_me_chip_test.dart` — expect FAIL.

In `buddy_picker.dart`:

7a. Add fields + constructor params:

```dart
  /// The active diver's own role id (#547). The Me chip renders only when
  /// [onDiverRoleChanged] is provided (the bulk-edit surface passes null).
  final String? diverRoleId;
  final ValueChanged<String?>? onDiverRoleChanged;
```

7b. In `build`, render the chip as the first child of the `Wrap` (and also show it in the empty state by moving the empty-state check to consider only buddies but still show the Me chip above it — simplest: render a `Wrap` containing `[if (onDiverRoleChanged != null) _MeChip(...), ...buddyChips]` and keep the empty-state container only when `selectedBuddies.isEmpty && onDiverRoleChanged == null`; when buddies are empty but the Me chip is shown, render the Wrap with just the Me chip followed by the existing empty-state hint text).

7c. New private widget in the same file:

```dart
class _MeChip extends ConsumerWidget {
  final String? diverRoleId;
  final ValueChanged<String?> onChanged;

  const _MeChip({required this.diverRoleId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diver = ref.watch(currentDiverProvider).value;
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final role = diverRoleId == null ? null : rolesById[diverRoleId!];
    final roleLabel = diverRoleId == null
        ? context.l10n.buddies_picker_setMyRole
        : (role ?? DiveRole.synthetic(diverRoleId!))
              .localizedName(context.l10n);
    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          size: 14,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(diver?.name ?? context.l10n.buddies_picker_me),
          Text(
            roleLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () async {
        final roles =
            ref.read(allDiveRolesProvider).value ?? const <DiveRole>[];
        final selection = await showDiveRoleSelector(
          context,
          title: context.l10n.buddies_picker_selectMyRole,
          roles: roles,
          allowNone: true,
          selectedRoleId: diverRoleId,
        );
        if (selection != null) {
          onChanged(selection.role?.id);
        }
      },
    );
  }
}
```

Test-harness note: the chip's title shows the diver's name when `currentDiverProvider` resolves one, falling back to the localized "Me". In the Me-chip tests, override `currentDiverProvider.overrideWith((ref) async => null)` so the fallback "Me" label renders and `find.text('Me')` matches.

7d. Rewire the two existing role sheets to `showDiveRoleSelector` (deleting `_BuddyChip._showRoleSelector`'s inline sheet and `_showRoleSelectorForBuddy`'s inline sheet):

```dart
  // _BuddyChip.onPressed:
  onPressed: () async {
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectRole(buddyWithRole.buddy.name),
      roles: roles,
      selectedRoleId: buddyWithRole.role.id,
      onCreateCustomRole: onCreateCustomRole,
    );
    if (selection?.role != null) onRoleChanged(selection!.role!);
  },
```

and in `_BuddySelectionSheetState`:

```dart
  void _showRoleSelectorForBuddy(
    BuildContext context,
    Buddy buddy,
    List<BuddyRoleCredential> credentials,
  ) async {
    final roles = ref.read(allDiveRolesProvider).value ?? const <DiveRole>[];
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectRole(buddy.name),
      roles: roles,
      credentialRoleIds: credentials.map((c) => c.role.name).toSet(),
      onCreateCustomRole: _createCustomRole,
    );
    if (selection?.role != null) _addBuddy(buddy, selection!.role!);
  }

  Future<DiveRole?> _createCustomRole(String name) async {
    try {
      return await ref
          .read(diveRoleListNotifierProvider.notifier)
          .addDiveRoleByName(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveRoles_snackbar_errorAdding(e)),
          ),
        );
      }
      return null;
    }
  }
```

`BuddyPicker` (the chip row) also needs a `_createCustomRole` equivalent — since `BuddyPicker` is a `ConsumerWidget`, define the callback inline in `build` using `ref` and pass it to `_BuddyChip` as `onCreateCustomRole`.

- [ ] **Step 7: Run picker tests to verify everything passes**

Run: `flutter test test/features/buddies/presentation/widgets/`
Expected: PASS (including the pre-existing picker tests updated in Task 5).

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): role selector with custom-role creation and Me chip"
```

---

### Task 8: Dive edit page save path + dive detail page Me row

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state ~165, `_loadExistingDive` ~700, `_buildBuddiesSection` ~3986-4001, `Dive(...)` construction ~4388-4489)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildBuddiesSection` ~3614-3668)

**Interfaces:**
- Consumes: `BuddyPicker.diverRoleId`/`onDiverRoleChanged` (Task 7), `Dive.diverRoleId` (Task 6), `diveRoleMapProvider`, `DiveRoleDisplay`.
- Produces: my-role editing end-to-end; detail page "Me" row.

- [ ] **Step 1: Wire the edit page**

1a. State (next to `_selectedBuddies` at line ~165):

```dart
  String? _diverRoleId;
```

1b. `_loadExistingDive` (in the block at ~700 where buddies load):

```dart
        _diverRoleId = dive.diverRoleId;
```

(`dive` here is the loaded `_existingDive` — match the local variable name used in that method.)

1c. `_buildBuddiesSection` (~3986-4001):

```dart
      child: BuddyPicker(
        diveId: widget.diveId,
        selectedBuddies: _selectedBuddies,
        diverRoleId: _diverRoleId,
        onDiverRoleChanged: (roleId) {
          _markDirty();
          setState(() => _diverRoleId = roleId);
        },
        onChanged: (buddies) {
          _markDirty();
          setState(() => _selectedBuddies = buddies);
        },
      ),
```

1d. The `Dive(...)` construction in `_saveDive` (lines 4388-4489): add `diverRoleId: _diverRoleId,` next to where other simple fields are passed (any position in the named-arg list works; put it near `diveType`-related args for readability).

Note the bulk-edit surface in this same file does NOT get a Me chip (it passes no `onDiverRoleChanged`, so the chip stays hidden there).

- [ ] **Step 2: Wire the detail page**

In `_buildBuddiesSection` (3614-3668): the tiles are emitted via `...buddies.map((bwr) => _buildBuddyTile(context, bwr))` at line ~3654. Insert a Me row before them when the dive has a role. The section needs access to the `dive` object and a `WidgetRef` — this page is a Consumer page; match how sibling sections access `dive` (pass it as a parameter if the method doesn't already have it):

```dart
            if (dive.diverRoleId != null) _buildMyRoleTile(context, ref, dive),
            ...buddies.map((bwr) => _buildBuddyTile(context, bwr)),
```

```dart
  Widget _buildMyRoleTile(BuildContext context, WidgetRef ref, Dive dive) {
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final role =
        rolesById[dive.diverRoleId!] ?? DiveRole.synthetic(dive.diverRoleId!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(context.l10n.buddies_picker_me),
      subtitle: Text(role.localizedName(context.l10n)),
    );
  }
```

Also handle the case where the dive has a `diverRoleId` but no buddies: the section currently may render nothing when the buddy list is empty — check the surrounding emptiness condition (~3614-3630) and extend it so the section renders when `buddies.isNotEmpty || dive.diverRoleId != null`.

- [ ] **Step 3: Verify end-to-end**

Run: `flutter analyze`
Expected: no errors.
Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart test/features/buddies/presentation/widgets/`
Expected: PASS.

Manual smoke (deferred to final verification if no device available): edit a dive, set "My role" to Rear Guard, save, confirm the detail page shows "Me — Rear Guard", re-open edit and clear it via "No role".

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): my-role editing on dive edit page and detail display"
```

---

### Task 9: Dive Roles management page, route, Settings entry

**Files:**
- Create: `lib/features/dive_roles/presentation/pages/dive_roles_page.dart`
- Modify: `lib/core/router/app_router.dart` (import near line 102, route near lines 975-980)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Manage Data card, after the Dive Types tile at lines 1626-1635)
- Test: `test/features/dive_roles/presentation/pages/dive_roles_page_test.dart` (new)

**Interfaces:**
- Consumes: `diveRoleListNotifierProvider` (Task 2), l10n keys (Task 3).
- Produces: `/dive-roles` route with `DiveRolesPage`.

- [ ] **Step 1: Write the failing page test**

Create `test/features/dive_roles/presentation/pages/dive_roles_page_test.dart`. Override `diveRoleListNotifierProvider` with a notifier stub or override its dependencies (`diveRoleRepositoryProvider` + `currentDiverIdProvider`) backed by the in-memory DB via `setUpTestDatabase()` — prefer the DB-backed approach, matching how `dive_types` page tests do it if such a test exists (check `test/features/dive_types/`; if a page test exists there, mirror it exactly):

```dart
testWidgets('shows built-in section with 9 localized roles and no delete '
    'affordance on built-ins', (tester) async {
  // pump DiveRolesPage with the DB-backed providers
  expect(find.text('Built-in Dive Roles'), findsOneWidget);
  expect(find.text('Rear Guard'), findsOneWidget);
});

testWidgets('add dialog creates a custom role listed under Custom',
    (tester) async {
  // requires an active diver in the test DB (insert divers row and set
  // current diver the way the dive_types page test does)
  // tap FAB, type 'Hekkensluiter', tap Add
  expect(find.text('Hekkensluiter'), findsOneWidget);
});

testWidgets('deleting an in-use custom role is blocked with a snackbar',
    (tester) async {
  // seed a custom role + a dive with diver_role = its id (raw SQL),
  // tap its delete icon
  expect(
    find.textContaining('used by existing dives'),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_roles/presentation/pages/dive_roles_page_test.dart`
Expected: FAIL (page does not exist).

- [ ] **Step 3: Implement the page**

Create `lib/features/dive_roles/presentation/pages/dive_roles_page.dart` as a structural clone of `lib/features/dive_types/presentation/pages/dive_types_page.dart` (251 lines), with these substitutions:
- `DiveTypesPage` -> `DiveRolesPage`, `diveTypeListNotifierProvider` -> `diveRoleListNotifierProvider`, `DiveTypeEntity` -> `DiveRole`.
- All `diveTypes_*` l10n keys -> the `diveRoles_*` keys from Task 3.
- Built-in tiles display `role.localizedName(context.l10n)` (import `dive_role_display.dart`); custom tiles display `role.name`.
- Add dialog calls `addDiveRoleByName(result)`.
- Delete flow: `isDiveRoleInUse` -> blocked snackbar `diveRoles_snackbar_cannotDelete(role.name)`; else confirm dialog -> `deleteDiveRole`.
- ADDITION over the dive-types clone: a rename affordance on custom tiles (an `IconButton` with `Icons.edit` and tooltip `diveRoles_renameTooltip` beside the delete icon) opening an `AlertDialog` (`diveRoles_renameDialog_title`) pre-filled with the current name; confirm calls `renameDiveRole(role.id, newName)`.

- [ ] **Step 4: Register route and Settings entry**

In `app_router.dart` (after the dive-types route at lines 975-980):

```dart
          // Dive Roles Management
          GoRoute(
            path: '/dive-roles',
            name: 'diveRoles',
            builder: (context, state) => const DiveRolesPage(),
          ),
```

plus the import next to the dive_types import (line ~102).

In `settings_page.dart`, after the Dive Types tile + divider (lines 1626-1636):

```dart
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(context.l10n.settings_manage_diveRoles),
                  subtitle: Text(
                    context.l10n.settings_manage_diveRoles_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-roles'),
                ),
                const Divider(height: 1),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_roles/presentation/pages/dive_roles_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): dive roles management page under Settings"
```

---

### Task 10: UDDF full backup for custom roles

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (custom section near the divetypes section at lines 1181-1204)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (param threading at lines ~56, 444, 499 / forwards at 414, 468, 523)
- Modify: `lib/core/services/export/export_service.dart` (params at 252/300, forwards at 275/323)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (fetch at ~345, pass at ~433)
- Modify: `lib/core/services/export/models/uddf_import_result.dart` (new `customDiveRoles` field mirroring `customDiveTypes` at lines 20, 45, 66, 85, 110-111, 138)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (parse near lines 331-343, result at 428)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (import the parsed roles, mirroring customDiveTypes handling at lines ~109, ~314)
- Test: `test/core/services/export/uddf/uddf_dive_roles_backup_test.dart` (new)

**Interfaces:**
- Consumes: `DiveRole`, `allDiveRolesProvider`, `DiveRoleRepository`.
- Produces: `<diveroles><diverole id="..."><name/><sortorder/></diverole></diveroles>` in full-backup UDDF; restore recreates custom roles with their original ids.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dive_roles_backup_test.dart`. Two halves:

```dart
test('export builders emit a diveroles section for custom roles only',
    () {
  // Call the builder function added in Step 3 directly with:
  // [DiveRole custom 'uuid-1' name 'Hekkensluiter' sortOrder 9]
  // Assert the returned XML fragment contains
  // '<diverole id="uuid-1">', '<name>Hekkensluiter</name>'.
});

test('full import parses diveroles into customDiveRoles', () async {
  // Feed UddfFullImportService (or its parser entry point — mirror how
  // an existing full-import test drives divetypes parsing; check
  // test/ for uddf_full_import tests to copy the harness) a minimal UDDF
  // document containing:
  // <diveroles><diverole id="uuid-1"><name>Hekkensluiter</name>
  // <sortorder>9</sortorder></diverole></diveroles>
  // Assert result.customDiveRoles is [{'id': 'uuid-1',
  // 'name': 'Hekkensluiter', 'sortOrder': 9}].
});
```

Locate the existing divetypes full-import test (`grep -rn "customDiveTypes" test/`) and copy its harness verbatim, swapping element names.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/export/uddf/uddf_dive_roles_backup_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement export**

In `uddf_export_builders.dart`, next to the divetypes section builder (lines 1181-1204), add the exact analog (copy the divetypes builder function verbatim, rename to roles):

```dart
  // <diveroles> custom section: one <diverole id=...> per custom role with
  // <name> and <sortorder>. Built-ins are skipped (re-seeded on import).
```

Thread `List<DiveRole>? customDiveRoles` through `uddf_full_export_service.dart` exactly parallel to `customDiveTypes` (parameter at each of the three signatures, forward at each of the three call sites, call the new builder beside the divetypes builder call at ~1181 usage site). Then `export_service.dart` params/forwards (252/275, 300/323), then `export_providers.dart`:

```dart
      final customDiveRoles = await DiveRoleRepository().getAllDiveRoles(
        diverId: currentDiverId,
      );
      // pass only custom: .where((r) => !r.isBuiltIn).toList()
```

fetched beside `customDiveTypes` (~345) and passed beside it (~433). (If a `diveRolesProvider`-style read fits the file's idiom better — `_ref.read(allDiveRolesProvider.future)` — use that and filter `!isBuiltIn`.)

- [ ] **Step 4: Implement import**

- `uddf_import_result.dart`: add `final List<Map<String, dynamic>> customDiveRoles;` with default `const []`, wired into the same 6 spots as `customDiveTypes` (field 20, ctor 45, isEmpty 66, count 85, summary 110-111, copyWith/factory 138).
- `uddf_full_import_service.dart`: parse `<diveroles>/<diverole>` beside the divetypes parse (331-343) into `customDiveRoles` maps `{'id', 'name', 'sortOrder'}`; include in the result (428). Add a `parseDiveRoleElement` to `UddfImportParsers` cloned from `parseDiveTypeElement`.
- `uddf_entity_importer.dart`: mirror the customDiveTypes import path (~109, ~314): insert each custom role via raw companion insert `INSERT OR IGNORE` semantics (preserve the original id so `dive_buddies.role` / `dives.diver_role` references resolve after restore):

```dart
    await db.into(db.diveRoles).insert(
      DiveRolesCompanion.insert(
        id: roleData['id'] as String,
        diverId: Value(targetDiverId),
        name: roleData['name'] as String,
        isBuiltIn: const Value(false),
        sortOrder: Value((roleData['sortOrder'] as int?) ?? 0),
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
```

(match the exact idiom the customDiveTypes import uses — including how it resolves `targetDiverId` and timestamps.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/`
Expected: PASS (new + pre-existing).
Run: `flutter test test/integration/uddf_round_trip_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(roles): include custom dive roles in UDDF full backup/restore"
```

---

### Task 11: Full-project verification

**Files:** none (verification only; fix regressions found)

- [ ] **Step 1: Format check**

Run: `dart format .`
Expected: "0 changed" (fix and re-commit if anything reformats).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (do not pipe the output).

- [ ] **Step 3: Run the affected test directories**

Run each (separately, to stay within timeouts):

```bash
flutter test test/core/database/
flutter test test/core/services/sync/
flutter test test/core/services/export/
flutter test test/features/buddies/
flutter test test/features/dive_roles/
flutter test test/features/dive_log/
flutter test test/features/dive_types/
flutter test test/features/signatures/
flutter test test/features/dive_import/ test/integration/uddf_round_trip_test.dart
```

Expected: all PASS. Fix any regressions (most likely: missed `BuddyRole` fixtures — convert to `DiveRole` per Task 5 Step 8).

- [ ] **Step 4: Commit any fixes**

```bash
dart format .
git add -A
git commit -m "test(roles): fix remaining fixtures after DiveRole migration"
```

(Skip the commit if the tree is clean.)

- [ ] **Step 5: Report**

Summarize: schema v103, files created/modified, test counts, and remaining manual verification (on-device smoke of the Me chip flow and a two-device sync check for custom roles).
