import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// A full Open-Meteo hourly payload for one day, in the shape WeatherMapper
/// expects (copied from the deleted surface_day_weather_provider_test).
http.Response weatherResponse({double noonTemp = 29.0, num cloud = 95}) =>
    http.Response(
      jsonEncode({
        'hourly': {
          'time': ['2026-03-08T09:00', '2026-03-08T12:00'],
          'temperature_2m': [24.0, noonTemp],
          'relative_humidity_2m': [80.0, 70.0],
          'precipitation': [0.0, 0.0],
          'cloud_cover': [10.0, cloud],
          'wind_speed_10m': [8.0, 12.0],
          'wind_direction_10m': [30.0, 45.0],
          'surface_pressure': [1012.0, 1011.0],
          'weathercode': [0, 0],
        },
      }),
      200,
    );

/// Nothing the day header could render: humidity and pressure only.
http.Response unrenderableResponse() => http.Response(
  jsonEncode({
    'hourly': {
      'time': ['2026-03-08T12:00'],
      'temperature_2m': [null],
      'relative_humidity_2m': [70.0],
      'precipitation': [null],
      'cloud_cover': [null],
      'wind_speed_10m': [null],
      'wind_direction_10m': [null],
      'surface_pressure': [1011.0],
      'weathercode': [null],
    },
  }),
  200,
);

/// Records upserts instead of touching a database.
class FakeTripDayWeatherRepository implements TripDayWeatherRepository {
  FakeTripDayWeatherRepository({this.stored = const {}});

  final Map<int, TripDayWeather> stored;
  final List<TripDayWeather> upserts = [];

  @override
  Future<Map<int, TripDayWeather>> getForTrip(String tripId) async => stored;

  @override
  Future<void> upsert(TripDayWeather weather) async => upserts.add(weather);

  @override
  Future<void> deleteByTripId(String tripId) async {}

  @override
  Stream<void> watchWeatherChanges() => const Stream.empty();
}

void main() {
  /// Two past days with no dives, and one map point on day 0 that day 1
  /// borrows through nearestPointForDay.
  TripStory twoDayStory() => TripStory(
    trip: Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 9),
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    ),
    days: [
      TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 1,
        kind: TripStoryDayKind.past,
      ),
      TripStoryDay(
        date: DateTime(2026, 3, 9),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
      ),
    ],
    checklist: const TripStoryChecklistSummary(done: 0, total: 0),
    mapGeometry: const TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.16,
          longitude: -68.28,
          dayIndex: 0,
          label: 'Site',
        ),
      ],
    ),
  );

  ProviderContainer containerWith({
    required http.Client client,
    required FakeTripDayWeatherRepository repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        weatherHttpClientProvider.overrideWithValue(client),
        tripDayWeatherRepositoryProvider.overrideWithValue(repository),
        tripStoryProvider('trip-1').overrideWith((ref) async => twoDayStory()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('tripDayWeatherBackfillProvider', () {
    test('fetches each target once and stores the result', () async {
      var calls = 0;
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((request) async {
          calls++;
          // Local noon at the coordinate, not the archive's GMT midnight.
          expect(request.url.queryParameters['timezone'], 'auto');
          return weatherResponse();
        }),
        repository: repository,
      );

      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(calls, 2);
      expect(repository.upserts, hasLength(2));
      final first = repository.upserts.first;
      expect(first.tripId, 'trip-1');
      expect(first.date, DateTime(2026, 3, 8));
      expect(first.airTemp, 29.0);
      expect(first.cloudCover, CloudCover.overcast);
      expect(first.latitude, 12.16);
      expect(first.longitude, -68.28);
      expect(first.weatherSource, WeatherSource.openMeteo);
      // The full payload is stored even though the header renders only part.
      expect(first.humidity, 70.0);
      expect(first.surfacePressure, isNotNull);
      expect(repository.upserts[1].date, DateTime(2026, 3, 9));
    });

    test('a failed fetch writes no row', () async {
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((_) async => http.Response('', 500)),
        repository: repository,
      );

      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(repository.upserts, isEmpty);
    });

    test('a result with nothing renderable writes no row', () async {
      // Storing it would suppress the retry that a later archive update
      // would satisfy.
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((_) async => unrenderableResponse()),
        repository: repository,
      );

      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(repository.upserts, isEmpty);
    });

    test('a day already stored is not fetched', () async {
      final repository = FakeTripDayWeatherRepository(
        stored: {
          // Keyed as getForTrip keys it. A local DateTime's epoch matches the
          // day key only at UTC+0, so keying it that way would assert a
          // contract production never offers.
          tripDayMillis(DateTime(2026, 3, 8)): TripDayWeather(
            id: 'w1',
            tripId: 'trip-1',
            date: DateTime(2026, 3, 8),
            latitude: 12.16,
            longitude: -68.28,
            airTemp: 21,
            fetchedAt: DateTime(2026, 3, 9),
            createdAt: DateTime(2026, 3, 9),
            updatedAt: DateTime(2026, 3, 9),
          ),
        },
      );
      var calls = 0;
      final container = containerWith(
        client: MockClient((_) async {
          calls++;
          return weatherResponse();
        }),
        repository: repository,
      );

      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(calls, 1);
      expect(repository.upserts, hasLength(1));
      expect(repository.upserts.single.date, DateTime(2026, 3, 9));
    });

    test('a miss is retried when the trip is viewed again', () async {
      // The documented policy is that a miss writes nothing and is retried on
      // the next view. A provider that stays alive for the container's
      // lifetime would serve its completed state instead, so a transient
      // failure would not be retried until the app restarted.
      var calls = 0;
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        repository: repository,
      );

      // First visit: the view mounts, watches, and the pass runs.
      final first = container.listen(
        tripDayWeatherBackfillProvider('trip-1'),
        (_, _) {},
      );
      await container.read(tripDayWeatherBackfillProvider('trip-1').future);
      expect(calls, 2, reason: 'two days, both missing');

      // Leaving the trip drops the last listener.
      first.close();
      await Future<void>.delayed(Duration.zero);

      // Returning to the trip must run the pass again.
      container.listen(tripDayWeatherBackfillProvider('trip-1'), (_, _) {});
      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(calls, 4);
    });

    test('the pass does not re-run while the view stays mounted', () async {
      var calls = 0;
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        repository: repository,
      );

      container.listen(tripDayWeatherBackfillProvider('trip-1'), (_, _) {});
      await container.read(tripDayWeatherBackfillProvider('trip-1').future);
      // A rebuild re-watches; that must not start another pass.
      await container.read(tripDayWeatherBackfillProvider('trip-1').future);

      expect(calls, 2);
    });

    test('fetches run one at a time', () async {
      final gate = Completer<void>();
      var started = 0;
      final repository = FakeTripDayWeatherRepository();
      final container = containerWith(
        client: MockClient((_) async {
          started++;
          if (started == 1) await gate.future;
          return weatherResponse();
        }),
        repository: repository,
      );

      final pending = container.read(
        tripDayWeatherBackfillProvider('trip-1').future,
      );
      await Future<void>.delayed(Duration.zero);

      // A two-week trip must not open with a burst of parallel requests.
      expect(started, 1);

      gate.complete();
      await pending;
      expect(started, 2);
    });
  });
}
