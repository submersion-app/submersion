import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';

/// Exercises the provider's transfer paths through a [drive.DriveApi] backed
/// by a mock HTTP client (injected via the debugSetDriveApi seam), since the
/// real api is only ever minted from an authenticated Google session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gdrive_provider_test');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  http.Response jsonResponse(Object? body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  GoogleDriveStorageProvider providerWith(MockClient mock) =>
      GoogleDriveStorageProvider()..debugSetDriveApi(drive.DriveApi(mock));

  /// Routes the Drive REST surface: file listing (for _findFile), multipart
  /// AND resumable upload protocols (googleapis picks one), and alt=media
  /// downloads.
  MockClient driveMock({
    List<Map<String, Object?>> existingFiles = const [],
    List<int>? mediaBytes,
    int mediaStatus = 200,
    void Function(http.Request request)? onRequest,
  }) {
    return MockClient((request) async {
      onRequest?.call(request);
      final path = request.url.path;
      if (path == '/drive/v3/files' && request.method == 'GET') {
        return jsonResponse({'files': existingFiles});
      }
      if (path.startsWith('/upload/')) {
        if (request.url.queryParameters['uploadType'] == 'resumable' &&
            request.method == 'POST') {
          return http.Response(
            '',
            200,
            headers: {
              'location':
                  'https://www.googleapis.com/upload/session/fake-session',
            },
          );
        }
        // Multipart upload, or a resumable-session data PUT.
        return jsonResponse({'id': 'uploaded-id', 'name': 'b.db'});
      }
      if (path.startsWith('/drive/v3/files/') &&
          request.url.queryParameters['alt'] == 'media') {
        if (mediaStatus != 200) {
          return http.Response('not found', mediaStatus);
        }
        return http.Response.bytes(
          mediaBytes!,
          200,
          headers: {
            'content-type': 'application/octet-stream',
            'content-length': '${mediaBytes.length}',
          },
        );
      }
      return http.Response('unexpected: ${request.method} $path', 500);
    });
  }

  group('uploadFileFromPath', () {
    test('streams a new file into the target folder', () async {
      final src = File('${tempDir.path}/backup.db')
        ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));
      final methods = <String>[];
      final provider = providerWith(
        driveMock(onRequest: (r) => methods.add(r.method)),
      );

      final result = await provider.uploadFileFromPath(
        src.path,
        'b.db',
        folderId: 'folder-1',
      );

      expect(result.fileId, 'uploaded-id');
      // The file did not exist, so the create path ran (a POST, not a PATCH).
      expect(methods, contains('POST'));
      expect(methods, isNot(contains('PATCH')));
    });

    test('updates in place when the file already exists', () async {
      final src = File('${tempDir.path}/backup.db')
        ..writeAsBytesSync(List<int>.generate(1024, (i) => i % 251));
      final methods = <String>[];
      final provider = providerWith(
        driveMock(
          existingFiles: [
            {'id': 'uploaded-id', 'name': 'b.db'},
          ],
          onRequest: (r) => methods.add(r.method),
        ),
      );

      final result = await provider.uploadFileFromPath(
        src.path,
        'b.db',
        folderId: 'folder-1',
      );

      expect(result.fileId, 'uploaded-id');
      expect(
        methods,
        contains('PATCH'),
        reason: 'an existing file must be updated, not duplicated',
      );
    });

    test('wraps transport failures in CloudStorageException', () async {
      final src = File('${tempDir.path}/backup.db')..writeAsBytesSync([1]);
      final provider = providerWith(
        MockClient((_) async => http.Response('boom', 500)),
      );

      await expectLater(
        provider.uploadFileFromPath(src.path, 'b.db', folderId: 'folder-1'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('listFiles pagination', () {
    /// Serves [pages] one files.list call at a time, handing out a
    /// nextPageToken for every page but the last -- Drive's own protocol.
    /// Records each request so the test can assert what was asked for.
    MockClient pagedDriveMock(
      List<List<Map<String, Object?>>> pages, {
      List<Uri>? listRequests,
    }) {
      return MockClient((request) async {
        if (request.url.path != '/drive/v3/files' || request.method != 'GET') {
          return http.Response(
            'unexpected: ${request.method} ${request.url}',
            500,
          );
        }
        listRequests?.add(request.url);
        final token = request.url.queryParameters['pageToken'];
        final index = token == null ? 0 : int.parse(token);
        return jsonResponse({
          'files': pages[index],
          if (index < pages.length - 1) 'nextPageToken': '${index + 1}',
        });
      });
    }

    Map<String, Object?> file(String name) => {
      'id': 'id-$name',
      'name': name,
      'modifiedTime': '2026-01-01T00:00:00.000Z',
      'size': '10',
    };

    test('follows nextPageToken and returns every page', () async {
      final provider = providerWith(
        pagedDriveMock([
          [file('a'), file('b')],
          [file('c')],
        ]),
      );

      final files = await provider.listFiles(folderId: 'folder-1');

      expect(files.map((f) => f.name), [
        'a',
        'b',
        'c',
      ], reason: 'a single files.list call truncates at Drive\'s page size');
    });

    test('asks for nextPageToken and an explicit page size', () async {
      final requests = <Uri>[];
      final provider = providerWith(
        pagedDriveMock([
          [file('a')],
        ], listRequests: requests),
      );

      await provider.listFiles(folderId: 'folder-1');

      expect(requests, hasLength(1));
      expect(
        requests.single.queryParameters['fields'],
        contains('nextPageToken'),
        reason:
            'a \$fields listing only files(...) suppresses the token, so the '
            'page loop would stop after one page with no error',
      );
      expect(requests.single.queryParameters['pageSize'], '1000');
    });

    test(
      'paginates a name lookup, so an existing file is never duplicated',
      () async {
        final src = File('${tempDir.path}/backup.db')
          ..writeAsBytesSync([1, 2, 3]);
        final methods = <String>[];
        final provider = GoogleDriveStorageProvider()
          ..debugSetDriveApi(
            drive.DriveApi(
              MockClient((request) async {
                methods.add(request.method);
                if (request.url.path == '/drive/v3/files' &&
                    request.method == 'GET') {
                  final token = request.url.queryParameters['pageToken'];
                  // Drive may hand back a short (even empty) page while more
                  // results remain; the match only appears on page two.
                  return jsonResponse(
                    token == null
                        ? {'files': <Object?>[], 'nextPageToken': '1'}
                        : {
                            'files': [
                              {'id': 'uploaded-id', 'name': 'b.db'},
                            ],
                          },
                  );
                }
                return jsonResponse({'id': 'uploaded-id', 'name': 'b.db'});
              }),
            ),
          );

        final result = await provider.uploadFileFromPath(
          src.path,
          'b.db',
          folderId: 'folder-1',
        );

        expect(result.fileId, 'uploaded-id');
        expect(
          methods,
          contains('PATCH'),
          reason: 'the match on page two must update, not create a duplicate',
        );
      },
    );

    test('treats an empty token as the end of the listing', () async {
      final provider = providerWith(
        MockClient((request) async {
          if (request.url.path != '/drive/v3/files') {
            return http.Response('unexpected', 500);
          }
          // A token of '' would re-issue the same request forever if it were
          // only null-checked.
          return jsonResponse({
            'files': [
              {'id': 'id-a', 'name': 'a'},
            ],
            'nextPageToken': '',
          });
        }),
      );

      final files = await provider.listFiles(folderId: 'folder-1');

      expect(files.map((f) => f.name), ['a']);
    });
  });

  group('downloadToFile', () {
    test('pipes the media stream straight to disk', () async {
      final data = List<int>.generate(64 * 1024, (i) => i % 249);
      final provider = providerWith(driveMock(mediaBytes: data));
      final dest = File('${tempDir.path}/out.bin');

      await provider.downloadToFile('file-1', dest.path);

      expect(dest.readAsBytesSync(), Uint8List.fromList(data));
    });

    test('a missing file throws and leaves no destination file', () async {
      final provider = providerWith(driveMock(mediaStatus: 404));
      final dest = File('${tempDir.path}/out.bin');

      await expectLater(
        provider.downloadToFile('file-1', dest.path),
        throwsA(isA<CloudStorageException>()),
      );
      expect(dest.existsSync(), isFalse);
    });
  });
}
