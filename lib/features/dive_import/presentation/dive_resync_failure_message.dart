import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The sentence the diver reads when a resync did not update the dive.
///
/// One key per case rather than a reason interpolated into a wrapper
/// sentence: the fragment would have to be a grammatical fit for eleven
/// languages at once, and the reasons are a closed set, so each locale gets
/// a whole sentence it can phrase its own way.
String diveResyncFailureMessage(
  AppLocalizations l10n,
  DiveResyncFailure reason,
) => switch (reason) {
  DiveResyncFailure.diveMissing => l10n.diveLog_detail_resyncFailed_diveMissing,
  DiveResyncFailure.noStoredFile =>
    l10n.diveLog_detail_resyncFailed_noStoredFile,
  DiveResyncFailure.unsupportedFormat =>
    l10n.diveLog_detail_resyncFailed_unsupportedFormat,
  DiveResyncFailure.storedFileMissing =>
    l10n.diveLog_detail_resyncFailed_storedFileMissing,
  DiveResyncFailure.noMatchingDive =>
    l10n.diveLog_detail_resyncFailed_noMatchingDive,
  DiveResyncFailure.unexpectedError =>
    l10n.diveLog_detail_resyncFailed_unexpectedError,
};
