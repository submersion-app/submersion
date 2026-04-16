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
}
