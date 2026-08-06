import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

void main() {
  group('ReefHabitatService.fetch', () {
    test('returns ok with the threat level when a reef intersects', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'data-gis.unep-wcmc.org');
        expect(request.url.queryParameters['geometry'], '34.453,27.988');
        return http.Response(
          jsonEncode({
            'features': [
              {
                'attributes': {'threat_txt': 'High'},
              },
            ],
          }),
          200,
        );
      });

      final result = await ReefHabitatService(
        client: client,
      ).fetch(const GeoPoint(27.988, 34.453));

      expect(result.status, ReefDataStatus.ok);
      expect(result.value!.onReef, isTrue);
      expect(result.value!.threatLevel, 'High');
    });

    test('returns empty when no reef intersects', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'features': []}), 200),
      );
      final result = await ReefHabitatService(
        client: client,
      ).fetch(const GeoPoint(51.5, -0.12));
      expect(result.status, ReefDataStatus.empty);
      expect(result.value, isNull);
    });

    test('returns unavailable on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('gateway', 502));
      final result = await ReefHabitatService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });

    test('returns unavailable on an ArcGIS error envelope', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 400},
          }),
          200,
        ),
      );
      final result = await ReefHabitatService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });

    test('returns unavailable when the request throws', () async {
      final client = MockClient((_) async => throw const SocketExceptionStub());
      final result = await ReefHabitatService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });
  });
}
