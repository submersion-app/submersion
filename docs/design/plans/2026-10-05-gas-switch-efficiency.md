# Gas-Switch Efficiency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect late and missed open-circuit deco gas switches, cost each by tissue replay, and show them as a chart overlay, a dive detail card and a safety review finding, without changing any existing deco value.

**Architecture:** A pure analyzer in `lib/core/deco/gas_switch/` (detector, on-time gas schedule, tissue replay, orchestrator) runs inside `ProfileAnalysisService.analyze` on the OC path after every existing curve is built, on its own engine instances, and stores its result in a new nullable `ProfileAnalysis.gasSwitchEfficiency`. The UI (chart bands and tooltip, detail card, safety rule) only reads that field. A persisted diver setting seeds the overlay toggle.

**Tech Stack:** Flutter, Dart, Riverpod, Drift (schema v261), fl_chart, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-05-gas-switch-efficiency-design.md`

## Global Constraints

- TTS, ceiling, deco stops, CNS and every other `DecoStatus` / `ProfileAnalysis` value stay byte-identical. The analyzer never touches `_buhlmannAlgorithm` and never mutates analysis lists.
- Open circuit only: runs when `diveMode == DiveMode.oc`, gas segments exist, and the ascent plan is an `OptimalOcAscentGas` with at least two gases.
- Gases are exactly `OptimalOcAscentGas.gases` (built by `buildAvailableGases`); mixes match by fO2 and fHe within 0.005.
- Tolerance: late when `idealDepth - switchDepth > stopIncrement` or `switchTimestamp - idealTimestamp > 120 s`. MOD hysteresis 1.0 m. Replay TTS stride 30 s.
- Flag only windows with `ceilingCurve > 0` somewhere inside them.
- Safety severity: caution, significant when extra deco >= 300 s. `SafetyReviewService.engineVersion` 5 to 6.
- Persisted setting `defaultShowLateGasSwitches`, default true, schema 260 to 261, rung in `migrations/ladder/rungs_v231_onward.dart`. Nothing new in `database.dart` except the version constant and the `migrationVersions` entry.
- `lib/core/database/migrations/before_open.dart` is at the 800-line guard cap; it must not grow.
- Depths and times in the UI go through `UnitFormatter` (diver units).
- No em dashes or en dashes as punctuation in code, comments, ARB strings, commits or docs. No emojis. Files 200 to 400 lines typical, 800 max.
- Run `dart format .` before each commit. Never `git add -A`; stage explicit paths.

## Review Focus

1. **Recorded air vs cylinder air.** Segments use `airN2Fraction` (0.7902), cylinders 0.79; a strict equality would call air a different gas and invent windows. Pinned by the detector test "air segment matches an air cylinder" (Task 2).
2. **Switch recorded between samples.** A gas switch timestamp rarely lands on a sample; the on-time schedule must not lose or duplicate segments. Pinned by `withSwitchesOnTime` tests (Task 3).
3. **Repetitive dive (residual tissues).** The replay must seed from `startCompartments` exactly like the analysis, or costs drift. Pinned by the replay parity test with seeded compartments (Task 3).
4. **Imperial units in the tooltip and card.** Depth delays must convert; pinned by the card widget test in feet (Task 10) and the tooltip format test (Task 9).
5. **Band past the visible range.** A window extending beyond the visible x range (zoomed chart, or a missed window ending at the last sample) must be clamped, since fl_chart asserts on out-of-range annotations; pinned by the chart clamp test (Task 9).

---

## File Structure

Create:
- `lib/core/deco/gas_switch/gas_switch_efficiency.dart`: result types (`GasSwitchWindowKind`, `GasSwitchWindow`, `GasSwitchEfficiency`).
- `lib/core/deco/gas_switch/gas_segment_lookup.dart`: `activeSegmentAt`, `segmentFO2`, `sameMix`, `mixMatchTolerance`.
- `lib/core/deco/gas_switch/gas_switch_window_detector.dart`: `DetectedSwitchWindow`, `SwitchWindowDetection`, `detectSwitchWindows`.
- `lib/core/deco/gas_switch/on_time_gas_schedule.dart`: `withSwitchesOnTime`.
- `lib/core/deco/gas_switch/tissue_replay.dart`: `TissueReplay` (interval loading, peak TTS gap).
- `lib/core/deco/gas_switch/gas_switch_efficiency_analyzer.dart`: `GasSwitchEfficiencyAnalyzer` (flag rule, costs).
- `lib/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart`: the dive detail card.
- `lib/features/dive_log/presentation/utils/gas_switch_format.dart`: shared tooltip/card formatting (`formatMinSec`, `gasSwitchGasLabel`, `lateSwitchColor`).
- Tests under `test/core/deco/gas_switch/`, `test/features/dive_log/...`, `test/core/database/migration_v261_late_gas_switch_setting_test.dart`.

Modify:
- `lib/core/deco/ascent/ascent_gas_plan.dart` (public `gases` getter), `lib/core/deco/buhlmann_algorithm.dart` (`withSameConfig`).
- `lib/features/dive_log/data/services/profile_analysis_service.dart` (field + wiring).
- `lib/features/dive_log/domain/entities/safety_finding.dart`, `lib/features/dive_log/domain/services/safety_review_service.dart`, `lib/features/dive_log/presentation/widgets/safety_finding_text.dart`, `lib/features/settings/presentation/pages/safety_settings_page.dart`.
- Settings stack: `lib/core/database/tables/diver_tables.dart`, `lib/core/database/migrations/helpers/diver_migrations.dart`, `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/before_open.dart`, `lib/core/database/database.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`, `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/presentation/pages/section_appearance_page.dart`, `test/helpers/mock_providers.dart` (and any other fake the analyzer flags).
- Legend/chart: `profile_legend_provider.dart`, `profile_legend_config.dart`, `chart_options_dialog.dart`, `active_legend_entries.dart`, `dive_profile_chart.dart`.
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`.
- 11 ARB files plus generated `app_localizations*.dart`.

---

### Task 1: Result types and plan/engine accessors

**Files:**
- Create: `lib/core/deco/gas_switch/gas_switch_efficiency.dart`
- Modify: `lib/core/deco/ascent/ascent_gas_plan.dart` (class `OptimalOcAscentGas`)
- Modify: `lib/core/deco/buhlmann_algorithm.dart` (after the constructor, ~line 60)
- Test: `test/core/deco/gas_switch/gas_switch_efficiency_test.dart`

**Interfaces:**
- Produces: `GasSwitchWindowKind {late, missed}`; `GasSwitchWindow` (fields below, `contains(int)`, `isMissed`, `copyWith`); `GasSwitchEfficiency({required bool evaluated, List<GasSwitchWindow> windows = const [], int totalExtraDecoSeconds = 0})`, `GasSwitchEfficiency.notEvaluated`, `windowAt(int)`, `copyWith`; `OptimalOcAscentGas.gases` (`List<AvailableGas>`); `BuhlmannAlgorithm.withSameConfig()` (`BuhlmannAlgorithm`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';

void main() {
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1910,
    switchDepth: 15,
    endTimestamp: 1910,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: 120,
  );

  test('window contains its inclusive span only', () {
    expect(late.contains(1629), isFalse);
    expect(late.contains(1630), isTrue);
    expect(late.contains(1910), isTrue);
    expect(late.contains(1911), isFalse);
    expect(late.isMissed, isFalse);
  });

  test('copyWith replaces only the given fields', () {
    final changed = late.copyWith(extraDecoSeconds: 60);
    expect(changed.extraDecoSeconds, 60);
    expect(changed.copyWith(extraDecoSeconds: 120), late);
  });

  test('efficiency finds the window under a timestamp', () {
    const efficiency = GasSwitchEfficiency(
      evaluated: true,
      windows: [late],
      totalExtraDecoSeconds: 120,
    );
    expect(efficiency.windowAt(1700), late);
    expect(efficiency.windowAt(100), isNull);
    expect(GasSwitchEfficiency.notEvaluated.evaluated, isFalse);
    expect(GasSwitchEfficiency.notEvaluated.windows, isEmpty);
    expect(efficiency.copyWith(evaluated: false).evaluated, isFalse);
  });

  test('OptimalOcAscentGas exposes its gases', () {
    const air = AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66);
    const ean50 = AvailableGas(fN2: 0.5, fHe: 0, maxPpO2Mod: 22);
    final plan = OptimalOcAscentGas(gases: [air, ean50], maxPpO2: 1.6);
    expect(plan.gases, [air, ean50]);
  });

  test('withSameConfig copies configuration with fresh tissues', () {
    final engine = BuhlmannAlgorithm(
      gfLow: 0.4,
      gfHigh: 0.8,
      lastStopDepth: 6,
      stopIncrement: 3,
      ascentRate: 10,
      environment: DiveEnvironment.standard,
    )..calculateSegment(depthMeters: 40, durationSeconds: 1200);
    final copy = engine.withSameConfig();
    expect(copy.gfLow, 0.4);
    expect(copy.gfHigh, 0.8);
    expect(copy.lastStopDepth, 6);
    expect(copy.stopIncrement, 3);
    expect(copy.ascentRate, 10);
    expect(copy.environment, engine.environment);
    expect(
      copy.compartments.first.currentPN2,
      BuhlmannAlgorithm().compartments.first.currentPN2,
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/deco/gas_switch/gas_switch_efficiency_test.dart`
Expected: FAIL, `gas_switch_efficiency.dart` not found.

- [ ] **Step 3: Implement**

`lib/core/deco/gas_switch/gas_switch_efficiency.dart`:

```dart
import 'package:equatable/equatable.dart';

/// How a deco gas switch fell short of the ideal ascent (issue #2939).
enum GasSwitchWindowKind {
  /// The diver switched, but past the depth or time tolerance.
  late,

  /// The diver never breathed the gas from the window's start onward.
  missed,
}

/// One flagged stretch where a richer eligible gas was carried but not
/// breathed. Timestamps are seconds from dive start; depths are metres.
class GasSwitchWindow extends Equatable {
  const GasSwitchWindow({
    required this.kind,
    required this.fO2,
    required this.fHe,
    required this.idealTimestamp,
    required this.idealDepth,
    this.switchTimestamp,
    this.switchDepth,
    required this.endTimestamp,
    required this.delaySeconds,
    this.depthDelayMeters,
    required this.extraDecoSeconds,
  });

  final GasSwitchWindowKind kind;

  /// Mix that should have been breathed.
  final double fO2;
  final double fHe;

  /// Where the ideal ascent would have switched.
  final int idealTimestamp;
  final double idealDepth;

  /// Where the diver did switch; null when missed.
  final int? switchTimestamp;
  final double? switchDepth;

  /// Last instant of the shaded window.
  final int endTimestamp;

  final int delaySeconds;

  /// How much shallower than ideal the switch happened; null when missed.
  final double? depthDelayMeters;

  /// Largest TTS gap the late switch caused (tissue replay).
  final int extraDecoSeconds;

  bool get isMissed => kind == GasSwitchWindowKind.missed;

  bool contains(int timestamp) =>
      timestamp >= idealTimestamp && timestamp <= endTimestamp;

  GasSwitchWindow copyWith({
    GasSwitchWindowKind? kind,
    double? fO2,
    double? fHe,
    int? idealTimestamp,
    double? idealDepth,
    int? switchTimestamp,
    double? switchDepth,
    int? endTimestamp,
    int? delaySeconds,
    double? depthDelayMeters,
    int? extraDecoSeconds,
  }) {
    return GasSwitchWindow(
      kind: kind ?? this.kind,
      fO2: fO2 ?? this.fO2,
      fHe: fHe ?? this.fHe,
      idealTimestamp: idealTimestamp ?? this.idealTimestamp,
      idealDepth: idealDepth ?? this.idealDepth,
      switchTimestamp: switchTimestamp ?? this.switchTimestamp,
      switchDepth: switchDepth ?? this.switchDepth,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      depthDelayMeters: depthDelayMeters ?? this.depthDelayMeters,
      extraDecoSeconds: extraDecoSeconds ?? this.extraDecoSeconds,
    );
  }

  @override
  List<Object?> get props => [
    kind,
    fO2,
    fHe,
    idealTimestamp,
    idealDepth,
    switchTimestamp,
    switchDepth,
    endTimestamp,
    delaySeconds,
    depthDelayMeters,
    extraDecoSeconds,
  ];
}

/// Gas-switch efficiency of one open-circuit dive: a read-only comparison of
/// the gases breathed against the ideal ascent TTS already assumes.
class GasSwitchEfficiency extends Equatable {
  const GasSwitchEfficiency({
    required this.evaluated,
    this.windows = const [],
    this.totalExtraDecoSeconds = 0,
  });

  /// The dive had a deco obligation and at least one gas to assess.
  static const notEvaluated = GasSwitchEfficiency(evaluated: false);

  /// False when there was nothing to judge, so the UI can tell "all switches
  /// on time" apart from "not applicable".
  final bool evaluated;

  /// Flagged windows only, time-ordered.
  final List<GasSwitchWindow> windows;

  /// Extra deco with every flagged window fixed at once (not a sum).
  final int totalExtraDecoSeconds;

  GasSwitchWindow? windowAt(int timestamp) {
    for (final window in windows) {
      if (window.contains(timestamp)) return window;
    }
    return null;
  }

  GasSwitchEfficiency copyWith({
    bool? evaluated,
    List<GasSwitchWindow>? windows,
    int? totalExtraDecoSeconds,
  }) {
    return GasSwitchEfficiency(
      evaluated: evaluated ?? this.evaluated,
      windows: windows ?? this.windows,
      totalExtraDecoSeconds:
          totalExtraDecoSeconds ?? this.totalExtraDecoSeconds,
    );
  }

  @override
  List<Object?> get props => [evaluated, windows, totalExtraDecoSeconds];
}
```

In `OptimalOcAscentGas`, below `final double maxPpO2;`:

```dart
  /// The gases this plan chooses from, in the order given.
  List<AvailableGas> get gases => _gases;
```

In `BuhlmannAlgorithm`, below the `compartments` getter:

```dart
  /// A new engine with this one's configuration and surface-saturated
  /// tissues, for read-only replays that must decompress exactly like this
  /// engine without disturbing its state.
  BuhlmannAlgorithm withSameConfig() => BuhlmannAlgorithm(
    gfLow: gfLow,
    gfHigh: gfHigh,
    lastStopDepth: lastStopDepth,
    stopIncrement: stopIncrement,
    ascentRate: ascentRate,
    environment: environment,
  );
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/deco/gas_switch/gas_switch_efficiency_test.dart test/core/deco/ascent_gas_plan_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format lib/core/deco test/core/deco
git add lib/core/deco/gas_switch/gas_switch_efficiency.dart lib/core/deco/ascent/ascent_gas_plan.dart lib/core/deco/buhlmann_algorithm.dart test/core/deco/gas_switch/gas_switch_efficiency_test.dart
git commit -m "feat(deco): add gas-switch efficiency result types"
```

---

### Task 2: Window detector

**Files:**
- Create: `lib/core/deco/gas_switch/gas_segment_lookup.dart`
- Create: `lib/core/deco/gas_switch/gas_switch_window_detector.dart`
- Create: `test/core/deco/gas_switch/gas_switch_test_profiles.dart` (shared test helpers)
- Test: `test/core/deco/gas_switch/gas_switch_window_detector_test.dart`

**Interfaces:**
- Consumes: `AvailableGas`, `OptimalOcAscentGas` (Task 1).
- Produces:
  - `ProfileGasSegment activeSegmentAt(List<ProfileGasSegment> segments, int timestamp)`
  - `double segmentFO2(ProfileGasSegment s)`
  - `bool sameMix(double fO2a, double fHeA, double fO2b, double fHeB)`
  - `const double mixMatchTolerance = 0.005`
  - `class DetectedSwitchWindow {AvailableGas gas; int startIndex; int endIndex; int? switchIndex;}`
  - `class SwitchWindowDetection {int assessedGasCount; List<DetectedSwitchWindow> windows;}`
  - `const double modHysteresisMeters = 1.0`
  - `SwitchWindowDetection detectSwitchWindows({required List<double> depths, required List<int> timestamps, required List<ProfileGasSegment> gasSegments, required List<AvailableGas> gases, required double maxPpO2})`
  - Test helpers: `sampleProfile`, `gasOf`, `seg`, `standardDecoDive`, `indexAt`.

- [ ] **Step 1: Write the shared test helpers**

`test/core/deco/gas_switch/gas_switch_test_profiles.dart`:

```dart
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';

typedef SampledProfile = ({List<int> timestamps, List<double> depths});

/// Samples a piecewise-linear dive every [step] seconds through
/// [waypoints] (seconds, metres).
SampledProfile sampleProfile(List<(int, double)> waypoints, {int step = 10}) {
  final timestamps = <int>[];
  final depths = <double>[];
  for (var t = waypoints.first.$1; t <= waypoints.last.$1; t += step) {
    timestamps.add(t);
    depths.add(_depthAt(waypoints, t));
  }
  if (timestamps.last != waypoints.last.$1) {
    timestamps.add(waypoints.last.$1);
    depths.add(waypoints.last.$2);
  }
  return (timestamps: timestamps, depths: depths);
}

double _depthAt(List<(int, double)> waypoints, int t) {
  for (var k = 1; k < waypoints.length; k++) {
    final (t1, d1) = waypoints[k];
    if (t <= t1) {
      final (t0, d0) = waypoints[k - 1];
      return t1 == t0 ? d1 : d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
  }
  return waypoints.last.$2;
}

/// A cylinder with its MOD at [maxPpO2].
AvailableGas gasOf(double fO2, {double fHe = 0, double maxPpO2 = 1.6}) =>
    AvailableGas(
      fN2: 1 - fO2 - fHe,
      fHe: fHe,
      maxPpO2Mod: O2ToxicityCalculator.calculateMod(fO2, maxPpO2: maxPpO2),
    );

/// A recorded gas segment starting at [t].
ProfileGasSegment seg(int t, double fO2, {double fHe = 0}) =>
    ProfileGasSegment(startTimestamp: t, fN2: 1 - fO2 - fHe, fHe: fHe);

/// 25 min at 40 m, then stops at 21, 18, 15, 12, 9, 6 and 3 m. EAN50's MOD
/// (22 m at 1.6) is first reached at the 21 m stop (t = 1630); O2's (6 m)
/// at t = 2510.
const standardDecoDive = <(int, double)>[
  (0, 0),
  (120, 40),
  (1500, 40),
  (1630, 21),
  (1750, 21),
  (1770, 18),
  (1890, 18),
  (1910, 15),
  (2030, 15),
  (2050, 12),
  (2230, 12),
  (2250, 9),
  (2490, 9),
  (2510, 6),
  (3110, 6),
  (3130, 3),
  (3730, 3),
  (3750, 0),
];

int indexAt(SampledProfile profile, int timestamp) =>
    profile.timestamps.indexOf(timestamp);
```

- [ ] **Step 2: Write the failing detector tests**

`test/core/deco/gas_switch/gas_switch_window_detector_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final air = gasOf(0.21);
  final ean50 = gasOf(0.5);
  final o2 = gasOf(1.0);

  SwitchWindowDetection detect(
    List<ProfileGasSegment> segments, {
    SampledProfile? profile,
  }) {
    final p = profile ?? dive;
    return detectSwitchWindows(
      depths: p.depths,
      timestamps: p.timestamps,
      gasSegments: segments,
      gases: [air, ean50, o2],
      maxPpO2: 1.6,
    );
  }

  test('activeSegmentAt mirrors the engine lookup', () {
    final segments = [seg(0, 0.21), seg(100, 0.5)];
    expect(segmentFO2(activeSegmentAt(segments, 0)), closeTo(0.21, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, 99)), closeTo(0.21, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, 100)), closeTo(0.5, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, -5)), closeTo(0.21, 1e-9));
  });

  test('air segment matches an air cylinder (0.7902 vs 0.79)', () {
    const recordedAir = ProfileGasSegment(startTimestamp: 0, fN2: 0.7902);
    expect(sameMix(segmentFO2(recordedAir), 0, air.fO2, air.fHe), isTrue);
    expect(sameMix(0.32, 0, 0.36, 0), isFalse);
  });

  test('on-time switches produce windows that end at the switch', () {
    final result = detect([seg(0, 0.21), seg(1690, 0.5), seg(2540, 1.0)]);
    expect(result.assessedGasCount, 2); // EAN50 and O2; air never deeper than 67 m
    expect(result.windows, hasLength(2));
    final first = result.windows.first;
    expect(first.gas, same(ean50));
    expect(dive.timestamps[first.startIndex], 1630);
    expect(dive.timestamps[first.switchIndex!], 1690);
    expect(first.endIndex, first.switchIndex);
    final second = result.windows.last;
    expect(second.gas, same(o2));
    expect(dive.timestamps[second.startIndex], 2510);
    expect(dive.timestamps[second.switchIndex!], 2540);
  });

  test('a gas never switched to is a window with no switch', () {
    final result = detect([seg(0, 0.21)]);
    final ean = result.windows.firstWhere((w) => identical(w.gas, ean50));
    expect(ean.switchIndex, isNull);
    // Ends where O2 becomes the ideal gas.
    expect(dive.timestamps[ean.endIndex], 2510);
    final oxygen = result.windows.firstWhere((w) => identical(w.gas, o2));
    expect(oxygen.switchIndex, isNull);
    expect(oxygen.endIndex, dive.timestamps.length - 1);
  });

  test('skipping EAN50 straight to O2 leaves EAN50 without a switch', () {
    final result = detect([seg(0, 0.21), seg(2540, 1.0)]);
    final ean = result.windows.firstWhere((w) => identical(w.gas, ean50));
    expect(ean.switchIndex, isNull);
    final oxygen = result.windows.firstWhere((w) => identical(w.gas, o2));
    expect(dive.timestamps[oxygen.switchIndex!], 2540);
  });

  test('a mid-dive excursion above the MOD opens no early window', () {
    final profile = sampleProfile([
      (0, 0),
      (120, 40),
      (600, 40),
      (720, 15),
      (1020, 15),
      (1140, 40),
      ...standardDecoDive.skip(2),
    ]);
    final result = detect([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
    ], profile: profile);
    expect(result.windows, isNotEmpty);
    for (final window in result.windows) {
      expect(profile.timestamps[window.startIndex], greaterThanOrEqualTo(1630));
    }
  });

  test('a gas the dive never took below its MOD is not assessed', () {
    final result = detect(
      [seg(0, 0.21)],
      profile: sampleProfile([
        (0, 0),
        (60, 20),
        (5400, 20),
        (5460, 6),
        (6060, 6),
        (6080, 3),
        (6680, 3),
        (6700, 0),
      ]),
    );
    // EAN50 (MOD 22 m) never had depth > 23 m. O2 (MOD 6 m) did.
    expect(result.windows.where((w) => identical(w.gas, ean50)), isEmpty);
  });

  test('air breaks after an on-time O2 switch open no window', () {
    final result = detect([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
      seg(2780, 0.21),
      seg(3080, 1.0),
    ]);
    expect(result.windows, hasLength(2)); // only the two on-time switches
    expect(
      result.windows.every((w) => w.switchIndex == w.endIndex),
      isTrue,
    );
  });

  test('identical-mix switches (sidemount) open no window', () {
    final result = detectSwitchWindows(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: [seg(0, 0.32), seg(900, 0.32), seg(1690, 0.5)],
      gases: [gasOf(0.32), ean50],
      maxPpO2: 1.6,
    );
    expect(result.windows, hasLength(1));
    expect(result.windows.single.gas, same(ean50));
  });

  test('a switch to a gas outside the plan opens no window of its own', () {
    final result = detectSwitchWindows(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: [seg(0, 0.21), seg(1200, 0.32), seg(1690, 0.5)],
      gases: [air, ean50],
      maxPpO2: 1.6,
    );
    expect(result.windows, hasLength(1));
    expect(result.windows.single.gas, same(ean50));
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/deco/gas_switch/gas_switch_window_detector_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 4: Implement `gas_segment_lookup.dart`**

```dart
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// Mixes closer than this in both fO2 and fHe are the same gas. Recorded air
/// segments carry airN2Fraction (0.7902) while cylinders derive 0.79, and
/// real mixes differ by at least a percent.
const double mixMatchTolerance = 0.005;

/// The recorded segment active at [timestamp]: the last one starting at or
/// before it, else the first. Mirrors BuhlmannAlgorithm's own lookup so a
/// replay breathes exactly what the analysis breathed.
ProfileGasSegment activeSegmentAt(
  List<ProfileGasSegment> segments,
  int timestamp,
) {
  var active = segments.first;
  for (final segment in segments) {
    if (segment.startTimestamp <= timestamp) {
      active = segment;
    } else {
      break;
    }
  }
  return active;
}

double segmentFO2(ProfileGasSegment segment) =>
    1.0 - segment.fN2 - segment.fHe;

bool sameMix(double fO2a, double fHeA, double fO2b, double fHeB) =>
    (fO2a - fO2b).abs() <= mixMatchTolerance &&
    (fHeA - fHeB).abs() <= mixMatchTolerance;
```

- [ ] **Step 5: Implement `gas_switch_window_detector.dart`**

```dart
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';

/// Depth below a gas's MOD that a sample must exceed to count as "deeper than
/// the MOD": absorbs waves and sensor noise at a stop near the MOD.
const double modHysteresisMeters = 1.0;

/// A stretch where a richer eligible gas was carried but not breathed, before
/// the tolerance and obligation rules decide whether it is flagged.
class DetectedSwitchWindow {
  const DetectedSwitchWindow({
    required this.gas,
    required this.startIndex,
    required this.endIndex,
    this.switchIndex,
  });

  /// The gas the ideal ascent would have been breathing.
  final AvailableGas gas;

  /// First behind sample.
  final int startIndex;

  /// Sample at which the window stopped: the switch, a richer ideal gas taking
  /// over, or the last sample.
  final int endIndex;

  /// First sample from [startIndex] onward that breathes [gas]; null when the
  /// diver never did (a missed switch).
  final int? switchIndex;
}

class SwitchWindowDetection {
  const SwitchWindowDetection({
    required this.assessedGasCount,
    required this.windows,
  });

  /// Gases the dive took deeper than their MOD and then ascended past.
  final int assessedGasCount;
  final List<DetectedSwitchWindow> windows;
}

/// Compares the gas breathed at each sample with the gas the ideal ascent
/// (OptimalOcAscentGas over the gases already eligible) would breathe there.
///
/// A gas is assessed only once the dive has been deeper than its MOD plus
/// [modHysteresisMeters]; it becomes eligible from the first sample after the
/// last such sample, so a mid-dive excursion never opens a window. A sample is
/// behind when the ideal gas is richer than the breathed one and the diver has
/// not breathed the ideal gas since it became eligible: a return to a leaner
/// gas after switching is an air break, not a late switch.
SwitchWindowDetection detectSwitchWindows({
  required List<double> depths,
  required List<int> timestamps,
  required List<ProfileGasSegment> gasSegments,
  required List<AvailableGas> gases,
  required double maxPpO2,
}) {
  final n = depths.length;
  final idealIndex = <int, int>{};
  for (var g = 0; g < gases.length; g++) {
    final threshold = gases[g].maxPpO2Mod + modHysteresisMeters;
    final lastDeep = depths.lastIndexWhere((d) => d > threshold);
    if (lastDeep < 0 || lastDeep + 1 >= n) continue;
    idealIndex[g] = lastDeep + 1;
  }
  if (idealIndex.isEmpty) {
    return const SwitchWindowDetection(assessedGasCount: 0, windows: []);
  }

  final actual = [
    for (var i = 0; i < n; i++) activeSegmentAt(gasSegments, timestamps[i]),
  ];
  bool breathes(int i, AvailableGas gas) =>
      sameMix(segmentFO2(actual[i]), actual[i].fHe, gas.fO2, gas.fHe);

  final breathedSinceIdeal = <int>{};
  final windows = <DetectedSwitchWindow>[];
  int? openGas;
  var openStart = 0;

  void close(int endIndex) {
    final gas = gases[openGas!];
    int? switchIndex;
    for (var k = openStart; k < n; k++) {
      if (breathes(k, gas)) {
        switchIndex = k;
        break;
      }
    }
    windows.add(
      DetectedSwitchWindow(
        gas: gas,
        startIndex: openStart,
        endIndex: endIndex,
        switchIndex: switchIndex,
      ),
    );
    openGas = null;
  }

  for (var i = 0; i < n; i++) {
    for (final entry in idealIndex.entries) {
      if (entry.value <= i && breathes(i, gases[entry.key])) {
        breathedSinceIdeal.add(entry.key);
      }
    }
    final ideal = _idealGasIndex(i, depths[i], gases, idealIndex, maxPpO2);
    final behind =
        ideal != null &&
        !breathedSinceIdeal.contains(ideal) &&
        gases[ideal].fO2 > segmentFO2(actual[i]) + mixMatchTolerance;
    if (behind && ideal == openGas) continue;
    if (openGas != null) close(i);
    if (behind) {
      openGas = ideal;
      openStart = i;
    }
  }
  if (openGas != null) close(n - 1);

  return SwitchWindowDetection(
    assessedGasCount: idealIndex.length,
    windows: windows,
  );
}

/// Index into [gases] of the ideal gas at sample [i], or null when no
/// assessed gas is eligible there (none past its ideal index and at or above
/// its MOD).
int? _idealGasIndex(
  int i,
  double depth,
  List<AvailableGas> gases,
  Map<int, int> idealIndex,
  double maxPpO2,
) {
  final eligible = [
    for (final entry in idealIndex.entries)
      if (entry.value <= i && depth <= gases[entry.key].maxPpO2Mod + 1e-9)
        entry.key,
  ];
  if (eligible.isEmpty) return null;
  final pick = OptimalOcAscentGas(
    gases: [for (final g in eligible) gases[g]],
    maxPpO2: maxPpO2,
  ).gasForDepth(depth);
  for (final g in eligible) {
    if (gases[g].fN2 == pick.fN2 && gases[g].fHe == pick.fHe) return g;
  }
  return eligible.first;
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/core/deco/gas_switch/gas_switch_window_detector_test.dart`
Expected: PASS. If `assessedGasCount` differs because air's MOD at 1.6 (66.2 m) is never exceeded, that is the intended reading; keep the assertion at 2.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/deco/gas_switch test/core/deco/gas_switch
git add lib/core/deco/gas_switch/gas_segment_lookup.dart lib/core/deco/gas_switch/gas_switch_window_detector.dart test/core/deco/gas_switch/gas_switch_test_profiles.dart test/core/deco/gas_switch/gas_switch_window_detector_test.dart
git commit -m "feat(deco): detect late and missed deco gas switch windows"
```

---

### Task 3: On-time gas schedule and tissue replay

**Files:**
- Create: `lib/core/deco/gas_switch/on_time_gas_schedule.dart`
- Create: `lib/core/deco/gas_switch/tissue_replay.dart`
- Test: `test/core/deco/gas_switch/on_time_gas_schedule_test.dart`
- Test: `test/core/deco/gas_switch/tissue_replay_test.dart`

**Interfaces:**
- Consumes: `DetectedSwitchWindow`, `activeSegmentAt` (Task 2); `BuhlmannAlgorithm.withSameConfig`, `OptimalOcAscentGas` (Task 1).
- Produces:
  - `List<ProfileGasSegment> withSwitchesOnTime(List<ProfileGasSegment> recorded, List<DetectedSwitchWindow> windows, List<int> timestamps)`
  - `class TissueReplay({required BuhlmannAlgorithm Function() newEngine, required List<double> depths, required List<int> timestamps, required AscentGasPlan ascentPlan, List<TissueCompartment>? startCompartments})`
  - `int TissueReplay.peakTtsGap({required List<ProfileGasSegment> actual, required List<ProfileGasSegment> counterfactual, required int fromIndex, int? mustEvaluateIndex})`
  - `@visibleForTesting BuhlmannAlgorithm TissueReplay.replayThrough(List<ProfileGasSegment> segments, int index)`
  - `static const int TissueReplay.evaluationStrideSeconds = 30`

- [ ] **Step 1: Write the failing schedule tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final ean50 = gasOf(0.5);

  /// Start timestamps, and fO2 in whole percent (rounded, so air's 0.79 vs
  /// 0.7902 cannot make the comparison flaky).
  (List<int>, List<int>) shape(List<ProfileGasSegment> segments) => (
    [for (final s in segments) s.startTimestamp],
    [for (final s in segments) (segmentFO2(s) * 100).round()],
  );

  test('a late switch moves to the ideal time and keeps the recorded one', () {
    final window = DetectedSwitchWindow(
      gas: ean50,
      startIndex: indexAt(dive, 1630),
      endIndex: indexAt(dive, 1910),
      switchIndex: indexAt(dive, 1910),
    );
    final result = withSwitchesOnTime(
      [seg(0, 0.21), seg(1905, 0.5)],
      [window],
      dive.timestamps,
    );
    // The switch at 1905 lies inside the window and is replaced; the gas
    // then resumes at the window end.
    expect(shape(result).$1, [0, 1630, 1910]);
    expect(shape(result).$2, [21, 50, 50]);
  });

  test('a missed window resumes the recorded gas at its end', () {
    final window = DetectedSwitchWindow(
      gas: ean50,
      startIndex: indexAt(dive, 1630),
      endIndex: indexAt(dive, 2510),
    );
    final result = withSwitchesOnTime(
      [seg(0, 0.21), seg(2540, 1.0)],
      [window],
      dive.timestamps,
    );
    expect(shape(result).$1, [0, 1630, 2510, 2540]);
    expect(shape(result).$2, [21, 50, 21, 100]);
  });

  test('no windows leaves the schedule untouched', () {
    final recorded = [seg(0, 0.21), seg(1690, 0.5)];
    expect(withSwitchesOnTime(recorded, const [], dive.timestamps), recorded);
  });
}
```

The lists are asserted separately on purpose: a record holding a `List` compares by identity in `expect()`.

- [ ] **Step 2: Write the failing replay tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';
import 'package:submersion/core/deco/gas_switch/tissue_replay.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final gases = [gasOf(0.21), gasOf(0.5), gasOf(1.0)];
  final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
  BuhlmannAlgorithm newEngine() => BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7);

  TissueReplay replay({List<TissueCompartment>? startCompartments}) =>
      TissueReplay(
        newEngine: newEngine,
        depths: dive.depths,
        timestamps: dive.timestamps,
        ascentPlan: plan,
        startCompartments: startCompartments,
      );

  void expectSameTissues(BuhlmannAlgorithm a, List<TissueCompartment> b) {
    for (var k = 0; k < b.length; k++) {
      expect(a.compartments[k].currentPN2, closeTo(b[k].currentPN2, 1e-12));
      expect(a.compartments[k].currentPHe, closeTo(b[k].currentPHe, 1e-12));
    }
  }

  test('replay loads tissues exactly like the analysis engine', () {
    final segments = [seg(0, 0.21), seg(1695, 0.5), seg(2545, 1.0)];
    final statuses = newEngine().processProfileWithGasSegments(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: segments,
      ascentGasPlan: plan,
    );
    final replayed = replay().replayThrough(segments, dive.depths.length - 1);
    expectSameTissues(replayed, statuses.last.compartments);
  });

  test('replay seeds residual tissues like the analysis', () {
    final residual = (newEngine()
          ..calculateSegment(depthMeters: 30, durationSeconds: 1800))
        .compartments;
    final segments = [seg(0, 0.21), seg(1695, 0.5)];
    final engine = newEngine()..setCompartments(residual);
    final statuses = engine.processProfileWithGasSegments(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: segments,
      ascentGasPlan: plan,
    );
    final replayed = replay(
      startCompartments: residual,
    ).replayThrough(segments, dive.depths.length - 1);
    expectSameTissues(replayed, statuses.last.compartments);
  });

  test('identical schedules have no gap', () {
    final segments = [seg(0, 0.21), seg(1690, 0.5)];
    expect(
      replay().peakTtsGap(
        actual: segments,
        counterfactual: segments,
        fromIndex: indexAt(dive, 1630),
      ),
      0,
    );
  });

  test('a late EAN50 switch costs deco, a missed one costs more', () {
    final start = indexAt(dive, 1630);
    int costOf(
      List<ProfileGasSegment> recorded,
      int endIndex,
      int? switchIndex,
    ) {
      final window = DetectedSwitchWindow(
        gas: gases[1],
        startIndex: start,
        endIndex: endIndex,
        switchIndex: switchIndex,
      );
      return replay().peakTtsGap(
        actual: recorded,
        counterfactual: withSwitchesOnTime(
          recorded,
          [window],
          dive.timestamps,
        ),
        fromIndex: start,
        mustEvaluateIndex: endIndex,
      );
    }

    final lateCost = costOf(
      [seg(0, 0.21), seg(1910, 0.5)],
      indexAt(dive, 1910),
      indexAt(dive, 1910),
    );
    final missedCost = costOf(
      [seg(0, 0.21)],
      dive.depths.length - 1,
      null,
    );
    expect(lateCost, greaterThan(0));
    expect(missedCost, greaterThan(lateCost));
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/deco/gas_switch/on_time_gas_schedule_test.dart test/core/deco/gas_switch/tissue_replay_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 4: Implement `on_time_gas_schedule.dart`**

```dart
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';

/// The recorded gas schedule as it would have been had the diver switched on
/// time in every window of [windows]: each window breathes its gas from its
/// first sample, any recorded switch inside it is dropped, and the recorded
/// gas resumes at the window's last sample. Everything outside the windows is
/// as dived.
List<ProfileGasSegment> withSwitchesOnTime(
  List<ProfileGasSegment> recorded,
  List<DetectedSwitchWindow> windows,
  List<int> timestamps,
) {
  var result = [...recorded];
  for (final window in windows) {
    final startTs = timestamps[window.startIndex];
    final endTs = timestamps[window.endIndex];
    final resume = activeSegmentAt(recorded, endTs);
    final kept = [
      for (final s in result)
        if (s.startTimestamp < startTs || s.startTimestamp >= endTs) s,
    ];
    result = [
      ...kept,
      ProfileGasSegment(
        startTimestamp: startTs,
        fN2: window.gas.fN2,
        fHe: window.gas.fHe,
      ),
      if (endTs > startTs && !kept.any((s) => s.startTimestamp == endTs))
        ProfileGasSegment(
          startTimestamp: endTs,
          fN2: resume.fN2,
          fHe: resume.fHe,
        ),
    ]..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
  }
  return result;
}
```

- [ ] **Step 5: Implement `tissue_replay.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';

/// Replays a recorded depth trace on fresh engines so two gas schedules can be
/// compared without touching the analysis engine.
///
/// Interval loading mirrors BuhlmannAlgorithm.processProfileWithGasSegments
/// (split at every switch inside an interval, linear depth, average depth per
/// sub-interval); a parity test pins the two together. The replay restarts
/// from the dive start because DecoStatus does not store the GF-low anchor.
class TissueReplay {
  TissueReplay({
    required this.newEngine,
    required this.depths,
    required this.timestamps,
    required this.ascentPlan,
    this.startCompartments,
  });

  /// TTS is compared every this many seconds of dive time.
  static const int evaluationStrideSeconds = 30;

  final BuhlmannAlgorithm Function() newEngine;
  final List<double> depths;
  final List<int> timestamps;
  final AscentGasPlan ascentPlan;
  final List<TissueCompartment>? startCompartments;

  /// The engine after loading samples 1..[index] with [segments].
  @visibleForTesting
  BuhlmannAlgorithm replayThrough(List<ProfileGasSegment> segments, int index) {
    final engine = _seeded();
    for (var i = 1; i <= index; i++) {
      _loadInterval(engine, i, segments);
    }
    return engine;
  }

  /// Largest `TTS(actual) - TTS(counterfactual)` from [fromIndex] to the end
  /// of the dive, evaluated every [evaluationStrideSeconds] and at
  /// [mustEvaluateIndex]; floored at zero.
  int peakTtsGap({
    required List<ProfileGasSegment> actual,
    required List<ProfileGasSegment> counterfactual,
    required int fromIndex,
    int? mustEvaluateIndex,
  }) {
    final a = _seeded();
    final c = _seeded();
    var peak = 0;
    int? lastEvaluated;
    for (var i = 0; i < depths.length; i++) {
      if (i > 0) {
        _loadInterval(a, i, actual);
        _loadInterval(c, i, counterfactual);
      }
      if (i < fromIndex) continue;
      final due =
          lastEvaluated == null ||
          timestamps[i] - lastEvaluated >= evaluationStrideSeconds ||
          i == mustEvaluateIndex;
      if (!due) continue;
      lastEvaluated = timestamps[i];
      final gap = _tts(a, i, actual) - _tts(c, i, counterfactual);
      if (gap > peak) peak = gap;
    }
    return peak;
  }

  BuhlmannAlgorithm _seeded() {
    final engine = newEngine();
    final start = startCompartments;
    if (start != null) engine.setCompartments(start);
    return engine;
  }

  int _tts(BuhlmannAlgorithm engine, int i, List<ProfileGasSegment> segments) {
    final gas = activeSegmentAt(segments, timestamps[i]);
    final scratch = newEngine()
      ..restoreState(
        engine.compartments,
        gfLowCeilingAnchor: engine.gfLowCeilingAnchor,
      );
    return scratch
        .getDecoStatus(
          currentDepth: depths[i],
          fN2: gas.fN2,
          fHe: gas.fHe,
          ascentGas: ascentPlan,
        )
        .ttsSeconds;
  }

  void _loadInterval(
    BuhlmannAlgorithm engine,
    int i,
    List<ProfileGasSegment> segments,
  ) {
    final start = timestamps[i - 1];
    final end = timestamps[i];
    final boundaries = <int>[
      start,
      for (final s in segments)
        if (s.startTimestamp > start && s.startTimestamp < end)
          s.startTimestamp,
      end,
    ];
    for (var b = 1; b < boundaries.length; b++) {
      final subStart = boundaries[b - 1];
      final subEnd = boundaries[b];
      final avgDepth = (_depthAt(i, subStart) + _depthAt(i, subEnd)) / 2.0;
      final gas = activeSegmentAt(segments, subStart);
      engine.calculateSegment(
        depthMeters: avgDepth,
        durationSeconds: subEnd - subStart,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
    }
  }

  double _depthAt(int i, int t) {
    final t0 = timestamps[i - 1];
    final t1 = timestamps[i];
    if (t1 == t0) return depths[i];
    return depths[i - 1] + (depths[i] - depths[i - 1]) * ((t - t0) / (t1 - t0));
  }
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/core/deco/gas_switch/`
Expected: PASS. If the parity test fails, diff the loop against `processProfileWithGasSegments` (lib/core/deco/buhlmann_algorithm.dart:1010) and fix the replay, never the engine.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/deco/gas_switch test/core/deco/gas_switch
git add lib/core/deco/gas_switch/on_time_gas_schedule.dart lib/core/deco/gas_switch/tissue_replay.dart test/core/deco/gas_switch/on_time_gas_schedule_test.dart test/core/deco/gas_switch/tissue_replay_test.dart
git commit -m "feat(deco): replay tissues to cost late gas switches"
```

---

### Task 4: Analyzer (flag rule, costs, evaluated)

**Files:**
- Create: `lib/core/deco/gas_switch/gas_switch_efficiency_analyzer.dart`
- Test: `test/core/deco/gas_switch/gas_switch_efficiency_analyzer_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `class GasSwitchEfficiencyAnalyzer({required BuhlmannAlgorithm Function() newEngine, required List<AvailableGas> gases, required double maxPpO2, List<TissueCompartment>? startCompartments})` with `static const int timeToleranceSeconds = 120` and `GasSwitchEfficiency? analyze({required List<double> depths, required List<int> timestamps, required List<ProfileGasSegment> gasSegments, required List<double> ceilingCurve})`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency_analyzer.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  BuhlmannAlgorithm newEngine() => BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7);
  final air = gasOf(0.21);
  final ean50 = gasOf(0.5);
  final o2 = gasOf(1.0);

  GasSwitchEfficiency? run(
    List<ProfileGasSegment> segments, {
    List<(int, double)> waypoints = standardDecoDive,
    List<AvailableGas>? gases,
  }) {
    final profile = sampleProfile(waypoints);
    final available = gases ?? [air, ean50, o2];
    final plan = OptimalOcAscentGas(gases: available, maxPpO2: 1.6);
    final ceilings = newEngine()
        .processProfileWithGasSegments(
          depths: profile.depths,
          timestamps: profile.timestamps,
          gasSegments: segments,
          ascentGasPlan: plan,
        )
        .map((s) => s.ceilingMeters)
        .toList();
    return GasSwitchEfficiencyAnalyzer(
      newEngine: newEngine,
      gases: available,
      maxPpO2: 1.6,
    ).analyze(
      depths: profile.depths,
      timestamps: profile.timestamps,
      gasSegments: segments,
      ceilingCurve: ceilings,
    );
  }

  test('fewer than two gases is not applicable', () {
    expect(run([seg(0, 0.21)], gases: [air]), isNull);
  });

  test('on-time switches are evaluated with nothing flagged', () {
    final result = run([seg(0, 0.21), seg(1690, 0.5), seg(2540, 1.0)])!;
    expect(result.evaluated, isTrue);
    expect(result.windows, isEmpty);
    expect(result.totalExtraDecoSeconds, 0);
  });

  test('a switch 6 m shallower than ideal is late by depth', () {
    final result = run([seg(0, 0.21), seg(1910, 0.5), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.late);
    expect(window.fO2, closeTo(0.5, 1e-9));
    expect(window.idealTimestamp, 1630);
    expect(window.idealDepth, closeTo(21, 1e-9));
    expect(window.switchTimestamp, 1910);
    expect(window.switchDepth, closeTo(15, 1e-9));
    expect(window.depthDelayMeters, closeTo(6, 1e-9));
    expect(window.delaySeconds, 280);
    expect(window.extraDecoSeconds, greaterThan(0));
    expect(result.totalExtraDecoSeconds, window.extraDecoSeconds);
  });

  test('a switch 130 s after the ideal time is late by time', () {
    final result = run([seg(0, 0.21), seg(1760, 0.5), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.late);
    expect(window.delaySeconds, 130);
    expect(window.depthDelayMeters, lessThanOrEqualTo(3));
  });

  test('120 s at the stop is inside the tolerance', () {
    final result = run([seg(0, 0.21), seg(1750, 0.5), seg(2540, 1.0)])!;
    expect(result.windows, isEmpty);
  });

  test('a never-breathed gas is missed', () {
    final result = run([seg(0, 0.21), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.missed);
    expect(window.switchTimestamp, isNull);
    expect(window.switchDepth, isNull);
    expect(window.depthDelayMeters, isNull);
    expect(window.endTimestamp, 2510);
    expect(window.delaySeconds, 2510 - 1630);
    expect(window.extraDecoSeconds, greaterThan(0));
  });

  test('two flagged windows: total is positive and at most the sum', () {
    final result = run([seg(0, 0.21), seg(1910, 0.5), seg(2700, 1.0)])!;
    expect(result.windows, hasLength(2));
    final sum = result.windows.fold<int>(0, (s, w) => s + w.extraDecoSeconds);
    expect(result.totalExtraDecoSeconds, greaterThan(0));
    expect(result.totalExtraDecoSeconds, lessThanOrEqualTo(sum));
  });

  test('a no-deco dive is not evaluated', () {
    final result = run(
      [seg(0, 0.21)],
      waypoints: [(0, 0), (60, 26), (540, 26), (720, 5), (900, 5), (930, 0)],
      gases: [air, ean50],
    )!;
    expect(result.evaluated, isFalse);
    expect(result.windows, isEmpty);
  });

  test('a deco dive that never went below any MOD is not evaluated', () {
    final result = run(
      [seg(0, 0.21)],
      waypoints: [
        (0, 0),
        (60, 20),
        (5400, 20),
        (5460, 9),
        (5700, 9),
        (5720, 6),
        (6320, 6),
        (6340, 3),
        (6940, 3),
        (6960, 0),
      ],
      gases: [air, ean50],
    )!;
    expect(result.evaluated, isFalse);
  });

  test('air breaks on O2 are not flagged', () {
    final result = run([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
      seg(2780, 0.21),
      seg(3080, 1.0),
    ])!;
    expect(result.windows, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/deco/gas_switch/gas_switch_efficiency_analyzer_test.dart`
Expected: FAIL, analyzer not found.

- [ ] **Step 3: Implement**

```dart
import 'dart:math' as math;

import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';
import 'package:submersion/core/deco/gas_switch/tissue_replay.dart';

/// Gas-switch efficiency of an open-circuit dive (issue #2939): late and
/// missed deco gas switches against the same ideal ascent TTS assumes, each
/// costed by tissue replay. Read-only: it runs on its own engines.
class GasSwitchEfficiencyAnalyzer {
  GasSwitchEfficiencyAnalyzer({
    required this.newEngine,
    required this.gases,
    required this.maxPpO2,
    this.startCompartments,
  });

  /// A switch this long after the ideal time is late, whatever the depth.
  static const int timeToleranceSeconds = 120;

  final BuhlmannAlgorithm Function() newEngine;
  final List<AvailableGas> gases;
  final double maxPpO2;
  final List<TissueCompartment>? startCompartments;

  /// Null when not applicable (fewer than two gases, no samples, or a
  /// ceiling curve that does not match the profile).
  GasSwitchEfficiency? analyze({
    required List<double> depths,
    required List<int> timestamps,
    required List<ProfileGasSegment> gasSegments,
    required List<double> ceilingCurve,
  }) {
    if (gases.length < 2 ||
        depths.length < 2 ||
        gasSegments.isEmpty ||
        ceilingCurve.length != depths.length) {
      return null;
    }
    if (!ceilingCurve.any((c) => c > 0)) {
      return GasSwitchEfficiency.notEvaluated;
    }
    final detection = detectSwitchWindows(
      depths: depths,
      timestamps: timestamps,
      gasSegments: gasSegments,
      gases: gases,
      maxPpO2: maxPpO2,
    );
    if (detection.assessedGasCount == 0) {
      return GasSwitchEfficiency.notEvaluated;
    }

    final stopIncrement = newEngine().stopIncrement;
    final flagged = [
      for (final w in detection.windows)
        if (_hadObligation(w, ceilingCurve) &&
            _isFault(w, depths, timestamps, stopIncrement))
          w,
    ];
    if (flagged.isEmpty) return const GasSwitchEfficiency(evaluated: true);

    final replay = TissueReplay(
      newEngine: newEngine,
      depths: depths,
      timestamps: timestamps,
      ascentPlan: OptimalOcAscentGas(gases: gases, maxPpO2: maxPpO2),
      startCompartments: startCompartments,
    );
    final windows = [
      for (final w in flagged)
        _toWindow(
          w,
          depths,
          timestamps,
          replay.peakTtsGap(
            actual: gasSegments,
            counterfactual: withSwitchesOnTime(gasSegments, [w], timestamps),
            fromIndex: w.startIndex,
            mustEvaluateIndex: w.endIndex,
          ),
        ),
    ];
    final total = flagged.length == 1
        ? windows.single.extraDecoSeconds
        : replay.peakTtsGap(
            actual: gasSegments,
            counterfactual: withSwitchesOnTime(
              gasSegments,
              flagged,
              timestamps,
            ),
            fromIndex: flagged.first.startIndex,
          );
    return GasSwitchEfficiency(
      evaluated: true,
      windows: windows,
      totalExtraDecoSeconds: total,
    );
  }

  bool _hadObligation(DetectedSwitchWindow w, List<double> ceilingCurve) {
    for (var k = w.startIndex; k <= w.endIndex; k++) {
      if (ceilingCurve[k] > 0) return true;
    }
    return false;
  }

  bool _isFault(
    DetectedSwitchWindow w,
    List<double> depths,
    List<int> timestamps,
    double stopIncrement,
  ) {
    final switchIndex = w.switchIndex;
    if (switchIndex == null) return true;
    final depthDelay = _idealDepth(w, depths) - depths[switchIndex];
    final timeDelay = timestamps[switchIndex] - timestamps[w.startIndex];
    return depthDelay > stopIncrement + 1e-9 ||
        timeDelay > timeToleranceSeconds;
  }

  double _idealDepth(DetectedSwitchWindow w, List<double> depths) =>
      math.min(w.gas.maxPpO2Mod, depths[w.startIndex]);

  GasSwitchWindow _toWindow(
    DetectedSwitchWindow w,
    List<double> depths,
    List<int> timestamps,
    int extraDecoSeconds,
  ) {
    final switchIndex = w.switchIndex;
    final idealTimestamp = timestamps[w.startIndex];
    final idealDepth = _idealDepth(w, depths);
    final endTimestamp = timestamps[w.endIndex];
    final switchTimestamp = switchIndex == null
        ? null
        : timestamps[switchIndex];
    return GasSwitchWindow(
      kind: switchIndex == null
          ? GasSwitchWindowKind.missed
          : GasSwitchWindowKind.late,
      fO2: w.gas.fO2,
      fHe: w.gas.fHe,
      idealTimestamp: idealTimestamp,
      idealDepth: idealDepth,
      switchTimestamp: switchTimestamp,
      switchDepth: switchIndex == null ? null : depths[switchIndex],
      endTimestamp: endTimestamp,
      delaySeconds: (switchTimestamp ?? endTimestamp) - idealTimestamp,
      depthDelayMeters: switchIndex == null
          ? null
          : idealDepth - depths[switchIndex],
      extraDecoSeconds: extraDecoSeconds,
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/deco/gas_switch/`
Expected: PASS. If "no-deco dive is not evaluated" fails because the 26 m / 8 min dive carries a ceiling at GF 70, shorten the bottom to 6 min (waypoint (420, 26)) rather than change the rule.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/deco/gas_switch test/core/deco/gas_switch
git add lib/core/deco/gas_switch/gas_switch_efficiency_analyzer.dart test/core/deco/gas_switch/gas_switch_efficiency_analyzer_test.dart
git commit -m "feat(deco): flag and cost late gas switches against the ideal ascent"
```

---

### Task 5: Wire into ProfileAnalysis

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (class `ProfileAnalysis` ~:212-540; `analyze` ~:740-1075)
- Test: `test/features/dive_log/data/services/profile_analysis_gas_switch_test.dart`

**Interfaces:**
- Consumes: `GasSwitchEfficiencyAnalyzer`, `OptimalOcAscentGas.gases`, `BuhlmannAlgorithm.withSameConfig`.
- Produces: `ProfileAnalysis.gasSwitchEfficiency` (`GasSwitchEfficiency?`), constructor and `copyWith` parameter of the same name.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

import '../../../../core/deco/gas_switch/gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final gases = [gasOf(0.21), gasOf(0.5), gasOf(1.0)];
  final lateSegments = [seg(0, 0.21), seg(1910, 0.5), seg(2540, 1.0)];

  ProfileAnalysis analyze({AscentGasPlan? plan, DiveMode mode = DiveMode.oc}) =>
      ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7).analyze(
        diveId: 'd1',
        depths: dive.depths,
        timestamps: dive.timestamps,
        gasSegments: lateSegments,
        ascentGasPlan: plan,
        diveMode: mode,
      );

  test('an OC multi-gas dive carries its gas-switch efficiency', () {
    final analysis = analyze(
      plan: OptimalOcAscentGas(gases: gases, maxPpO2: 1.6),
    );
    final efficiency = analysis.gasSwitchEfficiency!;
    expect(efficiency.evaluated, isTrue);
    expect(efficiency.windows.single.kind, GasSwitchWindowKind.late);
  });

  test('no optimal plan means no efficiency', () {
    expect(analyze().gasSwitchEfficiency, isNull);
  });

  test('every deco value matches the engine run alone', () {
    final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
    final analysis = analyze(plan: plan);
    final statuses = BuhlmannAlgorithm(
      gfLow: 0.3,
      gfHigh: 0.7,
    ).processProfileWithGasSegments(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: lateSegments,
      ascentGasPlan: plan,
    );
    expect(analysis.ttsCurve, statuses.map((s) => s.ttsSeconds).toList());
    expect(analysis.ceilingCurve, statuses.map((s) => s.ceilingMeters).toList());
    expect(analysis.ndlCurve, statuses.map((s) => s.ndlSeconds).toList());
  });

  test('copyWith carries the field', () {
    const efficiency = GasSwitchEfficiency(evaluated: true);
    final copy = ProfileAnalysis.empty().copyWith(
      gasSwitchEfficiency: efficiency,
    );
    expect(copy.gasSwitchEfficiency, efficiency);
    expect(copy.copyWith().gasSwitchEfficiency, efficiency);
    expect(ProfileAnalysis.empty().gasSwitchEfficiency, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_gas_switch_test.dart`
Expected: FAIL, `gasSwitchEfficiency` undefined.

- [ ] **Step 3: Implement**

In `ProfileAnalysis`:
- Add the import `package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart` and, for the wiring, `.../gas_switch/gas_switch_efficiency_analyzer.dart`.
- Field, placed after `inputsFingerprint`:

```dart
  /// Late and missed deco gas switches against the ideal ascent (#2939).
  /// Null off the open-circuit path or with fewer than two gases. Read-only:
  /// computing it changes no other field.
  final GasSwitchEfficiency? gasSwitchEfficiency;
```

- Constructor: `this.gasSwitchEfficiency,` after `this.inputsFingerprint,`.
- `copyWith`: parameter `GasSwitchEfficiency? gasSwitchEfficiency,` and `gasSwitchEfficiency: gasSwitchEfficiency ?? this.gasSwitchEfficiency,`.
- `empty()` needs no change (defaults to null).

In `analyze`, immediately before the final `return ProfileAnalysis(` (the one at ~:1042 with `ttsCurve: ttsCurve,`):

```dart
    // Read-only technique feedback (#2939): its own engines, after every
    // curve above is final, so no deco value can move.
    final plan = ascentGasPlan;
    final gasSwitchEfficiency =
        useOcGasSegments && plan is OptimalOcAscentGas
        ? GasSwitchEfficiencyAnalyzer(
            newEngine: _buhlmannAlgorithm.withSameConfig,
            gases: plan.gases,
            maxPpO2: plan.maxPpO2,
            startCompartments: startCompartments,
          ).analyze(
            depths: depths,
            timestamps: timestamps,
            gasSegments: gasSegments,
            ceilingCurve: ceilingCurve,
          )
        : null;
```

and add `gasSwitchEfficiency: gasSwitchEfficiency,` to that return. If `gasSegments` does not promote to non-null here, use `gasSegments!` (it is non-null whenever `useOcGasSegments` is true).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_gas_switch_test.dart test/features/dive_log/data/services/ test/core/deco/`
Expected: PASS (existing analysis and deco suites unchanged).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/services test/features/dive_log/data/services
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_gas_switch_test.dart
git commit -m "feat(dive-log): compute gas-switch efficiency in profile analysis"
```

---

### Task 6: Localized strings

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Script (scratchpad, not committed): `$SCRATCH/add_gas_switch_l10n.py`

**Interfaces:**
- Produces (AppLocalizations getters/methods):
  - `diveLog_legend_label_lateGasSwitches`
  - `diveLog_tooltip_lateSwitch`, `diveLog_tooltip_missedSwitch`
  - `diveLog_tooltip_lateSwitchValue(String gas, String delay, String depth, String extra)`, `diveLog_tooltip_missedSwitchValue(String gas, String extra)`
  - `diveLog_gasSwitches_title`, `diveLog_gasSwitches_onTime`
  - `diveLog_gasSwitches_lateRow(String actual, String ideal, String delay)`, `diveLog_gasSwitches_missedRow(String ideal)`
  - `diveLog_gasSwitches_extraDeco(String extra)`, `diveLog_gasSwitches_total(String extra)`
  - `safetyReview_lateGasSwitch_title(String extra)`, `safetySettings_rule_lateGasSwitch`
  - `settings_appearance_lateGasSwitches`, `settings_appearance_lateGasSwitches_subtitle`

  The generated method's parameter order follows the `@placeholders` map order; the script writes placeholders in the order listed above, and every call site passes named-by-position arguments in that order.

- [ ] **Step 1: Write the insertion script**

Each key is inserted before an anchor key present in every ARB (ARBs are feature-grouped; inserting next to a sibling keeps the grouping). The script fails loudly if an anchor is missing or the result is not valid JSON.

```python
#!/usr/bin/env python3.14
import json, pathlib, re, sys

ARB = pathlib.Path("lib/l10n/arb")
LOCALES = ["en", "ar", "de", "es", "fr", "he", "hu", "it", "nl", "pt", "zh"]

# key -> (anchor to insert before, placeholders in order)
KEYS = {
    "diveLog_legend_label_lateGasSwitches": ("diveLog_legend_label_gasSwitches", []),
    "diveLog_tooltip_lateSwitch": ("diveLog_tooltip_gtr", []),
    "diveLog_tooltip_missedSwitch": ("diveLog_tooltip_gtr", []),
    "diveLog_tooltip_lateSwitchValue": ("diveLog_tooltip_gtr", ["gas", "delay", "depth", "extra"]),
    "diveLog_tooltip_missedSwitchValue": ("diveLog_tooltip_gtr", ["gas", "extra"]),
    "diveLog_gasSwitches_title": ("diveLog_detail_section_decoStatus", []),
    "diveLog_gasSwitches_onTime": ("diveLog_detail_section_decoStatus", []),
    "diveLog_gasSwitches_lateRow": ("diveLog_detail_section_decoStatus", ["actual", "ideal", "delay"]),
    "diveLog_gasSwitches_missedRow": ("diveLog_detail_section_decoStatus", ["ideal"]),
    "diveLog_gasSwitches_extraDeco": ("diveLog_detail_section_decoStatus", ["extra"]),
    "diveLog_gasSwitches_total": ("diveLog_detail_section_decoStatus", ["extra"]),
    "safetyReview_lateGasSwitch_title": ("safetyReview_timeRange", ["extra"]),
    "safetySettings_rule_lateGasSwitch": ("safetySettings_rule_highSurfaceGf", []),
    "settings_appearance_lateGasSwitches": ("settings_appearance_gasTimeline", []),
    "settings_appearance_lateGasSwitches_subtitle": ("settings_appearance_gasTimeline", []),
}

T = {
 "en": ["Late gas switches", "Late switch", "Missed switch",
        "{gas}, {delay} / {depth} late, +{extra} deco", "{gas}, +{extra} deco",
        "Gas switches", "All gas switches on time",
        "Switched at {actual} instead of {ideal}, {delay} late",
        "Not switched (ideal at {ideal})", "+{extra} deco", "Total extra deco: {extra}",
        "A late or missed gas switch added {extra} of deco", "Late gas switch",
        "Late gas switches", "Shade late and missed deco gas switches on the profile"],
 "de": ["Späte Gaswechsel", "Später Wechsel", "Verpasster Wechsel",
        "{gas}, {delay} / {depth} zu spät, +{extra} Deko", "{gas}, +{extra} Deko",
        "Gaswechsel", "Alle Gaswechsel rechtzeitig",
        "Gewechselt bei {actual} statt {ideal}, {delay} zu spät",
        "Nicht gewechselt (ideal bei {ideal})", "+{extra} Deko", "Zusätzliche Deko gesamt: {extra}",
        "Ein später oder verpasster Gaswechsel hat {extra} Deko hinzugefügt", "Später Gaswechsel",
        "Späte Gaswechsel", "Späte und verpasste Deko-Gaswechsel im Profil hervorheben"],
 "es": ["Cambios de gas tardíos", "Cambio tardío", "Cambio omitido",
        "{gas}, {delay} / {depth} tarde, +{extra} de deco", "{gas}, +{extra} de deco",
        "Cambios de gas", "Todos los cambios de gas a tiempo",
        "Cambiado a {actual} en lugar de {ideal}, {delay} tarde",
        "Sin cambiar (ideal a {ideal})", "+{extra} de deco", "Deco adicional total: {extra}",
        "Un cambio de gas tardío u omitido añadió {extra} de deco", "Cambio de gas tardío",
        "Cambios de gas tardíos", "Sombrear en el perfil los cambios de gas de deco tardíos y omitidos"],
 "fr": ["Changements de gaz tardifs", "Changement tardif", "Changement manqué",
        "{gas}, {delay} / {depth} de retard, +{extra} de déco", "{gas}, +{extra} de déco",
        "Changements de gaz", "Tous les changements de gaz à temps",
        "Changé à {actual} au lieu de {ideal}, {delay} de retard",
        "Non changé (idéal à {ideal})", "+{extra} de déco", "Déco supplémentaire totale : {extra}",
        "Un changement de gaz tardif ou manqué a ajouté {extra} de déco", "Changement de gaz tardif",
        "Changements de gaz tardifs", "Ombrer sur le profil les changements de gaz de déco tardifs et manqués"],
 "it": ["Cambi gas tardivi", "Cambio tardivo", "Cambio mancato",
        "{gas}, {delay} / {depth} di ritardo, +{extra} di deco", "{gas}, +{extra} di deco",
        "Cambi gas", "Tutti i cambi gas puntuali",
        "Cambiato a {actual} invece di {ideal}, {delay} di ritardo",
        "Non cambiato (ideale a {ideal})", "+{extra} di deco", "Deco aggiuntiva totale: {extra}",
        "Un cambio gas tardivo o mancato ha aggiunto {extra} di deco", "Cambio gas tardivo",
        "Cambi gas tardivi", "Evidenzia nel profilo i cambi gas deco tardivi e mancati"],
 "nl": ["Late gaswissels", "Late wissel", "Gemiste wissel",
        "{gas}, {delay} / {depth} te laat, +{extra} deco", "{gas}, +{extra} deco",
        "Gaswissels", "Alle gaswissels op tijd",
        "Gewisseld op {actual} in plaats van {ideal}, {delay} te laat",
        "Niet gewisseld (ideaal op {ideal})", "+{extra} deco", "Totale extra deco: {extra}",
        "Een late of gemiste gaswissel voegde {extra} deco toe", "Late gaswissel",
        "Late gaswissels", "Late en gemiste decogaswissels op het profiel arceren"],
 "pt": ["Trocas de gás tardias", "Troca tardia", "Troca omitida",
        "{gas}, {delay} / {depth} de atraso, +{extra} de deco", "{gas}, +{extra} de deco",
        "Trocas de gás", "Todas as trocas de gás a tempo",
        "Trocado a {actual} em vez de {ideal}, {delay} de atraso",
        "Não trocado (ideal a {ideal})", "+{extra} de deco", "Deco extra total: {extra}",
        "Uma troca de gás tardia ou omitida acrescentou {extra} de deco", "Troca de gás tardia",
        "Trocas de gás tardias", "Sombrear no perfil as trocas de gás de deco tardias e omitidas"],
 "hu": ["Késői gázváltások", "Késői váltás", "Kihagyott váltás",
        "{gas}, {delay} / {depth} késés, +{extra} deko", "{gas}, +{extra} deko",
        "Gázváltások", "Minden gázváltás időben",
        "Váltás {actual} mélységben {ideal} helyett, {delay} késés",
        "Nincs váltás (ideális: {ideal})", "+{extra} deko", "Összes többlet deko: {extra}",
        "Egy késői vagy kihagyott gázváltás {extra} dekót adott hozzá", "Késői gázváltás",
        "Késői gázváltások", "A késői és kihagyott deko gázváltások jelölése a profilon"],
 "ar": ["تبديلات الغاز المتأخرة", "تبديل متأخر", "تبديل فائت",
        "{gas}، تأخير {delay} / {depth}، +{extra} تخفيف ضغط", "{gas}، +{extra} تخفيف ضغط",
        "تبديلات الغاز", "جميع تبديلات الغاز في وقتها",
        "تم التبديل عند {actual} بدلاً من {ideal}، بتأخير {delay}",
        "لم يتم التبديل (المثالي عند {ideal})", "+{extra} تخفيف ضغط", "إجمالي تخفيف الضغط الإضافي: {extra}",
        "أضاف تبديل غاز متأخر أو فائت {extra} من تخفيف الضغط", "تبديل غاز متأخر",
        "تبديلات الغاز المتأخرة", "تظليل تبديلات غاز تخفيف الضغط المتأخرة والفائتة على المخطط"],
 "he": ["החלפות גז מאוחרות", "החלפה מאוחרת", "החלפה שהוחמצה",
        "{gas}, איחור {delay} / {depth}, +{extra} דקו", "{gas}, +{extra} דקו",
        "החלפות גז", "כל החלפות הגז בזמן",
        "הוחלף ב-{actual} במקום {ideal}, איחור {delay}",
        "לא הוחלף (אידיאלי ב-{ideal})", "+{extra} דקו", "סך דקו נוסף: {extra}",
        "החלפת גז מאוחרת או שהוחמצה הוסיפה {extra} דקו", "החלפת גז מאוחרת",
        "החלפות גז מאוחרות", "הצללת החלפות גז דקו מאוחרות ושהוחמצו בפרופיל"],
 "zh": ["延迟换气", "延迟换气", "漏换气",
        "{gas}，延迟 {delay} / {depth}，减压 +{extra}", "{gas}，减压 +{extra}",
        "换气", "所有换气均按时",
        "在 {actual} 换气，而非 {ideal}，延迟 {delay}",
        "未换气（理想深度 {ideal}）", "减压 +{extra}", "额外减压总计：{extra}",
        "一次延迟或遗漏的换气增加了 {extra} 减压", "延迟换气",
        "延迟换气", "在剖面图上标出延迟和遗漏的减压换气"],
}

def main():
    keys = list(KEYS)
    for loc in LOCALES:
        path = ARB / f"app_{loc}.arb"
        text = path.read_text(encoding="utf-8")
        values = dict(zip(keys, T[loc], strict=True))
        for key, (anchor, placeholders) in KEYS.items():
            if f'"{key}"' in text:
                sys.exit(f"{loc}: {key} already present")
            pattern = re.compile(rf'^(  "{re.escape(anchor)}":)', re.M)
            if len(pattern.findall(text)) != 1:
                sys.exit(f"{loc}: anchor {anchor} not found exactly once")
            block = f'  {json.dumps(key)}: {json.dumps(values[key], ensure_ascii=False)},\n'
            if placeholders:
                meta = {"placeholders": {p: {"type": "String"} for p in placeholders}}
                body = json.dumps(meta, ensure_ascii=False, indent=2).replace("\n", "\n  ")
                block += f'  {json.dumps("@" + key)}: {body},\n'
            text = pattern.sub(lambda m: block + m.group(1), text, count=1)
        json.loads(text)  # must stay valid JSON
        path.write_text(text, encoding="utf-8")
    print("OK")

main()
```

Before running, check that the em and en dash counts of the new strings are zero (they are; none of the strings above uses one).

- [ ] **Step 2: Run the script, regenerate, verify**

```bash
cd <worktree> && python3.14 "$SCRATCH/add_gas_switch_l10n.py"
flutter gen-l10n
git diff --stat lib/l10n
```

Expected: `OK`, 11 ARB files plus the generated Dart files changed, `flutter analyze lib/l10n` clean.

- [ ] **Step 3: Verify placeholder argument order**

Run: `grep -n "String diveLog_tooltip_lateSwitchValue(\|String diveLog_gasSwitches_lateRow(" lib/l10n/arb/app_localizations.dart`
Expected: `(String gas, String delay, String depth, String extra)` and `(String actual, String ideal, String delay)`. If the generator orders differently, call sites in Tasks 8 and 9 follow the generated order.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(dive-log): add strings for late gas switch feedback"
```

---

### Task 7: Safety review rule

**Files:**
- Modify: `lib/features/dive_log/domain/entities/safety_finding.dart` (enum)
- Modify: `lib/features/dive_log/domain/services/safety_review_service.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_finding_text.dart` (two switches)
- Modify: `lib/features/settings/presentation/pages/safety_settings_page.dart:~200`
- Test: `test/features/dive_log/domain/services/safety_review_late_gas_switch_test.dart`

**Interfaces:**
- Consumes: `ProfileAnalysis.gasSwitchEfficiency` (Task 5), l10n keys (Task 6).
- Produces: `SafetyRuleId.lateGasSwitch`; `SafetyReviewService.engineVersion == 6`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

void main() {
  GasSwitchWindow window(int extra, {int start = 1630}) => GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: start,
    idealDepth: 21,
    switchTimestamp: start + 280,
    switchDepth: 15,
    endTimestamp: start + 280,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: extra,
  );

  List<SafetyFinding> review(GasSwitchEfficiency? efficiency) =>
      const SafetyReviewService()
          .review(
            diveId: 'd1',
            analysis: ProfileAnalysis.empty().copyWith(
              gasSwitchEfficiency: efficiency,
            ),
            now: DateTime.utc(2026, 10, 5),
          )
          .where((f) => f.ruleId == SafetyRuleId.lateGasSwitch)
          .toList();

  test('engine version is 6', () {
    expect(SafetyReviewService.engineVersion, 6);
  });

  test('one finding per window, severity by extra deco', () {
    final findings = review(
      GasSwitchEfficiency(
        evaluated: true,
        windows: [window(120), window(300, start: 2510)],
        totalExtraDecoSeconds: 400,
      ),
    );
    expect(findings, hasLength(2));
    expect(findings[0].severity, SafetySeverity.caution);
    expect(findings[0].startTimestamp, 1630);
    expect(findings[0].endTimestamp, 1910);
    expect(findings[0].value, 120);
    expect(findings[1].severity, SafetySeverity.significant);
  });

  test('no efficiency or not evaluated means no finding', () {
    expect(review(null), isEmpty);
    expect(review(GasSwitchEfficiency.notEvaluated), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/domain/services/safety_review_late_gas_switch_test.dart`
Expected: FAIL, `lateGasSwitch` undefined.

- [ ] **Step 3: Implement**

`safety_finding.dart`: add `lateGasSwitch;` after `highSurfaceGf,` (change `highSurfaceGf;` to `highSurfaceGf,`).

`safety_review_service.dart`:
- Extend the version doc with `/// v6: late and missed deco gas switches (#2939).` and set `static const int engineVersion = 6;`.
- In `review`, after `_highSurfaceGfFindings`: `findings.addAll(_lateGasSwitchFindings(diveId, analysis, now, nextId));`
- Add:

```dart
  /// Extra deco from one late or missed gas switch at or above which the
  /// finding is significant rather than a caution.
  static const int _significantExtraDecoSeconds = 300;

  List<SafetyFinding> _lateGasSwitchFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    final efficiency = analysis.gasSwitchEfficiency;
    if (efficiency == null || !efficiency.evaluated) return const [];
    return [
      for (final window in efficiency.windows)
        SafetyFinding(
          id: nextId(),
          diveId: diveId,
          ruleId: SafetyRuleId.lateGasSwitch,
          severity: window.extraDecoSeconds >= _significantExtraDecoSeconds
              ? SafetySeverity.significant
              : SafetySeverity.caution,
          startTimestamp: window.idealTimestamp,
          endTimestamp: window.endTimestamp,
          value: window.extraDecoSeconds.toDouble(),
          engineVersion: engineVersion,
          createdAt: now,
        ),
    ];
  }
```

`safety_finding_text.dart`, title switch:

```dart
    SafetyRuleId.lateGasSwitch => l10n.safetyReview_lateGasSwitch_title(
      value == null ? unknown : _formatSeconds(value.round()),
    ),
```

and in `safetyRuleLabel`: `SafetyRuleId.lateGasSwitch => l10n.safetySettings_rule_lateGasSwitch,`.

`safety_settings_page.dart`: add `SafetyRuleId.lateGasSwitch => l10n.safetySettings_rule_lateGasSwitch,` to the rule-name switch.

Then `flutter analyze lib test` and add the new value to any other exhaustive `switch` it reports (for example in `lib/features/dive_log/query/`).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/domain/ test/features/dive_log/presentation/widgets/safety_review_section_test.dart test/features/dive_log/data/repositories/safety_findings_repository_test.dart test/features/settings/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features test/features
git add lib/features/dive_log/domain/entities/safety_finding.dart lib/features/dive_log/domain/services/safety_review_service.dart lib/features/dive_log/presentation/widgets/safety_finding_text.dart lib/features/settings/presentation/pages/safety_settings_page.dart test/features/dive_log/domain/services/safety_review_late_gas_switch_test.dart
git commit -m "feat(dive-log): raise a safety finding for late gas switches"
```

---

### Task 8: Persisted overlay default (schema v261)

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `defaultShowGasSwitchMarkers`, ~:357)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (new assert at the end)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append v261)
- Modify: `lib/core/database/migrations/before_open.dart` (net zero lines)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 261`, `migrationVersions` gets `261`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (defaults map)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (3 spots)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field, ctor, copyWith x2, setter, select provider)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (switch after gas switch markers)
- Modify: `test/helpers/mock_providers.dart` and any fake notifier `flutter analyze` flags
- Modify: `test/core/database/migration_v260_tank_shared_computers_test.dart` (relax the exact-version assertion)
- Test: `test/core/database/migration_v261_late_gas_switch_setting_test.dart`, `test/core/services/sync/sync_diver_settings_late_gas_switch_test.dart`

**Interfaces:**
- Produces: `AppSettings.defaultShowLateGasSwitches` (bool, default true), `SettingsNotifier.setDefaultShowLateGasSwitches(bool)`, `defaultShowLateGasSwitchesProvider`.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v261: diver_settings.default_show_late_gas_switches (issue #2939).
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 260');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v261 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(
      AppDatabase.migrationStepCount(260),
      AppDatabase.migrationStepCount(261) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v260 defaults the overlay on', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT default_show_late_gas_switches AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<int>('v'), 1);
  });
}
```

If the v260-shaped setup table lacks columns that other v2xx backstops in `beforeOpen` require, copy the setup used by `migration_v259_tank_usage_duration_test.dart` (which creates only the table it needs); `beforeOpen` asserts are guarded by `PRAGMA table_info` and skip missing tables.

- [ ] **Step 2: Write the failing sync fallback test**

`test/core/services/sync/sync_diver_settings_late_gas_switch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer still on v260 exports no default_show_late_gas_switches. The column
/// is NOT NULL, so an unseeded import would throw in DiverSetting.fromJson.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('applies a pre-v261 payload missing the late switch default', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-lgs',
            diverId: 'diver-lgs',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', 'ds-lgs');
    expect(exported, isNotNull);
    expect(exported!['defaultShowLateGasSwitches'], isTrue);

    final legacy = Map<String, dynamic>.from(exported)
      ..remove('defaultShowLateGasSwitches');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-lgs'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-lgs'))).getSingle();
    expect(row.defaultShowLateGasSwitches, isTrue);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/database/migration_v261_late_gas_switch_setting_test.dart test/core/services/sync/sync_diver_settings_late_gas_switch_test.dart`
Expected: FAIL (version 260, getter missing).

- [ ] **Step 4: Implement the column and migration**

`diver_tables.dart`, after `defaultShowGasSwitchMarkers`:

```dart
  /// v261: shade late and missed deco gas switches on the profile (#2939).
  BoolColumn get defaultShowLateGasSwitches =>
      boolean().withDefault(const Constant(true))();
```

`diver_migrations.dart`, at the end of the extension:

```dart
  /// v261: diver_settings.default_show_late_gas_switches (issue #2939).
  /// Column only, defaulting on; re-asserted in beforeOpen.
  Future<void> _assertLateGasSwitchSettingColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_show_late_gas_switches')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_late_gas_switches '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (default_show_late_gas_switches IN (0, 1))',
      );
    }
  }
```

`rungs_v231_onward.dart`, after the v260 block:

```dart
    // v261: diver_settings.default_show_late_gas_switches (issue #2939).
    // Column only, defaulting on. Re-asserted in beforeOpen.
    if (from < 261) {
      await _assertLateGasSwitchSettingColumn();
    }
    if (from < 261) await reportProgress();
```

`before_open.dart` (must stay at 800 lines): replace

```dart
    // v237 backstop: the dive figure switch.
    await _assertShowDiveFigureColumn();

    // v229 backstop: the per-set diver figure switch.
    await _assertEquipmentSetShowFigureColumn();
```

with

```dart
    // v237 and v229 backstops: the dive and per-set diver figure switches.
    await _assertShowDiveFigureColumn();
    await _assertEquipmentSetShowFigureColumn();
```

and replace

```dart
    // v211 backstop: re-assert diver_settings.auto_tag_imports.
    await _assertAutoTagImportsColumn();
```

with

```dart
    // v211 and v261 backstops: diver_settings.auto_tag_imports and
    // default_show_late_gas_switches.
    await _assertAutoTagImportsColumn();
    await _assertLateGasSwitchSettingColumn();
```

`database.dart`: `currentSchemaVersion = 261`, and append to `migrationVersions` after `260,`:

```dart
    // v261: diver_settings.default_show_late_gas_switches (issue #2939).
    // Additive column with a default, so the floor stays.
    261,
```

`migration_v260_tank_shared_computers_test.dart`: change `expect(AppDatabase.currentSchemaVersion, 260);` to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(260));` and its test name to `'v260 is at or below the current schema version and in the ladder'`. Then `grep -rn "user_version'), 260\|, 260)" test/core` and point any "ladder finished" literal at `AppDatabase.currentSchemaVersion`.

Run codegen: `dart run build_runner build --delete-conflicting-outputs` (log to the scratchpad).

- [ ] **Step 5: Implement the settings layers**

`sync_data_serializer.dart`, in the defaults map after the GTR block:

```dart
      // v261: seed it so payloads predating the column hydrate instead of
      // throwing in DiverSetting.fromJson (issue #2939).
      'defaultShowLateGasSwitches': true,
```

`diver_settings_repository.dart`: next to each `defaultShowGasSwitchMarkers` line add the matching line:
- `:216` `defaultShowLateGasSwitches: Value(s.defaultShowLateGasSwitches),`
- `:466` `defaultShowLateGasSwitches: Value(settings.defaultShowLateGasSwitches),`
- `:674` `defaultShowLateGasSwitches: row.defaultShowLateGasSwitches,`

`settings_providers.dart`, next to each `defaultShowGasSwitchMarkers` spot:
- field: `/// Shade late and missed deco gas switches on the profile (#2939).` `final bool defaultShowLateGasSwitches;`
- ctor: `this.defaultShowLateGasSwitches = true,`
- copyWith param `bool? defaultShowLateGasSwitches,` and body `defaultShowLateGasSwitches: defaultShowLateGasSwitches ?? this.defaultShowLateGasSwitches,`
- setter in `SettingsNotifier`:

```dart
  Future<void> setDefaultShowLateGasSwitches(bool value) async {
    state = state.copyWith(defaultShowLateGasSwitches: value);
    await _saveSettings();
  }
```

- provider:

```dart
final defaultShowLateGasSwitchesProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsProvider.select((s) => s.defaultShowLateGasSwitches),
  );
});
```

`section_appearance_page.dart`, after the gas switch markers `SwitchListTile`:

```dart
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_lateGasSwitches),
        subtitle: Text(
          context.l10n.settings_appearance_lateGasSwitches_subtitle,
        ),
        secondary: const Icon(Icons.timer_off_outlined),
        value: settings.defaultShowLateGasSwitches,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setDefaultShowLateGasSwitches(value);
        },
      ),
```

`test/helpers/mock_providers.dart` (and every fake `flutter analyze` reports as missing the member):

```dart
  @override
  Future<void> setDefaultShowLateGasSwitches(bool value) async =>
      state = state.copyWith(defaultShowLateGasSwitches: value);
```

- [ ] **Step 6: Run tests**

Run: `flutter analyze` then `flutter test test/core/database/ test/core/services/sync/ test/features/settings/`
Expected: analyze clean; tests PASS, including `database_table_libraries_test.dart` (800-line cap).

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core/database/tables/diver_tables.dart lib/core/database/migrations/helpers/diver_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart lib/core/database/database.dart lib/core/database/database.g.dart lib/core/services/sync/sync_data_serializer.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/presentation/pages/section_appearance_page.dart test/helpers/mock_providers.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/core/database/migration_v261_late_gas_switch_setting_test.dart test/core/services/sync/sync_diver_settings_late_gas_switch_test.dart
git status --short   # stage any other generated table file or fake the build changed, by explicit path
git commit -m "feat(settings): persist the late gas switch overlay default"
```

---

### Task 9: Legend toggle, chart bands and tooltip

**Files:**
- Create: `lib/features/dive_log/presentation/utils/gas_switch_format.dart`
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (6 spots + toggle)
- Modify: `lib/features/dive_log/presentation/widgets/profile_legend_config.dart`
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart` (markers section)
- Modify: `lib/features/dive_log/presentation/widgets/active_legend_entries.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart`, `dive_profile_panel.dart`, `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` (pass `gasSwitchEfficiency: analysis?.gasSwitchEfficiency,` beside each `ttsCurve: analysis?.ttsCurve,`)
- Test: `test/features/dive_log/presentation/providers/profile_legend_provider_late_switch_test.dart`, `test/features/dive_log/presentation/widgets/dive_profile_chart_late_switch_test.dart`, `test/features/dive_log/presentation/utils/gas_switch_format_test.dart`

**Interfaces:**
- Consumes: `ProfileAnalysis.gasSwitchEfficiency`, `AppSettings.defaultShowLateGasSwitches`, l10n keys.
- Produces:
  - `ProfileLegendState.showLateGasSwitches`, `ProfileLegend.toggleLateGasSwitches()`
  - `ProfileLegendConfig.hasLateGasSwitches`
  - `String formatMinSec(int seconds)` ("3:20"), `String gasSwitchGasLabel(double fO2, double fHe)` (via `GasMix.name`), `const Color lateSwitchLegendColor`
  - `String lateSwitchTooltipValue(GasSwitchWindow w, UnitFormatter units, AppLocalizations l10n)` and `String lateSwitchTooltipLabel(GasSwitchWindow w, AppLocalizations l10n)`

- [ ] **Step 1: Write the failing format tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_switch_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1830,
    switchDepth: 12,
    endTimestamp: 1830,
    delaySeconds: 200,
    depthDelayMeters: 9,
    extraDecoSeconds: 250,
  );

  test('minutes and seconds', () {
    expect(formatMinSec(0), '0:00');
    expect(formatMinSec(200), '3:20');
    expect(formatMinSec(3725), '62:05');
  });

  test('gas labels reuse GasMix names', () {
    expect(gasSwitchGasLabel(0.5, 0), 'EAN50');
    expect(gasSwitchGasLabel(1.0, 0), 'O2');
    expect(gasSwitchGasLabel(0.21, 0.35), 'Tx 21/35');
  });

  test('late tooltip in metric and imperial', () {
    final metric = UnitFormatter(const AppSettings());
    expect(lateSwitchTooltipLabel(late, l10n), 'Late switch');
    expect(
      lateSwitchTooltipValue(late, metric, l10n),
      'EAN50, 3:20 / ${metric.formatDepth(9, decimals: 0)} late, +4:10 deco',
    );
    final imperial = UnitFormatter(
      const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(lateSwitchTooltipValue(late, imperial, l10n), contains('ft'));
  });

  test('missed tooltip', () {
    final missed = late.copyWith(kind: GasSwitchWindowKind.missed);
    final metric = UnitFormatter(const AppSettings());
    expect(lateSwitchTooltipLabel(missed, l10n), 'Missed switch');
    expect(lateSwitchTooltipValue(missed, metric, l10n), 'EAN50, +4:10 deco');
  });
}
```

(Check `AppSettings` const-constructibility and the `DepthUnit` import path with `grep -n "enum DepthUnit" -r lib/core`; adjust the import, not the assertion.)

- [ ] **Step 2: Implement `gas_switch_format.dart`**

```dart
import 'dart:ui';

import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Legend chip colour for the late gas switch overlay. The bands themselves
/// take the colour of the gas that should have been breathed.
const Color lateSwitchLegendColor = Color(0xFFFF8F00);

/// `m:ss`, the profile tooltip's own time format.
String formatMinSec(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

String gasSwitchGasLabel(double fO2, double fHe) =>
    GasMix(o2: fO2 * 100, he: fHe * 100).name;

String lateSwitchTooltipLabel(GasSwitchWindow window, AppLocalizations l10n) =>
    window.isMissed
    ? l10n.diveLog_tooltip_missedSwitch
    : l10n.diveLog_tooltip_lateSwitch;

String lateSwitchTooltipValue(
  GasSwitchWindow window,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final gas = gasSwitchGasLabel(window.fO2, window.fHe);
  final extra = formatMinSec(window.extraDecoSeconds);
  if (window.isMissed) {
    return l10n.diveLog_tooltip_missedSwitchValue(gas, extra);
  }
  return l10n.diveLog_tooltip_lateSwitchValue(
    gas,
    formatMinSec(window.delaySeconds),
    units.formatDepth(window.depthDelayMeters, decimals: 0),
    extra,
  );
}
```

Run: `flutter test test/features/dive_log/presentation/utils/gas_switch_format_test.dart`. Expected: PASS. (`formatDepth(9, decimals: 0)` renders `9m`; the test builds its expectation from the same call so the format is not hardcoded.)

- [ ] **Step 3: Write the failing legend provider test**

`test/features/dive_log/presentation/providers/profile_legend_provider_late_switch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(AppSettings settings) {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(profileLegendProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  test('late gas switches show by default', () {
    final container = containerWith(const AppSettings());
    expect(container.read(profileLegendProvider).showLateGasSwitches, isTrue);
  });

  test('seeds from the diver default', () {
    final container = containerWith(
      const AppSettings(defaultShowLateGasSwitches: false),
    );
    expect(container.read(profileLegendProvider).showLateGasSwitches, isFalse);
  });

  test('toggles for the session', () {
    final container = containerWith(const AppSettings());
    container.read(profileLegendProvider.notifier).toggleLateGasSwitches();
    expect(container.read(profileLegendProvider).showLateGasSwitches, isFalse);
  });
}
```

- [ ] **Step 4: Implement the legend state**

In `profile_legend_provider.dart`, beside each `showGasSwitchMarkers` spot:
- field `/// Late and missed deco gas switch bands (#2939). Seeds from [AppSettings.defaultShowLateGasSwitches].` `final bool showLateGasSwitches;`
- ctor `this.showLateGasSwitches = true,`
- `activeSecondaryCount`: `if (showLateGasSwitches) count++;`
- copyWith param and body
- `==` (`showLateGasSwitches == other.showLateGasSwitches &&`) and `hashCode` list entry
- settings select record: `defaultShowLateGasSwitches: s.defaultShowLateGasSwitches,`
- seed: `showLateGasSwitches: settings.defaultShowLateGasSwitches,`
- toggle:

```dart
  void toggleLateGasSwitches() {
    state = state.copyWith(showLateGasSwitches: !state.showLateGasSwitches);
  }
```

Run the provider tests. Expected: PASS.

- [ ] **Step 5: Legend config, options dialog, chip**

`profile_legend_config.dart`: field `final bool hasLateGasSwitches;`, ctor `this.hasLateGasSwitches = false,`, and `hasLateGasSwitches ||` in `hasSecondaryToggles`.

`chart_options_dialog.dart`, right after the gas switches `buildToggleItem` in the markers section:

```dart
      if (config.hasLateGasSwitches)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_lateGasSwitches,
          color: lateSwitchLegendColor,
          isEnabled: legendState.showLateGasSwitches,
          onTap: legendNotifier.toggleLateGasSwitches,
        ),
```

`active_legend_entries.dart`, after the gas switches `add(...)`:

```dart
  add(
    config.hasLateGasSwitches,
    state.showLateGasSwitches,
    l10n.diveLog_legend_label_lateGasSwitches,
    lateSwitchLegendColor,
  );
```

- [ ] **Step 6: Write the failing chart test**

`test/features/dive_log/presentation/widgets/dive_profile_chart_late_switch_test.dart` (harness copied from `dive_profile_chart_gtr_test.dart`):

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 20 samples, 30 s apart (0..570 s).
List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

GasSwitchWindow _window({int start = 150, int end = 450}) => GasSwitchWindow(
  kind: GasSwitchWindowKind.late,
  fO2: 0.5,
  fHe: 0,
  idealTimestamp: start,
  idealDepth: 10,
  switchTimestamp: end,
  switchDepth: 4,
  endTimestamp: end,
  delaySeconds: end - start,
  depthDelayMeters: 6,
  extraDecoSeconds: 90,
);

Widget _harness(
  GasSwitchWindow window, {
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: _profile(),
            gasSwitchEfficiency: GasSwitchEfficiency(
              evaluated: true,
              windows: [window],
            ),
            tooltipPresentation: TooltipPresentation.external,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

List<VerticalRangeAnnotation> _bands(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .rangeAnnotations
    .verticalRangeAnnotations;

void main() {
  testWidgets('shades the window while the toggle is on', (tester) async {
    await tester.pumpWidget(_harness(_window()));
    await tester.pumpAndSettle();
    expect(_bands(tester), hasLength(1));
    expect(_bands(tester).single.x1, 150);
    expect(_bands(tester).single.x2, 450);

    ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChart)),
    ).read(profileLegendProvider.notifier).toggleLateGasSwitches();
    await tester.pumpAndSettle();
    expect(_bands(tester), isEmpty);
  });

  testWidgets('clamps a window running past the visible range', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_window(start: 300, end: 9999)));
    await tester.pumpAndSettle();
    expect(_bands(tester).single.x1, 300);
    expect(_bands(tester).single.x2, lessThanOrEqualTo(570));
  });

  testWidgets('the tooltip names the late switch under the cursor', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(_window(), onTooltipData: (r) => rows = r),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineChart)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();
    expect(rows, isNotNull);
    expect(rows!.map((r) => r.label), contains('Late switch'));
    await gesture.up();
  });
}
```

If the centre touch does not land inside 150..450 s (the plot area is inset by axis labels), widen the window to `_window(start: 0, end: 570)` for the tooltip test rather than computing pixel offsets.

- [ ] **Step 7: Implement the chart**

In `dive_profile_chart.dart`:
- constructor parameter `this.gasSwitchEfficiency,` (after `this.ttsCurve,`) and field `/// Late and missed gas switches to shade (#2939); null hides the overlay.` `final GasSwitchEfficiency? gasSwitchEfficiency;`
- state field next to `_showGtr`: `bool _showLateGasSwitches = true;`, synced next to `_showGasSwitchMarkers = legendState.showGasSwitchMarkers;` with `_showLateGasSwitches = legendState.showLateGasSwitches;`.
- legend config (~:2851): `hasLateGasSwitches: widget.gasSwitchEfficiency?.windows.isNotEmpty ?? false,`
- in `_buildHighlightRangeAnnotations`, first statement after `final annotations = <VerticalRangeAnnotation>[];`:

```dart
    // Late and missed gas switches (#2939), tinted with the gas the ideal
    // ascent would have been breathing. Drawn first so a selected finding's
    // band paints over them.
    if (_showLateGasSwitches) {
      for (final window
          in widget.gasSwitchEfficiency?.windows ??
              const <GasSwitchWindow>[]) {
        final visible = visibleHighlightSpan(
          ProfileHighlightRange(
            startTimestamp: window.idealTimestamp,
            endTimestamp: window.endTimestamp,
            color: GasColors.forMixFraction(window.fO2, window.fHe),
          ),
          visibleMinX: visibleMinX,
          visibleMaxX: visibleMaxX,
        );
        if (visible == null) continue;
        annotations.add(
          VerticalRangeAnnotation(
            x1: visible.x1,
            x2: visible.x2,
            color: GasColors.forMixFraction(
              window.fO2,
              window.fHe,
            ).withValues(alpha: 0.12),
          ),
        );
      }
    }
```

- in `_buildTooltipRowsForIndex`, just before `// Marker info (if touching near a marker)`:

```dart
    // Late or missed gas switch under the cursor (#2939).
    if (_showLateGasSwitches) {
      final window = widget.gasSwitchEfficiency?.windowAt(
        point.timestamp,
      );
      if (window != null) {
        rows.add(
          TooltipRow(
            label: lateSwitchTooltipLabel(window, l10n),
            value: lateSwitchTooltipValue(window, units, l10n),
            bulletColor: GasColors.forMixFraction(window.fO2, window.fHe),
          ),
        );
      }
    }
```

- imports: `gas_switch_efficiency.dart` and `../utils/gas_switch_format.dart`.

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/dive_log/presentation/`
Expected: PASS (includes existing legend, chart and options dialog suites).

- [ ] **Step 9: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/utils/gas_switch_format.dart lib/features/dive_log/presentation/providers/profile_legend_provider.dart lib/features/dive_log/presentation/widgets/profile_legend_config.dart lib/features/dive_log/presentation/widgets/chart_options_dialog.dart lib/features/dive_log/presentation/widgets/active_legend_entries.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/utils/gas_switch_format_test.dart test/features/dive_log/presentation/providers/profile_legend_provider_late_switch_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_late_switch_test.dart
git commit -m "feat(dive-log): shade late gas switches on the profile chart"
```

---

### Task 10: Dive detail card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_decoPanelCards` ~:2343, `_decoStatusColumn` ~:2481)
- Test: `test/features/dive_log/presentation/widgets/gas_switch_efficiency_card_test.dart`

**Interfaces:**
- Consumes: `GasSwitchEfficiency`, `gas_switch_format.dart`, l10n keys, `settingsProvider`.
- Produces: `class GasSwitchEfficiencyCard extends ConsumerWidget { const GasSwitchEfficiencyCard({super.key, required this.efficiency}); }`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget testApp({required Widget child, bool imperial = false}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _StubSettingsNotifier(
          AppSettings(
            depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1910,
    switchDepth: 15,
    endTimestamp: 1910,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: 125,
  );
  const missed = GasSwitchWindow(
    kind: GasSwitchWindowKind.missed,
    fO2: 1.0,
    fHe: 0,
    idealTimestamp: 2510,
    idealDepth: 6,
    endTimestamp: 3750,
    delaySeconds: 1240,
    extraDecoSeconds: 400,
  );

  testWidgets('lists each flagged switch and the total', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [late, missed],
            totalExtraDecoSeconds: 480,
          ),
        ),
      ),
    );
    expect(find.text('Gas switches'), findsOneWidget);
    expect(find.text('EAN50'), findsOneWidget);
    expect(find.textContaining('Switched at 15'), findsOneWidget);
    expect(find.textContaining('4:40 late'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.textContaining('Not switched (ideal at 6'), findsOneWidget);
    expect(find.text('Total extra deco: 8:00'), findsOneWidget);
  });

  testWidgets('says all switches were on time when none are flagged', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(evaluated: true),
        ),
      ),
    );
    expect(find.text('All gas switches on time'), findsOneWidget);
  });

  testWidgets('depths follow imperial units', (tester) async {
    await tester.pumpWidget(
      testApp(
        imperial: true,
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [late],
            totalExtraDecoSeconds: 125,
          ),
        ),
      ),
    );
    expect(find.textContaining('ft'), findsWidgets);
  });
}
```

`ProviderScope` and `StateNotifier` come from `package:submersion/core/providers/provider.dart`, as in the GTR chart test.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/gas_switch_efficiency_card_test.dart`
Expected: FAIL, card not found.

- [ ] **Step 3: Implement the card**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_switch_format.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Late and missed deco gas switches of one dive, beside the deco status
/// card (#2939). Shown only when the dive was evaluated.
class GasSwitchEfficiencyCard extends ConsumerWidget {
  const GasSwitchEfficiencyCard({super.key, required this.efficiency});

  final GasSwitchEfficiency efficiency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onTime = efficiency.windows.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    onTime ? Icons.check_circle : Icons.timer_off_outlined,
                    size: 16,
                    color: onTime ? Colors.green : lateSwitchLegendColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(l10n.diveLog_gasSwitches_title, style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (onTime)
              Text(l10n.diveLog_gasSwitches_onTime, style: textTheme.bodySmall)
            else ...[
              for (final window in efficiency.windows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _WindowRow(window: window, units: units),
                ),
              Text(
                l10n.diveLog_gasSwitches_total(
                  formatMinSec(efficiency.totalExtraDecoSeconds),
                ),
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.window, required this.units});

  final GasSwitchWindow window;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final ideal = units.formatDepth(window.idealDepth, decimals: 0);
    final detail = window.isMissed
        ? l10n.diveLog_gasSwitches_missedRow(ideal)
        : l10n.diveLog_gasSwitches_lateRow(
            units.formatDepth(window.switchDepth, decimals: 0),
            ideal,
            formatMinSec(window.delaySeconds),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5, right: 8),
          decoration: BoxDecoration(
            color: GasColors.forMixFraction(window.fO2, window.fHe),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gasSwitchGasLabel(window.fO2, window.fHe),
                style: textTheme.bodyMedium,
              ),
              Text(detail, style: textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          l10n.diveLog_gasSwitches_extraDeco(
            formatMinSec(window.extraDecoSeconds),
          ),
          style: textTheme.labelMedium,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Wire into the detail page**

In `_decoPanelCards`:
- record type becomes `({Widget deco, Widget o2, Widget? gasSwitches, Widget Function({bool expand}) tissue})?`.
- withheld branch: add `gasSwitches: null,`.
- before the final return:

```dart
    final efficiency = analysis.gasSwitchEfficiency;
    final gasSwitchCard = efficiency != null && efficiency.evaluated
        ? GasSwitchEfficiencyCard(efficiency: efficiency)
        : null;
```

  and return `(deco: decoCard, o2: o2Card, gasSwitches: gasSwitchCard, tissue: buildTissueCard)`.

In `_decoStatusColumn`, after `cards.o2,`:

```dart
        if (cards.gasSwitches != null) ...[
          const SizedBox(height: 8),
          cards.gasSwitches!,
        ],
```

Add the import for the card.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/gas_switch_efficiency_card_test.dart test/features/dive_log/presentation/pages/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/gas_switch_efficiency_card_test.dart
git commit -m "feat(dive-log): summarise gas switch efficiency on dive detail"
```

---

### Task 11: Whole-branch verification and screenshots

**Files:** none new (fixes only).

- [ ] **Step 1: Format, analyze, architecture guards**

```bash
dart format .
flutter analyze
flutter test test/architecture/
```

Expected: no format changes, analyze clean (infos are fatal in CI), guards PASS.

- [ ] **Step 2: Affected suites**

```bash
flutter test test/core/deco/ test/core/database/ test/core/services/sync/ test/features/dive_log/ test/features/settings/ test/l10n/
```

Expected: PASS. Investigate any failure with superpowers:systematic-debugging before touching code.

- [ ] **Step 3: After screenshots**

Launch with the `run` skill on a multi-gas OC deco dive (import `test/dives/001_short_deco_single_gas_switch.ssrf.xml` if the dev database has none), toggle the overlay, hover a band, open the dive detail Deco section and the Appearance settings page. Capture light and dark, phone and desktop widths, into the scratchpad as `<nn>-<screen>-after[-dark][-phone].png`.

- [ ] **Step 4: Commit any fixes**

```bash
git status --short
git add <explicit paths>
git commit -m "fix(dive-log): address verification findings for gas switch efficiency"
```

(Skip if nothing changed.)
