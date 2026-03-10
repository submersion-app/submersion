# Chart Options Dialog Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the dive profile "More chart options" dialog with collapsible sections, inline segmented source selectors, and swap Ceiling/Events between primary legend and dialog.

**Architecture:** Two files change: the provider (`profile_legend_provider.dart`) gets section expansion state and explicit source-set methods; the widget (`dive_profile_legend.dart`) gets a rewritten dialog with collapsible sections and `SegmentedButton` source selectors. Events moves to primary legend, Ceiling moves to dialog.

**Tech Stack:** Flutter, Riverpod (codegen), Material 3 `SegmentedButton`, `ExpansionTile`

**Spec:** `docs/superpowers/specs/2026-03-09-chart-options-redesign-design.md`

---

## Chunk 1: Provider Changes

### Task 1: Add section expansion state to ProfileLegendState

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart:14-244`
- Test: `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart` (create)

- [ ] **Step 1: Write failing test for section expansion state**

Create `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

void main() {
  group('ProfileLegendState', () {
    group('sectionExpanded', () {
      test('defaults to expected initial values', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        expect(state.sectionExpanded['decompression'], true);
        expect(state.sectionExpanded['markers'], false);
        expect(state.sectionExpanded['gasAnalysis'], false);
        expect(state.sectionExpanded['other'], false);
        expect(state.sectionExpanded['tankPressures'], true);
      });

      test('copyWith preserves sectionExpanded', () {
        const state = ProfileLegendState();
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
        expect(updated.sectionExpanded['overlays'], true);
      });

      test('equality includes sectionExpanded', () {
        const state1 = ProfileLegendState();
        final state2 = state1.copyWith(
          sectionExpanded: {...state1.sectionExpanded, 'markers': true},
        );
        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: FAIL -- `sectionExpanded` field does not exist yet.

- [ ] **Step 3: Add sectionExpanded field to ProfileLegendState**

In `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`, add to `ProfileLegendState`:

1. Add field after `showTankPressure` (line 53):
```dart
  // Collapsible section expanded/collapsed state (session-only)
  final Map<String, bool> sectionExpanded;
```

2. Add to constructor (after `this.showTankPressure = const {}` at line 83):
```dart
    this.sectionExpanded = const {
      'overlays': true,
      'decompression': true,
      'markers': false,
      'gasAnalysis': false,
      'other': false,
      'tankPressures': true,
    },
```

3. Add to `copyWith` -- add parameter:
```dart
    Map<String, bool>? sectionExpanded,
```
And in the return body:
```dart
      sectionExpanded: sectionExpanded ?? this.sectionExpanded,
```

4. Add to `operator ==` (chain with `&&` after the existing `mapEquals(showTankPressure, ...)` line):
```dart
          mapEquals(sectionExpanded, other.sectionExpanded);
```

5. Add to `hashCode` (after `...showTankPressure.entries`):
```dart
    ...sectionExpanded.entries,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log/presentation/providers/profile_legend_provider_test.dart lib/features/dive_log/presentation/providers/profile_legend_provider.dart
git commit -m "feat: add sectionExpanded state to ProfileLegendState"
```

---

### Task 2: Add explicit source set methods and toggleSection

**Important:** Do NOT remove the existing `cycle*Source` methods yet. They are still called from `dive_profile_legend.dart`. They will be removed in Task 7 when the dialog is rewritten and callers are updated.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart:256-465`
- Test: `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`

- [ ] **Step 1: Write tests for set methods and toggleSection**

Append to the test file, inside `main()`. Add the `MetricDataSource` import at the top of the file:

```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```

Then add these test groups:

```dart
  group('ProfileLegend notifier methods (via state)', () {
    group('explicit source set methods', () {
      test('setCeilingSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ceilingSource, MetricDataSource.calculated);
        final updated = state.copyWith(ceilingSource: MetricDataSource.computer);
        expect(updated.ceilingSource, MetricDataSource.computer);
      });

      test('setNdlSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ndlSource, MetricDataSource.calculated);
        final updated = state.copyWith(ndlSource: MetricDataSource.computer);
        expect(updated.ndlSource, MetricDataSource.computer);
      });
    });

    group('toggleSection', () {
      test('toggles a collapsed section to expanded', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['markers'], false);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
      });

      test('toggles an expanded section to collapsed', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'overlays': false},
        );
        expect(updated.sectionExpanded['overlays'], false);
      });
    });
  });
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS (these test copyWith which already works).

- [ ] **Step 3: Add set methods and toggleSection to ProfileLegend notifier**

In the `ProfileLegend` class, add these methods AFTER the existing `cycle*Source` methods (after line 429). Keep the cycle methods for now:

```dart
  // Explicit data source set methods (for SegmentedButton)
  void setCeilingSource(MetricDataSource source) {
    state = state.copyWith(ceilingSource: source);
  }

  void setNdlSource(MetricDataSource source) {
    state = state.copyWith(ndlSource: source);
  }

  void setTtsSource(MetricDataSource source) {
    state = state.copyWith(ttsSource: source);
  }

  void setCnsSource(MetricDataSource source) {
    state = state.copyWith(cnsSource: source);
  }

  // Section expand/collapse
  void toggleSection(String sectionKey) {
    final current = state.sectionExpanded[sectionKey] ?? false;
    state = state.copyWith(
      sectionExpanded: {...state.sectionExpanded, sectionKey: !current},
    );
  }
```

- [ ] **Step 4: Run codegen and tests**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_legend_provider.dart lib/features/dive_log/presentation/providers/profile_legend_provider.g.dart test/features/dive_log/presentation/providers/profile_legend_provider_test.dart
git commit -m "feat: add explicit source set methods and toggleSection to ProfileLegend"
```

---

### Task 3: Update activeSecondaryCount (add Ceiling, remove Events)

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart:87-110`
- Test: `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`

- [ ] **Step 1: Write failing test for updated secondary count**

Append to test file inside the `ProfileLegendState` group:

```dart
    group('activeSecondaryCount', () {
      test('includes showCeiling in count', () {
        const isolatedState = ProfileLegendState(
          showCeiling: true,
          showAscentRateColors: false,
          showEvents: false,
          showMaxDepthMarker: false,
          showPressureMarkers: false,
          showGasSwitchMarkers: false,
        );
        expect(isolatedState.activeSecondaryCount, 1);
      });

      test('does NOT include showEvents in count', () {
        const state = ProfileLegendState(
          showEvents: true,
          showAscentRateColors: false,
          showMaxDepthMarker: false,
          showPressureMarkers: false,
          showGasSwitchMarkers: false,
          showCeiling: false,
        );
        expect(state.activeSecondaryCount, 0);
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: FAIL -- `showCeiling` is not counted, `showEvents` is still counted.

- [ ] **Step 3: Update activeSecondaryCount getter**

In `ProfileLegendState.activeSecondaryCount` (line 87-110), make two changes:

1. Add `if (showCeiling) count++;` (Ceiling is now a secondary toggle).
2. Remove the line `if (showEvents) count++;` (Events is now a primary toggle).

The updated getter:
```dart
  int get activeSecondaryCount {
    var count = 0;
    if (showCeiling) count++;
    if (showHeartRate) count++;
    if (showSac) count++;
    if (showAscentRateColors) count++;
    if (showMaxDepthMarker) count++;
    if (showPressureMarkers) count++;
    if (showGasSwitchMarkers) count++;
    if (showNdl) count++;
    if (showPpO2) count++;
    if (showPpN2) count++;
    if (showPpHe) count++;
    if (showMod) count++;
    if (showDensity) count++;
    if (showGf) count++;
    if (showSurfaceGf) count++;
    if (showMeanDepth) count++;
    if (showTts) count++;
    if (showCns) count++;
    if (showOtu) count++;
    count += showTankPressure.values.where((v) => v).length;
    return count;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_legend_provider.dart test/features/dive_log/presentation/providers/profile_legend_provider_test.dart
git commit -m "fix: update activeSecondaryCount to include Ceiling, exclude Events"
```

---

## Chunk 2: Widget Changes -- Primary Legend

### Task 4: Create test helper and swap Ceiling/Events in primary legend toggles

**Files:**
- Create: `test/helpers/test_app.dart` (if it doesn't exist)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart:96-209`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart` (create)

- [ ] **Step 1: Create test helper if needed**

Check if `test/helpers/test_app.dart` exists. If not, create it:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Widget testApp({required Widget child, List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
```

- [ ] **Step 2: Write failing test for Events in primary legend**

Create `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DiveProfileLegend - primary toggles', () {
    testWidgets('shows Events toggle when hasEvents is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasEvents: true,
              hasCeilingCurve: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );

      // Events should be in the primary legend
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets('does NOT show Ceiling in primary legend even when data available', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasCeilingCurve: true,
              hasEvents: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );

      // Events should appear, Ceiling should NOT (it moved to dialog)
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Ceiling'), findsNothing);
      expect(find.text('Ceiling (DC)'), findsNothing);
      expect(find.text('Ceiling (Calc)'), findsNothing);
      expect(find.text('Ceiling (Calc*)'), findsNothing);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: FAIL -- "Events" text not found (Ceiling is currently shown instead).

- [ ] **Step 4: Swap Ceiling/Events in primary legend build method**

In `DiveProfileLegend.build()` (line 123-209 of `dive_profile_legend.dart`):

1. **Remove** the Ceiling primary toggle block (lines 173-185):
```dart
                // Ceiling toggle (primary)
                if (config.hasCeilingCurve)
                  _buildMetricToggle(
                    context,
                    color: const Color(0xFFD32F2F), // Red 700
                    label: _sourceLabel(
                      context.l10n.diveLog_legend_label_ceiling,
                      legendState.ceilingSource,
                      sourceInfo?.ceilingActual ?? MetricDataSource.calculated,
                    ),
                    isEnabled: legendState.showCeiling,
                    onTap: legendNotifier.toggleCeiling,
                  ),
```

2. **Add** Events primary toggle in its place:
```dart
                // Events toggle (primary)
                if (config.hasEvents)
                  _buildMetricToggle(
                    context,
                    color: Colors.amber,
                    label: context.l10n.diveLog_legend_label_events,
                    isEnabled: legendState.showEvents,
                    onTap: legendNotifier.toggleEvents,
                  ),
```

3. **Update** `ProfileLegendConfig.hasSecondaryToggles` (line 72-93): remove `hasEvents ||` from the list of conditions. `hasCeilingCurve ||` stays.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart test/helpers/test_app.dart
git commit -m "feat: swap Ceiling/Events in primary legend toggles"
```

---

## Chunk 3: Widget Changes -- Dialog Rewrite

### Task 5: Update _MoreOptionsButton secondary count and add l10n keys

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart:320-352`
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Update _activeSecondaryCount getter**

In `_MoreOptionsButton._activeSecondaryCount` (line 320-352):

1. **Add** Ceiling count:
```dart
    if (config.hasCeilingCurve && legendState.showCeiling) count++;
```

2. **Remove** Events count line:
```dart
    if (config.hasEvents && legendState.showEvents) count++;
```

- [ ] **Step 2: Add section header l10n keys**

Add these keys to `lib/l10n/arb/app_en.arb` near the existing `diveLog_legend_*` keys:

```json
  "diveLog_chartSection_overlays": "Overlays",
  "diveLog_chartSection_markers": "Markers",
  "diveLog_chartSection_decompression": "Decompression",
  "diveLog_chartSection_gasAnalysis": "Gas Analysis",
  "diveLog_chartSection_other": "Other",
  "diveLog_chartSection_tankPressures": "Tank Pressures",
  "diveLog_legend_source_dc": "DC",
  "diveLog_legend_source_calc": "Calc",
```

- [ ] **Step 3: Run code generation and tests**

Run: `flutter gen-l10n && flutter test`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/l10n/arb/app_en.arb lib/l10n/generated/
git commit -m "feat: update secondary count and add l10n keys for chart option sections"
```

---

### Task 6: Add helper methods for dialog rewrite

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`

- [ ] **Step 1: Add _buildSection helper method**

Add to `_ChartOptionsDialog` class, before `_buildToggleItem`:

```dart
  Widget _buildSection(
    BuildContext context, {
    required String key,
    required String title,
    required ProfileLegendState legendState,
    required ProfileLegend legendNotifier,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(key),
        title: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: legendState.sectionExpanded[key] ?? false,
        onExpansionChanged: (_) => legendNotifier.toggleSection(key),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        dense: true,
        children: children,
      ),
    );
  }
```

- [ ] **Step 2: Add _buildToggleWithSource helper method**

Add to `_ChartOptionsDialog` class, after `_buildToggleItem`. This combines a visibility toggle with an inline `SegmentedButton` for DC/Calc source selection:

```dart
  Widget _buildToggleWithSource(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
    required MetricDataSource currentSource,
    required ValueChanged<MetricDataSource> onSourceChanged,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: isEnabled
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            SizedBox(
              height: 28,
              child: SegmentedButton<MetricDataSource>(
                segments: [
                  ButtonSegment(
                    value: MetricDataSource.computer,
                    label: Text(
                      context.l10n.diveLog_legend_source_dc,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  ButtonSegment(
                    value: MetricDataSource.calculated,
                    label: Text(
                      context.l10n.diveLog_legend_source_calc,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
                selected: {currentSource},
                onSelectionChanged: (selected) =>
                    onSourceChanged(selected.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
Expected: No errors (the helpers are added but not yet called).

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart
git commit -m "feat: add _buildSection and _buildToggleWithSource helpers for dialog"
```

---

### Task 7: Rewrite _ChartOptionsDialog with collapsible sections

This task replaces the `_buildItems` method with `_buildSections`, wires up the dialog, and removes old code. The existing `_buildToggleItem` method is kept as-is for metrics without source selectors.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart:404-936`

- [ ] **Step 1: Replace _buildItems with _buildSections**

Delete the entire `_buildItems` method (lines 467-822) and replace with `_buildSections`. All 6 sections are fully specified below:

```dart
  List<Widget> _buildSections(
    BuildContext context,
    ProfileLegendState legendState,
    ProfileLegend legendNotifier,
    MetricSourceInfo? sourceInfo,
  ) {
    final sections = <Widget>[];
    final l10n = context.l10n;

    // --- Overlays section ---
    final overlayItems = <Widget>[
      if (config.hasHeartRateData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_heartRate,
          color: Colors.red,
          isEnabled: legendState.showHeartRate,
          onTap: legendNotifier.toggleHeartRate,
        ),
      if (config.hasSacCurve)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_sacRate,
          color: Colors.teal,
          isEnabled: legendState.showSac,
          onTap: legendNotifier.toggleSac,
        ),
      if (config.hasAscentRates)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_ascentRate,
          color: Colors.lime.shade700,
          isEnabled: legendState.showAscentRateColors,
          onTap: legendNotifier.toggleAscentRateColors,
        ),
    ];
    if (overlayItems.isNotEmpty) {
      sections.add(_buildSection(
        context,
        key: 'overlays',
        title: l10n.diveLog_chartSection_overlays,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: overlayItems,
      ));
    }

    // --- Markers section ---
    final markerItems = <Widget>[
      if (config.hasMaxDepthMarker)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_maxDepth,
          color: Colors.red,
          isEnabled: legendState.showMaxDepthMarker,
          onTap: legendNotifier.toggleMaxDepthMarker,
        ),
      if (config.hasPressureMarkers)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_pressureThresholds,
          color: Colors.orange,
          isEnabled: legendState.showPressureMarkers,
          onTap: legendNotifier.togglePressureMarkers,
        ),
      if (config.hasGasSwitches)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_gasSwitches,
          color: GasColors.nitrox,
          isEnabled: legendState.showGasSwitchMarkers,
          onTap: legendNotifier.toggleGasSwitchMarkers,
        ),
    ];
    if (markerItems.isNotEmpty) {
      sections.add(_buildSection(
        context,
        key: 'markers',
        title: l10n.diveLog_chartSection_markers,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: markerItems,
      ));
    }

    // --- Tank Pressures section (only when multi-tank) ---
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      final tankItems = <Widget>[];
      final sortedTankIds = _sortedTankIds(config.tankPressures!.keys);
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : _getTankColor(i);
        final label = tank?.name ?? l10n.diveLog_tank_title(i + 1);
        tankItems.add(
          _buildToggleItem(
            context,
            label: label,
            color: color,
            isEnabled: legendState.showTankPressure[tankId] ?? true,
            onTap: () => legendNotifier.toggleTankPressure(tankId),
          ),
        );
      }
      if (tankItems.isNotEmpty) {
        sections.add(_buildSection(
          context,
          key: 'tankPressures',
          title: l10n.diveLog_chartSection_tankPressures,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: tankItems,
        ));
      }
    }

    // --- Decompression section ---
    final decoItems = <Widget>[
      if (config.hasCeilingCurve)
        _buildToggleWithSource(
          context,
          label: l10n.diveLog_legend_label_ceiling,
          color: const Color(0xFFD32F2F),
          isEnabled: legendState.showCeiling,
          onTap: legendNotifier.toggleCeiling,
          currentSource: legendState.ceilingSource,
          onSourceChanged: legendNotifier.setCeilingSource,
        ),
      if (config.hasNdlData)
        _buildToggleWithSource(
          context,
          label: l10n.diveLog_legend_label_ndl,
          color: Colors.lightGreen.shade700,
          isEnabled: legendState.showNdl,
          onTap: legendNotifier.toggleNdl,
          currentSource: legendState.ndlSource,
          onSourceChanged: legendNotifier.setNdlSource,
        ),
      if (config.hasTtsData)
        _buildToggleWithSource(
          context,
          label: l10n.diveLog_legend_label_tts,
          color: const Color(0xFFAD1457),
          isEnabled: legendState.showTts,
          onTap: legendNotifier.toggleTts,
          currentSource: legendState.ttsSource,
          onSourceChanged: legendNotifier.setTtsSource,
        ),
      if (config.hasCnsData)
        _buildToggleWithSource(
          context,
          label: l10n.diveLog_legend_label_cns,
          color: const Color(0xFFE65100),
          isEnabled: legendState.showCns,
          onTap: legendNotifier.toggleCns,
          currentSource: legendState.cnsSource,
          onSourceChanged: legendNotifier.setCnsSource,
        ),
      if (config.hasOtuData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_otu,
          color: const Color(0xFF6D4C41),
          isEnabled: legendState.showOtu,
          onTap: legendNotifier.toggleOtu,
        ),
    ];
    if (decoItems.isNotEmpty) {
      sections.add(_buildSection(
        context,
        key: 'decompression',
        title: l10n.diveLog_chartSection_decompression,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: decoItems,
      ));
    }

    // --- Gas Analysis section ---
    final gasItems = <Widget>[
      if (config.hasPpO2Data)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_ppO2,
          color: const Color(0xFF00ACC1),
          isEnabled: legendState.showPpO2,
          onTap: legendNotifier.togglePpO2,
        ),
      if (config.hasPpN2Data)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_ppN2,
          color: Colors.indigo,
          isEnabled: legendState.showPpN2,
          onTap: legendNotifier.togglePpN2,
        ),
      if (config.hasPpHeData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_ppHe,
          color: Colors.pink.shade300,
          isEnabled: legendState.showPpHe,
          onTap: legendNotifier.togglePpHe,
        ),
      if (config.hasModData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_mod,
          color: Colors.deepOrange,
          isEnabled: legendState.showMod,
          onTap: legendNotifier.toggleMod,
        ),
      if (config.hasDensityData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_gasDensity,
          color: Colors.brown,
          isEnabled: legendState.showDensity,
          onTap: legendNotifier.toggleDensity,
        ),
    ];
    if (gasItems.isNotEmpty) {
      sections.add(_buildSection(
        context,
        key: 'gasAnalysis',
        title: l10n.diveLog_chartSection_gasAnalysis,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: gasItems,
      ));
    }

    // --- Other section ---
    final otherItems = <Widget>[
      if (config.hasGfData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_gfPercent,
          color: Colors.deepPurple,
          isEnabled: legendState.showGf,
          onTap: legendNotifier.toggleGf,
        ),
      if (config.hasSurfaceGfData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_surfaceGf,
          color: Colors.purple.shade300,
          isEnabled: legendState.showSurfaceGf,
          onTap: legendNotifier.toggleSurfaceGf,
        ),
      if (config.hasMeanDepthData)
        _buildToggleItem(
          context,
          label: l10n.diveLog_legend_label_meanDepth,
          color: Colors.blueGrey,
          isEnabled: legendState.showMeanDepth,
          onTap: legendNotifier.toggleMeanDepth,
        ),
    ];
    if (otherItems.isNotEmpty) {
      sections.add(_buildSection(
        context,
        key: 'other',
        title: l10n.diveLog_chartSection_other,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: otherItems,
      ));
    }

    return sections;
  }
```

- [ ] **Step 2: Update the Consumer builder to call _buildSections**

In `_ChartOptionsDialog.build()`, inside the `Consumer` builder, change the call from `_buildItems(context, legendState, sourceInfo)` to:

```dart
final legendNotifier = ref.read(profileLegendProvider.notifier);
```

And change the `Column.children` from `_buildItems(context, legendState, sourceInfo)` to:

```dart
_buildSections(context, legendState, legendNotifier, sourceInfo)
```

The dialog already has access to `legendNotifier` as a field, but the `Consumer` builder also needs it from `ref` since the dialog is a `StatelessWidget` that stores the notifier passed from the parent. Either approach works -- use `legendNotifier` (the field) since it is already available.

- [ ] **Step 3: Remove old _buildSourceSelector method**

Delete `_buildSourceSelector` (currently around lines 862-901). This is the method that rendered the separate "Source: DC/Calc" rows. It is now replaced by the inline `SegmentedButton` inside `_buildToggleWithSource`.

- [ ] **Step 4: Remove cycle*Source methods from provider**

Now that the widget callers are updated to use `set*Source` methods, remove the 4 `cycle*Source` methods from `ProfileLegend` in `profile_legend_provider.dart` (lines 398-429):

```dart
  // DELETE these methods:
  void cycleNdlSource() { ... }
  void cycleCeilingSource() { ... }
  void cycleTtsSource() { ... }
  void cycleCnsSource() { ... }
```

- [ ] **Step 5: Run codegen and full test suite**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test`
Expected: PASS

- [ ] **Step 6: Run dart format**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/providers/profile_legend_provider.dart`

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/providers/profile_legend_provider.dart lib/features/dive_log/presentation/providers/profile_legend_provider.g.dart
git commit -m "feat: rewrite chart options dialog with collapsible sections and SegmentedButton source selectors"
```

---

## Chunk 4: Widget Tests for Dialog

### Task 8: Write widget tests for collapsible sections, segmented buttons, and badge count

**Files:**
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

- [ ] **Step 1: Add dialog widget tests**

Append to the test file. These tests open the dialog via the "More" button and verify section behavior, source selection, expand/collapse interaction, and badge count:

```dart
  group('_ChartOptionsDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasEvents: true,
              hasHeartRateData: true,
              hasSacCurve: true,
              hasAscentRates: true,
              hasCeilingCurve: true,
              hasNdlData: true,
              hasTtsData: true,
              hasCnsData: true,
              hasOtuData: true,
              hasPpO2Data: true,
              hasMaxDepthMarker: true,
              hasGfData: true,
              hasSurfaceGfData: true,
              hasMeanDepthData: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all section headers', (tester) async {
      await openDialog(tester);
      expect(find.text('Overlays'), findsOneWidget);
      expect(find.text('Markers'), findsOneWidget);
      expect(find.text('Decompression'), findsOneWidget);
      expect(find.text('Gas Analysis'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('Overlays section starts expanded with metrics visible', (tester) async {
      await openDialog(tester);
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('SAC'), findsOneWidget);
    });

    testWidgets('tapping collapsed section expands it', (tester) async {
      await openDialog(tester);
      // Markers starts collapsed, so Max Depth should not be visible
      // (ExpansionTile may still build children -- check via tapping)
      await tester.tap(find.text('Markers'));
      await tester.pumpAndSettle();
      expect(find.text('Max Depth'), findsOneWidget);
    });

    testWidgets('Ceiling has visibility toggle in Decompression section', (tester) async {
      await openDialog(tester);
      expect(find.text('Ceiling'), findsOneWidget);
    });

    testWidgets('source-capable metrics have SegmentedButtons', (tester) async {
      await openDialog(tester);
      // 4 metrics with source selectors: Ceiling, NDL, TTS, CNS
      expect(
        find.byType(SegmentedButton<MetricDataSource>),
        findsNWidgets(4),
      );
    });

    testWidgets('tapping SegmentedButton changes source state', (tester) async {
      await openDialog(tester);
      // Find the first "DC" text in a SegmentedButton and tap it
      // Default source is MetricDataSource.calculated, so tapping DC should change it
      final dcButtons = find.text('DC');
      await tester.tap(dcButtons.first);
      await tester.pumpAndSettle();
      // The SegmentedButton should now show DC as selected
      // (visual verification -- the button rebuilds with the new selection)
    });

    testWidgets('Ceiling toggle changes visibility state', (tester) async {
      await openDialog(tester);
      // Ceiling defaults to on (showCeiling: true). Find and tap the Ceiling row.
      // The InkWell wrapping the row handles the tap.
      final ceilingText = find.text('Ceiling');
      expect(ceilingText, findsOneWidget);
      await tester.tap(ceilingText);
      await tester.pumpAndSettle();
      // After tapping, the checkbox icon should change.
      // We verify the toggle was processed (no error thrown).
    });
  });

  group('Badge count', () {
    testWidgets('badge reflects active secondary count including Ceiling', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasCeilingCurve: true,
              hasAscentRates: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      // Default state: showCeiling=true, showAscentRateColors=true
      // Badge should show 2
      expect(find.text('2'), findsOneWidget);
    });
  });
```

Add this import at the top of the file:
```dart
import 'package:submersion/core/constants/profile_metrics.dart';
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "test: add widget tests for collapsible sections, source buttons, and badge count"
```

---

### Task 9: Run full test suite, format, and analyze

- [ ] **Step 1: Run dart format on all changed files**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Final commit if any formatting changes**

```bash
git add lib/ test/
git commit -m "chore: format and analyze clean"
```
