import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_cursor_line.dart';

const _tank = DiveTank(id: 't1', gasMix: GasMix(o2: 21));

TankCursorLine? _line(
  List<(int, double)> points, {
  String key = 't1',
  Set<String> estimated = const {},
}) => TankCursorLine.forTanks(
  const [_tank],
  EstimatedTankPressures({
    key: [
      for (final (t, p) in points)
        TankPressurePoint(tankId: key, timestamp: t, pressure: p),
    ],
  }, estimated),
)['t1'];

void main() {
  group('TankCursorLine', () {
    test('interpolates between the readings either side', () {
      final line = _line([(0, 200), (100, 100)])!;
      expect(line.pressureAt(25), closeTo(175, 1e-9));
      expect(line.estimated, isFalse);
    });

    test('no cursor, no pressure, but the peak is known', () {
      final line = _line([(0, 180), (60, 210), (100, 90)])!;
      expect(line.pressureAt(null), isNull);
      expect(line.peak, 210);
    });

    test('marks the estimate', () {
      expect(_line([(0, 200), (100, 150)], estimated: {'t1'})!.estimated, true);
    });

    test('a negative reading is no pressure', () {
      expect(_line([(0, -5), (100, -10)])!.pressureAt(50), isNull);
    });

    test('a series keyed by an old tank id is matched', () {
      expect(_line([(0, 200), (100, 100)], key: 'old')!.pressureAt(50), 150);
    });

    test(
      'a timestamp shared by two readings reads the last, as the chart does',
      () {
        expect(
          _line([(0, 200), (50, 160), (50, 150), (100, 100)])!.pressureAt(50),
          150,
        );
      },
    );

    test('no lines when the chart cannot scale them', () {
      // Every reading of every tank identical (a pressure channel logged
      // with no transmitter paired): the chart draws no pressure line.
      expect(_line([(0, 0), (100, 0)]), isNull);
      // A single reading has no range either.
      expect(_line([(30, 200)]), isNull);
    });

    test('a flat tank beside a draining one keeps its line', () {
      const stage = DiveTank(id: 't2', gasMix: GasMix(o2: 50));
      final lines = TankCursorLine.forTanks(
        const [_tank, stage],
        const EstimatedTankPressures({
          't1': [
            TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 't1', timestamp: 100, pressure: 100),
          ],
          't2': [
            TankPressurePoint(tankId: 't2', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 't2', timestamp: 100, pressure: 200),
          ],
        }, {}),
      );
      expect(lines['t2']!.pressureAt(50), 200);
    });

    test('no line for the tank, none here', () {
      expect(_line(const []), isNull);
      expect(TankCursorLine.forTanks(const [_tank], null), isEmpty);
      expect(
        TankCursorLine.forTanks(const [
          _tank,
        ], const EstimatedTankPressures({}, {})),
        isEmpty,
      );
    });
  });
}
