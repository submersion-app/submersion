import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/arcgis_feature_query.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';

/// Fetches reef presence and threat level from WRI Reefs at Risk Revisited
/// 2011 (CC BY 3.0), hosted on a UNEP-WCMC ArcGIS server.
///
/// Keyless and CORS-enabled. Attribution is required; see
/// `reef_attribution_sheet.dart`.
class ReefHabitatService {
  final http.Client _client;

  static const String endpoint =
      'https://data-gis.unep-wcmc.org/server/rest/services/Hosted/'
      'WRI002_ReefsAtRiskRevisited2011/FeatureServer/0/query';

  static const List<String> _outFields = ['threat_txt'];

  ReefHabitatService({http.Client? client}) : _client = client ?? http.Client();

  Future<ReefPart<ReefHabitat>> fetch(GeoPoint point) async {
    try {
      final uri = ArcGisFeatureQuery.buildUri(
        endpoint: endpoint,
        point: point,
        where: '1=1',
        outFields: _outFields,
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        developer.log(
          'Reef habitat HTTP ${response.statusCode}',
          name: 'ReefHabitatService',
        );
        return const ReefPart.unavailable();
      }

      final features = ArcGisFeatureQuery.parseAttributes(response.body);
      if (features.isEmpty) return const ReefPart.empty();

      return ReefPart.ok(
        ReefHabitat(
          onReef: true,
          threatLevel: features.first['threat_txt'] as String?,
        ),
      );
    } catch (e) {
      developer.log(
        'Reef habitat fetch failed: $e',
        name: 'ReefHabitatService',
      );
      return const ReefPart.unavailable();
    }
  }
}
