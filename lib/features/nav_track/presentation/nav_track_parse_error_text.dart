import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The localized, diver-facing text for a failed route import.
///
/// [NavTrackParseException.message] names the offending row or value in
/// English, for the log and for tests. This is the localizable half --
/// mirrors `trackParseErrorText` for the GPS logger.
String navTrackParseErrorText(AppLocalizations l10n, NavTrackParseException e) {
  return switch (e.reason) {
    NavTrackParseReason.unsupportedFormat =>
      l10n.navTrack_importError_unsupportedFormat,
    NavTrackParseReason.unreadable => l10n.navTrack_importError_unreadable,
    NavTrackParseReason.tooShort => l10n.navTrack_importError_tooShort,
    NavTrackParseReason.badData => l10n.navTrack_importError_badData,
    NavTrackParseReason.tooLarge => l10n.navTrack_importError_tooLarge,
  };
}
