import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// A transient answer is the store saying "not yet", not "no", and its raw
/// message is a developer string naming an object key. Every other kind
/// carries a message written to be read.
void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('a transient failure reads as not ready yet, not as its raw '
      'message', () {
    final message = mediaStoreErrorMessage(
      l10n,
      const MediaStoreException(
        'still downloading from iCloud: smv1/store.json',
        kind: MediaStoreErrorKind.transient,
      ),
    );

    expect(message, l10n.settings_mediaStorage_error_notReady);
    expect(message, isNot(contains('smv1/store.json')));
  });

  test('every other kind keeps the message it carries', () {
    for (final kind in [
      MediaStoreErrorKind.auth,
      MediaStoreErrorKind.fatal,
      MediaStoreErrorKind.notFound,
    ]) {
      expect(
        mediaStoreErrorMessage(
          l10n,
          MediaStoreException('bucket policy denies this key', kind: kind),
        ),
        'bucket policy denies this key',
      );
    }
  });
}
