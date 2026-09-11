# Dive List Trip Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fold consecutive same-trip dives in the Dives list under a collapsible, pinned trip header without making any dive card narrower.

**Architecture:** A pure function turns the loaded page of `DiveSummary` rows into a list of sealed `DiveListSection`s (loose runs and trip runs). `_buildDiveList` becomes a `CustomScrollView`; each trip section renders as a `DecoratedSliver` (the full-bleed band) wrapping a `SliverMainAxisGroup` of a pinned header plus a `SliverList` of member rows. Rows are still rendered by the existing `DiveListItem`, untouched, so card geometry is identical grouped or not.

**Tech Stack:** Flutter 3.47, Riverpod, Drift (SQLite), `shared_preferences`, `intl`/`flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-09-dive-list-trip-grouping-design.md`

## Global Constraints

- **Dive cards must never narrow.** Every dive card keeps `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` (detailed) / `vertical: 2` (compact). No indent, no rail, no inset. Task 9 asserts this with a width test.
- **Schema version claimed: 201.** Settled 2026-09-09 during execution: PR #1677 (transmitter registry) MERGED, so `origin/main` shipped v200 and this branch was rebased onto it. 201 is the next free rung. If the equipment-assemblies program lands 201 first, renumber this rung to the next free number, which is the convention every recent rung comment in `database.dart` documents: a rung at or below the shipped version never runs its onUpgrade step.
- **Do not raise `minimumCompatibleSchemaVersion`** (currently 183). An additive defaulted column does not require it.
- **No em-dash characters (U+2014) anywhere**, including code, comments, commit messages and ARB strings. Use commas, colons, semicolons or separate sentences.
- **No mention of Claude, Claude Code or Anthropic** in any commit message, code comment, or anything else written to the repository.
- **Grouping applies to `ListViewMode.detailed` and `ListViewMode.compact` only.** `ListViewMode.table` ignores it entirely.
- Run `dart format .` before every commit. The pre-push hook runs `flutter analyze --fatal-infos` over the whole project, so an info-level lint fails the push.
- This worktree needs `dart run build_runner build --delete-conflicting-outputs` before app code compiles (`database.g.dart` is gitignored and per-worktree). Run it once before Task 1 if `flutter test` reports missing generated symbols.
- `lib/l10n/arb/app_localizations*.dart` is **checked in** and goes stale silently. Any task that adds an ARB key must run `flutter gen-l10n` and commit the regenerated files with it.

---

### Task 1: DiveSummary carries trip identity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart`
- Test: `test/features/dive_log/domain/entities/dive_summary_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `DiveSummary.tripId` (`String?`), `.tripName` (`String?`), `.tripStartDate` (`DateTime?`), `.tripEndDate` (`DateTime?`); all four added to the constructor, `copyWith` and `props`; `DiveSummary.fromDive` maps them from `dive.trip`.

- [ ] **Step 1: Write the failing test**

Append to the existing `group('DiveSummary', ...)` in `test/features/dive_log/domain/entities/dive_summary_test.dart`:

```dart
    test('fromDive carries trip identity when the dive is on a trip', () {
      final trip = Trip(
        id: 't1',
        name: 'Tassie',
        startDate: DateTime(2026, 6, 8),
        endDate: DateTime(2026, 6, 9),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      final dive = Dive(
        id: 'd1',
        dateTime: DateTime(2026, 6, 8, 9, 33),
        trip: trip,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      final summary = DiveSummary.fromDive(dive);

      expect(summary.tripId, 't1');
      expect(summary.tripName, 'Tassie');
      expect(summary.tripStartDate, DateTime(2026, 6, 8));
      expect(summary.tripEndDate, DateTime(2026, 6, 9));
    });

    test('fromDive leaves trip identity null for a loose dive', () {
      final dive = Dive(
        id: 'd2',
        dateTime: DateTime(2026, 6, 10, 9, 0),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      final summary = DiveSummary.fromDive(dive);

      expect(summary.tripId, isNull);
      expect(summary.tripName, isNull);
      expect(summary.tripStartDate, isNull);
      expect(summary.tripEndDate, isNull);
    });

    test('copyWith preserves trip identity', () {
      final summary = DiveSummary(
        id: 'd1',
        dateTime: DateTime(2026, 6, 8),
        sortTimestamp: 0,
        tripId: 't1',
        tripName: 'Tassie',
        tripStartDate: DateTime(2026, 6, 8),
        tripEndDate: DateTime(2026, 6, 9),
      );

      expect(summary.copyWith(rating: 4).tripId, 't1');
      expect(summary.copyWith(rating: 4).tripName, 'Tassie');
    });
```

Add the import at the top of the test file:

```dart
import 'package:submersion/features/trips/domain/entities/trip.dart';
```

If `Dive`'s or `Trip`'s constructors require other named parameters, fill them with the same literals the surrounding tests in this file already use rather than inventing new ones.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_summary_test.dart`
Expected: FAIL, `No named parameter with the name 'tripId'`.

- [ ] **Step 3: Add the fields**

In `lib/features/dive_log/domain/entities/dive_summary.dart`, after the site fields block (the `siteLongitude` declaration), add:

```dart
  // Trip fields (from LEFT JOIN trips). Four scalars, deliberately not a Trip
  // object: a list row must never drag a full entity behind it.
  final String? tripId;
  final String? tripName;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
```

Add to the constructor parameter list, after `this.siteLongitude,`:

```dart
    this.tripId,
    this.tripName,
    this.tripStartDate,
    this.tripEndDate,
```

In `factory DiveSummary.fromDive(Dive dive)`, after `siteLongitude: dive.site?.location?.longitude,`:

```dart
      tripId: dive.tripId ?? dive.trip?.id,
      tripName: dive.trip?.name,
      tripStartDate: dive.trip?.startDate,
      tripEndDate: dive.trip?.endDate,
```

In `copyWith`, add the four parameters after `double? siteLongitude,`:

```dart
    String? tripId,
    String? tripName,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
```

and in its body, after `siteLongitude: siteLongitude ?? this.siteLongitude,`:

```dart
      tripId: tripId ?? this.tripId,
      tripName: tripName ?? this.tripName,
      tripStartDate: tripStartDate ?? this.tripStartDate,
      tripEndDate: tripEndDate ?? this.tripEndDate,
```

In `props`, add after `siteLongitude,`:

```dart
    tripId,
    tripName,
    tripStartDate,
    tripEndDate,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_summary_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/dive_summary.dart test/features/dive_log/domain/entities/dive_summary_test.dart
git commit -m "feat(dive-log): carry trip identity on DiveSummary (#1193)"
```

---

### Task 2: The summary SELECTs join trips

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (the paginated summary SQL near line 2013, the `_summariesForIds` SQL near line 2742, and `_mapSummaryRows` near line 2782)
- Test: `test/features/dive_log/data/repositories/dive_summary_trip_fields_test.dart` (create)

**Interfaces:**
- Consumes: `DiveSummary.tripId/tripName/tripStartDate/tripEndDate` from Task 1.
- Produces: `getDiveSummaries()` and the id-batch summary path both populate the four trip fields.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/dive_summary_trip_fields_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertTrip(String id, String name) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion(
            id: Value(id),
            name: Value(name),
            startDate: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
            endDate: Value(DateTime(2026, 6, 9).millisecondsSinceEpoch),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id, {String? tripId, DateTime? date}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            name: Value('Dive $id'),
            diveDateTime: Value(
              asWallClockUtc(date ?? DateTime(2026, 6, 8)).millisecondsSinceEpoch,
            ),
            tripId: Value(tripId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('dive summary trip fields', () {
    test('getDiveSummaries populates trip identity', () async {
      await insertTrip('t1', 'Tassie');
      await insertDive('d1', tripId: 't1');
      await insertDive('d2');

      final summaries = await repository.getDiveSummaries();
      final onTrip = summaries.firstWhere((s) => s.id == 'd1');
      final loose = summaries.firstWhere((s) => s.id == 'd2');

      expect(onTrip.tripId, 't1');
      expect(onTrip.tripName, 'Tassie');
      expect(onTrip.tripStartDate, DateTime(2026, 6, 8));
      expect(onTrip.tripEndDate, DateTime(2026, 6, 9));
      expect(loose.tripId, isNull);
      expect(loose.tripName, isNull);
    });

    test('the id-batch summary path populates trip identity too', () async {
      await insertTrip('t1', 'Tassie');
      await insertDive('d1', tripId: 't1');

      final summaries = await repository.getSummariesByIds(['d1']);

      expect(summaries.single.tripId, 't1');
      expect(summaries.single.tripName, 'Tassie');
    });
  });
}
```

If the id-batch method is not named `getSummariesByIds`, use the public method that wraps `_summariesForIds` (grep for `_summariesForIds` and use its caller).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_summary_trip_fields_test.dart`
Expected: FAIL, `Expected: 't1' Actual: <null>`.

- [ ] **Step 3: Add the join and the mapping**

In the paginated summary SQL (near line 2013), extend the SELECT list. Add after the `s.longitude AS site_longitude, ` line:

```dart
            't.id AS trip_id, t.name AS trip_name, '
            't.start_date AS trip_start_date, t.end_date AS trip_end_date, '
```

and add the join immediately after the sites join:

```dart
            'LEFT JOIN trips t ON d.trip_id = t.id '
```

Add `_db.trips` to that query's `readsFrom` set so Drift invalidates the stream when a trip is renamed.

Make the identical two edits in the `_summariesForIds` SQL near line 2742, including adding `_db.trips` to its `readsFrom: {_db.dives, _db.diveSites, _db.diveSafetyFindings}`.

In `_mapSummaryRows` (near line 2782), inside the returned `DiveSummary(...)`, after `siteLongitude: row.readNullable<double>('site_longitude'),`:

```dart
        tripId: row.readNullable<String>('trip_id'),
        tripName: row.readNullable<String>('trip_name'),
        tripStartDate: _epochOrNull(row.readNullable<int>('trip_start_date')),
        tripEndDate: _epochOrNull(row.readNullable<int>('trip_end_date')),
```

and add this private helper directly below `_mapSummaryRows`:

```dart
  /// Trip dates are stored as epoch milliseconds; null stays null.
  static DateTime? _epochOrNull(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/`
Expected: PASS, including the pre-existing repository tests (the join must not change row counts, since it is a LEFT JOIN on a unique id).

- [ ] **Step 5: Check the query plan did not regress**

Run: `flutter test test/core/database/query_plan_test.dart`
Expected: PASS. If that test asserts on the summary query's plan, update the expectation to include the `trips` lookup by primary key, and only accept a plan that uses `SEARCH t USING INTEGER PRIMARY KEY` or an index, never `SCAN t`.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_summary_trip_fields_test.dart
git commit -m "feat(dive-log): join trips into the dive summary queries (#1193)"
```

---

### Task 3: Trip dive-count provider

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add a public method)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (add the provider)
- Test: `test/features/dive_log/data/repositories/trip_dive_counts_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Future<Map<String, int>> DiveRepository.getTripDiveCounts()` and `final tripDiveCountsProvider = FutureProvider<Map<String, int>>(...)`. Task 6 consumes the map; Task 9 watches the provider.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/trip_dive_counts_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertTrip(String id) async {
    await db.into(db.trips).insert(
      TripsCompanion(
        id: Value(id),
        name: Value('Trip $id'),
        startDate: Value(now),
        endDate: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> insertDive(String id, {String? tripId}) async {
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(id),
        diveDateTime: Value(
          asWallClockUtc(DateTime(2026, 6, 8)).millisecondsSinceEpoch,
        ),
        tripId: Value(tripId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  group('getTripDiveCounts', () {
    test('counts dives per trip and omits loose dives', () async {
      await insertTrip('t1');
      await insertTrip('t2');
      await insertDive('d1', tripId: 't1');
      await insertDive('d2', tripId: 't1');
      await insertDive('d3', tripId: 't2');
      await insertDive('d4');

      final counts = await repository.getTripDiveCounts();

      expect(counts['t1'], 2);
      expect(counts['t2'], 1);
      expect(counts.length, 2);
    });

    test('returns an empty map when nothing is on a trip', () async {
      await insertDive('d1');

      expect(await repository.getTripDiveCounts(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/trip_dive_counts_test.dart`
Expected: FAIL, `The method 'getTripDiveCounts' isn't defined`.

- [ ] **Step 3: Implement the query**

Add to `DiveRepository` in `dive_repository_impl.dart`, next to the other summary methods:

```dart
  /// Total dives per trip, for the dive list's group headers.
  ///
  /// One grouped count for the whole list rather than a query per header, and
  /// deliberately unfiltered: the header contrasts "how many of this trip are
  /// in the list right now" against the trip's real size, so this side of that
  /// comparison must ignore the view filter.
  // stats-scope-exempt: a structural count for list chrome, not a statistic.
  Future<Map<String, int>> getTripDiveCounts() async {
    final rows = await _db
        .customSelect(
          'SELECT trip_id, COUNT(*) AS n FROM dives '
          'WHERE trip_id IS NOT NULL GROUP BY trip_id',
          readsFrom: {_db.dives},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('trip_id'): row.read<int>('n'),
    };
  }
```

Add the provider to `lib/features/dive_log/presentation/providers/dive_providers.dart`, beside the other dive providers:

```dart
/// Total dives per trip, keyed by trip id, for dive list group headers.
///
/// One query for the entire list. Refreshes on the same dive-change tick the
/// list itself watches, so adding or removing a dive from a trip corrects the
/// header count without a manual invalidate.
final tripDiveCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(diveChangeTickProvider);
  return ref.read(diveRepositoryProvider).getTripDiveCounts();
});
```

Grep `dive_providers.dart` for the tick provider the paginated list already watches (search for `watchDiveDetailChanges` or a `Tick` provider) and use that exact name in place of `diveChangeTickProvider`. If no tick provider exists, drop the `ref.watch` line and instead have Task 9 call `ref.invalidate(tripDiveCountsProvider)` where the list already refreshes.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/trip_dive_counts_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/data/repositories/trip_dive_counts_test.dart
git commit -m "feat(dive-log): count dives per trip for list group headers (#1193)"
```

---

### Task 4: The `groupTripsInDiveList` setting (schema v201)

**Files:**
- Modify: `lib/core/database/database.dart` (column, `currentSchemaVersion`, `migrationVersions`, `_assertGroupTripsInDiveListColumn`, `onUpgrade` rung, `beforeOpen` backstop)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` field, ctor default, `copyWith`, setter, runtime `StateProvider`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (create + update + row mapping)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_applyDiverSettingDefaults`)
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier` setter)
- Test: `test/core/database/migration_v201_group_trips_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `AppSettings.groupTripsInDiveList` (`bool`, default `false`), `SettingsNotifier.setGroupTripsInDiveList(bool)`, and `final diveListGroupTripsProvider = StateProvider<bool>(...)` (runtime-scoped, seeded by `ref.read`). Task 7 reads the provider; Task 11 writes both.

**Before starting:** confirm 201 is still free.

```bash
grep -n "currentSchemaVersion = " lib/core/database/database.dart
gh pr view 1677 --json state,title 2>/dev/null | head -5
```

Settled during execution: main is at 200, this branch rebased onto it, so this rung is 201. If main has moved again, use `currentSchemaVersion + 1`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v201_group_trips_test.dart`, mirroring `migration_v198_planner_water_type_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  group('v201 group trips in dive list', () {
    test('v201 is at or below the current version and is in the ladder', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(201));
      expect(AppDatabase.migrationVersions, contains(201));
    });

    test('a fresh database has the column, defaulting to off', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final row = cols.firstWhere(
        (c) => c.read<String>('name') == 'group_trips_in_dive_list',
      );

      expect(row.read<int>('notnull'), 1);
      expect(row.read<String>('dflt_value'), '0');
    });

    test('a database stranded without the column gains it on open', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      await db.customStatement(
        'ALTER TABLE diver_settings DROP COLUMN group_trips_in_dive_list',
      );
      await db.assertGroupTripsInDiveListColumnForTesting();

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      expect(
        cols.map((c) => c.read<String>('name')),
        contains('group_trips_in_dive_list'),
      );
    });
  });
}
```

Match the exact structure of `test/core/database/migration_v198_planner_water_type_test.dart` where it differs from the above; that file is the template, this is the shape.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v201_group_trips_test.dart`
Expected: FAIL on the ladder assertion (200 is not >= 201).

- [ ] **Step 3: Add the column and the rung**

In `lib/core/database/database.dart`, in `class DiverSettings extends Table`, after the list-view-mode columns:

```dart
  /// Fold consecutive same-trip dives under a trip header in the dive list
  /// (v201, issue #1193). Off by default: grouping changes list structure, so
  /// existing divers opt in.
  BoolColumn get groupTripsInDiveList =>
      boolean().withDefault(const Constant(false))();
```

Bump the version:

```dart
  static const int currentSchemaVersion = 201;
```

Append to `migrationVersions`, after `199,`:

```dart
    // v201: diver_settings.group_trips_in_dive_list -- inline collapsible trip
    // groups in the dive list (#1193). Additive defaulted boolean, no
    // backfill. 200 shipped with the transmitter
    // registry; the equipment assembly program may take 202.
    201,
```

Add the idempotent helper beside `_assertDefaultPlannerWaterTypeColumn`:

```dart
  /// Idempotent DDL for diver_settings.group_trips_in_dive_list (v201).
  /// Existing rows default to off, matching a fresh install.
  Future<void> _assertGroupTripsInDiveListColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('group_trips_in_dive_list')) return;
    await customStatement(
      'ALTER TABLE diver_settings ADD COLUMN group_trips_in_dive_list '
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// Test hook for the v201 rung, so a stranded-database case can drive the
  /// assert directly.
  @visibleForTesting
  Future<void> assertGroupTripsInDiveListColumnForTesting() =>
      _assertGroupTripsInDiveListColumn();
```

In `onUpgrade`, after the v199 pair:

```dart
        // v201: diver_settings.group_trips_in_dive_list (#1193). Column-only
        // rung, no backfill.
        if (from < 201) {
          await _assertGroupTripsInDiveListColumn();
        }
        if (from < 201) await reportProgress();
```

In `beforeOpen`, after the v199 backstop:

```dart
        // v201 backstop: re-assert diver_settings.group_trips_in_dive_list.
        await _assertGroupTripsInDiveListColumn();
```

If `@visibleForTesting` is not already imported in `database.dart`, add `import 'package:meta/meta.dart';` or use the `foundation` import the file already carries.

- [ ] **Step 4: Regenerate Drift output and run the migration test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v201_group_trips_test.dart
```

Expected: PASS.

- [ ] **Step 5: Wire the setting through AppSettings**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

Field, beside the other dive-list display settings:

```dart
  /// Fold consecutive same-trip dives under a trip header in the dive list
  /// (#1193).
  final bool groupTripsInDiveList;
```

Constructor default:

```dart
    this.groupTripsInDiveList = false,
```

`copyWith` parameter and body:

```dart
    bool? groupTripsInDiveList,
```
```dart
      groupTripsInDiveList: groupTripsInDiveList ?? this.groupTripsInDiveList,
```

Notifier setter, beside `setShowMapBackgroundOnDiveCards`:

```dart
  Future<void> setGroupTripsInDiveList(bool value) async {
    state = state.copyWith(groupTripsInDiveList: value);
    await _saveSettings();
  }
```

Runtime provider, directly below `diveListViewModeProvider`:

```dart
/// Runtime-scoped "group trips" toggle for the dive list.
///
/// Same contract as [diveListViewModeProvider]: seeded once with `ref.read`
/// so an unrelated settings write cannot stomp a session override.
final diveListGroupTripsProvider = StateProvider<bool>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.groupTripsInDiveList;
});
```

In `lib/features/settings/data/repositories/diver_settings_repository.dart`, add to `_mapRowToAppSettings`:

```dart
      groupTripsInDiveList: row.groupTripsInDiveList,
```

and to both `createSettingsForDiver` and `updateSettingsForDiver` companions:

```dart
        groupTripsInDiveList: Value(settings.groupTripsInDiveList),
```

(use `s.groupTripsInDiveList` in `createSettingsForDiver` if that is the local variable name there).

In `lib/core/services/sync/sync_data_serializer.dart`, inside `_applyDiverSettingDefaults`, beside `'showMapBackgroundOnDiveCards': false,`:

```dart
      'groupTripsInDiveList': false,
```

In `test/helpers/mock_providers.dart`, in `MockSettingsNotifier`, beside the other overridden setters:

```dart
  @override
  Future<void> setGroupTripsInDiveList(bool value) async =>
      state = state.copyWith(groupTripsInDiveList: value);
```

- [ ] **Step 6: Run the settings and database suites**

Run:

```bash
flutter test test/core/database/ test/features/settings/
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/features/settings lib/core/services/sync/sync_data_serializer.dart test/core/database/migration_v201_group_trips_test.dart test/helpers/mock_providers.dart
git commit -m "feat(settings): add the group-trips dive list setting (schema v201) (#1193)"
```

---

### Task 5: Collapsed trip ids in SharedPreferences

**Files:**
- Create: `lib/features/dive_log/presentation/providers/trip_group_collapse_provider.dart`
- Test: `test/features/dive_log/presentation/providers/trip_group_collapse_provider_test.dart` (create)

**Interfaces:**
- Consumes: `sharedPreferencesProvider` (already exists, stubbed by `getBaseOverrides`), `currentDiverIdProvider`.
- Produces: `class CollapsedTripsNotifier extends StateNotifier<Set<String>>` with `void toggle(String tripId)`, `void collapseAll(Iterable<String> tripIds)`, `void expandAll()`; and `final collapsedTripIdsProvider = StateNotifierProvider<CollapsedTripsNotifier, Set<String>>(...)`. Tasks 6, 9 and 11 consume these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/trip_group_collapse_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('collapsedTripIdsProvider', () {
    test('starts empty', () async {
      final container = await makeContainer();
      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });

    test('toggle adds then removes a trip id', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.toggle('t1');
      expect(container.read(collapsedTripIdsProvider), {'t1'});

      notifier.toggle('t1');
      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });

    test('a collapsed id survives a new container reading the same prefs',
        () async {
      final container = await makeContainer();
      container.read(collapsedTripIdsProvider.notifier).toggle('t1');

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);

      expect(second.read(collapsedTripIdsProvider), {'t1'});
    });

    test('collapseAll and expandAll replace the whole set', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.collapseAll(['t1', 't2']);
      expect(container.read(collapsedTripIdsProvider), {'t1', 't2'});

      notifier.expandAll();
      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });
  });
}
```

Check the exact name and location of `sharedPreferencesProvider` first:

```bash
grep -rn "sharedPreferencesProvider" lib/core/providers/provider.dart | head -3
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/trip_group_collapse_provider_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Implement the notifier**

Create `lib/features/dive_log/presentation/providers/trip_group_collapse_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';

/// Preference key holding the ids of trips folded shut in the dive list.
///
/// Device-local on purpose. Which trips a diver has tidied away is browsing
/// state, not logbook data, so it stays out of the synced settings row rather
/// than pushing an ever-growing id blob through sync.
const String kCollapsedTripIdsPrefsKey = 'dive_list_collapsed_trip_ids';

/// Trips folded shut in the dive list, persisted across restarts.
class CollapsedTripsNotifier extends StateNotifier<Set<String>> {
  CollapsedTripsNotifier(this._prefs)
    : super(_prefs.getStringList(kCollapsedTripIdsPrefsKey)?.toSet() ?? {});

  final SharedPreferences _prefs;

  /// Fold [tripId] shut, or open it again.
  void toggle(String tripId) {
    final next = Set<String>.from(state);
    if (!next.remove(tripId)) next.add(tripId);
    _write(next);
  }

  /// Fold every trip in [tripIds] shut, keeping anything already collapsed.
  void collapseAll(Iterable<String> tripIds) {
    _write({...state, ...tripIds});
  }

  /// Open every trip.
  void expandAll() => _write({});

  void _write(Set<String> next) {
    state = next;
    // Fire and forget: the in-memory set is the source of truth for this
    // session, and a failed write costs a collapsed trip, not data.
    _prefs.setStringList(kCollapsedTripIdsPrefsKey, next.toList());
  }
}

final collapsedTripIdsProvider =
    StateNotifierProvider<CollapsedTripsNotifier, Set<String>>((ref) {
      return CollapsedTripsNotifier(ref.watch(sharedPreferencesProvider));
    });
```

If `sharedPreferencesProvider` is asynchronous in this codebase (a `FutureProvider`), adapt by reading `.requireValue` and adjust the test overrides to match; check before writing.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/trip_group_collapse_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/providers/trip_group_collapse_provider.dart test/features/dive_log/presentation/providers/trip_group_collapse_provider_test.dart
git commit -m "feat(dive-log): persist collapsed trip groups per device (#1193)"
```

---

### Task 6: The `buildDiveListSections` pure function

**Files:**
- Create: `lib/features/dive_log/presentation/helpers/dive_list_sections.dart`
- Test: `test/features/dive_log/presentation/helpers/dive_list_sections_test.dart` (create)

**Interfaces:**
- Consumes: `DiveSummary` trip fields (Task 1), the trip counts map (Task 3), the collapsed set (Task 5).
- Produces:
  - `sealed class DiveListSection`
  - `class LooseSection extends DiveListSection { final List<DiveListEntry> entries; }`
  - `class TripSection extends DiveListSection { final String tripId; final String tripName; final DateTime? startDate; final DateTime? endDate; final List<DiveListEntry> entries; final bool collapsed; final int totalCount; int get loadedCount; }`
  - `class DiveListEntry { final DiveSummary dive; final int flatIndex; }`
  - `List<DiveListSection> buildDiveListSections({required List<DiveSummary> dives, required bool groupingEnabled, required Set<String> collapsedTripIds, required Map<String, int> tripTotals, String? forceExpandedTripId})`
  - `List<DiveSummary> visibleDivesOf(List<DiveListSection> sections)`

  Tasks 8, 9 and 10 use these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/helpers/dive_list_sections_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';

void main() {
  DiveSummary dive(String id, {String? tripId, String? tripName}) {
    return DiveSummary(
      id: id,
      dateTime: DateTime(2026, 6, 8),
      sortTimestamp: 0,
      tripId: tripId,
      tripName: tripName,
      tripStartDate: tripId == null ? null : DateTime(2026, 6, 8),
      tripEndDate: tripId == null ? null : DateTime(2026, 6, 9),
    );
  }

  group('buildDiveListSections', () {
    test('grouping off yields one loose section holding every dive', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie'), dive('d2')],
        groupingEnabled: false,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(1));
      expect(sections.single, isA<LooseSection>());
      expect((sections.single as LooseSection).entries, hasLength(2));
    });

    test('a run of same-trip dives becomes one trip section', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
          dive('d4'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(3));
      expect(sections[0], isA<LooseSection>());
      expect(sections[2], isA<LooseSection>());

      final trip = sections[1] as TripSection;
      expect(trip.tripId, 't1');
      expect(trip.tripName, 'Tassie');
      expect(trip.loadedCount, 2);
      expect(trip.totalCount, 4);
      expect(trip.collapsed, isFalse);
    });

    test('a trip interrupted by a loose dive yields two sections, both '
        'labelled with the trip total', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(3));
      expect((sections[0] as TripSection).totalCount, 4);
      expect((sections[2] as TripSection).totalCount, 4);
    });

    test('entries keep their original flat index', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 2},
      );

      final trip = sections[1] as TripSection;
      expect(trip.entries.map((e) => e.flatIndex), [1, 2]);
    });

    test('a collapsed trip keeps its entries but reports collapsed', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
      );

      final trip = sections.single as TripSection;
      expect(trip.collapsed, isTrue);
      expect(trip.entries, hasLength(1));
    });

    test('forceExpandedTripId overrides a collapsed trip', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
        forceExpandedTripId: 't1',
      );

      expect((sections.single as TripSection).collapsed, isFalse);
    });

    test('a trip with no known total falls back to the loaded count', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {},
      );

      expect((sections.single as TripSection).totalCount, 1);
    });

    test('visibleDivesOf skips dives inside a collapsed trip', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
      );

      expect(visibleDivesOf(sections).map((d) => d.id), ['d1', 'd3']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_list_sections_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Implement the function**

Create `lib/features/dive_log/presentation/helpers/dive_list_sections.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// One dive in the list, paired with its position in the flat, ungrouped list.
///
/// The flat index is load-bearing: the detailed card falls back to
/// `diveNumber ?? flatIndex + 1` for its leading badge, and the detail page's
/// prev/next walks flat list order. A position within a section would be
/// wrong for both.
class DiveListEntry {
  const DiveListEntry({required this.dive, required this.flatIndex});

  final DiveSummary dive;
  final int flatIndex;
}

/// A run of rows in the dive list: either loose dives or one trip's dives.
sealed class DiveListSection {
  const DiveListSection();

  List<DiveListEntry> get entries;
}

/// Consecutive dives that belong to no trip.
class LooseSection extends DiveListSection {
  const LooseSection(this.entries);

  @override
  final List<DiveListEntry> entries;
}

/// Consecutive dives that belong to the same trip.
///
/// Sections are runs, not sets. A trip interrupted by a loose dive produces
/// two sections for the same trip, both labelled with the trip's real total,
/// so it reads as "this trip, continued". Gathering a trip's dives out of date
/// order would break the chronological sort the list is built on.
class TripSection extends DiveListSection {
  const TripSection({
    required this.tripId,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.collapsed,
    required this.totalCount,
  });

  final String tripId;
  final String tripName;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  final List<DiveListEntry> entries;

  final bool collapsed;

  /// Every dive on this trip, filter and pagination independent.
  final int totalCount;

  /// Dives from this trip currently in the list.
  int get loadedCount => entries.length;

  /// True when the list holds fewer of this trip than the trip really has, so
  /// the header should read "6 of 14" rather than a bare count.
  bool get isPartial => loadedCount < totalCount;
}

/// Splits [dives] into loose runs and trip runs for rendering.
///
/// [dives] must already be in list order; this never reorders anything.
List<DiveListSection> buildDiveListSections({
  required List<DiveSummary> dives,
  required bool groupingEnabled,
  required Set<String> collapsedTripIds,
  required Map<String, int> tripTotals,
  String? forceExpandedTripId,
}) {
  final entries = [
    for (var i = 0; i < dives.length; i++)
      DiveListEntry(dive: dives[i], flatIndex: i),
  ];

  if (!groupingEnabled) {
    return entries.isEmpty ? const [] : [LooseSection(entries)];
  }

  final sections = <DiveListSection>[];
  var index = 0;

  while (index < entries.length) {
    final tripId = entries[index].dive.tripId;

    if (tripId == null) {
      final run = <DiveListEntry>[];
      while (index < entries.length && entries[index].dive.tripId == null) {
        run.add(entries[index]);
        index++;
      }
      sections.add(LooseSection(run));
      continue;
    }

    final run = <DiveListEntry>[];
    while (index < entries.length && entries[index].dive.tripId == tripId) {
      run.add(entries[index]);
      index++;
    }
    final head = run.first.dive;
    sections.add(
      TripSection(
        tripId: tripId,
        tripName: head.tripName ?? '',
        startDate: head.tripStartDate,
        endDate: head.tripEndDate,
        entries: run,
        collapsed:
            collapsedTripIds.contains(tripId) && tripId != forceExpandedTripId,
        // An unknown total means the counts query has not resolved yet. Fall
        // back to what is loaded so the header never claims fewer dives than
        // it is showing.
        totalCount: tripTotals[tripId] ?? run.length,
      ),
    );
  }

  return sections;
}

/// The dives a diver can actually see, in order.
///
/// Dives inside a collapsed trip are excluded, so a shift-range does not sweep
/// up rows that are folded away.
List<DiveSummary> visibleDivesOf(List<DiveListSection> sections) {
  return [
    for (final section in sections)
      if (section is! TripSection || !section.collapsed)
        for (final entry in section.entries) entry.dive,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_list_sections_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/helpers/dive_list_sections.dart test/features/dive_log/presentation/helpers/dive_list_sections_test.dart
git commit -m "feat(dive-log): split the dive list into loose and trip sections (#1193)"
```

---

### Task 7: The grouping-enabled gate

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_list_grouping_enabled_test.dart` (create)

**Interfaces:**
- Consumes: `diveListGroupTripsProvider` (Task 4), `diveSortProvider`, `diveListViewModeProvider`.
- Produces: `final diveListGroupingEnabledProvider = Provider<bool>(...)`. Tasks 9, 11 and 12 read it.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/dive_list_grouping_enabled_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  ProviderContainer makeContainer({
    required bool toggle,
    required DiveSortField sortField,
    required ListViewMode viewMode,
  }) {
    final container = ProviderContainer(
      overrides: [
        diveListGroupTripsProvider.overrideWith((ref) => toggle),
        diveSortProvider.overrideWith(
          (ref) => SortState(
            field: sortField,
            direction: SortDirection.descending,
          ),
        ),
        diveListViewModeProvider.overrideWith((ref) => viewMode),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('diveListGroupingEnabledProvider', () {
    test('on under a date sort in detailed mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isTrue);
    });

    test('on under a dive-number sort in compact mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.diveNumber,
        viewMode: ListViewMode.compact,
      );
      expect(container.read(diveListGroupingEnabledProvider), isTrue);
    });

    test('off when the toggle is off', () {
      final container = makeContainer(
        toggle: false,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('off under a depth sort', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.depth,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('off in table mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.table,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/dive_list_grouping_enabled_test.dart`
Expected: FAIL, `Undefined name 'diveListGroupingEnabledProvider'`.

- [ ] **Step 3: Implement the gate**

Add to `lib/features/dive_log/presentation/providers/dive_providers.dart`:

```dart
/// Sort fields under which a trip's dives stay contiguous.
///
/// Both are chronological in practice, so a trip forms a single run. Under any
/// other sort a trip scatters, and grouping would fragment a 14-dive trip into
/// a dozen one-dive headers, which is noisier than no grouping at all.
const Set<DiveSortField> kChronologicalDiveSortFields = {
  DiveSortField.date,
  DiveSortField.diveNumber,
};

/// Whether the dive list should render trip group headers right now.
///
/// The toggle alone is not enough: grouping also needs a chronological sort
/// and a card view mode. One place to reason about it, rather than the same
/// three conditions repeated at every call site.
final diveListGroupingEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(diveListGroupTripsProvider)) return false;
  final sort = ref.watch(diveSortProvider);
  if (!kChronologicalDiveSortFields.contains(sort.field)) return false;
  return ref.watch(diveListViewModeProvider) != ListViewMode.table;
});
```

Add whatever imports the file is missing (`list_view_mode.dart`, `settings_providers.dart`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/dive_list_grouping_enabled_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/dive_list_grouping_enabled_test.dart
git commit -m "feat(dive-log): gate trip grouping on sort and view mode (#1193)"
```

---

### Task 8: The trip group header widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/trip_group_header.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the other ten ARB files
- Modify: `lib/l10n/arb/app_localizations*.dart` (regenerated)
- Test: `test/features/dive_log/presentation/widgets/trip_group_header_test.dart` (create)

**Interfaces:**
- Consumes: `TripSection` (Task 6), `UnitFormatter.formatDateRange`.
- Produces:
  - `class TripGroupHeader extends ConsumerWidget` with named params `{required TripSection section, required VoidCallback onToggle, required VoidCallback onOpenTrip, bool isSelectionMode = false, bool? groupChecked, ValueChanged<bool?>? onGroupCheckedChanged}`
  - `class TripGroupHeaderDelegate extends SliverPersistentHeaderDelegate` with the same params plus `double extent`
  - `double tripGroupHeaderExtent(BuildContext context)`

  Task 9 constructs both; Task 10 passes the selection params.

- [ ] **Step 1: Add the l10n keys**

In `lib/l10n/arb/app_en.arb`, insert next to the existing `diveLog_listPage_search*` cluster:

```json
  "diveLog_listPage_tripGroupLabel": "TRIP",
  "diveLog_listPage_tripGroupDiveCount": "{count, plural, =1{1 dive} other{{count} dives}}",
  "diveLog_listPage_tripGroupDiveCountPartial": "{loaded} of {total} dives",
  "diveLog_listPage_tripGroupExpand": "Show dives on {tripName}",
  "diveLog_listPage_tripGroupCollapse": "Hide dives on {tripName}",
  "diveLog_listPage_tripGroupOpenTrip": "Open trip {tripName}",
```

and, in the `@`-metadata region of the same file (near the other `@diveLog_listPage_*` blocks):

```json
  "@diveLog_listPage_tripGroupDiveCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "@diveLog_listPage_tripGroupDiveCountPartial": {
    "description": "Dive count on a dive list trip header when only some of the trip's dives are in the list.",
    "placeholders": {
      "loaded": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "@diveLog_listPage_tripGroupExpand": {
    "placeholders": {
      "tripName": {
        "type": "String"
      }
    }
  },
  "@diveLog_listPage_tripGroupCollapse": {
    "placeholders": {
      "tripName": {
        "type": "String"
      }
    }
  },
  "@diveLog_listPage_tripGroupOpenTrip": {
    "placeholders": {
      "tripName": {
        "type": "String"
      }
    }
  },
```

Add the same six keys (translated, **no** `@` blocks) to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Those files are not alphabetical and each groups keys differently, so anchor the insert on the neighbouring **key** `diveLog_listPage_searchFieldLabel` in each file rather than on a line number.

Run `flutter gen-l10n` and confirm `git status` shows the regenerated `lib/l10n/arb/app_localizations*.dart` files as modified.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/trip_group_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  TripSection section({
    int loaded = 2,
    int total = 2,
    bool collapsed = false,
  }) {
    return TripSection(
      tripId: 't1',
      tripName: 'Tassie',
      startDate: DateTime(2026, 6, 8),
      endDate: DateTime(2026, 6, 9),
      entries: [
        for (var i = 0; i < loaded; i++)
          DiveListEntry(
            dive: DiveSummary(
              id: 'd$i',
              dateTime: DateTime(2026, 6, 8),
              sortTimestamp: 0,
              tripId: 't1',
              tripName: 'Tassie',
            ),
            flatIndex: i,
          ),
      ],
      collapsed: collapsed,
      totalCount: total,
    );
  }

  Future<void> pumpHeader(
    WidgetTester tester, {
    required TripSection value,
    VoidCallback? onToggle,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: TripGroupHeader(
          section: value,
          onToggle: onToggle ?? () {},
          onOpenTrip: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TripGroupHeader', () {
    testWidgets('shows the trip name', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.text('Tassie'), findsOneWidget);
    });

    testWidgets('shows a plain count when the whole trip is loaded',
        (tester) async {
      await pumpHeader(tester, value: section(loaded: 4, total: 4));
      expect(find.textContaining('4 dives'), findsOneWidget);
      expect(find.textContaining('of'), findsNothing);
    });

    testWidgets('shows "6 of 14 dives" when only part of the trip is loaded',
        (tester) async {
      await pumpHeader(tester, value: section(loaded: 6, total: 14));
      expect(find.textContaining('6 of 14 dives'), findsOneWidget);
    });

    testWidgets('tapping anywhere on the header toggles', (tester) async {
      var toggled = 0;
      await pumpHeader(
        tester,
        value: section(),
        onToggle: () => toggled++,
      );

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });

    testWidgets('the chevron points down when expanded and right when '
        'collapsed', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await pumpHeader(tester, value: section(collapsed: true));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/trip_group_header_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 4: Implement the header and its delegate**

Create `lib/features/dive_log/presentation/widgets/trip_group_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/extensions/context_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Base height of a trip group header at the default text scale.
const double _kHeaderBaseExtent = 60;

/// Height of the pinned trip header, grown for the ambient text scale.
///
/// A pinned sliver header needs a fixed extent, so this cannot be left to
/// intrinsic sizing: at 200% text a hardcoded height would clip the second
/// line, and widget tests running at standard density would never see it.
double tripGroupHeaderExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return _kHeaderBaseExtent * scale.clamp(1.0, 2.0);
}

/// Header for one run of same-trip dives in the dive list.
///
/// Tapping anywhere toggles the group: the whole band is the target, not just
/// the chevron. Opening the trip itself has its own button, because the dive
/// cards below already spend tap and double-tap.
class TripGroupHeader extends ConsumerWidget {
  const TripGroupHeader({
    super.key,
    required this.section,
    required this.onToggle,
    required this.onOpenTrip,
    this.isSelectionMode = false,
    this.groupChecked,
    this.onGroupCheckedChanged,
  });

  final TripSection section;
  final VoidCallback onToggle;
  final VoidCallback onOpenTrip;

  /// In selection mode the open-trip button gives way to a tri-state checkbox
  /// covering the group's loaded dives.
  final bool isSelectionMode;
  final bool? groupChecked;
  final ValueChanged<bool?>? onGroupCheckedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));

    final countText = section.isPartial
        ? l10n.diveLog_listPage_tripGroupDiveCountPartial(
            section.loadedCount,
            section.totalCount,
          )
        : l10n.diveLog_listPage_tripGroupDiveCount(section.totalCount);

    final dateText = units.formatDateRange(
      section.startDate,
      section.endDate,
      l10n: l10n,
    );

    return Semantics(
      button: true,
      label: section.collapsed
          ? l10n.diveLog_listPage_tripGroupExpand(section.tripName)
          : l10n.diveLog_listPage_tripGroupCollapse(section.tripName),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Material(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: double.infinity,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.card_travel,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.diveLog_listPage_tripGroupLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              section.tripName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$dateText  ·  $countText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelectionMode)
                  Checkbox(
                    tristate: true,
                    value: groupChecked,
                    onChanged: onGroupCheckedChanged,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: l10n.diveLog_listPage_tripGroupOpenTrip(
                      section.tripName,
                    ),
                    onPressed: onOpenTrip,
                  ),
                Icon(
                  section.collapsed ? Icons.chevron_right : Icons.expand_more,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins a [TripGroupHeader] to the top of its own group.
///
/// Bounded by the enclosing `SliverMainAxisGroup`, so it releases when the
/// next group arrives instead of stacking.
class TripGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const TripGroupHeaderDelegate({
    required this.section,
    required this.extent,
    required this.onToggle,
    required this.onOpenTrip,
    this.isSelectionMode = false,
    this.groupChecked,
    this.onGroupCheckedChanged,
  });

  final TripSection section;
  final double extent;
  final VoidCallback onToggle;
  final VoidCallback onOpenTrip;
  final bool isSelectionMode;
  final bool? groupChecked;
  final ValueChanged<bool?>? onGroupCheckedChanged;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: TripGroupHeader(
        section: section,
        onToggle: onToggle,
        onOpenTrip: onOpenTrip,
        isSelectionMode: isSelectionMode,
        groupChecked: groupChecked,
        onGroupCheckedChanged: onGroupCheckedChanged,
      ),
    );
  }

  @override
  bool shouldRebuild(TripGroupHeaderDelegate oldDelegate) {
    return oldDelegate.section.tripId != section.tripId ||
        oldDelegate.section.collapsed != section.collapsed ||
        oldDelegate.section.loadedCount != section.loadedCount ||
        oldDelegate.section.totalCount != section.totalCount ||
        oldDelegate.extent != extent ||
        oldDelegate.isSelectionMode != isSelectionMode ||
        oldDelegate.groupChecked != groupChecked;
  }
}
```

If `context.l10n` lives in a different extension file, use whatever import `dive_list_content.dart` already uses for it.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/trip_group_header_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter gen-l10n
git add lib/features/dive_log/presentation/widgets/trip_group_header.dart lib/l10n test/features/dive_log/presentation/widgets/trip_group_header_test.dart
git commit -m "feat(dive-log): add the trip group header for the dive list (#1193)"
```

---

### Task 9: Rebuild the dive list as a sliver scroll view

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildDiveList`, near line 1481)
- Test: `test/features/dive_log/presentation/widgets/dive_list_trip_grouping_test.dart` (create)

**Interfaces:**
- Consumes: `buildDiveListSections`, `LooseSection`, `TripSection`, `DiveListEntry`, `visibleDivesOf` (Task 6); `TripGroupHeader`, `TripGroupHeaderDelegate`, `tripGroupHeaderExtent` (Task 8); `diveListGroupingEnabledProvider` (Task 7); `collapsedTripIdsProvider` (Task 5); `tripDiveCountsProvider` (Task 3).
- Produces: a `CustomScrollView`-based dive list. Task 10 extends its selection handling; Task 12 adds a leading notice sliver.

**This is the largest task.** The existing `_buildDiveList` body up to and including the `itemCount` computation stays exactly as it is; only the returned widget tree changes.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_list_trip_grouping_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives, {bool hasMore = false})
    : super(
        AsyncValue.data(
          PaginatedDiveListState(dives: dives, hasMore: hasMore),
        ),
      );

  int loadNextPageCalls = 0;

  @override
  Future<void> loadNextPage() async {
    loadNextPageCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  DiveSummary dive(String id, {String? tripId, String? tripName}) {
    return DiveSummary(
      id: id,
      diveNumber: int.parse(id.substring(1)),
      name: 'Dive $id',
      dateTime: DateTime(2026, 6, 8),
      sortTimestamp: 0,
      tripId: tripId,
      tripName: tripName,
      tripStartDate: tripId == null ? null : DateTime(2026, 6, 8),
      tripEndDate: tripId == null ? null : DateTime(2026, 6, 9),
    );
  }

  Future<List<Override>> overridesFor(
    List<DiveSummary> dives, {
    bool grouping = true,
    Map<String, int> tripTotals = const {},
    _MockPaginatedNotifier? notifier,
  }) async {
    final base = await getBaseOverrides();
    return [
      ...base,
      diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
      diveListGroupTripsProvider.overrideWith((ref) => grouping),
      tripDiveCountsProvider.overrideWith((ref) async => tripTotals),
      paginatedDiveListProvider.overrideWith(
        (ref) => notifier ?? _MockPaginatedNotifier(dives),
      ),
    ];
  }

  group('dive list trip grouping', () {
    testWidgets('a trip header appears above its dives', (tester) async {
      final overrides = await overridesFor(
        [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        tripTotals: const {'t1': 2},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
      expect(find.text('Tassie'), findsOneWidget);
    });

    testWidgets('grouped dive cards are exactly as wide as loose ones',
        (tester) async {
      final overrides = await overridesFor(
        [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
        ],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      final loose = tester.getSize(
        find.ancestor(
          of: find.text('Dive d1'),
          matching: find.byType(Card),
        ).first,
      );
      final grouped = tester.getSize(
        find.ancestor(
          of: find.text('Dive d2'),
          matching: find.byType(Card),
        ).first,
      );

      expect(
        grouped.width,
        loose.width,
        reason: 'grouping must never narrow a dive card (#1193)',
      );
    });

    testWidgets('tapping the header hides the trip dives', (tester) async {
      final overrides = await overridesFor(
        [dive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dive d1'), findsOneWidget);

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(find.text('Dive d1'), findsNothing);
      expect(find.byType(TripGroupHeader), findsOneWidget);
    });

    testWidgets('no headers when grouping is off', (tester) async {
      final overrides = await overridesFor(
        [dive('d1', tripId: 't1', tripName: 'Tassie')],
        grouping: false,
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsNothing);
      expect(find.text('Dive d1'), findsOneWidget);
    });

    testWidgets('a fully collapsed page still asks for the next one',
        (tester) async {
      final dives = [
        for (var i = 0; i < 8; i++)
          dive('d$i', tripId: 't1', tripName: 'Tassie'),
      ];
      final notifier = _MockPaginatedNotifier(dives, hasMore: true);
      final overrides = await overridesFor(
        dives,
        tripTotals: const {'t1': 40},
        notifier: notifier,
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(
        notifier.loadNextPageCalls,
        greaterThan(0),
        reason: 'the sentinel must keep paging when every dive is hidden',
      );
      expect(
        notifier.loadNextPageCalls,
        lessThan(20),
        reason: 'and must not spin in a loop',
      );
    });
  });
}
```

Confirm `DiveListContent`'s constructor parameter is `showAppBar` before running; copy the exact pump shape from `dive_list_content_test.dart` if it differs.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_trip_grouping_test.dart`
Expected: FAIL, no `TripGroupHeader` found.

- [ ] **Step 3: Replace the returned tree in `_buildDiveList`**

Keep everything in `_buildDiveList` above the `return RefreshIndicator(` unchanged. Insert this directly before the return:

```dart
    final groupingEnabled = ref.watch(diveListGroupingEnabledProvider);
    final collapsedTripIds = ref.watch(collapsedTripIdsProvider);
    final tripTotals =
        ref.watch(tripDiveCountsProvider).whenOrNull(data: (m) => m) ??
        const <String, int>{};

    // Never fold away the dive the diver is looking at.
    final openDiveTripId = dives
        .where(
          (d) =>
              d.id == widget.selectedId ||
              d.id == ref.watch(highlightedDiveIdProvider),
        )
        .map((d) => d.tripId)
        .whereType<String>()
        .firstOrNull;

    final sections = buildDiveListSections(
      dives: dives,
      groupingEnabled: groupingEnabled,
      collapsedTripIds: collapsedTripIds,
      tripTotals: tripTotals,
      forceExpandedTripId: openDiveTripId,
    );

    // Range selection and prev/next walk what the diver can actually see, so
    // a shift-range never sweeps up rows folded inside a collapsed trip.
    final visibleDives = visibleDivesOf(sections);

    final showTrailingRow =
        paginatedState.hasMore || paginatedState.isLoadingMore;
```

Then replace the returned tree with:

```dart
    return RefreshIndicator(
      onRefresh: () => ref.read(paginatedDiveListProvider.notifier).refresh(),
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                for (final section in sections)
                  if (section is TripSection)
                    _buildTripSectionSliver(context, section, visibleDives)
                  else
                    _buildDiveSliverList(
                      context,
                      section.entries,
                      visibleDives,
                    ),
                if (showTrailingRow)
                  SliverToBoxAdapter(
                    child: _buildTrailingRow(context, paginatedState),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The trailing loader or retry row.
  ///
  /// Deliberately a built widget rather than a scroll-offset check: when the
  /// list shrinks under a position already at the bottom, or when collapsed
  /// trips leave a freshly loaded page almost entirely invisible, Flutter
  /// clamps the offset during layout without notifying scroll listeners.
  /// Building this row is the only signal that survives (#1610).
  Widget _buildTrailingRow(
    BuildContext context,
    PaginatedDiveListState paginatedState,
  ) {
    if (paginatedState.loadMoreFailed) {
      return _buildLoadMoreFailedRow(context);
    }
    _loadNextPageIfStranded(paginatedState);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// A run of dive rows, with no group chrome.
  Widget _buildDiveSliverList(
    BuildContext context,
    List<DiveListEntry> entries,
    List<DiveSummary> visibleDives,
  ) {
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) =>
          _buildDiveRow(context, entries[index], visibleDives),
    );
  }

  /// One trip: a faint full-bleed band behind a pinned header and its dives.
  ///
  /// The band is a [DecoratedSliver] rather than a wrapping widget so the rows
  /// stay lazily built, and so the grouped region is WIDER than the cards it
  /// contains. Nothing here may touch the cards' own margins (#1193).
  Widget _buildTripSectionSliver(
    BuildContext context,
    TripSection section,
    List<DiveSummary> visibleDives,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.14),
        border: Border(
          top: BorderSide(
            color: scheme.secondary.withValues(alpha: 0.22),
          ),
          bottom: BorderSide(
            color: scheme.secondary.withValues(alpha: 0.22),
          ),
        ),
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TripGroupHeaderDelegate(
              section: section,
              extent: tripGroupHeaderExtent(context),
              onToggle: () => ref
                  .read(collapsedTripIdsProvider.notifier)
                  .toggle(section.tripId),
              onOpenTrip: () => context.push('/trips/${section.tripId}'),
            ),
          ),
          if (!section.collapsed)
            _buildDiveSliverList(context, section.entries, visibleDives),
        ],
      ),
    );
  }
```

Finally add `_buildDiveRow`, which is the old `itemBuilder` body verbatim with the index replaced by the entry's flat index:

```dart
  Widget _buildDiveRow(
    BuildContext context,
    DiveListEntry entry,
    List<DiveSummary> visibleDives,
  ) {
    final dive = entry.dive;
    final isSelected = _selectedIds.contains(dive.id);
    final isMasterSelected = widget.selectedId == dive.id;
    final isHighlighted = ref.watch(highlightedDiveIdProvider) == dive.id;
    // Shared renderer: honours the active view mode and card config, and
    // keeps the home Recent dives list in sync (#506).
    return DiveListItem(
      summary: dive,
      diveTypeLabelResolver: _diveTypeLabelResolver!,
      diveTypeShortLabelResolver: _diveTypeShortLabelResolver!,
      diveTypeListVisibilityPredicate: _diveTypeListVisibilityPredicate!,
      fullDive: _fullDiveLookup[dive.id],
      diveNumber: dive.diveNumber ?? entry.flatIndex + 1,
      colorValue: getCardColorValue(dive, _colorAttribute!),
      minValueInList: _minColorValue,
      maxValueInList: _maxColorValue,
      gradientStartColor: _gradientColors!.start,
      gradientEndColor: _gradientColors!.end,
      isSelectionMode: _isSelectionMode,
      isChecked: isSelected,
      isHighlighted: isMasterSelected || isHighlighted,
      onTap: () => _handleRowTap(dive.id, visibleDives),
    );
  }
```

The per-build values (`diveTypeLabelResolver`, `fullDiveLookup`, the colour range, the gradient) are currently locals inside `_buildDiveList`. Promote each to a nullable field on `_DiveListContentState` assigned at the top of `_buildDiveList`, exactly as the field names above imply (`_diveTypeLabelResolver`, `_diveTypeShortLabelResolver`, `_diveTypeListVisibilityPredicate`, `_fullDiveLookup`, `_colorAttribute`, `_minColorValue`, `_maxColorValue`, `_gradientColors`). They are recomputed on every build before any row is built, so a row can never read a stale one.

Add the imports `dive_list_sections.dart`, `trip_group_header.dart`, `trip_group_collapse_provider.dart`, and `package:collection/collection.dart` if `firstOrNull` is not already available.

- [ ] **Step 4: Run the new tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_trip_grouping_test.dart`
Expected: PASS, 5 tests, including the width assertion.

- [ ] **Step 5: Run every existing dive list test**

Run: `flutter test test/features/dive_log/`
Expected: PASS. `dive_list_scroll_retention_test.dart` and `dive_list_selection_test.dart` exercise the scroll and selection paths this task rewrote; if either fails, fix the production code rather than loosening the test, unless the test asserts on `ListView` specifically, in which case update it to `CustomScrollView`.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_trip_grouping_test.dart
git commit -m "feat(dive-log): render trip groups as pinned-header slivers (#1193)"
```

---

### Task 10: Group selection

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildTripSectionSliver`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_trip_grouping_selection_test.dart` (create)

**Interfaces:**
- Consumes: `SelectionController.selectAll(List<String>)`, `.replaceChecked(List<String>)`, and `TripSection` from Task 6.
- Produces: no new public names.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_list_trip_grouping_selection_test.dart`. Reuse the `_MockPaginatedNotifier`, `dive()` and `overridesFor()` helpers from Task 9's test file verbatim (copy them in; the two files are independent), then:

```dart
  group('trip group selection', () {
    testWidgets('the group checkbox selects every loaded dive in the trip',
        (tester) async {
      final overrides = await overridesFor(
        [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        tripTotals: const {'t1': 2},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode by checking one dive's own checkbox.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final headerCheckbox = find.descendant(
        of: find.byType(TripGroupHeader),
        matching: find.byType(Checkbox),
      );
      expect(headerCheckbox, findsOneWidget);

      await tester.tap(headerCheckbox);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(headerCheckbox).value,
        isTrue,
      );
    });
  });
```

Adjust the "enter selection mode" step to whatever gesture the existing `dive_list_selection_test.dart` uses; copy it from there rather than inventing one.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_trip_grouping_selection_test.dart`
Expected: FAIL, no `Checkbox` inside the header.

- [ ] **Step 3: Wire the checkbox**

In `_buildTripSectionSliver`, compute the group's state and pass it to the delegate:

```dart
    final groupIds = section.entries.map((e) => e.dive.id).toList();
    final checkedInGroup = groupIds.where(_selectedIds.contains).length;
    final bool? groupChecked = checkedInGroup == 0
        ? false
        : (checkedInGroup == groupIds.length ? true : null);
```

and in the `TripGroupHeaderDelegate(...)` call add:

```dart
              isSelectionMode: _isSelectionMode,
              groupChecked: groupChecked,
              onGroupCheckedChanged: (_) {
                // Loaded dives only, matching the existing select-all: the
                // list can only act on rows it holds.
                if (checkedInGroup == groupIds.length) {
                  _selection.replaceChecked(
                    _selectedIds.where((id) => !groupIds.contains(id)).toList(),
                  );
                } else {
                  _selection.selectAll([..._selectedIds, ...groupIds]);
                }
                setState(() {});
              },
```

If `SelectionController` notifies listeners and the widget already rebuilds from it, drop the `setState(() {})`; check how `_toggleSelection` triggers a rebuild and match it exactly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_trip_grouping_selection_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the whole selection suite**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_trip_grouping_selection_test.dart
git commit -m "feat(dive-log): select a whole trip group from its header (#1193)"
```

---

### Task 11: The "Group trips" menu item

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (both `PopupMenuButton`s, near lines 1031 and 1201)
- Modify: `lib/l10n/arb/*.arb` (11 files) and the regenerated `app_localizations*.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_grouping_menu_test.dart` (create)

**Interfaces:**
- Consumes: `diveListGroupTripsProvider` and `SettingsNotifier.setGroupTripsInDiveList` (Task 4), `collapsedTripIdsProvider` (Task 5).
- Produces: no new public names.

- [ ] **Step 1: Add the l10n keys**

To `app_en.arb`, beside the keys added in Task 8:

```json
  "diveLog_listPage_menuGroupTrips": "Group trips",
  "diveLog_listPage_menuExpandAllTrips": "Expand all trips",
  "diveLog_listPage_menuCollapseAllTrips": "Collapse all trips",
```

No `@` metadata needed (no placeholders). Add translations of the same three keys to the other ten ARB files, anchored on `diveLog_listPage_tripGroupLabel` in each. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_list_grouping_menu_test.dart`, reusing the `dive()` / `overridesFor()` helpers from Task 9's test file and rendering `DiveListContent` with `showAppBar: true`:

```dart
    testWidgets('the overflow menu offers Group trips and it is checked when on',
        (tester) async {
      final overrides = await overridesFor(
        [dive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Group trips'), findsOneWidget);
      expect(find.text('Collapse all trips'), findsOneWidget);
    });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_grouping_menu_test.dart`
Expected: FAIL, `Group trips` not found.

- [ ] **Step 4: Add the items to both menus**

In the wide app bar's `PopupMenuButton.onSelected`, add before the `view_` branch:

```dart
            } else if (value == 'group_trips') {
              final next = !ref.read(diveListGroupTripsProvider);
              ref.read(diveListGroupTripsProvider.notifier).state = next;
              ref.read(settingsProvider.notifier).setGroupTripsInDiveList(next);
            } else if (value == 'expand_all_trips') {
              ref.read(collapsedTripIdsProvider.notifier).expandAll();
            } else if (value == 'collapse_all_trips') {
              ref.read(collapsedTripIdsProvider.notifier).collapseAll(
                    _visibleTripIds(),
                  );
```

and in its `itemBuilder`, directly after the `...ListViewModeToggle.menuItems(...)` spread:

```dart
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'group_trips',
                checked: ref.watch(diveListGroupTripsProvider),
                child: Text(context.l10n.diveLog_listPage_menuGroupTrips),
              ),
              if (ref.watch(diveListGroupingEnabledProvider)) ...[
                PopupMenuItem(
                  value: 'expand_all_trips',
                  child: Text(
                    context.l10n.diveLog_listPage_menuExpandAllTrips,
                  ),
                ),
                PopupMenuItem(
                  value: 'collapse_all_trips',
                  child: Text(
                    context.l10n.diveLog_listPage_menuCollapseAllTrips,
                  ),
                ),
              ],
```

Make the identical additions to the compact app bar's menu near line 1201. The compact menu's icons use `size: 20`; these items are text-only, so nothing changes there.

Add the helper used by "collapse all":

```dart
  /// Trip ids present in the loaded list, so Collapse all folds what is on
  /// screen rather than every trip the diver has ever logged.
  List<String> _visibleTripIds() {
    final dives =
        ref.read(paginatedDiveListProvider).value?.dives ?? const <DiveSummary>[];
    return dives.map((d) => d.tripId).whereType<String>().toSet().toList();
  }
```

Note both menus read `currentMode` with `ref.read` inside `itemBuilder`; use `ref.watch` for the checked state as written above so the tick renders correctly when the menu is rebuilt.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_grouping_menu_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter gen-l10n
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/l10n test/features/dive_log/presentation/widgets/dive_list_grouping_menu_test.dart
git commit -m "feat(dive-log): add the Group trips toggle to the dive list menus (#1193)"
```

---

### Task 12: The grouping-paused notice

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildDiveList` slivers)
- Modify: `lib/l10n/arb/*.arb` (11 files) and the regenerated `app_localizations*.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_grouping_paused_test.dart` (create)

**Interfaces:**
- Consumes: `diveListGroupTripsProvider`, `diveListGroupingEnabledProvider`, `diveSortProvider`.
- Produces: no new public names.

- [ ] **Step 1: Add the l10n keys**

To `app_en.arb`, beside the Task 11 keys:

```json
  "diveLog_listPage_groupingPausedBySort": "Trip grouping is off while sorted by {sortName}",
  "diveLog_listPage_groupingPausedAction": "Sort by date",
```

and in the metadata region:

```json
  "@diveLog_listPage_groupingPausedBySort": {
    "description": "Shown above the dive list when the Group trips toggle is on but the active sort scatters a trip's dives.",
    "placeholders": {
      "sortName": {
        "type": "String"
      }
    }
  },
```

Add both keys to the other ten ARB files, anchored on `diveLog_listPage_menuGroupTrips`. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_list_grouping_paused_test.dart`, reusing Task 9's helpers and adding a `diveSortProvider` override:

```dart
    testWidgets('a depth sort pauses grouping and says so', (tester) async {
      final base = await overridesFor(
        [dive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );
      final overrides = [
        ...base,
        diveSortProvider.overrideWith(
          (ref) => const SortState(
            field: DiveSortField.depth,
            direction: SortDirection.descending,
          ),
        ),
      ];

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsNothing);
      expect(find.textContaining('Trip grouping is off'), findsOneWidget);
      expect(find.text('Sort by date'), findsOneWidget);
    });

    testWidgets('the action restores the date sort and the groups',
        (tester) async {
      // same setup as above
      await tester.tap(find.text('Sort by date'));
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
    });
```

Write the second test out in full with its own setup rather than relying on the comment.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_grouping_paused_test.dart`
Expected: FAIL, notice text not found.

- [ ] **Step 4: Add the notice sliver**

In `_buildDiveList`, add above the sections loop in the `slivers:` list:

```dart
                if (ref.watch(diveListGroupTripsProvider) && !groupingEnabled)
                  SliverToBoxAdapter(child: _buildGroupingPausedNotice(context)),
```

and add the builder:

```dart
  /// Explains why the trip headers are missing while the toggle is on.
  ///
  /// Not folded into the active-filters bar: that bar only exists when a
  /// filter is active, and a paused grouping is not a filter.
  Widget _buildGroupingPausedNotice(BuildContext context) {
    final theme = Theme.of(context);
    final sort = ref.watch(diveSortProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.diveLog_listPage_groupingPausedBySort(
                sortFieldLabel(context, sort.field),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(diveSortProvider.notifier).state = const SortState(
                field: DiveSortField.date,
                direction: SortDirection.descending,
              );
            },
            child: Text(context.l10n.diveLog_listPage_groupingPausedAction),
          ),
        ],
      ),
    );
  }
```

`sortFieldLabel(context, field)` must be the existing localized sort-field label helper. Find it with:

```bash
grep -rn "DiveSortField" lib/features/dive_log/presentation/ lib/shared/ | grep -i "label\|name" | head
```

and use that exact function. The sort bottom sheet at `dive_list_content.dart:879` already renders these labels, so the helper exists; if it turns out to be a private method on another widget, promote it to a shared helper file in the same commit rather than duplicating the switch.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_grouping_paused_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter gen-l10n
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/l10n test/features/dive_log/presentation/widgets/dive_list_grouping_paused_test.dart
git commit -m "feat(dive-log): explain when trip grouping is paused by the sort (#1193)"
```

---

### Task 13: Full verification

**Files:** none created; fixes only.

- [ ] **Step 1: Format and analyze the whole project**

Run:

```bash
dart format .
flutter analyze --fatal-infos 2>&1 | tail -20
```

Expected: `No issues found!`. Do not pipe analyze through `grep`, which hides the exit status.

- [ ] **Step 2: Confirm the generated l10n is not stale**

Run:

```bash
flutter gen-l10n && git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'
```

Expected: empty output. Any listed file means a regenerated artifact was not committed; commit it.

- [ ] **Step 3: Run the full test suite once**

Run: `flutter test 2>&1 | tail -30`
Expected: all tests pass. One full run is enough; do not overlap it with another local run.

- [ ] **Step 4: Check the summary query's cost on a large library**

Run: `flutter test test/core/database/query_plan_test.dart test/features/dive_log/presentation/providers/paginated_dive_list_page_retention_test.dart`
Expected: PASS. The `trips` join must resolve by primary key. If the plan shows a scan of `trips`, stop and investigate before merging.

- [ ] **Step 5: Smoke test on a device**

Run the app, turn on Group trips, and confirm by eye:
- a trip header appears above a run of trip dives, with the band behind it,
- the header pins while scrolling through a long trip and releases at the next group,
- collapsing a trip and restarting the app keeps it collapsed,
- switching the sort to Deepest first hides the headers and shows the notice,
- table mode is unchanged.

- [ ] **Step 6: Commit any fixes**

```bash
dart format .
git add -u
git commit -m "chore(dive-log): verification fixes for trip grouping (#1193)"
```

Stage explicit paths rather than `git add -A`, which can sweep edits from sibling worktrees.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: data (1, 2), trip totals (3), settings and persistence (4, 5), grouping model (6), gating (7), header widget (8), sliver structure and the width constraint (9), selection (10), chrome (11, 12), testing (spread across all tasks plus 13). The spec's "auto-expand the group holding the open dive" rule is implemented in Task 9 via `forceExpandedTripId` and unit-tested in Task 6.

**Type consistency.** `TripSection`, `LooseSection`, `DiveListEntry`, `buildDiveListSections`, `visibleDivesOf`, `collapsedTripIdsProvider`, `CollapsedTripsNotifier.toggle/collapseAll/expandAll`, `tripDiveCountsProvider`, `diveListGroupTripsProvider`, `diveListGroupingEnabledProvider`, `TripGroupHeader`, `TripGroupHeaderDelegate` and `tripGroupHeaderExtent` are spelled identically in the tasks that define them and the tasks that consume them.

**Known soft spots**, flagged deliberately rather than papered over: three call sites depend on names this plan could not fully verify without running the app, and each carries an inline instruction to grep for the real one first: the dive-change tick provider in Task 3, the async-or-sync shape of `sharedPreferencesProvider` in Task 5, and the localized sort-field label helper in Task 12.
