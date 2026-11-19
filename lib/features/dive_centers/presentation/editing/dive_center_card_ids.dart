import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the dive centre page that can be edited in place (issue #4527,
/// phase 3), in page order. Cards that only show what is calculated or imported
/// have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum DiveCenterCardId { header, map, contact, notes, documents, rentalGear }

/// What each card of the dive centre page is called.
extension DiveCenterCardIdNames on DiveCenterCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    DiveCenterCardId.header => l.settings_conflict_ref_diveCenter,
    DiveCenterCardId.map => l.diveCenters_editCard_map,
    DiveCenterCardId.contact => l.diveCenters_section_contact,
    DiveCenterCardId.notes => l.diveCenters_section_notes,
    DiveCenterCardId.documents => l.documents_section_title,
    DiveCenterCardId.rentalGear => l.diveCenters_rental_sectionTitle,
  };
}
