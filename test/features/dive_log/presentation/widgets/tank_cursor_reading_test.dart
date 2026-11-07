import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_cursor_reading.dart';

const _tank = DiveTank(id: 't1', gasMix: GasMix(o2: 21));

EstimatedTankPressures _series(
  List<(int, double)> points, {
  Set<String> estimated = const {},
}) => EstimatedTankPressures({
  't1': [
    for (final (t, p) in points)
      TankPressurePoint(tankId: 't1', timestamp: t, pressure: p),
  ],
}, estimated);

void main() {
  group('tankCursorReading', () {
    test('interpolates between the readings either side', () {
      final reading = tankCursorReading(
        tank: _tank,
        tanks: const [_tank],
        chartSeries: _series([(0, 200), (100, 100)]),
        cursorSeconds: 25,
      );
      expect(reading!.pressure, closeTo(175, 1e-9));
      expect(reading.peak, 200);
      expect(reading.estimated, isFalse);
    });

    test('no cursor still reports the peak, for the reserved label', () {
      final reading = tankCursorReading(
        tank: _tank,
        tanks: const [_tank],
        chartSeries: _series([(0, 180), (60, 210), (100, 90)]),
        cursorSeconds: null,
      );
      expect(reading!.pressure, isNull);
      expect(reading.peak, 210);
    });

    test('marks the estimate', () {
      final reading = tankCursorReading(
        tank: _tank,
        tanks: const [_tank],
        chartSeries: _series([(0, 200), (100, 150)], estimated: {'t1'}),
        cursorSeconds: 50,
      );
      expect(reading!.estimated, isTrue);
    });

    test('a negative reading is no pressure', () {
      final reading = tankCursorReading(
        tank: _tank,
        tanks: const [_tank],
        chartSeries: _series([(0, -5), (100, -5)]),
        cursorSeconds: 50,
      );
      expect(reading!.pressure, isNull);
    });

    test('no line for the tank, no reading', () {
      expect(
        tankCursorReading(
          tank: _tank,
          tanks: const [_tank],
          chartSeries: const EstimatedTankPressures({}, {}),
          cursorSeconds: 50,
        ),
        isNull,
      );
      expect(
        tankCursorReading(
          tank: _tank,
          tanks: const [_tank],
          chartSeries: null,
          cursorSeconds: 50,
        ),
        isNull,
      );
    });
  });
}
