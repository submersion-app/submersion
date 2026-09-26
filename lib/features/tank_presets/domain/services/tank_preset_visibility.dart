import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

// Which tank presets the diver's pickers offer (issue #2305).
//
// A diver can hide built-in presets they never use. Hiding only narrows the
// pickers: import matching and default resolution keep reading the full
// catalog, and the Tank Presets settings page keeps listing everything so a
// hidden preset can be shown again.

/// [all] without the built-in presets named in [hidden].
///
/// Custom presets are never hidden, even when one shares a built-in slug.
/// The [defaultPresetName] always stays, so a default that ended up in the
/// hidden set (the settings page never allows that, but a synced row could
/// carry it) is still offered where it is applied.
List<TankPresetEntity> visibleTankPresets(
  List<TankPresetEntity> all,
  Set<String> hidden, {
  String? defaultPresetName,
}) {
  if (hidden.isEmpty) return all;
  return [
    for (final preset in all)
      if (!preset.isBuiltIn ||
          preset.name == defaultPresetName ||
          !hidden.contains(preset.name))
        preset,
  ];
}

/// [visible] plus any hidden built-in preset named in [keep], so a picker
/// whose current value is a hidden preset still shows that value.
///
/// Restored presets go back to their catalog position among the built-in
/// ones, custom presets stay first, and every preset already in [visible]
/// keeps its instance. Returns [visible] itself when nothing is missing.
List<TankPresetEntity> withKeptTankPresets(
  List<TankPresetEntity> visible,
  Iterable<String?> keep,
) {
  final present = {for (final preset in visible) preset.name};
  final missing = {
    for (final name in keep)
      if (name != null &&
          !present.contains(name) &&
          TankPresets.byName(name) != null)
        name,
  };
  if (missing.isEmpty) return visible;

  final builtInByName = {
    for (final preset in visible)
      if (preset.isBuiltIn) preset.name: preset,
  };
  return [
    for (final preset in visible)
      if (!preset.isBuiltIn) preset,
    for (final builtIn in TankPresets.all)
      if (builtInByName[builtIn.name] case final existing?)
        existing
      else if (missing.contains(builtIn.name))
        TankPresetEntity.fromBuiltIn(builtIn),
  ];
}
