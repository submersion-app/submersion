import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';

GasSwitchWithTank _sw(double o2Fraction, {double heFraction = 0.0}) {
  return GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'gs-1',
      diveId: 'dive-1',
      timestamp: 600,
      tankId: 'tank-1',
      createdAt: DateTime(2026, 1, 1),
    ),
    tankName: 'Tank',
    gasMix: '',
    o2Fraction: o2Fraction,
    heFraction: heFraction,
  );
}

void main() {
  group('GasSwitchWithTankGasType.gasType', () {
    test('air (21% O2, 0% He) returns air', () {
      expect(_sw(0.21).gasType, GasType.air);
    });

    test('nitrox (32% O2, 0% He) returns nitrox', () {
      expect(_sw(0.32).gasType, GasType.nitrox);
    });

    test('pure oxygen (100% O2, 0% He) returns oxygen', () {
      expect(_sw(1.0).gasType, GasType.oxygen);
    });

    test('99% O2 with no helium returns oxygen', () {
      expect(_sw(0.99).gasType, GasType.oxygen);
    });

    test('trimix (21% O2, 35% He) returns trimix', () {
      expect(_sw(0.21, heFraction: 0.35).gasType, GasType.trimix);
    });

    test('trimix takes priority over oxygen (100% O2 + He)', () {
      expect(_sw(1.0, heFraction: 0.01).gasType, GasType.trimix);
    });

    test('oxygen takes priority over nitrox (99% O2, no He)', () {
      expect(_sw(0.99).gasType, GasType.oxygen);
    });
  });

  group('GasTypeFromFractions.gasType', () {
    test('air fractions return air', () {
      expect((o2: 0.21, he: 0.0).gasType, GasType.air);
    });

    test('nitrox fractions return nitrox', () {
      expect((o2: 0.32, he: 0.0).gasType, GasType.nitrox);
    });

    test('pure oxygen fraction (1.0) returns oxygen', () {
      expect((o2: 1.0, he: 0.0).gasType, GasType.oxygen);
    });

    test('0.99 O2 fraction returns oxygen', () {
      expect((o2: 0.99, he: 0.0).gasType, GasType.oxygen);
    });

    test('trimix fractions return trimix', () {
      expect((o2: 0.21, he: 0.35).gasType, GasType.trimix);
    });

    test('trimix takes priority over oxygen', () {
      expect((o2: 1.0, he: 0.01).gasType, GasType.trimix);
    });

    test('0.22 O2 boundary is still air', () {
      expect((o2: 0.22, he: 0.0).gasType, GasType.air);
    });

    test('above 0.22 O2 is nitrox', () {
      expect((o2: 0.221, he: 0.0).gasType, GasType.nitrox);
    });
  });
}
