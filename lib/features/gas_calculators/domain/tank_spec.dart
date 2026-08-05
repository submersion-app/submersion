import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/tank_presets.dart';

/// A cylinder described the way gas planning needs it: water capacity plus a
/// working pressure.
///
/// The distinction matters. An AL80 holds 11.1 L of WATER at 206.8 bar, which
/// is roughly 2296 L of FREE GAS at the surface. Storing free gas where water
/// capacity is expected inflates the divisor by ~200x and drives reserve
/// pressure to near zero -- the defect behind the reported "3 psi".
class TankSpec extends Equatable {
  /// Internal (water) volume in liters.
  final double waterVolumeLiters;

  /// Rated working pressure in bar.
  final double workingPressureBar;

  /// Manufacturer's published free-gas capacity in cubic feet, when the tank
  /// is specified that way. Null for metric tanks, where cuft is not a
  /// meaningful spec.
  final double? ratedCapacityCuft;

  /// Short display label, e.g. "AL80" or "Steel 12L".
  final String label;

  const TankSpec({
    required this.waterVolumeLiters,
    required this.workingPressureBar,
    required this.label,
    this.ratedCapacityCuft,
  });

  /// Free gas at the surface, in liters, at the rated working pressure.
  ///
  /// Ideal-gas figure. It runs a few percent above the manufacturer's rated
  /// capacity for high-pressure cylinders because it ignores compressibility;
  /// that is acceptable for planning and matches what the rest of the app
  /// already does in [TankPreset.volumeCuft].
  double get freeGasLiters => waterVolumeLiters * workingPressureBar;

  factory TankSpec.fromPreset(TankPreset preset) => TankSpec(
    waterVolumeLiters: preset.volumeLiters,
    workingPressureBar: preset.workingPressureBar,
    ratedCapacityCuft: preset.ratedCapacityCuft,
    label: preset.displayName,
  );

  @override
  List<Object?> get props => [
    waterVolumeLiters,
    workingPressureBar,
    ratedCapacityCuft,
    label,
  ];
}

/// The default cylinder, used as the initial state of both calculators.
TankSpec defaultTankSpec() => TankSpec.fromPreset(TankPresets.steel12);

/// Cylinder choices offered to divers using liters, ascending.
List<TankSpec> metricTankChoices() => [
  TankSpec.fromPreset(TankPresets.steel10),
  TankSpec.fromPreset(TankPresets.steel12),
  TankSpec.fromPreset(TankPresets.steel15),
];

/// Cylinder choices offered to divers using cubic feet, ascending.
///
/// Working pressures differ per tank -- 206.8 bar for aluminium, 237.3 for
/// high-pressure steel. The previous code assumed a flat 200 bar for all of
/// them.
List<TankSpec> imperialTankChoices() => [
  TankSpec.fromPreset(TankPresets.al63),
  TankSpec.fromPreset(TankPresets.al80),
  TankSpec.fromPreset(TankPresets.hp100),
  TankSpec.fromPreset(TankPresets.hp120),
];
