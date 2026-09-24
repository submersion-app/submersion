import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/sync/media_resolution_hints.dart';
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

    test('isExpired uses 3-day backoff at attempt count 1', () async {
      // 2 days ago (within 3-day window at attempt 1)
      final twoDaysAgo = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(
            LocalAssetCacheCompanion.insert(
              mediaId: 'media-attempt1',
              resolvedAt: twoDaysAgo,
              resolutionMethod: 'unresolved',
              attemptCount: const Value(1),
            ),
          );

      final expired = await repository.isExpired('media-attempt1');
      expect(expired, isFalse);
    });

    test('isExpired expires after 3 days at attempt count 1', () async {
      final fourDaysAgo = DateTime.now()
          .subtract(const Duration(days: 4))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(
            LocalAssetCacheCompanion.insert(
              mediaId: 'media-attempt1-expired',
              resolvedAt: fourDaysAgo,
              resolutionMethod: 'unresolved',
              attemptCount: const Value(1),
            ),
          );

      final expired = await repository.isExpired('media-attempt1-expired');
      expect(expired, isTrue);
    });

    test('isExpired uses 7-day backoff at attempt count 2+', () async {
      // 5 days ago (within 7-day window at attempt 2)
      final fiveDaysAgo = DateTime.now()
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(
            LocalAssetCacheCompanion.insert(
              mediaId: 'media-attempt2',
              resolvedAt: fiveDaysAgo,
              resolutionMethod: 'unresolved',
              attemptCount: const Value(2),
            ),
          );

      final expired = await repository.isExpired('media-attempt2');
      expect(expired, isFalse);
    });

    test('isExpired expires after 7 days at attempt count 2+', () async {
      final eightDaysAgo = DateTime.now()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(
            LocalAssetCacheCompanion.insert(
              mediaId: 'media-attempt2-expired',
              resolvedAt: eightDaysAgo,
              resolutionMethod: 'unresolved',
              attemptCount: const Value(2),
            ),
          );

      final expired = await repository.isExpired('media-attempt2-expired');
      expect(expired, isTrue);
    });

    test(
      'isExpired clamps backoff at 7 days for high attempt counts',
      () async {
        // Even at attempt count 10, backoff should clamp to 7 days (index 2)
        final sixDaysAgo = DateTime.now()
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch;

        await db
            .into(db.localAssetCache)
            .insert(
              LocalAssetCacheCompanion.insert(
                mediaId: 'media-attempt10',
                resolvedAt: sixDaysAgo,
                resolutionMethod: 'unresolved',
                attemptCount: const Value(10),
              ),
            );

        final expired = await repository.isExpired('media-attempt10');
        expect(expired, isFalse);
      },
    );

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

  // A sync that brings a row a cloud id or an upload retries its search at
  // once (spec 6.2); a mapping that was found stays.
  test('clearUnresolved drops only unresolved entries', () async {
    await repository.cacheResolution(
      mediaId: 'u',
      localAssetId: null,
      method: 'unresolved',
    );
    await repository.cacheResolution(
      mediaId: 'r',
      localAssetId: 'B-1',
      method: 'cloud_id',
    );

    await repository.clearUnresolved(['u', 'r', 'absent']);

    expect(await repository.getCacheEntry('u'), isNull);
    expect((await repository.getCacheEntry('r'))!.localAssetId, 'B-1');
  });

  // A relink on a peer points the row at another photo, so even a mapping
  // this device found is about the old one.
  test('applyResolutionHints drops remapped rows whatever they say', () async {
    await repository.cacheResolution(
      mediaId: 'u',
      localAssetId: null,
      method: 'unresolved',
    );
    await repository.cacheResolution(
      mediaId: 'r',
      localAssetId: 'B-1',
      method: 'cloud_id',
    );
    await repository.cacheResolution(
      mediaId: 'moved',
      localAssetId: 'B-2',
      method: 'cloud_id',
    );

    await repository.applyResolutionHints(
      const MediaResolutionHints(retry: {'u', 'r'}, remap: {'moved'}),
    );

    expect(await repository.getCacheEntry('u'), isNull);
    expect((await repository.getCacheEntry('r'))!.localAssetId, 'B-1');
    expect(await repository.getCacheEntry('moved'), isNull);
  });
}
