import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A steady water current: how fast it flows and the direction it sets
/// toward (the oceanographic convention, the opposite of wind, which is named
/// by where it comes from).
class CurrentVector extends Equatable {
  /// Current speed in metres per second, never negative.
  final double speedMps;

  /// True direction the water flows toward, in degrees 0 to 360.
  final double setsTowardDeg;

  const CurrentVector({required this.speedMps, required this.setsTowardDeg});

  /// The component of this current along a leg travelled on [headingDeg],
  /// in m/s. Positive helps the diver along, negative holds them back.
  double alongRouteComponent(double headingDeg) {
    final radians = (setsTowardDeg - headingDeg) * math.pi / 180.0;
    return speedMps * math.cos(radians);
  }

  /// The component of this current across a leg travelled on [headingDeg],
  /// in m/s; positive sets the diver to the right of the track. A diver
  /// holding the track angles into it, which costs speed over the ground.
  double crossTrackComponent(double headingDeg) {
    final radians = (setsTowardDeg - headingDeg) * math.pi / 180.0;
    return speedMps * math.sin(radians);
  }

  CurrentVector copyWith({double? speedMps, double? setsTowardDeg}) {
    return CurrentVector(
      speedMps: speedMps ?? this.speedMps,
      setsTowardDeg: setsTowardDeg ?? this.setsTowardDeg,
    );
  }

  @override
  List<Object?> get props => [speedMps, setsTowardDeg];
}
