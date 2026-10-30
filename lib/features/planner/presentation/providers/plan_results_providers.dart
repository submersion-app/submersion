import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart'
    show DivePlanState;
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart'
    show contingenciesExpandedProvider, planEngineConfigProvider;

/// The classic slate range table for [plan]; null when there is nothing to
/// vary. Runs on a background isolate, so it reads nothing but its arguments.
RangeTable? computeRangeTable(
  domain.DivePlan plan,
  TissueState? startState,
  PlanEngineConfig config,
) {
  final table = RangeTableService(
    config: config,
  ).compute(plan, startState: startState);
  return table.isEmpty ? null : table;
}

/// Worst-case bailout for [plan]; null when it has none to compute.
BailoutOutcome? computeBailout(
  domain.DivePlan plan,
  TissueState? startState,
  PlanEngineConfig config,
) {
  return BailoutSolver(config: config).solve(plan, startState: startState);
}

/// Deviation (deeper/longer/both) outcomes for [plan].
List<DeviationOutcome> computeDeviations(
  domain.DivePlan plan,
  TissueState? startState,
  PlanEngineConfig config,
) {
  return ContingencyService(
    config: config,
  ).deviations(plan, startState: startState);
}

/// Lost-gas outcomes for [plan].
List<LostGasOutcome> computeLostGas(
  domain.DivePlan plan,
  TissueState? startState,
  PlanEngineConfig config,
) {
  return ContingencyService(
    config: config,
  ).lostGas(plan, startState: startState);
}

/// Thrown by a computation that a newer edit replaced while it settled.
/// Nothing ever sees it: Riverpod drops what a replaced build produces.
class _Superseded implements Exception {
  const _Superseded();
}

/// What a background result depends on in the plan state. The tissue seed is
/// selected by its raw fields, not as a seeded [TissueState], which has no
/// value equality.
(domain.DivePlan, List<TissueCompartment>?, Duration?) _engineInputs(
  DivePlanState s,
) => (planForEngine(s), s.initialTissueState, s.surfaceInterval);

/// Runs [computation] for the plan once its latest edit has settled.
/// Recomputed when an input the engine reads changes; Riverpod drops the
/// result of a computation superseded by a newer edit, so a stale result is
/// never delivered as current. [computation] is a top-level function, so
/// nothing of this provider's reaches the isolate.
Future<PlanBackgroundResult<T>> _settled<T>(
  Ref ref,
  PlanComputation<T> computation,
) async {
  final (plan, _, _) = ref.watch(
    divePlanNotifierProvider.select(_engineInputs),
  );
  final config = ref.watch(planEngineConfigProvider);
  final runner = ref.watch(planResultRunnerProvider);
  final settle = ref.watch(planResultsSettleDelayProvider);
  final startState = startStateForPlan(
    ref.read(divePlanNotifierProvider),
    config: config,
  );
  if (settle > Duration.zero) {
    await Future<void>.delayed(settle);
    if (!ref.mounted) throw const _Superseded();
  }
  final value = await runner.run(computation, plan, startState, config);
  return PlanBackgroundResult(planId: plan.id, value: value);
}

/// Whether the current plan may have a bailout picture, for anything that
/// must hold its place while [planBailoutProvider] computes.
final planMayHaveBailoutProvider = Provider<bool>((ref) {
  return ref.watch(
    divePlanNotifierProvider.select(
      (s) => planMayHaveBailout(divePlanFromState(s)),
    ),
  );
});

/// Worst-case bailout for the current loop plan. Off the UI isolate: this is
/// a full open-circuit schedule at every sampled point of the plan.
final planBailoutProvider =
    FutureProvider<PlanBackgroundResult<BailoutOutcome?>>(
      (ref) => _settled(ref, computeBailout),
      retry: (_, _) => null,
    );

/// The classic slate range table (depth x time variants) for the current
/// plan. Off the UI isolate: this is 25 engine runs.
final planRangeTableProvider =
    FutureProvider<PlanBackgroundResult<RangeTable?>>(
      (ref) => _settled(ref, computeRangeTable),
      retry: (_, _) => null,
    );

/// Deviation (deeper/longer/both) outcomes for the current plan. The full
/// deviation + lost-gas tables (3 engine runs + one per deco/stage tank) are
/// only computed while [contingenciesExpandedProvider] is true, so a collapsed
/// sheet costs nothing.
final planDeviationsProvider =
    FutureProvider<PlanBackgroundResult<List<DeviationOutcome>>>((ref) {
      if (ref.watch(contingenciesExpandedProvider)) {
        return _settled(ref, computeDeviations);
      }
      final planId = ref.watch(divePlanNotifierProvider.select((s) => s.id));
      return PlanBackgroundResult(planId: planId, value: const []);
    }, retry: (_, _) => null);

/// Lost-gas outcomes for the current OC plan, gated as
/// [planDeviationsProvider] is.
final planLostGasProvider =
    FutureProvider<PlanBackgroundResult<List<LostGasOutcome>>>((ref) {
      if (ref.watch(contingenciesExpandedProvider)) {
        return _settled(ref, computeLostGas);
      }
      final planId = ref.watch(divePlanNotifierProvider.select((s) => s.id));
      return PlanBackgroundResult(planId: planId, value: const []);
    }, retry: (_, _) => null);
