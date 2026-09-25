import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

RemotePhoto _photo(String name) => RemotePhoto(
  url: Uri.parse('https://divelogs.de/pics/$name'),
  fileName: name,
);

void main() {
  final start = DateTime.utc(2024, 5, 1, 9);

  test('downloads and attaches photos of surviving dives only', () async {
    final attached = <(String, String, List<int>)>[];
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
        'divelogs-2': [_photo('b.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1', 1: 'dive-2'},
      removedDiveIds: const {'dive-2'},
      dives: [
        {'sourceUuid': 'divelogs-1', 'dateTime': start},
        {'sourceUuid': 'divelogs-2', 'dateTime': start},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1, 2, 3]),
      attach: (file, diveId, diveStart) async {
        attached.add((diveId, p.basename(file.path), await file.readAsBytes()));
        expect(diveStart, start);
      },
    );

    expect(outcome, (attached: 1, failed: 0));
    expect(attached.single.$1, 'dive-1');
    expect(attached.single.$2, 'a.jpg');
    expect(attached.single.$3, [1, 2, 3]);
  });

  test('prefers the existing dive start for a matched duplicate', () async {
    final existingStart = DateTime.utc(2024, 5, 1, 9, 5);
    DateTime? seen;
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'existing-dive'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1', 'dateTime': start},
      ],
      diveStartById: {'existing-dive': existingStart},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async => seen = diveStart,
    );
    expect(seen, existingStart);
  });

  test('two photos with the same name on one dive both attach', () async {
    final names = <String>[];
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('same.jpg'), _photo('same.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([names.length]),
      attach: (file, diveId, diveStart) async {
        names.add(p.basename(file.path));
        expect(file.existsSync(), isTrue);
      },
    );
    expect(outcome.attached, 2);
    expect(names, ['same.jpg', 'same.jpg']);
  });

  test('a failed download is counted and the rest continue', () async {
    var calls = 0;
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('bad.jpg'), _photo('good.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async {
        if (url.path.endsWith('bad.jpg')) throw Exception('401');
        return Uint8List.fromList([1]);
      },
      attach: (file, diveId, diveStart) async => calls++,
    );
    expect(outcome, (attached: 1, failed: 1));
    expect(calls, 1);
  });

  test('a failed attach is counted as failed', () async {
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async =>
          throw const FileSystemException('disk full'),
    );
    expect(outcome, (attached: 0, failed: 1));
  });

  test('stops downloading once cancelled', () async {
    final token = ImportCancellationToken();
    var downloads = 0;
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg'), _photo('b.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async {
        downloads++;
        token.cancel();
        return Uint8List.fromList([1]);
      },
      attach: (file, diveId, diveStart) async {},
      cancelToken: token,
    );
    expect(downloads, 1);
  });

  test('leaves no temp files behind', () async {
    final seen = <String>[];
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async =>
          seen.add(file.parent.parent.path),
    );
    expect(Directory(seen.single).existsSync(), isFalse);
  });

  test('an error that stops the run fails every remaining photo', () async {
    var downloads = 0;
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg'), _photo('b.jpg')],
        'divelogs-2': [_photo('c.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1', 1: 'dive-2'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
        {'sourceUuid': 'divelogs-2'},
      ],
      diveStartById: const {},
      download: (url) async {
        downloads++;
        throw StateError('session expired');
      },
      attach: (file, diveId, diveStart) async {},
      stopOn: (error) => error is StateError,
    );
    expect(downloads, 1);
    expect(outcome, (attached: 0, failed: 3));
  });
}
