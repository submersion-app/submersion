import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';

import '../../../../helpers/test_database.dart';

/// The planner keeps the plan's site id in memory and the provider is not
/// auto-disposed, so the id outlives the site whenever one is deleted while
/// the plan is still being edited (issue #1985).
///
/// [DivePlanRepository.savePlan] drops an id that no longer names a row, so
/// the save succeeds. The notifier must then adopt what was actually stored,
/// or its state keeps showing a site the database no longer holds.
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

  Future<void> seedSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  test(
    'save succeeds and clears the site when it was deleted meanwhile',
    () async {
      await seedSite('site-1');
      final planner = notifier();
      addTearDown(planner.dispose);
      planner.updateSite('site-1');

      // The site goes while the plan is still only in the planner's memory.
      await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();

      await planner.save();

      expect(planner.state.siteId, isNull);
      expect(planner.state.isDirty, isFalse);
      final stored = await repository.getPlan(planner.state.id);
      expect(stored, isNotNull);
      expect(stored!.siteId, isNull);
    },
  );

  test('save keeps the site when it still exists', () async {
    await seedSite('site-1');
    final planner = notifier();
    addTearDown(planner.dispose);
    planner.updateSite('site-1');

    await planner.save();

    expect(planner.state.siteId, 'site-1');
    expect((await repository.getPlan(planner.state.id))!.siteId, 'site-1');
  });

  test(
    'save does not clear a site the diver picked while it was saving',
    () async {
      await seedSite('site-1');
      await seedSite('site-2');
      final planner = notifier();
      addTearDown(planner.dispose);
      planner.updateSite('site-1');
      await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();

      // Switching sites during the save's async gap is the planner's own race:
      // the reconciliation describes the id that was sent, so it must not stomp
      // a newer choice the diver has already made.
      final saving = planner.save();
      planner.updateSite('site-2');
      await saving;

      expect(planner.state.siteId, 'site-2');
    },
  );

  test(
    'save leaves the plan dirty when the diver edited during the save',
    () async {
      await seedSite('site-1');
      await seedSite('site-2');
      final planner = notifier();
      addTearDown(planner.dispose);
      planner.updateSite('site-1');

      final saving = planner.save();
      planner.updateSite('site-2');
      await saving;

      // The write described the plan as it was submitted, so an edit made
      // during the async gap is still unsaved and the plan is still dirty.
      // Clearing the flag unconditionally disables Save and strands the edit.
      expect(planner.state.isDirty, isTrue);

      await planner.save();
      expect((await repository.getPlan(planner.state.id))!.siteId, 'site-2');
    },
  );
}
