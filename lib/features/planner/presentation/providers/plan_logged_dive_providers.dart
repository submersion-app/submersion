import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What the planner shows for a logged dive picked in the series bar (issue
/// #3565): the plan it was dived from, if any, and what its safety review
/// found. The plan is the one the dive is linked to (#4058), computed the
/// same way as the dive log's planned-profile overlay and Compare, so all
/// three agree.

/// Whether a logged dive is shown in the planner in place of a planned one.
final viewingLoggedDiveProvider = Provider<bool>(
  (ref) => ref.watch(viewedLoggedDiveProvider) != null,
);

/// The plan the logged dive in view was dived from, computed; null when it
/// was never planned, or while that is still being looked up.
final viewedLoggedDivePlanProvider = Provider<LinkedPlanComparison?>((ref) {
  final logged = ref.watch(viewedLoggedDiveProvider);
  if (logged == null) return null;
  return ref.watch(linkedPlanComparisonProvider(logged.id)).value;
});

/// The range table of the plan [diveId] was dived from, computed in the
/// background like the editor's; null when it has no plan or nothing to
/// vary. It starts from a fresh diver, even for a later dive of a series.
final linkedPlanRangeTableProvider = FutureProvider.family<RangeTable?, String>(
  (ref, diveId) async {
    final comparison = await ref.watch(
      linkedPlanComparisonProvider(diveId).future,
    );
    if (comparison == null || comparison.plan.segments.isEmpty) return null;
    return ref
        .watch(planResultRunnerProvider)
        .run(
          computeRangeTable,
          comparison.plan,
          null,
          ref.watch(planEngineConfigProvider),
        );
  },
);

/// The safety review findings of the logged dive in view that the dive log
/// would show: none with the review off, and none from a rule the diver
/// turned off. Dismissed ones are left out of the count, as they are of the
/// dive's own.
final viewedLoggedDiveFindingsProvider = Provider<List<SafetyFinding>>((ref) {
  final logged = ref.watch(viewedLoggedDiveProvider);
  if (logged == null || !ref.watch(safetyReviewEnabledProvider)) {
    return const [];
  }
  final disabled = ref.watch(safetyReviewDisabledRulesProvider);
  final review = ref.watch(safetyReviewProvider(logged.id)).value;
  return [
    for (final finding in review?.activeFindings ?? const <SafetyFinding>[])
      if (!disabled.contains(finding.ruleId.dbValue)) finding,
  ];
});
