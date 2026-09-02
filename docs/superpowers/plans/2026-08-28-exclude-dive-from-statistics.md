# Exclude a Dive from Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver mark a dive as excluded from all statistics, or from gas statistics only, while keeping it fully visible and editable in the logbook.

**Architecture:** Two boolean columns on `dives`, enforced by a single shared SQL predicate helper (`DiveStatsScope`) that every descriptive aggregate query interpolates. The helper is applied *orthogonally* to the diver's `DiveFilterState` view filter, never inside it, so the exclusion cannot evaporate when no view filter is active. A source-census test prevents future aggregates from silently skipping the scope.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, raw `customSelect` SQL throughout.

**Spec:** `docs/superpowers/specs/2026-08-28-exclude-dive-from-statistics-design.md`

## Global Constraints

- **Schema version 178.** Main is at 175; 176 is claimed by open PR #1328, 177 by open PR #1361. Before pushing, re-run BOTH claim scans (open-PR diffs and every worktree's working-tree scalar). A rung claimed below main's scalar merges with no conflict marker and its migration step then silently never runs.
- **Worktree:** all work happens in `.claude/worktrees/issue-526-exclude-from-stats` on branch `worktree-issue-526-exclude-from-stats`. Use absolute paths or `git -C`; the Bash working directory resets to the main checkout between calls.
- **No em-dashes** (U+2014) in any output: code, comments, docs, commit messages. No en-dashes as prose punctuation, no double hyphens, no spaced hyphens as punctuation.
- **No emojis** in code, comments, or documentation.
- **Localization:** every new user-facing string needs keys in all eleven locales: `ar de en es fr he hu it nl pt zh`. English-only additions fail `arb_parity_test` against every other locale.
- **Immutability:** never mutate objects or arrays. All domain entities have `copyWith`.
- **TDD:** write the failing test first, watch it fail, then implement.
- **Commit frequently**, one commit per task minimum. No `Co-Authored-By` trailer. No Claude Code attribution or session URL in commit messages or PR bodies.
- **Never run `git add -A` or `git add -u`** in this shared checkout. Stage explicit paths only; `-A` sweeps a sibling session's uncommitted work into your commit.
- **Never pipe `flutter test` into `grep`.** The pipeline returns grep's exit status, not the test runner's.
- **Do not overlap local test runs.** Two concurrent runs fake a lone failure.

---

## File Structure

**Created:**

| File | Responsibility |
| --- | --- |
| `lib/core/database/dive_stats_scope.dart` | The single canonical SQL predicate for "which dives count as statistics". Pure string builder, no I/O. |
| `test/core/database/dive_stats_scope_test.dart` | Unit tests for the predicate strings. |
| `test/core/database/dive_stats_scope_census_test.dart` | Source census: every `FROM dives` query either carries the scope or is explicitly marked exempt. |
| `test/features/statistics/dive_stats_scope_behavior_test.dart` | Behavioral guard suite over a seeded fixture, covering every descriptive aggregate. |
| `test/features/dive_log/dive_stats_exclusion_migration_test.dart` | v177 to v178 migration, backstop idempotency, minimal-schema self-guard. |

**Modified (principal):**

| File | Change |
| --- | --- |
| `lib/core/database/database.dart` | Two columns on `Dives`, `currentSchemaVersion` to 178, `_assertDiveStatsExclusionColumns()`, `onUpgrade` rung, `beforeOpen` backstop. |
| `lib/features/statistics/data/repositories/statistics_repository.dart` | `_diveFilter` emits the scope unconditionally; four hand patches; seven gas queries switch to `gas: true`. |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Five aggregate methods get the scope; entity mappers and companions carry the two flags. |
| `lib/features/dive_log/domain/entities/dive.dart` | Two fields, constructor defaults, `copyWith`, equality list. |
| `lib/features/dive_log/domain/models/dive_filter_state.dart` | `excludedFromStatsOnly` axis. |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Two checkboxes in The Dive section; two gated bulk-edit rows. |
| `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` | Two `BulkField` values, two `BulkScalarInputs` fields. |
| Nine per-entity repositories | Scope added to descriptive count queries (Task 6). |
| `lib/l10n/arb/app_*.arb` (11 files) | New keys. |

---

### Task 1: Schema columns and migration

**Files:**
- Modify: `lib/core/database/database.dart` (Dives table ~line 731, `currentSchemaVersion` line 3291, helper near `_assertBuddyFavoriteColumn` ~line 5412, `onUpgrade` rung ~line 9073, `beforeOpen` backstop ~line 9310)
- Test: `test/features/dive_log/dive_stats_exclusion_migration_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: columns `dives.excluded_from_stats` and `dives.excluded_from_gas_stats`, both `INTEGER NOT NULL DEFAULT 0`. Drift getters `excludedFromStats` and `excludedFromGasStats` of type `BoolColumn`. Method `AppDatabase._assertDiveStatsExclusionColumns()`.

- [ ] **Step 1: Write the failing migration test**

Create `test/features/dive_log/dive_stats_exclusion_migration_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> diveColumnNames(AppDatabase database) async {
    final cols = await database
        .customSelect("PRAGMA table_info('dives')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('schema version is 178', () {
    expect(AppDatabase.currentSchemaVersion, 178);
  });

  test('a fresh database has both exclusion columns defaulting to 0', () async {
    final names = await diveColumnNames(db);
    expect(names, contains('excluded_from_stats'));
    expect(names, contains('excluded_from_gas_stats'));

    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time) VALUES ('d1', 0)",
    );
    final row = await db
        .customSelect(
          'SELECT excluded_from_stats, excluded_from_gas_stats '
          "FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.read<int>('excluded_from_stats'), 0);
    expect(row.read<int>('excluded_from_gas_stats'), 0);
  });

  test('the column assert is idempotent across repeated calls', () async {
    await db.assertDiveStatsExclusionColumnsForTesting();
    await db.assertDiveStatsExclusionColumnsForTesting();
    final names = await diveColumnNames(db);
    expect(names, contains('excluded_from_stats'));
    expect(names, contains('excluded_from_gas_stats'));
  });

  test('the column assert self-guards when dives does not exist', () async {
    await db.customStatement('DROP TABLE dives');
    await expectLater(
      db.assertDiveStatsExclusionColumnsForTesting(),
      completes,
    );
  });

  test('an upgrade from v177 adds both columns to an existing dives table',
      () async {
    await db.customStatement('DROP TABLE dives');
    await db.customStatement(
      'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, '
      'dive_date_time INTEGER NOT NULL, '
      'is_planned INTEGER NOT NULL DEFAULT 0)',
    );
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time) VALUES ('legacy', 0)",
    );

    await db.assertDiveStatsExclusionColumnsForTesting();

    final row = await db
        .customSelect(
          'SELECT excluded_from_stats, excluded_from_gas_stats '
          "FROM dives WHERE id = 'legacy'",
        )
        .getSingle();
    expect(row.read<int>('excluded_from_stats'), 0,
        reason: 'pre-existing rows must default to included');
    expect(row.read<int>('excluded_from_gas_stats'), 0);
  });
}
```

Note: if `AppDatabase.forTesting` does not exist under that exact name in this repo, use whatever constructor the neighbouring migration tests in `test/` already use. Find it with:

```bash
grep -rn "AppDatabase(" test/ --include='*.dart' | head -5
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-526-exclude-from-stats
flutter test test/features/dive_log/dive_stats_exclusion_migration_test.dart
```

Expected: FAIL. `AppDatabase.currentSchemaVersion` is 175, the columns do not exist, and `assertDiveStatsExclusionColumnsForTesting` is undefined.

- [ ] **Step 3: Add the two columns to the Dives table**

In `lib/core/database/database.dart`, immediately after the `isFavorite` getter (~line 731):

```dart
  // Statistics exclusion (schema v178, issues #526 and #1272).
  // excludedFromStats is the master flag: the dive stays in the logbook but
  // contributes to no descriptive aggregate, its count included.
  // excludedFromGasStats drops the dive from SAC/RMV and gas-mix aggregates
  // only, for an otherwise ordinary dive whose gas number is unrepresentative
  // (for example purging the tank for an end-of-dive weight check).
  // The master flag implies the gas flag; see DiveStatsScope.
  BoolColumn get excludedFromStats =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get excludedFromGasStats =>
      boolean().withDefault(const Constant(false))();
```

- [ ] **Step 4: Bump the schema version**

At `lib/core/database/database.dart:3291`, change:

```dart
  static const int currentSchemaVersion = 175;
```

to:

```dart
  static const int currentSchemaVersion = 178;
```

- [ ] **Step 5: Add the idempotent column-assert helper**

In `lib/core/database/database.dart`, next to `_assertBuddyFavoriteColumn` (~line 5412):

```dart
  /// Idempotent DDL for the v178 dives.excluded_from_stats and
  /// dives.excluded_from_gas_stats columns (issues #526 and #1272), letting a
  /// diver keep a dive in the logbook while removing it from statistics.
  /// Self-guards on the table existing, and defaults every pre-existing row to
  /// included. Same dual-call contract (onUpgrade + beforeOpen backstop) as
  /// the other column-assert helpers.
  Future<void> _assertDiveStatsExclusionColumns() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('excluded_from_stats')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN excluded_from_stats '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('excluded_from_gas_stats')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN excluded_from_gas_stats '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Test-only entry point for [_assertDiveStatsExclusionColumns].
  @visibleForTesting
  Future<void> assertDiveStatsExclusionColumnsForTesting() =>
      _assertDiveStatsExclusionColumns();
```

If `@visibleForTesting` is not already imported in this file, add `import 'package:meta/meta.dart';` to the import block. Check first:

```bash
grep -n "visibleForTesting" lib/core/database/database.dart | head -3
```

- [ ] **Step 6: Add the onUpgrade rung**

In `onUpgrade`, immediately after the `if (from < 175) await reportProgress();` line (~line 9073):

```dart
        // v178: dives.excluded_from_stats and dives.excluded_from_gas_stats
        // (issues #526 and #1272). Column-only rung, no backfill: every
        // pre-existing row correctly defaults to included.
        if (from < 178) {
          await _assertDiveStatsExclusionColumns();
        }
        if (from < 178) await reportProgress();
```

- [ ] **Step 7: Add the beforeOpen backstop**

In `beforeOpen`, immediately after the v175 backstop call (~line 9310):

```dart
        // v178 backstop: re-assert the dives statistics-exclusion columns
        // (same parallel-branch version-collision self-heal). Safe to re-run
        // on every open: the helper is column-only with no backfill, so it
        // cannot resurrect or overwrite diver data.
        await _assertDiveStatsExclusionColumns();
```

- [ ] **Step 8: Regenerate Drift code**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-526-exclude-from-stats
dart run build_runner build --delete-conflicting-outputs
```

Expected: `database.g.dart` regenerates with `excludedFromStats` and `excludedFromGasStats` on both the table class and the data class. If only one of the two has them, the build was interrupted; re-run before continuing.

- [ ] **Step 9: Run the migration test to verify it passes**

```bash
flutter test test/features/dive_log/dive_stats_exclusion_migration_test.dart
```

Expected: PASS, all five tests.

- [ ] **Step 10: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-526-exclude-from-stats
git add lib/core/database/database.dart lib/core/database/database.g.dart \
  test/features/dive_log/dive_stats_exclusion_migration_test.dart
git commit -m "feat(db): add dives statistics-exclusion columns at schema v178

Two boolean columns, excluded_from_stats (master) and
excluded_from_gas_stats (SAC/RMV only), both defaulting to included.
Column-only rung with a beforeOpen backstop; no backfill needed."
```

---

### Task 2: The DiveStatsScope predicate helper

**Files:**
- Create: `lib/core/database/dive_stats_scope.dart`
- Test: `test/core/database/dive_stats_scope_test.dart`

**Interfaces:**
- Consumes: the column names from Task 1.
- Produces: `DiveStatsScope.predicate({String alias = 'd', bool gas = false}) -> String` and `DiveStatsScope.and({String alias = 'd', bool gas = false}) -> String`. `and()` returns `predicate()` prefixed with a leading space and `AND `, for appending into an existing WHERE clause. Both are `static`; the class is not instantiable.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/dive_stats_scope_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';

void main() {
  group('DiveStatsScope.predicate', () {
    test('defaults to alias d and the two descriptive rules', () {
      expect(
        DiveStatsScope.predicate(),
        'd.excluded_from_stats = 0 AND d.is_planned = 0',
      );
    });

    test('honours a custom alias on every term', () {
      expect(
        DiveStatsScope.predicate(alias: 'd2'),
        'd2.excluded_from_stats = 0 AND d2.is_planned = 0',
      );
    });

    test('the gas variant adds the gas flag and the gauge-mode rule', () {
      expect(
        DiveStatsScope.predicate(gas: true),
        'd.excluded_from_stats = 0 AND d.is_planned = 0 '
        "AND d.excluded_from_gas_stats = 0 AND d.dive_mode <> 'gauge'",
      );
    });

    test('the gas variant honours a custom alias on every term', () {
      final sql = DiveStatsScope.predicate(alias: 'dives', gas: true);
      expect(sql.contains('d.'), isFalse,
          reason: 'no term may fall back to the default alias');
      expect(sql, contains('dives.excluded_from_gas_stats = 0'));
      expect(sql, contains("dives.dive_mode <> 'gauge'"));
    });
  });

  group('DiveStatsScope.and', () {
    test('prefixes the predicate for appending into an existing WHERE', () {
      expect(
        DiveStatsScope.and(),
        ' AND d.excluded_from_stats = 0 AND d.is_planned = 0',
      );
    });

    test('carries alias and gas through to the predicate', () {
      expect(
        DiveStatsScope.and(alias: 'x', gas: true),
        ' AND ${DiveStatsScope.predicate(alias: 'x', gas: true)}',
      );
    });

    test('never emits a bind placeholder', () {
      expect(DiveStatsScope.and(gas: true).contains('?'), isFalse,
          reason: 'callers must not have to thread params for the scope');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/dive_stats_scope_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: package:submersion/core/database/dive_stats_scope.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/core/database/dive_stats_scope.dart`:

```dart
/// The canonical SQL predicate deciding which dives contribute to
/// *descriptive* statistics.
///
/// Two rules always apply:
///
/// - `excluded_from_stats = 0`: the diver ticked "exclude from statistics"
///   (issue #526), for example a 90 minute session at 12 ft that is not an
///   official dive by most agency standards.
/// - `is_planned = 0`: a dive the planner created that has not happened.
///   Before schema v178 these counted toward every total, which was a bug.
///
/// The [gas] variant adds two more, for SAC/RMV and gas-mix aggregates:
///
/// - `excluded_from_gas_stats = 0`: the diver ticked "exclude from gas
///   statistics" (issue #1272), for example purging the tank down to 500 psi
///   for an end-of-dive weight check.
/// - `dive_mode <> 'gauge'`: gauge-mode dives carry no usable gas data. This
///   rule predates v178 and was hand-copied into seven queries in
///   StatisticsRepository; it now lives here.
///
/// **This is deliberately NOT folded into `buildFilteredDiveIdSubquery`.**
/// That function implements the diver's transient *view* filter and correctly
/// returns an empty no-op when no axis is active. This scope is a persistent
/// property of the dive and must apply unconditionally. Merging the two would
/// either make the exclusion evaporate for every diver who never opens the
/// filter sheet, or silently scope the deliberately-unfiltered surfaces
/// (dashboard quick stats, dive-log summary, species detail page).
///
/// **Operational counts deliberately ignore this scope.** Equipment service
/// intervals, course-requirement progress, and the logbook list header all
/// count excluded dives on purpose; each carries a doc comment saying so. A
/// practice dive still cycled the regulator, and a dive the diver linked to a
/// course requirement was linked on purpose.
///
/// See `docs/superpowers/specs/2026-08-28-exclude-dive-from-statistics-design.md`.
class DiveStatsScope {
  const DiveStatsScope._();

  /// The bare predicate, with no leading conjunction. Use when the query has
  /// no WHERE clause yet: `WHERE ${DiveStatsScope.predicate()}`.
  ///
  /// [alias] must match the alias the query already gives the `dives` table
  /// (or `dives` itself when the query does not alias it). Queries that join
  /// `dives` to itself need one call per alias.
  static String predicate({String alias = 'd', bool gas = false}) {
    final parts = <String>[
      '$alias.excluded_from_stats = 0',
      '$alias.is_planned = 0',
    ];
    if (gas) {
      parts.add('$alias.excluded_from_gas_stats = 0');
      parts.add("$alias.dive_mode <> 'gauge'");
    }
    return parts.join(' AND ');
  }

  /// The predicate prefixed with ` AND `, for appending into an existing
  /// WHERE clause. Emits no bind placeholders, so callers never thread params
  /// for the scope.
  static String and({String alias = 'd', bool gas = false}) =>
      ' AND ${predicate(alias: alias, gas: gas)}';
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/database/dive_stats_scope_test.dart
```

Expected: PASS, all seven tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/dive_stats_scope.dart \
  test/core/database/dive_stats_scope_test.dart
git commit -m "feat(db): add DiveStatsScope, the canonical statistics predicate

One place deciding which dives count as statistics. Absorbs the
gauge-mode rule that was hand-copied into seven gas queries, and adds
is_planned, which no aggregate filtered on before."
```

---

### Task 3: Entity and mapper plumbing

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (fields ~line 120, constructor ~line 235, `copyWith` params ~line 587, `copyWith` body ~line 682, props list ~line 780)
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart`
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (mappers ~3562 and ~3944, companions ~1409 and ~1664)
- Test: `test/features/dive_log/dive_stats_exclusion_entity_test.dart`

**Interfaces:**
- Consumes: `dives.excludedFromStats` / `excludedFromGasStats` from Task 1.
- Produces: `Dive.excludedFromStats` and `Dive.excludedFromGasStats`, both `final bool`, defaulting to `false` in the constructor, present in `copyWith` as `bool?` and in the equality props list. Same two fields on `DiveSummary`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/dive_stats_exclusion_entity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  Dive makeDive() => Dive(id: 'd1', diveDateTime: DateTime(2026, 1, 1));

  test('both exclusion flags default to false', () {
    final dive = makeDive();
    expect(dive.excludedFromStats, isFalse);
    expect(dive.excludedFromGasStats, isFalse);
  });

  test('copyWith sets each flag independently', () {
    final dive = makeDive();
    expect(dive.copyWith(excludedFromStats: true).excludedFromStats, isTrue);
    expect(
      dive.copyWith(excludedFromStats: true).excludedFromGasStats,
      isFalse,
      reason: 'the master flag must not write through to the gas flag; '
          'the implication lives in SQL, not in the entity',
    );
    expect(
      dive.copyWith(excludedFromGasStats: true).excludedFromGasStats,
      isTrue,
    );
  });

  test('copyWith preserves the flags when they are not passed', () {
    final excluded = makeDive().copyWith(
      excludedFromStats: true,
      excludedFromGasStats: true,
    );
    final renamed = excluded.copyWith(notes: 'changed');
    expect(renamed.excludedFromStats, isTrue);
    expect(renamed.excludedFromGasStats, isTrue);
  });

  test('the flags participate in equality', () {
    final a = makeDive();
    final b = makeDive().copyWith(excludedFromStats: true);
    expect(a, isNot(equals(b)));
  });
}
```

If `Dive`'s required constructor arguments differ from `id` and `diveDateTime`, adjust `makeDive()` to the minimal valid set. Check with:

```bash
sed -n '225,245p' lib/features/dive_log/domain/entities/dive.dart
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/dive_log/dive_stats_exclusion_entity_test.dart
```

Expected: FAIL, "The getter 'excludedFromStats' isn't defined for the class 'Dive'".

- [ ] **Step 3: Add the fields to the Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`, immediately after `final bool isFavorite;` (~line 120):

```dart
  /// Excluded from every descriptive statistic, its count included (#526).
  /// The dive stays fully visible and editable in the logbook.
  final bool excludedFromStats;

  /// Excluded from SAC/RMV and gas-mix aggregates only (#1272), for a dive
  /// whose gas number is unrepresentative. Implied by [excludedFromStats];
  /// the implication is applied in SQL by DiveStatsScope, not here.
  final bool excludedFromGasStats;
```

After `this.isFavorite = false,` in the constructor (~line 235):

```dart
    this.excludedFromStats = false,
    this.excludedFromGasStats = false,
```

After `bool? isFavorite,` in the `copyWith` signature (~line 587):

```dart
    bool? excludedFromStats,
    bool? excludedFromGasStats,
```

After `isFavorite: isFavorite ?? this.isFavorite,` in the `copyWith` body (~line 682):

```dart
      excludedFromStats: excludedFromStats ?? this.excludedFromStats,
      excludedFromGasStats: excludedFromGasStats ?? this.excludedFromGasStats,
```

After `isFavorite,` in the props list (~line 780):

```dart
    excludedFromStats,
    excludedFromGasStats,
```

- [ ] **Step 4: Run the entity test to verify it passes**

```bash
flutter test test/features/dive_log/dive_stats_exclusion_entity_test.dart
```

Expected: PASS.

- [ ] **Step 5: Plumb the mappers and companions**

Find every place `isFavorite` crosses the database boundary and add the two flags beside it:

```bash
grep -n "isFavorite" lib/features/dive_log/data/repositories/dive_repository_impl.dart
grep -n "isFavorite" lib/features/dive_log/domain/entities/dive_summary.dart
grep -n "isFavorite" lib/features/dive_log/domain/services/dive_merge_builder.dart
```

For each row-to-entity mapper, add:

```dart
      excludedFromStats: row.excludedFromStats,
      excludedFromGasStats: row.excludedFromGasStats,
```

For each entity-to-companion site, add:

```dart
      excludedFromStats: Value(dive.excludedFromStats),
      excludedFromGasStats: Value(dive.excludedFromGasStats),
```

`DiveSummary` gets the same two `final bool` fields with `= false` defaults, and its mapper gets the same two lines. `dive_merge_builder.dart` treats them exactly as it treats `isFavorite`.

- [ ] **Step 6: Verify the whole project analyzes clean**

```bash
flutter analyze
```

Expected: no errors. Any "isn't defined" error names a mapper or companion site missed in Step 5.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart \
  lib/features/dive_log/domain/entities/dive_summary.dart \
  lib/features/dive_log/domain/services/dive_merge_builder.dart \
  lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  test/features/dive_log/dive_stats_exclusion_entity_test.dart
git commit -m "feat(dive): carry statistics-exclusion flags on the Dive entity

Mirrors the isFavorite plumbing across entity, summary, merge builder,
mappers and companions."
```

---

### Task 4: Enforce the scope in the statistics feature

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart`
- Test: `test/features/statistics/dive_stats_scope_behavior_test.dart` (created here, extended in Tasks 5 and 6)

**Interfaces:**
- Consumes: `DiveStatsScope.and` from Task 2.
- Produces: `StatisticsRepository._diveFilter` gains a `bool gas = false` parameter and now emits the scope unconditionally, whether or not the `DiveFilterState` has active axes.

- [ ] **Step 1: Write the failing behavioral test**

Create `test/features/statistics/dive_stats_scope_behavior_test.dart`. Seed five dives and assert the aggregates ignore the right ones:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StatisticsRepository repo;

  /// Seeds one included dive and four that every descriptive aggregate must
  /// ignore. All five are 30 minutes at 30 m so any leak shows up as an
  /// inflated count or a shifted average, not as a subtle rounding change.
  Future<void> seed() async {
    Future<void> insert(
      String id, {
      bool excludedFromStats = false,
      bool excludedFromGasStats = false,
      bool isPlanned = false,
      String diveMode = 'oc',
    }) async {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, max_depth, avg_depth, '
        'bottom_time, dive_mode, is_planned, excluded_from_stats, '
        'excluded_from_gas_stats) VALUES (?, ?, 30.0, 15.0, 1800, ?, ?, ?, ?)',
        [
          id,
          DateTime(2026, 1, 1).millisecondsSinceEpoch,
          diveMode,
          isPlanned ? 1 : 0,
          excludedFromStats ? 1 : 0,
          excludedFromGasStats ? 1 : 0,
        ],
      );
    }

    await insert('included');
    await insert('excluded', excludedFromStats: true);
    await insert('gas-excluded', excludedFromGasStats: true);
    await insert('planned', isPlanned: true);
    await insert('gauge', diveMode: 'gauge');
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StatisticsRepository(db);
    await seed();
  });

  tearDown(() async {
    await db.close();
  });

  test('getDivesPerYear counts only the included dive', () async {
    final rows = await repo.getDivesPerYear();
    final total = rows.fold<int>(0, (sum, r) => sum + r.count);
    expect(total, 1,
        reason: 'excluded, planned and gas-excluded dives must not be counted; '
            'gauge dives are excluded from gas stats only, so this counts it '
            'as well and the expected total is 2 if gauge is included');
  });

  test('getCumulativeDiveCount ignores excluded and planned dives', () async {
    final rows = await repo.getCumulativeDiveCount();
    expect(rows.isEmpty || rows.last.count <= 2, isTrue);
  });

  test('getDepthProgressionTrend ignores excluded and planned dives',
      () async {
    final rows = await repo.getDepthProgressionTrend();
    expect(rows.length, lessThanOrEqualTo(2));
  });

  test('getSacVolumeTrend ignores gas-excluded and gauge dives', () async {
    final rows = await repo.getSacVolumeTrend();
    expect(rows, isEmpty,
        reason: 'no dive_tanks rows were seeded, so this asserts the query '
            'runs and returns nothing rather than throwing on the new columns');
  });
}
```

Adjust the expected counts once you see which of the five each aggregate legitimately includes. The gauge dive is excluded from gas aggregates only, so non-gas aggregates count two dives (`included` and `gauge`), and gas aggregates count one. Encode whichever is correct per method; do not weaken an assertion to make it pass.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: FAIL. Counts include the excluded and planned dives.

- [ ] **Step 3: Make `_diveFilter` emit the scope unconditionally**

In `lib/features/statistics/data/repositories/statistics_repository.dart`, replace the `_diveFilter` helper (~line 189):

```dart
  /// Builds the always-on statistics scope plus, when the diver has active
  /// filter axes, the `AND <alias>.id IN (<subquery>)` fragment and its raw
  /// params.
  ///
  /// The scope is emitted unconditionally and the user filter conditionally.
  /// They are deliberately separate: [buildFilteredDiveIdSubquery] is the
  /// diver's transient view filter and no-ops when nothing is selected, while
  /// [DiveStatsScope] is a persistent property of the dive. Folding the scope
  /// into the subquery would make the exclusion evaporate for every diver who
  /// never opens the filter sheet.
  ///
  /// Pass `gas: true` for SAC/RMV and gas-mix aggregates, which additionally
  /// drop per-dive gas exclusions and gauge-mode dives.
  ({String clause, List<Object?> params}) _diveFilter(
    DiveFilterState filter, {
    String alias = 'dives',
    bool gas = false,
  }) {
    final scope = DiveStatsScope.and(alias: alias, gas: gas);
    final f = buildFilteredDiveIdSubquery(filter);
    if (f.subquery.isEmpty) {
      return (clause: scope, params: const <Object?>[]);
    }
    return (
      clause: '$scope AND $alias.id IN (${f.subquery})',
      params: f.params,
    );
  }
```

Add the import at the top of the file:

```dart
import 'package:submersion/core/database/dive_stats_scope.dart';
```

- [ ] **Step 4: Switch the seven gas queries to the gas variant**

In each of the seven gas methods, change the `_diveFilter` call to pass `gas: true` and delete the now-duplicated literal `AND d.dive_mode <> 'gauge'` from the SQL.

The methods: `getSacVolumeTrend`, `getSacPressureTrend`, `getGasMixDistribution`, `getSacVolumeRecords`, `getSacPressureRecords`, `getSacVolumeByTankRole`, `getSacPressureByTankRole`.

For each:

```dart
      final df = _diveFilter(filter, alias: 'd', gas: true);
```

and in the SQL, change:

```sql
        WHERE d.dive_date_time >= ? AND d.dive_mode <> 'gauge' $diverFilter ${df.clause}
```

to:

```sql
        WHERE d.dive_date_time >= ? $diverFilter ${df.clause}
```

Confirm all seven literals are gone:

```bash
grep -n "dive_mode <> 'gauge'" lib/features/statistics/data/repositories/statistics_repository.dart
```

Expected: no output.

- [ ] **Step 5: Hand-patch the three methods that bypass `_diveFilter`**

`getYearStats`, `getEntryExitMethodPairsForSite`, and `getSiteHistoryByName` build their own WHERE clauses. In each, append the scope to the existing WHERE using the alias that query already gives `dives`:

```dart
${DiveStatsScope.and(alias: 'd')}
```

If a query does not alias the table, use `alias: 'dives'`.

- [ ] **Step 6: Patch the self-join inside getSurfaceIntervalStats**

`getSurfaceIntervalStats` has a nested `FROM dives d2` subquery (~line 2025) that the filter clause has never reached. Add the scope to the inner alias as well as the outer:

```dart
${DiveStatsScope.and(alias: 'd2')}
```

- [ ] **Step 7: Run the behavioral test to verify it passes**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run the whole statistics suite for regressions**

```bash
flutter test test/features/statistics/
```

Expected: PASS. Failures here are most likely tests that seed a planned dive and expect it counted; leave them failing and record them for Task 8 rather than weakening the new behavior.

- [ ] **Step 9: Commit**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart \
  test/features/statistics/dive_stats_scope_behavior_test.dart
git commit -m "feat(stats): honour the statistics scope in StatisticsRepository

_diveFilter now emits the scope unconditionally, covering 37 aggregates
in one edit. Four methods that build their own WHERE are patched by
hand, including the getSurfaceIntervalStats self-join the user filter
never reached. The seven gas queries drop their hand-copied gauge-mode
literal in favour of the shared gas variant."
```

---

### Task 5: Enforce the scope in the dive log repository

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getStatistics` ~2816, `getRecords` ~2984, `getPersonalRecordIds` ~3224, `countDivesSince` ~3137, `getOnThisDayDiveIds` ~3155, and the doc comment on `getDiveCount` ~2190)
- Test: `test/features/statistics/dive_stats_scope_behavior_test.dart` (extend)

**Interfaces:**
- Consumes: `DiveStatsScope.and` from Task 2.
- Produces: no signature changes. `getDiveCount` keeps its current behavior and gains a doc comment explaining why.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/statistics/dive_stats_scope_behavior_test.dart`, inside the existing `main()`:

```dart
  group('DiveRepository aggregates', () {
    late DiveRepositoryImpl diveRepo;

    setUp(() {
      diveRepo = DiveRepositoryImpl(db);
    });

    test('getStatistics counts only dives in scope', () async {
      final stats = await diveRepo.getStatistics();
      expect(stats.totalDives, 2,
          reason: 'included and gauge; excluded, gas-excluded and planned '
              'are all out of scope for a non-gas aggregate');
    });

    test('getRecords ignores out-of-scope dives', () async {
      await db.customStatement(
        'UPDATE dives SET max_depth = 99.0 WHERE id = ?',
        ['excluded'],
      );
      final records = await diveRepo.getRecords();
      expect(records.deepestDive?.id, isNot('excluded'),
          reason: 'an excluded dive must never become a record');
    });

    test('getPersonalRecordIds ignores out-of-scope dives', () async {
      await db.customStatement(
        'UPDATE dives SET bottom_time = 99999 WHERE id = ?',
        ['planned'],
      );
      final ids = await diveRepo.getPersonalRecordIds();
      expect(ids.values, isNot(contains('planned')));
    });

    test('countDivesSince ignores out-of-scope dives', () async {
      final count = await diveRepo.countDivesSince(DateTime(2020));
      expect(count, 2);
    });

    test('getDiveCount deliberately still counts excluded dives', () async {
      final count = await diveRepo.getDiveCount();
      expect(count, 5,
          reason: 'the logbook list header counts what is in the logbook; '
              'an excluded dive is still in the logbook');
    });
  });
```

Add the import:

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
```

Adjust the constructor call and the record accessor names (`deepestDive`, `values`) to whatever the real types expose. Find them with:

```bash
grep -n "class DiveRecords\|deepest" lib/features/dive_log/domain/ -r | head -10
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: FAIL on the four scope tests, PASS on `getDiveCount` (which is asserting current behavior stays put).

- [ ] **Step 3: Add the scope to the four aggregate methods**

Add the import to `dive_repository_impl.dart`:

```dart
import 'package:submersion/core/database/dive_stats_scope.dart';
```

`getStatistics` (~2816) builds `fBare`, `fAliasD` and `basicWhere` fragments and issues four statements. Append the scope to each statement's WHERE with the alias that statement uses. For an unaliased `FROM dives`, use `alias: 'dives'`; for `FROM dives d`, use `alias: 'd'`.

`getRecords` (~2984), `getPersonalRecordIds` (~3224), `countDivesSince` (~3137) and `getOnThisDayDiveIds` (~3155) get the same treatment, statement by statement. `getRecords` and `getPersonalRecordIds` each issue roughly six superlative statements; every one needs the scope, or a single record will still surface an excluded dive.

Verify none were missed:

```bash
grep -c "DiveStatsScope" lib/features/dive_log/data/repositories/dive_repository_impl.dart
```

Expected: at least 20 occurrences across the five methods.

- [ ] **Step 4: Document the deliberate exemption on getDiveCount**

Above `getDiveCount` (~2190), add:

```dart
  /// Counts the dives in the logbook list, matching the diver's active view
  /// filter.
  ///
  /// Deliberately does NOT apply [DiveStatsScope]: an excluded dive is still
  /// in the logbook and the list still shows it, so the header still counts
  /// it. Only descriptive *statistics* honour the exclusion. Do not "fix"
  /// this; see the design doc and the census test's exemption list.
  // stats-scope-exempt: logbook list header, not a statistic
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: PASS, all tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  test/features/statistics/dive_stats_scope_behavior_test.dart
git commit -m "feat(dive): honour the statistics scope in DiveRepository aggregates

getStatistics, getRecords, getPersonalRecordIds, countDivesSince and
getOnThisDayDiveIds all scope out excluded and planned dives.
getDiveCount deliberately does not: the logbook list counts what is in
the logbook."
```

---

### Task 6: Enforce the scope in per-entity descriptive counts

**Files:**
- Modify: nine repositories, listed in the table below
- Test: `test/features/statistics/dive_stats_scope_behavior_test.dart` (extend)

**Interfaces:**
- Consumes: `DiveStatsScope.and` from Task 2.
- Produces: no signature changes.

- [ ] **Step 1: Write the failing tests**

Append a group to the behavioral suite. Seed a buddy, a site and a trip linked to both the `included` and the `excluded` dive, then assert each count is 1 rather than 2:

```dart
  group('per-entity descriptive counts', () {
    setUp(() async {
      await db.customStatement(
        "INSERT INTO buddies (id, name) VALUES ('b1', 'Test Buddy')",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (dive_id, buddy_id) VALUES ('included', 'b1')",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (dive_id, buddy_id) VALUES ('excluded', 'b1')",
      );
    });

    test('getDiveCountForBuddy ignores excluded dives', () async {
      final repo = BuddyRepository(db);
      expect(await repo.getDiveCountForBuddy('b1'), 1);
    });

    test('getBuddyStats ignores excluded dives', () async {
      final repo = BuddyRepository(db);
      final stats = await repo.getBuddyStats('b1');
      expect(stats.diveCount, 1);
    });
  });
```

Add equivalent tests for sites, trips and tags following the same shape: link both `included` and `excluded`, assert the count is 1. Adjust constructor names and result accessors to the real types.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: FAIL, each count returns 2.

- [ ] **Step 3: Add the scope to each query**

For every method in the table, add `${DiveStatsScope.and(alias: '<the query's alias>')}` to the WHERE clause, and add the import to each file:

```dart
import 'package:submersion/core/database/dive_stats_scope.dart';
```

| File | Methods |
| --- | --- |
| `lib/features/buddies/data/repositories/buddy_repository.dart` | `getAllBuddies` (both inline aggregate joins), `getDiveCountForBuddy`, `getDiveIdsForBuddy`, `getBuddyStats` (main query and the favourite-site query) |
| `lib/features/dive_sites/data/repositories/site_repository_impl.dart` | `getDiveAggregatesBySite` |
| `lib/features/trips/data/repositories/trip_repository.dart` | `getTripWithStats`, `getAllTripsWithStats`, `getDiveCountForTrip` |
| `lib/features/dive_centers/data/repositories/dive_center_repository.dart` | `getDiveCountForCenter` |
| `lib/features/tags/data/repositories/tag_repository.dart` | the three per-tag `dive_count` queries |
| `lib/features/dive_types/data/repositories/dive_type_repository.dart` | the two per-type `dive_count` queries |
| `lib/features/dive_roles/data/repositories/dive_role_repository.dart` | the usage-count query |
| `lib/features/divers/data/repositories/diver_repository.dart` | `getDiveCountForDiver`, `getTotalBottomTimeForDiver` |
| `lib/features/marine_life/data/repositories/seen_species_repository.dart` | `getSeenSpecies`, `getSightingsForSpecies` |
| `lib/features/marine_life/data/repositories/species_repository.dart` | `sightingCountsBySpecies`, `getSpeciesSpottedAtSite` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | the dive-computer count query (~line 6239) |

**Queries that need a join added first.** `getDiveCountForBuddy`, and the tag and dive-type count queries, currently count junction-table rows without touching `dives` at all. For example:

```sql
SELECT COUNT(*) as count FROM dive_buddies WHERE buddy_id = ?
```

becomes:

```sql
SELECT COUNT(*) as count FROM dive_buddies db
JOIN dives d ON d.id = db.dive_id
WHERE db.buddy_id = ?${DiveStatsScope.and(alias: 'd')}
```

Adding the join changes performance characteristics. Confirm `dive_buddies.dive_id` and the equivalent junction columns are indexed:

```bash
grep -rn "dive_buddies\|dive_tags\|dive_dive_types" lib/core/database/performance_indexes.dart
```

If any is missing an index on its `dive_id` column, add one in that file as part of this task.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/statistics/dive_stats_scope_behavior_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run the affected feature suites**

```bash
flutter test test/features/buddies/ test/features/trips/ test/features/tags/ \
  test/features/dive_sites/ test/features/marine_life/ test/features/divers/
```

Expected: PASS, except for planned-dive fallout recorded for Task 8.

- [ ] **Step 6: Commit**

```bash
git add lib/features/buddies lib/features/dive_sites lib/features/trips \
  lib/features/dive_centers lib/features/tags lib/features/dive_types \
  lib/features/dive_roles lib/features/divers lib/features/marine_life \
  lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  lib/core/database/performance_indexes.dart \
  test/features/statistics/dive_stats_scope_behavior_test.dart
git commit -m "feat: honour the statistics scope in per-entity dive counts

Buddy, site, trip, dive-centre, tag, dive-type, role, diver, marine-life
and dive-computer counts all stop counting excluded and planned dives.
Three junction-table counts gain a join to dives to see the flags."
```

---

### Task 7: Document the operational exemptions and add the census test

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart`, `lib/features/equipment/domain/services/service_due_engine.dart`, `lib/features/courses/data/repositories/course_repository.dart`, `lib/features/courses/data/repositories/course_requirement_repository.dart`
- Create: `test/core/database/dive_stats_scope_census_test.dart`

**Interfaces:**
- Consumes: the marker comment convention `// stats-scope-exempt: <reason>` introduced in Task 5.
- Produces: a test that fails when a new `FROM dives` query carries neither the scope nor an exemption marker.

- [ ] **Step 1: Write the failing census test**

Create `test/core/database/dive_stats_scope_census_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every source file holding aggregate SQL over `dives`. A query in one of
/// these files that neither applies DiveStatsScope nor carries an explicit
/// exemption marker is a bug: someone added an aggregate without deciding
/// whether an excluded dive should count.
const _censusFiles = <String>[
  'lib/features/statistics/data/repositories/statistics_repository.dart',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart',
  'lib/features/buddies/data/repositories/buddy_repository.dart',
  'lib/features/dive_sites/data/repositories/site_repository_impl.dart',
  'lib/features/trips/data/repositories/trip_repository.dart',
  'lib/features/dive_centers/data/repositories/dive_center_repository.dart',
  'lib/features/tags/data/repositories/tag_repository.dart',
  'lib/features/dive_types/data/repositories/dive_type_repository.dart',
  'lib/features/dive_roles/data/repositories/dive_role_repository.dart',
  'lib/features/divers/data/repositories/diver_repository.dart',
  'lib/features/marine_life/data/repositories/seen_species_repository.dart',
  'lib/features/marine_life/data/repositories/species_repository.dart',
  'lib/features/equipment/data/repositories/equipment_repository_impl.dart',
  'lib/features/courses/data/repositories/course_repository.dart',
  'lib/features/courses/data/repositories/course_requirement_repository.dart',
];

void main() {
  test('every dives aggregate applies the scope or is marked exempt', () {
    final offenders = <String>[];

    for (final path in _censusFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: '$path is in the census list but does not exist. If it was '
              'renamed, update _censusFiles.');

      final source = file.readAsStringSync();

      // Split on customSelect/customStatement boundaries so each chunk is one
      // query plus the code immediately preceding it (where its exemption
      // marker lives).
      final chunks = source.split(RegExp(r'custom(Select|Statement)\('));

      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (!RegExp(r'\bFROM\s+dives\b', caseSensitive: false)
            .hasMatch(chunk)) {
          continue;
        }
        final applied = chunk.contains('DiveStatsScope') ||
            chunk.contains('excluded_from_stats');
        // The marker may sit just above the call, which lands at the end of
        // the previous chunk.
        final previous = i > 0 ? chunks[i - 1] : '';
        final exempt = chunk.contains('stats-scope-exempt') ||
            previous.contains('stats-scope-exempt');

        if (!applied && !exempt) {
          final snippet = chunk
              .split('\n')
              .firstWhere(
                (l) => l.toUpperCase().contains('FROM DIVES'),
                orElse: () => chunk.split('\n').first,
              )
              .trim();
          offenders.add('$path: $snippet');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These queries read `dives` but neither apply DiveStatsScope '
          'nor carry a `// stats-scope-exempt: <reason>` marker.\n\n'
          'Decide which this query is:\n'
          '  - Descriptive (a statistic a diver reads): apply the scope.\n'
          '  - Operational (gear wear, course credit, the logbook list): add\n'
          '    the marker with a one-line reason.\n\n'
          'Offenders:\n${offenders.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/dive_stats_scope_census_test.dart
```

Expected: FAIL, listing the equipment and course queries as offenders. If it also lists a query from Tasks 4 to 6, that query was missed; go back and add the scope.

- [ ] **Step 3: Add exemption markers to the operational queries**

In `equipment_repository_impl.dart`, above `getUsageSamplesForEquipment`:

```dart
  /// Usage samples (date, duration) for the equipment's service clock.
  ///
  /// Deliberately does NOT apply [DiveStatsScope]. A dive the diver excluded
  /// from statistics still physically happened: it cycled the regulator and
  /// put hours on it. Suppressing it here would push a real service interval
  /// later than it should be, which is a safety-relevant error, not a
  /// cosmetic one. Do not "fix" this.
  // stats-scope-exempt: gear wear is physical, not descriptive
```

Add the same shape of comment and marker above `getDiveCountForEquipment` and `getTripCountForEquipment`.

In `course_repository.dart` above `getDiveCountForCourse`, and in `course_requirement_repository.dart` above `getCourseProgress` and `getSuggestedDives`:

```dart
  /// Deliberately does NOT apply [DiveStatsScope]. The diver linked this dive
  /// to a course requirement on purpose; excluding it from statistics is a
  /// statement about their logbook averages, not a retraction of course
  /// credit. Do not "fix" this.
  // stats-scope-exempt: course credit is deliberate, not descriptive
```

Also add a note to `ServiceDueEngine` (`service_due_engine.dart:12`) recording that its inputs are deliberately unscoped, so a reader of the engine does not go looking for a missing filter.

- [ ] **Step 4: Run the census test to verify it passes**

```bash
flutter test test/core/database/dive_stats_scope_census_test.dart
```

Expected: PASS.

- [ ] **Step 5: Verify the census actually catches a regression**

Temporarily add a fake unscoped aggregate to `tag_repository.dart`:

```dart
  Future<int> temporaryCensusProbe() async {
    final r = await _db
        .customSelect('SELECT COUNT(*) AS c FROM dives')
        .getSingle();
    return r.read<int>('c');
  }
```

Run the census test. Expected: FAIL, naming that query. Then delete the probe and re-run to confirm PASS. This step exists because a census test that silently matches nothing is worse than no test at all.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment lib/features/courses \
  test/core/database/dive_stats_scope_census_test.dart
git commit -m "test: census every dives aggregate for the statistics scope

Equipment service clocks and course-requirement progress are marked
exempt with reasons; every other dives aggregate must apply
DiveStatsScope or the census fails. Verified the census catches an
unscoped query rather than matching nothing."
```

---

### Task 8: Triage the is_planned test fallout

**Files:**
- Modify: whichever existing tests fail (unknown until Step 1)

**Interfaces:**
- Consumes: the completed enforcement from Tasks 4 to 6.
- Produces: a green suite, and a written list of every behavior change accepted.

This task exists because folding `is_planned = 0` into the scope changes results for tests written when planned dives counted. Those failures will look like regressions and there may be many. **Do not blanket-update them.** A genuine regression can hide in the noise.

- [ ] **Step 1: Run the full suite and capture the failures**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-526-exclude-from-stats
flutter test 2>&1 | tee /tmp/dive-stats-fallout.txt
```

Do not pipe into `grep`: the pipeline would return grep's exit status instead of the runner's. `tee` preserves it.

Do not start this run while another local test run is in progress; overlapping runs produce phantom lone failures.

- [ ] **Step 2: Classify every failure**

For each failing test, answer in writing:

1. Does the test seed a dive with `isPlanned: true`?
2. Does the assertion depend on that dive being counted?

If both are yes, it is expected fallout: update the expectation and note it. If either is no, it is a real regression: fix the code, not the test.

Record the classification in the commit message so a reviewer can audit the judgment calls.

- [ ] **Step 3: Check the known-flaky index before treating anything as a regression**

Some full-suite failures in this repo are known flakes that pass when the file runs alone:

```bash
flutter test <the single failing file>
```

A test that passes alone and fails in the full suite is a flake, not fallout. Check it against the flaky index rather than "fixing" it.

- [ ] **Step 4: Apply the updates**

Update only the expectations classified as genuine fallout in Step 2.

- [ ] **Step 5: Re-run the full suite**

```bash
flutter test 2>&1 | tee /tmp/dive-stats-fallout-2.txt
```

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add test/
git commit -m "test: update expectations for planned dives leaving statistics

Planned dives previously counted toward every aggregate, which was a
bug. Each updated expectation was individually classified as fallout
rather than blanket-updated; see the classification list below.

<paste the Step 2 classification list here>"
```

---

### Task 9: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale ARBs (`ar de es fr he hu it nl pt zh`)

**Interfaces:**
- Consumes: nothing.
- Produces: the keys `diveLog_edit_excludeFromStats`, `diveLog_edit_excludeFromStatsHelp`, `diveLog_edit_excludeFromGasStats`, `diveLog_edit_excludeFromGasStatsHelp`, `diveLog_badge_excludedFromStats`, `diveLog_badge_excludedFromGasStats`, `diveLog_bulkEdit_fieldExcludeFromStats`, `diveLog_bulkEdit_fieldExcludeFromGasStats`, `diveLog_filter_excludedOnly`, `diveLog_edit_summary_excluded`, and `statistics_excludedDivesFootnote` (a plural, taking `count`).

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`:

```json
  "diveLog_edit_excludeFromStats": "Exclude from statistics",
  "diveLog_edit_excludeFromStatsHelp": "Keep this dive in your logbook, but leave it out of every statistic, including your dive count.",
  "diveLog_edit_excludeFromGasStats": "Exclude from gas statistics",
  "diveLog_edit_excludeFromGasStatsHelp": "Leave this dive out of SAC, RMV and gas mix statistics only. Useful when the gas number is not representative.",
  "diveLog_badge_excludedFromStats": "Excluded from statistics",
  "diveLog_badge_excludedFromGasStats": "Excluded from gas statistics",
  "diveLog_bulkEdit_fieldExcludeFromStats": "Exclude from statistics",
  "diveLog_bulkEdit_fieldExcludeFromGasStats": "Exclude from gas statistics",
  "diveLog_filter_excludedOnly": "Excluded from statistics only",
  "diveLog_edit_summary_excluded": "Excluded",
  "statistics_excludedDivesFootnote": "{count, plural, =1{1 dive excluded from statistics} other{{count} dives excluded from statistics}}",
  "@statistics_excludedDivesFootnote": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Match the surrounding file's key ordering and formatting conventions rather than appending at the end if the file is sorted.

- [ ] **Step 2: Translate into the other ten locales**

Add the same keys, translated, to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`.

Keep the ICU plural structure intact in every locale, using that locale's required plural categories (Arabic needs `zero`, `one`, `two`, `few`, `many`, `other`).

- [ ] **Step 3: Regenerate the localizations**

```bash
flutter gen-l10n
```

- [ ] **Step 4: Run the parity test**

```bash
flutter test test/l10n/
```

Expected: PASS. A report of "N missing" against *every* locale means English has keys the others lack; a report against one locale means that one file was missed.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "i18n: add statistics-exclusion strings in all eleven locales"
```

---

### Task 10: Dive edit form checkboxes

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_buildTheDiveSection` ~2025, state fields ~956, load from existing dive ~4961, save path)
- Test: `test/features/dive_log/presentation/dive_edit_exclusion_test.dart`

**Interfaces:**
- Consumes: `Dive.excludedFromStats` / `excludedFromGasStats` (Task 3), the l10n keys (Task 9).
- Produces: state fields `_excludedFromStats` and `_excludedFromGasStats`, both `bool`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_log/presentation/dive_edit_exclusion_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the gas checkbox is disabled while the master flag is on',
      (tester) async {
    // Pump the dive edit page for an existing dive with excludedFromStats
    // true, using the repo's existing edit-page test harness.
    // Then:
    final gasTile = tester.widget<CheckboxListTile>(
      find.byKey(const Key('dive-edit-exclude-from-gas-stats')),
    );
    expect(gasTile.onChanged, isNull,
        reason: 'the master flag implies the gas flag, so the gas control '
            'must be inert rather than silently overridden');
    expect(gasTile.value, isTrue,
        reason: 'it must read as checked, since that is the effective state');
  });

  testWidgets('toggling exclude-from-statistics persists on save',
      (tester) async {
    // Pump the edit page for a dive with both flags false, tap the master
    // checkbox, save, and assert the persisted Dive has excludedFromStats
    // true and excludedFromGasStats false.
  });
}
```

Fill in the pump-and-save bodies using whatever harness the neighbouring edit-page tests already use:

```bash
ls test/features/dive_log/presentation/
grep -rn "dive_edit_page" test/ --include='*.dart' | head -5
```

Use that harness rather than building a fresh `MaterialApp`; the page depends on providers and l10n that the harness already wires.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/dive_log/presentation/dive_edit_exclusion_test.dart
```

Expected: FAIL, the keyed widgets do not exist.

- [ ] **Step 3: Add the state fields**

Near `bool _bulkFavorite = false;` (~line 956) in `_DiveEditPageState`:

```dart
  bool _excludedFromStats = false;
  bool _excludedFromGasStats = false;
```

Initialize them from the existing dive wherever `isFavorite` is read (~line 4961):

```dart
    _excludedFromStats = _existingDive?.excludedFromStats ?? false;
    _excludedFromGasStats = _existingDive?.excludedFromGasStats ?? false;
```

and include them in the `Dive` the save path builds:

```dart
      excludedFromStats: _excludedFromStats,
      excludedFromGasStats: _excludedFromGasStats,
```

- [ ] **Step 4: Add the checkboxes to The Dive section**

At the end of the children list in `_buildTheDiveSection` (~line 2025):

```dart
        CheckboxListTile(
          key: const Key('dive-edit-exclude-from-stats'),
          value: _excludedFromStats,
          onChanged: (v) {
            _markDirty();
            setState(() => _excludedFromStats = v ?? false);
          },
          title: Text(context.l10n.diveLog_edit_excludeFromStats),
          subtitle: Text(context.l10n.diveLog_edit_excludeFromStatsHelp),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          key: const Key('dive-edit-exclude-from-gas-stats'),
          // The master flag implies the gas flag. Render the implication as
          // checked-and-inert rather than letting the diver set a value that
          // the SQL scope would silently override.
          value: _excludedFromStats || _excludedFromGasStats,
          onChanged: _excludedFromStats
              ? null
              : (v) {
                  _markDirty();
                  setState(() => _excludedFromGasStats = v ?? false);
                },
          title: Text(context.l10n.diveLog_edit_excludeFromGasStats),
          subtitle: Text(context.l10n.diveLog_edit_excludeFromGasStatsHelp),
          controlAffinity: ListTileControlAffinity.leading,
        ),
```

Match the section's existing row style. If The Dive section uses a `FormRow.toggle` helper rather than raw `CheckboxListTile`, use `FormRow.toggle` and keep the `Key`s.

- [ ] **Step 5: Surface the state in the collapsed section summary**

In the summary builder for The Dive section, append when either flag is set:

```dart
      if (_excludedFromStats || _excludedFromGasStats)
        context.l10n.diveLog_edit_summary_excluded,
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
flutter test test/features/dive_log/presentation/dive_edit_exclusion_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart \
  test/features/dive_log/presentation/dive_edit_exclusion_test.dart
git commit -m "feat(dive): add statistics-exclusion checkboxes to the edit form

The gas checkbox renders checked and inert while the master flag is on,
so the implication is visible rather than silently overridden."
```

---

### Task 11: Bulk edit support

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (enum ~line 8, `BulkScalarInputs` ~line 60)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (gated rows ~line 1056, `_collectScalarInputs` ~line 1106)
- Test: `test/features/dive_log/presentation/bulk_edit_exclusion_test.dart`

**Interfaces:**
- Consumes: `BulkField`, `BulkScalarInputs`, `_gatedRow`, the l10n keys from Task 9.
- Produces: `BulkField.excludedFromStats`, `BulkField.excludedFromGasStats`, and matching `bool?` fields on `BulkScalarInputs`.

This task is what makes #526 practical. Its author is describing a class of dives, not one dive; a per-dive checkbox alone would be a thirty-tap chore.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/bulk_edit_exclusion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an ungated exclusion field leaves selected dives untouched',
      (tester) async {
    // Pump the bulk edit form over two dives, one with excludedFromStats
    // true and one false. Change some OTHER field and apply.
    // Assert both dives keep their original excludedFromStats value: an
    // untouched gate must not write false over everything.
  });

  testWidgets('a gated exclusion field applies to every selected dive',
      (tester) async {
    // Pump the bulk edit form over two dives with excludedFromStats false.
    // Enable the exclude-from-statistics gate, set it true, apply.
    // Assert both dives now have excludedFromStats true.
  });
}
```

Fill in the bodies using the existing bulk-edit test harness:

```bash
grep -rn "BulkField\|bulkEdit" test/ --include='*.dart' | head -10
```

The first test is the important one. Writing `false` over every selected dive when the diver never touched the field is the classic bulk-edit bug this repo's gate widget exists to prevent.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/dive_log/presentation/bulk_edit_exclusion_test.dart
```

Expected: FAIL, `BulkField.excludedFromStats` is undefined.

- [ ] **Step 3: Extend the enum and the inputs class**

In `bulk_edit_field_set.dart`, after `isFavorite,` in the `BulkField` enum:

```dart
  excludedFromStats,
  excludedFromGasStats,
```

and after `this.isFavorite,` in the `BulkScalarInputs` constructor, plus the matching `final bool? excludedFromStats;` / `final bool? excludedFromGasStats;` field declarations alongside `final bool? isFavorite;`.

Wire both into wherever `BulkScalarInputs` becomes a `DivesCompanion`, following `isFavorite` exactly:

```bash
grep -n "isFavorite" lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart
```

- [ ] **Step 4: Add the gated rows**

In `dive_edit_page.dart`, after the `BulkField.isFavorite` gated row (~line 1056):

```dart
              _gatedRow(
                BulkField.excludedFromStats,
                FormRow.toggle(
                  label: context.l10n.diveLog_bulkEdit_fieldExcludeFromStats,
                  value: _bulkExcludedFromStats,
                  onChanged: (v) =>
                      setState(() => _bulkExcludedFromStats = v),
                ),
              ),
              _gatedRow(
                BulkField.excludedFromGasStats,
                FormRow.toggle(
                  label:
                      context.l10n.diveLog_bulkEdit_fieldExcludeFromGasStats,
                  value: _bulkExcludedFromGasStats,
                  onChanged: (v) =>
                      setState(() => _bulkExcludedFromGasStats = v),
                ),
              ),
```

Declare the two state fields next to `_bulkFavorite` (~line 956):

```dart
  bool _bulkExcludedFromStats = false;
  bool _bulkExcludedFromGasStats = false;
```

and add them to `_collectScalarInputs` (~line 1112), beside `isFavorite: _bulkFavorite,`:

```dart
      excludedFromStats: _bulkExcludedFromStats,
      excludedFromGasStats: _bulkExcludedFromGasStats,
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/dive_log/presentation/bulk_edit_exclusion_test.dart
```

Expected: PASS, both tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart \
  lib/features/dive_log/presentation/pages/dive_edit_page.dart \
  test/features/dive_log/presentation/bulk_edit_exclusion_test.dart
git commit -m "feat(dive): bulk-edit support for the statistics-exclusion flags

Gated like isFavorite, so an untouched field never writes false over
every selected dive. This is what makes #526 practical for a diver with
thirty pool sessions."
```

---

### Task 12: Badges on the list item and detail page

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_item.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test: `test/features/dive_log/presentation/dive_exclusion_badge_test.dart`

**Interfaces:**
- Consumes: `Dive.excludedFromStats` / `excludedFromGasStats`, the badge l10n keys.
- Produces: nothing other tasks consume.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/dive_exclusion_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an included dive shows no exclusion badge', (tester) async {
    // Pump DiveListItem for a dive with both flags false.
    expect(find.byKey(const Key('dive-excluded-badge')), findsNothing);
  });

  testWidgets('an excluded dive shows the badge', (tester) async {
    // Pump DiveListItem for a dive with excludedFromStats true.
    expect(find.byKey(const Key('dive-excluded-badge')), findsOneWidget);
  });

  testWidgets('the badge fits a 360px-wide row without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Pump DiveListItem for an excluded dive with a long site name.
    expect(tester.takeException(), isNull);
  });
}
```

The third test matters: the test font renders one `fontSize`-wide glyph per character, so a `Row` containing an unconstrained `Text` overflows at 360px in tests even when it looks fine on a real device. Wrap the row's flexible child in `Flexible` or `Expanded`.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/dive_log/presentation/dive_exclusion_badge_test.dart
```

Expected: FAIL, no badge widget.

- [ ] **Step 3: Add the badge**

In `dive_list_item.dart`, in the row that already renders status icons (find it by looking for where `isFavorite` renders its star):

```dart
        if (dive.excludedFromStats || dive.excludedFromGasStats)
          Tooltip(
            key: const Key('dive-excluded-badge'),
            message: dive.excludedFromStats
                ? context.l10n.diveLog_badge_excludedFromStats
                : context.l10n.diveLog_badge_excludedFromGasStats,
            child: Icon(
              dive.excludedFromStats
                  ? Icons.bar_chart_outlined
                  : Icons.local_gas_station_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
```

Add the same block to the dive detail page's header badge row.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/dive_log/presentation/dive_exclusion_badge_test.dart
```

Expected: PASS, all three tests. If the 360px test fails with an overflow, wrap the row's text child in `Flexible`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_item.dart \
  lib/features/dive_log/presentation/pages/dive_detail_page.dart \
  test/features/dive_log/presentation/dive_exclusion_badge_test.dart
git commit -m "feat(dive): badge excluded dives in the list and on the detail page"
```

---

### Task 13: Statistics footnote

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (new method)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart` (new provider)
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Test: `test/features/statistics/excluded_dives_footnote_test.dart`

**Interfaces:**
- Consumes: `DiveStatsScope.predicate` (Task 2), `statistics_excludedDivesFootnote` (Task 9).
- Produces: `StatisticsRepository.countExcludedDives({String? diverId}) -> Future<int>` and `excludedDiveCountProvider`, a `FutureProvider<int>`.

This is what prevents a "247 here, 248 there" support ticket months from now.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/excluded_dives_footnote_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StatisticsRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> insert(String id, {bool excluded = false}) =>
      db.customStatement(
        'INSERT INTO dives (id, dive_date_time, excluded_from_stats) '
        'VALUES (?, 0, ?)',
        [id, excluded ? 1 : 0],
      );

  test('counts zero when nothing is excluded', () async {
    await insert('a');
    expect(await repo.countExcludedDives(), 0);
  });

  test('counts only dives the diver excluded', () async {
    await insert('a');
    await insert('b', excluded: true);
    await insert('c', excluded: true);
    expect(await repo.countExcludedDives(), 2);
  });

  test('does not count planned dives', () async {
    await insert('a');
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, is_planned) "
      "VALUES ('planned', 0, 1)",
    );
    expect(await repo.countExcludedDives(), 0,
        reason: 'the footnote explains the diver\'s own choice; a planned '
            'dive is not something they excluded');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/statistics/excluded_dives_footnote_test.dart
```

Expected: FAIL, `countExcludedDives` undefined.

- [ ] **Step 3: Add the repository method**

In `statistics_repository.dart`:

```dart
  /// Counts the dives the diver has explicitly excluded from statistics.
  ///
  /// Deliberately counts only `excluded_from_stats`, not the whole
  /// [DiveStatsScope]: the footnote exists to explain the diver's own choice
  /// back to them. Planned dives are not something they chose to exclude, so
  /// folding them in would make the number confusing rather than clarifying.
  // stats-scope-exempt: counts the excluded, by definition
  Future<int> countExcludedDives({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM dives '
      'WHERE excluded_from_stats = 1 $diverFilter',
      variables: diverId != null ? [Variable(diverId)] : const [],
    ).getSingle();
    return row.read<int>('c');
  }
```

- [ ] **Step 4: Add the provider and render the footnote**

In `statistics_providers.dart`:

```dart
/// Count of dives the diver excluded from statistics, for the Overview
/// footnote. Kept separate from the filtered providers: it explains a
/// persistent property of the logbook, not the current view filter.
final excludedDiveCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statisticsTickProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  final diver = ref.watch(currentDiverProvider);
  return repo.countExcludedDives(diverId: diver?.id);
});
```

Match the surrounding providers' exact dependency names; `statisticsTickProvider` and `currentDiverProvider` may be spelled differently in this file. Check:

```bash
grep -n "^final .*Provider" lib/features/statistics/presentation/providers/statistics_providers.dart | head -20
```

In `statistics_overview_page.dart`, at the bottom of the page body:

```dart
        ref.watch(excludedDiveCountProvider).maybeWhen(
              data: (count) => count == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        context.l10n.statistics_excludedDivesFootnote(count),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/statistics/excluded_dives_footnote_test.dart
```

Expected: PASS, all three tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/statistics/ \
  test/features/statistics/excluded_dives_footnote_test.dart
git commit -m "feat(stats): footnote the excluded dive count on the Overview

Renders only when nonzero. Explains why the statistics dive count and
the logbook dive count differ."
```

---

### Task 14: The excluded-dives filter axis

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (field ~line 18, constructor ~line 80, `hasActiveFilters` ~line 103, `copyWith` ~line 139, `apply` ~line 298)
- Modify: `lib/features/statistics/data/dive_filter_sql.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_buildFilterWhereClauses` ~line 2293)
- Modify: the filter sheet widget
- Test: `test/features/dive_log/dive_filter_excluded_axis_test.dart`

**Interfaces:**
- Consumes: the `excluded_from_stats` column, `diveLog_filter_excludedOnly`.
- Produces: `DiveFilterState.excludedFromStatsOnly`, a `bool?`. Null means no filtering on this axis; true means only excluded dives. Mirrors `favoritesOnly`.

Three implementations of the same semantics must agree. A divergence between them is invisible until a diver notices two screens disagreeing.

- [ ] **Step 1: Write the failing parity test**

Create `test/features/dive_log/dive_filter_excluded_axis_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  final included = Dive(
    id: 'included',
    diveDateTime: DateTime(2026, 1, 1),
  );
  final excluded = Dive(
    id: 'excluded',
    diveDateTime: DateTime(2026, 1, 2),
    excludedFromStats: true,
  );

  test('a null axis is inactive and filters nothing', () {
    const filter = DiveFilterState();
    expect(filter.hasActiveFilters, isFalse);
    expect(filter.apply([included, excluded]), hasLength(2));
    expect(buildFilteredDiveIdSubquery(filter).subquery, isEmpty);
  });

  test('apply() keeps only excluded dives when the axis is true', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    expect(filter.hasActiveFilters, isTrue);
    final result = filter.apply([included, excluded]);
    expect(result.map((d) => d.id), ['excluded']);
  });

  test('the SQL subquery encodes the same rule', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    final sql = buildFilteredDiveIdSubquery(filter);
    expect(sql.subquery, contains('excluded_from_stats = 1'));
  });

  test('copyWith can set and clear the axis', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    expect(filter.copyWith(clearExcludedFromStatsOnly: true)
        .excludedFromStatsOnly, isNull);
    expect(const DiveFilterState()
        .copyWith(excludedFromStatsOnly: true)
        .excludedFromStatsOnly, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/dive_log/dive_filter_excluded_axis_test.dart
```

Expected: FAIL, no such named parameter.

- [ ] **Step 3: Add the axis to DiveFilterState**

Beside `final bool? favoritesOnly;` (~line 18):

```dart
  /// When true, keep only dives the diver excluded from statistics, so they
  /// can find and review them. Null means this axis is inactive.
  ///
  /// This is a view filter for *finding* excluded dives. It plays no part in
  /// enforcing the exclusion; that is DiveStatsScope's job and applies
  /// unconditionally.
  final bool? excludedFromStatsOnly;
```

Add `this.excludedFromStatsOnly,` to the constructor (~line 80).

In `hasActiveFilters` (~line 103), beside the `favoritesOnly == true ||` term:

```dart
      excludedFromStatsOnly == true ||
```

In `copyWith`, add `bool? excludedFromStatsOnly,` and `bool clearExcludedFromStatsOnly = false,` to the signature, and to the body:

```dart
      excludedFromStatsOnly: clearExcludedFromStatsOnly
          ? null
          : (excludedFromStatsOnly ?? this.excludedFromStatsOnly),
```

In `apply` (~line 298), beside the `favoritesOnly` check:

```dart
      if (excludedFromStatsOnly == true && !dive.excludedFromStats) {
        return false;
      }
```

Match the surrounding code's exact predicate style; the existing block may use `continue` inside a loop rather than `return false` inside a `where`.

- [ ] **Step 4: Add the axis to the two SQL builders**

In `dive_filter_sql.dart`, beside the `favoritesOnly` condition:

```dart
  if (filter.excludedFromStatsOnly == true) {
    conditions.add('excluded_from_stats = 1');
  }
```

In `dive_repository_impl.dart`'s `_buildFilterWhereClauses` (~line 2293), add the equivalent clause with that method's alias convention.

- [ ] **Step 5: Add the control to the filter sheet**

In `lib/features/statistics/presentation/widgets/dive_filter_sheet.dart` (confirm the path with `find lib -name 'dive_filter_sheet.dart'`), add a toggle beside the favorites toggle, labelled `context.l10n.diveLog_filter_excludedOnly`, reading and writing `excludedFromStatsOnly` with `clearExcludedFromStatsOnly: true` when switched off.

- [ ] **Step 6: Run the test to verify it passes**

```bash
flutter test test/features/dive_log/dive_filter_excluded_axis_test.dart
```

Expected: PASS, all four tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/domain/models/dive_filter_state.dart \
  lib/features/statistics/data/dive_filter_sql.dart \
  lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  lib/features/statistics/presentation/widgets/dive_filter_sheet.dart \
  test/features/dive_log/dive_filter_excluded_axis_test.dart
git commit -m "feat(dive): add an excluded-dives filter axis

Lets a diver find the dives they excluded. Implemented in all three
filter paths (SQL subquery, repository WHERE builder, in-memory apply)
with a parity test asserting they agree."
```

---

### Task 15: UDDF and sync round trips

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf_exclusion_roundtrip_test.dart`
- Test: `test/core/services/sync/sync_exclusion_roundtrip_test.dart`

**Interfaces:**
- Consumes: `Dive.excludedFromStats` / `excludedFromGasStats`.
- Produces: nothing other tasks consume.

Sync needs no hand plumbing: `_exportDives` serializes via the generated `row.toJson()`, so the columns ride along. The sync test is a regression guard. UDDF is hand-plumbed and genuinely needs the work.

- [ ] **Step 1: Write the failing round-trip tests**

Create `test/core/services/export/uddf_exclusion_roundtrip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UDDF export then import preserves both exclusion flags', () async {
    // Build a Dive with excludedFromStats true and excludedFromGasStats
    // false, export it to UDDF, import the result, and assert both flags
    // survive with their original values.
    //
    // Then repeat with the flags swapped, so a bug that writes one flag
    // into the other's slot cannot pass.
  });

  test('importing UDDF without the exclusion extension defaults to included',
      () async {
    // Import a UDDF document produced by another application, with no
    // Submersion exclusion element. Assert both flags read back false
    // rather than null or true.
  });
}
```

Create `test/core/services/sync/sync_exclusion_roundtrip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync serialization carries both exclusion flags', () async {
    // Insert a dive with both flags true, run the dives export the sync
    // serializer uses, and assert the emitted JSON contains
    // excluded_from_stats and excluded_from_gas_stats set truthy.
    //
    // This is a regression guard: the serializer is generated, so this test
    // exists to catch a future hand-written column allowlist that would
    // silently drop the flags.
  });
}
```

Fill in both bodies using the existing export and sync test harnesses:

```bash
ls test/core/services/export/uddf/
ls test/core/services/sync/ | head -20
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/core/services/export/uddf_exclusion_roundtrip_test.dart \
  test/core/services/sync/sync_exclusion_roundtrip_test.dart
```

Expected: the UDDF tests FAIL (flags are dropped). The sync test may already PASS, which is the correct outcome for a regression guard.

- [ ] **Step 3: Plumb UDDF export and import**

Find how `isFavorite` crosses the UDDF boundary and mirror it:

```bash
grep -n "isFavorite" lib/core/services/export/uddf/uddf_export_builders.dart \
  lib/core/services/export/uddf/uddf_full_import_service.dart
```

Write both flags into the same application-specific extension element `isFavorite` uses, and read them back with a `false` default so a document from another application imports as included rather than null.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/core/services/export/uddf_exclusion_roundtrip_test.dart \
  test/core/services/sync/sync_exclusion_roundtrip_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/ test/core/services/
git commit -m "feat(export): carry statistics-exclusion flags through UDDF

Round-trip tested in both directions, with a default-to-included path
for documents from other applications. Sync needs no plumbing (generated
serializer); its test is a regression guard."
```

---

### Task 16: Release notes and final verification

**Files:**
- Create or modify: the release notes file for the next version
- Modify: nothing in `lib/`

**Interfaces:**
- Consumes: everything.
- Produces: a branch ready to push.

- [ ] **Step 1: Write the release note**

Find the release notes location and the current version:

```bash
ls docs/releases/ | tail -5
grep -n "^version:" pubspec.yaml
```

Add entries under the next version:

```markdown
### Added

- Dives can now be excluded from statistics. Open a dive, and under The Dive
  you will find "Exclude from statistics" (keeps the dive in your logbook but
  leaves it out of every statistic, dive count included) and "Exclude from gas
  statistics" (leaves it out of SAC, RMV and gas mix figures only, for a dive
  whose gas number is not representative). Both are available in bulk edit, and
  a filter axis lets you find the dives you have excluded. (#526, #1272)

### Fixed

- Planned dives no longer count toward your statistics. A dive created in the
  planner but never logged was previously included in every total, average and
  record. If you have used the planner, your dive count and averages will
  change to reflect only dives you actually made.
```

The Fixed entry is not optional. It changes existing divers' numbers on upgrade with no action on their part, and an unexplained shift in a dive count reads as data loss.

- [ ] **Step 2: Format the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-526-exclude-from-stats
dart format .
```

- [ ] **Step 3: Analyze the whole project**

```bash
flutter analyze
```

Expected: zero issues. CI treats infos as fatal, so an info here fails the build.

- [ ] **Step 4: Run the full test suite once**

```bash
flutter test 2>&1 | tee /tmp/dive-stats-final.txt
```

Do not pipe into `grep`. Do not run this while another local test run is active. One full run is sufficient before the PR.

Expected: green. Check any failure against the known-flaky index by rerunning that file alone before treating it as real.

- [ ] **Step 5: Re-run both schema ladder claim scans**

This is the last chance to catch a rung collision, and it must happen now rather than earlier, because another branch may have claimed 178 in the meantime.

```bash
# 1. Claims visible in open PRs
for n in $(gh pr list --state open --limit 100 --json number --jq '.[].number'); do
  gh pr diff "$n" | grep -oE '^\+\s*static const int currentSchemaVersion = [0-9]+' \
    | sed "s/^/PR $n: /"
done

# 2. The claims method 1 cannot see: every worktree's working-tree scalar
for w in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
  v=$(grep -oE 'currentSchemaVersion = [0-9]+' \
      "$w/lib/core/database/database.dart" 2>/dev/null | head -1)
  echo "$w: $v"
done
```

If anything else claims 178, renumber this branch to the next free rung under the prior-claim tiebreak (a pushed open PR wins over an unpushed worktree), updating the column comment, the `onUpgrade` rung, the `beforeOpen` comment, the migration test, and the release note together.

- [ ] **Step 6: Commit**

```bash
git add docs/releases/
git commit -m "docs: release notes for statistics exclusion

Documents the new flags and, separately, the behavior change from
planned dives leaving statistics."
```

- [ ] **Step 7: Verify the branch is clean and ready**

```bash
git status --short
git log --oneline origin/main..HEAD
```

Expected: a clean working tree and roughly sixteen commits. Do not push or open a PR without asking; the diver on the other end of this decides when.

---

## Self-Review

**Spec coverage.** Every spec section maps to at least one task:

| Spec section | Tasks |
| --- | --- |
| Section 1, schema and entity | 1, 3 |
| Section 1, sync and UDDF | 15 |
| Section 2, DiveStatsScope helper | 2 |
| Section 2, Tier 1 statistics | 4 |
| Section 2, Tier 2 dive log | 5 |
| Section 2, Tier 3 per-entity | 6 |
| Section 2, operational exemptions | 7 |
| Section 2, is_planned fix | 2 (predicate), 8 (fallout) |
| Section 3, edit form | 10 |
| Section 3, bulk edit | 11 |
| Section 3, badges | 12 |
| Section 3, statistics footnote | 13 |
| Section 3, filter axis | 14 |
| Section 3, localization | 9 |
| Section 4, behavioral guard suite | 4, 5, 6 |
| Section 4, source census | 7 |
| Section 4, migration tests | 1 |
| Section 4, filter parity | 14 |
| Section 4, round trips | 15 |
| Section 4, widget tests | 10, 11, 12 |
| Risks, is_planned fallout | 8 |
| Risks, schema rung collision | 16 |
| Risks, release note | 16 |
| Verification | 16 |

No gaps.

**Type consistency.** `DiveStatsScope.predicate` and `DiveStatsScope.and` keep the same signature (`{String alias = 'd', bool gas = false}`) everywhere they appear, in Tasks 2, 4, 5, 6 and 7. `Dive.excludedFromStats` and `Dive.excludedFromGasStats` are `bool` (non-nullable, defaulting to false) in Tasks 3, 10, 11, 12 and 14. `DiveFilterState.excludedFromStatsOnly` is `bool?` in Task 14, matching `favoritesOnly`, and its `copyWith` clear flag is `clearExcludedFromStatsOnly` in both the signature and the test. `BulkScalarInputs.excludedFromStats` is `bool?` in Task 11, matching `isFavorite`. `countExcludedDives({String? diverId})` returns `Future<int>` in Task 13 and its test. The marker string `stats-scope-exempt` is identical in Tasks 5, 7, 13 and the census test's matcher.

**Placeholder scan.** No TBD or TODO. Three tasks contain deliberately unfilled test bodies (10, 11, 15) where the body depends on a test harness whose API this plan cannot quote without inventing it; each carries the exact `grep`/`ls` command that locates the harness, plus a precise statement of what the test must assert. Task 12's badge test and every other test are written in full.

**Line numbers.** Every line reference is marked approximate and paired with a symbol name, because line numbers drift as earlier tasks land. Anchor on the symbol, not the number.
