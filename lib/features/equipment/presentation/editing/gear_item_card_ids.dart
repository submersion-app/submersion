import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the gear item page and its passports that can be edited in
/// place (issue #4527, phase 3), in page order. Cards that only show what is
/// calculated or imported have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
///
/// The passports' cards come last: they are cards of the item, held in its
/// sitting. The Transmitter and Parts cards hold nothing, so they have no
/// id: one opens another record's page, the other's actions are
/// whole-record operations or open a new item.
enum GearItemCardId {
  header,
  diveComputer,
  details,
  location,
  twinSet,
  serviceClocks,
  conditionFindings,
  photos,
  observations,
  components,
  legacyFiles,
  serviceHistory,
  notes,
  documents,
  passportFills,
  passportService,
  passportTag,
  passportTrip,
}

/// What each card of the gear item page and its passports is called.
extension GearItemCardIdNames on GearItemCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    GearItemCardId.header => l.settings_conflict_ref_equipment,
    GearItemCardId.diveComputer => l.diveComputer_title,
    GearItemCardId.details => l.equipment_detail_detailsTitle,
    GearItemCardId.location => l.equipment_location_card_title,
    GearItemCardId.twinSet => l.twinSet_title,
    GearItemCardId.serviceClocks => l.equipment_serviceClocks_title,
    GearItemCardId.conditionFindings => l.equipmentCondition_findings_title,
    GearItemCardId.photos => l.equipment_photos_title,
    GearItemCardId.observations => l.equipmentObservation_card_title,
    GearItemCardId.components => l.equipment_components_title,
    GearItemCardId.legacyFiles => l.equipment_documents_linkedTitle,
    GearItemCardId.serviceHistory => l.equipment_service_historyTitle,
    GearItemCardId.notes => l.equipment_detail_notesTitle,
    GearItemCardId.documents => l.documents_section_title,
    GearItemCardId.passportFills => l.passport_history_title,
    GearItemCardId.passportService => l.passport_service_title,
    GearItemCardId.passportTag => l.passport_tag_title,
    GearItemCardId.passportTrip => l.passport_trip_title,
  };
}
