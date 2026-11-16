import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/planned_dives_effect.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A saved plan or series written into the log as planned dives by an
/// agent (#4203): previewed per dive, applied through the planner's own
/// writer, and reverted with the rest of the set.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  final followed = <String, SeriesFollow>{};
  // Each read of a dived dive, once per time the saved plan is computed.
  var follows = 0;
  Future<SeriesFollow?> followOf(String id) async {
    follows++;
    return followed[id];
  }

  final nine = DateTime.utc(2026, 10, 27, 9);

  /// Dives A, at nine, and B, two hours after A surfaces, for [diverId].
  Future<StoredSeries> saveSeries({
    DateTime? start,
    double depthB = 30,
    String? diverId = kDiverA,
  }) => DivePlanSeriesRepository().saveSeries(
    StoredSeries(
      id: 's1',
      name: 'Reef day',
      diverId: diverId,
      dives: [
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: 'a').copyWith(startDateTime: start),
          ),
        ),
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(
              id: 'b',
              depth: depthB,
              surfaceInterval: const Duration(hours: 2),
            ),
          ),
        ),
      ],
    ),
  );

  Map<String, Object?> writeSeries([
    Map<String, Object?> options = const {},
    Map<String, Object?> more = const {},
  ]) => updateOp('dive_plan_series', 's1', {
    PlannedDivesEffect.field: options,
    ...more,
  });

  Future<String?> linkOf(String planId) async =>
      (await DivePlanRepository().getPlan(planId))?.linkedDiveId;

  Future<Dive?> diveOf(String? id) async =>
      id == null ? null : DiveRepository().getDiveById(id);

  List<Map<String, Object?>> entriesOf(PlanItem item) => [
    for (final e
        in item.fields[PlannedDivesEffect.entriesKey]!.newValue! as List)
      (e as Map).cast<String, Object?>(),
  ];

  Future<void> markDived(String diveId) => db.customStatement(
    'UPDATE dives SET is_planned = 0 WHERE id = ?',
    [diveId],
  );

  /// The active diver, which a test can switch between preview and apply.
  var active = kDiverA;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    followed.clear();
    active = kDiverA;
    h = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(repositories, followOf: followOf),
      activeDiverId: () async => active,
    );
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  group('a saved series', () {
    test('gets a planned entry for each dive, linked to its plan', () async {
      await saveSeries(start: nine);

      final preview = await h.preview([writeSeries()]);
      final item = preview.items.single;
      expect(item.block, isNull);
      expect(item.alsoCreates, {'dives': 2});
      expect(entriesOf(item).map((e) => e['action']), ['create', 'create']);
      await h.apply(preview);

      for (final planId in ['a', 'b']) {
        final dive = await diveOf(await linkOf(planId));
        expect(dive, isNotNull, reason: planId);
        expect(dive!.isPlanned, isTrue);
        expect(dive.diverId, kDiverA);
      }
      final a = (await diveOf(await linkOf('a')))!;
      final b = (await diveOf(await linkOf('b')))!;
      expect(a.dateTime, nine);
      expect(b.dateTime.isAfter(a.dateTime), isTrue);
    });

    test('run again, rewrites the same entries in place', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      final ids = [await linkOf('a'), await linkOf('b')];

      final preview = await h.preview([writeSeries()]);
      final item = preview.items.single;
      expect(item.alsoCreates, isEmpty);
      expect(item.alsoChanges, {'dives': 2});
      expect(entriesOf(item), [
        {'dive': 'A', 'action': 'update', 'dive_id': ids[0]},
        {'dive': 'B', 'action': 'update', 'dive_id': ids[1]},
      ]);
      await h.apply(preview);

      expect([await linkOf('a'), await linkOf('b')], ids);
      expect(await db.customSelect('SELECT id FROM dives').get(), hasLength(4));
    });

    test('leaves a dived entry alone', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      final dived = (await linkOf('a'))!;
      await markDived(dived);

      final preview = await h.preview([writeSeries()]);
      expect(entriesOf(preview.items.single).first, {
        'dive': 'A',
        'action': 'skip_dived',
        'dive_id': dived,
      });
      expect(preview.items.single.alsoChanges, {'dives': 1});
    });

    test('is computed once per preview, and again at apply', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      await markDived((await linkOf('a'))!);

      follows = 0;
      final preview = await h.preview([writeSeries()]);
      // The refusal check and the side effects share one computation.
      expect(follows, 1);

      follows = 0;
      await h.apply(preview);
      // Never from the preview: the apply checks the plan is current before
      // asking and again inside its transaction, each afresh, then the write
      // computes once more.
      expect(follows, 3);
    });

    test('needs the first dive\'s start', () async {
      await saveSeries();

      final preview = await h.preview([writeSeries()]);

      final block = preview.items.single.block!;
      expect(block.reason, BlockReason.missingField);
      expect(block.detail, contains('start_date_time'));
    });

    test('refuses an option it does not know', () async {
      await saveSeries(start: nine);

      final preview = await h.preview([
        writeSeries({'delete_everything': true}),
      ]);

      expect(preview.items.single.block!.reason, BlockReason.invalidValue);
    });

    test(
      'a dive dropped with delete_removed takes its planned entry',
      () async {
        await saveSeries(start: nine);
        await h.run([writeSeries()]);
        final dropped = (await linkOf('b'))!;

        final preview = await h.preview([
          writeSeries(
            {PlannedDivesEffect.deleteRemoved: true},
            {
              'plan_ids': ['a'],
            },
          ),
        ]);
        final item = preview.items.single;
        expect(item.block, isNull);
        expect(item.reach.parts, containsPair('dive_plans', 1));
        expect(item.reach.parts, containsPair('dives', 1));
        // What goes with the entry, as a delete of the dive lists it.
        expect(item.reach.parts['dive_tanks'], greaterThan(0));
        // The dropped plan's link goes with the plan, not left unlinked.
        expect(item.reach.unlinked, isNot(contains('dive_plans')));
        expect(entriesOf(item).last, {
          'dive': 'removed',
          'action': 'delete_removed',
          'dive_id': dropped,
        });
        await h.apply(preview);

        expect(await diveOf(dropped), isNull);
        expect(await diveOf(await linkOf('a')), isNotNull);
      },
    );

    test('a dive dropped without delete_removed keeps its entry', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      final dropped = (await linkOf('b'))!;

      final preview = await h.preview([
        writeSeries(const {}, {
          'plan_ids': ['a'],
        }),
      ]);
      expect(entriesOf(preview.items.single).last['action'], 'keep_removed');
      await h.apply(preview);

      expect((await diveOf(dropped))!.isPlanned, isTrue);
    });

    test('an entry dived after the preview makes the plan stale', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      final preview = await h.preview([writeSeries()]);

      await markDived((await linkOf('a'))!);

      await expectLater(h.apply(preview), throwsA(anything));
      expect((await diveOf(await linkOf('a')))!.isPlanned, isFalse);
    });

    test(
      'cannot follow an earlier change to its plans in the same set',
      () async {
        await saveSeries(start: nine);

        final preview = await h.preview([
          updateOp('dive_plans', 'a', {'notes': 'Bring a torch'}),
          writeSeries(),
        ]);

        expect(preview.items.last.block!.reason, BlockReason.notPermitted);
      },
    );

    test(
      'cannot follow an earlier change to an entry\'s tank in the same set',
      () async {
        await saveSeries(start: nine);
        await h.run([writeSeries()]);
        final tank = await db
            .customSelect(
              'SELECT id FROM dive_tanks WHERE dive_id = ? ORDER BY id LIMIT 1',
              variables: [Variable.withString((await linkOf('a'))!)],
            )
            .getSingle();

        final preview = await h.preview([
          updateOp('dive_tanks', tank.read<String>('id'), {'name': 'Left'}),
          writeSeries(),
        ]);

        final block = preview.items.last.block!;
        expect(block.reason, BlockReason.notPermitted);
        expect(block.detail, contains('the log'));
      },
    );

    test(
      'cannot follow an earlier link that takes one of its entries',
      () async {
        await saveSeries(start: nine);
        await h.run([writeSeries()]);
        await DivePlanRepository().savePlan(
          divePlanFromState(seriesDiveState(id: 'q')),
        );

        final preview = await h.preview([
          updateOp('dive_plans', 'q', {'linked_dive_id': await linkOf('a')}),
          writeSeries(),
        ]);

        expect(preview.items.first.block, isNull);
        expect(preview.items.last.block!.reason, BlockReason.notPermitted);
      },
    );

    test('refuses a later change to an entry it rewrites', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);

      final preview = await h.preview([
        writeSeries(),
        updateOp('dives', (await linkOf('a'))!, {'notes': 'Bring a torch'}),
      ]);

      expect(preview.items.first.block, isNull);
      final block = preview.items.last.block!;
      expect(block.reason, BlockReason.notPermitted);
      expect(block.detail, contains('rewrites'));
    });

    test(
      'refuses a later change to a record of an entry it rewrites',
      () async {
        await saveSeries(start: nine);
        await h.run([writeSeries()]);
        final tank = await db
            .customSelect(
              'SELECT id FROM dive_tanks WHERE dive_id = ? ORDER BY id LIMIT 1',
              variables: [Variable.withString((await linkOf('a'))!)],
            )
            .getSingle();

        final preview = await h.preview([
          writeSeries(),
          updateOp('dive_tanks', tank.read<String>('id'), {'name': 'Left'}),
        ]);

        expect(preview.items.last.block!.reason, BlockReason.notPermitted);
      },
    );

    test('leaves a later change to another dive alone', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);

      final preview = await h.preview([
        writeSeries(),
        updateOp('dives', 'd1', {'notes': 'Bring a torch'}),
      ]);

      expect(preview.items.map((i) => i.block), [isNull, isNull]);
    });

    test('with no owner, writes its entries for the active diver', () async {
      await saveSeries(start: nine, diverId: null);

      await h.run([writeSeries()]);

      for (final planId in ['a', 'b']) {
        final dive = await diveOf(await linkOf(planId));
        expect(dive!.diverId, kDiverA, reason: planId);
      }
    });

    test('cannot be dissolved in the same change', () async {
      await saveSeries(start: nine);

      final preview = await h.preview([
        writeSeries(const {}, {'dissolve_keeping_plan_id': 'a'}),
      ]);

      expect(preview.items.single.block!.reason, BlockReason.notPermitted);
    });
  });

  group('a new series', () {
    const reef = {
      'start_date_time': '2026-10-27T09:00:00Z',
      'tanks': [
        {'volume_l': 12, 'start_pressure_bar': 200, 'o2_fraction': 0.32},
      ],
      'bottom': {'depth_m': 24, 'time_s': 1200},
    };
    const wall = {
      'surface_interval_s': 5400,
      // Another gas, so it is a fresh tank, not dive A's carried on.
      'tanks': [
        {'volume_l': 12, 'start_pressure_bar': 200, 'o2_fraction': 0.36},
      ],
      'bottom': {'depth_m': 18, 'time_s': 1800},
    };

    test('is saved and logged in one change', () async {
      final preview = await h.preview([
        createOp('dive_plan_series', {
          'name': 'Reef day',
          'dives': [reef, wall],
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);
      final item = preview.items.single;
      expect(item.block, isNull);
      expect(item.alsoCreates, {'dive_plans': 2, 'dives': 2});
      // A new series has no entries yet, so it only counts the ones it gets.
      expect(item.fields, isNot(contains(PlannedDivesEffect.entriesKey)));
      final id = (await h.apply(preview)).created.single.id;

      final stored = (await DivePlanSeriesRepository().getSeries(id))!;
      for (final dive in stored.dives) {
        final entry = await diveOf(dive.plan.linkedDiveId);
        expect(entry, isNotNull);
        expect(entry!.isPlanned, isTrue);
        expect(entry.diverId, kDiverA);
      }
    });

    test('without a first start is refused', () async {
      final preview = await h.preview([
        createOp('dive_plan_series', {
          'name': 'Reef day',
          'dives': [
            {...reef}..remove('start_date_time'),
            wall,
          ],
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);

      expect(preview.items.single.block!.reason, BlockReason.missingField);
    });

    test('as a copy is refused', () async {
      await saveSeries(start: nine);

      final preview = await h.preview([
        createOp('dive_plan_series', {
          'duplicate_of': 's1',
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);

      expect(preview.items.single.block!.reason, BlockReason.notPermitted);
    });

    test('reverted, leaves no plan and no entry', () async {
      final result = await h.run([
        createOp('dive_plan_series', {
          'name': 'Reef day',
          'dives': [reef, wall],
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);

      await h.revert(result);

      expect(await db.customSelect('SELECT id FROM dives').get(), hasLength(2));
      expect(await db.customSelect('SELECT id FROM dive_plans').get(), isEmpty);
      expect(
        await db
            .customSelect(
              "SELECT id FROM dive_profile_series WHERE dive_id NOT IN "
              "('d1', 'd2')",
            )
            .get(),
        isEmpty,
      );
    });
  });

  group('a single plan', () {
    Future<void> savePlan({String? linkedDiveId}) async {
      await DivePlanRepository().savePlan(
        divePlanFromState(
          seriesDiveState(id: 'p').copyWith(startDateTime: nine),
        ),
      );
      if (linkedDiveId != null) {
        await DivePlanRepository().linkPlanToDive('p', linkedDiveId);
      }
    }

    Map<String, Object?> writePlan([Map<String, Object?> options = const {}]) =>
        updateOp('dive_plans', 'p', {PlannedDivesEffect.field: options});

    test('gets a planned entry, linked to it', () async {
      await savePlan();

      final preview = await h.preview([writePlan()]);
      expect(preview.items.single.block, isNull);
      expect(preview.items.single.alsoCreates, {'dives': 1});
      await h.apply(preview);

      final entry = (await diveOf(await linkOf('p')))!;
      expect(entry.isPlanned, isTrue);
      expect(entry.diverId, kDiverA);
    });

    Map<String, Object?> createPlan() => createOp('dive_plans', {
      'name': 'Wreck',
      'start_date_time': '2026-10-27T09:00:00Z',
      'tanks': [
        {
          'volume_l': 12,
          'start_pressure_bar': 200,
          'o2_fraction': 0.32,
          'he_fraction': 0,
          'role': 'backGas',
        },
      ],
      'segments': [
        {'target_depth_m': 20, 'duration_s': 120, 'tank': 0},
        {'target_depth_m': 20, 'duration_s': 1800, 'tank': 0},
      ],
      PlannedDivesEffect.field: const <String, Object?>{},
    });

    test('is created and logged in one change', () async {
      final preview = await h.preview([createPlan()]);
      final item = preview.items.single;
      expect(item.block, isNull);
      expect(item.alsoCreates, {'dives': 1});
      // A new plan has no entry yet, so it only counts the one it gets.
      expect(item.fields, isNot(contains(PlannedDivesEffect.entriesKey)));
      final id = (await h.apply(preview)).created.single.id;

      expect((await diveOf(await linkOf(id)))!.isPlanned, isTrue);
    });

    test(
      'created, cannot follow an earlier change to the log in the same set',
      () async {
        final preview = await h.preview([
          updateOp('dives', 'd1', {'notes': 'Bring a torch'}),
          createPlan(),
        ]);

        final block = preview.items.last.block!;
        expect(block.reason, BlockReason.notPermitted);
        expect(block.detail, contains('the log'));
      },
    );

    test('previewed for one diver is stale once another is active', () async {
      await savePlan();
      final preview = await h.preview([writePlan()]);
      expect(preview.items.single.block, isNull);

      active = kDiverB;

      await expectLater(h.apply(preview), throwsA(anything));
      expect(await linkOf('p'), isNull);
    });

    test('linked to a dived dive needs move_dived_link', () async {
      await savePlan(linkedDiveId: 'd1');

      final refused = await h.preview([writePlan()]);
      expect(refused.items.single.block!.reason, BlockReason.notPermitted);
      expect(refused.items.single.block!.detail, contains('move_dived_link'));

      await h.run([
        writePlan({PlannedDivesEffect.moveDivedLink: true}),
      ]);

      final entry = await linkOf('p');
      expect(entry, isNot('d1'));
      expect((await diveOf(entry))!.isPlanned, isTrue);
      expect((await diveOf('d1'))!.isPlanned, isFalse);
    });

    test('in a series is refused', () async {
      await saveSeries(start: nine);

      final preview = await h.preview([
        updateOp('dive_plans', 'a', {
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);

      final block = preview.items.single.block!;
      expect(block.reason, BlockReason.notPermitted);
      expect(block.detail, contains('s1'));
    });
  });

  group('revert', () {
    /// Every row of the log tables a planned entry spans, keyed by table,
    /// less the stamps every write renews.
    Future<Map<String, List<Map<String, Object?>>>> logSnapshot() async {
      const tables = [
        'dives',
        'dive_tanks',
        'dive_profile_series',
        'gas_switches',
        'dive_plans',
      ];
      const stamps = {'updated_at', 'hlc'};
      return {
        for (final table in tables)
          table: [
            for (final row
                in await db
                    .customSelect('SELECT * FROM $table ORDER BY id')
                    .get())
              {
                for (final e in row.data.entries)
                  if (!stamps.contains(e.key)) e.key: e.value,
              },
          ],
      };
    }

    test('of a rewrite puts each entry and its profile back', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      // Dive B is planned shallower, so its entry is rewritten.
      await saveSeries(start: nine, depthB: 18);
      final before = await logSnapshot();

      final result = await h.run([writeSeries()]);
      expect(await logSnapshot(), isNot(before));

      await h.revert(result);

      expect(await logSnapshot(), before);
    });

    test('of a first write leaves the log as it was', () async {
      await saveSeries(start: nine);
      final before = await logSnapshot();

      final result = await h.run([writeSeries()]);
      await h.revert(result);

      expect(await logSnapshot(), before);
    });

    test('of delete_removed brings the entry and its plan back', () async {
      await saveSeries(start: nine);
      await h.run([writeSeries()]);
      final dropped = (await linkOf('b'))!;
      final before = await logSnapshot();

      final result = await h.run([
        writeSeries(
          {PlannedDivesEffect.deleteRemoved: true},
          {
            'plan_ids': ['a'],
          },
        ),
      ]);
      expect(await diveOf(dropped), isNull);
      await h.revert(result);

      expect(await logSnapshot(), before);
      expect(await linkOf('b'), dropped);
    });

    test('of a moved link puts it back on the dived dive', () async {
      await DivePlanRepository().savePlan(
        divePlanFromState(
          seriesDiveState(id: 'p').copyWith(startDateTime: nine),
        ),
      );
      await DivePlanRepository().linkPlanToDive('p', 'd1');
      final before = await logSnapshot();

      final result = await h.run([
        updateOp('dive_plans', 'p', {
          PlannedDivesEffect.field: {PlannedDivesEffect.moveDivedLink: true},
        }),
      ]);
      expect(await linkOf('p'), isNot('d1'));
      await h.revert(result);

      expect(await linkOf('p'), 'd1');
      expect(await logSnapshot(), before);
    });
  });
}
