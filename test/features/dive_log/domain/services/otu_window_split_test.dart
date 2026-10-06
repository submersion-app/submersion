import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/otu_window_split.dart';

void main() {
  // A 50-minute dive from 23:30 to 00:20 that accrued 100 OTU.
  final start = DateTime.utc(2026, 7, 17, 23, 30);
  final end = DateTime.utc(2026, 7, 18, 0, 20);
  final midnight = DateTime.utc(2026, 7, 18);
  final nextMidnight = DateTime.utc(2026, 7, 19);
  final dayBefore = DateTime.utc(2026, 7, 17);

  group('OtuWindowSplit.otuWithin', () {
    test('splits on the OTU curve, not on elapsed time', () {
      // 30 min before midnight at 0.5 bar (no OTU), 20 min after at high
      // ppO2: every OTU lands after midnight even though 60% of the time is
      // before it.
      final otu = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: const [0, 0, 100],
        curveTimestamps: const [0, 1800, 3000],
        diveStart: start,
        diveEnd: end,
        from: midnight,
        to: nextMidnight,
      );
      expect(otu, closeTo(100, 1e-9));
    });

    test('interpolates the curve between samples at the cutoff', () {
      // Cumulative OTU climbs linearly 0 -> 100 over the whole dive; the
      // cutoff at 1800 s sits 60% of the way through.
      final before = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: const [0, 100],
        curveTimestamps: const [0, 3000],
        diveStart: start,
        diveEnd: end,
        from: dayBefore,
        to: midnight,
      );
      final after = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: const [0, 100],
        curveTimestamps: const [0, 3000],
        diveStart: start,
        diveEnd: end,
        from: midnight,
        to: nextMidnight,
      );
      expect(before, closeTo(60, 1e-9));
      expect(after, closeTo(40, 1e-9));
    });

    test('scales the curve to the exposure total when they differ', () {
      // A computer-sourced total of 50 on a calculated curve ending at 100.
      final otu = OtuWindowSplit.otuWithin(
        totalOtu: 50,
        otuCurve: const [0, 100],
        curveTimestamps: const [0, 3000],
        diveStart: start,
        diveEnd: end,
        from: midnight,
        to: nextMidnight,
      );
      expect(otu, closeTo(20, 1e-9));
    });

    test('falls back to elapsed time without a usable curve', () {
      final otu = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: null,
        curveTimestamps: null,
        diveStart: start,
        diveEnd: end,
        from: midnight,
        to: nextMidnight,
      );
      expect(otu, closeTo(40, 1e-9));
    });

    test('a dive wholly inside the window counts in full', () {
      final otu = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: const [0, 100],
        curveTimestamps: const [0, 3000],
        diveStart: start,
        diveEnd: end,
        from: dayBefore,
        to: nextMidnight,
      );
      expect(otu, closeTo(100, 1e-9));
    });

    test('a dive wholly outside the window counts nothing', () {
      final otu = OtuWindowSplit.otuWithin(
        totalOtu: 100,
        otuCurve: const [0, 100],
        curveTimestamps: const [0, 3000],
        diveStart: start,
        diveEnd: end,
        from: nextMidnight,
        to: nextMidnight.add(const Duration(days: 1)),
      );
      expect(otu, 0);
    });

    test('a dive with no duration counts in the window holding its start', () {
      double within(DateTime from, DateTime to) => OtuWindowSplit.otuWithin(
        totalOtu: 30,
        otuCurve: null,
        curveTimestamps: null,
        diveStart: midnight,
        diveEnd: midnight,
        from: from,
        to: to,
      );
      expect(within(midnight, nextMidnight), 30);
      expect(within(dayBefore, midnight), 0);
    });
  });
}
