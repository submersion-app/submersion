import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/core/tide/constants/harmonic_constituents.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';

enum NoaaFetchStatus {
  /// Constituents fetched and parsed.
  ok,

  /// The station deterministically has no usable harmonic data
  /// (404, empty list, malformed payload). Safe to cache.
  unavailable,

  /// Transient problem (network, timeout, 5xx). Do NOT cache.
  failed,
}

/// Harmonic data for one NOAA station.
class NoaaStationData {
  final Map<String, TideConstituent> constituents;

  /// MSL minus MLLW in meters, or null when datums were unavailable.
  final double? datumOffsetMllw;

  const NoaaStationData({
    required this.constituents,
    required this.datumOffsetMllw,
  });
}

class NoaaFetchResult {
  final NoaaFetchStatus status;
  final NoaaStationData? data;

  const NoaaFetchResult(this.status, [this.data]);
}

/// Fetches a NOAA CO-OPS station's published harmonic constituents and
/// datum offsets. One successful fetch is cached forever by the caller;
/// this service is stateless.
class NoaaStationService {
  static const _base =
      'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations';
  static const _timeout = Duration(seconds: 10);

  /// NOAA constituent spellings that differ from this codebase's names.
  /// Identity for everything else; names absent from our tables are
  /// skipped entirely (no Doodson/nodal data to predict them with).
  static const _nameMap = {
    'NU2': 'Nu2',
    'MU2': 'Mu2',
    'LAM2': 'La2',
    'RHO': 'Rho1',
    'MM': 'Mm',
    'SSA': 'Ssa',
    'SA': 'Sa',
    'MF': 'Mf',
  };

  final http.Client _client;

  NoaaStationService({http.Client? client}) : _client = client ?? http.Client();

  Future<NoaaFetchResult> fetchStation(String stationId) async {
    final http.Response harconResponse;
    try {
      harconResponse = await _client
          .get(Uri.parse('$_base/$stationId/harcon.json?units=metric'))
          .timeout(_timeout);
    } catch (e) {
      developer.log(
        'NOAA harcon fetch failed for $stationId: $e',
        name: 'NoaaStationService',
      );
      return const NoaaFetchResult(NoaaFetchStatus.failed);
    }

    if (harconResponse.statusCode == 404) {
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }
    if (harconResponse.statusCode != 200) {
      return const NoaaFetchResult(NoaaFetchStatus.failed);
    }

    final Map<String, TideConstituent> constituents;
    try {
      constituents = _parseConstituents(harconResponse.body);
    } catch (e) {
      developer.log(
        'NOAA harcon payload malformed for $stationId: $e',
        name: 'NoaaStationService',
      );
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }
    if (constituents.isEmpty) {
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }

    // Datums are best-effort: without them heights reference MSL.
    double? datumOffsetMllw;
    try {
      final datumsResponse = await _client
          .get(Uri.parse('$_base/$stationId/datums.json?units=metric'))
          .timeout(_timeout);
      if (datumsResponse.statusCode == 200) {
        datumOffsetMllw = _parseMllwOffset(datumsResponse.body);
      }
    } catch (e) {
      developer.log(
        'NOAA datums fetch failed for $stationId: $e',
        name: 'NoaaStationService',
      );
    }

    return NoaaFetchResult(
      NoaaFetchStatus.ok,
      NoaaStationData(
        constituents: constituents,
        datumOffsetMllw: datumOffsetMllw,
      ),
    );
  }

  Map<String, TideConstituent> _parseConstituents(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final list = decoded['HarmonicConstituents'] as List;
    final result = <String, TideConstituent>{};
    for (final raw in list) {
      final c = raw as Map<String, dynamic>;
      final noaaName = c['name'] as String;
      final name = _nameMap[noaaName] ?? noaaName;
      final amplitude = (c['amplitude'] as num).toDouble();
      if (amplitude <= 0 || !constituentSpeeds.containsKey(name)) continue;
      result[name] = TideConstituent(
        name: name,
        amplitude: amplitude,
        phase: (c['phase_GMT'] as num).toDouble(),
      );
    }
    return result;
  }

  double? _parseMllwOffset(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final datums = decoded['datums'];
    if (datums is! List) return null;
    double? msl;
    double? mllw;
    for (final raw in datums) {
      final d = raw as Map<String, dynamic>;
      if (d['name'] == 'MSL') msl = (d['value'] as num).toDouble();
      if (d['name'] == 'MLLW') mllw = (d['value'] as num).toDouble();
    }
    if (msl == null || mllw == null) return null;
    return msl - mllw;
  }
}
