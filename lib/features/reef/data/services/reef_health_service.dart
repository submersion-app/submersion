import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';

/// Fetches NOAA Coral Reef Watch thermal-stress data via the PacIOOS ERDDAP
/// server.
///
/// PacIOOS is the only NOAA server that sends `Access-Control-Allow-Origin: *`
/// and the only one carrying all products in a single dataset. Do not switch
/// to `coastwatch.pfeg.noaa.gov/erddap/griddap/NOAA_DHW` even though NOAA's
/// own documentation cites it: it redirects here without a CORS header, so it
/// works on mobile and desktop and fails only on web.
class ReefHealthService {
  final http.Client _client;

  static const String _base = 'https://pae-paha.pacioos.hawaii.edu';
  static const String _path = '/erddap/griddap/dhw_5km.json';

  static const List<String> _variables = [
    'CRW_SST',
    'CRW_SSTANOMALY',
    'CRW_HOTSPOT',
    'CRW_DHW',
    'CRW_DHW_mask',
  ];

  /// NOAA's product splices in Met Office OSTIA reanalysis before 2002, and
  /// that segment is licensed for academic use only. From 2002 the data is
  /// explicitly free and open under GHRSST.
  static final DateTime earliestSupportedDate = DateTime.utc(2002, 1, 1);

  /// Half-width of the land-pixel fallback box, in degrees.
  static const double _fallbackSpan = 0.075;

  ReefHealthService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches conditions at [point]. Pass [date] for a past dive; omit it for
  /// the latest available observation.
  Future<ReefPart<ReefHealth>> fetch(GeoPoint point, {DateTime? date}) async {
    if (date != null && date.toUtc().isBefore(earliestSupportedDate)) {
      return const ReefPart.empty();
    }

    final time = date == null ? 'last' : _formatDate(date);

    try {
      final direct = await _request(_pointUri(point, time));
      if (direct == null) return const ReefPart.unavailable();

      final rows = _rows(direct);
      if (rows.isEmpty) return const ReefPart.empty();

      final onWater = rows.where((r) => r.mask == 0).toList();
      if (onWater.isNotEmpty) {
        return ReefPart.ok(_toHealth(onWater.first));
      }

      // The site sits on a land, ice, or missing pixel. Widen to a small box
      // and take the nearest valid water pixel.
      final boxed = await _request(_boxUri(point, time));
      if (boxed == null) return const ReefPart.unavailable();

      final candidates = _rows(boxed).where((r) => r.mask == 0).toList();
      if (candidates.isEmpty) return const ReefPart.empty();

      candidates.sort(
        (a, b) =>
            _distanceSquared(point, a).compareTo(_distanceSquared(point, b)),
      );
      return ReefPart.ok(_toHealth(candidates.first));
    } catch (e) {
      developer.log('Reef health fetch failed: $e', name: 'ReefHealthService');
      return const ReefPart.unavailable();
    }
  }

  Uri _pointUri(GeoPoint point, String time) {
    final lat = point.latitude.toStringAsFixed(3);
    final lon = point.longitude.toStringAsFixed(3);
    final query = _variables
        .map((v) => '$v[($time)][($lat)][($lon)]')
        .join(',');
    return Uri.parse('$_base$_path?$query');
  }

  Uri _boxUri(GeoPoint point, String time) {
    // ERDDAP answers out-of-range coordinates with HTTP 404, so a site near a
    // pole or the antimeridian would lose its land-pixel fallback entirely.
    // Clamp to the WGS84 range the grid actually covers.
    final latLo = _clamp(point.latitude - _fallbackSpan, -90, 90);
    final latHi = _clamp(point.latitude + _fallbackSpan, -90, 90);
    final lonLo = _clamp(point.longitude - _fallbackSpan, -180, 180);
    final lonHi = _clamp(point.longitude + _fallbackSpan, -180, 180);
    final query = _variables
        .map((v) => '$v[($time)][($latLo):1:($latHi)][($lonLo):1:($lonHi)]')
        .join(',');
    return Uri.parse('$_base$_path?$query');
  }

  /// Returns the decoded table, or null when the response is unusable.
  ///
  /// ERDDAP answers out-of-range coordinates and future dates with HTTP 404
  /// and a non-JSON body, so the status code is checked before parsing.
  Future<Map<String, dynamic>?> _request(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      developer.log(
        'Reef health HTTP ${response.statusCode}',
        name: 'ReefHealthService',
      );
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  List<_Sample> _rows(Map<String, dynamic> body) {
    final table = body['table'];
    if (table is! Map<String, dynamic>) return const [];
    final names = (table['columnNames'] as List?)?.cast<String>();
    final rows = table['rows'];
    if (names == null || rows is! List) return const [];

    double? numAt(List<dynamic> row, String column) {
      final i = names.indexOf(column);
      if (i < 0 || i >= row.length) return null;
      return (row[i] as num?)?.toDouble();
    }

    final timeIndex = names.indexOf('time');
    if (timeIndex < 0) return const [];

    return rows
        .whereType<List<dynamic>>()
        .map((row) {
          return _Sample(
            time: DateTime.parse(row[timeIndex] as String).toUtc(),
            latitude: numAt(row, 'latitude') ?? 0,
            longitude: numAt(row, 'longitude') ?? 0,
            sst: numAt(row, 'CRW_SST'),
            anomaly: numAt(row, 'CRW_SSTANOMALY'),
            hotspot: numAt(row, 'CRW_HOTSPOT'),
            dhw: numAt(row, 'CRW_DHW'),
            mask: numAt(row, 'CRW_DHW_mask')?.toInt(),
          );
        })
        .toList(growable: false);
  }

  ReefHealth _toHealth(_Sample s) => ReefHealth(
    sst: s.sst,
    sstAnomaly: s.anomaly,
    hotspot: s.hotspot,
    degreeHeatingWeeks: s.dhw,
    alertLevel: BleachingAlertLevel.derive(dhw: s.dhw, hotspot: s.hotspot),
    observedAt: s.time,
  );

  double _distanceSquared(GeoPoint point, _Sample s) {
    final dLat = point.latitude - s.latitude;
    final dLon = point.longitude - s.longitude;
    return dLat * dLat + dLon * dLon;
  }

  String _clamp(double value, double min, double max) =>
      value.clamp(min, max).toStringAsFixed(3);

  String _formatDate(DateTime date) {
    final utc = date.toUtc();
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$m-$d';
  }
}

class _Sample {
  final DateTime time;
  final double latitude;
  final double longitude;
  final double? sst;
  final double? anomaly;
  final double? hotspot;
  final double? dhw;
  final int? mask;

  const _Sample({
    required this.time,
    required this.latitude,
    required this.longitude,
    this.sst,
    this.anomaly,
    this.hotspot,
    this.dhw,
    this.mask,
  });
}
