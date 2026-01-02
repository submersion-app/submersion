import 'dart:convert';
import 'dart:io';

import '../models/weather_data.dart';
import 'logger_service.dart';

/// Service for fetching weather data from OpenWeatherMap API.
class WeatherService {
  static final _log = LoggerService.forClass(WeatherService);
  static WeatherService? _instance;

  WeatherService._();

  static WeatherService get instance {
    _instance ??= WeatherService._();
    return _instance!;
  }

  /// Fetch current weather for coordinates.
  /// Used for dives happening today.
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
    required String apiKey,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$latitude&lon=$longitude'
        '&appid=$apiKey&units=metric',
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(url);
      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return WeatherResult.success(_parseCurrentWeather(json));
      } else if (response.statusCode == 401) {
        return WeatherResult.error('Invalid API key');
      } else if (response.statusCode == 429) {
        return WeatherResult.error('Too many requests, try again later');
      } else {
        _log.warning('Weather API error: ${response.statusCode} - $body');
        return WeatherResult.error('API error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _log.error('Network error fetching weather', e);
      return WeatherResult.error('Network error: check your connection');
    } catch (e, stackTrace) {
      _log.error('Failed to fetch current weather', e, stackTrace);
      return WeatherResult.error('Error: $e');
    }
  }

  /// Fetch historical weather for past dives.
  /// Uses One Call API 3.0 timemachine endpoint.
  /// Note: Requires paid subscription for historical data.
  Future<WeatherResult> getHistoricalWeather({
    required double latitude,
    required double longitude,
    required DateTime dateTime,
    required String apiKey,
  }) async {
    try {
      final timestamp = dateTime.millisecondsSinceEpoch ~/ 1000;
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall/timemachine'
        '?lat=$latitude&lon=$longitude'
        '&dt=$timestamp'
        '&appid=$apiKey&units=metric',
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(url);
      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return WeatherResult.success(_parseHistoricalWeather(json));
      } else if (response.statusCode == 401) {
        return WeatherResult.error('Invalid API key');
      } else if (response.statusCode == 429) {
        return WeatherResult.error('Too many requests, try again later');
      } else if (response.statusCode == 400) {
        // Historical data might not be available or requires subscription
        _log.info('Historical weather not available, trying current weather');
        return getCurrentWeather(
          latitude: latitude,
          longitude: longitude,
          apiKey: apiKey,
        );
      } else {
        _log.warning('Weather API error: ${response.statusCode} - $body');
        return WeatherResult.error('API error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _log.error('Network error fetching historical weather', e);
      return WeatherResult.error('Network error: check your connection');
    } catch (e, stackTrace) {
      _log.error('Failed to fetch historical weather', e, stackTrace);
      return WeatherResult.error('Error: $e');
    }
  }

  WeatherData _parseCurrentWeather(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>?;
    final wind = json['wind'] as Map<String, dynamic>?;
    final weatherList = json['weather'] as List?;
    final weather = weatherList?.isNotEmpty == true
        ? weatherList!.first as Map<String, dynamic>?
        : null;

    return WeatherData(
      airTemp: main?['temp']?.toDouble(),
      humidity: main?['humidity']?.toDouble(),
      windSpeed: wind?['speed']?.toDouble(),
      windDirection: wind?['deg']?.toDouble(),
      visibility: json['visibility'] as int?,
      description: weather?['description'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  WeatherData _parseHistoricalWeather(Map<String, dynamic> json) {
    // One Call timemachine returns data in a slightly different format
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) {
      return WeatherData(fetchedAt: DateTime.now());
    }

    final current = data.first as Map<String, dynamic>;
    final weatherList = current['weather'] as List?;
    final weather = weatherList?.isNotEmpty == true
        ? weatherList!.first as Map<String, dynamic>?
        : null;

    return WeatherData(
      airTemp: current['temp']?.toDouble(),
      humidity: current['humidity']?.toDouble(),
      windSpeed: current['wind_speed']?.toDouble(),
      windDirection: current['wind_deg']?.toDouble(),
      visibility: current['visibility'] as int?,
      description: weather?['description'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  /// Test if API key is valid by making a simple request.
  Future<bool> testApiKey(String apiKey) async {
    final result = await getCurrentWeather(
      latitude: 51.5074, // London
      longitude: -0.1278,
      apiKey: apiKey,
    );
    return result.isSuccess;
  }
}
