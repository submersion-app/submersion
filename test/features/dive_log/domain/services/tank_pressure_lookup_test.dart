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

  group('pressureAtCursor', () {
    final series = [_p(0, 200), _p(60, 190), _p(120, 170)];

    test('is null for an empty series', () {
      expect(pressureAtCursor(const [], 30), isNull);
    });

    test('interpolates between samples and holds past the ends', () {
      expect(pressureAtCursor(series, 60), 190);
      expect(pressureAtCursor(series, 90), closeTo(180, 1e-9));
      expect(pressureAtCursor(series, -10), 200);
      expect(pressureAtCursor(series, 500), 170);
    });

    test('sorts an out-of-order series', () {
      expect(
        pressureAtCursor([_p(120, 170), _p(0, 200), _p(60, 190)], 90),
        closeTo(180, 1e-9),
      );
    });

    // As the profile chart reads its own line and tooltip: the last of the
    // samples sharing the cursor's timestamp, and between timestamps from
    // the last sample before to the first sample after.
    test('the last of samples sharing the cursor timestamp wins', () {
      expect(pressureAtCursor([_p(0, 200), _p(60, 190), _p(60, 185)], 60), 185);
    });

    test('between duplicates, from the last before to the first after', () {
      final dupes = [_p(0, 200), _p(0, 198), _p(100, 150), _p(100, 140)];
      expect(pressureAtCursor(dupes, 50), closeTo(174, 1e-9));
    });

    test('an out-of-order series keeps shared timestamps in input order', () {
      // Long enough that List.sort would use its unstable quicksort.
      final series = [
        for (var i = 0; i < 50; i++) _p(60, 200.0 - i),
        _p(0, 250),
      ];
      expect(pressureAtCursor(series, 60), 151);
    });
  });
}
