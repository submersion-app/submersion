import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('UnitFormatter formatTankVolume', () {
    late UnitFormatter metricFormatter;
    late UnitFormatter imperialFormatter;

    setUp(() {
      metricFormatter = const UnitFormatter(AppSettings());
      imperialFormatter = const UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );
    });

    test('returns -- for null volume', () {
      expect(imperialFormatter.formatTankVolume(null, 207.0), '--');
    });

    test('metric shows physical volume in liters', () {
      expect(metricFormatter.formatTankVolume(11.1, 207.0), '11 L');
    });

    test('metric shows volume with decimals', () {
      expect(
        metricFormatter.formatTankVolume(11.1, 207.0, decimals: 1),
        '11.1 L',
      );
    });

    test('imperial uses ratedCapacityCuft when provided', () {
      expect(
        imperialFormatter.formatTankVolume(
          11.1,
          206.843,
          ratedCapacityCuft: 77.4,
        ),
        '77 cuft',
      );
    });

    test('imperial uses ratedCapacityCuft with decimals', () {
      expect(
        imperialFormatter.formatTankVolume(
          11.1,
          206.843,
          ratedCapacityCuft: 77.4,
          decimals: 1,
        ),
        '77.4 cuft',
      );
    });

    test('imperial auto-matches known preset specs', () {
      // 11.1L @ 207 bar matches AL80 -> 77.4 cuft
      expect(imperialFormatter.formatTankVolume(11.1, 207.0), '77 cuft');
    });

    test('imperial calculates from ideal gas for non-standard tanks', () {
      // 14.0L @ 220 bar doesn't match any preset -> ideal gas
      // 14.0 * 220.0 / 28.3168 ≈ 108.8
      expect(imperialFormatter.formatTankVolume(14.0, 220.0), '109 cuft');
    });

    test('imperial shows approximate when no working pressure', () {
      // Uses 200 bar default: 11.1 * 200 / 28.3168 ≈ 78.4
      expect(imperialFormatter.formatTankVolume(11.1, null), '~78 cuft');
    });

    test('imperial shows approximate when working pressure is zero', () {
      expect(imperialFormatter.formatTankVolume(11.1, 0.0), '~78 cuft');
    });
  });
}
