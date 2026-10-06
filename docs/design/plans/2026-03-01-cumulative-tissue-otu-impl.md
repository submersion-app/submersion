# Cumulative Tissue Loading & OTU Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make NDL/tissue loading and OTU cumulative across repetitive dives, mirroring the existing recursive CNS lookback pattern.

**Architecture:** Add `startCompartments` and `startOtu` parameters to `ProfileAnalysisService.analyze()`. In the provider layer, compute residual tissue state via recursive lookback (48h cutoff) and residual OTU via same-day summation. The `BuhlmannAlgorithm.processProfile()` method stops calling `reset()` internally so callers can pre-load compartments.

**Tech Stack:** Dart/Flutter, Riverpod providers, Drift ORM, Buhlmann ZH-L16C algorithm

**Design doc:** `docs/plans/2026-03-01-cumulative-tissue-otu-design.md`

---

### Task 1: BuhlmannAlgorithm — Remove internal reset from processProfile

The `processProfile()` method currently calls `reset()` at line 526 of `buhlmann_algorithm.dart`, which overwrites any pre-loaded compartments. The caller should control initialization instead.

**Files:**

- Modify: `lib/core/deco/buhlmann_algorithm.dart:516-564`
- Modify: `lib/core/deco/buhlmann_algorithm.dart:566-603` (getCeilingCurve/getNdlCurve)
- Test: `test/core/deco/buhlmann_algorithm_test.dart`

**Step 1: Write failing test — processProfile respects pre-loaded compartments**

Add a new test group at the end of the `BuhlmannAlgorithm` group in `test/core/deco/buhlmann_algorithm_test.dart`:

```dart
group('cumulative tissue loading', () {
  test('processProfile should use pre-loaded compartments', () {
    final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

    // Simulate dive 1: 30m for 20 minutes
    algorithm.calculateSegment(
      depthMeters: 30.0,
      durationSeconds: 20 * 60,
      fN2: airN2Fraction,
    );
    final postDive1Compartments = algorithm.compartments;

    // Simulate 60 min surface interval
    algorithm.calculateSegment(
      depthMeters: 0.0,
      durationSeconds: 60 * 60,
      fN2: airN2Fraction,
    );
    final recoveredCompartments = algorithm.compartments;

    // Now create fresh algorithm and pre-load recovered state
    final dive2Algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
    dive2Algorithm.setCompartments(recoveredCompartments);

    // processProfile for dive 2 at 18m for 30 min
    final depths = <double>[];
    final timestamps = <int>[];
    for (int t = 0; t <= 30 * 60; t += 60) {
      timestamps.add(t);
      depths.add(18.0);
    }

    final statusesCumulative = dive2Algorithm.processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: airN2Fraction,
    );

    // Compare with fresh algorithm (no residual loading)
    final freshAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
    final statusesFresh = freshAlgorithm.processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: airN2Fraction,
    );

    // Cumulative dive should have SHORTER NDL than fresh dive
    final cumulativeNdl = statusesCumulative.last.ndlSeconds;
    final freshNdl = statusesFresh.last.ndlSeconds;

    expect(
      cumulativeNdl,
      lessThan(freshNdl),
      reason: 'Repetitive dive should have shorter NDL due to residual loading',
    );
  });

  test('48-hour surface interval should produce near-surface-saturated state', () {
    final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

    // Deep dive: 40m for 20 minutes
    algorithm.calculateSegment(
      depthMeters: 40.0,
      durationSeconds: 20 * 60,
      fN2: airN2Fraction,
    );

    // 48 hours at surface
    algorithm.calculateSegment(
      depthMeters: 0.0,
      durationSeconds: 48 * 60 * 60,
      fN2: airN2Fraction,
    );

    final recovered = algorithm.compartments;

    // Create fresh surface-saturated algorithm
    final fresh = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

    // All compartments should be within 1% of surface values
    for (int i = 0; i < 16; i++) {
      expect(
        recovered[i].currentPN2,
        closeTo(fresh.compartments[i].currentPN2, 0.01),
        reason: 'Compartment ${i + 1} should be near surface-saturated after 48h',
      );
    }
  });
});
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/buhlmann_algorithm_test.dart --name "processProfile should use pre-loaded compartments"`
Expected: FAIL — processProfile calls reset() internally, discarding pre-loaded compartments

**Step 3: Implement — remove reset() from processProfile**

In `lib/core/deco/buhlmann_algorithm.dart`, modify `processProfile()` (line 516-564): remove the `reset()` call at line 526.

Change line 526 from:

```dart
    reset();
    final results = <DecoStatus>[];
```yaml
to:

```dart
    final results = <DecoStatus>[];
```dart
Also update `getCeilingCurve()` (line 569-583) and `getNdlCurve()` (line 589-603) to call `reset()` before `processProfile()` so these convenience methods maintain their existing behavior:

In `getCeilingCurve()`, add `reset();` before `final statuses = processProfile(...)`:

```dart
  List<double> getCeilingCurve({
    required List<double> depths,
    required List<int> timestamps,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    reset();
    final statuses = processProfile(
```text
In `getNdlCurve()`, same change:

```dart
  List<int> getNdlCurve({
    required List<double> depths,
    required List<int> timestamps,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    reset();
    final statuses = processProfile(
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/core/deco/buhlmann_algorithm_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/buhlmann_algorithm_test.dart
git commit -m "feat: remove reset() from processProfile to support cumulative tissue loading"
```text
---

### Task 2: O2Exposure — Add otuStart and otuDaily fields

Add `otuStart` and `otuDaily` fields to support cumulative OTU tracking across same-day dives.

**Files:**

- Modify: `lib/core/deco/entities/o2_exposure.dart:9-106`
- Test: `test/core/deco/o2_exposure_test.dart` (create new)

**Step 1: Write failing test**

Create `test/core/deco/o2_exposure_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

void main() {
  group('O2Exposure cumulative OTU', () {
    test('otuDaily should equal otuStart plus otu', () {
      const exposure = O2Exposure(
        otu: 45.0,
        otuStart: 120.0,
      );
      expect(exposure.otuDaily, equals(165.0));
    });

    test('otuDaily defaults to otu when otuStart is zero', () {
      const exposure = O2Exposure(otu: 45.0);
      expect(exposure.otuDaily, equals(45.0));
    });

    test('otuDailyPercentOfLimit should use daily total', () {
      const exposure = O2Exposure(
        otu: 45.0,
        otuStart: 255.0,
      );
      // otuDaily = 300, dailyOtuLimit = 300, so 100%
      expect(exposure.otuDailyPercentOfLimit, equals(100.0));
    });

    test('copyWith should preserve otuStart', () {
      const original = O2Exposure(otu: 45.0, otuStart: 120.0);
      final copy = original.copyWith(otu: 50.0);
      expect(copy.otuStart, equals(120.0));
      expect(copy.otu, equals(50.0));
      expect(copy.otuDaily, equals(170.0));
    });

    test('otuStart should be included in props for equality', () {
      const a = O2Exposure(otu: 45.0, otuStart: 120.0);
      const b = O2Exposure(otu: 45.0, otuStart: 0.0);
      expect(a, isNot(equals(b)));
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/o2_exposure_test.dart`
Expected: FAIL — `otuStart`, `otuDaily`, `otuDailyPercentOfLimit` don't exist

**Step 3: Implement — add fields to O2Exposure**

In `lib/core/deco/entities/o2_exposure.dart`, add to the class:

After the `otu` field (line 17), add:

```dart
  /// OTU accumulated from earlier dives on the same calendar day
  final double otuStart;
```text
Add computed properties after `otuPercentOfDaily` (line 60):

```dart
  /// Total OTU for the day (prior dives + this dive)
  double get otuDaily => otuStart + otu;

  /// Weekly OTU limit (REPEX guidelines)
  static const double weeklyOtuLimit = 850.0;

  /// Daily OTU as percentage of daily limit (using cumulative daily total)
  double get otuDailyPercentOfLimit => (otuDaily / dailyOtuLimit) * 100;
```text
Update the constructor (line 31-39) to include `otuStart`:

```dart
  const O2Exposure({
    this.cnsStart = 0.0,
    this.cnsEnd = 0.0,
    this.otu = 0.0,
    this.otuStart = 0.0,
    this.maxPpO2 = 0.0,
    this.maxPpO2Depth = 0.0,
    this.timeAboveWarning = 0,
    this.timeAboveCritical = 0,
  });
```text
Update `copyWith` (line 76-94) to include `otuStart`:

```dart
  O2Exposure copyWith({
    double? cnsStart,
    double? cnsEnd,
    double? otu,
    double? otuStart,
    double? maxPpO2,
    double? maxPpO2Depth,
    int? timeAboveWarning,
    int? timeAboveCritical,
  }) {
    return O2Exposure(
      cnsStart: cnsStart ?? this.cnsStart,
      cnsEnd: cnsEnd ?? this.cnsEnd,
      otu: otu ?? this.otu,
      otuStart: otuStart ?? this.otuStart,
      maxPpO2: maxPpO2 ?? this.maxPpO2,
      maxPpO2Depth: maxPpO2Depth ?? this.maxPpO2Depth,
      timeAboveWarning: timeAboveWarning ?? this.timeAboveWarning,
      timeAboveCritical: timeAboveCritical ?? this.timeAboveCritical,
    );
  }
```text
Update `props` (line 97-105) to include `otuStart`:

```dart
  @override
  List<Object?> get props => [
    cnsStart,
    cnsEnd,
    otu,
    otuStart,
    maxPpO2,
    maxPpO2Depth,
    timeAboveWarning,
    timeAboveCritical,
  ];
```text
Also update the existing `otuPercentOfDaily` getter (line 60) to use single-dive OTU (keep as-is for backward compatibility — it's the per-dive percentage):

```dart
  /// This dive's OTU as percentage of daily limit
  double get otuPercentOfDaily => (otu / dailyOtuLimit) * 100;
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/core/deco/o2_exposure_test.dart`
Expected: ALL PASS

Also run existing tests to check for regressions:
Run: `flutter test test/core/deco/`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/core/deco/entities/o2_exposure.dart test/core/deco/o2_exposure_test.dart
git commit -m "feat: add otuStart and otuDaily fields to O2Exposure for cumulative tracking"
```text
---

### Task 3: ProfileAnalysisService — Add startCompartments and startOtu params

Wire the new parameters into the service's `analyze()` method.

**Files:**

- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:492-534`
- Test: `test/features/dive_log/data/services/profile_analysis_service_test.dart` (add tests)

**Step 1: Write failing tests**

Add to the existing test file (or create if it doesn't exist) `test/features/dive_log/data/services/profile_analysis_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  group('ProfileAnalysisService cumulative support', () {
    late ProfileAnalysisService service;

    setUp(() {
      service = ProfileAnalysisService(
        gfLow: 1.0,
        gfHigh: 1.0,
      );
    });

    List<double> buildConstantDepthProfile(double depth, int durationMin) {
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= durationMin * 60; t += 60) {
        timestamps.add(t);
        depths.add(depth);
      }
      return depths;
    }

    test('analyze with startCompartments should produce shorter NDL than fresh', () {
      // Create pre-loaded compartments from a simulated first dive
      final preAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      preAlgorithm.calculateSegment(
        depthMeters: 30.0,
        durationSeconds: 20 * 60,
        fN2: airN2Fraction,
      );
      // 60 min surface interval
      preAlgorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final residualCompartments = preAlgorithm.compartments;

      // Build a 30-min dive at 18m
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= 30 * 60; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      // Analyze with residual loading
      final cumulative = service.analyze(
        diveId: 'test-cumulative',
        depths: depths,
        timestamps: timestamps,
        startCompartments: residualCompartments,
      );

      // Analyze fresh (no residual)
      final fresh = service.analyze(
        diveId: 'test-fresh',
        depths: depths,
        timestamps: timestamps,
      );

      // Last NDL value should be shorter for cumulative
      expect(
        cumulative.ndlCurve.last,
        lessThan(fresh.ndlCurve.last),
        reason: 'Cumulative tissue loading should reduce NDL',
      );
    });

    test('analyze with startOtu should set otuStart on O2Exposure', () {
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= 30 * 60; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      final result = service.analyze(
        diveId: 'test-otu',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: 0.32, // EAN32 for meaningful OTU
        startOtu: 120.0,
      );

      expect(result.o2Exposure.otuStart, equals(120.0));
      expect(result.o2Exposure.otuDaily, equals(120.0 + result.o2Exposure.otu));
    });

    test('analyze without startCompartments should use surface-saturated state', () {
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= 30 * 60; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      // Two calls without startCompartments should produce identical results
      final result1 = service.analyze(
        diveId: 'test-1',
        depths: depths,
        timestamps: timestamps,
      );
      final result2 = service.analyze(
        diveId: 'test-2',
        depths: depths,
        timestamps: timestamps,
      );

      expect(result1.ndlCurve, equals(result2.ndlCurve));
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart`
Expected: FAIL — `startCompartments` and `startOtu` parameters don't exist

**Step 3: Implement — add parameters to analyze()**

In `lib/features/dive_log/data/services/profile_analysis_service.dart`, modify `analyze()`:

Add parameters after `scrVo2` (line 506):

```dart
    double scrVo2 = ScrCalculator.defaultVo2,
    List<TissueCompartment>? startCompartments,
    double startOtu = 0.0,
```typescript
Add import for `TissueCompartment` at top of file (if not already imported — it's available via `buhlmann_algorithm.dart` imports):

```dart
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
```text
Replace lines 524-526 (the reset + processProfile call):

```dart
    // Calculate decompression data
    if (startCompartments != null) {
      _buhlmannAlgorithm.setCompartments(startCompartments);
    } else {
      _buhlmannAlgorithm.reset();
    }
    final decoStatuses = _buhlmannAlgorithm.processProfile(
```text
In the O2Exposure construction (two places: OC at line 581-587, and CCR/SCR at line 589-596), add `startOtu` as `otuStart`:

For OC path (line 582-587), update the `calculateDiveExposure` call result. Since `calculateDiveExposure` doesn't know about `otuStart`, apply it after:

Replace the O2Exposure section (lines 580-596) with:

```dart
    // Calculate O2 exposure using the ppO2 curve
    final O2Exposure rawO2Exposure;
    if (diveMode == DiveMode.oc) {
      rawO2Exposure = _o2ToxicityCalculator.calculateDiveExposure(
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        startCns: startCns,
      );
    } else {
      // For CCR/SCR, calculate O2 exposure from ppO2 curve
      rawO2Exposure = _calculateO2ExposureFromPpO2Curve(
        ppO2Curve: ppO2Curve,
        timestamps: timestamps,
        depths: depths,
        startCns: startCns,
      );
    }

    // Apply cumulative OTU from earlier same-day dives
    final o2Exposure = startOtu > 0
        ? rawO2Exposure.copyWith(otuStart: startOtu)
        : rawO2Exposure;
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart`
Expected: ALL PASS

Run full test suite to check for regressions:
Run: `flutter test`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "feat: add startCompartments and startOtu params to ProfileAnalysisService.analyze"
```dart
---

### Task 4: Profile Analysis Provider — Add residual tissue state computation

Add `_computeResidualTissueState()` that mirrors the existing `_computeResidualCns()` pattern, with a 48-hour cutoff.

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:420-466`
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` (add tests)

**Step 1: Write failing test**

This requires mocking the repository. Check if the existing provider test file has mocks set up. If not, create the test structure. The key behavior to test is the function's logic, which we can test via the provider:

Add to test file (create or extend `test/features/dive_log/presentation/providers/cumulative_tissue_test.dart`):

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Tests for the Schreiner off-gassing math used in residual tissue computation.
///
/// The provider-level integration (recursive lookback via Riverpod) is tested
/// separately. These tests validate the core math in isolation.
void main() {
  group('Residual tissue state computation', () {
    test('off-gassing at surface should reduce tissue loading', () {
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

      // Load tissues at 30m for 20 min
      algorithm.calculateSegment(
        depthMeters: 30.0,
        durationSeconds: 20 * 60,
        fN2: airN2Fraction,
      );
      final loadedCompartments = algorithm.compartments;

      // Off-gas at surface for 60 min
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final recoveredCompartments = algorithm.compartments;

      // All compartments should have lower N2 tension after surface interval
      for (int i = 0; i < 16; i++) {
        expect(
          recoveredCompartments[i].currentPN2,
          lessThan(loadedCompartments[i].currentPN2),
          reason: 'Compartment ${i + 1} N2 should decrease during surface interval',
        );
      }
    });

    test('repetitive dive should have shorter NDL than fresh dive', () {
      // Simulate: dive 1 (30m/20min) -> 60 min SI -> dive 2 (18m)
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

      // Dive 1
      algorithm.calculateSegment(
        depthMeters: 30.0,
        durationSeconds: 20 * 60,
        fN2: airN2Fraction,
      );

      // Surface interval 60 min
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final residualCompartments = algorithm.compartments;

      // Dive 2 with residual loading
      final dive2Algo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      dive2Algo.setCompartments(residualCompartments);
      final ndlCumulative = dive2Algo.calculateNdl(
        depthMeters: 18.0,
        fN2: airN2Fraction,
      );

      // Fresh dive 2 (no residual)
      final freshAlgo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      final ndlFresh = freshAlgo.calculateNdl(
        depthMeters: 18.0,
        fN2: airN2Fraction,
      );

      expect(
        ndlCumulative,
        lessThan(ndlFresh),
        reason: 'Repetitive dive NDL should be shorter than fresh dive',
      );
      expect(
        ndlCumulative,
        greaterThan(0),
        reason: 'After 60 min SI, 18m dive should still have positive NDL',
      );
    });

    test('48-hour cutoff: tissue state should be near surface-saturated', () {
      final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      final surfaceN2 = calculateInspiredN2(surfacePressureBar, airN2Fraction);

      // Heavy dive: 40m for 25 min
      algorithm.calculateSegment(
        depthMeters: 40.0,
        durationSeconds: 25 * 60,
        fN2: airN2Fraction,
      );

      // 48 hours at surface
      algorithm.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 48 * 60 * 60,
        fN2: airN2Fraction,
      );

      // All compartments should be within 1% of surface-saturated
      for (int i = 0; i < 16; i++) {
        expect(
          algorithm.compartments[i].currentPN2,
          closeTo(surfaceN2, 0.008),
          reason: 'Compartment ${i + 1} should be near surface level after 48h',
        );
      }
    });
  });
}
```text
**Step 2: Run test to verify it passes (these test core math, not the provider)**

Run: `flutter test test/features/dive_log/presentation/providers/cumulative_tissue_test.dart`
Expected: ALL PASS (these validate the math that the provider will use)

**Step 3: Implement _computeResidualTissueState in the provider**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, add after `_computeResidualCns()` (after line 466):

```dart
/// Computes residual tissue compartment state from previous dives.
///
/// Mirrors the recursive CNS lookback pattern: fetches the previous dive's
/// full analysis (which recursively accounts for even earlier dives), extracts
/// end-of-dive compartments, then applies Schreiner off-gassing for the
/// surface interval.
///
/// Returns null if no previous dive exists or surface interval >= 48 hours
/// (tissues are effectively surface-saturated).
Future<List<TissueCompartment>?> _computeResidualTissueState(
  Ref ref,
  String diveId,
) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final surfaceInterval = await repository.getSurfaceInterval(diveId);
    if (surfaceInterval == null || surfaceInterval.inHours >= 48) return null;

    final previousDive = await repository.getPreviousDive(diveId);
    if (previousDive == null) return null;

    // Recursively get the previous dive's full analysis (including its own
    // residual tissue state from even earlier dives).
    final previousAnalysis = await ref.watch(
      profileAnalysisProvider(previousDive.id).future,
    );
    if (previousAnalysis == null || previousAnalysis.decoStatuses.isEmpty) {
      return null;
    }

    // Extract end-of-dive compartment state
    final endOfDiveCompartments = previousAnalysis.decoStatuses.last.compartments;

    // Apply Schreiner off-gassing for the surface interval
    final settings = ref.watch(settingsProvider);
    final algorithm = BuhlmannAlgorithm(
      gfLow: settings.gfLowDecimal,
      gfHigh: settings.gfHighDecimal,
    );
    algorithm.setCompartments(List.from(endOfDiveCompartments));
    algorithm.calculateSegment(
      depthMeters: 0,
      durationSeconds: surfaceInterval.inSeconds,
      fN2: airN2Fraction,
      fHe: 0.0,
    );

    return algorithm.compartments;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate residual tissue state for: $diveId',
      e,
      stackTrace,
    );
    return null;
  }
}
```typescript
Add the required import at the top of the file (if not already present):

```dart
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
```text
**Step 4: Wire into profileAnalysisProvider**

In the same file, in `profileAnalysisProvider` (around line 353-380), add the residual tissue state computation alongside the existing `startCns` computation.

After the `startCns` line (line 354-356):

```dart
      final startCns = computerCns != null
          ? computerCns.cnsStart
          : await _computeResidualCns(ref, diveId);
```text
Add:

```dart
      // Compute residual tissue state from previous dives (48h cutoff)
      final startCompartments = await _computeResidualTissueState(ref, diveId);
```text
Then pass it to `service.analyze()` (line 364-380). Add `startCompartments: startCompartments,` after `startCns: startCns,`:

```dart
      final analysis = service.analyze(
        diveId: diveId,
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        heFraction: heFraction,
        startCns: startCns,
        startCompartments: startCompartments,
        pressures: pressures,
        // ... rest unchanged
```text
**Step 5: Run tests**

Run: `flutter test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/cumulative_tissue_test.dart
git commit -m "feat: add recursive residual tissue state computation for cumulative NDL"
```dart
---

### Task 5: Profile Analysis Provider — Add residual OTU computation

Add `_computeResidualOtu()` that sums OTU from earlier same-day dives (non-recursive).

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- Test: `test/features/dive_log/presentation/providers/cumulative_otu_test.dart` (create new)

**Step 1: Write failing test**

Create `test/features/dive_log/presentation/providers/cumulative_otu_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

void main() {
  group('Cumulative OTU computation', () {
    test('otuDaily should accumulate across dives', () {
      // Dive 1: 45 OTU
      const dive1 = O2Exposure(otu: 45.0, otuStart: 0.0);
      expect(dive1.otuDaily, equals(45.0));

      // Dive 2: 38 OTU, startOtu = 45 (from dive 1)
      const dive2 = O2Exposure(otu: 38.0, otuStart: 45.0);
      expect(dive2.otuDaily, equals(83.0));

      // Dive 3: 52 OTU, startOtu = 83 (from dives 1+2)
      const dive3 = O2Exposure(otu: 52.0, otuStart: 83.0);
      expect(dive3.otuDaily, equals(135.0));
    });

    test('otuDailyPercentOfLimit should show correct percentage', () {
      const exposure = O2Exposure(otu: 50.0, otuStart: 250.0);
      // otuDaily = 300, limit = 300, so 100%
      expect(exposure.otuDailyPercentOfLimit, equals(100.0));
    });

    test('weekly OTU limit constant should be 850', () {
      expect(O2Exposure.weeklyOtuLimit, equals(850.0));
    });
  });
}
```text
**Step 2: Run test to verify it passes (tests entity math, not provider)**

Run: `flutter test test/features/dive_log/presentation/providers/cumulative_otu_test.dart`
Expected: ALL PASS (entity fields were added in Task 2)

**Step 3: Implement _computeResidualOtu in the provider**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, add after `_computeResidualTissueState()`:

```dart
/// Computes cumulative OTU from earlier dives on the same calendar day.
///
/// Non-recursive: queries all dives on the same day, gets each dive's
/// profile analysis, and sums their per-dive OTU values.
///
/// Returns 0.0 if no earlier dives exist on the same day.
Future<double> _computeResidualOtu(Ref ref, String diveId) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    // Get current dive's date
    final currentDive = await repository.getDiveById(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final startOfDay = DateTime(diveDate.year, diveDate.month, diveDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all dives on the same day
    final sameDayDives = await repository.getDivesInRange(startOfDay, endOfDay);

    // Sum OTU from dives that occurred BEFORE this one
    double totalOtu = 0.0;
    for (final dive in sameDayDives) {
      if (dive.id == diveId) continue;
      final diveTime = dive.entryTime ?? dive.dateTime;
      if (diveTime.isBefore(diveDate)) {
        final analysis = await ref.watch(
          profileAnalysisProvider(dive.id).future,
        );
        if (analysis != null) {
          totalOtu += analysis.o2Exposure.otu;
        }
      }
    }

    return totalOtu;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate residual OTU for: $diveId',
      e,
      stackTrace,
    );
    return 0.0;
  }
}
```text
**Step 4: Wire into profileAnalysisProvider**

In `profileAnalysisProvider`, after `startCompartments`:

```dart
      // Compute cumulative OTU from earlier same-day dives
      final startOtu = await _computeResidualOtu(ref, diveId);
```text
Pass to `service.analyze()`:

```dart
      final analysis = service.analyze(
        diveId: diveId,
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        heFraction: heFraction,
        startCns: startCns,
        startCompartments: startCompartments,
        startOtu: startOtu,
        pressures: pressures,
        // ... rest unchanged
```text
**Step 5: Run tests**

Run: `flutter test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/cumulative_otu_test.dart
git commit -m "feat: add cumulative OTU computation from same-day dives"
```dart
---

### Task 6: Weekly OTU Provider

Add a provider for weekly OTU rolling total (7-day window, 850 OTU limit).

**Files:**

- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- Test: `test/features/dive_log/presentation/providers/cumulative_otu_test.dart` (extend)

**Step 1: Write failing test**

Add to `cumulative_otu_test.dart`:

```dart
// (These test the entity constants and math only.
// Provider integration testing requires Riverpod test harness.)

test('weekly OTU limit should be 850', () {
  expect(O2Exposure.weeklyOtuLimit, equals(850.0));
});
```text
**Step 2: Implement weekly OTU provider**

In `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`, add:

```dart
/// Weekly OTU rolling total for a given dive (7-day window ending on dive date).
///
/// Queries all dives in the 7 days leading up to (and including) the dive's
/// date, sums their OTU. Used by O2ToxicityCard for REPEX compliance display.
final weeklyOtuProvider = FutureProvider.family<double, String>((
  ref,
  diveId,
) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final currentDive = await repository.getDiveById(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final endOfDay = DateTime(
      diveDate.year,
      diveDate.month,
      diveDate.day,
    ).add(const Duration(days: 1));
    final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

    final weekDives = await repository.getDivesInRange(sevenDaysAgo, endOfDay);

    double totalOtu = 0.0;
    for (final dive in weekDives) {
      final analysis = await ref.watch(
        profileAnalysisProvider(dive.id).future,
      );
      if (analysis != null) {
        totalOtu += analysis.o2Exposure.otu;
      }
    }

    return totalOtu;
  } catch (e, stackTrace) {
    _log.error('Failed to calculate weekly OTU for: $diveId', e, stackTrace);
    return 0.0;
  }
});
```text
**Step 3: Run tests**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart
git commit -m "feat: add weeklyOtuProvider for 7-day rolling OTU total"
```text
---

### Task 7: O2ToxicityCard — Display cumulative OTU

Update the O2 toxicity card to show daily OTU total and weekly OTU total.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart:184-249`
- No new tests (UI widget — tested via existing widget test or manual verification)

**Step 1: Update _buildOtuDisplay in O2ToxicityCard**

In `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`, update `_buildOtuDisplay()` (lines 184-249).

The existing display shows single-dive OTU and "% of daily limit". Update it to show daily total when `otuStart > 0`:

Replace the `_buildOtuDisplay` method body. The key change: use `otuDailyPercentOfLimit` when `otuStart > 0`, and show both this-dive and daily totals:

```dart
  Widget _buildOtuDisplay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasPriorOtu = exposure.otuStart > 0;

    // OTU color based on daily cumulative limit
    Color getOtuColor() {
      final pct = hasPriorOtu
          ? exposure.otuDailyPercentOfLimit
          : exposure.otuPercentOfDaily;
      if (pct >= 100) return colorScheme.error;
      if (pct >= 80) return Colors.orange;
      if (pct >= 50) return Colors.amber;
      return Colors.green;
    }

    final displayPct = hasPriorOtu
        ? exposure.otuDailyPercentOfLimit
        : exposure.otuPercentOfDaily;

    return Semantics(
      label: context.l10n.diveLog_o2tox_semantics_otu(
        exposure.otuFormatted,
        displayPct.toStringAsFixed(0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.diveLog_o2tox_oxygenToleranceUnits,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                if (hasPriorOtu) ...[
                  Text(
                    '${exposure.otuDaily.toStringAsFixed(0)} OTU',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: getOtuColor(),
                    ),
                  ),
                  Text(
                    'This dive: ${exposure.otuFormatted}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Text(
                    exposure.otuFormatted,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: getOtuColor(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${displayPct.toStringAsFixed(0)}%',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: getOtuColor(),
                  ),
                ),
                Text(
                  context.l10n.diveLog_o2tox_ofDailyLimit,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
```text
**Step 2: Run tests and verify build**

Run: `flutter test`
Run: `flutter analyze`
Expected: ALL PASS, no lint warnings

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart
git commit -m "feat: display cumulative daily OTU in O2ToxicityCard"
```text
---

### Task 8: Integration Tests — Multi-dive scenario

Verify end-to-end that tissue loading and OTU accumulate correctly across a multi-dive day.

**Files:**

- Test: `test/core/deco/cumulative_integration_test.dart` (create new)

**Step 1: Write integration tests**

Create `test/core/deco/cumulative_integration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  group('Cumulative tissue loading integration', () {
    test('3-dive day: NDL should decrease with each successive dive', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      // Build a simple constant-depth profile
      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      // Dive 1: 25m for 30 min (fresh)
      final dive1 = service.analyze(
        diveId: 'dive-1',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
      );

      // Simulate 60 min surface interval
      final algo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      algo.setCompartments(
        List.from(dive1.decoStatuses.last.compartments),
      );
      algo.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final si1Compartments = algo.compartments;

      // Dive 2: 25m for 30 min (with residual from dive 1)
      final dive2 = service.analyze(
        diveId: 'dive-2',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        startCompartments: si1Compartments,
      );

      // Simulate another 60 min surface interval
      final algo2 = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      algo2.setCompartments(
        List.from(dive2.decoStatuses.last.compartments),
      );
      algo2.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 60 * 60,
        fN2: airN2Fraction,
      );
      final si2Compartments = algo2.compartments;

      // Dive 3: 25m for 30 min (with residual from dives 1+2)
      final dive3 = service.analyze(
        diveId: 'dive-3',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        startCompartments: si2Compartments,
      );

      // NDL should decrease: dive1 > dive2 > dive3
      final ndl1 = dive1.ndlCurve.first;
      final ndl2 = dive2.ndlCurve.first;
      final ndl3 = dive3.ndlCurve.first;

      expect(ndl1, greaterThan(ndl2),
          reason: 'Dive 2 NDL should be shorter than dive 1');
      expect(ndl2, greaterThan(ndl3),
          reason: 'Dive 3 NDL should be shorter than dive 2');

      // All should still have positive NDL at the start
      expect(ndl1, greaterThan(0));
      expect(ndl2, greaterThan(0));
      expect(ndl3, greaterThan(0));
    });

    test('OTU should accumulate across dives via startOtu', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      // Dive 1: EAN32 at 25m for 30 min
      final dive1 = service.analyze(
        diveId: 'dive-1',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        o2Fraction: 0.32,
      );

      // Dive 2: same profile, startOtu from dive 1
      final dive2 = service.analyze(
        diveId: 'dive-2',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        o2Fraction: 0.32,
        startOtu: dive1.o2Exposure.otu,
      );

      expect(dive2.o2Exposure.otuStart, equals(dive1.o2Exposure.otu));
      expect(
        dive2.o2Exposure.otuDaily,
        closeTo(dive1.o2Exposure.otu + dive2.o2Exposure.otu, 0.01),
      );
    });

    test('startCompartments with null should behave like fresh dive', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      final withNull = service.analyze(
        diveId: 'null-test',
        depths: depths(18.0, 30),
        timestamps: timestamps(30),
        startCompartments: null,
      );

      final withoutParam = service.analyze(
        diveId: 'no-param-test',
        depths: depths(18.0, 30),
        timestamps: timestamps(30),
      );

      expect(withNull.ndlCurve, equals(withoutParam.ndlCurve));
    });
  });
}
```text
**Step 2: Run integration tests**

Run: `flutter test test/core/deco/cumulative_integration_test.dart`
Expected: ALL PASS

**Step 3: Run full test suite**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add test/core/deco/cumulative_integration_test.dart
git commit -m "test: add integration tests for cumulative tissue loading and OTU"
```dart
---

### Task 9: Format, analyze, and final verification

**Step 1: Format all code**

Run: `dart format lib/ test/`

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

**Step 3: Run full test suite**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Final commit (if formatting changed anything)**

```bash
git add -A
git commit -m "chore: format code for cumulative tissue loading feature"
```
