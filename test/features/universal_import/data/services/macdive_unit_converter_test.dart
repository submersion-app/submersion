import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

void main() {
  final metric = const MacDiveUnitConverter(MacDiveUnitSystem.metric);
  final imperial = const MacDiveUnitConverter(MacDiveUnitSystem.imperial);
  final unknown = const MacDiveUnitConverter(MacDiveUnitSystem.unknown);

  group('depthToMeters', () {
    test('metric passes through', () {
      expect(metric.depthToMeters(20.0), 20.0);
    });
    test('imperial converts feet → meters (30.48 cm / ft)', () {
      expect(imperial.depthToMeters(100.0), closeTo(30.48, 0.001));
      expect(imperial.depthToMeters(33.0), closeTo(10.058, 0.001));
    });
    test('unknown passes through (best effort)', () {
      expect(unknown.depthToMeters(20.0), 20.0);
    });
    test('null passes through', () {
      expect(imperial.depthToMeters(null), isNull);
      expect(metric.depthToMeters(null), isNull);
    });
  });

  group('tempToCelsius', () {
    test('imperial F → C', () {
      expect(imperial.tempToCelsius(80.0), closeTo(26.667, 0.01));
      expect(imperial.tempToCelsius(32.0), closeTo(0.0, 0.001));
      expect(imperial.tempToCelsius(212.0), closeTo(100.0, 0.001));
    });
    test('metric passes through', () {
      expect(metric.tempToCelsius(25.0), 25.0);
    });
    test('null passes through', () {
      expect(imperial.tempToCelsius(null), isNull);
    });
  });

  group('pressureToBar', () {
    test('imperial psi → bar (1 psi = 0.0689476 bar)', () {
      expect(imperial.pressureToBar(3000.0), closeTo(206.843, 0.01));
      expect(imperial.pressureToBar(14.5038), closeTo(1.0, 0.001));
    });
    test('metric passes through', () {
      expect(metric.pressureToBar(200.0), 200.0);
    });
    test('null passes through', () {
      expect(imperial.pressureToBar(null), isNull);
    });
  });

  group('weightToKg', () {
    test('imperial lb → kg (1 lb = 0.453592 kg)', () {
      expect(imperial.weightToKg(10.0), closeTo(4.536, 0.01));
      expect(imperial.weightToKg(2.205), closeTo(1.0, 0.01));
    });
    test('metric passes through', () {
      expect(metric.weightToKg(5.0), 5.0);
    });
    test('null passes through', () {
      expect(imperial.weightToKg(null), isNull);
    });
  });

  group('tankSizeLiters', () {
    test('metric passes through (liters)', () {
      expect(metric.tankSizeLiters(12.0, 232.0), 12.0);
    });

    test('imperial AL80 (77.4 cft @ 3000 psi) approximates 10.59 L', () {
      // cft to L: multiply by 28.3168
      // divide by working pressure in bar (3000 psi = 206.843 bar)
      // 77.4 * 28.3168 / 206.843 ≈ 10.59 L
      final result = imperial.tankSizeLiters(77.4, 3000.0);
      expect(result, closeTo(10.59, 0.1));
    });

    test('null size passes through', () {
      expect(imperial.tankSizeLiters(null, 3000.0), isNull);
    });

    test('imperial with missing working pressure returns null', () {
      expect(imperial.tankSizeLiters(77.4, null), isNull);
      expect(imperial.tankSizeLiters(77.4, 0.0), isNull);
    });
  });
}
