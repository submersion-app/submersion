import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';

Map<String, Object?> fileEntry(
  String name, {
  String tag = 'file',
  int size = 10,
}) => {
  '.tag': tag,
  'name': name,
  'path_lower': '/$name'.toLowerCase(),
  'path_display': '/$name',
  'server_modified': '2026-07-02T12:00:00Z',
  'size': size,
};

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response apiError(String summary, [int status = 409]) =>
    json({'error_summary': summary, 'error': {}}, status);

void main() {
  var rejectedCount = 0;
  var tokenCounter = 0;

  setUp(() {
    rejectedCount = 0;
    tokenCounter = 0;
  });

  DropboxApiClient client(
    MockClient mock, {
    int chunkedThreshold = 150 * 1024 * 1024,
    int chunkBytes = 8 * 1024 * 1024,
    List<Duration>? waits,
  }) => DropboxApiClient(
    getAccessToken: () async => 'token-${++tokenCounter}',
    onAccessTokenRejected: () => rejectedCount++,
    httpClient: mock,
    chunkedUploadThresholdBytes: chunkedThreshold,
    uploadChunkBytes: chunkBytes,
    wait: (d) async => waits?.add(d),
  );

  group('upload', () {
    test('single-call upload: content endpoint, overwrite mode, bearer '
        'token, api-arg header', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return json(fileEntry('submersion_sync.json'));
      });
      final meta = await client(
        mock,
      ).upload('/submersion_sync.json', Uint8List.fromList([1, 2, 3]));

      expect(
        seen.url.toString(),
        'https://content.dropboxapi.com/2/files/upload',
      );
      expect(seen.headers['Authorization'], 'Bearer token-1');
      expect(seen.headers['Content-Type'], 'application/octet-stream');
      final arg =
          jsonDecode(seen.headers['Dropbox-API-Arg']!) as Map<String, Object?>;
      expect(arg['path'], '/submersion_sync.json');
      expect(arg['mode'], 'overwrite');
      expect(arg['mute'], true);
      expect(seen.bodyBytes, [1, 2, 3]);
      expect(meta.pathLower, '/submersion_sync.json');
      expect(meta.serverModified, DateTime.utc(2026, 7, 2, 12));
    });

    test('payload above the threshold uses an upload session '
        '(start/append/finish with correct offsets)', () async {
      final calls = <(String, Map<String, Object?>, int)>[];
      final mock = MockClient((request) async {
        final arg =
            jsonDecode(request.headers['Dropbox-API-Arg']!)
                as Map<String, Object?>;
        calls.add((request.url.path, arg, request.bodyBytes.length));
        if (request.url.path == '/2/files/upload_session/start') {
          return json({'session_id': 'sess-1'});
        }
        if (request.url.path == '/2/files/upload_session/append_v2') {
          return json({});
        }
        return json(fileEntry('big.bin', size: 10));
      });
      final data = Uint8List.fromList(List.filled(10, 7));
      await client(
        mock,
        chunkedThreshold: 6,
        chunkBytes: 4,
      ).upload('/big.bin', data);

      expect(calls[0].$1, '/2/files/upload_session/start');
      expect(calls[0].$3, 4);
      expect(calls[1].$1, '/2/files/upload_session/append_v2');
      expect((calls[1].$2['cursor'] as Map<String, Object?>)['offset'], 4);
      expect(calls[1].$3, 4);
      expect(calls[2].$1, '/2/files/upload_session/finish');
      expect((calls[2].$2['cursor'] as Map<String, Object?>)['offset'], 8);
      expect(calls[2].$3, 2);
      expect(
        (calls[2].$2['commit'] as Map<String, Object?>)['path'],
        '/big.bin',
      );
    });

    test('insufficient_space maps to a distinct message', () async {
      final mock = MockClient(
        (_) async => apiError('path/insufficient_space/..'),
      );
      await expectLater(
        client(mock).upload('/f', Uint8List(1)),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('out of storage space'),
          ),
        ),
      );
    });
  });

  group('download', () {
    test('returns the body bytes', () async {
      final mock = MockClient(
        (request) async => http.Response.bytes([9, 8, 7], 200),
      );
      expect(await client(mock).download('/f.json'), [9, 8, 7]);
    });

    test('not_found throws CloudStorageException', () async {
      final mock = MockClient((_) async => apiError('path/not_found/..'));
      await expectLater(
        client(mock).download('/gone.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('getMetadata', () {
    test('maps the metadata JSON', () async {
      final mock = MockClient((_) async => json(fileEntry('f.json', size: 5)));
      final meta = await client(mock).getMetadata('/f.json');
      expect(meta!.name, 'f.json');
      expect(meta.size, 5);
    });

    test('not_found returns null', () async {
      final mock = MockClient((_) async => apiError('path/not_found/..'));
      expect(await client(mock).getMetadata('/gone'), isNull);
    });
  });

  group('listFolder', () {
    test(
      'follows has_more cursors to exhaustion and keeps only files',
      () async {
        var page = 0;
        final mock = MockClient((request) async {
          page++;
          if (page == 1) {
            expect(request.url.path, '/2/files/list_folder');
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['path'], '');
            return json({
              'entries': [fileEntry('a.json'), fileEntry('sub', tag: 'folder')],
              'cursor': 'cur-1',
              'has_more': true,
            });
          }
          expect(request.url.path, '/2/files/list_folder/continue');
          expect(
            (jsonDecode(request.body) as Map<String, Object?>)['cursor'],
            'cur-1',
          );
          return json({
            'entries': [fileEntry('b.json')],
            'cursor': 'cur-2',
            'has_more': false,
          });
        });
        final entries = await client(mock).listFolder();
        expect(entries.map((e) => e.name), ['a.json', 'b.json']);
      },
    );
  });

  group('delete', () {
    test('posts to delete_v2', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return json({'metadata': fileEntry('f.json')});
      });
      await client(mock).delete('/f.json');
      expect(seen.url.path, '/2/files/delete_v2');
      expect(
        (jsonDecode(seen.body) as Map<String, Object?>)['path'],
        '/f.json',
      );
    });

    test('not_found is treated as success (idempotent delete)', () async {
      final mock = MockClient(
        (_) async => apiError('path_lookup/not_found/..'),
      );
      await client(mock).delete('/already-gone');
    });
  });

  group('auth retry', () {
    test(
      'a 401 invalidates the token and retries once with a fresh one',
      () async {
        final tokens = <String?>[];
        final mock = MockClient((request) async {
          tokens.add(request.headers['Authorization']);
          if (tokens.length == 1) return http.Response('expired', 401);
          return json(fileEntry('f.json'));
        });
        final meta = await client(mock).getMetadata('/f.json');
        expect(meta, isNotNull);
        expect(rejectedCount, 1);
        expect(tokens, ['Bearer token-1', 'Bearer token-2']);
      },
    );

    test('a second 401 surfaces as an auth CloudStorageException', () async {
      final mock = MockClient((_) async => http.Response('expired', 401));
      await expectLater(
        client(mock).getMetadata('/f.json'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('Reconnect Dropbox'),
          ),
        ),
      );
      expect(rejectedCount, 2);
    });
  });

  group('rate limiting', () {
    test('a 429 waits Retry-After seconds and retries once', () async {
      final waits = <Duration>[];
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('slow down', 429, headers: {'retry-after': '3'});
        }
        return json(fileEntry('f.json'));
      });
      final meta = await client(mock, waits: waits).getMetadata('/f.json');
      expect(meta, isNotNull);
      expect(waits, [const Duration(seconds: 3)]);
    });

    test('a second 429 surfaces as CloudStorageException', () async {
      final mock = MockClient((_) async => http.Response('slow down', 429));
      await expectLater(
        client(mock, waits: []).getMetadata('/f.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('getCurrentAccount', () {
    test('parses email and display name', () async {
      final mock = MockClient(
        (_) async => json({
          'email': 'diver@example.com',
          'name': {'display_name': 'Diver'},
        }),
      );
      final account = await client(mock).getCurrentAccount();
      expect(account.email, 'diver@example.com');
      expect(account.displayName, 'Diver');
    });
  });

  group('network failures', () {
    test('a thrown ClientException wraps as CloudStorageException', () async {
      final mock = MockClient(
        (_) async => throw http.ClientException('connection refused'),
      );
      await expectLater(
        client(mock).getMetadata('/f.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });
}
