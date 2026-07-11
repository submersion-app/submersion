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
}
