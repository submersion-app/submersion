# Trip Gas Logistics PR 4: Fill Forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell the diver whether the trip's full cylinders cover today and tomorrow, and when to fill: one line on the trip's cylinders card, a banner and a strip of planned days on the board, the trip's "Divers sharing cylinders" and "Dives per day", and fill hours on dive centers.

**Architecture:** Schema v249 adds five nullable or defaulted columns (trips, itinerary days, dive centers); the entities and repositories carry them. A pure `computeFillForecast` in the trips domain turns the trip calendar, the itinerary, the slots' statuses, today's logged dives and the fill station's hours into demand, supply, shortfalls and a deadline. `tripFillForecastProvider` gathers those inputs and refreshes itself at the deadline and at midnight. The card, the board banner and the day strip read it; tapping a day writes that day's planned dives on the itinerary, creating a single itinerary row when the trip has none for that date.

**Tech Stack:** Flutter, Riverpod (via `core/providers/provider.dart`), Drift (in-memory in tests), `package:clock`, `flutter gen-l10n` (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-25-trip-gas-logistics-design.md` (sections "Phase 2, its own rung", "Phase 2 forecasting", "Testing", "Delivery" item 4).

## Global Constraints

- Branch `ericgriffin/trip-gas-forecast`, cut from `origin/main` after PR 3 (#2578) merged. The PR body carries `Part of #2325`.
- Schema version **249**. 248 is held by #2585 (open). Re-check before pushing: `gh pr list --state open` diffs for `currentSchemaVersion = 249`, and update the ladder memory note with the claim.
- The sync floor (`minimumCompatibleSchemaVersion`, 240) does not move: every column is additive and nullable or defaulted.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, strings, commits, PR text).
- No tool attribution of any kind (the contributor guide's Attribution section) in commits, PR text or review replies; no co-author trailer.
- Every new string in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- Times of day go through `UnitFormatter` (the diver's 12 or 24 hour setting). Never `TimeOfDay.format(context)` (architecture guard `preference_aware_date_format_test.dart`).
- Number fields use `numberInputFormatters()` and `numberValidator` / `readNumber` (architecture guard `number_parsing_single_source_test.dart`).
- Codegen after any table edit: `grep build_runner scripts/setup.sh | sh` (a bare `build` token in a Bash command is refused).
- Imports grouped dart, flutter, packages, local; `dart format .`; `dart analyze --fatal-infos <touched files>` prints "No issues found!" before each commit; new files stay under 400 lines.
- TDD: every task starts with a failing test. Run tests with `TMPDIR=<scratchpad>/tmp flutter test <paths>`, never overlapping runs.
- A test that replaces process-wide state puts it back (CI bundles test files in one isolate).

### Decided with the user (2026-09-29)

- **Tomorrow's supply** is the full cylinders left once today's remaining dives have used theirs: `max(0, full - todayDemand)`, not the full count now.
- **Fractions round up.** Planned dives per day from the expected-dives spread or the history median is `ceil`.
- **Both lines, today first.** When today is short, the card shows today's line and then tomorrow's (when tomorrow is also short), both in the error colour; the first line shown carries the fill deadline.
- **A tapped day with no itinerary row gets one**: a single `trip_itinerary_days` row for that date, typed dive day, carrying the planned dives. An itinerary may therefore cover only some days.

### Rulings in this plan (for the user's review)

- **R1, per-date itinerary.** Because an itinerary may now be partial, a trip day is a dive day when its row is typed dive day **or it has no row**. The forecast, the scrubber margin (which today treats any itinerary as the whole trip) and the liveaboard "Generate itinerary" button (which today hides once any row exists) all use this rule, through one helper. For a trip with no itinerary, and for a full one, nothing changes.
- **R2, logged dives.** Dives already logged on the trip today reduce today's *planned dives* before the multiplication by divers sharing: `max(0, planned - logged) * divers`. The spec's "today's demand is reduced by dives already logged" read literally (`planned * divers - logged`) would undercount a shared bottle for every dive one diver logs.
- **R3, expected dives spread** over the whole trip's dive days (not the remaining ones), as the scrubber margin reads `expectedDives`.
- **R4, the fill station** is the dive center `lastTripFillCenter` already picks for the fill sheet (the newest of the slots' latest fills that names a center). The helper moves from the fill sheet into the trips domain so the forecast and the sheet share it.
- **R5, fill hours** are `fill_opens_at` and `fill_closes_at`, minutes after local midnight (the spec's names). Both or neither, and closing after opening: one daily window, no overnight hours (the spec leaves weekday schedules out of scope).
- **R6, refresh.** The forecast provider schedules one timer to rebuild itself at the fill deadline while it is ahead, else at the next local midnight; nothing else about "now" is watched.
- **R7, the day editor** offers 0 to 12 planned dives per day. An explicit 0 is a rest day; "Use the estimate" returns the day to the fallback chain.
- **R8, divers sharing** saves as 1 when blank, zero or negative, as the trip form already treats its other planning fields.
- **R9, export.** UDDF and CSV exports do not carry the new fields, as they do not carry `expectedDives` or `returnFlightAt` today.

## Review Focus

1. Saving the trip edit page or the dive center edit page rebuilds the whole entity, so a new field it forgets is reset on every edit (sharing back to 1, fill hours to none). Pinned in Task 10 ("editing keeps the fill forecast fields") and Task 11 ("editing keeps the fill hours").
2. A single planned day on a shore trip must not collapse the scrubber margin's dive-day count to one, and a liveaboard with one planned day must still offer "Generate itinerary", which then adds only the missing days. Pinned in Task 4 ("a partial itinerary counts its uncovered days", "a partial itinerary still offers Generate").
3. Two saves of one day's plan in quick succession never leave two itinerary rows for one date (the table has no uniqueness constraint). Pinned in Task 3 ("two plans for one day at once leave one row").
4. Editing the trip's dates regenerates the itinerary; a day's planned dives must survive it, as its type and notes do. Pinned in Task 3 ("updateDay and regenerateForTrip keep the plan").
5. A dive logged at 23:30 wall clock counts for its own day in any device timezone, and a dive at 00:10 the next day does not. Pinned in Task 6 ("dives count by their wall-clock day").

---

## File Structure

| File | Responsibility |
| --- | --- |
| Modify `lib/core/database/tables/trip_tables.dart`, `site_tables.dart` | The five v249 columns |
| Modify `lib/core/database/migrations/helpers/trip_migrations.dart`, `ladder/rungs_v231_onward.dart`, `before_open.dart`, `lib/core/database/database.dart` | Rung, backstop, ladder, version |
| Modify `lib/features/trips/domain/entities/trip.dart`, `itinerary_day.dart`, `lib/features/dive_centers/domain/entities/dive_center.dart` | The new fields |
| Modify `lib/features/trips/data/repositories/trip_repository.dart`, `itinerary_day_repository.dart`, `lib/features/dive_centers/data/repositories/dive_center_repository.dart` | Carry the fields; `setPlannedDives` |
| Create `lib/features/trips/domain/services/trip_dive_days.dart` | Pure per-date dive-day rule (R1) |
| Modify `lib/features/trips/presentation/providers/scrubber_margin_providers.dart`, `widgets/story/trip_story_hero.dart` | Use the per-date rule |
| Modify `lib/features/trips/domain/services/scrubber_margin_service.dart` | `medianOf` made public |
| Create `lib/features/trips/domain/services/fill_forecast.dart` | Pure `computeFillForecast`, `fillForecastNextRefresh` |
| Modify `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`, `widgets/cylinders/trip_cylinder_fill_sheet.dart` | `lastTripFillCenter` moves to the domain |
| Modify `lib/features/trips/data/repositories/trip_cylinder_repository.dart` | `countTripDivesOn` |
| Create `lib/features/trips/presentation/providers/trip_fill_forecast_providers.dart` | `tripFillForecastProvider` |
| Modify all 11 `lib/l10n/arb/app_*.arb` + generated files | 23 new keys |
| Modify `lib/core/utils/unit_formatter.dart` | `formatMinutesOfDay` |
| Modify `lib/features/trips/presentation/helpers/trip_cylinder_display.dart` | `tripFillForecastLines` |
| Create `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart` | Card text and board banner |
| Create `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart` | Day strip and day plan dialog |
| Modify `lib/features/trips/presentation/widgets/trip_cylinders_card.dart`, `pages/trip_cylinder_board_page.dart` | Show the forecast |
| Modify `lib/features/trips/presentation/pages/trip_edit_page.dart` | Two Planning fields |
| Create `lib/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart` | Fill hours rows and validation |
| Modify `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart` | Fill hours section |

---

### Task 1: Schema v249

**Files:**
- Modify: `lib/core/database/tables/trip_tables.dart` (`Trips` after `expectedRuntimeMinutes`; `TripItineraryDays` after `notes`)
- Modify: `lib/core/database/tables/site_tables.dart` (`DiveCenters` after `notes`)
- Modify: `lib/core/database/migrations/helpers/trip_migrations.dart` (append to `extension TripMigrations`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v247 block)
- Modify: `lib/core/database/migrations/before_open.dart` (top of `_beforeOpen`)
- Modify: `lib/core/database/database.dart:230` (`currentSchemaVersion`) and the end of `migrationVersions`
- Create: `test/core/database/migration_v249_trip_fill_forecast_test.dart`
- Modify: `test/core/database/migration_v247_dive_derived_metrics_test.dart:59-67`

**Interfaces:**
- Produces: Drift columns `Trips.diversSharingCylinders` (int, default 1), `Trips.divesPerDayTarget` (int?), `TripItineraryDays.plannedDives` (int?), `DiveCenters.fillOpensAt` and `DiveCenters.fillClosesAt` (int?); SQL names `divers_sharing_cylinders`, `dives_per_day_target`, `planned_dives`, `fill_opens_at`, `fill_closes_at`. Generated companions gain the same named parameters.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v249_trip_fill_forecast_test.dart`:

```dart
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v249: the trip fill forecast's inputs (issue #2325, PR 4). Columns only,
/// no backfill: trips.divers_sharing_cylinders (not null, default 1),
/// trips.dives_per_day_target, trip_itinerary_days.planned_dives, and the
/// dive center fill hours in minutes after local midnight. 248 is held by
/// #2585. The sync floor does not move: an older peer ignores the columns,
/// and the serializer fills the not-null default for a payload without it.
void main() {
  const expected = {
    'trips': {'divers_sharing_cylinders', 'dives_per_day_target'},
    'trip_itinerary_days': {'planned_dives'},
    'dive_centers': {'fill_opens_at', 'fill_closes_at'},
  };

  Future<Map<String, QueryRow>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final r in rows) r.read<String>('name'): r};
  }

  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY, name TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE trip_itinerary_days (id TEXT NOT NULL PRIMARY KEY)',
      );
      rawDb.execute('CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute("INSERT INTO trips (id, name) VALUES ('t1', 'Bonaire')");
    },
  );

  test('v249 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 249);
    expect(AppDatabase.migrationVersions, contains(249));
    expect(AppDatabase.migrationVersions, isNot(contains(248)));
    expect(AppDatabase.migrationStepCount(247), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has every column; sharing is not null, 1', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      final cols = await columns(db, table);
      for (final name in names) {
        expect(cols.keys, contains(name), reason: '$table.$name');
      }
    }
    final sharing = (await columns(db, 'trips'))['divers_sharing_cylinders']!;
    expect(sharing.read<int>('notnull'), 1);
    expect(sharing.read<String?>('dflt_value'), contains('1'));
    final target = (await columns(db, 'trips'))['dives_per_day_target']!;
    expect(target.read<int>('notnull'), 0);
  });

  test('a database at v247 gains the columns; its trip shares one', () async {
    final db = AppDatabase(strandedAt(247));
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      expect((await columns(db, table)).keys, containsAll(names));
    }
    final row = await db
        .customSelect(
          "SELECT divers_sharing_cylinders AS n FROM trips WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('n'), 1);
  });

  test('a database already at v249 without them regains them', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      expect((await columns(db, table)).keys, containsAll(names));
    }
  });
}
```

Relax the v247 pin in `test/core/database/migration_v247_dive_derived_metrics_test.dart` (lines 59-67) to:

```dart
  test('v247 is in the ladder', () {
    // Relaxed once v249 (the trip fill forecast) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(247));
    expect(AppDatabase.migrationVersions, contains(247));
    expect(AppDatabase.migrationStepCount(245), greaterThanOrEqualTo(1));
    // A device-local table: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/core/database/migration_v249_trip_fill_forecast_test.dart`
Expected: FAIL. `currentSchemaVersion` is 247, and the columns are missing.

- [ ] **Step 3: Declare the columns**

In `Trips` (`trip_tables.dart`), directly after `IntColumn get expectedRuntimeMinutes => integer().nullable()();`:

```dart

  /// v249: the fill forecast's inputs (issue #2325): how many divers breathe
  /// from the trip's cylinders, and a dives-per-day target (null derives
  /// it).
  IntColumn get diversSharingCylinders =>
      integer().withDefault(const Constant(1))();
  IntColumn get divesPerDayTarget => integer().nullable()();
```

In `TripItineraryDays`, directly after its `notes` column:

```dart

  /// v249: the day's planned dives for the fill forecast; null derives it.
  IntColumn get plannedDives => integer().nullable()();
```

In `DiveCenters` (`site_tables.dart`), directly after its `notes` column:

```dart

  /// v249: fill hours for the trip fill forecast, minutes after local
  /// midnight; null when unknown.
  IntColumn get fillOpensAt => integer().nullable()();
  IntColumn get fillClosesAt => integer().nullable()();
```

- [ ] **Step 4: Add the helper, the rung, the backstop and the ladder entry**

Append inside `extension TripMigrations on AppDatabase` in `helpers/trip_migrations.dart`, before its closing brace:

```dart

  /// v249: the fill forecast's inputs (issue #2325, PR 4). Additive columns,
  /// no backfill; idempotent, so it is also the beforeOpen backstop.
  Future<void> _assertTripFillForecastColumns() async {
    await _addColumnIfMissing(
      'trips',
      'divers_sharing_cylinders',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing('trips', 'dives_per_day_target', 'INTEGER');
    await _addColumnIfMissing(
      'trip_itinerary_days',
      'planned_dives',
      'INTEGER',
    );
    await _addColumnIfMissing('dive_centers', 'fill_opens_at', 'INTEGER');
    await _addColumnIfMissing('dive_centers', 'fill_closes_at', 'INTEGER');
  }
```

In `ladder/rungs_v231_onward.dart`, directly after `if (from < 247) await reportProgress();`:

```dart
    // v249: the trip fill forecast's inputs (issue #2325, PR 4). Columns
    // only, no backfill; re-asserted in beforeOpen. 248 is held by #2585.
    if (from < 249) {
      await _assertTripFillForecastColumns();
    }
    if (from < 249) await reportProgress();
```

At the top of `_beforeOpen` in `before_open.dart`, before `// v240 backstop`:

```dart
    // v249 backstop: the trip fill forecast's columns.
    await _assertTripFillForecastColumns();

```

In `database.dart`: set `static const int currentSchemaVersion = 249;` and append to `migrationVersions`, after the `247,` entry:

```dart
    // v249: the trip fill forecast's inputs (issue #2325, PR 4): trips
    // divers sharing and dives per day, itinerary planned dives, dive
    // center fill hours. Additive columns, so the floor does not move. 248
    // is held by #2585 (open).
    249,
```

- [ ] **Step 5: Run codegen**

Run: `grep build_runner scripts/setup.sh | sh`
Expected: `database.g.dart` regenerated; `git status --short lib/core/database` lists it modified.

- [ ] **Step 6: Run the migration tests and the sync suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/core/database/migration_v249_trip_fill_forecast_test.dart test/core/database/migration_v247_dive_derived_metrics_test.dart test/core/services/sync`
Expected: `All tests passed!` (the sync suite covers the serializer's schema-default fill for payloads without the new not-null column).

- [ ] **Step 7: Commit**

```bash
git add lib/core/database test/core/database/migration_v249_trip_fill_forecast_test.dart test/core/database/migration_v247_dive_derived_metrics_test.dart
git commit -m "feat(trips): schema v249 for the fill forecast (#2325)"
```

---

### Task 2: Trips and dive centers carry the new fields

**Files:**
- Modify: `lib/features/trips/domain/entities/trip.dart`
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`createTrip` ~:105-123, `updateTrip` ~:153-167, `_mapRowToTrip` ~:674, `_mapDataToTrip` ~:705)
- Modify: `lib/features/dive_centers/domain/entities/dive_center.dart`
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (`createDiveCenter` ~:140, `updateDiveCenter` ~:190, `_mapRowToDiveCenter` ~:340, `_mapCustomRowToDiveCenter` ~:363)
- Test: `test/features/trips/data/repositories/trip_repository_expected_fields_test.dart`, `test/features/trips/domain/entities/trip_test.dart`, `test/features/dive_centers/data/repositories/dive_center_repository_test.dart`, `test/features/dive_centers/domain/entities/dive_center_test.dart`

**Interfaces:**
- Consumes: the Task 1 columns.
- Produces:
  - `Trip.diversSharingCylinders` (int, default 1), `Trip.divesPerDayTarget` (int?); `Trip.copyWith({int? diversSharingCylinders, Object? divesPerDayTarget = _undefined})`.
  - `DiveCenter.fillOpensAt`, `DiveCenter.fillClosesAt` (int?, minutes after local midnight); `DiveCenter.copyWith({Object? fillOpensAt = _undefined, Object? fillClosesAt = _undefined})`.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `test/features/trips/data/repositories/trip_repository_expected_fields_test.dart`:

```dart

  test('the fill forecast fields round-trip through both mappers', () async {
    final repo = TripRepository();
    final created = await repo.createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        diversSharingCylinders: 3,
        divesPerDayTarget: 2,
      ),
    );
    final byId = await repo.getTripById(created.id);
    expect(byId!.diversSharingCylinders, 3);
    expect(byId.divesPerDayTarget, 2);
    final withStats = await repo.getAllTripsWithStats();
    expect(withStats.single.trip.diversSharingCylinders, 3);
    expect(withStats.single.trip.divesPerDayTarget, 2);

    await repo.updateTrip(
      byId.copyWith(diversSharingCylinders: 1, divesPerDayTarget: null),
    );
    final cleared = await repo.getTripById(created.id);
    expect(cleared!.diversSharingCylinders, 1);
    expect(cleared.divesPerDayTarget, isNull);
  });
```

Append to `main()` in `test/features/trips/domain/entities/trip_test.dart`:

```dart

  test('a trip shares its cylinders among one diver by default', () {
    final trip = Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(trip.diversSharingCylinders, 1);
    expect(trip.divesPerDayTarget, isNull);
    final planned = trip.copyWith(diversSharingCylinders: 3, divesPerDayTarget: 2);
    expect(planned.divesPerDayTarget, 2);
    expect(planned.copyWith(divesPerDayTarget: null).divesPerDayTarget, isNull);
    expect(planned.copyWith(name: 'x').diversSharingCylinders, 3);
    expect(planned, isNot(trip));
  });
```

Append to `main()` in `test/features/dive_centers/data/repositories/dive_center_repository_test.dart`:

```dart

  test('fill hours round-trip through both mappers and clear', () async {
    final created = await repository.createDiveCenter(
      createTestCenter(name: 'Dive Friends').copyWith(
        fillOpensAt: 480,
        fillClosesAt: 1020,
      ),
    );
    final byId = await repository.getDiveCenterById(created.id);
    expect(byId!.fillOpensAt, 480);
    expect(byId.fillClosesAt, 1020);
    final found = await repository.searchDiveCenters('Dive Friends');
    expect(found.single.fillClosesAt, 1020);

    await repository.updateDiveCenter(
      byId.copyWith(fillOpensAt: null, fillClosesAt: null),
    );
    final cleared = await repository.getDiveCenterById(created.id);
    expect(cleared!.fillOpensAt, isNull);
    expect(cleared.fillClosesAt, isNull);
  });
```

Append to `main()` in `test/features/dive_centers/domain/entities/dive_center_test.dart`:

```dart

  test('fill hours copy, clear and compare', () {
    final now = DateTime(2026);
    final center = DiveCenter(
      id: 'c1',
      name: 'Dive Friends',
      fillOpensAt: 480,
      fillClosesAt: 1020,
      createdAt: now,
      updatedAt: now,
    );
    expect(center.copyWith(name: 'x').fillClosesAt, 1020);
    expect(center.copyWith(fillOpensAt: null).fillOpensAt, isNull);
    expect(center.copyWith(fillClosesAt: 1080), isNot(center));
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/data/repositories/trip_repository_expected_fields_test.dart test/features/trips/domain/entities/trip_test.dart test/features/dive_centers/data/repositories/dive_center_repository_test.dart test/features/dive_centers/domain/entities/dive_center_test.dart`
Expected: FAIL to compile: `diversSharingCylinders`, `divesPerDayTarget`, `fillOpensAt` and `fillClosesAt` are undefined.

- [ ] **Step 3: Add the Trip fields**

In `trip.dart`, after `final int? expectedRuntimeMinutes;`:

```dart

  /// Fill forecast inputs (issue #2325, v249): the divers breathing from the
  /// trip's cylinders (at least 1), and a dives-per-day target (null derives
  /// it from the itinerary, the expected dives or recent trips).
  final int diversSharingCylinders;
  final int? divesPerDayTarget;
```

Constructor, after `this.expectedRuntimeMinutes,`: `this.diversSharingCylinders = 1,` and `this.divesPerDayTarget,`. In `copyWith`, parameters after `Object? expectedRuntimeMinutes = _undefined,`: `int? diversSharingCylinders,` and `Object? divesPerDayTarget = _undefined,`; body after `expectedRuntimeMinutes: ...`:

```dart
      diversSharingCylinders:
          diversSharingCylinders ?? this.diversSharingCylinders,
      divesPerDayTarget: divesPerDayTarget == _undefined
          ? this.divesPerDayTarget
          : divesPerDayTarget as int?,
```

`props`, after `expectedRuntimeMinutes,`: `diversSharingCylinders,` and `divesPerDayTarget,`.

- [ ] **Step 4: Carry them through TripRepository**

In both the `createTrip` and `updateTrip` companions, after `expectedRuntimeMinutes: Value(trip.expectedRuntimeMinutes),`:

```dart
              diversSharingCylinders: Value(trip.diversSharingCylinders),
              divesPerDayTarget: Value(trip.divesPerDayTarget),
```

In `_mapRowToTrip`, after `expectedRuntimeMinutes: row.expectedRuntimeMinutes,`:

```dart
      diversSharingCylinders: row.diversSharingCylinders,
      divesPerDayTarget: row.divesPerDayTarget,
```

In `_mapDataToTrip`, after `expectedRuntimeMinutes: data['expected_runtime_minutes'] as int?,`:

```dart
      diversSharingCylinders:
          (data['divers_sharing_cylinders'] as int?) ?? 1,
      divesPerDayTarget: data['dives_per_day_target'] as int?,
```

- [ ] **Step 5: Add the DiveCenter fields**

In `dive_center.dart`, after `final String notes;`:

```dart

  /// Fill hours (v249), minutes after local midnight: when the station fills
  /// cylinders, for the trip fill forecast's deadline. Both or neither.
  final int? fillOpensAt;
  final int? fillClosesAt;
```

Constructor, after `this.notes = '',`: `this.fillOpensAt,` and `this.fillClosesAt,`. In `copyWith`, parameters after `String? notes,`: `Object? fillOpensAt = _undefined,` and `Object? fillClosesAt = _undefined,`; body after `notes: notes ?? this.notes,`:

```dart
      fillOpensAt: fillOpensAt == _undefined
          ? this.fillOpensAt
          : fillOpensAt as int?,
      fillClosesAt: fillClosesAt == _undefined
          ? this.fillClosesAt
          : fillClosesAt as int?,
```

`props`, after `notes,`: `fillOpensAt,` and `fillClosesAt,`. At the end of the file:

```dart

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

- [ ] **Step 6: Carry them through DiveCenterRepository**

In both companions (create and update), after `notes: Value(center.notes),`:

```dart
              fillOpensAt: Value(center.fillOpensAt),
              fillClosesAt: Value(center.fillClosesAt),
```

In `_mapRowToDiveCenter`, after `notes: row.notes,`: `fillOpensAt: row.fillOpensAt,` and `fillClosesAt: row.fillClosesAt,`. In `_mapCustomRowToDiveCenter`, after the `notes:` line:

```dart
      fillOpensAt: row.data['fill_opens_at'] as int?,
      fillClosesAt: row.data['fill_closes_at'] as int?,
```

- [ ] **Step 7: Run the tests, then the two features' suites**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips test/features/dive_centers`
Expected: `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/trips/domain/entities/trip.dart lib/features/trips/data/repositories/trip_repository.dart lib/features/dive_centers/domain/entities/dive_center.dart lib/features/dive_centers/data/repositories/dive_center_repository.dart test/features/trips/data/repositories/trip_repository_expected_fields_test.dart test/features/trips/domain/entities/trip_test.dart test/features/dive_centers/data/repositories/dive_center_repository_test.dart test/features/dive_centers/domain/entities/dive_center_test.dart
git commit -m "feat(trips): trips and dive centers carry the forecast fields (#2325)"
```

---

### Task 3: Itinerary days carry planned dives; set one day's plan

**Files:**
- Modify: `lib/features/trips/domain/entities/itinerary_day.dart`
- Modify: `lib/features/trips/data/repositories/itinerary_day_repository.dart` (`saveAll` ~:64, `updateDay` ~:114, `regenerateForTrip` ~:218, `_mapRow` ~:258; new `setPlannedDives`)
- Test: `test/features/trips/data/repositories/itinerary_day_repository_test.dart`

**Interfaces:**
- Consumes: `TripItineraryDays.plannedDives` (Task 1).
- Produces:
  - `ItineraryDay.plannedDives` (int?); `ItineraryDay.copyWith({Object? plannedDives = _undefined})`.
  - `Future<void> ItineraryDayRepository.setPlannedDives({required String tripId, required DateTime date, required int? plannedDives})`

- [ ] **Step 1: Write the failing tests**

Append a group at the end of the top-level `group('ItineraryDayRepository', ...)` in `itinerary_day_repository_test.dart` (the file's `setUp` creates a trip from 2025-03-01 to 2025-03-07 as `testTripId`):

```dart

    group('planned dives (fill forecast)', () {
      test('a day with no row gets one, a dive day with its plan', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3, 14),
          plannedDives: 3,
        );
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.date, DateTime(2025, 3, 3));
        expect(days.single.dayNumber, 3);
        expect(days.single.dayType, DayType.diveDay);
        expect(days.single.plannedDives, 3);
      });

      test('a day with a row keeps it, its type and its notes', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 4,
            date: DateTime(2025, 3, 4),
            dayType: DayType.portDay,
            notes: 'Kralendijk',
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 4),
          plannedDives: 1,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.portDay);
        expect(day.notes, 'Kralendijk');
        expect(day.plannedDives, 1);
      });

      test('null returns a day to the estimate and keeps its row', () async {
        final date = DateTime(2025, 3, 3);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: date,
          plannedDives: 3,
        );
        await repository.setPlannedDives(
          tripId: testTripId,
          date: date,
          plannedDives: null,
        );
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.plannedDives, isNull);
      });

      test('null on a day with no row writes nothing', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: null,
        );
        expect(await repository.getByTripId(testTripId), isEmpty);
      });

      test('two plans for one day at once leave one row', () async {
        // The table has no (trip, date) uniqueness; the find and the insert
        // share one transaction, so the second write finds the first row.
        final date = DateTime(2025, 3, 3);
        await Future.wait([
          repository.setPlannedDives(
            tripId: testTripId,
            date: date,
            plannedDives: 2,
          ),
          repository.setPlannedDives(
            tripId: testTripId,
            date: date,
            plannedDives: 4,
          ),
        ]);
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.plannedDives, 4);
      });

      test('saveAll, updateDay and regenerateForTrip keep the plan', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 3,
            date: DateTime(2025, 3, 3),
          ).copyWith(plannedDives: 2),
        ]);
        final saved = (await repository.getByTripId(testTripId)).single;
        expect(saved.plannedDives, 2);

        await repository.updateDay(saved.copyWith(notes: 'Klein Bonaire'));
        expect((await repository.getByTripId(testTripId)).single.plannedDives, 2);

        await repository.regenerateForTrip(testTripId, startDate, endDate);
        final regenerated = await repository.getByTripId(testTripId);
        final third = regenerated.firstWhere(
          (d) => d.date == DateTime(2025, 3, 3),
        );
        expect(third.plannedDives, 2);
        expect(
          regenerated.where((d) => d.plannedDives != null),
          hasLength(1),
        );
      });
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/data/repositories/itinerary_day_repository_test.dart`
Expected: FAIL to compile: `setPlannedDives` and `plannedDives` are undefined.

- [ ] **Step 3: Add the field**

In `itinerary_day.dart`, after `final String notes;`:

```dart

  /// Planned dives on this day for the fill forecast (v249). Null derives
  /// it; an explicit 0 is a rest day.
  final int? plannedDives;
```

Constructor, after `this.notes = '',`: `this.plannedDives,`. In `copyWith`, after `String? notes,`: `Object? plannedDives = _undefined,`; body after `notes: notes ?? this.notes,`:

```dart
      plannedDives: plannedDives == _undefined
          ? this.plannedDives
          : plannedDives as int?,
```

`props`, after `notes,`: `plannedDives,`.

- [ ] **Step 4: Carry it through the repository and add setPlannedDives**

In `saveAll`'s companion, after `notes: Value(entry.day.notes),`: `plannedDives: Value(entry.day.plannedDives),`. In `updateDay`'s companion, after `notes: Value(day.notes),`: `plannedDives: Value(day.plannedDives),`, and change its doc comment's field list to "(dayType, portName, latitude, longitude, notes, plannedDives, updatedAt)". In `regenerateForTrip`'s merge `copyWith`, after `notes: oldDay.notes,`: `plannedDives: oldDay.plannedDives,`, and add "plannedDives" to the comment above it. In `_mapRow`, after `notes: row.notes,`: `plannedDives: row.plannedDives,`.

Add `import 'package:submersion/features/trips/domain/entities/trip.dart' show calendarDaysBetween;` and this method after `updateDay`:

```dart
  /// Sets one day's planned dives for the fill forecast; null returns the
  /// day to the estimate. A day with no itinerary row gets one, typed dive
  /// day (decided 2026-09-29: a trip may plan single days without an
  /// itinerary); null on such a day writes nothing. The find and the insert
  /// share one transaction, and the table has no (trip, date) uniqueness,
  /// so two quick saves cannot insert the day twice.
  Future<void> setPlannedDives({
    required String tripId,
    required DateTime date,
    required int? plannedDives,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      String? written;
      await _db.transaction(() async {
        final rows = await (_db.select(
          _db.tripItineraryDays,
        )..where((t) => t.tripId.equals(tripId))).get();
        final existing = rows.where((r) {
          final d = DateTime.fromMillisecondsSinceEpoch(r.date);
          return d.year == day.year && d.month == day.month && d.day == day.day;
        }).firstOrNull;
        if (existing != null) {
          await (_db.update(
            _db.tripItineraryDays,
          )..where((t) => t.id.equals(existing.id))).write(
            TripItineraryDaysCompanion(
              plannedDives: Value(plannedDives),
              updatedAt: Value(now),
            ),
          );
          written = existing.id;
        } else if (plannedDives != null) {
          final trip = await (_db.select(
            _db.trips,
          )..where((t) => t.id.equals(tripId))).getSingle();
          final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
          final id = _uuid.v4();
          await _db
              .into(_db.tripItineraryDays)
              .insert(
                TripItineraryDaysCompanion.insert(
                  id: id,
                  tripId: tripId,
                  dayNumber: calendarDaysBetween(start, day) + 1,
                  date: day.millisecondsSinceEpoch,
                  plannedDives: Value(plannedDives),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          written = id;
        }
        if (written case final id?) {
          await _syncRepository.markRecordPending(
            entityType: 'itineraryDays',
            recordId: id,
            localUpdatedAt: now,
          );
        }
      });
      if (written != null) SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set planned dives for trip $tripId on $day',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: Run the tests, then the trips suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/domain/entities/itinerary_day.dart lib/features/trips/data/repositories/itinerary_day_repository.dart test/features/trips/data/repositories/itinerary_day_repository_test.dart
git commit -m "feat(trips): itinerary days carry planned dives (#2325)"
```

---

### Task 4: One per-date dive-day rule (R1)

**Files:**
- Create: `lib/features/trips/domain/services/trip_dive_days.dart`
- Modify: `lib/features/trips/presentation/providers/scrubber_margin_providers.dart` (~:77-78 and ~:170-173)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_hero.dart` (:26, :87, `_generate` ~:190-197)
- Test: `test/features/trips/domain/services/trip_dive_days_test.dart`, `test/features/trips/presentation/providers/scrubber_margin_providers_test.dart`, `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`

**Interfaces:**
- Consumes: `ItineraryDay` (Task 3), `DayType` (`core/constants/enums.dart`).
- Produces:
  - `DateTime tripDay(DateTime date)`
  - `List<DateTime> tripDaysBetween(DateTime from, DateTime to)`
  - `Map<DateTime, ItineraryDay> itineraryByDay(List<ItineraryDay> itinerary)`
  - `bool isTripDiveDay(ItineraryDay? row)`
  - `int tripDiveDayCount({required DateTime start, required DateTime end, required List<ItineraryDay> itinerary})`

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/domain/services/trip_dive_days_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

void main() {
  final start = DateTime(2026, 3, 8);
  final end = DateTime(2026, 3, 14);

  ItineraryDay row(int day, DayType type) => ItineraryDay(
    id: 'i$day',
    tripId: 't1',
    dayNumber: day - 7,
    date: DateTime(2026, 3, day),
    dayType: type,
    createdAt: start,
    updatedAt: start,
  );

  test('the days between two dates, across a daylight-saving change', () {
    // 2026-03-08 is the US spring-forward: a 23-hour day.
    expect(tripDaysBetween(DateTime(2026, 3, 7, 18), DateTime(2026, 3, 9)), [
      DateTime(2026, 3, 7),
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 9),
    ]);
    expect(tripDaysBetween(end, start), isEmpty);
  });

  test('with no itinerary every trip day is a dive day', () {
    expect(tripDiveDayCount(start: start, end: end, itinerary: const []), 7);
  });

  test('a day typed otherwise is not; an uncovered day still is', () {
    expect(
      tripDiveDayCount(
        start: start,
        end: end,
        itinerary: [row(9, DayType.seaDay), row(10, DayType.diveDay)],
      ),
      6,
    );
    expect(isTripDiveDay(null), isTrue);
    expect(isTripDiveDay(row(9, DayType.embark)), isFalse);
  });

  test('rows outside the trip are ignored', () {
    expect(
      tripDiveDayCount(
        start: start,
        end: end,
        itinerary: [row(20, DayType.seaDay)],
      ),
      7,
    );
  });
}
```

Append to `main()` in `scrubber_margin_providers_test.dart`, after 'an itinerary with no dive days expects no dives':

```dart

  test('a partial itinerary counts its uncovered days as dive days', () async {
    // A single planned day (the board's day strip) is not a whole
    // itinerary: June 1 and 3 have no row and are dive days, June 2 is a
    // sea day. Two dive days at the default two dives.
    await rebreather();
    final t = await trip('Shore', DateTime(2026, 6, 1), DateTime(2026, 6, 3));
    await ItineraryDayRepository().saveAll([
      ItineraryDay(
        id: '',
        tripId: t.id,
        dayNumber: 2,
        date: DateTime(2026, 6, 2),
        dayType: DayType.seaDay,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final m = (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single;
    expect(m.expectedDives, 4);
  });
```

In `trip_story_hero_test.dart`, give `_story` an itinerary parameter (replace its `itineraryDays: [],` with `itineraryDays: itinerary,` and add `List<ItineraryDay> itinerary = const [],` to its parameters), then append to `main()`:

```dart

  testWidgets('a partial itinerary still offers Generate, which adds only '
      'the missing days', (tester) async {
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: _daysFrom(today, 40),
      end: _daysFrom(today, 43),
      tripType: TripType.liveaboard,
    );
    final planned = ItineraryDay(
      id: 'planned',
      tripId: trip.id,
      dayNumber: 2,
      date: _daysFrom(today, 41),
      dayType: DayType.diveDay,
      plannedDives: 3,
      createdAt: now,
      updatedAt: now,
    );
    final story = _story(trip, today: now, itinerary: [planned]);
    final fakeRepo = _FakeItineraryRepo();
    await pumpHero(
      tester,
      story,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(fakeRepo)],
    );

    await tester.tap(find.text('Generate itinerary'));
    await tester.pump();
    expect(fakeRepo.saved, hasLength(3));
    expect(
      fakeRepo.saved!.map((d) => d.date),
      isNot(contains(_daysFrom(today, 41))),
    );
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/trip_dive_days_test.dart test/features/trips/presentation/providers/scrubber_margin_providers_test.dart test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`
Expected: FAIL. The helper file does not exist; the scrubber margin expects 0 (the partial itinerary counts as the whole trip); the hero hides Generate.

- [ ] **Step 3: Write the helper**

Create `lib/features/trips/domain/services/trip_dive_days.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

/// Local midnight of [date]'s calendar day.
DateTime tripDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Every calendar day from [from] to [to], inclusive, by calendar arithmetic
/// so a daylight-saving change never drops or repeats a day. Empty when
/// [from] is after [to].
List<DateTime> tripDaysBetween(DateTime from, DateTime to) {
  final first = tripDay(from);
  final last = tripDay(to);
  return [
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// The itinerary row for each day, keyed by [tripDay].
Map<DateTime, ItineraryDay> itineraryByDay(List<ItineraryDay> itinerary) => {
  for (final d in itinerary) tripDay(d.date): d,
};

/// Pure. Whether a trip day is a dive day: its itinerary row says so, or it
/// has no row. An itinerary may cover only some days (a single planned day
/// from the board, decided 2026-09-29), so a day it does not cover is an
/// ordinary dive day, and a trip with no itinerary at all is all dive days.
bool isTripDiveDay(ItineraryDay? row) =>
    row == null || row.dayType == DayType.diveDay;

/// Pure. The trip's dive days from [start] to [end] under [isTripDiveDay];
/// itinerary rows outside the trip are ignored.
int tripDiveDayCount({
  required DateTime start,
  required DateTime end,
  required List<ItineraryDay> itinerary,
}) {
  final byDay = itineraryByDay(itinerary);
  return tripDaysBetween(
    start,
    end,
  ).where((d) => isTripDiveDay(byDay[d])).length;
}
```

- [ ] **Step 4: Use it in the scrubber margin and the story hero**

In `scrubber_margin_providers.dart`, replace

```dart
      final diveDays = days.where((d) => d.dayType == DayType.diveDay).length;
```

with

```dart
      final diveDays = tripDiveDayCount(
        start: trip.startDate,
        end: trip.endDate,
        itinerary: days,
      );
```

and replace

```dart
              // Only a missing itinerary falls back to the calendar: one
              // with no dive days (a crossing, a port stay) expects none.
              itineraryDiveDays: days.isEmpty ? trip.durationDays : diveDays,
```

with

```dart
              // Day by day: a day the itinerary types otherwise expects no
              // dives, and a day it does not cover is a dive day, so a trip
              // with no itinerary counts the calendar.
              itineraryDiveDays: diveDays,
```

Import `trip_dive_days.dart`; remove the `enums.dart` import only if the analyzer reports it unused.

In `trip_story_hero.dart`, replace

```dart
    final hasItinerary = story.days.any((d) => d.itineraryDay != null);
```

with

```dart
    // Every trip day has its row: a single planned day (the board's day
    // strip) is not an itinerary, so Generate stays until each day has one.
    final coversTrip = story.days
        .where((d) => trip.containsDate(d.date))
        .every((d) => d.itineraryDay != null);
```

change `!hasItinerary` at the Generate condition to `!coversTrip`, and in `_generate` replace the `final days = ItineraryDay.generateForTrip(...)` statement with:

```dart
      // Only the days the itinerary lacks: a planned day keeps its row.
      final covered = {
        for (final d in widget.story.days)
          if (d.itineraryDay != null) tripDay(d.date),
      };
      final days = ItineraryDay.generateForTrip(
        tripId: trip.id,
        startDate: trip.startDate,
        endDate: trip.endDate,
      ).where((d) => !covered.contains(tripDay(d.date))).toList();
```

Import `trip_dive_days.dart`. Update the double-tap comment above `if (_saving) return;` to say "would insert the missing days twice" instead of "two full batches".

- [ ] **Step 5: Run the tests, then the trips suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips`
Expected: `All tests passed!` (the existing 'an itinerary with no dive days expects no dives' still passes: its rows cover every trip day).

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/domain/services/trip_dive_days.dart lib/features/trips/presentation/providers/scrubber_margin_providers.dart lib/features/trips/presentation/widgets/story/trip_story_hero.dart test/features/trips/domain/services/trip_dive_days_test.dart test/features/trips/presentation/providers/scrubber_margin_providers_test.dart test/features/trips/presentation/widgets/story/trip_story_hero_test.dart
git commit -m "feat(trips): an itinerary may cover only some days (#2325)"
```

---

### Task 5: The pure forecast

**Files:**
- Create: `lib/features/trips/domain/services/fill_forecast.dart`
- Modify: `lib/features/trips/domain/services/scrubber_margin_service.dart` (`_median` becomes `medianOf`)
- Test: `test/features/trips/domain/services/fill_forecast_test.dart`

**Interfaces:**
- Consumes: Task 4's helpers; `defaultDivesPerDiveDay` (2.0) from `scrubber_margin_service.dart`.
- Produces:
  - `double medianOf(List<double> values)` (scrubber_margin_service.dart)
  - `class FillForecastDay { DateTime date; int plannedDives; bool isOverride; }`
  - `class FillForecastInputs { now, tripStart, tripEnd, slotCount, fullCount, partialCount, itinerary, divesPerDayTarget, expectedDives, divesPerDiveDayHistory, diversSharing, divesLoggedToday, fillOpensAt, fillClosesAt }`
  - `class FillForecast { fullCount, partialCount, todayDemand, tomorrowDemand, tomorrowSupply, todayShortfall, tomorrowShortfall, deadlineMinutes, remainingDemand, days; bool get caution, fillRunNeeded, isShort }`
  - `FillForecast? computeFillForecast(FillForecastInputs inputs)`
  - `DateTime fillForecastNextRefresh(DateTime now, FillForecast forecast)`

- [ ] **Step 1: Write the failing tests**

Every vector below is worked by hand in its comment. Create `test/features/trips/domain/services/fill_forecast_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';

void main() {
  // A seven-day trip; "now" is 09:00 on its third day, Mar 10.
  final start = DateTime(2026, 3, 8);
  final end = DateTime(2026, 3, 14);
  final morning = DateTime(2026, 3, 10, 9);

  ItineraryDay day(int d, {DayType type = DayType.diveDay, int? planned}) =>
      ItineraryDay(
        id: 'i$d',
        tripId: 't1',
        dayNumber: d - 7,
        date: DateTime(2026, 3, d),
        dayType: type,
        plannedDives: planned,
        createdAt: start,
        updatedAt: start,
      );

  FillForecast? forecast({
    DateTime? now,
    int full = 6,
    int partial = 1,
    int slots = 8,
    List<ItineraryDay> itinerary = const [],
    int? target,
    int? expected,
    List<double> history = const [],
    int divers = 1,
    int logged = 0,
    int? opens,
    int? closes,
  }) => computeFillForecast(
    FillForecastInputs(
      now: now ?? morning,
      tripStart: start,
      tripEnd: end,
      slotCount: slots,
      fullCount: full,
      partialCount: partial,
      itinerary: itinerary,
      divesPerDayTarget: target,
      expectedDives: expected,
      divesPerDiveDayHistory: history,
      diversSharing: divers,
      divesLoggedToday: logged,
      fillOpensAt: opens,
      fillClosesAt: closes,
    ),
  );

  List<int> planned(FillForecast f) => [
    for (final d in f.days) d.plannedDives,
  ];

  group('planned dives per day, first match wins', () {
    test('nothing set: two a day, today through the last day', () {
      final f = forecast()!;
      expect(f.days.first.date, DateTime(2026, 3, 10));
      expect(planned(f), [2, 2, 2, 2, 2]);
    });

    test('the median of recent trips, rounded up', () {
      // Median of 2.0 and 3.0 is 2.5, rounded up to 3.
      expect(planned(forecast(history: [2.0, 3.0])!).first, 3);
    });

    test('the expected dives spread over the dive days beat history', () {
      // 15 dives over 7 dive days is 2.14 a day, rounded up to 3.
      expect(planned(forecast(expected: 15, history: [1.0])!).first, 3);
    });

    test('the spread counts only dive days', () {
      // Mar 12 is a sea day: 13 dives over 6 dive days is 2.17, so 3 (over
      // 7 it would be 1.86, so 2). The sea day plans none.
      final f = forecast(
        expected: 13,
        itinerary: [day(12, type: DayType.seaDay)],
      )!;
      expect(planned(f), [3, 3, 0, 3, 3]);
    });

    test('the trip target beats the expected dives', () {
      expect(planned(forecast(target: 4, expected: 15)!).first, 4);
    });

    test('a zero or negative target counts as unset', () {
      expect(planned(forecast(target: 0, history: [3.0])!).first, 3);
    });

    test('a planned itinerary day beats everything, even off a dive day', () {
      final f = forecast(
        target: 4,
        itinerary: [
          day(11, type: DayType.portDay, planned: 1),
          day(12, planned: 0),
        ],
      )!;
      expect(planned(f), [4, 1, 0, 4, 4]);
      expect([for (final d in f.days) d.isOverride], [
        false,
        true,
        true,
        false,
        false,
      ]);
    });
  });

  group('demand and supply', () {
    test('the spec example: tomorrow short once today has used its share', () {
      // 2 divers, 2 dives a day: today needs 4 of the 6 full, leaving 2 for
      // tomorrow's 4.
      final f = forecast(divers: 2)!;
      expect(f.todayDemand, 4);
      expect(f.tomorrowDemand, 4);
      expect(f.tomorrowSupply, 2);
      expect(f.todayShortfall, 0);
      expect(f.tomorrowShortfall, 2);
      expect(f.fillRunNeeded, isTrue);
      expect(f.caution, isFalse);
    });

    test('dives logged today reduce today\'s planned dives', () {
      // 3 divers, 1 of 2 dives logged: 1 dive left is 3 cylinders. 4 full
      // leaves 1 for tomorrow's 6: 5 short.
      final f = forecast(divers: 3, logged: 1, full: 4)!;
      expect(f.todayDemand, 3);
      expect(f.tomorrowDemand, 6);
      expect(f.tomorrowSupply, 1);
      expect(f.tomorrowShortfall, 5);
    });

    test('more dives logged than planned needs nothing more today', () {
      expect(forecast(logged: 3)!.todayDemand, 0);
    });

    test('today short: caution, and nothing left for tomorrow', () {
      // 1 full, today needs 2: 1 short; tomorrow's 2 have none left.
      final f = forecast(full: 1)!;
      expect(f.todayShortfall, 1);
      expect(f.caution, isTrue);
      expect(f.tomorrowSupply, 0);
      expect(f.tomorrowShortfall, 2);
    });

    test('enough: 6 full cover today\'s 2 and tomorrow\'s 2', () {
      final f = forecast()!;
      expect(f.tomorrowSupply, 4);
      expect(f.isShort, isFalse);
    });

    test('partial slots are reported, never counted', () {
      final f = forecast(full: 1, partial: 5)!;
      expect(f.partialCount, 5);
      expect(f.caution, isTrue);
    });

    test('the whole trip\'s remaining demand', () {
      // Today 2, then Mar 11 to 14 at 2 each: 10.
      expect(forecast()!.remainingDemand, 10);
    });
  });

  group('the trip calendar', () {
    test('an ended trip has no forecast', () {
      expect(forecast(now: DateTime(2026, 3, 15, 9)), isNull);
    });

    test('a trip with no slots has no forecast', () {
      expect(forecast(slots: 0, full: 0, partial: 0), isNull);
    });

    test('the last day asks nothing of tomorrow', () {
      final f = forecast(now: DateTime(2026, 3, 14, 9))!;
      expect(f.tomorrowDemand, 0);
      expect(f.days, hasLength(1));
    });

    test('the evening before the trip, tomorrow is its first day', () {
      final f = forecast(now: DateTime(2026, 3, 7, 20))!;
      expect(f.todayDemand, 0);
      expect(f.tomorrowDemand, 2);
      expect(f.days.first.date, DateTime(2026, 3, 8));
      expect(f.days, hasLength(7));
      expect(f.remainingDemand, 14);
    });
  });

  group('the fill deadline', () {
    test('closing later today is the deadline', () {
      expect(forecast(opens: 480, closes: 1020)!.deadlineMinutes, 1020);
    });

    test('after closing there is none', () {
      final f = forecast(
        now: DateTime(2026, 3, 10, 17, 30),
        opens: 480,
        closes: 1020,
      )!;
      expect(f.deadlineMinutes, isNull);
    });

    test('without both hours there is none', () {
      expect(forecast(closes: 1020)!.deadlineMinutes, isNull);
    });

    test('hours that close before they open are ignored', () {
      expect(forecast(opens: 1020, closes: 480)!.deadlineMinutes, isNull);
    });
  });

  group('fillForecastNextRefresh', () {
    test('at the deadline while it is ahead', () {
      final f = forecast(opens: 480, closes: 1020)!;
      expect(fillForecastNextRefresh(morning, f), DateTime(2026, 3, 10, 17));
    });

    test('else at the next midnight', () {
      expect(
        fillForecastNextRefresh(morning, forecast()!),
        DateTime(2026, 3, 11),
      );
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/fill_forecast_test.dart`
Expected: FAIL to compile: `fill_forecast.dart` does not exist.

- [ ] **Step 3: Make the median public**

In `scrubber_margin_service.dart`, rename `_median` to `medianOf` (declaration and its one call site) and give it a doc comment:

```dart
/// The median of [values]; the mean of the middle two for an even count.
/// [values] must not be empty.
double medianOf(List<double> values) {
```

- [ ] **Step 4: Write the forecast**

Create `lib/features/trips/domain/services/fill_forecast.dart`:

```dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/scrubber_margin_service.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// One remaining trip day: its date (local midnight), the dives planned on
/// it, and whether an itinerary day set that number.
class FillForecastDay extends Equatable {
  const FillForecastDay({
    required this.date,
    required this.plannedDives,
    this.isOverride = false,
  });

  final DateTime date;
  final int plannedDives;
  final bool isOverride;

  @override
  List<Object?> get props => [date, plannedDives, isOverride];
}

/// Everything the forecast reads. Nothing here is stored by the forecast.
class FillForecastInputs {
  const FillForecastInputs({
    required this.now,
    required this.tripStart,
    required this.tripEnd,
    required this.slotCount,
    required this.fullCount,
    required this.partialCount,
    this.itinerary = const [],
    this.divesPerDayTarget,
    this.expectedDives,
    this.divesPerDiveDayHistory = const [],
    this.diversSharing = 1,
    this.divesLoggedToday = 0,
    this.fillOpensAt,
    this.fillClosesAt,
  });

  /// The device's local time; its calendar date is "today".
  final DateTime now;
  final DateTime tripStart;
  final DateTime tripEnd;
  final int slotCount;
  final int fullCount;
  final int partialCount;
  final List<ItineraryDay> itinerary;
  final int? divesPerDayTarget;
  final int? expectedDives;
  final List<double> divesPerDiveDayHistory;
  final int diversSharing;
  final int divesLoggedToday;

  /// The fill station's hours, minutes after local midnight.
  final int? fillOpensAt;
  final int? fillClosesAt;
}

/// The forecast's answer. Demand and supply count cylinders.
class FillForecast extends Equatable {
  const FillForecast({
    required this.fullCount,
    required this.partialCount,
    required this.todayDemand,
    required this.tomorrowDemand,
    required this.tomorrowSupply,
    required this.todayShortfall,
    required this.tomorrowShortfall,
    required this.deadlineMinutes,
    required this.remainingDemand,
    required this.days,
  });

  final int fullCount;
  final int partialCount;

  /// Cylinders today's remaining dives need.
  final int todayDemand;
  final int tomorrowDemand;

  /// Full cylinders left for tomorrow once today's remaining dives have
  /// used theirs (decided 2026-09-29).
  final int tomorrowSupply;
  final int todayShortfall;
  final int tomorrowShortfall;

  /// Today's closing time at the fill station, minutes after local
  /// midnight, while it is still ahead; else null.
  final int? deadlineMinutes;

  /// Cylinders the rest of the trip needs, today's remaining dives included.
  final int remainingDemand;

  /// Today (or the trip's first day, before it starts) through its last.
  final List<FillForecastDay> days;

  /// Today's remaining dives already need more than the full cylinders.
  bool get caution => todayShortfall > 0;

  /// Tomorrow needs more than today will leave.
  bool get fillRunNeeded => tomorrowShortfall > 0;

  bool get isShort => caution || fillRunNeeded;

  @override
  List<Object?> get props => [
    fullCount,
    partialCount,
    todayDemand,
    tomorrowDemand,
    tomorrowSupply,
    todayShortfall,
    tomorrowShortfall,
    deadlineMinutes,
    remainingDemand,
    days,
  ];
}

/// Pure. The trip's fill forecast (spec "Phase 2 forecasting"), or null
/// for a trip that has ended or has no slots.
///
/// A day's demand is its planned dives times the divers sharing. Today's
/// planned dives drop by the dives already logged, floored at zero, before
/// that multiplication. Supply is the full slots; partial ones are reported,
/// never counted. Tomorrow's supply is what today's remaining dives leave.
FillForecast? computeFillForecast(FillForecastInputs inputs) {
  final today = tripDay(inputs.now);
  final start = tripDay(inputs.tripStart);
  final end = tripDay(inputs.tripEnd);
  if (inputs.slotCount == 0 || end.isBefore(today)) return null;

  final byDay = itineraryByDay(inputs.itinerary);
  final perDiveDay = _perDiveDay(inputs, start, end);
  int plannedOn(DateTime day) {
    if (day.isBefore(start) || day.isAfter(end)) return 0;
    final row = byDay[day];
    final set = row?.plannedDives;
    if (set != null) return math.max(0, set);
    return isTripDiveDay(row) ? perDiveDay : 0;
  }

  final divers = math.max(1, inputs.diversSharing);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final todayDives = math.max(0, plannedOn(today) - inputs.divesLoggedToday);
  final todayDemand = todayDives * divers;
  final tomorrowDemand = plannedOn(tomorrow) * divers;
  final tomorrowSupply = math.max(0, inputs.fullCount - todayDemand);

  final first = today.isAfter(start) ? today : start;
  final days = [
    for (final day in tripDaysBetween(first, end))
      FillForecastDay(
        date: day,
        plannedDives: plannedOn(day),
        isOverride: byDay[day]?.plannedDives != null,
      ),
  ];
  final later = days
      .where((d) => d.date.isAfter(today))
      .fold(0, (sum, d) => sum + d.plannedDives * divers);

  final opens = inputs.fillOpensAt;
  final closes = inputs.fillClosesAt;
  final nowMinutes = inputs.now.hour * 60 + inputs.now.minute;
  final deadline =
      opens != null && closes != null && opens < closes && nowMinutes < closes
      ? closes
      : null;

  return FillForecast(
    fullCount: inputs.fullCount,
    partialCount: inputs.partialCount,
    todayDemand: todayDemand,
    tomorrowDemand: tomorrowDemand,
    tomorrowSupply: tomorrowSupply,
    todayShortfall: math.max(0, todayDemand - inputs.fullCount),
    tomorrowShortfall: math.max(0, tomorrowDemand - tomorrowSupply),
    deadlineMinutes: deadline,
    remainingDemand: todayDemand + later,
    days: days,
  );
}

/// Dives on an ordinary dive day, first match wins (the spec's order after
/// an itinerary day's own plan): the trip's target, the expected dives
/// spread over the trip's dive days, the median of recent trips, else the
/// default. A fraction rounds up (decided 2026-09-29): a bottle too many,
/// never one too few. A zero or negative number counts as unset.
int _perDiveDay(FillForecastInputs inputs, DateTime start, DateTime end) {
  int? positive(int? v) => v != null && v > 0 ? v : null;
  final target = positive(inputs.divesPerDayTarget);
  if (target != null) return target;
  final expected = positive(inputs.expectedDives);
  if (expected != null) {
    final diveDays = tripDiveDayCount(
      start: start,
      end: end,
      itinerary: inputs.itinerary,
    );
    if (diveDays > 0) return (expected / diveDays).ceil();
  }
  final history = inputs.divesPerDiveDayHistory;
  return (history.isEmpty ? defaultDivesPerDiveDay : medianOf(history))
      .ceil();
}

/// Pure. When the forecast next changes by itself: at the fill deadline
/// while it is ahead, else at the next local midnight.
DateTime fillForecastNextRefresh(DateTime now, FillForecast forecast) {
  final today = tripDay(now);
  final deadline = forecast.deadlineMinutes;
  if (deadline != null) {
    final at = DateTime(
      today.year,
      today.month,
      today.day,
      deadline ~/ 60,
      deadline % 60,
    );
    if (at.isAfter(now)) return at;
  }
  return DateTime(today.year, today.month, today.day + 1);
}
```

- [ ] **Step 5: Run the tests, then the trips domain suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/domain/services/fill_forecast.dart lib/features/trips/domain/services/scrubber_margin_service.dart test/features/trips/domain/services/fill_forecast_test.dart
git commit -m "feat(trips): the pure fill forecast (#2325)"
```

---

### Task 6: The forecast provider

**Files:**
- Modify: `lib/features/trips/domain/services/trip_cylinder_state_fold.dart` (append `lastTripFillCenter`)
- Modify: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart` (remove `lastTripFillCenter` ~:28-40; import the fold)
- Modify: `lib/features/trips/data/repositories/trip_cylinder_repository.dart` (add `countTripDivesOn` after `getTankUsesForTrip`)
- Create: `lib/features/trips/presentation/providers/trip_fill_forecast_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_fill_forecast_providers_test.dart`

**Interfaces:**
- Consumes: `computeFillForecast`, `fillForecastNextRefresh` (Task 5); `Trip.diversSharingCylinders`, `Trip.divesPerDayTarget`, `DiveCenter.fillOpensAt/fillClosesAt` (Task 2); `tripByIdProvider`, `tripCylinderStatesProvider`, `itineraryDaysProvider`, `validatedCurrentDiverIdProvider`, `tripHistoryRepositoryProvider`, `tripCylinderRepositoryProvider`, `diveCenterByIdProvider`, `tripCylinderCounts`.
- Produces:
  - `String? lastTripFillCenter(List<TripCylinderState> slots)` (now in `trip_cylinder_state_fold.dart`)
  - `Future<int> TripCylinderRepository.countTripDivesOn(String tripId, DateTime day)`
  - `final tripFillForecastProvider = FutureProvider.family<FillForecast?, String>`

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/providers/trip_fill_forecast_providers_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository cylinders;
  late String tripId;

  // 09:00 local on the trip's third day.
  final now = DateTime(2026, 3, 10, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    cylinders = TripCylinderRepository();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        diversSharingCylinders: 2,
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  Future<void> fullSlots(int count, {String? centerId}) async {
    final at = DateTime.utc(2026, 3, 9, 18);
    for (var i = 0; i < count; i++) {
      final slot = await cylinders.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: 'Truck ${i + 1}',
          workingPressure: 207,
          sortOrder: i,
          createdAt: at,
          updatedAt: at,
        ),
      );
      await cylinders.createEvent(
        TripCylinderEvent(
          id: '',
          tripCylinderId: slot.id,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          pressure: 200,
          o2Percent: 32,
          diveCenterId: centerId,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
  }

  Future<void> diveAt(String id, DateTime wallClock) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: wallClock.millisecondsSinceEpoch,
          tripId: Value(tripId),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<T> at<T>(DateTime instant, Future<T> Function() body) =>
      withClock(Clock.fixed(instant), body);

  test('gathers the trip, slots, today\'s dives and the fill station', () async {
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await fullSlots(3, centerId: center.id);
    await diveAt('today', DateTime.utc(2026, 3, 10, 8));
    await diveAt('yesterday', DateTime.utc(2026, 3, 9, 10));

    final f = (await at(
      now,
      () => container.read(tripFillForecastProvider(tripId).future),
    ))!;
    // Two a day (no history, no target), 2 divers. Today: 1 dive left is 2
    // cylinders; tomorrow 4. Three full leave 1 for tomorrow: 3 short.
    expect(f.fullCount, 3);
    expect(f.todayDemand, 2);
    expect(f.tomorrowDemand, 4);
    expect(f.tomorrowSupply, 1);
    expect(f.tomorrowShortfall, 3);
    expect(f.deadlineMinutes, 1020);
    expect(f.days, hasLength(5));
    // Today 2, then Mar 11 to 14 at 4 each.
    expect(f.remainingDemand, 18);
  });

  test('an ended trip has no forecast', () async {
    await fullSlots(2);
    expect(
      await at(
        DateTime(2026, 3, 15, 9),
        () => container.read(tripFillForecastProvider(tripId).future),
      ),
      isNull,
    );
  });

  test('a trip with no slots has no forecast', () async {
    expect(
      await at(
        now,
        () => container.read(tripFillForecastProvider(tripId).future),
      ),
      isNull,
    );
  });

  test('dives count by their wall-clock day', () async {
    await diveAt('late', DateTime.utc(2026, 3, 10, 23, 30));
    await diveAt('after-midnight', DateTime.utc(2026, 3, 11, 0, 10));
    await diveAt('early', DateTime.utc(2026, 3, 10, 0, 5));
    expect(await cylinders.countTripDivesOn(tripId, DateTime(2026, 3, 10)), 2);
    expect(await cylinders.countTripDivesOn(tripId, DateTime(2026, 3, 11)), 1);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/providers/trip_fill_forecast_providers_test.dart`
Expected: FAIL to compile: the provider file and `countTripDivesOn` do not exist.

- [ ] **Step 3: Move lastTripFillCenter into the domain**

Cut `lastTripFillCenter` (and its doc comment) from `trip_cylinder_fill_sheet.dart` and append it to `trip_cylinder_state_fold.dart`, with its doc extended:

```dart

/// The fill station the trip used last: the newest of the slots' latest
/// fills that names a dive center. The fill sheet's default (the Bonaire
/// ritual is the same drive-through every morning) and the fill forecast's
/// station for the deadline.
String? lastTripFillCenter(List<TripCylinderState> slots) {
  TripCylinderEvent? latest;
  for (final s in slots) {
    final fill = s.lastFill;
    if (fill == null || fill.diveCenterId == null) continue;
    if (latest == null || fill.occurredAt.isAfter(latest.occurredAt)) {
      latest = fill;
    }
  }
  return latest?.diveCenterId;
}
```

Add `import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';` to the fill sheet; remove its `trip_cylinder_event.dart` import only if the analyzer reports it unused. The fill sheet test already imports the fold.

- [ ] **Step 4: Count a trip's dives on a day**

In `trip_cylinder_repository.dart`, after `getTankUsesForTrip`:

```dart

  /// Dives on the trip whose entry falls on [day]'s calendar date, in the
  /// wall-clock frame every dive time is stored in: the fill forecast's
  /// "dives already logged today".
  Future<int> countTripDivesOn(String tripId, DateTime day) async {
    final from = DateTime.utc(day.year, day.month, day.day);
    final to = DateTime.utc(day.year, day.month, day.day + 1);
    final row = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the forecast counts every dive on the trip,
          -- as the board does
          SELECT COUNT(*) AS n FROM dives
          WHERE trip_id = ?1
            AND COALESCE(entry_time, dive_date_time) >= ?2
            AND COALESCE(entry_time, dive_date_time) < ?3
          ''',
          variables: [
            Variable.withString(tripId),
            Variable.withInt(from.millisecondsSinceEpoch),
            Variable.withInt(to.millisecondsSinceEpoch),
          ],
          readsFrom: {_db.dives},
        )
        .getSingle();
    return row.read<int>('n');
  }
```

- [ ] **Step 5: Write the provider**

Create `lib/features/trips/presentation/providers/trip_fill_forecast_providers.dart`:

```dart
import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The trip's fill forecast, or null for an unknown trip, an ended one or
/// one with no slots. Rebuilds when the trip, its slots, its dives (through
/// the slot states), its itinerary or the fill station change, and by
/// itself at the fill deadline and at midnight (one timer).
final tripFillForecastProvider = FutureProvider.family<FillForecast?, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripByIdProvider(tripId).future);
  if (trip == null) return null;
  final states = await ref.watch(tripCylinderStatesProvider(tripId).future);
  final itinerary = await ref.watch(itineraryDaysProvider(tripId).future);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final now = clock.now();
  final history = await ref
      .watch(tripHistoryRepositoryProvider)
      .divesPerDiveDay(diverId: diverId, before: trip.startDate);
  final logged = await ref
      .watch(tripCylinderRepositoryProvider)
      .countTripDivesOn(tripId, now);
  final centerId = lastTripFillCenter(states);
  final center = centerId == null
      ? null
      : await ref.watch(diveCenterByIdProvider(centerId).future);
  final counts = tripCylinderCounts(states);
  final forecast = computeFillForecast(
    FillForecastInputs(
      now: now,
      tripStart: trip.startDate,
      tripEnd: trip.endDate,
      slotCount: states.length,
      fullCount: counts.full,
      partialCount: counts.partial,
      itinerary: itinerary,
      divesPerDayTarget: trip.divesPerDayTarget,
      expectedDives: trip.expectedDives,
      divesPerDiveDayHistory: history,
      diversSharing: trip.diversSharingCylinders,
      divesLoggedToday: logged,
      fillOpensAt: center?.fillOpensAt,
      fillClosesAt: center?.fillClosesAt,
    ),
  );
  if (forecast != null) {
    final timer = Timer(
      fillForecastNextRefresh(now, forecast).difference(now),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
  }
  return forecast;
});
```

- [ ] **Step 6: Run the tests, then the trips suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/trips/domain/services/trip_cylinder_state_fold.dart lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart lib/features/trips/data/repositories/trip_cylinder_repository.dart lib/features/trips/presentation/providers/trip_fill_forecast_providers.dart test/features/trips/presentation/providers/trip_fill_forecast_providers_test.dart
git commit -m "feat(trips): the fill forecast provider (#2325)"
```

---

### Task 7: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`

**Interfaces:**
- Produces: `trips_cylinders_forecast_todayShort(int needed, int full)`, `trips_cylinders_forecast_tomorrowShort(int needed, int full)`, `trips_cylinders_forecast_fillBefore(String time)`, `trips_cylinders_forecast_enough`, `trips_cylinders_forecast_daysTitle`, `trips_cylinders_forecast_plannedDives(int count)`, `trips_cylinders_forecast_dayTitle(String date)`, `trips_cylinders_forecast_useEstimate`, `trips_cylinders_forecast_fewer`, `trips_cylinders_forecast_more`, `trips_cylinders_forecast_saveError(String error)`, `trips_edit_label_diversSharing`, `trips_edit_hint_diversSharing`, `trips_edit_label_divesPerDay`, `trips_edit_hint_divesPerDay`, `diveCenters_section_fillHours`, `diveCenters_fillHours_caption`, `diveCenters_fillHours_opens`, `diveCenters_fillHours_closes`, `diveCenters_fillHours_notSet`, `diveCenters_fillHours_clear`, `diveCenters_fillHours_errorBoth`, `diveCenters_fillHours_errorOrder`.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `trip_cylinder_display_test.dart`:

```dart

  test('the forecast strings exist in English', () {
    expect(
      l10n.trips_cylinders_forecast_todayShort(4, 2),
      'Today needs 4, you have 2 full.',
    );
    expect(
      l10n.trips_cylinders_forecast_tomorrowShort(6, 1),
      "Tomorrow needs 6, you'll have 1 full.",
    );
    expect(
      l10n.trips_cylinders_forecast_fillBefore('5:00 PM'),
      'Fill before 5:00 PM.',
    );
    expect(
      l10n.trips_cylinders_forecast_enough,
      'Enough full cylinders through tomorrow.',
    );
    expect(l10n.trips_cylinders_forecast_plannedDives(1), '1 dive');
    expect(l10n.trips_cylinders_forecast_plannedDives(0), '0 dives');
    expect(l10n.trips_edit_label_diversSharing, 'Divers sharing cylinders');
    expect(l10n.diveCenters_section_fillHours, 'Fill hours');
    expect(
      l10n.diveCenters_fillHours_errorOrder,
      'Closing time must be after opening time.',
    );
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: FAIL, the getters are undefined.

- [ ] **Step 3: Add the keys to all 11 ARB files and regenerate**

Before running, compare each locale's wording with its existing `trips_cylinders_title`, `trips_edit_label_expectedDives` and `diveCenters_section_notes` values, and adjust the terms below where that locale already uses a different word for cylinder, dive or fill. Save this as `<scratchpad>/add_forecast_strings.py` and run it from the worktree root with `python3.14`:

```python
import io
import json
import sys

ARB = 'lib/l10n/arb'
LOCALES = ['ar', 'de', 'en', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']
T = 'trips_cylinders_title'
E = 'trips_edit_label_expectedDives'
C = 'diveCenters_section_notes'

# (anchor, key, placeholders, values). Each key goes directly before its
# anchor, in this order; a key with placeholders gets its "@" block in every
# locale, as the existing keys do.
STRINGS = [
    (T, 'trips_cylinders_forecast_todayShort', {'needed': 'int', 'full': 'int'}, {
        'en': 'Today needs {needed}, you have {full} full.',
        'ar': 'اليوم يحتاج إلى {needed}، ولديك {full} ممتلئة.',
        'de': 'Heute werden {needed} gebraucht, Sie haben {full} volle.',
        'es': 'Hoy se necesitan {needed}, tiene {full} llenas.',
        'fr': "Aujourd'hui il en faut {needed}, vous en avez {full} pleins.",
        'he': 'היום צריך {needed}, יש לך {full} מלאים.',
        'hu': 'Ma {needed} kell, {full} teli van.',
        'it': 'Oggi ne servono {needed}, ne ha {full} piene.',
        'nl': 'Vandaag zijn er {needed} nodig, je hebt er {full} vol.',
        'pt': 'Hoje são precisos {needed}, tem {full} cheios.',
        'zh': '今天需要 {needed} 个，你有 {full} 个满瓶。',
    }),
    (T, 'trips_cylinders_forecast_tomorrowShort', {'needed': 'int', 'full': 'int'}, {
        'en': "Tomorrow needs {needed}, you'll have {full} full.",
        'ar': 'غدًا يحتاج إلى {needed}، وسيكون لديك {full} ممتلئة.',
        'de': 'Morgen werden {needed} gebraucht, Sie haben dann {full} volle.',
        'es': 'Mañana se necesitan {needed}, tendrá {full} llenas.',
        'fr': 'Demain il en faut {needed}, vous en aurez {full} pleins.',
        'he': 'מחר צריך {needed}, יהיו לך {full} מלאים.',
        'hu': 'Holnap {needed} kell, {full} teli marad.',
        'it': 'Domani ne servono {needed}, ne avrà {full} piene.',
        'nl': 'Morgen zijn er {needed} nodig, je hebt er dan {full} vol.',
        'pt': 'Amanhã são precisos {needed}, terá {full} cheios.',
        'zh': '明天需要 {needed} 个，届时你有 {full} 个满瓶。',
    }),
    (T, 'trips_cylinders_forecast_fillBefore', {'time': 'String'}, {
        'en': 'Fill before {time}.',
        'ar': 'املأ قبل {time}.',
        'de': 'Vor {time} füllen.',
        'es': 'Llene antes de las {time}.',
        'fr': 'Remplir avant {time}.',
        'he': 'למלא לפני {time}.',
        'hu': 'Töltés {time} előtt.',
        'it': 'Ricarichi prima delle {time}.',
        'nl': 'Vul voor {time}.',
        'pt': 'Encha antes das {time}.',
        'zh': '请在 {time} 前充气。',
    }),
    (T, 'trips_cylinders_forecast_enough', {}, {
        'en': 'Enough full cylinders through tomorrow.',
        'ar': 'أسطوانات ممتلئة كافية حتى الغد.',
        'de': 'Genug volle Flaschen bis morgen.',
        'es': 'Suficientes botellas llenas hasta mañana.',
        'fr': "Assez de blocs pleins jusqu'à demain.",
        'he': 'יש מספיק מכלים מלאים עד מחר.',
        'hu': 'Elég teli palack holnapig.',
        'it': 'Bombole piene sufficienti fino a domani.',
        'nl': 'Genoeg volle flessen tot en met morgen.',
        'pt': 'Cilindros cheios suficientes até amanhã.',
        'zh': '满瓶足够用到明天。',
    }),
    (T, 'trips_cylinders_forecast_daysTitle', {}, {
        'en': 'Planned dives',
        'ar': 'الغطسات المخططة',
        'de': 'Geplante Tauchgänge',
        'es': 'Inmersiones planificadas',
        'fr': 'Plongées planifiées',
        'he': 'צלילות מתוכננות',
        'hu': 'Tervezett merülések',
        'it': 'Immersioni pianificate',
        'nl': 'Geplande duiken',
        'pt': 'Mergulhos planeados',
        'zh': '计划潜水',
    }),
    # The same wording as trips_cylinders_linkedDives in every locale, which
    # already interpolates the count in the fr and pt "one" branch.
    (T, 'trips_cylinders_forecast_plannedDives', {'count': 'int'}, {
        'en': '{count, plural, one{{count} dive} other{{count} dives}}',
        'ar': '{count, plural, one{{count} غطسة} other{{count} غطسات}}',
        'de': '{count, plural, one{{count} Tauchgang} other{{count} Tauchgänge}}',
        'es': '{count, plural, one{{count} inmersión} other{{count} inmersiones}}',
        'fr': '{count, plural, one{{count} plongée} other{{count} plongées}}',
        'he': '{count, plural, one{{count} צלילה} other{{count} צלילות}}',
        'hu': '{count, plural, one{{count} merülés} other{{count} merülés}}',
        'it': '{count, plural, one{{count} immersione} other{{count} immersioni}}',
        'nl': '{count, plural, one{{count} duik} other{{count} duiken}}',
        'pt': '{count, plural, one{{count} mergulho} other{{count} mergulhos}}',
        'zh': '{count, plural, other{{count} 次潜水}}',
    }),
    (T, 'trips_cylinders_forecast_dayTitle', {'date': 'String'}, {
        'en': 'Planned dives, {date}',
        'ar': 'الغطسات المخططة، {date}',
        'de': 'Geplante Tauchgänge, {date}',
        'es': 'Inmersiones planificadas, {date}',
        'fr': 'Plongées planifiées, {date}',
        'he': 'צלילות מתוכננות, {date}',
        'hu': 'Tervezett merülések, {date}',
        'it': 'Immersioni pianificate, {date}',
        'nl': 'Geplande duiken, {date}',
        'pt': 'Mergulhos planeados, {date}',
        'zh': '计划潜水，{date}',
    }),
    (T, 'trips_cylinders_forecast_useEstimate', {}, {
        'en': 'Use the estimate',
        'ar': 'استخدام التقدير',
        'de': 'Schätzung verwenden',
        'es': 'Usar la estimación',
        'fr': "Utiliser l'estimation",
        'he': 'להשתמש בהערכה',
        'hu': 'Becslés használata',
        'it': 'Usa la stima',
        'nl': 'Schatting gebruiken',
        'pt': 'Usar a estimativa',
        'zh': '使用估计值',
    }),
    (T, 'trips_cylinders_forecast_fewer', {}, {
        'en': 'Fewer dives',
        'ar': 'غطسات أقل',
        'de': 'Weniger Tauchgänge',
        'es': 'Menos inmersiones',
        'fr': 'Moins de plongées',
        'he': 'פחות צלילות',
        'hu': 'Kevesebb merülés',
        'it': 'Meno immersioni',
        'nl': 'Minder duiken',
        'pt': 'Menos mergulhos',
        'zh': '减少潜水',
    }),
    (T, 'trips_cylinders_forecast_more', {}, {
        'en': 'More dives',
        'ar': 'غطسات أكثر',
        'de': 'Mehr Tauchgänge',
        'es': 'Más inmersiones',
        'fr': 'Plus de plongées',
        'he': 'יותר צלילות',
        'hu': 'Több merülés',
        'it': 'Più immersioni',
        'nl': 'Meer duiken',
        'pt': 'Mais mergulhos',
        'zh': '增加潜水',
    }),
    (T, 'trips_cylinders_forecast_saveError', {'error': 'String'}, {
        'en': "Couldn't save the plan: {error}",
        'ar': 'تعذّر حفظ الخطة: {error}',
        'de': 'Plan konnte nicht gespeichert werden: {error}',
        'es': 'No se pudo guardar el plan: {error}',
        'fr': "Impossible d'enregistrer le plan : {error}",
        'he': 'לא ניתן לשמור את התוכנית: {error}',
        'hu': 'A terv mentése nem sikerült: {error}',
        'it': 'Impossibile salvare il piano: {error}',
        'nl': 'Plan kon niet worden opgeslagen: {error}',
        'pt': 'Não foi possível guardar o plano: {error}',
        'zh': '无法保存计划：{error}',
    }),
    (E, 'trips_edit_label_diversSharing', {}, {
        'en': 'Divers sharing cylinders',
        'ar': 'الغواصون المشتركون في الأسطوانات',
        'de': 'Taucher, die sich Flaschen teilen',
        'es': 'Buceadores que comparten botellas',
        'fr': 'Plongeurs partageant les blocs',
        'he': 'צוללים החולקים מכלים',
        'hu': 'Palackokon osztozó búvárok',
        'it': 'Subacquei che condividono le bombole',
        'nl': 'Duikers die flessen delen',
        'pt': 'Mergulhadores que partilham cilindros',
        'zh': '共用气瓶的潜水员',
    }),
    (E, 'trips_edit_hint_diversSharing', {}, {
        'en': 'Including you. Blank means 1.',
        'ar': 'بما في ذلك أنت. الفراغ يعني 1.',
        'de': 'Sie eingeschlossen. Leer bedeutet 1.',
        'es': 'Usted incluido. En blanco significa 1.',
        'fr': 'Vous compris. Vide signifie 1.',
        'he': 'כולל אותך. ריק פירושו 1.',
        'hu': 'Önnel együtt. Üresen 1.',
        'it': 'Lei compreso. Vuoto significa 1.',
        'nl': 'Jij meegerekend. Leeg betekent 1.',
        'pt': 'Incluindo você. Em branco significa 1.',
        'zh': '包括你自己。留空表示 1。',
    }),
    (E, 'trips_edit_label_divesPerDay', {}, {
        'en': 'Dives per day',
        'ar': 'غطسات في اليوم',
        'de': 'Tauchgänge pro Tag',
        'es': 'Inmersiones por día',
        'fr': 'Plongées par jour',
        'he': 'צלילות ליום',
        'hu': 'Merülés naponta',
        'it': 'Immersioni al giorno',
        'nl': 'Duiken per dag',
        'pt': 'Mergulhos por dia',
        'zh': '每天潜水次数',
    }),
    (E, 'trips_edit_hint_divesPerDay', {}, {
        'en': 'For the fill forecast. Blank means estimate.',
        'ar': 'لتوقع التعبئة. الفراغ يعني التقدير.',
        'de': 'Für die Füllprognose. Leer bedeutet Schätzung.',
        'es': 'Para la previsión de llenado. En blanco significa estimar.',
        'fr': 'Pour la prévision de remplissage. Vide signifie estimer.',
        'he': 'לתחזית המילוי. ריק פירושו הערכה.',
        'hu': 'A töltési előrejelzéshez. Üresen becslés.',
        'it': 'Per la previsione di ricarica. Vuoto significa stima.',
        'nl': 'Voor de vulprognose. Leeg betekent schatting.',
        'pt': 'Para a previsão de enchimento. Em branco significa estimativa.',
        'zh': '用于充气预测。留空表示估算。',
    }),
    (C, 'diveCenters_section_fillHours', {}, {
        'en': 'Fill hours',
        'ar': 'ساعات التعبئة',
        'de': 'Füllzeiten',
        'es': 'Horario de llenado',
        'fr': 'Horaires de remplissage',
        'he': 'שעות מילוי',
        'hu': 'Töltési idő',
        'it': 'Orari di ricarica',
        'nl': 'Vultijden',
        'pt': 'Horário de enchimento',
        'zh': '充气时间',
    }),
    (C, 'diveCenters_fillHours_caption', {}, {
        'en': 'When the station fills cylinders. The trip fill forecast uses the closing time.',
        'ar': 'متى تملأ المحطة الأسطوانات. يستخدم توقع التعبئة للرحلة وقت الإغلاق.',
        'de': 'Wann die Station Flaschen füllt. Die Füllprognose der Reise nutzt die Schließzeit.',
        'es': 'Cuándo llena botellas la estación. La previsión de llenado del viaje usa la hora de cierre.',
        'fr': "Quand la station remplit les blocs. La prévision de remplissage du voyage utilise l'heure de fermeture.",
        'he': 'מתי התחנה ממלאת מכלים. תחזית המילוי של הטיול משתמשת בשעת הסגירה.',
        'hu': 'Mikor tölt palackot az állomás. Az út töltési előrejelzése a zárási időt használja.',
        'it': "Quando la stazione ricarica le bombole. La previsione di ricarica del viaggio usa l'orario di chiusura.",
        'nl': 'Wanneer het station flessen vult. De vulprognose van de reis gebruikt de sluitingstijd.',
        'pt': 'Quando a estação enche cilindros. A previsão de enchimento da viagem usa a hora de fecho.',
        'zh': '气站充气的时间。行程充气预测使用关门时间。',
    }),
    (C, 'diveCenters_fillHours_opens', {}, {
        'en': 'Opens', 'ar': 'يفتح', 'de': 'Öffnet', 'es': 'Abre',
        'fr': 'Ouverture', 'he': 'נפתח', 'hu': 'Nyit', 'it': 'Apre',
        'nl': 'Opent', 'pt': 'Abre', 'zh': '开门',
    }),
    (C, 'diveCenters_fillHours_closes', {}, {
        'en': 'Closes', 'ar': 'يغلق', 'de': 'Schließt', 'es': 'Cierra',
        'fr': 'Fermeture', 'he': 'נסגר', 'hu': 'Zár', 'it': 'Chiude',
        'nl': 'Sluit', 'pt': 'Fecha', 'zh': '关门',
    }),
    # The same words as each locale's diveLog_edit_row_notSet.
    (C, 'diveCenters_fillHours_notSet', {}, {
        'en': 'Not set', 'ar': 'غير محدد', 'de': 'Nicht gesetzt',
        'es': 'Sin definir', 'fr': 'Non défini', 'he': 'לא הוגדר',
        'hu': 'Nincs megadva', 'it': 'Non impostato', 'nl': 'Niet ingesteld',
        'pt': 'Não definido', 'zh': '未设置',
    }),
    (C, 'diveCenters_fillHours_clear', {}, {
        'en': 'Clear fill hours',
        'ar': 'مسح ساعات التعبئة',
        'de': 'Füllzeiten löschen',
        'es': 'Borrar horario de llenado',
        'fr': 'Effacer les horaires de remplissage',
        'he': 'ניקוי שעות המילוי',
        'hu': 'Töltési idő törlése',
        'it': 'Cancella orari di ricarica',
        'nl': 'Vultijden wissen',
        'pt': 'Limpar horário de enchimento',
        'zh': '清除充气时间',
    }),
    (C, 'diveCenters_fillHours_errorBoth', {}, {
        'en': 'Set both times, or neither.',
        'ar': 'حدد الوقتين معًا أو لا شيء.',
        'de': 'Beide Zeiten setzen oder keine.',
        'es': 'Indique ambas horas o ninguna.',
        'fr': 'Indiquez les deux heures, ou aucune.',
        'he': 'יש להגדיר את שתי השעות או אף אחת.',
        'hu': 'Adja meg mindkét időpontot, vagy egyiket sem.',
        'it': 'Imposti entrambi gli orari o nessuno.',
        'nl': 'Stel beide tijden in, of geen van beide.',
        'pt': 'Defina as duas horas, ou nenhuma.',
        'zh': '请同时设置两个时间，或都不设置。',
    }),
    (C, 'diveCenters_fillHours_errorOrder', {}, {
        'en': 'Closing time must be after opening time.',
        'ar': 'يجب أن يكون وقت الإغلاق بعد وقت الفتح.',
        'de': 'Die Schließzeit muss nach der Öffnungszeit liegen.',
        'es': 'La hora de cierre debe ser posterior a la de apertura.',
        'fr': "L'heure de fermeture doit suivre l'heure d'ouverture.",
        'he': 'שעת הסגירה חייבת להיות אחרי שעת הפתיחה.',
        'hu': 'A zárásnak a nyitás után kell lennie.',
        'it': "L'orario di chiusura deve seguire quello di apertura.",
        'nl': 'De sluitingstijd moet na de openingstijd liggen.',
        'pt': 'A hora de fecho tem de ser depois da de abertura.',
        'zh': '关门时间必须晚于开门时间。',
    }),
]

for loc in LOCALES:
    path = f'{ARB}/app_{loc}.arb'
    raw = io.open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    lines = raw.split(nl)
    for anchor, key, placeholders, values in STRINGS:
        if any(line.startswith(f'  "{key}":') for line in lines):
            sys.exit(f'{key} is already in {path}')
        idx = next(i for i, line in enumerate(lines) if line.startswith(f'  "{anchor}":'))
        block = [f'  "{key}": {json.dumps(values[loc], ensure_ascii=False)},']
        if placeholders:
            block += [f'  "@{key}": {{', '    "placeholders": {']
            items = list(placeholders.items())
            for n, (name, kind) in enumerate(items):
                block += [f'      "{name}": {{', f'        "type": "{kind}"',
                          '      }' + (',' if n < len(items) - 1 else '')]
            block += ['    }', '  },']
        lines[idx:idx] = block
    io.open(path, 'w', encoding='utf-8', newline='').write(nl.join(lines))
print('ok')
```

Then run `flutter gen-l10n` and confirm `git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'` lists all 12 generated files as modified.

- [ ] **Step 4: Run the test to verify it passes, then the l10n suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart test/l10n`
Expected: `All tests passed!` (parity, placeholders, plural zero and singular interpolation).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb test/features/trips/presentation/helpers/trip_cylinder_display_test.dart
git commit -m "feat(trips): fill forecast strings in every locale (#2325)"
```

---

### Task 8: The forecast on the card and the board banner

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart` (after `formatTime`)
- Modify: `lib/features/trips/presentation/helpers/trip_cylinder_display.dart`
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_cylinders_card.dart`
- Modify: `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart`
- Test: `trip_cylinder_display_test.dart`, `test/features/trips/presentation/widgets/trip_cylinders_card_test.dart`, `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`

**Interfaces:**
- Consumes: `FillForecast` (Task 5), `tripFillForecastProvider` (Task 6), the Task 7 strings.
- Produces:
  - `String UnitFormatter.formatMinutesOfDay(int minutes)`
  - `({List<String> lines, bool short}) tripFillForecastLines(AppLocalizations l10n, UnitFormatter units, FillForecast f)`
  - `class TripFillForecastText extends StatelessWidget { FillForecast forecast; UnitFormatter units; }`
  - `class TripFillForecastBanner extends StatelessWidget { FillForecast forecast; UnitFormatter units; }` (key `fill-forecast-banner`)
  - The board page's body shows the banner (and, from Task 9, the strip) above the segment when the forecast is non-null.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `trip_cylinder_display_test.dart` (add `import 'package:submersion/core/constants/units.dart';` and `import 'package:submersion/features/trips/domain/services/fill_forecast.dart';`):

```dart

  FillForecast forecastOf({
    int todayShortfall = 0,
    int tomorrowShortfall = 0,
    int? deadline,
  }) => FillForecast(
    fullCount: 2,
    partialCount: 0,
    todayDemand: 4,
    tomorrowDemand: 6,
    tomorrowSupply: 1,
    todayShortfall: todayShortfall,
    tomorrowShortfall: tomorrowShortfall,
    deadlineMinutes: deadline,
    remainingDemand: 10,
    days: const [],
  );

  test('a time of day in the diver\'s format', () {
    expect(units.formatMinutesOfDay(1020), '5:00 PM');
    expect(
      const UnitFormatter(
        AppSettings(timeFormat: TimeFormat.twentyFourHour),
      ).formatMinutesOfDay(1020),
      '17:00',
    );
  });

  test('forecast lines: both shortfalls, today first, with the deadline', () {
    final r = tripFillForecastLines(
      l10n,
      units,
      forecastOf(todayShortfall: 2, tomorrowShortfall: 5, deadline: 1020),
    );
    expect(r.short, isTrue);
    expect(r.lines, [
      'Today needs 4, you have 2 full. Fill before 5:00 PM.',
      "Tomorrow needs 6, you'll have 1 full.",
    ]);
  });

  test('forecast lines: tomorrow alone, no deadline', () {
    final r = tripFillForecastLines(
      l10n,
      units,
      forecastOf(tomorrowShortfall: 5),
    );
    expect(r.lines, ["Tomorrow needs 6, you'll have 1 full."]);
  });

  test('forecast lines: enough', () {
    final r = tripFillForecastLines(l10n, units, forecastOf(deadline: 1020));
    expect(r.short, isFalse);
    expect(r.lines, ['Enough full cylinders through tomorrow.']);
  });
```

In `trip_cylinders_card_test.dart`, add `import 'package:submersion/features/trips/domain/services/fill_forecast.dart';` and `import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';`, give `host` a `FillForecast? forecast` parameter, and add to its overrides:

```dart
        tripFillForecastProvider(
          't1',
        ).overrideWith((ref) async => forecast),
```

Then append to `main()`:

```dart

  FillForecast shortForecast() => const FillForecast(
    fullCount: 1,
    partialCount: 0,
    todayDemand: 2,
    tomorrowDemand: 4,
    tomorrowSupply: 0,
    todayShortfall: 1,
    tomorrowShortfall: 4,
    deadlineMinutes: 1020,
    remainingDemand: 12,
    days: [],
  );

  testWidgets('a short forecast shows both lines in the error colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(states(), current: true, forecast: shortForecast()),
    );
    await tester.pumpAndSettle();
    final today = find.text(
      'Today needs 2, you have 1 full. Fill before 5:00 PM.',
    );
    expect(today, findsOneWidget);
    expect(find.text("Tomorrow needs 4, you'll have 0 full."), findsOneWidget);
    final context = tester.element(today);
    expect(
      tester.widget<Text>(today).style?.color,
      Theme.of(context).colorScheme.error,
    );
  });

  testWidgets('no forecast, no line', (tester) async {
    await tester.pumpWidget(host(states(), current: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-cylinders-forecast')), findsNothing);
  });
```

In `trip_cylinder_board_page_test.dart`, add the same two imports, give both `pumpBoard` and `pumpBoardWithRouter` a `FillForecast? forecast` named parameter, and add to both override lists:

```dart
          tripFillForecastProvider(
            tripId,
          ).overrideWith((ref) async => forecast),
```

Then append to `main()`:

```dart

  testWidgets('the board shows the forecast as a banner', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: const FillForecast(
        fullCount: 1,
        partialCount: 0,
        todayDemand: 0,
        tomorrowDemand: 4,
        tomorrowSupply: 1,
        todayShortfall: 0,
        tomorrowShortfall: 3,
        deadlineMinutes: null,
        remainingDemand: 8,
        days: [],
      ),
    );
    expect(find.byKey(const Key('fill-forecast-banner')), findsOneWidget);
    expect(find.text("Tomorrow needs 4, you'll have 1 full."), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart test/features/trips/presentation/widgets/trip_cylinders_card_test.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: FAIL to compile: `formatMinutesOfDay` and `tripFillForecastLines` are undefined.

- [ ] **Step 3: The formatter and the lines**

In `unit_formatter.dart`, after `formatTime`:

```dart

  /// A time of day given as minutes after midnight (a dive center's fill
  /// hours), in the diver's 12 or 24 hour format.
  String formatMinutesOfDay(int minutes) =>
      formatTime(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
```

In `trip_cylinder_display.dart` (import `fill_forecast.dart`):

```dart

/// The forecast in words (decided 2026-09-29): today's shortfall, then
/// tomorrow's, the first of them ending with the fill deadline; or, with no
/// shortfall, that the full cylinders last through tomorrow.
({List<String> lines, bool short}) tripFillForecastLines(
  AppLocalizations l10n,
  UnitFormatter units,
  FillForecast f,
) {
  final lines = [
    if (f.caution)
      l10n.trips_cylinders_forecast_todayShort(f.todayDemand, f.fullCount),
    if (f.fillRunNeeded)
      l10n.trips_cylinders_forecast_tomorrowShort(
        f.tomorrowDemand,
        f.tomorrowSupply,
      ),
  ];
  if (lines.isEmpty) {
    return (lines: [l10n.trips_cylinders_forecast_enough], short: false);
  }
  final deadline = f.deadlineMinutes;
  if (deadline == null) return (lines: lines, short: true);
  final fill = l10n.trips_cylinders_forecast_fillBefore(
    units.formatMinutesOfDay(deadline),
  );
  return (lines: ['${lines.first} $fill', ...lines.skip(1)], short: true);
}
```

- [ ] **Step 4: The text and the banner**

Create `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The forecast as lines of text, for the trip's cylinders card: each
/// shortfall in the error colour, else the all-clear.
class TripFillForecastText extends StatelessWidget {
  const TripFillForecastText({
    super.key,
    required this.forecast,
    required this.units,
  });

  final FillForecast forecast;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:lines, :short) = tripFillForecastLines(
      context.l10n,
      units,
      forecast,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: short ? theme.colorScheme.error : null,
              fontWeight: short ? FontWeight.w600 : null,
            ),
          ),
      ],
    );
  }
}

/// The same forecast as the board's banner: the alert swatch on a
/// shortfall, a quiet surface otherwise.
class TripFillForecastBanner extends StatelessWidget {
  const TripFillForecastBanner({
    super.key,
    required this.forecast,
    required this.units,
  });

  final FillForecast forecast;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:lines, :short) = tripFillForecastLines(
      context.l10n,
      units,
      forecast,
    );
    final swatch = StatusColors.of(context).alert;
    final foreground = short
        ? swatch.onContainer
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('fill-forecast-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: short
              ? swatch.container
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              short ? Icons.warning_amber : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Show them**

In `trip_cylinders_card.dart` (import `trip_fill_forecast_providers.dart` and `widgets/cylinders/trip_fill_forecast_banner.dart`), after `final units = ...;`:

```dart
    final forecast = ref.watch(tripFillForecastProvider(trip.id)).value;
```

and in the non-empty branch's `content`, directly after the summary `Text(...)`:

```dart
        if (forecast != null) ...[
          const SizedBox(height: 4),
          TripFillForecastText(
            key: const Key('trip-cylinders-forecast'),
            forecast: forecast,
            units: units,
          ),
        ],
```

In `trip_cylinder_board_page.dart` (import `unit_formatter.dart`, `settings_providers.dart`, `trip_fill_forecast_providers.dart`, `trip_fill_forecast_banner.dart`), in `build` after the dive center lines:

```dart
    final units = UnitFormatter(ref.watch(settingsProvider));
    final forecast = ref.watch(tripFillForecastProvider(tripId)).value;
```

and as the first children of the non-empty `body = Column(children: [...])`:

```dart
        if (forecast != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TripFillForecastBanner(forecast: forecast, units: units),
          ),
```

- [ ] **Step 6: Run the tests, then the trips presentation suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation test/architecture`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/unit_formatter.dart lib/features/trips/presentation/helpers/trip_cylinder_display.dart lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart lib/features/trips/presentation/widgets/trip_cylinders_card.dart lib/features/trips/presentation/pages/trip_cylinder_board_page.dart test/features/trips/presentation/helpers/trip_cylinder_display_test.dart test/features/trips/presentation/widgets/trip_cylinders_card_test.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart
git commit -m "feat(trips): the fill forecast on the card and the board (#2325)"
```

---

### Task 9: The day strip

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart`
- Modify: `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart`
- Test: `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`

**Interfaces:**
- Consumes: `FillForecastDay` (Task 5), `ItineraryDayRepository.setPlannedDives` (Task 3), `itineraryDayRepositoryProvider`, the Task 7 strings.
- Produces:
  - `class TripFillForecastStrip extends ConsumerStatefulWidget { String tripId; List<FillForecastDay> days; UnitFormatter units; }` (chip keys `forecast-day-<index>`)
  - `Future<({int? plannedDives})?> showTripDayPlanDialog(BuildContext context, {required FillForecastDay day, required String dateLabel})` (keys `plan-fewer`, `plan-more`, `plan-count`, `plan-use-estimate`)

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `trip_cylinder_board_page_test.dart` (add `import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';` and `import 'package:submersion/core/constants/enums.dart';` if absent). The board test's trip runs 2026-03-08 to 2026-03-14:

```dart

  FillForecast forecastWithDays(List<FillForecastDay> days) => FillForecast(
    fullCount: 4,
    partialCount: 0,
    todayDemand: 2,
    tomorrowDemand: 2,
    tomorrowSupply: 2,
    todayShortfall: 0,
    tomorrowShortfall: 0,
    deadlineMinutes: null,
    remainingDemand: 6,
    days: days,
  );

  testWidgets('the strip lists the remaining days with their plans', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(date: DateTime(2026, 3, 13), plannedDives: 2),
        FillForecastDay(
          date: DateTime(2026, 3, 14),
          plannedDives: 1,
          isOverride: true,
        ),
      ]),
    );
    expect(find.text('Planned dives'), findsOneWidget);
    expect(find.textContaining('2 dives'), findsOneWidget);
    expect(find.textContaining('1 dive'), findsOneWidget);
  });

  testWidgets('saving a day writes its plan to the itinerary', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(date: DateTime(2026, 3, 10), plannedDives: 2),
      ]),
    );
    await tester.tap(find.byKey(const Key('forecast-day-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-more')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final days = await ItineraryDayRepository().getByTripId(tripId);
    expect(days, hasLength(1));
    expect(days.single.date, DateTime(2026, 3, 10));
    expect(days.single.dayNumber, 3);
    expect(days.single.dayType, DayType.diveDay);
    expect(days.single.plannedDives, 3);
  });

  testWidgets('using the estimate clears a planned day', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await ItineraryDayRepository().setPlannedDives(
      tripId: tripId,
      date: DateTime(2026, 3, 10),
      plannedDives: 4,
    );
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(
          date: DateTime(2026, 3, 10),
          plannedDives: 4,
          isOverride: true,
        ),
      ]),
    );
    await tester.tap(find.byKey(const Key('forecast-day-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-use-estimate')));
    await tester.pumpAndSettle();

    final day = (await ItineraryDayRepository().getByTripId(tripId)).single;
    expect(day.plannedDives, isNull);
  });

  testWidgets('cancel writes nothing', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(date: DateTime(2026, 3, 10), plannedDives: 2),
      ]),
    );
    await tester.tap(find.byKey(const Key('forecast-day-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-more')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await ItineraryDayRepository().getByTripId(tripId), isEmpty);
  });
```

If `pumpBoard` settles with `pumpAndSettle` after the save and the board's providers keep a frame scheduled, replace the post-save `pumpAndSettle` with ten `pump(const Duration(milliseconds: 100))` calls and record that as a ruling.

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: FAIL. No 'Planned dives' title and no `forecast-day-0`.

- [ ] **Step 3: Write the strip and the dialog**

Create `lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The most dives the day editor offers (ruling R7).
const int _maxPlannedDives = 12;

/// The remaining trip days with their planned dives, for the board.
/// Tapping a day edits its plan; the forecast refreshes through the
/// itinerary provider's change stream.
class TripFillForecastStrip extends ConsumerStatefulWidget {
  const TripFillForecastStrip({
    super.key,
    required this.tripId,
    required this.days,
    required this.units,
  });

  final String tripId;
  final List<FillForecastDay> days;
  final UnitFormatter units;

  @override
  ConsumerState<TripFillForecastStrip> createState() =>
      _TripFillForecastStripState();
}

class _TripFillForecastStripState extends ConsumerState<TripFillForecastStrip> {
  /// One save at a time: the repository's transaction keeps the rows
  /// right, and this keeps a second dialog from opening over a save.
  bool _saving = false;

  Future<void> _edit(FillForecastDay day) async {
    if (_saving) return;
    final result = await showTripDayPlanDialog(
      context,
      day: day,
      dateLabel: widget.units.formatWeekdayMonthDay(day.date),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(itineraryDayRepositoryProvider)
          .setPlannedDives(
            tripId: widget.tripId,
            date: day.date,
            plannedDives: result.plannedDives,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_cylinders_forecast_saveError('$e')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.trips_cylinders_forecast_daysTitle,
            style: theme.textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = widget.days[i];
              return ActionChip(
                key: Key('forecast-day-$i'),
                avatar: day.isOverride
                    ? const Icon(Icons.edit_calendar, size: 16)
                    : null,
                label: Text(
                  '${widget.units.formatWeekdayMonthDay(day.date)} · '
                  '${l10n.trips_cylinders_forecast_plannedDives(day.plannedDives)}',
                ),
                onPressed: _saving ? null : () => _edit(day),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Asks for [day]'s planned dives, 0 to 12. Returns the number, or a null
/// number to return the day to the estimate (offered when the day has its
/// own plan), or null when the diver cancels.
Future<({int? plannedDives})?> showTripDayPlanDialog(
  BuildContext context, {
  required FillForecastDay day,
  required String dateLabel,
}) {
  var count = day.plannedDives.clamp(0, _maxPlannedDives);
  return showDialog<({int? plannedDives})>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.trips_cylinders_forecast_dayTitle(dateLabel)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('plan-fewer'),
                tooltip: l10n.trips_cylinders_forecast_fewer,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: count > 0 ? () => setState(() => count--) : null,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$count',
                  key: const Key('plan-count'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                key: const Key('plan-more'),
                tooltip: l10n.trips_cylinders_forecast_more,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: count < _maxPlannedDives
                    ? () => setState(() => count++)
                    : null,
              ),
            ],
          ),
          actions: [
            if (day.isOverride)
              TextButton(
                key: const Key('plan-use-estimate'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop((plannedDives: null)),
                child: Text(l10n.trips_cylinders_forecast_useEstimate),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop((plannedDives: count)),
              child: Text(l10n.common_action_save),
            ),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 4: Put the strip on the board**

In `trip_cylinder_board_page.dart` (import `trip_fill_forecast_strip.dart`), replace the Task 8 banner entry with:

```dart
        if (forecast != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TripFillForecastBanner(forecast: forecast, units: units),
          ),
          if (forecast.days.isNotEmpty)
            TripFillForecastStrip(
              tripId: tripId,
              days: forecast.days,
              units: units,
            ),
        ],
```

- [ ] **Step 5: Run the tests, then the trips presentation suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation test/architecture`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart lib/features/trips/presentation/pages/trip_cylinder_board_page.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart
git commit -m "feat(trips): plan each remaining day from the board (#2325)"
```

---

### Task 10: Divers sharing and dives per day on the trip form

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (controllers ~:48, listeners ~:113, load ~:142, dispose ~:192, Planning section after the expected runtime field ~:594, `_saveTrip` ~:949)
- Test: `test/features/trips/presentation/pages/trip_edit_page_test.dart`

**Interfaces:**
- Consumes: `Trip.diversSharingCylinders`, `Trip.divesPerDayTarget` (Task 2); `trips_edit_label_diversSharing`, `trips_edit_hint_diversSharing`, `trips_edit_label_divesPerDay`, `trips_edit_hint_divesPerDay` (Task 7).

- [ ] **Step 1: Write the failing tests**

In `trip_edit_page_test.dart`, give `_MockTripListNotifier` a `Trip? lastUpdated;` field and set it in `updateTrip` (`lastUpdated = trip;` after `updateCalls++;`). Add, next to `_MockTripRepositoryWithTrip`:

```dart
/// The existing trip with fill forecast fields set, for the keep-on-edit
/// test.
class _MockTripRepositoryWithForecastTrip extends _MockTripRepositoryWithTrip {
  @override
  Future<Trip?> getTripById(String id) async =>
      (await super.getTripById(id))!.copyWith(
        diversSharingCylinders: 4,
        divesPerDayTarget: 3,
      );
}
```

Append to `group('TripEditPage - New Trip', ...)`, after 'empty planning fields save as null':

```dart

    testWidgets('the fill forecast fields save as integers', (tester) async {
      final notifier = _MockTripListNotifier([]);
      await _pumpNewTripPage(
        tester,
        repository: _CandidateScanRepo(),
        notifier: notifier,
        activeDiverId: null,
      );
      final sharing = find.widgetWithText(
        TextFormField,
        'Divers sharing cylinders',
      );
      await tester.ensureVisible(sharing);
      await tester.enterText(sharing, '3');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dives per day'),
        '2',
      );
      await _saveNewTrip(tester, 'Bonaire 2026');
      expect(notifier.lastAdded?.diversSharingCylinders, 3);
      expect(notifier.lastAdded?.divesPerDayTarget, 2);
    });

    testWidgets('blank or non-positive fill forecast fields save as the '
        'defaults', (tester) async {
      final notifier = _MockTripListNotifier([]);
      await _pumpNewTripPage(
        tester,
        repository: _CandidateScanRepo(),
        notifier: notifier,
        activeDiverId: null,
      );
      final sharing = find.widgetWithText(
        TextFormField,
        'Divers sharing cylinders',
      );
      await tester.ensureVisible(sharing);
      await tester.enterText(sharing, '0');
      await _saveNewTrip(tester, 'Bonaire 2026');
      expect(notifier.lastAdded?.diversSharingCylinders, 1);
      expect(notifier.lastAdded?.divesPerDayTarget, isNull);
    });
```

Append to `group('TripEditPage - Edit Trip', ...)`, modelled on 'save existing trip calls updateTrip':

```dart

    testWidgets('editing keeps the fill forecast fields', (tester) async {
      final notifier = _MockTripListNotifier([]);
      final router = GoRouter(
        initialLocation: '/trips/edit',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) =>
                const Scaffold(body: Text('LIST_PAGE')),
          ),
          GoRoute(
            path: '/trips/edit',
            builder: (context, state) => const TripEditPage(tripId: 'test-id'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithForecastTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-id',
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Updated Name',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(notifier.lastUpdated?.diversSharingCylinders, 4);
      expect(notifier.lastUpdated?.divesPerDayTarget, 3);
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: FAIL. No 'Divers sharing cylinders' field; the edit saves sharing 1 and no target.

- [ ] **Step 3: Add the fields**

Controllers after `_expectedRuntimeController`: `final _diversSharingController = TextEditingController();` and `final _divesPerDayController = TextEditingController();`. Add `addListener(_onFieldChanged)` for both next to the others, and `dispose()` for both next to the others. On load, after the expected runtime line:

```dart
        _diversSharingController.text = '${trip.diversSharingCylinders}';
        _divesPerDayController.text = trip.divesPerDayTarget?.toString() ?? '';
```

In the Planning section, directly after the expected runtime `TextFormField` and its `const SizedBox(height: 16),`:

```dart
                  // Fill forecast (#2325): who breathes from the trip's
                  // cylinders, and a dives-per-day target. Blank sharing is
                  // one diver; a blank target derives it.
                  TextFormField(
                    controller: _diversSharingController,
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_diversSharing,
                      prefixIcon: const Icon(Icons.groups_outlined),
                      hintText: context.l10n.trips_edit_hint_diversSharing,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _divesPerDayController,
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_divesPerDay,
                      prefixIcon: const Icon(Icons.today_outlined),
                      hintText: context.l10n.trips_edit_hint_divesPerDay,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
```

In `_saveTrip`'s `Trip(...)`, after `expectedRuntimeMinutes: ...,`:

```dart
        // Blank or non-positive is the default: one diver, the estimate.
        diversSharingCylinders:
            _positiveOrNull(_diversSharingController.text) ?? 1,
        divesPerDayTarget: _positiveOrNull(_divesPerDayController.text),
```

- [ ] **Step 4: Run the tests, then the trips presentation suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/pages test/architecture`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_edit_page.dart test/features/trips/presentation/pages/trip_edit_page_test.dart
git commit -m "feat(trips): divers sharing and dives per day on the trip form (#2325)"
```

---

### Task 11: Fill hours on the dive center form

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart` (state ~:54, `_initializeFromCenter` ~:188, `_save` ~:208, `_buildForm` before `// Coordinates Section`)
- Create: `test/features/dive_centers/presentation/pages/dive_center_edit_page_fill_hours_test.dart`

**Interfaces:**
- Consumes: `DiveCenter.fillOpensAt/fillClosesAt` (Task 2), `UnitFormatter.formatMinutesOfDay` (Task 8), the `diveCenters_*fillHours*` strings (Task 7).
- Produces:
  - `enum FillHoursProblem { missingOne, closesBeforeOpens }`
  - `FillHoursProblem? fillHoursProblem(int? opensAt, int? closesAt)`
  - `class DiveCenterFillHoursSection extends StatelessWidget` (keys `fill-hours-opens`, `fill-hours-closes`, `fill-hours-clear`, `fill-hours-error`)

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_centers/presentation/pages/dive_center_edit_page_fill_hours_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  group('fillHoursProblem', () {
    test('neither time is fine', () {
      expect(fillHoursProblem(null, null), isNull);
    });
    test('one time alone is not', () {
      expect(fillHoursProblem(480, null), FillHoursProblem.missingOne);
      expect(fillHoursProblem(null, 1020), FillHoursProblem.missingOne);
    });
    test('closing must follow opening', () {
      expect(fillHoursProblem(480, 1020), isNull);
      expect(fillHoursProblem(1020, 480), FillHoursProblem.closesBeforeOpens);
      expect(fillHoursProblem(480, 480), FillHoursProblem.closesBeforeOpens);
    });
  });

  Future<void> pumpPage(WidgetTester tester, {String? centerId}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterEditPage(
              centerId: centerId,
              embedded: true,
              onSaved: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDefault(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
  }

  testWidgets('the fill hours save with a new center', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends');
    // The pickers open at 08:00 and 17:00.
    await pickDefault(tester, 'fill-hours-opens');
    await pickDefault(tester, 'fill-hours-closes');
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
    await save(tester);

    final saved = (await DiveCenterRepository().getAllDiveCenters()).single;
    expect(saved.fillOpensAt, 480);
    expect(saved.fillClosesAt, 1020);
  });

  testWidgets('one time alone blocks the save', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends');
    await pickDefault(tester, 'fill-hours-opens');
    await save(tester);
    expect(find.text('Set both times, or neither.'), findsOneWidget);
    expect(await DiveCenterRepository().getAllDiveCenters(), isEmpty);
  });

  testWidgets('editing keeps the fill hours', (tester) async {
    final now = DateTime(2026);
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpPage(tester, centerId: center.id);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends 2');
    await save(tester);
    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.name, 'Dive Friends 2');
    expect(saved.fillOpensAt, 480);
    expect(saved.fillClosesAt, 1020);
  });

  testWidgets('clear removes the fill hours', (tester) async {
    final now = DateTime(2026);
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpPage(tester, centerId: center.id);
    await tester.ensureVisible(find.byKey(const Key('fill-hours-clear')));
    await tester.tap(find.byKey(const Key('fill-hours-clear')));
    await tester.pumpAndSettle();
    await save(tester);
    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.fillOpensAt, isNull);
    expect(saved.fillClosesAt, isNull);
  });
}
```

The embedded header's save control is a `FilledButton` labelled "Save" (`_buildEmbeddedHeader`); `.last` skips any other "Save" text.

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_centers/presentation/pages/dive_center_edit_page_fill_hours_test.dart`
Expected: FAIL to compile: `dive_center_fill_hours_section.dart` does not exist.

- [ ] **Step 3: Write the section**

Create `lib/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why a pair of fill hours cannot be saved.
enum FillHoursProblem { missingOne, closesBeforeOpens }

/// Pure. Both times or neither, and the station closes after it opens: one
/// daily window, so no overnight hours (ruling R5).
FillHoursProblem? fillHoursProblem(int? opensAt, int? closesAt) {
  if (opensAt == null && closesAt == null) return null;
  if (opensAt == null || closesAt == null) return FillHoursProblem.missingOne;
  return closesAt > opensAt ? null : FillHoursProblem.closesBeforeOpens;
}

/// The dive center's fill hours: an opening and a closing time, each picked
/// with the time picker and shown in the diver's time format, a clear
/// button, and [errorText] under them when the pair cannot be saved.
class DiveCenterFillHoursSection extends StatelessWidget {
  const DiveCenterFillHoursSection({
    super.key,
    required this.opensAt,
    required this.closesAt,
    required this.units,
    required this.onChanged,
    this.errorText,
  });

  final int? opensAt;
  final int? closesAt;
  final UnitFormatter units;
  final void Function(int? opensAt, int? closesAt) onChanged;
  final String? errorText;

  static const _defaultOpens = 8 * 60;
  static const _defaultCloses = 17 * 60;

  Future<int?> _pick(BuildContext context, int? current, int fallback) async {
    final m = current ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required int? value,
    required VoidCallback onTap,
  }) => ListTile(
    key: key,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(
      value == null
          ? context.l10n.diveCenters_fillHours_notSet
          : units.formatMinutesOfDay(value),
    ),
    trailing: const Icon(Icons.edit),
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.diveCenters_section_fillHours,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (opensAt != null || closesAt != null)
              IconButton(
                key: const Key('fill-hours-clear'),
                tooltip: l10n.diveCenters_fillHours_clear,
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null, null),
              ),
          ],
        ),
        Text(l10n.diveCenters_fillHours_caption, style: theme.textTheme.bodySmall),
        _row(
          context,
          key: const Key('fill-hours-opens'),
          icon: Icons.lock_open_outlined,
          label: l10n.diveCenters_fillHours_opens,
          value: opensAt,
          onTap: () async {
            final m = await _pick(context, opensAt, _defaultOpens);
            if (m != null) onChanged(m, closesAt);
          },
        ),
        _row(
          context,
          key: const Key('fill-hours-closes'),
          icon: Icons.lock_outline,
          label: l10n.diveCenters_fillHours_closes,
          value: closesAt,
          onTap: () async {
            final m = await _pick(context, closesAt, _defaultCloses);
            if (m != null) onChanged(opensAt, m);
          },
        ),
        if (errorText != null)
          Text(
            errorText!,
            key: const Key('fill-hours-error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Put it on the page**

In `dive_center_edit_page.dart` (import `unit_formatter.dart` and the new widget): state fields after `List<String> _selectedAffiliations = [];`:

```dart
  int? _fillOpensAt;
  int? _fillClosesAt;

  /// Set by a save the fill hours blocked, so their error shows from then.
  bool _fillHoursChecked = false;
```

In `_initializeFromCenter`, after `_selectedAffiliations = ...;`:

```dart
    _fillOpensAt = center.fillOpensAt;
    _fillClosesAt = center.fillClosesAt;
```

At the top of `_save`, replace `if (!_formKey.currentState!.validate()) return;` with:

```dart
    final formValid = _formKey.currentState!.validate();
    final hoursValid = fillHoursProblem(_fillOpensAt, _fillClosesAt) == null;
    if (!hoursValid) setState(() => _fillHoursChecked = true);
    if (!formValid || !hoursValid) return;
```

In the `DiveCenter(...)` it builds, after `notes: _notesController.text.trim(),`:

```dart
        fillOpensAt: _fillOpensAt,
        fillClosesAt: _fillClosesAt,
```

Add the method:

```dart
  String? _fillHoursErrorText(BuildContext context) =>
      switch (fillHoursProblem(_fillOpensAt, _fillClosesAt)) {
        null => null,
        FillHoursProblem.missingOne =>
          context.l10n.diveCenters_fillHours_errorBoth,
        FillHoursProblem.closesBeforeOpens =>
          context.l10n.diveCenters_fillHours_errorOrder,
      };
```

In `_buildForm`, directly before `// Coordinates Section`:

```dart
          // Fill hours (#2325): the trip fill forecast's deadline.
          DiveCenterFillHoursSection(
            opensAt: _fillOpensAt,
            closesAt: _fillClosesAt,
            units: UnitFormatter(ref.watch(settingsProvider)),
            errorText: _fillHoursChecked ? _fillHoursErrorText(context) : null,
            onChanged: (opens, closes) => setState(() {
              _fillOpensAt = opens;
              _fillClosesAt = closes;
              _hasChanges = true;
            }),
          ),

          const SizedBox(height: 24),

```

- [ ] **Step 5: Run the tests, then the dive centers suite and the guards**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_centers test/architecture test/shared/widgets/app_date_picker_adoption_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart test/features/dive_centers/presentation/pages/dive_center_edit_page_fill_hours_test.dart
git commit -m "feat(dive-centers): fill hours for the trip fill forecast (#2325)"
```

---

### Task 12: Verification and screenshots

**Files:** none beyond fixes the runs demand.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze --fatal-infos`
Expected: no files changed by the formatter; "No issues found!".

- [ ] **Step 2: Run the affected suites**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips test/features/dive_centers test/core/database test/core/services/sync test/l10n test/architecture test/shared`
Expected: `All tests passed!`

- [ ] **Step 3: Run the full suite once**

Run: `TMPDIR=<scratchpad>/tmp flutter test > <scratchpad>/full.log 2>&1; tail -5 <scratchpad>/full.log`
Expected: `All tests passed!`. A failure outside the touched features goes to the report by name, with whether it also fails on `origin/main`.

- [ ] **Step 4: Screenshots for the PR**

Capture, with a throwaway golden harness in the scratchpad (never committed), light and dark at phone (390x844) and desktop (1280x800) widths, 2x:

1. The trip's cylinders card: before (main) and after, with a short forecast.
2. The board: before (main) and after, with the banner and the day strip.
3. The day plan dialog (new).
4. The trip edit page's Planning section: before and after.
5. The dive center edit page: before and after, with fill hours set.

Send the images to the user; the PR body lists what each shows.

- [ ] **Step 5: Record the schema claim**

Update the ladder memory note: 249 is claimed by this branch (PR 4 of #2325); re-scan open PRs for 249 before pushing.
