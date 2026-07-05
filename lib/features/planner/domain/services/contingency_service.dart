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

  /// The deeper / longer / both variants (empty when the plan has no
  /// segments).
  List<DeviationOutcome> deviations(domain.DivePlan plan) {
    if (plan.segments.isEmpty) return const [];
    final deeper = _deepened(plan);
    final longer = _lengthened(plan);
    final both = _lengthened(deeper);
    return [
      DeviationOutcome(
        key: 'deeper',
        plan: deeper,
        outcome: _engine.compute(deeper),
      ),
      DeviationOutcome(
        key: 'longer',
        plan: longer,
        outcome: _engine.compute(longer),
      ),
      DeviationOutcome(key: 'both', plan: both, outcome: _engine.compute(both)),
    ];
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
      final without = plan.copyWith(
        tanks: plan.tanks.where((t) => t.id != tank.id).toList(),
      );
      results.add(
        LostGasOutcome(tank: tank, outcome: _engine.compute(without)),
      );
    }
    return results;
  }

  /// Depths equal to the plan's max depth grow by the deviation delta —
  /// the bottom deepens and the descent that feeds it follows.
  domain.DivePlan _deepened(domain.DivePlan plan) {
    final maxDepth = plan.maxDepth;
    final delta = plan.deviationDepthDelta;
    PlanSegment deepen(PlanSegment segment) {
      var changed = segment;
      if ((segment.startDepth - maxDepth).abs() < 0.01) {
        changed = changed.copyWith(startDepth: segment.startDepth + delta);
      }
      if ((segment.endDepth - maxDepth).abs() < 0.01) {
        changed = changed.copyWith(endDepth: segment.endDepth + delta);
      }
      return changed;
    }

    return plan.copyWith(segments: plan.segments.map(deepen).toList());
  }

  /// Bottom segments grow by the deviation minutes.
  domain.DivePlan _lengthened(domain.DivePlan plan) {
    final extraSeconds = plan.deviationTimeMinutes * 60;
    return plan.copyWith(
      segments: [
        for (final segment in plan.segments)
          segment.type == SegmentType.bottom
              ? segment.copyWith(
                  durationSeconds: segment.durationSeconds + extraSeconds,
                )
              : segment,
      ],
    );
  }
}
