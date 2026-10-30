import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';

/// Runs a plan computation on the calling isolate. A real isolate never
/// completes under `testWidgets`' fake clock.
class InlinePlanResultRunner implements PlanResultRunner {
  const InlinePlanResultRunner();

  @override
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  ) async {
    return computation(plan, startState, config);
  }
}

/// Overrides for any test that mounts the results sheet, the canvas or the
/// chart mode toggle: no settle, so no timer is left pending, and no isolate.
List<dynamic> plannerResultsInline() => [
  planResultsSettleDelayProvider.overrideWithValue(Duration.zero),
  planResultRunnerProvider.overrideWithValue(const InlinePlanResultRunner()),
];
