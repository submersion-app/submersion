# Weather and Conditions Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add statistics for every chartable field of the dive form's Conditions group to the Insights Conditions tab, organized into four headed groups.

**Architecture:** One SQL query returns every in-scope dive's condition columns; a pure-Dart `ConditionsStats.fromRows` builds every distribution, band count and coverage count in the diver's units; one rows provider and one derived stats provider feed reusable band and category cards, grouped on the existing Conditions page.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`), Drift `customSelect`, fl_chart via the existing `CategoryBarChart`, `HorizontalCategoryBarChart` and `DistributionPieChart`, ARB l10n.

**Spec:** `docs/design/specs/2026-10-10-conditions-weather-insights-design.md`

## Global Constraints

- Issue: #3118. Release v1.8.2.
- No schema change.
- Every displayed value respects the active diver's unit settings. Wind is km/h when the depth unit is metres and knots otherwise; surface pressure is mbar when metric and inHg otherwise; swell follows the depth unit; temperatures follow the temperature unit.
- Band edges (lower inclusive, upper exclusive; first open below, last open above):
  - Air temp °C: 10, 20, 25, 30. °F: 50, 70, 80, 90.
  - Wind km/h: 10, 20, 30, 40. kts: 5, 10, 15, 20.
  - Humidity %: 40, 60, 80.
  - Surface pressure mbar: 900, 1000, 1020. inHg: 27, 29.5, 30.1.
  - Swell m: 0.5, 1, 2. ft: 2, 3, 6.
- Display precision used before binning: air temp 1 decimal, wind 0, humidity 0, surface pressure 0 (mbar) or 2 (inHg), swell 1.
- Coverage line under each new chart: "Based on {recorded} of {total} dives", plural on total, using the CLDR `one` category (never `=1`).
- New cards with nothing recorded are hidden; Surface & weather and Water movement headers hide when all their cards are hidden.
- Altitude and exit method read the dive's stored value only (no site fallback).
- Existing cards keep their behaviour; they only move under group headers.
- Files stay under 800 lines; `insights_repository.dart` and `insights_providers.dart` do not grow beyond an import and a `part` line.
- No em dashes anywhere. No emojis. No mention of AI tools in code, commits or PR text.
- Stored dive times are decoded with `wallClockUtcFromMillis`.
- Every new user-facing string is translated into ar, de, es, fr, he, hu, it, nl, pt and zh; `flutter gen-l10n` runs after the translations are in.

## Review Focus

- **A reading exactly on an edge after unit conversion** (18.0 °C shown as 64.4 °F, 1.0 m swell shown as 3.3 ft): it must land in the band its displayed value says. Pinned in Task 1 (`countIntoBands` boundary tests) and Task 2 (°F and ft re-bin tests).
- **A blank or unrecognized stored enum string** (an import that wrote `''` or `'Partly Cloudy'` instead of `partlyCloudy`): counted as not recorded, never a crash. Pinned in Task 2 (`parseStoredEnum`) and Task 3 (repository maps a blank string to null).
- **A dive excluded from statistics or planned**: not counted, and not in the coverage denominator. Pinned in Task 3.
- **The query failing**: one error card per new group, the existing cards unaffected. Pinned in Task 7.
- **Switching °C to °F (or m to ft) with the page open**: re-bins without re-running the query. Pinned in Task 4.

---

### Task 1: Condition band edges and binning

**Files:**
- Create: `lib/features/insights/domain/conditions/condition_bands.dart`
- Test: `test/features/insights/domain/conditions/condition_bands_test.dart`

**Interfaces:**
- Produces:
  - `typedef BandCount = ({double? lower, double? upper, int count});`
  - `class ConditionsUnits { const ConditionsUnits({required TemperatureUnit temperature, required DepthUnit depth}); bool get isMetric; }` with value equality
  - `List<double> airTempBandEdges(TemperatureUnit unit)`
  - `List<double> windSpeedBandEdges({required bool metric})`
  - `const List<double> humidityBandEdges`
  - `List<double> surfacePressureBandEdges({required bool metric})`
  - `List<double> swellHeightBandEdges(DepthUnit unit)`
  - `double windSpeedForDisplay(double metersPerSecond, {required bool metric})`
  - `double surfacePressureForDisplay(double bar, {required bool metric})`
  - `List<BandCount> countIntoBands(Iterable<double> values, List<double> edges, {required int decimals})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('band edges', () {
    test('air temperature has round numbers per unit', () {
      expect(airTempBandEdges(TemperatureUnit.celsius), [10, 20, 25, 30]);
      expect(airTempBandEdges(TemperatureUnit.fahrenheit), [50, 70, 80, 90]);
    });

    test('wind follows the metric flag', () {
      expect(windSpeedBandEdges(metric: true), [10, 20, 30, 40]);
      expect(windSpeedBandEdges(metric: false), [5, 10, 15, 20]);
    });

    test('humidity, pressure and swell', () {
      expect(humidityBandEdges, [40, 60, 80]);
      expect(surfacePressureBandEdges(metric: true), [900, 1000, 1020]);
      expect(surfacePressureBandEdges(metric: false), [27, 29.5, 30.1]);
      expect(swellHeightBandEdges(DepthUnit.meters), [0.5, 1, 2]);
      expect(swellHeightBandEdges(DepthUnit.feet), [2, 3, 6]);
    });
  });

  group('ConditionsUnits', () {
    test('is metric when the depth unit is metres', () {
      const metric = ConditionsUnits(
        temperature: TemperatureUnit.celsius,
        depth: DepthUnit.meters,
      );
      const imperial = ConditionsUnits(
        temperature: TemperatureUnit.celsius,
        depth: DepthUnit.feet,
      );
      expect(metric.isMetric, isTrue);
      expect(imperial.isMetric, isFalse);
    });

    test('has value equality', () {
      expect(
        const ConditionsUnits(
          temperature: TemperatureUnit.fahrenheit,
          depth: DepthUnit.feet,
        ),
        const ConditionsUnits(
          temperature: TemperatureUnit.fahrenheit,
          depth: DepthUnit.feet,
        ),
      );
    });
  });

  group('conversions match UnitFormatter', () {
    // Two converters that disagreed would chart a dive in a band its own
    // detail page contradicts.
    test('wind speed', () {
      const metricFormatter = UnitFormatter(AppSettings());
      const imperialFormatter = UnitFormatter(
        AppSettings(depthUnit: DepthUnit.feet),
      );
      expect(
        windSpeedForDisplay(5, metric: true),
        closeTo(metricFormatter.convertWindSpeed(5), 1e-9),
      );
      expect(
        windSpeedForDisplay(5, metric: false),
        closeTo(imperialFormatter.convertWindSpeed(5), 1e-9),
      );
    });

    test('surface pressure', () {
      expect(surfacePressureForDisplay(1.013, metric: true), closeTo(1013, 1e-9));
      expect(
        surfacePressureForDisplay(1.0, metric: false),
        closeTo(29.53, 1e-9),
      );
    });
  });

  group('countIntoBands', () {
    test('returns every band, empty ones included', () {
      final bands = countIntoBands([12], [10, 20], decimals: 0);
      expect(bands, [
        (lower: null, upper: 10.0, count: 0),
        (lower: 10.0, upper: 20.0, count: 1),
        (lower: 20.0, upper: null, count: 0),
      ]);
    });

    test('lower edge is inclusive, upper exclusive', () {
      final bands = countIntoBands([10, 20, 19.9], [10, 20], decimals: 1);
      expect(bands.map((b) => b.count), [0, 2, 1]);
    });

    test('rounds to the displayed precision before binning', () {
      // 19.96 shows as "20.0", so it belongs to the band starting at 20.
      final bands = countIntoBands([19.96], [10, 20], decimals: 1);
      expect(bands.map((b) => b.count), [0, 0, 1]);
    });

    test('18 C converted to F lands where its displayed value says', () {
      // 18 C = 64.4 F, displayed 64.4: band 50-70.
      final f = TemperatureUnit.celsius.convert(18, TemperatureUnit.fahrenheit);
      final bands = countIntoBands([f], [50, 70, 80, 90], decimals: 1);
      expect(bands.map((b) => b.count), [0, 1, 0, 0, 0]);
    });

    test('no values gives all-zero bands', () {
      final bands = countIntoBands(const [], [1, 2], decimals: 0);
      expect(bands.map((b) => b.count), [0, 0, 0]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/domain/conditions/condition_bands_test.dart`
Expected: FAIL, `condition_bands.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:submersion/core/constants/units.dart';

/// One band of a numeric condition and how many dives fell in it (#3118).
///
/// [lower] is inclusive and [upper] exclusive, both in the display unit the
/// edges were defined in. Null leaves that side open, so the first band is
/// "below" and the last "at or above".
typedef BandCount = ({double? lower, double? upper, int count});

/// The unit choices the condition statistics bin in.
///
/// Wind, surface pressure and swell all follow the depth unit, as
/// `UnitFormatter` does: metric is km/h, mbar and metres; imperial is knots,
/// inHg and feet.
class ConditionsUnits {
  const ConditionsUnits({required this.temperature, required this.depth});

  final TemperatureUnit temperature;
  final DepthUnit depth;

  bool get isMetric => depth == DepthUnit.meters;

  @override
  bool operator ==(Object other) =>
      other is ConditionsUnits &&
      other.temperature == temperature &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(temperature, depth);
}

/// Air temperature edges. Each unit has its own round numbers rather than
/// one set converted, as `waterTempBandEdges` does.
List<double> airTempBandEdges(TemperatureUnit unit) => switch (unit) {
  TemperatureUnit.celsius => const <double>[10, 20, 25, 30],
  TemperatureUnit.fahrenheit => const <double>[50, 70, 80, 90],
};

/// Wind edges, roughly Beaufort 2 to 6 in each unit.
List<double> windSpeedBandEdges({required bool metric}) =>
    metric ? const <double>[10, 20, 30, 40] : const <double>[5, 10, 15, 20];

/// Relative humidity edges, in percent.
const List<double> humidityBandEdges = <double>[40, 60, 80];

/// Surface pressure edges: below 900 mbar is altitude, 1000 to 1020 is a
/// normal sea-level day.
List<double> surfacePressureBandEdges({required bool metric}) => metric
    ? const <double>[900, 1000, 1020]
    : const <double>[27, 29.5, 30.1];

/// Swell height edges in the depth unit.
List<double> swellHeightBandEdges(DepthUnit unit) => switch (unit) {
  DepthUnit.meters => const <double>[0.5, 1, 2],
  DepthUnit.feet => const <double>[2, 3, 6],
};

/// m/s to km/h or knots, with the factors `UnitFormatter.convertWindSpeed`
/// uses. The domain cannot depend on settings, so the factors are repeated
/// here and a test pins them to the formatter's.
double windSpeedForDisplay(double metersPerSecond, {required bool metric}) =>
    metric ? metersPerSecond * 3.6 : metersPerSecond * 1.94384;

/// bar to mbar or inHg, with the factors `UnitFormatter.formatSurfacePressure`
/// uses.
double surfacePressureForDisplay(double bar, {required bool metric}) =>
    metric ? bar * 1000 : bar * 29.53;

/// Counts [values], already in the display unit, into the bands [edges]
/// define.
///
/// Each value is first rounded to the [decimals] the app displays it at, so a
/// reading shown as "20.0" lands in the band that starts at 20 even when it
/// is stored as 19.96. Every band is returned, empty ones included.
List<BandCount> countIntoBands(
  Iterable<double> values,
  List<double> edges, {
  required int decimals,
}) {
  int bandOf(double value) {
    final shown = double.parse(value.toStringAsFixed(decimals));
    final above = edges.lastIndexWhere((edge) => shown >= edge);
    return above + 1;
  }

  final indexes = values.map(bandOf).toList();
  return [
    for (var band = 0; band <= edges.length; band++)
      (
        lower: band == 0 ? null : edges[band - 1],
        upper: band == edges.length ? null : edges[band],
        count: indexes.where((i) => i == band).length,
      ),
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/insights/domain/conditions/condition_bands_test.dart`
Expected: PASS. If the `AppSettings()` const constructor needs arguments, construct it as the test helpers do (`const AppSettings(hasAcceptedPlanningDisclaimer: true)`) and pass `depthUnit:` the same way.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/domain/conditions/condition_bands.dart test/features/insights/domain/conditions/condition_bands_test.dart
git commit -m "feat(insights): band edges and binning for condition statistics"
```

---

### Task 2: Conditions row and stats aggregation

**Files:**
- Create: `lib/features/insights/domain/conditions/conditions_row.dart`
- Create: `lib/features/insights/domain/conditions/conditions_stats.dart`
- Test: `test/features/insights/domain/conditions/conditions_stats_test.dart`

**Interfaces:**
- Consumes: Task 1's `BandCount`, `ConditionsUnits`, edge functions, conversions, `countIntoBands`.
- Produces:
  - `T? parseStoredEnum<T extends Enum>(List<T> values, String? name)`
  - `class ConditionsRow` with `diveId`, `dateTime`, `airTemp` (°C), `cloudCover`, `precipitation`, `windSpeed` (m/s), `windDirection` (`CurrentDirection`), `humidity`, `surfacePressure` (bar), `currentStrength`, `currentDirection`, `swellHeight` (m), `altitude` (m), `exitMethod` (`EntryMethod`)
  - `class CategoryStat<T extends Enum> { List<({T value, int count})> counts; int recorded; bool get isEmpty; }`
  - `class BandStat { List<BandCount> bands; int recorded; bool get isEmpty; }`
  - `class ConditionsStats` with `totalDives`, `airTempTrend` (`List<TrendDataPoint>`), `airTemp`, `cloudCover`, `precipitation`, `windSpeed`, `windDirection`, `humidity`, `surfacePressure`, `currentStrength`, `currentDirection`, `swellHeight`, `altitude` (`CategoryStat<AltitudeGroup>`), `exitMethod` (`CategoryStat<EntryMethod>`), and `factory ConditionsStats.fromRows(List<ConditionsRow> rows, ConditionsUnits units)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';

void main() {
  const metric = ConditionsUnits(
    temperature: TemperatureUnit.celsius,
    depth: DepthUnit.meters,
  );
  const imperial = ConditionsUnits(
    temperature: TemperatureUnit.fahrenheit,
    depth: DepthUnit.feet,
  );

  var seq = 0;
  ConditionsRow row({
    int day = 1,
    double? airTemp,
    CloudCover? cloudCover,
    Precipitation? precipitation,
    double? windSpeed,
    CurrentDirection? windDirection,
    double? humidity,
    double? surfacePressure,
    CurrentStrength? currentStrength,
    CurrentDirection? currentDirection,
    double? swellHeight,
    double? altitude,
    EntryMethod? exitMethod,
  }) {
    seq++;
    return ConditionsRow(
      diveId: 'dive-$seq',
      dateTime: DateTime.utc(2026, 1, day),
      airTemp: airTemp,
      cloudCover: cloudCover,
      precipitation: precipitation,
      windSpeed: windSpeed,
      windDirection: windDirection,
      humidity: humidity,
      surfacePressure: surfacePressure,
      currentStrength: currentStrength,
      currentDirection: currentDirection,
      swellHeight: swellHeight,
      altitude: altitude,
      exitMethod: exitMethod,
    );
  }

  group('parseStoredEnum', () {
    test('reads a stored enum name', () {
      expect(
        parseStoredEnum(CloudCover.values, 'partlyCloudy'),
        CloudCover.partlyCloudy,
      );
    });

    test('blank, unknown and null are not recorded', () {
      expect(parseStoredEnum(CloudCover.values, ''), isNull);
      expect(parseStoredEnum(CloudCover.values, 'Partly Cloudy'), isNull);
      expect(parseStoredEnum(CloudCover.values, null), isNull);
    });
  });

  test('no rows gives empty slices and zero total', () {
    final stats = ConditionsStats.fromRows(const [], metric);
    expect(stats.totalDives, 0);
    expect(stats.airTemp.isEmpty, isTrue);
    expect(stats.cloudCover.isEmpty, isTrue);
    expect(stats.airTempTrend, isEmpty);
  });

  test('totalDives counts every row, recorded only those with a value', () {
    final stats = ConditionsStats.fromRows([
      row(cloudCover: CloudCover.clear),
      row(),
      row(),
    ], metric);
    expect(stats.totalDives, 3);
    expect(stats.cloudCover.recorded, 1);
  });

  test('categories are in natural order with zero categories dropped', () {
    final stats = ConditionsStats.fromRows([
      row(precipitation: Precipitation.rain),
      row(precipitation: Precipitation.rain),
      row(precipitation: Precipitation.rain),
      row(precipitation: Precipitation.none),
    ], metric);
    // Natural order puts None first though Rain has more dives.
    expect(stats.precipitation.counts, [
      (value: Precipitation.none, count: 1),
      (value: Precipitation.rain, count: 3),
    ]);
    expect(stats.precipitation.recorded, 4);
  });

  test('wind and current direction count separately', () {
    final stats = ConditionsStats.fromRows([
      row(windDirection: CurrentDirection.north),
      row(currentDirection: CurrentDirection.south),
    ], metric);
    expect(stats.windDirection.counts, [
      (value: CurrentDirection.north, count: 1),
    ]);
    expect(stats.currentDirection.counts, [
      (value: CurrentDirection.south, count: 1),
    ]);
  });

  test('current strength, exit method and altitude groups', () {
    final stats = ConditionsStats.fromRows([
      row(
        currentStrength: CurrentStrength.strong,
        exitMethod: EntryMethod.ladder,
        altitude: 50,
      ),
      row(altitude: 1200),
    ], metric);
    expect(stats.currentStrength.counts, [
      (value: CurrentStrength.strong, count: 1),
    ]);
    expect(stats.exitMethod.counts, [(value: EntryMethod.ladder, count: 1)]);
    expect(stats.altitude.counts, [
      (value: AltitudeGroup.seaLevel, count: 1),
      (value: AltitudeGroup.group2, count: 1),
    ]);
  });

  test('numeric fields bin in metric units', () {
    final stats = ConditionsStats.fromRows([
      row(
        airTemp: 22,
        windSpeed: 5, // 18 km/h
        humidity: 75,
        surfacePressure: 1.013, // 1013 mbar
        swellHeight: 1.5,
      ),
    ], metric);
    expect(stats.airTemp.bands.map((b) => b.count), [0, 0, 1, 0, 0]);
    expect(stats.windSpeed.bands.map((b) => b.count), [0, 1, 0, 0, 0]);
    expect(stats.humidity.bands.map((b) => b.count), [0, 0, 1, 0]);
    expect(stats.surfacePressure.bands.map((b) => b.count), [0, 0, 1, 0]);
    expect(stats.swellHeight.bands.map((b) => b.count), [0, 0, 1, 0]);
  });

  test('numeric fields re-bin in imperial units', () {
    final stats = ConditionsStats.fromRows([
      row(
        airTemp: 22, // 71.6 F
        windSpeed: 5, // 9.7 kts, shown as 10
        surfacePressure: 1.013, // 29.91 inHg
        swellHeight: 1.0, // 3.3 ft
      ),
    ], imperial);
    expect(stats.airTemp.bands.first.upper, 50);
    expect(stats.airTemp.bands.map((b) => b.count), [0, 0, 1, 0, 0]);
    // 9.72 kts displays as "10", so it starts the 10-15 band.
    expect(stats.windSpeed.bands.map((b) => b.count), [0, 0, 1, 0, 0]);
    expect(stats.surfacePressure.bands.map((b) => b.count), [0, 0, 1, 0]);
    expect(stats.swellHeight.bands.map((b) => b.count), [0, 0, 1, 0]);
  });

  test('air temperature trend is dated, in Celsius, with dive ids', () {
    final stats = ConditionsStats.fromRows([
      row(day: 5, airTemp: 30),
      row(day: 2, airTemp: 20),
      row(day: 3),
    ], imperial);
    expect(stats.airTempTrend.map((p) => p.value), [20, 30]);
    expect(stats.airTempTrend.map((p) => p.date.day), [2, 5]);
    expect(stats.airTempTrend.every((p) => p.diveId != null), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/domain/conditions/conditions_stats_test.dart`
Expected: FAIL, the two files do not exist.

- [ ] **Step 3: Write `conditions_row.dart`**

```dart
import 'package:submersion/core/constants/enums.dart';

/// The enum value stored under [name], or null when [name] is null, blank or
/// not a value of the enum. An import that wrote display text instead of the
/// enum name counts as not recorded rather than failing the whole chart.
T? parseStoredEnum<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : values.asNameMap()[name];

/// One in-scope dive's condition fields, as the Conditions statistics read
/// them (issue #3118). Units are the stored ones: Celsius, m/s, bar, metres.
class ConditionsRow {
  const ConditionsRow({
    required this.diveId,
    required this.dateTime,
    this.airTemp,
    this.cloudCover,
    this.precipitation,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.surfacePressure,
    this.currentStrength,
    this.currentDirection,
    this.swellHeight,
    this.altitude,
    this.exitMethod,
  });

  final String diveId;
  final DateTime dateTime;
  final double? airTemp;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? windSpeed;
  final CurrentDirection? windDirection;
  final double? humidity;
  final double? surfacePressure;
  final CurrentStrength? currentStrength;
  final CurrentDirection? currentDirection;
  final double? swellHeight;
  final double? altitude;
  final EntryMethod? exitMethod;
}
```

- [ ] **Step 4: Write `conditions_stats.dart`**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// Dives per value of a categorical condition, in the enum's natural order
/// (calm to severe, clockwise compass), categories with no dive left out.
class CategoryStat<T extends Enum> {
  const CategoryStat({required this.counts, required this.recorded});

  final List<({T value, int count})> counts;

  /// Dives with this field recorded: the first number of the coverage line.
  final int recorded;

  bool get isEmpty => recorded == 0;
}

/// Dives per band of a numeric condition, every band included.
class BandStat {
  const BandStat({required this.bands, required this.recorded});

  final List<BandCount> bands;
  final int recorded;

  bool get isEmpty => recorded == 0;
}

/// Every statistic on the Conditions tab that comes from the condition
/// columns (issue #3118), built in one pass over the in-scope dives.
class ConditionsStats {
  const ConditionsStats({
    required this.totalDives,
    required this.airTempTrend,
    required this.airTemp,
    required this.cloudCover,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.humidity,
    required this.surfacePressure,
    required this.currentStrength,
    required this.currentDirection,
    required this.swellHeight,
    required this.altitude,
    required this.exitMethod,
  });

  /// [rows] holds every in-scope dive, recorded or not, so its length is the
  /// coverage line's denominator. Bands are binned in [units].
  factory ConditionsStats.fromRows(
    List<ConditionsRow> rows,
    ConditionsUnits units,
  ) {
    CategoryStat<T> category<T extends Enum>(
      List<T> order,
      T? Function(ConditionsRow) pick,
    ) {
      final picked = [for (final r in rows) ?pick(r)];
      return CategoryStat<T>(
        counts: [
          for (final value in order)
            if (picked.where((p) => p == value).length case final count
                when count > 0)
              (value: value, count: count),
        ],
        recorded: picked.length,
      );
    }

    BandStat band(
      double? Function(ConditionsRow) pick,
      List<double> edges,
      int decimals,
    ) {
      final values = [for (final r in rows) ?pick(r)];
      return BandStat(
        bands: countIntoBands(values, edges, decimals: decimals),
        recorded: values.length,
      );
    }

    final metric = units.isMetric;
    final trend = [
      for (final r in rows)
        if (r.airTemp case final celsius?)
          TrendDataPoint(date: r.dateTime, value: celsius, diveId: r.diveId),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return ConditionsStats(
      totalDives: rows.length,
      airTempTrend: List.unmodifiable(trend),
      airTemp: band(
        (r) => r.airTemp == null
            ? null
            : TemperatureUnit.celsius.convert(r.airTemp!, units.temperature),
        airTempBandEdges(units.temperature),
        1,
      ),
      cloudCover: category(CloudCover.values, (r) => r.cloudCover),
      precipitation: category(Precipitation.values, (r) => r.precipitation),
      windSpeed: band(
        (r) => r.windSpeed == null
            ? null
            : windSpeedForDisplay(r.windSpeed!, metric: metric),
        windSpeedBandEdges(metric: metric),
        0,
      ),
      windDirection: category(CurrentDirection.values, (r) => r.windDirection),
      humidity: band((r) => r.humidity, humidityBandEdges, 0),
      surfacePressure: band(
        (r) => r.surfacePressure == null
            ? null
            : surfacePressureForDisplay(r.surfacePressure!, metric: metric),
        surfacePressureBandEdges(metric: metric),
        metric ? 0 : 2,
      ),
      currentStrength: category(
        CurrentStrength.values,
        (r) => r.currentStrength,
      ),
      currentDirection: category(
        CurrentDirection.values,
        (r) => r.currentDirection,
      ),
      swellHeight: band(
        (r) => r.swellHeight == null
            ? null
            : DepthUnit.meters.convert(r.swellHeight!, units.depth),
        swellHeightBandEdges(units.depth),
        1,
      ),
      altitude: category(
        AltitudeGroup.values,
        (r) => r.altitude == null ? null : AltitudeGroup.fromAltitude(r.altitude),
      ),
      exitMethod: category(EntryMethod.values, (r) => r.exitMethod),
    );
  }

  final int totalDives;

  /// Air temperature per dive in Celsius, by date; formatted at display time.
  final List<TrendDataPoint> airTempTrend;
  final BandStat airTemp;
  final CategoryStat<CloudCover> cloudCover;
  final CategoryStat<Precipitation> precipitation;
  final BandStat windSpeed;
  final CategoryStat<CurrentDirection> windDirection;
  final BandStat humidity;
  final BandStat surfacePressure;
  final CategoryStat<CurrentStrength> currentStrength;
  final CategoryStat<CurrentDirection> currentDirection;
  final BandStat swellHeight;
  final CategoryStat<AltitudeGroup> altitude;
  final CategoryStat<EntryMethod> exitMethod;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/insights/domain/conditions/`
Expected: PASS. If the `if (... case final count when count > 0)` element does not compile on this SDK, replace it with a precomputed `final countOf = {for (final v in order) v: picked.where((p) => p == v).length};` and `for (final v in order) if (countOf[v]! > 0) (value: v, count: countOf[v]!)`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/domain/conditions/ test/features/insights/domain/conditions/conditions_stats_test.dart
git commit -m "feat(insights): aggregate condition statistics from per-dive rows"
```

---

### Task 3: Repository query for condition rows

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_conditions.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (one import for `conditions_row.dart`, one `part` line beside `part 'insights_repository_focus.dart';`)
- Test: `test/features/insights/data/repositories/conditions_rows_test.dart`

**Interfaces:**
- Consumes: Task 2's `ConditionsRow`, `parseStoredEnum`.
- Produces: `extension InsightsRepositoryConditions on InsightsRepository { Future<List<ConditionsRow>> getConditionsRows({String? diverId, DiveFilterState filter = const DiveFilterState()}); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    int day = 1,
    String? diverId,
    String? siteId,
    bool excluded = false,
    bool planned = false,
    double? airTemp,
    String? cloudCover,
    String? precipitation,
    double? windSpeed,
    String? windDirection,
    double? humidity,
    double? surfacePressure,
    String? currentStrength,
    String? currentDirection,
    double? swellHeight,
    double? altitude,
    String? exitMethod,
  }) async {
    final ms = DateTime.utc(2026, 3, day, 10).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(ms),
            diverId: Value(diverId),
            siteId: Value(siteId),
            excludedFromStats: Value(excluded),
            isPlanned: Value(planned),
            airTemp: Value(airTemp),
            cloudCover: Value(cloudCover),
            precipitation: Value(precipitation),
            windSpeed: Value(windSpeed),
            windDirection: Value(windDirection),
            humidity: Value(humidity),
            surfacePressure: Value(surfacePressure),
            currentStrength: Value(currentStrength),
            currentDirection: Value(currentDirection),
            swellHeight: Value(swellHeight),
            altitude: Value(altitude),
            exitMethod: Value(exitMethod),
            createdAt: Value(ms),
            updatedAt: Value(ms),
          ),
        );
  }

  test('maps every condition column', () async {
    await insertDive(
      'a',
      airTemp: 24.5,
      cloudCover: 'overcast',
      precipitation: 'drizzle',
      windSpeed: 6.2,
      windDirection: 'northEast',
      humidity: 81,
      surfacePressure: 1.009,
      currentStrength: 'light',
      currentDirection: 'west',
      swellHeight: 0.8,
      altitude: 450,
      exitMethod: 'ladder',
    );

    final rows = await repository.getConditionsRows();

    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.diveId, 'a');
    expect(r.dateTime, DateTime.utc(2026, 3, 1, 10));
    expect(r.airTemp, 24.5);
    expect(r.cloudCover, CloudCover.overcast);
    expect(r.precipitation, Precipitation.drizzle);
    expect(r.windSpeed, 6.2);
    expect(r.windDirection, CurrentDirection.northEast);
    expect(r.humidity, 81);
    expect(r.surfacePressure, 1.009);
    expect(r.currentStrength, CurrentStrength.light);
    expect(r.currentDirection, CurrentDirection.west);
    expect(r.swellHeight, 0.8);
    expect(r.altitude, 450);
    expect(r.exitMethod, EntryMethod.ladder);
  });

  test('returns dives with nothing recorded, ordered by date', () async {
    await insertDive('later', day: 9);
    await insertDive('earlier', day: 2, cloudCover: 'clear');

    final rows = await repository.getConditionsRows();

    expect(rows.map((r) => r.diveId), ['earlier', 'later']);
    expect(rows.last.cloudCover, isNull);
  });

  test('a blank or display-text enum string reads as not recorded', () async {
    await insertDive('a', cloudCover: '', precipitation: 'Light Rain');

    final r = (await repository.getConditionsRows()).single;

    expect(r.cloudCover, isNull);
    expect(r.precipitation, isNull);
  });

  test('leaves out excluded and planned dives', () async {
    await insertDive('kept');
    await insertDive('excluded', excluded: true);
    await insertDive('planned', planned: true);

    final rows = await repository.getConditionsRows();

    expect(rows.map((r) => r.diveId), ['kept']);
  });

  test('honours the diver and the view filter', () async {
    await insertDive('mine-reef', diverId: 'me', siteId: 'reef');
    await insertDive('mine-lake', diverId: 'me', siteId: 'lake');
    await insertDive('theirs-reef', diverId: 'them', siteId: 'reef');

    final rows = await repository.getConditionsRows(
      diverId: 'me',
      filter: const DiveFilterState(siteId: 'reef'),
    );

    expect(rows.map((r) => r.diveId), ['mine-reef']);
  });
}
```

If inserting a dive with a `siteId` that has no `dive_sites` row trips a foreign key, insert minimal `DiveSitesCompanion` rows for `reef` and `lake` first, copying the helper in `water_type_distribution_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/data/repositories/conditions_rows_test.dart`
Expected: FAIL, `getConditionsRows` is not defined.

- [ ] **Step 3: Write the part file**

```dart
part of 'insights_repository.dart';

/// The per-dive condition columns behind the Conditions tab's weather and
/// water-movement statistics (issue #3118), kept beside the repository so the
/// main file does not grow further; a part shares its scope helpers.
extension InsightsRepositoryConditions on InsightsRepository {
  /// One row per in-scope dive, recorded or not, ordered by date.
  ///
  /// Every dive is returned so the row count is the "of N dives" denominator
  /// of each chart's coverage line. Altitude and exit method are the dive's
  /// stored values: neither has a site fallback that decompression or the
  /// detail page would agree with.
  Future<List<ConditionsRow>> getConditionsRows({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND dives.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = [?diverId, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          id, dive_date_time, air_temp, cloud_cover, precipitation,
          wind_speed, wind_direction, humidity, surface_pressure,
          current_strength, current_direction, swell_height, altitude,
          exit_method
        FROM dives
        WHERE 1 = 1 $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return [
        for (final row in results)
          ConditionsRow(
            diveId: row.read<String>('id'),
            dateTime: wallClockUtcFromMillis(row.read<int>('dive_date_time')),
            airTemp: row.read<double?>('air_temp'),
            cloudCover: parseStoredEnum(
              CloudCover.values,
              row.read<String?>('cloud_cover'),
            ),
            precipitation: parseStoredEnum(
              Precipitation.values,
              row.read<String?>('precipitation'),
            ),
            windSpeed: row.read<double?>('wind_speed'),
            windDirection: parseStoredEnum(
              CurrentDirection.values,
              row.read<String?>('wind_direction'),
            ),
            humidity: row.read<double?>('humidity'),
            surfacePressure: row.read<double?>('surface_pressure'),
            currentStrength: parseStoredEnum(
              CurrentStrength.values,
              row.read<String?>('current_strength'),
            ),
            currentDirection: parseStoredEnum(
              CurrentDirection.values,
              row.read<String?>('current_direction'),
            ),
            swellHeight: row.read<double?>('swell_height'),
            altitude: row.read<double?>('altitude'),
            exitMethod: parseStoredEnum(
              EntryMethod.values,
              row.read<String?>('exit_method'),
            ),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get conditions rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Wire the part into the repository**

In `insights_repository.dart`, add beside the other domain imports:

```dart
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
```

and, if `package:submersion/core/constants/enums.dart` is not already imported, add it. Next to `part 'insights_repository_focus.dart';` add:

```dart
part 'insights_repository_conditions.dart';
```

Callers of the extension need no extra import because the part shares the library.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/insights/data/repositories/conditions_rows_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/data/repositories/insights_repository.dart lib/features/insights/data/repositories/insights_repository_conditions.dart test/features/insights/data/repositories/conditions_rows_test.dart
git commit -m "feat(insights): query condition columns for every in-scope dive"
```

---

### Task 4: Providers

**Files:**
- Create: `lib/features/insights/presentation/providers/conditions_stats_providers.dart`
- Modify: `lib/features/insights/presentation/providers/trend_chart_settings_provider.dart` (add `airTemp` id)
- Test: `test/features/insights/presentation/providers/conditions_stats_providers_test.dart`

**Interfaces:**
- Consumes: Task 3's `getConditionsRows`; Task 2's `ConditionsStats.fromRows`; Task 1's `ConditionsUnits`.
- Produces:
  - `final conditionsRowsProvider = FutureProvider<List<ConditionsRow>>`
  - `final conditionsUnitsProvider = Provider<ConditionsUnits>`
  - `final conditionsStatsProvider = FutureProvider<ConditionsStats>`
  - `TrendChartIds.airTemp == 'air-temp'`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('air temperature trend has its own chart id', () {
    expect(TrendChartIds.airTemp, 'air-temp');
  });

  test('a unit change re-bins without re-running the query', () async {
    var queries = 0;
    final settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides(settingsNotifier: settings)).cast(),
        conditionsRowsProvider.overrideWith((ref) async {
          queries++;
          return [
            ConditionsRow(
              diveId: 'a',
              dateTime: DateTime.utc(2026, 1, 1),
              airTemp: 22, // 20-25 C; 71.6 F is 70-80 F
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conditionsStatsProvider, (_, _) {});

    final celsius = await container.read(conditionsStatsProvider.future);
    expect(celsius.airTemp.bands.first.upper, 10);

    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    final fahrenheit = await container.read(conditionsStatsProvider.future);

    expect(fahrenheit.airTemp.bands.first.upper, 50);
    expect(fahrenheit.airTemp.bands.map((b) => b.count), [0, 0, 1, 0, 0]);
    expect(queries, 1);
  });

  test('depth unit switches wind and swell to imperial', () async {
    final settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides(settingsNotifier: settings)).cast(),
        conditionsRowsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conditionsUnitsProvider, (_, _) {});

    expect(container.read(conditionsUnitsProvider).isMetric, isTrue);
    await settings.setDepthUnit(DepthUnit.feet);
    expect(container.read(conditionsUnitsProvider).isMetric, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/presentation/providers/conditions_stats_providers_test.dart`
Expected: FAIL, the providers file and `TrendChartIds.airTemp` do not exist.

- [ ] **Step 3: Add the chart id**

In `trend_chart_settings_provider.dart`, inside `abstract final class TrendChartIds`, after `waterTemp`:

```dart
  static const airTemp = 'air-temp';
```

- [ ] **Step 4: Write the providers**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Every in-scope dive's condition columns (issue #3118). Keyed on the diver
/// and the Insights filter only, so a unit change does not re-query.
final conditionsRowsProvider = FutureProvider<List<ConditionsRow>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(insightsFilterProvider);
  return repository.getConditionsRows(diverId: diverId, filter: filter);
});

/// The unit choices the condition bands are defined in.
final conditionsUnitsProvider = Provider<ConditionsUnits>(
  (ref) => ConditionsUnits(
    temperature: ref.watch(settingsProvider.select((s) => s.temperatureUnit)),
    depth: ref.watch(settingsProvider.select((s) => s.depthUnit)),
  ),
);

/// Every condition statistic, re-binned when the units change.
final conditionsStatsProvider = FutureProvider<ConditionsStats>((ref) async {
  final units = ref.watch(conditionsUnitsProvider);
  final rows = await ref.watch(conditionsRowsProvider.future);
  return ConditionsStats.fromRows(rows, units);
});
```

`invalidateSelfWhen` is the project's extension used by `insights_focus_providers.dart`; if the import above does not bring it in, import it from wherever that file gets it. The provider-tick architecture guard requires it here.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/insights/presentation/providers/conditions_stats_providers_test.dart test/architecture/provider_change_tick_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/presentation/providers/conditions_stats_providers.dart lib/features/insights/presentation/providers/trend_chart_settings_provider.dart test/features/insights/presentation/providers/conditions_stats_providers_test.dart
git commit -m "feat(insights): providers for condition statistics"
```

---

### Task 5: Localized strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces these getters on `AppLocalizations` (placeholders in the order shown):
  - `insights_conditions_group_water`, `insights_conditions_group_surfaceWeather`, `insights_conditions_group_waterMovement`, `insights_conditions_group_siteAccess`
  - `insights_conditions_coverage(int recorded, int total)`
  - `insights_conditions_weather_error`
  - `insights_conditions_chart_semanticLabel(String chartTitle, String description)`
  - `insights_conditions_airTempTrend_title`, `_subtitle`, `_error`
  - `insights_conditions_<card>_title` and `_subtitle` for card in: `airTempBands`, `cloudCover`, `precipitation`, `windSpeed`, `windDirection`, `humidity`, `surfacePressure`, `currentStrength`, `currentDirection`, `swellHeight`, `altitude`, `exitMethod`

- [ ] **Step 1: Write the English keys**

Insert this block into `app_en.arb` immediately before the line `"insights_conditions_waterTempBands_title": ...` (textual insert, never a JSON round-trip):

```json
  "insights_conditions_group_water": "Water",
  "@insights_conditions_group_water": {"description": "Heading of the Conditions statistics group for water temperature, visibility and water type"},
  "insights_conditions_group_surfaceWeather": "Surface & Weather",
  "@insights_conditions_group_surfaceWeather": {"description": "Heading of the Conditions statistics group for air temperature, cloud, precipitation, wind, humidity and surface pressure"},
  "insights_conditions_group_waterMovement": "Water Movement",
  "@insights_conditions_group_waterMovement": {"description": "Heading of the Conditions statistics group for current and swell"},
  "insights_conditions_group_siteAccess": "Site & Access",
  "@insights_conditions_group_siteAccess": {"description": "Heading of the Conditions statistics group for site type, altitude, entry method and exit method"},
  "insights_conditions_coverage": "{total, plural, one{Based on {recorded} of {total} dive} other{Based on {recorded} of {total} dives}}",
  "@insights_conditions_coverage": {"description": "Line under a Conditions chart: how many dives in the current filter have this field recorded, out of all dives in the filter", "placeholders": {"recorded": {"type": "int"}, "total": {"type": "int"}}},
  "insights_conditions_weather_error": "Failed to load weather and conditions data",
  "@insights_conditions_weather_error": {"description": "Error shown in a Conditions statistics group when the weather and conditions data could not be loaded"},
  "insights_conditions_chart_semanticLabel": "{chartTitle}. {description}",
  "@insights_conditions_chart_semanticLabel": {"description": "Screen-reader summary of a Conditions chart: its title followed by each category or band with its dive count", "placeholders": {"chartTitle": {"type": "String"}, "description": {"type": "String"}}},
  "insights_conditions_airTempTrend_title": "Air Temperature Over Time",
  "@insights_conditions_airTempTrend_title": {"description": "Title of the chart of air temperature on each dive over time"},
  "insights_conditions_airTempTrend_subtitle": "Air temperature on each dive",
  "@insights_conditions_airTempTrend_subtitle": {"description": "Subtitle of the air temperature over time chart"},
  "insights_conditions_airTempTrend_error": "Failed to load air temperature",
  "@insights_conditions_airTempTrend_error": {"description": "Error state of the air temperature over time chart"},
  "insights_conditions_airTempBands_title": "Dives by Air Temperature",
  "@insights_conditions_airTempBands_title": {"description": "Title of the card counting dives per air-temperature band"},
  "insights_conditions_airTempBands_subtitle": "How your dives split across air temperature bands",
  "@insights_conditions_airTempBands_subtitle": {"description": "Subtitle of the dives-by-air-temperature card"},
  "insights_conditions_cloudCover_title": "Cloud Cover",
  "@insights_conditions_cloudCover_title": {"description": "Title of the card showing the share of dives per cloud cover (clear to overcast)"},
  "insights_conditions_cloudCover_subtitle": "Sky conditions on your dives",
  "@insights_conditions_cloudCover_subtitle": {"description": "Subtitle of the cloud cover card"},
  "insights_conditions_precipitation_title": "Precipitation",
  "@insights_conditions_precipitation_title": {"description": "Title of the card counting dives per precipitation type (none, drizzle, rain, snow and so on)"},
  "insights_conditions_precipitation_subtitle": "Rain, snow and other precipitation on your dives",
  "@insights_conditions_precipitation_subtitle": {"description": "Subtitle of the precipitation card"},
  "insights_conditions_windSpeed_title": "Wind Speed",
  "@insights_conditions_windSpeed_title": {"description": "Title of the card counting dives per wind-speed band"},
  "insights_conditions_windSpeed_subtitle": "How your dives split across wind speed bands",
  "@insights_conditions_windSpeed_subtitle": {"description": "Subtitle of the wind speed card"},
  "insights_conditions_windDirection_title": "Wind Direction",
  "@insights_conditions_windDirection_title": {"description": "Title of the card counting dives per recorded wind direction (compass point)"},
  "insights_conditions_windDirection_subtitle": "Wind direction recorded on your dives",
  "@insights_conditions_windDirection_subtitle": {"description": "Subtitle of the wind direction card"},
  "insights_conditions_humidity_title": "Humidity",
  "@insights_conditions_humidity_title": {"description": "Title of the card counting dives per relative-humidity band"},
  "insights_conditions_humidity_subtitle": "Relative humidity on your dives",
  "@insights_conditions_humidity_subtitle": {"description": "Subtitle of the humidity card"},
  "insights_conditions_surfacePressure_title": "Surface Pressure",
  "@insights_conditions_surfacePressure_title": {"description": "Title of the card counting dives per barometric surface-pressure band"},
  "insights_conditions_surfacePressure_subtitle": "Barometric pressure at the surface on your dives",
  "@insights_conditions_surfacePressure_subtitle": {"description": "Subtitle of the surface pressure card"},
  "insights_conditions_currentStrength_title": "Current Strength",
  "@insights_conditions_currentStrength_title": {"description": "Title of the card showing the share of dives per current strength (none to strong)"},
  "insights_conditions_currentStrength_subtitle": "How strong the current was on your dives",
  "@insights_conditions_currentStrength_subtitle": {"description": "Subtitle of the current strength card"},
  "insights_conditions_currentDirection_title": "Current Direction",
  "@insights_conditions_currentDirection_title": {"description": "Title of the card counting dives per recorded current direction (compass point)"},
  "insights_conditions_currentDirection_subtitle": "Current direction recorded on your dives",
  "@insights_conditions_currentDirection_subtitle": {"description": "Subtitle of the current direction card"},
  "insights_conditions_swellHeight_title": "Swell Height",
  "@insights_conditions_swellHeight_title": {"description": "Title of the card counting dives per swell-height band"},
  "insights_conditions_swellHeight_subtitle": "How your dives split across swell heights",
  "@insights_conditions_swellHeight_subtitle": {"description": "Subtitle of the swell height card"},
  "insights_conditions_altitude_title": "Altitude",
  "@insights_conditions_altitude_title": {"description": "Title of the card counting dives per altitude group (sea level, altitude group 1 and so on)"},
  "insights_conditions_altitude_subtitle": "Dives by altitude group",
  "@insights_conditions_altitude_subtitle": {"description": "Subtitle of the altitude card"},
  "insights_conditions_exitMethod_title": "Exit Method",
  "@insights_conditions_exitMethod_title": {"description": "Title of the card counting dives per exit method (ladder, shore and so on)"},
  "insights_conditions_exitMethod_subtitle": "How you left the water",
  "@insights_conditions_exitMethod_subtitle": {"description": "Subtitle of the exit method card"},
```

Before inserting, check how `app_en.arb` writes neighbouring `@` entries (multi-line or one-line) and match that layout.

- [ ] **Step 2: Translate into all ten locales**

For each of ar, de, es, fr, he, hu, it, nl, pt, zh, write the 34 keys (values only, no `@` entries) and insert them before `"insights_conditions_waterTempBands_title"` in that locale's ARB with a python3.14 script that inserts lines textually, builds each line as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, and asserts `json.loads` of the result parses. Translation rules:
- Keep `{recorded}`, `{total}`, `{chartTitle}`, `{description}` verbatim, and the ICU plural with the `one{...}` and `other{...}` categories (add `few`/`many`/`two`/`zero` categories where the locale's CLDR rules need them, as neighbouring plural keys in that ARB do).
- Reuse each locale's existing terms from the same ARB: the word for "dive" from `insights_summary_tagUsage_diveCount`, the card style of `insights_conditions_waterTempBands_title`/`_subtitle`, and the weather terms already used in `enum_cloudCover_*`, `enum_precipitation_*`, `diveLog_detail_label_windSpeed`, `diveLog_detail_label_humidity`, `diveLog_detail_label_surfacePressure`, `diveLog_detail_label_swellHeight`, `diveLog_detail_label_currentStrength`, `diveLog_detail_label_exitMethod`, `diveLog_detail_label_altitude`.
- Match accent usage of the neighbouring `insights_conditions_*` keys in fr and hu.

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n`
Expected: no "untranslated message" lines naming any `insights_conditions_` key.

Run: `grep -A2 "get insights_conditions_cloudCover_title" lib/l10n/arb/app_localizations_de.dart`
Expected: a German string, not "Cloud Cover".

Run: `git diff --numstat lib/l10n/arb/*.arb`
Expected: the ten locale ARBs each add the same number of lines; explain any that differ.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(insights): strings for weather and conditions statistics"
```

---

### Task 6: Reusable condition cards

**Files:**
- Create: `lib/features/insights/presentation/formatters/condition_band_label.dart`
- Create: `lib/features/insights/presentation/widgets/conditions/conditions_card_parts.dart` (`ConditionsGroupHeader`, `ConditionsCoverageLine`)
- Create: `lib/features/insights/presentation/widgets/conditions/conditions_band_card.dart`
- Create: `lib/features/insights/presentation/widgets/conditions/conditions_category_card.dart`
- Test: `test/features/insights/presentation/formatters/condition_band_label_test.dart`
- Test: `test/features/insights/presentation/widgets/conditions/conditions_cards_test.dart`

**Interfaces:**
- Consumes: Task 2's `BandStat`, `CategoryStat`; Task 5's strings.
- Produces:
  - `String conditionBandLabel({required double? lower, required double? upper})`
  - `ConditionsGroupHeader({required String title, bool isFirst = false})`
  - `ConditionsCoverageLine({required int recorded, required int total})`
  - `ConditionsBandCard({required String title, required String subtitle, required BandStat stat, required int totalDives, required String unitSymbol, required Color barColor})`
  - `enum ConditionsChartKind { pie, bar }`
  - `ConditionsCategoryCard<T extends Enum>({required String title, required String subtitle, required CategoryStat<T> stat, required int totalDives, required String Function(T) labelOf, required ConditionsChartKind kind, Color Function(T)? colorOf, Color? barColor})`
  - Both cards render `SizedBox.shrink()` when `stat.isEmpty`, and otherwise a `StatSectionCard` with 16 px top padding.

- [ ] **Step 1: Write the failing label test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/formatters/condition_band_label.dart';

void main() {
  test('open-below, closed and open-above bands', () {
    expect(conditionBandLabel(lower: null, upper: 10), '<10');
    expect(conditionBandLabel(lower: 10, upper: 20), '10-20');
    expect(conditionBandLabel(lower: 30, upper: null), '30+');
  });

  test('keeps a fractional edge and drops a whole one\'s decimals', () {
    expect(conditionBandLabel(lower: 0.5, upper: 1), '0.5-1');
    expect(conditionBandLabel(lower: 29.5, upper: 30.1), '29.5-30.1');
  });
}
```

- [ ] **Step 2: Write the failing card tests**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  const bands = BandStat(
    bands: [
      (lower: null, upper: 10.0, count: 1),
      (lower: 10.0, upper: null, count: 2),
    ],
    recorded: 3,
  );

  testWidgets('band card shows its bars and coverage line', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Wind Speed',
        subtitle: 'sub',
        stat: bands,
        totalDives: 10,
        unitSymbol: 'km/h',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Wind Speed'), findsOneWidget);
    expect(find.text('<10'), findsOneWidget);
    expect(find.text('10+'), findsOneWidget);
    expect(find.text('Based on 3 of 10 dives'), findsOneWidget);
  });

  testWidgets('band card is hidden when nothing is recorded', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Wind Speed',
        subtitle: 'sub',
        stat: BandStat(bands: [], recorded: 0),
        totalDives: 10,
        unitSymbol: 'km/h',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Wind Speed'), findsNothing);
  });

  testWidgets('coverage line uses the singular for one dive', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Humidity',
        subtitle: 'sub',
        stat: BandStat(
          bands: [(lower: null, upper: null, count: 1)],
          recorded: 1,
        ),
        totalDives: 1,
        unitSymbol: '%',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Based on 1 of 1 dive'), findsOneWidget);
  });

  testWidgets('category pie labels values and colors by value', (
    tester,
  ) async {
    await pump(
      tester,
      ConditionsCategoryCard<CloudCover>(
        title: 'Cloud Cover',
        subtitle: 'sub',
        stat: const CategoryStat(
          counts: [
            (value: CloudCover.clear, count: 3),
            (value: CloudCover.overcast, count: 1),
          ],
          recorded: 4,
        ),
        totalDives: 8,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.pie,
        colorOf: (v) => v == CloudCover.clear ? Colors.amber : Colors.grey,
      ),
    );
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.map((s) => s.title), ['75%', '25%']);
    expect(chart.data.sections.map((s) => s.color), [
      Colors.amber,
      Colors.grey,
    ]);
    expect(find.text('clear'), findsOneWidget);
    expect(find.text('Based on 4 of 8 dives'), findsOneWidget);
  });

  testWidgets('category bar card is hidden when nothing is recorded', (
    tester,
  ) async {
    await pump(
      tester,
      ConditionsCategoryCard<Precipitation>(
        title: 'Precipitation',
        subtitle: 'sub',
        stat: const CategoryStat(counts: [], recorded: 0),
        totalDives: 8,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.bar,
      ),
    );
    expect(find.text('Precipitation'), findsNothing);
  });

  testWidgets('category bar lists categories in the given order', (
    tester,
  ) async {
    await pump(
      tester,
      ConditionsCategoryCard<Precipitation>(
        title: 'Precipitation',
        subtitle: 'sub',
        stat: const CategoryStat(
          counts: [
            (value: Precipitation.none, count: 1),
            (value: Precipitation.rain, count: 3),
          ],
          recorded: 4,
        ),
        totalDives: 4,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.bar,
      ),
    );
    final none = tester.getTopLeft(find.text('none'));
    final rain = tester.getTopLeft(find.text('rain'));
    expect(none.dy, lessThan(rain.dy));
  });
}
```

The bar-order test assumes `HorizontalCategoryBarChart` lays bars top to bottom in list order; read `horizontal_category_bar_chart.dart` first and, if it sorts, assert the order it promises instead.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/insights/presentation/formatters/condition_band_label_test.dart test/features/insights/presentation/widgets/conditions/`
Expected: FAIL, files do not exist.

- [ ] **Step 4: Write the label formatter**

```dart
import 'package:submersion/core/utils/number_display.dart';

/// Label for one condition band: "<10", "10-20" or "30+", in the unit the
/// bands were defined in (issue #3118). A whole edge prints without decimals
/// and a fractional one keeps its single decimal, in the locale's separator.
/// The unit symbol is left to the caller, which puts it on the axis.
String conditionBandLabel({required double? lower, required double? upper}) {
  String edge(double value) => localiseDecimalText(
    value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1),
  );
  if (lower == null) return '<${edge(upper!)}';
  if (upper == null) return '${edge(lower)}+';
  return '${edge(lower)}-${edge(upper)}';
}
```

- [ ] **Step 5: Write `conditions_card_parts.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Heading of one group on the Conditions tab (issue #3118).
class ConditionsGroupHeader extends StatelessWidget {
  const ConditionsGroupHeader({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  final String title;

  /// The first group sits at the top of the page and needs no gap above it.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// "Based on 42 of 310 dives" under a condition chart.
class ConditionsCoverageLine extends StatelessWidget {
  const ConditionsCoverageLine({
    super.key,
    required this.recorded,
    required this.total,
  });

  final int recorded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        context.l10n.insights_conditions_coverage(recorded, total),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
```

If the generated `insights_conditions_coverage` takes its arguments in another order (gen-l10n follows the `@placeholders` map order), call it in that order; the "Based on 3 of 10 dives" test catches a swap.

- [ ] **Step 6: Write `conditions_band_card.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/formatters/condition_band_label.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives per band of a numeric condition, with its coverage line (issue
/// #3118). Renders nothing when no dive has the value.
class ConditionsBandCard extends StatelessWidget {
  const ConditionsBandCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.totalDives,
    required this.unitSymbol,
    required this.barColor,
  });

  final String title;
  final String subtitle;
  final BandStat stat;
  final int totalDives;

  /// Shown once on the x-axis, so each tick carries just the numbers.
  final String unitSymbol;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (stat.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final data = [
      for (final band in stat.bands)
        (
          label: conditionBandLabel(lower: band.lower, upper: band.upper),
          count: band.count,
        ),
    ];
    final description = data
        .map(
          (d) =>
              '${d.label}$unitSymbol: ${l10n.insights_summary_tagUsage_diveCount(d.count)}',
        )
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StatSectionCard(
        title: title,
        subtitle: subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: l10n.insights_conditions_chart_semanticLabel(
                title,
                description,
              ),
              child: CategoryBarChart(
                data: data,
                barColor: barColor,
                valueFormatter: l10n.insights_summary_tagUsage_diveCount,
                xAxisLabel: unitSymbol,
              ),
            ),
            ConditionsCoverageLine(recorded: stat.recorded, total: totalDives),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Write `conditions_category_card.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How a categorical condition is drawn: a pie for a short ordinal scale
/// (cloud cover, current strength), horizontal bars for longer lists whose
/// labels need room (precipitation, compass directions, methods).
enum ConditionsChartKind { pie, bar }

/// Dives per value of a categorical condition, with its coverage line (issue
/// #3118). Renders nothing when no dive has the value.
class ConditionsCategoryCard<T extends Enum> extends StatelessWidget {
  const ConditionsCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.totalDives,
    required this.labelOf,
    required this.kind,
    this.colorOf,
    this.barColor,
  });

  final String title;
  final String subtitle;
  final CategoryStat<T> stat;
  final int totalDives;
  final String Function(T) labelOf;
  final ConditionsChartKind kind;

  /// Pie slice color per value, so a value keeps its color whatever its
  /// share. Null uses the chart's default palette.
  final Color Function(T)? colorOf;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    if (stat.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final description = stat.counts
        .map(
          (c) =>
              '${labelOf(c.value)}: ${l10n.insights_summary_tagUsage_diveCount(c.count)}',
        )
        .join(', ');
    final chart = switch (kind) {
      ConditionsChartKind.pie => DistributionPieChart(
        data: [
          for (final c in stat.counts)
            DistributionSegment(
              label: labelOf(c.value),
              count: c.count,
              percentage: c.count / stat.recorded * 100,
            ),
        ],
        colors: colorOf == null
            ? null
            : [for (final c in stat.counts) colorOf!(c.value)],
      ),
      ConditionsChartKind.bar => HorizontalCategoryBarChart(
        data: [
          for (final c in stat.counts)
            (label: labelOf(c.value), count: c.count),
        ],
        barColor: barColor,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StatSectionCard(
        title: title,
        subtitle: subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: l10n.insights_conditions_chart_semanticLabel(
                title,
                description,
              ),
              child: chart,
            ),
            ConditionsCoverageLine(recorded: stat.recorded, total: totalDives),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/insights/presentation/formatters/condition_band_label_test.dart test/features/insights/presentation/widgets/conditions/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/insights/presentation/formatters/condition_band_label.dart lib/features/insights/presentation/widgets/conditions/ test/features/insights/presentation/formatters/condition_band_label_test.dart test/features/insights/presentation/widgets/conditions/
git commit -m "feat(insights): band and category cards for condition statistics"
```

---

### Task 7: Group widgets

**Files:**
- Create: `lib/features/insights/presentation/widgets/conditions/surface_weather_group.dart`
- Create: `lib/features/insights/presentation/widgets/conditions/water_movement_group.dart`
- Create: `lib/features/insights/presentation/widgets/conditions/site_access_condition_cards.dart` (`AltitudeConditionsCard`, `ExitMethodConditionsCard`)
- Test: `test/features/insights/presentation/widgets/conditions/conditions_groups_test.dart`

**Interfaces:**
- Consumes: Task 4's `conditionsStatsProvider`, `TrendChartIds.airTemp`; Task 6's cards and parts; existing `localizedName` extensions in `dive_log/presentation/widgets/environment_enum_display.dart` (`CloudCover`, `Precipitation`, `CurrentDirection`, `CurrentStrength`, `EntryMethod`) and `dive_log/presentation/formatters/altitude_group_label.dart` (`AltitudeGroup`).
- Produces: `const SurfaceWeatherGroup()`, `const WaterMovementGroup()`, `const AltitudeConditionsCard()`, `const ExitMethodConditionsCard()`.
- Loading and error: Surface & weather and Water movement each show their header plus one spinner while loading, and their header plus one `StatEmptyState` with `insights_conditions_weather_error` on failure. The altitude and exit cards sit inside the always-visible Site & access group and render nothing while loading or on failure, since the two weather groups above already report the shared query's failure.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/site_access_condition_cards.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/surface_weather_group.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/water_movement_group.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<List<ConditionsRow>> Function() rows,
  ) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conditionsRowsProvider.overrideWith((ref) => rows()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SurfaceWeatherGroup(),
                  WaterMovementGroup(),
                  AltitudeConditionsCard(),
                  ExitMethodConditionsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ConditionsRow row(String id, {
    double? airTemp,
    CloudCover? cloudCover,
    CurrentStrength? currentStrength,
    double? altitude,
    EntryMethod? exitMethod,
  }) => ConditionsRow(
    diveId: id,
    dateTime: DateTime.utc(2026, 1, 1),
    airTemp: airTemp,
    cloudCover: cloudCover,
    currentStrength: currentStrength,
    altitude: altitude,
    exitMethod: exitMethod,
  );

  testWidgets('groups with nothing recorded are hidden entirely', (
    tester,
  ) async {
    await pump(tester, () async => [row('a'), row('b')]);
    expect(find.text('Surface & Weather'), findsNothing);
    expect(find.text('Water Movement'), findsNothing);
    expect(find.text('Altitude'), findsNothing);
    expect(find.text('Exit Method'), findsNothing);
  });

  testWidgets('shows only the cards that have data', (tester) async {
    await pump(
      tester,
      () async => [
        row('a', cloudCover: CloudCover.clear),
        row('b', currentStrength: CurrentStrength.light),
        row('c'),
      ],
    );
    expect(find.text('Surface & Weather'), findsOneWidget);
    expect(find.text('Cloud Cover'), findsOneWidget);
    expect(find.text('Precipitation'), findsNothing);
    expect(find.text('Air Temperature Over Time'), findsNothing);
    expect(find.text('Water Movement'), findsOneWidget);
    expect(find.text('Current Strength'), findsOneWidget);
    expect(find.text('Swell Height'), findsNothing);
    expect(find.text('Based on 1 of 3 dives'), findsNWidgets(2));
  });

  testWidgets('air temperature shows trend and bands', (tester) async {
    await pump(tester, () async => [row('a', airTemp: 22)]);
    expect(find.text('Air Temperature Over Time'), findsOneWidget);
    expect(find.text('Dives by Air Temperature'), findsOneWidget);
  });

  testWidgets('altitude and exit method cards show their localized values', (
    tester,
  ) async {
    await pump(
      tester,
      () async => [row('a', altitude: 1200, exitMethod: EntryMethod.ladder)],
    );
    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('Altitude Group 2'), findsOneWidget);
    expect(find.text('Exit Method'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('a failed query shows one error per weather group', (
    tester,
  ) async {
    await pump(tester, () async => throw StateError('boom'));
    expect(
      find.text('Failed to load weather and conditions data'),
      findsNWidgets(2),
    );
    expect(find.text('Surface & Weather'), findsOneWidget);
    expect(find.text('Water Movement'), findsOneWidget);
    expect(find.text('Altitude'), findsNothing);
  });
}
```

The 'Ladder' and 'Altitude Group 2' strings are the English values of `enum_entryMethod_ladder` and `enum_altitudeGroup_group2`; check `app_en.arb` and adjust the expectation if the ladder label differs.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/presentation/widgets/conditions/conditions_groups_test.dart`
Expected: FAIL, the group widgets do not exist.

- [ ] **Step 3: Write `surface_weather_group.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Surface & weather group of the Conditions tab (issue #3118): air
/// temperature, cloud, precipitation, wind, humidity and surface pressure.
/// Hidden when none of them is recorded on any dive in the filter.
class SurfaceWeatherGroup extends ConsumerWidget {
  const SurfaceWeatherGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final header = ConditionsGroupHeader(
      title: l10n.insights_conditions_group_surfaceWeather,
    );
    return ref
        .watch(conditionsStatsProvider)
        .when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              StatEmptyState(
                icon: Icons.error_outline,
                message: l10n.insights_conditions_weather_error,
              ),
            ],
          ),
          data: (stats) {
            final hasAny = [
              stats.airTemp.isEmpty,
              stats.cloudCover.isEmpty,
              stats.precipitation.isEmpty,
              stats.windSpeed.isEmpty,
              stats.windDirection.isEmpty,
              stats.humidity.isEmpty,
              stats.surfacePressure.isEmpty,
            ].contains(false);
            if (!hasAny) return const SizedBox.shrink();
            final units = UnitFormatter(ref.watch(settingsProvider));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                ..._cards(context, stats, units),
              ],
            );
          },
        );
  }

  List<Widget> _cards(
    BuildContext context,
    ConditionsStats stats,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    final total = stats.totalDives;
    return [
      if (!stats.airTemp.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TrendChartSection(
            chartId: TrendChartIds.airTemp,
            onDiveSelected: (diveId) => context.push('/dives/$diveId'),
            title: l10n.insights_conditions_airTempTrend_title,
            subtitle: l10n.insights_conditions_airTempTrend_subtitle,
            pointsAsync: AsyncData(stats.airTempTrend),
            errorMessage: l10n.insights_conditions_airTempTrend_error,
            lineColor: Colors.deepOrange,
            valueFormatter: (value) => units.formatTemperature(value),
            // A per-year rate is a difference: no 32-degree offset in F.
            rateFormatter: (value) => units.formatTemperatureDelta(value),
          ),
        ),
      ConditionsBandCard(
        title: l10n.insights_conditions_airTempBands_title,
        subtitle: l10n.insights_conditions_airTempBands_subtitle,
        stat: stats.airTemp,
        totalDives: total,
        unitSymbol: units.temperatureSymbol,
        barColor: Colors.deepOrange.shade300,
      ),
      ConditionsCategoryCard<CloudCover>(
        title: l10n.insights_conditions_cloudCover_title,
        subtitle: l10n.insights_conditions_cloudCover_subtitle,
        stat: stats.cloudCover,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.pie,
        colorOf: _cloudColor,
      ),
      ConditionsCategoryCard<Precipitation>(
        title: l10n.insights_conditions_precipitation_title,
        subtitle: l10n.insights_conditions_precipitation_subtitle,
        stat: stats.precipitation,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.bar,
        barColor: Colors.indigo.shade300,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_windSpeed_title,
        subtitle: l10n.insights_conditions_windSpeed_subtitle,
        stat: stats.windSpeed,
        totalDives: total,
        unitSymbol: units.windSpeedSymbol,
        barColor: Colors.blueGrey.shade400,
      ),
      ConditionsCategoryCard<CurrentDirection>(
        title: l10n.insights_conditions_windDirection_title,
        subtitle: l10n.insights_conditions_windDirection_subtitle,
        stat: stats.windDirection,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.bar,
        barColor: Colors.blueGrey.shade400,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_humidity_title,
        subtitle: l10n.insights_conditions_humidity_subtitle,
        stat: stats.humidity,
        totalDives: total,
        unitSymbol: '%',
        barColor: Colors.lightBlue.shade400,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_surfacePressure_title,
        subtitle: l10n.insights_conditions_surfacePressure_subtitle,
        stat: stats.surfacePressure,
        totalDives: total,
        unitSymbol: units.surfacePressureSymbol,
        barColor: Colors.purple.shade300,
      ),
    ];
  }

  /// Keyed by value so each sky keeps its color whatever its share.
  static Color _cloudColor(CloudCover value) => switch (value) {
    CloudCover.clear => Colors.amber.shade400,
    CloudCover.partlyCloudy => Colors.lightBlue.shade300,
    CloudCover.mostlyCloudy => Colors.blueGrey.shade300,
    CloudCover.overcast => Colors.grey.shade600,
  };
}
```

- [ ] **Step 4: Write `water_movement_group.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Water movement group of the Conditions tab (issue #3118): current
/// strength, current direction and swell height. Hidden when none of them is
/// recorded on any dive in the filter.
class WaterMovementGroup extends ConsumerWidget {
  const WaterMovementGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final header = ConditionsGroupHeader(
      title: l10n.insights_conditions_group_waterMovement,
    );
    return ref
        .watch(conditionsStatsProvider)
        .when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              StatEmptyState(
                icon: Icons.error_outline,
                message: l10n.insights_conditions_weather_error,
              ),
            ],
          ),
          data: (stats) {
            if (stats.currentStrength.isEmpty &&
                stats.currentDirection.isEmpty &&
                stats.swellHeight.isEmpty) {
              return const SizedBox.shrink();
            }
            final units = UnitFormatter(ref.watch(settingsProvider));
            final total = stats.totalDives;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                ConditionsCategoryCard<CurrentStrength>(
                  title: l10n.insights_conditions_currentStrength_title,
                  subtitle: l10n.insights_conditions_currentStrength_subtitle,
                  stat: stats.currentStrength,
                  totalDives: total,
                  labelOf: (v) => v.localizedName(l10n),
                  kind: ConditionsChartKind.pie,
                  colorOf: _strengthColor,
                ),
                ConditionsCategoryCard<CurrentDirection>(
                  title: l10n.insights_conditions_currentDirection_title,
                  subtitle: l10n.insights_conditions_currentDirection_subtitle,
                  stat: stats.currentDirection,
                  totalDives: total,
                  labelOf: (v) => v.localizedName(l10n),
                  kind: ConditionsChartKind.bar,
                  barColor: Colors.teal.shade400,
                ),
                ConditionsBandCard(
                  title: l10n.insights_conditions_swellHeight_title,
                  subtitle: l10n.insights_conditions_swellHeight_subtitle,
                  stat: stats.swellHeight,
                  totalDives: total,
                  unitSymbol: units.depthSymbol,
                  barColor: Colors.blue.shade400,
                ),
              ],
            );
          },
        );
  }

  /// Calm to strong, light to dark, keyed by value.
  static Color _strengthColor(CurrentStrength value) => switch (value) {
    CurrentStrength.none => Colors.green.shade300,
    CurrentStrength.light => Colors.lightBlue.shade300,
    CurrentStrength.moderate => Colors.orange.shade400,
    CurrentStrength.strong => Colors.red.shade400,
  };
}
```

- [ ] **Step 5: Write `site_access_condition_cards.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives per altitude group, in the Site & access group (issue #3118).
///
/// Renders nothing while loading or on failure: the weather groups above
/// already report the shared query's state, and this group's header stays
/// for the site type and entry method cards.
class AltitudeConditionsCard extends ConsumerWidget {
  const AltitudeConditionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(conditionsStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ConditionsCategoryCard<AltitudeGroup>(
      title: l10n.insights_conditions_altitude_title,
      subtitle: l10n.insights_conditions_altitude_subtitle,
      stat: stats.altitude,
      totalDives: stats.totalDives,
      labelOf: (v) => v.localizedName(l10n),
      kind: ConditionsChartKind.bar,
      barColor: Colors.brown.shade300,
    );
  }
}

/// Dives per exit method, in the Site & access group (issue #3118). The
/// stored value only: exit method has no site fallback.
class ExitMethodConditionsCard extends ConsumerWidget {
  const ExitMethodConditionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(conditionsStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ConditionsCategoryCard<EntryMethod>(
      title: l10n.insights_conditions_exitMethod_title,
      subtitle: l10n.insights_conditions_exitMethod_subtitle,
      stat: stats.exitMethod,
      totalDives: stats.totalDives,
      labelOf: (v) => v.localizedName(l10n),
      kind: ConditionsChartKind.bar,
      barColor: Colors.teal,
    );
  }
}
```

If `AsyncValue.value` rethrows on error in this Riverpod version, use `.valueOrNull` instead; the error test in Step 1 tells.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/insights/presentation/widgets/conditions/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/insights/presentation/widgets/conditions/ test/features/insights/presentation/widgets/conditions/conditions_groups_test.dart
git commit -m "feat(insights): weather, water movement and site access condition groups"
```

---

### Task 8: Regroup the Conditions page

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_conditions_page.dart:34-54` (the `content` column) and `:294` (water temp `rateFormatter`, the follow-up below)
- Modify: the five `test/features/insights/presentation/pages/insights_conditions_*_test.dart` pump helpers (add a `conditionsRowsProvider` override)
- Test: `test/features/insights/presentation/pages/insights_conditions_groups_test.dart`

**Interfaces:**
- Consumes: Task 6's `ConditionsGroupHeader`; Task 7's group widgets and cards; Task 4's `conditionsRowsProvider`.

**Follow-up folded in:** the existing water temperature trend passes `units.formatTemperature` as its `rateFormatter`. A per-year rate is a difference, so in Fahrenheit it gains the 32-degree offset (0.1 °C/yr reads as about 32.2 °F). Switch it to `units.formatTemperatureDelta`, as the air temperature trend does.

- [ ] **Step 1: Write the failing page test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    List<ConditionsRow> rows = const [],
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          visibilityDistributionProvider.overrideWith((ref) async => const []),
          waterTypeDistributionProvider.overrideWith((ref) async => const []),
          siteTypeDistributionProvider.overrideWith((ref) async => const []),
          entryMethodDistributionProvider.overrideWith((ref) async => const []),
          waterTempTrendProvider.overrideWith(
            (ref) async => [
              TrendDataPoint(date: DateTime.utc(2024), value: 20, diveId: 'a'),
              TrendDataPoint(date: DateTime.utc(2026), value: 21, diveId: 'b'),
            ],
          ),
          temperatureByMonthProvider.overrideWith((ref) async => const []),
          waterTempBandDistributionProvider.overrideWith(
            (ref) async => const [],
          ),
          waterTempBandMetricsProvider.overrideWith((ref) async => const []),
          conditionsRowsProvider.overrideWith((ref) async => rows),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsConditionsPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('existing cards sit under the Water and Site & Access headers', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Site & Access'), findsOneWidget);
    expect(topOf(tester, 'Water'), lessThan(topOf(tester, 'Visibility')));
    expect(
      topOf(tester, 'Site & Access'),
      lessThan(topOf(tester, 'Entry Method')),
    );
    expect(
      topOf(tester, 'Dives by Water Temperature'),
      lessThan(topOf(tester, 'Site & Access')),
    );
  });

  testWidgets('weather groups sit between Water and Site & Access', (
    tester,
  ) async {
    await pumpPage(
      tester,
      rows: [
        ConditionsRow(
          diveId: 'a',
          dateTime: DateTime.utc(2026, 1, 1),
          cloudCover: CloudCover.clear,
          currentStrength: CurrentStrength.none,
        ),
      ],
    );
    final weather = topOf(tester, 'Surface & Weather');
    final movement = topOf(tester, 'Water Movement');
    expect(topOf(tester, 'Dives by Water Temperature'), lessThan(weather));
    expect(weather, lessThan(movement));
    expect(movement, lessThan(topOf(tester, 'Site & Access')));
  });

  testWidgets('water temperature rate in F is a difference, not a reading', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    await pumpPage(tester, settings: settings);
    final section = tester.widget<TrendChartSection>(
      find.byWidgetPredicate(
        (w) => w is TrendChartSection && w.chartId == TrendChartIds.waterTemp,
      ),
    );
    // 1 C per year is 1.8 F per year, never 33.8 F.
    expect(section.rateFormatter!(1), '1.8°F');
  });
}
```

Section titles ('Visibility', 'Entry Method', 'Dives by Water Temperature') are the English values of the existing `insights_conditions_*_title` keys; confirm them in `app_en.arb`. If `TrendChartSection.rateFormatter` is not a public field, read the rendered rate label instead after enabling the linear fit.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/presentation/pages/insights_conditions_groups_test.dart`
Expected: FAIL, no group headers and the rate formats as '33.8°F'.

- [ ] **Step 3: Regroup the page**

Add imports:

```dart
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/site_access_condition_cards.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/surface_weather_group.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/water_movement_group.dart';
```

Replace the `children` of the content `Column` with:

```dart
        children: [
          ConditionsGroupHeader(
            title: context.l10n.insights_conditions_group_water,
            isFirst: true,
          ),
          _buildVisibilitySection(context, ref),
          const SizedBox(height: 16),
          _buildWaterTypeSection(context, ref),
          const SizedBox(height: 16),
          _buildTemperatureTrendSection(context, ref, units),
          const SizedBox(height: 16),
          _buildTemperatureSection(context, ref, units),
          const SizedBox(height: 16),
          _buildTemperatureBandSection(context, ref, units),
          // Each new group brings its own header and top spacing, and hides
          // itself when nothing in it is recorded (issue #3118).
          const SurfaceWeatherGroup(),
          const WaterMovementGroup(),
          ConditionsGroupHeader(
            title: context.l10n.insights_conditions_group_siteAccess,
          ),
          _buildSiteTypeSection(context, ref),
          const AltitudeConditionsCard(),
          const SizedBox(height: 16),
          _buildEntryMethodSection(context, ref),
          const ExitMethodConditionsCard(),
        ],
```

- [ ] **Step 4: Fix the water temperature rate formatter**

In `_buildTemperatureTrendSection`, replace

```dart
      rateFormatter: (value) => units.formatTemperature(value),
```

with

```dart
      // A per-year rate is a difference: no 32-degree offset in F.
      rateFormatter: (value) => units.formatTemperatureDelta(value),
```

- [ ] **Step 5: Override the new provider in existing page tests**

In each pump helper of `insights_conditions_not_recorded_test.dart`, `insights_conditions_temperature_test.dart`, `insights_conditions_visibility_test.dart`, `insights_conditions_water_temp_band_metrics_test.dart` and `insights_conditions_water_temp_bands_test.dart`, add to `overrides`:

```dart
          conditionsRowsProvider.overrideWith((ref) async => const []),
```

with the import `package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart`. This keeps those tests off the database for the new groups, which then hide.

- [ ] **Step 6: Run the Insights tests**

Run: `flutter test test/features/insights/`
Expected: PASS. Any other test that renders the Conditions page (for example `insights_page_content_test.dart`) gets the same override if it fails on the new provider.

- [ ] **Step 7: Commit**

```bash
git add lib/features/insights/presentation/pages/insights_conditions_page.dart test/features/insights/presentation/pages/
git commit -m "feat(insights): group the Conditions tab and add weather statistics"
```

---

### Task 9: Full verification

**Files:** none new.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: no changes, or only files from this branch; commit any it rewrites with the task they belong to.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Architecture and shared guards**

Run: `flutter test test/architecture/ test/shared/`
Expected: PASS (new `lib/` files; the dive-date decode and provider-tick guards apply).

- [ ] **Step 4: Insights and l10n tests**

Run: `flutter test test/features/insights/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: File sizes**

Run: `wc -l lib/features/insights/presentation/pages/insights_conditions_page.dart lib/features/insights/presentation/widgets/conditions/*.dart lib/features/insights/domain/conditions/*.dart lib/features/insights/data/repositories/insights_repository_conditions.dart`
Expected: every file under 800 lines.

- [ ] **Step 6: Em dash scan**

Run: `git diff origin/main...HEAD | python3.14 -c "import sys; print(sys.stdin.read().count(chr(0x2014)))"`
Expected: 0.
