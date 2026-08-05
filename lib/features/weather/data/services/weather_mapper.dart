import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// Maps Open-Meteo API response data to domain types.
///
/// All conversion methods are static and pure -- no state, no side effects.
class WeatherMapper {
  WeatherMapper._();

  /// Map cloud cover percentage (0-100) to CloudCover enum.
  static CloudCover? mapCloudCover(num? percent) {
    if (percent == null) return null;
    if (percent <= 20) return CloudCover.clear;
    if (percent <= 50) return CloudCover.partlyCloudy;
    if (percent <= 80) return CloudCover.mostlyCloudy;
    return CloudCover.overcast;
  }

  /// Map precipitation amount (mm/h) and WMO weather code to Precipitation enum.
  ///
  /// Weather codes checked first for snow/sleet/hail detection:
  /// - 71-77, 85-86: snow
  /// - 66-67: sleet (freezing rain)
  /// - 96-99: hail (thunderstorm with hail)
  static Precipitation mapPrecipitation(num? mmPerHour, {int? weatherCode}) {
    // Check weather code for special precipitation types
    if (weatherCode != null) {
      if ((weatherCode >= 71 && weatherCode <= 77) ||
          (weatherCode >= 85 && weatherCode <= 86)) {
        return Precipitation.snow;
      }
      if (weatherCode >= 66 && weatherCode <= 67) {
        return Precipitation.sleet;
      }
      if (weatherCode >= 96 && weatherCode <= 99) {
        return Precipitation.hail;
      }
    }

    // Fall back to amount-based classification
    final amount = mmPerHour ?? 0;
    if (amount <= 0) return Precipitation.none;
    if (amount <= 0.5) return Precipitation.drizzle;
    if (amount <= 2.5) return Precipitation.lightRain;
    if (amount <= 7.5) return Precipitation.rain;
    return Precipitation.heavyRain;
  }

  /// Map wind direction in degrees (0-360) to CurrentDirection enum.
  ///
  /// Uses >= lower bound, < upper bound for each sector (45 degree sectors).
  static CurrentDirection? mapWindDirection(num? degrees) {
    if (degrees == null) return null;
    final d = degrees.toDouble() % 360;
    if (d >= 337.5 || d < 22.5) return CurrentDirection.north;
    if (d < 67.5) return CurrentDirection.northEast;
    if (d < 112.5) return CurrentDirection.east;
    if (d < 157.5) return CurrentDirection.southEast;
    if (d < 202.5) return CurrentDirection.south;
    if (d < 247.5) return CurrentDirection.southWest;
    if (d < 292.5) return CurrentDirection.west;
    return CurrentDirection.northWest;
  }

  /// Convert wind speed from km/h to m/s.
  static double? convertWindSpeedKmhToMs(num? kmh) {
    if (kmh == null) return null;
    return kmh / 3.6;
  }

  /// Convert pressure from hPa (mbar) to bar.
  static double? convertPressureHpaToBar(num? hpa) {
    if (hpa == null) return null;
    return hpa / 1000;
  }

  /// Map a full Open-Meteo hourly API response to WeatherData.
  ///
  /// Selects the hour closest to [targetHour] from the hourly arrays.
  static WeatherData mapApiResponse(
    Map<String, dynamic> hourlyData, {
    required DateTime targetHour,
  }) {
    final times = (hourlyData['time'] as List).cast<String>();
    final index = _findClosestHourIndex(times, targetHour);

    final temp = _getDouble(hourlyData['temperature_2m'], index);
    final humidity = _getDouble(hourlyData['relative_humidity_2m'], index);
    final precip = _getDouble(hourlyData['precipitation'], index);
    final cloud = _getDouble(hourlyData['cloud_cover'], index);
    final windKmh = _getDouble(hourlyData['wind_speed_10m'], index);
    final windDeg = _getDouble(hourlyData['wind_direction_10m'], index);
    final pressureHpa = _getDouble(hourlyData['surface_pressure'], index);
    final weatherCode = _getInt(hourlyData['weathercode'], index);

    final cloudCoverEnum = mapCloudCover(cloud);
    final windDirection = mapWindDirection(windDeg);
    final windSpeedMs = convertWindSpeedKmhToMs(windKmh);
    final precipEnum = mapPrecipitation(precip, weatherCode: weatherCode);
    final pressureBar = convertPressureHpaToBar(pressureHpa);

    return WeatherData(
      windSpeed: windSpeedMs,
      windDirection: windDirection,
      cloudCover: cloudCoverEnum,
      precipitation: precipEnum,
      humidity: humidity,
      airTemp: temp,
      surfacePressure: pressureBar,
      weatherCode: weatherCode,
      // Deliberately null. The provider returns no prose and has no language
      // parameter, so any description here would be ours -- and persisting it
      // froze one locale and one unit system into the database. It is built
      // at display time instead, from the fields above plus weatherCode.
      description: null,
    );
  }

  static int _findClosestHourIndex(List<String> times, DateTime target) {
    int closestIndex = 0;
    Duration closestDiff = const Duration(days: 365);

    for (int i = 0; i < times.length; i++) {
      final parsed = DateTime.parse(times[i]);
      final diff = (parsed.difference(target)).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  static double? _getDouble(dynamic list, int index) {
    if (list is! List || index >= list.length) return null;
    final val = list[index];
    if (val == null) return null;
    return (val as num).toDouble();
  }

  static int? _getInt(dynamic list, int index) {
    if (list is! List || index >= list.length) return null;
    final val = list[index];
    if (val == null) return null;
    return (val as num).toInt();
  }
}
