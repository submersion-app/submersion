import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveProfilePoint decompression fields', () {
    test('constructor accepts all new deco fields', () {
      const point = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 45.0,
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 2,
        tts: 180,
      );

      expect(point.timestamp, 120);
      expect(point.depth, 30.0);
      expect(point.cns, 45.0);
      expect(point.ndl, 600);
      expect(point.ceiling, 3.0);
      expect(point.ascentRate, 9.0);
      expect(point.rbt, 1200);
      expect(point.decoType, 2);
      expect(point.tts, 180);
    });

    test('new deco fields default to null', () {
      const point = DiveProfilePoint(timestamp: 0, depth: 10.0);

      expect(point.cns, isNull);
      expect(point.ndl, isNull);
      expect(point.ceiling, isNull);
      expect(point.ascentRate, isNull);
      expect(point.rbt, isNull);
      expect(point.decoType, isNull);
      expect(point.tts, isNull);
    });

    test('copyWith preserves deco fields when not overridden', () {
      const original = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 45.0,
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 2,
        tts: 180,
      );

      final copied = original.copyWith(depth: 25.0);

      expect(copied.depth, 25.0);
      expect(copied.cns, 45.0);
      expect(copied.ndl, 600);
      expect(copied.ceiling, 3.0);
      expect(copied.ascentRate, 9.0);
      expect(copied.rbt, 1200);
      expect(copied.decoType, 2);
      expect(copied.tts, 180);
    });

    test('copyWith overrides individual deco fields', () {
      const original = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 45.0,
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 0,
        tts: 180,
      );

      final updated = original.copyWith(
        cns: 50.0,
        ndl: 500,
        ceiling: 6.0,
        ascentRate: 12.0,
        rbt: 900,
        decoType: 2,
        tts: 300,
      );

      expect(updated.cns, 50.0);
      expect(updated.ndl, 500);
      expect(updated.ceiling, 6.0);
      expect(updated.ascentRate, 12.0);
      expect(updated.rbt, 900);
      expect(updated.decoType, 2);
      expect(updated.tts, 300);
    });

    test('equality includes deco fields', () {
      const point1 = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 45.0,
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 2,
        tts: 180,
      );

      const point2 = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 45.0,
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 2,
        tts: 180,
      );

      const point3 = DiveProfilePoint(
        timestamp: 120,
        depth: 30.0,
        cns: 50.0, // different CNS
        ndl: 600,
        ceiling: 3.0,
        ascentRate: 9.0,
        rbt: 1200,
        decoType: 2,
        tts: 180,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });
  });

  group('Dive decompression fields', () {
    Dive createMinimalDive({
      String? decoAlgorithm,
      int? decoConservatism,
      int? gradientFactorLow,
      int? gradientFactorHigh,
    }) {
      return Dive(
        id: 'test-dive-1',
        dateTime: DateTime(2024, 1, 15),
        decoAlgorithm: decoAlgorithm,
        decoConservatism: decoConservatism,
        gradientFactorLow: gradientFactorLow,
        gradientFactorHigh: gradientFactorHigh,
      );
    }

    test('constructor accepts decoAlgorithm and decoConservatism', () {
      final dive = createMinimalDive(
        decoAlgorithm: 'buhlmann',
        decoConservatism: 2,
      );

      expect(dive.decoAlgorithm, 'buhlmann');
      expect(dive.decoConservatism, 2);
    });

    test('new deco fields default to null', () {
      final dive = createMinimalDive();

      expect(dive.decoAlgorithm, isNull);
      expect(dive.decoConservatism, isNull);
    });

    test('existing gradient factor fields still work', () {
      final dive = createMinimalDive(
        gradientFactorLow: 30,
        gradientFactorHigh: 85,
        decoAlgorithm: 'buhlmann',
        decoConservatism: 0,
      );

      expect(dive.gradientFactorLow, 30);
      expect(dive.gradientFactorHigh, 85);
      expect(dive.decoAlgorithm, 'buhlmann');
      expect(dive.decoConservatism, 0);
    });

    test('copyWith preserves deco fields when not overridden', () {
      final original = createMinimalDive(
        decoAlgorithm: 'vpm',
        decoConservatism: -1,
      );

      final copied = original.copyWith(maxDepth: 40.0);

      expect(copied.decoAlgorithm, 'vpm');
      expect(copied.decoConservatism, -1);
      expect(copied.maxDepth, 40.0);
    });

    test('copyWith overrides deco fields', () {
      final original = createMinimalDive(
        decoAlgorithm: 'buhlmann',
        decoConservatism: 0,
      );

      final updated = original.copyWith(
        decoAlgorithm: 'rgbm',
        decoConservatism: 3,
      );

      expect(updated.decoAlgorithm, 'rgbm');
      expect(updated.decoConservatism, 3);
    });

    test('equality includes deco fields', () {
      final dive1 = createMinimalDive(
        decoAlgorithm: 'buhlmann',
        decoConservatism: 0,
      );

      final dive2 = createMinimalDive(
        decoAlgorithm: 'buhlmann',
        decoConservatism: 0,
      );

      final dive3 = createMinimalDive(
        decoAlgorithm: 'vpm',
        decoConservatism: 0,
      );

      expect(dive1, equals(dive2));
      expect(dive1, isNot(equals(dive3)));
    });
  });
}
