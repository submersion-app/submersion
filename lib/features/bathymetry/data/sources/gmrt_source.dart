import 'package:http/http.dart' as http;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Global primary tier: GMRT GridServer (CC-BY 4.0). Best-available
/// resolution everywhere (~61 m where ship multibeam exists, ~450 m
/// GEBCO-based background elsewhere).
class GmrtSource implements BathymetrySource {
  static const String sourceId = 'gmrt';
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final String baseUrl;

  GmrtSource({http.Client? client, this.baseUrl = 'https://www.gmrt.org'})
    : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => true;

  /// GMRT's global tiles run to roughly 60 m where ship multibeam exists.
  /// A NOMINAL figure: elsewhere the same grid spacing carries upsampled
  /// GEBCO. The resolver's preemption factor exists so this number cannot
  /// demote a genuinely surveyed regional source on a claim alone.
  static const double declaredCellSizeMeters = 60;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(
        cellSizeMeters: declaredCellSizeMeters,
        detail: 'GMRT GridServer',
      );

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final dLat = spanMeters / 2 / 110540.0;
    final dLon = spanMeters / 2 / metersPerDegreeLongitude(center.latitude);
    final url = Uri.parse('$baseUrl/services/GridServer').replace(
      queryParameters: {
        'north': '${center.latitude + dLat}',
        'south': '${center.latitude - dLat}',
        'east': '${center.longitude + dLon}',
        'west': '${center.longitude - dLon}',
        'format': 'esriascii',
        'resolution': 'high',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('GMRT HTTP ${resp.statusCode}');
      }
      return EsriAsciiGridParser.parse(
        resp.body,
        sourceId: sourceId,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('GMRT fetch failed: $e');
    }
  }
}
