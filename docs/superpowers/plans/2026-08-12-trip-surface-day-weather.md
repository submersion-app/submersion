# Trip Surface-Day Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show fetched historical weather on true trip surface-day headers using the same icon and unit-aware temperature badge as dive days.

**Architecture:** Keep trip-story composition synchronous and render headers immediately. The story view selects the nearest existing trip map point for each surface day and passes an immutable request to a cached Riverpod family provider; that provider asks the existing Open-Meteo service for local-noon weather and returns the compact `TripStoryDayWeather` already consumed by the header.

**Tech Stack:** Flutter, Dart, Riverpod, `http`, Open-Meteo Historical Weather API, `flutter_test`

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-surface-day-weather` on `codex/trip-surface-day-weather`.
- No database migration, trip-day weather entity, sync changes, or offline persistence.
- No copying or interpolating weather values from adjacent dives.
- Fetch only for `TripStoryDay.isSurface`; a dive day with missing logged weather must not fetch.
- Use the nearest existing trip map point, preserving route order for equidistant ties.
- Request 12:00 on the surface date with Open-Meteo `timezone=auto`.
- Loading, missing-location, unavailable-weather, and request failures render no placeholder or error and cannot block the trip story.
- Reuse the existing badge's icon precedence, semantics, typography, and active-diver temperature conversion.
- Keep the existing dive-edit weather request URL unchanged unless a caller explicitly opts into location-local time.
- Write every production change only after its focused test has failed for the expected missing behavior.
- Run `dart format` on every changed Dart file.

## File Structure

- Modify `lib/features/trips/domain/entities/trip_story_day.dart`: pure nearest-point selection.
- Modify `lib/features/weather/data/services/weather_service.dart`: opt-in `timezone=auto`.
- Create `lib/features/trips/presentation/providers/surface_day_weather_provider.dart`: request/cache key and weather mapping.
- Modify `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`: select logged or fetched weather.
- Modify `lib/features/trips/presentation/widgets/story/trip_story_view.dart`: pass the nearest-coordinate request to surface headers.
- Modify the matching tests under `test/features/trips/` and `test/features/weather/`; create a focused provider test.

---

### Task 1: Select the nearest trip map point

**Files:**
- Modify: `lib/features/trips/domain/entities/trip_story_day.dart`
- Test: `test/features/trips/domain/entities/trip_story_day_test.dart`

**Interfaces:**
- Consumes: `TripStoryMapGeometry.points` and an integer story-day index.
- Produces: `TripStoryMapPoint? TripStoryMapGeometry.nearestPointForDay(int dayIndex)`.

- [ ] **Step 1: Write the failing tests**

Add these cases to the existing `TripStoryMapGeometry` group. They catch selecting the wrong day, replacing the stable tie with a later point, and returning a value for empty geometry.

```dart
test('nearestPointForDay returns a point on the requested day', () {
  const geometry = TripStoryMapGeometry(
    points: [
      TripStoryMapPoint(latitude: 1, longitude: 2, dayIndex: 0, label: 'A'),
      TripStoryMapPoint(latitude: 3, longitude: 4, dayIndex: 2, label: 'B'),
    ],
  );
  expect(geometry.nearestPointForDay(2)?.label, 'B');
});

test('nearestPointForDay uses the closest point at trip boundaries', () {
  const geometry = TripStoryMapGeometry(
    points: [
      TripStoryMapPoint(latitude: 1, longitude: 2, dayIndex: 2, label: 'First'),
      TripStoryMapPoint(latitude: 3, longitude: 4, dayIndex: 4, label: 'Last'),
    ],
  );
  expect(geometry.nearestPointForDay(0)?.label, 'First');
  expect(geometry.nearestPointForDay(7)?.label, 'Last');
});

test('nearestPointForDay preserves route order for an equidistant tie', () {
  const geometry = TripStoryMapGeometry(
    points: [
      TripStoryMapPoint(latitude: 1, longitude: 2, dayIndex: 0, label: 'Prior'),
      TripStoryMapPoint(latitude: 3, longitude: 4, dayIndex: 2, label: 'Next'),
    ],
  );
  expect(geometry.nearestPointForDay(1)?.label, 'Prior');
});

test('nearestPointForDay returns null for empty geometry', () {
  const geometry = TripStoryMapGeometry(points: []);
  expect(geometry.nearestPointForDay(1), isNull);
});
```

- [ ] **Step 2: Run the test and verify RED**

```bash
flutter test test/features/trips/domain/entities/trip_story_day_test.dart
```

Expected: compilation fails because `nearestPointForDay` does not exist.

- [ ] **Step 3: Add the minimal stable scan**

```dart
TripStoryMapPoint? nearestPointForDay(int dayIndex) {
  TripStoryMapPoint? nearest;
  int? nearestDistance;
  for (final point in points) {
    final distance = (point.dayIndex - dayIndex).abs();
    if (nearestDistance == null || distance < nearestDistance) {
      nearest = point;
      nearestDistance = distance;
    }
  }
  return nearest;
}
```

The strict `<` preserves the first route point on a tie.

- [ ] **Step 4: Format and verify GREEN**

```bash
dart format lib/features/trips/domain/entities/trip_story_day.dart test/features/trips/domain/entities/trip_story_day_test.dart
flutter test test/features/trips/domain/entities/trip_story_day_test.dart
```

Expected: every test in the file passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/entities/trip_story_day.dart test/features/trips/domain/entities/trip_story_day_test.dart
git commit -m "feat(trips): resolve nearest story day location"
```

---

### Task 2: Opt surface requests into location-local time

**Files:**
- Modify: `lib/features/weather/data/services/weather_service.dart`
- Test: `test/features/weather/data/services/weather_service_test.dart`

**Interfaces:**
- Consumes: existing `WeatherService.fetchWeather` arguments plus `bool useLocationTimezone = false`.
- Produces: the same `Future<WeatherData?>`; opted-in URLs contain `timezone=auto`.

- [ ] **Step 1: Protect the default URL and add the failing opt-in test**

Add `expect(request.url.queryParameters['timezone'], isNull);` to the existing success callback. Then add:

```dart
test('fetchWeather can request the coordinate local timezone', () async {
  final mockClient = MockClient((request) async {
    expect(request.url.queryParameters['timezone'], 'auto');
    return http.Response(
      jsonEncode({
        'hourly': {
          'time': ['2024-06-15T12:00'],
          'temperature_2m': [28.0],
          'relative_humidity_2m': [70.0],
          'precipitation': [0.0],
          'cloud_cover': [20.0],
          'wind_speed_10m': [14.0],
          'wind_direction_10m': [50.0],
          'surface_pressure': [1014.0],
          'weathercode': [0],
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
    entryTime: DateTime(2024, 6, 15, 12),
    useLocationTimezone: true,
  );
  expect(result?.airTemp, 28.0);
});
```

- [ ] **Step 2: Run the test and verify RED**

```bash
flutter test test/features/weather/data/services/weather_service_test.dart
```

Expected: compilation fails because `useLocationTimezone` is not a named parameter.

- [ ] **Step 3: Add the optional flag and query entry**

```dart
Future<WeatherData?> fetchWeather({
  required double latitude,
  required double longitude,
  required DateTime date,
  required DateTime entryTime,
  bool useLocationTimezone = false,
}) async {
```

```dart
final uri = Uri.https(_baseUrl, _path, {
  'latitude': latitude.toString(),
  'longitude': longitude.toString(),
  'start_date': dateStr,
  'end_date': dateStr,
  'hourly': _hourlyParams,
  if (useLocationTimezone) 'timezone': 'auto',
});
```

Document that the flag requests coordinate-local hourly timestamps; default callers retain GMT behavior.

- [ ] **Step 4: Format and verify GREEN**

```bash
dart format lib/features/weather/data/services/weather_service.dart test/features/weather/data/services/weather_service_test.dart
flutter test test/features/weather/data/services/weather_service_test.dart
```

Expected: every service test passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/weather/data/services/weather_service.dart test/features/weather/data/services/weather_service_test.dart
git commit -m "feat(weather): support location local archive hours"
```

---

### Task 3: Fetch and cache compact surface-day weather

**Files:**
- Create: `lib/features/trips/presentation/providers/surface_day_weather_provider.dart`
- Create: `test/features/trips/presentation/providers/surface_day_weather_provider_test.dart`

**Interfaces:**
- Consumes: `SurfaceDayWeatherRequest(date, latitude, longitude)` and `weatherServiceProvider`.
- Produces: `surfaceDayWeatherProvider`, a non-auto-dispose `FutureProvider.family<TripStoryDayWeather?, SurfaceDayWeatherRequest>`.

- [ ] **Step 1: Create the failing provider test**

Use a literal Open-Meteo response with 09:00 and 12:00 entries. The first test proves local noon is selected and mapped, the second proves equal family keys make one HTTP call, and the third proves service failure becomes null.

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/surface_day_weather_provider.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

http.Response weatherResponse() => http.Response(
  jsonEncode({
    'hourly': {
      'time': ['2024-06-15T09:00', '2024-06-15T12:00'],
      'temperature_2m': [24.0, 29.0],
      'relative_humidity_2m': [80.0, 70.0],
      'precipitation': [0.0, 1.0],
      'cloud_cover': [10.0, 95.0],
      'wind_speed_10m': [8.0, 12.0],
      'wind_direction_10m': [30.0, 45.0],
      'surface_pressure': [1012.0, 1011.0],
      'weathercode': [0, 61],
    },
  }),
  200,
);

void main() {
  final request = SurfaceDayWeatherRequest(
    date: DateTime(2024, 6, 15),
    latitude: 12.1,
    longitude: -68.2,
  );

  test('fetches local noon and maps compact trip weather', () async {
    final client = MockClient((http.Request httpRequest) async {
      expect(httpRequest.url.queryParameters['timezone'], 'auto');
      expect(httpRequest.url.queryParameters['start_date'], '2024-06-15');
      return weatherResponse();
    });
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final weather = await container.read(
      surfaceDayWeatherProvider(request).future,
    );
    expect(
      weather,
      const TripStoryDayWeather(
        airTemp: 29,
        cloudCover: CloudCover.overcast,
        precipitation: Precipitation.rain,
      ),
    );
  });

  test('caches one request for an equal family key', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return weatherResponse();
    });
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container.read(surfaceDayWeatherProvider(request).future);
    await container.read(
      surfaceDayWeatherProvider(
        SurfaceDayWeatherRequest(
          date: DateTime(2024, 6, 15),
          latitude: 12.1,
          longitude: -68.2,
        ),
      ).future,
    );
    expect(calls, 1);
  });

  test('propagates unavailable weather as null', () async {
    final client = MockClient((_) async => http.Response('', 500));
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(surfaceDayWeatherProvider(request).future),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run the provider test and verify RED**

```bash
flutter test test/features/trips/presentation/providers/surface_day_weather_provider_test.dart
```

Expected: compilation fails because the provider file, request type, and family do not exist.

- [ ] **Step 3: Implement the request and provider**

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

class SurfaceDayWeatherRequest extends Equatable {
  final DateTime date;
  final double latitude;
  final double longitude;

  const SurfaceDayWeatherRequest({
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  DateTime get localNoon => DateTime(date.year, date.month, date.day, 12);

  @override
  List<Object?> get props => [date, latitude, longitude];
}

final surfaceDayWeatherProvider =
    FutureProvider.family<TripStoryDayWeather?, SurfaceDayWeatherRequest>((
      ref,
      request,
    ) async {
      final weather = await ref.watch(weatherServiceProvider).fetchWeather(
        latitude: request.latitude,
        longitude: request.longitude,
        date: DateTime(request.date.year, request.date.month, request.date.day),
        entryTime: request.localNoon,
        useLocationTimezone: true,
      );
      if (weather == null) return null;
      return TripStoryDayWeather(
        airTemp: weather.airTemp,
        cloudCover: weather.cloudCover,
        precipitation: weather.precipitation,
      );
    });
```

Do not use `.autoDispose`; cached results must survive sliver unmount/remount.

- [ ] **Step 4: Format and verify GREEN**

```bash
dart format lib/features/trips/presentation/providers/surface_day_weather_provider.dart test/features/trips/presentation/providers/surface_day_weather_provider_test.dart
flutter test test/features/trips/presentation/providers/surface_day_weather_provider_test.dart
```

Expected: all three provider tests pass and the cache test observes one call.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/providers/surface_day_weather_provider.dart test/features/trips/presentation/providers/surface_day_weather_provider_test.dart
git commit -m "feat(trips): fetch surface day weather"
```

---

### Task 4: Render fetched weather through the existing badge

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`

**Interfaces:**
- Consumes: optional `SurfaceDayWeatherRequest? surfaceWeatherRequest`.
- Produces: unchanged header presentation, with fetched weather used only when `day.isSurface`.

- [ ] **Step 1: Extend the harness and write failing widget tests**

Add `dart:async`, Riverpod `Override`, and the new provider imports. Extend `pumpHeader` with `SurfaceDayWeatherRequest? surfaceWeatherRequest` and `List<Override> extra = const []`; append `extra` to the overrides and pass the request into `TripStoryDayHeader`.

Use this request:

```dart
final request = SurfaceDayWeatherRequest(
  date: DateTime(2026, 3, 8),
  latitude: 12.1,
  longitude: -68.2,
);
```

Add:

```dart
testWidgets('surface day shows fetched weather in the existing badge', (
  tester,
) async {
  await pumpHeader(
    tester,
    surfaceDay(),
    surfaceWeatherRequest: request,
    extra: [
      surfaceDayWeatherProvider(request).overrideWith(
        (ref) async => const TripStoryDayWeather(
          airTemp: 22,
          cloudCover: CloudCover.clear,
        ),
      ),
    ],
  );
  await tester.pump();
  expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
  expect(find.text('22°C'), findsOneWidget);
});

testWidgets('fetched surface temperature respects Fahrenheit', (
  tester,
) async {
  final settings = MockSettingsNotifier();
  await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
  await pumpHeader(
    tester,
    surfaceDay(),
    settingsNotifier: settings,
    surfaceWeatherRequest: request,
    extra: [
      surfaceDayWeatherProvider(request).overrideWith(
        (ref) async => const TripStoryDayWeather(airTemp: 22),
      ),
    ],
  );
  await tester.pump();
  expect(find.text('71.6°F'), findsOneWidget);
});

testWidgets('loading and failed surface weather stay badge-free', (
  tester,
) async {
  final pending = Completer<TripStoryDayWeather?>();
  await pumpHeader(
    tester,
    surfaceDay(),
    surfaceWeatherRequest: request,
    extra: [
      surfaceDayWeatherProvider(request).overrideWith((ref) => pending.future),
    ],
  );
  expect(find.textContaining('°'), findsNothing);
  expect(find.byType(CircularProgressIndicator), findsNothing);

  pending.completeError(Exception('weather unavailable'));
  await tester.pump();
  expect(find.textContaining('°'), findsNothing);
  expect(find.byType(CircularProgressIndicator), findsNothing);
});

testWidgets('surface day without a request stays badge-free', (tester) async {
  await pumpHeader(tester, surfaceDay());
  expect(find.textContaining('°'), findsNothing);
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

- [ ] **Step 2: Run the header test and verify RED**

```bash
flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
```

Expected: compilation fails because the header has no `surfaceWeatherRequest` parameter.

- [ ] **Step 3: Watch surface weather and reuse one badge builder**

Add the field and constructor parameter:

```dart
final SurfaceDayWeatherRequest? surfaceWeatherRequest;

const TripStoryDayHeader({
  super.key,
  required this.day,
  this.surfaceWeatherRequest,
});
```

In `build`:

```dart
final request = day.isSurface ? surfaceWeatherRequest : null;
final fetchedWeather = request == null
    ? null
    : ref.watch(surfaceDayWeatherProvider(request)).asData?.value;
final weather = day.weather ?? fetchedWeather;
final units = UnitFormatter(ref.watch(settingsProvider));
final weatherBadge = _weatherBadge(context, theme, units, weather);
```

Change `_weatherBadge` to accept `TripStoryDayWeather? weather` and remove its internal `final weather = day.weather;`. Leave its current icon, semantic label, formatter, style, and null checks intact.

- [ ] **Step 4: Format and verify GREEN**

```bash
dart format lib/features/trips/presentation/widgets/story/trip_story_day_header.dart test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
```

Expected: existing dive-weather tests and all new surface-weather tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/trip_story_day_header.dart test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
git commit -m "feat(trips): show weather on surface day headers"
```

---

### Task 5: Wire surface headers to nearest story coordinates

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: `TripStory.mapGeometry.nearestPointForDay(index)`.
- Produces: a `SurfaceDayWeatherRequest` passed only to a surface day's `TripStoryDayHeader`.

- [ ] **Step 1: Add the failing story-view integration test**

Import `dart:convert`, `http`, and `MockClient`. Extend `pumpView` with `http.Client? weatherHttpClient` and pass it to `getBaseOverrides(weatherHttpClient: weatherHttpClient)`.

Add this regression test. The one-call assertion catches accidental dive-day fetching; the coordinates catch choosing the later point in the middle-day tie.

```dart
testWidgets('only the surface day fetches from the nearest trip point', (
  tester,
) async {
  final trip = _trip(
    start: DateTime(2026, 3, 25),
    end: DateTime(2026, 3, 27),
  );
  final story = _story(
    trip,
    dives: [
      _diveAt('d1', DateTime(2026, 3, 25, 9), 12.10, -68.20),
      _diveAt('d3', DateTime(2026, 3, 27, 9), 13.30, -69.40),
    ],
    today: DateTime(2026, 6, 1),
  );
  var calls = 0;
  final client = MockClient((request) async {
    calls++;
    expect(request.url.queryParameters['latitude'], '12.1');
    expect(request.url.queryParameters['longitude'], '-68.2');
    expect(request.url.queryParameters['start_date'], '2026-03-26');
    expect(request.url.queryParameters['timezone'], 'auto');
    return http.Response(
      jsonEncode({
        'hourly': {
          'time': ['2026-03-26T12:00'],
          'temperature_2m': [26.0],
          'relative_humidity_2m': [70.0],
          'precipitation': [0.0],
          'cloud_cover': [10.0],
          'wind_speed_10m': [8.0],
          'wind_direction_10m': [30.0],
          'surface_pressure': [1012.0],
          'weathercode': [0],
        },
      }),
      200,
    );
  });

  await pumpView(tester, story, weatherHttpClient: client);
  await tester.pump();

  expect(calls, 1);
  expect(find.text('26°C'), findsOneWidget);
});
```

- [ ] **Step 2: Run the view test and verify RED**

```bash
flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart
```

Expected: the call count is zero and `26°C` is absent because the view passes no request.

- [ ] **Step 3: Resolve and pass the request in `_daySliver`**

Import the surface weather provider. After reading `day`, add:

```dart
final weatherPoint = day.isSurface
    ? story.mapGeometry.nearestPointForDay(index)
    : null;
final surfaceWeatherRequest = weatherPoint == null
    ? null
    : SurfaceDayWeatherRequest(
        date: day.date,
        latitude: weatherPoint.latitude,
        longitude: weatherPoint.longitude,
      );
```

Pass it to the pinned header:

```dart
PinnedHeaderSliver(
  child: TripStoryDayHeader(
    day: day,
    surfaceWeatherRequest: surfaceWeatherRequest,
  ),
),
```

- [ ] **Step 4: Format and run the focused suite**

```bash
dart format lib/features/trips/presentation/widgets/story/trip_story_view.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart
flutter test \
  test/features/trips/domain/entities/trip_story_day_test.dart \
  test/features/weather/data/services/weather_service_test.dart \
  test/features/trips/presentation/providers/surface_day_weather_provider_test.dart \
  test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart \
  test/features/trips/presentation/widgets/story/trip_story_view_test.dart
```

Expected: all focused tests pass. The pre-existing `flutter_map` OpenStreetMap policy message may appear; no new warning or exception may appear.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/trip_story_view.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "feat(trips): wire surface weather to trip location"
```

---

### Task 6: Final verification

**Files:**
- Verify all production and test files changed in Tasks 1-5.

**Interfaces:**
- Consumes: the complete branch.
- Produces: formatted, analyzed, fully tested implementation with a clean worktree.

- [ ] **Step 1: Verify formatting and patch hygiene**

```bash
dart format --set-exit-if-changed \
  lib/features/trips/domain/entities/trip_story_day.dart \
  lib/features/weather/data/services/weather_service.dart \
  lib/features/trips/presentation/providers/surface_day_weather_provider.dart \
  lib/features/trips/presentation/widgets/story/trip_story_day_header.dart \
  lib/features/trips/presentation/widgets/story/trip_story_view.dart \
  test/features/trips/domain/entities/trip_story_day_test.dart \
  test/features/weather/data/services/weather_service_test.dart \
  test/features/trips/presentation/providers/surface_day_weather_provider_test.dart \
  test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart \
  test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git diff --check origin/main...HEAD
```

Expected: both commands exit 0 without formatting changes or whitespace errors.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze
```

Expected: exit 0 with no issues introduced by the branch.

- [ ] **Step 3: Run the full test suite**

```bash
flutter test
```

Expected: exit 0 with all tests passing.

- [ ] **Step 4: Review the final diff against the spec**

```bash
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- lib/features/trips lib/features/weather test/features/trips test/features/weather
```

Confirm all of the following from the diff and test output:

- only surface days construct a weather request;
- nearest-point ties preserve route order;
- the request targets local noon with `timezone=auto`;
- non-surface weather callers retain their previous URL;
- loading, error, and missing location show no UI;
- no database, sync, localization, or persistence file changed.

- [ ] **Step 5: Confirm branch status**

```bash
git status --short --branch
git log --oneline --decorate origin/main..HEAD
```

Expected: the worktree is clean on `codex/trip-surface-day-weather`, and the log contains the design plus focused implementation commits.
