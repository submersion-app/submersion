import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// The Compare card's plan link, held in a sitting (issue #4527, plan 6).
void main() {
  late AppDatabase db;
  late DivePlanRepository repository;
  late ProviderContainer container;
  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DivePlanRepository();
    container = ProviderContainer();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(1000),
            createdAt: Value(1000),
            updatedAt: Value(1000),
          ),
        );
    for (final (id, linked) in [('plan-old', 'dive-1'), ('plan-new', null)]) {
      await repository.savePlan(
        domain.DivePlan(
          id: id,
          name: 'Plan $id',
          gfLow: 30,
          gfHigh: 70,
          linkedDiveId: linked,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
    }
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<EditSession<Dive>> started() async {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    loadDivePlanLink(session, container.read);
    await session.settled();
    return session;
  }

  Future<String?> linkedTo(String planId) async =>
      (await repository.getPlan(planId))?.linkedDiveId;

  test('loads the stored link', () async {
    final session = await started();
    expect(sittingPlanLink(session), (planId: 'plan-old'));
  });

  test('a read that fails is told, and reading again recovers', () async {
    var fail = true;
    final flaky = ProviderContainer(
      overrides: [
        divePlanRepositoryProvider.overrideWithValue(
          _Flaky(() => fail, repository),
        ),
      ],
    );
    addTearDown(flaky.dispose);
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    loadDivePlanLink(session, flaky.read);
    await session.settled();
    expect(sittingPlanLink(session), isNull);
    expect(planLinkLoadFailed(session), isTrue);

    fail = false;
    await reloadDivePlanLink(session);
    expect(planLinkLoadFailed(session), isFalse);
    expect(sittingPlanLink(session), (planId: 'plan-old'));
  });

  test('a plan linked in the sitting is written at Save; Cancel leaves the '
      'old link', () async {
    final session = await started();
    setPlanLink(session, 'plan-new');
    expect(session.changedCardIds, {'diveLab'});
    expect(await linkedTo('plan-new'), isNull);

    await session.runHeldWrites();
    expect(await linkedTo('plan-new'), 'dive-1');
    expect(await linkedTo('plan-old'), isNull);

    final other = await started();
    setPlanLink(other, 'plan-old');
    other.dispose();
    expect(await linkedTo('plan-old'), isNull);
  });

  test(
    'unlinked in the sitting: unlinked at Save; linked back: no change',
    () async {
      final session = await started();
      setPlanLink(session, null);
      expect(session.isDirty, isTrue);
      setPlanLink(session, 'plan-old');
      expect(session.isDirty, isFalse);

      setPlanLink(session, null);
      await session.runHeldWrites();
      expect(await linkedTo('plan-old'), isNull);
    },
  );

  // Code review (#4527): unlinking clears every plan on the plan's dive as
  // it is now, so one sync moved elsewhere must be left alone.
  test('a plan sync moved to another dive before Save stays linked there '
      'when the sitting unlinked it', () async {
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-2'),
            diveDateTime: Value(2000),
            createdAt: Value(2000),
            updatedAt: Value(2000),
          ),
        );
    final session = await started();
    setPlanLink(session, null);
    await db.customStatement(
      "UPDATE dive_plans SET linked_dive_id = 'dive-2' WHERE id = ?",
      ['plan-old'],
    );

    await session.runHeldWrites();
    expect(await linkedTo('plan-old'), 'dive-2');
  });
}

class _Flaky extends DivePlanRepository {
  _Flaky(this.failing, this.real);

  final bool Function() failing;
  final DivePlanRepository real;

  @override
  Future<domain.DivePlan?> getPlanByLinkedDiveId(String diveId) async {
    if (failing()) throw StateError('database locked');
    return real.getPlanByLinkedDiveId(diveId);
  }
}
