import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test(
    'a review that changes no synced row does not touch the clock',
    () async {
      // The marker is device-local. With no findings before and none now,
      // nothing that syncs has changed, so bumping the parent's clock would
      // hand every peer a version to fetch for the commonest case of all.
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp-empty',
        findings: const [],
        engineVersion: 1,
        now: t0,
      );
      expect(
        (await db.select(db.syncRecords).get())
            .where((r) => r.entityType == 'equipment')
            .map((r) => r.recordId),
        isEmpty,
      );

      // A findings row IS synced, so writing one does bump it.
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp1',
        findings: [incident()],
        engineVersion: 1,
        now: t0,
      );
      expect(
        (await db.select(db.syncRecords).get())
            .where((r) => r.entityType == 'equipment')
            .map((r) => r.recordId),
        ['reg'],
      );
    },
  );

  test(
    'a recurring finding on a tag this build does not know is kept',
    () async {
      // A newer peer can emit issueRecurring for an observation tag added
      // after this build. This engine cannot re-emit it, so its absence here
      // says nothing, and a tombstone would delete it on the peer that
      // computed it (as phase 3a keeps unknown observation tags).
      final evidence = FindingEvidence(
        n: 20,
        windowStart: t0,
        windowEnd: t0.add(const Duration(days: 30)),
        diveIds: const ['d1', 'd2', 'd3'],
        values: const {'count': 3},
        tag: 'tagFromTheFuture',
      );
      await db
          .into(db.equipmentFindings)
          .insert(
            EquipmentFindingsCompanion.insert(
              id: conditionFindingId(
                'reg',
                ConditionRuleId.issueRecurring,
                tag: 'tagFromTheFuture',
              ),
              equipmentId: 'reg',
              ruleId: ConditionRuleId.issueRecurring.dbValue,
              severity: ConditionSeverity.caution.dbValue,
              evidence: Value(evidence.encode()),
              evidenceFingerprint: evidenceFingerprint(evidence),
              engineVersion: 1,
              createdAt: 1,
            ),
          );
      // And one on a known tag, which this engine would re-emit if it fired.
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp1',
        findings: [
          recurring(const ['d1', 'd2', 'd3']),
        ],
        engineVersion: 1,
        now: t0,
      );

      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp2',
        findings: const [],
        engineVersion: 1,
        now: t0.add(const Duration(days: 1)),
      );

      final left = (await db.select(db.equipmentFindings).get())
          .map((f) => f.id)
          .toSet();
      expect(left, {
        conditionFindingId(
          'reg',
          ConditionRuleId.issueRecurring,
          tag: 'tagFromTheFuture',
        ),
      });
      expect(
        await tombstones(),
        {
          conditionFindingId(
            'reg',
            ConditionRuleId.issueRecurring,
            tag: 'freeFlow',
          ),
        },
        reason: 'the known tag stopped firing and goes, the unknown one stays',
      );
    },
  );

  test('a finding that fires again clears its old tombstone', () async {
    // Ids are deterministic, so a rule that stops firing and later fires
    // again writes the same id. The tombstone from the stop would ride the
    // next changeset beside the new row and delete it on every peer.
    final f = recurring(['d1', 'd2', 'd3']);
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [f],
      engineVersion: 1,
      now: t0,
    );
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: const [],
      engineVersion: 1,
      now: t0,
    );
    expect(await tombstones(), {f.id});

    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp3',
      findings: [f],
      engineVersion: 1,
      now: t0,
    );
    expect(await tombstones(), isEmpty);
    expect((await repo.getFindings('reg')).single.id, f.id);
  });

  test('re-emitting an identical finding writes nothing', () async {
    // The sweep recomputes an item whenever anything about a dive moves,
    // and most of those recomputes land on the same finding. Rewriting an
    // identical row would hand every peer the same record to fetch again.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [incident()],
      engineVersion: 1,
      now: t0,
    );
    await db.delete(db.syncRecords).go();

    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [incident()],
      engineVersion: 1,
      now: t0.add(const Duration(days: 1)),
    );
    expect(await db.select(db.syncRecords).get(), isEmpty);
    // Still stored, and still the only row: skipping the write must not
    // let the deletion pass mistake it for a rule that stopped firing.
    expect(
      (await repo.getFindings('reg')).single.ruleId,
      ConditionRuleId.incidentLinked,
    );
    expect(await tombstones(), isEmpty);
  });

  test('a moved window is written even when the fingerprint holds', () async {
    // evidenceFingerprint hashes the dive ids and the values, not the
    // window. Editing a dive's date moves windowStart without changing
    // either, so a skip-if-identical check built on the fingerprint alone
    // would leave the sentence quoting a date the dive no longer has.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [incident()],
      engineVersion: 1,
      now: t0,
    );
    final before = (await repo.getFindings('reg')).single;

    final moved = incident();
    final shifted = EquipmentFinding(
      id: moved.id,
      equipmentId: moved.equipmentId,
      ruleId: moved.ruleId,
      severity: moved.severity,
      value: moved.value,
      evidence: FindingEvidence(
        n: moved.evidence.n,
        windowStart: moved.evidence.windowStart.add(const Duration(days: 2)),
        windowEnd: moved.evidence.windowEnd.add(const Duration(days: 2)),
        diveIds: moved.evidence.diveIds,
        values: moved.evidence.values,
        tag: moved.evidence.tag,
        slot: moved.evidence.slot,
      ),
      evidenceFingerprint: moved.evidenceFingerprint,
      engineVersion: moved.engineVersion,
      createdAt: moved.createdAt,
    );
    expect(shifted.evidenceFingerprint, before.evidenceFingerprint);

    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [shifted],
      engineVersion: 1,
      now: t0.add(const Duration(days: 1)),
    );
    final after = (await repo.getFindings('reg')).single;
    expect(
      after.evidence.windowStart,
      before.evidence.windowStart.add(const Duration(days: 2)),
    );
  });

  test('a review with no findings still records the engine version', () async {
    // An item the engine cleared is the common case. Recording 0 here (the
    // newest version among no rows) made the marker read as stale forever,
    // so every read recomputed instead of serving from it.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp-empty',
      findings: const [],
      engineVersion: 1,
      now: t0,
    );
    final review = await repo.getReview('reg');
    expect(review!.engineVersion, 1);
    expect(review.inputFingerprint, 'fp-empty');
    expect(await repo.getFindings('reg'), isEmpty);
  });

  test('saveReview stores findings, the marker and marks the parent', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
        incident(),
      ],
      engineVersion: 1,
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
        engineVersion: 1,
        now: t0,
      );
      final later = t0.add(const Duration(days: 10));
      await repo.saveReview(
        equipmentId: 'reg',
        inputFingerprint: 'fp2',
        findings: [
          recurring(['d1', 'd2', 'd3', 'd4'], createdAt: later),
        ],
        engineVersion: 1,
        now: later,
      );
      final stored = (await repo.getFindings('reg')).single;
      expect(stored.createdAt, t0);
      expect(stored.value, 4);
      expect(stored.evidence.diveIds, hasLength(4));
      expect(await tombstones(), isEmpty);
    },
  );

  /// Dive dates for the carry-over rule: d1 to d3 are the dives the
  /// finding was dismissed with, d4 to d6 happened afterwards, and the
  /// b-prefixed ones are an imported backlog from years before.
  final diveDates = <String, DateTime>{
    'd1': t0,
    'd2': t0.add(const Duration(days: 1)),
    'd3': t0.add(const Duration(days: 1)),
    'd4': t0.add(const Duration(days: 4)),
    'd5': t0.add(const Duration(days: 5)),
    'd6': t0.add(const Duration(days: 8)),
    'b1': t0.subtract(const Duration(days: 900)),
    'b2': t0.subtract(const Duration(days: 800)),
    'b3': t0.subtract(const Duration(days: 700)),
  };

  test('a dismissed finding stays dismissed until three new dives', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
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
      engineVersion: 1,
      diveDates: diveDates,
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
      engineVersion: 1,
      diveDates: diveDates,
      now: t0.add(const Duration(days: 9)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isFalse);
  });

  test('one new dive named three times is still one new dive', () async {
    // incidentLinked names a dive once per incident, so three incidents on
    // one dive after the dismissal list that dive three times. The rule
    // is three new dives, not three new entries.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
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
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [
        recurring(['d1', 'd2', 'd3', 'd4', 'd4', 'd4']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
      now: t0.add(const Duration(days: 5)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isTrue);
  });

  test('a row for a rule this build does not know survives a review', () async {
    // A newer peer's rule arrives by sync. This build cannot compute it,
    // so it never appears in the engine's output; deleting it as "stopped
    // firing" would tombstone it and delete it on the newer peer too.
    await db
        .into(db.equipmentFindings)
        .insert(
          EquipmentFindingsCompanion.insert(
            id: 'cf_reg_futureRule',
            equipmentId: 'reg',
            ruleId: 'futureRule',
            severity: 'caution',
            evidenceFingerprint: 'x',
            engineVersion: 9,
            createdAt: 1,
          ),
        );
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [incident()],
      engineVersion: 1,
      now: t0,
    );
    final rows = await db.select(db.equipmentFindings).get();
    expect(rows.map((r) => r.id), contains('cf_reg_futureRule'));
    expect(await tombstones(), isEmpty);
  });

  test('an imported backlog of older dives leaves a dismissal alone', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
      now: t0,
    );
    await repo.setDismissed(
      findingId: conditionFindingId(
        'reg',
        ConditionRuleId.issueRecurring,
        tag: 'freeFlow',
      ),
      dismissed: true,
      now: t0.add(const Duration(days: 1)),
    );

    // Three dive ids the evidence has not seen, but every one of them
    // happened years before the dismissal. Nothing has been learned since
    // the diver said they had seen this, so it stays dismissed: otherwise
    // importing a logbook would re-raise every dismissed finding at once.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [
        recurring(['d1', 'd2', 'd3', 'b1', 'b2', 'b3']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
      now: t0.add(const Duration(days: 2)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isTrue);

    // Three dives that did happen after it do clear it.
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp3',
      findings: [
        recurring(['d1', 'd2', 'd3', 'b1', 'b2', 'b3', 'd4', 'd5', 'd6']),
      ],
      engineVersion: 1,
      diveDates: diveDates,
      now: t0.add(const Duration(days: 9)),
    );
    expect((await repo.getFindings('reg')).single.isDismissed, isFalse);
  });

  test('a stored row is keyed to the item the review is for', () async {
    // The transaction scopes its deletions and its marker to this
    // equipmentId, so a row written under a different one would be
    // invisible to both and leave the item's findings inconsistent.
    final stray = incident().copyWith(equipmentId: 'other');
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [stray],
      engineVersion: 1,
      now: t0,
    );
    final rows = await db.select(db.equipmentFindings).get();
    expect(rows.map((r) => r.equipmentId), ['reg']);
    expect((await repo.getFindings('reg')).single.equipmentId, 'reg');
  });

  test('a rule that stops firing is deleted with a tombstone', () async {
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp1',
      findings: [
        recurring(['d1', 'd2', 'd3']),
        incident(),
      ],
      engineVersion: 1,
      now: t0,
    );
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp2',
      findings: [incident()],
      engineVersion: 1,
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
        engineVersion: 1,
        now: t0,
      );
      await repo.saveReview(
        equipmentId: 'bcd',
        inputFingerprint: 'fp1',
        findings: [
          incident().copyWith(id: 'cf_bcd_incidentLinked', equipmentId: 'bcd'),
        ],
        engineVersion: 1,
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
        engineVersion: 1,
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
      engineVersion: 1,
      now: t0,
    );
    await (db.delete(db.equipment)..where((t) => t.id.equals('reg'))).go();
    expect(await repo.getFindings('reg'), isEmpty);
    expect(await repo.getReview('reg'), isNull);
  });
}
