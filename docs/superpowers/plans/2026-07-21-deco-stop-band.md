# Deco Stop Band Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render decompression stops on the dive profile chart as a stepped shaded band, switchable between app-calculated and dive-computer values via a new settings toggle.

**Architecture:** A pure quantization function turns the calculated ceiling curve into stop levels; `ProfileAnalysis` carries the result as a new `decoStopCurve` field, which `overlayComputerDecoData` swaps for raw dive-computer ceiling values when the computer source is selected. A standalone builder converts that curve into an fl_chart step-line bar which `DiveProfileChart` draws beneath the existing smooth ceiling line.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, fl_chart ^1.1.1, flutter_test.

**Spec:** [docs/superpowers/specs/2026-07-21-deco-stop-band-design.md](../specs/2026-07-21-deco-stop-band-design.md)

## Global Constraints

- Dart code must pass `dart format .` with no changes. Run it before every commit.
- No emojis in code, comments, or documentation.
- No Claude attribution or co-author trailer in commit messages or PR bodies.
- Immutability: never mutate existing lists or entities in place; build new ones.
- Files stay in the 200-400 line range, 800 maximum. `dive_profile_chart.dart` is already 4953 lines, so new rendering code goes in its own file.
- Schema bump target is **129 to 130**. `AppDatabase.currentSchemaVersion` lives at [lib/core/database/database.dart:2817](../../../lib/core/database/database.dart#L2817).
- `flutter test | tail` masks the exit code in this repo. Always capture the status explicitly, for example `flutter test 2>&1 | tail -20; echo "EXIT=${PIPESTATUS[0]}"`.
- Tests come first. Write the failing test, watch it fail, then implement.
- Stage explicit paths when committing. Never `git add -A` in this checkout.

---

### Task 1: Stop-level quantization function

**Files:**
- Create: `lib/features/dive_log/domain/services/deco_stop_curve.dart`
- Test: `test/features/dive_log/domain/services/deco_stop_curve_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `List<double> quantizeCeilingToStops(List<double> ceilingCurve, {required double stopIncrement})` — rounds each positive value up to the next multiple of `stopIncrement`; zero and negative values become `0.0`. Also `List<int> stepTransitionIndices(List<double> curve)` — returns indices where the value differs from the previous one, always including index 0 and the last index when the curve is non-empty.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/domain/services/deco_stop_curve_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/deco_stop_curve.dart';

void main() {
  group('quantizeCeilingToStops', () {
    test('rounds a partial ceiling up to the next stop', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 3.0);
      expect(result, [6.0]);
    });

    test('leaves an exact multiple unchanged', () {
      final result = quantizeCeilingToStops([6.0], stopIncrement: 3.0);
      expect(result, [6.0]);
    });

    test('keeps zero as zero (no obligation)', () {
      final result = quantizeCeilingToStops([0.0], stopIncrement: 3.0);
      expect(result, [0.0]);
    });

    test('clamps negative values to zero', () {
      final result = quantizeCeilingToStops([-1.5], stopIncrement: 3.0);
      expect(result, [0.0]);
    });

    test('honors a non-3m increment', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 2.0);
      expect(result, [6.0]);
    });

    test('tolerates floating point noise just above a multiple', () {
      // 6.0000000001 must not round up to 9m.
      final result = quantizeCeilingToStops(
        [6.0000000001],
        stopIncrement: 3.0,
      );
      expect(result, [6.0]);
    });

    test('returns empty for an empty curve', () {
      expect(quantizeCeilingToStops([], stopIncrement: 3.0), isEmpty);
    });

    test('falls back to the raw curve when the increment is not positive', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 0.0);
      expect(result, [4.2]);
    });

    test('quantizes a whole descent-to-ascent curve', () {
      final result = quantizeCeilingToStops(
        [0.0, 0.0, 1.1, 4.9, 7.2, 3.0, 0.0],
        stopIncrement: 3.0,
      );
      expect(result, [0.0, 0.0, 3.0, 6.0, 9.0, 3.0, 0.0]);
    });
  });

  group('stepTransitionIndices', () {
    test('returns empty for an empty curve', () {
      expect(stepTransitionIndices([]), isEmpty);
    });

    test('returns only index 0 for a single-element curve', () {
      expect(stepTransitionIndices([3.0]), [0]);
    });

    test('keeps every transition plus the endpoints', () {
      // Value changes at indices 2, 4 and 6.
      final curve = [0.0, 0.0, 3.0, 3.0, 6.0, 6.0, 0.0, 0.0];
      expect(stepTransitionIndices(curve), [0, 2, 4, 6, 7]);
    });

    test('returns first and last index for a constant curve', () {
      expect(stepTransitionIndices([3.0, 3.0, 3.0]), [0, 2]);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/deco_stop_curve_test.dart 2>&1 | tail -20`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion' ... deco_stop_curve.dart` or "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/domain/services/deco_stop_curve.dart`:

```dart
import 'dart:math' as math;

/// Tolerance for treating a ceiling as sitting exactly on a stop boundary.
/// Buhlmann ceilings arrive as floating point, so a value that is 1e-9 above
/// a multiple of the stop increment must not be pushed to the next stop.
const double _stopEpsilon = 1e-6;

/// Quantize a decompression ceiling curve to discrete stop levels.
///
/// Each positive ceiling is rounded up to the next multiple of
/// [stopIncrement], which is how a dive computer presents a stop: a ceiling of
/// 4.2 m means the diver may not ascend above the 6 m stop. Zero and negative
/// values mean no obligation and become 0.0.
///
/// When [stopIncrement] is not positive the curve is returned unchanged, so a
/// misconfigured setting degrades to the raw ceiling rather than dividing by
/// zero.
List<double> quantizeCeilingToStops(
  List<double> ceilingCurve, {
  required double stopIncrement,
}) {
  if (stopIncrement <= 0) return List<double>.from(ceilingCurve);
  return [
    for (final ceiling in ceilingCurve)
      if (ceiling <= 0)
        0.0
      else
        (math.max(1, (ceiling / stopIncrement - _stopEpsilon).ceil())) *
            stopIncrement,
  ];
}

/// Indices at which a piecewise-constant curve changes value.
///
/// A stop curve is flat between transitions, so keeping only the transition
/// samples (plus the final index, which anchors the trailing segment) is a
/// lossless compression. The generic profile decimator is unsuitable here
/// because it can drop the exact sample where a step occurs, which would slant
/// the step edge.
List<int> stepTransitionIndices(List<double> curve) {
  if (curve.isEmpty) return const [];
  final indices = <int>[0];
  for (var i = 1; i < curve.length; i++) {
    if (curve[i] != curve[i - 1]) indices.add(i);
  }
  final lastIndex = curve.length - 1;
  if (indices.last != lastIndex) indices.add(lastIndex);
  return indices;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/deco_stop_curve_test.dart 2>&1 | tail -20`
Expected: PASS, "All tests passed!" with 13 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_log/domain/services/deco_stop_curve.dart test/features/dive_log/domain/services/deco_stop_curve_test.dart
git add lib/features/dive_log/domain/services/deco_stop_curve.dart test/features/dive_log/domain/services/deco_stop_curve_test.dart
git commit -m "feat(profile): add deco stop quantization and step transition helpers"
```

---

### Task 2: Carry `decoStopCurve` on `ProfileAnalysis`

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (field near line 210, constructor near line 289, `copyWith` near line 378, empty/fallback instances near lines 451 and 602, population near line 650, `ProfileAnalysis(...)` return near line 871)
- Test: `test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart`

**Interfaces:**
- Consumes: `quantizeCeilingToStops` from Task 1.
- Produces: `ProfileAnalysis.decoStopCurve` — a non-nullable `List<double>`, same length as `ceilingCurve`, defaulting to `const []`. Also a `decoStopCurve` parameter on `ProfileAnalysis.copyWith`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  test('decoStopCurve quantizes the calculated ceiling curve', () {
    const analysis = ProfileAnalysis(
      ascentRates: [],
      ascentRateStats: AscentRateStats(
        maxAscentRate: 0,
        averageAscentRate: 0,
        violationCount: 0,
      ),
      ascentRateViolations: [],
      events: [],
      ceilingCurve: [0.0, 4.2, 6.0, 0.0],
      ndlCurve: [],
      decoStatuses: [],
      o2Exposure: O2Exposure(cns: 0, otu: 0),
      ppO2Curve: [],
      decoStopCurve: [0.0, 6.0, 6.0, 0.0],
      maxDepth: 0,
      averageDepth: 0,
      maxDepthTimestamp: 0,
      durationSeconds: 0,
    );

    expect(analysis.decoStopCurve, [0.0, 6.0, 6.0, 0.0]);
  });

  test('copyWith replaces decoStopCurve', () {
    const analysis = ProfileAnalysis(
      ascentRates: [],
      ascentRateStats: AscentRateStats(
        maxAscentRate: 0,
        averageAscentRate: 0,
        violationCount: 0,
      ),
      ascentRateViolations: [],
      events: [],
      ceilingCurve: [],
      ndlCurve: [],
      decoStatuses: [],
      o2Exposure: O2Exposure(cns: 0, otu: 0),
      ppO2Curve: [],
      decoStopCurve: [3.0],
      maxDepth: 0,
      averageDepth: 0,
      maxDepthTimestamp: 0,
      durationSeconds: 0,
    );

    expect(analysis.copyWith(decoStopCurve: [9.0]).decoStopCurve, [9.0]);
    expect(analysis.copyWith().decoStopCurve, [3.0]);
  });
}
```

Note: the constructor arguments above mirror the required parameters of the current `ProfileAnalysis`. If a required parameter has been added or renamed since this plan was written, read the constructor at `profile_analysis_service.dart` around line 289 and adjust the literal — do not change the assertions.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart 2>&1 | tail -20`
Expected: FAIL — "No named parameter with the name 'decoStopCurve'".

- [ ] **Step 3: Add the field**

In `lib/features/dive_log/data/services/profile_analysis_service.dart`, directly after the `ceilingCurve` field declaration (around line 210):

```dart
  /// Decompression ceiling at each profile point (meters)
  final List<double> ceilingCurve;

  /// Decompression stop level at each profile point (meters).
  ///
  /// For calculated data this is [ceilingCurve] rounded up to the diver's stop
  /// increment, which is what the chart draws as a stepped band. For
  /// computer-sourced data the overlay in profile_analysis_provider.dart
  /// replaces it with the raw stop depths the computer reported.
  final List<double> decoStopCurve;
```

In the constructor (around line 289), after `required this.ceilingCurve,`:

```dart
    this.decoStopCurve = const [],
```

In `copyWith` (around line 378), after the `ceilingCurve` parameter:

```dart
    List<double>? decoStopCurve,
```

and in its returned instance, after `ceilingCurve: ceilingCurve ?? this.ceilingCurve,`:

```dart
      decoStopCurve: decoStopCurve ?? this.decoStopCurve,
```

- [ ] **Step 4: Populate it from the calculated ceiling**

Around line 650 the service already builds the ceiling curve:

```dart
    final ceilingCurve = decoStatuses.map((s) => s.ceilingMeters).toList();
```

Add immediately after it:

```dart
    final decoStopCurve = quantizeCeilingToStops(
      ceilingCurve,
      stopIncrement: decoStopIncrement,
    );
```

`decoStopIncrement` is already a parameter of this method (see line 480). Add the import at the top of the file, in the local relative-import group:

```dart
import '../../domain/services/deco_stop_curve.dart';
```

In the `ProfileAnalysis(...)` returned around line 871, after `ceilingCurve: ceilingCurve,`:

```dart
      decoStopCurve: decoStopCurve,
```

The empty/fallback instances near lines 451 and 602 already pass `ceilingCurve: []` / `const []`; leave them alone, since `decoStopCurve` defaults to `const []`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart 2>&1 | tail -20`
Expected: PASS, 2 tests.

- [ ] **Step 6: Run the wider analysis-service suite for regressions**

Run: `flutter test test/features/dive_log/ 2>&1 | tail -20; echo "EXIT=${PIPESTATUS[0]}"`
Expected: `EXIT=0`, all tests passing.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_deco_stops_test.dart
git commit -m "feat(profile): populate quantized decoStopCurve on ProfileAnalysis"
```

---

### Task 3: Source resolution for the stop curve

**Files:**
- Modify: `lib/core/constants/profile_metrics.dart:191-196` (add `decoStopActual` to `MetricSourceInfo`)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:396-461` (`overlayComputerDecoData`)
- Test: `test/features/dive_log/presentation/providers/deco_stop_source_test.dart`

**Interfaces:**
- Consumes: `ProfileAnalysis.decoStopCurve` from Task 2.
- Produces: a `decoStopSource` named parameter on `overlayComputerDecoData` (defaulting to `MetricDataSource.calculated`), and a `decoStopActual` field on `MetricSourceInfo`.

**Why this cannot reuse `ceilingSource`:** `overlayComputerDecoData` rewrites `analysis.ceilingCurve` with computer values when `ceilingSource == computer`. If the band derived from the post-overlay ceiling, choosing "computer" for the ceiling line would silently drag the band along with it. The band therefore resolves its own source against the incoming (calculated) `decoStopCurve`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/deco_stop_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_profile_point.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

ProfileAnalysis _analysis({
  required List<double> ceilingCurve,
  required List<double> decoStopCurve,
}) {
  return ProfileAnalysis(
    ascentRates: const [],
    ascentRateStats: const AscentRateStats(
      maxAscentRate: 0,
      averageAscentRate: 0,
      violationCount: 0,
    ),
    ascentRateViolations: const [],
    events: const [],
    ceilingCurve: ceilingCurve,
    ndlCurve: const [],
    decoStatuses: const [],
    o2Exposure: const O2Exposure(cns: 0, otu: 0),
    ppO2Curve: const [],
    decoStopCurve: decoStopCurve,
    maxDepth: 0,
    averageDepth: 0,
    maxDepthTimestamp: 0,
    durationSeconds: 0,
  );
}

DiveProfilePoint _point({required int timestamp, double? ceiling}) {
  return DiveProfilePoint(
    timestamp: timestamp,
    depth: 30,
    ceiling: ceiling,
  );
}

void main() {
  group('deco stop source resolution', () {
    test('calculated source keeps the quantized curve', () {
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 4.5),
      ];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.calculated,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
      expect(sources.decoStopActual, MetricDataSource.calculated);
    });

    test('calculated source is unaffected by a computer ceiling source', () {
      // Regression guard: selecting "computer" for the ceiling line must not
      // change the band when the band is set to calculated.
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 4.5),
      ];
      final (result, _) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        ceilingSource: MetricDataSource.computer,
        decoStopSource: MetricDataSource.calculated,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
    });

    test('computer source uses raw DC stop depths without rounding', () {
      // 4.5 m is a legitimate non-3m stop on some computers and must survive.
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 3.0),
      ];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 2.1], decoStopCurve: [6.0, 3.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [4.5, 3.0]);
      expect(sources.decoStopActual, MetricDataSource.computer);
    });

    test('computer source treats a missing DC ceiling as no obligation', () {
      final profile = [
        _point(timestamp: 0, ceiling: 6.0),
        _point(timestamp: 10, ceiling: null),
      ];
      final (result, _) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [6.0, 0.0]);
    });

    test('computer source falls back when the dive has no DC ceiling', () {
      final profile = [
        _point(timestamp: 0),
        _point(timestamp: 10),
      ];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
      expect(sources.decoStopActual, MetricDataSource.calculated);
    });
  });
}
```

Note: `DiveProfilePoint`'s constructor may require more parameters than `timestamp`, `depth` and `ceiling`. Read the entity and fill in whatever else is required in the `_point` helper only — do not change the assertions.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/deco_stop_source_test.dart 2>&1 | tail -20`
Expected: FAIL — "No named parameter with the name 'decoStopSource'".

- [ ] **Step 3: Extend `MetricSourceInfo`**

In `lib/core/constants/profile_metrics.dart`, replace the typedef at lines 191-196 with:

```dart
typedef MetricSourceInfo = ({
  MetricDataSource ndlActual,
  MetricDataSource ceilingActual,
  MetricDataSource ttsActual,
  MetricDataSource cnsActual,
  MetricDataSource decoStopActual,
});
```

This is a record type, so every construction site must now supply `decoStopActual`. Find them with:

```bash
grep -rn "ceilingActual:" lib test --include=*.dart
```

Update each one. The construction inside `overlayComputerDecoData` is handled in Step 4; any other site that builds a `MetricSourceInfo` literal gets `decoStopActual: MetricDataSource.calculated` unless it is specifically about deco stops.

- [ ] **Step 4: Resolve the source in `overlayComputerDecoData`**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, add the parameter to the signature (after `ceilingSource`, around line 400):

```dart
  MetricDataSource decoStopSource = MetricDataSource.calculated,
```

After the existing `hasComputerCeiling` line (around line 406) the same flag serves the band, since both read `p.ceiling`. Add the use flag after `useCeiling` (around line 414):

```dart
  final useDecoStop =
      decoStopSource == MetricDataSource.computer && hasComputerCeiling;
```

Add the reported source to the `sourceInfo` record (around line 430):

```dart
    decoStopActual: useDecoStop
        ? MetricDataSource.computer
        : MetricDataSource.calculated,
```

Include the new flag in the early-return guard (around line 439):

```dart
  if (!useNdl &&
      !useCeiling &&
      !useDecoStop &&
      !useTts &&
      !useCns &&
      resolvedPpO2 == null) {
    return (analysis, sourceInfo);
  }
```

Add the curve to the `copyWith` (around line 452, after the `ceilingCurve` entry):

```dart
    decoStopCurve: useDecoStop
        ? List<double>.generate(
            profile.length,
            // Raw DC stop depth, deliberately not re-quantized: some computers
            // use non-3m stop spacing and rounding would misreport what the
            // diver actually saw. A null means no obligation at that sample.
            (i) => profile[i].ceiling ?? 0.0,
          )
        : null,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/deco_stop_source_test.dart 2>&1 | tail -20`
Expected: PASS, 5 tests.

- [ ] **Step 6: Verify nothing else broke on the record change**

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!" — any remaining `MetricSourceInfo` literal missing `decoStopActual` shows up here.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/core/constants/profile_metrics.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/deco_stop_source_test.dart
git add lib/core/constants/profile_metrics.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/deco_stop_source_test.dart
git commit -m "feat(profile): resolve deco stop band source independently of ceiling"
```

---

### Task 4: Schema v130 — two diver_settings columns

**Files:**
- Modify: `lib/core/database/database.dart` (table columns near line 1497, new helper near line 3335, `currentSchemaVersion` at line 2817, onUpgrade tail near line 6698, beforeOpen backstop tail near line 6788)
- Modify: `lib/core/services/sync/sync_data_serializer.dart:5086` (defaults map)
- Create: `test/core/database/migration_v130_deco_stops_test.dart`
- Modify: `test/core/database/migration_v129_quality_findings_test.dart:52-58` (relax the tripwire)
- Modify: `test/core/services/sync/sync_diver_settings_fallback_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `DiverSettings.showDecoStopsOnProfile` (bool, default true) and `DiverSettings.defaultDecoStopSource` (int, default 1 = calculated) on the Drift table, plus `AppDatabase.currentSchemaVersion == 130`.

**Why the ceremony:** this repo has been bitten by every one of these four steps. Bare `m.addColumn` crashes partial-schema migration tests that instantiate old databases without unrelated tables; a missing backstop call leaves parallel-branch databases without the column; the tripwire test is skipped on Windows so a stale version only fails on CI; and an unseeded non-nullable key makes `DiverSetting.fromJson` throw on pre-column sync payloads.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v130_deco_stops_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  test('diver_settings has the deco stop band columns', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final cols = [for (final r in rows) r.read<String>('name')];
    expect(cols, contains('show_deco_stops_on_profile'));
    expect(cols, contains('default_deco_stop_source'));
  });

  test('deco stop columns default to visible and calculated', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {
      for (final r in rows) r.read<String>('name'): r.read<String?>('dflt_value'),
    };
    expect(byName['show_deco_stops_on_profile'], '1');
    expect(byName['default_deco_stop_source'], '1');
  });

  test('v130 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v130.
    expect(AppDatabase.currentSchemaVersion, 130);
    expect(AppDatabase.migrationVersions, contains(130));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v130_deco_stops_test.dart 2>&1 | tail -20`
Expected: FAIL — the column assertions fail and the tripwire reports `129` where `130` was expected.

- [ ] **Step 3: Add the table columns**

In `lib/core/database/database.dart`, after `IntColumn get defaultCnsSource => integer().withDefault(const Constant(1))();` (around line 1500):

```dart
  // Deco stop band on the profile chart (v130). Source is a MetricDataSource
  // index: 0 = computer, 1 = calculated.
  BoolColumn get showDecoStopsOnProfile =>
      boolean().withDefault(const Constant(true))();
  IntColumn get defaultDecoStopSource =>
      integer().withDefault(const Constant(1))();
```

- [ ] **Step 4: Bump the schema version**

At line 2817, change:

```dart
  static const int currentSchemaVersion = 130;
```

Then find the `migrationVersions` list in the same file and add `130` to it:

```bash
grep -n "migrationVersions" lib/core/database/database.dart
```

- [ ] **Step 5: Add the guarded, idempotent helper**

In `lib/core/database/database.dart`, after `_assertNoFlySettingsColumn` (around line 3350), following the exact pattern of `_assertCnsCalculationMethodColumn`:

```dart
  /// v130: diver_settings deco stop band columns. PRAGMA-guarded and
  /// idempotent so it is safe to call from both onUpgrade and the beforeOpen
  /// backstop. The guard on cols.isNotEmpty keeps partial-schema migration
  /// tests, which open databases without this table, from crashing on DDL.
  Future<void> _assertDecoStopSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('show_deco_stops_on_profile')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_deco_stops_on_profile '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (show_deco_stops_on_profile IN (0, 1))',
      );
    }
    if (cols.isNotEmpty && !names.contains('default_deco_stop_source')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_deco_stop_source '
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
  }
```

- [ ] **Step 6: Call the helper from both onUpgrade and the backstop**

In the `onUpgrade` block, immediately after the `if (from < 129)` section (around line 6698):

```dart
        // v130: deco stop band columns on diver_settings.
        if (from < 130) {
          await _assertDecoStopSettingsColumns();
        }
        if (from < 130) await reportProgress();
```

In the `beforeOpen` backstop section, immediately after the v129 backstop line (around line 6788):

```dart
        // v130 backstop: re-assert the deco stop band settings columns.
        await _assertDecoStopSettingsColumns();
```

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10`
Expected: "Succeeded after ..." with `database.g.dart` regenerated.

- [ ] **Step 8: Relax the v129 tripwire**

In `test/core/database/migration_v129_quality_findings_test.dart`, replace the body of the tripwire test (lines 52-58) with:

```dart
  test('v129 migration is registered', () {
    // Relaxed from the exact-latest tripwire when v130 (deco stop band
    // settings) landed on top. The exact-latest assertion now lives in
    // migration_v130_deco_stops_test.dart.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(129));
    expect(AppDatabase.migrationVersions, contains(129));
  });
```

- [ ] **Step 9: Seed the sync defaults**

In `lib/core/services/sync/sync_data_serializer.dart`, in `_applyDiverSettingDefaults`, immediately after the `'cnsCalculationMethod': 'shearwater',` entry (around line 5086):

```dart
      // v130: non-nullable columns; seed them so payloads predating the
      // columns hydrate instead of throwing in DiverSetting.fromJson.
      'showDecoStopsOnProfile': true,
      'defaultDecoStopSource': 1,
```

- [ ] **Step 10: Add the legacy-payload test**

Append to `test/core/services/sync/sync_diver_settings_fallback_test.dart`, matching the existing tests' style in that file (read it first and mirror how it builds a payload and invokes the importer):

```dart
  test('legacy payload without deco stop keys imports with defaults', () async {
    // A payload exported before v130 has neither key. Both columns are NOT
    // NULL, so an unseeded import would throw in DiverSetting.fromJson.
    final legacy = buildLegacyDiverSettingsPayload()
      ..remove('showDecoStopsOnProfile')
      ..remove('defaultDecoStopSource');

    await expectLater(importDiverSettings(legacy), completes);

    final stored = await db.select(db.diverSettings).getSingle();
    expect(stored.showDecoStopsOnProfile, isTrue);
    expect(stored.defaultDecoStopSource, 1);
  });
```

Adapt `buildLegacyDiverSettingsPayload` and `importDiverSettings` to whatever helper names that file already uses. Keep the two assertions.

- [ ] **Step 11: Run the database and sync suites**

Run: `flutter test test/core/database/ test/core/services/sync/ 2>&1 | tail -20; echo "EXIT=${PIPESTATUS[0]}"`
Expected: `EXIT=0`. The v130 test passes, the relaxed v129 test passes, and the partial-schema migration tests stay green.

- [ ] **Step 12: Format and commit**

```bash
dart format lib/core/database/database.dart lib/core/services/sync/sync_data_serializer.dart test/core/database/migration_v130_deco_stops_test.dart test/core/database/migration_v129_quality_findings_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/services/sync/sync_data_serializer.dart test/core/database/migration_v130_deco_stops_test.dart test/core/database/migration_v129_quality_findings_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart
git commit -m "feat(db): add deco stop band settings columns (schema v130)"
```

---

### Task 5: Settings state plumbing

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (key constant near line 69, fields near lines 133/180, defaults near lines 389/404, `copyWith` near lines 533/549 and 645/663, setters near lines 1103/1196, derived provider near line 1640)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (write sites near lines 88/104 and 234/252, read site near lines 422/441)
- Test: `test/features/settings/deco_stop_settings_test.dart`

**Interfaces:**
- Consumes: the Drift columns from Task 4.
- Produces: `AppSettings.showDecoStopsOnProfile` (bool) and `AppSettings.defaultDecoStopSource` (`MetricDataSource`); notifier methods `setShowDecoStopsOnProfile(bool)` and `setDefaultDecoStopSource(MetricDataSource)`; provider `showDecoStopsOnProfileProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/deco_stop_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('deco stop settings default to visible and calculated', () {
    const settings = AppSettings();
    expect(settings.showDecoStopsOnProfile, isTrue);
    expect(settings.defaultDecoStopSource, MetricDataSource.calculated);
  });

  test('copyWith updates the deco stop settings independently', () {
    const settings = AppSettings();

    final hidden = settings.copyWith(showDecoStopsOnProfile: false);
    expect(hidden.showDecoStopsOnProfile, isFalse);
    expect(hidden.defaultDecoStopSource, MetricDataSource.calculated);
    expect(hidden.showCeilingOnProfile, settings.showCeilingOnProfile);

    final computer = settings.copyWith(
      defaultDecoStopSource: MetricDataSource.computer,
    );
    expect(computer.defaultDecoStopSource, MetricDataSource.computer);
    expect(computer.defaultCeilingSource, settings.defaultCeilingSource);
    expect(computer.showDecoStopsOnProfile, isTrue);
  });
}
```

Note: if `AppSettings` cannot be built with no arguments, read its constructor and supply the required arguments. Keep the assertions.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/deco_stop_settings_test.dart 2>&1 | tail -20`
Expected: FAIL — "The getter 'showDecoStopsOnProfile' isn't defined for the class 'AppSettings'".

- [ ] **Step 3: Add the settings key constants**

In `lib/features/settings/presentation/providers/settings_providers.dart`, next to `showCeilingOnProfile` (around line 69):

```dart
  static const String showDecoStopsOnProfile = 'show_deco_stops_on_profile';
  static const String defaultDecoStopSource = 'default_deco_stop_source';
```

- [ ] **Step 4: Add the fields, defaults and copyWith entries**

After the `showCeilingOnProfile` field (around line 133):

```dart
  final bool showDecoStopsOnProfile;
```

After the `defaultCeilingSource` field (around line 180):

```dart
  final MetricDataSource defaultDecoStopSource;
```

In the constructor, after `this.showCeilingOnProfile = true,` (around line 389):

```dart
    this.showDecoStopsOnProfile = true,
```

and after `this.defaultCeilingSource = MetricDataSource.calculated,` (around line 404):

```dart
    this.defaultDecoStopSource = MetricDataSource.calculated,
```

In `copyWith`'s parameter list, after the matching `showCeilingOnProfile` (line 533) and `defaultCeilingSource` (line 549) entries:

```dart
    bool? showDecoStopsOnProfile,
```
```dart
    MetricDataSource? defaultDecoStopSource,
```

and in its returned instance, after the matching lines 645 and 663:

```dart
      showDecoStopsOnProfile:
          showDecoStopsOnProfile ?? this.showDecoStopsOnProfile,
```
```dart
      defaultDecoStopSource: defaultDecoStopSource ?? this.defaultDecoStopSource,
```

- [ ] **Step 5: Add the notifier setters and derived provider**

Next to `setShowCeilingOnProfile` (around line 1103), mirroring its body including whatever persistence call it makes:

```dart
  Future<void> setShowDecoStopsOnProfile(bool value) async {
    state = state.copyWith(showDecoStopsOnProfile: value);
    await _persist();
  }
```

Next to `setDefaultCeilingSource` (around line 1196):

```dart
  Future<void> setDefaultDecoStopSource(MetricDataSource value) async {
    state = state.copyWith(defaultDecoStopSource: value);
    await _persist();
  }
```

Read the two neighbouring setters first and copy their exact persistence mechanism — `_persist()` above is a placeholder for whatever they actually call.

Next to `showCeilingOnProfileProvider` (around line 1640):

```dart
final showDecoStopsOnProfileProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showDecoStopsOnProfile));
});
```

- [ ] **Step 6: Wire the repository**

In `lib/features/settings/data/repositories/diver_settings_repository.dart`, add to both write sites (after line 88 and after line 234 respectively):

```dart
              showDecoStopsOnProfile: Value(s.showDecoStopsOnProfile),
```
```dart
          showDecoStopsOnProfile: Value(settings.showDecoStopsOnProfile),
```

and next to the `defaultCeilingSource` writes at lines 104 and 252:

```dart
              defaultDecoStopSource: Value(s.defaultDecoStopSource.toInt()),
```
```dart
          defaultDecoStopSource: Value(settings.defaultDecoStopSource.toInt()),
```

At the read site, next to lines 422 and 441:

```dart
      showDecoStopsOnProfile: row.showDecoStopsOnProfile,
      defaultDecoStopSource: MetricDataSource.fromInt(
        row.defaultDecoStopSource,
      ),
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/settings/deco_stop_settings_test.dart 2>&1 | tail -20`
Expected: PASS, 2 tests.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/features/settings/ test/features/settings/deco_stop_settings_test.dart
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart test/features/settings/deco_stop_settings_test.dart
git commit -m "feat(settings): add deco stop band visibility and source settings"
```

---

### Task 6: The stepped band renderer

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/deco_stop_band.dart`
- Test: `test/features/dive_log/presentation/widgets/deco_stop_band_test.dart`

**Interfaces:**
- Consumes: `stepTransitionIndices` from Task 1.
- Produces: `LineChartBarData buildDecoStopBand({required List<double> decoStopCurve, required List<int> timestamps, required UnitFormatter units})` and the constant `decoStopBandColor`.

**Rendering notes:** depths are negated for the chart's inverted Y axis, exactly as `_buildCeilingLine` does. `belowBarData` with `cutOffY: 0` fills from the stop depth up to the surface. Samples where the curve is 0 sit at y=0, so the band naturally collapses to nothing when there is no obligation, with no gap handling required.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/deco_stop_band_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';

void main() {
  late UnitFormatter units;

  setUp(() {
    units = metricUnitFormatter();
  });

  test('produces a step line chart bar filled to the surface', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [0.0, 3.0, 3.0, 0.0],
      timestamps: [0, 10, 20, 30],
      units: units,
    );

    expect(bar.isStepLineChart, isTrue);
    expect(bar.belowBarData.show, isTrue);
    expect(bar.belowBarData.applyCutOffY, isTrue);
    expect(bar.belowBarData.cutOffY, 0);
  });

  test('negates depth for the inverted Y axis', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [6.0, 6.0],
      timestamps: [0, 10],
      units: units,
    );

    expect(bar.spots.first.y, -6.0);
  });

  test('keeps every step transition after decimation', () {
    // Long flat runs must compress, but the samples at 2, 4 and 6 are where
    // the level changes and must survive so the step edges stay vertical.
    final curve = [0.0, 0.0, 3.0, 3.0, 6.0, 6.0, 0.0, 0.0];
    final timestamps = [0, 10, 20, 30, 40, 50, 60, 70];

    final bar = buildDecoStopBand(
      decoStopCurve: curve,
      timestamps: timestamps,
      units: units,
    );

    final xs = bar.spots.map((s) => s.x).toList();
    expect(xs, [0.0, 20.0, 40.0, 60.0, 70.0]);
  });

  test('an all-zero curve produces no visible band', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [0.0, 0.0, 0.0],
      timestamps: [0, 10, 20],
      units: units,
    );

    expect(bar.spots.every((s) => s.y == 0), isTrue);
  });

  test('an empty curve produces no spots', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [],
      timestamps: [],
      units: units,
    );

    expect(bar.spots, isEmpty);
  });

  test('ignores curve entries beyond the timestamp list', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [3.0, 3.0, 6.0],
      timestamps: [0, 10],
      units: units,
    );

    expect(bar.spots.every((s) => s.x <= 10), isTrue);
  });
}
```

Note: `metricUnitFormatter()` is a placeholder. Read how other tests in `test/features/dive_log/presentation/` construct a `UnitFormatter` and use that exact construction. Keep the assertions.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/deco_stop_band_test.dart 2>&1 | tail -20`
Expected: FAIL — "Target of URI doesn't exist: 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/presentation/widgets/deco_stop_band.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../domain/services/deco_stop_curve.dart';

/// Red 700, matching the ceiling line so the band and the curve read as one
/// decompression concept. Green was rejected because it already denotes NDL.
const Color decoStopBandColor = Color(0xFFD32F2F);

/// Opacity of the shaded region between the stop depth and the surface.
const double _decoStopFillAlpha = 0.18;

/// Build the stepped deco stop band for the profile chart.
///
/// The curve is piecewise constant, so it is compressed to its transitions
/// rather than run through the generic profile decimator, which could drop the
/// exact sample where a step occurs and slant the edge.
///
/// Depths are negated because the chart's Y axis is inverted, and the fill
/// runs up to `cutOffY: 0` (the surface). Samples with no obligation sit at 0,
/// so the band collapses to zero height on its own.
LineChartBarData buildDecoStopBand({
  required List<double> decoStopCurve,
  required List<int> timestamps,
  required UnitFormatter units,
}) {
  final length = decoStopCurve.length < timestamps.length
      ? decoStopCurve.length
      : timestamps.length;
  final curve = decoStopCurve.sublist(0, length);

  final spots = [
    for (final i in stepTransitionIndices(curve))
      FlSpot(
        timestamps[i].toDouble(),
        -units.convertDepth(curve[i]),
      ),
  ];

  return LineChartBarData(
    spots: spots,
    isCurved: false,
    isStepLineChart: true,
    // 0 holds each stop value forward from its sample until the next
    // transition, so the vertical edge lands where the level actually changes.
    lineChartStepData: const LineChartStepData(stepDirection: 0),
    color: decoStopBandColor,
    barWidth: 1.5,
    isStrokeCapRound: false,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      color: decoStopBandColor.withValues(alpha: _decoStopFillAlpha),
      cutOffY: 0, // Fill from the stop depth up to the surface
      applyCutOffY: true,
    ),
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/deco_stop_band_test.dart 2>&1 | tail -20`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_log/presentation/widgets/deco_stop_band.dart test/features/dive_log/presentation/widgets/deco_stop_band_test.dart
git add lib/features/dive_log/presentation/widgets/deco_stop_band.dart test/features/dive_log/presentation/widgets/deco_stop_band_test.dart
git commit -m "feat(profile): add stepped deco stop band renderer"
```

---

### Task 7: Wire the band into the chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (fields near line 78, constructor near line 441, state field near line 501, `initState` near line 927, legend sync near line 1500, cache keys near line 1551, legend config near line 1599, bar list near line 2333, tooltip near line 2732)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1627`
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:329`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart:372`
- Modify: `lib/l10n/arb/app_en.arb` and the other ten ARB files
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart`

**Interfaces:**
- Consumes: `buildDecoStopBand` and `decoStopBandColor` from Task 6; `ProfileAnalysis.decoStopCurve` from Tasks 2 and 3.
- Produces: `DiveProfileChart.decoStopCurve` (`List<double>?`) and `DiveProfileChart.showDecoStops` (`bool`, default true).

- [ ] **Step 1: Add the l10n strings**

In `lib/l10n/arb/app_en.arb`, next to `"diveLog_legend_label_ceiling"` (line 2759):

```json
  "diveLog_legend_label_decoStops": "Deco stops",
```

and next to `"diveLog_tooltip_ceiling"` (line 3397):

```json
  "diveLog_tooltip_decoStop": "Deco stop",
```

Add matching `@`-metadata entries if the neighbouring keys have them — check the lines directly after each existing key. Then add both keys to the other ten ARB files (`app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`) with the same English strings, which is what `app_de.arb` already does for `diveLog_legend_label_ceiling`. Translation follows separately.

Regenerate: `flutter gen-l10n 2>&1 | tail -5`

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart`. Read `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart` first and mirror its harness exactly — how it wraps the chart in `ProviderScope` and localization delegates, how it builds a sample profile, and how it pumps. `buildChartHarness` and `sampleProfileWithDeco` below are stand-ins for that file's actual setup; replace them with the real thing, extended so the profile dips into deco. The assertions are what matter and must be kept as written:

```dart
  testWidgets('renders the deco stop band beneath the ceiling line', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildChartHarness(
        profile: sampleProfileWithDeco(),
        ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
        decoStopCurve: const [0.0, 6.0, 6.0, 0.0],
        showDecoStops: true,
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData;
    final bandIndex = bars.indexWhere((b) => b.isStepLineChart);
    final ceilingIndex = bars.indexWhere((b) => b.dashArray != null);

    expect(bandIndex, isNonNegative, reason: 'deco stop band should render');
    expect(
      bandIndex,
      lessThan(ceilingIndex),
      reason: 'band draws first so the dashed ceiling stays legible on top',
    );
  });

  testWidgets('omits the band when showDecoStops is false', (tester) async {
    await tester.pumpWidget(
      buildChartHarness(
        profile: sampleProfileWithDeco(),
        ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
        decoStopCurve: const [0.0, 6.0, 6.0, 0.0],
        showDecoStops: false,
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.any((b) => b.isStepLineChart), isFalse);
  });

  testWidgets('omits the band when no curve is supplied', (tester) async {
    await tester.pumpWidget(
      buildChartHarness(
        profile: sampleProfileWithDeco(),
        ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
        decoStopCurve: null,
        showDecoStops: true,
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.any((b) => b.isStepLineChart), isFalse);
  });
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart 2>&1 | tail -20`
Expected: FAIL — "No named parameter with the name 'decoStopCurve'".

- [ ] **Step 4: Add the widget parameters**

In `dive_profile_chart.dart`, after the `ceilingCurve` field (around line 78):

```dart
  /// Deco stop levels in meters, same length as profile. Drawn as a stepped
  /// band from the stop depth up to the surface.
  final List<double>? decoStopCurve;
```

After the `showCeiling` field (around line 99):

```dart
  /// Whether to show the stepped deco stop band by default
  final bool showDecoStops;
```

In the constructor, after `this.ceilingCurve,` (around line 441):

```dart
    this.decoStopCurve,
```

and after `this.showCeiling = true,`:

```dart
    this.showDecoStops = true,
```

Add the import in the local relative group:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
```

- [ ] **Step 5: Add the runtime toggle state**

After the `_showCeiling` state field (around line 501):

```dart
  bool _showDecoStops = true;
```

In `initState`, after `_showCeiling = widget.showCeiling;` (around line 927):

```dart
    _showDecoStops = widget.showDecoStops;
```

In the rebuild cache-key list, after `identityHashCode(widget.ceilingCurve),` (around line 1551):

```dart
      identityHashCode(widget.decoStopCurve),
```

Do **not** touch the legend-sync block (around line 1500) or the legend config construction (around line 1599) in this task. Both depend on fields that Task 8 adds to `ProfileLegendState` and `ProfileLegendConfig`, and wiring them here would leave the tree uncompilable. Task 8 does it.

- [ ] **Step 6: Draw the band**

In the `lineBarsData` list, immediately **before** the existing ceiling entry (around line 2333), so the band draws underneath:

```dart
                    // Deco stop band, drawn before the ceiling line so the
                    // dashed curve stays legible on top of the fill.
                    if (_showDecoStops && widget.decoStopCurve != null)
                      buildDecoStopBand(
                        decoStopCurve: widget.decoStopCurve!,
                        timestamps: [
                          for (final p in widget.profile) p.timestamp,
                        ],
                        units: units,
                      ),
                    // Ceiling line (if showing and data available)
                    if (_showCeiling && widget.ceilingCurve != null)
                      _buildCeilingLine(units),
```

- [ ] **Step 7: Add the tooltip row**

In the tooltip builder, immediately after the ceiling row block (around line 2732-2745):

```dart
                    // Deco stop (if enabled - always show row)
                    if (_showDecoStops) {
                      String stopValue = '—';
                      if (widget.decoStopCurve != null &&
                          spot.spotIndex < widget.decoStopCurve!.length) {
                        final stop = widget.decoStopCurve![spot.spotIndex];
                        if (stop > 0) {
                          stopValue = units.formatDepth(stop);
                        }
                      }
                      rows.add(
                        _buildTooltipRow(
                          context.l10n.diveLog_tooltip_decoStop,
                          stopValue,
                        ),
                      );
                    }
```

Read the surrounding ceiling block first and match its exact row-construction call; `rows.add(_buildTooltipRow(...))` above reflects the shape at line 2741 but the local variable name may differ.

- [ ] **Step 8: Pass the curve from all three call sites**

In `dive_detail_page.dart` after line 1627, `fullscreen_profile_page.dart` after line 329, and `dive_profile_panel.dart` after line 372, add below each `ceilingCurve: analysis?.ceilingCurve,`:

```dart
                        decoStopCurve: analysis?.decoStopCurve,
```

Match each file's existing indentation.

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart 2>&1 | tail -20`
Expected: PASS, 3 tests.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/features/dive_log/ lib/l10n/ test/features/dive_log/
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/l10n/arb/ lib/l10n/app_localizations*.dart test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart
git commit -m "feat(profile): draw the deco stop band on the dive profile chart"
```

---

### Task 8: Legend and settings UI

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (fields near lines 25/57, defaults near lines 76/99, `copyWith` near lines 152/174 and 189/212, equality near lines 230/253, hashCode near lines 266/289, settings hydration near lines 320/343 and 353/377, notifier methods near lines 414/505)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` (config field near lines 18/52/83, count near line 306, entry near line 628)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (legend sync near line 1500, legend config near line 1599 — deferred from Task 7)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (watch near line 898, pass-through near line 1001)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:966` (source dropdown)
- Modify: `lib/features/settings/presentation/pages/default_visible_metrics_page.dart:68` (visibility switch)
- Test: `test/features/dive_log/presentation/providers/profile_legend_deco_stop_test.dart`

**Interfaces:**
- Consumes: `AppSettings.showDecoStopsOnProfile` / `defaultDecoStopSource` from Task 5; `decoStopSource` on `overlayComputerDecoData` from Task 3.
- Produces: `ProfileLegendState.showDecoStops` (bool) and `decoStopSource` (`MetricDataSource`); notifier methods `toggleDecoStops()` and `setDecoStopSource(MetricDataSource)`; `ProfileLegendConfig.hasDecoStopCurve` (bool, default false).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/profile_legend_deco_stop_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

void main() {
  test('deco stop legend state defaults to visible and calculated', () {
    const state = ProfileLegendState();
    expect(state.showDecoStops, isTrue);
    expect(state.decoStopSource, MetricDataSource.calculated);
  });

  test('copyWith toggles deco stops without touching the ceiling', () {
    const state = ProfileLegendState();
    final updated = state.copyWith(showDecoStops: false);

    expect(updated.showDecoStops, isFalse);
    expect(updated.showCeiling, state.showCeiling);
  });

  test('deco stop source is independent of the ceiling source', () {
    const state = ProfileLegendState();
    final updated = state.copyWith(
      decoStopSource: MetricDataSource.computer,
    );

    expect(updated.decoStopSource, MetricDataSource.computer);
    expect(updated.ceilingSource, MetricDataSource.calculated);
  });

  test('equality accounts for the deco stop fields', () {
    const state = ProfileLegendState();
    expect(state.copyWith(showDecoStops: false) == state, isFalse);
    expect(
      state.copyWith(decoStopSource: MetricDataSource.computer) == state,
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_deco_stop_test.dart 2>&1 | tail -20`
Expected: FAIL — "The getter 'showDecoStops' isn't defined for the class 'ProfileLegendState'".

- [ ] **Step 3: Extend the legend state**

In `profile_legend_provider.dart`, add next to each `showCeiling` / `ceilingSource` occurrence at the line numbers listed under Files:

Field declarations:

```dart
  final bool showDecoStops;
```
```dart
  final MetricDataSource decoStopSource;
```

Constructor defaults:

```dart
    this.showDecoStops = true,
```
```dart
    this.decoStopSource = MetricDataSource.calculated,
```

`copyWith` parameters and assignments:

```dart
    bool? showDecoStops,
```
```dart
    MetricDataSource? decoStopSource,
```
```dart
      showDecoStops: showDecoStops ?? this.showDecoStops,
```
```dart
      decoStopSource: decoStopSource ?? this.decoStopSource,
```

Equality operands and hashCode entries:

```dart
          showDecoStops == other.showDecoStops &&
```
```dart
          decoStopSource == other.decoStopSource &&
```
```dart
    showDecoStops,
```
```dart
    decoStopSource,
```

Note: `hashCode` here uses `Object.hash`/`Object.hashAll` with a fixed argument list. If adding two entries pushes it past the 20-argument limit of `Object.hash`, convert the call to `Object.hashAll([...])` with the same operands in the same order.

Settings hydration, next to `showCeilingOnProfile: s.showCeilingOnProfile,` and `defaultCeilingSource: s.defaultCeilingSource,`:

```dart
          showDecoStopsOnProfile: s.showDecoStopsOnProfile,
```
```dart
          defaultDecoStopSource: s.defaultDecoStopSource,
```

and next to `showCeiling: settings.showCeilingOnProfile,` / `ceilingSource: settings.defaultCeilingSource,`:

```dart
      showDecoStops: settings.showDecoStopsOnProfile,
```
```dart
      decoStopSource: settings.defaultDecoStopSource,
```

Also add the `showDecoStops` counter next to the `if (showCeiling) count++;` line (around line 118):

```dart
    if (showDecoStops) count++;
```

- [ ] **Step 4: Add the notifier methods**

Next to `toggleCeiling` (around line 414) and `setCeilingSource` (around line 505), mirroring their exact bodies including any persistence:

```dart
  void toggleDecoStops() {
    state = state.copyWith(showDecoStops: !state.showDecoStops);
  }
```
```dart
  void setDecoStopSource(MetricDataSource source) {
    state = state.copyWith(decoStopSource: source);
  }
```

Read the two originals and copy whatever they do beyond setting state.

- [ ] **Step 5: Feed the source into the analysis provider**

In `profile_analysis_provider.dart`, next to the `ceilingSource` watch (around line 898):

```dart
    final decoStopSource = ref.watch(
      profileLegendProvider.select((s) => s.decoStopSource),
    );
```

and next to the `ceilingSource: ceilingSource,` argument (around line 1001):

```dart
      decoStopSource: decoStopSource,
```

- [ ] **Step 6: Add the legend entry**

In `dive_profile_legend.dart`, add the config field next to `hasCeilingCurve` at lines 18, 52 and 83:

```dart
  final bool hasDecoStopCurve;
```
```dart
    this.hasDecoStopCurve = false,
```
```dart
      hasDecoStopCurve ||
```

Next to the count at line 306:

```dart
    if (config.hasDecoStopCurve && legendState.showDecoStops) count++;
```

And in the decompression section, immediately before the `hasCeilingCurve` entry at line 628:

```dart
      if (config.hasDecoStopCurve)
        _buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_decoStops,
          color: decoStopBandColor,
          isEnabled: legendState.showDecoStops,
          onTap: legendNotifier.toggleDecoStops,
          currentSource: legendState.decoStopSource,
          onSourceChanged: legendNotifier.setDecoStopSource,
        ),
```

Add the import:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
```

- [ ] **Step 7: Connect the chart to the legend**

These two edits were deliberately deferred from Task 7 because they depend on the state and config fields added above.

In `dive_profile_chart.dart`, in the legend-sync block, after `_showCeiling = legendState.showCeiling;` (around line 1500):

```dart
      _showDecoStops = legendState.showDecoStops;
```

and in the legend config construction, after `hasCeilingCurve: widget.ceilingCurve != null,` (around line 1599):

```dart
      hasDecoStopCurve: widget.decoStopCurve != null,
```

- [ ] **Step 8: Add the settings UI**

In `settings_page.dart`, immediately after the Ceiling Source dropdown block (lines 964-971):

```dart
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: 'Deco Stop Source',
                  value: settings.defaultDecoStopSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultDecoStopSource(source),
                ),
```

In `default_visible_metrics_page.dart`, immediately after the ceiling switch block at line 68, copy that block verbatim and change only the label, the value and the setter:

```dart
            value: settings.showDecoStopsOnProfile,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setShowDecoStopsOnProfile(v),
```

Read lines 60-80 of that file first to get the surrounding widget and label mechanism right.

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_deco_stop_test.dart 2>&1 | tail -20`
Expected: PASS, 4 tests.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/features/dive_log/ lib/features/settings/ test/features/dive_log/
git add lib/features/dive_log/presentation/providers/profile_legend_provider.dart lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/providers/profile_analysis_provider.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/pages/default_visible_metrics_page.dart test/features/dive_log/presentation/providers/profile_legend_deco_stop_test.dart
git commit -m "feat(profile): add deco stop band toggles to legend and settings"
```

---

### Task 9: Full verification

**Files:** none created or modified unless a failure demands it.

- [ ] **Step 1: Confirm formatting is clean**

Run: `dart format --set-exit-if-changed lib/ test/ 2>&1 | tail -10; echo "EXIT=$?"`
Expected: `EXIT=0` and no files listed as changed.

- [ ] **Step 2: Confirm static analysis is clean**

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!"

- [ ] **Step 3: Run the full test suite with the real exit code**

Run: `flutter test 2>&1 | tail -30; echo "EXIT=${PIPESTATUS[0]}"`
Expected: `EXIT=0`, "All tests passed!"

If anything fails, fix it and re-run this step. Do not report the work as complete on a non-zero exit code.

- [ ] **Step 4: Verify in the running app**

Run: `flutter run -d windows`

Open a dive that went into deco and confirm all of the following:
1. A stepped red band spans from the stop depth up to the surface.
2. The dashed smooth ceiling line is still visible on top of the band.
3. The band has hard vertical edges at level changes, not slanted ones.
4. Hovering shows a "Deco stop" tooltip row with a depth, and an em-dash on samples with no obligation.
5. Toggling "Deco stops" in the legend hides and shows the band.
6. Switching the legend's deco stop source between Calculated and Computer changes the band shape, and does so without altering the ceiling line.
7. Opening a no-deco dive shows no band at all.

- [ ] **Step 5: Commit any fixes**

If steps 1-4 required changes:

```bash
dart format lib/ test/
git add <the specific files you changed>
git commit -m "fix(profile): <what you fixed>"
```
