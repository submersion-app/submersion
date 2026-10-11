# Dive Table View UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every entity table scrollbars, a resize handle that tracks the pointer and a "Hide column" header menu, and give the dive table column and cell filter menus plus a surface interval that matches the detail page (issue #2984).

**Architecture:** The dive table's own 560-line `DiveTableView` becomes a thin `ConsumerWidget` over the shared `EntityTableView`, fed by a new `DiveFieldAdapter` (after `DiveField` implements `EntityField`). The shared table gains scrollbars, a stateful resize handle that commits once on drag end, and generic header and cell menu hooks. Dive filters are pure functions over `DiveFilterState` and the query AST (`lib/features/dive_log/query/`), wired to the menus in the dive wrapper. Surface interval gets one SQL definition in `dive_times_sql.dart` used by the table (batch repository read), the `surfaceInterval` query field and Insights.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`, `FutureProvider`), Drift custom SQL on SQLite, the in-house query engine under `lib/core/query/`, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-10-10-dive-table-ux-design.md` (read its "Amendments recorded while planning" section; it is authoritative where the body differs).

## Global Constraints

- Never write the em-dash character (U+2014), and no en-dash as prose punctuation, in code, comments, tests, ARB values, commit messages or docs.
- Nothing written to the repo or GitHub mentions Claude, Claude Code or Anthropic; no co-author trailers.
- TDD: each task writes its failing test first and runs it red before the implementation.
- Every unit shown respects the active diver's unit settings (`UnitFormatter`, `UnitPrefs`).
- New user-facing strings go into `app_en.arb` AND all ten locale ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs LAST, after every ARB has its translation (Task 13).
- A shared widget (`lib/shared/widgets/entity_table/`) must not call `context.l10n` during `build`: menu labels are resolved when a menu opens, so the seven list tests that pump tables under bare `MaterialApp`s keep passing.
- Tests that change process-wide state restore it (`TargetPlatformVariant` instead of assigning `debugDefaultTargetPlatformOverride`).
- Paths built with `p.join`, never string concatenation (none expected here).
- Files stay under 800 lines; do not grow `dive_list_content.dart` (already 2330 lines).
- Before committing each task: `dart format` on the touched files and `flutter analyze` clean.
- Run `test/architecture/` and `test/shared/` after any task that adds a file under `lib/`.

## Review Focus

1. An imperial diver uses a number cell filter: the rule must be built in the diver's units and still contain the clicked dive ("Only 76.8 ft" keeps the 23.4167 m dive). Pinned in Task 11 (`imperial depth` test).
2. A cell whose display is not the value the query reads (runtime derived from the profile, entry method inherited from the site, legacy free-text buddy, legacy visibility bucket) must offer no value items rather than a rule that excludes the clicked dive. Pinned in Task 11 (`derived display offers no items` tests).
3. A large log: the surface interval SQL runs per row (batch read, query filter, Insights) and must seek an index, not scan `dives` per row. Pinned in Task 1 (query plan test).
4. A column filter added while the query is already a single node, an AND, or an OR group, or while "All dives" suspends the axes: the rule is ANDed at top level, never nested into the OR, never duplicated. Pinned in Task 11 (`addDiveTableRule` tests).
5. Hiding the sorted column, the last column, or a pinned column: sort clears, the last column cannot go, pinned columns can be hidden. Pinned in Task 8 (notifier tests).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/data/repositories/dive_times_sql.dart` (modify) | `diveSurfaceIntervalSecondsSql`, the one SI definition |
| `lib/core/database/performance_indexes.dart` (modify) | `idx_dives_entry_date` for the previous-dive seeks |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (modify) | `getSurfaceIntervals()` batch read |
| `lib/features/dive_log/presentation/providers/dive_providers.dart` (modify) | `diveSurfaceIntervalsProvider`; delete unused `surfaceIntervalsProvider` |
| `lib/features/dive_log/query/dive_query_entity.dart` (modify) | `surfaceInterval` field reads the shared SQL |
| `lib/features/insights/data/repositories/insights_repository.dart` (modify) | SI stats read the shared SQL |
| `lib/core/constants/dive_field.dart` (modify) | `implements EntityField`, forwarding getters, `isRightAligned` |
| `lib/core/constants/dive_field_labels.dart` (create) | localized label switches moved out of `dive_field.dart` |
| `lib/features/dive_log/presentation/table/dive_field_adapter.dart` (create) | `DiveFieldAdapter`, `TableViewConfig.toEntityConfig()` |
| `lib/shared/widgets/entity_table/entity_table_resize_handle.dart` (create) | pointer-tracking resize handle |
| `lib/shared/widgets/entity_table/entity_table_menu.dart` (create) | `EntityTableMenuAction`, builders typedefs, `showEntityTableMenu` |
| `lib/shared/widgets/entity_table/entity_table_header_cell.dart` (modify) | resize handle, menu gestures, filter indicator |
| `lib/shared/widgets/entity_table/entity_table_view.dart` (modify) | live widths, scrollbars, menu hooks |
| `lib/shared/providers/entity_table_config_providers.dart` (modify) | `hideColumn` |
| `lib/features/dive_log/presentation/providers/view_config_providers.dart` (modify) | `hideColumn` |
| seven `*_list_content.dart` (modify) | pass `onHideColumn` |
| `lib/features/dive_log/presentation/widgets/dive_table_view.dart` (rewrite) | thin wrapper over `EntityTableView` |
| `lib/features/dive_log/presentation/widgets/table_header_cell.dart` (delete) | replaced by the shared header cell |
| `lib/features/dive_log/query/dive_column_filters.dart` (create) | column to registry path map, unfilterable set |
| `lib/features/dive_log/query/dive_cell_filter_options.dart` (create) | cell menu rules from a dive and a column |
| `lib/features/dive_log/query/dive_column_filter_edits.dart` (create) | add rule, reset column, is filtered |
| `lib/features/dive_log/domain/services/dive_participant_names.dart` (modify) | `nonGuideBuddies` |
| `lib/features/dive_log/presentation/table/dive_table_menus.dart` (create) | menu items with l10n, Add filter flow |
| `lib/core/query/presentation/query_editor.dart` (modify) | `initialTab` |
| `lib/features/query/presentation/entity_query_editor.dart`, `dive_query_editor.dart` (modify) | `initialTab`, `readQueryEditorContext` |
| `lib/features/dive_log/presentation/widgets/refine/*` (modify) | `initialDraft`, `startOnRulesBuilder` |
| `lib/l10n/arb/app_*.arb` (modify) | 13 new keys |

---

### Task 1: One surface interval SQL definition and its index

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_times_sql.dart` (append)
- Modify: `lib/core/database/performance_indexes.dart` (dives block)
- Test: `test/features/dive_log/data/repositories/dive_surface_interval_sql_test.dart` (create)
- Test: `test/core/database/query_plan_test.dart` (add one test)

**Interfaces:**
- Produces: `const String kSurfaceIntervalPreviousAlias = 'si_prev';` and `String diveSurfaceIntervalSecondsSql(String alias, {String previousScope = ''})`, an INTEGER-valued SQL expression in seconds, NULL for the first dive.

- [ ] **Step 1: Write the failing SQL tests**

```dart
// test/features/dive_log/data/repositories/dive_surface_interval_sql_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final base = DateTime.utc(2026, 4, 1, 10).millisecondsSinceEpoch;
  const minute = 60 * 1000;

  Future<void> insert(
    String id, {
    int? entry,
    int? exit,
    int? dateTime,
    int? runtimeSeconds,
    int? storedSi,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(dateTime ?? entry ?? base),
            entryTime: Value(entry),
            exitTime: Value(exit),
            runtime: Value(runtimeSeconds),
            surfaceIntervalSeconds: Value(storedSi),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
        );
  }

  Future<Map<String, Object?>> intervals() async {
    final rows = await db
        .customSelect(
          'SELECT d.id AS id, ${diveSurfaceIntervalSecondsSql('d')} AS si, '
          "typeof(${diveSurfaceIntervalSecondsSql('d')}) AS t FROM dives d",
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): (r.readNullable<int>('si'), r.read<String>('t')),
    };
  }

  test('first dive has no interval', () async {
    await insert('a', entry: base, exit: base + 40 * minute);
    expect((await intervals())['a'], (null, 'null'));
  });

  test('gap runs from the previous exit to this entry, as an integer', () async {
    await insert('a', entry: base, exit: base + 40 * minute + 500);
    await insert('b', entry: base + 120 * minute, exit: base + 160 * minute);
    // 80 min minus the 500 ms the previous exit ran over, truncated.
    expect((await intervals())['b'], (80 * 60 - 1, 'integer'));
  });

  test('a stored interval wins over the computed gap', () async {
    await insert('a', entry: base, exit: base + 40 * minute);
    await insert('b', entry: base + 120 * minute, storedSi: 3600);
    expect((await intervals())['b'], (3600, 'integer'));
  });

  test('previous exit falls back to its start plus its runtime', () async {
    await insert('a', entry: base, runtimeSeconds: 50 * 60);
    await insert('b', entry: base + 120 * minute);
    expect((await intervals())['b'], (70 * 60, 'integer'));
  });

  test('an overlapping dive clamps to zero', () async {
    await insert('a', entry: base, exit: base + 60 * minute);
    await insert('b', entry: base + 30 * minute);
    expect((await intervals())['b'], (0, 'integer'));
  });

  test('a dive with an entry time ranks above a later one without', () async {
    // getPreviousDiveTimes orders by entry_time DESC, so a null-entry dive
    // is the previous one only when no dive with an entry time precedes.
    await insert('a', entry: base, exit: base + 10 * minute);
    await insert('legacy', dateTime: base + 60 * minute);
    await insert('b', entry: base + 120 * minute);
    expect((await intervals())['b'], (110 * 60, 'integer'));
  });

  test('a null-entry dive is the previous one when nothing else is', () async {
    await insert('legacy', dateTime: base);
    await insert('b', entry: base + 30 * minute);
    expect((await intervals())['b'], (30 * 60, 'integer'));
  });

  test('previousScope narrows the previous dive', () async {
    await insert('a', entry: base, exit: base + 10 * minute);
    await insert('skip', entry: base + 60 * minute, exit: base + 70 * minute);
    await insert('b', entry: base + 120 * minute);
    final row = await db
        .customSelect(
          'SELECT ${diveSurfaceIntervalSecondsSql('d', previousScope: " AND $kSurfaceIntervalPreviousAlias.id != 'skip'")} AS si '
          "FROM dives d WHERE d.id = 'b'",
        )
        .getSingle();
    expect(row.read<int>('si'), 110 * 60);
  });
}
```

Add to `test/core/database/query_plan_test.dart` (inside `main`, after the existing tests; import `package:submersion/features/dive_log/data/repositories/dive_times_sql.dart`):

```dart
  test('surface interval lookups seek idx_dives_entry_date, never scan', () async {
    final p = await plan(
      db,
      'SELECT d.id, ${diveSurfaceIntervalSecondsSql('d')} FROM dives d',
    );
    expect(p, contains('idx_dives_entry_date'));
    expect(p, isNot(contains('SCAN $kSurfaceIntervalPreviousAlias')));
  });
```

- [ ] **Step 2: Run them red**

Run: `flutter test test/features/dive_log/data/repositories/dive_surface_interval_sql_test.dart test/core/database/query_plan_test.dart`
Expected: compile FAIL, `diveSurfaceIntervalSecondsSql` is not defined.

- [ ] **Step 3: Implement the expression**

Append to `dive_times_sql.dart`:

```dart
/// The alias the previous dive takes inside [diveSurfaceIntervalSecondsSql],
/// exposed so a caller's `previousScope` can name it.
const kSurfaceIntervalPreviousAlias = 'si_prev';

/// A dive's surface interval in whole seconds (#2984): ONE definition for
/// the dive table, the `surfaceInterval` query field and Insights.
///
/// The stored `surface_interval_seconds` wins. Otherwise it is the gap from
/// the previous dive's exit to this dive's start, where "previous" is what
/// `DiveRepository.getPreviousDiveTimes` picks for the detail page: any
/// diver, the dive whose `entry_time` is latest before this dive's start
/// (ties by `dive_date_time`), and only when no such dive exists, the
/// latest dive with no `entry_time` whose `dive_date_time` is before it.
/// That ranking is spelled as two subqueries so each is an index range seek
/// on `idx_dives_entry_date` rather than a scan of `dives` per row.
///
/// The previous dive's exit is its `exit_time`, else its start plus
/// [effectiveRuntimeSecondsSql]. A negative gap (overlapping dives) is
/// zero, matching `getSurfaceInterval`; the first dive is NULL. The CAST
/// truncates, like `Duration.inSeconds`.
///
/// [previousScope] is appended to both subqueries' WHERE clauses and must
/// lead with ` AND `; it names the previous dive as
/// [kSurfaceIntervalPreviousAlias].
String diveSurfaceIntervalSecondsSql(
  String alias, {
  String previousScope = '',
}) {
  const p = kSurfaceIntervalPreviousAlias;
  final start = 'COALESCE($alias.entry_time, $alias.dive_date_time)';
  final previousExit =
      'COALESCE($p.exit_time, COALESCE($p.entry_time, $p.dive_date_time) '
      '+ COALESCE(${effectiveRuntimeSecondsSql(p)}, 0) '
      '* $_millisecondsPerSecond)';
  String gap(String where, String order) =>
      '(SELECT MAX(0, CAST(($start - $previousExit) '
      '/ $_millisecondsPerSecond AS INTEGER)) '
      'FROM dives $p WHERE $p.id != $alias.id AND $where$previousScope '
      'ORDER BY $order LIMIT 1)';
  return 'COALESCE($alias.surface_interval_seconds, '
      '${gap('$p.entry_time < $start', '$p.entry_time DESC, $p.dive_date_time DESC')}, '
      '${gap('$p.entry_time IS NULL AND $p.dive_date_time < $start', '$p.dive_date_time DESC')})';
}
```

Add to `kPerformanceIndexes`, after `idx_dives_diver_exittime`:

```dart
  // The previous-dive seeks of diveSurfaceIntervalSecondsSql (#2984): a
  // range on entry_time, and entry_time IS NULL plus a range on
  // dive_date_time. Not diver-leading, because the detail page's previous
  // dive is not diver-scoped.
  (
    name: 'idx_dives_entry_date',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_entry_date '
        'ON dives(entry_time, dive_date_time)',
  ),
```

- [ ] **Step 4: Run them green**

Run: `flutter test test/features/dive_log/data/repositories/dive_surface_interval_sql_test.dart test/core/database/query_plan_test.dart test/core/database/performance_indexes_test.dart`
Expected: PASS. If the plan test shows `SCAN si_prev`, read the printed plan and adjust only the index column order, never the predicate.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_times_sql.dart lib/core/database/performance_indexes.dart test/features/dive_log/data/repositories/dive_surface_interval_sql_test.dart test/core/database/query_plan_test.dart
git commit -m "feat(dive-log): one SQL definition of a dive's surface interval"
```

---

### Task 2: Batch surface intervals for the table

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (after `getSurfaceInterval`, near line 5478)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart:1378-1404` (replace `surfaceIntervalsProvider`)
- Test: `test/features/dive_log/data/repositories/dive_surface_intervals_parity_test.dart` (create)

**Interfaces:**
- Consumes: `diveSurfaceIntervalSecondsSql` (Task 1).
- Produces: `Future<Map<String, Duration?>> DiveRepository.getSurfaceIntervals()`; `final diveSurfaceIntervalsProvider = FutureProvider<Map<String, Duration?>>`.

- [ ] **Step 1: Write the failing parity test**

```dart
// test/features/dive_log/data/repositories/dive_surface_intervals_parity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 4, 1, hour, minute);

  test('the batch matches the detail page for every dive', () async {
    final dives = [
      domain.Dive(id: 'first', dateTime: at(8), entryTime: at(8), exitTime: at(8, 45)),
      domain.Dive(id: 'runtime-only', dateTime: at(10), entryTime: at(10), runtime: const Duration(minutes: 50)),
      domain.Dive(id: 'after-runtime', dateTime: at(12), entryTime: at(12), exitTime: at(12, 40)),
      domain.Dive(id: 'overlap', dateTime: at(12, 20), entryTime: at(12, 20)),
      domain.Dive(id: 'stored', dateTime: at(15), entryTime: at(15), surfaceInterval: const Duration(minutes: 33)),
      domain.Dive(
        id: 'profile-only',
        dateTime: at(17),
        entryTime: at(17),
        profile: [
          for (var t = 0; t <= 1200; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t == 0 || t == 1200 ? 0 : 12),
        ],
      ),
      domain.Dive(id: 'after-profile', dateTime: at(19), entryTime: at(19)),
    ];
    for (final d in dives) {
      await repository.createDive(d);
    }

    final batch = await repository.getSurfaceIntervals();

    for (final d in dives) {
      final detail = d.surfaceInterval ?? await repository.getSurfaceInterval(d.id);
      expect(batch[d.id], detail, reason: d.id);
    }
    expect(batch['first'], isNull);
    expect(batch['stored'], const Duration(minutes: 33));
  });
}
```

- [ ] **Step 2: Run it red**

Run: `flutter test test/features/dive_log/data/repositories/dive_surface_intervals_parity_test.dart`
Expected: compile FAIL, `getSurfaceIntervals` not defined.

- [ ] **Step 3: Implement the batch read and provider**

In `dive_repository_impl.dart`, add the import `import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';` if absent, and after `getSurfaceInterval`:

```dart
  /// Every dive's surface interval keyed by id (#2984): the stored value,
  /// else the gap [diveSurfaceIntervalSecondsSql] computes, which is what
  /// [getSurfaceInterval] gives the detail page. One statement over the
  /// whole log, so filtering the table never changes the dive a gap is
  /// measured from.
  // stats-scope-exempt: physiological interval between real dives, not a statistic
  Future<Map<String, Duration?>> getSurfaceIntervals() async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT d.id AS id, ${diveSurfaceIntervalSecondsSql('d')} AS si '
            'FROM dives d',
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();
      return {
        for (final row in rows)
          row.read<String>('id'): switch (row.readNullable<int>('si')) {
            null => null,
            final seconds => Duration(seconds: seconds),
          },
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to calculate surface intervals',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `dive_providers.dart`, replace the whole `surfaceIntervalsProvider` declaration and its doc comment with:

```dart
/// Every dive's surface interval for the table (#2984), over the whole log
/// so a filter never changes the dive a gap is measured from. Reloaded on
/// any write to `dives`, which is where entry, exit and runtime live.
final diveSurfaceIntervalsProvider = FutureProvider<Map<String, Duration?>>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getSurfaceIntervals();
});
```

Then `grep -rn "surfaceIntervalsProvider" lib test` and confirm only `diveSurfaceIntervalsProvider` remains.

- [ ] **Step 4: Run it green**

Run: `flutter test test/features/dive_log/data/repositories/dive_surface_intervals_parity_test.dart test/architecture/`
Expected: PASS. If a dive differs, the definition in Task 1 disagrees with `getPreviousDiveTimes`/`DiveTimes.effectiveRuntime`; fix `diveSurfaceIntervalSecondsSql`, never the detail page.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/data/repositories/dive_surface_intervals_parity_test.dart
git commit -m "feat(dive-log): batch surface intervals matching the detail page"
```

---

### Task 3: The `surfaceInterval` query field reads the shared definition

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart:320-325`
- Test: `test/features/dive_log/query/dive_query_surface_interval_test.dart` (create)

**Interfaces:**
- Consumes: `diveSurfaceIntervalSecondsSql` (Task 1).

- [ ] **Step 1: Write the failing test**

Self-contained (no `seedQueryFixture`: its dives would become previous dives). The `ids` helper is the one in `dive_query_semantics_test.dart`, minus the diver filter.

```dart
// test/features/dive_log/query/dive_query_surface_interval_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 10),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final node = (parser.parse(text) as ParseOk).node;
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  final base = DateTime.utc(2026, 4, 1, 10);
  Dive dive(String id, int startMinute, {int? exitMinute, Duration? stored}) =>
      Dive(
        id: id,
        dateTime: base.add(Duration(minutes: startMinute)),
        entryTime: base.add(Duration(minutes: startMinute)),
        exitTime: exitMinute == null
            ? null
            : base.add(Duration(minutes: exitMinute)),
        surfaceInterval: stored,
      );

  test('surfaceInterval filters on the computed gap when none is stored', () async {
    await repository.createDive(dive('a', 0, exitMinute: 40));
    await repository.createDive(dive('b', 100));

    expect(await ids('surfaceInterval = 60'), {'b'});
    expect(await ids('surfaceInterval >= 61'), isEmpty);
    expect(await ids('surfaceInterval:none'), {'a'});
  });

  test('a stored interval still wins', () async {
    await repository.createDive(dive('a', 0, exitMinute: 40));
    await repository.createDive(dive('b', 100, stored: const Duration(minutes: 15)));

    expect(await ids('surfaceInterval = 15'), {'b'});
  });
}
```

- [ ] **Step 2: Run it red**

Run: `flutter test test/features/dive_log/query/dive_query_surface_interval_test.dart`
Expected: FAIL, `surfaceInterval = 60` matches nothing (the field reads only the stored column).

- [ ] **Step 3: Point the field at the shared SQL**

Add `import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';` and replace the `surfaceInterval` entry:

```dart
    // The table's value (#2984): stored, else the gap from the previous
    // dive, so what a diver sees in the column is what this field filters.
    _num(
      'surfaceInterval',
      '(${diveSurfaceIntervalSecondsSql('{r}')} / 60)',
      dimension: FieldDimension.minutes,
      emptySql: '(${diveSurfaceIntervalSecondsSql('{r}')}) IS NULL',
      tables: const ['dive_profile_series'],
    ),
```

- [ ] **Step 4: Run green, plus the query suites**

Run: `flutter test test/features/dive_log/query/ test/core/query/ test/features/query/`
Expected: PASS. A golden SQL test that pinned the old `surface_interval_seconds / 60` text is updated to the new expression in this step (the behaviour change is the point).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/query/dive_query_entity.dart test/features/dive_log/query/dive_query_surface_interval_test.dart
git commit -m "feat(dive-log): filter surface interval on the value the table shows"
```

---

### Task 4: Insights surface interval stats read the shared definition

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:2473-2533`
- Test: `test/features/insights/data/repositories/insights_repository_surface_interval_test.dart` (add two tests)

- [ ] **Step 1: Write the failing tests** (inside the existing `group('getSurfaceIntervalStats', ...)`)

```dart
    test('measures from the previous dive whatever its diver, like the detail page', () async {
      final a = await insertDiver(id: 'diver-a');
      final b = await insertDiver(id: 'diver-b');
      final base = DateTime(2024, 9, 1).millisecondsSinceEpoch;
      await insertDive(id: 'a1', diverId: a, entryTimeMs: base, exitTimeMs: base + 30 * 60 * 1000);
      await insertDive(id: 'b1', diverId: b, entryTimeMs: base + 60 * 60 * 1000, exitTimeMs: base + 90 * 60 * 1000);
      await insertDive(id: 'a2', diverId: a, entryTimeMs: base + 120 * 60 * 1000);

      final stats = await repository.getSurfaceIntervalStats(diverId: a);

      // a2 measures from b1's exit (30 min), not a1's (90 min).
      expect(stats.minMinutes, closeTo(30.0, 0.1));
      expect(stats.maxMinutes, closeTo(30.0, 0.1));
    });

    test('a previous dive excluded from statistics is skipped', () async {
      final base = DateTime(2024, 10, 1).millisecondsSinceEpoch;
      await insertDive(id: 'kept', entryTimeMs: base, exitTimeMs: base + 30 * 60 * 1000);
      await insertDive(id: 'excluded', entryTimeMs: base + 60 * 60 * 1000, exitTimeMs: base + 90 * 60 * 1000);
      await (db.update(db.dives)..where((t) => t.id.equals('excluded')))
          .write(const DivesCompanion(excludedFromStats: Value(true)));
      await insertDive(id: 'next', entryTimeMs: base + 120 * 60 * 1000);

      final stats = await repository.getSurfaceIntervalStats();

      expect(stats.maxMinutes, closeTo(90.0, 0.1));
    });
```

- [ ] **Step 2: Run red**

Run: `flutter test test/features/insights/data/repositories/insights_repository_surface_interval_test.dart`
Expected: the first new test FAILS (90 minutes: today's query is diver-scoped).

- [ ] **Step 3: Use the shared expression**

Add `import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';` and replace the inner `SELECT COALESCE(...) AS effective_si` block with:

```dart
        FROM (
          SELECT
            ${diveSurfaceIntervalSecondsSql(
              'd',
              // The scope applies to the preceding dive as well: a surface
              // interval measured from an excluded dive is as wrong as one
              // measured to it. The user filter never reaches this alias.
              previousScope: DiveStatsScope.and(alias: kSurfaceIntervalPreviousAlias),
            )} AS effective_si
          FROM dives d
          WHERE 1=1 $diverFilter ${df.clause}
        )
```

Keep the outer `WHERE effective_si IS NOT NULL AND effective_si > 0` and the AVG/MIN/MAX over `effective_si / 60.0`.

- [ ] **Step 4: Run green**

Run: `flutter test test/features/insights/`
Expected: PASS (the five existing tests keep passing).

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/data/repositories/insights_repository.dart test/features/insights/data/repositories/insights_repository_surface_interval_test.dart
git commit -m "feat(insights): surface interval stats use the dive table's definition"
```

---

### Task 5: `DiveField` implements `EntityField`; `DiveFieldAdapter`

**Files:**
- Create: `lib/core/constants/dive_field_labels.dart`
- Modify: `lib/core/constants/dive_field.dart`
- Create: `lib/features/dive_log/presentation/table/dive_field_adapter.dart`
- Test: `test/core/constants/dive_field_entity_field_test.dart` (create)
- Test: `test/features/dive_log/presentation/table/dive_field_adapter_test.dart` (create)

**Interfaces:**
- Produces: `enum DiveField implements EntityField` with `bool get isRightAligned`; `class DiveFieldAdapter extends EntityFieldAdapter<Dive, DiveField>` with ctor `DiveFieldAdapter({GasModel gasModel = GasModel.real, String Function(String id)? diveTypeLabel, Map<String, Duration?> surfaceIntervals = const {}})`; `extension TableViewConfigEntityView on TableViewConfig { EntityTableViewConfig<DiveField> toEntityConfig(); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/constants/dive_field_entity_field_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/shared/constants/entity_field.dart';

void main() {
  test('every DiveField is an EntityField with its existing metadata', () {
    for (final f in DiveField.values) {
      final EntityField e = f;
      expect(e.categoryName, f.category.name);
      expect(e.minWidth, lessThanOrEqualTo(e.defaultWidth));
    }
  });

  test('numeric columns align right, text columns left', () {
    expect(DiveField.maxDepth.isRightAligned, isTrue);
    expect(DiveField.surfaceInterval.isRightAligned, isTrue);
    expect(DiveField.siteName.isRightAligned, isFalse);
    expect(DiveField.notes.isRightAligned, isFalse);
  });
}
```

```dart
// test/features/dive_log/presentation/table/dive_field_adapter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';

void main() {
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026, 4, 1), maxDepth: 23.4);

  test('surface interval reads the computed map', () {
    final adapter = DiveFieldAdapter(surfaceIntervals: const {'d1': Duration(minutes: 75)});
    expect(adapter.extractValue(DiveField.surfaceInterval, dive), const Duration(minutes: 75));
  });

  test('a dive missing from the map shows its stored interval', () {
    final stored = dive.copyWith(surfaceInterval: const Duration(minutes: 9));
    expect(DiveFieldAdapter().extractValue(DiveField.surfaceInterval, stored), const Duration(minutes: 9));
  });

  test('other fields delegate to extractFromDive', () {
    expect(DiveFieldAdapter().extractValue(DiveField.maxDepth, dive), 23.4);
  });

  test('table config converts without changing columns, widths or sort', () {
    final config = TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true, width: 70),
        TableColumnConfig(field: DiveField.maxDepth, width: 91),
      ],
      sortField: DiveField.maxDepth,
      sortAscending: false,
    );
    final entity = config.toEntityConfig();
    expect(entity.toJson(), config.toJson());
  });
}
```

- [ ] **Step 2: Run red**

Run: `flutter test test/core/constants/dive_field_entity_field_test.dart test/features/dive_log/presentation/table/dive_field_adapter_test.dart`
Expected: compile FAIL (`DiveField` is not an `EntityField`; adapter missing).

- [ ] **Step 3: Move the label switches out, then implement the interface**

Move `localizedDisplayName` and `localizedShortLabel` (the two `switch (this)` expressions at `dive_field.dart:506-633`) verbatim into a new extension:

```dart
// lib/core/constants/dive_field_labels.dart
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized names of each [DiveField], split from `dive_field.dart` to keep
/// it under the 800-line limit.
extension DiveFieldLabels on DiveField {
  /// Localized full name for settings and picker UIs.
  String labelFor(AppLocalizations l10n) => switch (this) {
    // (the localizedDisplayName arms, unchanged)
  };

  /// Localized compact label for column headers.
  String shortLabelFor(AppLocalizations l10n) => switch (this) {
    // (the localizedShortLabel arms, unchanged)
  };
}
```

Delete those two members from `DiveFieldMetadata`. In `dive_field.dart` add `import 'package:submersion/shared/constants/entity_field.dart';` and `import 'package:submersion/core/constants/dive_field_labels.dart';`, add `export 'package:submersion/core/constants/dive_field_labels.dart';` beside the other exports, change the enum header to `enum DiveField implements EntityField {`, and after the last value add (turning the final `,` into `;`):

```dart
  // EntityField (#2984), so the dive table runs on the shared EntityTableView.
  // The logic stays in the extensions; these forward to it.
  @override
  String get displayName => DiveFieldMetadata(this).displayName;
  @override
  String get shortLabel => DiveFieldMetadata(this).shortLabel;
  @override
  String localizedDisplayName(AppLocalizations l10n) => labelFor(l10n);
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabelFor(l10n);
  @override
  IconData? get icon => DiveFieldMetadata(this).icon;
  @override
  double get defaultWidth => DiveFieldColumnSizing(this).defaultWidth;
  @override
  double get minWidth => DiveFieldColumnSizing(this).minWidth;
  @override
  bool get sortable => DiveFieldMetadata(this).sortable;
  @override
  String get categoryName => DiveFieldMetadata(this).category.name;
  @override
  bool get isRightAligned => _rightAligned.contains(this);

  /// Numeric columns, right-aligned (moved from DiveTableView).
  static const Set<DiveField> _rightAligned = {
    diveNumber, maxDepth, avgDepth, bottomTime, runtime, waterTemp, airTemp,
    swellHeight, altitude, surfacePressure, windSpeed, humidity, tankCount,
    startPressure, endPressure, sac, rmv, gasConsumed, totalWeight,
    gradientFactorLow, gradientFactorHigh, cnsStart, cnsEnd, otu,
    setpointLow, setpointHigh, setpointDeco, ratingStars, surfaceInterval,
    siteLatitude, siteLongitude,
  };
```

If `DiveFieldMetadata` does not already declare `displayName`, `shortLabel`, `icon` and `sortable` (it does at lines 259, 383, 635, 758), stop and re-read the file. Existing callers of `field.localizedDisplayName(l10n)` keep compiling through the forwarding member.

Create the adapter:

```dart
// lib/features/dive_log/presentation/table/dive_field_adapter.dart
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

/// Feeds dives to the shared EntityTableView (#2984). Carries the context
/// the dive columns need that a field enum cannot: the RMV gas model, the
/// dive-type label resolver and the computed surface intervals.
class DiveFieldAdapter extends EntityFieldAdapter<Dive, DiveField> {
  DiveFieldAdapter({
    this.gasModel = GasModel.real,
    this.diveTypeLabel,
    this.surfaceIntervals = const {},
  });

  final GasModel gasModel;
  final String Function(String id)? diveTypeLabel;

  /// `diveSurfaceIntervalsProvider`'s map (stored, else computed). A dive
  /// missing from it (still loading, or the read failed) shows its stored
  /// value.
  final Map<String, Duration?> surfaceIntervals;

  @override
  List<DiveField> get allFields => DiveField.values;

  @override
  Map<String, List<DiveField>> get fieldsByCategory => {
    for (final c in DiveFieldCategory.values)
      c.name: DiveField.fieldsForCategory(c),
  };

  @override
  dynamic extractValue(DiveField field, Dive entity) {
    if (field == DiveField.surfaceInterval &&
        surfaceIntervals.containsKey(entity.id)) {
      return surfaceIntervals[entity.id];
    }
    return field.extractFromDive(
      entity,
      gasModel: gasModel,
      diveTypeLabel: diveTypeLabel,
    );
  }

  @override
  String formatValue(DiveField field, dynamic value, UnitFormatter units) =>
      field.formatValue(value, units);

  @override
  DiveField fieldFromName(String name) =>
      diveFieldFromName(name) ?? DiveField.diveNumber;
}

/// The dive table's stored config as the shared table reads it. Same JSON
/// shape, so nothing stored changes.
extension TableViewConfigEntityView on TableViewConfig {
  EntityTableViewConfig<DiveField> toEntityConfig() =>
      EntityTableViewConfig<DiveField>(
        columns: [
          for (final c in columns)
            EntityTableColumnConfig<DiveField>(
              field: c.field,
              width: c.width,
              isPinned: c.isPinned,
            ),
        ],
        sortField: sortField,
        sortAscending: sortAscending,
      );
}
```

- [ ] **Step 4: Run green, plus everything that reads DiveField**

Run: `flutter analyze` then `flutter test test/core/constants/ test/features/dive_log/presentation/ test/features/settings/presentation/pages/column_config_page_test.dart`
Expected: PASS, analyze clean, `wc -l lib/core/constants/dive_field.dart` under 800.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/ lib/features/dive_log/presentation/table/dive_field_adapter.dart test/core/constants/dive_field_entity_field_test.dart test/features/dive_log/presentation/table/dive_field_adapter_test.dart
git commit -m "refactor(dive-log): DiveField implements EntityField with a table adapter"
```

---

### Task 6: A resize handle that follows the pointer and commits once

**Files:**
- Create: `lib/shared/widgets/entity_table/entity_table_resize_handle.dart`
- Modify: `lib/shared/widgets/entity_table/entity_table_header_cell.dart`
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart`
- Create: `test/shared/widgets/entity_table/entity_table_test_harness.dart` (shared test fixtures)
- Test: `test/shared/widgets/entity_table/entity_table_resize_test.dart` (create)

**Interfaces:**
- Produces: `const double kEntityTableMaxColumnWidth = 600.0;`; `EntityTableHeaderCell` gains `double minWidth` (defaults to `field.minWidth`) and `VoidCallback? onResizeEnd`; `onResize` keeps its `ValueChanged<double>` type and now receives the live absolute width. `EntityTableView.onResizeColumn` is called once per drag, on end.
- Test harness produces: `class TestEntity`, `class TestField implements EntityField` (fields `entityName`, `entityCount`, `values`), `class TestAdapter`, `Widget buildTestTable({...})` mirroring `entity_table_view_test.dart`'s private fixtures with every new `EntityTableView` parameter optional.

- [ ] **Step 1: Write the harness and the failing test**

Create the harness by copying `_TestEntity`, `_TestField`, `_TestAdapter`, `_defaultConfig`, `_units` and `_buildTable` from `test/shared/widgets/entity_table/entity_table_view_test.dart` (lines 15-160), renaming them public (`TestEntity`, `TestField`, `TestAdapter`, `testTableConfig`, `buildTestTable`). `buildTestTable` takes the same parameters plus `void Function(TestField)? onHideColumn`, `EntityTableHeaderMenuBuilder<TestField>? headerMenuBuilder`, `EntityTableCellMenuBuilder<TestEntity, TestField>? cellMenuBuilder`, `bool Function(TestField)? isColumnFiltered` (add those four in Task 8; Task 6 needs only the existing ones).

```dart
// test/shared/widgets/entity_table/entity_table_resize_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';

import 'entity_table_test_harness.dart';

void main() {
  Finder header(String label) =>
      find.widgetWithText(EntityTableHeaderCell, label);

  testWidgets('the edge stays under the pointer past the minimum and back', (
    tester,
  ) async {
    final commits = <double>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [TestEntity('a', 'Alpha', 1)],
        onResizeColumn: (_, w) => commits.add(w),
      ),
    );
    // Count is 120 wide with a 60 minimum. Grab its right edge.
    final rect = tester.getRect(header('Count'));
    final gesture = await tester.startGesture(
      Offset(rect.right - 2, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-100, 0)); // asks for 20, clamps to 60
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 60);

    await gesture.moveBy(const Offset(40, 0)); // pointer is 60 left of start
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 60);

    await gesture.moveBy(const Offset(30, 0)); // pointer is 30 left of start
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 90);
    expect(commits, isEmpty, reason: 'nothing saved mid-drag');

    await gesture.up();
    await tester.pump();
    expect(commits, [90]);
  });

  testWidgets('the width never exceeds the maximum', (tester) async {
    final commits = <double>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [TestEntity('a', 'Alpha', 1)],
        onResizeColumn: (_, w) => commits.add(w),
      ),
    );
    final rect = tester.getRect(header('Count'));
    final gesture = await tester.startGesture(
      Offset(rect.right - 2, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(900, 0));
    await gesture.up();
    await tester.pump();
    expect(commits, [600]);
  });
}
```

- [ ] **Step 2: Run red**

Run: `flutter test test/shared/widgets/entity_table/entity_table_resize_test.dart`
Expected: FAIL (`commits` is non-empty mid-drag; width drifts to 100 after the return move).

- [ ] **Step 3: Implement**

```dart
// lib/shared/widgets/entity_table/entity_table_resize_handle.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Widest a column can be dragged.
const double kEntityTableMaxColumnWidth = 600.0;

/// The drag handle on a header's trailing edge (#2984).
///
/// Width is computed from where the drag STARTED, not added up from deltas,
/// so the edge stays under the pointer after the width hits [minWidth] and
/// the pointer comes back. [onResize] gets each live width; [onResizeEnd]
/// fires once when the drag ends or is cancelled, which is when the table
/// saves.
class EntityTableResizeHandle extends StatefulWidget {
  const EntityTableResizeHandle({
    super.key,
    required this.width,
    required this.minWidth,
    required this.handleWidth,
    required this.color,
    required this.onResize,
    this.onResizeEnd,
  });

  final double width;
  final double minWidth;
  final double handleWidth;
  final Color color;
  final ValueChanged<double> onResize;
  final VoidCallback? onResizeEnd;

  @override
  State<EntityTableResizeHandle> createState() =>
      _EntityTableResizeHandleState();
}

class _EntityTableResizeHandleState extends State<EntityTableResizeHandle> {
  double? _startWidth;
  double _startX = 0;
  double? _last;

  void _end() {
    if (_startWidth == null) return;
    _startWidth = null;
    _last = null;
    widget.onResizeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Measured from pointer-down, so the touch slop is not lost.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: (d) {
        _startWidth = widget.width;
        _startX = d.globalPosition.dx;
      },
      onHorizontalDragUpdate: (d) {
        final start = _startWidth;
        if (start == null) return;
        final next = (start + d.globalPosition.dx - _startX)
            .clamp(widget.minWidth, kEntityTableMaxColumnWidth)
            .toDouble();
        if (next == _last) return;
        _last = next;
        widget.onResize(next);
      },
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: widget.handleWidth,
          child: Center(child: Container(width: 1, color: widget.color)),
        ),
      ),
    );
  }
}
```

In `EntityTableHeaderCell`: add fields `final double? minWidth;` and `final VoidCallback? onResizeEnd;` (constructor params), and replace the `GestureDetector(...)` resize child of the `Positioned` with:

```dart
              child: EntityTableResizeHandle(
                width: width,
                minWidth: minWidth ?? field.minWidth,
                handleWidth: handleWidth,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                onResize: onResize!,
                onResizeEnd: onResizeEnd,
              ),
```

In `_EntityTableViewState`: add `final Map<F, double> _liveWidths = {};` and

```dart
  double _widthOf(EntityTableColumnConfig<F> c) =>
      _liveWidths[c.field] ?? c.width;

  void _resizeLive(F field, double width) =>
      setState(() => _liveWidths[field] = width);

  void _resizeCommit(F field) {
    final width = _liveWidths[field];
    if (width == null) return;
    widget.onResizeColumn(field, width);
    setState(() => _liveWidths.remove(field));
  }
```

Use `_widthOf(col)` everywhere `col.width`/`column.width`/`c.width` is read (`_pinnedWidth`, `_scrollableWidth`, both header maps, `_buildCell`), and pass `onResize: (w) => _resizeLive(col.field, w), onResizeEnd: () => _resizeCommit(col.field)` to both header cell constructions.

- [ ] **Step 4: Run green**

Run: `flutter test test/shared/widgets/entity_table/`
Expected: PASS. `entity_table_header_cell_test.dart`'s "drag handle ... triggers onResize" still expects about 140 after a 20 px drag, which the new handle gives.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/entity_table/ test/shared/widgets/entity_table/
git commit -m "fix(shared): column resize follows the pointer and saves once"
```

---

### Task 7: Table scrollbars

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart` (body)
- Test: `test/shared/widgets/entity_table/entity_table_scrollbar_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/widgets/entity_table/entity_table_scrollbar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entity_table_test_harness.dart';

void main() {
  final many = [
    for (var i = 0; i < 80; i++) TestEntity('e$i', 'Name $i', i),
  ];

  Scrollbar bar(WidgetTester tester, Axis axis) => tester
      .widgetList<Scrollbar>(find.byType(Scrollbar))
      .singleWhere((s) => s.controller!.position.axis == axis);

  testWidgets('one vertical and one horizontal scrollbar, always shown on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestTable(entities: many));
    await tester.pumpAndSettle();
    expect(bar(tester, Axis.vertical).thumbVisibility, isTrue);
    expect(bar(tester, Axis.horizontal).thumbVisibility, isTrue);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('touch platforms keep the default visibility', (tester) async {
    await tester.pumpWidget(buildTestTable(entities: many));
    await tester.pumpAndSettle();
    expect(bar(tester, Axis.vertical).thumbVisibility, isNull);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('the vertical bar tracks the body list as it scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestTable(entities: many));
    await tester.pumpAndSettle();
    final vertical = bar(tester, Axis.vertical).controller!;
    await tester.drag(find.text('Name 5'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run red**

Run: `flutter test test/shared/widgets/entity_table/entity_table_scrollbar_test.dart`
Expected: FAIL, no `Scrollbar` found.

- [ ] **Step 3: Implement**

Add to the state class:

```dart
  static const _desktop = {
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  /// Always-visible bars on desktop, the platform default on touch.
  bool? get _thumbVisibility =>
      _desktop.contains(defaultTargetPlatform) ? true : null;
```

(import `package:flutter/foundation.dart` for `defaultTargetPlatform`). Wrap the pinned `ListView.builder` in
`ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false), child: ...)` so the pinned column never draws its own bar, and replace the scrollable body's `Expanded(child: SingleChildScrollView(...))` with:

```dart
              // Both bars sit outside the horizontal scroller, so the
              // vertical one stays at the viewport's edge (#2984). The body
              // list is one scrollable below the horizontal one (depth 1).
              Expanded(
                child: Scrollbar(
                  controller: _bodyHorizontalController,
                  thumbVisibility: _thumbVisibility,
                  notificationPredicate: (n) =>
                      n.depth == 0 && n.metrics.axis == Axis.horizontal,
                  child: Scrollbar(
                    controller: _scrollableVerticalController,
                    thumbVisibility: _thumbVisibility,
                    notificationPredicate: (n) =>
                        n.depth == 1 && n.metrics.axis == Axis.vertical,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        // (the existing horizontal SingleChildScrollView,
                        // unchanged)
                      ),
                    ),
                  ),
                ),
              ),
```

- [ ] **Step 4: Run green**

Run: `flutter test test/shared/widgets/entity_table/ test/shared/widgets/table_mode_layout/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/entity_table/entity_table_view.dart test/shared/widgets/entity_table/entity_table_scrollbar_test.dart
git commit -m "feat(shared): vertical and horizontal scrollbars on every table"
```

---

### Task 8: Header and cell menus; Hide column on every table

**Files:**
- Create: `lib/shared/widgets/entity_table/entity_table_menu.dart`
- Modify: `lib/shared/widgets/entity_table/entity_table_header_cell.dart`, `entity_table_view.dart`
- Modify: `lib/shared/providers/entity_table_config_providers.dart`, `lib/features/dive_log/presentation/providers/view_config_providers.dart`
- Modify: the seven list contents (`course`, `site`, `certification`, `trip`, `dive_center`, `equipment`, `buddy` `*_list_content.dart`)
- Modify: `lib/l10n/arb/app_en.arb` (one key; locales in Task 13)
- Test: `test/shared/widgets/entity_table/entity_table_menu_test.dart` (create)
- Test: `test/shared/providers/entity_table_config_notifier_test.dart`, `test/features/dive_log/presentation/providers/view_config_providers_test.dart` (add; create the latter if absent)

**Interfaces:**
- Produces:

```dart
class EntityTableMenuAction {
  const EntityTableMenuAction({required String label, required VoidCallback onSelected, bool enabled = true});
}
typedef EntityTableHeaderMenuBuilder<F> = List<EntityTableMenuAction> Function(BuildContext context, F field);
typedef EntityTableCellMenuBuilder<T, F> = List<EntityTableMenuAction> Function(BuildContext context, T entity, F field);
Future<void> showEntityTableMenu(BuildContext context, {required Offset position, required List<List<EntityTableMenuAction>> sections});
```

`EntityTableView` gains optional `onHideColumn`, `headerMenuBuilder`, `cellMenuBuilder`, `isColumnFiltered`. `EntityTableConfigNotifier.hideColumn(F)` and `TableViewConfigNotifier.hideColumn(DiveField)`. ARB key `tableMode_menu_hideColumn`.

- [ ] **Step 1: Write the failing tests**

Notifier tests (add to `entity_table_config_notifier_test.dart`, using its existing notifier setup; mirror them for `TableViewConfigNotifier` with `DiveField`):

```dart
  group('hideColumn', () {
    test('removes a column, pinned or not', () {
      notifier.hideColumn(TestField.entityName); // pinned in the default config
      expect(notifier.state.columns.map((c) => c.field), [TestField.entityCount]);
    });

    test('never removes the last column', () {
      notifier.hideColumn(TestField.entityName);
      notifier.hideColumn(TestField.entityCount);
      expect(notifier.state.columns, hasLength(1));
    });

    test('clears the sort when the sorted column goes', () {
      notifier.setSortField(TestField.entityCount);
      notifier.hideColumn(TestField.entityCount);
      expect(notifier.state.sortField, isNull);
    });
  });
```

Widget tests:

```dart
// test/shared/widgets/entity_table/entity_table_menu_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

import 'entity_table_test_harness.dart';

void main() {
  const rows = [TestEntity('a', 'Alpha', 1), TestEntity('b', 'Beta', 2)];

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('right-click on a header offers Hide column', (tester) async {
    TestField? hidden;
    await tester.pumpWidget(
      buildTestTable(entities: rows, onHideColumn: (f) => hidden = f),
    );
    await rightClick(tester, find.text('Count'));
    await tester.tap(find.text('Hide column'));
    await tester.pumpAndSettle();
    expect(hidden, TestField.entityCount);
  });

  testWidgets('long-press on a header opens the same menu', (tester) async {
    await tester.pumpWidget(buildTestTable(entities: rows, onHideColumn: (_) {}));
    await tester.longPress(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('Hide column'), findsOneWidget);
  });

  testWidgets('Hide column is disabled on the last column', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        config: testSingleColumnConfig,
        onHideColumn: (_) {},
      ),
    );
    await rightClick(tester, find.text('Name'));
    final item = tester.widget<PopupMenuItem<EntityTableMenuAction>>(
      find.ancestor(of: find.text('Hide column'), matching: find.byType(PopupMenuItem<EntityTableMenuAction>)),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('header builder items come before Hide column', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        onHideColumn: (_) {},
        headerMenuBuilder: (_, f) => [
          EntityTableMenuAction(label: 'Extra ${f.name}', onSelected: () {}),
        ],
      ),
    );
    await rightClick(tester, find.text('Count'));
    final extra = tester.getTopLeft(find.text('Extra entityCount')).dy;
    final hide = tester.getTopLeft(find.text('Hide column')).dy;
    expect(extra, lessThan(hide));
  });

  testWidgets('a cell menu opens on right-click and on long-press', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        cellMenuBuilder: (_, e, f) => [
          EntityTableMenuAction(label: 'Pick ${e.id}', onSelected: () => picked.add(e.id)),
        ],
      ),
    );
    await rightClick(tester, find.text('Beta'));
    await tester.tap(find.text('Pick b'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick a'));
    await tester.pumpAndSettle();
    expect(picked, ['b', 'a']);
  });

  testWidgets('without a cell builder no row registers a long-press', (tester) async {
    await tester.pumpWidget(buildTestTable(entities: rows));
    final detectors = tester.widgetList<RawGestureDetector>(find.byType(RawGestureDetector));
    for (final d in detectors) {
      expect(d.gestures.containsKey(LongPressGestureRecognizer), isFalse);
    }
  });

  testWidgets('a filtered column shows the indicator', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        isColumnFiltered: (f) => f == TestField.entityCount,
      ),
    );
    expect(find.byKey(const ValueKey('entity-table-filtered-entityCount')), findsOneWidget);
    expect(find.byKey(const ValueKey('entity-table-filtered-entityName')), findsNothing);
  });
}
```

The long-press-registration test only checks rows: header cells are allowed a long-press recognizer when `onHideColumn` or `headerMenuBuilder` is set, and neither is set there. Add `testSingleColumnConfig` (one pinned `entityName` column) to the harness, plus the four new `buildTestTable` parameters.

- [ ] **Step 2: Run red**

Run: `flutter test test/shared/widgets/entity_table/entity_table_menu_test.dart test/shared/providers/entity_table_config_notifier_test.dart`
Expected: compile FAIL (`entity_table_menu.dart`, `hideColumn` missing).

- [ ] **Step 3: Implement**

```dart
// lib/shared/widgets/entity_table/entity_table_menu.dart
import 'package:flutter/material.dart';

/// One item in a table header or cell menu (#2984).
@immutable
class EntityTableMenuAction {
  const EntityTableMenuAction({
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// Items a list adds to a column's header menu, above "Hide column".
typedef EntityTableHeaderMenuBuilder<F> =
    List<EntityTableMenuAction> Function(BuildContext context, F field);

/// Items for the menu of one cell; an empty list shows no menu.
typedef EntityTableCellMenuBuilder<T, F> =
    List<EntityTableMenuAction> Function(
      BuildContext context,
      T entity,
      F field,
    );

/// Shows [sections] as one popup at [position] (global), a divider between
/// non-empty sections, and runs the chosen action after the menu closes.
Future<void> showEntityTableMenu(
  BuildContext context, {
  required Offset position,
  required List<List<EntityTableMenuAction>> sections,
}) async {
  final shown = sections.where((s) => s.isNotEmpty).toList();
  if (shown.isEmpty) return;
  final overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(position);
  final chosen = await showMenu<EntityTableMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      local & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const PopupMenuDivider(),
        for (final action in shown[i])
          PopupMenuItem<EntityTableMenuAction>(
            value: action,
            enabled: action.enabled,
            child: Text(action.label),
          ),
      ],
    ],
  );
  chosen?.onSelected();
}
```

`EntityTableHeaderCell`: add `final ValueChanged<Offset>? onOpenMenu;` and `final bool isFiltered;` (default false). Wrap the `Positioned.fill` InkWell in

```dart
            child: GestureDetector(
              onSecondaryTapUp: onOpenMenu == null
                  ? null
                  : (d) => onOpenMenu!(d.globalPosition),
              onLongPressStart: onOpenMenu == null
                  ? null
                  : (d) => onOpenMenu!(d.globalPosition),
              child: InkWell(/* unchanged */),
            ),
```

and inside the header `Row`, before the sort icon:

```dart
                    if (isFiltered)
                      Padding(
                        key: ValueKey('entity-table-filtered-${field.name}'),
                        padding: const EdgeInsetsDirectional.only(end: 2),
                        child: Icon(
                          Icons.filter_alt,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                      ),
```

`EntityTableView`: add the four optional fields with doc comments:

```dart
  /// Hides [field]'s column. When set, every header menu offers "Hide
  /// column", disabled on the last column (#2984).
  final void Function(F field)? onHideColumn;

  /// Extra header menu items, shown above "Hide column".
  final EntityTableHeaderMenuBuilder<F>? headerMenuBuilder;

  /// Cell menu items. Null leaves cells with no menu and no long-press
  /// recognizer, as before #2984.
  final EntityTableCellMenuBuilder<T, F>? cellMenuBuilder;

  /// Whether [field]'s column is filtered (shown as a header icon).
  final bool Function(F field)? isColumnFiltered;
```

In the state:

```dart
  bool get _hasHeaderMenu =>
      widget.onHideColumn != null || widget.headerMenuBuilder != null;

  void _openHeaderMenu(BuildContext context, F field, Offset position) {
    // Labels resolve here, never in build, so tables pumped without
    // localizations still build.
    final l10n = context.l10n;
    showEntityTableMenu(
      context,
      position: position,
      sections: [
        widget.headerMenuBuilder?.call(context, field) ?? const [],
        if (widget.onHideColumn != null)
          [
            EntityTableMenuAction(
              label: l10n.tableMode_menu_hideColumn,
              enabled: widget.config.columns.length > 1,
              onSelected: () => widget.onHideColumn!(field),
            ),
          ],
      ],
    );
  }
```

Pass to both header constructions: `isFiltered: widget.isColumnFiltered?.call(col.field) ?? false`, and `onOpenMenu: _hasHeaderMenu ? (pos) => _openHeaderMenu(context, col.field, pos) : null` (the header's `context` comes from a `Builder` around each header cell so the menu anchors in the right overlay). In `_buildCell`, when `widget.cellMenuBuilder != null`, wrap the returned `Container` in:

```dart
      Builder(
        builder: (cellContext) {
          void open(Offset position) => showEntityTableMenu(
            cellContext,
            position: position,
            sections: [widget.cellMenuBuilder!(cellContext, entity, column.field)],
          );
          return GestureDetector(
            onSecondaryTapUp: (d) => open(d.globalPosition),
            onLongPressStart: (d) => open(d.globalPosition),
            child: cell,
          );
        },
      )
```

Notifiers (same body in both, typed for each):

```dart
  /// Removes [field]'s column, pinned or not, unless it is the last one
  /// (#2984); a sort on it is cleared. The column picker adds it back.
  void hideColumn(F field) {
    if (state.columns.length <= 1) return;
    final next = state.columns.where((c) => c.field != field).toList();
    if (next.length == state.columns.length) return;
    state = state.copyWith(
      columns: next,
      clearSortField: state.sortField == field,
    );
    _save();
  }
```

ARB: insert into `app_en.arb` next to the other `tableMode_` keys (anchor on `"tableMode_tooltip_toggleDetailPane"`, keep the group sorted, add its `@` entry beside the group's other metadata):

```json
  "tableMode_menu_hideColumn": "Hide column",
  "@tableMode_menu_hideColumn": {"description": "Table column header menu item that removes the column from the table"},
```

Run `flutter gen-l10n` now only to compile (Task 13 regenerates after the translations go in).

Wire the seven lists: `grep -n "onResizeColumn:" lib/features/*/presentation/widgets/*_list_content.dart` and add beside each one `onHideColumn: <same notifier expression>.hideColumn,` (for `site_list_content.dart` that is `onHideColumn: notifier.hideColumn,`).

- [ ] **Step 4: Run green, plus every table consumer**

Run: `flutter test test/shared/ test/features/buddies/presentation test/features/certifications/presentation test/features/courses/presentation test/features/dive_centers/presentation test/features/dive_sites/presentation test/features/equipment/presentation test/features/trips/presentation test/features/dive_log/presentation/providers`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/ lib/features/*/presentation/widgets/*_list_content.dart lib/features/dive_log/presentation/providers/view_config_providers.dart lib/l10n/arb/app_en.arb test/shared/ test/features/dive_log/presentation/providers/
git commit -m "feat(shared): header and cell menus with Hide column on every table"
```

---

### Task 9: The dive table runs on the shared table

**Files:**
- Rewrite: `lib/features/dive_log/presentation/widgets/dive_table_view.dart`
- Delete: `lib/features/dive_log/presentation/widgets/table_header_cell.dart`
- Modify: `test/features/dive_log/presentation/widgets/dive_table_view_test.dart`, `dive_table_view_sort_test.dart`, `dive_table_view_dive_type_label_test.dart`, `dive_list_content_test.dart` (harness overrides only)
- Test: `test/features/dive_log/presentation/widgets/dive_table_surface_interval_test.dart` (create)

**Interfaces:**
- Consumes: `DiveFieldAdapter`, `toEntityConfig` (Task 5); `diveSurfaceIntervalsProvider` (Task 2); `hideColumn` (Task 8).
- Produces: `DiveTableView` keeps its constructor exactly (so `dive_list_content.dart` is untouched) and becomes a `ConsumerWidget`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/presentation/widgets/dive_table_surface_interval_test.dart
// Harness: copy _TestSettingsNotifier, _TestTableConfigNotifier and the
// testApp wiring from dive_table_view_test.dart.

void main() {
  testWidgets('surface interval shows the computed value, not "--"', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          tableViewConfigProvider.overrideWith(
            (ref) => _TestTableConfigNotifier(
              TableViewConfig(columns: [
                TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
                TableColumnConfig(field: DiveField.surfaceInterval),
              ]),
            ),
          ),
          diveSurfaceIntervalsProvider.overrideWith(
            (ref) async => const {'d2': Duration(minutes: 65)},
          ),
          diveFilterProvider.overrideWith((ref) => const DiveFilterState()),
        ],
        child: DiveTableView(
          dives: [
            Dive(id: 'd1', dateTime: DateTime.utc(2026, 4, 1, 8), diveNumber: 1),
            Dive(id: 'd2', dateTime: DateTime.utc(2026, 4, 1, 11), diveNumber: 2),
          ],
          diveTypeLabelResolver: Dive.diveTypeDisplayName,
          onDiveTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1h 5m'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run red**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_surface_interval_test.dart`
Expected: FAIL, `1h 5m` not found (the old table shows `--`).

- [ ] **Step 3: Rewrite the wrapper**

```dart
// lib/features/dive_log/presentation/widgets/dive_table_view.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

/// The dive list's table (#2984): the shared [EntityTableView] fed by
/// [DiveFieldAdapter] and the dive table's stored config, so scrollbars,
/// resizing and column menus are the same code every list runs.
class DiveTableView extends ConsumerWidget {
  // (fields, doc comments and constructor unchanged from the old widget)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final notifier = ref.read(tableViewConfigProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final intervals =
        ref.watch(diveSurfaceIntervalsProvider).value ??
        const <String, Duration?>{};
    return EntityTableView<Dive, DiveField>(
      entities: dives,
      idExtractor: (d) => d.id,
      adapter: DiveFieldAdapter(
        gasModel: settings.gasModel,
        diveTypeLabel: diveTypeLabelResolver,
        surfaceIntervals: intervals,
      ),
      config: config.toEntityConfig(),
      units: UnitFormatter(settings),
      onSortFieldChanged: notifier.setSortField,
      onResizeColumn: notifier.resizeColumn,
      onHideColumn: notifier.hideColumn,
      onEntityTap: onDiveTap,
      onEntityTapDown: onDiveTapDown,
      onEntityDoubleTap: onDiveDoubleTap,
      selectedIds: selectedIds,
      isSelectionMode: isSelectionMode,
      highlightedId: highlightedId,
    );
  }
}
```

Delete `table_header_cell.dart`; `grep -rn "TableHeaderCell\b\|table_header_cell.dart" lib test` and move any remaining test reference to `EntityTableHeaderCell`.

In the three `dive_table_view*_test.dart` harnesses and `dive_list_content_test.dart`, add to the overrides list:

```dart
      diveSurfaceIntervalsProvider.overrideWith((ref) async => const {}),
```

Tests that found widgets by the old private structure (`find.descendant(of: find.byType(DiveTableView), ...)`) keep working because the wrapper is still the ancestor. A test asserting a behaviour the shared table already pins is kept as is (it now covers the dive wiring).

- [ ] **Step 4: Run green**

Run: `flutter test test/features/dive_log/presentation/ test/shared/widgets/`
Expected: PASS. `rows register no long-press recognizer` still passes (no cell menu yet; Task 12 changes it).

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/dive_log/presentation/widgets/dive_table_view.dart lib/features/dive_log/presentation/widgets/table_header_cell.dart test/features/dive_log/presentation/widgets/
git commit -m "refactor(dive-log): run the dive table on the shared EntityTableView"
```

---

### Task 10: Column to query field map and its census

**Files:**
- Create: `lib/features/dive_log/query/dive_column_filters.dart`
- Test: `test/features/dive_log/query/dive_column_filters_census_test.dart` (create)

**Interfaces:**
- Produces:

```dart
enum DiveColumnFilterKind { relation, multiRelation, number, integer, duration, date, text, enumValue, boolean, headerOnly }
class DiveColumnFilter { const DiveColumnFilter(String key, DiveColumnFilterKind kind, {int decimals = 0}); final String key; final DiveColumnFilterKind kind; final int decimals; FieldPath get path; }
const Map<DiveField, DiveColumnFilter> kDiveColumnFilters;
const Set<DiveField> kUnfilterableDiveColumns;
```

- [ ] **Step 1: Write the failing census**

```dart
// test/features/dive_log/query/dive_column_filters_census_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

void main() {
  test('every column is mapped or explicitly unfilterable, never both', () {
    for (final f in DiveField.values) {
      final mapped = kDiveColumnFilters.containsKey(f);
      final excluded = kUnfilterableDiveColumns.contains(f);
      expect(mapped != excluded, isTrue, reason: '$f');
    }
  });

  test('every mapped key resolves to a field or relation of the right kind', () {
    kDiveColumnFilters.forEach((column, spec) {
      final res = resolvePath(appQueryRegistry, diveQueryEntity, spec.path);
      expect(res.error, isNull, reason: '$column -> ${spec.key}');
      switch (spec.kind) {
        case DiveColumnFilterKind.relation:
        case DiveColumnFilterKind.multiRelation:
          expect(res.terminalRelation, isNotNull, reason: '$column');
        case DiveColumnFilterKind.number:
        case DiveColumnFilterKind.integer:
        case DiveColumnFilterKind.duration:
          expect(res.field?.type, FieldType.number, reason: '$column');
        case DiveColumnFilterKind.date:
          expect(res.field?.type, FieldType.date, reason: '$column');
        case DiveColumnFilterKind.text:
          expect(res.field?.type, FieldType.text, reason: '$column');
        case DiveColumnFilterKind.enumValue:
          expect(res.field?.type, FieldType.enumName, reason: '$column');
        case DiveColumnFilterKind.boolean:
          expect(res.field?.type, FieldType.bool, reason: '$column');
        case DiveColumnFilterKind.headerOnly:
          expect(res.field ?? res.terminalRelation, isNotNull, reason: '$column');
      }
    });
  });

  test('durations are whole minutes, matching how the cell rounds', () {
    for (final e in kDiveColumnFilters.entries.where((e) => e.value.kind == DiveColumnFilterKind.duration)) {
      final res = resolvePath(appQueryRegistry, diveQueryEntity, e.value.path);
      expect(res.field!.dimension, FieldDimension.minutes, reason: '${e.key}');
    }
  });
}
```

- [ ] **Step 2: Run red**

Run: `flutter test test/features/dive_log/query/dive_column_filters_census_test.dart`
Expected: compile FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_log/query/dive_column_filters.dart
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';

/// How a dive table column's menus filter it (#2984).
enum DiveColumnFilterKind {
  /// One related row (site, trip, center, computer).
  relation,

  /// Several related rows (dive types, buddies, tags): With / Without each.
  multiRelation,

  /// A measured number shown rounded to [DiveColumnFilter.decimals].
  number,

  /// A whole number shown as is (dive number, rating, tank count).
  integer,

  /// A Duration shown in whole minutes.
  duration,
  date,
  text,
  enumValue,
  boolean,

  /// Header Add / Reset only: the cell shows something the field does not
  /// read (resolved names, a SAC unit the field may not use, a value the
  /// table never loads), so a cell rule could miss the clicked dive.
  headerOnly,
}

/// The registry field one dive table column filters on.
class DiveColumnFilter {
  const DiveColumnFilter(this.key, this.kind, {this.decimals = 0});

  /// Top-level key in `diveQueryEntity`.
  final String key;
  final DiveColumnFilterKind kind;

  /// Decimal places the cell shows a [DiveColumnFilterKind.number] with,
  /// in the diver's units.
  final int decimals;

  FieldPath get path => FieldPath([key]);
}

/// Every filterable dive table column (#2984). A column in neither this map
/// nor [kUnfilterableDiveColumns] fails the census test.
const Map<DiveField, DiveColumnFilter> kDiveColumnFilters = {
  DiveField.siteName: DiveColumnFilter('site', DiveColumnFilterKind.relation),
  DiveField.tripName: DiveColumnFilter('trip', DiveColumnFilterKind.relation),
  DiveField.diveCenterName: DiveColumnFilter('center', DiveColumnFilterKind.relation),
  DiveField.diveComputerModel: DiveColumnFilter('computer', DiveColumnFilterKind.relation),
  DiveField.diveTypeName: DiveColumnFilter('types', DiveColumnFilterKind.multiRelation),
  DiveField.buddy: DiveColumnFilter('buddies', DiveColumnFilterKind.multiRelation),
  DiveField.tags: DiveColumnFilter('tags', DiveColumnFilterKind.multiRelation),
  DiveField.diveNumber: DiveColumnFilter('diveNumber', DiveColumnFilterKind.integer),
  DiveField.ratingStars: DiveColumnFilter('rating', DiveColumnFilterKind.integer),
  DiveField.tankCount: DiveColumnFilter('gasCount', DiveColumnFilterKind.integer),
  DiveField.maxDepth: DiveColumnFilter('depth', DiveColumnFilterKind.number, decimals: 1),
  DiveField.avgDepth: DiveColumnFilter('avgDepth', DiveColumnFilterKind.number, decimals: 1),
  DiveField.waterTemp: DiveColumnFilter('waterTemp', DiveColumnFilterKind.number, decimals: 1),
  DiveField.airTemp: DiveColumnFilter('airTemp', DiveColumnFilterKind.number, decimals: 1),
  DiveField.visibility: DiveColumnFilter('visibility', DiveColumnFilterKind.number),
  DiveField.totalWeight: DiveColumnFilter('weight', DiveColumnFilterKind.number, decimals: 1),
  DiveField.bottomTime: DiveColumnFilter('bottomTime', DiveColumnFilterKind.duration),
  DiveField.runtime: DiveColumnFilter('runtime', DiveColumnFilterKind.duration),
  DiveField.surfaceInterval: DiveColumnFilter('surfaceInterval', DiveColumnFilterKind.duration),
  DiveField.dateTime: DiveColumnFilter('date', DiveColumnFilterKind.date),
  DiveField.diveName: DiveColumnFilter('name', DiveColumnFilterKind.text),
  DiveField.currentStrength: DiveColumnFilter('currentStrength', DiveColumnFilterKind.enumValue),
  DiveField.entryMethod: DiveColumnFilter('entryMethod', DiveColumnFilterKind.enumValue),
  DiveField.exitMethod: DiveColumnFilter('exitMethod', DiveColumnFilterKind.enumValue),
  DiveField.waterType: DiveColumnFilter('waterType', DiveColumnFilterKind.enumValue),
  DiveField.diveMode: DiveColumnFilter('diveMode', DiveColumnFilterKind.enumValue),
  DiveField.isFavorite: DiveColumnFilter('favorite', DiveColumnFilterKind.boolean),
  DiveField.notes: DiveColumnFilter('notes', DiveColumnFilterKind.headerOnly),
  DiveField.diveMaster: DiveColumnFilter('diveMaster', DiveColumnFilterKind.headerOnly),
  DiveField.sac: DiveColumnFilter('sac', DiveColumnFilterKind.headerOnly),
  DiveField.cnsEnd: DiveColumnFilter('cnsEnd', DiveColumnFilterKind.headerOnly),
  DiveField.otu: DiveColumnFilter('otu', DiveColumnFilterKind.headerOnly),
};

/// Columns with no registry field: their header menu offers only Hide.
const Set<DiveField> kUnfilterableDiveColumns = {
  DiveField.currentDirection, DiveField.swellHeight, DiveField.altitude,
  DiveField.surfacePressure, DiveField.windSpeed, DiveField.cloudCover,
  DiveField.precipitation, DiveField.humidity, DiveField.weatherDescription,
  DiveField.primaryGas, DiveField.diluentGas, DiveField.startPressure,
  DiveField.endPressure, DiveField.rmv, DiveField.gasConsumed,
  DiveField.gradientFactorLow, DiveField.gradientFactorHigh,
  DiveField.decoAlgorithm, DiveField.decoConservatism, DiveField.cnsStart,
  DiveField.setpointLow, DiveField.setpointHigh, DiveField.setpointDeco,
  DiveField.siteLocation, DiveField.siteLatitude, DiveField.siteLongitude,
  DiveField.importSource,
};
```

- [ ] **Step 4: Run green**

Run: `flutter test test/features/dive_log/query/dive_column_filters_census_test.dart`
Expected: PASS. If a key fails to resolve, read `dive_query_entity.dart` for its real key (aliases do not count) and fix the map, not the registry.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/query/dive_column_filters.dart test/features/dive_log/query/dive_column_filters_census_test.dart
git commit -m "feat(dive-log): map dive table columns to query fields"
```

---

### Task 11: Cell filter rules and filter edits (pure)

**Files:**
- Create: `lib/features/dive_log/query/dive_cell_filter_options.dart`
- Create: `lib/features/dive_log/query/dive_column_filter_edits.dart`
- Modify: `lib/features/dive_log/domain/services/dive_participant_names.dart`
- Test: `test/features/dive_log/query/dive_cell_filter_options_test.dart`, `test/features/dive_log/query/dive_column_filter_edits_test.dart` (create)

**Interfaces:**
- Consumes: `kDiveColumnFilters` (Task 10).
- Produces:

```dart
enum CellFilterKind { only, exclude, atLeast, atMost, onOrAfter, onOrBefore, withValue, withoutValue, noValue, anyValue }
class CellFilterOption { const CellFilterOption(CellFilterKind kind, QueryNode rule, {String valueLabel = ''}); }
List<CellFilterOption> diveCellFilterOptions({required DiveField field, required Dive dive, required UnitFormatter units, required UnitPrefs prefs, String Function(String id)? diveTypeLabel, Map<String, Duration?> surfaceIntervals = const {}});
DiveFilterState addDiveTableRule(DiveFilterState filter, QueryNode rule);
DiveFilterState resetDiveColumnFilter(DiveFilterState filter, DiveField field);
bool isDiveColumnFiltered(DiveFilterState filter, DiveField field);
extension on Dive { List<BuddyWithRole> get nonGuideBuddies; }
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/query/dive_column_filter_edits_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';

ConditionNode c(String key, QueryOp op, QueryValue? v) =>
    ConditionNode(FieldPath([key]), op, v);

void main() {
  final site = c('site', QueryOp.eq, const RefValue('s1', 'Salt Pier'));
  final deep = c('depth', QueryOp.gte, const NumberValue(30, null));

  group('addDiveTableRule', () {
    test('an empty query becomes the rule', () {
      expect(addDiveTableRule(const DiveFilterState(), site).query, site);
    });

    test('a single node and the rule are ANDed', () {
      final f = const DiveFilterState().copyWith(query: deep);
      expect(addDiveTableRule(f, site).query, AndNode([deep, site]));
    });

    test('an OR query is kept whole and ANDed, never extended', () {
      final or = OrNode([deep, site]);
      final f = const DiveFilterState().copyWith(query: or);
      final rule = c('rating', QueryOp.gte, const NumberValue(4, null));
      expect(addDiveTableRule(f, rule).query, AndNode([or, rule]));
    });

    test('an equal top-level rule is not added twice', () {
      final f = addDiveTableRule(const DiveFilterState(), site);
      expect(addDiveTableRule(f, site), f);
    });

    test('axes stay as they are, suspended or not', () {
      final f = const DiveFilterState(siteId: 'x').copyWith(axesSuspended: true);
      final next = addDiveTableRule(f, deep);
      expect(next.siteId, 'x');
      expect(next.axesSuspended, isTrue);
    });
  });

  group('resetDiveColumnFilter and isDiveColumnFiltered', () {
    test('removes plain and negated top-level rules on the column only', () {
      final f = const DiveFilterState().copyWith(
        query: AndNode([site, NotNode(c('site', QueryOp.eq, const RefValue('s2', 'Reef'))), deep]),
      );
      expect(isDiveColumnFiltered(f, DiveField.siteName), isTrue);
      final next = resetDiveColumnFilter(f, DiveField.siteName);
      expect(next.query, deep);
      expect(isDiveColumnFiltered(next, DiveField.siteName), isFalse);
      expect(isDiveColumnFiltered(next, DiveField.maxDepth), isTrue);
    });

    test('leaves rules nested in groups alone', () {
      final f = const DiveFilterState().copyWith(query: OrNode([site, deep]));
      expect(isDiveColumnFiltered(f, DiveField.siteName), isFalse);
      expect(resetDiveColumnFilter(f, DiveField.siteName), f);
    });

    test('clears the column axis too', () {
      final f = const DiveFilterState(siteId: 's1', minDepth: 10, maxDepth: 30);
      expect(isDiveColumnFiltered(f, DiveField.siteName), isTrue);
      expect(resetDiveColumnFilter(f, DiveField.siteName).siteId, isNull);
      final depth = resetDiveColumnFilter(f, DiveField.maxDepth);
      expect((depth.minDepth, depth.maxDepth), (null, null));
      expect(depth.siteId, 's1');
    });

    test('an unfilterable column is never filtered', () {
      expect(isDiveColumnFiltered(const DiveFilterState(), DiveField.altitude), isFalse);
    });
  });
}
```

```dart
// test/features/dive_log/query/dive_cell_filter_options_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  const metric = UnitFormatter(AppSettings());
  final imperialSettings = const AppSettings().copyWith(depthUnit: DepthUnit.feet);
  final imperial = UnitFormatter(imperialSettings);
  const feetPrefs = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );
  final base = Dive(id: 'd', dateTime: DateTime.utc(2026, 4, 1, 9));

  List<CellFilterOption> options(DiveField f, Dive d, {UnitFormatter units = metric, UnitPrefs prefs = kMetricPrefs, Map<String, Duration?> si = const {}}) =>
      diveCellFilterOptions(field: f, dive: d, units: units, prefs: prefs, surfaceIntervals: si);

  (double, double) betweenOf(QueryNode n) {
    final items = ((n as ConditionNode).value! as ListValue).items;
    return ((items[0] as NumberValue).value, (items[1] as NumberValue).value);
  }

  test('a site offers Only and Exclude by id', () {
    final d = base.copyWith(site: const DiveSite(id: 's1', name: 'Salt Pier'));
    final o = options(DiveField.siteName, d);
    expect(o.map((x) => x.kind), [CellFilterKind.only, CellFilterKind.exclude]);
    expect(o.first.rule, ConditionNode(FieldPath(['site']), QueryOp.eq, const RefValue('s1', 'Salt Pier')));
    expect(o.last.rule, NotNode(o.first.rule));
    expect(o.first.valueLabel, 'Salt Pier');
  });

  test('an empty cell offers none and any', () {
    final o = options(DiveField.siteName, base);
    expect(o.map((x) => x.kind), [CellFilterKind.noValue, CellFilterKind.anyValue]);
    expect((o.first.rule as ConditionNode).op, QueryOp.isEmpty);
  });

  test('a depth Only keeps the clicked dive inside the displayed step', () {
    final o = options(DiveField.maxDepth, base.copyWith(maxDepth: 23.4167));
    expect(o.map((x) => x.kind), [CellFilterKind.only, CellFilterKind.atLeast, CellFilterKind.atMost]);
    final (lo, hi) = betweenOf(o.first.rule);
    expect(lo, closeTo(23.35, 1e-9));
    expect(hi, closeTo(23.45, 1e-9));
    expect(o.first.valueLabel, metric.formatDepth(23.4167));
  });

  test('imperial depth rounds in feet and still holds the clicked dive', () {
    final o = options(DiveField.maxDepth, base.copyWith(maxDepth: 23.4167), units: imperial, prefs: feetPrefs);
    final (lo, hi) = betweenOf(o.first.rule);
    expect(lo, lessThanOrEqualTo(23.4167));
    expect(hi, greaterThanOrEqualTo(23.4167));
    // 76.8 ft +- 0.05 ft, stored in metres.
    expect(hi - lo, closeTo(0.1 * 0.3048, 1e-9));
    final atLeast = (o[1].rule as ConditionNode).value! as NumberValue;
    expect(atLeast.value, lessThanOrEqualTo(23.4167));
  });

  test('durations use whole minutes', () {
    final o = options(DiveField.bottomTime, base.copyWith(bottomTime: const Duration(minutes: 47, seconds: 50)));
    expect((o.first.rule as ConditionNode).value, const NumberValue(47, null));
  });

  test('surface interval reads the computed map', () {
    final o = options(DiveField.surfaceInterval, base, si: const {'d': Duration(minutes: 65)});
    expect((o.first.rule as ConditionNode).value, const NumberValue(65, null));
  });

  test('a date offers Only, On or after, On or before by day', () {
    final o = options(DiveField.dateTime, base.copyWith(entryTime: DateTime.utc(2026, 4, 1, 9)));
    expect(o.map((x) => x.kind), [CellFilterKind.only, CellFilterKind.onOrAfter, CellFilterKind.onOrBefore]);
    expect((o.first.rule as ConditionNode).value, DateValue(DateTime.utc(2026, 4, 1)));
  });

  test('tags offer With and Without per tag', () {
    // Build two tags with the Tag entity's real constructor.
    final at = DateTime.utc(2026, 1, 1);
    final o = options(
      DiveField.tags,
      base.copyWith(
        tags: [
          Tag(id: 't1', name: 'Night', createdAt: at, updatedAt: at),
          Tag(id: 't2', name: 'Wreck', createdAt: at, updatedAt: at),
        ],
      ),
    );
    expect(o.map((x) => x.kind), [CellFilterKind.withValue, CellFilterKind.withoutValue, CellFilterKind.withValue, CellFilterKind.withoutValue]);
  });

  group('derived display offers no items', () {
    test('runtime derived from timestamps', () {
      final d = base.copyWith(entryTime: DateTime.utc(2026, 4, 1, 9), exitTime: DateTime.utc(2026, 4, 1, 9, 50));
      expect(options(DiveField.runtime, d), isEmpty);
    });

    test('entry method inherited from the site', () {
      final d = base.copyWith(site: const DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.shore));
      expect(options(DiveField.entryMethod, d), isEmpty);
    });

    test('legacy free-text buddy', () {
      expect(options(DiveField.buddy, base.copyWith(buddy: 'Sam')), isEmpty);
    });

    test('legacy visibility bucket', () {
      expect(options(DiveField.visibility, base.copyWith(visibility: Visibility.good)), isEmpty);
    });

    test('a dive name shown from its site', () {
      expect(options(DiveField.diveName, base.copyWith(site: const DiveSite(id: 's', name: 'S'))), isEmpty);
    });
  });

  test('header-only and unfilterable columns offer nothing', () {
    expect(options(DiveField.notes, base.copyWith(notes: 'x')), isEmpty);
    expect(options(DiveField.altitude, base.copyWith(altitude: 300)), isEmpty);
  });
}
```

`Tag`, `Visibility.good` and `AppSettings.copyWith(depthUnit:)` are the real names (checked while planning). `Dive.copyWith` must accept every field the tests set; add any missing one to the test via the `Dive(...)` constructor instead.

- [ ] **Step 2: Run red**

Run: `flutter test test/features/dive_log/query/dive_cell_filter_options_test.dart test/features/dive_log/query/dive_column_filter_edits_test.dart`
Expected: compile FAIL.

- [ ] **Step 3: Implement**

Add to `DiveParticipantNames` in `dive_participant_names.dart`:

```dart
  /// The linked participants [resolvedBuddyNames] lists: no guide or
  /// divemaster role (#2984, the buddy column's cell filters).
  List<BuddyWithRole> get nonGuideBuddies => buddies
      .where((b) => !b.roleIds.any(_guideRoleIds.contains))
      .toList();
```

(import `package:submersion/features/buddies/domain/entities/buddy.dart` if `BuddyWithRole` is not already in scope.)

```dart
// lib/features/dive_log/query/dive_column_filter_edits.dart
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';

/// The top-level AND children of [query], as the filter chips show them.
List<QueryNode> _topLevel(QueryNode? query) => switch (query) {
  null => const [],
  AndNode(:final children) => children,
  final node => [node],
};

QueryNode? _join(List<QueryNode> nodes) => switch (nodes.length) {
  0 => null,
  1 => nodes.single,
  _ => AndNode(nodes),
};

bool _isOnKey(QueryNode node, String key) => switch (node) {
  ConditionNode(:final path) => path.segments.first == key,
  NotNode(:final child) => _isOnKey(child, key),
  _ => false,
};

/// [filter] with [rule] ANDed as a new top-level child (#2984), so it shows
/// as its own removable chip; unchanged when an equal child is there.
DiveFilterState addDiveTableRule(DiveFilterState filter, QueryNode rule) {
  final top = _topLevel(filter.query);
  if (top.contains(rule)) return filter;
  return filter.copyWith(query: _join([...top, rule]));
}

/// [filter] without [field]'s column filter: every top-level rule on its
/// key (plain or negated) and its Refine axis. Rules inside groups stay.
DiveFilterState resetDiveColumnFilter(DiveFilterState filter, DiveField field) {
  final key = kDiveColumnFilters[field]?.key;
  if (key == null) return filter;
  final top = _topLevel(filter.query);
  final kept = top.where((n) => !_isOnKey(n, key)).toList();
  final withoutRules = kept.length == top.length
      ? filter
      : filter.copyWith(query: _join(kept), clearQuery: kept.isEmpty);
  return _clearAxis(withoutRules, field);
}

/// Whether [field]'s column has a top-level rule or its axis set.
bool isDiveColumnFiltered(DiveFilterState filter, DiveField field) {
  final key = kDiveColumnFilters[field]?.key;
  if (key == null) return false;
  return _topLevel(filter.query).any((n) => _isOnKey(n, key)) ||
      _hasAxis(filter, field);
}

bool _hasAxis(DiveFilterState f, DiveField field) => switch (field) {
  DiveField.siteName => f.siteId != null || f.siteIds.isNotEmpty,
  DiveField.tripName => f.tripId != null,
  DiveField.diveCenterName => f.diveCenterId != null,
  DiveField.diveTypeName => f.diveTypeId != null,
  DiveField.diveComputerModel => f.computerId != null,
  DiveField.buddy =>
    f.buddyId != null || f.buddyNameFilter != null || f.noBuddyOnly == true,
  DiveField.tags => f.tagIds.isNotEmpty,
  DiveField.dateTime => f.startDate != null || f.endDate != null,
  DiveField.maxDepth => f.minDepth != null || f.maxDepth != null,
  DiveField.bottomTime =>
    f.minBottomTimeMinutes != null || f.maxBottomTimeMinutes != null,
  DiveField.waterTemp => f.minWaterTemp != null || f.maxWaterTemp != null,
  DiveField.visibility => f.minVisibility != null || f.maxVisibility != null,
  DiveField.ratingStars => f.minRating != null,
  DiveField.isFavorite => f.favoritesOnly == true,
  DiveField.waterType => f.waterTypes.isNotEmpty,
  _ => false,
};

DiveFilterState _clearAxis(DiveFilterState f, DiveField field) => switch (field) {
  DiveField.siteName => f.copyWith(clearSiteId: true, clearSiteIds: true),
  DiveField.tripName => f.copyWith(clearTripId: true),
  DiveField.diveCenterName => f.copyWith(clearDiveCenterId: true),
  DiveField.diveTypeName => f.copyWith(clearDiveType: true),
  DiveField.diveComputerModel => f.copyWith(clearComputerId: true),
  DiveField.buddy => f.copyWith(
    clearBuddyId: true,
    clearBuddyNameFilter: true,
    clearNoBuddyOnly: true,
  ),
  DiveField.tags => f.copyWith(clearTagIds: true),
  DiveField.dateTime => f.copyWith(clearStartDate: true, clearEndDate: true),
  DiveField.maxDepth => f.copyWith(clearMinDepth: true, clearMaxDepth: true),
  DiveField.bottomTime => f.copyWith(
    clearMinBottomTimeMinutes: true,
    clearMaxBottomTimeMinutes: true,
  ),
  DiveField.waterTemp => f.copyWith(clearMinWaterTemp: true, clearMaxWaterTemp: true),
  DiveField.visibility => f.copyWith(clearMinVisibility: true, clearMaxVisibility: true),
  DiveField.ratingStars => f.copyWith(clearMinRating: true),
  DiveField.isFavorite => f.copyWith(clearFavoritesOnly: true),
  DiveField.waterType => f.copyWith(clearWaterTypes: true),
  _ => f,
};
```

If an axis field name above differs in `DiveFilterState` (check with `grep -n "final .* minBottomTimeMinutes\|final .* siteIds\|final .* waterTypes" lib/features/dive_log/domain/models/dive_filter_state.dart`), use the real name.

```dart
// lib/features/dive_log/query/dive_cell_filter_options.dart
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// What a cell menu item does (#2984); the menu words it.
enum CellFilterKind {
  only,
  exclude,
  atLeast,
  atMost,
  onOrAfter,
  onOrBefore,
  withValue,
  withoutValue,
  noValue,
  anyValue,
}

/// One cell menu item: the rule it adds and the value it names.
@immutable
class CellFilterOption {
  const CellFilterOption(this.kind, this.rule, {this.valueLabel = ''});

  final CellFilterKind kind;
  final QueryNode rule;

  /// The value as the cell shows it; empty for noValue and anyValue.
  final String valueLabel;
}

/// The cell menu for [field] on [dive] (#2984).
///
/// Every item is a rule the query engine evaluates on the SAME value the
/// cell displays. Where the cell shows something the field does not read
/// (a runtime derived from timestamps, an entry method inherited from the
/// site, a legacy free-text buddy, a legacy visibility bucket, a dive name
/// shown from its site), there are no items rather than a rule that would
/// drop the dive that was clicked.
List<CellFilterOption> diveCellFilterOptions({
  required DiveField field,
  required Dive dive,
  required UnitFormatter units,
  required UnitPrefs prefs,
  String Function(String id)? diveTypeLabel,
  Map<String, Duration?> surfaceIntervals = const {},
}) {
  final spec = kDiveColumnFilters[field];
  if (spec == null || spec.kind == DiveColumnFilterKind.headerOnly) {
    return const [];
  }
  ConditionNode cond(QueryOp op, QueryValue? v) =>
      ConditionNode(spec.path, op, v);
  final empty = [
    CellFilterOption(CellFilterKind.noValue, cond(QueryOp.isEmpty, null)),
    CellFilterOption(CellFilterKind.anyValue, cond(QueryOp.isSet, null)),
  ];
  final displayed = field.formatValue(
    field == DiveField.surfaceInterval
        ? (surfaceIntervals.containsKey(dive.id)
              ? surfaceIntervals[dive.id]
              : dive.surfaceInterval)
        : field.extractFromDive(
            dive,
            gasModel: units.settings.gasModel,
            diveTypeLabel: diveTypeLabel,
          ),
    units,
  );
  final raw = _queriedValue(field, dive, surfaceIntervals, diveTypeLabel);
  if (raw == null || (raw is List && raw.isEmpty)) {
    return isBlankFieldValue(displayed) ? empty : const [];
  }
  if (isBlankFieldValue(displayed)) return const [];

  List<CellFilterOption> onlyExclude(QueryValue v, String label) => [
    CellFilterOption(CellFilterKind.only, cond(QueryOp.eq, v), valueLabel: label),
    CellFilterOption(
      CellFilterKind.exclude,
      NotNode(cond(QueryOp.eq, v)),
      valueLabel: label,
    ),
  ];
  List<CellFilterOption> ordered(QueryValue only, QueryValue lo, QueryValue hi, String label, {bool dates = false}) => [
    CellFilterOption(CellFilterKind.only, cond(dates ? QueryOp.eq : (only is ListValue ? QueryOp.between : QueryOp.eq), only), valueLabel: label),
    CellFilterOption(dates ? CellFilterKind.onOrAfter : CellFilterKind.atLeast, cond(QueryOp.gte, lo), valueLabel: label),
    CellFilterOption(dates ? CellFilterKind.onOrBefore : CellFilterKind.atMost, cond(QueryOp.lte, hi), valueLabel: label),
  ];

  switch (spec.kind) {
    case DiveColumnFilterKind.relation:
      final ref = raw as RefValue;
      return onlyExclude(ref, ref.label);
    case DiveColumnFilterKind.multiRelation:
      return [
        for (final ref in (raw as List<RefValue>)) ...[
          CellFilterOption(CellFilterKind.withValue, cond(QueryOp.eq, ref), valueLabel: ref.label),
          CellFilterOption(
            CellFilterKind.withoutValue,
            NotNode(cond(QueryOp.eq, ref)),
            valueLabel: ref.label,
          ),
        ],
      ];
    case DiveColumnFilterKind.integer:
      final v = NumberValue((raw as num).toDouble(), null);
      return ordered(v, v, v, displayed);
    case DiveColumnFilterKind.duration:
      final minutes = NumberValue((raw as Duration).inMinutes.toDouble(), null);
      return ordered(minutes, minutes, minutes, displayed);
    case DiveColumnFilterKind.number:
      final dimension = resolvePath(appQueryRegistry, diveQueryEntity, spec.path).field!.dimension;
      final (shown, _) = storageToDisplay((raw as num).toDouble(), null, dimension, prefs);
      final step = math.pow(10, -spec.decimals).toDouble();
      final rounded = (shown / step).round() * step;
      double ground(double v) => groundToStorage(v, null, dimension, prefs);
      final lo = NumberValue(ground(rounded - step / 2), null);
      final hi = NumberValue(ground(rounded + step / 2), null);
      return ordered(ListValue([lo, hi]), lo, hi, displayed);
    case DiveColumnFilterKind.date:
      final day = DateValue(raw as DateTime);
      return ordered(day, day, day, units.formatDate(raw), dates: true);
    case DiveColumnFilterKind.text:
      return onlyExclude(StringValue(raw as String), raw);
    case DiveColumnFilterKind.enumValue:
      return onlyExclude(EnumValue((raw as Enum).name, label: displayed), displayed);
    case DiveColumnFilterKind.boolean:
      return onlyExclude(BoolValue(raw as bool), displayed);
    case DiveColumnFilterKind.headerOnly:
      return const [];
  }
}

/// The value the column's query field reads for [dive], or null when it
/// reads nothing (an empty cell, or a cell showing a derived value).
Object? _queriedValue(
  DiveField field,
  Dive dive,
  Map<String, Duration?> surfaceIntervals,
  String Function(String id)? diveTypeLabel,
) => switch (field) {
  DiveField.siteName => switch (dive.site) {
    null => null,
    final s => RefValue(s.id, s.name),
  },
  DiveField.tripName => switch (dive.trip) {
    null => null,
    final t => RefValue(t.id, t.name),
  },
  DiveField.diveCenterName => switch (dive.diveCenter) {
    null => null,
    final c => RefValue(c.id, c.name),
  },
  DiveField.diveComputerModel => switch (dive.computerId) {
    null => null,
    final id => RefValue(id, dive.diveComputerModel ?? id),
  },
  DiveField.diveTypeName => [
    for (final id in dive.diveTypeIds)
      RefValue(id, (diveTypeLabel ?? Dive.diveTypeDisplayName)(id)),
  ],
  DiveField.buddy => [
    for (final b in dive.nonGuideBuddies) RefValue(b.buddy.id, b.buddy.name),
  ],
  DiveField.tags => [for (final t in dive.tags) RefValue(t.id, t.name)],
  DiveField.diveNumber => dive.diveNumber,
  DiveField.ratingStars => dive.rating,
  DiveField.tankCount => dive.tanks.length,
  DiveField.maxDepth => dive.maxDepth,
  DiveField.avgDepth => dive.avgDepth,
  DiveField.waterTemp => dive.waterTemp,
  DiveField.airTemp => dive.airTemp,
  DiveField.visibility => dive.visibilityMeters,
  DiveField.totalWeight => dive.totalWeight > 0 ? dive.totalWeight : null,
  DiveField.bottomTime => dive.bottomTime,
  DiveField.runtime => dive.runtime,
  DiveField.surfaceInterval =>
    surfaceIntervals.containsKey(dive.id)
        ? surfaceIntervals[dive.id]
        : dive.surfaceInterval,
  DiveField.dateTime => dive.effectiveEntryTime,
  DiveField.diveName => dive.effectiveName,
  DiveField.currentStrength => dive.currentStrength,
  DiveField.entryMethod => dive.entryMethod,
  DiveField.exitMethod => dive.exitMethod,
  DiveField.waterType => dive.effectiveWaterType,
  DiveField.diveMode => dive.diveMode,
  DiveField.isFavorite => dive.isFavorite,
  _ => null,
};
```

Notes for the implementer: the "derived display offers no items" rule falls out of the guard `raw == null && !isBlankFieldValue(displayed)`; a duration that displays `--` (zero minutes) hits `if (isBlankFieldValue(displayed)) return const []`. `Dive.diveTypeDisplayName` is the static the old table test passes as the resolver. If a getter named above is not on `Dive` (`effectiveEntryTime`, `effectiveName`, `effectiveWaterType`, `visibilityMeters`, `computerId`), find the extractor's spelling in `dive_field_extractor.dart` and use it.

- [ ] **Step 4: Run green**

Run: `flutter test test/features/dive_log/query/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/query/ lib/features/dive_log/domain/services/dive_participant_names.dart test/features/dive_log/query/
git commit -m "feat(dive-log): cell filter rules and column filter edits"
```

---

### Task 12: Dive table menus, Add filter flow, Refine panel seeding

**Files:**
- Create: `lib/features/dive_log/presentation/table/dive_table_menus.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_table_view.dart` (menus)
- Modify: `lib/core/query/presentation/query_editor.dart` (`initialTab`)
- Modify: `lib/features/query/presentation/entity_query_editor.dart` (`initialTab`, `readQueryEditorContext`), `dive_query_editor.dart` (`initialTab`)
- Modify: `lib/features/dive_log/presentation/widgets/refine/show_refine_panel.dart`, `refine_panel.dart`, `groups/refine_rules_group.dart`
- Modify: `lib/l10n/arb/app_en.arb` (12 keys)
- Test: `test/features/dive_log/presentation/widgets/dive_table_menus_test.dart` (create)
- Test: `test/features/dive_log/presentation/widgets/refine/refine_panel_seed_test.dart` (create)
- Modify: `test/features/dive_log/presentation/widgets/dive_table_view_test.dart` (the long-press test)

**Interfaces:**
- Consumes: Tasks 8, 10, 11.
- Produces: `showRefinePanel(context, {required filterProvider, VoidCallback? onApplied, DiveFilterState? initialDraft, bool startOnRulesBuilder = false})`; `RefinePanel({required filterProvider, onApplied, DiveFilterState? initialDraft, bool startOnRulesBuilder = false})`; `QueryEditor(..., int initialTab = 0)`; `QueryEditorContext readQueryEditorContext(BuildContext context, WidgetRef ref, QueryEntity root)`; in `dive_table_menus.dart`: `List<EntityTableMenuAction> diveHeaderMenuItems(BuildContext, WidgetRef, DiveField)`, `List<EntityTableMenuAction> diveCellMenuItems(BuildContext, WidgetRef, Dive, DiveField, {required String Function(String) diveTypeLabel, required Map<String, Duration?> surfaceIntervals})`, `String cellFilterLabel(AppLocalizations, CellFilterOption, DiveField)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/presentation/widgets/dive_table_menus_test.dart
// Harness: as dive_table_surface_interval_test.dart (Task 9), with a real
// diveFilterProvider (no override) so the test can read what a menu wrote:
//   final container = ProviderScope.containerOf(tester.element(find.byType(DiveTableView)));

void main() {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 4, 1, 9),
    diveNumber: 7,
    maxDepth: 23.4167,
    site: const DiveSite(id: 's1', name: 'Salt Pier'),
  );

  testWidgets('right-click a site cell, Only Salt Pier adds the rule', (tester) async {
    await pumpDiveTable(tester, [dive]);
    await tester.tap(find.text('Salt Pier'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only Salt Pier'));
    await tester.pumpAndSettle();
    final query = container(tester).read(diveFilterProvider).query;
    expect(query, ConditionNode(FieldPath(['site']), QueryOp.eq, const RefValue('s1', 'Salt Pier')));
  });

  testWidgets('long-press on a cell opens the filter menu, not selection', (tester) async {
    var tapped = 0;
    await pumpDiveTable(tester, [dive], onDiveTap: (_) => tapped++);
    await tester.longPress(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(find.text('Exclude Salt Pier'), findsOneWidget);
    expect(tapped, 0);
  });

  testWidgets('a filtered column shows the indicator and Reset clears it', (tester) async {
    await pumpDiveTable(tester, [dive]);
    container(tester).read(diveFilterProvider.notifier).state = const DiveFilterState(siteId: 's1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entity-table-filtered-siteName')), findsOneWidget);
    await tester.tap(find.text('Site'), buttons: kSecondaryButton); // header label for siteName
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();
    expect(container(tester).read(diveFilterProvider).siteId, isNull);
    expect(find.byKey(const ValueKey('entity-table-filtered-siteName')), findsNothing);
  });

  testWidgets('an unfilterable column header offers only Hide column', (tester) async {
    await pumpDiveTable(tester, [dive], columns: [DiveField.diveNumber, DiveField.altitude]);
    await tester.tap(find.text(DiveField.altitude.displayName), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Add filter'), findsNothing);
    expect(find.text('Hide column'), findsOneWidget);
  });
}
```

Use the header label the table actually renders (`EntityTableHeaderCell` shows `localizedDisplayName`), read it from `DiveField.siteName.localizedDisplayName(AppLocalizations of en)` if "Site" is not the exact string.

```dart
// test/features/dive_log/presentation/widgets/refine/refine_panel_seed_test.dart
// Pump showRefinePanel from a button inside testApp, with the overrides the
// existing refine panel tests use (grep test/features/dive_log/presentation/widgets/refine/ for their harness).

void main() {
  testWidgets('a seeded draft opens the Rules group on the Builder tab', (tester) async {
    final rule = ConditionNode(FieldPath(['depth']), QueryOp.gte, const NumberValue(30, null));
    await pumpAndOpen(tester, initialDraft: const DiveFilterState().copyWith(query: rule), startOnRulesBuilder: true);
    final tabs = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(tabs.controller!.index, 1);
    // Cancel leaves the live filter untouched.
    await tester.tap(find.byKey(kRefineCancelKey));
    await tester.pumpAndSettle();
    expect(liveFilter(tester).query, isNull);
  });
}
```

Change the old `rows register no long-press recognizer` test in `dive_table_view_test.dart` to assert the new contract: a cell's long-press opens the filter menu and never calls `onDiveTap` (the menu test above), and keep the original "no long-press without a cell builder" guarantee in `entity_table_menu_test.dart` (Task 8). Rename it `rows register long-press only for the cell filter menu` and assert that every `RawGestureDetector` carrying a `LongPressGestureRecognizer` is a descendant of a cell, not of the row's `GestureDetector` with `onTap`.

- [ ] **Step 2: Run red**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_menus_test.dart test/features/dive_log/presentation/widgets/refine/refine_panel_seed_test.dart`
Expected: FAIL (no menu items; `initialDraft` unknown).

- [ ] **Step 3: Implement**

`QueryEditor`: add `this.initialTab = 0` and `final int initialTab;`, and initialize `late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);`. Thread `int initialTab = 0` through `EntityQueryEditor` and `DiveQueryEditor` to it.

In `entity_query_editor.dart`, extract the context construction:

```dart
/// The editor context for [root], read once (for an action) rather than
/// watched (#2984: the dive table's Add filter builds a rule with it).
QueryEditorContext readQueryEditorContext(
  BuildContext context,
  WidgetRef ref,
  QueryEntity root,
) => QueryEditorContext(
  registry: appQueryRegistry,
  root: root,
  prefs: ref.read(queryUnitPrefsProvider),
  names: ref.read(queryNameIndexProvider).value ?? NameIndex.empty,
  labels: AppQueryLabels(context),
  now: DateTime.now,
);
```

`RefineRulesGroup`: add `this.startOnBuilder = false` and pass `initialTab: startOnBuilder ? 1 : 0` to `DiveQueryEditor`. `RefinePanel`: add `this.initialDraft` and `this.startOnRulesBuilder = false`; `initState` uses `_draft = widget.initialDraft ?? ref.read(widget.filterProvider);`; pass `startOnBuilder: widget.startOnRulesBuilder` to the Rules group. `showRefinePanel`: add the two parameters and pass them to `RefinePanel`.

```dart
// lib/features/dive_log/presentation/table/dive_table_menus.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/show_refine_panel.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

/// Header menu items for a dive column (#2984): Add filter and Reset
/// filter on a filterable column, nothing on the rest (the table adds Hide).
List<EntityTableMenuAction> diveHeaderMenuItems(
  BuildContext context,
  WidgetRef ref,
  DiveField field,
) {
  if (!kDiveColumnFilters.containsKey(field)) return const [];
  final l10n = context.l10n;
  final filter = ref.read(diveFilterProvider);
  return [
    EntityTableMenuAction(
      label: l10n.tableMode_menu_addFilter,
      onSelected: () => _addColumnFilter(context, ref, field),
    ),
    EntityTableMenuAction(
      label: l10n.tableMode_menu_resetFilter,
      enabled: isDiveColumnFiltered(filter, field),
      onSelected: () => ref.read(diveFilterProvider.notifier).state =
          resetDiveColumnFilter(ref.read(diveFilterProvider), field),
    ),
  ];
}

/// Cell menu items for [dive] in [field]'s column; each applies at once.
List<EntityTableMenuAction> diveCellMenuItems(
  BuildContext context,
  WidgetRef ref,
  Dive dive,
  DiveField field, {
  required String Function(String id) diveTypeLabel,
  required Map<String, Duration?> surfaceIntervals,
}) {
  final l10n = context.l10n;
  final options = diveCellFilterOptions(
    field: field,
    dive: dive,
    units: UnitFormatter(ref.read(settingsProvider)),
    prefs: ref.read(queryUnitPrefsProvider),
    diveTypeLabel: diveTypeLabel,
    surfaceIntervals: surfaceIntervals,
  );
  return [
    for (final o in options)
      EntityTableMenuAction(
        label: cellFilterLabel(l10n, o, field),
        onSelected: () => ref.read(diveFilterProvider.notifier).state =
            addDiveTableRule(ref.read(diveFilterProvider), o.rule),
      ),
  ];
}

/// How a cell menu words [option].
String cellFilterLabel(
  AppLocalizations l10n,
  CellFilterOption option,
  DiveField field,
) {
  final v = option.valueLabel;
  final column = field.localizedDisplayName(l10n);
  return switch (option.kind) {
    CellFilterKind.only => l10n.tableMode_cell_only(v),
    CellFilterKind.exclude => l10n.tableMode_cell_exclude(v),
    CellFilterKind.atLeast => l10n.tableMode_cell_atLeast(v),
    CellFilterKind.atMost => l10n.tableMode_cell_atMost(v),
    CellFilterKind.onOrAfter => l10n.tableMode_cell_onOrAfter(v),
    CellFilterKind.onOrBefore => l10n.tableMode_cell_onOrBefore(v),
    CellFilterKind.withValue => l10n.tableMode_cell_with(v),
    CellFilterKind.withoutValue => l10n.tableMode_cell_without(v),
    CellFilterKind.noValue => l10n.tableMode_cell_noValue(column),
    CellFilterKind.anyValue => l10n.tableMode_cell_anyValue(column),
  };
}

/// Add filter: a default rule for the column (a relation asks for its row
/// first, as the builder's Add condition does), then the Refine panel with
/// that rule in its draft, on the Builder tab. Show applies; dismiss drops.
Future<void> _addColumnFilter(
  BuildContext context,
  WidgetRef ref,
  DiveField field,
) async {
  final spec = kDiveColumnFilters[field]!;
  final editor = readQueryEditorContext(context, ref, diveQueryEntity);
  final target = resolvePath(editor.registry, editor.root, spec.path);
  final op = opsFor(target).first;
  final QueryNode rule;
  final relation = target.terminalRelation;
  if (relation != null) {
    final strings = queryBuilderStringsOf(context.l10n);
    final picked = await showQueryRefPicker(
      context,
      editor: editor,
      kind: relation.target,
      title: strings.pickRef.replaceAll(
        '{name}',
        editor.labels.relation(relation),
      ),
      searchHint: strings.pickRefSearch,
    );
    if (picked == null || !context.mounted) return;
    rule = ConditionNode(spec.path, op, picked);
  } else {
    rule = ConditionNode(spec.path, op, defaultValueFor(target, op, editor));
  }
  await showRefinePanel(
    context,
    filterProvider: diveFilterProvider,
    initialDraft: addDiveTableRule(ref.read(diveFilterProvider), rule),
    startOnRulesBuilder: true,
  );
}
```

In `DiveTableView.build` add `final filter = ref.watch(diveFilterProvider);` and pass:

```dart
      headerMenuBuilder: (context, field) =>
          diveHeaderMenuItems(context, ref, field),
      cellMenuBuilder: (context, dive, field) => diveCellMenuItems(
        context,
        ref,
        dive,
        field,
        diveTypeLabel: diveTypeLabelResolver,
        surfaceIntervals: intervals,
      ),
      isColumnFiltered: (field) => isDiveColumnFiltered(filter, field),
```

ARB (`app_en.arb`, inserted after `tableMode_menu_hideColumn`, keep the `tableMode_` group sorted, each with an `@` entry whose `placeholders` declares `value` or `column` as `{"type": "String"}`):

| Key | English |
| --- | --- |
| `tableMode_menu_addFilter` | `Add filter` |
| `tableMode_menu_resetFilter` | `Reset filter` |
| `tableMode_cell_only` | `Only {value}` |
| `tableMode_cell_exclude` | `Exclude {value}` |
| `tableMode_cell_atLeast` | `At least {value}` |
| `tableMode_cell_atMost` | `At most {value}` |
| `tableMode_cell_onOrAfter` | `On or after {value}` |
| `tableMode_cell_onOrBefore` | `On or before {value}` |
| `tableMode_cell_with` | `With {value}` |
| `tableMode_cell_without` | `Without {value}` |
| `tableMode_cell_noValue` | `Only dives with no {column}` |
| `tableMode_cell_anyValue` | `Only dives with a {column}` |

Run `flutter gen-l10n` to compile (regenerated again in Task 13).

- [ ] **Step 4: Run green**

Run: `flutter test test/features/dive_log/ test/features/query/ test/core/query/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ test/ 
git status --short   # confirm only this task's files are staged
git commit -m "feat(dive-log): column and cell filter menus on the dive table"
```

---

### Task 13: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: Insert the translations by anchor**

Write a `python3.14` script in the scratchpad that, for each locale file, finds the line of `"tableMode_tooltip_toggleDetailPane"` (confirm it exists in all eleven files first with `grep -c`), inserts the 13 new lines after it as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, writes the file, and `json.loads` it to prove it parses. Never json round-trip a file. Match each locale's neighbouring `tableMode_` and dive-log wording for "dive" and accents before finalizing.

| Key | de | es | fr | it | nl |
| --- | --- | --- | --- | --- | --- |
| hideColumn | Spalte ausblenden | Ocultar columna | Masquer la colonne | Nascondi colonna | Kolom verbergen |
| addFilter | Filter hinzufügen | Añadir filtro | Ajouter un filtre | Aggiungi filtro | Filter toevoegen |
| resetFilter | Filter zurücksetzen | Restablecer filtro | Réinitialiser le filtre | Reimposta filtro | Filter wissen |
| only | Nur {value} | Solo {value} | Uniquement {value} | Solo {value} | Alleen {value} |
| exclude | {value} ausschließen | Excluir {value} | Exclure {value} | Escludi {value} | {value} uitsluiten |
| atLeast | Mindestens {value} | Al menos {value} | Au moins {value} | Almeno {value} | Minstens {value} |
| atMost | Höchstens {value} | Como máximo {value} | Au plus {value} | Al massimo {value} | Hoogstens {value} |
| onOrAfter | Ab {value} | Desde {value} | À partir du {value} | Dal {value} | Vanaf {value} |
| onOrBefore | Bis {value} | Hasta {value} | Jusqu'au {value} | Fino al {value} | Tot en met {value} |
| with | Mit {value} | Con {value} | Avec {value} | Con {value} | Met {value} |
| without | Ohne {value} | Sin {value} | Sans {value} | Senza {value} | Zonder {value} |
| noValue | Nur Tauchgänge ohne {column} | Solo inmersiones sin {column} | Uniquement les plongées sans {column} | Solo immersioni senza {column} | Alleen duiken zonder {column} |
| anyValue | Nur Tauchgänge mit {column} | Solo inmersiones con {column} | Uniquement les plongées avec {column} | Solo immersioni con {column} | Alleen duiken met {column} |

| Key | pt | hu | ar | he | zh |
| --- | --- | --- | --- | --- | --- |
| hideColumn | Ocultar coluna | Oszlop elrejtése | إخفاء العمود | הסתר עמודה | 隐藏列 |
| addFilter | Adicionar filtro | Szűrő hozzáadása | إضافة عامل تصفية | הוסף מסנן | 添加筛选 |
| resetFilter | Redefinir filtro | Szűrő visszaállítása | إعادة تعيين عامل التصفية | אפס מסנן | 重置筛选 |
| only | Apenas {value} | Csak {value} | {value} فقط | רק {value} | 仅 {value} |
| exclude | Excluir {value} | {value} kizárása | استبعاد {value} | החרג את {value} | 排除 {value} |
| atLeast | Pelo menos {value} | Legalább {value} | {value} على الأقل | לפחות {value} | 至少 {value} |
| atMost | No máximo {value} | Legfeljebb {value} | {value} على الأكثر | לכל היותר {value} | 至多 {value} |
| onOrAfter | A partir de {value} | {value} vagy később | في {value} أو بعده | החל מ-{value} | {value} 及之后 |
| onOrBefore | Até {value} | {value} vagy korábban | في {value} أو قبله | עד {value} | {value} 及之前 |
| with | Com {value} | Ezzel: {value} | مع {value} | עם {value} | 包含 {value} |
| without | Sem {value} | Enélkül: {value} | بدون {value} | בלי {value} | 不含 {value} |
| noValue | Apenas mergulhos sem {column} | Csak {column} nélküli merülések | الغطسات التي ليس لها {column} فقط | רק צלילות ללא {column} | 仅显示无{column}的潜水 |
| anyValue | Apenas mergulhos com {column} | Csak {column} értékkel rendelkező merülések | الغطسات التي لها {column} فقط | רק צלילות עם {column} | 仅显示有{column}的潜水 |

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n`, then `git diff --numstat -- lib/l10n/arb/*.arb` (every locale ARB: 13 added, 0 removed), then `grep -A1 "get tableMode_menu_hideColumn" lib/l10n/arb/app_localizations_de.dart` (shows the German), then `flutter test test/l10n/`.
Expected: equal numstat rows, translated getters, PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(dive-log): translate the table menu strings"
```

---

### Task 14: Full verification

- [ ] **Step 1:** `dart format .` and `flutter analyze` (clean).
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/core/ test/features/dive_log/ test/features/insights/ test/features/query/ test/l10n/` plus the seven list feature test folders from Task 8.
- [ ] **Step 3:** `wc -l` every file created or modified under `lib/` is under 800 (except the pre-existing `dive_list_content.dart` and `dive_repository_impl.dart`, which must not have grown by more than the batch method).
- [ ] **Step 4:** Commit any formatting fallout as `chore: format`.
