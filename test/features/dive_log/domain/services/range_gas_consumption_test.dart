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
        avgDepth: 10,
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
        avgDepth: 10,
        model: GasModel.ideal,
      );

      expect(result.sac, closeTo(5.0, 1e-9));
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
        avgDepth: 10,
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
        avgDepth: 10,
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
        avgDepth: 10,
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
        avgDepth: 10,
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
        avgDepth: 10,
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
        avgDepth: 10,
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
          avgDepth: 10,
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
        avgDepth: 10,
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
        avgDepth: 10,
        model: model,
      ).rmv;

      expect(rmv(GasModel.real), lessThan(rmv(GasModel.ideal)!));
    });
  });
}
