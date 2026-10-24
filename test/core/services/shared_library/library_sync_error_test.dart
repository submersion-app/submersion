// Issue #3563: a library's sync failure is stored as a code, so the page
// says it in the reader's language rather than in the English it was
// written in.

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/shared_library/library_sync_error.dart';

void main() {
  test('every code survives the round trip through the library row', () {
    for (final code in LibrarySyncErrorCode.values) {
      final error = LibrarySyncError(code, detail: 'd');
      final back = LibrarySyncError.decode(error.encode());
      expect(back.code, code);
      expect(back.detail, 'd');
    }
  });

  test('a code with no detail decodes with none', () {
    final back = LibrarySyncError.decode(
      const LibrarySyncError(LibrarySyncErrorCode.accountMissing).encode(),
    );
    expect(back.code, LibrarySyncErrorCode.accountMissing);
    expect(back.detail, isNull);
  });

  test('text an older build stored is shown as it was written', () {
    final back = LibrarySyncError.decode(
      'The account for Reef Survey is no longer on this device',
    );
    expect(back.code, LibrarySyncErrorCode.failed);
    expect(
      back.detail,
      'The account for Reef Survey is no longer on this device',
    );
  });

  test('a code a newer build wrote is shown by its detail', () {
    final back = LibrarySyncError.decode(
      '{"code":"somethingNew","detail":"Reef Survey needs attention"}',
    );
    expect(back.code, LibrarySyncErrorCode.failed);
    expect(back.detail, 'Reef Survey needs attention');
  });

  test('a code a newer build wrote with no detail keeps the stored text', () {
    const stored = '{"code":"somethingNew"}';
    final back = LibrarySyncError.decode(stored);
    expect(back.code, LibrarySyncErrorCode.failed);
    expect(back.detail, stored);
  });

  test('JSON that is not a stored code is kept as text', () {
    const stored = '{"message":"bucket not found"}';
    expect(LibrarySyncError.decode(stored).detail, stored);
    expect(LibrarySyncError.decode('[1]').detail, '[1]');
  });

  test('a WebDAV refusal keeps what its translation needs', () {
    final back = LibrarySyncError.decode(
      LibrarySyncError.fromWebDav(
        WebDavException(
          'Too large',
          code: WebDavErrorCode.tooLarge,
          statusCode: 413,
          sizeBytes: 5 * 1024 * 1024,
          host: 'dav.example.com',
          location: 'https://elsewhere.example.com/',
          cause: 'HTTP 413',
        ),
      ).encode(),
    );
    expect(back.code, LibrarySyncErrorCode.webdav);
    expect(back.detail, 'Too large (HTTP 413)');
    final e = back.webdav!;
    expect(e.code, WebDavErrorCode.tooLarge);
    expect(e.statusCode, 413);
    expect(e.sizeBytes, 5 * 1024 * 1024);
    expect(e.host, 'dav.example.com');
    expect(e.location, 'https://elsewhere.example.com/');
    expect('${e.cause}', 'HTTP 413');
    expect(e.displayMessage, 'Too large (HTTP 413)');
  });

  test('a WebDAV code a newer build added reads as unexpected', () {
    final back = LibrarySyncError.decode(
      '{"code":"webdav","detail":"x","webdav":{"code":"somethingNew"}}',
    );
    expect(back.webdav!.code, WebDavErrorCode.unexpected);
  });

  group('fromTransportError', () {
    test('each account error has its code', () {
      expect(
        LibrarySyncError.fromTransportError(
          LibraryAccountMissingError('Reef Survey'),
        ).code,
        LibrarySyncErrorCode.accountMissing,
      );
      expect(
        LibrarySyncError.fromTransportError(
          LibraryAccountSignedOutError('acc'),
        ).code,
        LibrarySyncErrorCode.accountSignedOut,
      );
      final unsupported = LibrarySyncError.fromTransportError(
        LibraryAccountUnsupportedError('adobeLightroom'),
      );
      expect(unsupported.code, LibrarySyncErrorCode.accountUnsupported);
      expect(unsupported.detail, 'adobeLightroom');
    });

    test('another refusal keeps its message', () {
      final e = LibrarySyncError.fromTransportError(StateError('no folder'));
      expect(e.code, LibrarySyncErrorCode.failed);
      expect(e.detail, 'no folder');
    });
  });

  group('fromSyncFailure', () {
    test('a WebDAV refusal keeps its WebDAV code', () {
      final e = LibrarySyncError.fromSyncFailure(
        WebDavException('No', code: WebDavErrorCode.forbidden),
      );
      expect(e.code, LibrarySyncErrorCode.webdav);
      expect(e.webdav!.code, WebDavErrorCode.forbidden);
    });

    test('other storage keeps its display message', () {
      final e = LibrarySyncError.fromSyncFailure(
        const CloudStorageException('Forbidden', 'HTTP 403'),
      );
      expect(e.code, LibrarySyncErrorCode.failed);
      expect(e.detail, 'Forbidden (HTTP 403)');
    });

    test('anything else keeps its text', () {
      final e = LibrarySyncError.fromSyncFailure(const FormatException('bad'));
      expect(e.code, LibrarySyncErrorCode.failed);
      expect(e.detail, 'FormatException: bad');
    });
  });

  test('the log line names the code and its detail', () {
    expect(
      const LibrarySyncError(
        LibrarySyncErrorCode.needsNewerApp,
        detail: '5',
      ).toString(),
      'LibrarySyncError(needsNewerApp: 5)',
    );
    expect(
      const LibrarySyncError(LibrarySyncErrorCode.notALibrary).toString(),
      'LibrarySyncError(notALibrary)',
    );
  });
}
