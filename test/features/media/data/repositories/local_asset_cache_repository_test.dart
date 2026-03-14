import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late LocalAssetCacheRepository repository;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repository = LocalAssetCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  group('LocalAssetCacheRepository', () {
    test('getCachedAssetId returns null for unknown mediaId', () async {
      final result = await repository.getCachedAssetId('unknown-id');
      expect(result, isNull);
    });

    test('cacheResolution stores and retrieves a resolved asset ID', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      final result = await repository.getCachedAssetId('media-1');
      expect(result, equals('local-asset-abc'));
    });

    test('cacheResolution stores null for unresolved entries', () async {
      await repository.cacheResolution(
        mediaId: 'media-2',
        localAssetId: null,
        method: 'unresolved',
      );

      final entry = await repository.getCacheEntry('media-2');
      expect(entry, isNotNull);
      expect(entry!.localAssetId, isNull);
      expect(entry.resolutionMethod, equals('unresolved'));
    });

    test('clearEntry removes a cached entry', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      await repository.clearEntry('media-1');

      final result = await repository.getCachedAssetId('media-1');
      expect(result, isNull);
    });

    test('isExpired returns true for unresolved entry past backoff', () async {
      final pastTime = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(
            LocalAssetCacheCompanion.insert(
              mediaId: 'media-old',
              resolvedAt: pastTime,
              resolutionMethod: 'unresolved',
              attemptCount: const Value(0),
            ),
          );

      final expired = await repository.isExpired('media-old');
      expect(expired, isTrue);
    });

    test('isExpired returns false for resolved entry', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      final expired = await repository.isExpired('media-1');
      expect(expired, isFalse);
    });

    test('incrementAttempt increases attempt_count', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: null,
        method: 'unresolved',
      );

      await repository.incrementAttempt('media-1');

      final entry = await repository.getCacheEntry('media-1');
      expect(entry!.attemptCount, equals(1));
    });
  });
}
