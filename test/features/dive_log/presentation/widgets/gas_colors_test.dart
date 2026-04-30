import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

void main() {
  group('GasColors constants', () {
    test('air is dark orange, distinct from depth line blue', () {
      expect(GasColors.air, const Color(0xFFEF6C00));
    });

    test('nitrox is green', () {
      expect(GasColors.nitrox, const Color(0xFF4CAF50));
    });

    test('oxygen is blue', () {
      expect(GasColors.oxygen, const Color(0xFF1976D2));
    });

    test('trimix is purple', () {
      expect(GasColors.trimix, const Color(0xFF9C27B0));
    });

    test('all four colors are distinct', () {
      expect(GasColors.air, isNot(GasColors.nitrox));
      expect(GasColors.air, isNot(GasColors.oxygen));
      expect(GasColors.air, isNot(GasColors.trimix));
      expect(GasColors.nitrox, isNot(GasColors.oxygen));
      expect(GasColors.nitrox, isNot(GasColors.trimix));
      expect(GasColors.oxygen, isNot(GasColors.trimix));
    });
  });

  group('GasColors.forGasType', () {
    test('returns air color for GasType.air', () {
      expect(GasColors.forGasType(GasType.air), GasColors.air);
    });

    test('returns nitrox color for GasType.nitrox', () {
      expect(GasColors.forGasType(GasType.nitrox), GasColors.nitrox);
    });

    test('returns oxygen color for GasType.oxygen', () {
      expect(GasColors.forGasType(GasType.oxygen), GasColors.oxygen);
    });

    test('returns trimix color for GasType.trimix', () {
      expect(GasColors.forGasType(GasType.trimix), GasColors.trimix);
    });
  });

  group('GasColors.forGasMix', () {
    test('returns air color for standard air (21% O2, 0% He)', () {
      const mix = GasMix(o2: 21, he: 0);
      expect(GasColors.forGasMix(mix), GasColors.air);
    });

    test('returns nitrox color for enriched air (32% O2, 0% He)', () {
      const mix = GasMix(o2: 32, he: 0);
      expect(GasColors.forGasMix(mix), GasColors.nitrox);
    });

    test('returns trimix color when helium is present', () {
      const mix = GasMix(o2: 21, he: 35);
      expect(GasColors.forGasMix(mix), GasColors.trimix);
    });

    test('returns oxygen color for pure O2 (100%)', () {
      const mix = GasMix(o2: 100, he: 0);
      expect(GasColors.forGasMix(mix), GasColors.oxygen);
    });

    test('returns oxygen color for 99% O2', () {
      const mix = GasMix(o2: 99, he: 0);
      expect(GasColors.forGasMix(mix), GasColors.oxygen);
    });

    test('trimix takes precedence over nitrox when both apply', () {
      // High O2 + He = trimix, not nitrox
      const mix = GasMix(o2: 32, he: 20);
      expect(GasColors.forGasMix(mix), GasColors.trimix);
    });

    test('trimix takes precedence over oxygen', () {
      const mix = GasMix(o2: 100, he: 1);
      expect(GasColors.forGasMix(mix), GasColors.trimix);
    });
  });

  group('GasColors.forMixPercent', () {
    test('returns air for standard air percentages', () {
      expect(GasColors.forMixPercent(21, 0), GasColors.air);
    });

    test('returns air for 22% O2 (boundary)', () {
      expect(GasColors.forMixPercent(22, 0), GasColors.air);
    });

    test('returns nitrox for O2 above 22%', () {
      expect(GasColors.forMixPercent(32, 0), GasColors.nitrox);
    });

    test('returns trimix when He is present', () {
      expect(GasColors.forMixPercent(21, 35), GasColors.trimix);
    });

    test('returns oxygen for 99% O2', () {
      expect(GasColors.forMixPercent(99, 0), GasColors.oxygen);
    });

    test('returns oxygen for 100% O2', () {
      expect(GasColors.forMixPercent(100, 0), GasColors.oxygen);
    });

    test('trimix takes precedence over nitrox', () {
      expect(GasColors.forMixPercent(32, 20), GasColors.trimix);
    });

    test('trimix takes precedence over oxygen', () {
      expect(GasColors.forMixPercent(100, 1), GasColors.trimix);
    });
  });

  group('GasColors.forMixFraction', () {
    test('returns air for standard air fractions', () {
      expect(GasColors.forMixFraction(0.21, 0), GasColors.air);
    });

    test('returns air for 0.22 O2 (boundary)', () {
      expect(GasColors.forMixFraction(0.22, 0), GasColors.air);
    });

    test('returns nitrox for O2 fraction above 0.22', () {
      expect(GasColors.forMixFraction(0.32, 0), GasColors.nitrox);
    });

    test('returns oxygen for 0.99 O2 fraction', () {
      expect(GasColors.forMixFraction(0.99, 0), GasColors.oxygen);
    });

    test('returns oxygen for 1.0 O2 fraction', () {
      expect(GasColors.forMixFraction(1.0, 0), GasColors.oxygen);
    });

    test('returns trimix when He fraction is present', () {
      expect(GasColors.forMixFraction(0.21, 0.35), GasColors.trimix);
    });

    test('trimix takes precedence over oxygen', () {
      expect(GasColors.forMixFraction(1.0, 0.01), GasColors.trimix);
    });
  });

  group('GasColors.fillColor', () {
    test('returns color with default 0.2 opacity', () {
      final fill = GasColors.fillColor(GasColors.air);
      expect(fill.a, closeTo(0.2, 0.01));
    });

    test('respects custom opacity', () {
      final fill = GasColors.fillColor(GasColors.nitrox, opacity: 0.5);
      expect(fill.a, closeTo(0.5, 0.01));
    });
  });

  group('GasColors.gradientColors', () {
    test('returns two colors with different opacities', () {
      final gradient = GasColors.gradientColors(GasColors.air);
      expect(gradient, hasLength(2));
      expect(gradient[0].a, closeTo(0.05, 0.01));
      expect(gradient[1].a, closeTo(0.3, 0.01));
    });
  });
}
