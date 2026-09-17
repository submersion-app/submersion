import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
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
/// or its state keeps showing a dive the database no longer holds. A dropped
/// source dive takes its seeded tissues and surface interval with it, as
/// unfollowing the dive does: the tissues are never persisted, so keeping them
/// would seed deco from a dive the plan no longer follows until the next
/// reload silently changed the schedule.
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

  const tissues = [
    TissueCompartment(
      compartmentNumber: 1,
      halfTimeN2: 5.0,
      halfTimeHe: 1.88,
      mValueAN2: 1.1696,
      mValueBN2: 0.5578,
      mValueAHe: 1.6189,
      mValueBHe: 0.4770,
      currentPN2: 1.2,
    ),
  ];

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

  test('save drops the seeded tissues and surface interval with a deleted '
      'source dive', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setFollowedDive(
      diveId: 'dive-1',
      compartments: tissues,
      surfaceInterval: const Duration(hours: 2),
    );
    await deleteDive('dive-1');

    await planner.save();

    // Left in place, the tissues would keep seeding deco for a plan that no
    // longer follows a dive, and vanish on reload since they are not stored.
    expect(planner.state.initialTissueState, isNull);
    expect(planner.state.surfaceInterval, isNull);
    expect(planner.state.isDirty, isFalse);
    expect(
      (await repository.getPlan(planner.state.id))!.surfaceInterval,
      isNull,
    );
  });

  test(
    'save keeps the followed dive context when only the linked dive went',
    () async {
      await seedDive('dive-1');
      await seedDive('dive-2');
      final planner = notifier();
      addTearDown(planner.dispose);
      planner.setFollowedDive(
        diveId: 'dive-1',
        compartments: tissues,
        surfaceInterval: const Duration(hours: 2),
      );
      planner.setLinkedDive('dive-2');
      await deleteDive('dive-2');

      await planner.save();

      expect(planner.state.sourceDiveId, 'dive-1');
      expect(planner.state.initialTissueState, tissues);
      expect(planner.state.surfaceInterval, const Duration(hours: 2));
    },
  );

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
      compartments: tissues,
      surfaceInterval: const Duration(hours: 3),
    );
    await saving;

    // The newly followed dive brings its own context, which must survive too.
    expect(planner.state.sourceDiveId, 'dive-2');
    expect(planner.state.initialTissueState, tissues);
    expect(planner.state.surfaceInterval, const Duration(hours: 3));
  });

  test('save does not clear a surface interval the diver set while it was '
      'saving', () async {
    await seedDive('dive-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.setFollowedDive(
      diveId: 'dive-1',
      compartments: tissues,
      surfaceInterval: const Duration(hours: 2),
    );
    await deleteDive('dive-1');

    final saving = planner.save();
    planner.setSurfaceInterval(const Duration(hours: 4));
    await saving;

    // The dead dive and its unstored tissues still go, but an interval typed
    // during the gap is a newer choice than the one that was sent, and it
    // stays dirty so the next save stores it.
    expect(planner.state.sourceDiveId, isNull);
    expect(planner.state.initialTissueState, isNull);
    expect(planner.state.surfaceInterval, const Duration(hours: 4));
    expect(planner.state.isDirty, isTrue);
  });
}
