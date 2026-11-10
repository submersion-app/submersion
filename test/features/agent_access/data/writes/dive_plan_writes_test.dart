import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/compute_plan_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Saved dive plans and repetitive series, as the planner saves them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Future<String> plan([String name = 'Reef']) => make('dive_plans', {
    'name': name,
    'tanks': [
      {'volume_l': 11.1, 'start_pressure_bar': 200, 'o2_fraction': 0.32},
    ],
    'segments': [
      {'target_depth_m': 20, 'duration_s': 1200, 'tank': 0},
    ],
  });

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a plan is saved, renamed, duplicated and deleted', () async {
    final id = await plan(' Reef ');
    final doc = (await h.one('dive_plans', id))!;
    expect(doc['name'], 'Reef');
    final tank = (doc['tanks']! as List).cast<Map>().single;
    final segment = (doc['segments']! as List).cast<Map>().single;
    expect(segment['tank_id'], tank['id']);
    expect(segment['o2_fraction'], 0.32);
    final row = await (db.select(
      db.divePlans,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(row.summaryMaxDepth, 20);

    await h.run([
      updateOp('dive_plans', id, {'name': 'Wall', 'gf_low': 30, 'gf_high': 70}),
    ]);
    final renamed = (await h.one('dive_plans', id))!;
    expect(
      [renamed['name'], renamed['gf_low'], renamed['gf_high']],
      ['Wall', 30, 70],
    );

    final copy = await make('dive_plans', {'duplicate_of': id, 'name': 'Copy'});
    final copied = (await h.one('dive_plans', copy))!;
    expect(copied['name'], 'Copy');
    expect(copied['segments'], hasLength(1));

    await h.run([deleteOp('dive_plans', id)]);
    expect(await h.one('dive_plans', id), isNull);
  });

  test(
    'linking a plan to a dive lists the plan it takes the dive from',
    () async {
      final first = await plan('First');
      final second = await plan('Second');
      await h.run([
        updateOp('dive_plans', first, {'linked_dive_id': 'd1'}),
      ]);

      final take = await h.preview([
        updateOp('dive_plans', second, {'linked_dive_id': 'd1'}),
      ]);
      expect(take.items.single.alsoChanges, {'dive_plans': 1});
      await h.apply(take);

      expect((await h.one('dive_plans', first))!['linked_dive_id'], isNull);
      expect((await h.one('dive_plans', second))!['linked_dive_id'], 'd1');
    },
  );

  test('a series removing a dive lists that plan\'s delete', () async {
    final now = DateTime.now();
    DivePlan blank(String id) =>
        DivePlan(id: id, name: id, createdAt: now, updatedAt: now);
    final series = await DivePlanSeriesRepository().saveSeries(
      StoredSeries(
        id: 'series-1',
        name: 'Two dives',
        dives: [
          StoredSeriesDive(plan: blank('plan-1')),
          StoredSeriesDive(plan: blank('plan-2')),
        ],
      ),
    );
    final ids = [for (final d in series.dives) d.plan.id];

    final plan = await h.preview([
      updateOp('dive_plan_series', series.id, {
        'name': 'One dive',
        'plan_ids': [ids.first],
      }),
    ]);
    expect(plan.items.single.reach.parts, {'dive_plans': 1});
    await h.apply(plan);

    final doc = (await h.one('dive_plan_series', series.id))!;
    expect(doc['name'], 'One dive');
    expect(
      [for (final d in doc['dives']! as List) (d as Map)['plan_id']],
      [ids.first],
    );
    expect(await h.one('dive_plans', ids.last), isNull);
  });

  test('compute_plan resolved_inputs save as the plan it computed '
      '(#4203)', () async {
    final settings = DiverSettingsRepository();
    final computed =
        await ComputePlanTool(
          loader: DiverContextLoader(
            db: () => db,
            divers: DiverRepository(),
            settings: settings,
            localeTag: 'en',
            activeDiverId: () async => kDiverA,
          ),
          settings: settings,
          followOf: (_) async => null,
          caveat: () => '',
        ).call({
          'dives': [
            {
              'gf_low': 35,
              'gf_high': 75,
              'tanks': [
                {'volume_l': 24, 'start_pressure_bar': 200},
                {'volume_l': 7, 'start_pressure_bar': 200, 'o2_fraction': 0.5},
              ],
              'bottom': {'depth_m': 42, 'time_s': 1500},
            },
          ],
        }, AgentToolContext(db: db, clientName: 'test'));
    final dive = (computed['dives']! as List).single as Map;

    final id = await make('dive_plans', {
      'name': 'Computed',
      ...(dive['resolved_inputs']! as Map).cast<String, Object?>(),
    });

    final row = await (db.select(
      db.divePlans,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(row.summaryRuntimeSeconds, dive['runtime_s']);
    expect(row.summaryTtsSeconds, dive['tts_at_bottom_s']);
    expect(row.summaryMaxDepth, dive['max_depth_m']);
  });

  test('a plan sets and clears its ascent rates and gas allowance', () async {
    const keys = [
      'intermediate_ascent_rate_m_min',
      'shallow_ascent_rate_m_min',
      'final_ascent_rate_m_min',
      'gas_switch_stop_s',
      'sac_factor',
      'problem_solving_minutes',
      'o2_narcotic',
    ];
    final id = await make('dive_plans', {
      'name': 'Rates',
      'tanks': [
        {'volume_l': 12, 'start_pressure_bar': 200},
      ],
      'segments': [
        {'target_depth_m': 30, 'duration_s': 1200, 'tank': 0},
      ],
      'intermediate_ascent_rate_m_min': 6,
      'shallow_ascent_rate_m_min': 3,
      'final_ascent_rate_m_min': 1,
      'gas_switch_stop_s': 60,
      'sac_factor': 1.5,
      'problem_solving_minutes': 0,
      'o2_narcotic': false,
    });
    final saved = (await h.one('dive_plans', id))!;
    expect([for (final k in keys) saved[k]], [6, 3, 1, 60, 1.5, 0, false]);

    await h.run([
      updateOp('dive_plans', id, {for (final k in keys) k: null}),
    ]);
    final cleared = (await h.one('dive_plans', id))!;
    expect([for (final k in keys) cleared[k]], everyElement(isNull));
  });

  test('a plan naming a missing site is refused', () async {
    final plan = await h.preview([
      createOp('dive_plans', {'name': 'X', 'site_id': 'gone'}),
      createOp('dive_plans', {
        'name': 'Y',
        'segments': [
          {'target_depth_m': 10, 'duration_s': 60, 'tank': 3},
        ],
      }),
    ]);

    expect(plan.items[0].block!.reason, BlockReason.unknownReference);
    expect(plan.items[1].block!.reason, BlockReason.invalidValue);
  });

  test('a plan tank in the suit inflation role is refused (#4243)', () async {
    final plan = await h.preview([
      createOp('dive_plans', {
        'name': 'Dry',
        'tanks': [
          {'volume_l': 11.1, 'o2_fraction': 0.32},
          {'volume_l': 0.85, 'o2_fraction': 0.21, 'role': 'suitInflation'},
        ],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test(
    "a plan's summary is worked out with its owner's planner settings",
    () async {
      Future<int?> ttsOf(String id) async => (await (db.select(
        db.divePlans,
      )..where((p) => p.id.equals(id))).getSingle()).summaryTtsSeconds;
      Future<String> deep() => make('dive_plans', {
        'name': 'Deep',
        'tanks': [
          {'volume_l': 15, 'start_pressure_bar': 230, 'o2_fraction': 0.21},
        ],
        'segments': [
          {'target_depth_m': 40, 'duration_s': 1500, 'tank': 0},
        ],
      });

      final atDefaultsId = await deep();
      final atDefaults = await ttsOf(atDefaultsId);
      await DiverSettingsRepository().createSettingsForDiver(
        kDiverA,
        settings: const AppSettings(gfLow: 20, gfHigh: 50),
      );
      final strict = await deep();

      expect(await ttsOf(strict), greaterThan(atDefaults!));

      // An update works it out again for the plan's owner too.
      await h.run([
        updateOp('dive_plans', strict, {'name': 'Deeper'}),
      ]);
      expect(await ttsOf(strict), greaterThan(atDefaults));

      // A bare copy works it out again too, rather than keeping the
      // summary its source was saved with.
      final copy = await make('dive_plans', {'duplicate_of': atDefaultsId});
      expect(await ttsOf(copy), await ttsOf(strict));
    },
  );
}
