import 'dart:isolate';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// A background result and the plan it was computed for. A provider keeps its
/// previous value through a reload, which is what an edit to one plan wants
/// and what opening another plan must not show (see [planResultView]).
class PlanBackgroundResult<T> {
  const PlanBackgroundResult({required this.planId, required this.value});

  final String planId;
  final T value;
}

/// What a background result is doing, from the diver's point of view.
enum PlanResultStatus {
  /// The value describes the plan as it stands.
  current,

  /// The value is for an earlier revision; a newer result is on the way.
  updating,

  /// There is nothing to show yet; a result is on the way.
  calculating,

  /// The newest revision could not be computed.
  failed,
}

/// A background result as a section shows it.
class PlanResultView<T> {
  const PlanResultView({required this.value, required this.status});

  /// Null when there is nothing for this plan to show. Also null for a
  /// [PlanResultStatus.current] result that is itself null.
  final T? value;
  final PlanResultStatus status;

  /// Whether what is on screen must say it is not the current answer.
  bool get isMarked => status != PlanResultStatus.current;

  /// Whether the answer is in and there is nothing to show for it.
  bool get isFinishedEmpty =>
      status == PlanResultStatus.current && value == null;
}

/// Reads [result] for the plan [planId] that is open now. A value computed
/// for any other plan counts as no value at all, so another plan's figures
/// are never shown, not even dimmed.
///
/// Loading is checked before the error: a provider keeps a failure through a
/// reload, and a run already under way supersedes it.
PlanResultView<T> planResultView<T>(
  AsyncValue<PlanBackgroundResult<T>> result,
  String planId,
) {
  final held = result.value;
  final isForThisPlan = held != null && held.planId == planId;
  final value = isForThisPlan ? held.value : null;
  if (result.isLoading) {
    return PlanResultView(
      value: value,
      status: value != null
          ? PlanResultStatus.updating
          : PlanResultStatus.calculating,
    );
  }
  if (result.hasError) {
    return PlanResultView(value: value, status: PlanResultStatus.failed);
  }
  return PlanResultView(
    value: value,
    status: isForThisPlan
        ? PlanResultStatus.current
        : PlanResultStatus.calculating,
  );
}

/// The status of a section built from two results: the more severe of them.
PlanResultStatus combinePlanResultStatus(
  PlanResultStatus a,
  PlanResultStatus b,
) {
  const severest = [
    PlanResultStatus.failed,
    PlanResultStatus.calculating,
    PlanResultStatus.updating,
  ];
  for (final status in severest) {
    if (a == status || b == status) return status;
  }
  return PlanResultStatus.current;
}

/// One background calculation. Must be a top-level function or static method,
/// so that nothing but its arguments crosses to the isolate.
typedef PlanComputation<T> =
    T Function(
      domain.DivePlan plan,
      TissueState? startState,
      PlanEngineConfig config,
    );

/// Runs a [PlanComputation]. Injectable so tests can run it on the calling
/// isolate.
abstract interface class PlanResultRunner {
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  );
}

/// Runs each computation on its own background isolate. These are dozens of
/// full plan-engine runs, which would drop frames on the UI isolate; the
/// inputs are plain values, so they cross the isolate boundary by copy.
class IsolatePlanResultRunner implements PlanResultRunner {
  const IsolatePlanResultRunner();

  @override
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  ) {
    return Isolate.run(() => computation(plan, startState, config));
  }
}

final planResultRunnerProvider = Provider<PlanResultRunner>(
  (ref) => const IsolatePlanResultRunner(),
);

/// How long an edit must stand before background results are computed. A drag
/// is an edit per frame and a figure is typed a keystroke at a time, and an
/// isolate cannot be cancelled once started. Injectable so widget tests can
/// run with none.
final planResultsSettleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 150),
);
