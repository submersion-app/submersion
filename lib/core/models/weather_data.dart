/// Data models for weather and tide API responses.
library;

/// Weather data from OpenWeatherMap API.
class WeatherData {
  final double? airTemp; // celsius
  final double? humidity; // percentage
  final double? windSpeed; // m/s
  final double? windDirection; // degrees
  final int? visibility; // meters
  final String? description; // e.g., "clear sky", "light rain"
  final DateTime fetchedAt;

  const WeatherData({
    this.airTemp,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.visibility,
    this.description,
    required this.fetchedAt,
  });

  WeatherData copyWith({
    double? airTemp,
    double? humidity,
    double? windSpeed,
    double? windDirection,
    int? visibility,
    String? description,
    DateTime? fetchedAt,
  }) {
    return WeatherData(
      airTemp: airTemp ?? this.airTemp,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      visibility: visibility ?? this.visibility,
      description: description ?? this.description,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Tide state indicating rising or falling.
enum TideState { rising, falling, high, low }

/// Tide data from World Tides API.
class TideData {
  final double? currentHeight; // meters relative to chart datum
  final TideState? state; // rising, falling, high, low
  final DateTime? nextHigh;
  final DateTime? nextLow;
  final double? currentSpeed; // knots (for tidal currents)
  final double? currentDirection; // degrees
  final DateTime fetchedAt;

  const TideData({
    this.currentHeight,
    this.state,
    this.nextHigh,
    this.nextLow,
    this.currentSpeed,
    this.currentDirection,
    required this.fetchedAt,
  });

  TideData copyWith({
    double? currentHeight,
    TideState? state,
    DateTime? nextHigh,
    DateTime? nextLow,
    double? currentSpeed,
    double? currentDirection,
    DateTime? fetchedAt,
  }) {
    return TideData(
      currentHeight: currentHeight ?? this.currentHeight,
      state: state ?? this.state,
      nextHigh: nextHigh ?? this.nextHigh,
      nextLow: nextLow ?? this.nextLow,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentDirection: currentDirection ?? this.currentDirection,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Combined result from weather and tide fetches.
class ConditionsData {
  final WeatherData? weather;
  final TideData? tide;
  final String? errorMessage;
  final bool isLoading;

  const ConditionsData({
    this.weather,
    this.tide,
    this.errorMessage,
    this.isLoading = false,
  });

  ConditionsData copyWith({
    WeatherData? weather,
    TideData? tide,
    String? errorMessage,
    bool? isLoading,
  }) {
    return ConditionsData(
      weather: weather ?? this.weather,
      tide: tide ?? this.tide,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasData => weather != null || tide != null;
}

/// Result wrapper for weather API calls.
class WeatherResult {
  final WeatherData? data;
  final String? error;

  bool get isSuccess => data != null;

  WeatherResult.success(this.data) : error = null;
  WeatherResult.error(this.error) : data = null;
}

/// Result wrapper for tide API calls.
class TideResult {
  final TideData? data;
  final String? error;

  bool get isSuccess => data != null;

  TideResult.success(this.data) : error = null;
  TideResult.error(this.error) : data = null;
}
