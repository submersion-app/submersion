import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';

import '../../../../helpers/test_database.dart';

/// The planner keeps the plan's source and linked dive ids in memory and the
/// provider is not auto-disposed, so they outlive the dive whenever one is
/// deleted while the plan is still being edited (issue #2006).
///
/// [DivePlanRepository.savePlan] drops an id that no longer names a row, so
/// the save succeeds. The notifier must then adopt what was actually stored,
/// or its state keeps showing a dive the database no longer holds.
void main() {
  late AppDatabase db;
  late DivePlanRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DivePlanNotifier notifier() =>
      DivePlanNotifier(PlanCalculatorService(), repository: repository);

  Future<void> seedDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(1000),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  Future<void> deleteDive(String id) =>
      (db.delete(db.dives)..where((t) => t.id.equals(id))).go();

  test('save succeeds and clears the source dive when it was deleted '
      'meanwhile', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setFollowedDive(
      diveId: 'dive-1',
      surfaceInterval: const Duration(hours: 2),
    );

    // The dive goes while the plan is still only in the planner's memory.
    await deleteDive('dive-1');

    await planner.save();

    expect(planner.state.sourceDiveId, isNull);
    expect(planner.state.isDirty, isFalse);
    final stored = await repository.getPlan(planner.state.id);
    expect(stored, isNotNull);
    expect(stored!.sourceDiveId, isNull);
  });

  test('save succeeds and clears the linked dive when it was deleted '
      'meanwhile', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setLinkedDive('dive-1');

    await deleteDive('dive-1');

    await planner.save();

    expect(planner.state.linkedDiveId, isNull);
    expect(planner.state.isDirty, isFalse);
    expect((await repository.getPlan(planner.state.id))!.linkedDiveId, isNull);
  });

  test('save keeps dive links that still exist', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setFollowedDive(
      diveId: 'dive-1',
      surfaceInterval: const Duration(hours: 2),
    );
    planner.setLinkedDive('dive-2');

    await planner.save();

    expect(planner.state.sourceDiveId, 'dive-1');
    expect(planner.state.linkedDiveId, 'dive-2');
    final stored = await repository.getPlan(planner.state.id);
    expect(stored!.sourceDiveId, 'dive-1');
    expect(stored.linkedDiveId, 'dive-2');
  });

  test('save does not clear a linked dive the diver picked while it was '
      'saving', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setLinkedDive('dive-1');
    await deleteDive('dive-1');

    // Linking another dive during the save's async gap is the planner's own
    // race: the reconciliation describes the id that was sent, so it must not
    // stomp a newer choice the diver has already made.
    final saving = planner.save();
    planner.setLinkedDive('dive-2');
    await saving;

    expect(planner.state.linkedDiveId, 'dive-2');
  });

  test('save does not clear a source dive the diver picked while it was '
      'saving', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setFollowedDive(
      diveId: 'dive-1',
      surfaceInterval: const Duration(hours: 2),
    );
    await deleteDive('dive-1');

    final saving = planner.save();
    planner.setFollowedDive(
      diveId: 'dive-2',
      surfaceInterval: const Duration(hours: 2),
    );
    await saving;

    expect(planner.state.sourceDiveId, 'dive-2');
  });
}
