import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/services/planned_dives_writer.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';

import '../../../../helpers/test_database.dart';
import '../../series/series_fixtures.dart';

/// The planned-dives writer on its own, with no planner behind it (issue
/// #4203): what an agent writing a saved plan into the log runs.
void main() {
  late DiveRepository dives;
  late DivePlanRepository plans;
  late PlannedDivesWriter writer;
  final nine = DateTime.utc(2026, 10, 27, 9);
  const config = PlanEngineConfig();

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    plans = DivePlanRepository();
    writer = PlannedDivesWriter(
      dives: dives,
      plans: plans,
      siteOf: SiteRepository().getSiteById,
      shares: ItemSharesRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  /// Dives A (named Wreck, at nine) and B, an hour after A surfaces.
  PlanSeries twoDives() => PlanSeries(
    dives: [
      PlanSeriesDive(
        state: seriesDiveState(id: 'a').copyWith(startDateTime: nine),
        name: 'Wreck',
        fixedStart: true,
      ),
      PlanSeriesDive(
        state: seriesDiveState(
          id: 'b',
          depth: 18,
          surfaceInterval: const Duration(hours: 1),
        ),
      ),
    ],
  );

  List<SeriesDiveResult> resultsOf(PlanSeries series) =>
      computeSeries(series.dives, config: config);

  /// Saves each dive's plan row, as the planner does before linking.
  Future<void> saveRows(PlanSeries series) async {
    for (final dive in series.dives) {
      await plans.savePlan(divePlanFromState(dive.state));
    }
  }

  Future<PlannedDivesWritten> writeAll(
    PlannedDivesPlan plan, {
    Future<Dive> Function(Dive dive)? addDive,
  }) => writer.write(
    plan,
    config: config,
    addDive: addDive ?? dives.createDive,
    updateDive: dives.updateDive,
  );

  /// [series] with each dive's link taken from its plan row.
  Future<PlanSeries> relinked(PlanSeries series) async => series.copyWith(
    dives: [
      for (final dive in series.dives)
        dive.copyWith(
          state: dive.state.copyWith(
            linkedDiveId: (await plans.getPlan(dive.state.id))?.linkedDiveId,
          ),
        ),
    ],
  );

  test(
    'a series with no entries creates one per dive, then links them',
    () async {
      final series = twoDives();
      await saveRows(series);
      final lookups = await writer.lookUp(series, diverId: null);
      final plan = writer.decide(series, resultsOf(series), lookups);

      expect(plan.writable, isTrue);
      expect(plan.steps.map((s) => s.action), [
        PlannedDiveAction.create,
        PlannedDiveAction.create,
      ]);
      expect(plan.steps.map((s) => s.name), ['Wreck', null]);

      final written = await writeAll(plan);
      expect(written.created, 2);
      expect(written.failure, isNull);
      final linked = await writer.link(written);
      expect(linked.keys, ['a', 'b']);

      final a = await dives.getDiveById(linked['a']!);
      expect(a?.isPlanned, isTrue);
      expect(a?.name, 'Wreck');
      expect(a?.dateTime, nine);
      expect(a?.profile, isNotEmpty);
      expect((await plans.getPlan('b'))?.linkedDiveId, linked['b']);
    },
  );

  test('running it again rewrites the same entries in place', () async {
    final series = twoDives();
    await saveRows(series);
    final first = await writeAll(
      writer.decide(
        series,
        resultsOf(series),
        await writer.lookUp(series, diverId: null),
      ),
    );
    final linked = await writer.link(first);

    final again = await relinked(series);
    final plan = writer.decide(
      again,
      resultsOf(again),
      await writer.lookUp(again, diverId: null),
    );
    expect(plan.steps.map((s) => s.action), [
      PlannedDiveAction.update,
      PlannedDiveAction.update,
    ]);
    expect(plan.steps.map((s) => s.entry?.id), [linked['a'], linked['b']]);

    final written = await writeAll(plan);
    expect(written.updated, 2);
    expect(written.newEntries, isEmpty);
    expect(await writer.link(written), isEmpty);
  });

  test('a dived dive of a series is left alone', () async {
    final dived = await dives.createDive(loggedDive('dived', nine));
    final series = twoDives();
    final withDived = series.copyWith(
      dives: [
        series.dives[0].copyWith(
          state: series.dives[0].state.copyWith(linkedDiveId: dived.id),
        ),
        series.dives[1],
      ],
    );
    final plan = writer.decide(
      withDived,
      resultsOf(withDived),
      await writer.lookUp(withDived, diverId: null),
    );
    expect(plan.steps.map((s) => s.action), [
      PlannedDiveAction.skipDived,
      PlannedDiveAction.create,
    ]);
    expect(plan.steps.first.entry?.id, dived.id);

    final written = await writeAll(plan);
    expect(written.skipped, 1);
    expect(written.created, 1);
    expect(written.newEntries.keys, ['b']);
  });

  test(
    'a single plan linked to a dived dive waits for the link to move',
    () async {
      final dived = await dives.createDive(loggedDive('dived', nine));
      final single = PlanSeries.single(
        seriesDiveState(id: 'a').copyWith(linkedDiveId: dived.id),
      );
      final results = resultsOf(single);
      final lookups = await writer.lookUp(single, diverId: null);

      final asked = writer.decide(single, results, lookups);
      expect(asked.needsLinkMove, isTrue);
      expect(asked.writable, isFalse);
      expect(asked.steps, isEmpty);

      final moved = writer.decide(
        single,
        results,
        lookups,
        moveDivedLink: true,
      );
      expect(moved.steps.single.action, PlannedDiveAction.create);
      expect(moved.steps.single.entry, isNull);
      expect(moved.steps.single.name, 'Reef day');
    },
  );

  test('a dive with no segments blocks the whole plan', () async {
    final series = twoDives();
    final empty = series.copyWith(
      dives: [
        series.dives[0],
        series.dives[1].copyWith(
          state: series.dives[1].state.copyWith(segments: const []),
        ),
      ],
    );
    final plan = writer.decide(
      empty,
      resultsOf(empty),
      await writer.lookUp(empty, diverId: null),
    );
    expect(plan.writable, isFalse);
    expect(plan.blockedIndex, 1);
    expect(plan.blockedEmpty, isTrue);
  });

  test('a site the entry\'s diver cannot see is left off', () async {
    final now = DateTime.now();
    final owner = await DiverRepository().createDiver(
      Diver(id: 'owner', name: 'owner', createdAt: now, updatedAt: now),
    );
    final other = await DiverRepository().createDiver(
      Diver(id: 'other', name: 'other', createdAt: now, updatedAt: now),
    );
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: owner.id),
    );
    final single = PlanSeries.single(
      seriesDiveState(id: 'a').copyWith(siteId: site.id),
    );

    Future<DiveSite?> siteFor(String diverId) async => writer
        .decide(
          single,
          resultsOf(single),
          await writer.lookUp(single, diverId: diverId),
        )
        .steps
        .single
        .site;

    expect((await siteFor(owner.id))?.id, site.id);
    expect(await siteFor(other.id), isNull);
  });

  test('a write that fails part way returns what it wrote', () async {
    final series = twoDives();
    await saveRows(series);
    final plan = writer.decide(
      series,
      resultsOf(series),
      await writer.lookUp(series, diverId: null),
    );
    var calls = 0;
    final written = await writeAll(
      plan,
      addDive: (dive) {
        if (++calls == 2) throw StateError('disk full');
        return dives.createDive(dive);
      },
    );

    expect(written.failure, isA<StateError>());
    expect(written.failureStack, isNotNull);
    expect(written.created, 1);
    expect(written.newEntries.keys, ['a']);
    expect((await writer.link(written)).keys, ['a']);
  });

  test('orphans are the planned entries no plan links any more', () async {
    final planned = await dives.createDive(
      loggedDive('planned', nine, isPlanned: true),
    );
    final linked = await dives.createDive(
      loggedDive('linked', nine, isPlanned: true),
    );
    final dived = await dives.createDive(loggedDive('dived', nine));
    final row = await plans.savePlan(
      divePlanFromState(seriesDiveState(id: 'a')),
    );
    await plans.linkPlanToDive(row.id, linked.id);

    final orphans = await writer.orphans({planned.id, linked.id, dived.id});
    expect(orphans.map((d) => d.id), [planned.id]);
  });
}
