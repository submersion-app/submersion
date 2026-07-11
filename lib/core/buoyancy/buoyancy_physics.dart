import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';

/// Empty-tank buoyancy and dry mass keyed by TankPresets name.
///
/// Initial values cross-checked against manufacturer spec sheets during
/// implementation; the near-empty convention subtracts the reserve-gas
/// mass at prediction time (see [BuoyancyPhysics.tankTermKg]).
const Map<String, ({double emptyBuoyancyKg, double dryMassKg})> kTankCatalog = {
  'al40': (emptyBuoyancyKg: 0.9, dryMassKg: 6.8),
  'al63': (emptyBuoyancyKg: 1.2, dryMassKg: 12.2),
  'al80': (emptyBuoyancyKg: 1.7, dryMassKg: 14.2),
  'hp80': (emptyBuoyancyKg: -1.3, dryMassKg: 13.0),
  'hp100': (emptyBuoyancyKg: -1.0, dryMassKg: 15.0),
  'hp120': (emptyBuoyancyKg: -1.4, dryMassKg: 18.0),
  'lp85': (emptyBuoyancyKg: -0.5, dryMassKg: 14.5),
  'steel10': (emptyBuoyancyKg: -1.2, dryMassKg: 12.5),
  'steel12': (emptyBuoyancyKg: -1.4, dryMassKg: 14.5),
  'steel15': (emptyBuoyancyKg: -1.8, dryMassKg: 17.5),
  'al30Stage': (emptyBuoyancyKg: 0.5, dryMassKg: 5.5),
  'al40Stage': (emptyBuoyancyKg: 0.9, dryMassKg: 6.8),
};

/// Deterministic buoyancy terms for weight prediction: never learned,
/// computed the same for every diver.
///
/// Sign convention throughout: positive = buoyant = needs lead to offset;
/// negative = sinks = counts as ballast.
class BuoyancyPhysics {
  /// Reference density: predictions are baselined to salt water.
  static const double densitySaltKgL = 1.025;
  static const double densityBrackishKgL = 1.010;
  static const double densityFreshKgL = 1.000;

  /// Assumed body mass when the diver has no weight entry (confidence is
  /// capped in that case).
  static const double defaultBodyMassKg = 75.0;

  /// The weighting convention is neutral at the safety stop with reserve
  /// gas remaining.
  static const double defaultReserveBar = 50.0;

  /// Air mass per liter of water volume per bar (~1.225 g/L at 1 bar).
  static const double airDensityKgPerLBar = 0.001225;

  static const double _defaultVolumeL = 11.0;

  static double _density(WaterType waterType) => switch (waterType) {
    WaterType.salt => densitySaltKgL,
    WaterType.brackish => densityBrackishKgL,
    WaterType.fresh => densityFreshKgL,
  };

  /// Lead-equivalent shift vs the salt-water baseline, scaled by the total
  /// displaced mass (body + rig). Negative in fresh water: less lead needed.
  static double waterTermKg({
    required WaterType? waterType,
    required double totalMassKg,
  }) {
    if (waterType == null) return 0.0;
    return totalMassKg * (_density(waterType) / densitySaltKgL - 1.0);
  }

  /// Near-empty buoyancy of one tank: the catalog (or per-material
  /// fallback) empty value minus the mass of the reserve gas.
  ///
  /// Resolution order: explicit [presetName] in the catalog, then
  /// TankPresets.matchBySpecs(volume, working pressure), then a
  /// per-material per-liter estimate.
  static double tankTermKg({
    String? presetName,
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    double reserveBar = defaultReserveBar,
  }) {
    final entry = _catalogEntry(presetName, volumeL, workingPressureBar);
    final volume = volumeL ?? _presetVolume(presetName) ?? _defaultVolumeL;
    final emptyBuoyancy =
        entry?.emptyBuoyancyKg ?? volume * _materialPerLiter(material);
    return emptyBuoyancy - volume * reserveBar * airDensityKgPerLBar;
  }

  /// Approximate tank dry mass (for displacement scaling of the water
  /// term).
  static double tankDryMassKg({
    String? presetName,
    double? volumeL,
    TankMaterial? material,
  }) {
    final entry = _catalogEntry(presetName, volumeL, null);
    if (entry != null) return entry.dryMassKg;
    return (volumeL ?? _defaultVolumeL) * 1.3;
  }

  static ({double emptyBuoyancyKg, double dryMassKg})? _catalogEntry(
    String? presetName,
    double? volumeL,
    double? workingPressureBar,
  ) {
    if (presetName != null && kTankCatalog.containsKey(presetName)) {
      return kTankCatalog[presetName];
    }
    if (volumeL != null && workingPressureBar != null) {
      final match = TankPresets.matchBySpecs(volumeL, workingPressureBar);
      if (match != null) return kTankCatalog[match.name];
    }
    return null;
  }

  static double? _presetVolume(String? presetName) =>
      presetName != null ? TankPresets.byName(presetName)?.volumeLiters : null;

  static double _materialPerLiter(TankMaterial? material) => switch (material) {
    TankMaterial.aluminum || null => 0.15,
    TankMaterial.steel => -0.12,
    TankMaterial.carbonFiber => 0.30,
  };
}
