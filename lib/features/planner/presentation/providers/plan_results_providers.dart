import 'dart:async';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
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

/// Everything a background result depends on, in one place: what the plan
/// state gives the engine, and the diver's settings. The tissue seed is held
/// by its raw compartments, not as a seeded [TissueState], which has no value
/// equality; the plan carries the surface interval it off-gasses over.
typedef _PlanResultInputs = ({
  domain.DivePlan plan,
  List<TissueCompartment>? seed,
  DiveEnvironment? seedEnvironment,
  PlanEngineConfig config,
});

/// Selected here once, rather than by each result, because the select rebuilds
/// and compares the plan on every edit.
final _planResultInputsProvider = Provider<_PlanResultInputs>((ref) {
  final (plan, seed, seedEnvironment) = ref.watch(
    divePlanNotifierProvider.select(
      (s) =>
          (planForEngine(s), s.initialTissueState, s.initialTissueEnvironment),
    ),
  );
  return (
    plan: plan,
    seed: seed,
    seedEnvironment: seedEnvironment,
    config: ref.watch(planEngineConfigProvider),
  );
});

/// Completes once [delay] has passed with this computation still wanted. A
/// newer edit cancels it, so the computation goes no further and leaves nothing
/// to fire.
Future<void> _settle(Ref ref, Duration delay) {
  final settled = Completer<void>();
  ref.onDispose(Timer(delay, settled.complete).cancel);
  return settled.future;
}

/// Runs [computation] for the plan once its latest edit has settled.
/// Recomputed when an input the engine reads changes; Riverpod drops the
/// result of a computation superseded by a newer edit, so a stale result is
/// never delivered as current. [computation] is a top-level function, so
/// nothing of this provider's reaches the isolate.
Future<PlanBackgroundResult<T>> _settled<T>(
  Ref ref,
  PlanComputation<T> computation,
) async {
  final inputs = ref.watch(_planResultInputsProvider);
  final runner = ref.watch(planResultRunnerProvider);
  final settle = ref.watch(planResultsSettleDelayProvider);
  if (settle > Duration.zero) await _settle(ref, settle);
  final startState = startStateForPlan(
    ref.read(divePlanNotifierProvider),
    config: inputs.config,
  );
  try {
    final value = await runner.run(
      computation,
      inputs.plan,
      startState,
      inputs.config,
    );
    return PlanBackgroundResult(planId: inputs.plan.id, value: value);
  } catch (e, st) {
    _log.error('Could not compute a plan result', error: e, stackTrace: st);
    rethrow;
  }
}

/// A background result that needs no calculating: what [_settled] would come
/// to, for a plan that has nothing to compute.
PlanBackgroundResult<T> _nothingToCompute<T>(Ref ref, T value) {
  final planId = ref.watch(divePlanNotifierProvider.select((s) => s.id));
  return PlanBackgroundResult(planId: planId, value: value);
}

bool _hasSegments(Ref ref) =>
    ref.watch(divePlanNotifierProvider.select((s) => s.segments.isNotEmpty));

/// Whether the current plan may have a bailout picture, for anything that
/// must hold its place while [planBailoutProvider] computes.
final planMayHaveBailoutProvider = Provider<bool>((ref) {
  return ref.watch(
    _planResultInputsProvider.select((i) => planMayHaveBailout(i.plan)),
  );
});

/// Worst-case bailout for the current loop plan. Off the UI isolate: this is
/// a full open-circuit schedule at every sampled point of the plan.
final planBailoutProvider =
    FutureProvider<PlanBackgroundResult<BailoutOutcome?>>((ref) {
      if (ref.watch(planMayHaveBailoutProvider)) {
        return _settled(ref, computeBailout);
      }
      return _nothingToCompute(ref, null);
    }, retry: (_, _) => null);

/// The classic slate range table (depth x time variants) for the current
/// plan. Off the UI isolate: this is 25 engine runs.
final planRangeTableProvider =
    FutureProvider<PlanBackgroundResult<RangeTable?>>((ref) {
      if (_hasSegments(ref)) return _settled(ref, computeRangeTable);
      return _nothingToCompute(ref, null);
    }, retry: (_, _) => null);

/// Deviation (deeper/longer/both) outcomes for the current plan. The full
/// deviation + lost-gas tables (3 engine runs + one per deco/stage tank) are
/// only computed while [contingenciesExpandedProvider] is true, so a collapsed
/// sheet costs nothing.
final planDeviationsProvider =
    FutureProvider<PlanBackgroundResult<List<DeviationOutcome>>>((ref) {
      if (ref.watch(contingenciesExpandedProvider) && _hasSegments(ref)) {
        return _settled(ref, computeDeviations);
      }
      return _nothingToCompute(ref, const []);
    }, retry: (_, _) => null);

/// Lost-gas outcomes for the current OC plan, gated as
/// [planDeviationsProvider] is.
final planLostGasProvider =
    FutureProvider<PlanBackgroundResult<List<LostGasOutcome>>>((ref) {
      if (ref.watch(contingenciesExpandedProvider) && _hasSegments(ref)) {
        return _settled(ref, computeLostGas);
      }
      return _nothingToCompute(ref, const []);
    }, retry: (_, _) => null);

/// What the chart does about the bailout picture: [picture] to draw in place
/// of the live plan, if any, and [status] and [gasGap] to say on the chart, if
/// any. All are null outside [ChartDisplayMode.bailout].
///
/// A pending result keeps the last picture, because it clears in moments. A
/// failed one does not: nothing replaces it until the next edit, and a full
/// bailout curve reads as current in a way dimmed text does not. A gas gap
/// has no picture either, since the curve would be an ascent no carried gas
/// can make (#3961). The gate is read first, so removing the last bailout
/// tank drops the picture that frame.
final planChartBailoutProvider =
    Provider<
      ({
        BailoutOutcome? picture,
        PlanResultStatus? status,
        BailoutGasGap? gasGap,
      })
    >((ref) {
      const nothing = (picture: null, status: null, gasGap: null);
      if (ref.watch(chartDisplayModeProvider) != ChartDisplayMode.bailout) {
        return nothing;
      }
      if (!ref.watch(planMayHaveBailoutProvider)) return nothing;
      final view = planResultView(
        ref.watch(planBailoutProvider),
        ref.watch(divePlanNotifierProvider.select((s) => s.id)),
      );
      final outcome = view.status == PlanResultStatus.failed
          ? null
          : view.value;
      return (
        picture: outcome?.gasGap == null ? outcome : null,
        status: view.isMarked ? view.status : null,
        gasGap: outcome?.gasGap,
      );
    });

/// What the chart draws: [planLiveCanvasSeriesProvider], or in
/// [ChartDisplayMode.bailout] the worst-case bailout picture while there is
/// one to draw.
final planCanvasSeriesProvider = Provider<PlanCanvasSeries>((ref) {
  final picture = ref.watch(planChartBailoutProvider.select((c) => c.picture));
  if (picture != null) return buildBailoutCanvasSeries(picture);
  return ref.watch(planLiveCanvasSeriesProvider);
});

/// Everything computed that a slate prints, all for one revision of the plan.
/// Awaited, never read as it stands, so a slate cannot carry figures for an
/// older revision. A failure throws: no slate is better than one with a
/// section silently missing.
///
/// Listened to for as long as the wait lasts: all of them start together
/// whether or not anything is watching them, and an edit reruns them. With
/// nothing listening, an edit drops the running build without starting a new
/// one, and a future awaited on it never completes.
///
/// Awaited in turn, and each future taken only when its turn comes, so that a
/// later result failing first is not an error nobody is listening to.
///
/// [container] rather than a `WidgetRef`, which ends if the diver leaves the
/// canvas during the wait.
///
/// Null when another plan has taken this one's place by the time the results
/// land: leaving a replan resets the planner, and these providers only ever
/// answer for the plan that is open, so the slate asked for is out of reach.
Future<
  ({
    DivePlanState state,
    PlanOutcome outcome,
    List<DeviationOutcome> deviations,
    List<LostGasOutcome> lostGas,
    RangeTable? rangeTable,
    BailoutOutcome? bailout,
  })?
>
planSlateResults(ProviderContainer container) async {
  final planId = container.read(divePlanNotifierProvider).id;
  final listeners = [
    container.listen(planDeviationsProvider, (_, _) {}),
    container.listen(planLostGasProvider, (_, _) {}),
    container.listen(planRangeTableProvider, (_, _) {}),
    container.listen(planBailoutProvider, (_, _) {}),
  ];
  // Everything these results depend on. Any of it can change during the wait,
  // after some have resolved, so go round again until all of them agree.
  (_PlanResultInputs, bool) inputs() => (
    container.read(_planResultInputsProvider),
    container.read(contingenciesExpandedProvider),
  );
  try {
    while (true) {
      final asked = inputs();
      final deviations = await container.read(planDeviationsProvider.future);
      final lostGas = await container.read(planLostGasProvider.future);
      final rangeTable = await container.read(planRangeTableProvider.future);
      final bailout = await container.read(planBailoutProvider.future);
      if (container.read(divePlanNotifierProvider).id != planId) return null;
      if (inputs() != asked) continue;
      return (
        state: container.read(divePlanNotifierProvider),
        outcome: container.read(planOutcomeProvider),
        deviations: deviations.value,
        lostGas: lostGas.value,
        rangeTable: rangeTable.value,
        bailout: bailout.value,
      );
    }
  } finally {
    for (final listener in listeners) {
      listener.close();
    }
  }
}
