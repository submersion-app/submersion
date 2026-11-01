import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// The cylinder [stop]'s air break is breathed from, or null on a stop with no
/// air break: whichever [tankForGas] finds for the break gas [plan] offers at
/// the stop's depth, or [stopTankId] when it offers none.
String? airBreakTankIdFor(
  DecoStop stop, {
  required AscentGasPlan plan,
  required String? stopTankId,
  required String? Function(double fO2, double fHe) tankForGas,
}) {
  if (stop.airBreakSeconds == 0) return null;
  final breakGas = plan.breakGasForDepth(stop.depthMeters);
  return breakGas != null ? tankForGas(breakGas.fO2, breakGas.fHe) : stopTankId;
}

/// The runs of a stop of [stopSeconds] with air breaks: alternating spells
/// on the stop gas and on the break gas, in order.
///
/// Follows the scheduler's own sequence (`BuhlmannAlgorithm._stopGasChunks`):
/// each whole minute, and the part minute at the end, takes the gas for the
/// point in the [policy]'s cycle where that minute starts. Replaying a stop
/// in these runs loads the tissues as the scheduler did when it timed it.
List<({bool onBreak, int seconds})> airBreakRuns(
  int stopSeconds,
  AirBreakPolicy policy,
) {
  final cycle = policy.o2Seconds + policy.breakSeconds;
  final runs = <({bool onBreak, int seconds})>[];
  for (var start = 0; start < stopSeconds; start += 60) {
    final seconds = stopSeconds - start < 60 ? stopSeconds - start : 60;
    final onBreak = start % cycle >= policy.o2Seconds;
    if (runs.isNotEmpty && runs.last.onBreak == onBreak) {
      final last = runs.removeLast();
      runs.add((onBreak: onBreak, seconds: last.seconds + seconds));
    } else {
      runs.add((onBreak: onBreak, seconds: seconds));
    }
  }
  return runs;
}
