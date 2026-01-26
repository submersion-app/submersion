import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  group('MediaType', () {
    test('displayName returns human-readable text', () {
      expect(MediaType.photo.displayName, 'Photo');
      expect(MediaType.video.displayName, 'Video');
      expect(MediaType.instructorSignature.displayName, 'Instructor Signature');
    });

    test('fromString parses valid values', () {
      expect(MediaType.fromString('photo'), MediaType.photo);
      expect(MediaType.fromString('video'), MediaType.video);
      expect(
        MediaType.fromString('instructorSignature'),
        MediaType.instructorSignature,
      );
    });

    test('fromString returns null for invalid values', () {
      expect(MediaType.fromString('invalid'), isNull);
      expect(MediaType.fromString(null), isNull);
    });
  });

  group('MatchConfidence', () {
    test('displayName returns human-readable text', () {
      expect(MatchConfidence.exact.displayName, 'Exact');
      expect(MatchConfidence.interpolated.displayName, 'Interpolated');
      expect(MatchConfidence.estimated.displayName, 'Estimated');
      expect(MatchConfidence.noProfile.displayName, 'No Profile');
    });

    test('fromString parses valid values', () {
      expect(MatchConfidence.fromString('exact'), MatchConfidence.exact);
      expect(
        MatchConfidence.fromString('interpolated'),
        MatchConfidence.interpolated,
      );
      expect(
        MatchConfidence.fromString('estimated'),
        MatchConfidence.estimated,
      );
      expect(
        MatchConfidence.fromString('noProfile'),
        MatchConfidence.noProfile,
      );
    });

    test('fromString returns null for invalid values', () {
      expect(MatchConfidence.fromString('invalid'), isNull);
      expect(MatchConfidence.fromString(null), isNull);
    });
  });

  group('MediaItem', () {
    late MediaItem baseItem;
    late DateTime now;

    setUp(() {
      now = DateTime(2024, 6, 15, 10, 30);
      baseItem = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('creates with required fields', () {
      expect(baseItem.id, 'media-1');
      expect(baseItem.diveId, 'dive-1');
      expect(baseItem.platformAssetId, 'asset-123');
      expect(baseItem.mediaType, MediaType.photo);
      expect(baseItem.takenAt, now);
      expect(baseItem.createdAt, now);
      expect(baseItem.updatedAt, now);
    });

    test('optional fields default to null or expected values', () {
      expect(baseItem.siteId, isNull);
      expect(baseItem.filePath, isNull);
      expect(baseItem.originalFilename, isNull);
      expect(baseItem.latitude, isNull);
      expect(baseItem.longitude, isNull);
      expect(baseItem.width, isNull);
      expect(baseItem.height, isNull);
      expect(baseItem.durationSeconds, isNull);
      expect(baseItem.caption, isNull);
      expect(baseItem.isFavorite, false);
      expect(baseItem.thumbnailPath, isNull);
      expect(baseItem.thumbnailGeneratedAt, isNull);
      expect(baseItem.lastVerifiedAt, isNull);
      expect(baseItem.isOrphaned, false);
      expect(baseItem.signerId, isNull);
      expect(baseItem.signerName, isNull);
      expect(baseItem.enrichment, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = baseItem.copyWith(caption: 'Beautiful reef');

      expect(updated.id, baseItem.id);
      expect(updated.diveId, baseItem.diveId);
      expect(updated.platformAssetId, baseItem.platformAssetId);
      expect(updated.mediaType, baseItem.mediaType);
      expect(updated.takenAt, baseItem.takenAt);
      expect(updated.caption, 'Beautiful reef');
    });

    test('copyWith can update all fields', () {
      final newTime = DateTime(2024, 7, 1);
      final updated = baseItem.copyWith(
        id: 'media-2',
        diveId: 'dive-2',
        siteId: 'site-1',
        platformAssetId: 'asset-456',
        filePath: '/path/to/file.jpg',
        originalFilename: 'photo.jpg',
        mediaType: MediaType.video,
        latitude: 45.5,
        longitude: -122.6,
        takenAt: newTime,
        width: 1920,
        height: 1080,
        durationSeconds: 120,
        caption: 'Test caption',
        isFavorite: true,
        thumbnailPath: '/path/to/thumb.jpg',
        thumbnailGeneratedAt: newTime,
        lastVerifiedAt: newTime,
        isOrphaned: true,
        signerId: 'signer-1',
        signerName: 'John Instructor',
        createdAt: newTime,
        updatedAt: newTime,
      );

      expect(updated.id, 'media-2');
      expect(updated.diveId, 'dive-2');
      expect(updated.siteId, 'site-1');
      expect(updated.platformAssetId, 'asset-456');
      expect(updated.filePath, '/path/to/file.jpg');
      expect(updated.originalFilename, 'photo.jpg');
      expect(updated.mediaType, MediaType.video);
      expect(updated.latitude, 45.5);
      expect(updated.longitude, -122.6);
      expect(updated.takenAt, newTime);
      expect(updated.width, 1920);
      expect(updated.height, 1080);
      expect(updated.durationSeconds, 120);
      expect(updated.caption, 'Test caption');
      expect(updated.isFavorite, true);
      expect(updated.thumbnailPath, '/path/to/thumb.jpg');
      expect(updated.thumbnailGeneratedAt, newTime);
      expect(updated.lastVerifiedAt, newTime);
      expect(updated.isOrphaned, true);
      expect(updated.signerId, 'signer-1');
      expect(updated.signerName, 'John Instructor');
      expect(updated.createdAt, newTime);
      expect(updated.updatedAt, newTime);
    });

    test('copyWith can set nullable fields to null', () {
      final itemWithValues = baseItem.copyWith(
        siteId: 'site-1',
        caption: 'Test',
        signerId: 'signer-1',
      );

      final cleared = itemWithValues.copyWith(
        siteId: null,
        caption: null,
        signerId: null,
      );

      expect(cleared.siteId, isNull);
      expect(cleared.caption, isNull);
      expect(cleared.signerId, isNull);
    });

    test('isGalleryPhoto returns true for platform asset', () {
      final galleryPhoto = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(galleryPhoto.isGalleryPhoto, true);
    });

    test('isGalleryPhoto returns false for file path only', () {
      final filePhoto = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        filePath: '/path/to/photo.jpg',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(filePhoto.isGalleryPhoto, false);
    });

    test('isVideo returns true for video type', () {
      final video = baseItem.copyWith(mediaType: MediaType.video);
      expect(video.isVideo, true);
    });

    test('isVideo returns false for photo type', () {
      expect(baseItem.isVideo, false);
    });

    test('durationString formats seconds correctly', () {
      final video30s = baseItem.copyWith(durationSeconds: 30);
      expect(video30s.durationString, '0:30');

      final video90s = baseItem.copyWith(durationSeconds: 90);
      expect(video90s.durationString, '1:30');

      final video3600s = baseItem.copyWith(durationSeconds: 3661);
      expect(video3600s.durationString, '61:01');
    });

    test('durationString returns null when no duration', () {
      expect(baseItem.durationString, isNull);
    });

    test('equality works correctly', () {
      final item1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final item2 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final item3 = MediaItem(
        id: 'media-2',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
    });
  });

  group('MediaEnrichment', () {
    late MediaEnrichment baseEnrichment;
    late DateTime now;

    setUp(() {
      now = DateTime(2024, 6, 15, 10, 30);
      baseEnrichment = MediaEnrichment(
        id: 'enrichment-1',
        mediaId: 'media-1',
        diveId: 'dive-1',
        depthMeters: 15.5,
        matchConfidence: MatchConfidence.exact,
        createdAt: now,
      );
    });

    test('creates with dive data', () {
      expect(baseEnrichment.id, 'enrichment-1');
      expect(baseEnrichment.mediaId, 'media-1');
      expect(baseEnrichment.diveId, 'dive-1');
      expect(baseEnrichment.depthMeters, 15.5);
      expect(baseEnrichment.matchConfidence, MatchConfidence.exact);
      expect(baseEnrichment.createdAt, now);
    });

    test('optional fields default to null', () {
      expect(baseEnrichment.temperatureCelsius, isNull);
      expect(baseEnrichment.elapsedSeconds, isNull);
      expect(baseEnrichment.timestampOffsetSeconds, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = baseEnrichment.copyWith(temperatureCelsius: 22.5);

      expect(updated.id, baseEnrichment.id);
      expect(updated.mediaId, baseEnrichment.mediaId);
      expect(updated.diveId, baseEnrichment.diveId);
      expect(updated.depthMeters, baseEnrichment.depthMeters);
      expect(updated.temperatureCelsius, 22.5);
    });

    test('copyWith can update all fields', () {
      final newTime = DateTime(2024, 7, 1);
      final updated = baseEnrichment.copyWith(
        id: 'enrichment-2',
        mediaId: 'media-2',
        diveId: 'dive-2',
        depthMeters: 25.0,
        temperatureCelsius: 20.0,
        elapsedSeconds: 1800,
        matchConfidence: MatchConfidence.interpolated,
        timestampOffsetSeconds: 30,
        createdAt: newTime,
      );

      expect(updated.id, 'enrichment-2');
      expect(updated.mediaId, 'media-2');
      expect(updated.diveId, 'dive-2');
      expect(updated.depthMeters, 25.0);
      expect(updated.temperatureCelsius, 20.0);
      expect(updated.elapsedSeconds, 1800);
      expect(updated.matchConfidence, MatchConfidence.interpolated);
      expect(updated.timestampOffsetSeconds, 30);
      expect(updated.createdAt, newTime);
    });

    test('equality works correctly', () {
      final enrichment1 = MediaEnrichment(
        id: 'enrichment-1',
        mediaId: 'media-1',
        diveId: 'dive-1',
        depthMeters: 15.5,
        matchConfidence: MatchConfidence.exact,
        createdAt: now,
      );

      final enrichment2 = MediaEnrichment(
        id: 'enrichment-1',
        mediaId: 'media-1',
        diveId: 'dive-1',
        depthMeters: 15.5,
        matchConfidence: MatchConfidence.exact,
        createdAt: now,
      );

      expect(enrichment1, equals(enrichment2));
    });
  });

  group('MediaSpeciesTag', () {
    late MediaSpeciesTag baseTag;
    late DateTime now;

    setUp(() {
      now = DateTime(2024, 6, 15, 10, 30);
      baseTag = MediaSpeciesTag(
        id: 'tag-1',
        mediaId: 'media-1',
        speciesId: 'species-1',
        createdAt: now,
      );
    });

    test('creates with required fields', () {
      expect(baseTag.id, 'tag-1');
      expect(baseTag.mediaId, 'media-1');
      expect(baseTag.speciesId, 'species-1');
      expect(baseTag.createdAt, now);
    });

    test('optional fields default to null', () {
      expect(baseTag.sightingId, isNull);
      expect(baseTag.bboxX, isNull);
      expect(baseTag.bboxY, isNull);
      expect(baseTag.bboxWidth, isNull);
      expect(baseTag.bboxHeight, isNull);
      expect(baseTag.notes, isNull);
    });

    test('creates with bounding box (normalized 0.0-1.0 coordinates)', () {
      final tagWithBbox = MediaSpeciesTag(
        id: 'tag-1',
        mediaId: 'media-1',
        speciesId: 'species-1',
        bboxX: 0.25,
        bboxY: 0.35,
        bboxWidth: 0.15,
        bboxHeight: 0.20,
        createdAt: now,
      );

      expect(tagWithBbox.bboxX, 0.25);
      expect(tagWithBbox.bboxY, 0.35);
      expect(tagWithBbox.bboxWidth, 0.15);
      expect(tagWithBbox.bboxHeight, 0.20);
    });

    test('equality works correctly', () {
      final tag1 = MediaSpeciesTag(
        id: 'tag-1',
        mediaId: 'media-1',
        speciesId: 'species-1',
        createdAt: now,
      );

      final tag2 = MediaSpeciesTag(
        id: 'tag-1',
        mediaId: 'media-1',
        speciesId: 'species-1',
        createdAt: now,
      );

      expect(tag1, equals(tag2));
    });
  });

  group('PendingPhotoSuggestion', () {
    late PendingPhotoSuggestion baseSuggestion;
    late DateTime now;

    setUp(() {
      now = DateTime(2024, 6, 15, 10, 30);
      baseSuggestion = PendingPhotoSuggestion(
        id: 'suggestion-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        takenAt: now,
        createdAt: now,
      );
    });

    test('creates with required fields', () {
      expect(baseSuggestion.id, 'suggestion-1');
      expect(baseSuggestion.diveId, 'dive-1');
      expect(baseSuggestion.platformAssetId, 'asset-123');
      expect(baseSuggestion.takenAt, now);
      expect(baseSuggestion.createdAt, now);
    });

    test('optional fields have expected defaults', () {
      expect(baseSuggestion.thumbnailPath, isNull);
      expect(baseSuggestion.dismissed, false);
    });

    test('equality works correctly', () {
      final suggestion1 = PendingPhotoSuggestion(
        id: 'suggestion-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        takenAt: now,
        createdAt: now,
      );

      final suggestion2 = PendingPhotoSuggestion(
        id: 'suggestion-1',
        diveId: 'dive-1',
        platformAssetId: 'asset-123',
        takenAt: now,
        createdAt: now,
      );

      expect(suggestion1, equals(suggestion2));
    });
  });
}
