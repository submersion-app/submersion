import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the GPS track page that can be edited in place (issue #4527,
/// phase 3), in page order. Cards that only show what is calculated or imported
/// have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum GpsTrackCardId { header, trim }

/// What each card of the GPS track page is called.
extension GpsTrackCardIdNames on GpsTrackCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    GpsTrackCardId.header => l.gpsTrack_detail_title,
    GpsTrackCardId.trim => l.gpsTrack_editCard_trim,
  };
}
