import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';

/// Repository singleton for saved repetitive series.
final divePlanSeriesRepositoryProvider = Provider<DivePlanSeriesRepository>(
  (ref) =>
      DivePlanSeriesRepository(plans: ref.watch(divePlanRepositoryProvider)),
);

/// Saves the series in the editor, every dive of it (issue #3565), and adopts
/// what was stored. Each dive is saved with its start and interval as the
/// chain settles them; what it carries in is worked out again on opening.
///
/// Takes the container rather than a `WidgetRef`: the save outlives a page
/// the diver leaves during it.
Future<void> saveCurrentSeries(ProviderContainer container) async {
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final repository = container.read(divePlanSeriesRepositoryProvider);
  final plans = container.read(divePlanRepositoryProvider);
  final series = container.read(planSeriesNotifierProvider);
  final results = container.read(planSeriesResultsProvider);

  final dives = <StoredSeriesDive>[];
  for (var i = 0; i < series.dives.length; i++) {
    final dive = series.dives[i];
    final result = results[i];
    dives.add(
      StoredSeriesDive(
        plan: divePlanFromState(
          result.state,
          existing: await plans.getPlan(dive.state.id),
        ),
        name: dive.name,
        fixedStart: dive.fixedStart,
        settingOverrides: dive.settingOverrides,
        sourceTankIds: dive.sourceTankIds,
        pinnedTankIds: dive.pinnedTankIds,
        summaryMaxDepth: result.outcome.maxDepth,
        summaryRuntimeSeconds: result.outcome.runtimeSeconds,
        summaryTtsSeconds: result.outcome.ttsAtBottom,
      ),
    );
  }

  final stored = await repository.saveSeries(
    StoredSeries(
      id: series.id ?? const Uuid().v4(),
      name: series.dives.first.state.name,
      diverId: container.read(currentDiverIdProvider),
      followedDiveId: series.follow?.followed.id,
      dives: dives,
    ),
  );
  if (!notifier.mounted) return;
  notifier.loadSeries(
    _toSeries(
      stored,
      // A followed dive deleted since it was followed has gone from the row.
      follow: stored.followedDiveId == null ? null : series.follow,
      selectedIndex: series.selectedIndex,
    ),
  );
}

/// Opens the saved plan [planId]: its whole series with that dive selected
/// when it has one, carrying in what the followed dive and earlier dives left
/// behind. An ordinary plan opens as it always has.
Future<void> openSavedPlan(ProviderContainer container, String planId) async {
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final editor = container.read(divePlanNotifierProvider.notifier);
  final repository = container.read(divePlanSeriesRepositoryProvider);

  final seriesId = await repository.seriesIdForPlan(planId);
  final stored = seriesId == null ? null : await repository.getSeries(seriesId);
  if (stored == null || stored.dives.isEmpty) {
    await editor.loadPlanById(planId);
    return;
  }

  // Rebuilt from the dive, not followed afresh: following would re-mint the
  // first dive's tanks and reset its interval.
  final followedId = stored.followedDiveId;
  final follow = followedId == null
      ? null
      : await container.awaitFuture(seriesFollowProvider(followedId).future);
  if (!notifier.mounted) return;

  final index = stored.dives.indexWhere((dive) => dive.plan.id == planId);
  notifier.loadSeries(
    _toSeries(
      stored,
      follow: follow == null ? null : _withOwnPressures(follow, stored),
      selectedIndex: index < 0 ? 0 : index,
    ),
  );
}

PlanSeries _toSeries(
  StoredSeries stored, {
  required SeriesFollow? follow,
  required int selectedIndex,
}) {
  return PlanSeries(
    id: stored.id,
    follow: follow,
    selectedIndex: selectedIndex,
    dives: [
      for (final dive in stored.dives)
        PlanSeriesDive(
          state: stateFromDivePlan(dive.plan).copyWith(isDirty: false),
          name: dive.name,
          fixedStart: dive.fixedStart,
          settingOverrides: dive.settingOverrides,
          sourceTankIds: dive.sourceTankIds,
          pinnedTankIds: dive.pinnedTankIds,
        ),
    ],
  );
}

/// [follow] with the first dive's own pressures, which are not stored: each
/// tank taken from the logged dive fills to what that tank started with.
SeriesFollow _withOwnPressures(SeriesFollow follow, StoredSeries stored) {
  final first = stored.dives.first;
  final logged = {for (final tank in follow.endTanks) tank.id: tank};
  return follow.copyWith(
    ownStartPressures: {
      for (final tank in first.plan.tanks)
        tank.id:
            ?(logged[first.sourceTankIds[tank.id]]?.startPressure ??
            logged[first.sourceTankIds[tank.id]]?.workingPressure ??
            tank.startPressure),
    },
  );
}
