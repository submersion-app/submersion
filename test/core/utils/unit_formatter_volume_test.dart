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
      expect(metricFormatter.formatTankVolume(11.1, 207.0), '11.1 L');
    });

    test('metric keeps fractional sizes distinct from whole ones', () {
      // A 1.5 L stage must never render as the 2 L bottle beside it.
      expect(metricFormatter.formatTankVolume(1.5, 200.0), '1.5 L');
      expect(metricFormatter.formatTankVolume(2.0, 200.0), '2 L');
    });

    test('metric trims a trailing zero from whole sizes', () {
      expect(metricFormatter.formatTankVolume(12.0, 232.0), '12 L');
      expect(metricFormatter.formatTankVolume(15.0, 232.0), '15 L');
    });

    test('metric rounds to a single decimal', () {
      expect(metricFormatter.formatTankVolume(11.14, 207.0), '11.1 L');
      expect(metricFormatter.formatTankVolume(11.16, 207.0), '11.2 L');
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
          cuftDecimals: 1,
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

    test('metric ignores cuftDecimals, which only governs the cuft branch', () {
      expect(
        metricFormatter.formatTankVolume(1.5, 200.0, cuftDecimals: 0),
        '1.5 L',
      );
    });
  });

  group('UnitFormatter formatVolume', () {
    test('gas quantities stay whole - a fractional liter is noise', () {
      const metricFormatter = UnitFormatter(AppSettings());
      expect(metricFormatter.formatVolume(1800.0), '1800 L');
      expect(metricFormatter.formatVolume(1823.6), '1824 L');
    });

    test('honours an explicit decimals argument', () {
      const metricFormatter = UnitFormatter(AppSettings());
      expect(metricFormatter.formatVolume(1823.6, decimals: 1), '1823.6 L');
    });

    test('returns -- for null', () {
      const metricFormatter = UnitFormatter(AppSettings());
      expect(metricFormatter.formatVolume(null), '--');
    });
  });
}
