import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// The gas switches a planned dive makes, for its entry in the log (issue
/// #3565): every line of [schedule] the plan changes gas on, on the fly during
/// an ascent as much as at a stop, at the start of that line. The first line is
/// only the gas the dive starts on.
///
/// Each goes on the tank of [entryTanks] matching the line's own tank of
/// [planTanks] by position, while it holds that gas, else on the first holding
/// that gas. A line with no such tank has nothing to switch to, and is left out.
List<GasSwitch> plannedGasSwitches(
  List<PlanScheduleRow> schedule, {
  required List<DiveTank> planTanks,
  required List<DiveTank> entryTanks,
  required String diveId,
  required DateTime createdAt,
}) {
  bool holds(DiveTank tank, PlanScheduleRow row) =>
      (tank.gasMix.o2 / 100 - row.gasFO2).abs() < 0.005 &&
      (tank.gasMix.he / 100 - row.gasFHe).abs() < 0.005;

  final switches = <GasSwitch>[];
  for (var i = 1; i < schedule.length; i++) {
    final row = schedule[i];
    if (!row.gasSwitch) continue;
    final position = planTanks.indexWhere((t) => t.id == row.tankId);
    final tank =
        position >= 0 &&
            position < entryTanks.length &&
            holds(entryTanks[position], row)
        ? entryTanks[position]
        : entryTanks.where((t) => holds(t, row)).firstOrNull;
    if (tank == null) continue;
    switches.add(
      GasSwitch(
        id: '',
        diveId: diveId,
        // A line's time and depth are where it ends; it starts where the line
        // before it did.
        timestamp: row.runtimeSeconds - row.durationSeconds,
        tankId: tank.id,
        depth: schedule[i - 1].depthMeters,
        createdAt: createdAt,
      ),
    );
  }
  return switches;
}
