import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the certification page that can be edited in place (issue
/// #4527, phase 3), in page order. Cards that only show what is calculated or
/// imported have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
///
/// The header block holds nothing of its own: its title, agency and badge
/// come from Details.
enum CertificationCardId {
  details,
  dates,
  currency,
  instructor,
  cardPhotos,
  documents,
  notes,
}

/// What each card of the certification page is called.
extension CertificationCardIdNames on CertificationCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    CertificationCardId.details => l.certifications_detail_sectionTitle_details,
    CertificationCardId.dates => l.certifications_detail_sectionTitle_dates,
    CertificationCardId.currency =>
      l.certifications_detail_sectionTitle_currency,
    CertificationCardId.instructor =>
      l.certifications_detail_sectionTitle_instructor,
    CertificationCardId.cardPhotos =>
      l.certifications_detail_sectionTitle_cardPhotos,
    CertificationCardId.documents => l.documents_section_title,
    CertificationCardId.notes => l.certifications_detail_sectionTitle_notes,
  };
}
