import 'package:equatable/equatable.dart';

import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Derived spec figures for the passport's Cylinder card (spec section 8).
/// Every input is metric; the caller formats for display.
class PassportSpecMetrics extends Equatable {
  /// Litres at 1 bar held at working pressure under the diver's gas model.
  final double? freeGasLiters;

  /// Buoyancy with no gas inside, from the tank physics catalog or the
  /// per-material estimate. Positive floats.
  final double? emptyBuoyancyKg;

  /// [emptyBuoyancyKg] minus the mass of the gas at working pressure.
  final double? fullBuoyancyKg;

  const PassportSpecMetrics({
    this.freeGasLiters,
    this.emptyBuoyancyKg,
    this.fullBuoyancyKg,
  });

  static PassportSpecMetrics compute({
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    double o2Percent = 21,
    double hePercent = 0,
    required GasModel gasModel,
  }) {
    if (volumeL == null) return const PassportSpecMetrics();
    final preset = workingPressureBar == null
        ? null
        : TankPresets.matchBySpecs(volumeL, workingPressureBar);
    final empty = BuoyancyPhysics.tankTermKg(
      presetName: preset?.name,
      volumeL: volumeL,
      workingPressureBar: workingPressureBar,
      material: material,
      reserveBar: 0,
    );
    if (workingPressureBar == null) {
      return PassportSpecMetrics(emptyBuoyancyKg: empty);
    }
    // The same gas model for both figures: free gas in litres at 1 bar, and
    // its mass at the surface density, so the full-cylinder buoyancy agrees
    // with the free gas the diver sees on the line above.
    final freeGas = gasVolume(
      tankSizeLiters: volumeL,
      pressureBar: workingPressureBar,
      o2Percent: o2Percent,
      hePercent: hePercent,
      model: gasModel,
    );
    final gasMass =
        freeGas *
        GasDensity.mixDensityKgPerLBar(
          o2Percent: o2Percent,
          hePercent: hePercent,
        );
    return PassportSpecMetrics(
      freeGasLiters: freeGas,
      emptyBuoyancyKg: empty,
      fullBuoyancyKg: empty - gasMass,
    );
  }

  @override
  List<Object?> get props => [freeGasLiters, emptyBuoyancyKg, fullBuoyancyKg];
}

/// Depth limits of the current mix at the diver's own ppO2 limits.
class PassportGasLimits extends Equatable {
  final double modWorkingM;
  final double modDecoM;

  /// Equivalent narcotic depth at [modWorkingM]; null for a mix without
  /// helium, where it would equal the depth itself.
  final double? endAtWorkingModM;

  const PassportGasLimits({
    required this.modWorkingM,
    required this.modDecoM,
    this.endAtWorkingModM,
  });

  static PassportGasLimits compute({
    required GasMix mix,
    required double ppO2Working,
    required double ppO2Deco,
    required bool o2Narcotic,
  }) {
    final modWorking = mix.mod(ppO2: ppO2Working);
    return PassportGasLimits(
      modWorkingM: modWorking,
      modDecoM: mix.mod(ppO2: ppO2Deco),
      endAtWorkingModM: mix.he > 0
          ? mix.end(modWorking, o2Narcotic: o2Narcotic)
          : null,
    );
  }

  @override
  List<Object?> get props => [modWorkingM, modDecoM, endAtWorkingModM];
}
