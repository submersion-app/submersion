import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/keychain_gated_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';

/// Exercises the provider through the [GoogleDriveAuthenticator] seam: auth
/// delegation, the 401 retry, and error mapping. The transfer paths that take
/// a file path are covered separately in
/// google_drive_storage_provider_test.dart, which injects a DriveApi directly.
class _FakeAuthenticator implements GoogleDriveAuthenticator {
  _FakeAuthenticator(this._client);

  http.Client? _client;
  int authenticateCalls = 0;
  int silentAuthCalls = 0;
  int authFailures = 0;
  bool silentAuthResult = true;
  bool signedOut = false;

  @override
  http.Client? get authClient => _client;

  @override
  Future<void> authenticate() async => authenticateCalls++;

  @override
  Future<bool> attemptSilentAuth() async {
    silentAuthCalls++;
    return silentAuthResult;
  }

  @override
  Future<void> handleAuthFailure() async => authFailures++;

  @override
  Future<void> signOut() async {
    signedOut = true;
    _client = null;
  }

  @override
  Future<String?> get userEmail async => 'diver@example.com';
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// Minimal fake Drive v3 backend. List responses are keyed by a substring
/// of the q query parameter (folder lookups contain the folder mimeType,
/// file lookups contain the file name).
class _FakeDrive {
  final List<http.Request> requests = [];
  final Map<String, List<Map<String, Object?>>> listResponses = {};
  int failuresRemaining = 0;
  int failureStatus = 401;
  String failureReason = 'authError';

  MockClient client() => MockClient((request) async {
    requests.add(request);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return http.Response(
        jsonEncode({
          'error': {
            'code': failureStatus,
            'message': 'fake failure',
            'errors': [
              {'reason': failureReason, 'message': 'fake failure'},
            ],
          },
        }),
        failureStatus,
        headers: _jsonHeaders,
      );
    }
    final path = request.url.path;
    if (request.method == 'GET' && path == '/drive/v3/files') {
      final q = request.url.queryParameters['q'] ?? '';
      for (final entry in listResponses.entries) {
        if (q.contains(entry.key)) {
          return http.Response(
            jsonEncode({'files': entry.value}),
            200,
            headers: _jsonHeaders,
          );
        }
      }
      return http.Response(
        jsonEncode({'files': <Object?>[]}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      return http.Response(
        jsonEncode({'id': 'created-1', 'name': 'created'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if ((request.method == 'PATCH' || request.method == 'PUT') &&
        path.startsWith('/upload/drive/v3/files/')) {
      return http.Response(
        jsonEncode({'id': path.split('/').last, 'name': 'updated'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'POST' && path == '/drive/v3/files') {
      return http.Response(
        jsonEncode({'id': 'folder-created-1', 'name': 'Submersion Sync'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      if (request.url.queryParameters['alt'] == 'media') {
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      }
      return http.Response(
        jsonEncode({
          'id': path.split('/').last,
          'name': 'meta.json',
          'modifiedTime': '2026-07-02T10:00:00.000Z',
          'size': '3',
        }),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'DELETE') {
      return http.Response('', 204);
    }
    return http.Response('unexpected ${request.method} $path', 500);
  });
}

const _folderQueryKey = "mimeType = 'application/vnd.google-apps.folder'";

void main() {
  late _FakeDrive drive_;
  late _FakeAuthenticator auth;
  late GoogleDriveStorageProvider provider;

  setUp(() {
    drive_ = _FakeDrive();
    drive_.listResponses[_folderQueryKey] = [
      {'id': 'folder-7', 'name': 'Submersion Sync'},
    ];
    auth = _FakeAuthenticator(drive_.client());
    provider = GoogleDriveStorageProvider(authenticator: auth);
  });

  test('isAvailable is platform + desktop-config gated', () async {
    final expected = (Platform.isWindows || Platform.isLinux)
        ? GoogleDriveClientConfig.hasDesktopClient
        : true;
    expect(await provider.isAvailable(), expected);
  });

  test('isAuthenticated delegates to silent auth when no client yet', () async {
    final unauthenticated = GoogleDriveStorageProvider(
      authenticator: _FakeAuthenticator(null)..silentAuthResult = false,
    );
    expect(await unauthenticated.isAuthenticated(), isFalse);
  });

  test('getUserEmail delegates to the authenticator', () async {
    expect(await provider.getUserEmail(), 'diver@example.com');
  });

  test('mediaHttpClient yields the authenticated client', () async {
    expect(await provider.mediaHttpClient(), isNotNull);
  });

  test('mediaHttpClient returns null when no session can be built', () async {
    final offline = GoogleDriveStorageProvider(
      authenticator: _FakeAuthenticator(null)..silentAuthResult = false,
    );
    expect(await offline.mediaHttpClient(), isNull);
  });

  test('a fresh process re-authenticates silently without authenticate()', () {
    // Cold-launch regression guard. isSyncAvailable() -> isAuthenticated() is
    // the FIRST thing sync does after a restart, with no authenticate() call
    // in this process. An in-process opt-in flag here would report sync as
    // unauthenticated after every launch, which is checklist item 2.
    return expectLater(
      GoogleDriveStorageProvider(
        authenticator: _FakeAuthenticator(drive_.client()),
      ).isAuthenticated(),
      completion(isTrue),
    );
  });

  test('an injected DriveApi outranks the authenticator client', () async {
    // The transfer tests construct a provider with no usable authenticator;
    // injection has to win or every call would throw "Not authenticated".
    final injected = GoogleDriveStorageProvider(
      authenticator: _FakeAuthenticator(null)..silentAuthResult = false,
    )..debugSetDriveApi(drive.DriveApi(drive_.client()));

    expect(await injected.getFileInfo('file-1'), isNotNull);
  });

  test('upload creates a new file when none exists by that name', () async {
    final result = await provider.uploadFile(
      Uint8List.fromList([1, 2]),
      'ssv1.dev.cs.000001.json',
    );
    expect(result.fileId, 'created-1');
    expect(
      drive_.requests.any(
        (r) => r.method == 'POST' && r.url.path == '/upload/drive/v3/files',
      ),
      isTrue,
    );
  });

  test('upload updates in place when the name already exists', () async {
    drive_.listResponses["name = 'ssv1.dev.manifest.json'"] = [
      {'id': 'existing-9', 'name': 'ssv1.dev.manifest.json'},
    ];
    final result = await provider.uploadFile(
      Uint8List.fromList([1, 2]),
      'ssv1.dev.manifest.json',
    );
    expect(result.fileId, 'existing-9');
    expect(
      drive_.requests.any(
        (r) => r.url.path == '/upload/drive/v3/files/existing-9',
      ),
      isTrue,
    );
  });

  test('the sync folder id is cached across calls', () async {
    await provider.uploadFile(Uint8List.fromList([1]), 'a.json');
    await provider.uploadFile(Uint8List.fromList([2]), 'b.json');
    final folderQueries = drive_.requests.where(
      (r) => (r.url.queryParameters['q'] ?? '').contains(_folderQueryKey),
    );
    expect(folderQueries, hasLength(1));
  });

  test('download returns the file bytes', () async {
    final bytes = await provider.downloadFile('file-1');
    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('listFiles maps Drive results to CloudFileInfo', () async {
    drive_.listResponses['ssv1.'] = [
      {
        'id': 'f1',
        'name': 'ssv1.dev.cs.000001.json',
        'modifiedTime': '2026-07-01T00:00:00.000Z',
        'size': '10',
      },
    ];
    final files = await provider.listFiles(namePattern: 'ssv1.');
    expect(files, hasLength(1));
    expect(files.single.id, 'f1');
    expect(files.single.sizeBytes, 10);
  });

  test('deleteFile issues a DELETE', () async {
    await provider.deleteFile('f1');
    expect(drive_.requests.last.method, 'DELETE');
    expect(drive_.requests.last.url.path, '/drive/v3/files/f1');
  });

  test('a 401 triggers one silent re-auth and a retry', () async {
    drive_.failuresRemaining = 1;
    final files = await provider.listFiles(namePattern: 'ssv1.');
    expect(files, isEmpty);
    expect(auth.authFailures, 1);
    expect(auth.silentAuthCalls, 1);
  });

  test('a 401 with failed re-auth surfaces a sign-in-again error', () async {
    drive_.failuresRemaining = 1;
    auth.silentAuthResult = false;
    await expectLater(
      provider.listFiles(namePattern: 'ssv1.'),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          contains('sign in'),
        ),
      ),
    );
  });

  test('quota exhaustion maps to a storage-is-full error', () async {
    drive_.failuresRemaining = 1;
    drive_.failureStatus = 403;
    drive_.failureReason = 'storageQuotaExceeded';
    await expectLater(
      provider.listFiles(namePattern: 'ssv1.'),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          contains('storage is full'),
        ),
      ),
    );
  });

  group('authenticate', () {
    test('delegates and binds a DriveApi to the fresh client', () async {
      await provider.authenticate();

      expect(auth.authenticateCalls, 1);
      // Proven by the api actually working, not by inspecting private state.
      expect(await provider.getFileInfo('file-1'), isNotNull);
    });

    test('throws when sign-in yields no authorized client', () async {
      final clientless = GoogleDriveStorageProvider(
        authenticator: _FakeAuthenticator(null),
      );

      await expectLater(
        clientless.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('did not produce an authorized client'),
          ),
        ),
      );
    });
  });

  group('transport failures map to CloudStorageException', () {
    /// A provider whose every Drive call fails with a non-auth transport
    /// error, exercising each operation's generic catch + _mapDriveError.
    GoogleDriveStorageProvider failing() => GoogleDriveStorageProvider(
      authenticator: _FakeAuthenticator(
        MockClient((_) async => http.Response('upstream exploded', 500)),
      ),
    );

    test('listFiles', () async {
      await expectLater(
        failing().listFiles(folderId: 'folder-7'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('deleteFile', () async {
      await expectLater(
        failing().deleteFile('f1'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('createFolder', () async {
      await expectLater(
        failing().createFolder('Submersion Sync'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('getOrCreateSyncFolder', () async {
      await expectLater(
        failing().getOrCreateSyncFolder(),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('uploadFile', () async {
      await expectLater(
        failing().uploadFile(Uint8List.fromList([1]), 'a.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('downloadFile', () async {
      await expectLater(
        failing().downloadFile('file-1'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('fileExists reports false rather than throwing', () async {
      expect(await failing().fileExists('file-1'), isFalse);
    });

    test(
      'createFolder maps a full-quota 403 to a storage-is-full error',
      () async {
        drive_.failuresRemaining = 1;
        drive_.failureStatus = 403;
        drive_.failureReason = 'storageQuotaExceeded';

        await expectLater(
          provider.createFolder('Submersion Sync'),
          throwsA(
            isA<CloudStorageException>().having(
              (e) => e.message,
              'message',
              contains('storage is full'),
            ),
          ),
        );
      },
    );
  });

  test('signOut resets provider caches and delegates', () async {
    await provider.uploadFile(Uint8List.fromList([1]), 'a.json');
    await provider.signOut();
    expect(auth.signedOut, isTrue);
    expect(await provider.getFileInfo('x'), isNull);
  });

  group('default authenticator selection', () {
    test('Windows/Linux get the loopback flow outright', () {
      expect(
        GoogleDriveStorageProvider.authenticatorFor(
          isLoopbackPlatform: true,
          isMacOS: false,
        ),
        isA<DesktopOAuthAuthenticator>(),
      );
    });

    test('iOS and Android get google_sign_in outright', () {
      expect(
        GoogleDriveStorageProvider.authenticatorFor(
          isLoopbackPlatform: false,
          isMacOS: false,
        ),
        isA<GoogleSignInAuthenticator>(),
      );
    });

    test('macOS defers the choice to the keychain gate', () {
      // Neither flow works on every macOS build: google_sign_in needs the
      // data-protection keychain the Developer ID DMG cannot reach, and the
      // loopback listener needs the sandbox to be off. Only a runtime probe
      // can tell the two builds apart.
      expect(
        GoogleDriveStorageProvider.authenticatorFor(
          isLoopbackPlatform: false,
          isMacOS: true,
        ),
        isA<KeychainGatedAuthenticator>(),
      );
    });
  });
}
