import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';

TankPressureSampleView _sample(
  int timeSeconds, {
  double? pressureBar,
  int? tankIndex,
  List<double?>? tankPressuresBar,
}) => (
  timeSeconds: timeSeconds,
  pressureBar: pressureBar,
  tankIndex: tankIndex,
  tankPressuresBar: tankPressuresBar,
);

void main() {
  group('groupPressuresByTank', () {
    test('keeps every transmitter reported on the same sample', () {
      // Issue #1223: a CCR dive with an O2 and a diluent transmitter reports
      // both on nearly every sample.
      final series = groupPressuresByTank([
        _sample(0, tankPressuresBar: [193.0, 191.0]),
        _sample(10, tankPressuresBar: [192.0, 180.0]),
        _sample(20, tankPressuresBar: [191.0, 170.0]),
      ]);

      expect(series.keys, unorderedEquals([0, 1]));
      expect(series[0]!.map((p) => p.pressure), [193.0, 192.0, 191.0]);
      expect(series[1]!.map((p) => p.pressure), [191.0, 180.0, 170.0]);
      expect(series[0]!.map((p) => p.timestamp), [0, 10, 20]);
    });

    test('skips the tanks that reported nothing at a sample', () {
      // A transmitter that drops out ("no comms") leaves a hole, and the other
      // tank must not inherit it.
      final series = groupPressuresByTank([
        _sample(0, tankPressuresBar: [193.0, 191.0]),
        _sample(10, tankPressuresBar: [192.0, null]),
        _sample(20, tankPressuresBar: [null, 170.0]),
      ]);

      expect(series[0]!.map((p) => p.timestamp), [0, 10]);
      expect(series[1]!.map((p) => p.timestamp), [0, 20]);
    });

    test('falls back to the single reading when no per-tank list is given', () {
      // UDDF/FIT imports and older native builds report one pressure per sample.
      final series = groupPressuresByTank([
        _sample(0, pressureBar: 200.0, tankIndex: 1),
        _sample(10, pressureBar: 190.0, tankIndex: 1),
      ]);

      expect(series.keys, [1]);
      expect(series[1]!.map((p) => p.pressure), [200.0, 190.0]);
    });

    test('treats a missing tank index on the fallback path as tank 0', () {
      final series = groupPressuresByTank([_sample(0, pressureBar: 200.0)]);

      expect(series.keys, [0]);
      expect(series[0]!.single.pressure, 200.0);
    });

    test('prefers the per-tank list over the single reading', () {
      // pressureBar carries whichever transmitter libdivecomputer reported last,
      // so honouring both would duplicate that tank's reading.
      final series = groupPressuresByTank([
        _sample(
          0,
          pressureBar: 191.0,
          tankIndex: 1,
          tankPressuresBar: [193.0, 191.0],
        ),
      ]);

      expect(series[0]!.single.pressure, 193.0);
      expect(series[1]!.single.pressure, 191.0);
      expect(series[1]!, hasLength(1));
    });

    test('ignores samples with no pressure at all', () {
      final series = groupPressuresByTank([
        _sample(0),
        _sample(10, tankPressuresBar: [null, null]),
      ]);

      expect(series, isEmpty);
    });

    test('handles an empty sample list', () {
      expect(groupPressuresByTank(const []), isEmpty);
    });

    test('preserves sample order within each tank', () {
      final series = groupPressuresByTank([
        for (var t = 0; t < 5; t++)
          _sample(t * 10, tankPressuresBar: [200.0 - t, 150.0 - t]),
      ]);

      expect(series[0]!.map((p) => p.timestamp), [0, 10, 20, 30, 40]);
      expect(series[1]!.map((p) => p.pressure), [
        150.0,
        149.0,
        148.0,
        147.0,
        146.0,
      ]);
    });
  });
}
