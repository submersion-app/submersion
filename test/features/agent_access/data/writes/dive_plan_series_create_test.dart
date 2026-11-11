import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/compute_plan_tool.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A repetitive series an agent creates from its dives, as `compute_plan`
/// takes them, rather than as a copy (#4203).
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

  Map<String, Object?> seriesOp(Map<String, Object?> fields) =>
      createOp('dive_plan_series', fields);

  Future<String> make(Map<String, Object?> fields) async =>
      (await h.run([seriesOp(fields)])).created.single.id;

  /// A series saved by the planner, to copy.
  Future<StoredSeries> savedSeries() => DivePlanSeriesRepository().saveSeries(
    StoredSeries(
      id: 's1',
      name: 'Saved',
      dives: [
        StoredSeriesDive(plan: divePlanFromState(seriesDiveState(id: 'a'))),
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
          ),
        ),
      ],
    ),
  );

  ComputePlanTool computeTool() {
    final settings = DiverSettingsRepository();
    return ComputePlanTool(
      loader: DiverContextLoader(
        db: () => db,
        divers: DiverRepository(),
        settings: settings,
        localeTag: 'en',
        activeDiverId: () async => kDiverA,
      ),
      settings: settings,
      followOf: followOf,
      caveat: () => '',
    );
  }

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

  test('a series is created from its dives', () async {
    final preview = await h.preview([
      seriesOp({
        'name': 'Reef day',
        'dives': [reef, wall],
      }),
    ]);
    expect(preview.items.single.block, isNull);
    expect(preview.items.single.alsoCreates, {'dive_plans': 2});
    final id = (await h.apply(preview)).created.single.id;

    final stored = (await DivePlanSeriesRepository().getSeries(id))!;
    expect(stored.name, 'Reef day');
    expect(stored.diverId, kDiverA);
    expect(stored.followedDiveId, isNull);
    expect(stored.dives, hasLength(2));
    expect(
      [for (final d in stored.dives) d.plan.name],
      ['Reef day', 'Reef day'],
    );
    final second = stored.dives[1];
    expect(second.plan.surfaceInterval, const Duration(seconds: 5400));
    // The second dive took the first one's tank and carries its pressure on.
    expect(second.sourceTankIds, {
      second.plan.tanks.single.id: stored.dives[0].plan.tanks.single.id,
    });
    for (final dive in stored.dives) {
      expect(dive.summaryRuntimeSeconds, greaterThan(0));
      expect(dive.summaryMaxDepth, isNotNull);
    }
  });

  test('compute_plan resolved_inputs save as the series it computed, which '
      'computes the same once saved', () async {
    await DiverSettingsRepository().createSettingsForDiver(
      kDiverA,
      settings: const AppSettings(gfLow: 30, gfHigh: 70),
    );
    final computed = await computeTool().call({
      'dives': [
        {
          'tanks': [
            {'volume_l': 15, 'start_pressure_bar': 230, 'o2_fraction': 0.21},
          ],
          'bottom': {'depth_m': 40, 'time_s': 1200},
        },
        {
          'surface_interval_s': 3600,
          'bottom': {'depth_m': 30, 'time_s': 1500},
        },
      ],
    }, AgentToolContext(db: db, clientName: 'test'));
    final results = [
      for (final d in computed['dives']! as List)
        (d as Map).cast<String, Object?>(),
    ];

    final id = await make({
      'name': 'Deep pair',
      'dives': [for (final r in results) r['resolved_inputs']],
    });

    final stored = (await DivePlanSeriesRepository().getSeries(id))!;
    for (final (i, dive) in stored.dives.indexed) {
      expect(dive.summaryRuntimeSeconds, results[i]['runtime_s']);
      expect(dive.summaryTtsSeconds, results[i]['tts_at_bottom_s']);
      expect(dive.summaryMaxDepth, results[i]['max_depth_m']);
    }
    final settings = await DiverSettingsRepository().getSettingsForDiver(
      kDiverA,
    );
    final reopened = await computeStoredSeries(
      stored,
      config: planEngineConfigFromSettings(settings!),
      dives: DiveRepository(),
      followOf: followOf,
    );
    expect(
      [for (final r in reopened.results) r.outcome.runtimeSeconds],
      [for (final r in results) r['runtime_s']],
    );
    expect(
      [for (final r in reopened.results) r.outcome.ttsAtBottom],
      [for (final r in results) r['tts_at_bottom_s']],
    );
  });

  test('a series following a logged dive starts after it', () async {
    followed['d1'] = SeriesFollow(
      loggedDives: [
        seriesLoggedDive(
          'd1',
          DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ],
      endCns: 20,
    );

    final id = await make({
      'name': 'After the wreck',
      'followed_dive_id': 'd1',
      'dives': [reef, wall],
    });

    final stored = (await DivePlanSeriesRepository().getSeries(id))!;
    expect(stored.followedDiveId, 'd1');
    final interval = stored.dives.first.plan.surfaceInterval!;
    expect(interval.inMinutes, closeTo(120, 1));
  });

  test('reverting the create removes the series and its dives', () async {
    final result = await h.run([
      seriesOp({
        'name': 'Reef day',
        'dives': [reef, wall],
      }),
    ]);
    expect(await db.select(db.divePlans).get(), hasLength(2));

    await h.revert(result);

    expect(await db.select(db.divePlanSeries).get(), isEmpty);
    expect(await db.select(db.divePlans).get(), isEmpty);
    expect(await db.select(db.divePlanTanks).get(), isEmpty);
    expect(await db.select(db.divePlanSegments).get(), isEmpty);
  });

  group('refused', () {
    Future<PlanBlock?> blockOf(Map<String, Object?> fields) async =>
        (await h.preview([seriesOp(fields)])).items.single.block;

    test('a series of one dive, which is a dive plan', () async {
      final block = await blockOf({
        'name': 'Solo',
        'dives': [reef],
      });
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('dive_plans'));
    });

    test('neither dives nor a copy', () async {
      final block = await blockOf({'name': 'Empty'});
      expect(block!.reason, BlockReason.missingField);
    });

    test('dives with no name', () async {
      final block = await blockOf({
        'dives': [reef, wall],
      });
      expect(block!.reason, BlockReason.missingField);
    });

    test('dives and a copy together', () async {
      final copy = await savedSeries();
      final block = await blockOf({
        'name': 'Both',
        'duplicate_of': copy.id,
        'dives': [reef, wall],
      });
      expect(block!.reason, BlockReason.notPermitted);
    });

    test('a followed dive on a copy', () async {
      final copy = await savedSeries();
      final block = await blockOf({
        'duplicate_of': copy.id,
        'followed_dive_id': 'd1',
      });
      expect(block!.reason, BlockReason.notPermitted);
    });

    test('a dive the planner could not compute, naming it', () async {
      final block = await blockOf({
        'name': 'No interval',
        'dives': [
          reef,
          {
            'bottom': {'depth_m': 18, 'time_s': 2700},
          },
        ],
      });
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('dives[1]'));
    });

    test('following a dive that is not a logged one', () async {
      final block = await blockOf({
        'name': 'After nothing',
        'followed_dive_id': 'd1',
        'dives': [reef, wall],
      });
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('d1'));
    });
  });
}
