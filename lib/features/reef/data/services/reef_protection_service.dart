import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/arcgis_feature_query.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';

/// Fetches marine protected areas containing a point from ProtectedSeas
/// Navigator (CC BY 4.0). Keyless and CORS-enabled.
///
/// The `category_name` filter is required: unfiltered queries also return
/// exclusive economic zones and tuna-treaty areas, which are not dive
/// relevant.
class ReefProtectionService {
  final http.Client _client;

  static const String endpoint =
      'https://services9.arcgis.com/lm7wE8a9YA9rKfzy/arcgis/rest/services/'
      'Navigator_AllSites_010925_attributes/FeatureServer/0/query';

  static const String _where = "category_name='Marine Protected Area'";

  /// Identity fields only. The activity-permission codes are excluded by
  /// design: they carry no published codebook, and a misreading would be
  /// wrong regulatory information rather than a cosmetic bug.
  static const List<String> _outFields = [
    'site_name',
    'country',
    'iucn_cat',
    'wdpa_id',
    'navigator_link',
  ];

  ReefProtectionService({http.Client? client})
    : _client = client ?? http.Client();

  Future<ReefPart<List<ReefProtection>>> fetch(GeoPoint point) async {
    try {
      final uri = ArcGisFeatureQuery.buildUri(
        endpoint: endpoint,
        point: point,
        where: _where,
        outFields: _outFields,
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        developer.log(
          'Reef protection HTTP ${response.statusCode}',
          name: 'ReefProtectionService',
        );
        return const ReefPart.unavailable();
      }

      final areas = ArcGisFeatureQuery.parseAttributes(
        response.body,
      ).map(_toProtection).whereType<ReefProtection>().toList(growable: false);

      if (areas.isEmpty) return const ReefPart.empty();
      return ReefPart.ok(areas);
    } catch (e) {
      developer.log(
        'Reef protection fetch failed: $e',
        name: 'ReefProtectionService',
      );
      return const ReefPart.unavailable();
    }
  }

  ReefProtection? _toProtection(Map<String, dynamic> attributes) {
    final name = (attributes['site_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return ReefProtection(
      siteName: name,
      country: attributes['country'] as String?,
      iucnCategory: attributes['iucn_cat'] as String?,
      wdpaId: (attributes['wdpa_id'] as num?)?.toInt(),
      navigatorLink: attributes['navigator_link'] as String?,
    );
  }
}
