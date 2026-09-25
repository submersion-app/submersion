import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';

/// The two gas temperatures the density calculator offers.
///
/// Colder gas is denser, so [zeroC] is the conservative choice and the
/// calculator's default.
enum GasDensityTemperature {
  zeroC(0.0),
  twentyC(20.0);

  final double celsius;
  const GasDensityTemperature(this.celsius);
}

/// Where a density sits against the published work-of-breathing limits.
enum GasDensityLevel { ok, warn, critical }

/// Classify [densityGPerL] against [gasDensityWarnGPerL] and
/// [gasDensityCriticalGPerL]. A value exactly on a limit is still within it.
GasDensityLevel gasDensityLevelFor(double densityGPerL) {
  if (densityGPerL > gasDensityCriticalGPerL) return GasDensityLevel.critical;
  if (densityGPerL > gasDensityWarnGPerL) return GasDensityLevel.warn;
  return GasDensityLevel.ok;
}

class GasDensityInputs {
  /// O2 of the breathing gas (OC) or of the diluent (CCR), in percent.
  final double o2Percent;

  /// He of the breathing gas or diluent, in percent. Clamped to the room the
  /// oxygen leaves.
  final double hePercent;

  final double depthMeters;

  /// CCR setpoint in bar; null means open circuit.
  final double? setpointBar;

  final GasDensityTemperature temperature;

  final WaterType waterType;

  const GasDensityInputs({
    required this.o2Percent,
    required this.hePercent,
    required this.depthMeters,
    required this.setpointBar,
    required this.temperature,
    required this.waterType,
  });

  bool get isCcr => setpointBar != null;
}

class GasDensityResult {
  final double ambientPressureBar;

  /// Partial pressures of the gas actually breathed: the mix itself on open
  /// circuit, the loop on a rebreather.
  final double pO2Bar;
  final double pN2Bar;
  final double pHeBar;

  final double densityGPerL;
  final GasDensityLevel level;

  /// The setpoint is above ambient pressure, so the loop is pure oxygen.
  final bool setpointCapped;

  /// The diluent alone carries more oxygen than the setpoint at this depth,
  /// so the loop runs at the diluent's ppO2 instead.
  final bool diluentAboveSetpoint;

  const GasDensityResult({
    required this.ambientPressureBar,
    required this.pO2Bar,
    required this.pN2Bar,
    required this.pHeBar,
    required this.densityGPerL,
    required this.level,
    required this.setpointCapped,
    required this.diluentAboveSetpoint,
  });

  double get loopO2Percent => _percentOf(pO2Bar);
  double get loopN2Percent => _percentOf(pN2Bar);
  double get loopHePercent => _percentOf(pHeBar);

  double _percentOf(double partial) =>
      ambientPressureBar > 0 ? partial / ambientPressureBar * 100 : 0;
}

/// Density of the breathed gas at depth, on open circuit or on a CCR loop.
///
/// Ambient pressure follows [DiveEnvironment] for the chosen water type at a
/// 1.0 bar surface, the app's convention everywhere else.
///
/// On a rebreather the loop holds the setpoint where it can: shallower than
/// the setpoint the loop is pure oxygen, and where the diluent alone already
/// carries more oxygen than the setpoint, the loop runs at the diluent's
/// ppO2, which is also the denser, more conservative answer. The remaining
/// pressure is split by the diluent's N2:He ratio. No alveolar water vapour
/// is subtracted: density is a property of the gas in the loop.
GasDensityResult computeGasDensity(GasDensityInputs inputs) {
  final fO2 = inputs.o2Percent.clamp(0.0, 100.0) / 100;
  final fHe = inputs.hePercent.clamp(0.0, 100.0 - fO2 * 100) / 100;
  final fN2 = math.max(1.0 - fO2 - fHe, 0.0);

  final depth = math.max(inputs.depthMeters, 0.0);
  final ambient = DiveEnvironment.forConditions(
    waterType: inputs.waterType,
  ).pressureAtDepth(depth);

  double pO2;
  double pN2;
  double pHe;
  var setpointCapped = false;
  var diluentAboveSetpoint = false;

  final setpoint = inputs.setpointBar;
  if (setpoint == null) {
    pO2 = fO2 * ambient;
    pN2 = fN2 * ambient;
    pHe = fHe * ambient;
  } else {
    final diluentPO2 = fO2 * ambient;
    if (setpoint >= ambient) {
      setpointCapped = true;
      pO2 = ambient;
    } else if (diluentPO2 > setpoint) {
      diluentAboveSetpoint = true;
      pO2 = diluentPO2;
    } else {
      pO2 = setpoint;
    }
    final inert = math.max(ambient - pO2, 0.0);
    final inertFraction = fN2 + fHe;
    if (inertFraction <= 0) {
      pO2 = ambient;
      pN2 = 0;
      pHe = 0;
    } else {
      pN2 = inert * fN2 / inertFraction;
      pHe = inert * fHe / inertFraction;
    }
  }

  final density = gasDensityFromPartialPressures(
    pO2Bar: pO2,
    pN2Bar: pN2,
    pHeBar: pHe,
    temperatureC: inputs.temperature.celsius,
  );

  return GasDensityResult(
    ambientPressureBar: ambient,
    pO2Bar: pO2,
    pN2Bar: pN2,
    pHeBar: pHe,
    densityGPerL: density,
    level: gasDensityLevelFor(density),
    setpointCapped: setpointCapped,
    diluentAboveSetpoint: diluentAboveSetpoint,
  );
}
