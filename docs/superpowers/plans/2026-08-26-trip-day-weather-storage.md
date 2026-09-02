# Stored Trip Day Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fetch weather for a trip day at most once, store it as synced trip data, and read it from the database on every later view instead of re-hitting Open-Meteo.

**Architecture:** A new synced table `trip_day_weather` holds one row per (trip, date), written by a backfill pass that runs when the trip story is viewed and reads by a Riverpod provider subscribed to the table's change tick. The day header stops fetching entirely and becomes a pure widget that renders whatever weather it is handed, with dive-logged weather still taking precedence over a fetched summary.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod 3, Equatable, Open-Meteo archive API via the existing `WeatherService`.

**Spec:** `docs/superpowers/specs/2026-08-26-trip-day-weather-storage-design.md`

## Global Constraints

- **Worktree:** all work happens in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather` on branch `worktree-trip-day-weather`. The Bash working directory does NOT reliably persist across turns: put `cd <worktree> &&` in the same compound command as the work and echo `pwd`, or use absolute paths. A relative-path write from the wrong cwd silently edits the main checkout.
- **Schema version is 171.** Renumbered from 168: that number was already claimed and pushed by PR #1237 (issue #638), but the claim was local and unpushed when this branch picked its number, so an open-PR scan could not see it. 165-170 are claimed by #1290, #1300, #1276, #1237, the gear-twin branch, and #1322. Re-verify with BOTH scans (open-PR diffs AND every worktree's working-tree scalar) immediately before pushing, not just when picking the number. Do NOT raise `minimumCompatibleSchemaVersion` (stays 160): a new table is additive.
- **No em-dashes** (`—`, U+2014) in any output: code, comments, docs, commit messages. En-dashes and " - " as prose punctuation are equally forbidden. A hyphen inside a compound word or CLI flag is fine.
- **No emojis** in code, comments, or documentation.
- **Timestamps are epoch MILLISECONDS** in these tables (`DateTime.millisecondsSinceEpoch`), matching `ItineraryDayRepository`. The `// Unix timestamp` comment on `trip_itinerary_days.date` is misleading; the repository writes milliseconds.
- **Immutability:** never mutate objects or lists. All domain entities get `copyWith`.
- **TDD:** write the failing test first, watch it fail, then implement.
- **Formatting:** run `dart format .` before every commit.
- **Commit messages:** no `Co-Authored-By` trailer, no Claude Code attribution line, no session URL.
- **Units:** anything displaying units must respect the active diver's unit settings. Weather is stored in metric (celsius, m/s, bar) and converted at display time by `UnitFormatter`.

---

### Task 1: Schema, entity, and the v171 migration

**Files:**
- Create: `lib/features/trips/domain/entities/trip_day_weather.dart`
- Modify: `lib/core/database/database.dart` (table class near `TripItineraryDays` at line 117; `@DriftDatabase(tables: [...])` list; `currentSchemaVersion` at line 3183; `migrationVersions` list; a new `_assertTripDayWeatherSchema()` helper next to `_assertQualityFindingsSchema()` at line 3932; the `onUpgrade` ladder tail at line 8614; the `beforeOpen` backstop block around line 8823)
- Test: `test/core/database/migration_v171_trip_day_weather_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - Drift table `TripDayWeather` -> generated row class `TripDayWeatherData`, accessor `_db.tripDayWeather`, companion `TripDayWeatherCompanion`.
  - Domain entity `TripDayWeather` (in the `features/trips` namespace; import it `as domain` wherever the Drift row class is also in scope, per the project's import-alias convention) with fields `id`, `tripId`, `date`, `latitude`, `longitude`, `airTemp`, `cloudCover`, `precipitation`, `windSpeed`, `windDirection`, `humidity`, `surfacePressure`, `weatherCode`, `weatherSource`, `fetchedAt`, `createdAt`, `updatedAt`; `copyWith`; and `TripStoryDayWeather toStoryWeather()`.
  - `AppDatabase.currentSchemaVersion == 171`.

- [ ] **Step 1: Re-verify the schema version claim**

Run from the worktree:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion && \
  for n in $(gh pr list --state open --json number --jq '.[].number'); do \
    v=$(gh pr diff $n 2>/dev/null | grep -E '^\+\s*static const int currentSchemaVersion' | head -1); \
    [ -n "$v" ] && echo "PR $n: $v"; \
  done
```

Expected: claims at 165 (#1290), 166 (#1300), 167 (#1276), 168 (#1237), 169 (the dive-computer gear-twin branch, local only), 170 (#1322), plus a stale claim from #603 that is far below main and does not count. NOTE: the #1237 claim read as stale v161 when this plan was written and was in fact a live v168, because its renumber was resolved locally and not yet pushed. An open-PR scan cannot see an unpushed claim; also scan every worktree's working-tree scalar. The next free rung is **171**.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v171_trip_day_weather_test.dart`. Model it on the other `migration_v*_test.dart` files in that directory: read one first to copy the exact in-memory database setup helper they use.

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v171 trip_day_weather', () {
    test('the ladder claims 171', () {
      expect(
        AppDatabase.currentSchemaVersion,
        greaterThanOrEqualTo(171),
      );
      expect(AppDatabase.migrationVersions, contains(171));
    });

    test('a new database has the trip_day_weather table with every column', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db
          .customSelect('PRAGMA table_info(trip_day_weather)')
          .get();
      final names = rows.map((r) => r.data['name'] as String).toSet();

      expect(names, containsAll(<String>{
        'id',
        'trip_id',
        'date',
        'latitude',
        'longitude',
        'air_temp',
        'cloud_cover',
        'precipitation',
        'wind_speed',
        'wind_direction',
        'humidity',
        'surface_pressure',
        'weather_code',
        'weather_source',
        'fetched_at',
        'created_at',
        'updated_at',
        'hlc',
      }));
    });

    test('one row per trip and date', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement('PRAGMA foreign_keys = OFF');

      Future<void> insert(String id) => db.customStatement(
        'INSERT INTO trip_day_weather '
        '(id, trip_id, date, latitude, longitude, weather_source, '
        'fetched_at, created_at, updated_at) '
        "VALUES ('$id', 'trip-1', 1000, 1.0, 2.0, 'openMeteo', 1, 1, 1)",
      );

      await insert('a');
      await expectLater(insert('b'), throwsA(isA<SqliteException>()));
    });

    test('the migration adds the table to a stranded v164 database', () async {
      // A database stamped at the previous rung must gain the table on open.
      final executor = NativeDatabase.memory();
      final raw = AppDatabase(executor);
      await raw.customStatement('PRAGMA user_version = 164');
      await raw.customStatement('DROP TABLE IF EXISTS trip_day_weather');
      await raw.close();

      final db = AppDatabase(executor);
      addTearDown(db.close);
      final rows = await db
          .customSelect('PRAGMA table_info(trip_day_weather)')
          .get();

      expect(rows, isNotEmpty);
    });
  });
}
```

Note on the last test: check how the sibling `migration_v*_test.dart` files build a stranded database. If they use a shared helper (a temp file database re-opened at a pinned `user_version`), use that helper verbatim instead of the sketch above, because an in-memory executor cannot always be reopened.

- [ ] **Step 3: Run the test and watch it fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/core/database/migration_v171_trip_day_weather_test.dart
```

Expected: FAIL. `migrationVersions` does not contain 171, and `PRAGMA table_info(trip_day_weather)` returns no rows.

- [ ] **Step 4: Add the Drift table**

In `lib/core/database/database.dart`, directly after the `TripItineraryDays` class (which ends at line 136), add:

```dart
/// Fetched historical weather for one trip day, for days whose dives supply
/// no weather of their own (surface days and dive-free itinerary days).
///
/// A separate table rather than columns on `trips` or `trip_itinerary_days`
/// on purpose: HLC conflicts resolve per row, so parking an automatic,
/// derived write on a row the diver also edits by hand lets a weather write
/// race a rename or a note edit and lose it. Weather owns its own row and its
/// own clock.
///
/// Metric storage throughout (celsius, m/s, bar); conversion to the diver's
/// units happens at display time.
class TripDayWeather extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();

  /// Local midnight for the day, as epoch milliseconds (the same convention
  /// TripItineraryDays.date is written with).
  IntColumn get date => integer()();

  /// The coordinates the lookup actually used, so a row records what it was
  /// fetched for even if the trip's sites later move.
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  RealColumn get airTemp => real().nullable()(); // celsius
  TextColumn get cloudCover => text().nullable()(); // enum: CloudCover.name
  TextColumn get precipitation =>
      text().nullable()(); // enum: Precipitation.name
  RealColumn get windSpeed => real().nullable()(); // m/s
  TextColumn get windDirection =>
      text().nullable()(); // enum: CurrentDirection.name
  RealColumn get humidity => real().nullable()(); // 0-100
  RealColumn get surfacePressure => real().nullable()(); // bar

  /// Raw WMO weather code, kept so prose renders in the diver's locale at
  /// display time rather than being frozen as English at fetch time.
  IntColumn get weatherCode => integer().nullable()();

  TextColumn get weatherSource =>
      text().withDefault(const Constant('openMeteo'))();
  IntColumn get fetchedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Then add `TripDayWeather,` to the `tables: [...]` list in the `@DriftDatabase` annotation, next to `TripItineraryDays`.

- [ ] **Step 5: Add the schema-assert helper**

Next to `_assertQualityFindingsSchema()` (line 3932), which is the pattern to copy, add:

```dart
  /// v171: fetched per-day trip weather. Idempotent, so it doubles as the
  /// beforeOpen backstop for a database that took the rung before the unique
  /// index existed.
  Future<void> _assertTripDayWeatherSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS trip_day_weather (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips (id),
        date INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        air_temp REAL,
        cloud_cover TEXT,
        precipitation TEXT,
        wind_speed REAL,
        wind_direction TEXT,
        humidity REAL,
        surface_pressure REAL,
        weather_code INTEGER,
        weather_source TEXT NOT NULL DEFAULT 'openMeteo',
        fetched_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_day_weather_trip_date '
      'ON trip_day_weather (trip_id, date)',
    );
  }
```

- [ ] **Step 6: Claim the rung in all six places**

1. `static const int currentSchemaVersion = 171;` (was 164, line 3183).
2. Append `171,` to the end of the `migrationVersions` list. The ladder is non-contiguous by design (162 is permanently skipped and reserved rungs may be missing); do not "fix" the gaps.
3. The helper docstring above already names v171.
4. In `onUpgrade`, after the `if (from < 164) await reportProgress();` pair at line 8617, add both halves:

```dart
        // v171: trip_day_weather, fetched per-day weather for trip days whose
        // dives supply none.
        if (from < 171) {
          await _assertTripDayWeatherSchema();
        }
        if (from < 171) await reportProgress();
```

5. In `beforeOpen`, alongside the other backstops (around line 8823), add:

```dart
        // v171 backstop: re-assert the trip day weather table (the helper is
        // CREATE TABLE IF NOT EXISTS, so it is safe on every open).
        await _assertTripDayWeatherSchema();
```

6. The test file created in Step 2 already carries the version in its filename and assertions.

Leave `minimumCompatibleSchemaVersion` at 160.

- [ ] **Step 7: Run codegen**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  dart run build_runner build --delete-conflicting-outputs
```

Expected: succeeds, and `lib/core/database/database.g.dart` now defines `TripDayWeatherData` and `$TripDayWeatherTable`.

- [ ] **Step 8: Write the domain entity**

Create `lib/features/trips/domain/entities/trip_day_weather.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Stored historical weather for one trip day.
///
/// Written only for days whose dives supply no weather of their own; a day
/// with dive-logged weather always renders that instead.
class TripDayWeather extends Equatable {
  final String id;
  final String tripId;

  /// Local midnight for the day this describes.
  final DateTime date;

  /// The coordinates the lookup used.
  final double latitude;
  final double longitude;

  final double? airTemp; // celsius
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? windSpeed; // m/s
  final CurrentDirection? windDirection;
  final double? humidity; // 0-100
  final double? surfacePressure; // bar
  final int? weatherCode;
  final WeatherSource weatherSource;
  final DateTime fetchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripDayWeather({
    required this.id,
    required this.tripId,
    required this.date,
    required this.latitude,
    required this.longitude,
    this.airTemp,
    this.cloudCover,
    this.precipitation,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.surfacePressure,
    this.weatherCode,
    this.weatherSource = WeatherSource.openMeteo,
    required this.fetchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when at least one field the day header can render is present.
  /// A result with nothing renderable is not worth a row.
  bool get hasRenderableWeather =>
      airTemp != null || cloudCover != null || precipitation != null;

  /// The compact view model the day header consumes.
  TripStoryDayWeather toStoryWeather() => TripStoryDayWeather(
    airTemp: airTemp,
    cloudCover: cloudCover,
    precipitation: precipitation,
  );

  TripDayWeather copyWith({
    String? id,
    String? tripId,
    DateTime? date,
    double? latitude,
    double? longitude,
    Object? airTemp = _undefined,
    Object? cloudCover = _undefined,
    Object? precipitation = _undefined,
    Object? windSpeed = _undefined,
    Object? windDirection = _undefined,
    Object? humidity = _undefined,
    Object? surfacePressure = _undefined,
    Object? weatherCode = _undefined,
    WeatherSource? weatherSource,
    DateTime? fetchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripDayWeather(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      airTemp: airTemp == _undefined ? this.airTemp : airTemp as double?,
      cloudCover: cloudCover == _undefined
          ? this.cloudCover
          : cloudCover as CloudCover?,
      precipitation: precipitation == _undefined
          ? this.precipitation
          : precipitation as Precipitation?,
      windSpeed: windSpeed == _undefined
          ? this.windSpeed
          : windSpeed as double?,
      windDirection: windDirection == _undefined
          ? this.windDirection
          : windDirection as CurrentDirection?,
      humidity: humidity == _undefined ? this.humidity : humidity as double?,
      surfacePressure: surfacePressure == _undefined
          ? this.surfacePressure
          : surfacePressure as double?,
      weatherCode: weatherCode == _undefined
          ? this.weatherCode
          : weatherCode as int?,
      weatherSource: weatherSource ?? this.weatherSource,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    date,
    latitude,
    longitude,
    airTemp,
    cloudCover,
    precipitation,
    windSpeed,
    windDirection,
    humidity,
    surfacePressure,
    weatherCode,
    weatherSource,
    fetchedAt,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

Before writing this, confirm `CurrentDirection` and `WeatherSource` exist in `lib/core/constants/enums.dart` (they do: `WeatherSource` is at line 567, and `windDirection` on the dives table is documented as `CurrentDirection.name` at line 733).

- [ ] **Step 9: Run the migration test and the database suite**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/core/database/
```

Expected: PASS, including the pre-existing ladder audit tests. Roughly 465 tests, about 15 seconds. If a ladder audit fails, re-read the six places above; a missing `migrationVersions` entry or a missing `reportProgress()` twin is the usual cause.

- [ ] **Step 10: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(db): add trip_day_weather table at schema v171

One row per trip day, holding fetched historical weather for days whose
dives supply none. A separate table rather than columns on an existing
row so an automatic derived write never conflicts with hand-entered data
under row-level HLC resolution."
```

---

### Task 2: Repository

**Files:**
- Create: `lib/features/trips/data/repositories/trip_day_weather_repository.dart`
- Modify: `lib/features/trips/data/repositories/trip_repository.dart:263-267` (the `deleteTrip` transaction)
- Test: `test/features/trips/data/repositories/trip_day_weather_repository_test.dart`

**Interfaces:**
- Consumes: `TripDayWeather` domain entity and the `_db.tripDayWeather` Drift table from Task 1.
- Produces: `TripDayWeatherRepository` with
  - `Stream<void> watchWeatherChanges()`
  - `Future<Map<int, TripDayWeather>> getForTrip(String tripId)` keyed by `date.millisecondsSinceEpoch`
  - `Future<void> upsert(TripDayWeather weather)`
  - `Future<void> deleteByTripId(String tripId)`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/trips/data/repositories/trip_day_weather_repository_test.dart`. Read `test/features/trips/data/repositories/itinerary_day_repository_test.dart` first (if it exists) or another repository test in `test/features/trips/data/repositories/` to copy the exact `DatabaseService` test harness those tests use, since these repositories reach `DatabaseService.instance.database` rather than taking a database argument.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TripDayWeatherRepository repository;

  // Use the same in-memory DatabaseService setup the sibling trip repository
  // tests use, and insert a parent trip row named 'trip-1' before each test
  // (trip_id is a non-nullable FK and beforeOpen enables foreign keys).

  TripDayWeather sample({
    String id = 'w1',
    String tripId = 'trip-1',
    DateTime? date,
    double? airTemp = 21.5,
  }) {
    final day = date ?? DateTime(2026, 3, 8);
    return TripDayWeather(
      id: id,
      tripId: tripId,
      date: day,
      latitude: 12.16,
      longitude: -68.28,
      airTemp: airTemp,
      cloudCover: CloudCover.clear,
      fetchedAt: DateTime(2026, 3, 9),
      createdAt: DateTime(2026, 3, 9),
      updatedAt: DateTime(2026, 3, 9),
    );
  }

  test('upsert then read back, keyed by date millis', () async {
    await repository.upsert(sample());

    final stored = await repository.getForTrip('trip-1');

    expect(stored, hasLength(1));
    final row = stored[DateTime(2026, 3, 8).millisecondsSinceEpoch]!;
    expect(row.airTemp, 21.5);
    expect(row.cloudCover, CloudCover.clear);
    expect(row.weatherSource, WeatherSource.openMeteo);
  });

  test('upserting the same day twice keeps one row', () async {
    await repository.upsert(sample());
    await repository.upsert(sample(id: 'w2', airTemp: 25));

    final stored = await repository.getForTrip('trip-1');

    expect(stored, hasLength(1));
    expect(
      stored[DateTime(2026, 3, 8).millisecondsSinceEpoch]!.airTemp,
      25,
    );
  });

  test('getForTrip is scoped to one trip', () async {
    await repository.upsert(sample());
    await repository.upsert(sample(id: 'w2', tripId: 'trip-2'));

    expect(await repository.getForTrip('trip-1'), hasLength(1));
  });

  test('deleteByTripId removes only that trip rows', () async {
    await repository.upsert(sample());
    await repository.upsert(sample(id: 'w2', tripId: 'trip-2'));

    await repository.deleteByTripId('trip-1');

    expect(await repository.getForTrip('trip-1'), isEmpty);
    expect(await repository.getForTrip('trip-2'), hasLength(1));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/data/repositories/trip_day_weather_repository_test.dart
```

Expected: FAIL with an unresolved import of `trip_day_weather_repository.dart`.

- [ ] **Step 3: Write the repository**

Create `lib/features/trips/data/repositories/trip_day_weather_repository.dart`. `ItineraryDayRepository` is the shape to copy exactly: the `DatabaseService.instance.database` getter, the `SyncRepository()` field, the logger, `markRecordPending` after every write, `logDeletion` for every delete, and `SyncEventBus.notifyLocalChange()` at the end of each mutating method.

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart'
    as domain;

/// Reads and writes stored per-day trip weather.
///
/// The unique index on (trip_id, date) is what makes an upsert idempotent:
/// two devices that both fetch the same day converge on one row rather than
/// accumulating duplicates.
class TripDayWeatherRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(TripDayWeatherRepository);

  /// Emits whenever `trip_day_weather` changes, so the display provider
  /// refreshes after a backfill write or a sync import.
  Stream<void> watchWeatherChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripDayWeather));

  /// Stored weather for a trip, keyed by `date.millisecondsSinceEpoch`.
  Future<Map<int, domain.TripDayWeather>> getForTrip(String tripId) async {
    final rows = await (_db.select(
      _db.tripDayWeather,
    )..where((t) => t.tripId.equals(tripId))).get();
    return {for (final row in rows) row.date: _mapRow(row)};
  }

  /// Insert or replace one day's weather.
  Future<void> upsert(domain.TripDayWeather weather) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Replace any existing row for this day rather than relying on the id:
      // the day is the identity, and a peer may have written its own id for
      // the same day.
      final existing =
          await (_db.select(_db.tripDayWeather)..where(
                (t) =>
                    t.tripId.equals(weather.tripId) &
                    t.date.equals(weather.date.millisecondsSinceEpoch),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? weather.id;

      await _db
          .into(_db.tripDayWeather)
          .insertOnConflictUpdate(
            TripDayWeatherCompanion(
              id: Value(id),
              tripId: Value(weather.tripId),
              date: Value(weather.date.millisecondsSinceEpoch),
              latitude: Value(weather.latitude),
              longitude: Value(weather.longitude),
              airTemp: Value(weather.airTemp),
              cloudCover: Value(weather.cloudCover?.name),
              precipitation: Value(weather.precipitation?.name),
              windSpeed: Value(weather.windSpeed),
              windDirection: Value(weather.windDirection?.name),
              humidity: Value(weather.humidity),
              surfacePressure: Value(weather.surfacePressure),
              weatherCode: Value(weather.weatherCode),
              weatherSource: Value(weather.weatherSource.name),
              fetchedAt: Value(weather.fetchedAt.millisecondsSinceEpoch),
              createdAt: Value(
                existing?.createdAt ?? weather.createdAt.millisecondsSinceEpoch,
              ),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'tripDayWeather',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to store weather for trip ${weather.tripId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete every stored day for a trip, logging each id for sync.
  Future<void> deleteByTripId(String tripId) async {
    try {
      final existing = await (_db.select(
        _db.tripDayWeather,
      )..where((t) => t.tripId.equals(tripId))).get();
      if (existing.isEmpty) return;

      await (_db.delete(
        _db.tripDayWeather,
      )..where((t) => t.tripId.equals(tripId))).go();

      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripDayWeather',
          recordId: row.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete weather for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  domain.TripDayWeather _mapRow(TripDayWeatherData row) {
    return domain.TripDayWeather(
      id: row.id,
      tripId: row.tripId,
      date: DateTime.fromMillisecondsSinceEpoch(row.date),
      latitude: row.latitude,
      longitude: row.longitude,
      airTemp: row.airTemp,
      cloudCover: row.cloudCover == null
          ? null
          : CloudCover.values.byName(row.cloudCover!),
      precipitation: row.precipitation == null
          ? null
          : Precipitation.values.byName(row.precipitation!),
      windSpeed: row.windSpeed,
      windDirection: row.windDirection == null
          ? null
          : CurrentDirection.values.byName(row.windDirection!),
      humidity: row.humidity,
      surfacePressure: row.surfacePressure,
      weatherCode: row.weatherCode,
      weatherSource: WeatherSource.values.byName(row.weatherSource),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row.fetchedAt),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
```

If the generated row class is not named `TripDayWeatherData`, check `database.g.dart` for the actual name and use it.

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/data/repositories/trip_day_weather_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Wire the trip-delete cascade**

In `lib/features/trips/data/repositories/trip_repository.dart`, inside the `deleteTrip` transaction (line 263), add the new repository next to the others:

```dart
        await LiveaboardDetailsRepository().deleteByTripId(id);
        await ItineraryDayRepository().deleteByTripId(id);
        await TripChecklistRepository().deleteByTripId(id);
        await TripDayWeatherRepository().deleteByTripId(id);
```

Add the import for `trip_day_weather_repository.dart` in the same file's local import group.

- [ ] **Step 6: Add a deletion test and run the trip repository suite**

Append to the repository test file:

```dart
  test('deleting a trip takes its weather rows with it', () async {
    await repository.upsert(sample());

    await TripRepository().deleteTrip('trip-1');

    expect(await repository.getForTrip('trip-1'), isEmpty);
  });
```

Import `TripRepository` at the top of the test file. Then:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/
```

Expected: PASS, with no regressions in the existing trip tests.

- [ ] **Step 7: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(trips): add TripDayWeatherRepository

Upsert is keyed by (trip, date) rather than by id so two devices that
both fetch the same day converge on one row. Deleting a trip takes its
weather rows with it, logged for sync like every other child record."
```

---

### Task 3: Sync registration

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:49` (the `hlcTargets` map)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (13 sites, listed below)
- Modify: `lib/core/services/sync/sync_service.dart:1209`, `:1959`, `:2120`
- Test: `test/core/services/sync/trip_day_weather_sync_test.dart`

**Interfaces:**
- Consumes: the `trip_day_weather` table from Task 1.
- Produces: entity type key `'tripDayWeather'` registered end to end, and `SyncData.tripDayWeather` as a `List<Map<String, dynamic>>` field.

Every site below is a copy of what `'itineraryDays'` does. Three structural tests already in the suite will fail if any site is missed: `sync_hlc_target_registration_test` (asserts every table with an `hlc` column is in `hlcTargets`), the `entityHasUpdatedAt covers exactly the SyncData entities` test, and the merge-order parity test.

- [ ] **Step 1: Write the failing round-trip test**

Create `test/core/services/sync/trip_day_weather_sync_test.dart`, modeled directly on `test/core/services/sync/site_features_sync_test.dart` (the closest analogue: a synced child record with a non-nullable FK to its parent).

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-1',
            name: 'Bonaire',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripDayWeather)
        .insert(
          TripDayWeatherCompanion.insert(
            id: 'w-1',
            tripId: 'trip-1',
            date: DateTime(2026, 3, 8).millisecondsSinceEpoch,
            latitude: 12.16,
            longitude: -68.28,
            airTemp: const Value(24.0),
            cloudCover: const Value('clear'),
            fetchedAt: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('tripDayWeather export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('tripDayWeather', 'w-1');
    expect(record, isNotNull);
    expect(record!['airTemp'], 24.0);
    expect(record['cloudCover'], 'clear');

    // A remote edit merges over the local row (LWW payload apply).
    await serializer.upsertRecord('tripDayWeather', {
      ...record,
      'airTemp': 26.0,
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('tripDayWeather', 'w-1');
    expect(merged!['airTemp'], 26.0);

    expect(await serializer.recordIdsFor('tripDayWeather'), contains('w-1'));

    await serializer.deleteRecord('tripDayWeather', 'w-1');
    expect(await serializer.fetchRecord('tripDayWeather', 'w-1'), isNull);
  });

  test('the delta export filters on the row own hlc', () async {
    await (db.update(db.tripDayWeather)..where((t) => t.id.equals('w-1')))
        .write(
          const TripDayWeatherCompanion(
            hlc: Value('2026-08-16T00:00:00.000-0000'),
          ),
        );

    Future<int> changesetCount(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return payload.data.tripDayWeather.length;
    }

    // A base carries the row; a watermark newer than it excludes it; an
    // older watermark includes it.
    expect(await changesetCount(null), 1);
    expect(await changesetCount('2026-08-17T00:00:00.000-0000'), 0);
    expect(await changesetCount('2026-08-15T00:00:00.000-0000'), 1);
  });

  test('tripDayWeather is registered as an hlc target', () {
    expect(SyncRepository.hlcTargets.containsKey('tripDayWeather'), isTrue);
    expect(
      SyncRepository.hlcTargets['tripDayWeather']!.table,
      'trip_day_weather',
    );
  });

  test('tripDayWeather carries an updatedAt flag', () {
    expect(SyncService.entityHasUpdatedAt['tripDayWeather'], isTrue);
  });
}
```

Two things to check against generated code rather than assume. First, the keys in the `fetchRecord` map come from Drift's generated `toJson()`, which uses Dart field names (`airTemp`, `cloudCover`), not SQL column names; if an assertion fails on a key, confirm the real name in `database.g.dart`. Second, `TripsCompanion.insert` may require more than `id`/`name`/`createdAt`/`updatedAt`; read the `Trips` table definition and supply whatever else is non-nullable and undefaulted.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/core/services/sync/trip_day_weather_sync_test.dart
```

Expected: FAIL, because `hlcTargets` has no `tripDayWeather` key and `SyncData` has no such field.

- [ ] **Step 3: Register the HLC target**

In `lib/core/data/repositories/sync_repository.dart`, after the `'itineraryDays'` entry (line 49):

```dart
    'tripDayWeather': (table: 'trip_day_weather', pk: 'id'),
```

- [ ] **Step 4: Add all 13 serializer sites**

In `lib/core/services/sync/sync_data_serializer.dart`, add a `tripDayWeather` line immediately after each `itineraryDays` line at these locations:

1. Line 249, the `SyncData` field list: `final List<Map<String, dynamic>> tripDayWeather;`
2. Line 324, the constructor: `this.tripDayWeather = const [],`
3. Line 400, `toJson`: `'tripDayWeather': tripDayWeather,`
4. Line 477, `fromJson`: `tripDayWeather: _parseList(json['tripDayWeather']),`
5. Line 762, the table tuple list:

```dart
    (
      key: 'tripDayWeather',
      table: _db.tripDayWeather,
      blob: false,
      full: null,
    ),
```

6. Line 1268, the export block:

```dart
      tripDayWeather: await _safeExport(
        'tripDayWeather',
        () => _exportTripDayWeather(hlcSince),
      ),
```

7. Line 1707, single-record fetch:

```dart
      case 'tripDayWeather':
        final row = await (_db.select(
          _db.tripDayWeather,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

8. Line 2032, batch fetch:

```dart
      case 'tripDayWeather':
        final rows = await (_db.select(
          _db.tripDayWeather,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

9. Line 2592, single upsert:

```dart
      case 'tripDayWeather':
        await _db
            .into(_db.tripDayWeather)
            .insertOnConflictUpdate(
              TripDayWeatherData.fromJson(data).toCompanion(false),
            );
        return;
```

10. Line 3196, batch upsert:

```dart
      case 'tripDayWeather':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tripDayWeather,
            records
                .map((r) => TripDayWeatherData.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```

11. Line 3681, the plain id projection: `case 'tripDayWeather': return plain(_db.tripDayWeather, _db.tripDayWeather.id);`
12. Line 3914, table lookup: `case 'tripDayWeather': return _db.tripDayWeather;`
13. Line 4222, delete by id:

```dart
      case 'tripDayWeather':
        await (_db.delete(
          _db.tripDayWeather,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

Then add the export helper next to `_exportItineraryDays` (line 4892), copying its body exactly:

```dart
  Future<List<Map<String, dynamic>>> _exportTripDayWeather(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tripDayWeather);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

Read `_exportItineraryDays` in full before copying: if it does anything else (such as a diver scope filter), mirror that too.

Use the generated row class name from `database.g.dart` in sites 9 and 10; the plan assumes `TripDayWeatherData`.

- [ ] **Step 5: Add the three sync_service sites**

In `lib/core/services/sync/sync_service.dart`:

1. After the `itineraryDays` merge-order record at line 1209:

```dart
          (
            type: 'tripDayWeather',
            records: data.tripDayWeather,
            hasUpdatedAt: true,
          ),
```

2. In `entityHasUpdatedAt` after line 1959: `'tripDayWeather': true,`
3. In the FK parent map after line 2120:

```dart
    'tripDayWeather': [(field: 'tripId', parent: 'trips', nullable: false)],
```

- [ ] **Step 6: Run the sync suite**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/core/services/sync/
```

Expected: PASS, including the new round-trip test and the three structural tests. A failure naming an entity coverage mismatch means one of the 17 sites is missing.

- [ ] **Step 7: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(sync): replicate trip day weather

Registers tripDayWeather end to end: hlc target, serializer payload and
switch arms, merge order, updatedAt flag, and the trips FK parent so a
changeset never imports weather ahead of its trip."
```

---

### Task 4: Backfill rules (pure domain logic)

**Files:**
- Create: `lib/features/trips/domain/services/trip_day_weather_backfill.dart`
- Test: `test/features/trips/domain/services/trip_day_weather_backfill_test.dart`

**Interfaces:**
- Consumes: `TripStory`, `TripStoryDay`, `TripStoryMapGeometry` (all in `features/trips/domain/entities/`), and the `Map<int, TripDayWeather>` shape `TripDayWeatherRepository.getForTrip` returns.
- Produces:

```dart
class TripDayWeatherTarget extends Equatable {
  final DateTime date;      // local midnight
  final double latitude;
  final double longitude;
  DateTime get localNoon;   // date at 12:00, the sample hour to request
}

class TripDayWeatherBackfill {
  static List<TripDayWeatherTarget> targetsFor({
    required TripStory story,
    required Map<int, TripDayWeather> stored,
  });
}
```

This task is pure: no database, no network, no Riverpod. That is the point. All four skip rules are testable as a plain function.

- [ ] **Step 1: Write the failing test**

Create `test/features/trips/domain/services/trip_day_weather_backfill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_day_weather_backfill.dart';

void main() {
  // Build the smallest story that exercises one rule at a time. Copy the
  // Trip/Dive fixture helpers from
  // test/features/trips/domain/entities/trip_story_day_test.dart rather than
  // hand-rolling new ones.

  Trip trip() => Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: DateTime(2026, 3, 8),
    endDate: DateTime(2026, 3, 14),
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  TripStory storyWith(
    List<TripStoryDay> days, {
    List<TripStoryMapPoint> points = const [],
  }) {
    return TripStory(
      trip: trip(),
      days: days,
      checklist: const TripStoryChecklistSummary(done: 0, total: 0),
      mapGeometry: TripStoryMapGeometry(points: points),
    );
  }

  Dive diveWith({double? airTemp}) =>
      Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), airTemp: airTemp);

  TripStoryDay day({
    required int index,
    TripStoryDayKind kind = TripStoryDayKind.past,
    List<Dive> dives = const [],
  }) {
    return TripStoryDay(
      date: DateTime(2026, 3, 8 + index),
      dayNumber: index + 1,
      kind: kind,
      dives: dives,
    );
  }

  TripStoryMapPoint pointFor(int dayIndex) => TripStoryMapPoint(
    latitude: 12.16,
    longitude: -68.28,
    dayIndex: dayIndex,
    label: 'Site',
  );

  test('a past day with no dives and a nearby point is a target', () {
    final story = storyWith([day(index: 0)], points: [pointFor(0)]);

    final targets = TripDayWeatherBackfill.targetsFor(
      story: story,
      stored: const {},
    );

    expect(targets, hasLength(1));
    expect(targets.single.date, DateTime(2026, 3, 8));
    expect(targets.single.latitude, 12.16);
    expect(targets.single.localNoon, DateTime(2026, 3, 8, 12));
  });

  test('a day whose dives carry weather is skipped', () {
    // Build a dive with airTemp set so TripStoryDay.weather is non-null.
    final story = storyWith(
      [day(index: 0, dives: [diveWith(airTemp: 26)])],
      points: [pointFor(0)],
    );

    expect(
      TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
      isEmpty,
    );
  });

  test('a future day is skipped', () {
    final story = storyWith(
      [day(index: 0, kind: TripStoryDayKind.future)],
      points: [pointFor(0)],
    );

    expect(
      TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
      isEmpty,
    );
  });

  test('a day with a stored row is skipped', () {
    final story = storyWith([day(index: 0)], points: [pointFor(0)]);
    final stored = {
      DateTime(2026, 3, 8).millisecondsSinceEpoch: TripDayWeather(
        id: 'w1',
        tripId: 'trip-1',
        date: DateTime(2026, 3, 8),
        latitude: 12.16,
        longitude: -68.28,
        airTemp: 21,
        fetchedAt: DateTime(2026, 3, 9),
        createdAt: DateTime(2026, 3, 9),
        updatedAt: DateTime(2026, 3, 9),
      ),
    };

    expect(
      TripDayWeatherBackfill.targetsFor(story: story, stored: stored),
      isEmpty,
    );
  });

  test('a day with no map point anywhere in the story is skipped', () {
    final story = storyWith([day(index: 0)]);

    expect(
      TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
      isEmpty,
    );
  });

  test('a day borrows the nearest day point when it has none of its own', () {
    // nearestPointForDay already walks outward, so day 1 with a point only on
    // day 0 is still a target, at day 0 coordinates.
    final story = storyWith(
      [day(index: 0, dives: [diveWith(airTemp: 26)]), day(index: 1)],
      points: [pointFor(0)],
    );

    final targets = TripDayWeatherBackfill.targetsFor(
      story: story,
      stored: const {},
    );

    expect(targets, hasLength(1));
    expect(targets.single.date, DateTime(2026, 3, 9));
    expect(targets.single.latitude, 12.16);
  });
}
```

Add the imports these fixtures need: `Trip` from `features/trips/domain/entities/trip.dart` and `Dive` from `features/dive_log/domain/entities/dive.dart`. If `Trip`'s constructor has gained a required parameter, read the entity and supply it.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/domain/services/trip_day_weather_backfill_test.dart
```

Expected: FAIL with an unresolved import of `trip_day_weather_backfill.dart`.

- [ ] **Step 3: Write the service**

Create `lib/features/trips/domain/services/trip_day_weather_backfill.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// One day that needs a weather lookup, with the coordinates to look it up at.
class TripDayWeatherTarget extends Equatable {
  /// Local midnight for the day.
  final DateTime date;
  final double latitude;
  final double longitude;

  const TripDayWeatherTarget({
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  /// The hour to sample. Noon local reads as "the day's weather" far better
  /// than the API's default midnight boundary.
  DateTime get localNoon => DateTime(date.year, date.month, date.day, 12);

  @override
  List<Object?> get props => [date, latitude, longitude];
}

/// Decides which trip days need a weather lookup.
///
/// Pure by design: no database, no network. Every skip rule is a plain
/// condition over the built story and the rows already stored.
class TripDayWeatherBackfill {
  const TripDayWeatherBackfill._();

  static List<TripDayWeatherTarget> targetsFor({
    required TripStory story,
    required Map<int, TripDayWeather> stored,
  }) {
    final targets = <TripDayWeatherTarget>[];

    for (var index = 0; index < story.days.length; index++) {
      final day = story.days[index];

      // A dive that logged weather is the better source; never override it.
      if (day.weather != null) continue;

      // A historical archive has nothing for a day that has not happened.
      if (day.kind == TripStoryDayKind.future) continue;

      final date = DateTime(day.date.year, day.date.month, day.date.day);
      if (stored.containsKey(date.millisecondsSinceEpoch)) continue;

      // nearestPointForDay walks outward from the day, so a dive-free day
      // between two dived days borrows the closer one's coordinates.
      final point = story.mapGeometry.nearestPointForDay(index);
      if (point == null) continue;

      targets.add(
        TripDayWeatherTarget(
          date: date,
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      );
    }

    return targets;
  }
}
```

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/domain/services/trip_day_weather_backfill_test.dart
```

Expected: PASS, all six tests.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(trips): decide which trip days need a weather lookup

Pure rules over the built story and the rows already stored: dive-logged
weather wins, future days have no archive, stored days are done, and a
day with no mappable point anywhere in the trip has nowhere to ask."
```

---

### Task 5: Providers and the fetch loop

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_day_weather_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_day_weather_providers_test.dart`

**Interfaces:**
- Consumes: `TripDayWeatherRepository` (Task 2), `TripDayWeatherBackfill.targetsFor` (Task 4), the existing `weatherServiceProvider` from `lib/features/weather/presentation/providers/weather_providers.dart`, and `tripStoryProvider(tripId)` from `trip_story_providers.dart`.
- Produces:
  - `tripDayWeatherRepositoryProvider` -> `Provider<TripDayWeatherRepository>`
  - `tripDayWeatherProvider` -> `FutureProvider.family<Map<int, TripDayWeather>, String>` keyed by trip id, values keyed by `date.millisecondsSinceEpoch`
  - `tripDayWeatherBackfillProvider` -> `FutureProvider.family<void, String>` keyed by trip id

**Why the backfill provider does not watch the weather table:** the display provider subscribes to the table tick, but the backfill must not, or every row it writes would invalidate it and start another pass. It reads stored rows directly from the repository instead. Its only reactive dependency is the story itself, so adding dives to a trip re-evaluates what still needs fetching.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/trips/presentation/providers/trip_day_weather_providers_test.dart`. The existing `surface_day_weather_provider_test.dart` (deleted in Task 6) is where the `MockClient` weather-response fixture comes from; lift it rather than inventing one, because it encodes the exact Open-Meteo response shape `WeatherMapper` expects.

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// A full Open-Meteo hourly payload for one day. Copied from the deleted
/// surface_day_weather_provider_test.
http.Response weatherResponse({double noonTemp = 29.0, int cloud = 95}) =>
    http.Response(
      jsonEncode({
        'hourly': {
          'time': ['2026-03-08T09:00', '2026-03-08T12:00'],
          'temperature_2m': [24.0, noonTemp],
          'relative_humidity_2m': [80.0, 70.0],
          'precipitation': [0.0, 0.0],
          'cloud_cover': [10.0, cloud],
          'wind_speed_10m': [8.0, 12.0],
          'wind_direction_10m': [30.0, 45.0],
          'surface_pressure': [1012.0, 1011.0],
          'weathercode': [0, 0],
        },
      }),
      200,
    );

/// Records upserts instead of touching a database.
class FakeTripDayWeatherRepository implements TripDayWeatherRepository {
  FakeTripDayWeatherRepository({this.stored = const {}});

  final Map<int, TripDayWeather> stored;
  final List<TripDayWeather> upserts = [];

  @override
  Future<Map<int, TripDayWeather>> getForTrip(String tripId) async => stored;

  @override
  Future<void> upsert(TripDayWeather weather) async => upserts.add(weather);

  @override
  Future<void> deleteByTripId(String tripId) async {}

  @override
  Stream<void> watchWeatherChanges() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Two past days with no dives, and one map point on day 0 that day 1
  /// borrows through nearestPointForDay.
  TripStory twoDayStory() => TripStory(
    trip: Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 9),
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    ),
    days: [
      TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 1,
        kind: TripStoryDayKind.past,
      ),
      TripStoryDay(
        date: DateTime(2026, 3, 9),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
      ),
    ],
    checklist: const TripStoryChecklistSummary(done: 0, total: 0),
    mapGeometry: const TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.16,
          longitude: -68.28,
          dayIndex: 0,
          label: 'Site',
        ),
      ],
    ),
  );

  ProviderContainer containerWith({
    required http.Client client,
    required FakeTripDayWeatherRepository repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        weatherHttpClientProvider.overrideWithValue(client),
        tripDayWeatherRepositoryProvider.overrideWithValue(repository),
        tripStoryProvider('trip-1').overrideWith((ref) async => twoDayStory()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('fetches each target once and stores the result', () async {
    var calls = 0;
    final repository = FakeTripDayWeatherRepository();
    final container = containerWith(
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['timezone'], 'auto');
        return weatherResponse();
      }),
      repository: repository,
    );

    await container.read(tripDayWeatherBackfillProvider('trip-1').future);

    expect(calls, 2);
    expect(repository.upserts, hasLength(2));
    expect(repository.upserts.first.airTemp, 29.0);
    expect(repository.upserts.first.latitude, 12.16);
    expect(repository.upserts.first.tripId, 'trip-1');
  });

  test('a failed fetch writes no row', () async {
    final repository = FakeTripDayWeatherRepository();
    final container = containerWith(
      client: MockClient((_) async => http.Response('', 500)),
      repository: repository,
    );

    await container.read(tripDayWeatherBackfillProvider('trip-1').future);

    expect(repository.upserts, isEmpty);
  });

  test('a result with nothing renderable writes no row', () async {
    // Humidity and pressure only: the day header could render none of it, and
    // storing it would suppress the retry once the archive catches up.
    final repository = FakeTripDayWeatherRepository();
    final container = containerWith(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2026-03-08T12:00'],
              'temperature_2m': [null],
              'relative_humidity_2m': [70.0],
              'precipitation': [null],
              'cloud_cover': [null],
              'wind_speed_10m': [null],
              'wind_direction_10m': [null],
              'surface_pressure': [1011.0],
              'weathercode': [null],
            },
          }),
          200,
        ),
      ),
      repository: repository,
    );

    await container.read(tripDayWeatherBackfillProvider('trip-1').future);

    expect(repository.upserts, isEmpty);
  });

  test('a day already stored is not fetched', () async {
    final repository = FakeTripDayWeatherRepository(
      stored: {
        DateTime(2026, 3, 8).millisecondsSinceEpoch: TripDayWeather(
          id: 'w1',
          tripId: 'trip-1',
          date: DateTime(2026, 3, 8),
          latitude: 12.16,
          longitude: -68.28,
          airTemp: 21,
          fetchedAt: DateTime(2026, 3, 9),
          createdAt: DateTime(2026, 3, 9),
          updatedAt: DateTime(2026, 3, 9),
        ),
      },
    );
    var calls = 0;
    final container = containerWith(
      client: MockClient((_) async {
        calls++;
        return weatherResponse();
      }),
      repository: repository,
    );

    await container.read(tripDayWeatherBackfillProvider('trip-1').future);

    expect(calls, 1);
    expect(repository.upserts, hasLength(1));
    expect(repository.upserts.single.date, DateTime(2026, 3, 9));
  });

  test('fetches run one at a time', () async {
    final gate = Completer<void>();
    var started = 0;
    final repository = FakeTripDayWeatherRepository();
    final container = containerWith(
      client: MockClient((_) async {
        started++;
        if (started == 1) await gate.future;
        return weatherResponse();
      }),
      repository: repository,
    );

    final pending = container.read(
      tripDayWeatherBackfillProvider('trip-1').future,
    );
    await Future<void>.delayed(Duration.zero);

    // The second day must not be in flight while the first is pending.
    expect(started, 1);

    gate.complete();
    await pending;
    expect(started, 2);
  });
}
```

Add the `Trip` import (`features/trips/domain/entities/trip.dart`) for the fixture. Note that `tripStoryProvider` is a `family`, so the override must name the same key the backfill reads: `tripStoryProvider('trip-1')`.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/presentation/providers/trip_day_weather_providers_test.dart
```

Expected: FAIL with an unresolved import of `trip_day_weather_providers.dart`.

- [ ] **Step 3: Write the providers**

Create `lib/features/trips/presentation/providers/trip_day_weather_providers.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/services/trip_day_weather_backfill.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

final tripDayWeatherRepositoryProvider = Provider<TripDayWeatherRepository>(
  (ref) => TripDayWeatherRepository(),
);

/// Stored weather for a trip, keyed by `date.millisecondsSinceEpoch`.
///
/// Subscribes to the table tick, so a row written by the backfill or arriving
/// through sync re-renders the day headers without the widget knowing a fetch
/// ever happened.
final tripDayWeatherProvider =
    FutureProvider.family<Map<int, TripDayWeather>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripDayWeatherRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchWeatherChanges());
      return repository.getForTrip(tripId);
    });

/// Fills the gaps: fetches historical weather for trip days that have none
/// stored and no dive to supply it, then writes what it finds.
///
/// Deliberately does NOT watch [tripDayWeatherProvider]. Watching the rows it
/// writes would invalidate this provider on every write and start another
/// pass; it reads the stored rows straight from the repository instead. The
/// story is its only reactive input, so assigning dives to a trip re-evaluates
/// what is still missing.
///
/// Not auto-disposed: one pass per trip per provider container lifetime.
final tripDayWeatherBackfillProvider = FutureProvider.family<void, String>((
  ref,
  tripId,
) async {
  final story = await ref.watch(tripStoryProvider(tripId).future);
  final repository = ref.watch(tripDayWeatherRepositoryProvider);
  final service = ref.watch(weatherServiceProvider);

  final stored = await repository.getForTrip(tripId);
  final targets = TripDayWeatherBackfill.targetsFor(
    story: story,
    stored: stored,
  );
  if (targets.isEmpty) return;

  const uuid = Uuid();

  // Sequential on purpose: a two-week trip would otherwise open with a burst
  // of parallel requests, and rows landing one at a time let headers fill in
  // progressively.
  for (final target in targets) {
    final weather = await service.fetchWeather(
      latitude: target.latitude,
      longitude: target.longitude,
      date: target.date,
      entryTime: target.localNoon,
      useLocationTimezone: true,
    );
    if (weather == null) continue;

    final now = DateTime.now();
    final row = TripDayWeather(
      id: uuid.v4(),
      tripId: tripId,
      date: target.date,
      latitude: target.latitude,
      longitude: target.longitude,
      airTemp: weather.airTemp,
      cloudCover: weather.cloudCover,
      precipitation: weather.precipitation,
      windSpeed: weather.windSpeed,
      windDirection: weather.windDirection,
      humidity: weather.humidity,
      surfacePressure: weather.surfacePressure,
      weatherCode: weather.weatherCode,
      fetchedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // A row the header could render nothing from is worse than no row: it
    // would suppress the retry that a later archive update would satisfy.
    if (!row.hasRenderableWeather) continue;

    await repository.upsert(row);
  }
});
```

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/presentation/providers/trip_day_weather_providers_test.dart
```

Expected: PASS, all five tests.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(trips): fetch and store trip day weather once

The display provider rides the table tick; the backfill deliberately does
not, so the rows it writes cannot invalidate it into another pass. A miss
or an unrenderable result writes nothing and is retried on a later view."
```

---

### Task 6: Read path, and delete the per-view fetch

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart:34-70` (drop the provider watch, take stored weather as a parameter)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart:10` (import), `:236-243` (build stored weather instead of a fetch request), and the `TripStoryDayHeader` construction in `_daySliver`
- Delete: `lib/features/trips/presentation/providers/surface_day_weather_provider.dart`
- Delete: `test/features/trips/presentation/providers/surface_day_weather_provider_test.dart`
- Modify: `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart` (the four weather tests at lines 267-330)
- Modify: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart` (add provider overrides)

**Interfaces:**
- Consumes: `tripDayWeatherProvider` and `tripDayWeatherBackfillProvider` (Task 5).
- Produces: `TripStoryDayHeader({required TripStoryDay day, TripStoryDayWeather? storedWeather})`. The `surfaceWeatherRequest` parameter and the `SurfaceDayWeatherRequest` type are gone.

**Note for whoever implements this:** adding a provider dependency to a widget breaks every existing test that pumps it without an override. `trip_story_view_test.dart` pumps the whole view and will need both new providers overridden. Run that file's tests before assuming the change is complete.

- [ ] **Step 1: Update the header tests first**

In `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`, replace the four tests that override `surfaceDayWeatherProvider` (lines 267-330) with tests that pass the weather in directly. The header no longer fetches, so there is no loading state to test and the "pending future" test at line 305 has no meaning; replace it with the absence case.

```dart
    testWidgets('shows stored weather in the existing badge', (tester) async {
      await pumpHeader(
        tester,
        surfaceDay(),
        storedWeather: const TripStoryDayWeather(
          airTemp: 22,
          cloudCover: CloudCover.clear,
        ),
      );

      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.text('22°C'), findsOneWidget);
    });

    testWidgets('stored temperature respects Fahrenheit', (tester) async {
      final settings = MockSettingsNotifier();
      await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
      await pumpHeader(
        tester,
        surfaceDay(),
        settingsNotifier: settings,
        storedWeather: const TripStoryDayWeather(airTemp: 22),
      );

      expect(find.text('71.6°F'), findsOneWidget);
    });

    testWidgets('without stored weather stays badge-free', (tester) async {
      await pumpHeader(tester, surfaceDay());

      expect(find.textContaining('°'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('dive-logged weather wins over stored weather', (tester) async {
      // A day whose dive logged 26C must render 26, not the stored 22.
      await pumpHeader(
        tester,
        dayWithDive(airTemp: 26),
        storedWeather: const TripStoryDayWeather(airTemp: 22),
      );

      expect(find.text('26°C'), findsOneWidget);
      expect(find.text('22°C'), findsNothing);
    });
```

Update the `pumpHeader` helper in that file: replace its `surfaceWeatherRequest` parameter with `storedWeather`, and drop the `extra` overrides those tests passed. Use the file's existing fixture for a day with a dive in the last test.

- [ ] **Step 2: Run the header tests and watch them fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
```

Expected: FAIL to compile, because `TripStoryDayHeader` has no `storedWeather` parameter.

- [ ] **Step 3: Simplify the header**

In `trip_story_day_header.dart`:

- Replace the `surfaceWeatherRequest` field and constructor parameter with `final TripStoryDayWeather? storedWeather;` / `this.storedWeather`.
- Delete the `surface_day_weather_provider.dart` import.
- Replace the three lines at 66-69:

```dart
    final request = day.isSurface ? surfaceWeatherRequest : null;
    final fetchedWeather = request == null
        ? null
        : ref.watch(surfaceDayWeatherProvider(request)).asData?.value;
    final weather = day.weather ?? fetchedWeather;
```

with:

```dart
    // Dive-logged weather always wins: it is what the diver recorded, and a
    // fetched day summary is only ever a stand-in for days that logged none.
    final weather = day.weather ?? storedWeather;
```

Update the class docstring: the header no longer fetches anything, and the note about which days get a badge should say "days with logged or stored weather".

The widget still needs `ref` for `settingsProvider`, so it stays a `ConsumerWidget`.

- [ ] **Step 4: Wire the view**

In `trip_story_view.dart`:

- Replace the `surface_day_weather_provider.dart` import with `trip_day_weather_providers.dart`.
- In the widget's `build`, watch both providers once for the whole trip:

```dart
    // One read for the whole story; the backfill is a fire-and-forget pass
    // whose writes come back through the provider above.
    final storedWeather =
        ref.watch(tripDayWeatherProvider(widget.story.trip.id)).asData?.value ??
        const <int, TripDayWeather>{};
    ref.watch(tripDayWeatherBackfillProvider(widget.story.trip.id));
```

Pass `storedWeather` down to `_daySliver`, since that method builds the header.

- Replace the `weatherPoint` / `surfaceWeatherRequest` block at lines 236-243 with a map lookup:

```dart
    final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
    final stored = storedWeather[dayDate.millisecondsSinceEpoch];
```

- Construct the header with `storedWeather: stored?.toStoryWeather()`.

Check whether `_daySliver` is called from a place that must now thread the map through; if the method is on the state class, reading the value in `build` and passing it as a parameter keeps the data flow explicit.

- [ ] **Step 5: Delete the replaced provider**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  git rm lib/features/trips/presentation/providers/surface_day_weather_provider.dart \
         test/features/trips/presentation/providers/surface_day_weather_provider_test.dart
```

Then confirm nothing still references it:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  grep -rn "surfaceDayWeather\|SurfaceDayWeatherRequest" lib test
```

Expected: no output.

- [ ] **Step 6: Override the new providers in the view test**

In `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`, add to the overrides that file already builds:

```dart
        tripDayWeatherProvider(
          tripId,
        ).overrideWith((ref) async => const <int, TripDayWeather>{}),
        tripDayWeatherBackfillProvider(tripId).overrideWith((ref) async {}),
```

Without these, the view reaches a real repository and a real HTTP client under `flutter test`.

- [ ] **Step 7: Run the trips suite**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test test/features/trips/
```

Expected: PASS. A hang here usually means a widget test hit a real database or HTTP client; check the overrides.

- [ ] **Step 8: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  dart format . && \
  git add -A && \
  git commit -m "feat(trips): read trip day weather from the database

The day header no longer fetches: it renders whatever weather it is
handed, with dive-logged weather still winning. surfaceDayWeatherProvider
and its per-view Open-Meteo call are deleted."
```

---

### Task 7: Whole-project verification

**Files:** none created; this task proves the branch is shippable.

- [ ] **Step 1: Format the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  dart format .
```

- [ ] **Step 2: Analyze the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  flutter analyze
```

Expected: "No issues found!". CI treats infos as fatal, so an info-level finding must be fixed too. Do not pipe this through `grep`: a pipe masks the exit code and hides failures. The "Analyzing <dirname>..." line is the receipt that it ran in the right tree.

- [ ] **Step 3: Run the full test suite once**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  echo "PWD: $(pwd)" && \
  flutter test 2>&1 | tail -40
```

Expected: all tests pass. Notes:
- One full run is sufficient before opening a PR; do not run the suite repeatedly.
- Do not overlap this with another local test run, including in another worktree: concurrent runs produce spurious lone failures.
- If the output ends with no summary line and exit code 0, the run was killed by a sibling session rather than passing. Re-run it.
- If a single file fails here but passes when run alone, it is a known cross-test interaction, not a regression in this branch. Confirm by running that file alone before investigating.

- [ ] **Step 4: Re-check the schema rung**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  grep -n "currentSchemaVersion = " lib/core/database/database.dart | head -1
```

Expected: 171, and still above every claim found by the Task 1 scan. Re-run BOTH scans immediately before pushing, not just when picking the number: a claim can land in between. If another branch has taken 171 since, renumber: the six places from Task 1 Step 6 plus the test filename and this plan, then re-run `flutter test test/core/database/`.

- [ ] **Step 5: Commit anything the format pass touched**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-day-weather && \
  git status --short && \
  git add -A && \
  git commit -m "chore: format" || echo "nothing to commit"
```

---

## What this plan does not do

- **Range batching.** The Open-Meteo archive endpoint accepts `start_date`/`end_date`, so days sharing a coordinate could collapse into one request. Every day is fetched exactly once ever, so this is an optimization, not a fix. Noted in the spec as a follow-up.
- **A manual refresh action.** Nothing in the UI re-fetches a stored day. Deleting the row is the only way to force a refetch, and no UI exposes that.
- **Weather on dive days.** Dives already store their own, and `TripStoryDay.weather` composes it.
