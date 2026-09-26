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

/// Molar mass of air as the app defines it everywhere, 21/79.
const double _airMolarMassGPerMol =
    0.21 * o2MolarMassGPerMol + 0.79 * n2MolarMassGPerMol;

/// Where a density sits against the published work-of-breathing limits.
enum GasDensityLevel { ok, warn, critical }

/// Classify [densityGPerL] against [gasDensityWarnGPerL] and
/// [gasDensityCriticalGPerL]. A value exactly on a limit is still within it.
GasDensityLevel gasDensityLevelFor(double densityGPerL) {
  if (densityGPerL > gasDensityCriticalGPerL) return GasDensityLevel.critical;
  if (densityGPerL > gasDensityWarnGPerL) return GasDensityLevel.warn;
  return GasDensityLevel.ok;
}

/// [gasDensityLevelFor] on the value as displayed with [fractionDigits]
/// decimals, so the status never contradicts the number beside it: 5.2004
/// shows as 5.20 and is therefore within the 5.2 limit.
GasDensityLevel gasDensityLevelForDisplay(
  double densityGPerL,
  int fractionDigits,
) => gasDensityLevelFor(
  double.parse(densityGPerL.toStringAsFixed(fractionDigits)),
);

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

  /// [openCircuit] clears the setpoint, which a null [setpointBar] cannot.
  GasDensityInputs copyWith({
    double? o2Percent,
    double? hePercent,
    double? depthMeters,
    double? setpointBar,
    bool openCircuit = false,
    GasDensityTemperature? temperature,
    WaterType? waterType,
  }) => GasDensityInputs(
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    depthMeters: depthMeters ?? this.depthMeters,
    setpointBar: openCircuit ? null : setpointBar ?? this.setpointBar,
    temperature: temperature ?? this.temperature,
    waterType: waterType ?? this.waterType,
  );
}

class GasDensityResult {
  final double ambientPressureBar;

  /// Partial pressures of the gas actually breathed: the mix itself on open
  /// circuit, the loop on a rebreather.
  final double pO2Bar;
  final double pN2Bar;
  final double pHeBar;

  /// Unrounded. Classify it with [gasDensityLevelForDisplay] at the
  /// precision it is shown at, so the status matches the number.
  final double densityGPerL;

  /// Equivalent air density depth: the depth, in the same water, at which
  /// air (21/79) would be as dense as this gas. Independent of temperature,
  /// and never negative: a gas lighter than surface air gives 0.
  final double eaddMeters;

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
    required this.eaddMeters,
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
/// Ambient pressure follows [DiveEnvironment] for the chosen water type
/// (salt 1025 kg/m3, fresh 1000 kg/m3) at a 1.0 bar surface, as the deco
/// calculator and planner do. The other gas calculators use a flat 1 bar per
/// 10 m, so at the same depth this one sees a slightly different pressure.
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
  final environment = DiveEnvironment.forConditions(
    waterType: inputs.waterType,
  );
  final ambient = environment.pressureAtDepth(depth);

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
    // Strictly above: at equality the setpoint itself fills the loop with
    // oxygen, and the "above ambient" hint would be untrue.
    if (setpoint > ambient) {
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

  // Air at this pressure has the same density at any temperature, since
  // R * T cancels between the two.
  final equivalentAirPressure =
      (pO2 * o2MolarMassGPerMol +
          pN2 * n2MolarMassGPerMol +
          pHe * heMolarMassGPerMol) /
      _airMolarMassGPerMol;
  final eadd = math.max(
    environment.depthAtPressure(equivalentAirPressure),
    0.0,
  );

  return GasDensityResult(
    ambientPressureBar: ambient,
    pO2Bar: pO2,
    pN2Bar: pN2,
    pHeBar: pHe,
    densityGPerL: density,
    eaddMeters: eadd,
    setpointCapped: setpointCapped,
    diluentAboveSetpoint: diluentAboveSetpoint,
  );
}
