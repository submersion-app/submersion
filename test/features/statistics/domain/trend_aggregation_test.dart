import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

TrendDataPoint p(int y, int m, int d, double v) =>
    TrendDataPoint(date: DateTime.utc(y, m, d), value: v);

void main() {
  group('aggregate none', () {
    test('returns one bucket per point, mean equal to min and max', () {
      final buckets = aggregate([
        p(2024, 3, 1, 10),
        p(2024, 3, 2, 20),
      ], TrendAggregation.none);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 1));
      expect(buckets[0].mean, 10);
      expect(buckets[0].min, 10);
      expect(buckets[0].max, 10);
      expect(buckets[0].count, 1);
    });

    test('returns an empty list for no points', () {
      expect(aggregate(const [], TrendAggregation.none), isEmpty);
    });
  });

  group('aggregate monthly', () {
    test('collapses a month into mean, min, max and count', () {
      final buckets = aggregate([
        p(2024, 3, 1, 10),
        p(2024, 3, 20, 30),
        p(2024, 4, 2, 50),
      ], TrendAggregation.monthly);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 1));
      expect(buckets[0].mean, 20);
      expect(buckets[0].min, 10);
      expect(buckets[0].max, 30);
      expect(buckets[0].count, 2);
      expect(buckets[1].date, DateTime.utc(2024, 4, 1));
      expect(buckets[1].count, 1);
    });

    test('orders buckets by date regardless of input order', () {
      final buckets = aggregate([
        p(2024, 5, 1, 1),
        p(2023, 1, 1, 2),
      ], TrendAggregation.monthly);

      expect(buckets.map((b) => b.date), [
        DateTime.utc(2023, 1, 1),
        DateTime.utc(2024, 5, 1),
      ]);
    });
  });

  group('aggregate weekly', () {
    test('buckets to the Monday of the point week', () {
      // 2024-03-07 is a Thursday; its Monday is 2024-03-04.
      final buckets = aggregate([p(2024, 3, 7, 10)], TrendAggregation.weekly);

      expect(buckets.single.date, DateTime.utc(2024, 3, 4));
    });

    test('a Monday point stays on its own Monday', () {
      final buckets = aggregate([p(2024, 3, 4, 10)], TrendAggregation.weekly);

      expect(buckets.single.date, DateTime.utc(2024, 3, 4));
    });

    test(
      'a Sunday point falls into the week that started six days earlier',
      () {
        // 2024-03-10 is a Sunday.
        final buckets = aggregate([
          p(2024, 3, 10, 10),
        ], TrendAggregation.weekly);

        expect(buckets.single.date, DateTime.utc(2024, 3, 4));
      },
    );

    test('splits points across two adjacent weeks', () {
      final buckets = aggregate([
        p(2024, 3, 10, 10), // Sunday, week of Mar 4
        p(2024, 3, 11, 20), // Monday, week of Mar 11
      ], TrendAggregation.weekly);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 4));
      expect(buckets[1].date, DateTime.utc(2024, 3, 11));
    });
  });

  group('rollingMean', () {
    test('returns an empty list below the minimum point count', () {
      final points = List.generate(4, (i) => p(2024, 1, i + 1, 10));
      expect(rollingMean(points), isEmpty);
    });

    test('leaves a flat series flat', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, 7));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed, hasLength(10));
      for (final s in smoothed) {
        expect(s.value, closeTo(7, 1e-9));
      }
    });

    test('averages the centred window', () {
      // Values 0..9, window 3: interior point i averages i-1, i, i+1.
      final points = List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed[5].value, closeTo(5, 1e-9));
      expect(smoothed[1].value, closeTo(1, 1e-9));
    });

    test('truncates the window at both ends rather than padding', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 5);

      // First point sees indices 0,1,2 only: mean 1.
      expect(smoothed.first.value, closeTo(1, 1e-9));
      // Last point sees indices 7,8,9 only: mean 8.
      expect(smoothed.last.value, closeTo(8, 1e-9));
    });

    test('keeps each smoothed point on its own date', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed[3].date, points[3].date);
    });

    test('counts dives rather than calendar time', () {
      // Two clusters far apart. A time-based window would average across the
      // gap; a count-based window of 3 must not.
      final points = <TrendDataPoint>[
        p(2024, 1, 1, 10),
        p(2024, 1, 2, 10),
        p(2024, 1, 3, 10),
        p(2026, 1, 1, 50),
        p(2026, 1, 2, 50),
        p(2026, 1, 3, 50),
      ];
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed.first.value, closeTo(10, 1e-9));
      expect(smoothed.last.value, closeTo(50, 1e-9));
    });
  });

  group('linearFit', () {
    test('returns null below the minimum point count', () {
      final points = List.generate(4, (i) => p(2024, 1, i + 1, 10));
      expect(linearFit(points), isNull);
    });

    test('recovers a known slope of one unit per day', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final fit = linearFit(points)!;

      expect(fit.slopePerDay, closeTo(1.0, 1e-9));
      expect(fit.perYear, closeTo(365.25, 1e-6));
    });

    test('reports a zero slope for a flat series', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, 7));
      final fit = linearFit(points)!;

      expect(fit.slopePerDay, closeTo(0, 1e-9));
    });

    test('valueAt reproduces the fitted line at the origin and beyond', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final fit = linearFit(points)!;

      expect(fit.valueAt(DateTime.utc(2024, 1, 1)), closeTo(0, 1e-9));
      expect(fit.valueAt(DateTime.utc(2024, 1, 11)), closeTo(10, 1e-9));
    });

    test('returns null when every point shares one date', () {
      final points = List.generate(10, (i) => p(2024, 1, 1, i.toDouble()));
      expect(linearFit(points), isNull);
    });
  });
}
