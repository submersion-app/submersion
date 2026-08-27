import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('UnitFormatter speed', () {
    const metric = UnitFormatter(AppSettings());
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    test('metric renders km/h', () {
      // 10 m/s = 36 km/h
      expect(metric.formatSpeed(10.0), '36.0 km/h');
    });

    test('imperial renders knots, the marine convention for boat speed', () {
      // 10 m/s * 1.94384 = 19.4384 kts
      expect(imperial.formatSpeed(10.0), '19.4 kts');
    });

    test('zero speed renders without a sign or NaN', () {
      expect(metric.formatSpeed(0.0), '0.0 km/h');
    });

    test('honours the decimals argument', () {
      expect(metric.formatSpeed(10.0, decimals: 0), '36 km/h');
    });

    test('speedSymbol matches the diver preference', () {
      expect(metric.speedSymbol, 'km/h');
      expect(imperial.speedSymbol, 'kts');
    });

    test('agrees with formatWindSpeed, which shares the conversion', () {
      // Two speed formatters that disagreed on units would be a bug; they
      // are deliberately one implementation with two names.
      expect(
        metric.formatSpeed(10.0, decimals: 0),
        metric.formatWindSpeed(10.0),
      );
      expect(
        imperial.formatSpeed(10.0, decimals: 0),
        imperial.formatWindSpeed(10.0),
      );
    });
  });
}
