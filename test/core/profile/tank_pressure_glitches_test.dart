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

    test('a transmitter that never paired has no glitches', () {
      // An hour at one reading a second, every one near zero: no lead-in
      // ends anywhere, and nothing dips below the level.
      final series = [for (var t = 0; t < 3600; t++) (t: t, bar: 0.0)];
      final scan = scanPressureGlitches(series);
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

    test('a dip that returns a little below the prior level ends there', () {
      // 191.7 -> 170.2 -> 185.1: the reading after the dip sits 6.6 bar
      // below the level before it (gas breathed meanwhile), which must not
      // keep the dip open for the rest of the dive.
      final series = [
        (t: 190, bar: 191.7),
        (t: 200, bar: 191.7),
        (t: 210, bar: 191.7),
        (t: 220, bar: 170.2),
        (t: 230, bar: 185.1),
        (t: 240, bar: 183.4),
        (t: 250, bar: 183.0),
        (t: 260, bar: 182.0),
      ];
      final scan = scanPressureGlitches(series);
      expect(scan.glitchIndices, {3});
    });

    test('a dip that wobbles on its way down is still one glitch', () {
      // 100 -> 80 -> 87 -> 80 -> 100: the jump to 87 stays well below the
      // level, so it is the dip wobbling, not its end.
      final series = [
        ...draining(start: 101.5, count: 5),
        (t: 50, bar: 100.0),
        (t: 60, bar: 80.0),
        (t: 70, bar: 87.0),
        (t: 80, bar: 80.0),
        (t: 90, bar: 100.0),
        (t: 100, bar: 99.8),
      ];
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, {6, 7, 8});
    });

    test(
      'a dropout right after the valve opened does not undo the lead-in',
      () {
        // 8 -> 200 -> 200 -> 0 -> 199: the lead-in is still the 8 bar, and the
        // dropout is a glitch of its own.
        final series = [
          (t: 0, bar: 8.0),
          (t: 10, bar: 200.0),
          (t: 20, bar: 200.0),
          (t: 30, bar: 0.0),
          (t: 40, bar: 199.0),
          (t: 50, bar: 198.8),
          (t: 60, bar: 198.6),
        ];
        final scan = scanPressureGlitches(series);
        expect(scan.glitchIndices, {0, 3});
        expect(scan.episodeCount, 2);
      },
    );

    test('a single reading spiking above the level is a glitch', () {
      // 61.4 -> 80.1 -> 59.7, as logged.
      final series = withValues(draining(start: 70), {12: 80.1});
      final scan = scanPressureGlitches(series);
      expect(scan.episodeCount, 1);
      expect(scan.glitchIndices, {12});
    });

    test('a two-reading spike above the level is one glitch', () {
      final series = withValues(draining(start: 50), {10: 104.0, 11: 104.0});
      expect(scanPressureGlitches(series).glitchIndices, {10, 11});
    });

    test('a jump up that stays is not a glitch', () {
      // A lasting step up is no misread; the rise check reports it.
      final series = [
        ...draining(start: 100, count: 15),
        for (var i = 15; i < 30; i++) (t: i * 10, bar: 140.0 - i * 0.3),
      ];
      expect(scanPressureGlitches(series).episodeCount, 0);
    });

    test('a dip that returns a few bar above the prior level is a glitch', () {
      // 108 -> 96.3 -> 88.1 -> 93.1 -> 93.1 -> 111.1, as logged.
      final series = [
        ...draining(start: 110, count: 5),
        (t: 50, bar: 108.0),
        (t: 60, bar: 96.3),
        (t: 70, bar: 88.1),
        (t: 80, bar: 93.1),
        (t: 90, bar: 93.1),
        (t: 100, bar: 111.1),
        (t: 110, bar: 111.0),
      ];
      expect(scanPressureGlitches(series).glitchIndices, {6, 7, 8, 9});
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

    test('a dropout the cylinder comes back from a few bar warmer is a '
        'glitch', () {
      // Four minutes at ~0 bar, and the cylinder warmed meanwhile: the
      // reading after it sits 4 bar above the one before. A reading of ~0
      // bar is no pressure the cylinder held, whatever follows it.
      final base = draining(count: 60);
      final series = [
        for (var i = 0; i < base.length; i++)
          if (i >= 10 && i < 34)
            (t: base[i].t, bar: 0.6)
          else if (i >= 34)
            (t: base[i].t, bar: base[9].bar + 4 - (i - 34) * 0.3)
          else
            base[i],
      ];
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

    // A spike is a reading above the cylinder's level. A reported endpoint
    // that happens to equal one is a real header value: the glitches a
    // source takes an endpoint from (a lead-in, a dropout, a dip) all read
    // low.
    test('a reported start that equals a mid-dive spike is kept', () {
      // The transmitter paired late: the series opens at 185 bar while the
      // computer's header recorded the 200 bar the cylinder was filled to.
      final series = withValues(draining(start: 185), {15: 200.2});
      expect(scanPressureGlitches(series).glitchIndices, {15});
      expect(
        replaceGlitchedEndpoint(
          reportedBar: 200,
          readings: series,
          atStart: true,
        ),
        200,
      );
    });

    test('a reported end that equals a mid-dive spike is kept', () {
      final series = withValues(draining(), {15: 210.4});
      expect(scanPressureGlitches(series).glitchIndices, {15});
      expect(
        replaceGlitchedEndpoint(
          reportedBar: 210.2,
          readings: series,
          atStart: false,
        ),
        210.2,
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

  // Issue #2687: a source can report an endpoint no cylinder is breathed at
  // (0.34 bar) that matches no reading of its own series, which shows the
  // cylinder at 84-93 bar.
  group('replaceNearZeroEndpoint', () {
    test('a near-zero end the series contradicts takes its last reading', () {
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.34,
          otherBar: 200,
          readings: draining(),
          atStart: false,
        ),
        closeTo(200 - 29 * 0.3, 1e-9),
      );
    });

    test('a near-zero start the series contradicts takes its first', () {
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.46,
          otherBar: 120,
          readings: draining(start: 190),
          atStart: true,
        ),
        190,
      );
    });

    test('the replacement skips a lead-in at that end of the series', () {
      // The reported 0.46 bar matches no reading, so the glitch rule leaves
      // it; the first clean reading is the one after the 3.9 bar lead-in.
      final series = withValues(draining(), {0: 3.9});
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.46,
          otherBar: 80,
          readings: series,
          atStart: true,
        ),
        closeTo(199.7, 1e-9),
      );
    });

    test('a series that drops to near zero and stays there is a dropout', () {
      // The transmitter lost its signal for the rest of the log: nothing
      // follows the drop to show it was a misread, so the scan keeps it, but
      // no cylinder loses 190 bar between two readings.
      final series = withValues(draining(), {27: 0.3, 28: 0.3, 29: 0.3});
      expect(scanPressureGlitches(series).glitchIndices, isEmpty);
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.3,
          otherBar: 200,
          readings: series,
          atStart: false,
        ),
        closeTo(200 - 26 * 0.3, 1e-9),
      );
    });

    test('a non-finite value is resolved like a near-zero one', () {
      expect(
        replaceNearZeroEndpoint(
          reportedBar: double.nan,
          otherBar: 200,
          readings: const [],
          atStart: false,
        ),
        isNull,
      );
      expect(
        replaceNearZeroEndpoint(
          reportedBar: double.infinity,
          otherBar: 60,
          readings: draining(),
          atStart: true,
        ),
        200,
      );
    });

    test('a value at the near-zero bound is a real pressure and kept', () {
      expect(
        replaceNearZeroEndpoint(
          reportedBar: kPressureGlitchNearZeroBar,
          otherBar: 200,
          readings: draining(),
          atStart: false,
        ),
        kPressureGlitchNearZeroBar,
      );
    });

    test('a near-zero value the series agrees with is kept', () {
      // A series that runs down to near zero itself corroborates the value.
      final series = [
        for (var i = 0; i < 30; i++) (t: i * 10, bar: 60 - i * 2.0),
      ];
      expect(series.last.bar, lessThan(kPressureGlitchNearZeroBar));
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 2.0,
          otherBar: 60,
          readings: series,
          atStart: false,
        ),
        2.0,
      );
    });

    test('without a series it is cleared when the other end is real', () {
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.34,
          otherBar: 200,
          readings: const [],
          atStart: false,
        ),
        isNull,
      );
      expect(
        replaceNearZeroEndpoint(
          reportedBar: 0.46,
          otherBar: 90,
          readings: const [],
          atStart: true,
        ),
        isNull,
      );
    });

    test('without a series it is kept when the other end is no help', () {
      for (final other in [null, 0.2]) {
        expect(
          replaceNearZeroEndpoint(
            reportedBar: 0.34,
            otherBar: other,
            readings: const [],
            atStart: false,
          ),
          0.34,
          reason: 'other endpoint $other',
        );
      }
    });

    test('a plausible value and null come back unchanged', () {
      for (final reported in [null, 84.0]) {
        expect(
          replaceNearZeroEndpoint(
            reportedBar: reported,
            otherBar: 200,
            readings: const [],
            atStart: false,
          ),
          reported,
        );
      }
    });
  });
}
