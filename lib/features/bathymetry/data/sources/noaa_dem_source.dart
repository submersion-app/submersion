import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// High-resolution coastal tier: the NOAA NCEI DEM mosaic ImageServer,
/// which stacks CUDEM and regional DEMs over an ETOPO background. US
/// public domain. Coverage is patchy and mostly US coastal, so this source
/// declines wherever the stack holds nothing better than that background.
///
/// The probe is what keeps that honest. `identify` reports every DEM under
/// a point with its own cell size, so the source knows BEFORE fetching
/// whether it has anything worth having: measured 3.4 m in the Florida
/// Keys, 10.3 m at La Jolla, and only ETOPO's 464 m at Bonaire, where it
/// declines and lets the ETOPO tier serve that data directly.
class NoaaDemSource implements BathymetrySource {
  static const String sourceId = 'noaa_dem';

  /// Below this cell size the mosaic is offering a real coastal DEM. Above
  /// it, the stack holds only its ETOPO background, which the ETOPO tier
  /// already serves without the extra round trip.
  static const double usefulCellSizeMeters = 50;

  /// Cells per side requested from exportImage. The server resamples to
  /// whatever is asked, so this is a render-budget choice, not a data one.
  static const int requestDim = 256;

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String baseUrl;

  NoaaDemSource({
    http.Client? client,
    this.baseUrl =
        'https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_all/ImageServer',
  }) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  /// Coverage is patchy coastal, so a dry answer here proves nothing about
  /// whether a coordinate is on land.
  @override
  bool get global => false;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async {
    final url = Uri.parse('$baseUrl/identify').replace(
      queryParameters: {
        'geometry': '{"x":${center.longitude},"y":${center.latitude}}',
        'geometryType': 'esriGeometryPoint',
        'returnCatalogItems': 'true',
        // Load-bearing. The default truncates the catalogue to three items,
        // which hides a covered site's DEM behind the ETOPO background and
        // makes the source decline where it actually has data.
        'maxItemCount': '25',
        'f': 'json',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return null;
      // ArcGIS returns error envelopes with HTTP 200, so a body without a
      // catalogue is an ordinary decline rather than an exceptional case.
      final items =
          (body['catalogItems'] as Map<String, dynamic>?)?['features'];
      if (items is! List || items.isEmpty) return null;

      String? bestName;
      double? bestDeg;
      for (final item in items) {
        if (item is! Map) continue;
        final attrs = item['attributes'];
        if (attrs is! Map) continue;
        final lowPs = attrs['LowPS'];
        if (lowPs is! num) continue;
        final deg = lowPs.toDouble();
        if (deg <= 0) continue;
        if (bestDeg == null || deg < bestDeg) {
          bestDeg = deg;
          bestName = attrs['Name'] as String?;
        }
      }
      if (bestDeg == null) return null;

      // LowPS is in degrees; convert on the longitude axis, which is the
      // shorter of the two at every latitude away from the equator.
      final meters = bestDeg * metersPerDegreeLongitude(center.latitude);
      if (meters > usefulCellSizeMeters) return null;
      return SourceCapability(
        cellSizeMeters: meters,
        detail: bestName ?? 'NOAA NCEI DEM',
      );
    } catch (_) {
      // A probe never throws: an unreachable or surprising service simply
      // means this source does not contribute here.
      return null;
    }
  }

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final dLat = spanMeters / 2 / 110540.0;
    final dLon = spanMeters / 2 / metersPerDegreeLongitude(center.latitude);
    final west = center.longitude - dLon;
    final east = center.longitude + dLon;
    final south = center.latitude - dLat;
    final north = center.latitude + dLat;
    final url = Uri.parse('$baseUrl/exportImage').replace(
      queryParameters: {
        'bbox': '$west,$south,$east,$north',
        'bboxSR': '4326',
        'imageSR': '4326',
        'size': '$requestDim,$requestDim',
        'format': 'tiff',
        'pixelType': 'F32',
        'noDataInterpretation': 'esriNoDataMatchAny',
        'interpolation': 'RSP_BilinearInterpolation',
        'f': 'image',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('NOAA DEM HTTP ${resp.statusCode}');
      }
      return ArcgisFloat32TiffParser.parse(
        resp.bodyBytes,
        westLon: west,
        eastLon: east,
        southLat: south,
        northLat: north,
        sourceId: sourceId,
        resolutionMeters: spanMeters / requestDim,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('NOAA DEM fetch failed: $e');
    }
  }
}
