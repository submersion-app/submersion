import 'dart:async';

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
