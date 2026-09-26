# Media Map Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth media library view mode, `map`, that places photo and video thumbnails on a clustered map and lets the diver open them from there.

**Architecture:** A new unpaged repository query resolves each library row to one map point (own GPS, then the dive's entry fix, then the dive's site, then the attached site) and a small auto-dispose notifier holds those points. A new `MediaMapContent` widget draws them with the same flutter_map and marker-cluster stack the dive map uses, with thumbnails as markers and an in-map place strip for co-located stacks. Only the stateless camera helpers are extracted into the maps feature; the existing dive, site and dive-center maps are untouched (follow-up issue #2330).

**Tech Stack:** Flutter 3.47, Riverpod 3 with the legacy `StateNotifierProvider` API (the media feature's convention), Drift, flutter_map 8.2, flutter_map_marker_cluster 8.2, latlong2, `flutter gen-l10n` for the eleven ARB files.

**Spec:** `docs/superpowers/specs/2026-09-25-media-map-mode-design.md` (issue #2329; the PR body must say `Closes #2329`).

## Global Constraints

- No schema change. The query reads `media.latitude/longitude`, `dives.entry_latitude/entry_longitude`, and `dive_sites.latitude/longitude` through both `dives.site_id` and `media.site_id`.
- Placement order is fixed: own GPS, dive entry fix, dive's site, attached site. Both GPS sources pass `isPlausibleFix` (`lib/features/media/data/services/gps_fix.dart`); site coordinates are trusted as stored, subject only to the valid range.
- Camera defaults are the dive map's, verbatim: animate-to 500ms and zoom 12 when below 10; animate-to-bounds 800ms, 120dp padding, max zoom 14; fit-all single point zoom 12, otherwise 50dp padding.
- Marker and cluster tiles are 56dp; thumbnail decode target is 112x112; cluster radius is 80; map zoom range is 2 to 18.
- No em-dashes anywhere (code, comments, commits, docs). No emojis. No mention of the AI tool in any commit, PR or comment.
- New l10n keys go in all eleven ARB files under `lib/l10n/arb/`. `app_en.arb` is alphabetical and carries `@key` metadata; the other ten are feature-grouped, carry no metadata, and take the new keys directly after `media_library_viewMode_timeline`. Plurals use CLDR categories with `{count}` in every branch (never a literal digit in the `one` branch); Arabic and Hebrew use the `=1`/`=2` exact forms the existing keys in those files use.
- Run `flutter gen-l10n` after any ARB edit and commit the generated `lib/l10n/arb/app_localizations*.dart` with the ARBs; the pre-push hook rejects stale generated files.
- Run `dart format .` (whole project) before every commit. Run `flutter analyze` on the whole project before the PR; infos are fatal in CI.
- Never run two `flutter test` invocations at once (local runs are I/O bound). Never pipe `flutter test` through `grep`; the pipe hides the exit status.
- Imports grouped dart, flutter, packages, local. Files snake_case, classes PascalCase. Immutable state objects with `copyWith`.
- `test/architecture/` scans all of `lib/`; run it after every task that adds a `lib/` file.

## Review Focus

Inputs the spec implies but no task would otherwise exercise, most likely to bite first. Each has a test pinned to the owning task.

1. A site stored with only one of latitude/longitude, or a value outside the valid range (a hand-typed 190 longitude). Expected: the row falls through to the next placement or is dropped, never a `LatLng` assertion crash on the map. Pinned in Task 3 (resolver rejects half pairs and out-of-range site coordinates).
2. A cluster tap when every member shares one point but the camera is far zoomed out (the first tap on a site's stack at world zoom). Expected: the strip opens immediately rather than a pointless zoom that lands on the same stack. Pinned in Task 10 (co-located cluster opens the strip at zoom 2).
3. A media table write while the diver is browsing the map (a store upload stamping rows). Expected: the points reload but the camera stays where the diver left it. Pinned in Task 10 (a state reload without a filter change does not move the camera).
4. A library whose in-scope rows are all unlocated. Expected: the empty card and the unlocated count both show; no crash from fitting zero points. Pinned in Task 10 (zero points, non-zero unlocated count) and Task 2 (`fitAll` with an empty list is a no-op).
5. Switching to map mode while the toolbar is at 320dp with a selection active. Expected: no layout overflow, selection exits, the select control disappears. Pinned in Task 12.

---

### Task 1: `boundsForPoints` in the maps domain utilities

**Files:**
- Modify: `lib/features/maps/domain/map_utils.dart`
- Test: `test/features/maps/domain/map_utils_bounds_test.dart`

**Interfaces:**
- Consumes: `LatLng`, `LatLngBounds` from `latlong2` / `flutter_map`.
- Produces: `LatLngBounds? boundsForPoints(List<LatLng> points)`. Returns null when no point is in range. Used by Task 2.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/maps/domain/map_utils_bounds_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

void main() {
  test('one point yields a zero-span box at that point', () {
    final bounds = boundsForPoints([const LatLng(10, 20)])!;
    expect(bounds.south, 10);
    expect(bounds.north, 10);
    expect(bounds.west, 20);
    expect(bounds.east, 20);
  });

  test('many points are padded by ten percent of each span', () {
    final bounds = boundsForPoints([
      const LatLng(0, 0),
      const LatLng(10, 20),
    ])!;
    expect(bounds.south, closeTo(-1, 1e-9));
    expect(bounds.north, closeTo(11, 1e-9));
    expect(bounds.west, closeTo(-2, 1e-9));
    expect(bounds.east, closeTo(22, 1e-9));
  });

  test('an out-of-range point is skipped', () {
    final bounds = boundsForPoints([
      const LatLng(5, 5),
      const LatLng(6, 6),
      // latlong2 0.9 does not assert its ranges, so a bad point is easy to
      // build; flutter_map is what chokes on one, which is why we skip it.
      const LatLng(95, 200),
    ])!;
    expect(bounds.north, lessThan(90));
    expect(bounds.east, lessThan(180));
  });

  test('padding is clamped at the poles and the antimeridian', () {
    final bounds = boundsForPoints([
      const LatLng(-89, -179),
      const LatLng(89, 179),
    ])!;
    expect(bounds.south, -90);
    expect(bounds.north, 90);
    expect(bounds.west, -180);
    expect(bounds.east, 180);
  });

  test('no usable point yields null', () {
    expect(boundsForPoints(const []), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/domain/map_utils_bounds_test.dart`
Expected: FAIL, `boundsForPoints` is not defined.

- [ ] **Step 3: Add the function**

Append to `lib/features/maps/domain/map_utils.dart`:

```dart
/// Bounding box for [points], padded by ten percent of each span and
/// clamped to the valid ranges. Points outside the valid ranges are
/// skipped. Returns null when no point is usable.
///
/// This is the `_calculateBounds` the dive, site and dive-center maps each
/// carry privately (issue #2330 migrates them onto this one).
LatLngBounds? boundsForPoints(List<LatLng> points) {
  double minLat = 90, maxLat = -90;
  double minLng = 180, maxLng = -180;
  var any = false;

  for (final p in points) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    any = true;
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  }
  if (!any) return null;

  final latPadding = (maxLat - minLat) * 0.1;
  final lngPadding = (maxLng - minLng) * 0.1;
  final south = (minLat - latPadding).clamp(-90.0, 90.0);
  final north = (maxLat + latPadding).clamp(-90.0, 90.0);
  final west = (minLng - lngPadding).clamp(-180.0, 180.0);
  final east = (maxLng + lngPadding).clamp(-180.0, 180.0);
  return LatLngBounds(LatLng(south, west), LatLng(north, east));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/domain/map_utils_bounds_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/maps/domain/map_utils.dart test/features/maps/domain/map_utils_bounds_test.dart
git commit -m "feat(maps): add boundsForPoints to the shared map utilities"
```

---

### Task 2: `MapCameraAnimator`

**Files:**
- Create: `lib/features/maps/presentation/widgets/map_camera_animator.dart`
- Test: `test/features/maps/presentation/widgets/map_camera_animator_test.dart`

**Interfaces:**
- Consumes: `boundsForPoints` (Task 1), `MapController`, `CameraFit`, `MapCamera` from flutter_map.
- Produces:
  - `MapCameraAnimator({required MapController controller, required TickerProvider vsync})`
  - `Future<void> animateTo(LatLng target, {Duration duration})`
  - `Future<void> animateToBounds(LatLngBounds bounds, {EdgeInsets padding, double maxZoom, Duration duration})`
  - `void fitAll(List<LatLng> points, {double singlePointZoom, EdgeInsets padding})`
  - `void dispose()`
  Used by Task 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/maps/presentation/widgets/map_camera_animator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';

Future<MapController> _pumpMap(WidgetTester tester) async {
  final controller = MapController();
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: FlutterMap(
          mapController: controller,
          options: const MapOptions(
            initialCenter: LatLng(0, 0),
            initialZoom: 2,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('animateTo lands on the target at zoom 12 from a wide view', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateTo(const LatLng(10, 20));
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.center.latitude, closeTo(10, 1e-6));
    expect(controller.camera.center.longitude, closeTo(20, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
  });

  testWidgets('animateTo keeps the zoom when already at 10 or closer', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    controller.move(const LatLng(0, 0), 14);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateTo(const LatLng(1, 1));
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.zoom, closeTo(14, 1e-6));
  });

  testWidgets('animateToBounds ends inside the bounds and at most zoom 14', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateToBounds(
      LatLngBounds(const LatLng(10, 10), const LatLng(10.01, 10.01)),
    );
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.center.latitude, closeTo(10.005, 1e-3));
    expect(controller.camera.zoom, lessThanOrEqualTo(14));
  });

  testWidgets('fitAll with one point moves to zoom 12', (tester) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    animator.fitAll([const LatLng(-8, 115)]);
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
  });

  testWidgets('fitAll with an empty list leaves the camera alone', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    animator.fitAll(const []);
    await tester.pump();

    expect(controller.camera.zoom, closeTo(2, 1e-6));
  });

  testWidgets('dispose mid-flight completes the pending future without '
      'throwing', (tester) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );

    final done = animator.animateTo(const LatLng(10, 20));
    await tester.pump(const Duration(milliseconds: 100));
    animator.dispose();
    await tester.pumpAndSettle();

    await done.timeout(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // The camera stopped short of the target: the flight was cancelled.
    expect(controller.camera.center.latitude, lessThan(10));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/presentation/widgets/map_camera_animator_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the animator**

```dart
// lib/features/maps/presentation/widgets/map_camera_animator.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/map_utils.dart';

/// Animated camera moves shared by the app's maps.
///
/// The dive, site and dive-center maps each carry private copies of these
/// three moves with identical durations and paddings; the defaults here are
/// those values verbatim so migrating them (issue #2330) is
/// behaviour-preserving. One improvement over the copies: [dispose] cancels
/// an in-flight animation, which a per-call `AnimationController` that is
/// only disposed after `forward()` completes cannot do.
///
/// Every method needs [controller] attached to a mounted `FlutterMap`;
/// call them from `onMapReady` or later.
class MapCameraAnimator {
  MapCameraAnimator({required this.controller, required this.vsync});

  final MapController controller;
  final TickerProvider vsync;

  AnimationController? _inFlight;
  CurvedAnimation? _inFlightCurve;

  /// Eases to [target] over [duration]. Zooms in to 12 when the camera is
  /// wider than zoom 10; otherwise keeps the current zoom.
  Future<void> animateTo(
    LatLng target, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final start = controller.camera;
    final targetZoom = start.zoom < 10 ? 12.0 : start.zoom;
    return _run(start, target, targetZoom, duration);
  }

  /// Eases to a camera that shows [bounds] with [padding], never closer
  /// than [maxZoom].
  Future<void> animateToBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(120),
    double maxZoom = 14.0,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    final start = controller.camera;
    final target = CameraFit.bounds(
      bounds: bounds,
      padding: padding,
      maxZoom: maxZoom,
    ).fit(start);
    return _run(start, target.center, target.zoom, duration);
  }

  /// Jumps (no animation) to show every point: a single point at
  /// [singlePointZoom], otherwise the padded bounds. Empty input and input
  /// with no in-range point are no-ops.
  void fitAll(
    List<LatLng> points, {
    double singlePointZoom = 12.0,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.move(points.first, singlePointZoom);
      return;
    }
    final bounds = boundsForPoints(points);
    if (bounds == null) return;
    controller.fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
  }

  /// Cancels any in-flight animation. Safe to call twice.
  void dispose() {
    final current = _inFlight;
    final curve = _inFlightCurve;
    _inFlight = null;
    _inFlightCurve = null;
    curve?.dispose();
    current?.stop();
    current?.dispose();
  }

  Future<void> _run(
    MapCamera start,
    LatLng targetCenter,
    double targetZoom,
    Duration duration,
  ) {
    // A new move supersedes the previous one.
    dispose();

    final animation = AnimationController(duration: duration, vsync: vsync);
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    _inFlight = animation;
    _inFlightCurve = curve;

    curve.addListener(() {
      final t = curve.value;
      final lat =
          start.center.latitude +
          (targetCenter.latitude - start.center.latitude) * t;
      final lng =
          start.center.longitude +
          (targetCenter.longitude - start.center.longitude) * t;
      final zoom = start.zoom + (targetZoom - start.zoom) * t;
      controller.move(LatLng(lat, lng), zoom);
    });

    final done = Completer<void>();
    // whenCompleteOrCancel fires on natural completion and on cancellation
    // (dispose stops the ticker). It runs on a later microtask, so a
    // cancelled controller has already been disposed by then and must not
    // be disposed again: only tear down a controller that is still ours.
    animation.forward().whenCompleteOrCancel(() {
      if (identical(_inFlight, animation)) {
        _inFlight = null;
        _inFlightCurve = null;
        curve.dispose();
        animation.dispose();
      }
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/presentation/widgets/map_camera_animator_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS.

```bash
dart format .
git add lib/features/maps/presentation/widgets/map_camera_animator.dart test/features/maps/presentation/widgets/map_camera_animator_test.dart
git commit -m "feat(maps): add MapCameraAnimator with cancellable camera moves"
```

---

### Task 3: `MediaPlacement`, `MediaMapPoint` and `resolveMediaPlacement`

**Files:**
- Create: `lib/features/media/domain/entities/media_map_point.dart`
- Create: `lib/features/media/domain/services/media_placement_resolver.dart`
- Test: `test/features/media/domain/services/media_placement_resolver_test.dart`

**Interfaces:**
- Consumes: `isPlausibleFix(double, double)` from `lib/features/media/data/services/gps_fix.dart`; `MediaLibraryEntry` from `lib/features/media/domain/entities/media_library_filter.dart`.
- Produces:
  - `enum MediaPlacement { ownGps, diveEntry, diveSite, attachedSite }`
  - `class MediaMapPoint { MediaLibraryEntry entry; LatLng point; MediaPlacement placement; String? placeLabel; MediaItem get item; }`
  - `typedef ResolvedPlacement = ({LatLng point, MediaPlacement placement});`
  - `ResolvedPlacement? resolveMediaPlacement({double? ownLatitude, double? ownLongitude, double? diveEntryLatitude, double? diveEntryLongitude, double? diveSiteLatitude, double? diveSiteLongitude, double? attachedSiteLatitude, double? attachedSiteLongitude})`
  Used by Tasks 4, 5, 7, 8, 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/domain/services/media_placement_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/services/media_placement_resolver.dart';

void main() {
  test('the own fix wins over every other source', () {
    final r = resolveMediaPlacement(
      ownLatitude: 1,
      ownLongitude: 2,
      diveEntryLatitude: 3,
      diveEntryLongitude: 4,
      diveSiteLatitude: 5,
      diveSiteLongitude: 6,
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.point, const LatLng(1, 2));
    expect(r.placement, MediaPlacement.ownGps);
  });

  test('a (0,0) own fix falls through to the dive entry fix', () {
    final r = resolveMediaPlacement(
      ownLatitude: 0,
      ownLongitude: 0,
      diveEntryLatitude: 3,
      diveEntryLongitude: 4,
    )!;
    expect(r.point, const LatLng(3, 4));
    expect(r.placement, MediaPlacement.diveEntry);
  });

  test('an implausible dive entry fix falls through to the dive site', () {
    final r = resolveMediaPlacement(
      diveEntryLatitude: 0,
      diveEntryLongitude: 0,
      diveSiteLatitude: 5,
      diveSiteLongitude: 6,
    )!;
    expect(r.point, const LatLng(5, 6));
    expect(r.placement, MediaPlacement.diveSite);
  });

  test('with no dive context the attached site places the item', () {
    final r = resolveMediaPlacement(
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.point, const LatLng(7, 8));
    expect(r.placement, MediaPlacement.attachedSite);
  });

  test('nothing usable resolves to null', () {
    expect(resolveMediaPlacement(), isNull);
  });

  test('half a coordinate pair is not a position', () {
    expect(resolveMediaPlacement(ownLatitude: 1), isNull);
    expect(resolveMediaPlacement(diveSiteLongitude: 6), isNull);
  });

  test('an out-of-range site coordinate is skipped, not asserted on', () {
    final r = resolveMediaPlacement(
      diveSiteLatitude: 5,
      diveSiteLongitude: 190,
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.placement, MediaPlacement.attachedSite);
  });

  test('a site at exactly (0,0) is trusted as stored', () {
    // Sites are typed by hand, so (0,0) is a real (if unlikely) position,
    // unlike a camera that wrote (0,0) for "no fix".
    final r = resolveMediaPlacement(diveSiteLatitude: 0, diveSiteLongitude: 0)!;
    expect(r.placement, MediaPlacement.diveSite);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/services/media_placement_resolver_test.dart`
Expected: FAIL, imports do not resolve.

- [ ] **Step 3: Create the entity file**

```dart
// lib/features/media/domain/entities/media_map_point.dart
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// Which source placed a media item on the map. The order of the values is
/// the fallback order.
enum MediaPlacement { ownGps, diveEntry, diveSite, attachedSite }

/// One located library item: where it sits on the map and why.
class MediaMapPoint extends Equatable {
  const MediaMapPoint({
    required this.entry,
    required this.point,
    required this.placement,
    this.placeLabel,
  });

  /// The item plus the dive header fields the grid already carries.
  final MediaLibraryEntry entry;

  final LatLng point;
  final MediaPlacement placement;

  /// The dive's site name, else the attached site's name, else null. For a
  /// site placement this is the site the item sits at; for a GPS placement
  /// it is the nearest known context.
  final String? placeLabel;

  MediaItem get item => entry.item;

  @override
  List<Object?> get props => [entry.item.id, point, placement, placeLabel];
}
```

- [ ] **Step 4: Create the resolver**

```dart
// lib/features/media/domain/services/media_placement_resolver.dart
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';

/// A resolved map position and the source it came from.
typedef ResolvedPlacement = ({LatLng point, MediaPlacement placement});

/// Picks where a media item sits on the map.
///
/// Own GPS wins, then the dive's entry fix, then the dive's site, then the
/// attached site. The two GPS sources must pass [isPlausibleFix], which
/// rejects the `(0, 0)` cameras and phones write when the receiver had no
/// fix. Site coordinates are typed by hand and trusted as stored, subject
/// only to the valid range (a `LatLng` outside it asserts). Returns null
/// when nothing usable is present.
ResolvedPlacement? resolveMediaPlacement({
  double? ownLatitude,
  double? ownLongitude,
  double? diveEntryLatitude,
  double? diveEntryLongitude,
  double? diveSiteLatitude,
  double? diveSiteLongitude,
  double? attachedSiteLatitude,
  double? attachedSiteLongitude,
}) {
  final own = _fix(ownLatitude, ownLongitude);
  if (own != null) return (point: own, placement: MediaPlacement.ownGps);

  final entry = _fix(diveEntryLatitude, diveEntryLongitude);
  if (entry != null) {
    return (point: entry, placement: MediaPlacement.diveEntry);
  }

  final site = _stored(diveSiteLatitude, diveSiteLongitude);
  if (site != null) return (point: site, placement: MediaPlacement.diveSite);

  final attached = _stored(attachedSiteLatitude, attachedSiteLongitude);
  if (attached != null) {
    return (point: attached, placement: MediaPlacement.attachedSite);
  }
  return null;
}

/// A GPS fix: both axes present and plausible.
LatLng? _fix(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!isPlausibleFix(lat, lng)) return null;
  return LatLng(lat, lng);
}

/// A stored site position: both axes present and inside the valid ranges.
LatLng? _stored(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/media/domain/services/media_placement_resolver_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 6: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS.

```bash
dart format .
git add lib/features/media/domain/entities/media_map_point.dart lib/features/media/domain/services/media_placement_resolver.dart test/features/media/domain/services/media_placement_resolver_test.dart
git commit -m "feat(media): add MediaMapPoint and the media placement resolver"
```

---

### Task 4: Repository query, count and change tick

**Files:**
- Modify: `lib/features/media/data/repositories/media_library_repository.dart` (add three members after `countMissing`, around line 302, and one import)
- Test: `test/features/media/data/media_library_repository_map_test.dart`
- Modify: `test/architecture/repository_tick_stream_test.dart` (two firing cases plus one entry in the silence map at line 171)

**Interfaces:**
- Consumes: `resolveMediaPlacement`, `MediaMapPoint`, `MediaPlacement` (Task 3); existing `_baseWhere`, `_dateKey`, `mediaItemFromRow`, `MediaRepository.changeTickDebounce`, `debounce` from `core/utils/stream_debounce.dart`.
- Produces on `MediaLibraryRepository`:
  - `Future<List<MediaMapPoint>> getMapPoints({required String? diverId, MediaLibraryFilter filter = MediaLibraryFilter.none})`
  - `Future<int> countInScope({required String? diverId, MediaLibraryFilter filter = MediaLibraryFilter.none})`
  - `Stream<void> watchMapChanges()`
  Used by Task 5.

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/media/data/media_library_repository_map_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late MediaLibraryRepository repo;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(
    String id,
    String name, {
    double? lat,
    double? lng,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          latitude: Value(lat),
          longitude: Value(lng),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertDive(
    String id, {
    required String diverId,
    int? number,
    String? siteId,
    double? entryLat,
    double? entryLng,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveNumber: Value(number),
          siteId: Value(siteId),
          entryLatitude: Value(entryLat),
          entryLongitude: Value(entryLng),
          diveDateTime: Value(
            TripMediaScanner.toWallClockUtc(
              DateTime(2026, 6, 12),
            ).millisecondsSinceEpoch,
          ),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertMedia(
    String id,
    DateTime takenAt, {
    String? diveId,
    String? siteId,
    double? lat,
    double? lng,
    MediaType mediaType = MediaType.photo,
  }) => mediaRepo.createMedia(
    MediaItem(
      id: id,
      mediaType: mediaType,
      sourceType: MediaSourceType.localFile,
      filePath: '/tmp/$id',
      localPath: '/tmp/$id',
      originalFilename: '$id.jpg',
      diveId: diveId,
      siteId: siteId,
      latitude: lat,
      longitude: lng,
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRepo = MediaRepository();
    repo = MediaLibraryRepository();

    await insertDiver('d1');
    await insertDiver('d2');
    await insertSite('site-1', 'Blue Hole', lat: 12.5, lng: 43.2);
    await insertSite('site-att', 'Reef', lat: -8.0, lng: 115.0);
    await insertSite('site-nocoord', 'Nowhere');

    await insertDive('dive-1', diverId: 'd1', number: 1, siteId: 'site-1');
    await insertDive(
      'dive-entry',
      diverId: 'd1',
      number: 2,
      entryLat: 10.0,
      entryLng: 20.0,
    );
    await insertDive(
      'dive-entry-site',
      diverId: 'd1',
      number: 3,
      siteId: 'site-1',
      entryLat: 12.6,
      entryLng: 43.3,
    );
    await insertDive('dive-nocoord', diverId: 'd1', siteId: 'site-nocoord');
    await insertDive('dive-other', diverId: 'd2', siteId: 'site-1');

    final t = DateTime(2026, 6, 12, 10);
    await insertMedia('own', t, diveId: 'dive-1', lat: 1.0, lng: 2.0);
    await insertMedia(
      'zero',
      t.add(const Duration(minutes: 1)),
      diveId: 'dive-1',
      lat: 0,
      lng: 0,
    );
    await insertMedia(
      'entry',
      t.add(const Duration(minutes: 2)),
      diveId: 'dive-entry',
    );
    await insertMedia(
      'entry-over-site',
      t.add(const Duration(minutes: 3)),
      diveId: 'dive-entry-site',
    );
    await insertMedia(
      'site',
      t.add(const Duration(minutes: 4)),
      diveId: 'dive-1',
    );
    await insertMedia(
      'attached',
      t.add(const Duration(minutes: 5)),
      siteId: 'site-att',
    );
    await insertMedia(
      'unlinked',
      t.add(const Duration(minutes: 6)),
      lat: 5.0,
      lng: 6.0,
    );
    await insertMedia(
      'unlocated',
      t.add(const Duration(minutes: 7)),
      diveId: 'dive-nocoord',
    );
    await insertMedia(
      'doc',
      t.add(const Duration(minutes: 8)),
      diveId: 'dive-1',
      mediaType: MediaType.document,
    );
    await insertMedia(
      'sig',
      t.add(const Duration(minutes: 9)),
      diveId: 'dive-1',
      mediaType: MediaType.instructorSignature,
    );
    await insertMedia(
      'other',
      t.add(const Duration(minutes: 10)),
      diveId: 'dive-other',
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Map<String, MediaMapPoint> byId(List<MediaMapPoint> points) => {
    for (final p in points) p.item.id: p,
  };

  test('resolves every placement kind with its label', () async {
    final points = byId(await repo.getMapPoints(diverId: 'd1'));

    expect(points['own']!.point, const LatLng(1, 2));
    expect(points['own']!.placement, MediaPlacement.ownGps);
    expect(points['own']!.placeLabel, 'Blue Hole');

    expect(points['zero']!.point, const LatLng(12.5, 43.2));
    expect(points['zero']!.placement, MediaPlacement.diveSite);

    expect(points['entry']!.point, const LatLng(10, 20));
    expect(points['entry']!.placement, MediaPlacement.diveEntry);
    expect(points['entry']!.placeLabel, isNull);

    expect(points['entry-over-site']!.point, const LatLng(12.6, 43.3));
    expect(points['entry-over-site']!.placement, MediaPlacement.diveEntry);
    expect(points['entry-over-site']!.placeLabel, 'Blue Hole');

    expect(points['site']!.placement, MediaPlacement.diveSite);
    expect(points['site']!.entry.diveNumber, 1);

    expect(points['attached']!.point, const LatLng(-8, 115));
    expect(points['attached']!.placement, MediaPlacement.attachedSite);
    expect(points['attached']!.placeLabel, 'Reef');
    expect(points['attached']!.entry.siteName, 'Reef');

    expect(points['unlinked']!.placement, MediaPlacement.ownGps);
    expect(points['unlinked']!.placeLabel, isNull);
  });

  test('drops unlocated rows, documents and signatures', () async {
    final ids = (await repo.getMapPoints(diverId: 'd1')).map((p) => p.item.id);
    expect(ids, isNot(contains('unlocated')));
    expect(ids, isNot(contains('doc')));
    expect(ids, isNot(contains('sig')));
  });

  test('dive-linked rows are scoped to the diver; unlinked and site-only '
      'rows are global', () async {
    final d1 = (await repo.getMapPoints(diverId: 'd1')).map((p) => p.item.id);
    expect(d1, isNot(contains('other')));
    expect(d1, containsAll(['attached', 'unlinked']));

    final all = (await repo.getMapPoints(diverId: null)).map((p) => p.item.id);
    expect(all, contains('other'));
  });

  test('orders by date taken ascending', () async {
    final ids = (await repo.getMapPoints(diverId: 'd1'))
        .map((p) => p.item.id)
        .toList();
    expect(ids, [
      'own',
      'zero',
      'entry',
      'entry-over-site',
      'site',
      'attached',
      'unlinked',
    ]);
  });

  test('honours the library filter', () async {
    final videos = await repo.getMapPoints(
      diverId: 'd1',
      filter: const MediaLibraryFilter(mediaType: MediaType.video),
    );
    expect(videos, isEmpty);

    final atSite = await repo.getMapPoints(
      diverId: 'd1',
      filter: const MediaLibraryFilter(siteId: 'site-att'),
    );
    expect(atSite.map((p) => p.item.id), ['attached']);
  });

  test('countInScope counts photo and video rows the grid would show', () async {
    // d1: own, zero, entry, entry-over-site, site, attached, unlinked,
    // unlocated = 8 (doc, sig and the other diver's row excluded).
    expect(await repo.countInScope(diverId: 'd1'), 8);
    // So the map's unlocated count for d1 is 8 - 7 = 1.
    final located = await repo.getMapPoints(diverId: 'd1');
    expect(await repo.countInScope(diverId: 'd1') - located.length, 1);
  });

  test('watchMapChanges emits on a site coordinate edit', () async {
    var fired = false;
    final sub = repo.watchMapChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);

    await (db.update(db.diveSites)..where((s) => s.id.equals('site-1'))).write(
      const DiveSitesCompanion(latitude: Value(13.0)),
    );
    for (var i = 0; i < 150 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(fired, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/media_library_repository_map_test.dart`
Expected: FAIL, `getMapPoints` is not defined.

- [ ] **Step 3: Add the imports and the three members**

Add to the import block of `lib/features/media/data/repositories/media_library_repository.dart` (keep the block sorted):

```dart
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/services/media_placement_resolver.dart';
```

Insert after `countMissing()` (before the doc comment of `watchMediaChanges`):

```dart
  /// Photo and video rows only: documents have nothing to show on a map and
  /// signatures are never library rows. Subsumes [_notSignature].
  Expression<bool> get _mappable =>
      _db.media.fileType.isIn(const ['photo', 'video']);

  /// Every in-scope row that can be placed on the map, in the timeline's
  /// order (date taken ascending, then id).
  ///
  /// Unpaged by design: the cluster layer needs the whole located set at
  /// once. Sites are joined twice, through the dive and through the row's
  /// own site link, because site-attached media (issue #959) has no dive.
  /// The four coordinate pairs are fetched raw and resolved in Dart by
  /// [resolveMediaPlacement] so the plausibility rule lives in one place.
  Future<List<MediaMapPoint>> getMapPoints({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final s = _db.diveSites;
      final attached = _db.alias(_db.diveSites, 'attached_site');

      final where =
          _baseWhere(diverId, filter) &
          _mappable &
          (m.latitude.isNotNull() |
              d.entryLatitude.isNotNull() |
              s.latitude.isNotNull() |
              attached.latitude.isNotNull());

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
              leftOuterJoin(attached, attached.id.equalsExp(m.siteId)),
            ])
            ..where(where)
            ..orderBy([OrderingTerm.asc(_dateKey), OrderingTerm.asc(m.id)]);

      final rows = await query.get();
      final points = <MediaMapPoint>[];
      for (final row in rows) {
        final mediaRow = row.readTable(m);
        final diveRow = row.readTableOrNull(d);
        final siteRow = row.readTableOrNull(s);
        final attachedRow = row.readTableOrNull(attached);

        final resolved = resolveMediaPlacement(
          ownLatitude: mediaRow.latitude,
          ownLongitude: mediaRow.longitude,
          diveEntryLatitude: diveRow?.entryLatitude,
          diveEntryLongitude: diveRow?.entryLongitude,
          diveSiteLatitude: siteRow?.latitude,
          diveSiteLongitude: siteRow?.longitude,
          attachedSiteLatitude: attachedRow?.latitude,
          attachedSiteLongitude: attachedRow?.longitude,
        );
        if (resolved == null) continue;

        final label = siteRow?.name ?? attachedRow?.name;
        points.add(
          MediaMapPoint(
            entry: MediaLibraryEntry(
              item: mediaItemFromRow(mediaRow),
              diveNumber: diveRow?.diveNumber,
              // Wall-clock-as-UTC, exactly as getPage hydrates it.
              diveDateTime: diveRow == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      diveRow.diveDateTime,
                      isUtc: true,
                    ),
              siteName: label,
            ),
            point: resolved.point,
            placement: resolved.placement,
            placeLabel: label,
          ),
        );
      }
      return points;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media map points',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// How many photo and video rows the grid would show for this scope. The
  /// map's "without a location" count is this minus [getMapPoints].length.
  Future<int> countInScope({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    final m = _db.media;
    final d = _db.dives;
    final count = countAll();
    final query =
        _db.selectOnly(m).join([
            leftOuterJoin(d, d.id.equalsExp(m.diveId), useColumns: false),
          ])
          ..addColumns([count])
          ..where(_baseWhere(diverId, filter) & _mappable);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Emits whenever anything that can move a map point changes: the media
  /// row itself, a dive's entry fix, or a site's coordinates. Built and
  /// debounced exactly like [watchMediaChanges]; see its notes on why a
  /// `tableUpdates` stream and not a watched query.
  Stream<void> watchMapChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.media, _db.dives, _db.diveSites]),
      )
      .debounce(MediaRepository.changeTickDebounce);
```

- [ ] **Step 4: Run the repository test**

Run: `flutter test test/features/media/data/media_library_repository_map_test.dart`
Expected: PASS (7 tests).

If `_baseWhere` fails to compile against `selectOnly(m).join(...)` because the species `existsQuery` or the trip predicate references `d` columns not selected, keep `useColumns: false` (it only suppresses result columns, the join stays available to the WHERE) and re-run.

- [ ] **Step 5: Add the tick-stream guard cases**

In `test/architecture/repository_tick_stream_test.dart`, add to the `ticks` map that starts at line 171:

```dart
      'MediaLibraryRepository.watchMapChanges':
          MediaLibraryRepository().watchMapChanges,
```

Then add a group next to the existing `MediaLibraryRepository.watchMediaChanges` firing cases (search the file for `watchMediaChanges fires`):

```dart
  group('MediaLibraryRepository.watchMapChanges', () {
    // The map places media through dives (entry fix) and dive_sites
    // (coordinates), so a tick over media alone would leave a moved site's
    // photos where they were until something else happened to write media.
    test('fires on a dive_sites write', () async {
      expect(
        await fires(
          MediaLibraryRepository().watchMapChanges(),
          () => db
              .into(db.diveSites)
              .insert(
                DiveSitesCompanion(
                  id: const Value('site-tick'),
                  name: const Value('Tick'),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              ),
        ),
        isTrue,
      );
    });

    test('fires on a dives write', () async {
      expect(
        await fires(
          MediaLibraryRepository().watchMapChanges(),
          () => db
              .into(db.dives)
              .insert(
                DivesCompanion(
                  id: const Value('dive-tick'),
                  diveDateTime: Value(now),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              ),
        ),
        isTrue,
      );
    });
  });
```

Add `import 'package:drift/drift.dart' show Value;` if the file does not already import `Value`.

- [ ] **Step 6: Run the guard file and the whole architecture suite**

Run: `flutter test test/architecture/repository_tick_stream_test.dart`
Expected: PASS, including the silence case for the new tick.

Run: `flutter test test/architecture`
Expected: PASS.

- [ ] **Step 7: Run the existing library repository tests to confirm nothing regressed**

Run: `flutter test test/features/media/data/media_library_repository_test.dart`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/media/data/repositories/media_library_repository.dart test/features/media/data/media_library_repository_map_test.dart test/architecture/repository_tick_stream_test.dart
git commit -m "feat(media): add the unpaged map points query, scope count and map change tick"
```

---

### Task 5: `mediaMapPointsProvider`

**Files:**
- Create: `lib/features/media/presentation/providers/media_map_providers.dart`
- Test: `test/features/media/presentation/media_map_providers_test.dart`

**Interfaces:**
- Consumes: `MediaLibraryRepository.getMapPoints / countInScope / watchMapChanges` (Task 4); `mediaLibraryRepositoryProvider`, `mediaLibraryFilterProvider` (existing, `media_library_providers.dart`); `currentDiverIdProvider` (`features/divers/presentation/providers/diver_providers.dart`).
- Produces:
  - `class MediaMapState { List<MediaMapPoint> points; int unlocatedCount; bool isLoading; Object? error; copyWith }`
  - `final mediaMapPointsProvider = StateNotifierProvider.autoDispose<MediaMapNotifier, MediaMapState>`
  - `class MediaMapNotifier extends StateNotifier<MediaMapState> { Future<void> load(); }`
  Used by Tasks 10 and 11.

The spec names an `AsyncNotifierProvider`; the media feature's convention is the legacy `StateNotifierProvider` (`MediaLibraryNotifier` is the model), so this follows the convention with the same substance: auto-dispose and an explicit loading/error state.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/presentation/media_map_providers_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';

MediaMapPoint _point(String id) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: '/tmp/$id',
      takenAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    ),
  ),
  point: const LatLng(1, 2),
  placement: MediaPlacement.ownGps,
);

class _FakeMapRepo implements MediaLibraryRepository {
  final changes = StreamController<void>.broadcast();
  List<MediaMapPoint> points = [];
  int total = 0;
  int loads = 0;
  Object? failWith;
  MediaLibraryFilter? lastFilter;
  String? lastDiverId;

  @override
  Future<List<MediaMapPoint>> getMapPoints({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    loads++;
    lastFilter = filter;
    lastDiverId = diverId;
    final error = failWith;
    if (error != null) throw error;
    return points;
  }

  @override
  Future<int> countInScope({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async => total;

  @override
  Stream<void> watchMapChanges() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeMapRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeMapRepo();
    container = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.changes.close);
    // autoDispose: keep the provider alive for the test's duration.
    container.listen(mediaMapPointsProvider, (_, _) {});
  });

  test('loads points and derives the unlocated count', () async {
    repo.points = [_point('a'), _point('b')];
    repo.total = 5;

    container.read(mediaMapPointsProvider);
    await _settle();
    await _settle();

    final state = container.read(mediaMapPointsProvider);
    expect(state.isLoading, isFalse);
    expect(state.points.map((p) => p.item.id), ['a', 'b']);
    expect(state.unlocatedCount, 3);
    expect(repo.lastDiverId, 'd1');
    expect(repo.lastFilter, MediaLibraryFilter.none);
  });

  test('reloads on the map change tick', () async {
    container.read(mediaMapPointsProvider);
    await _settle();
    await _settle();
    expect(repo.loads, 1);

    repo.points = [_point('c')];
    repo.changes.add(null);
    await _settle();
    await _settle();

    expect(repo.loads, 2);
    expect(
      container.read(mediaMapPointsProvider).points.map((p) => p.item.id),
      ['c'],
    );
  });

  test('a failed load surfaces the error and keeps the last points', () async {
    repo.points = [_point('a')];
    container.read(mediaMapPointsProvider);
    await _settle();
    await _settle();

    repo.failWith = StateError('boom');
    repo.changes.add(null);
    await _settle();
    await _settle();

    final state = container.read(mediaMapPointsProvider);
    expect(state.error, isA<StateError>());
    expect(state.points.map((p) => p.item.id), ['a']);
    expect(state.isLoading, isFalse);
  });

  test('a filter change rebuilds the notifier with the new filter', () async {
    container.read(mediaMapPointsProvider);
    await _settle();
    await _settle();

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video);
    await _settle();
    await _settle();

    expect(repo.lastFilter?.mediaType, MediaType.video);
  });

  test('the unlocated count never goes negative', () async {
    repo.points = [_point('a')];
    repo.total = 0;
    container.read(mediaMapPointsProvider);
    await _settle();
    await _settle();

    expect(container.read(mediaMapPointsProvider).unlocatedCount, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/media_map_providers_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the provider file**

```dart
// lib/features/media/presentation/providers/media_map_providers.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

/// The map mode's data: every located in-scope item plus how many in-scope
/// items could not be placed.
class MediaMapState {
  const MediaMapState({
    this.points = const [],
    this.unlocatedCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<MediaMapPoint> points;
  final int unlocatedCount;
  final bool isLoading;
  final Object? error;

  MediaMapState copyWith({
    List<MediaMapPoint>? points,
    int? unlocatedCount,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return MediaMapState(
      points: points ?? this.points,
      unlocatedCount: unlocatedCount ?? this.unlocatedCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Located points for the map view mode. Rebuilt when the filter or the
/// active diver changes; reloaded on the map change tick (media, dives and
/// dive_sites writes).
///
/// Explicitly auto-dispose: Riverpod 3 defaults it off, and leaving map
/// mode should release the point list rather than hold it for the process
/// lifetime.
final mediaMapPointsProvider =
    StateNotifierProvider.autoDispose<MediaMapNotifier, MediaMapState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(mediaLibraryFilterProvider);
      return MediaMapNotifier(repo, diverId, filter);
    });

class MediaMapNotifier extends StateNotifier<MediaMapState> {
  MediaMapNotifier(this._repo, this._diverId, this._filter)
    : super(const MediaMapState(isLoading: true)) {
    _changesSub = _repo.watchMapChanges().listen((_) => load());
    load();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  StreamSubscription<void>? _changesSub;

  Future<void> load() async {
    // Keep the points on screen while reloading, as the grid does: emptying
    // them would unmount every marker and re-resolve every thumbnail.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final points = await _repo.getMapPoints(
        diverId: _diverId,
        filter: _filter,
      );
      final total = await _repo.countInScope(
        diverId: _diverId,
        filter: _filter,
      );
      if (!mounted) return;
      state = MediaMapState(
        points: points,
        unlocatedCount: math.max(0, total - points.length),
      );
    } catch (e) {
      if (!mounted) return;
      state = MediaMapState(
        points: state.points,
        unlocatedCount: state.unlocatedCount,
        error: e,
      );
    }
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _changesSub = null;
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/media_map_providers_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS. (`provider_change_tick_test` skips providers whose body constructs a notifier class; the notifier subscribes to the tick itself, as `MediaLibraryNotifier` does.)

```bash
dart format .
git add lib/features/media/presentation/providers/media_map_providers.dart test/features/media/presentation/media_map_providers_test.dart
git commit -m "feat(media): add the media map points provider"
```

---

### Task 6: Localisation keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (insert around lines 9920 to 9928)
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (insert directly after each file's `media_library_viewMode_timeline` line)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces on `AppLocalizations`: `media_library_viewMode_map`, `media_map_emptyTitle`, `media_map_emptyHint`, `media_map_unlocatedCount(int count)`, `media_map_placeItemCount(int count)`, `media_map_closeStrip`, `media_map_markerSemantics`, `media_map_clusterSemantics(int count, String place)`, `media_map_errorLoading(String error)`. Used by Tasks 7, 8, 10, 12.

- [ ] **Step 1: Add the English keys**

In `app_en.arb`, insert between the `@media_library_viewMode_grid` block and the `media_library_viewMode_timeline` key:

```json
  "media_library_viewMode_map": "Map",
  "@media_library_viewMode_map": {
    "description": "Library view mode: thumbnails placed on a map"
  },
```

Insert after the `@media_library_viewMode_timeline` block and before `media_viewer_goToDive`:

```json
  "media_map_closeStrip": "Close",
  "@media_map_closeStrip": {
    "description": "Tooltip on the button that dismisses the media map place strip"
  },
  "media_map_clusterSemantics": "{count, plural, one{{count} item at {place}} other{{count} items at {place}}}",
  "@media_map_clusterSemantics": {
    "description": "Screen-reader label for a cluster of media on the map",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "place": {
        "type": "String"
      }
    }
  },
  "media_map_emptyHint": "Photos and videos are placed by their own GPS, their dive's entry point, or their dive's site.",
  "@media_map_emptyHint": {
    "description": "Media map empty state: how items get a location"
  },
  "media_map_emptyTitle": "No media with a location",
  "@media_map_emptyTitle": {
    "description": "Media map empty state title"
  },
  "media_map_errorLoading": "Error loading media locations: {error}",
  "@media_map_errorLoading": {
    "description": "Media map error state",
    "placeholders": {
      "error": {
        "type": "String"
      }
    }
  },
  "media_map_markerSemantics": "Open media",
  "@media_map_markerSemantics": {
    "description": "Screen-reader label for a single media thumbnail on the map"
  },
  "media_map_placeItemCount": "{count, plural, one{{count} item} other{{count} items}}",
  "@media_map_placeItemCount": {
    "description": "Item count shown in the media map place strip",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "media_map_unlocatedCount": "{count, plural, one{{count} item without a location} other{{count} items without a location}}",
  "@media_map_unlocatedCount": {
    "description": "Label on the media map for in-scope items that could not be placed",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

- [ ] **Step 2: Add the ten translations**

In each non-English file, insert the block directly after the `"media_library_viewMode_timeline"` line, keeping that file's comma and quoting style. No `@` metadata in these files.

`app_de.arb`:
```json
  "media_library_viewMode_map": "Karte",
  "media_map_closeStrip": "Schließen",
  "media_map_clusterSemantics": "{count, plural, one{{count} Element bei {place}} other{{count} Elemente bei {place}}}",
  "media_map_emptyHint": "Fotos und Videos werden nach ihrem eigenen GPS, dem Einstiegspunkt des Tauchgangs oder dem Tauchplatz platziert.",
  "media_map_emptyTitle": "Keine Medien mit Ort",
  "media_map_errorLoading": "Fehler beim Laden der Medienorte: {error}",
  "media_map_markerSemantics": "Medium öffnen",
  "media_map_placeItemCount": "{count, plural, one{{count} Element} other{{count} Elemente}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} Element ohne Ort} other{{count} Elemente ohne Ort}}",
```

`app_es.arb`:
```json
  "media_library_viewMode_map": "Mapa",
  "media_map_closeStrip": "Cerrar",
  "media_map_clusterSemantics": "{count, plural, one{{count} elemento en {place}} other{{count} elementos en {place}}}",
  "media_map_emptyHint": "Las fotos y los vídeos se sitúan según su propio GPS, el punto de entrada de la inmersión o el punto de buceo.",
  "media_map_emptyTitle": "Sin medios con ubicación",
  "media_map_errorLoading": "Error al cargar las ubicaciones de los medios: {error}",
  "media_map_markerSemantics": "Abrir medio",
  "media_map_placeItemCount": "{count, plural, one{{count} elemento} other{{count} elementos}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} elemento sin ubicación} other{{count} elementos sin ubicación}}",
```

`app_fr.arb`:
```json
  "media_library_viewMode_map": "Carte",
  "media_map_closeStrip": "Fermer",
  "media_map_clusterSemantics": "{count, plural, one{{count} élément à {place}} other{{count} éléments à {place}}}",
  "media_map_emptyHint": "Les photos et vidéos sont placées d'après leur propre GPS, le point de mise à l'eau de la plongée ou le site de plongée.",
  "media_map_emptyTitle": "Aucun média localisé",
  "media_map_errorLoading": "Erreur de chargement des positions des médias : {error}",
  "media_map_markerSemantics": "Ouvrir le média",
  "media_map_placeItemCount": "{count, plural, one{{count} élément} other{{count} éléments}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} élément sans position} other{{count} éléments sans position}}",
```

`app_it.arb`:
```json
  "media_library_viewMode_map": "Mappa",
  "media_map_closeStrip": "Chiudi",
  "media_map_clusterSemantics": "{count, plural, one{{count} elemento a {place}} other{{count} elementi a {place}}}",
  "media_map_emptyHint": "Foto e video sono posizionati in base al proprio GPS, al punto di ingresso dell'immersione o al sito di immersione.",
  "media_map_emptyTitle": "Nessun media con posizione",
  "media_map_errorLoading": "Errore nel caricamento delle posizioni dei media: {error}",
  "media_map_markerSemantics": "Apri media",
  "media_map_placeItemCount": "{count, plural, one{{count} elemento} other{{count} elementi}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} elemento senza posizione} other{{count} elementi senza posizione}}",
```

`app_nl.arb`:
```json
  "media_library_viewMode_map": "Kaart",
  "media_map_closeStrip": "Sluiten",
  "media_map_clusterSemantics": "{count, plural, one{{count} item bij {place}} other{{count} items bij {place}}}",
  "media_map_emptyHint": "Foto's en video's worden geplaatst op basis van hun eigen gps, het instappunt van de duik of de duikstek.",
  "media_map_emptyTitle": "Geen media met locatie",
  "media_map_errorLoading": "Fout bij het laden van medialocaties: {error}",
  "media_map_markerSemantics": "Media openen",
  "media_map_placeItemCount": "{count, plural, one{{count} item} other{{count} items}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} item zonder locatie} other{{count} items zonder locatie}}",
```

`app_pt.arb`:
```json
  "media_library_viewMode_map": "Mapa",
  "media_map_closeStrip": "Fechar",
  "media_map_clusterSemantics": "{count, plural, one{{count} item em {place}} other{{count} itens em {place}}}",
  "media_map_emptyHint": "As fotos e os vídeos são colocados pelo seu próprio GPS, pelo ponto de entrada do mergulho ou pelo local de mergulho.",
  "media_map_emptyTitle": "Sem multimédia com localização",
  "media_map_errorLoading": "Erro ao carregar as localizações da multimédia: {error}",
  "media_map_markerSemantics": "Abrir multimédia",
  "media_map_placeItemCount": "{count, plural, one{{count} item} other{{count} itens}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} item sem localização} other{{count} itens sem localização}}",
```

`app_hu.arb`:
```json
  "media_library_viewMode_map": "Térkép",
  "media_map_closeStrip": "Bezárás",
  "media_map_clusterSemantics": "{count, plural, one{{count} elem itt: {place}} other{{count} elem itt: {place}}}",
  "media_map_emptyHint": "A fotók és videók a saját GPS-adatuk, a merülés beszállási pontja vagy a merülőhely alapján kerülnek a térképre.",
  "media_map_emptyTitle": "Nincs helyadattal rendelkező média",
  "media_map_errorLoading": "Hiba a médiahelyek betöltésekor: {error}",
  "media_map_markerSemantics": "Média megnyitása",
  "media_map_placeItemCount": "{count, plural, one{{count} elem} other{{count} elem}}",
  "media_map_unlocatedCount": "{count, plural, one{{count} elem hely nélkül} other{{count} elem hely nélkül}}",
```

`app_zh.arb`:
```json
  "media_library_viewMode_map": "地图",
  "media_map_closeStrip": "关闭",
  "media_map_clusterSemantics": "{count, plural, other{{place}：{count} 项}}",
  "media_map_emptyHint": "照片和视频按其自身 GPS、潜水入水点或潜点放置。",
  "media_map_emptyTitle": "没有带位置的媒体",
  "media_map_errorLoading": "加载媒体位置时出错：{error}",
  "media_map_markerSemantics": "打开媒体",
  "media_map_placeItemCount": "{count, plural, other{{count} 项}}",
  "media_map_unlocatedCount": "{count, plural, other{{count} 项没有位置}}",
```

`app_ar.arb`:
```json
  "media_library_viewMode_map": "خريطة",
  "media_map_closeStrip": "إغلاق",
  "media_map_clusterSemantics": "{count, plural, =1{عنصر واحد في {place}} =2{عنصران في {place}} other{{count} عناصر في {place}}}",
  "media_map_emptyHint": "تُوضع الصور ومقاطع الفيديو حسب إحداثيات GPS الخاصة بها، أو نقطة دخول الغوصة، أو موقع الغوص.",
  "media_map_emptyTitle": "لا توجد وسائط لها موقع",
  "media_map_errorLoading": "خطأ في تحميل مواقع الوسائط: {error}",
  "media_map_markerSemantics": "فتح الوسائط",
  "media_map_placeItemCount": "{count, plural, =1{عنصر واحد} =2{عنصران} other{{count} عناصر}}",
  "media_map_unlocatedCount": "{count, plural, =1{عنصر واحد بلا موقع} =2{عنصران بلا موقع} other{{count} عناصر بلا موقع}}",
```

`app_he.arb`:
```json
  "media_library_viewMode_map": "מפה",
  "media_map_closeStrip": "סגירה",
  "media_map_clusterSemantics": "{count, plural, =1{פריט אחד ב-{place}} other{{count} פריטים ב-{place}}}",
  "media_map_emptyHint": "תמונות וסרטונים ממוקמים לפי ה-GPS שלהם, נקודת הכניסה של הצלילה או אתר הצלילה.",
  "media_map_emptyTitle": "אין מדיה עם מיקום",
  "media_map_errorLoading": "שגיאה בטעינת מיקומי המדיה: {error}",
  "media_map_markerSemantics": "פתיחת מדיה",
  "media_map_placeItemCount": "{count, plural, =1{פריט אחד} other{{count} פריטים}}",
  "media_map_unlocatedCount": "{count, plural, =1{פריט אחד ללא מיקום} other{{count} פריטים ללא מיקום}}",
```

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: no output, exit 0. `git status` shows the eleven ARBs and `lib/l10n/arb/app_localizations*.dart` modified.

Run: `python3.14 - <<'PY'
import json, pathlib
keys = None
for p in sorted(pathlib.Path('lib/l10n/arb').glob('app_*.arb')):
    d = json.load(open(p, encoding='utf-8'))
    have = {k for k in d if k.startswith('media_map_') or k == 'media_library_viewMode_map'}
    print(p.name, len(have))
PY`
Expected: every file prints 9.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/l10n/arb
git commit -m "feat(media): add media map l10n keys in all locales"
```

---

### Task 7: `MediaMapMarker`

**Files:**
- Create: `lib/features/media/presentation/widgets/media_map_marker.dart`
- Test: `test/features/media/presentation/widgets/media_map_marker_test.dart`

**Interfaces:**
- Consumes: `MediaItemView` (existing), `MediaItem.isVideo`.
- Produces:
  - `const double kMediaMapMarkerSize = 56;`
  - `class MediaMapMarker extends StatelessWidget { MediaMapMarker({Key? key, required MediaItem item, int? count}) }`. `count` non-null draws the cluster badge with key `ValueKey('media-map-cluster-badge')`.
  Used by Task 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/presentation/widgets/media_map_marker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaItem _item({MediaType type = MediaType.photo}) => MediaItem(
  id: 'm1',
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-1',
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

Future<void> _pump(WidgetTester tester, Widget marker) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: Center(child: marker)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a plain marker is a 56dp thumbnail with no badge', (
    tester,
  ) async {
    await _pump(tester, MediaMapMarker(item: _item()));

    expect(find.byType(MediaItemView), findsOneWidget);
    expect(
      tester.getSize(find.byType(MediaMapMarker)),
      const Size(kMediaMapMarkerSize, kMediaMapMarkerSize),
    );
    expect(find.byKey(const ValueKey('media-map-cluster-badge')), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });

  testWidgets('a cluster marker shows the count badge', (tester) async {
    await _pump(tester, MediaMapMarker(item: _item(), count: 12));

    expect(find.byKey(const ValueKey('media-map-cluster-badge')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a video marker carries the play glyph', (tester) async {
    await _pump(tester, MediaMapMarker(item: _item(type: MediaType.video)));

    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/media_map_marker_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the widget**

```dart
// lib/features/media/presentation/widgets/media_map_marker.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

/// Edge of a map thumbnail in logical pixels: 52dp of image inside a 2dp
/// border, the visual weight of the dive map's 50dp selected marker.
const double kMediaMapMarkerSize = 56;

/// Decode target for a map thumbnail: twice the tile edge so it stays sharp
/// on 2x displays and still two orders of magnitude cheaper than the
/// original.
const Size _thumbnailTarget = Size(112, 112);

/// One media thumbnail on the map. With [count] it is a cluster's
/// representative tile and carries a count badge.
///
/// Deliberately gesture-free: the map wraps it in the tap handling it needs,
/// and the cluster plugin owns the cluster tap.
class MediaMapMarker extends StatelessWidget {
  const MediaMapMarker({super.key, required this.item, this.count});

  final MediaItem item;

  /// Number of items behind this tile when it stands for a cluster; null
  /// for a single item.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeCount = count;

    return SizedBox(
      width: kMediaMapMarkerSize,
      height: kMediaMapMarkerSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: kMediaMapMarkerSize,
            height: kMediaMapMarkerSize,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: _thumbnailTarget,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (item.isVideo)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(
                Icons.play_circle_fill,
                size: 16,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
          if (badgeCount != null)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                key: const ValueKey('media-map-cluster-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  '$badgeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/media_map_marker_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS.

```bash
dart format .
git add lib/features/media/presentation/widgets/media_map_marker.dart test/features/media/presentation/widgets/media_map_marker_test.dart
git commit -m "feat(media): add the media map thumbnail marker"
```

---

### Task 8: `MediaPlaceStrip`

**Files:**
- Create: `lib/features/media/presentation/widgets/media_place_strip.dart`
- Test: `test/features/media/presentation/widgets/media_place_strip_test.dart`

**Interfaces:**
- Consumes: `MediaMapPoint` (Task 3), `MediaItemView`, l10n `media_map_placeItemCount`, `media_map_closeStrip`, `media_map_markerSemantics` (Task 6).
- Produces: `class MediaPlaceStrip extends StatelessWidget { MediaPlaceStrip({required String title, required List<MediaMapPoint> points, required VoidCallback onClose, required void Function(MediaMapPoint) onItemTap}) }`. Used by Task 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/presentation/widgets/media_place_strip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaMapPoint _point(String id) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-$id',
      takenAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
  ),
  point: const LatLng(1, 2),
  placement: MediaPlacement.diveSite,
  placeLabel: 'Blue Hole',
);

void main() {
  testWidgets('shows the title, the count, and one tile per point; tapping '
      'a tile and the close button reach their callbacks', (tester) async {
    MediaMapPoint? tapped;
    var closed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: MediaPlaceStrip(
              title: 'Blue Hole',
              points: [_point('a'), _point('b'), _point('c')],
              onClose: () => closed++,
              onItemTap: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.byType(MediaItemView), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('media-place-strip-tile-b')));
    await tester.pumpAndSettle();
    expect(tapped?.item.id, 'b');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('a single item uses the singular count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: MediaPlaceStrip(
              title: '1.000000, 2.000000',
              points: [_point('a')],
              onClose: () {},
              onItemTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/media_place_strip_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the widget**

```dart
// lib/features/media/presentation/widgets/media_place_strip.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The media map's place strip: the items stacked at one point, as a
/// horizontal row of thumbnails under a place title.
///
/// An in-map overlay rather than a modal sheet, so the map stays pannable
/// underneath and the panel behaves the same on a phone and on a wide
/// desktop window, the way `MapInfoCard` sits on the other maps. The map
/// owns the open/closed state and positions this widget.
class MediaPlaceStrip extends StatelessWidget {
  const MediaPlaceStrip({
    super.key,
    required this.title,
    required this.points,
    required this.onClose,
    required this.onItemTap,
  });

  /// The place label, or formatted coordinates when no site is known.
  final String title;

  /// The stacked items, in date order, oldest first.
  final List<MediaMapPoint> points;

  final VoidCallback onClose;
  final void Function(MediaMapPoint point) onItemTap;

  static const double _tileEdge = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.media_map_closeStrip,
                  onPressed: onClose,
                ),
              ],
            ),
            Text(
              l10n.media_map_placeItemCount(points.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _tileEdge,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: points.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final point = points[index];
                  return Semantics(
                    button: true,
                    label: l10n.media_map_markerSemantics,
                    child: GestureDetector(
                      key: ValueKey('media-place-strip-tile-${point.item.id}'),
                      onTap: () => onItemTap(point),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: _tileEdge,
                          height: _tileEdge,
                          child: MediaItemView(
                            item: point.item,
                            thumbnail: true,
                            targetSize: const Size(192, 192),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/media_place_strip_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS.

```bash
dart format .
git add lib/features/media/presentation/widgets/media_place_strip.dart test/features/media/presentation/widgets/media_place_strip_test.dart
git commit -m "feat(media): add the media map place strip"
```

---

### Task 9: Shared `openMediaViewer` helper

**Files:**
- Create: `lib/features/media/presentation/pages/media_viewer_launcher.dart`
- Modify: `lib/features/media/presentation/pages/media_library_view.dart:46-63` (replace `_openViewer` body with a call to the helper)
- Test: `test/features/media/presentation/media_viewer_launcher_test.dart`

**Interfaces:**
- Consumes: `MediaViewerPage(mediaList, initialMediaId, showGoToDive)` (existing).
- Produces: `typedef MediaViewerOpener = void Function(BuildContext context, List<MediaItem> items, String initialMediaId);` and `void openMediaViewer(BuildContext context, List<MediaItem> items, String initialMediaId)`. Used by Tasks 10 and 11.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/presentation/media_viewer_launcher_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: '/tmp/$id',
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

void main() {
  testWidgets('pushes a full-screen MediaViewerPage on the tapped item', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    openMediaViewer(ctx, [_item('a'), _item('b')], 'b');
    await tester.pump();

    final route = observer.pushed.last as MaterialPageRoute<void>;
    expect(route.fullscreenDialog, isTrue);
    final page = route.builder(ctx) as MediaViewerPage;
    expect(page.initialMediaId, 'b');
    expect(page.mediaList.map((m) => m.id), ['a', 'b']);
    expect(page.showGoToDive, isTrue);
  });
}

class _RecordingObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}
```

The test inspects the route's builder without pumping the viewer, so it needs none of the viewer's providers.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/media_viewer_launcher_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the helper**

```dart
// lib/features/media/presentation/pages/media_viewer_launcher.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';

/// Signature of [openMediaViewer], so a surface can take the opener as a
/// parameter and a test can capture calls instead of pushing the viewer.
typedef MediaViewerOpener =
    void Function(BuildContext context, List<MediaItem> items, String initialMediaId);

/// Pushes the cross-dive media viewer as a full-screen dialog on [items],
/// starting at [initialMediaId]. The library grid and the media map share
/// this so the two entry points cannot drift.
void openMediaViewer(
  BuildContext context,
  List<MediaItem> items,
  String initialMediaId,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MediaViewerPage(
        mediaList: items,
        initialMediaId: initialMediaId,
        showGoToDive: true,
      ),
    ),
  );
}
```

- [ ] **Step 4: Point the library view at it**

In `lib/features/media/presentation/pages/media_library_view.dart`, replace the import of `media_viewer_page.dart` with:

```dart
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
```

and replace the `_openViewer` method (lines 46 to 63) with:

```dart
  void _openViewer(
    BuildContext context,
    List<MediaLibraryEntry> entries,
    MediaLibraryEntry entry,
  ) {
    openMediaViewer(
      context,
      entries.map((e) => e.item).toList(),
      entry.item.id,
    );
  }
```

- [ ] **Step 5: Run the new test and the library view tests**

Run: `flutter test test/features/media/presentation/media_viewer_launcher_test.dart test/features/media/presentation/media_library_view_missing_test.dart test/features/media/presentation/media_section_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/pages/media_viewer_launcher.dart lib/features/media/presentation/pages/media_library_view.dart test/features/media/presentation/media_viewer_launcher_test.dart
git commit -m "refactor(media): share the viewer launcher between the grid and the map"
```

---

### Task 10: `MediaMapContent`

**Files:**
- Create: `lib/features/media/presentation/widgets/media_map_content.dart`
- Test: `test/features/media/presentation/widgets/media_map_content_test.dart`

**Interfaces:**
- Consumes: `mediaMapPointsProvider`, `MediaMapState`, `MediaMapNotifier` (Task 5); `MediaMapMarker`, `kMediaMapMarkerSize` (Task 7); `MediaPlaceStrip` (Task 8); `MapCameraAnimator` (Task 2); `openMediaViewer`, `MediaViewerOpener` (Task 9); `mediaLibraryFilterProvider`; `submersionTileLayer`, `MapAttribution`, `MapCompassButton`, `TrackpadZoomMap`, `rotatableMapInteraction` (existing maps feature); `settingsProvider` + `UnitFormatter` for coordinates; l10n keys from Task 6 plus `diveLog_map_tooltip_fitAllSites` and `diveLog_error_retry`.
- Produces: `class MediaMapContent extends ConsumerStatefulWidget { MediaMapContent({Key? key, MediaViewerOpener openViewer = openMediaViewer}) }`. Used by Task 11.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/presentation/widgets/media_map_content_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

MediaMapPoint _point(
  String id, {
  LatLng at = const LatLng(12.5, 43.2),
  String? label = 'Blue Hole',
  bool favorite = false,
}) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-$id',
      isFavorite: favorite,
      takenAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
  ),
  point: at,
  placement: MediaPlacement.diveSite,
  placeLabel: label,
);

class _SeededMapNotifier extends StateNotifier<MediaMapState>
    implements MediaMapNotifier {
  _SeededMapNotifier(super.state);

  void seed(MediaMapState next) => state = next;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Opened {
  List<MediaItem>? items;
  String? initialId;
}

Future<_SeededMapNotifier> _pump(
  WidgetTester tester, {
  required MediaMapState state,
  _Opened? opened,
}) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final base = await getBaseOverrides();
  final notifier = _SeededMapNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        mediaMapPointsProvider.overrideWith((ref) => notifier),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaMapContent(
            openViewer: (context, items, id) {
              opened?.items = items;
              opened?.initialId = id;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return notifier;
}

/// flutter_map's double-tap disambiguation timer must be flushed before
/// teardown or the test fails on a pending timer.
Future<void> _flushMapTimers(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  testWidgets('renders the map with one thumbnail marker per point', (
    tester,
  ) async {
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a'), _point('b', at: const LatLng(-8, 115))]),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(MediaMapMarker), findsNWidgets(2));
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    await _flushMapTimers(tester);
  });

  testWidgets('no points shows the empty card, and the unlocated label still '
      'shows its count', (tester) async {
    await _pump(
      tester,
      state: const MediaMapState(points: [], unlocatedCount: 3),
    );

    expect(find.text('No media with a location'), findsOneWidget);
    expect(find.text('3 items without a location'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushMapTimers(tester);
  });

  testWidgets('the unlocated label is absent at zero', (tester) async {
    await _pump(tester, state: MediaMapState(points: [_point('a')]));

    expect(find.textContaining('without a location'), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('loading with nothing yet shows a spinner', (tester) async {
    await _pump(tester, state: const MediaMapState(isLoading: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('an error with nothing loaded shows the retry card', (
    tester,
  ) async {
    await _pump(tester, state: MediaMapState(error: StateError('boom')));

    expect(find.textContaining('Error loading media locations'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a single marker tap opens the viewer on that item', (
    tester,
  ) async {
    final opened = _Opened();
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
      opened: opened,
    );

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();

    expect(opened.initialId, 'a');
    expect(opened.items?.map((m) => m.id), ['a']);
    await _flushMapTimers(tester);
  });

  testWidgets('a co-located cluster opens the place strip even at world '
      'zoom, and a background tap closes it', (tester) async {
    final opened = _Opened();
    await _pump(
      tester,
      state: MediaMapState(
        points: [_point('a'), _point('b'), _point('c', favorite: true)],
      ),
      opened: opened,
    );

    // Three points at one location render as a single cluster tile.
    expect(find.byType(MediaMapMarker), findsOneWidget);
    expect(find.byKey(const ValueKey('media-map-cluster-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    // A strip tile opens the viewer with the whole stack as the sequence.
    await tester.tap(find.byKey(const ValueKey('media-place-strip-tile-b')));
    await tester.pump();
    expect(opened.initialId, 'b');
    expect(opened.items?.map((m) => m.id), ['a', 'b', 'c']);

    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    await _flushMapTimers(tester);
    expect(find.byType(MediaPlaceStrip), findsNothing);
  });

  testWidgets('the cluster representative is the favorite', (tester) async {
    await _pump(
      tester,
      state: MediaMapState(
        points: [_point('a'), _point('b', favorite: true)],
      ),
    );

    final marker = tester.widget<MediaMapMarker>(find.byType(MediaMapMarker));
    expect(marker.item.id, 'b');
    expect(marker.count, 2);
    await _flushMapTimers(tester);
  });

  testWidgets('a point reload without a filter change keeps the camera', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
    );
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final controller = map.mapController!;
    final fittedZoom = controller.camera.zoom;
    expect(fittedZoom, closeTo(12, 1e-6), reason: 'first load fits');

    controller.move(const LatLng(0, 0), 4);
    await tester.pump();

    notifier.seed(MediaMapState(points: [_point('a'), _point('d', at: const LatLng(1, 1))]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.camera.zoom, closeTo(4, 1e-6));
    expect(controller.camera.center.latitude, closeTo(0, 1e-6));
    await _flushMapTimers(tester);
  });

  testWidgets('a marker that stays on screen keeps its thumbnail state '
      'across a zoom change', (tester) async {
    await _pump(tester, state: MediaMapState(points: [_point('a')]));
    final before = tester.state(find.byType(MediaItemView));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.mapController!.move(const LatLng(12.5, 43.2), 13);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(identical(tester.state(find.byType(MediaItemView)), before), isTrue);
    await _flushMapTimers(tester);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/media_map_content_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Create the widget**

```dart
// lib/features/media/presentation/widgets/media_map_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The library's map view mode: every located item as a thumbnail marker,
/// clustered, with a place strip for stacks that share one point.
///
/// Mirrors the dive map's widget tree (trackpad wrapper, world-constrained
/// rotatable map, the shared tile layer, the marker cluster layer,
/// attribution, compass, fit-all) without its heat map, seascape or
/// bathymetry layers. Camera moves go through [MapCameraAnimator].
class MediaMapContent extends ConsumerStatefulWidget {
  const MediaMapContent({super.key, this.openViewer = openMediaViewer});

  /// How a tap reaches the viewer. Injected so tests can capture the call
  /// instead of pushing the real viewer and its provider graph.
  final MediaViewerOpener openViewer;

  @override
  ConsumerState<MediaMapContent> createState() => _MediaMapContentState();
}

/// A stack of co-located points the strip is showing.
class _StripSelection {
  const _StripSelection({required this.title, required this.points});
  final String title;
  final List<MediaMapPoint> points;
}

class _MediaMapContentState extends ConsumerState<MediaMapContent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final MapCameraAnimator _animator = MapCameraAnimator(
    controller: _mapController,
    vsync: this,
  );

  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;
  static const _minZoom = 2.0;
  static const _maxZoom = 18.0;

  bool _mapReady = false;

  /// True until the next successful data delivery has been fitted. Set on
  /// first build and on every filter change; NOT on table-write reloads,
  /// which would yank the camera mid-browse.
  bool _pendingFit = true;

  _StripSelection? _strip;

  @override
  void dispose() {
    _animator.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitIfPending(MediaMapState state) {
    if (!_pendingFit || !_mapReady) return;
    if (state.isLoading && state.points.isEmpty) return;
    if (state.error != null) return;
    _pendingFit = false;
    _animator.fitAll(state.points.map((p) => p.point).toList());
  }

  String _titleFor(List<MediaMapPoint> cluster) {
    final label = cluster
        .map((p) => p.placeLabel)
        .firstWhere((l) => l != null, orElse: () => null);
    if (label != null) return label;
    final first = cluster.first.point;
    final units = UnitFormatter(ref.read(settingsProvider));
    return units.formatCoordinates(first.latitude, first.longitude);
  }

  MediaMapPoint _representative(List<MediaMapPoint> cluster) =>
      cluster.firstWhere((p) => p.item.isFavorite, orElse: () => cluster.first);

  /// Recovers the points behind the plugin's markers through their media-id
  /// keys. Markers without one of our keys are ignored.
  List<MediaMapPoint> _pointsFor(
    Iterable<Marker> markers,
    Map<String, MediaMapPoint> byId,
  ) {
    final points = <MediaMapPoint>[];
    for (final marker in markers) {
      final key = marker.key;
      if (key is ValueKey<String>) {
        final point = byId[key.value];
        if (point != null) points.add(point);
      }
    }
    return points;
  }

  void _onClusterTap(MarkerClusterNode node, Map<String, MediaMapPoint> byId) {
    final cluster = _pointsFor(node.mapMarkers, byId);
    if (cluster.isEmpty) return;
    final first = cluster.first.point;
    final coLocated = cluster.every((p) => p.point == first);
    final atMaxZoom = _mapController.camera.zoom >= _maxZoom - 0.01;
    if (coLocated || atMaxZoom) {
      setState(() {
        _strip = _StripSelection(title: _titleFor(cluster), points: cluster);
      });
    } else {
      _animator.animateToBounds(node.bounds);
    }
  }

  void _closeStrip() {
    if (_strip == null) return;
    setState(() => _strip = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mediaLibraryFilterProvider, (_, _) => _pendingFit = true);
    ref.listen(mediaMapPointsProvider, (_, next) => _fitIfPending(next));

    final state = ref.watch(mediaMapPointsProvider);
    final l10n = context.l10n;

    if (state.isLoading && state.points.isEmpty && state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.points.isEmpty) {
      return _buildErrorState(context, state.error!);
    }

    final byId = {for (final p in state.points) p.item.id: p};
    final colorScheme = Theme.of(context).colorScheme;
    final strip = _strip;

    return Stack(
      children: [
        TrackpadZoomMap(
          controller: _mapController,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              interactionOptions: rotatableMapInteraction,
              onMapReady: () {
                _mapReady = true;
                _fitIfPending(ref.read(mediaMapPointsProvider));
              },
              onTap: (_, _) => _closeStrip(),
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-90, -180),
                  const LatLng(90, 180),
                ),
              ),
            ),
            children: [
              submersionTileLayer(ref),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(kMediaMapMarkerSize, kMediaMapMarkerSize),
                  markers: [
                    for (final p in state.points)
                      Marker(
                        key: ValueKey<String>(p.item.id),
                        point: p.point,
                        width: kMediaMapMarkerSize,
                        height: kMediaMapMarkerSize,
                        child: Semantics(
                          button: true,
                          label: l10n.media_map_markerSemantics,
                          child: GestureDetector(
                            onTap: () =>
                                widget.openViewer(context, [p.item], p.item.id),
                            child: MediaMapMarker(item: p.item),
                          ),
                        ),
                      ),
                  ],
                  builder: (context, markers) {
                    final cluster = _pointsFor(markers, byId);
                    if (cluster.isEmpty) return const SizedBox.shrink();
                    return Semantics(
                      button: true,
                      label: l10n.media_map_clusterSemantics(
                        cluster.length,
                        _titleFor(cluster),
                      ),
                      child: MediaMapMarker(
                        item: _representative(cluster).item,
                        count: cluster.length,
                      ),
                    );
                  },
                  zoomToBoundsOnClick: false,
                  onClusterTap: (node) => _onClusterTap(node, byId),
                ),
              ),
              const MapAttribution(),
            ],
          ),
        ),

        // Controls card: fit-all, plus the unlocated count when non-zero.
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.unlocatedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: Text(
                        l10n.media_map_unlocatedCount(state.unlocatedCount),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: l10n.diveLog_map_tooltip_fitAllSites,
                    onPressed: () => _animator.fitAll(
                      state.points.map((p) => p.point).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 64,
          right: 8,
          child: MapCompassButton(controller: _mapController),
        ),

        if (state.isLoading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),

        if (state.points.isEmpty)
          Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.media_map_emptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.media_map_emptyHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (strip != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: MediaPlaceStrip(
                    title: strip.title,
                    points: strip.points,
                    onClose: _closeStrip,
                    onItemTap: (point) => widget.openViewer(
                      context,
                      strip.points.map((p) => p.item).toList(),
                      point.item.id,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(l10n.media_map_errorLoading(error.toString())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(mediaMapPointsProvider),
            child: Text(l10n.diveLog_error_retry),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/media_map_content_test.dart`
Expected: PASS (10 tests).

If the co-located cluster test cannot find `MediaPlaceStrip` after the tap, the tap did not reach the cluster plugin's own `GestureDetector`. Replace the `tester.tap(find.byType(MediaMapMarker))` in that test with `await tester.tap(find.byKey(const ValueKey('media-map-cluster-badge')), warnIfMissed: false)` and re-run; the badge sits inside the same cluster widget.

If the thumbnail-state test fails because the zoom recreated the element, check that `Marker(key: ValueKey<String>(id))` is set (the cluster plugin passes `marker.key` through at `marker_cluster_layer.dart:196`); that is the whole mechanism.

- [ ] **Step 5: Run the architecture guards, format and commit**

Run: `flutter test test/architecture`
Expected: PASS.

```bash
dart format .
git add lib/features/media/presentation/widgets/media_map_content.dart test/features/media/presentation/widgets/media_map_content_test.dart
git commit -m "feat(media): add MediaMapContent with thumbnail markers and the place strip"
```

---

### Task 11: The `map` view mode in the library view

**Files:**
- Modify: `lib/features/media/presentation/providers/media_library_providers.dart:17` (enum)
- Modify: `lib/features/media/presentation/pages/media_library_view.dart:165-190` (switch) and its imports
- Test: `test/features/media/presentation/media_library_view_map_test.dart`
- Test: `test/features/media/presentation/media_library_providers_test.dart` (one added case)

**Interfaces:**
- Consumes: `MediaMapContent` (Task 10).
- Produces: `MediaLibraryViewMode.map`. Used by Task 12.

Note: this task breaks the toolbar's exhaustiveness? No: `SegmentedButton` takes a list, not a switch, so the toolbar compiles without the new segment until Task 12 adds it. The only exhaustive switch over the enum is the library view's, which this task updates.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/media/presentation/media_library_providers_test.dart`, inside its `main`, a case for the view-mode notifier (search the file for `MediaLibraryViewModeNotifier` and add next to those cases; if there is no such group, add this at the end of `main`):

```dart
  test('the view mode notifier round-trips map', () async {
    final settings = _RecordingSettingsRepo();
    final notifier = MediaLibraryViewModeNotifier(settings);
    addTearDown(notifier.dispose);

    await notifier.setMode(MediaLibraryViewMode.map);
    expect(settings.values['media_library_view_mode'], 'map');

    final reloaded = MediaLibraryViewModeNotifier(settings);
    addTearDown(reloaded.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.state, MediaLibraryViewMode.map);
  });
```

with, at file scope (skip if the file already has an equivalent recording fake; reuse that instead):

```dart
class _RecordingSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}
```

Create `test/features/media/presentation/media_library_view_map_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededMapNotifier extends StateNotifier<MediaMapState>
    implements MediaMapNotifier {
  _SeededMapNotifier() : super(const MediaMapState());

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MapModeSettingsRepo extends AppSettingsRepository {
  @override
  Future<String?> getRawSetting(String key) async =>
      key == 'media_library_view_mode' ? 'map' : null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

MediaLibraryEntry _entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-$id',
    takenAt: DateTime(2026, 3, 12),
    createdAt: DateTime(2026, 3, 12),
    updatedAt: DateTime(2026, 3, 12),
  ),
);

void main() {
  testWidgets('the persisted map mode renders the map instead of the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaLibraryNotifierProvider.overrideWith(
            (ref) => _SeededLibraryNotifier(
              MediaLibraryState(entries: [_entry('a')]),
            ),
          ),
          mediaMapPointsProvider.overrideWith((ref) => _SeededMapNotifier()),
          appSettingsRepositoryProvider.overrideWithValue(
            _MapModeSettingsRepo(),
          ),
          sitesProvider.overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaLibraryView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MediaMapContent), findsOneWidget);
    expect(find.byType(MediaLibraryGrid), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/media_library_view_map_test.dart test/features/media/presentation/media_library_providers_test.dart`
Expected: FAIL, `MediaLibraryViewMode.map` is not defined.

- [ ] **Step 3: Add the enum value**

In `lib/features/media/presentation/providers/media_library_providers.dart` line 17:

```dart
/// Library browse presentations. Values are persisted by name via the app
/// settings key-value store; an unknown stored name falls back to [grid],
/// which is what makes adding a value here migration-free.
enum MediaLibraryViewMode { grid, byDive, timeline, map }
```

- [ ] **Step 4: Add the switch case**

In `lib/features/media/presentation/pages/media_library_view.dart`, add the import:

```dart
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
```

and add a fourth case to the `switch (mode)` in `_buildBody`:

```dart
      MediaLibraryViewMode.map => const MediaMapContent(),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/media/presentation/media_library_view_map_test.dart test/features/media/presentation/media_library_providers_test.dart test/features/media/presentation/media_library_view_missing_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze, format and commit**

Run: `flutter analyze lib/features/media`
Expected: No issues found.

```bash
dart format .
git add lib/features/media/presentation/providers/media_library_providers.dart lib/features/media/presentation/pages/media_library_view.dart test/features/media/presentation/media_library_view_map_test.dart test/features/media/presentation/media_library_providers_test.dart
git commit -m "feat(media): add the map library view mode"
```

---

### Task 12: Toolbar: the fourth segment, the narrow-width menu, and selection exit

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_toolbar.dart`
- Test: `test/features/media/presentation/media_library_toolbar_test.dart` (four added cases)

**Interfaces:**
- Consumes: `MediaLibraryViewMode.map` (Task 11), `SelectionController.exit()` / `.value.isActive` (existing), l10n `media_library_viewMode_map` (Task 6).
- Produces: `const double kMediaToolbarFourSegmentMinWidth` (measured in Step 3) and the private `_ViewModeMenuButton`.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `test/features/media/presentation/media_library_toolbar_test.dart` (the file's `container`, `selection`, `host` and `pump` helpers are reused; `pump` sets a 1600px view):

```dart
  testWidgets('a wide row shows four view-mode segments including map', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(SegmentedButton<MediaLibraryViewMode>), findsOneWidget);
    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.byType(PopupMenuButton<MediaLibraryViewMode>), findsNothing);

    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();
    expect(container.read(mediaLibraryViewModeProvider), MediaLibraryViewMode.map);
  });

  testWidgets('a 320dp row collapses the view modes to a menu and does not '
      'overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SegmentedButton<MediaLibraryViewMode>), findsNothing);
    expect(find.byType(PopupMenuButton<MediaLibraryViewMode>), findsOneWidget);

    // Review Focus 5: the narrow row, a selection in flight, then map.
    selection.enterExplicit();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<MediaLibraryViewMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(mediaLibraryViewModeProvider), MediaLibraryViewMode.map);
    expect(selection.value.isActive, isFalse);
    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
  });

  testWidgets('choosing map with a selection active exits selection', (
    tester,
  ) async {
    await pump(tester);
    selection.enterExplicit();
    expect(selection.value.isActive, isTrue);

    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();

    expect(selection.value.isActive, isFalse);
    expect(container.read(mediaLibraryViewModeProvider), MediaLibraryViewMode.map);
  });

  testWidgets('the select control is hidden in map mode', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);

    await container
        .read(mediaLibraryViewModeProvider.notifier)
        .setMode(MediaLibraryViewMode.map);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/media_library_toolbar_test.dart`
Expected: the four new cases FAIL (`Icons.map` not found; overflow exception at 320dp or no `PopupMenuButton`).

- [ ] **Step 3: Measure the four-segment row**

Create a throwaway test `test/features/media/presentation/toolbar_measure_test.dart` (do not commit it):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('measure', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () {},
              ),
              SegmentedButton<MediaLibraryViewMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: MediaLibraryViewMode.grid, icon: Icon(Icons.grid_view)),
                  ButtonSegment(value: MediaLibraryViewMode.byDive, icon: Icon(Icons.scuba_diving)),
                  ButtonSegment(value: MediaLibraryViewMode.timeline, icon: Icon(Icons.calendar_month)),
                  ButtonSegment(value: MediaLibraryViewMode.map, icon: Icon(Icons.map)),
                ],
                selected: const {MediaLibraryViewMode.grid},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.getSize(find.byType(IconButton)).width;
    final segments = tester.getSize(find.byType(SegmentedButton<MediaLibraryViewMode>)).width;
    // Three compact icon buttons (filter, sort, select) plus the segments,
    // plus 8dp of spare for the Spacer.
    // ignore: avoid_print
    print('MEASURE icon=$button segments=$segments threshold=${3 * button + segments + 8}');
  });
}
```

Run: `flutter test test/features/media/presentation/toolbar_measure_test.dart`
Read the `MEASURE ... threshold=` line, round the threshold UP to the next whole number, and use it as `kMediaToolbarFourSegmentMinWidth` in Step 4. Then delete the throwaway file:

```bash
rm test/features/media/presentation/toolbar_measure_test.dart
```

- [ ] **Step 4: Rewrite the toolbar**

Replace the whole of `lib/features/media/presentation/widgets/media_library_toolbar.dart` with the following, substituting the measured number for `<MEASURED>` in both the constant and its doc comment:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// Narrowest row width at which the four view-mode segments fit beside the
/// three compact icon buttons with 8dp to spare. Measured at 1x on the
/// default Material 3 theme with a throwaway test that laid out one compact
/// icon button and the four-segment button and summed three buttons, the
/// segments and 8dp. Below it the segments collapse to
/// [_ViewModeMenuButton]. 320dp, the narrowest phone the app ships to, is
/// below it.
const double kMediaToolbarFourSegmentMinWidth = <MEASURED>;

/// The library's control row: filter, sort, select, and view mode.
///
/// Every control is fixed-width, which is the point. The chip row this
/// replaced was an Expanded horizontal scroller that claimed all free width
/// and squeezed the view-mode selector beside it.
///
/// Fixed widths also mean the row has a hard budget. The fourth view mode
/// (map) pushed the segmented button past what 320dp can hold next to the
/// three compact icon buttons, so the row measures itself: with room, four
/// segments; without, one menu button showing the current mode's icon, the
/// way the dive list picks its view mode.
class MediaLibraryToolbar extends ConsumerWidget {
  const MediaLibraryToolbar({
    super.key,
    required this.selection,
    required this.canSelect,
  });

  /// The library's selection state machine. The Select control is the only
  /// way into multi-select: long-press enters selection nowhere in the app.
  final SelectionController selection;

  /// Whether there is anything to select. An empty library hides the control
  /// rather than offering a mode with no items in it.
  final bool canSelect;

  static IconData iconFor(MediaLibraryViewMode mode) => switch (mode) {
    MediaLibraryViewMode.grid => Icons.grid_view,
    MediaLibraryViewMode.byDive => Icons.scuba_diving,
    MediaLibraryViewMode.timeline => Icons.calendar_month,
    MediaLibraryViewMode.map => Icons.map,
  };

  static String labelFor(MediaLibraryViewMode mode, AppLocalizations l10n) =>
      switch (mode) {
        MediaLibraryViewMode.grid => l10n.media_library_viewMode_grid,
        MediaLibraryViewMode.byDive => l10n.media_library_viewMode_byDive,
        MediaLibraryViewMode.timeline => l10n.media_library_viewMode_timeline,
        MediaLibraryViewMode.map => l10n.media_library_viewMode_map,
      };

  void _setMode(WidgetRef ref, MediaLibraryViewMode next) {
    // Map mode has no multi-select; leaving a selection half-open under a
    // surface that cannot show it would strand the selection bar.
    if (next == MediaLibraryViewMode.map && selection.value.isActive) {
      selection.exit();
    }
    ref.read(mediaLibraryViewModeProvider.notifier).setMode(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactModes =
            constraints.maxWidth < kMediaToolbarFourSegmentMinWidth;
        return Row(
          children: [
            IconButton(
              icon: Badge(
                isLabelVisible: !filter.isEmpty,
                child: const Icon(Icons.filter_list, size: 20),
              ),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.media_library_filter_title,
              onPressed: () => showMediaLibraryFilterSheet(context),
            ),
            // Grid only: the by-dive and timeline groupers consume an
            // already-date-sorted stream, so a name or size sort would break
            // their grouping rather than reorder it, and the map has no order.
            if (mode == MediaLibraryViewMode.grid)
              IconButton(
                icon: const Icon(Icons.sort, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.media_library_sort_title,
                onPressed: () {
                  final sort = ref.read(mediaLibrarySortProvider);
                  showSortBottomSheet<MediaSortField>(
                    context: context,
                    title: l10n.media_library_sort_title,
                    currentField: sort.field,
                    currentDirection: sort.direction,
                    fields: MediaSortField.values,
                    getFieldDisplayName: (field) => field.localizedName(l10n),
                    getFieldIcon: (field) => field.icon,
                    onSortChanged: (field, direction) => ref
                        .read(mediaLibrarySortProvider.notifier)
                        .setSort(field, direction),
                  );
                },
              ),
            // The map cannot show a selection, so it does not offer one.
            if (canSelect && mode != MediaLibraryViewMode.map)
              IconButton(
                key: const ValueKey('enter_selection'),
                icon: const Icon(Icons.checklist, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.common_selection_enterTooltip,
                onPressed: selection.enterExplicit,
              ),
            const Spacer(),
            if (compactModes)
              _ViewModeMenuButton(
                current: mode,
                onChanged: (next) => _setMode(ref, next),
              )
            else
              SegmentedButton<MediaLibraryViewMode>(
                showSelectedIcon: false,
                segments: [
                  for (final m in MediaLibraryViewMode.values)
                    ButtonSegment(
                      value: m,
                      icon: Icon(iconFor(m)),
                      tooltip: labelFor(m, l10n),
                    ),
                ],
                selected: {mode},
                onSelectionChanged: (chosen) => _setMode(ref, chosen.single),
              ),
          ],
        );
      },
    );
  }
}

/// The narrow-width view-mode picker: the current mode's icon, opening a
/// menu of all four. Mirrors `ListViewModeToggle`.
class _ViewModeMenuButton extends StatelessWidget {
  const _ViewModeMenuButton({required this.current, required this.onChanged});

  final MediaLibraryViewMode current;
  final ValueChanged<MediaLibraryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<MediaLibraryViewMode>(
      icon: Icon(MediaLibraryToolbar.iconFor(current), size: 20),
      tooltip: MediaLibraryToolbar.labelFor(current, l10n),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final m in MediaLibraryViewMode.values)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(
                  MediaLibraryToolbar.iconFor(m),
                  size: 20,
                  color: m == current ? primary : null,
                ),
                const SizedBox(width: 12),
                Text(
                  MediaLibraryToolbar.labelFor(m, l10n),
                  style: m == current
                      ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the toolbar tests**

Run: `flutter test test/features/media/presentation/media_library_toolbar_test.dart`
Expected: PASS, all existing cases plus the four new ones.

If the 320dp case still reports an overflow, the measured threshold was too low for the 320dp host (the toolbar's outer 8dp padding lives in `MediaLibraryView`, not here, so the `host()` in this test hands the row the full 320). Raise the constant by the overflow amount the exception reports and re-run.

- [ ] **Step 6: Run the media presentation suite and the architecture guards**

Run: `flutter test test/features/media/presentation`
Expected: PASS.

Run: `flutter test test/architecture`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_library_toolbar.dart test/features/media/presentation/media_library_toolbar_test.dart
git commit -m "feat(media): add the map view-mode segment with a narrow-width menu fallback"
```

---

### Task 13: Whole-project verification and the pull request

**Files:**
- No new files. Verification only, then the PR.

- [ ] **Step 1: Format the whole project and confirm nothing changed**

```bash
dart format .
git status --short
```
Expected: clean.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (infos count as failures in CI).

- [ ] **Step 3: Confirm the generated l10n is current**

Run: `flutter gen-l10n && git status --short lib/l10n`
Expected: no output from `git status` (nothing regenerated differently).

- [ ] **Step 4: Run the touched test directories, one invocation at a time**

Run: `flutter test test/features/media test/features/maps test/architecture`
Expected: all PASS. Do not pipe through `grep`; read the final summary line.

- [ ] **Step 5: Scan the diff for forbidden characters**

Run: `git diff origin/main...HEAD | grep -nP "\x{2014}|\x{2013}" || echo "no dashes"`
Expected: `no dashes`.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin ericgriffin/media-map-mode-260133
```

PR title: `Media map mode: thumbnails on a map as a fourth library view`

PR body (the `Closes` keyword must sit directly before the number):

```
Closes #2329

Adds a fourth media library view mode, `map`, that places photo and video thumbnails on a clustered map.

- Placement: own GPS fix, then the dive's entry fix, then the dive's site, then the attached site. Both GPS sources pass the existing plausibility check.
- Markers and clusters are thumbnails; a cluster shows its favorite (else oldest) item with a count badge.
- Tapping a separable cluster zooms in. A cluster whose members share one point, or any cluster at maximum zoom, opens an in-map place strip; tapping a strip tile opens the viewer with the stack as the swipe sequence. A lone thumbnail opens the viewer directly.
- The map obeys the active library filter and shows how many in-scope items have no location.
- No multi-select on the map; switching to map exits an active selection. The view-mode segments collapse to a menu button on rows narrower than the measured four-segment width, so 320dp phones do not overflow.
- New unpaged repository query with a second site join through the media row's own site link, and a change tick over media, dives and dive_sites.
- `MapCameraAnimator` and `boundsForPoints` are extracted into the maps feature. The dive, site and dive-center maps keep their private copies; #2330 migrates them.

Spec: docs/superpowers/specs/2026-09-25-media-map-mode-design.md
Plan: docs/superpowers/plans/2026-09-25-media-map-mode.md
```

Create it with `gh pr create --title "<title>" --body-file <path to a file holding the body>` from the scratchpad, never inline with a `read` loop. No attribution lines, no tool mention.

- [ ] **Step 7: Bind the PR for CI monitoring**

Call `mcp__ccd_pr__get_status`; if it does not report this PR, call `mcp__ccd_pr__bind_pr` with its URL. Do not poll CI by hand.
