# Weather Conditions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add weather condition logging to dive records with Open-Meteo auto-fetch and a merged "Environment" UI section.

**Architecture:** Inline weather fields on the `dives` table (8 new columns), a `WeatherService` HTTP client for Open-Meteo, and a `WeatherRepository` to orchestrate fetch + persist. The existing "Conditions" UI section becomes an "Environment" section with Weather and Dive Conditions sub-headers.

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod, http package, Open-Meteo Historical Weather API

**Spec:** `docs/superpowers/specs/2026-03-13-weather-conditions-design.md`

---

## Chunk 1: Data Layer -- Enums, Entity, Database Migration

### Task 1: Add CloudCover, Precipitation, WeatherSource Enums

**Files:**
- Modify: `lib/core/constants/enums.dart`
- Test: `test/core/constants/enums_test.dart`

- [ ] **Step 1: Write tests for new enums**

Create `test/core/constants/enums_test.dart` (or add to existing test file if one exists):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('CloudCover', () {
    test('has exactly 4 values', () {
      expect(CloudCover.values.length, 4);
    });

    test('each value has a displayName', () {
      expect(CloudCover.clear.displayName, 'Clear');
      expect(CloudCover.partlyCloudy.displayName, 'Partly Cloudy');
      expect(CloudCover.mostlyCloudy.displayName, 'Mostly Cloudy');
      expect(CloudCover.overcast.displayName, 'Overcast');
    });
  });

  group('Precipitation', () {
    test('has exactly 8 values', () {
      expect(Precipitation.values.length, 8);
    });

    test('each value has a displayName', () {
      expect(Precipitation.none.displayName, 'None');
      expect(Precipitation.drizzle.displayName, 'Drizzle');
      expect(Precipitation.lightRain.displayName, 'Light Rain');
      expect(Precipitation.rain.displayName, 'Rain');
      expect(Precipitation.heavyRain.displayName, 'Heavy Rain');
      expect(Precipitation.snow.displayName, 'Snow');
      expect(Precipitation.sleet.displayName, 'Sleet');
      expect(Precipitation.hail.displayName, 'Hail');
    });
  });

  group('WeatherSource', () {
    test('has exactly 2 values', () {
      expect(WeatherSource.values.length, 2);
    });

    test('each value has a displayName', () {
      expect(WeatherSource.manual.displayName, 'Manual');
      expect(WeatherSource.openMeteo.displayName, 'Open-Meteo');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/constants/enums_test.dart`
Expected: Compilation errors -- `CloudCover`, `Precipitation`, `WeatherSource` not defined.

- [ ] **Step 3: Add enums to enums.dart**

Add at the end of `lib/core/constants/enums.dart` (after the existing `DayType` enum around line 469):

```dart
/// Cloud cover conditions
enum CloudCover {
  clear('Clear'),
  partlyCloudy('Partly Cloudy'),
  mostlyCloudy('Mostly Cloudy'),
  overcast('Overcast');

  final String displayName;
  const CloudCover(this.displayName);
}

/// Precipitation type
enum Precipitation {
  none('None'),
  drizzle('Drizzle'),
  lightRain('Light Rain'),
  rain('Rain'),
  heavyRain('Heavy Rain'),
  snow('Snow'),
  sleet('Sleet'),
  hail('Hail');

  final String displayName;
  const Precipitation(this.displayName);
}

/// Source of weather data
enum WeatherSource {
  manual('Manual'),
  openMeteo('Open-Meteo');

  final String displayName;
  const WeatherSource(this.displayName);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/constants/enums_test.dart`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/enums.dart test/core/constants/enums_test.dart
git commit -m "feat: add CloudCover, Precipitation, WeatherSource enums"
```

---

### Task 2: Add Weather Fields to Dive Entity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Test: `test/features/dive_log/domain/entities/dive_weather_test.dart`

- [ ] **Step 1: Write tests for new weather fields on Dive**

Create `test/features/dive_log/domain/entities/dive_weather_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive weather fields', () {
    test('default weather fields are null', () {
      final dive = Dive(
        id: 'test-1',
        dateTime: DateTime(2024, 6, 15),
      );
      expect(dive.windSpeed, isNull);
      expect(dive.windDirection, isNull);
      expect(dive.cloudCover, isNull);
      expect(dive.precipitation, isNull);
      expect(dive.humidity, isNull);
      expect(dive.weatherDescription, isNull);
      expect(dive.weatherSource, isNull);
      expect(dive.weatherFetchedAt, isNull);
    });

    test('can construct Dive with weather fields', () {
      final fetchedAt = DateTime(2024, 6, 15, 10, 30);
      final dive = Dive(
        id: 'test-2',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        windDirection: CurrentDirection.northEast,
        cloudCover: CloudCover.partlyCloudy,
        precipitation: Precipitation.none,
        humidity: 75.0,
        weatherDescription: 'Warm and sunny',
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: fetchedAt,
      );

      expect(dive.windSpeed, 5.5);
      expect(dive.windDirection, CurrentDirection.northEast);
      expect(dive.cloudCover, CloudCover.partlyCloudy);
      expect(dive.precipitation, Precipitation.none);
      expect(dive.humidity, 75.0);
      expect(dive.weatherDescription, 'Warm and sunny');
      expect(dive.weatherSource, WeatherSource.openMeteo);
      expect(dive.weatherFetchedAt, fetchedAt);
    });

    test('copyWith preserves weather fields when not overridden', () {
      final dive = Dive(
        id: 'test-3',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        cloudCover: CloudCover.overcast,
      );

      final copy = dive.copyWith(notes: 'Updated');
      expect(copy.windSpeed, 5.5);
      expect(copy.cloudCover, CloudCover.overcast);
      expect(copy.notes, 'Updated');
    });

    test('copyWith can override weather fields', () {
      final dive = Dive(
        id: 'test-4',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        cloudCover: CloudCover.overcast,
      );

      final copy = dive.copyWith(
        windSpeed: 10.0,
        cloudCover: CloudCover.clear,
      );
      expect(copy.windSpeed, 10.0);
      expect(copy.cloudCover, CloudCover.clear);
    });

    test('Equatable includes weather fields', () {
      final dive1 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
      );
      final dive2 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
      );
      final dive3 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 10.0,
      );

      expect(dive1, equals(dive2));
      expect(dive1, isNot(equals(dive3)));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/entities/dive_weather_test.dart`
Expected: Compilation error -- Dive constructor does not accept `windSpeed`, etc.

- [ ] **Step 3: Add weather fields to Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`, add to the field declarations (after the `customFields` field at line 113):

```dart
  // Weather fields
  final double? windSpeed; // m/s
  final CurrentDirection? windDirection;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? humidity; // 0-100
  final String? weatherDescription;
  final WeatherSource? weatherSource;
  final DateTime? weatherFetchedAt;
```

Add import for enums at the top if not already imported (it's already imported via `enums.dart`).

Add to the constructor (after `customFields` parameter at line 189):

```dart
    // Weather fields
    this.windSpeed,
    this.windDirection,
    this.cloudCover,
    this.precipitation,
    this.humidity,
    this.weatherDescription,
    this.weatherSource,
    this.weatherFetchedAt,
```

Add to `copyWith` method parameters (after `customFields` parameter at line 494):

```dart
    // Weather fields
    double? windSpeed,
    CurrentDirection? windDirection,
    CloudCover? cloudCover,
    Precipitation? precipitation,
    double? humidity,
    String? weatherDescription,
    WeatherSource? weatherSource,
    DateTime? weatherFetchedAt,
```

Add to `copyWith` return body (after `customFields` line at line 570):

```dart
      // Weather fields
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      cloudCover: cloudCover ?? this.cloudCover,
      precipitation: precipitation ?? this.precipitation,
      humidity: humidity ?? this.humidity,
      weatherDescription: weatherDescription ?? this.weatherDescription,
      weatherSource: weatherSource ?? this.weatherSource,
      weatherFetchedAt: weatherFetchedAt ?? this.weatherFetchedAt,
```

Add to `props` list (after `customFields` line at line 649):

```dart
    // Weather fields
    windSpeed,
    windDirection,
    cloudCover,
    precipitation,
    humidity,
    weatherDescription,
    weatherSource,
    weatherFetchedAt,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/entities/dive_weather_test.dart`
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_weather_test.dart
git commit -m "feat: add weather fields to Dive entity"
```

---

### Task 3: Create WeatherData Value Object

**Files:**
- Create: `lib/features/weather/domain/entities/weather_data.dart`
- Test: `test/features/weather/domain/entities/weather_data_test.dart`

- [ ] **Step 1: Write tests for WeatherData**

Create `test/features/weather/domain/entities/weather_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

void main() {
  group('WeatherData', () {
    test('can be constructed with all fields', () {
      final data = WeatherData(
        windSpeed: 5.5,
        windDirection: CurrentDirection.north,
        cloudCover: CloudCover.clear,
        precipitation: Precipitation.none,
        humidity: 60.0,
        airTemp: 28.0,
        surfacePressure: 1.013,
        description: 'Clear skies',
      );

      expect(data.windSpeed, 5.5);
      expect(data.windDirection, CurrentDirection.north);
      expect(data.cloudCover, CloudCover.clear);
      expect(data.precipitation, Precipitation.none);
      expect(data.humidity, 60.0);
      expect(data.airTemp, 28.0);
      expect(data.surfacePressure, 1.013);
      expect(data.description, 'Clear skies');
    });

    test('defaults are all null', () {
      const data = WeatherData();
      expect(data.windSpeed, isNull);
      expect(data.windDirection, isNull);
      expect(data.cloudCover, isNull);
      expect(data.precipitation, isNull);
      expect(data.humidity, isNull);
      expect(data.airTemp, isNull);
      expect(data.surfacePressure, isNull);
      expect(data.description, isNull);
    });

    test('equality works', () {
      const data1 = WeatherData(windSpeed: 5.5, humidity: 60.0);
      const data2 = WeatherData(windSpeed: 5.5, humidity: 60.0);
      const data3 = WeatherData(windSpeed: 10.0, humidity: 60.0);

      expect(data1, equals(data2));
      expect(data1, isNot(equals(data3)));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/weather/domain/entities/weather_data_test.dart`
Expected: Compilation error -- file not found.

- [ ] **Step 3: Create WeatherData entity**

Create `lib/features/weather/domain/entities/weather_data.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Immutable value object for weather data fetched from an API or entered manually.
///
/// Used as the return type from WeatherService and as input to WeatherRepository
/// when persisting fetched data to a dive record.
class WeatherData extends Equatable {
  final double? windSpeed; // m/s
  final CurrentDirection? windDirection;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? humidity; // 0-100
  final double? airTemp; // celsius
  final double? surfacePressure; // bar
  final String? description;

  const WeatherData({
    this.windSpeed,
    this.windDirection,
    this.cloudCover,
    this.precipitation,
    this.humidity,
    this.airTemp,
    this.surfacePressure,
    this.description,
  });

  @override
  List<Object?> get props => [
    windSpeed,
    windDirection,
    cloudCover,
    precipitation,
    humidity,
    airTemp,
    surfacePressure,
    description,
  ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/weather/domain/entities/weather_data_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/weather/domain/entities/weather_data.dart test/features/weather/domain/entities/weather_data_test.dart
git commit -m "feat: create WeatherData value object"
```

---

### Task 4: Add Weather Columns to Database and Migration

**Files:**
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Add weather columns to Dives table definition**

In `lib/core/database/database.dart`, add after the `waterType` column (around line 140):

```dart
  // Weather conditions
  RealColumn get windSpeed => real().nullable()(); // m/s
  TextColumn get windDirection => text().nullable()(); // enum: CurrentDirection.name
  TextColumn get cloudCover => text().nullable()();
  TextColumn get precipitation => text().nullable()();
  RealColumn get humidity => real().nullable()(); // 0-100
  TextColumn get weatherDescription => text().nullable()();
  TextColumn get weatherSource => text().nullable()(); // enum: WeatherSource.name
  IntColumn get weatherFetchedAt =>
      integer().nullable()(); // unix timestamp
```

**Note:** The existing underwater current column is `currentDirection`, so `windDirection` does not conflict.

- [ ] **Step 2: Increment schema version**

Change `int get schemaVersion => 47;` to `int get schemaVersion => 48;` (around line 1167).

- [ ] **Step 3: Add migration logic**

Inside the `onUpgrade` method, add a new migration block (follow the pattern of existing `if (from < N)` blocks):

```dart
if (from < 48) {
  await customStatement(
    'ALTER TABLE dives ADD COLUMN wind_speed REAL',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN wind_direction TEXT',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN cloud_cover TEXT',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN precipitation TEXT',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN humidity REAL',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN weather_description TEXT',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN weather_source TEXT',
  );
  await customStatement(
    'ALTER TABLE dives ADD COLUMN weather_fetched_at INTEGER',
  );
}
```

**Important:** Drift converts camelCase Dart names to snake_case SQL column names. Match the SQL names to the Dart field names' snake_case equivalents.

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` with new columns.

- [ ] **Step 5: Verify build compiles**

Run: `flutter analyze`
Expected: No errors (warnings are acceptable).

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add weather columns to dives table (migration v48)"
```

---

### Task 5: Update DiveRepository Mapping for Weather Fields

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_weather_test.dart`

- [ ] **Step 1: Write tests for weather field mapping in repository**

Create `test/features/dive_log/data/repositories/dive_repository_weather_test.dart`. This test verifies that weather fields round-trip correctly through createDive/getDiveById. Uses the project's `test_database.dart` helper to inject an in-memory database into `DatabaseService.instance`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('DiveRepository weather fields', () {
    test('createDive persists weather fields and getDiveById retrieves them',
        () async {
      final dive = Dive(
        id: 'weather-test-1',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        windDirection: CurrentDirection.northEast,
        cloudCover: CloudCover.partlyCloudy,
        precipitation: Precipitation.none,
        humidity: 75.0,
        weatherDescription: 'Warm and sunny',
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: DateTime(2024, 6, 15, 10, 0),
      );

      await repository.createDive(dive);
      final retrieved = await repository.getDiveById('weather-test-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.windSpeed, 5.5);
      expect(retrieved.windDirection, CurrentDirection.northEast);
      expect(retrieved.cloudCover, CloudCover.partlyCloudy);
      expect(retrieved.precipitation, Precipitation.none);
      expect(retrieved.humidity, 75.0);
      expect(retrieved.weatherDescription, 'Warm and sunny');
      expect(retrieved.weatherSource, WeatherSource.openMeteo);
      expect(retrieved.weatherFetchedAt, isNotNull);
    });

    test('null weather fields persist as null', () async {
      final dive = Dive(
        id: 'weather-test-2',
        dateTime: DateTime(2024, 6, 15),
      );

      await repository.createDive(dive);
      final retrieved = await repository.getDiveById('weather-test-2');

      expect(retrieved, isNotNull);
      expect(retrieved!.windSpeed, isNull);
      expect(retrieved.windDirection, isNull);
      expect(retrieved.cloudCover, isNull);
      expect(retrieved.precipitation, isNull);
      expect(retrieved.humidity, isNull);
      expect(retrieved.weatherDescription, isNull);
      expect(retrieved.weatherSource, isNull);
      expect(retrieved.weatherFetchedAt, isNull);
    });

    test('updateDive updates weather fields', () async {
      final dive = Dive(
        id: 'weather-test-3',
        dateTime: DateTime(2024, 6, 15),
      );
      await repository.createDive(dive);

      final updated = dive.copyWith(
        windSpeed: 8.0,
        cloudCover: CloudCover.overcast,
        weatherSource: WeatherSource.manual,
      );
      await repository.updateDive(updated);

      final retrieved = await repository.getDiveById('weather-test-3');
      expect(retrieved!.windSpeed, 8.0);
      expect(retrieved.cloudCover, CloudCover.overcast);
      expect(retrieved.weatherSource, WeatherSource.manual);
    });
  });
}
```

**Important:** `DiveRepository()` takes no constructor arguments -- it gets its database via `DatabaseService.instance.database`. The `setUpTestDatabase()` helper injects an in-memory database into `DatabaseService.instance`, which `DiveRepository` then uses automatically. See `test/helpers/test_database.dart` for the pattern.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_weather_test.dart`
Expected: Compilation error -- Dive constructor doesn't accept weather fields (if running before Task 2), or mapping fails because repository doesn't read new columns yet.

- [ ] **Step 3: Update `_mapRowToDive` to read weather columns**

In `_mapRowToDive` method (around line 1969+), add weather field mappings after the existing conditions fields (after `waterType` mapping):

```dart
windSpeed: row.windSpeed,
windDirection: row.windDirection != null
    ? CurrentDirection.values.firstWhere(
        (c) => c.name == row.windDirection,
        orElse: () => CurrentDirection.none,
      )
    : null,
cloudCover: row.cloudCover != null
    ? CloudCover.values.firstWhere(
        (c) => c.name == row.cloudCover,
        orElse: () => CloudCover.clear,
      )
    : null,
precipitation: row.precipitation != null
    ? Precipitation.values.firstWhere(
        (p) => p.name == row.precipitation,
        orElse: () => Precipitation.none,
      )
    : null,
humidity: row.humidity,
weatherDescription: row.weatherDescription,
weatherSource: row.weatherSource != null
    ? WeatherSource.values.firstWhere(
        (w) => w.name == row.weatherSource,
        orElse: () => WeatherSource.manual,
      )
    : null,
weatherFetchedAt: row.weatherFetchedAt != null
    ? DateTime.fromMillisecondsSinceEpoch(row.weatherFetchedAt! * 1000)
    : null,
```

- [ ] **Step 4: Update `_mapRowToDiveWithPreloadedData` similarly**

Add the same weather field mappings to `_mapRowToDiveWithPreloadedData` (around line 1745+). The pattern is identical.

- [ ] **Step 5: Update `createDive` DivesCompanion**

In `createDive` method (around line 494+), add to the DivesCompanion constructor after existing conditions fields:

```dart
windSpeed: Value(dive.windSpeed),
windDirection: Value(dive.windDirection?.name),
cloudCover: Value(dive.cloudCover?.name),
precipitation: Value(dive.precipitation?.name),
humidity: Value(dive.humidity),
weatherDescription: Value(dive.weatherDescription),
weatherSource: Value(dive.weatherSource?.name),
weatherFetchedAt: Value(
  dive.weatherFetchedAt != null
      ? dive.weatherFetchedAt!.millisecondsSinceEpoch ~/ 1000
      : null,
),
```

- [ ] **Step 6: Update `updateDive` DivesCompanion**

In `updateDive` method (around line 689+), add same fields to the DivesCompanion.

- [ ] **Step 7: Add required imports**

Ensure `CloudCover`, `Precipitation`, `WeatherSource` are accessible. They should be via the existing `enums.dart` import.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_weather_test.dart`
Expected: All 3 tests pass (weather fields round-trip correctly).

- [ ] **Step 9: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_weather_test.dart
git commit -m "feat: map weather fields in DiveRepository"
```

---

## Chunk 2: Weather Service -- HTTP Client and Mapper

### Task 6: Create Weather Mapper (Pure Logic)

**Files:**
- Create: `lib/features/weather/data/services/weather_mapper.dart`
- Test: `test/features/weather/data/services/weather_mapper_test.dart`

- [ ] **Step 1: Write tests for weather mapper**

Create `test/features/weather/data/services/weather_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/data/services/weather_mapper.dart';

void main() {
  group('WeatherMapper', () {
    group('mapCloudCover', () {
      test('0-20% maps to clear', () {
        expect(WeatherMapper.mapCloudCover(0), CloudCover.clear);
        expect(WeatherMapper.mapCloudCover(20), CloudCover.clear);
      });

      test('21-50% maps to partlyCloudy', () {
        expect(WeatherMapper.mapCloudCover(21), CloudCover.partlyCloudy);
        expect(WeatherMapper.mapCloudCover(50), CloudCover.partlyCloudy);
      });

      test('51-80% maps to mostlyCloudy', () {
        expect(WeatherMapper.mapCloudCover(51), CloudCover.mostlyCloudy);
        expect(WeatherMapper.mapCloudCover(80), CloudCover.mostlyCloudy);
      });

      test('81-100% maps to overcast', () {
        expect(WeatherMapper.mapCloudCover(81), CloudCover.overcast);
        expect(WeatherMapper.mapCloudCover(100), CloudCover.overcast);
      });

      test('null returns null', () {
        expect(WeatherMapper.mapCloudCover(null), isNull);
      });
    });

    group('mapPrecipitation', () {
      test('weathercode for snow returns snow', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 71),
          Precipitation.snow,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 77),
          Precipitation.snow,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 85),
          Precipitation.snow,
        );
      });

      test('weathercode for freezing rain returns sleet', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 66),
          Precipitation.sleet,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 67),
          Precipitation.sleet,
        );
      });

      test('weathercode for hail returns hail', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 96),
          Precipitation.hail,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 99),
          Precipitation.hail,
        );
      });

      test('0mm rain returns none', () {
        expect(
          WeatherMapper.mapPrecipitation(0.0, weatherCode: 0),
          Precipitation.none,
        );
      });

      test('light amounts return drizzle', () {
        expect(
          WeatherMapper.mapPrecipitation(0.3, weatherCode: 51),
          Precipitation.drizzle,
        );
      });

      test('moderate amounts return lightRain', () {
        expect(
          WeatherMapper.mapPrecipitation(1.5, weatherCode: 61),
          Precipitation.lightRain,
        );
      });

      test('heavy amounts return rain', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 63),
          Precipitation.rain,
        );
      });

      test('very heavy amounts return heavyRain', () {
        expect(
          WeatherMapper.mapPrecipitation(10.0, weatherCode: 65),
          Precipitation.heavyRain,
        );
      });

      test('null precipitation returns none', () {
        expect(
          WeatherMapper.mapPrecipitation(null, weatherCode: 0),
          Precipitation.none,
        );
      });
    });

    group('mapWindDirection', () {
      test('0 degrees maps to north', () {
        expect(WeatherMapper.mapWindDirection(0), CurrentDirection.north);
      });

      test('45 degrees maps to northEast', () {
        expect(WeatherMapper.mapWindDirection(45), CurrentDirection.northEast);
      });

      test('90 degrees maps to east', () {
        expect(WeatherMapper.mapWindDirection(90), CurrentDirection.east);
      });

      test('180 degrees maps to south', () {
        expect(WeatherMapper.mapWindDirection(180), CurrentDirection.south);
      });

      test('270 degrees maps to west', () {
        expect(WeatherMapper.mapWindDirection(270), CurrentDirection.west);
      });

      test('350 degrees maps to north (wraps)', () {
        expect(WeatherMapper.mapWindDirection(350), CurrentDirection.north);
      });

      test('null returns null', () {
        expect(WeatherMapper.mapWindDirection(null), isNull);
      });
    });

    group('convertWindSpeedKmhToMs', () {
      test('converts km/h to m/s', () {
        expect(
          WeatherMapper.convertWindSpeedKmhToMs(36.0),
          closeTo(10.0, 0.01),
        );
      });

      test('null returns null', () {
        expect(WeatherMapper.convertWindSpeedKmhToMs(null), isNull);
      });
    });

    group('convertPressureHpaToBar', () {
      test('converts hPa to bar', () {
        expect(
          WeatherMapper.convertPressureHpaToBar(1013.0),
          closeTo(1.013, 0.001),
        );
      });

      test('null returns null', () {
        expect(WeatherMapper.convertPressureHpaToBar(null), isNull);
      });
    });

    group('buildDescription', () {
      test('builds description from weather data', () {
        final desc = WeatherMapper.buildDescription(
          cloudCover: CloudCover.partlyCloudy,
          airTempCelsius: 28.0,
          windSpeedMs: 3.0,
          windDirection: CurrentDirection.northEast,
          precipitation: Precipitation.none,
        );
        expect(desc, isNotEmpty);
        expect(desc, contains('Partly Cloudy'));
      });

      test('handles all nulls gracefully', () {
        final desc = WeatherMapper.buildDescription();
        expect(desc, isNull);
      });
    });

    group('mapApiResponse', () {
      test('maps a full hourly API response', () {
        final hourlyData = {
          'time': [
            '2024-06-15T08:00',
            '2024-06-15T09:00',
            '2024-06-15T10:00',
          ],
          'temperature_2m': [26.0, 27.0, 28.0],
          'relative_humidity_2m': [80.0, 75.0, 70.0],
          'precipitation': [0.0, 0.0, 0.0],
          'cloud_cover': [30.0, 25.0, 20.0],
          'wind_speed_10m': [10.0, 12.0, 14.0],
          'wind_direction_10m': [45.0, 50.0, 55.0],
          'surface_pressure': [1013.0, 1013.5, 1014.0],
          'weathercode': [1, 1, 0],
        };

        final result = WeatherMapper.mapApiResponse(
          hourlyData,
          targetHour: DateTime(2024, 6, 15, 9, 30),
        );

        // Should pick hour index 1 (09:00) as closest to 09:30
        expect(result.airTemp, 27.0);
        expect(result.humidity, 75.0);
        expect(result.precipitation, Precipitation.none);
        expect(result.cloudCover, CloudCover.partlyCloudy);
        expect(result.windDirection, CurrentDirection.northEast);
        expect(result.surfacePressure, closeTo(1.0135, 0.001));
        expect(result.windSpeed, closeTo(12.0 / 3.6, 0.01));
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/weather/data/services/weather_mapper_test.dart`
Expected: Compilation error -- `WeatherMapper` not defined.

- [ ] **Step 3: Implement WeatherMapper**

Create `lib/features/weather/data/services/weather_mapper.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// Maps Open-Meteo API response data to domain types.
///
/// All conversion methods are static and pure -- no state, no side effects.
class WeatherMapper {
  WeatherMapper._();

  /// Map cloud cover percentage (0-100) to CloudCover enum.
  static CloudCover? mapCloudCover(num? percent) {
    if (percent == null) return null;
    if (percent <= 20) return CloudCover.clear;
    if (percent <= 50) return CloudCover.partlyCloudy;
    if (percent <= 80) return CloudCover.mostlyCloudy;
    return CloudCover.overcast;
  }

  /// Map precipitation amount (mm/h) and WMO weather code to Precipitation enum.
  ///
  /// Weather codes checked first for snow/sleet/hail detection:
  /// - 71-77, 85-86: snow
  /// - 66-67: sleet (freezing rain)
  /// - 96-99: hail (thunderstorm with hail)
  static Precipitation mapPrecipitation(
    num? mmPerHour, {
    int? weatherCode,
  }) {
    // Check weather code for special precipitation types
    if (weatherCode != null) {
      if ((weatherCode >= 71 && weatherCode <= 77) ||
          (weatherCode >= 85 && weatherCode <= 86)) {
        return Precipitation.snow;
      }
      if (weatherCode >= 66 && weatherCode <= 67) {
        return Precipitation.sleet;
      }
      if (weatherCode >= 96 && weatherCode <= 99) {
        return Precipitation.hail;
      }
    }

    // Fall back to amount-based classification
    final amount = mmPerHour ?? 0;
    if (amount <= 0) return Precipitation.none;
    if (amount <= 0.5) return Precipitation.drizzle;
    if (amount <= 2.5) return Precipitation.lightRain;
    if (amount <= 7.5) return Precipitation.rain;
    return Precipitation.heavyRain;
  }

  /// Map wind direction in degrees (0-360) to CurrentDirection enum.
  ///
  /// Uses >= lower bound, < upper bound for each sector (45 degree sectors).
  static CurrentDirection? mapWindDirection(num? degrees) {
    if (degrees == null) return null;
    final d = degrees.toDouble() % 360;
    if (d >= 337.5 || d < 22.5) return CurrentDirection.north;
    if (d < 67.5) return CurrentDirection.northEast;
    if (d < 112.5) return CurrentDirection.east;
    if (d < 157.5) return CurrentDirection.southEast;
    if (d < 202.5) return CurrentDirection.south;
    if (d < 247.5) return CurrentDirection.southWest;
    if (d < 292.5) return CurrentDirection.west;
    return CurrentDirection.northWest;
  }

  /// Convert wind speed from km/h to m/s.
  static double? convertWindSpeedKmhToMs(num? kmh) {
    if (kmh == null) return null;
    return kmh / 3.6;
  }

  /// Convert pressure from hPa (mbar) to bar.
  static double? convertPressureHpaToBar(num? hpa) {
    if (hpa == null) return null;
    return hpa / 1000;
  }

  /// Build a human-readable weather description from data.
  ///
  /// Returns null if no data is available.
  static String? buildDescription({
    CloudCover? cloudCover,
    double? airTempCelsius,
    double? windSpeedMs,
    CurrentDirection? windDirection,
    Precipitation? precipitation,
  }) {
    final parts = <String>[];

    if (cloudCover != null) {
      parts.add(cloudCover.displayName);
    }

    if (airTempCelsius != null) {
      parts.add('${airTempCelsius.round()}C');
    }

    if (windSpeedMs != null && windSpeedMs > 0) {
      final beaufort = _windDescription(windSpeedMs);
      final dirStr =
          windDirection != null && windDirection != CurrentDirection.none
              ? ' from ${windDirection.displayName}'
              : '';
      parts.add('$beaufort$dirStr');
    }

    if (precipitation != null && precipitation != Precipitation.none) {
      parts.add(precipitation.displayName);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Map a full Open-Meteo hourly API response to WeatherData.
  ///
  /// Selects the hour closest to [targetHour] from the hourly arrays.
  static WeatherData mapApiResponse(
    Map<String, dynamic> hourlyData, {
    required DateTime targetHour,
  }) {
    final times = (hourlyData['time'] as List).cast<String>();
    final index = _findClosestHourIndex(times, targetHour);

    final temp = _getDouble(hourlyData['temperature_2m'], index);
    final humidity = _getDouble(hourlyData['relative_humidity_2m'], index);
    final precip = _getDouble(hourlyData['precipitation'], index);
    final cloud = _getDouble(hourlyData['cloud_cover'], index);
    final windKmh = _getDouble(hourlyData['wind_speed_10m'], index);
    final windDeg = _getDouble(hourlyData['wind_direction_10m'], index);
    final pressureHpa = _getDouble(hourlyData['surface_pressure'], index);
    final weatherCode = _getInt(hourlyData['weathercode'], index);

    final cloudCoverEnum = mapCloudCover(cloud);
    final windDirection = mapWindDirection(windDeg);
    final windSpeedMs = convertWindSpeedKmhToMs(windKmh);
    final precipEnum = mapPrecipitation(precip, weatherCode: weatherCode);
    final pressureBar = convertPressureHpaToBar(pressureHpa);

    return WeatherData(
      windSpeed: windSpeedMs,
      windDirection: windDirection,
      cloudCover: cloudCoverEnum,
      precipitation: precipEnum,
      humidity: humidity,
      airTemp: temp,
      surfacePressure: pressureBar,
      description: buildDescription(
        cloudCover: cloudCoverEnum,
        airTempCelsius: temp,
        windSpeedMs: windSpeedMs,
        windDirection: windDirection,
        precipitation: precipEnum,
      ),
    );
  }

  static int _findClosestHourIndex(List<String> times, DateTime target) {
    int closestIndex = 0;
    Duration closestDiff = const Duration(days: 365);

    for (int i = 0; i < times.length; i++) {
      final parsed = DateTime.parse(times[i]);
      final diff = (parsed.difference(target)).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  static double? _getDouble(dynamic list, int index) {
    if (list is! List || index >= list.length) return null;
    final val = list[index];
    if (val == null) return null;
    return (val as num).toDouble();
  }

  static int? _getInt(dynamic list, int index) {
    if (list is! List || index >= list.length) return null;
    final val = list[index];
    if (val == null) return null;
    return (val as num).toInt();
  }

  static String _windDescription(double ms) {
    if (ms < 0.5) return 'calm';
    if (ms < 3.4) return 'light breeze';
    if (ms < 8.0) return 'moderate breeze';
    if (ms < 13.9) return 'strong breeze';
    return 'high wind';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/weather/data/services/weather_mapper_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/weather/data/services/weather_mapper.dart test/features/weather/data/services/weather_mapper_test.dart
git commit -m "feat: add WeatherMapper for Open-Meteo API response mapping"
```

---

### Task 7: Create WeatherService HTTP Client

**Files:**
- Create: `lib/features/weather/data/services/weather_service.dart`
- Test: `test/features/weather/data/services/weather_service_test.dart`

- [ ] **Step 1: Write tests for WeatherService**

Create `test/features/weather/data/services/weather_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    test('fetchWeather returns WeatherData on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'archive-api.open-meteo.com');
        expect(request.url.queryParameters['latitude'], '28.5');
        expect(request.url.queryParameters['longitude'], '-80.6');
        expect(request.url.queryParameters['start_date'], '2024-06-15');
        expect(request.url.queryParameters['end_date'], '2024-06-15');

        return http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2024-06-15T09:00', '2024-06-15T10:00'],
              'temperature_2m': [27.0, 28.0],
              'relative_humidity_2m': [75.0, 70.0],
              'precipitation': [0.0, 0.0],
              'cloud_cover': [25.0, 20.0],
              'wind_speed_10m': [12.0, 14.0],
              'wind_direction_10m': [45.0, 50.0],
              'surface_pressure': [1013.0, 1014.0],
              'weathercode': [1, 0],
            },
          }),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNotNull);
      expect(result!.airTemp, 27.0);
      expect(result.cloudCover, CloudCover.partlyCloudy);
      expect(result.precipitation, Precipitation.none);
    });

    test('fetchWeather returns null on HTTP error', () async {
      final mockClient = MockClient((_) async {
        return http.Response('Server error', 500);
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNull);
    });

    test('fetchWeather returns null on network error', () async {
      final mockClient = MockClient((_) async {
        throw Exception('No internet');
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/weather/data/services/weather_service_test.dart`
Expected: Compilation error -- `WeatherService` not defined.

- [ ] **Step 3: Implement WeatherService**

Create `lib/features/weather/data/services/weather_service.dart`:

```dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/weather/data/services/weather_mapper.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// HTTP client for the Open-Meteo Historical Weather API.
///
/// Returns [WeatherData] on success, null on any failure (network, API error,
/// malformed response). Callers should handle null gracefully.
class WeatherService {
  final http.Client _client;

  static const _baseUrl = 'archive-api.open-meteo.com';
  static const _path = '/v1/archive';
  static const _hourlyParams =
      'temperature_2m,relative_humidity_2m,precipitation,'
      'cloud_cover,wind_speed_10m,wind_direction_10m,'
      'surface_pressure,weathercode';

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch historical weather for a given location and date.
  ///
  /// [entryTime] is used to select the closest hourly data point.
  /// Returns null if the request fails or data is unavailable.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final uri = Uri.https(_baseUrl, _path, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': dateStr,
        'end_date': dateStr,
        'hourly': _hourlyParams,
      });

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        developer.log(
          'Weather API error: ${response.statusCode}',
          name: 'WeatherService',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return null;

      return WeatherMapper.mapApiResponse(hourly, targetHour: entryTime);
    } catch (e) {
      developer.log(
        'Weather fetch failed: $e',
        name: 'WeatherService',
      );
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/weather/data/services/weather_service_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/weather/data/services/weather_service.dart test/features/weather/data/services/weather_service_test.dart
git commit -m "feat: add WeatherService HTTP client for Open-Meteo API"
```

---

### Task 8: Create WeatherRepository

**Files:**
- Create: `lib/features/weather/data/repositories/weather_repository.dart`
- Test: `test/features/weather/data/repositories/weather_repository_test.dart`

- [ ] **Step 1: Write tests for WeatherRepository**

Create `test/features/weather/data/repositories/weather_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/weather/data/repositories/weather_repository.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

@GenerateMocks([WeatherService, DiveRepository])
import 'weather_repository_test.mocks.dart';

void main() {
  late MockWeatherService mockWeatherService;
  late MockDiveRepository mockDiveRepository;
  late WeatherRepository weatherRepository;

  setUp(() {
    mockWeatherService = MockWeatherService();
    mockDiveRepository = MockDiveRepository();
    weatherRepository = WeatherRepository(
      weatherService: mockWeatherService,
      diveRepository: mockDiveRepository,
    );
  });

  group('fetchAndSaveWeather', () {
    final testDive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2024, 6, 15, 10, 0),
      airTemp: null,
      surfacePressure: null,
    );

    final testWeatherData = WeatherData(
      windSpeed: 3.5,
      windDirection: CurrentDirection.northEast,
      cloudCover: CloudCover.partlyCloudy,
      precipitation: Precipitation.none,
      humidity: 75.0,
      airTemp: 28.0,
      surfacePressure: 1.013,
      description: 'Partly Cloudy, 28C',
    );

    test('fetches weather and updates dive', () async {
      when(mockDiveRepository.getDiveById('dive-1'))
          .thenAnswer((_) async => testDive);
      when(mockWeatherService.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 10, 0),
      )).thenAnswer((_) async => testWeatherData);
      when(mockDiveRepository.updateDive(any))
          .thenAnswer((_) async => testDive);

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-1',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      final captured =
          verify(mockDiveRepository.updateDive(captureAny)).captured.single
              as Dive;
      expect(captured.windSpeed, 3.5);
      expect(captured.cloudCover, CloudCover.partlyCloudy);
      expect(captured.weatherSource, WeatherSource.openMeteo);
      expect(captured.weatherFetchedAt, isNotNull);
      // airTemp should be populated (was null)
      expect(captured.airTemp, 28.0);
      // surfacePressure should be populated (was null)
      expect(captured.surfacePressure, 1.013);
    });

    test('does not overwrite existing airTemp', () async {
      final diveWithAirTemp = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 6, 15, 10, 0),
        airTemp: 30.0, // Already set
        surfacePressure: null,
      );

      when(mockDiveRepository.getDiveById('dive-2'))
          .thenAnswer((_) async => diveWithAirTemp);
      when(mockWeatherService.fetchWeather(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        date: anyNamed('date'),
        entryTime: anyNamed('entryTime'),
      )).thenAnswer((_) async => testWeatherData);
      when(mockDiveRepository.updateDive(any))
          .thenAnswer((_) async => diveWithAirTemp);

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-2',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      final captured =
          verify(mockDiveRepository.updateDive(captureAny)).captured.single
              as Dive;
      // Should keep existing airTemp (30.0), not overwrite with API value (28.0)
      expect(captured.airTemp, 30.0);
    });

    test('does not update dive when service returns null', () async {
      when(mockDiveRepository.getDiveById('dive-3'))
          .thenAnswer((_) async => testDive);
      when(mockWeatherService.fetchWeather(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        date: anyNamed('date'),
        entryTime: anyNamed('entryTime'),
      )).thenAnswer((_) async => null);

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-3',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      verifyNever(mockDiveRepository.updateDive(any));
    });
  });
}
```

- [ ] **Step 2: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates `weather_repository_test.mocks.dart`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/weather/data/repositories/weather_repository_test.dart`
Expected: Compilation error -- `WeatherRepository` not defined.

- [ ] **Step 4: Implement WeatherRepository**

Create `lib/features/weather/data/repositories/weather_repository.dart`:

```dart
import 'dart:developer' as developer;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

/// Orchestrates weather data fetching and persistence.
///
/// Fetches weather from [WeatherService] and persists it to the dive record
/// via [DiveRepository].
class WeatherRepository {
  final WeatherService _weatherService;
  final DiveRepository _diveRepository;

  WeatherRepository({
    required WeatherService weatherService,
    required DiveRepository diveRepository,
  })  : _weatherService = weatherService,
        _diveRepository = diveRepository;

  /// Fetch weather for a dive and save it to the dive record.
  ///
  /// Respects the overwrite policy: airTemp and surfacePressure are only
  /// populated if they are currently null on the dive.
  ///
  /// Silently returns on any failure (network, API, missing dive).
  Future<void> fetchAndSaveWeather({
    required String diveId,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  }) async {
    try {
      final dive = await _diveRepository.getDiveById(diveId);
      if (dive == null) return;

      final weatherData = await _weatherService.fetchWeather(
        latitude: latitude,
        longitude: longitude,
        date: DateTime(dateTime.year, dateTime.month, dateTime.day),
        entryTime: dateTime,
      );

      if (weatherData == null) return;

      final updatedDive = dive.copyWith(
        windSpeed: weatherData.windSpeed,
        windDirection: weatherData.windDirection,
        cloudCover: weatherData.cloudCover,
        precipitation: weatherData.precipitation,
        humidity: weatherData.humidity,
        weatherDescription: weatherData.description,
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: DateTime.now(),
        // Only populate airTemp/surfacePressure if currently null
        airTemp: dive.airTemp ?? weatherData.airTemp,
        surfacePressure: dive.surfacePressure ?? weatherData.surfacePressure,
      );

      await _diveRepository.updateDive(updatedDive);
    } catch (e) {
      developer.log(
        'Failed to fetch/save weather for dive $diveId: $e',
        name: 'WeatherRepository',
      );
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/weather/data/repositories/weather_repository_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/weather/data/repositories/weather_repository.dart test/features/weather/data/repositories/weather_repository_test.dart
git commit -m "feat: add WeatherRepository for fetch + persist orchestration"
```

---

### Task 9: Create Weather Riverpod Providers

**Files:**
- Create: `lib/features/weather/presentation/providers/weather_providers.dart`

- [ ] **Step 1: Create weather providers**

Create `lib/features/weather/presentation/providers/weather_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/weather/data/repositories/weather_repository.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// HTTP client provider (allows injection for testing)
final weatherHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// WeatherService provider
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final client = ref.watch(weatherHttpClientProvider);
  return WeatherService(client: client);
});

/// WeatherRepository provider
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  final diveRepository = ref.watch(diveRepositoryProvider);
  return WeatherRepository(
    weatherService: weatherService,
    diveRepository: diveRepository,
  );
});

/// State for manual weather fetch operations on the edit page
enum WeatherFetchStatus { idle, loading, success, error }

/// Provider for manual weather fetch state
final weatherFetchStatusProvider =
    StateProvider<WeatherFetchStatus>((ref) => WeatherFetchStatus.idle);

/// Provider for fetching weather data manually (returns WeatherData without saving)
final fetchWeatherProvider = FutureProvider.family<WeatherData?, ({
  double latitude,
  double longitude,
  DateTime date,
  DateTime entryTime,
})>((ref, params) async {
  final service = ref.watch(weatherServiceProvider);
  return service.fetchWeather(
    latitude: params.latitude,
    longitude: params.longitude,
    date: params.date,
    entryTime: params.entryTime,
  );
});
```

- [ ] **Step 2: Verify build compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/weather/presentation/providers/weather_providers.dart
git commit -m "feat: add weather Riverpod providers"
```

---

### Task 10: Add Wind Speed Formatting to UnitFormatter

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart`
- Test: `test/core/utils/unit_formatter_wind_test.dart`

- [ ] **Step 1: Write tests for wind speed formatting**

Create `test/core/utils/unit_formatter_wind_test.dart`. `UnitFormatter` takes an `AppSettings` object. Wind speed unit is derived from depth unit: meters -> km/h (metric), feet -> kts (imperial):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('UnitFormatter wind speed', () {
    late UnitFormatter metricFormatter;
    late UnitFormatter imperialFormatter;

    setUp(() {
      // Metric: defaults are already metric (depth=meters, temp=celsius, etc.)
      metricFormatter = const UnitFormatter(AppSettings());

      // Imperial: override depth to feet (wind unit is derived from depth)
      imperialFormatter = const UnitFormatter(
        AppSettings(depthUnit: DepthUnit.feet),
      );
    });

    test('formatWindSpeed converts m/s to km/h in metric', () {
      // 10 m/s = 36 km/h
      expect(metricFormatter.formatWindSpeed(10.0), '36 km/h');
    });

    test('formatWindSpeed converts m/s to knots in imperial', () {
      // 10 m/s = 19.4 kts -> rounds to 19
      expect(imperialFormatter.formatWindSpeed(10.0), '19 kts');
    });

    test('formatWindSpeed returns -- for null', () {
      expect(metricFormatter.formatWindSpeed(null), '--');
    });

    test('windSpeedSymbol returns km/h for metric', () {
      expect(metricFormatter.windSpeedSymbol, 'km/h');
    });

    test('windSpeedSymbol returns kts for imperial', () {
      expect(imperialFormatter.windSpeedSymbol, 'kts');
    });

    test('convertWindSpeed converts m/s to display unit', () {
      expect(metricFormatter.convertWindSpeed(10.0), closeTo(36.0, 0.01));
      expect(
        imperialFormatter.convertWindSpeed(10.0),
        closeTo(19.44, 0.01),
      );
    });

    test('windSpeedToMs converts display unit back to m/s', () {
      expect(metricFormatter.windSpeedToMs(36.0), closeTo(10.0, 0.01));
      expect(imperialFormatter.windSpeedToMs(19.44), closeTo(10.0, 0.01));
    });
  });
}
```

**Note:** Verify the `AppSettings` constructor accepts these parameters. Check existing tests in `test/core/utils/` for the exact constructor pattern and adjust if needed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/unit_formatter_wind_test.dart`
Expected: Compilation error -- `formatWindSpeed` not defined.

- [ ] **Step 3: Add formatWindSpeed and windSpeedSymbol to UnitFormatter**

In `lib/core/utils/unit_formatter.dart`, add methods following the existing pattern for `formatTemperature`:

```dart
  // ============================================================================
  // Wind Speed
  // ============================================================================

  /// Whether the user prefers metric wind speed (km/h) vs imperial (knots).
  /// Derived from depth unit: meters -> metric, feet -> imperial.
  bool get _isMetricWind => settings.depthUnit == DepthUnit.meters;

  /// Format wind speed from m/s to the user's preferred unit.
  String formatWindSpeed(double? metersPerSecond, {int decimals = 0}) {
    if (metersPerSecond == null) return '--';
    final converted = convertWindSpeed(metersPerSecond);
    return '${converted.toStringAsFixed(decimals)} $windSpeedSymbol';
  }

  /// Convert wind speed from m/s to the user's preferred display unit.
  double convertWindSpeed(double metersPerSecond) {
    return _isMetricWind
        ? metersPerSecond * 3.6 // m/s to km/h
        : metersPerSecond * 1.94384; // m/s to knots
  }

  /// Convert wind speed from the user's display unit back to m/s (for storage).
  double windSpeedToMs(double value) {
    return _isMetricWind ? value / 3.6 : value / 1.94384;
  }

  /// Wind speed unit symbol.
  String get windSpeedSymbol => _isMetricWind ? 'km/h' : 'kts';
```

**Note:** This derives metric/imperial from `settings.depthUnit` to avoid adding a new user-facing setting. This is consistent with how a diver configured for meters/celsius/bar would expect km/h, while one configured for feet/fahrenheit/psi would expect knots.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/unit_formatter_wind_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/unit_formatter.dart test/core/utils/unit_formatter_wind_test.dart
git commit -m "feat: add wind speed formatting to UnitFormatter"
```

---

## Chunk 3: UI -- Edit Page and Detail Page

### Task 11: Update Dive Edit Page -- Environment Section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

This is the largest UI change. The existing `_buildConditionsSection` becomes `_buildEnvironmentSection` with Weather and Dive Conditions sub-headers.

**File size note:** `dive_edit_page.dart` is already 4000+ lines. To keep it manageable, extract the Weather sub-section UI into a private helper method `_buildWeatherFields()` within the same file. If the file exceeds 800 lines of net additions, consider extracting the entire Environment section into a separate widget file `lib/features/dive_log/presentation/widgets/environment_section.dart` as a follow-up.

- [ ] **Step 1: Add imports for weather types**

At the top of `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, add:

```dart
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
```

- [ ] **Step 2: Add weather state fields**

In `_DiveEditPageState` (after the existing conditions fields around line 115), add:

```dart
  // Weather fields
  CurrentDirection? _windDirection;
  CloudCover? _cloudCover;
  Precipitation? _precipitation;
  WeatherSource? _weatherSource;
  DateTime? _weatherFetchedAt;
  final _windSpeedController = TextEditingController();
  final _humidityController = TextEditingController();
  final _weatherDescriptionController = TextEditingController();
  bool _isFetchingWeather = false;
```

- [ ] **Step 3: Initialize weather fields from existing dive**

In the dive initialization block (around line 274, where existing conditions are loaded), add:

```dart
          _windDirection = dive.windDirection;
          _cloudCover = dive.cloudCover;
          _precipitation = dive.precipitation;
          _weatherSource = dive.weatherSource;
          _weatherFetchedAt = dive.weatherFetchedAt;
          _windSpeedController.text = dive.windSpeed != null
              ? units.convertWindSpeed(dive.windSpeed!).toStringAsFixed(1)
              : '';
          _humidityController.text =
              dive.humidity != null ? dive.humidity!.toStringAsFixed(0) : '';
          _weatherDescriptionController.text =
              dive.weatherDescription ?? '';
```

- [ ] **Step 4: Add disposal for new controllers**

In the `dispose` method (around line 396), add:

```dart
    _windSpeedController.dispose();
    _humidityController.dispose();
    _weatherDescriptionController.dispose();
```

- [ ] **Step 5: Rename `_buildConditionsSection` to `_buildEnvironmentSection`**

Rename the method and update the call site (around line 446). Then restructure the method body:

1. Add the card header with "Environment" title and "Fetch Weather" button
2. Add Weather sub-header with fields: Air Temp, Humidity, Wind Speed, Wind Direction, Barometric Pressure, Cloud Cover, Precipitation, Weather Description
3. Add a Divider
4. Add Dive Conditions sub-header with existing fields: Water Temp, Visibility, Water Type, Current Direction, Current Strength, Swell Height, Altitude, Entry Method, Exit Method

Move `airTemp` and `surfacePressure` fields from their current location into the Weather sub-header.

The "Fetch Weather" button handler should:

1. Check prerequisites (date and site with coordinates), disable button if missing
2. If any weather field is already populated, show confirmation dialog before proceeding
3. Set `_isFetchingWeather = true` (button shows spinner)
4. Call `ref.read(weatherServiceProvider).fetchWeather(...)` with site coordinates and dive date
5. On success: populate all weather form fields from the returned `WeatherData`, set `_weatherSource = WeatherSource.openMeteo`, set `_weatherFetchedAt = DateTime.now()`, respect airTemp/surfacePressure overwrite policy (only fill if controller is empty)
6. On failure: show snackbar with appropriate error message
7. Set `_isFetchingWeather = false`

- [ ] **Step 6: Add weather fields to the save method**

In the `_saveDive` method (around line 2985), add weather fields to the Dive constructor:

```dart
        windSpeed: _windSpeedController.text.isNotEmpty
            ? units.windSpeedToMs(double.parse(_windSpeedController.text))
            : null,
        windDirection: _windDirection,
        cloudCover: _cloudCover,
        precipitation: _precipitation,
        humidity: _humidityController.text.isNotEmpty
            ? double.parse(_humidityController.text)
            : null,
        weatherDescription: _weatherDescriptionController.text.isNotEmpty
            ? _weatherDescriptionController.text
            : null,
        weatherSource: _weatherSource,
        weatherFetchedAt: _weatherFetchedAt,
```

**Note:** `_weatherFetchedAt` is initialized from the existing dive (Step 3) and updated to `DateTime.now()` when a manual fetch succeeds (Step 5's "Fetch Weather" button handler). This ensures it tracks when the API data was actually fetched.

- [ ] **Step 7: Verify build compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "feat: replace Conditions with Environment section on dive edit page"
```

---

### Task 12: Update Dive Detail Page -- Environment Section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

- [ ] **Step 1: Update `_hasConditions` to include weather fields**

Rename to `_hasEnvironmentData` and expand:

```dart
  bool _hasEnvironmentData(Dive dive) {
    // Weather fields (moved from details section to Environment)
    return dive.airTemp != null ||
        dive.surfacePressure != null ||
        dive.windSpeed != null ||
        dive.windDirection != null ||
        dive.cloudCover != null ||
        dive.precipitation != null ||
        dive.humidity != null ||
        dive.weatherDescription != null ||
        // Dive condition fields (waterTemp, visibility, waterType in Environment)
        dive.waterTemp != null ||
        dive.visibility != null ||
        dive.waterType != null ||
        dive.currentDirection != null ||
        dive.currentStrength != null ||
        dive.swellHeight != null ||
        dive.entryMethod != null ||
        dive.exitMethod != null;
  }
```

- [ ] **Step 2: Rename `_buildConditionsSection` to `_buildEnvironmentSection`**

Update the method to show two sub-headers:

1. **Weather** sub-header: wind speed, wind direction, cloud cover, precipitation, humidity, weather description, plus "via Open-Meteo" attribution if `weatherSource == WeatherSource.openMeteo`
2. **Dive Conditions** sub-header: existing fields (current direction, current strength, swell height, entry/exit methods)

Move `airTemp` display from the details section into the Weather sub-header. Move `surfacePressure` display into the Weather sub-header.

- [ ] **Step 3: Update call site**

Update the call in the build method (around line 244) from `_buildConditionsSection` to `_buildEnvironmentSection`, and update the `_hasConditions` check to `_hasEnvironmentData`.

- [ ] **Step 4: Verify build compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat: replace Conditions with Environment section on dive detail page"
```

---

### Task 13: Add Auto-Fetch on New Dive Creation

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (or wherever the save-new-dive flow triggers post-save logic)

- [ ] **Step 1: Add auto-fetch after createDive**

In `_saveDive()`, after `notifier.addDive(dive)` returns (around line 3083), add a fire-and-forget call. Use `_selectedSite` from the form state (not `savedDive.site`) because the returned dive object may not have the site pre-loaded with coordinates:

```dart
      } else {
        final savedDive = await notifier.addDive(dive);
        savedDiveId = savedDive.id;

        // Auto-fetch weather for new dives with coordinates
        if (_selectedSite != null &&
            _selectedSite!.hasCoordinates &&
            savedDiveId != null) {
          // Fire and forget -- don't await, don't block save
          ref.read(weatherRepositoryProvider).fetchAndSaveWeather(
            diveId: savedDiveId,
            latitude: _selectedSite!.location!.latitude,
            longitude: _selectedSite!.location!.longitude,
            dateTime: dive.dateTime,
          );
        }
      }
```

**Important:** Use `_selectedSite` (the form's site state) not `savedDive.site`, because `addDive` returns a Dive without preloaded site relations. The `_selectedSite` is available in the `_DiveEditPageState` and was already validated to have coordinates via `hasCoordinates`.

- [ ] **Step 2: Verify build compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "feat: auto-fetch weather on new dive creation"
```

---

## Chunk 4: Export/Import/Sync, Localization, and Cleanup

### Task 14: Update CSV Export

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart`

- [ ] **Step 1: Add weather columns to CSV headers**

In `generateDivesCsvContent`, add after existing headers (around line 142):

```dart
  'Wind Speed (m/s)',
  'Wind Direction',
  'Cloud Cover',
  'Precipitation',
  'Humidity (%)',
  'Weather Description',
```

- [ ] **Step 2: Add weather data to row construction**

In the row data construction (around line 146+), add:

```dart
  dive.windSpeed?.toStringAsFixed(1) ?? '',
  dive.windDirection?.displayName ?? '',
  dive.cloudCover?.displayName ?? '',
  dive.precipitation?.displayName ?? '',
  dive.humidity?.toStringAsFixed(0) ?? '',
  dive.weatherDescription ?? '',
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/export/csv/csv_export_service.dart
git commit -m "feat: add weather columns to CSV export"
```

---

### Task 15: Update Excel Export

**Files:**
- Modify: `lib/core/services/export/excel/excel_export_service.dart`

- [ ] **Step 1: Add weather headers to Excel export**

In `_buildDivesSheet` method (around line 158), add after the `'Notes'` header (line 182):

```dart
      'Wind Speed (m/s)',
      'Wind Direction',
      'Cloud Cover',
      'Precipitation',
      'Humidity (%)',
      'Weather Description',
```

- [ ] **Step 2: Add weather data to Excel row construction**

In `_buildDivesSheet`, add to the `rowData` list (around line 219, after the `dive.notes` line):

```dart
        dive.windSpeed?.toStringAsFixed(1) ?? '',
        dive.windDirection?.displayName ?? '',
        dive.cloudCover?.displayName ?? '',
        dive.precipitation?.displayName ?? '',
        dive.humidity?.toStringAsFixed(0) ?? '',
        dive.weatherDescription ?? '',
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/export/excel/excel_export_service.dart
git commit -m "feat: add weather columns to Excel export"
```

---

### Task 16: Update Sync Serializer

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`

- [ ] **Step 1: Add weather fields to serialization**

In the dive serialization map (around line 1481, after `waterType`), add:

```dart
    'windSpeed': r.windSpeed,
    'windDirection': r.windDirection,
    'cloudCover': r.cloudCover,
    'precipitation': r.precipitation,
    'humidity': r.humidity,
    'weatherDescription': r.weatherDescription,
    'weatherSource': r.weatherSource,
    'weatherFetchedAt': r.weatherFetchedAt,
```

- [ ] **Step 2: Verify deserialization handles new columns automatically**

Deserialization uses Drift's generated `Dive.fromJson(data)` (see line 643 of `sync_data_serializer.dart`). After running `build_runner` in Task 4, the generated `Dive.fromJson` will automatically include the new columns (`windSpeed`, `windDirection`, `cloudCover`, etc.) because they are now part of the Dives table schema. No manual deserialization code is needed -- Drift handles it.

Verify by checking that the generated `database.g.dart` includes the new columns in the `Dive.fromJson` factory method after codegen.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart
git commit -m "feat: add weather fields to sync serializer"
```

---

### Task 17: Update UDDF Export

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`

- [ ] **Step 1: Add weather data to UDDF dive element**

In `buildDiveElement`, inside the `informationbeforedive` element (around line 132), after the existing `atmosphericpressure` element, add weather fields as custom extension elements. These are not part of the UDDF standard schema but follow the same pattern used for other non-standard elements (e.g., `divenumber`, `entrytime`) already in the codebase:

```dart
// Custom weather extension elements (not UDDF standard, but consistent
// with existing custom elements in informationbeforedive)
if (dive.windSpeed != null) {
  builder.element('windspeed', nest: dive.windSpeed!.toStringAsFixed(1));
}
if (dive.windDirection != null) {
  builder.element('winddirection', nest: dive.windDirection!.name);
}
if (dive.cloudCover != null) {
  builder.element('cloudcover', nest: dive.cloudCover!.name);
}
if (dive.precipitation != null && dive.precipitation != Precipitation.none) {
  builder.element('precipitation', nest: dive.precipitation!.name);
}
if (dive.humidity != null) {
  builder.element('humidity', nest: dive.humidity!.toStringAsFixed(0));
}
if (dive.weatherDescription != null) {
  builder.element('weatherdescription', nest: dive.weatherDescription!);
}
```

**Note:** UDDF does not define standard weather elements. These custom elements are placed inside `informationbeforedive`, consistent with how the existing codebase handles non-standard fields. Other UDDF-consuming software will simply ignore unknown elements.

- [ ] **Step 2: Commit**

```bash
git add lib/core/services/export/uddf/uddf_export_builders.dart
git commit -m "feat: add weather fields to UDDF export"
```

---

### Task 18: Update Universal Import Field Mapping

**Files:**
- Modify: `lib/features/universal_import/data/services/field_mapping_engine.dart`
- Modify: `lib/features/universal_import/data/parsers/csv_import_parser.dart`

- [ ] **Step 1: Add weather field mappings to generic auto-map**

In `_guessTargetField` (or equivalent method), add keyword matching for weather fields:

```dart
if (header.contains('wind') && header.contains('speed')) return 'windSpeed';
if (header.contains('wind') && header.contains('dir')) return 'windDirection';
if (header.contains('cloud')) return 'cloudCover';
if (header.contains('precip')) return 'precipitation';
if (header.contains('humid')) return 'humidity';
if (header.contains('weather') && header.contains('desc')) return 'weatherDescription';
```

- [ ] **Step 2: Add weather fields to Submersion preset**

In `_submersionPreset` (or whatever the self-import preset is), add:

```dart
ColumnMapping(sourceColumn: 'Wind Speed (m/s)', targetField: 'windSpeed'),
ColumnMapping(sourceColumn: 'Wind Direction', targetField: 'windDirection'),
ColumnMapping(sourceColumn: 'Cloud Cover', targetField: 'cloudCover'),
ColumnMapping(sourceColumn: 'Precipitation', targetField: 'precipitation'),
ColumnMapping(sourceColumn: 'Humidity (%)', targetField: 'humidity'),
ColumnMapping(sourceColumn: 'Weather Description', targetField: 'weatherDescription'),
```

- [ ] **Step 3: Add weather field parsing to CSV import parser**

In `csv_import_parser.dart`, add `'windSpeed'` and `'humidity'` to the numeric parsing switch case (around line 261):

```dart
      'windSpeed' ||
      'humidity' => double.tryParse(rawValue),
```

Add string fields (`windDirection`, `cloudCover`, `precipitation`, `weatherDescription`) to the string pass-through, or handle them like existing enum string fields.

**Note:** There is no separate `csv_import_service.dart` -- all CSV import parsing goes through `csv_import_parser.dart` (handled above) and `field_mapping_engine.dart` (Step 1-2). The universal import wizard handles the rest via its existing generic mapping infrastructure.

- [ ] **Step 4: Commit**

```bash
git add lib/features/universal_import/data/services/field_mapping_engine.dart lib/features/universal_import/data/parsers/csv_import_parser.dart
git commit -m "feat: add weather fields to universal import mapping"
```

---

### Task 19: Add Localization Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add weather localization strings**

Add to `app_en.arb` near the existing conditions strings:

```json
  "diveLog_edit_section_environment": "Environment",
  "diveLog_edit_subsection_weather": "Weather",
  "diveLog_edit_subsection_diveConditions": "Dive Conditions",
  "diveLog_edit_label_windSpeed": "Wind Speed",
  "diveLog_edit_label_windDirection": "Wind Direction",
  "diveLog_edit_label_cloudCover": "Cloud Cover",
  "diveLog_edit_label_precipitation": "Precipitation",
  "diveLog_edit_label_humidity": "Humidity",
  "diveLog_edit_label_weatherDescription": "Weather Description",
  "diveLog_edit_button_fetchWeather": "Fetch Weather",
  "diveLog_edit_fetchingWeather": "Fetching weather...",
  "diveLog_edit_weatherFetched": "Weather data loaded",
  "diveLog_edit_fetchWeatherNoConnection": "No internet connection",
  "diveLog_edit_fetchWeatherUnavailable": "Weather data unavailable for this date",
  "diveLog_edit_fetchWeatherNotYetAvailable": "Weather data not yet available for this date",
  "diveLog_edit_fetchWeatherHint": "Add a date and dive site first",
  "diveLog_edit_fetchWeatherConfirm": "Replace existing weather data with fetched data?",
  "diveLog_detail_section_environment": "Environment",
  "diveLog_detail_subsection_weather": "Weather",
  "diveLog_detail_subsection_diveConditions": "Dive Conditions",
  "diveLog_detail_label_windSpeed": "Wind Speed",
  "diveLog_detail_label_windDirection": "Wind Direction",
  "diveLog_detail_label_cloudCover": "Cloud Cover",
  "diveLog_detail_label_precipitation": "Precipitation",
  "diveLog_detail_label_humidity": "Humidity",
  "diveLog_detail_label_weatherDescription": "Description",
  "diveLog_detail_weatherSourceOpenMeteo": "via Open-Meteo",
  "enum_cloudCover_clear": "Clear",
  "enum_cloudCover_partlyCloudy": "Partly Cloudy",
  "enum_cloudCover_mostlyCloudy": "Mostly Cloudy",
  "enum_cloudCover_overcast": "Overcast",
  "enum_precipitation_none": "None",
  "enum_precipitation_drizzle": "Drizzle",
  "enum_precipitation_lightRain": "Light Rain",
  "enum_precipitation_rain": "Rain",
  "enum_precipitation_heavyRain": "Heavy Rain",
  "enum_precipitation_snow": "Snow",
  "enum_precipitation_sleet": "Sleet",
  "enum_precipitation_hail": "Hail",
```

**Note:** The enum `displayName` getters in the Dart enums return hardcoded English strings. These localization keys enable translated display names in the UI. When rendering enum values in the UI, use `AppLocalizations.of(context)!.enum_cloudCover_clear` (or a helper) instead of `cloudCover.displayName` for proper localization.

- [ ] **Step 2: Add keys to non-English ARB files**

Add the same keys to all 9 non-English ARB files with English values as placeholders. The files are:
- `lib/l10n/arb/app_ar.arb`
- `lib/l10n/arb/app_de.arb`
- `lib/l10n/arb/app_es.arb`
- `lib/l10n/arb/app_fr.arb`
- `lib/l10n/arb/app_he.arb`
- `lib/l10n/arb/app_hu.arb`
- `lib/l10n/arb/app_it.arb`
- `lib/l10n/arb/app_nl.arb`
- `lib/l10n/arb/app_pt.arb`

Use the English values as placeholders (they will be translated later). This prevents missing key errors at runtime.

- [ ] **Step 3: Run localization generation**

Run: `flutter gen-l10n` (or whatever command the project uses to regenerate localization files)
Expected: Updated `app_localizations.dart` and per-language files. No missing key errors.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add weather localization strings"
```

---

### Task 20: Format and Final Verification

- [ ] **Step 1: Format all modified code**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Final commit if formatting changed anything**

```bash
git add -A
git commit -m "chore: formatting"
```
