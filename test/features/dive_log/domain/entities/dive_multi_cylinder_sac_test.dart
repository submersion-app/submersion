import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// 60 minutes at an average depth of 10 m: 2 bar ambient, so a 120 bar
/// drop is 1.0 bar/min at the surface.
Dive _dive(List<DiveTank> tanks, {DiveMode diveMode = DiveMode.oc}) => Dive(
  id: 'd',
  dateTime: DateTime(2024, 1, 1),
  runtime: const Duration(minutes: 60),
  avgDepth: 10.0,
  diveMode: diveMode,
  tanks: tanks,
);

DiveTank _tank(
  String id,
  TankRole role, {
  double? volume,
  double start = 200,
  double end = 80,
}) => DiveTank(
  id: id,
  role: role,
  volume: volume,
  startPressure: start,
  endPressure: end,
);

void main() {
  // Issue #3109: the overview SAC read only the first cylinder on sidemount
  // and multi-cylinder dives.
  group('Dive.sac across breathed cylinders (#3109)', () {
    test('sums both drops of a sidemount pair with no volumes', () {
      final dive = _dive([
        _tank('l', TankRole.sidemountLeft),
        _tank('r', TankRole.sidemountRight, end: 140),
      ]);
      // (120 + 60) bar / 60 min / 2 bar = 1.5 bar/min
      expect(dive.sac, closeTo(1.5, 1e-9));
    });

    test('sums a sidemount pair when only one cylinder has a volume', () {
      final dive = _dive([
        _tank('l', TankRole.sidemountLeft, volume: 11.1),
        _tank('r', TankRole.sidemountRight, end: 140),
      ]);
      expect(dive.sac, closeTo(1.5, 1e-9));
    });

    test('weights a sidemount pair of different sizes by volume', () {
      final dive = _dive([
        _tank('l', TankRole.sidemountLeft, volume: 12),
        _tank('r', TankRole.sidemountRight, volume: 6),
      ]);
      // 120 + 120 * 6 / 12 = 180 bar of the 12 L reference
      expect(dive.sac, closeTo(1.5, 1e-9));
    });

    test('converts a stage into back-gas bar by volume', () {
      final dive = _dive([
        _tank('b', TankRole.backGas, volume: 12),
        _tank('s', TankRole.stage, volume: 6, end: 140),
      ]);
      // 120 + 60 * 6 / 12 = 150 bar / 60 / 2 = 1.25 bar/min
      expect(dive.sac, closeTo(1.25, 1e-9));
    });

    test('skips a breathed cylinder whose size cannot be related', () {
      final dive = _dive([
        _tank('b', TankRole.backGas, volume: 12),
        _tank('s', TankRole.stage, end: 140),
      ]);
      expect(dive.sac, closeTo(1.0, 1e-9));
    });

    test('a carried but unbreathed cylinder changes nothing', () {
      final dive = _dive([
        _tank('l', TankRole.sidemountLeft, volume: 11.1),
        _tank('r', TankRole.sidemountRight, volume: 11.1),
        _tank('s', TankRole.stage, volume: 11.1, start: 200, end: 200),
      ]);
      expect(dive.sac, closeTo(2.0, 1e-9));
    });

    test('a rebreather dive keeps the single reference cylinder', () {
      final dive = _dive([
        _tank('dil', TankRole.diluent, volume: 3),
        _tank('o2', TankRole.oxygenSupply, volume: 3, end: 140),
      ], diveMode: DiveMode.ccr);
      expect(dive.sac, closeTo(1.0, 1e-9));
    });

    test('stays null when the reference cylinder has no drop', () {
      final dive = _dive([
        _tank('l', TankRole.sidemountLeft, start: 200, end: 200),
        _tank('r', TankRole.sidemountRight),
      ]);
      expect(dive.sac, isNull);
    });
  });

  group('Dive.rmvFor borrows a sidemount partner volume (#3109)', () {
    test('counts the partner that has no volume of its own', () {
      final partial = _dive([
        _tank('l', TankRole.sidemountLeft, volume: 11.1),
        _tank('r', TankRole.sidemountRight, end: 140),
      ]);
      final complete = _dive([
        _tank('l', TankRole.sidemountLeft, volume: 11.1),
        _tank('r', TankRole.sidemountRight, volume: 11.1, end: 140),
      ]);
      expect(
        partial.rmvFor(GasModel.real),
        closeTo(complete.rmvFor(GasModel.real)!, 1e-9),
      );
    });

    test('does not borrow for a cylinder outside the sidemount pair', () {
      final withStage = _dive([
        _tank('b', TankRole.backGas, volume: 12),
        _tank('s', TankRole.stage, end: 140),
      ]);
      final alone = _dive([_tank('b', TankRole.backGas, volume: 12)]);
      expect(
        withStage.rmvFor(GasModel.real),
        closeTo(alone.rmvFor(GasModel.real)!, 1e-9),
      );
    });
  });
}
