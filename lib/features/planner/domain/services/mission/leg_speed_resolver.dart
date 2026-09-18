import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// Effective ground speed along a leg in each direction, in m/s.
class LegSpeeds extends Equatable {
  final double outboundMps;
  final double returnMps;

  const LegSpeeds({required this.outboundMps, required this.returnMps});

  bool get outboundTraversable => outboundMps > 0;
  bool get returnTraversable => returnMps > 0;
  bool get traversable => outboundTraversable && returnTraversable;

  @override
  List<Object?> get props => [outboundMps, returnMps];
}

/// Applies a leg's current to a base travel speed.
///
/// The along-route component of the current is added outbound and subtracted
/// on the return, which is the same formula evaluated on the reversed
/// heading. A direction whose effective speed is not positive cannot be
/// travelled at all.
class LegSpeedResolver {
  const LegSpeedResolver();

  LegSpeeds resolve({
    required MissionLeg leg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    final component = current?.alongRouteComponent(leg.headingDeg) ?? 0.0;
    return LegSpeeds(
      outboundMps: baseSpeedMps + component,
      returnMps: baseSpeedMps - component,
    );
  }
}
