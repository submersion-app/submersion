import 'dart:developer' as developer;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

/// Orchestrates weather data fetching and persistence.
///
/// Fetches weather from [WeatherService] and persists it to the dive record
/// via [DiveRepository].
class WeatherRepository {
  final WeatherService _weatherService;
  final DiveRepository _diveRepository;

  WeatherRepository({
    required WeatherService weatherService,
    required DiveRepository diveRepository,
  }) : _weatherService = weatherService,
       _diveRepository = diveRepository;

  /// Fetch weather for a dive and save it to the dive record.
  ///
  /// Respects the overwrite policy: airTemp and surfacePressure are only
  /// populated if they are currently null on the dive.
  ///
  /// Silently returns on any failure (network, API, missing dive).
  Future<void> fetchAndSaveWeather({
    required String diveId,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  }) async {
    try {
      final dive = await _diveRepository.getDiveById(diveId);
      if (dive == null) return;

      final weatherData = await _weatherService.fetchWeather(
        latitude: latitude,
        longitude: longitude,
        date: DateTime(dateTime.year, dateTime.month, dateTime.day),
        entryTime: dateTime,
      );

      if (weatherData == null) return;

      // Re-read rather than writing [dive] back: updateDive rewrites every
      // column and child collection from the entity it is handed, and the
      // dive changed while the request was out (a new dive's logbook rules
      // run in that window, #3513). Writing the earlier read back would
      // undo them, as it once deleted freshly defaulted gear (#1720).
      final stored = await _diveRepository.getDiveById(diveId);
      if (stored == null) return;

      final updatedDive = stored.copyWith(
        windSpeed: weatherData.windSpeed,
        windDirection: weatherData.windDirection,
        cloudCover: weatherData.cloudCover,
        precipitation: weatherData.precipitation,
        humidity: weatherData.humidity,
        weatherDescription: weatherData.description,
        weatherCode: weatherData.weatherCode,
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: DateTime.now(),
        // Only populate airTemp/surfacePressure if currently null
        airTemp: stored.airTemp ?? weatherData.airTemp,
        surfacePressure: stored.surfacePressure ?? weatherData.surfacePressure,
      );

      await _diveRepository.updateDive(updatedDive);
    } catch (e) {
      developer.log(
        'Failed to fetch/save weather for dive $diveId: $e',
        name: 'WeatherRepository',
      );
    }
  }
}
