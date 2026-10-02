import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_member_analysis.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_validator.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Computes a DPV mission: the round-trip segments, per-leg speeds, every
/// scooter failure at every waypoint, the abandonment point and the member
/// and factor that constrain the mission.
class MissionEngine {
  final MissionScenarioService scenarios;
  final MissionSegmentBuilder builder;
  final LegSpeedResolver speeds;
  final MemberGasService gas;
  final MissionMemberAnalysis analysis;

  const MissionEngine({
    this.scenarios = const MissionScenarioService(),
    this.builder = const MissionSegmentBuilder(),
    this.speeds = const LegSpeedResolver(),
    this.gas = const MemberGasService(),
    this.analysis = const MissionMemberAnalysis(),
  });

  MissionOutcome compute({
    required domain.DivePlan plan,
    required DpvMission mission,
  }) {
    final issues = [
      ...validateMission(mission),
      ...validatePlanForMission(plan),
    ];
    if (issues.any((i) => i.severity == MissionIssueSeverity.blocking)) {
      return MissionOutcome.empty(issues: issues);
    }

    final team = mission.team;
    final cruise = cruiseSpeedMps(team);
    final limitingId = cruiseLimitingMemberId(team);

    final (speeds: legSpeeds, :cut) = traversableRoute(mission);
    if (cut != null) issues.add(cut);
    if (legSpeeds.isEmpty) return MissionOutcome.empty(issues: issues);
    final legs = mission.legs.sublist(0, legSpeeds.length);
    final route = mission.copyWith(legs: legs);
    final positions = waypointPositions(legs);
    final openWater = route.environment == MissionEnvironment.openWater;

    final profile = builder.build(
      plan: plan,
      mission: route,
      throughLegIndex: legs.length - 1,
      outboundSpeedMps: cruise,
      exitSpeedMps: cruise,
    );
    if (profile.segments.isEmpty) {
      // The builder has no cylinder to breathe: nothing can be computed, and
      // an empty answer must not read as a mission with no problems.
      return MissionOutcome.empty(
        issues: [
          ...issues,
          const MissionIssue(
            type: MissionIssueType.planHasNoTank,
            severity: MissionIssueSeverity.blocking,
          ),
        ],
      );
    }

    final legOutcomes = _legOutcomes(legs, legSpeeds, profile);
    final roundTripSeconds = profile.segments.fold(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final returnSecondsFrom = analysis.returnSecondsFrom(legs, profile);
    final roundTripOutcome = scenarios.engine.compute(
      plan.copyWith(segments: profile.segments),
    );
    if (ExitPathEvaluator.breaksCriticalLimit(roundTripOutcome)) {
      // The planned route is unsafe before anything fails; no exit
      // analysis of it can be trusted.
      return MissionOutcome.empty(
        issues: [
          ...issues,
          const MissionIssue(
            type: MissionIssueType.planNotDiveable,
            severity: MissionIssueSeverity.blocking,
          ),
        ],
      );
    }
    final environment = PlanEngine.environmentFor(plan);
    final bottomTank = plan.tanks.firstWhere(
      (t) => t.id == profile.segments.first.tankId,
    );

    final waypoints = <WaypointOutcome>[];
    var cumulative = 0.0;
    for (var k = 0; k < legs.length; k++) {
      cumulative += legs[k].distanceM;
      final arrival = profile.waypointArrivalSeconds[k];
      final outboundRows = roundTripOutcome.schedule
          .where((r) => r.runtimeSeconds <= arrival)
          .toList();
      // One outbound profile per waypoint, shared by every scenario there.
      final outbound = builder.outbound(
        plan: plan,
        mission: route,
        throughLegIndex: k,
        speedMps: cruise,
      );
      final overheadSafeSurface = openWater
          ? null
          : _overheadSafeSurface(
              plan: plan,
              mission: route,
              k: k,
              outbound: outbound,
              issues: issues,
            );
      final members = <MemberWaypointOutcome>[];
      for (final member in team) {
        // Per failed member: the ascent is the same, but the diver whose
        // scooter died breathes their stressed SAC up to the first stop.
        final surface = openWater
            ? _evaluateSurface(
                plan: plan,
                mission: route,
                k: k,
                failedMemberId: member.id,
                outbound: outbound,
                issues: issues,
              )
            : null;
        final swim = _evaluate(
          plan: plan,
          mission: route,
          k: k,
          member: member,
          mode: MissionExitMode.swim,
          outbound: outbound,
          issues: issues,
        );
        ExitOutcome? best;
        for (final tower in team) {
          if (tower.id == member.id) continue;
          final tow = _evaluate(
            plan: plan,
            mission: route,
            k: k,
            member: member,
            mode: MissionExitMode.tow,
            towerId: tower.id,
            outbound: outbound,
            issues: issues,
          );
          best = _betterTow(best, tow);
        }
        final outboundLiters = gas.litersByTank(
          rows: outboundRows,
          environment: environment,
          sacFor: (_) => member.sacBottom,
        );
        members.add(
          MemberWaypointOutcome(
            memberId: member.id,
            gasRemainingBar: gas.remainingBar(
              tank: bottomTank,
              litersUsed: outboundLiters[bottomTank.id] ?? 0.0,
              model: scenarios.engine.config.gasModel,
            ),
            swim: swim,
            tow: best,
            surface: surface,
            survivable:
                swim.feasible ||
                (best?.feasible ?? false) ||
                (surface?.feasible ?? false),
          ),
        );
      }
      // In open water the safe surface is the ascent alone, which does not
      // depend on whose scooter failed.
      final safeSurfaceSeconds = openWater
          // A failed surface run knows no ascent time, so it has none to
          // give; its zero must not read as a safe surface reached at once.
          ? members.map((m) => m.surface?.knownTtsSeconds).nonNulls.firstOrNull
          : overheadSafeSurface;
      waypoints.add(
        WaypointOutcome(
          index: k,
          legId: legs[k].id,
          cumulativeDistanceM: cumulative,
          arrivalRuntimeSeconds: arrival,
          directDistanceHomeM: positions[k].distanceHomeM,
          safeSurfaceSeconds: safeSurfaceSeconds,
          members: members,
          survivable: members.every((m) => m.survivable),
        ),
      );
    }

    int? abandonment;
    for (var k = 0; k < waypoints.length; k++) {
      if (!waypoints[k].survivable) break;
      abandonment = k;
    }

    final memberOutcomes = [
      for (final member in team)
        analysis.memberOutcome(
          member: member,
          mission: route,
          waypoints: waypoints,
          abandonment: abandonment,
          roundTripSeconds: roundTripSeconds,
          returnSecondsFrom: returnSecondsFrom,
          setsCruise: member.id == limitingId,
          bottomTank: bottomTank,
          reserveBar: plan.reservePressure,
          gasModel: scenarios.engine.config.gasModel,
        ),
    ];

    return MissionOutcome(
      segments: profile.segments,
      cruiseSpeedMps: cruise,
      legs: legOutcomes,
      waypoints: waypoints,
      members: memberOutcomes,
      abandonmentIndex: abandonment,
      constraint: analysis.constraint(memberOutcomes),
      issues: issues,
    );
  }

  /// The planned round trip at cruise as the plan's segments: the outbound
  /// legs up to the first one the current makes untraversable, then the same
  /// way back. Empty when the mission has a blocking validation issue or no
  /// leg can be travelled, so a half-built mission never feeds the plan
  /// engine nonsense. For a mission [compute] accepts, this is its outcome's
  /// `segments`.
  List<PlanSegment> roundTripSegments({
    required domain.DivePlan plan,
    required DpvMission mission,
  }) {
    final blocked = validateMission(
      mission,
    ).any((i) => i.severity == MissionIssueSeverity.blocking);
    if (blocked) return const [];
    final cruise = cruiseSpeedMps(mission.team);
    final route = traversableRoute(mission).speeds;
    if (route.isEmpty) return const [];
    final traversable = mission.legs.sublist(0, route.length);
    return builder
        .build(
          plan: plan,
          mission: mission.copyWith(legs: traversable),
          throughLegIndex: traversable.length - 1,
          outboundSpeedMps: cruise,
          exitSpeedMps: cruise,
        )
        .segments;
  }

  /// Every leg resolved at the team's cruise speed, up to the first one the
  /// current makes untraversable in either direction, and the issue naming
  /// that leg (null when the whole route can be travelled). [speeds] holds
  /// one entry per leg kept, in route order.
  ({List<LegSpeeds> speeds, MissionIssue? cut}) traversableRoute(
    DpvMission mission,
  ) {
    final cruise = cruiseSpeedMps(mission.team);
    final kept = <LegSpeeds>[];
    for (final leg in mission.legs) {
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: cruise,
      );
      if (!resolved.traversable) {
        return (
          speeds: kept,
          cut: MissionIssue(
            type: MissionIssueType.untraversableLeg,
            severity: MissionIssueSeverity.blocking,
            legId: leg.id,
            outbound: !resolved.outboundTraversable,
          ),
        );
      }
      kept.add(resolved);
    }
    return (speeds: kept, cut: null);
  }

  List<LegOutcome> _legOutcomes(
    List<MissionLeg> legs,
    List<LegSpeeds> legSpeeds,
    MissionProfile profile,
  ) {
    int seconds(String id) =>
        profile.segments.firstWhere((s) => s.id == id).durationSeconds;
    return [
      for (var i = 0; i < legs.length; i++)
        LegOutcome(
          legId: legs[i].id,
          outboundSpeedMps: legSpeeds[i].outboundMps,
          returnSpeedMps: legSpeeds[i].returnMps,
          outboundSeconds: seconds('mission-out-${legs[i].id}'),
          returnSeconds: seconds('mission-ret-${legs[i].id}'),
        ),
    ];
  }

  ExitOutcome _evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
    required MissionMember member,
    required MissionExitMode mode,
    String? towerId,
    required MissionProfile outbound,
    required List<MissionIssue> issues,
  }) {
    try {
      return scenarios.evaluate(
        plan: plan,
        mission: mission,
        waypointIndex: k,
        failedMemberId: member.id,
        mode: mode,
        towerId: towerId,
        outbound: outbound,
      );
    } on Object {
      // One scenario the engine cannot schedule must not hide the others;
      // report it and treat the exit as unavailable.
      issues.add(
        MissionIssue(
          type: MissionIssueType.scenarioFailed,
          severity: MissionIssueSeverity.warning,
          legId: mission.legs[k].id,
          memberId: member.id,
        ),
      );
      return ExitOutcome.failed(mode: mode, towerId: towerId);
    }
  }

  /// The open-water surface exit at waypoint [k] after [failedMemberId]'s
  /// scooter dies; a failed, infeasible exit (with a warning) when it cannot
  /// be run, so the binding factor does not blame the current for it.
  ExitOutcome _evaluateSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
    required String failedMemberId,
    required MissionProfile outbound,
    required List<MissionIssue> issues,
  }) {
    try {
      return scenarios.evaluateSurface(
        plan: plan,
        mission: mission,
        waypointIndex: k,
        failedMemberId: failedMemberId,
        outbound: outbound,
      );
    } on Object {
      issues.add(
        MissionIssue(
          type: MissionIssueType.scenarioFailed,
          severity: MissionIssueSeverity.warning,
          legId: mission.legs[k].id,
          memberId: failedMemberId,
        ),
      );
      return const ExitOutcome.failed(mode: MissionExitMode.surface);
    }
  }

  /// The overhead time to a safe surface from waypoint [k], or null (with a
  /// warning) when it cannot be computed.
  int? _overheadSafeSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int k,
    required MissionProfile outbound,
    required List<MissionIssue> issues,
  }) {
    try {
      return scenarios.overheadSafeSurfaceSeconds(
        plan: plan,
        mission: mission,
        waypointIndex: k,
        outbound: outbound,
      );
    } on Object {
      issues.add(
        MissionIssue(
          type: MissionIssueType.scenarioFailed,
          severity: MissionIssueSeverity.warning,
          legId: mission.legs[k].id,
        ),
      );
      return null;
    }
  }

  /// Prefers a feasible tow; then one that was computed over one whose
  /// computation threw; then one that made headway over one the current
  /// blocked. A failed or blocked tow reports no time, so either would
  /// otherwise win on time and hide why the tow that ran failed. Then the
  /// quicker one.
  ExitOutcome _betterTow(ExitOutcome? current, ExitOutcome candidate) {
    if (current == null) return candidate;
    if (candidate.feasible != current.feasible) {
      return candidate.feasible ? candidate : current;
    }
    if (candidate.failed != current.failed) {
      return candidate.failed ? current : candidate;
    }
    if (candidate.blockedByCurrent != current.blockedByCurrent) {
      return candidate.blockedByCurrent ? current : candidate;
    }
    final candidateSeconds = candidate.knownExitSeconds;
    final currentSeconds = current.knownExitSeconds;
    // Both failed: neither has a time to compare, so the first stands.
    if (candidateSeconds == null || currentSeconds == null) return current;
    return candidateSeconds < currentSeconds ? candidate : current;
  }
}
