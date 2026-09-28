import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';

/// Slowest speed over the ground that still counts as headway, in m/s
/// (3 m/min). Below it a 300 m leg takes over an hour and a half, and the
/// leg time would carry into gas, battery and deco as if it were a plan, so
/// such a direction is blocked like a current the diver cannot beat.
const double kMinSpeedOverGroundMps = 0.05;

/// Speed over the ground along a track in each direction, in m/s.
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

/// Applies a current to a speed through the water.
///
/// A diver holding a straight track angles into the cross-track share of
/// the current, so their speed over the ground is the along-track share
/// plus `sqrt(v^2 - x^2)`. The return flips the along-track share and keeps
/// the cross share. A cross current as fast as the diver cannot be held at
/// all, and a direction whose speed over the ground is below
/// [kMinSpeedOverGroundMps] resolves to zero: it cannot be travelled.
class LegSpeedResolver {
  const LegSpeedResolver();

  LegSpeeds resolve({
    required MissionLeg leg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    return resolveHeading(
      headingDeg: leg.headingDeg,
      current: current,
      baseSpeedMps: baseSpeedMps,
    );
  }

  LegSpeeds resolveHeading({
    required double headingDeg,
    required CurrentVector? current,
    required double baseSpeedMps,
  }) {
    final along = current?.alongRouteComponent(headingDeg) ?? 0.0;
    final cross = current?.crossTrackComponent(headingDeg) ?? 0.0;
    if (cross.abs() >= baseSpeedMps) {
      return const LegSpeeds(outboundMps: 0, returnMps: 0);
    }
    final made = math.sqrt(baseSpeedMps * baseSpeedMps - cross * cross);
    return LegSpeeds(
      outboundMps: headway(made + along),
      returnMps: headway(made - along),
    );
  }

  /// [speedOverGroundMps], or zero when it is below
  /// [kMinSpeedOverGroundMps]. Public so a speed worked out without a
  /// heading (a shore route's worst case) is held to the same floor.
  static double headway(double speedOverGroundMps) {
    return speedOverGroundMps < kMinSpeedOverGroundMps ? 0 : speedOverGroundMps;
  }
}
