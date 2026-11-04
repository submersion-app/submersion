import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';

/// The worst-case bailout point as the chart marks it (issue #4211): the
/// instant of a loop plan at which an open-circuit bailout needs the most
/// gas, with the figures its card shows.
class PlanChartWorstCase {
  const PlanChartWorstCase({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.ttsSeconds,
    required this.litersRequired,
    required this.availableLiters,
    required this.sufficient,
    required this.stale,
  });

  final int runtimeSeconds;
  final double depthMeters;

  /// Time to surface from this instant on the bailout gases.
  final int ttsSeconds;
  final double litersRequired;
  final double availableLiters;

  /// Whether the carried bailout gas covers this worst case.
  final bool sufficient;

  /// Whether this comes from an earlier revision of the plan while a newer
  /// result is on the way: still marked, but dimmed.
  final bool stale;

  PlanChartWorstCase copyWith({
    int? runtimeSeconds,
    double? depthMeters,
    int? ttsSeconds,
    double? litersRequired,
    double? availableLiters,
    bool? sufficient,
    bool? stale,
  }) => PlanChartWorstCase(
    runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
    depthMeters: depthMeters ?? this.depthMeters,
    ttsSeconds: ttsSeconds ?? this.ttsSeconds,
    litersRequired: litersRequired ?? this.litersRequired,
    availableLiters: availableLiters ?? this.availableLiters,
    sufficient: sufficient ?? this.sufficient,
    stale: stale ?? this.stale,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanChartWorstCase &&
      other.runtimeSeconds == runtimeSeconds &&
      other.depthMeters == depthMeters &&
      other.ttsSeconds == ttsSeconds &&
      other.litersRequired == litersRequired &&
      other.availableLiters == availableLiters &&
      other.sufficient == sufficient &&
      other.stale == stale;

  @override
  int get hashCode => Object.hash(
    runtimeSeconds,
    depthMeters,
    ttsSeconds,
    litersRequired,
    availableLiters,
    sufficient,
    stale,
  );
}

/// The worst case to mark for [view], or null when there is none to mark: no
/// value, a failed run (an older value would read as current), or a gas gap,
/// whose figures were sized on a gas past its MOD and are no bailout plan
/// (#3961).
PlanChartWorstCase? chartWorstCaseFrom(PlanResultView<BailoutOutcome?> view) {
  if (view.status == PlanResultStatus.failed) return null;
  final outcome = view.value;
  if (outcome == null || outcome.gasGap != null) return null;
  final worst = outcome.worstCase;
  return PlanChartWorstCase(
    runtimeSeconds: worst.runtimeSeconds,
    depthMeters: worst.depthMeters,
    ttsSeconds: worst.ttsSeconds,
    litersRequired: worst.litersRequired,
    availableLiters: outcome.availableLiters,
    sufficient: outcome.sufficient,
    stale: view.isMarked,
  );
}

/// The worst-case bailout point the chart marks, in the CCR view and the
/// Bailout view alike, since both show the same instant. The gate is read
/// first, so removing the last bailout cylinder drops the marker that frame.
final planChartWorstCaseProvider = Provider<PlanChartWorstCase?>((ref) {
  if (!ref.watch(planMayHaveBailoutProvider)) return null;
  return chartWorstCaseFrom(
    planResultView(
      ref.watch(planBailoutProvider),
      ref.watch(divePlanNotifierProvider.select((s) => s.id)),
    ),
  );
});
