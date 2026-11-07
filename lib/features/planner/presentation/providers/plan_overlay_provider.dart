import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';

/// Seconds between points on a plan's chart line. The chart curves between
/// points, so a flat bottom held by two far-apart points would bow past the
/// depth the plan actually holds.
const int kPlannedOverlayStepSeconds = 10;

/// A dive's linked plan, run through the engine once: its outcome and its
/// chart line, so the ghost line and Compare's table cannot disagree.
class LinkedPlanComparison {
  const LinkedPlanComparison({
    required this.plan,
    required this.outcome,
    required this.overlay,
  });

  final domain.DivePlan plan;
  final PlanOutcome outcome;
  final ChartSourceOverlay overlay;
}

/// The plan linked to a dive, as it is saved now, computed: a dive of a
/// series after the first starts from what the dives before it were planned
/// to leave. Null when the dive has no linked plan.
///
/// Recomputes the plan through the same PlanEngine the canvas uses so the
/// result always reflects the plan's full computed schedule (segments + deco
/// ascent), not just the stored bottom segments.
final linkedPlanComparisonProvider = FutureProvider.autoDispose
    .family<LinkedPlanComparison?, String>((ref, diveId) async {
      retainDiveData(ref);
      final repository = ref.watch(divePlanRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchPlanChanges());

      final plan = await repository.getPlanByLinkedDiveId(diveId);
      if (plan == null) return null;

      final config = ref.watch(planEngineConfigProvider);
      final outcome =
          await _seriesOutcome(ref, plan, config) ??
          PlanEngine(config: config).compute(plan);
      return LinkedPlanComparison(
        plan: plan,
        outcome: outcome,
        overlay: buildPlannedOverlay(plan, config: config, outcome: outcome),
      );
    });

/// [plan]'s outcome as its series planned it (issue #3565): a later dive, or
/// one following a logged dive, starts from what the dives before it were
/// planned to leave, not a fresh diver. Planned, whatever was then dived,
/// since this is the plan. Null for a plan in no series, which starts fresh.
Future<PlanOutcome?> _seriesOutcome(
  Ref ref,
  domain.DivePlan plan,
  PlanEngineConfig config,
) async {
  final seriesRepository = ref.watch(divePlanSeriesRepositoryProvider);
  final seriesId = await seriesRepository.seriesIdForPlan(plan.id);
  if (seriesId == null) return null;
  final stored = await seriesRepository.getSeries(seriesId);
  final index =
      stored?.dives.indexWhere((dive) => dive.plan.id == plan.id) ?? -1;
  if (stored == null || index < 0) return null;
  final followedId = stored.followedDiveId;
  if (index == 0 && followedId == null) return null;
  final follow = followedId == null
      ? null
      : await ref.watch(seriesFollowProvider(followedId).future);
  final dives = seriesFromStored(
    stored,
    follow: follow,
    selectedIndex: index,
  ).dives;
  return computeSeries(
    dives.sublist(0, index + 1),
    config: config,
    follow: follow,
  )[index].outcome;
}

/// The planned profile for a dive with a linked plan, rendered as a chart
/// overlay next to the actual logged profile ("plan vs actual"). Null when
/// the dive has no linked plan.
final plannedProfileOverlayProvider = FutureProvider.autoDispose
    .family<ChartSourceOverlay?, String>((ref, diveId) async {
      retainDiveData(ref);
      final comparison = await ref.watch(
        linkedPlanComparisonProvider(diveId).future,
      );
      return comparison?.overlay;
    });

/// Pure mapping from a plan to its chart overlay (exposed for tests). Pass
/// [outcome] when the plan has already been computed.
ChartSourceOverlay buildPlannedOverlay(
  domain.DivePlan plan, {
  PlanEngineConfig config = const PlanEngineConfig(),
  PlanOutcome? outcome,
}) {
  final computed = outcome ?? PlanEngine(config: config).compute(plan);
  final series = buildCanvasSeries(
    plan: plan,
    outcome: computed,
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
    points: _denseProfile(series.profile),
  );
}

/// [profile] with points added along each leg, [kPlannedOverlayStepSeconds]
/// apart, keeping every corner.
List<DiveProfilePoint> _denseProfile(List<CanvasPoint> profile) {
  final points = <DiveProfilePoint>[];
  for (var i = 0; i < profile.length; i++) {
    final point = profile[i];
    points.add(
      DiveProfilePoint(
        timestamp: point.timeSeconds.round(),
        depth: point.depth,
      ),
    );
    if (i == profile.length - 1) break;
    final next = profile[i + 1];
    final span = next.timeSeconds - point.timeSeconds;
    for (
      var t = kPlannedOverlayStepSeconds.toDouble();
      // Stopping a second short keeps two points off one rounded timestamp.
      t < span - 1;
      t += kPlannedOverlayStepSeconds
    ) {
      points.add(
        DiveProfilePoint(
          timestamp: (point.timeSeconds + t).round(),
          depth: point.depth + (next.depth - point.depth) * (t / span),
        ),
      );
    }
  }
  return points;
}
