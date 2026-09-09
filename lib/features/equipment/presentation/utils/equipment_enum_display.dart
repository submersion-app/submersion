import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for the equipment enums shown on screen.
///
/// The `displayName` field on each enum stays hardcoded English on purpose: it
/// feeds data interchange (CSV/Excel export, the PDF templates, the field
/// extractor) where a stable, locale-independent value is wanted. These getters
/// drive on-screen UI so the same values honor the active locale (issue #1608).
///
/// Each switch is exhaustive by enum value, so adding a value is a compile
/// error until its localization key is wired in.
extension EquipmentTypeDisplay on EquipmentType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentType.regulator => l10n.enum_equipmentType_regulator,
    EquipmentType.firstStage => l10n.enum_equipmentType_firstStage,
    EquipmentType.secondStage => l10n.enum_equipmentType_secondStage,
    EquipmentType.hose => l10n.enum_equipmentType_hose,
    EquipmentType.bcd => l10n.enum_equipmentType_bcd,
    EquipmentType.backplate => l10n.enum_equipmentType_backplate,
    EquipmentType.wing => l10n.enum_equipmentType_wing,
    EquipmentType.harness => l10n.enum_equipmentType_harness,
    EquipmentType.wetsuit => l10n.enum_equipmentType_wetsuit,
    EquipmentType.drysuit => l10n.enum_equipmentType_drysuit,
    EquipmentType.undersuit => l10n.enum_equipmentType_undersuit,
    EquipmentType.baselayer => l10n.enum_equipmentType_baselayer,
    EquipmentType.rashGuard => l10n.enum_equipmentType_rashGuard,
    EquipmentType.fins => l10n.enum_equipmentType_fins,
    EquipmentType.mask => l10n.enum_equipmentType_mask,
    EquipmentType.snorkel => l10n.enum_equipmentType_snorkel,
    EquipmentType.computer => l10n.enum_equipmentType_computer,
    EquipmentType.transmitter => l10n.enum_equipmentType_transmitter,
    EquipmentType.instrument => l10n.enum_equipmentType_instrument,
    EquipmentType.compass => l10n.enum_equipmentType_compass,
    EquipmentType.tank => l10n.enum_equipmentType_tank,
    EquipmentType.rebreather => l10n.enum_equipmentType_rebreather,
    EquipmentType.weights => l10n.enum_equipmentType_weights,
    EquipmentType.light => l10n.enum_equipmentType_light,
    EquipmentType.camera => l10n.enum_equipmentType_camera,
    EquipmentType.housing => l10n.enum_equipmentType_housing,
    EquipmentType.strobe => l10n.enum_equipmentType_strobe,
    EquipmentType.smb => l10n.enum_equipmentType_smb,
    EquipmentType.reel => l10n.enum_equipmentType_reel,
    EquipmentType.knife => l10n.enum_equipmentType_knife,
    EquipmentType.tool => l10n.enum_equipmentType_tool,
    EquipmentType.hood => l10n.enum_equipmentType_hood,
    EquipmentType.gloves => l10n.enum_equipmentType_gloves,
    EquipmentType.boots => l10n.enum_equipmentType_boots,
    EquipmentType.dpv => l10n.enum_equipmentType_dpv,
    EquipmentType.o2Cell => l10n.enum_equipmentType_o2Cell,
    EquipmentType.battery => l10n.enum_equipmentType_battery,
    EquipmentType.other => l10n.enum_equipmentType_other,
  };
}

extension EquipmentStatusDisplay on EquipmentStatus {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentStatus.active => l10n.enum_equipmentStatus_active,
    EquipmentStatus.needsService => l10n.enum_equipmentStatus_needsService,
    EquipmentStatus.inService => l10n.enum_equipmentStatus_inService,
    EquipmentStatus.retired => l10n.enum_equipmentStatus_retired,
    EquipmentStatus.sold => l10n.enum_equipmentStatus_sold,
    EquipmentStatus.loaned => l10n.enum_equipmentStatus_loaned,
    EquipmentStatus.lost => l10n.enum_equipmentStatus_lost,
  };
}
