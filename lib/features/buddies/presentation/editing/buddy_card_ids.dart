import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the buddy page that can be edited in place (issue #4527, phase
/// 3), in page order. Cards that only show what is calculated or imported have
/// none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum BuddyCardId {
  header,
  contact,
  certifications,
  statistics,
  gear,
  notes,
  documents,
}

/// What each card of the buddy page is called.
extension BuddyCardIdNames on BuddyCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    BuddyCardId.header => l.settings_conflict_ref_buddy,
    BuddyCardId.contact => l.buddies_section_contact,
    BuddyCardId.certifications => l.buddies_section_certifications,
    BuddyCardId.statistics => l.buddies_section_diveStatistics,
    BuddyCardId.gear => l.buddies_editCard_gear,
    BuddyCardId.notes => l.buddies_section_notes,
    BuddyCardId.documents => l.documents_section_title,
  };
}
