import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';

/// Fraction of burn time that must remain at the surface.
const double kDefaultBatteryReserveFraction = 1.0 / 3.0;

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

  const DpvMission({
    this.legs = const [],
    this.team = const [],
    this.batteryReserveFraction = kDefaultBatteryReserveFraction,
    this.defaultCurrent,
  });

  /// The current in force on [leg]: its own, else the mission default.
  CurrentVector? currentFor(MissionLeg leg) => leg.current ?? defaultCurrent;

  DpvMission copyWith({
    List<MissionLeg>? legs,
    List<MissionMember>? team,
    double? batteryReserveFraction,
    CurrentVector? defaultCurrent,
    bool clearDefaultCurrent = false,
  }) {
    return DpvMission(
      legs: legs ?? this.legs,
      team: team ?? this.team,
      batteryReserveFraction:
          batteryReserveFraction ?? this.batteryReserveFraction,
      defaultCurrent: clearDefaultCurrent
          ? null
          : (defaultCurrent ?? this.defaultCurrent),
    );
  }

  @override
  List<Object?> get props => [
    legs,
    team,
    batteryReserveFraction,
    defaultCurrent,
  ];
}
