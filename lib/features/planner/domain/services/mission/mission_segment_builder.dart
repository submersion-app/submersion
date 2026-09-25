import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

/// The segments a route produces, with the run time at which each outbound
/// waypoint is reached.
class MissionProfile extends Equatable {
  final List<PlanSegment> segments;

  /// Elapsed seconds on arrival at waypoint k (the end of outbound leg k).
  final List<int> waypointArrivalSeconds;

  const MissionProfile({
    required this.segments,
    required this.waypointArrivalSeconds,
  });

  @override
  List<Object?> get props => [segments, waypointArrivalSeconds];
}

/// Turns a mission route into the bottom segments of a plan.
///
/// Each leg becomes a hold at its depth for `distance / speed over ground`,
/// and a depth change between legs becomes an explicit travel segment
/// first. The segment chain resolves a hold whose depth differs from the
/// previous one as a travel leg spanning its WHOLE duration, so the travel
/// must be authored separately or the leg would be integrated as a slow
/// descent. The engine's own ascent takes over after the last segment.
class MissionSegmentBuilder {
  final LegSpeedResolver speeds;

  const MissionSegmentBuilder({this.speeds = const LegSpeedResolver()});

  /// The planned round trip: outbound legs 0 through [throughLegIndex] at
  /// [outboundSpeedMps], then the same legs retraced at [exitSpeedMps]. An
  /// empty profile when the plan has no tank to breathe.
  MissionProfile build({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double outboundSpeedMps,
    required double exitSpeedMps,
  }) {
    final out = outbound(
      plan: plan,
      mission: mission,
      throughLegIndex: throughLegIndex,
      speedMps: outboundSpeedMps,
    );
    if (out.segments.isEmpty) return out;
    final last = math.min(throughLegIndex, mission.legs.length - 1);
    return MissionProfile(
      segments: appendExitLegs(
        plan: plan,
        segments: out.segments,
        exitLegs: retraceExitLegs(mission, last),
        exitSpeedMps: exitSpeedMps,
      ),
      waypointArrivalSeconds: out.waypointArrivalSeconds,
    );
  }

  /// Outbound legs 0 through [throughLegIndex] at [speedMps] through the
  /// water, each in its own current.
  MissionProfile outbound({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int throughLegIndex,
    required double speedMps,
  }) {
    final tank = _bottomTank(plan);
    if (tank == null || mission.legs.isEmpty) {
      return const MissionProfile(segments: [], waypointArrivalSeconds: []);
    }
    final last = math.min(throughLegIndex, mission.legs.length - 1);
    final segments = <PlanSegment>[];
    final arrivals = <int>[];
    var runtime = 0;
    var depth = 0.0;
    for (final leg in mission.legs.sublist(0, last + 1)) {
      if (leg.depthM != depth) {
        final travel = _travel(
          plan,
          tank,
          'mission-out-travel-${leg.id}',
          depth,
          leg.depthM,
          segments.length,
        );
        segments.add(travel);
        runtime += travel.durationSeconds;
        depth = leg.depthM;
      }
      final speed = speeds
          .resolve(
            leg: leg,
            current: mission.currentFor(leg),
            baseSpeedMps: speedMps,
          )
          .outboundMps;
      final hold = _hold(
        tank,
        'mission-out-${leg.id}',
        depth,
        leg.distanceM,
        speed,
        segments.length,
      );
      segments.add(hold);
      runtime += hold.durationSeconds;
      arrivals.add(runtime);
    }
    return MissionProfile(segments: segments, waypointArrivalSeconds: arrivals);
  }

  /// [segments] followed by [exitLegs] travelled at [exitSpeedMps] through
  /// the water, each on its own heading in its own current. Legs shorter
  /// than [kMinExitLegM] are skipped. Returns a new list.
  List<PlanSegment> appendExitLegs({
    required domain.DivePlan plan,
    required List<PlanSegment> segments,
    required List<ExitLeg> exitLegs,
    required double exitSpeedMps,
  }) {
    final tank = _bottomTank(plan);
    if (tank == null) return segments;
    final result = [...segments];
    var depth = segments.isEmpty ? 0.0 : segments.last.targetDepth;
    for (final leg in exitLegs) {
      if (leg.distanceM < kMinExitLegM) continue;
      if (leg.depthM != depth) {
        result.add(
          _travel(
            plan,
            tank,
            'mission-ret-travel-${leg.id}',
            depth,
            leg.depthM,
            result.length,
          ),
        );
        depth = leg.depthM;
      }
      final speed = speeds
          .resolveHeading(
            headingDeg: leg.headingDeg,
            current: leg.current,
            baseSpeedMps: exitSpeedMps,
          )
          .outboundMps;
      result.add(
        _hold(
          tank,
          'mission-ret-${leg.id}',
          depth,
          leg.distanceM,
          speed,
          result.length,
        ),
      );
    }
    return result;
  }

  PlanSegment _travel(
    domain.DivePlan plan,
    DiveTank tank,
    String id,
    double fromDepth,
    double toDepth,
    int order,
  ) {
    return PlanSegment.travel(
      id: id,
      fromDepth: fromDepth,
      targetDepth: toDepth,
      tankId: tank.id,
      gasMix: tank.gasMix,
      ratePerMinute: toDepth > fromDepth ? plan.descentRate : plan.ascentRate,
      order: order,
    );
  }

  PlanSegment _hold(
    DiveTank tank,
    String id,
    double depth,
    double metres,
    double mps,
    int order,
  ) {
    // Never clamp: a hold of one second against a current the diver cannot
    // beat would report an impossible exit as feasible. Callers check
    // traversability first; reaching here with no headway is a bug.
    if (mps <= 0) {
      throw ArgumentError.value(mps, 'mps', 'no headway on $id');
    }
    return PlanSegment(
      id: id,
      targetDepth: depth,
      durationSeconds: math.max(1, _holdSeconds(metres, mps)),
      tankId: tank.id,
      gasMix: tank.gasMix,
      order: order,
    );
  }

  /// Whole seconds to cover [metres] at [mps], rounded up so the hold never
  /// ends short of the waypoint. The tolerance keeps floating noise in a
  /// speed (0.5 + 0.1 is not exactly 0.6) from adding a spurious second to a
  /// leg that divides exactly.
  static int _holdSeconds(double metres, double mps) =>
      (metres / mps - 1e-6).ceil();

  /// The tank the bottom is breathed from: the first cylinder declared back
  /// gas, else the first cylinder (the one the canvas gives a new segment).
  ///
  /// Deliberately not `TankRoleResolver`: it derives the bottom tank from the
  /// plan's segments, and these are the segments being generated, so on a
  /// fresh mission it would just pick the first tank, deco bottle or not.
  DiveTank? _bottomTank(domain.DivePlan plan) {
    if (plan.tanks.isEmpty) return null;
    for (final tank in plan.tanks) {
      if (tank.role == TankRole.backGas) return tank;
    }
    return plan.tanks.first;
  }
}
