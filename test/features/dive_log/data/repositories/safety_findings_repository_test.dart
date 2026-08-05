import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncRepository syncRepository;
  late SafetyFindingsRepository repo;
  final now = DateTime.utc(2026, 7, 16);

  SafetyFinding finding(
    String id, {
    SafetyRuleId rule = SafetyRuleId.rapidAscent,
  }) => SafetyFinding(
    id: id,
    diveId: 'dive-1',
    ruleId: rule,
    severity: SafetySeverity.caution,
    startTimestamp: 100,
    endTimestamp: 140,
    value: 14.2,
    engineVersion: 1,
    createdAt: now,
  );

  Future<void> createTestDive(String id) async {
    final ts = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    syncRepository = SyncRepository();
    repo = SafetyFindingsRepository(db: db, syncRepository: syncRepository);
    await createTestDive('dive-1');
  });

  tearDown(() => tearDownTestDatabase());

  test('getReview returns null for a never-analyzed dive', () async {
    expect(await repo.getReview('dive-1'), isNull);
  });

  test('saveReview then getReview round-trips findings', () async {
    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [
          finding('f1'),
          finding('f2', rule: SafetyRuleId.sawtoothProfile),
        ],
      ),
    );
    final review = await repo.getReview('dive-1');
    expect(review, isNotNull);
    expect(review!.engineVersion, 1);
    expect(review.findings, hasLength(2));
    expect(review.findings.first.ruleId, SafetyRuleId.rapidAscent);
    expect(review.findings.first.value, 14.2);
  });

  test('saveReview replaces prior findings', () async {
    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [finding('f1')],
      ),
    );
    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 2,
        reviewedAt: now,
        findings: [finding('f3')],
      ),
    );
    final review = await repo.getReview('dive-1');
    expect(review!.engineVersion, 2);
    expect(review.findings.map((f) => f.id), ['f3']);
  });

  test('a zero-findings review still marks the dive analyzed', () async {
    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: const [],
      ),
    );
    final review = await repo.getReview('dive-1');
    expect(review, isNotNull);
    expect(review!.findings, isEmpty);
  });

  test('setDismissed toggles dismissedAt', () async {
    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [finding('f1')],
      ),
    );
    await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);
    var review = await repo.getReview('dive-1');
    expect(review!.findings.single.isDismissed, isTrue);
    await repo.setDismissed(findingId: 'f1', dismissed: false, now: now);
    review = await repo.getReview('dive-1');
    expect(review!.findings.single.isDismissed, isFalse);
  });

  test(
    'setDismissed advances the parent dive HLC so the change syncs',
    () async {
      // dive_safety_findings has no HLC of its own; the incremental exporter
      // pulls findings for dives whose parent HLC advanced. A standalone dismiss
      // must therefore bump the parent dive's HLC or the change is stranded.
      await syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: 'dive-1',
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      await repo.saveReview(
        SafetyReview(
          diveId: 'dive-1',
          engineVersion: 1,
          reviewedAt: now,
          findings: [finding('f1')],
        ),
      );

      // Watermark = the dive's HLC after saveReview. An export since this
      // watermark is empty until a further change advances the dive's HLC.
      final watermark =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'dive-1'")
                  .getSingle())
              .read<String>('hlc');

      final serializer = SyncDataSerializer();
      final deviceId = await syncRepository.getDeviceId();
      final before = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: watermark,
        deletions: const [],
      );
      expect(
        before.data.diveSafetyFindings,
        isEmpty,
        reason: 'nothing changed since the watermark yet',
      );

      await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);

      final after = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: watermark,
        deletions: const [],
      );
      final exportedIds = after.data.diveSafetyFindings
          .map((f) => f['id'])
          .toSet();
      expect(
        exportedIds,
        contains('f1'),
        reason:
            'dismiss must advance the dive HLC so the finding is re-exported',
      );
      final exported = after.data.diveSafetyFindings.firstWhere(
        (f) => f['id'] == 'f1',
      );
      expect(exported['dismissedAt'], isNotNull);
    },
  );

  test('saveReview advances the parent dive HLC so the review syncs', () async {
    // A review computed lazily on first view does not otherwise touch the
    // dive, but both safety exporters gate on the parent dive's HLC. Without
    // a bump the freshly computed review (and its device-local finding ids)
    // would never reach other devices, so a later dismiss could reference a
    // finding id a peer never received.
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: 'dive-1',
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    final watermark =
        (await db
                .customSelect("SELECT hlc FROM dives WHERE id = 'dive-1'")
                .getSingle())
            .read<String>('hlc');

    final serializer = SyncDataSerializer();
    final deviceId = await syncRepository.getDeviceId();
    final before = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(
      before.data.diveSafetyReviews,
      isEmpty,
      reason: 'no review saved yet',
    );
    expect(before.data.diveSafetyFindings, isEmpty);

    await repo.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [finding('f1')],
      ),
    );

    final after = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(
      after.data.diveSafetyReviews,
      isNotEmpty,
      reason: 'saveReview must advance the dive HLC so the review is exported',
    );
    expect(
      after.data.diveSafetyFindings.map((f) => f['id']).toSet(),
      contains('f1'),
      reason: 'the review findings must ride the same dive-HLC bump',
    );
  });

  test(
    'getReview skips rows whose rule_id is not a known SafetyRuleId',
    () async {
      // Persist a valid review with one recognized finding.
      await repo.saveReview(
        SafetyReview(
          diveId: 'dive-1',
          engineVersion: 1,
          reviewedAt: now,
          findings: [finding('f1')],
        ),
      );
      // Simulate a finding synced from a newer app whose rule_id this build does
      // not recognize. It is inserted raw because saveReview only accepts valid
      // enum values. It must be dropped on read, not coerced to a default rule.
      await db
          .into(db.diveSafetyFindings)
          .insert(
            DiveSafetyFindingsCompanion.insert(
              id: 'f-unknown',
              diveId: 'dive-1',
              ruleId: 'someFutureRuleThatDoesNotExist',
              severity: SafetySeverity.caution.dbValue,
              engineVersion: 1,
              createdAt: now.millisecondsSinceEpoch,
            ),
          );

      final review = await repo.getReview('dive-1');
      expect(review, isNotNull);
      expect(
        review!.findings.map((f) => f.id),
        ['f1'],
        reason: 'the unknown-rule row is skipped, not coerced to rapidAscent',
      );
    },
  );

  test(
    'clearReviewForDive removes marker and findings with tombstones',
    () async {
      await repo.saveReview(
        SafetyReview(
          diveId: 'dive-1',
          engineVersion: 1,
          reviewedAt: now,
          findings: [finding('f1')],
        ),
      );
      await SafetyFindingsRepository.clearReviewForDive(
        db,
        syncRepository,
        'dive-1',
      );
      expect(await repo.getReview('dive-1'), isNull);

      final tombstones = await db.select(db.deletionLog).get();
      expect(
        tombstones.map((t) => t.entityType).toSet(),
        containsAll(['diveSafetyFindings', 'diveSafetyReviews']),
      );
    },
  );
}
