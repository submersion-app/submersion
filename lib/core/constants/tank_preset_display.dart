import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display strings for the built-in [TankPreset] constants.
///
/// [TankPresets] is a const table with no BuildContext, and its rows are also
/// seeded into `tank_presets` as `TankPresetEntity` values whose `displayName`
/// exports and sync carry, so the English value stays the stable identifier
/// and screens resolve through here at render time, keyed on the slug in
/// [TankPreset.name] -- the same shape as `builtInDiveTypeName` for the seeded
/// dive types.
///
/// Domain call on the names: "AL80", "HP100", "LP85", "AL30 Stage" are
/// manufacturer/industry designations stamped on the cylinder and quoted in
/// every fill station price list. They are NOT translated, and every locale in
/// `lib/l10n/arb` already keeps them byte-identical. The only names that move
/// are the metric ones, where "Steel" is an ordinary material word ("Stahl
/// 10L", "Acier 10L", "Acciaio 10L"). All descriptions are prose and translate
/// in full.
String? builtInTankPresetName(AppLocalizations l10n, String slug) =>
    switch (slug) {
      'al40' => l10n.tank_al40_displayName,
      'al63' => l10n.tank_al63_displayName,
      'al80' => l10n.tank_al80_displayName,
      'hp80' => l10n.tank_hp80_displayName,
      'hp100' => l10n.tank_hp100_displayName,
      'hp120' => l10n.tank_hp120_displayName,
      'lp85' => l10n.tank_lp85_displayName,
      'steel10' => l10n.tank_steel10_displayName,
      'steel12' => l10n.tank_steel12_displayName,
      'steel15' => l10n.tank_steel15_displayName,
      'al30stage' => l10n.tank_al30Stage_displayName,
      'al40stage' => l10n.tank_al40Stage_displayName,
      _ => null,
    };

/// Localized description for a built-in cylinder preset; null when unknown.
String? builtInTankPresetDescription(AppLocalizations l10n, String slug) =>
    switch (slug) {
      'al40' => l10n.tank_al40_description,
      'al63' => l10n.tank_al63_description,
      'al80' => l10n.tank_al80_description,
      'hp80' => l10n.tank_hp80_description,
      'hp100' => l10n.tank_hp100_description,
      'hp120' => l10n.tank_hp120_description,
      'lp85' => l10n.tank_lp85_description,
      'steel10' => l10n.tank_steel10_description,
      'steel12' => l10n.tank_steel12_description,
      'steel15' => l10n.tank_steel15_description,
      'al30stage' => l10n.tank_al30Stage_description,
      'al40stage' => l10n.tank_al40Stage_description,
      _ => null,
    };

extension TankPresetDisplay on TankPreset {
  /// Localized name for built-in presets; the stored English name otherwise.
  String localizedDisplayName(AppLocalizations l10n) =>
      builtInTankPresetName(l10n, name) ?? displayName;

  /// Localized description for built-in presets; the stored one otherwise.
  String? localizedDescription(AppLocalizations l10n) =>
      builtInTankPresetDescription(l10n, name) ?? description;
}
