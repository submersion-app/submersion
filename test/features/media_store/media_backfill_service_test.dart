import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaBackfillService service;

  setUp(() async {
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    service = MediaBackfillService(
      mediaRepository: mediaRepository,
      queue: queue,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<domain.MediaItem> mediaRow({
    required String name,
    domain.MediaType mediaType = domain.MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? takenAt,
    DateTime? uploadedAt,
  }) async {
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: mediaType,
        sourceType: sourceType,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        takenAt: takenAt ?? DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (uploadedAt != null) {
      await mediaRepository.stampRemoteUploaded(
        created.id,
        uploadedAt: uploadedAt,
      );
    }
    return created;
  }

  test('enqueues device-resident photos without a remote stamp, newest '
      'first, skipping videos, signatures, network sources, and uploaded '
      'rows', () async {
    final old = await mediaRow(name: 'old.jpg', takenAt: DateTime(2025));
    final recent = await mediaRow(name: 'new.jpg', takenAt: DateTime(2026, 6));
    await mediaRow(name: 'clip.mp4', mediaType: domain.MediaType.video);
    await mediaRow(
      name: 'sig.png',
      mediaType: domain.MediaType.instructorSignature,
    );
    await mediaRow(name: 'net.jpg', sourceType: MediaSourceType.networkUrl);
    await mediaRow(name: 'up.jpg', uploadedAt: DateTime(2026, 7));

    final ids = await mediaRepository.getBackfillCandidateIds();
    expect(ids, [recent.id, old.id]);

    expect(await service.enqueueAll(), 2);
    final rows = await queue.allForTesting();
    expect(rows.map((r) => r.mediaId).toSet(), {recent.id, old.id});

    // Idempotent: re-running does not duplicate pending rows.
    expect(await service.enqueueAll(), 2);
    expect((await queue.allForTesting()).length, 2);
  });

  test('connector photos are candidates; connector videos key on the thumb '
      'stamp', () async {
    final photo = await mediaRow(
      name: 'lr.jpg',
      sourceType: MediaSourceType.serviceConnector,
    );
    final videoNoThumb = await mediaRow(
      name: 'lr1.mp4',
      mediaType: domain.MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
      takenAt: DateTime(2025, 12),
    );
    final videoWithThumb = await mediaRow(
      name: 'lr2.mp4',
      mediaType: domain.MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
    );
    await mediaRepository.stampRemoteThumbUploaded(
      videoWithThumb.id,
      uploadedAt: DateTime(2026, 7),
    );
    // A gallery video stays excluded even though connector videos now
    // qualify.
    await mediaRow(name: 'gal.mp4', mediaType: domain.MediaType.video);

    final ids = await mediaRepository.getBackfillCandidateIds();
    expect(ids, [photo.id, videoNoThumb.id]);
  });
}
