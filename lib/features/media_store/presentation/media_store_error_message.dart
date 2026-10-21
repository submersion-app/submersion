import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// User-facing text for a failed attach.
///
/// A transient answer is the store saying "not yet", not "no": on iCloud it
/// is a container whose copy of `store.json` has not finished coming down,
/// and the raw message is a developer string naming an object key. Every
/// other kind carries a message written to be read.
///
/// Attach only. Verify keeps the raw text: it is a diagnostic, and "wait a
/// moment and try again" answers a question it did not ask.
String mediaStoreErrorMessage(AppLocalizations l10n, MediaStoreException e) {
  return e.kind == MediaStoreErrorKind.transient
      ? l10n.settings_mediaStorage_error_notReady
      : e.message;
}
