import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/shared_library/library_sync_error.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('a WebDAV failure reads as the WebDAV settings put it', () {
    final error = WebDavException(
      'Unauthorized',
      code: WebDavErrorCode.unauthorized,
    );
    expect(
      libraryErrorText(de, error),
      de.settings_webdavConfig_error_unauthorized,
    );
  });

  test('another storage failure keeps the provider message', () {
    expect(
      libraryErrorText(de, const CloudStorageException('S3 is not configured')),
      'S3 is not configured',
    );
  });

  test('roles changed since this device trusted them says what to do', () {
    expect(
      libraryErrorText(de, RolesOutOfDateError('L')),
      de.sharedLibrary_members_rolesOutOfDate,
    );
  });

  // Issue #3563: an action that reaches a library whose account is gone.
  test('a missing account says how to connect it again', () {
    expect(
      libraryErrorText(de, LibraryAccountMissingError('Reef Survey')),
      de.sharedLibrary_syncError_accountMissing,
    );
    expect(
      libraryErrorText(de, LibraryAccountSignedOutError('acc')),
      de.sharedLibrary_syncError_accountSignedOut,
    );
    expect(
      libraryErrorText(de, LibraryAccountUnsupportedError('adobeLightroom')),
      de.sharedLibrary_connect_onlyS3Webdav,
    );
  });

  group('librarySyncErrorText (issue #3563)', () {
    String text(LibrarySyncError e) =>
        librarySyncErrorText(en, e, libraryName: 'Reef Survey');

    test('each code reads as its sentence', () {
      final sentences = {
        LibrarySyncErrorCode.accountMissing:
            'The account for this library is no longer on this device. '
            'Use Change connection to choose it again.',
        LibrarySyncErrorCode.accountSignedOut:
            'This device is signed out of the account for this library. '
            'Sign in to it again in Connected accounts, or use Change '
            'connection.',
        LibrarySyncErrorCode.accountUnsupported:
            'Shared site libraries work with S3 and WebDAV accounts.',
        LibrarySyncErrorCode.notALibrary: 'No library at this location.',
        LibrarySyncErrorCode.retired:
            'This library was made by a test build of Submersion. '
            'Create it again.',
        LibrarySyncErrorCode.needsNewerApp:
            'This library needs a newer version of Submersion.',
        LibrarySyncErrorCode.needsPassphrase:
            'Enter the passphrase for Reef Survey.',
        LibrarySyncErrorCode.passphraseChanged:
            'The passphrase of Reef Survey changed. Enter the new one.',
        LibrarySyncErrorCode.webdav: 'Something went wrong.',
        LibrarySyncErrorCode.failed: 'Something went wrong.',
      };
      expect(sentences.keys, unorderedEquals(LibrarySyncErrorCode.values));
      for (final MapEntry(key: code, value: sentence) in sentences.entries) {
        expect(text(LibrarySyncError(code)), sentence, reason: '$code');
      }
    });

    test('a WebDAV refusal reads as the WebDAV settings put it', () {
      final stored = LibrarySyncError.fromWebDav(
        WebDavException('Unauthorized', code: WebDavErrorCode.unauthorized),
      ).encode();
      expect(
        text(LibrarySyncError.decode(stored)),
        en.settings_webdavConfig_error_unauthorized,
      );
    });

    test('a message with no translation shows as it was given', () {
      expect(
        text(
          const LibrarySyncError(
            LibrarySyncErrorCode.failed,
            detail: 'HTTP 403 Forbidden',
          ),
        ),
        'HTTP 403 Forbidden',
      );
      expect(
        text(
          const LibrarySyncError(LibrarySyncErrorCode.webdav, detail: 'boom'),
        ),
        'boom',
      );
    });
  });
}
