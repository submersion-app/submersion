# Linear Tank Pressure Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw a transmitter-style linear start→end pressure line on the dive profile chart for tanks that have manually-entered start/end pressures but no air-integrated (AI) time-series data, marked as "estimated".

**Architecture:** A pure synthesis helper builds flat–drop–flat `TankPressurePoint` series in memory, windowed by gas switches; a composing Riverpod provider augments the real pressure map with these estimates and reports which tankIds are synthetic; the chart, legend, tooltip, and readout render the synthetic series like a normal pressure line but tagged "(est.)". Nothing is persisted — SAC analysis and exports keep reading real `TankPressureProfiles` data only.

**Tech Stack:** Flutter, Drift (untouched here), Riverpod, fl_chart, Flutter gen-l10n.

## Global Constraints

- After every task: `dart format .` produces no changes, and `flutter analyze` is clean (whole project).
- Synthesis is **in-memory only** — never written to the database, sync, or export.
- **Trigger** for synthesizing a tank's line: the tank has no rows in the real pressure map AND `startPressure != null` AND `endPressure != null` AND `startPressure > endPressure` AND the dive has a depth profile (`diveDurationSeconds > 0`).
- **Starting tank** (active from t=0) = the tank with the lowest `DiveTank.order`, identical to `buildGasUsageSegments`.
- New user-facing string added to all **11** `lib/l10n/arb/app_*.arb` files (`ar, de, en, es, fr, he, hu, it, nl, pt, zh`), translated (not English fallbacks), then regenerated with `flutter gen-l10n`.
- Commit messages: no `Co-Authored-By` trailers.
- Branch: `issue-197-linear-tank-pressure-line`.

## File Structure

- `lib/features/dive_log/data/services/gas_usage_segments_service.dart` — add `buildActiveTankIntervals` (tank-keyed timeline, reuses the same walk rules as `buildGasUsageSegments`).
- `lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart` (new) — `synthesizeEstimatedTankPressures`, `EstimatedTankPressures`, private `_buildFlatDropFlat`. DB-free pure service beside `gas_usage_segments_service.dart`.
- `lib/features/dive_log/presentation/providers/dive_providers.dart` — add `estimatedTankPressuresProvider`.
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — new `estimatedTankIds` field; `isCurved:false` for estimated tanks; "(est.)" suffix in tooltip + readout rows; pass estimated set into the legend config.
- `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` — `estimatedTankIds` on `ProfileLegendConfig`; "(est.)" suffix on estimated tank rows.
- `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` — consume `estimatedTankPressuresProvider`; pass `estimatedTankIds`.
- `lib/l10n/arb/app_*.arb` (11) + regenerated `app_localizations*.dart`.
- Tests: extend `test/features/dive_log/data/services/gas_usage_segments_service_test.dart`; new `test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart`; new `test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart`; extend `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart` and `dive_profile_legend_test.dart`.

---

### Task 1: `buildActiveTankIntervals` — per-tank active windows from gas switches

**Files:**
- Modify: `lib/features/dive_log/data/services/gas_usage_segments_service.dart` (append new function)
- Test: `test/features/dive_log/data/services/gas_usage_segments_service_test.dart` (add new group)

**Interfaces:**
- Consumes: `DiveTank` (`.id`, `.order`), `GasSwitchWithTank` (`.timestamp`, `.tankId`) from `dive.dart` / `gas_switch.dart`.
- Produces: `Map<String, List<({int start, int end})>> buildActiveTankIntervals({required List<DiveTank> tanks, required List<GasSwitchWithTank> gasSwitches, required int diveDurationSeconds})` — keys are tankIds; each value is that tank's ascending, non-overlapping active `[start, end)` intervals.

- [ ] **Step 1: Write the failing tests**

Add this group to the existing test file (reuse the file's existing `_tank` and `_switch` helpers):

```dart
  group('buildActiveTankIntervals', () {
    test('empty when no tanks or zero duration', () {
      expect(
        buildActiveTankIntervals(
          tanks: const [],
          gasSwitches: const [],
          diveDurationSeconds: 1800,
        ),
        isEmpty,
      );
      expect(
        buildActiveTankIntervals(
          tanks: [_tank(id: 't1', o2: 21)],
          gasSwitches: const [],
          diveDurationSeconds: 0,
        ),
        isEmpty,
      );
    });

    test('single tank, no switches -> one full-dive interval for lowest order', () {
      final result = buildActiveTankIntervals(
        tanks: [_tank(id: 'late', o2: 100, order: 2), _tank(id: 'first', o2: 21)],
        gasSwitches: const [],
        diveDurationSeconds: 2400,
      );
      expect(result.keys, ['first']);
      expect(result['first'], [(start: 0, end: 2400)]);
    });

    test('deco bottle owns only its switch window', () {
      final result = buildActiveTankIntervals(
        tanks: [_tank(id: 'back', o2: 21), _tank(id: 'deco', o2: 50, order: 1)],
        gasSwitches: [_switch(tankId: 'deco', timestamp: 1200, o2Fraction: 0.50)],
        diveDurationSeconds: 1800,
      );
      expect(result['back'], [(start: 0, end: 1200)]);
      expect(result['deco'], [(start: 1200, end: 1800)]);
    });

    test('back gas returned to yields two intervals with a gap', () {
      final result = buildActiveTankIntervals(
        tanks: [_tank(id: 'back', o2: 21), _tank(id: 'deco', o2: 50, order: 1)],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200, o2Fraction: 0.50),
          _switch(tankId: 'back', timestamp: 1800, o2Fraction: 0.21),
        ],
        diveDurationSeconds: 2400,
      );
      expect(result['back'], [(start: 0, end: 1200), (start: 1800, end: 2400)]);
      expect(result['deco'], [(start: 1200, end: 1800)]);
    });

    test('switch exactly at t=0 produces no zero-length leading interval', () {
      final result = buildActiveTankIntervals(
        tanks: [_tank(id: 'back', o2: 21), _tank(id: 'deco', o2: 50, order: 1)],
        gasSwitches: [
          _switch(tankId: 'back', timestamp: 0, o2Fraction: 0.21),
          _switch(tankId: 'deco', timestamp: 1500, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 3000,
      );
      expect(result['back'], [(start: 0, end: 1500)]);
      expect(result['deco'], [(start: 1500, end: 3000)]);
    });

    test('out-of-bounds switches are dropped', () {
      final result = buildActiveTankIntervals(
        tanks: [_tank(id: 'back', o2: 21), _tank(id: 'deco', o2: 50, order: 1)],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: -10, o2Fraction: 0.50),
          _switch(tankId: 'deco', timestamp: 9000, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 1800,
      );
      expect(result['back'], [(start: 0, end: 1800)]);
      expect(result.containsKey('deco'), isFalse);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/gas_usage_segments_service_test.dart`
Expected: FAIL — `buildActiveTankIntervals` is not defined.

- [ ] **Step 3: Implement `buildActiveTankIntervals`**

Append to `gas_usage_segments_service.dart` (after `buildGasUsageSegments`):

```dart
/// Per-tank active intervals: for each tankId, the ascending, non-overlapping
/// [start, end) windows during which it was the breathed gas.
///
/// Uses the same starting-tank + switch-walk rules as [buildGasUsageSegments]
/// (starting tank = lowest [DiveTank.order]; switches sorted and clamped to
/// [0, diveDurationSeconds]; the initial window runs from t=0 to the first
/// switch), but keys by tankId with no gas-mix merging.
///
/// Returns an empty map when there are no tanks or the dive has no duration.
Map<String, List<({int start, int end})>> buildActiveTankIntervals({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
}) {
  final result = <String, List<({int start, int end})>>{};
  if (tanks.isEmpty || diveDurationSeconds <= 0) return result;

  final startingTank = ([
    ...tanks,
  ]..sort((a, b) => a.order.compareTo(b.order))).first;

  final inBounds =
      ([...gasSwitches]..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
          .where((s) => s.timestamp >= 0 && s.timestamp <= diveDurationSeconds)
          .toList(growable: false);

  void add(String tankId, int start, int end) {
    if (start >= end) return;
    result.putIfAbsent(tankId, () => []).add((start: start, end: end));
  }

  if (inBounds.isEmpty) {
    add(startingTank.id, 0, diveDurationSeconds);
    return result;
  }

  if (inBounds.first.timestamp > 0) {
    add(startingTank.id, 0, inBounds.first.timestamp);
  }
  for (var i = 0; i < inBounds.length; i++) {
    final end = i + 1 < inBounds.length
        ? inBounds[i + 1].timestamp
        : diveDurationSeconds;
    add(inBounds[i].tankId, inBounds[i].timestamp, end);
  }
  return result;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/data/services/gas_usage_segments_service_test.dart`
Expected: PASS (existing `buildGasUsageSegments` tests plus the new group).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data/services/gas_usage_segments_service.dart test/features/dive_log/data/services/gas_usage_segments_service_test.dart
flutter analyze lib/features/dive_log/data/services/gas_usage_segments_service.dart
git add lib/features/dive_log/data/services/gas_usage_segments_service.dart test/features/dive_log/data/services/gas_usage_segments_service_test.dart
git commit -m "feat(dive-log): add buildActiveTankIntervals for per-tank gas windows"
```

---

### Task 2: `synthesizeEstimatedTankPressures` — build the flat–drop–flat series

**Files:**
- Create: `lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart`
- Test: `test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart`

**Interfaces:**
- Consumes: `buildActiveTankIntervals` (Task 1); `TankPressurePoint` (`.id/.tankId/.timestamp/.pressure`), `DiveTank` (`.id/.order/.startPressure/.endPressure`), `GasSwitchWithTank`.
- Produces:
  - `class EstimatedTankPressures { final Map<String, List<TankPressurePoint>> pressures; final Set<String> estimatedTankIds; const EstimatedTankPressures(this.pressures, this.estimatedTankIds); }`
  - `EstimatedTankPressures synthesizeEstimatedTankPressures({required Map<String, List<TankPressurePoint>> existing, required List<DiveTank> tanks, required List<GasSwitchWithTank> gasSwitches, required int diveDurationSeconds})`.

- [ ] **Step 1: Write the failing tests**

Create the test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

DiveTank _tank({
  required String id,
  double? start,
  double? end,
  int order = 0,
}) => DiveTank(
  id: id,
  gasMix: const GasMix(o2: 21),
  order: order,
  startPressure: start,
  endPressure: end,
);

GasSwitchWithTank _switch({required String tankId, required int timestamp}) =>
    GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'gs-$timestamp',
        diveId: 'd1',
        timestamp: timestamp,
        tankId: tankId,
        createdAt: DateTime(2026, 1, 1),
      ),
      tankName: '',
      gasMix: '',
      o2Fraction: 0.21,
    );

void main() {
  group('synthesizeEstimatedTankPressures', () {
    test('single tank, no switches -> straight two-point line', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 2400,
      );
      expect(result.estimatedTankIds, {'t1'});
      final pts = result.pressures['t1']!;
      expect(pts.map((p) => (p.timestamp, p.pressure)), [(0, 200.0), (2400, 65.0)]);
    });

    test('deco bottle -> flat, drop, flat', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [
          _tank(id: 'back', start: 200, end: 90),
          _tank(id: 'deco', start: 190, end: 130, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200),
          _switch(tankId: 'back', timestamp: 1800),
        ],
        diveDurationSeconds: 2400,
      );
      final deco = result.pressures['deco']!.map((p) => (p.timestamp, p.pressure));
      expect(deco, [(0, 190.0), (1200, 190.0), (1800, 130.0), (2400, 130.0)]);
    });

    test('back gas returned to -> drop split across windows by duration', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [
          _tank(id: 'back', start: 200, end: 65),
          _tank(id: 'deco', start: 190, end: 130, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200),
          _switch(tankId: 'back', timestamp: 1800),
        ],
        diveDurationSeconds: 2400,
      );
      // active [0,1200]+[1800,2400] = 1800s, drop 135 -> 0.075 bar/s.
      final back = result.pressures['back']!.map((p) => (p.timestamp, p.pressure));
      expect(back, [(0, 200.0), (1200, 110.0), (1800, 110.0), (2400, 65.0)]);
    });

    test('real data passes through untouched and is not marked estimated', () {
      final real = {
        't1': const [
          TankPressurePoint(id: 'r0', tankId: 't1', timestamp: 0, pressure: 205),
          TankPressurePoint(id: 'r1', tankId: 't1', timestamp: 600, pressure: 150),
        ],
      };
      final result = synthesizeEstimatedTankPressures(
        existing: real,
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 2400,
      );
      expect(result.estimatedTankIds, isEmpty);
      expect(result.pressures['t1'], same(real['t1']));
    });

    test('skips when a pressure is missing, equal, or inverted', () {
      for (final tank in [
        _tank(id: 'x', start: 200), // no end
        _tank(id: 'x', end: 100), // no start
        _tank(id: 'x', start: 100, end: 100), // equal
        _tank(id: 'x', start: 90, end: 120), // inverted
      ]) {
        final result = synthesizeEstimatedTankPressures(
          existing: const {},
          tanks: [tank],
          gasSwitches: const [],
          diveDurationSeconds: 2400,
        );
        expect(result.estimatedTankIds, isEmpty);
        expect(result.pressures.containsKey('x'), isFalse);
      }
    });

    test('no profile duration -> nothing synthesized', () {
      final result = synthesizeEstimatedTankPressures(
        existing: const {},
        tanks: [_tank(id: 't1', start: 200, end: 65)],
        gasSwitches: const [],
        diveDurationSeconds: 0,
      );
      expect(result.estimatedTankIds, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart`
Expected: FAIL — file/functions do not exist.

- [ ] **Step 3: Implement the synthesizer**

Create `estimated_tank_pressure_synthesizer.dart`:

```dart
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Real per-tank pressures augmented with in-memory linear estimates, plus the
/// set of tankIds that were synthesized (so the UI can label them "estimated").
class EstimatedTankPressures {
  final Map<String, List<TankPressurePoint>> pressures;
  final Set<String> estimatedTankIds;
  const EstimatedTankPressures(this.pressures, this.estimatedTankIds);
}

/// Builds transmitter-style linear pressure series for tanks that have both
/// start/end pressures but no time-series data. Never persists; pure.
///
/// For each qualifying tank the series is flat at startPressure until the tank
/// is first breathed, drops linearly while breathed (windowed by gas switches),
/// holds flat during gaps, and ends flat at endPressure. The total drop is
/// distributed across active windows in proportion to their duration.
EstimatedTankPressures synthesizeEstimatedTankPressures({
  required Map<String, List<TankPressurePoint>> existing,
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
}) {
  final pressures = <String, List<TankPressurePoint>>{...existing};
  final estimated = <String>{};
  if (diveDurationSeconds <= 0) {
    return EstimatedTankPressures(pressures, estimated);
  }

  final intervals = buildActiveTankIntervals(
    tanks: tanks,
    gasSwitches: gasSwitches,
    diveDurationSeconds: diveDurationSeconds,
  );

  for (final tank in tanks) {
    if (existing[tank.id]?.isNotEmpty ?? false) continue;
    final start = tank.startPressure;
    final end = tank.endPressure;
    if (start == null || end == null || start <= end) continue;

    final windows = intervals[tank.id] ?? const <({int start, int end})>[];
    final points = _buildFlatDropFlat(
      tankId: tank.id,
      startPressure: start,
      endPressure: end,
      // Fallback: a tank with start/end but no gas-switch evidence gets a
      // single full-dive window (a plain straight line).
      windows: windows.isEmpty
          ? [(start: 0, end: diveDurationSeconds)]
          : windows,
      diveDurationSeconds: diveDurationSeconds,
    );
    pressures[tank.id] = points;
    estimated.add(tank.id);
  }
  return EstimatedTankPressures(pressures, estimated);
}

List<TankPressurePoint> _buildFlatDropFlat({
  required String tankId,
  required double startPressure,
  required double endPressure,
  required List<({int start, int end})> windows,
  required int diveDurationSeconds,
}) {
  final sorted = [...windows]..sort((a, b) => a.start.compareTo(b.start));
  final totalActive = sorted.fold<int>(0, (s, w) => s + (w.end - w.start));
  if (totalActive <= 0) {
    return [
      _pt(tankId, 0, startPressure),
      _pt(tankId, diveDurationSeconds, endPressure),
    ];
  }
  final dropRate = (startPressure - endPressure) / totalActive;

  final points = <TankPressurePoint>[_pt(tankId, 0, startPressure)];
  var pressure = startPressure;

  if (sorted.first.start > 0) {
    points.add(_pt(tankId, sorted.first.start, startPressure));
  }
  for (var i = 0; i < sorted.length; i++) {
    final w = sorted[i];
    pressure -= dropRate * (w.end - w.start);
    points.add(_pt(tankId, w.end, pressure));
    if (i + 1 < sorted.length && sorted[i + 1].start > w.end) {
      points.add(_pt(tankId, sorted[i + 1].start, pressure));
    }
  }
  if (sorted.last.end < diveDurationSeconds) {
    points.add(_pt(tankId, diveDurationSeconds, endPressure));
  } else {
    // Clamp the final vertex to endPressure to absorb floating-point drift.
    points[points.length - 1] = _pt(tankId, sorted.last.end, endPressure);
  }
  return points;
}

TankPressurePoint _pt(String tankId, int ts, double pressure) =>
    TankPressurePoint(
      id: 'est-$tankId-$ts',
      tankId: tankId,
      timestamp: ts,
      pressure: pressure,
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart
flutter analyze lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart
git add lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart test/features/dive_log/data/services/estimated_tank_pressure_synthesizer_test.dart
git commit -m "feat(dive-log): synthesize linear tank pressure series for manual dives"
```

---

### Task 3: `estimatedTankPressuresProvider` — compose real + estimated

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Test: `test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart`

**Interfaces:**
- Consumes: `tankPressuresProvider` (family, `dive_providers.dart:950`), `diveProvider` (family, `:160`, returns `Dive?`), `gasSwitchesProvider` (family, `gas_switch_providers.dart:9`), `synthesizeEstimatedTankPressures` + `EstimatedTankPressures` (Task 2).
- Produces: `final estimatedTankPressuresProvider = FutureProvider.family<EstimatedTankPressures, String>(...)`.

- [ ] **Step 1: Write the failing test**

Create the test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';

void main() {
  test('augments real map with an estimated line for a manual tank', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      tanks: const [
        DiveTank(
          id: 't1',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 60,
        ),
      ],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        tankPressuresProvider('d1').overrideWith(
          (ref) async => <String, List<TankPressurePoint>>{},
        ),
        diveProvider('d1').overrideWith((ref) async => dive),
        gasSwitchesProvider('d1').overrideWith(
          (ref) async => <GasSwitchWithTank>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(estimatedTankPressuresProvider('d1').future);

    expect(result.estimatedTankIds, {'t1'});
    expect(result.pressures['t1']!.first.pressure, 200);
    expect(result.pressures['t1']!.last.pressure, 60);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart`
Expected: FAIL — `estimatedTankPressuresProvider` is not defined.

- [ ] **Step 3: Add the provider**

Add these imports near the other imports in `dive_providers.dart`:

```dart
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
```

Add the provider next to `tankPressuresProvider` (around `dive_providers.dart:959`):

```dart
/// Real per-tank pressures augmented with in-memory linear estimates for tanks
/// that have start/end pressures but no transmitter data. Chart-only; the
/// estimates are never persisted, so SAC analysis and exports (which read the
/// repository directly) still see real data only.
final estimatedTankPressuresProvider =
    FutureProvider.family<EstimatedTankPressures, String>((ref, diveId) async {
      final real = await ref.watch(tankPressuresProvider(diveId).future);
      final dive = await ref.watch(diveProvider(diveId).future);
      final switches = await ref.watch(gasSwitchesProvider(diveId).future);
      if (dive == null) {
        return EstimatedTankPressures(real, const <String>{});
      }
      return synthesizeEstimatedTankPressures(
        existing: real,
        tanks: dive.tanks,
        gasSwitches: switches,
        diveDurationSeconds:
            dive.profile.isEmpty ? 0 : dive.profile.last.timestamp,
      );
    });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart
flutter analyze lib/features/dive_log/presentation/providers/dive_providers.dart
git add lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/estimated_tank_pressures_provider_test.dart
git commit -m "feat(dive-log): add estimatedTankPressuresProvider composing real+estimated pressures"
```

---

### Task 4: Localized "(est.)" suffix string

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (template, with description) and the other 10 arb files.
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`.

**Interfaces:**
- Produces: `AppLocalizations.diveLog_pressure_estimatedSuffix` → getter returning the localized "(est.)" string, consumed by Tasks 6 and 7.

- [ ] **Step 1: Add the key to `app_en.arb`**

Insert after the `"diveLog_chartSection_tankPressures"` entry (near `app_en.arb:2229`):

```json
  "diveLog_pressure_estimatedSuffix": "(est.)",
  "@diveLog_pressure_estimatedSuffix": {
    "description": "Short suffix appended to a tank label when its pressure line is a linear start-to-end estimate rather than measured air-integrated data. Abbreviation of 'estimated'."
  },
```

- [ ] **Step 2: Add the translated key to the other 10 arb files**

Add the entry to each file with these values (no `@` metadata needed in non-template files):

```
app_de.arb: "diveLog_pressure_estimatedSuffix": "(gesch.)",
app_es.arb: "diveLog_pressure_estimatedSuffix": "(est.)",
app_fr.arb: "diveLog_pressure_estimatedSuffix": "(est.)",
app_it.arb: "diveLog_pressure_estimatedSuffix": "(stim.)",
app_pt.arb: "diveLog_pressure_estimatedSuffix": "(est.)",
app_nl.arb: "diveLog_pressure_estimatedSuffix": "(gesch.)",
app_hu.arb: "diveLog_pressure_estimatedSuffix": "(becs.)",
app_ar.arb: "diveLog_pressure_estimatedSuffix": "(تقديري)",
app_he.arb: "diveLog_pressure_estimatedSuffix": "(משוער)",
app_zh.arb: "diveLog_pressure_estimatedSuffix": "(估算)",
```

Insert each in the same relative position as in the template (place it beside the existing `diveLog_chartSection_tankPressures` entry in each file to keep diffs local).

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` updated; no errors.

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/l10n`
Expected: clean. Confirm `AppLocalizations` now exposes `diveLog_pressure_estimatedSuffix`.

- [ ] **Step 5: Format, commit**

```bash
dart format lib/l10n/arb/app_localizations.dart
git add lib/l10n/arb
git commit -m "i18n(dive-log): add estimated-pressure suffix string in all locales"
```

---

### Task 5: Chart — `estimatedTankIds` field + crisp (straight) estimated line

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (field ~`:130`, ctor ~`:453`, `_buildMultiTankPressureLines` ~`:3653`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart` (helper `_buildChart` ~`:91/:142`, new test)

**Interfaces:**
- Consumes: `EstimatedTankPressures.estimatedTankIds` (Task 2/3) — passed in as `Set<String>?`.
- Produces: `DiveProfileChart({..., Set<String>? estimatedTankIds})` field, and estimated pressure lines rendered with `isCurved: false`.

- [ ] **Step 1: Write the failing test**

First extend the `_buildChart` helper: add `Set<String>? estimatedTankIds,` to its parameter list (beside `tanks`) and `estimatedTankIds: estimatedTankIds,` to the `DiveProfileChart(...)` call. Then add this test (a synthesized single-tank line is straight + dashed; a real line is curved + dashed):

```dart
  testWidgets('estimated tank pressure line is straight (isCurved false)', (
    tester,
  ) async {
    const tank = DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0);
    final points = const [
      TankPressurePoint(id: 'e0', tankId: 't1', timestamp: 0, pressure: 200),
      TankPressurePoint(id: 'e1', tankId: 't1', timestamp: 270, pressure: 60),
    ];

    await tester.pumpWidget(
      _buildChart(
        tanks: const [tank],
        tankPressures: {'t1': points},
        estimatedTankIds: const {'t1'},
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final estimatedBars = chart.data.lineBarsData
        .where((b) => b.dashArray != null && b.isCurved == false)
        .toList();
    expect(estimatedBars, isNotEmpty);

    // Control: same data, NOT estimated -> pressure line is curved.
    await tester.pumpWidget(
      _buildChart(tanks: const [tank], tankPressures: {'t1': points}),
    );
    await tester.pumpAndSettle();
    final chart2 = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart2.data.lineBarsData.where(
        (b) => b.dashArray != null && b.isCurved == false,
      ),
      isEmpty,
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --plain-name "estimated tank pressure line is straight"`
Expected: FAIL — `estimatedTankIds` is not a parameter of `DiveProfileChart` (compile error) or the estimated bar is still curved.

- [ ] **Step 3: Add the field and use it**

In `dive_profile_chart.dart`, declare the field next to `tankPressures` (after `:130`):

```dart
  /// Tank IDs whose pressure series is a synthesized linear estimate (no AI
  /// data). Rendered straight and labelled "(est.)".
  final Set<String>? estimatedTankIds;
```

Add to the constructor next to `this.tankPressures,` (after `:453`):

```dart
    this.estimatedTankIds,
```

In `_buildMultiTankPressureLines`, change the `LineChartBarData`'s `isCurved: true,` (`:3653`) to:

```dart
          isCurved: !(widget.estimatedTankIds?.contains(tankId) ?? false),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --plain-name "estimated tank pressure line is straight"`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat(dive-log): render estimated tank pressure lines straight on the profile chart"
```

---

### Task 6: Chart — "(est.)" suffix in tooltip and readout rows

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (tooltip rows ~`:1254`, readout rows ~`:2843`, add helper)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `widget.estimatedTankIds` (Task 5), `context.l10n.diveLog_pressure_estimatedSuffix` (Task 4).
- Produces: tooltip/readout tank rows whose label ends with the localized "(est.)" for estimated tanks.

- [ ] **Step 1: Write the failing test**

Add this test (long-press emits external tooltip rows, as in the existing `_emitExternalTooltip` tests):

```dart
  testWidgets('tooltip labels an estimated tank with the (est.) suffix', (
    tester,
  ) async {
    // 20-point profile matching the proven long-press tooltip tests, so the
    // gesture reliably lands on a data point and emits external tooltip rows.
    final profile = List.generate(
      20,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i < 10 ? i * 3.0 : (19 - i) * 3.0,
      ),
    );
    const tank = DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0);
    // A straight two-point estimate spanning the whole profile (0..570s).
    const points = [
      TankPressurePoint(id: 'e0', tankId: 't1', timestamp: 0, pressure: 200),
      TankPressurePoint(id: 'e1', tankId: 't1', timestamp: 570, pressure: 60),
    ];
    List<TooltipRow>? rows;

    await tester.pumpWidget(
      _buildChart(
        profile: profile,
        tanks: const [tank],
        tankPressures: {'t1': points},
        estimatedTankIds: const {'t1'},
        tooltipBelow: true,
        onTooltipData: (r) => rows = r,
      ),
    );
    await tester.pumpAndSettle();

    // Long-press near the center; assert BEFORE releasing (release clears rows).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineChart)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();

    expect(rows, isNotNull);
    expect(rows!.where((r) => r.label.contains('(est.)')), isNotEmpty);
    await gesture.up();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --plain-name "tooltip labels an estimated tank"`
Expected: FAIL — no tank row label contains "(est.)".

- [ ] **Step 3: Add the suffix helper and apply it**

Add a helper method inside the `DiveProfileChart` state class (near the other tank helpers):

```dart
  String _estimatedSuffix(String tankId) =>
      (widget.estimatedTankIds?.contains(tankId) ?? false)
      ? ' ${context.l10n.diveLog_pressure_estimatedSuffix}'
      : '';
```

In the **tooltip** builder (`:1254-1256`), append the suffix:

```dart
        final tankLabel =
            DiveProfileChart.tankTooltipLabel(tank, 'Tank ${i + 1}') +
            _tankSourceSuffix(tankId, tankComputerIds, contributingComputerIds) +
            _estimatedSuffix(tankId);
```

In the **readout** builder (`:2843-2852`), append the suffix:

```dart
                        final tankLabel =
                            DiveProfileChart.tankTooltipLabel(
                              tank,
                              context.l10n.diveLog_tank_title(i + 1),
                            ) +
                            _tankSourceSuffix(
                              tankId,
                              tankComputerIds,
                              contributingComputerIds,
                            ) +
                            _estimatedSuffix(tankId);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --plain-name "tooltip labels an estimated tank"`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat(dive-log): mark estimated tank pressure in chart tooltip and readout"
```

---

### Task 7: Legend — "(est.)" suffix on estimated tank rows

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` (`ProfileLegendConfig` ~`:13-57`, tank-pressures section ~`:590-592`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (legend config build ~`:1478`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

**Interfaces:**
- Consumes: `widget.estimatedTankIds` (Task 5), `context.l10n.diveLog_pressure_estimatedSuffix` (Task 4).
- Produces: `ProfileLegendConfig.estimatedTankIds` (`Set<String>`, default `const {}`), rendered as a "(est.)" suffix on matching tank rows in the "Tank Pressures" dialog section.

- [ ] **Step 1: Write the failing test**

Add this test to `dive_profile_legend_test.dart` (mirrors the existing tune-dialog pattern):

```dart
  testWidgets('estimated tank row shows the (est.) suffix', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: DiveProfileLegend(
          config: const ProfileLegendConfig(
            hasMultiTankPressure: true,
            tanks: _testTanks,
            tankPressures: {
              'tank-1': [
                TankPressurePoint(
                  id: 'e0',
                  tankId: 'tank-1',
                  timestamp: 0,
                  pressure: 200,
                ),
              ],
            },
            estimatedTankIds: {'tank-1'},
          ),
          zoomLevel: 1.0,
          onZoomIn: () {},
          onZoomOut: () {},
          onResetZoom: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tank Pressures lives in the "more options" (tune) dialog.
    await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('(est.)'), findsWidgets);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart --plain-name "estimated tank row"`
Expected: FAIL — `estimatedTankIds` is not a parameter of `ProfileLegendConfig` (compile error).

- [ ] **Step 3: Add the config field**

In `dive_profile_legend.dart`, add the field to `ProfileLegendConfig` (after `tankPressures`, `:28`):

```dart
  final Set<String> estimatedTankIds;
```

Add to the constructor (after `this.tankPressures,`):

```dart
    this.estimatedTankIds = const {},
```

- [ ] **Step 4: Render the suffix in the tank-pressures section**

In the "Tank Pressures" section (`:590-592`), replace the `label` assignment:

```dart
        final baseLabel = tank != null
            ? _buildTankLabel(context, tank, fallbackIndex: i + 1)
            : context.l10n.diveLog_tank_title(i + 1);
        final label = config.estimatedTankIds.contains(tankId)
            ? '$baseLabel ${context.l10n.diveLog_pressure_estimatedSuffix}'
            : baseLabel;
```

- [ ] **Step 5: Pass the set from the chart into the config**

In `dive_profile_chart.dart`, in the `ProfileLegendConfig(...)` construction (after `tankPressures: widget.tankPressures,`, `:1478`):

```dart
      estimatedTankIds: widget.estimatedTankIds ?? const {},
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart --plain-name "estimated tank row"`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git add lib/features/dive_log/presentation/widgets/dive_profile_legend.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "feat(dive-log): label estimated tanks in the profile legend"
```

---

### Task 8: Wire the three chart hosts to the estimated provider

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`

**Interfaces:**
- Consumes: `estimatedTankPressuresProvider` (Task 3), `DiveProfileChart.estimatedTankIds` (Task 5).
- Produces: all three chart hosts feed the augmented map + estimated set to the chart. No new public API.

- [ ] **Step 1: Update `dive_profile_panel.dart`**

Replace the `tankPressures` watch (around `:248`):

```dart
    final estimated = ref
        .watch(estimatedTankPressuresProvider(widget.diveId))
        .valueOrNull;
    final tankPressures = estimated?.pressures;
```

Pass the estimated set to the chart alongside `tankPressures:` (around `:390`):

```dart
                  tankPressures: tankPressures,
                  estimatedTankIds: estimated?.estimatedTankIds,
```

Add the import if not present:

```dart
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
```
(The panel already imports `dive_providers.dart` for `tankPressuresProvider`; keep a single import. Remove the now-unused `tankPressuresProvider` reference only if nothing else uses it.)

- [ ] **Step 2: Update `dive_detail_page.dart`**

Find where it reads `tankPressuresProvider(...)` (around `:1063-1064`) and passes `tankPressures:` to `DiveProfileChart` (around `:1334`). Apply the same change: read `estimatedTankPressuresProvider`, pass `tankPressures: estimated?.pressures` and add `estimatedTankIds: estimated?.estimatedTankIds`.

```dart
    final estimated = ref
        .watch(estimatedTankPressuresProvider(dive.id))
        .valueOrNull;
```
```dart
              tankPressures: estimated?.pressures,
              estimatedTankIds: estimated?.estimatedTankIds,
```

- [ ] **Step 3: Update `fullscreen_profile_page.dart`**

Same change at its `tankPressuresProvider` read (around `:143`) and its `DiveProfileChart(...)` `tankPressures:` argument (around `:353/:365`):

```dart
    final estimated = ref
        .watch(estimatedTankPressuresProvider(diveId))
        .valueOrNull;
```
```dart
            tankPressures: estimated?.pressures,
            estimatedTankIds: estimated?.estimatedTankIds,
```

- [ ] **Step 4: Analyze and run affected tests**

Run:
```bash
flutter analyze lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
```
Expected: analyze clean; tests PASS.

- [ ] **Step 5: Manual verification (per the verify skill)**

Launch the app (`flutter run -d macos`), open a dive that has a tank with start/end pressures but no AI data (or add one via edit). Confirm:
1. A dashed, gas-colored, **straight** pressure line appears on the profile chart.
2. The legend's "Tank Pressures" (tune dialog) row and the hover tooltip/readout show the tank with a "(est.)" suffix.
3. A dive **with** real AI pressure data still shows its curved line and no "(est.)" tag.

- [ ] **Step 6: Format, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart
git add lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart
git commit -m "feat(dive-log): show estimated tank pressure lines on all profile chart hosts (#197)"
```

---

## Final verification

- [ ] Run the full dive_log test suite:
  ```bash
  flutter test test/features/dive_log/
  ```
  Expected: all PASS.
- [ ] Whole-project format + analyze:
  ```bash
  dart format . && flutter analyze
  ```
  Expected: no changes, no issues.
