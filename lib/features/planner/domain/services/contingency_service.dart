import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';

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

/// The schedule that results from losing one deco/stage/travel cylinder.
class LostGasOutcome {
  final DiveTank tank;
  final domain.DivePlan plan;
  final PlanOutcome outcome;

  const LostGasOutcome({
    required this.tank,
    required this.plan,
    required this.outcome,
  });
}

/// Derives contingency variants of a plan and runs them through the
/// PlanEngine: the classic slate trio (+depth, +time, both) and one
/// lost-gas schedule per carried deco/stage/travel cylinder.
class ContingencyService {
  final PlanEngineConfig config;

  const ContingencyService({this.config = const PlanEngineConfig()});

  PlanEngine get _engine => PlanEngine(config: config);

  /// The three deviation keys, in slate order.
  static const deviationKeys = ['deeper', 'longer', 'both'];

  /// The deeper / longer / both variants that apply to [plan], in slate
  /// order: empty when the plan has no segments, and only 'deeper' when it
  /// has no bottom to lengthen (see [canLengthen]).
  ///
  /// Every method here takes the live plan's [startState] (a repetitive
  /// dive's residual tissue loading): a contingency is an alternative to the
  /// live plan, so it starts from the same tissues.
  List<DeviationOutcome> deviations(
    domain.DivePlan plan, {
    TissueState? startState,
  }) => [
    for (final key in deviationKeys)
      ?deviationFor(plan, key, startState: startState),
  ];

  /// Whether [plan] has a bottom a time delta can lengthen (see
  /// [SegmentChain.bottomLegIndex]). A plan with none, such as one linear
  /// descent that never holds at depth, gets no '+time' variant: it would
  /// equal the base plan, and 'both' would equal 'deeper' (#4849).
  bool canLengthen(domain.DivePlan plan) {
    final ordered = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    const chain = SegmentChain();
    return chain.bottomLegIndex(
          chain.resolve(ordered),
          descentRate: config.resolvedFor(plan).descentRate,
        ) !=
        null;
  }

  /// A single deviation variant by [key] ('deeper' | 'longer' | 'both'), or
  /// null when the plan has no segments, or when [key] adds time and the
  /// plan has no bottom to lengthen (see [canLengthen]). Lets callers (the
  /// chart ghost) run just the one variant the user selected instead of all
  /// three.
  DeviationOutcome? deviationFor(
    domain.DivePlan plan,
    String key, {
    TissueState? startState,
  }) {
    if (plan.segments.isEmpty) return null;
    if (key != 'deeper' && !canLengthen(plan)) return null;
    final variant = switch (key) {
      'deeper' => _deepened(plan),
      'longer' => _lengthened(plan),
      _ => _lengthened(_deepened(plan)),
    };
    return DeviationOutcome(
      key: key,
      plan: variant,
      outcome: _engine.compute(variant, startState: startState),
    );
  }

  /// Whether [tank] is eligible to be marked lost: a dedicated deco/stage
  /// cylinder, or any cylinder flagged as travel gas regardless of its role
  /// (a diluent, pony, or sidemount tank breathed on the descent is just as
  /// losable as a dedicated stage/deco bottle).
  ///
  /// Reads the *derived* role, so [tank] must come from a plan that has been
  /// through [TankRoleResolver]. Both callers below resolve first.
  bool isLosable(DiveTank tank) =>
      tank.role == TankRole.deco ||
      tank.role == TankRole.stage ||
      tank.isTravelGas;

  /// One outcome per losable cylinder (see [isLosable]). Empty for CCR plans
  /// (loop loss is the bailout solver's job) and when no such cylinder is
  /// carried.
  List<LostGasOutcome> lostGas(
    domain.DivePlan inputPlan, {
    TissueState? startState,
  }) {
    if (inputPlan.mode == domain.PlanMode.ccr || inputPlan.segments.isEmpty) {
      return const [];
    }
    // Losability is a question about derived roles (deco/stage), so resolve
    // before asking it.
    final plan = const TankRoleResolver().apply(inputPlan);
    final results = <LostGasOutcome>[];
    for (final tank in plan.tanks) {
      if (!isLosable(tank)) continue;
      final outcome = lostGasFor(plan, tank.id, startState: startState);
      if (outcome != null) results.add(outcome);
    }
    return results;
  }

  /// A single tank's lost-gas schedule by [tankId], or null when the tank is
  /// missing, not losable, the only cylinder carried, or the plan can't be
  /// varied (no segments, or CCR). Lets callers (the chart ghost, a tapped
  /// row) run just the one variant selected instead of the full set.
  LostGasOutcome? lostGasFor(
    domain.DivePlan inputPlan,
    String tankId, {
    TissueState? startState,
  }) {
    if (inputPlan.mode == domain.PlanMode.ccr || inputPlan.segments.isEmpty) {
      return null;
    }
    final plan = const TankRoleResolver().apply(inputPlan);
    DiveTank? tank;
    for (final t in plan.tanks) {
      if (t.id == tankId) {
        tank = t;
        break;
      }
    }
    if (tank == null || !isLosable(tank)) return null;
    final remaining = plan.tanks.where((t) => t.id != tankId).toList();
    // Nothing left to breathe — a lost-gas schedule would be meaningless.
    if (remaining.isEmpty) return null;
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
          segment.tankId == tankId
              ? segment.copyWith(tankId: fallback.id, gasMix: fallback.gasMix)
              : segment,
      ],
    );
    return LostGasOutcome(
      tank: tank,
      plan: without,
      outcome: _engine.compute(without, startState: startState),
    );
  }

  // Resolved against [plan] (issue #3552): this service's own [config] is
  // the app-wide one, not necessarily already resolvedFor this plan, unlike
  // PlanEngine/BailoutSolver's internal copy.
  domain.DivePlan _deepened(domain.DivePlan plan) {
    final resolved = config.resolvedFor(plan);
    return deviatePlan(
      plan,
      depthDelta: resolved.deviationDepthDelta,
      descentRate: resolved.descentRate,
    );
  }

  domain.DivePlan _lengthened(domain.DivePlan plan) {
    final resolved = config.resolvedFor(plan);
    return deviatePlan(
      plan,
      timeDeltaMinutes: resolved.deviationTimeMinutes,
      descentRate: resolved.descentRate,
    );
  }
}

/// A [plan] variant deviated by [depthDelta] meters and/or
/// [timeDeltaMinutes] minutes (either may be negative).
///
/// Targets equal to the plan's max depth shift by the delta — the bottom
/// moves, and the descent that feeds it follows because it targets the same
/// depth. The bottom leg grows (or shrinks) by the time delta. Shared by the
/// contingency trio and the range tables so every "what if" variant deviates
/// the same way.
///
/// [descentRate] is the plan's resolved descent rate, the one the engine
/// splits rate-split descents with (#4849). It decides whether such a
/// descent holds and so can be the bottom (see [SegmentChain.bottomLegIndex]),
/// and, because a descent authored shorter than its travel is stretched to
/// the travel time, the delta is added to that stretched duration rather
/// than to the authored one.
domain.DivePlan deviatePlan(
  domain.DivePlan plan, {
  required double descentRate,
  double depthDelta = 0,
  int timeDeltaMinutes = 0,
}) {
  var segments = plan.segments;

  if (depthDelta != 0) {
    final maxDepth = plan.maxDepth;
    // Only targets need shifting. The descent that feeds the bottom targets
    // max depth as well, and every other leg starts wherever its predecessor
    // now finishes.
    segments = [
      for (final segment in segments)
        (segment.targetDepth - maxDepth).abs() < 0.01
            ? segment.copyWith(targetDepth: segment.targetDepth + depthDelta)
            : segment,
    ];
  }

  if (timeDeltaMinutes != 0) {
    // The delta buys bottom time once, on the bottom leg (see
    // SegmentChain.bottomLegIndex), rather than once per level leg as the old
    // per-type loop did on a multi-level plan.
    final ordered = List<PlanSegment>.from(segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    const chain = SegmentChain();
    final legs = chain.resolve(ordered);
    final bottomIndex = chain.bottomLegIndex(legs, descentRate: descentRate);
    if (bottomIndex != null) {
      final bottom = legs[bottomIndex];
      final bottomId = bottom.segment.id;
      final travelSeconds = bottom.isDepthChange
          ? PlanSegment.travelSeconds(
              metres: bottom.endDepth - bottom.startDepth,
              ratePerMinute: descentRate,
            )
          : 0;
      final fromSeconds = math.max(bottom.durationSeconds, travelSeconds);
      final extraSeconds = timeDeltaMinutes * 60;
      segments = [
        for (final segment in segments)
          segment.id == bottomId
              ? segment.copyWith(durationSeconds: fromSeconds + extraSeconds)
              : segment,
      ];
    }
  }

  return plan.copyWith(segments: segments);
}
