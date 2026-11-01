import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';

/// The planned profile for a dive created via convert-to-dive, rendered as
/// a chart overlay next to the actual logged profile ("plan vs actual").
///
/// Recomputes the plan through the same PlanEngine the canvas uses so the
/// ghost line always reflects the plan's full computed schedule (segments +
/// deco ascent), not just the stored bottom segments. Null when the dive
/// was not created from a plan.
final plannedProfileOverlayProvider =
    FutureProvider.family<ChartSourceOverlay?, String>((ref, diveId) async {
      final repository = ref.watch(divePlanRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchPlanChanges());

      final plan = await repository.getPlanByLinkedDiveId(diveId);
      if (plan == null) return null;

      final config = ref.watch(planEngineConfigProvider);
      final seriesId = plan.seriesId;
      if (seriesId == null) return buildPlannedOverlay(plan, config: config);

      // A later dive's plan starts with what the dives before it left: as
      // planned, whatever was then dived, since this is the plan.
      final stored = await ref
          .watch(divePlanSeriesRepositoryProvider)
          .getSeries(seriesId);
      final index =
          stored?.dives.indexWhere((dive) => dive.plan.id == plan.id) ?? -1;
      if (stored == null || index < 0) {
        return buildPlannedOverlay(plan, config: config);
      }
      final followedId = stored.followedDiveId;
      final follow = followedId == null
          ? null
          : await ref.watch(seriesFollowProvider(followedId).future);
      final result = computeSeries(
        seriesFromStored(stored, follow: follow, selectedIndex: index).dives,
        config: config,
        follow: follow,
      )[index];
      return buildPlannedOverlay(plan, config: config, outcome: result.outcome);
    });

/// Pure mapping from a plan to its chart overlay (exposed for tests).
ChartSourceOverlay buildPlannedOverlay(
  domain.DivePlan plan, {
  PlanEngineConfig config = const PlanEngineConfig(),
  PlanOutcome? outcome,
}) {
  outcome ??= PlanEngine(config: config).compute(plan);
  final series = buildCanvasSeries(
    plan: plan,
    outcome: outcome,
    config: config,
  );

  return ChartSourceOverlay(
    sourceId: 'plan:${plan.id}',
    name: plan.name,
    color: Colors.purple,
    // A plan is not another computer's reading of the same dive, so it keeps
    // its own identity colour rather than a tint of each metric's colour.
    tintByMetric: false,
    computerId: null,
    points: [
      for (final point in series.profile)
        DiveProfilePoint(
          timestamp: point.timeSeconds.round(),
          depth: point.depth,
        ),
    ],
  );
}
