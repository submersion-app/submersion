import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One diver on an exit: their own bottom SAC, and whether they breathe the
/// plan's stressed SAC on the exit's bottom part (never less than their own).
class ExitDiver extends Equatable {
  final String id;
  final double sacBottom;
  final bool stressed;

  const ExitDiver({
    required this.id,
    required this.sacBottom,
    this.stressed = false,
  });

  @override
  List<Object?> get props => [id, sacBottom, stressed];
}

/// What one exit costs: time at depth, the ascent, and each diver's gas.
class ExitPathResult extends Equatable {
  /// Seconds from the failure point to the end of the exit legs.
  final int exitBottomSeconds;
  final int ttsSeconds;

  /// Surface litres each diver breathes from the failure point to the
  /// surface, by diver id.
  final Map<String, double> exitLitersByMember;

  /// Divers whose outbound plus exit gas leaves a tank below the plan's
  /// reserve.
  final Set<String> gasShortfallMemberIds;

  /// True when an exit leg cannot be travelled at the exit speed.
  final bool blockedByCurrent;

  /// True when the plan engine finds a critical limit broken on this exit
  /// (ppO2, hypoxic gas, gas density or CNS). Gas running out is not one of
  /// them: that is judged per diver here, not at the plan's single SAC.
  final bool notDiveable;

  const ExitPathResult({
    required this.exitBottomSeconds,
    required this.ttsSeconds,
    required this.exitLitersByMember,
    required this.gasShortfallMemberIds,
    required this.blockedByCurrent,
    this.notDiveable = false,
  });

  static const blocked = ExitPathResult(
    exitBottomSeconds: 0,
    ttsSeconds: 0,
    exitLitersByMember: {},
    gasShortfallMemberIds: {},
    blockedByCurrent: true,
  );

  @override
  List<Object?> get props => [
    exitBottomSeconds,
    ttsSeconds,
    exitLitersByMember,
    gasShortfallMemberIds,
    blockedByCurrent,
    notDiveable,
  ];
}

/// Evaluates a way out from a point on a dive: exit legs appended to the
/// outbound profile, the plan engine run once for the schedule and time to
/// surface, and each diver's gas charged from the schedule rows with their
/// own SAC.
///
/// Nothing here knows about scooters, so the overhead planner proposed in
/// #2164 and discussed in #2294 can use it for any exit (issue #2086).
class ExitPathEvaluator {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final MemberGasService gas;
  final LegSpeedResolver speeds;

  const ExitPathEvaluator({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.gas = const MemberGasService(),
    this.speeds = const LegSpeedResolver(),
  });

  ExitPathResult evaluate({
    required domain.DivePlan plan,
    required List<PlanSegment> outboundSegments,
    required int failureRuntimeSeconds,
    required List<ExitLeg> exitLegs,
    required double exitSpeedMps,
    required List<ExitDiver> divers,
  }) {
    for (final leg in exitLegs) {
      if (leg.distanceM < kMinExitLegM) continue;
      final resolved = speeds.resolveHeading(
        headingDeg: leg.headingDeg,
        current: leg.current,
        baseSpeedMps: exitSpeedMps,
      );
      if (!resolved.outboundTraversable) return ExitPathResult.blocked;
    }

    final segments = builder.appendExitLegs(
      plan: plan,
      segments: outboundSegments,
      exitLegs: exitLegs,
      exitSpeedMps: exitSpeedMps,
    );
    final outcome = engine.compute(plan.copyWith(segments: segments));
    final authoredRuntime = outcome.runtimeSeconds - outcome.ttsAtBottom;
    final exitBottomSeconds = math.max(
      0,
      authoredRuntime - failureRuntimeSeconds,
    );
    final environment = PlanEngine.environmentFor(plan);
    final outboundRows = outcome.schedule
        .where((r) => r.runtimeSeconds <= failureRuntimeSeconds)
        .toList();
    final exitRows = outcome.schedule
        .where((r) => r.runtimeSeconds > failureRuntimeSeconds)
        .toList();
    // The exit rows begin at the failure depth, not the surface.
    final failureDepth = outboundSegments.isEmpty
        ? 0.0
        : outboundSegments.last.targetDepth;
    // Deco breathing starts at the first computed stop; the ascent up to it
    // is still worked at the diver's own (or stressed) rate.
    final firstStopStart = [
      for (final row in exitRows)
        if (row.runtimeSeconds > authoredRuntime &&
            row.kind == PlanScheduleRowKind.stop)
          row.startRuntimeSeconds,
    ].firstOrNull;

    final liters = <String, double>{};
    final shortfall = <String>{};
    for (final diver in divers) {
      final outbound = gas.litersByTank(
        rows: outboundRows,
        environment: environment,
        sacFor: (_) => diver.sacBottom,
      );
      final exit = gas.litersByTank(
        rows: exitRows,
        environment: environment,
        startDepth: failureDepth,
        sacFor: (row) {
          if (firstStopStart != null &&
              row.startRuntimeSeconds >= firstStopStart) {
            return plan.sacDecoEffective;
          }
          return diver.stressed
              ? stressedSacFor(plan, diver.sacBottom)
              : diver.sacBottom;
        },
      );
      liters[diver.id] = exit.values.fold(0.0, (a, b) => a + b);
      if (_gasShort(plan, outbound, exit)) shortfall.add(diver.id);
    }

    return ExitPathResult(
      exitBottomSeconds: exitBottomSeconds,
      ttsSeconds: outcome.ttsAtBottom,
      exitLitersByMember: liters,
      gasShortfallMemberIds: shortfall,
      blockedByCurrent: false,
      notDiveable: breaksCriticalLimit(outcome),
    );
  }

  /// Whether [outcome] breaks a critical plan-engine limit other than gas
  /// running out: ppO2, hypoxic gas, gas density or CNS. Gas running out is
  /// judged per diver by this evaluator, not at the plan's single SAC.
  static bool breaksCriticalLimit(PlanOutcome outcome) {
    return outcome.issues.any(
      (i) =>
          i.severity == PlanIssueSeverity.critical &&
          i.type != PlanIssueType.gasOut,
    );
  }

  /// The SAC a diver breathes when stressed: their own bottom SAC scaled by
  /// the plan's stressed-to-bottom ratio, so a heavy breather is stressed in
  /// proportion. Never below their own SAC; a plan with no bottom SAC gives
  /// no ratio, so the diver keeps their own.
  static double stressedSacFor(domain.DivePlan plan, double sacBottom) {
    if (plan.sacBottom <= 0) {
      return math.max(plan.sacStressedEffective, sacBottom);
    }
    final factor = plan.sacStressedEffective / plan.sacBottom;
    return sacBottom * math.max(1.0, factor);
  }

  /// True when any tank the diver breathes, with a known size and fill,
  /// would end below the plan reserve after [outbound] plus [exit] litres.
  /// A cylinder never breathed, or a bailout cylinder, is not held to the
  /// reserve, matching the plan engine's own reserve rule.
  bool _gasShort(
    domain.DivePlan plan,
    Map<String, double> outbound,
    Map<String, double> exit,
  ) {
    for (final tank in plan.tanks) {
      if (tank.role == TankRole.bailout) continue;
      final used = (outbound[tank.id] ?? 0.0) + (exit[tank.id] ?? 0.0);
      if (used <= 0) continue;
      final remaining = gas.remainingBar(
        tank: tank,
        litersUsed: used,
        model: engine.config.gasModel,
      );
      if (remaining == null) continue;
      if (remaining < plan.reservePressure) return true;
    }
    return false;
  }
}
