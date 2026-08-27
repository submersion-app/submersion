import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Global fallback tier: NOAA ETOPO 2022 (15 arc-second, ~450 m cells,
/// US public domain) via ERDDAP griddap JSON, with mirror failover.
class EtopoErddapSource implements BathymetrySource {
  static const String sourceId = 'etopo2022';
  static const String _dataset = 'ETOPO_2022_v1_15s';
  static const double _resolutionMeters = 450;
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final List<String> hosts;

  EtopoErddapSource({
    http.Client? client,
    this.hosts = const [
      'https://coastwatch.pfeg.noaa.gov',
      'https://oceanwatch.pifsc.noaa.gov',
    ],
  }) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => true;

  @override
  bool covers(GeoPoint center) => true;

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    // ~450 m cells need a wide box for enough samples.
    final span = math.max(spanMeters, 10000.0);
    final dLat = span / 2 / 110540.0;
    final dLon = span / 2 / metersPerDegreeLongitude(center.latitude);
    Object? lastError;
    for (final host in hosts) {
      final url = Uri.parse(
        '$host/erddap/griddap/$_dataset.json'
        '?z[(${center.latitude - dLat}):(${center.latitude + dLat})]'
        '[(${center.longitude - dLon}):(${center.longitude + dLon})]',
      );
      try {
        final resp = await _client.get(url).timeout(_timeout);
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode} from $host';
          continue;
        }
        return ErddapGridParser.parse(
          resp.body,
          sourceId: sourceId,
          resolutionMeters: _resolutionMeters,
          fetchedAt: DateTime.now(),
        );
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw BathymetryFetchException('ETOPO fetch failed: $lastError');
  }
}
