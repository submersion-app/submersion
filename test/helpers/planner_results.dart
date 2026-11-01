import 'dart:async';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';

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

/// Counts each computation's runs, on the calling isolate.
class CountingPlanResultRunner extends InlinePlanResultRunner {
  final runs = <Object>[];

  int runsOf(Object computation) =>
      runs.where((run) => run == computation).length;

  @override
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  ) {
    runs.add(computation);
    return super.run(computation, plan, startState, config);
  }
}

/// One run held by [HeldPlanResultRunner].
class HeldPlanRun {
  HeldPlanRun(this.computation, this.plan, this.finish, this.fail);

  /// Which calculation this is, to pick one out of several held together.
  final Object computation;
  final domain.DivePlan plan;

  /// Computes the result and delivers it.
  final void Function() finish;

  /// Delivers [error] in place of a result.
  final void Function(Object error) fail;
}

/// Holds every run until the test finishes or fails it, to freeze a result
/// mid-flight.
class HeldPlanResultRunner implements PlanResultRunner {
  final held = <HeldPlanRun>[];

  /// The latest run of [computation].
  HeldPlanRun latest(Object computation) =>
      held.lastWhere((run) => run.computation == computation);

  @override
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  ) {
    final completer = Completer<T>();
    held.add(
      HeldPlanRun(
        computation,
        plan,
        () => completer.complete(computation(plan, startState, config)),
        completer.completeError,
      ),
    );
    return completer.future;
  }
}

/// Overrides for any test that mounts the results sheet, the canvas or the
/// chart mode toggle: no settle, so no timer is left pending, and no isolate.
List<dynamic> plannerResultsInline() => [
  planResultsSettleDelayProvider.overrideWithValue(Duration.zero),
  planResultRunnerProvider.overrideWithValue(const InlinePlanResultRunner()),
];

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);
const _o2 = GasMix(o2: 100);
const plannerTrimix = GasMix(o2: 18, he: 45);

List<PlanSegment> _profile(double depth, int minutes, String tank, GasMix mix) {
  return [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: tank,
      gasMix: mix,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: tank,
      gasMix: mix,
      order: 1,
    ),
  ];
}

domain.DivePlan _plan({
  required String id,
  required List<DiveTank> tanks,
  required List<PlanSegment> segments,
  domain.PlanMode mode = domain.PlanMode.oc,
}) => domain.DivePlan(
  id: id,
  name: id,
  mode: mode,
  gfLow: 40,
  gfHigh: 80,
  tanks: tanks,
  segments: segments,
  createdAt: DateTime(2026, 10, 30),
  updatedAt: DateTime(2026, 10, 30),
);

domain.DivePlan ordinaryOcPlan() => _plan(
  id: 'oc',
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _air),
  ],
  segments: _profile(40, 20, 'back', _air),
);

domain.DivePlan multiGasDecoPlan() => _plan(
  id: 'deco',
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: plannerTrimix),
    DiveTank(
      id: 'stage',
      volume: 11.1,
      startPressure: 207,
      gasMix: _ean50,
      role: TankRole.deco,
    ),
    DiveTank(
      id: 'oxygen',
      volume: 7,
      startPressure: 207,
      gasMix: _o2,
      role: TankRole.deco,
    ),
  ],
  segments: _profile(60, 25, 'back', plannerTrimix),
);

domain.DivePlan ccrWithBailoutPlan() => _plan(
  id: 'ccr',
  mode: domain.PlanMode.ccr,
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: plannerTrimix,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'o2',
      volume: 3,
      startPressure: 200,
      gasMix: _o2,
      role: TankRole.oxygenSupply,
    ),
    DiveTank(
      id: 'bo',
      volume: 11.1,
      startPressure: 207,
      gasMix: plannerTrimix,
      role: TankRole.bailout,
    ),
  ],
  segments: _profile(60, 25, 'dil', plannerTrimix),
);

/// Opens [plan] in the planner.
void loadPlan(ProviderContainer container, domain.DivePlan plan) {
  container
      .read(divePlanNotifierProvider.notifier)
      .loadPlan(stateFromDivePlan(plan));
}

/// Keeps all four background results alive, as a mounted sheet does.
void listenToAllPlanResults(ProviderContainer container) {
  container.listen(planRangeTableProvider, (_, _) {});
  container.listen(planBailoutProvider, (_, _) {});
  container.listen(planDeviationsProvider, (_, _) {});
  container.listen(planLostGasProvider, (_, _) {});
}

/// Changes how long the 'bottom' segment of one of the plans above lasts.
void editBottomTime(ProviderContainer container, int seconds) {
  final state = container.read(divePlanNotifierProvider);
  final bottom = state.segments.firstWhere((s) => s.id == 'bottom');
  container
      .read(divePlanNotifierProvider.notifier)
      .updateSegment(bottom.id, bottom.copyWith(durationSeconds: seconds));
}
