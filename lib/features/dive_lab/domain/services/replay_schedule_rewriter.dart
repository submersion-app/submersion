import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A hypothetical cylinder as a carried tank (deco role so the optimal
/// ascent treats it as a deco gas).
DiveTank hypotheticalTank(HypotheticalTankRef ref) => DiveTank(
  id: ref.tankId,
  name: ref.gasMix.name,
  volume: ref.volumeLiters,
  startPressure: ref.startPressureBar,
  gasMix: ref.gasMix,
  role: TankRole.deco,
);

/// The bailout cylinders a [BailOutIntervention] breathes: the named tank,
/// the hypothetical one, or every bailout-role tank carried.
List<DiveTank> bailoutPool(BailOutIntervention i, List<DiveTank> tanks) {
  final ref = i.tank;
  if (ref is HypotheticalTankRef) return [hypotheticalTank(ref)];
  if (ref is ExistingTankRef) {
    return tanks.where((t) => t.id == ref.tankId).toList();
  }
  return tanks.where((t) => t.role == TankRole.bailout).toList();
}

/// The breathing schedule the replay timeline follows: the actual schedule
/// with the interventions applied from [branchTimestamp]. Returns [actual]
/// itself when nothing changes.
TankSchedule rewriteScheduleForReplay({
  required TankSchedule actual,
  required List<ScenarioIntervention> interventions,
  required int branchTimestamp,
  required List<int> timestamps,
  required List<double> depths,
  required double maxPpO2,
}) {
  var schedule = actual;
  for (final i in interventions) {
    if (i is SwitchGasIntervention) {
      final ref = i.tank;
      schedule = switch (ref) {
        ExistingTankRef(:final tankId) => schedule.switchedTo(
          tankId,
          fromTimestamp: branchTimestamp,
        ),
        HypotheticalTankRef() => schedule.switchedTo(
          ref.tankId,
          fromTimestamp: branchTimestamp,
          addedTank: hypotheticalTank(ref),
        ),
      };
    }
  }
  for (final i in interventions) {
    if (i is LoseTankIntervention) {
      schedule = substituteTankByDepth(
        schedule,
        lostTankId: i.tankId,
        fromTimestamp: branchTimestamp,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: maxPpO2,
      );
    }
  }
  for (final i in interventions) {
    if (i is BailOutIntervention) {
      final pool = bailoutPool(i, schedule.tanks);
      if (pool.isEmpty) continue;
      final tanks = [
        ...schedule.tanks,
        for (final t in pool)
          if (!schedule.tanks.any((x) => x.id == t.id)) t,
      ];
      final diveEnd = timestamps.isEmpty ? branchTimestamp : timestamps.last;
      schedule = TankSchedule(
        intervals: TankSchedule.collapseIntervals([
          ...schedule.intervals.where(
            (iv) => iv.startTimestamp < branchTimestamp,
          ),
          ...intervalsByDepth(
            pool: pool,
            fromTimestamp: branchTimestamp,
            toTimestamp: diveEnd + 1,
            timestamps: timestamps,
            depths: depths,
            maxPpO2: maxPpO2,
          ),
        ]),
        tanks: tanks,
      );
    }
  }
  return schedule;
}
