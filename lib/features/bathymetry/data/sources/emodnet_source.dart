import 'package:http/http.dart' as http;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

typedef _Box = ({
  double minLat,
  double maxLat,
  double minLon,
  double maxLon,
  String dataset,
});

/// Regional tier: EMODnet Bathymetry DTM 2024 (~115 m surveyed, CC-BY 4.0)
/// via its ERDDAP server. Covers European seas plus one Caribbean tile.
/// Vertical datum is LAT (not MSL) — fine standalone, never mix its cells
/// into another source's grid.
class EmodnetSource implements BathymetrySource {
  static const String sourceId = 'emodnet';
  static const double _resolutionMeters = 115;
  static const Duration _timeout = Duration(seconds: 10);

  static const _Box _carib = (
    minLat: 11.0,
    maxLat: 19.0,
    minLon: -70.5,
    maxLon: -59.5,
    dataset: 'bathymetry_dtm_carib_2024',
  );
  static const _Box _europe = (
    minLat: 15.0,
    maxLat: 90.0,
    minLon: -36.0,
    maxLon: 43.0,
    dataset: 'bathymetry_dtm_2024',
  );

  final http.Client _client;
  final String baseUrl;

  EmodnetSource({
    http.Client? client,
    this.baseUrl = 'https://erddap.emodnet.eu',
  }) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => false;

  static bool _inBox(GeoPoint p, _Box b) =>
      p.latitude >= b.minLat &&
      p.latitude <= b.maxLat &&
      p.longitude >= b.minLon &&
      p.longitude <= b.maxLon;

  @override
  bool covers(GeoPoint center) =>
      _inBox(center, _carib) || _inBox(center, _europe);

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final box = _inBox(center, _carib) ? _carib : _europe;
    final dLat = spanMeters / 2 / 110540.0;
    final dLon = spanMeters / 2 / metersPerDegreeLongitude(center.latitude);
    final url = Uri.parse(
      '$baseUrl/erddap/griddap/${box.dataset}.json'
      '?elevation[(${center.latitude - dLat}):(${center.latitude + dLat})]'
      '[(${center.longitude - dLon}):(${center.longitude + dLon})]',
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('EMODnet HTTP ${resp.statusCode}');
      }
      return ErddapGridParser.parse(
        resp.body,
        sourceId: sourceId,
        resolutionMeters: _resolutionMeters,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('EMODnet fetch failed: $e');
    }
  }
}
