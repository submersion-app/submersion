import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

void main() {
  group('DiveStatistics.firstDiveDate', () {
    test('accepts null firstDiveDate (no dives logged)', () {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.firstDiveDate, isNull);
    });

    test('accepts a non-null firstDiveDate', () {
      final date = DateTime(2020, 1, 15);
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 3600,
        maxDepth: 20,
        avgMaxDepth: 15,
        totalSites: 2,
        firstDiveDate: date,
      );
      expect(stats.firstDiveDate, equals(date));
    });
  });

  group('DiveStatistics.monthsSinceFirstDive', () {
    test('returns null when firstDiveDate is null', () {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns null when firstDiveDate is in the future', () {
      final future = DateTime.now().add(const Duration(days: 10));
      final stats = DiveStatistics(
        totalDives: 1,
        totalTimeSeconds: 3000,
        maxDepth: 18,
        avgMaxDepth: 18,
        totalSites: 1,
        firstDiveDate: future,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns null when tenure is under 1 month', () {
      final recent = DateTime.now().subtract(const Duration(days: 10));
      final stats = DiveStatistics(
        totalDives: 3,
        totalTimeSeconds: 9000,
        maxDepth: 20,
        avgMaxDepth: 15,
        totalSites: 1,
        firstDiveDate: recent,
      );
      expect(stats.monthsSinceFirstDive, isNull);
    });

    test('returns approximately 12 for a 1-year tenure', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final stats = DiveStatistics(
        totalDives: 24,
        totalTimeSeconds: 86400,
        maxDepth: 30,
        avgMaxDepth: 20,
        totalSites: 5,
        firstDiveDate: oneYearAgo,
      );
      expect(stats.monthsSinceFirstDive, closeTo(12.0, 0.5));
    });
  });

  group('DiveStatistics.divesPerMonth', () {
    test('returns null when monthsSinceFirstDive is null', () {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.divesPerMonth, isNull);
    });

    test('divides totalDives by months for a 1-year diver', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final stats = DiveStatistics(
        totalDives: 24,
        totalTimeSeconds: 86400,
        maxDepth: 30,
        avgMaxDepth: 20,
        totalSites: 5,
        firstDiveDate: oneYearAgo,
      );
      expect(stats.divesPerMonth, closeTo(2.0, 0.2));
    });
  });

  group('DiveStatistics.divesPerYear', () {
    test('returns null when monthsSinceFirstDive is null', () {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );
      expect(stats.divesPerYear, isNull);
    });

    test('divides totalDives by years for a 2-year diver', () {
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      final stats = DiveStatistics(
        totalDives: 40,
        totalTimeSeconds: 144000,
        maxDepth: 40,
        avgMaxDepth: 25,
        totalSites: 10,
        firstDiveDate: twoYearsAgo,
      );
      expect(stats.divesPerYear, closeTo(20.0, 1.0));
    });
  });
}
