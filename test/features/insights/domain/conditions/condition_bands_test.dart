import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('band edges', () {
    test('air temperature has round numbers per unit', () {
      expect(airTempBandEdges(TemperatureUnit.celsius), [10, 20, 25, 30]);
      expect(airTempBandEdges(TemperatureUnit.fahrenheit), [50, 70, 80, 90]);
    });

    test('wind follows the metric flag', () {
      expect(windSpeedBandEdges(metric: true), [10, 20, 30, 40]);
      expect(windSpeedBandEdges(metric: false), [5, 10, 15, 20]);
    });

    test('humidity, pressure and swell', () {
      expect(humidityBandEdges, [40, 60, 80]);
      expect(surfacePressureBandEdges(metric: true), [900, 1000, 1020]);
      expect(surfacePressureBandEdges(metric: false), [27, 29.5, 30.1]);
      expect(swellHeightBandEdges(DepthUnit.meters), [0.5, 1, 2]);
      expect(swellHeightBandEdges(DepthUnit.feet), [2, 3, 6]);
    });
  });

  group('ConditionsUnits', () {
    test('is metric when the depth unit is metres', () {
      const metric = ConditionsUnits(
        temperature: TemperatureUnit.celsius,
        depth: DepthUnit.meters,
      );
      const imperial = ConditionsUnits(
        temperature: TemperatureUnit.celsius,
        depth: DepthUnit.feet,
      );
      expect(metric.isMetric, isTrue);
      expect(imperial.isMetric, isFalse);
    });

    test('has value equality', () {
      expect(
        const ConditionsUnits(
          temperature: TemperatureUnit.fahrenheit,
          depth: DepthUnit.feet,
        ),
        const ConditionsUnits(
          temperature: TemperatureUnit.fahrenheit,
          depth: DepthUnit.feet,
        ),
      );
    });
  });

  group('conversions match UnitFormatter', () {
    // Two converters that disagreed would chart a dive in a band its own
    // detail page contradicts.
    test('wind speed', () {
      const metricFormatter = UnitFormatter(AppSettings());
      const imperialFormatter = UnitFormatter(
        AppSettings(depthUnit: DepthUnit.feet),
      );
      expect(
        windSpeedForDisplay(5, metric: true),
        closeTo(metricFormatter.convertWindSpeed(5), 1e-9),
      );
      expect(
        windSpeedForDisplay(5, metric: false),
        closeTo(imperialFormatter.convertWindSpeed(5), 1e-9),
      );
    });

    test('surface pressure', () {
      const metricFormatter = UnitFormatter(AppSettings());
      const imperialFormatter = UnitFormatter(
        AppSettings(depthUnit: DepthUnit.feet),
      );
      expect(
        surfacePressureForDisplay(1.013, metric: true),
        closeTo(1013, 1e-9),
      );
      expect(metricFormatter.formatSurfacePressure(1.013), startsWith('1013'));
      expect(
        surfacePressureForDisplay(1.0, metric: false),
        closeTo(29.53, 1e-9),
      );
      expect(imperialFormatter.formatSurfacePressure(1.0), startsWith('29.53'));
    });
  });

  group('countIntoBands', () {
    test('returns every band, empty ones included', () {
      final bands = countIntoBands([12], [10, 20], decimals: 0);
      expect(bands, [
        (lower: null, upper: 10.0, count: 0),
        (lower: 10.0, upper: 20.0, count: 1),
        (lower: 20.0, upper: null, count: 0),
      ]);
    });

    test('lower edge is inclusive, upper exclusive', () {
      final bands = countIntoBands([10, 20, 19.9], [10, 20], decimals: 1);
      expect(bands.map((b) => b.count), [0, 2, 1]);
    });

    test('rounds to the displayed precision before binning', () {
      // 19.96 shows as "20.0", so it belongs to the band starting at 20.
      final bands = countIntoBands([19.96], [10, 20], decimals: 1);
      expect(bands.map((b) => b.count), [0, 0, 1]);
    });

    test('18 C converted to F lands where its displayed value says', () {
      // 18 C = 64.4 F, displayed 64.4: band 50-70.
      final f = TemperatureUnit.celsius.convert(18, TemperatureUnit.fahrenheit);
      final bands = countIntoBands([f], [50, 70, 80, 90], decimals: 1);
      expect(bands.map((b) => b.count), [0, 1, 0, 0, 0]);
    });

    test('no values gives all-zero bands', () {
      final bands = countIntoBands(const [], [1, 2], decimals: 0);
      expect(bands.map((b) => b.count), [0, 0, 0]);
    });
  });
}
