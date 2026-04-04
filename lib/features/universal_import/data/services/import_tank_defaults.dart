import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Apply default tank values to a single tank data map.
///
/// Fills missing fields (volume, workingPressure, material, presetName) from [defaultPreset]
/// and missing startPressure from [defaultStartPressure].
/// Fields that already have non-zero values are left untouched.
///
/// Returns a new map with defaults applied (does not mutate the input).
Map<String, dynamic> applyTankDefaults(
  Map<String, dynamic> tank, {
  required TankPresetEntity? defaultPreset,
  required int defaultStartPressure,
}) {
  final result = Map<String, dynamic>.of(tank);

  if (defaultPreset != null) {
    // Fill volume if missing or zero
    final volume = result['volume'];
    if (volume == null || (volume is num && volume <= 0)) {
      result['volume'] = defaultPreset.volumeLiters;
    }

    // Fill workingPressure if missing or zero
    final wp = result['workingPressure'];
    if (wp == null || (wp is num && wp <= 0)) {
      result['workingPressure'] = defaultPreset.workingPressureBar;
    }

    // Fill material if missing
    if (result['material'] == null) {
      result['material'] = defaultPreset.material;
    }

    // Fill presetName if missing
    if (result['presetName'] == null) {
      result['presetName'] = defaultPreset.name;
    }
  }

  // Fill startPressure if missing or zero (independent of preset)
  final sp = result['startPressure'];
  if (sp == null || (sp is num && sp <= 0)) {
    result['startPressure'] = defaultStartPressure;
  }

  return result;
}

/// Apply default tank values to a list of tank data maps.
///
/// Convenience wrapper around [applyTankDefaults] for batch processing.
List<Map<String, dynamic>> applyTankDefaultsToList(
  List<Map<String, dynamic>> tanks, {
  required TankPresetEntity? defaultPreset,
  required int defaultStartPressure,
}) {
  return tanks
      .map(
        (t) => applyTankDefaults(
          t,
          defaultPreset: defaultPreset,
          defaultStartPressure: defaultStartPressure,
        ),
      )
      .toList();
}
