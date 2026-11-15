import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/tides/presentation/widgets/tide_chart_ticks.dart';

DateTime _identity(DateTime instant) => instant;

void main() {
  group('tideHeightTicks', () {
    test('picks round values inside the range', () {
      final axis = tideHeightTicks(0.2, 1.7);

      expect(axis.ticks, [0.5, 1.0, 1.5]);
      expect(axis.decimals, 1);
    });

    test('widens the step until the ticks fit the count', () {
      // Whole feet would give six ticks; two-foot steps give three.
      final axis = tideHeightTicks(0.6, 5.6, maxCount: 4);

      expect(axis.ticks, [2.0, 4.0]);
      expect(axis.decimals, 0);
    });

    test('covers a range that crosses the datum', () {
      final axis = tideHeightTicks(-0.9, 0.9);

      expect(axis.ticks, [-0.5, 0.0, 0.5]);
    });

    test('keeps two decimals for a very small tide', () {
      final axis = tideHeightTicks(0.02, 0.13);

      expect(axis.ticks.length, inInclusiveRange(2, 4));
      expect(axis.decimals, 2);
      for (final tick in axis.ticks) {
        expect(tick, inInclusiveRange(0.02, 0.13));
      }
    });

    test('a flat range still yields its one value', () {
      expect(tideHeightTicks(1.0, 1.0).ticks, [1.0]);
    });
  });

  group('wallClockHourTicks', () {
    test('lands on round hours of the site clock', () {
      final ticks = wallClockHourTicks(
        start: DateTime.utc(2026, 3, 27, 22, 5),
        end: DateTime.utc(2026, 3, 28, 22, 5),
        stepHours: 4,
        toSite: _identity,
      );

      expect(ticks, [
        DateTime.utc(2026, 3, 28),
        DateTime.utc(2026, 3, 28, 4),
        DateTime.utc(2026, 3, 28, 8),
        DateTime.utc(2026, 3, 28, 12),
        DateTime.utc(2026, 3, 28, 16),
        DateTime.utc(2026, 3, 28, 20),
      ]);
    });

    test('follows the site offset, not UTC', () {
      // A site four hours behind UTC: its midnight is 04:00 UTC.
      DateTime toSite(DateTime instant) =>
          instant.subtract(const Duration(hours: 4));

      final ticks = wallClockHourTicks(
        start: DateTime.utc(2026, 3, 28, 2),
        end: DateTime.utc(2026, 3, 29, 2),
        stepHours: 6,
        toSite: toSite,
      );

      expect(ticks.map(toSite).map((t) => t.hour), [0, 6, 12, 18]);
      expect(ticks.first, DateTime.utc(2026, 3, 28, 4));
    });

    test('a window that starts on a round hour includes it', () {
      final ticks = wallClockHourTicks(
        start: DateTime.utc(2026, 3, 28),
        end: DateTime.utc(2026, 3, 28, 12),
        stepHours: 6,
        toSite: _identity,
      );

      expect(ticks, [
        DateTime.utc(2026, 3, 28),
        DateTime.utc(2026, 3, 28, 6),
        DateTime.utc(2026, 3, 28, 12),
      ]);
    });

    test('stays on round hours across a clock change', () {
      // The site clock jumps forward an hour at 02:00 UTC.
      final change = DateTime.utc(2026, 3, 28, 2);
      DateTime toSite(DateTime instant) => instant.isBefore(change)
          ? instant
          : instant.add(const Duration(hours: 1));

      final ticks = wallClockHourTicks(
        start: DateTime.utc(2026, 3, 27, 20),
        end: DateTime.utc(2026, 3, 28, 20),
        stepHours: 4,
        toSite: toSite,
      );

      for (final tick in ticks) {
        final wall = toSite(tick);
        expect(wall.hour % 4, 0, reason: 'tick at $tick reads $wall');
        expect(wall.minute, 0);
      }
    });
  });

  group('tideTimeStepHours', () {
    test('uses a finer step on a wide plot', () {
      expect(tideTimeStepHours(plotWidth: 600, labelWidth: 40), 2);
    });

    test('uses a coarser step on a narrow plot', () {
      expect(tideTimeStepHours(plotWidth: 250, labelWidth: 40), 6);
    });

    test('falls back to the coarsest step', () {
      expect(tideTimeStepHours(plotWidth: 60, labelWidth: 70), 12);
    });
  });
}
