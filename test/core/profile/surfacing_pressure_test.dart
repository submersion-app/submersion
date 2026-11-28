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

    test('passes over a signal dropout at the surfacing sample', () {
      // Issue #2441: the transmitter logged ~0 bar exactly as the diver
      // surfaced, then recovered. The dropout says nothing about what the
      // cylinder held, so the last real reading before it stands.
      final points = [
        point(0, 20.0, {0: 200.0}),
        point(600, 20.0, {0: 150.0}),
        point(900, 1.0, {0: 0.8}),
        point(960, 0.0, {0: 147.0}),
        point(1020, 0.0, {0: 146.0}),
      ];

      final readings = surfacingTankReadings(points);

      expect(readings[0]!.atSurfacing, 150.0);
      expect(readings[0]!.lastAfterSurfacing, 146.0);
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

  group('seriesEndpointsAtSurfacing', () {
    // A 30 minute dive: down at 60 s, back on the surface after 1800 s.
    const depths = [
      (t: 0, depth: 0.0),
      (t: 60, depth: 12.0),
      (t: 1740, depth: 3.0),
      (t: 1800, depth: 0.5),
      (t: 1830, depth: 0.0),
      (t: 1860, depth: 0.0),
    ];

    test('ends at surfacing when the valve was closed on the surface', () {
      // Issue #5000: a Suunto Nautic kept logging after the dive and caught
      // the diver closing the valve, so the series ends at 0 bar.
      final readings = [
        (t: 0, bar: 205.0),
        (t: 900, bar: 150.0),
        (t: 1740, bar: 103.0),
        (t: 1830, bar: 0.0),
        (t: 1860, bar: 0.0),
      ];

      final endpoints = seriesEndpointsAtSurfacing(readings, depths: depths);

      expect(endpoints, (start: 205.0, end: 103.0));
    });

    test('ends at surfacing when the regulator bled down slowly', () {
      final readings = [
        (t: 0, bar: 205.0),
        (t: 1740, bar: 103.0),
        (t: 1830, bar: 60.0),
        (t: 1860, bar: 12.0),
      ];

      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 205.0,
        end: 103.0,
      ));
    });

    test('keeps the last reading when nothing was logged after surfacing', () {
      final readings = [(t: 0, bar: 205.0), (t: 1740, bar: 103.0)];

      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 205.0,
        end: 103.0,
      ));
    });

    test('keeps a tail that reads above the surfacing reading', () {
      // A cylinder warming in the sun gains pressure on the surface; the
      // rule only ever raises an end pressure, as for a reported one.
      final readings = [
        (t: 0, bar: 205.0),
        (t: 1740, bar: 103.0),
        (t: 1860, bar: 106.0),
      ];

      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 205.0,
        end: 106.0,
      ));
    });

    test('passes over a dropout at the surfacing reading', () {
      final readings = [
        (t: 0, bar: 205.0),
        (t: 1700, bar: 104.0),
        (t: 1740, bar: 0.0),
        (t: 1800, bar: 103.0),
        (t: 1860, bar: 0.0),
      ];

      // The 0 bar at 1740 s recovers, so it is a dropout; the reading before
      // it is the last one at or before surfacing.
      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 205.0,
        end: 104.0,
      ));
    });

    test('measures from the last descent after a surface break', () {
      const twoDescents = [
        (t: 0, depth: 0.0),
        (t: 60, depth: 12.0),
        (t: 900, depth: 0.0),
        (t: 960, depth: 8.0),
        (t: 1740, depth: 3.0),
        (t: 1830, depth: 0.0),
      ];
      final readings = [
        (t: 0, bar: 205.0),
        (t: 900, bar: 150.0),
        (t: 1740, bar: 103.0),
        (t: 1830, bar: 0.0),
      ];

      expect(seriesEndpointsAtSurfacing(readings, depths: twoDescents), (
        start: 205.0,
        end: 103.0,
      ));
    });

    test('reads the series alone when the profile never left the surface', () {
      final readings = [(t: 0, bar: 205.0), (t: 1830, bar: 0.0)];

      expect(
        seriesEndpointsAtSurfacing(
          readings,
          depths: const [(t: 0, depth: 0.0), (t: 1830, depth: 0.2)],
        ),
        (start: 205.0, end: 0.0),
      );
    });

    test('reads the series alone when it starts after surfacing', () {
      final readings = [(t: 1830, bar: 103.0), (t: 1860, bar: 0.0)];

      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 103.0,
        end: 0.0,
      ));
    });

    test('accepts readings out of time order', () {
      final readings = [
        (t: 1830, bar: 0.0),
        (t: 0, bar: 205.0),
        (t: 1740, bar: 103.0),
      ];

      expect(seriesEndpointsAtSurfacing(readings, depths: depths), (
        start: 205.0,
        end: 103.0,
      ));
    });

    test('returns null for an empty series', () {
      expect(seriesEndpointsAtSurfacing(const [], depths: depths), isNull);
    });
  });
}
