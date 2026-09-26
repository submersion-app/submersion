/// Maximum and minimum operating depth of a breathing gas.
///
/// The single home of the MOD formula. `O2ToxicityCalculator.calculateMod`,
/// `GasMix.mod` and `ScrCalculator.calculateMod` delegate here, so the
/// planner, the dive log and the gas calculators cannot drift apart.
///
/// The values are exact and never rounded: the planner switches gases on
/// them. A limit depth shown to a diver is rounded DOWN at display time, via
/// `UnitFormatter.formatDepthFloor`.
library;

import 'dart:math' as math;

import 'package:submersion/core/deco/entities/dive_environment.dart';

/// Depth in meters at which [o2Fraction] reaches [maxPpO2].
///
/// Without an [environment] this is the flat model every existing caller
/// uses, 1 bar surface and exactly 10 m per bar, kept bit-identical so gas
/// switch depths do not move. With one, the pressure follows its water
/// density and surface pressure.
///
/// A gas without oxygen has no MOD and returns 0. With an [environment] the
/// MOD is never negative: a limit the mix already exceeds at the surface
/// (pure O2 at a 0.5 bar flush ppO2) gives 0, not a depth above the water.
double maxOperatingDepthMeters(
  double o2Fraction, {
  required double maxPpO2,
  DiveEnvironment? environment,
}) {
  if (o2Fraction <= 0) return 0;
  final pressure = maxPpO2 / o2Fraction;
  if (environment == null) return (pressure - 1.0) * 10.0;
  return math.max(environment.depthAtPressure(pressure), 0.0);
}

/// Shallowest depth in meters at which [o2Fraction] reaches [minPpO2].
///
/// 0 for a gas that is breathable at the surface. A gas without oxygen is
/// never breathable and returns infinity.
double minimumOperatingDepthMeters(
  double o2Fraction, {
  required double minPpO2,
  DiveEnvironment? environment,
}) {
  if (o2Fraction <= 0) return double.infinity;
  final pressure = minPpO2 / o2Fraction;
  final depth = environment == null
      ? (pressure - 1.0) * 10.0
      : environment.depthAtPressure(pressure);
  return math.max(depth, 0.0);
}
