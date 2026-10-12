# Multiple Courses per Dive and Certifications per Course Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a dive belong to several training courses and a course earn several certifications (issue #2515).

**Architecture:** A new synced junction `dive_courses` (deterministic UUIDv5 ids) is the source of truth for a dive's courses; `dives.course_id` stays as a denormalized representative. `certifications.course_id` becomes the source of truth for a course's certifications; `courses.certification_id` stays as a denormalized representative. One seed function copies representative-only links into the junction and runs in the v288 rung, in beforeOpen, and after every sync apply.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, the in-house HLC sync engine, flutter_test.

**Spec:** `docs/design/specs/2026-10-12-multiple-courses-and-certifications-design.md`

## Global Constraints

- Schema rung: **v288** (main is at 283; 282, 284 and 285 are held by open PRs #3133, #3299, #3306). `minimumCompatibleSchemaVersion` stays at 280.
- Junction id: `Uuid().v5(Namespace.url.value, 'submersion:dive-course:$diveId:$courseId')`. Never change this string once shipped.
- Representative order for a dive's courses: course `start_date`, then `name`, then `id`.
- Representative order for a course's certifications: `issue_date` (NULL last), then `name`, then `id`.
- New tables go in `lib/core/database/tables/`, never in `database.dart`. Rungs append to `migrations/ladder/rungs_v231_onward.dart`. `before_open.dart` is at 759/800 lines: add at most one call line there.
- Every file under `lib/core/database/tables/` and `migrations/` stays at or under 800 lines (`test/core/database/database_table_libraries_test.dart`).
- No em-dashes anywhere (code, comments, docs, commits). No emojis.
- Every user-visible string goes through ARB, in all 11 locales (`lib/l10n/arb/`).
- Imports grouped dart, flutter, packages, local. `dart format .` before each commit.
- Commit messages: `feat(courses): ...`, `test(...)`, `fix(...)`. No attribution trailers.
- Platform-agnostic paths in tests (`p.join`, `Directory.systemTemp`). Tests restore any global state they replace.

## Review Focus

1. **An older app version on a second device** writes only `dives.course_id`. Expected: the dive gains that course on a new device and keeps its other courses. Pinned in Task 2 (sync seed test).
2. **Moving a certification from course A to course B** in B's editor. Expected: A's representative `certification_id` is recomputed (it may become NULL), and A's detail page stops listing the cert. Pinned in Task 4.
3. **Deleting a course that is the representative of a multi-course dive.** Expected: the dive keeps its other course, `dives.course_id` names that course, and the link rows are tombstoned. Pinned in Task 4.
4. **Undoing a planned-dive fill or a merge** on a dive with two courses. Expected: both courses come back. Pinned in Task 5.
5. **A multi-file UDDF import where two files both have a `cert_c1`.** Expected: each course links to its own file's certification, never the other file's. Pinned in Task 7 (payload merger test).

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/database/dive_course_identity.dart` (new) | `diveCourseLinkId(diveId, courseId)` |
| `lib/core/database/dive_course_links_schema.dart` (new) | Unique index assert, the idempotent `seedDiveCourseLinks(db)`, the certification-side backfill |
| `lib/core/database/tables/buddy_tables.dart` | `DiveCourses` table next to `Courses` |
| `lib/core/database/migrations/helpers/course_link_migrations.dart` (new part) | `_assertDiveCourseSchema()` and the v288 data step |
| `lib/core/database/migrations/before_open_course_links.dart` (new part) | beforeOpen backstop |
| `lib/features/courses/data/dive_course_links.dart` (new) | Junction reads and writes for repositories: hydrate, diff-write a set, bulk add/remove/replace, representative refresh |
| `lib/features/courses/data/course_certification_links.dart` (new) | `setCourseCertifications`, certification representative refresh |
| `lib/features/courses/presentation/widgets/course_picker.dart` | Rewritten as `CourseMultiSelectField` plus a multi-select sheet |
| `lib/features/certifications/presentation/widgets/certification_multi_select_field.dart` (new) | Chip field plus multi-select sheet with "Linked to" hint |
| `lib/features/dive_log/presentation/widgets/dive_course_rows.dart` (new) | Dive detail course rows and signature header chips (keeps `dive_detail_page.dart` from growing) |

---

### Task 1: Junction table, identity, uniqueness, seed and the v288 rung

**Files:**
- Create: `lib/core/database/dive_course_identity.dart`
- Create: `lib/core/database/dive_course_links_schema.dart`
- Create: `lib/core/database/migrations/helpers/course_link_migrations.dart`
- Create: `lib/core/database/migrations/before_open_course_links.dart`
- Modify: `lib/core/database/tables/buddy_tables.dart` (after `CourseRequirementDives`, ~line 301)
- Modify: `lib/core/database/database.dart` (tables list near `CourseRequirementDives`; `currentSchemaVersion` 283 to 286; append `286` to `migrationVersions`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (import + two `part` lines)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append rung)
- Modify: `lib/core/database/migrations/migration_strategy.dart` (`_onCreate`: assert the unique index)
- Modify: `lib/core/database/migrations/before_open.dart` (one call line, after the uniqueness asserts ~line 723)
- Modify: `lib/core/database/migrations/helpers/sync_migrations.dart` (`'dive_courses'` in the hlc list)
- Modify: `lib/core/database/performance_indexes.dart` (`idx_dive_courses_course_id`)
- Test: `test/core/database/migration_v286_dive_courses_test.dart`

**Interfaces:**
- Produces: `String diveCourseLinkId(String diveId, String courseId)`; `Future<int> seedDiveCourseLinks(DatabaseConnectionUser db)` (returns rows inserted); `Future<void> assertDiveCourseUniqueness(DatabaseConnectionUser db)`; `Future<void> backfillCertificationCourseLinks(DatabaseConnectionUser db)`; Drift table getter `db.diveCourses`, data class `DiveCourseRow`, companion `DiveCoursesCompanion`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/core/database/migration_v286_dive_courses_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';
import 'package:submersion/core/database/dive_course_links_schema.dart';

void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 283');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE courses (id TEXT PRIMARY KEY, diver_id TEXT, '
        'name TEXT, agency TEXT, start_date INTEGER, '
        'certification_id TEXT, created_at INTEGER, updated_at INTEGER)',
      );
      rawDb.execute(
        'CREATE TABLE dives (id TEXT PRIMARY KEY, course_id TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE certifications (id TEXT PRIMARY KEY, name TEXT, '
        'issue_date INTEGER, course_id TEXT)',
      );
      rawDb.execute(
        "INSERT INTO courses VALUES ('c1','d','AN','tdi',100,'k1',0,0)",
      );
      rawDb.execute(
        "INSERT INTO courses VALUES ('c2','d','DP','tdi',200,'k2',0,0)",
      );
      rawDb.execute("INSERT INTO dives VALUES ('v1','c1')");
      rawDb.execute("INSERT INTO dives VALUES ('v2',NULL)");
      // k1: linked only from the course side; k2: already points at c1, so
      // the certification side wins and c2 loses it.
      rawDb.execute("INSERT INTO certifications VALUES ('k1','AN',1,NULL)");
      rawDb.execute("INSERT INTO certifications VALUES ('k2','DP',2,'c1')");
    },
  );

  Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async =>
      [for (final r in await db.customSelect(sql).get()) r.data];

  test('v288 is in the ladder and leaves the sync floor alone', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(286));
    expect(AppDatabase.migrationVersions, contains(286));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(286));
  });

  test('creates dive_courses with its columns', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final cols = await rows(db, 'PRAGMA table_info(dive_courses)');
    expect({for (final c in cols) c['name']}, {
      'id', 'dive_id', 'course_id', 'created_at', 'hlc',
    });
  });

  test('seeds one deterministic link per dive course', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final links = await rows(db, 'SELECT * FROM dive_courses');
    expect(links, hasLength(1));
    expect(links.single['id'], diveCourseLinkId('v1', 'c1'));
    expect(links.single['hlc'], isNull);
  });

  test('the seed is idempotent', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await seedDiveCourseLinks(db), 0);
    expect(await rows(db, 'SELECT id FROM dive_courses'), hasLength(1));
  });

  test('the pair is unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await expectLater(
      db.customStatement(
        "INSERT INTO dive_courses (id, dive_id, course_id, created_at) "
        "VALUES ('other', 'v1', 'c1', 0)",
      ),
      throwsA(anything),
    );
  });

  test('certification side becomes the truth, representatives follow', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final certs = await rows(
      db,
      'SELECT id, course_id FROM certifications ORDER BY id',
    );
    expect(certs, [
      {'id': 'k1', 'course_id': 'c1'},
      {'id': 'k2', 'course_id': 'c1'},
    ]);
    final courses = await rows(
      db,
      'SELECT id, certification_id FROM courses ORDER BY id',
    );
    expect(courses, [
      {'id': 'c1', 'certification_id': 'k1'},
      {'id': 'c2', 'certification_id': null},
    ]);
  });

  test('a fresh database has the table and the unique index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final idx = await rows(
      db,
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_dive_courses_dive_course_unique'",
    );
    expect(idx, hasLength(1));
  });

  test('beforeOpen heals a database already at 286 without the table', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 286');
          rawDb.execute('CREATE TABLE courses (id TEXT PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dives (id TEXT PRIMARY KEY, course_id TEXT)',
          );
          rawDb.execute("INSERT INTO courses VALUES ('c1')");
          rawDb.execute("INSERT INTO dives VALUES ('v1','c1')");
        },
      ),
    );
    addTearDown(db.close);
    expect(await rows(db, 'SELECT id FROM dive_courses'), hasLength(1));
  });
}
```

Note: if the fixture misses a column a later beforeOpen backstop needs, follow `migration_v279_dive_computer_connections_test.dart`: add the column to the fixture rather than weakening an assertion.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/core/database/migration_v286_dive_courses_test.dart`
Expected: compile failure, `dive_course_identity.dart` not found.

- [ ] **Step 3: Identity helper**

```dart
// lib/core/database/dive_course_identity.dart
import 'package:uuid/uuid.dart';

/// The id of the `dive_courses` row linking [diveId] to [courseId] (#2515).
///
/// Deterministic, so the same link made on two devices, or seeded by the v288
/// migration on two devices, is one row under sync upsert rather than two.
/// The name string is frozen: changing it would fork every link in a synced
/// fleet.
String diveCourseLinkId(String diveId, String courseId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:dive-course:$diveId:$courseId',
);
```

- [ ] **Step 4: Table**

Append to `lib/core/database/tables/buddy_tables.dart` after `CourseRequirementDives`:

```dart
/// The courses a dive belongs to (v288, issue #2515). The source of truth for
/// a dive's courses; `dives.course_id` stays as a denormalized representative
/// for older app versions and single-value exports.
///
/// The id is a DETERMINISTIC UUIDv5 of (dive, course), see
/// `diveCourseLinkId`, and the pair is also uniquely indexed
/// (`idx_dive_courses_dive_course_unique`).
@DataClassName('DiveCourseRow')
class DiveCourses extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

In `database.dart`, add `DiveCourses,` to the `@DriftDatabase(tables: [...])` list right after `CourseRequirementDives,` with the comment `// A dive's courses (v288, issue #2515)`. Set `currentSchemaVersion = 286`. Append to `migrationVersions`:

```dart
    // v288: dive_courses junction and the certification-side course link
    // (issue #2515). 284 and 285 are held by open PRs #3299 and #3306.
    286,
```

Run: `dart run build_runner build --delete-conflicting-outputs` (or `bash scripts/setup.sh` if that command is refused).

- [ ] **Step 5: Schema helpers (uniqueness, seed, certification backfill)**

```dart
// lib/core/database/dive_course_links_schema.dart
library;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_course_identity.dart';

const String kDiveCoursesUniqueIndexName =
    'idx_dive_courses_dive_course_unique';

Future<bool> _exists(DatabaseConnectionUser db, String type, String name) async {
  final rows = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
        variables: [Variable<String>(type), Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// One `dive_courses` row per (dive, course). Ids are deterministic, so a
/// duplicate pair can only come from a hand-written row; the collapse keeps
/// the lowest id so every device keeps the same survivor.
Future<void> assertDiveCourseUniqueness(DatabaseConnectionUser db) async {
  if (!await _exists(db, 'table', 'dive_courses')) return;
  if (await _exists(db, 'index', kDiveCoursesUniqueIndexName)) return;
  await db.customStatement('''
    DELETE FROM dive_courses WHERE rowid IN (
      SELECT rowid FROM (
        SELECT rowid, ROW_NUMBER() OVER (
          PARTITION BY dive_id, course_id ORDER BY id ASC
        ) AS rn FROM dive_courses
      ) WHERE rn > 1
    )
  ''');
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS $kDiveCoursesUniqueIndexName '
    'ON dive_courses(dive_id, course_id)',
  );
}

/// Copies each dive's representative `dives.course_id` into `dive_courses`
/// when that pair has no row yet. Returns how many rows it inserted.
///
/// Runs in the v288 rung, on every open, and after every sync apply. It only
/// ever ADDS: an older app version writes just the representative column, and
/// this is how its link reaches the set without stripping the dive's other
/// courses. It cannot resurrect a removed link, because removing a dive's
/// representative course always rewrites `dives.course_id` in the same
/// transaction. Local and idempotent: no hlc, nothing marked pending; every
/// device derives the same rows from the same synced dives.
Future<int> seedDiveCourseLinks(DatabaseConnectionUser db) async {
  for (final table in const ['dive_courses', 'dives', 'courses']) {
    if (!await _exists(db, 'table', table)) return 0;
  }
  final missing = await db.customSelect('''
    SELECT d.id AS dive_id, d.course_id AS course_id FROM dives d
    WHERE d.course_id IS NOT NULL
      AND EXISTS (SELECT 1 FROM courses c WHERE c.id = d.course_id)
      AND NOT EXISTS (
        SELECT 1 FROM dive_courses dc
        WHERE dc.dive_id = d.id AND dc.course_id = d.course_id
      )
  ''').get();
  var inserted = 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final row in missing) {
    final diveId = row.read<String>('dive_id');
    final courseId = row.read<String>('course_id');
    inserted += await db.customUpdate(
      'INSERT OR IGNORE INTO dive_courses (id, dive_id, course_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(diveCourseLinkId(diveId, courseId)),
        Variable<String>(diveId),
        Variable<String>(courseId),
        Variable<int>(now),
      ],
    );
  }
  return inserted;
}

/// The certification side becomes the truth (v288): a course's
/// `certification_id` that names a certification with no course claims it,
/// then every course's representative is recomputed from the certification
/// side. Runs in the rung only. Deterministic over synced data, so it marks
/// nothing pending.
Future<void> backfillCertificationCourseLinks(
  DatabaseConnectionUser db,
) async {
  for (final table in const ['courses', 'certifications']) {
    if (!await _exists(db, 'table', table)) return;
  }
  await db.customStatement('''
    UPDATE certifications SET course_id = (
      SELECT c.id FROM courses c
      WHERE c.certification_id = certifications.id
      ORDER BY c.id LIMIT 1
    )
    WHERE course_id IS NULL
      AND EXISTS (
        SELECT 1 FROM courses c WHERE c.certification_id = certifications.id
      )
  ''');
  await db.customStatement('''
    UPDATE courses SET certification_id = (
      SELECT k.id FROM certifications k WHERE k.course_id = courses.id
      ORDER BY k.issue_date IS NULL, k.issue_date, k.name, k.id LIMIT 1
    )
  ''');
}
```

- [ ] **Step 6: Migration part, rung, backstop, create-time index**

```dart
// lib/core/database/migrations/helpers/course_link_migrations.dart
part of '../app_database_migrations.dart';

/// The `dive_courses` junction (v288, issue #2515).
extension CourseLinkMigrations on AppDatabase {
  /// Schema only: the table and its unique index. Idempotent.
  Future<void> _assertDiveCourseSchema() async {
    for (final parent in const ['dives', 'courses']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(diveCourses);
    await assertDiveCourseUniqueness(this);
  }
}
```

```dart
// lib/core/database/migrations/before_open_course_links.dart
part of 'app_database_migrations.dart';

/// beforeOpen backstop for the v288 course links, split out of before_open.dart
/// to keep it under the migration file size limit. The seed only adds rows
/// that `dives.course_id` names, so it cannot resurrect a removed link.
extension BeforeOpenCourseLinks on AppDatabase {
  Future<void> _assertCourseLinks() async {
    await _assertDiveCourseSchema();
    await seedDiveCourseLinks(this);
  }
}
```

In `app_database_migrations.dart`: add `import 'package:submersion/core/database/dive_course_links_schema.dart';`, `part 'before_open_course_links.dart';` and `part 'helpers/course_link_migrations.dart';` beside the existing part lines.

Append in `rungs_v231_onward.dart` after the v283 block:

```dart
    // v288: the dive_courses junction and the certification-side course link
    // (issue #2515). Schema re-asserted and links re-seeded in beforeOpen;
    // the certification backfill runs here only.
    if (from < 286) {
      await _assertDiveCourseSchema();
      await seedDiveCourseLinks(this);
      await backfillCertificationCourseLinks(this);
    }
    if (from < 286) await reportProgress();
```

In `migration_strategy.dart` `_onCreate`, after `await assertDiveRoleLinkUniqueness(this);` add `await assertDiveCourseUniqueness(this);`.

In `before_open.dart`, after the dive role uniqueness assert (~line 723), add one line: `await _assertCourseLinks();`.

In `sync_migrations.dart`, add `'dive_courses',` after `'dive_buddy_roles',`.

In `performance_indexes.dart`, after `idx_courses_diver`:

```dart
  // A course's dives through the junction (v288, issue #2515).
  (
    name: 'idx_dive_courses_course_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_courses_course_id '
        'ON dive_courses(course_id)',
  ),
```

- [ ] **Step 7: Run the test and the database suite**

Run: `flutter test test/core/database/migration_v286_dive_courses_test.dart test/core/database/database_table_libraries_test.dart test/core/database/performance_indexes_test.dart`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database/migration_v286_dive_courses_test.dart
git commit -m "feat(courses): add dive_courses junction and v288 migration"
```

---

### Task 2: Sync wiring for `diveCourses`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every site listed below)
- Modify: `lib/core/services/sync/sync_service.dart` (mergeOrder, `entityHasUpdatedAt`, `parentRefs`)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`, `test/core/services/sync/sync_serializer_upsert_test.dart` (target lists), `test/core/services/sync/clear_child_columns_test.dart`
- Create: `test/core/services/sync/sync_dive_courses_test.dart`

**Interfaces:**
- Consumes: `seedDiveCourseLinks`, `db.diveCourses`, `DiveCourseRow` (Task 1).
- Produces: entity type `'diveCourses'`; `SyncData.diveCourses`.

- [ ] **Step 1: Write the failing sync test**

Model on `test/core/services/sync/sync_dive_dive_types_test.dart` (read it first for the two-database harness helpers it uses). Three tests:

```dart
// test/core/services/sync/sync_dive_courses_test.dart (bodies use the same
// helpers as sync_dive_dive_types_test.dart: seed a diver, a course and a
// dive on both sides, export from A, apply on B)
test('a peer link replicates', ...);
// A inserts dive_courses(diveCourseLinkId('v1','c1')) and marks it pending;
// after A's export is applied on B, B has exactly that row.

test('the same link made on both devices converges to one row', ...);
// A and B each insert the (v1, c1) link with diveCourseLinkId; B applies A's
// payload; B still has exactly one row for the pair and no exception.

test('a representative-only dive gains the course and keeps others', ...);
// B has links (v1,c1) and (v1,c2). A peer payload carries dive v1 with
// course_id = 'c3' and no dive_courses rows (an older app version).
// After apply on B: dive_courses for v1 is {c1, c2, c3}.

test('a peer tombstone removes the link', ...);
```

Write each body in full against that file's helpers before running.

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/core/services/sync/sync_dive_courses_test.dart`
Expected: FAIL (`diveCourses` unknown to `SyncData`).

- [ ] **Step 3: Register the entity**

`sync_data_serializer.dart`, each next to its `diveDiveTypes` twin:
- `SyncData` field `final List<Map<String, dynamic>> diveCourses;`, constructor `this.diveCourses = const [],`, `toJson` `'diveCourses': diveCourses,`, `fromJson` `diveCourses: _parseList(json['diveCourses']),`. Keep `toJson` and `_baseTables` in the same relative position (directly after `diveDiveTypes`).
- `_baseTables`: `(key: 'diveCourses', table: _db.diveCourses, blob: false, full: null),`
- `parentGatedChildEntities`: `'diveCourses',`
- `parentGatedTables`: `'diveCourses': 'dive_courses',`
- `_buildSyncData`: 

```dart
      diveCourses: await _safeExport(
        'diveCourses',
        () async => _withPendingChildren(
          'diveCourses',
          await _exportDiveCourses(hlcSince),
          pendingChildren,
        ),
      ),
```

- `fetchRecord`: `case 'diveCourses': final row = await (_db.select(_db.diveCourses)..where((t) => t.id.equals(recordId))).getSingleOrNull(); return row?.toJson();`
- `upsertRecord`: 

```dart
      case 'diveCourses':
        // Deterministic ids, plus a unique (dive, course) index: DoNothing
        // with an empty target absorbs a conflict on either constraint, and
        // the pair is the row's whole meaning.
        await _db
            .into(_db.diveCourses)
            .insert(
              DiveCourseRow.fromJson(data),
              onConflict: DoNothing<$DiveCoursesTable, DiveCourseRow>(
                target: const [],
              ),
            );
        return;
```

- `upsertRecords`: same with `_db.batch((b) => b.insertAll(_db.diveCourses, records.map(DiveCourseRow.fromJson).toList(), onConflict: DoNothing<$DiveCoursesTable, DiveCourseRow>(target: const [])))`.
- `recordIdsFor`: `case 'diveCourses': return plain(_db.diveCourses, _db.diveCourses.id);`
- `_syncTableFor`: `case 'diveCourses': return _db.diveCourses;`
- `deleteRecord`: `case 'diveCourses': await (_db.delete(_db.diveCourses)..where((t) => t.id.equals(recordId))).go(); return;`
- Export helper beside `_exportDiveDiveTypes`:

```dart
  Future<List<Map<String, dynamic>>> _exportDiveCourses(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final diveIds = await _diveIdsModifiedSince(hlcSince);
      if (diveIds.isEmpty) return [];
      final rows = await (_db.select(
        _db.diveCourses,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveCourses).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

(Check `_diveIdsModifiedSince`'s exact signature at ~line 9179 and match it.)

- Seed after apply: in `repairDanglingForeignKeys()`, after `_repairDanglingReferences()`:

```dart
    // An older app version writes only dives.course_id (#2515).
    if (await seedDiveCourseLinks(_db) > 0) {
      _db.notifyUpdates({
        TableUpdate.onTable(_db.diveCourses, kind: UpdateKind.insert),
      });
    }
```

Also call the same block from the two single-record conflict paths that call `alignLinkedRouteOwners()` directly (sync_service.dart ~3914 and ~3926): extract it as `Future<void> seedRepresentativeCourseLinks()` on the serializer and call that.

`sync_service.dart`:
- mergeOrder, after the `diveDiveTypes` entry: `(type: 'diveCourses', records: data.diveCourses, hasUpdatedAt: false),`
- `entityHasUpdatedAt`: `'diveCourses': false,`
- `parentRefs`: 

```dart
    'diveCourses': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'courseId', parent: 'courses', nullable: false),
    ],
```

`sync_repository.dart` `hlcTargets`: `'diveCourses': (table: 'dive_courses', pk: 'id'),`

Tests: add `'dive_courses': 'diveCourses',` to `syncedTables` in the completeness test; add `(type: 'diveCourses', table: db.diveCourses.actualTableName),` to both target lists; add `expect(serializer.clearableChildKeys('diveCourses'), isEmpty);` beside the `diveDiveTypes` line.

- [ ] **Step 4: Run the sync suite**

Run: `flutter test test/core/services/sync/ test/architecture/child_write_restamps_test.dart test/features/settings/presentation/conflicts/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core test/core
git add lib/core/services/sync lib/core/data/repositories/sync_repository.dart test/core/services/sync
git commit -m "feat(courses): sync the dive_courses junction"
```

---

### Task 3: `Dive.courseIds` and the dive repository

**Files:**
- Create: `lib/features/courses/data/dive_course_links.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/domain/services/dive_mirror_fields.dart` (`'courseId'` to `'courseIds'` in `kUnmirroredDiveFields`)
- Modify: `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart` (`'courseId'` to `'courseIds'` in `kHumanDiveFields`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive ~1863, updateDive ~2193, `getDivesForCourse` ~3024, the three hydration paths ~604/4513/2686+3368, `watchDiveDetailChanges` ~334)
- Modify: every `Dive(...)` / `copyWith` caller passing `courseId:` (find with `grep -rn "courseId:" lib --include=*.dart | grep -v "Value("`)
- Test: `test/features/courses/data/dive_course_links_test.dart`, `test/features/dive_log/data/repositories/dive_repository_courses_test.dart`

**Interfaces:**
- Consumes: `diveCourseLinkId`, `db.diveCourses` (Task 1).
- Produces:
  - `Dive.courseIds` (`List<String>`, default `const []`, representative first) and getter `String? get courseId => courseIds.isEmpty ? null : courseIds.first;`. The constructor and `copyWith` take `courseIds`, never `courseId`.
  - `class DiveCourseLinks { DiveCourseLinks(AppDatabase db, SyncRepository sync); Future<Map<String, List<String>>> courseIdsForDives(List<String> diveIds); Future<void> writeCourseSet(String diveId, List<String> courseIds, {required int now}); Future<String?> refreshRepresentative(String diveId, {required int now, bool markPending = false}); Future<void> addCourses(List<String> diveIds, List<String> courseIds, {required int now}); Future<void> removeCourses(List<String> diveIds, List<String> courseIds, {required int now}); Future<Map<String, int>> courseCountsForDives(List<String> diveIds); }`

- [ ] **Step 1: Write the failing link tests**

```dart
// test/features/courses/data/dive_course_links_test.dart
// Setup: setUpTestDatabase(); insert diver 'd'; courses c1 (start 100, 'B'),
// c2 (start 100, 'A'), c3 (start 50, 'Z'); dive v1. links =
// DiveCourseLinks(db, SyncRepository()).

test('writeCourseSet writes deterministic rows and the representative', () async {
  await links.writeCourseSet('v1', ['c1', 'c2'], now: 1);
  final rows = await db.select(db.diveCourses).get();
  expect({for (final r in rows) r.id}, {
    diveCourseLinkId('v1', 'c1'),
    diveCourseLinkId('v1', 'c2'),
  });
  final dive = await (db.select(db.dives)..where((t) => t.id.equals('v1')))
      .getSingle();
  expect(dive.courseId, 'c2'); // same start date, 'A' sorts before 'B'
});

test('writeCourseSet diffs: an unchanged pair keeps its row', () async {
  await links.writeCourseSet('v1', ['c1', 'c2'], now: 1);
  await links.writeCourseSet('v1', ['c1', 'c3'], now: 2);
  final rows = await db.select(db.diveCourses).get();
  final c1 = rows.firstWhere((r) => r.courseId == 'c1');
  expect(c1.createdAt, 1);
  expect(rows.map((r) => r.courseId).toSet(), {'c1', 'c3'});
  final tombstones = await db.select(db.deletionLog).get();
  expect(tombstones.map((t) => t.recordId), [diveCourseLinkId('v1', 'c2')]);
});

test('an empty set clears the representative', () async {
  await links.writeCourseSet('v1', ['c1'], now: 1);
  await links.writeCourseSet('v1', [], now: 2);
  final dive = await (db.select(db.dives)..where((t) => t.id.equals('v1')))
      .getSingle();
  expect(dive.courseId, isNull);
});

test('courseIdsForDives lists the representative first', () async {
  await links.writeCourseSet('v1', ['c1', 'c2', 'c3'], now: 1);
  expect((await links.courseIdsForDives(['v1']))['v1'], ['c3', 'c2', 'c1']);
});

test('a dive with only the legacy column hydrates from it', () async {
  await db.customStatement("UPDATE dives SET course_id = 'c1' WHERE id = 'v1'");
  expect((await links.courseIdsForDives(['v1']))['v1'], ['c1']);
});

test('add and remove keep other courses', () async {
  await links.writeCourseSet('v1', ['c1'], now: 1);
  await links.addCourses(['v1'], ['c2'], now: 2);
  await links.removeCourses(['v1'], ['c1'], now: 3);
  expect((await links.courseIdsForDives(['v1']))['v1'], ['c2']);
});

test('counts per course across dives', () async { ... });
```

Check the deletion log table and column names in `database.g.dart` before running (`deletionLog`, `recordId`).

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/features/courses/data/dive_course_links_test.dart`
Expected: compile failure.

- [ ] **Step 3: Implement `DiveCourseLinks`**

```dart
// lib/features/courses/data/dive_course_links.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';

/// Reads and writes a dive's courses (`dive_courses`, issue #2515) and keeps
/// the representative `dives.course_id` in step with the set. No transaction
/// and no notify: callers own both.
class DiveCourseLinks {
  DiveCourseLinks(this._db, this._sync);

  final AppDatabase _db;
  final SyncRepository _sync;

  static const _representativeSql = '''
    SELECT dc.course_id FROM dive_courses dc
    JOIN courses c ON c.id = dc.course_id
    WHERE dc.dive_id = ?
    ORDER BY c.start_date, c.name, c.id LIMIT 1
  ''';

  /// Each dive's course ids, the stored representative first, then by course
  /// start date, name and id. A dive with no junction rows falls back to its
  /// representative column (a link made by an older app version that the
  /// seed has not reached yet).
  Future<Map<String, List<String>>> courseIdsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final map = <String, List<String>>{};
    for (final chunk in _chunks(diveIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT dc.dive_id, dc.course_id FROM dive_courses dc '
            'JOIN courses c ON c.id = dc.course_id '
            'JOIN dives d ON d.id = dc.dive_id '
            'WHERE dc.dive_id IN ($placeholders) '
            'ORDER BY dc.dive_id, (dc.course_id = d.course_id) DESC, '
            'c.start_date, c.name, c.id',
            variables: [for (final id in chunk) Variable<String>(id)],
            readsFrom: {_db.diveCourses, _db.courses, _db.dives},
          )
          .get();
      for (final r in rows) {
        (map[r.read<String>('dive_id')] ??= []).add(
          r.read<String>('course_id'),
        );
      }
      final legacy = await (_db.select(_db.dives)
            ..where((t) => t.id.isIn(chunk) & t.courseId.isNotNull()))
          .get();
      for (final d in legacy) {
        map.putIfAbsent(d.id, () => [d.courseId!]);
      }
    }
    return map;
  }

  /// Makes [diveId]'s courses exactly [courseIds]: inserts new pairs, removes
  /// and tombstones dropped ones, leaves unchanged pairs alone, then rewrites
  /// the representative. Callers mark the dive itself pending.
  Future<void> writeCourseSet(
    String diveId,
    List<String> courseIds, {
    required int now,
  }) async {
    final want = courseIds.toSet();
    final existing = await (_db.select(
      _db.diveCourses,
    )..where((t) => t.diveId.equals(diveId))).get();
    final have = {for (final r in existing) r.courseId};
    for (final row in existing.where((r) => !want.contains(r.courseId))) {
      await (_db.delete(
        _db.diveCourses,
      )..where((t) => t.id.equals(row.id))).go();
      await _sync.logDeletion(entityType: 'diveCourses', recordId: row.id);
    }
    for (final courseId in want.difference(have)) {
      final id = diveCourseLinkId(diveId, courseId);
      await _db
          .into(_db.diveCourses)
          .insert(
            DiveCoursesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              courseId: Value(courseId),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _sync.markRecordPending(
        entityType: 'diveCourses',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await refreshRepresentative(diveId, now: now);
  }

  /// Rewrites `dives.course_id` from the set. Returns the representative.
  /// With [markPending], a changed dive is also stamped for sync (used when
  /// the caller is not already saving the dive, such as a course delete).
  Future<String?> refreshRepresentative(
    String diveId, {
    required int now,
    bool markPending = false,
  }) async {
    final rep = await _db
        .customSelect(
          _representativeSql,
          variables: [Variable<String>(diveId)],
        )
        .getSingleOrNull();
    final courseId = rep?.read<String>('course_id');
    final changed = await (_db.update(_db.dives)
          ..where(
            (t) => t.id.equals(diveId) & t.courseId.isNotValue(courseId),
          ))
        .write(DivesCompanion(courseId: Value(courseId)));
    if (changed > 0 && markPending) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
    return courseId;
  }

  Future<void> addCourses(
    List<String> diveIds,
    List<String> courseIds, {
    required int now,
  }) async {
    final current = await courseIdsForDives(diveIds);
    for (final diveId in diveIds) {
      await writeCourseSet(diveId, [
        ...?current[diveId],
        ...courseIds,
      ], now: now);
    }
  }

  Future<void> removeCourses(
    List<String> diveIds,
    List<String> courseIds, {
    required int now,
  }) async {
    final current = await courseIdsForDives(diveIds);
    final drop = courseIds.toSet();
    for (final diveId in diveIds) {
      await writeCourseSet(diveId, [
        for (final c in current[diveId] ?? const <String>[])
          if (!drop.contains(c)) c,
      ], now: now);
    }
  }

  /// {courseId: how many of [diveIds] are in it}, for the bulk editor.
  Future<Map<String, int>> courseCountsForDives(List<String> diveIds) async {
    final current = await courseIdsForDives(diveIds);
    final counts = <String, int>{};
    for (final ids in current.values) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    const size = 500;
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }
}
```

If `Expression.isNotValue` does not exist in this Drift version, use `t.courseId.isNull() | t.courseId.equals(courseId).not()` when `courseId` is non-null and `t.courseId.isNotNull()` when it is null. Check by compiling.

- [ ] **Step 4: Run the link tests**

Run: `flutter test test/features/courses/data/dive_course_links_test.dart`
Expected: PASS.

- [ ] **Step 5: Entity**

In `dive.dart`: replace the `courseId` field with

```dart
  // Training courses (v288, issue #2515). The representative (the
  // `dives.course_id` column) comes first.
  final List<String> courseIds;
```

constructor `this.courseIds = const [],`, `copyWith` parameter `List<String>? courseIds` with `courseIds: courseIds ?? this.courseIds`, `props` `courseIds` in place of `courseId`, and the getter

```dart
  /// The representative training course, or null.
  String? get courseId => courseIds.isEmpty ? null : courseIds.first;
```

Update both census sets (`courseId` to `courseIds`). Then `flutter analyze` and fix every caller that passed `courseId:` to `Dive(...)` or `copyWith`: pass `courseIds: [x]` or `courseIds: const []` instead (the UDDF importer at ~2916 is handled fully in Task 7; for now pass `courseIds: [?linkedCourseId]`, or the `if` collection form if null-aware elements are not enabled). The merge builder becomes an ordered union:

```dart
    // Courses: ordered union, the earliest dive's courses first (#2515).
    final mergedCourseIds = <String>[];
    for (final d in sorted) {
      for (final c in d.courseIds) {
        if (!mergedCourseIds.contains(c)) mergedCourseIds.add(c);
      }
    }
```

and `courseIds: mergedCourseIds,` in place of the `_firstNonNull` line.

- [ ] **Step 6: Repository write and read paths**

In `DiveRepositoryImpl` add a field `late final DiveCourseLinks _courseLinks = DiveCourseLinks(_db, _syncRepository);` (match how `_roleLinks` is constructed). In `createDive` and `updateDive`, keep `courseId: Value(dive.courseId)` in the companion and, after `_replaceDiveTypeRows(...)`, add `await _courseLinks.writeCourseSet(id, dive.courseIds, now: now);` (`dive.id` in `updateDive`).

Hydration: at each place `_diveTypesForDives` is called (getDivesByIds ~604, `_mapRowToDive` ~4513, summaries ~2686 and ~3368), also load `final coursesByDive = await _courseLinks.courseIdsForDives(diveIds);` and pass `courseIds: coursesByDive[row.id] ?? const []` where the `Dive` is built. Remove the `courseId: row.courseId` mapper lines. If `DiveSummary` has no course field, skip the summary paths.

`getDivesForCourse`:

```dart
      final query = _db.select(_db.dives)
        ..where(
          (t) => existsQuery(
            _db.select(_db.diveCourses)..where(
              (j) => j.diveId.equalsExp(t.id) & j.courseId.equals(courseId),
            ),
          ),
        )
        ..orderBy([...unchanged...]);
```

`watchDiveDetailChanges`: add `TableUpdateQuery.onTable(_db.diveCourses),` after the `courses` entry.

- [ ] **Step 7: Repository test**

```dart
// test/features/dive_log/data/repositories/dive_repository_courses_test.dart
test('a dive saves and reloads with two courses', () async {
  final created = await repo.createDive(baseDive.copyWith(courseIds: ['c1', 'c2']));
  final loaded = await repo.getDiveById(created.id);
  expect(loaded!.courseIds.toSet(), {'c1', 'c2'});
  expect(loaded.courseId, loaded.courseIds.first);
});
test('updating to one course drops the other', ...);
test('getDivesForCourse lists a dive under each of its courses', ...);
test('deleting the dive cascades its links', ...);
test('deleting the diver leaves no dive_courses rows behind', ...);
// Through the diver deletion service the app uses (find it from
// diver_owned_rows.dart); its dives and courses go, so the junction must too.
```

Use the dive fixture helpers already used by `test/features/dive_log/data/repositories/dive_repository_dive_types_test.dart`.

- [ ] **Step 8: Run**

Run: `flutter analyze && flutter test test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart test/features/dive_log/data/repositories/ test/features/courses/`
Expected: no analyzer errors; tests PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib test
git add lib/features test/features
git commit -m "feat(courses): store a dive's courses as a set"
```

---

### Task 4: Course and certification repositories and providers

**Files:**
- Create: `lib/features/courses/data/course_certification_links.dart`
- Modify: `lib/features/certifications/domain/entities/certification.dart` (read-only `courseId`)
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart` (map `courseId`; `getCertificationsForCourse`; `deleteCertification` refreshes the course representative)
- Modify: `lib/features/courses/data/repositories/course_repository.dart`
- Modify: `lib/features/courses/data/repositories/course_requirement_repository.dart` (`getSuggestedDives`)
- Modify: `lib/features/courses/presentation/providers/course_providers.dart`
- Test: `test/features/courses/data/course_certification_links_test.dart`, extend `test/features/courses/data/repositories/course_repository_link_test.dart`, `test/features/courses/presentation/providers/course_providers_test.dart`

**Interfaces:**
- Consumes: `DiveCourseLinks` (Task 3).
- Produces:
  - `Certification.courseId` (`String?`, read-only: never written by create/update).
  - `class CourseCertificationLinks { CourseCertificationLinks(AppDatabase db, SyncRepository sync); Future<void> setCourseCertifications(String courseId, List<String> certificationIds, {required int now}); Future<void> refreshRepresentative(String courseId, {required int now}); }`
  - `CertificationRepository.getCertificationsForCourse(String courseId) -> Future<List<Certification>>`
  - `CourseRepository`: `getCoursesForDive(String diveId) -> Future<List<Course>>` (representative first; replaces `getCourseForDive`), `linkDiveToCourse(diveId, courseId)`, `unlinkDiveFromCourse(diveId, courseId)`, `setCourseCertifications(courseId, certIds)`, `Stream<void> watchCourseLinkChanges()` (dives, dive_courses, certifications, courses).
  - Providers: `coursesForDiveProvider` (family `String` to `List<Course>`, replaces `courseForDiveProvider`), `certificationsForCourseProvider` (family `String` to `List<Certification>`), `CourseListNotifier.setCourseCertifications(courseId, certIds)` (replaces `linkCourseToCertification`).

- [ ] **Step 1: Failing tests for certification links**

```dart
// test/features/courses/data/course_certification_links_test.dart
// Setup: diver 'd'; courses A, B; certs k1 (issue 1), k2 (issue 2), k3 (no date).
test('a course earns several certifications, earliest is representative', () async {
  await links.setCourseCertifications('A', ['k2', 'k1'], now: 1);
  expect(await certCourse('k1'), 'A');
  expect(await certCourse('k2'), 'A');
  expect(await courseRep('A'), 'k1');
});
test('unticking clears the certification side and the representative', () async {
  await links.setCourseCertifications('A', ['k1'], now: 1);
  await links.setCourseCertifications('A', [], now: 2);
  expect(await certCourse('k1'), isNull);
  expect(await courseRep('A'), isNull);
});
test('moving a certification recomputes the old course', () async {
  await links.setCourseCertifications('A', ['k1', 'k2'], now: 1);
  await links.setCourseCertifications('B', ['k1'], now: 2);
  expect(await certCourse('k1'), 'B');
  expect(await courseRep('A'), 'k2');
  expect(await courseRep('B'), 'k1');
});
test('an undated certification sorts last', ...);
test('every touched row is marked pending', ...);
```

- [ ] **Step 2: Run, confirm failure.** `flutter test test/features/courses/data/course_certification_links_test.dart`

- [ ] **Step 3: Implement**

```dart
// lib/features/courses/data/course_certification_links.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// A course's certifications (issue #2515). `certifications.course_id` is the
/// truth; `courses.certification_id` is a representative kept for older app
/// versions and single-value exports. No transaction and no notify: callers
/// own both.
class CourseCertificationLinks {
  CourseCertificationLinks(this._db, this._sync);

  final AppDatabase _db;
  final SyncRepository _sync;

  Future<void> setCourseCertifications(
    String courseId,
    List<String> certificationIds, {
    required int now,
  }) async {
    final want = certificationIds.toSet();
    final current = await (_db.select(
      _db.certifications,
    )..where((t) => t.courseId.equals(courseId))).get();
    final have = {for (final c in current) c.id};
    final touchedCourses = <String>{courseId};

    for (final id in have.difference(want)) {
      await _setCourse(id, null, now);
    }
    for (final id in want.difference(have)) {
      final cert = await (_db.select(
        _db.certifications,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (cert == null) continue;
      if (cert.courseId != null) touchedCourses.add(cert.courseId!);
      await _setCourse(id, courseId, now);
    }
    for (final id in touchedCourses) {
      await refreshRepresentative(id, now: now);
    }
  }

  Future<void> _setCourse(String certificationId, String? courseId, int now) async {
    await (_db.update(
      _db.certifications,
    )..where((t) => t.id.equals(certificationId))).write(
      CertificationsCompanion(courseId: Value(courseId), updatedAt: Value(now)),
    );
    await _sync.markRecordPending(
      entityType: 'certifications',
      recordId: certificationId,
      localUpdatedAt: now,
    );
  }

  /// Rewrites `courses.certification_id` to the earliest-issued linked
  /// certification (undated last, then name, then id), marking the course
  /// pending only when the value changed.
  Future<void> refreshRepresentative(String courseId, {required int now}) async {
    final rep = await _db
        .customSelect(
          'SELECT id FROM certifications WHERE course_id = ? '
          'ORDER BY issue_date IS NULL, issue_date, name, id LIMIT 1',
          variables: [Variable<String>(courseId)],
        )
        .getSingleOrNull();
    final certId = rep?.read<String>('id');
    final changed = await _db.customUpdate(
      'UPDATE courses SET certification_id = ?1, updated_at = ?2 '
      'WHERE id = ?3 AND certification_id IS NOT ?1',
      variables: [
        Variable<String>(certId),
        Variable<int>(now),
        Variable<String>(courseId),
      ],
      updates: {_db.courses},
    );
    if (changed > 0) {
      await _sync.markRecordPending(
        entityType: 'courses',
        recordId: courseId,
        localUpdatedAt: now,
      );
    }
  }
}
```

- [ ] **Step 4: Run the link tests.** Expected PASS.

- [ ] **Step 5: Certification entity and repository**

Add `final String? courseId;` to `Certification` (constructor `this.courseId,`, `copyWith`, `props`) with the doc comment `/// The course this certification came from (issue #2515). Read-only here: only CourseCertificationLinks writes certifications.course_id.` Map it in both mappers (`courseId: row.courseId` and `row.data['course_id'] as String?`). Do NOT add it to the create/update companions.

Add:

```dart
  /// The certifications earned through [courseId], earliest issued first
  /// (undated last). The representative is the first.
  Future<List<domain.Certification>> getCertificationsForCourse(
    String courseId,
  ) async {
    final rows = await (_db.select(_db.certifications)
          ..where((t) => t.courseId.equals(courseId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.issueDate.isNull()),
            (t) => OrderingTerm.asc(t.issueDate),
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return _withCardImages(rows.map(_mapRowToCertification).toList());
  }
```

In `deleteCertification`, read the row's `courseId` before deleting and, inside the same transaction after the delete, call `CourseCertificationLinks(_db, _syncRepository).refreshRepresentative(courseId, now: now)` when it was non-null. Add a test: deleting the representative certification moves the course's representative to the next one.

- [ ] **Step 6: Course repository**

Replace in `course_repository.dart` (keep try/catch + `_log.error` + rethrow on every method, as the file does):

- `getCoursesForDive(String diveId)`:

```sql
SELECT c.* FROM dive_courses dc
JOIN courses c ON c.id = dc.course_id
JOIN dives d ON d.id = dc.dive_id
WHERE dc.dive_id = ?
ORDER BY (c.id = d.course_id) DESC, c.start_date, c.name, c.id
```

Keep the `// stats-scope-exempt: course credit is deliberate, not descriptive` marker. Delete `getCourseForDive`.

- `getCourseForCertification`: `SELECT c.* FROM courses c JOIN certifications k ON k.course_id = c.id WHERE k.id = ?` and update the comment (the certification side is the truth since v288).
- `getDiveCountForCourse`: `SELECT COUNT(*) AS count FROM dive_courses WHERE course_id = ?` (keep its doc comment and exemption marker).
- `createCourse` / `updateCourse`: remove `certificationId: Value(course.certificationId)` from both companions. Add a one-line comment: `// certification_id is derived; CourseCertificationLinks owns it (#2515).`
- `deleteCourse`, inside the transaction, replace the `UPDATE dives SET course_id = NULL ...` statement with:

```dart
        // Its dive links go with it, tombstoned; each dive's representative
        // moves to its next course (#2515).
        final diveLinks = await (_db.select(
          _db.diveCourses,
        )..where((t) => t.courseId.equals(id))).get();
        await (_db.delete(
          _db.diveCourses,
        )..where((t) => t.courseId.equals(id))).go();
        for (final link in diveLinks) {
          await _syncRepository.logDeletion(
            entityType: 'diveCourses',
            recordId: link.id,
          );
          await _courseLinks.refreshRepresentative(
            link.diveId,
            now: now,
            markPending: true,
          );
        }
```

with `final now = DateTime.now().millisecondsSinceEpoch;` at the top of the transaction. The `UPDATE certifications SET course_id = NULL ...` statement stays, followed by `markRecordPending` for each certification it cleared (select their ids first).
- `linkDiveToCourse(diveId, courseId)` / `unlinkDiveFromCourse(diveId, courseId)`: inside `_db.transaction`, read the current set via `_courseLinks.courseIdsForDives([diveId])`, call `writeCourseSet` with the course added or removed, then stamp the dive (`updated_at`) and `markRecordPending('dives', diveId)`; `SyncEventBus.notifyLocalChange()` after.
- `setCourseCertifications(courseId, certIds)`: `_db.transaction(() => _certLinks.setCourseCertifications(...))`, then `SyncEventBus.notifyLocalChange()`. Delete `linkCourseToCertification`.
- `watchCourseLinkChanges()`:

```dart
  Stream<void> watchCourseLinkChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveCourses),
      TableUpdateQuery.onTable(_db.certifications),
    ]),
  );
```

Fields: `late final _courseLinks = DiveCourseLinks(_db, _syncRepository);` and `late final _certLinks = CourseCertificationLinks(_db, _syncRepository);` (getters, since `_db` is a getter: use `DiveCourseLinks get _courseLinks => DiveCourseLinks(_db, _syncRepository);`).

`course_requirement_repository.dart` `getSuggestedDives`: replace `(d.course_id = ?1 OR d.dive_date_time >= ?3)` with `(EXISTS (SELECT 1 FROM dive_courses dc WHERE dc.dive_id = d.id AND dc.course_id = ?1) OR d.dive_date_time >= ?3)`, add `_db.diveCourses` to `readsFrom`, and update the doc comment's `(dives.course_id)` to `(dive_courses)`.

- [ ] **Step 7: Providers**

In `course_providers.dart`:
- Replace `courseForDiveProvider` with:

```dart
/// A dive's courses, the representative first (#2515).
final coursesForDiveProvider = FutureProvider.family<List<Course>, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(courseRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return repository.getCoursesForDive(diveId);
});
```

- `courseForCertificationProvider`, `courseDivesProvider`, `courseDiveCountProvider`: add `ref.invalidateSelfWhen(repository.watchCourseLinkChanges());` (the courses-tick on `courseForCertificationProvider` stays). Update the `courseDiveCountProvider` doc: the count is over `dive_courses`.
- New:

```dart
/// The certifications a course earned, earliest issued first (#2515).
final certificationsForCourseProvider =
    FutureProvider.family<List<Certification>, String>((ref, courseId) async {
      final repository = ref.watch(certificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchCertificationsChanges());
      return repository.getCertificationsForCourse(courseId);
    });
```

- `CourseListNotifier`: replace `linkCourseToCertification` with `setCourseCertifications(courseId, certIds)` (calls the repository, invalidates `courseByIdProvider(courseId)` and `certificationsForCourseProvider(courseId)`, then `refresh()`); `linkDiveToCourse` / `unlinkDiveFromCourse` invalidate `coursesForDiveProvider(diveId)`.

Then `flutter analyze` and update every `courseForDiveProvider` reference (dive detail page, dive edit page, tests, `test/architecture/provider_tick_build_smoke_test.dart`) to `coursesForDiveProvider`. UI callers get their real rework in Tasks 8 and 9; for now take `.firstOrNull` so the build stays green.

- [ ] **Step 8: Repository tests** (extend `course_repository_link_test.dart`)

```dart
test('a dive can be linked to two courses', ...);
test('unlinking one course keeps the other and moves the representative', ...);
test('deleting a dive\'s representative course keeps its other course', () async {
  // dive v1 in A and B, representative A. deleteCourse(A).
  // Expect: dive_courses for v1 == {B}; dives.course_id == 'B'; a deletionLog
  // entry for diveCourseLinkId('v1','A'); v1 marked pending.
});
test('getCourseForCertification reads the certification side', ...);
test('updateCourse never overwrites the derived certification_id', ...);
test('suggested dives include a dive linked through the junction', ...);
```

- [ ] **Step 9: Run**

Run: `flutter analyze && flutter test test/features/courses/ test/features/certifications/ test/architecture/provider_tick_build_smoke_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/features test/features test/architecture
git commit -m "feat(courses): let a course earn several certifications"
```

---

### Task 5: Merge, consolidation, planned fill undo and bulk edit

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_snapshot.dart` (`diveCourseRows`)
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart` (undo: delete merged rows ~693, re-insert ~820)
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart` (union ~655, `snapshotIds` ~929, `currentChildIds` ~989, batch delete ~1042, re-insert ~1177)
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (`DiveCoursesOp`)
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart` (`priorCourseIds`)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (bulk course ops and counts delegating to `_courseLinks`)
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (remove `BulkField.course` and `BulkScalarInputs.courseId`)
- Test: `test/features/dive_log/data/services/dive_merge_service_courses_test.dart`, `test/features/dive_log/data/services/dive_consolidation_service_test.dart` (extend), `test/features/dive_log/data/services/bulk_dive_edit_service_courses_test.dart`

**Interfaces:**
- Consumes: `DiveCourseLinks.addCourses/removeCourses/writeCourseSet/courseCountsForDives/refreshRepresentative` (Task 3).
- Produces: `class DiveCoursesOp extends BulkCollectionOp { final BulkCollectionMode mode; final List<String> courseIds; }`; `DiveRepository.bulkAddCourses/bulkRemoveCourses/bulkReplaceCourses(List<String> diveIds, List<String> courseIds)`; `DiveRepository.courseCountsForDives(List<String> diveIds) -> Future<Map<String, int>>`; `BulkEditSnapshot.priorCourseIds` (`Map<String, List<String>>?`).

- [ ] **Step 1: Failing tests**

```dart
// merge: two dives, A in course c1, B in c2. apply merge -> merged dive's
// courseIds == {c1, c2}. undo -> A has [c1], B has [c2] again (junction rows
// and dives.course_id).
// consolidation: target in c1, secondary in c2 -> target ends in {c1, c2},
// dives.course_id still c1 (start date earlier), the new link row marked
// pending. undo -> target back to [c1]; the c2 link tombstoned.
// planned fill: planned dive in {c1, c2}; fill then undo -> {c1, c2}.
// bulk: dives v1 {c1}, v2 {} -> DiveCoursesOp(add, [c2]) -> v1 {c1,c2},
// v2 {c2}; DiveCoursesOp(remove, [c1]) -> v1 {c2}; undo restores {c1} / {}.
```

Write each body against the fixtures in the neighbouring dive-types tests (`dive_consolidation_service_test.dart`, `bulk_dive_edit_service_dive_types_test.dart`).

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement**

Snapshot: `final List<DiveCourseRow> diveCourseRows;` captured with `await (db.select(db.diveCourses)..where((t) => t.diveId.isIn(diveIds))).get()`.

Merge service undo, beside the dive-types lines: `batch.deleteWhere(_db.diveCourses, (t) => t.diveId.equals(mergedId));` and

```dart
      for (final r in snapshot.diveCourseRows) {
        await _db
            .into(_db.diveCourses)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveCourses',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
```

Run this after the source dive rows are re-inserted (they carry their own `course_id`).

Consolidation union, after the dive-types union block:

```dart
        // Courses: union onto the target (#2515). Deterministic ids, so a pair
        // the target already has is the same row.
        for (final row in snapshot.diveCourseRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          final id = diveCourseLinkId(targetDiveId, row.courseId);
          final inserted = await _db
              .into(_db.diveCourses)
              .insert(
                DiveCoursesCompanion(
                  id: Value(id),
                  diveId: Value(targetDiveId),
                  courseId: Value(row.courseId),
                  createdAt: Value(now),
                ),
                mode: InsertMode.insertOrIgnore,
              );
          if (inserted > 0) {
            await _sync.markRecordPending(
              entityType: 'diveCourses',
              recordId: id,
              localUpdatedAt: now,
            );
          }
        }
        await DiveCourseLinks(_db, _sync).refreshRepresentative(
          targetDiveId,
          now: now,
        );
```

(The target dive is stamped pending later in the same method, so `markPending` stays false here.) Add `'diveCourses': {for (final r in snapshot.diveCourseRows) r.id}` to `snapshotIds`, the matching `currentChildIds` entry, `batch.deleteWhere(_db.diveCourses, (t) => t.diveId.equals(mergedId));`, and the re-insert loop (same shape as the merge undo loop).

Bulk: `DiveCoursesOp` in `bulk_edit_request.dart`:

```dart
class DiveCoursesOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | remove | replace
  final List<String> courseIds;
  const DiveCoursesOp({required this.mode, required this.courseIds});
}
```

`bulk_dive_edit_service.dart`: prior capture `case DiveCoursesOp(): priorCourseIds = await _diveRepo.courseIdsForDives(ids);` (expose `courseIdsForDives` on the repository by delegating to `_courseLinks`), seeding missing ids with `const []`; `_applyOp` switch calling `bulkAddCourses` / `bulkRemoveCourses` / `bulkReplaceCourses`, `update` throwing `UnsupportedError('Courses have no in-place update')`; undo `for (final id in ids) await _diveRepo.bulkReplaceCourses([id], priorCourseIds[id] ?? const []);` placed after the prior dive rows are restored. Repository bulk methods call the `_courseLinks` method then `_bumpDives(diveIds, now)`.

Remove `BulkField.course`, `BulkScalarInputs.courseId` and its `buildScalarCompanion` arm; fix the analyzer fallout in `dive_edit_page.dart` by deleting the gated course row (Task 8 adds the membership editor).

- [ ] **Step 4: Run.** `flutter analyze && flutter test test/features/dive_log/ test/features/dive_computer/` Expected PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(courses): carry a dive's courses through merge, consolidation and bulk edit"
```

---

### Task 6: Query language, connections, data quality, signatures

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart:487`
- Modify: `lib/features/courses/query/course_query_entity.dart:61-79`
- Modify: `lib/features/certifications/query/certification_query_entity.dart:78-89`
- Modify: `lib/features/connections/data/connections_membership_sql.dart:33-35`, `lib/features/connections/data/repositories/connections_repository.dart:191`
- Modify: `lib/features/data_quality/data/services/diver_data_sql.dart:34, 83, 87-98`
- Modify: `lib/features/signatures/data/services/signature_storage_service.dart:139-142`
- Test: extend the existing tests for each (find with `grep -rln "course" test/features/dive_log/query test/features/courses/query test/features/connections test/features/data_quality test/features/signatures`)

- [ ] **Step 1: Failing tests**

```dart
// dive query: dive v1 in courses c1 ('AN') and c2 ('DP').
// 'course.name:DP' matches v1; 'course.name:AN' matches v1; 'course:none'
// does not match v1; a dive with no courses matches 'course:none'.
// course query: course c2 'dives' relation counts v1.
// certification query: cert k1 with course_id c1 -> 'course.name:AN' matches.
// connections: v1 is a member of both course nodes.
// data quality: a dive whose only diver data is a course link reports
// has_course = 1 and carries diver data.
// signatures: a signature on v1 is returned for c1 and for c2.
```

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement**

Dives: `_junction('course', QuerySubject.courses, 'dive_courses', 'course_id', aliases: ['courses']),` in place of the `_fk` line. The key stays `course`, so saved queries keep working.

Courses:

```dart
    // The certification side is the truth since v288 (#2515).
    QueryRelation(
      key: 'certification',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.course_id = {from}.id',
      isMany: true,
      labelKey: 'query_courses_certification',
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.dive_id FROM dive_courses j '
          'WHERE j.course_id = {from}.id)',
      isMany: true,
      labelKey: 'query_courses_dives',
      tables: ['dive_courses'],
    ),
```

(`relations` is `const` today; drop `const` on the list if `tables:` needs a non-const list, or keep it `const ['dive_courses']`.)

Certifications:

```dart
    // The certification side is the truth since v288 (#2515).
    const QueryRelation(
      key: 'course',
      target: QuerySubject.courses,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.course_id',
      isMany: false,
      labelKey: 'query_certifications_course',
    ),
```

Connections: `ConnectionKind.course => 'SELECT dive_id, course_id AS entity_id FROM dive_courses',`, update the header comment (course becomes a junction kind), and add `TableUpdateQuery.onTable(_db.diveCourses),` to `watchConnectionsChanges`.

Data quality: `'OR EXISTS (SELECT 1 FROM dive_courses c WHERE c.dive_id = dives.id) '` in place of `'OR dives.course_id IS NOT NULL '`; `'EXISTS (SELECT 1 FROM dive_courses c WHERE c.dive_id = dives.id) AS has_course'` in place of `'(dives.course_id IS NOT NULL) AS has_course'`; add `db.diveCourses,` to `diverDataTables`.

Signatures:

```sql
SELECT m.* FROM media m
INNER JOIN dive_courses dc ON dc.dive_id = m.dive_id
WHERE dc.course_id = ? AND m.file_type = ?
ORDER BY m.taken_at DESC
```

- [ ] **Step 4: Run.** `flutter test test/features/dive_log/query test/features/courses test/features/certifications test/features/connections test/features/data_quality test/features/signatures test/features/explore test/core/query` Expected PASS (fix any pinned SQL snapshot or EXPLAIN QUERY PLAN test by updating its expectation to the junction form).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features test/features test/core
git commit -m "feat(courses): read a dive's courses through the junction everywhere"
```

---

### Task 7: UDDF export and import, universal import

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (~294 dive links; ~1534 course cert links; the course builder needs the certification list)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart:813-823` (`certificationRefs`)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1340` (`courseRefs`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_importCourses` takes `certIdMapping`; dive linking ~2680)
- Modify: `lib/features/universal_import/data/services/payload_ref_keys.dart` (`'courseRefs'` list ref)
- Modify: `lib/features/universal_import/data/services/payload_merger.dart` (`_namespaced` and `_rewriteAliases` for course certification refs)
- Test: extend `test/core/services/export/uddf/` round-trip tests, `test/features/universal_import/data/services/payload_merger_test.dart`

- [ ] **Step 1: Failing tests**

```dart
// export: a dive with courseIds [c1, c2] writes two <link ref="course_..."/>;
// a course with certs k1, k2 (course_id = it) writes two cert links.
// parser: a dive with two course links yields courseRefs [course_c1,
// course_c2] and courseRef course_c1; a course with two cert links yields
// certificationRefs [cert_k1, cert_k2] and certificationRef cert_k1.
// importer round-trip: export then import into an empty database -> the
// imported dive has two courses; the imported course has both certifications
// (certifications.course_id set) and the representative certification_id.
// merger: two files each with course c1 linking cert_k1 -> each merged course's
// certificationRefs are 'fileA:cert_k1' / 'fileB:cert_k1'; a dive's courseRefs
// are namespaced the same way.
```

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement**

Export, dive:

```dart
            // Course associations (one link per course, #2515)
            for (final courseId in dive.courseIds) {
              builder.element(
                'link',
                attributes: {'ref': 'course_$courseId'},
              );
            }
```

Export, course: thread the certifications already passed to the builder (check the builder's parameters; the certifications section at ~978 receives them) and emit `for (final cert in certifications.where((c) => c.courseId == course.id)) builder.element('link', attributes: {'ref': 'cert_${cert.id}'});` in place of the single `course.certificationId` link.

Parser: collect `final certRefs = <String>[];`, add each `cert_` ref, then `if (certRefs.isNotEmpty) { course['certificationRefs'] = certRefs; course['certificationRef'] = certRefs.first; }`.

Full import service dive links: `courseRefs.add(ref)` for `course_` refs, then after the loop `if (courseRefs.isNotEmpty) { diveData['courseRefs'] = courseRefs; diveData['courseRef'] = courseRefs.first; }`.

Importer: pass `certIdMapping` into `_importCourses` (new parameter after `buddyIdMapping`); after `createCourse`:

```dart
      // The certifications this course earned (#2515). Certifications are
      // imported before courses, so certIdMapping is complete here.
      final certRefs = [
        ...?(courseData['certificationRefs'] as List?)?.whereType<String>(),
        if (courseData['certificationRefs'] == null &&
            courseData['certificationRef'] is String)
          courseData['certificationRef'] as String,
      ];
      final certIds = [
        for (final ref in certRefs)
          if (certIdMapping[ref] != null) certIdMapping[ref]!,
      ];
      if (certIds.isNotEmpty) {
        await repository.setCourseCertifications(newId, certIds);
      }
```

Dive linking:

```dart
      final courseRefs = [
        ...?(diveData['courseRefs'] as List?)?.whereType<String>(),
        if (diveData['courseRefs'] == null && diveData['courseRef'] is String)
          diveData['courseRef'] as String,
      ];
      final linkedCourseIds = [
        for (final ref in courseRefs)
          if (courseIdMapping[ref] != null) courseIdMapping[ref]!,
      ];
```

and `courseIds: linkedCourseIds,` in the `Dive(...)`.

`payload_ref_keys.dart`: add `'courseRefs': ImportEntityType.courses,` to `diveListRefTypes`.

`payload_merger.dart` `_namespaced`: add

```dart
    if (type == ImportEntityType.courses) {
      final ref = item['certificationRef'];
      if (ref is String && ref.isNotEmpty) {
        item['certificationRef'] = '$fileId:$ref';
      }
      final refs = item['certificationRefs'];
      if (refs is List) {
        item['certificationRefs'] = [
          for (final r in refs)
            if (r is String && r.isNotEmpty) '$fileId:$r' else r,
        ];
      }
    }
```

and in `_rewriteAliases`, rewrite the same two course fields through `resolve` (read the method first and follow its dive-field loop).

- [ ] **Step 4: Run.** `flutter test test/core/services/export test/features/dive_import test/features/universal_import test/features/import_wizard` Expected PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "fix(courses): keep every course and earned certification through UDDF"
```

---

### Task 8: Course multi-select, dive editor and bulk editor

**Files:**
- Modify (rewrite): `lib/features/courses/presentation/widgets/course_picker.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state ~349, load ~966-1007, section ~3276-3309, save ~6149, invalidation ~6407-6423, bulk collections ~1826+, `_loadBulkMembers` ~4475, `_collectCollectionOps` ~1951, confirm summary ~2469)
- Modify: ARB files (Task 10 adds every string; add the English keys here as you use them and run `flutter gen-l10n`)
- Test: rewrite `test/features/courses/presentation/widgets/course_picker_test.dart` (find its real path), extend the dive edit page course tests

**Interfaces:**
- Produces: `class CourseMultiSelectField extends ConsumerWidget { const CourseMultiSelectField({super.key, required List<String> selectedCourseIds, required ValueChanged<List<String>> onChanged}); }` and `Future<void> showCourseMultiPickerSheet(BuildContext context, {required List<String> selectedCourseIds, required ValueChanged<List<String>> onChanged})`.

- [ ] **Step 1: Failing widget tests**

```dart
testWidgets('shows a chip per selected course', ...);
testWidgets('the sheet toggles courses and stays open', ...);
// open sheet, tick 'AN' and 'DP' -> onChanged received ['AN-id'] then
// ['AN-id','DP-id']; the sheet is still visible until Done is tapped.
testWidgets('a chip delete removes that course only', ...);
testWidgets('dive editor saves two courses', ...);
testWidgets('bulk editor adds a course to every selected dive', ...);
```

Use the provider override helpers the existing `course_picker` and dive-edit tests use.

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement the field and sheet**

Model on `DiveTypeMultiSelectField` (`lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart`): an `InkWell` around an `InputDecorator` holding a `Wrap` of `InputChip`s (one per selected course, `onDeleted` removes it, `avatar: Icon(Icons.school, size: 16)`), and an empty-state hint (`courses_picker_tapToLink`). Tapping opens `showModalBottomSheet(isScrollControlled: true, showDragHandle: true)` with a stateful sheet that keeps a `_working` list, a title row (`courses_picker_selectCoursesTitle`, a "New course" button as today, and a `courses_picker_done` `TextButton` that pops), and `CheckboxListTile` rows sorted in-progress first then `startDate` descending (keep today's `courses_picker_active` badge as `secondary`). Each toggle calls `onChanged` immediately, so closing by drag keeps the selection. Keep every `Semantics` label the old sheet set.

- [ ] **Step 4: Dive editor**

Replace `Course? _selectedCourse` with `List<String> _selectedCourseIds = const [];`. Load from `dive.courseIds`. `_showCourseSection => _selectedCourseIds.isNotEmpty || _expanded['course'] == true`. The section uses `diveLog_edit_section_trainingCourses`, summary = the selected course names joined with ', ' (read names from `courseListNotifierProvider`), and child `CourseMultiSelectField(selectedCourseIds: _selectedCourseIds, onChanged: (ids) { _markDirty(); setState(() => _selectedCourseIds = ids); })`. Save: `courseIds: _selectedCourseIds`. Invalidation: for every id in old union new, invalidate `courseDivesProvider(id)` and `courseDiveCountProvider(id)`, plus `coursesForDiveProvider(savedDiveId)`.

Bulk: mirror the dive-types membership editor. Add state `Map<String, int> _courseCounts = {}`, `List<BulkMembershipItem> _courseMembers = []`, `MembershipDelta _courseDelta = MembershipDelta.empty`; load counts with `repo.courseCountsForDives(ids)` in `_loadBulkMembers` and names from `courseListNotifierProvider`; render a `BulkMembershipEditor(title: l10n.diveLog_edit_section_trainingCourses, ..., onAdd: _bulkAddCourses, onChanged: (d) => setState(() => _courseDelta = d))` with `Icons.school`; `_bulkAddCourses` opens the multi-select sheet and appends picked ids as members; `_collectCollectionOps` emits `DiveCoursesOp(add, _courseDelta.addIds)` and `DiveCoursesOp(remove, _courseDelta.removeIds)`; add the courses entry to `summarizeBulkMembership`.

- [ ] **Step 5: Run.** `flutter analyze && flutter test test/features/courses/presentation test/features/dive_log/presentation/pages` Expected PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(courses): pick several courses for a dive"
```

---

### Task 9: Dive detail page

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_course_rows.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (784, 1041, 3266, `_buildCourseRow` 4521-4576 removed, signature header 5046-5110, `_buildAddSignatureButton` 5160, `_showSignatureCapture` 5216)
- Test: `test/features/dive_log/presentation/pages/dive_detail_course_row_test.dart` (extend)

**Interfaces:**
- Produces: `class DiveCourseRows extends ConsumerWidget { const DiveCourseRows({super.key, required String diveId}); }` and `class DiveCourseChips extends ConsumerWidget { const DiveCourseChips({super.key, required String diveId}); }`.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('a dive in two courses shows a row per course', ...);
// both names visible; tapping the second pushes '/courses/<second id>'.
testWidgets('the signature header shows a chip per course', ...);
testWidgets('signature capture prefills the first course instructor', ...);
testWidgets('a dive with no course shows no course row', ...);
```

At 732 px wide (half-width card) and phone width, per the side-by-side pairing rule.

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement**

`DiveCourseRows` watches `coursesForDiveProvider(diveId)`; empty or loading renders `SizedBox.shrink()`. Otherwise a `Column` whose first row has the `diveLog_edit_section_trainingCourses` label on the left (only the first row carries the label; later rows leave it blank) and each row keeps the exact structure of today's `_buildCourseRow` (Semantics button with `diveLog_detail_semantics_viewCourse(name)`, `InkWell` pushing `/courses/<id>`, ellipsized name, chevron). `DiveCourseChips` renders a `Wrap(spacing: 4, runSpacing: 4)` of today's tappable school-icon chips, one per course.

In the page: gates use `dive.courseIds.isNotEmpty`; `if (dive.courseIds.isNotEmpty) DiveCourseRows(diveId: dive.id),`; the signature header's single chip becomes `DiveCourseChips(diveId: dive.id)` inside the existing `Flexible`; the two instructor reads use `ref.watch(coursesForDiveProvider(dive.id)).valueOrNull?.firstOrNull` (the representative course's instructor, a documented rule: `// The representative course's instructor signs (#2515).`).

- [ ] **Step 4: Run.** `flutter test test/features/dive_log/presentation` Expected PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(courses): show every course on the dive detail page"
```

---

### Task 10: Course editor, course detail and certification detail

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_multi_select_field.dart`
- Modify: `lib/features/courses/presentation/pages/course_edit_page.dart` (53, 83-96, 268-297, 444, 471-483)
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart` (158-160, 428-513)
- Modify: `lib/features/certifications/presentation/widgets/certification_picker.dart` (delete if no caller remains; check with grep)
- Test: `test/features/certifications/presentation/widgets/certification_multi_select_field_test.dart`, extend the course edit and detail page tests

**Interfaces:**
- Consumes: `certificationsForCourseProvider`, `CourseListNotifier.setCourseCertifications`, `Certification.courseId` (Task 4).
- Produces: `class CertificationMultiSelectField extends ConsumerWidget { const CertificationMultiSelectField({super.key, required String? courseId, required List<String> selectedCertificationIds, required ValueChanged<List<String>> onChanged}); }`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('shows a chip per selected certification', ...);
testWidgets('a certification linked to another course shows Linked to', ...);
// cert k3.courseId == 'other' whose name is 'Rescue' -> subtitle contains
// 'Linked to: Rescue'; k1.courseId == this course -> no hint.
testWidgets('course editor saves two certifications', ...);
// after save: setCourseCertifications called with [k1, k2].
testWidgets('course detail lists each earned certification', ...);
testWidgets('certification detail shows the course from the cert side', ...);
```

- [ ] **Step 2: Run, confirm failure.**

- [ ] **Step 3: Implement**

The field mirrors `CourseMultiSelectField`: chips titled with `certificationTitleL10n(cert, l10n, catalog: context.certificationCatalog)`; the sheet keeps today's `CertificationPickerSheet` content (title `certifications_picker_selectTitle`, "New certification" button, empty state, issue-date-descending sort, expired badge, semantics label) but with `CheckboxListTile` rows. A row's subtitle appends `courses_picker_linkedTo(courseName)` when `cert.courseId != null && cert.courseId != courseId`, with the course name read from `courseListNotifierProvider`.

Course editor: replace `_selectedCertification` with `List<String> _selectedCertificationIds = const []`, loaded once from `certificationsForCourseProvider(course.id).future` in `_initializeFromCourse`. The section header uses `courses_section_earnedCertifications` and the hint `courses_field_linkCertificationsHint`. Save: build `Course` without `certificationId`; after add/update, `await notifier.setCourseCertifications(savedId, _selectedCertificationIds);` (always, so unticking clears). Remove the old link/unlink block.

Course detail: `final certs = ref.watch(certificationsForCourseProvider(course.id)).valueOrNull ?? const [];` and `if (certs.isNotEmpty) _buildCertificationSection(context, certs),` where the section keeps its card and header (`courses_section_earnedCertifications`) and renders one of today's `ListTile`s per certification, adding the card number to the subtitle when present (`'${agencyName} - ${cert.cardNumber}'`).

Certification detail: unchanged code; `courseForCertificationProvider` already reads the certification side (Task 4).

- [ ] **Step 4: Run.** `flutter analyze && flutter test test/features/courses test/features/certifications` Expected PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(courses): pick several earned certifications for a course"
```

---

### Task 11: Localization and full verification

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (all 11 locales), generated `app_localizations*.dart`

New keys (English; translate into ar, de, es, fr, he, hu, it, nl, pt, zh):

| Key | English | Notes |
| --- | --- | --- |
| `diveLog_edit_section_trainingCourses` | Training Courses | Dive editor section, bulk title, detail label |
| `courses_section_earnedCertifications` | Earned Certifications | Course editor and detail |
| `courses_field_linkCertificationsHint` | Link the certifications earned from this course | Course editor |
| `courses_picker_selectCoursesTitle` | Select Courses | Course sheet title |
| `courses_picker_done` | Done | Sheet close |
| `courses_picker_linkedTo` | Linked to: {courseName} | Placeholder `courseName` (String) |
| `certifications_picker_selectTitle` | Select Certifications | Certification sheet title |

Remove keys left with no caller (`courses_section_earnedCertification`, `courses_field_linkCertificationHint`, `diveLog_edit_section_trainingCourse` if unused, `courses_picker_selectTitle`, `certifications_picker_sheetTitle`) from every locale, unless a grep shows another caller. Read `INDEX_L10N` memory cues and `docs/developer/` l10n notes before editing ARB files.

- [ ] **Step 1:** Add the keys, `@` descriptions in `app_en.arb`, translations in every locale; `flutter gen-l10n`.
- [ ] **Step 2:** `dart format .`
- [ ] **Step 3:** `flutter analyze` (expected: no issues)
- [ ] **Step 4:** `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database test/core/services/sync test/features/courses test/features/certifications test/features/dive_log test/features/dive_import test/features/universal_import test/features/connections test/features/data_quality test/features/signatures test/features/settings/presentation/conflicts`, logging to the scratchpad. Expected: all PASS.
- [ ] **Step 5:** Commit

```bash
git add lib/l10n test
git commit -m "feat(courses): localize multiple courses and certifications"
```
