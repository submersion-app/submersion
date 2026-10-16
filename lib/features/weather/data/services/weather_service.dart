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
  /// [date] and [entryTime] are wall-clock values at the site: the request
  /// asks for the coordinate's own timezone, so the day window and the hourly
  /// timestamps are both in local time there, and [entryTime] selects the
  /// closest hourly data point on its wall-clock fields.
  /// Returns null if the request fails or data is unavailable.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async {
    final hourly = await fetchHourly(
      latitude: latitude,
      longitude: longitude,
      date: date,
    );
    if (hourly == null) return null;
    return mapHourly(hourly, entryTime: entryTime);
  }

  /// Fetch the raw hourly block for one site-local day.
  ///
  /// One response covers every dive made at that place on [date]; callers
  /// that serve several dives from it map each with [mapHourly] at its own
  /// entry time. Returns null if the request fails or data is unavailable.
  Future<Map<String, dynamic>?> fetchHourly({
    required double latitude,
    required double longitude,
    required DateTime date,
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
        // Open-Meteo defaults to GMT. Every caller passes the site's wall
        // clock, so the day window and the hourly labels must be in the
        // coordinate's own timezone too (issue #3349).
        'timezone': 'auto',
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
      return json['hourly'] as Map<String, dynamic>?;
    } catch (e) {
      developer.log('Weather fetch failed: $e', name: 'WeatherService');
      return null;
    }
  }

  /// Map a block from [fetchHourly] to the sample nearest [entryTime].
  ///
  /// Returns null, and logs, if the block is malformed.
  WeatherData? mapHourly(
    Map<String, dynamic> hourly, {
    required DateTime entryTime,
  }) {
    try {
      return WeatherMapper.mapApiResponse(hourly, targetHour: entryTime);
    } catch (e) {
      developer.log('Weather mapping failed: $e', name: 'WeatherService');
      return null;
    }
  }
}
