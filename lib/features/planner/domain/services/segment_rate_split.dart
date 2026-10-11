import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// [segments] (already sorted) with every segment flagged
/// [PlanSegment.splitAtConfiguredRate] -- and carrying an actual depth
/// change -- expanded into two: travel at the plan's configured
/// descent/ascent rate, then a hold at the target depth for whatever time
/// remains of the segment's own authored duration (#3264).
///
/// The chart, the deco computation and the gas-consumption accounting all
/// read this expanded list, so all three agree on the kinked profile a
/// diver sees; the diver's own authored [segments] -- what the segment
/// list shows and the editor opens on -- are never touched. The travel
/// half keeps the original segment's id (so a later edit or a chart tap by
/// id still resolves to the one segment the diver authored); the hold half
/// gets a synthetic id derived from it. A segment whose configured-rate
/// travel time already reaches or exceeds its own authored duration is
/// left exactly as it is -- there is no remainder left to hold.
List<PlanSegment> expandRateSplitSegments(
  List<PlanSegment> segments,
  domain.DivePlan plan,
) {
  final result = <PlanSegment>[];
  var fromDepth = 0.0;
  for (final segment in segments) {
    final toDepth = segment.targetDepth;
    if (!segment.splitAtConfiguredRate || toDepth == fromDepth) {
      result.add(segment);
      fromDepth = toDepth;
      continue;
    }

    final rate = toDepth > fromDepth ? plan.descentRate : plan.ascentRate;
    final travelSeconds = PlanSegment.travelSeconds(
      metres: toDepth - fromDepth,
      ratePerMinute: rate,
    );
    if (travelSeconds >= segment.durationSeconds) {
      result.add(segment);
      fromDepth = toDepth;
      continue;
    }

    result.add(segment.copyWith(durationSeconds: travelSeconds));
    result.add(
      PlanSegment(
        id: '${segment.id}__hold',
        targetDepth: toDepth,
        durationSeconds: segment.durationSeconds - travelSeconds,
        tankId: segment.tankId,
        gasMix: segment.gasMix,
        setpointBar: segment.setpointBar,
        diveModeOverride: segment.diveModeOverride,
        order: segment.order,
      ),
    );
    fromDepth = toDepth;
  }
  return result;
}
