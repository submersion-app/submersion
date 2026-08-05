import 'package:flutter/material.dart';

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
      return buildPlannedOverlay(plan, config: config);
    });

/// Pure mapping from a plan to its chart overlay (exposed for tests).
ChartSourceOverlay buildPlannedOverlay(
  domain.DivePlan plan, {
  PlanEngineConfig config = const PlanEngineConfig(),
}) {
  final outcome = PlanEngine(config: config).compute(plan);
  final series = buildCanvasSeries(segments: plan.segments, outcome: outcome);

  return ChartSourceOverlay(
    sourceId: 'plan:${plan.id}',
    name: plan.name,
    color: Colors.purple,
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
