import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// The gas switches a planned dive makes, for its entry in the log (issue
/// #3565): wherever the breathed cylinder changes, on the fly during an
/// ascent as much as at a stop, at the time and depth the change happens.
///
/// The [schedule]'s lines leave out the travel between stops (see
/// [PlanScheduleRow.foldedTravel]), so that is walked too: a leg into a
/// switch stop is still on the gas it left, and a switch can fall partway up
/// a folded leg. The dive's first gas is written as a switch at the start
/// only when the log would otherwise start the entry on another cylinder
/// (see [startingTankOf]), as a plan descending on a travel gas does.
///
/// Each goes on the tank of [entryTanks] matching the plan tank of
/// [planTanks] by position, while it holds that gas, else on the first
/// holding that gas. A stretch with no such tank has nothing to switch to,
/// and is left out.
List<GasSwitch> plannedGasSwitches(
  List<PlanScheduleRow> schedule, {
  required List<DiveTank> planTanks,
  required List<DiveTank> entryTanks,
  required String diveId,
  required DateTime createdAt,
}) {
  bool holds(DiveTank tank, double fO2, double fHe) =>
      (tank.gasMix.o2 / 100 - fO2).abs() < 0.005 &&
      (tank.gasMix.he / 100 - fHe).abs() < 0.005;

  DiveTank? entryTankFor(String? planTankId, double fO2, double fHe) {
    final position = planTanks.indexWhere((t) => t.id == planTankId);
    if (position >= 0 &&
        position < entryTanks.length &&
        holds(entryTanks[position], fO2, fHe)) {
      return entryTanks[position];
    }
    return entryTanks.where((t) => holds(t, fO2, fHe)).firstOrNull;
  }

  final switches = <GasSwitch>[];
  String? breathing;
  var started = false;
  void breathe(DiveTank? tank, int at, double depth) {
    if (tank == null || tank.id == breathing) return;
    final first = !started;
    started = true;
    breathing = tank.id;
    if (first) {
      final logStart = startingTankOf(
        tanks: entryTanks,
        switches: const [],
        diveStart: 0,
      );
      if (logStart?.id == tank.id) return;
    }
    switches.add(
      GasSwitch(
        id: '',
        diveId: diveId,
        timestamp: at,
        tankId: tank.id,
        depth: depth,
        createdAt: createdAt,
      ),
    );
  }

  // Where the dive is as each stretch starts: a line's time and depth are
  // where it ends, and the next stretch starts there.
  var time = 0;
  var depth = 0.0;
  for (final row in schedule) {
    for (final leg in row.foldedTravel) {
      final gas = planTanks.where((t) => t.id == leg.tankId).firstOrNull;
      if (gas != null) {
        breathe(
          entryTankFor(leg.tankId, gas.gasMix.o2 / 100, gas.gasMix.he / 100),
          time,
          leg.fromDepthMeters,
        );
      }
      time += leg.seconds;
      depth = leg.toDepthMeters;
    }
    breathe(
      entryTankFor(row.tankId, row.gasFO2, row.gasFHe),
      row.startRuntimeSeconds,
      depth,
    );
    time = row.runtimeSeconds;
    depth = row.depthMeters;
  }
  return switches;
}
