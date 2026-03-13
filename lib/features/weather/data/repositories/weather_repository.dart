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

      final updatedDive = dive.copyWith(
        windSpeed: weatherData.windSpeed,
        windDirection: weatherData.windDirection,
        cloudCover: weatherData.cloudCover,
        precipitation: weatherData.precipitation,
        humidity: weatherData.humidity,
        weatherDescription: weatherData.description,
        weatherSource: WeatherSource.openMeteo,
        weatherFetchedAt: DateTime.now(),
        // Only populate airTemp/surfacePressure if currently null
        airTemp: dive.airTemp ?? weatherData.airTemp,
        surfacePressure: dive.surfacePressure ?? weatherData.surfacePressure,
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
