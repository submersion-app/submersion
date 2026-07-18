# Planner Redesign Phase 1: Chart + Design System - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fl_chart planner chart with a CustomPainter "Precision Instrument" chart (stop tags, ceiling no-go band, gas flags, mean-depth line), plus the shared planner widget vocabulary, inside the existing layout.

**Architecture:** A new `lib/features/planner/presentation/chart/` family: pure `PlanChartGeometry` (mapping + hit-testing), `PlanChartPalette` (theme-derived colors), `StopTagLayouter` (tag collision avoidance), and three painters split by repaint frequency (backdrop / series / overlay), composed by a `PlanProfileChart` ConsumerWidget. Data flow is unchanged: the chart consumes `planCanvasSeriesProvider`, `deviationGhostSeriesProvider`, `planBailoutProvider`, `scrubTimeProvider`. Spec: docs/superpowers/specs/2026-07-17-planner-ui-redesign-design.md section 6.1.

**Tech Stack:** Flutter CustomPainter, Riverpod 3, existing planner providers. No new dependencies. fl_chart remains (other features still use it).

## Global Constraints

- All work in worktree `.claude/worktrees/planner-ui-redesign`, branch `worktree-planner-ui-redesign`.
- No emojis in code, comments, or docs. No hard-coded colors in chart code - every color derives from `Theme.of(context).colorScheme` via `PlanChartPalette`.
- `dart format .` must produce no changes before every commit; `flutter analyze` clean.
- New user-visible strings go into ALL 11 locales (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`) and `AppLocalizations` is regenerated with `flutter gen-l10n`.
- Commit messages: conventional style, no Co-Authored-By line, no attribution footers.
- Run targeted test files, never the whole suite mid-task (whole suite runs in the pre-push hook).
- Never use bare `git stash` (shared stash stack across worktrees).
- Store metric internally; convert for display via `UnitFormatter` (`convertDepth`, `formatDepth(v, decimals: 0)`, `depthSymbol`).

## Existing types you will consume (already in the codebase)

- `PlanCanvasSeries` (lib/features/planner/presentation/providers/plan_canvas_providers.dart): `profile`/`ceiling` as `List<CanvasPoint>`, `gasSwitches`/`stopLabels` as `List<CanvasMarker>`, `maxTimeSeconds`, `maxDepth` (meters), `isEmpty`, `depthAt(double)`.
- `CanvasPoint(timeSeconds, depth)`; `CanvasMarker(timeSeconds, depth, label, {durationSeconds})`.
- Providers: `planCanvasSeriesProvider: Provider<PlanCanvasSeries>`, `deviationGhostSeriesProvider: Provider<PlanCanvasSeries?>`, `planBailoutProvider: Provider<BailoutOutcome?>` (has `nearest(double).ttsSeconds`), `scrubTimeProvider: StateProvider<double?>`, `selectedSegmentIdProvider: StateProvider<String?>` and `divePlanNotifierProvider` (both in lib/features/dive_planner/presentation/providers/dive_planner_providers.dart).
- l10n keys already present: `divePlanner_message_noProfile`, `divePlanner_message_addSegmentsForProfile`, `divePlanner_action_quickPlan`, `divePlanner_label_timeAxis`, `divePlanner_label_depthAxis` (takes unit symbol), `plannerCanvas_scrub_readout(min, depth)`, `plannerCanvas_scrub_bailout(tts)`.
- Test harness: `test/helpers/test_app.dart` provides `testApp({overrides, child})`.

---

### Task 1: PlanChartPalette

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_palette.dart`
- Test: `test/features/planner/chart/plan_chart_palette_test.dart`

**Interfaces:**
- Produces: `class PlanChartPalette` with final `Color` fields `backdrop, gridLine, axisLabel, profileLine, profileFillTop, profileFillBottom, ceilingLine, ceilingFill, meanDepthLine, gasFlag, gasFlagBackground, stopTagBackground, stopTagBorder, stopTagText, ghostLine, scrubCursor, readoutBackground, readoutBorder, readoutText`; factory `PlanChartPalette.of(ThemeData theme)`; value equality (`==`/`hashCode`) so painters can compare palettes in `shouldRepaint`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';

void main() {
  final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );
  final darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );

  test('derives all colors from the scheme, differing by brightness', () {
    final light = PlanChartPalette.of(lightTheme);
    final dark = PlanChartPalette.of(darkTheme);
    expect(light.backdrop, isNot(dark.backdrop));
    expect(light.profileLine, isNot(dark.profileLine));
    // The profile line stays in the primary family.
    expect(
      light.profileLine.toARGB32() == lightTheme.colorScheme.primary.toARGB32(),
      isTrue,
    );
  });

  test('equal themes produce equal palettes (shouldRepaint contract)', () {
    expect(
      PlanChartPalette.of(darkTheme),
      equals(PlanChartPalette.of(darkTheme)),
    );
    expect(
      PlanChartPalette.of(darkTheme).hashCode,
      PlanChartPalette.of(darkTheme).hashCode,
    );
    expect(
      PlanChartPalette.of(darkTheme),
      isNot(equals(PlanChartPalette.of(lightTheme))),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_chart_palette_test.dart`
Expected: FAIL (file/class does not exist).

- [ ] **Step 3: Implement the palette**

```dart
import 'package:flutter/material.dart';

/// Theme-derived colors for the plan profile chart. Every color comes from
/// the active [ColorScheme] so all theme presets, light and dark, render
/// coherently (no hard-coded values).
class PlanChartPalette {
  final Color backdrop;
  final Color gridLine;
  final Color axisLabel;
  final Color profileLine;
  final Color profileFillTop;
  final Color profileFillBottom;
  final Color ceilingLine;
  final Color ceilingFill;
  final Color meanDepthLine;
  final Color gasFlag;
  final Color gasFlagBackground;
  final Color stopTagBackground;
  final Color stopTagBorder;
  final Color stopTagText;
  final Color ghostLine;
  final Color scrubCursor;
  final Color readoutBackground;
  final Color readoutBorder;
  final Color readoutText;

  const PlanChartPalette({
    required this.backdrop,
    required this.gridLine,
    required this.axisLabel,
    required this.profileLine,
    required this.profileFillTop,
    required this.profileFillBottom,
    required this.ceilingLine,
    required this.ceilingFill,
    required this.meanDepthLine,
    required this.gasFlag,
    required this.gasFlagBackground,
    required this.stopTagBackground,
    required this.stopTagBorder,
    required this.stopTagText,
    required this.ghostLine,
    required this.scrubCursor,
    required this.readoutBackground,
    required this.readoutBorder,
    required this.readoutText,
  });

  factory PlanChartPalette.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Color tint(Color base, Color over, double amount) =>
        Color.alphaBlend(over.withValues(alpha: amount), base);
    return PlanChartPalette(
      backdrop: dark
          ? tint(scheme.surfaceContainerLowest, scheme.primary, 0.04)
          : tint(scheme.surfaceContainerLow, scheme.primary, 0.03),
      gridLine: scheme.outline.withValues(alpha: dark ? 0.14 : 0.18),
      axisLabel: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      // Lerp toward onSurface brightens in dark themes and is a no-op-ish
      // darkening in light themes - stays in the primary family either way.
      profileLine: dark
          ? Color.lerp(scheme.primary, scheme.onSurface, 0.25)!
          : scheme.primary,
      profileFillTop: scheme.primary.withValues(alpha: 0.02),
      profileFillBottom: scheme.primary.withValues(alpha: dark ? 0.30 : 0.18),
      ceilingLine: scheme.error.withValues(alpha: 0.75),
      ceilingFill: scheme.error.withValues(alpha: 0.07),
      meanDepthLine: scheme.outline.withValues(alpha: 0.5),
      gasFlag: scheme.tertiary,
      gasFlagBackground: tint(scheme.surface, scheme.tertiary, 0.18),
      stopTagBackground: tint(scheme.surface, scheme.primary, 0.10),
      stopTagBorder: scheme.primary.withValues(alpha: 0.45),
      stopTagText: Color.lerp(scheme.primary, scheme.onSurface, 0.45)!,
      ghostLine: scheme.outline.withValues(alpha: 0.6),
      scrubCursor: scheme.onSurfaceVariant,
      readoutBackground: scheme.surfaceContainerHighest.withValues(
        alpha: 0.95,
      ),
      readoutBorder: scheme.outline.withValues(alpha: 0.3),
      readoutText: scheme.onSurface,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanChartPalette &&
      other.backdrop == backdrop &&
      other.gridLine == gridLine &&
      other.axisLabel == axisLabel &&
      other.profileLine == profileLine &&
      other.profileFillTop == profileFillTop &&
      other.profileFillBottom == profileFillBottom &&
      other.ceilingLine == ceilingLine &&
      other.ceilingFill == ceilingFill &&
      other.meanDepthLine == meanDepthLine &&
      other.gasFlag == gasFlag &&
      other.gasFlagBackground == gasFlagBackground &&
      other.stopTagBackground == stopTagBackground &&
      other.stopTagBorder == stopTagBorder &&
      other.stopTagText == stopTagText &&
      other.ghostLine == ghostLine &&
      other.scrubCursor == scrubCursor &&
      other.readoutBackground == readoutBackground &&
      other.readoutBorder == readoutBorder &&
      other.readoutText == readoutText;

  @override
  int get hashCode => Object.hashAll([
    backdrop,
    gridLine,
    axisLabel,
    profileLine,
    profileFillTop,
    profileFillBottom,
    ceilingLine,
    ceilingFill,
    meanDepthLine,
    gasFlag,
    gasFlagBackground,
    stopTagBackground,
    stopTagBorder,
    stopTagText,
    ghostLine,
    scrubCursor,
    readoutBackground,
    readoutBorder,
    readoutText,
  ]);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_chart_palette_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_chart_palette.dart test/features/planner/chart/plan_chart_palette_test.dart
git commit -m "feat(planner): theme-derived chart palette for the new plan chart"
```

---

### Task 2: PlanChartGeometry

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_geometry.dart`
- Test: `test/features/planner/chart/plan_chart_geometry_test.dart`

**Interfaces:**
- Consumes: `CanvasPoint`, `PlanSegment` (existing).
- Produces:
  - `class PlanChartGeometry { PlanChartGeometry({required Size size, required double maxTimeSeconds, required double maxDepthMeters, required double depthUnitScale}); Rect get plotRect; double xFor(double timeSeconds); double yFor(double depthMeters); Offset toPixel(double timeSeconds, double depthMeters); double timeAtDx(double dx); double get timeTickIntervalSeconds; double get depthTickIntervalMeters; static double niceInterval(double maxValue); static double meanDepthMeters(List<CanvasPoint> profile); }`
  - Top-level `String? segmentIdAtTime(List<PlanSegment> segments, double timeSeconds)` (moves here from the old chart; same behavior).
- Value equality on the four constructor inputs (for painter `shouldRepaint`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

void main() {
  final geometry = PlanChartGeometry(
    size: const Size(500, 400),
    maxTimeSeconds: 3600,
    maxDepthMeters: 40,
    depthUnitScale: 1,
  );

  group('mapping', () {
    test('time 0 maps to plot left, depth 0 to plot top', () {
      expect(geometry.xFor(0), geometry.plotRect.left);
      expect(geometry.yFor(0), geometry.plotRect.top);
    });

    test('max time maps inside the plot (5 percent padding)', () {
      final x = geometry.xFor(3600);
      expect(x, lessThan(geometry.plotRect.right));
      expect(x, greaterThan(geometry.plotRect.left));
    });

    test('timeAtDx inverts xFor and clamps to the data range', () {
      expect(geometry.timeAtDx(geometry.xFor(1800)), closeTo(1800, 0.01));
      expect(geometry.timeAtDx(-50), 0);
      expect(geometry.timeAtDx(10000), 3600);
    });

    test('deeper is lower on screen', () {
      expect(geometry.yFor(30), greaterThan(geometry.yFor(10)));
    });
  });

  group('ticks', () {
    test('niceInterval matches the legacy ladder', () {
      expect(PlanChartGeometry.niceInterval(8), 2);
      expect(PlanChartGeometry.niceInterval(18), 5);
      expect(PlanChartGeometry.niceInterval(45), 10);
      expect(PlanChartGeometry.niceInterval(90), 20);
      expect(PlanChartGeometry.niceInterval(200), 30);
    });

    test('depth interval respects the display unit scale (feet)', () {
      final feet = PlanChartGeometry(
        size: const Size(500, 400),
        maxTimeSeconds: 3600,
        maxDepthMeters: 40,
        depthUnitScale: 3.2808,
      );
      // 40 m * 1.1 padding * 3.2808 = ~144 ft display -> 30 ft interval,
      // converted back to meters for drawing.
      expect(feet.depthTickIntervalMeters, closeTo(30 / 3.2808, 0.001));
    });
  });

  test('meanDepthMeters is the time-weighted trapezoid mean', () {
    const profile = [
      CanvasPoint(0, 0),
      CanvasPoint(100, 20),
      CanvasPoint(300, 20),
    ];
    // 100 s ramp averaging 10 m + 200 s flat at 20 m = (1000 + 4000) / 300.
    expect(
      PlanChartGeometry.meanDepthMeters(profile),
      closeTo(5000 / 300, 0.001),
    );
    expect(PlanChartGeometry.meanDepthMeters(const []), 0);
  });

  group('segmentIdAtTime', () {
    const gas = GasMix(o2: 21);
    final segments = [
      PlanSegment.descent(
        id: 'descent',
        targetDepth: 30,
        tankId: 't1',
        gasMix: gas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'bottom',
        depth: 30,
        durationMinutes: 20,
        tankId: 't1',
        gasMix: gas,
        order: 1,
      ),
    ];

    test('maps times to the covering segment', () {
      expect(segmentIdAtTime(segments, 50), 'descent');
      expect(segmentIdAtTime(segments, 600), 'bottom');
    });

    test('returns null past the last user segment', () {
      expect(segmentIdAtTime(segments, 5000), isNull);
    });

    test('empty segments yield null', () {
      expect(segmentIdAtTime(const [], 10), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_chart_geometry_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the geometry**

```dart
import 'dart:ui';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Pure (time, depth) to pixel mapping for the plan profile chart, plus tick
/// intervals and inverse hit-testing. Positions work in metric depth;
/// [depthUnitScale] (display units per meter) only shapes tick spacing so
/// grid lines land on round display values.
class PlanChartGeometry {
  final Size size;
  final double maxTimeSeconds;
  final double maxDepthMeters;
  final double depthUnitScale;

  static const double leftGutter = 44;
  static const double bottomGutter = 24;
  static const double topPad = 12;
  static const double rightPad = 12;

  const PlanChartGeometry({
    required this.size,
    required this.maxTimeSeconds,
    required this.maxDepthMeters,
    required this.depthUnitScale,
  });

  Rect get plotRect =>
      Rect.fromLTRB(leftGutter, topPad, size.width - rightPad,
          size.height - bottomGutter);

  double get _paddedMaxTime => maxTimeSeconds > 0 ? maxTimeSeconds * 1.05 : 600;
  double get _paddedMaxDepth => maxDepthMeters > 0 ? maxDepthMeters * 1.1 : 10;

  double xFor(double timeSeconds) =>
      plotRect.left + (timeSeconds / _paddedMaxTime) * plotRect.width;

  double yFor(double depthMeters) =>
      plotRect.top + (depthMeters / _paddedMaxDepth) * plotRect.height;

  Offset toPixel(double timeSeconds, double depthMeters) =>
      Offset(xFor(timeSeconds), yFor(depthMeters));

  /// Inverse of [xFor], clamped to the data range (not the padded range) so
  /// scrubbing never reads past the end of the plan.
  double timeAtDx(double dx) {
    if (maxTimeSeconds <= 0) return 0;
    final t = (dx - plotRect.left) / plotRect.width * _paddedMaxTime;
    return t.clamp(0.0, maxTimeSeconds);
  }

  double get timeTickIntervalSeconds => niceInterval(_paddedMaxTime / 60) * 60;

  double get depthTickIntervalMeters =>
      niceInterval(_paddedMaxDepth * depthUnitScale) / depthUnitScale;

  /// Legacy interval ladder from the fl_chart implementation, preserved so
  /// grid density matches diver expectations.
  static double niceInterval(double maxValue) {
    if (maxValue <= 0) return 5;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return 30;
  }

  /// Time-weighted mean depth of a polyline profile (trapezoidal rule).
  static double meanDepthMeters(List<CanvasPoint> profile) {
    if (profile.length < 2) return 0;
    double weighted = 0;
    for (var i = 1; i < profile.length; i++) {
      final dt = profile[i].timeSeconds - profile[i - 1].timeSeconds;
      weighted += dt * (profile[i].depth + profile[i - 1].depth) / 2;
    }
    final total = profile.last.timeSeconds - profile.first.timeSeconds;
    return total > 0 ? weighted / total : 0;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanChartGeometry &&
      other.size == size &&
      other.maxTimeSeconds == maxTimeSeconds &&
      other.maxDepthMeters == maxDepthMeters &&
      other.depthUnitScale == depthUnitScale;

  @override
  int get hashCode =>
      Object.hash(size, maxTimeSeconds, maxDepthMeters, depthUnitScale);
}

/// The user-authored segment whose time span covers [timeSeconds], or null
/// when the time falls in the computed ascent past the last segment.
String? segmentIdAtTime(List<PlanSegment> segments, double timeSeconds) {
  final ordered = List<PlanSegment>.from(segments)
    ..sort((a, b) => a.order.compareTo(b.order));
  var elapsed = 0.0;
  for (final segment in ordered) {
    final end = elapsed + segment.durationSeconds;
    if (timeSeconds >= elapsed && timeSeconds <= end) return segment.id;
    elapsed = end;
  }
  return null;
}
```

Note: the old chart keeps its own private copy of `segmentIdAtTime` until Task 8 deletes it; the two top-level functions live in different libraries and do not collide as long as no file imports both.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_chart_geometry_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_chart_geometry.dart test/features/planner/chart/plan_chart_geometry_test.dart
git commit -m "feat(planner): pure chart geometry with hit-testing and tick logic"
```

---

### Task 3: StopTagLayouter

**Files:**
- Create: `lib/features/planner/presentation/chart/stop_tag_layouter.dart`
- Test: `test/features/planner/chart/stop_tag_layouter_test.dart`

**Interfaces:**
- Produces: `class StopTagLayouter { static List<Rect> layout({required List<Offset> anchors, required List<Size> sizes, required Rect bounds, double gap = 2}); }` - returns one rect per anchor, in input order, such that no two rects overlap and every rect is horizontally inside `bounds`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/stop_tag_layouter.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 400, 300);
  const tag = Size(44, 16);

  test('single tag sits just right and below its anchor', () {
    final rects = StopTagLayouter.layout(
      anchors: const [Offset(100, 100)],
      sizes: const [tag],
      bounds: bounds,
    );
    expect(rects.single.left, 106);
    expect(rects.single.top, 104);
  });

  test('dense stops never overlap and stay in bounds (15-stop trimix)', () {
    // 15 stops on a shallow staircase - anchors 12 px apart vertically,
    // tags 16 px tall: naive placement must collide.
    final anchors = [
      for (var i = 0; i < 15; i++) Offset(200 + i * 8.0, 60 + i * 12.0),
    ];
    final rects = StopTagLayouter.layout(
      anchors: anchors,
      sizes: List.filled(15, tag),
      bounds: bounds,
    );
    expect(rects.length, 15);
    for (var i = 0; i < rects.length; i++) {
      expect(rects[i].left, greaterThanOrEqualTo(bounds.left));
      expect(rects[i].right, lessThanOrEqualTo(bounds.right));
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'tag $i overlaps tag $j',
        );
      }
    }
  });

  test('tag near the right edge is pulled inside the bounds', () {
    final rects = StopTagLayouter.layout(
      anchors: const [Offset(395, 50)],
      sizes: const [tag],
      bounds: bounds,
    );
    expect(rects.single.right, lessThanOrEqualTo(bounds.right));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/stop_tag_layouter_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the layouter**

```dart
import 'dart:ui';

/// Greedy collision-avoiding placement for stop tags. Each tag prefers to sit
/// just right of and below its anchor (the start of a deco shelf); when that
/// spot is taken it slides down, and if it runs out of room below it flips
/// above the anchor. Deterministic and O(n^2), which is fine for the tag
/// counts a dive plan produces.
class StopTagLayouter {
  static List<Rect> layout({
    required List<Offset> anchors,
    required List<Size> sizes,
    required Rect bounds,
    double gap = 2,
  }) {
    assert(anchors.length == sizes.length);
    final placed = <Rect>[];
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      final size = sizes[i];
      var rect = Rect.fromLTWH(
        anchor.dx + 6,
        anchor.dy + 4,
        size.width,
        size.height,
      );
      if (rect.right > bounds.right) {
        rect = rect.translate(bounds.right - rect.right, 0);
      }
      if (rect.left < bounds.left) {
        rect = rect.translate(bounds.left - rect.left, 0);
      }
      var candidate = rect;
      var guard = 0;
      while (_collides(candidate, placed, gap) && guard++ < 64) {
        candidate = candidate.translate(0, size.height + gap);
        if (candidate.bottom > bounds.bottom) {
          // Out of room below: flip above the anchor and walk upward.
          candidate = Rect.fromLTWH(
            rect.left,
            anchor.dy - 4 - size.height,
            size.width,
            size.height,
          );
          while (_collides(candidate, placed, gap) && guard++ < 64) {
            candidate = candidate.translate(0, -(size.height + gap));
          }
          break;
        }
      }
      placed.add(candidate);
    }
    return placed;
  }

  static bool _collides(Rect rect, List<Rect> placed, double gap) =>
      placed.any((p) => p.inflate(gap / 2).overlaps(rect.inflate(gap / 2)));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/stop_tag_layouter_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/stop_tag_layouter.dart test/features/planner/chart/stop_tag_layouter_test.dart
git commit -m "feat(planner): collision-avoiding stop tag layouter"
```

---

### Task 4: Paint utilities (dashes and text)

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_paint_utils.dart`
- Test: `test/features/planner/chart/plan_chart_paint_utils_test.dart`

**Interfaces:**
- Produces: `Path dashedPath(Path source, {required double dash, required double gap})`; `TextPainter layoutLabel(String text, TextStyle style, TextDirection direction)` (returns a laid-out `TextPainter` ready to `paint`).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';

void main() {
  test('dashedPath keeps roughly dash/(dash+gap) of the source length', () {
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final dashed = dashedPath(line, dash: 5, gap: 5);
    final total = dashed
        .computeMetrics()
        .fold<double>(0, (sum, m) => sum + m.length);
    expect(total, closeTo(50, 5.001));
  });

  test('layoutLabel produces a laid-out painter with nonzero size', () {
    final painter = layoutLabel(
      '21m 1\'',
      const TextStyle(fontSize: 10),
      TextDirection.ltr,
    );
    expect(painter.width, greaterThan(0));
    expect(painter.height, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_chart_paint_utils_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the utilities**

```dart
import 'dart:ui';

import 'package:flutter/painting.dart';

/// A copy of [source] consisting of dash segments of length [dash] separated
/// by [gap]. Used for ceiling boundaries, gas-switch stems, ghost profiles,
/// and the mean-depth line.
Path dashedPath(Path source, {required double dash, required double gap}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      result.addPath(metric.extractPath(distance, end), Offset.zero);
      distance += dash + gap;
    }
  }
  return result;
}

/// Lays out [text] once; callers paint via `painter.paint(canvas, offset)`.
TextPainter layoutLabel(
  String text,
  TextStyle style,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  )..layout();
  return painter;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_chart_paint_utils_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_chart_paint_utils.dart test/features/planner/chart/plan_chart_paint_utils_test.dart
git commit -m "feat(planner): dash and label paint utilities for the plan chart"
```

---

### Task 5: Fixtures + backdrop painter (grid, axes, ceiling band)

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_backdrop_painter.dart`
- Create: `test/features/planner/chart/chart_fixtures.dart`
- Test: `test/features/planner/chart/plan_chart_backdrop_painter_test.dart`

**Interfaces:**
- Consumes: `PlanChartGeometry`, `PlanChartPalette`, `dashedPath`, `layoutLabel`, `PlanCanvasSeries`.
- Produces: `class PlanChartBackdropPainter extends CustomPainter { PlanChartBackdropPainter({required this.geometry, required this.palette, required this.ceiling, required this.depthUnitScale, required this.depthAxisLabel, required this.timeAxisLabel, required this.labelStyle, required this.textDirection}); final PlanChartGeometry geometry; final PlanChartPalette palette; final List<CanvasPoint> ceiling; final double depthUnitScale; final String depthAxisLabel; final String timeAxisLabel; final TextStyle labelStyle; final TextDirection textDirection; }` - public fields (tests and `shouldRepaint` read them).
- Fixtures produce: `PlanCanvasSeries ndlSeries()` (30 m / 20 min, no stops, no ceiling), `PlanCanvasSeries decoSeries()` (45 m / 25 min, 4 stops with one gas switch to EAN50 and a ceiling staircase), `PlanCanvasSeries denseDecoSeries()` (15 stops).

- [ ] **Step 1: Write the fixtures (support code, no standalone test)**

```dart
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Hand-built series fixtures so painter tests never depend on the engine.
PlanCanvasSeries ndlSeries() => const PlanCanvasSeries(
  profile: [
    CanvasPoint(0, 0),
    CanvasPoint(100, 30),
    CanvasPoint(1300, 30),
    CanvasPoint(1500, 0),
  ],
  ceiling: [],
  gasSwitches: [],
  stopLabels: [],
  maxTimeSeconds: 1500,
  maxDepth: 30,
);

PlanCanvasSeries decoSeries() => const PlanCanvasSeries(
  profile: [
    CanvasPoint(0, 0),
    CanvasPoint(150, 45),
    CanvasPoint(1500, 45),
    CanvasPoint(1660, 21),
    CanvasPoint(1720, 21),
    CanvasPoint(1780, 12),
    CanvasPoint(1960, 12),
    CanvasPoint(1990, 9),
    CanvasPoint(2290, 9),
    CanvasPoint(2320, 6),
    CanvasPoint(3040, 6),
    CanvasPoint(3100, 0),
  ],
  ceiling: [
    CanvasPoint(1500, 19),
    CanvasPoint(1720, 14),
    CanvasPoint(1960, 9),
    CanvasPoint(2290, 5),
    CanvasPoint(3040, 0),
  ],
  gasSwitches: [CanvasMarker(1660, 21, 'EAN50')],
  stopLabels: [
    CanvasMarker(1660, 21, '', durationSeconds: 60),
    CanvasMarker(1780, 12, '', durationSeconds: 180),
    CanvasMarker(1990, 9, '', durationSeconds: 300),
    CanvasMarker(2320, 6, '', durationSeconds: 720),
  ],
  maxTimeSeconds: 3100,
  maxDepth: 45,
);

PlanCanvasSeries denseDecoSeries() {
  final profile = <CanvasPoint>[
    const CanvasPoint(0, 0),
    const CanvasPoint(200, 75),
    const CanvasPoint(1400, 75),
  ];
  final stops = <CanvasMarker>[];
  var t = 1400.0;
  for (var depth = 45.0; depth >= 3; depth -= 3) {
    t += 60;
    profile.add(CanvasPoint(t, depth));
    stops.add(CanvasMarker(t, depth, '', durationSeconds: 120));
    t += 120;
    profile.add(CanvasPoint(t, depth));
  }
  profile.add(CanvasPoint(t + 30, 0));
  return PlanCanvasSeries(
    profile: profile,
    ceiling: const [],
    gasSwitches: const [],
    stopLabels: stops,
    maxTimeSeconds: t + 30,
    maxDepth: 75,
  );
}
```

- [ ] **Step 2: Write the failing painter test**

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';

import 'chart_fixtures.dart';

void main() {
  final palette = PlanChartPalette.of(
    ThemeData(colorScheme: const ColorScheme.dark()),
  );
  PlanChartBackdropPainter painter({PlanChartGeometry? geometry}) =>
      PlanChartBackdropPainter(
        geometry:
            geometry ??
            const PlanChartGeometry(
              size: Size(500, 400),
              maxTimeSeconds: 3100,
              maxDepthMeters: 45,
              depthUnitScale: 1,
            ),
        palette: palette,
        ceiling: decoSeries().ceiling,
        depthUnitScale: 1,
        depthAxisLabel: 'm',
        timeAxisLabel: 'min',
        labelStyle: const TextStyle(fontSize: 10),
        textDirection: TextDirection.ltr,
      );

  test('paints without throwing on a real canvas', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter().paint(canvas, const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints an empty ceiling without throwing', () {
    final recorder = ui.PictureRecorder();
    final p = PlanChartBackdropPainter(
      geometry: const PlanChartGeometry(
        size: Size(500, 400),
        maxTimeSeconds: 1500,
        maxDepthMeters: 30,
        depthUnitScale: 1,
      ),
      palette: palette,
      ceiling: const [],
      depthUnitScale: 1,
      depthAxisLabel: 'm',
      timeAxisLabel: 'min',
      labelStyle: const TextStyle(fontSize: 10),
      textDirection: TextDirection.ltr,
    );
    p.paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('shouldRepaint only when inputs change', () {
    final a = painter();
    final b = painter();
    expect(a.shouldRepaint(b), isFalse);
    final moved = painter(
      geometry: const PlanChartGeometry(
        size: Size(500, 400),
        maxTimeSeconds: 9999,
        maxDepthMeters: 45,
        depthUnitScale: 1,
      ),
    );
    expect(moved.shouldRepaint(a), isTrue);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_chart_backdrop_painter_test.dart`
Expected: FAIL (painter does not exist).

- [ ] **Step 4: Implement the backdrop painter**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Static chart furniture: grid lines, axis tick labels, axis unit labels,
/// and the ceiling no-go band (shaded area above the deco ceiling with a
/// dashed boundary). Repaints only when the plan data or theme changes.
class PlanChartBackdropPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final List<CanvasPoint> ceiling;
  final double depthUnitScale;
  final String depthAxisLabel;
  final String timeAxisLabel;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  const PlanChartBackdropPainter({
    required this.geometry,
    required this.palette,
    required this.ceiling,
    required this.depthUnitScale,
    required this.depthAxisLabel,
    required this.timeAxisLabel,
    required this.labelStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;
    final gridPaint = Paint()
      ..color = palette.gridLine
      ..strokeWidth = 1;
    final style = labelStyle.copyWith(color: palette.axisLabel);

    // Horizontal depth grid + labels (skip the surface line at depth 0).
    final depthStep = geometry.depthTickIntervalMeters;
    for (var d = depthStep; d < geometry.maxDepthMeters * 1.1; d += depthStep) {
      final y = geometry.yFor(d);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = layoutLabel(
        (d * depthUnitScale).round().toString(),
        style,
        textDirection,
      );
      label.paint(
        canvas,
        Offset(plot.left - label.width - 6, y - label.height / 2),
      );
    }

    // Vertical time grid + labels.
    final timeStep = geometry.timeTickIntervalSeconds;
    for (var t = timeStep; t < geometry.maxTimeSeconds * 1.05; t += timeStep) {
      final x = geometry.xFor(t);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      final label = layoutLabel(
        (t / 60).round().toString(),
        style,
        textDirection,
      );
      label.paint(canvas, Offset(x - label.width / 2, plot.bottom + 4));
    }

    // Axis unit labels: depth unit top-left, time unit bottom-right.
    final depthUnit = layoutLabel(depthAxisLabel, style, textDirection);
    depthUnit.paint(canvas, Offset(plot.left - depthUnit.width - 6, plot.top));
    final timeUnit = layoutLabel(timeAxisLabel, style, textDirection);
    timeUnit.paint(
      canvas,
      Offset(plot.right - timeUnit.width, plot.bottom + 4),
    );

    // Ceiling no-go band: the region shallower than the ceiling.
    if (ceiling.length >= 2) {
      final band = Path()
        ..moveTo(geometry.xFor(ceiling.first.timeSeconds), plot.top);
      for (final point in ceiling) {
        band.lineTo(geometry.xFor(point.timeSeconds), geometry.yFor(point.depth));
      }
      band
        ..lineTo(geometry.xFor(ceiling.last.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(band, Paint()..color = palette.ceilingFill);

      final boundary = Path()
        ..moveTo(
          geometry.xFor(ceiling.first.timeSeconds),
          geometry.yFor(ceiling.first.depth),
        );
      for (final point in ceiling.skip(1)) {
        boundary.lineTo(
          geometry.xFor(point.timeSeconds),
          geometry.yFor(point.depth),
        );
      }
      canvas.drawPath(
        dashedPath(boundary, dash: 5, gap: 4),
        Paint()
          ..color = palette.ceilingLine
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(PlanChartBackdropPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.ceiling != ceiling ||
      oldDelegate.depthUnitScale != depthUnitScale ||
      oldDelegate.depthAxisLabel != depthAxisLabel ||
      oldDelegate.timeAxisLabel != timeAxisLabel;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_chart_backdrop_painter_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_chart_backdrop_painter.dart test/features/planner/chart/chart_fixtures.dart test/features/planner/chart/plan_chart_backdrop_painter_test.dart
git commit -m "feat(planner): backdrop painter with grid, axes, and ceiling no-go band"
```

---

### Task 6: Series painter (profile, fill, ghost, mean depth, gas flags, stop tags)

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_series_painter.dart`
- Test: `test/features/planner/chart/plan_chart_series_painter_test.dart`

**Interfaces:**
- Consumes: Tasks 1-5 outputs; `PlanCanvasSeries`.
- Produces: `class PlanChartSeriesPainter extends CustomPainter { PlanChartSeriesPainter({required this.geometry, required this.palette, required this.series, required this.ghost, required this.stopTagLabels, required this.meanDepthLabel, required this.labelStyle, required this.tagStyle, required this.textDirection}); final PlanChartGeometry geometry; final PlanChartPalette palette; final PlanCanvasSeries series; final PlanCanvasSeries? ghost; final List<String> stopTagLabels; final String meanDepthLabel; final TextStyle labelStyle; final TextStyle tagStyle; final TextDirection textDirection; }` - `ghost` and `series` are public: Task 8's widget tests and the migrated contingency test read them.
- `stopTagLabels` is index-aligned with `series.stopLabels` (the widget preformats them with `UnitFormatter` so the painter stays unit-agnostic).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';

import 'chart_fixtures.dart';

void main() {
  final palette = PlanChartPalette.of(
    ThemeData(colorScheme: const ColorScheme.dark()),
  );
  const geometry = PlanChartGeometry(
    size: Size(500, 400),
    maxTimeSeconds: 3100,
    maxDepthMeters: 45,
    depthUnitScale: 1,
  );

  PlanChartSeriesPainter painter({bool withGhost = false}) =>
      PlanChartSeriesPainter(
        geometry: geometry,
        palette: palette,
        series: decoSeries(),
        ghost: withGhost ? ndlSeries() : null,
        stopTagLabels: const ["21m 1'", "12m 3'", "9m 5'", "6m 12'"],
        meanDepthLabel: 'mean 32m',
        labelStyle: const TextStyle(fontSize: 10),
        tagStyle: const TextStyle(fontSize: 9),
        textDirection: TextDirection.ltr,
      );

  test('paints deco plan with ghost, tags, and flags without throwing', () {
    final recorder = ui.PictureRecorder();
    painter(withGhost: true).paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints a dense 15-stop schedule without throwing', () {
    final dense = denseDecoSeries();
    final p = PlanChartSeriesPainter(
      geometry: PlanChartGeometry(
        size: const Size(500, 400),
        maxTimeSeconds: dense.maxTimeSeconds,
        maxDepthMeters: dense.maxDepth,
        depthUnitScale: 1,
      ),
      palette: palette,
      series: dense,
      ghost: null,
      stopTagLabels: [
        for (final m in dense.stopLabels)
          "${m.depth.round()}m ${m.durationSeconds ~/ 60}'",
      ],
      meanDepthLabel: 'mean 40m',
      labelStyle: const TextStyle(fontSize: 10),
      tagStyle: const TextStyle(fontSize: 9),
      textDirection: TextDirection.ltr,
    );
    final recorder = ui.PictureRecorder();
    p.paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('shouldRepaint when the ghost appears', () {
    expect(painter(withGhost: true).shouldRepaint(painter()), isTrue);
    expect(painter().shouldRepaint(painter()), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_chart_series_painter_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the series painter**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/stop_tag_layouter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// The data layer of the plan chart: ghost contingency profile, gradient
/// fill, the profile line itself, the mean-depth line, gas-switch flags, and
/// collision-avoided stop tags.
class PlanChartSeriesPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final PlanCanvasSeries series;
  final PlanCanvasSeries? ghost;
  final List<String> stopTagLabels;
  final String meanDepthLabel;
  final TextStyle labelStyle;
  final TextStyle tagStyle;
  final TextDirection textDirection;

  const PlanChartSeriesPainter({
    required this.geometry,
    required this.palette,
    required this.series,
    required this.ghost,
    required this.stopTagLabels,
    required this.meanDepthLabel,
    required this.labelStyle,
    required this.tagStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;

    // Ghost contingency profile under everything.
    final ghostSeries = ghost;
    if (ghostSeries != null && ghostSeries.profile.length >= 2) {
      canvas.drawPath(
        dashedPath(_polyline(ghostSeries.profile), dash: 5, gap: 4),
        Paint()
          ..color = palette.ghostLine
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    if (series.profile.length >= 2) {
      // Gradient fill between the profile and the surface.
      final fill = Path.from(_polyline(series.profile))
        ..lineTo(geometry.xFor(series.profile.last.timeSeconds), plot.top)
        ..lineTo(geometry.xFor(series.profile.first.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.profileFillTop, palette.profileFillBottom],
          ).createShader(plot),
      );

      // Mean-depth line (dashed) with a right-aligned label above it.
      final mean = PlanChartGeometry.meanDepthMeters(series.profile);
      if (mean > 0) {
        final y = geometry.yFor(mean);
        final line = Path()
          ..moveTo(plot.left, y)
          ..lineTo(plot.right, y);
        canvas.drawPath(
          dashedPath(line, dash: 8, gap: 5),
          Paint()
            ..color = palette.meanDepthLine
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
        final label = layoutLabel(
          meanDepthLabel,
          labelStyle.copyWith(color: palette.meanDepthLine),
          textDirection,
        );
        label.paint(
          canvas,
          Offset(plot.right - label.width - 4, y - label.height - 2),
        );
      }

      // The profile line.
      canvas.drawPath(
        _polyline(series.profile),
        Paint()
          ..color = palette.profileLine
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Gas-switch flags: dashed stem from the surface to the switch, pill on
    // top with the gas name.
    for (final marker in series.gasSwitches) {
      final x = geometry.xFor(marker.timeSeconds);
      final stem = Path()
        ..moveTo(x, plot.top)
        ..lineTo(x, geometry.yFor(marker.depth));
      canvas.drawPath(
        dashedPath(stem, dash: 3, gap: 3),
        Paint()
          ..color = palette.gasFlag
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );
      final label = layoutLabel(
        marker.label,
        tagStyle.copyWith(color: palette.gasFlag),
        textDirection,
      );
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x + 4,
          plot.top + 4,
          label.width + 12,
          label.height + 6,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(pill, Paint()..color = palette.gasFlagBackground);
      label.paint(canvas, Offset(pill.left + 6, pill.top + 3));
    }

    // Stop tags with collision avoidance.
    if (series.stopLabels.isNotEmpty &&
        stopTagLabels.length == series.stopLabels.length) {
      final painters = [
        for (final text in stopTagLabels)
          layoutLabel(
            text,
            tagStyle.copyWith(color: palette.stopTagText),
            textDirection,
          ),
      ];
      final rects = StopTagLayouter.layout(
        anchors: [
          for (final m in series.stopLabels)
            geometry.toPixel(
              m.timeSeconds + m.durationSeconds,
              m.depth,
            ),
        ],
        sizes: [
          for (final p in painters) Size(p.width + 10, p.height + 6),
        ],
        bounds: plot,
      );
      final borderPaint = Paint()
        ..color = palette.stopTagBorder
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final fillPaint = Paint()..color = palette.stopTagBackground;
      for (var i = 0; i < rects.length; i++) {
        final rrect = RRect.fromRectAndRadius(
          rects[i],
          const Radius.circular(4),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);
        painters[i].paint(
          canvas,
          Offset(rects[i].left + 5, rects[i].top + 3),
        );
      }
    }
  }

  Path _polyline(List<CanvasPoint> points) {
    final path = Path()
      ..moveTo(
        geometry.xFor(points.first.timeSeconds),
        geometry.yFor(points.first.depth),
      );
    for (final point in points.skip(1)) {
      path.lineTo(
        geometry.xFor(point.timeSeconds),
        geometry.yFor(point.depth),
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(PlanChartSeriesPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.series != series ||
      oldDelegate.ghost != ghost ||
      oldDelegate.meanDepthLabel != meanDepthLabel ||
      !listEquals(oldDelegate.stopTagLabels, stopTagLabels);
}
```

Add the `listEquals` import: `import 'package:flutter/foundation.dart';` is already exported by material - if the analyzer complains, use `package:flutter/foundation.dart` explicitly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_chart_series_painter_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_chart_series_painter.dart test/features/planner/chart/plan_chart_series_painter_test.dart
git commit -m "feat(planner): series painter with fill, ghost, mean depth, flags, stop tags"
```

---

### Task 7: PlanProfileChart widget (overlay, gestures, readout, empty state, l10n)

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_profile_chart.dart`
- Modify: `lib/l10n/arb/app_en.arb` (add `plannerCanvas_chart_meanDepth`), plus the same key in `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`
- Test: `test/features/planner/chart/plan_profile_chart_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-6; providers listed in the preamble; `SimplePlanDialog` (existing quick-plan dialog); `UnitFormatter`.
- Produces: `class PlanProfileChart extends ConsumerWidget` (const constructor, no parameters). Layer `CustomPaint`s carry `Key`s: `planChartBackdrop`, `planChartSeries`, `planChartOverlay` - later tests find painters through them. Also `class PlanChartOverlayPainter extends CustomPainter` with public `final double? scrubX`.
- Interaction contract (parity with the old chart): hover/drag sets `scrubTimeProvider` to the time under the pointer (clamped); pointer exit / drag end clears it to null; tap-up additionally sets `selectedSegmentIdProvider` via `segmentIdAtTime`.

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/arb/app_en.arb`, next to the other `plannerCanvas_` keys:

```json
"plannerCanvas_chart_meanDepth": "mean {depth}",
"@plannerCanvas_chart_meanDepth": {
  "description": "Label on the dashed mean-depth line of the plan chart",
  "placeholders": {
    "depth": {"type": "String"}
  }
}
```

Translations for the other ten locales (value only; copy the `@` metadata pattern from en):

| File | Value |
| --- | --- |
| app_ar.arb | "المتوسط {depth}" |
| app_de.arb | "Mittel {depth}" |
| app_es.arb | "media {depth}" |
| app_fr.arb | "moyenne {depth}" |
| app_he.arb | "ממוצע {depth}" |
| app_hu.arb | "átlag {depth}" |
| app_it.arb | "media {depth}" |
| app_nl.arb | "gem. {depth}" |
| app_pt.arb | "média {depth}" |
| app_zh.arb | "平均 {depth}" |

Then run: `flutter gen-l10n`
Expected: regenerates `AppLocalizations` with the new getter.

- [ ] **Step 2: Write the failing widget test**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget harness() => testApp(
    overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
    child: const SizedBox(width: 500, height: 400, child: PlanProfileChart()),
  );

  PlanChartSeriesPainter seriesPainter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
              .painter
          as PlanChartSeriesPainter;

  testWidgets('renders the empty state with a quick-plan action', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planChartSeries')), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('empty-state action opens the quick-plan dialog', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('renders all three paint layers once a plan exists', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planChartBackdrop')), findsOneWidget);
    expect(find.byKey(const Key('planChartSeries')), findsOneWidget);
    expect(find.byKey(const Key('planChartOverlay')), findsOneWidget);
  });

  testWidgets('gas switch reaches the painter and scrub shows the readout', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.addTank(
      const DiveTank(
        id: 'o2',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 100),
        role: TankRole.deco,
      ),
    );
    await tester.pumpAndSettle();

    expect(seriesPainter(tester).series.gasSwitches, isNotEmpty);

    container.read(scrubTimeProvider.notifier).state = 300;
    await tester.pumpAndSettle();
    expect(find.textContaining('RT'), findsOneWidget);
  });

  testWidgets('dragging on the chart scrubs; releasing clears', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byKey(const Key('planChartOverlay')));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(container.read(scrubTimeProvider), isNotNull);

    await gesture.up();
    await tester.pump();
    expect(container.read(scrubTimeProvider), isNull);
  });

  testWidgets('tapping selects the segment under the pointer', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planChartOverlay')));
    await tester.pump();
    expect(container.read(selectedSegmentIdProvider), isNotNull);
  });

  testWidgets('mouse hover scrubs and exit clears', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('planChartOverlay'))),
    );
    await tester.pump();
    expect(container.read(scrubTimeProvider), isNotNull);

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(container.read(scrubTimeProvider), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_profile_chart_test.dart`
Expected: FAIL (widget does not exist).

- [ ] **Step 4: Implement the widget**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Precision Instrument plan chart: three painter layers split by repaint
/// frequency (backdrop / series / overlay), a scrub readout, and gesture
/// handling for hover-scrub and tap-to-select. Pure consumer of the canvas
/// providers - all data flow is unchanged from the fl_chart predecessor.
class PlanProfileChart extends ConsumerWidget {
  const PlanProfileChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(planCanvasSeriesProvider);
    final ghost = ref.watch(deviationGhostSeriesProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final palette = PlanChartPalette.of(theme);

    if (series.isEmpty) return _EmptyState(theme: theme);

    final maxTime = ghost != null && ghost.maxTimeSeconds > series.maxTimeSeconds
        ? ghost.maxTimeSeconds
        : series.maxTimeSeconds;
    final maxDepth = ghost != null && ghost.maxDepth > series.maxDepth
        ? ghost.maxDepth
        : series.maxDepth;
    final labelStyle = theme.textTheme.labelSmall ?? const TextStyle(fontSize: 10);
    final tagStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(fontSize: 9, fontWeight: FontWeight.w600);
    final direction = Directionality.of(context);

    final stopTagLabels = [
      for (final marker in series.stopLabels)
        "${units.formatDepth(marker.depth, decimals: 0)} "
            "${marker.durationSeconds ~/ 60}'",
    ];
    final meanDepthLabel = context.l10n.plannerCanvas_chart_meanDepth(
      units.formatDepth(
        PlanChartGeometry.meanDepthMeters(series.profile),
        decimals: 0,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = PlanChartGeometry(
          size: constraints.biggest,
          maxTimeSeconds: maxTime,
          maxDepthMeters: maxDepth,
          depthUnitScale: units.convertDepth(1),
        );

        void scrubTo(Offset localPosition) {
          ref.read(scrubTimeProvider.notifier).state =
              geometry.timeAtDx(localPosition.dx);
        }

        void clearScrub() =>
            ref.read(scrubTimeProvider.notifier).state = null;

        return MouseRegion(
          onHover: (event) => scrubTo(event.localPosition),
          onExit: (_) => clearScrub(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => scrubTo(details.localPosition),
            onTapUp: (details) {
              final time = geometry.timeAtDx(details.localPosition.dx);
              ref.read(selectedSegmentIdProvider.notifier).state =
                  segmentIdAtTime(
                    ref.read(divePlanNotifierProvider).segments,
                    time,
                  );
            },
            onHorizontalDragUpdate: (details) =>
                scrubTo(details.localPosition),
            onHorizontalDragEnd: (_) => clearScrub(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.backdrop,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('planChartBackdrop'),
                        painter: PlanChartBackdropPainter(
                          geometry: geometry,
                          palette: palette,
                          ceiling: series.ceiling,
                          depthUnitScale: units.convertDepth(1),
                          depthAxisLabel: units.depthSymbol,
                          timeAxisLabel:
                              context.l10n.divePlanner_label_timeAxis,
                          labelStyle: labelStyle,
                          textDirection: direction,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('planChartSeries'),
                        painter: PlanChartSeriesPainter(
                          geometry: geometry,
                          palette: palette,
                          series: series,
                          ghost: ghost,
                          stopTagLabels: stopTagLabels,
                          meanDepthLabel: meanDepthLabel,
                          labelStyle: labelStyle,
                          tagStyle: tagStyle,
                          textDirection: direction,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final scrubTime = ref.watch(scrubTimeProvider);
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const Key('planChartOverlay'),
                                painter: PlanChartOverlayPainter(
                                  geometry: geometry,
                                  palette: palette,
                                  scrubX: scrubTime == null
                                      ? null
                                      : geometry.xFor(scrubTime),
                                ),
                              ),
                            ),
                            if (scrubTime != null)
                              Positioned(
                                top: 12,
                                left: PlanChartGeometry.leftGutter + 4,
                                child: _ScrubReadout(
                                  runtimeSeconds: scrubTime,
                                  depthMeters: series.depthAt(scrubTime),
                                  units: units,
                                  palette: palette,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Scrub cursor layer; repaints per pointer event without touching the
/// series or backdrop layers.
class PlanChartOverlayPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final double? scrubX;

  const PlanChartOverlayPainter({
    required this.geometry,
    required this.palette,
    required this.scrubX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = scrubX;
    if (x == null) return;
    final plot = geometry.plotRect;
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = palette.scrubCursor
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(PlanChartOverlayPainter oldDelegate) =>
      oldDelegate.scrubX != scrubX ||
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette;
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.divePlanner_message_noProfile,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.divePlanner_message_addSegmentsForProfile,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SimplePlanDialog(),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: Text(context.l10n.divePlanner_action_quickPlan),
          ),
        ],
      ),
    );
  }
}

class _ScrubReadout extends ConsumerWidget {
  const _ScrubReadout({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.units,
    required this.palette,
  });

  final double runtimeSeconds;
  final double depthMeters;
  final UnitFormatter units;
  final PlanChartPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final minutes = (runtimeSeconds / 60).round();
    final bailout = ref.watch(planBailoutProvider);
    var text = context.l10n.plannerCanvas_scrub_readout(
      minutes.toString(),
      units.formatDepth(depthMeters, decimals: 0),
    );
    if (bailout != null) {
      final point = bailout.nearest(runtimeSeconds);
      text +=
          ' · '
          '${context.l10n.plannerCanvas_scrub_bailout('${(point.ttsSeconds / 60).ceil()}')}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.readoutBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.readoutBorder),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.readoutText,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/planner/chart/plan_profile_chart_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/chart/plan_profile_chart.dart lib/l10n/arb test/features/planner/chart/plan_profile_chart_test.dart
git add -A lib/l10n
git commit -m "feat(planner): PlanProfileChart widget with layered painters and scrub"
```

---

### Task 8: Swap the new chart into PlanCanvasPage; migrate dependent tests; delete the old chart

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (import at line 26; two `PlanCanvasChart()` sites, currently lines 269 and 365)
- Modify: `test/features/planner/plan_canvas_page_test.dart` (import + `find.byType(PlanCanvasChart)` sites)
- Modify: `test/features/planner/contingency_ui_test.dart` (LineChart assertions -> series painter assertions)
- Delete: `lib/features/planner/presentation/widgets/plan_canvas_chart.dart`
- Delete: `test/features/planner/plan_canvas_chart_test.dart` (fully superseded by Task 2 + Task 7 tests)

**Interfaces:**
- Consumes: `PlanProfileChart`, `PlanChartSeriesPainter.ghost` (public field), `Key('planChartSeries')`.

- [ ] **Step 1: Swap the widget in the page**

In `plan_canvas_page.dart`: replace the import
`import 'package:submersion/features/planner/presentation/widgets/plan_canvas_chart.dart';`
with
`import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';`
and both `child: PlanCanvasChart(),` occurrences with `child: PlanProfileChart(),` (they are inside `const Padding(...)` in both the phone and wide builders; keep the `const`).

- [ ] **Step 2: Migrate plan_canvas_page_test.dart**

Replace the old chart import with
`import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';`
and every `find.byType(PlanCanvasChart)` with `find.byType(PlanProfileChart)`.

- [ ] **Step 3: Migrate contingency_ui_test.dart**

Replace imports: drop `package:fl_chart/fl_chart.dart` and the old chart import; add:

```dart
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
```

Replace `Expanded(child: PlanCanvasChart())` with `Expanded(child: PlanProfileChart())` and `find.byType(PlanCanvasChart)` with `find.byType(PlanProfileChart)`. Replace the LineChart ghost assertions:

```dart
    PlanChartSeriesPainter seriesPainter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                .painter
            as PlanChartSeriesPainter;
    expect(seriesPainter().ghost, isNull);

    await tester.tap(find.text('+5m'));
    await tester.pumpAndSettle();

    expect(container.read(selectedDeviationProvider), 'deeper');
    expect(seriesPainter().ghost, isNotNull);

    // Back to base clears the ghost.
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
    expect(seriesPainter().ghost, isNull);
```

- [ ] **Step 4: Delete the old chart and its test**

```bash
git rm lib/features/planner/presentation/widgets/plan_canvas_chart.dart test/features/planner/plan_canvas_chart_test.dart
```

- [ ] **Step 5: Run the affected tests**

Run: `flutter test test/features/planner/`
Expected: PASS across the planner directory (page, contingency, chart tests). If `flutter analyze` reports a now-unused fl_chart import anywhere in the planner feature, remove it (fl_chart itself stays in pubspec - plan_compare_page.dart and other features still use it).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(planner): cut PlanCanvasPage over to PlanProfileChart, drop fl_chart chart"
```

---

### Task 9: Golden tests (macOS-gated)

**Files:**
- Create: `test/features/planner/chart/plan_profile_chart_golden_test.dart`
- Create (generated): `test/features/planner/chart/goldens/*.png`

**Interfaces:**
- Consumes: `PlanProfileChart`, fixtures, `planCanvasSeriesProvider` override.

Rationale: the repo has no golden infrastructure and CI runs on multiple platforms; text rasterization differs across OSes, so goldens are gated to macOS (the platform the team develops on), following the repo's existing Apple-only test precedent.

- [ ] **Step 1: Write the golden test**

```dart
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

import '../../../helpers/test_app.dart';
import 'chart_fixtures.dart';

void main() {
  Widget harness(PlanCanvasSeries series, {required Brightness brightness}) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: ProviderScope(
        overrides: [
          planCanvasSeriesProvider.overrideWith((ref) => series),
        ],
        child: const Scaffold(
          body: Center(
            child: SizedBox(width: 800, height: 500, child: PlanProfileChart()),
          ),
        ),
      ),
    );
  }

  group('plan chart goldens', () {
    testWidgets('deco plan, dark', (tester) async {
      await tester.pumpWidget(
        harness(decoSeries(), brightness: Brightness.dark),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_deco_dark.png'),
      );
    });

    testWidgets('deco plan, light', (tester) async {
      await tester.pumpWidget(
        harness(decoSeries(), brightness: Brightness.light),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_deco_light.png'),
      );
    });

    testWidgets('ndl plan, dark', (tester) async {
      await tester.pumpWidget(harness(ndlSeries(), brightness: Brightness.dark));
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_ndl_dark.png'),
      );
    });

    testWidgets('dense trimix schedule, dark', (tester) async {
      await tester.pumpWidget(
        harness(denseDecoSeries(), brightness: Brightness.dark),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_dense_dark.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
```

Note: if `testApp` from the helpers is needed for provider scaffolding instead of a raw `ProviderScope` (e.g. missing overrides cause errors), mirror the harness style used in `plan_profile_chart_test.dart` but keep the `planCanvasSeriesProvider` override - fixtures, not the engine, must drive the pixels. The import of `test_app.dart` may then be removed if unused.

- [ ] **Step 2: Generate the goldens (macOS)**

Run: `flutter test test/features/planner/chart/plan_profile_chart_golden_test.dart --update-goldens`
Expected: 4 PNG files appear under `test/features/planner/chart/goldens/`.

- [ ] **Step 3: Verify they pass without updating**

Run: `flutter test test/features/planner/chart/plan_profile_chart_golden_test.dart`
Expected: PASS (4 tests) on macOS; the suite self-skips elsewhere.

- [ ] **Step 4: Visually inspect the goldens**

Open the four PNGs and check: stop tags legible and non-overlapping (dense fixture especially), ceiling band visible under the ascent, gas flag pill at the switch, mean-depth dashed line with label, sensible axis labels in both brightnesses. Text renders in the test-default font; blocky glyphs are expected only if a fixture font is missing - layout, not typography, is what these goldens guard.

- [ ] **Step 5: Commit**

```bash
git add test/features/planner/chart/plan_profile_chart_golden_test.dart test/features/planner/chart/goldens
git commit -m "test(planner): macOS-gated golden images for the plan chart"
```

---

### Task 10: Plan kit vocabulary + results-sheet adoption

**Files:**
- Create: `lib/features/planner/presentation/widgets/plan_kit.dart`
- Modify: `lib/features/planner/presentation/widgets/plan_results_sheet.dart` (replace private `_SectionHeader` at line ~237 and the body of `_IssueRow` at line ~403)
- Test: `test/features/planner/chart/plan_kit_test.dart`

**Interfaces:**
- Produces: `class PlanSectionHeader extends StatelessWidget { const PlanSectionHeader(this.label, {super.key}); final String label; }` and `class PlanWarningRow extends StatelessWidget { const PlanWarningRow({required this.icon, required this.color, required this.message, super.key}); final IconData icon; final Color color; final String message; }`. Phase 2 consumes these when restyling panes; a stat-tile widget is deliberately deferred to phase 2 where it is first used (YAGNI).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';

void main() {
  testWidgets('PlanSectionHeader renders uppercased label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlanSectionHeader('Deco Schedule')),
      ),
    );
    expect(find.text('DECO SCHEDULE'), findsOneWidget);
  });

  testWidgets('PlanWarningRow renders icon and message in color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlanWarningRow(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            message: 'Gas density high',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final text = tester.widget<Text>(find.text('Gas density high'));
    expect(text.style?.color, Colors.orange);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/chart/plan_kit_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the kit**

```dart
import 'package:flutter/material.dart';

/// Shared visual vocabulary for planner surfaces. Phase 1 introduces the
/// pieces the results sheet already needs; later phases extend this file as
/// panes are restyled (see the redesign spec, section 6.1).
class PlanSectionHeader extends StatelessWidget {
  const PlanSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class PlanWarningRow extends StatelessWidget {
  const PlanWarningRow({
    required this.icon,
    required this.color,
    required this.message,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Adopt in the results sheet**

In `plan_results_sheet.dart`:
1. Add `import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';`
2. Delete the private `_SectionHeader` class and replace its seven usages with `PlanSectionHeader(...)` (same call sites, e.g. `PlanSectionHeader(context.l10n.divePlanner_label_decoSchedule)`).
3. Rewrite `_IssueRow.build` to delegate:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = planIssueSeverityColor(theme.colorScheme, issue.severity);
    return PlanWarningRow(
      icon: _issueIcon(issue.severity),
      color: color,
      message: planIssueMessage(context, issue, units),
    );
  }
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/planner/chart/plan_kit_test.dart test/features/planner/`
Expected: PASS (kit tests plus the untouched results-sheet behavior in existing planner tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/widgets/plan_kit.dart lib/features/planner/presentation/widgets/plan_results_sheet.dart test/features/planner/chart/plan_kit_test.dart
git commit -m "feat(planner): shared plan kit vocabulary, adopt in results sheet"
```

---

### Task 11: Phase gate - verify in the running app, full checks

**Files:** none created; verification only.

- [ ] **Step 1: Static checks**

```bash
dart format .
flutter analyze
```
Expected: no formatting changes, no analyzer issues.

- [ ] **Step 2: Planner + l10n test sweep**

Run: `flutter test test/features/planner/ test/features/dive_planner/`
Expected: PASS. (Full suite runs in the pre-push hook; do not run it here.)

- [ ] **Step 3: Run the app and exercise the chart**

Run `flutter run -d macos` (check first that no other `flutter run -d macos` session is active - two instances kill each other). In the app: Planning > Dive Planner > Quick Plan (45m / 25 min), add an EAN50 deco tank, then verify visually: stop tags with depths and durations, shaded ceiling band, gas flag, mean-depth line, hover scrub with readout, tap selects the segment in the list, contingency chip ghosting still draws, phone-size window still renders (resize below 900 px wide). Toggle dark/light and one non-default theme preset - the chart must recolor coherently.

- [ ] **Step 4: Commit any straggler fixes; do not push**

```bash
git status
```
Expected: clean tree. Pushing and PR creation happen only when the user asks (project convention).

---

## Self-Review (completed during planning)

- Spec coverage (spec section 6.1): geometry (Task 2), three painter layers behind RepaintBoundaries (Tasks 5-7), StopTagLayouter (Task 3), PlanChartPalette with no ThemeExtension (Task 1), data flow unchanged (Task 7 consumes the four existing providers), shared vocabulary + adoption (Task 10), goldens + fixture set (Task 9; macOS-gated with rationale), old-chart deletion and test migration (Task 8). Stat tile deferred to phase 2 with YAGNI justification recorded in Task 10.
- Placeholder scan: every code step carries complete code; no TBD/TODO items.
- Type consistency: `PlanChartGeometry` constructor and equality used identically in Tasks 2, 5, 6, 7, 9; painter keys (`planChartBackdrop`/`planChartSeries`/`planChartOverlay`) match between Task 7 widget and Task 7/8 tests; `PlanChartSeriesPainter.ghost` is the public field the migrated contingency test reads.
