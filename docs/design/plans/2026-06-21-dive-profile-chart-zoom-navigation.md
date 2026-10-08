# Dive Profile Chart Zoom & Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive profile chart zoom anchor under the cursor/pinch (not the upper-left corner) and give it intuitive pan navigation, branched on the active pointer kind.

**Architecture:** Lift all zoom/pan/anchor math out of `_DiveProfileChartState` into a pure, immutable `ProfileChartViewport` value object plus two pure helpers (`chartFocalFraction`, `chartDragIntent`). The widget keeps one `_viewport` field, re-sources its visible-window computation from it, and routes each input (mouse wheel, trackpad pinch, touch pinch, mouse drag, touch scrub, double-tap, double-tap-hold) to a one-line viewport transform. Uniform 2-D zoom is kept; only the anchoring and navigation change.

**Tech Stack:** Flutter 3.x / Dart 3, `fl_chart ^1.1.1` (zoom/pan stays hand-rolled on top of it), Riverpod, `flutter_test`.

## Global Constraints

- **Library floor:** `fl_chart ^1.1.1` — do not change the dependency or adopt fl_chart's built-in transform.
- **Zoom model:** uniform 2-D (one scalar scales time and depth together); zoom limits `[1.0, 10.0]`.
- **Anchoring:** zoom anchors under the cursor (mouse/trackpad/wheel) or pinch focal point (touch), never the corner.
- **Pointer routing:** branch on the active `PointerDeviceKind`, not `defaultTargetPlatform`. One-finger touch drag stays a tooltip scrub; mouse drag pans.
- **Immutability always** (CLAUDE.md): `ProfileChartViewport` is `@immutable`; every gesture returns a new instance, never mutates.
- **State scope:** zoom/pan stays local widget state in `_DiveProfileChartState`; no new Riverpod provider; per-instance and ephemeral, as today.
- **No new user-facing strings:** reuse the existing `diveLog_profile_zoomHint` l10n key. (If any new string were added it would require translation into all 10 non-en locales — this plan adds none.)
- **No emojis, no `print`/console output, no hardcoded secrets.** Proper null handling.
- **Formatting/analysis:** `dart format .` must produce no changes; `flutter analyze` (whole project, not piped) must be clean — run both before every commit.
- **Tests:** run the specific test file(s) for the task, not broad directories (avoids Bash timeouts).
- **Branch:** all work and commits on `worktree-profile-chart-zoom-nav`. Per-task commits are pre-authorized by plan approval + subagent-driven execution. No `Co-Authored-By` trailer.

---

### Task 1: `ProfileChartViewport` value object

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ProfileChartViewport` with `const ProfileChartViewport({double zoom = 1, double offsetX = 0, double offsetY = 0})`
  - `static const double minZoom = 1.0, maxZoom = 10.0;`
  - `static const ProfileChartViewport reset = ProfileChartViewport();`
  - `bool get isZoomed;` `double get visibleWidth;` `double get visibleHeight;`
  - `ProfileChartViewport zoomedAt(double focalX, double focalY, double factor)`
  - `ProfileChartViewport pannedBy(double dx, double dy)`
  - fields `double zoom, offsetX, offsetY`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_chart_viewport.dart';

// Data fraction (0..1 of total range) currently under a focal point that sits
// at `focal` (0..1) of the visible window.
double _dataUnderFocal(double offset, double zoom, double focal) =>
    offset + focal / zoom;

void main() {
  group('ProfileChartViewport', () {
    test('reset is unzoomed at the origin', () {
      const vp = ProfileChartViewport.reset;
      expect(vp.zoom, 1.0);
      expect(vp.offsetX, 0.0);
      expect(vp.offsetY, 0.0);
      expect(vp.isZoomed, isFalse);
      expect(vp.visibleWidth, 1.0);
      expect(vp.visibleHeight, 1.0);
    });

    test('zoomedAt center keeps the center centered', () {
      final vp = ProfileChartViewport.reset.zoomedAt(0.5, 0.5, 2);
      expect(vp.zoom, 2.0);
      expect(vp.offsetX, closeTo(0.25, 1e-9));
      expect(vp.offsetY, closeTo(0.25, 1e-9));
      expect(vp.isZoomed, isTrue);
    });

    test('zoomedAt top-left pins the top-left corner', () {
      final vp = ProfileChartViewport.reset.zoomedAt(0, 0, 2);
      expect(vp.offsetX, closeTo(0.0, 1e-9));
      expect(vp.offsetY, closeTo(0.0, 1e-9));
    });

    test('zoomedAt bottom-right pins the bottom-right corner', () {
      final vp = ProfileChartViewport.reset.zoomedAt(1, 1, 2);
      expect(vp.offsetX, closeTo(0.5, 1e-9));
      expect(vp.offsetY, closeTo(0.5, 1e-9));
    });

    test('anchor invariant: the data point under the focal stays fixed', () {
      const cases = [
        [0.3, 0.7, 2.0],
        [0.2, 0.5, 3.0],
        [0.6, 0.4, 1.5],
      ];
      for (final c in cases) {
        const start = ProfileChartViewport(zoom: 2, offsetX: 0.25, offsetY: 0.25);
        final before = _dataUnderFocal(start.offsetX, start.zoom, c[0]);
        final after = start.zoomedAt(c[0], c[1], c[2]);
        final now = _dataUnderFocal(after.offsetX, after.zoom, c[0]);
        expect(now, closeTo(before, 1e-9), reason: 'case $c');
      }
    });

    test('pannedBy clamps to [0, 1 - 1/zoom]', () {
      const vp = ProfileChartViewport(zoom: 2, offsetX: 0.25, offsetY: 0.25);
      final left = vp.pannedBy(-1, -1);
      expect(left.offsetX, 0.0);
      expect(left.offsetY, 0.0);
      final right = vp.pannedBy(1, 1);
      expect(right.offsetX, closeTo(0.5, 1e-9)); // maxOff = 1 - 1/2
      expect(right.offsetY, closeTo(0.5, 1e-9));
    });

    test('zoom clamps to [minZoom, maxZoom] and is a no-op at the rail', () {
      // Zooming out from reset cannot go below 1.0 -> unchanged instance.
      final out = ProfileChartViewport.reset.zoomedAt(0.5, 0.5, 0.5);
      expect(out.zoom, 1.0);
      expect(out.offsetX, 0.0);
      // At max zoom, zooming further in is a no-op.
      const atMax = ProfileChartViewport(zoom: 10, offsetX: 0.4, offsetY: 0.4);
      final stillMax = atMax.zoomedAt(0.5, 0.5, 2);
      expect(stillMax.zoom, 10.0);
      expect(stillMax.offsetX, 0.4);
    });

    test('zoom in then out at the same focal round-trips to the origin', () {
      final there = ProfileChartViewport.reset.zoomedAt(0.3, 0.7, 2);
      final back = there.zoomedAt(0.3, 0.7, 0.5);
      expect(back.zoom, closeTo(1.0, 1e-9));
      expect(back.offsetX, closeTo(0.0, 1e-9));
      expect(back.offsetY, closeTo(0.0, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'profile_chart_viewport.dart'` / `ProfileChartViewport` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Immutable description of the dive profile chart's visible window, expressed
/// as normalized fractions [0,1] of the total data range. Resolution- and
/// data-independent, so the anchor math is unit-testable with plain numbers.
///
/// `offsetX`/`offsetY` are the normalized left/top edges of the visible window
/// (`offsetY == 0` is the surface). The window spans `1/zoom` of each axis, so
/// both offsets are valid in `[0, 1 - 1/zoom]`.
@immutable
class ProfileChartViewport {
  final double zoom; // >= 1.0
  final double offsetX;
  final double offsetY;

  const ProfileChartViewport({
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  static const double minZoom = 1.0;
  static const double maxZoom = 10.0;
  static const ProfileChartViewport reset = ProfileChartViewport();

  bool get isZoomed => zoom > 1.0;
  double get visibleWidth => 1.0 / zoom;
  double get visibleHeight => 1.0 / zoom;

  /// Zoom by [factor] (>1 = in, <1 = out) keeping the data point under the
  /// focal point fixed. [focalX]/[focalY] are fractions (0..1) of the visible
  /// plot area under the cursor/pinch (0 = left/top edge).
  ProfileChartViewport zoomedAt(double focalX, double focalY, double factor) {
    final newZoom = (zoom * factor).clamp(minZoom, maxZoom);
    if (newZoom == zoom) return this;
    final anchorX = offsetX + focalX / zoom; // data fraction under focus, before
    final anchorY = offsetY + focalY / zoom;
    return ProfileChartViewport(
      zoom: newZoom,
      offsetX: anchorX - focalX / newZoom, // keep it under focus, after
      offsetY: anchorY - focalY / newZoom,
    )._clamped();
  }

  /// Pan by a normalized delta (fractions of the total range).
  ProfileChartViewport pannedBy(double dx, double dy) => ProfileChartViewport(
    zoom: zoom,
    offsetX: offsetX + dx,
    offsetY: offsetY + dy,
  )._clamped();

  ProfileChartViewport _clamped() {
    final maxOff = 1.0 - 1.0 / zoom;
    return ProfileChartViewport(
      zoom: zoom,
      offsetX: offsetX.clamp(0.0, maxOff),
      offsetY: offsetY.clamp(0.0, maxOff),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
git commit -m "feat: add ProfileChartViewport for cursor-anchored profile zoom"
```
Expected: format makes no further changes; analyze reports no issues.

---

### Task 2: `chartFocalFraction` plot-rect helper

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`

**Interfaces:**
- Consumes: `Offset`, `Size` (from `package:flutter/widgets.dart`).
- Produces: `({double fx, double fy}) chartFocalFraction(Offset localPos, Size box, {required double left, required double right, required double top, required double bottom})` — maps a gesture's `localPosition` (in the full widget box) to a fraction (0..1, clamped) of the inner plot rect.

- [ ] **Step 1: Write the failing test**

Append inside `main()` in `profile_chart_viewport_test.dart`:

```dart
  group('chartFocalFraction', () {
    const box = Size(200, 100);
    const insets = (left: 40.0, right: 10.0, top: 0.0, bottom: 24.0);
    // plotW = 200-40-10 = 150 ; plotH = 100-0-24 = 76

    test('left/top gutter maps to 0', () {
      final f = chartFocalFraction(const Offset(40, 0), box,
          left: insets.left, right: insets.right, top: insets.top, bottom: insets.bottom);
      expect(f.fx, closeTo(0.0, 1e-9));
      expect(f.fy, closeTo(0.0, 1e-9));
    });

    test('right/bottom plot edge maps to 1', () {
      final f = chartFocalFraction(const Offset(190, 76), box,
          left: insets.left, right: insets.right, top: insets.top, bottom: insets.bottom);
      expect(f.fx, closeTo(1.0, 1e-9));
      expect(f.fy, closeTo(1.0, 1e-9));
    });

    test('mid plot maps to the expected fraction', () {
      final f = chartFocalFraction(const Offset(115, 38), box,
          left: insets.left, right: insets.right, top: insets.top, bottom: insets.bottom);
      expect(f.fx, closeTo(0.5, 1e-9)); // (115-40)/150
      expect(f.fy, closeTo(0.5, 1e-9)); // (38-0)/76
    });

    test('positions outside the plot clamp to [0,1]', () {
      final lo = chartFocalFraction(const Offset(0, -50), box,
          left: insets.left, right: insets.right, top: insets.top, bottom: insets.bottom);
      expect(lo.fx, 0.0);
      expect(lo.fy, 0.0);
      final hi = chartFocalFraction(const Offset(500, 500), box,
          left: insets.left, right: insets.right, top: insets.top, bottom: insets.bottom);
      expect(hi.fx, 1.0);
      expect(hi.fy, 1.0);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: FAIL — `The function 'chartFocalFraction' isn't defined`.

- [ ] **Step 3: Write the minimal implementation**

Append to `profile_chart_viewport.dart`:

```dart
/// Maps a gesture's [localPos] (in the full widget [box]) to a fraction
/// (0..1, clamped) of the inner plot rect, given the reserved axis gutters.
/// fl_chart reserves [left]/[right]/[top]/[bottom] for axis names + tick
/// labels (+ the gas strip), so the data window only fills the inner rect.
({double fx, double fy}) chartFocalFraction(
  Offset localPos,
  Size box, {
  required double left,
  required double right,
  required double top,
  required double bottom,
}) {
  final plotW = (box.width - left - right).clamp(1.0, double.infinity);
  final plotH = (box.height - top - bottom).clamp(1.0, double.infinity);
  return (
    fx: ((localPos.dx - left) / plotW).clamp(0.0, 1.0),
    fy: ((localPos.dy - top) / plotH).clamp(0.0, 1.0),
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
git commit -m "feat: add chartFocalFraction plot-rect focal mapping"
```

---

### Task 3: `chartDragIntent` pointer-kind router

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`

**Interfaces:**
- Consumes: `PointerDeviceKind` (from `package:flutter/gestures.dart`).
- Produces:
  - `enum ChartDragIntent { pan, scrub, zoomPan, none }`
  - `ChartDragIntent chartDragIntent({required PointerDeviceKind kind, required int pointerCount, required bool doubleTapHold})`

- [ ] **Step 1: Write the failing test**

Append inside `main()`:

```dart
  group('chartDragIntent', () {
    test('two or more pointers always zoom+pan', () {
      for (final k in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        expect(
          chartDragIntent(kind: k, pointerCount: 2, doubleTapHold: false),
          ChartDragIntent.zoomPan,
        );
      }
    });

    test('single mouse/trackpad pointer pans', () {
      expect(
        chartDragIntent(kind: PointerDeviceKind.mouse, pointerCount: 1, doubleTapHold: false),
        ChartDragIntent.pan,
      );
      expect(
        chartDragIntent(kind: PointerDeviceKind.trackpad, pointerCount: 1, doubleTapHold: false),
        ChartDragIntent.pan,
      );
    });

    test('single touch pointer scrubs', () {
      expect(
        chartDragIntent(kind: PointerDeviceKind.touch, pointerCount: 1, doubleTapHold: false),
        ChartDragIntent.scrub,
      );
    });

    test('single touch pointer pans during double-tap-hold', () {
      expect(
        chartDragIntent(kind: PointerDeviceKind.touch, pointerCount: 1, doubleTapHold: true),
        ChartDragIntent.pan,
      );
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: FAIL — `chartDragIntent` / `ChartDragIntent` not defined.

- [ ] **Step 3: Write the minimal implementation**

Add the import at the top of `profile_chart_viewport.dart` (below the existing `widgets.dart` import):

```dart
import 'package:flutter/gestures.dart';
```

Append:

```dart
/// What a drag/scale event should do on the profile chart.
enum ChartDragIntent { pan, scrub, zoomPan, none }

/// Decides the meaning of an in-progress gesture from the active pointer kind,
/// the pointer count, and whether a double-tap-hold is active. Keying off the
/// pointer kind (not the platform) is what lets one-finger touch keep scrubbing
/// while a mouse drag pans.
ChartDragIntent chartDragIntent({
  required PointerDeviceKind kind,
  required int pointerCount,
  required bool doubleTapHold,
}) {
  if (pointerCount >= 2) return ChartDragIntent.zoomPan;
  if (doubleTapHold) return ChartDragIntent.pan;
  return kind == PointerDeviceKind.touch
      ? ChartDragIntent.scrub
      : ChartDragIntent.pan;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart
git commit -m "feat: add chartDragIntent pointer-kind drag routing"
```

---

### Task 4: Wire the viewport into the chart; anchor all existing zoom channels

This is an atomic refactor — it replaces the three zoom/pan doubles with one `_viewport` everywhere they are referenced, so the file only compiles once every reference is updated. In the process, the wheel anchors to the cursor, touch pinch anchors to the focal point, buttons zoom about center, and double-tap zooms about the tap point.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
  (state `:457-469`, `_resetZoom` `:507-513`, `_zoomIn/_zoomOut/_clampPanOffsets` `:893-912`, legend args `:1027-1029`, hint `:1052-1063`, gestures `:1082-1153`, window `:1239-1246`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `ProfileChartViewport`, `chartFocalFraction` (Tasks 1-2).
- Produces (private to the state, relied on by Tasks 5-7):
  - field `ProfileChartViewport _viewport`
  - field `ProfileChartViewport _gestureStartViewport`
  - field `Offset _startFocalPoint`
  - field `Offset _lastTapDownLocal`
  - method `({double left, double top, double right, double bottom}) _plotInsets(double availableWidth, UnitFormatter units)`

- [ ] **Step 1: Write the failing widget tests**

Append to `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart` (reuses the existing `_buildChart` and `_makeProfile` helpers in that file). Add these imports at the top if missing: `import 'package:flutter/gestures.dart';`.

```dart
  // Reads the primary fl_chart LineChartData (the depth/time plot is first).
  LineChartData _primaryChartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  group('zoom anchoring', () {
    testWidgets('mouse wheel up zooms in WITHOUT pinning the left edge to 0',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final before = _primaryChartData(tester);
      expect(before.minX, 0.0); // at zoom 1 the window starts at t=0

      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);
      // Cursor in the right third of the plot.
      final cursor = topLeft + Offset(size.width * 0.75, size.height * 0.5);

      await tester.sendEventToBinding(
        PointerScrollEvent(position: cursor, scrollDelta: const Offset(0, -100)),
      );
      await tester.pump();

      final after = _primaryChartData(tester);
      // Zoomed in: visible time range shrank.
      expect(after.maxX - after.minX, lessThan(before.maxX - before.minX));
      // Anchored toward the cursor, not the corner: left edge moved off 0.
      expect(after.minX, greaterThan(0.0));
    });

    testWidgets('mouse wheel down at max-out keeps the full window',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 100)),
      );
      await tester.pump();

      final after = _primaryChartData(tester);
      expect(after.minX, 0.0); // cannot zoom out past 1.0
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "zoom anchoring"`
Expected: FAIL — the first test fails on `expect(after.minX, greaterThan(0.0))` because today's wheel zoom keeps `minX == 0` (upper-left anchoring).

- [ ] **Step 3: Add the import and replace the zoom/pan state fields**

At the top of `dive_profile_chart.dart`, add (with the other local widget imports):

```dart
import 'profile_chart_viewport.dart';
```

Replace `dive_profile_chart.dart:457-469` (the `// Zoom/pan state` … `_maxZoom` block) with:

```dart
  // Zoom/pan state — see profile_chart_viewport.dart.
  ProfileChartViewport _viewport = ProfileChartViewport.reset;

  // Snapshot of the viewport at the start of a continuous gesture; continuous
  // gestures report cumulative scale/pan, so we apply them against this.
  ProfileChartViewport _gestureStartViewport = ProfileChartViewport.reset;
  Offset _startFocalPoint = Offset.zero;

  // Local position of the most recent (double-)tap, for tap-anchored zoom.
  Offset _lastTapDownLocal = Offset.zero;
```

- [ ] **Step 4: Add the `_plotInsets` helper**

Insert this method just above `_zoomIn()` (i.e. just before `dive_profile_chart.dart:893`). It mirrors the existing plot-bounds math at `:2265-2270` and the bottom reservation at `:1379-1382`:

```dart
  /// The plot-rect insets (reserved axis gutters) for the current build, so a
  /// gesture's local position can be mapped to a plot-area fraction. Mirrors
  /// the axis reservations used for the gas-strip overlay (left/right at
  /// :2265-2270, bottom at :1379-1382). Top has no titles, so its inset is 0.
  ({double left, double top, double right, double bottom}) _plotInsets(
    double availableWidth,
    UnitFormatter units,
  ) {
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric = preferredMetric != null
        ? _getEffectiveRightAxisMetric(preferredMetric)
        : null;
    final rightAxisRange = effectiveRightAxisMetric != null
        ? _getMetricRange(effectiveRightAxisMetric, units)
        : null;
    final hasRightAxisName =
        effectiveRightAxisMetric != null && rightAxisRange != null;

    return (
      left: DiveProfileChart._leftRightAxisNameSize +
          DiveProfileChart.leftAxisSize(availableWidth),
      top: 0,
      right: (hasRightAxisName ? DiveProfileChart._leftRightAxisNameSize : 0) +
          DiveProfileChart.rightAxisSize(availableWidth),
      bottom: DiveProfileChart._bottomAxisNameSize +
          (_hasGasStrip
              ? DiveProfileChart._bottomTickReservedSize +
                  DiveProfileChart.gasTimelineHeight
              : DiveProfileChart._bottomTickReservedSize),
    );
  }
```

- [ ] **Step 5: Replace `_resetZoom`, `_zoomIn`, `_zoomOut`; delete `_clampPanOffsets`**

Replace `dive_profile_chart.dart:507-513` (`_resetZoom`) with:

```dart
  void _resetZoom() {
    setState(() => _viewport = ProfileChartViewport.reset);
  }
```

Replace `dive_profile_chart.dart:893-912` (`_zoomIn`, `_zoomOut`, and the whole `_clampPanOffsets` method) with:

```dart
  // Buttons have no cursor, so they zoom about the visible center.
  void _zoomIn() {
    setState(() => _viewport = _viewport.zoomedAt(0.5, 0.5, 1.5));
  }

  void _zoomOut() {
    setState(() => _viewport = _viewport.zoomedAt(0.5, 0.5, 1 / 1.5));
  }
```

- [ ] **Step 6: Re-source the legend zoom-control args**

Replace `dive_profile_chart.dart:1027-1029` (the `zoomLevel`/`minZoom`/`maxZoom` args) with:

```dart
              zoomLevel: _viewport.zoom,
              minZoom: ProfileChartViewport.minZoom,
              maxZoom: ProfileChartViewport.maxZoom,
```

- [ ] **Step 7: Re-source the zoom hint**

Replace `dive_profile_chart.dart:1052` (`if (_zoomLevel > 1.0)`) with `if (_viewport.isZoomed)` and `dive_profile_chart.dart:1057` (`_zoomLevel.toStringAsFixed(1)`) with `_viewport.zoom.toStringAsFixed(1)`.

- [ ] **Step 8: Rework the gesture handlers**

Replace `dive_profile_chart.dart:1082-1136` (the `onScaleStart`, `onScaleUpdate`, and `onDoubleTap` handlers) with:

```dart
            onScaleStart: (details) {
              _gestureStartViewport = _viewport;
              _startFocalPoint = details.localFocalPoint;
            },
            onScaleUpdate: (details) {
              // Single-pointer drags (mouse pan / touch scrub) are wired in a
              // later task; for now only multi-touch pinch+pan acts here.
              if (details.pointerCount < 2) return;

              setState(() {
                final box = constraints.biggest;
                final insets = _plotInsets(constraints.maxWidth, units);
                final plotW = (box.width - insets.left - insets.right)
                    .clamp(1.0, double.infinity);
                final plotH = (box.height - insets.top - insets.bottom)
                    .clamp(1.0, double.infinity);
                final focal = chartFocalFraction(
                  _startFocalPoint,
                  box,
                  left: insets.left,
                  right: insets.right,
                  top: insets.top,
                  bottom: insets.bottom,
                );
                // scale is cumulative from gesture start -> apply to snapshot.
                var vp = _gestureStartViewport.zoomedAt(
                  focal.fx,
                  focal.fy,
                  details.scale,
                );
                final panPx = details.localFocalPoint - _startFocalPoint;
                vp = vp.pannedBy(
                  -panPx.dx / plotW / vp.zoom,
                  -panPx.dy / plotH / vp.zoom,
                );
                _viewport = vp;
              });
            },
            onDoubleTapDown: (details) {
              _lastTapDownLocal = details.localPosition;
            },
            onDoubleTap: () {
              setState(() {
                if (_viewport.isZoomed) {
                  _viewport = ProfileChartViewport.reset;
                } else {
                  final box = constraints.biggest;
                  final insets = _plotInsets(constraints.maxWidth, units);
                  final focal = chartFocalFraction(
                    _lastTapDownLocal,
                    box,
                    left: insets.left,
                    right: insets.right,
                    top: insets.top,
                    bottom: insets.bottom,
                  );
                  _viewport = _viewport.zoomedAt(focal.fx, focal.fy, 2.0);
                }
              });
            },
```

- [ ] **Step 9: Rework the mouse-wheel handler**

Replace `dive_profile_chart.dart:1138-1153` (the `onPointerSignal` body) with:

```dart
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  setState(() {
                    final box = constraints.biggest;
                    final insets = _plotInsets(constraints.maxWidth, units);
                    final focal = chartFocalFraction(
                      event.localPosition,
                      box,
                      left: insets.left,
                      right: insets.right,
                      top: insets.top,
                      bottom: insets.bottom,
                    );
                    final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
                    _viewport = _viewport.zoomedAt(focal.fx, focal.fy, factor);
                  });
                }
              },
```

- [ ] **Step 10: Re-source the visible-window computation**

Replace `dive_profile_chart.dart:1239-1246` (the `visibleRangeX` … `visibleMaxDepth` block) with:

```dart
    // Apply zoom and pan to calculate visible bounds (see ProfileChartViewport).
    final visibleRangeX = totalMaxTime * _viewport.visibleWidth;
    final visibleRangeY = totalMaxDepth * _viewport.visibleHeight;

    final visibleMinX = _viewport.offsetX * totalMaxTime;
    final visibleMaxX = visibleMinX + visibleRangeX;

    final visibleMinDepth = _viewport.offsetY * totalMaxDepth;
    final visibleMaxDepth = visibleMinDepth + visibleRangeY;
```

- [ ] **Step 11: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
Expected: PASS — the new `zoom anchoring` group passes and all pre-existing chart tests stay green.

- [ ] **Step 12: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat: anchor dive profile zoom to cursor/pinch via ProfileChartViewport"
```

---

### Task 5: Trackpad pinch zoom-to-cursor + two-finger-scroll pan; pointer-kind tracking

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (state fields near `:457`; `initState` `:476`; the `Listener` at `:1137`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `_viewport`, `_gestureStartViewport`, `_plotInsets`, `chartFocalFraction`, `ProfileChartViewport`.
- Produces (relied on by Task 6): field `PointerDeviceKind _activePointerKind`; field `Offset _trackpadAnchor`.

- [ ] **Step 1: Write the failing widget test**

Append to `dive_profile_chart_test.dart`:

```dart
  group('trackpad interaction', () {
    testWidgets('trackpad pinch zooms in anchored off-center (not at 0)',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);
      final anchor = topLeft + Offset(size.width * 0.7, size.height * 0.5);

      final before = tester.widget<LineChart>(chart).data;
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(anchor));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(anchor, scale: 2.0),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      final after = tester.widget<LineChart>(chart).data;
      expect(after.maxX - after.minX, lessThan(before.maxX - before.minX));
      expect(after.minX, greaterThan(0.0)); // anchored toward the cursor
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "trackpad interaction"`
Expected: FAIL — `after.minX` stays `0.0` (no trackpad pan-zoom handler yet), so `greaterThan(0.0)` fails.

- [ ] **Step 3: Add pointer-kind + trackpad-anchor state fields**

Immediately below the `_lastTapDownLocal` field added in Task 4, add:

```dart
  // Active pointer kind, corrected on the first real pointer event. Chooses
  // pan-vs-scrub for single-pointer drags and is set by trackpad gestures.
  PointerDeviceKind _activePointerKind =
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)
      ? PointerDeviceKind.touch
      : PointerDeviceKind.mouse;

  // Cursor position at the start of a trackpad pan/zoom gesture.
  Offset _trackpadAnchor = Offset.zero;
```

If `defaultTargetPlatform` is not resolved, ensure `import 'package:flutter/foundation.dart';` is present at the top of the file (it usually already is for `kDebugMode`/`Equatable`-adjacent code; add it if `flutter analyze` reports it undefined).

- [ ] **Step 4: Add the trackpad handlers + kind tracking to the `Listener`**

In the `Listener` at `dive_profile_chart.dart:1137`, add these handlers alongside the existing `onPointerSignal` (keep `onPointerSignal` as reworked in Task 4):

```dart
              onPointerDown: (event) => _activePointerKind = event.kind,
              onPointerPanZoomStart: (event) {
                _activePointerKind = PointerDeviceKind.trackpad;
                _gestureStartViewport = _viewport;
                _trackpadAnchor = event.localPosition;
              },
              onPointerPanZoomUpdate: (event) {
                setState(() {
                  final box = constraints.biggest;
                  final insets = _plotInsets(constraints.maxWidth, units);
                  final plotW = (box.width - insets.left - insets.right)
                      .clamp(1.0, double.infinity);
                  final plotH = (box.height - insets.top - insets.bottom)
                      .clamp(1.0, double.infinity);
                  final focal = chartFocalFraction(
                    _trackpadAnchor,
                    box,
                    left: insets.left,
                    right: insets.right,
                    top: insets.top,
                    bottom: insets.bottom,
                  );
                  // scale and localPan are cumulative from the gesture start.
                  var vp = _gestureStartViewport.zoomedAt(
                    focal.fx,
                    focal.fy,
                    event.scale,
                  );
                  vp = vp.pannedBy(
                    -event.localPan.dx / plotW / vp.zoom,
                    -event.localPan.dy / plotH / vp.zoom,
                  );
                  _viewport = vp;
                });
              },
```

Note: the two-finger-scroll pan sign (`-event.localPan`) is the natural-scroll convention; if hardware testing shows it inverted, flip the sign — this is the spec's "pan sign finalized under TDD".

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "trackpad interaction"`
Expected: PASS. Then run the full file to confirm no regressions: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat: trackpad pinch zoom-to-cursor and two-finger pan on profile chart"
```

---

### Task 6: Desktop hover-select + mouse click-drag pan (touch one-finger still scrubs)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (state field near `:457`; `onScaleUpdate` single-pointer branch; the `Listener`/its child at `:1137-1162`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `chartDragIntent`, `ChartDragIntent`, `_activePointerKind`, `_viewport`, `_plotInsets`, `chartFocalFraction`, `widget.onPointSelected`, `widget.profile`.
- Produces (relied on by Task 7): field `bool _doubleTapHold`; method `int? _hoverIndex(Offset, Size, insets)`.

- [ ] **Step 1: Write the failing widget tests**

Append to `dive_profile_chart_test.dart`:

```dart
  group('desktop pan and hover', () {
    testWidgets('mouse click-drag pans a zoomed-in chart', (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      // Zoom in first (about center) via two wheel steps.
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      // Drag left with the mouse -> window should move right (minX increases).
      final gesture =
          await tester.startGesture(center, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await tester.pump();

      final panned = tester.widget<LineChart>(chart).data;
      expect(panned.minX, greaterThan(zoomed.minX));
    });

    testWidgets('touch one-finger drag does NOT pan (still scrubs)',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      final gesture =
          await tester.startGesture(center, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await tester.pump();

      final after = tester.widget<LineChart>(chart).data;
      expect(after.minX, zoomed.minX); // unchanged: one finger scrubs, no pan
    });

    testWidgets('mouse hover selects the nearest sample', (tester) async {
      int? selected;
      await tester.pumpWidget(
        _buildChart(
          profile: _makeProfile(points: 20),
          onPointSelected: (i) => selected = i,
        ),
      );
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(topLeft + Offset(size.width * 0.5, size.height * 0.5)),
      );
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected, inInclusiveRange(0, 19));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "desktop pan and hover"`
Expected: FAIL — mouse drag does not pan yet (`panned.minX` equals `zoomed.minX`), and hover does not call `onPointSelected`.

- [ ] **Step 3: Add the `_doubleTapHold` flag and the hover-index helper**

Below the `_trackpadAnchor` field (Task 5), add:

```dart
  // True between a double-tap-down and the gesture's end; lets a held-finger
  // drag pan instead of scrub. Toggled in a later task; false here.
  bool _doubleTapHold = false;

  // Index of the last sample reported via hover, to de-dupe onPointSelected.
  int? _lastHoverIndex;
```

Add this helper next to `_plotInsets`:

```dart
  /// Nearest profile sample index under a hover at [localPos], or null if the
  /// profile is empty. Maps the cursor X through the current viewport to a
  /// timestamp, then finds the closest sample.
  int? _hoverIndex(
    Offset localPos,
    Size box,
    ({double left, double top, double right, double bottom}) insets,
  ) {
    if (widget.profile.isEmpty) return null;
    final focal = chartFocalFraction(
      localPos,
      box,
      left: insets.left,
      right: insets.right,
      top: insets.top,
      bottom: insets.bottom,
    );
    final totalMaxTime =
        widget.profile.map((p) => p.timestamp).reduce(math.max).toDouble();
    final t = (_viewport.offsetX + focal.fx * _viewport.visibleWidth) *
        totalMaxTime;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.profile.length; i++) {
      final d = (widget.profile[i].timestamp - t).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }
```

(`math` is already imported in this file as `import 'dart:math' as math;` — it is used at `:1227`.)

- [ ] **Step 4: Route the single-pointer drag by intent**

Replace the early-return guard in `onScaleUpdate` (the `if (details.pointerCount < 2) return;` line added in Task 4) with:

```dart
              if (details.pointerCount < 2) {
                final intent = chartDragIntent(
                  kind: _activePointerKind,
                  pointerCount: details.pointerCount,
                  doubleTapHold: _doubleTapHold,
                );
                if (intent != ChartDragIntent.pan) return; // touch scrub
                setState(() {
                  final box = constraints.biggest;
                  final insets = _plotInsets(constraints.maxWidth, units);
                  final plotW = (box.width - insets.left - insets.right)
                      .clamp(1.0, double.infinity);
                  final plotH = (box.height - insets.top - insets.bottom)
                      .clamp(1.0, double.infinity);
                  final d = details.focalPointDelta;
                  _viewport = _viewport.pannedBy(
                    -d.dx / plotW / _viewport.zoom,
                    -d.dy / plotH / _viewport.zoom,
                  );
                });
                return;
              }
```

- [ ] **Step 5: Add hover-select + exit-clear**

In the `Listener` (Task 5), add `onPointerHover`:

```dart
              onPointerHover: (event) {
                _activePointerKind = PointerDeviceKind.mouse;
                final idx = _hoverIndex(
                  event.localPosition,
                  constraints.biggest,
                  _plotInsets(constraints.maxWidth, units),
                );
                if (idx != _lastHoverIndex) {
                  _lastHoverIndex = idx;
                  widget.onPointSelected?.call(idx);
                }
              },
```

Wrap the `Listener`'s `child:` (the `_buildChart(...)` call at `:1154`) in a `MouseRegion` so the selection clears when the cursor leaves:

```dart
              child: MouseRegion(
                onExit: (_) {
                  if (_lastHoverIndex != null) {
                    _lastHoverIndex = null;
                    widget.onPointSelected?.call(null);
                  }
                },
                child: _buildChart(
                  context,
                  units,
                  availableWidth: constraints.maxWidth,
                  hasTemperatureData: hasTemperatureData,
                  hasPressureData: hasPressureData,
                  hasHeartRateData: hasHeartRateData,
                ),
              ),
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "desktop pan and hover"`
Expected: PASS. Then run the whole file to confirm no regressions: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat: desktop hover select and click-drag pan on profile chart"
```

---

### Task 7: Double-tap-and-hold to pan (touch)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (state field near `:457`; `dispose`; `onDoubleTapDown`/`onDoubleTap`; add `onScaleEnd`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `_doubleTapHold` (Task 6), `_viewport`, `_plotInsets`.
- Produces: nothing new for later tasks (final task).

- [ ] **Step 1: Write the failing widget test**

Append to `dive_profile_chart_test.dart` (add `import 'dart:ui';` only if `PointerDeviceKind` needs it — it comes from `package:flutter/gestures.dart`, already imported in Task 4):

```dart
  group('double-tap-hold pan', () {
    testWidgets('double-tap then hold-drag pans a zoomed-in chart',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      // Zoom in so there is room to pan.
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      // First tap (quick) then a second touch that is held and dragged.
      await tester.tapAt(center, kind: PointerDeviceKind.touch);
      final hold =
          await tester.startGesture(center, kind: PointerDeviceKind.touch);
      await hold.moveBy(const Offset(-60, 0));
      await hold.up();
      await tester.pump();

      final panned = tester.widget<LineChart>(chart).data;
      expect(panned.minX, greaterThan(zoomed.minX));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "double-tap-hold pan"`
Expected: FAIL — `_doubleTapHold` never becomes true, so the held touch drag scrubs and `panned.minX` equals `zoomed.minX`.

- [ ] **Step 3: Add the timer import and field**

Ensure `import 'dart:async';` is present at the top of `dive_profile_chart.dart` (add it with the other `dart:` imports if missing). Below the `_lastHoverIndex` field (Task 6), add:

```dart
  // Fallback that clears _doubleTapHold if a double-tap-down is not followed by
  // a drag (so a later normal drag is not misrouted to pan).
  Timer? _doubleTapHoldTimer;
```

- [ ] **Step 4: Set/clear the hold flag**

Replace the `onDoubleTapDown` handler (added in Task 4) with:

```dart
            onDoubleTapDown: (details) {
              _lastTapDownLocal = details.localPosition;
              _doubleTapHold = true;
              _doubleTapHoldTimer?.cancel();
              _doubleTapHoldTimer = Timer(
                const Duration(milliseconds: 400),
                () => _doubleTapHold = false,
              );
            },
```

At the very start of the `onDoubleTap` handler body (added in Task 4), before the `setState`, add:

```dart
              _doubleTapHold = false;
              _doubleTapHoldTimer?.cancel();
```

Add an `onScaleEnd` handler to the `GestureDetector` (next to `onScaleStart`/`onScaleUpdate`):

```dart
            onScaleEnd: (details) {
              _doubleTapHold = false;
              _doubleTapHoldTimer?.cancel();
            },
```

- [ ] **Step 5: Cancel the timer in `dispose`**

Find the state's `dispose()` (if none exists, add one overriding `State.dispose`) and cancel the timer before `super.dispose()`:

```dart
  @override
  void dispose() {
    _doubleTapHoldTimer?.cancel();
    super.dispose();
  }
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --name "double-tap-hold pan"`
Expected: PASS. If the synthetic double-tap timing does not trip the recognizer, adjust the gesture timing in the test (insert `await tester.pump(const Duration(milliseconds: 50));` between the tap and the hold) — the spec sanctions finalizing this gesture's thresholds under TDD. Then run the whole file: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat: double-tap-hold to pan on profile chart (touch)"
```

---

## Final verification (after Task 7)

- [ ] Run the full dive-log widget suite to confirm no regressions across the chart, panel, and detail page:

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart \
  test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart \
  test/features/dive_log/presentation/pages/dive_detail_page_test.dart
```
Expected: all PASS.

- [ ] Confirm `dart format .` reports no changes and `flutter analyze` is clean.
- [ ] Manual device check (not automated): on macOS/desktop verify wheel + trackpad pinch zoom to the cursor and click-drag pans; on a phone verify one-finger scrub, two-finger pinch+pan, and double-tap-hold pan. (The two-finger-scroll and double-tap-hold pan **signs/thresholds** are the spec's TDD-finalized items — adjust if they feel inverted on hardware.)

## Notes on coverage vs. the spec

- Spec "Component 1 — ProfileChartViewport" → Task 1. "Component 2 — pure helpers" → Tasks 2-3. "Component 3 — input routing" → Tasks 4-7. "Component 4 — coexistence/edges" → Task 4 (buttons-about-center, reset, hint, plot-rect focal correction) + Task 6 (hover/scrub coexistence) + Task 7 (double-tap state machine).
- The spec's desktop hover behavior is implemented as driving the existing `onPointSelected` selection path (Task 6). fl_chart may also surface its native hover tooltip; the de-dupe via `_lastHoverIndex` keeps selection idempotent.
- Out-of-scope items (X-only zoom, rubber-band, inertia, scrollbars, persisted/cross-instance zoom, other profile charts) get no task, per the spec.
