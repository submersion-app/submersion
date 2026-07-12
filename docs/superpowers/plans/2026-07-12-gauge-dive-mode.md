# Gauge Dive Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-class `gauge` dive mode that logs depth+time only — suppressing decompression, ppO2, CNS/OTU, MOD, gas-density, and gas statistics — so gauge/bottom-timer dives are not "messed up" by an assumed air mix.

**Architecture:** `DiveMode.gauge` is a new value of the existing free-text `dive_mode` column (no migration). The profile analysis service returns a profile-only result for gauge dives; the detail page hides gas/deco sections; the edit form hides tank controls; gas statistics exclude gauge dives; and downloads from a computer in gauge mode auto-classify and skip air-tank synthesis. Tank rows are preserved (hidden) when a dive is set to gauge, so the change is reversible.

**Tech Stack:** Flutter 3.x, Dart, Drift ORM (SQLite), Riverpod, flutter gen-l10n, libdivecomputer_plugin (Pigeon).

## Global Constraints

- Anything displaying units must respect the active diver's unit settings (not relevant to most tasks here, but holds).
- All Dart must pass `dart format .` with no changes and `flutter analyze` with no issues.
- New user-facing strings go into ALL 10 ARB locales (`ar de en es fr he hu it nl pt`) and are regenerated with `flutter gen-l10n`.
- `dive_mode` is a plain `TextColumn` with default `'oc'` and NO check constraint / NO enum converter — adding `DiveMode.gauge` requires NO schema-version bump and NO Drift codegen.
- `DiveMode.fromCode` must keep its default-to-`oc` behavior for unknown strings.
- Commit messages: conventional-commit style, NO `Co-Authored-By` trailer, NO Claude attribution/session line.
- Run tests with explicit file paths (the full suite is slow); never pipe `flutter analyze` through `tail`.
- Work in the worktree at `.claude/worktrees/gauge-dive-mode` (branch `worktree-gauge-dive-mode`).

---

### Task 1: Localization strings for gauge mode

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (and the other 10 ARB files: `app_ar app_de app_es app_fr app_he app_hu app_it app_nl app_pt app_zh`)
- Generated (do not hand-edit): `lib/l10n/arb/app_localizations*.dart`

(11 locales total: `ar de en es fr he hu it nl pt zh`.)

**Interfaces:**
- Produces: `AppLocalizations.enum_diveMode_gauge` (String), `AppLocalizations.diveLog_diveMode_gaugeDescription` (String). Consumed by Task 2 (selector) and Task 4.

Keys have NO `@`-metadata (matches existing `enum_diveMode_*` / `diveLog_diveMode_*Description`). Insert each new key next to its `oc/ccr/scr` siblings, preserving the file's alphabetical-ish key grouping and trailing commas.

Strings to add (English is the template; the rest are translations):

| locale | `enum_diveMode_gauge` | `diveLog_diveMode_gaugeDescription` |
|--------|----------------------|-------------------------------------|
| en | `Gauge` | `Depth and time only; no gas or decompression tracking` |
| ar | `مقياس` | `العمق والوقت فقط؛ بدون تتبع الغاز أو تخفيف الضغط` |
| de | `Gauge` | `Nur Tiefe und Zeit; keine Gas- oder Dekompressionsverfolgung` |
| es | `Gauge` | `Solo profundidad y tiempo; sin seguimiento de gas ni descompresión` |
| fr | `Profondimètre` | `Profondeur et temps uniquement; aucun suivi du gaz ni de la décompression` |
| he | `מד עומק` | `עומק וזמן בלבד; ללא מעקב גז או דקומפרסיה` |
| hu | `Gauge` | `Csak mélység és idő; nincs gáz- vagy dekompressziókövetés` |
| it | `Gauge` | `Solo profondità e tempo; nessun tracciamento di gas o decompressione` |
| nl | `Gauge` | `Alleen diepte en tijd; geen gas- of decompressietracking` |
| pt | `Gauge` | `Apenas profundidade e tempo; sem rastreamento de gás ou descompressão` |
| zh | `计深表` | `仅记录深度和时间；不追踪气体或减压` |

- [ ] **Step 1: Add the two keys to `app_en.arb`**

Next to `"enum_diveMode_ccr"` add:
```json
  "enum_diveMode_gauge": "Gauge",
```
Next to `"diveLog_diveMode_ccrDescription"` add:
```json
  "diveLog_diveMode_gaugeDescription": "Depth and time only; no gas or decompression tracking",
```

- [ ] **Step 2: Add the same two keys (translated per the table) to the other 9 ARB files**

Add `enum_diveMode_gauge` and `diveLog_diveMode_gaugeDescription` to each of `app_ar app_de app_es app_fr app_he app_hu app_it app_nl app_pt`, using the translated values from the table, next to their `ccr` siblings.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations.dart` now declares `String get enum_diveMode_gauge;` and `String get diveLog_diveMode_gaugeDescription;`.

- [ ] **Step 4: Verify getters exist and analyze is clean**

Run: `grep -n "enum_diveMode_gauge\|diveLog_diveMode_gaugeDescription" lib/l10n/arb/app_localizations.dart`
Expected: both getters present.
Run: `flutter analyze lib/l10n`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(l10n): add gauge dive mode strings (#569)"
```

---

### Task 2: `DiveMode.gauge` enum, `isGauge`, selector, and analysis suppression

This is ONE atomic task: adding `gauge` to the enum breaks every exhaustive `switch (DiveMode)` at compile time. Exactly two files have such switches (`dive_mode_selector.dart`, `profile_analysis_service.dart`); both are fixed here.

**Files:**
- Modify: `lib/core/constants/enums.dart:317-335` (add `gauge` value)
- Modify: `lib/features/dive_log/domain/entities/dive.dart:288-294` (add `isGauge`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_mode_selector.dart:72-92` (icon + description switches)
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (gauge early-return ~line 566; switch case ~line 622)
- Test: `test/core/constants/enums_test.dart`
- Test: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

**Interfaces:**
- Produces: `DiveMode.gauge` (enum value, `code == 'gauge'`, `displayName == 'Gauge'`); `Dive.isGauge` (bool getter); `ProfileAnalysisService.analyze(..., diveMode: DiveMode.gauge)` returns a profile-only `ProfileAnalysis` (empty `ceilingCurve`/`ndlCurve`/`decoStatuses`/`ppO2Curve`, null gas curves, default `O2Exposure()`, but populated `ascentRates`/`maxDepth`/`averageDepth`/`meanDepthCurve`). Consumed by Tasks 3, 4, 5.

- [ ] **Step 1: Write the failing enum test**

In `test/core/constants/enums_test.dart`, add:
```dart
group('DiveMode.gauge', () {
  test('gauge has code "gauge" and displayName "Gauge"', () {
    expect(DiveMode.gauge.code, 'gauge');
    expect(DiveMode.gauge.displayName, 'Gauge');
  });

  test('fromCode("gauge") returns gauge; unknown still falls back to oc', () {
    expect(DiveMode.fromCode('gauge'), DiveMode.gauge);
    expect(DiveMode.fromCode('nonsense'), DiveMode.oc);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/constants/enums_test.dart`
Expected: FAIL — `DiveMode.gauge` is not defined (compile error).

- [ ] **Step 3: Add the `gauge` enum value**

In `lib/core/constants/enums.dart`, change the enum declaration:
```dart
enum DiveMode {
  oc('Open Circuit'),
  ccr('Closed Circuit Rebreather'),
  scr('Semi-Closed Rebreather'),
  gauge('Gauge');
```
(`code`, `fromCode`, and `displayName` are unchanged — `gauge` participates automatically.)

- [ ] **Step 4: Add `isGauge` to the domain entity**

In `lib/features/dive_log/domain/entities/dive.dart`, after `isSCR` (line 291), before `isRebreather`:
```dart
  /// Whether this is an SCR dive
  bool get isSCR => diveMode == DiveMode.scr;

  /// Whether this is a gauge (bottom-timer) dive: depth+time only, no gas
  /// or decompression modeling.
  bool get isGauge => diveMode == DiveMode.gauge;

  /// Whether this is any type of rebreather dive
  bool get isRebreather => isCCR || isSCR;
```
(`isRebreather` intentionally excludes gauge.)

- [ ] **Step 5: Fix the selector's exhaustive switches**

In `lib/features/dive_log/presentation/widgets/dive_mode_selector.dart`, add a `gauge` arm to `_getIconForMode` (line 72):
```dart
      case DiveMode.scr:
        return Icons.sync_alt; // Semi-closed - partial loop
      case DiveMode.gauge:
        return Icons.timer_outlined; // Gauge / bottom timer - depth & time only
    }
```
And to `_getDescriptionForMode` (line 83):
```dart
      case DiveMode.scr:
        return context.l10n.diveLog_diveMode_scrDescription;
      case DiveMode.gauge:
        return context.l10n.diveLog_diveMode_gaugeDescription;
    }
```

- [ ] **Step 6: Write the failing analysis test**

In `test/features/dive_log/data/services/profile_analysis_service_test.dart`, add (reuse the file's existing `ProfileAnalysisService()` setup and depth/timestamp helpers; a descending-then-ascending profile that WOULD incur deco on air):
```dart
group('gauge dive mode', () {
  test('gauge returns profile-only analysis: no deco/ppO2/tox, keeps ascent', () {
    final service = ProfileAnalysisService();
    // 40 m for 30 min then a fast ascent — on air this would show deco.
    final depths = <double>[0, 20, 40, 40, 40, 40, 40, 20, 0];
    final timestamps = <int>[0, 60, 120, 600, 1200, 1800, 1810, 1850, 1900];

    final gauge = service.analyze(
      diveId: 'g1',
      depths: depths,
      timestamps: timestamps,
      diveMode: DiveMode.gauge,
    );

    // No decompression / O2 toxicity / gas curves.
    expect(gauge.ceilingCurve, isEmpty);
    expect(gauge.ndlCurve, isEmpty);
    expect(gauge.decoStatuses, isEmpty);
    expect(gauge.ppO2Curve, isEmpty);
    expect(gauge.hasCnsData, isFalse);
    expect(gauge.hasModData, isFalse);
    expect(gauge.hasDensityData, isFalse);
    expect(gauge.o2Exposure.cnsEnd, 0.0);
    // Still surfaces depth/time-derived data for the profile chart.
    expect(gauge.maxDepth, 40);
    expect(gauge.ascentRates, isNotEmpty);
  });
});
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart --plain-name "gauge dive mode"`
Expected: FAIL — currently gauge produces air-based deco (non-empty `ceilingCurve`), or a compile error on the not-yet-handled switch.

- [ ] **Step 8: Add the gauge early-return in `analyze()`**

In `lib/features/dive_log/data/services/profile_analysis_service.dart`, immediately AFTER the ascent-rate block (after `ascentRateViolations` is computed, ~line 565) and BEFORE `// Calculate decompression data` (line 567), insert:
```dart
    // Gauge (bottom-timer) dives record depth and time only. No gas is known,
    // so decompression, ppO2, CNS/OTU, MOD, and gas-density analysis are not
    // meaningful and must never be fabricated from an assumed air mix. Surface
    // the depth/time-derived data (ascent rates, depth stats, events) and leave
    // every gas/deco curve empty so panels and chart overlays report "no data".
    if (diveMode == DiveMode.gauge) {
      double maxDepth = 0;
      int maxDepthTimestamp = 0;
      double depthSum = 0;
      for (int i = 0; i < depths.length; i++) {
        if (depths[i] > maxDepth) {
          maxDepth = depths[i];
          maxDepthTimestamp = timestamps[i];
        }
        depthSum += depths[i];
      }
      final gaugeEvents = _detectEvents(
        diveId: diveId,
        depths: depths,
        timestamps: timestamps,
        ascentRates: ascentRates,
        ascentRateViolations: ascentRateViolations,
        ndlCurve: const [],
        ppO2Curve: const [],
        maxDepth: maxDepth,
        maxDepthTimestamp: maxDepthTimestamp,
      );
      return ProfileAnalysis(
        ascentRates: ascentRates,
        ascentRateStats: ascentRateStats,
        ascentRateViolations: ascentRateViolations,
        events: gaugeEvents,
        ceilingCurve: const [],
        ndlCurve: const [],
        decoStatuses: const [],
        o2Exposure: const O2Exposure(),
        ppO2Curve: const [],
        meanDepthCurve: _calculateMeanDepthCurve(depths),
        maxDepth: maxDepth,
        averageDepth: depths.isNotEmpty ? depthSum / depths.length : 0,
        maxDepthTimestamp: maxDepthTimestamp,
        durationSeconds:
            timestamps.isNotEmpty ? timestamps.last - timestamps.first : 0,
      );
    }
```

- [ ] **Step 9: Satisfy the exhaustive ppO2 switch**

The `switch (diveMode)` at ~line 622 is exhaustive and now needs a `gauge` arm. Add (after the `case DiveMode.oc:` arm, ~line 666):
```dart
      case DiveMode.gauge:
        // Unreachable: gauge returns early above. Present only so the switch
        // stays exhaustive over DiveMode.
        ppO2Curve = List<double>.filled(depths.length, 0.0);
    }
```

- [ ] **Step 10: Run both test files to verify they pass**

Run: `flutter test test/core/constants/enums_test.dart test/features/dive_log/data/services/profile_analysis_service_test.dart`
Expected: PASS.

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze lib/core/constants lib/features/dive_log
git add lib/core/constants/enums.dart lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/presentation/widgets/dive_mode_selector.dart lib/features/dive_log/data/services/profile_analysis_service.dart test/core/constants/enums_test.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "feat(dive-log): add gauge dive mode with profile-only analysis (#569)"
```

---

### Task 3: Analysis providers skip the computer-deco overlay for gauge

`analyze()` now returns profile-only for gauge, but both analysis providers post-process it with `overlayComputerDecoData` (which can re-inject computer-reported NDL/ceiling/CNS) and compute a rebreather ppO2. Gate both.

> IMPLEMENTATION NOTE (as-built): the short-circuit is placed at the TOP of each
> provider (right after the empty-profile guard / after `final diveId = dive.id;`),
> BEFORE any GF/residual/settings lookups — a gauge dive needs none of them. Uses a
> default `ProfileAnalysisService().analyze(..., diveMode: DiveMode.gauge)`. This is
> cleaner and unit-testable in a bare `ProviderContainer` (no settings overrides),
> and makes the separate rebreather-ppO2 line edits unnecessary. The test fixture
> uses the `Dive` domain field `dateTime:` (NOT `diveDateTime:`, which is the DB
> column name).

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` — `computeAnalysisForProfile` (~line 825 and ~line 870) and `diveProfileAnalysisProvider` (~line 1298 and ~line 1335)
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_gauge_test.dart` (create)

**Interfaces:**
- Consumes: `Dive.isGauge`, gauge-aware `analyze()` (Task 2).
- Produces: `diveProfileAnalysisProvider(gaugeDive)` returns the profile-only analysis unmodified (no overlay). Consumed by the detail page / chart.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/dive_log/presentation/providers/profile_analysis_provider_gauge_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

void main() {
  test('diveProfileAnalysisProvider returns profile-only analysis for gauge', () {
    final profile = <DiveProfilePoint>[
      for (var i = 0; i <= 9; i++)
        DiveProfilePoint(
          timestamp: i * 60,
          depth: [0.0, 20, 40, 40, 40, 40, 40, 20, 10, 0][i],
        ),
    ];
    final dive = Dive(
      id: 'gauge-1',
      diveDateTime: DateTime.utc(2026, 1, 1),
      diveMode: DiveMode.gauge,
      profile: profile,
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final analysis = container.read(diveProfileAnalysisProvider(dive));
    expect(analysis, isNotNull);
    expect(analysis!.ceilingCurve, isEmpty);
    expect(analysis.ppO2Curve, isEmpty);
    expect(analysis.hasCnsData, isFalse);
    expect(analysis.ascentRates, isNotEmpty);
  });
}
```
(If `Dive`/`DiveProfilePoint` require more non-null fields, copy the minimal constructor args used by the existing dive fixtures under `test/`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_gauge_test.dart`
Expected: FAIL — overlay may run / ceilingCurve non-empty, or the profile-only guarantee is not yet enforced at the provider.

- [ ] **Step 3: Gate `diveProfileAnalysisProvider`**

In `profile_analysis_provider.dart`, change the rebreather-ppO2 line (~1298) so gauge does not resolve a loop ppO2:
```dart
    final rebreatherPpO2 = dive.isRebreather
        ? resolveRebreatherPpO2(dive.profile)
        : null;
```
Then immediately AFTER `final analysis = service.analyze(...);` (after line 1335) and BEFORE `// Overlay computer-reported deco data` (line 1337), insert:
```dart
    if (dive.isGauge) {
      // Gauge dives carry no gas/deco; do not overlay computer deco data.
      return analysis;
    }
```

- [ ] **Step 4: Gate `computeAnalysisForProfile`**

In the same file, change the rebreather-ppO2 line (~825) to:
```dart
    final rebreatherPpO2 = dive.isRebreather
        ? resolveRebreatherPpO2(profile)
        : null;
```
Then immediately AFTER the `final analysis = await compute(_runProfileAnalysis, ...);` call closes (after line 870) and BEFORE `// Overlay computer-reported deco data` (line 872), insert:
```dart
    if (dive.isGauge) {
      // Gauge dives carry no gas/deco: skip the computer-deco overlay and the
      // computer-CNS override; still surface any dive-computer events.
      final dbEvents =
          await ref.watch(diveComputerEventsProvider(diveId).future);
      return dbEvents.isEmpty
          ? analysis
          : analysis.copyWith(events: mergeEvents(analysis.events, dbEvents));
    }
```

Note: the pre-existing `dive.diveMode == DiveMode.oc` guards at lines 809/816 already null out gas segments and ascent gases for gauge — leave them as-is.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_gauge_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze lib/features/dive_log/presentation/providers
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_gauge_test.dart
git commit -m "feat(dive-log): skip computer-deco overlay for gauge dives (#569)"
```

---

### Task 4: Edit form hides tank controls in gauge mode

Add a `showTankControls` flag to `GasGearSection`; when false, hide the tank list and the add-tank row (keep mode selector, weights, equipment). Wire it from the edit page.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:2386-2423` (`_buildGasGearSection`)
- Test: `test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart` (create)

**Interfaces:**
- Consumes: `DiveMode.gauge` (Task 2).
- Produces: `GasGearSection(... showTankControls: bool)` — when false, `tankCards` and the add-tank InkWell are not built; `rebreatherPanel`, `modeSelector`, `equipmentChild`, `weightChild` still render.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('hides tank cards and add-tank row when showTankControls is false',
      (tester) async {
    await tester.pumpWidget(_host(GasGearSection(
      expanded: true,
      onToggle: () {},
      summary: 'summary',
      modeSelector: const Text('MODE'),
      tankCards: const [Text('TANK-CARD')],
      onAddTank: () {},
      addTankLabel: 'Add tank',
      equipmentChild: const Text('EQUIP'),
      weightChild: const Text('WEIGHTS'),
      showTankControls: false,
    )));
    await tester.pumpAndSettle();

    expect(find.text('TANK-CARD'), findsNothing);
    expect(find.text('+ Add tank'), findsNothing);
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('EQUIP'), findsOneWidget);
    expect(find.text('WEIGHTS'), findsOneWidget);
  });

  testWidgets('shows tank cards when showTankControls is true (default)',
      (tester) async {
    await tester.pumpWidget(_host(GasGearSection(
      expanded: true,
      onToggle: () {},
      summary: 'summary',
      modeSelector: const Text('MODE'),
      tankCards: const [Text('TANK-CARD')],
      onAddTank: () {},
      addTankLabel: 'Add tank',
      equipmentChild: const Text('EQUIP'),
      weightChild: const Text('WEIGHTS'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('TANK-CARD'), findsOneWidget);
    expect(find.text('+ Add tank'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart`
Expected: FAIL — `showTankControls` is not a parameter (compile error).

- [ ] **Step 3: Add the `showTankControls` flag to `GasGearSection`**

In `gas_gear_section.dart`, add the field (default true) to the constructor and class:
```dart
    required this.equipmentChild,
    required this.weightChild,
    this.rebreatherPanel,
    this.showTankControls = true,
    this.errorCount = 0,
  });
```
```dart
  final Widget equipmentChild;
  final Widget weightChild;

  /// Whether to show the tank cards + add-tank affordance. False for gauge
  /// dives, which log depth and time only.
  final bool showTankControls;
```
Then in `build`, replace the unconditional tank widgets (lines 56-71) with conditional ones:
```dart
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: modeSelector,
        ),
        ?rebreatherPanel,
        if (showTankControls) ...[
          Column(children: tankCards),
          InkWell(
            onTap: onAddTank,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  '+ $addTankLabel',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        equipmentChild,
        weightChild,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the flag from the edit page**

In `dive_edit_page.dart` `_buildGasGearSection` (line 2388), add the flag to the `GasGearSection(...)` call (e.g. right after `weightChild:`):
```dart
      equipmentChild: _equipmentChild(),
      weightChild: _weightChild(units),
      showTankControls: _diveMode != DiveMode.gauge,
    );
```
(`_rebreatherPanel()` already returns null for non-CCR/SCR modes, so gauge shows no rebreather panel.)

- [ ] **Step 6: Analyze the edit page and commit**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`
Expected: No issues.
```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart
git commit -m "feat(dive-log): hide tank controls in gauge mode edit form (#569)"
```

---

### Task 5: Detail page hides gas/deco sections for gauge

Hide `decoO2` (deco/tissue/O2 tox), `sacSegments` (SAC by segment), and `tanks` (Cylinders) sections on the dive detail page when the dive is gauge. The always-on profile chart still renders (its deco/ppO2 overlays are already empty for gauge from Tasks 2-3).

**Files:**
- Modify: `lib/core/constants/dive_detail_sections.dart` (add a `hiddenInGaugeMode` predicate on `DiveDetailSectionId`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:487-488` (render guard)
- Test: `test/core/constants/dive_detail_sections_test.dart` (create or extend)

**Interfaces:**
- Consumes: `Dive.isGauge` (Task 2).
- Produces: `DiveDetailSectionId.hiddenInGaugeMode` (bool) — true for `decoO2`, `sacSegments`, `tanks`.

- [ ] **Step 1: Write the failing predicate test**

Create `test/core/constants/dive_detail_sections_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

void main() {
  test('gauge hides deco, SAC segments, and cylinders sections only', () {
    final hidden = DiveDetailSectionId.values
        .where((s) => s.hiddenInGaugeMode)
        .toSet();
    expect(hidden, {
      DiveDetailSectionId.decoO2,
      DiveDetailSectionId.sacSegments,
      DiveDetailSectionId.tanks,
    });
    // Sanity: sections a gauge diver still wants remain visible.
    expect(DiveDetailSectionId.environment.hiddenInGaugeMode, isFalse);
    expect(DiveDetailSectionId.weights.hiddenInGaugeMode, isFalse);
    expect(DiveDetailSectionId.notes.hiddenInGaugeMode, isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: FAIL — `hiddenInGaugeMode` is not defined.

- [ ] **Step 3: Add the predicate**

In `dive_detail_sections.dart`, add to the `DiveDetailSectionId` enum (after `localizedDescription`, before the closing `}` at line 125):
```dart
  /// Whether this section is hidden for gauge (bottom-timer) dives, which log
  /// depth and time only — no gas, decompression, or O2-toxicity data.
  bool get hiddenInGaugeMode =>
      this == DiveDetailSectionId.decoO2 ||
      this == DiveDetailSectionId.sacSegments ||
      this == DiveDetailSectionId.tanks;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: PASS.

- [ ] **Step 5: Apply the guard in the detail page**

In `dive_detail_page.dart`, change the section render loop (line 487-488) from:
```dart
            for (final section in settings.diveDetailSections)
              if (section.visible) ...builders[section.id]?.call() ?? [],
```
to:
```dart
            for (final section in settings.diveDetailSections)
              if (section.visible &&
                  !(dive.isGauge && section.id.hiddenInGaugeMode))
                ...builders[section.id]?.call() ?? [],
```

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze lib/core/constants/dive_detail_sections.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No issues.
```bash
dart format lib/ test/
git add lib/core/constants/dive_detail_sections.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/core/constants/dive_detail_sections_test.dart
git commit -m "feat(dive-log): hide gas/deco detail sections for gauge dives (#569)"
```

---

### Task 6: Statistics exclude gauge dives from gas queries

A gauge dive keeps its (hidden) tank rows for reversibility, so gas statistics must exclude it explicitly. Add `AND d.dive_mode <> 'gauge'` to each gas-derived query (NOT the shared `_diveFilter` — gauge dives still count toward dive-count/depth stats).

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` — `getGasMixDistribution` (~275), `getSacVolumeTrend` (~78), `getSacPressureTrend` (~209), `getSacVolumeRecords` (~325), `getSacPressureRecords` (~454), `getSacVolumeByTankRole` (~518), `getSacPressureByTankRole` (~598) [as-built: 7 queries total incl. `getSacVolumeByTankRole`, which the original list missed; all use alias `d`]
- Test: `test/features/statistics/data/repositories/statistics_repository_gauge_test.dart` (create)

**Interfaces:**
- Consumes: `dive_mode` column value `'gauge'`.
- Produces: gas stats that ignore gauge dives.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/data/repositories/statistics_repository_gauge_test.dart`, modeled on the existing `statistics_repository_sac_test.dart` setup (in-memory `AppDatabase`, `StatisticsRepository`). Insert one OC air dive with a tank and one gauge dive with a tank, then:
```dart
test('getGasMixDistribution excludes gauge dives', () async {
  // (setup) insert an OC dive with an air tank, and a gauge dive with a tank.
  final dist = await repository.getGasMixDistribution();
  final total = dist.fold<int>(0, (sum, s) => sum + s.count);
  expect(total, 1, reason: 'only the OC dive should be counted');
});
```
(Use the same insertion helpers the sibling SAC test uses; set `diveMode: const Value('gauge')` on the gauge dive's `DivesCompanion`, and `'oc'` on the other.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_gauge_test.dart`
Expected: FAIL — total is 2 (gauge dive counted as "Air").

- [ ] **Step 3: Add the gauge filter to `getGasMixDistribution`**

In `statistics_repository.dart`, change the `WHERE` line inside the `getGasMixDistribution` SQL (currently `WHERE 1=1 $diverFilter ${df.clause}`):
```sql
        WHERE 1=1 AND d.dive_mode <> 'gauge' $diverFilter ${df.clause}
```

- [ ] **Step 4: Add the same filter to the five SAC queries**

For each of `getSacVolumeTrend`, `getSacPressureTrend`, `getSacVolumeRecords`, `getSacPressureRecords`, `getSacPressureByTankRole`, first read the query to confirm the alias its `FROM dives <alias>` uses (getGasMixDistribution uses `d`; verify each query individually — do not assume). Then add `AND <alias>.dive_mode <> 'gauge'` into that query's existing `WHERE`/`AND` chain (the same chain that already constrains `dive_tanks` / pressures). Show each edited WHERE clause verbatim in the diff; do not introduce a shared constant.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_gauge_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the existing statistics suite (regression) and commit**

Run: `flutter test test/features/statistics/data/repositories/`
Expected: PASS (no regressions in SAC/filter tests).
```bash
dart format lib/ test/
git add lib/features/statistics/data/repositories/statistics_repository.dart test/features/statistics/data/repositories/statistics_repository_gauge_test.dart
git commit -m "feat(statistics): exclude gauge dives from gas statistics (#569)"
```

---

### Task 7: Download raw-parse paths detect gauge (reparse + tank synthesis)

Map libdivecomputer's gauge mode string to `'gauge'` and skip air-tank synthesis for gauge dives. This covers the reparse path and the shared tank resolver (both live-download and reparse call `resolveParsedTanks`).

**Files:**
- Create: `lib/features/dive_computer/data/services/libdc_dive_mode.dart` (shared `mapLibdcDiveModeCode`)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart:378,751-762` (use shared mapper; delete `_mapDiveMode`)
- Modify: `lib/features/dive_computer/data/services/parsed_tank_resolver.dart:84` (`_resolveCylinders` gauge guard)
- Test: `test/features/dive_computer/data/services/parsed_tank_resolver_test.dart` (extend)
- Test: `test/features/dive_computer/data/services/libdc_dive_mode_test.dart` (create)

**Interfaces:**
- Consumes: `parsed.diveMode` string (`"gauge"` for gauge — emitted by the plugin's native layer, confirmed).
- Produces: `mapLibdcDiveModeCode(String?) -> String` (a `DiveMode.code`); reparse persists `dive_mode = 'gauge'`; `resolveParsedTanks(gaugeParsed) == const []`; `resolveGasSwitches(gaugeParsed) == const []`. `mapLibdcDiveModeCode` is also consumed by Task 8.

- [ ] **Step 1: Write the failing tank-resolver test**

In `parsed_tank_resolver_test.dart`, add (using the file's existing `ParsedDive` fixture builder):
```dart
test('gauge-mode parsed dive yields no synthesized tanks or switches', () {
  final parsed = buildParsedDive(
    diveMode: 'gauge',
    gasMixes: [buildGasMix(index: 0, o2: 21, he: 0)], // computer reported air
    tanks: const [],
  );
  expect(resolveParsedTanks(parsed), isEmpty);
  expect(resolveGasSwitches(parsed), isEmpty);
});
```
(Match the fixture helper names actually used in this test file; add the `diveMode` argument to the fixture builder if it doesn't set it.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/parsed_tank_resolver_test.dart --plain-name "gauge-mode"`
Expected: FAIL — currently one pressureless air cylinder is synthesized.

- [ ] **Step 3: Add the gauge guard to `_resolveCylinders`**

In `parsed_tank_resolver.dart`, at the very top of `_resolveCylinders` (after line 84's signature, before `final gasMixes = parsed.gasMixes;`):
```dart
_ResolvedCylinders _resolveCylinders(pigeon.ParsedDive parsed) {
  // Gauge (bottom-timer) dives log depth and time only. Never synthesize a
  // cylinder (or an air fallback) for them, so the imported dive stays tankless.
  if (parsed.diveMode == 'gauge') {
    return const _ResolvedCylinders([], {});
  }
  final gasMixes = parsed.gasMixes;
```
(This makes both `resolveParsedTanks` and `resolveGasSwitches` return empty, since `gasIndexToTankIndex` is empty.)

- [ ] **Step 4: Run the resolver test to verify it passes**

Run: `flutter test test/features/dive_computer/data/services/parsed_tank_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing shared-mapper test**

Create `test/features/dive_computer/data/services/libdc_dive_mode_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';

void main() {
  test('maps libdivecomputer dive-mode strings to app codes', () {
    expect(mapLibdcDiveModeCode('gauge'), 'gauge');
    expect(mapLibdcDiveModeCode('open_circuit'), 'oc');
    expect(mapLibdcDiveModeCode('ccr'), 'ccr');
    expect(mapLibdcDiveModeCode('scr'), 'scr');
    expect(mapLibdcDiveModeCode('freedive'), 'oc'); // deferred: freedive -> oc
    expect(mapLibdcDiveModeCode(null), 'oc');
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/libdc_dive_mode_test.dart`
Expected: FAIL — `libdc_dive_mode.dart` / `mapLibdcDiveModeCode` does not exist.

- [ ] **Step 7: Create the shared mapper and use it in reparse**

Create `lib/features/dive_computer/data/services/libdc_dive_mode.dart`:
```dart
/// Map dive-mode strings emitted by the libdivecomputer plugin
/// ("freedive"/"gauge"/"open_circuit"/"ccr"/"scr") to the app's [DiveMode]
/// codes. Gauge maps to 'gauge'; freedive is intentionally deferred to 'oc'
/// (freedive is a separate axis handled elsewhere).
String mapLibdcDiveModeCode(String? mode) {
  switch (mode) {
    case 'open_circuit':
      return 'oc';
    case 'ccr':
      return 'ccr';
    case 'scr':
      return 'scr';
    case 'gauge':
      return 'gauge';
    default:
      return 'oc';
  }
}
```
Then in `reparse_service.dart`: delete the private `_mapDiveMode` (lines 750-762), add `import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';`, and change the call site (line 378) from `diveMode: Value(_mapDiveMode(parsed.diveMode))` to `diveMode: Value(mapLibdcDiveModeCode(parsed.diveMode))`.

- [ ] **Step 8: Run both download test files to verify they pass**

Run: `flutter test test/features/dive_computer/data/services/parsed_tank_resolver_test.dart test/features/dive_computer/data/services/libdc_dive_mode_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze lib/features/dive_computer/data/services
git add lib/features/dive_computer/data/services/libdc_dive_mode.dart lib/features/dive_computer/data/services/reparse_service.dart lib/features/dive_computer/data/services/parsed_tank_resolver.dart test/features/dive_computer/data/services/parsed_tank_resolver_test.dart test/features/dive_computer/data/services/libdc_dive_mode_test.dart
git commit -m "feat(dive-computer): detect gauge mode on reparse and skip tank synthesis (#569)"
```

---

### Task 8: Live-download persists the computer's dive mode (gauge auto-detect)

The live-download path builds a `DownloadedDive` (no `diveMode`) and persists via `importProfile` (no `diveMode`), so it currently always stores `'oc'`. Thread the computer's mode through, mirroring how `decoAlgorithm` is already threaded. This also fixes latent loss of CCR/SCR on live download.

> NOTE (flag for reviewer): this task changes live-download behavior for CCR/SCR too (they were previously stored as `'oc'` and had to be set manually). If you want gauge-only, restrict the mapping in Step 4 to `mode == 'gauge' ? DiveMode.gauge : DiveMode.oc`. Call this out in the PR description.

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (add `diveMode` field, ~line 138)
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart:24` (set `diveMode`)
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart:502-562` (pass `diveMode` to `importProfile`)
- Modify: the dive repository `importProfile` signature + DivesCompanion write (locate via `grep -n "Future<String> importProfile" lib/features/dive_log/data/repositories/dive_repository_impl.dart` and its abstract declaration) — mirror the existing `decoAlgorithm` parameter end-to-end
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart` (create or extend)

**Interfaces:**
- Consumes: `mapLibdcDiveModeCode` (Task 7), `parsed.diveMode`.
- Produces: `DownloadedDive.diveMode` (`DiveMode`); a live-downloaded gauge dive persists with `dive_mode = 'gauge'` and no tanks (tanks already empty via Task 7's resolver guard).

- [ ] **Step 1: Write the failing mapper test**

Create/extend `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`:
```dart
test('parsedDiveToDownloaded maps gauge mode and imports no tanks', () {
  final parsed = buildParsedDive(diveMode: 'gauge', tanks: const [], gasMixes: const []);
  final downloaded = parsedDiveToDownloaded(parsed);
  expect(downloaded.diveMode, DiveMode.gauge);
  expect(downloaded.tanks, isEmpty);
});
```
(Reuse the same `ParsedDive` fixture builder as Task 7.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: FAIL — `DownloadedDive.diveMode` undefined.

- [ ] **Step 3: Add the `diveMode` field to `DownloadedDive`**

In `downloaded_dive.dart`, add to the class fields (near `decoAlgorithm`, ~line 129) and the constructor:
```dart
  /// Breathing/logging mode reported by the computer (oc/ccr/scr/gauge).
  final DiveMode diveMode;
```
Add `this.diveMode = DiveMode.oc,` to the constructor (matching the existing default-parameter style; import `enums.dart` if not already imported).

- [ ] **Step 4: Set `diveMode` in `parsedDiveToDownloaded`**

In `parsed_dive_mapper.dart`, add these imports:
```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';
```
and add to the `DownloadedDive(...)` construction (after `decoConservatism:`, ~line 47):
```dart
    decoConservatism: parsed.decoConservatism,
    diveMode: DiveMode.fromCode(mapLibdcDiveModeCode(parsed.diveMode)),
```

- [ ] **Step 5: Thread `diveMode` through `importProfile`**

Mirror `decoAlgorithm` exactly:
1. Add `DiveMode diveMode = DiveMode.oc,` to the `importProfile` declaration (abstract interface + `dive_repository_impl.dart` implementation).
2. In the implementation, write it to the `DivesCompanion` (find where `decoAlgorithm:`/`diveMode:` is set on the companion; set `diveMode: Value(diveMode.code)`).
3. In `dive_import_service.dart` `_importNewDive`, pass `diveMode: dive.diveMode,` in the `importProfile(...)` call (after `decoConservatism:`, ~line 547).

- [ ] **Step 6: Run the mapper test + a focused import regression**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_computer/`
Expected: PASS (no regressions in existing download/import tests).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze lib/features/dive_computer lib/features/dive_log/data/repositories
git add lib/features/dive_computer/domain/entities/downloaded_dive.dart lib/features/dive_computer/data/services/parsed_dive_mapper.dart lib/features/dive_computer/data/services/dive_import_service.dart lib/features/dive_log/data/repositories/ test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
git commit -m "feat(dive-computer): persist gauge dive mode on live download (#569)"
```

---

## Final verification (after all tasks)

- [ ] Run the full affected suites:
  `flutter test test/core/constants test/features/dive_log test/features/statistics test/features/dive_computer`
- [ ] `dart format .` (whole project) — no changes.
- [ ] `flutter analyze` (whole project) — No issues.
- [ ] Manual smoke (macOS): create a dive, set mode to Gauge → tank controls disappear in the edit form; save; open detail → no Cylinders / Deco / SAC-segment sections, profile chart still shows depth+time; confirm gas-mix statistics tab excludes it. Switch back to OC → tanks and gas/deco return.

## Post-implementation

- [ ] Update the issue #569 thread / PR description. Note the Task 8 CCR/SCR live-download behavior change and the deferred freedive mapping.
- [ ] Follow-up issue (optional): map libdivecomputer `freedive` mode (currently → `oc`) to a dedicated handling if desired.
