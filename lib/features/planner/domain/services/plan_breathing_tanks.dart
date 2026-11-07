import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

const _uuid = Uuid();

/// The cylinder a new plan starts with: an AL80 of air at the plan fill
/// pressure.
DiveTank defaultPlanTank({required String id}) => DiveTank(
  id: id,
  name: 'Primary',
  volume: 11.1, // AL80
  workingPressure: 207.0,
  startPressure: TankPresets.planFillPressureBar,
  gasMix: const GasMix(o2: 21, he: 0),
  role: TankRole.backGas,
  order: 0,
);

/// A plan's tanks and segments holding breathing gas only (issue #4243).
typedef BreathingPlanParts = ({
  List<DiveTank> tanks,
  List<PlanSegment> segments,
});

/// [tanks] and [segments] with every suit inflation bottle stripped.
///
/// A plan is breathing gas: the engine plans deco, reserves and bailouts on
/// every tank it is given, so a suit inflation bottle must never reach one.
/// Every way into a plan (the What-if conversion, a saved cylinder, a stored
/// or imported plan) strips it. A segment that named a stripped bottle moves
/// to the first remaining tank and takes its gas, since the engine reads a
/// segment's own mix. A plan whose only tanks are bottles gets a new plan's
/// cylinder ([defaultPlanTank]) in their place, since the engine needs one
/// tank to plan on; a bottle's own volume and mix are never planned on.
///
/// Returns the same lists when there is no bottle.
BreathingPlanParts breathingPlanParts(
  List<DiveTank> tanks,
  List<PlanSegment> segments,
) {
  if (tanks.every((t) => t.role.isBreathingGas)) {
    return (tanks: tanks, segments: segments);
  }
  final breathing = [
    for (final tank in tanks)
      if (tank.role.isBreathingGas) tank,
  ];
  final stripped = {
    for (final tank in tanks)
      if (!tank.role.isBreathingGas) tank.id,
  };
  final fallback = breathing.firstOrNull ?? defaultPlanTank(id: _uuid.v4());
  return (
    tanks: breathing.isEmpty ? [fallback] : breathing,
    segments: [
      for (final segment in segments)
        stripped.contains(segment.tankId)
            ? segment.copyWith(tankId: fallback.id, gasMix: fallback.gasMix)
            : segment,
    ],
  );
}

/// [plan] holding breathing gas only; see [breathingPlanParts]. Returns
/// [plan] itself when it holds no bottle.
DivePlanState withoutSuitInflationCylinders(DivePlanState plan) {
  final parts = breathingPlanParts(plan.tanks, plan.segments);
  if (identical(parts.tanks, plan.tanks)) return plan;
  return plan.copyWith(tanks: parts.tanks, segments: parts.segments);
}
