# OTU Stacked Bars Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the text-only OTU metrics row in `CompactO2ToxicityPanel` with two full-width stacked bars (Daily and Weekly) that mirror the existing CNS Oxygen Clock bar pattern.

**Architecture:** The existing `_buildOtuBreakdown` method (3-column text row) and `_buildOtuMetric` helper in `CompactO2ToxicityPanel` are replaced with `_buildOtuProgress` (renders two vertical bar sections) and `_buildStackedOtuBar` (renders one 4-layer stacked bar). All data is already available via `O2Exposure` fields and the `weeklyOtu` parameter -- no provider or data model changes needed.

**Tech Stack:** Flutter widgets, `O2Exposure` entity, `CompactO2ToxicityPanel` widget, localization (ARB)

---

### Task 1: Write widget tests for the new OTU stacked bars

**Files:**

- Create: `test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart`

**Step 1: Write failing tests for daily and weekly OTU bar rendering**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  // Shared exposure: 43 OTU this dive, 42 OTU from prior same-day dives
  // Daily total = 42 + 43 = 85 / 300 (28%)
  const exposure = O2Exposure(
    cnsStart: 5.0,
    cnsEnd: 12.0,
    otu: 43.0,
    otuStart: 42.0,
    maxPpO2: 1.3,
    maxPpO2Depth: 28.0,
  );

  Widget buildPanel({
    O2Exposure exp = exposure,
    double? selectedOtu,
    double? weeklyOtu,
  }) {
    return localizedMaterialApp(
      home: Scaffold(
        body: CompactO2ToxicityPanel(
          exposure: exp,
          selectedOtu: selectedOtu,
          weeklyOtu: weeklyOtu,
        ),
      ),
    );
  }

  group('CompactO2ToxicityPanel OTU bars', () {
    testWidgets('renders daily OTU header with value and limit', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();

      // Should show "Daily" label
      expect(find.text('Daily'), findsOneWidget);
      // Should show "85 / 300 OTU" (otuDaily / dailyOtuLimit)
      expect(find.text('85 / 300 OTU'), findsOneWidget);
    });

    testWidgets('renders weekly OTU header with value and limit', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      expect(find.text('Weekly'), findsOneWidget);
      // weeklyOtu = 320, limit = 850
      expect(find.text('320 / 850 OTU'), findsOneWidget);
    });

    testWidgets('renders daily footer with start and delta', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();

      // Footer: "Start: 42 OTU" and "+43 this dive"
      expect(find.text('Start: 42 OTU'), findsOneWidget);
      expect(find.text('+43 this dive'), findsOneWidget);
    });

    testWidgets('renders weekly footer with prior and delta', (tester) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      // Prior = weeklyOtu - otu = 320 - 43 = 277
      expect(find.text('Prior: 277 OTU'), findsOneWidget);
      // "+43 this dive" appears twice (daily + weekly)
      expect(find.text('+43 this dive'), findsAtLeast(2));
    });

    testWidgets('shows cursor value in daily header when selectedOtu provided',
        (tester) async {
      await tester.pumpWidget(buildPanel(selectedOtu: 21));
      await tester.pumpAndSettle();

      // Cursor mode: "21 / 85 / 300 OTU"
      expect(find.text('21 / 85 / 300 OTU'), findsOneWidget);
    });

    testWidgets('falls back to this-dive OTU when weeklyOtu is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: null));
      await tester.pumpAndSettle();

      // When weeklyOtu is null, total = exposure.otu = 43, prior = 0
      expect(find.text('43 / 850 OTU'), findsOneWidget);
      expect(find.text('Prior: 0 OTU'), findsOneWidget);
    });

    testWidgets('does not render old 3-column text metrics', (tester) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      // The old "This Dive" text metric column should be gone
      // (The "This Dive" label was part of _buildOtuMetric)
      // Now only "Daily" and "Weekly" labels should exist as section headers
      expect(find.text('This Dive'), findsNothing);
    });

    testWidgets('renders no prior segment when otuStart is zero', (
      tester,
    ) async {
      const noPrior = O2Exposure(
        cnsStart: 0,
        cnsEnd: 10,
        otu: 43,
        otuStart: 0,
        maxPpO2: 1.2,
        maxPpO2Depth: 25,
      );

      await tester.pumpWidget(buildPanel(exp: noPrior));
      await tester.pumpAndSettle();

      // Start = 0, so footer shows "Start: 0 OTU"
      expect(find.text('Start: 0 OTU'), findsOneWidget);
    });
  });
}
```text
**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart`
Expected: FAIL -- tests look for "Daily" header label, "85 / 300 OTU", etc. which don't exist yet (the current widget renders "This Dive", "Daily (%)", "Weekly (%)" in a different format).

---

### Task 2: Replace `_buildOtuBreakdown` with `_buildOtuProgress` and add `_buildStackedOtuBar`

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart:469-506` (build method, line ~486)
- Modify: `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart:715-886` (remove old methods, add new ones)

**Step 1: Update the `build` method to call `_buildOtuProgress` instead of `_buildOtuBreakdown`**

In `CompactO2ToxicityPanel.build()`, change:

```dart
        // OTU breakdown (This Dive, Daily, Weekly)
        _buildOtuBreakdown(context, colorScheme, textTheme),
```yaml
to:

```dart
        // OTU progress bars (Daily + Weekly)
        _buildOtuProgress(context, colorScheme, textTheme),
```text
**Step 2: Remove the old `_buildOtuBreakdown` and `_buildOtuMetric` methods**

Delete the following methods from `CompactO2ToxicityPanel`:

- `_buildOtuBreakdown` (lines 715-780)
- `_buildOtuMetric` (lines 852-886)

**Step 3: Add the new `_buildOtuProgress` method**

Add this method to `CompactO2ToxicityPanel`, placed after `_buildStackedCnsBar`:

```dart
  Widget _buildOtuProgress(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // Daily data
    final dailyTotal = exposure.otuDaily;
    final dailyPct = exposure.otuDailyPercentOfLimit;
    final dailyColor = _getOtuLimitColor(dailyPct, colorScheme);

    // Weekly data
    final weeklyTotal = weeklyOtu ?? exposure.otu;
    final weeklyPrior = (weeklyTotal - exposure.otu).clamp(0.0, double.infinity);
    final weeklyPct = (weeklyTotal / O2Exposure.weeklyOtuLimit) * 100;
    final weeklyColor = _getOtuLimitColor(weeklyPct, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_o2tox_oxygenToleranceUnits,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),

        // Daily OTU bar
        _buildOtuBarSection(
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'Daily',
          total: dailyTotal,
          limit: O2Exposure.dailyOtuLimit,
          prior: exposure.otuStart,
          thisDive: exposure.otu,
          percent: dailyPct,
          color: dailyColor,
          priorLabel: 'Start: ${exposure.otuStart.toStringAsFixed(0)} OTU',
        ),
        const SizedBox(height: 8),

        // Weekly OTU bar
        _buildOtuBarSection(
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'Weekly',
          total: weeklyTotal,
          limit: O2Exposure.weeklyOtuLimit,
          prior: weeklyPrior,
          thisDive: exposure.otu,
          percent: weeklyPct,
          color: weeklyColor,
          priorLabel: 'Prior: ${weeklyPrior.toStringAsFixed(0)} OTU',
        ),
      ],
    );
  }
```text
**Step 4: Add the `_buildOtuBarSection` method**

This wraps a single bar with header/footer rows:

```dart
  Widget _buildOtuBarSection({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String label,
    required double total,
    required double limit,
    required double prior,
    required double thisDive,
    required double percent,
    required Color color,
    required String priorLabel,
  }) {
    // Header value: "cursor / total / limit" or "total / limit"
    final String headerValue;
    if (selectedOtu != null) {
      headerValue =
          '${selectedOtu!.toStringAsFixed(0)} / '
          '${total.toStringAsFixed(0)} / '
          '${limit.toStringAsFixed(0)} OTU';
    } else {
      headerValue =
          '${total.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} OTU';
    }

    return Semantics(
      label:
          '$label: ${total.toStringAsFixed(0)} of '
          '${limit.toStringAsFixed(0)} OTU, '
          '${percent.toStringAsFixed(0)} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodyMedium),
              Text(
                headerValue,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Stacked bar
          _buildStackedOtuBar(
            colorScheme: colorScheme,
            endColor: color,
            totalFraction: (total / limit).clamp(0.0, 1.0),
            priorFraction: (prior / limit).clamp(0.0, 1.0),
            selectedDelta: selectedOtu,
            limit: limit,
          ),
          const SizedBox(height: 2),

          // Footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                priorLabel,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '+${thisDive.toStringAsFixed(0)} this dive',
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
```text
**Step 5: Add the `_buildStackedOtuBar` method**

This renders the 4-layer stacked bar, mirroring `_buildStackedCnsBar`:

```dart
  /// Builds the stacked OTU bar with up to four layers:
  ///   1. Background track (full width = limit)
  ///   2. Colored bar: total OTU as fraction of limit
  ///   3. Primary overlay: OTU at cursor point during this dive
  ///   4. Prior segment: OTU from prior dives (always visible)
  Widget _buildStackedOtuBar({
    required ColorScheme colorScheme,
    required Color endColor,
    required double totalFraction,
    required double priorFraction,
    required double? selectedDelta,
    required double limit,
  }) {
    const barHeight = 20.0;
    const barRadius = BorderRadius.all(Radius.circular(6));

    return ClipRRect(
      borderRadius: barRadius,
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;

            return Stack(
              children: [
                // Background track
                Container(
                  width: totalWidth,
                  height: barHeight,
                  color: colorScheme.surfaceContainerHighest,
                ),
                // Colored bar: total OTU as fraction of limit
                Container(
                  width: totalWidth * totalFraction,
                  height: barHeight,
                  color: endColor,
                ),
                // Primary overlay: OTU at cursor point
                if (selectedDelta != null && selectedDelta > 0)
                  Positioned(
                    left: totalWidth * priorFraction,
                    child: Container(
                      width:
                          totalWidth *
                          (selectedDelta / limit).clamp(
                            0.0,
                            1.0 - priorFraction,
                          ),
                      height: barHeight,
                      color: colorScheme.primary,
                    ),
                  ),
                // Prior segment: OTU from prior dives (always on top)
                if (priorFraction > 0)
                  Container(
                    width: totalWidth * priorFraction,
                    height: barHeight,
                    color: Colors.blueGrey,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
```text
**Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart`
Expected: PASS

**Step 7: Run full test suite to check for regressions**

Run: `flutter test`
Expected: All tests pass (existing tests that reference `CompactO2ToxicityPanel` may need updating if they checked for "This Dive" text)

**Step 8: Format code**

Run: `dart format lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart`

**Step 9: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart
git commit -m "feat: replace OTU text metrics with stacked daily/weekly bars

Replace _buildOtuBreakdown 3-column text row with _buildOtuProgress
rendering two full-width stacked bars (Daily 300 OTU limit, Weekly
850 OTU limit) matching the CNS Oxygen Clock bar pattern. Each bar
shows 4 layers: background, total, cursor overlay, and prior segment."
```

---

### Task 3: Verify visual rendering and edge cases

**Files:**

- No new files

**Step 1: Run the app and navigate to a dive with O2 exposure data**

Run: `flutter run -d macos`
Navigate to a dive detail page with nitrox profile data (ppO2 > 0.5).

**Step 2: Verify daily bar rendering**

Expected:

- "Oxygen Tolerance Units" section header visible
- "Daily" label on left, "X / 300 OTU" on right (colored by threshold)
- Stacked bar: blueGrey prior segment + colored total bar + background remaining
- Footer: "Start: X OTU" on left, "+Y this dive" on right

**Step 3: Verify weekly bar rendering**

Expected:

- "Weekly" label on left, "X / 850 OTU" on right (colored by threshold)
- Stacked bar with prior segment = weekly total minus this dive
- Footer: "Prior: X OTU" on left, "+Y this dive" on right

**Step 4: Verify cursor interaction**

Scrub the dive profile chart cursor. Expected:

- Daily header changes to "cursor / total / 300 OTU" format
- Weekly header changes to "cursor / total / 850 OTU" format
- Primary-colored overlay appears on both bars showing OTU at cursor point

**Step 5: Verify edge case -- first dive of day (no prior)**

Navigate to a dive that is the first of its day. Expected:

- No blueGrey prior segment on daily bar
- Footer shows "Start: 0 OTU"

---

### Task 4: Run analysis and format check

**Files:**

- No new files

**Step 1: Run dart format**

Run: `dart format lib/ test/`
Expected: No formatting changes needed (already formatted in Task 2)

**Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No analysis issues

**Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass

---

## Summary of Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart` | Modify | Replace `_buildOtuBreakdown`+`_buildOtuMetric` with `_buildOtuProgress`+`_buildOtuBarSection`+`_buildStackedOtuBar` |
| `test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart` | Create | Widget tests for daily/weekly stacked bars, cursor, null weekly, no prior |
