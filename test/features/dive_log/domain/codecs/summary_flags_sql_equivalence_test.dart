import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// Pins that the scalar columns a `dive_profile_series` row stores next to
/// its blob agree with what the legacy row-per-sample SQL would have
/// computed over the same decoded samples. The deco-signal SQL consumers
/// (dive_filter_sql.dart, dive_repository_impl.dart, statistics_repository)
/// read these columns instead of scanning `dive_profiles`, so a mismatch
/// here would silently reclassify every dive that has one.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;

  Future<void> seedDive(String diveId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  /// Inserts [samples] (already in ascending timestamp order) as one series
  /// of a fresh dive, reads the raw row back, and asserts every scalar
  /// column against the legacy-SQL-equivalent fold over the samples.
  Future<void> expectSummaryMatchesLegacyFold(
    String diveId,
    List<ProfileSample> samples,
  ) async {
    await seedDive(diveId);
    await repo.insertSeries(diveId: diveId, samples: samples, now: 1000);

    final rows = await repo.getRowsForDives([diveId]);
    expect(rows, hasLength(1));
    final row = rows.single;

    expect(
      row.hasDecoType,
      samples.any((s) => s.decoType != null),
      reason: 'has_deco_type must equal samples.any((s) => s.decoType != null)',
    );
    expect(
      row.hasDecoStop,
      samples.any((s) => s.decoType == 2),
      reason: 'has_deco_stop must equal samples.any((s) => s.decoType == 2)',
    );
    expect(
      row.hasPositiveCeiling,
      samples.any((s) => (s.ceiling ?? 0) > 0),
      reason:
          'has_positive_ceiling must equal '
          'samples.any((s) => (s.ceiling ?? 0) > 0)',
    );
    expect(
      row.maxDepth,
      samples.map((s) => s.depth).reduce((a, b) => a > b ? a : b),
    );
    expect(row.firstDepth, samples.first.depth);
    expect(row.lastDepth, samples.last.depth);
    expect(row.startTimestamp, samples.first.timestamp);
    expect(row.endTimestamp, samples.last.timestamp);
    expect(row.sampleCount, samples.length);
  }

  test('no deco fields at all', () async {
    await expectSummaryMatchesLegacyFold('dive-no-deco-fields', const [
      ProfileSample(timestamp: 0, depth: 1.0),
      ProfileSample(timestamp: 30, depth: 15.0),
      ProfileSample(timestamp: 60, depth: 3.0),
    ]);
  });

  test('decoType 1 only (never a deco stop)', () async {
    await expectSummaryMatchesLegacyFold('dive-deco-type-1-only', const [
      ProfileSample(timestamp: 0, depth: 5.0, decoType: 0),
      ProfileSample(timestamp: 20, depth: 20.0, decoType: 1),
      ProfileSample(timestamp: 40, depth: 5.0, decoType: 1),
    ]);
  });

  test('decoType 2 sets the deco-stop flag', () async {
    await expectSummaryMatchesLegacyFold('dive-deco-type-2', const [
      ProfileSample(timestamp: 0, depth: 5.0, decoType: 0),
      ProfileSample(timestamp: 30, depth: 25.0, decoType: 2),
    ]);
  });

  test(
    'a positive ceiling with no deco type at all still means deco',
    () async {
      await expectSummaryMatchesLegacyFold('dive-ceiling-only', const [
        ProfileSample(timestamp: 0, depth: 5.0),
        ProfileSample(timestamp: 20, depth: 30.0, ceiling: 3.0),
      ]);
    },
  );

  test('a zero ceiling does not count as positive', () async {
    await expectSummaryMatchesLegacyFold('dive-ceiling-zero', const [
      ProfileSample(timestamp: 0, depth: 5.0, ceiling: 0.0),
      ProfileSample(timestamp: 20, depth: 10.0),
    ]);
  });
}
