import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';

/// Runs the engine once over an editing [state], seeding tissues from any
/// followed dive exactly the way the live canvas does.
PlanOutcome computeOutcomeForState(
  DivePlanState state, {
  required PlanEngineConfig config,
}) {
  final engine = PlanEngine(config: config);
  return engine.compute(
    divePlanFromState(state),
    startState: startStateForPlan(state, config: config),
  );
}

/// Whether an editing [state] starts with a deco obligation left by the dive
/// before it: its tissues, once off-gassed over the surface interval, still
/// cannot surface at the plan's high gradient factor.
bool startsOwingDeco(DivePlanState state, {required PlanEngineConfig config}) {
  final seed = startStateForPlan(state, config: config);
  if (seed is! BuhlmannState) return false;
  final algorithm = BuhlmannAlgorithm(
    gfLow: (state.gfLow ?? config.gfLow) / 100.0,
    gfHigh: (state.gfHigh ?? config.gfHigh) / 100.0,
    environment: _environmentFor(state),
  )..setCompartments(seed.compartments);
  return algorithm.surfaceTargetCeiling() > 0;
}

/// The tissues an editing [state] starts from: a followed dive's
/// compartments off-gassed over the surface interval, or null for a fresh
/// diver. Every engine run that stands in for this plan (the live outcome,
/// contingencies, the range table, the bailout picture) starts here.
///
/// Reads gfLow/gfHigh from [state], falling back to [config] (issue #3552,
/// follow-up to v304-307) when the plan has not overridden them - the same
/// resolution PlanEngineConfig.resolvedFor applies for the engine run
/// itself, kept in sync here so the seed and the schedule agree.
TissueState? startStateForPlan(
  DivePlanState state, {
  required PlanEngineConfig config,
}) {
  return seededTissueState(
    compartments: state.initialTissueState,
    surfaceInterval: state.surfaceInterval,
    gfLow: (state.gfLow ?? config.gfLow) / 100.0,
    gfHigh: (state.gfHigh ?? config.gfHigh) / 100.0,
    environment: _environmentFor(state),
  );
}

/// Matches the engine: altitude <= 0 is unset (legacy 1.0 bar), so the seed
/// is off-gassed at the same surface pressure the plan is computed at.
DiveEnvironment _environmentFor(DivePlanState state) =>
    DiveEnvironment.forConditions(
      altitudeMeters: (state.altitude ?? 0) > 0 ? state.altitude : null,
      waterType: state.waterType ?? WaterType.salt,
      salinityPpt: state.salinityPpt,
    );
