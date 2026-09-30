import 'dart:isolate';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
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

/// How long an edit must stand before the mission is computed. A figure is
/// typed one keystroke at a time, each an edit, and an isolate cannot be
/// cancelled once started. Injectable so widget tests can run with none.
final missionSettleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 150),
);

final _epoch = DateTime.utc(2000);

/// What the engine reads: the plan without its name, notes and timestamps,
/// which change on a rename or a save and never change the outcome.
(domain.DivePlan?, DpvMission?) _missionInputs(DivePlanState s) {
  final mission = s.mission;
  if (mission == null) return (null, null);
  final plan = divePlanFromState(
    s,
  ).copyWith(name: '', notes: '', createdAt: _epoch, updatedAt: _epoch);
  return (plan, mission);
}

/// The failure-scenario outcome of the plan's DPV mission, or null when the
/// plan has none. Recomputed when an input the engine reads changes, once
/// the edit settles; Riverpod drops the result of a computation superseded
/// by a newer edit, so a stale outcome is never delivered as current.
/// Never retried: an engine error is the same error the next time.
final missionOutcomeProvider = FutureProvider<MissionOutcome?>((ref) async {
  final (plan, mission) = ref.watch(
    divePlanNotifierProvider.select(_missionInputs),
  );
  if (plan == null || mission == null) return null;
  final config = ref.watch(planEngineConfigProvider);
  final runner = ref.watch(missionEngineRunnerProvider);
  final settle = ref.watch(missionSettleDelayProvider);
  if (settle > Duration.zero) {
    await Future<void>.delayed(settle);
    // A newer edit replaced this computation while it waited.
    if (!ref.mounted) return null;
  }
  return runner(plan, mission, config);
}, retry: (_, _) => null);
