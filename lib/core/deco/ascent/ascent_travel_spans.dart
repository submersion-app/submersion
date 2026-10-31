import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// One stretch of computed ascent travel, on a single gas.
typedef AscentTravelSpan = ({double fromDepth, double toDepth, int seconds});

/// The ascent leg from [fromDepth] to [toDepth], lasting [seconds], split
/// wherever [ascentPlan] changes gas.
///
/// Each span's share follows the depth it covers, and the last takes whatever
/// rounding leaves over, so the spans always add back up to [seconds]. The
/// table, the gas charged and the oxygen exposure all split here, so they
/// cannot disagree about where a gas starts on a leg that crosses a switch.
List<AscentTravelSpan> splitAscentLeg(
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
  final spans = <AscentTravelSpan>[];
  var remaining = seconds;
  for (var i = 1; i < boundaries.length; i++) {
    final spanFrom = boundaries[i - 1];
    final spanTo = boundaries[i];
    final spanSeconds = i == boundaries.length - 1
        ? remaining
        : (seconds * (spanFrom - spanTo) / (fromDepth - toDepth)).round();
    spans.add((fromDepth: spanFrom, toDepth: spanTo, seconds: spanSeconds));
    remaining -= spanSeconds;
  }
  return spans;
}

/// Every stretch of travel in a computed ascent from [fromDepth], up through
/// [stopDepths] (deepest first) to the surface. A stop holds still, so it
/// carries none of this time, and each leg runs at the rate of its own
/// [AscentPhase].
List<AscentTravelSpan> ascentTravelSpans(
  SchedulePolicy policy,
  AscentGasPlan ascentPlan, {
  required double fromDepth,
  required List<double> stopDepths,
}) {
  final spans = <AscentTravelSpan>[];

  void addLeg(double from, double to, int seconds) {
    if (from <= to) return;
    spans.addAll(
      splitAscentLeg(
        ascentPlan,
        fromDepth: from,
        toDepth: to,
        seconds: seconds,
      ),
    );
  }

  var depth = fromDepth;
  var phase = AscentPhase.toFirstStop;
  for (final stopDepth in stopDepths) {
    addLeg(
      depth,
      stopDepth,
      policy.ascentSeconds(fromDepth: depth, toDepth: stopDepth, phase: phase),
    );
    depth = stopDepth;
    phase = AscentPhase.betweenStops;
  }
  addLeg(
    depth,
    0,
    policy.ascentSeconds(
      fromDepth: depth,
      toDepth: 0,
      phase: AscentPhase.surfacingAfter(phase),
    ),
  );
  return spans;
}
