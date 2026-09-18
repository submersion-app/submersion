import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// What went wrong, or what the diver should know, while computing a mission.
enum MissionIssueType {
  emptyTeam,
  emptyRoute,
  scooterUnspecified,
  memberSacUnset,
  untraversableLeg,
  scenarioFailed,
}

enum MissionIssueSeverity { info, warning, blocking }

/// How a team gets a diver with a dead scooter back to the start.
enum MissionExitMode { swim, tow }

/// The first thing that stops a member going further.
enum MissionBindingFactor { battery, ownGas, noFeasibleTow, swimGas }

/// One issue found while computing a mission. Carries ids, not prose; the
/// UI localises the message.
class MissionIssue extends Equatable {
  final MissionIssueType type;
  final MissionIssueSeverity severity;
  final String? legId;
  final String? memberId;

  /// For [MissionIssueType.untraversableLeg]: true when the outbound
  /// direction is blocked, false for the return, null when not applicable.
  final bool? outbound;

  const MissionIssue({
    required this.type,
    required this.severity,
    this.legId,
    this.memberId,
    this.outbound,
  });

  @override
  List<Object?> get props => [type, severity, legId, memberId, outbound];
}

/// Effective speeds and durations of one leg at the team cruise speed.
class LegOutcome extends Equatable {
  final String legId;
  final double outboundSpeedMps;
  final double returnSpeedMps;
  final int outboundSeconds;
  final int returnSeconds;

  const LegOutcome({
    required this.legId,
    required this.outboundSpeedMps,
    required this.returnSpeedMps,
    required this.outboundSeconds,
    required this.returnSeconds,
  });

  @override
  List<Object?> get props => [
    legId,
    outboundSpeedMps,
    returnSpeedMps,
    outboundSeconds,
    returnSeconds,
  ];
}

/// One way out after a scooter failure, evaluated through the plan engine.
class ExitOutcome extends Equatable {
  final MissionExitMode mode;

  /// The teammate towing, for [MissionExitMode.tow]; null for a swim.
  final String? towerId;
  final bool feasible;

  /// Seconds from the failure point back to the start of the route.
  final int exitBottomSeconds;

  /// Time to surface from the end of the exit, from the plan engine.
  final int ttsSeconds;

  /// Surface litres each member breathes from the failure point to the
  /// surface, by member id.
  final Map<String, double> exitLitersByMember;
  final Set<String> gasShortfallMemberIds;
  final Set<String> batteryShortfallMemberIds;

  /// True when a current on some exit leg is at least as fast as the exit
  /// speed, so the team cannot make headway at all. A current the scooters
  /// beat at cruise can still stop a swim or a slow tow.
  final bool blockedByCurrent;

  const ExitOutcome({
    required this.mode,
    this.towerId,
    required this.feasible,
    required this.exitBottomSeconds,
    required this.ttsSeconds,
    required this.exitLitersByMember,
    this.gasShortfallMemberIds = const {},
    this.batteryShortfallMemberIds = const {},
    this.blockedByCurrent = false,
  });

  int get exitSeconds => exitBottomSeconds + ttsSeconds;

  @override
  List<Object?> get props => [
    mode,
    towerId,
    feasible,
    exitBottomSeconds,
    ttsSeconds,
    exitLitersByMember,
    gasShortfallMemberIds,
    batteryShortfallMemberIds,
    blockedByCurrent,
  ];
}

/// One member's situation at one waypoint if their scooter dies there.
class MemberWaypointOutcome extends Equatable {
  final String memberId;

  /// Pressure left on the bottom tank on arrival; null when the tank has no
  /// start pressure.
  final double? gasRemainingBar;
  final ExitOutcome swim;

  /// The best tow exit (feasible if any is), or null with no teammate.
  final ExitOutcome? tow;
  final bool survivable;

  const MemberWaypointOutcome({
    required this.memberId,
    required this.gasRemainingBar,
    required this.swim,
    this.tow,
    required this.survivable,
  });

  @override
  List<Object?> get props => [memberId, gasRemainingBar, swim, tow, survivable];
}

/// One waypoint of the route with every member's failure evaluated there.
class WaypointOutcome extends Equatable {
  final int index;
  final String legId;
  final double cumulativeDistanceM;
  final int arrivalRuntimeSeconds;
  final List<MemberWaypointOutcome> members;

  /// True when every member's failure here has a feasible exit.
  final bool survivable;

  const WaypointOutcome({
    required this.index,
    required this.legId,
    required this.cumulativeDistanceM,
    required this.arrivalRuntimeSeconds,
    required this.members,
    required this.survivable,
  });

  @override
  List<Object?> get props => [
    index,
    legId,
    cumulativeDistanceM,
    arrivalRuntimeSeconds,
    members,
    survivable,
  ];
}

/// One member across the whole mission.
class MemberOutcome extends Equatable {
  final String memberId;

  /// Fraction of burn time used on the no-failure round trip.
  final double batteryRoundTripFraction;
  final bool setsCruiseSpeed;
  final MissionBindingFactor? bindingFactor;
  final int? bindingWaypointIndex;

  /// Bottom-tank pressure that must remain at the abandonment point to cover
  /// this member's worst feasible exit plus the plan reserve; null when no
  /// waypoint is survivable.
  final double? turnPressureBar;

  const MemberOutcome({
    required this.memberId,
    required this.batteryRoundTripFraction,
    required this.setsCruiseSpeed,
    this.bindingFactor,
    this.bindingWaypointIndex,
    this.turnPressureBar,
  });

  @override
  List<Object?> get props => [
    memberId,
    batteryRoundTripFraction,
    setsCruiseSpeed,
    bindingFactor,
    bindingWaypointIndex,
    turnPressureBar,
  ];
}

/// The member and factor that bind earliest along the route.
class MissionConstraint extends Equatable {
  final String memberId;
  final MissionBindingFactor factor;
  final int waypointIndex;

  const MissionConstraint({
    required this.memberId,
    required this.factor,
    required this.waypointIndex,
  });

  @override
  List<Object?> get props => [memberId, factor, waypointIndex];
}

/// Everything the mission engine computes.
class MissionOutcome extends Equatable {
  /// The generated round-trip segments the plan should carry.
  final List<PlanSegment> segments;
  final double cruiseSpeedMps;
  final List<LegOutcome> legs;
  final List<WaypointOutcome> waypoints;
  final List<MemberOutcome> members;

  /// Last waypoint index at which every member's failure is survivable and
  /// every earlier waypoint is too; null when even the first is not.
  final int? abandonmentIndex;
  final MissionConstraint? constraint;
  final List<MissionIssue> issues;

  const MissionOutcome({
    required this.segments,
    required this.cruiseSpeedMps,
    required this.legs,
    required this.waypoints,
    required this.members,
    required this.abandonmentIndex,
    required this.constraint,
    required this.issues,
  });

  /// An outcome with nothing computed, for a mission that cannot run.
  const MissionOutcome.empty({required this.issues})
    : segments = const [],
      cruiseSpeedMps = 0,
      legs = const [],
      waypoints = const [],
      members = const [],
      abandonmentIndex = null,
      constraint = null;

  bool get isBlocked =>
      issues.any((i) => i.severity == MissionIssueSeverity.blocking);

  @override
  List<Object?> get props => [
    segments,
    cruiseSpeedMps,
    legs,
    waypoints,
    members,
    abandonmentIndex,
    constraint,
    issues,
  ];
}
