# Course Requirement Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track countable course requirements (AOW's five adventure dives, Rescue prerequisites) against the logbook, with editable per-course requirement rows, explicit dive↔requirement links, starter templates, and progress surfaced on the course detail page and dashboard.

**Architecture:** Two new Drift tables at schema v112 — `course_requirements` (HLC merge-root child of `courses`) and `course_requirement_dives` (clockless junction with deterministic ids, parent-HLC-gated sync). Progress is always computed at read time, never stored. Templates are Dart constants copied into rows at instantiation. Repository + FutureProvider/`invalidateSelfWhen` reactive pattern throughout.

**Tech Stack:** Flutter 3.x / Material 3, Drift ORM, Riverpod, go_router, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-16-course-requirement-tracker-design.md`

## Refinements vs the spec (discovered during codebase survey; all approved patterns)

1. **Junction has NO `hlc` column and NO unique index.** Its `id` is a deterministic UUIDv5 of `(requirementId, diveId)`, so the same link made on two devices converges to one row under sync upsert (the PK dedupes; a unique index would be redundant). Delta export is gated by the parent requirement's `hlc`, which `linkDive`/`unlinkDive` bump — the exact `equipment_set_items` pattern.
2. **Suggestions include dives already assigned to the course** via the existing `dives.course_id` FK (v-old feature), plus dives dated on/after `courses.start_date`. `start_date` is a non-null column, so the spec's "60-day fallback" is dropped.
3. **Drift data classes are named `CourseRequirementRow` / `CourseRequirementDiveRow`** via `@DataClassName`, avoiding a clash with the domain entity `CourseRequirement` (same trick as `DiveRoleRow`).
4. **`CourseRepository.deleteCourse` must be extended**: FK cascade will delete the new child rows, but sync needs per-row tombstones for them (issue #466 lesson) or another device resurrects them.
5. **UDDF full export/import registration is deferred** (out of scope). Backups are whole-file SQLite copies and cover the new tables automatically with zero registration.
6. **Template content (requirement names) is data, not UI strings** — copied into user rows in English, like built-in reference data. Only chrome (buttons, headers, sheets) is localized.

## Global Constraints

- Working directory: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/cert-requirement-tracker` (worktree, branch `worktree-cert-requirement-tracker`). Never touch the main checkout.
- Schema version: exactly **112**. If `currentSchemaVersion` in `lib/core/database/database.dart` is no longer 111 when you start, STOP and report — another branch claimed v112.
- TDD: every task writes its failing test first.
- All new user-visible strings: add to `lib/l10n/arb/app_en.arb` AND all 10 other locales (`ar de es fr he hu it nl pt zh`), then run `flutter gen-l10n`.
- No emojis anywhere. `dart format .` before every commit. Run `flutter analyze` without piping through `tail`/`grep` (masking trap).
- Run tests as specific files (`flutter test test/path/file_test.dart`), never the whole suite mid-task (timeout trap).
- Commit messages: plain conventional commits, no Co-Authored-By, no session URLs.
- After editing `lib/core/database/database.dart` table definitions: run `dart run build_runner build --delete-conflicting-outputs` before anything imports the generated classes.

---

### Task 1: Schema v112 — tables, migration, backstop

**Files:**
- Modify: `lib/core/database/database.dart` (4 places: table defs after `Courses` ~line 2033; `@DriftDatabase` tables list ~line 2161; `currentSchemaVersion` line 2207 + `migrationVersions` list; `onUpgrade` after the v111 block ~line 5529; `beforeOpen` backstop ~line 5558)
- Test: `test/core/database/course_requirements_schema_test.dart`

**Interfaces:**
- Produces: Drift tables `courseRequirements` / `courseRequirementDives`; generated classes `CourseRequirementRow`, `CourseRequirementsCompanion`, `CourseRequirementDiveRow`, `CourseRequirementDivesCompanion`. Columns as defined below (snake_case in SQL: `course_id`, `target_count`, `completed_at`, `sort_order`, `requirement_id`, `dive_id`).

- [ ] **Step 1: Write the failing schema test**

Create `test/core/database/course_requirements_schema_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

Future<Set<String>> _columns(String table) async {
  final db = DatabaseService.instance.database;
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.data['name'] as String).toSet();
}

Future<void> _seedCourseFixture() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_datetime, created_at, updated_at) "
    "VALUES ('dive-1', 'diver-1', 2000, 1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('v112 course requirement schema', () {
    test('course_requirements has the expected columns', () async {
      final cols = await _columns('course_requirements');
      expect(
        cols,
        containsAll({
          'id',
          'course_id',
          'name',
          'kind',
          'target_count',
          'completed_at',
          'sort_order',
          'notes',
          'created_at',
          'updated_at',
          'hlc',
        }),
      );
    });

    test('course_requirement_dives has the expected columns and no hlc',
        () async {
      final cols = await _columns('course_requirement_dives');
      expect(
        cols,
        containsAll({'id', 'requirement_id', 'dive_id', 'created_at'}),
      );
      expect(cols, isNot(contains('hlc')));
    });

    test('deleting a course cascades requirements and links', () async {
      final db = DatabaseService.instance.database;
      await _seedCourseFixture();
      await db.customStatement(
        "INSERT INTO course_requirements (id, course_id, name, kind, "
        "target_count, sort_order, created_at, updated_at) "
        "VALUES ('req-1', 'course-1', 'Deep adventure dive', 'dive', 1, 0, "
        "1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO course_requirement_dives (id, requirement_id, dive_id, "
        "created_at) VALUES ('link-1', 'req-1', 'dive-1', 1000)",
      );

      await db.customStatement("DELETE FROM courses WHERE id = 'course-1'");

      final reqs = await db
          .customSelect('SELECT COUNT(*) AS c FROM course_requirements')
          .getSingle();
      final links = await db
          .customSelect('SELECT COUNT(*) AS c FROM course_requirement_dives')
          .getSingle();
      expect(reqs.data['c'], 0);
      expect(links.data['c'], 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/course_requirements_schema_test.dart`
Expected: FAIL — `no such table: course_requirements`.

- [ ] **Step 3: Add the table definitions**

In `lib/core/database/database.dart`, immediately after the `Courses` table's closing brace (~line 2033), add:

```dart
/// Countable requirements for a training course (requirement tracker spec,
/// docs/superpowers/specs/2026-07-16-course-requirement-tracker-design.md).
/// kind is a RequirementKind enum name: 'dive' rows derive progress from
/// course_requirement_dives links; 'checklist' rows complete via completedAt.
@DataClassName('CourseRequirementRow')
class CourseRequirements extends Table {
  TextColumn get id => text()();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get targetCount => integer().withDefault(const Constant(1))();
  IntColumn get completedAt => integer().nullable()(); // Unix ms, checklist
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction crediting a logged dive toward a course requirement.
///
/// The id is a DETERMINISTIC UUIDv5 of (requirementId, diveId) -- see
/// CourseRequirementRepository.linkIdFor -- so the same link created on two
/// devices converges to a single row under sync upsert; no unique index is
/// needed. No hlc column: delta export is gated by the parent requirement's
/// hlc, which linkDive/unlinkDive bump (equipment_set_items pattern).
@DataClassName('CourseRequirementDiveRow')
class CourseRequirementDives extends Table {
  TextColumn get id => text()();
  TextColumn get requirementId => text()
      .references(CourseRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Register the tables and bump the version**

Still in `database.dart`:

a. In the `@DriftDatabase(tables: [...])` list, after the `Courses,` entry (~line 2161), add:

```dart
    // Course requirement tracker (v112)
    CourseRequirements,
    CourseRequirementDives,
```

b. Change line 2207: `static const int currentSchemaVersion = 111;` → `static const int currentSchemaVersion = 112;`

c. In the `migrationVersions` list (starts ~line 2212), append `112,` after the final existing entry (`111,`).

d. In `onUpgrade`, directly after the `if (from < 111) await reportProgress();` line (~line 5529), add:

```dart
        if (from < 112) {
          // Course requirement tracker: both tables are new, no data
          // migration. createTable is idempotent (IF NOT EXISTS).
          await m.createTable(courseRequirements);
          await m.createTable(courseRequirementDives);
        }
        if (from < 112) await reportProgress();
```

e. In `beforeOpen`, after the v111 backstop call to `_assertEquipmentSetDefaultAndGeofenceSchema()` (~line 5558), add:

```dart
        // v112 backstop: course requirement tables (parallel-branch
        // collision self-heal; createTable is idempotent).
        await createMigrator().createTable(courseRequirements);
        await createMigrator().createTable(courseRequirementDives);
```

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0; `database.g.dart` now contains `CourseRequirementRow` and `CourseRequirementDiveRow`.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/core/database/course_requirements_schema_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): add course_requirements and course_requirement_dives tables (v112)"
```

---

### Task 2: Domain entities

**Files:**
- Create: `lib/features/courses/domain/entities/course_requirement.dart`
- Create: `lib/features/courses/domain/entities/course_progress.dart`
- Test: `test/features/courses/domain/course_requirement_test.dart`

**Interfaces:**
- Produces:
  - `enum RequirementKind { dive, checklist }` with `static RequirementKind fromName(String? name)` (defaults to `dive`).
  - `class CourseRequirement` — fields `String id, String courseId, String name, RequirementKind kind, int targetCount, DateTime? completedAt, int sortOrder, String? notes, DateTime createdAt, DateTime updatedAt`; `copyWith`; `clearCompletedAt()`.
  - `class RequirementDiveSummary` — `String? linkId` (null for suggestions), `String diveId`, `int? diveNumber`, `DateTime dateTime`, `String? siteName`.
  - `class CourseRequirementProgress` — `CourseRequirement requirement`, `List<RequirementDiveSummary> linkedDives`; getters `creditCount`, `isSatisfied`.
  - `class CourseProgress` — `String courseId`, `List<CourseRequirementProgress> requirements`; getters `satisfiedCount`, `totalCount`, `isComplete`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/courses/domain/course_requirement_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

CourseRequirement _req({
  RequirementKind kind = RequirementKind.dive,
  int targetCount = 1,
  DateTime? completedAt,
}) {
  return CourseRequirement(
    id: 'req-1',
    courseId: 'course-1',
    name: 'Deep adventure dive',
    kind: kind,
    targetCount: targetCount,
    completedAt: completedAt,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

RequirementDiveSummary _dive(String id) => RequirementDiveSummary(
      linkId: 'link-$id',
      diveId: id,
      diveNumber: 1,
      dateTime: DateTime(2026, 7, 1),
      siteName: 'Blue Hole',
    );

void main() {
  group('RequirementKind.fromName', () {
    test('parses known names and defaults unknown to dive', () {
      expect(RequirementKind.fromName('checklist'), RequirementKind.checklist);
      expect(RequirementKind.fromName('dive'), RequirementKind.dive);
      expect(RequirementKind.fromName('garbage'), RequirementKind.dive);
      expect(RequirementKind.fromName(null), RequirementKind.dive);
    });
  });

  group('CourseRequirementProgress.isSatisfied', () {
    test('dive kind satisfied only at targetCount links', () {
      final p2of3 = CourseRequirementProgress(
        requirement: _req(targetCount: 3),
        linkedDives: [_dive('d1'), _dive('d2')],
      );
      expect(p2of3.creditCount, 2);
      expect(p2of3.isSatisfied, isFalse);

      final p3of3 = CourseRequirementProgress(
        requirement: _req(targetCount: 3),
        linkedDives: [_dive('d1'), _dive('d2'), _dive('d3')],
      );
      expect(p3of3.isSatisfied, isTrue);
    });

    test('checklist kind ignores links, satisfied by completedAt', () {
      final unchecked = CourseRequirementProgress(
        requirement: _req(kind: RequirementKind.checklist),
        linkedDives: [_dive('d1')],
      );
      expect(unchecked.isSatisfied, isFalse);

      final checked = CourseRequirementProgress(
        requirement: _req(
          kind: RequirementKind.checklist,
          completedAt: DateTime(2026, 7, 1),
        ),
        linkedDives: const [],
      );
      expect(checked.isSatisfied, isTrue);
    });
  });

  group('CourseProgress', () {
    test('rolls up satisfied counts; empty course is not complete', () {
      final progress = CourseProgress(
        courseId: 'course-1',
        requirements: [
          CourseRequirementProgress(
            requirement: _req(),
            linkedDives: [_dive('d1')],
          ),
          CourseRequirementProgress(
            requirement: _req(kind: RequirementKind.checklist),
            linkedDives: const [],
          ),
        ],
      );
      expect(progress.satisfiedCount, 1);
      expect(progress.totalCount, 2);
      expect(progress.isComplete, isFalse);

      const empty = CourseProgress(courseId: 'course-1', requirements: []);
      expect(empty.isComplete, isFalse);
    });
  });

  group('CourseRequirement copyWith', () {
    test('copyWith preserves and clearCompletedAt clears', () {
      final req = _req(
        kind: RequirementKind.checklist,
        completedAt: DateTime(2026, 7, 1),
      );
      final renamed = req.copyWith(name: 'Knowledge development');
      expect(renamed.name, 'Knowledge development');
      expect(renamed.completedAt, req.completedAt);

      final cleared = req.clearCompletedAt();
      expect(cleared.completedAt, isNull);
      expect(cleared.name, req.name);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/courses/domain/course_requirement_test.dart`
Expected: FAIL — missing imports/classes.

- [ ] **Step 3: Implement the entities**

Create `lib/features/courses/domain/entities/course_requirement.dart`:

```dart
import 'package:equatable/equatable.dart';

/// The two shapes a course requirement can take.
enum RequirementKind {
  /// Progress derives from dives linked via course_requirement_dives.
  dive,

  /// Manual check-off (knowledge development, EFR prerequisite, swim test).
  checklist;

  static RequirementKind fromName(String? name) =>
      RequirementKind.values.asNameMap()[name] ?? RequirementKind.dive;
}

/// One countable requirement of a training course, e.g. "Deep adventure
/// dive" (dive, target 1) or "Knowledge development" (checklist).
class CourseRequirement extends Equatable {
  final String id;
  final String courseId;
  final String name;
  final RequirementKind kind;
  final int targetCount;
  final DateTime? completedAt;
  final int sortOrder;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseRequirement({
    required this.id,
    required this.courseId,
    required this.name,
    required this.kind,
    this.targetCount = 1,
    this.completedAt,
    this.sortOrder = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  CourseRequirement copyWith({
    String? id,
    String? courseId,
    String? name,
    RequirementKind? kind,
    int? targetCount,
    DateTime? completedAt,
    int? sortOrder,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseRequirement(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      targetCount: targetCount ?? this.targetCount,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// copyWith cannot null out completedAt; unchecking a checklist item
  /// goes through this instead (same pattern as Course.clearCompletionDate).
  CourseRequirement clearCompletedAt() {
    return CourseRequirement(
      id: id,
      courseId: courseId,
      name: name,
      kind: kind,
      targetCount: targetCount,
      completedAt: null,
      sortOrder: sortOrder,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        name,
        kind,
        targetCount,
        completedAt,
        sortOrder,
        notes,
        createdAt,
        updatedAt,
      ];
}
```

Create `lib/features/courses/domain/entities/course_progress.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// A dive shown in the requirement tracker: either credited to a
/// requirement (linkId set) or offered as a suggestion (linkId null).
class RequirementDiveSummary extends Equatable {
  final String? linkId;
  final String diveId;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;

  const RequirementDiveSummary({
    this.linkId,
    required this.diveId,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
  });

  @override
  List<Object?> get props => [linkId, diveId, diveNumber, dateTime, siteName];
}

/// A requirement plus its credited dives. Progress is derived, never stored:
/// stored counters would need cross-device conflict resolution, derived
/// counts just merge junction rows and recompute.
class CourseRequirementProgress extends Equatable {
  final CourseRequirement requirement;
  final List<RequirementDiveSummary> linkedDives;

  const CourseRequirementProgress({
    required this.requirement,
    required this.linkedDives,
  });

  int get creditCount => linkedDives.length;

  bool get isSatisfied => requirement.kind == RequirementKind.checklist
      ? requirement.completedAt != null
      : creditCount >= requirement.targetCount;

  @override
  List<Object?> get props => [requirement, linkedDives];
}

/// Roll-up of all requirements of one course.
class CourseProgress extends Equatable {
  final String courseId;
  final List<CourseRequirementProgress> requirements;

  const CourseProgress({required this.courseId, required this.requirements});

  int get satisfiedCount => requirements.where((r) => r.isSatisfied).length;

  int get totalCount => requirements.length;

  bool get isComplete => totalCount > 0 && satisfiedCount == totalCount;

  @override
  List<Object?> get props => [courseId, requirements];
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/courses/domain/course_requirement_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): course requirement domain entities and progress roll-up"
```

---

### Task 3: Template catalog

**Files:**
- Create: `lib/core/constants/course_templates.dart`
- Test: `test/core/constants/course_templates_test.dart`

**Interfaces:**
- Consumes: `RequirementKind` from Task 2.
- Produces: `class CourseTemplateRequirement { final String name; final RequirementKind kind; final int targetCount; }`, `class CourseTemplate { final String id; final String name; final List<CourseTemplateRequirement> requirements; }`, `abstract final class CourseTemplateCatalog { static const List<CourseTemplate> templates; }`.

- [ ] **Step 1: Write the failing test**

Create `test/core/constants/course_templates_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

void main() {
  group('CourseTemplateCatalog', () {
    test('has unique template ids and non-empty requirement lists', () {
      final ids = CourseTemplateCatalog.templates.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final template in CourseTemplateCatalog.templates) {
        expect(template.requirements, isNotEmpty,
            reason: '${template.id} has no requirements');
        for (final req in template.requirements) {
          expect(req.name.trim(), isNotEmpty);
          expect(req.targetCount, greaterThanOrEqualTo(1));
        }
      }
    });

    test('AOW template models five adventure dives plus knowledge', () {
      final aow = CourseTemplateCatalog.templates
          .firstWhere((t) => t.id == 'advanced-open-water');
      final diveTotal = aow.requirements
          .where((r) => r.kind == RequirementKind.dive)
          .fold<int>(0, (sum, r) => sum + r.targetCount);
      expect(diveTotal, 5);
      expect(
        aow.requirements.any((r) => r.kind == RequirementKind.checklist),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/constants/course_templates_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the catalog**

Create `lib/core/constants/course_templates.dart`:

```dart
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// One requirement row a template will copy into course_requirements.
class CourseTemplateRequirement {
  final String name;
  final RequirementKind kind;
  final int targetCount;

  const CourseTemplateRequirement(
    this.name,
    this.kind, [
    this.targetCount = 1,
  ]);
}

/// A starter set of requirements for a common course. Templates are a copy
/// source only: picking one inserts ordinary editable rows and the template
/// carries no identity into the database. Requirement names are data (they
/// become user-owned rows), so they are deliberately not localized --
/// mirroring built-in reference data seeds.
class CourseTemplate {
  final String id;
  final String name;
  final List<CourseTemplateRequirement> requirements;

  const CourseTemplate({
    required this.id,
    required this.name,
    required this.requirements,
  });
}

/// Agency-neutral starter templates (PADI-shaped counts, editable after
/// instantiation). Deliberately NOT authoritative curricula: agencies revise
/// standards and vary by region, so these are conveniences, never truth.
abstract final class CourseTemplateCatalog {
  static const List<CourseTemplate> templates = [
    CourseTemplate(
      id: 'advanced-open-water',
      name: 'Advanced Open Water',
      requirements: [
        CourseTemplateRequirement('Deep adventure dive', RequirementKind.dive),
        CourseTemplateRequirement(
          'Navigation adventure dive',
          RequirementKind.dive,
        ),
        CourseTemplateRequirement(
          'Elective adventure dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'rescue-diver',
      name: 'Rescue Diver',
      requirements: [
        CourseTemplateRequirement(
          'EFR / CPR certification current',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Self-rescue review',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Rescue exercise dives',
          RequirementKind.dive,
          2,
        ),
        CourseTemplateRequirement(
          'Rescue scenario dives',
          RequirementKind.dive,
          2,
        ),
      ],
    ),
    CourseTemplate(
      id: 'deep-specialty',
      name: 'Deep Diver',
      requirements: [
        CourseTemplateRequirement(
          'Deep training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'night-specialty',
      name: 'Night Diver',
      requirements: [
        CourseTemplateRequirement(
          'Night training dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'navigation-specialty',
      name: 'Underwater Navigator',
      requirements: [
        CourseTemplateRequirement(
          'Navigation training dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'nitrox',
      name: 'Enriched Air Nitrox',
      requirements: [
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Practical application session',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'cavern-intro',
      name: 'Cavern / Intro to Cave',
      requirements: [
        CourseTemplateRequirement(
          'Cavern training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Line and reel drills',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'wreck-specialty',
      name: 'Wreck Diver',
      requirements: [
        CourseTemplateRequirement(
          'Wreck training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
  ];
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/constants/course_templates_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): course requirement starter template catalog"
```

---

### Task 4: Repository

**Files:**
- Create: `lib/features/courses/data/repositories/course_requirement_repository.dart`
- Modify: `lib/features/courses/data/repositories/course_repository.dart` (extend `deleteCourse` with child tombstones — find the existing `deleteCourse` method)
- Test: `test/features/courses/data/repositories/course_requirement_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 generated classes, Task 2 entities, Task 3 `CourseTemplate`.
- Produces (all on `class CourseRequirementRepository`):
  - `static String linkIdFor(String requirementId, String diveId)`
  - `Stream<void> watchRequirementsChanges()`
  - `Future<CourseProgress> getCourseProgress(String courseId)`
  - `Future<CourseRequirement> createRequirement({required String courseId, required String name, required RequirementKind kind, int targetCount = 1, String? notes})`
  - `Future<void> updateRequirement(CourseRequirement requirement)`
  - `Future<void> setChecklistComplete(String id, bool complete)`
  - `Future<void> deleteRequirement(String id)`
  - `Future<void> applyTemplate(String courseId, CourseTemplate template)`
  - `Future<void> linkDive({required String requirementId, required String diveId})`
  - `Future<void> unlinkDive({required String requirementId, required String diveId})`
  - `Future<List<RequirementDiveSummary>> getSuggestedDives(String courseId)`

Sync side-effects (contract with Task 5): every requirement write calls `markRecordPending(entityType: 'courseRequirements', ...)`; link/unlink additionally bump the PARENT requirement (updatedAt + markRecordPending) because junction delta export is gated on the parent's hlc; deletes log per-row tombstones for entityTypes `'courseRequirements'` and `'courseRequirementDives'`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/courses/data/repositories/course_requirement_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

import '../../../../helpers/test_database.dart';

Future<void> _seedDiverAndCourse({int startDate = 5000}) async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', $startDate, 1000, 1000)",
  );
}

Future<void> _seedDive(
  String id, {
  int dateTime = 9000,
  String diverId = 'diver-1',
  String? courseId,
  String? siteId,
}) async {
  final db = DatabaseService.instance.database;
  final courseCol = courseId != null ? "'$courseId'" : 'NULL';
  final siteCol = siteId != null ? "'$siteId'" : 'NULL';
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_datetime, course_id, site_id, "
    "created_at, updated_at) "
    "VALUES ('$id', '$diverId', $dateTime, $courseCol, $siteCol, 1000, 1000)",
  );
}

void main() {
  late CourseRequirementRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CourseRequirementRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('requirement CRUD', () {
    test('create assigns uuid, sortOrder increments per course', () async {
      await _seedDiverAndCourse();
      final first = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final second = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      expect(first.id.length, 36);
      expect(second.sortOrder, greaterThan(first.sortOrder));

      final progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, 2);
      expect(progress.requirements.first.requirement.name,
          'Deep adventure dive');
    });

    test('setChecklistComplete sets and clears completedAt', () async {
      await _seedDiverAndCourse();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      var progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.isSatisfied, isTrue);

      await repository.setChecklistComplete(req.id, false);
      progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.isSatisfied, isFalse);
    });

    test('deleteRequirement removes row and logs tombstones for links',
        () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      await repository.deleteRequirement(req.id);

      final progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements, isEmpty);

      final db = DatabaseService.instance.database;
      final tombstones = await db.customSelect(
        "SELECT entity_type, record_id FROM deletion_log "
        "ORDER BY entity_type",
      ).get();
      final types =
          tombstones.map((r) => r.data['entity_type'] as String).toList();
      expect(types, contains('courseRequirements'));
      expect(types, contains('courseRequirementDives'));
    });
  });

  group('applyTemplate', () {
    test('copies all rows in order and appends on second apply', () async {
      await _seedDiverAndCourse();
      final aow = CourseTemplateCatalog.templates
          .firstWhere((t) => t.id == 'advanced-open-water');
      await repository.applyTemplate('course-1', aow);
      var progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, aow.requirements.length);
      expect(progress.requirements.first.requirement.name,
          aow.requirements.first.name);

      await repository.applyTemplate('course-1', aow);
      progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, aow.requirements.length * 2);
    });
  });

  group('linkDive / unlinkDive', () {
    test('link credits dive with deterministic id; relink is a no-op',
        () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Elective adventure dives',
        kind: RequirementKind.dive,
        targetCount: 3,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');

      final progress = await repository.getCourseProgress('course-1');
      final reqProgress = progress.requirements.single;
      expect(reqProgress.creditCount, 1);
      expect(reqProgress.linkedDives.single.linkId,
          CourseRequirementRepository.linkIdFor(req.id, 'dive-1'));
      expect(reqProgress.isSatisfied, isFalse);
    });

    test('unlink removes credit and logs junction tombstone', () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      await repository.unlinkDive(requirementId: req.id, diveId: 'dive-1');

      final progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.creditCount, 0);

      final db = DatabaseService.instance.database;
      final tombstones = await db.customSelect(
        "SELECT record_id FROM deletion_log "
        "WHERE entity_type = 'courseRequirementDives'",
      ).get();
      expect(tombstones.single.data['record_id'],
          CourseRequirementRepository.linkIdFor(req.id, 'dive-1'));
    });

    test('linking bumps the parent requirement updatedAt (sync gate)',
        () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "UPDATE course_requirements SET updated_at = 1 WHERE id = '${req.id}'",
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      final row = await db
          .customSelect(
            "SELECT updated_at FROM course_requirements "
            "WHERE id = '${req.id}'",
          )
          .getSingle();
      expect(row.data['updated_at'] as int, greaterThan(1));
    });
  });

  group('getSuggestedDives', () {
    test('suggests course-assigned and post-start dives, excludes linked '
        'and other-diver dives, newest first, capped at 10', () async {
      await _seedDiverAndCourse(startDate: 5000);
      await _seedDive('before-start', dateTime: 4000);
      await _seedDive('after-start', dateTime: 6000);
      await _seedDive('assigned-old', dateTime: 3000, courseId: 'course-1');
      await _seedDive('other-diver', dateTime: 7000, diverId: 'diver-2');
      await _seedDive('linked', dateTime: 8000);

      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-2', 'Other', 1000, 1000)",
      );

      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'linked');

      final suggested = await repository.getSuggestedDives('course-1');
      final ids = suggested.map((s) => s.diveId).toList();
      expect(ids, ['after-start', 'assigned-old']);
      expect(ids, isNot(contains('before-start')));
      expect(ids, isNot(contains('other-diver')));
      expect(ids, isNot(contains('linked')));
      expect(suggested.first.linkId, isNull);
    });
  });
}
```

Note: the `other-diver` dive is inserted before `diver-2` exists; if the FK
rejects it, move the `diver-2` INSERT above `_seedDive('other-diver', ...)`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/courses/data/repositories/course_requirement_repository_test.dart`
Expected: FAIL — repository file does not exist.

- [ ] **Step 3: Implement the repository**

Create `lib/features/courses/data/repositories/course_requirement_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// Maps a Drift row to the domain entity.
CourseRequirement mapCourseRequirementRow(CourseRequirementRow row) {
  return CourseRequirement(
    id: row.id,
    courseId: row.courseId,
    name: row.name,
    kind: RequirementKind.fromName(row.kind),
    targetCount: row.targetCount,
    completedAt: row.completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.completedAt!)
        : null,
    sortOrder: row.sortOrder,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

class CourseRequirementRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CourseRequirementRepository);

  /// Deterministic junction id: the same (requirement, dive) pair yields the
  /// same id on every device, so concurrent links converge to one row under
  /// sync upsert and unlink tombstones match cross-device.
  static String linkIdFor(String requirementId, String diveId) =>
      const Uuid().v5(
        Namespace.url.value,
        'submersion:course-requirement-dive:$requirementId:$diveId',
      );

  /// Emits when either requirement table changes (sync writes included).
  Stream<void> watchRequirementsChanges() => _db.tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.courseRequirements,
          _db.courseRequirementDives,
        ]),
      );

  /// All requirements of [courseId] with their credited dives, in
  /// sortOrder. One requirement query plus one joined link query -- no N+1.
  Future<CourseProgress> getCourseProgress(String courseId) async {
    try {
      final reqRows =
          await (_db.select(_db.courseRequirements)
                ..where((t) => t.courseId.equals(courseId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();

      final linksByRequirement = <String, List<RequirementDiveSummary>>{};
      if (reqRows.isNotEmpty) {
        final linkQuery =
            _db.select(_db.courseRequirementDives).join([
                innerJoin(
                  _db.dives,
                  _db.dives.id.equalsExp(_db.courseRequirementDives.diveId),
                ),
                leftOuterJoin(
                  _db.diveSites,
                  _db.diveSites.id.equalsExp(_db.dives.siteId),
                ),
              ])
              ..where(
                _db.courseRequirementDives.requirementId.isIn(
                  reqRows.map((r) => r.id).toList(),
                ),
              )
              ..orderBy([OrderingTerm.asc(_db.dives.diveDateTime)]);

        for (final row in await linkQuery.get()) {
          final link = row.readTable(_db.courseRequirementDives);
          final dive = row.readTable(_db.dives);
          final site = row.readTableOrNull(_db.diveSites);
          linksByRequirement
              .putIfAbsent(link.requirementId, () => [])
              .add(
                RequirementDiveSummary(
                  linkId: link.id,
                  diveId: dive.id,
                  diveNumber: dive.diveNumber,
                  dateTime:
                      DateTime.fromMillisecondsSinceEpoch(dive.diveDateTime),
                  siteName: site?.name,
                ),
              );
        }
      }

      return CourseProgress(
        courseId: courseId,
        requirements: [
          for (final row in reqRows)
            CourseRequirementProgress(
              requirement: mapCourseRequirementRow(row),
              linkedDives: linksByRequirement[row.id] ?? const [],
            ),
        ],
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get course progress for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<CourseRequirement> createRequirement({
    required String courseId,
    required String name,
    required RequirementKind kind,
    int targetCount = 1,
    String? notes,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSortOrder = await _getMaxSortOrder(courseId);

      await _db
          .into(_db.courseRequirements)
          .insert(
            CourseRequirementsCompanion(
              id: Value(id),
              courseId: Value(courseId),
              name: Value(name.trim()),
              kind: Value(kind.name),
              targetCount: Value(targetCount),
              sortOrder: Value(maxSortOrder + 1),
              notes: Value(notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Created requirement $id ($name) for course: $courseId');

      final row = await (_db.select(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).getSingle();
      return mapCourseRequirementRow(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create requirement',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateRequirement(CourseRequirement requirement) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.courseRequirements,
      )..where((t) => t.id.equals(requirement.id))).write(
        CourseRequirementsCompanion(
          name: Value(requirement.name.trim()),
          kind: Value(requirement.kind.name),
          targetCount: Value(requirement.targetCount),
          sortOrder: Value(requirement.sortOrder),
          notes: Value(requirement.notes),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: requirement.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated requirement: ${requirement.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update requirement: ${requirement.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> setChecklistComplete(String id, bool complete) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).write(
        CourseRequirementsCompanion(
          completedAt: Value(complete ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set checklist state: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a requirement. FK cascade removes its junction rows, but sync
  /// needs a tombstone PER ROW (issue #466 lesson) or another device
  /// resurrects the links.
  Future<void> deleteRequirement(String id) async {
    try {
      final links = await (_db.select(
        _db.courseRequirementDives,
      )..where((t) => t.requirementId.equals(id))).get();

      await (_db.delete(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).go();

      await _syncRepository.logDeletion(
        entityType: 'courseRequirements',
        recordId: id,
      );
      for (final link in links) {
        await _syncRepository.logDeletion(
          entityType: 'courseRequirementDives',
          recordId: link.id,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted requirement $id with ${links.length} links');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete requirement: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Append the template's rows to the course. Never destructive: applying
  /// twice duplicates rows, which is the user's explicit choice to fix.
  Future<void> applyTemplate(String courseId, CourseTemplate template) async {
    for (final item in template.requirements) {
      await createRequirement(
        courseId: courseId,
        name: item.name,
        kind: item.kind,
        targetCount: item.targetCount,
      );
    }
  }

  /// Credit [diveId] toward [requirementId]. Idempotent: the deterministic
  /// id plus insertOrIgnore make a duplicate link a silent no-op. Bumps the
  /// parent requirement so the junction rides the parent's sync delta.
  Future<void> linkDive({
    required String requirementId,
    required String diveId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.courseRequirementDives)
          .insert(
            CourseRequirementDivesCompanion(
              id: Value(linkIdFor(requirementId, diveId)),
              requirementId: Value(requirementId),
              diveId: Value(diveId),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await _touchRequirement(requirementId, now);
      SyncEventBus.notifyLocalChange();
      _log.info('Linked dive $diveId to requirement $requirementId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link dive $diveId to requirement $requirementId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> unlinkDive({
    required String requirementId,
    required String diveId,
  }) async {
    try {
      final id = linkIdFor(requirementId, diveId);
      final deleted = await (_db.delete(
        _db.courseRequirementDives,
      )..where((t) => t.id.equals(id))).go();
      if (deleted == 0) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      await _syncRepository.logDeletion(
        entityType: 'courseRequirementDives',
        recordId: id,
      );
      await _touchRequirement(requirementId, now);
      SyncEventBus.notifyLocalChange();
      _log.info('Unlinked dive $diveId from requirement $requirementId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unlink dive $diveId from requirement $requirementId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Candidate dives for crediting: the course diver's dives that are either
  /// assigned to this course (dives.course_id) or dated on/after the course
  /// start, excluding dives already credited to any requirement of this
  /// course. Newest first, capped at 10.
  Future<List<RequirementDiveSummary>> getSuggestedDives(
    String courseId,
  ) async {
    try {
      final course = await (_db.select(
        _db.courses,
      )..where((t) => t.id.equals(courseId))).getSingleOrNull();
      if (course == null) return const [];

      final rows = await _db
          .customSelect(
            '''
            SELECT d.id, d.dive_number, d.dive_datetime, s.name AS site_name
            FROM dives d
            LEFT JOIN dive_sites s ON s.id = d.site_id
            WHERE d.diver_id = ?2
              AND (d.course_id = ?1 OR d.dive_datetime >= ?3)
              AND d.id NOT IN (
                SELECT l.dive_id
                FROM course_requirement_dives l
                JOIN course_requirements r ON r.id = l.requirement_id
                WHERE r.course_id = ?1
              )
            ORDER BY d.dive_datetime DESC
            LIMIT 10
            ''',
            variables: [
              Variable.withString(courseId),
              Variable.withString(course.diverId),
              Variable.withInt(course.startDate),
            ],
            readsFrom: {
              _db.dives,
              _db.diveSites,
              _db.courseRequirementDives,
              _db.courseRequirements,
            },
          )
          .get();

      return [
        for (final row in rows)
          RequirementDiveSummary(
            diveId: row.data['id'] as String,
            diveNumber: row.data['dive_number'] as int?,
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              row.data['dive_datetime'] as int,
            ),
            siteName: row.data['site_name'] as String?,
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get suggested dives for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bump the parent requirement's updatedAt and mark it sync-pending so
  /// its hlc advances -- junction delta export is gated on the parent hlc.
  Future<void> _touchRequirement(String requirementId, int now) async {
    await (_db.update(
      _db.courseRequirements,
    )..where((t) => t.id.equals(requirementId))).write(
      CourseRequirementsCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'courseRequirements',
      recordId: requirementId,
      localUpdatedAt: now,
    );
  }

  Future<int> _getMaxSortOrder(String courseId) async {
    final result = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS max_order FROM course_requirements '
          'WHERE course_id = ?1',
          variables: [Variable.withString(courseId)],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }
}
```

Note on `Namespace.url.value`: the project uses `package:uuid` v4.x. If the
analyzer reports `Namespace` undefined, the fallback spelling is
`Uuid.NAMESPACE_URL` (older API) — use whichever resolves; do not invent a
third form. The literal namespace string must not change once shipped.

- [ ] **Step 4: Extend CourseRepository.deleteCourse with child tombstones**

In `lib/features/courses/data/repositories/course_repository.dart`, find the existing `deleteCourse` method. BEFORE the statement that deletes the course row, insert collection of child ids, and AFTER the existing course deletion-log call, log the child tombstones:

```dart
      // Course requirement children are removed by FK cascade, but sync
      // needs per-row tombstones (issue #466) or peers resurrect them.
      final requirements = await (_db.select(
        _db.courseRequirements,
      )..where((t) => t.courseId.equals(id))).get();
      final requirementIds = requirements.map((r) => r.id).toList();
      final links = requirementIds.isEmpty
          ? <CourseRequirementDiveRow>[]
          : await (_db.select(
              _db.courseRequirementDives,
            )..where((t) => t.requirementId.isIn(requirementIds))).get();
```

and after the existing `logDeletion(entityType: 'courses', ...)` call:

```dart
      for (final requirement in requirements) {
        await _syncRepository.logDeletion(
          entityType: 'courseRequirements',
          recordId: requirement.id,
        );
      }
      for (final link in links) {
        await _syncRepository.logDeletion(
          entityType: 'courseRequirementDives',
          recordId: link.id,
        );
      }
```

Match the local variable names actually used in that method (`_db`, `_syncRepository` — verify; if the class uses different names, adapt). Add a test to the repository test file from Step 1:

```dart
  group('deleteCourse tombstones', () {
    test('deleting a course logs tombstones for requirements and links',
        () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');

      final courseRepository = CourseRepository();
      await courseRepository.deleteCourse('course-1');

      final db = DatabaseService.instance.database;
      final tombstones = await db.customSelect(
        'SELECT entity_type FROM deletion_log',
      ).get();
      final types =
          tombstones.map((r) => r.data['entity_type'] as String).toSet();
      expect(types, containsAll({
        'courses',
        'courseRequirements',
        'courseRequirementDives',
      }));
    });
  });
```

(Add `import 'package:submersion/features/courses/data/repositories/course_repository.dart';` to the test file.)

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/courses/data/repositories/course_requirement_repository_test.dart`
Expected: PASS (all groups). Also run the existing course repo tests to catch regressions:
`flutter test test/features/courses/data/repositories/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): course requirement repository with linking, templates, and tombstones"
```

---

### Task 5: Sync registration

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData fields ×5, `_baseTables`, `exportData`, `fetchRecord`, `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord`, two private exporters)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder`, `entityHasUpdatedAt`, `parentRefs`)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets`)
- Test: `test/core/services/sync/sync_course_requirements_test.dart` (new round-trip test)

**Interfaces:**
- Consumes: Task 1 tables/generated classes.
- Produces: entity types `'courseRequirements'` (HLC root, `hasUpdatedAt: true`) and `'courseRequirementDives'` (clockless junction, `hasUpdatedAt: false`, delta gated by parent hlc) registered end-to-end.

Reference patterns: `courses` (plain HLC entity) and `equipmentSetItems` (parent-gated junction) in the same files. The junction here is SIMPLER than `equipmentSetItems` because it has its own single-column `id` PK — use the plain id forms everywhere, not the composite-key forms.

- [ ] **Step 1: Add the SyncData fields, run the structural tests to see them fail**

In `sync_data_serializer.dart`, mirror the `courses` field in all five SyncData spots (declaration, constructor default, `toJson`, `fromJson`, and `_baseTables`):

```dart
  // declaration block (next to courses):
  final List<Map<String, dynamic>> courseRequirements;
  final List<Map<String, dynamic>> courseRequirementDives;

  // constructor:
  this.courseRequirements = const [],
  this.courseRequirementDives = const [],

  // toJson():
  'courseRequirements': courseRequirements,
  'courseRequirementDives': courseRequirementDives,

  // fromJson():
  courseRequirements: _parseList(json['courseRequirements']),
  courseRequirementDives: _parseList(json['courseRequirementDives']),
```

In `_baseTables`, after the `courses` entry (order here must match `toJson` order — the parity test checks it):

```dart
  (key: 'courseRequirements', table: _db.courseRequirements, blob: false, full: null),
  (key: 'courseRequirementDives', table: _db.courseRequirementDives, blob: false, full: null),
```

Then run the structural tests — this is the failing-test step:

```
flutter test test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart
```
Expected: FAIL — `entityHasUpdatedAt` no longer covers the SyncData entities, and `recordIdsFor`/`deleteAllRecords` throw for the new types.

- [ ] **Step 2: Complete every registration site**

a. `sync_data_serializer.dart` — `exportData` (next to the courses line):

```dart
  courseRequirements: await _safeExport(
    'courseRequirements',
    () => _exportCourseRequirements(hlcSince),
  ),
  courseRequirementDives: await _safeExport(
    'courseRequirementDives',
    () => _exportCourseRequirementDives(hlcSince),
  ),
```

b. Private exporters (place near `_exportDiveRoles`):

```dart
  Future<List<Map<String, dynamic>>> _exportCourseRequirements(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.courseRequirements);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  /// Clockless junction: delta export rides the PARENT requirement's hlc
  /// (linkDive/unlinkDive bump it), mirroring equipmentSetItems.
  Future<List<Map<String, dynamic>>> _exportCourseRequirementDives(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final changed = await (_db.select(
        _db.courseRequirements,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final requirementIds = changed.map((r) => r.id).toSet();
      if (requirementIds.isEmpty) return [];
      final rows = await (_db.select(
        _db.courseRequirementDives,
      )..where((t) => t.requirementId.isIn(requirementIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.courseRequirementDives).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

c. The seven serializer switches — copy the `courses` case shape for `courseRequirements` and the plain-id junction shape for `courseRequirementDives`:

- `fetchRecord`: both types (id-select, `row?.toJson()`).
- `fetchRecords` (batched): `courseRequirements` ONLY (junctions fall through to `default` — do NOT add a junction case).
- `upsertRecord`:

```dart
      case 'courseRequirements':
        await _db
            .into(_db.courseRequirements)
            .insertOnConflictUpdate(
              CourseRequirementRow.fromJson(data).toCompanion(false),
            );
        return;
      case 'courseRequirementDives':
        await _db
            .into(_db.courseRequirementDives)
            .insertOnConflictUpdate(CourseRequirementDiveRow.fromJson(data));
        return;
```

(`.toCompanion(false)` on the HLC entity ONLY — the junction keeps the plain form, per the #474 rule.)

- `upsertRecords` (batched): same pair using `insertAllOnConflictUpdate`, mirroring the `diveRoles` batched case.
- `recordIdsFor`: `return plain(_db.courseRequirements, _db.courseRequirements.id);` and `return plain(_db.courseRequirementDives, _db.courseRequirementDives.id);`
- `_syncTableFor`: `return _db.courseRequirements;` / `return _db.courseRequirementDives;`
- `deleteRecord`: id-delete `.go()` for both.
- `deleteAllRecords`: NO case needed (no `isBuiltIn` filter — falls through to `_syncTableFor`).

d. `sync_service.dart`:

- `mergeOrder` — insert AFTER the `courses` entry, requirement before junction (parents apply first):

```dart
  (type: 'courseRequirements', records: data.courseRequirements, hasUpdatedAt: true),
  (type: 'courseRequirementDives', records: data.courseRequirementDives, hasUpdatedAt: false),
```

- `entityHasUpdatedAt`:

```dart
  'courseRequirements': true,
  'courseRequirementDives': false,
```

- `parentRefs`:

```dart
  'courseRequirements': [
    (field: 'courseId', parent: 'courses', nullable: false),
  ],
  'courseRequirementDives': [
    (field: 'requirementId', parent: 'courseRequirements', nullable: false),
    (field: 'diveId', parent: 'dives', nullable: false),
  ],
```

(Match the exact record shape used by existing `parentRefs` entries — copy the `courses` entry's syntax.)

e. `sync_repository.dart` — `_hlcTargets` (HLC entity ONLY, junction intentionally absent):

```dart
  'courseRequirements': (table: 'course_requirements', pk: 'id'),
```

- [ ] **Step 3: Re-run the structural tests**

```
flutter test test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart
```
Expected: PASS (parent_refs test validates the new FKs against the live schema).

- [ ] **Step 4: Write the round-trip test**

Create `test/core/services/sync/sync_course_requirements_test.dart`. FIRST read `test/core/services/sync/sync_dive_dive_types_test.dart` and mirror its setup/serializer instantiation exactly (constructor args may carry dependencies). The test body to implement with that scaffolding:

```dart
// Scenario 1: full export/import round-trip.
// - Seed diver, course, dive, one requirement, one link (raw SQL inserts,
//   same fixtures as course_requirement_repository_test.dart).
// - exportData(hlcSince: null) -> assert data.courseRequirements has 1 row
//   and data.courseRequirementDives has 1 row.
// - Wipe both tables (DELETE FROM ...).
// - upsertRecord('courseRequirements', row) then
//   upsertRecord('courseRequirementDives', linkRow).
// - Assert both tables have their row back with identical column values.

// Scenario 2: delta export rides the parent hlc.
// - Stamp the requirement row's hlc to '2026-01-02T00:00:00.000Z-0001-dev'
//   (UPDATE course_requirements SET hlc = ...).
// - exportData(hlcSince: '2026-01-01T...') -> both lists non-empty.
// - exportData(hlcSince: '2026-12-31T...') -> both lists empty.

// Scenario 3: deterministic junction id converges.
// - upsertRecord the same link row twice -> SELECT COUNT(*) is 1.
```

Use the exact `exportData`/`upsertRecord` call signatures from the template test. If the template test uses `SyncDataSerializer(...)` with dependencies, replicate them verbatim.

- [ ] **Step 5: Run the new test plus the sync batch-coverage suites**

```
flutter test test/core/services/sync/sync_course_requirements_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_serializer_upsert_test.dart
```
Expected: PASS. If `sync_data_serializer_batch_coverage_test.dart` or `sync_serializer_upsert_test.dart` maintain hand-coded entity lists (they do — `targets` lists), ADD the two new types there following the file's existing pattern, with `courseRequirements` in the HLC arm and `courseRequirementDives` in the plain-id junction arm.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(sync): register courseRequirements and courseRequirementDives entities"
```

---

### Task 6: Providers

**Files:**
- Create: `lib/features/courses/presentation/providers/course_requirement_providers.dart`
- Test: `test/features/courses/presentation/course_requirement_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 4; existing `inProgressCoursesProvider` (`course_providers.dart`), `diveRepositoryProvider`, `validatedCurrentDiverIdProvider`, `ref.invalidateSelfWhen` (exported by `package:submersion/core/providers/provider.dart`).
- Produces:
  - `courseRequirementRepositoryProvider` — `Provider<CourseRequirementRepository>`
  - `courseProgressProvider` — `FutureProvider.family<CourseProgress, String>`
  - `suggestedDivesProvider` — `FutureProvider.family<List<RequirementDiveSummary>, String>`
  - `typedef ActiveCourseProgress = ({Course course, CourseProgress progress});`
  - `activeCoursesProgressProvider` — `FutureProvider<List<ActiveCourseProgress>>` (in-progress courses with `totalCount > 0` filtering left to the UI)

- [ ] **Step 1: Write the failing test**

Create `test/features/courses/presentation/course_requirement_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('courseProgressProvider resolves progress and refreshes after a '
      'requirement write', () async {
    await _seed();
    final repository = CourseRequirementRepository();
    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Deep adventure dive',
      kind: RequirementKind.dive,
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final progress =
        await container.read(courseProgressProvider('course-1').future);
    expect(progress.totalCount, 1);
    expect(progress.satisfiedCount, 0);

    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Knowledge development',
      kind: RequirementKind.checklist,
    );
    // invalidateSelfWhen listens to a table stream; give it a tick.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final refreshed =
        await container.read(courseProgressProvider('course-1').future);
    expect(refreshed.totalCount, 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/courses/presentation/course_requirement_providers_test.dart`
Expected: FAIL — providers file missing.

- [ ] **Step 3: Implement the providers**

Create `lib/features/courses/presentation/providers/course_requirement_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Repository provider
final courseRequirementRepositoryProvider =
    Provider<CourseRequirementRepository>((ref) {
  return CourseRequirementRepository();
});

/// Requirement progress for one course. Self-invalidates on any write to
/// the requirement tables (including sync merges) so progress stays live.
final courseProgressProvider = FutureProvider.family<CourseProgress, String>((
  ref,
  courseId,
) async {
  final repository = ref.watch(courseRequirementRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRequirementsChanges());
  return repository.getCourseProgress(courseId);
});

/// Candidate dives to credit toward requirements of a course. Watches both
/// the requirement tables (links consume suggestions) and the dives table
/// (new logged dives appear as candidates -- issue #217 lesson).
final suggestedDivesProvider =
    FutureProvider.family<List<RequirementDiveSummary>, String>((
  ref,
  courseId,
) async {
  final repository = ref.watch(courseRequirementRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRequirementsChanges());
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDivesChanges(),
  );
  return repository.getSuggestedDives(courseId);
});

/// One in-progress course with its requirement progress.
typedef ActiveCourseProgress = ({Course course, CourseProgress progress});

/// All in-progress courses of the current diver with their progress, for
/// the dashboard card. Courses without requirements are included; the card
/// filters totalCount == 0 (nothing meaningful to show).
final activeCoursesProgressProvider =
    FutureProvider<List<ActiveCourseProgress>>((ref) async {
  final courses = await ref.watch(inProgressCoursesProvider.future);
  final repository = ref.watch(courseRequirementRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRequirementsChanges());
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDivesChanges(),
  );
  return [
    for (final course in courses)
      (course: course, progress: await repository.getCourseProgress(course.id)),
  ];
});
```

If `Course` does not resolve from `domain/entities/course.dart` with that
import path, match the import used in `course_providers.dart`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/courses/presentation/course_requirement_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): requirement progress and suggestion providers"
```

---

### Task 7: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` plus ALL of `app_ar.arb app_de.arb app_es.arb app_fr.arb app_he.arb app_hu.arb app_it.arb app_nl.arb app_pt.arb app_zh.arb`

**Interfaces:**
- Produces: `context.l10n.<key>` getters used by Tasks 8-10 (exact key list below).

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, next to the existing `courses_*` block (~line 1375), add:

```json
  "courses_section_requirements": "Requirements",
  "courses_requirements_progress": "{satisfied} of {total} complete",
  "@courses_requirements_progress": {
    "placeholders": {
      "satisfied": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "courses_requirements_empty": "Track adventure dives, prerequisites, and check-offs for this course.",
  "courses_action_addRequirement": "Add requirement",
  "courses_action_addFromTemplate": "Add from template",
  "courses_action_editRequirement": "Edit requirement",
  "courses_action_deleteRequirement": "Delete requirement",
  "courses_requirement_diveProgress": "{count} of {target} dives",
  "@courses_requirement_diveProgress": {
    "placeholders": {
      "count": { "type": "int" },
      "target": { "type": "int" }
    }
  },
  "courses_requirement_suggestions": "Suggested dives",
  "courses_action_linkDive": "Link",
  "courses_action_unlinkDive": "Unlink dive",
  "courses_requirement_field_name": "Name",
  "courses_requirement_kind_dive": "Dive requirement",
  "courses_requirement_kind_checklist": "Check-off item",
  "courses_requirement_field_targetCount": "Required dives",
  "courses_template_addsCount": "Adds {count} requirements",
  "@courses_template_addsCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "dashboard_activeCourses_title": "Courses in progress",
```

- [ ] **Step 2: Translate into all 10 other locales**

Add the same keys with translated values to every other arb file (`ar de es fr he hu it nl pt zh`). Match each file's existing tone for the `courses_*` namespace (open a few existing `courses_` keys in each file for reference). Placeholders (`{satisfied}`, `{total}`, `{count}`, `{target}`) must appear verbatim in every translation; the `@`-metadata blocks are only needed in `app_en.arb` (check whether the other arb files carry `@` blocks for existing keys — mirror whatever they do).

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n
flutter analyze lib/l10n
```
Expected: gen-l10n exits 0 with no untranslated-message warnings for the new keys; analyze passes.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(l10n): course requirement tracker strings for all locales"
```

---

### Task 8: Course detail Requirements section

**Files:**
- Create: `lib/features/courses/presentation/widgets/course_requirements_section.dart`
- Create: `lib/features/courses/presentation/widgets/requirement_tile.dart`
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart` (insert the section into `_buildContent`)
- Test: `test/features/courses/presentation/course_requirements_section_test.dart`

**Interfaces:**
- Consumes: Task 6 providers, Task 7 strings, `context.l10n` via `package:submersion/l10n/l10n_extension.dart`.
- Produces: `class CourseRequirementsSection extends ConsumerWidget { const CourseRequirementsSection({super.key, required this.courseId}); final String courseId; }` and `class RequirementTile extends ConsumerWidget { const RequirementTile({super.key, required this.progress, required this.suggestions}); final CourseRequirementProgress progress; final List<RequirementDiveSummary> suggestions; }`. Task 9 adds the add/edit/template entry points onto the section's header actions.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/courses/presentation/course_requirements_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('renders requirement rows with progress header',
      (tester) async {
    await tester.runAsync(() async {
      await _seed();
      final repository = CourseRequirementRepository();
      await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final checklist = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(checklist.id, true);
    });

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deep adventure dive'), findsOneWidget);
    expect(find.text('Knowledge development'), findsOneWidget);
    expect(find.text('1 of 2 complete'), findsOneWidget);
  });

  testWidgets('checklist checkbox toggles completion', (tester) async {
    late String requirementId;
    await tester.runAsync(() async {
      await _seed();
      final repository = CourseRequirementRepository();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      requirementId = req.id;
    });

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository()
          .getCourseProgress('course-1');
      expect(
        progress.requirements
            .singleWhere((r) => r.requirement.id == requirementId)
            .isSatisfied,
        isTrue,
      );
    });
  });

  testWidgets('suggestion chip links the dive', (tester) async {
    await tester.runAsync(() async {
      await _seed();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_number, dive_datetime, "
        "created_at, updated_at) "
        "VALUES ('dive-1', 'diver-1', 47, 9000, 1000, 1000)",
      );
      await CourseRequirementRepository().createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
    });

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    // The suggestion chip carries the dive number.
    final chip = find.widgetWithText(ActionChip, '#47');
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository()
          .getCourseProgress('course-1');
      expect(progress.requirements.single.creditCount, 1);
    });
  });
}
```

(Widget-test traps honored: `themeAnimationDuration: Duration.zero`, all post-pump database awaits inside `tester.runAsync`, `ensureVisible` before taps. If chip text rendering differs — e.g. the chip shows "#47 · Jul 12" — loosen the finder to `find.textContaining('#47')`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/courses/presentation/course_requirements_section_test.dart`
Expected: FAIL — widget files missing.

- [ ] **Step 3: Implement RequirementTile**

Create `lib/features/courses/presentation/widgets/requirement_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

/// One requirement row: a checkbox for checklist items, a progress count
/// plus expandable credited-dive list for dive requirements. Unsatisfied
/// dive requirements offer suggestion chips (one tap credits the dive).
class RequirementTile extends ConsumerWidget {
  const RequirementTile({
    super.key,
    required this.progress,
    required this.suggestions,
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = progress.requirement;
    if (requirement.kind == RequirementKind.checklist) {
      return CheckboxListTile(
        value: requirement.completedAt != null,
        onChanged: (checked) {
          ref
              .read(courseRequirementRepositoryProvider)
              .setChecklistComplete(requirement.id, checked ?? false);
        },
        title: Text(requirement.name),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }
    return _DiveRequirementTile(
      progress: progress,
      suggestions: suggestions,
    );
  }
}

class _DiveRequirementTile extends ConsumerWidget {
  const _DiveRequirementTile({
    required this.progress,
    required this.suggestions,
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  String _diveLabel(RequirementDiveSummary dive) {
    final number = dive.diveNumber != null ? '#${dive.diveNumber}' : '';
    final date = DateFormat.MMMd().format(dive.dateTime);
    final site = dive.siteName;
    return [number, date, if (site != null) site]
        .where((part) => part.isNotEmpty)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = progress.requirement;
    final theme = Theme.of(context);
    final satisfied = progress.isSatisfied;

    return ExpansionTile(
      leading: satisfied
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : Icon(Icons.radio_button_unchecked,
              color: theme.colorScheme.outline),
      title: Text(requirement.name),
      subtitle: Text(
        context.l10n.courses_requirement_diveProgress(
          progress.creditCount,
          requirement.targetCount,
        ),
        style: theme.textTheme.bodySmall,
      ),
      dense: true,
      children: [
        for (final dive in progress.linkedDives)
          ListTile(
            dense: true,
            leading: const Icon(Icons.link, size: 18),
            title: Text(_diveLabel(dive)),
            trailing: IconButton(
              tooltip: context.l10n.courses_action_unlinkDive,
              icon: const Icon(Icons.link_off, size: 18),
              onPressed: () {
                ref.read(courseRequirementRepositoryProvider).unlinkDive(
                      requirementId: requirement.id,
                      diveId: dive.diveId,
                    );
              },
            ),
          ),
        if (!satisfied && suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.courses_requirement_suggestions,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final dive in suggestions)
                      ActionChip(
                        label: Text(_diveLabel(dive)),
                        onPressed: () {
                          ref
                              .read(courseRequirementRepositoryProvider)
                              .linkDive(
                                requirementId: requirement.id,
                                diveId: dive.diveId,
                              );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement CourseRequirementsSection**

Create `lib/features/courses/presentation/widgets/course_requirements_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/requirement_tile.dart';

/// The requirement tracker card on the course detail page: overall progress
/// header, one tile per requirement, and empty-state actions. Add/template
/// entry points are wired in by the header action buttons.
class CourseRequirementsSection extends ConsumerWidget {
  const CourseRequirementsSection({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(courseProgressProvider(courseId));
    final suggestionsAsync = ref.watch(suggestedDivesProvider(courseId));
    final theme = Theme.of(context);

    // AsyncValue.value keeps prior data during reloads (#429 flicker rule).
    final progress = progressAsync.value;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final suggestions = suggestionsAsync.value ?? const [];

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, size: 20,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.courses_section_requirements,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (progress.totalCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.courses_requirements_progress(
                  progress.satisfiedCount,
                  progress.totalCount,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress.satisfiedCount / progress.totalCount,
              ),
              const SizedBox(height: 8),
              for (final requirementProgress in progress.requirements)
                RequirementTile(
                  progress: requirementProgress,
                  suggestions: suggestions,
                ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.courses_requirements_empty,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the section into the course detail page**

In `lib/features/courses/presentation/pages/course_detail_page.dart`, inside `_buildContent`, add the section to the main `Column`'s children immediately after the certification section block (the `if (course.certificationId != null) _buildCertificationSection(...)` entry, ~line 145):

```dart
          CourseRequirementsSection(courseId: course.id),
```

Add the import:

```dart
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/courses/presentation/course_requirements_section_test.dart`
Expected: PASS (3 tests). Also run the existing course page tests:
`flutter test test/features/courses/presentation/`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): requirements section on course detail page"
```

---

### Task 9: Add/edit and template sheets

**Files:**
- Create: `lib/features/courses/presentation/widgets/add_requirement_sheet.dart`
- Create: `lib/features/courses/presentation/widgets/template_picker_sheet.dart`
- Modify: `lib/features/courses/presentation/widgets/course_requirements_section.dart` (header action buttons + empty-state buttons)
- Modify: `lib/features/courses/presentation/widgets/requirement_tile.dart` (edit/delete menu on tiles)
- Test: `test/features/courses/presentation/requirement_sheets_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 6, 7, 8.
- Produces:
  - `class RequirementDraft { final String name; final RequirementKind kind; final int targetCount; }`
  - `Future<RequirementDraft?> showAddRequirementSheet(BuildContext context, {CourseRequirement? existing})` — returns null on cancel.
  - `Future<CourseTemplate?> showTemplatePickerSheet(BuildContext context)` — returns null on cancel.
  - The section performs the repository calls (create/update/applyTemplate); sheets only collect input.

- [ ] **Step 1: Write the failing tests**

Create `test/features/courses/presentation/requirement_sheets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('add requirement flow creates a checklist row', (tester) async {
    await tester.runAsync(_seed);

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    // Empty state shows the add button.
    final addButton = find.text('Add requirement');
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Knowledge development',
    );
    await tester.tap(find.text('Check-off item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository()
          .getCourseProgress('course-1');
      expect(progress.requirements.single.requirement.name,
          'Knowledge development');
    });
  });

  testWidgets('template picker applies the selected template',
      (tester) async {
    await tester.runAsync(_seed);

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final templateButton = find.text('Add from template');
    await tester.ensureVisible(templateButton);
    await tester.tap(templateButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Advanced Open Water'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository()
          .getCourseProgress('course-1');
      expect(progress.requirements.length, 4);
    });
  });
}
```

(If a common `Save` string does not exist in l10n, check for an existing `common_save`/`action_save` key and use its English value in the finder; add nothing new without checking first.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/courses/presentation/requirement_sheets_test.dart`
Expected: FAIL — buttons/sheets missing.

- [ ] **Step 3: Implement AddRequirementSheet**

Create `lib/features/courses/presentation/widgets/add_requirement_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// Input collected by the add/edit requirement sheet. The caller owns the
/// repository write.
class RequirementDraft {
  final String name;
  final RequirementKind kind;
  final int targetCount;

  const RequirementDraft({
    required this.name,
    required this.kind,
    required this.targetCount,
  });
}

/// Bottom sheet to create or edit a requirement. Returns null on cancel.
Future<RequirementDraft?> showAddRequirementSheet(
  BuildContext context, {
  CourseRequirement? existing,
}) {
  return showModalBottomSheet<RequirementDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddRequirementSheet(existing: existing),
  );
}

class _AddRequirementSheet extends StatefulWidget {
  const _AddRequirementSheet({this.existing});

  final CourseRequirement? existing;

  @override
  State<_AddRequirementSheet> createState() => _AddRequirementSheetState();
}

class _AddRequirementSheetState extends State<_AddRequirementSheet> {
  late final TextEditingController _nameController;
  late RequirementKind _kind;
  late int _targetCount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _kind = widget.existing?.kind ?? RequirementKind.dive;
    _targetCount = widget.existing?.targetCount ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      RequirementDraft(name: name, kind: _kind, targetCount: _targetCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null
                ? l10n.courses_action_addRequirement
                : l10n.courses_action_editRequirement,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.courses_requirement_field_name,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<RequirementKind>(
            segments: [
              ButtonSegment(
                value: RequirementKind.dive,
                label: Text(l10n.courses_requirement_kind_dive),
              ),
              ButtonSegment(
                value: RequirementKind.checklist,
                label: Text(l10n.courses_requirement_kind_checklist),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) {
              setState(() => _kind = selection.single);
            },
          ),
          if (_kind == RequirementKind.dive) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.courses_requirement_field_targetCount),
                ),
                IconButton(
                  onPressed: _targetCount > 1
                      ? () => setState(() => _targetCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_targetCount'),
                IconButton(
                  onPressed: () => setState(() => _targetCount++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );
  }
}
```

(`MaterialLocalizations.saveButtonLabel` gives a localized "Save" for free; if the test's `find.text('Save')` fails because the framework renders "SAVE" uppercase, use `find.text(...)` on the actual rendered label — check with the FormSection uppercase trap in mind.)

- [ ] **Step 4: Implement TemplatePickerSheet**

Create `lib/features/courses/presentation/widgets/template_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/course_templates.dart';

/// Bottom sheet listing starter templates with a preview of the rows each
/// adds. Returns the selected template, or null on cancel.
Future<CourseTemplate?> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<CourseTemplate>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.courses_action_addFromTemplate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final template in CourseTemplateCatalog.templates)
            ListTile(
              title: Text(template.name),
              subtitle: Text(
                template.requirements.map((r) => r.name).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                l10n.courses_template_addsCount(
                  template.requirements.length,
                ),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => Navigator.of(context).pop(template),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire entry points into the section and tiles**

In `course_requirements_section.dart`:

a. Add imports for the two sheets and the template catalog.

b. In the header `Row`, after the title `Expanded`, add action buttons:

```dart
                IconButton(
                  tooltip: context.l10n.courses_action_addFromTemplate,
                  icon: const Icon(Icons.library_add_outlined, size: 20),
                  onPressed: () => _addFromTemplate(context, ref),
                ),
                IconButton(
                  tooltip: context.l10n.courses_action_addRequirement,
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _addRequirement(context, ref),
                ),
```

c. Replace the empty-state `Text` block's surrounding `else` branch content with the text plus two `TextButton.icon`s labeled with the same two l10n strings, calling the same handlers.

d. Add the handlers to the class:

```dart
  Future<void> _addRequirement(BuildContext context, WidgetRef ref) async {
    final draft = await showAddRequirementSheet(context);
    if (draft == null) return;
    await ref.read(courseRequirementRepositoryProvider).createRequirement(
          courseId: courseId,
          name: draft.name,
          kind: draft.kind,
          targetCount: draft.targetCount,
        );
  }

  Future<void> _addFromTemplate(BuildContext context, WidgetRef ref) async {
    final template = await showTemplatePickerSheet(context);
    if (template == null) return;
    await ref
        .read(courseRequirementRepositoryProvider)
        .applyTemplate(courseId, template);
  }
```

e. In `requirement_tile.dart`, add a trailing `PopupMenuButton<String>` to BOTH tile variants with `edit` and `delete` items (l10n: `courses_action_editRequirement`, `courses_action_deleteRequirement`). `edit` opens `showAddRequirementSheet(context, existing: requirement)` and on non-null result calls `updateRequirement(requirement.copyWith(name: draft.name, kind: draft.kind, targetCount: draft.targetCount))`; `delete` calls `deleteRequirement(requirement.id)` directly (requirement rows are cheap to recreate; no confirm dialog).

For the `CheckboxListTile` variant, use its `secondary:` slot for the menu; for the `ExpansionTile`, wrap the existing leading/trailing arrangement — put the menu in `trailing:` (the expansion chevron moves into the subtitle row or is dropped; simplest is `trailing:` menu and rely on tile tap to expand).

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/courses/presentation/requirement_sheets_test.dart test/features/courses/presentation/course_requirements_section_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): add/edit requirement and template picker sheets"
```

---

### Task 10: Dashboard active-course progress card

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/active_course_progress_card.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (insert card; add provider invalidation to `onRefresh`)
- Test: `test/features/dashboard/presentation/active_course_progress_card_test.dart`

**Interfaces:**
- Consumes: `activeCoursesProgressProvider` (Task 6), `dashboard_activeCourses_title` (Task 7), go_router route `/courses/:id` (verify the detail route path at `lib/core/router/app_router.dart:589` before hardcoding).
- Produces: `class ActiveCourseProgressCard extends ConsumerWidget` that renders `SizedBox.shrink()` when there is nothing to show.

- [ ] **Step 1: Write the failing test**

Create `test/features/dashboard/presentation/active_course_progress_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/dashboard/presentation/widgets/active_course_progress_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _seedCourse({required bool completed}) async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  final completionCol = completed ? '2000' : 'NULL';
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "completion_date, created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, $completionCol, "
    "1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('hidden when no in-progress course has requirements',
      (tester) async {
    await tester.runAsync(() => _seedCourse(completed: true));
    await tester.pumpWidget(_wrap(const ActiveCourseProgressCard()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('shows course name and satisfied fraction when active',
      (tester) async {
    await tester.runAsync(() async {
      await _seedCourse(completed: false);
      final repository = CourseRequirementRepository();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
    });

    await tester.pumpWidget(_wrap(const ActiveCourseProgressCard()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AOW'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
```

Note: `activeCoursesProgressProvider` depends on `inProgressCoursesProvider`, which resolves the current diver via `validatedCurrentDiverIdProvider`. If the seeded course does not appear because no current diver is set in the test container, check how existing dashboard/course provider tests establish the current diver (search `test/` for `validatedCurrentDiverIdProvider` overrides or a settings seed helper) and mirror that — likely an override: `ProviderScope(overrides: [...])` or inserting the diver id into the settings table.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dashboard/presentation/active_course_progress_card_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement the card**

Create `lib/features/dashboard/presentation/widgets/active_course_progress_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

/// Dashboard card: one compact progress row per in-progress course that has
/// requirements. Renders nothing (and reserves no space) otherwise, so the
/// dashboard column spacing is owned here via a bottom margin.
class ActiveCourseProgressCard extends ConsumerWidget {
  const ActiveCourseProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(activeCoursesProgressProvider);
    final entries = (entriesAsync.value ?? const [])
        .where((entry) => entry.progress.totalCount > 0)
        .toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 20,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.dashboard_activeCourses_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final entry in entries)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push('/courses/${entry.course.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: LinearProgressIndicator(
                            value: entry.progress.satisfiedCount /
                                entry.progress.totalCount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.progress.satisfiedCount}'
                          '/${entry.progress.totalCount}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Before committing, verify the course detail route: open `lib/core/router/app_router.dart` around line 589 and confirm the detail path is `/courses/:id` (adjust the `context.push` target to the actual pattern if it differs, e.g. a named route).

- [ ] **Step 4: Insert into the dashboard page**

In `lib/features/dashboard/presentation/pages/dashboard_page.dart`:

a. Import the card and the requirement providers.

b. In the `Column` children, between `const AlertsCard(),` / `const SizedBox(height: 12),` and `const RecentDivesCard(),` (lines 43-45), insert:

```dart
                const ActiveCourseProgressCard(),
```

(The card owns its own bottom margin, so no extra `SizedBox` — when hidden it collapses to zero height and the existing 12px gap between AlertsCard and RecentDivesCard is unchanged.)

c. In `onRefresh`, add:

```dart
            ref.invalidate(activeCoursesProgressProvider);
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/dashboard/presentation/active_course_progress_card_test.dart`
Expected: PASS. Also run existing dashboard tests: `flutter test test/features/dashboard/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dashboard): active course progress card"
```

---

### Task 11: Final verification

**Files:** none new.

- [ ] **Step 1: Full formatting and analysis**

```bash
dart format .
flutter analyze
```
Expected: format changes nothing; analyze reports no issues. Do NOT pipe analyze through `tail`/`head`/`grep`.

- [ ] **Step 2: Run the feature's full test surface**

```bash
flutter test test/core/database/course_requirements_schema_test.dart \
  test/core/constants/course_templates_test.dart \
  test/features/courses/ \
  test/features/dashboard/ \
  test/core/services/sync/
```
Expected: ALL PASS. The sync directory is included because the structural parity tests are the regression net for Task 5.

- [ ] **Step 3: Verify in the running app (manual smoke)**

Run `flutter run -d macos` (check no other `flutter run -d macos` session is active first). Verify: open a course → Requirements card renders; add from template (AOW) → 4 rows; check off Knowledge development → header progress updates; link a suggested dive → count increments; dashboard shows the course row with the fraction. Quit the app.

- [ ] **Step 4: Commit any remaining changes**

```bash
git status
dart format .
git add -A
git commit -m "chore(courses): requirement tracker final polish" # only if there are changes
```

Then report completion — do NOT push or open a PR without being asked (pre-push hooks run format/analyze/full tests when that happens).

---

## Self-review notes (already applied)

- Spec coverage: data model → Task 1; entities/progress → Task 2; templates → Task 3; repository incl. suggestions/tombstones → Task 4; sync → Task 5 (spec's "standard sync pattern" expanded to the real 15-site registration); providers → Task 6; l10n → Task 7; course page UI → Tasks 8-9; dashboard → Task 10; error handling is embedded in the repository (try/catch + logger, idempotent link); testing woven through every task.
- Deliberate spec deviations are listed under "Refinements vs the spec" at the top.
- Type consistency: `RequirementKind`, `CourseRequirement`, `RequirementDiveSummary`, `CourseRequirementProgress`, `CourseProgress`, `RequirementDraft`, `linkIdFor`, `getCourseProgress` are used with identical spellings across Tasks 2, 4, 6, 8, 9, 10.
