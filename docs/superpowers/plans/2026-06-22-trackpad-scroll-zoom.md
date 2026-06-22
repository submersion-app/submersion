# Two-finger Trackpad Scroll → Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make two-finger up/down scroll on a trackpad zoom in/out (cursor-anchored) on all 17 maps and on the dive profile chart.

**Architecture:** One pure helper converts a trackpad vertical scroll delta into a zoom-level delta. A passive `Listener`-based wrapper (`TrackpadZoomMap`) drives `MapController` zoom for maps. The dive profile chart's existing `onPointerPanZoomUpdate` is modified to fold vertical scroll into its zoom factor instead of panning.

**Tech Stack:** Flutter, flutter_map 8.2.2 (`MapController`, `MapCamera.focusedZoomCenter`), fl_chart, Riverpod.

## Global Constraints

- `dart format .` must produce no changes (CI gate).
- `flutter analyze` must pass with zero issues across the whole project.
- No emojis in code/comments.
- Immutability; no mutation of shared objects.
- Only `PointerDeviceKind.trackpad` gestures are re-interpreted; touch and mouse paths are untouched.
- Direction matches the existing mouse-wheel convention: negative `dy` (scroll up/away) zooms in.
- Zoom is cursor-anchored.
- Run specific test files (not broad directories) to avoid Bash timeouts.

---

### Task 1: Pure zoom-delta helper

**Files:**
- Create: `lib/core/ui/trackpad_zoom.dart`
- Test: `test/core/ui/trackpad_zoom_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01})` — returns an additive zoom-level delta; negative `scrollDy` returns a positive delta (zoom in); `0` returns `0`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom.dart';

void main() {
  group('trackpadScrollZoomDelta', () {
    test('zero scroll yields zero delta', () {
      expect(trackpadScrollZoomDelta(0), 0);
    });

    test('scroll up (negative dy) zooms in (positive delta)', () {
      expect(trackpadScrollZoomDelta(-100), greaterThan(0));
    });

    test('scroll down (positive dy) zooms out (negative delta)', () {
      expect(trackpadScrollZoomDelta(100), lessThan(0));
    });

    test('is symmetric for equal-and-opposite scrolls', () {
      expect(trackpadScrollZoomDelta(-50), -trackpadScrollZoomDelta(50));
    });

    test('scales with sensitivity', () {
      expect(
        trackpadScrollZoomDelta(-100, sensitivity: 0.02),
        2 * trackpadScrollZoomDelta(-100, sensitivity: 0.01),
      );
    });

    test('default sensitivity maps a ~100px flick to ~1 zoom level', () {
      expect(trackpadScrollZoomDelta(-100), closeTo(1.0, 0.0001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/ui/trackpad_zoom_test.dart`
Expected: FAIL — `trackpad_zoom.dart` / `trackpadScrollZoomDelta` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
/// Pure helpers for trackpad two-finger-scroll zooming, shared by the maps and
/// the dive profile chart so sign and sensitivity live in one tested place.

/// Converts a trackpad two-finger vertical scroll delta (logical pixels) into an
/// additive zoom-level delta.
///
/// Negative [scrollDy] (scroll up / away from the user) returns a positive delta
/// (zoom in), matching the mouse-wheel convention so wheel and trackpad agree on
/// the same machine. Map consumers add the result to `camera.zoom`; the dive
/// profile chart applies `pow(2, delta)` as a multiplicative factor.
double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01}) {
  return -scrollDy * sensitivity;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/ui/trackpad_zoom_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/trackpad_zoom.dart test/core/ui/trackpad_zoom_test.dart
git commit -m "feat(ui): add trackpadScrollZoomDelta helper"
```

---

### Task 2: `TrackpadZoomMap` wrapper widget

**Files:**
- Create: `lib/features/maps/presentation/widgets/trackpad_zoom_map.dart`
- Test: `test/features/maps/presentation/widgets/trackpad_zoom_map_test.dart`

**Interfaces:**
- Consumes: `trackpadScrollZoomDelta` (Task 1); flutter_map `MapController`, `MapCamera.focusedZoomCenter`.
- Produces: `TrackpadZoomMap({required MapController controller, required Widget child, double minZoom = 1.0, double maxZoom = 22.0})` — a `StatelessWidget` that wraps `child` (a `FlutterMap`) in a passive `Listener` and zooms `controller` on trackpad two-finger vertical scroll.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';

void main() {
  Future<MapController> pumpMap(WidgetTester tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackpadZoomMap(
            controller: controller,
            child: FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
                minZoom: 1,
                maxZoom: 18,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('trackpad two-finger scroll up zooms in', (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(center);
    await gesture.panZoomUpdate(center, pan: const Offset(0, -100));
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, greaterThan(start));
  });

  testWidgets('trackpad two-finger scroll down zooms out', (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(center);
    await gesture.panZoomUpdate(center, pan: const Offset(0, 100));
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, lessThan(start));
  });

  testWidgets('touch two-finger pan does not zoom via the wrapper',
      (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.panZoomStart(center);
    await gesture.panZoomUpdate(center, pan: const Offset(0, -100));
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, start);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/presentation/widgets/trackpad_zoom_map_test.dart`
Expected: FAIL — `trackpad_zoom_map.dart` / `TrackpadZoomMap` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/ui/trackpad_zoom.dart';

/// Wraps a [FlutterMap] so a two-finger vertical scroll on a trackpad zooms the
/// map toward the cursor, instead of panning.
///
/// The [Listener] is passive (it never enters the gesture arena), so flutter_map
/// keeps handling click-drag pan, pinch zoom, and mouse-wheel zoom underneath.
/// Only [PointerDeviceKind.trackpad] events are re-interpreted; touch gestures
/// (tablet pinch / two-finger pan) flow through to flutter_map unchanged.
class TrackpadZoomMap extends StatelessWidget {
  const TrackpadZoomMap({
    super.key,
    required this.controller,
    required this.child,
    this.minZoom = 1.0,
    this.maxZoom = 22.0,
  });

  /// The same controller passed to the wrapped [FlutterMap]'s `mapController`.
  final MapController controller;
  final Widget child;
  final double minZoom;
  final double maxZoom;

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.kind != PointerDeviceKind.trackpad) return;
    // Per-event vertical delta. Use the global panDelta (not localPanDelta):
    // on macOS the trackpad localPan is contaminated by the widget's
    // global->local translation (see dive profile chart, PR #372).
    final delta = trackpadScrollZoomDelta(event.panDelta.dy);
    if (delta == 0) return;

    final MapCamera camera;
    try {
      camera = controller.camera;
    } catch (_) {
      // Controller not yet attached to a FlutterMap.
      return;
    }
    final newZoom = (camera.zoom + delta).clamp(minZoom, maxZoom);
    if (newZoom == camera.zoom) return;
    // focusedZoomCenter keeps the point under the cursor fixed; it already
    // accounts for map rotation.
    controller.move(camera.focusedZoomCenter(event.localPosition, newZoom),
        newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/presentation/widgets/trackpad_zoom_map_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/maps/presentation/widgets/trackpad_zoom_map.dart test/features/maps/presentation/widgets/trackpad_zoom_map_test.dart
git commit -m "feat(maps): add TrackpadZoomMap two-finger-scroll zoom wrapper"
```

---

### Task 3: Profile chart — scroll-to-zoom in `onPointerPanZoomUpdate`

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (the `onPointerPanZoomUpdate` handler, currently around lines 1289-1328)
- Test: `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart` (add a group)

**Interfaces:**
- Consumes: `trackpadScrollZoomDelta` (Task 1); existing `ProfileChartViewport.zoomedAt`.
- Produces: no new public API; behavior change only.

- [ ] **Step 1: Add the failing test (documents the scroll→factor mapping)**

Append this group inside `main()` in `profile_chart_viewport_test.dart`:

```dart
  group('trackpad scroll folds into a cumulative zoom factor', () {
    test('scroll up produces a >1 factor (zoom in)', () {
      final factor = math.pow(2, trackpadScrollZoomDelta(-100)).toDouble();
      expect(factor, greaterThan(1.0));
      final vp = ProfileChartViewport().zoomedAt(0.5, 0.5, factor);
      expect(vp.zoom, greaterThan(1.0));
    });

    test('scroll down produces a <1 factor (zoom out) and is a no-op at rail',
        () {
      final factor = math.pow(2, trackpadScrollZoomDelta(100)).toDouble();
      expect(factor, lessThan(1.0));
      // Already at minZoom -> zooming out is a no-op.
      final vp = ProfileChartViewport().zoomedAt(0.5, 0.5, factor);
      expect(vp.zoom, ProfileChartViewport.minZoom);
    });
  });
```

Add these imports at the top of the test file if missing:

```dart
import 'dart:math' as math;
import 'package:submersion/core/ui/trackpad_zoom.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: FAIL — `trackpadScrollZoomDelta` import unresolved (if Task 1 not yet merged into this worktree state) or the new group present but compiling; if Task 1 is done it should compile and PASS, in which case this test only guards the mapping. Confirm it at least compiles and runs.

- [ ] **Step 3: Modify the chart handler**

Add the import near the other `package:submersion/...` imports in `dive_profile_chart.dart`:

```dart
import 'package:submersion/core/ui/trackpad_zoom.dart';
```

Ensure `dart:math` is imported (it is used as `math` if present; otherwise add `import 'dart:math' as math;`). Replace the body of `onPointerPanZoomUpdate` so it folds the cumulative vertical pan into the zoom factor and no longer translates:

```dart
              onPointerPanZoomUpdate: (event) {
                setState(() {
                  final box = constraints.biggest;
                  final insets = _plotInsets(constraints.maxWidth, units);
                  final focal = chartFocalFraction(
                    _trackpadAnchor,
                    box,
                    left: insets.left,
                    right: insets.right,
                    top: insets.top,
                    bottom: insets.bottom,
                  );
                  // Cumulative since gesture start: pinch (event.scale) and
                  // two-finger vertical scroll (event.pan.dy) both zoom,
                  // cursor-anchored at the gesture-start position. Two-finger
                  // scroll no longer pans; pan is done with click-drag.
                  final factor = event.scale *
                      math.pow(2, trackpadScrollZoomDelta(event.pan.dy))
                          .toDouble();
                  _viewport =
                      _gestureStartViewport.zoomedAt(focal.fx, focal.fy, factor);
                });
              },
```

(Delete the previous `var vp = ...zoomedAt(...event.scale)` + `vp = vp.pannedBy(-event.pan...)` + `_viewport = vp;` lines this replaces. Keep `onPointerPanZoomStart` and `onPointerSignal` as they are.)

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: PASS (existing 15 + new 2 = 17).
Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
git commit -m "feat(profile): two-finger trackpad scroll zooms the dive profile chart"
```

---

### Task 4: Roll out `TrackpadZoomMap` to Category A maps (wrap-only)

These 9 sites already are stateful and pass a `MapController` to `FlutterMap`. For each, wrap the existing `FlutterMap(...)` in `TrackpadZoomMap` using the SAME controller already passed to its `mapController:` argument.

**Files (modify each):**
- `lib/features/maps/presentation/pages/region_picker_page.dart`
- `lib/features/maps/presentation/pages/dive_activity_map_page.dart`
- `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`

**Interfaces:**
- Consumes: `TrackpadZoomMap` (Task 2).
- Produces: nothing new.

**The recipe (apply at each `FlutterMap(`):**

Add the import:
```dart
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
```

Transform, where `<ctrl>` is the exact expression already given to `mapController:`:
```dart
// Before:
FlutterMap(
  mapController: <ctrl>,
  options: ...,
  children: ...,
)
// After:
TrackpadZoomMap(
  controller: <ctrl>,
  child: FlutterMap(
    mapController: <ctrl>,
    options: ...,
    children: ...,
  ),
)
```

- [ ] **Step 1: Apply the recipe to all 9 files.** Use the controller already passed to each `mapController:` argument. Do not change options/children.

- [ ] **Step 2: Format + analyze**

Run: `dart format lib/`
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Smoke test the affected widget tests (if any exist)**

Run: `flutter test test/features/maps/ test/features/dive_sites/ test/features/dive_centers/ test/features/dive_log/presentation/widgets/dive_map_content_test.dart 2>/dev/null; true`
Expected: No new failures attributable to these wraps (pre-existing unrelated skips/failures are acceptable; compare against baseline). If a map test pumps the widget, it should still build.

- [ ] **Step 4: Commit**

```bash
git add lib/features/maps lib/features/dive_sites lib/features/dive_log lib/features/dive_centers
git commit -m "feat(maps): enable trackpad scroll zoom on stateful map sites"
```

---

### Task 5: Roll out to Category B maps (convert stateless → stateful, then wrap)

These 8 maps (6 files) are in `ConsumerWidget`s (or lack a controller). Each needs a `MapController` created and held by a stateful widget, passed to both `FlutterMap` and `TrackpadZoomMap`.

**Files (modify each):**
- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart` (1 map; optional `controller` param)
- `lib/features/trips/presentation/widgets/trip_voyage_map.dart` (1 map; `TripVoyageMap` is `ConsumerWidget`)
- `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (1 map; `TripOverviewTab` is `ConsumerWidget`)
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (2 maps in `_SiteDetailContent`, a `ConsumerWidget`)
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (2 maps in `_MapSection`, a `ConsumerWidget`)
- `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (1 map in `SiteListTile`, a `ConsumerWidget`)

**Interfaces:**
- Consumes: `TrackpadZoomMap` (Task 2), flutter_map `MapController`.
- Produces: nothing new.

**Conversion recipe (per widget that contains the FlutterMap):**

1. Add imports if missing:
```dart
import 'package:flutter_map/flutter_map.dart'; // usually already present
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
```

2. Convert the enclosing `ConsumerWidget` to `ConsumerStatefulWidget`:
```dart
// Before:
class Foo extends ConsumerWidget {
  const Foo({super.key, ...});
  @override
  Widget build(BuildContext context, WidgetRef ref) { ... }
}
// After:
class Foo extends ConsumerStatefulWidget {
  const Foo({super.key, ...});
  @override
  ConsumerState<Foo> createState() => _FooState();
}

class _FooState extends ConsumerState<Foo> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final ref = this.ref; // ConsumerState exposes `ref` directly; use it as-is
    ...
  }
}
```
Inside the new `build`, replace references to constructor params with `widget.<param>` and use `ref` directly (it is a member of `ConsumerState`).

3. Wrap the FlutterMap and supply the controller:
```dart
TrackpadZoomMap(
  controller: _mapController,
  child: FlutterMap(
    mapController: _mapController,
    options: ...,
    children: ...,
  ),
)
```

**Per-file notes:**

- `dive_locations_map.dart`: keeps its optional `final MapController? controller;` param. In the state, use an effective controller:
```dart
late final MapController _effectiveController =
    widget.controller ?? MapController();
```
  Pass `_effectiveController` to both `TrackpadZoomMap.controller` and `FlutterMap.mapController`.
- `site_detail_page.dart` `_SiteDetailContent`: has TWO `FlutterMap`s (inline preview + full-screen body). Create TWO controllers (`_previewController`, `_fullController`) and wrap each map with its own.
- `dive_center_detail_page.dart` `_MapSection`: same — TWO `FlutterMap`s, two controllers.
- `site_list_content.dart` `SiteListTile`: convert `SiteListTile` (the tile, not `_SiteListContentState`) to `ConsumerStatefulWidget`; one controller per tile.
- `trip_overview_tab.dart`: `TripOverviewTab` is a large tab. Convert it to `ConsumerStatefulWidget` holding one `_mapController`; only the one `FlutterMap` (around line 191) is wrapped.

- [ ] **Step 1: Apply the conversion + wrap recipe to all 6 files (8 maps).**

- [ ] **Step 2: Format + analyze**

Run: `dart format lib/`
Run: `flutter analyze`
Expected: No issues. (Watch for: leftover `WidgetRef ref` params in build signatures, missing `widget.` prefixes, unused imports.)

- [ ] **Step 3: Run affected widget tests**

Run: `flutter test test/features/trips/ test/features/dive_sites/ test/features/dive_centers/ test/features/dive_log/presentation/widgets/dive_locations_map_test.dart 2>/dev/null; true`
Expected: Affected widgets still build/pump; no new failures vs baseline.

- [ ] **Step 4: Commit**

```bash
git add lib/features/trips lib/features/dive_sites lib/features/dive_centers lib/features/dive_log
git commit -m "feat(maps): enable trackpad scroll zoom on converted stateless map sites"
```

---

### Task 6: Whole-project verification

**Files:** none (verification only).

- [ ] **Step 1: Format check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: Exit 0 (no changes).

- [ ] **Step 2: Whole-project analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Run the new/affected unit + widget tests**

Run: `flutter test test/core/ui/trackpad_zoom_test.dart test/features/maps/presentation/widgets/trackpad_zoom_map_test.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: All PASS.

- [ ] **Step 4: Document on-device verification (cannot be automated)**

Record in the PR description that the following require a real macOS trackpad (the Key risk from the spec):
- Two-finger vertical scroll zooms maps and the chart, cursor-anchored.
- No double-handling: the gesture does NOT also pan the map (confirms flutter_map's recognizer ignores trackpad pan-zoom). If panning is observed, apply the spec's fallback (disable `pinchMove` for trackpad / custom recognizer).
- Click-drag still pans; pinch still zooms; mouse-wheel still zooms.
- Touch (if a touchscreen Mac/iPad is available) still pinches/pans normally.

- [ ] **Step 5: Final commit (if any formatting fixups were needed)**

```bash
git add -A
git commit -m "chore: trackpad scroll zoom verification fixups" || true
```
