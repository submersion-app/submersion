import 'dart:math' as math;

import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One way home after a member's scooter dies on arrival at a waypoint:
/// the underwater swim or tow (retracing the route in an overhead, straight
/// home in open water), or in open water the surface exit.
///
/// The exit itself is evaluated by the scooter-free [ExitPathEvaluator];
/// this service adds what scooters bring: the tow speed and the battery.
class MissionScenarioService {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final BatteryBurnService battery;
  final ExitPathEvaluator exits;

  const MissionScenarioService({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
    this.exits = const ExitPathEvaluator(),
  });

  /// Speed through the water of a tow exit: the tower's tow speed, capped by
  /// every other running scooter's rated speed so the team stays together.
  double towSpeedMps({
    required DpvMission mission,
    required String failedMemberId,
    required String towerId,
  }) {
    var speed = double.infinity;
    for (final member in mission.team) {
      if (member.id == failedMemberId) continue;
      final own = member.id == towerId
          ? member.scooter.towSpeedMps
          : member.scooter.ratedSpeedMps;
      speed = math.min(speed, own);
    }
    return speed.isFinite ? speed : 0.0;
  }

  /// The swim or tow exit after [failedMemberId]'s scooter dies at waypoint
  /// [waypointIndex]. The surface exit is [evaluateSurface].
  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
  }) {
    if (mode == MissionExitMode.surface) {
      throw ArgumentError.value(
        mode,
        'mode',
        'the surface exit has its own evaluation',
      );
    }
    final exitSpeed = mode == MissionExitMode.swim
        ? slowestSwimSpeedMps(mission.team)
        : towSpeedMps(
            mission: mission,
            failedMemberId: failedMemberId,
            towerId: towerId!,
          );
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruiseSpeedMps(mission.team),
    );
    final failureRuntime = outbound.waypointArrivalSeconds[waypointIndex];
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: failureRuntime,
      exitLegs: exitLegsFor(mission, waypointIndex),
      exitSpeedMps: exitSpeed,
      divers: [
        for (final member in mission.team)
          ExitDiver(
            id: member.id,
            sacBottom: member.sacBottom,
            stressed: member.id == failedMemberId,
          ),
      ],
    );
    final tower = mode == MissionExitMode.tow ? towerId : null;
    if (result.blockedByCurrent) {
      return ExitOutcome(
        mode: mode,
        towerId: tower,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
        blockedByCurrent: true,
      );
    }

    final batteryShortfall = <String>{};
    for (final member in mission.team) {
      if (member.id == failedMemberId) continue;
      final tows = mode == MissionExitMode.tow && member.id == towerId;
      final powered =
          failureRuntime +
          (mode == MissionExitMode.tow && !tows ? result.exitBottomSeconds : 0);
      final fraction = battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds: powered,
        towingSeconds: tows ? result.exitBottomSeconds : 0,
      );
      if (!battery.withinReserve(
        burnFraction: fraction,
        reserveFraction: mission.batteryReserveFraction,
      )) {
        batteryShortfall.add(member.id);
      }
    }

    return ExitOutcome(
      mode: mode,
      towerId: tower,
      feasible:
          result.gasShortfallMemberIds.isEmpty && batteryShortfall.isEmpty,
      exitBottomSeconds: result.exitBottomSeconds,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      batteryShortfallMemberIds: batteryShortfall,
    );
  }

  /// Open water: ascend at waypoint [waypointIndex], then swim at the
  /// surface straight to the entry or to the waypoint's shore exit and walk.
  ///
  /// The ascent does not depend on whose scooter failed, so the result is
  /// shared by every member. Surface swimming is not charged gas and ignores
  /// current. The fastest surface route is chosen, among those within the
  /// mission's surface swim limit when one is set; when none is within it,
  /// the fastest route is reported and the exit is infeasible.
  ExitOutcome evaluateSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
  }) {
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruiseSpeedMps(mission.team),
    );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: outbound.waypointArrivalSeconds[waypointIndex],
      exitLegs: const [],
      exitSpeedMps: 0,
      divers: [
        for (final member in mission.team)
          ExitDiver(id: member.id, sacBottom: member.sacBottom),
      ],
    );

    final swimSpeed = slowestSwimSpeedMps(mission.team);
    if (swimSpeed <= 0) {
      throw ArgumentError.value(swimSpeed, 'swimSpeed', 'no surface swim');
    }
    final shore = mission.legs[waypointIndex].shoreExit;
    final routes = <({double swimM, double walkM, bool viaShore})>[
      (
        swimM: waypointPositions(mission.legs)[waypointIndex].distanceHomeM,
        walkM: 0.0,
        viaShore: false,
      ),
      // A walk needs a walking speed; a shore right at the entry does not.
      if (shore != null && (shore.walkM <= 0 || mission.walkSpeedMps > 0))
        (swimM: shore.surfaceSwimM, walkM: shore.walkM, viaShore: true),
    ];
    int seconds(({double swimM, double walkM, bool viaShore}) route) {
      final walk = route.walkM > 0 ? route.walkM / mission.walkSpeedMps : 0.0;
      return math.max(0, (route.swimM / swimSpeed + walk - 1e-6).ceil());
    }

    final limit = mission.surfaceSwimLimitM;
    final within = [
      for (final route in routes)
        if (limit == null || route.swimM <= limit) route,
    ];
    final pool = within.isEmpty ? routes : within;
    final chosen = pool.reduce((a, b) => seconds(b) < seconds(a) ? b : a);
    final exceeded = within.isEmpty;

    return ExitOutcome(
      mode: MissionExitMode.surface,
      feasible: result.gasShortfallMemberIds.isEmpty && !exceeded,
      exitBottomSeconds: 0,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      surfaceSeconds: seconds(chosen),
      surfaceSwimM: chosen.swimM,
      walkM: chosen.walkM,
      viaShore: chosen.viaShore,
      surfaceLimitExceeded: exceeded,
    );
  }

  /// In an overhead, seconds from waypoint [waypointIndex] to a safe surface
  /// with no failure: the way out at cruise plus the ascent.
  int overheadSafeSurfaceSeconds({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
  }) {
    final cruise = cruiseSpeedMps(mission.team);
    final outbound = builder.outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      speedMps: cruise,
    );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: outbound.segments,
      failureRuntimeSeconds: outbound.waypointArrivalSeconds[waypointIndex],
      exitLegs: retraceExitLegs(mission, waypointIndex),
      exitSpeedMps: cruise,
      divers: const [],
    );
    return result.exitBottomSeconds + result.ttsSeconds;
  }
}
