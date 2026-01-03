import 'package:submersion/core/providers/provider.dart';

import '../../../../core/models/weather_data.dart';
import '../../../../core/services/tide_service.dart';
import '../../../../core/services/weather_service.dart';
import '../../../settings/presentation/providers/api_key_providers.dart';

/// Provider for fetching dive conditions from weather and tide APIs.
final conditionsFetchProvider =
    StateNotifierProvider.autoDispose<ConditionsFetchNotifier, ConditionsData>(
        (ref) {
  final apiKeys = ref.watch(apiKeyProvider);
  return ConditionsFetchNotifier(apiKeys);
});

/// StateNotifier for managing conditions fetch state.
class ConditionsFetchNotifier extends StateNotifier<ConditionsData> {
  final ApiKeyState _apiKeys;

  ConditionsFetchNotifier(this._apiKeys) : super(const ConditionsData());

  /// Fetch weather and tide conditions for a dive location and time.
  Future<void> fetchConditions({
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    WeatherData? weather;
    TideData? tide;
    final errors = <String>[];

    // Fetch weather if API key is available
    if (_apiKeys.hasWeatherKey) {
      final isHistorical = dateTime.isBefore(
        DateTime.now().subtract(const Duration(hours: 3)),
      );

      WeatherResult result;
      if (isHistorical) {
        result = await WeatherService.instance.getHistoricalWeather(
          latitude: latitude,
          longitude: longitude,
          dateTime: dateTime,
          apiKey: _apiKeys.openWeatherMapKey!,
        );
      } else {
        result = await WeatherService.instance.getCurrentWeather(
          latitude: latitude,
          longitude: longitude,
          apiKey: _apiKeys.openWeatherMapKey!,
        );
      }

      if (result.isSuccess) {
        weather = result.data;
      } else {
        errors.add('Weather: ${result.error}');
      }
    } else {
      errors.add('No OpenWeatherMap API key configured');
    }

    // Fetch tide if API key is available
    if (_apiKeys.hasTideKey) {
      final result = await TideService.instance.getTideData(
        latitude: latitude,
        longitude: longitude,
        dateTime: dateTime,
        apiKey: _apiKeys.worldTidesKey!,
      );

      if (result.isSuccess) {
        tide = result.data;
      } else {
        errors.add('Tides: ${result.error}');
      }
    }
    // Note: Tide API key is optional, don't add error if not configured

    state = ConditionsData(
      weather: weather,
      tide: tide,
      errorMessage: errors.isEmpty ? null : errors.join('\n'),
      isLoading: false,
    );
  }

  /// Reset the state.
  void reset() {
    state = const ConditionsData();
  }
}
