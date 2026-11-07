import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_series_settings.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';

/// Repository singleton for saved repetitive series.
final divePlanSeriesRepositoryProvider = Provider<DivePlanSeriesRepository>(
  (ref) =>
      DivePlanSeriesRepository(plans: ref.watch(divePlanRepositoryProvider)),
);

/// Saves the series in the editor, every dive of it (issue #3565), and adopts
/// what was stored. Each dive is saved with its interval as the chain
/// settles it; what it carries in is worked out again on opening.
///
/// Takes the container rather than a `WidgetRef`: the save outlives a page
/// the diver leaves during it.
Future<void> saveCurrentSeries(ProviderContainer container) async {
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final repository = container.read(divePlanSeriesRepositoryProvider);
  final series = container.read(planSeriesNotifierProvider);

  // One dive that follows nothing is an ordinary plan again: it leaves the
  // series it was saved in, so it converts and compares like any plan.
  if (series.id case final id? when !series.isSeries && series.follow == null) {
    await _saveAsPlainPlan(container, id);
    return;
  }

  final stored = await repository.saveSeries(
    await currentStoredSeries(container),
  );
  if (!notifier.mounted) return;
  // Edited while the save ran: those edits were not stored, so keep them,
  // still unsaved, rather than swap in the copy that was.
  if (container.read(planSeriesNotifierProvider) != series) {
    notifier.adoptSavedId(stored.id);
    return;
  }
  notifier.loadSeries(
    seriesFromStored(
      stored,
      // A followed dive deleted since it was followed has gone from the row.
      follow: stored.followedDiveId == null ? null : series.follow,
      selectedIndex: series.selectedIndex,
    ),
    justSaved: true,
  );
}

/// Saves the one dive in the editor as an ordinary plan, leaving the saved
/// series [seriesId] it was in.
Future<void> _saveAsPlainPlan(
  ProviderContainer container,
  String seriesId,
) async {
  final editor = container.read(divePlanNotifierProvider.notifier);
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final outcome = container.read(planOutcomeProvider);
  await container
      .read(divePlanSeriesRepositoryProvider)
      .dissolveSeries(
        seriesId,
        keepPlanId: container.read(divePlanNotifierProvider).id,
      );
  await editor.save(
    summary: PlanSummaryData(
      maxDepth: outcome.maxDepth,
      runtimeSeconds: outcome.runtimeSeconds,
      ttsSeconds: outcome.ttsAtBottom,
    ),
  );
  if (notifier.mounted) notifier.leaveSavedSeries();
}

/// Gives the planner the name [name] just stored from elsewhere for the
/// saved plans row [renamed] (its whole series when it is in one), if that
/// is what the planner holds. Without it the planner's next save would write
/// back the name it opened with.
void adoptRenameInPlanner(
  ProviderContainer container,
  DivePlanSummary renamed,
  String name,
) {
  final series = container.read(planSeriesNotifierProvider);
  final seriesId = renamed.seriesId;
  final open = seriesId != null
      ? series.id == seriesId
      : series.id == null && series.dives.any((d) => d.state.id == renamed.id);
  if (open) {
    container.read(planSeriesNotifierProvider.notifier).adoptStoredName(name);
  }
}

/// The series in the editor as it would be stored, for saving or sharing.
Future<StoredSeries> currentStoredSeries(ProviderContainer container) async {
  final plans = container.read(divePlanRepositoryProvider);
  final series = container.read(planSeriesNotifierProvider);
  final results = container.read(planSeriesResultsProvider);

  final follow = series.follow;
  final dives = <StoredSeriesDive>[];
  for (var i = 0; i < series.dives.length; i++) {
    final dive = series.dives[i];
    final result = results[i];
    final existing = await plans.getPlan(dive.state.id);
    dives.add(
      StoredSeriesDive(
        // A dive that has been dived keeps its plan as saved: what the chain
        // holds for it now is what happened, such as its real start.
        plan: existing != null && dive.actual != null
            ? existing
            : divePlanFromState(
                i == 0 && follow != null
                    ? _atOwnPressures(result.state, dive, follow)
                    : result.state,
                existing: existing,
              ),
        name: dive.name,
        sourceTankIds: dive.sourceTankIds,
        pinnedTankIds: dive.pinnedTankIds,
        fixedStart: dive.fixedStart,
        settingOverrides: dive.settingOverrides,
        summaryMaxDepth: result.outcome.maxDepth,
        summaryRuntimeSeconds: result.outcome.runtimeSeconds,
        summaryTtsSeconds: result.outcome.ttsAtBottom,
      ),
    );
  }

  return StoredSeries(
    id: series.id ?? const Uuid().v4(),
    name: series.dives.first.state.name,
    diverId: container.read(currentDiverIdProvider),
    followedDiveId: series.follow?.followed.id,
    dives: dives,
  );
}

/// The first dive's [state] with each tank it did not have typed in back at
/// its own pressure. What the followed dive leaves in a tank is worked out
/// again on opening; stored, it would outlive that dive, and a shared file,
/// which leaves the dive out, would start from the sender's remaining gas.
DivePlanState _atOwnPressures(
  DivePlanState state,
  PlanSeriesDive dive,
  SeriesFollow follow,
) => state.copyWith(
  tanks: [
    for (final tank in state.tanks)
      if (!dive.pinnedTankIds.contains(tank.id) &&
          follow.ownStartPressures[tank.id] != null)
        tank.copyWith(startPressure: follow.ownStartPressures[tank.id])
      else
        tank,
  ],
);

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
    // Whether its dive has been dived, read first: the plan then shows as
    // dived from its first frame (issue #3565).
    final linked =
        (await container.read(divePlanRepositoryProvider).getPlan(planId))
            ?.linkedDiveId;
    final actuals = linked == null
        ? const <String, SeriesFollow>{}
        : await _actualsOf(container, [(planId, linked)]);
    if (!notifier.mounted) return;
    await editor.loadPlanById(planId);
    // No await between the load and this, so no frame shows the plan alone.
    if (notifier.mounted) notifier.setActuals(actuals);
    return;
  }

  // Rebuilt from the dive, not followed afresh: following would re-mint the
  // first dive's tanks and reset its interval.
  final followedId = stored.followedDiveId;
  final follow = followedId == null
      ? null
      : await container.awaitFuture(seriesFollowProvider(followedId).future);
  if (!notifier.mounted) return;

  final actuals = await _actualsOf(container, [
    for (final dive in stored.dives)
      if (dive.plan.linkedDiveId case final id?) (dive.plan.id, id),
  ]);
  if (!notifier.mounted) return;

  final index = stored.dives.indexWhere((dive) => dive.plan.id == planId);
  notifier.loadSeries(
    seriesFromStored(
      stored,
      follow: follow == null ? null : _withOwnPressures(follow, stored),
      selectedIndex: index < 0 ? 0 : index,
    ),
    actuals: actuals,
  );
}

/// What the log says about [links], read through [container].
Future<Map<String, SeriesFollow>> _actualsOf(
  ProviderContainer container,
  List<(String, String)> links,
) => links.isEmpty
    ? Future.value(const {})
    : readSeriesActuals(
        links,
        container.read(diveRepositoryProvider),
        (diveId) => container.awaitFuture(seriesFollowProvider(diveId).future),
      );

/// The planner's series for [stored], following [follow] with
/// [selectedIndex] selected. Nothing in it is unsaved.
PlanSeries seriesFromStored(
  StoredSeries stored, {
  required SeriesFollow? follow,
  required int selectedIndex,
}) {
  final dives = [
    for (final dive in stored.dives)
      PlanSeriesDive(
        state: stateFromDivePlan(dive.plan).copyWith(isDirty: false),
        name: dive.name,
        sourceTankIds: dive.sourceTankIds,
        pinnedTankIds: dive.pinnedTankIds,
        fixedStart: dive.fixedStart,
        settingOverrides: dive.settingOverrides,
      ),
  ];
  final first = dives.first.state;
  return PlanSeries(
    id: stored.id,
    follow: follow,
    selectedIndex: selectedIndex,
    dives: [
      // The first dive's settings are the series'; a later one keeps every
      // group whose values are not the series', said so or not.
      for (final (index, dive) in dives.indexed)
        index == 0
            ? dive.copyWith(settingOverrides: const {})
            : dive.copyWith(settingOverrides: ownSettingGroups(first, dive)),
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
