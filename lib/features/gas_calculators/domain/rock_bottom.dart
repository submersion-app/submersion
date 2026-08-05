import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

/// Ambient pressure in bar at [depthMeters] of seawater.
double ambientPressureAtDepth(double depthMeters) => depthMeters / 10.0 + 1.0;

/// Inputs to a minimum-gas (rock bottom) calculation.
///
/// All values are canonical: meters, meters per minute, liters per minute,
/// minutes.
class RockBottomInputs {
  final double depthMeters;
  final double ascentRateMetersPerMin;
  final double diverSacLitersPerMin;
  final double buddySacLitersPerMin;

  /// Time budgeted at depth to solve the problem before ascending.
  ///
  /// Standard minimum-gas practice (GUE/UTD) budgets this; omitting it
  /// understates the requirement, because the whole point of the reserve is
  /// that something has already gone wrong.
  final double solveMinutes;

  final bool includeSafetyStop;
  final double safetyStopDepthMeters;
  final double safetyStopMinutes;
  final TankSpec tank;

  const RockBottomInputs({
    required this.depthMeters,
    required this.ascentRateMetersPerMin,
    required this.diverSacLitersPerMin,
    required this.buddySacLitersPerMin,
    required this.solveMinutes,
    required this.includeSafetyStop,
    required this.tank,
    this.safetyStopDepthMeters = 5.0,
    this.safetyStopMinutes = 3.0,
  });

  /// Both divers breathing from one cylinder during an air share.
  double get combinedSacLitersPerMin =>
      diverSacLitersPerMin + buddySacLitersPerMin;
}

/// Per-phase breakdown of the gas required to surface from depth.
class RockBottomResult {
  final double solveGasLiters;
  final double ascentGasLiters;
  final double safetyStopGasLiters;
  final double finalAscentGasLiters;
  final double totalLiters;

  /// Reserve expressed as a pressure in the given cylinder.
  final double reserveBar;

  final double ascentMinutes;
  final double totalMinutes;

  const RockBottomResult({
    required this.solveGasLiters,
    required this.ascentGasLiters,
    required this.safetyStopGasLiters,
    required this.finalAscentGasLiters,
    required this.totalLiters,
    required this.reserveBar,
    required this.ascentMinutes,
    required this.totalMinutes,
  });
}

/// Compute the minimum gas both divers need to reach the surface from depth.
///
/// Four phases, every one of them driven by the caller's ascent rate. Each
/// ascent phase is priced at the arithmetic mean depth of that phase, which is
/// exact for a constant-rate ascent.
RockBottomResult computeRockBottom(RockBottomInputs inputs) {
  final combined = inputs.combinedSacLitersPerMin;
  final rate = inputs.ascentRateMetersPerMin;
  final stopDepth = inputs.includeSafetyStop
      ? inputs.safetyStopDepthMeters
      : 0.0;

  // Phase 1: solve the problem at depth.
  final solveGas =
      combined *
      ambientPressureAtDepth(inputs.depthMeters) *
      inputs.solveMinutes;

  // Phase 2: ascend from depth to the stop (or straight to the surface).
  final ascentDistance = (inputs.depthMeters - stopDepth).clamp(
    0.0,
    double.infinity,
  );
  final ascentMinutes = rate > 0 ? ascentDistance / rate : 0.0;
  final ascentGas =
      combined *
      ambientPressureAtDepth((inputs.depthMeters + stopDepth) / 2) *
      ascentMinutes;

  // Phase 3: hold the safety stop.
  final stopGas = inputs.includeSafetyStop
      ? combined * ambientPressureAtDepth(stopDepth) * inputs.safetyStopMinutes
      : 0.0;

  // Phase 4: ascend the last few meters at the same rate.
  final finalMinutes = inputs.includeSafetyStop && rate > 0
      ? stopDepth / rate
      : 0.0;
  final finalGas = inputs.includeSafetyStop
      ? combined * ambientPressureAtDepth(stopDepth / 2) * finalMinutes
      : 0.0;

  final total = solveGas + ascentGas + stopGas + finalGas;

  return RockBottomResult(
    solveGasLiters: solveGas,
    ascentGasLiters: ascentGas,
    safetyStopGasLiters: stopGas,
    finalAscentGasLiters: finalGas,
    totalLiters: total,
    // Water capacity, never free gas -- see TankSpec.
    reserveBar: inputs.tank.waterVolumeLiters > 0
        ? total / inputs.tank.waterVolumeLiters
        : 0.0,
    ascentMinutes: ascentMinutes,
    totalMinutes:
        inputs.solveMinutes +
        ascentMinutes +
        (inputs.includeSafetyStop ? inputs.safetyStopMinutes : 0.0) +
        finalMinutes,
  );
}
