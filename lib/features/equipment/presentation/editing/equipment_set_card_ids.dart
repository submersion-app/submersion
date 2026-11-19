import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the equipment set page that can be edited in place (issue
/// #4527, phase 3), in page order. Cards that only show what is calculated or
/// imported have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum EquipmentSetCardId { header, figure, members, bundle, geofences }

/// What each card of the equipment set page is called.
extension EquipmentSetCardIdNames on EquipmentSetCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    EquipmentSetCardId.header => l.settings_conflict_ref_equipmentSet,
    EquipmentSetCardId.figure => l.equipment_setEdit_figureSwitch_title,
    EquipmentSetCardId.members => l.equipment_setDetail_equipmentInSetTitle,
    EquipmentSetCardId.bundle => l.equipment_setEdit_bundleTitle,
    EquipmentSetCardId.geofences => l.equipment_setDetail_geofencesTitle,
  };
}
