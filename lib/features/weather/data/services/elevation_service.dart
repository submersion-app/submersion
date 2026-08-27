import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// HTTP client for the Open-Meteo Elevation API.
///
/// Returns ground elevation in meters above sea level, or null on any
/// failure (network, API error, malformed response). Never throws.
class ElevationService {
  final http.Client _client;

  static const _baseUrl = 'api.open-meteo.com';
  static const _path = '/v1/elevation';
  static const _timeout = Duration(seconds: 5);

  ElevationService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch ground elevation for a coordinate pair.
  ///
  /// Negative results (offshore grid cells) clamp to 0; values round to the
  /// nearest whole meter so a stored 0 always means sea level.
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https(_baseUrl, _path, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        developer.log(
          'Elevation API error: ${response.statusCode}',
          name: 'ElevationService',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final values = json['elevation'] as List<dynamic>?;
      if (values == null || values.isEmpty) return null;
      final raw = (values.first as num).toDouble();
      return raw < 0 ? 0.0 : raw.roundToDouble();
    } catch (e) {
      developer.log('Elevation fetch failed: $e', name: 'ElevationService');
      return null;
    }
  }
}
