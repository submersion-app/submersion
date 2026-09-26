import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/mission/waypoint_outcome.dart';

export 'package:submersion/features/planner/domain/entities/mission/exit_outcome.dart';
export 'package:submersion/features/planner/domain/entities/mission/waypoint_outcome.dart';

/// What went wrong, or what the diver should know, while computing a mission.
enum MissionIssueType {
  emptyTeam,
  emptyRoute,
  scooterUnspecified,
  memberSacUnset,
  memberSwimSpeedUnset,

  /// A shore exit distance, the surface swim limit or the walking speed is
  /// negative. Carries the leg id for a shore exit, null otherwise.
  openWaterInputInvalid,

  /// A leg shorter than half a metre: too short to travel either way.
  legTooShort,

  /// The plan carries no cylinder, so no dive can be computed at all.
  planHasNoTank,

  /// A cylinder has no volume or no fill pressure, so no exit's gas can be
  /// proven safe.
  tankBudgetUnknown,

  /// The plan is a rebreather plan; version 1 plans open circuit only.
  unsupportedMode,

  /// The planned route itself breaks a critical plan-engine limit (ppO2,
  /// hypoxic gas, gas density or CNS) before any failure.
  planNotDiveable,

  /// The battery reserve fraction is outside 0 to 1, or not a number.
  batteryReserveInvalid,

  /// A leg depth is negative or not a number. Carries the leg id.
  legDepthInvalid,
  untraversableLeg,
  scenarioFailed,
}

enum MissionIssueSeverity { info, warning, blocking }

/// The first thing that stops a member going further. The order is the
/// tie-break priority when two members bind at the same waypoint.
///
/// [teamGas]: the member could get out, but a teammate's gas cannot cover
/// the exit. [exposure]: the exit breaks a critical oxygen or gas limit
/// (in practice CNS from the extra time). [blockedByCurrent]: no exit can make headway. [noFeasibleTow]:
/// only when the member has a teammate whose tow was possible but failed.
/// [surfaceSwimLimit]: open water, the only way out is a surface swim longer
/// than the mission's limit.
enum MissionBindingFactor {
  battery,
  ownGas,
  teamGas,
  exposure,
  blockedByCurrent,
  noFeasibleTow,
  surfaceSwimLimit,
}

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

  MissionIssue copyWith({
    MissionIssueType? type,
    MissionIssueSeverity? severity,
    String? legId,
    bool clearLegId = false,
    String? memberId,
    bool clearMemberId = false,
    bool? outbound,
    bool clearOutbound = false,
  }) {
    return MissionIssue(
      type: type ?? this.type,
      severity: severity ?? this.severity,
      legId: clearLegId ? null : (legId ?? this.legId),
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      outbound: clearOutbound ? null : (outbound ?? this.outbound),
    );
  }

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

  LegOutcome copyWith({
    String? legId,
    double? outboundSpeedMps,
    double? returnSpeedMps,
    int? outboundSeconds,
    int? returnSeconds,
  }) {
    return LegOutcome(
      legId: legId ?? this.legId,
      outboundSpeedMps: outboundSpeedMps ?? this.outboundSpeedMps,
      returnSpeedMps: returnSpeedMps ?? this.returnSpeedMps,
      outboundSeconds: outboundSeconds ?? this.outboundSeconds,
      returnSeconds: returnSeconds ?? this.returnSeconds,
    );
  }

  @override
  List<Object?> get props => [
    legId,
    outboundSpeedMps,
    returnSpeedMps,
    outboundSeconds,
    returnSeconds,
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

  MemberOutcome copyWith({
    String? memberId,
    double? batteryRoundTripFraction,
    bool? setsCruiseSpeed,
    MissionBindingFactor? bindingFactor,
    bool clearBindingFactor = false,
    int? bindingWaypointIndex,
    bool clearBindingWaypointIndex = false,
    double? turnPressureBar,
    bool clearTurnPressureBar = false,
  }) {
    return MemberOutcome(
      memberId: memberId ?? this.memberId,
      batteryRoundTripFraction:
          batteryRoundTripFraction ?? this.batteryRoundTripFraction,
      setsCruiseSpeed: setsCruiseSpeed ?? this.setsCruiseSpeed,
      bindingFactor: clearBindingFactor
          ? null
          : (bindingFactor ?? this.bindingFactor),
      bindingWaypointIndex: clearBindingWaypointIndex
          ? null
          : (bindingWaypointIndex ?? this.bindingWaypointIndex),
      turnPressureBar: clearTurnPressureBar
          ? null
          : (turnPressureBar ?? this.turnPressureBar),
    );
  }

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

  MissionConstraint copyWith({
    String? memberId,
    MissionBindingFactor? factor,
    int? waypointIndex,
  }) {
    return MissionConstraint(
      memberId: memberId ?? this.memberId,
      factor: factor ?? this.factor,
      waypointIndex: waypointIndex ?? this.waypointIndex,
    );
  }

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

  MissionOutcome copyWith({
    List<PlanSegment>? segments,
    double? cruiseSpeedMps,
    List<LegOutcome>? legs,
    List<WaypointOutcome>? waypoints,
    List<MemberOutcome>? members,
    int? abandonmentIndex,
    bool clearAbandonmentIndex = false,
    MissionConstraint? constraint,
    bool clearConstraint = false,
    List<MissionIssue>? issues,
  }) {
    return MissionOutcome(
      segments: segments ?? this.segments,
      cruiseSpeedMps: cruiseSpeedMps ?? this.cruiseSpeedMps,
      legs: legs ?? this.legs,
      waypoints: waypoints ?? this.waypoints,
      members: members ?? this.members,
      abandonmentIndex: clearAbandonmentIndex
          ? null
          : (abandonmentIndex ?? this.abandonmentIndex),
      constraint: clearConstraint ? null : (constraint ?? this.constraint),
      issues: issues ?? this.issues,
    );
  }

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
