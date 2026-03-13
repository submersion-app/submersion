import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/weather/data/services/weather_mapper.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// HTTP client for the Open-Meteo Historical Weather API.
///
/// Returns [WeatherData] on success, null on any failure (network, API error,
/// malformed response). Callers should handle null gracefully.
class WeatherService {
  final http.Client _client;

  static const _baseUrl = 'archive-api.open-meteo.com';
  static const _path = '/v1/archive';
  static const _hourlyParams =
      'temperature_2m,relative_humidity_2m,precipitation,'
      'cloud_cover,wind_speed_10m,wind_direction_10m,'
      'surface_pressure,weathercode';

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch historical weather for a given location and date.
  ///
  /// [entryTime] is used to select the closest hourly data point.
  /// Returns null if the request fails or data is unavailable.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final uri = Uri.https(_baseUrl, _path, {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': dateStr,
        'end_date': dateStr,
        'hourly': _hourlyParams,
      });

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        developer.log(
          'Weather API error: ${response.statusCode}',
          name: 'WeatherService',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return null;

      return WeatherMapper.mapApiResponse(hourly, targetHour: entryTime);
    } catch (e) {
      developer.log('Weather fetch failed: $e', name: 'WeatherService');
      return null;
    }
  }
}
