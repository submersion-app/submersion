import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/compute_plan_tool.dart';
import 'package:submersion/features/agent_access/data/writes/families/planned_dives_effect.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';
import '../records/record_harness.dart';
import '../writes/child_write_harness.dart';

/// `compute_plan` given a saved plan's or series' id (issue #4203): the
/// plan computed again as the planner opens it, with where each dive
/// stands in the log.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  final followed = <String, SeriesFollow>{};
  Future<SeriesFollow?> followOf(String id) async => followed[id];

  final nine = DateTime.utc(2026, 11, 14, 9);

  const deep = {
    'start_date_time': '2026-11-14T09:00:00Z',
    'tanks': [
      {'volume_l': 15, 'start_pressure_bar': 230, 'o2_fraction': 0.21},
      {
        'volume_l': 7,
        'start_pressure_bar': 200,
        'o2_fraction': 0.5,
        'role': 'deco',
      },
    ],
    'bottom': {'depth_m': 40, 'time_s': 1200},
  };
  // On a fresh cylinder of its own: the first dive's back gas would run
  // out, and the planner refuses to log a dive that does.
  const shallow = {
    'surface_interval_s': 5400,
    'tanks': [
      {'volume_l': 12, 'start_pressure_bar': 200, 'o2_fraction': 0.32},
    ],
    'bottom': {'depth_m': 18, 'time_s': 2700},
  };

  ComputePlanTool tool() {
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
      records: RecordRepositories(activeDiverId: () async => kDiverA),
      caveat: () => 'Check it.',
    );
  }

  Future<Map<String, Object?>> compute(Map<String, Object?> args) =>
      tool().call(args, AgentToolContext(db: db, clientName: 'test'));

  List<Map<String, Object?>> divesOf(Map<String, Object?> out) => [
    for (final d in out['dives']! as List) (d as Map).cast<String, Object?>(),
  ];

  /// What a schedule adds up to, to compare two computations of it.
  List<Object?> scheduleOf(Map<String, Object?> out) => [
    for (final d in divesOf(out))
      [d['runtime_s'], d['tts_at_bottom_s'], d['stops'], d['cns_end_percent']],
  ];

  Matcher refusal(AgentToolErrorCode code) =>
      throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

  /// The series [dives] describe, computed then saved from its
  /// resolved_inputs as an agent saves it; its id.
  Future<(String, Map<String, Object?>)> savedSeries(
    List<Map<String, Object?>> dives, {
    Map<String, Object?> extra = const {},
  }) async {
    final computed = await compute({'dives': dives, ...extra});
    final result = await h.run([
      createOp('dive_plan_series', {
        'name': 'Deep pair',
        'dives': [for (final d in divesOf(computed)) d['resolved_inputs']],
        'followed_dive_id': ?extra['follow_dive_id'],
      }),
    ]);
    return (result.created.single.id, computed);
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
    await DiverSettingsRepository().createSettingsForDiver(
      kDiverA,
      settings: const AppSettings(gfLow: 30, gfHigh: 70),
    );
  });
  tearDown(() => tearDownTestDatabase());

  group('a saved series', () {
    test('computes as it did before it was saved', () async {
      final (id, before) = await savedSeries([deep, shallow]);

      final recalled = await compute({'series_id': id});
      expect(scheduleOf(recalled), scheduleOf(before));
      expect(recalled['recalled'], {
        'series_id': id,
        'name': 'Deep pair',
        'overrides': <String>[],
      });
      expect(recalled['recall_note'], contains('Settings'));
      expect(recalled['caveat'], 'Check it.');
      expect(recalled['diver_id'], kDiverA);
      final dives = divesOf(recalled);
      expect(dives.map((d) => d['log_state']), ['planned', 'planned']);
      expect(dives.map((d) => d['linked_dive_id']), [null, null]);
    });

    test('its resolved_inputs compute the same schedule again', () async {
      final (id, _) = await savedSeries([deep, shallow]);
      final recalled = await compute({'series_id': id});

      final again = await compute({
        'dives': [for (final d in divesOf(recalled)) d['resolved_inputs']],
      });
      expect(scheduleOf(again), scheduleOf(recalled));
      final second = divesOf(recalled)[1]['resolved_inputs']! as Map;
      expect(second['surface_interval_s'], 5400);
      expect(second.containsKey('start_date_time'), isFalse);
      // Another gas: nothing of the dive before carries into it.
      expect(second['carries_from_tank'], [null]);
    });

    test('follows its logged dive as that dive is now', () async {
      followed['d1'] = SeriesFollow(
        loggedDives: [
          seriesLoggedDive('d1', nine.subtract(const Duration(hours: 3))),
        ],
        endCns: 25,
      );
      final (id, before) = await savedSeries(
        [
          {...deep}..remove('start_date_time'),
          shallow,
        ],
        extra: {'follow_dive_id': 'd1'},
      );

      final recalled = await compute({'series_id': id});
      expect(recalled['followed_dive_id'], 'd1');
      expect(recalled['followed_dive_in_log'], isTrue);
      expect(scheduleOf(recalled), scheduleOf(before));
      // Given back with the dive it follows, it computes the same again.
      final again = await compute({
        'dives': [for (final d in divesOf(recalled)) d['resolved_inputs']],
        'follow_dive_id': recalled['followed_dive_id'],
      });
      expect(scheduleOf(again), scheduleOf(recalled));

      // The followed dive is gone from the log: computed without it.
      followed.clear();
      final alone = await compute({'series_id': id});
      expect(alone['followed_dive_in_log'], isFalse);
      expect(
        divesOf(alone).first['carried_in'],
        isNot(divesOf(before).first['carried_in']),
      );
    });

    test(
      'a dive saved with no interval computes again at the default',
      () async {
        final (id, _) = await savedSeries([deep, shallow]);
        final stored = (await DivePlanSeriesRepository().getSeries(id))!;
        // As the planner can save a later dive: no interval of its own.
        await db.customStatement(
          'UPDATE dive_plans SET surface_interval_seconds = NULL WHERE id = ?',
          [stored.dives.last.plan.id],
        );

        final recalled = await compute({'series_id': id});
        final second = divesOf(recalled).last['resolved_inputs']! as Map;
        expect(second['surface_interval_s'], 3600);
        final again = await compute({
          'dives': [for (final d in divesOf(recalled)) d['resolved_inputs']],
        });
        expect(scheduleOf(again), scheduleOf(recalled));
      },
    );

    test('a later dive leaving a setting to Settings keeps it so', () async {
      final (id, _) = await savedSeries([
        {...deep, 'gf_low': 50, 'gf_high': 85},
        shallow,
      ]);
      final stored = (await DivePlanSeriesRepository().getSeries(id))!;
      // As the planner can save it: the first dive's own gradient factors,
      // the second on Settings'.
      await db.customStatement(
        'UPDATE dive_plans SET gf_low = NULL, gf_high = NULL WHERE id = ?',
        [stored.dives.last.plan.id],
      );

      final recalled = await compute({'series_id': id});
      final second = divesOf(recalled).last['resolved_inputs']! as Map;
      expect(second.containsKey('gf_low'), isTrue);
      expect(second['gf_low'], isNull);
      final again = await compute({
        'dives': [for (final d in divesOf(recalled)) d['resolved_inputs']],
      });
      expect(scheduleOf(again), scheduleOf(recalled));
    });

    test('says where each dive stands once it is in the log', () async {
      final (id, _) = await savedSeries([deep, shallow]);
      await h.run([
        updateOp('dive_plan_series', id, {
          PlannedDivesEffect.field: const <String, Object?>{},
        }),
      ]);
      final stored = (await DivePlanSeriesRepository().getSeries(id))!;
      final first = (await DivePlanRepository().getPlan(
        stored.dives.first.plan.id,
      ))!.linkedDiveId!;

      var dives = divesOf(await compute({'series_id': id}));
      expect(dives.map((d) => d['log_state']), [
        'logged_as_planned',
        'logged_as_planned',
      ]);
      expect(dives.first['linked_dive_id'], first);

      await db.customStatement('UPDATE dives SET is_planned = 0 WHERE id = ?', [
        first,
      ]);
      dives = divesOf(await compute({'series_id': id}));
      expect(dives.map((d) => d['log_state']), ['dived', 'logged_as_planned']);
    });

    test('is computed with its own diver\'s Settings', () async {
      await DiverSettingsRepository().createSettingsForDiver(
        kDiverB,
        settings: const AppSettings(gfLow: 50, gfHigh: 90),
      );
      final (id, _) = await savedSeries([deep, shallow]);
      await db.customStatement(
        'UPDATE dive_plan_series SET diver_id = ? WHERE id = ?',
        [kDiverB, id],
      );

      final owned = await compute({'series_id': id});
      expect(owned['diver_id'], kDiverB);
      final asked = await compute({'series_id': id, 'diver_id': kDiverA});
      expect(asked['diver_id'], kDiverA);
      expect(scheduleOf(owned), isNot(scheduleOf(asked)));
    });
  });

  group('a saved plan in no series', () {
    test('computes as it did before it was saved', () async {
      final before = await compute({
        'dives': [deep],
      });
      final result = await h.run([
        createOp('dive_plans', {
          'name': 'Deep',
          ...divesOf(before).single['resolved_inputs']! as Map<String, Object?>,
        }),
      ]);
      final id = result.created.single.id;

      final recalled = await compute({'plan_id': id});
      expect(scheduleOf(recalled), scheduleOf(before));
      expect((recalled['recalled']! as Map)['plan_id'], id);
      expect(recalled['followed_dive_id'], isNull);
      expect(recalled.containsKey('followed_dive_in_log'), isFalse);
      expect(divesOf(recalled).single['log_state'], 'planned');
      final again = await compute({
        'dives': [divesOf(recalled).single['resolved_inputs']],
      });
      expect(scheduleOf(again), scheduleOf(recalled));
    });
  });

  group('overrides', () {
    test('try a setting on every dive and save nothing', () async {
      final (id, before) = await savedSeries([deep, shallow]);

      final tried = await compute({
        'series_id': id,
        'overrides': {'gf_low': 50, 'gf_high': 85},
      });
      expect((tried['recalled']! as Map)['overrides'], ['gf_high', 'gf_low']);
      expect(scheduleOf(tried), isNot(scheduleOf(before)));
      for (final d in divesOf(tried)) {
        expect((d['resolved_inputs']! as Map)['gf_low'], 50);
      }

      final stored = (await DivePlanSeriesRepository().getSeries(id))!;
      expect([for (final d in stored.dives) d.plan.gfLow], [null, null]);
      expect(scheduleOf(await compute({'series_id': id})), scheduleOf(before));
    });

    test('a null clears the plan\'s own value, so Settings decide', () async {
      final (id, before) = await savedSeries([
        {...deep, 'gf_low': 50, 'gf_high': 85},
        shallow,
      ]);
      final cleared = await compute({
        'series_id': id,
        'overrides': {'gf_low': null, 'gf_high': null},
      });
      expect(scheduleOf(cleared), isNot(scheduleOf(before)));
      final first = divesOf(cleared).first['resolved_inputs']! as Map;
      expect(first.containsKey('gf_low'), isFalse);
    });
  });

  test('ids sent as null ask for no recall', () async {
    final out = await compute({
      'plan_id': null,
      'series_id': null,
      'dives': [deep],
    });
    expect(out.containsKey('recalled'), isFalse);
    expect(divesOf(out), hasLength(1));
    // With nothing else, it is the missing dives that is refused.
    await expectLater(
      compute({'plan_id': null}),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
            .having((e) => e.details?['field'], 'field', 'dives'),
      ),
    );
  });

  group('refused', () {
    test('both ids', () async {
      await expectLater(
        compute({'plan_id': 'p', 'series_id': 's'}),
        refusal(AgentToolErrorCode.invalidArgument),
      );
    });

    test('dives or follow_dive_id beside an id', () async {
      await expectLater(
        compute({
          'series_id': 's',
          'dives': [deep],
        }),
        refusal(AgentToolErrorCode.invalidArgument),
      );
      await expectLater(
        compute({'plan_id': 'p', 'follow_dive_id': 'd1'}),
        refusal(AgentToolErrorCode.invalidArgument),
      );
    });

    test('an id no saved plan or series has', () async {
      await expectLater(
        compute({'series_id': 'nope'}),
        refusal(AgentToolErrorCode.notFound),
      );
      await expectLater(
        compute({'plan_id': 'nope'}),
        refusal(AgentToolErrorCode.notFound),
      );
    });

    test('a plan in a series, naming the series', () async {
      final (id, _) = await savedSeries([deep, shallow]);
      final stored = (await DivePlanSeriesRepository().getSeries(id))!;
      await expectLater(
        compute({'plan_id': stored.dives.first.plan.id}),
        throwsA(
          isA<AgentToolException>()
              .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
              .having((e) => e.message, 'message', contains(id)),
        ),
      );
    });

    test('overrides without an id to recall', () async {
      await expectLater(
        compute({
          'dives': [deep],
          'overrides': {'gf_low': 50},
        }),
        refusal(AgentToolErrorCode.invalidArgument),
      );
    });

    test('a diver_id that is not an id, recalled or not', () async {
      final (id, _) = await savedSeries([deep, shallow]);
      for (final args in [
        {'series_id': id, 'diver_id': 7},
        {
          'dives': [deep],
          'diver_id': 7,
        },
      ]) {
        await expectLater(
          compute(args),
          refusal(AgentToolErrorCode.invalidArgument),
          reason: '$args',
        );
      }
    });

    test('an override that is not a setting, or out of range', () async {
      final (id, _) = await savedSeries([deep, shallow]);
      for (final overrides in [
        {'tanks': <Object?>[]},
        {'gf_low': 0},
        'gf 50',
      ]) {
        await expectLater(
          compute({'series_id': id, 'overrides': overrides}),
          refusal(AgentToolErrorCode.invalidArgument),
          reason: '$overrides',
        );
      }
    });
  });
}
