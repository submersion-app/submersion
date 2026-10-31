import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/range_gas_consumption.dart';

/// A pressure series falling linearly from [from] bar at t=0 to [to] bar at
/// t=[end], sampled every 60 s.
List<TankPressurePoint> _linear(
  String tankId, {
  required double from,
  required double to,
  int end = 600,
}) => [
  for (var t = 0; t <= end; t += 60)
    TankPressurePoint(
      tankId: tankId,
      timestamp: t,
      pressure: from + (to - from) * t / end,
    ),
];

/// 10 m throughout, so the ambient pressure over any range is 2 bar.
const _flatAt10m = [
  DiveProfilePoint(timestamp: 0, depth: 10),
  DiveProfilePoint(timestamp: 3600, depth: 10),
];

void main() {
  const backGas = DiveTank(id: 'bg', volume: 12, role: TankRole.backGas);

  group('rangeGasConsumption', () {
    test('reads SAC and RMV from the pressure drop inside the range', () {
      // 200 -> 100 bar over 10 min: 180 bar at 2:00, 130 bar at 7:00. A
      // 50 bar drop over 5 min at 2 bar ambient is 5 bar/min, 60 L/min.
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {'bg': _linear('bg', from: 200, to: 100)},
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5.0, 1e-9));
      expect(result.rmv, closeTo(60.0, 1e-9));
    });

    test('interpolates between pressure samples at the range edges', () {
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {'bg': _linear('bg', from: 200, to: 100)},
        // 1:30 -> 185 bar, 6:30 -> 135 bar: the same 50 bar over 5 min.
        startTimestamp: 90,
        endTimestamp: 390,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5.0, 1e-9));
    });

    test('counts only the time the pressure series covers (#3890)', () {
      // Readings start at 5:00, falling 10 bar a minute. A 4:00 to 6:00
      // selection sees the one minute's 10 bar, which is not 5 bar/min.
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {
          'bg': [
            for (var t = 300; t <= 600; t += 60)
              TankPressurePoint(
                tankId: 'bg',
                timestamp: t,
                pressure: 200 - (t - 300) / 6,
              ),
          ],
        },
        startTimestamp: 240,
        endTimestamp: 360,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      // 10 bar/min at 2 bar ambient.
      expect(result.sac, closeTo(5, 1e-9));
      expect(result.rmv, closeTo(60, 1e-9));
    });

    test('stops counting where the pressure series ends (#3890)', () {
      // Readings stop at 5:00, falling 10 bar a minute. A 4:00 to 6:00
      // selection again sees one minute's 10 bar.
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {
          'bg': [
            for (var t = 0; t <= 300; t += 60)
              TankPressurePoint(
                tankId: 'bg',
                timestamp: t,
                pressure: 200 - t / 6,
              ),
          ],
        },
        startTimestamp: 240,
        endTimestamp: 360,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5, 1e-9));
      expect(result.rmv, closeTo(60, 1e-9));
    });

    test('cylinders breathed in turn cover the selection between them', () {
      // Each series reads for half of the range, and each falls 20 bar: 40
      // bar over all four minutes, not over either cylinder's two.
      final result = rangeGasConsumption(
        tanks: const [
          backGas,
          DiveTank(id: 'stage', volume: 12, role: TankRole.stage, order: 1),
        ],
        tankPressures: {
          'bg': [
            for (var t = 0; t <= 120; t += 60)
              TankPressurePoint(
                tankId: 'bg',
                timestamp: t,
                pressure: 200 - t / 6,
              ),
          ],
          'stage': [
            for (var t = 120; t <= 240; t += 60)
              TankPressurePoint(
                tankId: 'stage',
                timestamp: t,
                pressure: 200 - (t - 120) / 6,
              ),
          ],
        },
        startTimestamp: 0,
        endTimestamp: 240,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.rmv, closeTo(60, 1e-9));
    });

    group('depth over the pressure coverage (#3973)', () {
      // 30 m, up to 10 m over the fifth minute, then 10 m to 10:00.
      const profile = [
        DiveProfilePoint(timestamp: 0, depth: 30),
        DiveProfilePoint(timestamp: 240, depth: 30),
        DiveProfilePoint(timestamp: 300, depth: 10),
        DiveProfilePoint(timestamp: 600, depth: 10),
      ];

      // 200 -> 150 bar across the 10 m stretch alone: 50 bar over 5 min at
      // 2 bar ambient is 5 bar/min, 60 L/min of 12 L.
      const lateStart = [
        TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 200),
        TankPressurePoint(tankId: 'bg', timestamp: 600, pressure: 150),
      ];

      RangeGasConsumption over(
        int start,
        int end, {
        Map<String, List<TankPressurePoint>> pressures = const {
          'bg': lateStart,
        },
        List<DiveProfilePoint> profile = profile,
        List<DiveTank> tanks = const [backGas],
      }) => rangeGasConsumption(
        tanks: tanks,
        tankPressures: pressures,
        startTimestamp: start,
        endTimestamp: end,
        profile: profile,
        model: GasModel.ideal,
      );

      test('a selection of the covered stretch alone', () {
        final result = over(300, 600);

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, closeTo(60, 1e-9));
      });

      test('reaching back before the readings leaves the rate alone', () {
        final result = over(0, 600);

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, closeTo(60, 1e-9));
      });

      test('reaching past the readings leaves the rate alone', () {
        // 200 -> 120 bar over the 30 m stretch alone: 80 bar over 4 min at
        // 4 bar ambient is 5 bar/min, 60 L/min of 12 L.
        final result = over(
          0,
          600,
          pressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 240, pressure: 120),
            ],
          },
        );

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, closeTo(60, 1e-9));
      });

      test('a selection inside the readings uses its own depth', () {
        // 240 s to 300 s, the ascent: 20 m on average, so 3 bar ambient.
        // The series reads the whole 10 min, falling 1 bar every 6 s, so
        // this is 10 bar over the minute.
        final result = over(
          240,
          300,
          pressures: {'bg': _linear('bg', from: 200, to: 100)},
        );

        expect(result.sac, closeTo(10 / 3, 1e-9));
        expect(result.rmv, closeTo(40, 1e-9));
      });

      test('cylinders read together span from the first to the last', () {
        // The stage reads from 2:00 and the back gas only from 5:00, so the
        // time and the depth both run from 2:00 to 10:00.
        final result = over(
          0,
          600,
          tanks: const [
            backGas,
            DiveTank(id: 'stage', volume: 12, role: TankRole.stage, order: 1),
          ],
          pressures: const {
            'bg': lateStart,
            'stage': [
              TankPressurePoint(tankId: 'stage', timestamp: 120, pressure: 200),
              TankPressurePoint(tankId: 'stage', timestamp: 600, pressure: 152),
            ],
          },
        );

        // 2:00 to 4:00 at 30 m, the ascent at 20 m on average, 5:00 to 10:00
        // at 10 m: (120 * 30 + 60 * 20 + 300 * 10) / 480 is 16.25 m, so
        // 2.625 bar ambient. 98 bar of 12 L over 8 min.
        expect(result.sac, closeTo(98 / 8 / 2.625, 1e-9));
        expect(result.rmv, closeTo(98 * 12 / 8 / 2.625, 1e-9));
      });

      test('time between two series that do not touch counts for nothing', () {
        // Each series falls 20 bar in 2 min, 3 min apart. The gap is 30 m to
        // 10 m, the first series at 30 m and the second at 10 m: 40 bar over
        // 4 min, (120 * 30 + 120 * 10) / 240 is 20 m, so 3 bar ambient.
        final result = over(
          0,
          420,
          tanks: const [
            backGas,
            DiveTank(id: 'stage', volume: 12, role: TankRole.stage, order: 1),
          ],
          pressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 120, pressure: 180),
            ],
            'stage': [
              TankPressurePoint(tankId: 'stage', timestamp: 300, pressure: 200),
              TankPressurePoint(tankId: 'stage', timestamp: 420, pressure: 180),
            ],
          },
        );

        expect(result.sac, closeTo(40 / 4 / 3, 1e-9));
        expect(result.rmv, closeTo(40 * 12 / 4 / 3, 1e-9));
      });

      test('a cylinder a lane does not count adds nothing to its time', () {
        // Neither cylinder has a size, so SAC reads the back gas alone: 50
        // bar over the 5 min at 10 m, not 9 min reaching back over the stage.
        final result = over(
          0,
          600,
          tanks: const [
            DiveTank(id: 'bg', role: TankRole.backGas),
            DiveTank(id: 'stage', role: TankRole.stage, order: 1),
          ],
          pressures: const {
            'bg': lateStart,
            'stage': [
              TankPressurePoint(tankId: 'stage', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'stage', timestamp: 240, pressure: 160),
            ],
          },
        );

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, isNull);
      });

      test('RMV keeps to the cylinders with a volume', () {
        // The sized back gas gives RMV over its own 5 min at 10 m; SAC also
        // counts only it, the unsized stage being unrelated to it.
        final result = over(
          0,
          600,
          tanks: const [
            backGas,
            DiveTank(id: 'stage', role: TankRole.stage, order: 1),
          ],
          pressures: const {
            'bg': lateStart,
            'stage': [
              TankPressurePoint(tankId: 'stage', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'stage', timestamp: 240, pressure: 160),
            ],
          },
        );

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, closeTo(60, 1e-9));
      });

      test('readings sharing one timestamp cover no time', () {
        final result = over(
          0,
          600,
          pressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 150),
            ],
          },
        );

        expect(result.sac, isNull);
        expect(result.rmv, isNull);
      });

      test('a profile stopping early ends the gas use with its depth', () {
        // The line stops at 6:40, 10 bar into a 100 bar fall: 10 bar over
        // 100 s at 2 bar ambient, not 100 bar over the 5 min it did not reach.
        final result = over(
          0,
          600,
          profile: const [
            DiveProfilePoint(timestamp: 300, depth: 10),
            DiveProfilePoint(timestamp: 340, depth: 10),
            DiveProfilePoint(timestamp: 400, depth: 10),
          ],
          pressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 400, pressure: 190),
              TankPressurePoint(tankId: 'bg', timestamp: 600, pressure: 100),
            ],
          },
        );

        expect(result.sac, closeTo(3, 1e-9));
        expect(result.rmv, closeTo(36, 1e-9));
      });

      test('a profile starting late starts the gas use with its depth', () {
        // The line starts at 5:00, trimmed, so it has no lead-in: 50 bar
        // over the 5 min at 2 bar ambient, not 60 bar over all 10.
        final result = over(
          0,
          600,
          profile: const [
            DiveProfilePoint(timestamp: 300, depth: 10),
            DiveProfilePoint(timestamp: 400, depth: 10),
            DiveProfilePoint(timestamp: 600, depth: 10),
          ],
          pressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 190),
              TankPressurePoint(tankId: 'bg', timestamp: 600, pressure: 140),
            ],
          },
        );

        expect(result.sac, closeTo(5, 1e-9));
        expect(result.rmv, closeTo(60, 1e-9));
      });

      test('a profile of one sample has no time to measure over', () {
        final result = over(
          300,
          600,
          profile: const [DiveProfilePoint(timestamp: 400, depth: 10)],
        );

        expect(result.sac, isNull);
        expect(result.rmv, isNull);
      });

      test('nothing when the profile does not reach the readings', () {
        final result = over(
          0,
          600,
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 30),
            DiveProfilePoint(timestamp: 240, depth: 30),
          ],
        );

        expect(result.sac, isNull);
        expect(result.rmv, isNull);
      });

      test('an empty profile yields nothing', () {
        final result = over(300, 600, profile: const []);

        expect(result.sac, isNull);
        expect(result.rmv, isNull);
      });
    });

    test('a tank without a pressure series yields nothing', () {
      // Start and end pressures describe the whole dive, not the range.
      final result = rangeGasConsumption(
        tanks: const [
          DiveTank(id: 'bg', volume: 12, startPressure: 200, endPressure: 50),
        ],
        tankPressures: const {},
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, isNull);
      expect(result.rmv, isNull);
    });

    test('a series filed under a stale tank id is adopted', () {
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {'old-id': _linear('old-id', from: 200, to: 100)},
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5.0, 1e-9));
    });

    test('RMV needs a cylinder volume; SAC does not', () {
      final result = rangeGasConsumption(
        tanks: const [DiveTank(id: 'bg')],
        tankPressures: {'bg': _linear('bg', from: 200, to: 100)},
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5.0, 1e-9));
      expect(result.rmv, isNull);
    });

    test('a sidemount pair adds both cylinders', () {
      const left = DiveTank(id: 'l', volume: 12, role: TankRole.sidemountLeft);
      // The right cylinder borrows its partner's size.
      const right = DiveTank(id: 'r', role: TankRole.sidemountRight, order: 1);
      final result = rangeGasConsumption(
        tanks: const [left, right],
        tankPressures: {
          'l': _linear('l', from: 200, to: 150),
          'r': _linear('r', from: 200, to: 150),
        },
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      // 25 bar from each over 5 min at 2 bar ambient.
      expect(result.sac, closeTo(5.0, 1e-9));
      expect(result.rmv, closeTo(60.0, 1e-9));
    });

    test('a range on the stage counts the stage in RMV', () {
      const stage = DiveTank(
        id: 'st',
        volume: 7,
        role: TankRole.stage,
        gasMix: GasMix(o2: 50),
        order: 1,
      );
      final result = rangeGasConsumption(
        tanks: const [backGas, stage],
        tankPressures: {
          'bg': _linear('bg', from: 150, to: 150),
          'st': _linear('st', from: 200, to: 152),
        },
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      // 24 bar of a 7 L stage over 5 min at 2 bar ambient: 16.8 L/min.
      expect(result.rmv, closeTo(16.8, 1e-9));
      // SAC is in bar of the back gas, which did not drop.
      expect(result.sac, isNull);
    });

    test('a rebreather range has no SAC and no RMV (#3673)', () {
      const diluent = DiveTank(id: 'dil', volume: 3, role: TankRole.diluent);
      const oxygen = DiveTank(
        id: 'o2',
        volume: 3,
        role: TankRole.oxygenSupply,
        gasMix: GasMix(o2: 100),
        order: 1,
      );
      final result = rangeGasConsumption(
        tanks: const [diluent, oxygen],
        tankPressures: {
          'dil': _linear('dil', from: 200, to: 180),
          'o2': _linear('o2', from: 200, to: 160),
        },
        startTimestamp: 0,
        endTimestamp: 600,
        profile: _flatAt10m,
        model: GasModel.ideal,
        isRebreather: true,
      );

      expect(result.sac, isNull);
      expect(result.rmv, isNull);
    });

    test('an empty or reversed range yields nothing', () {
      for (final (start, end) in [(300, 300), (420, 120)]) {
        final result = rangeGasConsumption(
          tanks: const [backGas],
          tankPressures: {'bg': _linear('bg', from: 200, to: 100)},
          startTimestamp: start,
          endTimestamp: end,
          profile: _flatAt10m,
          model: GasModel.ideal,
        );
        expect(result.sac, isNull, reason: '$start..$end');
        expect(result.rmv, isNull, reason: '$start..$end');
      }
    });

    test('a pressure that rises across the range yields nothing', () {
      final result = rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {'bg': _linear('bg', from: 100, to: 110)},
        startTimestamp: 120,
        endTimestamp: 420,
        profile: _flatAt10m,
        model: GasModel.ideal,
      );

      expect(result.sac, isNull);
      expect(result.rmv, isNull);
    });

    test('the real gas model yields less gas than the ideal one', () {
      double? rmv(GasModel model) => rangeGasConsumption(
        tanks: const [backGas],
        tankPressures: {'bg': _linear('bg', from: 230, to: 30)},
        startTimestamp: 0,
        endTimestamp: 600,
        profile: _flatAt10m,
        model: model,
      ).rmv;

      expect(rmv(GasModel.real), lessThan(rmv(GasModel.ideal)!));
    });
  });
}
