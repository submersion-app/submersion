import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// An exit leg shorter than this is no leg at all: a route that ends where
/// it started has nothing to swim, and floating error must not make it one.
const double kMinExitLegM = 0.5;

/// A position relative to the entry, in metres east and north.
class RoutePoint extends Equatable {
  final double eastM;
  final double northM;

  const RoutePoint({required this.eastM, required this.northM});

  double get distanceHomeM => math.sqrt(eastM * eastM + northM * northM);

  /// True bearing from here back to the entry, in [0, 360). Zero at the
  /// entry itself, where there is no direction to go.
  double get bearingHomeDeg {
    if (distanceHomeM < kMinExitLegM) return 0;
    final degrees = math.atan2(-eastM, -northM) * 180.0 / math.pi;
    return (degrees + 360.0) % 360.0;
  }

  @override
  List<Object?> get props => [eastM, northM];
}

/// Each waypoint's position by dead reckoning: the sum of every leg up to
/// it along its heading.
List<RoutePoint> waypointPositions(List<MissionLeg> legs) {
  var east = 0.0;
  var north = 0.0;
  return [
    for (final leg in legs)
      () {
        final radians = leg.headingDeg * math.pi / 180.0;
        east += leg.distanceM * math.sin(radians);
        north += leg.distanceM * math.cos(radians);
        return RoutePoint(eastM: east, northM: north);
      }(),
  ];
}

/// The way back along the route from waypoint [waypointIndex]: its legs in
/// reverse, each on its reciprocal heading in its own current.
List<ExitLeg> retraceExitLegs(DpvMission mission, int waypointIndex) {
  final last = math.min(waypointIndex, mission.legs.length - 1);
  return [
    for (final leg in mission.legs.sublist(0, last + 1).reversed)
      ExitLeg(
        id: leg.id,
        distanceM: leg.distanceM,
        depthM: leg.depthM,
        headingDeg: leg.returnHeadingDeg,
        current: mission.currentFor(leg),
      ),
  ];
}

/// The underwater way out from waypoint [waypointIndex] for the mission's
/// environment: the route retraced in an overhead, or one straight leg home
/// at the waypoint's depth in open water (none when the waypoint is the
/// entry). The straight leg takes the current in force on the leg that ends
/// at the waypoint: its own, else the mission default.
List<ExitLeg> exitLegsFor(DpvMission mission, int waypointIndex) {
  switch (mission.environment) {
    case MissionEnvironment.overhead:
      return retraceExitLegs(mission, waypointIndex);
    case MissionEnvironment.openWater:
      final point = waypointPositions(mission.legs)[waypointIndex];
      if (point.distanceHomeM < kMinExitLegM) return const [];
      final leg = mission.legs[waypointIndex];
      return [
        ExitLeg(
          id: 'home',
          distanceM: point.distanceHomeM,
          depthM: leg.depthM,
          headingDeg: point.bearingHomeDeg,
          current: mission.currentFor(leg),
        ),
      ];
  }
}
