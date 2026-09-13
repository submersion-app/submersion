import 'package:submersion/core/constants/tank_presets.dart';

/// Litre-bar per cubic foot of gas at the surface, the constant
/// `UnitFormatter.formatTankVolume` uses.
const _literBarPerCuft = 28.3168;

/// The working pressure `UnitFormatter.formatTankVolume` assumes when a
/// tank has none. The CSV reader assumes the same, so a blank pressure
/// still round trips.
const double assumedWorkingPressureBar = 200;

double? _pressureOrNull(double? bar) => bar != null && bar > 0 ? bar : null;

/// The number an imperial diver knows a cylinder by: the preset's rated
/// capacity when [volumeLiters] and [workingPressureBar] match one (exactly
/// what the app displays), otherwise the ideal-gas capacity.
double ratedCapacityCuft(double volumeLiters, double? workingPressureBar) {
  final pressure = _pressureOrNull(workingPressureBar);
  if (pressure != null) {
    final rated = TankPresets.matchBySpecs(
      volumeLiters,
      pressure,
    )?.ratedCapacityCuft;
    if (rated != null) return rated;
  }
  return volumeLiters *
      (pressure ?? assumedWorkingPressureBar) /
      _literBarPerCuft;
}

/// Inverse of [ratedCapacityCuft]: the physical volume in litres.
double volumeLitersFromCapacity(double cuft, double? workingPressureBar) {
  final pressure = _pressureOrNull(workingPressureBar);
  if (pressure != null) {
    final preset = TankPresets.matchByCapacity(cuft, pressure);
    if (preset != null) return preset.volumeLiters;
  }
  return cuft * _literBarPerCuft / (pressure ?? assumedWorkingPressureBar);
}
