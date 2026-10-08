import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Unassisted swim speed with full kit, in m/s (12 m/min).
const double kDefaultSwimSpeedMps = 0.2;

/// One diver on a DPV mission, with their own consumption and scooter.
///
/// SAC lives here because no buddy or diver record stores one; the optional
/// links only supply a name and a photo.
class MissionMember extends Equatable {
  final String id;
  final int order;
  final String displayName;
  final String? buddyId;
  final String? diverId;

  /// Bottom surface air consumption in litres per minute.
  final double sacBottom;

  /// Speed this member swims at when their scooter is dead, in m/s.
  final double swimSpeedMps;
  final ScooterSpec scooter;

  const MissionMember({
    required this.id,
    required this.order,
    required this.displayName,
    this.buddyId,
    this.diverId,
    required this.sacBottom,
    this.swimSpeedMps = kDefaultSwimSpeedMps,
    required this.scooter,
  });

  MissionMember copyWith({
    String? id,
    int? order,
    String? displayName,
    String? buddyId,
    bool clearBuddyId = false,
    String? diverId,
    bool clearDiverId = false,
    double? sacBottom,
    double? swimSpeedMps,
    ScooterSpec? scooter,
  }) {
    return MissionMember(
      id: id ?? this.id,
      order: order ?? this.order,
      displayName: displayName ?? this.displayName,
      buddyId: clearBuddyId ? null : (buddyId ?? this.buddyId),
      diverId: clearDiverId ? null : (diverId ?? this.diverId),
      sacBottom: sacBottom ?? this.sacBottom,
      swimSpeedMps: swimSpeedMps ?? this.swimSpeedMps,
      scooter: scooter ?? this.scooter,
    );
  }

  @override
  List<Object?> get props => [
    id,
    order,
    displayName,
    buddyId,
    diverId,
    sacBottom,
    swimSpeedMps,
    scooter,
  ];
}
