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

/// A surface route home: metres swum at [mps] over the ground, then walked.
typedef _SurfaceRoute = ({
  double swimM,
  double walkM,
  bool viaShore,
  double mps,
});

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

  const MissionScenarioService({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
  });

  /// The exit evaluator, built on this service's own engine and builder so
  /// the engine a caller injects (the diver's ppO2, END and gas-model
  /// settings) reaches every exit, not only the planned round trip.
  ExitPathEvaluator get exits => ExitPathEvaluator(
    engine: engine,
    builder: builder,
    speeds: builder.speeds,
  );

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
    MissionProfile? outbound,
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
    final out =
        outbound ??
        builder.outbound(
          plan: plan,
          mission: mission,
          throughLegIndex: waypointIndex,
          speedMps: cruiseSpeedMps(mission.team),
        );
    final failureRuntime = out.waypointArrivalSeconds[waypointIndex];
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: out.segments,
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
          result.gasShortfallMemberIds.isEmpty &&
          batteryShortfall.isEmpty &&
          !result.notDiveable,
      exitBottomSeconds: result.exitBottomSeconds,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      batteryShortfallMemberIds: batteryShortfall,
      notDiveable: result.notDiveable,
    );
  }

  /// Open water: ascend at waypoint [waypointIndex], then swim at the
  /// surface straight to the entry or to the waypoint's shore exit and walk.
  ///
  /// The ascent itself does not depend on whose scooter failed, but its gas
  /// does: [failedMemberId], when given, breathes their stressed SAC up to
  /// the first stop. Surface swimming is not charged gas. It does
  /// feel the current: the swim home takes the same current as the straight
  /// underwater leg home, resolved as speed over ground, and a shore route,
  /// whose bearing is unknown, takes the worst the current can do. A route
  /// that makes no headway is closed; when every route is closed the exit is
  /// blocked by current. Otherwise the fastest open route is chosen, among
  /// those within the mission's surface swim limit when one is set; when
  /// none is within it, the fastest route is reported and the exit is
  /// infeasible.
  ExitOutcome evaluateSurface({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    String? failedMemberId,
    MissionProfile? outbound,
  }) {
    final out =
        outbound ??
        builder.outbound(
          plan: plan,
          mission: mission,
          throughLegIndex: waypointIndex,
          speedMps: cruiseSpeedMps(mission.team),
        );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: out.segments,
      failureRuntimeSeconds: out.waypointArrivalSeconds[waypointIndex],
      exitLegs: const [],
      exitSpeedMps: 0,
      divers: [
        for (final member in mission.team)
          ExitDiver(
            id: member.id,
            sacBottom: member.sacBottom,
            stressed: member.id == failedMemberId,
          ),
      ],
    );

    final swimSpeed = slowestSwimSpeedMps(mission.team);
    if (swimSpeed <= 0) {
      throw ArgumentError.value(swimSpeed, 'swimSpeed', 'no surface swim');
    }
    final leg = mission.legs[waypointIndex];
    final home = waypointPositions(mission.legs)[waypointIndex];
    final current = mission.currentFor(leg);
    final homeMps = home.distanceHomeM < kMinExitLegM
        ? swimSpeed
        : builder.speeds
              .resolveHeading(
                headingDeg: home.bearingHomeDeg,
                current: current,
                baseSpeedMps: swimSpeed,
              )
              .outboundMps;
    // A shore route has no bearing, so it takes the worst the current can do.
    final shoreMps = swimSpeed - (current?.speedMps ?? 0.0);
    final shore = leg.shoreExit;
    final routes = <_SurfaceRoute>[
      (swimM: home.distanceHomeM, walkM: 0.0, viaShore: false, mps: homeMps),
      // A walk needs a walking speed; a shore right at the entry does not.
      if (shore != null && (shore.walkM <= 0 || mission.walkSpeedMps > 0))
        (
          swimM: shore.surfaceSwimM,
          walkM: shore.walkM,
          viaShore: true,
          mps: shoreMps,
        ),
    ];
    final open = [
      for (final route in routes)
        if (route.swimM < kMinExitLegM || route.mps > 0) route,
    ];
    if (open.isEmpty) {
      return ExitOutcome(
        mode: MissionExitMode.surface,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: result.ttsSeconds,
        exitLitersByMember: result.exitLitersByMember,
        gasShortfallMemberIds: result.gasShortfallMemberIds,
        blockedByCurrent: true,
      );
    }
    int seconds(_SurfaceRoute route) {
      final swim = route.swimM < kMinExitLegM ? 0.0 : route.swimM / route.mps;
      final walk = route.walkM > 0 ? route.walkM / mission.walkSpeedMps : 0.0;
      return math.max(0, (swim + walk - 1e-6).ceil());
    }

    final limit = mission.surfaceSwimLimitM;
    final within = [
      for (final route in open)
        if (limit == null || route.swimM <= limit) route,
    ];
    final pool = within.isEmpty ? open : within;
    final chosen = pool.reduce((a, b) => seconds(b) < seconds(a) ? b : a);
    final exceeded = within.isEmpty;

    return ExitOutcome(
      mode: MissionExitMode.surface,
      feasible:
          result.gasShortfallMemberIds.isEmpty &&
          !exceeded &&
          !result.notDiveable,
      exitBottomSeconds: 0,
      ttsSeconds: result.ttsSeconds,
      exitLitersByMember: result.exitLitersByMember,
      gasShortfallMemberIds: result.gasShortfallMemberIds,
      surfaceSeconds: seconds(chosen),
      surfaceSwimM: chosen.swimM,
      walkM: chosen.walkM,
      viaShore: chosen.viaShore,
      surfaceLimitExceeded: exceeded,
      notDiveable: result.notDiveable,
    );
  }

  /// In an overhead, seconds from waypoint [waypointIndex] to a safe surface
  /// with no failure: the way out at cruise plus the ascent.
  int overheadSafeSurfaceSeconds({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    MissionProfile? outbound,
  }) {
    final cruise = cruiseSpeedMps(mission.team);
    final out =
        outbound ??
        builder.outbound(
          plan: plan,
          mission: mission,
          throughLegIndex: waypointIndex,
          speedMps: cruise,
        );
    final result = exits.evaluate(
      plan: plan,
      outboundSegments: out.segments,
      failureRuntimeSeconds: out.waypointArrivalSeconds[waypointIndex],
      exitLegs: retraceExitLegs(mission, waypointIndex),
      exitSpeedMps: cruise,
      divers: const [],
    );
    return result.exitBottomSeconds + result.ttsSeconds;
  }
}
