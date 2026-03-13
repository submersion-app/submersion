import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    test('fetchWeather returns WeatherData on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'archive-api.open-meteo.com');
        expect(request.url.queryParameters['latitude'], '28.5');
        expect(request.url.queryParameters['longitude'], '-80.6');
        expect(request.url.queryParameters['start_date'], '2024-06-15');
        expect(request.url.queryParameters['end_date'], '2024-06-15');

        return http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2024-06-15T09:00', '2024-06-15T10:00'],
              'temperature_2m': [27.0, 28.0],
              'relative_humidity_2m': [75.0, 70.0],
              'precipitation': [0.0, 0.0],
              'cloud_cover': [25.0, 20.0],
              'wind_speed_10m': [12.0, 14.0],
              'wind_direction_10m': [45.0, 50.0],
              'surface_pressure': [1013.0, 1014.0],
              'weathercode': [1, 0],
            },
          }),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNotNull);
      expect(result!.airTemp, 27.0);
      expect(result.cloudCover, CloudCover.partlyCloudy);
      expect(result.precipitation, Precipitation.none);
    });

    test('fetchWeather returns null on HTTP error', () async {
      final mockClient = MockClient((_) async {
        return http.Response('Server error', 500);
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNull);
    });

    test('fetchWeather returns null on network error', () async {
      final mockClient = MockClient((_) async {
        throw Exception('No internet');
      });

      final service = WeatherService(client: mockClient);
      final result = await service.fetchWeather(
        latitude: 28.5,
        longitude: -80.6,
        date: DateTime(2024, 6, 15),
        entryTime: DateTime(2024, 6, 15, 9, 30),
      );

      expect(result, isNull);
    });
  });
}
