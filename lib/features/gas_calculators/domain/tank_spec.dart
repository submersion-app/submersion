import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';

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
  /// Under [GasModel.ideal] this is simply water volume times working
  /// pressure, which runs a few percent above the manufacturer's rated
  /// capacity for high-pressure cylinders because it ignores compressibility.
  /// Under [GasModel.real] it honors compressibility and lands close to the
  /// rated figure (issue #828).
  double freeGasLitersFor(GasModel model) => gasVolume(
    tankSizeLiters: waterVolumeLiters,
    pressureBar: workingPressureBar,
    o2Percent: 21,
    model: model,
  );

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

/// Cylinder choices a gas blender actually fills, named by the reporter of
/// issue #1100: the small decant bottles oxygen and helium come in, a common
/// aluminium single, and a steel twinset.
///
/// Deliberately separate from [metricTankChoices] and [imperialTankChoices],
/// which describe what a diver breathes from. A blending bench sees 2 and 3
/// litre bottles that never go in the water, and it sees a twinset as one
/// 24 litre vessel rather than as a pair.
List<TankSpec> blenderTankChoices() => [
  const TankSpec(waterVolumeLiters: 2, workingPressureBar: 200, label: '2 L'),
  const TankSpec(waterVolumeLiters: 3, workingPressureBar: 200, label: '3 L'),
  TankSpec.fromPreset(TankPresets.al80),
  const TankSpec(
    waterVolumeLiters: 24,
    workingPressureBar: 232,
    label: 'Steel 12 L twinset',
  ),
];
