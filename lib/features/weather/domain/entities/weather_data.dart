import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Immutable value object for weather data fetched from an API or entered manually.
///
/// Used as the return type from WeatherService and as input to WeatherRepository
/// when persisting fetched data to a dive record.
class WeatherData extends Equatable {
  final double? windSpeed; // m/s
  final CurrentDirection? windDirection;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? humidity; // 0-100
  final double? airTemp; // celsius
  final double? surfacePressure; // bar

  /// Free-text description. Null for fetched weather -- the provider returns
  /// no prose, and generating it here would freeze one locale and one unit
  /// system into the database. Populated only for manually entered or
  /// imported text, which is user data and renders verbatim.
  final String? description;

  /// Raw WMO weather code (0 clear, 61 rain, 95 thunderstorm, ...).
  ///
  /// The provider's only textual signal. Kept so the description can be
  /// rendered in the diver's locale at display time.
  final int? weatherCode;

  const WeatherData({
    this.windSpeed,
    this.windDirection,
    this.cloudCover,
    this.precipitation,
    this.humidity,
    this.airTemp,
    this.surfacePressure,
    this.description,
    this.weatherCode,
  });

  @override
  List<Object?> get props => [
    windSpeed,
    windDirection,
    cloudCover,
    precipitation,
    humidity,
    airTemp,
    surfacePressure,
    description,
    weatherCode,
  ];
}
