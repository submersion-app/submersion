import 'package:submersion/core/constants/enums.dart';
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
    startState: startStateForPlan(state),
  );
}

/// The tissues an editing [state] starts from: a followed dive's
/// compartments off-gassed over the surface interval, or null for a fresh
/// diver. Every engine run that stands in for this plan (the live outcome,
/// contingencies, the range table, the bailout picture) starts here.
TissueState? startStateForPlan(DivePlanState state) {
  return seededTissueState(
    compartments: state.initialTissueState,
    surfaceInterval: state.surfaceInterval,
    gfLow: state.gfLow / 100.0,
    gfHigh: state.gfHigh / 100.0,
    // Match the engine: altitude <= 0 is unset (legacy 1.0 bar), so the seed
    // is off-gassed at the same surface pressure the plan is computed at.
    environment: DiveEnvironment.forConditions(
      altitudeMeters: (state.altitude ?? 0) > 0 ? state.altitude : null,
      waterType: state.waterType ?? WaterType.salt,
      salinityPpt: state.salinityPpt,
    ),
  );
}
