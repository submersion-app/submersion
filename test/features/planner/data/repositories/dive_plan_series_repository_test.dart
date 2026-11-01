import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../../../helpers/test_database.dart';
import '../../series/series_fixtures.dart';

void main() {
  late DivePlanSeriesRepository repo;
  late DivePlanRepository plans;

  setUp(() async {
    await setUpTestDatabase();
    plans = DivePlanRepository();
    repo = DivePlanSeriesRepository(plans: plans);
  });

  tearDown(tearDownTestDatabase);

  StoredSeries twoDives() {
    final a = divePlanFromState(seriesDiveState(id: 'a'));
    final b = divePlanFromState(
      seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
    );
    return StoredSeries(
      id: 's1',
      name: 'Reef day',
      dives: [
        StoredSeriesDive(
          plan: a,
          name: 'Wreck',
          summaryMaxDepth: 30,
          summaryRuntimeSeconds: 2400,
        ),
        StoredSeriesDive(
          plan: b,
          fixedStart: true,
          settingOverrides: const {
            PlanSettingGroup.deco,
            PlanSettingGroup.tanks,
          },
          sourceTankIds: const {'b-back': 'a-back', 'b-stage': 'a-stage'},
          pinnedTankIds: const {'b-stage'},
        ),
      ],
    );
  }

  test('a series comes back as it was saved', () async {
    await repo.saveSeries(twoDives());

    final loaded = (await repo.getSeries('s1'))!;

    expect(loaded.name, 'Reef day');
    expect(loaded.dives.map((d) => d.plan.id), ['a', 'b']);
    expect(loaded.dives[0].name, 'Wreck');
    expect(loaded.dives[0].summaryMaxDepth, 30);
    final b = loaded.dives[1];
    expect(b.name, isNull);
    expect(b.fixedStart, isTrue);
    expect(b.settingOverrides, {PlanSettingGroup.deco, PlanSettingGroup.tanks});
    expect(b.sourceTankIds, {'b-back': 'a-back', 'b-stage': 'a-stage'});
    expect(b.pinnedTankIds, {'b-stage'});
    expect(b.plan.surfaceInterval, const Duration(hours: 2));
  });

  test('a plan knows its series; one saved alone has none', () async {
    await repo.saveSeries(twoDives());
    await plans.savePlan(divePlanFromState(seriesDiveState(id: 'alone')));

    expect(await repo.seriesIdForPlan('b'), 's1');
    expect(await repo.seriesIdForPlan('alone'), isNull);
    expect(await repo.getSeries('missing'), isNull);
  });

  test('a dive no longer in the series is deleted', () async {
    final series = await repo.saveSeries(twoDives());
    await repo.saveSeries(series.copyWith(dives: [series.dives.first]));

    expect((await repo.getSeries('s1'))!.dives, hasLength(1));
    expect(await plans.getPlan('b'), isNull);
  });

  test('saving again keeps the dives and their order', () async {
    final series = await repo.saveSeries(twoDives());
    await repo.saveSeries(series.copyWith(name: 'Renamed'));

    final loaded = (await repo.getSeries('s1'))!;
    expect(loaded.name, 'Renamed');
    expect(loaded.dives.map((d) => d.plan.id), ['a', 'b']);
  });

  test('deleting a series deletes its dives', () async {
    await repo.saveSeries(twoDives());
    await repo.deleteSeries('s1');

    expect(await repo.getSeries('s1'), isNull);
    expect(await plans.getPlan('a'), isNull);
    expect(await plans.getPlan('b'), isNull);
  });

  test('a duplicate has new ids, with its links moved to them', () async {
    await repo.saveSeries(twoDives());

    final copy = (await repo.duplicateSeries('s1'))!;

    expect(copy.id, isNot('s1'));
    expect(copy.name, 'Reef day (copy)');
    expect(copy.dives, hasLength(2));
    final a = copy.dives[0].plan;
    final b = copy.dives[1];
    expect(a.id, isNot('a'));
    expect(a.name, 'Reef day (copy)');
    expect(b.sourceTankIds, {
      b.plan.tanks[0].id: a.tanks[0].id,
      b.plan.tanks[1].id: a.tanks[1].id,
    });
    expect(b.pinnedTankIds, {b.plan.tanks[1].id});
    // The original is untouched, and the copy reads back the same.
    expect((await repo.getSeries('s1'))!.dives.first.plan.id, 'a');
    expect((await repo.getSeries(copy.id))!.dives, hasLength(2));
  });

  test('duplicating a series that is gone gives nothing', () async {
    expect(await repo.duplicateSeries('missing'), isNull);
  });

  test('a followed dive that is gone is dropped, not a failed save', () async {
    final stored = await repo.saveSeries(
      twoDives().copyWith(followedDiveId: 'gone'),
    );

    expect(stored.followedDiveId, isNull);
  });

  test('a tank id another plan holds moves the links with it', () async {
    await plans.savePlan(divePlanFromState(seriesDiveState(id: 'a')));
    final taken = twoDives();
    final clash = taken.copyWith(
      dives: [
        taken.dives[0].copyWith(
          plan: taken.dives[0].plan.copyWith(id: 'other'),
        ),
        taken.dives[1],
      ],
    );

    final stored = await repo.saveSeries(clash);

    final firstTanks = stored.dives[0].plan.tanks.map((t) => t.id).toSet();
    expect(firstTanks, isNot(contains('a-back')));
    expect(stored.dives[1].sourceTankIds.values.toSet(), firstTanks);
  });

  group('the series\' diver', () {
    Future<void> addDiver(String id) async {
      final database = DatabaseService.instance.database;
      await database
          .into(database.divers)
          .insert(
            db.DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }

    test('is whoever saved it first, through later saves by others', () async {
      await addDiver('first');
      await addDiver('second');

      final stored = await repo.saveSeries(
        twoDives().copyWith(diverId: 'first'),
      );
      expect(stored.diverId, 'first');
      final again = await repo.saveSeries(stored.copyWith(diverId: 'second'));
      expect(again.diverId, 'first');

      final database = DatabaseService.instance.database;
      final rows = await (database.select(
        database.divePlans,
      )..where((p) => p.seriesId.equals('s1'))).get();
      expect(rows.map((r) => r.diverId), everyElement('first'));
      expect((await repo.getSeries('s1'))!.diverId, 'first');
    });

    test('is set by a later save when the first had none', () async {
      await addDiver('second');
      final stored = await repo.saveSeries(twoDives());

      final again = await repo.saveSeries(stored.copyWith(diverId: 'second'));

      expect(again.diverId, 'second');
    });
  });

  test('a setting group this build does not know is left out', () async {
    await repo.saveSeries(twoDives());
    final database = DatabaseService.instance.database;
    await (database.update(
      database.divePlans,
    )..where((p) => p.id.equals('b'))).write(
      const db.DivePlansCompanion(
        settingOverrides: Value('deco,fromTheFuture'),
      ),
    );

    final loaded = (await repo.getSeries('s1'))!;

    expect(loaded.dives[1].settingOverrides, {PlanSettingGroup.deco});
  });
}
