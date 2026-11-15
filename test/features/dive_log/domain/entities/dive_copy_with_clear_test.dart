import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// `copyWith` keeps the old value when it is passed null, so emptying a
/// field needs a flag of its own. These are the values the Altitude and
/// Environment cards edit one at a time (issue #4527).
void main() {
  final full = Dive(
    id: 'dive',
    dateTime: DateTime(2024),
    airTemp: 21,
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 1.5,
    surfaceConditions: 'Calm',
    entryMethod: EntryMethod.shore,
    exitMethod: EntryMethod.boat,
    altitude: 1200,
    surfacePressure: 0.87,
    windSpeed: 4,
    windDirection: CurrentDirection.east,
    cloudCover: CloudCover.overcast,
    precipitation: Precipitation.drizzle,
    humidity: 60,
    weatherDescription: 'Clear',
    weatherSource: WeatherSource.openMeteo,
    weatherFetchedAt: DateTime(2024, 1, 2),
    weatherCode: 61,
  );

  // Each entry clears one value and reads it back.
  final cases = <String, (Dive Function(Dive), Object? Function(Dive))>{
    'airTemp': ((d) => d.copyWith(clearAirTemp: true), (d) => d.airTemp),
    'currentDirection': (
      (d) => d.copyWith(clearCurrentDirection: true),
      (d) => d.currentDirection,
    ),
    'currentStrength': (
      (d) => d.copyWith(clearCurrentStrength: true),
      (d) => d.currentStrength,
    ),
    'swellHeight': (
      (d) => d.copyWith(clearSwellHeight: true),
      (d) => d.swellHeight,
    ),
    'surfaceConditions': (
      (d) => d.copyWith(clearSurfaceConditions: true),
      (d) => d.surfaceConditions,
    ),
    'entryMethod': (
      (d) => d.copyWith(clearEntryMethod: true),
      (d) => d.entryMethod,
    ),
    'exitMethod': (
      (d) => d.copyWith(clearExitMethod: true),
      (d) => d.exitMethod,
    ),
    'altitude': ((d) => d.copyWith(clearAltitude: true), (d) => d.altitude),
    'surfacePressure': (
      (d) => d.copyWith(clearSurfacePressure: true),
      (d) => d.surfacePressure,
    ),
    'windSpeed': ((d) => d.copyWith(clearWindSpeed: true), (d) => d.windSpeed),
    'windDirection': (
      (d) => d.copyWith(clearWindDirection: true),
      (d) => d.windDirection,
    ),
    'cloudCover': (
      (d) => d.copyWith(clearCloudCover: true),
      (d) => d.cloudCover,
    ),
    'precipitation': (
      (d) => d.copyWith(clearPrecipitation: true),
      (d) => d.precipitation,
    ),
    'humidity': ((d) => d.copyWith(clearHumidity: true), (d) => d.humidity),
    'weatherDescription': (
      (d) => d.copyWith(clearWeatherDescription: true),
      (d) => d.weatherDescription,
    ),
    'weatherSource': (
      (d) => d.copyWith(clearWeatherSource: true),
      (d) => d.weatherSource,
    ),
    'weatherFetchedAt': (
      (d) => d.copyWith(clearWeatherFetchedAt: true),
      (d) => d.weatherFetchedAt,
    ),
    'weatherCode': (
      (d) => d.copyWith(clearWeatherCode: true),
      (d) => d.weatherCode,
    ),
  };

  test('the table covers all eighteen values', () {
    expect(cases, hasLength(18));
  });

  for (final entry in cases.entries) {
    test('clear ${entry.key} sets it to null and nothing else', () {
      final (clear, read) = entry.value;
      expect(read(full), isNotNull);

      final cleared = clear(full);

      expect(read(cleared), isNull);
      for (final other in cases.entries.where((e) => e.key != entry.key)) {
        expect(
          other.value.$2(cleared),
          other.value.$2(full),
          reason: '${other.key} must be left alone',
        );
      }
    });
  }

  test('a clear flag wins over a value passed with it', () {
    expect(full.copyWith(altitude: 5, clearAltitude: true).altitude, isNull);
  });

  test('a value passed without the flag still replaces the old one', () {
    expect(full.copyWith(altitude: 5).altitude, 5);
  });

  test('copyWith with no flags keeps every value', () {
    expect(full.copyWith(), full);
  });
}
