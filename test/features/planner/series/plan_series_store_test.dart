import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Saving and opening a series through the planner (issue #3565).
void main() {
  late ProviderContainer c;

  /// The followed dive, as the dive log would analyse it: a heavy load.
  SeriesFollow? followed;
  var dives = <Dive>[];

  setUp(() async {
    await setUpTestDatabase();
    followed = null;
    dives = [];
    c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        divesProvider.overrideWith((ref) async => dives),
        seriesFollowProvider.overrideWith((ref, id) async => followed),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    c.read(planSeriesNotifierProvider);
  });

  tearDown(tearDownTestDatabase);

  PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);
  DivePlanState editor() => c.read(divePlanNotifierProvider);

  test('a series reopens with its dives, names and intervals', () async {
    series().addDive();
    series().renameSelected('Wreck');
    c
        .read(divePlanNotifierProvider.notifier)
        .setSurfaceInterval(const Duration(hours: 2));
    await saveCurrentSeries(c);
    final saved = c.read(planSeriesNotifierProvider);
    final planId = saved.dives[1].state.id;

    c.read(divePlanNotifierProvider.notifier).newPlan();
    expect(c.read(planSeriesNotifierProvider).dives, hasLength(1));

    await openSavedPlan(c, planId);

    final opened = c.read(planSeriesNotifierProvider);
    expect(opened.id, saved.id);
    expect(opened.dives, hasLength(2));
    expect(opened.selectedIndex, 1);
    expect(opened.selected.name, 'Wreck');
    expect(editor().surfaceInterval, const Duration(hours: 2));
    expect(editor().initialTissueState, isNotNull);
    expect(opened.isDirty, isFalse);
  });

  test('saving leaves nothing to save; any change on any dive does', () async {
    series().addDive();
    expect(c.read(planSeriesDirtyProvider), isTrue);
    await saveCurrentSeries(c);
    expect(c.read(planSeriesDirtyProvider), isFalse);

    c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);
    series().select(0);
    expect(editor().isDirty, isFalse);
    expect(c.read(planSeriesDirtyProvider), isTrue);
  });

  test('naming or removing a dive is a change to save', () async {
    series().addDive();
    await saveCurrentSeries(c);

    series().renameSelected('Wreck');
    expect(c.read(planSeriesDirtyProvider), isTrue);
    await saveCurrentSeries(c);
    expect(c.read(planSeriesDirtyProvider), isFalse);

    series().removeDive(1);
    expect(c.read(planSeriesDirtyProvider), isTrue);
  });

  test('an ordinary plan opens as it always has', () async {
    await c.read(divePlanNotifierProvider.notifier).save();
    final id = editor().id;
    c.read(divePlanNotifierProvider.notifier).newPlan();

    await openSavedPlan(c, id);

    expect(editor().id, id);
    expect(c.read(planSeriesNotifierProvider).id, isNull);
    expect(c.read(planSeriesSavesAsSeriesProvider), isFalse);
  });

  test('a saved followed plan reopens with what it carries, not as a fresh '
      'diver', () async {
    final compartments = computeOutcomeForState(
      seriesDiveState(depth: 40, bottomMinutes: 40),
      config: const PlanEngineConfig(),
    ).endTissue.compartments;
    final end = DateTime(2026, 10, 27, 8);
    await c
        .read(diveRepositoryProvider)
        .createDive(loggedDive('logged', end, number: 7));
    followed = SeriesFollow(
      loggedDives: [seriesLoggedDive('logged', end, otu: 40, number: 7)],
      endTissues: compartments,
      endCns: 45,
    );
    series().followDive(followed!, surfaceInterval: const Duration(hours: 1));
    final before = c.read(planOutcomeProvider);
    expect(editor().initialTissueState, isNotNull);

    await saveCurrentSeries(c);
    final id = editor().id;
    c.read(divePlanNotifierProvider.notifier).newPlan();
    await openSavedPlan(c, id);

    final after = c.read(planOutcomeProvider);
    expect(c.read(planSeriesNotifierProvider).follow?.followed.id, 'logged');
    expect(after.runtimeSeconds, before.runtimeSeconds);
    expect(after.cnsEnd, before.cnsEnd);
    expect(after.otuTotal, before.otuTotal);
    expect(after.stops.length, before.stops.length);
  });

  test('a series deleted through the planner leaves no plans', () async {
    series().addDive();
    await saveCurrentSeries(c);
    final saved = c.read(planSeriesNotifierProvider);

    await c.read(divePlanSeriesRepositoryProvider).deleteSeries(saved.id!);

    final summaries = await c
        .read(divePlanRepositoryProvider)
        .getAllPlanSummaries();
    expect(summaries, isEmpty);
  });
}
