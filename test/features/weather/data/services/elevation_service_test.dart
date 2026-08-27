import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

void main() {
  group('ElevationService', () {
    test('returns elevation on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/elevation');
        expect(request.url.queryParameters['latitude'], '46.4');
        expect(request.url.queryParameters['longitude'], '8.0');
        return http.Response(
          jsonEncode({
            'elevation': [740.2],
          }),
          200,
        );
      });

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(
        latitude: 46.4,
        longitude: 8.0,
      );

      expect(result, 740.0);
    });

    test('rounds to the nearest whole meter', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'elevation': [12.6],
          }),
          200,
        ),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, 13.0);
    });

    test('clamps negative elevations to zero', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'elevation': [-4.0],
          }),
          200,
        ),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(
        latitude: 27.9,
        longitude: -15.4,
      );

      expect(result, 0.0);
    });

    test('returns null on non-200 response', () async {
      final mockClient = MockClient((_) async => http.Response('oops', 500));

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null on malformed body', () async {
      final mockClient = MockClient(
        (_) async => http.Response('not json', 200),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null when elevation list is empty', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'elevation': <double>[]}), 200),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });

    test('returns null when the request times out', () async {
      final mockClient = MockClient(
        (_) async => throw TimeoutException('timed out'),
      );

      final service = ElevationService(client: mockClient);
      final result = await service.fetchElevation(latitude: 1, longitude: 2);

      expect(result, isNull);
    });
  });
}
