import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Every agent write to a repetitive series can be reverted, leaving the
/// plan tables as they were before it (#4203).
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  const planTables = [
    'dive_plan_series',
    'dive_plans',
    'dive_plan_tanks',
    'dive_plan_segments',
  ];

  /// Columns a write stamps afresh, a revert included.
  const stamps = {'updated_at', 'hlc'};

  /// Every row of the plan tables, keyed by table, in a stable order, less
  /// the [stamps].
  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final table in planTables)
      table: [
        for (final row
            in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          {
            for (final e in row.data.entries)
              if (!stamps.contains(e.key)) e.key: e.value,
          },
      ],
  };

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<StoredSeries> threeDives() => DivePlanSeriesRepository().saveSeries(
    StoredSeries(
      id: 's1',
      name: 'Reef day',
      diverId: kDiverA,
      dives: [
        StoredSeriesDive(plan: divePlanFromState(seriesDiveState(id: 'a'))),
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
          ),
          sourceTankIds: const {'b-back': 'a-back'},
        ),
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: 'c', surfaceInterval: const Duration(hours: 3)),
          ),
          sourceTankIds: const {'c-back': 'b-back'},
        ),
      ],
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await threeDives();
  });
  tearDown(() => tearDownTestDatabase());

  test('reverting a copy removes the copy and leaves the original', () async {
    final before = await snapshot();
    final result = await h.run([
      createOp('dive_plan_series', {'duplicate_of': 's1', 'name': 'Copy'}),
    ]);
    expect(await count('dive_plan_series'), 2);
    expect(await count('dive_plans'), 6);

    await h.revert(result);

    expect(await snapshot(), before);
  });

  test('reverting a rename puts the old name back', () async {
    final before = await snapshot();
    final result = await h.run([
      updateOp('dive_plan_series', 's1', {'name': 'Wall day'}),
    ]);

    await h.revert(result);

    expect(await snapshot(), before);
  });

  test('reverting a reorder puts the dives back in order', () async {
    final before = await snapshot();
    final result = await h.run([
      updateOp('dive_plan_series', 's1', {
        'plan_ids': ['c', 'a', 'b'],
      }),
    ]);

    await h.revert(result);

    expect(await snapshot(), before);
  });

  test('reverting a drop brings the dropped dive back whole', () async {
    final before = await snapshot();
    final result = await h.run([
      updateOp('dive_plan_series', 's1', {
        'plan_ids': ['a', 'c'],
      }),
    ]);
    expect(await h.one('dive_plans', 'b'), isNull);

    await h.revert(result);

    expect(await snapshot(), before);
  });

  test('reverting a dissolve brings the series and its dives back', () async {
    final before = await snapshot();
    final result = await h.run([
      updateOp('dive_plan_series', 's1', {'dissolve_keeping_plan_id': 'a'}),
    ]);
    expect(await count('dive_plan_series'), 0);

    await h.revert(result);

    expect(await snapshot(), before);
  });

  test('reverting a delete brings the series and its dives back', () async {
    final before = await snapshot();
    final result = await h.run([deleteOp('dive_plan_series', 's1')]);
    expect(await count('dive_plans'), 0);

    await h.revert(result);

    expect(await snapshot(), before);
  });
}
