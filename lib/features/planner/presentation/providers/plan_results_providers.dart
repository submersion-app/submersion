import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart'
    show DivePlanState;
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

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

const _log = LoggerService('PlanResults');

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
  try {
    final value = await runner.run(computation, plan, startState, config);
    return PlanBackgroundResult(planId: plan.id, value: value);
  } catch (e, st) {
    _log.error('Could not compute a plan result', error: e, stackTrace: st);
    rethrow;
  }
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
    FutureProvider<PlanBackgroundResult<BailoutOutcome?>>((ref) {
      if (ref.watch(planMayHaveBailoutProvider)) {
        return _settled(ref, computeBailout);
      }
      final planId = ref.watch(divePlanNotifierProvider.select((s) => s.id));
      return PlanBackgroundResult(planId: planId, value: null);
    }, retry: (_, _) => null);

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

/// What the chart does about the bailout picture: [picture] to draw in place
/// of the live plan, if any, and [status] to say on the chart, if any. Both
/// are null outside [ChartDisplayMode.bailout].
///
/// A pending result keeps the last picture, because it clears in moments. A
/// failed one does not: nothing replaces it until the next edit, and a full
/// bailout curve reads as current in a way dimmed text does not. The gate is
/// read first, so removing the last bailout tank drops the picture that frame.
final planChartBailoutProvider =
    Provider<({BailoutOutcome? picture, PlanResultStatus? status})>((ref) {
      const nothing = (picture: null, status: null);
      if (ref.watch(chartDisplayModeProvider) != ChartDisplayMode.bailout) {
        return nothing;
      }
      if (!ref.watch(planMayHaveBailoutProvider)) return nothing;
      final view = planResultView(
        ref.watch(planBailoutProvider),
        ref.watch(divePlanNotifierProvider.select((s) => s.id)),
      );
      final picture = view.value;
      return switch (view.status) {
        PlanResultStatus.current => (picture: picture, status: null),
        PlanResultStatus.updating => (
          picture: picture,
          status: PlanResultStatus.updating,
        ),
        PlanResultStatus.calculating => (
          picture: null,
          status: PlanResultStatus.calculating,
        ),
        PlanResultStatus.failed => (
          picture: null,
          status: PlanResultStatus.failed,
        ),
      };
    });

/// What the chart draws: [planLiveCanvasSeriesProvider], or in
/// [ChartDisplayMode.bailout] the worst-case bailout picture while there is
/// one to draw.
final planCanvasSeriesProvider = Provider<PlanCanvasSeries>((ref) {
  final picture = ref.watch(planChartBailoutProvider).picture;
  if (picture != null) return buildBailoutCanvasSeries(picture);
  return ref.watch(planLiveCanvasSeriesProvider);
});

/// Everything computed that a slate prints, all for one revision of the plan.
/// Awaited, never read as it stands, so a slate cannot carry figures for an
/// older revision. A failure throws: no slate is better than one with a
/// section silently missing.
///
/// Awaited in turn, and each future taken only when its turn comes, so that a
/// later result failing first is not an error nobody is listening to.
///
/// [read] must outlive the widget that asked: the diver can leave the canvas
/// during the wait, so it comes from the container, not a `WidgetRef`.
Future<
  ({
    DivePlanState state,
    PlanOutcome outcome,
    List<DeviationOutcome> deviations,
    List<LostGasOutcome> lostGas,
    RangeTable? rangeTable,
    BailoutOutcome? bailout,
  })
>
planSlateResults(T Function<T>(ProviderListenable<T> provider) read) async {
  // An edit during the wait can land after some of these resolved, so go
  // round again until all of them are for the plan as it stands.
  while (true) {
    final asked = _engineInputs(read(divePlanNotifierProvider));
    // Reading each one starts it, so any nothing is watching run side by side
    // rather than settling one after another below.
    read(planDeviationsProvider);
    read(planLostGasProvider);
    read(planRangeTableProvider);
    read(planBailoutProvider);
    final deviations = await read(planDeviationsProvider.future);
    final lostGas = await read(planLostGasProvider.future);
    final rangeTable = await read(planRangeTableProvider.future);
    final bailout = await read(planBailoutProvider.future);
    final state = read(divePlanNotifierProvider);
    if (_engineInputs(state) != asked) continue;
    return (
      state: state,
      outcome: read(planOutcomeProvider),
      deviations: deviations.value,
      lostGas: lostGas.value,
      rangeTable: rangeTable.value,
      bailout: bailout.value,
    );
  }
}
