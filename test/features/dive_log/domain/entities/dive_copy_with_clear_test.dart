import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// `copyWith` keeps the old value when it is passed null, so emptying a
/// field needs a flag of its own. These are the values the Altitude,
/// Environment and Details cards edit one at a time (issue #4527).
void main() {
  final trip = Trip(
    id: 'trip',
    name: 'Red Sea',
    startDate: DateTime(2024),
    endDate: DateTime(2024, 1, 7),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final center = DiveCenter(
    id: 'center',
    name: 'Blue Hole Divers',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
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
    diveCenter: center,
    trip: trip,
    tripId: trip.id,
    visibility: Visibility.good,
    visibilityMeters: 12,
    visibilityMinMeters: 10,
    visibilityMaxMeters: 20,
    diveOperator: 'Emperor',
    boatName: 'Elite',
    boatCaptain: 'Sam',
    waterType: WaterType.salt,
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
    'diveCenter': (
      (d) => d.copyWith(clearDiveCenter: true),
      (d) => d.diveCenter,
    ),
    'trip': ((d) => d.copyWith(clearTrip: true), (d) => d.trip),
    'tripId': ((d) => d.copyWith(clearTripId: true), (d) => d.tripId),
    'visibility': (
      (d) => d.copyWith(clearVisibility: true),
      (d) => d.visibility,
    ),
    'visibilityMeters': (
      (d) => d.copyWith(clearVisibilityMeters: true),
      (d) => d.visibilityMeters,
    ),
    'visibilityMinMeters': (
      (d) => d.copyWith(clearVisibilityMinMeters: true),
      (d) => d.visibilityMinMeters,
    ),
    'visibilityMaxMeters': (
      (d) => d.copyWith(clearVisibilityMaxMeters: true),
      (d) => d.visibilityMaxMeters,
    ),
    'diveOperator': (
      (d) => d.copyWith(clearDiveOperator: true),
      (d) => d.diveOperator,
    ),
    'boatName': ((d) => d.copyWith(clearBoatName: true), (d) => d.boatName),
    'boatCaptain': (
      (d) => d.copyWith(clearBoatCaptain: true),
      (d) => d.boatCaptain,
    ),
    'waterType': ((d) => d.copyWith(clearWaterType: true), (d) => d.waterType),
  };

  test('the table covers all twenty-nine values', () {
    expect(cases, hasLength(29));
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

  test('clearing the trip needs both flags', () {
    final cleared = full.copyWith(clearTrip: true, clearTripId: true);
    expect(cleared.trip, isNull);
    expect(cleared.tripId, isNull);
    // The trap: the writer saves `tripId ?? trip?.id`, so clearing the trip
    // alone would put the old one back.
    expect(full.copyWith(clearTrip: true).tripId, trip.id);
  });

  test('a clear flag wins over a water type passed with it', () {
    expect(
      full.copyWith(waterType: WaterType.fresh, clearWaterType: true).waterType,
      isNull,
    );
  });

  test('a value passed without the flag still replaces the old one', () {
    expect(full.copyWith(altitude: 5).altitude, 5);
  });

  test('copyWith with no flags keeps every value', () {
    expect(full.copyWith(), full);
  });
}
