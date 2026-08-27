import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';

/// Serves a fixed elevation and counts requests; 500s when [fail] is true.
ElevationService _service({
  double elevation = 740.0,
  bool fail = false,
  List<Uri>? requests,
}) {
  return ElevationService(
    client: MockClient((request) async {
      requests?.add(request.url);
      if (fail) return http.Response('oops', 500);
      return http.Response(
        jsonEncode({
          'elevation': [elevation],
        }),
        200,
      );
    }),
  );
}

DiveSite _site({GeoPoint? location, double? altitude}) => DiveSite(
  id: 'site-1',
  name: 'Lake Test',
  location: location,
  altitude: altitude,
);

void main() {
  group('AltitudeResolver', () {
    test('prefers the dive entry location lookup', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(elevation: 740.0, requests: requests),
      );

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(altitude: 300.0),
      );

      expect(result.altitudeMeters, 740.0);
      expect(result.siteAltitudeWriteBack, isNull);
      expect(requests.single.queryParameters['latitude'], '46.4');
    });

    test('uses exit location when entry is missing', () async {
      final resolver = AltitudeResolver(elevationService: _service());

      final result = await resolver.resolve(
        exitLocation: const GeoPoint(46.5, 8.1),
      );

      expect(result.altitudeMeters, 740.0);
    });

    test('falls back to site altitude when dive lookup fails', () async {
      final resolver = AltitudeResolver(elevationService: _service(fail: true));

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(altitude: 300.0),
      );

      expect(result.altitudeMeters, 300.0);
      expect(result.siteAltitudeWriteBack, isNull);
    });

    test('uses site altitude when the dive has no GPS', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(requests: requests),
      );

      final result = await resolver.resolve(site: _site(altitude: 300.0));

      expect(result.altitudeMeters, 300.0);
      expect(requests, isEmpty);
    });

    test('looks up site coordinates and returns a write-back', () async {
      final resolver = AltitudeResolver(elevationService: _service());

      final result = await resolver.resolve(
        site: _site(location: const GeoPoint(46.4, 8.0)),
      );

      expect(result.altitudeMeters, 740.0);
      expect(result.siteAltitudeWriteBack, (
        siteId: 'site-1',
        altitudeMeters: 740.0,
      ));
    });

    test('returns empty resolution when nothing is available', () async {
      final requests = <Uri>[];
      final resolver = AltitudeResolver(
        elevationService: _service(requests: requests),
      );

      final result = await resolver.resolve();

      expect(result.altitudeMeters, isNull);
      expect(result.siteAltitudeWriteBack, isNull);
      expect(requests, isEmpty);
    });

    test('returns empty resolution when all lookups fail', () async {
      final resolver = AltitudeResolver(elevationService: _service(fail: true));

      final result = await resolver.resolve(
        entryLocation: const GeoPoint(46.4, 8.0),
        site: _site(location: const GeoPoint(46.4, 8.0)),
      );

      expect(result.altitudeMeters, isNull);
      expect(result.siteAltitudeWriteBack, isNull);
    });

    test('cache dedupes lookups for nearby coordinates', () async {
      final requests = <Uri>[];
      final cache = <String, double?>{};

      final first = AltitudeResolver(
        elevationService: _service(requests: requests),
        cache: cache,
      );
      await first.resolve(entryLocation: const GeoPoint(46.40001, 8.00001));

      final second = AltitudeResolver(
        elevationService: _service(requests: requests),
        cache: cache,
      );
      final result = await second.resolve(
        entryLocation: const GeoPoint(46.40004, 8.00003),
      );

      expect(result.altitudeMeters, 740.0);
      expect(requests, hasLength(1));
    });

    test('cache remembers failures within a run', () async {
      final requests = <Uri>[];
      final cache = <String, double?>{};
      final resolver = AltitudeResolver(
        elevationService: _service(fail: true, requests: requests),
        cache: cache,
      );

      await resolver.resolve(entryLocation: const GeoPoint(46.4, 8.0));
      await resolver.resolve(entryLocation: const GeoPoint(46.4, 8.0));

      expect(requests, hasLength(1));
    });
  });
}
