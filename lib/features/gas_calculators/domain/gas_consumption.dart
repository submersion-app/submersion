import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

/// Round [value] up to the next multiple of [grid].
///
/// Used where rounding must favour a larger reserve: a diver who turns the
/// dive 10 bar early is fine, one who turns it 10 bar late may not be.
double roundUpTo(double value, double grid) => (value / grid).ceil() * grid;

/// Round [value] down to the previous multiple of [grid].
///
/// Used where rounding must favour a shallower or leaner limit, such as MOD
/// and best-mix oxygen fraction.
double roundDownTo(double value, double grid) => (value / grid).floor() * grid;

class ConsumptionInputs {
  final double avgDepthMeters;
  final int minutes;
  final double sacLitersPerMin;
  final TankSpec tank;

  const ConsumptionInputs({
    required this.avgDepthMeters,
    required this.minutes,
    required this.sacLitersPerMin,
    required this.tank,
  });
}

class ConsumptionResult {
  final double litersConsumed;
  final double barConsumed;
  final double litersRemaining;
  final double barRemaining;

  /// Whether the plan needs more gas than the cylinder holds at its own
  /// working pressure -- not against a flat 200 bar assumption.
  final bool exceedsTank;

  /// Surface-equivalent consumption rate at the planned depth.
  final double gasAtDepthLitersPerMin;

  const ConsumptionResult({
    required this.litersConsumed,
    required this.barConsumed,
    required this.litersRemaining,
    required this.barRemaining,
    required this.exceedsTank,
    required this.gasAtDepthLitersPerMin,
  });
}

/// Gas used over a square-profile dive segment.
ConsumptionResult computeConsumption(ConsumptionInputs inputs) {
  final pressure = ambientPressureAtDepth(inputs.avgDepthMeters);
  final atDepth = inputs.sacLitersPerMin * pressure;
  final consumed = atDepth * inputs.minutes;

  final water = inputs.tank.waterVolumeLiters;
  final barConsumed = water > 0 ? consumed / water : 0.0;

  return ConsumptionResult(
    litersConsumed: consumed,
    barConsumed: barConsumed,
    litersRemaining: inputs.tank.freeGasLiters - consumed,
    barRemaining: inputs.tank.workingPressureBar - barConsumed,
    exceedsTank: barConsumed > inputs.tank.workingPressureBar,
    gasAtDepthLitersPerMin: atDepth,
  );
}
