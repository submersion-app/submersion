/// Maximum and minimum operating depth of a breathing gas.
///
/// The single home of the MOD formula. `O2ToxicityCalculator.calculateMod`,
/// `GasMix.mod` and `ScrCalculator.calculateMod` delegate here, so the
/// planner, the dive log and the gas calculators cannot drift apart.
///
/// The values are exact and never rounded. The planner switches gases on
/// [gasSwitchDepthMeters], the MOD in the plan's water with a display
/// tolerance. A limit depth shown to a diver is rounded DOWN at display
/// time, via `UnitFormatter.formatDepthFloor`.
library;

import 'dart:math' as math;

import 'package:submersion/core/deco/entities/dive_environment.dart';

/// Depth in meters at which [o2Fraction] reaches [maxPpO2].
///
/// Without an [environment] this is the flat model, 1 bar surface and
/// exactly 10 m per bar, the depth a diver reads off a MOD table. With one,
/// the pressure follows its water density and surface pressure.
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

/// Just under half the 0.01 bar step a ppO2 is shown to. A planned gas
/// switch allows this much over the limit, so a gas is breathed wherever its
/// ppO2 still reads as the limit. Not a full half: a stop landing exactly on
/// the switch depth would sit on the rounding boundary and could read one
/// step high.
const double gasSwitchPpO2Tolerance = 0.0049;

/// Deepest depth in meters at which a plan switches to [o2Fraction] under
/// [maxPpO2], measured in the plan's [environment] (issue #3566).
///
/// The switch follows the water the schedule's ppO2 is computed in, so a
/// table line never shows a gas above its limit: in seawater EAN40 at 30 m
/// is 1.606 bar and reads 1.61, so 30 m is breathed on the previous gas.
/// [gasSwitchPpO2Tolerance] keeps the switches that only round to the limit:
/// oxygen at 6 m in seawater is 1.603 bar and reads 1.60.
double gasSwitchDepthMeters(
  double o2Fraction, {
  required double maxPpO2,
  required DiveEnvironment environment,
}) => maxOperatingDepthMeters(
  o2Fraction,
  maxPpO2: maxPpO2 + gasSwitchPpO2Tolerance,
  environment: environment,
);

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
