# Filterable Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver scope the entire Statistics tab (Overview totals + all category pages) by the full existing dive-list filter — tags, date range, type, site, depth, rating, gas, etc. — via a reused filter sheet, with a clear active-filter indicator.

**Architecture:** A pure `buildFilteredDiveIdSubquery(DiveFilterState)` helper emits a self-contained `SELECT id FROM dives WHERE …` predicate mirroring `DiveFilterState.apply()`. Each of the ~32 statistics SQL aggregates appends one uniform `AND <alias>.id IN (<subquery>)` clause (no-op when the filter is empty). An independent `statisticsFilterProvider` drives a *new* `filteredDiveStatisticsProvider` and every advanced stats provider, leaving the shared `diveStatisticsProvider` (home dashboard) untouched. The existing `DiveFilterSheet` is extracted to its own file and parameterized by target provider.

**Tech Stack:** Flutter 3.x, Drift ORM (raw `customSelect` SQL), Riverpod (`StateProvider`, `FutureProvider`), Material 3.

## Global Constraints

- The dive repository class is named `DiveRepository` (in `lib/features/dive_log/data/repositories/dive_repository_impl.dart`) — NOT `DiveRepositoryImpl`.
- `dives.dive_date_time` is a Unix epoch in **milliseconds**, stored **wall-clock-as-UTC** (write path: `dive.dateTime.millisecondsSinceEpoch`). The helper's date→ms conversion MUST mirror the dive repository's existing dive-list SQL date filter so on-device dates filter identically (Task 1 Step 6 confirms this by grepping the dive repo). The parity test guards the truncation and end-day-inclusivity logic, not the timezone frame.
- `dives.bottom_time` / `runtime` are **seconds**. Minute filters use integer division `bottom_time / 60` to mirror `Duration.inMinutes` truncation.
- Junction/column truth: tags `dive_tags(dive_id, tag_id)`; types `dive_dive_types(dive_id, dive_type_id)`; equipment `dive_equipment(dive_id, equipment_id)`; tanks `dive_tanks.o2_percent`; custom fields `dive_custom_fields(field_key, field_value)`; `dives.is_favorite` (0/1), `dives.dive_center_id`, `dives.dive_computer_serial`, `dives.rating`.
- Tests: build the in-memory DB via `setUpTestDatabase()` from `test/helpers/test_database.dart`; this enables FK=ON automatically. Insert parents (divers/sites/tags) before children (dives/junctions). Repos are no-arg (`StatisticsRepository()`, `DiveRepository()`).
- Drift test import uses `import 'package:drift/drift.dart' hide isNull, isNotNull;`.
- No emojis in code, comments, or docs.
- New user-facing strings go through l10n and must be translated into all 10 non-en locales and regenerated (see Task 12).
- Run `dart format .` (whole repo) and whole-project `flutter analyze` before the final commit.
- Commit steps in this plan are pre-authorized by plan approval + task execution.

## File Structure

**Create:**
- `lib/features/statistics/data/dive_filter_sql.dart` — pure `buildFilteredDiveIdSubquery(DiveFilterState)`; the single source of filter→SQL truth.
- `lib/features/statistics/presentation/providers/statistics_filter_provider.dart` — `statisticsFilterProvider` (`StateProvider<DiveFilterState>`).
- `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` — the extracted, provider-parameterized `DiveFilterSheet`.
- `lib/features/statistics/presentation/widgets/statistics_filter_bar.dart` — active-filter summary bar (description + dive count + clear).
- Tests: `test/features/statistics/data/dive_filter_sql_test.dart`, `test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`, `test/features/statistics/data/repositories/statistics_repository_filter_test.dart`, `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`, `test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`.

**Modify:**
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — `getStatistics` gains `filter`.
- `lib/features/statistics/data/repositories/statistics_repository.dart` — private `_diveFilter` helper + `filter` param threaded into all 32 methods.
- `lib/features/statistics/presentation/providers/statistics_providers.dart` — `filteredDiveStatisticsProvider`; every advanced provider watches + passes the filter.
- `lib/features/statistics/presentation/pages/statistics_page.dart`, `.../widgets/statistics_list_content.dart` — convert to `ConsumerWidget`; filter icon + summary bar.
- `lib/features/statistics/presentation/pages/statistics_overview_page.dart` — switch line 22 to `filteredDiveStatisticsProvider`.
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`, `.../widgets/dive_list_content.dart` — import extracted sheet; call sites unchanged in behavior.
- `lib/l10n/*.arb` — new strings.

---

## Task 1: `DiveFilterSql` helper + behavioral tests

**Files:**
- Create: `lib/features/statistics/data/dive_filter_sql.dart`
- Test: `test/features/statistics/data/dive_filter_sql_test.dart`

**Interfaces:**
- Produces: `({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(DiveFilterState filter)` — `subquery` is `SELECT id FROM dives WHERE …` (or `''` when no active axes); `params` are raw bind values in `?` order.

- [ ] **Step 1: Write the failing test (harness + empty + a few axes)**

Create `test/features/statistics/data/dive_filter_sql_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertDive(
    String id, {
    DateTime? date,
    String? siteId,
    double? maxDepth,
    int? rating,
    int? bottomTimeSeconds,
    bool favorite = false,
  }) async {
    await db.into(db.dives).insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value((date ?? DateTime(2026, 6, 1)).millisecondsSinceEpoch),
            siteId: Value(siteId),
            maxDepth: Value(maxDepth),
            rating: Value(rating),
            bottomTime: Value(bottomTimeSeconds),
            isFavorite: Value(favorite),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSite(String id) async {
    await db.into(db.diveSites).insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertTag(String id) async {
    await db.into(db.tags).insert(
          TagsCompanion(
            id: Value(id),
            name: Value('Tag $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkTag(String diveId, String tagId) async {
    await db.into(db.diveTags).insert(
          DiveTagsCompanion(
            id: Value('$diveId-$tagId'),
            diveId: Value(diveId),
            tagId: Value(tagId),
            createdAt: Value(now),
          ),
        );
  }

  Future<Set<String>> idsMatching(DiveFilterState filter) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final sql = f.subquery.isEmpty ? 'SELECT id FROM dives' : f.subquery;
    final rows = await db
        .customSelect(sql, variables: f.params.map((p) => Variable(p)).toList())
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('empty filter is a no-op (returns all dives)', () async {
    await insertDive('a');
    await insertDive('b');
    final f = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(f.subquery, '');
    expect(f.params, isEmpty);
    expect(await idsMatching(const DiveFilterState()), {'a', 'b'});
  });

  test('date range filters inclusively through the end day', () async {
    await insertDive('before', date: DateTime(2026, 1, 1));
    await insertDive('inside', date: DateTime(2026, 6, 15));
    await insertDive('endday', date: DateTime(2026, 6, 30, 23, 0));
    await insertDive('after', date: DateTime(2026, 8, 1));
    final filter = DiveFilterState(
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 30),
    );
    expect(await idsMatching(filter), {'inside', 'endday'});
  });

  test('tag filter matches ANY selected tag', () async {
    await insertDive('a');
    await insertDive('b');
    await insertDive('c');
    await insertTag('dry');
    await insertTag('night');
    await linkTag('a', 'dry');
    await linkTag('b', 'night');
    expect(await idsMatching(const DiveFilterState(tagIds: ['dry'])), {'a'});
    expect(await idsMatching(const DiveFilterState(tagIds: ['dry', 'night'])),
        {'a', 'b'});
  });

  test('site, depth, rating, favorites axes', () async {
    await insertSite('s1');
    await insertDive('a', siteId: 's1', maxDepth: 30, rating: 5, favorite: true);
    await insertDive('b', maxDepth: 10, rating: 2);
    expect(await idsMatching(const DiveFilterState(siteId: 's1')), {'a'});
    expect(await idsMatching(const DiveFilterState(minDepth: 20)), {'a'});
    expect(await idsMatching(const DiveFilterState(minRating: 4)), {'a'});
    expect(await idsMatching(const DiveFilterState(favoritesOnly: true)), {'a'});
  });

  test('bottom-time filter truncates to whole minutes like Duration.inMinutes',
      () async {
    // 149s = 2 min (truncated); with maxBottomTimeMinutes: 2 it must pass.
    await insertDive('short', bottomTimeSeconds: 149);
    await insertDive('long', bottomTimeSeconds: 600);
    expect(await idsMatching(const DiveFilterState(maxBottomTimeMinutes: 2)),
        {'short'});
    expect(await idsMatching(const DiveFilterState(minBottomTimeMinutes: 5)),
        {'long'});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/dive_filter_sql_test.dart`
Expected: FAIL — `dive_filter_sql.dart` / `buildFilteredDiveIdSubquery` do not exist (compile error).

- [ ] **Step 3: Implement the helper**

Create `lib/features/statistics/data/dive_filter_sql.dart`:

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Builds a self-contained SQL subquery `SELECT id FROM dives WHERE ...` that
/// selects the ids of all dives matching [filter], mirroring
/// [DiveFilterState.apply] semantics exactly.
///
/// [params] are raw bind values (ints/strings/doubles) in the same order as
/// the `?` placeholders in [subquery]. Returns an empty no-op
/// (`subquery: ''`, `params: []`) when the filter has no translatable active
/// axes, so callers can skip injecting anything.
({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(
  DiveFilterState filter,
) {
  final conditions = <String>[];
  final params = <Object?>[];

  // Date range. dive_date_time is epoch MILLISECONDS (wall-clock-as-UTC).
  if (filter.startDate != null) {
    conditions.add('dive_date_time >= ?');
    params.add(filter.startDate!.millisecondsSinceEpoch);
  }
  if (filter.endDate != null) {
    // apply() keeps dives up to endDate + 1 day (inclusive of the end day).
    conditions.add('dive_date_time <= ?');
    params.add(
      filter.endDate!.add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
  }

  // Dive type: membership against the many-to-many junction.
  if (filter.diveTypeId != null) {
    conditions.add(
      'id IN (SELECT dive_id FROM dive_dive_types WHERE dive_type_id = ?)',
    );
    params.add(filter.diveTypeId);
  }

  if (filter.siteId != null) {
    conditions.add('site_id = ?');
    params.add(filter.siteId);
  }
  if (filter.tripId != null) {
    conditions.add('trip_id = ?');
    params.add(filter.tripId);
  }
  if (filter.diveCenterId != null) {
    conditions.add('dive_center_id = ?');
    params.add(filter.diveCenterId);
  }

  // Tags: match ANY selected tag.
  if (filter.tagIds.isNotEmpty) {
    final ph = List.filled(filter.tagIds.length, '?').join(', ');
    conditions.add('id IN (SELECT dive_id FROM dive_tags WHERE tag_id IN ($ph))');
    params.addAll(filter.tagIds);
  }

  // Equipment: match ANY selected item.
  if (filter.equipmentIds.isNotEmpty) {
    final ph = List.filled(filter.equipmentIds.length, '?').join(', ');
    conditions.add(
      'id IN (SELECT dive_id FROM dive_equipment WHERE equipment_id IN ($ph))',
    );
    params.addAll(filter.equipmentIds);
  }

  // Depth: null depth excluded when a bound is set.
  if (filter.minDepth != null) {
    conditions.add('max_depth IS NOT NULL AND max_depth >= ?');
    params.add(filter.minDepth);
  }
  if (filter.maxDepth != null) {
    conditions.add('max_depth IS NOT NULL AND max_depth <= ?');
    params.add(filter.maxDepth);
  }

  if (filter.favoritesOnly == true) {
    conditions.add('is_favorite = 1');
  }

  // Buddy free-text: case-insensitive substring.
  if (filter.buddyNameFilter != null && filter.buddyNameFilter!.isNotEmpty) {
    conditions.add(
      "buddy IS NOT NULL AND LOWER(buddy) LIKE '%' || LOWER(?) || '%'",
    );
    params.add(filter.buddyNameFilter);
  }

  if (filter.diveIds.isNotEmpty) {
    final ph = List.filled(filter.diveIds.length, '?').join(', ');
    conditions.add('id IN ($ph)');
    params.addAll(filter.diveIds);
  }

  // Gas O2: ANY tank within the present bounds (dives with no tanks excluded).
  if (filter.minO2Percent != null || filter.maxO2Percent != null) {
    final tankConds = <String>[];
    if (filter.minO2Percent != null) {
      tankConds.add('o2_percent >= ?');
      params.add(filter.minO2Percent);
    }
    if (filter.maxO2Percent != null) {
      tankConds.add('o2_percent <= ?');
      params.add(filter.maxO2Percent);
    }
    conditions.add(
      'id IN (SELECT dive_id FROM dive_tanks WHERE ${tankConds.join(' AND ')})',
    );
  }

  if (filter.minRating != null) {
    conditions.add('rating IS NOT NULL AND rating >= ?');
    params.add(filter.minRating);
  }

  // Bottom time: compare truncated whole minutes, mirroring Duration.inMinutes.
  if (filter.minBottomTimeMinutes != null) {
    conditions.add('bottom_time IS NOT NULL AND bottom_time / 60 >= ?');
    params.add(filter.minBottomTimeMinutes);
  }
  if (filter.maxBottomTimeMinutes != null) {
    conditions.add('bottom_time IS NOT NULL AND bottom_time / 60 <= ?');
    params.add(filter.maxBottomTimeMinutes);
  }

  if (filter.computerSerial != null) {
    conditions.add('dive_computer_serial = ?');
    params.add(filter.computerSerial);
  }

  // Custom fields: key match + optional value substring.
  if (filter.customFieldKey != null && filter.customFieldKey!.isNotEmpty) {
    if (filter.customFieldValue != null &&
        filter.customFieldValue!.isNotEmpty) {
      conditions.add(
        "id IN (SELECT dive_id FROM dive_custom_fields "
        "WHERE field_key = ? AND LOWER(field_value) LIKE '%' || LOWER(?) || '%')",
      );
      params.add(filter.customFieldKey);
      params.add(filter.customFieldValue);
    } else {
      conditions.add(
        'id IN (SELECT dive_id FROM dive_custom_fields WHERE field_key = ?)',
      );
      params.add(filter.customFieldKey);
    }
  }

  if (conditions.isEmpty) {
    return (subquery: '', params: const <Object?>[]);
  }
  return (
    subquery: 'SELECT id FROM dives WHERE ${conditions.join(' AND ')}',
    params: params,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/dive_filter_sql_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Add the apply()-vs-SQL parity test (guards the two subtle axes)**

Append to the test file's `main()`:

```dart
  test('parity: apply() and the subquery agree on date + bottom-time edges',
      () async {
    // Build domain dives and matching DB rows, then assert both filter paths
    // return the same ids for the same filter.
    final cases = <(String, DateTime, int)>[
      ('a', DateTime(2026, 6, 30, 23, 0), 149),
      ('b', DateTime(2026, 7, 2), 600),
      ('c', DateTime(2026, 5, 1), 61),
    ];
    for (final (id, date, bt) in cases) {
      await db.into(db.dives).insert(DivesCompanion(
            id: Value(id),
            diveDateTime: Value(date.millisecondsSinceEpoch),
            bottomTime: Value(bt),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));
    }
    final domainDives = cases
        .map((c) => Dive(
              id: c.$1,
              dateTime: c.$2,
              bottomTime: Duration(seconds: c.$3),
            ))
        .toList();

    for (final filter in <DiveFilterState>[
      DiveFilterState(startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 6, 30)),
      const DiveFilterState(maxBottomTimeMinutes: 2),
      const DiveFilterState(minBottomTimeMinutes: 2),
    ]) {
      final applied = filter.apply(domainDives).map((d) => d.id).toSet();
      final sqld = await idsMatching(filter);
      expect(sqld, applied, reason: 'mismatch for $filter');
    }
  });
```

Add the import at the top of the test file:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

- [ ] **Step 6: Run the parity test**

Run: `flutter test test/features/statistics/data/dive_filter_sql_test.dart`
Expected: PASS. This test constructs both sides in the same time frame, so it validates the truncation and end-day-inclusivity logic. To guarantee on-device dates (stored wall-clock-as-UTC) filter identically to the rest of the app, additionally grep the dive repository for how the existing dive-list filter converts `startDate`/`endDate` to `dive_date_time` bounds (search `dive_repository_impl.dart` for `dive_date_time` / `isBiggerOrEqualValue` / `millisecondsSinceEpoch` near the dive-list query), and match that exact conversion in the helper's two date branches (e.g. switch to `DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch` if that is what the dive list uses).

- [ ] **Step 7: Commit**

```bash
git add lib/features/statistics/data/dive_filter_sql.dart test/features/statistics/data/dive_filter_sql_test.dart
git commit -m "feat(statistics): add DiveFilterState-to-SQL subquery builder"
```

---

## Task 2: Thread filter into `getStatistics` + Overview wiring (thin end-to-end slice)

**Files:**
- Create: `lib/features/statistics/presentation/providers/statistics_filter_provider.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getStatistics`, ~line 1869)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart` (add `filteredDiveStatisticsProvider`)
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart:22`
- Test: `test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`

**Interfaces:**
- Consumes: `buildFilteredDiveIdSubquery` (Task 1).
- Produces: `statisticsFilterProvider` (`StateProvider<DiveFilterState>`); `filteredDiveStatisticsProvider` (`FutureProvider<DiveStatistics>`); `DiveRepository.getStatistics({String? diverId, DiveFilterState filter})`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id, {DateTime? date}) async {
    await db.into(db.dives).insert(DivesCompanion(
          id: Value(id),
          diveDateTime: Value((date ?? DateTime(2026, 6, 1)).millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
  }

  Future<void> tag(String id) async {
    await db.into(db.tags).insert(TagsCompanion(
          id: Value(id), name: Value(id), createdAt: Value(now), updatedAt: Value(now),
        ));
  }

  Future<void> link(String diveId, String tagId) async {
    await db.into(db.diveTags).insert(DiveTagsCompanion(
          id: Value('$diveId-$tagId'), diveId: Value(diveId),
          tagId: Value(tagId), createdAt: Value(now),
        ));
  }

  test('unfiltered getStatistics counts all dives (unchanged behavior)',
      () async {
    await dive('a');
    await dive('b');
    final stats = await repo.getStatistics();
    expect(stats.totalDives, 2);
  });

  test('tag filter scopes total dives', () async {
    await dive('a');
    await dive('b');
    await tag('dry');
    await link('a', 'dry');
    final stats = await repo.getStatistics(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(stats.totalDives, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`
Expected: FAIL — `getStatistics` has no `filter` parameter (compile error on the second test).

- [ ] **Step 3: Add the `filter` parameter and inject the clause**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, add the import near the top:

```dart
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';
```

Change the signature (line ~1869) from `Future<DiveStatistics> getStatistics({String? diverId}) async {` to:

```dart
  Future<DiveStatistics> getStatistics({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
```

Immediately after the existing `final whereClause = ...` / `final vars = ...` lines at the top of the `try`, insert:

```dart
      final df = buildFilteredDiveIdSubquery(filter);
      // Typed as Variable<Object> (not Variable<Object?>) to match the method's
      // `vars` list type; params are always non-null so `p!` is safe.
      final filterVars = df.params.map((p) => Variable<Object>(p!)).toList();
      // Clause fragments per table alias used below.
      final fBare = df.subquery.isEmpty ? '' : 'AND id IN (${df.subquery})';
      final fAliasD = df.subquery.isEmpty ? '' : 'AND d.id IN (${df.subquery})';
      // WHERE-prefix helpers so an empty base WHERE still starts correctly.
      final basicWhere = whereClause.isEmpty
          ? (df.subquery.isEmpty ? '' : 'WHERE id IN (${df.subquery})')
          : '$whereClause $fBare';
      vars.addAll(filterVars);
```

Then apply these exact substitutions in the four queries:

1. Basic stats query: replace the interpolated `$whereClause` with `$basicWhere`.
2. Monthly query: its `$monthlyWhereClause` already begins with `WHERE dive_date_time >= ...`; append the clause by replacing the interpolation `$monthlyWhereClause` with `$monthlyWhereClause $fBare`.
3. Depth query: replace `$depthWhereClause` with `$depthWhereClause $fBare` (it already begins `WHERE max_depth IS NOT NULL`).
4. Top-sites query: replace `$siteWhereClause` with the alias-aware form — change the line `final siteWhereClause = diverId != null ? 'WHERE d.diver_id = ?' : '';` to:

```dart
      final siteWhereClause = diverId != null
          ? 'WHERE d.diver_id = ? $fAliasD'
          : (df.subquery.isEmpty ? '' : 'WHERE 1=1 $fAliasD');
```

Because every query is passed the same shared `vars` list (now `[diverId?, ...filterVars]`) and each query's placeholders are diver-id (if present) followed by the filter's, ordering is preserved.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Create the filter provider**

Create `lib/features/statistics/presentation/providers/statistics_filter_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Independent filter for the Statistics tab. Deliberately NOT the same as
/// diveFilterProvider (the dive list) so filtering stats never rescopes the
/// list, the home dashboard, or vice-versa.
final statisticsFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);
```

- [ ] **Step 6: Add `filteredDiveStatisticsProvider` and switch the Overview page**

In `lib/features/statistics/presentation/providers/statistics_providers.dart`, add the import:

```dart
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
```

Add the provider (after the imports / near the top provider section):

```dart
/// Overview totals scoped by the Statistics filter. Kept separate from
/// diveStatisticsProvider so the home dashboard and dive-log summary (which
/// read diveStatisticsProvider) stay unfiltered.
final filteredDiveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getStatistics(diverId: currentDiverId, filter: filter);
});
```

Add the `DiveStatistics` / `diveRepositoryProvider` imports if the analyzer reports them missing (both come from `dive_providers.dart`, already imported).

In `lib/features/statistics/presentation/pages/statistics_overview_page.dart:22`, change `ref.watch(diveStatisticsProvider)` to `ref.watch(filteredDiveStatisticsProvider)`, and the invalidate at line 27 to `ref.invalidate(filteredDiveStatisticsProvider)`. Add the import for `statistics_providers.dart` if not present.

- [ ] **Step 7: Verify no bleed into the home tab (analyzer + targeted run)**

Run: `flutter analyze lib/features/statistics lib/features/dive_log`
Expected: no new errors. Confirm `hero_header.dart` and `dive_summary_widget.dart` still reference `diveStatisticsProvider` (unchanged).

Run: `flutter test test/features/dive_log/data/repositories/dive_statistics_filter_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/statistics/presentation/providers/statistics_filter_provider.dart lib/features/statistics/presentation/providers/statistics_providers.dart lib/features/statistics/presentation/pages/statistics_overview_page.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_statistics_filter_test.dart
git commit -m "feat(statistics): scope Overview totals by an independent stats filter"
```

---

## Task 3: Extract + parameterize `DiveFilterSheet`

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (remove class lines 1053-1689; add import)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (add import)
- Test: `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`

**Interfaces:**
- Produces: `DiveFilterSheet({required WidgetRef ref, StateProvider<DiveFilterState> filterProvider = diveFilterProvider})` in its own file.

- [ ] **Step 1: Move the class into a new file**

Cut lines 1053-1689 (the `/// Filter sheet for dive list` comment through the closing `}` of `_DiveFilterSheetState`) out of `dive_list_page.dart` into a new file `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`. At the top of the new file, copy the entire import block from `dive_list_page.dart`. (Unused imports will be flagged by the analyzer in Step 5 and removed.)

- [ ] **Step 2: Parameterize the constructor**

In the new file, change the constructor (was lines 1055-1057):

```dart
class DiveFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final StateProvider<DiveFilterState> filterProvider;

  const DiveFilterSheet({
    super.key,
    required this.ref,
    this.filterProvider = diveFilterProvider,
  });
```

Replace the three `diveFilterProvider` references inside the class with `widget.filterProvider`:
- `initState`: `final filter = widget.ref.read(widget.filterProvider);`
- Clear All button: `widget.ref.read(widget.filterProvider.notifier).state = const DiveFilterState();`
- `_applyFilters`: `widget.ref.read(widget.filterProvider.notifier).state = DiveFilterState(...)` (keep the existing field list).

- [ ] **Step 3: Add imports at the call sites**

In `dive_list_page.dart` and `dive_list_content.dart`, add:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
```

The three existing call sites (`dive_list_page.dart:212`, `dive_list_content.dart:771`, `:901`) stay `DiveFilterSheet(ref: ref)` — the new `filterProvider` param defaults to `diveFilterProvider`, so behavior is unchanged.

- [ ] **Step 4: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';

final _testStatsFilter = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

void main() {
  testWidgets('sheet writes the provider passed to filterProvider', (tester) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            capturedRef = ref;
            return Scaffold(
              body: DiveFilterSheet(ref: ref, filterProvider: _testStatsFilter),
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle "Favorites Only" and apply.
    await tester.tap(find.text('Favorites Only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(capturedRef.read(_testStatsFilter).favoritesOnly, true);
  });
}
```

(If the Apply button label differs, use the exact label rendered by the sheet's apply button.)

- [ ] **Step 5: Run test + analyze; fix imports**

Run: `flutter analyze lib/features/dive_log`
Expected: only "unused import" warnings in the new file — remove those imports until clean.

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the existing dive-list tests (no regression)**

Run: `flutter test test/features/dive_log/`
Expected: PASS (pre-existing dive-list tests unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart
git commit -m "refactor(dive-log): extract and parameterize DiveFilterSheet"
```

---

## Task 4: Date presets in the filter sheet

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (Date Range section)
- Test: extend `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`

**Interfaces:**
- Consumes: the sheet's local `_startDate` / `_endDate` state and `setState`.

- [ ] **Step 1: Write the failing test**

Append to `dive_filter_sheet_test.dart`:

```dart
  testWidgets('Last 12 months preset sets a start date and applies', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            return Scaffold(
              body: DiveFilterSheet(ref: ref, filterProvider: _testStatsFilter),
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Last 12 months'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveFilterSheet)),
    );
    expect(container.read(_testStatsFilter).startDate, isNotNull);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart -n "Last 12 months"`
Expected: FAIL — no "Last 12 months" chip exists yet.

- [ ] **Step 3: Insert the preset row**

In the Date Range section of the sheet's build (immediately after the `Text('Date Range', ...)` header and its following `const SizedBox(height: 8)`, before the Start/End `Row`), insert:

```dart
              Wrap(
                spacing: 8,
                children: [
                  _datePresetChip(context, 'All time', () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  }),
                  _datePresetChip(context, 'This year', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year, 1, 1);
                      _endDate = DateTime(now.year, now.month, now.day);
                    });
                  }),
                  _datePresetChip(context, 'Last 12 months', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year - 1, now.month, now.day);
                      _endDate = DateTime(now.year, now.month, now.day);
                    });
                  }),
                  _datePresetChip(context, 'Last year', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year - 1, 1, 1);
                      _endDate = DateTime(now.year - 1, 12, 31);
                    });
                  }),
                ],
              ),
              const SizedBox(height: 8),
```

Add the helper method inside `_DiveFilterSheetState` (near `_selectDate`):

```dart
  Widget _datePresetChip(BuildContext context, String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
```

(These labels are placeholder English; Task 12 replaces them with l10n keys.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`
Expected: PASS (both sheet tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart
git commit -m "feat(dive-log): add quick date presets to the filter sheet"
```

---

## Task 5: Statistics filter entry point + active-filter summary bar

**Files:**
- Create: `lib/features/statistics/presentation/widgets/statistics_filter_bar.dart`
- Modify: `lib/features/statistics/presentation/pages/statistics_page.dart` (`StatisticsMobileContent` → `ConsumerWidget`; app-bar action; summary bar)
- Modify: `lib/features/statistics/presentation/widgets/statistics_list_content.dart` (`StatisticsListContent` → `ConsumerWidget`; app-bar actions; summary bar)
- Test: `test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`

**Interfaces:**
- Consumes: `statisticsFilterProvider`, `filteredDiveStatisticsProvider`, `DiveFilterSheet`.
- Produces: `StatisticsFilterBar` widget.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';

void main() {
  testWidgets('tapping clear resets the statistics filter', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statisticsFilterProvider.overrideWith(
            (ref) => const DiveFilterState(favoritesOnly: true),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: StatisticsFilterBar())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StatisticsFilterBar)),
    );
    expect(container.read(statisticsFilterProvider).hasActiveFilters, true);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(container.read(statisticsFilterProvider).hasActiveFilters, false);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`
Expected: FAIL — `StatisticsFilterBar` does not exist.

- [ ] **Step 3: Implement `StatisticsFilterBar`**

Create `lib/features/statistics/presentation/widgets/statistics_filter_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

/// Summary bar shown at the top of the Statistics tab when a filter is active.
/// Shows the matching dive count and a clear affordance so a scoped total is
/// never mysterious.
class StatisticsFilterBar extends ConsumerWidget {
  const StatisticsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statisticsFilterProvider);
    if (!filter.hasActiveFilters) return const SizedBox.shrink();

    final statsAsync = ref.watch(filteredDiveStatisticsProvider);
    final countText = statsAsync.maybeWhen(
      data: (s) => '${s.totalDives} dives',
      orElse: () => '',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              countText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Clear filter',
            onPressed: () => ref.read(statisticsFilterProvider.notifier).state =
                const DiveFilterState(),
          ),
        ],
      ),
    );
  }
}
```

(Labels are placeholder English; Task 12 replaces them with l10n keys.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the filter icon + bar to the mobile page**

In `statistics_page.dart`, convert `StatisticsMobileContent` from `StatelessWidget` to `ConsumerWidget` (signature `Widget build(BuildContext context, WidgetRef ref)`), add these imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
```

Add a filter action to the `actions:` list (after the `emoji_events` IconButton):

```dart
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(statisticsFilterProvider).hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter statistics',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => DiveFilterSheet(
                ref: ref,
                filterProvider: statisticsFilterProvider,
              ),
            ),
          ),
```

Wrap the `body:` `ListView.separated(...)` in a `Column` so the bar sits above it:

```dart
      body: Column(
        children: [
          const StatisticsFilterBar(),
          Expanded(
            child: ListView.separated(
              // ...existing ListView.separated arguments unchanged...
            ),
          ),
        ],
      ),
```

- [ ] **Step 6: Add the filter icon + bar to the desktop content**

In `statistics_list_content.dart`, convert `StatisticsListContent` to `ConsumerWidget`, add the same 4 imports, and add the same `IconButton` (badged, opening the sheet with `statisticsFilterProvider`) to BOTH the full `AppBar` `actions:` (after `emoji_events`) and the compact `_buildCompactAppBar` `Row` (after the `emoji_events` IconButton, before the closing `],`). Insert the bar in the `showAppBar == false` branch:

```dart
    if (!showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          const StatisticsFilterBar(),
          Expanded(child: listContent),
        ],
      );
    }
```

Note: `_buildCompactAppBar` currently takes only `BuildContext`; add the badged filter `IconButton` using `ref.watch(statisticsFilterProvider)` — since the method is now inside a `ConsumerWidget`, pass `ref` in (change its signature to `_buildCompactAppBar(BuildContext context, WidgetRef ref)` and update its one call site in `build`).

- [ ] **Step 7: Analyze + run**

Run: `flutter analyze lib/features/statistics`
Expected: clean.

Run: `flutter test test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/statistics/presentation/widgets/statistics_filter_bar.dart lib/features/statistics/presentation/pages/statistics_page.dart lib/features/statistics/presentation/widgets/statistics_list_content.dart test/features/statistics/presentation/widgets/statistics_filter_bar_test.dart
git commit -m "feat(statistics): add filter entry point and active-filter bar"
```

---

## Threading recipe (shared by Tasks 6-11)

All 32 `StatisticsRepository` methods take the same uniform change. Tasks 6-11 apply this recipe; Task 6 also adds the `_diveFilter` helper it depends on.

**Per method:**
1. Add a parameter: `DiveFilterState filter = const DiveFilterState()`.
2. Build the fragment: `final df = _diveFilter(filter, alias: '<alias>');` where `<alias>` is the method's dives-table alias — `'dives'` for a single-table `FROM dives`, `'d'` for any method that JOINs `dives d` (the established convention; confirm by reading the method's `FROM`).
3. Splice `${df.clause}` into the SQL immediately AFTER the existing `$diverFilter` (still before `GROUP BY`/`HAVING`/`ORDER BY`/`LIMIT`).
4. Add `df.params` to the positional params list, by the **params-position rule**:
   - **Normal method** (no trailing `LIMIT ?`): append — `params = diverId != null ? [diverId, ...df.params] : [...df.params];` (extend the existing leading params — e.g. `[cutoff, diverId, ...df.params]` or `[speciesId, diverId, ...df.params]` — keeping `...df.params` LAST).
   - **`LIMIT ?` method** (the 8 flagged): insert before `limit` — `params = diverId != null ? [diverId, ...df.params, limit] : [...df.params, limit];`.

**Per provider:** in `statistics_providers.dart`, the `FutureProvider` that calls the threaded method adds `final filter = ref.watch(statisticsFilterProvider);` and passes `filter: filter`. Add `import '.../statistics_filter_provider.dart';` once.

**The 8 `LIMIT ?` methods** (params-position rule, insert-before-limit): `getTopBuddies`, `getTopDiveCenters`, `getCountriesVisited`, `getRegionsExplored`, `getDivesPerTrip`, `getMostCommonSightings`, `getBestSitesForMarineLife`, `getMostUsedGear`.

---

## Task 6: `_diveFilter` helper + Conditions category

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (helper + `getVisibilityDistribution` @823, `getWaterTypeDistribution` @865, `getEntryMethodDistribution` @907)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart` (their 3 providers)
- Test: `test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

**Interfaces:**
- Consumes: `buildFilteredDiveIdSubquery` (Task 1), `statisticsFilterProvider` (Task 2).
- Produces: private `_diveFilter(DiveFilterState, {String alias})` on `StatisticsRepository`; `filter` param on the three Conditions methods.

- [ ] **Step 1: Write the failing round-trip test**

Create `test/features/statistics/data/repositories/statistics_repository_filter_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id, {String? visibility}) async {
    await db.into(db.dives).insert(DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          visibility: Value(visibility),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
  }

  Future<void> tag(String id) async {
    await db.into(db.tags).insert(TagsCompanion(
          id: Value(id), name: Value(id), createdAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> link(String diveId, String tagId) async {
    await db.into(db.diveTags).insert(DiveTagsCompanion(
          id: Value('$diveId-$tagId'), diveId: Value(diveId),
          tagId: Value(tagId), createdAt: Value(now)));
  }

  test('visibility distribution respects a tag filter', () async {
    await dive('a', visibility: 'Good');
    await dive('b', visibility: 'Poor');
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getVisibilityDistribution();
    expect(all.length, 2);

    final filtered = await repo.getVisibilityDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.length, 1);
    expect(filtered.first.label, 'Good');
  });
}
```

(If `Dives.visibility` is a different column name/type, adjust the companion field to match; confirm at `database.dart`.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`
Expected: FAIL — `getVisibilityDistribution` has no `filter` parameter.

- [ ] **Step 3: Add imports + the `_diveFilter` helper**

At the top of `statistics_repository.dart`, add:

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';
```

Inside `class StatisticsRepository`, add the private helper (near the top, after the `_log` field):

```dart
  /// Builds the `AND <alias>.id IN (<subquery>)` fragment + raw params for a
  /// stats filter. Empty (no-op) when the filter has no active axes.
  ({String clause, List<Object?> params}) _diveFilter(
    DiveFilterState filter, {
    String alias = 'dives',
  }) {
    final f = buildFilteredDiveIdSubquery(filter);
    if (f.subquery.isEmpty) return (clause: '', params: const <Object?>[]);
    return (clause: 'AND $alias.id IN (${f.subquery})', params: f.params);
  }
```

- [ ] **Step 4: Thread the three Conditions methods (fully worked: `getVisibilityDistribution`)**

Change `getVisibilityDistribution`'s signature to add `DiveFilterState filter = const DiveFilterState()`, then edit its body:

```dart
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          visibility,
          COUNT(*) AS count
        FROM dives
        WHERE visibility IS NOT NULL AND visibility != '' $diverFilter ${df.clause}
        GROUP BY visibility
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();
```

Apply the identical recipe (alias `'dives'`, normal params-position) to `getWaterTypeDistribution` (@865) and `getEntryMethodDistribution` (@907) — each is a single-table `FROM dives` GROUP BY with the same `diverFilter`/`params` idiom.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire the 3 providers**

In `statistics_providers.dart`, add `import '.../statistics_filter_provider.dart';`, then in each of the three providers calling these methods (grep the method names), add `final filter = ref.watch(statisticsFilterProvider);` and pass `filter: filter`.

- [ ] **Step 7: Analyze + commit**

Run: `flutter analyze lib/features/statistics`
Expected: clean.

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope conditions stats by the filter"
```

---

## Task 7: Overview + Progression category

**Files:** Modify `statistics_repository.dart` (`getDiveTypeDistribution` @611 [alias `d`], `getGasMixDistribution`? no — gas is Task 8; here: `getDivesPerYear` @747, `getCumulativeDiveCount` @781, `getDepthProgressionTrend` @663 [leading `dive_date_time >= ?` cutoff], `getBottomTimeTrend` @706 [leading cutoff]); their providers; extend the filter test file.

**Interfaces:** Consumes `_diveFilter`. Note `getDiveTypeDistribution` JOINs `dives d` → alias `'d'`; the trends have a LEADING cutoff param so params = `[cutoff, diverId, ...df.params]` (df.params LAST, normal rule).

- [ ] **Step 1: Write the failing test** — append to `statistics_repository_filter_test.dart`:

```dart
  test('dive-type distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await db.into(db.diveDiveTypes).insert(DiveDiveTypesCompanion(
          id: const Value('t-a'), diveId: const Value('a'),
          diveTypeId: const Value('wreck'), createdAt: Value(now)));
    await db.into(db.diveDiveTypes).insert(DiveDiveTypesCompanion(
          id: const Value('t-b'), diveId: const Value('b'),
          diveTypeId: const Value('wreck'), createdAt: Value(now)));
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getDiveTypeDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.first.count, 1); // only dive 'a'
  });
```

- [ ] **Step 2: Run — Expected FAIL** (`getDiveTypeDistribution` has no `filter`).

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart -n "dive-type"`

- [ ] **Step 3: Thread the methods.** `getDiveTypeDistribution` (worked, alias `d`):

```dart
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          ddt.dive_type_id AS dive_type,
          COUNT(*) AS count
        FROM dive_dive_types ddt
        JOIN dives d ON d.id = ddt.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY ddt.dive_type_id
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();
```

Apply the recipe to `getDivesPerYear` (@747, alias per its `FROM`), `getCumulativeDiveCount` (@781), `getDepthProgressionTrend` (@663), `getBottomTimeTrend` (@706). For the two trends the existing params already lead with the date cutoff (`[cutoff, diverId?]`); extend to `[cutoff, diverId, ...df.params]` / `[cutoff, ...df.params]` keeping `df.params` last.

- [ ] **Step 4: Run — Expected PASS.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

- [ ] **Step 5: Wire providers** (grep the 5 method names in `statistics_providers.dart`; add filter watch + pass-through).

- [ ] **Step 6: Analyze + commit.**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope overview and progression stats by the filter"
```

---

## Task 8: Gas category

**Files:** Modify `statistics_repository.dart` (`getSacVolumeTrend` @65, `getSacPressureTrend` @190, `getGasMixDistribution` @250, `getSacVolumeRecords` @298, `getSacPressureRecords` @420, `getSacVolumeByTankRole` @487, `getSacPressureByTankRole` @563); their providers; extend the test file.

**Interfaces:** These JOIN `dive_tanks` to `dives` (alias `d`). The SAC trends/records have a leading `dive_date_time >= ?` cutoff → normal rule with `df.params` LAST. None are `LIMIT ?` methods.

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('gas-mix distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    for (final id in ['a', 'b']) {
      await db.into(db.diveTanks).insert(DiveTanksCompanion(
            id: Value('tank-$id'), diveId: Value(id),
            o2Percent: const Value(32.0), hePercent: const Value(0.0),
            tankOrder: const Value(0)));
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getGasMixDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    final total = filtered.fold<int>(0, (s, seg) => s + seg.count);
    expect(total, 1); // only dive 'a'
  });
```

(Include whatever `DiveTanksCompanion` fields are required; mirror the known-good insert from `statistics_repository_sac_test.dart`.)

- [ ] **Step 2: Run — Expected FAIL.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart -n "gas-mix"`

- [ ] **Step 3: Thread the 7 gas methods** per the recipe. For each, read the method's `FROM` to confirm the dives alias (`d` where `dives d` is joined), splice `${df.clause}` after `$diverFilter`, and extend params keeping `...df.params` last (after any leading cutoff). The SAC volume methods also do Dart-side aggregation after the query — leave that untouched; only the SQL WHERE + params change.

- [ ] **Step 4: Run — Expected PASS.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

- [ ] **Step 5: Wire the 7 gas providers.**

- [ ] **Step 6: Analyze + commit.**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope gas and SAC stats by the filter"
```

---

## Task 9: Social + Geographic categories (LIMIT-heavy)

**Files:** Modify `statistics_repository.dart` (`getTopBuddies` @990 [LIMIT], `getSoloVsBuddyCount` @1026, `getTopDiveCenters` @1056 [LIMIT], `getCountriesVisited` @1123 [LIMIT], `getRegionsExplored` @1162 [LIMIT], `getDivesPerTrip` @1203 [LIMIT]); their providers; extend the test file.

**Interfaces:** All six JOIN `dives d` (alias `'d'`). Five are `LIMIT ?` methods — use the **insert-before-limit** params rule. `getSoloVsBuddyCount` is normal.

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('top buddies respects a tag filter (LIMIT method)', () async {
    await dive('a');
    await dive('b');
    await db.into(db.buddies).insert(BuddiesCompanion(
          id: const Value('bud'), name: const Value('Sam'),
          createdAt: Value(now), updatedAt: Value(now)));
    for (final id in ['a', 'b']) {
      await db.into(db.diveBuddies).insert(DiveBuddiesCompanion(
            diveId: Value(id), buddyId: const Value('bud')));
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getTopBuddies(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.first.count, 1); // buddy appears on 1 filtered dive
  });
```

(Confirm `Buddies` / `DiveBuddies` companion required fields at `database.dart`; adjust if needed.)

- [ ] **Step 2: Run — Expected FAIL.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart -n "top buddies"`

- [ ] **Step 3: Thread the methods.** `getTopBuddies` (worked, LIMIT rule):

```dart
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params, limit]
          : [...df.params, limit];

      final results = await _db.customSelect('''
        SELECT b.id, b.name, COUNT(db.dive_id) AS dive_count
        FROM buddies b
        JOIN dive_buddies db ON db.buddy_id = b.id
        JOIN dives d ON d.id = db.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY b.id
        ORDER BY dive_count DESC
        LIMIT ?
        ''', variables: params.map((p) => Variable(p)).toList()).get();
```

Apply the recipe to `getTopDiveCenters`, `getCountriesVisited`, `getRegionsExplored`, `getDivesPerTrip` (all alias `d`, all LIMIT rule) and `getSoloVsBuddyCount` (alias `d`, normal rule).

- [ ] **Step 4: Run — Expected PASS.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

- [ ] **Step 5: Wire the 6 providers.**

- [ ] **Step 6: Analyze + commit.**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope social and geographic stats by the filter"
```

---

## Task 10: Marine Life category

**Files:** Modify `statistics_repository.dart` (`getUniqueSpeciesCount` @1248, `getMostCommonSightings` @1272 [LIMIT], `getBestSitesForMarineLife` @1314 [LIMIT], `getSpeciesStatistics` @1354 [leading `species_id = ?`]); their providers; extend the test file.

**Interfaces:** All JOIN `dives d` (alias `'d'`). `getSpeciesStatistics` leads with `species_id = ?` → params `[speciesId, diverId?, ...df.params]` (normal rule, df.params last; its `LIMIT 5` is hardcoded). Two are `LIMIT ?` methods.

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('unique species count respects a tag filter', () async {
    await dive('a');
    await dive('b');
    for (final id in ['a', 'b']) {
      await db.into(db.sightings).insert(SightingsCompanion.insert(
            id: 'sight-$id', diveId: id, speciesId: 'turtle'));
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getUniqueSpeciesCount(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered, 1);
  });
```

- [ ] **Step 2: Run — Expected FAIL.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart -n "unique species"`

- [ ] **Step 3: Thread the methods.** `getUniqueSpeciesCount` (worked, alias `d`):

```dart
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT COUNT(DISTINCT s.species_id) AS count
        FROM sightings s
        JOIN dives d ON d.id = s.dive_id
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();
```

Apply the recipe to `getMostCommonSightings` (LIMIT rule), `getBestSitesForMarineLife` (LIMIT rule), and `getSpeciesStatistics` (leading `speciesId`; params `[speciesId, diverId?, ...df.params]`; splice `${df.clause}` after each `$diverFilter` occurrence — it appears twice, @1376 and @1394; NOTE this method builds two queries sharing `baseParams`, so add `...df.params` to `baseParams` once and confirm both queries place `${df.clause}` after their `$diverFilter`).

- [ ] **Step 4: Run — Expected PASS.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

- [ ] **Step 5: Wire the 4 providers.**

- [ ] **Step 6: Analyze + commit.**

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope marine-life stats by the filter"
```

---

## Task 11: Time Patterns + Equipment + Profile categories

**Files:** Modify `statistics_repository.dart` (`getDivesByDayOfWeek` @1441, `getDivesByTimeOfDay` @1475, `getDivesBySeason` @1528, `getMostUsedGear` @1617 [LIMIT], `getWeightTrend` @1662 [leading cutoff], `getAscentDescentRates` @1708, `getDecoObligationStats` @1790); their providers; extend the test file.

**Interfaces:** Confirm each method's dives alias from its `FROM`. `getMostUsedGear` is a `LIMIT ?` method; `getWeightTrend` leads with a date cutoff (df.params last).

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('dives by day-of-week respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getDivesByDayOfWeek(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    final total = filtered.fold<int>(0, (s, e) => s + e.count);
    expect(total, 1);
  });
```

(Adjust the aggregation of the returned type to whatever `getDivesByDayOfWeek` returns — a list with a `count` per bucket.)

- [ ] **Step 2: Run — Expected FAIL.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart -n "day-of-week"`

- [ ] **Step 3: Thread the 7 methods** per the recipe (confirm alias per `FROM`; `getMostUsedGear` uses the LIMIT rule; `getWeightTrend` keeps `df.params` after its leading cutoff).

- [ ] **Step 4: Run — Expected PASS.**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_filter_test.dart`

- [ ] **Step 5: Wire the 7 providers.**

- [ ] **Step 6: Analyze + full stats test run + commit.**

Run: `flutter test test/features/statistics/`
Expected: PASS (all statistics tests, including pre-existing ones).

```bash
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/statistics/presentation/providers/statistics_providers.dart test/features/statistics/data/repositories/statistics_repository_filter_test.dart
git commit -m "feat(statistics): scope time, equipment, and profile stats by the filter"
```

---

## Task 12: Localization + final verification

**Files:** Modify `lib/l10n/app_en.arb` (+ all 10 non-en locale ARBs); replace placeholder English strings in `dive_filter_sheet.dart` (presets) and `statistics_filter_bar.dart` + the two stats pages (tooltips, "Filter statistics", "Clear filter", "<n> dives"); regenerate l10n.

- [ ] **Step 1: Add keys to `app_en.arb`**

Add entries (match the repo's existing `statistics_*` / `diveLog_*` key style), e.g. `statistics_tooltip_filter`, `statistics_filterBar_diveCount` (with an `{count}` placeholder), `statistics_filterBar_clear`, `diveLog_filterSheet_preset_allTime`, `_thisYear`, `_last12Months`, `_lastYear`.

- [ ] **Step 2: Regenerate + translate**

Run: `flutter gen-l10n` (or `flutter pub get` if gen runs on build).
Then add the translated values to each of the 10 non-en ARB files (per project rule: all locales translated, not left English). Replace the placeholder English literals in the Dart from Tasks 4 and 5 with `context.l10n.<key>` references.

- [ ] **Step 3: Format + analyze (whole project)**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues, no formatting changes remaining.

- [ ] **Step 4: Full affected-area test run**

Run: `flutter test test/features/statistics/ test/features/dive_log/`
Expected: PASS.

- [ ] **Step 5: Manual smoke (optional but recommended)**

Run: `flutter run -d macos`, open Statistics, tap the filter icon, pick a tag + "Last 12 months", confirm the summary bar shows a reduced dive count and every category page reflects the scope; open Home and confirm its totals are unchanged.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "i18n(statistics): localize filter strings across all locales"
```

---

## Self-Review

- **Spec coverage:** §5 SQL builder → Task 1. §6.3 filtered sibling provider (home untouched) → Task 2. §7.1 extract/parameterize sheet → Task 3. §7.2 presets → Task 4. §7.3-7.4 entry point + summary bar → Task 5. §5.3 threading all 32 methods → Tasks 6-11. §9 tests: builder (Task 1), parity (Task 1 Step 5), round-trip FK-ON (Tasks 6-11), provider/widget (Tasks 2, 3, 5). §10 l10n → Task 12.
- **Placeholder scan:** No TBD/TODO. "Confirm alias/companion fields in body" steps are real per-method verifications against existing code (aliases are known to vary), not hand-waves; the recipe + worked examples make each edit concrete.
- **Type consistency:** `buildFilteredDiveIdSubquery` → `({String subquery, List<Object?> params})` used consistently; `_diveFilter` → `({String clause, List<Object?> params})`; `statisticsFilterProvider` / `filteredDiveStatisticsProvider` names consistent across Tasks 2, 5, 6-11.

---

