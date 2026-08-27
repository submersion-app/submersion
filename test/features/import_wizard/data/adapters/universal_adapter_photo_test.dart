import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';

PickedImportFile _file(String name) => PickedImportFile(
  name: name,
  detection: const DetectionResult(format: ImportFormat.danDl7, confidence: 1),
  status: ImportFileStatus.parsed,
);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('photo_attach_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> photo(String name) async {
    final path = p.join(tmp.path, name);
    await File(path).writeAsBytes([1, 2, 3]);
    return path;
  }

  test('attaches photos to the single dive of each source file', () async {
    final photoA = await photo('a_pic.jpg');
    final attached = <(String, String)>[];

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'dive_a': [photoA],
      },
      diveIdByIndex: const {0: 'dive-id-a', 1: 'dive-id-b'},
      removedDiveIds: const {},
      dives: const [
        {'_sourceFileId': 'f0', 'dateTime': null},
        {'_sourceFileId': 'f1'},
      ],
      files: [_file('dive_a.zxu'), _file('dive_b.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async {
        attached.add((diveId, file.path));
      },
    );

    expect(count, 1);
    expect(attached.single.$1, 'dive-id-a');
    expect(attached.single.$2, photoA);
  });

  test('single-file flow maps photos via the state file name', () async {
    final photoA = await photo('solo_pic.jpg');
    final attached = <String>[];

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'solo': [photoA],
      },
      diveIdByIndex: const {0: 'dive-id-solo'},
      removedDiveIds: const {},
      dives: const [
        {'name': 'no source stamp on single-file payloads'},
      ],
      files: [_file('solo.zxu')],
      singleFileName: 'solo.zxu',
      attach: (file, diveId, takenAt) async => attached.add(diveId),
    );

    expect(count, 1);
    expect(attached.single, 'dive-id-solo');
  });

  test('skips consolidated-away dives and multi-dive files', () async {
    final photoA = await photo('a.jpg');
    final photoB = await photo('b.jpg');
    var calls = 0;

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'removed': [photoA],
        'multi': [photoB],
      },
      diveIdByIndex: const {0: 'gone', 1: 'm1', 2: 'm2'},
      removedDiveIds: const {'gone'},
      dives: const [
        {'_sourceFileId': 'f0'},
        {'_sourceFileId': 'f1'},
        {'_sourceFileId': 'f1'},
      ],
      files: [_file('removed.zxu'), _file('multi.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async => calls++,
    );

    expect(count, 0);
    expect(calls, 0);
  });

  test('a failing attach is swallowed and not counted', () async {
    final photoA = await photo('x.jpg');
    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'x': [photoA],
      },
      diveIdByIndex: const {0: 'dive-x'},
      removedDiveIds: const {},
      dives: const [
        {'_sourceFileId': 'f0'},
      ],
      files: [_file('x.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async => throw Exception('disk full'),
    );
    expect(count, 0);
  });
  group('attachResolvedPhotos', () {
    test('attaches each resolved photo to its own dive', () async {
      final attached = <({String path, String diveId, DateTime? takenAt})>[];

      final count = await UniversalAdapter.attachResolvedPhotos(
        media: [
          {
            'filename': '/home/jai/Pictures/a.jpg',
            'offsetSeconds': 200,
            '_diveIndex': 0,
          },
          {
            'filename': '/home/jai/Pictures/b.jpg',
            'offsetSeconds': null,
            '_diveIndex': 1,
          },
        ],
        resolvedPathByIndex: const {
          0: '/Users/eric/Photos/a.jpg',
          1: '/Users/eric/Photos/b.jpg',
        },
        diveIdByIndex: const {0: 'dive-a', 1: 'dive-b'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
          {'dateTime': DateTime.utc(2025, 1, 16, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attached.add((path: file.path, diveId: diveId, takenAt: takenAt));
        },
      );

      expect(count, 2);
      expect(attached, hasLength(2));
      final byDive = {for (final a in attached) a.diveId: a};
      // Dive start plus the 3:20 offset.
      expect(byDive['dive-a']!.takenAt, DateTime.utc(2025, 1, 15, 10, 3, 20));
      // No offset: falls back to the dive's own start.
      expect(byDive['dive-b']!.takenAt, DateTime.utc(2025, 1, 16, 10));
    });

    test('applies a negative offset before the dive start', () async {
      DateTime? seen;

      await UniversalAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': -65, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          seen = takenAt;
        },
      );

      expect(seen, DateTime.utc(2025, 1, 15, 9, 58, 55));
    });

    test('drops photos whose dive was folded away by consolidation', () async {
      var attachCalls = 0;

      final count = await UniversalAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/Users/eric/Photos/a.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {'dive-a'},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attachCalls++;
        },
      );

      expect(count, 0);
      expect(attachCalls, 0);
    });

    test('counts a failed copy without failing the import', () async {
      final count = await UniversalAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
          {'filename': '/p/b.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg', 1: '/x/b.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          if (file.path.endsWith('b.jpg')) {
            throw const FileSystemException('copy failed');
          }
        },
      );

      expect(count, 1);
    });

    test('passes the picture coordinates through', () async {
      double? seenLatitude;
      double? seenLongitude;

      await UniversalAdapter.attachResolvedPhotos(
        media: [
          {
            'filename': '/p/a.jpg',
            'offsetSeconds': 0,
            'latitude': 18.465562,
            'longitude': -66.084902,
            '_diveIndex': 0,
          },
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          seenLatitude = latitude;
          seenLongitude = longitude;
        },
      );

      expect(seenLatitude, closeTo(18.465562, 1e-6));
      expect(seenLongitude, closeTo(-66.084902, 1e-6));
    });

    test('leaves out a photo the user deselected in review', () async {
      final attached = <String>[];

      final count = await UniversalAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
          {'filename': '/p/b.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg', 1: '/x/b.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        selectedIndices: const {0},
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attached.add(file.path);
        },
      );

      expect(count, 1);
      expect(attached, ['/x/a.jpg']);
    });

    test('a null selection attaches every resolved photo', () async {
      var attachCalls = 0;

      final count = await UniversalAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
          {'filename': '/p/b.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg', 1: '/x/b.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attachCalls++;
        },
      );

      expect(count, 2);
      expect(attachCalls, 2);
    });

    test(
      'ignores a picture whose dive never made it into the import',
      () async {
        var attachCalls = 0;

        final count = await UniversalAdapter.attachResolvedPhotos(
          media: [
            {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 7},
          ],
          resolvedPathByIndex: const {0: '/x/a.jpg'},
          diveIdByIndex: const {0: 'dive-a'},
          removedDiveIds: const {},
          dives: [
            {'dateTime': DateTime.utc(2025, 1, 15, 10)},
          ],
          attach: (file, diveId, takenAt, latitude, longitude) async {
            attachCalls++;
          },
        );

        expect(count, 0);
        expect(attachCalls, 0);
      },
    );
  });
}
