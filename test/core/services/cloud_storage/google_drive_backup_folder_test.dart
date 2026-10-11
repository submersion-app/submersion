import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';

/// `createFolder` on Drive used to create a new folder on every call, because
/// Drive allows any number of same-named folders. Every cloud backup therefore
/// landed in a folder of its own, and listing "the" backup folder (issue #3214)
/// saw at most one of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response json(Object? body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  /// A Drive whose appDataFolder holds [folders] (id + createdTime) and, in
  /// each folder, the backups named in [filesByFolder]. Records every list
  /// query and every create.
  ({MockClient client, List<String> queries, List<String> creates}) driveWith({
    List<Map<String, String>> folders = const [],
    Map<String, List<String>> filesByFolder = const {},
  }) {
    final queries = <String>[];
    final creates = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/drive/v3/files' && request.method == 'GET') {
        final q = request.url.queryParameters['q'] ?? '';
        queries.add(q);
        if (q.contains("mimeType = 'application/vnd.google-apps.folder'")) {
          return json({'files': folders});
        }
        return json({
          'files': [
            for (final entry in filesByFolder.entries)
              if (q.contains("'${entry.key}' in parents"))
                for (final name in entry.value)
                  {
                    'id': '${entry.key}/$name',
                    'name': name,
                    'modifiedTime': '2026-03-14T09:30:15.000Z',
                  },
          ],
        });
      }
      if (path == '/drive/v3/files' && request.method == 'POST') {
        creates.add(request.body);
        return json({'id': 'created-folder'});
      }
      return http.Response('unexpected: ${request.method} $path', 500);
    });
    return (client: client, queries: queries, creates: creates);
  }

  GoogleDriveStorageProvider providerOver(MockClient client) =>
      GoogleDriveStorageProvider()..debugSetDriveApi(drive.DriveApi(client));

  test('reuses the oldest existing folder instead of creating one', () async {
    final drive = driveWith(
      folders: [
        {'id': 'newer', 'createdTime': '2026-05-01T00:00:00.000Z'},
        {'id': 'oldest', 'createdTime': '2026-01-01T00:00:00.000Z'},
      ],
    );

    final id = await providerOver(
      drive.client,
    ).createFolder('Submersion Backups');

    expect(id, 'oldest');
    expect(drive.creates, isEmpty);
  });

  test('creates the folder when none exists', () async {
    final drive = driveWith();

    final id = await providerOver(
      drive.client,
    ).createFolder('Submersion Backups');

    expect(id, 'created-folder');
    expect(drive.creates, hasLength(1));
  });

  test('lists backups across every duplicate of the folder', () async {
    final drive = driveWith(
      folders: [
        {'id': 'a', 'createdTime': '2026-01-01T00:00:00.000Z'},
        {'id': 'b', 'createdTime': '2026-02-01T00:00:00.000Z'},
      ],
      filesByFolder: {
        'a': ['submersion_backup_2026-01-01_120000.db'],
        'b': ['submersion_backup_2026-02-01_120000.db'],
      },
    );
    final provider = providerOver(drive.client);

    final folderId = await provider.createFolder('Submersion Backups');
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: 'submersion_backup_',
    );

    expect(files.map((f) => f.name), [
      'submersion_backup_2026-01-01_120000.db',
      'submersion_backup_2026-02-01_120000.db',
    ]);
  });

  test('batches the parent clauses when there are many duplicates', () async {
    // One duplicate per backup ever made is realistic for a daily schedule;
    // a single query naming them all would exceed Drive's query length.
    final ids = [for (var i = 0; i < 120; i++) 'f$i'];
    final drive = driveWith(
      folders: [
        for (var i = 0; i < ids.length; i++)
          {
            'id': ids[i],
            'createdTime': DateTime.utc(
              2026,
              1,
              1,
            ).add(Duration(days: i)).toIso8601String(),
          },
      ],
      filesByFolder: {
        for (final id in ids) id: ['submersion_backup_$id.db'],
      },
    );
    final provider = providerOver(drive.client);

    final folderId = await provider.createFolder('Submersion Backups');
    drive.queries.clear();
    final files = await provider.listFiles(folderId: folderId);

    expect(files, hasLength(120));
    expect(drive.queries.length, greaterThan(1));
    for (final q in drive.queries) {
      expect(' in parents'.allMatches(q).length, lessThanOrEqualTo(50));
    }
  });

  test('a folder it never resolved is listed on its own', () async {
    final drive = driveWith(
      filesByFolder: {
        'x': ['a.json'],
        'y': ['b.json'],
      },
    );

    final files = await providerOver(drive.client).listFiles(folderId: 'x');

    expect(files.map((f) => f.name), ['a.json']);
  });
}
