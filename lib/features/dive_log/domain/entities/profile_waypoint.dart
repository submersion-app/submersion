import 'package:equatable/equatable.dart';

/// A user-placed waypoint for manual profile drawing.
class ProfileWaypoint extends Equatable {
  /// Timestamp in seconds from dive start
  final int timestamp;

  /// Depth in meters
  final double depth;

  const ProfileWaypoint({required this.timestamp, required this.depth});

  ProfileWaypoint copyWith({int? timestamp, double? depth}) {
    return ProfileWaypoint(
      timestamp: timestamp ?? this.timestamp,
      depth: depth ?? this.depth,
    );
  }

  @override
  List<Object?> get props => [timestamp, depth];
}
