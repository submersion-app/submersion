import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentFindingsRepository repo;
  final t0 = DateTime.utc(2026, 1, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentFindingsRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  /// A recurring-issue finding whose evidence names [dives] on [dates].
  EquipmentFinding recurring(
    List<String> dives, {
    DateTime? createdAt,
    Map<String, DateTime> dates = const {},
  }) {
    final evidence = FindingEvidence(
      n: 20,
      windowStart: t0,
      windowEnd: t0.add(const Duration(days: 30)),
      diveIds: dives,
      values: {'count': dives.length.toDouble()},
      tag: 'freeFlow',
    );
    return EquipmentFinding(
      id: conditionFindingId(
        'reg',
        ConditionRuleId.issueRecurring,
        tag: 'freeFlow',
      ),
      equipmentId: 'reg',
      ruleId: ConditionRuleId.issueRecurring,
      severity: ConditionSeverity.caution,
      value: dives.length.toDouble(),
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: createdAt ?? t0,
    );
  }

  EquipmentFinding incident() {
    final evidence = FindingEvidence(
      n: 1,
      windowStart: t0,
      windowEnd: t0,
      values: const {'count': 1},
    );
    return EquipmentFinding(
      id: conditionFindingId('reg', ConditionRuleId.incidentLinked),
      equipmentId: 'reg',
      ruleId: ConditionRuleId.incidentLinked,
      severity: ConditionSeverity.info,
      value: 1,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: t0,
    );
  }

  Future<Set<String>> tombstones() async => {
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == 'equipmentFindings') t.recordId,
  };

  test('saveReview stores findings, the marker and marks the parent', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
        incident(),
      ],
      now: t0,
    );
    final stored = await repo.getFindings('reg');
    expect(stored.map((f) => f.ruleId), [
      ConditionRuleId.issueRecurring,
      ConditionRuleId.incidentLinked,
    ]);
    expect(stored.first.evidence.diveIds, ['d1', 'd2', 'd3']);
    expect(stored.first.evidence.tag, 'freeFlow');
    final review = await repo.getReview('reg');
    expect(review!.inputFingerprint, 'fp1');
    expect(review.engineVersion, 1);
    expect(review.reviewedAt, t0);
    final parent = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('reg'))).getSingle();
    expect(parent.hlc, isNotNull);
  });

  test(
    'a re-emitted finding keeps its created_at and updates its evidence',
    () async {
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp1',
        findings: [
          recurring(['d1', 'd2', 'd3'], createdAt: t0),
        ],
        now: t0,
      );
      final later = t0.add(const Duration(days: 10));
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp2',
        findings: [
          recurring(['d1', 'd2', 'd3', 'd4'], createdAt: later),
        ],
        now: later,
      );
      final stored = (await repo.getFindings('reg')).single;
      expect(stored.createdAt, t0);
      expect(stored.value, 4);
      expect(stored.evidence.diveIds, hasLength(4));
      expect(await tombstones(), isEmpty);
    },
  );

  test('a dismissed finding stays dismissed until three new dives', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
      ],
      now: t0,
    );
    final id = conditionFindingId(
      'reg',
      ConditionRuleId.issueRecurring,
      tag: 'freeFlow',
    );
    await repo.setDismissed(
      findingId: id,
      dismissed: true,
      now: t0.add(const Duration(days: 1)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isTrue);

    // Two new dives: still dismissed.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [
        recurring(['d1', 'd2', 'd3', 'd4', 'd5']),
      ],
      now: t0.add(const Duration(days: 5)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isTrue);

    // Three new dives: the dismissal clears.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp3',
      findings: [
        recurring(['d1', 'd2', 'd3', 'd4', 'd5', 'd6']),
      ],
      now: t0.add(const Duration(days: 9)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isFalse);
  });

  test('a rule that stops firing is deleted with a tombstone', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
        incident(),
      ],
      now: t0,
    );
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [incident()],
      now: t0,
    );
    final stored = await repo.getFindings('reg');
    expect(stored.map((f) => f.ruleId), [ConditionRuleId.incidentLinked]);
    expect(await tombstones(), {
      conditionFindingId(
        'reg',
        ConditionRuleId.issueRecurring,
        tag: 'freeFlow',
      ),
    });
  });

  test(
    'getFindings lists undismissed first, getAllUndismissed spans items',
    () async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'bcd',
              name: 'BCD',
              type: 'bcd',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp1',
        findings: [
          recurring(['d1', 'd2', 'd3']),
          incident(),
        ],
        now: t0,
      );
      await repo.saveReview(
        equipmentId: 'bcd',
        inputFingerprint: 'fp1',
        findings: [
          incident().copyWith(id: 'cf_bcd_incidentLinked', equipmentId: 'bcd'),
        ],
        now: t0,
      );
      await repo.setDismissed(
        findingId: conditionFindingId(
          'reg',
          ConditionRuleId.issueRecurring,
          tag: 'freeFlow',
        ),
        dismissed: true,
        now: t0,
      );
      final reg = await repo.getFindings('reg');
      expect(reg.first.ruleId, ConditionRuleId.incidentLinked);
      expect(reg.last.isDismissed, isTrue);
      final all = await repo.getAllUndismissed();
      expect(all.map((f) => f.equipmentId), unorderedEquals(['reg', 'bcd']));
    },
  );

  test(
    'a row whose rule this build does not know is dropped on read',
    () async {
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp1',
        findings: [incident()],
        now: t0,
      );
      await db
          .into(db.equipmentFindings)
          .insert(
            EquipmentFindingsCompanion.insert(
              id: 'cf_reg_futureRule',
              equipmentId: 'reg',
              ruleId: 'futureRule',
              severity: 'info',
              evidenceFingerprint: 'x',
              engineVersion: 9,
              createdAt: 1,
            ),
          );
      expect((await repo.getFindings('reg')).map((f) => f.ruleId), [
        ConditionRuleId.incidentLinked,
      ]);
    },
  );

  test('deleting the item cascades findings and the marker', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [incident()],
      now: t0,
    );
    await (db.delete(db.equipment)..where((t) => t.id.equals('reg'))).go();
    expect(await repo.getFindings('reg'), isEmpty);
    expect(await repo.getReview('reg'), isNull);
  });
}
