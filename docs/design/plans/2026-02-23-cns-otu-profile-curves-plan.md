# CNS% and OTU Profile Curves Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add cumulative CNS% and OTU overlay curves to the dive profile chart, disabled by default, toggleable via the "More" legend popover.

**Architecture:** Follow the existing curve pattern (ppO2, GF%, TTS, etc.): compute curves in `ProfileAnalysisService`, pass as `List<double>?` to `DiveProfileChart`, toggle via `ProfileLegendState`, render with `_buildXxxLine()`. Both curves are cumulative -- CNS starts at residual `startCns`, OTU starts at 0.

**Tech Stack:** Flutter, fl_chart, Riverpod, Drift ORM

---

### Task 1: Add CNS/OTU Curve Calculation to ProfileAnalysisService

**Files:**

- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart`

**Step 1: Add `cnsCurve` and `otuCurve` fields to `ProfileAnalysis`**

In the `ProfileAnalysis` class (around line 249), add after the `ttsCurve` field:

```dart
  /// Cumulative CNS% at each profile point (includes residual from prior dives)
  final List<double>? cnsCurve;

  /// Cumulative OTU at each profile point
  final List<double>? otuCurve;
```text
Add to the constructor (after `this.ttsCurve`):

```dart
    this.cnsCurve,
    this.otuCurve,
```text
Add helper getters (after `hasTtsData`):

```dart
  /// Whether CNS curve data is available
  bool get hasCnsData => cnsCurve != null && cnsCurve!.isNotEmpty;

  /// Whether OTU curve data is available
  bool get hasOtuData => otuCurve != null && otuCurve!.isNotEmpty;
```text
**Step 2: Add `_calculateCnsCurve()` private method**

Add after `_calculateMeanDepthCurve()` (around line 1401):

```dart
  /// Calculate cumulative CNS% curve from ppO2 data.
  ///
  /// Returns a list where each value is the total CNS% accumulated
  /// from dive start (including residual from prior dives) to that point.
  List<double> _calculateCnsCurve({
    required List<double> ppO2Curve,
    required List<int> timestamps,
    required double startCns,
  }) {
    if (ppO2Curve.isEmpty || ppO2Curve.length != timestamps.length) {
      return [];
    }

    final cnsCurve = <double>[startCns];
    double cumulativeCns = startCns;

    for (int i = 1; i < ppO2Curve.length; i++) {
      final duration = timestamps[i] - timestamps[i - 1];
      if (duration <= 0) {
        cnsCurve.add(cumulativeCns);
        continue;
      }

      final avgPpO2 = (ppO2Curve[i - 1] + ppO2Curve[i]) / 2.0;
      cumulativeCns += _o2ToxicityCalculator.calculateCnsForSegment(
        avgPpO2,
        duration,
      );
      cnsCurve.add(cumulativeCns);
    }

    return cnsCurve;
  }
```text
**Step 3: Add `_calculateOtuCurve()` private method**

Add immediately after `_calculateCnsCurve()`:

```dart
  /// Calculate cumulative OTU curve from ppO2 data.
  ///
  /// Returns a list where each value is the total OTU accumulated
  /// from dive start to that point.
  List<double> _calculateOtuCurve({
    required List<double> ppO2Curve,
    required List<int> timestamps,
  }) {
    if (ppO2Curve.isEmpty || ppO2Curve.length != timestamps.length) {
      return [];
    }

    final otuCurve = <double>[0.0];
    double cumulativeOtu = 0.0;

    for (int i = 1; i < ppO2Curve.length; i++) {
      final duration = timestamps[i] - timestamps[i - 1];
      if (duration <= 0) {
        otuCurve.add(cumulativeOtu);
        continue;
      }

      final avgPpO2 = (ppO2Curve[i - 1] + ppO2Curve[i]) / 2.0;
      cumulativeOtu += _o2ToxicityCalculator.calculateOtuForSegment(
        avgPpO2,
        duration,
      );
      otuCurve.add(cumulativeOtu);
    }

    return otuCurve;
  }
```dart
**Step 4: Wire curves into `analyze()` method**

In the `analyze()` method, after line 613 (`final ttsCurve = ...`), add:

```dart
    final cnsCurve = _calculateCnsCurve(
      ppO2Curve: ppO2Curve,
      timestamps: timestamps,
      startCns: startCns,
    );
    final otuCurve = _calculateOtuCurve(
      ppO2Curve: ppO2Curve,
      timestamps: timestamps,
    );
```text
In the `return ProfileAnalysis(...)` block (around line 636), add after `ttsCurve: ttsCurve,`:

```dart
      cnsCurve: cnsCurve,
      otuCurve: otuCurve,
```text
**Step 5: Run tests**

Run: `flutter test test/core/deco/`
Expected: All existing tests PASS (no behavior change to existing code).

**Step 6: Run `dart format`**

Run: `dart format lib/features/dive_log/data/services/profile_analysis_service.dart`

---

### Task 2: Add CNS/OTU to ProfileRightAxisMetric Enum

**Files:**

- Modify: `lib/core/constants/profile_metrics.dart`

**Step 1: Add enum values**

After the `tts` enum value (line 98), add before the closing semicolon:

```dart
  cns(
    displayName: 'CNS%',
    shortName: 'CNS',
    color: Color(0xFFE65100), // Orange 900
    unitSuffix: '%',
    category: ProfileMetricCategory.decompression,
  ),
  otu(
    displayName: 'OTU',
    shortName: 'OTU',
    color: Color(0xFF6D4C41), // Brown 600
    unitSuffix: 'OTU',
    category: ProfileMetricCategory.decompression,
  );
```dart
Note: Move the semicolon from after `tts(...)` to after `otu(...)`.

**Step 2: Run `dart format`**

Run: `dart format lib/core/constants/profile_metrics.dart`

---

### Task 3: Add Toggle State to ProfileLegendProvider

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`

**Step 1: Add fields to `ProfileLegendState`**

After `final bool showTts;` (line 42), add:

```dart
  final bool showCns;
  final bool showOtu;
```text
**Step 2: Update constructor defaults**

After `this.showTts = false,` (line 68), add:

```dart
    this.showCns = false,
    this.showOtu = false,
```text
**Step 3: Update `activeSecondaryCount`**

After `if (showTts) count++;` (line 91), add:

```dart
    if (showCns) count++;
    if (showOtu) count++;
```text
**Step 4: Update `copyWith` method**

Add parameters after `bool? showTts,` (line 121):

```dart
    bool? showCns,
    bool? showOtu,
```text
Add to return object after `showTts: showTts ?? this.showTts,` (line 149):

```dart
      showCns: showCns ?? this.showCns,
      showOtu: showOtu ?? this.showOtu,
```text
**Step 5: Update `==` operator**

Add after `showTts == other.showTts &&` (line 177):

```dart
          showCns == other.showCns &&
          showOtu == other.showOtu &&
```text
**Step 6: Update `hashCode`**

Add after `showTts,` (line 202):

```dart
    showCns,
    showOtu,
```text
**Step 7: Add toggle methods to `ProfileLegend` notifier**

After `toggleTts()` (line 345), add:

```dart
  void toggleCns() {
    state = state.copyWith(showCns: !state.showCns);
  }

  void toggleOtu() {
    state = state.copyWith(showOtu: !state.showOtu);
  }
```dart
**Step 8: Run codegen and format**

Run: `dart run build_runner build --delete-conflicting-outputs && dart format lib/features/dive_log/presentation/providers/profile_legend_provider.dart`

---

### Task 4: Add Legend Config and Menu Items

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`

**Step 1: Add fields to `ProfileLegendConfig`**

After `final bool hasTtsData;` (line 37), add:

```dart
  final bool hasCnsData;
  final bool hasOtuData;
```text
After `this.hasTtsData = false,` (line 62), add:

```dart
    this.hasCnsData = false,
    this.hasOtuData = false,
```text
**Step 2: Wire into `hasSecondaryToggles`**

After `hasTtsData` (line 84), add before the semicolon:

```dart
 ||
      hasCnsData ||
      hasOtuData
```text
**Step 3: Add menu items in `_MoreOptionsButton._buildMenuItems()`**

After the TTS menu item block (after line 639), add:

```dart
    // CNS%
    if (config.hasCnsData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: context.l10n.diveLog_legend_label_cns,
          color: const Color(0xFFE65100), // Orange 900
          isEnabled: legendState.showCns,
          onTap: legendNotifier.toggleCns,
        ),
      );
    }

    // OTU
    if (config.hasOtuData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: context.l10n.diveLog_legend_label_otu,
          color: const Color(0xFF6D4C41), // Brown 600
          isEnabled: legendState.showOtu,
          onTap: legendNotifier.toggleOtu,
        ),
      );
    }
```text
**Step 4: Update `_activeSecondaryCount`**

After `if (config.hasTtsData && legendState.showTts) count++;` (line 307), add:

```dart
    if (config.hasCnsData && legendState.showCns) count++;
    if (config.hasOtuData && legendState.showOtu) count++;
```text
**Step 5: Run `dart format`**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`

---

### Task 5: Add Localization Keys

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add legend and tooltip labels**

Near the existing `diveLog_legend_label_` entries, add:

```json
  "diveLog_legend_label_cns": "CNS%",
  "diveLog_legend_label_otu": "OTU",
```text
Near the existing `diveLog_tooltip_` entries, add:

```json
  "diveLog_tooltip_cns": "CNS",
  "diveLog_tooltip_otu": "OTU",
```dart
**Step 2: Run l10n generation**

Run: `flutter gen-l10n`

If this command is not configured, the localization delegates may auto-generate on build. Verify by running `flutter analyze` to check for missing key errors.

---

### Task 6: Add Chart Parameters and Rendering

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

**Step 1: Add widget parameters**

After `final List<int>? ttsCurve;` (line 120), add:

```dart
  /// Cumulative CNS% curve (includes residual from prior dives)
  final List<double>? cnsCurve;

  /// Cumulative OTU curve
  final List<double>? otuCurve;
```text
After `this.ttsCurve,` in the constructor (line 167), add:

```dart
    this.cnsCurve,
    this.otuCurve,
```text
**Step 2: Add local state booleans**

After `bool _showTts = false;` (line 206), add:

```dart
  bool _showCns = false;
  bool _showOtu = false;
```text
**Step 3: Sync local state from legend provider**

After `_showTts = legendState.showTts;` (line 413), add:

```dart
    _showCns = legendState.showCns;
    _showOtu = legendState.showOtu;
```dart
**Step 4: Add data availability checks**

After `final hasTtsData = ...` (line 435), add:

```dart
    final hasCnsData =
        widget.cnsCurve != null && widget.cnsCurve!.isNotEmpty;
    final hasOtuData =
        widget.otuCurve != null && widget.otuCurve!.isNotEmpty;
```text
**Step 5: Wire into `ProfileLegendConfig`**

After `hasTtsData: hasTtsData,` (line 463), add:

```dart
      hasCnsData: hasCnsData,
      hasOtuData: hasOtuData,
```text
**Step 6: Add line rendering calls**

After the TTS line rendering block (line 955), add:

```dart
              // CNS% curve (if showing)
              if (_showCns && widget.cnsCurve != null)
                _buildCnsLine(totalMaxDepth),

              // OTU curve (if showing)
              if (_showOtu && widget.otuCurve != null)
                _buildOtuLine(totalMaxDepth),
```text
**Step 7: Add tooltip rows**

After the TTS tooltip block (around line 1379), add:

```dart
                    // CNS% (if enabled)
                    if (_showCns) {
                      String cnsValue = '\u2014';
                      if (widget.cnsCurve != null &&
                          spot.spotIndex < widget.cnsCurve!.length) {
                        final cns = widget.cnsCurve![spot.spotIndex];
                        cnsValue = '${cns.toStringAsFixed(1)}%';
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_cns,
                        cnsValue,
                        const Color(0xFFE65100),
                      );
                    }

                    // OTU (if enabled)
                    if (_showOtu) {
                      String otuValue = '\u2014';
                      if (widget.otuCurve != null &&
                          spot.spotIndex < widget.otuCurve!.length) {
                        final otu = widget.otuCurve![spot.spotIndex];
                        otuValue = otu.toStringAsFixed(0);
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_otu,
                        otuValue,
                        const Color(0xFF6D4C41),
                      );
                    }
```text
**Step 8: Add `_buildCnsLine()` method**

Add after `_buildTtsLine()` method (or after `_buildSurfaceGfLine()`):

```dart
  /// Build cumulative CNS% line
  LineChartBarData _buildCnsLine(double chartMaxDepth) {
    final cnsData = widget.cnsCurve!;
    const cnsColor = Color(0xFFE65100); // Orange 900

    // Map CNS% to chart: 0% at top, 200% at bottom
    const minCns = 0.0;
    const maxCns = 200.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < cnsData.length; i++) {
      final cns = cnsData[i].clamp(minCns, maxCns);
      final yValue = _mapValueToDepth(cns, chartMaxDepth, minCns, maxCns);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: cnsColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3],
    );
  }
```text
**Step 9: Add `_buildOtuLine()` method**

Add immediately after `_buildCnsLine()`:

```dart
  /// Build cumulative OTU line
  LineChartBarData _buildOtuLine(double chartMaxDepth) {
    final otuData = widget.otuCurve!;
    const otuColor = Color(0xFF6D4C41); // Brown 600

    // Map OTU to chart: 0 at top, 300 at bottom (daily limit)
    const minOtu = 0.0;
    const maxOtu = 300.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < otuData.length; i++) {
      final otu = otuData[i].clamp(minOtu, maxOtu);
      final yValue = _mapValueToDepth(otu, chartMaxDepth, minOtu, maxOtu);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: otuColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
    );
  }
```text
**Step 10: Add right-axis support in `_hasDataForMetric()`**

After the `case ProfileRightAxisMetric.tts:` block (line 2496), add:

```dart
      case ProfileRightAxisMetric.cns:
        return widget.cnsCurve != null && widget.cnsCurve!.isNotEmpty;
      case ProfileRightAxisMetric.otu:
        return widget.otuCurve != null && widget.otuCurve!.isNotEmpty;
```text
**Step 11: Add right-axis ranges in `_getMetricRange()`**

After the `case ProfileRightAxisMetric.tts:` block (line 2587), add:

```dart
      case ProfileRightAxisMetric.cns:
        return (min: 0.0, max: 200.0); // 0-200%

      case ProfileRightAxisMetric.otu:
        return (min: 0.0, max: 300.0); // 0-300 OTU daily limit
```text
**Step 12: Add right-axis value formatting in `_formatRightAxisValue()`**

In the switch (around line 2616), add CNS and OTU to the group that uses `toStringAsFixed(0)`:

```dart
      case ProfileRightAxisMetric.cns:
      case ProfileRightAxisMetric.otu:
        return value.toStringAsFixed(0);
```text
**Step 13: Run `dart format`**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

---

### Task 7: Wire Data Through Dive Detail Page

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 1: Add to inline chart**

After `ttsCurve: analysis?.ttsCurve,` (line 885), add:

```dart
                      cnsCurve: analysis?.cnsCurve,
                      otuCurve: analysis?.otuCurve,
```text
**Step 2: Add to fullscreen chart**

After `ttsCurve: widget.analysis?.ttsCurve,` (line 3861), add:

```dart
                      cnsCurve: widget.analysis?.cnsCurve,
                      otuCurve: widget.analysis?.otuCurve,
```text
**Step 3: Add to fullscreen readout (expanded metrics)**

After the TTS block (around line 4192), add:

```dart
    final cnsValue = getCurveValue(
      analysis?.cnsCurve,
      (v) => '${v.toStringAsFixed(1)}%',
    );
    if (cnsValue != null) {
      depthTimeItems.add((context.l10n.diveLog_legend_label_cns, cnsValue));
    }

    final otuValue = getCurveValue(
      analysis?.otuCurve,
      (v) => v.toStringAsFixed(0),
    );
    if (otuValue != null) {
      depthTimeItems.add((context.l10n.diveLog_legend_label_otu, otuValue));
    }
```text
**Step 4: Add to compact metrics readout**

After the TTS compact block (around line 4444), add:

```dart
    // CNS%
    final cnsValue = getCurveValue(
      analysis?.cnsCurve,
      (v) => '${v.toStringAsFixed(1)}%',
    );
    if (cnsValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_cns,
          cnsValue,
        ),
      );
    }

    // OTU
    final otuValue = getCurveValue(
      analysis?.otuCurve,
      (v) => v.toStringAsFixed(0),
    );
    if (otuValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_otu,
          otuValue,
        ),
      );
    }
```

**Step 5: Run `dart format`**

Run: `dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

### Task 8: Build Verification

**Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors. Warnings about unused imports are OK if from generated code.

**Step 2: Run full test suite**

Run: `flutter test`
Expected: All existing tests PASS.

**Step 3: Run format check**

Run: `dart format --set-exit-if-changed lib/`
Expected: No formatting changes needed.

---

### Task 9: Manual Smoke Test

**Step 1: Launch app**

Run: `flutter run -d macos`

**Step 2: Verify CNS/OTU in profile chart**

1. Open a dive with profile data
2. Tap the "tune" (more options) icon on the profile chart legend
3. Scroll down to the decompression section
4. Verify "CNS%" and "OTU" toggles appear
5. Toggle CNS% on -- verify an orange dashed curve appears on the chart
6. Toggle OTU on -- verify a brown dashed curve appears on the chart
7. Touch/hover over the chart -- verify CNS% and OTU values appear in tooltip
8. Toggle both off -- curves disappear

**Step 3: Test fullscreen view**

1. Tap the fullscreen icon on the profile chart
2. Verify CNS/OTU toggles persist in fullscreen
3. Verify curves render correctly in landscape mode

---
