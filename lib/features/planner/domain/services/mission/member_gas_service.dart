import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Gas one team member breathes over a schedule, from their own SAC.
///
/// The plan engine charges gas at the plan's single SAC; a mission has one
/// SAC per member, so consumption is re-derived from the engine's schedule
/// rows (depth and duration) instead of running the engine once per member.
class MemberGasService {
  const MemberGasService();

  /// Surface litres breathed per tank id over [rows]. A travel row is charged
  /// at the mean of its start depth (the previous row's end, or [startDepth]
  /// for the first row) and its end depth; a level or stop row at its own
  /// depth. A stop's air break is charged to the cylinder it is breathed
  /// from, at the same depth and rate as the rest of the stop. [sacFor] gives
  /// the litres per minute in force on a row. Pass [startDepth] when [rows]
  /// are a slice of a dive that does not begin at the surface.
  Map<String, double> litersByTank({
    required List<PlanScheduleRow> rows,
    required DiveEnvironment environment,
    required double Function(PlanScheduleRow row) sacFor,
    double startDepth = 0.0,
  }) {
    final liters = <String, double>{};
    var previousDepth = startDepth;
    for (final row in rows) {
      final isTravel =
          row.kind == PlanScheduleRowKind.descent ||
          row.kind == PlanScheduleRowKind.ascent;
      final depth = isTravel
          ? (previousDepth + row.depthMeters) / 2.0
          : row.depthMeters;
      previousDepth = row.depthMeters;
      final tankId = row.tankId;
      if (tankId == null) continue;
      final litersPerMinute = sacFor(row) * environment.pressureAtDepth(depth);
      void charge(String id, int seconds) {
        liters[id] = (liters[id] ?? 0.0) + seconds / 60.0 * litersPerMinute;
      }

      charge(tankId, row.durationSeconds - row.airBreakSeconds);
      charge(row.airBreakTankId ?? tankId, row.airBreakSeconds);
    }
    return liters;
  }

  /// Pressure left in [tank] after [litersUsed], or null when the tank has no
  /// start pressure or no volume.
  double? remainingBar({
    required DiveTank tank,
    required double litersUsed,
    required GasModel model,
  }) {
    final start = tank.startPressure;
    final volume = tank.volume;
    if (start == null || volume == null) return null;
    return pressureAfterConsuming(
      tankSizeLiters: volume,
      startPressureBar: start,
      litersConsumed: litersUsed,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: model,
    );
  }
}
