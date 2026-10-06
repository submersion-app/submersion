# Dive Profile Chart Performance Optimization - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate drag lag and reduce rebuild overhead when interacting with the dive profile chart on iPhone.

**Architecture:** Five targeted optimizations to the existing touch/gesture pipeline in `DiveProfileChart` and `DiveDetailPage`. No new files, no new dependencies. Changes are localized to two files with one callback signature change. The fullscreen profile page (`_FullscreenProfilePage`, same file) also needs updating.

**Tech Stack:** Flutter, fl_chart, Riverpod (read-only, no provider changes)

---

### Task 1: Change onPointSelected Callback to Pass Index

The chart currently passes a `DiveProfilePoint` object, and both parent handlers do an O(n) `indexWhere()` to find the index. fl_chart already provides `spot.spotIndex` -- pass that directly.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:31` (callback type)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:149` (constructor param)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1025-1044` (touchCallback)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:960-973` (detail page handler)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4029-4043` (fullscreen handler)

**Step 1: Update callback type in DiveProfileChart**

In `dive_profile_chart.dart`, change the field declaration at line 31:

```dart
// Before:
final void Function(DiveProfilePoint? point)? onPointSelected;

// After:
final void Function(int? index)? onPointSelected;
```text
**Step 2: Update touchCallback to pass spotIndex**

In `dive_profile_chart.dart`, update the `touchCallback` at line 1025:

```dart
touchCallback: (event, response) {
  if (widget.onPointSelected != null) {
    if (event is FlPointerExitEvent ||
        event is FlLongPressEnd ||
        event is FlTapUpEvent ||
        event is FlPanEndEvent) {
      widget.onPointSelected!(null);
    } else if (response?.lineBarSpots != null &&
        response!.lineBarSpots!.isNotEmpty) {
      final spot = response.lineBarSpots!.first;
      if (spot.barIndex == 0 &&
          spot.spotIndex < widget.profile.length) {
        widget.onPointSelected!(spot.spotIndex);
      }
    }
  }
},
```text
**Step 3: Update detail page handler (line 960)**

In `dive_detail_page.dart`, update the `_DiveDetailPageState` handler:

```dart
onPointSelected: (index) {
  if (index == null) {
    setState(() => _selectedPointIndex = null);
    return;
  }
  setState(() {
    _heatMapHoverIndex = null;
    _selectedPointIndex = index;
  });
},
```text
**Step 4: Update fullscreen page handler (line 4029)**

In `dive_detail_page.dart`, update the `_FullscreenProfilePageState` handler:

```dart
onPointSelected: (index) {
  setState(() {
    _selectedPoint = index != null ? dive.profile[index] : null;
    _selectedPointIndex = index;
  });
},
```text
**Step 5: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No analysis issues

**Step 6: Commit**

```

feat: pass spotIndex directly in onPointSelected callback

Eliminates O(n) indexWhere scan (up to 5,000 items) on every
touch frame by passing fl_chart's spotIndex directly instead of
a DiveProfilePoint object that the parent must re-search for.

```dart
---

### Task 2: Add ValueNotifier for Selected Point Index (Detail Page)

Replace `setState()` on the 4,696-line `DiveDetailPage` with a `ValueNotifier<int?>` so only the widgets that depend on the selection rebuild per touch frame.

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:111-113` (state field)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:909-914` (MouseRegion onExit)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:960-973` (onPointSelected)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1067-1163` (_buildDecoO2Panel)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1090-1100` (onHeatMapHover)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1243-1244` (SAC segment highlight)

**Step 1: Replace state field with ValueNotifier**

In `_DiveDetailPageState`, change:

```dart
// Before (line 113):
int? _selectedPointIndex;

// After:
final ValueNotifier<int?> _selectedPointNotifier = ValueNotifier<int?>(null);
```text
Add dispose:

```dart
@override
void dispose() {
  _selectedPointNotifier.dispose();
  super.dispose();
}
```text
Note: If there is already a `dispose()` method, add the notifier disposal before `super.dispose()`.

**Step 2: Update MouseRegion onExit (line 909-914)**

```dart
// Before:
onExit: (_) {
  setState(() {
    _selectedPointIndex = null;
    _heatMapHoverIndex = null;
  });
},

// After:
onExit: (_) {
  _selectedPointNotifier.value = null;
  setState(() {
    _heatMapHoverIndex = null;
  });
},
```text
**Step 3: Update onPointSelected callback (line 960)**

```dart
// After (using Task 1's index-based callback):
onPointSelected: (index) {
  if (index == null) {
    _selectedPointNotifier.value = null;
    return;
  }
  _selectedPointNotifier.value = index;
  setState(() {
    _heatMapHoverIndex = null;
  });
},
```dart
Note: We still use `setState` for `_heatMapHoverIndex` because it controls the chart's `highlightedTimestamp` prop. But the notifier handles the hot path (selected index changes). If `_heatMapHoverIndex` was already null, the setState is essentially a no-op from Flutter's perspective (same state = no rebuild).

**Step 4: Wrap _buildDecoO2Panel with ValueListenableBuilder**

Wherever `_buildDecoO2Panel` is called in the build method, wrap it:

```dart
ValueListenableBuilder<int?>(
  valueListenable: _selectedPointNotifier,
  builder: (context, selectedPointIndex, _) {
    return _buildDecoO2Panel(context, ref, dive, selectedPointIndex);
  },
),
```text
Update the `_buildDecoO2Panel` method signature to accept `selectedPointIndex` as a parameter instead of reading from `_selectedPointIndex`:

```dart
Widget _buildDecoO2Panel(
  BuildContext context,
  WidgetRef ref,
  Dive dive,
  int? selectedPointIndex,
) {
```text
Replace all `_selectedPointIndex` references inside this method with the `selectedPointIndex` parameter.

**Step 5: Update onHeatMapHover (line 1095-1100)**

The tissue card's `onHeatMapHover` callback also sets `_selectedPointIndex`. Update it:

```dart
onHeatMapHover: (index) {
  _selectedPointNotifier.value = index;
  setState(() {
    _heatMapHoverIndex = index;
  });
},
```text
**Step 6: Wrap SAC segment highlight with ValueListenableBuilder**

At line 1243, the SAC segments section reads `_selectedPointIndex`. Wrap the call to `_buildSacSegmentsSection` similarly, or pass the notifier's value.

Find where `_buildSacSegmentsSection` is called and wrap it:

```dart
ValueListenableBuilder<int?>(
  valueListenable: _selectedPointNotifier,
  builder: (context, selectedPointIndex, _) {
    return _buildSacSegmentsSection(context, ref, dive, selectedPointIndex);
  },
),
```text
Update `_buildSacSegmentsSection` to accept `int? selectedPointIndex` as a parameter and replace `_selectedPointIndex` references with it.

**Step 7: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No analysis issues

**Step 8: Commit**

```

perf: use ValueNotifier for selected point to reduce rebuild scope

Replaces setState() on the 4,696-line DiveDetailPage with a
ValueNotifier<int?> so only tissue/deco/O2 panels rebuild per
touch frame instead of the entire page.

```text
---

### Task 3: Fix Gesture Disambiguation Delay

The `GestureDetector` wrapping the chart uses `onScaleStart`/`onScaleUpdate` which competes with fl_chart's internal pan recognizer. Flutter's gesture arena waits to disambiguate between tap, pan, and pinch, causing ~200ms initial drag lag on single-finger interaction.

Fix: Only apply zoom/pan logic when `details.pointerCount > 1` (two-finger pinch). Single-finger drag passes through to fl_chart's `touchCallback` without gesture arena delay.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:565-646` (gesture handling)

**Step 1: Guard onScaleUpdate for multi-touch only**

In `dive_profile_chart.dart`, update the `onScaleUpdate` handler at line 571:

```dart
onScaleUpdate: (details) {
  // Only apply zoom/pan for multi-touch (pinch) gestures.
  // Single-finger drag is handled by fl_chart's touchCallback
  // without gesture arena disambiguation delay.
  if (details.pointerCount < 2) return;

  setState(() {
    // Handle zoom
    final newZoom = (_previousZoom * details.scale).clamp(
      _minZoom,
      _maxZoom,
    );

    // Handle pan
    final panDelta = details.localFocalPoint - _startFocalPoint;

    // Convert pixel delta to normalized offset based on chart size
    final chartWidth = constraints.maxWidth;
    final chartHeight = constraints.maxHeight;

    // Only apply pan if zoomed in
    if (newZoom > 1.0) {
      final normalizedDeltaX = -panDelta.dx / chartWidth / newZoom;
      final normalizedDeltaY = -panDelta.dy / chartHeight / newZoom;

      _panOffsetX = (_previousPan.dx + normalizedDeltaX).clamp(
        0.0,
        1.0 - (1.0 / newZoom),
      );
      _panOffsetY = (_previousPan.dy + normalizedDeltaY).clamp(
        0.0,
        1.0 - (1.0 / newZoom),
      );
    } else {
      _panOffsetX = 0.0;
      _panOffsetY = 0.0;
    }

    _zoomLevel = newZoom;
  });
},
```text
**Step 2: Test on device**

Test on iPhone:

- Single-finger touch: tooltip should appear immediately
- Single-finger drag: crosshair should track finger with no initial delay
- Two-finger pinch: zoom should still work
- Double-tap: zoom toggle should still work

**Step 3: Commit**

```

perf: skip gesture arena for single-finger chart drag

Only engage zoom/pan gesture handling for multi-touch (pinch)
gestures. Single-finger drag falls through to fl_chart's native
touch system, eliminating the ~200ms gesture disambiguation delay
on initial drag.

```text
---

### Task 4: Memoize Tooltip Construction

The `getTooltipItems` callback creates 15+ TextSpan objects with formatting and unit conversions on every touch frame, even when the `spotIndex` hasn't changed.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:187` (add cache fields)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1046-end` (tooltip builder)

**Step 1: Add tooltip cache fields**

In `_DiveProfileChartState`, add cache fields near the zoom/pan state (around line 344):

```dart
// Tooltip memoization
int? _lastTooltipSpotIndex;
List<LineTooltipItem?> _lastTooltipItems = [];
```text
**Step 2: Add early return in getTooltipItems**

At the top of the `getTooltipItems` callback (line 1053), add cache check:

```dart
getTooltipItems: (touchedSpots) {
  // Return cached result if the same spot index is touched again
  if (touchedSpots.isNotEmpty) {
    final firstDepthSpot = touchedSpots
        .where((s) => s.barIndex == 0)
        .firstOrNull;
    if (firstDepthSpot != null &&
        firstDepthSpot.spotIndex == _lastTooltipSpotIndex) {
      return _lastTooltipItems;
    }
  }

  // Build tooltip showing all enabled metrics for the touched point
  // ... (existing code)
```dart
**Step 3: Cache result before returning**

At the end of the `getTooltipItems` callback, before the final `return`, save to cache:

```dart
  // Cache the result
  final result = touchedSpots.map((spot) {
    // ... existing mapping code ...
  }).toList();

  final depthSpot = touchedSpots
      .where((s) => s.barIndex == 0)
      .firstOrNull;
  if (depthSpot != null) {
    _lastTooltipSpotIndex = depthSpot.spotIndex;
    _lastTooltipItems = result;
  }

  return result;
```text
Note: The existing code uses `touchedSpots.map(...)` inline. Capture the result into a variable first, then cache it, then return it.

**Step 4: Hoist sacUnit read outside the tooltip builder**

In the `_buildChart` method, before the `lineTouchData:` line, read the SAC unit once:

```dart
final sacUnit = ref.read(sacUnitProvider);
```dart
Then inside the tooltip builder at line 1196, replace `ref.read(sacUnitProvider)` with the local `sacUnit` variable.

**Step 5: Invalidate cache when widget config changes**

In `didUpdateWidget`, clear the tooltip cache:

```dart
@override
void didUpdateWidget(covariant DiveProfileChart oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Clear tooltip cache when profile data changes
  if (oldWidget.profile != widget.profile) {
    _lastTooltipSpotIndex = null;
    _lastTooltipItems = [];
  }
  // ... existing didUpdateWidget code ...
}
```text
If there is no existing `didUpdateWidget`, add it.

**Step 6: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
Expected: No analysis issues

**Step 7: Commit**

```

perf: memoize tooltip construction by spotIndex

Caches the last tooltip TextSpan list keyed by spotIndex. During
slow drags the same index is often hit on consecutive frames --
returns cached result immediately instead of rebuilding 15+
TextSpan objects with formatting and unit conversions.
Also hoists sacUnitProvider read outside the tooltip builder.

```text
---

### Task 5: Configure fl_chart Touch Sensitivity

Set explicit `touchSpotThresholdInPercentage` to limit how many spots fl_chart evaluates during nearest-point detection.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1023-1024` (LineTouchData)

**Step 1: Add touch configuration**

Update the `LineTouchData` at line 1023:

```dart
lineTouchData: LineTouchData(
  enabled: true,
  touchSpotThreshold: 20,
  handleBuiltInTouches: true,
  touchCallback: (event, response) {
    // ... existing callback code ...
  },
```text
The `touchSpotThreshold` limits the pixel radius for spot detection (default is very generous). Setting it to 20 pixels reduces the search. `handleBuiltInTouches: true` (the default) lets fl_chart render the touch indicator internally.

**Step 2: Verify compilation and test**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
Expected: No analysis issues

Test: Touch the chart on a dense area and verify the tooltip still appears and tracks correctly.

**Step 3: Commit**

```text

perf: configure fl_chart touch threshold for faster spot detection

Sets explicit touchSpotThreshold to limit the search radius
for nearest-point detection on dense dive profiles.

```

---

### Task 6: Final Verification

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No issues

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Format code**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 4: Manual device testing**

Test on iPhone:

- Touch profile chart: tooltip appears instantly (no delay)
- Drag finger across chart: tracking starts immediately (no initial lag)
- Cards below chart update in real-time during drag
- Release finger: cards return to end-of-dive values
- Pinch to zoom: still works with two fingers
- Double-tap: zoom toggle still works
- Fullscreen profile: same behavior as detail page
- Heat map hover: still drives chart cursor correctly
- Test with both small (~500 point) and large (~5,000 point) dives
