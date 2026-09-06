import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for the tank / breathing-apparatus enums shown on screen
/// (cylinder configs, the dive editor's tank rows, the SCR panel, the dive-mode
/// selector).
///
/// The `displayName` / `shortName` fields on each enum stay hardcoded English
/// on purpose: they feed data interchange (CSV/Excel export, the PDF templates,
/// the field extractor) where a stable, locale-independent value is wanted.
/// These getters drive on-screen UI so the same values honor the active locale
/// (issue #1608).
///
/// Each switch is exhaustive by enum value, so adding a value is a compile
/// error until its localization key is wired in.
extension TankRoleDisplay on TankRole {
  String localizedName(AppLocalizations l10n) => switch (this) {
    TankRole.backGas => l10n.enum_tankRole_backGas,
    TankRole.stage => l10n.enum_tankRole_stage,
    TankRole.deco => l10n.enum_tankRole_deco,
    TankRole.bailout => l10n.enum_tankRole_bailout,
    TankRole.sidemountLeft => l10n.enum_tankRole_sidemountLeft,
    TankRole.sidemountRight => l10n.enum_tankRole_sidemountRight,
    TankRole.pony => l10n.enum_tankRole_pony,
    TankRole.diluent => l10n.enum_tankRole_diluent,
    TankRole.oxygenSupply => l10n.enum_tankRole_oxygenSupply,
  };
}

extension TankMaterialDisplay on TankMaterial {
  String localizedName(AppLocalizations l10n) => switch (this) {
    TankMaterial.aluminum => l10n.enum_tankMaterial_aluminum,
    TankMaterial.steel => l10n.enum_tankMaterial_steel,
    TankMaterial.carbonFiber => l10n.enum_tankMaterial_carbonFiber,
  };
}

extension ScrTypeDisplay on ScrType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ScrType.cmf => l10n.enum_scrType_cmf,
    ScrType.pascr => l10n.enum_scrType_pascr,
    ScrType.escr => l10n.enum_scrType_escr,
  };

  String localizedShortName(AppLocalizations l10n) => switch (this) {
    ScrType.cmf => l10n.enum_scrType_cmf_short,
    ScrType.pascr => l10n.enum_scrType_pascr_short,
    ScrType.escr => l10n.enum_scrType_escr_short,
  };
}

extension DiveModeDisplay on DiveMode {
  String localizedName(AppLocalizations l10n) => switch (this) {
    DiveMode.oc => l10n.enum_diveMode_oc,
    DiveMode.ccr => l10n.enum_diveMode_ccr,
    DiveMode.scr => l10n.enum_diveMode_scr,
    DiveMode.gauge => l10n.enum_diveMode_gauge,
  };
}
