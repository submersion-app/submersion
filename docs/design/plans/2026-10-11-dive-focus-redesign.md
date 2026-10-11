# Dive Focus Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the Insights Dive focus page so the finding leads, the controls read as a sentence, the chart shows the group, and fourteen metrics are available.

**Architecture:** The domain stays pure Dart (metrics, selection, group, factor analysis) and gains a strength score; the repository gains eight per-dive series in a new part file; the page's slivers are reordered around three new widgets (sentence builder, standouts card, reworked comparison table) and two small additions to the shared trend chart (per-series point radius, a reference line).

**Tech Stack:** Flutter, Riverpod (`StateProvider`, `FutureProvider`), Drift `customSelect`, fl_chart, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-10-11-dive-focus-redesign-design.md`

## Global Constraints

- No em-dashes in any output. No emojis. No mention of any AI tool in commits, PR or code.
- Every file under 800 lines; `dive_trend_chart.dart` is at 771, so new chart code goes in `trend_reference_line.dart`.
- Imports grouped dart, flutter, packages, local. `dart format .` before every commit.
- Values display in the active diver's units through `UnitFormatter`; storage units are litres, bar, metres, minutes, kilograms, Celsius, percent.
- Every new ARB key lands in `app_en.arb` with its `@meta` and is translated into all ten locale files (ar, de, es, fr, he, hu, it, nl, pt, zh) by anchor-line insertion, never a JSON round trip. Locale files carry no `@meta`. `test/l10n/arb_parity_test.dart` is red between Task 1 and Task 10; run it at Task 10.
- A threshold is entered in display units and stored in storage units ("above" is strictly greater, "below" strictly less).
- The selection lasts for the session only; nothing is persisted.
- Tests first for every task. Run `flutter analyze` and `test/architecture/` plus `test/shared/` after adding files under `lib/`.
- Commits are preauthorized by the build-feature skill; one per task, `feat(insights): ...`.

## Review Focus

1. A metric whose series is empty for this diver (no CNS ever logged): the sentence still renders, the summary shows the empty state, and switching to above/below does not throw on a null mean. Pinned in Task 6 (sentence) and Task 9 (results).
2. A threshold typed in imperial for a new metric (visibility in feet, altitude in feet, gas used in cuft) must be stored in metres or litres. Pinned in Task 1 (units) and Task 6 (sentence).
3. A group of exactly 5 dives with "Show all" absent, and a group of 6 with the button present and the count correct. Pinned in Task 9.
4. A factor report where every row is quiet: the table shows no group headings, only the Show more button, and the standouts card says nothing stands out. Pinned in Task 8.
5. Switching the metric while in a threshold mode: the old threshold is cleared and the new metric's mean is applied once it loads, without a stale value from the previous metric's units. Pinned in Task 6.

---

### Task 1: Fourteen metrics in the domain and the formatters

**Files:**
- Modify: `lib/features/insights/domain/focus/focus_metric.dart`
- Modify: `lib/features/insights/presentation/formatters/focus_metric_units.dart`
- Modify: `lib/features/insights/presentation/formatters/focus_labels.dart`
- Modify: `lib/features/insights/domain/focus/focus_factor_analyzer.dart` (self-factor rule)
- Modify: `lib/l10n/arb/app_en.arb` (anchor: after `"insights_focus_metric_waterTemp"`)
- Test: `test/features/insights/presentation/formatters/focus_metric_units_test.dart` (new)
- Test: `test/features/insights/domain/focus/focus_factor_analyzer_test.dart` (add two tests)

**Interfaces:**
- Produces: `enum FocusMetricGroup { gas, depthTime, conditions, exposure, kit }`; `FocusMetric` gains `gasUsed, avgDepth, surfaceInterval, airTemp, visibility, altitude, cns, otu`, a `group` field and `lowerIsBetter`; `focusMetricGroupLabel(FocusMetricGroup, AppLocalizations)`; `FocusMetricUnits` handles every metric.

- [ ] **Step 1: Write the failing units test**

```dart
// test/features/insights/presentation/formatters/focus_metric_units_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();
  const metric = AppSettings();
  const imperial = AppSettings(
    depthUnit: DepthUnit.feet,
    volumeUnit: VolumeUnit.cubicFeet,
    temperatureUnit: TemperatureUnit.fahrenheit,
    altitudeUnit: AltitudeUnit.feet,
  );
  FocusMetricUnits units(FocusMetric m, AppSettings s) =>
      FocusMetricUnits(m, UnitFormatter(s));

  test('every metric has a symbol and round-trips through display', () {
    for (final m in FocusMetric.values) {
      for (final s in [metric, imperial]) {
        final u = units(m, s);
        expect(u.symbol(l10n), isNotNull, reason: '$m');
        expect(u.toStorage(u.toDisplay(12.5)), closeTo(12.5, 1e-6), reason: '$m');
        expect(u.format(12.5, l10n), isNotEmpty, reason: '$m');
      }
    }
  });

  test('imperial visibility, altitude and gas used store metric', () {
    expect(units(FocusMetric.visibility, imperial).toStorage(100), closeTo(30.48, 0.01));
    expect(units(FocusMetric.altitude, imperial).toStorage(1000), closeTo(304.8, 0.1));
    expect(units(FocusMetric.gasUsed, imperial).toStorage(10), closeTo(283.17, 0.1));
  });

  test('surface interval formats as hours and minutes', () {
    expect(units(FocusMetric.surfaceInterval, metric).format(95, l10n), '1h 35m');
    expect(units(FocusMetric.surfaceInterval, metric).format(45, l10n), '45 min');
  });

  test('cns and otu are unitless percent and count', () {
    expect(units(FocusMetric.cns, metric).format(37.4, l10n), '37%');
    expect(units(FocusMetric.otu, metric).format(120.6, l10n), '121');
  });

  test('only the two temperatures allow a negative threshold', () {
    for (final m in FocusMetric.values) {
      expect(
        units(m, metric).allowsNegative,
        m == FocusMetric.waterTemp || m == FocusMetric.airTemp,
        reason: '$m',
      );
    }
  });

  test('metrics are grouped and gas metrics are lower-is-better', () {
    expect(FocusMetric.gasUsed.group, FocusMetricGroup.gas);
    expect(FocusMetric.surfaceInterval.group, FocusMetricGroup.depthTime);
    expect(FocusMetric.cns.group, FocusMetricGroup.exposure);
    expect(FocusMetric.values.where((m) => m.lowerIsBetter).toList(), [
      FocusMetric.rmv, FocusMetric.sac, FocusMetric.gasUsed,
    ]);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/formatters/focus_metric_units_test.dart`
Expected: FAIL, `gasUsed` is not a member of `FocusMetric`.

- [ ] **Step 3: Add the English strings**

Insert after the `"insights_focus_metric_waterTemp"` line in `app_en.arb` (plain keys, no placeholders, no `@meta` needed):

```json
  "insights_focus_metric_gasUsed": "Gas used",
  "insights_focus_metric_avgDepth": "Average depth",
  "insights_focus_metric_surfaceInterval": "Surface interval",
  "insights_focus_metric_airTemp": "Air temp",
  "insights_focus_metric_visibility": "Visibility",
  "insights_focus_metric_altitude": "Altitude",
  "insights_focus_metric_cns": "CNS at end",
  "insights_focus_metric_otu": "OTU",
  "insights_focus_metricGroup_gas": "Gas",
  "insights_focus_metricGroup_depthTime": "Depth and time",
  "insights_focus_metricGroup_conditions": "Conditions",
  "insights_focus_metricGroup_exposure": "Exposure",
  "insights_focus_metricGroup_kit": "Kit",
```

Then `flutter gen-l10n`.

- [ ] **Step 4: Implement the enum, units and labels**

`focus_metric.dart`:

```dart
/// Where a metric sits in the sentence builder's grouped menu.
enum FocusMetricGroup { gas, depthTime, conditions, exposure, kit }

/// A per-dive value Dive focus can rank or threshold on. Each reuses a
/// per-dive series the repository already computes, so a dive's value here
/// is exactly its value on the matching trend chart.
enum FocusMetric {
  rmv(FocusMetricGroup.gas, lowerIsBetter: true),
  sac(FocusMetricGroup.gas, lowerIsBetter: true),
  gasUsed(FocusMetricGroup.gas, lowerIsBetter: true),
  maxDepth(FocusMetricGroup.depthTime),
  avgDepth(FocusMetricGroup.depthTime),
  bottomTime(FocusMetricGroup.depthTime),
  surfaceInterval(FocusMetricGroup.depthTime),
  waterTemp(FocusMetricGroup.conditions),
  airTemp(FocusMetricGroup.conditions),
  visibility(FocusMetricGroup.conditions),
  altitude(FocusMetricGroup.conditions),
  cns(FocusMetricGroup.exposure),
  otu(FocusMetricGroup.exposure),
  weight(FocusMetricGroup.kit);

  const FocusMetric(this.group, {this.lowerIsBetter = false});

  final FocusMetricGroup group;

  /// Gas consumption is better when lower; the other metrics have no better
  /// end, so their modes read "lowest" and "highest".
  final bool lowerIsBetter;
}
```

`focus_metric_units.dart`: extend every switch. New arms:

```dart
  bool get allowsNegative =>
      metric == FocusMetric.waterTemp || metric == FocusMetric.airTemp;

  // symbol
    FocusMetric.gasUsed => units.volumeSymbol,
    FocusMetric.avgDepth => units.depthSymbol,
    FocusMetric.surfaceInterval => l10n.insights_focus_unit_minutes,
    FocusMetric.airTemp => units.temperatureSymbol,
    FocusMetric.visibility => units.depthSymbol,
    FocusMetric.altitude => units.altitudeSymbol,
    FocusMetric.cns => '%',
    FocusMetric.otu => l10n.insights_focus_metric_otu,
  // toDisplay
    FocusMetric.gasUsed => units.convertVolume(storage),
    FocusMetric.avgDepth || FocusMetric.visibility => units.convertDepth(storage),
    FocusMetric.surfaceInterval || FocusMetric.cns || FocusMetric.otu => storage,
    FocusMetric.airTemp => units.convertTemperature(storage),
    FocusMetric.altitude => units.convertAltitude(storage),
  // toStorage
    FocusMetric.gasUsed => units.volumeToLiters(display),
    FocusMetric.avgDepth || FocusMetric.visibility => units.depthToMeters(display),
    FocusMetric.surfaceInterval || FocusMetric.cns || FocusMetric.otu => display,
    FocusMetric.airTemp => units.temperatureToCelsius(display),
    FocusMetric.altitude => units.altitudeToMeters(display),
  // format
    FocusMetric.gasUsed => units.formatVolume(storage),
    FocusMetric.avgDepth => units.formatDepth(storage),
    FocusMetric.surfaceInterval => _hoursMinutes(storage, l10n),
    FocusMetric.airTemp => units.formatTemperature(storage),
    FocusMetric.visibility => units.formatDistance(storage),
    FocusMetric.altitude => units.formatAltitude(storage),
    FocusMetric.cns => '${storage.round()}%',
    FocusMetric.otu => '${storage.round()}',

  /// The Time patterns page's surface interval wording.
  static String _hoursMinutes(double minutes, AppLocalizations l10n) {
    final whole = minutes.round();
    if (whole < 60) return l10n.insights_timePatterns_surfaceInterval_formatMinutes(whole);
    return l10n.insights_timePatterns_surfaceInterval_formatHoursMinutes(
      whole ~/ 60,
      whole % 60,
    );
  }
```

Check the generated signatures of the two surface interval messages (`grep -n "formatHoursMinutes\|formatMinutes" lib/l10n/arb/app_localizations.dart`) and pass the placeholder types they declare.

`focus_labels.dart`: add the eight label arms and

```dart
String focusMetricGroupLabel(FocusMetricGroup group, AppLocalizations l10n) =>
    switch (group) {
      FocusMetricGroup.gas => l10n.insights_focus_metricGroup_gas,
      FocusMetricGroup.depthTime => l10n.insights_focus_metricGroup_depthTime,
      FocusMetricGroup.conditions => l10n.insights_focus_metricGroup_conditions,
      FocusMetricGroup.exposure => l10n.insights_focus_metricGroup_exposure,
      FocusMetricGroup.kit => l10n.insights_focus_metricGroup_kit,
    };
```

`focus_factor_analyzer.dart` `_selfFactor`:

```dart
    FocusMetric.maxDepth => FocusFactorId.maxDepth,
    FocusMetric.avgDepth => FocusFactorId.avgDepth,
    FocusMetric.bottomTime => FocusFactorId.duration,
    FocusMetric.weight => FocusFactorId.weight,
    FocusMetric.waterTemp => FocusFactorId.waterTemp,
    FocusMetric.visibility => FocusFactorId.visibility,
    _ => null,
```

Add to `focus_factor_analyzer_test.dart`:

```dart
  test('ranking by average depth or visibility omits that factor', () {
    for (final (metric, id) in [
      (FocusMetric.avgDepth, FocusFactorId.avgDepth),
      (FocusMetric.visibility, FocusFactorId.visibility),
    ]) {
      final report = FocusFactorAnalyzer.analyze(
        group: baseline.take(3).toList(),
        baseline: baseline,
        metric: metric,
      );
      expect(report.factors.map((f) => f.id), isNot(contains(id)));
    }
  });
```

`insights_focus_providers.dart` will not compile until Task 3 adds arms; to keep this task green, add a temporary `default` arm there that throws `UnimplementedError('Task 3')` for the eight new metrics, and remove it in Task 3.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights/presentation/formatters/focus_metric_units_test.dart test/features/insights/domain/focus/ test/features/insights/presentation/widgets/focus/focus_selector_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/insights
git commit -m "feat(insights): add eight Dive focus metrics with units and labels"
```

---

### Task 2: Eight per-dive series in the repository

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_focus_series.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (add `part 'insights_repository_focus_series.dart';` beside the existing focus part)
- Test: `test/features/insights/data/repositories/focus_metric_series_test.dart` (new)

**Interfaces:**
- Produces, on `InsightsRepository`, each `({String? diverId, DiveFilterState filter = const DiveFilterState()}) -> Future<List<TrendDataPoint>>`: `getAvgDepthPerDive`, `getSurfaceIntervalPerDive` (minutes), `getAirTempPerDive`, `getVisibilityPerDive` (metres), `getAltitudePerDive` (metres), `getCnsPerDive`, `getOtuPerDive`, `getGasUsedPerDive` (litres).

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/insights/data/repositories/focus_metric_series_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> dive(
    String id, {
    int day = 1,
    double? avgDepth,
    int? surfaceIntervalSeconds,
    double? airTemp,
    double? visibilityMeters,
    double? altitude,
    double? cnsEnd,
    double? otu,
    bool excluded = false,
    bool planned = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(id),
        diveDateTime: Value(DateTime.utc(2025, 3, day, 9).millisecondsSinceEpoch),
        avgDepth: Value(avgDepth),
        surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
        airTemp: Value(airTemp),
        visibilityMeters: Value(visibilityMeters),
        altitude: Value(altitude),
        cnsEnd: Value(cnsEnd),
        otu: Value(otu),
        excludedFromStats: Value(excluded),
        isPlanned: Value(planned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> tank(String diveId, int order, {double volume = 12, double start = 200, double end = 100}) =>
      db.into(db.diveTanks).insert(
        DiveTanksCompanion(
          id: Value('t-$diveId-$order'),
          diveId: Value(diveId),
          volume: Value(volume),
          startPressure: Value(start),
          endPressure: Value(end),
          o2Percent: const Value(21.0),
          hePercent: const Value(0.0),
          tankOrder: Value(order),
          tankRole: const Value('backGas'),
        ),
      );

  test('each column series returns dives that have the value, by date', () async {
    await dive('b', day: 2, avgDepth: 14, surfaceIntervalSeconds: 5400, airTemp: 22, visibilityMeters: 15, altitude: 300, cnsEnd: 12, otu: 30);
    await dive('a', day: 1, avgDepth: 10, surfaceIntervalSeconds: 600, airTemp: 18, visibilityMeters: 5, altitude: 0, cnsEnd: 8, otu: 20);
    await dive('none', day: 3);

    final cases = <String, Future<List<TrendDataPoint>>>{
      'avgDepth': repository.getAvgDepthPerDive(),
      'surfaceInterval': repository.getSurfaceIntervalPerDive(),
      'airTemp': repository.getAirTempPerDive(),
      'visibility': repository.getVisibilityPerDive(),
      'altitude': repository.getAltitudePerDive(),
      'cns': repository.getCnsPerDive(),
      'otu': repository.getOtuPerDive(),
    };
    for (final entry in cases.entries) {
      final points = await entry.value;
      expect(points.map((p) => p.diveId), ['a', 'b'], reason: entry.key);
    }
    expect((await repository.getSurfaceIntervalPerDive()).map((p) => p.value), [10, 90]);
    expect((await repository.getAltitudePerDive()).map((p) => p.value), [0, 300]);
  });

  test('gas used sums every tank of a dive in litres', () async {
    await dive('twin');
    await tank('twin', 0, volume: 12, start: 200, end: 100);
    await tank('twin', 1, volume: 12, start: 200, end: 150);
    await dive('empty');
    await tank('empty', 0, start: 100, end: 100);

    final points = await repository.getGasUsedPerDive();

    expect(points.single.diveId, 'twin');
    expect(points.single.value, closeTo(1800, 0.01));
  });

  test('excluded and planned dives are out of every series', () async {
    await dive('x', avgDepth: 10, cnsEnd: 5, excluded: true);
    await dive('p', avgDepth: 10, cnsEnd: 5, planned: true);
    await tank('x', 0);
    await tank('p', 0);

    expect(await repository.getAvgDepthPerDive(), isEmpty);
    expect(await repository.getCnsPerDive(), isEmpty);
    expect(await repository.getGasUsedPerDive(), isEmpty);
  });
}
```

Check how `focus_factor_rows_test.dart` proves planned and excluded dives drop out (its `dive` helper) and copy any column it sets that `_diveFilter` reads.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/insights/data/repositories/focus_metric_series_test.dart`
Expected: FAIL, `getAvgDepthPerDive` is not defined.

- [ ] **Step 3: Implement the part file**

```dart
// lib/features/insights/data/repositories/insights_repository_focus_series.dart
part of 'insights_repository.dart';

/// Per-dive series for the Dive focus metrics that have no trend chart of
/// their own. Each reads one column of `dives`, scoped like every other
/// descriptive aggregate, and skips dives without the value.
extension InsightsRepositoryFocusSeries on InsightsRepository {
  Future<List<TrendDataPoint>> getAvgDepthPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.avg_depth', 'average depth', diverId, filter);

  /// Minutes, from the stored seconds.
  Future<List<TrendDataPoint>> getSurfaceIntervalPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries(
    'd.surface_interval_seconds / 60.0',
    'surface interval',
    diverId,
    filter,
  );

  Future<List<TrendDataPoint>> getAirTempPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.air_temp', 'air temperature', diverId, filter);

  /// Metres typed by the diver; a dive logged only with a band has none.
  Future<List<TrendDataPoint>> getVisibilityPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.visibility_meters', 'visibility', diverId, filter);

  Future<List<TrendDataPoint>> getAltitudePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.altitude', 'altitude', diverId, filter);

  Future<List<TrendDataPoint>> getCnsPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.cns_end', 'CNS', diverId, filter);

  Future<List<TrendDataPoint>> getOtuPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.otu', 'OTU', diverId, filter);

  /// Litres breathed over the dive, summed across its tanks with the same
  /// per-tank volume rule the RMV series uses, before any division by time
  /// or depth.
  Future<List<TrendDataPoint>> getGasUsedPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = [?diverId, ...df.params];
      final results = await _db.customSelect('''
        SELECT d.id AS dive_id,
               d.dive_date_time AS dive_date_time,
               SUM((t.start_pressure - t.end_pressure)
                   * ${consumptionVolumeSql('t')}) AS litres
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE t.start_pressure > t.end_pressure
          $diverFilter ${df.clause}
        GROUP BY d.id
        HAVING litres > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();
      return [
        for (final row in results)
          TrendDataPoint(
            date: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('dive_date_time'),
              isUtc: true,
            ),
            value: row.read<double>('litres'),
            diveId: row.read<String>('dive_id'),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error('Failed to get per-dive gas used', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// One value per dive from [expression] over alias `d`, dives without it
  /// skipped, oldest first. [what] names the series in the error log.
  Future<List<TrendDataPoint>> _columnSeries(
    String expression,
    String what,
    String? diverId,
    DiveFilterState filter,
  ) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = [?diverId, ...df.params];
      final results = await _db.customSelect('''
        SELECT d.id AS dive_id, d.dive_date_time AS dive_date_time,
               ($expression) AS value
        FROM dives d
        WHERE ($expression) IS NOT NULL $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();
      return [
        for (final row in results)
          TrendDataPoint(
            date: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('dive_date_time'),
              isUtc: true,
            ),
            value: row.read<double>('value'),
            diveId: row.read<String>('dive_id'),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error('Failed to get per-dive $what', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

`consumptionVolumeSql` comes from `lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart`, already imported by `insights_repository.dart`. If a `_diveFilter` clause for `df.params` needs `diverId` first, keep the order `[?diverId, ...df.params]` as `getFocusFactorRows` does. `row.read<double>` on an integer SQLite column: if the altitude test fails with a type error, read as `num` and call `.toDouble()`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/insights/data/repositories/focus_metric_series_test.dart test/features/insights/data/repositories/dive_stats_scope_behavior_test.dart`
Expected: PASS (the scope census must still pass with eight new methods; if it lists methods by name, add the eight to its expected set).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights/data test/features/insights/data
git commit -m "feat(insights): per-dive series for the new Dive focus metrics"
```

---

### Task 3: Provider arms and the threshold default

**Files:**
- Modify: `lib/features/insights/presentation/providers/insights_focus_providers.dart`
- Test: `test/features/insights/presentation/providers/insights_focus_providers_test.dart` (new)

**Interfaces:**
- Produces: `focusMetricSeriesProvider(metric)` for all 14 metrics; `focusThresholdDefaultProvider: FutureProvider<double?>`, the population mean (storage units) of the selected metric, null when the series is empty.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/insights/presentation/providers/insights_focus_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> container(List<TrendDataPoint> cns) async {
    final c = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        focusMetricSeriesProvider(FocusMetric.cns).overrideWith((ref) async => cns),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the threshold default is the mean of the selected metric', () async {
    final c = await container([
      TrendDataPoint(date: DateTime.utc(2025), value: 10, diveId: 'a'),
      TrendDataPoint(date: DateTime.utc(2025, 2), value: 30, diveId: 'b'),
    ]);
    c.read(focusSelectionProvider.notifier).state =
        const FocusSelection(metric: FocusMetric.cns, mode: FocusMode.above);
    expect(await c.read(focusThresholdDefaultProvider.future), 20);
  });

  test('an empty series gives no default', () async {
    final c = await container(const []);
    c.read(focusSelectionProvider.notifier).state =
        const FocusSelection(metric: FocusMetric.cns, mode: FocusMode.above);
    expect(await c.read(focusThresholdDefaultProvider.future), isNull);
  });

  test('every metric has a series provider that resolves', () async {
    final c = ProviderContainer(overrides: await getBaseOverrides());
    addTearDown(c.dispose);
    for (final m in FocusMetric.values) {
      expect(await c.read(focusMetricSeriesProvider(m).future), isEmpty, reason: '$m');
    }
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/providers/insights_focus_providers_test.dart`
Expected: FAIL, `focusThresholdDefaultProvider` undefined and the Task 1 placeholder throws.

- [ ] **Step 3: Implement**

Replace the switch in `focusMetricSeriesProvider` with:

```dart
      switch (metric) {
        case FocusMetric.maxDepth:
          return ref.watch(depthProgressionTrendProvider.future);
        case FocusMetric.bottomTime:
          return ref.watch(bottomTimeTrendProvider.future);
        case FocusMetric.weight:
          return ref.watch(weightTrendProvider.future);
        case FocusMetric.waterTemp:
          return ref.watch(waterTempTrendProvider.future);
        case FocusMetric.rmv:
        case FocusMetric.sac:
        case FocusMetric.gasUsed:
        case FocusMetric.avgDepth:
        case FocusMetric.surfaceInterval:
        case FocusMetric.airTemp:
        case FocusMetric.visibility:
        case FocusMetric.altitude:
        case FocusMetric.cns:
        case FocusMetric.otu:
          final repository = ref.watch(insightsRepositoryProvider);
          ref.invalidateSelfWhen(repository.watchInsightsChanges());
          final diverId = ref.watch(currentDiverIdProvider);
          final filter = ref.watch(insightsFilterProvider);
          return switch (metric) {
            FocusMetric.rmv => repository.getSacVolumePerDive(diverId: diverId, filter: filter),
            FocusMetric.sac => repository.getSacPressurePerDive(diverId: diverId, filter: filter),
            FocusMetric.gasUsed => repository.getGasUsedPerDive(diverId: diverId, filter: filter),
            FocusMetric.avgDepth => repository.getAvgDepthPerDive(diverId: diverId, filter: filter),
            FocusMetric.surfaceInterval => repository.getSurfaceIntervalPerDive(diverId: diverId, filter: filter),
            FocusMetric.airTemp => repository.getAirTempPerDive(diverId: diverId, filter: filter),
            FocusMetric.visibility => repository.getVisibilityPerDive(diverId: diverId, filter: filter),
            FocusMetric.altitude => repository.getAltitudePerDive(diverId: diverId, filter: filter),
            FocusMetric.cns => repository.getCnsPerDive(diverId: diverId, filter: filter),
            FocusMetric.otu => repository.getOtuPerDive(diverId: diverId, filter: filter),
            _ => throw StateError('handled above'),
          };
      }
```

Add after `focusGroupProvider`:

```dart
/// The population mean of the selected metric, in storage units: the value
/// a threshold field starts from so the page never opens on an empty box.
/// Null when no dive has the metric.
final focusThresholdDefaultProvider = FutureProvider<double?>((ref) async {
  final metric = ref.watch(focusSelectionProvider.select((s) => s.metric));
  final series = await ref.watch(focusMetricSeriesProvider(metric).future);
  if (series.isEmpty) return null;
  return series.fold<double>(0, (sum, p) => sum + p.value) / series.length;
});
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/insights/presentation/providers/insights_focus_providers_test.dart test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights/presentation/providers test/features/insights/presentation/providers
git commit -m "feat(insights): series providers for every Dive focus metric and a threshold default"
```

---

### Task 4: Strength, ordered standouts and the quiet-row rule

**Files:**
- Modify: `lib/features/insights/domain/focus/focus_factor.dart`
- Modify: `lib/features/insights/domain/focus/focus_factor_analyzer.dart`
- Create: `lib/features/insights/presentation/formatters/focus_quiet_rows.dart`
  (the spec placed this under `domain/focus/`; it lives with the formatters because the rule reads the difference as the table renders it, in display units)
- Test: `test/features/insights/domain/focus/focus_factor_analyzer_test.dart` (add)
- Test: `test/features/insights/presentation/formatters/focus_quiet_rows_test.dart` (new)

**Interfaces:**
- Produces: `FocusFactor.strength: double` (numeric: `|difference| / baseline sd`, 0 when sd is 0 or data missing; categorical: the largest `CategoryShare.strength`, which is `groupShare - baselineShare`); `FocusFactorReport.standouts` ordered by strength, strongest first; `bool focusFactorIsQuiet(FocusFactor factor, {required String? formattedDifference})`.

- [ ] **Step 1: Write the failing analyzer tests**

Append to `focus_factor_analyzer_test.dart`:

```dart
  test('standouts are ordered by strength, strongest first', () {
    // Group: three shallow boat dives. Entry gap is 100% vs 40% (0.6);
    // depth gap is 7 m against sd 5.74 (about 1.22). Depth comes first.
    final group = baseline.take(3).toList();
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    expect(report.standouts.map((f) => f.id), [
      FocusFactorId.maxDepth,
      FocusFactorId.entryMethod,
    ]);
    expect(report.standouts.first.strength, closeTo(1.22, 0.01));
    expect(report.standouts.last.strength, closeTo(0.6, 0.001));
  });

  test('a factor with no baseline spread has zero strength', () {
    final flat = [for (var i = 0; i < 5; i++) row('f$i', maxDepth: 20)];
    final report = FocusFactorAnalyzer.analyze(
      group: flat.take(3).toList(),
      baseline: flat,
      metric: FocusMetric.rmv,
    );
    expect(factor<NumericFactor>(report, FocusFactorId.maxDepth).strength, 0);
  });
```

- [ ] **Step 2: Write the failing quiet-row test**

```dart
// test/features/insights/presentation/formatters/focus_quiet_rows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_quiet_rows.dart';

void main() {
  NumericFactor numeric({double? g, double? b, bool standsOut = false}) =>
      NumericFactor(
        id: FocusFactorId.maxDepth,
        groupCovered: g == null ? 0 : 3,
        groupSize: 3,
        groupMean: g,
        baselineMean: b,
        standsOut: standsOut,
        strength: standsOut ? 1 : 0,
      );
  CategoricalFactor categorical(List<CategoryShare> top) => CategoricalFactor(
    id: FocusFactorId.entryMethod,
    groupCovered: top.isEmpty ? 0 : 3,
    groupSize: 3,
    top: top,
  );
  CategoryShare share(double g, double b, {bool standsOut = false}) =>
      CategoryShare(
        key: 'boat',
        groupShare: g,
        baselineShare: b,
        groupCount: 3,
        standsOut: standsOut,
        strength: g - b,
      );

  test('a standout is never quiet', () {
    expect(
      focusFactorIsQuiet(numeric(g: 20, b: 20, standsOut: true), formattedDifference: '+0.0m'),
      isFalse,
    );
  });

  test('no data is quiet', () {
    expect(focusFactorIsQuiet(numeric(), formattedDifference: null), isTrue);
    expect(focusFactorIsQuiet(categorical(const []), formattedDifference: null), isTrue);
  });

  test('a difference that rounds to zero in display units is quiet', () {
    expect(focusFactorIsQuiet(numeric(g: 20.02, b: 20), formattedDifference: '+0.0m'), isTrue);
    expect(focusFactorIsQuiet(numeric(g: 20.02, b: 20), formattedDifference: '+0 ft'), isTrue);
    expect(focusFactorIsQuiet(numeric(g: 21, b: 20), formattedDifference: '+1.0m'), isFalse);
  });

  test('a categorical top value under a five point gap is quiet', () {
    expect(focusFactorIsQuiet(categorical([share(0.42, 0.40)]), formattedDifference: null), isTrue);
    expect(focusFactorIsQuiet(categorical([share(0.50, 0.40)]), formattedDifference: null), isFalse);
    expect(focusFactorIsQuiet(categorical([share(0.30, 0.40)]), formattedDifference: null), isFalse);
  });
}
```

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/features/insights/domain/focus/focus_factor_analyzer_test.dart test/features/insights/presentation/formatters/focus_quiet_rows_test.dart`
Expected: FAIL on `strength`.

- [ ] **Step 4: Implement the model**

`focus_factor.dart`:

```dart
sealed class FocusFactor {
  // existing fields...
  bool get standsOut;

  /// How far the group sits from its baseline, on the scale the standout
  /// rule uses: baseline standard deviations for a number, share gap for a
  /// category. Orders the standouts card; 0 when nothing can be compared.
  double get strength;
}

final class NumericFactor extends FocusFactor {
  const NumericFactor({
    ...existing...,
    required this.standsOut,
    required this.strength,
  });
  @override
  final double strength;
}

class CategoryShare {
  const CategoryShare({..., required this.standsOut, required this.strength, this.label});
  /// Group share minus baseline share.
  final double strength;
}

final class CategoricalFactor extends FocusFactor {
  @override
  double get strength =>
      top.fold(0, (m, s) => s.strength > m ? s.strength : m);
}

class FocusFactorReport {
  /// Standouts strongest first; ties keep display order.
  List<FocusFactor> get standouts {
    final out = factors.where((f) => f.standsOut).toList();
    final order = {for (var i = 0; i < factors.length; i++) factors[i].id: i};
    out.sort((a, b) {
      final c = b.strength.compareTo(a.strength);
      return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
    });
    return List.unmodifiable(out);
  }
}
```

`focus_factor_analyzer.dart` `_numeric`: compute `final strength = gMean == null || bMean == null || sd <= 0 ? 0.0 : (gMean - bMean).abs() / sd;` and pass `strength: strength`. In `_categorical` pass `strength: groupShare - baselineShare` to each `CategoryShare`.

Update every existing `NumericFactor(` and `CategoryShare(` construction in tests (`focus_factors_table_test.dart`, page tests) to pass `strength:`; `grep -rn "NumericFactor(\|CategoryShare(" test lib`.

- [ ] **Step 5: Implement the quiet rule**

```dart
// lib/features/insights/presentation/formatters/focus_quiet_rows.dart
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';

/// A categorical top value whose share gap is under this says nothing.
const double focusQuietSharePoints = 0.05;

/// Whether a comparison row says nothing worth a diver's glance: not a
/// standout, and either unrecorded, a numeric difference that rounds to
/// zero in the diver's display units ([formattedDifference], as the table
/// renders it), or a category lead under [focusQuietSharePoints].
bool focusFactorIsQuiet(
  FocusFactor factor, {
  required String? formattedDifference,
}) {
  if (factor.standsOut) return false;
  return switch (factor) {
    NumericFactor(:final groupMean, :final baselineMean) =>
      groupMean == null ||
          baselineMean == null ||
          formattedDifference == null ||
          !formattedDifference.contains(RegExp('[1-9]')),
    CategoricalFactor(:final top) =>
      top.isEmpty ||
          (top.first.groupShare - top.first.baselineShare).abs() <
              focusQuietSharePoints,
  };
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/insights/domain/focus test/features/insights/presentation/formatters test/features/insights/presentation/widgets/focus test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights test/features/insights
git commit -m "feat(insights): factor strength, ordered standouts and the quiet-row rule"
```

---

### Task 5: Point radius and a reference line on the trend chart

**Files:**
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart`
- Create: `lib/features/insights/presentation/widgets/trend_reference_line.dart`
- Test: `test/features/insights/presentation/widgets/dive_trend_chart_reference_line_test.dart` (new)

**Interfaces:**
- Produces: `TrendSeries({..., double? pointRadius})`; `class TrendReferenceLine { final double value; final String label; }`; `DiveTrendChart({..., TrendReferenceLine? referenceLine})`; `ExtraLinesData trendReferenceLines(BuildContext context, TrendReferenceLine? line)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/insights/presentation/widgets/dive_trend_chart_reference_line_test.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_reference_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i,
    diveId: 'd$i',
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 600, height: 300, child: child)),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('a reference line is drawn dashed at its value with its label', (
    tester,
  ) async {
    await tester.pumpWidget(host(DiveTrendChart(
      points: series(5),
      referenceLine: const TrendReferenceLine(value: 12.5, label: '12.5 L/min'),
    )));
    final line = readData(tester).extraLinesData.horizontalLines.single;
    expect(line.y, 12.5);
    expect(line.dashArray, isNotNull);
    expect(line.label.show, isTrue);
    expect(line.label.labelResolver(line), '12.5 L/min');
  });

  testWidgets('no reference line draws no extra lines', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(5))));
    expect(readData(tester).extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets('a secondary series can draw bigger dots', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(
      points: series(5),
      secondarySeries: [
        TrendSeries(label: 'g', points: series(2), color: Colors.red, pointRadius: 4.4),
      ],
    )));
    final bars = readData(tester).lineBarsData;
    final primary = bars.first.dotData.getDotPainter(const FlSpot(0, 0), 0, bars.first, 0) as FlDotCirclePainter;
    final group = bars.last.dotData.getDotPainter(const FlSpot(0, 0), 0, bars.last, 0) as FlDotCirclePainter;
    expect(primary.radius, 2.2);
    expect(group.radius, 4.4);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_reference_line_test.dart`
Expected: FAIL, `trend_reference_line.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/insights/presentation/widgets/trend_reference_line.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A horizontal marker on a [DiveTrendChart]: a threshold the diver set,
/// drawn dashed with its formatted value beside it.
@immutable
class TrendReferenceLine {
  const TrendReferenceLine({required this.value, required this.label});

  /// In the chart's y units (storage units).
  final double value;
  final String label;
}

/// fl_chart's extra lines for [line]; none when it is null. Kept out of
/// `dive_trend_chart.dart`, which sits at the file-size limit.
ExtraLinesData trendReferenceLines(BuildContext context, TrendReferenceLine? line) {
  if (line == null) return const ExtraLinesData();
  final scheme = Theme.of(context).colorScheme;
  return ExtraLinesData(
    horizontalLines: [
      HorizontalLine(
        y: line.value,
        color: scheme.tertiary,
        strokeWidth: 1.5,
        dashArray: const [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.tertiary),
          labelResolver: (_) => line.label,
        ),
      ),
    ],
  );
}
```

In `dive_trend_chart.dart`:
- `TrendSeries` gains `final double? pointRadius;` and the constructor parameter `this.pointRadius`.
- `DiveTrendChart` gains `this.referenceLine` and `final TrendReferenceLine? referenceLine;`.
- In `LineChartData(...)` add `extraLinesData: trendReferenceLines(context, widget.referenceLine),`.
- `_dataBar` gains `{double? radius}` and uses `radius: radius ?? (isRaw ? 2.2 : 3)`; the secondary loop passes `radius: widget.secondarySeries[i].pointRadius`.

Keep the import added for `trend_reference_line.dart`. Confirm `wc -l dive_trend_chart.dart` stays under 800.

- [ ] **Step 4: Run the chart tests**

Run: `flutter test test/features/insights/presentation/widgets/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights/presentation/widgets test/features/insights/presentation/widgets
git commit -m "feat(insights): reference line and per-series point radius on the trend chart"
```

---

### Task 6: The sentence builder

**Files:**
- Create: `lib/features/insights/presentation/widgets/focus/focus_sentence.dart`
- Create: `lib/features/insights/presentation/widgets/focus/focus_count_dialog.dart`
- Delete: `lib/features/insights/presentation/widgets/focus/focus_selector.dart`, `test/features/insights/presentation/widgets/focus/focus_selector_test.dart`
- Modify: `lib/features/insights/presentation/pages/insights_focus_page.dart` (swap the widget)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/focus/focus_sentence_test.dart` (new)
- Test: `test/l10n/dive_focus_sentence_markers_test.dart` (new)

**Interfaces:**
- Consumes: `focusThresholdDefaultProvider` (Task 3), `focusMetricGroupLabel` (Task 1).
- Produces: `class FocusSentence extends ConsumerStatefulWidget`; keys `focus-metric`, `focus-mode`, `focus-count`, `focus-threshold-field`, `focus-count-custom-field`; `const List<int> focusCountChoices = [5, 10, 20, 50]`; `Future<int?> showFocusCountDialog(BuildContext, {required int initial})`; marker constants `focusSentenceMarkers = ['<count>', '<mode>', '<metric>', '<value>']` and `List<String> splitFocusSentence(String template)` returning fragments and markers in order.

- [ ] **Step 1: Add the English strings**

After `"insights_focus_threshold_negativeError"`:

```json
  "insights_focus_sentence_ranked": "Show the {count} dives with the {mode} {metric}",
  "@insights_focus_sentence_ranked": {
    "description": "Dive focus sentence builder. Each placeholder is replaced by a control; keep all three, in any order.",
    "placeholders": { "count": { "type": "String" }, "mode": { "type": "String" }, "metric": { "type": "String" } }
  },
  "insights_focus_sentence_threshold": "Show the dives with {metric} {mode} {value}",
  "@insights_focus_sentence_threshold": {
    "description": "Dive focus sentence builder in threshold form. Each placeholder is replaced by a control; keep all three, in any order.",
    "placeholders": { "metric": { "type": "String" }, "mode": { "type": "String" }, "value": { "type": "String" } }
  },
  "insights_focus_count_custom": "Custom...",
  "insights_focus_count_dialogTitle": "How many dives?",
```

Change `"insights_focus_enterValue"` to `"Enter a value to see the dives above or below it"` (unchanged text; keep). Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing marker test**

```dart
// test/l10n/dive_focus_sentence_markers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_sentence.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every locale's sentence template must keep every control marker exactly
/// once, or the widget drops a control for that language.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.languageCode} sentence templates keep every marker', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final ranked = l10n.insights_focus_sentence_ranked('<count>', '<mode>', '<metric>');
      final threshold = l10n.insights_focus_sentence_threshold('<metric>', '<mode>', '<value>');
      for (final m in ['<count>', '<mode>', '<metric>']) {
        expect(m.allMatches(ranked).length, 1, reason: 'ranked $m');
      }
      for (final m in ['<metric>', '<mode>', '<value>']) {
        expect(m.allMatches(threshold).length, 1, reason: 'threshold $m');
      }
      expect(splitFocusSentence(ranked).where(focusSentenceMarkers.contains), hasLength(3));
    });
  }
}
```

Check the generated argument order with `grep -n "insights_focus_sentence_ranked(" lib/l10n/arb/app_localizations.dart`, since gen-l10n takes placeholders in `@placeholders` map order.

- [ ] **Step 3: Write the failing widget test**

```dart
// test/features/insights/presentation/widgets/focus/focus_sentence_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_sentence.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double? defaultThreshold = 16,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          focusThresholdDefaultProvider.overrideWith((ref) async => defaultThreshold),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FocusSentence()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(FocusSentence)));
  }

  testWidgets('the ranked sentence reads as words around three controls', (tester) async {
    await pump(tester);
    expect(find.text('Show the'), findsOneWidget);
    expect(find.text('dives with the'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-count')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-metric')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-threshold-field')), findsNothing);
  });

  testWidgets('RMV offers best and worst; depth offers lowest and highest', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-mode')));
    await tester.pumpAndSettle();
    expect(find.text('best'), findsWidgets);
    expect(find.text('worst'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(metric: FocusMetric.maxDepth);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('focus-mode')));
    await tester.pumpAndSettle();
    expect(find.text('highest'), findsOneWidget);
  });

  testWidgets('the metric menu is grouped', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-metric')));
    await tester.pumpAndSettle();
    expect(find.text('Depth and time'), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.text('CNS at end'), findsOneWidget);
  });

  testWidgets('picking 20 sets N; Custom opens a dialog that sets N', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    expect(c.read(focusSelectionProvider).count, 20);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('focus-count-custom-field')), '7');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(c.read(focusSelectionProvider).count, 7);
  });

  testWidgets('an out-of-range custom count shows the error and keeps N', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('focus-count-custom-field')), '0');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1 to 999'), findsOneWidget);
    expect(c.read(focusSelectionProvider).count, 10);
  });

  testWidgets('above rewrites the sentence and pre-fills the mean with its unit', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('above').last);
    await tester.pumpAndSettle();
    expect(find.text('dives with'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('focus-threshold-field')));
    expect(field.controller!.text, '16');
    expect(field.decoration!.suffixText, 'L/min');
    expect(c.read(focusSelectionProvider).threshold, 16);
    expect(c.read(focusSelectionProvider).mode, FocusMode.above);
  });

  testWidgets('an imperial threshold is stored in litres per minute', (tester) async {
    final c = await pump(tester, settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet));
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(mode: FocusMode.above, threshold: 20);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('focus-threshold-field')), '0.75');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(21.24, 0.01));
  });

  testWidgets('changing the metric in a threshold mode clears and re-fills the value', (tester) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(mode: FocusMode.above, threshold: 20);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('focus-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max depth').last);
    await tester.pumpAndSettle();
    final s = c.read(focusSelectionProvider);
    expect(s.metric, FocusMetric.maxDepth);
    // The default provider is overridden to 16 for every metric in this test.
    expect(s.threshold, 16);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('focus-threshold-field'))).decoration!.suffixText, 'm');
  });

  testWidgets('no dives with the metric leaves the threshold empty without error', (tester) async {
    final c = await pump(tester, defaultThreshold: null);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(mode: FocusMode.above);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('focus-threshold-field'))).controller!.text, '');
    expect(c.read(focusSelectionProvider).threshold, isNull);
  });

  testWidgets('a negative RMV is rejected; a sub-zero air temp is accepted', (tester) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(mode: FocusMode.above, threshold: 20);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('focus-threshold-field')), '-1');
    await tester.pump();
    expect(find.text('Enter zero or more'), findsOneWidget);
    expect(c.read(focusSelectionProvider).threshold, 20);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(metric: FocusMetric.airTemp, mode: FocusMode.below, threshold: 5);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('focus-threshold-field')), '-2');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, -2);
  });

  testWidgets('the sentence wraps on a phone', (tester) async {
    await pump(tester, width: 360);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 4: Run both to see them fail**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_sentence_test.dart test/l10n/dive_focus_sentence_markers_test.dart`
Expected: FAIL, `focus_sentence.dart` not found.

- [ ] **Step 5: Implement the count dialog**

```dart
// lib/features/insights/presentation/widgets/focus/focus_count_dialog.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a group size outside the sentence's preset choices. Returns the
/// number, or null when dismissed.
Future<int?> showFocusCountDialog(BuildContext context, {required int initial}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _FocusCountDialog(initial: initial),
    );

class _FocusCountDialog extends StatefulWidget {
  const _FocusCountDialog({required this.initial});
  final int initial;
  @override
  State<_FocusCountDialog> createState() => _FocusCountDialogState();
}

class _FocusCountDialogState extends State<_FocusCountDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final read = readNumber(_controller.text, integer: true, allowNegative: false);
    final n = read is NumberValue ? read.value.toInt() : null;
    if (n == null || n < FocusSelection.minCount || n > FocusSelection.maxCount) {
      setState(() => _error = context.l10n.insights_focus_count_error);
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.insights_focus_count_dialogTitle),
      content: TextField(
        key: const ValueKey('focus-count-custom-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.insights_focus_count_label,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Implement the sentence**

```dart
// lib/features/insights/presentation/widgets/focus/focus_sentence.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_count_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Slots the localised sentence templates carry; each becomes a control.
const List<String> focusSentenceMarkers = ['<count>', '<mode>', '<metric>', '<value>'];

/// The preset group sizes in the count menu; anything else is Custom.
const List<int> focusCountChoices = [5, 10, 20, 50];

final RegExp _marker = RegExp('<(count|mode|metric|value)>');

/// Splits a rendered template into trimmed text fragments and markers, in
/// order, dropping empty fragments. "Show the <count> dives" gives
/// ["Show the", "<count>", "dives"].
List<String> splitFocusSentence(String template) {
  final out = <String>[];
  var last = 0;
  for (final m in _marker.allMatches(template)) {
    final text = template.substring(last, m.start).trim();
    if (text.isNotEmpty) out.add(text);
    out.add(m.group(0)!);
    last = m.end;
  }
  final tail = template.substring(last).trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

/// Dive focus's group picker, read as a sentence: "Show the [10] dives with
/// the [best] [RMV]", or "Show the dives with [RMV] [above] [15 L/min]".
class FocusSentence extends ConsumerStatefulWidget {
  const FocusSentence({super.key});

  @override
  ConsumerState<FocusSentence> createState() => _FocusSentenceState();
}

class _FocusSentenceState extends ConsumerState<FocusSentence> {
  late final TextEditingController _threshold;
  String? _thresholdError;

  @override
  void initState() {
    super.initState();
    final selection = ref.read(focusSelectionProvider);
    _threshold = TextEditingController(
      text: _thresholdText(selection.threshold, _units(selection.metric, ref.read(settingsProvider))),
    );
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  static FocusMetricUnits _units(FocusMetric metric, AppSettings settings) =>
      FocusMetricUnits(metric, UnitFormatter(settings));

  static String _thresholdText(double? threshold, FocusMetricUnits units) =>
      threshold == null ? '' : formatRoundedForInput(units.toDisplay(threshold), 2);

  void _set(FocusSelection next) =>
      ref.read(focusSelectionProvider.notifier).state = next;

  /// Re-renders the stored threshold when this metric's unit changes, so
  /// the digits match the new suffix (#3017). Other settings changes leave a
  /// half-typed entry alone.
  void _onSettingsChanged(AppSettings? previous, AppSettings next) {
    if (previous == null) return;
    final selection = ref.read(focusSelectionProvider);
    final l10n = context.l10n;
    final before = _units(selection.metric, previous);
    final after = _units(selection.metric, next);
    if (before.symbol(l10n) == after.symbol(l10n)) return;
    _threshold.text = _thresholdText(selection.threshold, after);
    setState(() => _thresholdError = null);
  }

  /// A threshold mode with no value takes the metric's mean once it is
  /// known, so the page never sits on an empty box over an empty page.
  void _onDefaultChanged(AsyncValue<double?>? _, AsyncValue<double?> next) {
    final mean = next.value;
    final selection = ref.read(focusSelectionProvider);
    if (mean == null || selection.mode.isRanked || selection.threshold != null) return;
    _threshold.text = _thresholdText(mean, _units(selection.metric, ref.read(settingsProvider)));
    setState(() => _thresholdError = null);
    _set(selection.copyWith(threshold: mean));
  }

  void _onMetric(FocusMetric? metric, FocusSelection selection) {
    if (metric == null || metric == selection.metric) return;
    _threshold.clear();
    setState(() => _thresholdError = null);
    // A threshold means nothing in another metric's units; the default
    // listener refills it from the new metric's mean.
    _set(selection.copyWith(metric: metric, clearThreshold: true));
  }

  void _onMode(FocusMode? mode, FocusSelection selection) {
    if (mode == null || mode == selection.mode) return;
    _set(selection.copyWith(mode: mode));
    if (!mode.isRanked && selection.threshold == null) {
      // Apply an already-loaded default at once rather than waiting for the
      // listener, which only fires on a change.
      _onDefaultChanged(null, ref.read(focusThresholdDefaultProvider));
    }
  }

  Future<void> _onCount(int? choice, FocusSelection selection) async {
    if (choice == null) return;
    if (choice > 0) {
      _set(selection.copyWith(count: choice));
      return;
    }
    final n = await showFocusCountDialog(context, initial: selection.count);
    if (n != null) _set(selection.copyWith(count: n));
  }

  void _onThreshold(String text, FocusSelection selection, FocusMetricUnits units) {
    final read = readNumber(text);
    final value = read is NumberValue ? read.value : null;
    String? error;
    if (read is NumberInvalid) {
      error = context.l10n.insights_focus_threshold_error;
    } else if (value != null && value < 0 && !units.allowsNegative) {
      error = context.l10n.insights_focus_threshold_negativeError;
    }
    setState(() => _thresholdError = error);
    if (read is NumberBlank) {
      _set(selection.copyWith(clearThreshold: true));
    } else if (error == null && value != null) {
      _set(selection.copyWith(threshold: units.toStorage(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(settingsProvider, _onSettingsChanged);
    ref.listen(focusThresholdDefaultProvider, _onDefaultChanged);
    final selection = ref.watch(focusSelectionProvider);
    final units = _units(selection.metric, ref.watch(settingsProvider));
    final style = Theme.of(context).textTheme.titleMedium;

    final template = selection.mode.isRanked
        ? l10n.insights_focus_sentence_ranked('<count>', '<mode>', '<metric>')
        : l10n.insights_focus_sentence_threshold('<metric>', '<mode>', '<value>');

    Widget slot(String marker) => switch (marker) {
      '<count>' => _CountWord(selection: selection, onChanged: (c) => _onCount(c, selection)),
      '<mode>' => _ModeWord(selection: selection, onChanged: (m) => _onMode(m, selection)),
      '<metric>' => _MetricWord(selection: selection, onChanged: (m) => _onMetric(m, selection)),
      '<value>' => SizedBox(
        width: 160,
        child: TextField(
          key: const ValueKey('focus-threshold-field'),
          controller: _threshold,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            suffixText: units.symbol(l10n),
            errorText: _thresholdError,
            errorMaxLines: 2,
            isDense: true,
          ),
          onChanged: (text) => _onThreshold(text, selection, units),
        ),
      ),
      _ => Text(marker, style: style),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final part in splitFocusSentence(template))
              if (focusSentenceMarkers.contains(part)) slot(part) else Text(part, style: style),
          ],
        ),
      ),
    );
  }
}

/// A word of the sentence that opens a menu. The underline is dropped so
/// the control reads as part of the sentence, with the arrow as the cue.
class _Word<T> extends StatelessWidget {
  const _Word({required this.menuKey, required this.value, required this.items, required this.onChanged});
  final Key menuKey;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButton<T>(
      key: menuKey,
      value: value,
      items: items,
      onChanged: onChanged,
      underline: const SizedBox.shrink(),
      isDense: true,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
    );
  }
}

class _CountWord extends StatelessWidget {
  const _CountWord({required this.selection, required this.onChanged});
  final FocusSelection selection;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = !focusCountChoices.contains(selection.count);
    return _Word<int>(
      menuKey: const ValueKey('focus-count'),
      value: selection.count,
      items: [
        for (final n in focusCountChoices) DropdownMenuItem(value: n, child: Text('$n')),
        if (custom) DropdownMenuItem(value: selection.count, child: Text('${selection.count}')),
        // 0 stands for Custom: never a valid count (minCount is 1).
        DropdownMenuItem(value: 0, child: Text(l10n.insights_focus_count_custom)),
      ],
      onChanged: onChanged,
    );
  }
}

class _ModeWord extends StatelessWidget {
  const _ModeWord({required this.selection, required this.onChanged});
  final FocusSelection selection;
  final ValueChanged<FocusMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Word<FocusMode>(
      menuKey: const ValueKey('focus-mode'),
      value: selection.mode,
      items: [
        for (final mode in FocusMode.values)
          DropdownMenuItem(value: mode, child: Text(focusModeLabel(mode, selection.metric, l10n))),
      ],
      onChanged: onChanged,
    );
  }
}

class _MetricWord extends StatelessWidget {
  const _MetricWord({required this.selection, required this.onChanged});
  final FocusSelection selection;
  final ValueChanged<FocusMetric?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final heading = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return _Word<FocusMetric>(
      menuKey: const ValueKey('focus-metric'),
      value: selection.metric,
      items: [
        for (final group in FocusMetricGroup.values) ...[
          DropdownMenuItem(
            value: null,
            enabled: false,
            child: Text(focusMetricGroupLabel(group, l10n), style: heading),
          ),
          for (final m in FocusMetric.values)
            if (m.group == group)
              DropdownMenuItem(value: m, child: Text(focusMetricLabel(m, l10n))),
        ],
      ],
      onChanged: onChanged,
    );
  }
}
```

Mode labels are lower case in the sentence: change the English `insights_focus_mode_*` values to "best", "worst", "lowest", "highest", "above", "below" (the sentence needs them mid-sentence; nothing else uses them). The `DropdownMenuItem(value: null, enabled: false)` heading needs `DropdownButton<FocusMetric?>`; make `_Word<T>` take `T` nullable where needed (`_Word<FocusMetric?>`) and guard null in `_onMetric` (already does).

Swap the page: in `insights_focus_page.dart` replace `FocusSelector()` with `FocusSentence()` and the import. Delete `focus_selector.dart` and its test (`git rm`).

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/insights/presentation/widgets/focus test/l10n/dive_focus_sentence_markers_test.dart test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: PASS except any page test that tapped `focus-count-5` (it changes N through the menu now; update it to tap `focus-count` then `5`). The markers test fails for the ten locales until Task 10; run only the `en` case here (`--name en`).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/insights test && flutter analyze
git add -A lib/features/insights/presentation lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/insights test/l10n/dive_focus_sentence_markers_test.dart
git commit -m "feat(insights): sentence builder replaces the Dive focus selector row"
```

---

### Task 7: The "What stands out" card

**Files:**
- Create: `lib/features/insights/presentation/widgets/focus/focus_standouts_card.dart`
- Modify: `lib/features/insights/presentation/formatters/focus_factor_labels.dart` (direction words)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/focus/focus_standouts_card_test.dart` (new)

**Interfaces:**
- Consumes: `FocusFactorReport.standouts` ordered (Task 4), `focusNumericValue`, `focusNumericDifference`, `focusCategoryLabel`.
- Produces: `class FocusStandoutsCard extends ConsumerWidget { final FocusFactorReport report; final int groupSize; }` with `static const int maxFindings = 5`; `String focusDirectionWord(FocusFactorId id, double difference, AppLocalizations l10n)`.

- [ ] **Step 1: Add the English strings**

After `"insights_focus_factors_coverage"`'s `@meta` block:

```json
  "insights_focus_standouts_title": "What stands out",
  "insights_focus_standouts_none": "Nothing stands out about these dives.",
  "insights_focus_standouts_tooFew": "Pick at least 3 dives to see what they share",
  "insights_focus_standouts_more": "{count, plural, =1{and 1 more in the full comparison} other{and {count} more in the full comparison}}",
  "@insights_focus_standouts_more": { "placeholders": { "count": { "type": "int" } } },
  "insights_focus_standouts_categoryAll": "All {count} were {value} ({baseline} of all your dives)",
  "@insights_focus_standouts_categoryAll": { "placeholders": { "count": { "type": "int" }, "value": { "type": "String" }, "baseline": { "type": "String" } } },
  "insights_focus_standouts_categorySome": "{count} of {total} were {value}, against {baseline} of all your dives",
  "@insights_focus_standouts_categorySome": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" }, "value": { "type": "String" }, "baseline": { "type": "String" } } },
  "insights_focus_standouts_numeric": "{factor} {difference} {direction} ({group} vs {baseline})",
  "@insights_focus_standouts_numeric": { "placeholders": { "factor": { "type": "String" }, "difference": { "type": "String" }, "direction": { "type": "String" }, "group": { "type": "String" }, "baseline": { "type": "String" } } },
  "insights_focus_direction_deeper": "deeper",
  "insights_focus_direction_shallower": "shallower",
  "insights_focus_direction_longer": "longer",
  "insights_focus_direction_shorter": "shorter",
  "insights_focus_direction_warmer": "warmer",
  "insights_focus_direction_colder": "colder",
  "insights_focus_direction_larger": "larger",
  "insights_focus_direction_smaller": "smaller",
  "insights_focus_direction_moreLead": "more lead",
  "insights_focus_direction_lessLead": "less lead",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/insights/presentation/widgets/focus/focus_standouts_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_standouts_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

NumericFactor numeric(FocusFactorId id, double g, double b, {double strength = 1}) =>
    NumericFactor(id: id, groupCovered: 10, groupSize: 10, groupMean: g, baselineMean: b, standsOut: true, strength: strength);

CategoricalFactor category(FocusFactorId id, String key, double g, double b, int count, {double strength = 1}) =>
    CategoricalFactor(id: id, groupCovered: 10, groupSize: 10, top: [
      CategoryShare(key: key, groupShare: g, baselineShare: b, groupCount: count, standsOut: true, strength: strength),
    ]);

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, FocusFactorReport report, {int groupSize = 10}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: await getBaseOverrides(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FocusStandoutsCard(report: report, groupSize: groupSize)),
      ),
    ));
    await tester.pump();
  }

  testWidgets('findings read as sentences, strongest first', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [
      numeric(FocusFactorId.avgDepth, 11.3, 13.4, strength: 0.4),
      category(FocusFactorId.entryMethod, 'boat', 1.0, 0.64, 10, strength: 0.36),
      category(FocusFactorId.gas, 'nitrox', 0.8, 0.5, 8, strength: 0.3),
    ]));
    expect(find.text('What stands out'), findsOneWidget);
    expect(find.text('Average depth 2.1m shallower (11.3m vs 13.4m)'), findsOneWidget);
    expect(find.text('All 10 were Boat Entry (64% of all your dives)'), findsOneWidget);
    expect(find.text('8 of 10 were Nitrox, against 50% of all your dives'), findsOneWidget);
    final depth = tester.getTopLeft(find.textContaining('Average depth'));
    final boat = tester.getTopLeft(find.textContaining('All 10'));
    expect(depth.dy, lessThan(boat.dy));
  });

  testWidgets('direction words follow the factor', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [
      numeric(FocusFactorId.maxDepth, 30, 20),
      numeric(FocusFactorId.duration, 40, 50),
      numeric(FocusFactorId.waterTemp, 25, 20),
      numeric(FocusFactorId.tankVolume, 15, 12),
      numeric(FocusFactorId.weight, 5, 7),
    ]));
    expect(find.textContaining('deeper'), findsOneWidget);
    expect(find.textContaining('shorter'), findsOneWidget);
    expect(find.textContaining('warmer'), findsOneWidget);
    expect(find.textContaining('larger'), findsOneWidget);
    expect(find.textContaining('less lead'), findsOneWidget);
  });

  testWidgets('more than five findings adds a count line', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [
      for (final id in [FocusFactorId.maxDepth, FocusFactorId.avgDepth, FocusFactorId.duration, FocusFactorId.waterTemp, FocusFactorId.tankVolume, FocusFactorId.weight])
        numeric(id, 2, 1),
      category(FocusFactorId.gas, 'air', 1, 0.5, 10),
    ]));
    expect(find.text('and 2 more in the full comparison'), findsOneWidget);
    expect(find.textContaining('('), findsNWidgets(5));
  });

  testWidgets('no standouts says so', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [
      NumericFactor(id: FocusFactorId.maxDepth, groupCovered: 3, groupSize: 3, groupMean: 1, baselineMean: 1, standsOut: false, strength: 0),
    ]));
    expect(find.text('Nothing stands out about these dives.'), findsOneWidget);
  });

  testWidgets('too few dives asks for more', (tester) async {
    await pump(tester, const FocusFactorReport(factors: [], tooFewDives: true), groupSize: 2);
    expect(find.text('Pick at least 3 dives to see what they share'), findsOneWidget);
  });
}
```

If `focusCategoryLabel` renders "Boat Entry" differently, match the test text to what `entryMethodDistributionLabel('boat', l10n)` returns.

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_standouts_card_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 4: Implement**

Add to `focus_factor_labels.dart`:

```dart
/// The word after a numeric finding's size: "2.1 m shallower".
String focusDirectionWord(FocusFactorId id, double difference, AppLocalizations l10n) {
  final up = difference >= 0;
  return switch (id) {
    FocusFactorId.maxDepth || FocusFactorId.avgDepth =>
      up ? l10n.insights_focus_direction_deeper : l10n.insights_focus_direction_shallower,
    FocusFactorId.duration =>
      up ? l10n.insights_focus_direction_longer : l10n.insights_focus_direction_shorter,
    FocusFactorId.waterTemp =>
      up ? l10n.insights_focus_direction_warmer : l10n.insights_focus_direction_colder,
    FocusFactorId.tankVolume =>
      up ? l10n.insights_focus_direction_larger : l10n.insights_focus_direction_smaller,
    FocusFactorId.weight =>
      up ? l10n.insights_focus_direction_moreLead : l10n.insights_focus_direction_lessLead,
    _ => '',
  };
}

/// An unsigned difference in display units, for a sentence that carries the
/// direction as a word.
String focusNumericMagnitude(FocusFactorId id, double difference, UnitFormatter units, AppLocalizations l10n) {
  final signed = focusNumericDifference(id, difference, units, l10n);
  return signed.replaceFirst(RegExp(r'^(~?)[+-]'), r'$1');
}
```

```dart
// lib/features/insights/presentation/widgets/focus/focus_standouts_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The page's answer: the strongest standouts as plain sentences.
class FocusStandoutsCard extends ConsumerWidget {
  const FocusStandoutsCard({super.key, required this.report, required this.groupSize});

  static const int maxFindings = 5;

  final FocusFactorReport report;
  final int groupSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final typesById = watchDiveTypesById(ref);
    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toLanguageTag());

    final Widget body;
    if (report.tooFewDives) {
      body = Text(l10n.insights_focus_standouts_tooFew);
    } else if (report.standouts.isEmpty) {
      body = Text(l10n.insights_focus_standouts_none);
    } else {
      final standouts = report.standouts;
      final shown = standouts.take(maxFindings).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _sentence(f, l10n, units, percent, typesById),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          if (standouts.length > maxFindings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.insights_focus_standouts_more(standouts.length - maxFindings),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      );
    }
    return StatSectionCard(title: l10n.insights_focus_standouts_title, child: body);
  }

  String _sentence(FocusFactor f, AppLocalizations l10n, UnitFormatter units, NumberFormat percent, Map<String, DiveTypeEntity> typesById) {
    switch (f) {
      case NumericFactor(:final groupMean, :final baselineMean, :final difference):
        return l10n.insights_focus_standouts_numeric(
          focusFactorName(f.id, l10n),
          focusNumericMagnitude(f.id, difference!, units, l10n),
          focusDirectionWord(f.id, difference, l10n),
          focusNumericValue(f.id, groupMean!, units, l10n),
          focusNumericValue(f.id, baselineMean!, units, l10n),
        );
      case CategoricalFactor(:final top):
        final share = top.firstWhere((s) => s.standsOut);
        final value = focusCategoryLabel(f.id, share, l10n, units, typesById: typesById);
        final baseline = percent.format(share.baselineShare);
        return share.groupCount >= f.groupSize
            ? l10n.insights_focus_standouts_categoryAll(share.groupCount, value, baseline)
            : l10n.insights_focus_standouts_categorySome(share.groupCount, f.groupSize, value, baseline);
    }
  }
}
```

Add the `AppLocalizations` and `DiveTypeEntity` imports the file needs. Check the generated placeholder order for `insights_focus_standouts_numeric` and the two category messages before relying on positional arguments.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_standouts_card_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/insights
git commit -m "feat(insights): What stands out card for Dive focus"
```

---

### Task 8: The full comparison table

**Files:**
- Modify: `lib/features/insights/presentation/widgets/focus/focus_factors_table.dart` (rewrite)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/widgets/focus/focus_factors_table_test.dart` (rewrite)

**Interfaces:**
- Consumes: `focusFactorIsQuiet` (Task 4), `FocusFactor.strength`.
- Produces: `class FocusFactorsTable extends ConsumerStatefulWidget { final FocusFactorReport report; final FocusMetric metric; }`; key `focus-factors-show-more`; marker key `focus-standout-marker-<id.name>`.

- [ ] **Step 1: Add the English strings and retire the old ones**

Replace `"insights_focus_factors_title"`, `"insights_focus_factors_subtitle"`, `"insights_focus_factors_tooFew"`, `"insights_focus_factors_standoutsSummary"` (and its `@meta`) with:

```json
  "insights_focus_comparison_title": "Full comparison",
  "insights_focus_comparison_subtitle": "All dives means every dive in the current filter that has {metric}",
  "@insights_focus_comparison_subtitle": { "placeholders": { "metric": { "type": "String" } } },
  "insights_focus_column_these": "These dives",
  "insights_focus_column_all": "All dives",
  "insights_focus_column_difference": "Difference",
  "insights_focus_comparison_showMore": "{count, plural, =1{Show 1 more factor} other{Show {count} more factors}}",
  "@insights_focus_comparison_showMore": { "placeholders": { "count": { "type": "int" } } },
```

Keep `insights_focus_factors_standsOut` (the marker's semantics label), `insights_focus_factors_versus` is no longer used by the table but stays until Task 10's orphan sweep. Remove the four retired keys from every locale file too (Task 10 does the sweep; here only `app_en.arb`). Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Rewrite `focus_factors_table_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

NumericFactor numeric(FocusFactorId id, double? g, double? b, {bool standsOut = false}) =>
    NumericFactor(id: id, groupCovered: g == null ? 0 : 10, groupSize: 10, groupMean: g, baselineMean: b, standsOut: standsOut, strength: standsOut ? 1 : 0);

CategoricalFactor category(FocusFactorId id, List<(String, double, double)> top, {bool standsOut = false}) =>
    CategoricalFactor(id: id, groupCovered: top.isEmpty ? 0 : 10, groupSize: 10, top: [
      for (final (k, g, b) in top)
        CategoryShare(key: k, groupShare: g, baselineShare: b, groupCount: (g * 10).round(), standsOut: standsOut, strength: g - b),
    ]);

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, FocusFactorReport report, {AppSettings settings = const AppSettings(), double width = 800}) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(settingsNotifier: MockSettingsNotifier(settings));
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: FocusFactorsTable(report: report, metric: FocusMetric.rmv))),
      ),
    ));
    await tester.pump();
  }

  final report = FocusFactorReport(tooFewDives: false, factors: [
    numeric(FocusFactorId.maxDepth, 24.2, 21.6),
    numeric(FocusFactorId.avgDepth, 11.3, 13.4, standsOut: true),
    numeric(FocusFactorId.duration, 50, 50),
    numeric(FocusFactorId.waterTemp, null, null),
    category(FocusFactorId.entryMethod, [('boat', 1.0, 0.64)], standsOut: true),
    category(FocusFactorId.current, [('light', 0.42, 0.40)]),
  ]);

  testWidgets('headers name the metric and the columns', (tester) async {
    await pump(tester, report);
    expect(find.text('Full comparison'), findsOneWidget);
    expect(find.text('All dives means every dive in the current filter that has RMV'), findsOneWidget);
    expect(find.text('These dives'), findsOneWidget);
    expect(find.text('All dives'), findsOneWidget);
    expect(find.text('Difference'), findsOneWidget);
  });

  testWidgets('standouts sort first in their group with a marker', (tester) async {
    await pump(tester, report);
    final avg = tester.getTopLeft(find.text('Average depth'));
    final max = tester.getTopLeft(find.text('Max depth'));
    expect(avg.dy, lessThan(max.dy));
    expect(find.byKey(const ValueKey('focus-standout-marker-avgDepth')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-standout-marker-maxDepth')), findsNothing);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('quiet rows fold behind Show more and expand on tap', (tester) async {
    await pump(tester, report);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('Water temp'), findsNothing);
    expect(find.text('Current'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('focus-factors-show-more')));
    await tester.pump();
    expect(find.text('Show 3 more factors'), findsNothing);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Not recorded'), findsOneWidget);
  });

  testWidgets('a new report folds again', (tester) async {
    await pump(tester, report);
    await tester.tap(find.byKey(const ValueKey('focus-factors-show-more')));
    await tester.pump();
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: report.factors.reversed.toList()));
    expect(find.text('Duration'), findsNothing);
  });

  testWidgets('all quiet shows no headings, only the button', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [
      numeric(FocusFactorId.duration, 50, 50),
      category(FocusFactorId.current, [('light', 0.42, 0.40)]),
    ]));
    expect(find.text('Dive shape'), findsNothing);
    expect(find.text('Conditions'), findsNothing);
    expect(find.text('Show 2 more factors'), findsOneWidget);
  });

  testWidgets('nothing quiet shows no button', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [numeric(FocusFactorId.maxDepth, 24.2, 21.6)]));
    expect(find.byKey(const ValueKey('focus-factors-show-more')), findsNothing);
  });

  testWidgets('imperial folds a difference that rounds to zero in feet', (tester) async {
    await pump(tester, FocusFactorReport(tooFewDives: false, factors: [numeric(FocusFactorId.maxDepth, 20.02, 20.0)]),
        settings: const AppSettings(depthUnit: DepthUnit.feet));
    expect(find.text('Max depth'), findsNothing);
  });

  testWidgets('a phone width moves the difference under the group value', (tester) async {
    await pump(tester, report, width: 400);
    expect(find.text('Difference'), findsNothing);
    expect(find.textContaining('-2.1'), findsOneWidget);
  });

  testWidgets('too few dives renders nothing', (tester) async {
    await pump(tester, const FocusFactorReport(factors: [], tooFewDives: true));
    expect(find.text('Full comparison'), findsNothing);
  });
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/widgets/focus/focus_factors_table_test.dart`
Expected: FAIL on the `metric` parameter.

- [ ] **Step 4: Rewrite the table**

```dart
// lib/features/insights/presentation/widgets/focus/focus_factors_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_quiet_rows.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Below this width the difference column folds under the group value.
const double focusTableNarrowWidth = 600;

/// The group against its baseline, factor by factor: headed columns,
/// standouts first in each group, and rows that say nothing folded away.
class FocusFactorsTable extends ConsumerStatefulWidget {
  const FocusFactorsTable({super.key, required this.report, required this.metric});

  final FocusFactorReport report;
  final FocusMetric metric;

  @override
  ConsumerState<FocusFactorsTable> createState() => _FocusFactorsTableState();
}

class _FocusFactorsTableState extends ConsumerState<FocusFactorsTable> {
  bool _showQuiet = false;

  @override
  void didUpdateWidget(FocusFactorsTable old) {
    super.didUpdateWidget(old);
    // A new selection folds the quiet rows again.
    if (!identical(old.report, widget.report)) _showQuiet = false;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (report.tooFewDives) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final typesById = watchDiveTypesById(ref);
    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toLanguageTag());
    final narrow = MediaQuery.sizeOf(context).width < focusTableNarrowWidth;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    String? difference(FocusFactor f) => f is NumericFactor && f.difference != null
        ? focusNumericDifference(f.id, f.difference!, units, l10n)
        : null;
    final quiet = {
      for (final f in report.factors)
        if (focusFactorIsQuiet(f, formattedDifference: difference(f))) f.id,
    };
    final visible = [
      for (final f in report.factors)
        if (_showQuiet || !quiet.contains(f.id)) f,
    ];

    return StatSectionCard(
      title: l10n.insights_focus_comparison_title,
      subtitle: l10n.insights_focus_comparison_subtitle(focusMetricLabel(widget.metric, l10n)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visible.isNotEmpty)
            _Columns(
              narrow: narrow,
              label: const SizedBox.shrink(),
              these: Text(l10n.insights_focus_column_these, style: muted),
              all: Text(l10n.insights_focus_column_all, style: muted),
              difference: Text(l10n.insights_focus_column_difference, style: muted),
            ),
          for (final group in FocusFactorGroup.values)
            if (visible.any((f) => f.id.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(focusFactorGroupName(group, l10n), style: theme.textTheme.titleSmall),
              ),
              for (final f in _ordered(visible.where((f) => f.id.group == group)))
                _FactorRow(factor: f, units: units, percent: percent, typesById: typesById, narrow: narrow, difference: difference(f)),
            ],
          if (quiet.isNotEmpty && !_showQuiet)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                key: const ValueKey('focus-factors-show-more'),
                onPressed: () => setState(() => _showQuiet = true),
                child: Text(l10n.insights_focus_comparison_showMore(quiet.length)),
              ),
            ),
        ],
      ),
    );
  }

  /// Standouts first, the rest in display order.
  static List<FocusFactor> _ordered(Iterable<FocusFactor> factors) => [
    ...factors.where((f) => f.standsOut),
    ...factors.where((f) => !f.standsOut),
  ];
}

/// One row's four cells; on a narrow screen the difference moves under the
/// group cell and the fourth column disappears.
class _Columns extends StatelessWidget {
  const _Columns({required this.narrow, required this.label, required this.these, required this.all, required this.difference});
  final bool narrow;
  final Widget label;
  final Widget these;
  final Widget all;
  final Widget difference;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: label),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [these, difference])
              : these,
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: all),
        if (!narrow) ...[const SizedBox(width: 8), Expanded(flex: 2, child: difference)],
      ],
    ),
  );
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, required this.units, required this.percent, required this.typesById, required this.narrow, required this.difference});
  final FocusFactor factor;
  final UnitFormatter units;
  final NumberFormat percent;
  final Map<String, DiveTypeEntity> typesById;
  final bool narrow;
  final String? difference;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final bold = factor.standsOut ? const TextStyle(fontWeight: FontWeight.w600) : null;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (factor.standsOut)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  label: l10n.insights_focus_factors_standsOut,
                  child: Container(
                    key: ValueKey('focus-standout-marker-${factor.id.name}'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  ),
                ),
              ),
            Flexible(child: Text(focusFactorName(factor.id, l10n), style: bold)),
          ],
        ),
        if (factor.groupCovered > 0 && factor.groupCovered < factor.groupSize && factor is NumericFactor)
          Text(l10n.insights_focus_factors_coverage(factor.groupCovered, factor.groupSize), style: muted),
      ],
    );

    switch (factor) {
      case NumericFactor(:final groupMean, :final baselineMean) when groupMean != null && baselineMean != null:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Text(focusNumericValue(factor.id, groupMean, units, l10n), style: bold),
          all: Text(focusNumericValue(factor.id, baselineMean, units, l10n)),
          difference: Text(difference ?? '', style: muted),
        );
      case CategoricalFactor(:final top) when top.isNotEmpty:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in top)
                Text(
                  '${focusCategoryLabel(factor.id, s, l10n, units, typesById: typesById)} ${percent.format(s.groupShare)}',
                  style: s.standsOut ? const TextStyle(fontWeight: FontWeight.w600) : null,
                ),
            ],
          ),
          all: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final s in top) Text(percent.format(s.baselineShare))],
          ),
          difference: const SizedBox.shrink(),
        );
      default:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Text(l10n.insights_chart_notRecorded, style: muted),
          all: const SizedBox.shrink(),
          difference: const SizedBox.shrink(),
        );
    }
  }
}
```

`FocusResults` (Task 9) passes `metric:`; until then, update the one construction in `focus_results.dart` to `FocusFactorsTable(report: report, metric: selection.metric)` so the branch compiles.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights/presentation/widgets/focus test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: table tests PASS; page tests that look for "Common factors" fail until Task 9 (they are rewritten there).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/insights
git commit -m "feat(insights): headed, sorted and folded Dive focus comparison table"
```

---

### Task 9: The page: order, intro, legend, chart title and Show all

**Files:**
- Modify: `lib/features/insights/presentation/widgets/focus/focus_results.dart` (rewrite as `ConsumerStatefulWidget`)
- Modify: `lib/features/insights/presentation/pages/insights_focus_page.dart` (intro line)
- Modify: `lib/features/insights/presentation/widgets/insights_list_content.dart` (no code change; the subtitle string changes)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/insights/presentation/pages/insights_focus_page_test.dart` (update)

**Interfaces:**
- Consumes: `FocusSentence`, `FocusStandoutsCard`, `FocusFactorsTable(report, metric)`, `TrendReferenceLine`, `TrendSeries.pointRadius`.
- Produces: keys `focus-list-show-all`, `focus-legend`; `static const int FocusResults.previewRows = 5`.

- [ ] **Step 1: Change the English strings**

- `"insights_category_focus_subtitle": "What your best and worst dives have in common"`
- `"insights_focus_summary": "{count} of {total, plural, =1{1 dive} other{{total} dives}}. Average {group}, against {overall} across all your dives."` (placeholders unchanged)
- `"insights_focus_chart_title": "{metric} over time"` with `"@insights_focus_chart_title": { "placeholders": { "metric": { "type": "String" } } }`
- `"insights_focus_chart_group": "In the group"`
- add `"insights_focus_chart_others": "Other dives",`
- `"insights_focus_list_title": "The dives"`
- add `"insights_focus_list_showAll": "{count, plural, =1{Show the 1 dive} other{Show all {count} dives}}",` with int placeholder meta
- add `"insights_focus_intro": "See what a group of your dives has in common.",`

Run `flutter gen-l10n`.

- [ ] **Step 2: Update the page test**

In `insights_focus_page_test.dart` keep the `pump` helper, add `focusThresholdDefaultProvider.overrideWith((ref) async => 16)` to its overrides, and replace the body with:

```dart
  testWidgets('the page reads top to bottom: intro, sentence, summary, standouts, chart, comparison, dives', (tester) async {
    await pump(tester);
    expect(find.text('See what a group of your dives has in common.'), findsOneWidget);
    expect(find.byType(FocusSentence), findsOneWidget);
    expect(find.textContaining('10 of 12 dives. Average'), findsOneWidget);
    double y(Finder f) => tester.getTopLeft(f.first).dy;
    expect(y(find.byType(FocusSentence)), lessThan(y(find.text('What stands out'))));
    expect(y(find.text('What stands out')), lessThan(y(find.text('RMV over time'))));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('The dives'), 300, scrollable: scrollable);
    expect(y(find.text('Full comparison')), lessThan(y(find.text('The dives'))));
  });

  testWidgets('the dive list previews five rows and Show all expands it', (tester) async {
    await pump(tester);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('focus-list-show-all')), 300, scrollable: scrollable);
    expect(find.text('Show all 10 dives'), findsOneWidget);
    final list = tester.widget<FocusDiveList>(find.byType(FocusDiveList, skipOffstage: false));
    expect(list.members, hasLength(5));
    expect(list.ranked, isTrue);
    await tester.tap(find.byKey(const ValueKey('focus-list-show-all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-list-show-all')), findsNothing);
    expect(tester.widget<FocusDiveList>(find.byType(FocusDiveList, skipOffstage: false)).members, hasLength(10));
  });

  testWidgets('a group of five has no Show all; a new selection folds again', (tester) async {
    final c = await pump(tester, selection: const FocusSelection(count: 5));
    expect(find.byKey(const ValueKey('focus-list-show-all'), skipOffstage: false), findsNothing);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(count: 6);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Show all 6 dives', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the chart names the metric, shows a legend and bigger group dots', (tester) async {
    await pump(tester);
    expect(find.text('RMV over time'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-legend')), findsOneWidget);
    expect(find.text('In the group'), findsOneWidget);
    expect(find.text('Other dives'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    final scheme = Theme.of(tester.element(find.byType(DiveTrendChart))).colorScheme;
    expect(chart.pointColor, scheme.outlineVariant);
    expect(chart.secondarySeries.single.color, scheme.primary);
    expect(chart.secondarySeries.single.pointRadius, 4.4);
    expect(chart.referenceLine, isNull);
  });

  testWidgets('a threshold draws a labelled reference line', (tester) async {
    await pump(tester, selection: const FocusSelection(mode: FocusMode.above, threshold: 15));
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.referenceLine!.value, 15);
    expect(chart.referenceLine!.label, '15.0 L/min');
  });

  testWidgets('N beyond the data says all are shown', (tester) async {
    await pump(tester, selection: const FocusSelection(count: 20));
    expect(find.text('Only 12 dives have this value, so all of them are shown'), findsOneWidget);
  });

  testWidgets('a threshold with no match shows the range', (tester) async {
    await pump(tester, selection: const FocusSelection(mode: FocusMode.above, threshold: 500));
    expect(find.textContaining('No dives above'), findsOneWidget);
    expect(find.textContaining('Your dives range from'), findsOneWidget);
  });

  testWidgets('a failed group load shows the error state', (tester) async {
    await pump(tester, extraOverrides: [focusGroupProvider.overrideWith((ref) async => throw StateError('x'))]);
    expect(find.text('Failed to load dive focus'), findsOneWidget);
  });

  testWidgets('a failed factor report says so in both factor cards', (tester) async {
    await pump(tester, extraOverrides: [focusFactorReportProvider.overrideWith((ref) async => throw StateError('x'))]);
    expect(find.text('Failed to load dive focus', skipOffstage: false), findsNWidgets(2));
    expect(find.byType(DiveTrendChart, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a threshold mode with no value and no mean asks for one', (tester) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.above),
      extraOverrides: [focusThresholdDefaultProvider.overrideWith((ref) async => null)],
    );
    expect(find.text('Enter a value to see the dives above or below it'), findsOneWidget);
  });

  testWidgets('no dives with the metric shows the empty state', (tester) async {
    await pump(tester, series: const []);
    expect(find.text('No dives have this value yet'), findsOneWidget);
    expect(find.byType(FocusSentence), findsOneWidget);
  });

  testWidgets('tapping a row opens that dive', (tester) async {
    final pushed = <String>[];
    await pump(tester, pushed: pushed);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('focus-dive-d1')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.pumpAndSettle();
    expect(pushed, ['d1']);
  });

  testWidgets('changing N keeps the results up instead of flashing a spinner', (tester) async {
    final c = await pump(tester);
    final chart = tester.state(find.byType(DiveTrendChart));
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(count: 5);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('5 of 12 dives'), findsOneWidget);
    expect(tester.state(find.byType(DiveTrendChart)), same(chart));
  });

  testWidgets('a huge group builds only the rows on screen (#3013)', (tester) async {
    final many = [for (var i = 0; i < 1000; i++) TrendDataPoint(date: DateTime.utc(2020, 1, 1).add(Duration(days: i)), value: 12.0 + i % 10, diveId: 'd$i')];
    await pump(tester, series: many, selection: const FocusSelection(mode: FocusMode.above, threshold: 0));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('focus-list-show-all')), 2000, scrollable: scrollable, maxScrolls: 200);
    await tester.tap(find.byKey(const ValueKey('focus-list-show-all')));
    await tester.pump();
    final builtRows = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('focus-dive-'), skipOffstage: false);
    expect(builtRows.evaluate().length, lessThan(100));
  });

  testWidgets('asking for exactly every dive shows the normal summary', (tester) async {
    await pump(tester, selection: const FocusSelection(count: 12));
    expect(find.textContaining('12 of 12 dives'), findsOneWidget);
  });
```

Add imports for `FocusSentence`, `FocusDiveList` and `focusThresholdDefaultProvider`.

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/insights/presentation/pages/insights_focus_page_test.dart`
Expected: FAIL on the intro text and order.

- [ ] **Step 4: Implement**

`insights_focus_page.dart` content:

```dart
    const content = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _Intro()),
              SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: FocusSentence()),
              SliverToBoxAdapter(child: SizedBox(height: 16)),
              FocusResults(),
            ],
          ),
        ),
      ],
    );
```

with

```dart
class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) => Text(
    context.l10n.insights_focus_intro,
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
```

`focus_results.dart` becomes a `ConsumerStatefulWidget` with `bool _showAll = false;` reset by `ref.listen(focusSelectionProvider, (_, _) => setState(() => _showAll = false))` in `build`. Its `data:` branch returns:

```dart
            final report = ref.watch(focusFactorReportProvider);
            final members = _showAll
                ? group.members
                : group.members.take(FocusResults.previewRows).toList(growable: false);
            final hidden = group.members.length - members.length;
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      report.when(
                        skipLoadingOnReload: true,
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => StatSectionCard(
                          title: l10n.insights_focus_standouts_title,
                          child: Text(l10n.insights_focus_error),
                        ),
                        data: (r) => FocusStandoutsCard(report: r, groupSize: group.members.length),
                      ),
                      const SizedBox(height: 16),
                      StatSectionCard(
                        title: l10n.insights_focus_chart_title(focusMetricLabel(selection.metric, l10n)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Legend(key: const ValueKey('focus-legend'), group: theme.colorScheme.primary, others: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 8),
                            DiveTrendChart(
                              chartId: 'focus',
                              points: [for (final p in group.population) if (!memberIds.contains(p.diveId)) p],
                              secondarySeries: [
                                TrendSeries(
                                  label: l10n.insights_focus_chart_group,
                                  points: group.members,
                                  color: theme.colorScheme.primary,
                                  pointRadius: 4.4,
                                ),
                              ],
                              pointColor: theme.colorScheme.outlineVariant,
                              referenceLine: selection.mode.isRanked || selection.threshold == null
                                  ? null
                                  : TrendReferenceLine(
                                      value: selection.threshold!,
                                      label: metricUnits.format(selection.threshold!, l10n),
                                    ),
                              dateFormat: ref.watch(dateFormatProvider),
                              valueFormatter: (v) => metricUnits.format(v, l10n),
                              yAxisFormatter: (v) => metricUnits.toDisplay(v).toStringAsFixed(1),
                              onDiveSelected: (id) => context.push('/dives/$id'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      report.when(
                        skipLoadingOnReload: true,
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => StatSectionCard(
                          title: l10n.insights_focus_comparison_title,
                          child: Text(l10n.insights_focus_error),
                        ),
                        data: (r) => FocusFactorsTable(report: r, metric: selection.metric),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverStatSectionCard(
                  title: l10n.insights_focus_list_title,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      FocusDiveList(members: members, rows: rows, metricUnits: metricUnits, ranked: selection.mode.isRanked),
                      if (hidden > 0)
                        SliverToBoxAdapter(
                          child: Center(
                            child: TextButton(
                              key: const ValueKey('focus-list-show-all'),
                              onPressed: () => setState(() => _showAll = true),
                              child: Text(l10n.insights_focus_list_showAll(group.members.length)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
```

Add `static const int previewRows = 5;` on `FocusResults` and a small `_Legend` widget: a `Row` of two swatch-plus-label pairs (`Container` 10 by 10 with the colour, `SizedBox(width: 6)`, `Text` in `labelMedium`), spaced by 16. The too-few case is handled inside `FocusStandoutsCard` and `FocusFactorsTable`. The `SliverStatSectionCard` must accept a `SliverMainAxisGroup`; it takes any sliver.

Keep the `Material(type: MaterialType.transparency)` note in `focus_dive_list.dart`; nothing there changes.

- [ ] **Step 5: Run the focus tests**

Run: `flutter test test/features/insights/presentation/pages/insights_focus_page_test.dart test/features/insights/presentation/widgets/focus test/features/insights/presentation/pages/insights_gas_page_widget_test.dart test/features/insights/presentation/pages/insights_page_content_test.dart`
Expected: PASS. If `focus_results.dart` passes 400 lines, move `_Legend` and the chart card into `focus_chart_card.dart`.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/insights test/features/insights && flutter analyze
git add lib/features/insights lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart test/features/insights
git commit -m "feat(insights): Dive focus page leads with what stands out"
```

---

### Task 10: Translations, orphan keys and l10n guards

**Files:**
- Modify: all ten locale ARBs under `lib/l10n/arb/`
- Modify: `lib/l10n/arb/app_en.arb` (orphans)
- Test: `test/l10n/` (existing guards)

- [ ] **Step 1: List the keys**

```bash
git diff e4ce9cd7769..HEAD -- lib/l10n/arb/app_en.arb | grep '^[+-]  "insights_' | grep -v '^[+-]  "@'
```

Expect: added `insights_focus_metric_*` (8), `insights_focus_metricGroup_*` (5), `insights_focus_sentence_*` (2), `insights_focus_count_custom`, `insights_focus_count_dialogTitle`, `insights_focus_standouts_*` (6), `insights_focus_direction_*` (10), `insights_focus_comparison_*` (3), `insights_focus_column_*` (3), `insights_focus_chart_others`, `insights_focus_list_showAll`, `insights_focus_intro`; changed `insights_category_focus_subtitle`, `insights_focus_summary`, `insights_focus_chart_title`, `insights_focus_chart_group`, `insights_focus_list_title`, the six `insights_focus_mode_*`; removed `insights_focus_factors_title`, `_subtitle`, `_tooFew`, `_standoutsSummary`.

Also find orphans: `grep -rn "insights_focus_factors_versus\|insights_focus_threshold_label\|insights_focus_count_label" lib --include=*.dart` and drop any key no code reads from every ARB.

- [ ] **Step 2: Write the translations with a script**

Write `scratchpad/l10n_focus.py` (python3.14) holding a dict `{key: {locale: value}}` for every added and changed key in ar, de, es, fr, he, hu, it, nl, pt, zh. For each locale file: for an added key, insert the line `  "key": value,` after the anchor line `"insights_focus_metric_waterTemp"` (metrics and groups), `"insights_focus_threshold_negativeError"` (sentence and count), `"insights_focus_factors_coverage"` (standouts, directions, comparison, columns), `"insights_focus_chart_group"` (chart others), `"insights_focus_list_unknownSite"` (showAll), `"insights_focus_title"` (intro); for a changed key, replace the value on its own line; for a removed key, delete its line. Build each line with `json.dumps(value, ensure_ascii=False)`, and after writing assert `json.loads(open(f).read())` parses. Never json round-trip a file. Keep each locale's established nouns: look up how each locale renders "dive", "RMV", "SAC", "above", "below", "Boat Entry" in neighbouring focus keys and reuse them. Placeholders in `{braces}` and the `<count>`-style markers stay verbatim in every language, and plural forms keep both `=1{}` and `other{}` branches.

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n
git diff --numstat lib/l10n/arb/ | sort
```

Every locale row must show the same added/removed counts as its siblings; explain any that differs before moving on. Then `grep -A1 "get insights_focus_standouts_title" lib/l10n/arb/app_localizations_de.dart` to prove a translated body.

- [ ] **Step 4: Run the l10n guards**

Run: `flutter test test/l10n/`
Expected: PASS, including `arb_parity_test`, `arb_no_duplicate_keys_test`, `dive_focus_sentence_markers_test` for all eleven locales, and `dive_focus_count_strings_plural_test` (which pins `insights_focus_summary` and `insights_focus_factors_coverage`; add `insights_focus_list_showAll`, `insights_focus_standouts_more` and `insights_focus_comparison_showMore` to its list of plural keys).

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze
git add lib/l10n test/l10n
git commit -m "feat(insights): translate the Dive focus redesign strings"
```

---

### Task 11: User docs, guards, full run and after screenshots

**Files:**
- Modify: `docs/user/statistics.md` (Dive focus section)
- Delete: `test/features/insights/presentation/pages/tmp_focus_shot_test.dart` and `test/features/insights/presentation/pages/goldens/` (the throwaway before-screenshot test from brainstorming; never commit them)

- [ ] **Step 1: Rewrite the user docs section**

Replace the `### Dive focus` section of `docs/user/statistics.md` with:

```markdown
### Dive focus

Dive focus shows what a group of your dives has in common. Build the group as
a sentence: "Show the **10** dives with the **best** **RMV**", or "Show the
dives with **RMV** **above** **15 L/min**". Fourteen metrics are available,
grouped as Gas (RMV, SAC, gas used), Depth and time (max depth, average
depth, bottom time, surface interval), Conditions (water temp, air temp,
visibility, altitude), Exposure (CNS at end, OTU) and Kit (weight). Gas
metrics offer **best** and **worst**; the others offer **lowest** and
**highest**. A threshold starts at your average for that metric.

**What stands out** lists the strongest differences between the group and
every dive that has the value: "All 10 were boat entries (64% of all your
dives)", "Average depth 2.1 m shallower (11.3 m vs 13.4 m)". The chart
below marks the group in the accent colour and draws your threshold as a
dashed line. **Full comparison** gives every factor with the group's value,
the value across all dives and the difference; rows that say nothing fold
behind **Show more factors**. **The dives** lists the group, five at a time,
and opens any dive you tap. Dive focus needs at least three dives to compare.
```

- [ ] **Step 2: Remove the throwaway screenshot test**

```bash
rm -rf test/features/insights/presentation/pages/tmp_focus_shot_test.dart test/features/insights/presentation/pages/goldens
git status --porcelain
```

Expected: no untracked test files remain.

- [ ] **Step 3: Full checks**

```bash
dart format . && flutter analyze
flutter test test/features/insights test/l10n test/architecture test/shared
python3.14 scripts/check_docs_links.py
```

Expected: all PASS. Log long runs to the scratchpad and read the tail.

- [ ] **Step 4: After screenshots**

Recreate the throwaway golden test from brainstorming (same seed data, same four cases, light desktop, light phone, dark phone, and the threshold form with `FocusSelection(mode: FocusMode.above, threshold: 15)`), run it with `--update-goldens`, copy the PNGs to the scratchpad as `01-focus-after.png`, `02-focus-after-phone.png`, `03-focus-after-dark-phone.png`, `04-focus-threshold-after-phone.png`, then delete the test and goldens again. Look at every image before sending. Send before and after images in one `SendUserFile` call with `display: attach`.

- [ ] **Step 5: Commit**

```bash
git add docs/user/statistics.md
git commit -m "docs(insights): describe the redesigned Dive focus page"
```
