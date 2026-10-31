import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// The ascent leg from [fromDepth] to [toDepth], lasting [seconds], split
/// wherever [ascentPlan] changes gas.
///
/// Each span ends at the leg's own time for that depth, rounded to a whole
/// second, so no span can run backwards and they always add back up to
/// [seconds]. The table, the gas charged and the oxygen exposure all split
/// here, and all read a span's gas at its deeper end, so they cannot disagree
/// about where a gas starts.
List<AscentLeg> splitAscentLeg(
  AscentGasPlan ascentPlan, {
  required double fromDepth,
  required double toDepth,
  required int seconds,
}) {
  final boundaries = travelLegBoundaries(
    ascentPlan,
    fromDepth: fromDepth,
    toDepth: toDepth,
  );
  final spans = <AscentLeg>[];
  var elapsed = 0;
  for (var i = 1; i < boundaries.length; i++) {
    final spanTo = boundaries[i];
    final spanEnd = i == boundaries.length - 1
        ? seconds
        : (seconds * (fromDepth - spanTo) / (fromDepth - toDepth)).round();
    spans.add((
      fromDepth: boundaries[i - 1],
      toDepth: spanTo,
      seconds: spanEnd - elapsed,
    ));
    elapsed = spanEnd;
  }
  return spans;
}

/// Every stretch of travel in a computed ascent from [fromDepth], up through
/// [stopDepths] (deepest first) to the surface, split wherever [ascentPlan]
/// changes gas.
List<AscentLeg> ascentTravelSpans(
  SchedulePolicy policy,
  AscentGasPlan ascentPlan, {
  required double fromDepth,
  required List<double> stopDepths,
}) => [
  for (final leg in policy.ascentLegs(
    fromDepth: fromDepth,
    stopDepths: stopDepths,
  ))
    if (leg.fromDepth > leg.toDepth)
      ...splitAscentLeg(
        ascentPlan,
        fromDepth: leg.fromDepth,
        toDepth: leg.toDepth,
        seconds: leg.seconds,
      ),
];
