import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

import '../../../../helpers/test_database.dart';

/// The safety review grades the primary source's own samples, so a review
/// stored before the primary source changed graded another computer's
/// recording. Changing it drops the stored review so it recomputes on next
/// view, as a profile edit already does.
void main() {
  late AppDatabase db;
  late SafetyFindingsRepository findings;
  late ProfileSeriesRepository series;

  Future<void> computer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Computer $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> source(String id, String computerId, {bool primary = false}) =>
      db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: id,
              diveId: 'dive-1',
              computerId: Value(computerId),
              isPrimary: Value(primary),
              importedAt: DateTime(2026, 9, 14),
              createdAt: DateTime(2026, 9, 14),
            ),
          );

  Future<void> samples(
    String computerId,
    String sourceId, {
    bool primary = true,
  }) => series.insertSeries(
    diveId: 'dive-1',
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: primary,
    samples: const [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 60, depth: 18),
    ],
    now: 1000,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    findings = SafetyFindingsRepository(
      db: db,
      syncRepository: SyncRepository(),
    );
    series = ProfileSeriesRepository();
    const now = 1750000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await computer('dc-a');
    await computer('dc-b');
    await source('src-a', 'dc-a', primary: true);
    await source('src-b', 'dc-b');
    await samples('dc-a', 'src-a');
    await samples('dc-b', 'src-b', primary: false);
    await findings.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: SafetyReviewService.engineVersion,
        reviewedAt: DateTime(2026, 9, 14),
        inputsHash: 'settings',
        findings: const [],
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('setPrimaryDataSource drops the stored review', () async {
    expect(await findings.getReview('dive-1'), isNotNull);

    await DiveRepository().setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-b',
    );

    expect(await findings.getReview('dive-1'), isNull);
  });
}
