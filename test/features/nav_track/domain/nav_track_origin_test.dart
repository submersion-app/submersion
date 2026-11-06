import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_origin.dart';

NavTrackPoint _p(int t, double north, double east, double depth) =>
    NavTrackPoint(timestamp: t, north: north, east: east, depth: depth);

void main() {
  group('rebaseOnActiveStart', () {
    test('moves a recording whose first row is far from the console origin '
        'so the dive starts at 0 / 0', () {
      // An ENC that still holds the dive plan of another site reports every
      // row from that plan's first point (issue #4231).
      final points = [
        _p(0, 36512.32, 6966.22, 2.0),
        _p(2, 36512.18, 6965.86, 2.2),
        _p(4, 36511.79, 6965.14, 3.6),
      ];

      final rebased = rebaseOnActiveStart(points);

      expect(rebased.first.north, 0);
      expect(rebased.first.east, 0);
      expect(rebased[1].north, closeTo(-0.14, 1e-6));
      expect(rebased[1].east, closeTo(-0.36, 1e-6));
      expect(rebased[2].north, closeTo(-0.53, 1e-6));
      expect(rebased[2].east, closeTo(-1.08, 1e-6));
    });

    test('keeps depth, time and every other channel', () {
      const original = NavTrackPoint(
        timestamp: 10,
        north: -253.6,
        east: 159.9,
        depth: 1.9,
        course: 283.9,
        pitch: -58.9,
        roll: -31.3,
        distance: 0.26,
        speed: 0.3,
        temperature: 22,
        batteryVolts: 3.63,
      );

      final rebased = rebaseOnActiveStart([
        original,
        _p(12, -253.5, 159.6, 2.4),
      ]).first;

      expect(rebased.timestamp, 10);
      expect(rebased.depth, 1.9);
      expect(rebased.course, 283.9);
      expect(rebased.pitch, -58.9);
      expect(rebased.roll, -31.3);
      expect(rebased.distance, 0.26);
      expect(rebased.speed, 0.3);
      expect(rebased.temperature, 22);
      expect(rebased.batteryVolts, 3.63);
    });

    test('leaves a recording that already starts at 0 / 0 unchanged', () {
      final points = [_p(0, 0, 0, 1.7), _p(2, 1.5, -2.5, 3.0)];

      expect(rebaseOnActiveStart(points), points);
    });

    test('bases a recording with a pre-dive GPS calibration on the first '
        'dive sample, not on the calibration rows before it', () {
      // Two surface rows, a 120 m GPS re-calibration jump at the surface,
      // then the descent: the dive starts at the third row.
      final points = [
        _p(0, 0, 0, 0),
        _p(2, 0, 0, 0),
        _p(4, 120, 0, 0),
        _p(6, 120, 0, 1.5),
        _p(8, 121, 1, 3.0),
      ];

      final rebased = rebaseOnActiveStart(points);

      expect(rebased[3].north, 0);
      expect(rebased[3].east, 0);
      expect(rebased[4].north, closeTo(1, 1e-9));
      expect(rebased[4].east, closeTo(1, 1e-9));
      // The rows before the dive shift by the same amount, so the jump the
      // segmenter classifies stays exactly as large.
      expect(rebased[0].north, -120);
    });

    test('returns an empty list unchanged', () {
      expect(rebaseOnActiveStart(const []), isEmpty);
    });

    test('never changes the list it was given', () {
      final points = List<NavTrackPoint>.unmodifiable([
        _p(0, 50, 50, 2),
        _p(2, 51, 50, 3),
      ]);

      rebaseOnActiveStart(points);

      expect(points.first.north, 50);
    });
  });
}
