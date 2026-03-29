import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('MediaRepository error handling', () {
    late MediaRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = MediaRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final testMedia = MediaItem(
        id: 'test-id',
        mediaType: MediaType.photo,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final testEnrichment = MediaEnrichment(
        id: 'enrich-id',
        mediaId: 'test-id',
        diveId: 'dive-id',
        matchConfidence: MatchConfidence.noProfile,
        createdAt: now,
      );

      await expectLater(
        repository.getMediaForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(repository.getMediaById('test-id'), throwsA(anything));
      await expectLater(repository.createMedia(testMedia), throwsA(anything));
      await expectLater(repository.updateMedia(testMedia), throwsA(anything));
      await expectLater(repository.deleteMedia('test-id'), throwsA(anything));
      await expectLater(
        repository.deleteMultipleMedia(['test-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.markAsOrphaned('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.markAsVerified('test-id'),
        throwsA(anything),
      );
      await expectLater(repository.getOrphanedMedia(), throwsA(anything));
      await expectLater(repository.deleteOrphanedMedia(), throwsA(anything));
      await expectLater(
        repository.getEnrichmentForMedia('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.saveEnrichment(testEnrichment),
        throwsA(anything),
      );
      await expectLater(
        repository.getMediaCountForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getLinkedAssetIdsForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getGpsFromDiveMedia('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getPendingSuggestionCount('test-id'),
        throwsA(anything),
      );
    });
  });
}
