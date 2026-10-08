# Dive Profile Chart Performance Optimization

## Problem

Two related performance issues when interacting with the dive profile chart on iPhone:

1. **Initial drag lag**: Touching the chart and then dragging shows a ~200ms delay before tracking begins
2. **Real-time update speed**: Dragging across the chart to inspect data points feels sluggish due to full-page rebuilds and redundant computation on every touch frame

## Root Causes

Five compounding bottlenecks identified:

### 1. Gesture Disambiguation Delay

The `GestureDetector` wrapping the chart uses `onScaleStart`/`onScaleUpdate` for zoom/pan. Flutter's gesture arena delays single-finger pan recognition to rule out pinch-to-zoom, causing ~200ms initial drag lag.

- File: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (line 565)

### 2. O(n) Linear Scan Per Touch Frame

The `onPointSelected` callback receives a `DiveProfilePoint` object, and the parent does `indexWhere()` to find its index -- scanning up to 5,000 items per touch event.

- File: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (line 966)
- fl_chart already provides `spot.spotIndex` -- the linear search is redundant

### 3. Full-Page Rebuild Per Touch Frame

`setState()` on `DiveDetailPage` (4,696 lines) rebuilds the entire page on every drag movement -- chart, tissue card, deco card, O2 panel, toolbar, and all other widgets.

- File: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (line 962, 969)

### 4. Expensive Tooltip Construction

`getTooltipItems` creates 15+ `TextSpan` objects with formatting, unit conversions, string padding, and provider reads on every touch frame -- even when the touched index hasn't changed.

- File: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (line 1053)

### 5. Default Touch Search Configuration

fl_chart uses default touch detection settings which may scan more spots than needed for nearest-point detection.

## Design: Targeted Quick Wins

### Fix 1: Pass Index Directly (Eliminate O(n) Scan)

Change callback signature from `void Function(DiveProfilePoint?)` to `void Function(int?)`.

The chart already has `spot.spotIndex` from fl_chart. Pass it directly to the parent. The parent can do `dive.profile[index]` in O(1) if it needs the point.

**Before:**

```dart
// In chart
widget.onPointSelected!(widget.profile[spot.spotIndex]);

// In parent
onPointSelected: (point) {
  final index = dive.profile.indexWhere(
    (p) => p.timestamp == point.timestamp,
  );
  setState(() => _selectedPointIndex = index >= 0 ? index : null);
}
```text
**After:**

```dart
// In chart
widget.onPointSelected!(spot.spotIndex);

// In parent
onPointSelected: (index) {
  _selectedPointNotifier.value = index;
}
```

**Files:** `dive_profile_chart.dart`, `dive_detail_page.dart`

### Fix 2: ValueNotifier for Selected Index (Reduce Rebuild Scope)

Replace `int? _selectedPointIndex` state field with `ValueNotifier<int?>`.

Wrap only the widgets that react to selection changes in `ValueListenableBuilder`:

- Tissue loading card
- Deco status card
- O2 toxicity panel
- Time subtitle text

The chart itself does NOT need to rebuild -- fl_chart handles its own touch rendering.

**Files:** `dive_detail_page.dart`

### Fix 3: Separate Gesture Recognition (Fix Initial Drag Lag)

Only engage the outer `GestureDetector` for multi-pointer (pinch) gestures. Let fl_chart's internal touch system handle single-finger drag natively (no disambiguation delay).

In `onScaleUpdate`, check `details.pointerCount > 1` before applying zoom/pan. Single-finger events pass through to fl_chart's `touchCallback`.

Alternative: Set `handleBuiltInTouches: true` on `LineTouchData` to let fl_chart manage single-touch interaction directly.

**Files:** `dive_profile_chart.dart`

### Fix 4: Tooltip Memoization (Avoid Redundant Construction)

Cache the last tooltip result keyed by `spotIndex`. During slow drags, the same index may be hit on consecutive frames -- return the cached result immediately.

Move `ref.read(sacUnitProvider)` outside the tooltip builder into a local variable captured once.

**Files:** `dive_profile_chart.dart`

### Fix 5: Touch Sensitivity Configuration

Set explicit `touchSpotThresholdInPercentage` on `LineTouchData` to limit the search radius for nearest-point detection.

**Files:** `dive_profile_chart.dart`

## Files Changed

| File | Changes |
|------|---------|
| `dive_profile_chart.dart` | Callback signature, gesture separation, tooltip cache, touch config |
| `dive_detail_page.dart` | ValueNotifier, callback handlers, ValueListenableBuilder wrappers |

## Testing

- Verify tooltip appears on single touch (no delay)
- Verify drag tracking starts immediately (no gesture disambiguation lag)
- Verify pinch-to-zoom still works with two fingers
- Verify tissue/deco/O2 cards update correctly during drag
- Verify null selection on touch end (cards return to end-of-dive values)
- Verify both portrait detail page and landscape fullscreen profile work
- Performance test: profile with 5,000 points should feel smooth on iPhone

## Risk Assessment

- **Low risk**: Changes are localized to two files
- **No data model changes**: Only UI/interaction layer
- **Backwards compatible**: No API or provider changes
- **Testable**: Each fix can be verified independently
