import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  group('short length (issue #1804)', () {
    test('metric reads stored metres as centimetres', () {
      expect(metric.convertShortLength(0.56), closeTo(56, 1e-9));
      expect(metric.shortLengthSymbol, 'cm');
    });

    test('imperial reads stored metres as inches', () {
      // A 22" hose is 55.88 cm.
      expect(imperial.convertShortLength(0.5588), closeTo(22, 1e-9));
      expect(imperial.shortLengthSymbol, 'in');
    });

    test('display converts back to metres for storage', () {
      expect(metric.shortLengthToMeters(56), closeTo(0.56, 1e-12));
      expect(imperial.shortLengthToMeters(15), closeTo(0.381, 1e-12));
    });

    test('follows the depth unit, like body height', () {
      expect(metric.heightIsMetric, isTrue);
      expect(metric.shortLengthSymbol, 'cm');
      expect(imperial.heightIsMetric, isFalse);
      expect(imperial.shortLengthSymbol, 'in');
    });
  });
}
