import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  var seq = 0;
  Future<void> seedDive({double? meters, String? bucket}) async {
    seq++;
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, visibility, visibility_meters, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0)',
      [
        'dive-$seq',
        DateTime.utc(2026, 1, seq.clamp(1, 28)).millisecondsSinceEpoch,
        bucket,
        meters,
      ],
    );
  }

  Map<String, int> countsByLabel(List<DistributionSegment> segments) => {
    for (final s in segments) s.label: s.count,
  };

  test('measured dives bin by the supplied calibration', () async {
    await seedDive(meters: 6);
    await seedDive(meters: 13);

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.coldWater,
    );

    expect(countsByLabel(segments), {'good': 1, 'excellent': 1});
  });

  test('the same data re-bins under a different calibration', () async {
    await seedDive(meters: 6);
    await seedDive(meters: 13);

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.tropical,
    );

    // Under tropical both fall in moderate: same dives, different reading.
    expect(countsByLabel(segments), {'moderate': 2});
  });

  test(
    'legacy dives form their own segment, never merged into a band',
    () async {
      await seedDive(meters: 6);
      await seedDive(bucket: 'moderate');

      final segments = await repository.getVisibilityDistribution(
        scale: VisibilityScale.coldWater,
      );

      final counts = countsByLabel(segments);
      expect(counts['good'], 1);
      expect(
        counts['legacy_moderate'],
        1,
        reason:
            'a bucket does not say where in its range the dive fell, so it '
            'cannot be assigned a calibrated adjective',
      );
    },
  );

  test(
    'a measured dive that also has a bucket counts once, as measured',
    () async {
      await seedDive(meters: 6, bucket: 'moderate');

      final segments = await repository.getVisibilityDistribution(
        scale: VisibilityScale.coldWater,
      );

      expect(countsByLabel(segments), {'good': 1});
    },
  );

  test('dives with neither value are excluded', () async {
    await seedDive(meters: 6);
    await seedDive();

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.coldWater,
    );

    expect(segments.fold<int>(0, (sum, s) => sum + s.count), 1);
  });

  test('percentages sum to 100 across mixed data', () async {
    await seedDive(meters: 6);
    await seedDive(meters: 13);
    await seedDive(bucket: 'good');

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.coldWater,
    );

    final total = segments.fold<double>(0, (sum, s) => sum + s.percentage);
    expect(total, closeTo(100, 0.001));
  });

  test('returns nothing when no dive has visibility', () async {
    await seedDive();
    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.tropical,
    );
    expect(segments, isEmpty);
  });
}
