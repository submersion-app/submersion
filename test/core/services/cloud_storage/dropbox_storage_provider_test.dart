import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';

import '../../../support/fake_keychain_storage.dart';

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> fileEntry(String name) => {
  '.tag': 'file',
  'name': name,
  'path_lower': '/${name.toLowerCase()}',
  'path_display': '/$name',
  'server_modified': '2026-07-02T12:00:00Z',
  'size': 3,
};

void main() {
  late InMemoryKeychain keychain;
  late DropboxAuthStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = DropboxAuthStore(storage: keychain);
  });

  Future<void> connect() =>
      store.save(DropboxAuthData(refreshToken: 'rt', email: 'd@example.com'));

  DropboxStorageProvider provider(MockClient mock) {
    final auth = DropboxAuthManager(
      appKey: 'k',
      store: store,
      httpClient: mock,
      now: () => DateTime.utc(2026, 7, 2, 12),
      verifierGenerator: () => 'a' * 43,
    );
    return DropboxStorageProvider(
      authManager: auth,
      apiClient: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
        httpClient: mock,
      ),
    );
  }

  /// Routes the token endpoint and delegates everything else to [handler].
  MockClient mockApi(Future<http.Response> Function(http.Request) handler) =>
      MockClient((request) async {
        if (request.url.path == '/oauth2/token') {
          return json({
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 14400,
          });
        }
        return handler(request);
      });

  test('identity and availability', () async {
    final p = provider(mockApi((_) async => json({})));
    expect(p.providerId, 'dropbox');
    expect(p.providerName, 'Dropbox');
    expect(await p.isAvailable(), isTrue);
  });

  test('isAuthenticated reflects the stored connection', () async {
    final p = provider(mockApi((_) async => json({})));
    expect(await p.isAuthenticated(), isFalse);
    await connect();
    expect(await p.isAuthenticated(), isTrue);
  });

  test('getUserEmail comes from the stored blob, no network', () async {
    await connect();
    final p = provider(
      mockApi((_) async => throw StateError('no API call expected')),
    );
    expect(await p.getUserEmail(), 'd@example.com');
  });

  test(
    'authenticate throws a "not connected" error when disconnected',
    () async {
      final p = provider(mockApi((_) async => json({})));
      await expectLater(
        p.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('not connected'),
          ),
        ),
      );
    },
  );

  test('authenticate probes the account when connected', () async {
    await connect();
    final paths = <String>[];
    final p = provider(
      mockApi((request) async {
        paths.add(request.url.path);
        return json({'email': 'd@example.com'});
      }),
    );
    await p.authenticate();
    expect(paths, ['/2/users/get_current_account']);
  });

  test('uploadFile roots bare filenames at the app folder and returns the '
      'path as fileId', () async {
    await connect();
    late Map<String, Object?> arg;
    final p = provider(
      mockApi((request) async {
        arg =
            jsonDecode(request.headers['Dropbox-API-Arg']!)
                as Map<String, Object?>;
        return json(fileEntry('submersion_sync.json'));
      }),
    );
    final result = await p.uploadFile(
      Uint8List.fromList([1]),
      'submersion_sync.json',
    );
    expect(arg['path'], '/submersion_sync.json');
    expect(result.fileId, '/submersion_sync.json');
    expect(result.uploadTime, DateTime.utc(2026, 7, 2, 12));
  });

  test('uploadFile respects an explicit folderId', () async {
    await connect();
    late Map<String, Object?> arg;
    final p = provider(
      mockApi((request) async {
        arg =
            jsonDecode(request.headers['Dropbox-API-Arg']!)
                as Map<String, Object?>;
        return json(fileEntry('c.json'));
      }),
    );
    await p.uploadFile(
      Uint8List.fromList([1]),
      'c.json',
      folderId: '/changesets',
    );
    expect(arg['path'], '/changesets/c.json');
  });

  test('listFiles maps metadata and applies namePattern', () async {
    await connect();
    final p = provider(
      mockApi(
        (_) async => json({
          'entries': [
            fileEntry('submersion_sync.json'),
            fileEntry('other.txt'),
          ],
          'cursor': 'c',
          'has_more': false,
        }),
      ),
    );
    final files = await p.listFiles(namePattern: 'submersion_sync');
    expect(files, hasLength(1));
    expect(files.single.id, '/submersion_sync.json');
    expect(files.single.name, 'submersion_sync.json');
    expect(files.single.sizeBytes, 3);
  });

  test(
    'getFileInfo returns null for a missing file; fileExists follows it',
    () async {
      await connect();
      final p = provider(
        mockApi(
          (_) async =>
              json({'error_summary': 'path/not_found/..', 'error': {}}, 409),
        ),
      );
      expect(await p.getFileInfo('/gone.json'), isNull);
      expect(await p.fileExists('/gone.json'), isFalse);
    },
  );

  test(
    'createFolder and getOrCreateSyncFolder are pure path construction',
    () async {
      await connect();
      final p = provider(
        mockApi((_) async => throw StateError('no API call expected')),
      );
      expect(await p.getOrCreateSyncFolder(), '');
      expect(await p.createFolder('changesets'), '/changesets');
      expect(
        await p.createFolder('device-1', parentFolderId: '/changesets'),
        '/changesets/device-1',
      );
    },
  );

  test('signOut clears the stored connection', () async {
    await connect();
    final p = provider(mockApi((_) async => json({})));
    await p.signOut();
    expect(await store.load(), isNull);
  });

  test('mixin conflict detection matches Dropbox conflicted-copy names', () {
    final p = provider(mockApi((_) async => json({})));
    expect(
      p.isConflictCopy('submersion_sync (conflicted copy 2026-07-02).json'),
      isTrue,
    );
    expect(p.isConflictCopy('submersion_sync.json'), isFalse);
  });
}
