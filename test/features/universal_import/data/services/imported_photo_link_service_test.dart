import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/imported_photo_link_service.dart';
import 'package:submersion/features/universal_import/data/services/imported_photo_storage.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';

import '../../../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ResolvedPhoto _resolved({
  required String diveSourceUuid,
  required String filename,
  Uint8List? bytes,
  String? caption,
  int position = 0,
  PhotoResolutionKind kind = PhotoResolutionKind.directPath,
}) {
  return ResolvedPhoto(
    ref: ImportImageRef(
      originalPath: '/orig/$filename',
      diveSourceUuid: diveSourceUuid,
      caption: caption,
      position: position,
    ),
    kind: bytes == null ? PhotoResolutionKind.miss : kind,
    bytes: bytes,
    resolvedPath: bytes == null ? null : '/orig/$filename',
  );
}

/// Insert a minimal dive row so [MediaRepository.createMedia] can satisfy
/// its foreign-key constraint (media.dive_id REFERENCES dives.id). We use
/// raw companion insertion rather than DiveRepository to keep the test
/// focused on the linking service, not the domain model.
Future<void> _insertBareDive(AppDatabase db, String diveId) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: diveId,
          diveDateTime: DateTime(2024, 6, 1).millisecondsSinceEpoch ~/ 1000,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late Directory mediaRoot;
  late MediaRepository mediaRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRoot = Directory.systemTemp.createTempSync('ipls_media_');
    mediaRepository = MediaRepository();
  });

  tearDown(() async {
    if (mediaRoot.existsSync()) mediaRoot.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  ImportedPhotoLinkService buildService() {
    return ImportedPhotoLinkService(
      storage: ImportedPhotoStorage(mediaRoot: mediaRoot.path),
      mediaRepository: mediaRepository,
    );
  }

  group('ImportedPhotoLinkService.linkAll', () {
    test(
      'resolved photos with bytes are written to disk and registered as MediaItems',
      () async {
        const diveSourceUuid = 'dive-src-1';
        const newDiveId = 'new-dive-1';
        await _insertBareDive(db, newDiveId);
        final service = buildService();

        final result = await service.linkAll(
          resolved: [
            _resolved(
              diveSourceUuid: diveSourceUuid,
              filename: 'shark.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
              caption: 'Reef shark!',
              position: 2,
            ),
          ],
          sourceUuidToDiveId: const {diveSourceUuid: newDiveId},
        );

        expect(result.written, 1);
        expect(result.missingBytes, 0);
        expect(result.orphanDive, 0);
        expect(result.failures, 0);
        expect(result.isAllWritten, isTrue);

        // File landed under <mediaRoot>/dive/<newDiveId>/2-shark.jpg.
        final expected = File('${mediaRoot.path}/dive/$newDiveId/2-shark.jpg');
        expect(expected.existsSync(), isTrue);
        expect(expected.readAsBytesSync(), [1, 2, 3]);

        // MediaItem row is linked back to the dive with the correct filePath.
        final media = await mediaRepository.getMediaForDive(newDiveId);
        expect(media, hasLength(1));
        expect(media.single.diveId, newDiveId);
        expect(media.single.filePath, expected.path);
        expect(media.single.originalFilename, 'shark.jpg');
        expect(media.single.caption, 'Reef shark!');
      },
    );

    test(
      'photos with null bytes are counted as missing, no file or row',
      () async {
        const diveSourceUuid = 'dive-src-1';
        const newDiveId = 'new-dive-1';
        await _insertBareDive(db, newDiveId);
        final service = buildService();

        final result = await service.linkAll(
          resolved: [
            _resolved(
              diveSourceUuid: diveSourceUuid,
              filename: 'missing.jpg',
              bytes: null, // resolver miss the user accepted
            ),
          ],
          sourceUuidToDiveId: const {diveSourceUuid: newDiveId},
        );

        expect(result.written, 0);
        expect(result.missingBytes, 1);
        expect(result.orphanDive, 0);
        expect(result.failures, 0);

        // No files written and no MediaItem rows created.
        final diveDir = Directory('${mediaRoot.path}/dive/$newDiveId');
        expect(diveDir.existsSync(), isFalse);
        final media = await mediaRepository.getMediaForDive(newDiveId);
        expect(media, isEmpty);
      },
    );

    test(
      'photo whose diveSourceUuid is unknown is silently dropped as orphan',
      () async {
        final service = buildService();

        final result = await service.linkAll(
          resolved: [
            _resolved(
              diveSourceUuid: 'filtered-out-uuid',
              filename: 'x.jpg',
              bytes: Uint8List.fromList([9]),
            ),
          ],
          // Note: no entry for 'filtered-out-uuid' — simulates the user
          // deselecting the parent dive as a duplicate.
          sourceUuidToDiveId: const {},
        );

        expect(result.written, 0);
        expect(result.orphanDive, 1);
        expect(result.missingBytes, 0);
        expect(result.failures, 0);

        // Assert: no MediaItem was created against any dive in the DB.
        final rows = await db.select(db.media).get();
        expect(rows, isEmpty);
      },
    );

    test(
      'mixed batch: writes valid photos, skips misses and orphans',
      () async {
        const diveA = 'src-A';
        const diveB = 'src-B';
        const newA = 'new-A';
        const newB = 'new-B';
        await _insertBareDive(db, newA);
        await _insertBareDive(db, newB);
        final service = buildService();

        final result = await service.linkAll(
          resolved: [
            _resolved(
              diveSourceUuid: diveA,
              filename: 'a1.jpg',
              bytes: Uint8List.fromList([1]),
              position: 0,
            ),
            _resolved(
              diveSourceUuid: diveA,
              filename: 'a2.jpg',
              bytes: null, // miss
              position: 1,
            ),
            _resolved(
              diveSourceUuid: diveB,
              filename: 'b1.jpg',
              bytes: Uint8List.fromList([2]),
              position: 0,
            ),
            _resolved(
              diveSourceUuid: 'unknown-uuid',
              filename: 'orphan.jpg',
              bytes: Uint8List.fromList([3]),
            ),
          ],
          sourceUuidToDiveId: const {diveA: newA, diveB: newB},
        );

        expect(result.written, 2);
        expect(result.missingBytes, 1);
        expect(result.orphanDive, 1);
        expect(result.failures, 0);

        final mediaA = await mediaRepository.getMediaForDive(newA);
        expect(mediaA, hasLength(1));
        expect(mediaA.single.originalFilename, 'a1.jpg');

        final mediaB = await mediaRepository.getMediaForDive(newB);
        expect(mediaB, hasLength(1));
        expect(mediaB.single.originalFilename, 'b1.jpg');
      },
    );

    test('empty resolved list returns all-zero counts', () async {
      final service = buildService();
      final result = await service.linkAll(
        resolved: const [],
        sourceUuidToDiveId: const {'anything': 'nope'},
      );
      expect(result.written, 0);
      expect(result.missingBytes, 0);
      expect(result.orphanDive, 0);
      expect(result.failures, 0);
      expect(result.isAllWritten, isTrue);
    });

    test('photos preserve position ordering in the on-disk filename', () async {
      const diveSourceUuid = 'dive-src-1';
      const newDiveId = 'new-dive-1';
      await _insertBareDive(db, newDiveId);
      final service = buildService();

      await service.linkAll(
        resolved: [
          _resolved(
            diveSourceUuid: diveSourceUuid,
            filename: 'reef.jpg',
            bytes: Uint8List.fromList([1]),
            position: 5,
          ),
          _resolved(
            diveSourceUuid: diveSourceUuid,
            filename: 'turtle.jpg',
            bytes: Uint8List.fromList([2]),
            position: 0,
          ),
        ],
        sourceUuidToDiveId: const {diveSourceUuid: newDiveId},
      );

      expect(
        File('${mediaRoot.path}/dive/$newDiveId/5-reef.jpg').existsSync(),
        isTrue,
      );
      expect(
        File('${mediaRoot.path}/dive/$newDiveId/0-turtle.jpg').existsSync(),
        isTrue,
      );
    });
  });
}
