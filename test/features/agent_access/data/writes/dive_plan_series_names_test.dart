import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/planned_dives_effect.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// The names of a series' dives, which an agent reads as `dives[].name`,
/// written on a create and on an update (#4626).
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  final followed = <String, SeriesFollow>{};
  Future<SeriesFollow?> followOf(String id) async => followed[id];

  const reef = {
    'tanks': [
      {'volume_l': 12, 'start_pressure_bar': 200, 'o2_fraction': 0.32},
    ],
    'bottom': {'depth_m': 24, 'time_s': 2400},
  };
  const wall = {
    'surface_interval_s': 5400,
    'bottom': {'depth_m': 18, 'time_s': 2700},
  };

  Future<StoredSeries> stored(String id) async =>
      (await DivePlanSeriesRepository().getSeries(id))!;

  List<String?> namesOf(StoredSeries series) => [
    for (final d in series.dives) d.name,
  ];

  /// Dives a and b, a at nine, b named "Wall".
  Future<StoredSeries> saveSeries() => DivePlanSeriesRepository().saveSeries(
    StoredSeries(
      id: 's1',
      name: 'Reef day',
      diverId: kDiverA,
      dives: [
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(
              id: 'a',
            ).copyWith(startDateTime: DateTime.utc(2026, 10, 27, 9)),
          ),
        ),
        StoredSeriesDive(
          name: 'Wall',
          plan: divePlanFromState(
            seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
          ),
        ),
      ],
    ),
  );

  Map<String, Object?> rename(
    Map<String, Object?> names, [
    Map<String, Object?> more = const {},
  ]) => updateOp('dive_plan_series', 's1', {'dive_names': names, ...more});

  Future<PlanBlock?> blockOf(Map<String, Object?> op) async =>
      (await h.preview([op])).items.single.block;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    followed.clear();
    h = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(repositories, followOf: followOf),
    );
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  group('a new series', () {
    Map<String, Object?> create(List<Object?> dives) =>
        createOp('dive_plan_series', {'name': 'Reef day', 'dives': dives});

    test('takes each dive\'s name, trimmed, a blank as none', () async {
      final id = (await h.run([
        create([
          {...reef, 'name': ' Wreck '},
          {...wall, 'name': '  '},
          {...wall, 'name': 'Reef'},
        ]),
      ])).created.single.id;

      expect(namesOf(await stored(id)), ['Wreck', null, 'Reef']);
      expect(
        [
          for (final d
              in (await h.one('dive_plan_series', id))!['dives']! as List)
            (d as Map)['name'],
        ],
        ['Wreck', null, 'Reef'],
      );
    });

    test('without names, shows its dives by their letters', () async {
      final id = (await h.run([
        create([reef, wall]),
      ])).created.single.id;
      expect(namesOf(await stored(id)), [null, null]);
    });

    test('refuses a name that is not text', () async {
      final block = await blockOf(
        create([
          reef,
          {...wall, 'name': 7},
        ]),
      );
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('dives[1].name'));
    });

    test('refuses a name longer than the planner holds', () async {
      final block = await blockOf(
        create([
          {...reef, 'name': 'x' * (StoredSeriesDive.maxNameLength + 1)},
          wall,
        ]),
      );
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('dives[0].name'));
    });
  });

  group('a saved series', () {
    test('names a dive and clears another\'s name', () async {
      await saveSeries();
      final preview = await h.preview([
        rename({'a': ' Wreck ', 'b': null}),
      ]);
      expect(preview.items.single.block, isNull);
      await h.apply(preview);

      final series = await stored('s1');
      expect(namesOf(series), ['Wreck', null]);
      expect(series.name, 'Reef day');
    });

    test('keeps the names of the dives it leaves out', () async {
      await saveSeries();
      await h.run([
        rename({'a': 'Wreck'}),
      ]);
      expect(namesOf(await stored('s1')), ['Wreck', 'Wall']);
    });

    test('names its dives in the order plan_ids gives them', () async {
      await saveSeries();
      await h.run([
        rename(
          {'a': 'Wreck'},
          {
            'plan_ids': ['b', 'a'],
          },
        ),
      ]);
      final series = await stored('s1');
      expect([for (final d in series.dives) d.plan.id], ['b', 'a']);
      expect(namesOf(series), ['Wall', 'Wreck']);
    });

    test('names its planned entries in the same change', () async {
      await saveSeries();
      await h.run([
        rename({'a': 'Wreck'}, {PlannedDivesEffect.field: const {}}),
      ]);
      final link = (await DivePlanRepository().getPlan('a'))!.linkedDiveId;
      final entry = (await DiveRepository().getDiveById(link!))!;
      expect(entry.name, 'Wreck');
    });

    group('refuses', () {
      test('a dive the series does not hold', () async {
        await saveSeries();
        final block = await blockOf(rename({'zz': 'Wreck'}));
        expect(block!.reason, BlockReason.invalidValue);
        expect(block.detail, contains('zz'));
      });

      test('a dive plan_ids drops in the same change', () async {
        await saveSeries();
        final block = await blockOf(
          rename(
            {'b': 'Wreck'},
            {
              'plan_ids': ['a'],
            },
          ),
        );
        expect(block!.reason, BlockReason.invalidValue);
        expect(block.detail, contains('b'));
      });

      test('a name that is not text, or too long', () async {
        await saveSeries();
        for (final name in [7, 'x' * (StoredSeriesDive.maxNameLength + 1)]) {
          final block = await blockOf(rename({'a': name}));
          expect(block!.reason, BlockReason.invalidValue, reason: '$name');
        }
      });

      test('a list in place of an object', () async {
        await saveSeries();
        final block = await blockOf(
          updateOp('dive_plan_series', 's1', {
            'dive_names': ['Wreck'],
          }),
        );
        expect(block!.reason, BlockReason.invalidValue);
      });

      test('a rename in the same change as a dissolve', () async {
        await saveSeries();
        final block = await blockOf(
          rename({'a': 'Wreck'}, {'dissolve_keeping_plan_id': 'a'}),
        );
        expect(block!.reason, BlockReason.notPermitted);
      });

      test('renaming a dive that has been dived', () async {
        await saveSeries();
        await h.run([
          updateOp('dive_plans', 'b', {'linked_dive_id': 'd1'}),
        ]);
        final block = await blockOf(rename({'b': 'Wreck'}));
        expect(block!.reason, BlockReason.notPermitted);
        expect(block.detail, contains('b'));
        // Its name as it stands is no change, so is not refused.
        expect(await blockOf(rename({'b': 'Wall', 'a': 'Wreck'})), isNull);
      });
    });

    test('reverted, puts the names back', () async {
      await saveSeries();
      final result = await h.run([
        rename({'a': 'Wreck', 'b': null}),
      ]);
      await h.revert(result);
      expect(namesOf(await stored('s1')), [null, 'Wall']);
    });
  });
}
