import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
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
    String diveId = 'dive-1',
  }) => SafetyFinding(
    id: id,
    diveId: diveId,
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
      expect(review!.findings.map((f) => f.id), [
        'f1',
      ], reason: 'the unknown-rule row is skipped, not coerced to rapidAscent');
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

  group('setDismissedForDives', () {
    // Every rule is enabled unless a test narrows the set.
    final allRules = {for (final r in SafetyRuleId.values) r.dbValue};

    Future<void> seed(String diveId, List<SafetyFinding> findings) async {
      await repo.saveReview(
        SafetyReview(
          diveId: diveId,
          engineVersion: 1,
          reviewedAt: now,
          findings: findings,
        ),
      );
    }

    Future<Set<String>> dismissedIds(String diveId) async {
      final review = await repo.getReview(diveId);
      return review!.findings
          .where((f) => f.isDismissed)
          .map((f) => f.id)
          .toSet();
    }

    test('dismisses every active finding across the given dives', () async {
      await createTestDive('dive-2');
      await seed('dive-1', [finding('f1'), finding('f2')]);
      await seed('dive-2', [finding('f3', diveId: 'dive-2')]);

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1', 'dive-2'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      expect(changed, 3);
      expect(await dismissedIds('dive-1'), {'f1', 'f2'});
      expect(await dismissedIds('dive-2'), {'f3'});
    });

    test('leaves dives outside the id list untouched', () async {
      await createTestDive('dive-2');
      await seed('dive-1', [finding('f1')]);
      await seed('dive-2', [finding('f3', diveId: 'dive-2')]);

      await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      expect(await dismissedIds('dive-2'), isEmpty);
    });

    test('skips findings whose rule is not enabled', () async {
      await seed('dive-1', [
        finding('f1'),
        finding('f2', rule: SafetyRuleId.sawtoothProfile),
      ]);

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: {SafetyRuleId.rapidAscent.dbValue},
        now: now,
      );

      expect(changed, 1);
      expect(await dismissedIds('dive-1'), {
        'f1',
      }, reason: 'a rule the user has hidden must not be silently dismissed');
    });

    test('skips rows whose rule_id is not a known SafetyRuleId', () async {
      await seed('dive-1', [finding('f1')]);
      await db
          .into(db.diveSafetyFindings)
          .insert(
            DiveSafetyFindingsCompanion.insert(
              id: 'from-the-future',
              diveId: 'dive-1',
              ruleId: 'brand_new_rule',
              severity: SafetySeverity.caution.dbValue,
              engineVersion: 1,
              createdAt: now.millisecondsSinceEpoch,
            ),
          );

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      expect(changed, 1);
      final row = await (db.select(
        db.diveSafetyFindings,
      )..where((t) => t.id.equals('from-the-future'))).getSingle();
      expect(
        row.dismissedAt,
        isNull,
        reason: 'a finding this build cannot render must not be dismissed',
      );
    });

    test('restores dismissed findings when dismissed is false', () async {
      await seed('dive-1', [finding('f1'), finding('f2')]);
      await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: false,
        enabledRuleIds: allRules,
        now: now,
      );

      expect(changed, 2);
      expect(await dismissedIds('dive-1'), isEmpty);
    });

    test('counts only findings whose state actually changes', () async {
      await seed('dive-1', [finding('f1'), finding('f2')]);
      await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      expect(changed, 1, reason: 'f1 was already dismissed');
    });

    test('spans more dives than one query chunk', () async {
      final diveIds = <String>['dive-1'];
      await seed('dive-1', [finding('f1')]);
      for (var i = 2; i <= 7; i++) {
        final diveId = 'dive-$i';
        await createTestDive(diveId);
        await seed(diveId, [finding('f$i', diveId: diveId)]);
        diveIds.add(diveId);
      }

      final changed = await repo.setDismissedForDives(
        diveIds: diveIds,
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
        chunkSize: 2,
      );

      expect(changed, 7);
      for (final diveId in diveIds) {
        expect(await dismissedIds(diveId), hasLength(1));
      }
    });

    test('advances the parent dive HLC so the change syncs', () async {
      await syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: 'dive-1',
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      await seed('dive-1', [finding('f1')]);

      final watermark =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'dive-1'")
                  .getSingle())
              .read<String>('hlc');
      final serializer = SyncDataSerializer();
      final deviceId = await syncRepository.getDeviceId();

      await repo.setDismissedForDives(
        diveIds: ['dive-1'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      final after = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: watermark,
        deletions: const [],
      );
      final exported = after.data.diveSafetyFindings.firstWhere(
        (f) => f['id'] == 'f1',
      );
      expect(exported['dismissedAt'], isNotNull);
    });

    test(
      'announces the chunks that committed even when a later one throws',
      () async {
        // A multi-chunk run is several transactions. If chunk 2 fails, chunk 1
        // is already committed and its rows are marked pending; skipping the
        // local-change notification would strand them until some unrelated
        // write happened to kick the sync layer.
        final failing = _FailingSyncRepository();
        final failRepo = SafetyFindingsRepository(
          db: db,
          syncRepository: failing,
        );
        await createTestDive('dive-2');
        await seed('dive-1', [finding('f1')]);
        await seed('dive-2', [finding('f2', diveId: 'dive-2')]);

        final notifications = <void>[];
        final subscription = SyncEventBus.changes.listen(notifications.add);
        addTearDown(() => subscription.cancel());

        failing.failAfter = 2;
        await expectLater(
          failRepo.setDismissedForDives(
            diveIds: ['dive-1', 'dive-2'],
            dismissed: true,
            enabledRuleIds: allRules,
            now: now,
            chunkSize: 1,
          ),
          throwsA(isA<StateError>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(await dismissedIds('dive-1'), {'f1'});
        expect(await dismissedIds('dive-2'), isEmpty);
        expect(
          notifications,
          hasLength(1),
          reason: 'the committed chunk must still reach the sync layer',
        );
      },
    );

    test('leaves the dive HLC alone when nothing changes', () async {
      // An unconditional UPDATE would bump every dive's HLC and push the whole
      // library on every tap; only dives with a real change may be marked.
      await createTestDive('dive-2');
      await seed('dive-1', [finding('f1')]);
      await seed('dive-2', [finding('f3', diveId: 'dive-2')]);
      await repo.setDismissed(findingId: 'f3', dismissed: true, now: now);

      final before =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'dive-2'")
                  .getSingle())
              .read<String>('hlc');

      final changed = await repo.setDismissedForDives(
        diveIds: ['dive-1', 'dive-2'],
        dismissed: true,
        enabledRuleIds: allRules,
        now: now,
      );

      final after =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'dive-2'")
                  .getSingle())
              .read<String>('hlc');
      expect(changed, 1);
      expect(after, before, reason: 'dive-2 had nothing to dismiss');
    });
  });
}

/// A [SyncRepository] that fails once a set number of pending marks have been
/// recorded, to force a mid-run failure in a multi-chunk bulk write.
class _FailingSyncRepository extends SyncRepository {
  int? failAfter;
  int _marks = 0;

  @override
  Future<void> markRecordPending({
    required String entityType,
    required String recordId,
    required int localUpdatedAt,
  }) async {
    if (failAfter != null && _marks >= failAfter!) {
      throw StateError('sync bookkeeping failed');
    }
    _marks++;
    return super.markRecordPending(
      entityType: entityType,
      recordId: recordId,
      localUpdatedAt: localUpdatedAt,
    );
  }
}
