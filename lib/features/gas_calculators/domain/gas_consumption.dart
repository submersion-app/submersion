import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;
import 'package:submersion/core/utils/gas_compressibility.dart';
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

  /// Equation of state used to price the cylinder's contents (issue #828).
  final GasModel gasModel;

  const ConsumptionInputs({
    required this.avgDepthMeters,
    required this.minutes,
    required this.sacLitersPerMin,
    required this.tank,
    this.gasModel = GasModel.real,
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
  final freeGas = inputs.tank.freeGasLitersFor(inputs.gasModel);

  // The plan overruns the cylinder when it wants more gas than the cylinder
  // holds. Deciding this on liters rather than on bar keeps the flag right
  // when the pressure conversion saturates at empty.
  final exceeds = consumed > freeGas;

  // Bar the plan costs: the working pressure less whatever pressure still
  // holds the leftover gas, so the conversion honors the same gas model in
  // both directions. Past empty there is no cylinder left to model, so the
  // surplus is priced at the cylinder's nominal rate -- enough to keep
  // barConsumed above the working pressure and agree with [exceeds].
  final double barConsumed;
  if (water <= 0) {
    barConsumed = 0.0;
  } else if (exceeds) {
    barConsumed = inputs.tank.workingPressureBar + (consumed - freeGas) / water;
  } else {
    barConsumed =
        inputs.tank.workingPressureBar -
        pressureHoldingVolume(
          tankSizeLiters: water,
          litersRequired: freeGas - consumed,
          o2Percent: 21,
          model: inputs.gasModel,
        );
  }

  return ConsumptionResult(
    litersConsumed: consumed,
    barConsumed: barConsumed,
    litersRemaining: freeGas - consumed,
    barRemaining: inputs.tank.workingPressureBar - barConsumed,
    exceedsTank: exceeds,
    gasAtDepthLitersPerMin: atDepth,
  );
}
