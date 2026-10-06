# GPS Track Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render, import, export, and edit recorded GPS surface tracks, which Submersion has stored since schema v101 but has never drawn.

**Architecture:** A pure-Dart geometry core (Douglas–Peucker simplification, time windowing, speed derivation, bucketed colorization runs) feeds four thin map surfaces through Riverpod providers backed by a level-of-detail cache in the local (unsynced) database. Import and export attach at the repository layer, never at the view. Trim is non-destructive metadata; split writes both children before tombstoning the parent.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod 3, go_router, flutter_map 8.3, flutter_map_tile_caching, latlong2, the `xml` package, `compute()` isolates.

**Spec:** `docs/superpowers/specs/2026-08-07-gps-track-mapping-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **Timestamps are wall-clock-as-UTC.** Track points are epoch **seconds**; track `startTime`/`endTime` are epoch **milliseconds**. Both are the recording device's local wall clock reinterpreted as UTC. Never call `toLocal()` when formatting. Reference implementation: `lib/features/gps_log/presentation/pages/gps_logger_page.dart:239-246`.
- **Units follow diver settings.** Anything displaying a unit goes through `UnitFormatter`, driven by `settingsProvider`. Never hard-code m/ft/kt.
- **No emojis** in code, comments, or documentation.
- **Immutability.** Never mutate a list or object in place; return new instances.
- **`dart format .`** must produce no changes before any commit.
- **`flutter analyze`** must be clean. Never pipe it to `tail` — that masks the exit code.
- **Commit message style:** imperative sentence case, no `feat:`/`fix:` prefix, no `Co-Authored-By` trailer, no Claude Code attribution. Match the existing log ("Add customizable home screen design spec").
- **l10n:** every user-visible string goes in `lib/l10n/arb/app_en.arb` and is translated to **all** supported locales (ar, de, es, fr, he, hu, it, nl, pt, zh).
- **Schema versions:** main DB step is **v145** (main reached v147 by merge time) — re-grep `origin/main` for `currentSchemaVersion` immediately before pushing, because this ladder has had parallel-branch collisions. Local cache DB step is **v10**, renumbered from v9 when the NOAA tide cache claimed 9 first.
- **Worktree:** this work runs in its own git worktree. After creating it, run `git submodule update --init --recursive` then `flutter pub get` before anything else.

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `lib/features/gps_log/domain/track_geometry.dart` | Pure geometry: local projection, Douglas–Peucker, windowing, bounds, speed |
| `lib/features/gps_log/domain/track_colorization.dart` | `TrackColorMode`, `TrackRun`, bucketing into contiguous runs |
| `lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart` | Read/write simplified geometry in the local cache DB |
| `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart` | Hydration, simplification, dive-association providers |
| `lib/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart` | Runs to `PolylineLayer` |
| `lib/features/gps_log/presentation/widgets/track_color_legend.dart` | Legend for the active colorization mode |
| `lib/features/gps_log/presentation/widgets/track_shape_painter.dart` | Tile-less shape fallback for thumbnails |
| `lib/features/gps_log/presentation/widgets/gps_track_thumbnail.dart` | 88x64 non-interactive mini-map per list row |
| `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart` | `/gps-log/:id` |
| `lib/features/gps_log/presentation/pages/gps_track_map_page.dart` | `/gps-log/map` overview |
| `lib/features/gps_log/data/services/track_import/*.dart` | Orchestrator plus GPX, KML, CSV parsers |
| `lib/features/dive_import/data/services/fit/fit_track_extractor.dart` | Harvest the FIT position stream |
| `lib/core/services/export/gpx/gpx_export_service.dart` | GPX document builder plus share/save entry points |

**Modified:**

| Path | Change |
|---|---|
| `lib/core/database/database.dart` | `gps_tracks` +5 columns, `currentSchemaVersion` 142 to 145, migration step |
| `lib/core/database/local_cache_database.dart` | `gps_track_geometry_cache` table, v9 to v10, self-heal |
| `lib/core/utils/unit_formatter.dart` | `formatSpeed` |
| `lib/core/services/export/shared/file_export_utils.dart` | `saveTextToFile` |
| `lib/core/services/export/kml/kml_export_service.dart` | `<gx:Track>` output |
| `lib/core/services/sync/sync_data_serializer.dart` | Serialize the 5 new columns |
| `lib/core/router/app_router.dart` | `/gps-log/map` before `/gps-log/:id` |
| `lib/features/gps_log/data/repositories/gps_track_repository.dart` | `effectivePoints`, trim writes, ordered split |
| `lib/features/gps_log/presentation/pages/gps_logger_page.dart` | Thumbnails, row navigation, map-mode action |
| `lib/features/dive_log/presentation/widgets/dive_locations_map.dart` | Optional `trackRuns` / `trackBounds` |
| `lib/features/dive_log/presentation/widgets/surface_gps_section.dart` | Windowed track, full-track chip, track row |

---

## Phase 1: Schema and Core

No UI. Everything here is unit-testable without pumping a widget.

---

### Task 1: Local projection and Douglas–Peucker simplification

**Files:**
- Create: `lib/features/gps_log/domain/track_geometry.dart`
- Test: `test/features/gps_log/track_geometry_test.dart`

**Interfaces:**
- Consumes: `GpsTrackPoint` from `lib/features/gps_log/domain/entities/gps_track.dart`
- Produces:
  - `({double east, double north}) projectLocal(GpsTrackPoint origin, GpsTrackPoint p)`
  - `List<GpsTrackPoint> simplifyTrack(List<GpsTrackPoint> points, double toleranceMeters)`

Douglas–Peucker needs perpendicular point-to-segment distance, which is awkward on a sphere. Because a dive-day track spans kilometres, not continents, we project to a local flat east/north plane anchored at the track's first point and do the math in metres there. Error over that span is far below the 2 m tightest tolerance.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/track_geometry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

GpsTrackPoint p(double lat, double lon, {int t = 0}) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('projectLocal', () {
    test('projects a degree offset at the equator to known metres', () {
      // 0.001 deg longitude at the equator = 0.001 * 111320.0 = 111.32 m
      // 0.001 deg latitude anywhere       = 0.001 * 111194.93 = 111.19 m
      final origin = p(0.0, 0.0);
      final offset = projectLocal(origin, p(0.001, 0.001));
      expect(offset.east, closeTo(111.32, 0.01));
      expect(offset.north, closeTo(111.19, 0.01));
    });

    test('is zero for the origin itself', () {
      final origin = p(20.5, -87.3);
      final offset = projectLocal(origin, origin);
      expect(offset.east, 0.0);
      expect(offset.north, 0.0);
    });
  });

  group('simplifyTrack', () {
    test('drops a collinear midpoint', () {
      // All three on the equator: the midpoint lies exactly on the chord,
      // so its perpendicular distance is 0 and any tolerance removes it.
      final points = [p(0.0, 0.0), p(0.0, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 1.0);
      expect(result.length, 2);
      expect(result.first.longitude, 0.0);
      expect(result.last.longitude, 0.002);
    });

    test('keeps a midpoint deviating more than the tolerance', () {
      // Chord runs along the equator from lon 0 to lon 0.002. The midpoint
      // sits 0.001 deg north of it = 111.19 m perpendicular deviation.
      final points = [p(0.0, 0.0), p(0.001, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 50.0);
      expect(result.length, 3);
    });

    test('drops a midpoint deviating less than the tolerance', () {
      // Same 111.19 m deviation, but now under a 200 m tolerance.
      final points = [p(0.0, 0.0), p(0.001, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 200.0);
      expect(result.length, 2);
    });

    test('always preserves first and last points', () {
      final points = List.generate(
        100,
        (i) => p(0.0, i * 0.00001, t: i),
      );
      final result = simplifyTrack(points, 1000.0);
      expect(result.length, 2);
      expect(result.first.timestamp, 0);
      expect(result.last.timestamp, 99);
    });

    test('returns the input unchanged for fewer than three points', () {
      expect(simplifyTrack(const [], 10.0), isEmpty);
      expect(simplifyTrack([p(1, 1)], 10.0).length, 1);
      expect(simplifyTrack([p(1, 1), p(2, 2)], 10.0).length, 2);
    });

    test('preserves the original timestamps of surviving points', () {
      final points = [
        p(0.0, 0.0, t: 100),
        p(0.001, 0.001, t: 200),
        p(0.0, 0.002, t: 300),
      ];
      final result = simplifyTrack(points, 50.0);
      expect(result.map((e) => e.timestamp).toList(), [100, 200, 300]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_geometry_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'track_geometry.dart'` / `projectLocal` isn't defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gps_log/domain/track_geometry.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Metres per degree of latitude (constant everywhere on a sphere).
const double _metersPerDegreeLatitude = 111194.93;

/// Projects [p] into a local flat east/north plane in metres, anchored at
/// [origin].
///
/// A dive-day track spans kilometres, so the flat-earth error over that span
/// is far below the tightest simplification tolerance (2 m). Working in this
/// plane makes perpendicular point-to-segment distance trivial, which is what
/// Douglas-Peucker needs.
({double east, double north}) projectLocal(
  GpsTrackPoint origin,
  GpsTrackPoint p,
) {
  final metersPerLon = metersPerDegreeLongitude(origin.latitude);
  return (
    east: (p.longitude - origin.longitude) * metersPerLon,
    north: (p.latitude - origin.latitude) * _metersPerDegreeLatitude,
  );
}

/// Perpendicular distance in metres from [point] to the segment [a]-[b].
double _perpendicularDistance(
  ({double east, double north}) point,
  ({double east, double north}) a,
  ({double east, double north}) b,
) {
  final dx = b.east - a.east;
  final dy = b.north - a.north;
  final lengthSquared = dx * dx + dy * dy;

  // Degenerate segment: fall back to straight point-to-point distance.
  if (lengthSquared == 0) {
    final px = point.east - a.east;
    final py = point.north - a.north;
    return math.sqrt(px * px + py * py);
  }

  // Project onto the segment, clamped to its extent.
  var t = ((point.east - a.east) * dx + (point.north - a.north) * dy) /
      lengthSquared;
  t = t.clamp(0.0, 1.0);

  final projectedX = a.east + t * dx;
  final projectedY = a.north + t * dy;
  final ex = point.east - projectedX;
  final ey = point.north - projectedY;
  return math.sqrt(ex * ex + ey * ey);
}

/// Reduces [points] to the subset whose maximum perpendicular deviation from
/// the retained polyline stays within [toleranceMeters] (Douglas-Peucker).
///
/// First and last points are always retained. Surviving points keep their
/// original timestamps and accuracy - this decimates, it never interpolates.
List<GpsTrackPoint> simplifyTrack(
  List<GpsTrackPoint> points,
  double toleranceMeters,
) {
  if (points.length < 3) return List.unmodifiable(points);

  final origin = points.first;
  final projected = [for (final p in points) projectLocal(origin, p)];
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // Iterative rather than recursive: a 21k-point track would risk a deep
  // recursion on pathological input.
  final stack = <({int start, int end})>[
    (start: 0, end: points.length - 1),
  ];

  while (stack.isNotEmpty) {
    final segment = stack.removeLast();
    var maxDistance = 0.0;
    var maxIndex = -1;

    for (var i = segment.start + 1; i < segment.end; i++) {
      final distance = _perpendicularDistance(
        projected[i],
        projected[segment.start],
        projected[segment.end],
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxIndex != -1 && maxDistance > toleranceMeters) {
      keep[maxIndex] = true;
      stack.add((start: segment.start, end: maxIndex));
      stack.add((start: maxIndex, end: segment.end));
    }
  }

  return List.unmodifiable([
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ]);
}

/// Converts a track point to the [GeoPoint] the shared geo helpers take.
GeoPoint toGeoPoint(GpsTrackPoint p) => GeoPoint(p.latitude, p.longitude);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_geometry_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/domain/track_geometry.dart test/features/gps_log/track_geometry_test.dart
git commit -m "Add local projection and Douglas-Peucker track simplification"
```

---

### Task 2: Time windowing, bounds, and speed

**Files:**
- Modify: `lib/features/gps_log/domain/track_geometry.dart`
- Test: `test/features/gps_log/track_geometry_test.dart` (append groups)

**Interfaces:**
- Consumes: `projectLocal`, `toGeoPoint` from Task 1
- Produces:
  - `List<GpsTrackPoint> windowTrack(List<GpsTrackPoint> points, {required int fromEpochSeconds, required int toEpochSeconds})`
  - `({double minLat, double maxLat, double minLon, double maxLon})? trackBounds(List<GpsTrackPoint> points)`
  - `double speedMpsBetween(GpsTrackPoint a, GpsTrackPoint b)`
  - `double trackDistanceMeters(List<GpsTrackPoint> points)`

`trackBounds` normalizes longitude for antimeridian crossings. A Pacific track running from +179.9 to -179.9 is 0.2 degrees wide, but a naive min/max reports 359.8 degrees and fits the camera to the whole planet.

- [ ] **Step 1: Write the failing test**

Append to `test/features/gps_log/track_geometry_test.dart`, inside `main()`:

```dart
  group('windowTrack', () {
    final points = [
      p(0.0, 0.0, t: 100),
      p(0.0, 0.001, t: 200),
      p(0.0, 0.002, t: 300),
      p(0.0, 0.003, t: 400),
    ];

    test('includes points inside the window inclusively', () {
      final result =
          windowTrack(points, fromEpochSeconds: 200, toEpochSeconds: 300);
      expect(result.map((e) => e.timestamp).toList(), [200, 300]);
    });

    test('returns everything when the window spans the track', () {
      final result =
          windowTrack(points, fromEpochSeconds: 0, toEpochSeconds: 1000);
      expect(result.length, 4);
    });

    test('returns empty when the window misses the track entirely', () {
      final result =
          windowTrack(points, fromEpochSeconds: 500, toEpochSeconds: 600);
      expect(result, isEmpty);
    });

    test('handles an inverted window by returning empty', () {
      final result =
          windowTrack(points, fromEpochSeconds: 300, toEpochSeconds: 200);
      expect(result, isEmpty);
    });
  });

  group('trackBounds', () {
    test('returns null for an empty track', () {
      expect(trackBounds(const []), isNull);
    });

    test('computes a simple bounding box', () {
      final bounds = trackBounds([p(10.0, 20.0), p(12.0, 25.0), p(11.0, 22.0)]);
      expect(bounds!.minLat, 10.0);
      expect(bounds.maxLat, 12.0);
      expect(bounds.minLon, 20.0);
      expect(bounds.maxLon, 25.0);
    });

    test('collapses to a point for a single fix', () {
      final bounds = trackBounds([p(5.0, -3.0)]);
      expect(bounds!.minLat, 5.0);
      expect(bounds.maxLat, 5.0);
      expect(bounds.minLon, -3.0);
      expect(bounds.maxLon, -3.0);
    });

    test('normalizes an antimeridian crossing to a narrow span', () {
      // 179.9 E to 179.9 W is 0.2 deg wide, not 359.8. The unwrapped
      // maxLon exceeds 180, which is what the camera fit expects.
      final bounds = trackBounds([p(0.0, 179.9), p(0.0, -179.9)]);
      expect(bounds!.maxLon - bounds.minLon, closeTo(0.2, 1e-9));
      expect(bounds.minLon, closeTo(179.9, 1e-9));
      expect(bounds.maxLon, closeTo(180.1, 1e-9));
    });

    test('does not unwrap a track that merely spans a wide longitude range', () {
      // A genuine 60 deg span must stay 60 deg, not get folded.
      final bounds = trackBounds([p(0.0, -30.0), p(0.0, 30.0)]);
      expect(bounds!.minLon, -30.0);
      expect(bounds.maxLon, 30.0);
    });
  });

  group('speedMpsBetween', () {
    test('computes metres per second over the elapsed time', () {
      // 0.001 deg latitude = 111.19 m, over 10 s = 11.119 m/s
      final a = p(0.0, 0.0, t: 0);
      final b = p(0.001, 0.0, t: 10);
      expect(speedMpsBetween(a, b), closeTo(11.12, 0.02));
    });

    test('returns zero when no time elapsed', () {
      final a = p(0.0, 0.0, t: 50);
      final b = p(0.001, 0.0, t: 50);
      expect(speedMpsBetween(a, b), 0.0);
    });

    test('returns zero for a backwards timestamp rather than a negative speed', () {
      final a = p(0.0, 0.0, t: 100);
      final b = p(0.001, 0.0, t: 50);
      expect(speedMpsBetween(a, b), 0.0);
    });
  });

  group('trackDistanceMeters', () {
    test('sums consecutive leg distances', () {
      // Two legs of 0.001 deg latitude each = 2 * 111.19 m
      final points = [p(0.0, 0.0), p(0.001, 0.0), p(0.002, 0.0)];
      expect(trackDistanceMeters(points), closeTo(222.39, 0.1));
    });

    test('is zero for fewer than two points', () {
      expect(trackDistanceMeters(const []), 0.0);
      expect(trackDistanceMeters([p(1, 1)]), 0.0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_geometry_test.dart`
Expected: FAIL — `windowTrack` isn't defined.

- [ ] **Step 3: Write the implementation**

Append to `lib/features/gps_log/domain/track_geometry.dart`:

```dart
/// Points whose timestamp falls within [fromEpochSeconds]..[toEpochSeconds]
/// inclusive. Both bounds are wall-clock-as-UTC epoch SECONDS.
List<GpsTrackPoint> windowTrack(
  List<GpsTrackPoint> points, {
  required int fromEpochSeconds,
  required int toEpochSeconds,
}) {
  if (fromEpochSeconds > toEpochSeconds) return const [];
  return List.unmodifiable([
    for (final p in points)
      if (p.timestamp >= fromEpochSeconds && p.timestamp <= toEpochSeconds) p,
  ]);
}

/// Bounding box of [points], or null when empty.
///
/// Longitudes are unwrapped across the antimeridian: a track running from
/// 179.9 E to 179.9 W reports minLon 179.9 and maxLon 180.1 (a 0.2 deg span)
/// rather than the 359.8 deg span a naive min/max would produce, which would
/// fit the camera to the entire globe.
({double minLat, double maxLat, double minLon, double maxLon})? trackBounds(
  List<GpsTrackPoint> points,
) {
  if (points.isEmpty) return null;

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
  }

  var minLon = points.first.longitude;
  var maxLon = points.first.longitude;
  for (final p in points) {
    if (p.longitude < minLon) minLon = p.longitude;
    if (p.longitude > maxLon) maxLon = p.longitude;
  }

  // A raw span wider than half the globe means the track almost certainly
  // wraps the antimeridian rather than genuinely circling the planet. Re-run
  // the extent with western longitudes shifted into a continuous frame.
  if (maxLon - minLon > 180.0) {
    var shiftedMin = double.infinity;
    var shiftedMax = double.negativeInfinity;
    for (final p in points) {
      final lon = p.longitude < 0 ? p.longitude + 360.0 : p.longitude;
      if (lon < shiftedMin) shiftedMin = lon;
      if (lon > shiftedMax) shiftedMax = lon;
    }
    minLon = shiftedMin;
    maxLon = shiftedMax;
  }

  return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
}

/// Ground speed in metres per second between two consecutive fixes.
///
/// Returns 0 for zero or negative elapsed time. GPS logs do occasionally
/// carry out-of-order or duplicated timestamps, and a negative speed would
/// poison bucketing and the max-speed statistic.
double speedMpsBetween(GpsTrackPoint a, GpsTrackPoint b) {
  final elapsed = b.timestamp - a.timestamp;
  if (elapsed <= 0) return 0.0;
  return distanceMeters(toGeoPoint(a), toGeoPoint(b)) / elapsed;
}

/// Total along-track distance in metres.
double trackDistanceMeters(List<GpsTrackPoint> points) {
  if (points.length < 2) return 0.0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += distanceMeters(toGeoPoint(points[i - 1]), toGeoPoint(points[i]));
  }
  return total;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_geometry_test.dart`
Expected: PASS, 20 tests total.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/domain/track_geometry.dart test/features/gps_log/track_geometry_test.dart
git commit -m "Add track windowing, antimeridian-safe bounds, and speed math"
```

---

### Task 3: Colorization buckets and contiguous runs

**Files:**
- Create: `lib/features/gps_log/domain/track_colorization.dart`
- Test: `test/features/gps_log/track_colorization_test.dart`

**Interfaces:**
- Consumes: `speedMpsBetween` from Task 2
- Produces:
  - `enum TrackColorMode { uniform, speed, elapsed }`
  - `class TrackRun { final List<GpsTrackPoint> points; final int bucket; }`
  - `const int kTrackColorBuckets = 8;`
  - `List<TrackRun> bucketizeTrack(List<GpsTrackPoint> points, TrackColorMode mode, {int buckets = kTrackColorBuckets})`
  - `({double min, double max})? speedRange(List<GpsTrackPoint> points)`

Runs must **share a boundary point** with their neighbour, or the rendered polyline shows a one-segment gap at every bucket change.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/track_colorization_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';

GpsTrackPoint p(double lat, double lon, {int t = 0}) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('uniform mode', () {
    test('produces exactly one run covering every point', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.001, 0.0, t: 10),
        p(0.002, 0.0, t: 20),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.uniform);
      expect(runs.length, 1);
      expect(runs.first.bucket, 0);
      expect(runs.first.points.length, 3);
    });
  });

  group('elapsed mode', () {
    test('assigns increasing buckets across the track', () {
      final points = List.generate(
        9,
        (i) => p(0.0, i * 0.001, t: i * 100),
      );
      final runs = bucketizeTrack(points, TrackColorMode.elapsed, buckets: 3);
      expect(runs.length, greaterThan(1));
      expect(runs.first.bucket, lessThan(runs.last.bucket));
    });

    test('runs share a boundary point so the line has no gaps', () {
      final points = List.generate(
        9,
        (i) => p(0.0, i * 0.001, t: i * 100),
      );
      final runs = bucketizeTrack(points, TrackColorMode.elapsed, buckets: 3);
      for (var i = 1; i < runs.length; i++) {
        expect(
          runs[i].points.first.timestamp,
          runs[i - 1].points.last.timestamp,
          reason: 'run $i must start where run ${i - 1} ended',
        );
      }
    });
  });

  group('speed mode', () {
    test('separates a slow leg from a fast leg into different buckets', () {
      // Leg 1: 0.0001 deg lat (11.1 m) over 10 s  = 1.11 m/s
      // Leg 2: 0.0100 deg lat (1112 m) over 10 s  = 111 m/s
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.0001, 0.0, t: 10),
        p(0.0101, 0.0, t: 20),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.speed, buckets: 4);
      expect(runs.length, 2);
      expect(runs.first.bucket, isNot(equals(runs.last.bucket)));
    });

    test('merges consecutive legs at the same speed into one run', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.001, 0.0, t: 10),
        p(0.002, 0.0, t: 20),
        p(0.003, 0.0, t: 30),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.speed, buckets: 4);
      expect(runs.length, 1);
      expect(runs.first.points.length, 4);
    });
  });

  group('degenerate input', () {
    test('returns empty for an empty track', () {
      expect(bucketizeTrack(const [], TrackColorMode.speed), isEmpty);
    });

    test('returns empty for a single point (nothing to draw)', () {
      expect(bucketizeTrack([p(1, 1)], TrackColorMode.speed), isEmpty);
    });

    test('handles a two-point track as one run', () {
      final runs = bucketizeTrack(
        [p(0.0, 0.0, t: 0), p(0.001, 0.0, t: 10)],
        TrackColorMode.speed,
      );
      expect(runs.length, 1);
      expect(runs.first.points.length, 2);
    });
  });

  group('speedRange', () {
    test('returns null when there are no legs', () {
      expect(speedRange(const []), isNull);
      expect(speedRange([p(1, 1)]), isNull);
    });

    test('reports min and max leg speed', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.0001, 0.0, t: 10),
        p(0.0101, 0.0, t: 20),
      ];
      final range = speedRange(points);
      expect(range!.min, closeTo(1.11, 0.05));
      expect(range.max, closeTo(111.2, 1.0));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_colorization_test.dart`
Expected: FAIL — `bucketizeTrack` isn't defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gps_log/domain/track_colorization.dart`:

```dart
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

/// How a track polyline is colorized.
enum TrackColorMode { uniform, speed, elapsed }

/// Default number of quantization buckets.
///
/// flutter_map's Polyline.gradientColors cannot express a colour ramp along
/// arc length (it paints a straight screen-space gradient between the first
/// and last point), so colorization is done by quantizing into buckets and
/// emitting one Polyline per contiguous same-bucket run. Discrete bands also
/// map one-to-one onto legend rows.
const int kTrackColorBuckets = 8;

/// A contiguous span of track points sharing one quantization bucket.
class TrackRun {
  final List<GpsTrackPoint> points;
  final int bucket;

  const TrackRun({required this.points, required this.bucket});
}

/// Minimum and maximum leg speed in metres per second, or null when the
/// track has fewer than two points.
({double min, double max})? speedRange(List<GpsTrackPoint> points) {
  if (points.length < 2) return null;
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (var i = 1; i < points.length; i++) {
    final speed = speedMpsBetween(points[i - 1], points[i]);
    if (speed < min) min = speed;
    if (speed > max) max = speed;
  }
  return (min: min, max: max);
}

/// Bucket index for [value] within [min]..[max], clamped to 0..buckets-1.
int _bucketFor(double value, double min, double max, int buckets) {
  if (max <= min) return 0;
  final normalized = (value - min) / (max - min);
  return (normalized * buckets).floor().clamp(0, buckets - 1);
}

/// Splits [points] into contiguous runs sharing a quantization bucket.
///
/// Consecutive runs SHARE their boundary point: run N ends on the same point
/// run N+1 begins on. Without that overlap the rendered polyline shows a
/// one-segment gap at every bucket change.
List<TrackRun> bucketizeTrack(
  List<GpsTrackPoint> points,
  TrackColorMode mode, {
  int buckets = kTrackColorBuckets,
}) {
  // A single point has no segment to draw.
  if (points.length < 2) return const [];

  if (mode == TrackColorMode.uniform) {
    return [TrackRun(points: List.unmodifiable(points), bucket: 0)];
  }

  // One bucket per LEG (there are points.length - 1 legs).
  final legBuckets = <int>[];
  if (mode == TrackColorMode.speed) {
    final range = speedRange(points);
    final min = range?.min ?? 0.0;
    final max = range?.max ?? 0.0;
    for (var i = 1; i < points.length; i++) {
      legBuckets.add(
        _bucketFor(speedMpsBetween(points[i - 1], points[i]), min, max, buckets),
      );
    }
  } else {
    final start = points.first.timestamp;
    final end = points.last.timestamp;
    for (var i = 1; i < points.length; i++) {
      legBuckets.add(
        _bucketFor(
          points[i].timestamp.toDouble(),
          start.toDouble(),
          end.toDouble(),
          buckets,
        ),
      );
    }
  }

  final runs = <TrackRun>[];
  var runStart = 0;
  for (var leg = 1; leg <= legBuckets.length; leg++) {
    final atEnd = leg == legBuckets.length;
    final bucketChanged = !atEnd && legBuckets[leg] != legBuckets[leg - 1];
    if (atEnd || bucketChanged) {
      runs.add(
        TrackRun(
          // leg L spans points[L] .. points[L+1], so a run covering legs
          // runStart..leg-1 spans points runStart .. leg inclusive.
          points: List.unmodifiable(points.sublist(runStart, leg + 1)),
          bucket: legBuckets[runStart],
        ),
      );
      runStart = leg;
    }
  }

  return List.unmodifiable(runs);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_colorization_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/domain/track_colorization.dart test/features/gps_log/track_colorization_test.dart
git commit -m "Add track colorization buckets and contiguous runs"
```

---

### Task 4: Speed formatting in UnitFormatter

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart`
- Modify: `lib/l10n/arb/app_en.arb` and all locale ARBs
- Test: `test/core/utils/unit_formatter_speed_test.dart`

**Interfaces:**
- Produces: `String UnitFormatter.formatSpeed(double metersPerSecond, {int decimals = 1})`

Speed derives from the existing distance-unit preference: metric shows km/h, imperial shows mph. Knots are offered as an explicit third option because divers on boats routinely think in knots regardless of their depth units.

- [ ] **Step 1: Inspect the existing formatter to match its conventions**

Run: `sed -n '1,80p' lib/core/utils/unit_formatter.dart`

Note how `formatDistance` reads the unit off settings and which l10n keys it uses. `formatSpeed` must follow the identical shape.

- [ ] **Step 2: Write the failing test**

Create `test/core/utils/unit_formatter_speed_test.dart`. Build the `Settings` instance the same way the existing `test/core/utils/unit_formatter_test.dart` does — open that file first and copy its construction helper rather than inventing one:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

// Reuse the Settings builder from the sibling unit_formatter_test.dart.
// If that file defines a local helper, lift it into a shared test helper
// under test/helpers/ and import it from both.
import '../../helpers/settings_test_helper.dart';

void main() {
  group('formatSpeed', () {
    test('metric renders km/h', () {
      final units = UnitFormatter(metricSettings());
      // 10 m/s = 36 km/h
      expect(units.formatSpeed(10.0), '36.0 km/h');
    });

    test('imperial renders mph', () {
      final units = UnitFormatter(imperialSettings());
      // 10 m/s = 22.369 mph
      expect(units.formatSpeed(10.0), '22.4 mph');
    });

    test('zero speed renders without a sign or NaN', () {
      final units = UnitFormatter(metricSettings());
      expect(units.formatSpeed(0.0), '0.0 km/h');
    });

    test('honours the decimals argument', () {
      final units = UnitFormatter(metricSettings());
      expect(units.formatSpeed(10.0, decimals: 0), '36 km/h');
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/utils/unit_formatter_speed_test.dart`
Expected: FAIL — `formatSpeed` isn't defined on `UnitFormatter`.

- [ ] **Step 4: Implement `formatSpeed`**

Add to `lib/core/utils/unit_formatter.dart`, immediately after `formatDistance` so related formatters stay adjacent:

```dart
  /// Formats a speed in metres per second using the diver's distance-unit
  /// preference: metric renders km/h, imperial renders mph.
  String formatSpeed(double metersPerSecond, {int decimals = 1}) {
    final isMetric = _settings.depthUnit == DepthUnit.meters;
    final value = isMetric
        ? metersPerSecond * 3.6
        : metersPerSecond * 2.236936;
    final suffix = isMetric ? 'km/h' : 'mph';
    return '${value.toStringAsFixed(decimals)} $suffix';
  }
```

Adjust the settings field name and `DepthUnit` reference to match what `formatDistance` actually reads — copy its exact expression rather than assuming.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/utils/unit_formatter_speed_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Verify no existing formatter tests regressed**

Run: `flutter test test/core/utils/`
Expected: PASS, all tests.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/utils/unit_formatter.dart test/core/utils/unit_formatter_speed_test.dart
git commit -m "Add speed formatting to UnitFormatter"
```

---

### Task 5: Main database migration to v144

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Test: `test/core/database/migration_v144_gps_track_columns_test.dart`

**Interfaces:**
- Produces: `gps_tracks` columns `source` (TEXT, default `'phone'`), `sourceRef` (TEXT?), `name` (TEXT?), `trimStartTime` (INT?), `trimEndTime` (INT?)

All five columns land in one migration even though `source` is not read until Phase 6 and the trim bounds are not written until Phase 7. One migration on a collision-prone ladder is materially safer than three.

- [ ] **Step 1: Confirm the version is still free**

```bash
git fetch origin
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion ="
```

Expected: `144`. If it is not 144, stop and pick the next free version, updating every reference in this task. This check has already fired once: main was at 142 when the plan was written and reached 144 (visibility scale calibration) before this branch merged, so the step was renumbered from 144 to 145.

- [ ] **Step 2: Read an existing migration step to copy its shape**

Run: `grep -n "from < 14[0-2]" lib/core/database/database.dart`

Open the most recent step and match its structure exactly — the guard style, `m.addColumn` usage, and comment convention.

- [ ] **Step 3: Write the failing migration test**

Create `test/core/database/migration_v144_gps_track_columns_test.dart`. Note the setup convention: this repo has **no `AppDatabase.forTesting` constructor** — main-database tests go through `setUpTestDatabase()` from `test/helpers/test_database.dart`, which installs an in-memory `AppDatabase` into `DatabaseService.instance`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('gps_tracks carries the v144 columns', () async {
    final columns = await db
        .customSelect('PRAGMA table_info(gps_tracks)')
        .get();
    final names = columns.map((r) => r.data['name'] as String).toSet();

    expect(names, contains('source'));
    expect(names, contains('source_ref'));
    expect(names, contains('name'));
    expect(names, contains('trim_start_time'));
    expect(names, contains('trim_end_time'));
  });

  test('source defaults to phone for a row inserted without it', () async {
    await db.into(db.gpsTracks).insert(
          GpsTracksCompanion.insert(
            id: 'track-1',
            startTime: 1700000000000,
            createdAt: 1700000000000,
            updatedAt: 1700000000000,
          ),
        );
    final row = await (db.select(db.gpsTracks)
          ..where((t) => t.id.equals('track-1')))
        .getSingle();
    expect(row.source, 'phone');
    expect(row.trimStartTime, isNull);
    expect(row.trimEndTime, isNull);
  });

  test('schema version is 145', () {
    expect(db.schemaVersion, 145);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v144_gps_track_columns_test.dart`
Expected: FAIL — no such column `source`.

- [ ] **Step 5: Add the columns to the table definition**

In `lib/core/database/database.dart`, inside `class GpsTracks extends Table`, after `pointCount` (around line 380):

```dart
  /// Provenance: 'phone' | 'gpx' | 'fit' | 'kml' | 'csv'. Rendering code
  /// treats this as opaque - no view logic branches on it.
  TextColumn get source => text().withDefault(const Constant('phone'))();

  /// Originating filename or device, for imported tracks.
  TextColumn get sourceRef => text().nullable()();

  /// User-editable label.
  TextColumn get name => text().nullable()();

  /// Non-destructive trim bounds, wall-clock-as-UTC epoch MILLISECONDS.
  /// The points blob is never rewritten by a trim, so trimming is fully
  /// reversible and cannot lose a fix.
  IntColumn get trimStartTime => integer().nullable()();
  IntColumn get trimEndTime => integer().nullable()();
```

- [ ] **Step 6: Bump the version and add the migration step**

Change `currentSchemaVersion` from `142` to `145`, then add to the migration chain, matching the surrounding style:

```dart
      if (from < 145) {
        await m.addColumn(gpsTracks, gpsTracks.source);
        await m.addColumn(gpsTracks, gpsTracks.sourceRef);
        await m.addColumn(gpsTracks, gpsTracks.name);
        await m.addColumn(gpsTracks, gpsTracks.trimStartTime);
        await m.addColumn(gpsTracks, gpsTracks.trimEndTime);
      }
```

- [ ] **Step 7: Regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/database/migration_v144_gps_track_columns_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 9: Thread the columns through sync serialization**

Open `lib/core/services/sync/sync_data_serializer.dart`, find the `gps_tracks` entity handling, and add all five columns to both the serialize and deserialize paths. Defaulted columns need hydration on read so a peer on an older schema cannot push a null back over `source`: when the incoming payload omits `source`, write `'phone'` rather than `Value.absent()`.

- [ ] **Step 10: Extend the sync round-trip test**

Add to `test/core/services/sync/sync_gps_tracks_test.dart`. That file already has a `seedTrack()` helper and a `SyncDataSerializer serializer` / `GpsTrackRepository repo` pair in scope:

```dart
  test('v144 columns survive a serialize round trip', () async {
    final id = await seedTrack();
    final db = DatabaseService.instance.database;
    await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
      const GpsTracksCompanion(
        source: Value('gpx'),
        sourceRef: Value('cozumel-day-3.gpx'),
        name: Value('Palancar morning'),
        trimStartTime: Value(1700000600000),
        trimEndTime: Value(1700003000000),
      ),
    );

    final fetched = await serializer.fetchRecord('gpsTracks', id);
    expect(fetched!['source'], 'gpx');
    expect(fetched['sourceRef'], 'cozumel-day-3.gpx');
    expect(fetched['name'], 'Palancar morning');
    expect(fetched['trimStartTime'], 1700000600000);
    expect(fetched['trimEndTime'], 1700003000000);
  });

  test('an incoming payload without source hydrates the phone default',
      () async {
    // A peer on a pre-v144 schema omits the column entirely. It must land as
    // 'phone', never as null, or effectivePoints and the import dedupe rule
    // both see a source they cannot match.
    await serializer.upsertRecord('gpsTracks', {
      'id': 'peer-track',
      'startTime': 1700000000000,
      'endTime': 1700003600000,
      'tzOffsetMinutes': -300,
      'pointCount': 0,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    });

    final db = DatabaseService.instance.database;
    final row = await (db.select(db.gpsTracks)
          ..where((t) => t.id.equals('peer-track')))
        .getSingle();
    expect(row.source, 'phone');
  });
```

Add `import 'package:drift/drift.dart';` and `import 'package:submersion/core/services/database_service.dart';` to the file's imports.

- [ ] **Step 11: Run the sync tests**

Run: `flutter test test/core/services/sync/sync_gps_tracks_test.dart`
Expected: PASS.

- [ ] **Step 12: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/services/sync/sync_data_serializer.dart test/core/database/migration_v144_gps_track_columns_test.dart test/core/services/sync/sync_gps_tracks_test.dart
git commit -m "Add GPS track source, name, and trim-bound columns at schema v144"
```

---

### Task 6: effectivePoints accessor on the repository

**Files:**
- Modify: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Modify: `lib/features/gps_log/domain/entities/gps_track.dart`
- Test: `test/features/gps_log/gps_track_effective_points_test.dart`

**Interfaces:**
- Consumes: `windowTrack` from Task 2, trim columns from Task 5
- Produces:
  - `GpsTrack` gains `final String source; final String? sourceRef; final String? name; final int? trimStartTime; final int? trimEndTime;` plus `copyWith` coverage
  - `List<GpsTrackPoint> GpsTrack.effectivePoints`

This lands in Phase 1 even though nothing writes trim bounds until Phase 7. Every consumer reads through it from the start, so Phase 7 changes one accessor instead of auditing every call site.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/gps_track_effective_points_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: 0.0, longitude: t * 0.001);

GpsTrack trackWith({int? trimStart, int? trimEnd}) => GpsTrack(
      id: 'track-1',
      // Points are epoch SECONDS; trim bounds are epoch MILLISECONDS.
      startTime: 100000,
      endTime: 400000,
      points: [p(100), p(200), p(300), p(400)],
      trimStartTime: trimStart,
      trimEndTime: trimEnd,
    );

void main() {
  group('effectivePoints', () {
    test('returns every point when no trim is set', () {
      expect(trackWith().effectivePoints.length, 4);
    });

    test('drops points before the trim start', () {
      final track = trackWith(trimStart: 200000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(),
          [200, 300, 400]);
    });

    test('drops points after the trim end', () {
      final track = trackWith(trimEnd: 300000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(),
          [100, 200, 300]);
    });

    test('applies both bounds together', () {
      final track = trackWith(trimStart: 200000, trimEnd: 300000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(),
          [200, 300]);
    });

    test('never mutates the underlying points list', () {
      final track = trackWith(trimStart: 200000);
      track.effectivePoints;
      expect(track.points.length, 4);
    });

    test('returns empty when the trim window excludes everything', () {
      final track = trackWith(trimStart: 500000);
      expect(track.effectivePoints, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_effective_points_test.dart`
Expected: FAIL — `GpsTrack` has no named parameter `trimStartTime`.

- [ ] **Step 3: Extend the entity**

In `lib/features/gps_log/domain/entities/gps_track.dart`, add the five fields to `GpsTrack`, its constructor (with `this.source = 'phone'` and the rest nullable), and `copyWith`. Then add:

```dart
  /// The points this track actually represents, honouring non-destructive
  /// trim bounds.
  ///
  /// Every consumer - rendering, statistics, export, dive matching - reads
  /// through this rather than [points], so trimming cannot be silently
  /// ignored by one call site. Trim bounds are epoch MILLISECONDS while
  /// point timestamps are epoch SECONDS, hence the division.
  List<GpsTrackPoint> get effectivePoints {
    final start = trimStartTime;
    final end = trimEndTime;
    if (start == null && end == null) return points;
    return List.unmodifiable([
      for (final p in points)
        if ((start == null || p.timestamp >= start ~/ 1000) &&
            (end == null || p.timestamp <= end ~/ 1000))
          p,
    ]);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/gps_track_effective_points_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Map the new columns in the repository**

In `gps_track_repository.dart`, update `_toDomain` to populate `source`, `sourceRef`, `name`, `trimStartTime`, and `trimEndTime` from the Drift row.

- [ ] **Step 6: Run the existing repository tests**

Run: `flutter test test/features/gps_log/`
Expected: PASS, no regressions.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/domain/entities/gps_track.dart lib/features/gps_log/data/repositories/gps_track_repository.dart test/features/gps_log/gps_track_effective_points_test.dart
git commit -m "Add effectivePoints accessor honouring track trim bounds"
```

---

### Task 7: Geometry cache table in the local database

**Files:**
- Modify: `lib/core/database/local_cache_database.dart`
- Test: `test/core/database/local_cache_gps_geometry_test.dart`

**Interfaces:**
- Produces: `gps_track_geometry_cache` table `(trackId TEXT, lodLevel TEXT, points BLOB?, status TEXT, createdAt INT)`, primary key `(trackId, lodLevel)`; local cache `schemaVersion` 9 to 10

This goes in the local cache DB, not the synced one: simplified geometry is fully re-derivable from the stored blob, so the main DB would charge a schema bump, HLC timestamps, tombstones, merge rules, and backup weight for nothing.

- [ ] **Step 1: Read the existing pattern**

Run: `sed -n '85,200p' lib/core/database/local_cache_database.dart`

`ReefDataCache` is the closest model — copy its table shape, its status column convention, and its `beforeOpen` self-heal.

- [ ] **Step 2: Write the failing test**

Create `test/core/database/local_cache_gps_geometry_test.dart`:

Follow `test/core/database/local_cache_migration_v7_bathymetry_test.dart`: the local cache database is constructed **directly** with `LocalCacheDatabase(NativeDatabase.memory())` and torn down with `addTearDown(db.close)`. There is no `forTesting` constructor.

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  late LocalCacheDatabase db;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('schema version is 9', () {
    expect(db.schemaVersion, 9);
  });

  test('stores and reads back simplified geometry', () async {
    await db.into(db.gpsTrackGeometryCache).insert(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: 'track-1',
            lodLevel: 'thumbnail',
            status: 'ok',
            createdAt: 1700000000,
            points: Value(Uint8List.fromList([1, 2, 3])),
          ),
        );
    final row = await (db.select(db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals('track-1')))
        .getSingle();
    expect(row.status, 'ok');
    expect(row.points, [1, 2, 3]);
  });

  test('caches a definitive empty result without a blob', () async {
    await db.into(db.gpsTrackGeometryCache).insert(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: 'track-2',
            lodLevel: 'detail',
            status: 'empty',
            createdAt: 1700000000,
          ),
        );
    final row = await (db.select(db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals('track-2')))
        .getSingle();
    expect(row.status, 'empty');
    expect(row.points, isNull);
  });

  test('keys separate LOD levels for the same track independently', () async {
    for (final lod in ['thumbnail', 'overview', 'detail']) {
      await db.into(db.gpsTrackGeometryCache).insert(
            GpsTrackGeometryCacheCompanion.insert(
              trackId: 'track-3',
              lodLevel: lod,
              status: 'ok',
              createdAt: 1700000000,
            ),
          );
    }
    final rows = await (db.select(db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals('track-3')))
        .get();
    expect(rows.length, 3);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/database/local_cache_gps_geometry_test.dart`
Expected: FAIL — `gpsTrackGeometryCache` isn't defined.

- [ ] **Step 4: Add the table**

In `lib/core/database/local_cache_database.dart`, after `ReefDataCache`:

```dart
/// Simplified track geometry, cached per level of detail.
///
/// NOT synced and never backed up: every device can re-derive this from the
/// gps_tracks points blob in milliseconds, so paying the main database's
/// schema-bump, HLC, tombstone, and backup costs would buy nothing.
class GpsTrackGeometryCache extends Table {
  TextColumn get trackId => text()();

  /// 'thumbnail' (50 m tolerance) | 'overview' (10 m) | 'detail' (2 m)
  TextColumn get lodLevel => text()();

  /// Gzipped JSON in the same format as gps_tracks.points. Null when
  /// [status] is not 'ok'.
  BlobColumn get points => blob().nullable()();

  /// 'ok' | 'empty' | 'unavailable'. An explicit negative is cached so a
  /// genuinely empty track is not re-derived on every scroll.
  TextColumn get status => text()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {trackId, lodLevel};
}
```

Register it in the `@DriftDatabase(tables: [...])` list, bump `schemaVersion` from 9 to 10, add the migration step, and add the `beforeOpen` self-heal alongside the bathymetry and reef ones:

```dart
        CREATE TABLE IF NOT EXISTS gps_track_geometry_cache (
          track_id TEXT NOT NULL,
          lod_level TEXT NOT NULL,
          points BLOB,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (track_id, lod_level)
        )
```

- [ ] **Step 5: Regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/database/local_cache_gps_geometry_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/local_cache_database.dart lib/core/database/local_cache_database.g.dart test/core/database/local_cache_gps_geometry_test.dart
git commit -m "Add GPS track geometry cache table to the local database"
```

---

### Task 8: Geometry cache repository and map providers

**Files:**
- Create: `lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart`
- Create: `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart`
- Test: `test/features/gps_log/track_geometry_cache_repository_test.dart`
- Test: `test/features/gps_log/gps_track_map_providers_test.dart`

**Interfaces:**
- Consumes: `simplifyTrack` (Task 1), `effectivePoints` (Task 6), the cache table (Task 7), `encodeTrackPoints`/`decodeTrackPoints` from `track_point_codec.dart`
- Produces:
  - `enum TrackLod { thumbnail, overview, detail }` with `double get toleranceMeters`
  - `TrackGeometryCacheRepository.read(String trackId, TrackLod lod)` returning `List<GpsTrackPoint>?`
  - `TrackGeometryCacheRepository.write(String trackId, TrackLod lod, List<GpsTrackPoint> points)`
  - `TrackGeometryCacheRepository.invalidate(String trackId)`
  - `gpsTrackDetailProvider(String trackId)` → `FutureProvider.family<GpsTrack?, String>`
  - `gpsTrackGeometryProvider((String trackId, TrackLod lod))` → `FutureProvider.family<List<GpsTrackPoint>, (String, TrackLod)>`

`divesOnTrackProvider` and `trackForDiveProvider` are added in Task 12, with the dive-marker feature that first consumes them.

Simplification runs inside `compute()`. Follow the existing isolate pattern in `lib/core/tide/tide_calculator.dart` — top-level function, single serializable argument.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/gps_log/track_geometry_cache_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: t * 0.001, longitude: 0.0);

void main() {
  late LocalCacheDatabase db;
  late TrackGeometryCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = TrackGeometryCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('returns null for an uncached track', () async {
    expect(await repo.read('missing', TrackLod.thumbnail), isNull);
  });

  test('round-trips written geometry', () async {
    final points = [p(1), p(2), p(3)];
    await repo.write('track-1', TrackLod.detail, points);
    final read = await repo.read('track-1', TrackLod.detail);
    expect(read, isNotNull);
    expect(read!.length, 3);
    expect(read.first.timestamp, 1);
  });

  test('keeps LOD levels independent', () async {
    await repo.write('track-1', TrackLod.thumbnail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1), p(2), p(3)]);
    expect((await repo.read('track-1', TrackLod.thumbnail))!.length, 2);
    expect((await repo.read('track-1', TrackLod.detail))!.length, 3);
  });

  test('caches an empty result as a definitive answer, not a miss', () async {
    await repo.write('track-empty', TrackLod.overview, const []);
    final read = await repo.read('track-empty', TrackLod.overview);
    expect(read, isNotNull);
    expect(read, isEmpty);
  });

  test('invalidate clears every LOD for a track', () async {
    await repo.write('track-1', TrackLod.thumbnail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1), p(2), p(3)]);
    await repo.invalidate('track-1');
    expect(await repo.read('track-1', TrackLod.thumbnail), isNull);
    expect(await repo.read('track-1', TrackLod.detail), isNull);
  });

  test('invalidate leaves other tracks untouched', () async {
    await repo.write('track-1', TrackLod.detail, [p(1)]);
    await repo.write('track-2', TrackLod.detail, [p(1)]);
    await repo.invalidate('track-1');
    expect(await repo.read('track-2', TrackLod.detail), isNotNull);
  });

  test('rewriting the same key replaces rather than duplicates', () async {
    await repo.write('track-1', TrackLod.detail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1)]);
    expect((await repo.read('track-1', TrackLod.detail))!.length, 1);
  });

  group('TrackLod tolerances', () {
    test('match the spec', () {
      expect(TrackLod.thumbnail.toleranceMeters, 50.0);
      expect(TrackLod.overview.toleranceMeters, 10.0);
      expect(TrackLod.detail.toleranceMeters, 2.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_geometry_cache_repository_test.dart`
Expected: FAIL — `TrackGeometryCacheRepository` isn't defined.

- [ ] **Step 3: Implement the repository**

Create `lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

/// Level of detail for simplified track geometry.
enum TrackLod {
  /// Row thumbnails and unselected tracks on the overview map.
  thumbnail,

  /// Selected track on the overview map, detail page zoomed out.
  overview,

  /// Detail page at zoom >= 14.
  detail;

  /// Douglas-Peucker tolerance in metres. Expressed in metres rather than
  /// pixels so simplification is independent of screen density.
  double get toleranceMeters => switch (this) {
        TrackLod.thumbnail => 50.0,
        TrackLod.overview => 10.0,
        TrackLod.detail => 2.0,
      };
}

/// Reads and writes simplified geometry in the local (unsynced) cache.
///
/// Constructed with no arguments and resolving the database through
/// [LocalCacheDatabaseService.instance], matching [GpsTrackRepository]'s
/// convention of `AppDatabase get _db => DatabaseService.instance.database`.
class TrackGeometryCacheRepository {
  LocalCacheDatabase get _db => LocalCacheDatabaseService.instance.database;

  /// Cached geometry, or null on a cache miss.
  ///
  /// An empty list is a real answer (the track has no drawable points) and
  /// is distinct from null (nothing cached yet).
  Future<List<GpsTrackPoint>?> read(String trackId, TrackLod lod) async {
    final row = await (_db.select(_db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals(trackId))
          ..where((t) => t.lodLevel.equals(lod.name)))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.status != 'ok') return const [];
    final blob = row.points;
    if (blob == null) return const [];
    return decodeTrackPoints(blob);
  }

  Future<void> write(
    String trackId,
    TrackLod lod,
    List<GpsTrackPoint> points,
  ) async {
    await _db.into(_db.gpsTrackGeometryCache).insertOnConflictUpdate(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: trackId,
            lodLevel: lod.name,
            status: points.isEmpty ? 'empty' : 'ok',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            points: points.isEmpty
                ? const Value.absent()
                : Value(encodeTrackPoints(points)),
          ),
        );
  }

  /// Drops every cached LOD for [trackId]. Called after a trim or split
  /// changes which points the track represents.
  Future<void> invalidate(String trackId) async {
    await (_db.delete(_db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals(trackId)))
        .go();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_geometry_cache_repository_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Write the failing provider test**

Create `test/features/gps_log/gps_track_map_providers_test.dart`. Both databases need seeding: `setUpTestDatabase()` for the main one (the track lives there) and a direct `LocalCacheDatabase` for the cache.

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  /// Seeds a track of 100 near-collinear fixes: a straight run east with a
  /// sub-metre north wobble, so aggressive simplification should collapse it
  /// to a handful of points.
  Future<String> seedWobblyTrack() async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    for (var i = 0; i < 100; i++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: 1700000000 + i,
          // 1e-8 deg is ~1 mm of wobble - far below any tolerance.
          latitude: (i.isEven ? 1e-8 : -1e-8),
          longitude: i * 0.0001,
        ),
      );
    }
    await repo.finalizeTrack(id, endTimeMs: 1700000099000);
    return id;
  }

  test('simplifies on first read and writes the result to cache', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final simplified = await container
        .read(gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future);

    expect(simplified.length, lessThan(100));
    expect(simplified.length, greaterThanOrEqualTo(2));

    // The cache now holds it, so a cold provider would not re-simplify.
    final cached =
        await TrackGeometryCacheRepository().read(id, TrackLod.thumbnail);
    expect(cached, isNotNull);
    expect(cached!.length, simplified.length);
  });

  test('a second read returns the cached geometry unchanged', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container
        .read(gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future);
    container.invalidate(gpsTrackGeometryProvider((id, TrackLod.thumbnail)));
    final second = await container
        .read(gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future);

    expect(second.length, first.length);
    expect(second.first.timestamp, first.first.timestamp);
    expect(second.last.timestamp, first.last.timestamp);
  });

  test('different LOD levels produce independently cached results', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future);
    await container
        .read(gpsTrackGeometryProvider((id, TrackLod.detail)).future);

    final cache = TrackGeometryCacheRepository();
    expect(await cache.read(id, TrackLod.thumbnail), isNotNull);
    expect(await cache.read(id, TrackLod.detail), isNotNull);
  });

  test('returns empty for a track id that does not exist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container
        .read(gpsTrackGeometryProvider(('nope', TrackLod.detail)).future);
    expect(result, isEmpty);
  });
}
```

Tests for `divesOnTrackProvider` and `trackForDiveProvider` are written in Task 12, alongside the dive-marker feature that consumes them — keeping the provider and its first consumer in one reviewable unit.

- [ ] **Step 6: Implement the providers**

Create `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

/// Argument bundle for the isolate. compute() takes exactly one argument,
/// and it must be sendable.
class _SimplifyRequest {
  final List<GpsTrackPoint> points;
  final double toleranceMeters;

  const _SimplifyRequest(this.points, this.toleranceMeters);
}

/// Top-level so it can run in an isolate.
List<GpsTrackPoint> _simplifyInIsolate(_SimplifyRequest request) =>
    simplifyTrack(request.points, request.toleranceMeters);

final trackGeometryCacheRepositoryProvider =
    Provider<TrackGeometryCacheRepository>(
  (ref) => TrackGeometryCacheRepository(),
);

/// A single hydrated track, points blob decoded. This is the expensive step
/// and it happens once per track.
final gpsTrackDetailProvider =
    FutureProvider.family<GpsTrack?, String>((ref, trackId) async {
  return ref
      .watch(gpsTrackRepositoryProvider)
      .getTrack(trackId, includePoints: true);
});

/// Simplified geometry at a given level of detail, cached across launches.
final gpsTrackGeometryProvider =
    FutureProvider.family<List<GpsTrackPoint>, (String, TrackLod)>(
        (ref, key) async {
  final (trackId, lod) = key;
  final cache = ref.watch(trackGeometryCacheRepositoryProvider);

  final cached = await cache.read(trackId, lod);
  if (cached != null) return cached;

  final track = await ref.watch(gpsTrackDetailProvider(trackId).future);
  if (track == null) return const [];

  // Read through effectivePoints so trim bounds are honoured before
  // simplification rather than after.
  final simplified = await compute(
    _simplifyInIsolate,
    _SimplifyRequest(track.effectivePoints, lod.toleranceMeters),
  );
  await cache.write(trackId, lod, simplified);
  return simplified;
});
```

Note the import of `gps_log_providers.dart` for `gpsTrackRepositoryProvider`, and drop the unused `Dive` import — `divesOnTrackProvider` arrives in Task 12.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/gps_log/`
Expected: PASS, all tests.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart lib/features/gps_log/presentation/providers/gps_track_map_providers.dart test/features/gps_log/track_geometry_cache_repository_test.dart test/features/gps_log/gps_track_map_providers_test.dart
git commit -m "Add track geometry cache repository and map providers"
```

---

**Phase 1 complete.** The geometry core, both schema changes, and the provider layer are in place and fully unit-tested. Nothing is visible in the app yet.

Run the full suite before moving on:

```bash
flutter test
flutter analyze
```

---

## Phase 2: Track Detail Page

First user-visible value. At the end of this phase a diver can tap a track and see where the boat went.

---

### Task 9: Polyline layer from colorization runs

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart`
- Test: `test/features/gps_log/gps_track_polyline_layer_test.dart`

**Interfaces:**
- Consumes: `TrackRun`, `TrackColorMode`, `kTrackColorBuckets` (Task 3)
- Produces:
  - `List<Color> trackBucketColors(ColorScheme scheme, TrackColorMode mode, int buckets)`
  - `List<Polyline> buildTrackPolylines({required List<TrackRun> runs, required TrackColorMode mode, required ColorScheme scheme, double strokeWidth = 4.0, Color? uniformColor})`
  - `class GpsTrackPolylineLayer extends StatelessWidget` wrapping `PolylineLayer`

Each `Polyline` carries its run index as `hitValue`, which is how Task 13 resolves a tap back to a point. The colour ramp is generated from the theme rather than hard-coded so it reads correctly in both light and dark.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/gps_track_polyline_layer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: t * 0.001, longitude: 0.0);

TrackRun run(int bucket, int count) => TrackRun(
      points: List.generate(count, (i) => p(bucket * 100 + i)),
      bucket: bucket,
    );

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  group('trackBucketColors', () {
    test('returns one colour per bucket', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      expect(colors.length, 8);
    });

    test('produces visually distinct endpoints', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      expect(colors.first, isNot(equals(colors.last)));
    });

    test('uniform mode returns a single colour', () {
      final colors = trackBucketColors(scheme, TrackColorMode.uniform, 8);
      expect(colors.length, 1);
    });
  });

  group('buildTrackPolylines', () {
    test('emits one polyline per run', () {
      final runs = [run(0, 3), run(3, 4), run(7, 2)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines.length, 3);
    });

    test('carries the run index as hitValue for tap resolution', () {
      final runs = [run(0, 3), run(3, 4)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines[0].hitValue, 0);
      expect(lines[1].hitValue, 1);
    });

    test('maps each run to the colour for its bucket', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      final runs = [run(0, 2), run(7, 2)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines[0].color, colors[0]);
      expect(lines[1].color, colors[7]);
    });

    test('uniform mode honours an explicit uniformColor override', () {
      final runs = [run(0, 3)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.uniform,
        scheme: scheme,
        uniformColor: const Color(0xFF123456),
      );
      expect(lines.single.color, const Color(0xFF123456));
    });

    test('converts every point to a LatLng in order', () {
      final runs = [run(0, 3)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.uniform,
        scheme: scheme,
      );
      expect(lines.single.points.length, 3);
      expect(lines.single.points.first.latitude, closeTo(0.0, 1e-9));
    });

    test('returns empty for no runs', () {
      final lines = buildTrackPolylines(
        runs: const [],
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines, isEmpty);
    });

    test('clamps an out-of-range bucket rather than throwing', () {
      final lines = buildTrackPolylines(
        runs: [run(99, 2)],
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_polyline_layer_test.dart`
Expected: FAIL — `trackBucketColors` isn't defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/gps_log/domain/track_colorization.dart';

/// Sequential ramp endpoints for each colorization mode.
///
/// Speed runs cool (slow) to warm (fast); elapsed time runs light to dark in
/// the theme's primary hue. Both are generated from the active [ColorScheme]
/// rather than hard-coded so they hold up in light and dark themes.
List<Color> trackBucketColors(
  ColorScheme scheme,
  TrackColorMode mode,
  int buckets,
) {
  if (mode == TrackColorMode.uniform) return [scheme.primary];

  final (Color from, Color to) = switch (mode) {
    TrackColorMode.speed => (scheme.tertiary, scheme.error),
    TrackColorMode.elapsed => (scheme.primaryContainer, scheme.primary),
    TrackColorMode.uniform => (scheme.primary, scheme.primary),
  };

  if (buckets <= 1) return [to];
  return [
    for (var i = 0; i < buckets; i++)
      Color.lerp(from, to, i / (buckets - 1))!,
  ];
}

/// Converts colorization runs into one [Polyline] per run.
///
/// Each polyline carries its run index as [Polyline.hitValue] so a tap can be
/// resolved back to a specific span of the track.
List<Polyline<int>> buildTrackPolylines({
  required List<TrackRun> runs,
  required TrackColorMode mode,
  required ColorScheme scheme,
  double strokeWidth = 4.0,
  Color? uniformColor,
}) {
  if (runs.isEmpty) return const [];

  final colors = trackBucketColors(scheme, mode, kTrackColorBuckets);

  return [
    for (var i = 0; i < runs.length; i++)
      Polyline<int>(
        points: [
          for (final p in runs[i].points) LatLng(p.latitude, p.longitude),
        ],
        color: mode == TrackColorMode.uniform
            ? (uniformColor ?? colors.first)
            : colors[runs[i].bucket.clamp(0, colors.length - 1)],
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        hitValue: i,
      ),
  ];
}

/// Draws a colorized track as a flutter_map layer.
class GpsTrackPolylineLayer extends StatelessWidget {
  const GpsTrackPolylineLayer({
    super.key,
    required this.runs,
    required this.mode,
    this.strokeWidth = 4.0,
    this.uniformColor,
    this.hitNotifier,
  });

  final List<TrackRun> runs;
  final TrackColorMode mode;
  final double strokeWidth;
  final Color? uniformColor;
  final LayerHitNotifier<int>? hitNotifier;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer<int>(
      hitNotifier: hitNotifier,
      polylines: buildTrackPolylines(
        runs: runs,
        mode: mode,
        scheme: Theme.of(context).colorScheme,
        strokeWidth: strokeWidth,
        uniformColor: uniformColor,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/gps_track_polyline_layer_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart test/features/gps_log/gps_track_polyline_layer_test.dart
git commit -m "Add polyline layer builder for colorized GPS tracks"
```

---

### Task 10: Track detail route and page skeleton

**Files:**
- Create: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/gps_track_detail_page_test.dart`
- Test: `test/core/router/app_router_gps_track_test.dart`

**Interfaces:**
- Consumes: `gpsTrackDetailProvider`, `gpsTrackGeometryProvider`, `TrackLod` (Task 8); `GpsTrackPolylineLayer` (Task 9)
- Produces: route `/gps-log/:id` named `gpsTrackDetail`; `GpsTrackDetailPage({required String trackId})`

The static `/gps-log/map` route is added in Task 19, but its ordering constraint is established here: any static child of `/gps-log` must be declared **before** `:id` or the parameter route swallows it.

- [ ] **Step 1: Write the failing router test**

Create `test/core/router/app_router_gps_track_test.dart`, following the structure-assertion style used by the `dive planner back-navigation` group in `test/core/router/app_router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/router/app_router.dart';

/// Recursively collects every path in the route tree.
List<String> _allPaths(List<RouteBase> routes) => [
      for (final r in routes) ...[
        if (r is GoRoute) r.path,
        ..._allPaths(r.routes),
      ],
    ];

void main() {
  test('/gps-log has a :id child route', () {
    final paths = _allPaths(appRouter.configuration.routes);
    expect(paths, contains(':id'));
  });

  test('static gps-log children are declared before the :id route', () {
    // A static sibling declared after :id would never match - go_router
    // takes the first matching route, and :id matches any single segment.
    final gpsLog = _findRoute(appRouter.configuration.routes, '/gps-log');
    final childPaths = [
      for (final r in gpsLog.routes.whereType<GoRoute>()) r.path,
    ];
    final idIndex = childPaths.indexOf(':id');
    expect(idIndex, isNot(-1), reason: ':id child must exist');
    for (var i = 0; i < childPaths.length; i++) {
      if (childPaths[i] == ':id') continue;
      expect(
        i,
        lessThan(idIndex),
        reason: 'static child "${childPaths[i]}" must precede :id',
      );
    }
  });
}

GoRoute _findRoute(List<RouteBase> routes, String path) {
  for (final r in routes) {
    if (r is GoRoute && r.path == path) return r;
    try {
      return _findRoute(r.routes, path);
    } catch (_) {
      // keep searching siblings
    }
  }
  throw StateError('route $path not found');
}
```

Adjust `appRouter` to whatever the router instance or provider is actually named in `app_router.dart` — grep for the `GoRouter(` construction and match it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/router/app_router_gps_track_test.dart`
Expected: FAIL — `:id` is not in the route tree.

- [ ] **Step 3: Add l10n strings**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "gpsTrack_detail_title": "GPS Track",
  "@gpsTrack_detail_title": {
    "description": "App bar title for a single recorded GPS surface track"
  },
  "gpsTrack_detail_notFound": "This track is no longer available.",
  "@gpsTrack_detail_notFound": {
    "description": "Shown when a track id in the URL does not resolve"
  },
  "gpsTrack_detail_unreadable": "Track data could not be read.",
  "@gpsTrack_detail_unreadable": {
    "description": "Shown when a track's stored points blob fails to decode"
  },
  "gpsTrack_detail_noPoints": "This track has no recorded positions.",
  "@gpsTrack_detail_noPoints": {
    "description": "Shown when a track exists but contains zero fixes"
  }
```

Then translate all four into every locale ARB: ar, de, es, fr, he, hu, it, nl, pt, zh. Do not leave English strings in the other files.

- [ ] **Step 4: Regenerate localizations**

```bash
flutter gen-l10n
```

- [ ] **Step 5: Write the failing page test**

Create `test/features/gps_log/gps_track_detail_page_test.dart`. Copy the pump harness shape from `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart` — `getBaseOverrides()` from `test/helpers/mock_providers.dart`, an explicit surface size, and `AppLocalizations.localizationsDelegates`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: 20.0 + t * 0.001, longitude: -87.0);

GpsTrack _track() => GpsTrack(
      id: 'track-1',
      startTime: 1700000000000,
      endTime: 1700003600000,
      pointCount: 4,
      points: [p(0), p(1), p(2), p(3)],
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GpsTrackDetailPage(trackId: 'track-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a map with the track drawn', (tester) async {
    await _pump(tester, overrides: [
      gpsTrackDetailProvider('track-1').overrideWith((ref) async => _track()),
      gpsTrackGeometryProvider(('track-1', TrackLod.detail))
          .overrideWith((ref) async => _track().points),
    ]);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('shows a not-found message for a missing track',
      (tester) async {
    await _pump(tester, overrides: [
      gpsTrackDetailProvider('track-1').overrideWith((ref) async => null),
      gpsTrackGeometryProvider(('track-1', TrackLod.detail))
          .overrideWith((ref) async => const <GpsTrackPoint>[]),
    ]);

    expect(find.text('This track is no longer available.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('shows an unreadable message when decoding throws',
      (tester) async {
    await _pump(tester, overrides: [
      gpsTrackDetailProvider('track-1')
          .overrideWith((ref) async => throw const FormatException('bad gzip')),
      gpsTrackGeometryProvider(('track-1', TrackLod.detail))
          .overrideWith((ref) async => const <GpsTrackPoint>[]),
    ]);

    expect(find.text('Track data could not be read.'), findsOneWidget);
  });

  testWidgets('shows an empty message for a track with no fixes',
      (tester) async {
    await _pump(tester, overrides: [
      gpsTrackDetailProvider('track-1')
          .overrideWith((ref) async => const GpsTrack(
                id: 'track-1',
                startTime: 1700000000000,
                endTime: 1700003600000,
              )),
      gpsTrackGeometryProvider(('track-1', TrackLod.detail))
          .overrideWith((ref) async => const <GpsTrackPoint>[]),
    ]);

    expect(
      find.text('This track has no recorded positions.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_detail_page_test.dart`
Expected: FAIL — `GpsTrackDetailPage` isn't defined.

- [ ] **Step 7: Write the page**

Create `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen map of one recorded GPS surface track.
class GpsTrackDetailPage extends ConsumerStatefulWidget {
  const GpsTrackDetailPage({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<GpsTrackDetailPage> createState() =>
      _GpsTrackDetailPageState();
}

class _GpsTrackDetailPageState extends ConsumerState<GpsTrackDetailPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trackAsync = ref.watch(gpsTrackDetailProvider(widget.trackId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gpsTrack_detail_title)),
      body: trackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A corrupt or undecodable blob must not crash the page. Surface it
        // as a readable message; deletion is offered from the list.
        error: (_, __) => Center(child: Text(l10n.gpsTrack_detail_unreadable)),
        data: (track) {
          if (track == null) {
            return Center(child: Text(l10n.gpsTrack_detail_notFound));
          }
          final points = track.effectivePoints;
          if (points.isEmpty) {
            return Center(child: Text(l10n.gpsTrack_detail_noPoints));
          }
          return _TrackMap(
            trackId: widget.trackId,
            fallbackPoints: points,
            controller: _mapController,
          );
        },
      ),
    );
  }
}

class _TrackMap extends ConsumerWidget {
  const _TrackMap({
    required this.trackId,
    required this.fallbackPoints,
    required this.controller,
  });

  final String trackId;
  final List<GpsTrackPoint> fallbackPoints;
  final MapController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fall back to the unsimplified points while the isolate is working, so
    // the map draws immediately rather than flashing empty.
    final points = ref
            .watch(gpsTrackGeometryProvider((trackId, TrackLod.detail)))
            .value ??
        fallbackPoints;
    final runs = bucketizeTrack(points, TrackColorMode.uniform);
    final bounds = trackBounds(points)!;

    return TrackpadZoomMap(
      controller: controller,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(bounds.minLat, bounds.minLon),
              LatLng(bounds.maxLat, bounds.maxLon),
            ),
            padding: const EdgeInsets.all(48),
          ),
        ),
        children: [
          submersionTileLayer(ref),
          GpsTrackPolylineLayer(
            runs: runs,
            mode: TrackColorMode.uniform,
          ),
          const MapAttribution(),
          MapCompassButton(controller: controller),
        ],
      ),
    );
  }
}
```

There is **no** `mapTileLayerProvider` in this codebase. `map_tile_providers.dart` exposes only `mapTileUrlProvider`, `mapTileMaxZoomProvider`, and `mapTileAttributionProvider`, and every map builds its own `TileLayer` inline. Rather than paste a fourth copy, extract the shared helper in the next step.

Confirm the exact `MapAttribution` and `MapCompassButton` constructor signatures against `dive_activity_map_page.dart`, which already composes both.

- [ ] **Step 7a: Extract the shared tile layer helper**

Four maps now build an identical `TileLayer`. Create `lib/features/maps/presentation/widgets/submersion_tile_layer.dart`:

```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';

/// The app's standard basemap layer: configured tile URL, the diver's max
/// zoom, and the offline cache when it has been initialized.
///
/// Extracted because four maps had grown byte-identical copies of this.
TileLayer submersionTileLayer(WidgetRef ref, {double? maxZoomOverride}) {
  return TileLayer(
    urlTemplate: ref.watch(mapTileUrlProvider),
    userAgentPackageName: 'app.submersion',
    maxZoom: maxZoomOverride ?? ref.watch(mapTileMaxZoomProvider),
    tileProvider: TileCacheService.instance.isInitialized
        ? TileCacheService.instance.getTileProvider()
        : null,
  );
}
```

Then replace the inline `TileLayer` in `dive_locations_map.dart` (around line 170) with `submersionTileLayer(ref)`. Leave the other maps alone for now — `dive_locations_map.dart` is being modified in Phase 4 anyway, so it is in scope; the rest are not.

Run `flutter test test/features/dive_log/` afterwards to confirm no map test regressed.

- [ ] **Step 8: Register the route**

In `lib/core/router/app_router.dart`, add a child of the existing `/gps-log` route (around line 857). Declare it **last** among that route's children so future static siblings can be inserted before it:

```dart
            routes: [
              // Static children MUST precede ':id' - ':id' matches any single
              // segment and would otherwise swallow them.
              GoRoute(
                path: ':id',
                name: 'gpsTrackDetail',
                builder: (context, state) => GpsTrackDetailPage(
                  trackId: state.pathParameters['id']!,
                ),
              ),
            ],
```

- [ ] **Step 9: Make list rows navigate**

In `gps_logger_page.dart`, add `onTap: () => context.push('/gps-log/${track.id}')` to the track `ListTile` (around line 235) and a trailing chevron alongside the existing delete button.

- [ ] **Step 10: Run all the tests**

Run: `flutter test test/features/gps_log/ test/core/router/`
Expected: PASS.

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/presentation/pages/gps_track_detail_page.dart lib/core/router/app_router.dart lib/features/gps_log/presentation/pages/gps_logger_page.dart lib/l10n/ test/features/gps_log/gps_track_detail_page_test.dart test/core/router/app_router_gps_track_test.dart
git commit -m "Add GPS track detail page at /gps-log/:id"
```

---

### Task 11: Colorization toggle and legend

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/track_color_legend.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/track_color_legend_test.dart`
- Test: `test/features/gps_log/gps_track_detail_colorization_test.dart`

**Interfaces:**
- Consumes: `TrackColorMode`, `speedRange` (Task 3); `trackBucketColors` (Task 9); `UnitFormatter.formatSpeed` (Task 4)
- Produces:
  - `trackColorModeProvider` → `StateProvider<TrackColorMode>` defaulting to `TrackColorMode.uniform`
  - `class TrackColorLegend extends ConsumerWidget`

Switching mode must re-run only `bucketizeTrack` — never re-decode or re-simplify. That is what makes the toggle a frame rather than a reload, and the test asserts it by counting geometry-provider reads.

- [ ] **Step 1: Add l10n strings**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "gpsTrack_colorMode_uniform": "Plain",
  "@gpsTrack_colorMode_uniform": {
    "description": "Track colorization mode: single colour"
  },
  "gpsTrack_colorMode_speed": "Speed",
  "@gpsTrack_colorMode_speed": {
    "description": "Track colorization mode: colour by boat speed"
  },
  "gpsTrack_colorMode_elapsed": "Time",
  "@gpsTrack_colorMode_elapsed": {
    "description": "Track colorization mode: colour by elapsed time"
  },
  "gpsTrack_legend_slower": "Slower",
  "@gpsTrack_legend_slower": {
    "description": "Low end of the speed colour legend"
  },
  "gpsTrack_legend_faster": "Faster",
  "@gpsTrack_legend_faster": {
    "description": "High end of the speed colour legend"
  },
  "gpsTrack_legend_start": "Start",
  "@gpsTrack_legend_start": {
    "description": "Low end of the elapsed-time colour legend"
  },
  "gpsTrack_legend_end": "End",
  "@gpsTrack_legend_end": {
    "description": "High end of the elapsed-time colour legend"
  }
```

Translate all seven into ar, de, es, fr, he, hu, it, nl, pt, zh, then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing legend test**

Create `test/features/gps_log/track_color_legend_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_color_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required TrackColorMode mode,
  ({double min, double max})? range,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackColorLegend(mode: mode, speedRangeMps: range),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing in uniform mode', (tester) async {
    await _pump(tester, mode: TrackColorMode.uniform);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('Slower'), findsNothing);
  });

  testWidgets('speed mode labels both ends with formatted speeds',
      (tester) async {
    await _pump(
      tester,
      mode: TrackColorMode.speed,
      range: (min: 0.0, max: 10.0),
    );
    // 0 m/s and 10 m/s = 0.0 and 36.0 km/h under the default metric setting.
    expect(find.textContaining('0.0'), findsWidgets);
    expect(find.textContaining('36.0'), findsWidgets);
  });

  testWidgets('elapsed mode labels start and end', (tester) async {
    await _pump(tester, mode: TrackColorMode.elapsed);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
  });

  testWidgets('speed mode with no range falls back to generic labels',
      (tester) async {
    await _pump(tester, mode: TrackColorMode.speed);
    expect(find.text('Slower'), findsOneWidget);
    expect(find.text('Faster'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_color_legend_test.dart`
Expected: FAIL — `TrackColorLegend` isn't defined.

- [ ] **Step 4: Write the legend widget**

Create `lib/features/gps_log/presentation/widgets/track_color_legend.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour key for the active track colorization mode.
///
/// Renders nothing in uniform mode - a single-colour line needs no legend.
class TrackColorLegend extends ConsumerWidget {
  const TrackColorLegend({
    super.key,
    required this.mode,
    this.speedRangeMps,
  });

  final TrackColorMode mode;
  final ({double min, double max})? speedRangeMps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mode == TrackColorMode.uniform) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = trackBucketColors(
      theme.colorScheme,
      mode,
      kTrackColorBuckets,
    );

    final String lowLabel;
    final String highLabel;
    if (mode == TrackColorMode.speed) {
      final range = speedRangeMps;
      if (range == null) {
        lowLabel = l10n.gpsTrack_legend_slower;
        highLabel = l10n.gpsTrack_legend_faster;
      } else {
        final units = UnitFormatter(ref.watch(settingsProvider));
        lowLabel = units.formatSpeed(range.min);
        highLabel = units.formatSpeed(range.max);
      }
    } else {
      lowLabel = l10n.gpsTrack_legend_start;
      highLabel = l10n.gpsTrack_legend_end;
    }

    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in colors)
                  Container(width: 16, height: 10, color: color),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 16.0 * colors.length,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lowLabel, style: theme.textTheme.labelSmall),
                  Text(highLabel, style: theme.textTheme.labelSmall),
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

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_color_legend_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Write the failing toggle test**

Create `test/features/gps_log/gps_track_detail_colorization_test.dart`. Reuse the `_pump` harness shape from `gps_track_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_color_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
      timestamp: t,
      latitude: 20.0 + t * 0.001,
      longitude: -87.0 + t * 0.001,
    );

final _points = [p(0), p(10), p(20), p(30), p(40)];

GpsTrack _track() => GpsTrack(
      id: 'track-1',
      startTime: 1700000000000,
      endTime: 1700003600000,
      pointCount: _points.length,
      points: _points,
    );

void main() {
  testWidgets('toggling to Speed shows the legend without re-reading geometry',
      (tester) async {
    var geometryReads = 0;
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackDetailProvider('track-1')
              .overrideWith((ref) async => _track()),
          gpsTrackGeometryProvider(('track-1', TrackLod.detail))
              .overrideWith((ref) async {
            geometryReads++;
            return _points;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GpsTrackDetailPage(trackId: 'track-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(geometryReads, 1);
    expect(find.byType(TrackColorLegend), findsOneWidget);

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    // The whole point of the run-bucketing design: changing colour mode
    // re-runs bucketize only. No second decode, no second simplify.
    expect(geometryReads, 1);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('defaults to plain mode', (tester) async {
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackDetailProvider('track-1')
              .overrideWith((ref) async => _track()),
          gpsTrackGeometryProvider(('track-1', TrackLod.detail))
              .overrideWith((ref) async => _points),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GpsTrackDetailPage(trackId: 'track-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Uniform mode draws no legend content.
    expect(find.text('Start'), findsNothing);
    expect(find.text('Slower'), findsNothing);
  });
}
```

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_detail_colorization_test.dart`
Expected: FAIL — no `Speed` control on the page.

- [ ] **Step 8: Add the mode provider and wire the toggle**

Add to `gps_track_map_providers.dart`:

```dart
/// Active colorization mode on the track detail map.
///
/// Held outside the geometry providers on purpose: changing it must re-run
/// bucketizeTrack only, never the decode or the simplify.
final trackColorModeProvider =
    StateProvider<TrackColorMode>((ref) => TrackColorMode.uniform);
```

In `gps_track_detail_page.dart`, add a `SegmentedButton<TrackColorMode>` to the app bar `bottom` (or as a `PreferredSize` strip) with the three l10n labels, reading and writing `trackColorModeProvider`. In `_TrackMap`, replace the hard-coded `TrackColorMode.uniform` with `ref.watch(trackColorModeProvider)` in both the `bucketizeTrack` call and the `GpsTrackPolylineLayer` mode, and overlay `TrackColorLegend` bottom-left inside a `Stack` with `speedRangeMps: speedRange(points)`.

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/features/gps_log/`
Expected: PASS.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add track colorization toggle and colour legend"
```

---

### Task 12: Dive markers on the track

**Files:**
- Modify: `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Test: `test/features/gps_log/dives_on_track_provider_test.dart`
- Test: `test/features/gps_log/gps_track_detail_markers_test.dart`

**Interfaces:**
- Consumes: `gpsTrackDetailProvider` (Task 8)
- Produces:
  - `divesOnTrackProvider(String trackId)` → `FutureProvider.family<List<Dive>, String>`
  - `trackForDiveProvider(String diveId)` → `FutureProvider.family<GpsTrack?, String>`

`trackForDiveProvider` is consumed by Phase 4, not here, but both directions of the same relationship belong in one reviewable unit.

Track `startTime`/`endTime` are epoch **milliseconds** and `Dive.dateTime` is a `DateTime`. Compare in the wall-clock-as-UTC frame: a dive belongs to a track when its entry instant falls between the track's start and end.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/gps_log/dives_on_track_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  /// A track spanning 08:00 to 12:00 wall-clock on 2026-05-22.
  Future<String> seedTrack() async {
    final start = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: start, tzOffsetMinutes: 0);
    await repo.appendBufferPoint(
      id,
      GpsTrackPoint(
        timestamp: start ~/ 1000,
        latitude: 20.0,
        longitude: -87.0,
      ),
    );
    await repo.finalizeTrack(id, endTimeMs: end);
    return id;
  }

  test('returns only dives whose entry falls inside the track window',
      () async {
    final trackId = await seedTrack();
    // Seed three dives through the dive repository: 07:00 (before),
    // 09:30 (inside), 13:00 (after). Use the same dive-seeding helper the
    // existing test/features/gps_log/gps_track_match_service_test.dart uses
    // so the row shape matches.
    await seedDive(DateTime.utc(2026, 5, 22, 7));
    await seedDive(DateTime.utc(2026, 5, 22, 9, 30));
    await seedDive(DateTime.utc(2026, 5, 22, 13));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dives = await container.read(divesOnTrackProvider(trackId).future);
    expect(dives.length, 1);
    expect(dives.single.dateTime.hour, 9);
  });

  test('returns empty for a track with no dives', () async {
    final trackId = await seedTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(divesOnTrackProvider(trackId).future), isEmpty);
  });

  test('trackForDiveProvider finds the covering track', () async {
    final trackId = await seedTrack();
    final diveId = await seedDive(DateTime.utc(2026, 5, 22, 9, 30));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final track = await container.read(trackForDiveProvider(diveId).future);
    expect(track, isNotNull);
    expect(track!.id, trackId);
  });

  test('trackForDiveProvider returns null when no track covers the dive',
      () async {
    await seedTrack();
    final diveId = await seedDive(DateTime.utc(2026, 5, 23, 9, 30));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(trackForDiveProvider(diveId).future), isNull);
  });

  test('an unfinished track (null endTime) matches no dives', () async {
    final start = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: start, tzOffsetMinutes: 0);
    await seedDive(DateTime.utc(2026, 5, 22, 9));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(divesOnTrackProvider(id).future), isEmpty);
  });
}
```

Open `test/features/gps_log/gps_track_match_service_test.dart` and lift its dive-seeding helper into a shared `seedDive(DateTime entry)` in `test/helpers/` so both files use one implementation, then import it here.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/dives_on_track_provider_test.dart`
Expected: FAIL — `divesOnTrackProvider` isn't defined.

- [ ] **Step 3: Implement both providers**

Add to `gps_track_map_providers.dart`:

```dart
/// Dives whose entry instant falls inside [trackId]'s recording window.
///
/// Both sides are wall-clock-as-UTC, so they compare directly with no
/// timezone conversion - that is the whole reason the recorder stores
/// timestamps this way.
final divesOnTrackProvider =
    FutureProvider.family<List<Dive>, String>((ref, trackId) async {
  final track = await ref.watch(gpsTrackDetailProvider(trackId).future);
  final endTime = track?.endTime;
  // An in-progress track has no closed window to test dives against.
  if (track == null || endTime == null) return const [];

  final dives = await ref.watch(allDivesProvider.future);
  return [
    for (final dive in dives)
      if (_entryMillis(dive) >= track.startTime &&
          _entryMillis(dive) <= endTime)
        dive,
  ];
});

/// The track, if any, whose window covers [diveId].
final trackForDiveProvider =
    FutureProvider.family<GpsTrack?, String>((ref, diveId) async {
  final dive = await ref.watch(diveByIdProvider(diveId).future);
  if (dive == null) return null;
  final entry = _entryMillis(dive);

  final tracks = await ref
      .watch(gpsTrackRepositoryProvider)
      .getCompletedTracks(includePoints: false);
  for (final track in tracks) {
    final endTime = track.endTime;
    if (endTime == null) continue;
    if (entry >= track.startTime && entry <= endTime) {
      // Hydrate only the one that matched - never decode every blob.
      return ref.watch(gpsTrackDetailProvider(track.id).future);
    }
  }
  return null;
});

int _entryMillis(Dive dive) => dive.dateTime.millisecondsSinceEpoch;
```

Resolve `allDivesProvider` and `diveByIdProvider` to the actual provider names in `lib/features/dive_log/presentation/providers/dive_providers.dart` — grep for them rather than assuming. Add the `Dive` import back to this file.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/dives_on_track_provider_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the failing marker test**

Create `test/features/gps_log/gps_track_detail_markers_test.dart`, using the `_pump` harness from `gps_track_detail_page_test.dart` plus a `divesOnTrackProvider` override returning two dives with `entryLocation` set. Assert:

```dart
  testWidgets('renders one marker per dive plus start and end', (tester) async {
    // With 2 dives on the track, expect 2 dive markers, 1 start marker,
    // 1 end marker = 4 keyed marker children.
    expect(find.byKey(const ValueKey('track-start-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-end-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-dive-marker-dive-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('track-dive-marker-dive-2')),
        findsOneWidget);
  });

  testWidgets('renders no dive markers when the track has none',
      (tester) async {
    expect(find.byKey(const ValueKey('track-start-marker')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key.toString().contains('track-dive-marker'),
      ),
      findsNothing,
    );
  });
```

Write the full harness bodies following the existing file — these assertions are the contract, the pump setup is mechanical.

- [ ] **Step 6: Add the marker layer**

In `_TrackMap`, add a `MarkerLayer` after the polyline layer with a start marker, an end marker, and one marker per dive from `divesOnTrackProvider`. Tapping a dive marker calls `context.push('/dives/${dive.id}')`.

Put keys on the marker **child** via `KeyedSubtree`, never on the `Marker` itself. flutter_map reuses `Marker.key` for every repeated world copy it renders at low zoom, which produces duplicate-keyed siblings in the layer's `Stack`. `dive_locations_map.dart:117-121` documents this exact trap.

- [ ] **Step 7: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ test/features/gps_log/ test/helpers/
git commit -m "Add dive markers and track-dive association providers"
```

---

### Task 13: Tap a point to read time, speed, and accuracy

**Files:**
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Create: `lib/features/gps_log/presentation/widgets/track_point_info_card.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/track_point_lookup_test.dart`
- Test: `test/features/gps_log/gps_track_detail_inspect_test.dart`

**Interfaces:**
- Consumes: `Polyline.hitValue` from Task 9, `speedMpsBetween` from Task 2
- Produces:
  - `({GpsTrackPoint point, double speedMps})? nearestPointInRun({required List<GpsTrackPoint> fullPoints, required TrackRun run, required LatLng tapped})`
  - `class TrackPointInfoCard extends ConsumerWidget`

**The lookup resolves against the full decoded point list, not the simplified one.** A tap must report a real recorded fix with its real timestamp and accuracy, not whichever survivor of decimation happened to land nearby.

- [ ] **Step 1: Write the failing lookup test**

Create `test/features/gps_log/track_point_lookup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_point_info_card.dart';

GpsTrackPoint p(int t, double lat) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: 0.0, accuracy: 5.0);

void main() {
  // Full track at 1 Hz; the simplified run keeps only the endpoints.
  final full = [
    p(0, 0.0000),
    p(1, 0.0001),
    p(2, 0.0002),
    p(3, 0.0003),
    p(4, 0.0004),
  ];
  final run = TrackRun(points: [full.first, full.last], bucket: 0);

  test('returns a fix that survived decimation only in the full list', () {
    // Tap nearest to the t=2 fix, which is NOT in the simplified run.
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0002, 0.0),
    );
    expect(hit, isNotNull);
    expect(hit!.point.timestamp, 2);
  });

  test('reports the speed of the leg arriving at that fix', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0002, 0.0),
    );
    // 0.0001 deg latitude = 11.12 m, over 1 s.
    expect(hit!.speedMps, closeTo(11.12, 0.05));
  });

  test('clamps the search to the run span, not the whole track', () {
    final shortRun = TrackRun(points: [full[0], full[1]], bucket: 0);
    final hit = nearestPointInRun(
      fullPoints: full,
      run: shortRun,
      tapped: const LatLng(0.0004, 0.0),
    );
    // Tapped near t=4, but the run only spans t=0..1, so it clamps to t=1.
    expect(hit!.point.timestamp, 1);
  });

  test('returns zero speed for the very first fix', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0, 0.0),
    );
    expect(hit!.point.timestamp, 0);
    expect(hit.speedMps, 0.0);
  });

  test('returns null for an empty run', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: const TrackRun(points: [], bucket: 0),
      tapped: const LatLng(0.0, 0.0),
    );
    expect(hit, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_point_lookup_test.dart`
Expected: FAIL — `nearestPointInRun` isn't defined.

- [ ] **Step 3: Add l10n strings**

```json
  "gpsTrack_inspect_time": "Time",
  "@gpsTrack_inspect_time": {"description": "Label for a tapped fix's timestamp"},
  "gpsTrack_inspect_speed": "Speed",
  "@gpsTrack_inspect_speed": {"description": "Label for a tapped fix's speed"},
  "gpsTrack_inspect_accuracy": "Accuracy",
  "@gpsTrack_inspect_accuracy": {"description": "Label for a tapped fix's GPS accuracy"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 4: Implement the lookup and the card**

Create `lib/features/gps_log/presentation/widgets/track_point_info_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds the recorded fix nearest [tapped] within the span [run] covers.
///
/// Searches [fullPoints] rather than the run's own (simplified) points: a tap
/// must report a real recorded fix with its real timestamp and accuracy, not
/// whichever survivor of decimation happened to land nearby. The run only
/// bounds the search window.
({GpsTrackPoint point, double speedMps})? nearestPointInRun({
  required List<GpsTrackPoint> fullPoints,
  required TrackRun run,
  required LatLng tapped,
}) {
  if (run.points.isEmpty || fullPoints.isEmpty) return null;

  final fromTime = run.points.first.timestamp;
  final toTime = run.points.last.timestamp;
  final target = GeoPoint(tapped.latitude, tapped.longitude);

  GpsTrackPoint? best;
  var bestIndex = -1;
  var bestDistance = double.infinity;

  for (var i = 0; i < fullPoints.length; i++) {
    final candidate = fullPoints[i];
    if (candidate.timestamp < fromTime || candidate.timestamp > toTime) {
      continue;
    }
    final d = distanceMeters(toGeoPoint(candidate), target);
    if (d < bestDistance) {
      bestDistance = d;
      best = candidate;
      bestIndex = i;
    }
  }

  if (best == null) return null;
  final speed = bestIndex > 0
      ? speedMpsBetween(fullPoints[bestIndex - 1], best)
      : 0.0;
  return (point: best, speedMps: speed);
}

/// Shows the timestamp, speed, and accuracy of a tapped fix.
class TrackPointInfoCard extends ConsumerWidget {
  const TrackPointInfoCard({
    super.key,
    required this.point,
    required this.speedMps,
    required this.onDismiss,
  });

  final GpsTrackPoint point;
  final double speedMps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Wall-clock-as-UTC: format the UTC components directly. Calling
    // toLocal() here would shift every displayed time by the viewing
    // device's offset.
    final time = DateTime.fromMillisecondsSinceEpoch(
      point.timestamp * 1000,
      isUtc: true,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jms().format(time),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.gpsTrack_inspect_speed}: '
                    '${units.formatSpeed(speedMps)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (point.accuracy != null)
                    Text(
                      '${l10n.gpsTrack_inspect_accuracy}: '
                      '${units.formatDistance(point.accuracy!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_point_lookup_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Wire the hit notifier**

In `_TrackMap`, create a `LayerHitNotifier<int> hitNotifier = ValueNotifier(null)` in a `StatefulWidget`, pass it to `GpsTrackPolylineLayer`, and wrap the polyline layer in a `GestureDetector` that on tap reads `hitNotifier.value?.hitValues.firstOrNull`, maps it to `runs[index]`, calls `nearestPointInRun` with `hitNotifier.value!.coordinate`, and stores the result in local state. Render `TrackPointInfoCard` in the `Stack` when set.

Dispose the notifier in `dispose()`.

- [ ] **Step 7: Write and run the widget test**

Create `test/features/gps_log/gps_track_detail_inspect_test.dart` asserting that tapping the map centre (over the drawn line) shows a `TrackPointInfoCard`, and tapping its close button removes it. Use the `_pump` harness from `gps_track_detail_page_test.dart`.

Run: `flutter test test/features/gps_log/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add tap-to-inspect for recorded track fixes"
```

---

### Task 14: Track statistics header

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/track_stats_header.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/track_stats_header_test.dart`

**Interfaces:**
- Consumes: `trackDistanceMeters`, `speedRange` (Tasks 2-3); `divesOnTrackProvider` (Task 12); `UnitFormatter.formatSpeed` (Task 4)
- Produces: `class TrackStatsHeader extends ConsumerWidget`

- [ ] **Step 1: Add l10n strings**

```json
  "gpsTrack_stats_distance": "Distance",
  "@gpsTrack_stats_distance": {"description": "Total along-track distance"},
  "gpsTrack_stats_duration": "Duration",
  "@gpsTrack_stats_duration": {"description": "Track recording duration"},
  "gpsTrack_stats_avgSpeed": "Avg speed",
  "@gpsTrack_stats_avgSpeed": {"description": "Average speed over the track"},
  "gpsTrack_stats_maxSpeed": "Max speed",
  "@gpsTrack_stats_maxSpeed": {"description": "Fastest leg speed on the track"},
  "gpsTrack_stats_fixes": "Fixes",
  "@gpsTrack_stats_fixes": {"description": "Count of recorded GPS positions"},
  "gpsTrack_stats_dives": "Dives",
  "@gpsTrack_stats_dives": {"description": "Count of dives logged during this track"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/track_stats_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t, double lat) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: 0.0);

Future<void> _pump(WidgetTester tester, List<GpsTrackPoint> points,
    {int diveCount = 0}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(900, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackStatsHeader(points: points, diveCount: diveCount),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reports fix count and dive count', (tester) async {
    await _pump(
      tester,
      [p(0, 0.0), p(10, 0.001), p(20, 0.002)],
      diveCount: 2,
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('renders zeroed stats for an empty track without throwing',
      (tester) async {
    await _pump(tester, const []);
    expect(find.byType(TrackStatsHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a single-fix track without dividing by zero',
      (tester) async {
    await _pump(tester, [p(0, 0.0)]);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_stats_header_test.dart`
Expected: FAIL — `TrackStatsHeader` isn't defined.

- [ ] **Step 4: Implement the header**

Create `lib/features/gps_log/presentation/widgets/track_stats_header.dart` as a horizontally scrollable row of label/value pairs. Compute distance with `trackDistanceMeters`, duration from first-to-last timestamp, average speed as distance over duration (guarding zero duration), and max speed from `speedRange`. Format distance with `units.formatDistance` and both speeds with `units.formatSpeed`.

Wrap the row in `SingleChildScrollView(scrollDirection: Axis.horizontal)` so six stat tiles never overflow on a narrow phone.

- [ ] **Step 5: Mount it on the detail page**

Add `TrackStatsHeader` above the map in `GpsTrackDetailPage`, passing `points` and `divesOnTrackProvider(trackId).value?.length ?? 0`.

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add track statistics header to the detail page"
```

---

**Phase 2 complete.** A diver can open a recorded track, see the path drawn on a map, colorize it by speed or elapsed time, see where their dives happened, tap any point for time and speed, and read the day's totals.

```bash
flutter test
flutter analyze
```

---

## Phase 3: Thumbnails and Overview Map

---

### Task 15: Tile-less track shape painter

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/track_shape_painter.dart`
- Test: `test/features/gps_log/track_shape_painter_test.dart`

**Interfaces:**
- Consumes: `trackBounds` (Task 2)
- Produces:
  - `class TrackShapePainter extends CustomPainter`
  - `class TrackShapeChip extends StatelessWidget` — bounded, self-sizing wrapper

This is the offline fallback for row thumbnails. Recording a track on a boat means recording it with no signal, so tiles failing is the **normal** case for this feature, not an edge case. The shape alone still identifies a dive day.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/track_shape_painter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';

GpsTrackPoint p(double lat, double lon) =>
    GpsTrackPoint(timestamp: 0, latitude: lat, longitude: lon);

void main() {
  group('shouldRepaint', () {
    test('repaints when the points change', () {
      final a = TrackShapePainter(
        points: [p(0, 0), p(1, 1)],
        color: Colors.blue,
      );
      final b = TrackShapePainter(
        points: [p(0, 0), p(2, 2)],
        color: Colors.blue,
      );
      expect(b.shouldRepaint(a), isTrue);
    });

    test('repaints when the colour changes', () {
      final points = [p(0, 0), p(1, 1)];
      final a = TrackShapePainter(points: points, color: Colors.blue);
      final b = TrackShapePainter(points: points, color: Colors.red);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint for identical inputs', () {
      final points = [p(0, 0), p(1, 1)];
      final a = TrackShapePainter(points: points, color: Colors.blue);
      final b = TrackShapePainter(points: points, color: Colors.blue);
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('TrackShapeChip', () {
    testWidgets('renders at the requested size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(
                points: [p(0, 0), p(0.01, 0.01), p(0, 0.02)],
                width: 88,
                height: 64,
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(TrackShapeChip));
      expect(size.width, 88);
      expect(size.height, 64);
    });

    testWidgets('renders an empty track without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(points: [], width: 88, height: 64),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a single-point track without dividing by zero',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(
                points: [p(5, 5)],
                width: 88,
                height: 64,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_shape_painter_test.dart`
Expected: FAIL — `TrackShapePainter` isn't defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gps_log/presentation/widgets/track_shape_painter.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

/// Draws a track's shape with no basemap, scaled to fill the canvas.
///
/// The offline fallback for row thumbnails. A GPS track is recorded on a boat,
/// where there is usually no signal to fetch tiles with, so this path runs
/// often enough to deserve being good rather than being a stub.
class TrackShapePainter extends CustomPainter {
  TrackShapePainter({required this.points, required this.color});

  final List<GpsTrackPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final bounds = trackBounds(points);
    if (bounds == null) return;

    final latSpan = bounds.maxLat - bounds.minLat;
    final lonSpan = bounds.maxLon - bounds.minLon;

    // A perfectly straight north-south or east-west track has a zero span on
    // one axis; substituting 1 collapses that axis to the canvas centre
    // instead of producing NaN.
    final safeLatSpan = latSpan == 0 ? 1.0 : latSpan;
    final safeLonSpan = lonSpan == 0 ? 1.0 : lonSpan;

    // Preserve aspect ratio: use the tighter scale on both axes, then centre.
    const padding = 6.0;
    final usableWidth = size.width - padding * 2;
    final usableHeight = size.height - padding * 2;
    final scale = (usableWidth / safeLonSpan) < (usableHeight / safeLatSpan)
        ? usableWidth / safeLonSpan
        : usableHeight / safeLatSpan;

    final drawnWidth = safeLonSpan * scale;
    final drawnHeight = safeLatSpan * scale;
    final offsetX = (size.width - drawnWidth) / 2;
    final offsetY = (size.height - drawnHeight) / 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = offsetX + (points[i].longitude - bounds.minLon) * scale;
      // Screen y grows downward, latitude grows northward: invert.
      final y = offsetY + (bounds.maxLat - points[i].latitude) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(TrackShapePainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.points, points);
}

/// A fixed-size tinted chip containing a [TrackShapePainter].
class TrackShapeChip extends StatelessWidget {
  const TrackShapeChip({
    super.key,
    required this.points,
    required this.width,
    required this.height,
  });

  final List<GpsTrackPoint> points;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: TrackShapePainter(points: points, color: scheme.primary),
        ),
      ),
    );
  }
}
```

Note `shouldRepaint` compares point lists by identity. Every geometry list in this feature comes from `List.unmodifiable` in `simplifyTrack` or the cache repository, so a changed track always produces a new instance. Deep-comparing thousands of points on every frame would cost more than the repaint it avoids.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_shape_painter_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/presentation/widgets/track_shape_painter.dart test/features/gps_log/track_shape_painter_test.dart
git commit -m "Add tile-less track shape painter for offline thumbnails"
```

---

### Task 16: Row thumbnail mini-map

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/gps_track_thumbnail.dart`
- Test: `test/features/gps_log/gps_track_thumbnail_test.dart`

**Interfaces:**
- Consumes: `gpsTrackGeometryProvider` with `TrackLod.thumbnail` (Task 8); `trackBounds` (Task 2); `TrackShapeChip` (Task 15); `submersionTileLayer` (Task 10)
- Produces: `class GpsTrackThumbnail extends ConsumerWidget` — fixed 88x64

Three properties this widget must have, each for a specific reason:

1. **`InteractiveFlag.none`** so it never enters the gesture arena against the parent `ListView`. Without this, a drag starting on a thumbnail fights the list scroll.
2. **Zoom clamped to <= 12** so tracks from one trip resolve to the same cached tiles. A week in Cozumel then costs a handful of tile fetches total instead of four per row.
3. **`RepaintBoundary`** so a thumbnail repaint does not dirty the whole row.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/gps_track_thumbnail_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
      timestamp: t,
      latitude: 20.0 + t * 0.001,
      longitude: -87.0 + t * 0.001,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<GpsTrackPoint> geometry,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackGeometryProvider(('track-1', TrackLod.thumbnail))
            .overrideWith((ref) async => geometry),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: GpsTrackThumbnail(trackId: 'track-1')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders at exactly 88x64', (tester) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final size = tester.getSize(find.byType(GpsTrackThumbnail));
    expect(size.width, 88);
    expect(size.height, 64);
  });

  testWidgets('renders a non-interactive map when geometry is available',
      (tester) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags, InteractiveFlag.none);
  });

  testWidgets('clamps the camera to zoom 12 or lower', (tester) async {
    // Three fixes within ~300 m would otherwise fit at zoom ~17, which
    // would fetch tiles no other row shares.
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final fit = map.options.initialCameraFit;
    expect(fit, isA<CameraFit>());
    // maxZoom is carried on the CameraFit.bounds variant.
    expect(fit.toString(), contains('12'));
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    expect(
      find.ancestor(
        of: find.byType(FlutterMap),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('falls back to the shape chip for an empty track',
      (tester) async {
    await _pump(tester, geometry: const []);
    expect(find.byType(TrackShapeChip), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('shows the shape chip while geometry is still loading',
      (tester) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackGeometryProvider(('track-1', TrackLod.thumbnail))
              .overrideWith((ref) => Future.delayed(
                    const Duration(seconds: 5),
                    () => <GpsTrackPoint>[],
                  )),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: GpsTrackThumbnail(trackId: 'track-1')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TrackShapeChip), findsOneWidget);
    // Drain the pending timer so the test does not fail on a live timer.
    await tester.pump(const Duration(seconds: 6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_thumbnail_test.dart`
Expected: FAIL — `GpsTrackThumbnail` isn't defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/gps_log/presentation/widgets/gps_track_thumbnail.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';

const double _kThumbWidth = 88;
const double _kThumbHeight = 64;

/// Highest zoom a thumbnail will fit to.
///
/// Deliberately low. Tracks recorded on the same trip then share basemap
/// tiles, so a week of dives costs a handful of tile fetches for the whole
/// list rather than four per row.
const double _kThumbMaxZoom = 12.0;

/// A small non-interactive map preview of one recorded track.
class GpsTrackThumbnail extends ConsumerWidget {
  const GpsTrackThumbnail({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry =
        ref.watch(gpsTrackGeometryProvider((trackId, TrackLod.thumbnail)));

    // While loading, and on any error, show the tile-less shape rather than a
    // spinner: a list of spinners reads as broken, and the shape is the point.
    final points = geometry.value ?? const <GpsTrackPoint>[];
    final bounds = points.length >= 2 ? trackBounds(points) : null;

    if (bounds == null) {
      return TrackShapeChip(
        points: points,
        width: _kThumbWidth,
        height: _kThumbHeight,
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: _kThumbWidth,
        height: _kThumbHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            options: MapOptions(
              // Never interactive: a live map here would fight the parent
              // ListView for the gesture arena on every drag.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(
                  LatLng(bounds.minLat, bounds.minLon),
                  LatLng(bounds.maxLat, bounds.maxLon),
                ),
                padding: const EdgeInsets.all(8),
                maxZoom: _kThumbMaxZoom,
              ),
            ),
            children: [
              submersionTileLayer(ref, maxZoomOverride: _kThumbMaxZoom),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      for (final p in points) LatLng(p.latitude, p.longitude),
                    ],
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/gps_track_thumbnail_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/presentation/widgets/gps_track_thumbnail.dart test/features/gps_log/gps_track_thumbnail_test.dart
git commit -m "Add non-interactive map thumbnail for GPS track rows"
```

---

### Task 17: Wire thumbnails into the list and measure scroll performance

**Files:**
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart`
- Test: `test/features/gps_log/gps_logger_page_test.dart` (extend)
- Test: `test/features/gps_log/gps_track_list_scroll_perf_test.dart`

**Interfaces:**
- Consumes: `GpsTrackThumbnail` (Task 16)

**This task contains the go/no-go measurement for the whole thumbnail approach.** Twenty visible rows means twenty live `FlutterMap` instances, each with a controller, camera, and tile manager. If the measurement fails, the documented remedy is in Step 6 — do not skip the measurement and hope.

- [ ] **Step 1: Convert the track list to a builder**

`gps_logger_page.dart` currently renders tracks with a `for` loop inside a `ListView` (around line 234), which builds **every** row eagerly. With thumbnails attached that would instantiate one `FlutterMap` per track in the database on first paint.

Replace the outer `ListView` with a `CustomScrollView`: keep the record card and match button in a `SliverToBoxAdapter`, and move the track list into a `SliverList.builder` so only visible rows are built.

- [ ] **Step 2: Attach the thumbnail**

Replace the `ListTile`'s `leading: const Icon(Icons.route_outlined)` with:

```dart
                leading: GpsTrackThumbnail(trackId: track.id),
```

and widen `ListTile.minLeadingWidth` to 88 so the thumbnail is not clipped.

- [ ] **Step 3: Extend the existing page test**

Add to `test/features/gps_log/gps_logger_page_test.dart`:

```dart
  testWidgets('each track row shows a thumbnail', (tester) async {
    // Pump the page with two completed tracks in the repository.
    expect(find.byType(GpsTrackThumbnail), findsNWidgets(2));
  });

  testWidgets('tapping a row navigates to the track detail route',
      (tester) async {
    // Pump with a router observer; tap the first row; assert the pushed
    // location is '/gps-log/<id>'.
  });
```

Fill both bodies using the harness already in that file.

- [ ] **Step 4: Write the scroll performance test**

Create `test/features/gps_log/gps_track_list_scroll_perf_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_logger_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

/// Fifty tracks, one per day, three fixes each.
List<GpsTrack> _fiftyTracks() => [
      for (var d = 0; d < 50; d++)
        GpsTrack(
          id: 'track-$d',
          startTime: DateTime.utc(2026, 5, 1)
              .add(Duration(days: d))
              .millisecondsSinceEpoch,
          endTime: DateTime.utc(2026, 5, 1)
              .add(Duration(days: d, hours: 4))
              .millisecondsSinceEpoch,
          pointCount: 3,
          points: [
            for (var i = 0; i < 3; i++)
              GpsTrackPoint(
                timestamp: DateTime.utc(2026, 5, 1)
                        .add(Duration(days: d, minutes: i))
                        .millisecondsSinceEpoch ~/
                    1000,
                latitude: 20.0 + i * 0.001,
                longitude: -87.0 + i * 0.001,
              ),
          ],
        ),
    ];

Future<void> _pumpFifty(WidgetTester tester) async {
  final base = await getBaseOverrides();
  final tracks = _fiftyTracks();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith((ref) async => tracks),
        for (final track in tracks)
          gpsTrackGeometryProvider((track.id, TrackLod.thumbnail))
              .overrideWith((ref) async => track.points),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GpsLoggerPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 50-track list builds only the visible thumbnails',
      (tester) async {
    await _pumpFifty(tester);

    // The guard that matters: if the list eagerly builds every row, 50
    // FlutterMap instances exist at once and the remedy in Step 6 becomes
    // required. A handful on screen is fine.
    final built = find.byType(GpsTrackThumbnail).evaluate().length;
    expect(
      built,
      lessThan(15),
      reason: 'SliverList.builder must not build offscreen rows',
    );
  });

  testWidgets('scrolling a 50-track list settles without exceptions',
      (tester) async {
    await _pumpFifty(tester);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -3000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/gps_log/`
Expected: PASS.

- [ ] **Step 6: Measure on a real device, and apply the remedy only if needed**

Automated widget tests confirm the *build* behaviour but cannot measure frame time. Run the app on a physical Android or iOS device with at least 50 recorded tracks and scroll the GPS Log list:

```bash
flutter run --profile -d <device-id>
```

Watch the performance overlay. If frame times stay under 16 ms, this task is done.

**If it janks, apply the documented remedy rather than inventing one:** pre-render each thumbnail once to PNG bytes and cache them in the local cache DB (a `points BLOB` sibling column, or a second table keyed by `trackId`), then render rows as `Image.memory`. The list then holds zero `FlutterMap` instances. Add this as its own task before continuing to Task 18, and note the measured frame times in its commit message.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/presentation/pages/gps_logger_page.dart test/features/gps_log/
git commit -m "Show track thumbnails in the GPS log list"
```

---

### Task 18: All-tracks overview map

**Files:**
- Create: `lib/features/gps_log/presentation/pages/gps_track_map_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/gps_track_map_page_test.dart`
- Test: `test/core/router/app_router_gps_track_test.dart` (extend)

**Interfaces:**
- Consumes: `gpsTracksProvider` (existing), `gpsTrackGeometryProvider` (Task 8), `MapListScaffold`, `mapListSelectionProvider`
- Produces: route `/gps-log/map` named `gpsTrackMap`; `GpsTrackMapPage`

`MapListScaffold` gives desktop a split pane at >= 1100 px and mobile a map with an info-card overlay, both for free. `DiveActivityMapPage` is the reference consumer.

**The route must be declared before `:id`.** Task 10's router test already asserts this; adding `map` after `:id` will fail it.

- [ ] **Step 1: Extend the router test**

Add to `test/core/router/app_router_gps_track_test.dart`:

```dart
  test('/gps-log/map resolves to the overview, not the :id detail', () {
    final match = appRouter.configuration.findMatch(
      Uri.parse('/gps-log/map'),
    );
    final names = [
      for (final m in match.matches)
        if (m.route is GoRoute) (m.route as GoRoute).name,
    ];
    expect(names, contains('gpsTrackMap'));
    expect(names, isNot(contains('gpsTrackDetail')));
  });

  test('/gps-log/some-uuid still resolves to the detail page', () {
    final match = appRouter.configuration.findMatch(
      Uri.parse('/gps-log/abc-123'),
    );
    final names = [
      for (final m in match.matches)
        if (m.route is GoRoute) (m.route as GoRoute).name,
    ];
    expect(names, contains('gpsTrackDetail'));
  });
```

Adjust `findMatch` to the current go_router API if the signature differs — check the version in `pubspec.lock`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/router/app_router_gps_track_test.dart`
Expected: FAIL — `/gps-log/map` matches `gpsTrackDetail`.

- [ ] **Step 3: Add l10n strings**

```json
  "gpsTrack_map_title": "Track Map",
  "@gpsTrack_map_title": {"description": "App bar title for the all-tracks overview map"},
  "gpsTrack_map_noTracks": "No recorded tracks to show.",
  "@gpsTrack_map_noTracks": {"description": "Empty state on the overview map"},
  "gpsTrack_map_showMap": "Show map",
  "@gpsTrack_map_showMap": {"description": "Tooltip on the GPS log action that opens the overview map"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 4: Write the failing page test**

Create `test/features/gps_log/gps_track_map_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_map_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t, double base) => GpsTrackPoint(
      timestamp: t,
      latitude: base + t * 0.001,
      longitude: -87.0 + t * 0.001,
    );

GpsTrack _track(String id, double base) => GpsTrack(
      id: id,
      startTime: 1700000000000,
      endTime: 1700003600000,
      pointCount: 3,
      points: [p(0, base), p(1, base), p(2, base)],
    );

Future<void> _pump(WidgetTester tester, {Size size = const Size(1400, 900)}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith(
          (ref) async => [_track('t1', 20.0), _track('t2', 25.0)],
        ),
        gpsTrackGeometryProvider(('t1', TrackLod.thumbnail))
            .overrideWith((ref) async => _track('t1', 20.0).points),
        gpsTrackGeometryProvider(('t2', TrackLod.thumbnail))
            .overrideWith((ref) async => _track('t2', 25.0).points),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GpsTrackMapPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws every track on one map', (tester) async {
    await _pump(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    final layers = find.byType(PolylineLayer).evaluate().length;
    expect(layers, greaterThanOrEqualTo(1));
  });

  testWidgets('shows a list pane on a desktop-width surface', (tester) async {
    await _pump(tester);
    expect(find.text('Track Map'), findsOneWidget);
    // MapListScaffold renders the list pane at >= 1100 px.
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('shows only the map on a phone-width surface', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no tracks',
      (tester) async {
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTracksProvider.overrideWith((ref) async => <GpsTrack>[]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GpsTrackMapPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No recorded tracks to show.'), findsOneWidget);
  });

  testWidgets('selecting a track in the list highlights it on the map',
      (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GpsTrackMapPage)),
    );
    container
        .read(mapListSelectionProvider('gps-tracks').notifier)
        .select('t1');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

Adjust the `mapListSelectionProvider` notifier method name to whatever `lib/shared/providers/map_list_selection_provider.dart` actually exposes — read it first.

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_map_page_test.dart`
Expected: FAIL — `GpsTrackMapPage` isn't defined.

- [ ] **Step 6: Write the page**

Create `lib/features/gps_log/presentation/pages/gps_track_map_page.dart` following `dive_activity_map_page.dart`'s structure:

- `MapListScaffold(sectionKey: 'gps-tracks', title: l10n.gpsTrack_map_title, onBackPressed: () => context.go('/gps-log'), listPane: ..., mapPane: ...)`
- The map pane draws every track at `TrackLod.thumbnail` in `colorScheme.outline` (muted), and the selected track at `TrackLod.overview` in `colorScheme.primary` with a thicker stroke, drawn last so it sits on top.
- On selection change, animate the camera to that track's bounds using `calculateZoomForBounds` from `map_utils.dart`.
- The list pane reuses the track row from `gps_logger_page.dart`; extract that row into `lib/features/gps_log/presentation/widgets/gps_track_list_tile.dart` so both pages share one implementation rather than diverging.
- Tapping a track on the map sets `mapListSelectionProvider('gps-tracks')`.

- [ ] **Step 7: Register the route before `:id`**

```dart
            routes: [
              // MUST precede ':id' - ':id' matches any single segment and
              // would otherwise swallow '/gps-log/map'.
              GoRoute(
                path: 'map',
                name: 'gpsTrackMap',
                builder: (context, state) => const GpsTrackMapPage(),
              ),
              GoRoute(
                path: ':id',
                name: 'gpsTrackDetail',
                builder: (context, state) => GpsTrackDetailPage(
                  trackId: state.pathParameters['id']!,
                ),
              ),
            ],
```

- [ ] **Step 8: Add the app bar action**

In `gps_logger_page.dart`, add to the `AppBar` actions:

```dart
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.gpsTrack_map_showMap,
            onPressed: () => context.push('/gps-log/map'),
          ),
```

- [ ] **Step 9: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/ test/core/router/
dart format .
flutter analyze
git add lib/features/gps_log/ lib/core/router/app_router.dart lib/l10n/ test/
git commit -m "Add all-tracks overview map at /gps-log/map"
```

---

### Task 19: Date range filter on the overview map

**Files:**
- Modify: `lib/features/gps_log/presentation/pages/gps_track_map_page.dart`
- Modify: `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/gps_track_date_filter_test.dart`

**Interfaces:**
- Produces:
  - `trackDateFilterProvider` → `StateProvider<DateTimeRange?>`
  - `filteredTracksProvider` → `FutureProvider<List<GpsTrack>>`

"Every track ever" is the one query in this feature that grows without bound, so the overview needs a bound the user controls.

- [ ] **Step 1: Add l10n strings**

```json
  "gpsTrack_filter_all": "All dates",
  "@gpsTrack_filter_all": {"description": "Date filter chip label when no range is set"},
  "gpsTrack_filter_clear": "Clear date filter",
  "@gpsTrack_filter_clear": {"description": "Tooltip for removing the active date range"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/gps_track_date_filter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

GpsTrack _track(String id, DateTime start) => GpsTrack(
      id: id,
      startTime: start.millisecondsSinceEpoch,
      endTime: start.add(const Duration(hours: 4)).millisecondsSinceEpoch,
    );

void main() {
  ProviderContainer _container() {
    final container = ProviderContainer(
      overrides: [
        gpsTracksProvider.overrideWith((ref) async => [
              _track('may', DateTime.utc(2026, 5, 10)),
              _track('june', DateTime.utc(2026, 6, 15)),
              _track('july', DateTime.utc(2026, 7, 20)),
            ]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('returns every track when no filter is set', () async {
    final container = _container();
    expect((await container.read(filteredTracksProvider.future)).length, 3);
  });

  test('includes only tracks starting inside the range', () async {
    final container = _container();
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 6, 30),
    );
    final tracks = await container.read(filteredTracksProvider.future);
    expect(tracks.map((t) => t.id).toList(), ['june']);
  });

  test('includes a track starting exactly on the range end', () async {
    final container = _container();
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2026, 5, 1),
      end: DateTime.utc(2026, 5, 10),
    );
    final tracks = await container.read(filteredTracksProvider.future);
    expect(tracks.map((t) => t.id).toList(), ['may']);
  });

  test('returns empty when the range matches nothing', () async {
    final container = _container();
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2025, 1, 1),
      end: DateTime.utc(2025, 12, 31),
    );
    expect(await container.read(filteredTracksProvider.future), isEmpty);
  });

  test('clearing the filter restores every track', () async {
    final container = _container();
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 6, 30),
    );
    await container.read(filteredTracksProvider.future);
    container.read(trackDateFilterProvider.notifier).state = null;
    expect((await container.read(filteredTracksProvider.future)).length, 3);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_date_filter_test.dart`
Expected: FAIL — `trackDateFilterProvider` isn't defined.

- [ ] **Step 4: Implement the providers**

Add to `gps_track_map_providers.dart`:

```dart
/// Optional date bound on the overview map.
///
/// Null means unbounded. Track start times are wall-clock-as-UTC, so the
/// range's DateTime values are compared against them directly with no
/// timezone conversion.
final trackDateFilterProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Completed tracks narrowed by [trackDateFilterProvider].
final filteredTracksProvider = FutureProvider<List<GpsTrack>>((ref) async {
  final tracks = await ref.watch(gpsTracksProvider.future);
  final range = ref.watch(trackDateFilterProvider);
  if (range == null) return tracks;

  final from = range.start.millisecondsSinceEpoch;
  // Inclusive of the end date's full day.
  final to = range.end
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1))
      .millisecondsSinceEpoch;

  return [
    for (final track in tracks)
      if (track.startTime >= from && track.startTime <= to) track,
  ];
});
```

Add `import 'package:flutter/material.dart';` for `DateTimeRange`.

- [ ] **Step 5: Wire the filter chip**

In `GpsTrackMapPage`, switch the source from `gpsTracksProvider` to `filteredTracksProvider`, and add an app bar action showing either `l10n.gpsTrack_filter_all` or the formatted range. Tapping it opens `showDateRangePicker`; a clear button resets to null.

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add date range filter to the GPS track overview map"
```

---

**Phase 3 complete.** The GPS Log list shows a map preview per row, and an overview map draws every track with selection bound to the list.

```bash
flutter test
flutter analyze
```

---

## Phase 4: Dive Detail Integration

---

### Task 20: Optional track layer on DiveLocationsMap

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_locations_map_track_test.dart`

**Interfaces:**
- Consumes: `TrackRun` (Task 3), `GpsTrackPolylineLayer` (Task 9)
- Produces: `DiveLocationsMap` gains `final List<TrackRun>? trackRuns;` and `final bool fitToTrack;`

Additive and default-null, so all four existing call sites — the dive detail header, the Surface GPS section, the fullscreen locations page, and the match-sites review — keep working untouched.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_locations_map_track_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
      timestamp: t,
      latitude: 12.345 + t * 0.0001,
      longitude: 98.765 + t * 0.0001,
    );

final _runs = [
  TrackRun(points: [p(0), p(1), p(2), p(3)], bucket: 0),
];

Future<void> _pump(
  WidgetTester tester, {
  List<TrackRun>? trackRuns,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        home: Scaffold(
          body: DiveLocationsMap(
            entry: const GeoPoint(12.345, 98.765),
            exit: const GeoPoint(12.346, 98.766),
            interactive: true,
            trackRuns: trackRuns,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws no polyline layer when trackRuns is null',
      (tester) async {
    await _pump(tester);
    expect(find.byType(PolylineLayer<int>), findsNothing);
  });

  testWidgets('draws the track when runs are supplied', (tester) async {
    await _pump(tester, trackRuns: _runs);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('still renders the entry and exit markers with a track',
      (tester) async {
    await _pump(tester, trackRuns: _runs);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
  });

  testWidgets('handles an empty run list without throwing', (tester) async {
    await _pump(tester, trackRuns: const []);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_locations_map_track_test.dart`
Expected: FAIL — `DiveLocationsMap` has no `trackRuns` parameter.

- [ ] **Step 3: Add the parameters**

In `dive_locations_map.dart`, add to the constructor and fields:

```dart
  /// Optional surface track to draw beneath the markers.
  ///
  /// Null for every caller that predates GPS track rendering. When supplied,
  /// the track is drawn first so entry/exit/site markers stay on top.
  final List<TrackRun>? trackRuns;

  /// When true and [trackRuns] is non-empty, the camera fits the track's
  /// extent instead of just the marker points.
  final bool fitToTrack;
```

In `build`, insert the layer immediately after the `TileLayer` and before the `MarkerLayer`:

```dart
              if (trackRuns != null && trackRuns!.isNotEmpty)
                GpsTrackPolylineLayer(
                  runs: trackRuns!,
                  mode: TrackColorMode.uniform,
                  strokeWidth: 3.0,
                ),
```

When `fitToTrack` is true, extend the `points` list used for `CameraFit.bounds` with every run point before computing the fit. Keep the existing `maxZoom: 16.0` cap — a track spanning a few hundred metres would otherwise zoom past the tile provider's limit and render blank, which is the exact bug the existing comment at line 100 documents.

- [ ] **Step 4: Replace the inline TileLayer**

If Task 10 Step 7a has not already been applied here, replace the inline `TileLayer` with `submersionTileLayer(ref)` now.

- [ ] **Step 5: Run all dive_log map tests**

Run: `flutter test test/features/dive_log/`
Expected: PASS, no regressions in the four existing call sites.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_locations_map.dart test/features/dive_log/presentation/widgets/dive_locations_map_track_test.dart
git commit -m "Add optional surface track layer to DiveLocationsMap"
```

---

### Task 21: Windowed track in the Surface GPS section

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/surface_gps_section.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart` (extend)
- Test: `test/features/dive_log/presentation/widgets/surface_gps_track_test.dart`

**Interfaces:**
- Consumes: `trackForDiveProvider` (Task 12), `windowTrack` (Task 2), `bucketizeTrack` (Task 3), `DiveLocationsMap.trackRuns` (Task 20)
- Produces: `surfaceGpsFullTrackProvider` → `StateProvider<bool>`

Two constraints carried from the spec:

- **The lazy gate must survive.** `surface_gps_section.dart:105-109` builds map content only when the section is expanded, so a collapsed section performs no blob decode. Watching `trackForDiveProvider` at the top of `build` would defeat that — it must be watched inside `_content`, which only runs when expanded.
- **Adding a provider dependency to a shared widget breaks its existing consumer tests.** Every current `SurfaceGpsSection` test needs `trackForDiveProvider` overridden or it will hit the real repository. Step 5 handles this explicitly.

- [ ] **Step 1: Add l10n strings**

```json
  "diveLog_detail_surfaceGps_track": "Surface track",
  "@diveLog_detail_surfaceGps_track": {
    "description": "Row label for the GPS surface track covering this dive"
  },
  "diveLog_detail_surfaceGps_trackFixes": "{count, plural, =1{1 fix} other{{count} fixes}}",
  "@diveLog_detail_surfaceGps_trackFixes": {
    "description": "Count of GPS positions in the surface track",
    "placeholders": {"count": {"type": "int"}}
  },
  "diveLog_detail_surfaceGps_showFullTrack": "Full track",
  "@diveLog_detail_surfaceGps_showFullTrack": {
    "description": "Chip that expands the map from the dive window to the whole recording"
  }
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/surface_gps_track_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Dive from 09:00 to 09:45 wall-clock.
Dive _dive() => Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime.utc(2026, 5, 22, 9),
      bottomTime: const Duration(minutes: 45),
      maxDepth: 30.0,
      entryLocation: const GeoPoint(12.34567, 98.76543),
      exitLocation: const GeoPoint(12.34612, 98.76489),
    );

/// Track from 08:00 to 12:00, one fix every 15 minutes.
GpsTrack _track() {
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
    endTime: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    pointCount: 17,
    points: [
      for (var i = 0; i < 17; i++)
        GpsTrackPoint(
          timestamp: startSec + i * 900,
          latitude: 12.345 + i * 0.0002,
          longitude: 98.765 + i * 0.0002,
        ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, {GpsTrack? track}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        surfaceGpsSectionExpandedProvider.overrideWithValue(true),
        trackForDiveProvider('dive-1').overrideWith((ref) async => track),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SurfaceGpsSection(dive: _dive())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a track row when a track covers the dive',
      (tester) async {
    await _pump(tester, track: _track());
    expect(find.text('Surface track'), findsOneWidget);
  });

  testWidgets('shows no track row when no track covers the dive',
      (tester) async {
    await _pump(tester, track: null);
    expect(find.text('Surface track'), findsNothing);
  });

  testWidgets('draws only the dive window plus margin by default',
      (tester) async {
    await _pump(tester, track: _track());
    final layer = tester.widget<PolylineLayer<int>>(
      find.byType(PolylineLayer<int>),
    );
    final drawn = layer.polylines.fold<int>(
      0,
      (sum, line) => sum + line.points.length,
    );
    // Dive 09:00-09:45 plus 15 min either side = 08:45..10:00 = 6 fixes
    // at 15-minute spacing. The full track has 17.
    expect(drawn, lessThan(17));
    expect(drawn, greaterThan(1));
  });

  testWidgets('the full-track chip expands to the whole recording',
      (tester) async {
    await _pump(tester, track: _track());
    await tester.tap(find.text('Full track'));
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer<int>>(
      find.byType(PolylineLayer<int>),
    );
    final drawn = layer.polylines.fold<int>(
      0,
      (sum, line) => sum + line.points.length,
    );
    expect(drawn, 17);
  });

  testWidgets('a collapsed section never resolves the track', (tester) async {
    var resolved = false;
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          surfaceGpsSectionExpandedProvider.overrideWithValue(false),
          trackForDiveProvider('dive-1').overrideWith((ref) async {
            resolved = true;
            return _track();
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SurfaceGpsSection(dive: _dive())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The lazy gate exists so a collapsed section costs nothing. Watching
    // the track provider outside _content would silently break that.
    expect(resolved, isFalse);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/surface_gps_track_test.dart`
Expected: FAIL — no `Surface track` row.

- [ ] **Step 4: Implement the integration**

Add to `dive_detail_ui_providers.dart`:

```dart
/// Whether the Surface GPS map shows the whole recording rather than just
/// the dive's own window.
final surfaceGpsFullTrackProvider = StateProvider<bool>((ref) => false);
```

In `surface_gps_section.dart`, inside `_content` (never in `build`), watch `trackForDiveProvider(widget.dive.id)`. When it resolves to a track:

- Compute the window as `dive.dateTime` minus 15 minutes to `dive.dateTime + bottomTime` plus 15 minutes, both converted to epoch **seconds** to match point timestamps.
- Call `windowTrack` unless `surfaceGpsFullTrackProvider` is true, in which case use `track.effectivePoints` whole.
- Pass `bucketizeTrack(points, TrackColorMode.uniform)` to `DiveLocationsMap.trackRuns`, with `fitToTrack: true`.
- Add a `FilterChip` labelled `l10n.diveLog_detail_surfaceGps_showFullTrack` bound to the provider.
- Add a coordinate-style row: leading route icon, label `l10n.diveLog_detail_surfaceGps_track`, subtitle `l10n.diveLog_detail_surfaceGps_trackFixes(track.pointCount)`, tapping pushes `/gps-log/${track.id}`.

Label the row "Surface track". Never call it the diver's route — during the dive the recording phone is on the boat, so this is the surface support path, and on a drift dive that distinction is the whole point.

- [ ] **Step 5: Repair the existing SurfaceGpsSection tests**

`SurfaceGpsSection` now depends on a new provider, which will make every existing test in `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart` and `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart` hit the real repository.

Add to the override list in **both** files' pump helpers:

```dart
        trackForDiveProvider(_dive().id).overrideWith((ref) async => null),
```

- [ ] **Step 6: Run the full dive_log suite**

Run: `flutter test test/features/dive_log/`
Expected: PASS. If any test fails with a database or repository error, it is missing the override from Step 5.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/ lib/l10n/ test/features/dive_log/
git commit -m "Show the covering surface track in the dive Surface GPS section"
```

---

**Phase 4 complete.** All four rendering surfaces are live.

```bash
flutter test
flutter analyze
```

---

## Phase 5: Export

---

### Task 22: saveTextToFile helper

**Files:**
- Modify: `lib/core/services/export/shared/file_export_utils.dart`
- Test: `test/core/services/export/shared/save_text_to_file_test.dart`

**Interfaces:**
- Produces: `Future<String?> saveTextToFile(String content, String fileName, {required String dialogTitle, required List<String> allowedExtensions})`

`file_export_utils.dart` has `saveAndShareFile` (share sheet, returns `String`) and picker-based `saveImageToFile` / `savePdfToFile` (return `String?`, null on cancel), but **nothing that saves a string to a picked location**. Without this, a "Save to..." menu item would silently behave as share-only.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/shared/save_text_to_file_test.dart`. Model it on the existing `test/core/services/export/file_picker_save_test.dart`, which already stubs `FilePicker.platform`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns null when the user cancels the picker', () async {
    // Install the cancelling FilePicker stub from file_picker_save_test.dart.
    final result = await saveTextToFile(
      '<gpx/>',
      'track.gpx',
      dialogTitle: 'Save GPX',
      allowedExtensions: const ['gpx'],
    );
    expect(result, isNull);
  });

  test('returns the chosen path and writes the content', () async {
    // Install a stub returning a temp-directory path.
    final result = await saveTextToFile(
      '<gpx>hello</gpx>',
      'track.gpx',
      dialogTitle: 'Save GPX',
      allowedExtensions: const ['gpx'],
    );
    expect(result, isNotNull);
    expect(await File(result!).readAsString(), '<gpx>hello</gpx>');
  });
}
```

Lift the FilePicker stub out of `file_picker_save_test.dart` into `test/helpers/` if it is currently file-private, so both tests share one implementation.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/shared/save_text_to_file_test.dart`
Expected: FAIL — `saveTextToFile` isn't defined.

- [ ] **Step 3: Implement it**

Add to `file_export_utils.dart`, next to `savePdfToFile` so the picker-based savers stay together:

```dart
/// Save string content to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file path, or null if the user cancelled.
///
/// The string counterpart to [savePdfToFile]. Distinct from
/// [saveAndShareFile], which always opens the share sheet and cannot be
/// cancelled.
Future<String?> saveTextToFile(
  String content,
  String fileName, {
  required String dialogTitle,
  required List<String> allowedExtensions,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final result = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    bytes: bytes,
  );

  if (result == null) return null;

  // Matching savePdfToFile: on some platforms saveFile returns a path but
  // does not write the bytes itself.
  if (!Platform.isAndroid) {
    await File(result).writeAsBytes(bytes);
  }

  return result;
}
```

Add `import 'dart:convert';` to the file.

- [ ] **Step 4: Run test, format, analyze, commit**

```bash
flutter test test/core/services/export/
dart format .
flutter analyze
git add lib/core/services/export/shared/file_export_utils.dart test/core/services/export/
git commit -m "Add saveTextToFile helper for picker-based text exports"
```

---

### Task 23: GPX document builder

**Files:**
- Create: `lib/core/services/export/gpx/gpx_track_builder.dart`
- Test: `test/core/services/export/gpx/gpx_track_builder_test.dart`

**Interfaces:**
- Consumes: `GpsTrack.effectivePoints` (Task 6)
- Produces: `String buildGpxDocument(GpsTrack track, {required String creator})`

A pure string builder with no I/O, so it is golden-testable. **Export must reverse the timezone conversion:** stored timestamps are wall-clock-as-UTC, and GPX `<time>` is real UTC, so subtract `tzOffsetMinutes` before formatting. A round trip through export and re-import must be lossless.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/gpx/gpx_track_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/gpx/gpx_track_builder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrack _track({
  int tzOffsetMinutes = 0,
  String? name,
  int? trimStart,
  int? trimEnd,
}) {
  // 2026-05-22 08:00:00 wall clock.
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: startSec * 1000,
    endTime: (startSec + 120) * 1000,
    tzOffsetMinutes: tzOffsetMinutes,
    name: name,
    trimStartTime: trimStart,
    trimEndTime: trimEnd,
    pointCount: 3,
    points: [
      GpsTrackPoint(
        timestamp: startSec,
        latitude: 20.5,
        longitude: -87.25,
        accuracy: 5.0,
      ),
      GpsTrackPoint(
        timestamp: startSec + 60,
        latitude: 20.51,
        longitude: -87.26,
      ),
      GpsTrackPoint(
        timestamp: startSec + 120,
        latitude: 20.52,
        longitude: -87.27,
      ),
    ],
  );
}

void main() {
  test('emits a well-formed gpx root with the creator', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(gpx, contains('<gpx'));
    expect(gpx, contains('version="1.1"'));
    expect(gpx, contains('creator="Submersion"'));
    expect(gpx, contains('</gpx>'));
  });

  test('emits one trkpt per fix with lat and lon attributes', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect('<trkpt'.allMatches(gpx).length, 3);
    expect(gpx, contains('lat="20.5"'));
    expect(gpx, contains('lon="-87.25"'));
  });

  test('writes real UTC times for a zero offset', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, contains('<time>2026-05-22T08:00:00Z</time>'));
  });

  test('subtracts tzOffsetMinutes to recover real UTC', () {
    // Recorded at 08:00 local in UTC-5, so real UTC is 13:00.
    final gpx = buildGpxDocument(
      _track(tzOffsetMinutes: -300),
      creator: 'Submersion',
    );
    expect(gpx, contains('<time>2026-05-22T13:00:00Z</time>'));
  });

  test('handles a positive offset', () {
    // 08:00 local in UTC+8 is 00:00 real UTC.
    final gpx = buildGpxDocument(
      _track(tzOffsetMinutes: 480),
      creator: 'Submersion',
    );
    expect(gpx, contains('<time>2026-05-22T00:00:00Z</time>'));
  });

  test('includes the track name when set', () {
    final gpx = buildGpxDocument(
      _track(name: 'Palancar morning'),
      creator: 'Submersion',
    );
    expect(gpx, contains('<name>Palancar morning</name>'));
  });

  test('escapes XML metacharacters in the name', () {
    final gpx = buildGpxDocument(
      _track(name: 'Reef & <Wall>'),
      creator: 'Submersion',
    );
    expect(gpx, contains('Reef &amp; &lt;Wall&gt;'));
    expect(gpx, isNot(contains('<Wall>')));
  });

  test('emits hdop from accuracy where present', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, contains('<hdop>5.0</hdop>'));
    // Only the first fix has accuracy.
    expect('<hdop>'.allMatches(gpx).length, 1);
  });

  test('honours trim bounds via effectivePoints', () {
    final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final gpx = buildGpxDocument(
      _track(trimStart: startSec + 60000),
      creator: 'Submersion',
    );
    // The 08:00 fix is trimmed away; two remain.
    expect('<trkpt'.allMatches(gpx).length, 2);
  });

  test('emits an empty trkseg for a track with no points', () {
    const empty = GpsTrack(id: 'e', startTime: 0, endTime: 1);
    final gpx = buildGpxDocument(empty, creator: 'Submersion');
    expect(gpx, contains('<trkseg>'));
    expect(gpx, isNot(contains('<trkpt')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/gpx/gpx_track_builder_test.dart`
Expected: FAIL — `buildGpxDocument` isn't defined.

- [ ] **Step 3: Implement the builder**

Create `lib/core/services/export/gpx/gpx_track_builder.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Converts a stored wall-clock-as-UTC epoch second into real UTC.
///
/// Points are stored as the recording device's local wall clock reinterpreted
/// as UTC, so recovering the true instant means subtracting the offset that
/// was folded in at record time. GPX <time> is unambiguously real UTC.
DateTime realUtcFrom(int wallClockEpochSeconds, int tzOffsetMinutes) {
  return DateTime.fromMillisecondsSinceEpoch(
    wallClockEpochSeconds * 1000,
    isUtc: true,
  ).subtract(Duration(minutes: tzOffsetMinutes));
}

/// ISO 8601 with a trailing Z, which is what GPX consumers expect.
String _formatGpxTime(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

/// Builds a GPX 1.1 document for [track].
///
/// Pure: no file I/O, no share sheet. Respects trim bounds by reading
/// [GpsTrack.effectivePoints].
String buildGpxDocument(GpsTrack track, {required String creator}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'gpx',
    nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', creator);
      builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');

      builder.element(
        'trk',
        nest: () {
          final name = track.name;
          if (name != null && name.isNotEmpty) {
            // XmlBuilder.text escapes metacharacters for us.
            builder.element('name', nest: () => builder.text(name));
          }
          builder.element(
            'trkseg',
            nest: () {
              for (final point in track.effectivePoints) {
                builder.element(
                  'trkpt',
                  nest: () {
                    builder.attribute('lat', point.latitude.toString());
                    builder.attribute('lon', point.longitude.toString());
                    builder.element(
                      'time',
                      nest: () => builder.text(
                        _formatGpxTime(
                          realUtcFrom(point.timestamp, track.tzOffsetMinutes),
                        ),
                      ),
                    );
                    final accuracy = point.accuracy;
                    if (accuracy != null) {
                      builder.element(
                        'hdop',
                        nest: () => builder.text(accuracy.toString()),
                      );
                    }
                  },
                );
              }
            },
          );
        },
      );
    },
  );

  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/export/gpx/gpx_track_builder_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/export/gpx/ test/core/services/export/gpx/
git commit -m "Add GPX document builder for GPS tracks"
```

---

### Task 24: GPX export service and KML gx:Track

**Files:**
- Create: `lib/core/services/export/gpx/gpx_export_service.dart`
- Modify: `lib/core/services/export/kml/kml_export_service.dart`
- Test: `test/core/services/export/gpx/gpx_export_service_test.dart`
- Test: `test/core/services/export/kml/kml_track_export_test.dart`

**Interfaces:**
- Consumes: `buildGpxDocument` (Task 23), `saveTextToFile` (Task 22), `realUtcFrom` (Task 23)
- Produces:
  - `GpxExportService.shareTrack(GpsTrack)` → `Future<String>`
  - `GpxExportService.saveTrackToFile(GpsTrack)` → `Future<String?>`
  - `KmlExportService.generateTrackKml(GpsTrack)` → `Future<String>`
  - `KmlExportService.shareTrackKml(GpsTrack)` / `saveTrackKmlToFile(GpsTrack)`

`<gx:Track>` interleaves `<when>` and `<gx:coord>` in matching order, and `<gx:coord>` is space-separated `lon lat alt` — the opposite axis order from GPX attributes, which is a classic source of tracks rendering in the Indian Ocean.

- [ ] **Step 1: Write the failing KML test**

Create `test/core/services/export/kml/kml_track_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrack _track({int tzOffsetMinutes = 0}) {
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: startSec * 1000,
    endTime: (startSec + 60) * 1000,
    tzOffsetMinutes: tzOffsetMinutes,
    pointCount: 2,
    points: [
      GpsTrackPoint(timestamp: startSec, latitude: 20.5, longitude: -87.25),
      GpsTrackPoint(
        timestamp: startSec + 60,
        latitude: 20.51,
        longitude: -87.26,
      ),
    ],
  );
}

void main() {
  late KmlExportService service;

  setUp(() => service = KmlExportService());

  test('declares the gx namespace', () async {
    final kml = await service.generateTrackKml(_track());
    expect(kml, contains('xmlns:gx="http://www.google.com/kml/ext/2.2"'));
  });

  test('emits matching counts of when and gx:coord', () async {
    final kml = await service.generateTrackKml(_track());
    expect('<when>'.allMatches(kml).length, 2);
    expect('<gx:coord>'.allMatches(kml).length, 2);
  });

  test('writes gx:coord as lon lat alt, not lat lon', () async {
    final kml = await service.generateTrackKml(_track());
    // Longitude first. Getting this backwards puts a Cozumel track in the
    // Indian Ocean.
    expect(kml, contains('<gx:coord>-87.25 20.5 0</gx:coord>'));
  });

  test('converts wall-clock timestamps back to real UTC', () async {
    final kml = await service.generateTrackKml(_track(tzOffsetMinutes: -300));
    expect(kml, contains('<when>2026-05-22T13:00:00Z</when>'));
  });

  test('produces an empty gx:Track for a track with no points', () async {
    const empty = GpsTrack(id: 'e', startTime: 0, endTime: 1);
    final kml = await service.generateTrackKml(empty);
    expect(kml, contains('<gx:Track>'));
    expect(kml, isNot(contains('<when>')));
  });
}
```

- [ ] **Step 2: Write the failing GPX service test**

Create `test/core/services/export/gpx/gpx_export_service_test.dart` asserting that `saveTrackToFile` returns null when the picker is cancelled and a path otherwise, reusing the FilePicker stub helper from Task 22. Assert the filename pattern is `submersion_track_YYYY-MM-DD.gpx`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/core/services/export/`
Expected: FAIL — `generateTrackKml` isn't defined.

- [ ] **Step 4: Implement the GPX service**

Create `lib/core/services/export/gpx/gpx_export_service.dart`:

```dart
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/gpx/gpx_track_builder.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

const String _kGpxMimeType = 'application/gpx+xml';

/// GPX export for recorded GPS surface tracks.
class GpxExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  String _fileNameFor(GpsTrack track) {
    // Track times are wall-clock-as-UTC: format the UTC components.
    final date = DateTime.fromMillisecondsSinceEpoch(
      track.startTime,
      isUtc: true,
    );
    return 'submersion_track_${_dateFormat.format(date)}.gpx';
  }

  /// Writes the track and opens the system share sheet. Cannot be cancelled.
  Future<String> shareTrack(GpsTrack track) {
    return saveAndShareFile(
      buildGpxDocument(track, creator: 'Submersion'),
      _fileNameFor(track),
      _kGpxMimeType,
    );
  }

  /// Prompts for a location and writes the track there.
  /// Returns null if the user cancelled.
  Future<String?> saveTrackToFile(GpsTrack track) {
    return saveTextToFile(
      buildGpxDocument(track, creator: 'Submersion'),
      _fileNameFor(track),
      dialogTitle: 'Save GPX',
      allowedExtensions: const ['gpx'],
    );
  }
}
```

- [ ] **Step 5: Add gx:Track to the KML service**

Add to `KmlExportService`:

```dart
  /// Builds a KML document containing [track] as a timestamped gx:Track.
  ///
  /// Note the axis order: gx:coord is "lon lat alt", the reverse of GPX's
  /// lat/lon attributes.
  Future<String> generateTrackKml(GpsTrack track) async {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2" '
          'xmlns:gx="http://www.google.com/kml/ext/2.2">')
      ..writeln('  <Document>')
      ..writeln('    <Placemark>')
      ..writeln('      <gx:Track>');

    for (final point in track.effectivePoints) {
      final utc = realUtcFrom(point.timestamp, track.tzOffsetMinutes);
      buffer.writeln('        <when>${_formatKmlTime(utc)}</when>');
    }
    for (final point in track.effectivePoints) {
      buffer.writeln(
        '        <gx:coord>${point.longitude} ${point.latitude} 0</gx:coord>',
      );
    }

    buffer
      ..writeln('      </gx:Track>')
      ..writeln('    </Placemark>')
      ..writeln('  </Document>')
      ..writeln('</kml>');
    return buffer.toString();
  }

  String _formatKmlTime(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${two(utc.month)}-${two(utc.day)}T'
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }

  Future<String> shareTrackKml(GpsTrack track) async {
    return saveAndShareFile(
      await generateTrackKml(track),
      'submersion_track_${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(track.startTime, isUtc: true))}.kml',
      'application/vnd.google-earth.kml+xml',
    );
  }

  Future<String?> saveTrackKmlToFile(GpsTrack track) async {
    return saveTextToFile(
      await generateTrackKml(track),
      'submersion_track_${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(track.startTime, isUtc: true))}.kml',
      dialogTitle: 'Save KML',
      allowedExtensions: const ['kml'],
    );
  }
```

Import `gpx_track_builder.dart` for `realUtcFrom` rather than duplicating the conversion — one implementation, one place for the sign to be wrong.

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/core/services/export/
dart format .
flutter analyze
git add lib/core/services/export/ test/core/services/export/
git commit -m "Add GPX export service and KML gx:Track output"
```

---

### Task 25: Export menu on the track detail page

**Files:**
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/gps_track_export_menu_test.dart`

**Interfaces:**
- Consumes: `GpxExportService`, `KmlExportService.shareTrackKml` (Task 24)

- [ ] **Step 1: Add l10n strings**

```json
  "gpsTrack_action_export": "Export",
  "@gpsTrack_action_export": {"description": "Overflow menu entry that exports the track"},
  "gpsTrack_action_shareGpx": "Share as GPX",
  "@gpsTrack_action_shareGpx": {"description": "Share the track via the system share sheet as GPX"},
  "gpsTrack_action_saveGpx": "Save as GPX...",
  "@gpsTrack_action_saveGpx": {"description": "Save the track to a chosen location as GPX"},
  "gpsTrack_action_shareKml": "Share as KML",
  "@gpsTrack_action_shareKml": {"description": "Share the track via the system share sheet as KML"},
  "gpsTrack_action_saveKml": "Save as KML...",
  "@gpsTrack_action_saveKml": {"description": "Save the track to a chosen location as KML"},
  "gpsTrack_export_saved": "Saved to {path}",
  "@gpsTrack_export_saved": {
    "description": "Confirmation after a successful save",
    "placeholders": {"path": {"type": "String"}}
  },
  "gpsTrack_export_failed": "Export failed.",
  "@gpsTrack_export_failed": {"description": "Shown when writing the export file throws"}
```

The trailing `...` on the save entries follows the platform convention that a menu item opening a further dialog is elided. Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/gps_track_export_menu_test.dart`:

```dart
  testWidgets('the overflow menu offers all four export entries',
      (tester) async {
    // Pump the detail page, tap the overflow icon, expand Export.
    expect(find.text('Share as GPX'), findsOneWidget);
    expect(find.text('Save as GPX...'), findsOneWidget);
    expect(find.text('Share as KML'), findsOneWidget);
    expect(find.text('Save as KML...'), findsOneWidget);
  });

  testWidgets('a cancelled save shows no confirmation', (tester) async {
    // Override the export service with one whose saveTrackToFile returns
    // null. Tap Save as GPX. Assert no SnackBar appears - a cancel is not
    // a failure and must not be reported as one.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a successful save confirms with the path', (tester) async {
    expect(find.textContaining('Saved to'), findsOneWidget);
  });

  testWidgets('a throwing export shows a failure message', (tester) async {
    expect(find.text('Export failed.'), findsOneWidget);
  });
```

Fill the harness bodies using the `_pump` helper from `gps_track_detail_page_test.dart`, adding a `gpxExportServiceProvider` override. Introduce that provider in Step 3 so the service is injectable.

- [ ] **Step 3: Add the export providers and menu**

Add to `gps_track_map_providers.dart`:

```dart
final gpxExportServiceProvider = Provider<GpxExportService>(
  (ref) => GpxExportService(),
);
final kmlExportServiceProvider = Provider<KmlExportService>(
  (ref) => KmlExportService(),
);
```

Add a `PopupMenuButton` to the detail page app bar with an Export submenu. Handle the three outcomes distinctly:

- **null return** — the user cancelled. Show nothing. A cancel is not an error, and reporting it as one trains people to ignore the message.
- **a path** — show `l10n.gpsTrack_export_saved(path)`.
- **a throw** — log via `LoggerService` and show `l10n.gpsTrack_export_failed`.

Capture `ScaffoldMessenger.of(context)` before the await, and guard on `mounted` after — the standard async-gap pattern used in `gps_logger_page.dart:69`.

- [ ] **Step 4: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add GPX and KML export entries to the track detail menu"
```

---

**Phase 5 complete.** Tracks can leave the app as GPX or KML, via share sheet or a chosen location.

```bash
flutter test
flutter analyze
```

---

## Phase 6: Import

---

### Task 26: Timezone resolution for imported tracks

**Files:**
- Create: `lib/features/gps_log/data/services/track_import/track_timezone_resolver.dart`
- Test: `test/features/gps_log/track_timezone_resolver_test.dart`

**Interfaces:**
- Produces:
  - `int toWallClockEpochSecondsAt(DateTime realUtc, int tzOffsetMinutes)`
  - `int? inferOffsetFromDives(DateTime firstFixUtc, List<Dive> dives)`

**This is the trap that would silently break everything downstream.** GPX `<time>` and KML `<when>` carry real UTC. The app stores wall-clock-as-UTC. The existing `toWallClockEpochSeconds` in `track_point_codec.dart` converts via `timestamp.toLocal()` — the **importing** device's zone. Import a Cozumel track while sitting in Seattle and every fix lands two hours off, so dive matching finds nothing and no error is raised anywhere.

The importer must resolve the *track's* offset, not the importer's, and store it in the existing `tzOffsetMinutes` column.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/track_timezone_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_timezone_resolver.dart';

Dive _dive(DateTime entryWallClock) => Dive(
      id: 'd',
      diveNumber: 1,
      dateTime: entryWallClock,
      maxDepth: 30.0,
    );

void main() {
  group('toWallClockEpochSecondsAt', () {
    test('is identity for a zero offset', () {
      final utc = DateTime.utc(2026, 5, 22, 13, 0, 0);
      final result = toWallClockEpochSecondsAt(utc, 0);
      expect(result, utc.millisecondsSinceEpoch ~/ 1000);
    });

    test('shifts a negative offset back to local wall clock', () {
      // 13:00 real UTC in UTC-5 is 08:00 on the wall.
      final utc = DateTime.utc(2026, 5, 22, 13);
      final result = toWallClockEpochSecondsAt(utc, -300);
      final asWallClock = DateTime.fromMillisecondsSinceEpoch(
        result * 1000,
        isUtc: true,
      );
      expect(asWallClock.hour, 8);
      expect(asWallClock.day, 22);
    });

    test('shifts a positive offset forward', () {
      // 00:00 real UTC in UTC+8 is 08:00 on the wall, same day.
      final utc = DateTime.utc(2026, 5, 22, 0);
      final result = toWallClockEpochSecondsAt(utc, 480);
      final asWallClock = DateTime.fromMillisecondsSinceEpoch(
        result * 1000,
        isUtc: true,
      );
      expect(asWallClock.hour, 8);
      expect(asWallClock.day, 22);
    });

    test('rolls the date backwards when the offset crosses midnight', () {
      // 02:00 real UTC in UTC-5 is 21:00 the previous day.
      final utc = DateTime.utc(2026, 5, 22, 2);
      final result = toWallClockEpochSecondsAt(utc, -300);
      final asWallClock = DateTime.fromMillisecondsSinceEpoch(
        result * 1000,
        isUtc: true,
      );
      expect(asWallClock.day, 21);
      expect(asWallClock.hour, 21);
    });

    test('round-trips against the export conversion', () {
      // realUtcFrom is the inverse used by GPX export; the pair must
      // compose to identity or an export/re-import cycle drifts.
      final utc = DateTime.utc(2026, 5, 22, 13, 45, 30);
      const offset = -300;
      final wall = toWallClockEpochSecondsAt(utc, offset);
      final back = DateTime.fromMillisecondsSinceEpoch(
        wall * 1000,
        isUtc: true,
      ).subtract(const Duration(minutes: offset));
      expect(back, utc);
    });
  });

  group('inferOffsetFromDives', () {
    test('returns null when there are no dives', () {
      expect(
        inferOffsetFromDives(DateTime.utc(2026, 5, 22, 13), const []),
        isNull,
      );
    });

    test('infers the offset from the nearest dive on the same day', () {
      // Dive entry wall clock 08:30; track's first fix is 13:00 real UTC.
      // The implied offset is -270 min, snapped to the nearest 15 min.
      final offset = inferOffsetFromDives(
        DateTime.utc(2026, 5, 22, 13),
        [_dive(DateTime.utc(2026, 5, 22, 8, 30))],
      );
      expect(offset, -270);
    });

    test('snaps a near-miss to a whole quarter hour', () {
      // 08:32 implies -268; real zones are multiples of 15.
      final offset = inferOffsetFromDives(
        DateTime.utc(2026, 5, 22, 13),
        [_dive(DateTime.utc(2026, 5, 22, 8, 32))],
      );
      expect(offset! % 15, 0);
    });

    test('returns null when no dive is within a day of the track', () {
      expect(
        inferOffsetFromDives(
          DateTime.utc(2026, 5, 22, 13),
          [_dive(DateTime.utc(2026, 8, 1, 8))],
        ),
        isNull,
      );
    });

    test('rejects an implied offset outside the real range', () {
      // A dive 20 hours off implies an impossible zone; better to admit
      // we do not know than to store a fiction.
      expect(
        inferOffsetFromDives(
          DateTime.utc(2026, 5, 22, 13),
          [_dive(DateTime.utc(2026, 5, 21, 17))],
        ),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_timezone_resolver_test.dart`
Expected: FAIL — `toWallClockEpochSecondsAt` isn't defined.

- [ ] **Step 3: Implement the resolver**

Create `lib/features/gps_log/data/services/track_import/track_timezone_resolver.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Real UTC offsets range from -12:00 to +14:00.
const int _kMinOffsetMinutes = -720;
const int _kMaxOffsetMinutes = 840;

/// Converts a real-UTC instant into the app's wall-clock-as-UTC epoch
/// seconds, using an EXPLICIT offset.
///
/// Deliberately distinct from [toWallClockEpochSeconds] in
/// track_point_codec.dart, which uses the running device's local zone. That
/// is correct while recording (the device IS the recorder) and wrong on
/// import (the device is wherever the diver happens to be sitting).
int toWallClockEpochSecondsAt(DateTime realUtc, int tzOffsetMinutes) {
  return realUtc
          .add(Duration(minutes: tzOffsetMinutes))
          .millisecondsSinceEpoch ~/
      1000;
}

/// Best guess at the offset a track was recorded under, from dives logged
/// around the same time.
///
/// Dive entry times are already wall-clock-as-UTC, so the difference between
/// a dive's stored entry and the track's real-UTC first fix IS the offset.
/// Returns null when nothing plausible can be inferred - the import review
/// step then asks rather than guessing.
int? inferOffsetFromDives(DateTime firstFixUtc, List<Dive> dives) {
  if (dives.isEmpty) return null;

  Dive? nearest;
  var smallestGap = const Duration(days: 1);
  for (final dive in dives) {
    final gap = dive.dateTime.difference(firstFixUtc).abs();
    if (gap < smallestGap) {
      smallestGap = gap;
      nearest = dive;
    }
  }
  if (nearest == null) return null;

  final impliedMinutes =
      nearest.dateTime.difference(firstFixUtc).inMinutes;

  // Snap to a quarter hour: every real-world zone is a multiple of 15.
  final snapped = (impliedMinutes / 15).round() * 15;

  if (snapped < _kMinOffsetMinutes || snapped > _kMaxOffsetMinutes) {
    return null;
  }
  return snapped;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gps_log/track_timezone_resolver_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/data/services/track_import/ test/features/gps_log/track_timezone_resolver_test.dart
git commit -m "Add timezone resolver for imported GPS tracks"
```

---

### Task 27: GPX track parser

**Files:**
- Create: `lib/features/gps_log/data/services/track_import/parsed_track.dart`
- Create: `lib/features/gps_log/data/services/track_import/gpx_track_parser.dart`
- Test: `test/features/gps_log/gpx_track_parser_test.dart`
- Test fixture: `test/fixtures/gps_tracks/sample.gpx`

**Interfaces:**
- Produces:
  - `class ParsedTrack { final String? name; final List<({DateTime utc, double lat, double lon, double? accuracy})> fixes; }`
  - `class TrackParseException implements Exception { final String message; }`
  - `ParsedTrack parseGpx(String xml)`

Parsers return real-UTC fixes. Converting to wall-clock-as-UTC happens once, in the import service, after the offset is resolved — never in a parser.

**Per-point timestamps are required.** They are optional in the GPX schema, but a track without them can be neither matched to dives nor colorized. Rejecting is better than threading a nullable timestamp through the whole model.

- [ ] **Step 1: Create the fixture**

Create `test/fixtures/gps_tracks/sample.gpx`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Garmin" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>Cozumel Day 3</name>
    <trkseg>
      <trkpt lat="20.500000" lon="-87.250000">
        <time>2026-05-22T13:00:00Z</time>
        <hdop>5.0</hdop>
      </trkpt>
      <trkpt lat="20.510000" lon="-87.260000">
        <time>2026-05-22T13:01:00Z</time>
      </trkpt>
      <trkpt lat="20.520000" lon="-87.270000">
        <time>2026-05-22T13:02:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
```

Also create `test/fixtures/gps_tracks/no_time.gpx` (identical but with every `<time>` element removed) and `test/fixtures/gps_tracks/multi_seg.gpx` (two `<trkseg>` blocks of two points each).

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/gpx_track_parser_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/gpx_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

String _fixture(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsStringSync();

void main() {
  test('parses every trkpt', () {
    final track = parseGpx(_fixture('sample.gpx'));
    expect(track.fixes.length, 3);
  });

  test('reads the track name', () {
    expect(parseGpx(_fixture('sample.gpx')).name, 'Cozumel Day 3');
  });

  test('reads coordinates from the attributes', () {
    final first = parseGpx(_fixture('sample.gpx')).fixes.first;
    expect(first.lat, closeTo(20.5, 1e-9));
    expect(first.lon, closeTo(-87.25, 1e-9));
  });

  test('parses time as real UTC, not local', () {
    final first = parseGpx(_fixture('sample.gpx')).fixes.first;
    expect(first.utc.isUtc, isTrue);
    expect(first.utc, DateTime.utc(2026, 5, 22, 13, 0, 0));
  });

  test('reads hdop into accuracy where present', () {
    final fixes = parseGpx(_fixture('sample.gpx')).fixes;
    expect(fixes[0].accuracy, closeTo(5.0, 1e-9));
    expect(fixes[1].accuracy, isNull);
  });

  test('flattens multiple track segments in document order', () {
    final track = parseGpx(_fixture('multi_seg.gpx'));
    expect(track.fixes.length, 4);
    expect(
      track.fixes.map((f) => f.utc.millisecondsSinceEpoch).toList(),
      orderedEquals(
        List<int>.from(
          track.fixes.map((f) => f.utc.millisecondsSinceEpoch),
        )..sort(),
      ),
    );
  });

  test('rejects a file with no per-point timestamps', () {
    expect(
      () => parseGpx(_fixture('no_time.gpx')),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects a file with no track points at all', () {
    expect(
      () => parseGpx('<gpx version="1.1"><trk><trkseg/></trk></gpx>'),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects malformed XML with a TrackParseException, not a raw throw',
      () {
    expect(
      () => parseGpx('<gpx><trk>'),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects a trkpt with out-of-range coordinates', () {
    const bad = '<gpx version="1.1"><trk><trkseg>'
        '<trkpt lat="200.0" lon="-87.0"><time>2026-05-22T13:00:00Z</time>'
        '</trkpt></trkseg></trk></gpx>';
    expect(() => parseGpx(bad), throwsA(isA<TrackParseException>()));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gpx_track_parser_test.dart`
Expected: FAIL — `parseGpx` isn't defined.

- [ ] **Step 4: Implement the shared model and the parser**

Create `lib/features/gps_log/data/services/track_import/parsed_track.dart`:

```dart
/// One fix as it came out of a file, before any timezone reinterpretation.
typedef ParsedFix = ({
  DateTime utc,
  double lat,
  double lon,
  double? accuracy,
});

/// A track as parsed from a file.
///
/// Times are REAL UTC. Conversion to the app's wall-clock-as-UTC convention
/// happens once in the import service, after the track's offset is resolved -
/// never in a parser, which has no way to know the offset.
class ParsedTrack {
  final String? name;
  final List<ParsedFix> fixes;

  const ParsedTrack({this.name, required this.fixes});
}

/// A file could not be understood as a track.
class TrackParseException implements Exception {
  final String message;
  const TrackParseException(this.message);

  @override
  String toString() => 'TrackParseException: $message';
}

/// Rejects coordinates outside the valid range.
void validateCoordinate(double lat, double lon) {
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    throw TrackParseException('Coordinate out of range: $lat, $lon');
  }
}
```

Create `lib/features/gps_log/data/services/track_import/gpx_track_parser.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Parses a GPX 1.0 or 1.1 document into a [ParsedTrack].
///
/// Requires a <time> on every <trkpt>. The schema makes it optional, but a
/// track without timestamps cannot be matched to dives or colorized by speed
/// or elapsed time, so accepting one would mean carrying a nullable timestamp
/// through every downstream feature to serve a file nobody can use.
ParsedTrack parseGpx(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw TrackParseException('Not valid XML: ${e.message}');
  }

  // findAllElements without a namespace matches regardless of the default
  // xmlns, which varies between GPX 1.0 and 1.1 producers.
  final trackPoints = document.findAllElements('trkpt').toList();
  if (trackPoints.isEmpty) {
    throw const TrackParseException('No <trkpt> elements found');
  }

  final fixes = <ParsedFix>[];
  for (final node in trackPoints) {
    final latText = node.getAttribute('lat');
    final lonText = node.getAttribute('lon');
    if (latText == null || lonText == null) {
      throw const TrackParseException('<trkpt> missing lat or lon');
    }
    final lat = double.tryParse(latText);
    final lon = double.tryParse(lonText);
    if (lat == null || lon == null) {
      throw TrackParseException('Unparseable coordinate: $latText, $lonText');
    }
    validateCoordinate(lat, lon);

    final timeText =
        node.findElements('time').firstOrNull?.innerText.trim();
    if (timeText == null || timeText.isEmpty) {
      throw const TrackParseException(
        'Every track point needs a <time>; this file has points without one',
      );
    }
    final parsed = DateTime.tryParse(timeText);
    if (parsed == null) {
      throw TrackParseException('Unparseable time: $timeText');
    }

    final hdopText = node.findElements('hdop').firstOrNull?.innerText.trim();

    fixes.add((
      utc: parsed.toUtc(),
      lat: lat,
      lon: lon,
      accuracy: hdopText == null ? null : double.tryParse(hdopText),
    ));
  }

  fixes.sort((a, b) => a.utc.compareTo(b.utc));

  return ParsedTrack(
    name: document.findAllElements('name').firstOrNull?.innerText.trim(),
    fixes: List.unmodifiable(fixes),
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/gps_log/gpx_track_parser_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gps_log/data/services/track_import/ test/features/gps_log/gpx_track_parser_test.dart test/fixtures/gps_tracks/
git commit -m "Add GPX track parser"
```

---

### Task 28: KML track parser

**Files:**
- Create: `lib/features/gps_log/data/services/track_import/kml_track_parser.dart`
- Test: `test/features/gps_log/kml_track_parser_test.dart`
- Test fixtures: `test/fixtures/gps_tracks/sample.kml`, `linestring.kml`

**Interfaces:**
- Consumes: `ParsedTrack`, `TrackParseException`, `validateCoordinate` (Task 27)
- Produces: `ParsedTrack parseKml(String xml)`

`<gx:coord>` is `lon lat alt`, the reverse of GPX's attribute order. Getting this backwards silently relocates a Cozumel track to the Indian Ocean, so it gets its own test.

Plain `<LineString>` has no timestamps and is therefore rejected, consistent with the GPX rule.

- [ ] **Step 1: Create the fixtures**

Create `test/fixtures/gps_tracks/sample.kml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <Placemark>
      <name>Cozumel Day 3</name>
      <gx:Track>
        <when>2026-05-22T13:00:00Z</when>
        <when>2026-05-22T13:01:00Z</when>
        <when>2026-05-22T13:02:00Z</when>
        <gx:coord>-87.25 20.50 0</gx:coord>
        <gx:coord>-87.26 20.51 0</gx:coord>
        <gx:coord>-87.27 20.52 0</gx:coord>
      </gx:Track>
    </Placemark>
  </Document>
</kml>
```

Create `test/fixtures/gps_tracks/linestring.kml` with a `<LineString><coordinates>` block and no `<when>` elements.

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/kml_track_parser_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/kml_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

String _fixture(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsStringSync();

void main() {
  test('parses every when/coord pair', () {
    expect(parseKml(_fixture('sample.kml')).fixes.length, 3);
  });

  test('reads gx:coord as lon lat, not lat lon', () {
    // The fixture's first coord is "-87.25 20.50 0". Reading it backwards
    // would put this track off the coast of Somalia.
    final first = parseKml(_fixture('sample.kml')).fixes.first;
    expect(first.lat, closeTo(20.50, 1e-9));
    expect(first.lon, closeTo(-87.25, 1e-9));
  });

  test('pairs the nth when with the nth coord', () {
    final fixes = parseKml(_fixture('sample.kml')).fixes;
    expect(fixes[1].utc, DateTime.utc(2026, 5, 22, 13, 1));
    expect(fixes[1].lon, closeTo(-87.26, 1e-9));
  });

  test('reads the placemark name', () {
    expect(parseKml(_fixture('sample.kml')).name, 'Cozumel Day 3');
  });

  test('rejects a LineString with no timestamps', () {
    expect(
      () => parseKml(_fixture('linestring.kml')),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects mismatched when and coord counts', () {
    const bad = '<kml xmlns:gx="x"><gx:Track>'
        '<when>2026-05-22T13:00:00Z</when>'
        '<gx:coord>-87.25 20.5 0</gx:coord>'
        '<gx:coord>-87.26 20.51 0</gx:coord>'
        '</gx:Track></kml>';
    expect(() => parseKml(bad), throwsA(isA<TrackParseException>()));
  });

  test('rejects malformed XML', () {
    expect(() => parseKml('<kml>'), throwsA(isA<TrackParseException>()));
  });

  test('rejects a coord with fewer than two components', () {
    const bad = '<kml xmlns:gx="x"><gx:Track>'
        '<when>2026-05-22T13:00:00Z</when>'
        '<gx:coord>-87.25</gx:coord>'
        '</gx:Track></kml>';
    expect(() => parseKml(bad), throwsA(isA<TrackParseException>()));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/kml_track_parser_test.dart`
Expected: FAIL — `parseKml` isn't defined.

- [ ] **Step 4: Implement the parser**

Create `lib/features/gps_log/data/services/track_import/kml_track_parser.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Parses a KML <gx:Track> into a [ParsedTrack].
///
/// Only the timestamped gx:Track form is supported. A plain <LineString>
/// carries geometry with no times, and a track without times cannot be
/// matched to dives or colorized - same rule as the GPX parser.
ParsedTrack parseKml(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw TrackParseException('Not valid XML: ${e.message}');
  }

  final whens = document.findAllElements('when').toList();
  // The element is namespace-prefixed in every real producer, but match on
  // the local name so an unprefixed document still parses.
  final coords = document
      .descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'coord')
      .toList();

  if (whens.isEmpty || coords.isEmpty) {
    throw const TrackParseException(
      'No <gx:Track> with timestamps found. A plain LineString has no times '
      'and cannot be imported.',
    );
  }
  if (whens.length != coords.length) {
    throw TrackParseException(
      'Mismatched <when> (${whens.length}) and <gx:coord> '
      '(${coords.length}) counts',
    );
  }

  final fixes = <ParsedFix>[];
  for (var i = 0; i < whens.length; i++) {
    final time = DateTime.tryParse(whens[i].innerText.trim());
    if (time == null) {
      throw TrackParseException('Unparseable time: ${whens[i].innerText}');
    }

    // gx:coord is "lon lat alt" - the reverse of GPX's lat/lon attributes.
    final parts = coords[i].innerText.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw TrackParseException('Malformed coord: ${coords[i].innerText}');
    }
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lon == null) {
      throw TrackParseException('Unparseable coord: ${coords[i].innerText}');
    }
    validateCoordinate(lat, lon);

    fixes.add((utc: time.toUtc(), lat: lat, lon: lon, accuracy: null));
  }

  fixes.sort((a, b) => a.utc.compareTo(b.utc));

  return ParsedTrack(
    name: document.findAllElements('name').firstOrNull?.innerText.trim(),
    fixes: List.unmodifiable(fixes),
  );
}
```

- [ ] **Step 5: Run test, format, analyze, commit**

```bash
flutter test test/features/gps_log/kml_track_parser_test.dart
dart format .
flutter analyze
git add lib/features/gps_log/data/services/track_import/kml_track_parser.dart test/features/gps_log/kml_track_parser_test.dart test/fixtures/gps_tracks/
git commit -m "Add KML gx:Track parser"
```

---

### Task 29: CSV track parser and column mapping

**Files:**
- Create: `lib/features/gps_log/data/services/track_import/csv_track_parser.dart`
- Test: `test/features/gps_log/csv_track_parser_test.dart`
- Test fixture: `test/fixtures/gps_tracks/sample.csv`

**Interfaces:**
- Consumes: `ParsedTrack`, `TrackParseException`, `validateCoordinate` (Task 27)
- Produces:
  - `class CsvColumnMapping { final int latIndex, lonIndex, timeIndex; final int? accuracyIndex; final String? timeFormat; }`
  - `List<String> readCsvHeaders(String csv)`
  - `CsvColumnMapping? guessCsvMapping(List<String> headers)`
  - `ParsedTrack parseCsv(String csv, CsvColumnMapping mapping)`

Unlike the XML formats, CSV has no schema, so the user must confirm the mapping. `guessCsvMapping` proposes one from common header names; the UI presents it for confirmation rather than applying it silently.

- [ ] **Step 1: Create the fixture**

Create `test/fixtures/gps_tracks/sample.csv`:

```
timestamp,latitude,longitude,accuracy
2026-05-22T13:00:00Z,20.500000,-87.250000,5.0
2026-05-22T13:01:00Z,20.510000,-87.260000,
2026-05-22T13:02:00Z,20.520000,-87.270000,4.2
```

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/csv_track_parser_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

String _fixture() =>
    File('test/fixtures/gps_tracks/sample.csv').readAsStringSync();

void main() {
  group('readCsvHeaders', () {
    test('returns the header row', () {
      expect(
        readCsvHeaders(_fixture()),
        ['timestamp', 'latitude', 'longitude', 'accuracy'],
      );
    });

    test('throws on an empty file', () {
      expect(() => readCsvHeaders(''), throwsA(isA<TrackParseException>()));
    });
  });

  group('guessCsvMapping', () {
    test('recognises the common header names', () {
      final mapping = guessCsvMapping(
        ['timestamp', 'latitude', 'longitude', 'accuracy'],
      );
      expect(mapping!.timeIndex, 0);
      expect(mapping.latIndex, 1);
      expect(mapping.lonIndex, 2);
      expect(mapping.accuracyIndex, 3);
    });

    test('recognises abbreviated headers case-insensitively', () {
      final mapping = guessCsvMapping(['Time', 'Lat', 'Lon']);
      expect(mapping!.timeIndex, 0);
      expect(mapping.latIndex, 1);
      expect(mapping.lonIndex, 2);
      expect(mapping.accuracyIndex, isNull);
    });

    test('returns null when a required column cannot be identified', () {
      expect(guessCsvMapping(['a', 'b', 'c']), isNull);
    });
  });

  group('parseCsv', () {
    const mapping = CsvColumnMapping(
      timeIndex: 0,
      latIndex: 1,
      lonIndex: 2,
      accuracyIndex: 3,
    );

    test('parses every data row', () {
      expect(parseCsv(_fixture(), mapping).fixes.length, 3);
    });

    test('parses times as real UTC', () {
      final first = parseCsv(_fixture(), mapping).fixes.first;
      expect(first.utc, DateTime.utc(2026, 5, 22, 13));
      expect(first.utc.isUtc, isTrue);
    });

    test('leaves accuracy null for a blank cell', () {
      final fixes = parseCsv(_fixture(), mapping).fixes;
      expect(fixes[0].accuracy, closeTo(5.0, 1e-9));
      expect(fixes[1].accuracy, isNull);
    });

    test('rejects a row with an unparseable coordinate', () {
      const bad = 'time,lat,lon\n2026-05-22T13:00:00Z,north,-87.0\n';
      expect(
        () => parseCsv(
          bad,
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('rejects a row with an unparseable time', () {
      const bad = 'time,lat,lon\nyesterday,20.5,-87.0\n';
      expect(
        () => parseCsv(
          bad,
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('rejects a file with a header but no data rows', () {
      expect(
        () => parseCsv(
          'time,lat,lon\n',
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('skips a trailing blank line rather than failing on it', () {
      const withBlank = 'time,lat,lon\n2026-05-22T13:00:00Z,20.5,-87.0\n\n';
      final track = parseCsv(
        withBlank,
        const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
      );
      expect(track.fixes.length, 1);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/csv_track_parser_test.dart`
Expected: FAIL — `readCsvHeaders` isn't defined.

- [ ] **Step 4: Implement the parser**

Create `lib/features/gps_log/data/services/track_import/csv_track_parser.dart`. Use the `csv` package if it is already a dependency (check `pubspec.yaml`; `csv_export_service.dart` may already pull it in), otherwise split on commas with quote handling.

```dart
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Which CSV column holds which field.
///
/// CSV has no schema, so unlike GPX and KML this cannot be inferred with
/// confidence. [guessCsvMapping] proposes one; the import review step
/// presents it for confirmation rather than applying it silently.
class CsvColumnMapping {
  final int timeIndex;
  final int latIndex;
  final int lonIndex;
  final int? accuracyIndex;

  const CsvColumnMapping({
    required this.timeIndex,
    required this.latIndex,
    required this.lonIndex,
    this.accuracyIndex,
  });
}

const _kTimeHeaders = {'time', 'timestamp', 'datetime', 'date_time', 'utc'};
const _kLatHeaders = {'lat', 'latitude', 'y'};
const _kLonHeaders = {'lon', 'lng', 'long', 'longitude', 'x'};
const _kAccuracyHeaders = {'accuracy', 'hdop', 'precision', 'error'};

List<String> readCsvHeaders(String csv) {
  final lines = const LineSplitter().convert(csv);
  if (lines.isEmpty || lines.first.trim().isEmpty) {
    throw const TrackParseException('File is empty');
  }
  return [for (final h in lines.first.split(',')) h.trim()];
}

/// Proposes a mapping from common header names, or null when the required
/// three cannot be identified.
CsvColumnMapping? guessCsvMapping(List<String> headers) {
  int? find(Set<String> candidates) {
    for (var i = 0; i < headers.length; i++) {
      if (candidates.contains(headers[i].toLowerCase().trim())) return i;
    }
    return null;
  }

  final time = find(_kTimeHeaders);
  final lat = find(_kLatHeaders);
  final lon = find(_kLonHeaders);
  if (time == null || lat == null || lon == null) return null;

  return CsvColumnMapping(
    timeIndex: time,
    latIndex: lat,
    lonIndex: lon,
    accuracyIndex: find(_kAccuracyHeaders),
  );
}

ParsedTrack parseCsv(String csv, CsvColumnMapping mapping) {
  final lines = const LineSplitter().convert(csv);
  if (lines.length < 2) {
    throw const TrackParseException('File has a header but no data rows');
  }

  final fixes = <ParsedFix>[];
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    // Trailing newlines are normal; a blank line is not an error.
    if (line.isEmpty) continue;

    final cells = line.split(',');
    String? cell(int? index) {
      if (index == null || index >= cells.length) return null;
      final value = cells[index].trim();
      return value.isEmpty ? null : value;
    }

    final timeText = cell(mapping.timeIndex);
    final time = timeText == null ? null : DateTime.tryParse(timeText);
    if (time == null) {
      throw TrackParseException('Row ${i + 1}: unparseable time "$timeText"');
    }

    final lat = double.tryParse(cell(mapping.latIndex) ?? '');
    final lon = double.tryParse(cell(mapping.lonIndex) ?? '');
    if (lat == null || lon == null) {
      throw TrackParseException('Row ${i + 1}: unparseable coordinate');
    }
    validateCoordinate(lat, lon);

    fixes.add((
      utc: time.toUtc(),
      lat: lat,
      lon: lon,
      accuracy: double.tryParse(cell(mapping.accuracyIndex) ?? ''),
    ));
  }

  if (fixes.isEmpty) {
    throw const TrackParseException('No usable data rows');
  }
  fixes.sort((a, b) => a.utc.compareTo(b.utc));
  return ParsedTrack(fixes: List.unmodifiable(fixes));
}
```

Add `import 'dart:convert';` for `LineSplitter`.

- [ ] **Step 5: Run test, format, analyze, commit**

```bash
flutter test test/features/gps_log/csv_track_parser_test.dart
dart format .
flutter analyze
git add lib/features/gps_log/data/services/track_import/csv_track_parser.dart test/features/gps_log/csv_track_parser_test.dart test/fixtures/gps_tracks/
git commit -m "Add CSV track parser with column mapping"
```

---

### Task 30: FIT track extraction

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_track_extractor.dart`
- Modify: `lib/features/dive_import/data/services/fit_parser_service.dart`
- Test: `test/features/dive_import/fit_track_extractor_test.dart`

**Interfaces:**
- Consumes: `ParsedTrack`, `ParsedFix` (Task 27)
- Produces: `ParsedTrack? extractFitTrack(List<dynamic> records)`

Nearly free. `fit_parser_service.dart:128-137` **already** walks every FIT record reading `positionLat`/`positionLong` — and keeps only the last one, to use as the dive's exit fix. The whole position stream is right there and currently discarded.

- [ ] **Step 1: Read the existing loop**

Run: `sed -n '120,145p' lib/features/dive_import/data/services/fit_parser_service.dart`

Note the exact record type and the field names. `fit_tool` returns positions already in degrees (the field carries the semicircle scale), per the comment in `fit_summary_extractor.dart:35-36` — do **not** apply `semicircleToDegrees` a second time.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_import/fit_track_extractor_test.dart`. Model the record stubs on whatever `fit_tool` message type the parser iterates — read `fit_profile_extractor.dart` for how existing tests fake records, and follow it:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_track_extractor.dart';

void main() {
  test('returns null when no record carries a position', () {
    final records = [_record(null, null, DateTime.utc(2026, 5, 22, 13))];
    expect(extractFitTrack(records), isNull);
  });

  test('collects every positioned record', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 3);
  });

  test('skips records with no position but keeps the rest', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
      _record(null, null, DateTime.utc(2026, 5, 22, 13, 1)),
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 2);
  });

  test('keeps positions in degrees without re-scaling', () {
    // fit_tool already applies the semicircle scale. Applying it again
    // would collapse every coordinate toward zero.
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
    ];
    final fixes = extractFitTrack(records)!.fixes;
    expect(fixes.first.lat, closeTo(20.50, 1e-6));
    expect(fixes.first.lon, closeTo(-87.25, 1e-6));
  });

  test('returns null for a single positioned record (nothing to draw)', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
    ];
    expect(extractFitTrack(records), isNull);
  });

  test('orders fixes by timestamp', () {
    final records = [
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
    ];
    final fixes = extractFitTrack(records)!.fixes;
    expect(fixes.first.utc.minute, 0);
  });

  test('rejects out-of-range coordinates rather than importing them', () {
    final records = [
      _record(200.0, -87.25, DateTime.utc(2026, 5, 22, 13, 0)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 1);
  });
}
```

Write `_record(lat, lon, time)` as a small fake matching the record shape the parser consumes.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_import/fit_track_extractor_test.dart`
Expected: FAIL — `extractFitTrack` isn't defined.

- [ ] **Step 4: Implement the extractor**

Create `lib/features/dive_import/data/services/fit/fit_track_extractor.dart`:

```dart
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Harvests the full position stream from a FIT file's record messages.
///
/// fit_parser_service already iterates these records reading positionLat and
/// positionLong, but keeps only the last one as the dive's exit fix - the
/// rest of the stream is discarded. This collects all of it into a track.
///
/// Positions come back from fit_tool already in degrees (the field carries
/// the semicircle scale), so no conversion is applied here. Applying
/// semicircleToDegrees a second time would collapse every coordinate.
///
/// Returns null when fewer than two positioned records exist - one fix is a
/// point, not a track.
ParsedTrack? extractFitTrack(List<dynamic> records) {
  final fixes = <ParsedFix>[];

  for (final record in records) {
    final lat = record.positionLat as double?;
    final lon = record.positionLong as double?;
    final time = record.timestamp as DateTime?;
    if (lat == null || lon == null || time == null) continue;

    // A corrupt record should cost one fix, not the whole track.
    try {
      validateCoordinate(lat, lon);
    } on TrackParseException {
      continue;
    }

    fixes.add((utc: time.toUtc(), lat: lat, lon: lon, accuracy: null));
  }

  if (fixes.length < 2) return null;
  fixes.sort((a, b) => a.utc.compareTo(b.utc));
  return ParsedTrack(fixes: List.unmodifiable(fixes));
}
```

Adjust the field accessors to the real `fit_tool` record type discovered in Step 1, and type the parameter properly rather than leaving it `List<dynamic>` if a concrete type is available.

- [ ] **Step 5: Surface it from the parser service**

In `fit_parser_service.dart`, call `extractFitTrack(records)` alongside the existing exit-fix loop and expose the result on the parse result object so the import pipeline can pick it up. Do not change the existing entry/exit behaviour.

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/features/dive_import/
dart format .
flutter analyze
git add lib/features/dive_import/ test/features/dive_import/
git commit -m "Extract the full GPS track from FIT record messages"
```

---

### Task 31: Import service with format sniffing and dedupe

**Files:**
- Create: `lib/features/gps_log/data/services/track_import/track_import_service.dart`
- Modify: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Test: `test/features/gps_log/track_import_service_test.dart`

**Interfaces:**
- Consumes: every parser (Tasks 27-30), `toWallClockEpochSecondsAt` / `inferOffsetFromDives` (Task 26)
- Produces:
  - `enum TrackFileFormat { gpx, kml, csv, fit }`
  - `TrackFileFormat? sniffFormat(String fileName, Uint8List bytes)`
  - `class TrackImportCandidate { final ParsedTrack parsed; final TrackFileFormat format; final String sourceRef; final int tzOffsetMinutes; final String? duplicateOfTrackId; }` plus `copyWith`
  - `TrackImportService.prepare({required String fileName, required Uint8List bytes, CsvColumnMapping? csvMapping})` → `Future<TrackImportCandidate>`
  - `TrackImportService.commit(TrackImportCandidate)` → `Future<String>`
  - `GpsTrackRepository.insertImportedTrack(...)` → `Future<String>`
  - `bool overlapsMoreThan(int aStart, int aEnd, int bStart, int bEnd, double fraction)`

**The service takes bytes, not a string.** Three of the four formats are text, but **FIT is binary** — a `String` parameter cannot carry it, and `utf8.decode` on a FIT file throws. `prepare` accepts `Uint8List` and decodes to UTF-8 only for the text formats.

**Dedupe rule from the spec:** an incoming track is a probable duplicate when its span overlaps an existing track's span by more than **80%** *and* the two share a `source`. Flagged candidates surface as a choice; nothing is dropped or merged silently. Different sources overlapping in time import normally — a phone recording and a handheld recording of the same boat day are legitimately two records.

**prepare and commit are separate** so the review step can adjust the offset before anything is written.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/track_import_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';

import '../../helpers/test_database.dart';

Uint8List _bytes(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsBytesSync();

void main() {
  late TrackImportService service;
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
    service = TrackImportService();
  });

  tearDown(tearDownTestDatabase);

  group('sniffFormat', () {
    Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

    test('recognises gpx by extension', () {
      expect(
        sniffFormat('track.gpx', utf8Bytes('<gpx/>')),
        TrackFileFormat.gpx,
      );
    });

    test('recognises kml by extension', () {
      expect(
        sniffFormat('track.kml', utf8Bytes('<kml/>')),
        TrackFileFormat.kml,
      );
    });

    test('recognises csv by extension', () {
      expect(
        sniffFormat('track.csv', utf8Bytes('a,b,c')),
        TrackFileFormat.csv,
      );
    });

    test('recognises fit by its binary magic, not just the extension', () {
      // A FIT file carries ASCII ".FIT" at byte offset 8.
      final fit = Uint8List(16)
        ..setAll(8, utf8.encode('.FIT'));
      expect(sniffFormat('download.bin', fit), TrackFileFormat.fit);
    });

    test('falls back to content sniffing for an unknown extension', () {
      expect(
        sniffFormat(
          'track.dat',
          utf8Bytes('<?xml version="1.0"?><gpx><trk/></gpx>'),
        ),
        TrackFileFormat.gpx,
      );
    });

    test('returns null for something unrecognisable', () {
      expect(sniffFormat('notes.txt', utf8Bytes('hello world')), isNull);
    });

    test('returns null for binary that is not FIT, without throwing', () {
      // utf8.decode on arbitrary bytes throws; sniffing must not.
      final noise = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01, 0x80]);
      expect(sniffFormat('mystery.bin', noise), isNull);
    });
  });

  group('overlapsMoreThan', () {
    test('detects a full overlap', () {
      expect(overlapsMoreThan(0, 100, 0, 100, 0.8), isTrue);
    });

    test('detects a 90 percent overlap', () {
      expect(overlapsMoreThan(0, 100, 10, 110, 0.8), isTrue);
    });

    test('rejects a 50 percent overlap', () {
      expect(overlapsMoreThan(0, 100, 50, 150, 0.8), isFalse);
    });

    test('rejects disjoint spans', () {
      expect(overlapsMoreThan(0, 100, 200, 300, 0.8), isFalse);
    });

    test('rejects touching-but-not-overlapping spans', () {
      expect(overlapsMoreThan(0, 100, 100, 200, 0.8), isFalse);
    });
  });

  group('prepare', () {
    test('parses a GPX file into a candidate', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(candidate.format, TrackFileFormat.gpx);
      expect(candidate.parsed.fixes.length, 3);
      expect(candidate.sourceRef, 'sample.gpx');
    });

    test('defaults the offset to device-local when no dives overlap',
        () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(
        candidate.tzOffsetMinutes,
        DateTime.now().timeZoneOffset.inMinutes,
      );
    });

    test('flags nothing as duplicate on an empty database', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(candidate.duplicateOfTrackId, isNull);
    });
  });

  group('commit', () {
    test('writes a track with the right source and sourceRef', () async {
      final candidate = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      final id = await service.commit(candidate);

      final track = await repo.getTrack(id);
      expect(track!.source, 'gpx');
      expect(track.sourceRef, 'sample.gpx');
      expect(track.pointCount, 3);
    });

    test('converts fixes to wall-clock-as-UTC using the resolved offset',
        () async {
      final base = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      // Force UTC-5: 13:00 real UTC must land as 08:00 wall clock.
      final candidate = base.copyWith(tzOffsetMinutes: -300);
      final id = await service.commit(candidate);

      final track = await repo.getTrack(id);
      final first = DateTime.fromMillisecondsSinceEpoch(
        track!.points.first.timestamp * 1000,
        isUtc: true,
      );
      expect(first.hour, 8);
      expect(track.tzOffsetMinutes, -300);
    });

    test('flags a re-import of the same file as a duplicate', () async {
      final first = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      await service.commit(first);

      final second = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      expect(second.duplicateOfTrackId, isNotNull);
    });

    test('does not flag an overlapping track from a different source',
        () async {
      final gpx = await service.prepare(
        fileName: 'sample.gpx',
        bytes: _bytes('sample.gpx'),
      );
      await service.commit(gpx);

      // Same times, arriving as CSV: a phone and a handheld recording the
      // same boat day are two legitimate records, not a duplicate.
      final csv = await service.prepare(
        fileName: 'sample.csv',
        bytes: _bytes('sample.csv'),
      );
      expect(csv.duplicateOfTrackId, isNull);
    });

    test('rejects a timestamp-less file with a TrackParseException',
        () async {
      expect(
        () => service.prepare(
          fileName: 'no_time.gpx',
          bytes: _bytes('no_time.gpx'),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_import_service_test.dart`
Expected: FAIL — `TrackImportService` isn't defined.

- [ ] **Step 3: Add the repository insert**

Add to `GpsTrackRepository`, following the existing `finalizeTrack` / `_writeBlob` pattern for HLC and `SyncEventBus.notifyLocalChange()`:

```dart
  /// Inserts a fully-formed imported track in one write.
  ///
  /// Unlike startTrack/appendBufferPoint/finalizeTrack, an import already has
  /// every point in hand, so it skips the local buffer entirely.
  Future<String> insertImportedTrack({
    required List<domain.GpsTrackPoint> points,
    required int startTimeMs,
    required int endTimeMs,
    required int tzOffsetMinutes,
    required String source,
    String? sourceRef,
    String? name,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.gpsTracks).insert(
          GpsTracksCompanion.insert(
            id: id,
            startTime: startTimeMs,
            endTime: Value(endTimeMs),
            tzOffsetMinutes: Value(tzOffsetMinutes),
            pointCount: Value(points.length),
            points: Value(encodeTrackPoints(points)),
            // Always restate source explicitly. A Value.absent() here would
            // silently fall back to the 'phone' default and misattribute an
            // imported track.
            source: Value(source),
            sourceRef: Value(sourceRef),
            name: Value(name),
            createdAt: now,
            updatedAt: now,
          ),
        );
    SyncEventBus.notifyLocalChange();
    return id;
  }
```

- [ ] **Step 4: Implement the service**

Create `lib/features/gps_log/data/services/track_import/track_import_service.dart` with `sniffFormat`, `overlapsMoreThan`, `TrackImportCandidate` (including a `copyWith`), `prepare`, and `commit`.

`sniffFormat` works on bytes, checks the FIT magic before attempting any text decode, and never throws on binary input:

```dart
/// FIT files carry the ASCII bytes ".FIT" at offset 8.
bool _looksLikeFit(Uint8List bytes) {
  if (bytes.length < 12) return false;
  return bytes[8] == 0x2E && // .
      bytes[9] == 0x46 && //  F
      bytes[10] == 0x49 && // I
      bytes[11] == 0x54; //   T
}

/// Identifies a track file from its name and its bytes.
///
/// Checks the FIT magic first: FIT is binary, and utf8.decode on arbitrary
/// bytes throws. Returns null rather than guessing when nothing matches.
TrackFileFormat? sniffFormat(String fileName, Uint8List bytes) {
  if (_looksLikeFit(bytes)) return TrackFileFormat.fit;

  final extension = fileName.toLowerCase().split('.').last;
  switch (extension) {
    case 'gpx':
      return TrackFileFormat.gpx;
    case 'kml':
      return TrackFileFormat.kml;
    case 'csv':
      return TrackFileFormat.csv;
    case 'fit':
      return TrackFileFormat.fit;
  }

  // Unknown extension: sniff the content, but only if it decodes as text.
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return null;
  }

  final head = text.trimLeft().toLowerCase();
  if (head.contains('<gpx')) return TrackFileFormat.gpx;
  if (head.contains('<kml')) return TrackFileFormat.kml;
  return null;
}
```

`prepare` then decodes to text only for the three text formats:

```dart
Future<TrackImportCandidate> prepare({
  required String fileName,
  required Uint8List bytes,
  CsvColumnMapping? csvMapping,
}) async {
  final format = sniffFormat(fileName, bytes);
  if (format == null) {
    throw const TrackParseException('Unrecognised file type');
  }

  final ParsedTrack parsed;
  if (format == TrackFileFormat.fit) {
    // FIT goes through the existing binary parser, not a text decode.
    final records = await FitParserService().readRecords(bytes);
    final track = extractFitTrack(records);
    if (track == null) {
      throw const TrackParseException('No GPS positions in that FIT file');
    }
    parsed = track;
  } else {
    final text = utf8.decode(bytes);
    parsed = switch (format) {
      TrackFileFormat.gpx => parseGpx(text),
      TrackFileFormat.kml => parseKml(text),
      TrackFileFormat.csv => parseCsv(
          text,
          csvMapping ??
              guessCsvMapping(readCsvHeaders(text)) ??
              (throw const TrackParseException(
                'Could not identify the latitude, longitude, and time columns',
              )),
        ),
      TrackFileFormat.fit => throw StateError('handled above'),
    };
  }

  final firstFixUtc = parsed.fixes.first.utc;
  final dives = await DiveRepository().getAllDives();
  final tzOffsetMinutes = inferOffsetFromDives(firstFixUtc, dives) ??
      DateTime.now().timeZoneOffset.inMinutes;

  // Span of the incoming track in wall-clock-as-UTC milliseconds, which is
  // the frame existing tracks are stored in.
  final startMs =
      toWallClockEpochSecondsAt(firstFixUtc, tzOffsetMinutes) * 1000;
  final endMs =
      toWallClockEpochSecondsAt(parsed.fixes.last.utc, tzOffsetMinutes) * 1000;

  // Same source only: a phone recording and a handheld recording of the
  // same boat day are two legitimate records, not a duplicate.
  String? duplicateOfTrackId;
  final existing = await GpsTrackRepository()
      .getCompletedTracks(includePoints: false);
  for (final track in existing) {
    final trackEnd = track.endTime;
    if (trackEnd == null || track.source != format.name) continue;
    if (overlapsMoreThan(startMs, endMs, track.startTime, trackEnd, 0.8)) {
      duplicateOfTrackId = track.id;
      break;
    }
  }

  return TrackImportCandidate(
    parsed: parsed,
    format: format,
    sourceRef: fileName,
    tzOffsetMinutes: tzOffsetMinutes,
    duplicateOfTrackId: duplicateOfTrackId,
  );
}
```

Resolve `DiveRepository().getAllDives()` to the actual accessor in `lib/features/dive_log/data/repositories/` — grep for the method the match service already uses to load dives and reuse it.

Resolve `FitParserService().readRecords` to whatever entry point `fit_parser_service.dart` actually exposes for reading records from bytes — read it and match, adding a method if none is public yet.

`overlapsMoreThan` compares the intersection against the **shorter** of the two spans, so a five-minute clip fully inside a four-hour track counts as a duplicate of it:

```dart
/// True when [a] and [b] overlap by more than [fraction] of the shorter span.
bool overlapsMoreThan(
  int aStart,
  int aEnd,
  int bStart,
  int bEnd,
  double fraction,
) {
  final overlapStart = aStart > bStart ? aStart : bStart;
  final overlapEnd = aEnd < bEnd ? aEnd : bEnd;
  final overlap = overlapEnd - overlapStart;
  if (overlap <= 0) return false;

  final aSpan = aEnd - aStart;
  final bSpan = bEnd - bStart;
  final shorter = aSpan < bSpan ? aSpan : bSpan;
  if (shorter <= 0) return false;

  return overlap / shorter > fraction;
}
```

`prepare` sniffs the format, runs the matching parser, resolves the offset via `inferOffsetFromDives` falling back to `DateTime.now().timeZoneOffset.inMinutes`, then checks every existing track of the same `source` with `overlapsMoreThan(..., 0.8)`.

`commit` maps each `ParsedFix` through `toWallClockEpochSecondsAt(fix.utc, candidate.tzOffsetMinutes)` and calls `insertImportedTrack`, then triggers the existing match sweep via `gpsTrackMatchServiceProvider`.

- [ ] **Step 5: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ test/features/gps_log/
git commit -m "Add track import service with format sniffing and dedupe"
```

---

### Task 32: Import UI and review step

**Files:**
- Create: `lib/features/gps_log/presentation/pages/track_import_review_page.dart`
- Create: `lib/features/gps_log/presentation/widgets/csv_column_mapping_form.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/track_import_review_page_test.dart`

**Interfaces:**
- Consumes: `TrackImportService`, `TrackImportCandidate` (Task 31); `guessCsvMapping`, `CsvColumnMapping` (Task 29)

- [ ] **Step 1: Add l10n strings**

```json
  "gpsTrack_import_action": "Import track...",
  "@gpsTrack_import_action": {"description": "Menu entry that opens a file picker to import a GPS track"},
  "gpsTrack_import_reviewTitle": "Review Import",
  "@gpsTrack_import_reviewTitle": {"description": "Title of the import review screen"},
  "gpsTrack_import_fixCount": "{count, plural, =1{1 fix} other{{count} fixes}}",
  "@gpsTrack_import_fixCount": {
    "description": "Number of positions in the track being imported",
    "placeholders": {"count": {"type": "int"}}
  },
  "gpsTrack_import_timezone": "Recorded in",
  "@gpsTrack_import_timezone": {"description": "Label for the timezone offset selector"},
  "gpsTrack_import_timezoneHint": "Times in the file are UTC. Set the zone the track was recorded in so it lines up with your dives.",
  "@gpsTrack_import_timezoneHint": {"description": "Explains why the offset matters"},
  "gpsTrack_import_duplicate": "This looks like a duplicate of an existing track.",
  "@gpsTrack_import_duplicate": {"description": "Warning when the incoming track overlaps an existing one"},
  "gpsTrack_import_confirm": "Import",
  "@gpsTrack_import_confirm": {"description": "Button that commits the import"},
  "gpsTrack_import_failed": "Could not read that file: {reason}",
  "@gpsTrack_import_failed": {
    "description": "Shown when parsing fails",
    "placeholders": {"reason": {"type": "String"}}
  },
  "gpsTrack_import_csvMapping": "Match the columns",
  "@gpsTrack_import_csvMapping": {"description": "Heading for the CSV column mapping form"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/gps_log/track_import_review_page_test.dart`:

```dart
  testWidgets('shows the fix count and inferred timezone', (tester) async {
    // Pump the review page with a prepared GPX candidate of 3 fixes and
    // offset -300.
    expect(find.text('3 fixes'), findsOneWidget);
    expect(find.textContaining('UTC-5'), findsOneWidget);
  });

  testWidgets('changing the offset updates the previewed first fix time',
      (tester) async {
    // The whole reason this screen exists: the user must be able to see and
    // correct the offset before anything is written.
  });

  testWidgets('warns when the candidate is flagged as a duplicate',
      (tester) async {
    expect(
      find.text('This looks like a duplicate of an existing track.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the column mapping form for a CSV candidate',
      (tester) async {
    expect(find.text('Match the columns'), findsOneWidget);
  });

  testWidgets('does not show the mapping form for a GPX candidate',
      (tester) async {
    expect(find.text('Match the columns'), findsNothing);
  });

  testWidgets('a parse failure shows the reason and offers no Import button',
      (tester) async {
    expect(find.textContaining('Could not read that file'), findsOneWidget);
    expect(find.text('Import'), findsNothing);
  });
```

Fill the harness bodies using the `_pump` pattern from the other gps_log page tests.

- [ ] **Step 3: Build the review page**

Create `track_import_review_page.dart` showing:

- Track name (editable), fix count, and the time span rendered from the *currently selected* offset.
- A timezone offset selector defaulting to `candidate.tzOffsetMinutes`, with `gpsTrack_import_timezoneHint` beneath it. Changing it re-renders the previewed times live, so a wrong guess is visible before it is committed rather than after dives fail to match.
- A duplicate warning banner with skip / import-anyway when `duplicateOfTrackId` is set.
- The CSV mapping form when `format == TrackFileFormat.csv`, pre-filled from `guessCsvMapping`.
- An Import button calling `service.commit`, then popping with a confirmation.

Create `csv_column_mapping_form.dart` as a set of dropdowns, one per required field, populated from `readCsvHeaders`.

- [ ] **Step 4: Add the entry point and route**

Add an `Import track...` entry to the GPS Log app bar overflow that opens:

```dart
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'kml', 'csv', 'fit'],
      // Needed so FIT, which is binary, arrives intact rather than as a
      // path we would then have to read separately on every platform.
      withData: true,
    );
```

then calls `service.prepare(fileName: result.files.single.name, bytes: result.files.single.bytes!)` and pushes the review page. Catch `TrackParseException` and show `gpsTrack_import_failed(e.message)` rather than letting it escape.

Register `/gps-log/import` **before** `:id`, alongside `map`.

- [ ] **Step 5: Extend the router test**

Add to `test/core/router/app_router_gps_track_test.dart` a case asserting `/gps-log/import` resolves to the import route and not `gpsTrackDetail`, mirroring the `/gps-log/map` cases.

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/ test/core/router/
dart format .
flutter analyze
git add lib/features/gps_log/ lib/core/router/app_router.dart lib/l10n/ test/
git commit -m "Add GPS track import UI with timezone review and CSV mapping"
```

---

**Phase 6 complete.** Tracks arrive from GPX, KML, CSV, and FIT, with the timezone confirmed before anything is written.

```bash
flutter test
flutter analyze
```

---

## Phase 7: Trim and Split

The only phase that mutates a synced record. Ordering matters here in a way it does not anywhere else in this plan.

---

### Task 33: Non-destructive trim

**Files:**
- Modify: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Modify: `lib/features/gps_log/presentation/providers/gps_track_map_providers.dart`
- Test: `test/features/gps_log/gps_track_trim_test.dart`

**Interfaces:**
- Consumes: `effectivePoints` (Task 6), `TrackGeometryCacheRepository.invalidate` (Task 8)
- Produces:
  - `GpsTrackRepository.setTrimBounds(String id, {int? startMs, int? endMs})` → `Future<void>`
  - `GpsTrackRepository.clearTrim(String id)` → `Future<void>`

Trim writes only the two bound columns. **The points blob is never rewritten**, which makes trimming free, fully reversible, a tiny sync payload, and incapable of losing a fix. That is the entire reason the design chose bounds over truncation.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/gps_track_trim_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  /// Track from 08:00 to 12:00 with a fix every hour.
  Future<String> seed() async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: startMs, tzOffsetMinutes: 0);
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.01,
          longitude: -87.0,
        ),
      );
    }
    await repo.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  test('setTrimBounds narrows effectivePoints', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
      endMs: DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch,
    );
    final track = await repo.getTrack(id);
    expect(track!.effectivePoints.length, 3);
  });

  test('trimming never rewrites the points blob', () async {
    final id = await seed();
    final before = (await repo.getTrack(id))!.points.length;

    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    final after = await repo.getTrack(id);
    // The stored points are untouched; only the view of them narrows.
    expect(after!.points.length, before);
    expect(after.effectivePoints.length, lessThan(before));
  });

  test('clearTrim restores every fix', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    await repo.clearTrim(id);

    final track = await repo.getTrack(id);
    expect(track!.effectivePoints.length, 5);
    expect(track.trimStartTime, isNull);
    expect(track.trimEndTime, isNull);
  });

  test('a start-only trim leaves the end open', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    final track = await repo.getTrack(id);
    expect(track!.trimEndTime, isNull);
    expect(track.effectivePoints.length, 3);
  });

  test('trimming bumps updatedAt so the change syncs', () async {
    final id = await seed();
    final db = DatabaseService.instance.database;

    Future<int> updatedAt() async => (await (db.select(db.gpsTracks)
              ..where((t) => t.id.equals(id)))
            .getSingle())
        .updatedAt;

    final before = await updatedAt();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    expect(await updatedAt(), greaterThan(before));
  });

  test('a trim excluding everything yields no points but keeps the blob',
      () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 23).millisecondsSinceEpoch,
    );
    final track = await repo.getTrack(id);
    expect(track!.effectivePoints, isEmpty);
    expect(track.points, isNotEmpty);
  });
}
```

Note the `updatedAt` test reads the Drift row directly rather than going through `GpsTrack`. The **column** exists on `gps_tracks`, but the **domain entity does not expose it** — `gps_track.dart` carries no `updatedAt` field. Do not add one just for this assertion; the timestamp is sync bookkeeping, not something any view needs.

Add `import 'package:submersion/core/services/database_service.dart';` to the test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_trim_test.dart`
Expected: FAIL — `setTrimBounds` isn't defined.

- [ ] **Step 3: Implement the writes**

Add to `GpsTrackRepository`:

```dart
  /// Sets non-destructive trim bounds. The points blob is untouched.
  ///
  /// Passing null for a bound leaves that end open. Use [clearTrim] to
  /// remove both.
  Future<void> setTrimBounds(
    String id, {
    int? startMs,
    int? endMs,
  }) async {
    await (_db.update(_db.gpsTracks)..where((t) => t.id.equals(id))).write(
      GpsTracksCompanion(
        trimStartTime: Value(startMs),
        trimEndTime: Value(endMs),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Removes both trim bounds, restoring the full recording.
  Future<void> clearTrim(String id) => setTrimBounds(id);
```

- [ ] **Step 4: Invalidate the geometry cache**

Trim changes which points a track represents, so every cached LOD for it is stale. Wire this in the provider layer rather than the repository, so the data layer stays unaware of the presentation cache:

```dart
/// Trims a track and drops its cached geometry.
final trimTrackProvider = Provider(
  (ref) => (String id, {int? startMs, int? endMs}) async {
    await ref
        .read(gpsTrackRepositoryProvider)
        .setTrimBounds(id, startMs: startMs, endMs: endMs);
    await ref.read(trackGeometryCacheRepositoryProvider).invalidate(id);
    ref.invalidate(gpsTrackDetailProvider(id));
  },
);
```

- [ ] **Step 5: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ test/features/gps_log/gps_track_trim_test.dart
git commit -m "Add non-destructive trim bounds for GPS tracks"
```

---

### Task 34: Ordered split

**Files:**
- Modify: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Test: `test/features/gps_log/gps_track_split_test.dart`

**Interfaces:**
- Consumes: `insertImportedTrack` (Task 31), `effectivePoints` (Task 6)
- Produces: `GpsTrackRepository.splitTrack(String id, int atWallClockMs)` → `Future<(String, String)>`

**Write both children before tombstoning the parent.** A crash between those steps then leaves two children *and* the parent — visible duplicates the user can delete. Tombstoning first and crashing before the writes would leave nothing at all. That ordering is the entire safety property of this task and the test asserts it directly.

- [ ] **Step 1: Write the failing test**

Create `test/features/gps_log/gps_track_split_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  /// 08:00 to 12:00, one fix per hour, five fixes.
  Future<String> seed({String? name}) async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(
      startTimeMs: startMs,
      tzOffsetMinutes: -300,
    );
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.01,
          longitude: -87.0,
        ),
      );
    }
    await repo.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  test('produces two tracks covering all the original fixes', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    final first = await repo.getTrack(firstId);
    final second = await repo.getTrack(secondId);
    expect(first!.points.length + second!.points.length, 5);
  });

  test('puts the split point in the first child', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    expect((await repo.getTrack(firstId))!.points.length, 3);
    expect((await repo.getTrack(secondId))!.points.length, 2);
  });

  test('tombstones the parent', () async {
    final id = await seed();
    await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    expect(await repo.getTrack(id), isNull);
  });

  test('children inherit tzOffsetMinutes and source', () async {
    final id = await seed();
    final (firstId, secondId) = await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    for (final childId in [firstId, secondId]) {
      final child = await repo.getTrack(childId);
      expect(child!.tzOffsetMinutes, -300);
      expect(child.source, 'phone');
    }
  });

  test('children exist before the parent is deleted', () async {
    // The safety property: if this ordering ever inverts, a crash mid-split
    // destroys the track instead of duplicating it.
    final id = await seed();
    final observed = <String>[];
    repo.debugOnWrite = observed.add;

    await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    expect(observed.length, 3);
    expect(observed.last, 'delete:$id');
    expect(observed.sublist(0, 2).every((e) => e.startsWith('insert:')), isTrue);
  });

  test('rejects a split point outside the track span', () async {
    final id = await seed();
    expect(
      () => repo.splitTrack(
        id,
        DateTime.utc(2026, 5, 23).millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a split that would leave a child empty', () async {
    final id = await seed();
    expect(
      () => repo.splitTrack(
        id,
        DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });

  test('splitting respects existing trim bounds', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    final (firstId, secondId) = await repo.splitTrack(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    // The 08:00 fix was trimmed away, so only four survive the split.
    final first = await repo.getTrack(firstId);
    final second = await repo.getTrack(secondId);
    expect(first!.points.length + second!.points.length, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gps_log/gps_track_split_test.dart`
Expected: FAIL — `splitTrack` isn't defined.

- [ ] **Step 3: Add the write observer seam**

The ordering test needs to observe write order. Add to `GpsTrackRepository`:

```dart
  /// Test-only hook recording write operations in order.
  ///
  /// Exists so the split-ordering guarantee can be asserted directly rather
  /// than inferred from final state - final state looks identical whichever
  /// order the writes happened in.
  @visibleForTesting
  void Function(String)? debugOnWrite;
```

- [ ] **Step 4: Implement the split**

```dart
  /// Splits [id] into two tracks at [atWallClockMs].
  ///
  /// The fix at the split point goes to the first child. Returns the two new
  /// ids.
  ///
  /// ORDERING IS THE SAFETY PROPERTY: both children are written BEFORE the
  /// parent is tombstoned. A crash between those steps leaves two children
  /// and the parent - duplicates the user can delete. The reverse order
  /// would leave nothing.
  Future<(String, String)> splitTrack(String id, int atWallClockMs) async {
    final track = await getTrack(id, includePoints: true);
    if (track == null) {
      throw ArgumentError.value(id, 'id', 'No such track');
    }

    final atSeconds = atWallClockMs ~/ 1000;
    final points = track.effectivePoints;
    final first = [
      for (final p in points)
        if (p.timestamp <= atSeconds) p,
    ];
    final second = [
      for (final p in points)
        if (p.timestamp > atSeconds) p,
    ];

    if (first.isEmpty || second.isEmpty) {
      throw ArgumentError.value(
        atWallClockMs,
        'atWallClockMs',
        'Split point must leave fixes on both sides',
      );
    }

    final baseName = track.name;
    final firstId = await insertImportedTrack(
      points: first,
      startTimeMs: first.first.timestamp * 1000,
      endTimeMs: first.last.timestamp * 1000,
      tzOffsetMinutes: track.tzOffsetMinutes,
      source: track.source,
      sourceRef: track.sourceRef,
      name: baseName == null ? null : '$baseName (1)',
    );
    debugOnWrite?.call('insert:$firstId');

    final secondId = await insertImportedTrack(
      points: second,
      startTimeMs: second.first.timestamp * 1000,
      endTimeMs: second.last.timestamp * 1000,
      tzOffsetMinutes: track.tzOffsetMinutes,
      source: track.source,
      sourceRef: track.sourceRef,
      name: baseName == null ? null : '$baseName (2)',
    );
    debugOnWrite?.call('insert:$secondId');

    // Only now that both children are durable.
    await deleteTrack(id);
    debugOnWrite?.call('delete:$id');

    return (firstId, secondId);
  }
```

- [ ] **Step 5: Add the provider wrapper**

```dart
/// Splits a track and drops the parent's cached geometry.
final splitTrackProvider = Provider(
  (ref) => (String id, int atWallClockMs) async {
    final result =
        await ref.read(gpsTrackRepositoryProvider).splitTrack(id, atWallClockMs);
    await ref.read(trackGeometryCacheRepositoryProvider).invalidate(id);
    ref.invalidate(gpsTracksProvider);
    return result;
  },
);
```

- [ ] **Step 6: Run tests, format, analyze, commit**

```bash
flutter test test/features/gps_log/
dart format .
flutter analyze
git add lib/features/gps_log/ test/features/gps_log/gps_track_split_test.dart
git commit -m "Add ordered GPS track split with write-before-tombstone safety"
```

---

### Task 35: Trim and split UI

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/track_timeline_scrubber.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_track_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus all locale ARBs
- Test: `test/features/gps_log/track_timeline_scrubber_test.dart`
- Test: `test/features/gps_log/gps_track_edit_mode_test.dart`

**Interfaces:**
- Consumes: `trimTrackProvider` (Task 33), `splitTrackProvider` (Task 34)
- Produces:
  - `class TrackTimelineScrubber extends StatelessWidget`
  - `trackEditModeProvider` → `StateProvider<TrackEditMode>` where `enum TrackEditMode { none, trim, split }`

- [ ] **Step 1: Add l10n strings**

```json
  "gpsTrack_action_trim": "Trim...",
  "@gpsTrack_action_trim": {"description": "Menu entry that enters trim mode"},
  "gpsTrack_action_split": "Split...",
  "@gpsTrack_action_split": {"description": "Menu entry that enters split mode"},
  "gpsTrack_action_resetTrim": "Reset trim",
  "@gpsTrack_action_resetTrim": {"description": "Removes existing trim bounds"},
  "gpsTrack_action_rename": "Rename...",
  "@gpsTrack_action_rename": {"description": "Menu entry that renames the track"},
  "gpsTrack_edit_applyTrim": "Apply trim",
  "@gpsTrack_edit_applyTrim": {"description": "Commits the dragged trim bounds"},
  "gpsTrack_edit_confirmSplit": "Split here",
  "@gpsTrack_edit_confirmSplit": {"description": "Commits the split at the handle position"},
  "gpsTrack_edit_splitWarning": "Splitting creates two tracks and removes the original. This cannot be undone.",
  "@gpsTrack_edit_splitWarning": {"description": "Warns that split is destructive, unlike trim"},
  "gpsTrack_edit_cancel": "Cancel",
  "@gpsTrack_edit_cancel": {"description": "Leaves edit mode without changes"}
```

Translate into all locales, then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing scrubber test**

Create `test/features/gps_log/track_timeline_scrubber_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_timeline_scrubber.dart';

void main() {
  const startMs = 1700000000000;
  const endMs = 1700003600000;

  testWidgets('renders two handles in trim mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: endMs,
            mode: TrackScrubberMode.range,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('renders one handle in split mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: endMs,
            mode: TrackScrubberMode.single,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(RangeSlider), findsNothing);
  });

  testWidgets('reports millisecond values, not slider fractions',
      (tester) async {
    int? reportedStart;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: endMs,
            mode: TrackScrubberMode.range,
            onChanged: (s, e) => reportedStart = s,
          ),
        ),
      ),
    );
    await tester.drag(find.byType(RangeSlider), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(reportedStart, isNotNull);
    expect(reportedStart, greaterThanOrEqualTo(startMs));
    expect(reportedStart, lessThanOrEqualTo(endMs));
  });

  testWidgets('labels the ends with wall-clock times, not device-local',
      (tester) async {
    // The times shown must be the recording device's wall clock. Formatting
    // via toLocal() would shift them for anyone viewing from another zone.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
            endMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
            mode: TrackScrubberMode.range,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('8:00'), findsWidgets);
  });

  testWidgets('handles a zero-length span without dividing by zero',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: startMs,
            mode: TrackScrubberMode.range,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gps_log/track_timeline_scrubber_test.dart`
Expected: FAIL — `TrackTimelineScrubber` isn't defined.

- [ ] **Step 4: Build the scrubber**

Create `track_timeline_scrubber.dart` with `enum TrackScrubberMode { range, single }`, wrapping a `RangeSlider` or `Slider` over the track's millisecond span. Label both ends with `DateFormat.jm()` applied to `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)` — UTC components directly, never `toLocal()`.

Guard `endMs == startMs` by rendering a disabled slider rather than dividing by a zero span.

- [ ] **Step 5: Wire edit mode into the detail page**

Add `trackEditModeProvider`, and to the overflow menu: Rename, Trim, Split, Reset trim (only when bounds exist), Delete.

In trim mode, show the scrubber over the map with the excluded portions of the polyline dimmed live as handles move, plus Apply and Cancel. Apply calls `trimTrackProvider`.

In split mode, show a single handle, a marker on the map at that position, and the `gpsTrack_edit_splitWarning` text. Split is the one destructive operation here — trim is reversible and split is not, so it gets an explicit confirmation while trim does not.

- [ ] **Step 6: Write the edit mode test**

Create `test/features/gps_log/gps_track_edit_mode_test.dart` asserting:

```dart
  testWidgets('Trim shows a range scrubber and an Apply action',
      (tester) async {
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Apply trim'), findsOneWidget);
  });

  testWidgets('Split warns that the operation is destructive',
      (tester) async {
    expect(
      find.text(
        'Splitting creates two tracks and removes the original. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Reset trim appears only when the track has bounds',
      (tester) async {
    // With trimStartTime null, the entry is absent; with it set, present.
  });

  testWidgets('Cancel leaves edit mode without writing', (tester) async {
    // Assert the repository received no setTrimBounds call.
  });
```

Fill the harness bodies from the existing detail page test.

- [ ] **Step 7: Run the full suite, format, analyze, commit**

```bash
flutter test
dart format .
flutter analyze
git add lib/features/gps_log/ lib/l10n/ test/features/gps_log/
git commit -m "Add trim and split editing UI for GPS tracks"
```

---

**Phase 7 complete.** All seven phases done.

---

## Final Verification

Before opening the pull request:

```bash
# Whole suite, not just the touched features
flutter test

# Whole project. Never pipe to tail - it masks the exit code, and infos
# are fatal in CI.
flutter analyze

# Formatting across the project, not just changed files
dart format .
git diff --exit-code

# Confirm the schema version claim still holds against the remote
git fetch origin
git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="
```

Manual passes that automated tests cannot cover:

1. **Thumbnail scroll performance** on a physical device with 50+ tracks (Task 17 Step 6).
2. **A real GPX round trip**: export a recorded track, re-import the file, confirm the fix count, timestamps, and dive matching all survive.
3. **Offline behaviour**: enable airplane mode, open the GPS Log, confirm thumbnails fall back to shapes rather than showing broken tiles.
4. **Cross-device sync**: trim a track on one device, confirm the bounds appear on a second; split on one, confirm two children and no parent on the other.

## Spec Coverage

| Spec section | Tasks |
|---|---|
| Domain core (geometry, colorization) | 1, 2, 3 |
| Bucketed runs rather than gradient | 9 |
| Level-of-detail cache | 7, 8 |
| Providers | 8, 12 |
| Surface 1: row thumbnail | 15, 16, 17 |
| Surface 2: track detail | 10, 11, 12, 13, 14 |
| Surface 3: overview map | 18, 19 |
| Surface 4: dive detail | 20, 21 |
| Schema v144 | 5 |
| Local cache schema v10 | 7 |
| Import (GPX, KML, CSV, FIT) | 26, 27, 28, 29, 30, 31, 32 |
| Export (GPX, KML) | 22, 23, 24, 25 |
| Trim and split | 33, 34, 35 |
| Speed units | 4 |
| effectivePoints accessor | 6 |
| Error handling | 10 (unreadable/empty), 16 (offline), 32 (parse failure), 25 (cancel vs failure) |
| Antimeridian | 2 |
| Testing strategy | every task |
