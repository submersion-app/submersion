# Safety Findings Lane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the profile chart a first-class selection surface for safety findings: a tappable findings lane under the plot, a callout with Details/Dismiss/clear, and minimum-width highlight bands so short findings are visible.

**Architecture:** All state flows through the existing `selectedSafetyFindingProvider(diveId)`; the lane and callout are a widget overlay inside `DiveProfileChart`'s Stack (the `PhotoMarkerOverlay` pattern), with lane space reserved below the plot (the `GasTimelineStrip` pattern). Pure geometry (band inflation, chip layout/clustering) lives in standalone functions unit-tested without widgets. No schema, sync, repository, or rules-engine changes.

**Tech Stack:** Flutter 3.x, fl_chart, Riverpod, existing Submersion widgets/providers.

**Spec:** `docs/superpowers/specs/2026-08-09-safety-findings-lane-design.md`

## Global Constraints

- Run every command from the worktree root: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/safety-review-presentation` (bash cwd can reset to the main checkout between calls — verify with `pwd` before builds, codegen, and l10n generation; generated files landing in the main checkout is a known failure mode).
- No emojis anywhere. No alarm-red styling; severity colors come only from `safetySeverityColor`.
- All user-facing strings localized; new keys must be added to ALL 11 arb files (`app_en`, `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`) then `flutter gen-l10n`.
- `dart format .` (whole project) must produce no changes before any commit.
- Minimum highlight band width on the chart: 12 px. Minimum lane chip width: 26 px. Lane height: 24 px.
- Existing behavior preserved: section tile tap still selects + scrolls toward the chart; retap clears; dismissed findings never in the lane; findings without a start timestamp never in the lane.
- Immutability: never mutate passed-in lists; return new lists.
- Commit after each task with a plain imperative message (no Co-Authored-By line, no conventional-commit prefix).

---

### Task 1: Minimum-width band geometry (`highlightBandSpan`)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_highlight_range.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`

**Interfaces:**
- Consumes: existing `ProfileHighlightRange`, `visibleHighlightSpan` (same file).
- Produces: `({double x1, double x2})? highlightBandSpan(ProfileHighlightRange range, {required double visibleMinX, required double visibleMaxX, required double minWidthX})` — Task 2 calls this from the chart.

- [ ] **Step 1: Write the failing tests**

Append a new group to `test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart` (keep the existing `visibleHighlightSpan` tests untouched):

```dart
  group('highlightBandSpan', () {
    const color = Color(0xFF000000);

    test('wide range passes through unchanged', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 60,
          endTimestamp: 120,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 10,
      );
      expect(span, (x1: 60.0, x2: 120.0));
    });

    test('narrow range inflates to minWidthX centered on its midpoint', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 100,
          endTimestamp: 104,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 20,
      );
      expect(span, (x1: 92.0, x2: 112.0));
    });

    test('instant range inflates to minWidthX centered on the instant', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 90,
          endTimestamp: 90,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 84.0, x2: 96.0));
    });

    test('inflation shifts right when clamped by the window start', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 2,
          endTimestamp: 2,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 0.0, x2: 12.0));
    });

    test('inflation shifts left when clamped by the window end', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 268,
          endTimestamp: 268,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 258.0, x2: 270.0));
    });

    test('window narrower than minWidthX returns the whole window', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 100,
          endTimestamp: 101,
          color: color,
        ),
        visibleMinX: 98,
        visibleMaxX: 104,
        minWidthX: 12,
      );
      expect(span, (x1: 98.0, x2: 104.0));
    });

    test('range fully outside the window returns null', () {
      final span = highlightBandSpan(
        const ProfileHighlightRange(
          startTimestamp: 400,
          endTimestamp: 500,
          color: color,
        ),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, isNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`
Expected: FAIL — `highlightBandSpan` is not defined.

- [ ] **Step 3: Implement `highlightBandSpan`**

Append to `lib/features/dive_log/presentation/widgets/profile_highlight_range.dart`:

```dart
/// The drawable band for [range], inflated to at least [minWidthX] (x-axis
/// units) so short and instant findings stay visible. Centered on the
/// clamped span's midpoint, shifted (not shrunk) to stay inside the window;
/// a window narrower than [minWidthX] yields the whole window. Returns null
/// when nothing of the range is visible.
({double x1, double x2})? highlightBandSpan(
  ProfileHighlightRange range, {
  required double visibleMinX,
  required double visibleMaxX,
  required double minWidthX,
}) {
  final span = visibleHighlightSpan(
    range,
    visibleMinX: visibleMinX,
    visibleMaxX: visibleMaxX,
  );
  if (span == null) return null;
  if (span.x2 - span.x1 >= minWidthX) return span;
  if (visibleMaxX - visibleMinX <= minWidthX) {
    return (x1: visibleMinX, x2: visibleMaxX);
  }
  final mid = (span.x1 + span.x2) / 2;
  var x1 = mid - minWidthX / 2;
  var x2 = mid + minWidthX / 2;
  if (x1 < visibleMinX) {
    x2 += visibleMinX - x1;
    x1 = visibleMinX;
  } else if (x2 > visibleMaxX) {
    x1 -= x2 - visibleMaxX;
    x2 = visibleMaxX;
  }
  return (x1: x1, x2: x2);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/profile_highlight_range.dart test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart
git commit -m "Add minimum-width highlight band geometry helper"
```

---

### Task 2: Chart renders minimum-width bands (instant dashed line removed)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (highlight builders ~`:4984-5044`, call sites ~`:2590-2600`, span computed in `_buildChart` ~`:2144`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`

**Interfaces:**
- Consumes: `highlightBandSpan` (Task 1), existing `widget.highlightRange`, `_plotInsets(availableWidth, units)`, `visibleMinX`/`visibleMaxX` locals in `_buildChart`.
- Produces: the chart's highlight vocabulary becomes "band + two edge lines" for every visible highlight, including instants. No API change.

- [ ] **Step 1: Rewrite the instant-highlight test and add min-width tests**

In `test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`, REPLACE the test `'an instant highlight renders a single dashed cursor, no band'` with:

```dart
  testWidgets('an instant highlight renders a minimum-width band, no dash', (
    tester,
  ) async {
    await pumpChart(
      tester,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 90,
        endTimestamp: 90,
        color: Colors.teal,
      ),
    );
    final data = chartData(tester);

    final annotations = data.rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(1));
    expect(annotations.single.x1, lessThan(90));
    expect(annotations.single.x2, greaterThan(90));

    final lines = data.extraLinesData.verticalLines;
    expect(lines, hasLength(2));
    for (final line in lines) {
      expect(line.dashArray, isNull);
    }
  });

  testWidgets('a very short range inflates to a visible band', (tester) async {
    await pumpChart(
      tester,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 100,
        endTimestamp: 102,
        color: Colors.teal,
      ),
    );
    final data = chartData(tester);

    final annotations = data.rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(1));
    // 2 s of a 270 s axis is ~2-3 px at this width; the band must be wider
    // than the raw range because the 12 px minimum kicked in.
    expect(
      annotations.single.x2 - annotations.single.x1,
      greaterThan(2.0),
    );
    expect(data.extraLinesData.verticalLines, hasLength(2));
  });
```

Leave the other four tests untouched — they must keep passing (the 60–120 s range is wider than the 12 px minimum at a 400 px chart width, so its exact x values are unchanged).

- [ ] **Step 2: Run the file to verify the new tests fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`
Expected: the two new/rewritten tests FAIL (instant still renders a dashed line and no band); the others PASS.

- [ ] **Step 3: Implement in the chart**

In `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`:

3a. Add a constant next to `gasTimelineHeight` (~`:175`):

```dart
  /// Minimum on-screen width of the safety-highlight band, in logical px.
  /// Short and instant findings inflate to this so they stay visible.
  static const double _minHighlightBandPx = 12.0;
```

3b. In `_buildChart`, after `visibleMaxDepth` is computed (~`:2175`), compute the span once:

```dart
    // Highlight band, inflated to a 12 px minimum so short/instant findings
    // stay visible (spec: safety-findings-lane). Computed once and shared by
    // the band annotation and its edge lines.
    ({double x1, double x2})? highlightSpan;
    if (widget.highlightRange != null) {
      final plotInsets = _plotInsets(availableWidth, units);
      final plotWidth = (availableWidth - plotInsets.left - plotInsets.right)
          .clamp(1.0, double.infinity);
      highlightSpan = highlightBandSpan(
        widget.highlightRange!,
        visibleMinX: visibleMinX,
        visibleMaxX: visibleMaxX,
        minWidthX:
            DiveProfileChart._minHighlightBandPx *
            (visibleMaxX - visibleMinX) /
            plotWidth,
      );
    }
```

3c. Change the two call sites (~`:2590-2600`) to pass the span:

```dart
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: _buildHighlightRangeAnnotations(
                highlightSpan,
              ),
            ),
```

and in `extraLinesData.verticalLines`:

```dart
                ..._buildHighlightRangeLines(highlightSpan),
```

3d. REPLACE both builders (~`:4984-5044`) with:

```dart
  /// Translucent band for the externally highlighted time range. [span] is
  /// precomputed by [_buildChart] via [highlightBandSpan]: clamped to the
  /// visible window and inflated to the 12 px minimum, so instants and short
  /// ranges render the same visible band as wide ones.
  List<VerticalRangeAnnotation> _buildHighlightRangeAnnotations(
    ({double x1, double x2})? span,
  ) {
    final range = widget.highlightRange;
    if (range == null || span == null) return [];
    return [
      VerticalRangeAnnotation(
        x1: span.x1,
        x2: span.x2,
        color: range.color.withValues(alpha: 0.12),
      ),
    ];
  }

  /// Edge lines at the highlight band's (possibly inflated) edges.
  List<VerticalLine> _buildHighlightRangeLines(
    ({double x1, double x2})? span,
  ) {
    final range = widget.highlightRange;
    if (range == null || span == null) return [];
    return [
      for (final x in [span.x1, span.x2])
        VerticalLine(
          x: x,
          color: range.color.withValues(alpha: 0.7),
          strokeWidth: 1,
        ),
    ];
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart --timeout 120s`
Expected: PASS. (The page tests exercise highlight wiring end to end; a fullscreen test asserts the carried-over highlight — an instant selection there now yields a band, which these tests don't assert against, but run them to be sure.)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Render minimum-width highlight bands for short and instant safety findings"
```

---

### Task 3: Lane chip layout and clustering (pure)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/safety_lane_layout.dart`
- Test: `test/features/dive_log/presentation/widgets/safety_lane_layout_test.dart`

**Interfaces:**
- Consumes: nothing project-specific (pure geometry).
- Produces (used by Task 5's overlay):

```dart
class SafetyLaneChipPlacement {
  final double left;            // px from the lane's left edge
  final double width;           // px, >= minChipWidth (unless lane narrower)
  final List<int> memberIndexes; // indexes into the caller's findings list,
                                 // in ascending start-time order
}

List<SafetyLaneChipPlacement> layoutSafetyLaneChips({
  required List<({double startSeconds, double endSeconds})> ranges,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double laneWidth,
  double minChipWidth = 26.0,
})
```

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/safety_lane_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/safety_lane_layout.dart';

void main() {
  // Lane maps a 0..1000 s window onto 500 px: 1 px per 2 s.
  List<SafetyLaneChipPlacement> layout(
    List<({double startSeconds, double endSeconds})> ranges, {
    double visibleMin = 0,
    double visibleMax = 1000,
    double laneWidth = 500,
  }) {
    return layoutSafetyLaneChips(
      ranges: ranges,
      visibleMinSeconds: visibleMin,
      visibleMaxSeconds: visibleMax,
      laneWidth: laneWidth,
    );
  }

  test('a wide range maps to a proportional chip', () {
    final placements = layout([(startSeconds: 200.0, endSeconds: 400.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.left, 100);
    expect(placements.single.width, 100);
    expect(placements.single.memberIndexes, [0]);
  });

  test('a short range gets the minimum chip width, centered', () {
    // 10 s -> 5 px extent (100..105 px), inflated to 26 px centered on
    // the 102.5 px midpoint: left = 102.5 - 13 = 89.5.
    final placements = layout([(startSeconds: 200.0, endSeconds: 210.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.left, closeTo(89.5, 0.01));
    expect(placements.single.width, 26);
  });

  test('an instant range gets the minimum chip width', () {
    final placements = layout([(startSeconds: 500.0, endSeconds: 500.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.width, 26);
    expect(placements.single.left, closeTo(250 - 13, 0.01));
  });

  test('a chip near the lane start is clamped inside the lane', () {
    final placements = layout([(startSeconds: 0.0, endSeconds: 0.0)]);
    expect(placements.single.left, 0);
    expect(placements.single.width, 26);
  });

  test('a chip near the lane end is clamped inside the lane', () {
    final placements = layout([(startSeconds: 1000.0, endSeconds: 1000.0)]);
    expect(placements.single.left, closeTo(500 - 26, 0.01));
    expect(placements.single.width, 26);
  });

  test('a range outside the visible window produces no chip', () {
    final placements = layout([
      (startSeconds: 800.0, endSeconds: 900.0),
    ], visibleMin: 0, visibleMax: 500);
    expect(placements, isEmpty);
  });

  test('a range straddling the window edge is clamped to the edge', () {
    final placements = layout([
      (startSeconds: 400.0, endSeconds: 600.0),
    ], visibleMin: 0, visibleMax: 500, laneWidth: 500);
    expect(placements, hasLength(1));
    expect(placements.single.left, 400);
    expect(placements.single.width, 100);
  });

  test('overlapping chips merge into one cluster in start order', () {
    // Two instants 10 s (5 px) apart: both inflate to 26 px and overlap.
    final placements = layout([
      (startSeconds: 510.0, endSeconds: 510.0),
      (startSeconds: 500.0, endSeconds: 500.0),
    ]);
    expect(placements, hasLength(1));
    expect(placements.single.memberIndexes, [1, 0]);
  });

  test('non-overlapping chips stay separate', () {
    final placements = layout([
      (startSeconds: 100.0, endSeconds: 100.0),
      (startSeconds: 900.0, endSeconds: 900.0),
    ]);
    expect(placements, hasLength(2));
  });

  test('empty window or lane yields nothing', () {
    expect(
      layout([
        (startSeconds: 1.0, endSeconds: 2.0),
      ], visibleMin: 5, visibleMax: 5),
      isEmpty,
    );
    expect(
      layout([(startSeconds: 1.0, endSeconds: 2.0)], laneWidth: 0),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_lane_layout_test.dart`
Expected: FAIL — file/function not defined.

- [ ] **Step 3: Implement the layout**

Create `lib/features/dive_log/presentation/widgets/safety_lane_layout.dart`:

```dart
import 'dart:math' as math;

/// One tappable chip in the safety findings lane. [memberIndexes] holds the
/// indexes (into the caller's findings list) of every finding merged into
/// this chip, ascending by on-screen position; length > 1 marks a cluster.
class SafetyLaneChipPlacement {
  final double left;
  final double width;
  final List<int> memberIndexes;

  const SafetyLaneChipPlacement({
    required this.left,
    required this.width,
    required this.memberIndexes,
  });
}

/// Maps finding time ranges onto lane pixels: clamps to the visible window,
/// inflates every chip to [minChipWidth] (shifted to stay inside the lane),
/// and merges chips whose extents overlap into clusters. Pure geometry so
/// clustering behavior is unit-testable without widgets.
List<SafetyLaneChipPlacement> layoutSafetyLaneChips({
  required List<({double startSeconds, double endSeconds})> ranges,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double laneWidth,
  double minChipWidth = 26.0,
}) {
  final window = visibleMaxSeconds - visibleMinSeconds;
  if (window <= 0 || laneWidth <= 0) return const [];

  final extents = <({double left, double right, int index})>[];
  for (var i = 0; i < ranges.length; i++) {
    final r = ranges[i];
    if (r.endSeconds < visibleMinSeconds || r.startSeconds > visibleMaxSeconds) {
      continue;
    }
    var left = ((r.startSeconds - visibleMinSeconds) / window * laneWidth)
        .clamp(0.0, laneWidth);
    var right = ((r.endSeconds - visibleMinSeconds) / window * laneWidth)
        .clamp(0.0, laneWidth);
    if (right - left < minChipWidth) {
      final mid = (left + right) / 2;
      left = mid - minChipWidth / 2;
      right = mid + minChipWidth / 2;
      if (left < 0) {
        right -= left;
        left = 0;
      } else if (right > laneWidth) {
        left -= right - laneWidth;
        right = laneWidth;
      }
      left = math.max(left, 0.0);
      right = math.min(right, laneWidth);
    }
    extents.add((left: left, right: right, index: i));
  }
  extents.sort((a, b) => a.left.compareTo(b.left));

  final placements = <SafetyLaneChipPlacement>[];
  double clusterLeft = 0;
  double clusterRight = 0;
  var members = <int>[];
  for (final e in extents) {
    if (members.isEmpty) {
      clusterLeft = e.left;
      clusterRight = e.right;
      members = [e.index];
    } else if (e.left < clusterRight) {
      clusterRight = math.max(clusterRight, e.right);
      members.add(e.index);
    } else {
      placements.add(
        SafetyLaneChipPlacement(
          left: clusterLeft,
          width: clusterRight - clusterLeft,
          memberIndexes: members,
        ),
      );
      clusterLeft = e.left;
      clusterRight = e.right;
      members = [e.index];
    }
  }
  if (members.isNotEmpty) {
    placements.add(
      SafetyLaneChipPlacement(
        left: clusterLeft,
        width: clusterRight - clusterLeft,
        memberIndexes: members,
      ),
    );
  }
  return placements;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_lane_layout_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/safety_lane_layout.dart test/features/dive_log/presentation/widgets/safety_lane_layout_test.dart
git commit -m "Add pure chip layout and clustering for the safety findings lane"
```

---

### Task 4: Shared finding text/filter helpers and l10n strings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/safety_finding_text.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_finding_highlight.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_review_section.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`, `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`

**Interfaces:**
- Consumes: `SafetyFinding`, `SafetyRuleId`, `AppLocalizations`, `UnitFormatter`, existing arb keys `safetySettings_rule_rapidAscent` / `_missedDecoStop` / `_omittedSafetyStop` / `_sawtoothProfile` / `_highSurfaceGf`, `safetyReview_findingCount` (plural-metadata template).
- Produces (used by Tasks 5, 7, 8):
  - `String safetyFindingTitle(SafetyFinding finding, AppLocalizations l10n, UnitFormatter units)` — the full composed title (moved verbatim from `_FindingTile._titleFor` plus its `_duration`/`_seconds` helpers).
  - `String safetyFindingShortLabel(SafetyFinding finding, AppLocalizations l10n)` — the localized rule name (for wide chips).
  - `List<SafetyFinding> chartSafetyFindings(SafetyReview? review, Set<String> disabledRules)` — non-dismissed, rule-enabled, start-timestamped findings sorted by start time.
  - `profileHighlightRangeFor` now treats a null `endTimestamp` as an instant at `startTimestamp` (previously returned null).
  - New l10n getters: `l10n.safetyReview_details`, `l10n.safetyReview_clearHighlight`, `l10n.safetyReview_findingGroupSemantics(count)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart` (match the file's existing imports/fixtures; construct findings with the real `SafetyFinding` constructor — required fields are `id`, `diveId`, `ruleId`, `severity`, `engineVersion`, `createdAt`):

```dart
  group('profileHighlightRangeFor with missing end timestamp', () {
    test('start-only finding maps to an instant range', () {
      final finding = SafetyFinding(
        id: 'f1',
        diveId: 'd1',
        ruleId: SafetyRuleId.omittedSafetyStop,
        severity: SafetySeverity.caution,
        startTimestamp: 300,
        endTimestamp: null,
        engineVersion: 1,
        createdAt: DateTime(2026),
      );
      final range = profileHighlightRangeFor(
        finding,
        const ColorScheme.light(),
      );
      expect(range, isNotNull);
      expect(range!.startTimestamp, 300);
      expect(range.endTimestamp, 300);
    });

    test('finding with no start timestamp maps to null', () {
      final finding = SafetyFinding(
        id: 'f2',
        diveId: 'd1',
        ruleId: SafetyRuleId.sawtoothProfile,
        severity: SafetySeverity.info,
        engineVersion: 1,
        createdAt: DateTime(2026),
      );
      expect(
        profileHighlightRangeFor(finding, const ColorScheme.light()),
        isNull,
      );
    });
  });

  group('chartSafetyFindings', () {
    SafetyFinding finding(
      String id, {
      int? start,
      SafetyRuleId rule = SafetyRuleId.rapidAscent,
      DateTime? dismissedAt,
    }) {
      return SafetyFinding(
        id: id,
        diveId: 'd1',
        ruleId: rule,
        severity: SafetySeverity.caution,
        startTimestamp: start,
        engineVersion: 1,
        dismissedAt: dismissedAt,
        createdAt: DateTime(2026),
      );
    }

    test('filters dismissed, disabled-rule, and timestampless findings', () {
      final review = SafetyReview(
        diveId: 'd1',
        engineVersion: 1,
        reviewedAt: DateTime(2026),
        findings: [
          finding('keep', start: 200),
          finding('dismissed', start: 100, dismissedAt: DateTime(2026)),
          finding('no-time'),
          finding(
            'disabled',
            start: 50,
            rule: SafetyRuleId.sawtoothProfile,
          ),
          finding('earlier', start: 10),
        ],
      );
      final result = chartSafetyFindings(review, {
        SafetyRuleId.sawtoothProfile.dbValue,
      });
      expect(result.map((f) => f.id), ['earlier', 'keep']);
    });

    test('null review yields an empty list', () {
      expect(chartSafetyFindings(null, const {}), isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`
Expected: FAIL — `chartSafetyFindings` undefined; the start-only test fails (current code returns null).

- [ ] **Step 3: Implement helpers and refactor the section**

3a. In `lib/features/dive_log/presentation/widgets/safety_finding_highlight.dart`, change `profileHighlightRangeFor`'s body:

```dart
  if (finding == null) return null;
  final start = finding.startTimestamp;
  if (start == null) return null;
  final end = finding.endTimestamp ?? start;
  return ProfileHighlightRange(
    startTimestamp: start,
    endTimestamp: end,
    color: safetySeverityColor(finding.severity, colorScheme),
  );
```

Update its doc comment: a missing end timestamp now means "instant at start"; only a missing start disables highlighting. Then append:

```dart
/// The findings the profile chart's safety lane shows for [review]:
/// non-dismissed, rule-enabled, and placeable on the time axis (start
/// timestamp present), sorted by start time. [disabledRules] holds
/// [SafetyRuleId.dbValue] strings (settings.safetyReviewDisabledRules).
List<SafetyFinding> chartSafetyFindings(
  SafetyReview? review,
  Set<String> disabledRules,
) {
  if (review == null) return const [];
  final findings = review.findings
      .where(
        (f) =>
            !f.isDismissed &&
            !disabledRules.contains(f.ruleId.dbValue) &&
            f.startTimestamp != null,
      )
      .toList();
  findings.sort((a, b) => a.startTimestamp!.compareTo(b.startTimestamp!));
  return findings;
}
```

3b. Create `lib/features/dive_log/presentation/widgets/safety_finding_text.dart`. Move the bodies of `_FindingTile._titleFor`, `_FindingTile._duration`, and `_FindingTile._seconds` from `safety_review_section.dart` into top-level functions, changing `finding.` field access to the parameter (keep the placeholder comments — they document sync-data edge cases):

```dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Full composed title for a finding (rule + key numbers), shared by the
/// safety section tiles and the chart lane callout.
String safetyFindingTitle(
  SafetyFinding finding,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  // ... moved verbatim from _FindingTile._titleFor, with _duration()/_seconds()
  // inlined as the private functions below ...
}

/// Localized rule name only (settings-page strings), for narrow contexts
/// like wide lane chips.
String safetyFindingShortLabel(SafetyFinding finding, AppLocalizations l10n) {
  return switch (finding.ruleId) {
    SafetyRuleId.rapidAscent => l10n.safetySettings_rule_rapidAscent,
    SafetyRuleId.missedDecoStop => l10n.safetySettings_rule_missedDecoStop,
    SafetyRuleId.omittedSafetyStop =>
      l10n.safetySettings_rule_omittedSafetyStop,
    SafetyRuleId.sawtoothProfile => l10n.safetySettings_rule_sawtoothProfile,
    SafetyRuleId.highSurfaceGf => l10n.safetySettings_rule_highSurfaceGf,
  };
}
```

(The "moved verbatim" comment above is a transcription instruction for this step, not content to leave in the file: copy the exact switch expression from `safety_review_section.dart:224-252` and the two helpers at `:255-267`, renaming `_duration()` to a private `_durationOf(SafetyFinding finding)` and `_seconds` to `_formatSeconds`.)

3c. In `safety_review_section.dart`: delete `_titleFor`, `_duration`, `_seconds` from `_FindingTile`; import `safety_finding_text.dart`; replace the `title:` argument with `Text(safetyFindingTitle(finding, l10n, units))` (add `final l10n = context.l10n;` already present). Change `_tapHandlerFor` to gate only on the start timestamp:

```dart
  VoidCallback? _tapHandlerFor(SafetyFinding finding) {
    if (finding.startTimestamp == null) return null;
    return () => _toggleSelected(finding);
  }
```

3d. Add l10n keys. In `lib/l10n/arb/app_en.arb`, next to the existing `safetyReview_*` block (~`:7481`):

```json
  "safetyReview_details": "Details",
  "@safetyReview_details": {
    "description": "Link in the chart finding callout that scrolls to the full safety review section"
  },
  "safetyReview_clearHighlight": "Clear highlight",
  "@safetyReview_clearHighlight": {
    "description": "Tooltip/semantics for the button that clears the chart safety highlight"
  },
  "safetyReview_findingGroupSemantics": "{count, plural, =1{1 safety observation} other{{count} safety observations}}",
  "@safetyReview_findingGroupSemantics": {
    "description": "Semantics label for a clustered chip in the chart safety lane",
    "placeholders": {
      "count": {"type": "int"}
    }
  },
```

Add the same three keys (with the same `@`-metadata placeholder structure, mirroring how each file formats `safetyReview_findingCount`) to the other 10 arb files with these values:

| File | details | clearHighlight | findingGroupSemantics (=1 / other) |
|---|---|---|---|
| app_ar.arb | التفاصيل | مسح التمييز | ملاحظة سلامة واحدة / {count} ملاحظات سلامة |
| app_de.arb | Details | Hervorhebung entfernen | 1 Sicherheitshinweis / {count} Sicherheitshinweise |
| app_es.arb | Detalles | Quitar resaltado | 1 observación de seguridad / {count} observaciones de seguridad |
| app_fr.arb | Détails | Effacer la surbrillance | 1 observation de sécurité / {count} observations de sécurité |
| app_he.arb | פרטים | ניקוי הדגשה | ממצא בטיחות אחד / {count} ממצאי בטיחות |
| app_hu.arb | Részletek | Kiemelés törlése | 1 biztonsági megállapítás / {count} biztonsági megállapítás |
| app_it.arb | Dettagli | Rimuovi evidenziazione | 1 rilievo di sicurezza / {count} rilievi di sicurezza |
| app_nl.arb | Details | Markering wissen | 1 veiligheidsbevinding / {count} veiligheidsbevindingen |
| app_pt.arb | Detalhes | Limpar destaque | 1 observação de segurança / {count} observações de segurança |
| app_zh.arb | 详情 | 清除高亮 | {count} 条安全提示 (single "other" form; zh has no plural split — mirror how zh formats safetyReview_findingCount) |

Then regenerate (from the worktree root — verify `pwd` first):

```bash
flutter gen-l10n
```

- [ ] **Step 4: Run tests to verify everything passes**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart test/features/dive_log/presentation/widgets/safety_review_section_test.dart --timeout 120s`
Expected: PASS. Note: the section test `'a finding without timestamps is not tappable'` uses a finding with BOTH timestamps null, so it still passes; if any section test constructs a start-only finding and expects it inert, update that expectation (start-only findings are now tappable instants).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Extract shared safety finding text and chart-filter helpers, add callout strings"
```

---

### Task 5: SafetyFindingsOverlay widget (lane chips + callout)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/eager_tap_gesture_recognizer.dart`
- Create: `lib/features/dive_log/presentation/widgets/safety_findings_overlay.dart`
- Modify: `lib/features/dive_log/presentation/widgets/photo_marker_overlay.dart` (use the extracted recognizer)
- Test: `test/features/dive_log/presentation/widgets/safety_findings_overlay_test.dart`

**Interfaces:**
- Consumes: `layoutSafetyLaneChips` / `SafetyLaneChipPlacement` (Task 3), `safetyFindingTitle` / `safetyFindingShortLabel` (Task 4), `safetySeverityColor`, `SafetyFinding`, `UnitFormatter`.
- Produces (mounted by Task 6):

```dart
class SafetyFindingsOverlay extends StatelessWidget {
  final List<SafetyFinding> findings;      // pre-filtered via chartSafetyFindings
  final String? selectedFindingId;
  final double visibleMinSeconds;
  final double visibleMaxSeconds;
  final ({double left, double top, double right, double bottom}) insets;
  final double laneHeight;
  final double laneBottomOffset;           // px from overlay bottom to lane bottom
  final UnitFormatter units;
  final void Function(SafetyFinding finding) onFindingTap;   // select/toggle
  final void Function(SafetyFinding finding) onFindingDismiss;
  final void Function(SafetyFinding finding)? onFindingDetails; // null hides link
}
```

Tap contract: `onFindingTap` is a toggle request — the parent selects the finding, or clears when it is already selected. The overlay's cluster cycling builds on that: tap with none of the cluster selected reports the first member; with member *i* selected reports member *i+1*; with the last member selected reports that same last member (parent toggle clears).

- [ ] **Step 1: Extract the eager tap recognizer**

Create `lib/features/dive_log/presentation/widgets/eager_tap_gesture_recognizer.dart` by moving `_EagerTapGestureRecognizer` out of `photo_marker_overlay.dart`, renamed public, with its full doc comment:

```dart
import 'package:flutter/gestures.dart';

/// A tap that wins its gesture arena the instant the pointer lifts.
///
/// (move the complete comment block from photo_marker_overlay.dart:11-24 here)
class EagerTapGestureRecognizer extends TapGestureRecognizer {
  EagerTapGestureRecognizer({super.debugOwner});

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      resolve(GestureDisposition.accepted);
    }
    super.handlePrimaryPointer(event);
  }
}
```

In `photo_marker_overlay.dart`: delete the private class, import the new file, and replace the three `_EagerTapGestureRecognizer` references with `EagerTapGestureRecognizer`.

Run: `flutter test test/features/dive_log/presentation/widgets/ --timeout 120s`
Expected: PASS (pure move).

- [ ] **Step 2: Write the failing overlay tests**

Create `test/features/dive_log/presentation/widgets/safety_findings_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/features/settings/domain/entities/app_settings.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  SafetyFinding finding(
    String id, {
    required int start,
    int? end,
    SafetyRuleId rule = SafetyRuleId.rapidAscent,
  }) {
    return SafetyFinding(
      id: id,
      diveId: 'd1',
      ruleId: rule,
      severity: SafetySeverity.caution,
      startTimestamp: start,
      endTimestamp: end,
      value: 14,
      engineVersion: 1,
      createdAt: DateTime(2026),
    );
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required List<SafetyFinding> findings,
    String? selectedFindingId,
    void Function(SafetyFinding)? onTap,
    void Function(SafetyFinding)? onDismiss,
    void Function(SafetyFinding)? onDetails,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: SafetyFindingsOverlay(
              findings: findings,
              selectedFindingId: selectedFindingId,
              visibleMinSeconds: 0,
              visibleMaxSeconds: 1000,
              insets: (left: 48, top: 0, right: 38, bottom: 96),
              laneHeight: 24,
              laneBottomOffset: 36,
              units: UnitFormatter(const AppSettings()),
              onFindingTap: onTap ?? (_) {},
              onFindingDismiss: onDismiss ?? (_) {},
              onFindingDetails: onDetails,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one chip per finding', (tester) async {
    await pumpOverlay(
      tester,
      findings: [
        finding('a', start: 100, end: 200),
        finding('b', start: 800, end: 800),
      ],
    );
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-1')), findsOneWidget);
  });

  testWidgets('tapping a chip reports its finding', (tester) async {
    SafetyFinding? tapped;
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('overlapping findings cluster into one chip with a count', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [
        finding('a', start: 500, end: 500),
        finding('b', start: 505, end: 505),
      ],
    );
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-1')), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('cluster tap cycles: first, next, then toggles last to clear', (
    tester,
  ) async {
    final findings = [
      finding('a', start: 500, end: 500),
      finding('b', start: 505, end: 505),
    ];
    SafetyFinding? tapped;

    await pumpOverlay(tester, findings: findings, onTap: (f) => tapped = f);
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'a');

    await pumpOverlay(
      tester,
      findings: findings,
      selectedFindingId: 'a',
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'b');

    await pumpOverlay(
      tester,
      findings: findings,
      selectedFindingId: 'b',
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'b'); // parent toggle clears
  });

  testWidgets('selection shows the callout with title and actions', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
      onDetails: (_) {},
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('callout hides the Details link when onFindingDetails is null', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
    );
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('callout actions invoke their callbacks', (tester) async {
    SafetyFinding? cleared;
    SafetyFinding? dismissed;
    SafetyFinding? details;
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
      onTap: (f) => cleared = f,
      onDismiss: (f) => dismissed = f,
      onDetails: (f) => details = f,
    );
    await tester.tap(find.text('Details'));
    expect(details?.id, 'a');
    await tester.tap(find.text('Dismiss'));
    expect(dismissed?.id, 'a');
    await tester.tap(find.byIcon(Icons.close));
    expect(cleared?.id, 'a'); // clear = toggle-tap of the selected finding
  });

  testWidgets('no callout when the selected finding is not in the lane', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'gone',
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsNothing);
  });
}
```

Note: if `AppSettings` has no const default constructor, build the settings object the way `UnitFormatter` tests in this repo do (check `test/core/utils/unit_formatter_test.dart` and mirror it).

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_findings_overlay_test.dart`
Expected: FAIL — widget not defined.

- [ ] **Step 4: Implement the overlay**

Create `lib/features/dive_log/presentation/widgets/safety_findings_overlay.dart`. Structure (follow `photo_marker_overlay.dart` conventions; StatelessWidget — all state lives in the parent via `selectedFindingId`):

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/eager_tap_gesture_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_lane_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Chart overlay hosting the safety findings lane (tappable chips below the
/// plot) and the callout card for the selected finding. A widget layer, not
/// an fl_chart element, so taps never enter the chart's gesture arena
/// (PhotoMarkerOverlay precedent).
class SafetyFindingsOverlay extends StatelessWidget {
  // ... fields exactly as the Interfaces block above ...

  static const double _chipVerticalInset = 3.0;
  static const double _calloutMaxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth =
            constraints.maxWidth - insets.left - insets.right;
        if (laneWidth <= 0 || findings.isEmpty) {
          return const SizedBox.shrink();
        }
        final placements = layoutSafetyLaneChips(
          ranges: [
            for (final f in findings)
              (
                startSeconds: f.startTimestamp!.toDouble(),
                endSeconds: (f.endTimestamp ?? f.startTimestamp!).toDouble(),
              ),
          ],
          visibleMinSeconds: visibleMinSeconds,
          visibleMaxSeconds: visibleMaxSeconds,
          laneWidth: laneWidth,
        );
        if (placements.isEmpty) return const SizedBox.shrink();

        final laneTop =
            constraints.maxHeight - laneBottomOffset - laneHeight;

        SafetyLaneChipPlacement? selectedPlacement;
        if (selectedFindingId != null) {
          for (final p in placements) {
            if (p.memberIndexes.any(
              (i) => findings[i].id == selectedFindingId,
            )) {
              selectedPlacement = p;
              break;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Lane background strip.
            Positioned(
              left: insets.left,
              top: laneTop,
              width: laneWidth,
              height: laneHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < placements.length; i++)
              Positioned(
                key: ValueKey('safetyLaneChip-$i'),
                left: insets.left + placements[i].left,
                top: laneTop,
                width: placements[i].width,
                height: laneHeight,
                child: _buildChip(context, placements[i]),
              ),
            if (selectedPlacement != null)
              _buildCallout(
                context,
                selectedPlacement,
                constraints,
                laneTop,
              ),
          ],
        );
      },
    );
  }
}
```

Implementation notes for the private builders (write them in full; keep each focused):

- `_buildChip(BuildContext, SafetyLaneChipPlacement)`: resolve the cluster's severity as the most severe member (`SafetySeverity.values` order is info < caution < significant); color `safetySeverityColor(severity, colorScheme)`. Pill: `Container` inset vertically by `_chipVerticalInset`, `BorderRadius.circular((laneHeight - 2 * _chipVerticalInset) / 2)`, background color at alpha 0.9 — when any selection is active and this chip is not the selected one, drop to alpha 0.45. Selected chip gets `Border.all(color: severityColor, width: 2)`. Content row centered: `Icon(Icons.report_problem_outlined, size: 12)` for caution/significant or `Icons.info_outline` for info (same mapping as `_FindingTile._iconFor`), icon color = the tile's contrast trick: use `colorScheme.surface` for legibility on the colored pill. If `placement.width > 60` and the cluster has a single member, add the `safetyFindingShortLabel` text (`labelSmall`, ellipsized). If members > 1, add a count badge (`Text('${members.length}')` in a small circle, `colorScheme.primary` background — mirror `photo_marker_overlay.dart:269-291`). Wrap in `Semantics(button: true, label: ...)` — single member: `safetyFindingTitle(...)`; cluster: `context.l10n.safetyReview_findingGroupSemantics(members.length)`. Tap via a `RawGestureDetector` with `EagerTapGestureRecognizer` (copy `_eagerTap` from `photo_marker_overlay.dart:124-142` as a private helper) calling `_handleTap`.
- `_handleTap(List<SafetyFinding> members)` (members = `[for (final i in placement.memberIndexes) findings[i]]`):

```dart
  void _handleTap(List<SafetyFinding> members) {
    final selectedIdx = members.indexWhere((f) => f.id == selectedFindingId);
    if (selectedIdx == -1) {
      onFindingTap(members.first);
    } else if (selectedIdx < members.length - 1) {
      onFindingTap(members[selectedIdx + 1]);
    } else {
      // Last member selected: report it again so the parent toggle clears.
      onFindingTap(members.last);
    }
  }
```

- `_buildCallout(context, placement, constraints, laneTop)`: the selected finding is `findings.firstWhere((f) => f.id == selectedFindingId)`. Card centered over the chip center (`insets.left + placement.left + placement.width / 2`), clamped so `[left, left + width]` stays within `[insets.left, insets.left + laneWidth]`; width `math.min(_calloutMaxWidth, laneWidth)`. `Positioned(bottom: laneBottomOffset + laneHeight + 6, ...)` with `key: const ValueKey('safetyFindingCallout')`. `Material(elevation: 6, borderRadius: BorderRadius.circular(10), color: colorScheme.surfaceContainerHigh)` containing a `Padding(8)` column: header row (severity icon + `Expanded(Text(safetyFindingTitle(finding, context.l10n, units), style: bodySmall, maxLines: 2))` + `IconButton(icon: Icon(Icons.close, size: 18), tooltip: context.l10n.safetyReview_clearHighlight, onPressed: () => onFindingTap(finding))`), then an action row: `if (onFindingDetails != null) TextButton(child: Text(context.l10n.safetyReview_details), onPressed: () => onFindingDetails!(finding))` and `TextButton(child: Text(context.l10n.safetyReview_dismiss), onPressed: () => onFindingDismiss(finding))`. All buttons use the eager-tap-safe defaults (TextButton/IconButton are fine here — they sit above the chart's detector, and the callout floats over the plot where the double-tap-zoom hold matters less; if taps feel laggy in manual testing, wrap with the eager helper, but do not block on it).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_findings_overlay_test.dart test/features/dive_log/presentation/widgets/ --timeout 120s`
Expected: PASS (including all existing photo-marker tests after the recognizer extraction).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Add safety findings lane overlay with chip clustering and callout"
```

---

### Task 6: Mount the lane in DiveProfileChart (reservations + params)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_safety_lane_test.dart` (new)

**Interfaces:**
- Consumes: `SafetyFindingsOverlay` (Task 5), `SafetyFinding`.
- Produces — new optional `DiveProfileChart` parameters (used by Tasks 7 and 8):

```dart
  final List<SafetyFinding>? safetyFindings;         // pre-filtered, sorted
  final String? selectedSafetyFindingId;
  final void Function(SafetyFinding finding)? onSafetyFindingTap;
  final void Function(SafetyFinding finding)? onSafetyFindingDismiss;
  final void Function(SafetyFinding finding)? onSafetyFindingDetails;
  static const double safetyLaneHeight = 24.0;
```

The lane renders only when `safetyFindings` is non-empty AND `onSafetyFindingTap` is non-null. Vertical order below the plot: gas strip (adjacent to plot), then safety lane, then tick labels, then axis name.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/dive_profile_chart_safety_lane_test.dart`, reusing the pump pattern from `dive_profile_chart_highlight_test.dart` (same imports, same 10-point profile, same `MockSettingsNotifier` override):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  SafetyFinding finding(String id, {required int start, int? end}) {
    return SafetyFinding(
      id: id,
      diveId: 'd1',
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.caution,
      startTimestamp: start,
      endTimestamp: end,
      value: 14,
      engineVersion: 1,
      createdAt: DateTime(2026),
    );
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    List<SafetyFinding>? safetyFindings,
    String? selectedId,
    void Function(SafetyFinding)? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                safetyFindings: safetyFindings,
                selectedSafetyFindingId: selectedId,
                onSafetyFindingTap: onTap ?? (safetyFindings != null ? (_) {} : null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no findings renders no lane overlay', (tester) async {
    await pumpChart(tester);
    expect(find.byType(SafetyFindingsOverlay), findsNothing);
  });

  testWidgets('findings render the lane overlay with chips', (tester) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
    );
    expect(find.byType(SafetyFindingsOverlay), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
  });

  testWidgets('chip tap reaches the chart callback', (tester) async {
    SafetyFinding? tapped;
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('selected finding shows the callout above the lane', (
    tester,
  ) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      selectedId: 'a',
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_safety_lane_test.dart`
Expected: FAIL — unknown chart parameters.

- [ ] **Step 3: Implement the chart integration**

All in `dive_profile_chart.dart`:

3a. Add the five fields near `highlightRange` (~`:201`) with doc comments, the `safetyLaneHeight` constant near `gasTimelineHeight` (~`:175`), and the constructor parameters near `this.highlightRange` (~`:505`).

3b. Add the gate next to `_hasGasStrip` (~`:2107`):

```dart
  /// Whether the safety findings lane renders. Widget-param based (no
  /// provider read) so it is safe from both build and gesture paths.
  bool get _hasSafetyLane =>
      (widget.safetyFindings?.isNotEmpty ?? false) &&
      widget.onSafetyFindingTap != null;
```

3c. Extend every bottom reservation that currently special-cases the gas strip. There are four sites; in each, add the lane height when `_hasSafetyLane`:

- `bottomTitles.sideTitles.reservedSize` (~`:2321-2324`):

```dart
                  reservedSize:
                      DiveProfileChart._bottomTickReservedSize +
                      (_hasGasStrip ? DiveProfileChart.gasTimelineHeight : 0) +
                      (_hasSafetyLane
                          ? DiveProfileChart.safetyLaneHeight
                          : 0),
```

- `SideTitleWidget space` (~`:2337-2339`):

```dart
                      space:
                          8 +
                          (_hasGasStrip
                              ? DiveProfileChart.gasTimelineHeight
                              : 0) +
                          (_hasSafetyLane
                              ? DiveProfileChart.safetyLaneHeight
                              : 0),
```

- `_plotInsets` bottom (~`:1537-1542`) — same shape (note `_plotInsets` reads gas-strip visibility via `ref.read`; `_hasSafetyLane` reads only widget fields, which is safe):

```dart
      bottom:
          DiveProfileChart._bottomAxisNameSize +
          DiveProfileChart._bottomTickReservedSize +
          (hasGasStrip ? DiveProfileChart.gasTimelineHeight : 0) +
          (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
```

- Gas strip `Positioned.bottom` (~`:3435-3437`) and the cursor-extension `Positioned.bottom` (~`:3526-3528`) — the gas strip sits ABOVE the lane, so both gain the lane height:

```dart
            bottom:
                DiveProfileChart._bottomAxisNameSize +
                DiveProfileChart._bottomTickReservedSize +
                (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
```

3d. Mount the overlay as the LAST child of the chart Stack, after the `PhotoMarkerOverlay` block (~`:3478`):

```dart
        // Safety findings lane + callout: a widget layer like the photo
        // markers, occupying the extra bottom reservation added by
        // _hasSafetyLane, directly between the gas strip (or plot) and the
        // tick labels.
        if (_hasSafetyLane)
          Positioned.fill(
            child: SafetyFindingsOverlay(
              findings: widget.safetyFindings!,
              selectedFindingId: widget.selectedSafetyFindingId,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              insets: _plotInsets(availableWidth, units),
              laneHeight: DiveProfileChart.safetyLaneHeight,
              laneBottomOffset:
                  DiveProfileChart._bottomAxisNameSize +
                  DiveProfileChart._bottomTickReservedSize,
              units: units,
              onFindingTap: widget.onSafetyFindingTap!,
              onFindingDismiss: widget.onSafetyFindingDismiss ?? (_) {},
              onFindingDetails: widget.onSafetyFindingDetails,
            ),
          ),
```

The mounting site's enclosing builder must have `visibleMinX`/`visibleMaxX`/`availableWidth`/`units` in scope — it is the same Stack that mounts the gas strip and photo overlay, which already use all four.

3e. Cache note: the lane is a widget layer and the highlight is `rangeAnnotations` — neither goes through `_barsCache`, so no signature changes. Do NOT add safety params to any `_barsCache` signature.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_safety_lane_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart --timeout 120s`
Expected: PASS. Also run the broader chart tests to catch reservation regressions: `flutter test test/features/dive_log/presentation/widgets/ --timeout 300s` — expected PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Mount the safety findings lane in the dive profile chart"
```

---

### Task 7: Detail page wiring (lane data, dismiss helper, Details scroll, stale-selection guard)

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/safety_review_providers.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_review_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (chart wiring ~`:1636-1741`, section builder ~`:312-319`, state class fields)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`, `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`, `test/features/dive_log/presentation/providers/safety_review_providers_test.dart`

**Interfaces:**
- Consumes: chart params (Task 6), `chartSafetyFindings` (Task 4), `selectedSafetyFindingProvider`, `safetyReviewProvider`, `settingsProvider`, `SafetyFindingsRepository.setDismissed`.
- Produces: `Future<void> setSafetyFindingDismissed(WidgetRef ref, {required SafetyFinding finding, required bool dismissed})` in `safety_review_providers.dart` — Task 8 reuses it.

- [ ] **Step 1: Write the failing tests**

In `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`, extend the `'safety finding highlight wiring'` group (~`:1410`; reuse the group's existing dive/finding fixtures and pump helper — read the group first and follow its established setup exactly):

```dart
    testWidgets('active findings reach the chart as lane findings', (
      tester,
    ) async {
      // Arrange a dive whose stored review has one active timestamped
      // finding (the group's existing fixture does this); pump the page.
      // Assert the chart received it:
      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart).first,
      );
      expect(chart.safetyFindings, isNotNull);
      expect(chart.safetyFindings!.map((f) => f.id), [/* fixture id */]);
      expect(chart.onSafetyFindingTap, isNotNull);
      expect(chart.onSafetyFindingDismiss, isNotNull);
      expect(chart.onSafetyFindingDetails, isNotNull);
    });

    testWidgets('chart tap callback toggles the selection provider', (
      tester,
    ) async {
      // Pump as above, grab the chart widget, invoke its callback directly
      // (unit-testing the wiring without pixel-hunting the chip):
      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart).first,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart).first),
      );
      chart.onSafetyFindingTap!(/* fixture finding */);
      expect(
        container.read(selectedSafetyFindingProvider(/* diveId */))?.id,
        /* fixture id */,
      );
      chart.onSafetyFindingTap!(/* fixture finding */); // toggle
      expect(
        container.read(selectedSafetyFindingProvider(/* diveId */)),
        isNull,
      );
    });
```

(The `/* fixture */` markers refer to the concrete ids/objects already defined in that test group — substitute the group's actual fixture names when writing the test; they are group-local so cannot be named here.)

In `test/features/dive_log/presentation/providers/safety_review_providers_test.dart`, add coverage for the new helper (mirror the file's existing repository/container setup):

```dart
    test('setSafetyFindingDismissed clears a matching selection and persists', () async {
      // Seed a review with finding f; select f via
      // container.read(selectedSafetyFindingProvider(diveId).notifier).state = f;
      // call setSafetyFindingDismissed(ref-equivalent, finding: f, dismissed: true)
      // then assert: selection is null, repository row has dismissedAt set,
      // safetyReviewProvider(diveId) refetch shows the finding dismissed.
    });
```

Note: `setSafetyFindingDismissed` takes a `WidgetRef`; in a pure provider test use the section-test approach instead — if the file has no widget pump infrastructure, move this assertion into `safety_review_section_test.dart`'s dismiss group (which already pumps widgets and mocks the repository) by asserting the section still dismisses correctly after the refactor. Do not build new test infrastructure for this.

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart --timeout 300s`
Expected: new tests FAIL (`safetyFindings` param never set); existing tests PASS.

- [ ] **Step 3: Implement**

3a. In `safety_review_providers.dart`, append:

```dart
/// Dismisses or restores a finding and keeps UI state consistent: a dismissed
/// finding can no longer be the chart selection. Persists through
/// SafetyFindingsRepository.setDismissed, which also bumps the parent dive's
/// HLC so the change syncs (findings tables have no HLC of their own).
Future<void> setSafetyFindingDismissed(
  WidgetRef ref, {
  required SafetyFinding finding,
  required bool dismissed,
}) async {
  final diveId = finding.diveId;
  if (dismissed) {
    final selected = ref.read(selectedSafetyFindingProvider(diveId).notifier);
    if (selected.state?.id == finding.id) {
      selected.state = null;
    }
  }
  await ref
      .read(safetyFindingsRepositoryProvider)
      .setDismissed(
        findingId: finding.id,
        dismissed: dismissed,
        now: DateTime.now(),
      );
  ref.invalidate(safetyReviewProvider(diveId));
}
```

Add `import 'package:flutter_riverpod/flutter_riverpod.dart';` if `WidgetRef` is not already resolvable through the existing imports.

3b. In `safety_review_section.dart`, replace `_setDismissed`'s body with a delegate:

```dart
  Future<void> _setDismissed(SafetyFinding finding, bool dismissed) {
    return setSafetyFindingDismissed(
      ref,
      finding: finding,
      dismissed: dismissed,
    );
  }
```

3c. In `dive_detail_page.dart`:

- Add a state field on the page's `ConsumerState` class: `final _safetyReviewSectionKey = GlobalKey();` (next to `_profileChartExportKey`).
- In the section builder (~`:316`), pass the key: `SafetyReviewSection(key: _safetyReviewSectionKey, diveId: dive.id)`.
- In the chart `LayoutBuilder` (~`:1637-1643`), alongside the existing `selectedFinding` watch, add:

```dart
                final safetyReview = ref
                    .watch(safetyReviewProvider(diveId))
                    .value;
                final appSettings = ref.watch(settingsProvider);
                final laneFindings = appSettings.safetyReviewEnabled
                    ? chartSafetyFindings(
                        safetyReview,
                        appSettings.safetyReviewDisabledRules,
                      )
                    : const <SafetyFinding>[];
```

- Pass to `DiveProfileChart` (after `highlightRange:` ~`:1727-1730`):

```dart
                        safetyFindings: laneFindings.isEmpty
                            ? null
                            : laneFindings,
                        selectedSafetyFindingId: selectedFinding?.id,
                        onSafetyFindingTap: (finding) {
                          final notifier = ref.read(
                            selectedSafetyFindingProvider(diveId).notifier,
                          );
                          notifier.state = notifier.state?.id == finding.id
                              ? null
                              : finding;
                        },
                        onSafetyFindingDismiss: (finding) =>
                            setSafetyFindingDismissed(
                              ref,
                              finding: finding,
                              dismissed: true,
                            ),
                        onSafetyFindingDetails: (_) =>
                            _scrollToSafetySection(),
```

- Add the scroll method to the state class:

```dart
  /// Scrolls the page so the safety review section is visible (callout
  /// "Details" action). The selection stays active.
  void _scrollToSafetySection() {
    final ctx = _safetyReviewSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }
```

- Stale-selection guard: in the page's main `build` (where other `ref.listen` calls live, or at the top of build if there are none), add:

```dart
    // A finding dismissed elsewhere (section button, another device via sync,
    // batch re-analysis) must not stay highlighted: drop a selection whose
    // finding no longer exists as an active row.
    ref.listen(safetyReviewProvider(diveId), (previous, next) {
      final review = next.value;
      if (review == null) return;
      final selected = ref.read(selectedSafetyFindingProvider(diveId));
      if (selected == null) return;
      final stillActive = review.findings.any(
        (f) => f.id == selected.id && !f.isDismissed,
      );
      if (!stillActive) {
        ref.read(selectedSafetyFindingProvider(diveId).notifier).state = null;
      }
    });
```

- Imports: `safety_finding.dart` (entity), `safety_finding_highlight.dart` already imported for `profileHighlightRangeFor` — `chartSafetyFindings` comes with it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/widgets/safety_review_section_test.dart test/features/dive_log/presentation/providers/safety_review_providers_test.dart --timeout 300s`
Expected: PASS. Known trap: the detail page now watches `safetyReviewProvider` + `settingsProvider` in the chart region — if any existing page test fails on an unexpected provider state, mirror how the section's tests override the safety repository rather than adding new mocks.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Wire the safety findings lane into the dive detail page"
```

---

### Task 8: Fullscreen parity

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` (chart wiring ~`:299-410`)
- Test: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

**Interfaces:**
- Consumes: chart params (Task 6), `chartSafetyFindings` (Task 4), `setSafetyFindingDismissed` (Task 7), `selectedSafetyFindingProvider`, `safetyReviewProvider`, `settingsProvider`.
- Produces: fullscreen shows the same lane/callout; `onSafetyFindingDetails` is NOT wired there (no section exists in fullscreen — the callout hides the link, per the overlay's nullable-`onFindingDetails` contract). Selection round-trips with the detail page automatically via the shared provider family.

- [ ] **Step 1: Write the failing tests**

In `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`, next to the existing highlight carry-over test (~`:358`, reuse its fixtures/pump):

```dart
    testWidgets('lane findings and selection wiring reach the chart', (
      tester,
    ) async {
      // Same arrangement as the carried-over-highlight test: stored review
      // with an active timestamped finding.
      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart).first,
      );
      expect(chart.safetyFindings, isNotNull);
      expect(chart.onSafetyFindingTap, isNotNull);
      expect(chart.onSafetyFindingDismiss, isNotNull);
      expect(chart.onSafetyFindingDetails, isNull); // no section in fullscreen
    });

    testWidgets('fullscreen tap callback toggles the shared provider', (
      tester,
    ) async {
      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart).first,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart).first),
      );
      chart.onSafetyFindingTap!(/* fixture finding */);
      expect(
        container.read(selectedSafetyFindingProvider(/* diveId */))?.id,
        /* fixture id */,
      );
    });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart --timeout 300s`
Expected: new tests FAIL; existing PASS.

- [ ] **Step 3: Implement**

In `fullscreen_profile_page.dart` `build` (~`:125-155`), alongside the existing `selectedSafetyFindingProvider` watch (~`:152`):

```dart
    final safetyReview = ref.watch(safetyReviewProvider(widget.diveId)).value;
    final appSettings = ref.watch(settingsProvider);
    final laneFindings = appSettings.safetyReviewEnabled
        ? chartSafetyFindings(
            safetyReview,
            appSettings.safetyReviewDisabledRules,
          )
        : const <SafetyFinding>[];
```

Add the same stale-selection `ref.listen` block as Task 7 (identical code, `widget.diveId`). Then pass to the `DiveProfileChart` (~`:299`, near `highlightRange:` ~`:396`):

```dart
                          safetyFindings: laneFindings.isEmpty
                              ? null
                              : laneFindings,
                          selectedSafetyFindingId: ref
                              .watch(
                                selectedSafetyFindingProvider(widget.diveId),
                              )
                              ?.id,
                          onSafetyFindingTap: (finding) {
                            final notifier = ref.read(
                              selectedSafetyFindingProvider(
                                widget.diveId,
                              ).notifier,
                            );
                            notifier.state =
                                notifier.state?.id == finding.id
                                ? null
                                : finding;
                          },
                          onSafetyFindingDismiss: (finding) =>
                              setSafetyFindingDismissed(
                                ref,
                                finding: finding,
                                dismissed: true,
                              ),
```

(Reuse the already-watched selected finding local if the page has one at `:152` instead of re-watching inline — match the file's existing style.) Imports: `safety_finding.dart`, `safety_finding_highlight.dart`, `safety_review_providers.dart` as needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart --timeout 300s`
Expected: PASS, including the pre-existing carried-over-highlight test.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "Add safety findings lane parity to the fullscreen profile"
```

---

### Task 9: Full verification sweep

**Files:** none new.

- [ ] **Step 1: Format the whole project and verify no drift**

```bash
dart format .
git status --short
```
Expected: no modified files. If files changed, commit them as "Format".

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze
```
Run WITHOUT piping through head/grep (piping masks the exit code). Expected: zero issues — infos are CI-fatal in this project; fix any.

- [ ] **Step 3: Run the affected test tree**

```bash
flutter test test/features/dive_log/ --timeout 300s
```
Expected: PASS. Known flaky areas unrelated to this work (backup/media-store suites) are outside this path; if an unrelated flake appears elsewhere later in pre-push, re-run that file alone before assuming this change caused it.

- [ ] **Step 4: Manual smoke check (if a macOS environment is available)**

```bash
flutter run -d macos
```
Open a dive that has safety findings: verify the lane appears under the chart, chips are tappable, the callout's Details scrolls to the section, Dismiss removes the chip, the ✕ clears, a tiny finding shows a visible band, and fullscreen shows the same lane. This step is observational; do not block the branch on it if no device is available.

- [ ] **Step 5: Final commit if anything changed**

```bash
git status --short
```
Commit any stragglers with an accurate message.

---

## Self-review notes (already applied)

- Spec coverage: lane (Tasks 3/5/6), callout with Details/Dismiss/clear (5/7), min-width bands + instant-band vocabulary (1/2), two-way section sync + tile behavior preserved (7, section untouched except refactors), fullscreen parity minus the Details link (8 — the spec's "full parity: lane, callout, and clearing" enumerates exactly what fullscreen gets; Details-to-section is a detail-page navigation and the overlay contract makes it explicitly optional), dismissed/timestampless exclusion (4), stale-selection guard (7/8), cluster cycling (3/5), no schema/sync changes (none anywhere).
- Type consistency: `highlightBandSpan` record return matches `visibleHighlightSpan`'s; `SafetyLaneChipPlacement` names match between Task 3 and Task 5; chart param names match between Task 6 and Tasks 7/8; `setSafetyFindingDismissed` signature matches between Tasks 7 and 8.
- Two intentionally-flagged judgment points for the executor: (a) exact fixture names inside `dive_detail_page_test.dart`'s existing group must be read from that file; (b) `AppSettings` construction in the overlay test should mirror existing `UnitFormatter` test usage.
