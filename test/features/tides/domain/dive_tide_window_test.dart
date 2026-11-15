import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/services/dive_tide_window.dart';

const _bonaire = GeoPoint(12.15, -68.27); // UTC-4, no DST
// Reykjavik keeps UTC all year, so its wall clock reads the instant.
const _reykjavik = GeoPoint(64.15, -21.95);
final _calculator = TideCalculator(
  constituents: {
    'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
  },
);

DiveTideWindow _window(List<(DateTime, double)> points) => DiveTideWindow(
  entry: points.first.$1,
  start: points.first.$1,
  end: points.last.$1,
  predictions: [
    for (final (time, height) in points)
      TidePrediction(time: time, heightMeters: height),
  ],
  extremes: const [],
);

void main() {
  group('loadDiveTideWindow', () {
    test('reaches 12 hours either side of the entry instant', () async {
      // 10:00 on Bonaire's wall clock is 14:00 UTC.
      final window = await loadDiveTideWindow(
        calculator: _calculator,
        entryWallClock: DateTime.utc(2026, 3, 28, 10),
        location: _bonaire,
      );

      expect(window.entry, DateTime.utc(2026, 3, 28, 14));
      expect(window.start, DateTime.utc(2026, 3, 28, 2));
      expect(window.end, DateTime.utc(2026, 3, 29, 2));
      expect(window.predictions.first.time, window.start);
      expect(window.predictions.last.time, window.end);
    });

    test('carries every high and low inside the window, in order', () async {
      final window = await loadDiveTideWindow(
        calculator: _calculator,
        entryWallClock: DateTime.utc(2026, 3, 28, 10),
        location: _bonaire,
      );

      // M2 alone turns every 6.21 hours, so 24 hours hold 3 or 4 extremes,
      // against the single high and low a stored record names.
      expect(window.extremes.length, inInclusiveRange(3, 4));
      for (final extreme in window.extremes) {
        expect(extreme.time.isBefore(window.start), isFalse);
        expect(extreme.time.isAfter(window.end), isFalse);
      }
      for (var i = 1; i < window.extremes.length; i++) {
        expect(
          window.extremes[i].time.isAfter(window.extremes[i - 1].time),
          isTrue,
        );
        expect(window.extremes[i].type, isNot(window.extremes[i - 1].type));
      }
    });
  });

  test('copyWith replaces only the fields it is given', () {
    final t0 = DateTime.utc(2026, 3, 28, 12);
    final window = _window([
      (t0, 1.0),
      (t0.add(const Duration(hours: 1)), 2.0),
    ]);
    final later = t0.add(const Duration(minutes: 30));

    final moved = window.copyWith(entry: later);

    expect(moved.entry, later);
    expect(moved.start, window.start);
    expect(moved.end, window.end);
    expect(moved.predictions, window.predictions);
    expect(moved.extremes, window.extremes);
    expect(window.copyWith(), window);
  });

  test('keeps an extreme that falls exactly on the window start', () async {
    // Find a real high, then put the dive 12 hours after it so the window
    // opens on that very instant: the engine's extreme search needs a
    // sample either side of a turn, which the window's first sample lacks.
    final extremes = _calculator.findExtremes(
      start: DateTime.utc(2026, 3, 28),
      end: DateTime.utc(2026, 3, 29),
    );
    final edge = extremes.first.time;

    final window = await loadDiveTideWindow(
      calculator: _calculator,
      entryWallClock: edge.add(diveTideWindowHalfSpan),
      location: _reykjavik,
    );

    expect(window.start, edge);
    expect(
      window.extremes.any(
        (e) => e.time.difference(edge).abs() < const Duration(minutes: 1),
      ),
      isTrue,
      reason: 'the extreme at the window start was dropped',
    );
    // Nothing further out than the minute an extreme is shown to.
    for (final extreme in window.extremes) {
      expect(
        extreme.time.isBefore(
          window.start.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      expect(
        extreme.time.isAfter(window.end.add(const Duration(minutes: 1))),
        isFalse,
      );
    }
  });

  group('DiveTideWindow.heightAt', () {
    final t0 = DateTime.utc(2026, 3, 28, 12);
    final window = _window([
      (t0, 1.0),
      (t0.add(const Duration(minutes: 10)), 2.0),
      (t0.add(const Duration(minutes: 20)), 1.0),
    ]);

    test('reads a sampled instant exactly', () {
      expect(window.heightAt(t0.add(const Duration(minutes: 10))), 2.0);
    });

    test('interpolates between two samples', () {
      expect(
        window.heightAt(t0.add(const Duration(minutes: 5))),
        closeTo(1.5, 1e-9),
      );
      expect(
        window.heightAt(t0.add(const Duration(minutes: 18))),
        closeTo(1.2, 1e-9),
      );
    });

    test('has no height outside the sampled span', () {
      expect(window.heightAt(t0.subtract(const Duration(minutes: 1))), isNull);
      expect(window.heightAt(t0.add(const Duration(minutes: 21))), isNull);
    });
  });
}
