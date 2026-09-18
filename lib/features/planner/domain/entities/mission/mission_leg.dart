import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';

/// One outbound leg of a mission route. It ends at the waypoint it names.
class MissionLeg extends Equatable {
  final String id;
  final int order;

  /// Waypoint name, for example "T" or "Jump 2".
  final String label;

  /// Horizontal distance in metres, greater than zero.
  final double distanceM;

  /// Depth held along the leg, in metres.
  final double depthM;

  /// True heading of travel in degrees, 0 to 360.
  final double headingDeg;

  /// Current on this leg; null inherits the mission default.
  final CurrentVector? current;

  const MissionLeg({
    required this.id,
    required this.order,
    required this.label,
    required this.distanceM,
    required this.depthM,
    required this.headingDeg,
    this.current,
  });

  /// Heading of the return trip along this leg.
  double get returnHeadingDeg => (headingDeg + 180.0) % 360.0;

  MissionLeg copyWith({
    String? id,
    int? order,
    String? label,
    double? distanceM,
    double? depthM,
    double? headingDeg,
    CurrentVector? current,
    bool clearCurrent = false,
  }) {
    return MissionLeg(
      id: id ?? this.id,
      order: order ?? this.order,
      label: label ?? this.label,
      distanceM: distanceM ?? this.distanceM,
      depthM: depthM ?? this.depthM,
      headingDeg: headingDeg ?? this.headingDeg,
      current: clearCurrent ? null : (current ?? this.current),
    );
  }

  @override
  List<Object?> get props => [
    id,
    order,
    label,
    distanceM,
    depthM,
    headingDeg,
    current,
  ];
}
