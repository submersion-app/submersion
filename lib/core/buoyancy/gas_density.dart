import 'package:submersion/core/buoyancy/buoyancy_physics.dart';

/// Mass density of breathing-gas mixes per liter of cylinder volume per bar.
///
/// Component molar masses are scaled so that atmospheric air reproduces
/// [BuoyancyPhysics.airDensityKgPerLBar] exactly, keeping the twin's tank
/// math consistent with the static weight-prediction engine.
class GasDensity {
  static const double _molarMassO2 = 31.998;
  static const double _molarMassN2 = 28.014;
  static const double _molarMassHe = 4.0026;
  static const double _molarMassAir = 28.9647;

  static double mixDensityKgPerLBar({
    required double o2Percent,
    required double hePercent,
  }) {
    final o2 = o2Percent / 100.0;
    final he = hePercent / 100.0;
    final n2 = (1.0 - o2 - he).clamp(0.0, 1.0);
    final molarMass = o2 * _molarMassO2 + n2 * _molarMassN2 + he * _molarMassHe;
    return BuoyancyPhysics.airDensityKgPerLBar * molarMass / _molarMassAir;
  }
}
