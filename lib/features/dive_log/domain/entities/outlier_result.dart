import 'package:equatable/equatable.dart';

/// Result of outlier detection for a single profile point.
class OutlierResult extends Equatable {
  /// Index of the outlier point in the profile list
  final int index;

  /// Timestamp of the outlier point (seconds from dive start)
  final int timestamp;

  /// Depth of the outlier point (meters)
  final double depth;

  /// The depth delta that triggered the outlier flag
  final double depthDelta;

  /// Z-score of this point's delta relative to the local window
  final double zScore;

  /// Whether this was flagged by physical impossibility (>3m/s)
  final bool isPhysicallyImpossible;

  const OutlierResult({
    required this.index,
    required this.timestamp,
    required this.depth,
    required this.depthDelta,
    required this.zScore,
    this.isPhysicallyImpossible = false,
  });

  @override
  List<Object?> get props => [
    index,
    timestamp,
    depth,
    depthDelta,
    zScore,
    isPhysicallyImpossible,
  ];
}
