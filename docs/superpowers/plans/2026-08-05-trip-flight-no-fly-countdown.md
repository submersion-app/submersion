# Trip Return-Flight No-Fly Countdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store a return-flight departure time on a trip and show, on four surfaces, how much diving time remains before the diver's no-fly interval would collide with that flight.

**Architecture:** The trips feature stores one new nullable timestamp (`trips.return_flight_at`, schema v142). The safety feature owns all math: `NoFlyService` gains a pure `flightWindow()` method reusing the existing preset interval table, and a new provider family computes a `FlightWindowStatus` per trip. Four consumers render it: trip story card, No-Fly page section, dashboard gauge chip, dive-edit warning banner.

**Tech Stack:** Flutter 3 / Material 3, Drift ORM (SQLite), Riverpod, go_router, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-08-05-trip-flight-no-fly-countdown-design.md`

## Global Constraints

- Worktree: all work happens in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-flight-no-fly` on branch `worktree-trip-flight-no-fly`. Run `pwd` before trusting any shell result.
- Schema version: this feature claims **v142**. v138 (divelogs #603) and v139 (equipment currency #805) are reserved by parallel branches; the ladder deliberately skips them. Before starting Task 1, run `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion = "` — if main has advanced past 137, renumber every "142" in this plan to the next free number above both main and open-PR claims.
- Time frame: dive times in this app are **wall-clock-as-UTC** (`DateTime.utc(local components)`, displayed without `toLocal()`). Every new timestamp, comparison, and display in this feature uses that same frame. "Now" is obtained via the new `NoFlyService.wallClockNowUtc()`, never `DateTime.now().toUtc()`.
- Localization: every new user-facing string gets a key in `lib/l10n/arb/app_en.arb` AND translated values in all 10 other catalogs (`app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`), then `flutter gen-l10n`. Real translations, not English copies.
- No emojis anywhere. `dart format .` (whole project) before every commit. `flutter analyze` on the whole project with NO output piping/truncation — infos are fatal in CI.
- Commit messages: plain imperative mood matching repo history (e.g. "Add trips.return_flight_at column"), no `feat:` prefix, no Co-Authored-By line, no session URL.
- Riverpod: import via the barrel `package:submersion/core/providers/provider.dart` (Riverpod 3 legacy shims live there). `ref.invalidateSelfWhen(stream)` is the established self-invalidation helper.
- After any `database.dart` table change: `dart run build_runner build --delete-conflicting-outputs` before analyzing or testing.

---

### Task 1: Schema v142 — `trips.return_flight_at`

**Files:**
- Modify: `lib/core/database/database.dart` (Trips table ~line 62-83; `currentSchemaVersion` line 2864; `migrationVersions` list starting line 2869; onUpgrade v137 block ~line 7159-7163; beforeOpen backstop ~line 7182; helper section near `_assertWeatherCodeColumn` ~line 3933)
- Create: `test/core/database/migration_v142_trip_return_flight_test.dart`

**Interfaces:**
- Consumes: existing `_assertWeatherCodeColumn()` pattern.
- Produces: `trips.return_flight_at` INTEGER nullable column; generated `TripsCompanion.returnFlightAt` / `Trip.returnFlightAt` (Drift row class) after codegen. Later tasks rely on the column name `return_flight_at` and Dart getter `returnFlightAt`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v142_trip_return_flight_test.dart` (modeled exactly on `migration_v137_weather_code_test.dart`):

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v142 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(142));
    expect(AppDatabase.migrationVersions, contains(142));
  });

  test('a fresh database has trips.return_flight_at', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('trips')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('return_flight_at'));
  });

  test(
    'a database stranded before v142 gains return_flight_at via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add return_flight_at even when onUpgrade never ran
      // (v138/v139 are reserved by parallel branches, so a DB can arrive at
      // any intermediate version without this column).
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE trips (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT,
            start_date INTEGER,
            end_date INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('trips')").get();
      expect(
        cols.map((c) => c.read<String>('name')).toSet(),
        contains('return_flight_at'),
      );
    },
  );

  test('the assert is a no-op when the trips table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Opening must not throw on a minimal fixture.
    await db.customSelect('SELECT 1').get();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v142_trip_return_flight_test.dart`
Expected: FAIL — ladder test (137 < 142) and column tests (no `return_flight_at`).

- [ ] **Step 3: Implement the migration**

In `lib/core/database/database.dart`:

3a. In `class Trips extends Table`, after the `isShared` column:

```dart
  /// Return flight departure, wall-clock-as-UTC epoch ms (v142). Drives the
  /// remaining-dive-window countdown; null when the trip has no flight set.
  IntColumn get returnFlightAt => integer().nullable()();
```

3b. Bump `static const int currentSchemaVersion = 137;` to `142`.

3c. Append `142` to the `migrationVersions` list (after `137`).

3d. Add the idempotent helper next to `_assertWeatherCodeColumn()` (~line 3942):

```dart
  /// Idempotent DDL for the v142 return-flight column. Called from the v142
  /// onUpgrade step and the beforeOpen backstop, matching the
  /// _assertWeatherCodeColumn pattern so a schema-version collision cannot
  /// strand a database without it. Self-guarding when the table is absent
  /// (minimal migration-test fixtures).
  Future<void> _assertTripReturnFlightColumn() async {
    final cols = await customSelect("PRAGMA table_info('trips')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('return_flight_at')) {
      await customStatement(
        'ALTER TABLE trips ADD COLUMN return_flight_at INTEGER',
      );
    }
  }
```

3e. In `onUpgrade`, after the `if (from < 137)` block:

```dart
        // v142: trips.return_flight_at (return-flight dive-window countdown).
        // v138/v139 are reserved by parallel branches (#603, #805); the
        // beforeOpen backstop heals any DB stranded between.
        if (from < 142) {
          await _assertTripReturnFlightColumn();
        }
        if (from < 142) await reportProgress();
```

3f. In `beforeOpen`, after the v137 backstop line:

```dart
        // v142 backstop: re-assert trips.return_flight_at.
        await _assertTripReturnFlightColumn();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0; `database.g.dart` gains `returnFlightAt` on the trips row class and companion.

- [ ] **Step 5: Run the migration test and the neighboring ladder tests**

Run: `flutter test test/core/database/migration_v142_trip_return_flight_test.dart test/core/database/migration_v137_weather_code_test.dart test/core/database/migration_v125_no_fly_preset_test.dart`
Expected: PASS (v137/v125 tests use greaterThanOrEqualTo, so the bump to 142 is safe).

- [ ] **Step 6: Verify sync needs no per-column work**

Run: `grep -rn "return_flight\|start_date" lib/core/data/repositories/sync_repository.dart | head`
Expected: no explicit trips column list (export serializes whole rows via generated `toJson()`; hydration uses schema defaults post-#858). If a trips column enumeration DOES appear, add `return_flight_at` there and note it in the commit message.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add trips.return_flight_at column (schema v142)"
```

---

### Task 2: `Trip` entity field

**Files:**
- Modify: `lib/features/trips/domain/entities/trip.dart`
- Modify: `test/features/trips/domain/entities/trip_test.dart`

**Interfaces:**
- Produces: `Trip.returnFlightAt` (`DateTime?`), constructor param `this.returnFlightAt`, `copyWith(returnFlightAt: ...)` supporting explicit-null clearing via the file's existing `_undefined` sentinel. All later tasks use `trip.returnFlightAt`.

- [ ] **Step 1: Write the failing entity tests**

Append to `test/features/trips/domain/entities/trip_test.dart` (reuse the file's existing `Trip` fixture builder if one exists; otherwise construct inline as below):

```dart
  group('returnFlightAt', () {
    final base = Trip(
      id: 't1',
      name: 'Red Sea',
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 8, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

    test('defaults to null and is preserved by unrelated copyWith', () {
      expect(base.returnFlightAt, isNull);
      final withFlight = base.copyWith(
        returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30),
      );
      expect(
        withFlight.copyWith(name: 'Renamed').returnFlightAt,
        DateTime.utc(2026, 8, 10, 14, 30),
      );
    });

    test('copyWith clears returnFlightAt with an explicit null', () {
      final withFlight = base.copyWith(
        returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30),
      );
      expect(withFlight.copyWith(returnFlightAt: null).returnFlightAt, isNull);
    });

    test('participates in equality', () {
      expect(
        base.copyWith(returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30)),
        isNot(equals(base)),
      );
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: FAIL — no `returnFlightAt` parameter.

- [ ] **Step 3: Implement**

In `lib/features/trips/domain/entities/trip.dart`:
- Field after `isShared`: `final DateTime? returnFlightAt;` with doc comment `/// Return flight departure, wall-clock-as-UTC (see dive-time convention).`
- Constructor: `this.returnFlightAt,` after `this.isShared = false,`.
- `copyWith`: parameter `Object? returnFlightAt = _undefined,` and assignment
  `returnFlightAt: returnFlightAt == _undefined ? this.returnFlightAt : returnFlightAt as DateTime?,`
  (identical to the existing `location` sentinel handling).
- `props`: append `returnFlightAt`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/domain/entities/trip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "Add returnFlightAt to Trip entity"
```

---

### Task 3: Repository persistence + mapper consolidation

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`createTrip` ~L118, `updateTrip` ~L164, `_mapRowToTrip` ~L691, raw mappers in `searchTrips` ~L89, `findTripForDate` ~L583, `getAllTripsWithStats` ~L656)
- Modify: `test/features/trips/data/repositories/trip_repository_test.dart`

**Interfaces:**
- Consumes: `Trip.returnFlightAt` (Task 2), `TripsCompanion.returnFlightAt` (Task 1 codegen).
- Produces: round-trip persistence. New private helper `domain.Trip _mapDataToTrip(Map<String, Object?> data)` used by all three raw-SQL sites so a future column cannot miss one.

- [ ] **Step 1: Write the failing repository tests**

Append to `test/features/trips/data/repositories/trip_repository_test.dart`, reusing that file's existing setup/teardown harness (in-memory database via `DatabaseService`) and its existing trip-builder helper if present:

```dart
  group('returnFlightAt persistence', () {
    test('createTrip and getTripById round-trip the flight time', () async {
      final created = await repository.createTrip(
        domain.Trip(
          id: '',
          name: 'Flight trip',
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 10),
          returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30),
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      );
      final loaded = await repository.getTripById(created.id);
      expect(
        loaded!.returnFlightAt!.millisecondsSinceEpoch,
        DateTime.utc(2026, 8, 10, 14, 30).millisecondsSinceEpoch,
      );
    });

    test('updateTrip with null clears a previously set flight time', () async {
      final created = await repository.createTrip(
        domain.Trip(
          id: '',
          name: 'Cleared trip',
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 10),
          returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30),
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      );
      await repository.updateTrip(created.copyWith(returnFlightAt: null));
      final loaded = await repository.getTripById(created.id);
      expect(loaded!.returnFlightAt, isNull);
    });

    test('findTripForDate surfaces returnFlightAt (raw-SQL mapper)', () async {
      await repository.createTrip(
        domain.Trip(
          id: '',
          name: 'Raw mapper trip',
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 10),
          returnFlightAt: DateTime.utc(2026, 8, 10, 14, 30),
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      );
      final found = await repository.findTripForDate(DateTime.utc(2026, 8, 5));
      expect(found!.returnFlightAt, isNotNull);
    });
  });
```

Adjust construction to the harness's conventions (e.g. if the file already has a `makeTrip(...)` helper, extend it with a `returnFlightAt` parameter instead of inlining).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/data/repositories/trip_repository_test.dart`
Expected: FAIL — `returnFlightAt` never persisted (round-trip returns null).

- [ ] **Step 3: Implement**

In `trip_repository.dart`:

3a. `createTrip` companion: add `returnFlightAt: Value(trip.returnFlightAt?.millisecondsSinceEpoch),` after `isShared`.

3b. `updateTrip` companion: add the same line. (`Value(null)` writes SQL NULL, so clearing works without `.toCompanion` tricks.)

3c. `_mapRowToTrip`: add

```dart
      returnFlightAt: row.returnFlightAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.returnFlightAt!)
          : null,
```

3d. Consolidate the three duplicated raw-SQL mappers. Add below `_mapRowToTrip`:

```dart
  /// Shared mapper for customSelect rows (searchTrips, findTripForDate,
  /// getAllTripsWithStats) so a new trips column cannot silently miss one
  /// of the hand-written sites.
  domain.Trip _mapDataToTrip(Map<String, Object?> data) {
    return domain.Trip(
      id: data['id'] as String,
      diverId: data['diver_id'] as String?,
      name: data['name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(data['start_date'] as int),
      endDate: DateTime.fromMillisecondsSinceEpoch(data['end_date'] as int),
      location: data['location'] as String?,
      resortName: data['resort_name'] as String?,
      liveaboardName: data['liveaboard_name'] as String?,
      notes: (data['notes'] as String?) ?? '',
      tripType: TripType.fromName((data['trip_type'] as String?) ?? 'shore'),
      isShared: (data['is_shared'] as int? ?? 0) != 0,
      returnFlightAt: data['return_flight_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['return_flight_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int),
    );
  }
```

Replace the inline `domain.Trip(...)` constructions in `searchTrips`, `findTripForDate`, and `getAllTripsWithStats` with `_mapDataToTrip(row.data)` / `_mapDataToTrip(result.data)` (in `getAllTripsWithStats` keep the surrounding `TripWithStats` wrapper).

- [ ] **Step 4: Run repository tests (all three files, mappers are shared)**

Run: `flutter test test/features/trips/data/repositories/`
Expected: PASS, including pre-existing scan/error tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "Persist trip return flight time and consolidate trip row mappers"
```

---

### Task 4: `NoFlyService.flightWindow()`

**Files:**
- Modify: `lib/features/safety/domain/services/no_fly_service.dart`
- Modify: `test/features/safety/domain/services/no_fly_service_test.dart`

**Interfaces:**
- Consumes: existing `NoFlyPreset`, `NoFlyCategory`, `NoFlyStatus`.
- Produces (used by Tasks 5-11):

```dart
enum FlightWindowState { open, closed, conflict }

class FlightWindowStatus {
  final FlightWindowState state;
  final DateTime flightAt;   // departure, wall-clock-as-UTC
  final DateTime deadline;   // latest safe surfacing time
  final NoFlyCategory category;
  final Duration interval;
  Duration remaining(DateTime now);
}

// on NoFlyService:
static Duration intervalFor(NoFlyPreset preset, NoFlyCategory category);
static DateTime wallClockNowUtc();
FlightWindowStatus? flightWindow({required DateTime flightAt, required NoFlyPreset preset, required NoFlyCategory prospectiveCategory, DateTime? currentNoFlyUntil, required DateTime now});
```

- [ ] **Step 1: Write the failing unit tests**

Append to `test/features/safety/domain/services/no_fly_service_test.dart` (it already declares `const service = NoFlyService();` and frozen-clock style):

```dart
  group('flightWindow', () {
    final flightAt = DateTime.utc(2026, 8, 10, 9); // Mon 09:00 departure

    test('open: standard repetitive deadline is departure - 18h', () {
      final now = DateTime.utc(2026, 8, 9, 10);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: now,
      );
      expect(status!.state, FlightWindowState.open);
      expect(status.deadline, DateTime.utc(2026, 8, 9, 15));
      expect(status.remaining(now), const Duration(hours: 5));
    });

    test('closed: past the deadline but before departure', () {
      final now = DateTime.utc(2026, 8, 9, 16);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: now,
      );
      expect(status!.state, FlightWindowState.closed);
      expect(status.remaining(now), Duration.zero);
    });

    test('exactly at the deadline counts as closed', () {
      final now = DateTime.utc(2026, 8, 9, 15);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: now,
      );
      expect(status!.state, FlightWindowState.closed);
    });

    test('conflict: existing no-fly reaches past departure, beats open', () {
      final now = DateTime.utc(2026, 8, 9, 10);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.deco,
        currentNoFlyUntil: DateTime.utc(2026, 8, 10, 12),
        now: now,
      );
      expect(status!.state, FlightWindowState.conflict);
    });

    test('strict deco: deadline is departure - 48h', () {
      final now = DateTime.utc(2026, 8, 8, 8);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.strict,
        prospectiveCategory: NoFlyCategory.deco,
        currentNoFlyUntil: null,
        now: now,
      );
      expect(status!.deadline, DateTime.utc(2026, 8, 8, 9));
      expect(status.state, FlightWindowState.open);
      expect(status.interval, const Duration(hours: 48));
    });

    test('returns null once the flight has departed', () {
      final now = DateTime.utc(2026, 8, 10, 10);
      expect(
        service.flightWindow(
          flightAt: flightAt,
          preset: NoFlyPreset.standard,
          prospectiveCategory: NoFlyCategory.repetitive,
          currentNoFlyUntil: null,
          now: now,
        ),
        isNull,
      );
    });
  });

  test('intervalFor matches the table evaluate() uses', () {
    expect(
      NoFlyService.intervalFor(NoFlyPreset.standard, NoFlyCategory.single),
      const Duration(hours: 12),
    );
    expect(
      NoFlyService.intervalFor(NoFlyPreset.strict, NoFlyCategory.repetitive),
      const Duration(hours: 24),
    );
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/safety/domain/services/no_fly_service_test.dart`
Expected: FAIL — `flightWindow` / `intervalFor` undefined.

- [ ] **Step 3: Implement**

In `no_fly_service.dart`:

3a. After the `NoFlyStatus` class, add:

```dart
/// State of the forward-looking dive window before a booked flight.
enum FlightWindowState {
  /// Diving may continue; the diver must surface by [FlightWindowStatus.deadline].
  open,

  /// The deadline has passed: no more diving before this flight.
  closed,

  /// The diver's existing no-fly restriction already extends past the
  /// flight departure. Takes precedence over open/closed.
  conflict,
}

/// Forward-looking dive window for a trip's return flight: the latest safe
/// surfacing time is the departure minus the guideline interval for the
/// (preset, category) pair. Same fixed-interval doctrine as [NoFlyStatus].
class FlightWindowStatus {
  final FlightWindowState state;

  /// Flight departure, wall-clock-as-UTC (the dive-time frame).
  final DateTime flightAt;

  /// Latest safe surfacing time before [flightAt].
  final DateTime deadline;

  final NoFlyCategory category;
  final Duration interval;

  const FlightWindowStatus({
    required this.state,
    required this.flightAt,
    required this.deadline,
    required this.category,
    required this.interval,
  });

  Duration remaining(DateTime now) =>
      deadline.isAfter(now) ? deadline.difference(now) : Duration.zero;
}
```

3b. In `NoFlyService`, extract the interval table (replace the inline `switch` inside `evaluate` with a call to this):

```dart
  /// Guideline pre-flight surface interval for a (preset, category) pair.
  /// Single source of truth shared by [evaluate] and [flightWindow].
  static Duration intervalFor(NoFlyPreset preset, NoFlyCategory category) {
    return switch ((preset, category)) {
      (NoFlyPreset.standard, NoFlyCategory.single) => const Duration(hours: 12),
      (NoFlyPreset.standard, NoFlyCategory.repetitive) => const Duration(
        hours: 18,
      ),
      (NoFlyPreset.standard, NoFlyCategory.deco) => const Duration(hours: 24),
      (NoFlyPreset.strict, NoFlyCategory.single) => const Duration(hours: 18),
      (NoFlyPreset.strict, NoFlyCategory.repetitive) => const Duration(
        hours: 24,
      ),
      (NoFlyPreset.strict, NoFlyCategory.deco) => const Duration(hours: 48),
    };
  }

  /// The current moment in the app's wall-clock-as-UTC dive-time frame.
  /// Dive entry/exit times are stored as `DateTime.utc(local components)`,
  /// so comparisons against them must use the same construction -- NOT
  /// `DateTime.now().toUtc()`, which is the true instant and differs by the
  /// device's UTC offset.
  static DateTime wallClockNowUtc() {
    final now = DateTime.now();
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  /// Computes the dive window before [flightAt], or null when the flight has
  /// already departed. [prospectiveCategory] is the caller's forward-looking
  /// classification (at least repetitive on a trip); [currentNoFlyUntil] is
  /// the backward-looking restriction end used to detect a conflict.
  FlightWindowStatus? flightWindow({
    required DateTime flightAt,
    required NoFlyPreset preset,
    required NoFlyCategory prospectiveCategory,
    DateTime? currentNoFlyUntil,
    required DateTime now,
  }) {
    if (!flightAt.isAfter(now)) return null;
    final interval = intervalFor(preset, prospectiveCategory);
    final deadline = flightAt.subtract(interval);
    final FlightWindowState state;
    if (currentNoFlyUntil != null && currentNoFlyUntil.isAfter(flightAt)) {
      state = FlightWindowState.conflict;
    } else if (now.isBefore(deadline)) {
      state = FlightWindowState.open;
    } else {
      state = FlightWindowState.closed;
    }
    return FlightWindowStatus(
      state: state,
      flightAt: flightAt,
      deadline: deadline,
      category: prospectiveCategory,
      interval: interval,
    );
  }
```

3c. In `evaluate`, replace `final interval = switch ((preset, category)) { ... };` with `final interval = intervalFor(preset, category);` and delete the inline table.

- [ ] **Step 4: Run the whole safety unit-test directory (evaluate refactor regression)**

Run: `flutter test test/features/safety/domain/services/`
Expected: PASS — all pre-existing `evaluate` tests plus the new group.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "Add FlightWindowStatus and NoFlyService.flightWindow"
```

---

### Task 5: Flight-window providers

**Files:**
- Create: `lib/features/safety/presentation/providers/flight_window_providers.dart`
- Create: `test/features/safety/presentation/providers/flight_window_providers_test.dart`

**Interfaces:**
- Consumes: `NoFlyService.flightWindow/intervalFor/wallClockNowUtc` (Task 4), `Trip.returnFlightAt` (Task 2), `tripRepositoryProvider`/`tripForDateProvider` (existing), `diveRepositoryProvider.getNoFlyDiveInputs` (existing), `settingsProvider.noFlyPreset` (existing).
- Produces:
  - `final tripFlightWindowProvider = FutureProvider.family<FlightWindowStatus?, String>` (keyed by trip id)
  - `final activeTripFlightWindowProvider = FutureProvider<FlightWindowStatus?>`

- [ ] **Step 1: Write the failing provider tests**

Create `test/features/safety/presentation/providers/flight_window_providers_test.dart`. Open `test/features/safety/presentation/providers/no_fly_providers_test.dart` first and reuse its harness verbatim (database/DatabaseService setup, settings mock via `test/helpers` — see the settings-notifier mock helpers used across provider tests). Cover these four cases:

1. Trip with `returnFlightAt` 24h ahead, no dives logged: status non-null, `state == FlightWindowState.open`, `category == NoFlyCategory.repetitive` (floor applies even with zero dives), `deadline == returnFlightAt - 18h` under the standard preset.
2. Trip with a deco dive inside the 48h lookback: `category == NoFlyCategory.deco`, `deadline == returnFlightAt - 24h`.
3. Trip without `returnFlightAt`: provider returns null.
4. Dive ending so recently that `until` (repetitive interval from dive end) lands after `returnFlightAt`: `state == FlightWindowState.conflict`.

Use wall-clock-as-UTC fixtures (`DateTime.utc(...)`) for trip flight times and dive end times, mirroring how `no_fly_dive_inputs_test.dart` seeds dives.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/safety/presentation/providers/flight_window_providers_test.dart`
Expected: FAIL — file under test does not exist.

- [ ] **Step 3: Implement the providers**

Create `lib/features/safety/presentation/providers/flight_window_providers.dart`:

```dart
import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Forward-looking dive window for one trip's return flight, or null when
/// the trip has no flight set (or it already departed).
///
/// Category floor is repetitive: a trip is multi-day diving by definition,
/// so the single-dive interval would overstate the window. A deco dive in
/// the lookback escalates to the deco interval.
final tripFlightWindowProvider =
    FutureProvider.family<FlightWindowStatus?, String>((ref, tripId) async {
      final tripRepository = ref.watch(tripRepositoryProvider);
      ref.invalidateSelfWhen(tripRepository.watchTripsChanges());

      final trip = await tripRepository.getTripById(tripId);
      final flightAt = trip?.returnFlightAt;
      if (flightAt == null) return null;

      final diveRepository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final preset = ref.watch(settingsProvider.select((s) => s.noFlyPreset));
      final diverId = ref.watch(currentDiverIdProvider);

      final now = NoFlyService.wallClockNowUtc();
      const service = NoFlyService();

      NoFlyStatus? current;
      if (diverId != null) {
        final dives = await diveRepository.getNoFlyDiveInputs(
          since: now.subtract(NoFlyService.lookback),
          diverId: diverId,
        );
        current = service.evaluate(dives: dives, preset: preset, now: now);
      }

      final category = current?.category == NoFlyCategory.deco
          ? NoFlyCategory.deco
          : NoFlyCategory.repetitive;
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: preset,
        prospectiveCategory: category,
        currentNoFlyUntil: current?.until,
        now: now,
      );

      // State flips (open -> closed at the deadline, gone at departure)
      // happen without any table write; self-invalidate just past the next
      // boundary, mirroring noFlyStatusProvider's expiry timer.
      if (status != null) {
        final boundary = now.isBefore(status.deadline)
            ? status.deadline
            : status.flightAt;
        final untilBoundary = boundary.difference(now);
        if (untilBoundary > Duration.zero) {
          final timer = Timer(
            untilBoundary + const Duration(seconds: 1),
            ref.invalidateSelf,
          );
          ref.onDispose(timer.cancel);
        }
      }
      return status;
    });

/// Flight window for the trip containing today, or null. Feeds the
/// dashboard gauge and the No-Fly page.
final activeTripFlightWindowProvider = FutureProvider<FlightWindowStatus?>((
  ref,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final trip = await ref.watch(tripForDateProvider(today).future);
  if (trip == null || trip.returnFlightAt == null) return null;
  return ref.watch(tripFlightWindowProvider(trip.id).future);
});
```

- [ ] **Step 4: Run the provider tests**

Run: `flutter test test/features/safety/presentation/providers/`
Expected: PASS (new file plus pre-existing no_fly/emergency/incident provider tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "Add flight window providers"
```

---

### Task 6: Trip edit page — return flight field

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart` (state vars ~L55, hydration ~L128, dates section ~L232-283, picker helpers ~L680, `_saveTrip` ~L770)
- Modify: `lib/l10n/arb/app_en.arb` + the 10 other catalogs
- Modify: `test/features/trips/presentation/pages/trip_edit_page_test.dart`

**Interfaces:**
- Consumes: `Trip.returnFlightAt`, `showAppDatePicker` (`lib/shared/widgets/app_date_picker.dart`), Material `showTimePicker`.
- Produces: l10n keys `trips_edit_returnFlightLabel` ("Return flight"), `trips_edit_returnFlightNotSet` ("Not set"), `trips_edit_returnFlightClear` ("Clear return flight").

- [ ] **Step 1: Add the l10n strings**

In `app_en.arb`, next to the other `trips_edit_*` keys:

```json
  "trips_edit_returnFlightLabel": "Return flight",
  "trips_edit_returnFlightNotSet": "Not set",
  "trips_edit_returnFlightClear": "Clear return flight",
```

Add matching `@`-metadata only if sibling keys have it (the `trips_*` metadata block sits later in the file; simple no-placeholder strings need no metadata). Translate all three into the 10 other catalogs. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

Append to `test/features/trips/presentation/pages/trip_edit_page_test.dart`, reusing its pump harness:

```dart
    testWidgets('return flight row shows Not set and opens pickers', (
      tester,
    ) async {
      // Pump the edit page for a new trip using the file's existing harness.
      // 1. Expect find.text('Return flight') to be present in the dates
      //    section and 'Not set' as its subtitle.
      // 2. Tap the row; a date picker dialog appears (find.byType(DatePickerDialog)).
      // 3. Confirm today's date; a time picker appears (find.byType(TimePickerDialog)).
      // 4. Confirm; the subtitle now contains a formatted date instead of 'Not set'.
      // 5. Tap the clear icon (find.byIcon(Icons.clear)); subtitle reverts to 'Not set'.
    });
```

Fill the body with the harness's real pump/override calls (the file already pumps `TripEditPage` inside a localized `MaterialApp` — pin `locale: const Locale('en')` per the widget-test locale convention).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: new test FAILS (no 'Return flight' text).

- [ ] **Step 4: Implement the field**

In `trip_edit_page.dart`:

4a. State (near `_startDate`/`_endDate`): `DateTime? _returnFlightAt;`

4b. Hydration (where `_startDate = trip.startDate;` happens): `_returnFlightAt = trip.returnFlightAt;`

4c. UI — after the duration row in the dates section:

```dart
        Semantics(
          button: true,
          label: l10n.trips_edit_returnFlightLabel,
          child: ListTile(
            leading: const Icon(Icons.flight_land),
            title: Text(l10n.trips_edit_returnFlightLabel),
            subtitle: Text(
              _returnFlightAt == null
                  ? l10n.trips_edit_returnFlightNotSet
                  : '${dateFormat.format(_returnFlightAt!)}, '
                        '${TimeOfDay.fromDateTime(_returnFlightAt!).format(context)}',
            ),
            trailing: _returnFlightAt == null
                ? const Icon(Icons.edit)
                : IconButton(
                    tooltip: l10n.trips_edit_returnFlightClear,
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _returnFlightAt = null;
                      _hasChanges = true;
                    }),
                  ),
            contentPadding: EdgeInsets.zero,
            onTap: _selectReturnFlight,
          ),
        ),
```

(`dateFormat` already exists in scope; match how the start/end tiles obtain `l10n`.)

4d. Picker helper next to `_selectDate` (two sequential pickers, the dive-edit `_editEntry` pattern; wall-clock-as-UTC construction):

```dart
  Future<void> _selectReturnFlight() async {
    final initial =
        _returnFlightAt ??
        DateTime(_endDate.year, _endDate.month, _endDate.day, 12);
    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;
    setState(() {
      // Wall-clock-as-UTC, the same frame as dive times, so the no-fly
      // math can compare this directly against dive end times.
      _returnFlightAt = DateTime.utc(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _hasChanges = true;
    });
  }
```

4e. `_saveTrip`: add `returnFlightAt: _returnFlightAt,` to the `Trip(...)` construction.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/trips/presentation/pages/trip_edit_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "Add return flight picker to trip edit page"
```

---

### Task 7: `FlightWindowCard` + No-Fly page section

**Files:**
- Create: `lib/features/safety/presentation/widgets/flight_window_card.dart`
- Modify: `lib/features/safety/presentation/pages/no_fly_page.dart` (ListView children ~L45-69)
- Modify: `lib/l10n/arb/app_en.arb` + 10 catalogs
- Create: `test/features/safety/presentation/widgets/flight_window_card_test.dart`

**Interfaces:**
- Consumes: `FlightWindowStatus` (Task 4), `activeTripFlightWindowProvider` (Task 5), `formatNoFlyRemaining` (`lib/features/safety/presentation/formatters/no_fly_format.dart`).
- Produces: `class FlightWindowCard extends StatelessWidget { const FlightWindowCard({super.key, required this.status}); final FlightWindowStatus status; }` — reused by Task 8's trip story wrapper.
- Produces l10n keys:

```json
  "flightWindow_openTitle": "Time left to dive: {remaining}",
  "@flightWindow_openTitle": {
    "placeholders": { "remaining": { "type": "String" } }
  },
  "flightWindow_surfaceBy": "Surface by {time}",
  "@flightWindow_surfaceBy": {
    "placeholders": { "time": { "type": "String" } }
  },
  "flightWindow_departs": "Flight departs {time}",
  "@flightWindow_departs": {
    "placeholders": { "time": { "type": "String" } }
  },
  "flightWindow_closed": "No more diving before your flight",
  "flightWindow_conflict": "Your no-fly time extends past your flight departure",
```

- [ ] **Step 1: Add the l10n strings** (en + 10 translations, `flutter gen-l10n`).

- [ ] **Step 2: Write the failing widget test**

Create `test/features/safety/presentation/widgets/flight_window_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, FlightWindowStatus status) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FlightWindowCard(status: status)),
      ),
    );
  }

  FlightWindowStatus status(FlightWindowState state) => FlightWindowStatus(
    state: state,
    flightAt: DateTime.utc(2126, 8, 10, 9),
    deadline: DateTime.utc(2126, 8, 9, 15),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  testWidgets('open state shows countdown and surface-by time', (tester) async {
    await pumpCard(tester, status(FlightWindowState.open));
    expect(find.textContaining('Time left to dive'), findsOneWidget);
    expect(find.textContaining('Surface by'), findsOneWidget);
  });

  testWidgets('closed state shows the stop-diving message', (tester) async {
    await pumpCard(tester, status(FlightWindowState.closed));
    expect(find.text('No more diving before your flight'), findsOneWidget);
    expect(find.textContaining('Flight departs'), findsOneWidget);
  });

  testWidgets('conflict state shows the alert message', (tester) async {
    await pumpCard(tester, status(FlightWindowState.conflict));
    expect(
      find.text('Your no-fly time extends past your flight departure'),
      findsOneWidget,
    );
  });
}
```

(Far-future fixture dates keep the open state's `remaining(now)` positive without a fake clock.)

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/safety/presentation/widgets/flight_window_card_test.dart`
Expected: FAIL — widget file missing.

- [ ] **Step 4: Implement the card**

Create `lib/features/safety/presentation/widgets/flight_window_card.dart` (mirrors `NoFlyStatusCard`'s Card > Padding > Column layout):

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Presentational card for a [FlightWindowStatus]. Parents own the ticking:
/// re-build (NoFlyPage's minute timer, the trip story wrapper's timer) and
/// the countdown re-renders against the current wall-clock.
class FlightWindowCard extends StatelessWidget {
  final FlightWindowStatus status;

  const FlightWindowCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final now = NoFlyService.wallClockNowUtc();
    // Wall-clock-as-UTC values format their components directly -- no
    // toLocal(), matching how dive times are displayed everywhere.
    final timeFormat = DateFormat.E().add_jm();

    final (IconData icon, Color color, String title, String subtitle) =
        switch (status.state) {
          FlightWindowState.open => (
            Icons.flight_takeoff,
            scheme.primary,
            l10n.flightWindow_openTitle(
              formatNoFlyRemaining(status.remaining(now)),
            ),
            l10n.flightWindow_surfaceBy(timeFormat.format(status.deadline)),
          ),
          FlightWindowState.closed => (
            Icons.airplanemode_inactive,
            scheme.tertiary,
            l10n.flightWindow_closed,
            l10n.flightWindow_departs(timeFormat.format(status.flightAt)),
          ),
          FlightWindowState.conflict => (
            Icons.warning_amber,
            scheme.error,
            l10n.flightWindow_conflict,
            l10n.flightWindow_departs(timeFormat.format(status.flightAt)),
          ),
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
```

Check `formatNoFlyRemaining`'s exact signature in `no_fly_format.dart` before use; it takes a `Duration`.

- [ ] **Step 5: Wire into the No-Fly page**

In `no_fly_page.dart`, add to the `ListView` children right after the status-card if/else chain:

```dart
        Consumer(
          builder: (context, ref, _) {
            final flightAsync = ref.watch(activeTripFlightWindowProvider);
            final flight = flightAsync.valueOrNull;
            if (flight == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FlightWindowCard(status: flight),
            );
          },
        ),
```

Imports: `flight_window_providers.dart`, `flight_window_card.dart`. The page is already a `ConsumerStatefulWidget` with a minute ticker, so if it watches via `ref` directly instead of a nested `Consumer`, that is also fine — match the file's style. The existing router test (`app_router_test.dart` 'noFly route builds the NoFlyPage') now exercises `activeTripFlightWindowProvider`; if it fails on missing database/diver setup, override `activeTripFlightWindowProvider` with `(ref) async => null` in that test's ProviderScope.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/safety/ test/core/router/app_router_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "Add flight window card and No-Fly page section"
```

---

### Task 8: Trip story countdown card

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart` (`_contentSlivers()` ~L265-338, insertion right after the hero sliver, before the liveaboard block)
- Create: `test/features/trips/presentation/widgets/story/trip_flight_countdown_card_test.dart`

**Interfaces:**
- Consumes: `tripFlightWindowProvider` (Task 5), `FlightWindowCard` (Task 7), `TripStory.trip` (existing).
- Produces: `class TripFlightCountdownCard extends ConsumerStatefulWidget { const TripFlightCountdownCard({super.key, required this.tripId}); final String tripId; }`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/trips/presentation/widgets/story/trip_flight_countdown_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FlightWindowStatus? status,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripFlightWindowProvider('t1').overrideWith((ref) async => status),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TripFlightCountdownCard(tripId: 't1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the flight window card when a status exists', (
    tester,
  ) async {
    await pump(
      tester,
      status: FlightWindowStatus(
        state: FlightWindowState.open,
        flightAt: DateTime.utc(2126, 8, 10, 9),
        deadline: DateTime.utc(2126, 8, 9, 15),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    expect(find.textContaining('Time left to dive'), findsOneWidget);
  });

  testWidgets('renders nothing when the provider yields null', (tester) async {
    await pump(tester, status: null);
    expect(find.byType(Card), findsNothing);
  });
}
```

Note: the widget's periodic `Timer` must be created only in `initState` and cancelled in `dispose`, or `pumpAndSettle` will loop; with a 1-minute period this is safe.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_flight_countdown_card_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement the wrapper widget**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';

/// Trip story wrapper around [FlightWindowCard]: watches the trip's flight
/// window and re-renders each minute so the countdown stays current.
class TripFlightCountdownCard extends ConsumerStatefulWidget {
  final String tripId;

  const TripFlightCountdownCard({super.key, required this.tripId});

  @override
  ConsumerState<TripFlightCountdownCard> createState() =>
      _TripFlightCountdownCardState();
}

class _TripFlightCountdownCardState
    extends ConsumerState<TripFlightCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(tripFlightWindowProvider(widget.tripId));
    final status = statusAsync.valueOrNull;
    if (status == null) return const SizedBox.shrink();
    return FlightWindowCard(status: status);
  }
}
```

- [ ] **Step 4: Insert into the story view**

In `trip_story_view.dart` `_contentSlivers()`, between the hero sliver and the `if (trip.isLiveaboard)` block:

```dart
      if (trip.returnFlightAt != null && trip.isInProgress)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: TripFlightCountdownCard(tripId: trip.id),
          ),
        ),
```

(Shown only while the trip is underway; `isInProgress` is date-only, and the provider itself returns null once the flight departs.)

- [ ] **Step 5: Run story tests**

Run: `flutter test test/features/trips/presentation/widgets/story/`
Expected: PASS — new test plus existing story tests. `trip_story_view_test.dart` pumps stories whose trips have `returnFlightAt == null`, so the sliver stays absent there; if any story fixture trip is in progress AND gains a flight time, override `tripFlightWindowProvider(<id>)` in that test.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "Show flight window countdown card in trip story"
```

---

### Task 9: Dashboard gauge chip

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/gauge_providers.dart` (`HomeChipType` ~L24-37, `DashboardGauges` ~L53-103, `dashboardGaugesProvider` ~L180-216)
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart` (no-fly chip block ~L152-178)
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart` (exhaustive `chipName` switch ~L24)
- Modify: `lib/l10n/arb/app_en.arb` + 10 catalogs
- Modify: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart`

**Interfaces:**
- Consumes: `activeTripFlightWindowProvider`, `FlightWindowStatus`, `NoFlyService.wallClockNowUtc`.
- Produces: `HomeChipType.flightWindow` enum value; `DashboardGauges.flightWindow` (`FlightWindowStatus?`, constructor param, default null so existing const fixtures stay valid).
- Produces l10n keys:

```json
  "dashboard_gauges_flightWindow": "Dive window {hours}:{minutes}",
  "@dashboard_gauges_flightWindow": {
    "placeholders": {
      "hours": { "type": "String" },
      "minutes": { "type": "String" }
    }
  },
  "dashboard_gauges_flightWindowClosed": "No more diving before flight",
  "settings_homeChips_flightWindow": "Flight dive window",
```

- [ ] **Step 1: Add the l10n strings** (en + 10 translations, `flutter gen-l10n`).

- [ ] **Step 2: Write the failing widget test**

Append to `test/features/dashboard/presentation/widgets/gauge_strip_test.dart`, reusing `pumpStrip` and the `_emptyGauges` fixture (copy it with the new field via the class's copy pattern or construct a new `DashboardGauges` inline):

```dart
  testWidgets('shows flight window chip when a window is open', (tester) async {
    final gauges = DashboardGauges(
      gearGauges: const [],
      hasGear: true,
      insurance: null,
      noFlyStatus: null,
      daysSinceLastDive: null,
      flightWindow: FlightWindowStatus(
        state: FlightWindowState.open,
        flightAt: DateTime.utc(2126, 8, 10, 9),
        deadline: DateTime.utc(2126, 8, 9, 15),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    await pumpStrip(tester, gauges);
    expect(find.textContaining('Dive window'), findsOneWidget);
  });

  testWidgets('shows closed flight chip after the deadline', (tester) async {
    final gauges = DashboardGauges(
      gearGauges: const [],
      hasGear: true,
      insurance: null,
      noFlyStatus: null,
      daysSinceLastDive: null,
      flightWindow: FlightWindowStatus(
        state: FlightWindowState.closed,
        flightAt: DateTime.utc(2126, 8, 10, 9),
        deadline: DateTime.utc(2126, 8, 9, 15),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );
    await pumpStrip(tester, gauges);
    expect(find.text('No more diving before flight'), findsOneWidget);
  });

  testWidgets('shows no flight chip when no window exists', (tester) async {
    await pumpStrip(tester, _emptyGauges);
    expect(find.textContaining('Dive window'), findsNothing);
  });
```

Match the fixture's actual required constructor arguments to `_emptyGauges` in the file (it may list more fields than shown here).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/dashboard/presentation/widgets/gauge_strip_test.dart`
Expected: FAIL — `flightWindow` parameter unknown.

- [ ] **Step 4: Implement**

4a. `gauge_providers.dart`:
- `HomeChipType`: add `flightWindow,` (append at the end; `.name` is the persisted id, order is irrelevant).
- `DashboardGauges`: add `final FlightWindowStatus? flightWindow;` and constructor param `this.flightWindow,` (import `no_fly_service.dart` is already present for `NoFlyStatus`; add `flight_window_providers.dart` import in this file for the provider).
- `dashboardGaugesProvider`: add `final flightWindow = await ref.watch(activeTripFlightWindowProvider.future);` alongside the no-fly line and pass `flightWindow: flightWindow,`.

4b. `gauge_strip.dart` — after the existing no-fly chip block:

```dart
    if (_shown(hidden, HomeChipType.flightWindow)) {
      final flight = g.flightWindow;
      if (flight != null) {
        switch (flight.state) {
          case FlightWindowState.open:
            final remaining = flight.remaining(NoFlyService.wallClockNowUtc());
            chips.add(
              _chip(
                context,
                icon: Icons.flight_takeoff_outlined,
                label: l10n.dashboard_gauges_flightWindow(
                  remaining.inHours.toString(),
                  (remaining.inMinutes % 60).toString().padLeft(2, '0'),
                ),
                tone: _Tone.warn,
                onTap: () => context.goNamed('noFly'),
              ),
            );
          case FlightWindowState.closed:
          case FlightWindowState.conflict:
            chips.add(
              _chip(
                context,
                icon: Icons.flight_takeoff_outlined,
                label: l10n.dashboard_gauges_flightWindowClosed,
                tone: _Tone.alert,
                onTap: () => context.goNamed('noFly'),
              ),
            );
        }
      }
    }
```

(If the file navigates with `context.go('/path')` only, mirror the no-fly page's actual full path from `app_router.dart` instead of `goNamed`; check how the trip chip navigates and stay consistent.)

4c. `home_appearance_page.dart`: the `chipName` switch is exhaustive — add
`HomeChipType.flightWindow => l10n.settings_homeChips_flightWindow,`.

- [ ] **Step 5: Run dashboard tests**

Run: `flutter test test/features/dashboard/`
Expected: PASS. Known trap: `dashboardGaugesProvider` now watches `activeTripFlightWindowProvider`, which reaches the trip repository — provider-level tests (`gauge_providers_test.dart`, `dashboard_gauges_provider_test.dart`) may fail on missing setup even though `flutter analyze` is clean. Fix by overriding `activeTripFlightWindowProvider.overrideWith((ref) async => null)` in those tests' ProviderScopes/containers.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "Add flight window chip to dashboard gauge strip"
```

---

### Task 10: Dive edit warning banner

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/flight_window_warning_banner.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (form column children ~L794-839; state fields `_entryDate`/`_entryTime`/`_exitDate`/`_exitTime`/`_runtimeController` ~L152-157)
- Modify: `lib/l10n/arb/app_en.arb` + 10 catalogs
- Create: `test/features/dive_log/presentation/widgets/flight_window_warning_banner_test.dart`

**Interfaces:**
- Consumes: `tripFlightWindowProvider` (Task 5).
- Produces: `class FlightWindowWarningBanner extends ConsumerWidget { const FlightWindowWarningBanner({super.key, required this.tripId, required this.diveEndTime}); final String? tripId; final DateTime? diveEndTime; }`
- Produces l10n key:

```json
  "diveEdit_flightWindowWarning": "This dive ends after the latest safe surfacing time for your flight ({time})",
  "@diveEdit_flightWindowWarning": {
    "placeholders": { "time": { "type": "String" } }
  },
```

- [ ] **Step 1: Add the l10n string** (en + 10 translations, `flutter gen-l10n`).

- [ ] **Step 2: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/flight_window_warning_banner_test.dart` (same override approach as Task 8's test):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/flight_window_warning_banner.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final openStatus = FlightWindowStatus(
    state: FlightWindowState.open,
    flightAt: DateTime.utc(2126, 8, 10, 9),
    deadline: DateTime.utc(2126, 8, 9, 15),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  Future<void> pump(
    WidgetTester tester, {
    required String? tripId,
    required DateTime? diveEndTime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripFlightWindowProvider(
            't1',
          ).overrideWith((ref) async => openStatus),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FlightWindowWarningBanner(
              tripId: tripId,
              diveEndTime: diveEndTime,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('warns when the dive ends after the deadline', (tester) async {
    await pump(
      tester,
      tripId: 't1',
      diveEndTime: DateTime.utc(2126, 8, 9, 16),
    );
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsOneWidget,
    );
  });

  testWidgets('silent when the dive ends before the deadline', (tester) async {
    await pump(
      tester,
      tripId: 't1',
      diveEndTime: DateTime.utc(2126, 8, 9, 12),
    );
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsNothing,
    );
    expect(find.byType(SizedBox), findsWidgets); // collapsed to shrink
  });

  testWidgets('silent without a trip', (tester) async {
    await pump(
      tester,
      tripId: null,
      diveEndTime: DateTime.utc(2126, 8, 9, 16),
    );
    expect(
      find.textContaining('after the latest safe surfacing time'),
      findsNothing,
    );
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/flight_window_warning_banner_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 4: Implement the banner**

Create `flight_window_warning_banner.dart` (styling mirrors `trip_service_alert_banner.dart`; non-interactive, warn-only):

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Non-blocking warning shown while editing a dive whose end time falls
/// after the latest safe surfacing time for the trip's return flight.
/// Warn, never block: the diver may be logging a past trip or know better.
class FlightWindowWarningBanner extends ConsumerWidget {
  final String? tripId;
  final DateTime? diveEndTime;

  const FlightWindowWarningBanner({
    super.key,
    required this.tripId,
    required this.diveEndTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = tripId;
    final end = diveEndTime;
    if (id == null || end == null) return const SizedBox.shrink();

    final status = ref.watch(tripFlightWindowProvider(id)).valueOrNull;
    if (status == null || !end.isAfter(status.deadline)) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.E().add_jm().format(status.deadline);
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.flight_takeoff, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.diveEdit_flightWindowWarning(time),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire into the dive edit page**

5a. Find the selected-trip state variable: `grep -n "tripId" lib/features/dive_log/presentation/pages/dive_edit_page.dart | head -20` (the trip group section binds it; expect a field like `String? _selectedTripId` or similar — use the actual name found).

5b. Add an end-time helper near the other private helpers (same derivation `_saveDive` uses — exit fields if both set, else entry + runtime minutes):

```dart
  /// In-edit dive end time, wall-clock-as-UTC: exit fields when both are
  /// set, otherwise entry + runtime. Null when neither is derivable.
  DateTime? _currentDiveEndTime() {
    if (_exitDate != null && _exitTime != null) {
      return DateTime.utc(
        _exitDate!.year,
        _exitDate!.month,
        _exitDate!.day,
        _exitTime!.hour,
        _exitTime!.minute,
      );
    }
    final entry = DateTime.utc(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
      _entryTime.hour,
      _entryTime.minute,
    );
    final runtimeMinutes = int.tryParse(_runtimeController.text);
    if (runtimeMinutes == null || runtimeMinutes <= 0) return null;
    return entry.add(Duration(minutes: runtimeMinutes));
  }
```

5c. In the form column children, immediately before `_buildTheDiveSection(units)`:

```dart
            FlightWindowWarningBanner(
              tripId: /* the trip id field found in 5a */,
              diveEndTime: _currentDiveEndTime(),
            ),
```

The page rebuilds on every `setState` (entry/exit edits, runtime typing via `onChanged: _markDirty`), so the banner tracks edits live. If runtime edits don't trigger rebuilds (controller listeners only), add a `listener: () => setState(() {})` on `_runtimeController` in `initState` — verify by manual reasoning about `_markDirty` first; only add if actually needed.

- [ ] **Step 6: Run dive edit tests**

Run: `flutter test test/features/dive_log/presentation/widgets/flight_window_warning_banner_test.dart test/features/dive_log/presentation/pages/`
Expected: PASS. Known trap: dive edit page tests now construct a widget watching `tripFlightWindowProvider`; with `tripId == null` the provider is never touched, so existing tests should pass unchanged — if one seeds a trip id, override the family for that id with `(ref) async => null`.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "Warn in dive editor when a dive ends past the flight window deadline"
```

---

### Task 11: Full verification pass

**Files:** none new.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: no files changed (everything formatted per-task). If files change, commit them.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — full output, no piping. Infos are fatal in CI; fix every one.

- [ ] **Step 3: Regenerate l10n and check for drift**

Run: `flutter gen-l10n && git status --porcelain`
Expected: no dirty files (generated localizations already committed per task).

- [ ] **Step 4: Run the full test suite**

Run: `flutter test` (background it; expect several minutes)
Expected: PASS. Known pre-existing flaky tests (backup suite, media upload drain, recovery-code yoyo) may fail unrelated to this work — re-run an isolated failure once before investigating; do not chase failures that reproduce on `main`.

- [ ] **Step 5: Final commit if anything moved**

```bash
git add -A
git commit -m "Format and test fixes for flight window feature"  # only if needed
```

---

## Notes for the implementer

- **Pre-existing frame discrepancy (do NOT fix here):** `noFlyStatusProvider` and `gauge_strip.dart` compare wall-clock-as-UTC dive times against `DateTime.now().toUtc()` (true instant). Off-UTC devices get a skewed no-fly countdown. This feature deliberately uses `NoFlyService.wallClockNowUtc()` for its own math; the existing provider is left untouched. Flag it to the user as a candidate follow-up issue.
- **Dashboard reach:** `activeTripFlightWindowProvider` keys `tripForDateProvider` with local-midnight `today`, whose containment check uses the trips table's local-frame `start_date`/`end_date` — consistent with how `findTripForDate` is already consumed elsewhere.
- **Schema ladder:** if `origin/main` advances past v137 before Task 1 lands, renumber (see Global Constraints). The beforeOpen backstop makes the migration safe for DBs stranded at any intermediate version either way.
