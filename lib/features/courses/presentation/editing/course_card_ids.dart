import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the course page that can be edited in place (issue #4527, phase
/// 3), in page order. Cards that only show what is calculated or imported have
/// none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
///
/// [status] is the page's header block.
enum CourseCardId {
  status,
  details,
  instructor,
  earnedCertifications,
  requirements,
  notes,
  documents,
}

/// What each card of the course page is called.
extension CourseCardIdNames on CourseCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    CourseCardId.status => l.settings_conflict_ref_course,
    CourseCardId.details => l.courses_section_details,
    CourseCardId.instructor => l.courses_section_instructor,
    CourseCardId.earnedCertifications => l.courses_section_earnedCertifications,
    CourseCardId.requirements => l.courses_section_requirements,
    CourseCardId.notes => l.courses_section_notes,
    CourseCardId.documents => l.documents_section_title,
  };
}
