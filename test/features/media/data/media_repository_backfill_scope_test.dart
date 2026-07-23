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
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(
    String name, {
    String? diveId,
    String? siteId,
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: sourceType,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    siteId: siteId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test(
    'unlinked media are never backfill candidates (orphan regression)',
    () async {
      await insertDive('dive-1');
      await insertSite('site-1');
      final linkedToDive = await repo.createMedia(
        item('a.jpg', diveId: 'dive-1'),
      );
      final linkedToSite = await repo.createMedia(
        item('b.jpg', siteId: 'site-1'),
      );
      // The observed bug, miniaturized: an orphan gallery photo (dive was
      // deleted; FK nulled dive_id) must not be uploaded.
      await repo.createMedia(item('orphan.jpg'));
      // The video arm has the same hole and must be scoped too.
      await repo.createMedia(
        item(
          'orphan.mp4',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.serviceConnector,
        ),
      );

      final ids = await repo.getBackfillCandidateIds();
      expect(ids.toSet(), {linkedToDive.id, linkedToSite.id});
    },
  );

  group('videos are backfill candidates', () {
    test('an unbacked localFile video is a candidate', () async {
      await insertDive('dive-v1');
      final video = await repo.createMedia(
        item(
          'clip.mp4',
          diveId: 'dive-v1',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.localFile,
        ),
      );
      expect(await repo.getBackfillCandidateIds(), contains(video.id));
    });

    test('an unbacked platformGallery video is a candidate', () async {
      await insertDive('dive-v2');
      final video = await repo.createMedia(
        item(
          'clip2.mp4',
          diveId: 'dive-v2',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.platformGallery,
        ),
      );
      expect(await repo.getBackfillCandidateIds(), contains(video.id));
    });

    test('a video that already uploaded is not a candidate', () async {
      await insertDive('dive-v3');
      final video = await repo.createMedia(
        item(
          'clip3.mp4',
          diveId: 'dive-v3',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.localFile,
        ),
      );
      await repo.stampRemoteUploaded(video.id, uploadedAt: DateTime(2026, 6));
      expect(await repo.getBackfillCandidateIds(), isNot(contains(video.id)));
    });

    test(
      'a connector video with an uploaded thumb is not re-enqueued',
      () async {
        await insertDive('dive-v4');
        final video = await repo.createMedia(
          item(
            'connector.mp4',
            diveId: 'dive-v4',
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
          ),
        );
        await repo.stampRemoteThumbUploaded(
          video.id,
          uploadedAt: DateTime(2026, 6),
        );
        expect(await repo.getBackfillCandidateIds(), isNot(contains(video.id)));
      },
    );
  });
}
