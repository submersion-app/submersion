import 'dart:convert';
import 'dart:math' as math;

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
/// declines and lets the ETOPO tier serve that data directly. Those
/// figures are the cell's coarser axis, so they never overstate the DEM.
class NoaaDemSource implements BathymetrySource {
  static const String sourceId = 'noaa_dem';

  /// Below this cell size the mosaic is offering a real coastal DEM. Above
  /// it, the stack holds only its ETOPO background, which the ETOPO tier
  /// already serves without the extra round trip.
  static const double usefulCellSizeMeters = 50;

  /// Cells per side requested from exportImage. The server resamples to
  /// whatever is asked, so this is a render-budget choice, not a data one.
  static const int requestDim = 256;

  /// Meters per degree of latitude, effectively constant with latitude.
  static const double _metersPerDegLat = 110540.0;

  static const Duration _timeout = Duration(seconds: 15);

  /// Where the mosaic holds any DEM finer than [usefulCellSizeMeters], as
  /// (south, north, west, east) boxes in degrees. Outside them [probe]
  /// declines without a network call.
  ///
  /// This is load-bearing for caching, not only a saved round trip. A probe
  /// that cannot reach the service reports a transient failure, and the
  /// resolver then refuses to cache whatever it falls back to (issue #1770),
  /// because NOAA might have outranked it. Without this table a NOAA outage
  /// would stop caching for every coordinate on Earth, although NOAA can
  /// only ever win inside these boxes.
  ///
  /// Derived 2026-09-26 from the ImageServer's own catalogue: every item
  /// with `LowPS < 0.00046` (50 m at the equator), clustered, then padded
  /// by about a degree so new DEMs next to existing ones still land inside.
  /// Not only US coasts: NCEI also publishes DEMs for Bermuda, the Bahamas,
  /// Grenada, the Cook and Society Islands and the Galapagos. A DEM added
  /// somewhere new is missed until this table grows; the ETOPO, GMRT and
  /// EMODnet tiers still serve such a point, just more coarsely.
  static const List<({double south, double north, double west, double east})>
  coverageRegions = [
    // US mainland and Great Lakes, plus Bermuda and the Bahamas.
    (south: 23, north: 50, west: -128, east: -63),
    // Alaska east of the antimeridian, through the central Aleutians.
    (south: 50, north: 72, west: -180, east: -129),
    // Western Aleutians, west of the antimeridian (Shemya, Attu).
    (south: 50, north: 56, west: 171, east: 180),
    // Hawaii and the Northwestern Hawaiian Islands (Midway, Kure).
    (south: 17, north: 30, west: -180, east: -153),
    // Puerto Rico and the US and British Virgin Islands.
    (south: 16.5, north: 19.5, west: -68.5, east: -63.5),
    // Grenada.
    (south: 11, north: 14, west: -63, east: -60.5),
    // Guam and the Northern Mariana Islands.
    (south: 12, north: 21, west: 143.5, east: 147),
    // Wake Island.
    (south: 18.5, north: 20, west: 166, east: 167.5),
    // American Samoa.
    (south: -15.5, north: -10.5, west: -172, east: -168),
    // Cook Islands (Rarotonga) and Society Islands (Tahiti).
    (south: -23, north: -15.5, west: -161, east: -148),
    // Galapagos.
    (south: -3, north: 3, west: -93, east: -86.5),
  ];

  /// Whether [center] falls inside [coverageRegions], i.e. whether a probe
  /// there is worth a network call at all.
  static bool mayCover(GeoPoint center) => coverageRegions.any(
    (r) =>
        center.latitude >= r.south &&
        center.latitude <= r.north &&
        center.longitude >= r.west &&
        center.longitude <= r.east,
  );

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

  /// See [BathymetrySource.minKnownFraction]'s doc: unchanged from the
  /// resolver's original default. Unlike swissBATHY3D, this source's own
  /// coastal mosaic tiles are themselves sparse survey data (not a
  /// definitive land/water lookup per cell), so a thin grid here is
  /// genuinely as untrustworthy as EMODnet's.
  @override
  double get minKnownFraction => 0.60;

  /// Declines (null) where the mosaic has nothing finer than its ETOPO
  /// background, and instantly outside [coverageRegions]. Throws
  /// [BathymetryFetchException] when the service cannot be asked: see
  /// [BathymetrySource.probe] for why that must not read as a decline.
  @override
  Future<SourceCapability?> probe(GeoPoint center) async {
    if (!mayCover(center)) return null;
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
    final Object? body;
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('NOAA identify HTTP ${resp.statusCode}');
      }
      body = jsonDecode(resp.body);
    } on BathymetryFetchException {
      rethrow;
    } catch (e) {
      // Unreachable, timed out or unparseable: the service did not answer,
      // which is not the same as saying it has nothing here.
      throw BathymetryFetchException('NOAA identify failed: $e');
    }
    if (body is! Map<String, dynamic>) {
      throw const BathymetryFetchException('NOAA identify: unexpected body');
    }
    // ArcGIS reports server failures as an error envelope with HTTP 200.
    if (body['error'] != null) {
      throw BathymetryFetchException('NOAA identify error: ${body['error']}');
    }
    try {
      // A body without a catalogue, and no error, is an ordinary decline.
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

      // LowPS is in DEGREES, and a geographic cell is square in degrees,
      // so its two sides differ in meters: the north-south side is a
      // near-constant 110540 m per degree, while the east-west side shrinks
      // with cos(latitude). Report the COARSER of the two, because a cell
      // is only as good as its worst axis.
      //
      // Converting on longitude alone flatters a DEM as latitude rises. A
      // 3 arc-second cell is 92.1 m north-south everywhere, but reads
      // 46.4 m at 60 N and would slip under the threshold, so a 92 m grid
      // would be accepted as high resolution and, sitting first in the
      // declared order and within the resolver's preemption factor of
      // GMRT's 60 m, would be fetched instead of it. NOAA's mosaic really
      // does hold 3 arc-second Coastal Relief Model tiles, and Alaskan
      // coastal water is where they are the best available.
      //
      // max() rather than simply the latitude axis: at the equator a
      // degree of longitude is 111320 m against latitude's 110540, so the
      // coarser side is not always the same one.
      final meters =
          bestDeg *
          math.max(_metersPerDegLat, metersPerDegreeLongitude(center.latitude));
      if (meters > usefulCellSizeMeters) return null;
      return SourceCapability(
        cellSizeMeters: meters,
        detail: bestName ?? 'NOAA NCEI DEM',
      );
    } catch (_) {
      // The service answered, but with catalogue items of a shape this code
      // does not understand: nothing here it can use, so decline.
      return null;
    }
  }

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final dLat = spanMeters / 2 / _metersPerDegLat;
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
