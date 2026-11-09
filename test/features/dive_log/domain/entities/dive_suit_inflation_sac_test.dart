import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// A suit inflation bottle is not breathing gas (issue #4243): listed first,
/// sized and dropping, it changes no consumption figure.
///
/// 60 minutes at an average depth of 10 m: 2 bar ambient.
Dive _dive(List<DiveTank> tanks) => Dive(
  id: 'd',
  dateTime: DateTime(2024, 1, 1),
  runtime: const Duration(minutes: 60),
  avgDepth: 10.0,
  tanks: tanks,
);

DiveTank _tank(
  String id,
  TankRole role, {
  double? volume = 11.1,
  double start = 200,
  double end = 80,
  double o2 = 21,
}) => DiveTank(
  id: id,
  role: role,
  volume: volume,
  startPressure: start,
  endPressure: end,
  gasMix: GasMix(o2: o2),
);

final _suit = _tank('suit', TankRole.suitInflation, volume: 0.85, end: 150);

void main() {
  group('a suit inflation bottle listed first changes nothing', () {
    final sidemount = [
      _tank('l', TankRole.sidemountLeft),
      _tank('r', TankRole.sidemountRight, end: 140),
    ];
    final backGas = [_tank('b', TankRole.backGas, o2: 32)];

    for (final (name, tanks) in [
      ('sidemount', sidemount),
      ('back gas', backGas),
    ]) {
      test('$name: SAC', () {
        expect(_dive([_suit, ...tanks]).sac, _dive(tanks).sac);
      });

      test('$name: RMV', () {
        const model = GasModel.ideal;
        expect(
          _dive([_suit, ...tanks]).rmvFor(model),
          _dive(tanks).rmvFor(model),
        );
      });

      test('$name: SAC reference cylinder and volume', () {
        final withSuit = _dive([_suit, ...tanks]);
        expect(withSuit.sacReferenceTank, _dive(tanks).sacReferenceTank);
        expect(withSuit.sacReferenceVolume, _dive(tanks).sacReferenceVolume);
      });
    }
  });

  group('a dive whose only cylinder is the suit bottle', () {
    final dive = _dive([_suit]);

    test('has no SAC, RMV or reference cylinder', () {
      expect(dive.sac, isNull);
      expect(dive.rmvFor(GasModel.ideal), isNull);
      expect(dive.sacReferenceTank, isNull);
      expect(dive.sacReferenceVolume, isNull);
    });

    test('still lists it', () {
      expect(dive.tanks, [_suit]);
    });
  });

  group('shared helpers', () {
    test('sacReferenceTankOf never picks the suit bottle', () {
      final stage = _tank('st', TankRole.stage);
      expect(sacReferenceTankOf([_suit, stage]), stage);
      expect(sacReferenceTankOf([_suit]), isNull);
    });

    test('referencePressureDrop adds nothing for the suit bottle', () {
      final back = _tank('b', TankRole.backGas);
      expect(
        referencePressureDrop(reference: back, tanks: [_suit, back]),
        referencePressureDrop(reference: back, tanks: [back]),
      );
    });

    test('a suit bottle as the reference has no drop to count in', () {
      final back = _tank('b', TankRole.backGas);
      expect(
        referencePressureDrop(reference: _suit, tanks: [_suit, back]),
        isNull,
      );
    });
  });
}
