// test/features/dive_log/build_available_gases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Dive _diveWith(List<DiveTank> tanks) => Dive(
  id: 'd1',
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 1, 1),
  tanks: tanks,
);

void main() {
  const air = DiveTank(
    id: 't1',
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
  );
  const ean50 = DiveTank(id: 't2', gasMix: GasMix(o2: 50), role: TankRole.deco);
  const o2 = DiveTank(id: 't3', gasMix: GasMix(o2: 100), role: TankRole.deco);

  test('allCarried maps every tank mix and invents no gases', () {
    final gases = buildAvailableGases(
      _diveWith([air, ean50, o2]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.allCarried,
    );
    expect(gases.length, 3);
    // EAN50 MOD at 1.6 = 22 m.
    final ean = gases.firstWhere((g) => (g.fO2 - 0.5).abs() < 1e-9);
    expect(ean.maxPpO2Mod, closeTo(22.0, 1e-6));
  });

  test('decoStageOnly keeps deco/stage/bailout plus the back gas', () {
    final gases = buildAvailableGases(
      _diveWith([air, ean50, o2]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.decoStageOnly,
    );
    // Back gas (air) is always retained as the floor; deco gases kept.
    expect(gases.any((g) => (g.fO2 - 0.21).abs() < 1e-9), isTrue);
    expect(gases.any((g) => (g.fO2 - 0.50).abs() < 1e-9), isTrue);
    expect(gases.any((g) => (g.fO2 - 1.0).abs() < 1e-9), isTrue);
  });
}
