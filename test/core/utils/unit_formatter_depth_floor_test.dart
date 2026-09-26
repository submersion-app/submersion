import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  group('formatDepthFloor', () {
    test('null renders a placeholder', () {
      expect(metric.formatDepthFloor(null), '--');
    });

    test('rounds a limit depth down, never up', () {
      // EAN32 at 1.4: 33.75 m. formatDepth would show 33.8 / 34.
      expect(metric.formatDepthFloor(33.75), '33.7m');
      expect(metric.formatDepthFloor(33.75, decimals: 0), '33m');
      expect(metric.formatDepthFloor(56.6667, decimals: 0), '56m');
    });

    test('a value exactly on the grid is kept despite float noise', () {
      expect(metric.formatDepthFloor(40.0, decimals: 0), '40m');
      expect(metric.formatDepthFloor(39.99999999999, decimals: 0), '40m');
      expect(metric.formatDepthFloor(6.0), '6.0m');
    });

    test('floors in the display unit', () {
      // 33.75 m = 110.73 ft
      expect(imperial.formatDepthFloor(33.75, decimals: 0), '110ft');
      expect(imperial.formatDepthFloor(33.75), '110.7ft');
    });
  });

  group('formatDepthCeil', () {
    test('rounds a minimum depth up, never down', () {
      // Tx 10/70 at ppO2 0.18 in fresh water: 7.64 m.
      expect(metric.formatDepthCeil(7.64), '7.7m');
      expect(metric.formatDepthCeil(7.64, decimals: 0), '8m');
      expect(imperial.formatDepthCeil(7.64), '25.1ft');
    });

    test('a value on the grid stays put despite float noise', () {
      expect(metric.formatDepthCeil(8.0000000000001), '8.0m');
      expect(metric.formatDepthCeil(8.0), '8.0m');
    });

    test('zero is not shown as minus zero', () {
      expect(metric.formatDepthCeil(0), '0.0m');
    });

    test('null renders a placeholder', () {
      expect(metric.formatDepthCeil(null), '--');
    });
  });

  group('floorToFractionDigits', () {
    test('floors to the given number of decimals', () {
      expect(floorToFractionDigits(33.75, 1), 33.7);
      expect(floorToFractionDigits(33.75, 0), 33);
      expect(floorToFractionDigits(0.29999999999, 1), 0.3);
    });

    test('rounds a best-mix oxygen percentage toward the leaner mix', () {
      expect(floorToFractionDigits(35.16, 0), 35);
      expect(floorToFractionDigits(31.94, 0), 31);
      expect(floorToFractionDigits(35.0, 0), 35);
      expect(floorToFractionDigits(0, 0), 0);
    });

    test('floors negative values toward minus infinity', () {
      expect(floorToFractionDigits(-0.25, 1), -0.3);
    });
  });
}
