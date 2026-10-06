# Conditions Weather Placement and Altitude Auto-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the dive edit form's weather fetch action to the top of the Conditions section and auto-fill altitude from the dive's logged GPS, the site's stored altitude, or an elevation API lookup (with site write-back).

**Architecture:** A new `ElevationService` (Open-Meteo elevation API, mirroring `WeatherService`) feeds an `AltitudeResolver` that encodes one precedence rule: dive GPS lookup, then `site.altitude`, then site-coords lookup with write-back. Explicit call sites use it: the dive edit page (load / site assign / fetch retry), the site edit page (coordinate changes), and a `DiveAltitudeEnricher` on the four import/download persistence seams.

**Tech Stack:** Flutter, Riverpod, Drift, `package:http` (+ `package:http/testing.dart` MockClient in tests), Open-Meteo elevation API.

**Spec:** `docs/superpowers/specs/2026-08-06-conditions-weather-altitude-design.md`

## Global Constraints

- Run all commands from the worktree root: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/conditions-weather-altitude` (branch `feature/conditions-weather-altitude`).
- `dart format .` must produce no changes before every commit (format the whole project, not just changed files).
- `flutter analyze` (whole project) must be clean — infos are CI-fatal.
- Never pipe `flutter analyze` or `flutter test` through `| tail` or similar — it masks failures.
- No emojis anywhere. No console prints; use `dart:developer` `log` like `WeatherService` does.
- Anything displaying units must respect diver unit settings: altitude is stored in meters, displayed via `UnitFormatter.convertAltitude` / parsed via `altitudeToMeters`.
- New l10n strings go in ALL 11 arb files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`) followed by `flutter gen-l10n`.
- Elevation values: clamp negatives to 0, round to whole meters; 0 is a valid stored value.
- Auto-fill only ever writes an EMPTY altitude field; manual entry always wins.
- Commit at the end of each task (plan-approved commits are pre-authorized on this feature branch).

---

### Task 1: ElevationService and provider

**Files:**
- Create: `lib/features/weather/data/services/elevation_service.dart`
- Modify: `lib/features/weather/presentation/providers/weather_providers.dart`
- Test: `test/features/weather/data/services/elevation_service_test.dart`

**Interfaces:**
- Consumes: nothing new (mirrors `WeatherService` in the same directory).
- Produces: `class ElevationService { ElevationService({http.Client? client}); Future<double?> fetchElevation({required double latitude, required double longitude}); }` and `final elevationServiceProvider = Provider<ElevationService>` in `weather_providers.dart`. Later tasks read `ref.read(elevationServiceProvider)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/weather/data/services/elevation_service_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

void main() {
  group('ElevationService', () {
    test('returns elevation on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/elevation');
        expect(request.url.queryParameters['latitude'], '46.4');
        expect(request.url.queryParameters['longitude'], '8.0');
        return http.Response(
          jsonEncode({
            'elevation': [740.2],
          }),
          200,
        );
      });

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(
        latitude: 46.4,
        longitude: 8.0,
      );

      expect(result, 740.0);
    });

    test('rounds to the nearest whole meter', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'elevation': [12.6],
          }),
          200,
        ),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, 13.0);
    });

    test('clamps negative elevations to zero', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'elevation': [-4.0],
          }),
          200,
        ),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 27.9, longitude: -15.4);

      expect(result, 0.0);
    });

    test('returns null on non-200 response', () async {
      final mockClient = MockClient((_) async => http.Response('oops', 500));

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null on malformed body', () async {
      final mockClient = MockClient(
        (_) async => http.Response('not json', 200),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null when elevation list is empty', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'elevation': <double>[]}), 200),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null when the request times out', () async {
      final mockClient = MockClient(
        (_) async => throw TimeoutException('timed out'),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/weather/data/services/elevation_service_test.dart`
Expected: FAIL — `elevation_service.dart` does not exist (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/weather/data/services/elevation_service.dart`:

```dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// HTTP client for the Open-Meteo Elevation API.
///
/// Returns ground elevation in meters above sea level, or null on any
/// failure (network, API error, malformed response). Never throws.
class ElevationService {
  final http.Client _client;

  static const _baseUrl = 'api.open-meteo.com';
  static const _path = '/v1/elevation';
  static const _timeout = Duration(seconds: 5);

  ElevationService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch ground elevation for a coordinate pair.
  ///
  /// Negative results (offshore grid cells) clamp to 0; values round to the
  /// nearest whole meter so a stored 0 always means sea level.
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https(_baseUrl, _path, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        developer.log(
          'Elevation API error: ${response.statusCode}',
          name: 'ElevationService',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final values = json['elevation'] as List<dynamic>?;
      if (values == null || values.isEmpty) return null;
      final raw = (values.first as num).toDouble();
      return raw < 0 ? 0.0 : raw.roundToDouble();
    } catch (e) {
      developer.log('Elevation fetch failed: $e', name: 'ElevationService');
      return null;
    }
  }
}
```

Then add the provider to `lib/features/weather/presentation/providers/weather_providers.dart`, directly after `weatherServiceProvider` (add the import `package:submersion/features/weather/data/services/elevation_service.dart` to the import block):

```dart
/// ElevationService provider
final elevationServiceProvider = Provider<ElevationService>((ref) {
  final client = ref.watch(weatherHttpClientProvider);
  return ElevationService(client: client);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/weather/data/services/elevation_service_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/weather test/features/weather
git commit -m "Add ElevationService for Open-Meteo elevation lookups"
```

---

### Task 2: AltitudeResolver

**Files:**
- Create: `lib/features/weather/domain/services/altitude_resolver.dart`
- Test: `test/features/weather/domain/services/altitude_resolver_test.dart`

**Interfaces:**
- Consumes: `ElevationService.fetchElevation` (Task 1), `GeoPoint(latitude, longitude)` and `DiveSite` (fields `altitude`, `location`, `copyWith`) from `lib/features/dive_sites/domain/entities/dive_site.dart`.
- Produces:
  - `class AltitudeResolution { const AltitudeResolution({this.altitudeMeters, this.siteWriteBack}); final double? altitudeMeters; final DiveSite? siteWriteBack; }`
  - `class AltitudeResolver { AltitudeResolver({required ElevationService elevationService, Map<String, double?>? cache}); Future<AltitudeResolution> resolve({GeoPoint? entryLocation, GeoPoint? exitLocation, DiveSite? site}); }`
  - `siteWriteBack` is non-null only when the value came from a site-coords lookup; it is `site.copyWith(altitude: <result>)` and the CALLER persists it.
  - The optional `cache` map is consulted and populated per lookup, keyed by `'<lat 4dp>,<lng 4dp>'`; used by the import enricher (Task 7) so a batch at one location does one lookup.

- [ ] **Step 1: Write the failing tests**

Create `test/features/weather/domain/services/altitude_resolver_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';

/// Serves a fixed elevation and counts requests; 500s when [fail] is true.
ElevationService _service({
  double elevation = 740.0,
  bool fail = false,
  List<Uri>? requests,
}) {
  return ElevationService(
    client: MockClient((request) async {
      requests?.add(request.url);
      if (fail) return http.Response('oops', 500);
      return http.Response(
        jsonEncode({
          'elevation': [elevation],
        }),
        200,
      );
    }),
  );
}

DiveSite _site({GeoPoint? location, double? altitude}) => DiveSite(
  id: 'site-1',
  name: 'Lake Test',
  location: location,
  altitude: altitude,
);

void main() {
  group('AltitudeResolver', () {
    test('prefers the dive entry location lookup', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(elevation: 740.0, requests: requests),
      );

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(altitude: 300.0),
      );

      expect(result.altitudeMeters, 740.0);
      expect(result.siteWriteBack, isNull);
      expect(requests.single.queryParameters['latitude'], '46.4');
    });

    test('uses exit location when entry is missing', () async {
      final resolver = AltitudeResolver(elevationService: _service());

      final result = await resolver.resolve(
        exitLocation: const GeoPoint(46.5, 8.1),
      );

      expect(result.altitudeMeters, 740.0);
    });

    test('falls back to site altitude when dive lookup fails', () async {
      final resolver = AltitudeResolver(elevationService: _service(fail: true));

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(altitude: 300.0),
      );

      expect(result.altitudeMeters, 300.0);
      expect(result.siteWriteBack, isNull);
    });

    test('uses site altitude when the dive has no GPS', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(requests: requests),
      );

      final result = await resolver.resolve(site: _site(altitude: 300.0));

      expect(result.altitudeMeters, 300.0);
      expect(requests, isEmpty);
    });

    test('looks up site coordinates and returns a write-back', () async {
      final resolver = AltitudeResolver(elevationService: _service());

      final result = await resolver.resolve(
        site: _site(location: const GeoPoint(46.4, 8.0)),
      );

      expect(result.altitudeMeters, 740.0);
      expect(result.siteWriteBack, isNotNull);
      expect(result.siteWriteBack!.altitude, 740.0);
      expect(result.siteWriteBack!.id, 'site-1');
    });

    test('returns empty resolution when nothing is available', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(requests: requests),
      );

      final result = await resolver.resolve();

      expect(result.altitudeMeters, isNull);
      expect(result.siteWriteBack, isNull);
      expect(requests, isEmpty);
    });

    test('returns empty resolution when all lookups fail', () async {
      final resolver = AltitudeResolver(elevationService: _service(fail: true));

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(location: const GeoPoint(46.4, 8.0)),
      );

      expect(result.altitudeMeters, isNull);
      expect(result.siteWriteBack, isNull);
    });

    test('cache dedupes lookups for nearby coordinates', () async {
      final requests = <Uri>[];
      final cache = <String, double?>{};

      final first = AltitudeResolver(
        elevationService: _service(requests: requests),
        cache: cache,
      );
      await first.resolve(entryLocation: const GeoPoint(46.40001, 8.00001));

      final second = AltitudeResolver(
        elevationService: _service(requests: requests),
        cache: cache,
      );
      final result = await second.resolve(
        entryLocation: const GeoPoint(46.40004, 8.00003),
      );

      expect(result.altitudeMeters, 740.0);
      expect(requests, hasLength(1));
    });

    test('cache remembers failures within a run', () async {
      final requests = <Uri>[];
      final cache = <String, double?>{};
      final resolver = AltitudeResolver(
        elevationService: _service(fail: true, requests: requests),
        cache: cache,
      );

      await resolver.resolve(entryLocation: const GeoPoint(46.4, 8.0));
      await resolver.resolve(entryLocation: const GeoPoint(46.4, 8.0));

      expect(requests, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/weather/domain/services/altitude_resolver_test.dart`
Expected: FAIL — `altitude_resolver.dart` does not exist (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/weather/domain/services/altitude_resolver.dart`:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

/// Result of an altitude resolution.
///
/// [siteWriteBack] is non-null only when the altitude came from a lookup of
/// the site's own coordinates: the caller should persist it so future dives
/// at that site resolve locally without a network call.
class AltitudeResolution {
  const AltitudeResolution({this.altitudeMeters, this.siteWriteBack});

  final double? altitudeMeters;
  final DiveSite? siteWriteBack;
}

/// Encodes the altitude precedence rule from the 2026-08-06 conditions spec:
/// dive GPS lookup, then the site's stored altitude, then a site-coordinates
/// lookup with write-back. Auto-fill callers must only apply the result to an
/// empty field; manual entry always wins.
class AltitudeResolver {
  AltitudeResolver({
    required ElevationService elevationService,
    Map<String, double?>? cache,
  }) : _elevation = elevationService,
       _cache = cache;

  final ElevationService _elevation;

  /// Optional per-run lookup cache keyed by coordinates rounded to 4 decimal
  /// places (roughly 11 m) so a batch import at one location does one lookup.
  final Map<String, double?>? _cache;

  Future<AltitudeResolution> resolve({
    GeoPoint? entryLocation,
    GeoPoint? exitLocation,
    DiveSite? site,
  }) async {
    final divePoint = entryLocation ?? exitLocation;
    if (divePoint != null) {
      final meters = await _lookup(divePoint);
      if (meters != null) return AltitudeResolution(altitudeMeters: meters);
    }

    if (site == null) return const AltitudeResolution();
    if (site.altitude != null) {
      return AltitudeResolution(altitudeMeters: site.altitude);
    }

    final siteLocation = site.location;
    if (siteLocation != null) {
      final meters = await _lookup(siteLocation);
      if (meters != null) {
        return AltitudeResolution(
          altitudeMeters: meters,
          siteWriteBack: site.copyWith(altitude: meters),
        );
      }
    }
    return const AltitudeResolution();
  }

  Future<double?> _lookup(GeoPoint point) async {
    final cache = _cache;
    final key =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    if (cache != null && cache.containsKey(key)) return cache[key];
    final meters = await _elevation.fetchElevation(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    cache?[key] = meters;
    return meters;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/weather/domain/services/altitude_resolver_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/weather test/features/weather
git commit -m "Add AltitudeResolver with dive GPS, site altitude, site lookup precedence"
```

---

### Task 3: Conditions section layout and l10n

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_buildConditionsSection` around line 3449, `_weatherRows` around line 3579)
- Modify: all 11 arb files `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_log/presentation/widgets/edit_sections/conditions_section_test.dart` (new)

**Interfaces:**
- Consumes: `FormOverline` / `FormOverlineAction` (`lib/shared/widgets/forms/form_overline.dart`), existing `_fetchWeather`, `_isFetchingWeather`, `_selectedSite`.
- Produces: `ConditionsSection` gains a `topRows` parameter (`List<Widget>`, default `const []`) rendered before the water temperature row. New l10n getter `diveLog_edit_subsection_autofill`. Task 4 adds behavior to the fetch handler; this task only moves it.

- [ ] **Step 1: Add the l10n key to all 11 arb files**

In `lib/l10n/arb/app_en.arb`, directly above the existing `"diveLog_edit_subsection_weather"` entry (line ~12809), add:

```json
"diveLog_edit_subsection_autofill": "Auto-fill",
```

Add the translated entry at the same position in the other 10 files:

| File | Value |
| --- | --- |
| app_ar.arb | `"تعبئة تلقائية"` |
| app_de.arb | `"Automatisch ausfüllen"` |
| app_es.arb | `"Autocompletar"` |
| app_fr.arb | `"Remplissage automatique"` |
| app_he.arb | `"מילוי אוטומטי"` |
| app_hu.arb | `"Automatikus kitöltés"` |
| app_it.arb | `"Compilazione automatica"` |
| app_nl.arb | `"Automatisch invullen"` |
| app_pt.arb | `"Preenchimento automático"` |
| app_zh.arb | `"自动填充"` |

Then run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with the new getter.

- [ ] **Step 2: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/edit_sections/conditions_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

void main() {
  Widget host({required List<Widget> topRows, required List<Widget> weatherRows}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConditionsSection(
            expanded: true,
            onToggle: () {},
            summary: '',
            isEmpty: true,
            temperatureSymbol: 'C',
            waterTempController: TextEditingController(),
            airTempController: TextEditingController(),
            topRows: topRows,
            environmentRows: const [],
            weatherRows: weatherRows,
          ),
        ),
      ),
    );
  }

  testWidgets('renders topRows above the temperature fields', (tester) async {
    await tester.pumpWidget(
      host(
        topRows: [
          FormOverline(
            label: 'Auto-fill',
            actions: [
              FormOverlineAction(label: 'Fetch weather', onPressed: () {}),
            ],
          ),
        ],
        weatherRows: const [FormOverline(label: 'Weather')],
      ),
    );
    await tester.pumpAndSettle();

    final autofillY = tester.getTopLeft(find.text('AUTO-FILL')).dy;
    final weatherY = tester.getTopLeft(find.text('WEATHER')).dy;
    final firstFieldY = tester.getTopLeft(find.byType(TextField).first).dy;

    expect(find.text('Fetch weather'), findsOneWidget);
    expect(autofillY, lessThan(firstFieldY));
    expect(autofillY, lessThan(weatherY));
  });

  testWidgets('topRows defaults to empty and renders nothing extra', (
    tester,
  ) async {
    await tester.pumpWidget(host(topRows: const [], weatherRows: const []));
    await tester.pumpAndSettle();

    expect(find.byType(FormOverline), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/conditions_section_test.dart`
Expected: FAIL — `ConditionsSection` has no `topRows` parameter (compile error).

- [ ] **Step 4: Add `topRows` to ConditionsSection**

In `conditions_section.dart`, add the field, constructor parameter, and spread it first in `children`:

```dart
    this.topRows = const [],
```

```dart
  /// Rows pinned above the temperature fields (the auto-fill action overline).
  final List<Widget> topRows;
```

```dart
      children: [
        ...topRows,
        FormRow.text(
          label: l10n.diveLog_edit_label_waterTemp,
```

Also update the class doc comment's first line to mention the auto-fill row, e.g. "Group 3 of the dive form. An auto-fill action row leads, then water/air temperature as ordinary rows; the environment and weather row lists are page-provided...".

- [ ] **Step 5: Move the fetch action in dive_edit_page.dart**

In `_buildConditionsSection` (line ~3449), pass the new row:

```dart
    return ConditionsSection(
      expanded: _isExpanded('conditions', defaultValue: false),
      onToggle: () => _toggleSection('conditions', defaultValue: false),
      summary: _conditionsSummary(units),
      isEmpty: _conditionsIsEmpty(),
      temperatureSymbol: units.temperatureSymbol,
      waterTempController: _waterTempController,
      airTempController: _airTempController,
      topRows: [_autofillOverline(units)],
      environmentRows: _environmentRows(units),
      weatherRows: _weatherRows(units),
    );
```

Add the new method directly above `_weatherRows`:

```dart
  Widget _autofillOverline(UnitFormatter units) {
    final l10n = context.l10n;
    final canFetchWeather =
        _selectedSite != null && _selectedSite!.hasCoordinates;
    return FormOverline(
      label: l10n.diveLog_edit_subsection_autofill,
      actions: [
        FormOverlineAction(
          label: l10n.diveLog_edit_button_fetchWeather,
          icon: Icons.cloud_download,
          busy: _isFetchingWeather,
          onPressed: canFetchWeather ? () => _fetchWeather(units) : null,
        ),
      ],
    );
  }
```

In `_weatherRows` (line ~3579), replace the action-carrying overline with a plain one and delete the now-unused `canFetchWeather` local:

```dart
  List<Widget> _weatherRows(UnitFormatter units) {
    final l10n = context.l10n;
    return [
      FormOverline(label: l10n.diveLog_edit_subsection_weather),
      FormRow.text(
        label: l10n.diveLog_edit_label_humidity,
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/conditions_section_test.dart`
Expected: PASS (2 tests).

Also run the existing edit page suites to catch regressions:
`flutter test test/features/dive_log/presentation/pages/`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "Move weather fetch action to the top of the conditions section"
```

---

### Task 4: Dive edit page altitude auto-fill

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `test/helpers/mock_providers.dart` (`getBaseOverrides`, line ~469)
- Test: `test/features/dive_log/presentation/pages/dive_edit_altitude_autofill_test.dart` (new)

**Interfaces:**
- Consumes: `elevationServiceProvider` (Task 1), `AltitudeResolver`/`AltitudeResolution` (Task 2), existing page members: `_altitudeController`, `_existingDive`, `_selectedSite`, `_silently` (line ~294), `_assignSite` (line ~1974), `_fetchWeather` (line ~3644), `siteListNotifierProvider`, `settingsProvider`, `UnitFormatter`.
- Produces: `Future<void> _maybeAutoFillAltitude()` on the page state; `getBaseOverrides` gains an optional `http.Client? weatherHttpClient` parameter and always overrides `weatherHttpClientProvider` (default: instant 500 stub so no widget test ever hits the network).

- [ ] **Step 1: Wire the network stub into the shared test harness**

In `test/helpers/mock_providers.dart` add imports:

```dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
```

Extend `getBaseOverrides` (line ~469):

```dart
Future<List<Override>> getBaseOverrides({
  MockSettingsNotifier? settingsNotifier,
  http.Client? weatherHttpClient,
}) async {
```

and append to the returned list:

```dart
    // Weather/elevation lookups must never hit the network in widget tests;
    // the default stub fails fast so altitude auto-fill resolves to null.
    weatherHttpClientProvider.overrideWithValue(
      weatherHttpClient ?? MockClient((_) async => http.Response('', 500)),
    ),
```

with the import `package:submersion/features/weather/presentation/providers/weather_providers.dart`.

- [ ] **Step 2: Write the failing widget tests**

Create `test/features/dive_log/presentation/pages/dive_edit_altitude_autofill_test.dart`, modeled on `dive_edit_site_gps_test.dart` (same setUp/tearDown with `setUpTestDatabase`, same pump harness):

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
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

  Dive buildDive({double? altitude}) => Dive(
    id: 'dive-alt',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    altitude: altitude,
    entryLocation: const GeoPoint(46.4, 8.0),
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<void> pumpEditPage(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides(
      weatherHttpClient: MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(
          jsonEncode({
            'elevation': [740.2],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(diveId: diveId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  testWidgets('fills empty altitude from logged GPS on load', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.widgetWithText(TextField, '740'), findsOneWidget);
  });

  testWidgets('never overwrites an existing altitude', (tester) async {
    final created = await repository.createDive(buildDive(altitude: 500.0));
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.widgetWithText(TextField, '500'), findsOneWidget);
    expect(find.widgetWithText(TextField, '740'), findsNothing);
  });
}
```

Notes for the implementer:
- If `find.text('Conditions')` is ambiguous or the label differs, check `diveLog_edit_group_conditions` in `app_en.arb` and use that exact string.
- If `740` also matches another field, scope the finder to the altitude row: `find.descendant(of: find.byType(ConditionsSection), matching: find.widgetWithText(TextField, '740'))`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_altitude_autofill_test.dart`
Expected: The first test FAILS (no auto-fill exists; altitude field is empty). The second test may already pass — that is fine; it pins the invariant.

- [ ] **Step 4: Implement `_maybeAutoFillAltitude` and its hooks**

In `dive_edit_page.dart`:

1. Add imports: `dart:async` (for `unawaited`), `package:submersion/features/weather/domain/services/altitude_resolver.dart` (the page already imports `weather_providers.dart` at line 74).

2. Add the method near `_fetchWeather`:

```dart
  /// Fill an empty altitude field from the dive's logged GPS or the selected
  /// site (spec: 2026-08-06 conditions design). Never overwrites a value and
  /// never marks the form dirty on its own.
  Future<void> _maybeAutoFillAltitude() async {
    if (_altitudeController.text.isNotEmpty) return;

    final resolver = AltitudeResolver(
      elevationService: ref.read(elevationServiceProvider),
    );
    final resolution = await resolver.resolve(
      entryLocation: _existingDive?.entryLocation,
      exitLocation: _existingDive?.exitLocation,
      site: _selectedSite,
    );
    if (!mounted) return;

    final writeBack = resolution.siteWriteBack;
    if (writeBack != null) {
      await ref.read(siteListNotifierProvider.notifier).updateSite(writeBack);
      if (!mounted) return;
      if (_selectedSite?.id == writeBack.id) {
        _selectedSite = writeBack;
      }
    }

    final meters = resolution.altitudeMeters;
    if (meters == null || _altitudeController.text.isNotEmpty) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _silently(() {
        _altitudeController.text = units
            .convertAltitude(meters)
            .toStringAsFixed(0);
      });
    });
  }
```

3. Hook: end of `_loadExistingDive`, inside the existing `finally` block (line ~695), after `_suppressDirty = false;`:

```dart
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _suppressDirty = false;
        unawaited(_maybeAutoFillAltitude());
      }
    }
```

4. Hook: end of `_assignSite` (line ~1974) — covers the site picker, new-site creation, and new-dive prefill:

```dart
  void _assignSite(DiveSite? site) {
    _selectedSite = site;
    _waterType = waterTypeAfterSiteAssign(_waterType, site);
    unawaited(_maybeAutoFillAltitude());
  }
```

5. Hook: in `_fetchWeather`, at the end of the success `setState` path (right after the `_weatherFetchedAt = DateTime.now();` state update block, before the success snackbar):

```dart
      unawaited(_maybeAutoFillAltitude());
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_altitude_autofill_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Run the neighboring edit page suites**

Run: `flutter test test/features/dive_log/presentation/pages/ test/helpers/`
Expected: PASS — if any test fails on an unexpected HTTP override, it means it constructed `getBaseOverrides` differently; fix by threading the new parameter, never by removing the default stub.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "Auto-fill dive altitude from logged GPS or site on the edit form"
```

---

### Task 5: Altitude on the add-GPS-to-site action

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_updateSiteWithPhotoGps`, line ~1946)

**Interfaces:**
- Consumes: `elevationServiceProvider` (Task 1), existing `_updateSiteWithPhotoGps`.
- Produces: no new API; behavior only.

- [ ] **Step 1: Extend `_updateSiteWithPhotoGps`**

Replace the beginning of the method so the site update carries altitude when the site has none:

```dart
  Future<void> _updateSiteWithPhotoGps(GeoPoint gps) async {
    if (_selectedSite == null) return;

    var updatedSite = _selectedSite!.copyWith(location: gps);
    if (updatedSite.altitude == null) {
      final meters = await ref
          .read(elevationServiceProvider)
          .fetchElevation(latitude: gps.latitude, longitude: gps.longitude);
      if (!mounted) return;
      if (meters != null) {
        updatedSite = updatedSite.copyWith(altitude: meters);
      }
    }

    // Update the site via the notifier
    final siteNotifier = ref.read(siteListNotifierProvider.notifier);
    await siteNotifier.updateSite(updatedSite);
```

The rest of the method (setState, snackbar) is unchanged.

- [ ] **Step 2: Run the existing suites that exercise this page**

Run: `flutter test test/features/dive_log/presentation/pages/`
Expected: PASS — the Task 4 harness stub makes the lookup resolve null in tests, so existing photo-GPS behavior is unchanged there. This path's altitude behavior is covered by the Task 1/2 unit tests plus manual verification in Task 8.

- [ ] **Step 3: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib
git commit -m "Fill site altitude when attaching photo GPS to a site"
```

---

### Task 6: Site edit page altitude auto-fill

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_altitude_autofill_test.dart` (new)

**Interfaces:**
- Consumes: `elevationServiceProvider` (Task 1), existing page members: `_latitudeController`, `_longitudeController`, `_altitudeController` (line ~81), `_isApplyingInitialValues`, `_seedInitialLocation` (line ~141), `settingsProvider`, `UnitFormatter`.
- Produces: no new API; behavior only. Coordinate changes (typed, locate action, map pick — all flow through the controllers) trigger a debounced elevation lookup that fills an empty altitude field.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_sites/presentation/pages/site_edit_altitude_autofill_test.dart`. Model the pump harness on an existing site edit test in `test/features/dive_sites/presentation/pages/` (use the same overrides scaffolding it uses, plus `getBaseOverrides(weatherHttpClient: ...)` from Task 4):

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('typing coordinates fills an empty altitude field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides(
      weatherHttpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'elevation': [740.2],
          }),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: base.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SiteEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Expand the location group if it is collapsed, then type coordinates.
    final latField = find.widgetWithText(TextField, 'Latitude');
    await tester.ensureVisible(latField);
    await tester.enterText(latField, '46.4');
    final lngField = find.widgetWithText(TextField, 'Longitude');
    await tester.enterText(lngField, '8.0');

    // Let the 1-second debounce elapse, then the async lookup complete.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '740'), findsOneWidget);
  });
}
```

Notes for the implementer:
- `const SiteEditPage()` is valid — `siteId` is optional (new-site mode).
- The rendered labels are exactly "Latitude" and "Longitude" (`diveSites_edit_gps_latitude_label` / `diveSites_edit_gps_longitude_label`). If the Location group starts collapsed, tap its header (the `diveSites_edit_group_location` string) before entering text.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_altitude_autofill_test.dart`
Expected: FAIL on the final expect — altitude stays empty.

- [ ] **Step 3: Implement the debounced lookup**

In `site_edit_page.dart`:

1. Add imports: `dart:async`, `package:submersion/features/weather/presentation/providers/weather_providers.dart`.

2. Add state and methods to the state class:

```dart
  Timer? _altitudeLookupDebounce;

  /// Debounce typed coordinate edits; locate and map-pick set both controller
  /// texts at once and land here through the same listeners.
  void _scheduleAltitudeLookup() {
    if (_isApplyingInitialValues) return;
    _altitudeLookupDebounce?.cancel();
    _altitudeLookupDebounce = Timer(const Duration(seconds: 1), () {
      if (mounted) _maybeFetchAltitude();
    });
  }

  Future<void> _maybeFetchAltitude() async {
    if (_altitudeController.text.isNotEmpty) return;
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

    final meters = await ref
        .read(elevationServiceProvider)
        .fetchElevation(latitude: lat, longitude: lng);
    if (!mounted || meters == null) return;
    if (_altitudeController.text.isNotEmpty) return;

    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _altitudeController.text = units
          .convertAltitude(meters)
          .toStringAsFixed(0);
    });
  }
```

If the page obtains `UnitFormatter` differently (check how `_populateFields` gets its `units` at line ~200), match that pattern instead.

3. In `initState` (line ~104), after the existing listener registrations:

```dart
    _latitudeController.addListener(_scheduleAltitudeLookup);
    _longitudeController.addListener(_scheduleAltitudeLookup);
```

4. At the end of `_seedInitialLocation` (line ~141), after `_isApplyingInitialValues = false;` (seeding a new site from a dive's GPS must also fill altitude — the guard suppressed the listener):

```dart
    _scheduleAltitudeLookup();
```

5. In `dispose`, before the controller disposals:

```dart
    _altitudeLookupDebounce?.cancel();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_altitude_autofill_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the existing site edit suites**

Run: `flutter test test/features/dive_sites/`
Expected: PASS. Pending-timer failures in existing tests mean the debounce timer leaked — verify the `dispose` cancellation was added.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "Auto-fill site altitude when coordinates are set on the site form"
```

---

### Task 7: DiveAltitudeEnricher on the import and download seams

**Files:**
- Create: `lib/features/dive_log/domain/services/dive_altitude_enricher.dart`
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart` (`performImport`, line ~339)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (line ~1332)
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (line ~273)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`importProfile`, after the `ChecklistDiveLinker` call at line ~987)
- Test: `test/features/dive_log/domain/services/dive_altitude_enricher_test.dart` (new)

**Interfaces:**
- Consumes: `AltitudeResolver` (Task 2), `ElevationService` (Task 1), `DiveRepository` (`getDiveById(String)`, `updateDive(Dive)`, `createDive(Dive)`), `SiteRepository.updateSite(DiveSite)`, `Dive.copyWith(altitude:)`, `DatabaseService.instance.databaseOrNull`, `GeoPoint`.
- Produces:
  - `class DiveAltitudeEnricher { DiveAltitudeEnricher({ElevationService? elevationService, DiveRepository? diveRepository, SiteRepository? siteRepository}); Future<bool> applyForImportedDive(Dive dive); Future<bool> applyForDownloadedDive({required String diveId, required List<GeoPoint> points}); }`
  - One instance per import run (holds the coordinate cache). Both methods are best-effort: any thrown error returns false and never aborts an import.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/services/dive_altitude_enricher_test.dart`. Follow the test-database pattern from `dive_edit_site_gps_test.dart` (`setUpTestDatabase`/`tearDownTestDatabase`, real `DiveRepository`):

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

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

  Dive buildDive(String id, {GeoPoint? entryLocation, double? altitude}) =>
      Dive(
        id: id,
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryLocation: entryLocation,
        altitude: altitude,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

  ElevationService countingService(List<Uri> requests) => ElevationService(
    client: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode({
          'elevation': [740.2],
        }),
        200,
      );
    }),
  );

  test('fills altitude for an imported dive with GPS', () async {
    final dive = await repository.createDive(
      buildDive('d1', entryLocation: const GeoPoint(46.4, 8.0)),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isTrue);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 740.0);
  });

  test('skips dives that already have altitude', () async {
    final requests = <Uri>[];
    final dive = await repository.createDive(
      buildDive('d2', entryLocation: const GeoPoint(46.4, 8.0), altitude: 500),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    expect(requests, isEmpty);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 500.0);
  });

  test('skips dives with no GPS and no site', () async {
    final requests = <Uri>[];
    final dive = await repository.createDive(buildDive('d3'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    expect(requests, isEmpty);
  });

  test('one lookup covers a batch at the same location', () async {
    final requests = <Uri>[];
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    for (var i = 0; i < 3; i++) {
      final dive = await repository.createDive(
        buildDive('batch-$i', entryLocation: const GeoPoint(46.4, 8.0)),
      );
      await enricher.applyForImportedDive(dive);
    }

    expect(requests, hasLength(1));
    final stored = await repository.getDiveById('batch-2');
    expect(stored!.altitude, 740.0);
  });

  test('lookup failure leaves the dive importable and unchanged', () async {
    final dive = await repository.createDive(
      buildDive('d4', entryLocation: const GeoPoint(46.4, 8.0)),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: ElevationService(
        client: MockClient((_) async => http.Response('oops', 500)),
      ),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, isNull);
  });

  test('fills a downloaded dive from its GPS points', () async {
    final dive = await repository.createDive(buildDive('d5'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForDownloadedDive(
      diveId: dive.id,
      points: const [GeoPoint(46.4, 8.0)],
    );

    expect(applied, isTrue);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 740.0);
  });

  test('downloaded dive with no points is a no-op', () async {
    final dive = await repository.createDive(buildDive('d6'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForDownloadedDive(
      diveId: dive.id,
      points: const [],
    );

    expect(applied, isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/dive_altitude_enricher_test.dart`
Expected: FAIL — `dive_altitude_enricher.dart` does not exist (compile error).

- [ ] **Step 3: Write the enricher**

Create `lib/features/dive_log/domain/services/dive_altitude_enricher.dart`:

```dart
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';

/// Fills a newly imported or downloaded dive's altitude from its GPS fixes
/// or linked site. Best-effort like [DiveEquipmentDefaulter]: any failure is
/// swallowed so enrichment can never abort an import that has already
/// persisted the dive. Create ONE instance per import run — the resolver
/// cache dedupes lookups for a batch of dives at the same location.
class DiveAltitudeEnricher {
  DiveAltitudeEnricher({
    ElevationService? elevationService,
    DiveRepository? diveRepository,
    SiteRepository? siteRepository,
  }) : _resolver = AltitudeResolver(
         elevationService: elevationService ?? ElevationService(),
         cache: <String, double?>{},
       ),
       _dives = diveRepository ?? DiveRepository(),
       _sites = siteRepository ?? SiteRepository();

  final AltitudeResolver _resolver;
  final DiveRepository _dives;
  final SiteRepository _sites;

  /// Enrich a file-imported dive (domain entity in hand). Returns true when
  /// an altitude was written.
  Future<bool> applyForImportedDive(Dive dive) async {
    if (dive.altitude != null) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final resolution = await _resolver.resolve(
        entryLocation: dive.entryLocation,
        exitLocation: dive.exitLocation,
        site: dive.site,
      );
      final writeBack = resolution.siteWriteBack;
      if (writeBack != null) {
        await _sites.updateSite(writeBack);
      }
      final meters = resolution.altitudeMeters;
      if (meters == null) return false;
      await _dives.updateDive(dive.copyWith(altitude: meters));
      return true;
    } catch (_) {
      // Best-effort: never let altitude enrichment fail the dive operation.
      return false;
    }
  }

  /// Enrich a dive persisted by the dive computer download path, where only
  /// the id and the entry/exit GPS fixes are in hand.
  Future<bool> applyForDownloadedDive({
    required String diveId,
    required List<GeoPoint> points,
  }) async {
    if (points.isEmpty) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final resolution = await _resolver.resolve(entryLocation: points.first);
      final meters = resolution.altitudeMeters;
      if (meters == null) return false;
      final dive = await _dives.getDiveById(diveId);
      if (dive == null || dive.altitude != null) return false;
      await _dives.updateDive(dive.copyWith(altitude: meters));
      return true;
    } catch (_) {
      // Best-effort: never let altitude enrichment fail the dive operation.
      return false;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/dive_altitude_enricher_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Wire the four call sites**

Each site mirrors the existing `DiveEquipmentDefaulter` / `ChecklistDiveLinker` pattern. Add the import `package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart` to each file.

a) `lib/features/dive_import/presentation/providers/dive_import_providers.dart`, `performImport` (line ~339): hoist one instance before the `for` loop and call it after the existing linkers:

```dart
    try {
      final altitudeEnricher = DiveAltitudeEnricher();
      for (final sourceId in state.selectedDiveIds) {
```

```dart
        await repository.createDive(dive);
        await DiveEquipmentDefaulter().applyForImportedDive(dive);
        await ChecklistDiveLinker().applyForImportedDive(dive);
        await altitudeEnricher.applyForImportedDive(dive);
        imported++;
```

b) `lib/features/dive_import/data/services/uddf_entity_importer.dart` (line ~1332): find the enclosing dive `for` loop above the existing `await repos.diveRepository.createDive(dive);` block, declare `final altitudeEnricher = DiveAltitudeEnricher();` immediately before that loop, and extend the call block:

```dart
      await repos.diveRepository.createDive(dive);
      await DiveEquipmentDefaulter().applyForImportedDive(dive);
      await ChecklistDiveLinker().applyForImportedDive(dive);
      await altitudeEnricher.applyForImportedDive(dive);
```

c) `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (line ~273): declare `final altitudeEnricher = DiveAltitudeEnricher();` immediately before the `for (var i = 0; i < sortedIndices.length; i++)` loop and extend the call block the same way:

```dart
      await _diveRepository.createDive(dive);
      await DiveEquipmentDefaulter().applyForImportedDive(dive);
      await ChecklistDiveLinker().applyForImportedDive(dive);
      await altitudeEnricher.applyForImportedDive(dive);
```

d) `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, inside `importProfile` after the `ChecklistDiveLinker().autoLinkForDive(...)` call (line ~987), reusing the `defaultPoints` list already built at line ~973:

```dart
        // Fill altitude from the entry/exit GPS fixes (best-effort).
        await DiveAltitudeEnricher().applyForDownloadedDive(
          diveId: diveId,
          points: defaultPoints,
        );
```

Note on (d): `importProfile` is called once per dive, so a per-call enricher gets no cross-dive cache there. That is acceptable — downloads arrive one at a time through this seam and the lookup is one cheap GET; do NOT try to thread an instance through the repository constructor.

- [ ] **Step 6: Run the surrounding suites**

Run: `flutter test test/features/dive_import/ test/features/import_wizard/ test/features/dive_log/data/`
Expected: PASS. In the Flutter test binding, any un-mocked HTTP call returns an immediate 400, so the default-constructed enrichers resolve null quickly without network flakiness.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "Enrich imported and downloaded dives with altitude from GPS"
```

---

### Task 8: Full verification

**Files:**
- No new files; fixes only if verification fails.

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: no formatting changes, zero analyzer issues (infos are fatal in CI). Never pipe either command through `| tail`.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS. Known pre-existing flakes (per project memory): backup tests and recovery-code yo-yo tests can flake in the full run — re-run a failing file in isolation before assuming this change broke it. Budget 15+ minutes; do not kill the run early.

- [ ] **Step 3: Manual smoke test on macOS (optional but recommended)**

```bash
flutter run -d macos
```

- Open a dive with a site that has coordinates: Conditions section shows the Auto-fill overline with the Fetch weather button at the very top; Weather overline below has no button.
- Fetch weather: air temp fills; snackbar appears.
- Assign a site with coordinates but no altitude to a dive with no altitude: altitude fills within a second or two; reopen the site in the site editor and confirm its altitude field was written back.
- Site edit: type coordinates into a new site; altitude fills after about a second.

- [ ] **Step 4: Commit any verification fixes**

```bash
git add -A
git commit -m "Fix issues found during full-suite verification"
```

Only commit if fixes were needed; otherwise the branch is complete and ready for PR (PR descriptions carry no attribution lines or session links per CLAUDE.md).
