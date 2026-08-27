# Adaptive Profile Legend Row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the dive profile legend row with as many toggles as fit the available width, on exactly one line, never wrapping; overflow stays reachable in the existing options popover.

**Architecture:** A pure selection function admits toggle candidates (active first, canonical display order) against a width budget computed from `TextPainter` label measurement inside a `LayoutBuilder`. The options dialog becomes the complete catalog (gains Temperature/Pressure/Events), and the More-button badge counts active-but-hidden toggles. The oversized legend file is split first.

**Tech Stack:** Flutter 3.x, Riverpod (`profileLegendProvider`), flutter_test. No database, no l10n, no provider changes.

**Spec:** `docs/superpowers/specs/2026-08-05-adaptive-profile-legend-design.md`

## Global Constraints

- The legend row must render exactly one line at every width and text scale.
- No new l10n strings; reuse existing `diveLog_legend_label_*` keys. English values used in tests: `Depth`, `Temp`, `Pressure`, `Events`, `Ceiling`, `NDL`, `Heart Rate`, `SAC Rate`, `OTU`, `Gases`, `Max Depth`, `Deco stops`, `Photos`.
- No new persisted state; inline selection is derived per build.
- Max 800 lines per file; no emojis anywhere.
- After each task: `dart format .` must produce no changes; `flutter analyze` must report zero issues (CI treats infos as fatal — never pipe analyze output through `tail`/`grep`).
- Commit messages: plain summary line, no attribution lines, no session URLs.
- Widget tests render with the Ahem font: every glyph is exactly `fontSize` wide (labelSmall = 11px, so `Temp` measures 44px). `TextPainter` in the widget uses the same font, so measurement and rendering always agree. The pixel arithmetic in test comments uses this.
- Width calibration provision: the SizedBox widths in new tests are chosen from the arithmetic in each test's comment. The semantic assertion (which labels appear/disappear) is the contract; if a boundary assertion fails because a fixed chrome width differs by a few pixels, adjust the SizedBox width in steps of 25px until the semantic condition holds, and update the comment's arithmetic to match reality.

---

### Task 1: Extract the options dialog into its own file

The legend file is 1,167 lines (cap is 800) and the next tasks add code to both halves. Pure move-and-rename refactor; behavior identical; existing tests must pass unchanged.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart` (no edits; must stay green)

**Interfaces:**
- Consumes: `ProfileLegendConfig` (stays in `dive_profile_legend.dart`), `profileLegendProvider`.
- Produces: public `class ChartOptionsDialog extends StatelessWidget` with constructor `ChartOptionsDialog({super.key, required ProfileLegendConfig config, required Offset anchorOffset, required Size anchorSize})` — Task 2 modifies this class; the legend's `_MoreOptionsButton` constructs it.

- [ ] **Step 1: Move the dialog**

Cut everything from the `_ChartOptionsDialog` class declaration (line ~384, including its doc comment) through the end of the `_getTankColor` method (the end of that class, line ~1095) out of `dive_profile_legend.dart` and paste it into new file `chart_options_dialog.dart`. Rename `_ChartOptionsDialog` to `ChartOptionsDialog` (class name, constructor, and doc comment). Add file header imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
```

(The import of `dive_profile_legend.dart` supplies `ProfileLegendConfig`.)

- [ ] **Step 2: Update the legend file**

In `dive_profile_legend.dart`, add `import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';` and change `_MoreOptionsButton._showMoreOptions` to build `ChartOptionsDialog(...)` instead of `_ChartOptionsDialog(...)`. Remove imports the legend no longer needs (`deco_stop_band.dart` and `profile_metrics.dart` if now unused — check with analyze).

- [ ] **Step 3: Verify tests pass unchanged**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: all PASS (the test file references the dialog only through the legend, so no test edits).

- [ ] **Step 4: Format, analyze, check line counts**

Run: `dart format . && flutter analyze`
Expected: no formatting changes to other files, zero analyze issues.
Run: `wc -l lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/chart_options_dialog.dart`
Expected: both under 800.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/chart_options_dialog.dart
git commit -m "Extract chart options dialog into its own file"
```

---

### Task 2: Options dialog becomes the complete catalog

Add Temperature, Pressure, and Events toggles to the dialog's Overlays section so every toggle stays reachable when the inline row is too narrow to show them (spec: "popover becomes the complete catalog").

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

**Interfaces:**
- Consumes: `ChartOptionsDialog._buildSections` (Task 1), `legendNotifier.toggleTemperature/togglePressure/toggleEvents`, `legendState.showTemperature/showPressure/showEvents`.
- Produces: dialog Overlays section listing Temp/Pressure/Events; test helper `_inDialog` used by later tasks.

- [ ] **Step 1: Add the `_inDialog` scoping helper and the failing test**

In `dive_profile_legend_test.dart`, add below the `_testTanks` declaration:

```dart
/// Scopes a finder to the chart options dialog. Every dialog row lives inside
/// an ExpansionTile section; inline legend toggles never do. This keeps
/// assertions unambiguous once toggles can appear both inline and in the
/// dialog (adaptive legend row).
Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(ExpansionTile), matching: matching);
```

Add a new group at the end of `main()`:

```dart
group('dialog catalog completeness', () {
  testWidgets('Overlays section lists Temperature, Pressure, and Events', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: DiveProfileLegend(
          config: const ProfileLegendConfig(
            hasTemperatureData: true,
            hasPressureData: true,
            hasEvents: true,
            hasHeartRateData: true,
          ),
          zoomLevel: 1.0,
          onZoomIn: () {},
          onZoomOut: () {},
          onResetZoom: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(_inDialog(find.text('Temp')), findsOneWidget);
    expect(_inDialog(find.text('Pressure')), findsOneWidget);
    expect(_inDialog(find.text('Events')), findsOneWidget);
  });

  testWidgets('single-tank Pressure entry is absent for multi-tank dives', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: DiveProfileLegend(
          config: const ProfileLegendConfig(
            hasPressureData: true,
            hasMultiTankPressure: true,
            tanks: _testTanks,
            tankPressures: {
              'tank-1': [
                TankPressurePoint(
                  id: 'tp-1',
                  tankId: 'tank-1',
                  timestamp: 0,
                  pressure: 200,
                ),
              ],
            },
          ),
          zoomLevel: 1.0,
          onZoomIn: () {},
          onZoomOut: () {},
          onResetZoom: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Multi-tank dives use per-tank rows in Tank Pressures instead of the
    // single "Pressure" toggle.
    expect(_inDialog(find.text('Pressure')), findsNothing);
  });
});
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart --plain-name 'dialog catalog completeness'`
Expected: FAIL — `Temp`/`Pressure` not found in dialog.

- [ ] **Step 3: Add the three entries to the Overlays section**

In `chart_options_dialog.dart`, `_buildSections`, prepend to the `overlayItems` list literal (before the `if (config.hasHeartRateData)` entry):

```dart
      if (config.hasTemperatureData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_temp,
          color: Theme.of(context).colorScheme.tertiary,
          isEnabled: legendState.showTemperature,
          onTap: legendNotifier.toggleTemperature,
        ),
      if (config.hasPressureData && !config.hasMultiTankPressure)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_pressure,
          color: Colors.orange,
          isEnabled: legendState.showPressure,
          onTap: legendNotifier.togglePressure,
        ),
      if (config.hasEvents)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_events,
          color: Colors.amber,
          isEnabled: legendState.showEvents,
          onTap: legendNotifier.toggleEvents,
        ),
```

- [ ] **Step 4: Run the full legend test file**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: all PASS. (The pre-existing dialog tests assert labels like `Heart Rate` unscoped — they still pass because those labels appear only once until Task 4 promotes toggles inline.)

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format . && flutter analyze`

```bash
git add lib/features/dive_log/presentation/widgets/chart_options_dialog.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "List primary toggles in the chart options dialog"
```

---

### Task 3: Candidate model and pure selection logic

A new small file holds the candidate value type, the width-budget selection function, and tank helpers shared between the legend row and the dialog. Selection is pure Dart — unit-testable without widgets.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/legend_candidates.dart`
- Create: `test/features/dive_log/presentation/widgets/legend_candidates_test.dart`
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart` (adopt shared tank helpers)

**Interfaces:**
- Consumes: `DiveTank`, `GasMix` from `domain/entities/dive.dart`; `context.l10n`.
- Produces (used by Task 4 and the dialog):
  - `class LegendCandidate { final String id; final String label; final Color color; final bool isActive; final int priority; final VoidCallback onTap; }` (const constructor, all named required)
  - `List<LegendCandidate> selectInlineCandidates({required List<LegendCandidate> candidates, required double availableWidth, required double Function(LegendCandidate candidate) itemWidth})`
  - `List<String> sortTankIdsByOrder(Iterable<String> tankIds, List<DiveTank>? tanks)`
  - `Color tankFallbackColor(int index)`
  - `String tankLegendLabel(BuildContext context, DiveTank tank, {required int fallbackIndex})`

- [ ] **Step 1: Write the failing unit tests**

Create `test/features/dive_log/presentation/widgets/legend_candidates_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';

LegendCandidate _candidate(String id, int priority, {bool isActive = false}) {
  return LegendCandidate(
    id: id,
    label: id,
    color: Colors.blue,
    isActive: isActive,
    priority: priority,
    onTap: () {},
  );
}

void main() {
  group('selectInlineCandidates', () {
    test('returns all candidates in priority order when everything fits', () {
      final candidates = [
        _candidate('b', 1),
        _candidate('a', 0, isActive: true),
        _candidate('c', 2),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 1000,
        itemWidth: (c) => 50,
      );
      expect(admitted.map((c) => c.id).toList(), ['a', 'b', 'c']);
    });

    test('active candidates win space over higher-priority inactive ones', () {
      final candidates = [
        _candidate('inactiveHigh', 0),
        _candidate('activeLow', 1, isActive: true),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 60,
        itemWidth: (c) => 50,
      );
      expect(admitted.map((c) => c.id).toList(), ['activeLow']);
    });

    test('stops at the first candidate that does not fit', () {
      // Admission order: a (40), b (100, does not fit) -> stop; c is never
      // admitted even though its 40px would fit the remaining budget. This
      // keeps the row prefix-stable instead of skipping around.
      final candidates = [
        _candidate('a', 0, isActive: true),
        _candidate('b', 1, isActive: true),
        _candidate('c', 2, isActive: true),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 90,
        itemWidth: (c) => c.id == 'b' ? 100 : 40,
      );
      expect(admitted.map((c) => c.id).toList(), ['a']);
    });

    test('admitted set renders in priority order even when active order differs', () {
      final candidates = [
        _candidate('first', 0),
        _candidate('last', 3, isActive: true),
        _candidate('middle', 1, isActive: true),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 150,
        itemWidth: (c) => 50,
      );
      // All fit; display order is canonical priority order.
      expect(admitted.map((c) => c.id).toList(), ['first', 'middle', 'last']);
    });

    test('returns empty for zero or negative width', () {
      final candidates = [_candidate('a', 0, isActive: true)];
      expect(
        selectInlineCandidates(
          candidates: candidates,
          availableWidth: 0,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
      expect(
        selectInlineCandidates(
          candidates: candidates,
          availableWidth: -10,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
    });

    test('returns empty for empty input', () {
      expect(
        selectInlineCandidates(
          candidates: const [],
          availableWidth: 100,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
    });
  });

  group('sortTankIdsByOrder', () {
    test('sorts ids by tank order with unknown ids last', () {
      const tanks = [
        DiveTank(id: 't2', gasMix: GasMix(o2: 21), order: 1),
        DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0),
      ];
      expect(
        sortTankIdsByOrder(['unknown', 't2', 't1'], tanks),
        ['t1', 't2', 'unknown'],
      );
    });
  });

  group('tankFallbackColor', () {
    test('cycles through the palette', () {
      expect(tankFallbackColor(0), tankFallbackColor(6));
      expect(tankFallbackColor(1), isNot(tankFallbackColor(2)));
    });
  });
}
```

Add `import 'package:submersion/features/dive_log/domain/entities/dive.dart';` to the test imports (for `DiveTank`/`GasMix`).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/legend_candidates_test.dart`
Expected: FAIL — `legend_candidates.dart` does not exist.

- [ ] **Step 3: Implement `legend_candidates.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One toggle that competes for space in the inline legend row.
///
/// [priority] is the canonical display position (lower renders further left).
/// Active candidates are admitted before inactive ones regardless of
/// priority, but the admitted set always renders in priority order so a
/// toggle never changes position when clicked.
@immutable
class LegendCandidate {
  final String id;
  final String label;
  final Color color;
  final bool isActive;
  final int priority;
  final VoidCallback onTap;

  const LegendCandidate({
    required this.id,
    required this.label,
    required this.color,
    required this.isActive,
    required this.priority,
    required this.onTap,
  });
}

/// Selects which candidates fit the inline legend row.
///
/// Admission order is active-first (each group in priority order); admission
/// stops at the first candidate that does not fit, keeping the visible set a
/// stable prefix rather than a width-dependent patchwork. The returned list
/// is sorted back into priority order for display.
List<LegendCandidate> selectInlineCandidates({
  required List<LegendCandidate> candidates,
  required double availableWidth,
  required double Function(LegendCandidate candidate) itemWidth,
}) {
  final byPriority = [...candidates]
    ..sort((a, b) => a.priority.compareTo(b.priority));
  final admissionOrder = [
    ...byPriority.where((c) => c.isActive),
    ...byPriority.where((c) => !c.isActive),
  ];

  final admitted = <LegendCandidate>[];
  var used = 0.0;
  for (final candidate in admissionOrder) {
    final width = itemWidth(candidate);
    if (used + width > availableWidth) break;
    used += width;
    admitted.add(candidate);
  }
  admitted.sort((a, b) => a.priority.compareTo(b.priority));
  return admitted;
}

/// Sorts tank IDs by their tank's order; IDs without a matching tank go last.
List<String> sortTankIdsByOrder(
  Iterable<String> tankIds,
  List<DiveTank>? tanks,
) {
  int orderOf(String id) {
    if (tanks == null) return 999;
    for (final tank in tanks) {
      if (tank.id == id) return tank.order;
    }
    return 999;
  }

  final ids = tankIds.toList();
  ids.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
  return ids;
}

const _tankFallbackColors = [
  Colors.orange,
  Colors.amber,
  Colors.green,
  Colors.cyan,
  Colors.purple,
  Colors.pink,
];

/// Color for a tank without gas mix info, cycling a fixed palette by index.
Color tankFallbackColor(int index) {
  return _tankFallbackColors[index % _tankFallbackColors.length];
}

/// Display label for a tank: its name (or "Tank N") plus the gas mix name.
String tankLegendLabel(
  BuildContext context,
  DiveTank tank, {
  required int fallbackIndex,
}) {
  final tankTitle = tank.name?.trim().isNotEmpty == true
      ? tank.name!.trim()
      : context.l10n.diveLog_tank_title(fallbackIndex);
  return '$tankTitle (${tank.gasMix.name})';
}
```

- [ ] **Step 4: Run unit tests**

Run: `flutter test test/features/dive_log/presentation/widgets/legend_candidates_test.dart`
Expected: PASS.

- [ ] **Step 5: Adopt the shared helpers in the dialog**

In `chart_options_dialog.dart`: add `import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';`, delete the private `_sortedTankIds`, `_getTankColor`, and `_buildTankLabel` members, and replace their call sites:
- `_sortedTankIds(config.tankPressures!.keys)` becomes `sortTankIdsByOrder(config.tankPressures!.keys, config.tanks)`
- `_getTankColor(i)` becomes `tankFallbackColor(i)`
- `_buildTankLabel(context, tank, fallbackIndex: i + 1)` becomes `tankLegendLabel(context, tank, fallbackIndex: i + 1)`

(`_getTankById` stays — it is still used for color lookup.)

- [ ] **Step 6: Run the legend test file, format, analyze**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart && dart format . && flutter analyze`
Expected: PASS, no format changes, zero issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/legend_candidates.dart lib/features/dive_log/presentation/widgets/chart_options_dialog.dart test/features/dive_log/presentation/widgets/legend_candidates_test.dart
git commit -m "Add legend candidate model and width-budget selection"
```

---

### Task 4: Adaptive inline row in DiveProfileLegend

Replace the fixed primary-toggle `Wrap` with a measured single-line `Row` that renders the admitted candidates. This task also updates the pre-existing tests whose assumptions change (labels now appear inline as well as in the dialog).

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

**Interfaces:**
- Consumes: `LegendCandidate`, `selectInlineCandidates`, `sortTankIdsByOrder`, `tankFallbackColor`, `tankLegendLabel` (Task 3); `GasColors`, `decoStopBandColor`, `AppColors.chartDepth`.
- Produces: `_MoreOptionsButton` temporarily keeps its current signature (`config` + `legendState`); Task 5 changes it. The build method computes `admitted` and `candidates`; Task 5 reuses both for the badge.

- [ ] **Step 1: Write the failing widget tests**

Add to `dive_profile_legend_test.dart` a helper and a new group. The pixel arithmetic in comments assumes: zoom controls 128px, depth item 72px (13 chrome + 55 label + 4 spacing), More button 32px, safety margin 8px, toggle chrome 33px + 11px per label character + 4px spacing.

```dart
Future<void> _pumpLegendAt(
  WidgetTester tester, {
  required double width,
  required ProfileLegendConfig config,
}) async {
  await tester.pumpWidget(
    testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DiveProfileLegend(
            config: config,
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ... inside main():

group('adaptive inline row', () {
  testWidgets('narrow width keeps one line and drops low-priority toggles', (
    tester,
  ) async {
    // Available toggle budget at 400px is roughly
    // 400 - 128 (zoom) - 4 - 72 (depth) - 32 (more) - 8 (margin) = 156.
    // Actives admit first: Temp (81) fits, Events (103) does not -> stop.
    await _pumpLegendAt(
      tester,
      width: 400,
      config: const ProfileLegendConfig(
        hasTemperatureData: true,
        hasEvents: true,
        hasHeartRateData: true,
        hasSacCurve: true,
      ),
    );

    expect(find.text('Temp'), findsOneWidget);
    expect(find.text('Heart Rate'), findsNothing);
    expect(find.text('SAC Rate'), findsNothing);
    expect(
      tester.getSize(find.byType(DiveProfileLegend)).height,
      lessThan(56),
      reason: 'legend must stay a single line',
    );
  });

  testWidgets('wide width fills remaining space with inactive toggles', (
    tester,
  ) async {
    // Heart Rate and SAC Rate default OFF; at 1200px they are admitted as
    // inactive fillers after the active toggles.
    await _pumpLegendAt(
      tester,
      width: 1200,
      config: const ProfileLegendConfig(
        hasTemperatureData: true,
        hasEvents: true,
        hasHeartRateData: true,
        hasSacCurve: true,
      ),
    );

    expect(find.text('Heart Rate'), findsOneWidget);
    expect(find.text('SAC Rate'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DiveProfileLegend)).height,
      lessThan(56),
    );
  });

  testWidgets('an active low-priority toggle evicts inactive higher ones', (
    tester,
  ) async {
    // OTU (priority last) is toggled ON; Heart Rate (priority higher) is OFF.
    // Budget at 400px is ~156: OTU item is 33 + 33 + 4 = 70 and admits first
    // as the only active candidate; Heart Rate (147) no longer fits even
    // though it would fit alone (147 < 156).
    await _pumpLegendAt(
      tester,
      width: 400,
      config: const ProfileLegendConfig(
        hasHeartRateData: true,
        hasOtuData: true,
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileLegend)),
    );
    container.read(profileLegendProvider.notifier).toggleOtu();
    await tester.pumpAndSettle();

    expect(find.text('OTU'), findsOneWidget);
    expect(find.text('Heart Rate'), findsNothing);
  });

  testWidgets('visible toggles render in canonical order, not active order', (
    tester,
  ) async {
    await _pumpLegendAt(
      tester,
      width: 1200,
      config: const ProfileLegendConfig(
        hasTemperatureData: true,
        hasOtuData: true,
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileLegend)),
    );
    container.read(profileLegendProvider.notifier).toggleOtu();
    await tester.pumpAndSettle();

    // OTU was activated after Temp, but Temp (priority 0) stays left of OTU.
    expect(
      tester.getTopLeft(find.text('Temp')).dx,
      lessThan(tester.getTopLeft(find.text('OTU')).dx),
    );
  });

  testWidgets('large text scale admits fewer toggles but keeps one line', (
    tester,
  ) async {
    // At 1x a 500px legend admits Temp and Events; at 2x every label doubles
    // so only Temp fits.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpLegendAt(
      tester,
      width: 500,
      config: const ProfileLegendConfig(
        hasTemperatureData: true,
        hasEvents: true,
      ),
    );

    expect(find.text('Temp'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
    expect(
      tester.getSize(find.byType(DiveProfileLegend)).height,
      lessThan(56),
    );
  });

  testWidgets('multi-tank dives promote per-tank pressure toggles', (
    tester,
  ) async {
    await _pumpLegendAt(
      tester,
      width: 1200,
      config: const ProfileLegendConfig(
        hasMultiTankPressure: true,
        tanks: _testTanks,
        tankPressures: {
          'tank-1': [
            TankPressurePoint(
              id: 'tp-1',
              tankId: 'tank-1',
              timestamp: 0,
              pressure: 200,
            ),
          ],
          'tank-2': [
            TankPressurePoint(
              id: 'tp-2',
              tankId: 'tank-2',
              timestamp: 0,
              pressure: 200,
            ),
          ],
        },
      ),
    );

    // Inline row (dialog not open) shows one toggle per tank.
    expect(find.text('D80 (Air)'), findsOneWidget);
    expect(find.text('AL80 (EAN50)'), findsOneWidget);
  });
});
```

Add `import 'package:flutter_riverpod/flutter_riverpod.dart';` and `import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';` to the test file imports.

- [ ] **Step 2: Run new tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart --plain-name 'adaptive inline row'`
Expected: FAIL — `Heart Rate`/`SAC Rate`/`OTU` never render inline today; per-tank toggles are dialog-only.

- [ ] **Step 3: Implement the adaptive row**

In `dive_profile_legend.dart`:

3a. Add imports:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';
```

3b. Add layout constants to `DiveProfileLegend` (directly above `_buildMetricToggle` so the geometry comment sits next to the widget it mirrors):

```dart
  // Geometry of one inline toggle as built by _buildMetricToggle below:
  // horizontal padding 2+2, checkbox icon 14, gap 2, swatch 10, gap 3,
  // then the label text. _toggleChromeWidth MUST change in lockstep with
  // any visual edit to _buildMetricToggle.
  static const double _toggleChromeWidth = 2 + 2 + 14 + 2 + 10 + 3;

  // Geometry of the always-shown depth legend item (_buildLegendItem):
  // swatch 10, gap 3, label text.
  static const double _depthChromeWidth = 10 + 3;

  static const double _itemSpacing = 4;
  static const double _moreButtonWidth = 32;
  static const double _safetyMargin = 8;

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
```

3c. Add the candidate builder as a method of `DiveProfileLegend` (canonical priority = insertion order; the spec's ranked list):

```dart
  List<LegendCandidate> _buildCandidates(
    BuildContext context,
    ProfileLegendState state,
    ProfileLegend notifier,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final candidates = <LegendCandidate>[];

    void add({
      required bool present,
      required String id,
      required String label,
      required Color color,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      if (!present) return;
      candidates.add(
        LegendCandidate(
          id: id,
          label: label,
          color: color,
          isActive: isActive,
          priority: candidates.length,
          onTap: onTap,
        ),
      );
    }

    add(
      present: config.hasTemperatureData,
      id: 'temperature',
      label: l10n.diveLog_legend_label_temp,
      color: colorScheme.tertiary,
      isActive: state.showTemperature,
      onTap: notifier.toggleTemperature,
    );
    add(
      present: config.hasPressureData && !config.hasMultiTankPressure,
      id: 'pressure',
      label: l10n.diveLog_legend_label_pressure,
      color: Colors.orange,
      isActive: state.showPressure,
      onTap: notifier.togglePressure,
    );
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      final sortedIds = sortTankIdsByOrder(
        config.tankPressures!.keys,
        config.tanks,
      );
      for (var i = 0; i < sortedIds.length; i++) {
        final tankId = sortedIds[i];
        DiveTank? tank;
        for (final t in config.tanks ?? const <DiveTank>[]) {
          if (t.id == tankId) tank = t;
        }
        final baseLabel = tank != null
            ? tankLegendLabel(context, tank, fallbackIndex: i + 1)
            : l10n.diveLog_tank_title(i + 1);
        add(
          present: true,
          id: 'tank:$tankId',
          label: config.estimatedTankIds.contains(tankId)
              ? '$baseLabel ${l10n.diveLog_pressure_estimatedSuffix}'
              : baseLabel,
          color: tank != null
              ? GasColors.forGasMix(tank.gasMix)
              : tankFallbackColor(i),
          isActive: state.showTankPressure[tankId] ?? true,
          onTap: () => notifier.toggleTankPressure(tankId),
        );
      }
    }
    add(
      present: config.hasEvents,
      id: 'events',
      label: l10n.diveLog_legend_label_events,
      color: Colors.amber,
      isActive: state.showEvents,
      onTap: notifier.toggleEvents,
    );
    add(
      present: config.hasCeilingCurve,
      id: 'ceiling',
      label: l10n.diveLog_legend_label_ceiling,
      color: const Color(0xFFD32F2F),
      isActive: state.showCeiling,
      onTap: notifier.toggleCeiling,
    );
    add(
      present: config.hasDecoStopCurve,
      id: 'decoStops',
      label: l10n.diveLog_legend_label_decoStops,
      color: decoStopBandColor,
      isActive: state.showDecoStops,
      onTap: notifier.toggleDecoStops,
    );
    add(
      present: config.hasNdlData,
      id: 'ndl',
      label: l10n.diveLog_legend_label_ndl,
      color: Colors.yellow.shade700,
      isActive: state.showNdl,
      onTap: notifier.toggleNdl,
    );
    add(
      present: config.hasGasSwitches,
      id: 'gasSwitches',
      label: l10n.diveLog_legend_label_gasSwitches,
      color: GasColors.nitrox,
      isActive: state.showGasSwitchMarkers,
      onTap: notifier.toggleGasSwitchMarkers,
    );
    add(
      present: config.hasSacCurve,
      id: 'sac',
      label: l10n.diveLog_legend_label_sacRate,
      color: Colors.teal,
      isActive: state.showSac,
      onTap: notifier.toggleSac,
    );
    add(
      present: config.hasHeartRateData,
      id: 'heartRate',
      label: l10n.diveLog_legend_label_heartRate,
      color: Colors.red,
      isActive: state.showHeartRate,
      onTap: notifier.toggleHeartRate,
    );
    add(
      present: config.hasAscentRates,
      id: 'ascentRateColors',
      label: l10n.diveLog_legend_label_ascentRate,
      color: Colors.lime.shade700,
      isActive: state.showAscentRateColors,
      onTap: notifier.toggleAscentRateColors,
    );
    add(
      present: config.hasAscentRates,
      id: 'ascentRateLine',
      label: l10n.diveLog_legend_label_ascentRateLine,
      color: Colors.lime,
      isActive: state.showAscentRateLine,
      onTap: notifier.toggleAscentRateLine,
    );
    add(
      present: config.hasMaxDepthMarker,
      id: 'maxDepth',
      label: l10n.diveLog_legend_label_maxDepth,
      color: Colors.red,
      isActive: state.showMaxDepthMarker,
      onTap: notifier.toggleMaxDepthMarker,
    );
    add(
      present: config.hasTtsData,
      id: 'tts',
      label: l10n.diveLog_legend_label_tts,
      color: const Color(0xFFAD1457),
      isActive: state.showTts,
      onTap: notifier.toggleTts,
    );
    add(
      present: config.hasCnsData,
      id: 'cns',
      label: l10n.diveLog_legend_label_cns,
      color: const Color(0xFFE65100),
      isActive: state.showCns,
      onTap: notifier.toggleCns,
    );
    add(
      present: config.hasMeanDepthData,
      id: 'meanDepth',
      label: l10n.diveLog_legend_label_meanDepth,
      color: Colors.blueGrey,
      isActive: state.showMeanDepth,
      onTap: notifier.toggleMeanDepth,
    );
    add(
      present: config.hasGfData,
      id: 'gf',
      label: l10n.diveLog_legend_label_gfPercent,
      color: Colors.deepPurple,
      isActive: state.showGf,
      onTap: notifier.toggleGf,
    );
    add(
      present: config.hasSurfaceGfData,
      id: 'surfaceGf',
      label: l10n.diveLog_legend_label_surfaceGf,
      color: Colors.purple.shade300,
      isActive: state.showSurfaceGf,
      onTap: notifier.toggleSurfaceGf,
    );
    add(
      present: config.hasPpO2Data,
      id: 'ppO2',
      label: l10n.diveLog_legend_label_ppO2,
      color: const Color(0xFF00ACC1),
      isActive: state.showPpO2,
      onTap: notifier.togglePpO2,
    );
    add(
      present: config.hasPpN2Data,
      id: 'ppN2',
      label: l10n.diveLog_legend_label_ppN2,
      color: Colors.indigo,
      isActive: state.showPpN2,
      onTap: notifier.togglePpN2,
    );
    add(
      present: config.hasPpHeData,
      id: 'ppHe',
      label: l10n.diveLog_legend_label_ppHe,
      color: Colors.pink.shade300,
      isActive: state.showPpHe,
      onTap: notifier.togglePpHe,
    );
    add(
      present: config.hasModData,
      id: 'mod',
      label: l10n.diveLog_legend_label_mod,
      color: Colors.deepOrange,
      isActive: state.showMod,
      onTap: notifier.toggleMod,
    );
    add(
      present: config.hasDensityData,
      id: 'density',
      label: l10n.diveLog_legend_label_gasDensity,
      color: Colors.brown,
      isActive: state.showDensity,
      onTap: notifier.toggleDensity,
    );
    add(
      present: config.hasOtuData,
      id: 'otu',
      label: l10n.diveLog_legend_label_otu,
      color: const Color(0xFF6D4C41),
      isActive: state.showOtu,
      onTap: notifier.toggleOtu,
    );
    add(
      present: config.hasPressureMarkers,
      id: 'pressureMarkers',
      label: l10n.diveLog_legend_label_pressureThresholds,
      color: Colors.orange,
      isActive: state.showPressureMarkers,
      onTap: notifier.togglePressureMarkers,
    );
    add(
      present: config.hasPhotoMarkers,
      id: 'photoMarkers',
      label: l10n.diveLog_legend_label_photoMarkers,
      color: Colors.cyan,
      isActive: state.showPhotoMarkers,
      onTap: notifier.togglePhotoMarkers,
    );
    add(
      present: config.hasGasData,
      id: 'gasTimeline',
      label: l10n.diveLog_legend_label_showGas,
      color: GasColors.nitrox,
      isActive: state.showGas,
      onTap: notifier.toggleGas,
    );
    return candidates;
  }
```

3d. Replace the body of `build` from the `return Padding(` down to the end of the zoom-controls `Row` with:

```dart
    final candidates = _buildCandidates(context, legendState, legendNotifier);
    final showMoreButton = candidates.isNotEmpty || config.hasTankListSection;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final depthLabel = context.l10n.diveLog_legend_label_depth;
                final reserved =
                    _depthChromeWidth +
                    _labelWidth(context, depthLabel) +
                    _itemSpacing +
                    (showMoreButton ? _moreButtonWidth : 0) +
                    _safetyMargin;
                final admitted = selectInlineCandidates(
                  candidates: candidates,
                  availableWidth: constraints.maxWidth - reserved,
                  itemWidth: (c) =>
                      _toggleChromeWidth +
                      _labelWidth(context, c.label) +
                      _itemSpacing,
                );
                // The admitted set is measured to fit, so this scroll view
                // never actually scrolls; it exists to clip gracefully in
                // degenerate over-constrained layouts instead of throwing
                // RenderFlex overflow errors.
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      _buildLegendItem(
                        context,
                        color: AppColors.chartDepth,
                        label: depthLabel,
                      ),
                      for (final candidate in admitted) ...[
                        const SizedBox(width: _itemSpacing),
                        _buildMetricToggle(
                          context,
                          color: candidate.color,
                          label: candidate.label,
                          isEnabled: candidate.isActive,
                          onTap: candidate.onTap,
                        ),
                      ],
                      if (showMoreButton) ...[
                        const SizedBox(width: _itemSpacing),
                        _MoreOptionsButton(
                          config: config,
                          legendState: legendState,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          _ZoomControls(
            zoomLevel: zoomLevel,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
        ],
      ),
    );
```

The `initializeTankPressures` post-frame callback at the top of `build` stays as-is. The old inline `if (config.hasTemperatureData) ...` toggle entries and the `Wrap` are deleted.

- [ ] **Step 4: Update pre-existing tests whose assumptions changed**

In `dive_profile_legend_test.dart`:

4a. Rewrite `'does NOT show Ceiling in primary legend even when data available'` — the adaptive row now promotes Ceiling when space allows:

```dart
    testWidgets('shows Ceiling inline when space allows', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
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
      await tester.pumpAndSettle();

      // At the 800px default test width both toggles are admitted inline.
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Ceiling'), findsOneWidget);
    });
```

4b. Wrap dialog-content assertions in `_inDialog(...)` wherever the label can now also appear inline. Affected tests and their new expectations/taps:

- `'Overlays section starts expanded with metrics visible'`: `_inDialog(find.text('Heart Rate'))`, `_inDialog(find.text('SAC Rate'))`
- `'Overlays section shows both ascent-rate toggles'`: `_inDialog(find.text('Ascent Rate'))`, `_inDialog(find.text('Ascent Rate Line'))`
- `'tapping Ascent Rate Line toggles without crashing'`: tap `_inDialog(find.text('Ascent Rate Line'))`, assert `_inDialog(find.text('Ascent Rate Line'))` findsOneWidget
- `'tapping collapsed section expands it'`: assert `_inDialog(find.text('Max Depth'))`
- `'Ceiling has visibility toggle in Decompression section'`: `_inDialog(find.text('Ceiling'))`
- `'Ceiling row has no source SegmentedButton'`: build `ceilingRow` from `find.ancestor(of: _inDialog(find.text('Ceiling')), matching: find.byType(Row)).first`
- `'Ceiling toggle changes visibility state'`: tap `_inDialog(find.text('Ceiling'))`
- `'shows Tanks section for gas-switch dives without tank pressures'`: `_inDialog(find.text('D80 (Air)'))`, `_inDialog(find.text('AL80 (EAN50)'))`
- `'keeps Tank Pressures section for multi-tank pressure dives'`: same scoping for both tank labels
- `'gas strip toggle appears in Overlays when hasGasData is true'`: `_inDialog(find.text('Gases'))`
- `'shows the Photos toggle in the Markers section when available'`: `_inDialog(find.text('Photos'))`
- deco stop band group: `'deco stops toggle appears...'` becomes `_inDialog(find.text('Deco stops'))`; `'...absent...'` keeps `findsNothing` but scoped `_inDialog(find.text('Deco stops'))`; in the two swatch tests replace `find.text('Deco stops')` / `find.text('Ceiling')` inside the `find.ancestor(...)` expressions with `_inDialog(find.text('Deco stops'))` / `_inDialog(find.text('Ceiling'))`

4c. The two tests in `group('Badge count')` will now fail (all toggles fit at 800px, so the badge shows nothing). Replace both bodies with `expect(find.byIcon(Icons.tune), findsOneWidget);` as a placeholder assertion and mark the group name `'Badge count (rewritten in badge-semantics task)'` — Task 5 rewrites them properly. Do not delete the group.

- [ ] **Step 5: Run the whole legend test file**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: PASS, including the new `adaptive inline row` group. If a boundary test fails, apply the width calibration provision from Global Constraints.

- [ ] **Step 6: Format, analyze, file-size check**

Run: `dart format . && flutter analyze && wc -l lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
Expected: zero issues; legend file under 800 lines.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "Promote profile legend toggles adaptively into a single-line row"
```

---

### Task 5: Badge counts active-but-hidden toggles

The More-button badge changes meaning: it counts active toggles that did not make it into the inline row ("things that are on but not visible here").

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

**Interfaces:**
- Consumes: `candidates` and `admitted` computed in the legend build (Task 4).
- Produces: `_MoreOptionsButton({required ProfileLegendConfig config, required int hiddenActiveCount})` — the `legendState` field and `_activeSecondaryCount` getter are deleted.

- [ ] **Step 1: Rewrite the badge tests (failing first)**

Replace the two placeholder tests in the badge group with:

```dart
  group('Badge count', () {
    testWidgets('badge counts active toggles hidden from the inline row', (
      tester,
    ) async {
      // At 250px nothing fits inline; Ceiling is active by default, so
      // exactly one active toggle is hidden behind the More button.
      await _pumpLegendAt(
        tester,
        width: 250,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      expect(find.text('Ceiling'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('badge is hidden when every active toggle is inline', (
      tester,
    ) async {
      await _pumpLegendAt(
        tester,
        width: 1200,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      expect(find.text('Ceiling'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('hidden gas strip toggle counts toward the badge', (
      tester,
    ) async {
      // showGas defaults to true; at 250px it cannot render inline.
      await _pumpLegendAt(
        tester,
        width: 250,
        config: const ProfileLegendConfig(hasGasData: true),
      );

      expect(find.text('Gases'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart --plain-name 'Badge count'`
Expected: FAIL — old badge logic counts all active secondaries (e.g. shows a count even at 1200px).

- [ ] **Step 3: Implement the new badge semantics**

In `dive_profile_legend.dart`:

3a. Inside the `LayoutBuilder` builder, after computing `admitted`, add:

```dart
                final hiddenActiveCount =
                    candidates.where((c) => c.isActive).length -
                    admitted.where((c) => c.isActive).length;
```

and construct the button as `_MoreOptionsButton(config: config, hiddenActiveCount: hiddenActiveCount)`.

3b. Rewrite `_MoreOptionsButton`: delete the `legendState` field and the whole `_activeSecondaryCount` getter; the class becomes:

```dart
/// Button that shows a badge counting active toggles hidden from the inline
/// row, and opens the chart options dialog.
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;
  final int hiddenActiveCount;

  const _MoreOptionsButton({
    required this.config,
    required this.hiddenActiveCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () => _showMoreOptions(context),
      icon: Badge(
        isLabelVisible: hiddenActiveCount > 0,
        label: Text(
          hiddenActiveCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.tune, size: 18),
      ),
      tooltip: context.l10n.diveLog_profile_tooltip_moreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        foregroundColor: hiddenActiveCount > 0
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => ChartOptionsDialog(
        config: config,
        anchorOffset: buttonOffset,
        anchorSize: buttonSize,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the whole legend test file**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format . && flutter analyze`

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "Badge counts active toggles hidden from the inline legend row"
```

---

### Task 6: Full verification

The legend renders inside `dive_profile_chart.dart`, which has its own test files; changed inline behavior can surface there. Run the full suite and fix fallout.

**Files:**
- Possibly modify: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`, `test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`

- [ ] **Step 1: Run the dive_log feature tests**

Run: `flutter test test/features/dive_log/`
Expected: PASS. Likely failure modes if not: a chart test asserting a legend label count that is now duplicated inline (scope it with the `_inDialog` pattern or assert `findsWidgets`), or a sizing test asserting legend height (the row height is unchanged at 40px, so investigate rather than loosen).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS, modulo pre-existing flaky suites unrelated to this change (backup/media-upload); rerun any failure once in isolation to confirm it is unrelated before moving on.

- [ ] **Step 3: Final format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes, zero issues.

- [ ] **Step 4: Commit any test fixes**

```bash
git add -A test/
git commit -m "Adjust chart tests for adaptive legend row"
```

(Skip the commit if Step 1 and 2 required no changes.)
