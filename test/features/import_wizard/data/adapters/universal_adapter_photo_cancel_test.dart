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
}
