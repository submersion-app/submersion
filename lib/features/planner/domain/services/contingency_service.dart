import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// A "what if it goes deeper/longer" variant of the base plan.
class DeviationOutcome {
  /// 'deeper' | 'longer' | 'both'
  final String key;
  final domain.DivePlan plan;
  final PlanOutcome outcome;

  const DeviationOutcome({
    required this.key,
    required this.plan,
    required this.outcome,
  });
}

/// The schedule that results from losing one deco/stage cylinder.
class LostGasOutcome {
  final DiveTank tank;
  final PlanOutcome outcome;

  const LostGasOutcome({required this.tank, required this.outcome});
}

/// Derives contingency variants of a plan and runs them through the
/// PlanEngine: the classic slate trio (+depth, +time, both) and one
/// lost-gas schedule per carried deco/stage cylinder.
class ContingencyService {
  final PlanEngineConfig config;

  const ContingencyService({this.config = const PlanEngineConfig()});

  PlanEngine get _engine => PlanEngine(config: config);

  /// The three deviation keys, in slate order.
  static const deviationKeys = ['deeper', 'longer', 'both'];

  /// The deeper / longer / both variants (empty when the plan has no
  /// segments).
  List<DeviationOutcome> deviations(domain.DivePlan plan) {
    if (plan.segments.isEmpty) return const [];
    return [for (final key in deviationKeys) deviationFor(plan, key)!];
  }

  /// A single deviation variant by [key] ('deeper' | 'longer' | 'both'), or
  /// null when the plan has no segments. Lets callers (the chart ghost) run
  /// just the one variant the user selected instead of all three.
  DeviationOutcome? deviationFor(domain.DivePlan plan, String key) {
    if (plan.segments.isEmpty) return null;
    final variant = switch (key) {
      'deeper' => _deepened(plan),
      'longer' => _lengthened(plan),
      _ => _lengthened(_deepened(plan)),
    };
    return DeviationOutcome(
      key: key,
      plan: variant,
      outcome: _engine.compute(variant),
    );
  }

  /// One outcome per lost deco/stage cylinder. Empty for CCR plans (loop
  /// loss is the bailout solver's job) and when no such cylinder is carried.
  List<LostGasOutcome> lostGas(domain.DivePlan plan) {
    if (plan.mode == domain.PlanMode.ccr || plan.segments.isEmpty) {
      return const [];
    }
    final results = <LostGasOutcome>[];
    for (final tank in plan.tanks) {
      if (tank.role != TankRole.deco && tank.role != TankRole.stage) continue;
      final remaining = plan.tanks.where((t) => t.id != tank.id).toList();
      // Nothing left to breathe — a lost-gas schedule would be meaningless.
      if (remaining.isEmpty) continue;
      // Any user segment that breathed the lost cylinder is remapped onto a
      // fallback (prefer back gas). Without this the contingency would still
      // "breathe" the lost gas and its consumption would go unaccounted, since
      // the engine only reports usage for tanks present in plan.tanks.
      final fallback = remaining.firstWhere(
        (t) => t.role == TankRole.backGas,
        orElse: () => remaining.first,
      );
      final without = plan.copyWith(
        tanks: remaining,
        segments: [
          for (final segment in plan.segments)
            segment.tankId == tank.id
                ? segment.copyWith(tankId: fallback.id, gasMix: fallback.gasMix)
                : segment,
        ],
      );
      results.add(
        LostGasOutcome(tank: tank, outcome: _engine.compute(without)),
      );
    }
    return results;
  }

  domain.DivePlan _deepened(domain.DivePlan plan) =>
      deviatePlan(plan, depthDelta: plan.deviationDepthDelta);

  domain.DivePlan _lengthened(domain.DivePlan plan) =>
      deviatePlan(plan, timeDeltaMinutes: plan.deviationTimeMinutes);
}

/// A [plan] variant deviated by [depthDelta] meters and/or
/// [timeDeltaMinutes] minutes (either may be negative).
///
/// Depths equal to the plan's max depth shift by the delta — the bottom
/// moves and the descent that feeds it follows. Bottom segments grow (or
/// shrink) by the time delta. Shared by the contingency trio and the range
/// tables so every "what if" variant deviates the same way.
domain.DivePlan deviatePlan(
  domain.DivePlan plan, {
  double depthDelta = 0,
  int timeDeltaMinutes = 0,
}) {
  var segments = plan.segments;

  if (depthDelta != 0) {
    final maxDepth = plan.maxDepth;
    PlanSegment shift(PlanSegment segment) {
      var changed = segment;
      if ((segment.startDepth - maxDepth).abs() < 0.01) {
        changed = changed.copyWith(startDepth: segment.startDepth + depthDelta);
      }
      if ((segment.endDepth - maxDepth).abs() < 0.01) {
        changed = changed.copyWith(endDepth: segment.endDepth + depthDelta);
      }
      return changed;
    }

    segments = segments.map(shift).toList();
  }

  if (timeDeltaMinutes != 0) {
    final extraSeconds = timeDeltaMinutes * 60;
    segments = [
      for (final segment in segments)
        segment.type == SegmentType.bottom
            ? segment.copyWith(
                durationSeconds: segment.durationSeconds + extraSeconds,
              )
            : segment,
    ];
  }

  return plan.copyWith(segments: segments);
}
