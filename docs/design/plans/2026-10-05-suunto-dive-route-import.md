# Suunto DiveRoute Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the Suunto Nautic S / Ocean `DiveRoute` (1 Hz X/Y/Z) as an underwater route linked to its dive, from both the Suunto Cloud import and a new Suunto app JSON file import.

**Architecture:** A pure `SuuntoDiveRouteParser` turns `DiveRoute` samples into `NavTrackPoint`s on the dive's own time base, and `SuuntoDiveParser` attaches the result to `SuuntoParsedDive.route`. The Suunto Cloud adapter's import logic moves into an abstract `SuuntoDiveImportCore`, which writes the route through a `SuuntoRouteWriter` after every dive write. A new `SuuntoFileAdapter` reuses that core. `FormatDetector` recognises Suunto JSON as a hand-off format, and the universal wizard, share/drop, and batch summary all route it to the Suunto file wizard.

**Tech Stack:** Flutter, Riverpod (`StateProvider`, `Provider`), Drift (test DB via `setUpTestDatabase`), go_router, mockito (reusing `suunto_cloud_adapter_test.mocks.dart`), file_picker 12 (handles), ARB l10n (11 locales).

**Spec:** [docs/superpowers/specs/2026-10-05-suunto-dive-route-import-design.md](../specs/2026-10-05-suunto-dive-route-import-design.md)

## Global Constraints

- Never use the em-dash character anywhere (code, comments, docs, commits, ARB values).
- No mention of Claude, Claude Code or Anthropic in any commit, PR, or file.
- Imports grouped dart, flutter, packages, local; files snake_case; 800 lines max per file (`suunto_dive_parser.dart` is already 1046 lines, so new logic goes in new files).
- Paths in tests built with `p.join`, temp space via `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- `NavTrackPoint.timestamp` is wall-clock-as-UTC epoch seconds, the same convention as `dives.entryTime`.
- Route points use the same clock correction as the dive start (`SuuntoDiveParser._sampleClockCorrection`, the #2604 fix).
- Anchor = `DiveRouteOrigin` (degrees). A null-island origin means no explicit anchor.
- A route that fails to parse or write never fails the dive import.
- Every new user-visible string is added to all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), anchored after a neighbouring key of the same group, then `flutter gen-l10n` regenerates the committed `app_localizations*.dart`.
- Run `dart format .` before every commit.
- Commits on this branch use `feat(<scope>)` / `test(<scope>)` / `refactor(<scope>)` / `docs(<scope>)`.

## Review Focus

1. **Route samples out of order or repeated** (a timestamp equal to or earlier than the previous one). The earlier-than case is dropped, equal is kept, and the route still imports. Pinned in Task 1.
2. **`DiveRoute` present but `DiveRouteOrigin` missing or (0, 0).** The route imports unanchored by Suunto. `insertImportedRoute`'s existing fallback (the dive's entry fix) then applies. Pinned in Task 4.
3. **Importing the same Suunto file twice with "Replace source".** The dive ends with exactly one Suunto route, and it is primary. Pinned in Task 4.
4. **A JSON file that is not a Suunto export** (another app's JSON) dropped on the app. It must stay "unsupported" and must never open the Suunto wizard. A Suunto export of a non-dive activity is listed as "not a dive" and the other files still import. Pinned in Tasks 6 and 7.
5. **A route write that fails** (foreign-key failure, DB error). The writer logs it and returns null, and the dive import's counts are unchanged. Pinned in Tasks 4 and 5.

---

## File Structure

**Create**

| File | Responsibility |
| --- | --- |
| `lib/core/services/suunto_cloud/suunto_dive_route.dart` | `SuuntoDiveRoute` value type and the pure `SuuntoDiveRouteParser`. |
| `lib/core/services/suunto_cloud/suunto_json_file_reader.dart` | `SuuntoJsonFile`, `SuuntoFileRejection`, `SuuntoFileReadResult`, `readSuuntoJsonFile`. |
| `lib/features/import_wizard/data/adapters/suunto_route_writer.dart` | `SuuntoRouteWriter`: insert-or-replace a Suunto route on a dive, never throws. |
| `lib/features/import_wizard/data/adapters/suunto_dive_import_core.dart` | Abstract `SuuntoDiveImportCore`: bundle, duplicates, the three write paths, computers, notes, route attach (moved from `SuuntoCloudAdapter`). |
| `lib/features/import_wizard/data/adapters/suunto_file_adapter.dart` | `SuuntoFileAdapter` and `suuntoFileDivesReadyProvider`. |
| `lib/features/import_wizard/presentation/widgets/suunto_file_step.dart` | `SuuntoFileStep` acquisition widget and `suuntoJsonFilePickerProvider`. |
| `lib/features/import_wizard/presentation/suunto_file_import_navigation.dart` | `suuntoFileImportPath` and `openSuuntoFileImport`. |
| `lib/features/universal_import/presentation/widgets/suunto_json_handoff_card.dart` | The hand-off card shown by the universal wizard. |

**Tests**

- `test/core/services/suunto_cloud/suunto_dive_route_test.dart`
- `test/core/services/suunto_cloud/suunto_json_file_reader_test.dart`
- `test/features/import_wizard/data/adapters/suunto_route_writer_test.dart`
- `test/features/import_wizard/data/adapters/suunto_dive_import_core_route_test.dart`
- `test/features/import_wizard/data/adapters/suunto_file_adapter_test.dart`
- `test/features/import_wizard/presentation/widgets/suunto_file_step_test.dart`
- `test/features/universal_import/presentation/widgets/suunto_json_handoff_card_test.dart`

**Modify**

- `lib/core/services/suunto_cloud/suunto_dive_parser.dart`: `SuuntoParsedDive.route`, and compute it.
- `lib/core/services/suunto_cloud/suunto_sml_normalizer.dart`: throw `SuuntoNotADiveException`.
- `lib/core/services/suunto_cloud/suunto_api_exception.dart`: add `SuuntoNotADiveException`.
- `lib/features/nav_track/data/repositories/nav_track_repository.dart`: explicit anchor parameters on `insertImportedRoute`.
- `lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart`: becomes a thin subclass of the core.
- `lib/features/import_wizard/domain/models/import_bundle.dart`: `ImportSourceType.suuntoFile`.
- `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart`: invalidate computers for `suuntoFile`.
- `lib/features/universal_import/data/models/import_enums.dart`: `ImportFormat.suuntoJson`, `isHandoff`.
- `lib/features/universal_import/data/services/format_detector.dart`: `_detectSuuntoJson`.
- `lib/features/universal_import/presentation/providers/universal_import_providers.dart`: `isHandoff` in place of the `navTrack` checks.
- `lib/features/universal_import/presentation/widgets/file_selection_step.dart`: show the Suunto card.
- `lib/shared/services/incoming_file_handler.dart`, `lib/app.dart`, `lib/shared/widgets/global_drop_target.dart`: the new outcome.
- `lib/features/import_wizard/domain/models/import_file_outcome.dart`, `lib/features/import_wizard/data/adapters/universal_adapter.dart`, `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`: the batch "Import with Suunto importer" action.
- `lib/core/router/app_router.dart`: route `/transfer/import-file/suunto`, and pass `SuuntoRouteWriter` into the cloud adapter.
- `lib/l10n/arb/app_*.arb` (11 files) and the generated `app_localizations*.dart`.

---

### Task 0: Before screenshots

- [ ] **Step 1:** Launch the app with the `run` skill (macOS desktop). Capture, into the scratchpad:
  - `01-universal-import-suunto-json-before.png`: the universal import wizard after picking a Suunto app JSON (synthetic file from Task 6's test data, written to the scratchpad). Today it shows the unsupported/unknown outcome.
  - `02-dive-3d-estimated-path-before.png`: the 3D view of a dive with a compass profile, showing the "Estimated path" chip.

  No commit.

---

### Task 1: SuuntoDiveRouteParser

**Files:**
- Create: `lib/core/services/suunto_cloud/suunto_dive_route.dart`
- Test: `test/core/services/suunto_cloud/suunto_dive_route_test.dart`

**Interfaces:**
- Produces:
  - `class SuuntoDiveRoute { final List<NavTrackPoint> points; final double? originLatitude; final double? originLongitude; }`
  - `SuuntoDiveRouteParser.parse(List<Map<String, dynamic>> samples, {required int? Function(Map<String, dynamic>) timestampMs, required Duration clockCorrection, double? originLatitude, double? originLongitude}) -> SuuntoDiveRoute?`

Provisional axis convention (Task 10 verifies it against a real export):
- X is east and Y is north.
- Z orientation is self-calibrating. If most finite Z values are negative, the recording is up-positive and every Z is negated. Then depth = max(0, oriented Z).

The spec's "Z positive down, clamp small negatives" holds whichever way the device writes the sign.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_dive_route.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart'
    show kMaxNavTrackPointCount;

int? _ms(Map<String, dynamic> s) {
  final iso = s['TimeISO8601'] as String?;
  return iso == null ? null : DateTime.parse(iso).millisecondsSinceEpoch;
}

Map<String, dynamic> _routeSample(int second, num x, num y, num z) => {
  'TimeISO8601':
      '2026-04-19T10:00:${second.toString().padLeft(2, '0')}.000Z',
  'DiveRoute': {'X': x, 'Y': y, 'Z': z},
};

SuuntoDiveRoute? _parse(
  List<Map<String, dynamic>> samples, {
  Duration correction = Duration.zero,
  double? lat,
  double? lon,
}) => SuuntoDiveRouteParser.parse(
  samples,
  timestampMs: _ms,
  clockCorrection: correction,
  originLatitude: lat,
  originLongitude: lon,
);

void main() {
  final t0 = DateTime.utc(2026, 4, 19, 10).millisecondsSinceEpoch ~/ 1000;

  test('maps X to east, Y to north and Z to depth, one point per sample', () {
    final route = _parse([
      _routeSample(0, 0, 0, 0.5),
      _routeSample(1, 1.5, 2.5, 3.0),
      {'TimeISO8601': '2026-04-19T10:00:02.000Z', 'Depth': 3.1},
      _routeSample(3, 3.0, 5.0, 4.0),
    ], lat: 47.2, lon: -2.9)!;

    expect(route.points, hasLength(3));
    expect(route.points[1].east, 1.5);
    expect(route.points[1].north, 2.5);
    expect(route.points[1].depth, 3.0);
    expect(route.points.map((p) => p.timestamp), [t0, t0 + 1, t0 + 3]);
    expect(route.originLatitude, 47.2);
    expect(route.originLongitude, -2.9);
  });

  test('negates an up-positive Z so depth is positive down', () {
    final route = _parse([
      _routeSample(0, 0, 0, -0.2),
      _routeSample(1, 1, 1, -5.0),
      _routeSample(2, 2, 2, -6.0),
      _routeSample(3, 3, 3, 0.1),
    ])!;

    expect(route.points.map((p) => p.depth), [0.2, 5.0, 6.0, 0.0]);
  });

  test('clamps a small negative depth to zero on a down-positive Z', () {
    final route = _parse([
      _routeSample(0, 0, 0, -0.1),
      _routeSample(1, 1, 1, 5.0),
      _routeSample(2, 2, 2, 6.0),
    ])!;

    expect(route.points.first.depth, 0.0);
  });

  test('applies the clock correction to every timestamp', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      _routeSample(1, 1, 1, 1),
    ], correction: const Duration(hours: -2))!;

    expect(route.points.first.timestamp, t0 - 7200);
  });

  test('drops points with a missing or non-finite coordinate', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      {
        'TimeISO8601': '2026-04-19T10:00:01.000Z',
        'DiveRoute': {'X': 1, 'Y': null, 'Z': 1},
      },
      _routeSample(2, double.nan, 1, 1),
      _routeSample(3, 2, 2, 1),
    ])!;

    expect(route.points.map((p) => p.timestamp), [t0, t0 + 3]);
  });

  test('drops a point whose timestamp goes backwards, keeps equal ones', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      _routeSample(2, 1, 1, 1),
      _routeSample(1, 9, 9, 1),
      _routeSample(2, 2, 2, 1),
    ])!;

    expect(route.points.map((p) => p.east), [0, 1, 2]);
  });

  test('drops a sample with no timestamp', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      {
        'DiveRoute': {'X': 5, 'Y': 5, 'Z': 1},
      },
      _routeSample(1, 1, 1, 1),
    ])!;

    expect(route.points, hasLength(2));
  });

  test('returns null with fewer than two usable points', () {
    expect(_parse([_routeSample(0, 0, 0, 1)]), isNull);
    expect(_parse(const []), isNull);
  });

  test('returns null above the storable point cap', () {
    final samples = [
      for (var i = 0; i <= kMaxNavTrackPointCount; i++)
        {
          'TimeISO8601': DateTime.utc(
            2026,
            4,
            19,
          ).add(Duration(seconds: i)).toIso8601String(),
          'DiveRoute': {'X': 0, 'Y': 0, 'Z': 1},
        },
    ];
    expect(_parse(samples), isNull);
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (`suunto_dive_route.dart` does not exist)

Run: `flutter test test/core/services/suunto_cloud/suunto_dive_route_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart'
    show kMaxNavTrackPointCount;

/// The inertial route a Suunto Nautic S or Ocean records and the Suunto app
/// exports as `DiveRoute` (issue #1445): metres relative to
/// [originLatitude]/[originLongitude], the export's `DiveRouteOrigin`.
///
/// The watch itself stores only raw 10 Hz IMU data; the app dead-reckons
/// this route afterwards, so a JSON export is its only source.
class SuuntoDiveRoute {
  const SuuntoDiveRoute({
    required this.points,
    this.originLatitude,
    this.originLongitude,
  });

  final List<NavTrackPoint> points;

  /// `DiveRouteOrigin` in degrees, where east 0 / north 0 sits on the map.
  /// Null when the export carried no usable origin.
  final double? originLatitude;
  final double? originLongitude;
}

/// Reads `DiveRoute` samples into a [SuuntoDiveRoute].
///
/// Axis convention: X is east and Y is north. Z is depth, with its sign
/// calibrated from the recording itself: when most samples are negative
/// the device wrote Z up-positive and every value is negated, so depth is
/// always positive down whichever way the export writes it.
class SuuntoDiveRouteParser {
  const SuuntoDiveRouteParser._();

  /// Null when fewer than two usable points remain, or more than a track
  /// can store; the dive still imports either way.
  ///
  /// [timestampMs] reads a sample's `TimeISO8601` as wall-clock-as-UTC
  /// milliseconds, and [clockCorrection] is the shift the dive start got,
  /// so the route sits on the same time base as the dive's profile.
  static SuuntoDiveRoute? parse(
    List<Map<String, dynamic>> samples, {
    required int? Function(Map<String, dynamic> sample) timestampMs,
    required Duration clockCorrection,
    double? originLatitude,
    double? originLongitude,
  }) {
    final raw = <({int timestamp, double x, double y, double z})>[];
    int? lastTimestamp;
    for (final sample in samples) {
      final route = sample['DiveRoute'];
      if (route is! Map) continue;
      final x = _finite(route['X']);
      final y = _finite(route['Y']);
      final z = _finite(route['Z']);
      if (x == null || y == null || z == null) continue;
      final ms = timestampMs(sample);
      if (ms == null) continue;
      final timestamp = ((ms + clockCorrection.inMilliseconds) / 1000)
          .floor();
      if (lastTimestamp != null && timestamp < lastTimestamp) continue;
      lastTimestamp = timestamp;
      raw.add((timestamp: timestamp, x: x, y: y, z: z));
    }

    if (raw.length < 2 || raw.length > kMaxNavTrackPointCount) return null;

    final negatives = raw.where((r) => r.z < 0).length;
    final sign = negatives * 2 > raw.length ? -1.0 : 1.0;

    return SuuntoDiveRoute(
      points: List.unmodifiable([
        for (final r in raw)
          NavTrackPoint(
            timestamp: r.timestamp,
            north: r.y,
            east: r.x,
            depth: _depth(sign * r.z),
          ),
      ]),
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
  }

  static double _depth(double value) => value < 0 ? 0.0 : value;

  static double? _finite(Object? value) {
    if (value is! num) return null;
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
}
```

- [ ] **Step 4: Run, expect PASS.** Same command.
- [ ] **Step 5: Commit** `feat(suunto): parse the DiveRoute samples into a route`

---

### Task 2: Attach the route to SuuntoParsedDive, and type the not-a-dive rejection

**Files:**
- Modify: `lib/core/services/suunto_cloud/suunto_dive_parser.dart` (`SuuntoParsedDive` at :12-51, `parse` at :65-178)
- Modify: `lib/core/services/suunto_cloud/suunto_api_exception.dart`
- Modify: `lib/core/services/suunto_cloud/suunto_sml_normalizer.dart:58-63`
- Test: `test/core/services/suunto_cloud/suunto_dive_parser_test.dart` (new group at the end of `main`)
- Test: `test/core/services/suunto_cloud/suunto_sml_normalizer_test.dart`

**Interfaces:**
- Consumes: Task 1 `SuuntoDiveRouteParser.parse`.
- Produces:
  - `SuuntoParsedDive.route` (`SuuntoDiveRoute?`), carried by `copyWith`.
  - `class SuuntoNotADiveException extends SuuntoApiException`.

- [ ] **Step 1: Write the failing tests** (parser test file, new group)

```dart
  group('DiveRoute', () {
    Map<String, dynamic> headerAt(String dateTime) => {
      'DateTime': dateTime,
      'ActivityType': 51,
      'Device': {'Name': 'Ylivieska', 'SerialNumber': 'NS-1'},
      'DiveTime': 1800,
    };

    List<Map<String, dynamic>> samplesAt(String hhmm, String offset) => [
      {
        'TimeISO8601': '2026-04-19T$hhmm:40.000$offset',
        'Depth': 1.2,
        'DiveEvents': const {'DiveStatus': true},
        'DiveRouteOrigin': const {'Latitude': 47.3, 'Longitude': -2.9},
        'DiveRoute': const {'X': 0.0, 'Y': 0.0, 'Z': 1.2},
      },
      {
        'TimeISO8601': '2026-04-19T$hhmm:41.000$offset',
        'Depth': 1.8,
        'DiveRoute': const {'X': 0.4, 'Y': 0.9, 'Z': 1.8},
      },
    ];

    test('carries the route on the parsed dive, on the dive start clock', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('13:44', '+02:00'),
      );

      final route = result.route!;
      expect(route.points, hasLength(2));
      expect(
        route.points.first.timestamp,
        result.dive.startTime.millisecondsSinceEpoch ~/ 1000,
      );
      expect(route.originLatitude, 47.3);
      expect(route.originLongitude, -2.9);
    });

    test('shifts the route with the dive when the sample clock runs late '
        '(#2604)', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('15:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
      expect(
        result.route!.points.first.timestamp,
        result.dive.startTime.millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('has no route when the export carries no DiveRoute samples', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: [
          {
            'TimeISO8601': '2026-04-19T13:44:40.000+02:00',
            'Depth': 1.2,
            'DiveEvents': const {'DiveStatus': true},
          },
        ],
      );
      expect(result.route, isNull);
    });

    test('copyWith keeps the route', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('13:44', '+02:00'),
      );
      expect(result.copyWith(notes: 'n').route, same(result.route));
    });
  });
```

Normalizer test (add to its existing file):

```dart
  test('throws SuuntoNotADiveException for a non-dive activity', () {
    expect(
      () => SuuntoSmlNormalizer.parse({
        'DeviceLog': {
          'Header': {'ActivityType': 3},
          'Samples': const [],
        },
      }),
      throwsA(isA<SuuntoNotADiveException>()),
    );
  });

  test('passes DiveRoute through from the cloud Sample attribute', () {
    final export = SuuntoSmlNormalizer.parse({
      'Summary': {
        'Samples': [
          {
            'Attributes': {
              'suunto/sml': {
                'Header': {'ActivityType': 51},
              },
            },
          },
        ],
      },
      'Data': {
        'Samples': [
          {
            'TimeISO8601': '2026-04-19T10:00:00.000Z',
            'Attributes': {
              'suunto/sml': {
                'Sample': {
                  'DiveRoute': {'X': 1.0, 'Y': 2.0, 'Z': 3.0},
                },
              },
            },
          },
        ],
      },
    });
    expect(export.samples.single['DiveRoute'], {'X': 1.0, 'Y': 2.0, 'Z': 3.0});
  });
```

- [ ] **Step 2: Run, expect FAIL** (no `route` getter, no `SuuntoNotADiveException`).

Run: `flutter test test/core/services/suunto_cloud/suunto_dive_parser_test.dart test/core/services/suunto_cloud/suunto_sml_normalizer_test.dart`

- [ ] **Step 3: Implement**

`suunto_api_exception.dart`, append:

```dart
/// The export is a Suunto activity, but not a dive (`ActivityType` is not
/// scuba). A subtype so existing `on SuuntoApiException` handlers still
/// catch it, while a file import can tell the diver why it was skipped.
class SuuntoNotADiveException extends SuuntoApiException {
  const SuuntoNotADiveException(super.message);
}
```

`suunto_sml_normalizer.dart`: replace the `throw SuuntoApiException('Suunto JSON: not a dive activity ...')` with `throw SuuntoNotADiveException(...)` (same message).

`suunto_dive_parser.dart`:

1. Import `suunto_dive_route.dart`.
2. Add a `route` field to `SuuntoParsedDive`:
   - Constructor parameter `this.route`.
   - Field doc: `/// The recorded underwater route (DiveRoute), when the export carries one (issue #1445).` then `final SuuntoDiveRoute? route;`
   - `copyWith` takes `SuuntoDiveRoute? route` and uses `route: route ?? this.route`.
3. In `parse`, hoist the clock correction into a local and use it for `startTime`:

```dart
    final clockCorrection = _sampleClockCorrection(
      headerStart,
      headerOffset,
      firstPass.firstSampleMs,
    );
    final startTime = diveStartMs != null
        ? DateTime.fromMillisecondsSinceEpoch(
            diveStartMs,
            isUtc: true,
          ).add(clockCorrection)
        : (headerStart ?? DateTime.now().toUtc());
```

4. In the final `return SuuntoParsedDive(...)`, add:

```dart
      route: SuuntoDiveRouteParser.parse(
        samples,
        timestampMs: _parseTimestampMs,
        clockCorrection: clockCorrection,
        originLatitude: firstPass.latitude,
        originLongitude: firstPass.longitude,
      ),
```

(`firstPass.latitude/longitude` is the `DiveRouteOrigin` that `_FirstPass` already reads, with null island filtered out.)

- [ ] **Step 4: Run, expect PASS.** Run the whole `test/core/services/suunto_cloud/` directory.
- [ ] **Step 5: Commit** `feat(suunto): carry the DiveRoute on the parsed dive`

---

### Task 3: Explicit anchor on insertImportedRoute

**Files:**
- Modify: `lib/features/nav_track/data/repositories/nav_track_repository.dart:106-150`
- Test: `test/features/nav_track/data/repositories/nav_track_repository_test.dart` (group `insertImportedRoute`)

**Interfaces:**
- Produces: `insertImportedRoute(..., double? anchorLatitude, double? anchorLongitude)`. When both are non-null they are stored as the anchor, and the site and entry-fix fallback is skipped.

- [ ] **Step 1: Write the failing tests**

```dart
    test('an explicit anchor wins over the dive\'s entry fix (a Suunto '
        'route is relative to its own DiveRouteOrigin)', () async {
      await _insertDiveWithEntryLocation(
        db,
        'd1',
        latitude: 47.2,
        longitude: 8.4,
      );

      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'suunto:NS-1:2026-04-19T13:44:40.000Z',
        diveId: 'd1',
        anchorLatitude: 47.25,
        anchorLongitude: 8.45,
      );

      expect((await repo.getById(id))!.anchor, const GeoPoint(47.25, 8.45));
    });

    test('an explicit anchor wins over a chosen site', () async {
      await _insertSite(db, 's1', latitude: 10, longitude: 20);

      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'r',
        siteId: 's1',
        anchorLatitude: 11,
        anchorLongitude: 21,
      );

      expect((await repo.getById(id))!.anchor, const GeoPoint(11, 21));
    });

    test('a half-given anchor is ignored and the fallback applies', () async {
      await _insertDiveWithEntryLocation(
        db,
        'd1',
        latitude: 47.2,
        longitude: 8.4,
      );

      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'r',
        diveId: 'd1',
        anchorLatitude: 1,
      );

      expect((await repo.getById(id))!.anchor, const GeoPoint(47.2, 8.4));
    });
```

- [ ] **Step 2: Run, expect FAIL** (no such named parameter).

Run: `flutter test test/features/nav_track/data/repositories/nav_track_repository_test.dart`

- [ ] **Step 3: Implement**
  - Add `double? anchorLatitude, double? anchorLongitude` to the signature.
  - Extend the doc comment: "An explicit [anchorLatitude]/[anchorLongitude] pair, given when the source file carries its own origin fix (a Suunto `DiveRouteOrigin`), is stored as-is and skips both fallbacks."
  - Change the anchor resolution to:

```dart
      final explicit = anchorLatitude != null && anchorLongitude != null
          ? GeoPoint(anchorLatitude, anchorLongitude)
          : null;
      var anchor =
          explicit ??
          (siteId == null
              ? null
              : (await _siteRepository.getSiteById(siteId))?.location);
```

  and guard the entry-fix fallback with `explicit == null &&` in its `if`.
- [ ] **Step 4: Run, expect PASS** (the whole file, so the existing anchor tests still hold).
- [ ] **Step 5: Commit** `feat(nav-track): let an import supply the route's anchor`

---

### Task 4: SuuntoRouteWriter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/suunto_route_writer.dart`
- Test: `test/features/import_wizard/data/adapters/suunto_route_writer_test.dart`

**Interfaces:**
- Consumes: Task 2 `SuuntoParsedDive.route`; Task 3 anchor parameters; `NavTrackRepository.getForDive`, `.replace`; `normalizedIdentityPart` from `cloud_computer_identity.dart`.
- Produces:
  - `class SuuntoRouteWriter { SuuntoRouteWriter({NavTrackRepository? repository}); static String sourceRefFor(SuuntoParsedDive parsed); Future<String?> attach(String diveId, SuuntoParsedDive parsed); }`
  - `attach` returns the new route id, or null when there is no route or the write failed. It never throws.

- [ ] **Step 1: Write the failing tests** (real test database, like `nav_track_repository_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_route.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../../helpers/test_database.dart';

SuuntoParsedDive _parsed({
  SuuntoDiveRoute? route,
  String? serial = 'NS-1',
  DateTime? start,
}) => SuuntoParsedDive(
  dive: DownloadedDive(
    startTime: start ?? DateTime.utc(2026, 4, 19, 13, 44, 40),
    durationSeconds: 1800,
    maxDepth: 12,
    profile: const [],
  ),
  deviceName: 'Suunto Nautic S',
  serialNumber: serial,
  route: route,
);

SuuntoDiveRoute _route({double? lat = 47.3, double? lon = -2.9}) =>
    SuuntoDiveRoute(
      points: const [
        NavTrackPoint(timestamp: 1776606280, north: 0, east: 0, depth: 1),
        NavTrackPoint(timestamp: 1776606281, north: 1, east: 1, depth: 2),
      ],
      originLatitude: lat,
      originLongitude: lon,
    );

Future<void> _insertDive(AppDatabase db, String id, {double? lat, double? lon}) =>
    db.customStatement(
      'INSERT INTO dives (id, dive_date_time, entry_latitude, '
      'entry_longitude, created_at, updated_at) '
      "VALUES ('$id', 1700000000000, ${lat ?? 'NULL'}, ${lon ?? 'NULL'}, 1, 1)",
    );

void main() {
  late AppDatabase db;
  late NavTrackRepository repo;
  late SuuntoRouteWriter writer;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    repo = NavTrackRepository();
    writer = SuuntoRouteWriter(repository: repo);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('sourceRef is device serial plus the dive start', () {
    expect(
      SuuntoRouteWriter.sourceRefFor(_parsed()),
      'suunto:NS-1:2026-04-19T13:44:40.000Z',
    );
    expect(
      SuuntoRouteWriter.sourceRefFor(_parsed(serial: null)),
      'suunto:Suunto Nautic S:2026-04-19T13:44:40.000Z',
    );
  });

  test('does nothing for a dive without a route', () async {
    await _insertDive(db, 'd1');
    expect(await writer.attach('d1', _parsed()), isNull);
    expect(await repo.getForDive('d1'), isEmpty);
  });

  test('inserts a primary Suunto route anchored at DiveRouteOrigin', () async {
    await _insertDive(db, 'd1', lat: 10, lon: 20);
    final id = await writer.attach('d1', _parsed(route: _route()));

    final stored = (await repo.getForDive('d1')).single;
    expect(stored.id, id);
    expect(stored.source, NavTrackSource.suuntoRoute);
    expect(stored.isPrimary, isTrue);
    expect(stored.deviceName, 'Suunto Nautic S');
    expect(stored.anchor, const GeoPoint(47.3, -2.9));
  });

  test('falls back to the dive entry fix when the export had no origin',
      () async {
    await _insertDive(db, 'd1', lat: 10, lon: 20);
    await writer.attach('d1', _parsed(route: _route(lat: null, lon: null)));

    expect((await repo.getForDive('d1')).single.anchor, const GeoPoint(10, 20));
  });

  test('a re-import replaces the same Suunto route, keeping one primary',
      () async {
    await _insertDive(db, 'd1');
    final first = await writer.attach('d1', _parsed(route: _route()));
    final second = await writer.attach('d1', _parsed(route: _route()));

    final routes = await repo.getForDive('d1');
    expect(routes.map((r) => r.id), [second]);
    expect(routes.single.isPrimary, isTrue);
    expect(second, isNot(first));
  });

  test('another source keeps primary; the Suunto route is secondary',
      () async {
    await _insertDive(db, 'd1');
    final seacraft = await repo.insertImportedRoute(
      points: _route().points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
      diveId: 'd1',
    );
    final suunto = await writer.attach('d1', _parsed(route: _route()));

    final routes = {for (final r in await repo.getForDive('d1')) r.id: r};
    expect(routes[seacraft]!.isPrimary, isTrue);
    expect(routes[suunto]!.isPrimary, isFalse);
  });

  test('a failed write is logged and returns null, never throws', () async {
    // No dive row: the foreign key rejects the insert.
    expect(await writer.attach('missing', _parsed(route: _route())), isNull);
  });
}
```

(When implementing, confirm the domain getter names `NavTrack.anchor` and `NavTrack.deviceName` against `lib/features/nav_track/domain/entities/nav_track.dart`, and adjust the test if they differ.)

- [ ] **Step 2: Run, expect FAIL** (missing file).

Run: `flutter test test/features/import_wizard/data/adapters/suunto_route_writer_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/import_wizard/data/adapters/cloud_computer_identity.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes a Suunto dive's recorded route (issue #1445) onto the dive it was
/// imported with, for both the Suunto Cloud and the Suunto JSON file
/// import.
///
/// The dive is already saved when this runs, so a failure is logged and
/// swallowed: losing the route must never fail the import or stop the
/// dives after this one.
class SuuntoRouteWriter {
  SuuntoRouteWriter({NavTrackRepository? repository})
    : _repository = repository ?? NavTrackRepository();

  static final _log = LoggerService.forClass(SuuntoRouteWriter);

  final NavTrackRepository _repository;

  /// A key that is the same every time the same dive is imported: the
  /// device (serial, else model name) and the dive's start.
  static String sourceRefFor(SuuntoParsedDive parsed) {
    final device =
        normalizedIdentityPart(parsed.serialNumber) ??
        normalizedIdentityPart(parsed.deviceName) ??
        'unknown';
    return 'suunto:$device:${parsed.dive.startTime.toIso8601String()}';
  }

  /// Links [parsed]'s route to [diveId]. A Suunto route from an earlier
  /// import of the same dive is replaced (taking over its primary role)
  /// rather than duplicated. Returns the new route id, or null when there
  /// is no route or the write failed.
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async {
    final route = parsed.route;
    if (route == null) return null;
    try {
      final sourceRef = sourceRefFor(parsed);
      final previous = [
        for (final r in await _repository.getForDive(diveId))
          if (r.source == NavTrackSource.suuntoRoute && r.sourceRef == sourceRef)
            r.id,
      ];
      final id = await _repository.insertImportedRoute(
        points: route.points,
        source: NavTrackSource.suuntoRoute,
        sourceRef: sourceRef,
        deviceName: parsed.deviceName,
        diveId: diveId,
        anchorLatitude: route.originLatitude,
        anchorLongitude: route.originLongitude,
      );
      for (final oldId in previous) {
        await _repository.replace(oldId, withRouteId: id);
      }
      return id;
    } catch (e, st) {
      _log.error(
        'Could not attach the Suunto route to dive $diveId',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
```

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(import-wizard): write a Suunto route onto its imported dive`

---

### Task 5: Extract SuuntoDiveImportCore and attach routes on every write path

**Files:**
- Create: `lib/features/import_wizard/data/adapters/suunto_dive_import_core.dart`
- Modify: `lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart` (becomes about 120 lines)
- Modify: `lib/core/router/app_router.dart:1927-1949` (pass `routeWriter`)
- Test: `test/features/import_wizard/data/adapters/suunto_dive_import_core_route_test.dart`

**Interfaces:**
- Consumes: Task 4 `SuuntoRouteWriter`.
- Produces:

```dart
abstract class SuuntoDiveImportCore implements ImportSourceAdapter {
  SuuntoDiveImportCore({
    required DiveImportService importService,
    required DiveComputerRepository computerRepository,
    required DiveRepository diveRepository,
    required DiveConsolidationService consolidationService,
    required String diverId,
    SuuntoRouteWriter? routeWriter,
    WidgetRef? ref,
  });
  @protected WidgetRef? get ref;
  @protected String todayIsoDate();
  void setParsedDives(List<SuuntoParsedDive> dives);
  // implements: resetState (clears dives + computers; subclasses call super),
  // supportedDuplicateActions, duplicateActionsFor, buildBundle,
  // checkDuplicates, performImport.
  // abstract: sourceType, displayName, defaultTagName, acquisitionSteps.
}
```

`buildBundle` uses `sourceType` for `ImportSourceInfo.type` (today it hard-codes `suuntoCloud`).

- [ ] **Step 1: Write the failing route tests.** The file reuses the cloud adapter's generated mocks with `import 'suunto_cloud_adapter_test.mocks.dart';` (no codegen). It drives a `SuuntoCloudAdapter` built with `routeWriter: recorder`.

```dart
class _RecordingRouteWriter implements SuuntoRouteWriter {
  final attached = <(String, SuuntoParsedDive)>[];

  @override
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async {
    attached.add((diveId, parsed));
    return 'route-$diveId';
  }
}
```

Copy the `setUp`, `computerFor` and `stubImportAsNew` from `suunto_cloud_adapter_test.dart:66-115` verbatim. Build the bundle with `adapter.setParsedDives([...]); await adapter.buildBundle(); await adapter.checkDuplicates(bundle)`, as the existing `performImport()` tests in that file do. Copy their stubbing of `detectDuplicate`, `resolveConflict`, `importSingleDiveAsNew` and `_consolidationService.apply` for each path. Tests:

- **new dive:** `performImport` with no duplicate gives `recorder.attached` == `[('new-dive-id', parsed)]`.
- **skip:** a duplicate with `DuplicateAction.skip` leaves `recorder.attached` empty.
- **replace source:** a duplicate matched to `'existing-1'` with `DuplicateAction.replaceSource` gives `attached` == `[('existing-1', parsed)]`.
- **consolidate (folded):** `apply` succeeds, so `attached` == `[('existing-1', parsed)]` (the target, not the folded-away new dive).
- **consolidate (kept standalone):** `apply` throws `UnreadableSeriesException`, so `attached` == `[('new-dive-id', parsed)]`.
- **consolidate (same computer):** the target's computer id equals the resolved computer, so `attached` is empty.
- **counts unaffected:** a writer whose `attach` returns null yields the same `importedCounts`/`updatedCount` as one that returns an id.

Also extend `suunto_cloud_adapter_test.dart`'s `buildBundle()` group with: `expect(bundle.source.type, ImportSourceType.suuntoCloud)` (guards the `sourceType` refactor).

- [ ] **Step 2: Run, expect FAIL** (`routeWriter` is not a parameter).

Run: `flutter test test/features/import_wizard/data/adapters/suunto_dive_import_core_route_test.dart`

- [ ] **Step 3: Implement the extraction.** Move these members verbatim from `suunto_cloud_adapter.dart` into `SuuntoDiveImportCore`, renaming only where noted:
  - `_ConsolidateOutcome`, `_ConsolidateResult`, `_log` (use `LoggerService.forClass(SuuntoDiveImportCore)`)
  - the five dependency fields plus `_diverId`
  - `_parsedDives`, `_computersByKey`, `setParsedDives`
  - `supportedDuplicateActions`, `duplicateActionsFor`
  - `buildBundle`, with `type: sourceType` in place of `ImportSourceType.suuntoCloud`
  - `checkDuplicates`, `performImport`, `_fillNotes`
  - `_ensureComputers`, `_computerCacheKey`, `_computerFor`, `_resolveComputer`, `_diveToEntityItem`, `_consolidateDive`

  Add `final SuuntoRouteWriter _routeWriter;`, defaulting to `routeWriter ?? SuuntoRouteWriter()`. Expose `ref` through `@protected WidgetRef? get ref => _ref;`.

  `resetState()` in the core:

```dart
  @override
  @mustCallSuper
  void resetState() {
    _computersByKey.clear();
    _parsedDives = [];
  }
```

  `todayIsoDate()` holds the date formatting that `defaultTagName` uses today.

  Add one call after every `_fillNotes` in `performImport`, so each settled dive id also gets its route:
  - consolidated: `await _routeWriter.attach(matchResult.diveId, parsed);`
  - keptStandalone: `await _routeWriter.attach(keptId, parsed);`
  - replaceSource: `await _routeWriter.attach(matchResult.diveId, parsed);`
  - new: `await _routeWriter.attach(diveId, parsed);`

  Update the class doc comment to say the core is shared by the cloud and file adapters.

  `SuuntoCloudAdapter` becomes:

```dart
class SuuntoCloudAdapter extends SuuntoDiveImportCore {
  SuuntoCloudAdapter({
    required super.importService,
    required super.computerRepository,
    required super.diveRepository,
    required super.consolidationService,
    required super.diverId,
    super.routeWriter,
    super.ref,
  });

  SuuntoCloudClient? _client;
  void setClient(SuuntoCloudClient client) => _client = client;
  SuuntoCloudClient? get client => _client;

  @override
  void resetState() {
    super.resetState();
    _client = null;
    final r = ref;
    if (r == null) return;
    r.invalidate(suuntoCloudSignedInProvider);
    r.invalidate(suuntoCloudDivesFetchedProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.suuntoCloud;

  @override
  String get displayName => 'Suunto Cloud';

  @override
  String get defaultTagName => 'Suunto Cloud Import ${todayIsoDate()}';

  // acquisitionSteps: unchanged, moved verbatim.
}
```

  Keep the four top-level providers and their doc comments in `suunto_cloud_adapter.dart`.

  In `app_router.dart`'s `_SuuntoCloudImportWizardRoute`, pass `routeWriter: SuuntoRouteWriter(repository: ref.watch(navTrackRepositoryProvider)),`.
- [ ] **Step 4: Run, expect PASS.** Run the new test, `suunto_cloud_adapter_test.dart`, `suunto_cloud_adapter_notes_test.dart`, and `test/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps_test.dart`. All existing tests must pass unchanged, since they are the safety net for the move.
- [ ] **Step 5:** Run `flutter analyze lib/features/import_wizard lib/core/router` and expect no issues.
- [ ] **Step 6: Commit** `refactor(import-wizard): share the Suunto import core and attach routes on import`

---

### Task 6: Reading a Suunto JSON file

**Files:**
- Create: `lib/core/services/suunto_cloud/suunto_json_file_reader.dart`
- Test: `test/core/services/suunto_cloud/suunto_json_file_reader_test.dart`

**Interfaces:**
- Consumes: Task 2 `SuuntoNotADiveException`.
- Produces:

```dart
class SuuntoJsonFile { const SuuntoJsonFile({required String name, required Uint8List bytes}); }
enum SuuntoFileRejection { notJson, notSuuntoExport, notADive }
class SuuntoFileReadResult { final SuuntoJsonFile file; final SuuntoParsedDive? dive; final SuuntoFileRejection? rejection; }
SuuntoFileReadResult readSuuntoJsonFile(SuuntoJsonFile file);
```

- [ ] **Step 1: Write the failing tests.** Test data: a minimal `DeviceLog` export built in Dart and encoded with `utf8.encode(jsonEncode(...))`. Write a helper `Uint8List deviceLogBytes({int activityType = 51, bool withRoute = true})` producing:
  - Header: `ActivityType`, `DateTime: '2026-04-19T13:44:00.000+02:00'`, `Device {Name: 'Ylivieska', SerialNumber: 'NS-1'}`, `DiveTime: 60`
  - Samples: two, each with `TimeISO8601`, `Depth`, and `DiveRoute`; the first with `DiveEvents.DiveStatus: true` and `DiveRouteOrigin`.

  Cases:
  - **app export:** `dive` is non-null, `rejection` is null, `dive!.route!.points` has length 2.
  - **BOM:** the same bytes prefixed by `[0xEF, 0xBB, 0xBF]` read fine.
  - **invalid bytes:** `utf8.encode('not json')` gives `rejection == notJson` and `dive` null.
  - **unrelated JSON:** `{"type":"FeatureCollection"}` gives `notSuuntoExport`.
  - **JSON array:** `[1,2]` gives `notSuuntoExport`.
  - **non-dive:** `activityType: 3` gives `notADive`.
  - **wrong shape:** `DeviceLog` whose `Samples` is a string gives `notSuuntoExport`, never a thrown `TypeError`.

  Also write the synthetic export to the scratchpad. Task 0 and Task 11 use it as `suunto-sample.json`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_sml_normalizer.dart';

/// One file picked, shared or dropped for the Suunto JSON import.
class SuuntoJsonFile {
  const SuuntoJsonFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Why a picked file was not imported, for the file step to explain.
enum SuuntoFileRejection { notJson, notSuuntoExport, notADive }

/// A picked file, read: either a [dive] or the [rejection] that skipped it.
class SuuntoFileReadResult {
  const SuuntoFileReadResult.dive(this.file, SuuntoParsedDive this.dive)
    : rejection = null;
  const SuuntoFileReadResult.rejected(
    this.file,
    SuuntoFileRejection this.rejection,
  ) : dive = null;

  final SuuntoJsonFile file;
  final SuuntoParsedDive? dive;
  final SuuntoFileRejection? rejection;
}

/// Reads a Suunto app "export as JSON" file (the `DeviceLog` shape) or a
/// saved cloud `sml` export into a dive, the same way the cloud import
/// does once it has downloaded one.
SuuntoFileReadResult readSuuntoJsonFile(SuuntoJsonFile file) {
  final Object? decoded;
  try {
    var text = utf8.decode(file.bytes);
    if (text.startsWith('\u{FEFF}')) text = text.substring(1);
    decoded = jsonDecode(text);
  } on FormatException {
    return SuuntoFileReadResult.rejected(file, SuuntoFileRejection.notJson);
  }
  if (decoded is! Map<String, dynamic>) {
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  }
  try {
    final export = SuuntoSmlNormalizer.parse(decoded);
    return SuuntoFileReadResult.dive(
      file,
      SuuntoDiveParser.parse(header: export.header, samples: export.samples),
    );
  } on SuuntoNotADiveException {
    return SuuntoFileReadResult.rejected(file, SuuntoFileRejection.notADive);
  } on SuuntoApiException {
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  } on TypeError {
    // A JSON file whose keys match but whose values have the wrong shape.
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  }
}
```

  Write the BOM literal as a `\u{FEFF}` escape built in source, never the raw character. Remember that the Write tool decodes backslash-u escapes (memory `nul-escape`), so write this line with a sed or python edit and check it with `grep -c 'FEFF'`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(suunto): read a Suunto JSON export file into a dive`

---

### Task 7: Detect Suunto JSON as a hand-off format

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart`
- Modify: `lib/features/universal_import/data/services/format_detector.dart:30-78`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart:250,306,322,411`
- Modify: `lib/features/import_wizard/domain/models/import_file_outcome.dart`, `lib/features/import_wizard/data/adapters/universal_adapter.dart:1282`
- Test: `test/features/universal_import/data/services/format_detector_test.dart` (add a group); the providers test for `loadFileFromBytes` (find it with `grep -rln "loadFileFromBytes" test/features/universal_import`)

**Interfaces:**
- Produces:
  - `ImportFormat.suuntoJson` (`displayName` 'Suunto JSON', `isSupported` false)
  - `bool get isHandoff` (true for `navTrack` and `suuntoJson`)
  - `ImportFileOutcome.isSuuntoJson`

- [ ] **Step 1: Write the failing tests**
  - **Detector, positive cases:** each of these returns `suuntoJson` with `sourceApp == SourceApp.suunto`:
    - `{"DeviceLog":{"Header":{}}}`
    - the same text with a UTF-8 BOM and leading whitespace
    - a cloud-shaped `{"Summary":{"Samples":[{"Attributes":{"suunto/sml":{}}}]},"Data":{}}`
  - **Detector, negative cases:**
    - `{"type":"FeatureCollection"}` returns `unknown`, never `suuntoJson`.
    - Every file under `test/fixtures/universal_import/` and `test/fixtures/gps_tracks/` is never detected as `suuntoJson`. Loop over `Directory(p.join('test', 'fixtures', ...)).listSync(recursive: true)`.
  - **Enum:** `ImportFormat.suuntoJson.isSupported` is false and `isHandoff` is true. `ImportFormat.navTrack.isHandoff` is true and `ImportFormat.uddf.isHandoff` is false.
  - **Providers:** `loadFileFromBytes` on Suunto JSON bytes keeps the file and stays on `ImportWizardStep.fileSelection`, mirroring the existing navTrack test (find that test by grepping for `navTrack` in the providers' test).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**

`import_enums.dart`: add the value after `navTrack` with this doc comment:

```dart
  /// A Suunto app "export as JSON" (or a saved cloud sml export). Like
  /// [navTrack] it is a hand-off: the Suunto importer reads it into a
  /// dive the way the Suunto Cloud import does (so its DiveRoute arrives
  /// too, issue #1445), not the universal parser registry.
  suuntoJson,
```

Then `suuntoJson => 'Suunto JSON'` in `displayName`, and:

```dart
  /// Recognised, but imported by a dedicated flow rather than the
  /// universal pipeline: the wizard keeps the file on the file-selection
  /// step and shows that flow's hand-off card, a batch lists it as needing
  /// individual import, and a shared or dropped file opens the flow
  /// directly.
  bool get isHandoff => this == navTrack || this == suuntoJson;
```

`format_detector.dart`: call `_detectSuuntoJson(textContent)` after the XML check, before DL7:

```dart
    // 2a. Suunto app JSON export (a hand-off to the Suunto importer).
    final suuntoJson = _detectSuuntoJson(textContent);
    if (suuntoJson != null) return suuntoJson;
```

```dart
  /// The Suunto app's JSON export (`DeviceLog`) or a saved cloud export
  /// (`suunto/sml`). Matched on the opening brace plus a Suunto-only key in
  /// the peeked text, since a full export runs to megabytes.
  DetectionResult? _detectSuuntoJson(String text) {
    final body = (text.startsWith(_bom) ? text.substring(1) : text)
        .trimLeft();
    if (!body.startsWith('{')) return null;
    if (!body.contains('"DeviceLog"') && !body.contains('"suunto/sml"')) {
      return null;
    }
    return const DetectionResult(
      format: ImportFormat.suuntoJson,
      sourceApp: SourceApp.suunto,
      confidence: 0.95,
    );
  }
```

(Check `DetectionResult`'s constructor fields against `_detectXml`'s SML return at :191-197 and match them.)

`universal_import_providers.dart`:
- Replace each `detection.format == ImportFormat.navTrack` with `detection.format.isHandoff`.
- Replace `detection.format != ImportFormat.navTrack` with `!detection.format.isHandoff`.
- Generalise the surrounding comments to "a hand-off format (a Seacraft ENC route or a Suunto JSON export)".

`import_file_outcome.dart`: add `final bool isSuuntoJson;` (default false), with doc: "True when this file is a Suunto JSON export, which the summary offers to open in the Suunto importer." Then set `isSuuntoJson: f.detection.format == ui.ImportFormat.suuntoJson,` at `universal_adapter.dart:1282`.

Any exhaustive `switch` over `ImportFormat` that `flutter analyze` now flags gets a `suuntoJson` arm matching `navTrack`'s.
- [ ] **Step 4: Run, expect PASS.** Run the detector test, the providers test, and `flutter analyze lib/features/universal_import lib/features/import_wizard`.
- [ ] **Step 5: Commit** `feat(universal-import): recognise a Suunto JSON export as a hand-off`

---

### Task 8: The Suunto file wizard

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (add `suuntoFile` after `suuntoCloud`, doc "A Suunto app JSON export file import.")
- Modify: `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart:390-392` (add `|| widget.adapter.sourceType == ImportSourceType.suuntoFile`)
- Create: `lib/features/import_wizard/data/adapters/suunto_file_adapter.dart`
- Create: `lib/features/import_wizard/presentation/widgets/suunto_file_step.dart`
- Create: `lib/features/import_wizard/presentation/suunto_file_import_navigation.dart`
- Modify: `lib/core/router/app_router.dart` (route and wrapper)
- Modify: 11 ARB files, then `flutter gen-l10n`
- Test: `test/features/import_wizard/data/adapters/suunto_file_adapter_test.dart`, `test/features/import_wizard/presentation/widgets/suunto_file_step_test.dart`

**Interfaces:**
- Consumes: Task 5 core; Task 6 reader.
- Produces:
  - `final suuntoFileDivesReadyProvider = StateProvider<bool>((ref) => false);`
  - `class SuuntoFileAdapter extends SuuntoDiveImportCore { SuuntoFileAdapter({..., List<SuuntoJsonFile> initialFiles = const []}); }`
  - `final suuntoJsonFilePickerProvider = Provider<Future<List<SuuntoJsonFile>> Function()>(...)`
  - `class SuuntoFileStep extends ConsumerStatefulWidget { const SuuntoFileStep({super.key, required this.initialFiles, required this.onDivesRead}); }`
  - `const suuntoFileImportPath = '/transfer/import-file/suunto';`
  - `Future<void> openSuuntoFileImport(BuildContext context, List<SuuntoJsonFile> files)`

**ARB keys (English values; the other 10 locales get real translations, inserted after `navTrack_handoff_reviewTrackButton` in each file):**

| Key | English |
| --- | --- |
| `suuntoFile_step_title` | `Suunto app exports` |
| `suuntoFile_step_description` | `Choose one or more dives exported from the Suunto app as JSON. Dives recorded with a route bring it along.` |
| `suuntoFile_step_chooseFiles` | `Choose files` |
| `suuntoFile_step_readyCount` | `{count, plural, one{{count} dive ready to import} other{{count} dives ready to import}}` (placeholder `count`: `num`) |
| `suuntoFile_step_routeIncluded` | `Includes recorded route` |
| `suuntoFile_step_noRoute` | `No recorded route` |
| `suuntoFile_rejection_notJson` | `Not a JSON file` |
| `suuntoFile_rejection_notSuuntoExport` | `Not a Suunto app export` |
| `suuntoFile_rejection_notADive` | `Not a dive (another activity type)` |
| `suuntoJson_handoff_recognized` | `Suunto dive export recognised` |
| `suuntoJson_handoff_description` | `This file was exported from the Suunto app. The Suunto importer reads it the same way as the Suunto Cloud import, including the dive's recorded route.` |
| `suuntoJson_handoff_importButton` | `Import Suunto dive` |
| `universalImport_summary_importWithSuunto` | `Import with Suunto importer` |

Insert them with one python3.14 script that reads a dict per locale. The script must:
- Anchor on the `navTrack_handoff_reviewTrackButton` line.
- Keep `@suuntoFile_step_readyCount` metadata in `app_en.arb` only, as the other keys' metadata is.
- Write UTF-8 and preserve each file's line endings (check `git diff --numstat` afterwards).

Then run `flutter gen-l10n`.

- [ ] **Step 1: Write the failing adapter test** (`suunto_file_adapter_test.dart`, reusing `suunto_cloud_adapter_test.mocks.dart` and its `setUp` stubs):
  - `sourceType == ImportSourceType.suuntoFile` and `displayName == 'Suunto JSON'`.
  - `defaultTagName` starts with `'Suunto Import '`.
  - `acquisitionSteps` has one step whose `canAdvance` is `suuntoFileDivesReadyProvider`.
  - After `setParsedDives([parsed])`, `buildBundle()` has one dive item and `source.type == ImportSourceType.suuntoFile`.
  - `performImport` with no duplicate calls `importSingleDiveAsNew` once and the recording route writer once.
- [ ] **Step 2: Write the failing widget test** (`suunto_file_step_test.dart`). Pump with the repo's localized test harness (copy the pump helper used by `test/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps_test.dart`) and override `suuntoJsonFilePickerProvider`.
  - **initial files:** `initialFiles` = one valid export (Task 6 helper bytes) plus one `'not json'`. After `pumpAndSettle`:
    - Both file names are shown, with the text `Includes recorded route` and `Not a JSON file`.
    - `onDivesRead` received exactly one dive.
    - `suuntoFileDivesReadyProvider` is true. Read it through `ProviderScope.containerOf`.
  - **picking:** with no initial files, tapping `Choose files` calls the overridden picker, and its single non-dive file shows `Not a dive (another activity type)` with the provider still false.
- [ ] **Step 3: Run both, expect FAIL.**
- [ ] **Step 4: Implement `suunto_file_adapter.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_dive_import_core.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_file_step.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the file step has read at least one dive.
final suuntoFileDivesReadyProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for Suunto app "export as JSON" files (issue
/// #1445): the same dive pipeline as [SuuntoCloudAdapter], fed from files
/// instead of a signed-in account, so a dive's DiveRoute arrives with it.
class SuuntoFileAdapter extends SuuntoDiveImportCore {
  SuuntoFileAdapter({
    required super.importService,
    required super.computerRepository,
    required super.diveRepository,
    required super.consolidationService,
    required super.diverId,
    super.routeWriter,
    super.ref,
    this.initialFiles = const [],
  });

  /// Files handed over by the universal wizard, a share or a drop, read as
  /// soon as the step opens.
  final List<SuuntoJsonFile> initialFiles;

  @override
  void resetState() {
    super.resetState();
    ref?.invalidate(suuntoFileDivesReadyProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.suuntoFile;

  @override
  String get displayName => 'Suunto JSON';

  @override
  String get defaultTagName => 'Suunto Import ${todayIsoDate()}';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Files',
      icon: Icons.description_outlined,
      builder: (context) => SuuntoFileStep(
        initialFiles: initialFiles,
        onDivesRead: setParsedDives,
      ),
      canAdvance: suuntoFileDivesReadyProvider,
      autoAdvance: false,
    ),
  ];
}
```

- [ ] **Step 5: Implement `suunto_file_step.dart`.**
  - **Picker provider:** `suuntoJsonFilePickerProvider` defaults to `pickSuuntoJsonFiles`. That calls `FilePicker.pickFiles(type: FileType.any)`, then for each handle `SuuntoJsonFile(name: f.name, bytes: await f.readAsBytes())`. Confirm the `PlatformFile` getters in the file_picker 12 API; the handle model has no `path` on SAF.
  - **State:** `_results` (`List<SuuntoFileReadResult>`) and `_reading`.
  - **`initState`:** when `initialFiles` is non-empty, read them in `WidgetsBinding.instance.addPostFrameCallback`, because providers can't be modified during build.
  - **`_read(files)`:**
    - Sets `_reading`.
    - Calls `readSuuntoJsonFile` per file, and yields with `await Future<void>.delayed(Duration.zero)` between files so the spinner paints.
    - Stores the results.
    - Calls `widget.onDivesRead([for (r in results) if (r.dive != null) r.dive!])`.
    - Sets `ref.read(suuntoFileDivesReadyProvider.notifier).state = results.any((r) => r.dive != null)`.
  - **UI:**
    - Title (`titleLarge`) and description (`bodyMedium`, `onSurfaceVariant`).
    - An `OutlinedButton.icon` with `Icons.file_open` and the `Choose files` label. While reading, show a 16 px `CircularProgressIndicator` and disable the button.
    - When there are results, `suuntoFile_step_readyCount`, then one `ListTile` per result:
      - leading `Icons.check_circle_outline` (dive) or `Icons.block` (rejected)
      - title: the file name
      - subtitle: the route-included or no-route text, or the rejection text in `colorScheme.error`
    - Wrap everything in a `SingleChildScrollView` with 24 px padding, matching `SuuntoCloudSignInStep`.
- [ ] **Step 6: Implement navigation and the route**

```dart
// suunto_file_import_navigation.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';

/// The Suunto JSON file import wizard (issue #1445).
const suuntoFileImportPath = '/transfer/import-file/suunto';

/// Opens the Suunto file import with [files] already chosen.
Future<void> openSuuntoFileImport(
  BuildContext context,
  List<SuuntoJsonFile> files,
) => context.push(suuntoFileImportPath, extra: files);
```

`app_router.dart`, in the `/transfer` routes after `import-cloud/suunto`:

```dart
              GoRoute(
                path: 'import-file/suunto',
                name: 'importFromFileSuunto',
                builder: (context, state) => _SuuntoFileImportWizardRoute(
                  initialFiles: state.extra is List<SuuntoJsonFile>
                      ? state.extra! as List<SuuntoJsonFile>
                      : const [],
                ),
              ),
```

`_SuuntoFileImportWizardRoute` copies `_SuuntoCloudImportWizardRoute` but builds a `SuuntoFileAdapter(..., routeWriter: SuuntoRouteWriter(repository: ref.watch(navTrackRepositoryProvider)), initialFiles: initialFiles)`.

Add a test to the step test file or a new router test only if the router already has a test that pushes the cloud route; otherwise cover the route in Task 9's hand-off card test.
- [ ] **Step 7: Add the ARB strings, then run `flutter gen-l10n`.**
- [ ] **Step 8: Run, expect PASS.** Run both new tests, then `flutter analyze`.
- [ ] **Step 9: Commit** `feat(import-wizard): add the Suunto JSON file import wizard`

---

### Task 9: Hand-off from the universal wizard, share/drop and the batch summary

**Files:**
- Create: `lib/features/universal_import/presentation/widgets/suunto_json_handoff_card.dart`
- Modify: `lib/features/universal_import/presentation/widgets/file_selection_step.dart:33-46`
- Modify: `lib/shared/services/incoming_file_handler.dart`, `lib/app.dart:426-444`, `lib/shared/widgets/global_drop_target.dart:189-197`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart:714-760` (button and `_importWithSuunto`)
- Test: `test/features/universal_import/presentation/widgets/suunto_json_handoff_card_test.dart`, the existing `incoming_file_handler` test (grep `test/` for `handleIncomingFile`), the existing summary-step test that covers `import-summary-import-as-route` (grep for that key)

**Interfaces:**
- Consumes: Task 8 `openSuuntoFileImport`, `SuuntoJsonFile`; Task 7 `isHandoff`, `isSuuntoJson`.
- Produces: `IncomingFileOutcome.navigateToSuuntoFileImport`; `SuuntoJsonHandoffCard({required Uint8List bytes, required String fileName})`.

- [ ] **Step 1: Write the failing tests**
  - **Hand-off card:** pump the card inside a `MaterialApp.router` with a `GoRouter` whose routes are `/` (the card) and `suuntoFileImportPath` (a stub page that renders the length of `state.extra as List<SuuntoJsonFile>` and the first file's name). The card shows `Suunto dive export recognised`. Tapping the key `suunto-json-handoff-import` lands on the stub with `1` and the file name.
  - **Incoming file handler:** Suunto JSON bytes return `IncomingFileOutcome.navigateToSuuntoFileImport` and reset the notifier. Mirror the existing navTrack case in that test file.
  - **Summary step:** an outcome with `isSuuntoJson: true` and a `filePath` shows the key `import-summary-import-with-suunto` and not `import-summary-import-as-route`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**
  - **Hand-off card:** `SuuntoJsonHandoffCard` mirrors `NavTrackHandoffCard`:
    - card key `suunto-json-handoff-card`; icon `Icons.scuba_diving`; strings `suuntoJson_handoff_*`
    - a `FilledButton` with key `suunto-json-handoff-import` whose `onPressed` is `openSuuntoFileImport(context, [SuuntoJsonFile(name: fileName, bytes: bytes)])`
    - doc comment pointing at issue #1445 and at `ImportFormat.isHandoff`
  - **`file_selection_step.dart`:**

```dart
    final format = state.detectionResult?.format;
    final handoffBytes = format != null && format.isHandoff
        ? state.fileBytes
        : null;
    if (handoffBytes != null) {
      final fileName = state.fileName ?? '';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: format == ImportFormat.suuntoJson
            ? SuuntoJsonHandoffCard(bytes: handoffBytes, fileName: fileName)
            : NavTrackHandoffCard(bytes: handoffBytes, fileName: fileName),
      );
    }
```

  - **`incoming_file_handler.dart`:**
    - Add the enum value, documented as "A Suunto JSON export was recognised; push the Suunto file import with the same bytes/fileName."
    - After the navTrack check, add `if (detection.format == ImportFormat.suuntoJson) { notifier.reset(); return IncomingFileOutcome.navigateToSuuntoFileImport; }`.
  - **`app.dart`:** a new case that calls `router.push(suuntoFileImportPath, extra: [SuuntoJsonFile(name: fileName, bytes: bytes)])`, with the same comment style as the wizard case.
  - **`global_drop_target.dart`:** a new case that calls `await openSuuntoFileImport(context, [SuuntoJsonFile(name: fileName, bytes: bytes)]);`.
  - **`import_summary_step.dart`:**
    - Add `canImportWithSuunto = outcome.isSuuntoJson && outcome.filePath != null` and a `TextButton` with key `import-summary-import-with-suunto` and label `universalImport_summary_importWithSuunto`.
    - `_importWithSuunto` reads the file the way `_importAsRoute` does, then calls `openSuuntoFileImport`. On a read error it shows the same snackbar.
- [ ] **Step 4: Run, expect PASS.** Run all three tests and `flutter analyze`.
- [ ] **Step 5: Commit** `feat(universal-import): hand a Suunto JSON export to the Suunto importer`

---

### Task 10: Verify the axis convention against a real export (blocked on #1445 fixtures)

Do not start until K4pisa's files are available (comment on #1445). Tasks 1 to 9 do not depend on this one. The PR is not opened until this task is done (spec, "Rollout gate").

**Files:**
- Create: `test/fixtures/suunto/nautic_s_dive_route.json` (trimmed)
- Test: `test/core/services/suunto_cloud/suunto_dive_route_fixture_test.dart`
- Possibly modify: `lib/core/services/suunto_cloud/suunto_dive_route.dart`, the spec's "Provisional" sentence, `suunto_sml_normalizer.dart` (if the cloud shape keeps `DiveRoute` outside `Sample`)

- [ ] **Step 1:** Inspect a real file with a python3.14 script in the scratchpad. It should print:
  - the top-level keys
  - the keys of the first sample containing `DiveRoute` and the shape of its value
  - the count of `DiveRoute` samples
  - the median interval between them
  - the median of |Z - Depth| over samples carrying both
  - whether a heading channel exists (its key and units)

  If the shape differs from `{X, Y, Z}` inside a sample, stop and bring the finding to the user before changing the design.
- [ ] **Step 2:** The heading check is: for the first 60 s of movement, compare `atan2(dX, dY)` (bearing in the east/north frame) against the compass heading. Agreement within about 20 degrees confirms X east and Y north. A 90-degree offset or a mirror means the mapping changes, with a test.
- [ ] **Step 3:** Trim the fixture with a script:
  - Keep the header and footer.
  - Keep the samples between dive start and 120 s later, plus every 30th sample after that, so the whole path stays in view.
  - Keep `DiveRouteOrigin`.
  - Round the coordinates as the reporter asks, and confirm with them before committing.
  - The trimmed file should be under 300 KB.
- [ ] **Step 4:** Write a fixture test that reads the trimmed file through `readSuuntoJsonFile` and asserts:
  - the point count
  - the first timestamp equals the dive start in seconds
  - the median |depth - profile depth| is under 1.0 m
  - the bearing of the first sustained leg matches the recorded heading (the number found in Step 2)
  - the anchor equals the file's `DiveRouteOrigin`
- [ ] **Step 5:** Update the spec's "Provisional" note to "Verified against <fixture>".
- [ ] **Step 6: Commit** `test(suunto): pin the DiveRoute axis convention to a real Nautic S export`

---

### Task 11: Full verification and after screenshots

- [ ] **Step 1:** `dart format .`
- [ ] **Step 2:** `flutter analyze`, expecting `No issues found`. Infos are fatal in CI.
- [ ] **Step 3:** `flutter test test/architecture/`
- [ ] **Step 4:** Run the affected suites: `test/core/services/suunto_cloud/`, `test/features/import_wizard/`, `test/features/universal_import/`, `test/features/nav_track/`, `test/shared/`. Use a scratchpad TMPDIR, check `df -h /Volumes/fltmp` first, and never pipe through grep for the status.
- [ ] **Step 5:** Run `flutter gen-l10n`, then `git status` to confirm the generated files are clean.
- [ ] **Step 6:** Take the after screenshots with the `run` skill, using the scratchpad `suunto-sample.json`:
  - `03-universal-import-suunto-handoff-after.png` (light) and `-dark`
  - `04-suunto-file-step-after.png` (light, dark, and phone width)
  - `05-dive-3d-recorded-route-after.png` (after importing the sample, the provenance chip shows the recorded route)
- [ ] **Step 7:** Commit any formatting or l10n regeneration as `chore: format and regenerate l10n`. Skip the commit if nothing changed.
