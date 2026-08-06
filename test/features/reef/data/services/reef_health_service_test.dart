import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';

String _erddapBody({
  required String time,
  double? sst,
  double? anomaly,
  double? hotspot,
  double? dhw,
  int? mask,
}) => jsonEncode({
  'table': {
    'columnNames': [
      'time',
      'latitude',
      'longitude',
      'CRW_SST',
      'CRW_SSTANOMALY',
      'CRW_HOTSPOT',
      'CRW_DHW',
      'CRW_DHW_mask',
    ],
    'rows': [
      [time, 25.025, -80.375, sst, anomaly, hotspot, dhw, mask],
    ],
  },
});

void main() {
  group('ReefHealthService.fetch', () {
    test('requests PacIOOS with latitude before longitude', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          _erddapBody(
            time: '2026-07-23T12:00:00Z',
            sst: 30.56,
            anomaly: 1.15,
            hotspot: 0.96,
            dhw: 3.68,
            mask: 0,
          ),
          200,
        );
      });

      await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(25.010, -80.376));

      expect(captured.host, 'pae-paha.pacioos.hawaii.edu');
      expect(captured.path, contains('dhw_5km.json'));
      // Latitude constraint precedes longitude in every variable block.
      expect(captured.query, contains('(25.010)'));
      expect(
        captured.query.indexOf('(25.010)'),
        lessThan(captured.query.indexOf('(-80.376)')),
      );
    });

    test('derives the alert level rather than reading a raw code', () async {
      final client = MockClient(
        (_) async => http.Response(
          _erddapBody(
            time: '2023-09-19T12:00:00Z',
            sst: 31.0,
            anomaly: 1.9,
            hotspot: 1.47,
            dhw: 17.17,
            mask: 0,
          ),
          200,
        ),
      );
      final result = await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(24.525, -81.375));

      expect(result.status, ReefDataStatus.ok);
      expect(result.value!.alertLevel, BleachingAlertLevel.alertLevel4);
      expect(result.value!.degreeHeatingWeeks, 17.17);
    });

    test('queries a specific date for a past dive', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          _erddapBody(
            time: '2019-03-15T12:00:00Z',
            sst: 28.44,
            anomaly: 0,
            hotspot: -0.51,
            dhw: 0,
            mask: 0,
          ),
          200,
        );
      });

      final result = await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(-0.558, 130.690), date: DateTime.utc(2019, 3, 15));

      expect(captured.query, contains('2019-03-15'));
      expect(result.value!.alertLevel, BleachingAlertLevel.noStress);
      expect(result.value!.observedAt, DateTime.utc(2019, 3, 15, 12));
    });

    test(
      'returns empty for dates before 2002 without making a request',
      () async {
        var called = false;
        final client = MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        });

        final result = await ReefHealthService(client: client).fetch(
          const GeoPoint(25.010, -80.376),
          date: DateTime.utc(1999, 6, 1),
        );

        expect(called, isFalse);
        expect(result.status, ReefDataStatus.empty);
      },
    );

    test(
      'falls back to the nearest water pixel when the point is on land',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              _erddapBody(time: '2026-07-23T12:00:00Z', mask: 1),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'table': {
                'columnNames': [
                  'time',
                  'latitude',
                  'longitude',
                  'CRW_SST',
                  'CRW_SSTANOMALY',
                  'CRW_HOTSPOT',
                  'CRW_DHW',
                  'CRW_DHW_mask',
                ],
                'rows': [
                  [
                    '2026-07-23T12:00:00Z',
                    12.225,
                    -68.425,
                    null,
                    null,
                    null,
                    null,
                    1,
                  ],
                  [
                    '2026-07-23T12:00:00Z',
                    12.175,
                    -68.425,
                    29.1,
                    0.4,
                    0.3,
                    1.2,
                    0,
                  ],
                ],
              },
            }),
            200,
          );
        });

        final result = await ReefHealthService(
          client: client,
        ).fetch(const GeoPoint(12.200, -68.400));

        expect(callCount, 2);
        expect(result.status, ReefDataStatus.ok);
        expect(result.value!.degreeHeatingWeeks, 1.2);
      },
    );

    test('returns empty when the fallback box is entirely land', () async {
      var callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response(
          _erddapBody(time: '2026-07-23T12:00:00Z', mask: 1),
          200,
        );
      });

      final result = await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(39.0, -98.0));

      expect(callCount, 2);
      expect(result.status, ReefDataStatus.empty);
    });

    // ERDDAP answers out-of-range coordinates with HTTP 404, so an unclamped
    // box near a pole or the antimeridian would lose the fallback entirely.
    test('clamps the fallback box to valid WGS84 bounds', () async {
      final captured = <Uri>[];
      final client = MockClient((request) async {
        captured.add(request.url);
        return http.Response(
          _erddapBody(time: '2026-07-23T12:00:00Z', mask: 1),
          200,
        );
      });

      await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(89.98, 179.95));

      expect(captured, hasLength(2));
      final box = captured.last.query;
      expect(box, contains('(90.000)'));
      expect(box, contains('(180.000)'));
      expect(box, isNot(contains('90.055')));
      expect(box, isNot(contains('180.025')));
    });

    test('returns unavailable on the 404 non-JSON error body', () async {
      final client = MockClient(
        (_) async =>
            http.Response('Error {\n code=404;\n message="Not Found";\n}', 404),
      );
      final result = await ReefHealthService(
        client: client,
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });
  });
}
