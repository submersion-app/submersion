import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weather/data/services/weather_mapper.dart';

void main() {
  group('WeatherMapper', () {
    group('mapCloudCover', () {
      test('0-20% maps to clear', () {
        expect(WeatherMapper.mapCloudCover(0), CloudCover.clear);
        expect(WeatherMapper.mapCloudCover(20), CloudCover.clear);
      });

      test('21-50% maps to partlyCloudy', () {
        expect(WeatherMapper.mapCloudCover(21), CloudCover.partlyCloudy);
        expect(WeatherMapper.mapCloudCover(50), CloudCover.partlyCloudy);
      });

      test('51-80% maps to mostlyCloudy', () {
        expect(WeatherMapper.mapCloudCover(51), CloudCover.mostlyCloudy);
        expect(WeatherMapper.mapCloudCover(80), CloudCover.mostlyCloudy);
      });

      test('81-100% maps to overcast', () {
        expect(WeatherMapper.mapCloudCover(81), CloudCover.overcast);
        expect(WeatherMapper.mapCloudCover(100), CloudCover.overcast);
      });

      test('null returns null', () {
        expect(WeatherMapper.mapCloudCover(null), isNull);
      });
    });

    group('mapPrecipitation', () {
      test('weathercode for snow returns snow', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 71),
          Precipitation.snow,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 77),
          Precipitation.snow,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 85),
          Precipitation.snow,
        );
      });

      test('weathercode for freezing rain returns sleet', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 66),
          Precipitation.sleet,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 67),
          Precipitation.sleet,
        );
      });

      test('weathercode for hail returns hail', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 96),
          Precipitation.hail,
        );
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 99),
          Precipitation.hail,
        );
      });

      test('0mm rain returns none', () {
        expect(
          WeatherMapper.mapPrecipitation(0.0, weatherCode: 0),
          Precipitation.none,
        );
      });

      test('light amounts return drizzle', () {
        expect(
          WeatherMapper.mapPrecipitation(0.3, weatherCode: 51),
          Precipitation.drizzle,
        );
      });

      test('moderate amounts return lightRain', () {
        expect(
          WeatherMapper.mapPrecipitation(1.5, weatherCode: 61),
          Precipitation.lightRain,
        );
      });

      test('heavy amounts return rain', () {
        expect(
          WeatherMapper.mapPrecipitation(5.0, weatherCode: 63),
          Precipitation.rain,
        );
      });

      test('very heavy amounts return heavyRain', () {
        expect(
          WeatherMapper.mapPrecipitation(10.0, weatherCode: 65),
          Precipitation.heavyRain,
        );
      });

      test('null precipitation returns none', () {
        expect(
          WeatherMapper.mapPrecipitation(null, weatherCode: 0),
          Precipitation.none,
        );
      });
    });

    group('mapWindDirection', () {
      test('0 degrees maps to north', () {
        expect(WeatherMapper.mapWindDirection(0), CurrentDirection.north);
      });

      test('45 degrees maps to northEast', () {
        expect(WeatherMapper.mapWindDirection(45), CurrentDirection.northEast);
      });

      test('90 degrees maps to east', () {
        expect(WeatherMapper.mapWindDirection(90), CurrentDirection.east);
      });

      test('180 degrees maps to south', () {
        expect(WeatherMapper.mapWindDirection(180), CurrentDirection.south);
      });

      test('270 degrees maps to west', () {
        expect(WeatherMapper.mapWindDirection(270), CurrentDirection.west);
      });

      test('350 degrees maps to north (wraps)', () {
        expect(WeatherMapper.mapWindDirection(350), CurrentDirection.north);
      });

      test('null returns null', () {
        expect(WeatherMapper.mapWindDirection(null), isNull);
      });
    });

    group('convertWindSpeedKmhToMs', () {
      test('converts km/h to m/s', () {
        expect(
          WeatherMapper.convertWindSpeedKmhToMs(36.0),
          closeTo(10.0, 0.01),
        );
      });

      test('null returns null', () {
        expect(WeatherMapper.convertWindSpeedKmhToMs(null), isNull);
      });
    });

    group('convertPressureHpaToBar', () {
      test('converts hPa to bar', () {
        expect(
          WeatherMapper.convertPressureHpaToBar(1013.0),
          closeTo(1.013, 0.001),
        );
      });

      test('null returns null', () {
        expect(WeatherMapper.convertPressureHpaToBar(null), isNull);
      });
    });

    group('weather code and description', () {
      Map<String, dynamic> hourly({int? code}) => {
        'time': ['2026-07-26T12:00'],
        'temperature_2m': [24.0],
        'cloud_cover': [10.0],
        'wind_speed_10m': [10.0],
        'wind_direction_10m': [0.0],
        if (code != null) 'weathercode': [code],
      };

      test('retains the raw WMO code', () {
        final data = WeatherMapper.mapApiResponse(
          hourly(code: 61),
          targetHour: DateTime.parse('2026-07-26T12:00'),
        );
        expect(data.weatherCode, 61);
      });

      test('leaves the code null when the API omits it', () {
        final data = WeatherMapper.mapApiResponse(
          hourly(),
          targetHour: DateTime.parse('2026-07-26T12:00'),
        );
        expect(data.weatherCode, isNull);
      });

      test('does not generate an English description', () {
        final data = WeatherMapper.mapApiResponse(
          hourly(code: 0),
          targetHour: DateTime.parse('2026-07-26T12:00'),
        );
        // Prose is rendered at display time so it follows the diver's locale
        // and units. Persisting it here froze it as English and metric.
        expect(data.description, isNull);
      });
    });

    group('mapApiResponse', () {
      test('maps a full hourly API response', () {
        final hourlyData = {
          'time': ['2024-06-15T08:00', '2024-06-15T09:00', '2024-06-15T10:00'],
          'temperature_2m': [26.0, 27.0, 28.0],
          'relative_humidity_2m': [80.0, 75.0, 70.0],
          'precipitation': [0.0, 0.0, 0.0],
          'cloud_cover': [30.0, 25.0, 20.0],
          'wind_speed_10m': [10.0, 12.0, 14.0],
          'wind_direction_10m': [45.0, 50.0, 55.0],
          'surface_pressure': [1013.0, 1013.5, 1014.0],
          'weathercode': [1, 1, 0],
        };

        final result = WeatherMapper.mapApiResponse(
          hourlyData,
          targetHour: DateTime(2024, 6, 15, 9, 30),
        );

        // Should pick hour index 1 (09:00) as closest to 09:30
        expect(result.airTemp, 27.0);
        expect(result.humidity, 75.0);
        expect(result.precipitation, Precipitation.none);
        expect(result.cloudCover, CloudCover.partlyCloudy);
        expect(result.windDirection, CurrentDirection.northEast);
        expect(result.surfacePressure, closeTo(1.0135, 0.001));
        expect(result.windSpeed, closeTo(12.0 / 3.6, 0.01));
      });
    });
  });
}
