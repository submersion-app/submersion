import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  group('heightIsMetric', () {
    test('derives from the depth unit', () {
      expect(metric.heightIsMetric, isTrue);
      expect(imperial.heightIsMetric, isFalse);
    });
  });

  group('formatHeight', () {
    test('null renders a placeholder', () {
      expect(metric.formatHeight(null), '--');
      expect(imperial.formatHeight(null), '--');
    });

    test('metric renders whole centimeters', () {
      expect(metric.formatHeight(175), '175 cm');
      expect(metric.formatHeight(180.4), '180 cm');
    });

    test('imperial renders feet and inches', () {
      // 175 cm -> 68.9 in -> 69 in -> 5' 9"
      expect(imperial.formatHeight(175), '5\' 9"');
      // 180 cm -> 70.9 in -> 71 in -> 5' 11"
      expect(imperial.formatHeight(180), '5\' 11"');
    });

    test('imperial carries 12 inches into the next foot', () {
      // 182.88 cm == exactly 72 in -> 6' 0", not 5' 12"
      expect(imperial.formatHeight(182.88), '6\' 0"');
    });
  });

  group('feetInchesToCm', () {
    test('converts feet and inches to centimeters for storage', () {
      expect(imperial.feetInchesToCm(6, 0), closeTo(182.88, 1e-9));
      expect(imperial.feetInchesToCm(5, 9), closeTo(175.26, 1e-9));
    });

    test('treats feet-only as whole feet', () {
      expect(imperial.feetInchesToCm(5, 0), closeTo(152.4, 1e-9));
    });
  });
}
