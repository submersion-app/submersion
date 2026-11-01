import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';

import '../../../../helpers/test_database.dart';

/// The planner holds a plan in memory and `divePlanNotifierProvider` is not
/// auto-disposed, so a link written from the dive side would be lost when the
/// plan is saved later: `savePlan` writes the whole row (issue #4003). The
/// link actions tell the notifier, which adopts the link without treating it
/// as an edit of its own.
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

  test('adoptLink updates the open plan without dirtying it', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    await planner.save();
    expect(planner.state.isDirty, isFalse);

    planner.adoptLink(planner.state.id, 'dive-1');

    expect(planner.state.linkedDiveId, 'dive-1');
    expect(planner.state.isDirty, isFalse);
  });

  test('a save after adoptLink keeps the new link', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    await planner.save();
    final id = planner.state.id;

    await repository.linkPlanToDive(id, 'dive-1');
    planner.adoptLink(id, 'dive-1');
    planner.updateName('Renamed');
    await planner.save();

    expect((await repository.getPlan(id))!.linkedDiveId, 'dive-1');
  });

  test('a save after adoptLink keeps a cleared link cleared', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setLinkedDive('dive-1');
    await planner.save();
    final id = planner.state.id;

    await repository.unlinkPlan(id);
    planner.adoptLink(id, null);
    planner.updateName('Renamed');
    await planner.save();

    expect((await repository.getPlan(id))!.linkedDiveId, isNull);
  });

  test('adoptLink for another plan changes nothing', () async {
    final planner = notifier();
    addTearDown(planner.dispose);
    await planner.save();
    final before = planner.state;

    planner.adoptLink('another-plan', 'dive-1');

    expect(identical(planner.state, before), isTrue);
  });
}
