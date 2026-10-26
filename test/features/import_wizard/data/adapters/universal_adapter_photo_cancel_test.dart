import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';

/// Photo linking runs after the dives and stops on a cancel too (issue
/// #3216): a MacDive logbook can reference thousands of photos, and a
/// cancel that waited for every one of them to link was no cancel at all.
void main() {
  group('attachResolvedPhotos', () {
    final media = [
      for (var i = 0; i < 3; i++) {'filename': 'p$i.jpg', '_diveIndex': i},
    ];
    const resolved = {0: 'p0.jpg', 1: 'p1.jpg', 2: 'p2.jpg'};
    const diveIds = {0: 'dive-0', 1: 'dive-1', 2: 'dive-2'};
    final dives = [
      for (var i = 0; i < 3; i++) {'dateTime': DateTime.utc(2025, 1, 15 + i)},
    ];

    test('stops at the next photo once the import is cancelled', () async {
      final token = ImportCancellationToken();
      final attached = <String>[];

      final count = await UniversalAdapter.attachResolvedPhotos(
        media: media,
        resolvedPathByIndex: resolved,
        diveIdByIndex: diveIds,
        removedDiveIds: const {},
        dives: dives,
        cancelToken: token,
        attach: (photo) async {
          attached.add(photo.diveId);
          token.cancel();
        },
      );

      expect(attached, ['dive-0']);
      expect(count, 1);
    });

    test('attaches nothing when cancelled before it starts', () async {
      final count = await UniversalAdapter.attachResolvedPhotos(
        media: media,
        resolvedPathByIndex: resolved,
        diveIdByIndex: diveIds,
        removedDiveIds: const {},
        dives: dives,
        cancelToken: ImportCancellationToken()..cancel(),
        attach: (photo) async => fail('attached after a cancel'),
      );

      expect(count, 0);
    });
  });

  group('attachImportedPhotos', () {
    test('stops at the next photo once the import is cancelled', () async {
      final token = ImportCancellationToken();
      final attached = <String>[];

      final count = await UniversalAdapter.attachImportedPhotos(
        photoPathsByBaseName: const {
          'a': ['a1.jpg', 'a2.jpg'],
          'b': ['b1.jpg'],
        },
        diveIdByIndex: const {0: 'dive-a', 1: 'dive-b'},
        removedDiveIds: const {},
        dives: const [
          {'_sourceFileId': 'f0'},
          {'_sourceFileId': 'f1'},
        ],
        files: [
          for (final name in ['a.zxu', 'b.zxu'])
            PickedImportFile(
              name: name,
              detection: const DetectionResult(
                format: ImportFormat.danDl7,
                confidence: 1,
              ),
              status: ImportFileStatus.parsed,
            ),
        ],
        singleFileName: null,
        cancelToken: token,
        attach: (file, diveId, diveStart) async {
          attached.add(file.path);
          token.cancel();
        },
      );

      expect(attached, ['a1.jpg']);
      expect(count, 1);
    });
  });

  group('photo progress (#3555)', () {
    test('resolved photos count up to all of them, skipped ones too', () async {
      final progress = <(int, int)>[];
      await UniversalAdapter.attachResolvedPhotos(
        media: [
          for (var i = 0; i < 3; i++) {'filename': 'p$i.jpg', '_diveIndex': i},
        ],
        resolvedPathByIndex: const {0: 'p0.jpg', 1: 'p1.jpg', 2: 'p2.jpg'},
        diveIdByIndex: const {0: 'dive-0', 1: 'dive-1', 2: 'dive-2'},
        removedDiveIds: const {},
        dives: const [{}, {}, {}],
        selectedIndices: const {0, 2},
        attach: (photo) async {},
        onProgress: (current, total) => progress.add((current, total)),
      );
      expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    });

    test('bundled photos count up photo by photo', () async {
      final progress = <(int, int)>[];
      await UniversalAdapter.attachImportedPhotos(
        photoPathsByBaseName: const {
          'solo': ['a.jpg', 'b.jpg'],
        },
        diveIdByIndex: const {0: 'dive-solo'},
        removedDiveIds: const {},
        dives: const [{}],
        files: const [],
        singleFileName: 'solo.zxu',
        attach: (file, diveId, diveStart) async {},
        onProgress: (current, total) => progress.add((current, total)),
      );
      expect(progress, [(0, 2), (1, 2), (2, 2)]);
    });
  });
}
