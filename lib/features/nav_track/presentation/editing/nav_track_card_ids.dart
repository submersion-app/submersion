import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the underwater track page that can be edited in place (issue
/// #4527, phase 3), in page order. Cards that only show what is calculated or
/// imported have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum NavTrackCardId { header, dive, site, device, correction }

/// What each card of the underwater track page is called.
extension NavTrackCardIdNames on NavTrackCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    NavTrackCardId.header => l.changeLog_table_navTrack,
    NavTrackCardId.dive => l.navTrack_editCard_dive,
    NavTrackCardId.site => l.navTrack_editCard_site,
    NavTrackCardId.device => l.navTrack_editCard_device,
    NavTrackCardId.correction => l.navTrack_editCard_correction,
  };
}
