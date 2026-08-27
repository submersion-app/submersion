# Dedupe same-computer dive_data_sources rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop a dive that was created by merging two same-computer segments (e.g. a "split pair" combine) from showing a duplicate, empty-profile source chip alongside the real one with stale stats.

**Architecture:** Add one small private helper to `DiveRepository` that collapses `dive_data_sources` rows sharing a `computerId` down to the canonical one (primary-preferred), and call it from the two read paths that currently assume one row per computer without enforcing it: `getDataSources()` (feeds the "Sources" chip row) and `getProfilesByDataSource()` (feeds the profile chart). Display-only — no schema change, no data migration, no change to how merges write data.

**Tech Stack:** Dart, Drift (SQLite ORM), `flutter_test` with an in-memory `AppDatabase`.

Spec: `docs/superpowers/specs/2026-08-11-dedupe-same-computer-dive-data-sources-design.md`

---

### Task 1: Add `_canonicalDataSourceRows` and fix `getProfilesByDataSource`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:706-717` (the `sourceRows` query inside `getProfilesByDataSource`)
- Test: `test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test inside the existing `void main() { ... }` block in
`test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`,
after the `'metadata-only sources keep an entry with no points'` test (around
line 223). It reuses the `dive-1` / `src-a` (primary, computer `dc-a`) /
`src-b` (non-primary, computer `dc-b`) fixtures already created in `setUp`.

```dart
  test(
    'two sources sharing a computerId collapse onto the canonical (primary) '
    'one',
    () async {
      // Mirrors what a same-computer sequential merge produces
      // (dive_merge_service.dart step 10 carries over every original dive's
      // data source row as provenance; two originals logged by the same
      // physical computer both had their own row).
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-a-dup'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 3)),
              createdAt: Value(DateTime(2026, 1, 3)),
            ),
          );
      await insertProfileRow(
        diveId: 'dive-1',
        timestamp: 0,
        depth: 10.0,
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertProfileRow(
        diveId: 'dive-1',
        timestamp: 5,
        depth: 11.0,
        computerId: 'dc-a',
        isPrimary: true,
      );

      final result = await repository.getProfilesByDataSource('dive-1');

      expect(result.keys, containsAll(['src-a', 'src-b']));
      expect(result.containsKey('src-a-dup'), false);
      expect(
        result['src-a']!.points.map((p) => p.depth).toList(),
        [10.0, 11.0],
      );
    },
  );
```

Both new profile rows use `isPrimary: true` deliberately: `computerId: 'dc-a'`
matches the primary source's computer, so they're "primary family" rows
(`isPrimaryFamily` in the function under test). If one were `isPrimary:
false` here, it would trip the *unrelated* edited-profile heuristic
(`hasEditedProfile`) and get silently excluded from the result -- this test
is only about the same-computer collision, not the edit-detection path
already covered by the `'edited profile replaces primary rows...'` test
above it.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/profiles_by_data_source_test.dart --plain-name "two sources sharing a computerId"`

Expected: FAIL. With today's code, `sourceIdByComputer` is built by
iterating `sourceRows` in `desc(isPrimary), asc(createdAt)` order and
assigning `computerId -> id` for each -- the map literal's later write for
`'dc-a'` (from `src-a-dup`, which sorts after `src-a` since both are
non-primary... actually `src-a` IS primary so it sorts first, but the
literal still processes `src-a-dup` afterward and overwrites the map entry)
wins, so every `dc-a` profile point currently attributes to `src-a-dup`
instead of `src-a`. Expect the assertion on `result['src-a']!.points` to
fail (empty list, not `[10.0, 11.0]`), or `result.containsKey('src-a-dup')`
to be `true` instead of `false`.

- [ ] **Step 3: Add the helper and wire it into `getProfilesByDataSource`**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, add
this private method immediately before `getProfilesByDataSource` (i.e.
directly above the doc comment starting at line 700):

```dart
  /// Collapses [rows] so at most one dive_data_sources row survives per
  /// non-null computerId, keeping the first row encountered -- since every
  /// caller queries in `desc(isPrimary), asc(createdAt)` order, that's the
  /// primary if one exists, else the earliest-created. Rows with a null
  /// computerId (manual entries, edited profiles) are never deduped; there
  /// is nothing to collide on.
  ///
  /// A same-computer sequential merge (DiveMergeService.apply, step 10)
  /// carries over every original dive's data source row as provenance; when
  /// both originals were logged by the same physical computer, that
  /// produces two rows sharing one computerId on the merged dive. Without
  /// this, getProfilesByDataSource's computerId -> sourceId lookup collides
  /// and silently misroutes every profile point to whichever row is
  /// iterated last, and getDataSources shows a second, empty, selectable
  /// chip for the row that lost the collision.
  List<DiveDataSourcesData> _canonicalDataSourceRows(
    List<DiveDataSourcesData> rows,
  ) {
    final seenComputers = <String>{};
    final result = <DiveDataSourcesData>[];
    for (final row in rows) {
      final computerId = row.computerId;
      if (computerId == null) {
        result.add(row);
        continue;
      }
      if (!seenComputers.add(computerId)) continue;
      result.add(row);
    }
    return result;
  }
```

Then change the `sourceRows` query inside `getProfilesByDataSource`
(currently lines 710-717) from:

```dart
      final sourceRows =
          await (_db.select(_db.diveDataSources)
                ..where((t) => t.diveId.equals(diveId))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.isPrimary),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();
```

to:

```dart
      final sourceRows = _canonicalDataSourceRows(
        await (_db.select(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.isPrimary),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get(),
      );
```

Nothing else in the function changes -- `primary`, `sourceIdByComputer`,
the point-attribution loop, and the returned map all now operate on the
deduped list automatically.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`

Expected: PASS, all tests in the file (the new one plus the 6 pre-existing
ones) green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/profiles_by_data_source_test.dart
git commit -m "fix(dive_log): dedupe same-computer sources in getProfilesByDataSource"
```

---

### Task 2: Wire the same helper into `getDataSources`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:5432-5453`
- Create: `test/features/dive_log/data/repositories/canonical_data_sources_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/canonical_data_sources_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    final now = DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    for (final (id, name) in [
      ('dc-a', 'Kiyans Teric'),
      ('dc-b', 'Erics Teric'),
    ]) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value(name),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'getDataSources returns one row per computer, even when more than one '
    'dive_data_sources row shares a computerId',
    () async {
      // Mirrors what a same-computer sequential merge produces
      // (dive_merge_service.dart step 10 carries over every original dive's
      // data source row as provenance; two originals logged by the same
      // physical computer both had their own row).
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-primary'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-dup'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 2)),
              createdAt: Value(DateTime(2026, 1, 2)),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-b'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-b'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 3)),
              createdAt: Value(DateTime(2026, 1, 3)),
            ),
          );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-primary', 'src-b']);
    },
  );

  test(
    'getDataSources keeps every source when no two share a computerId',
    () async {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-a'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-b'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-b'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 2)),
              createdAt: Value(DateTime(2026, 1, 2)),
            ),
          );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-a', 'src-b']);
    },
  );
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/canonical_data_sources_test.dart`

Expected: the first test FAILs -- `sources.map((s) => s.id).toList()`
returns `['src-primary', 'src-dup', 'src-b']` (all three rows, unfiltered)
instead of `['src-primary', 'src-b']`. The second test passes already (no
collision to dedupe), confirming the fixture itself is sound before the fix
changes anything.

- [ ] **Step 3: Wire `_canonicalDataSourceRows` into `getDataSources`**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`,
change `getDataSources` (lines 5432-5453) from:

```dart
  Future<List<DiveDataSource>> getDataSources(String diveId) async {
    try {
      final query = _db.select(_db.diveDataSources)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.isPrimary),
          (t) => OrderingTerm.asc(t.createdAt),
        ]);
      final rows = await query.get();
      final computerNames = await _friendlyNamesFor(rows);
      return rows
          .map((row) => _mapRowToDataSource(row, computerNames))
          .toList();
    } catch (e, stackTrace) {
```

to:

```dart
  Future<List<DiveDataSource>> getDataSources(String diveId) async {
    try {
      final query = _db.select(_db.diveDataSources)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.isPrimary),
          (t) => OrderingTerm.asc(t.createdAt),
        ]);
      final rows = _canonicalDataSourceRows(await query.get());
      final computerNames = await _friendlyNamesFor(rows);
      return rows
          .map((row) => _mapRowToDataSource(row, computerNames))
          .toList();
    } catch (e, stackTrace) {
```

(Only the `final rows = ...` line changes; the rest of the function, and
the `catch` block after it, are untouched.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/canonical_data_sources_test.dart`

Expected: PASS, both tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/canonical_data_sources_test.dart
git commit -m "fix(dive_log): dedupe same-computer sources in getDataSources"
```

---

### Task 3: Regression sweep

`getDataSources` is called from many existing tests (consolidation,
multi-computer integration, quality repair) that exercise genuinely
different-computer scenarios -- this task confirms none of them accidentally
relied on seeing duplicate same-computer rows, and that formatting/analysis
stay clean.

**Files:** none modified unless a regression turns up.

- [ ] **Step 1: Format the changed files**

Run: `dart format lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/profiles_by_data_source_test.dart test/features/dive_log/data/repositories/canonical_data_sources_test.dart`

Expected: "Formatted N files (0 changed)" or similar -- no diffs, since the
code above was written in the project's existing style. If it reports
changes, that's fine too; just re-stage before the final commit if this
step runs after Task 2's commit.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/profiles_by_data_source_test.dart test/features/dive_log/data/repositories/canonical_data_sources_test.dart`

Expected: "No issues found!"

- [ ] **Step 3: Run the broader test suites that exercise `getDataSources`**

Run: `flutter test test/features/dive_log/data/repositories/ test/features/dive_log/integration/multi_computer_integration_test.dart test/features/data_quality/repairs/quality_repair_executor_test.dart`

Expected: PASS, no regressions. This directory/set covers every existing
caller found via `grep -rn "\.getDataSources(" test/` during design
(consolidation tests, the multi-computer integration test, the quality
repair executor test, and the two dedicated files this plan adds) --
all use distinct `computerId`s per source in their fixtures (the normal,
DiveConsolidationService-guarded case), so none should be affected by the
dedup, but this step is the actual verification rather than an assumption.

- [ ] **Step 4: If anything regressed, fix and commit separately**

Only needed if Step 3 surfaces a failure. Diagnose why that specific test's
fixture relied on seeing two same-computer rows (it shouldn't, per the
`DiveConsolidationService` `sameComputer` guard, so this would itself be
worth understanding before patching), fix, then:

```bash
git add -A
git commit -m "fix(dive_log): address regression from same-computer source dedup"
```

If nothing regressed, skip this step -- there is nothing to commit.
