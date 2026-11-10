import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../series/series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings(gfLow: 30, gfHigh: 70));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What an outcome shows a diver, to compare two computations of a dive.
List<Object?> _shown(SeriesDiveResult r) => [
  r.state.startDateTime,
  r.state.surfaceInterval,
  r.outcome.runtimeSeconds,
  r.outcome.ttsAtBottom,
  r.outcome.maxDepth,
  r.outcome.cnsEnd,
  r.outcome.otuTotal,
  [for (final s in r.outcome.stops) (s.depthMeters, s.durationSeconds)],
  [for (final i in r.outcome.issues) i.type],
  r.actual?.followed.id,
];

/// A saved plan or series computed without the planner (issue #4203).
void main() {
  final nine = DateTime.utc(2026, 10, 27, 9);
  const config = PlanEngineConfig();

  group('without the planner', () {
    late DiveRepository dives;
    late DivePlanRepository plans;
    late DivePlanSeriesRepository seriesRepository;

    setUp(() async {
      await setUpTestDatabase();
      dives = DiveRepository();
      plans = DivePlanRepository();
      seriesRepository = DivePlanSeriesRepository(plans: plans);
    });

    tearDown(tearDownTestDatabase);

    StoredSeries twoDives({String? followedDiveId}) => StoredSeries(
      id: 'series',
      name: 'Saturday',
      followedDiveId: followedDiveId,
      dives: [
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: 'a').copyWith(startDateTime: nine),
          ),
          name: 'Wreck',
          fixedStart: true,
        ),
        StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(
              id: 'b',
              depth: 18,
              surfaceInterval: const Duration(hours: 1),
            ),
          ),
        ),
      ],
    );

    Future<SeriesFollow?> noFollow(String _) async => null;

    /// [series] saved with dive A linked to [diveId], as the link actions
    /// leave it: saving a series never writes a link.
    Future<StoredSeries> savedWithALinkedTo(String diveId) async {
      final saved = await seriesRepository.saveSeries(twoDives());
      await plans.linkPlanToDive('a', diveId);
      return (await seriesRepository.getSeries(saved.id))!;
    }

    test('a series computes each dive carrying from the one before', () async {
      final stored = await seriesRepository.saveSeries(twoDives());

      final computed = await computeStoredSeries(
        stored,
        config: config,
        dives: dives,
        followOf: noFollow,
      );

      expect(computed.series.id, stored.id);
      expect(computed.series.dives.map((d) => d.name), ['Wreck', null]);
      expect(computed.results, hasLength(2));
      final direct = computeSeries(computed.series.dives, config: config);
      expect(computed.results.map(_shown), direct.map(_shown));
      // B starts an hour after A surfaces, carrying A's loading.
      final a = computed.results[0];
      final b = computed.results[1];
      expect(
        b.state.startDateTime,
        nine
            .add(Duration(seconds: a.outcome.runtimeSeconds))
            .add(const Duration(hours: 1)),
      );
      expect(b.state.initialCns, greaterThan(0));
    });

    test('it computes with the config it is given', () async {
      final stored = await seriesRepository.saveSeries(twoDives());
      final strict = await computeStoredSeries(
        stored,
        config: const PlanEngineConfig(gfLow: 20, gfHigh: 50),
        dives: dives,
        followOf: noFollow,
      );
      final loose = await computeStoredSeries(
        stored,
        config: const PlanEngineConfig(gfLow: 90, gfHigh: 95),
        dives: dives,
        followOf: noFollow,
      );
      // The plans carry their own GF 40/80, which wins over either config.
      expect(
        strict.results.map(_shown).toList(),
        loose.results.map(_shown).toList(),
      );
      final unset = twoDives();
      final withoutOwn = StoredSeries(
        id: 'other',
        name: 'Other',
        dives: [
          for (final d in unset.dives)
            d.copyWith(
              plan: divePlanFromState(
                stateFromDivePlan(
                  d.plan,
                ).copyWith(clearGfLow: true, clearGfHigh: true),
              ),
            ),
        ],
      );
      final strictOwn = await computeStoredSeries(
        withoutOwn,
        config: const PlanEngineConfig(gfLow: 20, gfHigh: 50),
        dives: dives,
        followOf: noFollow,
      );
      final looseOwn = await computeStoredSeries(
        withoutOwn,
        config: const PlanEngineConfig(gfLow: 90, gfHigh: 95),
        dives: dives,
        followOf: noFollow,
      );
      expect(
        strictOwn.results[0].outcome.ttsAtBottom,
        greaterThan(looseOwn.results[0].outcome.ttsAtBottom),
      );
    });

    test('a dived dive is taken as dived', () async {
      final dived = await dives.createDive(loggedDive('dived', nine));
      final stored = await savedWithALinkedTo(dived.id);
      expect(stored.dives.first.plan.linkedDiveId, dived.id);
      final follow = SeriesFollow(
        loggedDives: [
          seriesLoggedDive(dived.id, nine.add(const Duration(minutes: 50))),
        ],
      );
      final asked = <String>[];

      final computed = await computeStoredSeries(
        stored,
        config: config,
        dives: dives,
        followOf: (id) async {
          asked.add(id);
          return follow;
        },
      );

      expect(asked, [dived.id]);
      expect(computed.results[0].actual, follow);
      expect(computed.results[1].actual, isNull);
    });

    test('a planned entry is still a plan', () async {
      final planned = await dives.createDive(
        loggedDive('planned', nine, isPlanned: true),
      );
      final stored = await savedWithALinkedTo(planned.id);
      expect(stored.dives.first.plan.linkedDiveId, planned.id);

      final computed = await computeStoredSeries(
        stored,
        config: config,
        dives: dives,
        followOf: (_) async => fail('a planned entry is not read as dived'),
      );

      expect(computed.results.map((r) => r.actual), [isNull, isNull]);
    });

    test('a series that follows a logged dive starts from it', () async {
      final logged = await dives.createDive(loggedDive('logged', nine));
      final stored = await seriesRepository.saveSeries(
        twoDives(followedDiveId: logged.id),
      );
      final follow = SeriesFollow(
        loggedDives: [
          seriesLoggedDive(logged.id, nine.subtract(const Duration(hours: 1))),
        ],
        endCns: 30,
      );

      final computed = await computeStoredSeries(
        stored,
        config: config,
        dives: dives,
        followOf: (id) async => id == logged.id ? follow : null,
      );

      expect(computed.series.follow?.followed.id, logged.id);
      expect(computed.results[0].state.initialCns, greaterThan(0));
      final unfollowed = await computeStoredSeries(
        twoDives(),
        config: config,
        dives: dives,
        followOf: noFollow,
      );
      expect(unfollowed.results[0].state.initialCns ?? 0, 0);
    });

    test('a series with no dives is refused', () async {
      await expectLater(
        computeStoredSeries(
          const StoredSeries(id: 'empty', name: 'Empty', dives: []),
          config: config,
          dives: dives,
          followOf: noFollow,
        ),
        throwsArgumentError,
      );
      // The same, for a series never saved, with the log already read.
      expect(
        () => computeSeriesFromStored(
          const StoredSeries(id: 'empty', name: 'Empty', dives: []),
          follow: null,
          config: config,
        ),
        throwsArgumentError,
      );
    });

    test('a plan in no series computes on its own', () async {
      final plan = await plans.savePlan(
        divePlanFromState(seriesDiveState(id: 'solo')),
      );

      final computed = await computeStoredPlan(
        plan,
        config: config,
        dives: dives,
        followOf: noFollow,
      );

      expect(computed.series.isSeries, isFalse);
      expect(computed.series.dives.single.state.id, 'solo');
      expect(computed.results.single.outcome.runtimeSeconds, greaterThan(0));
      expect(computed.series.dives.single.state.isDirty, isFalse);
    });
  });

  group('matches the planner', () {
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await setUpTestDatabase();
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
      addTearDown(c.dispose);
    });

    tearDown(tearDownTestDatabase);

    test('a saved series computes as the planner opens it', () async {
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
      final notifier = c.read(planSeriesNotifierProvider.notifier);
      notifier.setSelectedStart(nine);
      notifier.addDive();
      notifier.fillAllTanks();
      await saveCurrentSeries(c);
      final saved = c.read(planSeriesNotifierProvider);
      final planId = saved.dives[0].state.id;

      // Opened afresh, as from the saved plans list.
      c.read(divePlanNotifierProvider.notifier).newPlan();
      await openSavedPlan(c, planId);
      final inPlanner = c.read(planSeriesResultsProvider);
      expect(inPlanner, hasLength(2));

      final stored = await c
          .read(divePlanSeriesRepositoryProvider)
          .getSeries(saved.id!);
      final computed = await computeStoredSeries(
        stored!,
        config: c.read(planEngineConfigProvider),
        dives: c.read(diveRepositoryProvider),
        followOf: (id) => c.read(seriesFollowProvider(id).future),
      );

      expect(computed.results.map(_shown), inPlanner.map(_shown));
    });

    test(
      'a dived plan in no series computes as the planner opens it',
      () async {
        final dived = await c
            .read(diveRepositoryProvider)
            .createDive(loggedDive('dived', nine));
        final plans = c.read(divePlanRepositoryProvider);
        // No surface interval and no start: the planner computes the plan as
        // it stands, not timed by when its dive was dived.
        final saved = await plans.savePlan(
          divePlanFromState(seriesDiveState(id: 'solo')),
        );
        await plans.linkPlanToDive(saved.id, dived.id);

        c.read(divePlanNotifierProvider.notifier).newPlan();
        await openSavedPlan(c, saved.id);
        final inPlanner = c.read(planSeriesResultsProvider);
        expect(inPlanner.single.actual?.followed.id, dived.id);

        final computed = await computeStoredPlan(
          (await plans.getPlan(saved.id))!,
          config: c.read(planEngineConfigProvider),
          dives: c.read(diveRepositoryProvider),
          followOf: (id) => c.awaitFuture(seriesFollowProvider(id).future),
        );

        expect(computed.results.map(_shown), inPlanner.map(_shown));
      },
    );
  });
}
