import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';

/// One leg of a way out: travelled on [headingDeg] at [depthM] for
/// [distanceM], in [current] (already resolved; null means none). Carries
/// no scooter or diver, so any exit (a retrace, a straight line home, a
/// jump back to a line) can be expressed with it.
class ExitLeg extends Equatable {
  /// Names the generated segments: `mission-ret-<id>`.
  final String id;
  final double distanceM;
  final double depthM;
  final double headingDeg;
  final CurrentVector? current;

  const ExitLeg({
    required this.id,
    required this.distanceM,
    required this.depthM,
    required this.headingDeg,
    this.current,
  });

  @override
  List<Object?> get props => [id, distanceM, depthM, headingDeg, current];
}
