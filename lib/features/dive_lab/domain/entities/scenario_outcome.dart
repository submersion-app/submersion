import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

enum ScenarioFlagKind {
  sacEstimated,
  pressureEstimated,
  pressureUnknown,
  tankVolumeAssumed,
  noBottomRemaining,
  replanNotCompletable,
  loopGasMissing,
}

class ScenarioFlag extends Equatable {
  const ScenarioFlag(this.kind, {this.tankId});
  final ScenarioFlagKind kind;
  final String? tankId;
  @override
  List<Object?> get props => [kind, tankId];
}

/// Everything the engine computed for one scenario.
class ScenarioOutcome {
  const ScenarioOutcome({
    required this.branch,
    required this.mode,
    required this.actual,
    required this.counterfactual,
    required this.counterfactualDepths,
    required this.counterfactualTimestamps,
    required this.counterfactualGasSegments,
    required this.planOutcome,
    required this.compiledPlan,
    required this.consumption,
    required this.deltas,
    required this.verdictDeltas,
    required this.flags,
  });

  final BranchState branch;
  final ScenarioMode mode;
  final ProfileAnalysis actual;
  final ProfileAnalysis counterfactual;
  final List<double> counterfactualDepths;
  final List<int> counterfactualTimestamps;
  final List<ProfileGasSegment> counterfactualGasSegments;
  final PlanOutcome? planOutcome;
  final domain.DivePlan? compiledPlan;
  final ScenarioConsumption consumption;
  final List<ScenarioDelta> deltas;
  final List<ScenarioDelta> verdictDeltas;
  final List<ScenarioFlag> flags;
}
