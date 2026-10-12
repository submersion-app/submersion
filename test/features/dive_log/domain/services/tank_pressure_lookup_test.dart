import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';

TankPressurePoint _p(int t, double bar) =>
    TankPressurePoint(tankId: 't', timestamp: t, pressure: bar);

void main() {
  group('pressureAtTime', () {
    final series = [_p(0, 200), _p(60, 190), _p(120, 170)];

    test('is null for an empty series', () {
      expect(pressureAtTime(const [], 30), isNull);
    });

    test('returns an exact sample', () {
      expect(pressureAtTime(series, 60), 190);
    });

    test('interpolates between samples', () {
      expect(pressureAtTime(series, 30), closeTo(195, 1e-9));
      expect(pressureAtTime(series, 90), closeTo(180, 1e-9));
    });

    test('clamps to the nearest sample outside the series', () {
      expect(pressureAtTime(series, -10), 200);
      expect(pressureAtTime(series, 500), 170);
    });

    test('sorts an out-of-order series', () {
      expect(
        pressureAtTime([_p(120, 170), _p(0, 200), _p(60, 190)], 90),
        closeTo(180, 1e-9),
      );
    });

    test('the first of samples sharing a timestamp wins', () {
      expect(pressureAtTime([_p(0, 200), _p(60, 190), _p(60, 185)], 60), 190);
    });
  });
}
