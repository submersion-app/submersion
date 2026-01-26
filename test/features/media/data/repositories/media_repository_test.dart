import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repository;
  late DiveRepository diveRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
    diveRepository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Helper to create a dive in the database for tests that need dive associations
  Future<Dive> createTestDiveInDb({String id = '', int diveNumber = 1}) async {
    final dive = Dive(id: id, diveNumber: diveNumber, dateTime: DateTime.now());
    return diveRepository.createDive(dive);
  }

  MediaItem createTestMediaItem({
    String id = '',
    String? diveId,
    String? siteId,
    String? platformAssetId,
    String filePath = '/path/to/photo.jpg',
    String? originalFilename,
    MediaType mediaType = MediaType.photo,
    double? latitude,
    double? longitude,
    DateTime? takenAt,
    int? width,
    int? height,
    int? durationSeconds,
    String? caption,
    bool isFavorite = false,
    bool isOrphaned = false,
    String? signerId,
    String? signerName,
  }) {
    final now = DateTime.now();
    return MediaItem(
      id: id,
      diveId: diveId,
      siteId: siteId,
      platformAssetId: platformAssetId,
      filePath: filePath,
      originalFilename: originalFilename,
      mediaType: mediaType,
      latitude: latitude,
      longitude: longitude,
      takenAt: takenAt ?? now,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      caption: caption,
      isFavorite: isFavorite,
      isOrphaned: isOrphaned,
      signerId: signerId,
      signerName: signerName,
      createdAt: now,
      updatedAt: now,
    );
  }

  MediaEnrichment createTestEnrichment({
    String id = '',
    required String mediaId,
    required String diveId,
    double? depthMeters,
    double? temperatureCelsius,
    int? elapsedSeconds,
    MatchConfidence matchConfidence = MatchConfidence.exact,
    int? timestampOffsetSeconds,
  }) {
    return MediaEnrichment(
      id: id,
      mediaId: mediaId,
      diveId: diveId,
      depthMeters: depthMeters,
      temperatureCelsius: temperatureCelsius,
      elapsedSeconds: elapsedSeconds,
      matchConfidence: matchConfidence,
      timestampOffsetSeconds: timestampOffsetSeconds,
      createdAt: DateTime.now(),
    );
  }

  group('MediaRepository', () {
    group('createMedia', () {
      test('should create media with generated ID when ID is empty', () async {
        final media = createTestMediaItem(filePath: '/photos/dive1.jpg');

        final created = await repository.createMedia(media);

        expect(created.id, isNotEmpty);
        expect(created.filePath, equals('/photos/dive1.jpg'));
      });

      test('should create media with provided ID', () async {
        final media = createTestMediaItem(
          id: 'custom-media-id',
          filePath: '/photos/dive2.jpg',
        );

        final created = await repository.createMedia(media);

        expect(created.id, equals('custom-media-id'));
      });

      test('should create media with all fields', () async {
        final takenAt = DateTime(2024, 1, 15, 10, 30, 0);
        final media = createTestMediaItem(
          filePath: '/photos/complete.jpg',
          platformAssetId: 'platform-123',
          originalFilename: 'IMG_001.jpg',
          mediaType: MediaType.photo,
          latitude: 45.5,
          longitude: -122.5,
          takenAt: takenAt,
          width: 1920,
          height: 1080,
          caption: 'Beautiful reef',
          isFavorite: true,
        );

        final created = await repository.createMedia(media);
        final fetched = await repository.getMediaById(created.id);

        expect(fetched, isNotNull);
        expect(fetched!.filePath, equals('/photos/complete.jpg'));
        expect(fetched.platformAssetId, equals('platform-123'));
        expect(fetched.originalFilename, equals('IMG_001.jpg'));
        expect(fetched.mediaType, equals(MediaType.photo));
        expect(fetched.latitude, equals(45.5));
        expect(fetched.longitude, equals(-122.5));
        expect(fetched.width, equals(1920));
        expect(fetched.height, equals(1080));
        expect(fetched.caption, equals('Beautiful reef'));
        expect(fetched.isFavorite, isTrue);
      });

      test('should create media linked to a dive', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final media = createTestMediaItem(
          diveId: dive.id,
          filePath: '/photos/linked.jpg',
        );

        final created = await repository.createMedia(media);
        final fetched = await repository.getMediaById(created.id);

        expect(fetched, isNotNull);
        expect(fetched!.diveId, equals(dive.id));
      });
    });

    group('getMediaById', () {
      test('should return media when found', () async {
        final media = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/findme.jpg'),
        );

        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.filePath, equals('/photos/findme.jpg'));
      });

      test('should return null when media not found', () async {
        final result = await repository.getMediaById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getMediaForDive', () {
      test('should return empty list when dive has no media', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final result = await repository.getMediaForDive(dive.id);

        expect(result, isEmpty);
      });

      test('should return media ordered by takenAt', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final earlier = DateTime(2024, 1, 15, 10, 0, 0);
        final later = DateTime(2024, 1, 15, 10, 30, 0);
        final latest = DateTime(2024, 1, 15, 11, 0, 0);

        await repository.createMedia(
          createTestMediaItem(
            diveId: dive.id,
            filePath: '/photos/middle.jpg',
            takenAt: later,
          ),
        );
        await repository.createMedia(
          createTestMediaItem(
            diveId: dive.id,
            filePath: '/photos/first.jpg',
            takenAt: earlier,
          ),
        );
        await repository.createMedia(
          createTestMediaItem(
            diveId: dive.id,
            filePath: '/photos/last.jpg',
            takenAt: latest,
          ),
        );

        final result = await repository.getMediaForDive(dive.id);

        expect(result.length, equals(3));
        expect(result[0].filePath, equals('/photos/first.jpg'));
        expect(result[1].filePath, equals('/photos/middle.jpg'));
        expect(result[2].filePath, equals('/photos/last.jpg'));
      });

      test('should only return media for specified dive', () async {
        final dive1 = await createTestDiveInDb(diveNumber: 1);
        final dive2 = await createTestDiveInDb(diveNumber: 2);

        await repository.createMedia(
          createTestMediaItem(diveId: dive1.id, filePath: '/photos/dive1.jpg'),
        );
        await repository.createMedia(
          createTestMediaItem(diveId: dive2.id, filePath: '/photos/dive2.jpg'),
        );

        final result = await repository.getMediaForDive(dive1.id);

        expect(result.length, equals(1));
        expect(result[0].filePath, equals('/photos/dive1.jpg'));
      });
    });

    group('updateMedia', () {
      test('should update media fields', () async {
        final media = await repository.createMedia(
          createTestMediaItem(
            filePath: '/photos/original.jpg',
            caption: 'Original caption',
          ),
        );

        final updated = media.copyWith(
          caption: 'Updated caption',
          isFavorite: true,
        );

        await repository.updateMedia(updated);
        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.caption, equals('Updated caption'));
        expect(result.isFavorite, isTrue);
      });
    });

    group('deleteMedia', () {
      test('should delete existing media', () async {
        final media = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/delete.jpg'),
        );

        await repository.deleteMedia(media.id);
        final result = await repository.getMediaById(media.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent media', () async {
        await expectLater(repository.deleteMedia('non-existent-id'), completes);
      });
    });

    group('orphaned media', () {
      test('should mark media as orphaned', () async {
        final media = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/orphan.jpg'),
        );
        expect(media.isOrphaned, isFalse);

        await repository.markAsOrphaned(media.id);
        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.isOrphaned, isTrue);
      });

      test('should mark media as verified', () async {
        final media = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/verify.jpg', isOrphaned: true),
        );

        await repository.markAsVerified(media.id);
        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.isOrphaned, isFalse);
        expect(result.lastVerifiedAt, isNotNull);
      });

      test('should get all orphaned media', () async {
        await repository.createMedia(
          createTestMediaItem(filePath: '/photos/normal.jpg'),
        );
        final orphan1 = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/orphan1.jpg'),
        );
        await repository.markAsOrphaned(orphan1.id);
        final orphan2 = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/orphan2.jpg'),
        );
        await repository.markAsOrphaned(orphan2.id);

        final result = await repository.getOrphanedMedia();

        expect(result.length, equals(2));
        expect(result.every((m) => m.isOrphaned), isTrue);
      });

      test('should delete all orphaned media and return count', () async {
        final normal = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/keep.jpg'),
        );
        final orphan1 = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/delete1.jpg'),
        );
        await repository.markAsOrphaned(orphan1.id);
        final orphan2 = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/delete2.jpg'),
        );
        await repository.markAsOrphaned(orphan2.id);

        final deletedCount = await repository.deleteOrphanedMedia();

        expect(deletedCount, equals(2));

        final remaining = await repository.getOrphanedMedia();
        expect(remaining, isEmpty);

        // Non-orphaned media should still exist
        final kept = await repository.getMediaById(normal.id);
        expect(kept, isNotNull);
        expect(kept!.filePath, equals('/photos/keep.jpg'));
      });
    });

    group('enrichment', () {
      test('should save and retrieve enrichment data', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final media = await repository.createMedia(
          createTestMediaItem(
            diveId: dive.id,
            filePath: '/photos/enriched.jpg',
          ),
        );

        final enrichment = createTestEnrichment(
          mediaId: media.id,
          diveId: dive.id,
          depthMeters: 15.5,
          temperatureCelsius: 22.0,
          elapsedSeconds: 300,
          matchConfidence: MatchConfidence.interpolated,
          timestampOffsetSeconds: -5,
        );

        await repository.saveEnrichment(enrichment);
        final result = await repository.getEnrichmentForMedia(media.id);

        expect(result, isNotNull);
        expect(result!.mediaId, equals(media.id));
        expect(result.diveId, equals(dive.id));
        expect(result.depthMeters, equals(15.5));
        expect(result.temperatureCelsius, equals(22.0));
        expect(result.elapsedSeconds, equals(300));
        expect(result.matchConfidence, equals(MatchConfidence.interpolated));
        expect(result.timestampOffsetSeconds, equals(-5));
      });

      test('should return null when no enrichment exists', () async {
        final media = await repository.createMedia(
          createTestMediaItem(filePath: '/photos/noenrich.jpg'),
        );

        final result = await repository.getEnrichmentForMedia(media.id);

        expect(result, isNull);
      });

      test('should update existing enrichment when saving', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final media = await repository.createMedia(
          createTestMediaItem(diveId: dive.id, filePath: '/photos/update.jpg'),
        );

        final initial = createTestEnrichment(
          mediaId: media.id,
          diveId: dive.id,
          depthMeters: 10.0,
        );
        await repository.saveEnrichment(initial);

        final updated = createTestEnrichment(
          mediaId: media.id,
          diveId: dive.id,
          depthMeters: 20.0,
        );
        await repository.saveEnrichment(updated);

        final result = await repository.getEnrichmentForMedia(media.id);
        expect(result!.depthMeters, equals(20.0));
      });
    });

    group('media count', () {
      test('should return count of media for dive', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final otherDive = await createTestDiveInDb(diveNumber: 2);

        await repository.createMedia(
          createTestMediaItem(diveId: dive.id, filePath: '/photos/1.jpg'),
        );
        await repository.createMedia(
          createTestMediaItem(diveId: dive.id, filePath: '/photos/2.jpg'),
        );
        await repository.createMedia(
          createTestMediaItem(diveId: dive.id, filePath: '/photos/3.jpg'),
        );
        await repository.createMedia(
          createTestMediaItem(diveId: otherDive.id, filePath: '/photos/4.jpg'),
        );

        final count = await repository.getMediaCountForDive(dive.id);

        expect(count, equals(3));
      });

      test('should return 0 when dive has no media', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final count = await repository.getMediaCountForDive(dive.id);

        expect(count, equals(0));
      });
    });

    group('pending suggestions', () {
      test('should return 0 when no pending suggestions exist', () async {
        final dive = await createTestDiveInDb(diveNumber: 1);
        final count = await repository.getPendingSuggestionCount(dive.id);

        expect(count, equals(0));
      });
    });

    group('video media', () {
      test('should create and retrieve video with duration', () async {
        final media = await repository.createMedia(
          createTestMediaItem(
            filePath: '/videos/dive.mp4',
            mediaType: MediaType.video,
            durationSeconds: 120,
          ),
        );

        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.mediaType, equals(MediaType.video));
        expect(result.durationSeconds, equals(120));
      });
    });

    group('instructor signature', () {
      test('should create signature with signer name only', () async {
        // Note: signerId requires a valid buddy to exist in the database.
        // For this test, we only use signerName which doesn't have a FK constraint.
        final media = await repository.createMedia(
          createTestMediaItem(
            filePath: '/signatures/instructor.png',
            mediaType: MediaType.instructorSignature,
            signerName: 'John Instructor',
          ),
        );

        final result = await repository.getMediaById(media.id);

        expect(result, isNotNull);
        expect(result!.mediaType, equals(MediaType.instructorSignature));
        expect(result.signerName, equals('John Instructor'));
      });
    });
  });
}
