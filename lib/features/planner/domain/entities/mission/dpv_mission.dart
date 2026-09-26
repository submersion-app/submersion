import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';

/// Fraction of burn time that must remain at the surface.
const double kDefaultBatteryReserveFraction = 1.0 / 3.0;

/// Walking speed on land in full kit, in m/s, for a shore exit.
const double kDefaultWalkSpeedMps = 0.8;

/// Where the mission is dived, which decides the ways out.
///
/// [overhead]: no direct ascent; an exit goes back along the route at depth.
/// [openWater]: a diver may ascend anywhere, swim straight home, or land on
/// a shore and walk.
enum MissionEnvironment { overhead, openWater }

/// A scooter mission attached to a dive plan: the outbound route, the team,
/// and the battery reserve rule. The return trip is derived, never authored.
class DpvMission extends Equatable {
  /// Ordered outbound legs.
  final List<MissionLeg> legs;

  /// Ordered team; a valid mission has at least one member.
  final List<MissionMember> team;
  final double batteryReserveFraction;

  /// Current inherited by legs whose own current is null.
  final CurrentVector? defaultCurrent;

  final MissionEnvironment environment;

  /// Walking speed for a shore exit, in m/s. Open water only.
  final double walkSpeedMps;

  /// Longest acceptable surface swim, in metres; null means a surface exit
  /// is reported but never blocks. Open water only.
  final double? surfaceSwimLimitM;

  const DpvMission({
    this.legs = const [],
    this.team = const [],
    this.batteryReserveFraction = kDefaultBatteryReserveFraction,
    this.defaultCurrent,
    this.environment = MissionEnvironment.overhead,
    this.walkSpeedMps = kDefaultWalkSpeedMps,
    this.surfaceSwimLimitM,
  });

  /// The current in force on [leg]: its own, else the mission default.
  CurrentVector? currentFor(MissionLeg leg) => leg.current ?? defaultCurrent;

  DpvMission copyWith({
    List<MissionLeg>? legs,
    List<MissionMember>? team,
    double? batteryReserveFraction,
    CurrentVector? defaultCurrent,
    bool clearDefaultCurrent = false,
    MissionEnvironment? environment,
    double? walkSpeedMps,
    double? surfaceSwimLimitM,
    bool clearSurfaceSwimLimit = false,
  }) {
    return DpvMission(
      legs: legs ?? this.legs,
      team: team ?? this.team,
      batteryReserveFraction:
          batteryReserveFraction ?? this.batteryReserveFraction,
      defaultCurrent: clearDefaultCurrent
          ? null
          : (defaultCurrent ?? this.defaultCurrent),
      environment: environment ?? this.environment,
      walkSpeedMps: walkSpeedMps ?? this.walkSpeedMps,
      surfaceSwimLimitM: clearSurfaceSwimLimit
          ? null
          : (surfaceSwimLimitM ?? this.surfaceSwimLimitM),
    );
  }

  @override
  List<Object?> get props => [
    legs,
    team,
    batteryReserveFraction,
    defaultCurrent,
    environment,
    walkSpeedMps,
    surfaceSwimLimitM,
  ];
}
