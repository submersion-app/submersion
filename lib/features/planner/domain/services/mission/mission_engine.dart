import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_member_analysis.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';

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
    final issues = _validate(mission);
    if (issues.any((i) => i.severity == MissionIssueSeverity.blocking)) {
      return MissionOutcome.empty(issues: issues);
    }

    final team = mission.team;
    final cruise = cruiseSpeedMps(team);
    final limitingId = cruiseLimitingMemberId(team);

    // Resolve every leg at cruise and cut the route at the first one the
    // current makes untraversable in either direction.
    final legSpeeds = <LegSpeeds>[];
    for (final leg in mission.legs) {
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: cruise,
      );
      if (!resolved.traversable) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.untraversableLeg,
            severity: MissionIssueSeverity.blocking,
            legId: leg.id,
            outbound: !resolved.outboundTraversable,
          ),
        );
        break;
      }
      legSpeeds.add(resolved);
    }
    if (legSpeeds.isEmpty) return MissionOutcome.empty(issues: issues);
    final legs = mission.legs.sublist(0, legSpeeds.length);
    final route = mission.copyWith(legs: legs);

    final profile = builder.build(
      plan: plan,
      mission: route,
      throughLegIndex: legs.length - 1,
      outboundSpeedMps: cruise,
      exitSpeedMps: cruise,
    );
    if (profile.segments.isEmpty) return MissionOutcome.empty(issues: issues);

    final legOutcomes = _legOutcomes(legs, legSpeeds, profile);
    final roundTripSeconds = profile.segments.fold(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final returnSecondsFrom = analysis.returnSecondsFrom(legs, profile);
    final roundTripOutcome = scenarios.engine.compute(
      plan.copyWith(segments: profile.segments),
    );
    final environment = MissionScenarioService.environmentFor(plan);
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
      final members = <MemberWaypointOutcome>[];
      for (final member in team) {
        final swim = _evaluate(
          plan: plan,
          mission: route,
          k: k,
          member: member,
          mode: MissionExitMode.swim,
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
            survivable: swim.feasible || (best?.feasible ?? false),
          ),
        );
      }
      waypoints.add(
        WaypointOutcome(
          index: k,
          legId: legs[k].id,
          cumulativeDistanceM: cumulative,
          arrivalRuntimeSeconds: arrival,
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

  List<MissionIssue> _validate(DpvMission mission) {
    final issues = <MissionIssue>[];
    if (mission.team.isEmpty) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.emptyTeam,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    if (mission.legs.isEmpty) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.emptyRoute,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    for (final member in mission.team) {
      if (member.scooter.ratedSpeedMps <= 0 ||
          member.scooter.burnTimeSeconds <= 0) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.scooterUnspecified,
            severity: MissionIssueSeverity.blocking,
            memberId: member.id,
          ),
        );
      }
      if (member.sacBottom <= 0) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.memberSacUnset,
            severity: MissionIssueSeverity.blocking,
            memberId: member.id,
          ),
        );
      }
    }
    return issues;
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
      return ExitOutcome(
        mode: mode,
        towerId: towerId,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
      );
    }
  }

  /// Prefers a feasible tow, then the quicker one.
  ExitOutcome _betterTow(ExitOutcome? current, ExitOutcome candidate) {
    if (current == null) return candidate;
    if (candidate.feasible != current.feasible) {
      return candidate.feasible ? candidate : current;
    }
    return candidate.exitSeconds < current.exitSeconds ? candidate : current;
  }
}
