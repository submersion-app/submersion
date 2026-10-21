// Issue #3482 phase 4: the Photos page says "{copied} of {total} copied",
// counted with the same rule that decides what "Upload everything already
// attached" would upload, so the two never disagree.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(DateTime(2026).millisecondsSinceEpoch),
            createdAt: Value(DateTime(2026).millisecondsSinceEpoch),
            updatedAt: Value(DateTime(2026).millisecondsSinceEpoch),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<String> add(
    String name, {
    String? diveId = 'dive-1',
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
    String? originDeviceId,
    bool original = false,
    bool compressed = false,
    bool thumb = false,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: mediaType,
        sourceType: sourceType,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        diveId: diveId,
        originDeviceId: originDeviceId,
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await (db.update(db.media)..where((m) => m.id.equals(created.id))).write(
      MediaCompanion(
        remoteUploadedAt: Value(original ? 1 : null),
        remoteCompressedUploadedAt: Value(compressed ? 1 : null),
        remoteThumbUploadedAt: Value(thumb ? 1 : null),
        originDeviceId: originDeviceId == null
            ? const Value.absent()
            : Value(originDeviceId),
      ),
    );
    return created.id;
  }

  Future<void> seedLibrary() async {
    await add('copied.jpg', original: true);
    await add('waiting.jpg');
    await add('compressed.jpg', compressed: true);
    await add(
      'copied.mp4',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.localFile,
      original: true,
    );
    // Connector videos copy their thumbnail only; this one has not yet.
    await add(
      'connector.mp4',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
    );
    // Not this device's to upload, and an orphan: neither counts.
    await add('desktop.jpg', originDeviceId: 'another-device');
    await add('orphan.jpg', diveId: null);
  }

  test('copied of total follows the upload rule', () async {
    await seedLibrary();

    final progress = await repo.countUploadProgress();

    expect(progress.total, 5);
    expect(progress.copied, 3);
  });

  test('what is left to copy is exactly what the backfill uploads', () async {
    await seedLibrary();

    final progress = await repo.countUploadProgress();
    final candidates = await repo.getBackfillCandidateIds();

    expect(candidates.length, progress.total - progress.copied);
  });

  test('an empty library counts nothing', () async {
    final progress = await repo.countUploadProgress();
    expect(progress.total, 0);
    expect(progress.copied, 0);
  });
}
