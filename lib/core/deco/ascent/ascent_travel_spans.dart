import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// One stretch of computed ascent travel, on a single gas.
typedef AscentTravelSpan = ({double fromDepth, double toDepth, int seconds});

/// Every stretch of travel in a computed ascent from [fromDepth], up through
/// [stopDepths] (deepest first) to the surface, split wherever [ascentPlan]
/// changes gas.
///
/// A stop holds still, so it carries none of this time: each leg runs at the
/// rate of its own [AscentPhase], and a leg split at a gas switch keeps its
/// whole duration, the last span taking whatever rounding leaves over.
List<AscentTravelSpan> ascentTravelSpans(
  SchedulePolicy policy,
  AscentGasPlan ascentPlan, {
  required double fromDepth,
  required List<double> stopDepths,
}) {
  final spans = <AscentTravelSpan>[];

  void addLeg(double from, double to, int seconds) {
    if (from <= to) return;
    final boundaries = travelLegBoundaries(
      ascentPlan,
      fromDepth: from,
      toDepth: to,
    );
    var remaining = seconds;
    for (var i = 0; i + 1 < boundaries.length; i++) {
      final isLast = i + 2 == boundaries.length;
      final spanSeconds = isLast
          ? remaining
          : (seconds * (boundaries[i] - boundaries[i + 1]) / (from - to))
                .round();
      spans.add((
        fromDepth: boundaries[i],
        toDepth: boundaries[i + 1],
        seconds: spanSeconds,
      ));
      remaining -= spanSeconds;
    }
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
