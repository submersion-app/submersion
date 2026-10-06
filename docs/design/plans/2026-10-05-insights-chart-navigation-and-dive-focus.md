# Insights Chart Navigation and Dive Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Insights date chart navigable (overview strip, horizontal wheel and trackpad pan, arrow keys, a per-chart Range menu) and add a Dive focus page that picks a group of dives by one metric, lists them, and compares their common factors with the diver's other dives (issue #1611).

**Architecture:** `ChartViewport` stays the single source of truth for a chart's visible window; a new input layer, an overview strip and a Range menu all read and write it, and `DiveTrendChart` reports settled windows back as a `TrendRange` stored per chart in `TrendChartSettings`. Dive focus is pure Dart domain logic (`selectFocusGroup`, `FocusFactorAnalyzer`) over the trend charts' existing per-dive series plus one new repository query (`getFocusFactorRows`), exposed through Riverpod providers to a new `/insights/focus` page.

**Tech Stack:** Flutter, Riverpod 3 (`StateProvider`, `FutureProvider`), Drift `customSelect`, fl_chart `LineChart`, `CustomPainter`, flutter_test.

**Spec:** `docs/design/specs/2026-10-05-insights-chart-navigation-and-dive-focus-design.md`

## Global Constraints

- Never use the em-dash or en-dash characters in code, comments, docs, commits or strings. No mention of Claude, Claude Code or Anthropic in anything committed or pushed.
- Store metric, display through `UnitFormatter` (`lib/core/utils/unit_formatter.dart`); every value the diver sees respects the active diver's units.
- New state is session-only (`StateProvider`); no schema change, no settings persistence.
- Every new query over `dives` goes through `InsightsRepository._diveFilter`, so `test/core/database/dive_stats_scope_census_test.dart` passes without an exemption marker.
- Files stay under 800 lines; `dive_trend_chart.dart` (848 today) must end under 800.
- Imports grouped dart, flutter, packages, local; `package:submersion/core/providers/provider.dart` is the project's Riverpod import.
- New strings go into `lib/l10n/arb/app_en.arb` next to a neighbouring key of the same group (the ARB is feature-grouped), then `flutter gen-l10n`. Task 18 translates all 10 other locales and reruns `flutter gen-l10n` LAST.
- A test that changes `Intl.defaultLocale` or any other process-wide state restores it with `addTearDown`.
- Run `dart format .` and `flutter analyze` before each commit; commit messages use `feat(insights): ...` or `refactor(insights): ...`.

## Review Focus

1. A series whose dives all fall on one day (zero time span) with a preset or custom range: the chart must draw without dividing by zero (pinned in Task 2 and Task 6).
2. An ice-diving water temperature threshold such as -1 C: a negative threshold must be accepted for water temp, while a negative RMV, SAC, depth, time or weight is rejected (pinned in Task 14). This refines the spec's "negative entry is invalid" rule, which did not consider sub-zero water.
3. A comma-decimal locale (de) typing "0,75" into the threshold field must read as 0.75, not 75 or an error (pinned in Task 14).
4. Narrowing the Insights filter while a chart has a custom range: the chart keeps showing the same dates, not the same fractions of the new span (pinned in Task 6).
5. Widening the overview strip's window to the full range by dragging an edge: zoom returns to 1, the chart reports `TrendRange.all`, and the strip disappears instead of staying stuck mid-gesture (pinned in Task 8).

---

### Task 1: ChartViewport window helpers and a per-chart zoom limit

A three-month window over a ten-year logbook needs a 40x zoom; `ChartViewport.maxZoom` is 10 and is shared with the dive profile chart, so the limit becomes a per-instance field that defaults to the old constant.

**Files:**
- Modify: `lib/core/ui/chart_viewport.dart:11-59`
- Test: `test/core/ui/chart_viewport_test.dart` (append a group)

**Interfaces:**
- Produces: `ChartViewport({double zoom, double offsetX, double offsetY, double zoomLimit = ChartViewport.maxZoom})`, `double get windowStart`, `double get windowEnd`, `factory ChartViewport.forWindow(double start, double end, {double zoomLimit})`, `ChartViewport withZoomLimit(double limit)`, `final double zoomLimit`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/ui/chart_viewport_test.dart`, inside `main()`:

```dart
  group('window helpers', () {
    test('forWindow maps a fraction window to zoom and offset', () {
      final vp = ChartViewport.forWindow(0.25, 0.75);
      expect(vp.zoom, closeTo(2, 1e-9));
      expect(vp.windowStart, closeTo(0.25, 1e-9));
      expect(vp.windowEnd, closeTo(0.75, 1e-9));
    });

    test('forWindow of the full range is unzoomed', () {
      final vp = ChartViewport.forWindow(0, 1);
      expect(vp.isZoomed, isFalse);
      expect(vp.windowStart, 0);
    });

    test('forWindow narrower than the limit widens to the limit', () {
      final vp = ChartViewport.forWindow(0.5, 0.501, zoomLimit: 20);
      expect(vp.zoom, closeTo(20, 1e-9));
    });

    test('forWindow ending at 1 keeps its end when widened', () {
      final vp = ChartViewport.forWindow(0.999, 1, zoomLimit: 10);
      expect(vp.windowEnd, closeTo(1, 1e-9));
      expect(vp.windowStart, closeTo(0.9, 1e-9));
    });

    test('a raised zoom limit is honoured by zoomedAt and kept by pannedBy',
        () {
      final vp = const ChartViewport(zoomLimit: 40).zoomedAt(0.5, 0, 30);
      expect(vp.zoom, closeTo(30, 1e-9));
      expect(vp.pannedBy(0.01, 0).zoomLimit, 40);
    });

    test('the default limit is unchanged for existing callers', () {
      final vp = ChartViewport.reset.zoomedAt(0.5, 0, 100);
      expect(vp.zoom, ChartViewport.maxZoom);
    });

    test('withZoomLimit clamps a zoom above the new limit', () {
      final vp = ChartViewport.forWindow(0.5, 0.52, zoomLimit: 50)
          .withZoomLimit(10);
      expect(vp.zoom, 10);
      expect(vp.zoomLimit, 10);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/ui/chart_viewport_test.dart`
Expected: FAIL to compile, `forWindow`, `windowStart`, `zoomLimit` undefined.

- [ ] **Step 3: Implement**

In `lib/core/ui/chart_viewport.dart`, replace the class body from the fields through `_clamped` with:

```dart
@immutable
class ChartViewport {
  final double zoom; // >= 1.0
  final double offsetX;
  final double offsetY;

  /// The deepest zoom this viewport allows. Defaults to [maxZoom]; a date
  /// chart over a long logbook raises it so a few weeks can fill the plot.
  final double zoomLimit;

  const ChartViewport({
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.zoomLimit = maxZoom,
  });

  /// A viewport showing [start]..[end] of the x range (fractions, 0..1).
  ///
  /// A window narrower than [zoomLimit] allows is widened about its centre,
  /// then shifted back inside 0..1, so a window ending at 1 still ends at 1.
  factory ChartViewport.forWindow(
    double start,
    double end, {
    double zoomLimit = maxZoom,
  }) {
    final width = (end - start).clamp(1.0 / zoomLimit, 1.0);
    final centre = (start + end) / 2;
    return ChartViewport(
      zoom: 1.0 / width,
      offsetX: centre - width / 2,
      zoomLimit: zoomLimit,
    )._clamped();
  }

  static const double minZoom = 1.0;
  static const double maxZoom = 10.0;
  static const ChartViewport reset = ChartViewport();

  bool get isZoomed => zoom > 1.0;
  double get visibleWidth => 1.0 / zoom;
  double get visibleHeight => 1.0 / zoom;

  /// Left edge of the visible x window, as a fraction of the full range.
  double get windowStart => offsetX;

  /// Right edge of the visible x window, as a fraction of the full range.
  double get windowEnd => offsetX + visibleWidth;

  /// This viewport under a different [limit], zoomed out to it if needed.
  ChartViewport withZoomLimit(double limit) => ChartViewport(
    zoom: zoom.clamp(minZoom, limit),
    offsetX: offsetX,
    offsetY: offsetY,
    zoomLimit: limit,
  )._clamped();

  /// Zoom by [factor] (>1 = in, <1 = out) keeping the data point under the
  /// focal point fixed. [focalX]/[focalY] are fractions (0..1) of the visible
  /// plot area under the cursor/pinch (0 = left/top edge).
  ChartViewport zoomedAt(double focalX, double focalY, double factor) {
    final newZoom = (zoom * factor).clamp(minZoom, zoomLimit);
    if (newZoom == zoom) return this;
    final anchorX =
        offsetX + focalX / zoom; // data fraction under focus, before
    final anchorY = offsetY + focalY / zoom;
    return ChartViewport(
      zoom: newZoom,
      offsetX: anchorX - focalX / newZoom, // keep it under focus, after
      offsetY: anchorY - focalY / newZoom,
      zoomLimit: zoomLimit,
    )._clamped();
  }

  /// Pan by a normalized delta (fractions of the total range).
  ChartViewport pannedBy(double dx, double dy) => ChartViewport(
    zoom: zoom,
    offsetX: offsetX + dx,
    offsetY: offsetY + dy,
    zoomLimit: zoomLimit,
  )._clamped();

  ChartViewport _clamped() {
    final maxOff = 1.0 - 1.0 / zoom;
    return ChartViewport(
      zoom: zoom,
      offsetX: offsetX.clamp(0.0, maxOff),
      offsetY: offsetY.clamp(0.0, maxOff),
      zoomLimit: zoomLimit,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/ui/chart_viewport_test.dart test/features/dive_log/presentation/widgets/`
Expected: PASS (the profile chart still uses the default limit).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/ui/chart_viewport.dart test/core/ui/chart_viewport_test.dart
git add lib/core/ui/chart_viewport.dart test/core/ui/chart_viewport_test.dart
git commit -m "feat(insights): give ChartViewport window helpers and a per-chart zoom limit"
```

---

### Task 2: TrendRange domain value and preset window maths

**Files:**
- Create: `lib/features/insights/domain/trend_range.dart`
- Test: `test/features/insights/domain/trend_range_test.dart`

**Interfaces:**
- Produces: `enum TrendRangePreset { all, years5, years2, year1, months6, months3, custom }`; `class TrendRange` with `const TrendRange.preset(TrendRangePreset)`, `const TrendRange.custom(DateTime start, DateTime end)`, `static const TrendRange all`, fields `preset`, `start`, `end`, value equality; `({double start, double end}) trendRangeFractions(TrendRange range, DateTime dataStart, DateTime dataEnd)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';

void main() {
  final start = DateTime.utc(2022, 1, 1);
  final end = DateTime.utc(2026, 1, 1);

  test('All is the whole span', () {
    final f = trendRangeFractions(TrendRange.all, start, end);
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('Last year ends at the latest dive and starts a year before', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.year1),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    final expected =
        DateTime.utc(2025, 1, 1).difference(start).inMilliseconds / full;
    expect(f.end, 1);
    expect(f.start, closeTo(expected, 1e-9));
  });

  test('Last 6 months crosses a year boundary', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.months6),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    final expected =
        DateTime.utc(2025, 7, 1).difference(start).inMilliseconds / full;
    expect(f.start, closeTo(expected, 1e-9));
  });

  test('a preset longer than the data shows everything', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.years5),
      start,
      end,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('a custom range inside the data maps to its fractions', () {
    final f = trendRangeFractions(
      TrendRange.custom(DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    expect(
      f.start,
      closeTo(DateTime.utc(2023).difference(start).inMilliseconds / full, 1e-9),
    );
    expect(
      f.end,
      closeTo(DateTime.utc(2024).difference(start).inMilliseconds / full, 1e-9),
    );
  });

  test('a custom range outside the data falls back to everything', () {
    final f = trendRangeFractions(
      TrendRange.custom(DateTime.utc(2010), DateTime.utc(2011)),
      start,
      end,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('a zero-length data span never divides by zero', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.months3),
      start,
      start,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('ranges compare by value', () {
    expect(
      TrendRange.custom(DateTime.utc(2023), DateTime.utc(2024)),
      TrendRange.custom(DateTime.utc(2023), DateTime.utc(2024)),
    );
    expect(
      const TrendRange.preset(TrendRangePreset.year1),
      isNot(TrendRange.all),
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/domain/trend_range_test.dart`
Expected: FAIL, `trend_range.dart` not found.

- [ ] **Step 3: Implement** `lib/features/insights/domain/trend_range.dart`

```dart
import 'package:flutter/foundation.dart';

/// The visible-window choices a date chart's Range menu offers.
enum TrendRangePreset { all, years5, years2, year1, months6, months3, custom }

/// What a date chart shows of its data: everything, a preset span ending at
/// the latest dive, or a custom pair of dates.
///
/// Dates rather than fractions, so a custom window keeps meaning the same
/// days when the filter changes the data's span.
@immutable
class TrendRange {
  const TrendRange.preset(this.preset)
    : assert(preset != TrendRangePreset.custom),
      start = null,
      end = null;

  const TrendRange.custom(DateTime this.start, DateTime this.end)
    : preset = TrendRangePreset.custom;

  static const all = TrendRange.preset(TrendRangePreset.all);

  final TrendRangePreset preset;
  final DateTime? start;
  final DateTime? end;

  @override
  bool operator ==(Object other) =>
      other is TrendRange &&
      other.preset == preset &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}

/// The fraction window (0..1 of [dataStart]..[dataEnd]) that [range] shows.
///
/// A preset ends at [dataEnd]. A window that would start before the data
/// starts at the data, and a window with no overlap at all shows everything.
({double start, double end}) trendRangeFractions(
  TrendRange range,
  DateTime dataStart,
  DateTime dataEnd,
) {
  const everything = (start: 0.0, end: 1.0);
  final fullMs =
      dataEnd.millisecondsSinceEpoch - dataStart.millisecondsSinceEpoch;
  if (fullMs <= 0) return everything;

  final DateTime from;
  final DateTime to;
  switch (range.preset) {
    case TrendRangePreset.all:
      return everything;
    case TrendRangePreset.custom:
      from = range.start!;
      to = range.end!;
    case TrendRangePreset.years5:
    case TrendRangePreset.years2:
    case TrendRangePreset.year1:
    case TrendRangePreset.months6:
    case TrendRangePreset.months3:
      to = dataEnd;
      from = _presetStart(range.preset, dataEnd);
  }

  double fraction(DateTime d) =>
      ((d.millisecondsSinceEpoch - dataStart.millisecondsSinceEpoch) / fullMs)
          .clamp(0.0, 1.0);
  final start = fraction(from);
  final end = fraction(to);
  return end <= start ? everything : (start: start, end: end);
}

DateTime _presetStart(TrendRangePreset preset, DateTime end) {
  final (years, months) = switch (preset) {
    TrendRangePreset.years5 => (5, 0),
    TrendRangePreset.years2 => (2, 0),
    TrendRangePreset.year1 => (1, 0),
    TrendRangePreset.months6 => (0, 6),
    TrendRangePreset.months3 => (0, 3),
    TrendRangePreset.all || TrendRangePreset.custom => (0, 0),
  };
  // DateTime.utc normalises a month below 1 into the previous year.
  return DateTime.utc(
    end.year - years,
    end.month - months,
    end.day,
    end.hour,
    end.minute,
    end.second,
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/insights/domain/trend_range_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/trend_range.dart test/features/insights/domain/trend_range_test.dart
git add lib/features/insights/domain/trend_range.dart test/features/insights/domain/trend_range_test.dart
git commit -m "feat(insights): add TrendRange and preset window maths"
```

---

### Task 3: TrendChartSettings carries the range

**Files:**
- Modify: `lib/features/insights/presentation/providers/trend_chart_settings_provider.dart:16-38`
- Test: `test/features/insights/presentation/providers/trend_chart_settings_provider_test.dart` (append)

**Interfaces:**
- Consumes: `TrendRange` (Task 2).
- Produces: `TrendChartSettings.range` (default `TrendRange.all`), `copyWith({..., TrendRange? range})`.

- [ ] **Step 1: Write the failing tests** (append inside `main()`)

```dart
  test('the range defaults to everything', () {
    expect(const TrendChartSettings().range, TrendRange.all);
  });

  test('copyWith replaces the range and keeps the rest', () {
    const before = TrendChartSettings(aggregation: TrendAggregation.weekly);
    final after = before.copyWith(
      range: const TrendRange.preset(TrendRangePreset.year1),
    );
    expect(after.range, const TrendRange.preset(TrendRangePreset.year1));
    expect(after.aggregation, TrendAggregation.weekly);
    expect(after.copyWith().range, after.range);
  });
```

Add the import `package:submersion/features/insights/domain/trend_range.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/providers/trend_chart_settings_provider_test.dart`
Expected: FAIL, no `range`.

- [ ] **Step 3: Implement**

```dart
class TrendChartSettings {
  const TrendChartSettings({
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = true,
    this.showLinearFit = false,
    this.range = TrendRange.all,
  });

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;

  /// The visible window, from the Range menu or the last pan and zoom.
  final TrendRange range;

  TrendChartSettings copyWith({
    TrendAggregation? aggregation,
    bool? showRollingMean,
    bool? showLinearFit,
    TrendRange? range,
  }) {
    return TrendChartSettings(
      aggregation: aggregation ?? this.aggregation,
      showRollingMean: showRollingMean ?? this.showRollingMean,
      showLinearFit: showLinearFit ?? this.showLinearFit,
      range: range ?? this.range,
    );
  }
}
```

Add `import 'package:submersion/features/insights/domain/trend_range.dart';`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/insights/presentation/providers/trend_chart_settings_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/presentation/providers/trend_chart_settings_provider.dart test/features/insights/presentation/providers/trend_chart_settings_provider_test.dart
git add lib/features/insights/presentation/providers/trend_chart_settings_provider.dart test/features/insights/presentation/providers/trend_chart_settings_provider_test.dart
git commit -m "feat(insights): keep a visible range in each trend chart's settings"
```

---

### Task 4: Move DiveTrendChart's input handling into its own layer (refactor)

Pure move: behaviour is unchanged and the existing chart tests are the safety net. It takes `dive_trend_chart.dart` from 848 lines to roughly 640 and gives Tasks 5 and 6 one place to add inputs.

**Files:**
- Create: `lib/features/insights/presentation/widgets/dive_trend_chart_input.dart`
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart:113-353`

**Interfaces:**
- Produces: `const trendChartPlotInsets = (left: 50.0, right: 0.0, top: 0.0, bottom: 30.0)`; `class TrendChartInputLayer extends StatefulWidget` with `({required Size box, required ChartViewport viewport, required ValueChanged<ChartViewport> onViewportChanged, required Widget child})`.

- [ ] **Step 1: Confirm the safety net is green before moving anything**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_test.dart test/features/insights/presentation/widgets/dive_trend_chart_series_test.dart test/features/insights/presentation/widgets/trend_chart_section_test.dart`
Expected: PASS.

- [ ] **Step 2: Create `dive_trend_chart_input.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';

/// Axis gutters `DiveTrendChart` reserves around its plot. A gesture's focal
/// point is taken against the inner plot rect, not the whole widget.
const trendChartPlotInsets = (left: 50.0, right: 0.0, top: 0.0, bottom: 30.0);

/// Every pointer input a `DiveTrendChart` understands: mouse drag and wheel,
/// touch drag and pinch, and trackpad pan-zoom.
///
/// Owns gesture bookkeeping only. The viewport belongs to the chart, which
/// hands the current one in and takes each new one back through
/// [onViewportChanged], so the zoom buttons and the overview strip edit the
/// same value.
class TrendChartInputLayer extends StatefulWidget {
  const TrendChartInputLayer({
    super.key,
    required this.box,
    required this.viewport,
    required this.onViewportChanged,
    required this.child,
  });

  final Size box;
  final ChartViewport viewport;
  final ValueChanged<ChartViewport> onViewportChanged;
  final Widget child;

  @override
  State<TrendChartInputLayer> createState() => _TrendChartInputLayerState();
}

class _TrendChartInputLayerState extends State<TrendChartInputLayer> {
  /// The latest viewport this layer emitted or was given. Several pointer
  /// events can land in one frame, before the chart rebuilds with the value
  /// emitted for the first, so deltas must build on this rather than on
  /// `widget.viewport`.
  late ChartViewport _current = widget.viewport;

  ChartViewport _gestureStartViewport = ChartViewport.reset;
  PointerDeviceKind _activePointerKind = PointerDeviceKind.mouse;
  int _activePointerCount = 0;
  Offset? _lastPointerLocal;
  bool _touchDragClaimed = false;
  final Map<int, Offset> _touchPositions = {};
  List<int> _pinchPointers = const [];
  double _pinchStartDistance = 1;
  Offset _pinchStartFocal = Offset.zero;

  @override
  void didUpdateWidget(TrendChartInputLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.viewport;
  }

  void _emit(ChartViewport next) {
    _current = next;
    widget.onViewportChanged(next);
  }

  double _focalX(Offset localPos) => chartFocalFraction(
    localPos,
    widget.box,
    left: trendChartPlotInsets.left,
    right: trendChartPlotInsets.right,
    top: trendChartPlotInsets.top,
    bottom: trendChartPlotInsets.bottom,
  ).fx;

  double _plotWidth() =>
      (widget.box.width -
              trendChartPlotInsets.left -
              trendChartPlotInsets.right)
          .clamp(1.0, double.infinity);

  void _zoomAt(Offset localPosition, double zoomDelta) {
    if (zoomDelta == 0) return;
    _activePointerKind = PointerDeviceKind.trackpad;
    _emit(
      _current.zoomedAt(
        _focalX(localPosition),
        0,
        math.pow(2, zoomDelta).toDouble(),
      ),
    );
  }

  void _beginPinch() {
    _pinchPointers = _touchPositions.keys.take(2).toList(growable: false);
    final p0 = _touchPositions[_pinchPointers[0]]!;
    final p1 = _touchPositions[_pinchPointers[1]]!;
    _pinchStartDistance = (p0 - p1).distance.clamp(1.0, double.infinity);
    _pinchStartFocal = (p0 + p1) / 2;
    _gestureStartViewport = _current;
  }

  void _updatePinch() {
    if (_pinchPointers.length < 2) return;
    final p0 = _touchPositions[_pinchPointers[0]];
    final p1 = _touchPositions[_pinchPointers[1]];
    if (p0 == null || p1 == null) return;
    final scale =
        (p0 - p1).distance.clamp(1.0, double.infinity) / _pinchStartDistance;
    var vp = _gestureStartViewport.zoomedAt(
      _focalX(_pinchStartFocal),
      0,
      scale,
    );
    final panPx = (p0 + p1) / 2 - _pinchStartFocal;
    vp = vp.pannedBy(-panPx.dx / _plotWidth() / vp.zoom, 0);
    _emit(vp);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        TrackpadZoomGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TrackpadZoomGestureRecognizer>(
              () => TrackpadZoomGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onZoom = _zoomAt,
            ),
      },
      child: Listener(
        onPointerDown: (event) {
          _activePointerCount++;
          _activePointerKind = event.kind;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
            if (_touchPositions.length == 2) _beginPinch();
          }
        },
        onPointerMove: (event) {
          final prev = _lastPointerLocal;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
          }
          if (prev == null) return;
          final intent = chartDragIntent(
            kind: _activePointerKind,
            pointerCount: _activePointerCount,
            isZoomed: _current.isZoomed,
          );
          if (intent == ChartDragIntent.zoomPan &&
              _activePointerKind == PointerDeviceKind.touch) {
            _updatePinch();
            return;
          }
          if (intent != ChartDragIntent.pan) return;
          // A touch drag only pans once the claim recognizer has won the
          // arena, so a scrub is never fought by a pan.
          if (_activePointerKind == PointerDeviceKind.touch &&
              !_touchDragClaimed) {
            return;
          }
          final d = event.localPosition - prev;
          _emit(_current.pannedBy(-d.dx / _plotWidth() / _current.zoom, 0));
        },
        onPointerUp: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          if (_pinchPointers.contains(event.pointer)) {
            _touchPositions.length >= 2
                ? _beginPinch()
                : _pinchPointers = const [];
          }
        },
        onPointerCancel: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          _pinchPointers = const [];
        },
        // Trackpad pan-zoom is claimed by the recognizer above so it does
        // not also scroll the enclosing page.
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          _activePointerKind = PointerDeviceKind.mouse;
          final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
          _emit(_current.zoomedAt(_focalX(event.localPosition), 0, factor));
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: {
                  ChartTouchClaimRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        ChartTouchClaimRecognizer
                      >(
                        () => ChartTouchClaimRecognizer(
                          isZoomed: () => _current.isZoomed,
                          debugOwner: this,
                        ),
                        (recognizer) {
                          recognizer.onClaimed = () {
                            _touchDragClaimed = true;
                          };
                          recognizer.onReleased = () {
                            _touchDragClaimed = false;
                          };
                        },
                      ),
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

- [ ] **Step 3: Slim `_DiveTrendChartState`**

In `dive_trend_chart.dart`:
1. Delete the fields `_gestureStartViewport`, `_activePointerKind`, `_activePointerCount`, `_lastPointerLocal`, `_touchDragClaimed`, `_touchPositions`, `_pinchPointers`, `_pinchStartDistance`, `_pinchStartFocal`, the `_insets` constant, and the methods `_focalX`, `_plotWidth`, `_zoomAt`, `_beginPinch`, `_updatePinch` (current lines 119-199, keeping `_drawnBuckets`, `_drawnSecondary`, `_secondaryBarStart`, the tooltip widths and `_x`).
2. Replace the whole `_interactiveChart` method (current lines 240-353) with:

```dart
  Widget _interactiveChart(BuildContext context, Size box) {
    // Built before the layer is handed the viewport: building the chart can
    // re-seat the viewport (a new range or a new data span).
    final chart = _buildChart(context);
    return TrendChartInputLayer(
      box: box,
      viewport: _viewport,
      onViewportChanged: (vp) => setState(() => _viewport = vp),
      child: chart,
    );
  }
```

3. Add `import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart_input.dart';` and remove imports `flutter analyze` then reports unused (likely `trackpad_zoom_recognizer.dart`; keep `chart_touch_recognizer.dart` if `nearestTouchedDataSpot` still resolves from it).

- [ ] **Step 4: Run the safety net and analyze**

Run: `flutter analyze lib/features/insights && flutter test test/features/insights/presentation/widgets/ test/features/equipment/presentation/widgets/`
Expected: no issues; PASS. `wc -l lib/features/insights/presentation/widgets/dive_trend_chart.dart` prints well under 800.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/presentation/widgets/
git add lib/features/insights/presentation/widgets/dive_trend_chart.dart lib/features/insights/presentation/widgets/dive_trend_chart_input.dart
git commit -m "refactor(insights): move trend chart input handling into its own layer"
```

---

### Task 5: Horizontal wheel, shift+wheel, trackpad sideways swipe and arrow keys pan

**Files:**
- Modify: `lib/core/ui/trackpad_zoom_recognizer.dart:28-60`
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart_input.dart`
- Test: `test/core/ui/trackpad_zoom_recognizer_test.dart` (create)
- Test: `test/features/insights/presentation/widgets/dive_trend_chart_input_test.dart` (create)

**Interfaces:**
- Produces: `TrackpadZoomGestureRecognizer.onPan` of type `void Function(Offset localPosition, double dx)?`.

- [ ] **Step 1: Write the failing recognizer test** `test/core/ui/trackpad_zoom_recognizer_test.dart`

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

void main() {
  testWidgets('a sideways two-finger swipe reports a horizontal pan', (
    tester,
  ) async {
    final pans = <double>[];
    final zooms = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RawGestureDetector(
          gestures: {
            TrackpadZoomGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  TrackpadZoomGestureRecognizer
                >(TrackpadZoomGestureRecognizer.new, (r) {
                  r.onPan = (_, dx) => pans.add(dx);
                  r.onZoom = (_, delta) => zooms.add(delta);
                }),
          },
          child: const SizedBox(width: 400, height: 300),
        ),
      ),
    );

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(-30, 0)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(pans, [-30]);
    // No vertical movement, so no zoom.
    expect(zooms.every((z) => z == 0), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/ui/trackpad_zoom_recognizer_test.dart`
Expected: FAIL to compile, `onPan` undefined.

- [ ] **Step 3: Implement `onPan`** in `trackpad_zoom_recognizer.dart`

Add the field under `onZoom`:

```dart
  /// Called per update with the pointer's local position and the swipe's
  /// horizontal movement in logical pixels. Null leaves a sideways swipe
  /// inert, which is what the maps and the dive profile chart want.
  void Function(Offset localPosition, double dx)? onPan;
```

and in `handleEvent`, after the `onZoom?.call(...)` line:

```dart
      final dx = event.panDelta.dx;
      if (dx != 0) onPan?.call(event.localPosition, dx);
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/ui/trackpad_zoom_recognizer_test.dart test/core/ui/`
Expected: PASS.

- [ ] **Step 5: Write the failing chart input tests** `test/features/insights/presentation/widgets/dive_trend_chart_input_test.dart`

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i % 5,
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

double minX(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.minX;

Future<void> zoomIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
  await tester.pump();
}

void main() {
  Widget chart() => host(DiveTrendChart(chartId: 'c', points: series(60)));

  testWidgets('a horizontal wheel pans a zoomed chart', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(120, 0)));
    await tester.pump();

    expect(minX(tester), greaterThan(before));
  });

  testWidgets('shift+wheel pans instead of zooming', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);
    final beforeSpan =
        tester.widget<LineChart>(find.byType(LineChart)).data.maxX - before;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.minX, greaterThan(before));
    expect(data.maxX - data.minX, closeTo(beforeSpan, 1));
  });

  testWidgets('a trackpad sideways swipe pans', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    final pointer = TestPointer(2, PointerDeviceKind.trackpad);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(centre, pan: const Offset(-80, 0)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(minX(tester), greaterThan(before));
  });

  testWidgets('arrow keys pan once the chart has focus', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    await tester.tap(find.byType(LineChart), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final afterRight = minX(tester);
    expect(afterRight, greaterThan(before));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(minX(tester), lessThan(afterRight));
  });

  testWidgets('arrow keys do nothing on an unzoomed chart', (tester) async {
    await tester.pumpWidget(chart());
    final before = minX(tester);
    await tester.tap(find.byType(LineChart), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(minX(tester), before);
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_input_test.dart`
Expected: the wheel, shift, trackpad and arrow tests FAIL (the unzoomed arrow test passes).

- [ ] **Step 7: Implement in `dive_trend_chart_input.dart`**

Add the import `package:flutter/services.dart`. In `_TrendChartInputLayerState` add:

```dart
  final FocusNode _focusNode = FocusNode(debugLabel: 'trend-chart');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Pans by a pointer movement of [dxPixels], the way a drag does: content
  /// follows the movement, so the window moves the other way.
  void _panByPixels(double dxPixels) {
    _emit(_current.pannedBy(-dxPixels / _plotWidth() / _current.zoom, 0));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_current.isZoomed) return KeyEventResult.ignored;
    final step = _current.visibleWidth / 4;
    final double dx;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      dx = -step;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      dx = step;
    } else {
      return KeyEventResult.ignored;
    }
    _emit(_current.pannedBy(dx, 0));
    return KeyEventResult.handled;
  }
```

Change the recognizer configuration to also set the pan:

```dart
              (recognizer) => recognizer
                ..onZoom = _zoomAt
                ..onPan = (_, dx) => _panByPixels(dx),
```

In `onPointerDown`, first line: `_focusNode.requestFocus();`.

Replace the `onPointerSignal` body with:

```dart
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          _activePointerKind = PointerDeviceKind.mouse;
          // A horizontal wheel, or shift with a vertical one, scrolls through
          // time; a plain vertical wheel keeps zooming at the pointer.
          final horizontal = event.scrollDelta.dx != 0
              ? event.scrollDelta.dx
              : HardwareKeyboard.instance.isShiftPressed
              ? event.scrollDelta.dy
              : 0.0;
          if (horizontal != 0) {
            _emit(
              _current.pannedBy(horizontal / _plotWidth() / _current.zoom, 0),
            );
            return;
          }
          final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
          _emit(_current.zoomedAt(_focalX(event.localPosition), 0, factor));
        },
```

Wrap the returned `RawGestureDetector` in `Focus(focusNode: _focusNode, onKeyEvent: _onKey, child: ...)`.

- [ ] **Step 8: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/ test/core/ui/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/core/ui lib/features/insights/presentation/widgets test/core/ui test/features/insights/presentation/widgets
git add lib/core/ui/trackpad_zoom_recognizer.dart lib/features/insights/presentation/widgets/dive_trend_chart_input.dart test/core/ui/trackpad_zoom_recognizer_test.dart test/features/insights/presentation/widgets/dive_trend_chart_input_test.dart
git commit -m "feat(insights): pan trend charts with the wheel, a trackpad swipe and arrow keys"
```

---

### Task 6: DiveTrendChart shows a TrendRange and reports navigation as one

**Files:**
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart`
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart_input.dart`
- Test: `test/features/insights/presentation/widgets/dive_trend_chart_range_test.dart` (create)

**Interfaces:**
- Consumes: `ChartViewport.forWindow/withZoomLimit/windowStart/windowEnd` (Task 1), `TrendRange`, `trendRangeFractions` (Task 2).
- Produces: `DiveTrendChart({..., TrendRange range = TrendRange.all, ValueChanged<TrendRange>? onRangeChanged})`; `TrendChartInputLayer({..., VoidCallback? onNavigationEnd})`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> weekly(int n, {DateTime? from}) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: (from ?? DateTime.utc(2022, 1, 3)).add(Duration(days: i * 7)),
    value: 10.0 + i % 7,
    diveId: 'd$i',
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

LineChartData data(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

void main() {
  const year1 = TrendRange.preset(TrendRangePreset.year1);
  const day = 86400000.0;

  testWidgets('a preset shows the last year of a four-year series', (
    tester,
  ) async {
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    final last = points.last.date;
    expect(data(tester).maxX, closeTo(ms(last), 1000));
    expect(
      data(tester).minX,
      closeTo(ms(DateTime.utc(last.year - 1, last.month, last.day)), 1000),
    );
  });

  testWidgets('three months of ten years is not capped at a tenth', (
    tester,
  ) async {
    final points = weekly(522);
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          range: const TrendRange.preset(TrendRangePreset.months3),
        ),
      ),
    );
    final span = data(tester).maxX - data(tester).minX;
    expect(span, lessThan(100 * day));
    expect(span, greaterThan(85 * day));
  });

  testWidgets('a new range prop moves the window', (tester) async {
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    final allMin = data(tester).minX;
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    expect(data(tester).minX, greaterThan(allMin));
  });

  testWidgets('a mouse drag reports the new window as a custom range', (
    tester,
  ) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    final centre = tester.getCenter(find.byType(LineChart));
    final gesture = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(120, 0));
    await gesture.up();
    await tester.pump();

    expect(reported?.preset, TrendRangePreset.custom);
    expect(ms(reported!.start!), closeTo(data(tester).minX, 1000));
    expect(ms(reported!.end!), closeTo(data(tester).maxX, 1000));
  });

  testWidgets('reset zoom reports All', (tester) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          chartId: 'c',
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('trend-c-zoom-reset')));
    await tester.pump();
    expect(reported, TrendRange.all);
  });

  testWidgets('a custom range keeps its dates when the data shrinks', (
    tester,
  ) async {
    final range = TrendRange.custom(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 7, 1),
    );
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: range)));
    expect(data(tester).minX, closeTo(ms(DateTime.utc(2024)), day));

    final narrowed = points
        .where((p) => !p.date.isBefore(DateTime.utc(2023, 6, 1)))
        .toList();
    await tester.pumpWidget(
      host(DiveTrendChart(points: narrowed, range: range)),
    );
    expect(data(tester).minX, closeTo(ms(DateTime.utc(2024)), day));
    expect(data(tester).maxX, closeTo(ms(DateTime.utc(2024, 7)), day));
  });

  testWidgets('a single-day series with a preset still draws', (tester) async {
    final points = [
      for (var i = 0; i < 3; i++)
        TrendDataPoint(date: DateTime.utc(2025, 5, 1), value: 10.0 + i),
    ];
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_range_test.dart`
Expected: FAIL to compile, `range` and `onRangeChanged` undefined.

- [ ] **Step 3: Add `onNavigationEnd` to the input layer**

In `TrendChartInputLayer` add the field and constructor parameter:

```dart
  /// Fires once a navigation settles: pointer up after a pan or pinch, the
  /// end of a trackpad gesture, and each wheel or arrow-key step.
  final VoidCallback? onNavigationEnd;
```

In the state add `bool _navigated = false;`, set `_navigated = true;` inside `_emit`, and add:

```dart
  void _settle() {
    if (!_navigated) return;
    _navigated = false;
    widget.onNavigationEnd?.call();
  }
```

Call `_settle()`: at the end of `onPointerUp` when `_activePointerCount == 0`; in `onPointerCancel`; at the end of `onPointerSignal` (both the pan and the zoom branches); after `_emit` in `_onKey`; and in a new `onPointerPanZoomEnd: (_) => _settle(),` on the `Listener`.

- [ ] **Step 4: Implement the range in `DiveTrendChart`**

Add constructor parameters `this.range = TrendRange.all, this.onRangeChanged,` and fields:

```dart
  /// The window to show. A changed range re-seats the viewport; so does a
  /// changed data span, so a custom window keeps meaning the same dates.
  final TrendRange range;

  /// Called with the window the diver navigated to: [TrendRange.all] when
  /// unzoomed, otherwise a custom range of the visible dates. Null when the
  /// caller does not keep the window.
  final ValueChanged<TrendRange>? onRangeChanged;
```

In `_DiveTrendChartState` add:

```dart
  /// The narrowest window a zoom can reach: a week, however long the data.
  static const _minWindow = Duration(days: 7);

  TrendRange? _appliedRange;
  ({int first, int last})? _appliedSpan;

  /// Full x range of the last build, for turning the viewport into dates.
  ({double min, double span})? _fullX;

  static DateTime _date(double ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);

  /// Applies [DiveTrendChart.range] when it, or the data's span, changed
  /// since it was last applied, and keeps the zoom limit matched to the span.
  /// Runs inside build, before anything reads [_viewport].
  void _seatViewport(double fullMin, double fullMax) {
    final span = (fullMax - fullMin).clamp(1.0, double.infinity);
    final zoomLimit = math.max(
      ChartViewport.maxZoom,
      span / _minWindow.inMilliseconds,
    );
    final dataSpan = (first: fullMin.round(), last: fullMax.round());
    _fullX = (min: fullMin, span: span);
    if (_appliedRange == widget.range && _appliedSpan == dataSpan) {
      if (_viewport.zoomLimit != zoomLimit) {
        _viewport = _viewport.withZoomLimit(zoomLimit);
      }
      return;
    }
    final window = trendRangeFractions(
      widget.range,
      _date(fullMin),
      _date(fullMax),
    );
    _viewport = ChartViewport.forWindow(
      window.start,
      window.end,
      zoomLimit: zoomLimit,
    );
    _appliedRange = widget.range;
    _appliedSpan = dataSpan;
  }

  /// Hands the settled window to [DiveTrendChart.onRangeChanged].
  void _reportRange() {
    final onRangeChanged = widget.onRangeChanged;
    final full = _fullX;
    if (onRangeChanged == null || full == null) return;
    final next = _viewport.isZoomed
        ? TrendRange.custom(
            _date(full.min + _viewport.windowStart * full.span),
            _date(full.min + _viewport.windowEnd * full.span),
          )
        : TrendRange.all;
    _appliedRange = next;
    if (next != widget.range) onRangeChanged(next);
  }
```

In `_buildChart`, directly after `final fullSpan = ...;` insert `_seatViewport(fullMin, fullMax);`.

In `_interactiveChart`, pass `onNavigationEnd: _reportRange,` to the layer.

In `build`, change the zoom control callbacks so each reports:

```dart
                onZoomIn: () {
                  setState(() => _viewport = _viewport.zoomedAt(0.5, 0, 1.5));
                  _reportRange();
                },
                onZoomOut: () {
                  setState(
                    () => _viewport = _viewport.zoomedAt(0.5, 0, 1 / 1.5),
                  );
                  _reportRange();
                },
                onResetZoom: () {
                  setState(
                    () => _viewport = ChartViewport.reset.withZoomLimit(
                      _viewport.zoomLimit,
                    ),
                  );
                  _reportRange();
                },
```

Add `import 'package:submersion/features/insights/domain/trend_range.dart';`.

The zoom controls are built after `_interactiveChart` in the same `Column` children list, so they read the re-seated `_viewport`; keep that order.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/ test/features/equipment/presentation/widgets/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/insights/presentation/widgets test/features/insights/presentation/widgets
git add lib/features/insights/presentation/widgets/dive_trend_chart.dart lib/features/insights/presentation/widgets/dive_trend_chart_input.dart test/features/insights/presentation/widgets/dive_trend_chart_range_test.dart
git commit -m "feat(insights): show and report a visible range on the trend chart"
```

---

### Task 7: ChartOverviewStrip widget

**Files:**
- Create: `lib/features/insights/presentation/widgets/chart_overview_strip.dart`
- Modify: `lib/l10n/arb/app_en.arb` (one key)
- Test: `test/features/insights/presentation/widgets/chart_overview_strip_test.dart`

**Interfaces:**
- Consumes: `ChartViewport` (Task 1).
- Produces: `ChartOverviewStrip({required List<Offset> points, required ChartViewport viewport, required ValueChanged<ChartViewport> onViewportChanged, VoidCallback? onChangeStart, VoidCallback? onChangeEnd, double height = 28})`, keyed `ValueKey('trend-overview-strip')`.

- [ ] **Step 1: Add the string**

In `app_en.arb`, after the last `"insights_trend_` key, add:

```json
  "insights_trend_overview_semanticLabel": "Chart overview. Drag the highlighted window to scroll through time.",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late ChartViewport latest;
  late int ends;

  Future<void> pump(WidgetTester tester, ChartViewport initial) async {
    latest = initial;
    ends = 0;
    var vp = initial;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, setState) => ChartOverviewStrip(
                  points: const [Offset(0, 0), Offset(0.5, 0.5), Offset(1, 1)],
                  viewport: vp,
                  onViewportChanged: (next) {
                    latest = next;
                    setState(() => vp = next);
                  },
                  onChangeEnd: () => ends++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset at(WidgetTester tester, double fraction) {
    final rect = tester.getRect(
      find.byKey(const ValueKey('trend-overview-strip')),
    );
    return Offset(rect.left + rect.width * fraction, rect.center.dy);
  }

  testWidgets('dragging inside the window moves it', (tester) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.375), const Offset(40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.35, 0.01));
    expect(latest.windowEnd - latest.windowStart, closeTo(0.25, 1e-6));
    expect(ends, 1);
  });

  testWidgets('dragging the left edge resizes and holds the right edge', (
    tester,
  ) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.25), const Offset(-40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.15, 0.01));
    expect(latest.windowEnd, closeTo(0.5, 0.01));
  });

  testWidgets('dragging the right edge resizes and holds the left edge', (
    tester,
  ) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.5), const Offset(40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.25, 0.01));
    expect(latest.windowEnd, closeTo(0.6, 0.01));
  });

  testWidgets('tapping outside the window centres it there', (tester) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.tapAt(at(tester, 0.9));
    await tester.pump();
    expect(latest.windowEnd, closeTo(1.0, 1e-6));
    expect(latest.windowStart, closeTo(0.75, 1e-6));
    expect(ends, 1);
  });

  testWidgets('tapping inside the window leaves it alone', (tester) async {
    final initial = ChartViewport.forWindow(0.25, 0.5);
    await pump(tester, initial);
    await tester.tapAt(at(tester, 0.4));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.25, 1e-6));
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/chart_overview_strip_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 4: Implement** `chart_overview_strip.dart`

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _StripDrag { move, resizeStart, resizeEnd }

/// A slim map of a zoomed date chart: every point across the full range, and
/// the visible window as a box. Drag the box to scroll, drag an edge to
/// resize, tap elsewhere to jump (issue #1611).
///
/// Reads and writes the chart's own [ChartViewport], so the strip, the zoom
/// buttons and pointer gestures can never disagree about the window.
class ChartOverviewStrip extends StatefulWidget {
  const ChartOverviewStrip({
    super.key,
    required this.points,
    required this.viewport,
    required this.onViewportChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.height = 28,
  });

  /// Every data point, x and y each normalised to 0..1 of the full range
  /// (y = 0 at the bottom).
  final List<Offset> points;
  final ChartViewport viewport;
  final ValueChanged<ChartViewport> onViewportChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final double height;

  @override
  State<ChartOverviewStrip> createState() => _ChartOverviewStripState();
}

class _ChartOverviewStripState extends State<ChartOverviewStrip> {
  /// How close to an edge, in logical pixels, a drag must start to resize.
  static const _edgeSlop = 10.0;

  late ChartViewport _current = widget.viewport;
  _StripDrag _drag = _StripDrag.move;

  @override
  void didUpdateWidget(ChartOverviewStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.viewport;
  }

  void _emit(ChartViewport next) {
    _current = next;
    widget.onViewportChanged(next);
  }

  ChartViewport _centredOn(double fraction) => _current.pannedBy(
    fraction - (_current.windowStart + _current.windowEnd) / 2,
    0,
  );

  bool _inside(double fraction) =>
      fraction >= _current.windowStart && fraction <= _current.windowEnd;

  void _onDragStart(DragStartDetails details, double width) {
    widget.onChangeStart?.call();
    final x = details.localPosition.dx;
    final startPx = _current.windowStart * width;
    final endPx = _current.windowEnd * width;
    if ((x - startPx).abs() <= _edgeSlop) {
      _drag = _StripDrag.resizeStart;
    } else if ((x - endPx).abs() <= _edgeSlop) {
      _drag = _StripDrag.resizeEnd;
    } else {
      _drag = _StripDrag.move;
      if (!_inside(x / width)) _emit(_centredOn(x / width));
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    final delta = details.delta.dx / width;
    final minWidth = 1 / _current.zoomLimit;
    switch (_drag) {
      case _StripDrag.move:
        _emit(_current.pannedBy(delta, 0));
      case _StripDrag.resizeStart:
        final start = (_current.windowStart + delta).clamp(
          0.0,
          _current.windowEnd - minWidth,
        );
        _emit(
          ChartViewport.forWindow(
            start,
            _current.windowEnd,
            zoomLimit: _current.zoomLimit,
          ),
        );
      case _StripDrag.resizeEnd:
        final end = (_current.windowEnd + delta).clamp(
          _current.windowStart + minWidth,
          1.0,
        );
        _emit(
          ChartViewport.forWindow(
            _current.windowStart,
            end,
            zoomLimit: _current.zoomLimit,
          ),
        );
    }
  }

  void _onTapUp(TapUpDetails details, double width) {
    final fraction = details.localPosition.dx / width;
    if (_inside(fraction)) return;
    widget.onChangeStart?.call();
    _emit(_centredOn(fraction));
    widget.onChangeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.insights_trend_overview_semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: const ValueKey('trend-overview-strip'),
            behavior: HitTestBehavior.opaque,
            // The drag starts where the finger went down, so an edge grab is
            // decided before the slop moves the pointer off the edge.
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _onDragStart(d, width),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
            onHorizontalDragEnd: (_) => widget.onChangeEnd?.call(),
            onHorizontalDragCancel: () => widget.onChangeEnd?.call(),
            onTapUp: (d) => _onTapUp(d, width),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _StripPainter(
                points: widget.points,
                start: widget.viewport.windowStart,
                end: widget.viewport.windowEnd,
                trackColor: scheme.surfaceContainerHighest,
                dotColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                windowColor: scheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.trackColor,
    required this.dotColor,
    required this.windowColor,
  });

  final List<Offset> points;
  final double start;
  final double end;
  final Color trackColor;
  final Color dotColor;
  final Color windowColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      Paint()..color = trackColor,
    );
    final dot = Paint()..color = dotColor;
    final usable = size.height - 6;
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.dx * size.width, 3 + (1 - p.dy) * usable),
        1.2,
        dot,
      );
    }
    final window = Rect.fromLTRB(
      start * size.width,
      0,
      end * size.width,
      size.height,
    );
    canvas.drawRect(window, Paint()..color = windowColor.withValues(alpha: 0.18));
    canvas.drawRect(
      window.deflate(0.75),
      Paint()
        ..color = windowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final handle = Paint()
      ..color = windowColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final x in [window.left, window.right]) {
      canvas.drawLine(
        Offset(x, size.height * 0.3),
        Offset(x, size.height * 0.7),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.start != start ||
      old.end != end ||
      !identical(old.points, points) ||
      old.trackColor != trackColor ||
      old.dotColor != dotColor ||
      old.windowColor != windowColor;
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/chart_overview_strip_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/insights/presentation/widgets/chart_overview_strip.dart test/features/insights/presentation/widgets/chart_overview_strip_test.dart
git add lib/features/insights/presentation/widgets/chart_overview_strip.dart test/features/insights/presentation/widgets/chart_overview_strip_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): add an overview strip for zoomed trend charts"
```

---

### Task 8: Show the overview strip under a zoomed DiveTrendChart

**Files:**
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart`
- Test: `test/features/insights/presentation/widgets/dive_trend_chart_overview_test.dart` (create)

**Interfaces:**
- Consumes: `ChartOverviewStrip` (Task 7), `_reportRange` (Task 6), `trendChartPlotInsets` (Task 4).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> weekly(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2022, 1, 3).add(Duration(days: i * 7)),
    value: 10.0 + i % 7,
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Offset stripAt(WidgetTester tester, double fraction) {
  final rect = tester.getRect(find.byType(ChartOverviewStrip));
  return Offset(rect.left + rect.width * fraction, rect.center.dy);
}

void main() {
  const year1 = TrendRange.preset(TrendRangePreset.year1);

  testWidgets('the strip appears only once the chart is zoomed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(DiveTrendChart(chartId: 'c', points: weekly(52))),
    );
    expect(find.byType(ChartOverviewStrip), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
    await tester.pump();
    expect(find.byType(ChartOverviewStrip), findsOneWidget);
  });

  testWidgets('dragging the strip pans the chart and reports at the end', (
    tester,
  ) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    final before = tester.widget<LineChart>(find.byType(LineChart)).data.minX;
    await tester.dragFrom(stripAt(tester, 0.875), const Offset(-60, 0));
    await tester.pump();
    final after = tester.widget<LineChart>(find.byType(LineChart)).data.minX;
    expect(after, lessThan(before));
    expect(reported?.preset, TrendRangePreset.custom);
  });

  testWidgets('widening the window to everything reports All and hides it', (
    tester,
  ) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    final rect = tester.getRect(find.byType(ChartOverviewStrip));
    // The year window starts about three quarters of the way along; drag
    // its left edge past the strip's start.
    final edge = Offset(
      rect.left +
          rect.width *
              (1 -
                  365 /
                      DateTime.utc(2022, 1, 3)
                          .add(const Duration(days: 208 * 7))
                          .difference(DateTime.utc(2022, 1, 3))
                          .inDays),
      rect.center.dy,
    );
    await tester.dragFrom(edge, Offset(-rect.width, 0));
    await tester.pump();
    expect(reported, TrendRange.all);
    expect(find.byType(ChartOverviewStrip), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_overview_test.dart`
Expected: FAIL, no strip found.

- [ ] **Step 3: Implement**

In `_DiveTrendChartState` add:

```dart
  /// True while the strip is being dragged, so a drag that zooms all the way
  /// out keeps its strip until the gesture ends.
  bool _stripActive = false;

  /// The strip's points, rebuilt with the chart only while it is showing.
  List<Offset> _overviewPoints = const [];
```

In `_buildChart`, after `yAxis` is computed, add:

```dart
    if (_viewport.isZoomed || _stripActive) {
      final ySpan = yAxis.max - yAxis.min;
      _overviewPoints = [
        for (final p in [
          ...points,
          ...widget.secondarySeries.expand((s) => s.points),
        ])
          Offset(
            ((_x(p.date) - fullMin) / fullSpan).clamp(0.0, 1.0),
            ySpan <= 0 ? 0.5 : ((p.value - yAxis.min) / ySpan).clamp(0.0, 1.0),
          ),
      ];
    }
```

In `build`, between `_interactiveChart(context, box),` and the zoom controls `Align`, add:

```dart
            if (_viewport.isZoomed || _stripActive)
              Padding(
                padding: EdgeInsets.only(
                  left: trendChartPlotInsets.left,
                  top: 6,
                ),
                child: ChartOverviewStrip(
                  points: _overviewPoints,
                  viewport: _viewport,
                  onViewportChanged: (vp) => setState(() => _viewport = vp),
                  onChangeStart: () => setState(() => _stripActive = true),
                  onChangeEnd: () {
                    setState(() => _stripActive = false);
                    _reportRange();
                  },
                ),
              ),
```

Add `import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/ test/features/equipment/presentation/widgets/`
Expected: PASS. `wc -l lib/features/insights/presentation/widgets/dive_trend_chart.dart` stays under 800.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/presentation/widgets test/features/insights/presentation/widgets
git add lib/features/insights/presentation/widgets/dive_trend_chart.dart test/features/insights/presentation/widgets/dive_trend_chart_overview_test.dart
git commit -m "feat(insights): show the overview strip under a zoomed trend chart"
```

---

### Task 9: Range menu in the control strip, wired through TrendChartSection

**Files:**
- Modify: `lib/features/insights/presentation/widgets/trend_control_strip.dart`
- Modify: `lib/features/insights/presentation/widgets/trend_chart_section.dart`
- Create: `lib/features/insights/presentation/formatters/trend_range_label.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/trend_control_strip_test.dart` (append), `test/features/insights/presentation/widgets/trend_chart_section_test.dart` (append)

**Interfaces:**
- Consumes: `TrendRange`, `TrendRangePreset` (Task 2), `TrendChartSettings.range` (Task 3), `DiveTrendChart.range/onRangeChanged` (Task 6).
- Produces: `TrendControlStrip({..., TrendRange range = TrendRange.all, ValueChanged<TrendRangePreset>? onRangePresetSelected})`; keys `ValueKey('trend-range-$chartId')` and `ValueKey('trend-range-$chartId-${preset.name}')`; `String trendRangeLabel(TrendRangePreset preset, AppLocalizations l10n, {bool menuItem = false})`.

- [ ] **Step 1: Add strings** after `"insights_trend_overview_semanticLabel"` in `app_en.arb`, then run `flutter gen-l10n`:

```json
  "insights_trend_range_tooltip": "Visible range",
  "insights_trend_range_all": "All",
  "insights_trend_range_years5": "Last 5 years",
  "insights_trend_range_years2": "Last 2 years",
  "insights_trend_range_year1": "Last year",
  "insights_trend_range_months6": "Last 6 months",
  "insights_trend_range_months3": "Last 3 months",
  "insights_trend_range_custom": "Custom",
  "insights_trend_range_customPick": "Custom range...",
```

- [ ] **Step 2: Write the failing control strip tests**

Extend the `host` helper in `trend_control_strip_test.dart` with `TrendRange range = TrendRange.all` and `ValueChanged<TrendRangePreset>? onRangePresetSelected`, passing both to `TrendControlStrip`, and append:

```dart
  testWidgets('shows the range menu with the current range', (tester) async {
    await tester.pumpWidget(
      host(
        range: const TrendRange.preset(TrendRangePreset.year1),
        onRangePresetSelected: (_) {},
      ),
    );
    expect(find.text('Last year'), findsOneWidget);
  });

  testWidgets('a custom range is labelled Custom', (tester) async {
    await tester.pumpWidget(
      host(
        range: TrendRange.custom(DateTime.utc(2024), DateTime.utc(2025)),
        onRangePresetSelected: (_) {},
      ),
    );
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('picking a preset reports it', (tester) async {
    TrendRangePreset? picked;
    await tester.pumpWidget(host(onRangePresetSelected: (p) => picked = p));
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('trend-range-depth-months6')),
    );
    await tester.pumpAndSettle();
    expect(picked, TrendRangePreset.months6);
  });

  testWidgets('no range menu without a handler', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byKey(const ValueKey('trend-range-depth')), findsNothing);
  });
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/trend_control_strip_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Implement the label helper** `lib/features/insights/presentation/formatters/trend_range_label.dart`

```dart
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen name for a Range menu entry. [menuItem] names the custom entry
/// as an action ("Custom range...") rather than a state ("Custom").
String trendRangeLabel(
  TrendRangePreset preset,
  AppLocalizations l10n, {
  bool menuItem = false,
}) => switch (preset) {
  TrendRangePreset.all => l10n.insights_trend_range_all,
  TrendRangePreset.years5 => l10n.insights_trend_range_years5,
  TrendRangePreset.years2 => l10n.insights_trend_range_years2,
  TrendRangePreset.year1 => l10n.insights_trend_range_year1,
  TrendRangePreset.months6 => l10n.insights_trend_range_months6,
  TrendRangePreset.months3 => l10n.insights_trend_range_months3,
  TrendRangePreset.custom =>
    menuItem
        ? l10n.insights_trend_range_customPick
        : l10n.insights_trend_range_custom,
};
```

- [ ] **Step 5: Implement the menu** in `TrendControlStrip`

Add constructor parameters `this.range = TrendRange.all, this.onRangePresetSelected,` and fields:

```dart
  /// The chart's visible window, named on the Range menu.
  final TrendRange range;

  /// Called with the picked entry. [TrendRangePreset.custom] asks the caller
  /// to open a date picker. Null hides the menu.
  final ValueChanged<TrendRangePreset>? onRangePresetSelected;
```

In `build`, add as the first child of the `Wrap`:

```dart
          if (onRangePresetSelected != null)
            PopupMenuButton<TrendRangePreset>(
              key: ValueKey('trend-range-$chartId'),
              tooltip: context.l10n.insights_trend_range_tooltip,
              initialValue: range.preset,
              onSelected: onRangePresetSelected,
              itemBuilder: (context) => [
                for (final preset in TrendRangePreset.values)
                  PopupMenuItem<TrendRangePreset>(
                    key: ValueKey('trend-range-$chartId-${preset.name}'),
                    value: preset,
                    child: Text(
                      trendRangeLabel(preset, context.l10n, menuItem: true),
                    ),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    trendRangeLabel(range.preset, context.l10n),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
```

Add imports for `trend_range.dart` and `trend_range_label.dart`.

- [ ] **Step 6: Run the control strip tests**

Run: `flutter test test/features/insights/presentation/widgets/trend_control_strip_test.dart`
Expected: PASS.

- [ ] **Step 7: Write the failing section tests**

Append to `trend_chart_section_test.dart`, using the file's existing `host(AsyncValue<List<TrendDataPoint>>)` helper. Add the import `package:submersion/features/insights/domain/trend_range.dart` and this top-level fixture next to `series`:

```dart
/// Four years of weekly dives from Monday 2022-01-03.
List<TrendDataPoint> fourYears() => List.generate(
  209,
  (i) => TrendDataPoint(
    date: DateTime.utc(2022, 1, 3).add(Duration(days: i * 7)),
    value: 10.0 + i % 7,
  ),
);
```

```dart
  testWidgets('picking a preset narrows the chart and stores the range', (
    tester,
  ) async {
    await tester.pumpWidget(host(AsyncValue.data(fourYears())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-range-depth-year1')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrendChartSection)),
    );
    expect(
      container.read(trendChartSettingsProvider(TrendChartIds.depth)).range,
      const TrendRange.preset(TrendRangePreset.year1),
    );
    expect(find.text('Last year'), findsOneWidget);
  });

  testWidgets('Custom range... stores the picked days', (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(fourYears())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-range-depth-custom')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    // The picker opens on the data's whole span; saving keeps it.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrendChartSection)),
    );
    final range = container
        .read(trendChartSettingsProvider(TrendChartIds.depth))
        .range;
    expect(range.preset, TrendRangePreset.custom);
    expect(range.start, DateTime.utc(2022, 1, 3));
    expect(find.text('Custom'), findsOneWidget);
  });
```

- [ ] **Step 8: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/trend_chart_section_test.dart`
Expected: FAIL, no range menu.

- [ ] **Step 9: Wire `TrendChartSection`**

Pass to `DiveTrendChart`:

```dart
                range: settings.range,
                onRangeChanged: (range) =>
                    _update(ref, settings.copyWith(range: range)),
```

Pass to `TrendControlStrip`:

```dart
                range: settings.range,
                onRangePresetSelected: (preset) =>
                    preset == TrendRangePreset.custom
                    ? _pickCustomRange(context, ref, points)
                    : _update(
                        ref,
                        settings.copyWith(range: TrendRange.preset(preset)),
                      ),
```

Add the method:

```dart
  /// Opens a date-range picker over the data's days and stores the pick as
  /// a custom range, from the start of the first day to the end of the last.
  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    List<TrendDataPoint> points,
  ) async {
    if (points.isEmpty) return;
    var first = points.first.date;
    var last = first;
    for (final p in points) {
      if (p.date.isBefore(first)) first = p.date;
      if (p.date.isAfter(last)) last = p.date;
    }
    final firstDay = DateTime(first.year, first.month, first.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    final current = ref.read(trendChartSettingsProvider(chartId)).range;
    DateTime clampDay(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return day.isBefore(firstDay)
          ? firstDay
          : day.isAfter(lastDay)
          ? lastDay
          : day;
    }

    final initial = current.preset == TrendRangePreset.custom
        ? DateTimeRange(
            start: clampDay(current.start!),
            end: clampDay(current.end!),
          )
        : DateTimeRange(start: firstDay, end: lastDay);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDay,
      lastDate: lastDay,
      initialDateRange: initial,
    );
    if (picked == null) return;
    final latest = ref.read(trendChartSettingsProvider(chartId));
    _update(
      ref,
      latest.copyWith(
        range: TrendRange.custom(
          DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
          DateTime.utc(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      ),
    );
  }
```

Trend dates are stored as UTC wall-clock values, so the picked local calendar day is rebuilt as the same UTC day. Add the `trend_range.dart` import.

- [ ] **Step 10: Run to verify pass**

Run: `flutter test test/features/insights/presentation/`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/widgets/trend_control_strip.dart lib/features/insights/presentation/widgets/trend_chart_section.dart lib/features/insights/presentation/formatters/trend_range_label.dart test/features/insights/presentation/widgets/trend_control_strip_test.dart test/features/insights/presentation/widgets/trend_chart_section_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): add a Range menu to every trend chart"
```

---

### Task 10: Focus metric, selection and group (pure Dart)

**Files:**
- Create: `lib/features/insights/domain/focus/focus_metric.dart`
- Create: `lib/features/insights/domain/focus/focus_selection.dart`
- Create: `lib/features/insights/domain/focus/focus_group.dart`
- Test: `test/features/insights/domain/focus/focus_group_test.dart`

**Interfaces:**
- Produces: `enum FocusMetric { rmv, sac, maxDepth, bottomTime, weight, waterTemp }` with `bool get lowerIsBetter`; `enum FocusMode { lowest, highest, above, below }` with `bool get isRanked`; `class FocusSelection({FocusMetric metric = rmv, FocusMode mode = lowest, int count = 10, double? threshold})` with `copyWith({FocusMetric? metric, FocusMode? mode, int? count, double? threshold, bool clearThreshold = false})`, `minCount = 1`, `maxCount = 999`, value equality; `class FocusGroup({required List<TrendDataPoint> members, required List<TrendDataPoint> population})` with `Set<String> get memberIds`, `double? get memberMean`, `double? get populationMean`, `double? get populationMin`, `double? get populationMax`; `FocusGroup selectFocusGroup(List<TrendDataPoint> series, FocusSelection selection)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

TrendDataPoint p(String id, int day, double value) => TrendDataPoint(
  date: DateTime.utc(2025, 1, day),
  value: value,
  diveId: id,
);

void main() {
  final series = [
    p('a', 1, 20),
    p('b', 2, 14),
    p('c', 3, 18),
    p('d', 4, 14),
    p('e', 5, 25),
  ];

  test('lowest N takes the smallest values, ties newest first', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 2),
    );
    expect(group.members.map((m) => m.diveId), ['d', 'b']);
  });

  test('highest N takes the largest values', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.highest, count: 2),
    );
    expect(group.members.map((m) => m.diveId), ['e', 'a']);
  });

  test('N beyond the data returns every dive', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 50),
    );
    expect(group.members, hasLength(5));
  });

  test('above is strictly greater, newest first', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.above, threshold: 18),
    );
    expect(group.members.map((m) => m.diveId), ['e', 'a']);
  });

  test('below is strictly less', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.below, threshold: 18),
    );
    expect(group.members.map((m) => m.diveId), ['d', 'b']);
  });

  test('a threshold mode without a threshold selects nothing', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.above),
    );
    expect(group.members, isEmpty);
    expect(group.population, hasLength(5));
  });

  test('points with no dive behind them are left out', () {
    final group = selectFocusGroup([
      ...series,
      TrendDataPoint(date: DateTime.utc(2025), value: 1),
    ], const FocusSelection(mode: FocusMode.lowest, count: 1));
    expect(group.population, hasLength(5));
    expect(group.members.single.diveId, anyOf('b', 'd'));
  });

  test('means and range describe the group and the population', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 2),
    );
    expect(group.memberMean, 14);
    expect(group.populationMean, closeTo(18.2, 1e-9));
    expect(group.populationMin, 14);
    expect(group.populationMax, 25);
  });

  test('only gas consumption has a better end', () {
    expect(FocusMetric.rmv.lowerIsBetter, isTrue);
    expect(FocusMetric.sac.lowerIsBetter, isTrue);
    expect(FocusMetric.maxDepth.lowerIsBetter, isFalse);
  });

  test('copyWith can clear the threshold', () {
    const s = FocusSelection(mode: FocusMode.above, threshold: 1);
    expect(s.copyWith(clearThreshold: true).threshold, isNull);
    expect(s.copyWith(count: 5).threshold, 1);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/domain/focus/focus_group_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement**

`focus_metric.dart`:

```dart
/// A per-dive value Dive focus can rank or threshold on. Each reuses the
/// trend chart series of the same name, so a dive's value here is exactly
/// its value on that chart.
enum FocusMetric {
  rmv,
  sac,
  maxDepth,
  bottomTime,
  weight,
  waterTemp;

  /// Gas consumption is better when lower; the other metrics have no better
  /// end, so their modes read "lowest" and "highest".
  bool get lowerIsBetter => this == rmv || this == sac;
}
```

`focus_selection.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

/// How Dive focus picks its group.
enum FocusMode {
  lowest,
  highest,
  above,
  below;

  bool get isRanked => this == lowest || this == highest;
}

/// The diver's Dive focus choice. [threshold] is in storage units (litres
/// or bar per minute, metres, minutes, kilograms, Celsius).
@immutable
class FocusSelection {
  const FocusSelection({
    this.metric = FocusMetric.rmv,
    this.mode = FocusMode.lowest,
    this.count = 10,
    this.threshold,
  });

  static const int minCount = 1;
  static const int maxCount = 999;

  final FocusMetric metric;
  final FocusMode mode;
  final int count;
  final double? threshold;

  FocusSelection copyWith({
    FocusMetric? metric,
    FocusMode? mode,
    int? count,
    double? threshold,
    bool clearThreshold = false,
  }) => FocusSelection(
    metric: metric ?? this.metric,
    mode: mode ?? this.mode,
    count: count ?? this.count,
    threshold: clearThreshold ? null : threshold ?? this.threshold,
  );

  @override
  bool operator ==(Object other) =>
      other is FocusSelection &&
      other.metric == metric &&
      other.mode == mode &&
      other.count == count &&
      other.threshold == threshold;

  @override
  int get hashCode => Object.hash(metric, mode, count, threshold);
}
```

`focus_group.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// The dives a [FocusSelection] picked, and the dives it picked from.
@immutable
class FocusGroup {
  const FocusGroup({required this.members, required this.population});

  /// The selected dives in display order: rank order for a ranked mode,
  /// newest first for a threshold.
  final List<TrendDataPoint> members;

  /// Every dive that has the metric: the group's comparison baseline.
  final List<TrendDataPoint> population;

  Set<String> get memberIds => {for (final m in members) m.diveId!};

  double? get memberMean => _mean(members);
  double? get populationMean => _mean(population);

  double? get populationMin => population.isEmpty
      ? null
      : population.map((p) => p.value).reduce((a, b) => a < b ? a : b);

  double? get populationMax => population.isEmpty
      ? null
      : population.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  static double? _mean(List<TrendDataPoint> points) => points.isEmpty
      ? null
      : points.fold<double>(0, (sum, p) => sum + p.value) / points.length;
}

/// Picks the group [selection] describes from a per-dive [series].
///
/// Ties at a ranked cut-off break newest first, so the same data always
/// yields the same group.
FocusGroup selectFocusGroup(
  List<TrendDataPoint> series,
  FocusSelection selection,
) {
  final population = [
    for (final p in series)
      if (p.diveId != null) p,
  ];
  int newestFirst(TrendDataPoint a, TrendDataPoint b) =>
      b.date.compareTo(a.date);
  final threshold = selection.threshold;

  final List<TrendDataPoint> members;
  switch (selection.mode) {
    case FocusMode.lowest:
      members =
          (List.of(population)..sort((a, b) {
                final c = a.value.compareTo(b.value);
                return c != 0 ? c : newestFirst(a, b);
              }))
              .take(selection.count)
              .toList(growable: false);
    case FocusMode.highest:
      members =
          (List.of(population)..sort((a, b) {
                final c = b.value.compareTo(a.value);
                return c != 0 ? c : newestFirst(a, b);
              }))
              .take(selection.count)
              .toList(growable: false);
    case FocusMode.above:
      members = threshold == null
          ? const []
          : (population.where((p) => p.value > threshold).toList()
              ..sort(newestFirst));
    case FocusMode.below:
      members = threshold == null
          ? const []
          : (population.where((p) => p.value < threshold).toList()
              ..sort(newestFirst));
  }
  return FocusGroup(
    members: List.unmodifiable(members),
    population: List.unmodifiable(population),
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/insights/domain/focus/focus_group_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/focus test/features/insights/domain/focus
git add lib/features/insights/domain/focus test/features/insights/domain/focus
git commit -m "feat(insights): select a Dive focus group by rank or threshold"
```

---

### Task 11: Factor rows from the repository

**Files:**
- Create: `lib/features/insights/domain/focus/focus_factor_row.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (add a method after `getSoloVsBuddyCount`; if the file passes 3,100 lines, put the method in a `part` file `insights_repository_focus.dart` as an extension, mirroring how migrations use part files)
- Test: `test/features/insights/data/repositories/focus_factor_rows_test.dart`

**Interfaces:**
- Produces: `class FocusFactorRow` (fields below); `Future<List<FocusFactorRow>> getFocusFactorRows({String? diverId, DiveFilterState filter = const DiveFilterState(), required VisibilityScale visibilityScale})`.

- [ ] **Step 1: Create the row model** `focus_factor_row.dart`

```dart
import 'package:flutter/foundation.dart';

/// One dive's factors for Dive focus, in storage units. Categorical values
/// are the stable keys the Insights distributions already emit, so the
/// existing label helpers can render them.
@immutable
class FocusFactorRow {
  const FocusFactorRow({
    required this.diveId,
    required this.dateTime,
    this.entryTime,
    this.maxDepth,
    this.avgDepth,
    this.durationMinutes,
    this.waterTemp,
    this.visibilityKey,
    this.currentStrength,
    this.waterType,
    this.entryMethod,
    this.siteId,
    this.siteName,
    this.diveType,
    this.gasClass,
    this.firstTankVolume,
    this.weight,
    this.suitKey,
    this.buddyKey,
  });

  final String diveId;

  /// `dive_date_time`, a wall-clock value stored as UTC.
  final DateTime dateTime;

  /// `entry_time` when recorded; preferred for time of day.
  final DateTime? entryTime;
  final double? maxDepth;
  final double? avgDepth;

  /// Runtime, falling back to bottom time, in minutes.
  final double? durationMinutes;
  final double? waterTemp;

  /// A `VisibilityBand` name or `legacy_<Visibility>`, as
  /// `getVisibilityDistribution` emits.
  final String? visibilityKey;

  /// A `CurrentStrength` enum name.
  final String? currentStrength;

  /// A `WaterType` enum name, falling back to the site's.
  final String? waterType;

  /// An `EntryMethod` enum name, falling back to the site's.
  final String? entryMethod;
  final String? siteId;
  final String? siteName;

  /// The dive type id or slug.
  final String? diveType;

  /// `air`, `nitrox` or `trimix`; null with no tanks.
  final String? gasClass;

  /// Litres of water capacity of the first tank by tank order.
  final double? firstTankVolume;

  /// Lead in kilograms.
  final double? weight;

  /// `drysuit`, `wetsuit:<mm>` or `unknown`; null with no suit linked.
  final String? suitKey;

  /// `solo` or `buddy`; null when neither is recorded.
  final String? buddyKey;
}
```

- [ ] **Step 2: Write the failing repository tests**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  const scale = VisibilityScale.tropical;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> dive(
    String id, {
    int day = 1,
    bool excluded = false,
    bool planned = false,
    double? maxDepth = 20,
    int? runtime = 2700,
    int? bottomTime = 2400,
    String? diverRole,
    String? buddy,
    double? visibilityMeters,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(id),
        diveDateTime: Value(DateTime.utc(2025, 3, day, 9).millisecondsSinceEpoch),
        maxDepth: Value(maxDepth),
        avgDepth: const Value(12),
        runtime: Value(runtime),
        bottomTime: Value(bottomTime),
        waterTemp: const Value(24),
        weightAmount: const Value(6),
        diverRole: Value(diverRole),
        buddy: Value(buddy),
        visibilityMeters: Value(visibilityMeters),
        excludedFromStats: Value(excluded),
        isPlanned: Value(planned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> tank(String diveId, int order, double volume, double o2,
      [double he = 0]) =>
      db.into(db.diveTanks).insert(
        DiveTanksCompanion(
          id: Value('t-$diveId-$order'),
          diveId: Value(diveId),
          volume: Value(volume),
          o2Percent: Value(o2),
          hePercent: Value(he),
          tankOrder: Value(order),
        ),
      );

  test('excluded and planned dives are out of scope', () async {
    await dive('in');
    await dive('out', excluded: true);
    await dive('plan', planned: true);
    final result = await repository.getFocusFactorRows(visibilityScale: scale);
    expect(result.map((r) => r.diveId), ['in']);
  });

  test('duration prefers runtime and falls back to bottom time', () async {
    await dive('rt', runtime: 3000, bottomTime: 2400);
    await dive('bt', day: 2, runtime: null, bottomTime: 1800);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['rt']!.durationMinutes, 50);
    expect(byId['bt']!.durationMinutes, 30);
  });

  test('gas class and first tank follow the tanks', () async {
    await dive('air');
    await tank('air', 0, 11.1, 21);
    await dive('nx', day: 2);
    await tank('nx', 1, 7, 50);
    await tank('nx', 0, 12, 32);
    await dive('tx', day: 3);
    await tank('tx', 0, 24, 18, 45);
    await dive('none', day: 4);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['air']!.gasClass, 'air');
    expect(byId['nx']!.gasClass, 'nitrox');
    expect(byId['nx']!.firstTankVolume, 12);
    expect(byId['tx']!.gasClass, 'trimix');
    expect(byId['none']!.gasClass, isNull);
    expect(byId['none']!.firstTankVolume, isNull);
  });

  test('solo and buddy follow the social page rules', () async {
    await dive('solo', diverRole: DiveRole.soloId);
    await dive('buddy', day: 2, buddy: 'Sam Lee');
    await dive('unknown', day: 3);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['solo']!.buddyKey, 'solo');
    expect(byId['buddy']!.buddyKey, 'buddy');
    expect(byId['unknown']!.buddyKey, isNull);
  });

  test('visibility uses the diver scale bands', () async {
    await dive('clear', visibilityMeters: 40);
    await dive('none', day: 2);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['clear']!.visibilityKey, 'excellent');
    expect(byId['none']!.visibilityKey, isNull);
  });

  test('suits classify as drysuit, wetsuit thickness, or unknown', () async {
    final equipment = EquipmentRepository();
    final dives = DiveRepository();
    final wet = await equipment.createEquipment(
      EquipmentItem(
        id: 'w5',
        name: 'Wetsuit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'w5',
            key: 'thickness_mm',
            valueText: '5',
            valueNum: 5,
          ),
        ],
      ),
    );
    final dry = await equipment.createEquipment(
      const EquipmentItem(id: 'dry', name: 'Dry', type: EquipmentType.drysuit),
    );
    final bare = await equipment.createEquipment(
      const EquipmentItem(id: 'w?', name: 'Old', type: EquipmentType.wetsuit),
    );
    await dives.createDive(
      domain.Dive(id: 'wet', dateTime: DateTime(2025, 3, 1), gear: looseGear([wet])),
    );
    await dives.createDive(
      domain.Dive(id: 'dry', dateTime: DateTime(2025, 3, 2), gear: looseGear([dry, wet])),
    );
    await dives.createDive(
      domain.Dive(id: 'bare', dateTime: DateTime(2025, 3, 3), gear: looseGear([bare])),
    );
    await dives.createDive(
      domain.Dive(id: 'nosuit', dateTime: DateTime(2025, 3, 4)),
    );
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['wet']!.suitKey, 'wetsuit:5');
    expect(byId['dry']!.suitKey, 'drysuit');
    expect(byId['bare']!.suitKey, 'unknown');
    expect(byId['nosuit']!.suitKey, isNull);
  });

  test('the Insights filter applies', () async {
    await dive('shallow', maxDepth: 8);
    await dive('deep', day: 2, maxDepth: 30);
    final result = await repository.getFocusFactorRows(
      visibilityScale: scale,
      filter: const DiveFilterState(minDepth: 15),
    );
    expect(result.map((r) => r.diveId), ['deep']);
  });
}
```

`VisibilityScale.tropical` is the app's default scale; its `excellentAtOrAboveM` is below 40 m, so the 40 m dive lands in `excellent`.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/data/repositories/focus_factor_rows_test.dart`
Expected: FAIL, `getFocusFactorRows` undefined.

- [ ] **Step 4: Implement the query**

```dart
  /// One row of Dive focus factors per in-scope dive (issue #1611).
  ///
  /// Scoped like every descriptive aggregate. The comparison baseline is
  /// narrowed further by the caller to the dives that have the ranked
  /// metric, so a gas-excluded dive drops out there, not here.
  Future<List<FocusFactorRow>> getFocusFactorRows({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    required VisibilityScale visibilityScale,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      // Drift binds positionally: the visibility thresholds and the Solo
      // role id sit in the SELECT list, ahead of the WHERE placeholders.
      final params = [
        visibilityScale.excellentAtOrAboveM,
        visibilityScale.goodAtOrAboveM,
        visibilityScale.moderateAtOrAboveM,
        DiveRole.soloId,
        ?diverId,
        ...df.params,
      ];

      final results = await _db.customSelect('''
        SELECT
          d.id,
          d.dive_date_time,
          d.entry_time,
          d.max_depth,
          d.avg_depth,
          COALESCE(d.runtime, d.bottom_time) / 60.0 AS duration_minutes,
          d.water_temp,
          CASE
            WHEN d.visibility_meters IS NOT NULL THEN
              CASE
                WHEN d.visibility_meters >= ? THEN 'excellent'
                WHEN d.visibility_meters >= ? THEN 'good'
                WHEN d.visibility_meters >= ? THEN 'moderate'
                ELSE 'poor'
              END
            ELSE 'legacy_' || NULLIF(d.visibility, '')
          END AS visibility_key,
          NULLIF(d.current_strength, '') AS current_strength,
          COALESCE(NULLIF(d.water_type, ''), NULLIF(s.water_type, ''))
            AS water_type,
          COALESCE(NULLIF(d.entry_method, ''), NULLIF(s.entry_method, ''))
            AS entry_method,
          d.site_id,
          s.name AS site_name,
          NULLIF(d.dive_type, '') AS dive_type,
          (SELECT CASE
              WHEN COUNT(*) = 0 THEN NULL
              WHEN MAX(t.he_percent) > 0 THEN 'trimix'
              WHEN MAX(t.o2_percent) > 21.5 THEN 'nitrox'
              ELSE 'air'
            END
            FROM dive_tanks t WHERE t.dive_id = d.id) AS gas_class,
          (SELECT t.volume FROM dive_tanks t WHERE t.dive_id = d.id
            ORDER BY t.tank_order LIMIT 1) AS first_tank_volume,
          d.weight_amount,
          (SELECT CASE
              WHEN COUNT(e.id) = 0 THEN NULL
              WHEN MAX(e.type = 'drysuit') = 1 THEN 'drysuit'
              WHEN MAX(ea.value_num) IS NOT NULL
                THEN 'wetsuit:' || MAX(ea.value_num)
              ELSE 'unknown'
            END
            FROM dive_equipment de
            JOIN equipment e ON e.id = de.equipment_id
              AND e.type IN ('wetsuit', 'drysuit')
            LEFT JOIN equipment_attributes ea ON ea.equipment_id = e.id
              AND e.type = 'wetsuit'
              AND ea.attr_key = 'thickness_mm'
              AND ea.is_custom = 0
              AND ea.value_num IS NOT NULL
            WHERE de.dive_id = d.id) AS suit_key,
          EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
            AS has_linked_buddy,
          NULLIF(TRIM(d.buddy), '') AS buddy_text,
          COALESCE(d.diver_role = ?, 0) AS is_solo
        FROM dives d
        LEFT JOIN dive_sites s ON s.id = d.site_id
        WHERE 1 = 1 $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return [
        for (final row in results)
          FocusFactorRow(
            diveId: row.read<String>('id'),
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('dive_date_time'),
              isUtc: true,
            ),
            entryTime: switch (row.read<int?>('entry_time')) {
              final ms? => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
              null => null,
            },
            maxDepth: row.read<double?>('max_depth'),
            avgDepth: row.read<double?>('avg_depth'),
            durationMinutes: row.read<double?>('duration_minutes'),
            waterTemp: row.read<double?>('water_temp'),
            visibilityKey: row.read<String?>('visibility_key'),
            currentStrength: row.read<String?>('current_strength'),
            waterType: row.read<String?>('water_type'),
            entryMethod: row.read<String?>('entry_method'),
            siteId: row.read<String?>('site_id'),
            siteName: row.read<String?>('site_name'),
            diveType: row.read<String?>('dive_type'),
            gasClass: row.read<String?>('gas_class'),
            firstTankVolume: row.read<double?>('first_tank_volume'),
            weight: row.read<double?>('weight_amount'),
            suitKey: _suitKey(row.read<String?>('suit_key')),
            buddyKey: _buddyKey(
              hasLinked: row.read<bool>('has_linked_buddy'),
              text: row.read<String?>('buddy_text'),
              isSolo: row.read<bool>('is_solo'),
            ),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive focus factor rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// SQLite renders a REAL as "5.0"; the key drops a whole number's ".0" so
  /// it reads "wetsuit:5" like the progression page's "5 mm".
  static String? _suitKey(String? raw) {
    if (raw == null || !raw.startsWith('wetsuit:')) return raw;
    final mm = double.tryParse(raw.substring('wetsuit:'.length));
    if (mm == null) return 'unknown';
    return mm == mm.roundToDouble()
        ? 'wetsuit:${mm.toStringAsFixed(0)}'
        : 'wetsuit:$mm';
  }

  /// The same rule `getSoloVsBuddyCount` applies, per dive.
  static String? _buddyKey({
    required bool hasLinked,
    required String? text,
    required bool isSolo,
  }) {
    if (hasLinked || LegacyNameParser.parse(text).isNotEmpty) return 'buddy';
    return isSolo ? 'solo' : null;
  }
```

Add imports for `focus_factor_row.dart` and `VisibilityScale` (`package:submersion/core/domain/visibility/visibility_scale.dart`) if the repository does not already import it. Check the column names against `lib/core/database/tables/dive_tables.dart` (`visibility_meters`, `current_strength`, `weight_amount`, `dive_type`, `diver_role`) and `dive_sites` (`water_type`, `entry_method`, `name`) before running.

- [ ] **Step 5: Run to verify pass, plus the scope census**

Run: `flutter test test/features/insights/data/repositories/focus_factor_rows_test.dart test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/domain/focus/focus_factor_row.dart lib/features/insights/data/repositories/ test/features/insights/data/repositories/focus_factor_rows_test.dart
git commit -m "feat(insights): read Dive focus factors per dive"
```

---

### Task 12: FocusFactorAnalyzer

**Files:**
- Create: `lib/features/insights/domain/focus/focus_factor.dart`
- Create: `lib/features/insights/domain/focus/focus_factor_analyzer.dart`
- Test: `test/features/insights/domain/focus/focus_factor_analyzer_test.dart`

**Interfaces:**
- Consumes: `FocusFactorRow` (Task 11), `FocusMetric` (Task 10).
- Produces: `enum FocusFactorGroup { diveShape, conditions, whenWhere, kitGas }`; `enum FocusFactorId` (values below) with `FocusFactorGroup get group`, `bool get isNumeric`; `sealed class FocusFactor { FocusFactorId id; int groupCovered; int groupSize; bool get standsOut; }`; `NumericFactor(... double? groupMean, double? baselineMean, bool standsOut)` with `double? get difference`; `CategoryShare({String key, String? label, double groupShare, double baselineShare, int groupCount, bool standsOut})`; `CategoricalFactor(... List<CategoryShare> top)`; `FocusFactorReport({List<FocusFactor> factors, bool tooFewDives})` with `List<FocusFactor> get standouts`; `abstract final class FocusFactorAnalyzer { static FocusFactorReport analyze({required List<FocusFactorRow> group, required List<FocusFactorRow> baseline, required FocusMetric metric}); static String timeOfDayKey(DateTime wallClock); }`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_analyzer.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

FocusFactorRow row(
  String id, {
  double? maxDepth,
  String? entry,
  int month = 3,
  int hour = 9,
  String? siteId,
  String? siteName,
}) => FocusFactorRow(
  diveId: id,
  dateTime: DateTime.utc(2025, month, 1, hour),
  maxDepth: maxDepth,
  entryMethod: entry,
  siteId: siteId,
  siteName: siteName,
);

T factor<T extends FocusFactor>(FocusFactorReport r, FocusFactorId id) =>
    r.factors.firstWhere((f) => f.id == id) as T;

void main() {
  final baseline = [
    for (var i = 0; i < 10; i++)
      row(
        'b$i',
        maxDepth: 10.0 + i * 2,
        entry: i < 4 ? 'boat' : 'shore',
      ),
  ];

  test('fewer than three dives is too few', () {
    final report = FocusFactorAnalyzer.analyze(
      group: baseline.take(2).toList(),
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    expect(report.tooFewDives, isTrue);
    expect(report.factors, isEmpty);
  });

  test('a numeric factor compares means and flags half a deviation', () {
    final group = baseline.take(3).toList(); // depths 10, 12, 14
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final depth = factor<NumericFactor>(report, FocusFactorId.maxDepth);
    expect(depth.groupMean, 12);
    expect(depth.baselineMean, 19);
    expect(depth.difference, -7);
    // Baseline sd of 10..28 step 2 is about 5.74; 7 > 2.87.
    expect(depth.standsOut, isTrue);
    expect(report.standouts, contains(depth));
  });

  test('a small numeric difference does not stand out', () {
    final group = [baseline[4], baseline[5], baseline[6]]; // 18, 20, 22
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    expect(
      factor<NumericFactor>(report, FocusFactorId.maxDepth).standsOut,
      isFalse,
    );
  });

  test('a categorical factor reports shares and flags a 20 point lead', () {
    final group = baseline.take(3).toList(); // all boat
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final entry = factor<CategoricalFactor>(report, FocusFactorId.entryMethod);
    final boat = entry.top.first;
    expect(boat.key, 'boat');
    expect(boat.groupShare, 1.0);
    expect(boat.baselineShare, 0.4);
    expect(boat.groupCount, 3);
    expect(boat.standsOut, isTrue);
  });

  test('coverage counts only the group dives that recorded a factor', () {
    final group = [
      row('x', maxDepth: 10),
      row('y'),
      row('z', maxDepth: 12),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: [...group, ...baseline],
      metric: FocusMetric.rmv,
    );
    final depth = factor<NumericFactor>(report, FocusFactorId.maxDepth);
    expect(depth.groupCovered, 2);
    expect(depth.groupSize, 3);
  });

  test('a factor nobody in the group recorded has no mean', () {
    final report = FocusFactorAnalyzer.analyze(
      group: baseline.take(3).toList(),
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final temp = factor<NumericFactor>(report, FocusFactorId.waterTemp);
    expect(temp.groupCovered, 0);
    expect(temp.groupMean, isNull);
    expect(temp.standsOut, isFalse);
  });

  test('the ranking metric own factor is left out', () {
    FocusFactorReport run(FocusMetric m) => FocusFactorAnalyzer.analyze(
      group: baseline.take(3).toList(),
      baseline: baseline,
      metric: m,
    );
    Set<FocusFactorId> ids(FocusMetric m) =>
        run(m).factors.map((f) => f.id).toSet();
    expect(ids(FocusMetric.maxDepth), isNot(contains(FocusFactorId.maxDepth)));
    expect(
      ids(FocusMetric.bottomTime),
      isNot(contains(FocusFactorId.duration)),
    );
    expect(ids(FocusMetric.weight), isNot(contains(FocusFactorId.weight)));
    expect(
      ids(FocusMetric.waterTemp),
      isNot(contains(FocusFactorId.waterTemp)),
    );
    expect(ids(FocusMetric.rmv), hasLength(FocusFactorId.values.length));
  });

  test('months and time of day come from the date', () {
    final group = [
      row('a', month: 7, hour: 5),
      row('b', month: 7, hour: 7),
      row('c', month: 7, hour: 20),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: group,
      metric: FocusMetric.rmv,
    );
    expect(
      factor<CategoricalFactor>(report, FocusFactorId.month).top.single.key,
      '7',
    );
    expect(
      factor<CategoricalFactor>(report, FocusFactorId.timeOfDay)
          .top
          .map((s) => s.key),
      containsAll(['Night', 'Morning', 'Evening']),
    );
  });

  test('a site share carries the site name as its label', () {
    final group = [
      for (var i = 0; i < 3; i++)
        row('s$i', siteId: 'reef', siteName: 'House Reef'),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: group,
      metric: FocusMetric.rmv,
    );
    final site = factor<CategoricalFactor>(report, FocusFactorId.site);
    expect(site.top.single.label, 'House Reef');
  });

  test('time of day uses the Time patterns buckets', () {
    expect(FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 5)), 'Night');
    expect(FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 6)), 'Morning');
    expect(FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 12)), 'Afternoon');
    expect(FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 18)), 'Evening');
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/domain/focus/focus_factor_analyzer_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `focus_factor.dart`**

```dart
import 'package:flutter/foundation.dart';

enum FocusFactorGroup { diveShape, conditions, whenWhere, kitGas }

/// Every factor the Dive focus table compares, in display order.
enum FocusFactorId {
  maxDepth(FocusFactorGroup.diveShape, numeric: true),
  avgDepth(FocusFactorGroup.diveShape, numeric: true),
  duration(FocusFactorGroup.diveShape, numeric: true),
  waterTemp(FocusFactorGroup.conditions, numeric: true),
  visibility(FocusFactorGroup.conditions),
  current(FocusFactorGroup.conditions),
  waterType(FocusFactorGroup.conditions),
  entryMethod(FocusFactorGroup.conditions),
  month(FocusFactorGroup.whenWhere),
  timeOfDay(FocusFactorGroup.whenWhere),
  site(FocusFactorGroup.whenWhere),
  diveType(FocusFactorGroup.whenWhere),
  gas(FocusFactorGroup.kitGas),
  tankVolume(FocusFactorGroup.kitGas, numeric: true),
  weight(FocusFactorGroup.kitGas, numeric: true),
  suit(FocusFactorGroup.kitGas),
  buddy(FocusFactorGroup.kitGas);

  const FocusFactorId(this.group, {this.numeric = false});

  final FocusFactorGroup group;
  final bool numeric;

  bool get isNumeric => numeric;
}

/// One row of the common-factors table.
@immutable
sealed class FocusFactor {
  const FocusFactor({
    required this.id,
    required this.groupCovered,
    required this.groupSize,
  });

  final FocusFactorId id;

  /// Group dives that recorded this factor.
  final int groupCovered;
  final int groupSize;

  bool get standsOut;
}

final class NumericFactor extends FocusFactor {
  const NumericFactor({
    required super.id,
    required super.groupCovered,
    required super.groupSize,
    required this.groupMean,
    required this.baselineMean,
    required this.standsOut,
  });

  final double? groupMean;
  final double? baselineMean;

  @override
  final bool standsOut;

  double? get difference => groupMean == null || baselineMean == null
      ? null
      : groupMean! - baselineMean!;
}

@immutable
class CategoryShare {
  const CategoryShare({
    required this.key,
    required this.groupShare,
    required this.baselineShare,
    required this.groupCount,
    required this.standsOut,
    this.label,
  });

  /// The stable key the label helpers render.
  final String key;

  /// Display text the key alone cannot give (a site's name).
  final String? label;
  final double groupShare;
  final double baselineShare;
  final int groupCount;
  final bool standsOut;
}

final class CategoricalFactor extends FocusFactor {
  const CategoricalFactor({
    required super.id,
    required super.groupCovered,
    required super.groupSize,
    required this.top,
  });

  /// The group's most common values, most common first.
  final List<CategoryShare> top;

  @override
  bool get standsOut => top.any((s) => s.standsOut);
}

@immutable
class FocusFactorReport {
  const FocusFactorReport({required this.factors, required this.tooFewDives});

  final List<FocusFactor> factors;

  /// The group is below the minimum size, so nothing was compared.
  final bool tooFewDives;

  List<FocusFactor> get standouts =>
      factors.where((f) => f.standsOut).toList(growable: false);
}
```

- [ ] **Step 4: Implement `focus_factor_analyzer.dart`**

```dart
import 'dart:math' as math;

import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

/// Compares a Dive focus group's factors with its baseline (issue #1611).
///
/// "Stands out" is an effect size, not a significance test: with ten dives a
/// p-value mostly says nothing, while half a baseline standard deviation
/// answers "is this big next to my usual spread?".
abstract final class FocusFactorAnalyzer {
  static const int minGroupSize = 3;
  static const double standoutDeviations = 0.5;
  static const double standoutSharePoints = 0.20;
  static const int standoutMinCount = 2;
  static const int topCategories = 3;

  static FocusFactorReport analyze({
    required List<FocusFactorRow> group,
    required List<FocusFactorRow> baseline,
    required FocusMetric metric,
  }) {
    if (group.length < minGroupSize) {
      return const FocusFactorReport(factors: [], tooFewDives: true);
    }
    final skip = _selfFactor(metric);
    return FocusFactorReport(
      tooFewDives: false,
      factors: [
        for (final id in FocusFactorId.values)
          if (id != skip)
            id.isNumeric
                ? _numeric(id, group, baseline)
                : _categorical(id, group, baseline),
      ],
    );
  }

  /// The Time patterns page's buckets, on the stored wall clock.
  static String timeOfDayKey(DateTime wallClock) => switch (wallClock.hour) {
    < 6 => 'Night',
    < 12 => 'Morning',
    < 18 => 'Afternoon',
    _ => 'Evening',
  };

  static FocusFactorId? _selfFactor(FocusMetric metric) => switch (metric) {
    FocusMetric.maxDepth => FocusFactorId.maxDepth,
    FocusMetric.bottomTime => FocusFactorId.duration,
    FocusMetric.weight => FocusFactorId.weight,
    FocusMetric.waterTemp => FocusFactorId.waterTemp,
    FocusMetric.rmv || FocusMetric.sac => null,
  };

  static double? _number(FocusFactorId id, FocusFactorRow r) => switch (id) {
    FocusFactorId.maxDepth => r.maxDepth,
    FocusFactorId.avgDepth => r.avgDepth,
    FocusFactorId.duration => r.durationMinutes,
    FocusFactorId.waterTemp => r.waterTemp,
    FocusFactorId.tankVolume => r.firstTankVolume,
    FocusFactorId.weight => r.weight,
    _ => null,
  };

  static String? _category(FocusFactorId id, FocusFactorRow r) =>
      switch (id) {
        FocusFactorId.visibility => r.visibilityKey,
        FocusFactorId.current => r.currentStrength,
        FocusFactorId.waterType => r.waterType,
        FocusFactorId.entryMethod => r.entryMethod,
        FocusFactorId.month => '${r.dateTime.month}',
        FocusFactorId.timeOfDay => timeOfDayKey(r.entryTime ?? r.dateTime),
        FocusFactorId.site => r.siteId,
        FocusFactorId.diveType => r.diveType,
        FocusFactorId.gas => r.gasClass,
        FocusFactorId.suit => r.suitKey,
        FocusFactorId.buddy => r.buddyKey,
        _ => null,
      };

  static NumericFactor _numeric(
    FocusFactorId id,
    List<FocusFactorRow> group,
    List<FocusFactorRow> baseline,
  ) {
    final g = [for (final r in group) ?_number(id, r)];
    final b = [for (final r in baseline) ?_number(id, r)];
    final gMean = _mean(g);
    final bMean = _mean(b);
    final sd = _sd(b, bMean);
    final standsOut =
        gMean != null &&
        bMean != null &&
        sd > 0 &&
        (gMean - bMean).abs() >= standoutDeviations * sd;
    return NumericFactor(
      id: id,
      groupCovered: g.length,
      groupSize: group.length,
      groupMean: gMean,
      baselineMean: bMean,
      standsOut: standsOut,
    );
  }

  static CategoricalFactor _categorical(
    FocusFactorId id,
    List<FocusFactorRow> group,
    List<FocusFactorRow> baseline,
  ) {
    Map<String, int> counts(List<FocusFactorRow> rows) {
      final out = <String, int>{};
      for (final r in rows) {
        final key = _category(id, r);
        if (key != null) out[key] = (out[key] ?? 0) + 1;
      }
      return out;
    }

    final g = counts(group);
    final b = counts(baseline);
    final gTotal = g.values.fold<int>(0, (s, c) => s + c);
    final bTotal = b.values.fold<int>(0, (s, c) => s + c);
    final labels = id == FocusFactorId.site
        ? {
            for (final r in [...baseline, ...group])
              if (r.siteId != null && r.siteName != null)
                r.siteId!: r.siteName!,
          }
        : const <String, String>{};

    final ranked = g.entries.toList()
      ..sort((x, y) {
        final c = y.value.compareTo(x.value);
        return c != 0 ? c : x.key.compareTo(y.key);
      });
    final top = [
      for (final e in ranked.take(topCategories))
        () {
          final groupShare = gTotal == 0 ? 0.0 : e.value / gTotal;
          final baselineShare = bTotal == 0 ? 0.0 : (b[e.key] ?? 0) / bTotal;
          return CategoryShare(
            key: e.key,
            label: labels[e.key],
            groupShare: groupShare,
            baselineShare: baselineShare,
            groupCount: e.value,
            standsOut:
                e.value >= standoutMinCount &&
                groupShare - baselineShare >= standoutSharePoints - 1e-9,
          );
        }(),
    ];
    return CategoricalFactor(
      id: id,
      groupCovered: gTotal,
      groupSize: group.length,
      top: List.unmodifiable(top),
    );
  }

  static double? _mean(List<double> values) => values.isEmpty
      ? null
      : values.fold<double>(0, (s, v) => s + v) / values.length;

  /// Population standard deviation; 0 for fewer than two values.
  static double _sd(List<double> values, double? mean) {
    if (mean == null || values.length < 2) return 0;
    final variance =
        values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
        values.length;
    return math.sqrt(variance);
  }
}
```

If the analyzer does not compile on the null-aware list element `?_number(id, r)`, the SDK is below 3.8; use `if (_number(id, r) case final v?) v` instead.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/insights/domain/focus/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/insights/domain/focus test/features/insights/domain/focus
git add lib/features/insights/domain/focus test/features/insights/domain/focus
git commit -m "feat(insights): compare a Dive focus group's common factors"
```

---

### Task 13: Focus providers and metric unit conversion

**Files:**
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart:109-117` (expose the keep-alive helper)
- Create: `lib/features/insights/presentation/providers/insights_focus_providers.dart`
- Create: `lib/features/insights/presentation/formatters/focus_metric_units.dart`
- Test: `test/features/insights/presentation/providers/insights_focus_providers_test.dart`
- Test: `test/features/insights/presentation/formatters/focus_metric_units_test.dart`

**Interfaces:**
- Consumes: Tasks 10 to 12.
- Produces: `void keepInsightsProviderAlive(Ref ref)`; `focusSelectionProvider` (`StateProvider<FocusSelection>`); `focusMetricSeriesProvider` (`FutureProvider.family<List<TrendDataPoint>, FocusMetric>`); `focusGroupProvider` (`FutureProvider<FocusGroup>`); `focusFactorRowsProvider` (`FutureProvider<List<FocusFactorRow>>`); `focusFactorReportProvider` (`FutureProvider<FocusFactorReport>`); `class FocusMetricUnits(FocusMetric metric, UnitFormatter units)` with `String symbol(AppLocalizations l10n)`, `double toDisplay(double)`, `double toStorage(double)`, `String format(double storage, AppLocalizations l10n)`, `bool get allowsNegative`.

- [ ] **Step 1: Write the failing unit-conversion tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );
  const metric = UnitFormatter(AppSettings());

  test('an imperial RMV threshold converts to litres per minute', () {
    final u = FocusMetricUnits(FocusMetric.rmv, imperial);
    expect(u.toStorage(0.75), closeTo(21.24, 0.01));
    expect(u.toDisplay(u.toStorage(0.75)), closeTo(0.75, 1e-9));
  });

  test('a Fahrenheit water temp converts to Celsius', () {
    final u = FocusMetricUnits(FocusMetric.waterTemp, imperial);
    expect(u.toStorage(50), closeTo(10, 1e-9));
  });

  test('depth in feet converts to metres', () {
    expect(
      FocusMetricUnits(FocusMetric.maxDepth, imperial).toStorage(100),
      closeTo(30.48, 1e-6),
    );
  });

  test('bottom time is minutes in every unit system', () {
    expect(FocusMetricUnits(FocusMetric.bottomTime, imperial).toStorage(40), 40);
    expect(FocusMetricUnits(FocusMetric.bottomTime, metric).toStorage(40), 40);
  });

  test('only water temp may go below zero', () {
    for (final m in FocusMetric.values) {
      expect(
        FocusMetricUnits(m, metric).allowsNegative,
        m == FocusMetric.waterTemp,
      );
    }
  });
}
```

Check the `AppSettings` import and the unit enum names against `lib/features/settings/presentation/providers/settings_providers.dart` and `lib/core/constants/units.dart`; adjust the constructor arguments to the real field names before running.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/formatters/focus_metric_units_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 3: Implement `focus_metric_units.dart`**

```dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One [FocusMetric] in the diver's units: its symbol, conversion both ways,
/// and formatting. Storage is litres or bar per minute, metres, minutes,
/// kilograms and Celsius.
class FocusMetricUnits {
  const FocusMetricUnits(this.metric, this.units);

  final FocusMetric metric;
  final UnitFormatter units;

  /// Sub-zero water is real (ice diving); nothing else can be negative.
  bool get allowsNegative => metric == FocusMetric.waterTemp;

  String symbol(AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.rmvSymbol,
    FocusMetric.sac => units.sacSymbol,
    FocusMetric.maxDepth => units.depthSymbol,
    FocusMetric.bottomTime => l10n.insights_focus_unit_minutes,
    FocusMetric.weight => units.weightSymbol,
    FocusMetric.waterTemp => units.temperatureSymbol,
  };

  double toDisplay(double storage) => switch (metric) {
    FocusMetric.rmv => units.convertRmv(storage),
    FocusMetric.sac => units.convertSac(storage),
    FocusMetric.maxDepth => units.convertDepth(storage),
    FocusMetric.bottomTime => storage,
    FocusMetric.weight => units.convertWeight(storage),
    FocusMetric.waterTemp => units.convertTemperature(storage),
  };

  double toStorage(double display) => switch (metric) {
    FocusMetric.rmv => units.volumeToLiters(display),
    FocusMetric.sac => units.pressureToBar(display),
    FocusMetric.maxDepth => units.depthToMeters(display),
    FocusMetric.bottomTime => display,
    FocusMetric.weight => units.weightToKg(display),
    FocusMetric.waterTemp => units.temperatureToCelsius(display),
  };

  String format(double storage, AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.formatRmv(storage),
    FocusMetric.sac => units.formatSac(storage),
    FocusMetric.maxDepth => units.formatDepth(storage),
    FocusMetric.bottomTime => l10n.surfaceInterval_format_minutes(
      storage.toStringAsFixed(0),
    ),
    FocusMetric.weight => units.formatWeight(storage),
    FocusMetric.waterTemp => units.formatTemperature(storage),
  };
}
```

Add to `app_en.arb` (a new `insights_focus_` block directly after `"insights_gas_sacTrend_title"`):

```json
  "insights_focus_unit_minutes": "min",
```

Run `flutter gen-l10n`, then rerun the test: PASS.

- [ ] **Step 4: Expose the keep-alive helper**

In `insights_providers.dart`, directly under `_keepAliveWithExpiry`, add:

```dart
/// [_keepAliveWithExpiry] for Insights providers declared in other files.
void keepInsightsProviderAlive(Ref ref) => _keepAliveWithExpiry(ref);
```

- [ ] **Step 5: Write the failing provider tests**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';

void main() {
  final rmv = [
    for (var i = 0; i < 6; i++)
      TrendDataPoint(
        date: DateTime.utc(2025, 1, i + 1),
        value: 10.0 + i,
        diveId: 'd$i',
      ),
  ];
  final depth = [
    TrendDataPoint(date: DateTime.utc(2025), value: 30, diveId: 'd0'),
  ];
  final rows = [
    for (var i = 0; i < 6; i++)
      FocusFactorRow(
        diveId: 'd$i',
        dateTime: DateTime.utc(2025, 1, i + 1),
        maxDepth: i < 3 ? 10 : 30,
      ),
    FocusFactorRow(diveId: 'noRmv', dateTime: DateTime.utc(2025), maxDepth: 99),
  ];

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        focusMetricSeriesProvider(FocusMetric.rmv).overrideWith(
          (ref) async => rmv,
        ),
        focusMetricSeriesProvider(FocusMetric.maxDepth).overrideWith(
          (ref) async => depth,
        ),
        focusFactorRowsProvider.overrideWith((ref) async => rows),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the default group is the best ten RMV dives', () async {
    final c = container();
    final group = await c.read(focusGroupProvider.future);
    expect(group.members.first.diveId, 'd0');
    expect(group.members, hasLength(6));
  });

  test('changing the selection re-picks the group', () async {
    final c = container();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.maxDepth,
      mode: FocusMode.highest,
      count: 1,
    );
    final group = await c.read(focusGroupProvider.future);
    expect(group.members.single.value, 30);
  });

  test('the baseline is only the dives that have the metric', () async {
    final c = container();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      count: 3,
    );
    final report = await c.read(focusFactorReportProvider.future);
    final depthFactor =
        report.factors.firstWhere((f) => f.id == FocusFactorId.maxDepth)
            as NumericFactor;
    expect(depthFactor.groupMean, 10);
    // Mean of d0..d5 only; the 99 m dive without an RMV is not baseline.
    expect(depthFactor.baselineMean, 20);
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/insights/presentation/providers/insights_focus_providers_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 7: Implement `insights_focus_providers.dart`**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_analyzer.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's Dive focus choice, for the session (issue #1611).
final focusSelectionProvider = StateProvider<FocusSelection>(
  (ref) => const FocusSelection(),
);

/// Per-dive values of [metric], from the same repository series the trend
/// charts draw, with the same filter and exclusion scope.
final focusMetricSeriesProvider =
    FutureProvider.family<List<TrendDataPoint>, FocusMetric>((
      ref,
      metric,
    ) async {
      keepInsightsProviderAlive(ref);
      final repository = ref.watch(insightsRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(insightsFilterProvider);
      return switch (metric) {
        FocusMetric.rmv => repository.getSacVolumePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.sac => repository.getSacPressurePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.maxDepth => repository.getDepthPerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.bottomTime => repository.getBottomTimePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.weight => repository.getWeightPerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.waterTemp => repository.getWaterTempPerDive(
          diverId: diverId,
          filter: filter,
        ),
      };
    });

/// The dives the current selection picks.
final focusGroupProvider = FutureProvider<FocusGroup>((ref) async {
  final selection = ref.watch(focusSelectionProvider);
  final series = await ref.watch(
    focusMetricSeriesProvider(selection.metric).future,
  );
  return selectFocusGroup(series, selection);
});

/// Factor rows for every in-scope dive.
final focusFactorRowsProvider = FutureProvider<List<FocusFactorRow>>((
  ref,
) async {
  keepInsightsProviderAlive(ref);
  final repository = ref.watch(insightsRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(insightsFilterProvider);
  final scale = ref.watch(settingsProvider.select((s) => s.visibilityScale));
  return repository.getFocusFactorRows(
    diverId: diverId,
    filter: filter,
    visibilityScale: scale,
  );
});

/// The group's factors against the dives that have the metric.
final focusFactorReportProvider = FutureProvider<FocusFactorReport>((
  ref,
) async {
  final selection = ref.watch(focusSelectionProvider);
  final group = await ref.watch(focusGroupProvider.future);
  final rows = await ref.watch(focusFactorRowsProvider.future);
  final byId = {for (final r in rows) r.diveId: r};
  List<FocusFactorRow> pick(Iterable<TrendDataPoint> points) => [
    for (final p in points) ?byId[p.diveId],
  ];
  return FocusFactorAnalyzer.analyze(
    group: pick(group.members),
    baseline: pick(group.population),
    metric: selection.metric,
  );
});
```

- [ ] **Step 8: Run to verify pass**

Run: `flutter test test/features/insights/presentation/providers/ test/features/insights/presentation/formatters/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/providers lib/features/insights/presentation/formatters/focus_metric_units.dart test/features/insights/presentation/providers/insights_focus_providers_test.dart test/features/insights/presentation/formatters/focus_metric_units_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): add Dive focus providers and metric units"
```

---

### Task 14: The group selector

**Files:**
- Create: `lib/features/insights/presentation/widgets/focus/focus_selector.dart`
- Create: `lib/features/insights/presentation/formatters/focus_labels.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/focus/focus_selector_test.dart`

**Interfaces:**
- Consumes: `focusSelectionProvider`, `FocusMetricUnits` (Task 13), `parseUserDecimal`, `formatRoundedForInput` (`lib/core/utils/number_input.dart`).
- Produces: `class FocusSelector extends ConsumerStatefulWidget` (no parameters); keys `focus-metric`, `focus-mode`, `focus-count-<n>`, `focus-count-field`, `focus-threshold-field`; `String focusMetricLabel(FocusMetric, AppLocalizations)`, `String focusModeLabel(FocusMode, FocusMetric, AppLocalizations)`.

- [ ] **Step 1: Add strings** to the `insights_focus_` block in `app_en.arb`, then `flutter gen-l10n`:

```json
  "insights_focus_metric_label": "Metric",
  "insights_focus_metric_rmv": "RMV",
  "insights_focus_metric_sac": "SAC",
  "insights_focus_metric_maxDepth": "Max depth",
  "insights_focus_metric_bottomTime": "Bottom time",
  "insights_focus_metric_weight": "Weight",
  "insights_focus_metric_waterTemp": "Water temp",
  "insights_focus_mode_best": "Best",
  "insights_focus_mode_worst": "Worst",
  "insights_focus_mode_lowest": "Lowest",
  "insights_focus_mode_highest": "Highest",
  "insights_focus_mode_above": "Above",
  "insights_focus_mode_below": "Below",
  "insights_focus_count_label": "Dives",
  "insights_focus_count_error": "Enter a whole number from 1 to 999",
  "insights_focus_threshold_label": "Value",
  "insights_focus_threshold_error": "Enter a number",
  "insights_focus_threshold_negativeError": "Enter zero or more",
```

- [ ] **Step 2: Write the label helpers** `focus_labels.dart`

```dart
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String focusMetricLabel(FocusMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      FocusMetric.rmv => l10n.insights_focus_metric_rmv,
      FocusMetric.sac => l10n.insights_focus_metric_sac,
      FocusMetric.maxDepth => l10n.insights_focus_metric_maxDepth,
      FocusMetric.bottomTime => l10n.insights_focus_metric_bottomTime,
      FocusMetric.weight => l10n.insights_focus_metric_weight,
      FocusMetric.waterTemp => l10n.insights_focus_metric_waterTemp,
    };

/// "Best" and "Worst" for gas consumption, where lower is better; "Lowest"
/// and "Highest" for metrics with no better end.
String focusModeLabel(
  FocusMode mode,
  FocusMetric metric,
  AppLocalizations l10n,
) => switch (mode) {
  FocusMode.lowest =>
    metric.lowerIsBetter
        ? l10n.insights_focus_mode_best
        : l10n.insights_focus_mode_lowest,
  FocusMode.highest =>
    metric.lowerIsBetter
        ? l10n.insights_focus_mode_worst
        : l10n.insights_focus_mode_highest,
  FocusMode.above => l10n.insights_focus_mode_above,
  FocusMode.below => l10n.insights_focus_mode_below,
};
```

- [ ] **Step 3: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_selector.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FocusSelector()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(FocusSelector)));
  }

  testWidgets('RMV offers Best and Worst; depth offers Lowest and Highest', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Worst'), findsOneWidget);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.maxDepth,
    );
    await tester.pump();
    expect(find.text('Lowest'), findsOneWidget);
    expect(find.text('Highest'), findsOneWidget);
  });

  testWidgets('a count chip sets N', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count-20')));
    await tester.pump();
    expect(c.read(focusSelectionProvider).count, 20);
  });

  testWidgets('an out-of-range count shows an error and keeps N', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('focus-count-field')), '0');
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 999'), findsOneWidget);
    expect(c.read(focusSelectionProvider).count, 10);
  });

  testWidgets('an imperial RMV threshold is stored in litres per minute', (
    tester,
  ) async {
    final c = await pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '0.75',
    );
    await tester.pump();
    final s = c.read(focusSelectionProvider);
    expect(s.mode, FocusMode.above);
    expect(s.threshold, closeTo(21.24, 0.01));
  });

  testWidgets('a negative RMV is rejected', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '-1',
    );
    await tester.pump();
    expect(find.text('Enter zero or more'), findsOneWidget);
    expect(c.read(focusSelectionProvider).threshold, isNull);
  });

  testWidgets('a sub-zero water temperature is accepted', (tester) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.waterTemp,
      mode: FocusMode.below,
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '-1',
    );
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(-1, 1e-9));
  });

  testWidgets('a comma decimal reads as a decimal in German', (tester) async {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);
    final c = await pump(tester);
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '0,75',
    );
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(0.75, 1e-9));
  });

  testWidgets('switching metric clears a threshold', (tester) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      mode: FocusMode.above,
      threshold: 20,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('focus-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max depth').last);
    await tester.pumpAndSettle();
    final s = c.read(focusSelectionProvider);
    expect(s.metric, FocusMetric.maxDepth);
    expect(s.threshold, isNull);
  });
}
```

Confirm the `VolumeUnit` import path and `AppSettings` field name with `grep -n "volumeUnit" lib/features/settings/presentation/providers/settings_providers.dart` before running.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_selector_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 5: Implement `focus_selector.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Metric, mode and value for Dive focus, on one wrapping row.
class FocusSelector extends ConsumerStatefulWidget {
  const FocusSelector({super.key});

  @override
  ConsumerState<FocusSelector> createState() => _FocusSelectorState();
}

class _FocusSelectorState extends ConsumerState<FocusSelector> {
  static const _countChips = [5, 10, 20];

  late final TextEditingController _count;
  late final TextEditingController _threshold;
  String? _countError;
  String? _thresholdError;

  @override
  void initState() {
    super.initState();
    final selection = ref.read(focusSelectionProvider);
    _count = TextEditingController(text: '${selection.count}');
    final threshold = selection.threshold;
    final units = FocusMetricUnits(
      selection.metric,
      UnitFormatter(ref.read(settingsProvider)),
    );
    _threshold = TextEditingController(
      text: threshold == null
          ? ''
          : formatRoundedForInput(units.toDisplay(threshold), 2),
    );
  }

  @override
  void dispose() {
    _count.dispose();
    _threshold.dispose();
    super.dispose();
  }

  void _set(FocusSelection next) =>
      ref.read(focusSelectionProvider.notifier).state = next;

  void _onCountChanged(String text, FocusSelection selection) {
    final n = int.tryParse(text.trim());
    final valid =
        n != null &&
        n >= FocusSelection.minCount &&
        n <= FocusSelection.maxCount;
    setState(
      () => _countError = valid ? null : context.l10n.insights_focus_count_error,
    );
    if (valid) _set(selection.copyWith(count: n));
  }

  void _onThresholdChanged(
    String text,
    FocusSelection selection,
    FocusMetricUnits units,
  ) {
    final value = parseUserDecimal(text);
    String? error;
    if (value == null) {
      error = text.trim().isEmpty
          ? null
          : context.l10n.insights_focus_threshold_error;
    } else if (value < 0 && !units.allowsNegative) {
      error = context.l10n.insights_focus_threshold_negativeError;
    }
    setState(() => _thresholdError = error);
    if (error == null && value != null) {
      _set(selection.copyWith(threshold: units.toStorage(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selection = ref.watch(focusSelectionProvider);
    final units = FocusMetricUnits(
      selection.metric,
      UnitFormatter(ref.watch(settingsProvider)),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<FocusMetric>(
          key: const ValueKey('focus-metric'),
          value: selection.metric,
          onChanged: (metric) {
            if (metric == null || metric == selection.metric) return;
            _threshold.clear();
            setState(() => _thresholdError = null);
            // A threshold means nothing in another metric's units.
            _set(selection.copyWith(metric: metric, clearThreshold: true));
          },
          items: [
            for (final m in FocusMetric.values)
              DropdownMenuItem(value: m, child: Text(focusMetricLabel(m, l10n))),
          ],
        ),
        SegmentedButton<FocusMode>(
          key: const ValueKey('focus-mode'),
          showSelectedIcon: false,
          segments: [
            for (final mode in FocusMode.values)
              ButtonSegment(
                value: mode,
                label: Text(focusModeLabel(mode, selection.metric, l10n)),
              ),
          ],
          selected: {selection.mode},
          onSelectionChanged: (modes) =>
              _set(selection.copyWith(mode: modes.first)),
        ),
        if (selection.mode.isRanked) ...[
          for (final n in _countChips)
            ChoiceChip(
              key: ValueKey('focus-count-$n'),
              label: Text('$n'),
              selected: selection.count == n,
              onSelected: (_) {
                _count.text = '$n';
                setState(() => _countError = null);
                _set(selection.copyWith(count: n));
              },
            ),
          SizedBox(
            width: 96,
            child: TextField(
              key: const ValueKey('focus-count-field'),
              controller: _count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.insights_focus_count_label,
                errorText: _countError,
                errorMaxLines: 3,
                isDense: true,
              ),
              onChanged: (text) => _onCountChanged(text, selection),
            ),
          ),
        ] else
          SizedBox(
            width: 180,
            child: TextField(
              key: const ValueKey('focus-threshold-field'),
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.insights_focus_threshold_label,
                suffixText: units.symbol(l10n),
                errorText: _thresholdError,
                errorMaxLines: 2,
                isDense: true,
              ),
              onChanged: (text) => _onThresholdChanged(text, selection, units),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_selector_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/widgets/focus/focus_selector.dart lib/features/insights/presentation/formatters/focus_labels.dart test/features/insights/presentation/widgets/focus/focus_selector_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): add the Dive focus group selector"
```

---

### Task 15: Common factors table

**Files:**
- Create: `lib/features/insights/presentation/formatters/focus_factor_labels.dart`
- Create: `lib/features/insights/presentation/widgets/focus/focus_factors_table.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/focus/focus_factors_table_test.dart`

**Interfaces:**
- Consumes: `FocusFactorReport`, `FocusFactor`, `CategoryShare` (Task 12); existing `visibilityDistributionLabel`, `waterTypeDistributionLabel`, `entryMethodDistributionLabel`, `diveTypeDistributionLabel`, `timeOfDayDistributionLabel`, `CurrentStrengthDisplay.localizedName`, `EquipmentType.drysuit.localizedName`.
- Produces: `FocusFactorsTable({required FocusFactorReport report})`; `String focusFactorName(FocusFactorId, AppLocalizations)`; `String focusCategoryLabel(FocusFactorId, CategoryShare, AppLocalizations, UnitFormatter)`; `String focusNumericValue(FocusFactorId, double, UnitFormatter, AppLocalizations)`.

- [ ] **Step 1: Add strings** to the `insights_focus_` block, then `flutter gen-l10n`:

```json
  "insights_focus_factors_title": "Common factors",
  "insights_focus_factors_subtitle": "This group compared with every dive that has the value",
  "insights_focus_factors_tooFew": "Choose at least 3 dives to compare common factors",
  "insights_focus_factors_standsOut": "Stands out",
  "insights_focus_factors_standoutsSummary": "Stands out: {factors}",
  "@insights_focus_factors_standoutsSummary": {
    "placeholders": { "factors": { "type": "String" } }
  },
  "insights_focus_factors_versus": "{group} vs {baseline}",
  "@insights_focus_factors_versus": {
    "placeholders": { "group": { "type": "String" }, "baseline": { "type": "String" } }
  },
  "insights_focus_factors_coverage": "{covered} of {total} dives",
  "@insights_focus_factors_coverage": {
    "placeholders": { "covered": { "type": "int" }, "total": { "type": "int" } }
  },
  "insights_focus_factorGroup_diveShape": "Dive shape",
  "insights_focus_factorGroup_conditions": "Conditions",
  "insights_focus_factorGroup_whenWhere": "When and where",
  "insights_focus_factorGroup_kitGas": "Kit and gas",
  "insights_focus_factor_avgDepth": "Average depth",
  "insights_focus_factor_duration": "Duration",
  "insights_focus_factor_visibility": "Visibility",
  "insights_focus_factor_current": "Current",
  "insights_focus_factor_waterType": "Water type",
  "insights_focus_factor_entryMethod": "Entry",
  "insights_focus_factor_month": "Month",
  "insights_focus_factor_timeOfDay": "Time of day",
  "insights_focus_factor_site": "Site",
  "insights_focus_factor_diveType": "Dive type",
  "insights_focus_factor_gas": "Gas",
  "insights_focus_factor_tankVolume": "Tank size",
  "insights_focus_factor_suit": "Suit",
  "insights_focus_factor_buddy": "Solo or buddy",
  "insights_focus_gas_air": "Air",
  "insights_focus_gas_nitrox": "Nitrox",
  "insights_focus_gas_trimix": "Trimix",
```

(Max depth, weight and water temp reuse the `insights_focus_metric_*` keys.)

- [ ] **Step 2: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, FocusFactorReport report) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FocusFactorsTable(report: report),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('too few dives shows the hint instead of a table', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(factors: [], tooFewDives: true),
    );
    expect(
      find.text('Choose at least 3 dives to compare common factors'),
      findsOneWidget,
    );
  });

  testWidgets('a standout numeric factor shows its chip and the summary', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.maxDepth,
            groupCovered: 3,
            groupSize: 4,
            groupMean: 12,
            baselineMean: 19,
            standsOut: true,
          ),
        ],
      ),
    );
    expect(find.text('Dive shape'), findsOneWidget);
    expect(find.text('Stands out'), findsOneWidget);
    expect(find.text('Stands out: Max depth'), findsOneWidget);
    expect(find.text('3 of 4 dives'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('a categorical factor lists shares as percentages', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          CategoricalFactor(
            id: FocusFactorId.gas,
            groupCovered: 4,
            groupSize: 4,
            top: [
              CategoryShare(
                key: 'nitrox',
                groupShare: 0.75,
                baselineShare: 0.4,
                groupCount: 3,
                standsOut: true,
              ),
            ],
          ),
        ],
      ),
    );
    expect(find.text('Gas'), findsOneWidget);
    expect(find.textContaining('Nitrox'), findsOneWidget);
    expect(find.textContaining('75%'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
  });

  testWidgets('a factor nobody recorded reads Not recorded', (tester) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.waterTemp,
            groupCovered: 0,
            groupSize: 3,
            groupMean: null,
            baselineMean: 24,
            standsOut: false,
          ),
        ],
      ),
    );
    expect(find.text('Not recorded'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_factors_table_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 4: Implement `focus_factor_labels.dart`**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_type_display.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String focusFactorName(FocusFactorId id, AppLocalizations l10n) =>
    switch (id) {
      FocusFactorId.maxDepth => l10n.insights_focus_metric_maxDepth,
      FocusFactorId.avgDepth => l10n.insights_focus_factor_avgDepth,
      FocusFactorId.duration => l10n.insights_focus_factor_duration,
      FocusFactorId.waterTemp => l10n.insights_focus_metric_waterTemp,
      FocusFactorId.visibility => l10n.insights_focus_factor_visibility,
      FocusFactorId.current => l10n.insights_focus_factor_current,
      FocusFactorId.waterType => l10n.insights_focus_factor_waterType,
      FocusFactorId.entryMethod => l10n.insights_focus_factor_entryMethod,
      FocusFactorId.month => l10n.insights_focus_factor_month,
      FocusFactorId.timeOfDay => l10n.insights_focus_factor_timeOfDay,
      FocusFactorId.site => l10n.insights_focus_factor_site,
      FocusFactorId.diveType => l10n.insights_focus_factor_diveType,
      FocusFactorId.gas => l10n.insights_focus_factor_gas,
      FocusFactorId.tankVolume => l10n.insights_focus_factor_tankVolume,
      FocusFactorId.weight => l10n.insights_focus_metric_weight,
      FocusFactorId.suit => l10n.insights_focus_factor_suit,
      FocusFactorId.buddy => l10n.insights_focus_factor_buddy,
    };

String focusFactorGroupName(FocusFactorGroup group, AppLocalizations l10n) =>
    switch (group) {
      FocusFactorGroup.diveShape => l10n.insights_focus_factorGroup_diveShape,
      FocusFactorGroup.conditions => l10n.insights_focus_factorGroup_conditions,
      FocusFactorGroup.whenWhere => l10n.insights_focus_factorGroup_whenWhere,
      FocusFactorGroup.kitGas => l10n.insights_focus_factorGroup_kitGas,
    };

/// A numeric factor's value in the diver's units.
String focusNumericValue(
  FocusFactorId id,
  double value,
  UnitFormatter units,
  AppLocalizations l10n,
) => switch (id) {
  FocusFactorId.maxDepth || FocusFactorId.avgDepth => units.formatDepth(value),
  FocusFactorId.duration => l10n.surfaceInterval_format_minutes(
    value.toStringAsFixed(0),
  ),
  FocusFactorId.waterTemp => units.formatTemperature(value),
  FocusFactorId.tankVolume => units.formatTankVolume(value, null),
  FocusFactorId.weight => units.formatWeight(value),
  _ => value.toStringAsFixed(1),
};

String _month(int month, AppLocalizations l10n) => [
  l10n.insights_timePatterns_month_jan,
  l10n.insights_timePatterns_month_feb,
  l10n.insights_timePatterns_month_mar,
  l10n.insights_timePatterns_month_apr,
  l10n.insights_timePatterns_month_may,
  l10n.insights_timePatterns_month_jun,
  l10n.insights_timePatterns_month_jul,
  l10n.insights_timePatterns_month_aug,
  l10n.insights_timePatterns_month_sep,
  l10n.insights_timePatterns_month_oct,
  l10n.insights_timePatterns_month_nov,
  l10n.insights_timePatterns_month_dec,
][month - 1];

/// Display text for one category value, from the stable key the repository
/// and the analyzer emit.
String focusCategoryLabel(
  FocusFactorId id,
  CategoryShare share,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final key = share.key;
  switch (id) {
    case FocusFactorId.visibility:
      return visibilityDistributionLabel(key, l10n, units);
    case FocusFactorId.current:
      return CurrentStrength.values
              .where((c) => c.name == key)
              .firstOrNull
              ?.localizedName(l10n) ??
          key;
    case FocusFactorId.waterType:
      return waterTypeDistributionLabel(key, l10n);
    case FocusFactorId.entryMethod:
      return entryMethodDistributionLabel(key, l10n);
    case FocusFactorId.month:
      final m = int.tryParse(key);
      return m == null || m < 1 || m > 12 ? key : _month(m, l10n);
    case FocusFactorId.timeOfDay:
      return timeOfDayDistributionLabel(key, l10n);
    case FocusFactorId.site:
      return share.label ?? key;
    case FocusFactorId.diveType:
      return diveTypeDistributionLabel(key, l10n);
    case FocusFactorId.gas:
      return switch (key) {
        'air' => l10n.insights_focus_gas_air,
        'nitrox' => l10n.insights_focus_gas_nitrox,
        'trimix' => l10n.insights_focus_gas_trimix,
        _ => key,
      };
    case FocusFactorId.suit:
      if (key == 'drysuit') return EquipmentType.drysuit.localizedName(l10n);
      if (key == 'unknown') {
        return l10n.insights_progression_divesBySuitThickness_unknown;
      }
      return '${key.substring('wetsuit:'.length)} mm';
    case FocusFactorId.buddy:
      return key == 'solo'
          ? l10n.insights_social_soloVsBuddy_solo
          : l10n.insights_social_soloVsBuddy_withBuddy;
    case FocusFactorId.maxDepth ||
        FocusFactorId.avgDepth ||
        FocusFactorId.duration ||
        FocusFactorId.waterTemp ||
        FocusFactorId.tankVolume ||
        FocusFactorId.weight:
      return key;
  }
}
```

Find the file that declares the `localizedName` extension on `EquipmentType` with `grep -rn "on EquipmentType" lib` and import that path in place of `equipment_type_display.dart` if it differs. Confirm the `CurrentStrength` enum lives in `core/constants/enums.dart`.

- [ ] **Step 5: Implement `focus_factors_table.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The common-factors table: the group against its baseline, grouped by
/// kind, with standouts flagged and summarised above.
class FocusFactorsTable extends ConsumerWidget {
  const FocusFactorsTable({super.key, required this.report});

  final FocusFactorReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    if (report.tooFewDives) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.insights_focus_factors_tooFew,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final standouts = report.standouts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (standouts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.insights_focus_factors_standoutsSummary(
                standouts.map((f) => focusFactorName(f.id, l10n)).join(', '),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (final group in FocusFactorGroup.values)
          if (report.factors.any((f) => f.id.group == group)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                focusFactorGroupName(group, l10n),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final factor in report.factors.where(
              (f) => f.id.group == group,
            ))
              _FactorRow(factor: factor, units: units, percent: percent),
          ],
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.factor,
    required this.units,
    required this.percent,
  });

  final FocusFactor factor;
  final UnitFormatter units;
  final NumberFormat percent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final List<Widget> values = switch (factor) {
      NumericFactor(:final groupMean, :final baselineMean, :final difference)
          when groupMean != null && baselineMean != null =>
        [
          Text(
            l10n.insights_focus_factors_versus(
              focusNumericValue(factor.id, groupMean, units, l10n),
              focusNumericValue(factor.id, baselineMean, units, l10n),
            ),
          ),
          if (difference != null)
            Text(
              '${difference >= 0 ? '+' : '-'}${focusNumericValue(factor.id, difference.abs(), units, l10n)}',
              style: muted,
            ),
        ],
      CategoricalFactor(:final top) when top.isNotEmpty => [
        for (final share in top)
          Text(
            '${focusCategoryLabel(factor.id, share, l10n, units)}: '
            '${l10n.insights_focus_factors_versus(percent.format(share.groupShare), percent.format(share.baselineShare))}',
            style: share.standsOut
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
      ],
      _ => [Text(l10n.insights_chart_notRecorded, style: muted)],
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(focusFactorName(factor.id, l10n)),
                if (factor.groupCovered > 0 &&
                    factor.groupCovered < factor.groupSize &&
                    factor is NumericFactor)
                  Text(
                    l10n.insights_focus_factors_coverage(
                      factor.groupCovered,
                      factor.groupSize,
                    ),
                    style: muted,
                  ),
                if (factor.standsOut)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(l10n.insights_focus_factors_standsOut),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: values,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/insights/presentation/widgets/focus/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/formatters/focus_factor_labels.dart lib/features/insights/presentation/widgets/focus/focus_factors_table.dart test/features/insights/presentation/widgets/focus/focus_factors_table_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): show Dive focus common factors"
```

---

### Task 16: The Dive focus page (summary, chart, dive list)

**Files:**
- Create: `lib/features/insights/presentation/widgets/focus/focus_results.dart`
- Create: `lib/features/insights/presentation/widgets/focus/focus_dive_list.dart`
- Create: `lib/features/insights/presentation/pages/insights_focus_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/pages/insights_focus_page_test.dart`

**Interfaces:**
- Consumes: Tasks 10 to 15; `DiveTrendChart`, `TrendSeries`, `StatSectionCard`, `StatEmptyState`, `InsightsFilterAction`, `InsightsFilterBar`.
- Produces: `InsightsFocusPage({bool embedded = false})`; `FocusResults()`; `FocusDiveList({required List<TrendDataPoint> members, required Map<String, FocusFactorRow> rows, required FocusMetricUnits metricUnits, required bool ranked})`; row keys `ValueKey('focus-dive-<diveId>')`.

- [ ] **Step 1: Add strings**, then `flutter gen-l10n`:

```json
  "insights_focus_title": "Dive focus",
  "insights_focus_error": "Failed to load dive focus",
  "insights_focus_empty": "No dives have this value yet",
  "insights_focus_summary": "{count} of {total} dives, group average {group} vs {overall} overall",
  "@insights_focus_summary": {
    "placeholders": {
      "count": { "type": "int" },
      "total": { "type": "int" },
      "group": { "type": "String" },
      "overall": { "type": "String" }
    }
  },
  "insights_focus_summary_allShown": "Only {total} dives have this value, so all of them are shown",
  "@insights_focus_summary_allShown": {
    "placeholders": { "total": { "type": "int" } }
  },
  "insights_focus_noMatch_above": "No dives above {value}. Your dives range from {min} to {max}.",
  "@insights_focus_noMatch_above": {
    "placeholders": {
      "value": { "type": "String" },
      "min": { "type": "String" },
      "max": { "type": "String" }
    }
  },
  "insights_focus_noMatch_below": "No dives below {value}. Your dives range from {min} to {max}.",
  "@insights_focus_noMatch_below": {
    "placeholders": {
      "value": { "type": "String" },
      "min": { "type": "String" },
      "max": { "type": "String" }
    }
  },
  "insights_focus_enterValue": "Enter a value to see the dives above or below it",
  "insights_focus_chart_title": "The group over time",
  "insights_focus_chart_group": "In group",
  "insights_focus_chart_others": "Other dives",
  "insights_focus_list_title": "Dives in the group",
  "insights_focus_list_unknownSite": "No site",
```

- [ ] **Step 2: Write the failing page tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_focus_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final rmv = [
    for (var i = 0; i < 12; i++)
      TrendDataPoint(
        date: DateTime.utc(2025, 1, i + 1),
        value: 12.0 + i,
        diveId: 'd$i',
      ),
  ];
  final rows = [
    for (var i = 0; i < 12; i++)
      FocusFactorRow(
        diveId: 'd$i',
        dateTime: DateTime.utc(2025, 1, i + 1),
        siteName: 'Site $i',
        maxDepth: 10.0 + i,
        durationMinutes: 45,
      ),
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<TrendDataPoint>? series,
    FocusSelection selection = const FocusSelection(),
    List<String>? pushed,
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: InsightsFocusPage(embedded: true)),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) {
            pushed?.add(state.pathParameters['id']!);
            return const Scaffold(body: Text('dive page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          focusSelectionProvider.overrideWith((ref) => selection),
          for (final m in FocusMetric.values)
            focusMetricSeriesProvider(m).overrideWith(
              (ref) async => m == FocusMetric.rmv ? (series ?? rmv) : const [],
            ),
          focusFactorRowsProvider.overrideWith((ref) async => rows),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return ProviderScope.containerOf(
      tester.element(find.byType(InsightsFocusPage)),
    );
  }

  testWidgets('best 10 lists ten dives in rank order with a summary', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('10 of 12 dives'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-dive-d0')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-dive-d10')), findsNothing);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  testWidgets('N beyond the data says all are shown', (tester) async {
    await pump(tester, selection: const FocusSelection(count: 20));
    expect(
      find.text('Only 12 dives have this value, so all of them are shown'),
      findsOneWidget,
    );
  });

  testWidgets('a threshold with no match shows the range', (tester) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.above, threshold: 500),
    );
    expect(find.textContaining('No dives above'), findsOneWidget);
    expect(find.textContaining('Your dives range from'), findsOneWidget);
  });

  testWidgets('a threshold mode with no value asks for one', (tester) async {
    await pump(tester, selection: const FocusSelection(mode: FocusMode.above));
    expect(
      find.text('Enter a value to see the dives above or below it'),
      findsOneWidget,
    );
  });

  testWidgets('no dives with the metric shows the empty state', (
    tester,
  ) async {
    await pump(tester, series: const []);
    expect(find.text('No dives have this value yet'), findsOneWidget);
  });

  testWidgets('tapping a row opens that dive', (tester) async {
    final pushed = <String>[];
    await pump(tester, pushed: pushed);
    await tester.ensureVisible(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.tap(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.pumpAndSettle();
    expect(pushed, ['d1']);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 4: Implement `focus_dive_list.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The group's dives, each opening its dive page.
class FocusDiveList extends StatelessWidget {
  const FocusDiveList({
    super.key,
    required this.members,
    required this.rows,
    required this.metricUnits,
    required this.ranked,
  });

  final List<TrendDataPoint> members;
  final Map<String, FocusFactorRow> rows;
  final FocusMetricUnits metricUnits;

  /// Shows a rank number in front of each row.
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final UnitFormatter units = metricUnits.units;
    return Column(
      children: [
        for (var i = 0; i < members.length; i++)
          () {
            final dive = members[i];
            final row = rows[dive.diveId];
            final details = [
              units.formatDate(dive.date),
              if (row?.maxDepth != null) units.formatDepth(row!.maxDepth),
              if (row?.durationMinutes != null)
                l10n.surfaceInterval_format_minutes(
                  row!.durationMinutes!.toStringAsFixed(0),
                ),
            ].join(' · ');
            return ListTile(
              key: ValueKey('focus-dive-${dive.diveId}'),
              contentPadding: EdgeInsets.zero,
              leading: ranked ? Text('${i + 1}') : null,
              title: Text(row?.siteName ?? l10n.insights_focus_list_unknownSite),
              subtitle: Text(details),
              trailing: Text(
                metricUnits.format(dive.value, l10n),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              onTap: () => context.push('/dives/${dive.diveId}'),
            );
          }(),
      ],
    );
  }
}
```

- [ ] **Step 5: Implement `focus_results.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_dive_list.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything under the selector: summary, chart, dive list and factors.
class FocusResults extends ConsumerWidget {
  const FocusResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(focusSelectionProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final metricUnits = FocusMetricUnits(selection.metric, units);

    return ref.watch(focusGroupProvider).when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          StatEmptyState(icon: Icons.error_outline, message: l10n.insights_focus_error),
      data: (group) {
        if (group.population.isEmpty) {
          return StatEmptyState(
            icon: Icons.filter_center_focus,
            message: l10n.insights_focus_empty,
          );
        }
        final message = _message(context, selection, group, metricUnits);
        if (group.members.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(message),
          );
        }
        final rows = {
          for (final r in ref.watch(focusFactorRowsProvider).value ?? const [])
            r.diveId: r,
        };
        final theme = Theme.of(context);
        final memberIds = group.memberIds;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            StatSectionCard(
              title: l10n.insights_focus_chart_title,
              child: DiveTrendChart(
                chartId: 'focus',
                points: [
                  for (final p in group.population)
                    if (!memberIds.contains(p.diveId)) p,
                ],
                secondarySeries: [
                  TrendSeries(
                    label: l10n.insights_focus_chart_group,
                    points: group.members,
                    color: theme.colorScheme.primary,
                  ),
                ],
                pointColor: theme.colorScheme.outline,
                dateFormat: ref.watch(dateFormatProvider),
                valueFormatter: (v) => metricUnits.format(v, l10n),
                yAxisFormatter: (v) =>
                    metricUnits.toDisplay(v).toStringAsFixed(1),
                onDiveSelected: (id) => context.push('/dives/$id'),
              ),
            ),
            const SizedBox(height: 16),
            StatSectionCard(
              title: l10n.insights_focus_list_title,
              child: FocusDiveList(
                members: group.members,
                rows: rows,
                metricUnits: metricUnits,
                ranked: selection.mode.isRanked,
              ),
            ),
            const SizedBox(height: 16),
            StatSectionCard(
              title: l10n.insights_focus_factors_title,
              subtitle: l10n.insights_focus_factors_subtitle,
              child: ref.watch(focusFactorReportProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(l10n.insights_focus_error),
                data: (report) => FocusFactorsTable(report: report),
              ),
            ),
          ],
        );
      },
    );
  }

  String _message(
    BuildContext context,
    FocusSelection selection,
    FocusGroup group,
    FocusMetricUnits metricUnits,
  ) {
    final l10n = context.l10n;
    final threshold = selection.threshold;
    if (!selection.mode.isRanked && threshold == null) {
      return l10n.insights_focus_enterValue;
    }
    if (group.members.isEmpty) {
      final value = metricUnits.format(threshold!, l10n);
      final min = metricUnits.format(group.populationMin!, l10n);
      final max = metricUnits.format(group.populationMax!, l10n);
      return selection.mode == FocusMode.above
          ? l10n.insights_focus_noMatch_above(value, min, max)
          : l10n.insights_focus_noMatch_below(value, min, max);
    }
    if (selection.mode.isRanked &&
        selection.count >= group.population.length) {
      return l10n.insights_focus_summary_allShown(group.population.length);
    }
    return l10n.insights_focus_summary(
      group.members.length,
      group.population.length,
      metricUnits.format(group.memberMean!, l10n),
      metricUnits.format(group.populationMean!, l10n),
    );
  }
}
```

`dateFormatProvider` is the one `TrendChartSection` reads; import it from the same settings providers file.

- [ ] **Step 6: Implement `insights_focus_page.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/presentation/widgets/focus/focus_results.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_selector.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pick a group of dives by one metric, see them, and see what they share
/// (issue #1611).
class InsightsFocusPage extends StatelessWidget {
  const InsightsFocusPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    const content = SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FocusSelector(), SizedBox(height: 16), FocusResults()],
      ),
    );
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.insights_focus_title),
        actions: const [InsightsFilterAction()],
      ),
      // Expanded is required: content is a SingleChildScrollView, and a
      // Column would otherwise hand it unbounded height.
      body: const Column(
        children: [
          InsightsFilterBar(),
          Expanded(child: content),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run to verify pass**

Run: `flutter test test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/pages/insights_focus_page.dart lib/features/insights/presentation/widgets/focus/ test/features/insights/presentation/pages/insights_focus_page_test.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): add the Dive focus page"
```

---

### Task 17: Route, Insights category and the gas records link

**Files:**
- Modify: `lib/core/router/app_router.dart:950-955` (route after `profile`)
- Modify: `lib/features/insights/presentation/widgets/insights_list_content.dart:48-127` (category)
- Modify: `lib/features/insights/presentation/pages/insights_page.dart:54-79` (embedded switch)
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart:245-314` (link)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/pages/insights_gas_page_widget_test.dart` (append), `test/features/insights/presentation/pages/insights_page_content_test.dart` (append)

**Interfaces:**
- Consumes: `InsightsFocusPage` (Task 16), `focusSelectionProvider` (Task 13).
- Produces: route `/insights/focus` named `insightsFocus`; category id `focus`; gas link key `ValueKey('gas-records-see-top')`.

- [ ] **Step 1: Add strings**, then `flutter gen-l10n`:

```json
  "insights_category_focus_subtitle": "Best, worst and threshold groups",
  "insights_gas_sacRecords_seeTop": "See top 10",
```

Put the first next to the other `insights_category_*_subtitle` keys and the second next to `insights_gas_sacRecords_title`.

- [ ] **Step 2: Write the failing tests**

Append to `insights_gas_page_widget_test.dart`:

```dart
  testWidgets('See top 10 presets Dive focus to the gas lane', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: InsightsGasPage(embedded: true)),
        ),
        GoRoute(
          path: '/insights/focus',
          builder: (_, _) => const Scaffold(body: Text('focus page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sacRecordsProvider.overrideWith(
            (ref) async => (
              best: RankingItem(
                id: 'd1',
                name: 'Best',
                value: 12,
                date: DateTime.utc(2025),
              ),
              worst: null,
            ),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InsightsGasPage)),
    );
    final lane = container.read(insightsGasLaneProvider);
    await tester.ensureVisible(find.byKey(const ValueKey('gas-records-see-top')));
    await tester.tap(find.byKey(const ValueKey('gas-records-see-top')));
    await tester.pumpAndSettle();

    expect(find.text('focus page'), findsOneWidget);
    expect(
      container.read(focusSelectionProvider),
      FocusSelection(
        metric: lane == GasConsumptionLane.rmv
            ? FocusMetric.rmv
            : FocusMetric.sac,
      ),
    );
  });
```

Check the `RankingItem` constructor in `lib/features/insights/presentation/widgets/ranking_list.dart` (or wherever `grep -rn "class RankingItem" lib` points) and match its required fields.

Append to `insights_page_content_test.dart`, inside `main()` (it uses the file's own `wrap` helper):

```dart
  testWidgets('the category list offers Dive focus', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await wrap(const InsightsMobileContent()));
    await tester.pumpAndSettle();
    expect(find.text('Dive focus'), findsOneWidget);
    expect(find.text('Best, worst and threshold groups'), findsOneWidget);
  });
```

If any existing test in that file asserts a fixed number of categories, raise it by one.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/insights/presentation/pages/insights_gas_page_widget_test.dart test/features/insights/presentation/pages/insights_page_content_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement**

Route, after the `profile` route in `app_router.dart`:

```dart
              GoRoute(
                path: 'focus',
                name: 'insightsFocus',
                builder: (context, state) => const InsightsFocusPage(),
              ),
```

Category, after `progression` in `insightsCategoriesOf`:

```dart
  InsightsCategory(
    id: 'focus',
    icon: Icons.filter_center_focus,
    title: context.l10n.insights_focus_title,
    subtitle: context.l10n.insights_category_focus_subtitle,
    color: Colors.deepOrange,
  ),
```

Embedded switch in `insights_page.dart`:

```dart
      case 'focus':
        return const InsightsFocusPage(embedded: true);
```

Gas records card: give the `StatSectionCard` in `_buildSacRecordsSection` a trailing link, shown only when there are records:

```dart
      trailing: TextButton(
        key: const ValueKey('gas-records-see-top'),
        onPressed: () {
          ref.read(focusSelectionProvider.notifier).state = FocusSelection(
            metric: isRmv ? FocusMetric.rmv : FocusMetric.sac,
          );
          context.push('/insights/focus');
        },
        child: Text(context.l10n.insights_gas_sacRecords_seeTop),
      ),
```

Add the imports. Check how `StatSectionCard` lays out `trailing` (header row) so the button sits beside the title, and that the card has room on a 360 px phone.

- [ ] **Step 5: Run the whole Insights suite and the architecture guards**

Run: `flutter test test/features/insights test/architecture test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS. Fix any architecture guard that flags a new `lib/` file (for example a widget adoption or file-size guard) in the file it names.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/core/router/app_router.dart lib/features/insights test/features/insights lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(insights): open Dive focus from Insights and the gas records card"
```

---

### Task 18: Translations, generated l10n and final verification

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: List the new keys**

Run: `git diff origin/main -- lib/l10n/arb/app_en.arb | grep '^+  "' | sed 's/:.*//' | sort -u`
Expected: every `insights_trend_overview_*`, `insights_trend_range_*`, `insights_focus_*`, `insights_category_focus_subtitle` and `insights_gas_sacRecords_seeTop` key from Tasks 7 to 17.

- [ ] **Step 2: Translate into all 10 locales**

For each locale ARB, insert each key (with its `@` metadata block for placeholder keys) next to the same neighbouring key used in `app_en.arb`, keeping that locale's existing terminology: German uses AMV, not SAC (`test/l10n/german_sac_terminology_test.dart`); keep RMV and SAC as the abbreviations the locale already uses in its `gasConsumption_*` keys. Keep every placeholder name unchanged. Do not use the em-dash or en-dash.

- [ ] **Step 3: Regenerate LAST and verify a non-English getter**

Run: `flutter gen-l10n && grep -A2 "get insights_focus_title" lib/l10n/arb/app_localizations_de.dart && git diff --numstat lib/l10n/arb/`
Expected: the German getter returns German text, and every `app_XX.arb` shows the same added-line count.

- [ ] **Step 4: Full verification**

Run each and read the output:

```bash
dart format .
flutter analyze
flutter test test/l10n test/architecture test/core test/features/insights test/features/equipment/presentation test/features/dive_log/presentation/widgets
```

Expected: format changes nothing further; analyze reports no issues; all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(insights): translate chart navigation and Dive focus strings"
```
