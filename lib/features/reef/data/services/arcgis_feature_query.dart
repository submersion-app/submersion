import 'dart:convert';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Builds and parses ArcGIS FeatureServer point-intersect queries.
///
/// Shared by the habitat and protection services, which differ only in
/// endpoint, filter, and output fields.
class ArcGisFeatureQuery {
  const ArcGisFeatureQuery._();

  /// ArcGIS takes `geometry` as `lon,lat`. GBIF and ERDDAP take latitude
  /// first, so the order is fixed here and never assembled by callers.
  static Uri buildUri({
    required String endpoint,
    required GeoPoint point,
    required String where,
    required List<String> outFields,
  }) {
    return Uri.parse(endpoint).replace(
      queryParameters: {
        'geometry': '${point.longitude},${point.latitude}',
        'geometryType': 'esriGeometryPoint',
        'inSR': '4326',
        'spatialRel': 'esriSpatialRelIntersects',
        'where': where,
        'outFields': outFields.join(','),
        'returnGeometry': 'false',
        'f': 'json',
      },
    );
  }

  /// Returns one attribute map per intersecting feature.
  ///
  /// Throws [FormatException] when the body is not JSON or carries an ArcGIS
  /// error envelope. ArcGIS returns those with HTTP 200, so a caller that
  /// skipped this check would report a failure as a definitive negative.
  static List<Map<String, dynamic>> parseAttributes(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const FormatException('ArcGIS response was not JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ArcGIS response was not an object');
    }
    if (decoded.containsKey('error')) {
      throw FormatException('ArcGIS error: ${decoded['error']}');
    }

    final features = decoded['features'];
    if (features is! List) return const [];

    return features
        .whereType<Map<String, dynamic>>()
        .map((f) => f['attributes'])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
