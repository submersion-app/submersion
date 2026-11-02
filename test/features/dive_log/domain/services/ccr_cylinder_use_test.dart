import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_cylinder_use.dart';

DiveTank _tank(
  String id,
  TankRole role, {
  double? volume = 7,
  double? start,
  double? end,
  double o2 = 21,
  int order = 0,
}) => DiveTank(
  id: id,
  volume: volume,
  startPressure: start,
  endPressure: end,
  gasMix: GasMix(o2: o2),
  role: role,
  order: order,
);

GasSwitchWithTank _switchTo(String tankId, int timestamp) => GasSwitchWithTank(
  gasSwitch: GasSwitch(
    id: 'sw-$tankId-$timestamp',
    diveId: 'dive',
    timestamp: timestamp,
    tankId: tankId,
    createdAt: DateTime.utc(2026),
  ),
  tankName: tankId,
  gasMix: 'Air',
  o2Fraction: 0.21,
);

List<TankPressurePoint> _series(String tankId, List<(int, double)> samples) => [
  for (final (t, bar) in samples)
    TankPressurePoint(tankId: tankId, timestamp: t, pressure: bar),
];

CcrDiveUse _use(
  List<DiveTank> tanks, {
  List<GasSwitchWithTank>? switches,
  Map<String, List<TankPressurePoint>>? pressures,
  int diveEnd = 3600,
  GasModel gasModel = GasModel.ideal,
}) => ccrDiveUse(
  tanks: tanks,
  gasSwitches: switches,
  tankPressures: pressures,
  diveEnd: diveEnd,
  gasModel: gasModel,
);

CcrCylinderUse _of(CcrDiveUse use, String tankId) =>
    use.cylinders.singleWhere((c) => c.tankId == tankId);

void main() {
  group('the timeline', () {
    test('no switches means the whole dive is loop time', () {
      final use = _use([_tank('d', TankRole.diluent, start: 200, end: 150)]);
      expect(use.loopSeconds, 3600);
    });

    test('a return to the loop onto a Diluent cylinder ends the bailout', () {
      final use = _use(
        [
          _tank('d', TankRole.diluent, start: 200, end: 150),
          _tank('b', TankRole.bailout, start: 200, end: 190),
        ],
        switches: [_switchTo('b', 1000), _switchTo('d', 1300)],
      );
      expect(use.loopSeconds, 3300);
    });

    test('a return onto a Sidemount cylinder stays bailout (known limit)', () {
      final use = _use(
        [
          _tank('b', TankRole.bailout, start: 200, end: 190),
          _tank('s', TankRole.sidemountRight, start: 200, end: 150),
        ],
        switches: [_switchTo('b', 1000), _switchTo('s', 1300)],
      );
      expect(use.loopSeconds, 1000);
    });

    test('a switch in the first 60 seconds is ignored', () {
      final use = _use(
        [
          _tank('s', TankRole.sidemountRight, start: 200, end: 150),
          _tank('o2', TankRole.oxygenSupply, volume: 2, start: 200, end: 150),
        ],
        switches: [_switchTo('s', 30)],
      );
      expect(use.loopSeconds, 3600);
      expect(_of(use, 's').loopRate, closeTo(50 * 7 / 60, 1e-9));
    });

    test('a switch at 61 seconds counts', () {
      final use = _use(
        [_tank('s', TankRole.sidemountRight, start: 200, end: 150)],
        switches: [_switchTo('s', 61)],
      );
      expect(use.loopSeconds, 61);
    });

    test('a switch naming a stale tank is ignored', () {
      final use = _use(
        [_tank('d', TankRole.diluent, start: 200, end: 150)],
        switches: [_switchTo('gone', 1000)],
      );
      expect(use.loopSeconds, 3600);
    });

    test('a switch after the end of the dive is ignored', () {
      final use = _use(
        [
          _tank('d', TankRole.diluent, start: 200, end: 150),
          _tank('b', TankRole.bailout, start: 200, end: 200),
        ],
        switches: [_switchTo('b', 3700)],
      );
      expect(use.loopSeconds, 3600);
    });

    test('bailed out from early on leaves almost no loop time', () {
      final use = _use(
        [
          _tank('d', TankRole.diluent, start: 200, end: 190),
          _tank('b', TankRole.bailout, start: 200, end: 100),
        ],
        switches: [_switchTo('b', 61)],
      );
      expect(use.loopSeconds, 61);
      expect(_of(use, 'd').loopRate, closeTo(10 * 7 / (61 / 60), 1e-9));
    });

    test('no runtime gives no rates and still one entry per tank', () {
      final use = _use([
        _tank('d', TankRole.diluent, start: 200, end: 150),
        _tank('o2', TankRole.oxygenSupply, start: 200, end: 150, o2: 100),
      ], diveEnd: 0);
      expect(use.loopSeconds, 0);
      expect(use.cylinders, hasLength(2));
      expect(_of(use, 'd').loopRate, isNull);
      expect(_of(use, 'o2').loopRate, isNull);
      expect(use.o2Rate, isNull);
      expect(use.diluentRate, isNull);
    });
  });

  group('logged pressures only', () {
    test('the issue dive: sidemount cylinders and an O2 supply', () {
      final use = _use([
        _tank('left', TankRole.sidemountLeft, start: 221, end: 220),
        _tank('right', TankRole.sidemountRight, start: 216, end: 163),
        _tank(
          'o2',
          TankRole.oxygenSupply,
          volume: 1.5,
          start: 174,
          end: 102,
          o2: 100,
        ),
      ]);
      expect(use.loopSeconds, 3600);
      expect(_of(use, 'left').loopRate, isNull);
      expect(_of(use, 'right').loopRate, closeTo(371 / 60, 1e-9));
      expect(_of(use, 'o2').loopRate, closeTo(108 / 60, 1e-9));
      expect(use.o2Rate, closeTo(1.8, 1e-9));
      expect(use.diluentRate, closeTo(371 / 60, 1e-9));
    });

    test('the cylinder bailed onto is all bailout', () {
      final use = _use(
        [_tank('right', TankRole.sidemountRight, start: 216, end: 163)],
        switches: [_switchTo('right', 3000)],
      );
      final right = _of(use, 'right');
      expect(right.loopRate, isNull);
      expect(right.bailoutStartBar, 216);
      expect(right.bailoutEndBar, 163);
      expect(right.bailoutWindows, [(start: 3000, end: 3600)]);
    });

    test('a cylinder not bailed onto is all loop', () {
      final use = _use(
        [
          _tank('b', TankRole.bailout, start: 200, end: 160),
          _tank('s', TankRole.stage, start: 200, end: 160),
        ],
        switches: [_switchTo('b', 3000)],
      );
      expect(_of(use, 'b').bailoutStartBar, 200);
      expect(_of(use, 's').bailoutStartBar, isNull);
      expect(_of(use, 's').loopRate, closeTo(40 * 7 / 50, 1e-9));
    });

    test('a matched pair sharing one switch both count as bailout', () {
      final use = _use(
        [
          _tank('left', TankRole.sidemountLeft, start: 200, end: 150),
          _tank('right', TankRole.sidemountRight, start: 200, end: 150),
        ],
        switches: [_switchTo('left', 3000)],
      );
      for (final id in ['left', 'right']) {
        expect(_of(use, id).bailoutWindows, isNotEmpty);
        expect(_of(use, id).loopRate, isNull);
      }
    });

    test('a marked loop cylinder stays loop gas', () {
      final use = _use(
        [
          _tank('d', TankRole.diluent, start: 200, end: 150),
          _tank('b', TankRole.bailout, start: 200, end: 200),
        ],
        switches: [_switchTo('b', 3000)],
      );
      expect(_of(use, 'd').loopRate, closeTo(50 * 7 / 50, 1e-9));
    });

    test('an end pressure above the start gives no gas', () {
      final use = _use([_tank('d', TankRole.diluent, start: 150, end: 160)]);
      expect(_of(use, 'd').loopLiters, 0);
      expect(_of(use, 'd').loopRate, isNull);
    });

    test('missing pressures give no gas', () {
      final use = _use([_tank('d', TankRole.diluent)]);
      expect(_of(use, 'd').loopLiters, 0);
      expect(_of(use, 'd').loopRate, isNull);
    });
  });

  group('with a pressure series', () {
    test('a shared cylinder splits loop and bailout', () {
      final use = _use(
        [_tank('right', TankRole.sidemountRight, start: 216, end: 163)],
        switches: [_switchTo('right', 3000)],
        pressures: {
          'right': _series('right', [(0, 216), (3000, 180), (3600, 163)]),
        },
      );
      final right = _of(use, 'right');
      expect(use.loopSeconds, 3000);
      expect(right.loopRate, closeTo(36 * 7 / 50, 1e-9));
      expect(right.bailoutStartBar, 180);
      expect(right.bailoutEndBar, 163);
      expect(right.bailoutWindows, [(start: 3000, end: 3600)]);
    });

    test('an O2 supply ignores its drop during a bailout', () {
      final use = _use(
        [
          _tank(
            'o2',
            TankRole.oxygenSupply,
            volume: 1.5,
            start: 200,
            end: 140,
            o2: 100,
          ),
          _tank('b', TankRole.bailout, start: 200, end: 180),
        ],
        switches: [_switchTo('b', 3000)],
        pressures: {
          'o2': _series('o2', [(0, 200), (3000, 150), (3600, 140)]),
        },
      );
      expect(_of(use, 'o2').loopRate, closeTo(50 * 1.5 / 50, 1e-9));
      expect(_of(use, 'o2').bailoutStartBar, isNull);
    });

    test('a dropout does not count as a drop', () {
      final use = _use(
        [_tank('d', TankRole.diluent)],
        pressures: {
          'd': _series('d', [(0, 200), (100, 0), (200, 199), (3600, 190)]),
        },
      );
      expect(_of(use, 'd').loopRate, closeTo(10 * 7 / 60, 1e-9));
    });

    test('a flat series falls back to logged pressures', () {
      final use = _use(
        [_tank('d', TankRole.diluent, start: 200, end: 150)],
        pressures: {
          'd': _series('d', [(0, 200), (3600, 200)]),
        },
      );
      expect(_of(use, 'd').loopRate, closeTo(50 * 7 / 60, 1e-9));
    });

    test('a period whose pressure rises counts as zero', () {
      final use = _use(
        [
          _tank('d', TankRole.diluent),
          _tank('b', TankRole.bailout, start: 200, end: 200),
        ],
        switches: [_switchTo('b', 1000), _switchTo('d', 1200)],
        pressures: {
          'd': _series('d', [(0, 200), (1000, 190), (1200, 190), (3600, 195)]),
        },
      );
      expect(use.loopSeconds, 3400);
      expect(_of(use, 'd').loopLiters, closeTo(10 * 7, 1e-9));
    });

    test('a series ending early uses its last reading', () {
      final use = _use(
        [_tank('d', TankRole.diluent)],
        pressures: {
          'd': _series('d', [(0, 200), (1800, 170)]),
        },
      );
      expect(_of(use, 'd').loopRate, closeTo(30 * 7 / 60, 1e-9));
    });

    test('a cylinder keeps only the gas lost while it was breathed', () {
      // Bailed onto a at 1000 s, then b at 2000 s. a's later drop is cooling.
      final use = _use(
        [_tank('a', TankRole.bailout), _tank('b', TankRole.bailout)],
        switches: [_switchTo('a', 1000), _switchTo('b', 2000)],
        pressures: {
          'a': _series('a', [(0, 200), (1000, 200), (2000, 150), (3600, 140)]),
        },
      );
      expect(_of(use, 'a').bailoutWindows, [(start: 1000, end: 2000)]);
      expect(_of(use, 'a').bailoutStartBar, 200);
      expect(_of(use, 'a').bailoutEndBar, 150);
    });

    test('the minimum drop applies to the loop share of a series', () {
      // 30 bar lost in all, only 15 of it on the loop.
      final use = _use(
        [_tank('s', TankRole.sidemountRight)],
        switches: [_switchTo('s', 3000)],
        pressures: {
          's': _series('s', [(0, 200), (3000, 185), (3600, 170)]),
        },
      );
      expect(_of(use, 's').loopRate, isNull);
      expect(_of(use, 's').bailoutStartBar, 185);
      expect(_of(use, 's').bailoutEndBar, 170);
    });
  });

  group('the minimum drop', () {
    test('an unbreathed bailout that lost 13 bar has no loop gas', () {
      final use = _use([_tank('b', TankRole.bailout, start: 200, end: 187)]);
      expect(_of(use, 'b').loopLiters, 0);
      expect(_of(use, 'b').loopRate, isNull);
      expect(use.diluentRate, isNull);
    });

    test('exactly 20 bar does not count', () {
      final use = _use([_tank('b', TankRole.bailout, start: 200, end: 180)]);
      expect(_of(use, 'b').loopRate, isNull);
    });

    test('21 bar counts', () {
      final use = _use([_tank('b', TankRole.bailout, start: 200, end: 179)]);
      expect(_of(use, 'b').loopRate, closeTo(21 * 7 / 60, 1e-9));
    });

    test('a Diluent cylinder has no minimum', () {
      final use = _use([_tank('d', TankRole.diluent, start: 200, end: 195)]);
      expect(_of(use, 'd').loopRate, closeTo(5 * 7 / 60, 1e-9));
    });

    test('an O2 Supply cylinder has no minimum', () {
      final use = _use([
        _tank('o2', TankRole.oxygenSupply, start: 200, end: 195, o2: 100),
      ]);
      expect(_of(use, 'o2').loopRate, closeTo(5 * 7 / 60, 1e-9));
    });
  });

  group('the O2 and diluent lines', () {
    test('pure O2 in a Sidemount cylinder counts toward O2', () {
      final use = _use([
        _tank(
          'o2',
          TankRole.sidemountLeft,
          volume: 3,
          start: 200,
          end: 150,
          o2: 100,
        ),
      ]);
      expect(use.o2Rate, closeTo(50 * 3 / 60, 1e-9));
      expect(use.diluentRate, isNull);
    });

    test('an untagged pure O2 back gas is the O2 line with no minimum', () {
      final use = _use([
        _tank('o2', TankRole.backGas, volume: 3, start: 200, end: 190, o2: 100),
      ]);
      expect(_of(use, 'o2').loopRate, closeTo(10 * 3 / 60, 1e-9));
      expect(use.o2Rate, closeTo(10 * 3 / 60, 1e-9));
    });

    test('every other cylinder adds up in the diluent line', () {
      final use = _use([
        _tank('left', TankRole.sidemountLeft, start: 200, end: 170),
        _tank('right', TankRole.sidemountRight, start: 200, end: 150),
      ]);
      expect(use.diluentRate, closeTo((30 + 50) * 7 / 60, 1e-9));
    });
  });

  group('volume', () {
    test('unknown volume gives no rate', () {
      final use = _use([
        _tank('d', TankRole.diluent, volume: null, start: 200, end: 150),
      ]);
      expect(_of(use, 'd').loopLiters, 0);
      expect(_of(use, 'd').loopRate, isNull);
    });

    test('a matched partner lends its volume', () {
      final use = _use([
        _tank(
          'left',
          TankRole.sidemountLeft,
          volume: null,
          start: 200,
          end: 150,
        ),
        _tank('right', TankRole.sidemountRight, start: 200, end: 200),
      ]);
      expect(_of(use, 'left').loopRate, closeTo(50 * 7 / 60, 1e-9));
    });

    test('the real gas model uses gasVolume at each pressure', () {
      final use = _use([
        _tank('d', TankRole.diluent, start: 300, end: 200),
      ], gasModel: GasModel.real);
      double volumeAt(double bar) => gasVolume(
        tankSizeLiters: 7,
        pressureBar: bar,
        o2Percent: 21,
        hePercent: 0,
        model: GasModel.real,
      );
      expect(
        _of(use, 'd').loopLiters,
        closeTo(volumeAt(300) - volumeAt(200), 1e-9),
      );
      expect(_of(use, 'd').loopLiters, isNot(closeTo(700, 1)));
    });
  });
}
