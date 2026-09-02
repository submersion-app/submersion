import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';

void main() {
  TripDayWeather weather({
    double? airTemp,
    CloudCover? cloudCover,
    Precipitation? precipitation,
    double? windSpeed,
    double? humidity,
  }) {
    final now = DateTime(2026, 3, 9);
    return TripDayWeather(
      id: 'w1',
      tripId: 'trip-1',
      date: DateTime(2026, 3, 8),
      latitude: 12.16,
      longitude: -68.28,
      airTemp: airTemp,
      cloudCover: cloudCover,
      precipitation: precipitation,
      windSpeed: windSpeed,
      humidity: humidity,
      fetchedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('tripDayMillis', () {
    test('is the calendar day in UTC, not the device local midnight', () {
      // The key must not depend on where the device is standing. A local
      // DateTime(y, m, d) has a different epoch value in every timezone, so
      // two devices would derive different row ids for the same calendar day
      // and never converge.
      expect(
        tripDayMillis(DateTime(2026, 3, 8, 17, 30)),
        DateTime.utc(2026, 3, 8).millisecondsSinceEpoch,
      );
    });

    test('takes the calendar fields as given, never shifting the day', () {
      // Guards the wrong fix: converting with toUtc() would move a late
      // evening local time onto the following calendar day.
      expect(
        tripDayMillis(DateTime(2026, 3, 8, 23, 59)),
        tripDayMillis(DateTime.utc(2026, 3, 8, 0, 1)),
      );
    });

    test('distinct days stay distinct', () {
      expect(
        tripDayMillis(DateTime(2026, 3, 8)),
        isNot(tripDayMillis(DateTime(2026, 3, 9))),
      );
    });
  });

  group('tripDayWeatherRowId', () {
    test('is stable for one calendar day regardless of the time given', () {
      expect(
        tripDayWeatherRowId(
          tripId: 't1',
          dayMillis: tripDayMillis(DateTime(2026, 3, 8, 1)),
        ),
        tripDayWeatherRowId(
          tripId: 't1',
          dayMillis: tripDayMillis(DateTime(2026, 3, 8, 22)),
        ),
      );
    });
  });

  group('hasRenderableWeather', () {
    test('air temperature alone counts', () {
      expect(weather(airTemp: 24).hasRenderableWeather, isTrue);
    });

    test('cloud cover alone counts', () {
      expect(
        weather(cloudCover: CloudCover.overcast).hasRenderableWeather,
        isTrue,
      );
    });

    test('active precipitation alone counts', () {
      expect(
        weather(precipitation: Precipitation.rain).hasRenderableWeather,
        isTrue,
      );
    });

    test('precipitation none alone does NOT count', () {
      // WeatherMapper.mapPrecipitation never returns null: a missing reading
      // becomes Precipitation.none, so `none` is not evidence that the fetch
      // resolved anything. weatherIconFor gives it no glyph either.
      expect(
        weather(precipitation: Precipitation.none).hasRenderableWeather,
        isFalse,
      );
    });

    test('wind and humidity alone do NOT count', () {
      // Stored, but never drawn in the day header badge.
      expect(
        weather(
          windSpeed: 6.5,
          humidity: 70,
          precipitation: Precipitation.none,
        ).hasRenderableWeather,
        isFalse,
      );
    });

    test('an empty result does not count', () {
      expect(weather().hasRenderableWeather, isFalse);
    });
  });

  group('toStoryWeather', () {
    test('carries only the three fields the header renders', () {
      final story = weather(
        airTemp: 24,
        cloudCover: CloudCover.clear,
        precipitation: Precipitation.none,
        windSpeed: 6.5,
        humidity: 70,
      ).toStoryWeather();

      expect(story.airTemp, 24);
      expect(story.cloudCover, CloudCover.clear);
      expect(story.precipitation, Precipitation.none);
    });
  });

  group('copyWith', () {
    test('clears a nullable field when passed null explicitly', () {
      final cleared = weather(airTemp: 24).copyWith(airTemp: null);

      expect(cleared.airTemp, isNull);
    });

    test('leaves an untouched field alone', () {
      final same = weather(airTemp: 24).copyWith(latitude: 0);

      expect(same.airTemp, 24);
      expect(same.latitude, 0);
    });
  });
}
