import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
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
/// pressure. The first dive is computed as given, so a dive it follows
/// still seeds it.
List<SeriesDiveResult> computeSeries(
  List<PlanSeriesDive> dives, {
  required PlanEngineConfig config,
}) {
  final results = <SeriesDiveResult>[];
  for (var i = 0; i < dives.length; i++) {
    final state = carriedState(dives, i, results);
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
DivePlanState carriedState(
  List<PlanSeriesDive> dives,
  int index,
  List<SeriesDiveResult> earlier,
) {
  final dive = dives[index];
  if (index == 0) return dive.state;
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
    initialOtu: _carriedOtu(dives, index, earlier),
    tanks: tanks,
  );
}

/// The OTU of every earlier dive that ended less than [otuCarryWindow]
/// before the dive at [index] starts. Times run from the first dive's start;
/// each dive starts its surface interval after the one before ends.
double _carriedOtu(
  List<PlanSeriesDive> dives,
  int index,
  List<SeriesDiveResult> earlier,
) {
  final ends = <int>[];
  var clock = 0;
  for (var j = 0; j < index; j++) {
    if (j > 0) clock += _intervalSeconds(dives[j]);
    clock += earlier[j].outcome.runtimeSeconds;
    ends.add(clock);
  }
  final start = clock + _intervalSeconds(dives[index]);

  var otu = 0.0;
  for (var j = 0; j < index; j++) {
    if (start - ends[j] >= otuCarryWindow.inSeconds) continue;
    final result = earlier[j];
    otu += result.outcome.otuTotal - (result.state.initialOtu ?? 0);
  }
  return otu;
}

int _intervalSeconds(PlanSeriesDive dive) =>
    (dive.state.surfaceInterval ?? defaultSeriesSurfaceInterval).inSeconds;
