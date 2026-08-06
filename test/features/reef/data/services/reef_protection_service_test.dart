import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

void main() {
  group('ReefProtectionService.fetch', () {
    test(
      'filters to marine protected areas and maps identity fields',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.queryParameters['where'],
            "category_name='Marine Protected Area'",
          );
          expect(request.url.queryParameters['geometry'], '-80.376,25.01');
          // The unverified activity codes must never be requested.
          final outFields = request.url.queryParameters['outFields']!;
          expect(outFields, isNot(contains('diving')));
          expect(outFields, isNot(contains('lfp')));
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'attributes': {
                    'site_name': 'Molasses Reef Sanctuary Preserve',
                    'country': 'United States',
                    'iucn_cat': 'Ia',
                    'wdpa_id': 12345,
                    'navigator_link': 'https://navigatormap.org/site/12345',
                  },
                },
              ],
            }),
            200,
          );
        });

        final result = await ReefProtectionService(
          client: client,
        ).fetch(const GeoPoint(25.010, -80.376));

        expect(result.status, ReefDataStatus.ok);
        expect(result.value, hasLength(1));
        expect(
          result.value!.first.siteName,
          'Molasses Reef Sanctuary Preserve',
        );
        expect(result.value!.first.iucnCategory, 'Ia');
        expect(result.value!.first.wdpaId, 12345);
      },
    );

    test('returns every overlapping area', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'features': [
              {
                'attributes': {'site_name': 'A'},
              },
              {
                'attributes': {'site_name': 'B'},
              },
            ],
          }),
          200,
        ),
      );
      final result = await ReefProtectionService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.value, hasLength(2));
    });

    test('returns empty when the site is not protected', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'features': []}), 200),
      );
      final result = await ReefProtectionService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.empty);
    });

    test('skips features with no site name', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'features': [
              {
                'attributes': {'site_name': null},
              },
            ],
          }),
          200,
        ),
      );
      final result = await ReefProtectionService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.empty);
    });

    test('returns unavailable on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final result = await ReefProtectionService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });
  });
}
