import 'package:submersion/core/constants/gas_templates.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display strings for the built-in [GasTemplate] constants.
///
/// [GasTemplates] is a const table with no BuildContext, and its `displayName`
/// / `description` fields are also what the SCR and CCR pickers persist and
/// what exports carry, so those English values deliberately stay put as the
/// stable identifier. Screens resolve through here at render time, keyed on
/// the slug in [GasTemplate.name] -- the same shape as `builtInDiveTypeName`
/// for the seeded dive types.
///
/// What is translated, and what is not, is a diving-domain call rather than a
/// mechanical one:
///
///   * "Air", "Oxygen" and "Air Diluent" are ordinary words for a gas and DO
///     translate (de "Luft"/"Sauerstoff", fr "Air"/"Oxygene").
///   * "EAN32", "Tx 18/45", "Helitrox 25/25" and "SCR EAN40" are international
///     mix designations. Every locale in `lib/l10n/arb` already keeps them
///     byte-identical to English, and they must stay that way: a diver reads
///     these off a cylinder sticker and an analyser printout.
///   * All descriptions are prose and translate in full.
///
/// One known gap: `gas_oxygen_description` bakes "6m" into the sentence rather
/// than routing it through UnitFormatter, so an imperial diver still reads
/// "6m deco only". Fixing it needs a depth formatter that this const table
/// cannot reach; flagged rather than papered over, because hardcoding "20ft"
/// into the English would only move the bug.
String? builtInGasTemplateName(AppLocalizations l10n, String slug) =>
    switch (slug) {
      'air' => l10n.gas_air_displayName,
      'ean32' => l10n.gas_ean32_displayName,
      'ean36' => l10n.gas_ean36_displayName,
      'ean40' => l10n.gas_ean40_displayName,
      'ean50' => l10n.gas_ean50_displayName,
      'oxygen' => l10n.gas_oxygen_displayName,
      'tmx2135' => l10n.gas_tmx2135_displayName,
      'tmx1845' => l10n.gas_tmx1845_displayName,
      'tmx1555' => l10n.gas_tmx1555_displayName,
      'helitrox2525' => l10n.gas_helitrox2525_displayName,
      'diluent_air' => l10n.gas_diluentAir_displayName,
      'diluent_tx1260' => l10n.gas_diluentTx1260_displayName,
      'diluent_tx1070' => l10n.gas_diluentTx1070_displayName,
      'scr_ean40' => l10n.gas_scrEan40_displayName,
      'scr_ean50' => l10n.gas_scrEan50_displayName,
      'scr_ean60' => l10n.gas_scrEan60_displayName,
      _ => null,
    };

/// Localized description for a built-in gas template; null when unknown.
String? builtInGasTemplateDescription(AppLocalizations l10n, String slug) =>
    switch (slug) {
      'air' => l10n.gas_air_description,
      'ean32' => l10n.gas_ean32_description,
      'ean36' => l10n.gas_ean36_description,
      'ean40' => l10n.gas_ean40_description,
      'ean50' => l10n.gas_ean50_description,
      'oxygen' => l10n.gas_oxygen_description,
      'tmx2135' => l10n.gas_tmx2135_description,
      'tmx1845' => l10n.gas_tmx1845_description,
      'tmx1555' => l10n.gas_tmx1555_description,
      'helitrox2525' => l10n.gas_helitrox2525_description,
      'diluent_air' => l10n.gas_diluentAir_description,
      'diluent_tx1260' => l10n.gas_diluentTx1260_description,
      'diluent_tx1070' => l10n.gas_diluentTx1070_description,
      'scr_ean40' => l10n.gas_scrEan40_description,
      'scr_ean50' => l10n.gas_scrEan50_description,
      'scr_ean60' => l10n.gas_scrEan60_description,
      _ => null,
    };

extension GasTemplateDisplay on GasTemplate {
  /// Localized name for built-in mixes; the stored English name otherwise.
  String localizedDisplayName(AppLocalizations l10n) =>
      builtInGasTemplateName(l10n, name) ?? displayName;

  /// Localized description for built-in mixes; the stored one otherwise.
  String? localizedDescription(AppLocalizations l10n) =>
      builtInGasTemplateDescription(l10n, name) ?? description;
}
