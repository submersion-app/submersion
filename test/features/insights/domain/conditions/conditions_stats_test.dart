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
