import 'dart:isolate';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Computes a mission outcome. Injectable so tests can run it on the
/// calling isolate.
typedef MissionEngineRunner =
    Future<MissionOutcome> Function(
      domain.DivePlan plan,
      DpvMission mission,
      PlanEngineConfig config,
    );

/// Runs the mission engine on a background isolate. A realistic mission is
/// dozens of full plan-engine runs, which would drop frames on the UI
/// isolate; the plan, the mission and the config are plain values, so they
/// cross the isolate boundary by copy.
Future<MissionOutcome> runMissionEngineInIsolate(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) {
  return Isolate.run(
    () => MissionEngine(
      scenarios: MissionScenarioService(engine: PlanEngine(config: config)),
    ).compute(plan: plan, mission: mission),
  );
}

final missionEngineRunnerProvider = Provider<MissionEngineRunner>(
  (ref) => runMissionEngineInIsolate,
);

/// The failure-scenario outcome of the plan's DPV mission, or null when the
/// plan has none. Recomputed on every edit and settings change; Riverpod
/// drops the result of a computation superseded by a newer edit, so a stale
/// outcome is never delivered as current.
final missionOutcomeProvider = FutureProvider<MissionOutcome?>((ref) async {
  final state = ref.watch(divePlanNotifierProvider);
  final mission = state.mission;
  if (mission == null) return null;
  final config = ref.watch(planEngineConfigProvider);
  final runner = ref.watch(missionEngineRunnerProvider);
  return runner(divePlanFromState(state), mission, config);
});
