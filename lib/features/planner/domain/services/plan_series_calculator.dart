import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

/// How long a dive's OTU counts towards a later dive: the daily limit.
const otuCarryWindow = Duration(hours: 24);

/// One dive of a series as computed: its inputs with everything the earlier
/// dives carry in applied, and the engine's outcome for them.
class SeriesDiveResult {
  final DivePlanState state;
  final PlanOutcome outcome;

  const SeriesDiveResult({required this.state, required this.outcome});
}

/// Computes a repetitive series in order (issue #3565). Each dive after the
/// first starts from the dive before it: its tissues as they surfaced, after
/// the ascent and its stops, then off-gassed, and its CNS
/// decayed over the surface interval, the OTU of every dive that ended in
/// the last [otuCarryWindow], and each mapped tank at its source tank's end
/// pressure. The first dive starts from the logged dive it [follow]s, if
/// any, the same way; otherwise it is computed as given.
List<SeriesDiveResult> computeSeries(
  List<PlanSeriesDive> dives, {
  required PlanEngineConfig config,
  SeriesFollow? follow,
}) {
  final results = <SeriesDiveResult>[];
  for (var i = 0; i < dives.length; i++) {
    final state = carriedState(dives, i, results, follow: follow);
    results.add(
      SeriesDiveResult(
        state: state,
        outcome: computeOutcomeForState(state, config: config),
      ),
    );
  }
  return results;
}

/// The inputs of the dive at [index] with what the dives before it carry in
/// applied, from [earlier]: the results of the dives before it, in order.
/// The first dive carries from the logged dive it [follow]s, if any.
DivePlanState carriedState(
  List<PlanSeriesDive> dives,
  int index,
  List<SeriesDiveResult> earlier, {
  SeriesFollow? follow,
}) {
  final dive = dives[index];
  if (index == 0) {
    if (follow == null) return dive.state;
    final tissues = follow.endTissues;
    return dive.state.copyWith(
      initialTissueState: tissues,
      initialTissueEnvironment: follow.endEnvironment,
      clearInitialTissueState: tissues == null,
      initialCns: follow.endCns,
      initialOtu: _carriedOtu(dives, 0, earlier, follow),
      surfaceInterval:
          dive.state.surfaceInterval ?? defaultSeriesSurfaceInterval,
      tanks: followedTankPressures(
        dive.state.tanks,
        follow,
        sources: dive.sourceTankIds,
        pinned: dive.pinnedTankIds,
      ),
    );
  }
  final previous = earlier[index - 1];

  final remaining = {
    for (final usage in previous.outcome.tankUsages)
      if (usage.remainingPressure case final pressure?)
        usage.tankId: pressure < 0 ? 0.0 : pressure,
  };
  final tanks = [
    for (final tank in dive.state.tanks)
      if (!dive.pinnedTankIds.contains(tank.id) &&
          remaining[dive.sourceTankIds[tank.id]] != null)
        tank.copyWith(startPressure: remaining[dive.sourceTankIds[tank.id]])
      else
        tank,
  ];

  return dive.state.copyWith(
    initialTissueState: previous.outcome.surfacedTissue.compartments,
    initialTissueEnvironment: environmentForPlan(previous.state),
    initialCns: previous.outcome.cnsEnd,
    initialOtu: _carriedOtu(dives, index, earlier, follow),
    tanks: tanks,
  );
}

/// The OTU of every earlier dive, logged ones the series [follow]s
/// included, that ended less than [otuCarryWindow] before the dive at
/// [index] starts. Times run from the first planned dive's start; each dive
/// starts its surface interval after the one before ends.
double _carriedOtu(
  List<PlanSeriesDive> dives,
  int index,
  List<SeriesDiveResult> earlier,
  SeriesFollow? follow,
) {
  final ends = <int>[];
  var clock = 0;
  for (var j = 0; j < index; j++) {
    if (j > 0) clock += _intervalSeconds(dives[j]);
    clock += earlier[j].outcome.runtimeSeconds;
    ends.add(clock);
  }
  final start = index == 0 ? 0 : clock + _intervalSeconds(dives[index]);

  var otu = 0.0;
  if (follow != null) {
    // The first planned dive starts its interval when the followed dive ends.
    final followedEnd = follow.followed.end;
    final firstStart = _intervalSeconds(dives[0]);
    for (final logged in follow.loggedDives) {
      final sinceEnd =
          start + firstStart + followedEnd.difference(logged.end).inSeconds;
      if (sinceEnd < otuCarryWindow.inSeconds) otu += logged.otu;
    }
  }
  for (var j = 0; j < index; j++) {
    if (start - ends[j] >= otuCarryWindow.inSeconds) continue;
    final result = earlier[j];
    otu += result.outcome.otuTotal - (result.state.initialOtu ?? 0);
  }
  return otu;
}

int _intervalSeconds(PlanSeriesDive dive) =>
    (dive.state.surfaceInterval ?? defaultSeriesSurfaceInterval).inSeconds;
