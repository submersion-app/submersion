import 'dart:convert';
import 'dart:io';

import '../models/weather_data.dart';
import 'logger_service.dart';

/// Service for fetching tide data from World Tides API.
class TideService {
  static final _log = LoggerService.forClass(TideService);
  static TideService? _instance;

  TideService._();

  static TideService get instance {
    _instance ??= TideService._();
    return _instance!;
  }

  /// Fetch tide data for coordinates and time.
  Future<TideResult> getTideData({
    required double latitude,
    required double longitude,
    required DateTime dateTime,
    required String apiKey,
  }) async {
    try {
      // Format date as YYYY-MM-DD
      final date =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

      final url = Uri.parse(
        'https://www.worldtides.info/api/v3'
        '?heights&extremes&currents'
        '&lat=$latitude&lon=$longitude'
        '&date=$date'
        '&key=$apiKey',
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(url);
      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;

        // Check for API-level errors
        if (json['error'] != null) {
          final error = json['error'] as String;
          _log.warning('Tide API returned error: $error');
          return TideResult.error(error);
        }

        return TideResult.success(_parseTideData(json, dateTime));
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return TideResult.error('Invalid API key');
      } else if (response.statusCode == 429) {
        return TideResult.error('Too many requests, try again later');
      } else {
        _log.warning('Tide API error: ${response.statusCode} - $body');
        return TideResult.error('API error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _log.error('Network error fetching tide data', e);
      return TideResult.error('Network error: check your connection');
    } catch (e, stackTrace) {
      _log.error('Failed to fetch tide data', e, stackTrace);
      return TideResult.error('Error: $e');
    }
  }

  TideData _parseTideData(Map<String, dynamic> json, DateTime targetTime) {
    final heights = json['heights'] as List?;
    final extremes = json['extremes'] as List?;
    final currents = json['currents'] as List?;

    double? currentHeight;
    TideState? state;
    DateTime? nextHigh;
    DateTime? nextLow;
    double? currentSpeed;
    double? currentDirection;

    final targetTs = targetTime.millisecondsSinceEpoch ~/ 1000;

    // Find height closest to target time
    if (heights != null && heights.isNotEmpty) {
      var closest = heights.first as Map<String, dynamic>;
      var minDiff = ((closest['dt'] as int) - targetTs).abs();

      for (final h in heights) {
        final hMap = h as Map<String, dynamic>;
        final diff = ((hMap['dt'] as int) - targetTs).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = hMap;
        }
      }
      currentHeight = closest['height']?.toDouble();
    }

    // Parse extremes for next high/low and determine tide state
    if (extremes != null && extremes.isNotEmpty) {
      for (final e in extremes) {
        final eMap = e as Map<String, dynamic>;
        final ts = eMap['dt'] as int;
        if (ts > targetTs) {
          final isHigh = eMap['type'] == 'High';
          if (isHigh && nextHigh == null) {
            nextHigh = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          } else if (!isHigh && nextLow == null) {
            nextLow = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          }
          if (nextHigh != null && nextLow != null) break;
        }
      }

      // Determine state based on upcoming extreme
      if (nextHigh != null && nextLow != null) {
        state = nextHigh.isBefore(nextLow) ? TideState.rising : TideState.falling;
      } else if (nextHigh != null) {
        state = TideState.rising;
      } else if (nextLow != null) {
        state = TideState.falling;
      }
    }

    // Parse currents if available
    if (currents != null && currents.isNotEmpty) {
      var closest = currents.first as Map<String, dynamic>;
      var minDiff = ((closest['dt'] as int) - targetTs).abs();

      for (final c in currents) {
        final cMap = c as Map<String, dynamic>;
        final diff = ((cMap['dt'] as int) - targetTs).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = cMap;
        }
      }
      // World Tides returns velocity in m/s, convert to knots
      final velMs = closest['vel']?.toDouble();
      if (velMs != null) {
        currentSpeed = velMs * 1.94384; // m/s to knots
      }
      currentDirection = closest['dir']?.toDouble();
    }

    return TideData(
      currentHeight: currentHeight,
      state: state,
      nextHigh: nextHigh,
      nextLow: nextLow,
      currentSpeed: currentSpeed,
      currentDirection: currentDirection,
      fetchedAt: DateTime.now(),
    );
  }

  /// Test if API key is valid by making a simple request.
  Future<bool> testApiKey(String apiKey) async {
    final result = await getTideData(
      latitude: 51.5074, // London
      longitude: -0.1278,
      dateTime: DateTime.now(),
      apiKey: apiKey,
    );
    return result.isSuccess;
  }
}
