import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/profile/surfacing_pressure.dart';

void main() {
  SurfacingProfilePoint point(
    int timeSeconds,
    double depthMeters, [
    Map<int, double> pressures = const {},
  ]) {
    return SurfacingProfilePoint(
      timeSeconds: timeSeconds,
      depthMeters: depthMeters,
      tankPressuresBar: pressures,
    );
  }

  group('surfacingTankReadings', () {
    test('splits each cylinder into its surfacing and post-surfacing '
        'readings', () {
      // Issue #1092: a CCR oxygen cylinder bleeds down through the constant
      // mass flow orifice while the computer keeps recording on the surface.
      final points = [
        point(0, 0.0, {1: 200.0}),
        point(600, 40.0, {1: 120.0}),
        point(3970, 1.2, {1: 41.0}),
        point(4000, 0.0, {1: 30.0}),
        point(4090, 0.0, {1: 4.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[1]!.atSurfacing, 41.0);
      expect(readings[1]!.lastAfterSurfacing, 4.0);
    });

    test('reads every cylinder independently', () {
      final points = [
        point(0, 5.0, {0: 200.0, 1: 180.0}),
        point(600, 2.0, {0: 150.0, 1: 41.0}),
        point(900, 0.0, {0: 149.0, 1: 4.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 150.0);
      expect(readings[0]!.lastAfterSurfacing, 149.0);
      expect(readings[1]!.atSurfacing, 41.0);
      expect(readings[1]!.lastAfterSurfacing, 4.0);
    });

    test('carries a cylinder forward when the surfacing sample omits it', () {
      // Transmitters report on their own cadence, so the sample that happens to
      // be the deepest-last one may carry no reading for a given cylinder.
      final points = [
        point(0, 20.0, {0: 200.0, 1: 180.0}),
        point(600, 10.0, {1: 150.0}),
        point(900, 3.0, {0: 120.0}),
        point(1200, 0.0, {0: 60.0, 1: 20.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 120.0);
      expect(readings[1]!.atSurfacing, 150.0);
    });

    test('reports no tail reading when the recording ends at surfacing', () {
      final points = [
        point(0, 20.0, {0: 200.0}),
        point(600, 10.0, {0: 120.0}),
        point(900, 3.0, {0: 60.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 60.0);
      expect(readings[0]!.lastAfterSurfacing, isNull);
    });

    test('uses the final descent when the diver re-descends', () {
      final points = [
        point(0, 20.0, {0: 200.0}),
        point(300, 0.0, {0: 160.0}),
        point(600, 15.0, {0: 140.0}),
        point(900, 5.0, {0: 100.0}),
        point(1200, 0.0, {0: 90.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 100.0);
      expect(readings[0]!.lastAfterSurfacing, 90.0);
    });

    test('treats a sample at the surface threshold as surfaced', () {
      final points = [
        point(0, 10.0, {0: 200.0}),
        point(300, kSurfaceThresholdMeters, {0: 150.0}),
        point(600, 0.0, {0: 100.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 200.0);
      expect(readings[0]!.lastAfterSurfacing, 100.0);
    });

    test('omits a cylinder first seen after surfacing', () {
      final points = [
        point(0, 10.0, {0: 200.0}),
        point(600, 0.0, {0: 100.0, 1: 50.0}),
      ];

      expect(surfacingTankReadings(points), isNot(contains(1)));
    });

    test('returns nothing when the whole profile stays at the surface', () {
      final points = [
        point(0, 0.0, {0: 200.0}),
        point(300, 0.5, {0: 150.0}),
      ];

      expect(surfacingTankReadings(points), isEmpty);
    });

    test('returns nothing when no sample carries a pressure', () {
      final points = [point(0, 10.0), point(300, 20.0), point(600, 0.0)];

      expect(surfacingTankReadings(points), isEmpty);
    });

    test('returns nothing for an empty profile', () {
      expect(surfacingTankReadings(const []), isEmpty);
    });

    test('orders by sample time rather than list position', () {
      final points = [
        point(4090, 0.0, {1: 4.0}),
        point(0, 0.0, {1: 200.0}),
        point(3970, 1.2, {1: 41.0}),
        point(600, 40.0, {1: 120.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[1]!.atSurfacing, 41.0);
      expect(readings[1]!.lastAfterSurfacing, 4.0);
    });
  });

  group('trimEndPressureBar', () {
    const bleedingTail = SurfacingTankReading(
      atSurfacing: 41.0,
      lastAfterSurfacing: 4.0,
    );

    test('raises a reported pressure that came from the surface tail', () {
      expect(trimEndPressureBar(reportedBar: 4.0, reading: bleedingTail), 41.0);
    });

    test('tolerates unit-conversion rounding when matching the tail', () {
      expect(
        trimEndPressureBar(reportedBar: 4.138, reading: bleedingTail),
        41.0,
      );
    });

    test('keeps a reported pressure that did not come from the tail', () {
      // The source read its end pressure from somewhere other than the last
      // sample -- a log header, or a transmitter that dropped out -- so there
      // is no post-surfacing artifact to undo.
      expect(
        trimEndPressureBar(reportedBar: 86.6, reading: bleedingTail),
        86.6,
      );
    });

    test('keeps the reported pressure when the recording has no tail', () {
      const noTail = SurfacingTankReading(
        atSurfacing: 60.0,
        lastAfterSurfacing: null,
      );

      expect(trimEndPressureBar(reportedBar: 60.0, reading: noTail), 60.0);
    });

    test('never lowers a reported pressure', () {
      // A tail that somehow rose above the surfacing reading cannot drag the
      // logged end pressure down.
      const risingTail = SurfacingTankReading(
        atSurfacing: 41.0,
        lastAfterSurfacing: 60.0,
      );

      expect(trimEndPressureBar(reportedBar: 60.0, reading: risingTail), 60.0);
    });

    test('keeps the reported pressure when the profile has no reading', () {
      expect(trimEndPressureBar(reportedBar: 4.0, reading: null), 4.0);
    });

    test('invents no pressure when none was reported', () {
      expect(
        trimEndPressureBar(reportedBar: null, reading: bleedingTail),
        isNull,
      );
    });
  });
}
