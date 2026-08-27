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
