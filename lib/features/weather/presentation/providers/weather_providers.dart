import 'package:http/http.dart' as http;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/weather/data/repositories/weather_repository.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// HTTP client provider (allows injection for testing)
final weatherHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// WeatherService provider
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final client = ref.watch(weatherHttpClientProvider);
  return WeatherService(client: client);
});

/// ElevationService provider
final elevationServiceProvider = Provider<ElevationService>((ref) {
  final client = ref.watch(weatherHttpClientProvider);
  return ElevationService(client: client);
});

/// WeatherRepository provider
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  final diveRepository = ref.watch(diveRepositoryProvider);
  return WeatherRepository(
    weatherService: weatherService,
    diveRepository: diveRepository,
  );
});

/// State for manual weather fetch operations on the edit page
enum WeatherFetchStatus { idle, loading, success, error }

/// Provider for manual weather fetch state
final weatherFetchStatusProvider = StateProvider<WeatherFetchStatus>(
  (ref) => WeatherFetchStatus.idle,
);

/// Provider for fetching weather data manually (returns WeatherData without saving)
final fetchWeatherProvider =
    FutureProvider.family<
      WeatherData?,
      ({double latitude, double longitude, DateTime date, DateTime entryTime})
    >((ref, params) async {
      final service = ref.watch(weatherServiceProvider);
      return service.fetchWeather(
        latitude: params.latitude,
        longitude: params.longitude,
        date: params.date,
        entryTime: params.entryTime,
      );
    });
