import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/arcgis_feature_query.dart';

void main() {
  group('ArcGisFeatureQuery.buildUri', () {
    test('emits geometry as lon,lat, not lat,lon', () {
      final uri = ArcGisFeatureQuery.buildUri(
        endpoint: 'https://example.org/FeatureServer/0/query',
        point: const GeoPoint(27.988, 34.453),
        where: '1=1',
        outFields: const ['name'],
      );
      expect(uri.queryParameters['geometry'], '34.453,27.988');
      expect(uri.queryParameters['geometryType'], 'esriGeometryPoint');
      expect(uri.queryParameters['inSR'], '4326');
      expect(uri.queryParameters['spatialRel'], 'esriSpatialRelIntersects');
      expect(uri.queryParameters['returnGeometry'], 'false');
      expect(uri.queryParameters['f'], 'json');
    });

    test('always sends a where clause', () {
      final uri = ArcGisFeatureQuery.buildUri(
        endpoint: 'https://example.org/FeatureServer/0/query',
        point: const GeoPoint(1, 2),
        where: "category_name='Marine Protected Area'",
        outFields: const ['a', 'b'],
      );
      expect(
        uri.queryParameters['where'],
        "category_name='Marine Protected Area'",
      );
      expect(uri.queryParameters['outFields'], 'a,b');
    });
  });

  group('ArcGisFeatureQuery.parseAttributes', () {
    test('returns attribute maps for each feature', () {
      final body = jsonEncode({
        'features': [
          {
            'attributes': {'name': 'Molasses Reef', 'iucn_cat': 'Ia'},
          },
        ],
      });
      final result = ArcGisFeatureQuery.parseAttributes(body);
      expect(result, hasLength(1));
      expect(result.first['name'], 'Molasses Reef');
    });

    test('returns an empty list when no features intersect', () {
      final result = ArcGisFeatureQuery.parseAttributes(
        jsonEncode({'features': <dynamic>[]}),
      );
      expect(result, isEmpty);
    });

    // ArcGIS answers HTTP 200 while wrapping a 400 in the body. Treating this
    // as "no features" would render a definitive "not on a reef".
    test('throws on an error envelope returned with HTTP 200', () {
      final body = jsonEncode({
        'error': {'code': 400, 'message': 'Unable to complete operation.'},
      });
      expect(
        () => ArcGisFeatureQuery.parseAttributes(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when the body is not JSON', () {
      expect(
        () => ArcGisFeatureQuery.parseAttributes('<html>502</html>'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
