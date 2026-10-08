import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/exit_outcome.dart';

/// One member's situation at one waypoint if their scooter dies there.
class MemberWaypointOutcome extends Equatable {
  final String memberId;

  /// Pressure left on the bottom tank on arrival; null when the tank has no
  /// start pressure.
  final double? gasRemainingBar;
  final ExitOutcome swim;

  /// The best tow exit (feasible if any is), or null when the member has no
  /// teammate: a solo diver has no buddy to tow them.
  final ExitOutcome? tow;

  /// Open water only: ascend in place and continue at the surface, with this
  /// member stressed up to the first stop. Null in an overhead, or when the
  /// scenario could not be run.
  final ExitOutcome? surface;
  final bool survivable;

  const MemberWaypointOutcome({
    required this.memberId,
    required this.gasRemainingBar,
    required this.swim,
    this.tow,
    this.surface,
    required this.survivable,
  });

  MemberWaypointOutcome copyWith({
    String? memberId,
    double? gasRemainingBar,
    bool clearGasRemainingBar = false,
    ExitOutcome? swim,
    ExitOutcome? tow,
    bool clearTow = false,
    ExitOutcome? surface,
    bool clearSurface = false,
    bool? survivable,
  }) {
    return MemberWaypointOutcome(
      memberId: memberId ?? this.memberId,
      gasRemainingBar: clearGasRemainingBar
          ? null
          : (gasRemainingBar ?? this.gasRemainingBar),
      swim: swim ?? this.swim,
      tow: clearTow ? null : (tow ?? this.tow),
      surface: clearSurface ? null : (surface ?? this.surface),
      survivable: survivable ?? this.survivable,
    );
  }

  @override
  List<Object?> get props => [
    memberId,
    gasRemainingBar,
    swim,
    tow,
    surface,
    survivable,
  ];
}

/// One waypoint of the route with every member's failure evaluated there.
class WaypointOutcome extends Equatable {
  final int index;
  final String legId;
  final double cumulativeDistanceM;
  final int arrivalRuntimeSeconds;

  /// Straight-line distance from the waypoint back to the entry, in metres.
  final double directDistanceHomeM;

  /// Seconds to the next safe surface with no failure: in an overhead the
  /// way out at cruise plus the ascent, in open water the ascent alone. Null
  /// when it could not be computed.
  final int? safeSurfaceSeconds;
  final List<MemberWaypointOutcome> members;

  /// True when every member's failure here has a feasible exit.
  final bool survivable;

  const WaypointOutcome({
    required this.index,
    required this.legId,
    required this.cumulativeDistanceM,
    required this.arrivalRuntimeSeconds,
    required this.directDistanceHomeM,
    required this.safeSurfaceSeconds,
    required this.members,
    required this.survivable,
  });

  WaypointOutcome copyWith({
    int? index,
    String? legId,
    double? cumulativeDistanceM,
    int? arrivalRuntimeSeconds,
    double? directDistanceHomeM,
    int? safeSurfaceSeconds,
    bool clearSafeSurfaceSeconds = false,
    List<MemberWaypointOutcome>? members,
    bool? survivable,
  }) {
    return WaypointOutcome(
      index: index ?? this.index,
      legId: legId ?? this.legId,
      cumulativeDistanceM: cumulativeDistanceM ?? this.cumulativeDistanceM,
      arrivalRuntimeSeconds:
          arrivalRuntimeSeconds ?? this.arrivalRuntimeSeconds,
      directDistanceHomeM: directDistanceHomeM ?? this.directDistanceHomeM,
      safeSurfaceSeconds: clearSafeSurfaceSeconds
          ? null
          : (safeSurfaceSeconds ?? this.safeSurfaceSeconds),
      members: members ?? this.members,
      survivable: survivable ?? this.survivable,
    );
  }

  @override
  List<Object?> get props => [
    index,
    legId,
    cumulativeDistanceM,
    arrivalRuntimeSeconds,
    directDistanceHomeM,
    safeSurfaceSeconds,
    members,
    survivable,
  ];
}
