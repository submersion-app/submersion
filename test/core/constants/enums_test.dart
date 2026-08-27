import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('CloudCover', () {
    test('has exactly 4 values', () {
      expect(CloudCover.values.length, 4);
    });

    test('each value has a displayName', () {
      expect(CloudCover.clear.displayName, 'Clear');
      expect(CloudCover.partlyCloudy.displayName, 'Partly Cloudy');
      expect(CloudCover.mostlyCloudy.displayName, 'Mostly Cloudy');
      expect(CloudCover.overcast.displayName, 'Overcast');
    });
  });

  group('Precipitation', () {
    test('has exactly 8 values', () {
      expect(Precipitation.values.length, 8);
    });

    test('each value has a displayName', () {
      expect(Precipitation.none.displayName, 'None');
      expect(Precipitation.drizzle.displayName, 'Drizzle');
      expect(Precipitation.lightRain.displayName, 'Light Rain');
      expect(Precipitation.rain.displayName, 'Rain');
      expect(Precipitation.heavyRain.displayName, 'Heavy Rain');
      expect(Precipitation.snow.displayName, 'Snow');
      expect(Precipitation.sleet.displayName, 'Sleet');
      expect(Precipitation.hail.displayName, 'Hail');
    });
  });

  group('WeatherSource', () {
    test('has exactly 2 values', () {
      expect(WeatherSource.values.length, 2);
    });

    test('each value has a displayName', () {
      expect(WeatherSource.manual.displayName, 'Manual');
      expect(WeatherSource.openMeteo.displayName, 'Open-Meteo');
    });
  });

  group('DiveMode.gauge', () {
    test('gauge has code "gauge" and displayName "Gauge"', () {
      expect(DiveMode.gauge.code, 'gauge');
      expect(DiveMode.gauge.displayName, 'Gauge');
    });

    test('fromCode("gauge") returns gauge; unknown still falls back to oc', () {
      expect(DiveMode.fromCode('gauge'), DiveMode.gauge);
      expect(DiveMode.fromCode('nonsense'), DiveMode.oc);
    });
  });
}
