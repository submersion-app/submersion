import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/profile/tank_pressure_glitches.dart';

/// A steadily draining series: [start] bar at t=0, losing [perSample] bar
/// every [step] seconds.
List<PressureReading> draining({
  double start = 200,
  double perSample = 0.3,
  int count = 30,
  int step = 10,
}) => [
  for (var i = 0; i < count; i++) (t: i * step, bar: start - i * perSample),
];

List<PressureReading> withValues(
  List<PressureReading> series,
  Map<int, double> byIndex,
) => [
  for (var i = 0; i < series.length; i++)
    (t: series[i].t, bar: byIndex[i] ?? series[i].bar),
];

void main() {
  group('scanPressureGlitches', () {
    test('a clean draining series has no glitches', () {
      final scan = scanPressureGlitches(draining());
      expect(scan.episodeCount, 0);
      expect(scan.glitchIndices, isEmpty);
    });

    test('an empty or single-reading series has no glitches', () {
      expect(scanPressureGlitches(const []).episodeCount, 0);
      expect(scanPressureGlitches(const [(t: 0, bar: 0.5)]).episodeCount, 0);
    });

    test('a near-zero dropout between normal readings is one episode', () {
      // 190:185.8  200:0.8  210:0.8  220:0.8  230:183.8, as logged.
      final series = withValues(draining(), {10: 0.8, 11: 0.8, 12: 0.8});
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, {10, 11, 12});
    });

    test('two separate dropouts are two episodes', () {
      final series = withValues(draining(), {5: 0.5, 20: 0.6, 21: 0.6});
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 2);
      expect(scan.glitchIndices, {5, 20, 21});
    });

    test('a partial dip that returns to the prior level is a glitch', () {
      // 131.1 -> 121.8 -> 130.2: a transient misread, not consumption.
      final series = withValues(draining(start: 135), {10: 121.8});
      final scan = scanPressureGlitches(series);
      expect(scan.glitchIndices, {10});
    });

    test('a lasting drop that never recovers is not a glitch', () {
      // A real loss of 30 bar (e.g. a free flow) stays down.
      final series = [
        for (var i = 0; i < 10; i++) (t: i * 10, bar: 200.0 - i * 0.3),
        for (var i = 10; i < 20; i++) (t: i * 10, bar: 170.0 - i * 0.3),
      ];
      expect(scanPressureGlitches(series).episodeCount, 0);
    });

    test('a non-zero dip longer than the window is not a glitch', () {
      final base = draining(count: 40);
      final series = withValues(base, {for (var i = 10; i < 25; i++) i: 150.0});
      expect(scanPressureGlitches(series).episodeCount, 0);
    });

    test('a dip across a long sampling gap is not a glitch', () {
      // One reading every ten minutes: the lower reading may be real
      // consumption at any point of the gap, not a misread.
      final series = [
        (t: 0, bar: 200.0),
        (t: 600, bar: 170.0),
        (t: 1200, bar: 195.0),
        (t: 1800, bar: 150.0),
      ];
      expect(scanPressureGlitches(series).episodeCount, 0);
    });

    test('a long near-zero dropout is still a glitch', () {
      // Signal lost for four minutes: the reading sits at ~0 throughout.
      final base = draining(count: 60);
      final series = withValues(base, {for (var i = 10; i < 34; i++) i: 0.6});
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, hasLength(24));
    });

    test('a dip followed by a higher reading than before is not a glitch', () {
      // The reading after the dip sits well above the level before it, so
      // the dip cannot be told apart from a switch of source.
      final series = [
        ...draining(start: 155.8, perSample: 0.3, count: 20),
        (t: 200, bar: 150.0),
        (t: 210, bar: 120.0),
        (t: 220, bar: 180.0),
        (t: 230, bar: 179.8),
      ];
      expect(scanPressureGlitches(series).episodeCount, 0);
    });

    test('low readings before the valve opened lead the series', () {
      // 3.9 bar at t=0, then the real cylinder pressure.
      final series = withValues(draining(start: 141.2), {0: 3.9});
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, {0});
    });

    test('a rising lead-in while the valve opens is one episode', () {
      final series = [
        (t: 0, bar: 0.3),
        (t: 10, bar: 50.0),
        (t: 20, bar: 120.0),
        ...draining(start: 200).skip(3),
      ];
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, {0, 1, 2});
    });

    test('a long near-zero lead-in is a glitch whatever its length', () {
      final series = [
        for (var i = 0; i < 30; i++) (t: i * 10, bar: 0.4),
        ...[for (final r in draining(start: 200)) (t: r.t + 300, bar: r.bar)],
      ];
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, hasLength(30));
    });

    test('a trailing drop with no recovery is left alone', () {
      // Nothing after it shows the drop was a misread (e.g. the valve was
      // closed and the hose purged at the end), so it is kept.
      final series = withValues(draining(), {29: 0.4});
      expect(scanPressureGlitches(series).episodeCount, 0);
    });
  });

  group('withoutPressureGlitches', () {
    test('drops exactly the glitch readings', () {
      final series = withValues(draining(), {10: 0.8, 11: 0.8});
      final clean = withoutPressureGlitches(series);
      expect(clean, hasLength(series.length - 2));
      expect(clean.every((r) => r.bar > 100), isTrue);
    });

    test('returns the series itself when there is nothing to drop', () {
      final series = draining();
      expect(identical(withoutPressureGlitches(series), series), isTrue);
    });
  });

  group('cleanSeriesEndpoints', () {
    test('skips a lead-in and a dropout, in any input order', () {
      final series = withValues(draining(start: 150), {0: 3.9, 12: 0.6});
      final shuffled = [...series.reversed];
      final endpoints = cleanSeriesEndpoints(shuffled)!;
      expect(endpoints.start, closeTo(149.7, 1e-9));
      expect(endpoints.end, closeTo(150 - 29 * 0.3, 1e-9));
    });

    test('an empty series has no endpoints', () {
      expect(cleanSeriesEndpoints(const []), isNull);
    });
  });

  group('replaceGlitchedEndpoint', () {
    test('a reported start taken from a lead-in glitch is replaced', () {
      final series = withValues(draining(start: 141.2), {0: 3.9});
      expect(
        replaceGlitchedEndpoint(
          reportedBar: 3.9,
          readings: series,
          atStart: true,
        ),
        closeTo(140.9, 1e-9),
      );
    });

    test('a reported end taken from a mid-dive glitch is replaced', () {
      final series = withValues(draining(), {15: 0.8});
      expect(
        replaceGlitchedEndpoint(
          reportedBar: 0.8,
          readings: series,
          atStart: false,
        ),
        closeTo(200 - 29 * 0.3, 1e-9),
      );
    });

    test('a reported value that is no glitch is kept', () {
      final series = withValues(draining(), {15: 0.8});
      expect(
        replaceGlitchedEndpoint(
          reportedBar: 200,
          readings: series,
          atStart: true,
        ),
        200,
      );
    });

    test('null stays null', () {
      expect(
        replaceGlitchedEndpoint(
          reportedBar: null,
          readings: draining(),
          atStart: true,
        ),
        isNull,
      );
    });
  });
}
