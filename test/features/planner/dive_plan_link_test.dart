import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../helpers/test_database.dart';

/// A plan links to one dive and a dive to one plan (issue #4003). The link is
/// `dive_plans.linked_dive_id`, the column Convert to dive already writes; the
/// by-hand link writes it directly so the plan's children are left alone.
void main() {
  late DivePlanRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id, {int? number, bool isPlanned = false}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveNumber: Value(number),
          isPlanned: Value(isPlanned),
          diveDateTime: const Value(1000),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  Future<void> seedPlan(String id, {String? linkedDiveId}) =>
      repository.savePlan(
        domain.DivePlan(
          id: id,
          name: 'Plan $id',
          gfLow: 30,
          gfHigh: 70,
          linkedDiveId: linkedDiveId,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

  Future<bool> isPending(String planId) async {
    final pending = await SyncRepository().getPendingRecords();
    return pending.any(
      (r) => r.entityType == 'divePlans' && r.recordId == planId,
    );
  }

  Future<void> clearPending() =>
      (db.delete(db.syncRecords)..where((t) => t.id.isNotNull())).go();

  test('link then unlink round-trips and writes a sync record', () async {
    await seedDive('dive-1');
    await seedPlan('plan-1');
    await clearPending();

    final result = await repository.linkPlanToDive('plan-1', 'dive-1');

    expect(result.previousDiveId, isNull);
    expect(result.displacedPlanIds, isEmpty);
    expect((await repository.getPlan('plan-1'))!.linkedDiveId, 'dive-1');
    expect(await isPending('plan-1'), isTrue);

    await clearPending();
    await repository.unlinkPlan('plan-1');

    expect((await repository.getPlan('plan-1'))!.linkedDiveId, isNull);
    expect(await isPending('plan-1'), isTrue);
  });

  test('linking leaves the plan\'s summary numbers alone', () async {
    await seedDive('dive-1');
    await repository.savePlan(
      domain.DivePlan(
        id: 'plan-1',
        name: 'Plan',
        gfLow: 30,
        gfHigh: 70,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      summary: const PlanSummaryData(maxDepth: 40, runtimeSeconds: 1800),
    );

    await repository.linkPlanToDive('plan-1', 'dive-1');

    final summary = await repository.getPlanSummary('plan-1');
    expect(summary!.maxDepth, 40);
    expect(summary.runtimeSeconds, 1800);
  });

  test(
    'linking a plan linked elsewhere moves the link and reports the old dive',
    () async {
      await seedDive('dive-1');
      await seedDive('dive-2');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');

      final result = await repository.linkPlanToDive('plan-1', 'dive-2');

      expect(result.previousDiveId, 'dive-1');
      expect(await repository.getPlanByLinkedDiveId('dive-1'), isNull);
      expect((await repository.getPlanByLinkedDiveId('dive-2'))!.id, 'plan-1');
    },
  );

  test(
    'linking a dive held by another plan clears that plan and reports it',
    () async {
      await seedDive('dive-1');
      await seedPlan('plan-old', linkedDiveId: 'dive-1');
      await seedPlan('plan-new');
      await clearPending();

      final result = await repository.linkPlanToDive('plan-new', 'dive-1');

      expect(result.displacedPlanIds, ['plan-old']);
      expect((await repository.getPlan('plan-old'))!.linkedDiveId, isNull);
      expect(await isPending('plan-old'), isTrue);
      expect(await isPending('plan-new'), isTrue);
    },
  );

  test('unlinking the new plan leaves the dive with no plan', () async {
    await seedDive('dive-1');
    await seedPlan('plan-old', linkedDiveId: 'dive-1');
    await seedPlan('plan-new');
    await repository.linkPlanToDive('plan-new', 'dive-1');

    await repository.unlinkPlan('plan-new');

    expect(await repository.getPlanByLinkedDiveId('dive-1'), isNull);
  });

  test('relinking the same plan to its dive displaces nothing', () async {
    await seedDive('dive-1');
    await seedPlan('plan-1', linkedDiveId: 'dive-1');

    final result = await repository.linkPlanToDive('plan-1', 'dive-1');

    expect(result.previousDiveId, 'dive-1');
    expect(result.displacedPlanIds, isEmpty);
    expect((await repository.getPlan('plan-1'))!.linkedDiveId, 'dive-1');
  });

  test(
    'getPlanByLinkedDiveId still picks the newest when a sync duplicate exists',
    () async {
      await seedDive('dive-1');
      await seedPlan('plan-a', linkedDiveId: 'dive-1');
      await seedPlan('plan-b', linkedDiveId: 'dive-1');
      await (db.update(db.divePlans)..where((t) => t.id.equals('plan-a')))
          .write(const DivePlansCompanion(updatedAt: Value(1)));

      expect((await repository.getPlanByLinkedDiveId('dive-1'))!.id, 'plan-b');
    },
  );

  test('linking a missing dive throws and changes nothing', () async {
    await seedDive('dive-1');
    await seedPlan('plan-1', linkedDiveId: 'dive-1');

    await expectLater(
      repository.linkPlanToDive('plan-1', 'no-such-dive'),
      throwsArgumentError,
    );

    expect((await repository.getPlan('plan-1'))!.linkedDiveId, 'dive-1');
  });

  test('linking a missing plan throws', () async {
    await seedDive('dive-1');

    await expectLater(
      repository.linkPlanToDive('no-such-plan', 'dive-1'),
      throwsArgumentError,
    );
  });

  test('unlinking a plan that is gone marks nothing pending', () async {
    await repository.unlinkPlan('no-such-plan');

    expect(await isPending('no-such-plan'), isFalse);
  });

  test(
    'summaries carry the linked dive\'s number, planned flag and date',
    () async {
      await seedDive('dive-1', number: 142);
      await seedDive('dive-2', isPlanned: true);
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
      await seedPlan('plan-2', linkedDiveId: 'dive-2');
      await seedPlan('plan-3');

      final summaries = {
        for (final s in await repository.getAllPlanSummaries()) s.id: s,
      };

      expect(summaries['plan-1']!.linkedDiveId, 'dive-1');
      expect(summaries['plan-1']!.linkedDiveNumber, 142);
      expect(summaries['plan-1']!.linkedDiveIsPlanned, isFalse);
      expect(
        summaries['plan-1']!.linkedDiveDate,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
      expect(summaries['plan-2']!.linkedDiveIsPlanned, isTrue);
      expect(summaries['plan-3']!.linkedDiveId, isNull);
      expect(summaries['plan-3']!.linkedDiveNumber, isNull);
      expect(summaries['plan-3']!.linkedDiveDate, isNull);
    },
  );
}
