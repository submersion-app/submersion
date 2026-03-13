import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive weather fields', () {
    test('default weather fields are null', () {
      final dive = Dive(id: 'test-1', dateTime: DateTime(2024, 6, 15));
      expect(dive.windSpeed, isNull);
      expect(dive.windDirection, isNull);
      expect(dive.cloudCover, isNull);
      expect(dive.precipitation, isNull);
      expect(dive.humidity, isNull);
      expect(dive.weatherDescription, isNull);
      expect(dive.weatherSource, isNull);
      expect(dive.weatherFetchedAt, isNull);
    });

    test('can construct Dive with weather fields', () {
      final fetchedAt = DateTime(2024, 6, 15, 10, 30);
      final dive = Dive(
        id: 'test-2',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        windDirection: CurrentDirection.northEast,
        cloudCover: CloudCover.partlyCloudy,
        precipitation: Precipitation.none,
        humidity: 75.0,
        weatherDescription: 'Warm and sunny',
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: fetchedAt,
      );

      expect(dive.windSpeed, 5.5);
      expect(dive.windDirection, CurrentDirection.northEast);
      expect(dive.cloudCover, CloudCover.partlyCloudy);
      expect(dive.precipitation, Precipitation.none);
      expect(dive.humidity, 75.0);
      expect(dive.weatherDescription, 'Warm and sunny');
      expect(dive.weatherSource, WeatherSource.openMeteo);
      expect(dive.weatherFetchedAt, fetchedAt);
    });

    test('copyWith preserves weather fields when not overridden', () {
      final dive = Dive(
        id: 'test-3',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        cloudCover: CloudCover.overcast,
      );

      final copy = dive.copyWith(notes: 'Updated');
      expect(copy.windSpeed, 5.5);
      expect(copy.cloudCover, CloudCover.overcast);
      expect(copy.notes, 'Updated');
    });

    test('copyWith can override weather fields', () {
      final dive = Dive(
        id: 'test-4',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
        cloudCover: CloudCover.overcast,
      );

      final copy = dive.copyWith(windSpeed: 10.0, cloudCover: CloudCover.clear);
      expect(copy.windSpeed, 10.0);
      expect(copy.cloudCover, CloudCover.clear);
    });

    test('Equatable includes weather fields', () {
      final dive1 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
      );
      final dive2 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 5.5,
      );
      final dive3 = Dive(
        id: 'test-5',
        dateTime: DateTime(2024, 6, 15),
        windSpeed: 10.0,
      );

      expect(dive1, equals(dive2));
      expect(dive1, isNot(equals(dive3)));
    });
  });
}
