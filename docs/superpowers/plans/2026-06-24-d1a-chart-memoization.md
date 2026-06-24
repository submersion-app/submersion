# D1a — Chart Memoization + combineMultiTankPressures O(N) + Decimator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Task 5 (measurement) is **interactive/main-session** — it runs the app + a profiler script and cannot be done by a subagent.

**Goal:** Make dive-profile-chart interactions stop rebuilding `FlSpot` series (memoization), make `combineMultiTankPressures` O(N), and land a tested-but-unwired feature-preserving decimator — then re-measure the now-clean cold build to decide whether decimation (Plan B) is needed.

**Architecture:** Three independent, self-contained pieces plus a measurement gate. The decimator is a pure function (primitive in/out). `combineMultiTankPressures` is rewritten in place with a forward merge-walk. Memoization adds an `FlSpotCache` that the chart's `FlSpot`-constructing builders read through, invalidated only when the underlying data or units change — so playback/hover/zoom/legend become cache hits.

**Tech Stack:** Dart/Flutter, fl_chart, Riverpod, flutter_test. Profiling via `scratchpad/vmcap.dart` (VM Service over WebSocket).

## Global Constraints

- **TDD:** failing test first, then minimal code (the project mandates this).
- **`dart format .`** (whole repo) must pass before any push.
- **No `Co-Authored-By`** trailer in commits.
- **Dive-safety (for the decimator):** a decimated index set MUST keep the max-depth sample, every ascent-rate **band** boundary, and every **`decoType`** transition. Verified by tests.
- **Decimator stays unwired in this plan** — it is exercised only by its unit tests. Wiring is Plan B (`docs/superpowers/specs/2026-06-24-d1-profile-chart-perf-design.md`).
- **Measurement is profile-mode only** (`flutter run --profile -d macos`); debug numbers are meaningless.
- Frequent commits — one per task.

## File Structure

- Create `lib/features/dive_log/presentation/widgets/profile_decimator.dart` — pure decimator (Task 1).
- Create `test/features/dive_log/presentation/widgets/profile_decimator_test.dart` (Task 1).
- Modify `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` — `combineMultiTankPressures` O(N) (Task 2).
- Modify `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` — parity test (Task 2).
- Create `lib/features/dive_log/presentation/widgets/fl_spot_cache.dart` — `FlSpotCache` (Task 3).
- Create `test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart` (Task 3).
- Modify `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — wire the cache + invalidation (Task 4).

---

### Task 1: Feature-preserving decimator (pure, unwired)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_decimator.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_decimator_test.dart`

**Interfaces:**
- Produces: `List<int> decimateProfileIndices({required List<double> depths, required List<int> bands, required List<int> decoTypes, int targetPoints = 2000})` — ascending original indices to keep. `bands[i]` = `AscentRatePoint.category.index` per sample; `decoTypes[i]` = `DiveProfilePoint.decoType ?? -1`. Identity list (`0..n-1`) when `depths.length <= targetPoints`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/presentation/widgets/profile_decimator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';

void main() {
  group('decimateProfileIndices', () {
    test('no-op when at or under target', () {
      final depths = List<double>.generate(50, (i) => i.toDouble());
      final r = decimateProfileIndices(
        depths: depths, bands: List.filled(50, 0), decoTypes: List.filled(50, -1),
        targetPoints: 2000,
      );
      expect(r, List<int>.generate(50, (i) => i));
    });

    test('keeps endpoints, ascends, stays in range, reduces count', () {
      final n = 6000;
      final depths = List<double>.generate(n, (i) => 30 + 5 * (i % 7));
      final r = decimateProfileIndices(
        depths: depths, bands: List.filled(n, 0), decoTypes: List.filled(n, -1),
        targetPoints: 2000,
      );
      expect(r.first, 0);
      expect(r.last, n - 1);
      for (var i = 1; i < r.length; i++) {
        expect(r[i] > r[i - 1], isTrue); // strictly ascending, in-range
      }
      expect(r.length, lessThan(n));
    });

    test('always keeps the global max-depth spike', () {
      final n = 5000;
      final depths = List<double>.generate(n, (i) => 10.0);
      depths[3777] = 42.0; // lone deep spike
      final r = decimateProfileIndices(
        depths: depths, bands: List.filled(n, 0), decoTypes: List.filled(n, -1),
        targetPoints: 500,
      );
      expect(r.contains(3777), isTrue);
    });

    test('keeps ascent-rate band crossings (no fabricated-safe ascent)', () {
      final n = 5000;
      final depths = List<double>.generate(n, (i) => 20.0);
      final bands = List<int>.filled(n, 0); // green
      for (var i = 2500; i < 2520; i++) bands[i] = 2; // brief red excursion
      final r = decimateProfileIndices(
        depths: depths, bands: bands, decoTypes: List.filled(n, -1),
        targetPoints: 400,
      );
      expect(r.contains(2500), isTrue); // entry crossing kept
      expect(r.contains(2520), isTrue); // exit crossing kept
    });

    test('keeps decoType transitions', () {
      final n = 5000;
      final deco = List<int>.filled(n, 0); // NDL
      for (var i = 4000; i < n; i++) deco[i] = 2; // enters deco
      final r = decimateProfileIndices(
        depths: List<double>.filled(n, 15.0), bands: List.filled(n, 0),
        decoTypes: deco, targetPoints: 400,
      );
      expect(r.contains(4000), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_decimator_test.dart`
Expected: FAIL — `profile_decimator.dart` / `decimateProfileIndices` not found.

- [ ] **Step 3: Implement the decimator**

```dart
// lib/features/dive_log/presentation/widgets/profile_decimator.dart

/// Returns the ascending original indices to keep when rendering a dense dive
/// profile, preserving dive-critical features: the depth envelope (incl. the
/// max-depth spike), every ascent-rate band boundary, and every decoType
/// transition. Min/max-per-bucket on depth preserves the envelope; force-keeps
/// preserve safety-relevant transitions.
///
/// [bands] is the per-sample ascent-rate category index (parallel to [depths]).
/// [decoTypes] is the per-sample decoType (use -1 for null). Returns the
/// identity index list when `depths.length <= targetPoints` (no-op).
List<int> decimateProfileIndices({
  required List<double> depths,
  required List<int> bands,
  required List<int> decoTypes,
  int targetPoints = 2000,
}) {
  final n = depths.length;
  if (n <= targetPoints) {
    return List<int>.generate(n, (i) => i);
  }

  final keep = <int>{0, n - 1};

  // Force-keep safety transitions: band crossings and decoType changes.
  for (var i = 1; i < n; i++) {
    if (bands[i] != bands[i - 1] || decoTypes[i] != decoTypes[i - 1]) {
      keep
        ..add(i - 1)
        ..add(i);
    }
  }

  // Global max-depth spike.
  var maxIdx = 0;
  for (var i = 1; i < n; i++) {
    if (depths[i] > depths[maxIdx]) maxIdx = i;
  }
  keep.add(maxIdx);

  // Min/max-per-bucket: preserves the depth envelope per time bucket.
  final bucketCount = (targetPoints / 2).floor().clamp(1, n);
  final bucketSize = n / bucketCount;
  for (var b = 0; b < bucketCount; b++) {
    final start = (b * bucketSize).floor();
    final end = ((b + 1) * bucketSize).floor().clamp(start + 1, n);
    var lo = start, hi = start;
    for (var i = start + 1; i < end; i++) {
      if (depths[i] < depths[lo]) lo = i;
      if (depths[i] > depths[hi]) hi = i;
    }
    keep..add(lo)..add(hi);
  }

  final result = keep.toList()..sort();
  return result;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_decimator_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/profile_decimator.dart \
        test/features/dive_log/presentation/widgets/profile_decimator_test.dart
git commit -m "feat(dive-profile): feature-preserving profile decimator (unwired)"
```

---

### Task 2: combineMultiTankPressures O(N²) -> O(N)

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:53-138`
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`

**Interfaces:**
- Unchanged public signature: `List<double>? combineMultiTankPressures({required List<int> timestamps, required Map<String, List<TankPressurePoint>> tankPressures, required List<DiveTank> tanks})`.
- Precondition (already true in production): `timestamps` and each tank's pressure points are ascending by timestamp.

- [ ] **Step 1: Write the failing parity test**

Add to `profile_analysis_provider_test.dart` (it already imports the function). The oracle is the previous O(N²) logic, copied locally; the new impl must match it exactly.

```dart
group('combineMultiTankPressures O(N) parity', () {
  // Oracle: the previous O(N^2) implementation, kept here as the reference.
  List<double>? oracle({
    required List<int> timestamps,
    required Map<String, List<TankPressurePoint>> tankPressures,
    required List<DiveTank> tanks,
  }) {
    if (tankPressures.isEmpty || tanks.isEmpty) return null;
    final vol = <String, double>{};
    for (final t in tanks) {
      if (t.volume != null && t.volume! > 0) vol[t.id] = t.volume!;
    }
    if (vol.isEmpty) for (final t in tanks) vol[t.id] = 1.0;
    final out = <double>[];
    for (final target in timestamps) {
      double gas = 0, v = 0;
      for (final e in tankPressures.entries) {
        final pts = e.value;
        if (pts.isEmpty) continue;
        final tv = vol[e.key] ?? 1.0;
        double? p;
        for (var j = 0; j < pts.length; j++) {
          if (pts[j].timestamp == target) { p = pts[j].pressure; break; }
          if (pts[j].timestamp > target) {
            p = j > 0
                ? pts[j - 1].pressure +
                    (pts[j].pressure - pts[j - 1].pressure) *
                        (target - pts[j - 1].timestamp) /
                        (pts[j].timestamp - pts[j - 1].timestamp)
                : pts[j].pressure;
            break;
          }
        }
        p ??= pts.last.pressure;
        gas += p * tv; v += tv;
      }
      out.add(v > 0 ? gas / v : 0);
    }
    return out;
  }

  TankPressurePoint tp(int t, double p) =>
      TankPressurePoint(timestamp: t, pressure: p);

  test('matches the oracle on a two-tank interpolated case', () {
    final timestamps = [0, 5, 10, 15, 20, 25, 30];
    final pressures = {
      'a': [tp(0, 200), tp(10, 180), tp(30, 120)],
      'b': [tp(0, 210), tp(20, 150)],
    };
    final tanks = [
      DiveTank(id: 'a', gasMix: const GasMix.air()),
      DiveTank(id: 'b', gasMix: const GasMix.air()),
    ];
    expect(
      combineMultiTankPressures(
          timestamps: timestamps, tankPressures: pressures, tanks: tanks),
      oracle(timestamps: timestamps, tankPressures: pressures, tanks: tanks),
    );
  });

  test('matches the oracle when timestamps run past all pressure points', () {
    final timestamps = [0, 50, 100];
    final pressures = {'a': [tp(0, 200), tp(40, 100)]};
    final tanks = [DiveTank(id: 'a', gasMix: const GasMix.air())];
    expect(
      combineMultiTankPressures(
          timestamps: timestamps, tankPressures: pressures, tanks: tanks),
      oracle(timestamps: timestamps, tankPressures: pressures, tanks: tanks),
    );
  });
});
```

Note: construct `DiveTank`/`GasMix`/`TankPressurePoint` exactly as existing tests in this file do — copy their constructor usage if these differ.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart --plain-name "O(N) parity"`
Expected: FAIL only if behavior diverges; if the oracle equals the current impl it PASSES now. To make the test meaningful first, confirm it compiles and the oracle/test harness runs against the current code (it should PASS, proving the oracle is faithful). Then Step 3 swaps the impl and the test guards it.

- [ ] **Step 3: Replace the inner scan with a forward merge-walk**

In `profile_analysis_provider.dart`, replace the per-timestamp `for (int j = 0; ...)` scan (lines ~102-123) with a per-tank cursor that only advances. Insert before the `for (int i...)` loop:

```dart
  // Per-tank cursor; timestamps and each tank's points are ascending, so the
  // cursor only moves forward across the whole pass (O(N + sum(points))).
  final cursors = <String, int>{
    for (final e in tankPressures.entries) e.key: 0,
  };
```

Replace the inner pressure-lookup block with:

```dart
      var j = cursors[tankId]!;
      while (j < pressurePoints.length &&
          pressurePoints[j].timestamp < targetTime) {
        j++;
      }
      cursors[tankId] = j;

      double pressure;
      if (j < pressurePoints.length &&
          pressurePoints[j].timestamp == targetTime) {
        pressure = pressurePoints[j].pressure;
      } else if (j > 0 && j < pressurePoints.length) {
        final p1 = pressurePoints[j - 1];
        final p2 = pressurePoints[j];
        final ratio =
            (targetTime - p1.timestamp) / (p2.timestamp - p1.timestamp);
        pressure = p1.pressure + (p2.pressure - p1.pressure) * ratio;
      } else if (j < pressurePoints.length) {
        pressure = pressurePoints[j].pressure; // before first point (j == 0)
      } else {
        pressure = pressurePoints.last.pressure; // after all points
      }
```

(Delete the old `double? pressure; for (int j...)` loop and the `pressure ??= pressurePoints.last.pressure;` line it replaces.)

- [ ] **Step 4: Run the parity test + the file's existing tests**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
Expected: PASS (parity cases + all pre-existing tests, including the #276 un-keyed-tank fallback).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart \
        test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git commit -m "perf(dive-profile): combineMultiTankPressures O(N^2) -> O(N) merge-walk"
```

---

### Task 3: FlSpotCache (pure, tested)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/fl_spot_cache.dart`
- Test: `test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart`

**Interfaces:**
- Produces: `class FlSpotCache { List<FlSpot> spots(String key, List<FlSpot> Function() build); void invalidate(String dataSignature); }` — `spots` returns the cached list (same instance) on a key hit; `invalidate` clears everything when the signature changes.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/fl_spot_cache.dart';

void main() {
  test('returns the same instance on a key hit (no rebuild)', () {
    final cache = FlSpotCache();
    var builds = 0;
    List<FlSpot> build() { builds++; return [const FlSpot(0, 0)]; }
    final a = cache.spots('depth', build);
    final b = cache.spots('depth', build);
    expect(identical(a, b), isTrue);
    expect(builds, 1);
  });

  test('invalidate(newSignature) forces a rebuild; same signature does not', () {
    final cache = FlSpotCache();
    var builds = 0;
    List<FlSpot> build() { builds++; return [const FlSpot(0, 0)]; }
    cache.invalidate('sigA');
    cache.spots('depth', build);
    cache.invalidate('sigA'); // unchanged -> keep cache
    cache.spots('depth', build);
    expect(builds, 1);
    cache.invalidate('sigB'); // changed -> drop cache
    cache.spots('depth', build);
    expect(builds, 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart`
Expected: FAIL — `fl_spot_cache.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_log/presentation/widgets/fl_spot_cache.dart
import 'package:fl_chart/fl_chart.dart';

/// Memoizes per-curve FlSpot lists for the dive profile chart. The cache is
/// dropped whenever the underlying data or units change (a new data signature);
/// within one signature, repeated builds (playback ticks, hover, zoom, legend
/// toggles) are pure cache hits and never reconstruct the spot lists.
class FlSpotCache {
  final Map<String, List<FlSpot>> _cache = {};
  String? _signature;

  /// Drops all cached series if [dataSignature] differs from the last one.
  void invalidate(String dataSignature) {
    if (dataSignature != _signature) {
      _cache.clear();
      _signature = dataSignature;
    }
  }

  /// Returns the cached spots for [key], building once via [build] on a miss.
  List<FlSpot> spots(String key, List<FlSpot> Function() build) {
    return _cache[key] ??= build();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/fl_spot_cache.dart \
        test/features/dive_log/presentation/widgets/fl_spot_cache_test.dart
git commit -m "feat(dive-profile): FlSpotCache for chart series memoization"
```

---

### Task 4: Wire FlSpotCache into the chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `FlSpotCache` (Task 3).
- The cache holds only the `List<FlSpot>` (the per-sample `.map` — the measured cost). `LineChartBarData` styling stays rebuilt each frame (it is cheap and may depend on volatile inputs like range selection), so caching only the spot lists is both the cost-targeting and the safe choice.

- [ ] **Step 1: Add the cache field + data signature**

In `_DiveProfileChartState`, add:

```dart
  final FlSpotCache _spotCache = FlSpotCache();

  /// Identity of every input that changes the spot geometry: the profile, the
  /// per-tank pressures, all analysis-derived curve arrays, and the unit
  /// signature. When any changes, the cache is dropped. (Playback, viewport,
  /// tooltip, and range state are deliberately absent — they never alter spots.)
  String _dataSignature(UnitFormatter units) => [
        identityHashCode(widget.profile),
        identityHashCode(widget.tankPressures),
        identityHashCode(widget.ppO2Curve),
        identityHashCode(widget.ppN2Curve),
        identityHashCode(widget.ppHeCurve),
        identityHashCode(widget.modCurve),
        identityHashCode(widget.densityCurve),
        identityHashCode(widget.gfCurve),
        identityHashCode(widget.surfaceGfCurve),
        identityHashCode(widget.meanDepthCurve),
        identityHashCode(widget.ttsCurve),
        identityHashCode(widget.cnsCurve),
        identityHashCode(widget.otuCurve),
        identityHashCode(widget.computerProfiles),
        units.depthSymbol,
        units.temperatureSymbol,
        units.pressureSymbol,
        units.sacSymbol,
      ].join('|');
```

Add `import 'fl_spot_cache.dart';` near the other local imports. (Include any additional analysis list props the widget holds — e.g. ascent-rate, sac, ceiling, ndl arrays if they are fields — so every spot input is covered.)

- [ ] **Step 2: Invalidate once per build**

In `build()` (after `units` is resolved, ~line 1028), add:

```dart
    _spotCache.invalidate(_dataSignature(units));
```

- [ ] **Step 3: Route each FlSpot construction through the cache**

For every `_build*Line` / `_buildSingleDepthSegment` method, wrap the `...map((p) => FlSpot(...)).toList()` expression in a cache lookup with a stable per-series key. Two worked examples:

`_buildSingleDepthSegment` (the velocity-colored depth pieces — call it with a key that includes the segment bounds, since each colored run is a distinct series):

```dart
      spots: _spotCache.spots('depth:$startIndex:$endIndex', () =>
          widget.profile
              .sublist(startIndex, endIndex)
              .map((p) => FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)))
              .toList()),
```

`_buildTemperatureLine`:

```dart
      spots: _spotCache.spots('temp', () => widget.profile
          .where((p) => p.temperature != null)
          .map((p) => FlSpot(p.timestamp.toDouble(),
              -_mapTempToDepth(units.convertTemperature(p.temperature!),
                  chartMaxDepth, minTemp, maxTemp)))
          .toList()),
```

Apply the same wrap, with a unique stable `key`, to each remaining builder: `_buildMultiComputerDepthLines` (`'computer:$computerId'`), `_buildMultiTankPressureLines` (`'pressure:$tankId'`), `_buildHeartRateLine` (`'hr'`), `_buildSacLine` (`'sac'`), `_buildAscentRateLine` (`'ascent'`), `_buildCeilingLine` (`'ceiling'`), `_buildNdlLine` (`'ndl'`), `_buildPpO2Line` (`'ppo2'`), `_buildPpN2Line` (`'ppn2'`), `_buildPpHeLine` (`'pphe'`), `_buildModLine` (`'mod'`), `_buildDensityLine` (`'density'`), `_buildGfLine` (`'gf'`), `_buildSurfaceGfLine` (`'surfacegf'`), `_buildMeanDepthLine` (`'meandepth'`), `_buildTtsLine` (`'tts'`), `_buildCnsLine` (`'cns'`), `_buildOtuLine` (`'otu'`). The rule is mechanical: wrap the existing `.map(...).toList()` in `_spotCache.spots('<key>', () => <that expression>)`; do not change the styling around it.

Note on `chartMaxDepth`/`minTemp`/`maxTemp`: these are derived from the (profile, units) pair and so are constant within one cache signature — caching the temp spots under `'temp'` is correct.

- [ ] **Step 4: Add an invalidation correctness widget test**

```dart
// in dive_profile_chart_test.dart
testWidgets('changing depth units rebuilds spots (cache not stale)', (tester) async {
  // Pump DiveProfileChart inside a ProviderScope with metric settings; read the
  // rendered depth tick labels (or a known FlSpot y). Then override settings to
  // imperial and pump again. Assert the depth axis/labels reflect feet, proving
  // the cache invalidated on unit change rather than serving metric spots.
  // Follow the existing pump/harness pattern already used in this test file.
});
```

(Use the harness already present in `dive_profile_chart_test.dart`; assert on a unit-dependent rendered value before/after a settings override.)

- [ ] **Step 5: Run the chart tests (regression + new)**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
Expected: PASS — all pre-existing chart tests (output unchanged) plus the new unit-invalidation test.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart \
        test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "perf(dive-profile): memoize chart FlSpot series via FlSpotCache"
```

---

### Task 5: Measure the clean cold build (interactive, main session)

**Files:** none (records numbers; decides Plan B).

- [ ] **Step 1: Run the full suite once**

Run: `flutter test`
Expected: green (or pre-existing-only failures noted). This is the pre-push gate.

- [ ] **Step 2: Launch profile build + connect the profiler**

Run `flutter run --profile -d macos`, grab the VM Service ws URL, and use `scratchpad/vmcap.dart` (`clear` → open Dive #41 + scrub → `read`). Let the on-launch sync settle first so the chart cost is isolated.

- [ ] **Step 3: Record before/after**

Compare against the Phase 1 findings (35 ms build, 56 ms `combineMultiTankPressures`). Capture: cold-open worst-frame build ms, and whether hover/playback/zoom now produce **zero** series rebuilds (cache hits → flat frame times during interaction). Append the numbers to `docs/superpowers/specs/2026-06-24-app-performance-findings.md` under a "Phase 2 — D1a result" heading (on this branch).

- [ ] **Step 4: Decide Plan B**

If the clean cold build is now under the frame budget, decimation (Plan B) is optional polish — note it and stop. If still over budget on dense dives, proceed to write the Plan B (decimation wiring) plan. Either way, record the decision with its justifying number.

---

## Self-Review

**Spec coverage:** Decimator (spec Component 1) → Task 1. `combineMultiTankPressures` O(N) (Component 3) → Task 2. Memoization (Component 2) → Tasks 3-4. Proof-by-measurement gate + Plan B decision → Task 5. Decimator stays unwired per the staged decision. Dive-safety invariants → Task 1 tests (max-depth, band crossings, decoType).

**Placeholder scan:** Tasks 1-3 carry complete code. Task 4 gives the exact cache pattern + two worked builders + the enumerated list of the remaining builders with their keys (a mechanical wrap, not a vague "handle the rest"). The two prose-guided spots (the parity-test constructor usage, the widget-test harness) explicitly defer to existing patterns in the named test files rather than inventing APIs — concrete, not placeholder.

**Type/name consistency:** `decimateProfileIndices` params (`depths`/`bands`/`decoTypes`/`targetPoints`) match Task 1 throughout. `FlSpotCache.spots`/`invalidate` match between Task 3 and Task 4. `_dataSignature(units)` returns the string fed to `invalidate`. `combineMultiTankPressures` signature is unchanged from the existing code.
