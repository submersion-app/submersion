import 'dart:convert';
import 'dart:io';
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

  group('path-based transfers', () {
    // 8 MiB, matching the provider's transfer chunk size.
    const chunk = 8 * 1024 * 1024;
    late Directory tempDir;

    setUp(() async {
      await connect();
      tempDir = Directory.systemTemp.createTempSync('dropbox_provider_test');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    File writeSource(int length) {
      final file = File('${tempDir.path}/src.bin');
      file.writeAsBytesSync(
        Uint8List.fromList(List<int>.generate(length, (i) => i % 251)),
      );
      return file;
    }

    Map<String, Object?> fileEntrySized(String name, int size) => {
      ...fileEntry(name),
      'size': size,
    };

    test('small uploads take the single upload endpoint', () async {
      final src = writeSource(1024);
      final paths = <String>[];
      final p = provider(
        mockApi((request) async {
          paths.add(request.url.path);
          return json(fileEntry('small.db'));
        }),
      );

      final result = await p.uploadFileFromPath(src.path, 'small.db');

      expect(paths, ['/2/files/upload']);
      expect(result.fileId, '/small.db');
    });

    test(
      'large uploads stream through an upload session, byte-identical',
      () async {
        final src = writeSource(2 * chunk + 1024); // start + append + finish
        final paths = <String>[];
        final received = BytesBuilder(copy: false);
        final p = provider(
          mockApi((request) async {
            paths.add(request.url.path);
            received.add(request.bodyBytes);
            switch (request.url.path) {
              case '/2/files/upload_session/start':
                return json({'session_id': 's1'});
              case '/2/files/upload_session/append_v2':
                return json({});
              case '/2/files/upload_session/finish':
                return json(fileEntrySized('big.db', 2 * chunk + 1024));
              default:
                return http.Response('unexpected', 500);
            }
          }),
        );

        final result = await p.uploadFileFromPath(src.path, 'big.db');

        expect(paths, [
          '/2/files/upload_session/start',
          '/2/files/upload_session/append_v2',
          '/2/files/upload_session/finish',
        ]);
        expect(
          received.takeBytes(),
          src.readAsBytesSync(),
          reason: 'session chunks must reassemble byte-identical',
        );
        expect(result.fileId, '/big.db');
      },
    );

    test('small downloads take the single download endpoint', () async {
      final p = provider(
        mockApi((request) async {
          if (request.url.path == '/2/files/get_metadata') {
            return json(fileEntry('f.db'));
          }
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      final dest = File('${tempDir.path}/out.bin');

      await p.downloadToFile('/f.db', dest.path);

      expect(dest.readAsBytesSync(), [1, 2, 3]);
    });

    test('large downloads stream by ranges, byte-identical', () async {
      final data = Uint8List.fromList(
        List<int>.generate(chunk + 4096, (i) => i % 249),
      );
      final p = provider(
        mockApi((request) async {
          if (request.url.path == '/2/files/get_metadata') {
            return json(fileEntrySized('big.db', data.length));
          }
          final range = request.headers['Range']!;
          final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
          final start = int.parse(m.group(1)!);
          final end = int.parse(m.group(2)!).clamp(0, data.length - 1);
          return http.Response.bytes(
            Uint8List.sublistView(data, start, end + 1),
            206,
            headers: {'content-range': 'bytes $start-$end/${data.length}'},
          );
        }),
      );
      final dest = File('${tempDir.path}/out.bin');

      await p.downloadToFile('/big.db', dest.path);

      expect(dest.readAsBytesSync(), data);
    });

    test('a missing file throws and leaves no destination file', () async {
      final p = provider(
        mockApi(
          (request) async => http.Response(
            jsonEncode({'error_summary': 'path/not_found/..'}),
            409,
          ),
        ),
      );
      final dest = File('${tempDir.path}/out.bin');

      await expectLater(
        p.downloadToFile('/nope.db', dest.path),
        throwsA(isA<CloudStorageException>()),
      );
      expect(dest.existsSync(), isFalse);
    });

    test('a mid-range failure deletes the partial download', () async {
      final data = Uint8List.fromList(
        List<int>.generate(chunk + 4096, (i) => i % 249),
      );
      final p = provider(
        mockApi((request) async {
          if (request.url.path == '/2/files/get_metadata') {
            return json(fileEntrySized('big.db', data.length));
          }
          final range = request.headers['Range']!;
          if (!range.startsWith('bytes=0-')) {
            return http.Response('boom', 500);
          }
          return http.Response.bytes(
            Uint8List.sublistView(data, 0, chunk),
            206,
            headers: {'content-range': 'bytes 0-${chunk - 1}/${data.length}'},
          );
        }),
      );
      final dest = File('${tempDir.path}/out.bin');

      await expectLater(
        p.downloadToFile('/big.db', dest.path),
        throwsA(isA<CloudStorageException>()),
      );
      expect(
        dest.existsSync(),
        isFalse,
        reason: 'a truncated download must never be left for the caller',
      );
    });
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
