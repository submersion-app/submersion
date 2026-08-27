import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/surface_day_weather_provider.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

http.Response weatherResponse() => http.Response(
  jsonEncode({
    'hourly': {
      'time': ['2024-06-15T09:00', '2024-06-15T12:00'],
      'temperature_2m': [24.0, 29.0],
      'relative_humidity_2m': [80.0, 70.0],
      'precipitation': [0.0, 1.0],
      'cloud_cover': [10.0, 95.0],
      'wind_speed_10m': [8.0, 12.0],
      'wind_direction_10m': [30.0, 45.0],
      'surface_pressure': [1012.0, 1011.0],
      'weathercode': [0, 61],
    },
  }),
  200,
);

void main() {
  final request = SurfaceDayWeatherRequest(
    date: DateTime(2024, 6, 15),
    latitude: 12.1,
    longitude: -68.2,
  );

  test('fetches local noon and maps compact trip weather', () async {
    final client = MockClient((http.Request httpRequest) async {
      expect(httpRequest.url.queryParameters['timezone'], 'auto');
      expect(httpRequest.url.queryParameters['start_date'], '2024-06-15');
      return weatherResponse();
    });
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final weather = await container.read(
      surfaceDayWeatherProvider(request).future,
    );

    expect(
      weather,
      const TripStoryDayWeather(
        airTemp: 29,
        cloudCover: CloudCover.overcast,
        precipitation: Precipitation.lightRain,
      ),
    );
  });

  test('caches one request for an equal family key', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return weatherResponse();
    });
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container.read(surfaceDayWeatherProvider(request).future);
    await container.read(
      surfaceDayWeatherProvider(
        SurfaceDayWeatherRequest(
          date: DateTime(2024, 6, 15),
          latitude: 12.1,
          longitude: -68.2,
        ),
      ).future,
    );

    expect(calls, 1);
  });

  test('propagates unavailable weather as null', () async {
    final client = MockClient((_) async => http.Response('', 500));
    final container = ProviderContainer(
      overrides: [weatherHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(surfaceDayWeatherProvider(request).future),
      isNull,
    );
  });
}
