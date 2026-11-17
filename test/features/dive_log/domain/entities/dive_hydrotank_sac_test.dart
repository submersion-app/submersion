import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// An Avelo Hydrotank (issue #4657) holds the gas the diver breathes, but
/// water pumped in for buoyancy raises its pressure, so its pressures count
/// as not measured for consumption. It stays the dive's main cylinder, so a
/// pony carried beside it never stands in for the whole dive.
///
/// 45 minutes at an average depth of 12 m.
Dive _dive(List<DiveTank> tanks) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 11, 17),
  runtime: const Duration(minutes: 45),
  avgDepth: 12.0,
  tanks: tanks,
);

DiveTank _tank(
  String id,
  TankRole role, {
  required double volume,
  required double end,
}) => DiveTank(
  id: id,
  role: role,
  volume: volume,
  startPressure: 200,
  endPressure: end,
  gasMix: const GasMix(o2: 21),
);

final _hydrotank = _tank('h', TankRole.hydrotank, volume: 10, end: 185);
final _pony = _tank('p', TankRole.pony, volume: 3, end: 170);

void main() {
  group('a Hydrotank and a pony', () {
    final dive = _dive([_hydrotank, _pony]);

    test('the Hydrotank stays the main cylinder', () {
      expect(dive.sacReferenceTank, _hydrotank);
      expect(sacReferenceTankOf([_hydrotank, _pony]), _hydrotank);
    });

    test('there is no whole-dive SAC or RMV, rather than a pony-only one', () {
      expect(dive.sac, isNull);
      expect(dive.rmvFor(GasModel.ideal), isNull);
    });

    test('the reference drop is unknown', () {
      expect(
        referencePressureDrop(
          reference: _hydrotank,
          tanks: [_hydrotank, _pony],
        ),
        isNull,
      );
    });
  });

  test('back gas listed before the Hydrotank gives no back-gas-only SAC', () {
    // Back gas is then the reference, and the Hydrotank's unknown gas would
    // simply go missing from the dive's total.
    final backGas = _tank('b', TankRole.backGas, volume: 10, end: 150);
    final dive = _dive([backGas, _hydrotank]);
    expect(dive.sac, isNull);
    expect(dive.rmvFor(GasModel.ideal), isNull);
  });

  group('a dive whose only cylinder is the Hydrotank', () {
    final dive = _dive([_hydrotank]);

    test('has no SAC or RMV, but keeps its reference cylinder', () {
      expect(dive.sac, isNull);
      expect(dive.rmvFor(GasModel.ideal), isNull);
      expect(dive.sacReferenceTank, _hydrotank);
    });
  });

  test('a back gas cylinder with the same pressures still has a SAC', () {
    final backGas = _tank('b', TankRole.backGas, volume: 10, end: 185);
    expect(_dive([backGas]).sac, isNotNull);
  });
}
