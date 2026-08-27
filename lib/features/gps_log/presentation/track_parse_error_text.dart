import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The localized, diver-facing text for a failed track import.
///
/// [TrackParseException.message] names the offending element, row, or value in
/// English. That is exactly what a log wants and exactly what a SnackBar in
/// Hebrew does not, so the UI shows the reason and the detail goes to the log.
String trackParseErrorText(AppLocalizations l10n, TrackParseException e) {
  return switch (e.reason) {
    TrackParseReason.unsupportedFormat =>
      l10n.gpsTrack_importError_unsupportedFormat,
    TrackParseReason.unreadable => l10n.gpsTrack_importError_unreadable,
    TrackParseReason.noPositions => l10n.gpsTrack_importError_noPositions,
    TrackParseReason.badData => l10n.gpsTrack_importError_badData,
  };
}
